import Metal
import SpriteKit
import Testing
@testable import Atrium

/// The marsh pond at a light (Sunset unless given), drawn at 1512 × 982 pixels at each of `times` (seconds), as levels
/// of 255 (the mean of red, green and blue), top row first; and the rows of the photo from `from` to `to` (of its
/// 706), as a range of them. The flock is drawn behind the ground, so it can't change the shore.
@MainActor private func marsh(_ times: [Double], light: Double = 3) throws -> (pictures: [[Double]], rows: (Double, Double) -> Range<Int>) {
    let settings = ["murmuration.light": light, "murmuration.ground": 1, "murmuration.falcon": 0]
    defer { settings.keys.forEach(UserDefaults.standard.removeObject) }
    for (key, value) in settings { UserDefaults.standard.set(value, forKey: key) }

    let (w, h) = (1512, 982)
    let device = try #require(MTLCreateSystemDefaultDevice()), queue = try #require(device.makeCommandQueue())
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    let texture = try #require(device.makeTexture(descriptor: descriptor)), pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = texture
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    let renderer = SKRenderer(device: device)
    renderer.scene = murmuration(size: CGSize(width: w / 2, height: h / 2))
    let clock = ProcessInfo.processInfo.systemUptime + 1
    WallpaperTime.restart()
    let pictures = try times.map { seconds in
        for frame in 0..<2 { // the first frame can go by before a shader has compiled
            WallpaperTime.set(clock + seconds + Double(frame) / 30)
            renderer.update(atTime: clock + seconds + Double(frame) / 30)
            let buffer = try #require(queue.makeCommandBuffer())
            renderer.render(withViewport: CGRect(x: 0, y: 0, width: w, height: h), commandBuffer: buffer, renderPassDescriptor: pass)
            buffer.commit()
            buffer.waitUntilCompleted()
        }
        var pixels = [UInt32](repeating: 0, count: w * h)
        texture.getBytes(&pixels, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
        return pixels.map { Double(($0 >> 16 & 255) + ($0 >> 8 & 255) + ($0 & 255)) / 3 }
    }
    // The photo stands on the bottom edge, 706 of 4096 as tall as it is wide.
    let top = Double(h) - Double(w) * 706 / 4096
    return (pictures, { from, to in Int(top + from * Double(w) / 4096) * w..<Int(top + to * Double(w) / 4096) * w })
}

/// The pond's far shore is lifted out of flat black but stays a silhouette: 2.7 of 255 without the lift, 6.0 with it.
@MainActor @Test func murmurationShoreIsLifted() throws {
    let (pictures, rows) = try marsh([0]), shore = rows(40, 120)
    let mean = pictures[0][shore].reduce(0, +) / Double(shore.count)
    #expect(mean > 4 && mean < 20, "the far shore is \(mean) of 255")
}

/// The water's shading, which runs only where the water map has water, still runs: its ripples move over 2 s (by
/// about 3.6 of 255), where water shaded as land would hold still.
@MainActor @Test func murmurationWaterRipples() throws {
    let (pictures, rows) = try marsh([0, 2]), water = rows(320, 650)
    let change = zip(pictures[0][water], pictures[1][water]).map { abs($0 - $1) }.reduce(0, +) / Double(water.count)
    #expect(change > 0.5, "the water changed by \(change) of 255 in 2 s")
}

/// The Sun shows in the water: at Golden hour, 5° up, its mirror image lands on the pond below the far shore, as white
/// as the disc in the sky. Without it the water's brightest was about 227 of 255, the sky's glow near the shore.
@MainActor @Test func murmurationSunInTheWater() throws {
    let (pictures, rows) = try marsh([0], light: 2), water = rows(140, 700)
    let brightest = pictures[0][water].max() ?? 0
    #expect(brightest > 250, "the water's brightest is \(brightest) of 255")
}
