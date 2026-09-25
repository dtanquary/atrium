import Metal
import SpriteKit
import Testing
import UniformTypeIdentifiers
@testable import Wallpaper

/// Renders every wallpaper offscreen at Retina size, saves a PNG to look at, and prints what a frame costs.
/// Fails if a scene comes out as one flat colour (e.g. a shader that didn't compile).
///
///     swift test                                                  # all scenes → $TMPDIR/wallpaper-snapshots
///     SNAPSHOT_SCENE="Live Sky" SNAPSHOT_SECONDS=20 swift test   # one scene, further into its animation
///     SNAPSHOT_DEFAULTS="gradient.ribbons=1,gradient.previewTime=1" swift test  # with Settings values
///     SNAPSHOT_APPEARANCE=light swift test                                      # in Light Mode
///
/// Only sceneDidLoad/init content shows up here: SKRenderer never calls didMove(to:).
@MainActor @Test func everySceneRenders() throws {
    let env = ProcessInfo.processInfo.environment
    let dir = URL(fileURLWithPath: env["SNAPSHOT_DIR"] ?? NSTemporaryDirectory() + "wallpaper-snapshots")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let seconds = Double(env["SNAPSHOT_SECONDS"] ?? "") ?? 4
    if let look = env["SNAPSHOT_APPEARANCE"] { NSApplication.shared.appearance = NSAppearance(named: look == "light" ? .aqua : .darkAqua) }
    let settings = (env["SNAPSHOT_DEFAULTS"] ?? "").split(separator: ",").map { $0.split(separator: "=") }
    for pair in settings where pair.count == 2 {
        UserDefaults.standard.set(Double(pair[1]).map { $0 as Any } ?? String(pair[1]), forKey: String(pair[0])) // numbers or names
    }
    defer { for pair in settings { UserDefaults.standard.removeObject(forKey: String(pair[0])) } }

    let device = try #require(MTLCreateSystemDefaultDevice())
    let queue = try #require(device.makeCommandQueue())
    let size = CGSize(width: 1512, height: 982) // 14" MacBook Pro, in points
    let (w, h) = (Int(size.width) * 2, Int(size.height) * 2)
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared

    for wallpaper in scenes where env["SNAPSHOT_SCENE"].map({ $0 == wallpaper.name }) ?? true {
        let name = wallpaper.name
        let renderer = SKRenderer(device: device)
        renderer.scene = wallpaper.make(size)
        let texture = try #require(device.makeTexture(descriptor: descriptor))
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store

        // Run every frame at 30 fps so actions and emitters advance normally; time the last 30.
        // SKRenderer's first update runs on the system clock, so frame times must start after it or every later
        // update counts as the past and update(_:) barely runs.
        let frames = Int(seconds * 30), clock = ProcessInfo.processInfo.systemUptime + 1
        var cpu = 0.0, gpu = 0.0
        for frame in 0...frames {
            let start = CFAbsoluteTimeGetCurrent()
            renderer.update(atTime: clock + Double(frame) / 30)
            let buffer = try #require(queue.makeCommandBuffer())
            renderer.render(withViewport: CGRect(x: 0, y: 0, width: w, height: h), commandBuffer: buffer, renderPassDescriptor: pass)
            buffer.commit()
            buffer.waitUntilCompleted()
            if frame > frames - 30 {
                let gpuTime = buffer.gpuEndTime - buffer.gpuStartTime
                gpu += gpuTime
                cpu += CFAbsoluteTimeGetCurrent() - start - gpuTime
            }
        }

        var pixels = [UInt32](repeating: 0, count: w * h)
        texture.getBytes(&pixels, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
        let colours = Set(stride(from: 0, to: pixels.count, by: 997).map { pixels[$0] })
        #expect(colours.count > 20, "\(name) rendered as a flat image")

        let image = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                            provider: CGDataProvider(data: Data(bytes: pixels, count: w * h * 4) as CFData)!,
                            decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let url = dir.appendingPathComponent("\(name).png")
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)

        print(String(format: "%@: cpu≈%.2f ms, gpu %.2f ms per frame → %@", name, cpu / 30 * 1000, gpu / 30 * 1000, url.path))
    }
}
