import AppKit
import SpriteKit
import UniformTypeIdentifiers

/// Matches the lock screen, and the tint macOS gives the menu bar and windows, to the wallpaper. macOS takes both from
/// the system wallpaper, which Atrium's window only covers, so while this is on each display's system wallpaper is a
/// still of Atrium's, refreshed as it changes. The user's own comes back when it's turned off or Atrium quits, and
/// after a crash at the next launch, since it's saved by display.
///
/// macOS sets a wallpaper for the Space in front and no other, so each Space is given the latest still as it comes to
/// the front (`spaceChanged`): the Space in front is the one the lock screen shows.
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

    /// Matches or restores as the switch says; call it whenever the wallpaper or the displays change.
    static func update(_ windows: [NSWindow]) {
        matching = knob.value > 0.5
        if matching == true { match(windows) } else { restore() }
    }

    /// Follows the switch on any defaults change, doing nothing unless it moved.
    static func settingChanged(_ windows: [NSWindow]) {
        if matching != (knob.value > 0.5) { update(windows) }
    }

    /// Sets each display's system wallpaper to a still of the scene on it, saving the user's own first.
    static func match(_ windows: [NSWindow]) {
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
            CGImageDestinationAddImage(out, image, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
            guard CGImageDestinationFinalize(out) else { continue }
            do { try NSWorkspace.shared.setDesktopImageURL(file, for: screen, options: [.allowClipping: true]) } catch { continue }
            stills[id] = file
            // The display's earlier stills go. Listed rather than asked of macOS, which reports a new wallpaper late.
            for old in (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            where old.lastPathComponent.hasPrefix(id) && old.lastPathComponent != file.lastPathComponent {
                try? FileManager.default.removeItem(at: old)
            }
        }
        UserDefaults.standard.set(saved, forKey: savedKey)
    }

    /// Gives the Space that has just come to the front each display's latest still. Without this a Space keeps the
    /// still it had when it was last in front as one was taken, which has been deleted since, or the user's own
    /// wallpaper if it never was: and that is what the lock screen showed from there.
    static func spaceChanged() {
        guard matching == true else { return }
        for screen in NSScreen.screens {
            guard let id = uuid(screen), let still = stills[id] else { continue }
            try? NSWorkspace.shared.setDesktopImageURL(still, for: screen, options: [.allowClipping: true])
        }
    }

    /// Puts back each display's own wallpaper, if Atrium replaced it.
    // ponytail: puts back the file only, at macOS's default fit; a moving Aerial may come back as its still
    static func restore() {
        guard let saved = UserDefaults.standard.dictionary(forKey: savedKey) as? [String: String], !saved.isEmpty else { return }
        for screen in NSScreen.screens {
            guard let id = uuid(screen), let url = saved[id].flatMap(URL.init(string:)) else { continue }
            try? NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
        }
        UserDefaults.standard.removeObject(forKey: savedKey)
        try? FileManager.default.removeItem(at: folder)
    }

    /// A display's lasting identity, the same across launches and reconnections.
    private static func uuid(_ screen: NSScreen) -> String? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }
}
