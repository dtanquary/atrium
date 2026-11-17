// Canopy mock-ups, drawn by SpriteKit's SKRenderer as the app's render test draws a wallpaper, so a tile shows what
// the build's shaders can draw. Not app code, but its sky, canopy shader and bake are meant to carry into the build.
// Started from the method research's probe ($TMPDIR/canopy-probe/main.swift and sky/main.swift).
//
//   swiftc -O mock.swift -o $TMPDIR/canopy-mock && $TMPDIR/canopy-mock '<json>'
//
// The camera lies on the forest floor looking straight up through a pinhole lens, `fov` degrees across the screen's
// long side (90 by default), head to the north: screen up is north, screen right is west. The sky is the app's own
// `Atmosphere` (copied in below) marched through that camera for a day of the year, a solar hour and a latitude. The
// crowns are one of three methods:
//   photo  (a) a real looking-up photo's canopy (a Poly Haven HDRI's zenith), its sky keyed out, swayed and relit;
//              autumn is a recolour and a dissolve of its leaves, with nothing behind them but sky.
//   built  (b) trees laid out by code (trunks, limbs, twigs) with scanned leaves grown on their twigs at load.
//   grown  (c) a real bare stand (an HDRI's zenith in leafless season) as the wood, with the same scanned leaves
//              grown on its twigs at load.
// In (b) and (c) the leaves are three depth layers of sprays, each spray an id that the season reads (when it turns,
// when it falls), lit by the light through the layers above it along the Sun's direction. Each crown sways as a body
// about its own base: a tree-id map flooded from each trunk along the wood, in four sway groups.
//
// JSON: method, hdri (path to an .hdr), out (.png, or a prefix with times), and optionally: rot, mirror, fov, width,
// height (points, drawn at 2x), day (of the year), hour (solar), lat, sprays (a layer), leafScale, turn (0 green to
// 1 turned), fallen (share of sprays down), palette (summer, bronze, aspen), trans (leaf transmittance), lift (contrast
// power on luminance, 1 = physics), skyDisp (the zenith's target brightness, 0-255), veil, overcast, camera (meter
// and clip as a camera does), sunBehind, halo, wind (m/s), falling (leaves in a 12 s window), fadeNear (m), trees,
// gap, clearSide (a forest edge), closed, bark (birch), soft (px of focus blur on the layers at 2x), zenith (the
// HDRI as a camera shows it), times, frames, fps, t, timing, raw (frames to stdout for ffmpeg).
import AppKit
import Foundation
import ImageIO
import Metal
import SpriteKit
import simd

struct Config: Decodable {
    var out: String
    var method: String?, hdri: String?
    var rot: Double?, mirror: Bool?, fov: Double?, width: Double?, height: Double?, seed: UInt64?
    var day: Double?, hour: Double?, lat: Double?
    var sprays: Int?, leafScale: Double?, turn: Double?, fallen: Double?, palette: String?, conifers: Bool?
    var trans: Double?, lift: Double?, skyDisp: Double?, veil: Double?, overcast: Bool?, camera: Bool?
    var sunBehind: Bool?, halo: Double?, wind: Double?, falling: Int?, fadeNear: Double?
    var trees: Int?, gap: Double?, clearSide: Double?, closed: Double?, bark: String?, soft: Int?
    var times: [Double]?, frames: Int?, fps: Double?, t: Double?, timing: Bool?, raw: Bool?, zenith: Bool?
}

setvbuf(stdout, nil, _IONBF, 0)
let cfg = try! JSONDecoder().decode(Config.self, from: CommandLine.arguments[1].data(using: .utf8)!)
let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path
let (wPt, hPt) = (cfg.width ?? 1512, cfg.height ?? 982)
let (W, H) = (Int(wPt * 2), Int(hPt * 2))
let margin = 1.1 // the canopy's layers are the screen plus 10%, to sway into
let (LW, LH) = (Int(Double(W) * margin), Int(Double(H) * margin))
let fov = cfg.fov ?? 90
let tanH = tan(fov / 2 * .pi / 180), tanV = tanH * Double(H) / Double(W)
let focal = Double(W) / 2 / tanH // pixels a radian at the centre, at 2x
let method = cfg.method ?? "grown"

/// SplitMix64: the same forest for the same seed.
struct Rand {
    var s: UInt64
    mutating func next() -> Double {
        s &+= 0x9E37_79B9_7F4A_7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
    }
    mutating func r(_ a: Double, _ b: Double) -> Double { a + (b - a) * next() }
}
var rng = Rand(s: cfg.seed ?? 3)
func ms(_ t0: UInt64) -> Double { Double(DispatchTime.now().uptimeNanoseconds - t0) / 1e6 }
func lin(_ hex: Int) -> SIMD3<Double> { SIMD3(Double(hex >> 16 & 255), Double(hex >> 8 & 255), Double(hex & 255)).map { pow($0 / 255, 2.2) } }
extension SIMD3 where Scalar == Double { func map(_ f: (Double) -> Double) -> SIMD3<Double> { SIMD3(f(x), f(y), f(z)) } }
func lum(_ v: SIMD3<Double>) -> Double { dot(v, SIMD3(0.2126, 0.7152, 0.0722)) }
func glsl(_ c: SIMD3<Double>) -> String { String(format: "vec3(%.5f, %.5f, %.5f)", c.x, c.y, c.z) }

/// A box blur of a float plane, `passes` times (three is close to a Gaussian), in place.
func boxBlur(_ a: inout [Float], _ w: Int, _ h: Int, _ r: Int, passes: Int = 2) {
    guard r > 0 else { return }
    var tmp = [Float](repeating: 0, count: a.count)
    for _ in 0..<passes {
        a.withUnsafeMutableBufferPointer { A in tmp.withUnsafeMutableBufferPointer { T in
            nonisolated(unsafe) let A = A, T = T
            DispatchQueue.concurrentPerform(iterations: h) { y in
                var s: Float = 0
                for x in -r...r { s += A[y * w + min(max(x, 0), w - 1)] }
                for x in 0..<w {
                    T[y * w + x] = s / Float(2 * r + 1)
                    s += A[y * w + min(x + r + 1, w - 1)] - A[y * w + max(x - r, 0)]
                }
            }
            DispatchQueue.concurrentPerform(iterations: w) { x in
                var s: Float = 0
                for y in -r...r { s += T[min(max(y, 0), h - 1) * w + x] }
                for y in 0..<h {
                    A[y * w + x] = s / Float(2 * r + 1)
                    s += T[min(y + r + 1, h - 1) * w + x] - T[max(y - r, 0) * w + x]
                }
            }
        } }
    }
}

// MARK: - The sky: the app's Atmosphere (WeatherSky.swift), copied in as the probe did

