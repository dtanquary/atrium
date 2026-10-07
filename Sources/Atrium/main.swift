import AppKit
import IOKit.ps
import ServiceManagement
import os
import SpriteKit
import SwiftUI

/// Pauses rendering while its window is fully covered, so a hidden wallpaper costs nothing, or while frozen. Keeps
/// `WallpaperTime` running as it draws, and restarts drawing if SpriteKit lets it stop (`watch`).
final class WallpaperView: SKView, SKViewDelegate {
    private static let log = Logger(subsystem: "com.dtanquary.atrium", category: "wallpaper")
    /// When it last drew a frame.
    private var lastDrawn = Date()
    /// Holds the current frame still, e.g. in Low Power Mode.
    var frozen = false { didSet { updatePaused() } }
    /// Runs even while frozen until then, so a new scene draws its first frame, or finishes crossfading, and an
    /// uncovered window catches up, before it's held still.
    private var awakeUntil = Date.distantPast

    override func viewDidMoveToWindow() {
        guard let window else { return }
        delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(occlusionChanged),
                                               name: NSWindow.didChangeOcclusionStateNotification, object: window)
    }

    override func presentScene(_ scene: SKScene?) {
        super.presentScene(scene)
        wake(for: 0.5)
    }

    /// Covered, the view isn't drawing, so a transition would wait there, `self.scene` still the old one, until it's
    /// uncovered: the lock screen's still, taken meanwhile, would be of the wallpaper before. So it swaps straight.
    override func presentScene(_ scene: SKScene, transition: SKTransition) {
        guard window?.occlusionState.contains(.visible) == true else { return presentScene(scene) }
        super.presentScene(scene, transition: transition)
        wake(for: 1.5)
    }

    private func wake(for seconds: Double) {
        awakeUntil = Date() + seconds
        updatePaused()
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds + 0.05) { [weak self] in self?.updatePaused() }
    }

    @objc private func occlusionChanged() {
        if window?.occlusionState.contains(.visible) == true { wake(for: 0.5) } else { updatePaused() }
    }

    @objc func updatePaused() {
        let was = isPaused
        isPaused = (frozen && Date() >= awakeUntil) || window?.occlusionState.contains(.visible) != true
        if was, !isPaused { lastDrawn = Date() } // just set going: give it the time `watch` allows before it's judged stopped
    }

    /// Restarts drawing if it has stopped while the view should be running. An SKView has been found holding its
    /// last frame for good after the Mac slept, its display link gone though it wasn't paused, and nothing else
    /// toggles `isPaused` until something changes; pausing and unpausing makes it set its render callback up again.
    /// Called every few seconds, and as the screens wake.
    func watch() {
        guard !isPaused, Date().timeIntervalSince(lastDrawn) > 5 else { return }
        Self.log.error("drawing stopped \(Date().timeIntervalSince(self.lastDrawn), format: .fixed(precision: 0)) s ago while running; restarting")
        isPaused = true
        lastDrawn = Date()
        updatePaused()
    }

    nonisolated func view(_ view: SKView, shouldRenderAtTime time: TimeInterval) -> Bool {
        MainActor.assumeIsolated {
            WallpaperTime.set(time)
            lastDrawn = Date()
        }
        return true
    }
}

/// Runs at the frame rate Settings → Power picks for Low Power Mode, battery or mains power (60 and 30 fps, and
/// frozen in Low Power Mode, unless changed).
@MainActor func applyPowerState(to views: [WallpaperView]) {
    let source = IOPSGetProvidingPowerSourceType(IOPSCopyPowerSourcesInfo().takeRetainedValue()).takeUnretainedValue()
    let fps = Power.rate(ProcessInfo.processInfo.isLowPowerModeEnabled ? Power.lowPower
                         : source as String == kIOPMBatteryPowerKey ? Power.battery : Power.plugged)
    for view in views {
        if fps > 0 { view.preferredFramesPerSecond = fps }
        view.frozen = fps == 0
    }
}

