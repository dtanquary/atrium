import AppKit
import AVFoundation
import ImageIO
import SwiftUI

/// The status menu's wallpapers as a grid of their stills, six across, each named in its corner, in place of a row of
/// text for each: the one on the desktop is named above them and ringed, the one under the pointer grows and plays its
/// loop from the picture it shows, and a click shows another and closes the menu (with Option held it stays open, to
/// try several). The pill beside the name opens Settings on that wallpaper's page, and the star after the name makes
/// it a favourite: those lead the grid, ahead of the rest.
/// It is one menu item's view, so the menu's own arrow keys and type-to-select pass it by: Settings → General →
/// Wallpapers in the menu → Names puts the list of names back for them and for VoiceOver.
@MainActor enum MenuGrid {
    static let knob = Knob(key: "menu.wallpapers", label: "Wallpapers in the menu", range: 0...1, standard: 0,
                           format: .choice(["Pictures", "Names"]))
    static var pictures: Bool { knob.value < 0.5 }

    // Where everything sits, in points from the top left. The pictures are drawn by it and the tile under the pointer
    // is found by it, so the two can't disagree.
    static let width = 600.0, inset = 14.0, gap = 8.0, top = 6.0, bottom = 10.0, across = 6
    /// The line above the tiles that names a wallpaper, and the space under it.
    static let caption = 26.0, captionGap = 6.0
    /// A tile: a sixth of the width between the insets, in the shape of a still (1200 × 779).
    static let tile = CGSize(width: (width - 2 * inset - Double(across - 1) * gap) / Double(across),
                             height: (width - 2 * inset - Double(across - 1) * gap) / Double(across) * 779 / 1200)

    /// The pill at the caption's right that opens the wallpaper on the desktop's page of Settings.
    static let settings = CGRect(x: width - inset - 86, y: top + (caption - 20) / 2, width: 86, height: 20)

    /// The star after the name that makes the wallpaper on the desktop a favourite, or no longer one. The name is set
    /// in the menu's own type, so its width as AppKit measures it is its width as drawn.
    static func star(after name: String) -> CGRect {
        let text = (name as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold)]).width
        return CGRect(x: inset + text.rounded(.up) + 3, y: top + (caption - 22) / 2, width: 22, height: 22)
    }

    static func height(count: Int) -> Double {
        let rows = Double((count + across - 1) / across)
        return top + caption + captionGap + rows * tile.height + (rows - 1) * gap + bottom
    }

    static func frame(_ index: Int) -> CGRect {
        CGRect(x: inset + Double(index % across) * (tile.width + gap),
               y: top + caption + captionGap + Double(index / across) * (tile.height + gap),
               width: tile.width, height: tile.height)
    }

    /// The tile at a point. Each takes half the gap round it too, so the name doesn't blink off between neighbours.
    static func index(at point: CGPoint, count: Int) -> Int? {
        (0..<count).first { frame($0).insetBy(dx: -gap / 2, dy: -gap / 2).contains(point) }
    }

    /// How much the tile under the pointer grows, and a tile's corners.
    static let magnify = 2.1, radius = 9.0

    /// Where a tile grows from: its own edge or corner at the sides of the grid, so it stays inside the menu.
    static func anchor(_ index: Int, count: Int) -> UnitPoint {
        let column = index % across, row = index / across
        return UnitPoint(x: column == 0 ? 0 : column == across - 1 ? 1 : 0.5,
                         y: row == 0 ? 0 : row == (count - 1) / across ? 1 : 0.5)
    }

    /// Where a tile ends up once it has grown.
    static func grown(_ index: Int, count: Int) -> CGRect {
        let tile = frame(index), at = anchor(index, count: count), more = magnify - 1
        return CGRect(x: tile.minX - more * tile.width * at.x, y: tile.minY - more * tile.height * at.y,
                      width: tile.width * magnify, height: tile.height * magnify)
    }

    /// The faint light round a tile's edge.
    static let edge = LinearGradient(colors: [.white.opacity(0.32), .white.opacity(0.12)], startPoint: .top, endPoint: .bottom)

    /// A wallpaper's loop for its tile (`menu-<name>.mp4`, made by `site/media.sh tiles` from the site's preview loop), or
    /// nil for one without, an unfinished wallpaper.
    static func loop(_ wallpaper: Wallpaper) -> URL? {
        let url = resource("menu-" + wallpaper.slug + ".mp4")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// A tile's picture: its loop's first frame (`menu-<name>.jpg`), so nothing jumps when the loop starts, in Light Mode
    /// too, or the Settings still for a wallpaper without a loop.
    static func picture(_ wallpaper: Wallpaper, light: Bool) -> URL {
        loop(wallpaper)?.deletingPathExtension().appendingPathExtension("jpg") ?? wallpaper.preview(light: light)
    }

    private static var stills: [URL: NSImage] = [:]

    /// A still shrunk to a tile, sharp at twice the size on a Retina display, kept for as long as the app runs, so each
    /// 1200-pixel JPEG is decoded once.
    // ponytail: the first opening of the menu decodes them all; warm them at launch if that ever shows as a pause
    static func still(_ url: URL) -> NSImage {
        if let kept = stills[url] { return kept }
        let options = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                       kCGImageSourceThumbnailMaxPixelSize: Int(tile.width * 2 * magnify)] as CFDictionary
        let image = CGImageSourceCreateWithURL(url as CFURL, nil)
            .flatMap { CGImageSourceCreateThumbnailAtIndex($0, 0, options) }
            .map { NSImage(cgImage: $0, size: tile) } ?? NSImage()
        stills[url] = image
        return image
    }
}

