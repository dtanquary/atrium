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

    // The A ring's own, a sample a km: the same, with boxes up to 8 km; the Encke gap's edges sharp (10 km in, the ring;
    // 5 km on, nothing); and the Keeler gap inside the one drawn from its own edges, 17.5 km either side of Daphnis's
    // orbit, so no second edge shows beside that one.
    start = CFAbsoluteTimeGetCurrent()
    let fine = RingProfile.loadFine(), fineBytes = fine.pyramidBytes(levels: RingProfile.fineLevels)
    print(String(format: "Saturn's Rings: the fine profile read and its pyramid baked in %.1f ms", (CFAbsoluteTimeGetCurrent() - start) * 1000))
    let count = fine.tau.count, fineLevels = RingProfile.fineLevels
    #expect(count == 16384 && count == RingProfile.fineCount && fineBytes.count == count * RingProfile.ks * fineLevels * 4)
    func fineValue(_ j: Int, _ m: Int, _ i: Int) -> Int { let at = ((j * fineLevels + m) * count + i) * 4; return Int(fineBytes[at]) << 8 | Int(fineBytes[at + 1]) }
    for j in [0, 5, 11] {
        for i in stride(from: 4, to: count - 4, by: 7) {
            #expect(abs(fineValue(j, 0, i) - Int(exp(-fine.tau[i] * pow(2, Double(j))) * 65535)) <= 1)
            #expect(abs(2 * fineValue(j, 3, i) - fineValue(j, 2, i - 2) - fineValue(j, 2, i + 2)) <= 3)
        }
    }
    /// The fine profile's τ at a radius in km.
    func tau(_ km: Double) -> Double { fine.tau[Int((km / 1000 - fine.start) / fine.step + 0.5)] }
    #expect(tau(133_415) > 0.4 && tau(133_430) == 0 && tau(133_600) == 0 && tau(133_750) > 0.4, "the Encke gap's edges")
    #expect(tau(136_486) > 0.4 && tau(136_504) == 0 && tau(136_522) > 0.4, "the Keeler gap within Daphnis's")
    #expect(tau(136_760) > 1 && tau(136_770) == 0, "the A ring's edge")
}

/// The planet's strip of colour by latitude is read, stays in the buttercream family from pole to pole (red over
/// green over blue, and no greyer than the belts' colour), and is brightest in the equatorial zone (within 15° of the
/// equator) and darkest toward a pole (past 70°).
@Test func saturnsRingsGlobeStaysButtercream() {
    let (texels, brightest) = SaturnGlobe.shared, n = texels.count / 4
    #expect(n == 512 && brightest > 0.4 && brightest < 0.6)
    let colours = (0..<n).map { (Double(texels[4 * $0]), Double(texels[4 * $0 + 1]), Double(texels[4 * $0 + 2])) }
    #expect(colours.allSatisfy { $0.0 > $0.1 && $0.1 > $0.2 && $0.0 - $0.2 > 40 })
    let lumas = colours.map { 0.2126 * $0.0 + 0.7152 * $0.1 + 0.0722 * $0.2 }
    let (most, least) = (lumas.indices.max { lumas[$0] < lumas[$1] }!, lumas.indices.min { lumas[$0] < lumas[$1] }!)
    #expect(abs(most - n / 2) < n / 12 && (least < n / 9 || least > n - n / 9), "brightest \(most), darkest \(least) of \(n)")
}

/// `RingProfile.load` reads the whole file as a line-by-line read finds it: every row's optical depth and brightness,
/// and where the rows start.
@Test func saturnsRingsProfileReadsWhole() throws {
    let rows = try String(contentsOf: resource("saturn-rings.tsv"), encoding: .utf8).split(whereSeparator: \.isNewline)
        .filter { !$0.hasPrefix("#") }.map { $0.split(separator: "\t").compactMap { Double($0) } }
    let profile = RingProfile.load()
    #expect(rows.count > 8000 && rows.allSatisfy { $0.count == 3 })
    #expect(profile.tau == rows.map { $0[1] } && profile.brightness == rows.map { $0[2] })
    #expect(abs(profile.start - rows[0][0] / 1000) < 1e-12 && abs(profile.step - (rows[1][0] - rows[0][0]) / 1000) < 1e-12)
}

