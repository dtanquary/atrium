import AppKit
import SwiftUI
import Testing
@testable import Atrium

/// Opens the Settings window on screen for a moment and captures it, since glass only renders in a real window.
///
///     SETTINGS_SHOT="Nebula" swift test --filter settingsWindow   # → $TMPDIR/atrium-settings-Nebula.png
///     SETTINGS_SHOT="About" …                                       # or General or Power
@MainActor @Test(.enabled(if: ProcessInfo.processInfo.environment["SETTINGS_SHOT"] != nil))
func settingsWindow() throws {
    let env = ProcessInfo.processInfo.environment
    let page = env["SETTINGS_SHOT"]!
    let path = (env["SNAPSHOT_DIR"] ?? NSTemporaryDirectory()) + "/atrium-settings-\(page).png"
    // The page Settings opens on (a wallpaper, General, Power or About), in the test's own defaults, with no wallpaper
    // on the desktop so a wallpaper's page shows its Show on Desktop button.
    UserDefaults.standard.set(page, forKey: SettingsView.pageKey)
    UserDefaults.standard.set("none", forKey: "scene")
    defer { for key in [SettingsView.pageKey, "scene"] { UserDefaults.standard.removeObject(forKey: key) } }
    NSApplication.shared.setActivationPolicy(.accessory)
    let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
    window.setContentSize(NSSize(width: 820, height: 640))
    window.styleMask.insert(.fullSizeContentView)
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.title = "Atrium"
    if let look = env["SNAPSHOT_APPEARANCE"] { window.appearance = NSAppearance(named: look == "light" ? .aqua : .darkAqua) }
    window.center()
    window.orderFrontRegardless()
    RunLoop.main.run(until: Date() + 2)
    let capture = Process()
    capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    capture.arguments = ["-x", "-o", "-l", "\(window.windowNumber)", path]
    try capture.run()
    capture.waitUntilExit()
    window.close()
    print("Settings for \(page) → \(path)")
}
