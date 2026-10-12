import Foundation
import simd

/// A seeded generator (SplitMix64) with the draws a nest and its colony need: the same seed gives the same nest.
public struct Dice: Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed &* 0x9E37_79B9_7F4A_7C15 &+ 0x0123_4567_89AB_CDEF }
    private mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    /// From 0 up to, not including, 1.
    public mutating func unit() -> Double { Double(next() >> 11) * 0x1p-53 }
    public mutating func uniform(_ low: Double, _ high: Double) -> Double { low + (high - low) * unit() }
    public mutating func chance(_ odds: Double) -> Bool { unit() < odds }
    public mutating func below(_ count: Int) -> Int { min(Int(unit() * Double(count)), count - 1) }
    public mutating func normal() -> Double { (-2 * log(max(unit(), 1e-12))).squareRoot() * cos(2 * .pi * unit()) }
    public mutating func exponential(_ mean: Double) -> Double { -mean * log(max(1 - unit(), 1e-12)) }
    public mutating func sign() -> Double { chance(0.5) ? 1 : -1 }
}

/// An ant nest dug in a thin tank seen from the side, as ONE map of when each cell is dug, so that the nest at any
/// moment of its day is "the cells whose rank is at most u" and a frame costs the same however much is dug. The
/// rank is the share of all the digging done when that cell goes, so the dug area is u times the whole, and how u
/// runs against the clock is the scene's business. The spoil is its height above the ground at each column, at
/// each of a few hundred shares (`heap`, `surface`).
///
/// It is grown by rules, not fitted to data (docs/ant-colony.md has the measured work they are after): faces go on
/// in wandering lines, branch off sideways and stop; three times in four a face that meets another tunnel runs on
/// into it, so galleries join and the sand is left in blocks; new faces open toward the largest stretch of undug
/// sand; rooms two to four body lengths across open off a tunnel's side or end; a tunnel's width wanders, and the
/// finished map is read through a smooth push a quarter of a body length deep, so no wall is a brush stroke. A
/// young colony works one or two faces at a time and a grown one eight (`faces`), and its entrances open one after
/// another. This is the numeric half, built optimised even in debug (Package.swift).
public struct Nest: Sendable {
    /// A tunnel's centre line, a cell apart, or a room's floor line: where each point is, the share of the digging
    /// at which it opens (2 for never), the tunnel's half width there, and where it leaves its parent (-1 is the
    /// surface, and `at` is then the column of its mouth).
    public struct Branch: Sendable {
        public var points: [SIMD2<Double>] = [], opened: [Double] = [], radius: [Double] = []
        public var parent = -1, at = 0.0, room = false
    }
    /// A way from one branch to another: a side branch leaving its parent, a face that broke through, or two
    /// tunnels crossing. Usable once `opened` of the digging is done.
    public struct Link: Sendable {
        public var a: Int, at: Double, b: Int, to: Double, opened: Double
    }

    public let cols: Int, rows: Int
    /// The row of the ground line, and an ant's length in cells.
    public let ground: Int, bodyLength: Double
    /// Per cell: the share of the digging at which it is dug (2 for never).
    public private(set) var rank: [Float] = []
    /// The spoil's height above the ground line at each column, in cells, at each of `levels` + 1 shares.
    public private(set) var heap: [Float] = []
    public private(set) var entrances: [Double] = []
    public private(set) var branches: [Branch] = [], links: [Link] = []
    /// Cells dug by the end of the day, and how much of that the spoil shows (the rest is taken to be carried off).
    public private(set) var dug = 0, shown = 0.0
    public static let levels = 256
    /// The slope loose sand heaps at: 36 degrees.
    static let repose = tan(36.0 * .pi / 180)

    /// How many faces are worked at once when `share` of the digging is done: one or two for a young colony, up
    /// to eight for a grown one, whatever the number of ants Settings asks for (so the nest is the date's alone).
    public static func faces(at share: Double) -> Int { 1 + Int(7 * pow(min(max(share, 0), 1), 0.8)) }

    /// A nest for a tank `cols` by `rows` cells with ants `bodyLength` cells long: the top `air` of it air, `dig`
    /// of the sand dug by the end, the spoil never more than `cap` body lengths high.
    public init(seed: UInt64, cols: Int, rows: Int, bodyLength: Double, air: Double = 0.17, dig: Double = 0.27, cap: Double = 1.8) {
        (self.cols, self.rows, self.bodyLength) = (cols, rows, bodyLength)
        ground = max(Int(Double(rows) * air), Int(3 * bodyLength))
        var builder = Builder(seed: seed, cols: cols, rows: rows, bl: bodyLength, y0: ground, dig: dig)
        builder.grow()
        finish(&builder, cap: cap)
    }

    /// The spoil's height above the ground line at column `x`, in cells, when `share` of the digging is done.
    public func surface(_ x: Double, at share: Double) -> Double {
        let f = min(max(share, 0), 1) * Double(Self.levels), level = min(Int(f), Self.levels - 1), t = Float(f - Double(level))
        let cx = min(max(x - 0.5, 0), Double(cols) - 1.001), i = Int(cx), s = Float(cx - Double(i)) // (a column's height is its middle's)
        func height(_ column: Int) -> Float { simd_mix(heap[level * cols + column], heap[(level + 1) * cols + column], t) }
        return Double(simd_mix(height(i), height(i + 1), s))
    }

