import Foundation
import ImageIO
import Metal
import SpriteKit
import Testing
import simd
@testable import Atrium

/// What the shader reads from a packed table at unit coordinates: the GPU's smoothing between the four entries
/// round it, done here in full precision on the same bytes.
private func smoothed(_ bytes: [UInt8], _ w: Int, _ h: Int, _ x: Double, _ y: Double, channels: Int) -> Double {
    let (fx, fy) = (min(max(x * Double(w) - 0.5, 0), Double(w - 1)), min(max(y * Double(h) - 0.5, 0), Double(h - 1)))
    let (i, j) = (min(Int(fx), max(w - 2, 0)), min(Int(fy), max(h - 2, 0))), (tx, ty) = (fx - Double(i), fy - Double(j))
    func entry(_ i: Int, _ j: Int) -> Double {
        let at = (min(j, h - 1) * w + min(i, w - 1)) * 4
        return (0..<channels).reduce(0.0) { $0 + (Double(bytes[at + $1]) / 255 - ($1 == 0 ? 0 : 0.5)) / pow(255, Double($1)) }
    }
    return (entry(i, j) * (1 - tx) + entry(i + 1, j) * tx) * (1 - ty) + (entry(i, j + 1) * (1 - tx) + entry(i + 1, j + 1) * tx) * ty
}

/// One over the distance along a ray of `e` after `turn`, as the shader gets it from table A.
private func tableRay(_ e2: Double, _ turn: Double) -> Double {
    let (w, h) = Bending.raysSize
    return smoothed(rayBytes, w, h, (Double(w - 1) / (1 + 6 * e2) + 0.5) / Double(w),
                    (min(max(turn / Bending.furthestTurn(e2), 0), 1) * Double(h - 1) + 0.5) / Double(h), channels: 2) / 2
}

private let rayBytes = Bending.packed(Bending.rays, bytes: 2), turnBytes = Bending.packed(Bending.turns, bytes: 3)

/// The two tables, as the shader reads them from their bytes, against rays followed step by step. Table A to
/// 5e-5 in one over the distance wherever a disc can be: out past the innermost orbit, before the ray's nearest
/// point, on rays aimed within 16 radii (its last two columns, for rays further out than any disc, are coarse).
/// Table B, the turn to the nearest point, to 1e-4 of a radian from far out to a part in 100,000 of the shadow's
/// edge; it's checked against a march to the turning point, not the integral that baked it.
@Test func bendingTablesFollowTheRays() {
    var worst = 0.0
    for e2 in [0.004, 0.02, 0.06, 0.11, 0.14, 0.1481, 0.16, 0.3, 1, 5, 40] {
        let limit = min(Bending.furthestTurn(e2), e2 < Bending.swallowed ? Bending.turnToNearest(e2) : .infinity)
        let turns = (1...40).map { Double($0) / 40 * limit }, exact = Bending.ray(e2.squareRoot(), at: turns)
        for (turn, u) in zip(turns, exact) where u <= 1.0 / 3 { worst = max(worst, abs(tableRay(e2, turn) - u)) }
    }
    #expect(worst < 5e-5, "table A is off by \(worst)")

    for fromEdge in [0.9, 0.5, 0.1, 0.01, 1e-3, 1e-4, 1e-5] {
        let e2 = Bending.swallowed * (1 - fromEdge), e = e2.squareRoot()
        var (u, slope, turned, h) = (0.0, e, 0.0, 1e-4)
        func bend(_ u: Double) -> Double { 1.5 * u * u - u }
        while true { // Runge-Kutta until it stops coming nearer
            let (a1, b1) = (slope, bend(u)), (a2, b2) = (slope + 0.5 * h * b1, bend(u + 0.5 * h * a1))
            let (a3, b3) = (slope + 0.5 * h * b2, bend(u + 0.5 * h * a2)), (a4, b4) = (slope + h * b3, bend(u + h * a3))
            let next = slope + h / 6 * (b1 + 2 * b2 + 2 * b3 + b4)
            if next <= 0 { turned += h * slope / (slope - next); break }
            u += h / 6 * (a1 + 2 * a2 + 2 * a3 + a4)
            (slope, turned) = (next, turned + h)
        }
        let column = (Bending.turnsColumn(e2) * Double(Bending.turnsSize - 1) + 0.5) / Double(Bending.turnsSize)
        let table = smoothed(turnBytes, Bending.turnsSize, 1, column, 0.5, channels: 3) * Bending.turnsScale + .pi / 2
        #expect(abs(table - turned) < 1e-4, "table B at \(fromEdge) from the edge: \(table), marched \(turned)")
    }
}

