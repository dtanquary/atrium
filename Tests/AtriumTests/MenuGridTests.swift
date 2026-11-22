import AppKit
import AVFoundation
import Testing
@testable import Atrium

/// A wallpaper with no still, or one that won't decode, would be a blank tile in the menu's grid.
@MainActor @Test func everyWallpaperHasAStillForTheMenu() {
    for wallpaper in allScenes {
        for light in [false, true] {
            #expect(MenuGrid.still(MenuGrid.picture(wallpaper, light: light)).size.width > 0, "\(wallpaper.name)")
        }
    }
}

/// Every wallpaper shown has a loop for its tile, and the tile's picture is that loop's first frame as the app decodes
/// it, so nothing jumps when the tile under the pointer starts to play. Run `site/media.sh tiles` if this fails.
@MainActor @Test func everyTilePictureIsItsLoopsFirstFrame() async throws {
    let size = (width: 120, height: 78)
    func pixels(_ image: CGImage) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: size.width * size.height * 4)
        let context = CGContext(data: &bytes, width: size.width, height: size.height, bitsPerComponent: 8, bytesPerRow: size.width * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        context?.interpolationQuality = .high
        context?.draw(image, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        return bytes
    }
    for wallpaper in scenes {
        let loop = try #require(MenuGrid.loop(wallpaper), "\(wallpaper.name) has no menu-*.mp4")
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: loop))
        (generator.requestedTimeToleranceBefore, generator.requestedTimeToleranceAfter) = (.zero, .zero)
        let first = try await generator.image(at: .zero).image
        let source = try #require(CGImageSourceCreateWithURL(MenuGrid.picture(wallpaper, light: false) as CFURL, nil))
        let picture = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let difference = zip(pixels(first), pixels(picture)).enumerated().filter { $0.offset % 4 != 3 }
            .map { Double(Int($0.element.0) - Int($0.element.1)) }
        let shift = difference.reduce(0, +) / Double(difference.count), mean = difference.map(abs).reduce(0, +) / Double(difference.count)
        // JPEG's noise on fine detail comes to 1 to 3.5 levels in all, but it shifts no colour: under half a level.
        #expect(abs(shift) < 1 && mean < 5, "\(wallpaper.name): the picture is \(mean) levels off its loop's first frame, shifted \(shift)")
    }
}

/// The grid finds each tile from any point on it and from the half gap round it, and nothing off the tiles.
@MainActor @Test func menuGridFindsTheTileUnderThePointer() {
    let count = 28
    for lead in [0, 1, 6, 7, count] { // none starred, a row of them part full, full, into a second, and every one
        for index in 0..<count {
            let frame = MenuGrid.frame(index, lead: lead)
            #expect(MenuGrid.index(at: CGPoint(x: frame.midX, y: frame.midY), count: count, lead: lead) == index)
            #expect(MenuGrid.index(at: CGPoint(x: frame.minX - 3, y: frame.maxY + 3), count: count, lead: lead) == index)
        }
        #expect(MenuGrid.index(at: CGPoint(x: 2, y: 60), count: count, lead: lead) == nil) // the left margin
        #expect(MenuGrid.index(at: CGPoint(x: 200, y: 12), count: count, lead: lead) == nil) // the caption
        let past = MenuGrid.frame(count + 1, lead: lead)
        #expect(MenuGrid.index(at: CGPoint(x: past.midX, y: past.midY), count: count, lead: lead) == nil) // past the last
        #expect(abs(MenuGrid.frame(count - 1, lead: lead).maxY + MenuGrid.bottom - MenuGrid.height(count: count, lead: lead)) < 0.001)
    }
    #expect(abs(MenuGrid.frame(MenuGrid.across - 1, lead: 0).maxX + MenuGrid.inset - MenuGrid.width) < 0.001)
}

