// Seismograph mock-ups, drawn by SpriteKit's SKRenderer as the app's render test draws a wallpaper, on Etching's own
// ground (its shader's tooth, copied, and LineRoute's grain tile), so a tile shows what the app can draw. Not app
// code. The sheet is stamped once as Etching stamps a line: each texel holds when the pen reaches it (24 bits of the
// day) and how much of it the line covers, and one shader compares those with the clock and maps the screen onto
// the sheet (flat, or round a drum), so a film costs one stamp.
//
//   mkdir -p $TMPDIR/sm && cp mock.swift $TMPDIR/sm/main.swift && swiftc -O $TMPDIR/sm/main.swift ../../Sources/LineRoute/LineRoute.swift \
//     -o $TMPDIR/seismo-mock && $TMPDIR/seismo-mock '<json>'   (main.swift: top-level code beside a second file; sheet.py does this)
//
// The JSON (lengths in device pixels, times in seconds from the sheet's midnight):
//   trace, yesterday, rate: files of little-endian Float32 samples at `rate` Hz from midnight (NaN for a gap), made by
//     traces.py: 1.0 is a row's spacing. gain multiplies; clip (rows) stops the pen as a drum's stops do.
//   now: the pen's time. minutes, lines: a row's minutes and the sheet's rows (30 and 48).
//   view: sheet (flat, the day as a page, today written over yesterday's faint line), roll (flat, the last 24 hours,
//     the newest row at the bottom), drum (upright: rows run round it, the pen still, the paper turning past it),
//     drum-real (the axis across, as recorders stand: rows run up and over the drum).
//   surface: Chart, Paper, Parchment, Blueprint, Powder, Smoked; tone light or dark; inks: RGBs the rows cycle through.
//   pen: the line's width. fade: how much thinner and paler a fast stroke is (0 to 1). old: yesterday's ink, a share
//     of the way from the ground to the ink. slant: the drum's helix. marks: the minute and hour pips, in rows.
//   labels: hours in the margin. top, bottom, left, right: margins as shares of the screen.
//   width, height: points, drawn at 2x. out: a .png, "-" for raw BGRA frames on stdout, or a prefix with times/frames.
import Foundation
import Metal
import SpriteKit

struct Config: Decodable {
    var trace: String?, yesterday: String?, rate: Double?, gain: Double?, clip: Double?
    var now: Double?, minutes: Double?, lines: Int?
    var view: String?, surface: String?, tone: String?, inks: [[Double]]?
    var pen: Double?, fade: Double?, old: Double?, slant: Bool?, marks: Double?, labels: Bool?
    var top: Double?, left: Double?, right: Double?, bottom: Double?
    var width: Double?, height: Double?
    var out: String
    var times: [Double]?, frames: Int?, fps: Double?, speed: Double?
}

let cfg = try! JSONDecoder().decode(Config.self, from: CommandLine.arguments[1].data(using: .utf8)!)
let wPt = cfg.width ?? 1512, hPt = cfg.height ?? 982
let W = Int(wPt * 2), H = Int(hPt * 2)
let lineSec = (cfg.minutes ?? 30) * 60, lines = cfg.lines ?? Int(86400 / lineSec)
let view = cfg.view ?? "sheet"
let now = cfg.now ?? 86400 * 0.6

// Etching's surfaces (Etching.swift), and the look research's two new ones: Chart, a dimmed cream under black-brown
// ink, and Smoked, soot with a pale scratch (research-look.md §3).
func tone(_ r: Double, _ g: Double, _ b: Double) -> SIMD3<Float> { SIMD3(Float(r), Float(g), Float(b)) / 255 }
typealias Pair = (SIMD3<Float>, SIMD3<Float>)
let surfaces: [String: (ground: Pair, ink: Pair, tooth: Pair)] = [
    "Chart": ((tone(208, 200, 184), tone(58, 56, 53)), (tone(46, 40, 36), tone(228, 224, 214)), ([0.009, 0.008, 0.025], [0.020, 0.024, 0.05])),
    "Paper": ((tone(236, 230, 216), tone(58, 56, 53)), (tone(36, 33, 31), tone(228, 224, 214)), ([0.009, 0.008, 0.025], [0.020, 0.024, 0.05])),
    "Parchment": ((tone(216, 199, 165), tone(74, 58, 42)), (tone(62, 42, 27), tone(232, 216, 184)), ([0.011, 0.010, 0.032], [0.020, 0.024, 0.05])),
    "Blueprint": ((tone(226, 232, 238), tone(24, 60, 116)), (tone(38, 72, 138), tone(232, 240, 248)), ([0.009, 0.008, 0.025], [0.020, 0.024, 0.05])),
    "Powder": ((tone(152, 154, 151), tone(104, 106, 104)), (tone(50, 52, 54), tone(34, 35, 37)), ([0.009, 0.008, 0.025], [0.013, 0.015, 0.035])),
    "Smoked": ((tone(34, 33, 31), tone(34, 33, 31)), (tone(196, 192, 184), tone(196, 192, 184)), ([0.030, 0.034, 0.06], [0.030, 0.034, 0.06])),
]
let dark = cfg.tone == "dark"
let surface = surfaces[cfg.surface ?? "Chart"]!
let ground = dark ? surface.ground.1 : surface.ground.0, toothK = dark ? surface.tooth.1 : surface.tooth.0
let inks: [SIMD3<Float>] = cfg.inks.map { $0.map { tone($0[0], $0[1], $0[2]) } } ?? [dark ? surface.ink.1 : surface.ink.0]