var windows: [NSWindow] = []
// ponytail: one-off moves of settings saved before the app became Atrium and Night Sky became Live Sky; drop after a while
if UserDefaults.standard.object(forKey: "scene") == nil,
   let old = UserDefaults.standard.persistentDomain(forName: "com.dtanquary.wallpaper") {
    for (key, value) in old { UserDefaults.standard.set(value, forKey: key) }
}
if UserDefaults.standard.string(forKey: "scene") == "Night Sky" { UserDefaults.standard.set("Live Sky", forKey: "scene") }
// ponytail: The Sun Today and The Moon became views in Solar System on 2026-09-27, which became Solar System Tour on
// 2026-09-28; drop these moves after a while
if let body = ["The Sun Today": "The Sun", "The Moon": "The Moon"][UserDefaults.standard.string(forKey: "scene") ?? ""] {
    UserDefaults.standard.set("Solar System Tour", forKey: "scene")
    UserDefaults.standard.set(body, forKey: Tour.solarSystem.showKey)
}
// ponytail: Names and Facts switches became one Show menu on 2026-09-28; drop this move after a while
if let names = UserDefaults.standard.object(forKey: "solar.captions") as? Double {
    let facts = UserDefaults.standard.object(forKey: "solar.facts") as? Double ?? 1
    UserDefaults.standard.set(names < 0.5 ? 0.0 : facts < 0.5 ? 2.0 : 3.0, forKey: "solar.captionLines")
    UserDefaults.standard.removeObject(forKey: "solar.captions")
    UserDefaults.standard.removeObject(forKey: "solar.facts")
}
if UserDefaults.standard.string(forKey: "scene") == "Solar System" { UserDefaults.standard.set("Solar System Tour", forKey: "scene") }
if let skip = UserDefaults.standard.string(forKey: Shuffle.skipKey), skip.split(separator: ",").contains("Solar System") {
    UserDefaults.standard.set(skip.split(separator: ",").map { $0 == "Solar System" ? "Solar System Tour" : String($0) }.joined(separator: ","),
                              forKey: Shuffle.skipKey)
}
if let name = UserDefaults.standard.string(forKey: "sun.wavelength") {
    if let i = TheSun.wavelengths.firstIndex(where: { $0.name == name }) { UserDefaults.standard.set(Double(i + 1), forKey: TheSun.wavelengthKnob.key) }
    UserDefaults.standard.removeObject(forKey: "sun.wavelength")
}
var current = UserDefaults.standard.string(forKey: "scene") ?? defaultScene.name
// A wallpaper that's been cut or hidden as unfinished gives way to the default.
if !scenes.contains(where: { $0.name == current }) {
    current = defaultScene.name
    UserDefaults.standard.removeObject(forKey: "scene")
}

@MainActor func currentScene(size: CGSize) -> SKScene {
    (scenes.first { $0.name == current } ?? defaultScene).make(size)
}

/// A borderless window for one display, parked at desktop level: above the system wallpaper,
/// below desktop icons, on every Space, and invisible to clicks.
@MainActor func wallpaperWindow(for screen: NSScreen) -> NSWindow {
    let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
    window.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopWindow)))
    window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    window.ignoresMouseEvents = true
    window.isReleasedWhenClosed = false

    let view = WallpaperView()
    applyPowerState(to: [view])
    view.presentScene(currentScene(size: screen.frame.size))
    window.contentView = view
    window.orderFront(nil)
    return window
}

/// Keeps one wallpaper window per display. Windows whose display hasn't changed are left alone so their scene
/// keeps running; macOS posts screen-change notifications for more than just plugging displays in.
@MainActor func syncWindows() {
    let screens = NSScreen.screens
    let kept = windows.filter { window in screens.contains { $0.frame == window.frame } }
    let added = screens.filter { screen in !kept.contains { $0.frame == screen.frame } }.map(wallpaperWindow)
    let gone = windows.filter { !kept.contains($0) }
    windows = kept + added
    if !added.isEmpty { matchLockScreen(after: 1.5) }
    guard !gone.isEmpty else { return }
    Task { // let the new windows draw a frame first, so the system wallpaper never flashes through
        try? await Task.sleep(for: .seconds(0.5))
        gone.forEach { $0.close() }
    }
}