final class Atmosphere: @unchecked Sendable {
    typealias V3 = SIMD3<Double>
    static let shared = Atmosphere()
    static let ground = 6360.0, top = 6460.0
    static let rayleigh = V3(5.802, 13.558, 33.1) * 1e-3
    static let ozone = V3(0.650, 1.881, 0.085) * 1e-3
    static let mieScatter = 3.996e-3, mieExtinct = 4.44e-3
    private let transmittance: [V3]
    private let multiple: [V3]
    private init() {
        let t = (0..<64 * 256).map { i in Self.opticalTransmittance(Self.height(i / 256, 63), Double(i % 256) / 255 * 2 - 1) }
        transmittance = t
        multiple = (0..<32 * 32).map { i in Self.multipleScattering(Self.height(i / 32, 31), Double(i % 32) / 31 * 2 - 1, t) }
    }
    private static func height(_ i: Int, _ n: Int) -> Double { pow(Double(i) / Double(n), 2) * 100 }
    private static func extinction(_ h: Double) -> V3 {
        rayleigh * exp(-h / 8) + V3(repeating: mieExtinct * exp(-h / 1.2)) + ozone * max(0, 1 - abs(h - 25) / 15)
    }
    private static func distanceToTop(_ r: Double, _ mu: Double) -> Double { max(0, -r * mu + sqrt(max(r * r * (mu * mu - 1) + top * top, 0))) }
    private static func hitsGround(_ r: Double, _ mu: Double) -> Bool { mu < 0 && r * r * (mu * mu - 1) + ground * ground >= 0 }
    private static func distanceToGround(_ r: Double, _ mu: Double) -> Double { -r * mu - sqrt(max(r * r * (mu * mu - 1) + ground * ground, 0)) }
    private static func opticalTransmittance(_ h: Double, _ mu: Double) -> V3 {
        let r = ground + h
        if hitsGround(r, mu) { return .zero }
        let len = distanceToTop(r, mu), n = 40
        var depth = V3.zero
        for k in 0..<n {
            let t = (Double(k) + 0.5) / Double(n) * len
            depth += extinction(sqrt(r * r + t * t + 2 * r * t * mu) - ground) * (len / Double(n))
        }
        return exp(-depth)
    }
    private static func lookup(_ table: [V3], _ w: Int, _ rows: Int, _ h: Double, _ mu: Double) -> V3 {
        let y = sqrt(min(max(h, 0), 100) / 100) * Double(rows - 1), x = (min(max(mu, -1), 1) + 1) / 2 * Double(w - 1)
        let (x0, y0) = (min(Int(x), w - 2), min(Int(y), rows - 2))
        let (fx, fy) = (x - Double(x0), y - Double(y0))
        let a = table[y0 * w + x0] * (1 - fx) + table[y0 * w + x0 + 1] * fx
        let b = table[(y0 + 1) * w + x0] * (1 - fx) + table[(y0 + 1) * w + x0 + 1] * fx
        return a * (1 - fy) + b * fy
    }
    func sunlight(_ h: Double, _ mu: Double) -> V3 { Self.lookup(transmittance, 256, 64, h, mu) }
    private static func multipleScattering(_ h: Double, _ muS: Double, _ table: [V3]) -> V3 {
        let r = ground + h, sun = V3(sqrt(max(0, 1 - muS * muS)), 0, muS), n = 64
        var light = V3.zero, fms = V3.zero
        for i in 0..<n {
            let z = 1 - (Double(i) + 0.5) / Double(n) * 2, a = Double(i) * 2.39996
            let dir = V3(sqrt(1 - z * z) * cos(a), sqrt(1 - z * z) * sin(a), z)
            let down = hitsGround(r, z)
            let len = down ? distanceToGround(r, z) : distanceToTop(r, z)
            let steps = 20, dt = len / Double(steps)
            var through = V3(1, 1, 1)
            for k in 0..<steps {
                let p = V3(0, 0, r) + dir * ((Double(k) + 0.5) * dt)
                let rr = length(p), hh = rr - ground
                let ext = extinction(hh), scatter = rayleigh * exp(-hh / 8) + V3(repeating: mieScatter * exp(-hh / 1.2))
                let step = exp(-ext * dt), integral = (V3(1, 1, 1) - step) / ext
                light += through * scatter * lookup(table, 256, 64, hh, dot(p / rr, sun)) / (4 * .pi) * integral
                fms += through * scatter * integral
                through *= step
            }
            if down { light += through * lookup(table, 256, 64, 0, muS) * max(muS, 0) * 0.3 / .pi }
        }
        return light / Double(n) / (V3(1, 1, 1) - fms / Double(n))
    }
    func march(h0: Double, dir: V3, lights: [(V3, Double)], far: Double = .infinity, steps: Int = 32) -> (light: V3, through: V3) {
        let r = Self.ground + h0, mu = dir.z
        let len = min(Self.hitsGround(r, mu) ? Self.distanceToGround(r, mu) : Self.distanceToTop(r, mu), far)
        var through = V3(1, 1, 1), light = V3.zero, t0 = 0.0
        for k in 0..<steps {
            let t1 = len * pow(Double(k + 1) / Double(steps), 2)
            let dt = t1 - t0, p = V3(0, 0, r) + dir * ((t0 + t1) / 2)
            t0 = t1
            let rr = length(p), hh = rr - Self.ground, up = p / rr
            let ext = Self.extinction(hh)
            let sr = Self.rayleigh * exp(-hh / 8), sm = Self.mieScatter * exp(-hh / 1.2)
            let step = exp(-ext * dt), integral = (V3(1, 1, 1) - step) / ext
            var scattered = V3.zero
            for (l, strength) in lights where strength > 0 {
                let c = dot(dir, l), muS = dot(up, l), g = 0.8
                let rayleighPhase = 3 / (16 * Double.pi) * (1 + c * c)
                let miePhase = 3 / (8 * Double.pi) * (1 - g * g) * (1 + c * c) / ((2 + g * g) * pow(1 + g * g - 2 * g * c, 1.5))
                scattered += ((sr * rayleighPhase + V3(repeating: sm * miePhase)) * sunlight(hh, muS)
                              + (sr + V3(repeating: sm)) * Self.lookup(multiple, 32, 32, hh, muS)) * strength
            }
            light += through * scattered * integral
            through *= step
        }
        return (light, through)
    }
}

typealias V3 = SIMD3<Double>
/// The Sun's direction (east, north, up) for a day of the year and a local solar hour: declination from the day, hour
/// angle from the hour (Cooper's formula, good to about half a degree; the app would use `Sky.sun`).
func sunDirection(day: Double, hour: Double, lat: Double) -> V3 {
    let dec = 23.44 * .pi / 180 * sin(2 * .pi * (284 + day) / 365), ha = (hour - 12) * 15 * .pi / 180, phi = lat * .pi / 180
    let up = sin(phi) * sin(dec) + cos(phi) * cos(dec) * cos(ha)
    let east = -cos(dec) * sin(ha)
    let north = cos(phi) * sin(dec) - sin(phi) * cos(dec) * cos(ha)
    return normalize(V3(east, north, up))
}
/// The zenith camera: a point of the screen (u, v from 0 to 1, v up) to a direction. Screen up is north and screen
/// right west, as the sky is seen lying on your back with your head to the north.
func ray(_ u: Double, _ v: Double) -> V3 { normalize(V3(-(u * 2 - 1) * tanH, (v * 2 - 1) * tanV, 1)) }
func screen(_ d: V3) -> SIMD2<Double> { SIMD2(0.5 - d.x / d.z / tanH / 2, 0.5 + d.y / d.z / tanV / 2) }

let lat = cfg.lat ?? 42
var day = cfg.day ?? 196, hour = cfg.hour ?? 15
let overcast = cfg.overcast ?? false

// MARK: - The stand: a looking-up HDRI's zenith, keyed (methods a and c)

/// The HDRI reprojected through the zenith camera at the layers' size (screen plus margin), linear RGB.
func zenithView(_ path: String) -> [SIMD3<Float>] {
    let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)!
    let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
    let (ew, eh) = (img.width, img.height)
    var eq = [Float](repeating: 0, count: ew * eh * 4)
    let ctx = CGContext(data: &eq, width: ew, height: eh, bitsPerComponent: 32, bytesPerRow: ew * 16,
                        space: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.floatComponents.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: ew, height: eh))
    let rot = (cfg.rot ?? 0) * .pi / 180, flip = (cfg.mirror ?? false) ? -1.0 : 1.0
    var out = [SIMD3<Float>](repeating: .zero, count: LW * LH)
    out.withUnsafeMutableBufferPointer { O in
        nonisolated(unsafe) let O = O
        eq.withUnsafeBufferPointer { E in
            nonisolated(unsafe) let E = E
            DispatchQueue.concurrentPerform(iterations: LH) { j in
                for i in 0..<LW {
                    // a layer pixel to the screen's uv (the layer is the screen plus margin, centred)
                    let u = ((Double(i) + 0.5) / Double(LW) - 0.5) * margin + 0.5, v = ((Double(j) + 0.5) / Double(LH) - 0.5) * margin + 0.5
                    var d = ray(u, 1 - v)
                    d = V3((d.x * cos(rot) - d.y * sin(rot)) * flip, d.x * sin(rot) + d.y * cos(rot), d.z)
                    let lon = atan2(d.y, d.x), la = asin(min(d.z, 1))
                    let x = (lon / (2 * .pi) + 0.5) * Double(ew) - 0.5, y = (0.5 - la / .pi) * Double(eh) - 0.5
                    let x0 = Int(floor(x)), y0 = max(Int(floor(y)), 0), fx = Float(x - floor(x)), fy = Float(y - floor(y))
                    func px(_ a: Int, _ b: Int) -> SIMD3<Float> {
                        let k = (min(b, eh - 1) * ew + ((a % ew) + ew) % ew) * 4
                        return SIMD3(E[k], E[k + 1], E[k + 2])
                    }
                    O[j * LW + i] = (px(x0, y0) * (1 - fx) + px(x0 + 1, y0) * fx) * (1 - fy) + (px(x0, y0 + 1) * (1 - fx) + px(x0 + 1, y0 + 1) * fx) * fy
                }
            }
        }
    }
    return out // row 0 is the top of the screen
}

