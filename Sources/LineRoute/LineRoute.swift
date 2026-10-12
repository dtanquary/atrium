import Foundation

/// The route a stylus takes to draw one picture in one unbroken line, and the stamping of it into the textures
/// Etching's shader reads. Routes are made by docs/etching/bake.py and shipped as `etching-<name>.route`:
/// the picture's own outlines first, then each depth of its shading, the stylus going back along lines already
/// drawn to get from place to place. This is the numeric half, built optimised even in debug (Package.swift):
/// a quarter of a million steps stamped into a display's worth of texels. docs/etching.md has the format.
public struct LineRoute: Sendable {
    /// The stylus's grid, in cells: one cell is one step.
    public let columns: Int, rows: Int
    /// The picture's rectangle on the grid, top row first, for placing it in something other than a whole screen.
    public let rect: (x: Int, y: Int, w: Int, h: Int)
    /// Steps taken after the first cell.
    public let steps: Int
    /// The whole drawing's clock, in cells of drawing: a step drawn counts its length, a step back along a line an
    /// eighth of it (`haste`).
    public let clock: Double
    /// The stylus's position after each step, in cells from the top left, eased by one step so corners round a
    /// little; and the clock when it gets there.
    public private(set) var x: [Float] = [], y: [Float] = [], t: [Double] = []

    /// The line's width in cells: on the real toy, about 1/700 of the screen's width.
    public static let line = 1.44
    /// Cells of drawing between two passes over a spot for the second to count as going over it again.
    static let apart = 8.0
    /// How many times faster the stylus goes back along a line already drawn than it draws. Nothing shows while it
    /// does, so it hurries: at twice the pace a picture stood still for up to 26 s at a time, at this for 3 to 6.
    public static let haste = 8.0

    private static let directions: [(Int, Int)] = [(1, 0), (0, 1), (-1, 0), (0, -1), (1, 1), (-1, 1), (-1, -1), (1, -1)]

    /// A route from its file's bytes; nothing if they aren't one. `walking` is false to read the heading alone
    /// (the grid, the picture's rectangle, the steps and the clock), which takes no time.
    public init?(_ data: Data, walking: Bool = true) {
        let bytes = [UInt8](data)
        guard bytes.count >= 32, bytes[0..<4].elementsEqual("LRT1".utf8) else { return nil }
        func short(_ at: Int) -> Int { Int(bytes[at]) | Int(bytes[at + 1]) << 8 }
        func long(_ at: Int) -> UInt32 { UInt32(short(at)) | UInt32(short(at + 2)) << 16 }
        (columns, rows) = (short(4), short(6))
        rect = (short(8), short(10), short(12), short(14))
        steps = Int(long(20))
        clock = Double(Float(bitPattern: long(24)))
        let packed = Int(long(28))
        guard columns > 0, rows > 0, clock > 0, bytes.count >= 32 + packed else { return nil }
        guard walking else { return }
        guard let runs = try? (Data(bytes[32..<32 + packed]) as NSData).decompressed(using: .zlib) as Data else { return nil }

        // the cells, then their positions eased by one step, then the clock along them
        var cx = [Float](), cy = [Float](), back = [Bool]()
        cx.reserveCapacity(steps + 1); cy.reserveCapacity(steps + 1); back.reserveCapacity(steps + 1)
        var (px, py) = (short(16), short(18))
        cx.append(Float(px) + 0.5); cy.append(Float(py) + 0.5); back.append(false)
        for run in runs {
            let (dx, dy) = Self.directions[Int(run >> 4 & 7)]
            for _ in 0...(run & 15) {
                px += dx; py += dy
                cx.append(Float(px) + 0.5); cy.append(Float(py) + 0.5); back.append(run & 128 != 0)
            }
        }
        guard cx.count == steps + 1 else { return nil }
        (x, y) = (cx, cy)
        for i in 1..<max(steps, 1) {
            x[i] = (cx[i - 1] + 2 * cx[i] + cx[i + 1]) / 4
            y[i] = (cy[i - 1] + 2 * cy[i] + cy[i + 1]) / 4
        }
        t = [Double](repeating: 0, count: steps + 1)
        for i in 1..<steps + 1 {
            let length = Double(((x[i] - x[i - 1]) * (x[i] - x[i - 1]) + (y[i] - y[i - 1]) * (y[i] - y[i - 1])).squareRoot())
            t[i] = t[i - 1] + (back[i] ? length / Self.haste : length)
        }
    }

