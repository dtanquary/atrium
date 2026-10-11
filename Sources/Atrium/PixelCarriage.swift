import SpriteKit

/// The carriage round the train's window in Pixel Window Seat (PixelTrain.swift): its wall, and a pale frame with
/// the light along its top edge, round a dark gasket and glass with small corners. By Settings' Carriage it has a
/// red curtain gathered at the left and a sill as well; or the curtain and a table under the window, with a lamp
/// on it that comes on at dusk and leaves its ghost in the glass.
///
/// It is the mock-ups' painter (docs/pixel-window-seat/train.py, `carriage` and `reflections`) line for line and
/// in the same arithmetic: in doubles, colours from 0 to 255 cut down to whole numbers at the end, rows counted
/// from the canvas's top. So what it paints can be checked against the sheets Dave picked from, byte for byte
/// (`trainWritesItsCarriage`, in TrainTests.swift).
///
/// Nothing here writes a pixel without keeping to the picture it writes into: the cabin through `box` and `fill`
/// or a loop clamped as theirs are, the ghost through `mark`. A pane can overhang a very small canvas, and a write
/// off the end stops the app.
struct PixelCarriage {
    /// Settings' Carriage, one of the train's own rows: what there is round the window. A train starts with the
    /// table and its lamp, which is what makes it a train and not the airliner's window on other country. With no
    /// window there is no carriage to choose.
    static let choice = Knob(key: "seat.carriage", label: "Carriage", range: 0...2, standard: 2, section: "View",
                             format: .choice(["A plain window", "A sill and a curtain", "A table and its lamp"]),
                             shownWhen: "seat.orbit", shownAt: 2, hiddenWhen: "seat.window", hiddenAt: 3)

    /// The canvas, in art pixels; the window's pane on it, its rows counted from the canvas's top; and Settings'
    /// Carriage: 0 a plain window, 1 a sill and a curtain, 2 a table and its lamp.
    let w: Int, h: Int, pane: (x: Int, y: Int, w: Int, h: Int), kind: Int
    /// The pixels of the scene's picture of the pane (whose rows run from the bottom) that the lamp leaves a ghost
    /// on, each with what lies on it: 1 the shade's ghost, 2 the stem's, and 4 the breath of the table's light.
    private var ghost: [(at: Int, part: UInt8)] = []

    /// The carriage on a canvas `w` by `h`, round the scene's pane, whose rows are counted from the bottom.
    init(w: Int, h: Int, glass: (x: Int, y: Int, w: Int, h: Int), kind: Int) {
        (self.w, self.h, pane, self.kind) = (w, h, (glass.x, h - glass.y - glass.h, glass.w, glass.h), kind)
        if kind == 2 { ghost = lampGhost() }
    }

    /// How big the pane is beside the mock-ups' own, 340 by 221, the Large window on a laptop: what hangs and
    /// stands at the window is drawn that much smaller, so it takes the same share of a smaller pane. (The frame
    /// and the gasket are the same few pixels at any size, as the airliner's reveal is.)
    private var scale: Double { min(Double(pane.w) / 340, Double(pane.h) / 221) }

    /// A measure of the mock-ups', in pixels, at this pane's scale.
    private func px(_ measure: Double) -> Int { Int((measure * scale).rounded(.toNearestOrEven)) }

    /// The canvas's row the table's far edge lies on, against the wall under the glass: the table hides the last
    /// 46 of the mock-ups' 221 rows of pane, most of the ground nearer than the lane. (By the pane's height alone,
    /// as the horizon is.)
    private var far: Int { pane.y + pane.h - Int((46 * Double(pane.h) / 221).rounded()) }

    /// The lamp on the table, at the right by the glass: its stem's column and the row its foot stands on.
    private var lamp: (x: Int, foot: Int) { (pane.x + pane.w - px(58), far + px(14)) }

    /// The rows of a lamp's shade over a foot on row `foot`, from its top: each with how far it reaches either
    /// side of the stem, and how far down the shade it is, 0 to 1.
    private func shade(_ foot: Int) -> [(y: Int, half: Int, down: Double)] {
        let rows = max(px(15), 2)
        return (0..<rows).map { (foot - px(36) + $0, px(7) + $0 * px(6) / (rows - 1), Double($0) / Double(rows - 1)) }
    }

    /// The cabin's light once night has fallen `night` of the way, 0 to 1. `dim` is how bright its colours are:
    /// their own by day and 22% of them at night, as a camera set for the view outside sees it. `lamp` is how far
    /// the table's lamp has come on, 0 to 1: from sunset until the Sun is 4° down, or by day under weather that has
    /// put the day out by `gloom` (`TrainWeather`: barely under a deck, a third in fog or snow, all but full in
    /// rain, full in a thunderstorm). `ghost` is how much of the lamp's ghost shows in the glass, which grows as the
    /// lamp does and as the dark outside deepens, to a half at night; a dark day is still too bright for one.
    static func light(_ night: Double, gloom: Double = 0) -> (dim: Double, lamp: Double, ghost: Double) {
        let on = min(max((max(night, gloom) - 0.35) / 0.4, 0), 1), lamp = on * on * (3 - 2 * on)
        return (0.22 + 0.78 * (1 - night), lamp, 0.5 * lamp * night * night)
    }

