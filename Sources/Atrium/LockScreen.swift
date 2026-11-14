import AppKit
import SpriteKit
import UniformTypeIdentifiers

/// Matches the lock screen, and the tint macOS gives the menu bar and windows, to the wallpaper. macOS takes both from
/// the system wallpaper, which Atrium's window only covers, so while this is on each display's system wallpaper is a
/// still of Atrium's, refreshed as it changes. The user's own comes back when it's turned off or Atrium quits, and
/// after a crash at the next launch, since it's saved by display: a display unplugged meanwhile gets its own back
/// when it's next connected.
///
/// macOS sets a wallpaper for the Space in front and no other, so each Space is given the latest still as it comes to
/// the front (`spaceChanged`): the Space in front is the one the lock screen shows.
///
/// macOS works out the menu bar's text colour, and that tint, from the system wallpaper only while some of it reaches
/// the screen, and once more at each unlock. Under Atrium's window none does, so both stayed as the still at the last
/// unlock left them while the wallpaper moved on: black text on a light bar over Space Tour's black sky (2026-11-13;
/// a flat white still, a lock and an unlock brought it back at will, and a flat black one cleared it). So each still
/// set is let through for a moment (`reread`).
///
/// macOS keeps a picture of every still it is given, uncompressed at the still's own size (17.8 MB at 3024 × 1964),
/// in a cache of its own that it was not seen to clear: on 2026-11-14 it still had each one asked of it, back
/// through the 42 hours its log gave names for, 344 of them. Atrium can't reach that cache, so it gives macOS as few
/// stills as do the job, and where one is for the menu bar alone, a small one (`match`, `forBar`).
// ponytail: the user's own goes back on the Space in front only. Other Spaces that were given a still keep pointing
// at it after it's deleted, until they're next in front with this on. Put theirs back as each comes to the front,
// keeping what was saved, if turning this off or quitting should leave every Space as it was.
@MainActor enum LockScreen {
    static let knob = Knob(key: "lockScreen.match", label: "Match the lock screen", range: 0...1, standard: 0, format: .toggle)
    /// Each display's own wallpaper, by display UUID, as a URL string.
    private static let savedKey = "lockScreen.saved"
    private static let folder = URL.applicationSupportDirectory.appending(path: "com.dtanquary.atrium/lock-screen")
    private static var matching: Bool?
    /// Each display's latest still, by display UUID.
    private static var stills: [String: URL] = [:]
    /// When the lock screen's stills were last taken: a wallpaper that hasn't drawn since needs no new one, and one
    /// that has gets only a small one for the menu bar until they are an hour old.
    static private(set) var taken = Date.distantPast
    /// Until when the wallpaper windows let the system wallpaper through (`reread`).
    private static var seeThroughUntil = Date.distantPast

    /// Matches or restores as the switch says; call it whenever the wallpaper or the displays change.
    static func update(_ windows: [NSWindow]) {
        matching = knob.value > 0.5
        if matching == true { match(windows) } else { restore(windows) }
    }

    /// Follows the switch on any defaults change, doing nothing unless it moved.
    static func settingChanged(_ windows: [NSWindow]) {
        if matching != (knob.value > 0.5) { update(windows) }
    }