/// The favourites have rows of their own with a line under them, and the rest start a fresh row: with none starred,
/// or every one, the grid is as it was.
@MainActor @Test func favoritesHaveRowsOfTheirOwn() throws {
    let row = MenuGrid.tile.height + MenuGrid.gap, first = MenuGrid.frame(0, lead: 3)
    #expect(MenuGrid.frame(3, lead: 3).minX == first.minX) // the first of the rest, back at the left edge
    #expect(abs(MenuGrid.frame(3, lead: 3).minY - first.minY - row - MenuGrid.shelf) < 0.001) // a row down, past the line
    #expect(abs(MenuGrid.frame(7, lead: 7).minY - first.minY - 2 * row - MenuGrid.shelf) < 0.001) // seven starred take two rows
    let line = try #require(MenuGrid.line(count: 27, lead: 3))
    #expect(MenuGrid.frame(2, lead: 3).maxY < line && line < MenuGrid.frame(3, lead: 3).minY)
    #expect(MenuGrid.line(count: 27, lead: 0) == nil && MenuGrid.line(count: 27, lead: 27) == nil)
    let plain = MenuGrid.height(count: 27, lead: 0)
    #expect(MenuGrid.height(count: 27, lead: 27) == plain)
    #expect(abs(MenuGrid.height(count: 27, lead: 3) - plain - MenuGrid.shelf) < 0.001) // 1 row and 4 where there were 5
    #expect(abs(MenuGrid.height(count: 27, lead: 1) - plain - MenuGrid.shelf - row) < 0.001) // 1 and 5: the star costs a row
}

/// The tile under the pointer grows from its own side of the grid, so it never leaves the menu.
@MainActor @Test func magnifiedTilesStayInTheMenu() {
    for count in [28, 31, 40] {
        for lead in [0, 1, 6, 7] {
            let bounds = CGRect(x: 0, y: 0, width: MenuGrid.width, height: MenuGrid.height(count: count, lead: lead))
            for index in 0..<count {
                #expect(bounds.contains(MenuGrid.grown(index, count: count, lead: lead)), "tile \(index) of \(count), \(lead) starred")
            }
        }
    }
}

/// Starred wallpapers lead the menu, by name as the rest are, and a starred name that is no longer a wallpaper counts
/// for nothing.
@MainActor @Test func favoritesLeadTheMenu() {
    let names = scenes.map(\.name), starred = ["Nebula", "Gone", "Fish Tank"]
    let order = Favorites.ordered(scenes, starred: starred).map(\.name)
    #expect(Array(order.prefix(2)) == ["Fish Tank", "Nebula"])
    #expect(Array(order.dropFirst(2)) == names.filter { !starred.contains($0) })
    #expect(Favorites.ordered(scenes, starred: []).map(\.name) == names)
    #expect(Favorites.lead(scenes, starred: starred) == 2)
}

