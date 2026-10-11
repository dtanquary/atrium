import SpriteKit

/// The carriage round the train's window in Pixel Window Seat (PixelTrain.swift): its wall, and a pale frame with
/// the light along its top edge, round a dark gasket and glass with small corners. By Settings' Carriage it has a
/// red curtain gathered at the left and a sill as well.
///
/// It is the mock-ups' painter (docs/pixel-window-seat/train.py, `carriage`) line for line and in the same
/// arithmetic: in doubles, colours from 0 to 255 cut down to whole numbers at the end, rows counted from the
/// canvas's top. So what it paints can be checked against the sheets Dave picked from, byte for byte
/// (`trainWritesItsCarriage`, in TrainTests.swift).
struct PixelCarriage {
    /// Settings' Carriage, one of the train's own rows: what there is round the window. With no window there is
    /// no carriage to choose.
    static let choice = Knob(key: "seat.carriage", label: "Carriage", range: 0...1, standard: 0, section: "View",
                             format: .choice(["A plain window", "A sill and a curtain"]),
                             shownWhen: "seat.orbit", shownAt: 2, hiddenWhen: "seat.window", hiddenAt: 3)

    /// The canvas, in art pixels; the window's pane on it, its rows counted from the canvas's top; and Settings'
    /// Carriage: 0 a plain window, 1 a sill and a curtain.
    let w: Int, h: Int, pane: (x: Int, y: Int, w: Int, h: Int), kind: Int

    /// The carriage on a canvas `w` by `h`, round the scene's pane, whose rows are counted from the bottom.
    init(w: Int, h: Int, glass: (x: Int, y: Int, w: Int, h: Int), kind: Int) {
        (self.w, self.h, pane, self.kind) = (w, h, (glass.x, h - glass.y - glass.h, glass.w, glass.h), kind)
    }

    /// How big the pane is beside the mock-ups' own, 340 by 221, the Large window on a laptop: what hangs and
    /// stands at the window is drawn that much smaller, so it takes the same share of a smaller pane. (The frame
    /// and the gasket are the same few pixels at any size, as the airliner's reveal is.)
    private var scale: Double { min(Double(pane.w) / 340, Double(pane.h) / 221) }

    /// A measure of the mock-ups', in pixels, at this pane's scale.
    private func px(_ measure: Double) -> Int { Int((measure * scale).rounded(.toNearestOrEven)) }

    /// How bright the cabin is once night has fallen `night` of the way, 0 to 1: its own colours by day, and 22% of
    /// them at night, as a camera set for the view outside sees it.
    static func light(_ night: Double) -> Double { 0.22 + 0.78 * (1 - night) }

    /// The cabin with its colours dimmed to `dim`, as bytes of red, green, blue and alpha, rows from the top. Alpha
    /// 0 is glass.
    func picture(dim: Double) -> [UInt8] {
        typealias Tone = SIMD3<Double>
        var out = [Tone](repeating: Tone(52, 56, 72) * dim, count: w * h), glass = [Bool](repeating: false, count: w * h)
        /// Each pixel of a box with rounded corners, cut as the mock-ups cut them: a corner's pixel is left out
        /// where its centre is more than `r` from the centre the corner turns about.
        func box(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ r: Int, _ put: (Int) -> Void) {
            for y in max(y0, 0)..<max(min(y1, h), max(y0, 0)) {
                for x in max(x0, 0)..<max(min(x1, w), max(x0, 0)) {
                    let inX = min(x - x0, x1 - 1 - x, r), inY = min(y - y0, y1 - 1 - y, r)
                    let a = Double(r - inX) - 0.5, b = Double(r - inY) - 0.5
                    if inX >= r || inY >= r || a * a + b * b <= Double(r * r) { put(y * w + x) }
                }
            }
        }
        /// A square-cornered box of one colour, over the glass too.
        func fill(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ tone: Tone) { box(x0, y0, x1, y1, 0) { (out[$0], glass[$0]) = (tone * dim, false) } }
        let (x0, y0, x1, y1) = (pane.x, pane.y, pane.x + pane.w, pane.y + pane.h)
        // The frame, with the light along its top two rows.
        box(x0 - 5, y0 - 5, x1 + 5, y1 + 5, 11) { out[$0] = ($0 / w < y0 - 3 ? Tone(150, 154, 168) : Tone(122, 126, 142)) * dim }
        box(x0 - 1, y0 - 1, x1 + 1, y1 + 1, 7) { out[$0] = Tone(20, 22, 30) * dim } // the gasket
        box(x0, y0, x1, y1, 6) { glass[$0] = true }

        if kind == 1 {
            // A red curtain down the pane's left side, in three tones of fold that waver as they fall, gathered in
            // by a tie three fifths of the way down and spreading a little below it.
            let cloth = [Tone(126, 62, 58), Tone(156, 80, 70), Tone(188, 104, 86)], tie = 0.62, scale = scale
            for y in max(y0, 0)..<max(min(y1, h), max(y0, 0)) { // kept to the canvas: a pane can overhang a very small one
                let t = Double(y - y0) / Double(pane.h), gathered = (t - tie) / 0.16
                let wide = (30 - 15 * exp(-(gathered * gathered)) + (t > tie ? 6 * (t - tie) : 0)) * scale
                for x in max(x0, 0)..<max(min(x0 + Int(wide.rounded(.toNearestOrEven)), w), max(x0, 0)) {
                    var fold = (Double(x - x0) / max(wide, 1) * 5 + 0.3 * sin(Double(y) / (9 * scale))).truncatingRemainder(dividingBy: 3)
                    if fold < 0 { fold += 3 }
                    (out[y * w + x], glass[y * w + x]) = (cloth[min(Int(fold), 2)] * dim, false)
                }
            }
            let knot = y0 + Int(Double(pane.h) * tie)
            fill(x0, knot - 1, x0 + px(16), knot + 2, Tone(214, 178, 96))
            // The sill across the foot of the pane, lit along its top, and a little way over the frame each side.
            let sill = y1 - px(9)
            fill(x0 - 3, sill, x1 + 3, sill + 2, Tone(170, 172, 182))
            fill(x0 - 3, sill + 2, x1 + 3, y1 + 2, Tone(104, 108, 124))
        }

        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        for i in 0..<w * h where !glass[i] {
            let c = out[i].clamped(lowerBound: .zero, upperBound: Tone(repeating: 255))
            (bytes[i * 4], bytes[i * 4 + 1], bytes[i * 4 + 2], bytes[i * 4 + 3]) = (UInt8(c.x), UInt8(c.y), UInt8(c.z), 255)
        }
        return bytes
    }

    /// The cabin as the texture of the scene's sprite of it, once night has fallen `night` of the way.
    func texture(night: Double) -> SKTexture {
        let bytes = picture(dim: Self.light(night))
        var canvas = Pixels(w, h)
        for i in 0..<w * h where bytes[i * 4 + 3] != 0 {
            // (Half a step up, so that `Pixels`' floats come back down to the same whole number.)
            canvas.plot(i % w, h - 1 - i / w, (RGB(Float(bytes[i * 4]), Float(bytes[i * 4 + 1]), Float(bytes[i * 4 + 2])) + 0.5) / 255)
        }
        return canvas.texture()
    }
}