/// How long the main thread takes to build the scene at its standards (Fly Through under Alternate) and draw its
/// first frame at 3024 × 1964: the first copy, which makes the shared textures (the pyramids, the star grid, the Milky
/// Way's glow read from its JPEG) and reads the loop's table, and a second, which shares them. Prints them;
/// docs/saturns-rings.md, Cost, has a release build's. With `RINGS_WARM` a JPEG is decoded first, as the app's menu
/// and Settings will have done before anyone switches to the wallpaper; with `RINGS_PARTS` it prints what each part
/// of the first copy takes by itself instead, and what the two it no longer does took (working out the loops' tables
/// and reading Black Hole's HEIC, which starts the HEIC decoder: last, so they warm nothing before them).
@MainActor @Test func saturnsRingsBuildTime() throws {
    let env = ProcessInfo.processInfo.environment
    /// Decodes a picture in Resources in full, as building a texture from it does.
    func decode(_ name: String, thumbnail: Bool = false) {
        guard let source = CGImageSourceCreateWithURL(resource(name) as CFURL, nil) else { return }
        let options = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 1024, kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        _ = thumbnail ? CGImageSourceCreateThumbnailAtIndex(source, 0, options) : CGImageSourceCreateImageAtIndex(source, 0, options)
    }
    if env["RINGS_WARM"] != nil { decode("preview-saturns-rings.jpg") }
    if env["RINGS_PARTS"] != nil {
        func time(_ what: String, _ body: () -> Void) {
            let start = CFAbsoluteTimeGetCurrent()
            body()
            print(String(format: "Saturn's Rings build, %@: %.1f ms", what, (CFAbsoluteTimeGetCurrent() - start) * 1000))
        }
        time("the profile read") { _ = RingProfile.shared }
        time("the pyramid baked") { _ = RingProfile.shared.pyramidBytes() }
        time("the fine pyramid read and baked") { _ = RingProfile.loadFine().pyramid(levels: RingProfile.fineLevels) }
        time("the star grid") { _ = BlackHole.starCells() }
        time("the glow's JPEG") { decode("saturn-glow.jpg") }
        time("the loops' tables read") { _ = (SaturnsRings.flight, SaturnsRings.alternateFlight) }
        time("the one-face loop's table worked out") { _ = SaturnsRings.flightTime() }
        time("the two-lap loop's table worked out") { _ = SaturnsRings.flightTime(knots: SaturnsRings.alternateKnots) }
        time("Black Hole's HEIC glow, at 1,024") { decode("blackhole-glow.heic", thumbnail: true) }
        return
    }
    let device = try #require(MTLCreateSystemDefaultDevice()), queue = try #require(device.makeCommandQueue())
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 3024, height: 1964, mipmapped: false)
    descriptor.usage = [.renderTarget]
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = try #require(device.makeTexture(descriptor: descriptor))
    var held: [SaturnsRings] = [] // so the second copy shares the first's textures
    var times: [String] = []
    for copy in ["first", "second"] {
        var start = CFAbsoluteTimeGetCurrent()
        let scene = SaturnsRings(size: CGSize(width: 1512, height: 982), moment: 0)
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
                SaturnsRings.motion(SaturnsRings.held(view, for: $0), SaturnsRings.held(view, for: $0 + frame * speed))
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
                let most = SaturnsRings.motion(at(t), at(t + frame), across: 32, up: 20) / frame
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
/// (`RINGS_STRIP=0>4`, Looking In to Over the Encke Gap, the views counted from 0), a hold (`RINGS_STRIP=5@200`,
/// Daphnis Close from 200 s in) or Fly Through (`RINGS_STRIP=fly@1740`, from 1,740 s round its loop at 1×), for
/// `RINGS_SECONDS` (12 by default) but for a glide, with any settings in `SNAPSHOT_DEFAULTS` as the
/// render test takes them (`saturn.face=1` for the lit face), and with `RINGS_FACE` the face set to that as the strip
/// begins (so a held view crosses to it and back); where the camera changes faces it also prints how far the frames
/// either side of the change differ, every pixel. Prints the frame-to-frame second difference
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
    let glide = spec.split(separator: ">").compactMap { Int($0) }, hold = spec.split(separator: "@").compactMap { Double($0) }, flies = spec.hasPrefix("fly@")
    let seconds = glide.count == 2 ? SaturnsRings.glide : Double(env["RINGS_SECONDS"] ?? "") ?? 12
    let settings = (env["SNAPSHOT_DEFAULTS"] ?? "").split(separator: ",").map { $0.split(separator: "=") }.filter { $0.count == 2 }
    // a view held in Cycle, or the loop, from the lit face, unless SNAPSHOT_DEFAULTS says otherwise (the standards
    // are Fly Through and Alternate)
    UserDefaults.standard.set(flies ? 7.0 : 0.0, forKey: SaturnsRings.view.key)
    UserDefaults.standard.set(1.0, forKey: SaturnsRings.face.key)
    defer { [SaturnsRings.view.key, SaturnsRings.face.key].forEach(UserDefaults.standard.removeObject) }
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
        flies ? SaturnsRings(size: size, fly: true, moment: (hold.last ?? 0) + moment)
            : glide.count == 2 ? SaturnsRings(size: size, from: glide[0], to: glide[1], moment: moment)
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
        print(String(format: "Saturn's Rings %@, %@: cpu %.2f ms, gpu %.2f ms a frame (medians)", spec, glide.count == 2 ? "mid-glide" : flies ? "flying" : "the hold",
                     cpu.sorted()[cpu.count / 2] * 1000, gpu.sorted()[gpu.count / 2] * 1000))
    }
    for fps in [15.0, 30.0] {
        if let face = env["RINGS_FACE"].flatMap(Double.init) { UserDefaults.standard.set(1 - face, forKey: SaturnsRings.face.key) }
        let strip = scene(at: 0)
        if let face = env["RINGS_FACE"].flatMap(Double.init) { UserDefaults.standard.set(face, forKey: SaturnsRings.face.key) }
        var lastLit = strip.camera().lit, lastPixels: [UInt8] = [], beforeLast: [UInt8] = []
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
            if strip.camera().lit != lastLit, !lastPixels.isEmpty {
                let differences = zip(pixels, lastPixels).enumerated().filter { $0.offset % 4 != 3 }.map { abs(Int($0.element.0) - Int($0.element.1)) }
                let before = zip(lastPixels, beforeLast).enumerated().filter { $0.offset % 4 != 3 }.map { abs(Int($0.element.0) - Int($0.element.1)) }
                print(String(format: "Saturn's Rings %@ at %.0f fps changes faces at frame %d: the frames either side differ by %d levels at most, %d values by more than 2 (the two frames before: %d, %d)",
                             spec, fps, frame, differences.max() ?? 0, differences.count { $0 > 2 }, before.max() ?? 0, before.count { $0 > 2 }))
                let worst = (0..<w * h).map { i in (i, (0..<3).map { abs(Int(pixels[i * 4 + $0]) - Int(lastPixels[i * 4 + $0])) }.max()!) }.filter { $0.1 > 2 }
                print("  where: " + worst.sorted { $0.1 > $1.1 }.prefix(12).map { String(format: "(%d, %d) %d: %d,%d,%d to %d,%d,%d", $0.0 % w, $0.0 / w, $0.1,
                    lastPixels[$0.0 * 4 + 2], lastPixels[$0.0 * 4 + 1], lastPixels[$0.0 * 4], pixels[$0.0 * 4 + 2], pixels[$0.0 * 4 + 1], pixels[$0.0 * 4]) }.joined(separator: "; "))
                try saveQuarter(lastPixels, w, h, to: dir.appendingPathComponent("rings-\(spec)-\(Int(fps))fps-before-change.jpg"))
                try saveQuarter(pixels, w, h, to: dir.appendingPathComponent("rings-\(spec)-\(Int(fps))fps-after-change.jpg"))
            }
            (lastLit, beforeLast, lastPixels) = (strip.camera().lit, lastPixels, pixels)
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
/// with JPL Horizons' to a tenth of a degree from Cassini's equinox to the next one, and the date pin is read. On
/// the main actor, as every test that changes a setting must be: the change is announced on the thread that makes
/// it, and off the main one it trapped in whichever scene another test had alive and listening (Pixel City's and
/// Pixel Train's `settingsChanged`, twice on 2026-11-21).
@MainActor @Test func saturnsRingsSunMatchesHorizons() {
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
    defer { [SaturnsRings.face.key, SaturnsRings.view.key].forEach(UserDefaults.standard.removeObject) }
    UserDefaults.standard.set(0.0, forKey: SaturnsRings.view.key) // the views held, in Cycle, not gliding onto Fly Through
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
    defer { [SaturnsRings.face.key, SaturnsRings.view.key].forEach(UserDefaults.standard.removeObject) }
    UserDefaults.standard.set(0.0, forKey: SaturnsRings.view.key) // the views held, in Cycle, not gliding onto Fly Through
    for up in [-0.1, 0.1] {
        let date = equinox(up)
        #expect(abs(SaturnsRings.light(on: date).up - up) < 0.01)
        for lit in [false, true] {
            UserDefaults.standard.set(lit ? 1.0 : 0.0, forKey: SaturnsRings.face.key)
            let axes = SaturnsRings.Camera(r: 126, h: 4, yaw: 38, pitch: 7, field: 70, sun: 320, lit: lit).axes(sunUp: up)
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

/// Fly Through's loop stays above the ring plane and outside the planet all the way round, with the Sun never within
/// 30° of behind the planet, passes through each view exactly (so the picture there is its tile), and is smooth:
/// every number's rate of change runs on unbroken through the views, as a spline's should.
@Test func saturnsRingsFlightStaysClear() {
    let order = SaturnsRings.flightOrder, n = order.count, steps = 240 * n
    for lit in [false, true] {
        let cameras = (0...steps + 1).map { SaturnsRings.path(Double($0) / 240, lit: lit) }
        for (i, camera) in cameras.enumerated() {
            let outside = pow(camera.r / 60.268, 2) + pow(camera.h / 54.364, 2)
            #expect(camera.h > 0.08 && outside > 1.5 && abs(remainder(camera.sun - 180, 360)) > 30 && (0...1).contains(camera.moon),
                    "at \(Double(i) / 240): r \(camera.r), h \(camera.h), the Sun at \(camera.sun)°, Daphnis \(camera.moon)")
        }
        for (k, view) in order.enumerated() {
            let want = SaturnsRings.held(SaturnsRings.views[view], for: 0, lit: lit), got = cameras[240 * k]
            #expect(abs(got.r - want.r) + abs(log(got.h / want.h)) + abs(got.yaw - want.yaw) + abs(got.pitch - want.pitch) + abs(got.field - want.field)
                    + abs(remainder(got.sun - want.sun, 360)) + abs(log(got.exposure / want.exposure)) < 1e-9, "\(SaturnsRings.views[view].name)")
        }
        // Smooth: a kink, where a number's rate jumps, makes its second difference from one sample to the next as big
        // as the jump times the step, where a smooth curve's is its bend times the step squared; so a kink stands out
        // as a spike, many times its neighbours. Daphnis's distance ahead counts only where it shows.
        func numbers(_ c: SaturnsRings.Camera) -> [Double] { [c.r, log(c.h), c.yaw, c.pitch, c.field, SaturnsRings.clear(c.sun), log(c.exposure), c.moon, c.ahead] }
        let all = cameras.map(numbers)
        for k in all[0].indices {
            let bends = (1..<all.count - 1).map { abs(all[$0 + 1][k] - 2 * all[$0][k] + all[$0 - 1][k]) }
            for i in 2..<bends.count - 2 where k != 8 || cameras[i].moon > 0 && cameras[i + 2].moon > 0 {
                let around = max(bends[i - 2], bends[i + 2], 1e-9)
                #expect(bends[i] < 8 * around + 1e-7, "number \(k) kinks at \(Double(i + 1) / 240): \(bends[i]) against \(around)")
            }
        }
    }
}

/// The loops' tables kept in Resources/saturn-flight.tsv are the ones `flightTime` works out now, to a millisecond: a
/// view, the order or the pace changed without the file leaves the camera flying the old loop's timing. To write the
/// file again:
///
///     RINGS_TABLES=1 swift test --filter saturnsRingsFlightTablesAreKept
@Test func saturnsRingsFlightTablesAreKept() throws {
    let tables = [("one", SaturnsRings.route(), SaturnsRings.flightTime()), ("two", SaturnsRings.alternateKnots, SaturnsRings.flightTime(knots: SaturnsRings.alternateKnots))]
    if ProcessInfo.processInfo.environment["RINGS_TABLES"] != nil {
        let header = """
            # Saturn's Rings: the seconds Fly Through takes at Speed 1× to reach each 1/120 of the way between its views, round
            # the one-face loop ("one") and the two-lap loop Alternate flies ("two"), as SaturnsRings.flightTime works them out.
            # Kept so the scene needn't work them out as it's built. Written by: RINGS_TABLES=1 swift test --filter saturnsRingsFlightTablesAreKept

            """
        let lines = tables.map { name, _, table in ([name] + table.map { String(format: "%.4f", $0) }).joined(separator: "\t") }
        try (header + lines.joined(separator: "\n") + "\n").write(to: resource("saturn-flight.tsv"), atomically: true, encoding: .utf8)
    }
    for (name, knots, table) in tables {
        let kept = try #require(SaturnsRings.keptFlight(name, knots: knots), "no table for the \(name) loop in saturn-flight.tsv")
        #expect(zip(kept, table).allSatisfy { abs($0 - $1) < 0.001 }, "saturn-flight.tsv's \(name) loop is stale: RINGS_TABLES=1 swift test --filter saturnsRingsFlightTablesAreKept")
    }
}

/// Fly Through goes at an even pace: round the loop at Speed 1×, the fastest thing on screen moves at about
/// `flightPace` device px a second throughout, never slowing near a stop, and never more than `flightMost`, which the
/// battery rate rests on; and the ground under the camera never crosses more than twice `calm` of its height a second
/// (the loop went at half this pace, within `calm`, until Dave's review pass: he ran it at 2×, so that is now 1×).
/// Prints the loop's length and what it found.
@Test func saturnsRingsFlightKeepsAnEvenPace() {
    let length = SaturnsRings.flight.last!, frame = 1.0 / 30
    var (least, most, ground, fastest) = (Double.infinity, 0.0, 0.0, 0.0)
    for seconds in stride(from: 0, to: length, by: 1) {
        let (a, b) = (SaturnsRings.flying(seconds), SaturnsRings.flying(seconds + frame))
        let moved = SaturnsRings.motion(a, b, across: 32, up: 20) / frame
        if moved > most { fastest = seconds }
        (least, most) = (min(least, moved), max(most, moved))
        ground = max(ground, abs(b.r - a.r) / frame / min(a.h, b.h))
    }
    print(String(format: "Saturn's Rings Fly Through: %.0f s round at 1× (%.1f min); the fastest thing on screen %.1f to %.1f px/s (its most %.0f s round); the ground's pace at most %.4f of the height a second",
                 length, length / 60, least, most, fastest, ground))
    print("Saturn's Rings Fly Through passes " + SaturnsRings.flightOrder.map { String(format: "%@ at %.0f s", SaturnsRings.views[$0].name, SaturnsRings.flightSeconds(at: $0)) }.joined(separator: ", "))
    #expect(least > 0.5 * SaturnsRings.flightPace && most <= SaturnsRings.flightMost && ground <= 2 * SaturnsRings.calm)
    #expect(SaturnsRings.flightRate(speed: 1).map { SaturnsRings.flightMost / Double($0) <= 2 } ?? true)
}

/// The loop's length at its even pace for every order of the views that keeps the low two (the Encke gap and
/// Daphnis Close) side by side, from Looking In, both ways round: prints them, shortest first. Opt-in:
///
///     RINGS_ORDERS=1 swift test -c release -Xswiftc -enable-testing --filter saturnsRingsFlightOrders
@Test(.enabled(if: ProcessInfo.processInfo.environment["RINGS_ORDERS"] != nil))
func saturnsRingsFlightOrders() {
    func orders(_ rest: [Int]) -> [[Int]] { rest.isEmpty ? [[]] : rest.flatMap { first in orders(rest.filter { $0 != first }).map { [first] + $0 } } }
    let candidates = orders([1, 2, 3, 4, 5]).map { [0] + $0 }.filter { order in
        let e = order.firstIndex(of: 4)!, f = order.firstIndex(of: 5)!
        return abs(e - f) == 1 || abs(e - f) == order.count - 1
    }
    let names = ["A", "B", "C", "D", "E", "F"]
    let timed = candidates.map { ($0, SaturnsRings.flightTime(order: $0).last!) }.sorted { $0.1 < $1.1 }
    for (order, seconds) in timed { print(String(format: "Saturn's Rings flight order %@: %.0f s", order.map { names[$0] }.joined(), seconds)) }
}

/// Switching between Fly Through, a view and Cycle, and back, at whatever moment, never makes the camera jump: from
/// one frame to the next at 30 fps no number moves more than a glide or the loop moves it, whether it was holding,
/// flying or partway through a glide. (The loop at 60 px/s moves the camera out or in by up to 0.021 Mm a frame, high
/// over the rings: twice what it did at 30, so that bound is twice what it was.)
@MainActor @Test func saturnsRingsSwitchesSmoothly() {
    let key = SaturnsRings.view.key
    defer { UserDefaults.standard.removeObject(forKey: key) }
    UserDefaults.standard.set(7.0, forKey: key)
    let scene = SaturnsRings(size: CGSize(width: 320, height: 200), moment: 0)
    // Fly Through, then Daphnis Close picked 30 s in, Fly Through again partway through that glide, Cycle once on the
    // loop, Along the Planet's Edge as Cycle glides off it, and Fly Through from that view's hold
    let picks: [(at: Double, view: Double)] = [(30, 6), (90, 7), (300, 0), (330, 3), (520, 7)]
    var last = scene.camera()
    for frame in 1...(700 * 30) {
        let seconds = Double(frame) / 30
        if let pick = picks.first(where: { abs($0.at - seconds) < 0.5 / 30 }) { UserDefaults.standard.set(pick.view, forKey: key) }
        scene.update(seconds)
        let now = scene.camera()
        let jump = [abs(now.r - last.r) / 0.04, abs(log(now.h / last.h)) / 0.01, abs(remainder(now.yaw - last.yaw, 360)) / 0.3,
                    abs(now.pitch - last.pitch) / 0.3, abs(remainder(now.sun - last.sun, 360)) / 0.3, abs(log(now.exposure / last.exposure)) / 0.01].max()!
        #expect(jump < 1, "at \(seconds) s: r \(last.r) to \(now.r), h \(last.h) to \(now.h), yaw \(last.yaw) to \(now.yaw), the Sun \(last.sun) to \(now.sun)")
        if jump >= 1 { break }
        last = now
    }
}

/// Fly Through at twelve moments evenly round its loop, from both faces, at 3024 × 1964: prints each one's luma
/// (Rec. 709) at the median, 99th, 99.9th and max, and saves it a quarter across to `SNAPSHOT_DIR` as
/// `fly-<face>-<moment>.jpg`, for docs/saturns-rings/build-flythrough.jpg; and times building the loop. Opt-in:
///
///     RINGS_FLY=1 SNAPSHOT_DIR=/some/dir swift test -c release -Xswiftc -enable-testing --filter saturnsRingsFlightMoments
@MainActor @Test(.enabled(if: ProcessInfo.processInfo.environment["RINGS_FLY"] != nil))
func saturnsRingsFlightMoments() throws {
    let start = CFAbsoluteTimeGetCurrent()
    _ = SaturnsRings.flightTime()
    print(String(format: "Saturn's Rings Fly Through: its loop worked out in %.0f ms", (CFAbsoluteTimeGetCurrent() - start) * 1000))
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
    defer { [SaturnsRings.face.key, SaturnsRings.view.key].forEach(UserDefaults.standard.removeObject) }
    UserDefaults.standard.set(7.0, forKey: SaturnsRings.view.key) // or the scene glides off the loop, for Cycle
    let length = SaturnsRings.flight.last!
    for lit in [true, false] {
        UserDefaults.standard.set(lit ? 1.0 : 0.0, forKey: SaturnsRings.face.key)
        for k in 0..<12 {
            let seconds = length * Double(k) / 12, renderer = SKRenderer(device: device)
            renderer.scene = SaturnsRings(size: CGSize(width: w / 2, height: h / 2), fly: true, moment: seconds, date: day("2026-11-19"))
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
            print(String(format: "Saturn's Rings fly %@ %d (%.0f s): %d %d %d %d", lit ? "lit" : "unlit", k, seconds,
                         percentile(0.5), percentile(0.99), percentile(0.999), histogram.lastIndex { $0 > 0 } ?? 0))
            try saveQuarter(pixels, w, h, to: dir.appendingPathComponent("fly-\(lit ? "lit" : "unlit")-\(k).jpg"))
        }
    }
}

/// Where a camera is, and which way it faces, in the world: the face and the turn together.
private func pose(_ camera: SaturnsRings.Camera) -> (at: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>) {
    let axes = camera.axes()
    return (axes.at, axes.right, axes.up)
}

/// The rules a camera keeps, frame by frame or sample by sample, changing faces or not: it is never nearer the ring
/// plane than 180 m, nor nearer than 100 km over ring material (Daphnis Close is 120 km up), and it changes faces
/// only out at the crossing point, 150 Mm out and 200 m off the plane, where the world doesn't move as it does.
private func keepsClear(_ cameras: [SaturnsRings.Camera], _ what: String) {
    for (i, camera) in cameras.enumerated() {
        let r = (camera.r * camera.r).squareRoot()
        #expect(camera.h >= 0.00018 && (r >= 141.9 || camera.h >= 0.1) && pow(r / 60.268, 2) + pow(camera.h / 54.364, 2) > 1.5,
                "\(what), \(i): r \(camera.r), h \(camera.h)")
        if i > 0, cameras[i - 1].lit != camera.lit {
            let (a, b) = (pose(cameras[i - 1]), pose(camera))
            #expect(camera.r >= 145 && camera.h <= 0.00022 && simd_distance(a.at, b.at) < 0.005 && simd_distance(a.right, b.right) < 0.01
                    && simd_distance(a.up, b.up) < 0.01, "\(what), \(i): changed faces at r \(camera.r), h \(camera.h), moving \(simd_distance(a.at, b.at)) Mm, turning \(simd_distance(a.right, b.right)) and \(simd_distance(a.up, b.up))")
        }
    }
}