// The sheet the pen writes on, in texels, and where it lies on the screen. Flat, it is the screen. Round a drum, it is
// the drum's whole turn (2πR) by its length, and the screen sees the front of it, out to 77° either side.
let reach = 77.0 * .pi / 180
let across = view == "drum-real" ? Double(H) : Double(W) // the screen's way round the drum
let radius = across / 2 / sin(reach)
let round = view.hasPrefix("drum")
let SW = round ? Int((2 * .pi * radius).rounded()) : W
let SH = view == "drum-real" ? W : H
let top = Double(SH) * (cfg.top ?? (round ? 0.04 : 0.06)), bottom = Double(SH) * (cfg.bottom ?? 0.03)
let left = round ? 0 : Double(W) * (cfg.left ?? 0.05), right = round ? Double(SW) : Double(W) * (1 - (cfg.right ?? 0.03))
let spacing = (Double(SH) - top - bottom) / Double(lines)
let pen = cfg.pen ?? 2.0, gain = cfg.gain ?? 1, clip = cfg.clip ?? 2.5, slant = cfg.slant ?? true, fade = cfg.fade ?? 0.5

func load(_ path: String?) -> [Float] {
    path.map { p in try! Data(contentsOf: URL(fileURLWithPath: p)).withUnsafeBytes { Array($0.bindMemory(to: Float.self)) } } ?? []
}
let rate = cfg.rate ?? 1
let todays = load(cfg.trace), yesterdays = load(cfg.yesterday)
// Rolled, the sheet's rows are the last 24 hours, its first row beginning `origin` seconds after yesterday's midnight.
let roll = view == "roll"
let origin = roll ? (floor(now / lineSec) + 1) * lineSec : 0
let samples = roll ? yesterdays + todays : todays
let clock = roll ? now + 86400 - origin : now

/// The pen's offset at a sheet time, in rows, up positive: the ground's motion, stopped at the drum's stops, and the
/// clock's pips (MEQ-800: 1 s each minute, 2 s each hour, 10 s at noon and midnight).
func deflection(_ t: Double, _ data: [Float]) -> Double? {
    // between two samples the ground moved between them: the line runs straight from one to the next
    let x = (t + origin) * rate, i = Int(x.rounded(.down)), f = x - Double(i)
    var v = 0.0
    if i >= 0, i + 1 < data.count {
        guard !data[i].isNaN, !data[i + 1].isNaN else { return nil }
        v = (Double(data[i]) * (1 - f) + Double(data[i + 1]) * f) * gain
    }
    v = max(-clip, min(clip, v))
    if let m = cfg.marks, m > 0 {
        let day = (t + origin).truncatingRemainder(dividingBy: 86400), s = day.truncatingRemainder(dividingBy: 60)
        let long = day.truncatingRemainder(dividingBy: 43200) < 60 ? 10.0 : (day.truncatingRemainder(dividingBy: 3600) < 60 ? 2.0 : 1.0)
        if s < long { v += m }
    }
    return v
}