/// Opens a menu holding the grid on screen for a moment and captures it, since a menu's glass only renders for real.
///
///     MENU_SHOT=1 swift test --filter menuShot           # → $TMPDIR/atrium-menu.png
///     MENU_SHOT="Nebula" swift test --filter menuShot    # with the pointer over that wallpaper, then clicks on it
///     MENU_SHOT="Settings" swift test --filter menuShot  # with the pointer over the Settings pill
///     MENU_FAVORITES="Nebula,Night Sky" MENU_SHOT=1 …     # with those starred, so leading the grid
///     SNAPSHOT_APPEARANCE=light MENU_SHOT=1 …            # in Light Mode
///
/// Run it with `--filter menuShot`, as above. Set for a whole `swift test`, two runs of four on 2026-11-14 ended early
/// some minutes after it, with exit code 0, no failure and no closing line, about 40 tests never run: the cause wasn't
/// found, and a run that ends without "Test run with … tests" hasn't passed.
///
/// The pointer and the clicks are events handed to the grid as the menu would hand them, at the middle of the tile
/// worked out from where the grid sits in the menu's window: the real pointer stays where it is. An Option-click
/// has to show the wallpaper and leave the menu open, a click on the pill ask for Settings, a plain click pick, and a
/// click on the star give the wallpaper on the desktop a star or take it away, the menu growing or shrinking by the
/// row that costs or saves while it is open.
@MainActor @Test(.enabled(if: ProcessInfo.processInfo.environment["MENU_SHOT"] != nil))
func menuShot() throws {
    let env = ProcessInfo.processInfo.environment
    let path = (env["SNAPSHOT_DIR"] ?? NSTemporaryDirectory()) + "/atrium-menu.png"
    try? FileManager.default.removeItem(atPath: path)
    NSApplication.shared.setActivationPolicy(.accessory)
    if let look = env["SNAPSHOT_APPEARANCE"] { NSApp.appearance = NSAppearance(named: look == "light" ? .aqua : .darkAqua) }
    // The stars are the user's own in the app, and this test's while it runs.
    let kept = UserDefaults.standard.string(forKey: Favorites.key)
    UserDefaults.standard.set(env["MENU_FAVORITES"] ?? "", forKey: Favorites.key)
    defer { UserDefaults.standard.set(kept, forKey: Favorites.key) }
    let order = Favorites.ordered(), lead = Favorites.lead()
    let current = UserDefaults.standard.string(forKey: "scene") ?? defaultScene.name
    let wanted = order.firstIndex { $0.name == env["MENU_SHOT"] }
    let pill = env["MENU_SHOT"] == "Settings"
    var hovered: String?, picked: String?, grown = false, lit = false, opened = false
    var optionPicked: String?, stayedOpen = false, ticked = false, starred = false, ringedFirst = false, fitted = false
    let menu = NSMenu(), grid = MenuGridView(settings: { opened = true }) { picked = $0 }, item = NSMenuItem()
    func mouse(_ type: NSEvent.EventType, at place: CGRect? = nil, _ modifiers: NSEvent.ModifierFlags = []) -> NSEvent? {
        // The wanted tile where it is now: the star moves the tiles.
        let tile = Favorites.ordered().firstIndex { $0.name == env["MENU_SHOT"] }.map { MenuGrid.frame($0, lead: Favorites.lead()) }
        guard let place = place ?? tile, let window = grid.window else { return nil }
        let inWindow = grid.convert(grid.bounds, to: nil)
        return .mouseEvent(with: type, location: NSPoint(x: inWindow.minX + place.midX, y: inWindow.maxY - place.midY),
                           modifierFlags: modifiers, timestamp: ProcessInfo.processInfo.systemUptime,
                           windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 0)
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
    after(0.7) { mouse(.mouseMoved, at: pill ? MenuGrid.settings : nil).map(grid.mouseMoved) }
    after(1.6) {
        hovered = grid.hover.name
        grown = grid.grown != nil
        lit = grid.hover.settings
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
        mouse(.leftMouseUp, .option).map(grid.mouseUp) // which shows it and leaves the menu open
        ringedFirst = grid.hover.picked == env["MENU_SHOT"] && picked == nil // before the wallpaper is built
        // Counted from here, as the capture takes a while: the wallpaper is shown a moment after the click.
        after(0.4) {
            (optionPicked, stayedOpen, ticked) = (picked, grid.window?.isVisible == true, grid.grown?.on == true)
            ringedFirst = ringedFirst && grid.hover.picked == nil
            picked = nil
            // The star before the clicks that close the menu: it leaves it open, and the menu has to follow the grid.
            let before = Favorites.names.contains(current), tall = grid.window?.frame.height ?? 0
            mouse(.leftMouseUp, at: MenuGrid.star(after: current)).map(grid.mouseUp)
            starred = Favorites.names.contains(current) != before
            after(0.3) {
                let more = MenuGrid.height(count: order.count, lead: Favorites.lead()) - MenuGrid.height(count: order.count, lead: lead)
                fitted = abs((grid.window?.frame.height ?? 0) - tall - more) < 1
                print("The star made the grid \(more) points taller, the menu \((grid.window?.frame.height ?? 0) - tall)")
                mouse(.leftMouseUp, at: MenuGrid.settings).map(grid.mouseUp) // which asks for Settings and closes the menu
                mouse(.leftMouseUp).map(grid.mouseUp) // which closes the menu, as a pick does
                menu.cancelTracking()
            }
        }
    }
    let screen = try #require(NSScreen.main).visibleFrame
    menu.popUp(positioning: nil, at: NSPoint(x: screen.maxX - MenuGrid.width - 40, y: screen.maxY - 8), in: nil)
    #expect(opened, "a click on the pill opens Settings")
    #expect(starred, "a click on the star stars the wallpaper on the desktop, or takes its star away")
    #expect(fitted, "the menu follows the grid as the star adds a row of favourites or takes it away")
    #expect(lit == pill, "the pill is lit under the pointer and only then")
    if let wanted {
        let moves = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #expect(hovered == order[wanted].name && picked == order[wanted].name, "over \(hovered ?? "none"), picked \(picked ?? "none")")
        #expect(grown == moves, "the tile under the pointer has its loop")
        #expect(optionPicked == order[wanted].name && stayedOpen, "an Option-click picked \(optionPicked ?? "none"), menu open: \(stayedOpen)")
        #expect(ticked == moves, "the grown tile takes the tick as it plays")
        #expect(ringedFirst, "an Option-click rings the wallpaper at once, and shows it a moment later")
    }
    print("The menu → \(path)")
}