/// Every crossing glide, from each view (on either face, anywhere in its drift) to the crossing point, and from it
/// to each view on the other face, and the two-lap loop Alternate flies, keep clear of the rings; and the two-lap loop
/// goes at the even pace the one-face loop does, which its battery rate rests on.
@Test func saturnsRingsCrossingsStayClear() {
    for lit in [false, true] {
        for view in SaturnsRings.views {
            for drift in [0, SaturnsRings.swing / 2] {
                let there = SaturnsRings.crossing(lit: lit), from = SaturnsRings.held(view, for: drift, lit: lit)
                keepsClear((0...200).map { SaturnsRings.between(from, there, Double($0) / 200) }, "\(view.name) to the crossing")
            }
            let away = SaturnsRings.crossing(lit: !lit, leaving: true), to = SaturnsRings.held(view, for: 0, lit: !lit)
            keepsClear((0...200).map { SaturnsRings.between(away, to, Double($0) / 200) }, "the crossing to \(view.name)")
        }
    }
    let knots = SaturnsRings.alternateKnots, steps = 240 * knots.count
    let lap = (0...steps).map { SaturnsRings.path(Double($0) / 240, knots: knots) }
    keepsClear(lap, "the two-lap loop")
    #expect(zip(lap, lap.dropFirst()).count { $0.lit != $1.lit } == 2, "the two-lap loop changes faces twice")
    let length = SaturnsRings.alternateFlight.last!, frame = 1.0 / 30
    var (least, most) = (Double.infinity, 0.0)
    for seconds in stride(from: 0, to: length, by: 1) {
        let moved = SaturnsRings.motion(SaturnsRings.flying(seconds, alternating: true), SaturnsRings.flying(seconds + frame, alternating: true), across: 32, up: 20) / frame
        (least, most) = (min(least, moved), max(most, moved))
    }
    print(String(format: "Saturn's Rings two-lap loop: %.0f s round at 1× (%.1f min, a lap %.1f); the fastest thing on screen %.1f to %.1f px/s",
                 length, length / 60, length / 120, least, most))
    #expect(least > 0.5 * SaturnsRings.flightPace && most <= SaturnsRings.alternateMost)
}

