import SpriteKit
import Testing
@testable import Atrium

/// Scenes that sum their own time must keep moving after days on screen. Summed as a Float, a 60 fps frame's step
/// rounds away to nothing once the total is large, and the wallpaper freezes.
@MainActor @Test(arguments: ["Flowing Gradient", "Lava Lamp"]) func phaseKeepsMovingAfterSixDays(name: String) throws {
    let scene = try #require(scenes.first { $0.name == name }).make(CGSize(width: 300, height: 200))
    let uniforms = scene.children.compactMap { ($0 as? SKSpriteNode)?.shader?.uniformNamed("u_phase") }
    let phase = try #require(uniforms.first)
    var t = 0.0
    while t < 6 * 86400 { t += 0.5; scene.update(t) }   // update(_:) caps a step at 0.5 s
    let before = phase.floatValue
    for _ in 0..<10 { t += 1.0 / 60; scene.update(t) }
    let moved = Double(phase.floatValue - before), expected = Double(before) / (6 * 86400) * 10 / 60
    #expect(abs(moved - expected) < expected * 0.5, "\(name) moved \(moved), expected about \(expected)")
}

@MainActor @Test func campfireShaderClockStaysSmall() {
    #expect(Flames.shaderClock(6 * 86400 + 1.25) == 1.25)
}

/// `u_now` counts from the first frame after a restart, whatever the view's own clock says, so it stays small.
@MainActor @Test func wallpaperTimeRestarts() {
    WallpaperTime.restart()
    WallpaperTime.set(500_000)          // a view's clock, days after launch
    WallpaperTime.set(500_030)
    #expect(WallpaperTime.now.floatValue == 30 && WallpaperTime.elapsed == 30)
    WallpaperTime.restart()
    WallpaperTime.set(900_000)
    #expect(WallpaperTime.now.floatValue == 0)
    WallpaperTime.restart()
}