/// The wallpapers the user has starred, which lead the menu's grid and its list of names.
@MainActor enum Favorites {
    /// Their names, comma separated, as Shuffle keeps the ones it leaves out.
    static let key = "favorites"
    static var names: [String] { (UserDefaults.standard.string(forKey: key) ?? "").split(separator: ",").map(String.init) }

    /// Stars a wallpaper, or takes its star away.
    static func toggle(_ name: String) {
        var names = names
        if let index = names.firstIndex(of: name) { names.remove(at: index) } else { names.append(name) }
        UserDefaults.standard.set(names.joined(separator: ","), forKey: key)
    }

    /// The wallpapers in the menu's order: the starred ones, then the rest, each run by name as `scenes` is. A starred
    /// name that is no longer a wallpaper counts for nothing.
    static func ordered(_ all: [Wallpaper] = scenes, starred: [String] = Favorites.names) -> [Wallpaper] {
        all.filter { starred.contains($0.name) } + all.filter { !starred.contains($0.name) }
    }
}

/// What the pointer is over, set by `MenuGridView` and drawn by `MenuGridPictures`: a wallpaper, the Settings pill or
/// the star.
@MainActor final class MenuGridHover: ObservableObject {
    @Published var name: String?
    @Published var settings = false
    @Published var star = false
    /// The wallpaper an Option-click has just picked, ringed and named at once while it is still being built.
    @Published var picked: String?
}

/// What lies over a tile's picture: its name in the bottom corner, white on a soft shade, the tick on the one on the
/// desktop, a star in the top corner of a favourite, and the faint light round its edge.
struct TileFace: View {
    let name: String, on: Bool, starred: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: MenuGrid.radius, style: .continuous)
        Text(name).font(.system(size: 8, weight: .semibold)).foregroundStyle(.white.opacity(0.95))
            .lineLimit(1).minimumScaleFactor(0.8)
            .shadow(color: .black.opacity(0.45), radius: 1.3, y: 0.5)
            .padding(.leading, 5.2).padding(.trailing, on ? 22 : 5.2) // clear of the tick
            .padding(.top, 11.2).padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [.black.opacity(0), .black.opacity(0.5)], startPoint: .top, endPoint: .bottom))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .clipShape(shape)
            .overlay(shape.strokeBorder(MenuGrid.edge))
            .overlay(alignment: .bottomTrailing) {
                if on {
                    Image(systemName: "checkmark").font(.system(size: 8, weight: .heavy)).foregroundStyle(.white)
                        .frame(width: 15, height: 15).background(Color.accentColor, in: .circle)
                        .padding(1.5).background(.white.opacity(0.92), in: .circle).padding(2.5)
                }
            }
            .overlay(alignment: .topTrailing) {
                if starred {
                    Image(systemName: "star.fill").font(.system(size: 7.5)).foregroundStyle(.yellow)
                        .shadow(color: .black.opacity(0.6), radius: 1.2, y: 0.5).padding(4.5)
                }
            }
            .accessibilityHidden(true) // the tile says it
    }
}