    /// The cabin with its colours dimmed to `dim` and its lamp `lamp` of the way on, as bytes of red, green, blue
    /// and alpha, rows from the top. Alpha 0 is glass.
    func picture(dim: Double, lamp glow: Double) -> [UInt8] {
        typealias Tone = SIMD3<Double>
        func c(_ r: Double, _ g: Double, _ b: Double) -> Tone { Tone(r, g, b) * dim }
        var out = [Tone](repeating: c(52, 56, 72), count: w * h), glass = [Bool](repeating: false, count: w * h)
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
        func fill(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ tone: Tone) { box(x0, y0, x1, y1, 0) { (out[$0], glass[$0]) = (tone, false) } }
        let (x0, y0, x1, y1) = (pane.x, pane.y, pane.x + pane.w, pane.y + pane.h)
        // The frame, with the light along its top two rows.
        box(x0 - 5, y0 - 5, x1 + 5, y1 + 5, 11) { out[$0] = $0 / w < y0 - 3 ? c(150, 154, 168) : c(122, 126, 142) }
        box(x0 - 1, y0 - 1, x1 + 1, y1 + 1, 7) { out[$0] = c(20, 22, 30) } // the gasket
        box(x0, y0, x1, y1, 6) { glass[$0] = true }

        if kind > 0 {
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
            fill(x0, knot - 1, x0 + px(16), knot + 2, c(214, 178, 96))
        }
        if kind == 1 {
            // The sill across the foot of the pane, lit along its top, and a little way over the frame each side.
            let sill = y1 - px(9)
            fill(x0 - 3, sill, x1 + 3, sill + 2, c(170, 172, 182))
            fill(x0 - 3, sill + 2, x1 + 3, y1 + 2, c(104, 108, 124))
        }
        if kind == 2 {
            // The table, from its far edge under the glass down to the canvas's foot and right across it: boards
            // with a dark seam between them and a few pale streaks of grain, under a narrow sill.
            let far = far, (x, foot) = lamp, wood = c(118, 76, 54), board = max(px(11), 2), streak = max(px(23), 1)
            fill(x0 - 3, far - 5, x1 + 3, far - 3, c(170, 172, 182))
            fill(x0 - 3, far - 3, x1 + 3, far, c(96, 100, 116))
            box(0, far, w, h, 0) {
                let y = $0 / w, n = (y - far) / board
                let tone = (y - far) % board == board - 1 ? c(92, 58, 44)
                    : unit(hash(($0 % w + n * 37) / streak, y, 31)) < 0.05 ? c(140, 94, 64) * 0.9 : n % 2 == 0 ? wood : wood * 0.93
                (out[$0], glass[$0]) = (tone, false)
            }
            fill(0, far, w, far + 1, c(172, 124, 86)) // the light along its far edge
            // The lamp: a brass foot and stem under a shade, which is cream with its left side in shadow by day
            // and glows after dark, brightest at its rim.
            let brass = c(176, 140, 70) * (1 - 0.5 * glow) + Tone(176, 140, 70) * (0.5 * glow)
            fill(x - px(6), foot - 2, x + px(6) + 1, foot + 1, brass)
            fill(x - 1, foot - px(20), x + 1, foot - 2, brass)
            for row in shade(foot) {
                let lit = Tone(255, 222, 160) * (0.86 + 0.14 * row.down)
                box(x - row.half, row.y, x + row.half + 1, row.y + 1, 0) {
                    let unlit = $0 % w - (x - row.half) < 3 ? c(190, 170, 146) : c(226, 208, 178)
                    (out[$0], glass[$0]) = (unlit * (1 - glow) + lit * glow, false)
                }
            }
            // Its pool of light on the table, dithered away toward its edge.
            if glow > 0 {
                let wide = Double(max(px(78), 1)), deep = Double(max(px(26), 1))
                box(x - px(80), far + 1, x + px(80), h, 0) {
                    let across = Double($0 % w - x) / wide, down = Double($0 / w - foot) / deep, r = across * across + down * down
                    guard r < 1, 1 - r > bayer[($0 / w) % 4][($0 % w) % 4] * 0.95 else { return }
                    let lit = (out[$0] * 0.6 + Tone(190, 130, 70) * (0.45 + 0.4 * (1 - r))).clamped(lowerBound: .zero, upperBound: Tone(repeating: 255))
                    out[$0] = out[$0] * (1 - glow) + lit * glow
                }
            }
        }

        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        for i in 0..<w * h where !glass[i] {
            let c = out[i].clamped(lowerBound: .zero, upperBound: Tone(repeating: 255))
            (bytes[i * 4], bytes[i * 4 + 1], bytes[i * 4 + 2], bytes[i * 4 + 3]) = (UInt8(c.x), UInt8(c.y), UInt8(c.z), 255)
        }
        return bytes
    }