    /// Whether the cell holding (x, y) is undug medium or spoil when `share` of the digging is done. Off the sides
    /// and the bottom of the tank counts as solid; above its top as open.
    public func solid(_ x: Double, _ y: Double, at share: Double) -> Bool {
        let (xi, yi) = (Int(x.rounded(.down)), Int(y.rounded(.down)))
        if xi < 0 || xi >= cols || yi >= rows { return true }
        if yi < 0 { return false }
        return yi >= ground ? Double(rank[yi * cols + xi]) > share : Double(ground) - y <= surface(x, at: share)
    }

    /// The map as the shader reads it, top row last (SpriteKit's way up): the rank as 16 bits over 0 to 2, in red
    /// and green.
    public func bytes() -> Data {
        var out = [UInt8](repeating: 255, count: cols * rows * 4)
        for y in 0..<rows { for x in 0..<cols {
            let to = ((rows - 1 - y) * cols + x) * 4, r = UInt16(min(max(rank[y * cols + x] / 2, 0), 1) * 65535)
            (out[to], out[to + 1]) = (UInt8(r >> 8), UInt8(r & 255))
        } }
        return Data(out)
    }

    /// The spoil as the shader reads it: `cols` across and `levels` + 1 up, a row to each share from none of the
    /// digging at the bottom to all of it at the top, the height as 16 bits over 0 to 64 cells in red and green.
    /// Read smoothed between its texels it is `surface`, so an ant on the spoil stands on what is drawn.
    public func heights() -> Data {
        var out = [UInt8](repeating: 255, count: heap.count * 4)
        for i in heap.indices {
            let h = UInt16(min(max(heap[i] / 64, 0), 1) * 65535)
            (out[i * 4], out[i * 4 + 1]) = (UInt8(h >> 8), UInt8(h & 255))
        }
        return Data(out)
    }

    /// What the shader needs to know about each cell's surroundings when `share` is dug, which it cannot work out
    /// from a read or two: how near a wall is, close in (red) and further out (green), which way that wall faces
    /// the light from the upper left (blue, a half for no slope), and the same nearness wider still (alpha), for
    /// the glow above the spoil and the shadow in a tunnel. Top row last. Blurs of the dug mask, a few
    /// milliseconds for a laptop's display; the scene makes one for the share coming, off the main thread.
    public func surroundings(at share: Double) -> Data {
        let count = cols * rows, bl = bodyLength
        var mask = [Float](repeating: 0, count: count)
        for x in 0..<cols {
            let top = Double(ground) - surface(Double(x) + 0.5, at: share)
            for y in 0..<rows { mask[y * cols + x] = (y >= ground ? Double(rank[y * cols + x]) > share : Double(y) + 0.5 >= top) ? 1 : 0 }
        }
        let near = blurred(mask, cols, rows, sigma: 0.07 * bl), wide = blurred(mask, cols, rows, sigma: 0.20 * bl), far = blurred(mask, cols, rows, sigma: 0.55 * bl)
        var out = [UInt8](repeating: 0, count: count * 4)
        for y in 0..<rows { for x in 0..<cols {
            let i = y * cols + x, to = ((rows - 1 - y) * cols + x) * 4
            let gx = wide[y * cols + min(x + 1, cols - 1)] - wide[y * cols + max(x - 1, 0)], gy = wide[min(y + 1, rows - 1) * cols + x] - wide[max(y - 1, 0) * cols + x]
            let lit = (gx * 0.50 + gy * 0.86) / (simd_length(SIMD2(gx, gy)) + 1e-4)
            (out[to], out[to + 1], out[to + 2], out[to + 3]) = (UInt8(near[i] * 255), UInt8(wide[i] * 255), UInt8((lit * 0.5 + 0.5) * 255), UInt8(far[i] * 255))
        } }
        return Data(out)
    }

    /// Noise to grain a medium with, as a square tile of `side` texels that repeats: fine grain in red (a bump every
    /// three texels or so) and in green the same lit from the upper left, and the same pair a dozen texels to a bump,
    /// for clumps, in blue and alpha. Each is spread to three deviations either side of a half.
    public static func grain(side: Int = 256, seed: UInt64 = 7) -> Data {
        var dice = Dice(seed: seed)
        func smooth(_ sigma: Double) -> [Float] { // white noise blurred round the tile's edges, to unit spread
            var a = (0..<side * side).map { _ in Float(dice.normal()) }, b = a
            let half = max(Int(sigma.rounded()), 1), width = Float(2 * half + 1)
            for pass in 0..<6 { // three running means across, then three down
                let step = pass < 3 ? 1 : side, line = pass < 3 ? side : 1
                for l in 0..<side {
                    var sum: Float = 0
                    for k in -half...half { sum += a[l * line + (k + side) % side * step] }
                    for i in 0..<side {
                        b[l * line + i * step] = sum / width
                        sum += a[l * line + (i + half + 1) % side * step] - a[l * line + (i - half + side) % side * step]
                    }
                }
                swap(&a, &b)
            }
            let spread = (a.reduce(0) { $0 + $1 * $1 } / Float(a.count)).squareRoot()
            return a.map { $0 / spread }
        }
        func lit(_ field: [Float], _ k: Int) -> [Float] { // its slope toward the upper left, to unit spread
            let slope = (0..<side * side).map { i -> Float in
                let (x, y) = (i % side, i / side)
                return field[(y - k + side) % side * side + (x - k + side) % side] - field[(y + k) % side * side + (x + k) % side]
            }
            let spread = (slope.reduce(0) { $0 + $1 * $1 } / Float(slope.count)).squareRoot()
            return slope.map { $0 / spread }
        }
        let fine = smooth(1), clump = smooth(3.5), channels = [fine, lit(fine, 1), clump, lit(clump, 2)]
        var out = [UInt8](repeating: 0, count: side * side * 4)
        for i in 0..<side * side { for c in 0..<4 { out[i * 4 + c] = UInt8(min(max(127.5 + channels[c][i] * 42.5, 0), 255)) } }
        return Data(out)
    }

