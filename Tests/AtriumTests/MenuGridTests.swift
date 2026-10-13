import AppKit
import Testing
@testable import Atrium

/// A wallpaper with no still, or one that won't decode, would be a blank tile in the menu's grid.
@MainActor @Test func everyWallpaperHasAStillForTheMenu() {
    for wallpaper in allScenes {
        for light in [false, true] {
            #expect(MenuGrid.still(wallpaper.preview(light: light)).size.width > 0, "\(wallpaper.name)")
        }
    }
}

/// The grid finds each tile from any point on it and from the half gap round it, and nothing off the tiles.
@MainActor @Test func menuGridFindsTheTileUnderThePointer() {
    let count = 28
    for index in 0..<count {
        let frame = MenuGrid.frame(index)
        #expect(MenuGrid.index(at: CGPoint(x: frame.midX, y: frame.midY), count: count) == index)
        #expect(MenuGrid.index(at: CGPoint(x: frame.minX - 3, y: frame.maxY + 3), count: count) == index)
    }
    #expect(MenuGrid.index(at: CGPoint(x: 2, y: 60), count: count) == nil) // the left margin
    #expect(MenuGrid.index(at: CGPoint(x: 200, y: 12), count: count) == nil) // the caption
    #expect(MenuGrid.index(at: CGPoint(x: MenuGrid.frame(29).midX, y: MenuGrid.frame(29).midY), count: count) == nil) // past the last
    #expect(abs(MenuGrid.frame(MenuGrid.across - 1).maxX + MenuGrid.inset - MenuGrid.width) < 0.001)
    #expect(abs(MenuGrid.frame(count - 1).maxY + MenuGrid.bottom - MenuGrid.height(count: count)) < 0.001)
}

/// Opens a menu holding the grid on screen for a moment and captures it, since a menu's glass only renders for real.
///
///     MENU_SHOT=1 swift test --filter menuShot           # → $TMPDIR/atrium-menu.png
///     MENU_SHOT="Nebula" swift test --filter menuShot    # with the pointer over that wallpaper
///     SNAPSHOT_APPEARANCE=light MENU_SHOT=1 …            # in Light Mode
@MainActor @Test(.enabled(if: ProcessInfo.processInfo.environment["MENU_SHOT"] != nil))
func menuShot() throws {
    let env = ProcessInfo.processInfo.environment
    let path = (env["SNAPSHOT_DIR"] ?? NSTemporaryDirectory()) + "/atrium-menu.png"
    try? FileManager.default.removeItem(atPath: path)
    NSApplication.shared.setActivationPolicy(.accessory)
    if let look = env["SNAPSHOT_APPEARANCE"] { NSApp.appearance = NSAppearance(named: look == "light" ? .aqua : .darkAqua) }
    let menu = NSMenu(), grid = MenuGridView { _ in }, item = NSMenuItem()
    menu.autoenablesItems = false
    item.view = grid
    menu.addItem(withTitle: "Pause", action: nil, keyEquivalent: "")
    menu.addItem(.separator())
    menu.addItem(item)
    menu.addItem(.separator())
    for title in ["Shuffle", "Settings…", "Quit Atrium"] { menu.addItem(withTitle: title, action: nil, keyEquivalent: "") }
    // The menu holds the main thread until it closes, so what happens while it's open is set up first: on timers,
    // which run while a menu tracks the mouse. The main queue doesn't, with this test itself a job on it.
    func after(_ seconds: Double, _ work: @escaping @MainActor () -> Void) {
        RunLoop.main.add(Timer(timeInterval: seconds, repeats: false) { _ in MainActor.assumeIsolated(work) }, forMode: .common)
    }
    after(0.7) { grid.hover.name = scenes.first { $0.name == env["MENU_SHOT"] }?.name }
    after(1.6) {
        // A capture of the menu's window alone comes out empty, so this takes its part of the screen, desktop and all.
        if let area = grid.window?.frame.insetBy(dx: -12, dy: -12), let screen = NSScreen.screens.first {
            let capture = Process()
            capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            capture.arguments = ["-x", "-R", "\(Int(area.minX)),\(Int(screen.frame.maxY - area.maxY)),\(Int(area.width)),\(Int(area.height))", path]
            try? capture.run()
            capture.waitUntilExit()
        }
        // Where this session may not record the screen, screencapture writes nothing: draw the grid ourselves, with no glass.
        if !FileManager.default.fileExists(atPath: path), let bitmap = grid.bitmapImageRepForCachingDisplay(in: grid.bounds) {
            grid.cacheDisplay(in: grid.bounds, to: bitmap)
            try? bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        }
        menu.cancelTracking()
    }
    let screen = try #require(NSScreen.main).visibleFrame
    menu.popUp(positioning: nil, at: NSPoint(x: screen.maxX - MenuGrid.width - 40, y: screen.maxY - 8), in: nil)
    print("The menu → \(path)")
}
