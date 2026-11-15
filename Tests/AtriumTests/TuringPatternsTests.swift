import SpriteKit
import Testing
@testable import Atrium

/// Turing Patterns six seconds in, drawn offscreen at 2x in Light or Dark Mode: coral from seed 3, standing still, in
/// Lagoon. Each pixel is its red, green and blue, top row first, `w` to a row.
@MainActor private func picture(light: Bool, _ w: Int = 640, _ h: Int = 400) throws -> [SIMD3<Int>] {
    let settings: [String: Any] = ["turing.seed": 3, "turing.pattern": 1, "turing.motion": 2, "turing.palette": "Lagoon"]
    let appearance = NSApplication.shared.appearance
    defer {
        settings.keys.forEach(UserDefaults.standard.removeObject)
        NSApplication.shared.appearance = appearance
    }
    for (key, value) in settings { UserDefaults.standard.set(value, forKey: key) }
    NSApplication.shared.appearance = NSAppearance(named: light ? .aqua : .darkAqua)

    let device = try #require(MTLCreateSystemDefaultDevice()), queue = try #require(device.makeCommandQueue())
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    let target = try #require(device.makeTexture(descriptor: descriptor)), pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = target
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    let renderer = SKRenderer(device: device)
    renderer.scene = turingPatterns(size: CGSize(width: w / 2, height: h / 2))
    let start = ProcessInfo.processInfo.systemUptime + 1 // the renderer's first update runs on the system's clock
    for frame in 0...180 { renderer.update(atTime: start + Double(frame) / 30) }
    let buffer = try #require(queue.makeCommandBuffer())
    renderer.render(withViewport: CGRect(x: 0, y: 0, width: w, height: h), commandBuffer: buffer, renderPassDescriptor: pass)
    buffer.commit()
    buffer.waitUntilCompleted()
    var pixels = [UInt32](repeating: 0, count: w * h)
    target.getBytes(&pixels, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
    return pixels.map { SIMD3(Int($0 >> 16 & 255), Int($0 >> 8 & 255), Int($0 & 255)) }
}

/// How many pixels wide the pattern's edge is in a Light Mode picture `w` to a row: along each row, the pixels whose
/// red is between the ink's and the paper's, for each time the row goes from one to the other. (Lagoon's ink has
/// almost no red and the paper has plenty, so only an edge is in between.)
private func edgeWidth(_ pixels: [SIMD3<Int>], _ w: Int) -> Double {
    var between = 0, crossings = 0
    for row in stride(from: 0, to: pixels.count, by: w) {
        var paper: Bool?
        for red in pixels[row..<row + w].map(\.x) {
            guard red < 110 || red > 150 else { between += 1; continue }
            if let paper, paper != (red > 150) { crossings += 1 }
            paper = red > 150
        }
    }
    return Double(between) / Double(max(crossings, 1))
}

/// The pattern's outline is in focus: the middle of its edge is under a pixel wide. (Measured 0.7 pixels; while the
/// edge ran from 0.25 to 0.45 of the field whatever its slope, it measured 2.5.)
@MainActor @Test func turingPatternsEdgeIsInFocus() throws {
    #expect(edgeWidth(try picture(light: true), 640) < 1.5)
}

/// How bright the ink is just inside the top edges of the pattern and just inside the bottom ones, in a Light Mode
/// picture `w` to a row: the mean of red, green and blue over the ink with paper six pixels above it, and below it.
private func flanks(_ pixels: [SIMD3<Int>], _ w: Int) -> (top: Double, bottom: Double) {
    var top = (sum: 0, count: 0), bottom = (sum: 0, count: 0)
    for i in 6 * w..<pixels.count - 6 * w where pixels[i].x < 110 {
        if pixels[i - 6 * w].x > 150 { top = (top.sum + pixels[i].wrappedSum(), top.count + 1) }
        if pixels[i + 6 * w].x > 150 { bottom = (bottom.sum + pixels[i].wrappedSum(), bottom.count + 1) }
    }
    return (Double(top.sum) / Double(max(top.count, 1)) / 3, Double(bottom.sum) / Double(max(bottom.count, 1)) / 3)
}

/// The relief is lit from above, as its doc always said: the ink inside an arm's top edge is brighter than the ink
/// inside its bottom edge (measured 64 against 49 of 255). Until 2026-11-14 it was the other way up, 48 against 67,
/// as Metal's `dfdy` runs down the screen.
@MainActor @Test func turingPatternsAreLitFromAbove() throws {
    let lit = flanks(try picture(light: true), 640)
    #expect(lit.top > lit.bottom + 5)
}

/// How bright the paper is beside the pattern, in a Light Mode picture `w` to a row: the mean red of the paper with
/// ink eight pixels up and to the left of it (in the pattern's lee, as the light comes from there), and of the paper
/// with ink eight pixels down and to the right.
private func paperBeside(_ pixels: [SIMD3<Int>], _ w: Int) -> (lee: Double, lit: Double) {
    var lee = (sum: 0, count: 0), lit = (sum: 0, count: 0)
    let reach = 8 * w + 8
    for i in reach..<pixels.count - reach where pixels[i].x > 150 {
        if pixels[i - reach].x < 110 { lee = (lee.sum + pixels[i].x, lee.count + 1) }
        if pixels[i + reach].x < 110 { lit = (lit.sum + pixels[i].x, lit.count + 1) }
    }
    return (Double(lee.sum) / Double(max(lee.count, 1)), Double(lit.sum) / Double(max(lit.count, 1)))
}

/// In Light Mode the relief casts a shadow on the paper, down and to the right: the paper there is darker than the
/// paper on the side the light comes from (measured 176 against 218 of 255; with no shadow, 221 against 220).
@MainActor @Test func turingPatternsCastAShadowInLightMode() throws {
    let paper = paperBeside(try picture(light: true), 640)
    #expect(paper.lee < paper.lit - 20)
}