    // MARK: - After the growth: the lumps, the ranks, the links and the spoil

    private mutating func finish(_ b: inout Builder, cap: Double) {
        let (bl, y0, count) = (bodyLength, ground, cols * rows)
        var dice = b.dice
        // Lumpy walls: the map read through a smooth push, none of it within a body length and a half of the ground.
        let seeds = (0..<8).map { _ in UInt64(dice.unit() * 4e9) }
        let big = Float(4 * b.clock + 10)
        var pushX = [Float](repeating: 0, count: count), pushY = pushX
        let push = [(1.6, 0), (0.6, 1), (1.6, 2), (0.6, 3)].map { Lumps($0.0 * bl, seeds[$0.1], cols: cols, rows: rows) }
        var time = [Float](repeating: big, count: count)
        for y in y0..<rows { for x in 0..<cols {
            let (px, py) = (Double(x), Double(y)), keep = min(Double(y - y0) / (1.5 * bl), 1)
            let dx = keep * (0.42 * bl * push[0](px, py) + 0.10 * bl * push[1](px, py))
            let dy = keep * (0.42 * bl * push[2](px, py) + 0.10 * bl * push[3](px, py))
            (pushX[y * cols + x], pushY[y * cols + x]) = (Float(dx), Float(dy))
            let (sx, sy) = (min(max(px + dx, 0), Double(cols) - 1.001), min(max(py + dy, Double(y0)), Double(rows) - 1.001))
            let (i, j, f, g) = (Int(sx), Int(sy), Float(sx - sx.rounded(.down)), Float(sy - sy.rounded(.down)))
            func at(_ i: Int, _ j: Int) -> Float { let t = b.time[j * cols + i]; return t.isFinite ? t : big }
            time[y * cols + x] = simd_mix(simd_mix(at(i, j), at(i + 1, j), f), simd_mix(at(i, j + 1), at(i + 1, j + 1), f), g)
        } }
        // No slivers: sand left thinner than 0.4 of a body length between two tunnels goes when the later one is dug.
        let end = Float(b.clock)
        let sand = time.map { $0 > end }, kept = opened(sand, cols, rows, radius: 2.2)
        for y in (y0 + Int(1.2 * bl))..<rows { for x in 0..<cols where sand[y * cols + x] && !kept[y * cols + x] {
            var latest: Float = 0
            for j in max(y - 4, y0)...min(y + 4, rows - 1) { for i in max(x - 4, 0)...min(x + 4, cols - 1) where (i - x) * (i - x) + (j - y) * (j - y) <= 17 {
                let t = time[j * cols + i]
                if t <= end, sand[j * cols + i] == false { latest = max(latest, t) }
            } }
            if latest > 0 { time[y * cols + x] = latest }
        } }
        // Ranks: a cell's is the share of all dug cells that are dug no later than it.
        let order = time.filter { $0 <= end }.sorted()
        dug = order.count
        func share(_ clock: Float) -> Double {
            if clock > end { return 2 }
            var (low, high) = (0, order.count)
            while low < high { let mid = (low + high) / 2; if order[mid] <= clock { low = mid + 1 } else { high = mid } }
            return Double(low) / Double(max(order.count, 1))
        }
        rank = time.map { Float(share($0)) }
        // The centre lines move with their tunnels, and open when their cells do.
        branches = b.branches.map { made in
            var branch = Branch(parent: made.parent, at: made.at, room: made.room)
            branch.radius = made.radius
            branch.points = made.points.map { p in
                var q = p
                for _ in 0..<3 { // where the push brings this point from, by going back and looking again
                    let i = min(max(Int(q.y), 0), rows - 1) * cols + min(max(Int(q.x), 0), cols - 1)
                    q = p - SIMD2(Double(pushX[i]), Double(pushY[i]))
                }
                return q
            }
            // a point is open once its own cell is dug as well, and no point before one that is not
            var latest = 0.0
            branch.opened = made.clock.indices.map { k in
                let q = branch.points[k], cell = min(max(Int(q.y), 0), rows - 1) * cols + min(max(Int(q.x), 0), cols - 1)
                latest = max(latest, share(Float(made.clock[k])), q.y >= Double(y0) ? Double(rank[cell]) : 0)
                return latest
            }
            return branch
        }
        // A way is open once the straight line between its two ends is dug as well (a face that broke through
        // may leave a wall standing a while); one whose line never is dug is no way.
        func through(_ from: SIMD2<Double>, _ to: SIMD2<Double>, since opened: Double) -> Double {
            (0...8).reduce(opened) { latest, step in
                let p = simd_mix(from, to, SIMD2(repeating: Double(step) / 8))
                return max(latest, p.y >= Double(y0) ? Double(rank[min(Int(p.y), rows - 1) * cols + min(max(Int(p.x), 0), cols - 1)]) : 0)
            }
        }
        func point(_ branch: Int, _ at: Double) -> SIMD2<Double> { branches[branch].points[min(max(Int(at), 0), branches[branch].points.count - 1)] }
        links = b.links.compactMap { link in
            var opened = share(Float(link.clock))
            if link.a >= 0 { opened = through(point(link.a, link.at), point(link.b, link.to), since: opened) }
            return opened <= 1 ? Link(a: link.a, at: link.at, b: link.b, to: link.to, opened: opened) : nil
        }
        // Where two tunnels cross without having met as faces, an ant may still turn from one into the other.
        // (Only pairs whose boxes come within half a body length are looked at point by point: a large nest has
        // a hundred thousand pairs.)
        let tunnels = branches.indices.filter { !branches[$0].room }
        let boxes = branches.map { branch in branch.points.reduce((low: SIMD2(repeating: Double.infinity), high: SIMD2(repeating: -Double.infinity))) { (simd_min($0.low, $1), simd_max($0.high, $1)) } }
        var joined = Set(links.map { [$0.a, $0.b] } + links.map { [$0.b, $0.a] })
        for (n, i) in tunnels.enumerated() { for j in tunnels[(n + 1)...] where !joined.contains([i, j]) {
            guard simd_reduce_max(simd_max(boxes[i].low - boxes[j].high, boxes[j].low - boxes[i].high)) < 0.5 * bl else { continue }
            var best = (0.25 * bl * bl, -1, -1)
            for p in stride(from: 0, to: branches[i].points.count, by: 3) { for q in stride(from: 0, to: branches[j].points.count, by: 3) {
                let d = simd_distance_squared(branches[i].points[p], branches[j].points[q])
                if d < best.0 { best = (d, p, q) }
            } }
            if best.1 >= 0 {
                let opened = through(branches[i].points[best.1], branches[j].points[best.2], since: max(branches[i].opened[best.1], branches[j].opened[best.2]))
                if opened <= 1 { links.append(Link(a: i, at: Double(best.1), b: j, to: Double(best.2), opened: opened)) }
                joined.insert([i, j])
            }
        } }
        // The ground, which poured sand never leaves level; and the spoil, a thin layer with a small mound either
        // side of each mouth and a funnel kept open round it, rounded at its crests.
        entrances = b.entrances
        let xs = (0..<cols).map { Double($0) + 0.5 }
        func line(_ scale: Double, _ seed: UInt64) -> [Double] { xs.map { 2.4 * lumps($0, 0, scale, seed) } }
        // (the funnel's foot is the mouth's own edge as it will be when the nest is done, so no spoil overhangs it)
        var clear = xs.map { x in (entrances.map { abs(x - $0) }.min() ?? 1e9) - 0.5 * bl }
        for pass in [Array(0..<cols), Array((0..<cols).reversed())] {
            var away = 1e9
            for x in pass {
                away = rank[y0 * cols + x] <= 1 ? -1 : away + 1
                clear[x] = min(clear[x], away)
            }
        }
        let funnel = clear.map { max($0, 0) * Self.repose }
        let (rough, fine) = (line(6 * bl, seeds[4]), line(1.2 * bl, seeds[5]))
        let floor = xs.indices.map { min(max(0.28 * bl + 0.16 * bl * rough[$0] + 0.05 * bl * fine[$0], 0), funnel[$0]) }
        let wander = line(5 * bl, seeds[6]), ripple = line(0.5 * bl, seeds[7])
        var weight = xs.indices.map { max(0.30 + 0.10 * wander[$0], 0.12) }
        for mouth in entrances { for side in [-1.0, 1.0] {
            let (tall, off, wide) = (dice.uniform(0.45, 1.0), bl * dice.uniform(1.8, 3.4), bl * dice.uniform(1.0, 1.9))
            for i in xs.indices { weight[i] += tall * exp(-0.5 * pow((xs[i] - mouth - side * off) / wide, 2)) }
        } }
        let most = weight.max() ?? 1
        weight = weight.indices.map { weight[$0] / most * (1 + 0.05 * ripple[$0]) }
        heap = [Float](repeating: 0, count: (Self.levels + 1) * cols)
        for level in 0...Self.levels {
            let grown = cap * bl * pow(Double(level) / Double(Self.levels), 0.8)
            let raw = xs.indices.map { Float(min(min(floor[$0] + grown * weight[$0], Double(y0) - 2), funnel[$0])) }
            let round = blurred(raw, cols, 1, sigma: 0.35 * bl)
            for i in xs.indices { heap[level * cols + i] = max(min(round[i], Float(funnel[i])), 0) }
        }
        var spoil = 0.0
        for x in 0..<cols { spoil += Double(heap[Self.levels * cols + x] - heap[x]) }
        shown = spoil / Double(max(dug, 1))
    }
}