/// Runs `scene` frame by frame at 10 fps (the scene's own clock goes no faster than that a frame) for `seconds`, from
/// `start` on its frame clock, and returns its camera at every frame.
@MainActor private func run(_ scene: SaturnsRings, for seconds: Double, from start: Double = 0) -> [SaturnsRings.Camera] {
    (1...Int(seconds * 10)).map { frame in
        scene.update(start + Double(frame) / 10)
        return scene.camera()
    }
}

/// The camera never jumps: from one frame to the next its place and its axes in the world move by about as much as
/// they did the frame before (a quarter more or less, or 3 km and 0.003 of a turn, which takes in the 0.4 km step through
/// the plane as it changes faces), so its speed has no break, through a change of faces as anywhere.
private func smooth(_ cameras: [SaturnsRings.Camera], _ what: String) {
    let steps = zip(cameras, cameras.dropFirst()).map { a, b -> SIMD3<Double> in
        let (p, q) = (pose(a), pose(b))
        return SIMD3(simd_distance(p.at, q.at), simd_distance(p.right, q.right), simd_distance(p.up, q.up))
    }
    for i in 1..<steps.count {
        let change = abs(steps[i] - steps[i - 1]), allowed = 0.25 * simd_max(steps[i], steps[i - 1]) + SIMD3(0.003, 0.003, 0.003)
        #expect(all(change .<= allowed), "\(what), frame \(i): moved \(steps[i - 1]) then \(steps[i])")
        if !all(change .<= allowed) { return }
    }
}