    /// The route as two textures' bytes, `width` by `height` texels, bottom row first as SpriteKit takes them.
    public struct Stamped: Sendable {
        public let width: Int, height: Int
        /// Red, green and blue: when the texel was first drawn, as a 24-bit share of the route's clock (all ones:
        /// never). Alpha: how much of the texel the finished line covers.
        public let when: Data
        /// Red, green and alpha: when it was gone over again, as a 24-bit share of the clock like `when`'s (all
        /// ones: never). Blue: how much of the texel the line of the picture before covered, which stays as a ghost.
        public let more: Data
        /// How much of each texel the finished line covers, a byte to a texel: the next picture's ghost.
        public let cover: Data
    }

    /// The screen's powder, as a 512 by 512 tile that repeats: red is its fine grain and soft mottle together (128
    /// for none, 2,000 levels to the whole of the screen's brightness), green a slow unevenness for stretching over
    /// the whole screen (128 for none, 40 levels to one standard deviation). The same tile every time.
    public static func grain() -> Data {
        let n = 512
        var seed: UInt64 = 7
        func random() -> Float { // SplitMix64, as a number from 0 to 1
            seed &+= 0x9E37_79B9_7F4A_7C15
            var z = seed
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return Float((z ^ (z >> 31)) >> 40) / Float(1 << 24)
        }
        func bell() -> Float { (random() + random() + random() + random() - 2) * 1.7320508 } // near enough normal, variance 1
        func evened(_ field: [Float]) -> [Float] {
            let mean = field.reduce(0, +) / Float(field.count), spread = (field.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Float(field.count)).squareRoot()
            return field.map { ($0 - mean) / spread }
        }
        let fine = (0..<n * n).map { _ in bell() }
        // the mottle: noise blurred about 3.5 texels wide, by three passes of a 7-texel box each way, wrapping
        var mottle = (0..<n * n).map { _ in bell() }
        for _ in 0..<3 {
            for across in [true, false] {
                var next = mottle
                for y in 0..<n { for x in 0..<n {
                    var sum: Float = 0
                    for k in -3...3 { sum += across ? mottle[y * n + (x + k + n) % n] : mottle[((y + k + n) % n) * n + x] }
                    next[y * n + x] = sum / 7
                } }
                mottle = next
            }
        }
        mottle = evened(mottle)
        // the slow unevenness: an 8 by 8 lattice of random levels, eased between
        let lattice = (0..<64).map { _ in bell() }
        let slow = evened((0..<n * n).map { i -> Float in
            let x = Float(i % n) / Float(n) * 8, y = Float(i / n) / Float(n) * 8, (ix, iy) = (Int(x), Int(y))
            let fx = x - Float(ix), fy = y - Float(iy), ux = fx * fx * (3 - 2 * fx), uy = fy * fy * (3 - 2 * fy)
            func at(_ a: Int, _ b: Int) -> Float { lattice[(b % 8) * 8 + a % 8] }
            return (at(ix, iy) * (1 - ux) + at(ix + 1, iy) * ux) * (1 - uy) + (at(ix, iy + 1) * (1 - ux) + at(ix + 1, iy + 1) * ux) * uy
        })
        var tile = Data(count: n * n * 4)
        tile.withUnsafeMutableBytes { tile in
            for i in 0..<n * n {
                tile[i * 4] = UInt8(min(max(128 + (0.010 * fine[i] + 0.012 * mottle[i]) * 2000, 0), 255))
                tile[i * 4 + 1] = UInt8(min(max(128 + slow[i] * 40, 0), 255))
                tile[i * 4 + 3] = 255
            }
        }
        return tile
    }

    /// The greatest "when" a drawn texel holds: the end of the clock.
    public static let end: Double = 16_777_214