// MARK: - The growth

/// The nest while it grows: a clock that counts cells dug, the moment each cell goes, and the faces at work.
private struct Builder {
    struct Made {
        var points: [SIMD2<Double>] = [], clock: [Double] = [], radius: [Double] = []
        var parent = -1, at = 0.0, room = false
    }
    struct Tip {
        var branch = 0, room = false
        var x = 0.0, y = 0.0, heading = 0.0, radius = 0.0, swell = 0.0, sign = 1.0, pitch = 0.0, bend = 0.0
        var gone = 0.0, last = 0.0, vigour = 1.0, length = 0.0, widen = 1.0, merging = 0.0
        // a room: where it leaves its tunnel, which way it opens, its half width and half height, and how far it has swelled
        var x0 = 0.0, y0 = 0.0, side = 1.0, across = 0.0, up = 0.0, grown = 0.25
    }
    var dice: Dice
    let cols: Int, rows: Int, bl: Double, y0: Int, target: Double
    var clock = 0.0
    var time: [Float], owner: [Int32]
    var branches: [Made] = [], tips: [Tip] = [], links: [(a: Int, at: Double, b: Int, to: Double, clock: Double)] = []
    var entrances: [Double] = [], waiting: [Double] = []

    init(seed: UInt64, cols: Int, rows: Int, bl: Double, y0: Int, dig: Double) {
        dice = Dice(seed: seed)
        (self.cols, self.rows, self.bl, self.y0) = (cols, rows, bl, y0)
        target = dig * Double(cols * (rows - y0))
        time = [Float](repeating: .infinity, count: cols * rows)
        owner = [Int32](repeating: -1, count: cols * rows)
    }

