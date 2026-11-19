import Foundation
import Metal
import simd
import SpriteKit
import Testing
import UniformTypeIdentifiers
@testable import Atrium

/// Saturn's Rings' pyramid: each k's finest row is the profile itself, exp(−τk) in two bytes beside the particles'
/// brightness, and each coarsest row the mean of the row below it over twice the width. Prints how long reading the
/// profile and baking the pyramid take, which happens on the main thread as the scene is built (a release build's
/// figures are in docs/saturns-rings.md, Cost).
@Test func saturnsRingsPyramidHoldsMeans() {
    var start = CFAbsoluteTimeGetCurrent()
    let rings = RingProfile.load()
    let read = CFAbsoluteTimeGetCurrent() - start
    start = CFAbsoluteTimeGetCurrent()
    let bytes = rings.pyramidBytes()
    print(String(format: "Saturn's Rings: profile read in %.1f ms, pyramid baked in %.1f ms", read * 1000, (CFAbsoluteTimeGetCurrent() - start) * 1000))
    let n = rings.tau.count, levels = RingProfile.levels
    #expect(n == 8751 && abs(rings.step - 0.008) < 1e-12 && bytes.count == n * RingProfile.ks * levels * 4)
    func value(_ j: Int, _ m: Int, _ i: Int) -> Int { let at = ((j * levels + m) * n + i) * 4; return Int(bytes[at]) << 8 | Int(bytes[at + 1]) }
    for j in [0, 5, 11] {
        for i in stride(from: 0, to: n, by: 7) {
            #expect(abs(value(j, 0, i) - Int(exp(-rings.tau[i] * pow(2, Double(j))) * 65535)) <= 1)
            if j == 0 { #expect(abs(Int(bytes[i * 4 + 2]) - Int(min(rings.brightness[i], 0.5) / 0.5 * 255)) <= 1) }
            if i >= 1024, i < n - 1024 { #expect(abs(2 * value(j, levels - 1, i) - value(j, levels - 2, i - 1024) - value(j, levels - 2, i + 1024)) <= 3) }
        }
    }
}

/// How long the main thread takes to build the scene and draw its first frame at 3024 × 1964: the first copy, which
/// makes the shared textures (the pyramid, the star grid, the Milky Way's glow read from its HEIC), and a second,
/// which shares them. Prints them; docs/saturns-rings.md, Cost, has a release build's.
@MainActor @Test func saturnsRingsBuildTime() throws {
    let device = try #require(MTLCreateSystemDefaultDevice()), queue = try #require(device.makeCommandQueue())
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 3024, height: 1964, mipmapped: false)
    descriptor.usage = [.renderTarget]
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = try #require(device.makeTexture(descriptor: descriptor))
    var held: [SaturnsRings] = [] // so the second copy shares the first's textures
    var times: [String] = []
    for copy in ["first", "second"] {
        var start = CFAbsoluteTimeGetCurrent()
        let scene = SaturnsRings(size: CGSize(width: 1512, height: 982), from: 2, moment: 0)
        let built = CFAbsoluteTimeGetCurrent() - start
        held.append(scene)
        let renderer = SKRenderer(device: device)
        renderer.scene = scene
        start = CFAbsoluteTimeGetCurrent()
        renderer.update(atTime: 1)
        let buffer = try #require(queue.makeCommandBuffer())
        renderer.render(withViewport: CGRect(x: 0, y: 0, width: 3024, height: 1964), commandBuffer: buffer, renderPassDescriptor: pass)
        buffer.commit()
        buffer.waitUntilCompleted()
        times.append(String(format: "%@ built in %.0f ms, its first frame drawn in %.0f ms", copy, built * 1000, (CFAbsoluteTimeGetCurrent() - start) * 1000))
    }
    print("Saturn's Rings: " + times.joined(separator: "; "))
}

/// Every glide, from any view anywhere in its drift (a hold can end at any point of it) or from halfway through
/// another glide (as when a view is picked in Settings then), to any other view, from either face, starts where the
/// camera was, ends on the view, and stays above the ring plane and outside the planet all the way, with the Sun
/// never within 30° of behind the planet, where its shadow would cross the camera.
@Test func saturnsRingsGlidesStayClear() {
    let views = SaturnsRings.views, swing = SaturnsRings.swing
    for (i, a) in views.enumerated() {
        for (j, b) in views.enumerated() where i != j {
            for (moment, lit) in [0, swing / 4, swing / 2, swing, 1.5 * swing, -1].flatMap({ m in [(m, false), (m, true)] }) {
                // -1: from halfway through a glide out of `b`, as when `b` is picked again in Settings mid-glide
                let from = moment >= 0 ? SaturnsRings.held(a, for: moment, lit: lit)
                    : SaturnsRings.between(SaturnsRings.held(b, for: swing, lit: lit), SaturnsRings.held(a, for: 0, lit: lit), 0.5)
                let to = SaturnsRings.held(b, for: 0, lit: lit)
                for step in 0...200 {
                    let camera = SaturnsRings.between(from, to, Double(step) / 200)
                    let outside = pow(camera.r / 60.268, 2) + pow(camera.h / 54.364, 2)
                    #expect(camera.h > 0.1 && outside > 1.5, "\(a.name) to \(b.name): r \(camera.r), h \(camera.h)")
                    #expect(abs(remainder(camera.sun - 180, 360)) > 30, "\(a.name) to \(b.name): the Sun at \(camera.sun)°")
                }
                let start = SaturnsRings.between(from, to, 0), end = SaturnsRings.between(from, to, 1)
                for (got, want) in [(start, from), (end, to)] {
                    #expect(abs(got.r - want.r) + abs(got.h - want.h) + abs(remainder(got.yaw - want.yaw, 360)) + abs(got.pitch - want.pitch)
                            + abs(got.field - want.field) + abs(remainder(got.sun - want.sun, 360)) + abs(got.moon - want.moon)
                            + (want.moon > 0 ? abs(got.ahead - want.ahead) : 0) + abs(log(got.exposure / want.exposure)) < 1e-9,
                            "\(a.name) to \(b.name)")
                }
            }
        }
    }
}

