import AppKit
import SwiftUI
import Testing
@testable import Atrium

/// Opens the Settings window on screen for a moment and captures it, since glass only renders in a real window.
///
///     SETTINGS_SHOT="Nebula" swift test --filter settingsWindow   # → $TMPDIR/atrium-settings-Nebula.png
@MainActor @Test(.enabled(if: ProcessInfo.processInfo.environment["SETTINGS_SHOT"] != nil))
func settingsWindow() throws {
    let env = ProcessInfo.processInfo.environment
    let page = env["SETTINGS_SHOT"]!
    let path = (env["SNAPSHOT_DIR"] ?? NSTemporaryDirectory()) + "/atrium-settings-\(page).png"
    UserDefaults.standard.set(page, forKey: "scene") // the page Settings opens on (the test's own defaults)
    defer { UserDefaults.standard.removeObject(forKey: "scene") }
    NSApplication.shared.setActivationPolicy(.accessory)
    let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
    window.setContentSize(NSSize(width: 820, height: 640))
    window.styleMask.insert(.fullSizeContentView)
    window.titlebarAppearsTransparent = true
    window.title = "Atrium"
    if let look = env["SNAPSHOT_APPEARANCE"] { window.appearance = NSAppearance(named: look == "light" ? .aqua : .darkAqua) }
    window.center()
    window.orderFrontRegardless()
    RunLoop.main.run(until: Date() + 1)
    UserDefaults.standard.set("none", forKey: "scene") // so the page shows its Show on Desktop button
    RunLoop.main.run(until: Date() + 1)
    let capture = Process()
    capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    capture.arguments = ["-x", "-o", "-l", "\(window.windowNumber)", path]
    try capture.run()
    capture.waitUntilExit()
    window.close()
    print("Settings for \(page) → \(path)")
}