    mutating func start(_ x: Double, _ y: Double, heading: Double, parent: Int, at: Double, pitch: Double? = nil, vigour: Double? = nil, length: Double? = nil) -> Int {
        branches.append(Made(points: [SIMD2(x, y)], clock: [clock], radius: [], parent: parent, at: at))
        let index = branches.count - 1
        links.append((parent, at, index, 0, clock))
        var tip = Tip(branch: index, x: x, y: y, heading: heading)
        tip.radius = max(bl * (0.60 + 0.05 * dice.normal()), 0.56 * bl)
        tip.sign = cos(heading) >= 0 ? 1 : -1
        tip.pitch = pitch ?? atan2(sin(heading), abs(cos(heading)))
        tip.vigour = vigour ?? dice.uniform(0.4, 1.0)
        tip.length = length ?? bl * (dice.exponential(9) + 5)
        branches[index].radius.append(tip.radius)
        tips.append(tip)
        return tips.count - 1
    }

    /// A room opening off a tunnel's side or end: it starts as a niche in the wall and swells outward to 2 to 4
    /// body lengths across and 1.2 to 1.7 high, with a flatter floor than roof.
    mutating func room(_ x: Double, _ y: Double, parent: Int, at: Double, side given: Double) {
        let (across, up) = (bl * dice.uniform(1.0, 2.0), bl * dice.uniform(0.72, 1.05))
        var side = given
        func fits(_ side: Double) -> Bool { 1.2 * bl < x + side * 2 * across && x + side * 2 * across < Double(cols) - 1.2 * bl }
        if !fits(side) { side = -side }
        guard fits(side), y - up >= Double(y0) + 1.3 * bl, y + up <= Double(rows) - bl else { return }
        let count = Int(1.8 * across)
        var made = Made(parent: parent, at: at, room: true)
        made.points = (0..<count).map { SIMD2(x + side * Double($0), y + 0.25 * up) }
        made.clock = [Double](repeating: 9e9, count: count)
        made.clock[0] = clock
        made.radius = [Double](repeating: up, count: count)
        branches.append(made)
        links.append((parent, at, branches.count - 1, 0, clock))
        var tip = Tip(branch: branches.count - 1, room: true)
        (tip.x0, tip.y0, tip.side, tip.across, tip.up, tip.vigour) = (x, y, side, across, up, dice.uniform(0.25, 0.5))
        tips.append(tip)
    }

    /// Digs a disc at the face now, and books the slow widening of the walls behind it for later.
    mutating func stamp(_ tip: Tip) -> Double {
        let r = tip.radius * exp(tip.swell), depth = (tip.y - Double(y0)) / Double(rows - y0)
        let wide = r + bl * 0.42 * (1.3 - 0.6 * depth) * tip.widen, reach = Int(wide + 2)
        let (xa, xb, ya, yb) = (max(Int(tip.x) - reach, 0), min(Int(tip.x) + reach, cols - 1), max(Int(tip.y) - reach, y0), min(Int(tip.y) + reach, rows - 1))
        guard xa <= xb, ya <= yb else { return r }
        var fresh = 0
        for y in ya...yb { for x in xa...xb {
            let d = simd_length(SIMD2(Double(x) + 0.5 - tip.x, Double(y) + 0.5 - tip.y))
            guard d <= wide else { continue }
            let i = y * cols + x
            if owner[i] < 0 { owner[i] = Int32(tip.branch) }
            if d <= r {
                if !(Double(time[i]) <= clock) { fresh += 1 }
                time[i] = min(time[i], Float(clock))
            } else {
                time[i] = min(time[i], Float(clock + target * (0.12 + 0.85 * pow((d - r) / max(wide - r, 1e-3), 1.3))))
            }
        } }
        clock += Double(fresh)
        return r
    }