/// Puts a wallpaper on the desktop and remembers it.
@MainActor func show(_ name: String) {
    current = name
    UserDefaults.standard.set(name, forKey: "scene")
    switchScene()
}

/// Crossfades every display to the chosen scene in its existing window.
@MainActor func switchScene() {
    for window in windows {
        let view = window.contentView as? SKView
        view?.presentScene(currentScene(size: window.frame.size), transition: .crossFade(withDuration: 0.8))
    }
    matchLockScreen(after: 1.5)
}

/// With Match the lock screen on, takes a fresh still once the scene has settled.
@MainActor func matchLockScreen(after seconds: Double) {
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
        if LockScreen.knob.value > 0.5 { LockScreen.match(windows) }
    }
}

/// Builds the wallpapers afresh once `WallpaperTime` has run for `hours`, restarting it along with every scene's own
/// clock, so no Float a shader animates by grows large enough to coarsen. Without `fade` it swaps them straight, for
/// when the displays are asleep and nobody's looking.
// ponytail: with a fade, the outgoing scene's u_now jumps to 0 as the crossfade starts; it's lost in the fade, and
// only displays that never sleep see it, every 3 days
@MainActor func refreshIfStale(after hours: Double, fade: Bool) {
    guard WallpaperTime.elapsed > hours * 3600 else { return }
    WallpaperTime.restart()
    if fade { return switchScene() }
    for window in windows { (window.contentView as? SKView)?.presentScene(currentScene(size: window.frame.size)) }
    matchLockScreen(after: 1.5)
}

/// The Settings window, an ordinary window that reopens where it was left. While it's open Atrium turns into a
/// regular app, in the Dock and ⌘-Tab with its own menus; closed, it's back to menu bar only. Its content is built
/// on opening and dropped on closing, so the live preview's scene doesn't linger.
@MainActor final class SettingsWindow: NSObject, NSWindowDelegate {
    static let shared = SettingsWindow()

    private lazy var window: NSWindow = {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 640),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: true)
        window.titlebarAppearsTransparent = true // sidebar runs up under the title bar, like System Settings
        window.titleVisibility = .hidden // the page has its own header; the title still names it in the Dock and Mission Control
        window.title = "Atrium"
        window.contentMinSize = NSSize(width: 720, height: 480)
        window.isReleasedWhenClosed = false
        window.delegate = self
        return window
    }()

    /// Opens Settings, on `page` if given (a wallpaper's name, or General, Power or About), else where it was left.
    func open(page: String? = nil) {
        if let page { UserDefaults.standard.set(page, forKey: SettingsView.pageKey) }
        if !window.isVisible {
            let hosting = NSHostingController(rootView: SettingsView())
            hosting.sizingOptions = [] // grouped Forms scroll, so they have no height of their own to size the window by
            // The window takes its new content's size, which is nothing yet, and would save that as a 1×1 frame.
            hosting.view.frame.size = window.contentRect(forFrameRect: window.frame).size
            window.contentViewController = hosting
            // Not "Settings": 0.67.0 saved a 1×1 frame under that name on reopening Settings, which hid it for good.
            if !window.setFrameUsingName("Settings Window") {
                window.setContentSize(NSSize(width: 820, height: 640))
                window.center()
            }
            window.setFrameAutosaveName("Settings Window")
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless() // in front even when macOS holds back activating a menu bar app
    }

    func windowWillClose(_ notification: Notification) {
        window.contentViewController = nil
        NSApp.setActivationPolicy(.accessory)
    }
}