/// A stamp: for each texel, when the pen covers it most (24 bits of the day) and how much (alpha).
func stamp(_ data: [Float], labels: Bool) -> [UInt8] {
    var when = [UInt8](repeating: 0, count: SW * SH * 4)
    let dayScale = 16_777_214.0 / 86400.0
    func put(_ x: Int, _ y: Int, _ cover: Double, _ t: Double) {
        guard x >= 0, x < SW, y >= 0, y < SH, cover > 0.004 else { return }
        let i = ((SH - 1 - y) * SW + x) * 4 // texture rows run up from the bottom
        let a = UInt8(min(255, cover * 255 + 0.5))
        if a <= when[i + 3] { return }
        let q = UInt32(max(0, min(16_777_214, t * dayScale)))
        when[i] = UInt8(q >> 16); when[i + 1] = UInt8(q >> 8 & 255); when[i + 2] = UInt8(q & 255); when[i + 3] = a
    }
    let cols = Int(right - left), colSec = lineSec / Double(cols), step = 1 / rate
    for line in 0..<lines {
        let base = top + (Double(line) + 0.5) * spacing
        for c in 0..<cols {
            // the trace's reach over this column and half a pen's width either side, so a steep stroke keeps its width
            let t0 = Double(line) * lineSec + (Double(c) - pen / 2) * colSec, t1 = Double(line) * lineSec + (Double(c + 1) + pen / 2) * colSec
            // its two ends and every sample between, so the line is whole however many columns a sample spans
            var lo = Double.infinity, hi = -Double.infinity
            var t = (t0 * rate).rounded(.up) / rate
            for at in [t0, t1] { if let v = deflection(at, data) { lo = min(lo, v); hi = max(hi, v) } }
            while t < t1 { if let v = deflection(t, data) { lo = min(lo, v); hi = max(hi, v) }; t += step }
            guard lo <= hi else { continue }
            let fall = slant ? Double(c) / Double(cols) * spacing : 0
            let yTop = base + fall - hi * spacing - pen / 2, yBot = base + fall - lo * spacing + pen / 2
            // a fast stroke is thinner and paler, as ink lays less of itself down where the pen moves quickly
            let ink = 1 - fade * (1 - min(1, 2.5 * pen / (yBot - yTop)))
            let tc = Double(line) * lineSec + Double(c) * colSec
            for y in Int(yTop.rounded(.down))...Int(yBot.rounded(.up)) {
                put(Int(left) + c, y, max(0, min(Double(y + 1), yBot) - max(Double(y), yTop)) * ink, tc)
            }
        }
    }
    // the hours in the left margin, printed on the sheet before the day began (time 0), in a pencil's grey
    if labels {
        let ctx = CGContext(data: nil, width: SW, height: SH, bitsPerComponent: 8, bytesPerRow: SW, space: CGColorSpaceCreateDeviceGray(),
                            bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        let font = CTFontCreateWithName("Helvetica" as CFString, max(spacing * 0.42, 15), nil)
        let every = lines > 48 ? 7200.0 : 3600.0
        for line in 0..<lines {
            let at = Double(line) * lineSec + origin
            guard at.truncatingRemainder(dividingBy: every) == 0 else { continue }
            let l = CTLineCreateWithAttributedString(NSAttributedString(string: String(format: "%02d", Int(at / 3600) % 24),
                                                                        attributes: [.font: font, .foregroundColor: CGColor(gray: 1, alpha: 1)]))
            let b = CTLineGetBoundsWithOptions(l, .useGlyphPathBounds)
            ctx.textPosition = CGPoint(x: left - b.width - 24, y: Double(SH) - (top + (Double(line) + 0.5) * spacing) - b.height / 2)
            CTLineDraw(l, ctx)
        }
        let px = ctx.data!.bindMemory(to: UInt8.self, capacity: SW * SH)
        for y in 0..<SH { for x in 0..<Int(left) where px[y * SW + x] > 0 { put(x, y, Double(px[y * SW + x]) / 255 * 0.5, 0) } } // rows run down, as the stamp's y does
    }
    return when
}

func texture(_ bytes: [UInt8]) -> SKTexture {
    let t = SKTexture(data: Data(bytes), size: CGSize(width: SW, height: SH))
    t.filteringMode = .nearest
    return t
}
let today = texture(stamp(samples, labels: (cfg.labels ?? true) && !round))
let before = texture(roll || yesterdays.isEmpty ? [UInt8](repeating: 0, count: SW * SH * 4) : stamp(yesterdays, labels: false))
let grain: SKTexture = {
    let t = SKTexture(data: LineRoute.grain(), size: CGSize(width: 512, height: 512))
    t.filteringMode = .linear
    return t
}()

let clockU = SKUniform(name: "u_clock", float: 0)
let penAt = SKUniform(name: "u_pen", vectorFloat2: [0, 0])
let inkU = (0..<4).map { SKUniform(name: "u_ink\($0)", vectorFloat3: inks[$0 % inks.count]) }
let viewCode = ["sheet": 0, "roll": 0, "drum": 1, "drum-real": 2][view]!
let taps = round ? 2 : 1
let source = """
vec4 hash42(vec2 p) {
    vec4 p4 = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
    p4 += dot(p4, p4.wzxy + 33.33);
    return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}
float when24(vec4 w) { return (floor(w.r * 255.0 + 0.5) * 65536.0 + floor(w.g * 255.0 + 0.5) * 256.0 + floor(w.b * 255.0 + 0.5)) / \(16_777_214.0 / 86400.0); }
void main() {
    // The screen's pixel, and the point of the sheet under it: the same, flat; round a drum, its angle from the
    // pen by an arcsine, which is how far round the turn the paper there is from the pen's.
    vec2 p = v_tex_coord * u_px;
    float shade = 1.0, a = 0.0, y = 0.0, aw = 0.0;
    vec3 ink = u_ink0;
    vec2 q = vec2(p.x, \(Double(SH)) - p.y);
    for (float j = 0.0; j < \(Double(taps)) - 0.5; j += 1.0) {
        for (float i = 0.0; i < \(Double(taps)) - 0.5; i += 1.0) {
            vec2 s = floor(p) + (vec2(i, j) + 0.5) / \(Double(taps));
            vec2 at = vec2(s.x, \(Double(SH)) - s.y);
            if (\(viewCode) == 1) {
                float th = asin(clamp((s.x - \(Double(W) / 2)) / \(radius), -1.0, 1.0));
                at = vec2(fract(u_clock / \(lineSec) + th / 6.2831853) * \(Double(SW)), \(Double(SH)) - s.y);
                shade = cos(th);
            } else if (\(viewCode) == 2) {
                float th = asin(clamp((s.y - \(Double(H) / 2)) / \(radius), -1.0, 1.0));
                at = vec2(fract(u_clock / \(lineSec) + th / 6.2831853) * \(Double(SW)), s.x);
                shade = cos(th);
            }
            if (i + j < 0.5) { q = at; }
            vec2 tc = (floor(at) + 0.5) / vec2(\(Double(SW)), \(Double(SH)));
            tc.y = 1.0 - tc.y;
            vec4 w = texture2D(u_today, tc), o = texture2D(u_before, tc);
            float t = when24(w), drawn = w.a * step(t, u_clock);
            float row = mod(floor(t / \(lineSec)), \(Double(inks.count)));
            vec3 c = row < 0.5 ? u_ink0 : (row < 1.5 ? u_ink1 : (row < 2.5 ? u_ink2 : u_ink3));
            ink = drawn > aw ? c : ink;
            aw = max(aw, drawn);
            a += drawn;
            y += o.a * step(u_clock, when24(o));
        }
    }
    a /= \(Double(taps * taps)); y /= \(Double(taps * taps));
    // Etching's tooth, as Etching.swift has it, on the paper (so round a drum it turns with it).
    vec2 px = floor(q), at = px + 0.5, cell = floor(at / 53.0);
    vec4 n = hash42(px), h = hash42(cell + 17.0);
    float soft = texture2D(u_grain, (mod(px + floor(h.zw * 512.0), 512.0) + 0.5) / 512.0).r - 1.004, fibres = 0.0;
    vec2 d = at - (cell + 0.16 + 0.68 * h.xy) * 53.0;
    if (dot(d, d) < 72.0) {
        vec2 along = normalize(vec2(h.z, fract(h.z * 64.0)) - 0.5);
        float reach = 3.0 + 4.0 * fract(h.w * 16.0);
        fibres += (step(0.5, h.w) * 2.0 - 1.0) * max(0.0, 1.0 - length(d - along * clamp(dot(d, along), -reach, reach)));
    }
    at += 400.0;
    cell = floor(at / 61.0);
    h = hash42(cell + 130.0);
    soft += texture2D(u_grain, (mod(px + floor(h.zw * 512.0), 512.0) + 0.5) / 512.0).r;
    d = at - (cell + 0.16 + 0.68 * h.xy) * 61.0;
    if (dot(d, d) < 72.0) {
        vec2 along = normalize(vec2(h.z, fract(h.z * 64.0)) - 0.5);
        float reach = 3.0 + 4.0 * fract(h.w * 16.0);
        fibres += (step(0.5, h.w) * 2.0 - 1.0) * max(0.0, 1.0 - length(d - along * clamp(dot(d, along), -reach, reach)));
    }
    float tooth = u_tooth.x * (n.x + n.y - 1.0) * 2.449 + u_tooth.y * soft * 5.635 + u_tooth.z * fibres;
    // yesterday's line, faint and in the older ink, where today's pen has not yet come; then today's; then the pen
    vec3 tone = mix(u_ground, u_ink0, y * \(cfg.old ?? 0.28));
    tone = mix(tone, ink, a);
    float tip = 1.0 - smoothstep(\(pen * 0.9), \(pen * 2.4), length(p - u_pen));
    tone = mix(tone, u_ink0, tip * 0.9);
    tone = tone * (1.0 + 0.02 * (v_tex_coord.y - v_tex_coord.x)) + tooth * min(tone, u_ground);
    // round a drum, the paper turns away from the light toward its edges
    gl_FragColor = vec4(tone * mix(0.45, 1.0, pow(max(shade, 0.0), 0.8)), 1.0);
}
"""
let scene = SKScene(size: CGSize(width: wPt, height: hPt))
let sprite = SKSpriteNode(color: .white, size: scene.size)
sprite.anchorPoint = .zero
sprite.shader = SKShader(source: source, uniforms: [
    SKUniform(name: "u_px", vectorFloat2: [Float(W), Float(H)]), SKUniform(name: "u_grain", texture: grain),
    SKUniform(name: "u_today", texture: today), SKUniform(name: "u_before", texture: before), clockU, penAt,
    SKUniform(name: "u_ground", vectorFloat3: ground), SKUniform(name: "u_tooth", vectorFloat3: toothK)] + inkU)
scene.addChild(sprite)

/// Where the pen is at a sheet time, in the screen's pixels (up from the bottom). Round a drum it stays at the
/// front, the middle of the screen, and moves along the drum one row a turn.
func penPlace(_ t: Double) -> SIMD2<Float> {
    let line = min(Int(t / lineSec), lines - 1), along = (t - Double(line) * lineSec) / lineSec
    let y = top + (Double(line) + 0.5) * spacing + (slant ? along * spacing : 0) - (deflection(t, samples) ?? 0) * spacing
    switch view {
    case "drum": return [Float(W / 2), Float(Double(H) - y)]
    case "drum-real": return [Float(y), Float(H / 2)]
    default: return [Float(left + along * (right - left)), Float(Double(H) - y)]
    }
}

let device = MTLCreateSystemDefaultDevice()!
let queue = device.makeCommandQueue()!
let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: W, height: H, mipmapped: false)
desc.usage = [.renderTarget, .shaderRead]
desc.storageMode = .shared
let target = device.makeTexture(descriptor: desc)!
let renderer = SKRenderer(device: device)
renderer.scene = scene