/// The camera never stops at the crossing point: at each change of faces, the fastest thing on screen moves at least
/// `least` of its mean pace over the move round it, two glides' length (up to 0.130.15 a crossing was two glides, each
/// eased to a stop there, so it moved 0). Prints the pace there, the mean, the slowest in the middle 80% of the move and
/// the pace every 10 s, in device px a second at 1×.
private func keepsMoving(_ cameras: [SaturnsRings.Camera], _ what: String, least: Double = 0.3) {
    let half = Int(SaturnsRings.glide * 10)
    for i in cameras.indices.dropFirst() where cameras[i - 1].lit != cameras[i].lit {
        func pace(_ j: Int) -> Double { SaturnsRings.motion(cameras[j - 1], cameras[j], across: 24, up: 16) * 10 }
        let move = Array(max(i - half, 1)..<min(i + half, cameras.count)), paces = move.map(pace)
        let mean = paces.reduce(0, +) / Double(paces.count), there = pace(i)
        let middle = paces[paces.count / 10..<paces.count * 9 / 10].min()!
        print(String(format: "Saturn's Rings %@, through the plane at %.0f px/s: the move's mean %.0f, the slowest in its middle 80%% %.0f; every 10 s: %@",
                     what, there, mean, middle, stride(from: 0, to: paces.count, by: 100).map { String(format: "%.0f", paces[$0]) }.joined(separator: " ")))
        #expect(there >= least * mean, "\(what): through the plane at \(there) px/s, the move's mean \(mean)")
    }
}

/// The faces in use: a view held under Alternate changes faces after half an hour, by the crossing point, and comes
/// back to the same view; under Follow the camera changes faces when the appearance does, from a held view and from
/// partway through a glide (going on to a view picked on its way to the plane); Cycle under Alternate changes faces
/// every other glide; and Fly Through under Alternate changes them once a lap. In every case the camera keeps clear
/// of the rings, never jumps, and never stops at the crossing point.
@MainActor @Test func saturnsRingsChangeFaces() {
    let keys = [SaturnsRings.view.key, SaturnsRings.face.key, SaturnsRings.hold.key]
    defer { keys.forEach(UserDefaults.standard.removeObject); NSApplication.shared.appearance = nil }
    let size = CGSize(width: 320, height: 200), hold = SaturnsRings.crossEvery

    // a held view under Alternate: lit to begin with, over to the unlit face after half an hour, back on Along the Planet's Edge
    UserDefaults.standard.set(3.0, forKey: keys[0])
    UserDefaults.standard.set(2.0, forKey: keys[1])
    var cameras = run(SaturnsRings(size: size, moment: 0), for: hold + 2 * SaturnsRings.glide + 10)
    keepsClear(cameras, "a held view")
    smooth(cameras, "a held view")
    keepsMoving(cameras, "a held view")
    let back = SaturnsRings.held(SaturnsRings.views[2], for: 0, lit: false), last = cameras.last!
    #expect(cameras.first!.lit && !last.lit && abs(last.h - back.h) < 0.01 && abs(last.yaw - back.yaw) < 0.01 && abs(last.r - back.r) < 0.1,
            "back on its view, on the other face: r \(last.r), h \(last.h)")

    // Follow, from a held view: lit in Light Mode, over to the unlit face when it goes dark
    UserDefaults.standard.set(3.0, forKey: keys[1])
    NSApplication.shared.appearance = NSAppearance(named: .aqua)
    let scene = SaturnsRings(size: size, moment: 0)
    #expect(scene.camera().lit)
    _ = run(scene, for: 20)
    NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
    cameras = run(scene, for: 2 * SaturnsRings.glide + 10, from: 20)
    keepsClear(cameras, "Follow")
    smooth(cameras, "Follow")
    keepsMoving(cameras, "Follow")
    #expect(!cameras.last!.lit, "Follow went over to the unlit face in Dark Mode")

    // Follow as Cycle glides, a view picked on the way to the plane: from where the camera is, on through the plane
    // to that view
    UserDefaults.standard.set(0.0, forKey: keys[0])
    UserDefaults.standard.set(1.0, forKey: keys[2])
    NSApplication.shared.appearance = NSAppearance(named: .aqua)
    let gliding = SaturnsRings(size: size, moment: 0)
    _ = run(gliding, for: 90)
    NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
    cameras = run(gliding, for: 60, from: 90)
    UserDefaults.standard.set(5.0, forKey: keys[0])
    cameras += run(gliding, for: 2 * SaturnsRings.glide - 50, from: 150)
    keepsClear(cameras, "Follow mid-glide")
    smooth(cameras, "Follow mid-glide")
    keepsMoving(cameras, "Follow mid-glide")
    let encke = SaturnsRings.held(SaturnsRings.views[4], for: 0, lit: false)
    #expect(!cameras.last!.lit && abs(cameras.last!.r - encke.r) < 0.1 && abs(cameras.last!.yaw - encke.yaw) < 0.01, "on to the view picked, on the unlit face")

    // Cycle under Alternate, a minute's hold: of four glides, two change faces
    UserDefaults.standard.set(0.0, forKey: keys[0])
    UserDefaults.standard.set(2.0, forKey: keys[1])
    UserDefaults.standard.set(1.0, forKey: keys[2])
    cameras = run(SaturnsRings(size: size, moment: 0), for: 4 * 60 + 2 * SaturnsRings.glide + 2 * 2 * SaturnsRings.glide)
    keepsClear(cameras, "Cycle")
    smooth(cameras, "Cycle")
    keepsMoving(cameras, "Cycle")
    #expect(zip(cameras, cameras.dropFirst()).count { $0.lit != $1.lit } == 2, "Cycle changed faces every other glide")

    // Fly Through under Alternate: once a lap
    UserDefaults.standard.set(7.0, forKey: keys[0])
    let lap = SaturnsRings.alternateFlight.last! / 2
    cameras = run(SaturnsRings(size: size, moment: 0), for: 2 * lap)
    keepsClear(cameras, "Fly Through")
    smooth(cameras, "Fly Through")
    keepsMoving(cameras, "Fly Through")
    #expect(zip(cameras, cameras.dropFirst()).count { $0.lit != $1.lit } == 2, "Fly Through changed faces once a lap")
}