/// The menu bar icon: pick or shuffle wallpapers, open Settings, toggle Open at Login, quit.
@MainActor final class StatusMenu: NSObject, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    override init() {
        super.init()
        item.button?.image = NSImage(systemSymbolName: "sparkles.tv", accessibilityDescription: "Atrium")
        item.menu = NSMenu()
        item.menu?.delegate = self
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if let update = Updater.shared.release {
            menu.addItem(withTitle: "Update to Atrium \(update.version)…", action: #selector(openUpdate), keyEquivalent: "").target = self
            menu.addItem(.separator())
        }
        for scene in scenes {
            let entry = menu.addItem(withTitle: scene.name, action: #selector(pick), keyEquivalent: "")
            entry.target = self
            entry.state = scene.name == current ? .on : .off
        }
        menu.addItem(.separator())
        let shuffle = menu.addItem(withTitle: "Shuffle", action: #selector(toggleShuffle), keyEquivalent: "")
        shuffle.target = self
        shuffle.state = Shuffle.on.value > 0.5 ? .on : .off
        if Shuffle.on.value > 0.5 {
            menu.addItem(withTitle: "Next Wallpaper", action: #selector(nextWallpaper), keyEquivalent: "").target = self
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        let login = menu.addItem(withTitle: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        let fullSpeed = menu.addItem(withTitle: "Full Speed on Battery", action: #selector(toggleFullSpeed), keyEquivalent: "")
        fullSpeed.target = self
        fullSpeed.state = Power.battery.value >= Power.plugged.value ? .on : .off
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Atrium", action: #selector(NSApplication.terminate), keyEquivalent: "q")
    }

    @objc func pick(_ sender: NSMenuItem) {
        show(sender.title)
    }

    @objc func openSettings() {
        SettingsWindow.shared.open()
    }

    @objc func openUpdate() {
        SettingsWindow.shared.open(page: UpdatePage.tag)
    }

    @objc func openAbout() {
        SettingsWindow.shared.open(page: AboutPage.tag)
    }

    /// For demos: battery runs as fast as mains power, or goes back to its default.
    @objc func toggleFullSpeed(_ sender: NSMenuItem) {
        if sender.state == .on {
            UserDefaults.standard.removeObject(forKey: Power.battery.key)
        } else {
            UserDefaults.standard.set(Power.plugged.value, forKey: Power.battery.key)
        }
    }

    @objc func toggleLogin() {
        setOpenAtLogin(SMAppService.mainApp.status != .enabled)
    }

    @objc func toggleShuffle(_ sender: NSMenuItem) {
        UserDefaults.standard.set(sender.state == .on ? 0.0 : 1.0, forKey: Shuffle.on.key)
    }

    @objc func nextWallpaper() {
        if let name = Shuffle.next() { show(name) }
    }
}

/// Opening Atrium again while it runs (from Finder, Spotlight or the Dock) opens Settings: the way back in if the
/// menu bar icon is hidden behind the notch or by the Menu Bar settings.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        SettingsWindow.shared.open()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        LockScreen.restore()
    }
}

/// The menus shown while Settings is open and Atrium is a regular app: the standard shortcuts (⌘W, ⌘Q, ⌘M, ⌘C…).
@MainActor func mainMenu(_ status: StatusMenu) -> NSMenu {
    let bar = NSMenu()
    func add(_ title: String, _ items: [NSMenuItem]) -> NSMenu {
        let menu = NSMenu(title: title)
        items.forEach(menu.addItem)
        bar.addItem(withTitle: title, action: nil, keyEquivalent: "").submenu = menu
        return menu
    }
    func item(_ title: String, _ action: Selector, _ key: String, _ target: AnyObject? = nil,
              _ modifiers: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target
        item.keyEquivalentModifierMask = modifiers
        return item
    }
    _ = add("Atrium", [item("About Atrium", #selector(StatusMenu.openAbout), "", status), .separator(),
                       item("Settings…", #selector(StatusMenu.openSettings), ",", status), .separator(),
                       item("Hide Atrium", #selector(NSApplication.hide), "h"),
                       item("Hide Others", #selector(NSApplication.hideOtherApplications), "h", nil, [.command, .option]),
                       item("Show All", #selector(NSApplication.unhideAllApplications), ""), .separator(),
                       item("Quit Atrium", #selector(NSApplication.terminate), "q")])
    _ = add("File", [item("Close Window", #selector(NSWindow.performClose), "w")])
    _ = add("Edit", [item("Cut", #selector(NSText.cut), "x"), item("Copy", #selector(NSText.copy), "c"),
                     item("Paste", #selector(NSText.paste), "v"), item("Select All", #selector(NSText.selectAll), "a")])
    NSApp.windowsMenu = add("Window", [item("Minimize", #selector(NSWindow.performMiniaturize), "m"),
                                       item("Zoom", #selector(NSWindow.performZoom), ""), .separator(),
                                       item("Bring All to Front", #selector(NSApplication.arrangeInFront), "")])
    return bar
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // menu bar only, no Dock icon, until Settings opens
let delegate = AppDelegate()
app.delegate = delegate
let menu = StatusMenu()
app.mainMenu = mainMenu(menu)
// First launch: open Settings with the welcome over it, so there's more to see than a new icon in the menu bar.
if !UserDefaults.standard.bool(forKey: "welcomed") {
    UserDefaults.standard.set(true, forKey: "welcomed")
    if UserDefaults.standard.object(forKey: "scene") == nil {
        UserDefaults.standard.set(true, forKey: WelcomeView.key)
        SettingsWindow.shared.open()
    }
}

syncWindows()
NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                       object: nil, queue: .main) { _ in
    MainActor.assumeIsolated { syncWindows() }
}

// Follow Low Power Mode, plugging in or unplugging, and Settings → Power as they change.
for name in [.NSProcessInfoPowerStateDidChange, UserDefaults.didChangeNotification] {
    NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
        MainActor.assumeIsolated { applyPowerState(to: windows.compactMap { $0.contentView as? WallpaperView }) }
    }
}
if let source = IOPSNotificationCreateRunLoopSource({ _ in
    MainActor.assumeIsolated { applyPowerState(to: windows.compactMap { $0.contentView as? WallpaperView }) }
}, nil)?.takeRetainedValue() {
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
}
// Move on to another wallpaper every so often while Shuffle is on, or at each unlock if it's set to. loginwindow posts
// the unlock; the name isn't documented, but has been the same for years.
Shuffle.reschedule()
DistributedNotificationCenter.default().addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { _ in
    MainActor.assumeIsolated { if Shuffle.onUnlock, let name = Shuffle.next() { show(name) } }
}
NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { _ in
    MainActor.assumeIsolated {
        Shuffle.reschedule()
        LockScreen.settingChanged(windows)
    }
}
// Match the lock screen, or put back the user's wallpaper if a crash left one of ours, once the scenes have drawn;
// then keep the still fresh (time-of-day scenes drift), and take one as the displays sleep, just before a lock.
DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { LockScreen.update(windows) }
Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { _ in
    MainActor.assumeIsolated { matchLockScreen(after: 0) }
}
// macOS gave that still to the Space in front only, so each other Space gets it as it comes to the front.
NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { _ in
    MainActor.assumeIsolated { LockScreen.spaceChanged() }
}
// Rebuild a long-running wallpaper so the clocks its shaders animate by stay small: quietly once the displays sleep,
// or with a crossfade for displays that never do.
NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { _ in
    MainActor.assumeIsolated {
        refreshIfStale(after: 12, fade: false)
        matchLockScreen(after: 0)
    }
}
Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
    MainActor.assumeIsolated { refreshIfStale(after: 72, fade: true) }
}
// A wallpaper that has stopped drawing though it should be running is restarted (see `WallpaperView.watch`).
Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
    MainActor.assumeIsolated { windows.compactMap { $0.contentView as? WallpaperView }.forEach { $0.watch() } }
}
NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { _ in
    MainActor.assumeIsolated { windows.compactMap { $0.contentView as? WallpaperView }.forEach { $0.watch() } }
}
// Look for a newer release once a day, unless Settings → Software Update says not to.
Updater.shared.check()
Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
    MainActor.assumeIsolated { Updater.shared.check() }
}
// Rebuild the scene in the other look when macOS switches between Light and Dark Mode.
// ponytail: rebuilds every scene, even ones with a single look; it only happens a couple of times a day
let appearance = app.observe(\.effectiveAppearance) { _, _ in
    MainActor.assumeIsolated { switchScene() }
}
app.run()