    /// Sets each display's system wallpaper to a still of the scene on it, saving the user's own first.
    ///
    /// `forBar` is for a wallpaper that has changed between two of the lock screen's stills, which are an hour apart
    /// (every ten minutes, Space Tour's next photo, an unlock): macOS is shown a small still of it,
    /// enough to dress the menu bar by and a hundredth of the size to keep, and then given the lock screen's own
    /// still back, which it has already and keeps nothing new for. The bar stays as the small one left it.
    static func match(_ windows: [NSWindow], forBar: Bool = false) {
        if !forBar { taken = Date() }
        var saved = UserDefaults.standard.dictionary(forKey: savedKey) as? [String: String] ?? [:]
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for window in windows {
            guard let screen = window.screen, let id = uuid(screen), let view = window.contentView as? SKView,
                  let scene = view.scene, let image = view.texture(from: scene)?.cgImage() else { continue }
            // Theirs, unless it's one of ours; a wallpaper they've picked since replaces the one saved.
            if let current = NSWorkspace.shared.desktopImageURL(for: screen), !current.path.hasPrefix(folder.path) {
                saved[id] = current.absoluteString
            }
            // A name never used before: macOS keeps its picture of each URL, across launches, so a name that comes
            // round again can show a still from days ago.
            let file = folder.appending(path: "\(id)-\(UUID().uuidString).jpg")
            guard let out = CGImageDestinationCreateWithURL(file as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { continue }
            // Small only where there's a still for the lock screen to go back to.
            let small = forBar && stills[id] != nil
            var options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.9]
            if small { options[kCGImageDestinationImageMaxPixelSize] = 256 }
            CGImageDestinationAddImage(out, image, options as CFDictionary)
            guard CGImageDestinationFinalize(out) else { continue }
            do { try NSWorkspace.shared.setDesktopImageURL(file, for: screen, options: [.allowClipping: true]) } catch { continue }
            if !small { stills[id] = file }
            // The display's earlier stills go. Listed rather than asked of macOS, which reports a new wallpaper late.
            for old in (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            where old.lastPathComponent.hasPrefix(id) && ![file, stills[id]].contains(where: { $0?.lastPathComponent == old.lastPathComponent }) {
                try? FileManager.default.removeItem(at: old)
            }
        }
        UserDefaults.standard.setIfChanged(saved, forKey: savedKey)
        reread(windows)
        guard forBar else { return }
        // Once macOS has read the small one. Not while a later still is being read: that one is the lock screen's.
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.1) {
            if matching == true, Date() >= seeThroughUntil { setStills() }
        }
    }

    /// Gives each display its latest still as its system wallpaper.
    private static func setStills() {
        for screen in NSScreen.screens {
            guard let id = uuid(screen), let still = stills[id] else { continue }
            try? NSWorkspace.shared.setDesktopImageURL(still, for: screen, options: [.allowClipping: true])
        }
    }

    /// Has macOS work out the menu bar's text colour and the tint of windows again, from the system wallpaper as it
    /// has just been set: for a few seconds a thousandth of it shows through `windows`, the wallpaper's own, which is
    /// enough for macOS and nothing anyone can see. Marking a window not opaque while every pixel of it is doesn't
    /// count; one clear pixel anywhere in it does, as does this.
    // ponytail: four seconds, where macOS drew a new wallpaper and read it within one when tried. On a Mac too busy
    // for that the bar keeps the last still's colour until the next. Stay see-through until `desktopImageURL` reports
    // the new still if that ever shows.
    static func reread(_ windows: [NSWindow]) {
        seeThroughUntil = Date() + 4
        windows.forEach { $0.alphaValue = 0.999 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.05) {
            if Date() >= seeThroughUntil { windows.forEach { $0.alphaValue = 1 } }
        }
    }

    /// Gives the Space that has just come to the front each display's latest still. Without this a Space keeps the
    /// still it had when it was last in front as one was taken, which has been deleted since, or the user's own
    /// wallpaper if it never was: and that is what the lock screen showed from there.
    static func spaceChanged(_ windows: [NSWindow]) {
        guard matching == true else { return }
        setStills()
        reread(windows)
    }

    /// Puts back each connected display's own wallpaper, if Atrium replaced it. A display that isn't connected keeps
    /// its entry and its still, for `update` to put back once it is. It doesn't ask macOS whether the display still
    /// shows a still: macOS reports a new wallpaper late, so Match turned off just after it went on would have
    /// skipped putting theirs back, then deleted the still.
    // ponytail: puts back the file only, at macOS's default fit; a moving Aerial may come back as its still. And a
    // display's own, picked while it was unplugged and Atrium wasn't running, is put back over with the older one.
    static func restore(_ windows: [NSWindow] = []) {
        guard var saved = UserDefaults.standard.dictionary(forKey: savedKey) as? [String: String], !saved.isEmpty else { return }
        for screen in NSScreen.screens {
            guard let id = uuid(screen), let url = saved.removeValue(forKey: id).flatMap(URL.init(string:)) else { continue }
            try? NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
        }
        reread(windows)
        UserDefaults.standard.set(saved.isEmpty ? nil : saved, forKey: savedKey)
        guard !saved.isEmpty else {
            try? FileManager.default.removeItem(at: folder)
            return
        }
        for still in (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        where !saved.keys.contains(where: still.lastPathComponent.hasPrefix) {
            try? FileManager.default.removeItem(at: still)
        }
    }

    /// A display's lasting identity, the same across launches and reconnections.
    private static func uuid(_ screen: NSScreen) -> String? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }
}