/// The next view in Cycle is any but the one showing and the one before it.
@Test func saturnsRingsNextViewIsNew() {
    for view in SaturnsRings.views.indices {
        for previous in SaturnsRings.views.indices where previous != view {
            let picks = Set((0..<200).map { _ in SaturnsRings.next(after: view, previous: previous) })
            #expect(picks == Set(SaturnsRings.views.indices).subtracting([view, previous]))
        }
    }
}

/// How far the fastest thing on screen moves from camera `a` to camera `b`, in device pixels at 3024 × 1964: the
/// points of the ring plane, the planet and the sky seen through a grid over the screen, found again from `b`. A
/// point is also taken as turning with the Sun where something there does (the planet's shadow's edge on the rings,
/// within 1 Mm; the planet, whose night side and ring shadows do; the stars, which keep to the Sun's frame), and as
/// moving with Daphnis where its waves are a tenth of a km or more, as the shader draws them; the larger counts.
private func fastest(_ a: SaturnsRings.Camera, _ b: SaturnsRings.Camera, across: Int = 48, up: Int = 32) -> Double {
    let (w, h) = (3024.0, 1964.0), (from, to) = (a.axes(), b.axes())
    let (lensA, lensB) = (tan(a.field / 2 * .pi / 180), tan(b.field / 2 * .pi / 180))
    func turned(_ p: SIMD3<Double>, by degrees: Double) -> SIMD3<Double> {
        let (c, s) = (cos(degrees * .pi / 180), sin(degrees * .pi / 180))
        return SIMD3(c * p.x - s * p.y, s * p.x + c * p.y, p.z)
    }
    /// Where `p` is on `b`'s screen in device pixels from the centre, a point if `far` is false, else a direction.
    func seen(_ p: SIMD3<Double>, far: Bool) -> SIMD2<Double>? {
        let q = far ? p : p - to.at, depth = simd_dot(q, to.ahead)
        guard depth > 1e-6 else { return nil }
        return SIMD2(simd_dot(q, to.right) / depth / lensB * w / 2, simd_dot(q, to.up) / depth / (lensB * h / w) * h / 2)
    }
    var most = 0.0
    for i in 0..<across {
        for j in 0..<up {
            let (x, y) = ((Double(i) + 0.5) / Double(across) * 2 - 1, (Double(j) + 0.5) / Double(up) * 2 - 1)
            let d = simd_normalize(from.right * x * lensA + from.up * y * lensA * h / w + from.ahead), c = from.at
            let k = 60.268 / 54.364, cs = SIMD3(c.x, c.y, c.z * k), ds = SIMD3(d.x, d.y, d.z * k)
            let (qa, qb, qc) = (simd_dot(ds, ds), simd_dot(cs, ds), simd_dot(cs, cs) - 60.268 * 60.268)
            let planet = qb * qb - qa * qc > 0 ? (-qb - (qb * qb - qa * qc).squareRoot()) / qa : Double.infinity
            let plane = -c.z / d.z, p = c + plane * d, r = (p.x * p.x + p.y * p.y).squareRoot()
            var moves: [(SIMD3<Double>, Bool)]
            if plane > 0, plane < planet, r > 72.2, r < 141.9 {
                moves = [(p, false)]
                let sun = from.sun, flat = simd_normalize(SIMD3(sun.x, sun.y, sun.z * k)), along = simd_dot(SIMD3(p.x, p.y, 0), flat)
                if along < 0, abs((r * r - along * along).squareRoot() - 60.268) < 1 { moves.append((turned(p, by: b.sun - a.sun), false)) }
                let dr = abs(r - SaturnsRings.daphnis) * 1000
                if a.moon + b.moon > 0, dr > 17.5, dr < 1050 {
                    // the wave's height there, as the shader has it (its moon.y at 1)
                    let phi = atan2(p.y, p.x) - a.ahead / SaturnsRings.daphnis, down = (-(r > SaturnsRings.daphnis ? 1.0 : -1.0) * phi)
                    let theta = 2 * .pi * (down - 2 * .pi * (down / (2 * .pi)).rounded(.down)) * 136504 / (3 * .pi * dr)
                    if 2.5 * pow(17.5 / dr, 2) * exp(-theta / 25) > 0.1 || exp(-(dr - 17.5) / 8 - theta / 25) > 0.1 {
                        moves.append((turned(p, by: (b.ahead - a.ahead) / SaturnsRings.daphnis * 180 / .pi), false))
                    }
                }
            } else if planet < .infinity {
                let q = c + planet * d
                moves = [(q, false), (turned(q, by: b.sun - a.sun), false)]
            } else {
                moves = [(turned(d, by: b.sun - a.sun), true)] // the stars keep to the Sun's frame
            }
            for (point, far) in moves {
                guard let there = seen(point, far: far) else { return .infinity }
                most = max(most, simd_distance(there, SIMD2(x * w / 2, y * h / 2)))
            }
        }
    }
    return most
}