/// The wood or canopy keyed from its sky: coverage by unmixing each pixel between the local sky and the dark wood
/// (twigs thinner than a pixel come out as the share of the pixel they cover), with green leaves kept by their hue;
/// their colour as a share of the sky's brightness; and how leafy each pixel is, for (a)'s autumn.
struct Stand { var matte: [Float], colour: [SIMD3<Float>], leafy: [Float], skyLevel: Float }
func key(_ view: [SIMD3<Float>]) -> Stand {
    let n = LW * LH
    let Y = view.map { 0.2126 * $0.x + 0.7152 * $0.y + 0.0722 * $0.z }
    // The sky's level, block by block (its brightest few percent), filled in where no sky shows, then smoothed.
    let B = 48, bw = (LW + B - 1) / B, bh = (LH + B - 1) / B
    var sky = [Float](repeating: -1, count: bw * bh)
    for by in 0..<bh { for bx in 0..<bw {
        var vals: [Float] = []
        for y in stride(from: by * B, to: min(by * B + B, LH), by: 2) { for x in stride(from: bx * B, to: min(bx * B + B, LW), by: 2) { vals.append(Y[y * LW + x]) } }
        vals.sort()
        sky[by * bw + bx] = vals[Int(Double(vals.count - 1) * 0.97)]
    } }
    let sorted = Y.sorted(), global = sorted[Int(Double(n - 1) * 0.97)], dark = sorted[Int(Double(n - 1) * 0.03)]
    for i in sky.indices where sky[i] < global * 0.7 { sky[i] = -1 } // a block of dense twigs is not sky
    for _ in 0..<200 where sky.contains(-1) { // grow the known blocks into the closed ones
        let old = sky
        for by in 0..<bh { for bx in 0..<bw where old[by * bw + bx] < 0 {
            var s: Float = 0, c: Float = 0
            for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                let x = bx + dx, y = by + dy
                if x >= 0, y >= 0, x < bw, y < bh, old[y * bw + x] >= 0 { s += old[y * bw + x]; c += 1 }
            }
            if c > 0 { sky[by * bw + bx] = s / c }
        } }
    }
    boxBlur(&sky, bw, bh, 1)
    var matte = [Float](repeating: 0, count: n), colour = [SIMD3<Float>](repeating: .zero, count: n), leafy = [Float](repeating: 0, count: n)
    // the sky's own colour, for the hue test
    var skyRGB = SIMD3<Float>.zero, cnt: Float = 0
    for i in stride(from: 0, to: n, by: 7) where Y[i] > global * 0.8 { skyRGB += view[i]; cnt += 1 }
    skyRGB /= max(cnt, 1)
    let skyGB = skyRGB.y / max(skyRGB.z, 1e-4)
    for j in 0..<LH { for i in 0..<LW {
        let k = j * LW + i
        let fx = (Float(i) + 0.5) / Float(B) - 0.5, fy = (Float(j) + 0.5) / Float(B) - 0.5
        let x0 = min(max(Int(floor(fx)), 0), bw - 1), y0 = min(max(Int(floor(fy)), 0), bh - 1)
        let x1 = min(x0 + 1, bw - 1), y1 = min(y0 + 1, bh - 1), ax = min(max(fx - Float(x0), 0), 1), ay = min(max(fy - Float(y0), 0), 1)
        let S = (sky[y0 * bw + x0] * (1 - ax) + sky[y0 * bw + x1] * ax) * (1 - ay) + (sky[y1 * bw + x0] * (1 - ax) + sky[y1 * bw + x1] * ax) * ay
        let p = view[k]
        var m = min(max((S - Y[k]) / max(S - dark, 1e-4), 0), 1)
        if Y[k] > 2.5 * S { m = 0 } // the Sun and its flare are sky
        // green against the sky's blue or grey: a leaf however brightly it's lit
        let gb = p.y / max(p.z, 1e-4)
        let green = min(max((gb / skyGB - 1.15) / 0.5, 0), 1)
        m = max(m, green * min(Y[k] / max(S * 0.05, 1e-5), 1))
        matte[k] = m
        let fg = m > 0.02 ? (p - (1 - m) * (S / max(lum3(skyRGB), 1e-5)) * skyRGB) / m : .zero
        var c = simd_max(fg, .zero) / global
        if lum3(c) > 0.9 { c *= 0.9 / lum3(c) }
        if c.x > c.y * 1.25 { c = SIMD3(repeating: lum3(c)) } // unmixed next to the photo's bright Sun: not a real red
        colour[k] = m < 0.3 ? c * (m / 0.3) + SIMD3<Float>(0.03, 0.03, 0.025) * (1 - m / 0.3) : c
        leafy[k] = green
    } }
    return Stand(matte: matte, colour: colour, leafy: leafy, skyLevel: global)
}
func lum3(_ v: SIMD3<Float>) -> Float { 0.2126 * v.x + 0.7152 * v.y + 0.0722 * v.z }

// MARK: - The stand laid out by code (method b)

/// Trees in a ring round a small gap, each a trunk running in from the screen's edge and a crown of limbs splitting
/// into twigs, in metres, projected through the lens and drawn as lines as wide as they are (fainter when thinner
/// than a pixel). Sizes from the method research: 20-26 m tall, crowns 7-9 m wide from 60% of the height, 5-6 m apart.
func builtStand() -> Stand {
    let cs = CGColorSpaceCreateDeviceGray()
    let ctx = CGContext(data: nil, width: LW, height: LH, bitsPerComponent: 8, bytesPerRow: LW, space: cs, bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    ctx.setFillColor(gray: 0, alpha: 1); ctx.fill(CGRect(x: 0, y: 0, width: LW, height: LH))
    ctx.setStrokeColor(gray: 1, alpha: 1); ctx.setLineCap(.round)
    var r = Rand(s: (cfg.seed ?? 3) &+ 77)
    func project(_ p: V3) -> CGPoint? {
        guard p.z > 0.5 else { return nil }
        // layer pixels, y up as CG draws: the screen's centre at the layer's
        return CGPoint(x: Double(LW) / 2 - p.x / p.z * focal, y: Double(LH) / 2 + p.y / p.z * focal)
    }
    func line(_ a: V3, _ b: V3, _ w0: Double, _ w1: Double) {
        let steps = 6
        for s in 0..<steps {
            let t0 = Double(s) / Double(steps), t1 = Double(s + 1) / Double(steps)
            let p = a + (b - a) * t0, q = a + (b - a) * t1
            guard let P = project(p), let Q = project(q) else { continue }
            let w = (w0 + (w1 - w0) * (t0 + t1) / 2) * focal / ((p.z + q.z) / 2)
            ctx.setLineWidth(max(w, 1)); ctx.setStrokeColor(gray: 1, alpha: min(w, 1))
            ctx.move(to: P); ctx.addLine(to: Q); ctx.strokePath()
        }
    }
    func limb(_ from: V3, _ dir: V3, _ len: Double, _ w: Double, _ depth: Int) {
        let mid = from + dir * len * 0.5 + V3(r.r(-0.15, 0.15), r.r(-0.15, 0.15), r.r(-0.05, 0.1)) * len
        let end = mid + normalize(dir + V3(r.r(-0.3, 0.3), r.r(-0.3, 0.3), r.r(0, 0.3))) * len * 0.5
        line(from, mid, w, w * 0.85); line(mid, end, w * 0.85, w * 0.7)
        guard depth < 6, len > 0.2 else { return }
        for _ in 0..<(depth < 3 ? 3 : 2) {
            var d = dir + V3(r.r(-0.8, 0.8), r.r(-0.8, 0.8), r.r(-0.2, 0.6))
            d = normalize(d)
            limb(end - dir * len * r.r(0, 0.4), d, len * r.r(0.55, 0.75), w * 0.6, depth + 1)
        }
    }
    let n = cfg.trees ?? 18, gap = cfg.gap ?? 6.5
    for k in 0..<n {
        let a = (Double(k) + r.r(-0.35, 0.35)) / Double(n) * 2 * .pi, d = gap + r.r(0, 9) * (k % 3 == 0 ? 1.3 : 1)
        if let side = cfg.clearSide, cos(a - side * .pi / 180) > 0.2 { continue }
        let base = V3(cos(a) * d, sin(a) * d, 0), height = r.r(20, 26), crownBase = height * r.r(0.55, 0.65)
        let dbh = r.r(0.3, 0.45)
        line(base + V3(0, 0, 1), base + V3(0, 0, crownBase), dbh, dbh * 0.75)
        let lean = V3(r.r(-0.3, 0.3), r.r(-0.3, 0.3), 1)
        line(base + V3(0, 0, crownBase), base + normalize(lean) * height, dbh * 0.75, 0.05)
        for l in 0..<Int(r.r(8, 12)) {
            let h = crownBase + (height - crownBase) * Double(l) / 8 * r.r(0.8, 1.1), az = r.r(0, 2 * .pi)
            let dir = normalize(V3(cos(az), sin(az), r.r(0.5, 1.4)))
            limb(base + V3(0, 0, h), dir, r.r(2.0, 3.4) * (1 - 0.4 * Double(l) / 8), dbh * 0.35, 0)
        }
    }
    let data = ctx.data!.assumingMemoryBound(to: UInt8.self)
    var matte = [Float](repeating: 0, count: LW * LH)
    for j in 0..<LH { for i in 0..<LW { matte[j * LW + i] = Float(data[j * LW + i]) / 255 } } // a bitmap's first row is its top
    // bark: the look research's branch colours (#21150D) as a share of its gap sky (#6E8BB8)
    let bark = SIMD3<Float>(lin(0x21150D).map { $0 / lum(lin(0x6E8BB8)) }.x.f, lin(0x21150D).map { $0 / lum(lin(0x6E8BB8)) }.y.f, lin(0x21150D).map { $0 / lum(lin(0x6E8BB8)) }.z.f)
    return Stand(matte: matte, colour: [SIMD3<Float>](repeating: bark, count: LW * LH), leafy: [Float](repeating: 0, count: LW * LH), skyLevel: 1)
}
extension Double { var f: Float { Float(self) } }


// MARK: - Which tree each pixel belongs to, for the sway

/// Floods each trunk's label along the wood from where it enters at the screen's edge (a run of wood along the
/// border), nearest first, then gives every other pixel the label of the wood nearest it. Returns labels and how far
/// along the wood each pixel is from its trunk's entry (0 at the edge), at half the layers' resolution, and each
/// label's entry angle round the centre.
func label(_ matte: [Float]) -> (labels: [Int32], dist: [Float], angle: [Double], w: Int, h: Int) {
    let w = LW / 2, h = LH / 2
    var m = [Float](repeating: 0, count: w * h)
    for j in 0..<h { for i in 0..<w { m[j * w + i] = max(max(matte[(2 * j) * LW + 2 * i], matte[(2 * j) * LW + 2 * i + 1]), max(matte[(2 * j + 1) * LW + 2 * i], matte[(2 * j + 1) * LW + 2 * i + 1])) } }
    var labels = [Int32](repeating: -1, count: w * h), dist = [Float](repeating: .infinity, count: w * h)
    // the border, walked clockwise from the top-left corner
    var border: [Int] = []
    for i in 0..<w { border.append(i) }
    for j in 1..<h { border.append(j * w + w - 1) }
    for i in stride(from: w - 2, through: 0, by: -1) { border.append((h - 1) * w + i) }
    for j in stride(from: h - 2, through: 1, by: -1) { border.append(j * w) }
    var queue: [Int] = [], angle: [Double] = []
    var run = -1, inside = false
    for k in border {
        if m[k] > 0.5 {
            if !inside { run += 1; inside = true
                let (i, j) = (k % w, k / w); angle.append(atan2(Double(h / 2 - j), Double(i - w / 2))) }
            labels[k] = Int32(run); dist[k] = 0; queue.append(k)
        } else { inside = false }
    }
    // breadth first along the wood (8-connected), so each pixel goes to the trunk that reaches it soonest
    var head = 0
    while head < queue.count {
        let k = queue[head]; head += 1
        let (i, j) = (k % w, k / w)
        for dj in -1...1 { for di in -1...1 where di != 0 || dj != 0 {
            let x = i + di, y = j + dj
            guard x >= 0, y >= 0, x < w, y < h else { continue }
            let n = y * w + x
            if labels[n] < 0 && m[n] > 0.08 { labels[n] = labels[k]; dist[n] = dist[k] + 1; queue.append(n) }
        } }
    }
    // everything else from the nearest labelled pixel
    queue = (0..<(w * h)).filter { labels[$0] >= 0 }; head = 0
    while head < queue.count {
        let k = queue[head]; head += 1
        let (i, j) = (k % w, k / w)
        for (di, dj) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
            let x = i + di, y = j + dj
            guard x >= 0, y >= 0, x < w, y < h else { continue }
            let n = y * w + x
            if labels[n] < 0 { labels[n] = max(labels[k], 0); dist[n] = dist[k]; queue.append(n) }
        }
    }
    for k in labels.indices where labels[k] < 0 { labels[k] = 0; dist[k] = 1e4 }
    return (labels, dist, angle, w, h)
}