    /// One step of a room's growth: an ellipse anchored at the tunnel's wall, its lower half flatter.
    mutating func swell(_ n: Int) -> Bool {
        tips[n].grown = min(1, tips[n].grown + 0.03)
        let tip = tips[n], a = tip.across * tip.grown, b = tip.up * (0.5 + 0.5 * tip.grown)
        let (cx, cy) = (tip.x0 + tip.side * a * 0.9, tip.y0)
        let (xa, xb, ya, yb) = (max(Int(cx - a) - 2, 0), min(Int(cx + a) + 2, cols - 1), max(Int(cy - b) - 2, y0), min(Int(cy + b) + 2, rows - 1))
        guard xa <= xb, ya <= yb else { return false }
        var fresh = 0
        let now = Float(clock)
        for y in ya...yb { for x in xa...xb {
            let (dx, dy) = (Double(x) + 0.5 - cx, Double(y) + 0.5 - cy)
            let e = pow(dx / a, 2) + pow(dy / (dy > 0 ? 0.62 * b : b), 2), i = y * cols + x
            if e <= 1.6, owner[i] < 0 { owner[i] = Int32(tip.branch) }
            if e <= 1, !(time[i] <= now) { fresh += 1; time[i] = .nan } // marked, then dated once the clock has moved on
        } }
        clock += Double(fresh)
        for y in ya...yb { for x in xa...xb where time[y * cols + x].isNaN { time[y * cols + x] = Float(clock) } }
        let open = min(branches[tip.branch].clock.count, max(Int(1.8 * a - 0.35 * bl), 0))
        for i in 0..<open where branches[tip.branch].clock[i] >= 9e9 { branches[tip.branch].clock[i] = clock }
        return tip.grown < 1
    }

    /// Whether the cell at (x, y) is another branch's tunnel, dug or booked for widening (1), or the edge of the sand (2).
    func other(_ tip: Tip, _ x: Double, _ y: Double) -> Int {
        if !(bl * 0.8 < x && x < Double(cols) - bl * 0.8 && y < Double(rows) - bl * 0.8) { return 2 }
        if y < Double(y0) + bl * 1.4 { return tip.gone > 2 * bl ? 2 : 0 }
        let o = Int(owner[Int(y) * cols + Int(x)])
        return o >= 0 && o != tip.branch && o != branches[tip.branch].parent ? 1 : 0
    }

    /// A branch keeps roughly the way it set off, pulled toward a shaft, a diagonal or a level gallery.
    mutating func pitch(for heading: Double) -> Double {
        let now = atan2(sin(heading), abs(cos(heading))) * 180 / .pi, kind = dice.unit()
        let goal = kind < 0.3 ? dice.uniform(58, 85) : kind < 0.6 ? dice.uniform(25, 55) : dice.uniform(-6, 18)
        return (0.5 * now + 0.5 * goal) * .pi / 180
    }

    /// One cell further for a tunnel's face. False once it has stopped.
    mutating func advance(_ n: Int) -> Bool {
        var tip = tips[n]
        defer { if n < tips.count, tips[n].branch == tip.branch { tips[n] = tip } }
        if tip.merging > 0 { // run straight on until it breaks through
            let (xi, yi) = (Int(tip.x + cos(tip.heading) * tip.radius * 0.6), Int(tip.y + sin(tip.heading) * tip.radius * 0.6))
            guard xi >= 0, xi < cols, yi >= y0, yi < rows else { return false }
            let o = Int(owner[yi * cols + xi])
            if Double(time[yi * cols + xi]) <= clock, o >= 0, o != tip.branch, tip.gone > 1.5 * bl {
                let there = branches[o].points, here = SIMD2(tip.x, tip.y)
                let nearest = there.indices.min { simd_distance_squared(there[$0], here) < simd_distance_squared(there[$1], here) } ?? 0
                links.append((tip.branch, Double(branches[tip.branch].points.count - 1), o, Double(nearest), clock))
                return false
            }
            if tip.merging > 4 * bl { return false } // it was a booked edge, not a tunnel yet: give up
            tip.merging += 1
        } else {
            let want = tip.sign > 0 ? tip.pitch : .pi - tip.pitch
            let off = (want - tip.heading + .pi).truncatingRemainder(dividingBy: 2 * .pi)
            tip.heading += 0.07 * ((off < 0 ? off + 2 * .pi : off) - .pi) + 0.05 * dice.normal() + 0.02 * tip.bend
            tip.bend += 0.25 * dice.normal() - 0.04 * tip.bend // slow swings, so a tunnel wanders and does not jitter
            tip.swell = min(max(tip.swell + 0.045 * dice.normal() - 0.05 * tip.swell, 0), 0.5) // wider here and there, never narrower than an ant is long
            if tip.gone > 1.5 * bl {
                let reach = tip.radius + bl
                func ahead(_ heading: Double) -> [Int] { [0, 0.4, -0.4].map { other(tip, tip.x + cos(heading + $0) * reach, tip.y + sin(heading + $0) * reach) } }
                let hits = ahead(tip.heading)
                if hits.contains(2) { // the edge of the sand: turn along it
                    guard let turn = [0.5, -0.5, 1.0, -1.0, 1.5, -1.5].first(where: { !ahead(tip.heading + $0).contains(2) }) else { return false }
                    let toward = tip.heading + turn
                    tip.heading += turn * 0.6
                    tip.sign = cos(toward) >= 0 ? 1 : -1
                    tip.pitch = atan2(sin(toward), abs(cos(toward))) * 0.6
                } else if hits.contains(1) {
                    if dice.chance(0.75) { tip.merging = 1 } else { return false }
                } else { // keep a body length and a half of sand from a neighbour alongside
                    for side in [1.3, -1.3] where other(tip, tip.x + cos(tip.heading + side) * (tip.radius + 1.5 * bl), tip.y + sin(tip.heading + side) * (tip.radius + 1.5 * bl)) == 1 {
                        tip.heading -= 0.13 * (side > 0 ? 1 : -1)
                    }
                }
            }
        }
        tip.x += cos(tip.heading); tip.y += sin(tip.heading); tip.gone += 1
        guard tip.x > 2, tip.x < Double(cols) - 2, tip.y >= Double(y0), tip.y < Double(rows) - 2 else { return false }
        let r = stamp(tip)
        branches[tip.branch].points.append(SIMD2(tip.x, tip.y))
        branches[tip.branch].clock.append(clock)
        branches[tip.branch].radius.append(r)
        let at = Double(branches[tip.branch].points.count - 1)
        if tip.gone >= tip.length {
            if dice.chance(0.45) { room(tip.x, tip.y, parent: tip.branch, at: at, side: tip.sign) }
            return false
        }
        if tip.merging > 0 || tip.gone < 2.5 * bl || tip.gone - tip.last < 2.5 * bl { return true }
        if dice.chance(1 / (bl * 11)) {
            room(tip.x, tip.y, parent: tip.branch, at: at, side: dice.sign())
            tip.last = tip.gone
        } else if dice.chance(1 / (bl * 5.5)), tips.count(where: { !$0.room }) < 9 {
            let turn = dice.uniform(35, 100) * .pi / 180 * dice.sign()
            var heading = tip.heading + turn
            if sin(heading) < -0.2 { heading = tip.heading - turn }
            if sin(heading) >= -0.2 {
                _ = start(tip.x, tip.y, heading: heading, parent: tip.branch, at: at, pitch: pitch(for: heading), vigour: tip.vigour * dice.uniform(0.6, 1.1))
            }
            tip.last = tip.gone
        }
        return true
    }

