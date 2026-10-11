import AppKit
import SwiftUI
import Testing
@testable import Atrium

/// Opens the Settings window on screen for a moment and captures it, since glass only renders in a real window.
///
///     SETTINGS_SHOT="Nebula" swift test --filter settingsWindow   # → $TMPDIR/atrium-settings-Nebula.png
///     SETTINGS_SHOT="About" …                                       # or General or Power
///     SNAPSHOT_DEFAULTS="seat.orbit=1" SETTINGS_SHOT="Pixel Window Seat" …   # with Settings values, as the render test takes them
///     SETTINGS_HEIGHT=1400 SETTINGS_SHOT="Nebula" …                 # a taller window, for a page longer than the usual one
@MainActor @Test(.enabled(if: ProcessInfo.processInfo.environment["SETTINGS_SHOT"] != nil))
func settingsWindow() throws {
    let env = ProcessInfo.processInfo.environment
    let page = env["SETTINGS_SHOT"]!
    let path = (env["SNAPSHOT_DIR"] ?? NSTemporaryDirectory()) + "/atrium-settings-\(page).png"
    // The page Settings opens on (a wallpaper, General, Power or About), in the test's own defaults, with no wallpaper
    // on the desktop so a wallpaper's page shows its Show on Desktop button.
    UserDefaults.standard.set(page, forKey: SettingsView.pageKey)
    UserDefaults.standard.set("none", forKey: "scene")
    let settings = (env["SNAPSHOT_DEFAULTS"] ?? "").split(separator: ",").map { $0.split(separator: "=") }.filter { $0.count == 2 }
    for pair in settings { UserDefaults.standard.set(Double(pair[1]).map { $0 as Any } ?? String(pair[1]), forKey: String(pair[0])) }
    defer { for key in [SettingsView.pageKey, "scene"] + settings.map { String($0[0]) } { UserDefaults.standard.removeObject(forKey: key) } }
    NSApplication.shared.setActivationPolicy(.accessory)
    let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
    window.setContentSize(NSSize(width: 820, height: Double(env["SETTINGS_HEIGHT"] ?? "") ?? 640))
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
    // Where this session may not record the screen, screencapture writes nothing: draw the window's views ourselves.
    // No glass that way, but the preview and every row, menu and label are there to check.
    if !FileManager.default.fileExists(atPath: path), let view = window.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }
    window.close()
    print("Settings for \(page) → \(path)")
}
