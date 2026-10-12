import Foundation
import simd

/// A peg board's holes: rows offset by half a pitch and √3/2 of a pitch apart, a honeycomb. One hole more than the
/// display holds on every side, so the sheet runs off its edges. Hole (col, row) is `row * cols + col` in every
/// array here, and row 0 is the bottom one, as a texture's first row is.
public struct Lattice: Sendable, Equatable {
    /// A row's height in pitches.
    public static let rise = 0.8660254037844386
    public let cols: Int, rows: Int
    /// A hole to the next in its row, in points; and where hole (0, 0) is, in points from the display's bottom left.
    public let pitch: Double, origin: SIMD2<Double>

    public init(width: Double, height: Double, pitch: Double) {
        self.pitch = pitch
        cols = Int((width / pitch).rounded(.up)) + 2
        rows = Int((height / (pitch * Self.rise)).rounded(.up)) + 2
        origin = [(width - (Double(cols) - 0.5) * pitch) / 2, (height - Double(rows - 1) * pitch * Self.rise) / 2]
    }

    public var count: Int { cols * rows }

    /// A hole's place in pitches from hole (0, 0): odd rows sit half a pitch along.
    public func place(_ col: Int, _ row: Int) -> SIMD2<Double> { [Double(col) + 0.5 * Double(row & 1), Double(row) * Self.rise] }

    /// The same in points from the display's bottom left.
    public func point(_ col: Int, _ row: Int) -> SIMD2<Double> { origin + place(col, row) * pitch }
}

/// A snow crystal grown on the lattice: for each hole, its place in the order the crystal froze (0 first, -1 where
/// it never did), and how far through the growth that was, from 0 to 1.
public struct Crystal: Sendable {
    public var order: [Int32], age: [Float]
    public var count: Int
}

/// Grows a snow crystal from the lattice's middle hole by Reiter's model (C. Reiter, "A local cellular model for
/// snow crystal growth", Chaos, Solitons & Fractals 23, 2005): every hole holds water, a hole is ice from 1 up, and
/// each step the water in holes that are not ice or beside it diffuses (`alpha`) while holes that are take `gamma`
/// from the air; `beta` is the water everywhere at the start. It stops when the crystal comes within three holes of
/// the display's edge or reaches `limit` pitches from its middle. Holes that froze on the same step come in the
/// order `rng` gives them.
// ponytail: grown where the scene is built, 5 to 20 ms for a laptop's half-size sheet, and `limit` keeps it under
// about 100 ms on any display; a crystal to fill a 6K display at the smallest pegs would want growing off the main thread
public func snowCrystal(on lattice: Lattice, alpha: Float, beta: Float, gamma: Float, limit: Double = 48,
                        using rng: inout some RandomNumberGenerator) -> Crystal {
    let (c0, r0) = (lattice.cols / 2, lattice.rows / 2), middle = lattice.place(c0, r0)
    let reach = min(Double(lattice.rows - 6) / 2 * Lattice.rise, Double(lattice.cols - 6) / 2, limit)
    // Only a window round the middle is worked: the crystal and four holes of air beyond it
    let (hw, hh) = (Int(reach) + 4, Int(reach / Lattice.rise) + 4)
    let (ca, ra) = (max(c0 - hw, 0), max(r0 - hh, 0)), (w, h) = (min(c0 + hw, lattice.cols - 1) - ca + 1, min(r0 + hh, lattice.rows - 1) - ra + 1)
    var water = [Float](repeating: beta, count: w * h), free = water, next = water
    var near = [Bool](repeating: false, count: w * h), when = [Int32](repeating: -1, count: w * h)
    water[(r0 - ra) * w + c0 - ca] = 1
    when[(r0 - ra) * w + c0 - ca] = 0
    // A hole's six neighbours: the two beside it and two in each row above and below, which sit half a pitch
    // either side of it. At the window's edge a missing neighbour is the hole itself.
    func around(_ i: Int, _ x: Int, _ y: Int, _ body: (Int) -> Void) {
        let odd = (y + ra) & 1, left = x - 1 + odd, right = x + odd, below = i - w - x, above = i + w - x
        body(x > 0 ? i - 1 : i)
        body(x < w - 1 ? i + 1 : i)
        body(y > 0 && left >= 0 ? below + left : i)
        body(y > 0 && right < w ? below + right : i)
        body(y < h - 1 && left >= 0 ? above + left : i)
        body(y < h - 1 && right < w ? above + right : i)
    }
    var last: Int32 = 0
    for step in 1...6000 {
        for y in 0..<h { for x in 0..<w {
            let i = y * w + x
            var beside = water[i] >= 1
            around(i, x, y) { if water[$0] >= 1 { beside = true } }
            near[i] = beside
            free[i] = beside ? 0 : water[i]
        } }
        var furthest = 0.0
        for y in 0..<h { for x in 0..<w {
            let i = y * w + x
            var sum: Float = 0
            around(i, x, y) { sum += free[$0] }
            next[i] = free[i] + alpha / 2 * (sum / 6 - free[i]) + (near[i] ? water[i] + gamma : 0)
            if next[i] >= 1, when[i] < 0 {
                when[i] = Int32(step)
                furthest = max(furthest, simd_distance(lattice.place(x + ca, y + ra), middle))
            }
        } }
        swap(&water, &next)
        last = Int32(step)
        if furthest > reach { break }
    }
    // Into the order they froze, and out to the whole lattice
    var frozen = when.indices.filter { when[$0] >= 0 }.map { (hole: $0, key: (when[$0], UInt32.random(in: .min ... .max, using: &rng))) }
    frozen.sort { $0.key < $1.key }
    var crystal = Crystal(order: [Int32](repeating: -1, count: lattice.count), age: [Float](repeating: 0, count: lattice.count), count: frozen.count)
    for (place, ice) in frozen.enumerated() {
        let hole = (ice.hole / w + ra) * lattice.cols + ice.hole % w + ca
        crystal.order[hole] = Int32(place)
        crystal.age[hole] = Float(when[ice.hole]) / Float(max(last, 1))
    }
    return crystal
}