/// Draws the moment `t` (the sheet's clock), and returns the GPU's time for it in ms. "-" as the path writes the
/// frame's BGRA to stdout.
@discardableResult
func render(at t: Double, to path: String?) -> Double {
    clockU.floatValue = Float(t)
    penAt.vectorFloat2Value = penPlace(t)
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = target
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    renderer.update(atTime: t)
    let buf = queue.makeCommandBuffer()!
    renderer.render(withViewport: CGRect(x: 0, y: 0, width: W, height: H), commandBuffer: buf, renderPassDescriptor: pass)
    buf.commit()
    buf.waitUntilCompleted()
    let gpu = (buf.gpuEndTime - buf.gpuStartTime) * 1000
    guard let path else { return gpu }
    let bytes = W * 4
    var px = [UInt8](repeating: 0, count: bytes * H)
    target.getBytes(&px, bytesPerRow: bytes, from: MTLRegionMake2D(0, 0, W, H), mipmapLevel: 0)
    if path == "-" {
        FileHandle.standardOutput.write(Data(px))
        return gpu
    }
    let ctx = CGContext(data: &px, width: W, height: H, bitsPerComponent: 8, bytesPerRow: bytes, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
    return gpu
}

if let times = cfg.times {
    for (i, t) in times.enumerated() { render(at: t + clock - now, to: cfg.out + String(format: "-%03d.png", i)) }
} else if let frames = cfg.frames {
    let fps = cfg.fps ?? 30, speed = cfg.speed ?? 1
    for f in 0..<frames { render(at: clock + Double(f) / fps * speed, to: cfg.out == "-" ? "-" : cfg.out + String(format: "-%04d.png", f)) }
} else {
    // the GPU's time a frame, the median of twenty after a warm-up, then the picture
    let gpu = (0..<24).map { render(at: clock + Double($0), to: nil) }.dropFirst(4).sorted()[10]
    render(at: clock, to: cfg.out)
    print("STATS " + String(format: "{\"gpu\": %.3f}", gpu))
}