/// Each view's `pace` is the fastest thing on screen as it holds, measured at 30 fps through two swings of its drift
/// (out and back; Daphnis's along the gap and back), and at every Speed its battery rate is the lowest that holds
/// that to about 2 device pixels a frame (Sources/CLAUDE.md, Adding a scene): 10 fps at 1× would be wrong at 4×.
/// The mirrored lit face moves the same. Glides run at the battery's own 30. Prints what it found, and each glide's
/// fastest with `RINGS_PAIRS` set.
@Test func saturnsRingsMotionFitsTheBatteryRates() {
    let views = SaturnsRings.views, frame = 1.0 / 30
    var holds: [String] = []
    for view in views {
        for speed in [1.0, 0.5, 2, 4, 10] {
            let most = stride(from: 0, to: 2 * SaturnsRings.swing, by: 5).map {
                fastest(SaturnsRings.held(view, for: $0), SaturnsRings.held(view, for: $0 + frame * speed))
            }.max()! / frame
            if speed == 1 {
                holds.append(String(format: "%@ %.2f", view.name, most))
                #expect(most <= view.pace && most > 0.95 * view.pace, "\(view.name)'s pace is \(most) px/s")
            }
            let rate = SaturnsRings.rate(view, speed: speed), lower = [10, 12, 15, 20].last { $0 < rate ?? 30 }
            if let rate { #expect(most / Double(rate) <= 2, "\(view.name) at \(speed)×") }
            if let lower { #expect(most / Double(lower) > 2, "\(view.name) at \(speed)× could run at \(lower) fps") }
        }
    }
    #expect(SaturnsRings.rate(views[1], speed: 0) == 10)
    var glideMost = (0.0, "")
    for (i, a) in views.enumerated() {
        for (j, b) in views.enumerated() where i != j {
            let from = SaturnsRings.held(a, for: SaturnsRings.swing), to = SaturnsRings.held(b, for: 0)
            func at(_ t: Double) -> SaturnsRings.Camera {
                let u = min(max(t / SaturnsRings.glide, 0), 1)
                return SaturnsRings.between(from, to, u * u * (3 - 2 * u))
            }
            var pair = 0.0
            for t in stride(from: 0, to: SaturnsRings.glide, by: 1) {
                let most = fastest(at(t), at(t + frame), across: 32, up: 20) / frame
                pair = max(pair, most)
                if most > glideMost.0 { glideMost = (most, "\(a.name) to \(b.name), \(Int(t)) s in") }
            }
            if ProcessInfo.processInfo.environment["RINGS_PAIRS"] != nil { print(String(format: "  %@ to %@: %.0f px/s", a.name, b.name, pair)) }
        }
    }
    print("Saturn's Rings, fastest on screen in device px/s: holds: \(holds.joined(separator: ", ")); glides: "
          + String(format: "%.0f (%@)", glideMost.0, glideMost.1))
}

/// A strip of frames at 3024 × 1964, drawn as the desktop draws them at 15 and then 30 fps, through a glide
/// (`RINGS_STRIP=0>4`, Looking In to Over the Encke Gap, the views counted from 0) or a hold (`RINGS_STRIP=5@200`,
/// Daphnis Close from 200 s in, for `RINGS_SECONDS`, 12 by default), with any settings in `SNAPSHOT_DEFAULTS` as the
/// render test takes them (`saturn.face=1` for the lit face). Prints the frame-to-frame second difference
/// |f(t+1) − 2f(t) + f(t−1)| of the green channel, 1 pixel in 16, at its 99th and 99.9th percentiles (smooth motion
/// keeps it small; crawling bands and flashes make it large), the largest change in the frame's mean from one frame
/// to the next (an exposure jump); saves six frames, a quarter across, to `SNAPSHOT_DIR` to look at; and times 60
/// frames from the glide's middle (or the hold's start) as the render test does, without reading them back, which
/// slows the GPU's clock. Opt-in, as a glide is 1,800 and 3,600 frames:
///
///     RINGS_STRIP="0>4" SNAPSHOT_DIR=/some/dir swift test -c release -Xswiftc -enable-testing --filter saturnsRingsStrip
@MainActor @Test(.enabled(if: ProcessInfo.processInfo.environment["RINGS_STRIP"] != nil))
func saturnsRingsStrip() throws {
    let env = ProcessInfo.processInfo.environment, spec = env["RINGS_STRIP"] ?? ""
    let glide = spec.split(separator: ">").compactMap { Int($0) }, hold = spec.split(separator: "@").compactMap { Double($0) }
    let seconds = glide.count == 2 ? SaturnsRings.glide : Double(env["RINGS_SECONDS"] ?? "") ?? 12
    let settings = (env["SNAPSHOT_DEFAULTS"] ?? "").split(separator: ",").map { $0.split(separator: "=") }.filter { $0.count == 2 }
    for pair in settings { UserDefaults.standard.set(Double(pair[1]) ?? 0, forKey: String(pair[0])) }
    defer { for pair in settings { UserDefaults.standard.removeObject(forKey: String(pair[0])) } }
    let dir = URL(fileURLWithPath: env["SNAPSHOT_DIR"] ?? NSTemporaryDirectory() + "atrium-snapshots")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let device = try #require(MTLCreateSystemDefaultDevice()), queue = try #require(device.makeCommandQueue())
    let size = CGSize(width: 1512, height: 982), (w, h) = (3024, 1964)
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    let texture = try #require(device.makeTexture(descriptor: descriptor))
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = texture
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    func scene(at moment: Double) -> SaturnsRings {
        glide.count == 2 ? SaturnsRings(size: size, from: glide[0], to: glide[1], moment: moment)
            : SaturnsRings(size: size, from: Int(hold.first ?? 0), moment: (hold.count > 1 ? hold[1] : 0) + moment)
    }
    do {
        let renderer = SKRenderer(device: device), clock = ProcessInfo.processInfo.systemUptime + 1
        renderer.scene = scene(at: glide.count == 2 ? SaturnsRings.glide / 2 : 0)
        var cpu: [Double] = [], gpu: [Double] = []
        for frame in 0..<90 {
            let start = CFAbsoluteTimeGetCurrent()
            renderer.update(atTime: clock + Double(frame) / 30)
            let buffer = try #require(queue.makeCommandBuffer())
            renderer.render(withViewport: CGRect(x: 0, y: 0, width: w, height: h), commandBuffer: buffer, renderPassDescriptor: pass)
            buffer.commit()
            buffer.waitUntilCompleted()
            if frame >= 30 { gpu.append(buffer.gpuEndTime - buffer.gpuStartTime); cpu.append(CFAbsoluteTimeGetCurrent() - start - gpu.last!) }
        }
        print(String(format: "Saturn's Rings %@, %@: cpu %.2f ms, gpu %.2f ms a frame (medians)", spec, glide.count == 2 ? "mid-glide" : "the hold",
                     cpu.sorted()[cpu.count / 2] * 1000, gpu.sorted()[gpu.count / 2] * 1000))
    }
    for fps in [15.0, 30.0] {
        let strip = scene(at: 0)
        let renderer = SKRenderer(device: device)
        renderer.scene = strip
        let clock = ProcessInfo.processInfo.systemUptime + 1, count = Int(seconds * fps)
        var pixels = [UInt8](repeating: 0, count: w * h * 4), last: [[UInt8]] = [], histogram = [Int](repeating: 0, count: 511)
        var means: [Double] = []
        for frame in 0...count {
            renderer.update(atTime: clock + Double(frame) / fps)
            let buffer = try #require(queue.makeCommandBuffer())
            renderer.render(withViewport: CGRect(x: 0, y: 0, width: w, height: h), commandBuffer: buffer, renderPassDescriptor: pass)
            buffer.commit()
            buffer.waitUntilCompleted()
            texture.getBytes(&pixels, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
            let green = stride(from: 0, to: h, by: 4).flatMap { y in stride(from: 0, to: w, by: 4).map { pixels[(y * w + $0) * 4 + 1] } }
            means.append(Double(green.reduce(0) { $0 + Int($1) }) / Double(green.count))
            last = Array((last + [green]).suffix(3))
            if last.count == 3 {
                for i in green.indices { histogram[abs(Int(last[2][i]) - 2 * Int(last[1][i]) + Int(last[0][i]))] += 1 }
            }
            if frame % max(count / 5, 1) == 0 { try saveQuarter(pixels, w, h, to: dir.appendingPathComponent("rings-\(spec)-\(Int(fps))fps-\(frame).jpg")) }
        }
        let total = histogram.reduce(0, +)
        func percentile(_ p: Double) -> Int {
            var sum = 0
            for (value, n) in histogram.enumerated() { sum += n; if Double(sum) >= p * Double(total) { return value } }
            return 510
        }
        let jump = zip(means, means.dropFirst()).map { abs($1 - $0) }.max() ?? 0
        print(String(format: "Saturn's Rings %@ at %.0f fps: second difference 99th %d, 99.9th %d, max %d; mean's largest step %.2f",
                     spec, fps, percentile(0.99), percentile(0.999), histogram.lastIndex { $0 > 0 } ?? 0, jump))
    }
}

/// Saves BGRA `pixels` a quarter across as a JPEG.
private func saveQuarter(_ pixels: [UInt8], _ w: Int, _ h: Int, to url: URL) throws {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!, info = CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
    let image = try #require(CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: space,
                                     bitmapInfo: CGBitmapInfo(rawValue: info), provider: CGDataProvider(data: Data(pixels) as CFData)!,
                                     decode: nil, shouldInterpolate: false, intent: .defaultIntent))
    let small = try #require(CGContext(data: nil, width: w / 4, height: h / 4, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: info))
    small.interpolationQuality = .high
    small.draw(image, in: CGRect(x: 0, y: 0, width: w / 4, height: h / 4))
    let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, try #require(small.makeImage()), nil)
    #expect(CGImageDestinationFinalize(destination))
}

/// Horizons' Sun over Saturn's ring plane: its sub-solar latitude on Saturn (quantity 15, seen from the Earth's
/// centre), which is planetodetic, made planetocentric by tan φc = (1 − f)² tan φd with Saturn's flattening, 0.098.
/// Fetched from ssd.jpl.nasa.gov/api/horizons.api on 2026-11-19. The two equinoxes are the published ones (Cassini's
/// of 2009 and the one of 6 May 2025), and 2032-05-15 is near the solstice.
private let horizons: [(day: String, up: Double)] = [
    ("2009-08-11", -0.002), ("2025-05-06", 0.010), ("2026-11-18", -8.360), ("2028-06-01", -16.227), ("2032-05-15", -26.725),
    ("2036-01-01", -16.644), ("2038-10-15", -1.541), ("2039-01-15", -0.121), ("2039-06-01", 1.976),
]

private func day(_ text: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate]
    return formatter.date(from: text)!
}

