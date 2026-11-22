import Foundation
import Testing
@testable import Atrium

// Checks that cover every wallpaper, for the ones with no better home: `./test.sh shared` runs these and every other
// test named `every…` (the render of every scene in RenderTests.swift, the menu's stills and tiles in
// MenuGridTests.swift, the battery rates and the trimmed wallpapers in theirs). Run it after adding, renaming or
// cutting a wallpaper, or touching Scenes.swift, Settings.swift or the menu's pictures (CLAUDE.md, Testing). A check
// over `allScenes` kept in one wallpaper's file is run by nobody working on another: Seismograph (since cut) broke the
// list below from Meander's file on 2026-11-21.

/// Meander changes mode by itself, so the app must not build it afresh when the appearance changes: its entry says
/// so. So does Etching's, whose screen eases to the other mode under the picture, Jellyfish's, whose tank's light
/// eases while its jellies carry on, Kelp Forest's, whose water eases to dusk while the forest sways on, Canopy's,
/// which bakes the day or the dusk and fades it in over the same stand, if its Time of day goes by the mode at all (a
/// rebuild would grow another stand), and Saturn's Rings', whose camera flies through the ring plane to the other
/// face; no other wallpaper's does (each of those is built to the mode it starts in).
@MainActor @Test func everyWallpaperThatFollowsTheAppearanceIsListed() {
    #expect(allScenes.filter(\.followsAppearance).map(\.name) == ["Canopy", "Etching", "Jellyfish", "Kelp Forest", "Meander", "Saturn's Rings"])
}

/// Swatches under a menu (`Wallpaper.looks`) hang together, for every wallpaper that has them: each set names a
/// menu among its wallpaper's knobs and a pick that menu has, no two sets share a pick or a key (nor a knob's), and
/// every swatch has colours for both modes. Only Meander has them so far: every other wallpaper's page is as it was.
@MainActor @Test func everySwatchUnderAMenuHangsTogether() {
    for wallpaper in allScenes where !wallpaper.looks.isEmpty {
        for look in wallpaper.looks {
            let menu = wallpaper.knobs.first { $0.key == look.shownWhen }, pick = look.shownAt ?? -1
            if case .choice(let names)? = menu?.format {
                #expect(names.indices.contains(Int(pick)) && pick == pick.rounded(), "\(look.key) hangs on pick \(pick) of \(names)")
            } else {
                Issue.record("\(look.key) hangs on \(look.shownWhen ?? "nothing"), which is no menu of \(wallpaper.name)'s")
            }
            #expect(!look.options.isEmpty && look.options.allSatisfy { !$0.dark.isEmpty && !$0.light.isEmpty } && Set(look.options.map(\.name)).count == look.options.count)
            #expect(look.standard.isEmpty || look.options.contains { $0.name == look.standard })
        }
        let keys = wallpaper.looks.map(\.key) + wallpaper.knobs.map(\.key) + [wallpaper.palettes?.key].compactMap { $0 }
        #expect(Set(keys).count == keys.count, "\(wallpaper.name) stores two settings under one key")
        #expect(Set(wallpaper.looks.map { "\($0.shownWhen ?? "") \($0.shownAt ?? -1)" }).count == wallpaper.looks.count, "\(wallpaper.name) has two sets of swatches for one pick")
    }
    #expect(allScenes.filter { !$0.looks.isEmpty }.map(\.name) == ["Meander", "Space Tour"]) // a new one: look at its Settings page, then add it here
}
