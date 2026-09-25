import AppKit
import IOKit.ps
import ServiceManagement
import SpriteKit
import SwiftUI

/// Pauses rendering while its window is fully covered, so a hidden wallpaper costs nothing, or while frozen.
final class WallpaperView: SKView {
    /// Holds the current frame still, e.g. in Low Power Mode.
    var frozen = false { didSet { updatePaused() } }

    override func viewDidMoveToWindow() {
        guard let window else { return }
        NotificationCenter.default.addObserver(self, selector: #selector(updatePaused),
                                               name: NSWindow.didChangeOcclusionStateNotification, object: window)
    }

    @objc func updatePaused() {
        isPaused = frozen || window?.occlusionState.contains(.visible) != true
    }
}

/// Still in Low Power Mode, 15 fps on battery, 30 fps on mains power.
@MainActor func applyPowerState(to views: [WallpaperView]) {
    let source = IOPSGetProvidingPowerSourceType(IOPSCopyPowerSourcesInfo().takeRetainedValue()).takeUnretainedValue()
    for view in views {
        view.preferredFramesPerSecond = source as String == kIOPMBatteryPowerKey ? 15 : 30
        view.frozen = ProcessInfo.processInfo.isLowPowerModeEnabled
    }
}

var windows: [NSWindow] = []
// ponytail: carries over a selection saved before Night Sky became Live Sky; drop after a while
if UserDefaults.standard.string(forKey: "scene") == "Night Sky" { UserDefaults.standard.set("Live Sky", forKey: "scene") }
var current = UserDefaults.standard.string(forKey: "scene") ?? scenes[0].name

@MainActor func currentScene(size: CGSize) -> SKScene {
    (scenes.first { $0.name == current } ?? scenes[0]).make(size)
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
}

/// The menu bar icon: pick a wallpaper, open Settings, toggle Open at Login, quit.
@MainActor final class StatusMenu: NSObject, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    private lazy var settings: NSWindow = {
        let hosting = NSHostingController(rootView: SettingsView())
        hosting.sizingOptions = [] // grouped Forms scroll, so they have no height of their own to size the window by
        let window = NSWindow(contentViewController: hosting)
        window.setContentSize(NSSize(width: 820, height: 640))
        window.styleMask.insert(.fullSizeContentView) // sidebar runs up under the title bar, like System Settings
        window.titlebarAppearsTransparent = true
        window.title = "Wallpapers"
        window.level = .floating // stays above other windows while you watch the wallpaper change
        window.isReleasedWhenClosed = false
        return window
    }()

    override init() {
        super.init()
        item.button?.image = NSImage(systemSymbolName: "sparkles.tv", accessibilityDescription: "Animated wallpaper")
        item.menu = NSMenu()
        item.menu?.delegate = self
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        for scene in scenes {
            let entry = menu.addItem(withTitle: scene.name, action: #selector(pick), keyEquivalent: "")
            entry.target = self
            entry.state = scene.name == current ? .on : .off
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        let login = menu.addItem(withTitle: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate), keyEquivalent: "q")
    }

    @objc func pick(_ sender: NSMenuItem) {
        show(sender.title)
    }

    @objc func openSettings() {
        NSApp.activate()
        settings.makeKeyAndOrderFront(nil)
    }

    @objc func toggleLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            NSAlert(error: error).runModal()
        }
        if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
let menu = StatusMenu()

syncWindows()
NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                       object: nil, queue: .main) { _ in
    MainActor.assumeIsolated { syncWindows() }
}

// Follow Low Power Mode and plugging in or unplugging as they happen.
NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { _ in
    MainActor.assumeIsolated { applyPowerState(to: windows.compactMap { $0.contentView as? WallpaperView }) }
}
if let source = IOPSNotificationCreateRunLoopSource({ _ in
    MainActor.assumeIsolated { applyPowerState(to: windows.compactMap { $0.contentView as? WallpaperView }) }
}, nil)?.takeRetainedValue() {
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
}
// Rebuild the scene in the other look when macOS switches between Light and Dark Mode.
// ponytail: rebuilds every scene, even ones with a single look; it only happens a couple of times a day
let appearance = app.observe(\.effectiveAppearance) { _, _ in
    MainActor.assumeIsolated { switchScene() }
}
app.run()