    /// How far a face could run from (x, y) along `heading` before meeting a tunnel or the edge of the sand, in cells.
    func free(_ x: Double, _ y: Double, _ heading: Double, upTo far: Double) -> Double {
        var d = 2.2 * bl
        while d < far {
            let (px, py) = (x + cos(heading) * d, y + sin(heading) * d)
            if !(bl < px && px < Double(cols) - bl && Double(y0) + 1.5 * bl < py && py < Double(rows) - bl) { return d }
            if owner[Int(py) * cols + Int(px)] >= 0 { return d }
            d += 2
        }
        return far
    }

    /// Opens a new face off the side of an existing tunnel, toward the largest stretch of undug sand.
    mutating func restart() -> Bool {
        let from = branches.indices.filter { !branches[$0].room && Double(branches[$0].points.count) > 3 * bl }
        guard !from.isEmpty else { return false }
        var best = (run: 0.0, branch: 0, index: 0, heading: 0.0)
        for _ in 0..<16 {
            let branch = from[dice.below(from.count)], points = branches[branch].points
            let low = Int(1.5 * bl), index = low + dice.below(max(points.count - 1 - low, 1))
            let heading = dice.uniform(-0.25, .pi + 0.25)
            let run = free(points[index].x, points[index].y, heading, upTo: 16 * bl) * dice.uniform(0.8, 1.2)
            if run > best.run { best = (run, branch, index, heading) }
        }
        guard best.run >= 4.5 * bl else { return false }
        let p = branches[best.branch].points[best.index]
        _ = start(p.x, p.y, heading: best.heading, parent: best.branch, at: Double(best.index), pitch: pitch(for: best.heading), vigour: dice.uniform(0.5, 1.0))
        return true
    }

    mutating func grow() {
        // Entrances well apart, the first opened at once and the others one by one as the colony grows.
        let most = min(max(Int(Double(cols) / (16 * bl)), 1), 4), count = max(most - dice.below(2), 1)
        var mouths: [Double] = [], tries = 0
        while mouths.count < count, tries < 400 {
            tries += 1
            let x = dice.uniform(0.08, 0.92) * Double(cols)
            if mouths.allSatisfy({ abs(x - $0) > 7 * bl }) { mouths.append(x) }
        }
        entrances = mouths.sorted()
        waiting = mouths // in the order drawn, which is no order across the tank
        var (rounds, fails, dugNow) = (0, 0, 0.0)
        while rounds < 600_000, fails < 400 {
            rounds += 1
            if rounds % 150 == 0 {
                let now = Float(clock)
                dugNow = Double(time.count { $0 <= now })
                if dugNow >= target { break }
            }
            let share = dugNow / target, limit = Nest.faces(at: share)
            // the next mouth opens once the nest is a twelfth dug for each one already open
            if let x = waiting.first, share >= Double(entrances.count - waiting.count) * 0.085 {
                waiting.removeFirst()
                var heading = dice.uniform(55, 88) * .pi / 180
                if dice.chance(0.5) { heading = .pi - heading }
                let n = start(x, Double(y0), heading: heading, parent: -1, at: x, vigour: dice.uniform(0.5, 1.0), length: bl * dice.uniform(9, 22))
                tips[n].widen = 1.3
            }
            let tunnels = tips.count { !$0.room }
            if tunnels < min(limit, 3) || (tunnels < min(limit, 6) && dice.chance(0.01)) { fails = restart() ? 0 : fails + 1 }
            guard !tips.isEmpty else { continue }
            // only the oldest `limit` faces are worked; the rest wait their turn
            let awake = min(tips.count, limit)
            var pick = dice.unit() * tips[..<awake].reduce(0) { $0 + $1.vigour }, n = 0
            while n < awake - 1, pick > tips[n].vigour { pick -= tips[n].vigour; n += 1 }
            if !(tips[n].room ? swell(n) : advance(n)) { tips.remove(at: n) }
        }
    }
}

