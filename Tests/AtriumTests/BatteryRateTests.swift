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

/// Runs `body` with the defaults in `settings` set, then removes them.
@MainActor private func with(_ settings: [String: Double], _ body: () throws -> Void) rethrows {
    defer { settings.keys.forEach(UserDefaults.standard.removeObject) }
    for (key, value) in settings { UserDefaults.standard.set(value, forKey: key) }
    try body()
}

private let small = CGSize(width: 320, height: 200)

/// Flowing Gradient runs slower on battery while its pools alone move, and at the battery's rate with the ribbons,
/// following the switch as it's flipped.
@MainActor @Test func flowingGradientRateFollowsRibbons() {
    with(["gradient.ribbonsOn": 0]) {
        let scene = FlowingGradient(size: small)
        #expect(scene.batteryRate == 20)
        UserDefaults.standard.set(1.0, forKey: "gradient.ribbonsOn")
        #expect(scene.batteryRate == nil)
    }
}

/// Game of Life's rate on battery follows its look: Calm slower than Classic.
@MainActor @Test func gameOfLifeRateFollowsLook() {
    with(["life.calm": 1]) {
        let scene = GameOfLife(size: small)
        #expect(scene.batteryRate == 12)
        UserDefaults.standard.set(0.0, forKey: "life.calm")
        #expect(scene.batteryRate == 20)
    }
}

/// Weather runs slower on battery under fair skies and fog, at the battery's rate in rain, and follows the weather
/// as it changes; A Tree for the Year, built on it, takes the calm rate back.
@MainActor @Test func weatherRateFollowsTheWeather() {
    with(["weather.lock": 1, "tree.lock": 1]) { // Clear
        let scene = WeatherScene(size: small)
        #expect(scene.batteryRate == 15)
        UserDefaults.standard.set(6.0, forKey: "weather.lock") // Rain
        #expect(scene.batteryRate == nil)
        UserDefaults.standard.set(4.0, forKey: "weather.lock") // Fog
        #expect(scene.batteryRate == 15)
        #expect(TreeScene(size: small).batteryRate == nil)
    }
}

/// Etching runs at 20 fps on battery while drawing, and 10 once the picture is done, resting or clearing.
@MainActor @Test func etchingRateFollowsTheDrawing() {
    for (hooks, rate) in [(["etching.drawn": 0.4], 20), (["etching.drawn": 1], 10), (["etching.cleared": 0.5], 10)] {
        with(hooks.merging([Etching.picture.key: 1]) { $1 }) {
            let scene = Etching(size: small)
            scene.update(ProcessInfo.processInfo.systemUptime)
            #expect(scene.batteryRate == rate, "\(hooks)")
        }
    }
}

/// Earth from Orbit runs at 10 fps on battery with no storm near, and at the battery's rate while it has storm cells
/// to flash in (here the preview's).
@MainActor @Test func earthRateFollowsStorms() {
    with(["earth.lightning": 1, "earth.previewStorm": 1]) {
        let scene = EarthFromOrbit(size: small)
        scene.update(1)
        #expect(scene.batteryRate == nil)
    }
    with(["earth.lightning": 0]) {
        let scene = EarthFromOrbit(size: small)
        scene.update(1)
        #expect(scene.batteryRate == 10)
    }
}

/// Dappled Light runs at 10 fps on battery under an overcast sky, which casts no leaf shadows.
@MainActor @Test func dappledLightRateUnderCloud() {
    with(["dappled.weather": 3]) { #expect(DappledLight(size: small).batteryRate == 10) }
}

/// The airliner and the space station run at 15 fps on battery while they paint 15 times a second, as at Speed 1×,
/// and at the battery's rate once a higher Speed has them painting more often. The Spaceport starts between launches,
/// at 15; Pixel City has no cap.
@MainActor @Test func pixelRates() {
    with(["seat.speed": 1]) {
        let plane = PixelWindowSeat(size: small)
        #expect(plane.batteryRate == 15)
        UserDefaults.standard.set(10.0, forKey: "seat.speed")
        #expect(plane.batteryRate == nil)
    }
    with(["seat.speed": 1]) { #expect(PixelOrbit(size: small).batteryRate == 15) }
    #expect(PixelCity(size: small, spaceport: true).batteryRate == 15)
    #expect(PixelCity(size: small, spaceport: false).batteryRate == nil)
}
