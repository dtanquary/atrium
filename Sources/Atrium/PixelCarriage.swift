import SpriteKit

/// The carriage round the train's window in Pixel Window Seat (PixelTrain.swift): its wall, and a pale frame with
/// the light along its top edge, round a dark gasket and glass with small corners.
///
/// It is the mock-ups' painter (docs/pixel-window-seat/train.py, `carriage`) line for line and in the same
/// arithmetic: in doubles, colours from 0 to 255 cut down to whole numbers at the end, rows counted from the
/// canvas's top. So what it paints can be checked against the sheets Dave picked from, byte for byte
/// (`trainWritesItsCarriage`, in TrainTests.swift).
struct PixelCarriage {
    /// The canvas, in art pixels, and the window's pane on it, its rows counted from the canvas's top.
    let w: Int, h: Int, pane: (x: Int, y: Int, w: Int, h: Int)

    /// The carriage on a canvas `w` by `h`, round the scene's pane, whose rows are counted from the bottom.
    init(w: Int, h: Int, glass: (x: Int, y: Int, w: Int, h: Int)) {
        (self.w, self.h, pane) = (w, h, (glass.x, h - glass.y - glass.h, glass.w, glass.h))
    }

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
        let (x0, y0, x1, y1) = (pane.x, pane.y, pane.x + pane.w, pane.y + pane.h)
        box(x0 - 5, y0 - 5, x1 + 5, y1 + 5, 11) { out[$0] = Tone(122, 126, 142) * dim } // the frame
        box(x0 - 5, y0 - 5, x1 + 5, y0 - 3, 2) { out[$0] = Tone(150, 154, 168) * dim } // the light along its top edge
        box(x0 - 1, y0 - 1, x1 + 1, y1 + 1, 7) { out[$0] = Tone(20, 22, 30) * dim } // the gasket
        box(x0, y0, x1, y1, 6) { glass[$0] = true }

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
        var px = Pixels(w, h)
        for i in 0..<w * h where bytes[i * 4 + 3] != 0 {
            // (Half a step up, so that `Pixels`' floats come back down to the same whole number.)
            px.plot(i % w, h - 1 - i / w, (RGB(Float(bytes[i * 4]), Float(bytes[i * 4 + 1]), Float(bytes[i * 4 + 2])) + 0.5) / 255)
        }
        return px.texture()
    }
}