/// The grid's drawing: the caption, then a tile for each wallpaper where `MenuGrid.frame` puts it, the starred first.
struct MenuGridPictures: View {
    @ObservedObject var hover: MenuGridHover
    /// Shows a wallpaper, opens its page of Settings, and stars the one on the desktop, for VoiceOver's press: the
    /// mouse goes through `MenuGridView`.
    let pick: (String) -> Void, settings: () -> Void, star: () -> Void
    @AppStorage("scene") private var saved = defaultScene.name
    @AppStorage(Favorites.key) private var starred = ""
    /// The wallpaper on the desktop, or the one about to be.
    private var current: String { hover.picked ?? saved }
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let favorites = starred.split(separator: ",").map(String.init), order = Favorites.ordered(starred: favorites)
        let favorite = favorites.contains(current), at = MenuGrid.star(after: current)
        return ZStack(alignment: .topLeading) {
            Text(current).font(.system(size: 13, weight: .semibold))
                .frame(width: MenuGrid.settings.minX - MenuGrid.inset - MenuGrid.gap, height: MenuGrid.caption, alignment: .leading)
                .offset(x: MenuGrid.inset, y: MenuGrid.top)
                .accessibilityHidden(true) // the tile says it too
            Image(systemName: favorite ? "star.fill" : "star").font(.system(size: 12, weight: .medium))
                .foregroundStyle(favorite ? Color.yellow : hover.star ? Color.primary : Color.secondary)
                .frame(width: at.width, height: at.height)
                .background(.primary.opacity(hover.star ? 0.12 : 0), in: .circle)
                .offset(x: at.minX, y: at.minY)
                .accessibilityElement()
                .accessibilityLabel(favorite ? "Remove \(current) from Favorites" : "Add \(current) to Favorites")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { star() }
            // Lit like the menu's own row under the pointer, so it reads as one more thing to choose.
            Label("Settings", systemImage: "slider.horizontal.3").font(.system(size: 11, weight: .medium))
                .foregroundStyle(hover.settings ? .white : .primary)
                .frame(width: MenuGrid.settings.width, height: MenuGrid.settings.height)
                .glassEffect(hover.settings ? .regular.tint(.accentColor) : .regular, in: .capsule)
                .offset(x: MenuGrid.settings.minX, y: MenuGrid.settings.minY)
                .accessibilityElement()
                .accessibilityLabel("\(current) Settings")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { settings() }
            ForEach(Array(order.enumerated()), id: \.element.name) { index, wallpaper in
                tile(wallpaper, starred: favorites.contains(wallpaper.name), at: MenuGrid.frame(index),
                     growing: MenuGrid.anchor(index, count: order.count))
            }
        }
        .frame(width: MenuGrid.width, height: MenuGrid.height(count: scenes.count), alignment: .topLeading)
    }

    private func tile(_ wallpaper: Wallpaper, starred: Bool, at frame: CGRect, growing anchor: UnitPoint) -> some View {
        let on = wallpaper.name == current, over = wallpaper.name == hover.name
        let shape = RoundedRectangle(cornerRadius: MenuGrid.radius, style: .continuous)
        return Image(nsImage: MenuGrid.still(MenuGrid.picture(wallpaper, light: scheme == .light)))
            .resizable().scaledToFill()
            .frame(width: frame.width, height: frame.height)
            .clipShape(shape)
            .overlay(TileFace(name: wallpaper.name, on: on, starred: starred))
            // The ring round the wallpaper on the desktop, 2 points clear of its tile.
            .overlay(RoundedRectangle(cornerRadius: MenuGrid.radius + 4.5, style: .continuous).strokeBorder(Color.accentColor, lineWidth: 2.5)
                .padding(-4.5).opacity(on ? 1 : 0))
            .shadow(color: .black.opacity(over ? 0.55 : 0.28), radius: over ? 16 : 1, y: over ? 12 : 1)
            .scaleEffect(over ? MenuGrid.magnify : 1, anchor: anchor)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.62), value: over)
            .offset(x: frame.minX, y: frame.minY)
            // A wallpaper starred, or no longer, slides to its new place, and those between make room.
            .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86), value: frame.origin)
            .zIndex(over ? 1 : 0)
            .accessibilityElement()
            .accessibilityLabel(starred ? "\(wallpaper.name), favorite" : wallpaper.name)
            .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { pick(wallpaper.name) }
    }
}