// MARK: - Leaves grown on the twigs (methods b and c)

let atlas = NSImage(contentsOfFile: repo + "/Sources/Atrium/Resources/dappled-leaves.png")!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let cells = (0..<16).map { atlas.cropping(to: CGRect(x: $0 % 4 * 256, y: $0 / 4 * 256, width: 256, height: 256))! }
let palette = cfg.palette ?? "summer"
let species: [Int] = palette == "aspen" ? Array(10..<16) : Array(0..<16) // aspen: the round beech-like shapes (no aspen scan)

/// A spray: a twig with 9-13 leaves from the scanned atlas, white on black, 96 px.
func spray(_ r: inout Rand) -> CGImage {
    let n = 96
    let c = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    c.setStrokeColor(gray: 0.35, alpha: 1); c.setLineWidth(1.2)
    let a0 = r.r(0, 2 * .pi)
    let base = CGPoint(x: 48 - cos(a0) * 36, y: 48 - sin(a0) * 36)
    c.move(to: base); c.addLine(to: CGPoint(x: 48 + cos(a0) * 36, y: 48 + sin(a0) * 36)); c.strokePath()
    for k in 0..<Int(r.r(9, 13)) {
        let t = Double(k) / 12, side: Double = k % 2 == 0 ? 1 : -1
        let p = CGPoint(x: base.x + cos(a0) * 72 * t, y: base.y + sin(a0) * 72 * t)
        let len = r.r(16, 24) * (palette == "aspen" ? 0.8 : 1)
        c.saveGState(); c.translateBy(x: p.x, y: p.y); c.rotate(by: a0 + side * r.r(0.5, 1.1) - .pi / 2)
        c.draw(cells[species[Int(r.next() * Double(species.count))]], in: CGRect(x: -len / 2, y: -len * 0.03, width: len, height: len))
        c.restoreGState()
    }
    return c.makeImage()!
}