/// The Sun's height over the ring plane from the date, by `SkyMath`'s orbit for Saturn and the IAU's pole, agrees
/// with JPL Horizons' to a tenth of a degree from Cassini's equinox to the next one, and the date pin is read.
@Test func saturnsRingsSunMatchesHorizons() {
    for (text, want) in horizons {
        let jd = Sky.julianDate(day(text)), got = asin(simd_dot(Sky.sun(from: .saturn, jd), SaturnsRings.pole(jd))) * 180 / .pi
        #expect(abs(got - want) < 0.1, "\(text): \(got)° against Horizons' \(want)°")
    }
    #expect(abs(SaturnsRings.light(on: day("2032-05-15")).up + 26.725) < 0.1)
    UserDefaults.standard.set("2032-05-15", forKey: "saturn.date")
    defer { UserDefaults.standard.removeObject(forKey: "saturn.date") }
    #expect(SaturnsRings.date == day("2032-05-15"))
}

/// The dates the Sun is `up` degrees over the ring plane near the 2039 equinox, found by halving between Horizons'
/// 2038-10-15 and 2039-06-01.
private func equinox(_ up: Double) -> Date {
    var (early, late) = (day("2038-10-15"), day("2039-06-01"))
    for _ in 0..<40 {
        let mid = early.addingTimeInterval(late.timeIntervalSince(early) / 2)
        if SaturnsRings.light(on: mid).up < up { early = mid } else { late = mid }
    }
    return early
}