/// A tile's face at the grown tile's size: drawn small and scaled up, as the tile's own is.
struct GrownFace: View {
    let name: String
    var on: Bool
    let starred: Bool

    var body: some View {
        TileFace(name: name, on: on, starred: starred)
            .frame(width: MenuGrid.tile.width, height: MenuGrid.tile.height)
            .scaleEffect(MenuGrid.magnify, anchor: .topLeading)
            .frame(width: MenuGrid.tile.width * MenuGrid.magnify, height: MenuGrid.tile.height * MenuGrid.magnify, alignment: .topLeading)
    }
}

/// What lies over the tile under the pointer once it has grown: its loop, held on the first frame, which is the picture
/// it grew from, until `play`; and its face, drawn small and scaled up as the tile's own is, so the text sits exactly
/// where it did (set larger, text runs narrower).
final class GrownTile: NSView {
    /// Plays the loop, from a file on disk and off the main thread, so the menu never waits on it.
    let player = AVQueuePlayer()
    private let looper: AVPlayerLooper
    private let video: AVPlayerLayer
    private let face: NSHostingView<GrownFace>
    /// Whether it's the wallpaper on the desktop: an Option-click makes it so while it plays.
    var on: Bool {
        get { face.rootView.on }
        set { face.rootView.on = newValue }
    }

    init(loop: URL, name: String, on: Bool, starred: Bool, at frame: CGRect) {
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: loop))
        video = AVPlayerLayer(player: player)
        face = NSHostingView(rootView: GrownFace(name: name, on: on, starred: starred))
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = MenuGrid.radius * MenuGrid.magnify
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        alphaValue = 0
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        video.videoGravity = .resizeAspectFill // as the picture fills its tile
        let view = NSView(frame: bounds)
        view.layer = video
        view.wantsLayer = true
        addSubview(view)
        face.frame = bounds
        addSubview(face)
    }

    required init?(coder: NSCoder) { fatalError("made in code") }

    /// Whether the loop's first frame is up: until then it would show its face over the tile's own.
    var ready: Bool { video.isReadyForDisplay }
}

/// The grid as a menu item's view. A menu sends an item's view the mouse but draws no highlight for it and doesn't
/// close on a click in it, so this follows the pointer itself, with a tracking area that works while Atrium isn't the
/// app in front, and picks on mouse-up as the menu's own rows do.
final class MenuGridView: NSView {
    let hover = MenuGridHover()
    private let pick: (String) -> Void, settings: () -> Void
    /// The tile under the pointer at its full size, playing.
    private(set) var grown: GrownTile?