/// The glow lit pegs cast on the sheet: each peg's light spread over the paper round it, summed here on the CPU as
/// pegs go in, on a grid of 4 × 4 texels to a hole that a shader reads smoothly. So the halo and the spill onto
/// neighbours cost the GPU one texture read and no blur. `bytes` is what the shader reads: red, green and blue as
/// the square root of sixteen times the light (so that 8 bits keep the faint end), alpha full.
public struct Glow: Sendable {
    /// Texels to a hole, along a row and up the rows.
    public static let fine = 4
    public let width: Int, height: Int
    public private(set) var bytes: [UInt8]
    private var light: [Float]

    /// One peg's light on the paper by distance from it, in pitches, as fitted to a dark-room photograph of a real
    /// board (docs/peg-board.md): a tight glow at the peg's foot, and a wide one in two reaches. Out to 7 pitches.
    private static let kernel: (across: Int, up: Int, weights: [Float]) = {
        let (across, up) = (7 * fine, Int((7 / Lattice.rise).rounded(.up)) * fine)
        var weights: [Float] = []
        for y in -up...up { for x in -across...across {
            let d = simd_length(SIMD2(Double(x), Double(y) * Lattice.rise)) / Double(fine)
            weights.append(Float(0.009 * exp(-max(d - 0.47, 0) / 0.16) + 0.0017 * exp(-d / 0.5) + 0.00014 * exp(-d / 2)))
        } }
        return (across, up, weights)
    }()

    public init(for lattice: Lattice) {
        (width, height) = (lattice.cols * Self.fine, lattice.rows * Self.fine)
        light = [Float](repeating: 0, count: width * height * 3)
        bytes = [UInt8](repeating: 0, count: width * height * 4)
        for i in stride(from: 3, to: bytes.count, by: 4) { bytes[i] = 255 }
    }

    /// Adds the light of a peg of `colour` (linear) in hole (col, row), and brings `bytes` up to date where it fell.
    public mutating func stamp(col: Int, row: Int, colour: SIMD3<Float>) {
        let fine = Self.fine, kernel = Self.kernel
        let (cx, cy) = (col * fine + (fine / 2) * (row & 1) + fine / 2, row * fine + fine / 2), span = 2 * kernel.across + 1
        let (x0, x1) = (max(cx - kernel.across, 0), min(cx + kernel.across, width - 1))
        let (y0, y1) = (max(cy - kernel.up, 0), min(cy + kernel.up, height - 1)), width = width
        light.withUnsafeMutableBufferPointer { light in bytes.withUnsafeMutableBufferPointer { bytes in kernel.weights.withUnsafeBufferPointer { weights in
            for y in y0...y1 {
                let from = (y - cy + kernel.up) * span - cx + kernel.across
                for x in x0...x1 {
                    let i = y * width + x, weight = weights[from + x]
                    for c in 0..<3 {
                        light[i * 3 + c] += weight * colour[c]
                        bytes[i * 4 + c] = UInt8(min((light[i * 3 + c] * 16).squareRoot(), 1) * 255)
                    }
                }
            }
        } } }
    }

    /// An empty sheet again.
    public mutating func clear() {
        for i in light.indices { light[i] = 0 }
        for i in bytes.indices where i % 4 != 3 { bytes[i] = 0 }
    }
}
