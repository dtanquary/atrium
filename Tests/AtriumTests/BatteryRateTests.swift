import SpriteKit
import Testing
@testable import Atrium

/// A scene that sets its own ceiling on battery, as a wallpaper with slow and fast phases does.
private final class Paced: SKScene, BatteryPaced {
    var batteryRate: Int? { didSet { batteryRateChanged(from: oldValue) } }
}

/// The rate `applyPowerState` gives a view held to `cap`, on whatever power this Mac is on now.
@MainActor private func rate(cap: Int?) -> Int {
    Power.fps(pick: powerKnob().value, plugged: Power.plugged.value, fast: Power.fastDisplay, cap: cap,
              heat: ProcessInfo.processInfo.thermalState)
}

/// Runs `body` with every Settings → Power choice at `pick`, putting the user's own back after.
@MainActor private func withPower(_ pick: Double, _ body: () throws -> Void) rethrows {
    let defaults = UserDefaults.standard, saved = Power.knobs.map { defaults.object(forKey: $0.key) }
    defer { for (knob, value) in zip(Power.knobs, saved) { defaults.set(value, forKey: knob.key) } }
    Power.knobs.forEach { defaults.set(pick, forKey: $0.key) }
    try body()
}

/// A view in a window, as on the desktop, so it hears scenes' changes of rate.
@MainActor private func windowed() -> (NSWindow, WallpaperView) {
    let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 64, height: 64), styleMask: .borderless, backing: .buffered, defer: false)
    let view = WallpaperView()
    window.contentView = view
    return (window, view)
}

/// A scene's own rate holds in place of its wallpaper's while it sets one; nil leaves its wallpaper's.
@MainActor @Test func sceneRateWinsOverWallpaperRate() {
    let view = WallpaperView(), size = CGSize(width: 64, height: 64)
    view.batteryRate = 20
    view.presentScene(SKScene(size: size))
    #expect(view.cap == 20)
    let paced = Paced(size: size)
    paced.batteryRate = 10
    view.presentScene(paced)
    #expect(view.cap == 10)
    paced.batteryRate = nil
    #expect(view.cap == 20)
}

/// A scene's change of rate reaches the view showing it at once, and only a change does.
@MainActor @Test func sceneRateChangeIsApplied() {
    withPower(2) { // 30 fps, never frozen
        let (window, view) = windowed()
        _ = window
        let paced = Paced(size: view.bounds.size)
        paced.batteryRate = 15
        view.presentScene(paced)
        view.preferredFramesPerSecond = 1 // what applying the rate would overwrite
        paced.batteryRate = 15
        #expect(view.preferredFramesPerSecond == 1)
        paced.batteryRate = 10
        #expect(view.preferredFramesPerSecond == rate(cap: 10))
        view.preferredFramesPerSecond = 1
        paced.batteryRate = nil
        #expect(view.preferredFramesPerSecond == rate(cap: nil))
    }
}

/// A window that counts as on screen without being there, so its view starts a crossfade, which then waits: nothing
/// draws in a test, so `scene` stays the outgoing one, as it does for the 0.8 s of a real fade.
private final class SeenWindow: NSWindow {
    override var occlusionState: NSWindow.OcclusionState { .visible }
}

/// Mid-crossfade the view's rate is the incoming scene's, which may change it before the fade ends; the outgoing
/// scene's changes no longer count.
@MainActor @Test func crossfadeTakesTheIncomingScenesRate() {
    withPower(2) {
        let window = SeenWindow(contentRect: CGRect(x: 0, y: 0, width: 64, height: 64), styleMask: .borderless, backing: .buffered, defer: false)
        let view = WallpaperView()
        window.contentView = view
        let old = Paced(size: view.bounds.size), new = Paced(size: view.bounds.size)
        old.batteryRate = 20
        new.batteryRate = 15
        view.presentScene(old)
        view.presentScene(new, transition: .crossFade(withDuration: 0.8))
        #expect(view.scene === old) // still fading
        #expect(view.cap == 15)
        new.batteryRate = 10
        #expect(view.preferredFramesPerSecond == rate(cap: 10))
        view.preferredFramesPerSecond = 1
        old.batteryRate = 12
        #expect(view.preferredFramesPerSecond == 1)
    }
}

/// A change of rate never sets a frozen or paused view going.
@MainActor @Test func rateChangeKeepsFrozenViewFrozen() {
    let (window, view) = windowed()
    _ = window
    let paced = Paced(size: view.bounds.size)
    paced.batteryRate = 15
    view.presentScene(paced)
    withPower(0) { // Freeze, on any power
        applyPowerState(to: [view])
        paced.batteryRate = 10
        #expect(view.frozen)
    }
    withPower(3) {
        defer { WallpaperView.paused = false }
        WallpaperView.paused = true
        applyPowerState(to: [view])
        paced.batteryRate = 20
        #expect(view.frozen)
    }
}

/// The rates a wallpaper or its scene may ask for: ones that divide 60 and 120, under the battery's standard 30.
@MainActor @Test func batteryRatesDivideTheDisplaysRates() {
    let allowed: Set<Int?> = [nil, 10, 12, 15, 20]
    for wallpaper in allScenes {
        #expect(allowed.contains(wallpaper.batteryRate), "\(wallpaper.name)")
        let scene = wallpaper.make(CGSize(width: 320, height: 200))
        #expect(allowed.contains((scene as? BatteryPaced)?.batteryRate), "\(wallpaper.name)'s scene")
    }
}