/// A scene drawn offscreen at `pixels` across, 2 pixels a point: each pixel's red, green and blue, top row first.
@MainActor private func drawn(_ scene: SKScene, _ w: Int, _ h: Int) throws -> [SIMD3<UInt8>] {
    let device = try #require(MTLCreateSystemDefaultDevice()), queue = try #require(device.makeCommandQueue())
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    let texture = try #require(device.makeTexture(descriptor: descriptor)), pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = texture
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    let renderer = SKRenderer(device: device)
    renderer.scene = scene
    for _ in 0..<2 { // the first frame can go by before a shader has compiled
        renderer.update(atTime: ProcessInfo.processInfo.systemUptime)
        let buffer = try #require(queue.makeCommandBuffer())
        renderer.render(withViewport: CGRect(x: 0, y: 0, width: w, height: h), commandBuffer: buffer, renderPassDescriptor: pass)
        buffer.commit()
        buffer.waitUntilCompleted()
    }
    var pixels = [UInt32](repeating: 0, count: w * h)
    texture.getBytes(&pixels, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
    return pixels.map { [UInt8($0 >> 16 & 255), UInt8($0 >> 8 & 255), UInt8($0 & 255)] }
}

/// The prototype's view: its brute-force picture (docs/black-hole/proto/out/compare-reference.png) has the camera
/// 100 M out, 78° from the axis, 40° across, the disc out to 24 M.
private let prototypeView = BlackHole.View(distance: 50, tilt: 78, outer: 12, field: 40)

/// The whole of the bending on the real GPU, against the prototype's picture, in which every ray was followed step
/// by step: checks on the disc and on the sky, which shift wherever a ray lands in the wrong place. Measured
/// 2026-10-11: 352 of 576,000 pixels differ, all on the edge of a check, which puts the edges within 0.015 of a
/// pixel on the disc and 0.002 on the sky on average (three times that in pixels at Retina size). With both
/// tables left to the GPU's own smoothing it was 987 (0.016 and 0.031 of a pixel); with both mixed by hand, 131.
@MainActor @Test func blackHoleBendsAsThePrototype() throws {
    let (w, h) = (960, 600)
    let ours = try drawn(BlackHole(size: CGSize(width: w / 2, height: h / 2), view: prototypeView, checks: true), w, h)
    let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("../../docs/black-hole/proto/out/compare-reference.png")
    let image = try #require(CGImageSourceCreateWithURL(file as CFURL, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) })
    #expect(image.width == w && image.height == h)
    let data = try #require(image.dataProvider?.data as Data?), step = image.bitsPerPixel / 8
    var differ = 0
    for row in 0..<h { for x in 0..<w where abs(Int(data[row * image.bytesPerRow + x * step]) - Int(ours[row * w + x].x)) > 3 { differ += 1 } }
    print("Black Hole: \(differ) of \(w * h) pixels differ from the prototype's brute-force picture")
    #expect(differ < 700, "\(differ) pixels differ: more than the edges of the checks")
    if let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] { // to look at
        let grey = ours.map(\.x), space = CGColorSpaceCreateDeviceGray()
        if let out = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: w, space: space,
                             bitmapInfo: CGBitmapInfo(rawValue: 0), provider: CGDataProvider(data: Data(grey) as CFData)!,
                             decode: nil, shouldInterpolate: false, intent: .defaultIntent),
           let to = CGImageDestinationCreateWithURL(URL(fileURLWithPath: dir).appendingPathComponent("Black Hole checks.png") as CFURL,
                                                    "public.png" as CFString, 1, nil) {
            CGImageDestinationAddImage(to, out, nil)
            CGImageDestinationFinalize(to)
        }
    }
}

