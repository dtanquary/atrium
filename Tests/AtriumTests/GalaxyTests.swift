import Foundation
import Metal
import SpriteKit
import Testing
@testable import Atrium

/// A pinned Galaxy (`galaxy.seed` 2: the largest centred roll) of `kind`, drawn at 2x after a second, as luma 0-255
/// a pixel, row by row.
@MainActor private func galaxyLuma(_ kind: String, size: CGSize = CGSize(width: 756, height: 491)) throws -> (luma: [Double], w: Int, h: Int) {
    UserDefaults.standard.set(2.0, forKey: "galaxy.seed")
    UserDefaults.standard.set(kind, forKey: "galaxy.kind")
    defer { for key in ["galaxy.seed", "galaxy.kind"] { UserDefaults.standard.removeObject(forKey: key) } }
    let device = try #require(MTLCreateSystemDefaultDevice()), queue = try #require(device.makeCommandQueue())
    let (w, h) = (Int(size.width) * 2, Int(size.height) * 2)
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    let texture = try #require(device.makeTexture(descriptor: descriptor))
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = texture
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    let renderer = SKRenderer(device: device)
    renderer.scene = Galaxy(size: size)
    let start = ProcessInfo.processInfo.systemUptime + 1
    WallpaperTime.restart()
    for frame in 0...30 {
        WallpaperTime.set(start + Double(frame) / 30)
        renderer.update(atTime: start + Double(frame) / 30)
    }
    let buffer = try #require(queue.makeCommandBuffer())
    renderer.render(withViewport: CGRect(x: 0, y: 0, width: w, height: h), commandBuffer: buffer, renderPassDescriptor: pass)
    buffer.commit()
    buffer.waitUntilCompleted()
    var pixels = [UInt32](repeating: 0, count: w * h)
    texture.getBytes(&pixels, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
    return (pixels.map { 0.114 * Double($0 & 255) + 0.587 * Double($0 >> 8 & 255) + 0.299 * Double($0 >> 16 & 255) }, w, h)
}

/// No single black pixels on the disc: `pow` of an arm profile's base, rounded a hair below 0 between the arms, used
/// to give not-a-number there, which draws black (70-220 a frame at full size before its base was clamped).
@MainActor @Test(arguments: Galaxy.kinds.map(\.name))
func galaxyHasNoBlackSpecks(kind: String) throws {
    let (luma, w, h) = try galaxyLuma(kind)
    var specks = 0
    for y in 1..<h - 1 {
        for x in 1..<w - 1 where luma[y * w + x] < 25 {
            let around = [-w - 1, -w, -w + 1, -1, 1, w - 1, w, w + 1].reduce(0.0) { $0 + luma[y * w + x + $1] } / 8
            if around > 70 { specks += 1 }
        }
    }
    #expect(specks == 0, "\(kind) has \(specks) black specks")
}