    /// `pick` shows a wallpaper; `settings` opens Settings on the page of the one on the desktop.
    init(settings: @escaping () -> Void = {}, pick: @escaping (String) -> Void) {
        self.pick = pick
        self.settings = settings
        super.init(frame: NSRect(x: 0, y: 0, width: MenuGrid.width, height: MenuGrid.height(count: scenes.count)))
        let pictures = NSHostingView(rootView: MenuGridPictures(hover: hover, pick: { [weak self] in self?.choose($0) },
                                                                settings: { [weak self] in self?.openSettings() },
                                                                star: { [weak self] in self?.star() }))
        pictures.frame = bounds
        addSubview(pictures)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
                                       owner: self))
    }

    required init?(coder: NSCoder) { fatalError("made in code") }

    override var isFlipped: Bool { true } // `MenuGrid` measures from the top

    /// Every click is this view's, not the SwiftUI view's inside it.
    override func hitTest(_ point: NSPoint) -> NSView? { super.hitTest(point).map { _ in self } }

    override func viewDidMoveToWindow() { leave() } // a menu that closes under the pointer sends no exit
    override func mouseEntered(with event: NSEvent) { mouseMoved(with: event) }
    override func mouseExited(with event: NSEvent) { leave() }

    override func mouseMoved(with event: NSEvent) {
        grow(index(at: event))
        let point = convert(event.locationInWindow, from: nil)
        let settings = MenuGrid.settings.contains(point), star = MenuGrid.star(after: current).contains(point)
        if settings != hover.settings { hover.settings = settings }
        if star != hover.star { hover.star = star }
    }

    /// The pointer is over nothing of the grid's.
    private func leave() {
        grow(nil)
        (hover.settings, hover.star) = (false, false)
    }

    /// The wallpaper on the desktop, and the wallpapers in the order their tiles are in.
    private var current: String { UserDefaults.standard.string(forKey: "scene") ?? defaultScene.name }
    private var order: [Wallpaper] { Favorites.ordered() }

    /// A click on a tile shows its wallpaper and closes the menu; with Option held the menu stays open, to try another.
    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let index = index(at: event) {
            choose(order[index].name, closing: !event.modifierFlags.contains(.option))
        } else if MenuGrid.settings.contains(point) {
            openSettings()
        } else if MenuGrid.star(after: current).contains(point) {
            star()
        }
    }

    private func index(at event: NSEvent) -> Int? {
        MenuGrid.index(at: convert(event.locationInWindow, from: nil), count: order.count)
    }

    /// Grows the tile at `index` and plays its loop, or with nil lets the one grown go. The tile springs open on its
    /// picture; once the spring has settled and the loop's first frame, that same picture, is up, the loop fades in over
    /// it and then plays. None plays with Reduce Motion on, or for a wallpaper without a loop. On timers, as they keep
    /// going while a menu tracks the mouse.
    private func grow(_ index: Int?) {
        let order = order, name = index.map { order[$0].name }
        guard name != hover.name else { return }
        hover.name = name
        grown?.removeFromSuperview()
        grown = nil
        guard let index, let name, let loop = MenuGrid.loop(order[index]), !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        let tile = GrownTile(loop: loop, name: name, on: name == current, starred: Favorites.names.contains(name),
                             at: MenuGrid.grown(index, count: order.count))
        addSubview(tile)
        grown = tile
        reveal(tile, after: 0.32)
    }

    private func reveal(_ tile: GrownTile, after seconds: Double) {
        RunLoop.main.add(Timer(timeInterval: seconds, repeats: false) { [weak self, weak tile] _ in
            MainActor.assumeIsolated {
                guard let self, let tile, tile === self.grown else { return }
                guard tile.ready else { return self.reveal(tile, after: 0.05) }
                NSAnimationContext.runAnimationGroup { $0.duration = 0.12; tile.animator().alphaValue = 1 } completionHandler: {
                    tile.player.play()
                }
            }
        }, forMode: .common)
    }

    /// Shows the wallpaper and closes the menu, as picking a row of a menu does. Left open, the ring, the tick and the
    /// name above move to it at once and it is shown a moment later: building a wallpaper holds the main thread, half a
    /// second for the heaviest (Fish Tank) on each display, and until it's done the click would seem to have missed.
    private func choose(_ name: String, closing: Bool = true) {
        guard !closing else {
            enclosingMenuItem?.menu?.cancelTracking()
            return pick(name)
        }
        hover.picked = name
        grown?.on = hover.name == name // the grown tile draws its own face over the loop
        RunLoop.main.add(Timer(timeInterval: 0.03, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.pick(name)
                if self.hover.picked == name { self.hover.picked = nil } // the saved wallpaper says it from here
            }
        }, forMode: .common) // which a menu tracking the mouse runs
    }

    private func openSettings() {
        enclosingMenuItem?.menu?.cancelTracking()
        settings()
    }

    /// Stars the wallpaper on the desktop, or takes its star away, and the tiles slide to their new places.
    private func star() {
        Favorites.toggle(current)
        grow(nil) // whichever tile had grown may have moved
    }
}