    /// Stamps the line into textures with `scale` texels to a cell, the grid's top left corner `dx`, `dy` texels in
    /// from the textures' own. A texel takes the time of the pass that covers it most, so the fringe of a line laid
    /// beside it later doesn't show early; and the time of the next pass over it, which draws it darker. `ghost` is
    /// the cover of the picture before, from its own stamping at this size, if there was one.
    ///
    /// A step whose own line is off the textures' edge takes no time, and the clock it would have taken comes off
    /// every time after it: a picture scaled up until it is cut off there is finished before the route's clock is,
    /// and nothing in it waits for a stylus that is out of sight. Even at `haste` the frame alone held a bare
    /// screen for 15 s. A route that fits inside is stamped to its own clock.
    // ponytail: where a later line overlaps an earlier one's edge by less than a quarter of a texel's cover, that
    // sliver shows with the earlier line; store a time per pass if lines ever cross thickly enough to see it.
    public func stamp(width: Int, height: Int, scale: Double, dx: Double, dy: Double, over ghost: Data? = nil) -> Stamped {
        let count = width * height, never: UInt32 = 0xFF_FFFF
        var first = [UInt32](repeating: never, count: count), second = [UInt32](repeating: never, count: count), cover = [UInt8](repeating: 0, count: count)
        let reach = Float(Self.line / 2 * scale) + 0.5, unit = Self.end / clock, gap = UInt32(Self.apart * unit)
        first.withUnsafeMutableBufferPointer { first in second.withUnsafeMutableBufferPointer { second in cover.withUnsafeMutableBufferPointer { cover in
            var saved = 0.0
            for i in 1..<max(x.count, 1) {
                let ax = Float(Double(x[i - 1]) * scale + dx), ay = Float(Double(height) - (Double(y[i - 1]) * scale + dy))
                let bx = Float(Double(x[i]) * scale + dx), by = Float(Double(height) - (Double(y[i]) * scale + dy))
                let ex = bx - ax, ey = by - ay, length = ex * ex + ey * ey
                let x0 = max(Int((min(ax, bx) - reach).rounded(.down)), 0), x1 = min(Int((max(ax, bx) + reach).rounded(.up)), width - 1)
                let y0 = max(Int((min(ay, by) - reach).rounded(.down)), 0), y1 = min(Int((max(ay, by) + reach).rounded(.up)), height - 1)
                // out of sight by its own line, whatever of its width reaches in: a row of hatching just off the
                // edge would otherwise be waited for and show a sliver
                let unseen = max(ax, bx) < 0 || min(ax, bx) > Float(width) || max(ay, by) < 0 || min(ay, by) > Float(height)
                let from = t[i - 1] - saved, took = unseen ? 0 : t[i] - t[i - 1]
                saved += t[i] - t[i - 1] - took
                guard x0 <= x1, y0 <= y1 else { continue }
                for py in y0...y1 {
                    for px in x0...x1 {
                        let qx = Float(px) + 0.5 - ax, qy = Float(py) + 0.5 - ay
                        let along = length > 0 ? min(max((qx * ex + qy * ey) / length, 0), 1) : 0
                        let sx = qx - along * ex, sy = qy - along * ey, far = sx * sx + sy * sy
                        guard far < reach * reach else { continue }
                        let level = UInt8(min(reach - far.squareRoot(), 1) * 255)
                        guard level > 0 else { continue }
                        let p = py * width + px, q = UInt32((from + Double(along) * took) * unit)
                        if first[p] == never || Int(level) > Int(cover[p]) + 64 {
                            first[p] = q; second[p] = never
                        } else if second[p] == never, level > 76, q > first[p] + gap {
                            second[p] = q
                        }
                        if level > cover[p] { cover[p] = level }
                    }
                }
            }
        } } }
        let before = ghost.flatMap { $0.count == count ? [UInt8]($0) : nil }
        var when = Data(count: count * 4), more = Data(count: count * 4)
        when.withUnsafeMutableBytes { when in more.withUnsafeMutableBytes { more in
            for p in 0..<count {
                let q = first[p], s = second[p]
                when[p * 4] = UInt8(q >> 16); when[p * 4 + 1] = UInt8(q >> 8 & 255); when[p * 4 + 2] = UInt8(q & 255); when[p * 4 + 3] = cover[p]
                more[p * 4] = UInt8(s >> 16); more[p * 4 + 1] = UInt8(s >> 8 & 255); more[p * 4 + 2] = before?[p] ?? 0; more[p * 4 + 3] = UInt8(s & 255)
            }
        } }
        return Stamped(width: width, height: height, when: when, more: more, cover: Data(cover))
    }
}