// MARK: - Small numeric helpers

/// The random value, from -1 to 1, at a point of the lattice `lumps` joins.
private func corner(_ i: Double, _ j: Double, _ seed: UInt64) -> Double {
    var h = seed &+ UInt64(bitPattern: Int64(i)) &* 0x9E37_79B9_7F4A_7C15 &+ UInt64(bitPattern: Int64(j)) &* 0xC2B2_AE3D_27D4_EB4F
    h = (h ^ (h >> 30)) &* 0xBF58_476D_1CE4_E5B9
    h = (h ^ (h >> 27)) &* 0x94D0_49BB_1331_11EB
    return Double((h ^ (h >> 31)) >> 11) * 0x1p-52 - 1
}

/// Smooth noise about one bump per `scale` cells, from -1 to 1 with a spread near 0.42: a lattice of random values
/// joined smoothly.
func lumps(_ x: Double, _ y: Double, _ scale: Double, _ seed: UInt64) -> Double {
    let (px, py) = (x / scale, y / scale), (ix, iy) = (px.rounded(.down), py.rounded(.down))
    let (fx, fy) = (px - ix, py - iy), (sx, sy) = (fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy))
    let top = corner(ix, iy, seed) + (corner(ix + 1, iy, seed) - corner(ix, iy, seed)) * sx
    let bottom = corner(ix, iy + 1, seed) + (corner(ix + 1, iy + 1, seed) - corner(ix, iy + 1, seed)) * sx
    return top + (bottom - top) * sy
}

/// `lumps` for every cell of a grid: the same numbers, with the lattice's values worked out once (they were most
/// of a large nest's bake, four to a call).
struct Lumps {
    let scale: Double, across: Int, values: [Double]

    init(_ scale: Double, _ seed: UInt64, cols: Int, rows: Int) {
        (self.scale, across) = (scale, Int(Double(cols) / scale) + 2)
        values = (0..<across * (Int(Double(rows) / scale) + 2)).map { [across] in corner(Double($0 % across), Double($0 / across), seed) }
    }

    func callAsFunction(_ x: Double, _ y: Double) -> Double {
        let (px, py) = (x / scale, y / scale), (ix, iy) = (px.rounded(.down), py.rounded(.down)), at = Int(iy) * across + Int(ix)
        let (fx, fy) = (px - ix, py - iy), (sx, sy) = (fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy))
        let top = values[at] + (values[at + 1] - values[at]) * sx, bottom = values[at + across] + (values[at + across + 1] - values[at + across]) * sx
        return top + (bottom - top) * sy
    }
}

/// A Gaussian blur of a `cols` by `rows` field, as three passes of a running mean each way: its cost does not grow
/// with `sigma`. Past the edges the field goes on as its edge value.
func blurred(_ field: [Float], _ cols: Int, _ rows: Int, sigma: Double) -> [Float] {
    let half = max(Int((sigma * 0.98).rounded()), 0)
    guard half > 0 else { return field }
    var (a, b) = (field, field)
    let width = Float(2 * half + 1)
    func pass(_ from: [Float], _ to: inout [Float], along count: Int, lines: Int, step: Int, lineStep: Int) {
        for line in 0..<lines {
            let base = line * lineStep
            var sum: Float = 0
            for k in -half...half { sum += from[base + min(max(k, 0), count - 1) * step] }
            for i in 0..<count {
                to[base + i * step] = sum / width
                sum += from[base + min(i + half + 1, count - 1) * step] - from[base + max(i - half, 0) * step]
            }
        }
    }
    for _ in 0..<3 { pass(a, &b, along: cols, lines: rows, step: 1, lineStep: cols); swap(&a, &b) }
    if rows > 1 { for _ in 0..<3 { pass(a, &b, along: rows, lines: cols, step: cols, lineStep: 1); swap(&a, &b) } }
    return a
}

/// A mask with everything thinner than a disc of `radius` cells taken off it (worn away, then grown back).
func opened(_ mask: [Bool], _ cols: Int, _ rows: Int, radius: Double) -> [Bool] {
    let reach = Int(radius), disc = (-reach...reach).flatMap { j in (-reach...reach).compactMap { i in Double(i * i + j * j) <= radius * radius ? (i, j) : nil } }
    func pass(_ from: [Bool], keeping all: Bool) -> [Bool] {
        var to = from
        for y in 0..<rows { for x in 0..<cols {
            var hit = all
            for (i, j) in disc {
                let (px, py) = (min(max(x + i, 0), cols - 1), min(max(y + j, 0), rows - 1))
                if from[py * cols + px] != all { hit = !all; break }
            }
            to[y * cols + x] = hit
        } }
        return to
    }
    return pass(pass(mask, keeping: true), keeping: false)
}
