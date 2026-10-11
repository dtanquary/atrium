import Foundation
import ImageIO
import Metal
import SpriteKit
import Testing
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