/// The camera changing faces, twelve moments each at 3024 × 1964: a view held (Along the Planet's Edge, lit) going over
/// to the unlit face and back to itself, from its start to its end; and the two-lap loop under Alternate, from From
/// Above, out past the rings, through the plane and on to Looking In on the unlit face. Prints each one's luma (Rec.
/// 709) at the median, 99th, 99.9th and max, and saves it a quarter across to `SNAPSHOT_DIR` as
/// `crossing-<held|loop>-<moment>.jpg`, for docs/saturns-rings/build-crossing.jpg. Opt-in:
///
///     RINGS_CROSSING=1 SNAPSHOT_DIR=/some/dir swift test -c release -Xswiftc -enable-testing --filter saturnsRingsCrossingMoments
@MainActor @Test(.enabled(if: ProcessInfo.processInfo.environment["RINGS_CROSSING"] != nil))
func saturnsRingsCrossingMoments() throws {
    let dir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] ?? NSTemporaryDirectory() + "atrium-snapshots")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let device = try #require(MTLCreateSystemDefaultDevice()), queue = try #require(device.makeCommandQueue())
    let (w, h) = (3024, 1964), size = CGSize(width: 1512, height: 982)
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    let texture = try #require(device.makeTexture(descriptor: descriptor))
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = texture
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    defer { UserDefaults.standard.removeObject(forKey: SaturnsRings.face.key) }
    func shoot(_ scene: SaturnsRings, upTo seconds: Double, from start: inout Double, renderer: SKRenderer, name: String) throws {
        while start < seconds - 1e-9 { start = min(start + 0.1, seconds); renderer.update(atTime: 1 + start) }
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
        let camera = scene.camera()
        print(String(format: "Saturn's Rings crossing %@ at %.0f s (%@, r %.1f, h %.4f, turned %.0f): %d %d %d %d", name, seconds, camera.lit ? "lit" : "unlit",
                     camera.r, camera.h, camera.roll, percentile(0.5), percentile(0.99), percentile(0.999), histogram.lastIndex { $0 > 0 } ?? 0))
        try saveQuarter(pixels, w, h, to: dir.appendingPathComponent("crossing-\(name).jpg"))
    }
    // a view held in Cycle, lit, asked for the unlit face as it begins
    UserDefaults.standard.set(0.0, forKey: SaturnsRings.view.key)
    UserDefaults.standard.set(1.0, forKey: SaturnsRings.face.key)
    let held = SaturnsRings(size: size, from: 2, moment: 0, date: day("2026-11-19"))
    UserDefaults.standard.set(0.0, forKey: SaturnsRings.face.key)
    var renderer = SKRenderer(device: device), clock = 0.0
    renderer.scene = held
    renderer.update(atTime: 1)
    for k in 0..<12 { try shoot(held, upTo: 2 * SaturnsRings.glide * Double(k) / 11, from: &clock, renderer: renderer, name: "held-\(k)") }
    // the two-lap loop, From Above to Looking In on the far side
    UserDefaults.standard.set(2.0, forKey: SaturnsRings.face.key)
    UserDefaults.standard.set(7.0, forKey: SaturnsRings.view.key)
    defer { UserDefaults.standard.removeObject(forKey: SaturnsRings.view.key) }
    let table = SaturnsRings.alternateFlight, (start, end) = (table[120 * 5], table[120 * 8])
    print(String(format: "Saturn's Rings crossing: the two-lap loop passes From Above at %.0f s, the point out past the rings at %.0f, the crossing at %.0f and Looking In at %.0f",
                 start, table[120 * 6], table[120 * 7], end))
    let loop = SaturnsRings(size: size, fly: true, moment: start, date: day("2026-11-19"))
    (renderer, clock) = (SKRenderer(device: device), 0)
    renderer.scene = loop
    renderer.update(atTime: 1)
    for k in 0..<12 { try shoot(loop, upTo: (end - start) * Double(k) / 11, from: &clock, renderer: renderer, name: "loop-\(k)") }
}

// MARK: The moons

/// JPL Horizons' places for the six moons at five moments the fit didn't use, from Saturn's centre in Mm, with the
/// Sun (Horizons' own) at azimuth 0 round Saturn's pole: the moon, the Julian date (UT), x toward the Sun along the
/// ring plane, y a quarter turn on round the pole, z toward the north pole. docs/saturns-rings/moons.py prints
/// them (ephemeris sat441l, fetched from ssd.jpl.nasa.gov/api/horizons.api on 2026-11-21).
private let horizonsMoons: [(String, Double, Double, Double, Double)] = [
    ("Mimas", 2461365.99920, 86.243, 166.847, 3.780), ("Mimas", 2461479.74920, 123.660, -133.361, 4.074),
    ("Mimas", 2462200.09920, 90.892, 164.954, -0.656), ("Mimas", 2463079.49920, 44.547, 176.756, 2.898),
    ("Mimas", 2464733.24920, 109.985, -150.899, -0.369),
    ("Enceladus", 2461365.99920, 84.423, -222.819, 0.010), ("Enceladus", 2461479.74920, 92.610, -218.864, -0.024),
    ("Enceladus", 2462200.09920, -232.532, 50.475, 0.009), ("Enceladus", 2463079.49920, 118.776, 205.909, -0.009),
    ("Enceladus", 2464733.24920, 199.650, -131.403, -0.043),
    ("Tethys", 2461365.99920, -86.276, -281.800, -1.711), ("Tethys", 2461479.74920, 279.062, -94.521, -4.156),
    ("Tethys", 2462200.09920, -285.906, 70.979, -4.652), ("Tethys", 2463079.49920, 94.461, 279.121, 4.727),
    ("Tethys", 2464733.24920, 288.450, 60.306, 2.862),
    ("Dione", 2461365.99920, -189.412, -325.504, 0.184), ("Dione", 2461479.74920, 76.063, 370.531, -0.130),
    ("Dione", 2462200.09920, -217.754, 309.201, 0.202), ("Dione", 2463079.49920, -349.383, -144.490, -0.143),
    ("Dione", 2464733.24920, -276.841, -257.752, 0.148),
    ("Rhea", 2461365.99920, 512.932, -123.568, -1.577), ("Rhea", 2461479.74920, 355.965, 388.829, 1.557),
    ("Rhea", 2462200.09920, -521.524, -74.179, -1.789), ("Rhea", 2463079.49920, 441.996, 286.587, 2.221),
    ("Rhea", 2464733.24920, 524.432, -47.787, -1.174),
    ("Titan", 2461365.99920, 157.047, -1229.102, 8.743), ("Titan", 2461479.74920, 958.441, -811.674, 6.342),
    ("Titan", 2462200.09920, 1241.881, -97.755, -2.416), ("Titan", 2463079.49920, 1177.166, 304.617, -8.667),
    ("Titan", 2464733.24920, -1098.584, -610.517, 5.807),
]