    /// The cabin as the texture of the scene's sprite of it, once night has fallen `night` of the way, under weather
    /// that has put the day out by `gloom`.
    func texture(night: Double, gloom: Double = 0) -> SKTexture {
        let light = Self.light(night, gloom: gloom), bytes = picture(dim: light.dim, lamp: light.lamp)
        var canvas = Pixels(w, h)
        for i in 0..<w * h where bytes[i * 4 + 3] != 0 {
            // (Half a step up, so that `Pixels`' floats come back down to the same whole number.)
            canvas.plot(i % w, h - 1 - i / w, (RGB(Float(bytes[i * 4]), Float(bytes[i * 4 + 1]), Float(bytes[i * 4 + 2])) + 0.5) / 255)
        }
        return canvas.texture()
    }

    // MARK: - The lamp's ghost

    /// Marks out what the lit lamp leaves in the glass, by the pane's own pixels: its shade and its stem again, a
    /// little toward the middle of the glass and two rows higher, and round their foot a low wide breath of the
    /// table's light, dithered away toward its edge and ending at the sill.
    private func lampGhost() -> [(at: Int, part: UInt8)] {
        var parts = [UInt8](repeating: 0, count: pane.w * pane.h)
        func mark(_ x0: Int, _ x1: Int, _ y: Int, _ part: UInt8) {
            guard y >= 0, y < pane.h else { return }
            for x in max(x0, 0)..<max(min(x1, pane.w), max(x0, 0)) { parts[(pane.h - 1 - y) * pane.w + x] |= part }
        }
        let edge = far - pane.y, x = lamp.x - pane.x - px(34), foot = lamp.foot - pane.y - 2
        for row in shade(foot) { mark(x - row.half, x + row.half + 1, row.y, 1) }
        for y in stride(from: foot - px(20), to: foot - 2, by: 1) { mark(x - 1, x + 1, y, 2) }
        let wide = Double(max(px(70), 1)), deep = Double(max(px(18), 1))
        for y in 0..<max(min(edge - 5, pane.h), 0) {
            for i in 0..<pane.w {
                let across = Double(i - x) / wide, down = Double(y - (edge - px(8))) / deep
                if min(max(1 - (across * across + down * down), 0), 1) > bayer[y % 4][i % 4] { mark(i, i + 1, y, 4) }
            }
        }
        return parts.indices.filter { parts[$0] != 0 }.map { ($0, parts[$0]) }
    }

    /// Lays the lamp's ghost over the scene's picture of the pane, `k` of it (`light`'s `ghost`): the shade's warm
    /// white mixed in by `k` and the stem's brass by three fifths of that, then the breath of the table's light,
    /// 28% of it at its most. It goes on last, over everything seen through the glass and the water on its outside:
    /// a reflection lies in the glass, in front of them all.
    func reflect(_ out: UnsafeMutableBufferPointer<UInt32>, ghost k: Double) {
        guard k > 0, out.count == pane.w * pane.h else { return } // (every spot of the ghost is a pixel of this pane)
        typealias Tone = SIMD3<Double>
        let breath = 0.28 * min(1, k / 0.32)
        let shade = Tone(255, 214, 150) * k, stem = Tone(176, 140, 70) * k * 0.6, warm = Tone(150, 104, 60) * breath
        for spot in ghost {
            let under = out[spot.at]
            var c = Tone(Double(under & 255), Double(under >> 8 & 255), Double(under >> 16 & 255))
            if spot.part & 1 != 0 { c = c * (1 - k) + shade } else if spot.part & 2 != 0 { c = c * (1 - k * 0.6) + stem }
            if spot.part & 4 != 0 { c = c * (1 - breath) + warm }
            out[spot.at] = 0xFF00_0000 | UInt32(c.z) << 16 | UInt32(c.y) << 8 | UInt32(c.x)
        }
    }
}

/// The mock-ups' 4×4 ordered-dither thresholds, by row and column: Pixel City's `bayer`, in doubles.
private let bayer: [[Double]] = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]].map { $0.map { $0 / 16 + 1 / 32 } }

/// A well-mixed hash of a pair of whole numbers, the airliner's and the mock-ups', and one as a number from 0 up to 1.
private func hash(_ x: Int, _ z: Int, _ salt: UInt64) -> UInt64 {
    var v = UInt64(bitPattern: Int64(x)) &* 0x9E37_79B9_7F4A_7C15 ^ UInt64(bitPattern: Int64(z)) &* 0xC2B2_AE3D_27D4_EB4F ^ salt &* 0x1656_67B1_9E37_79F9
    v = (v ^ (v >> 31)) &* 0xBF58_476D_1CE4_E5B9
    v = (v ^ (v >> 29)) &* 0x94D0_49BB_1331_11EB
    return v ^ (v >> 32)
}
private func unit(_ v: UInt64) -> Double { Double(v >> 40) / 16_777_216 }