/// Whether the GPU's own smoothing keeps what the tables' extra bytes hold: each table is stretched over the picture
/// by a shader that reads it as the scene's does and spreads the value over the pixel's three bytes, and the same
/// reading is made here on the table's bytes in full precision. A GPU that rounded what it read to a byte would be
/// out by up to 1/510 (0.002). An M-series GPU keeps the bytes but places its reading only to about a 35th of an
/// entry: measured 2026-10-11, table A within 2.1e-4 (mean 5e-5) and table B within 1.1e-4 (mean 1.2e-5). That is
/// why the scene mixes table B's entries itself, and why table A, left to the GPU, puts the disc's edges about a
/// 20th of a pixel out at Retina size (see blackHoleBendsAsThePrototype).
@MainActor @Test func gpuKeepsTheTablesPrecision() throws {
    let (w, h) = (960, 600)
    for (name, bytes, size, channels, limit) in [("A", rayBytes, Bending.raysSize, 2, 4e-4), ("B", turnBytes, (across: Bending.turnsSize, up: 1), 3, 2.5e-4)] {
        let table = SKTexture(data: Data(bytes), size: CGSize(width: size.across, height: size.up))
        table.filteringMode = .linear
        let scene = SKScene(size: CGSize(width: w / 2, height: h / 2)), sprite = SKSpriteNode(color: .black, size: scene.size)
        sprite.anchorPoint = .zero
        sprite.shader = SKShader(source: """
        void main() {
            vec4 t = texture2D(u_table, v_tex_coord);
            float v = clamp(t.r + (t.g - 0.5) / 255.0 + u_third * (t.b - 0.5) / 65025.0, 0.0, 0.99999) * 255.0;
            float mid = (v - floor(v)) * 255.0;
            gl_FragColor = vec4(floor(v) / 255.0, floor(mid) / 255.0, mid - floor(mid), 1.0);
        }
        """, uniforms: [SKUniform(name: "u_table", texture: table), SKUniform(name: "u_third", float: channels == 3 ? 1 : 0)])
        scene.addChild(sprite)
        let seen = try drawn(scene, w, h)
        var (worst, sum, between) = (0.0, 0.0, 0.0)
        for row in 0..<h { for x in 0..<w {
            let p = seen[row * w + x], value = (Double(p.x) + (Double(p.y) + Double(p.z) / 255) / 255) / 255
            let exact = smoothed(bytes, size.across, size.up, (Double(x) + 0.5) / Double(w), 1 - (Double(row) + 0.5) / Double(h), channels: channels)
            let next = smoothed(bytes, size.across, size.up, (Double(x) + 0.5) / Double(w) + 1 / Double(size.across), 1 - (Double(row) + 0.5) / Double(h), channels: channels)
            (worst, sum, between) = (max(worst, abs(value - exact)), sum + abs(value - exact), between + abs(next - exact))
        } }
        let n = Double(w * h)
        print(String(format: "Black Hole: the GPU reads table %@ within %.2g of its bytes smoothed exactly (mean %.2g; entries step by %.2g on average; a byte is %.2g)",
                     name, worst, sum / n, between / n, 1.0 / 255))
        #expect(worst < limit, "the GPU's reading of table \(name) is off by \(worst)")
    }
}

/// The disc's colours come from a table of black-body colours worked out in Swift. Its curves' constants were typed
/// in from memory of Wyman, Sloan & Shirley's fit, so they're checked here where it matters: the colour's place on
/// the CIE chart against the Planckian locus's published points, to 0.004.
@Test(arguments: [(2000.0, 0.5267, 0.4133), (3000, 0.4369, 0.4041), (4000, 0.3805, 0.3768), (5000, 0.3451, 0.3516),
                  (6500, 0.3135, 0.3237), (10000, 0.2807, 0.2884)])
func blackBodyKeepsToTheLocus(kelvin: Double, x: Double, y: Double) {
    let seen = BlackBody.chromaticity(kelvin)
    #expect(abs(seen.x - x) < 0.004 && abs(seen.y - y) < 0.004, "\(kelvin) K at \(seen), published \(x), \(y)")
}

