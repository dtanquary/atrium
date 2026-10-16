import AppKit
import AVFoundation
import ImageIO
import SwiftUI

/// The status menu's wallpapers as a grid of their stills, six across, each named in its corner, in place of a row of
/// text for each: the one on the desktop is named above them and ringed, the one under the pointer grows and plays its
/// loop from the picture it shows, and a click shows another.
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
        let url = resource("menu-" + wallpaper.name.lowercased().replacingOccurrences(of: " ", with: "-") + ".mp4")
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

/// The wallpaper the pointer is over, set by `MenuGridView` and drawn by `MenuGridPictures`.
@MainActor final class MenuGridHover: ObservableObject {
    @Published var name: String?
}

/// What lies over a tile's picture: its name in the bottom corner, white on a soft shade, the tick on the one on the
/// desktop, and the faint light round its edge.
struct TileFace: View {
    let name: String, on: Bool

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
            .accessibilityHidden(true) // the tile says it
    }
}

/// The grid's drawing: the caption, then a tile for each wallpaper where `MenuGrid.frame` puts it.
struct MenuGridPictures: View {
    @ObservedObject var hover: MenuGridHover
    /// Shows a wallpaper, for VoiceOver's press: the mouse goes through `MenuGridView`.
    let pick: (String) -> Void
    @AppStorage("scene") private var current = defaultScene.name
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack {
                Text(current).font(.system(size: 13, weight: .semibold))
                Spacer()
                Label("On Desktop", systemImage: "checkmark").font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8).frame(height: 20).glassEffect(.regular, in: .capsule)
            }
            .frame(width: MenuGrid.width - 2 * MenuGrid.inset, height: MenuGrid.caption)
            .offset(x: MenuGrid.inset, y: MenuGrid.top)
            .accessibilityHidden(true) // the tile says it too
            ForEach(Array(scenes.enumerated()), id: \.element.name) { index, wallpaper in
                tile(wallpaper, at: MenuGrid.frame(index), growing: MenuGrid.anchor(index, count: scenes.count))
            }
        }
        .frame(width: MenuGrid.width, height: MenuGrid.height(count: scenes.count), alignment: .topLeading)
    }

    private func tile(_ wallpaper: Wallpaper, at frame: CGRect, growing anchor: UnitPoint) -> some View {
        let on = wallpaper.name == current, over = wallpaper.name == hover.name
        let shape = RoundedRectangle(cornerRadius: MenuGrid.radius, style: .continuous)
        return Image(nsImage: MenuGrid.still(MenuGrid.picture(wallpaper, light: scheme == .light)))
            .resizable().scaledToFill()
            .frame(width: frame.width, height: frame.height)
            .clipShape(shape)
            .overlay(TileFace(name: wallpaper.name, on: on))
            // The ring round the wallpaper on the desktop, 2 points clear of its tile.
            .overlay(RoundedRectangle(cornerRadius: MenuGrid.radius + 4.5, style: .continuous).strokeBorder(Color.accentColor, lineWidth: 2.5)
                .padding(-4.5).opacity(on ? 1 : 0))
            .shadow(color: .black.opacity(over ? 0.55 : 0.28), radius: over ? 16 : 1, y: over ? 12 : 1)
            .scaleEffect(over ? MenuGrid.magnify : 1, anchor: anchor)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.62), value: over)
            .offset(x: frame.minX, y: frame.minY)
            .zIndex(over ? 1 : 0)
            .accessibilityElement()
            .accessibilityLabel(wallpaper.name)
            .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { pick(wallpaper.name) }
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

    init(loop: URL, name: String, on: Bool, at frame: CGRect) {
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: loop))
        video = AVPlayerLayer(player: player)
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
        let face = NSHostingView(rootView: TileFace(name: name, on: on)
            .frame(width: MenuGrid.tile.width, height: MenuGrid.tile.height)
            .scaleEffect(MenuGrid.magnify, anchor: .topLeading)
            .frame(width: frame.width, height: frame.height, alignment: .topLeading))
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
    private let pick: (String) -> Void
    /// The tile under the pointer at its full size, playing.
    private(set) var grown: GrownTile?

    init(pick: @escaping (String) -> Void) {
        self.pick = pick
        super.init(frame: NSRect(x: 0, y: 0, width: MenuGrid.width, height: MenuGrid.height(count: scenes.count)))
        let pictures = NSHostingView(rootView: MenuGridPictures(hover: hover) { [weak self] in self?.choose($0) })
        pictures.frame = bounds
        addSubview(pictures)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
                                       owner: self))
    }

    required init?(coder: NSCoder) { fatalError("made in code") }

    override var isFlipped: Bool { true } // `MenuGrid` measures from the top

    /// Every click is this view's, not the SwiftUI view's inside it.
    override func hitTest(_ point: NSPoint) -> NSView? { super.hitTest(point).map { _ in self } }

    override func viewDidMoveToWindow() { grow(nil) } // a menu that closes under the pointer sends no exit
    override func mouseEntered(with event: NSEvent) { mouseMoved(with: event) }
    override func mouseExited(with event: NSEvent) { grow(nil) }
    override func mouseMoved(with event: NSEvent) { grow(index(at: event)) }

    override func mouseUp(with event: NSEvent) {
        if let index = index(at: event) { choose(scenes[index].name) }
    }

    private func index(at event: NSEvent) -> Int? {
        MenuGrid.index(at: convert(event.locationInWindow, from: nil), count: scenes.count)
    }

    /// Grows the tile at `index` and plays its loop, or with nil lets the one grown go. The tile springs open on its
    /// picture; once the spring has settled and the loop's first frame, that same picture, is up, the loop fades in over
    /// it and then plays. None plays with Reduce Motion on, or for a wallpaper without a loop. On timers, as they keep
    /// going while a menu tracks the mouse.
    private func grow(_ index: Int?) {
        let name = index.map { scenes[$0].name }
        guard name != hover.name else { return }
        hover.name = name
        grown?.removeFromSuperview()
        grown = nil
        guard let index, let loop = MenuGrid.loop(scenes[index]), !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        let on = scenes[index].name == UserDefaults.standard.string(forKey: "scene") ?? defaultScene.name
        let tile = GrownTile(loop: loop, name: scenes[index].name, on: on, at: MenuGrid.grown(index, count: scenes.count))
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

    /// Closes the menu and shows the wallpaper, as picking a row of a menu does.
    private func choose(_ name: String) {
        enclosingMenuItem?.menu?.cancelTracking()
        pick(name)
    }
}