/// Every view from both faces at six dates (today, mid-2028, the 2032 solstice, a Sun 1.5° south in 2038, and 0.1°
/// either side of the plane at the 2039 equinox), at 3024 × 1964: prints each one's luma (Rec. 709) at the median,
/// 99th, 99.9th and max, and saves it a quarter across to `SNAPSHOT_DIR` as `dates-<date>-<face>-<view>.jpg`, for
/// docs/saturns-rings/build-dates.jpg. Opt-in:
///
///     RINGS_DATES=1 SNAPSHOT_DIR=/some/dir swift test --filter saturnsRingsDates
@MainActor @Test(.enabled(if: ProcessInfo.processInfo.environment["RINGS_DATES"] != nil))
func saturnsRingsDates() throws {
    let dir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] ?? NSTemporaryDirectory() + "atrium-snapshots")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let device = try #require(MTLCreateSystemDefaultDevice()), queue = try #require(device.makeCommandQueue())
    let (w, h) = (3024, 1964)
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    let texture = try #require(device.makeTexture(descriptor: descriptor))
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = texture
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    defer { UserDefaults.standard.removeObject(forKey: SaturnsRings.face.key) }
    let dates = [("2026-11-19", day("2026-11-19")), ("2028-06-01", day("2028-06-01")), ("2032-05-15", day("2032-05-15")),
                 ("2038-10-15", day("2038-10-15")), ("south-0.1", equinox(-0.1)), ("north-0.1", equinox(0.1))]
    for (name, date) in dates {
        for lit in [false, true] {
            UserDefaults.standard.set(lit ? 1.0 : 0.0, forKey: SaturnsRings.face.key)
            for view in SaturnsRings.views.indices {
                let renderer = SKRenderer(device: device)
                // Daphnis Close as its tile has it, the moon 0.6 Mm ahead
                renderer.scene = SaturnsRings(size: CGSize(width: w / 2, height: h / 2), from: view, moment: SaturnsRings.views[view].moon == nil ? 0 : 300.3, date: date)
                renderer.update(atTime: 1)
                let buffer = try #require(queue.makeCommandBuffer())
                renderer.render(withViewport: CGRect(x: 0, y: 0, width: w, height: h), commandBuffer: buffer, renderPassDescriptor: pass)
                buffer.commit()
                buffer.waitUntilCompleted()
                var pixels = [UInt8](repeating: 0, count: w * h * 4)
                texture.getBytes(&pixels, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
                var histogram = [Int](repeating: 0, count: 256)
                for i in stride(from: 0, to: pixels.count, by: 4) {
                    histogram[min(255, Int((0.0722 * Double(pixels[i]) + 0.7152 * Double(pixels[i + 1]) + 0.2126 * Double(pixels[i + 2])).rounded()))] += 1
                }
                func percentile(_ p: Double) -> Int {
                    var sum = 0
                    for (value, n) in histogram.enumerated() { sum += n; if Double(sum) >= p * Double(w * h) { return value } }
                    return 255
                }
                print(String(format: "Saturn's Rings dates %@ %@ %d (Sun %.2f°): %d %d %d %d", name, lit ? "lit" : "unlit", view + 1,
                             SaturnsRings.light(on: date).up, percentile(0.5), percentile(0.99), percentile(0.999), histogram.lastIndex { $0 > 0 } ?? 0))
                try saveQuarter(pixels, w, h, to: dir.appendingPathComponent("dates-\(name)-\(lit ? "lit" : "unlit")-\(view + 1).jpg"))
            }
        }
    }
}