struct Layers { var cov: [[Float]], id: [[Float]], bakeMs: Double, sprays: Int }
/// Grows three layers of sprays where the wood is twiggy: twigs are the matte's thin parts (fine twigs come out of the
/// key as a haze of part-covered pixels), the leaves fill round them, and the trunks, limbs and the evergreens' dense
/// masses grow none. Nearer (lower) layers have bigger sprays on screen.
func grow(_ matte: [Float]) -> Layers {
    let t0 = DispatchTime.now().uptimeNanoseconds
    let w = LW / 2, h = LH / 2, closed = cfg.closed ?? 0
    var m = [Float](repeating: 0, count: w * h)
    for j in 0..<h { for i in 0..<w { m[j * w + i] = 0.25 * (matte[(2 * j) * LW + 2 * i] + matte[(2 * j) * LW + 2 * i + 1] + matte[(2 * j + 1) * LW + 2 * i] + matte[(2 * j + 1) * LW + 2 * i + 1]) } }
    var thick = m.map { $0 > 0.85 ? Float(1) : 0 } // trunks and limbs are solid; a mass of twigs is a part-covered haze
    boxBlur(&thick, w, h, 5)
    var dens = [Float](repeating: 0, count: w * h)
    for k in 0..<(w * h) where m[k] > 0.03 { dens[k] = min(m[k] * 2.5, 1) * (1 - min(max((thick[k] - 0.72) / 0.2, 0), 1)) } // fine twigs key as a faint haze
    boxBlur(&dens, w, h, Int(5 * (1 + 2 * closed)), passes: 3)
    let top = dens.sorted()[Int(Double(w * h - 1) * 0.98)]
    for k in dens.indices { dens[k] = min(dens[k] / max(top, 1e-6), 1) }
    let n = Int(Double(cfg.sprays ?? 9000) * (1 + closed))
    var r = Rand(s: (cfg.seed ?? 3) &+ 11)
    let stamps = (0..<24).map { _ in spray(&r) }
    var cov = [[Float]](repeating: [], count: 3), ids = [[Float]](repeating: [], count: 3)
    let sizes = [62.0, 48.0, 38.0].map { $0 * (cfg.leafScale ?? 1) * (1 + 0.3 * closed) }
    DispatchQueue.concurrentPerform(iterations: 3) { li in
        var r = Rand(s: UInt64(100 + li) &+ (cfg.seed ?? 3))
        let ctx = CGContext(data: nil, width: LW, height: LH, bitsPerComponent: 8, bytesPerRow: LW * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        // clumps of sprays round points on the twigs, as a crown's leaves gather, with sky between the clumps
        var placed = 0, tries = 0
        let clump = sizes[li] * 0.9
        while placed < n && tries < n * 60 {
            tries += 1
            let cx = r.next(), cy = r.next()
            let d = Double(dens[min(Int(cy * Double(h)), h - 1) * w + min(Int(cx * Double(w)), w - 1)])
            if r.next() > min(max((d - 0.12 + 0.1 * closed) / 0.45, 0), 1) { continue }
            for _ in 0..<Int(r.r(4, 10)) {
                let a = r.r(0, 2 * .pi), rr = clump * sqrt(r.next())
                let x = cx + cos(a) * rr / Double(LW), y = cy + sin(a) * rr / Double(LH)
                guard x > 0, y > 0, x < 1, y < 1, dens[min(Int(y * Double(h)), h - 1) * w + min(Int(x * Double(w)), w - 1)] > 0.05 else { continue }
                placed += 1
                let s = sizes[li] * r.r(0.8, 1.2)
                ctx.saveGState()
                ctx.translateBy(x: x * Double(LW), y: (1 - y) * Double(LH)); ctx.rotate(by: r.r(0, 2 * .pi))
                let rect = CGRect(x: -s / 2, y: -s / 2, width: s, height: s)
                ctx.clip(to: rect, mask: stamps[Int(r.next() * 24)])
                ctx.setFillColor(red: r.r(0.01, 1), green: 0, blue: 0, alpha: 1)
                ctx.fill(rect)
                ctx.restoreGState()
            }
        }
        let px = ctx.data!.assumingMemoryBound(to: UInt8.self)
        var c = [Float](repeating: 0, count: LW * LH), id = [Float](repeating: 0, count: LW * LH)
        for j in 0..<LH { for i in 0..<LW { // CG's row 0 is the top in memory for a bitmap context
            let k = (j * LW + i) * 4, a = Float(px[k + 3]) / 255
            c[j * LW + i] = a; id[j * LW + i] = a > 0 ? min(Float(px[k]) / 255 / a, 1) : 0
        } }
        boxBlur(&c, LW, LH, 1 + (cfg.soft ?? 0), passes: 1 + (cfg.soft ?? 0 > 0 ? 1 : 0)) // pre-blurred by a texel against crawling edges, or a few: the eye's focus is on the sky
        cov[li] = c; ids[li] = id
    }
    return Layers(cov: cov, id: ids, bakeMs: ms(t0), sprays: n)
}

// MARK: - Build the stand

if cfg.zenith == true { // the HDRI's zenith as a camera shows it (metered on the frame, clipped): the reference sheet
    let v = zenithView(cfg.hdri!)
    let mean = v.reduce(Float(0)) { $0 + lum3($1) } / Float(v.count), k = 0.18 / mean
    let (w, h, x0, y0) = (W / 2, H / 2, (LW - W) / 2, (LH - H) / 2)
    var px = [UInt8](repeating: 255, count: w * h * 4)
    for j in 0..<h { for i in 0..<w { for c in 0..<3 {
        var s: Float = 0
        for dj in 0..<2 { for di in 0..<2 { s += v[(y0 + 2 * j + dj) * LW + x0 + 2 * i + di][c] } }
        px[(j * w + i) * 4 + c] = UInt8(min(pow(max(s / 4 * k, 0), 1 / 2.2), 1) * 255)
    } } }
    writePNG(px, w, h, cfg.out)
    print("STATS {}")
    exit(0)
}

let tPrep = DispatchTime.now().uptimeNanoseconds
var stand: Stand = method == "built" ? builtStand() : key(zenithView(cfg.hdri!))
if let r = cfg.soft, r > 0 { boxBlur(&stand.matte, LW, LH, r) }
let prepMs = ms(tPrep)
var lab = label(stand.matte)
if let side = cfg.clearSide { // a forest edge: the trees whose trunks enter on one side are gone
    let gone = Set(lab.angle.indices.filter { cos(lab.angle[$0] - side * .pi / 180) > 0.25 }.map { Int32($0) })
    // ragged, as crowns end: the label read a wandering 0-80 px off
    func at(_ i: Int, _ j: Int) -> Int {
        let x = Double(i), y = Double(j)
        let dx = 40 * (sin(x * 0.011 + y * 0.007) + 0.6 * sin(x * 0.031 - y * 0.023 + 1.3)), dy = 40 * (sin(y * 0.013 - x * 0.006 + 2.1) + 0.6 * sin(y * 0.029 + x * 0.027))
        let ii = min(max(Int(x + dx), 0), LW - 1), jj = min(max(Int(y + dy), 0), LH - 1)
        return (jj / 2) * lab.w + ii / 2
    }
    for j in 0..<LH { for i in 0..<LW where gone.contains(lab.labels[at(i, j)]) && lab.dist[(j / 2) * lab.w + i / 2] < 1e4 {
        stand.matte[j * LW + i] = 0
    } }
}
let layers: Layers? = method == "photo" ? nil : grow(stand.matte)

// MARK: - The sky and the light

let air = Atmosphere.shared
if cfg.sunBehind == true, let L = layers { // the solar hour near noon when the Sun stands behind the thick of a crown
    var best = (score: 1e9, hour: 12.0)
    for hh in stride(from: 10.5, through: 13.5, by: 0.05) {
        let s = screen(sunDirection(day: day, hour: hh, lat: lat))
        guard s.x > 0.05, s.x < 0.95, s.y > 0.05, s.y < 0.95 else { continue }
        var c: Float = 0, cnt: Float = 0
        for dj in stride(from: -40, through: 40, by: 8) { for di in stride(from: -40, through: 40, by: 8) {
            let i = Int(((s.x - 0.5) / margin + 0.5) * Double(LW)) + di, j = Int(((0.5 - s.y) / margin + 0.5) * Double(LH)) + dj
            guard i >= 0, j >= 0, i < LW, j < LH else { continue }
            c += 1 - (1 - L.cov[0][j * LW + i]) * (1 - L.cov[1][j * LW + i]) * (1 - L.cov[2][j * LW + i]); cnt += 1
        } }
        let score = abs(Double(c / max(cnt, 1)) - 0.8)
        if score < best.score { best = (score, hh) }
    }
    hour = best.hour
}
let sun = sunDirection(day: day, hour: hour, lat: lat)
let sunUV = screen(sun)
// Radiance per unit of solar irradiance (the Atmosphere's units), normalised so the zenith's brightest channel is 1.
let zenithRaw = air.march(h0: 0.3, dir: V3(0, 0, 1), lights: [(sun, 1)]).light
let direct = air.sunlight(0.3, sun.z) * max(sun.z, 0)                 // on a level surface
var diffuse = V3.zero                                                    // skylight on a level surface
for i in 0..<128 {
    let z = 1 - (Double(i) + 0.5) / 128, a = Double(i) * 2.39996, d = V3(sqrt(1 - z * z) * cos(a), sqrt(1 - z * z) * sin(a), z)
    diffuse += air.march(h0: 0.3, dir: d, lights: [(sun, 1)], steps: 12).light * z * (2 * .pi / 128)
}
let ocSky = lin(0xACB4C6) / lum(lin(0xACB4C6)) // overcast silver, the look research's sample
let norm = overcast ? 1.0 : 1 / max(zenithRaw.max(), 1e-9)
let zenith = overcast ? ocSky * 0.62 : zenithRaw * norm
// leaves: lit through by the beam on leaves at all angles (half their area faces it on average) and by the sky
let sunE = overcast ? V3.zero : air.sunlight(0.3, sun.z) * (sun.z > 0 ? 0.5 : 0) * norm / .pi
let ambE = overcast ? zenith : diffuse * norm / .pi
let skyPx: [UInt8] = {
    var px = [UInt8](repeating: 255, count: 128 * 96 * 4)
    for j in 0..<96 { for i in 0..<128 { // row 0 at the bottom, as SKTexture(data:) reads it
        let l = overcast ? zenith * (0.92 + 0.08 * Double(j) / 96) : air.march(h0: 0.3, dir: ray((Double(i) + 0.5) / 128, (Double(j) + 0.5) / 96), lights: [(sun, 1)]).light * norm
        for c in 0..<3 { px[(j * 128 + i) * 4 + c] = UInt8(min(sqrt(max(l[c], 0) / 8), 1) * 255) }
    } }
    return px
}()
func texture(_ bytes: [UInt8], _ w: Int, _ h: Int) -> SKTexture {
    let t = SKTexture(data: Data(bytes), size: CGSize(width: w, height: h))
    t.filteringMode = .linear
    return t
}

// MARK: - Textures for the shader (rows bottom first)

let tPack = DispatchTime.now().uptimeNanoseconds
func pack(_ f: (Int) -> (Float, Float, Float, Float)) -> [UInt8] {
    var out = [UInt8](repeating: 0, count: LW * LH * 4)
    out.withUnsafeMutableBufferPointer { O in
        nonisolated(unsafe) let O = O
        DispatchQueue.concurrentPerform(iterations: LH) { j in
            for i in 0..<LW {
                let v = f((LH - 1 - j) * LW + i), o = (j * LW + i) * 4
                O[o] = UInt8(min(max(v.0, 0), 1) * 255); O[o + 1] = UInt8(min(max(v.1, 0), 1) * 255)
                O[o + 2] = UInt8(min(max(v.2, 0), 1) * 255); O[o + 3] = UInt8(min(max(v.3, 0), 1) * 255)
            }
        }
    }
    return out
}
let woodTex = texture(pack { k in let c = stand.colour[k]; return (sqrt(c.x / 2), sqrt(c.y / 2), sqrt(c.z / 2), stand.matte[k]) }, LW, LH)
let noLeaves = [Float](repeating: 0, count: LW * LH)
let L0 = layers?.cov[0] ?? noLeaves, L1 = layers?.cov[1] ?? noLeaves, L2 = layers?.cov[2] ?? noLeaves
let I0 = layers?.id[0] ?? noLeaves, I1 = layers?.id[1] ?? noLeaves, I2 = layers?.id[2] ?? noLeaves
let texA = texture(pack { k in (L0[k], I0[k], L1[k], I1[k]) }, LW, LH)
// how solid the wood is round each pixel (trunks and limbs near 1, twigs low): a birch's white bark is on its trunks
let thick: [Float] = { var m = stand.matte; boxBlur(&m, LW, LH, 10); return m }()
let texB = texture(pack { k in (L2[k], I2[k], stand.leafy[k], thick[k]) }, LW, LH)
// coverage at an eighth of the resolution, blurred: the light from above and the veil read it
let (aw, ah) = (LW / 8, LH / 8)
func eighth(_ a: [Float], blur: Int) -> [Float] {
    var o = [Float](repeating: 0, count: aw * ah)
    for j in 0..<ah { for i in 0..<aw {
        var s: Float = 0
        for dj in stride(from: 0, to: 8, by: 2) { for di in stride(from: 0, to: 8, by: 2) { s += a[(j * 8 + dj) * LW + i * 8 + di] } }
        o[j * aw + i] = s / 16
    } }
    boxBlur(&o, aw, ah, blur)
    return o
}
let fallen = cfg.fallen ?? 0
func present(_ c: [Float], _ id: [Float]) -> [Float] { zip(c, id).map { $1 >= Float(fallen) ? $0 : 0 } }
let P0 = present(L0, I0), P1 = present(L1, I1), P2 = present(L2, I2)
let A0 = eighth(P0, blur: 2), A1 = eighth(P1, blur: 2), A2 = eighth(P2, blur: 2), AW = eighth(stand.matte, blur: 2)
func packSmall(_ a: [Float], _ b: [Float], _ c: [Float], _ d: [Float]) -> [UInt8] {
    var o = [UInt8](repeating: 0, count: aw * ah * 4)
    for j in 0..<ah { for i in 0..<aw {
        let k = (ah - 1 - j) * aw + i, q = (j * aw + i) * 4
        o[q] = UInt8(min(a[k], 1) * 255); o[q + 1] = UInt8(min(b[k], 1) * 255); o[q + 2] = UInt8(min(c[k], 1) * 255); o[q + 3] = UInt8(min(d[k], 1) * 255)
    } }
    return o
}
let aboveTex = texture(packSmall(A0, A1, A2, AW), aw, ah)
// four sway groups: each label's group, weighted by how far up its tree the pixel is (trunks near the edge barely move)
var groups = [[Float]](repeating: [Float](repeating: 0, count: aw * ah), count: 4)
for j in 0..<ah { for i in 0..<aw {
    var g: [Float] = [0, 0, 0, 0]
    for dj in 0..<4 { for di in 0..<4 {
        let k = min(j * 4 + dj, lab.h - 1) * lab.w + min(i * 4 + di, lab.w - 1)
        g[Int(lab.labels[k]) % 4] += min(lab.dist[k] / 350, 1) / 16
    } }
    for c in 0..<4 { groups[c][j * aw + i] = g[c] }
} }
for c in 0..<4 { boxBlur(&groups[c], aw, ah, 3) }
let swayTex = texture(packSmall(groups[0], groups[1], groups[2], groups[3]), aw, ah)
let packMs = ms(tPack)

// The share of the screen that is sky (less than half covered), from the bake.
let skyShare: Double = {
    var s = 0, n = 0
    for j in stride(from: Int(Double(LH) * 0.0455), to: Int(Double(LH) * 0.9545), by: 4) { for i in stride(from: Int(Double(LW) * 0.0455), to: Int(Double(LW) * 0.9545), by: 4) {
        let k = j * LW + i
        var c = 1 - (1 - P0[k]) * (1 - P1[k]) * (1 - P2[k]) * (1 - stand.matte[k])
        if method == "photo" { c = stand.matte[k] * (1 - stand.leafy[k] * (fallen > 0 ? Float(fallen) : 0)) }
        if c < 0.5 { s += 1 }; n += 1
    } }
    return Double(s) / Double(n)
}()
// How much of the Sun shows through the canopy where it stands (the build would ease this over seconds).
let sunVis: Double = {
    guard !overcast, sun.z > 0, sunUV.x > -0.05, sunUV.x < 1.05, sunUV.y > -0.05, sunUV.y < 1.05 else { return 0 }
    let i = min(max(Int(((sunUV.x - 0.5) / margin + 0.5) * Double(aw)), 0), aw - 1), j = min(max(Int(((0.5 - sunUV.y) / margin + 0.5) * Double(ah)), 0), ah - 1)
    let k = j * aw + i
    return Double((1 - A0[k]) * (1 - A1[k]) * (1 - A2[k]) * (1 - AW[k]))
}()

// MARK: - The shader: sky, three leaf layers and the wood, lit through each other, in one pass

func hue(_ hex: Int) -> V3 { let c = lin(hex); return c / lum(c) }
let trans = cfg.trans ?? 0.08 // a leaf passes about 5-15% of the light on its top side (method research §2)
let autumnHues: [Int] = palette == "aspen" ? [0xA5882C, 0xBE9C42, 0xD1B158, 0xC88B3F, 0x9D9F40]
    : [0x736230, 0x88743E, 0x9F894D, 0x9D9F40, 0xD29143] // beech bronze, with a little sugar maple's orange
let summerHues: [Int] = palette == "aspen" ? [0x9DAE4A, 0xB6C06D] : [0x99AE44, 0xB6C06D] // light through a leaf (look research §1)
// a camera's exposure (sheet 3's control) is metered on the frame; otherwise the zenith is held at skyDisp and the
// leaves lifted toward it by a contrast power on luminance
let skyTarget = -log(1 - pow((cfg.skyDisp ?? 175) / 255, 2))
var expo = skyTarget / max(zenith.max(), 1e-9)
let lift = cfg.camera == true ? 1.0 : (cfg.lift ?? 0.6)
let pivot = lum(zenith) * expo
let tanSun = min(sqrt(sun.x * sun.x + sun.y * sun.y) / max(sun.z, 0.05), 3)
let step = (1.0 / 6) * focal * (sun.z > 0 && !overcast ? 1 : 0) // the layers are about 3 m apart about 18 m up
let horiz = sqrt(sun.x * sun.x + sun.y * sun.y) + 1e-9
let SS = SIMD2(step * tanSun * (-sun.x / horiz) / Double(LW), step * tanSun * (sun.y / horiz) / Double(LH))
let sunCol = air.sunlight(0.3, sun.z) * norm
func defines() -> String {
    let d: [String: String] = [
        "MARGIN": "\(margin)", "TANH": "\(tanH)", "TANV": "\(tanV)", "TRANS": "\(trans)",
        "SUNE": glsl(sunE), "AMBE": glsl(ambE), "ZEN": glsl(zenith), "SUNDIR": glsl(V3(-sun.x, sun.y, sun.z)),
        "SS": String(format: "vec2(%.6f, %.6f)", SS.x, SS.y), "FWD": "\(cfg.camera == true ? 0 : 1.5)",
        "G0": glsl(hue(summerHues[0])), "G1": glsl(hue(summerHues[1])),
        "AU0": glsl(hue(autumnHues[0])), "AU1": glsl(hue(autumnHues[1])), "AU2": glsl(hue(autumnHues[2])),
        "AU3": glsl(hue(autumnHues[3])), "AU4": glsl(hue(autumnHues[4])),
        "LIFT": "\(lift)", "PIVOT": "\(pivot)", "VEIL": "\(cfg.veil ?? 0)", "PALE": glsl(hue(0xB2B9CB)),
        "WOODHUE": glsl(hue(0x4C4B46)), "BIRCH": cfg.bark == "birch" ? "1" : "0", "BIRCHHUE": glsl(hue(0xC6C3BC)), "CAMERA": cfg.camera == true ? "1" : "0", "PHOTO": method == "photo" ? "1" : "0",
        "SUNVIS": "\(sunVis)", "HALO": "\(cfg.halo ?? 0)", "SUNCOL": glsl(sunCol),
        "CELLS": String(format: "vec2(%.1f, %.1f)", Double(LW) / 11, Double(LH) / 11), // (a) thins a leaf at a time
    ]
    return d.sorted { $0.key < $1.key }.map { "#define \($0.key) \($0.value)\n" }.joined()
}
let shaderSource = defines() + """
float lumi(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
// A spray's colour of the light through it, from its id: green in summer; turning, by its own date, to one of the
// season's scanned and photographed hues. The sprays that fall first turn first.
vec3 leafHue(float id, float season) {
    float h = fract(id * 13.71);
    vec3 g = mix(G0, G1, h);
    float th = 0.65 * id + 0.35 * fract(id * 7.31);
    float turned = smoothstep(th - 0.08, th + 0.08, season);
    vec3 a = h < 0.3 ? AU0 : (h < 0.55 ? AU1 : (h < 0.8 ? AU2 : (h < 0.93 ? AU3 : AU4)));
    return mix(g, a, turned) * (0.8 + 0.4 * fract(id * 31.3));
}
vec3 rayDir(vec2 uv) { return normalize(vec3((uv.x * 2.0 - 1.0) * TANH, (uv.y * 2.0 - 1.0) * TANV, 1.0)); }
void main() {
    vec2 uv = v_tex_coord;
    vec2 lq = (uv - 0.5) / MARGIN + 0.5;
    vec4 g = texture2D(u_sway, lq);
    vec2 q = lq - (g.x * u_s01.xy + g.y * u_s01.zw + g.z * u_s23.xy + g.w * u_s23.zw);
    vec3 sky = texture2D(u_sky, uv).rgb; sky = sky * sky * 8.0;
    vec4 wd = texture2D(u_wood, q);
    vec4 A = texture2D(u_A, q);
    vec4 B = texture2D(u_B, q);
    vec4 ab = texture2D(u_above, q);
    // the light from the Sun reaching each layer, read through the layers above along its direction
    vec4 s1 = texture2D(u_above, q + SS);
    vec4 s2 = texture2D(u_above, q + SS * 2.0);
    vec4 s3 = texture2D(u_above, q + SS * 3.0);
    float v2s = exp(-2.2 * (s1.z + 0.5 * s1.w));
    float v1s = exp(-2.2 * (s1.y + s2.z + 0.5 * s2.w));
    float v0s = exp(-2.2 * (s1.x + s2.y + s3.z + 0.5 * s3.w));
    float v2a = exp(-1.6 * (0.9 * ab.z + 0.3 * ab.w));
    float v1a = exp(-1.6 * (ab.z + 0.9 * ab.y + 0.4 * ab.w));
    float v0a = exp(-1.6 * (ab.z + ab.y + 0.9 * ab.x + 0.5 * ab.w));
    vec3 d = rayDir(uv);
    float fwd = 1.0 + FWD * pow(max(dot(d, SUNDIR), 0.0), 12.0);
    vec3 col = sky;
    float p2 = step(u_season.y, B.g) * step(0.003, B.g);
    float p1 = step(u_season.y, A.a) * step(0.003, A.a);
    float p0 = step(u_season.y, A.g) * step(0.003, A.g);
    col = mix(col, leafHue(B.g, u_season.x) * TRANS * (SUNE * v2s * fwd + AMBE * v2a) + AMBE * 0.002, B.r * p2);
    // the wood (or, for a photo, its whole canopy), its colour a share of the sky's brightness, shaded by the leaves
    vec3 wc = wd.rgb * wd.rgb * 2.0 * lumi(ZEN);
    float wa = wd.a;
#if PHOTO
    vec2 cq = q * CELLS; vec2 ci = floor(cq); vec2 cf = fract(cq); cf = cf * cf * (3.0 - 2.0 * cf);
    float n00 = fract(sin(dot(ci, vec2(12.9898, 78.233))) * 43758.5453), n10 = fract(sin(dot(ci + vec2(1.0, 0.0), vec2(12.9898, 78.233))) * 43758.5453);
    float n01 = fract(sin(dot(ci + vec2(0.0, 1.0), vec2(12.9898, 78.233))) * 43758.5453), n11 = fract(sin(dot(ci + vec2(1.0, 1.0), vec2(12.9898, 78.233))) * 43758.5453);
    float cell = mix(mix(n00, n10, cf.x), mix(n01, n11, cf.x), cf.y);
    float th = 0.65 * cell + 0.35 * fract(cell * 7.31);
    float turned = smoothstep(th - 0.08, th + 0.08, u_season.x) * B.b;
    vec3 au = cell < 0.3 ? AU0 : (cell < 0.55 ? AU1 : (cell < 0.8 ? AU2 : (cell < 0.93 ? AU3 : AU4)));
    wc = mix(wc, au * lumi(wc) * 1.1, turned);
    wa *= 1.0 - B.b * smoothstep(cell - 0.04, cell + 0.04, u_season.y);  // a fallen leaf leaves sky: nothing behind it
#else
    wc = WOODHUE * min(lumi(wc), 0.5 * lumi(ZEN)) * (0.35 + 0.65 * v1a); // relit as bark in the canopy's shade
#if BIRCH
    wc = mix(wc, BIRCHHUE * lumi(ZEN) * 0.5 * (0.55 + 0.45 * v1a), smoothstep(0.85, 0.97, B.a)); // recoloured, not birch's own
#endif
#endif
    col = mix(col, wc, wa);
    col = mix(col, leafHue(A.a, u_season.x) * TRANS * (SUNE * v1s * fwd + AMBE * v1a) + AMBE * 0.002, A.b * p1);
    col = mix(col, leafHue(A.g, u_season.x) * TRANS * (SUNE * v0s * fwd + AMBE * v0a) + AMBE * 0.002, A.r * p0);
    // the veil: where sky meets leaf, a few pixels' mix of the two, and the blue paled toward silver
    float here = 1.0 - (1.0 - A.r * p0) * (1.0 - A.b * p1) * (1.0 - B.r * p2) * (1.0 - wa);
    float tb = 1.0 - (1.0 - ab.x) * (1.0 - ab.y) * (1.0 - ab.z) * (1.0 - ab.w);
    vec3 leafAvg = G1 * TRANS * (SUNE * 0.35 + AMBE * 0.5);
    col = mix(col, sky * (1.0 - tb) + leafAvg * tb, VEIL * 0.5 * clamp(tb * (1.0 - tb) * 4.0, 0.0, 1.0));
    col = mix(col, PALE * lumi(sky) * 1.1, VEIL * 0.6 * tb * (1.0 - here));
    // the Sun: a soft disc and a halo of glare where it shows through, no starburst
    float ang = acos(clamp(dot(d, SUNDIR), -1.0, 1.0));
    col += SUNVIS * SUNCOL * (60.0 * smoothstep(0.5, 0.9, SUNVIS) * (1.0 - smoothstep(0.0045, 0.0075, ang)) + HALO * (exp(-ang / 0.05) + 0.25 * exp(-ang / 0.25)));
    col *= u_expo;
#if CAMERA
    col = pow(min(col, vec3(1.0)), vec3(1.0 / 2.2)) * 0.816;   // the sensor clips, then scaled in linear light by 0.64
#else
    float l = max(lumi(col), 1e-6);
    col *= PIVOT * pow(l / PIVOT, LIFT) / l;
    col = sqrt(1.0 - exp(-col));                                 // Weather's film-like roll-off, roughly sRGB
#endif
    col = min(col, vec3(240.0 / 255.0));
    gl_FragColor = vec4(col + (fract(sin(dot(gl_FragCoord.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0, 1.0);
}
"""

// MARK: - The scene

let s01 = SKUniform(name: "u_s01", vectorFloat4: .zero), s23 = SKUniform(name: "u_s23", vectorFloat4: .zero)
let expoU = SKUniform(name: "u_expo", float: Float(expo))
let seasonU = SKUniform(name: "u_season", vectorFloat4: [Float(cfg.turn ?? 0), Float(fallen), 0, 0])
let shader = SKShader(source: shaderSource, uniforms: [s01, s23, expoU, seasonU,
    SKUniform(name: "u_sky", texture: texture(skyPx, 128, 96)), SKUniform(name: "u_wood", texture: woodTex),
    SKUniform(name: "u_A", texture: texA), SKUniform(name: "u_B", texture: texB),
    SKUniform(name: "u_above", texture: aboveTex), SKUniform(name: "u_sway", texture: swayTex)])
let scene = SKScene(size: CGSize(width: wPt, height: hPt))
let canopy = SKSpriteNode(color: .black, size: scene.size)
canopy.anchorPoint = .zero
canopy.shader = shader
scene.addChild(canopy)

/// The crowns' sway: four groups of trees, each its own frequency in the in-leaf range (0.15-0.3 Hz), mostly along
/// the wind with a little across it, under a gust envelope; a few pixels at 2x in a breeze.
let wind = cfg.wind ?? 0
var swayR = Rand(s: 9)
let swayPh = (0..<8).map { _ in swayR.r(0, 2 * .pi) }
func sway(_ t: Double) {
    let amp = min(6 * pow(wind / 4, 2), 14), wdir = 0.5, f: [Double] = [0.17, 0.21, 0.25, 0.29]
    let env = 0.7 + 0.3 * sin(2 * .pi * t / 23 + swayPh[7]) + 0.15 * sin(2 * .pi * t / 9.7 + swayPh[6])
    var v: [Float] = []
    for gI in 0..<4 {
        let along = sin(2 * .pi * f[gI] * t + swayPh[gI]) * env, across = 0.35 * sin(2 * .pi * f[gI] * 1.13 * t + swayPh[gI + 3])
        let dx = amp * (along * cos(wdir) - across * sin(wdir)), dy = amp * (along * sin(wdir) + across * cos(wdir))
        v += [Float(dx / Double(LW)), Float(dy / Double(LH))]
    }
    s01.vectorFloat4Value = [v[0], v[1], v[2], v[3]]
    s23.vectorFloat4Value = [v[4], v[5], v[6], v[7]]
}

/// Falling leaves (autumn): a scanned leaf each, about 9 cm, let go from the crowns 15-19 m up, falling about 0.9 m/s
/// with the 60% swing in speed of a tumbling plate, drifting with the wind and fluttering side to side, and faded out
/// before it comes nearer than fadeNear (5.5 m): the motion toward the viewer that rain was turned down for.
struct Leaf { var t0: Double, x: Double, y: Double, h0: Double, ph: Double, cell: Int, node: SKSpriteNode }
var leaves: [Leaf] = []
let fadeNear = cfg.fadeNear ?? 5.5
if let n = cfg.falling, n > 0 {
    var r = Rand(s: 21)
    let tint = { () -> NSColor in // the light through a turned leaf, as the canopy's middle layer is lit
        var c = hue(autumnHues[2]) * trans * (sunE * 0.5 + ambE * 0.6) * expo
        let l = lum(c); c *= pivot * pow(l / pivot, lift) / l
        c = c.map { sqrt(1 - exp(-$0)) }
        return NSColor(red: c.x, green: c.y, blue: c.z, alpha: 1)
    }()
    for k in 0..<(n * 2) {
        let node = SKSpriteNode(texture: SKTexture(cgImage: cells[[0, 2, 6, 11][k % 4]]), size: CGSize(width: 10, height: 10))
        node.color = tint; node.colorBlendFactor = 1; node.zPosition = 5; node.alpha = 0
        scene.addChild(node)
        leaves.append(Leaf(t0: -6 + Double(k) * 13 / Double(n), x: r.r(-5, 5), y: r.r(-3.5, 3.5), h0: r.r(15, 19), ph: r.r(0, 6.28), cell: k, node: node))
    }
}
func poseLeaves(_ t: Double) {
    for l in leaves {
        let a = t - l.t0
        guard a > 0 else { l.node.alpha = 0; continue }
        // height: 0.9 m/s on average, swinging 60% within each half-second turn
        let h = l.h0 - 0.9 * a - 0.9 * 0.6 / (2 * .pi * 0.9) * sin(2 * .pi * 0.9 * a + l.ph)
        let x = l.x + 0.35 * a * cos(0.5) + 0.25 * sin(1.3 * a + l.ph), y = l.y + 0.35 * a * sin(0.5) + 0.25 * cos(1.1 * a + l.ph)
        let fade = min(a / 1.5, 1) * min(max((h - fadeNear) / 2.5, 0), 1)
        guard h > 1, fade > 0 else { l.node.alpha = 0; continue }
        let px = wPt / 2 - x / h * focal / 2, py = hPt / 2 + y / h * focal / 2, s = 0.09 * focal / 2 / h
        l.node.position = CGPoint(x: px, y: py)
        l.node.size = CGSize(width: s, height: s)
        l.node.zRotation = CGFloat(1.7 * a + l.ph)
        l.node.xScale = CGFloat(cos(2.4 * a + l.ph))
        l.node.alpha = CGFloat(fade)
    }
}

// MARK: - Rendering

let device = MTLCreateSystemDefaultDevice()!
let queue = device.makeCommandQueue()!
let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: W, height: H, mipmapped: false)
desc.usage = [.renderTarget, .shaderRead]
desc.storageMode = .shared
let target = device.makeTexture(descriptor: desc)!
let renderer = SKRenderer(device: device)
renderer.scene = scene
let start = ProcessInfo.processInfo.systemUptime + 1