/// The moons are where Horizons has them, from 2026 to 2036: within 0.6° as seen from Saturn's centre (the fit's own
/// 0.4°, and the app's Sun, which the frame is turned to), and within half a percent in distance.
@Test func saturnsRingsMoonsMatchHorizons() throws {
    var most = 0.0
    for (name, jd, x, y, z) in horizonsMoons {
        let index = try #require(SaturnsRings.moons.firstIndex { $0.name == name })
        let got = SaturnsRings.moons(at: jd)[index], want = SIMD3(x, y, z)
        let apart = acos(min(simd_dot(simd_normalize(got), simd_normalize(want)), 1)) * 180 / .pi
        most = max(most, apart)
        #expect(apart < 0.6 && abs(simd_length(got) / simd_length(want) - 1) < 0.005, "\(name) at \(jd): \(apart)° from Horizons' place, \(got) against \(want)")
    }
    print(String(format: "Saturn's Rings: the moons are within %.2f° of Horizons' places", most))
}

/// How a moon at `moon` (`SaturnsRings.moons(at:)`'s frame) is seen from `camera`: where on the screen (−1 to 1
/// across and up, the screen `aspect` tall for its width), or nil if it's behind the camera; whether the planet is
/// before it; the ring radius where its light crosses the ring plane on the way, and how steeply (the sine of the
/// angle to the plane), or nil if it doesn't cross; and how much of its lit side faces the camera (1 all, −1 none;
/// −2 if the planet's shadow is on it).
private func sight(_ moon: SIMD3<Double>, from camera: SaturnsRings.Camera, sunUp: Double, aspect: Double)
    -> (at: SIMD2<Double>, far: Double, hidden: Bool, through: (r: Double, mu: Double)?, phase: Double)? {
    let axes = camera.axes(sunUp: sunUp), round = camera.sun * .pi / 180
    let place = SIMD3(cos(round) * moon.x - sin(round) * moon.y, sin(round) * moon.x + cos(round) * moon.y, moon.z), to = place - axes.at
    let depth = simd_dot(to, axes.ahead), tangent = tan(camera.field / 2 * .pi / 180)
    guard depth > 0 else { return nil }
    let at = SIMD2(simd_dot(to, axes.right) / depth / tangent, simd_dot(to, axes.up) / depth / (tangent * aspect))
    let k = 60.268 / 54.364, cs = SIMD3(axes.at.x, axes.at.y, axes.at.z * k), ds = SIMD3(to.x, to.y, to.z * k)
    let nearest = min(max(-simd_dot(cs, ds) / simd_dot(ds, ds), 0), 1)
    var through: (r: Double, mu: Double)?
    let cross = axes.at.z / (axes.at.z - place.z)
    if cross > 0, cross < 1 { let p = axes.at + cross * to; through = (simd_length(SIMD2(p.x, p.y)), abs(to.z) / simd_length(to)) }
    let ps = SIMD3(place.x, place.y, place.z * k), ss = simd_normalize(SIMD3(axes.sun.x, axes.sun.y, axes.sun.z * k)), along = simd_dot(ps, ss)
    let shadowed = along < 0 && simd_length(ps - along * ss) < 60.5
    return (at, simd_length(to), simd_length(cs + nearest * ds) < 60.268, through, shadowed ? -2 : simd_dot(axes.sun, simd_normalize(axes.at - place)))
}

/// Saturn's Rings holding `view` from the unlit face (or the lit) at `date`, w × h pixels (the scene half that in
/// points), with the moons or without: its pixels, BGRA, the top row first.
@MainActor private func ringsFrame(view: Int, lit: Bool = false, date: Date, moons: Bool, w: Int, h: Int) throws -> [UInt8] {
    let keys = [SaturnsRings.view.key, SaturnsRings.face.key, SaturnsRings.showMoons.key]
    defer { keys.forEach(UserDefaults.standard.removeObject) }
    for (key, value) in zip(keys, [0.0, lit ? 1.0 : 0.0, moons ? 1.0 : 0.0]) { UserDefaults.standard.set(value, forKey: key) }
    let device = try #require(MTLCreateSystemDefaultDevice()), queue = try #require(device.makeCommandQueue())
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    let texture = try #require(device.makeTexture(descriptor: descriptor))
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = texture
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    let renderer = SKRenderer(device: device)
    renderer.scene = SaturnsRings(size: CGSize(width: w / 2, height: h / 2), from: view, moment: 0, date: date)
    renderer.update(atTime: 1)
    let buffer = try #require(queue.makeCommandBuffer())
    renderer.render(withViewport: CGRect(x: 0, y: 0, width: w, height: h), commandBuffer: buffer, renderPassDescriptor: pass)
    buffer.commit()
    buffer.waitUntilCompleted()
    var pixels = [UInt8](repeating: 0, count: w * h * 4)
    texture.getBytes(&pixels, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
    return pixels
}

/// The first hour from `start`, within two years, at which some moon is seen from a held view (the unlit face, or
/// the lit) as `wanted` says: the view, the moon, the moment, and where it is on the screen.
private func firstSight(from start: Date, moons: Range<Int> = 0..<6, views: [Int] = Array(SaturnsRings.views.indices), lit: Bool = false, aspect: Double,
                        where wanted: (_ seen: (at: SIMD2<Double>, far: Double, hidden: Bool, through: (r: Double, mu: Double)?, phase: Double), _ moon: Int, _ view: Int) -> Bool)
    -> (view: Int, moon: Int, date: Date, at: SIMD2<Double>, far: Double)? {
    for hour in 0..<(2 * 365 * 24) {
        let date = start.addingTimeInterval(Double(hour) * 3600), places = SaturnsRings.moons(at: Sky.julianDate(date)), sunUp = SaturnsRings.light(on: date).up
        for view in views {
            let camera = SaturnsRings.held(SaturnsRings.views[view], for: 0, lit: lit)
            for moon in moons {
                guard let seen = sight(places[moon], from: camera, sunUp: sunUp, aspect: aspect), abs(seen.at.x) < 0.85, abs(seen.at.y) < 0.85,
                      wanted(seen, moon, view) else { continue }
                return (view, moon, date, seen.at, seen.far)
            }
        }
    }
    return nil
}

/// The moons are drawn where they are, and what's before them hides them: an icy moon in the clear shows as a disc
/// of its own size at its place on the screen, and not with Moons off; one with the planet before it doesn't show;
/// and one whose light comes up through the rings on the way shows dimmer, by about what the rings pass.
@MainActor @Test func saturnsRingsMoonsHideAndDim() throws {
    let (w, h) = (1512, 982), aspect = Double(h) / Double(w), start = day("2026-11-21"), rings = RingProfile.shared
    /// The most any pixel's green changes, with the moons and without, within the moon's own disc and 4 pixels round it.
    func shows(_ found: (view: Int, moon: Int, date: Date, at: SIMD2<Double>, far: Double)) throws -> Int {
        let with = try ringsFrame(view: found.view, date: found.date, moons: true, w: w, h: h)
        let without = try ringsFrame(view: found.view, date: found.date, moons: false, w: w, h: h)
        let tangent = tan(SaturnsRings.views[found.view].field / 2 * .pi / 180)
        let reach = Int(SaturnsRings.moons[found.moon].radius / 1000 / found.far / tangent * Double(w) / 2) + 4
        let (x, y) = (Int((found.at.x / 2 + 0.5) * Double(w)), Int((0.5 - found.at.y / 2) * Double(h)))
        var most = 0
        for row in max(y - reach, 0)...min(y + reach, h - 1) {
            for column in max(x - reach, 0)...min(x + reach, w - 1) {
                let at = (row * w + column) * 4 + 1
                most = max(most, abs(Int(with[at]) - Int(without[at])))
            }
        }
        return most
    }
    /// Whether the moon's light reaches the camera past the rings untouched.
    func clear(_ through: (r: Double, mu: Double)?) -> Bool { through.map { $0.r > 142 } ?? true }
    let open = try #require(firstSight(from: start, moons: 0..<5, aspect: aspect) { seen, _, _ in !seen.hidden && clear(seen.through) && seen.phase > 0.3 })
    let bright = try shows(open)
    #expect(bright > 60, "\(SaturnsRings.moons[open.moon].name) in the clear from \(SaturnsRings.views[open.view].name) on \(open.date): \(bright)")
    let behind = try #require(firstSight(from: start, aspect: aspect) { seen, _, _ in seen.hidden })
    #expect(try shows(behind) <= 1, "\(SaturnsRings.moons[behind.moon].name) behind the planet from \(SaturnsRings.views[behind.view].name) on \(behind.date)")
    // through the rings where they pass between a twentieth and a third of the light along the way
    let veiled = try #require(firstSight(from: start, moons: 0..<5, aspect: aspect) { seen, _, _ in
        guard !seen.hidden, seen.phase > 0.3, let through = seen.through, through.r > 74.6, through.r < 136.7 else { return false }
        let passes = exp(-rings.tau[Int((through.r - rings.start) / rings.step)] / through.mu)
        return passes > 0.05 && passes < 0.33
    })
    let dim = try shows(veiled)
    #expect(dim >= 2 && Double(dim) < 0.75 * Double(bright), "\(SaturnsRings.moons[veiled.moon].name) through the rings from \(SaturnsRings.views[veiled.view].name) on \(veiled.date): \(dim) against \(bright) in the clear")
    print("Saturn's Rings moons: \(SaturnsRings.moons[open.moon].name) in the clear \(bright) (\(SaturnsRings.views[open.view].name), \(open.date)); "
          + "\(SaturnsRings.moons[behind.moon].name) behind the planet (\(SaturnsRings.views[behind.view].name), \(behind.date)); "
          + "\(SaturnsRings.moons[veiled.moon].name) through the rings \(dim) (\(SaturnsRings.views[veiled.view].name), \(veiled.date))")
}

