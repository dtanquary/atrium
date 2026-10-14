import Metal
import SpriteKit
import Testing
@testable import Atrium

/// Lighter drawing applies a wallpaper's scale under the same condition as its battery cap, below mains power's rate,
/// and never with the switch off or without a scale; for comparing, on mains power too.
@Test func drawScaleFollowsThePower() {
    func scale(_ pick: Double, plugged: Double = 3, fast: Bool = false, batteryScale: CGFloat? = 0.5, lighter: Bool = true,
               onMains: Bool = false) -> CGFloat {
        Power.scale(pick: pick, plugged: plugged, fast: fast, batteryScale: batteryScale, lighter: lighter, onMains: onMains)
    }
    #expect(scale(2) == 0.5) // on battery at 30 fps, against 60 on mains
    #expect(scale(1) == 0.5 && scale(0) == 0.5) // Low Power Mode's 15 fps, and its Freeze (held still anyway)
    #expect(scale(3) == 1) // on mains power, or Full Speed on Battery: as fast as mains
    #expect(scale(4) == 1) // 120 picked runs at 60 without a fast display: not below mains power's
    #expect(scale(3, plugged: 4, fast: true) == 0.5 && scale(4, plugged: 4, fast: true) == 1)
    #expect(scale(2, batteryScale: nil) == 1)
    #expect(scale(2, lighter: false) == 1 && scale(3, lighter: false, onMains: true) == 1)
    #expect(scale(3, onMains: true) == 0.5 && scale(2, onMains: true) == 0.5)
}

/// Every wallpaper with a battery scale has a scene that can take it, and a scene built outside a view, as the render
/// tests build them, draws at full resolution.
@MainActor @Test func trimmedWallpapersBuildAtFullScale() {
    for wallpaper in allScenes where wallpaper.batteryScale != nil {
        let trim = (wallpaper.make(CGSize(width: 320, height: 200)) as? Trimmable)?.trim
        #expect(trim?.scale == 1 && trim?.shouldEnableEffects == false, "\(wallpaper.name)")
    }
}

/// A view gives the scene it shows the resolution it's set to, and the next scene too, and a frozen view stays
/// frozen through it.
@MainActor @Test func viewTrimsItsScene() {
    let view = WallpaperView(), size = CGSize(width: 64, height: 64)
    view.frozen = true
    view.drawScale = 0.75
    let first = shaderScene(size: size, source: "void main() { gl_FragColor = vec4(1.0); }") as! ShaderScene
    view.presentScene(first)
    #expect(first.trim.scale == 0.75 && first.trim.shouldEnableEffects && view.frozen)
    view.drawScale = 1
    #expect(first.trim.scale == 1 && !first.trim.shouldEnableEffects && view.frozen)
    view.drawScale = 0.5
    let next = shaderScene(size: size, source: "void main() { gl_FragColor = vec4(0.5); }") as! ShaderScene
    view.presentScene(next)
    #expect(next.trim.scale == 0.5 && view.frozen)
}

/// With Also while plugged in, `applyPowerState` gives a view its wallpaper's scale on whatever power this Mac is on,
/// for comparing; with Lighter drawing on battery off, never. Settings → Power is put back after.
@MainActor @Test func trimsCanBeComparedOnMainsPower() {
    let defaults = UserDefaults.standard, saved = Power.drawing.map { defaults.object(forKey: $0.key) }
    defer { for (knob, value) in zip(Power.drawing, saved) { defaults.set(value, forKey: knob.key) } }
    defaults.set(1.0, forKey: Power.lighter.key)
    defaults.set(1.0, forKey: Power.lighterPlugged.key)
    let view = WallpaperView()
    view.batteryScale = 0.75
    applyPowerState(to: [view])
    #expect(view.drawScale == 0.75)
    defaults.set(0.0, forKey: Power.lighter.key)
    applyPowerState(to: [view])
    #expect(view.drawScale == 1)
}

/// At scale 1 a trimmed scene draws byte for byte what it drew before it had a trim: the same scene, at the same
/// moment, with what its trim holds put straight on the scene in the trim's place.
@MainActor @Test(arguments: ["Live Sky", "Nebula", "Galaxy", "Meander", "Aurora", "Dappled Light"])
func trimAtFullScaleDrawsAsBefore(name: String) throws {
    let device = try #require(MTLCreateSystemDefaultDevice()), queue = try #require(device.makeCommandQueue())
    let size = CGSize(width: 600, height: 390), (w, h) = (1200, 780)
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    let texture = try #require(device.makeTexture(descriptor: descriptor))
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = texture
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    let scene = try #require(allScenes.first { $0.name == name }).make(size)
    let renderer = SKRenderer(device: device)
    renderer.scene = scene
    let start = ProcessInfo.processInfo.systemUptime + 1
    WallpaperTime.restart()
    for frame in 0...30 {
        WallpaperTime.set(start + Double(frame) / 30)
        renderer.update(atTime: start + Double(frame) / 30)
    }
    func draw() throws -> [UInt32] {
        let buffer = try #require(queue.makeCommandBuffer())
        renderer.render(withViewport: CGRect(x: 0, y: 0, width: w, height: h), commandBuffer: buffer, renderPassDescriptor: pass)
        buffer.commit()
        buffer.waitUntilCompleted()
        var pixels = [UInt32](repeating: 0, count: w * h)
        texture.getBytes(&pixels, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
        return pixels
    }
    let trimmed = try draw()
    let trim = try #require((scene as? Trimmable)?.trim)
    let at = try #require(scene.children.firstIndex(of: trim))
    trim.removeFromParent()
    for (offset, child) in trim.content.children.enumerated() {
        child.removeFromParent()
        scene.insertChild(child, at: at + offset)
    }
    let before = try draw()
    #expect(Set(stride(from: 0, to: trimmed.count, by: 997).map { trimmed[$0] }).count > 20, "\(name) drew a flat picture")
    #expect(trimmed == before, "\(name): \(zip(trimmed, before).count { $0 != $1 }) pixels differ")
}