@discardableResult func draw(_ t: Double) -> (gpu: Double, cpu: Double) {
    let t0 = DispatchTime.now().uptimeNanoseconds
    sway(t); poseLeaves(t)
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = target
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    renderer.update(atTime: start + t)
    let buf = queue.makeCommandBuffer()!
    renderer.render(withViewport: CGRect(x: 0, y: 0, width: W, height: H), commandBuffer: buf, renderPassDescriptor: pass)
    buf.commit()
    buf.waitUntilCompleted()
    let gpu = (buf.gpuEndTime - buf.gpuStartTime) * 1000
    return (gpu, ms(t0) - gpu)
}
/// The frame at half size (a 2x2 average: the desktop's size in points), RGBA, row 0 at the top.
func half() -> [UInt8] {
    var px = [UInt8](repeating: 0, count: W * H * 4)
    target.getBytes(&px, bytesPerRow: W * 4, from: MTLRegionMake2D(0, 0, W, H), mipmapLevel: 0)
    let (w, h) = (W / 2, H / 2)
    var out = [UInt8](repeating: 255, count: w * h * 4)
    for j in 0..<h { for i in 0..<w { for c in 0..<3 {
        let s = [2, 1, 0][c] // BGRA to RGBA
        let k = (2 * j * W + 2 * i) * 4 + s
        out[(j * w + i) * 4 + c] = UInt8((Int(px[k]) + Int(px[k + 4]) + Int(px[k + W * 4]) + Int(px[k + W * 4 + 4]) + 2) / 4)
    } } }
    return out
}
func writePNG(_ px: [UInt8], _ w: Int, _ h: Int, _ path: String) {
    var p = px
    let ctx = CGContext(data: &p, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
}

if cfg.camera == true { // meter as a camera does: the frame's mean at 18% grey, then clip
    expoU.floatValue = 0.05
    draw(cfg.t ?? 0)
    let px = half()
    var sum = 0.0
    for i in stride(from: 0, to: px.count, by: 4 * 3) {
        let l = 0.2126 * pow(Double(px[i]) / 255 / 0.816, 2.2) + 0.7152 * pow(Double(px[i + 1]) / 255 / 0.816, 2.2) + 0.0722 * pow(Double(px[i + 2]) / 255 / 0.816, 2.2)
        sum += l / 0.05
    }
    expo = 0.18 / (sum / Double(px.count / 12))
    expoU.floatValue = Float(expo)
}

let t = cfg.t ?? 0
if cfg.raw == true { // frames to stdout for ffmpeg, at half size
    let fps = cfg.fps ?? 30
    let out = FileHandle.standardOutput
    for f in 0..<(cfg.frames ?? 360) {
        draw(t + Double(f) / fps)
        out.write(Data(half()))
    }
    exit(0)
}
if let times = cfg.times {
    for (i, tt) in times.enumerated() { draw(tt); writePNG(half(), W / 2, H / 2, cfg.out + String(format: "-%03d.png", i)) }
} else {
    draw(t)
    writePNG(half(), W / 2, H / 2, cfg.out)
}
var gpus: [Double] = [], cpus: [Double] = []
if cfg.timing ?? true { // as the probe timed: medians of 50 frames after 20, stepped at 60 fps
    for f in 0..<70 { let (g, c) = draw(t + Double(f) / 60); if f >= 20 { gpus.append(g); cpus.append(c) } }
}
func median(_ a: [Double]) -> Double { a.isEmpty ? 0 : a.sorted()[a.count / 2] }
print(String(format: "STATS {\"gpu\": %.2f, \"cpu\": %.2f, \"bake\": %.0f, \"sprays\": %d, \"sky\": %.3f, \"expo\": %.3f, \"hour\": %.2f, \"sunAlt\": %.1f, \"sunVis\": %.2f}",
             median(gpus), median(cpus), (layers?.bakeMs ?? 0) + packMs, layers?.sprays ?? 0, skyShare, expo, hour, asin(sun.z) * 180 / .pi, sunVis))
