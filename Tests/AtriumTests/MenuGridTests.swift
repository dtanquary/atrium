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

/// The tile under the pointer grows from its own side of the grid, so it never leaves the menu.
@MainActor @Test func magnifiedTilesStayInTheMenu() {
    for count in [28, 31, 40] {
        let bounds = CGRect(x: 0, y: 0, width: MenuGrid.width, height: MenuGrid.height(count: count))
        for index in 0..<count {
            let frame = MenuGrid.frame(index), anchor = MenuGrid.anchor(index, count: count), grow = MenuGrid.magnify - 1
            let grown = CGRect(x: frame.minX - grow * frame.width * anchor.x, y: frame.minY - grow * frame.height * anchor.y,
                               width: frame.width * MenuGrid.magnify, height: frame.height * MenuGrid.magnify)
            #expect(bounds.contains(grown), "tile \(index) of \(count)")
        }
    }
}

/// Opens a menu holding the grid on screen for a moment and captures it, since a menu's glass only renders for real.
///
///     MENU_SHOT=1 swift test --filter menuShot           # → $TMPDIR/atrium-menu.png
///     MENU_SHOT="Nebula" swift test --filter menuShot    # with the pointer resting on that wallpaper, then a click on it
///     SNAPSHOT_APPEARANCE=light MENU_SHOT=1 …            # in Light Mode
///
/// The pointer and the click are events handed to the grid as the menu would hand them, at the middle of the tile
/// worked out from where the grid sits in the menu's window: the real pointer stays where it is.
@MainActor @Test(.enabled(if: ProcessInfo.processInfo.environment["MENU_SHOT"] != nil))
func menuShot() throws {
    let env = ProcessInfo.processInfo.environment
    let path = (env["SNAPSHOT_DIR"] ?? NSTemporaryDirectory()) + "/atrium-menu.png"
    try? FileManager.default.removeItem(atPath: path)
    NSApplication.shared.setActivationPolicy(.accessory)
    if let look = env["SNAPSHOT_APPEARANCE"] { NSApp.appearance = NSAppearance(named: look == "light" ? .aqua : .darkAqua) }
    let wanted = scenes.firstIndex { $0.name == env["MENU_SHOT"] }
    var hovered: String?, picked: String?, previews: [String?] = []
    let menu = NSMenu(), grid = MenuGridView(pick: { picked = $0 }, preview: { previews.append($0) }), item = NSMenuItem()
    func mouse(_ type: NSEvent.EventType) -> NSEvent? {
        guard let wanted, let window = grid.window else { return nil }
        let tile = MenuGrid.frame(wanted), inWindow = grid.convert(grid.bounds, to: nil)
        return .mouseEvent(with: type, location: NSPoint(x: inWindow.minX + tile.midX, y: inWindow.maxY - tile.midY), modifierFlags: [],
                           timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
                           eventNumber: 0, clickCount: 1, pressure: 0)
    }
    menu.autoenablesItems = false
    item.view = grid
    menu.addItem(item)
    menu.addItem(.separator())
    for title in ["Pause", "Shuffle", "Settings…", "Quit Atrium"] { menu.addItem(withTitle: title, action: nil, keyEquivalent: "") }
    // The menu holds the main thread until it closes, so what happens while it's open is set up first: on timers,
    // which run while a menu tracks the mouse. The main queue doesn't, with this test itself a job on it.
    func after(_ seconds: Double, _ work: @escaping @MainActor () -> Void) {
        RunLoop.main.add(Timer(timeInterval: seconds, repeats: false) { _ in MainActor.assumeIsolated(work) }, forMode: .common)
    }
    after(0.7) { mouse(.mouseMoved).map(grid.mouseMoved) }
    after(1.6) {
        hovered = grid.hover.name
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
        mouse(.leftMouseUp).map(grid.mouseUp) // which closes the menu, as a pick does
        menu.cancelTracking()
    }
    let screen = try #require(NSScreen.main).visibleFrame
    menu.popUp(positioning: nil, at: NSPoint(x: screen.maxX - MenuGrid.width - 40, y: screen.maxY - 8), in: nil)
    RunLoop.main.run(until: Date() + 0.2) // for the closed menu's call to put the desktop back
    if let wanted {
        #expect(hovered == scenes[wanted].name && picked == scenes[wanted].name, "over \(hovered ?? "none"), picked \(picked ?? "none")")
        // Resting on the tile previewed it on the desktop, and the menu closing put the desktop's own back (which after
        // a pick finds nothing to undo).
        #expect(previews.contains(scenes[wanted].name) && previews.last == .some(nil), "previews \(previews)")
    }
    print("The menu → \(path)")
}