/// The sky file is baked already turned to the scene's view (docs/black-hole/sky.py), so here the turn is made
/// again from scratch for one star whose place nobody can mistake: Sirius (HYG has it at RA 6.7525 h, Dec −16.7161°,
/// magnitude −1.44) must be the brightest thing in the cell it lands in. And the grid, one star to a cell, must
/// have kept nearly all 115,562.
@MainActor @Test func blackHoleSkyHoldsItsStars() {
    func turn(_ axis: Int, _ degrees: Double) -> simd_double3x3 {
        let (c, s) = (cos(degrees * .pi / 180), sin(degrees * .pi / 180))
        return [simd_double3x3(rows: [[1, 0, 0], [0, c, -s], [0, s, c]]), simd_double3x3(rows: [[c, 0, s], [0, 1, 0], [-s, 0, c]]),
                simd_double3x3(rows: [[c, -s, 0], [s, c, 0], [0, 0, 1]])][axis]
    }
    // the mock-up's turn of the sky (bh.py's sky_rot), from the camera's frame (right, up, toward the hole) to galactic
    let toGalactic = simd_double3x3(rows: [[0, 0, 1], [-1, 0, 0], [0, 1, 0]]) * turn(1, -55) * turn(0, 12) * turn(2, 35)
    let seen = toGalactic.transpose * (Sky.galactic * Sky.direction(6.7525 * 15, -16.7161))
    let (w, h) = BlackHole.skyCells
    let x = Int((atan2(seen.x, seen.z) / (2 * .pi) + 0.5) * Double(w)), y = Int((asin(seen.y) / .pi + 0.5) * Double(h))
    let cells = BlackHole.starCells
    #expect(cells[(y * w + x) * 4 + 2] == 254, "no Sirius at cell \(x), \(y)")
    let kept = stride(from: 2, to: cells.count, by: 4).count { cells[$0] > 0 }
    print("Black Hole: \(kept) of 115,562 stars have a cell of their own")
    #expect(kept > 108_000)
}

/// The glow, with the sky off so that only the disc shines. At Glow 0 there is none: the sky just over the hump is
/// exactly black, as the shadow's middle is. At 1 that sky is lit, the glow has died away by the picture's corner,
/// and no pixel is darker for it (but for the dither's one step).
@MainActor @Test func blackHoleGlows() throws {
    let defaults = UserDefaults.standard, held = ["blackhole.stars", "blackhole.milkyway", BlackHole.speed.key]
    for key in held { defaults.set(0, forKey: key) }
    defer { for key in held + [BlackHole.glow.key] { defaults.removeObject(forKey: key) } }
    let (w, h) = (756, 492)
    func picture(glow: Double) throws -> [SIMD3<UInt8>] {
        defaults.set(glow, forKey: BlackHole.glow.key)
        return try drawn(BlackHole(size: CGSize(width: w / 2, height: h / 2), start: (time: 20, generation: 7)), w, h)
    }
    let none = try picture(glow: 0), some = try picture(glow: 1)
    let hump = try #require((0..<h / 2).first { none[$0 * w + w / 2].x > 0 }), over = (hump - 5) * w + w / 2, shadow = (h / 2 - 24) * w + w / 2
    #expect(none[over] == .zero && none[shadow] == .zero)
    #expect(some[over].x > 25, "no glow over the hump: \(some[over])")
    #expect(some[0] == .zero, "the glow reaches the corner: \(some[0])")
    let darker = zip(none, some).map { Int($0.x) - Int($1.x) }.max() ?? 0
    #expect(darker <= 1, "a pixel is \(darker) of 255 darker for the glow")
}