/// A tenth of a degree either side of the plane, as at the 2039 equinox: the camera is on the side the Sun isn't (or
/// is, lit), the light is kept off the plane itself, and every view draws with no pixel black (where a division by
/// nothing would leave a NaN) and none flat.
@MainActor @Test func saturnsRingsDrawAtTheEquinox() throws {
    let device = try #require(MTLCreateSystemDefaultDevice()), queue = try #require(device.makeCommandQueue())
    let (w, h) = (756, 491)
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    let texture = try #require(device.makeTexture(descriptor: descriptor))
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = texture
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    defer { UserDefaults.standard.removeObject(forKey: SaturnsRings.face.key) }
    for up in [-0.1, 0.1] {
        let date = equinox(up)
        #expect(abs(SaturnsRings.light(on: date).up - up) < 0.01)
        for lit in [false, true] {
            UserDefaults.standard.set(lit ? 1.0 : 0.0, forKey: SaturnsRings.face.key)
            let axes = SaturnsRings.Camera(r: 126, h: 4, yaw: 38, pitch: 7, field: 70, sun: 320).axes(lit: lit, sunUp: up)
            #expect((axes.at.z > 0) == ((axes.sun.z < 0) != lit), "the camera's side at \(up)°, lit \(lit)")
            for view in SaturnsRings.views.indices {
                let renderer = SKRenderer(device: device)
                renderer.scene = SaturnsRings(size: CGSize(width: w / 2, height: h / 2), from: view, moment: 0, date: date)
                renderer.update(atTime: 1)
                let buffer = try #require(queue.makeCommandBuffer())
                renderer.render(withViewport: CGRect(x: 0, y: 0, width: w, height: h), commandBuffer: buffer, renderPassDescriptor: pass)
                buffer.commit()
                buffer.waitUntilCompleted()
                var pixels = [UInt32](repeating: 0, count: w * h)
                texture.getBytes(&pixels, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
                let black = pixels.count { $0 & 0xFFFFFF == 0 }, colours = Set(stride(from: 0, to: pixels.count, by: 97).map { pixels[$0] })
                #expect(black == 0 && colours.count > 20, "\(SaturnsRings.views[view].name) at \(up)°, lit \(lit): \(black) black pixels")
            }
        }
    }
}