/// Each moon the first time from the moment `RINGS_MOONS` gives (as 2026-11-22T02:00:00Z; now if it's anything else)
/// that it's in the clear in a held view's frame, from the lit face, and Pan in Over the Encke Gap, at 3024 × 1964: saves the 640 × 400 pixels round each to `SNAPSHOT_DIR` as
/// `moon-<name>.jpg`, for docs/saturns-rings/build-moons.jpg, and prints which view and when, how far it is and how
/// many pixels across; then, hour by hour for a day, which moons are in the clear in each view's frame. Opt-in:
///
///     RINGS_MOONS=2026-11-22T02:00:00Z SNAPSHOT_DIR=/some/dir swift test --filter saturnsRingsMoonMoments
@MainActor @Test(.enabled(if: ProcessInfo.processInfo.environment["RINGS_MOONS"] != nil))
func saturnsRingsMoonMoments() throws {
    let dir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] ?? NSTemporaryDirectory() + "atrium-snapshots")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let (w, h) = (3024, 1964), aspect = Double(h) / Double(w), stamp = ISO8601DateFormatter()
    let start = stamp.date(from: ProcessInfo.processInfo.environment["RINGS_MOONS"] ?? "") ?? Date()
    /// Saves the 640 × 400 pixels round (x, y), counted from the screen's centre as `sight` does, kept within the frame.
    func save(_ pixels: [UInt8], round at: SIMD2<Double>, as name: String) throws {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!, info = CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        let image = try #require(CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: space,
                                         bitmapInfo: CGBitmapInfo(rawValue: info), provider: CGDataProvider(data: Data(pixels) as CFData)!,
                                         decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let x = min(max(Int((at.x / 2 + 0.5) * Double(w)) - 320, 0), w - 640), y = min(max(Int((0.5 - at.y / 2) * Double(h)) - 200, 0), h - 400)
        let destination = try #require(CGImageDestinationCreateWithURL(dir.appendingPathComponent("moon-\(name).jpg") as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try #require(image.cropping(to: CGRect(x: x, y: y, width: 640, height: 400))),
                                   [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
    }
    for (index, moon) in SaturnsRings.moons.enumerated() {
        let found = try #require(firstSight(from: start, moons: index..<(index + 1), lit: true, aspect: aspect) { seen, _, _ in
            !seen.hidden && (seen.through.map { $0.r > 142 } ?? true) && seen.phase > 0.2
        })
        let field = tan(SaturnsRings.views[found.view].field / 2 * .pi / 180)
        let across: Double = moon.radius / 1000 / found.far / field * Double(w)
        print(String(format: "Saturn's Rings moon %@: from %@ at %@, %.0f Mm off, %.1f px across", moon.name, SaturnsRings.views[found.view].name,
                     stamp.string(from: found.date), found.far, across))
        try save(try ringsFrame(view: found.view, lit: true, date: found.date, moons: true, w: w, h: h), round: found.at, as: moon.name)
    }
    // Pan, a fixed way ahead of the camera round Saturn
    let encke = SaturnsRings.held(SaturnsRings.views[4], for: 0, lit: true), round = encke.sun * .pi / 180
    let pan = SaturnsRings.pan.r * SIMD3(cos(SaturnsRings.pan.ahead - round), sin(SaturnsRings.pan.ahead - round), 0)
    let seen = try #require(sight(pan, from: encke, sunUp: SaturnsRings.light(on: start).up, aspect: aspect))
    let across: Double = SaturnsRings.pan.radius / 1000 / seen.far / tan(encke.field / 2 * .pi / 180) * Double(w)
    print(String(format: "Saturn's Rings moon Pan: from Over the Encke Gap, %.2f Mm off, %.1f px across, at %.2f, %.2f", seen.far, across, seen.at.x, seen.at.y))
    try save(try ringsFrame(view: 4, lit: true, date: start, moons: true, w: w, h: h), round: seen.at, as: "Pan")
    // the day from then, hour by hour: which moons each view has in the clear, from either face
    for lit in [true, false] {
        for (index, view) in SaturnsRings.views.enumerated() {
            var hours = [String: [Int]]()
            for hour in 0..<24 {
                let date = start.addingTimeInterval(Double(hour) * 3600), places = SaturnsRings.moons(at: Sky.julianDate(date))
                let camera = SaturnsRings.held(SaturnsRings.views[index], for: 0, lit: lit), sunUp = SaturnsRings.light(on: date).up
                for (moon, place) in places.enumerated() {
                    guard let seen = sight(place, from: camera, sunUp: sunUp, aspect: aspect), abs(seen.at.x) < 0.95, abs(seen.at.y) < 0.95, !seen.hidden,
                          seen.through.map({ $0.r > 142 }) ?? true else { continue }
                    hours[SaturnsRings.moons[moon].name, default: []].append(hour)
                }
            }
            let list = hours.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value.first!)–\($0.value.last!) h (\($0.value.count) of 24)" }.joined(separator: ", ")
            print("Saturn's Rings moons, \(lit ? "lit" : "unlit") \(view.name), the day from \(stamp.string(from: start)): \(list.isEmpty ? "none" : list)")
        }
    }
}