/// For looking at the Black Hole moving: `BLACKHOLE_STRIPS=<dir> swift test --filter blackHoleMoves` steps one scene
/// frame by frame (not in real time) and saves, for 15 and 30 frames a second, eight frames in a row of three places
/// where trouble would show (the thin ring over the shadow, the disc's near side seen edge on, the bright left end)
/// with the change between each pair beside them, eight times over; then one frame with the glow a dragged slider
/// has left behind and the same frame with the glow made for it, for three sliders; then fifteen frames 7.5 s apart
/// through two lives of the streaks. It prints how much single pixels jump between frames, how much they step when
/// the fresh glow comes, and how far the disc's brightness and contrast wander over those two lives, with how much
/// of that keeps time with the streak generations handing over (breathing) rather than being the streaks
/// themselves coming and going.
@MainActor @Test func blackHoleMoves() throws {
    guard let dir = ProcessInfo.processInfo.environment["BLACKHOLE_STRIPS"] else { return }
    try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    let device = try #require(MTLCreateSystemDefaultDevice()), queue = try #require(device.makeCommandQueue())
    let (w, h) = (3024, 1964)
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    let texture = try #require(device.makeTexture(descriptor: descriptor)), pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = texture
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    var clock = ProcessInfo.processInfo.systemUptime + 1
    func frame(of renderer: SKRenderer, after seconds: Double, at fps: Double) throws -> [UInt32] {
        for _ in 0..<max(Int((seconds * fps).rounded()), 1) {
            clock += 1 / fps
            renderer.update(atTime: clock)
        }
        let buffer = try #require(queue.makeCommandBuffer())
        renderer.render(withViewport: CGRect(x: 0, y: 0, width: w, height: h), commandBuffer: buffer, renderPassDescriptor: pass)
        buffer.commit()
        buffer.waitUntilCompleted()
        var pixels = [UInt32](repeating: 0, count: w * h)
        texture.getBytes(&pixels, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
        return pixels
    }
    func save(_ pixels: [UInt32], _ w: Int, _ h: Int, _ name: String) {
        let image = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                            provider: CGDataProvider(data: Data(bytes: pixels, count: w * h * 4) as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let to = CGImageDestinationCreateWithURL(URL(fileURLWithPath: dir).appendingPathComponent(name) as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(to, image, nil)
        CGImageDestinationFinalize(to)
    }
    func luma(_ p: UInt32) -> Int { (Int(p >> 16 & 255) * 3 + Int(p >> 8 & 255) * 6 + Int(p & 255)) / 10 }

    // frame to frame, at the default size and speed
    let places = [("ring", w / 2 - 200, h / 2 - 260, 400, 150), ("near side", w / 2 - 700, h / 2 + 10, 400, 150), ("left end", w / 2 - 1050, h / 2 - 60, 400, 150)]
    for fps in [15.0, 30.0] {
        let renderer = SKRenderer(device: device)
        renderer.scene = BlackHole(size: CGSize(width: w / 2, height: h / 2))
        _ = try frame(of: renderer, after: 1, at: fps)
        let frames = try (0..<8).map { _ in try frame(of: renderer, after: 1 / fps, at: fps) }
        for (name, x0, y0, pw, ph) in places {
            var strip = [UInt32](repeating: 0, count: pw * 2 * ph * 8), jumps = [Int]()
            for (n, pixels) in frames.enumerated() { for y in 0..<ph { for x in 0..<pw {
                let p = pixels[(y0 + y) * w + x0 + x]
                strip[(n * ph + y) * pw * 2 + x] = p
                guard n > 0 else { continue }
                let change = abs(luma(p) - luma(frames[n - 1][(y0 + y) * w + x0 + x]))
                jumps.append(change)
                strip[(n * ph + y) * pw * 2 + pw + x] = UInt32(min(change * 8, 255)) * 0x010101
            } } }
            save(strip, pw * 2, ph * 8, "\(name) at \(Int(fps)) fps.png")
            jumps.sort()
            print(String(format: "Black Hole moving, %@ at %.0f fps: a pixel changes by %.2f of 255 a frame on average, 99.9%% of them by %d or less, the most %d",
                         name, fps, Double(jumps.reduce(0, +)) / Double(jumps.count), jumps[jumps.count * 999 / 1000], jumps.last!))
        }
    }

    // Is the turning plain to see at speed 1? Two frames 5 s apart, the whole disc: before, after, and the change.
    do {
        let renderer = SKRenderer(device: device)
        renderer.scene = BlackHole(size: CGSize(width: w / 2, height: h / 2))
        let first = try frame(of: renderer, after: 1, at: 30), second = try frame(of: renderer, after: 5, at: 30)
        let (pw, ph) = (2000, 900), (x0, y0) = (w / 2 - 1000, h / 2 - 470)
        var strip = [UInt32](repeating: 0, count: pw / 2 * (ph / 2) * 3), changes = [Int]()
        for y in stride(from: 0, to: ph, by: 2) { for x in stride(from: 0, to: pw, by: 2) {
            let (a, b) = (first[(y0 + y) * w + x0 + x], second[(y0 + y) * w + x0 + x]), change = abs(luma(a) - luma(b))
            strip[(y / 2) * (pw / 2) + x / 2] = a
            strip[(ph / 2 + y / 2) * (pw / 2) + x / 2] = b
            strip[(ph + y / 2) * (pw / 2) + x / 2] = UInt32(min(change * 4, 255)) * 0x010101
            if a >> 16 & 255 > (a & 255) + 40 { changes.append(change) } // the disc: red well over blue
        } }
        save(strip, pw / 2, ph / 2 * 3, "5 s apart at speed 1.png")
        print(String(format: "Black Hole moving, 5 s apart at speed 1: the disc's pixels change by %.1f of 255 on average; %.0f%% of them by 8 or more, %.0f%% by 25 or more",
                     Double(changes.reduce(0, +)) / Double(changes.count), Double(changes.count { $0 >= 8 }) / Double(changes.count) * 100,
                     Double(changes.count { $0 >= 25 }) / Double(changes.count) * 100))
    }

    // A slider dragged. The glow is made again at most every 0.15 s, so between times it is the last one (stretched
    // to fit, for Size). Does the picture step when the fresh one comes? The disc is held still, the slider is put
    // where 0.15 s of a drag across its whole range in 2 s would have taken it, and the same frame is drawn with
    // the glow as it was and then with the one made for it.
    for (key, moved) in [(BlackHole.size.key, 0.064), ("blackhole.brightness", 0.105), ("blackhole.streaks", 0.075)] {
        let defaults = UserDefaults.standard
        defaults.set(0, forKey: BlackHole.speed.key)
        defer { for key in [key, BlackHole.speed.key] { defaults.removeObject(forKey: key) } }
        let renderer = SKRenderer(device: device)
        renderer.scene = BlackHole(size: CGSize(width: w / 2, height: h / 2), start: (time: 20, generation: 7))
        defaults.set(0.8, forKey: key)
        _ = try frame(of: renderer, after: 1 / 30, at: 30)           // its glow is made again, for 0.8
        defaults.set(0.8 + moved, forKey: key)
        let stale = try frame(of: renderer, after: 1 / 30, at: 30)   // too soon for another
        let fresh = try frame(of: renderer, after: 0.2, at: 30)
        let (pw, ph) = (700, 300), (x0, y0) = (w / 2 - 350, h / 2 - 520)
        var strip = [UInt32](repeating: 0, count: pw * ph * 3), steps = [Int]()
        for i in 0..<w * h { steps.append(abs(luma(stale[i]) - luma(fresh[i]))) }
        for y in 0..<ph { for x in 0..<pw {
            let at = (y0 + y) * w + x0 + x
            (strip[y * pw + x], strip[(ph + y) * pw + x], strip[(2 * ph + y) * pw + x]) = (stale[at], fresh[at], UInt32(min(steps[at] * 32, 255)) * 0x010101)
        } }
        save(strip, pw, ph * 3, "a fresh glow after \(key) moved.png")
        steps.sort()
        print(String(format: "Black Hole moving, a fresh glow after 0.15 s of dragging %@: %.1f%% of pixels change at all, 99.9%% of them by %d of 255 or less, the most %d",
                     key, Double(steps.count { $0 > 0 }) / Double(steps.count) * 100, steps[steps.count * 999 / 1000], steps.last!))
    }

    // Two lives of the streaks: 120 units of the disc's time, 117 s at speed 1, looked at every 1.5 s. A generation
    // hands over every third of a life, 19.5 s or 13 looks, so any breathing would beat at that.
    let renderer = SKRenderer(device: device)
    renderer.scene = BlackHole(size: CGSize(width: w / 2, height: h / 2))
    let (cw, ch) = (1400, 700), (cx, cy) = (w / 2 - 700, h / 2 - 350)
    var sheet = [UInt32](repeating: 0, count: cw / 2 * 3 * (ch / 2) * 5), means = [Double](), spreads = [Double]()
    for n in 0..<78 {
        let pixels = try frame(of: renderer, after: 1.5, at: 30)
        var (sum, squares, count) = (0.0, 0.0, 0.0)
        for y in stride(from: 0, to: ch, by: 2) { for x in stride(from: 0, to: cw, by: 2) {
            let p = pixels[(cy + y) * w + cx + x]
            if n % 5 == 0, n < 75 { sheet[((n / 15) * (ch / 2) + y / 2) * (cw / 2 * 3) + (n / 5 % 3) * (cw / 2) + x / 2] = p }
            guard p >> 16 & 255 > (p & 255) + 40 else { continue } // the disc: red well over blue
            (sum, squares, count) = (sum + Double(luma(p)), squares + Double(luma(p) * luma(p)), count + 1)
        } }
        means.append(sum / count)
        spreads.append((squares / count - sum / count * (sum / count)).squareRoot())
    }
    save(sheet, cw / 2 * 3, ch / 2 * 5, "two lives of the streaks, every 7.5 s.png")
    for (name, series) in [("mean", means), ("spread", spreads)] {
        let average = series.reduce(0, +) / Double(series.count)
        let beat = (0..<78).reduce(SIMD2<Double>.zero) { $0 + series[$1] * SIMD2(cos(2 * .pi * Double($1) / 13), sin(2 * .pi * Double($1) / 13)) }
        print(String(format: "Black Hole moving, over two lives of the streaks: the disc's %@ runs %.1f to %.1f of 255 (average %.1f); the part of that which beats with the handover is ±%.1f%%",
                     name, series.min()!, series.max()!, average, (beat.x * beat.x + beat.y * beat.y).squareRoot() * 2 / 78 / average * 100))
    }
}

/// One still of the Black Hole that comes out the same every time, for comparing a change with what went before:
/// `BLACKHOLE_STILL=<file.png> swift test --filter blackHoleStill`, with `BLACKHOLE_DEFAULTS="blackhole.size=1.5,…"`
/// for Settings values as the render test takes them. The disc is held still at a fixed start, at full Retina size;
/// `BLACKHOLE_START="<disc time>,<generation>"` starts its streaks somewhere else.
@MainActor @Test func blackHoleStill() throws {
    let env = ProcessInfo.processInfo.environment
    guard let file = env["BLACKHOLE_STILL"] else { return }
    let settings = ((env["BLACKHOLE_DEFAULTS"] ?? "") + ",blackhole.speed=0").split(separator: ",").map { $0.split(separator: "=") }.filter { $0.count == 2 }
    for pair in settings { UserDefaults.standard.set(Double(pair[1]).map { $0 as Any } ?? String(pair[1]), forKey: String(pair[0])) }
    defer { for pair in settings { UserDefaults.standard.removeObject(forKey: String(pair[0])) } }
    let (w, h) = (3024, 1964)
    let start = (env["BLACKHOLE_START"] ?? "20,7").split(separator: ",").compactMap { Double($0) }
    let pixels = try drawn(BlackHole(size: CGSize(width: w / 2, height: h / 2), start: (time: start[0], generation: Int(start[1]))), w, h)
    let bytes = pixels.flatMap { [$0.x, $0.y, $0.z] }
    let image = try #require(CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 24, bytesPerRow: w * 3, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                     bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue), provider: CGDataProvider(data: Data(bytes) as CFData)!,
                                     decode: nil, shouldInterpolate: false, intent: .defaultIntent))
    let to = try #require(CGImageDestinationCreateWithURL(URL(fileURLWithPath: file) as CFURL, "public.png" as CFString, 1, nil))
    CGImageDestinationAddImage(to, image, nil)
    #expect(CGImageDestinationFinalize(to))
}
