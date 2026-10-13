import AppKit
import ImageIO
import SwiftUI

/// The status menu's wallpapers as a grid of their stills, five across, in place of a row of text for each: the name
/// of the one under the pointer reads out above them, a ring marks the one on the desktop, and a click shows another.
/// It is one menu item's view, so the menu's own arrow keys and type-to-select pass it by: Settings → General →
/// Wallpapers in the menu → Names puts the list of names back for them and for VoiceOver.
@MainActor enum MenuGrid {
    static let knob = Knob(key: "menu.wallpapers", label: "Wallpapers in the menu", range: 0...1, standard: 0,
                           format: .choice(["Pictures", "Names"]))
    static var pictures: Bool { knob.value < 0.5 }

    // Where everything sits, in points from the top left. The pictures are drawn by it and the tile under the pointer
    // is found by it, so the two can't disagree.
    static let width = 400.0, inset = 14.0, gap = 8.0, top = 6.0, bottom = 10.0, across = 5
    /// The line above the tiles that names a wallpaper, and the space under it.
    static let caption = 26.0, captionGap = 6.0
    /// A tile: a fifth of the width between the insets, in the shape of a still (1200 × 779).
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

    private static var stills: [URL: NSImage] = [:]

    /// A still shrunk to a tile, kept for as long as the app runs, so each 1200-pixel JPEG is decoded once.
    // ponytail: the first opening of the menu decodes them all; warm them at launch if that ever shows as a pause
    static func still(_ url: URL) -> NSImage {
        if let kept = stills[url] { return kept }
        let options = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                       kCGImageSourceThumbnailMaxPixelSize: Int(tile.width * 3)] as CFDictionary
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

/// The grid's drawing: the caption, then a tile for each wallpaper where `MenuGrid.frame` puts it.
struct MenuGridPictures: View {
    @ObservedObject var hover: MenuGridHover
    /// Shows a wallpaper, for VoiceOver's press: the mouse goes through `MenuGridView`.
    let pick: (String) -> Void
    @AppStorage("scene") private var current = defaultScene.name
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let named = hover.name ?? current
        ZStack(alignment: .topLeading) {
            HStack {
                Text(named).font(.system(size: 13, weight: .semibold))
                Spacer()
                if named == current {
                    Label("On Desktop", systemImage: "checkmark").font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 8).frame(height: 20).glassEffect(.regular, in: .capsule)
                }
            }
            .frame(width: MenuGrid.width - 2 * MenuGrid.inset, height: MenuGrid.caption)
            .offset(x: MenuGrid.inset, y: MenuGrid.top)
            .accessibilityHidden(true) // each tile says its own name
            ForEach(Array(scenes.enumerated()), id: \.element.name) { index, wallpaper in
                tile(wallpaper, at: MenuGrid.frame(index))
            }
        }
        .frame(width: MenuGrid.width, height: MenuGrid.height(count: scenes.count), alignment: .topLeading)
    }

    private func tile(_ wallpaper: Wallpaper, at frame: CGRect) -> some View {
        let on = wallpaper.name == current, over = wallpaper.name == hover.name
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        return Image(nsImage: MenuGrid.still(wallpaper.preview(light: scheme == .light)))
            .resizable().scaledToFill()
            .frame(width: frame.width, height: frame.height)
            .clipShape(shape)
            .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.32), .white.opacity(0.12)],
                                                       startPoint: .top, endPoint: .bottom)))
            .overlay(alignment: .bottomTrailing) {
                if on {
                    Image(systemName: "checkmark").font(.system(size: 8, weight: .heavy)).foregroundStyle(.white)
                        .frame(width: 15, height: 15).background(Color.accentColor, in: .circle)
                        .padding(1.5).background(.white.opacity(0.92), in: .circle).padding(2.5)
                }
            }
            // The ring round the wallpaper on the desktop, 2 points clear of its tile.
            .overlay(RoundedRectangle(cornerRadius: 13.5, style: .continuous).strokeBorder(Color.accentColor, lineWidth: 2.5)
                .padding(-4.5).opacity(on ? 1 : 0))
            .shadow(color: .black.opacity(over ? 0.5 : 0.28), radius: over ? 11 : 1, y: over ? 10 : 1)
            .scaleEffect(over ? 1.08 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.62), value: over)
            .offset(x: frame.minX, y: frame.minY)
            .zIndex(over ? 1 : 0)
            .accessibilityElement()
            .accessibilityLabel(wallpaper.name)
            .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { pick(wallpaper.name) }
    }
}

/// The grid as a menu item's view. A menu sends an item's view the mouse but draws no highlight for it and doesn't
/// close on a click in it, so this follows the pointer itself, with a tracking area that works while Atrium isn't the
/// app in front, and picks on mouse-up as the menu's own rows do.
final class MenuGridView: NSView {
    let hover = MenuGridHover()
    private let pick: (String) -> Void

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

    override func viewDidMoveToWindow() { hover.name = nil } // a menu that closes under the pointer sends no exit
    override func mouseEntered(with event: NSEvent) { mouseMoved(with: event) }
    override func mouseExited(with event: NSEvent) { hover.name = nil }

    override func mouseMoved(with event: NSEvent) {
        hover.name = name(at: event)
    }

    override func mouseUp(with event: NSEvent) {
        if let name = name(at: event) { choose(name) }
    }

    private func name(at event: NSEvent) -> String? {
        MenuGrid.index(at: convert(event.locationInWindow, from: nil), count: scenes.count).map { scenes[$0].name }
    }

    /// Closes the menu and shows the wallpaper, as picking a row of a menu does.
    private func choose(_ name: String) {
        enclosingMenuItem?.menu?.cancelTracking()
        pick(name)
    }
}
