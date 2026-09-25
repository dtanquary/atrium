import AppKit
import ServiceManagement
import SpriteKit

/// Pauses rendering while its window is fully covered, so a hidden wallpaper costs nothing.
final class WallpaperView: SKView {
    override func viewDidMoveToWindow() {
        guard let window else { return }
        NotificationCenter.default.addObserver(self, selector: #selector(occlusionChanged),
                                               name: NSWindow.didChangeOcclusionStateNotification, object: window)
    }

    @objc func occlusionChanged() {
        isPaused = window?.occlusionState.contains(.visible) != true
    }
}

var windows: [NSWindow] = []
var current = UserDefaults.standard.string(forKey: "scene") ?? scenes[0].name

/// One borderless window per display, parked at desktop level: above the system wallpaper,
/// below desktop icons, on every Space, and invisible to clicks.
@MainActor func showWallpapers() {
    let make = (scenes.first { $0.name == current } ?? scenes[0]).make
    let old = windows
    // ponytail: rebuilt from scratch on any display change, which restarts the scene
    windows = NSScreen.screens.map { screen in
        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopWindow)))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false

        let view = WallpaperView()
        view.preferredFramesPerSecond = 30 // ponytail: plenty for ambient motion; raise if it looks steppy
        view.presentScene(make(screen.frame.size))
        window.contentView = view
        window.orderFront(nil)
        return window
    }
    old.forEach { $0.close() } // after the new ones are up, so the system wallpaper never flashes through
}

/// The menu bar icon: pick a wallpaper, toggle Open at Login, quit.
@MainActor final class StatusMenu: NSObject, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

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
        let login = menu.addItem(withTitle: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate), keyEquivalent: "q")
    }

    @objc func pick(_ sender: NSMenuItem) {
        current = sender.title
        UserDefaults.standard.set(current, forKey: "scene")
        showWallpapers()
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

showWallpapers()
NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                       object: nil, queue: .main) { _ in
    MainActor.assumeIsolated { showWallpapers() }
}
app.run()
