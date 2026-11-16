import Foundation
import Metal
import SpriteKit
import Testing
@testable import Atrium

/// A pinned Nebula (`nebula.seed` 2 in Dusty: a pillar and a dark knot in the gold), drawn at 2x after a second with
/// `settings` held, pixel by pixel.
@MainActor private func nebulaPixels(_ settings: [String: Double] = [:]) throws -> [UInt32] {
    let held = ["nebula.seed": 2.0].merging(settings) { $1 }
    for (key, value) in held { UserDefaults.standard.set(value, forKey: key) }
    UserDefaults.standard.set("Dusty", forKey: "nebula.palette")
    defer { (Array(held.keys) + ["nebula.palette"]).forEach(UserDefaults.standard.removeObject) }
    let device = try #require(MTLCreateSystemDefaultDevice()), queue = try #require(device.makeCommandQueue())
    let size = CGSize(width: 378, height: 245), (w, h) = (756, 490)
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    let texture = try #require(device.makeTexture(descriptor: descriptor))
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = texture
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    let renderer = SKRenderer(device: device)
    renderer.scene = nebula(size: size)
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
    return pixels
}

/// The test seed gives the same nebula twice, and Crisp dust lanes reaches the shader: raised, the lanes change.
/// (A shader past about 30 uniforms draws nothing at all, so this also catches one too many.)
@MainActor @Test func nebulaFollowsItsSeedAndDustDetail() throws {
    let soft = try nebulaPixels()
    #expect(Set(soft).count > 1000, "Nebula drew next to nothing")
    #expect(try nebulaPixels() == soft, "the same seed drew a different nebula")
    #expect(try nebulaPixels(["nebula.detail": 1]) != soft, "Crisp dust lanes changed nothing")
}
