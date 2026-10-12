import Foundation
import simd

// Meander's river: a module of its own, built with -O even in a debug build, where its launch history would
// otherwise take seconds at every scene build. Foundation and simd only.

/// 0 below `edge0`, 1 above `edge1`, and a smooth S between.
@inline(__always) private func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
    let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
    return t * t * (3 - 2 * t)
}

/// A seeded generator (SplitMix64), so a seed gives the same river every time.
private struct Seeded: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Where the edge from `p` to `q` crosses the row at `y`, or not a number if it doesn't.
@inline(__always) private func crossing(_ p: SIMD2<Float>, _ q: SIMD2<Float>, _ y: Float) -> Float {
    (p.y - y) * (q.y - y) <= 0 && p.y != q.y ? p.x + (y - p.y) / (q.y - p.y) * (q.x - p.x) : .nan
}

/// A river migrating across its floodplain, and the ground's memory of where it has been. Bends grow and shift down
/// the valley; where a bend's two limbs touch the river cuts through and leaves the loop behind as a lake.
///
/// The law is Howard & Knutson's (1984): a bank moves at minus the curvature there plus 2.5 times the curvature
/// upstream, averaged with weights that fall off with distance. Flow never enters. Its form and the constants Ω, Γ
/// and α were read from Zoltán Sylvester's meanderpy (Apache-2.0, github.com/zsylvester/meanderpy); no code was
/// copied. Everything else here (the valley, the width, cutoffs, lakes, the fields) is ours: docs/meander.md.
///
/// Lengths are in channel widths and time in T, the time a bank of curvature 1 would take to move one width with
/// no upstream help. The river is periodic along the valley: its last node joins its first one period further on,
/// and the screen shows x from 0 to `across`. Pinned at its ends instead, the bends wash out downstream.
///
/// The ground is a grid of texels, each remembering when the channel last covered it (the stamp), the bank distance
/// of any old channel it lay in (the hollow), and the bank distance of the live channel and of any lake (the
/// water). A bank distance is the distance to a channel's centreline, less half its width there, plus a half: so
/// 0.5 is the bank and less is water. `pixels` holds what a shader reads.
public final class River {
    /// A list of texels, as indexes into the ground. Room for every texel, so the loop that fills it never has to
    /// grow it.
    private struct Texels {
        var items: [Int32], count = 0
        init(room: Int) { items = Array(repeating: 0, count: room) }
    }

    /// A node of the centreline: where it is and half the channel's width there. The rest is one step's working:
    /// the curvature at the node, the right-hand normal, and its part in the upstream average.
    public struct Node {
        public var x: Float, y: Float, half: Float
        var curl: Float = 0, nx: Float = 0, ny: Float = 0, carry: Float = 0, share: Float = 0
        /// Where its right and left banks were at the last `sweep`, while a past is being made.
        var right = SIMD2<Float>.zero, left = SIMD2<Float>.zero

        /// Moves it along the valley, by a period say.
        mutating func slide(_ dx: Float) {
            x += dx
            right.x += dx
            left.x += dx
        }
    }

    /// A cut-off loop: its nodes (x, y, half-width) as they were, when it was cut off, and when its first and last
    /// node each became an end. It's drawn by the routine that draws the river, so its edges are as smooth.
    public struct Lake {
        public var nodes: [SIMD3<Float>]
        public var born: Double, first: Double, last: Double
        /// The texels it was last drawn on and its bank distance at each, the box round them (the least column and
        /// row, then the greatest), and when that was.
        var texels: [Int32] = [], distances: [Float] = [], box = SIMD4<Int32>(.max, .max, -1, -1), drawn = -Double.infinity

        /// How far a silting front has come in from an end that has been one for `age`: about 3 widths in the first
        /// T, then a quarter of a width a T.
        static func front(_ age: Float) -> Float { 3.2 * (1 - exp(-age / 0.6)) + 0.25 * age }

        /// How long an end has been one for its front to have come `far` in: `front` the other way round.
        static func age(ofFront far: Float) -> Float {
            var (lo, hi) = (Float(0), 4 * max(far, 0) + 1)
            for _ in 0..<24 { if front(0.5 * (lo + hi)) < far { lo = 0.5 * (lo + hi) } else { hi = 0.5 * (lo + hi) } }
            return 0.5 * (lo + hi)
        }
    }

    /// Howard & Knutson's Ω and Γ, and α in widths: the fastest-growing bend is 8.24/α long, 11.3 widths.
    static let local: Float = -1, upstream: Float = 2.5, alpha: Float = 0.73
    /// No bank moves faster than this, in widths a T: it bounds the motion at a cutoff's kink.
    static let fastest: Float = 1.25
    /// Two stretches cut through when their centrelines are within this times their half-widths: banks touching.
    static let touching: Float = 1.04
    /// Half the width of the way through a neck when it is first cut, in widths, and how fast it opens toward the
    /// width the river asks for, in T: three seconds at speed 1 to two thirds of the full width, then at the
    /// river's own pace.
    static let breach: Float = 0.08, opens: Float = 0.25
    /// Valley out of sight beyond each end of the screen, in widths.
    static let margin: Float = 10
    /// How long the ground remembers the river, in T.
    public static let memory = 600.0
    /// A lake's life, in T: over its second half it narrows to nothing. A setting, so it can change as the river runs.
    public var lakeLife = 16.0
    /// How long the river's own courses stay in the picture, in T: a setting too. Ground it left longer ago than
    /// that is drawn as the older ground beneath, so that is what a bank's furthest reach there steps up to.
    public var stays = River.memory
    /// A stamp for ground the river has never covered.
    static let never: Float = -1e9
    /// A lake is drawn again once a front of its has moved this far since it last was, in texels; and how many
    /// lakes at the most are drawn again in one step.
    static let adrift: Float = 0.04, lakesAStep = 6

    /// Where the river may go. `within`: kept inside the screen, its walls standing 1.5 to 6.5 widths in from the
    /// top and bottom; what shows beyond them is the older ground (`beneath`). `full`: to the edges and past
    /// them, its walls up to 2 widths out, so the picture is river and floodplain from edge to edge and bends run
    /// off it.
    public enum Valley: Sendable { case within, full }

    /// The screen in widths, and texels a width.
    public let across: Float, up: Float, texels: Float
    public let valley: Valley
    /// Its seed, for the older river's; and whether it is one: the river that leaves another's backdrop, which
    /// wanders wider than either valley and is only ever swept.
    private let seed: UInt64, backdrop: Bool
    /// The valley's walls: how far past the ground's top and bottom they stand at their furthest out, in widths
    /// (inside it, below 0); how much of the walls' wander is kept; and over how many widths a wall resists.
    private let wall: (out: Float, wander: Float, resists: Float)
    /// The ground's grid.
    public let columns: Int, rows: Int
    public var period: Float { across + 2 * Self.margin }

    public private(set) var nodes: [Node] = []
    public private(set) var lakes: [Lake] = []
    /// The time in T, and what the stamps count from (see `rebase`): a little over the ground's memory back, so a
    /// texel the river has never reached, whose stamp is none, reads as older than anything remembered.
    public private(set) var now = 0.0, base = -(River.memory + 5)
    public private(set) var cutoffs = 0
    /// How many times the river has run back over a lake and taken part of it.
    public private(set) var trims = 0
    /// Nodes are kept 0.6 to 1.4 times this far apart.
    private var spacing: Float

    /// Per texel: the stamp (T since `base`), the hollow, the live channel's bank distance and the lakes'.
    public private(set) var ground: [SIMD4<Float>]
    /// Four bytes a texel for a shader: the stamp in 16 bits at 0.01 T a level, then the water (the live channel or
    /// a lake, whichever is nearer; its bank at mid-range, two texels either side filling the byte), then the hollow
    /// over 0.25 to 1.
    public private(set) var pixels: [UInt8]
    /// The older ground, which lies beneath this river's own and shows wherever that is forgotten or was never
    /// made (`layBackdrop`): four bytes a texel for a shader, the first two how long before `ancient` its river
    /// left there, in 16 bits at 0.01 T a level. It is laid once and never changes: its ages are for good.
    /// (Empty until the river has its past.)
    public private(set) var beneath: [UInt8] = []
    /// The older ground's age at a texel, in T.
    @inline(__always) private func olderAge(_ i: Int) -> Float { Float(Self.ancient) - Float(Int(beneath[i * 4]) << 8 | Int(beneath[i * 4 + 1])) / 100 }
    /// When a past being made will end (`age`): the older ground's ages are as at then, while it is made.
    private var pastEnds = 0.0

    /// A bank distance for texels nowhere near a channel.
    private static let far: Float = 9
    private var spare: [Node] = []
    private var path: [SIMD3<Float>] = [], banks: [SIMD4<Float>] = [], arcs: [Float] = [], under: [Double] = []
    private var scratch: [Float]
    private var touched: Texels, before: Texels, lakeTouched: Texels, lakeBefore: Texels
    private var erosion: [Float] = [], erosionColumns = 0, erosionRows = 0, erosionCell: Float = 8
    private var walls: [Float] = []
    private var head: [Int32] = [], next: [Int32] = [], cell: [Int32] = []
    /// How far the river is toward its next step, from 0 to 1 (see `advance`): a picture drawn between two steps
    /// can be mixed from them by it.
    public private(set) var owed = 0.0
    /// When `sweep` last ran, as a stamp.
    private var sweptAt: Float = 0
    /// Whether a past is being made by `sweep`, and the nodes a pass of `respace` is about to drop.
    private var sweeping = false, dropped: [Int] = []
    /// How far each lake's faster front has moved since the lake was drawn, in texels, for `drawLakes`.
    private var behind: [Float] = []
    /// The next row `forget` will see to.
    private var forgetting = 0

    /// A straight river with small wiggles, from which the bends grow, and the ground it will write on.
    public convenience init(seed: UInt64, across: Float, up: Float, texels: Float, spacing: Float = 0.5, valley: Valley = .within) {
        self.init(seed: seed, across: across, up: up, texels: texels, spacing: spacing, valley: valley, backdrop: false)
    }

    private init(seed: UInt64, across: Float, up: Float, texels: Float, spacing: Float, valley: Valley, backdrop: Bool) {
        (self.across, self.up, self.texels, self.spacing) = (across, up, texels, spacing)
        (self.seed, self.valley, self.backdrop) = (seed, valley, backdrop)
        wall = backdrop ? (4, 0.4, 2.5) : valley == .full ? (2, 0.4, 2.5) : (-1.5, 1, 5)
        columns = Int((across * texels).rounded())
        rows = Int((up * texels).rounded())
        ground = Array(repeating: [Self.never, 1, Self.far, Self.far], count: columns * rows)
        scratch = Array(repeating: .infinity, count: columns * rows)
        pixels = Array(repeating: 255, count: columns * rows * 4)
        (touched, before, lakeTouched, lakeBefore) = (Texels(room: columns * rows), Texels(room: columns * rows), Texels(room: columns * rows), Texels(room: columns * rows))
        var rng = Seeded(state: seed)
        func unit() -> Float { Float.random(in: 0..<1, using: &rng) }
        func normal() -> Float { (unit() + unit() + unit() + unit() - 2) * 1.732 } // near enough a bell curve

        let L = period, count = Int((L / spacing).rounded())
        let waves = (1..<40).map { k in (size: normal() * 0.25 / Float(k).squareRoot(), phase: unit() * 2 * .pi, k: Float(k)) }
        nodes.reserveCapacity(2048)
        spare.reserveCapacity(2048)
        // An older river starts on a wide swing, a bend to every 26 widths or so, so that it is all over its valley
        // from the first: it has less time than a river's own past to get there.
        let swing: Float = backdrop ? Self.swing * (up / 2 + wall.out) : 0, bends = (L / 26).rounded(), turned = backdrop ? unit() * 2 * .pi : 0
        for i in 0..<count {
            let along = Float(i) / Float(count)
            nodes.append(Node(x: -Self.margin + L * along, y: waves.reduce(up / 2 + swing * sin(2 * .pi * bends * along + turned)) { $0 + $1.size * sin(2 * .pi * $1.k * along + $1.phase) }, half: 0.5))
        }

        // How easily a bank erodes: a smooth random field, clay here and sand there, fixed for the river's life
        erosionColumns = Int((L / 8).rounded())
        erosionCell = L / Float(erosionColumns)
        erosionRows = Int(up / erosionCell) + 3
        erosion = (0..<erosionColumns * erosionRows).map { _ in exp(0.5 * normal()) }
        // How far each valley wall stands in along the valley, so the belt's edge is scalloped, not a corridor:
        // 256 places along the top wall, then the bottom
        for _ in 0..<2 {
            let bays = (2..<8).map { k in (size: normal() / Float(k).squareRoot(), phase: unit() * 2 * .pi, k: Float(k)) }
            walls += (0..<256).map { i in 2.5 * (1 + tanh(bays.reduce(0) { $0 + $1.size * sin(2 * .pi * $1.k * Float(i) / 256 + $1.phase) })) }
        }
        let reach = Self.touching * 1.5 // as far apart as two touching stretches' centrelines can be
        head = Array(repeating: -1, count: Int(L / reach) * (Int(up / (L / Float(Int(L / reach)))) + 3))
        path.reserveCapacity(2048)
        banks.reserveCapacity(2048)
    }

    // MARK: The river

    /// One step of the migration: every node moves along its normal at Ω times its curvature plus Γ times the
    /// curvature upstream, slowed or sped by the ground it is cutting into and stopped by the valley's walls.
    /// The channel's width eases toward 0.7 widths on straight reaches and 1.5 round the tightest bends.
    private func migrate(_ eps: Float) {
        let n = nodes.count, L = period, middle = up / 2, cap = Self.fastest * eps, ease = 1 - exp(-eps / 1.5), opening = 1 - exp(-eps / Self.opens)
        let alpha = Self.alpha, runUp = max(n - Int(16 / alpha / spacing), 0), margin = Self.margin
        let cell = erosionCell, across = erosionColumns, down = erosionRows
        erosion.withUnsafeBufferPointer { erosion in walls.withUnsafeBufferPointer { walls in nodes.withUnsafeMutableBufferPointer { p in
            for i in 0..<n { // the curvature is the circle through three nodes: they aren't evenly spaced
                let before = p[i == 0 ? n - 1 : i - 1], after = p[i == n - 1 ? 0 : i + 1]
                let ax = p[i].x - before.x + (i == 0 ? L : 0), ay = p[i].y - before.y
                let bx = after.x - p[i].x + (i == n - 1 ? L : 0), by = after.y - p[i].y
                let la = (ax * ax + ay * ay).squareRoot(), lb = (bx * bx + by * by).squareRoot()
                let cx = ax + bx, cy = ay + by, lc = (cx * cx + cy * cy).squareRoot() + 1e-12
                p[i].curl = 2 * (ax * by - ay * bx) / (la * lb * lc + 1e-12)
                p[i].nx = cy / lc
                p[i].ny = -cx / lc
                p[i].carry = exp(-alpha * la)
                p[i].share = 0.5 * (la + lb)
            }
            // The upstream average is two running sums; run them up from further round the period first
            var sum: Float = 0, weight: Float = 0, bend: Float = 0
            for i in runUp..<n { (sum, weight) = (p[i].curl * p[i].share + p[i].carry * sum, p[i].share + p[i].carry * weight) }
            for k in -3...3 { bend += abs(p[(k + n) % n].curl) }
            for i in 0..<n {
                (sum, weight) = (p[i].curl * p[i].share + p[i].carry * sum, p[i].share + p[i].carry * weight)
                let rate = Self.local * p[i].curl + Self.upstream * sum / weight, side: Float = rate < 0 ? -1 : 1
                let bankX = p[i].x + 0.5 * side * p[i].nx, bankY = p[i].y + 0.5 * side * p[i].ny // the bank being eaten
                var along = (bankX + margin) / L
                along -= along.rounded(.down)
                let gx = along * Float(across), gy = max(0, min(Float(down) - 1.001, bankY / cell))
                let ix = min(Int(gx), across - 1), iy = Int(gy), jx = (ix + 1) % across, fx = gx - Float(ix), fy = gy - Float(iy)
                var soft = (erosion[iy * across + ix] * (1 - fx) + erosion[iy * across + jx] * fx) * (1 - fy)
                    + (erosion[(iy + 1) * across + ix] * (1 - fx) + erosion[(iy + 1) * across + jx] * fx) * fy
                if side * p[i].ny * (bankY - middle) > 0 { // cutting toward a wall, which resists over its last 5 widths
                    let standsIn = walls[(bankY > middle ? 0 : 256) + min(Int(along * 256), 255)]
                    soft *= smoothstep(0, wall.resists, middle + wall.out - wall.wander * standsIn - abs(bankY - middle))
                }
                // bend is seven nodes' curvature; a node narrower than that ever asks for is a breach, which opens fast
                p[i].half += (0.5 * (0.7 + 0.8 * min(bend / 2.8, 1)) - p[i].half) * (p[i].half < 0.34 ? opening : ease)
                bend += abs(p[i + 4 < n ? i + 4 : i + 4 - n].curl) - abs(p[i < 3 ? i + n - 3 : i - 3].curl)
                let move = max(-cap, min(cap, rate * soft * eps))
                p[i].x += move * p[i].nx
                p[i].y += move * p[i].ny
            }
        } } }
        now += Double(eps)
    }

    /// Keeps the nodes 0.6 to 1.4 spacings apart by splitting long segments (on the cubic through their neighbours)
    /// and dropping the far node of short ones. No other node moves, so the rest of the river's banks stay put.
    /// Four passes at most: dropping a node and splitting what is left can undo each other for ever.
    private func respace() {
        let L = period, long = 1.96 * spacing * spacing, short = 0.36 * spacing * spacing // squared
        for _ in 0..<4 {
            let n = nodes.count
            let changed = nodes.withUnsafeBufferPointer { p in
                func length(_ i: Int) -> Float { // squared
                    let q = i == n - 1 ? 0 : i + 1, dx = p[q].x + (i == n - 1 ? L : 0) - p[i].x, dy = p[q].y - p[i].y
                    return dx * dx + dy * dy
                }
                var needed = false, i = 0
                while i < n, !needed {
                    let reach = length(i)
                    needed = reach > long || (reach < short && i < n - 1)
                    i += 1
                }
                guard needed else { return false }
                spare.removeAll(keepingCapacity: true)
                dropped.removeAll(keepingCapacity: true)
                i = 0
                while i < n {
                    let q = (i + 1) % n, wrap: Float = i == n - 1 ? L : 0, here = p[i], there = p[q], reach = length(i)
                    spare.append(here)
                    if reach > long {
                        let behind = p[(i + n - 1) % n], ahead = p[(i + 2) % n]
                        let x0 = behind.x - (i == 0 ? L : 0), x2 = there.x + wrap, x3 = ahead.x + (i + 2 >= n ? L : 0)
                        spare.append(Node(x: (-x0 + 9 * here.x + 9 * x2 - x3) / 16, y: (-behind.y + 9 * here.y + 9 * there.y - ahead.y) / 16,
                                          half: 0.5 * (here.half + there.half), right: 0.5 * (here.right + there.right + [wrap, 0]),
                                          left: 0.5 * (here.left + there.left + [wrap, 0])))
                    } else if reach < short && i < n - 1 {
                        dropped.append(i)
                        i += 1
                    }
                    i += 1
                }
                return true
            }
            guard changed else { break }
            // A node that goes takes a corner of the old bank line with it: sweep the two segments it ends first,
            // or the ground inside that corner is never stamped (where a bank swings round, these made fans of gaps)
            if sweeping { for i in dropped { sweep(loop: i..<i + 2) } }
            swap(&nodes, &spare)
        }
        // Keep the river in the period that holds the screen: the first node says where it is, near enough
        let shift = L * ((nodes[0].x + Self.margin) / L).rounded(.down)
        if shift != 0 { for i in nodes.indices { nodes[i].slide(-shift) } }
    }

    /// Finds the two stretches of river whose banks have touched, the pair nearest each other if several have: the
    /// loop between them is nodes `lo` to `hi`, `hi` counting on past the last node if the loop runs through the
    /// period's end. The search is by a grid of buckets a touching pair's reach across, each node against the nodes
    /// in its own bucket and the eight round it.
    private func neck() -> (lo: Int, hi: Int)? {
        let n = nodes.count, gap = Int(6 / spacing), L = period, margin = Self.margin
        let across = Int(L / (Self.touching * 1.5)), side = L / Float(across), down = head.count / across
        if next.count < n { (next, cell) = (Array(repeating: -1, count: nodes.capacity), Array(repeating: 0, count: nodes.capacity)) }
        var best: Float = 0, lo = -1, hi = -1
        nodes.withUnsafeBufferPointer { p in head.withUnsafeMutableBufferPointer { head in
        next.withUnsafeMutableBufferPointer { next in cell.withUnsafeMutableBufferPointer { cell in
            head.update(repeating: -1)
            for i in 0..<n {
                var along = (p[i].x + margin) / L
                along -= along.rounded(.down)
                let cx = min(Int(along * Float(across)), across - 1), cy = max(0, min(down - 1, Int(p[i].y / side) + 1)), c = cy * across + cx
                (cell[i], next[i], head[c]) = (Int32(cy << 16 | cx), head[c], Int32(i))
            }
            for i in 0..<n {
                let cx = Int(cell[i] & 0xFFFF), cy = Int(cell[i] >> 16), here = cy * across, below = here + across
                let left = cx == 0 ? across - 1 : cx - 1, right = cx == across - 1 ? 0 : cx + 1
                // its own bucket, the one to its right, and the three below: the other four look back at this one
                for k in 0..<(cy + 1 < down ? 5 : 2) {
                    var j = Int(head[k == 0 ? here + cx : k == 1 ? here + right : k == 2 ? below + left : k == 3 ? below + cx : below + right])
                    while j >= 0 {
                        var dx = p[j].x - p[i].x, periods = 0
                        if dx > 0.5 * L { (dx, periods) = (dx - L, 1) } else if dx < -0.5 * L { (dx, periods) = (dx + L, -1) }
                        let dy = p[j].y - p[i].y, reach = Self.touching * (p[i].half + p[j].half)
                        if dx * dx + dy * dy < reach * reach, j > i || k > 0 {
                            let between = (dx * dx + dy * dy).squareRoot() - reach
                            let other = j - periods * n, hops = abs(other - i) // node j's copy that is near node i
                            if between < best, hops >= gap, hops <= n - gap { (best, lo, hi) = (between, min(i, other), max(i, other)) }
                        }
                        j = Int(next[j])
                    }
                }
            }
        } } } }
        guard lo != -1 else { return nil }
        return lo < 0 ? (lo + n, hi + n) : lo >= n ? (lo - n, hi - n) : (lo, hi)
    }

    /// Cuts through a neck: drops the loop, which it returns. The river goes on from `hi` round to `lo` a period
    /// later, and its closing segment is then the way through the neck. With `breach` that way starts as a breach
    /// and widens: two nodes go in a third and two thirds of the way across, `Self.breach` wide, and `migrate`
    /// opens them out. (Two, each inside the channel it leaves: one in the middle made a waist with long flanks
    /// that was a third of a width across at the neck from the start.) At its full width from the first step,
    /// the way through took the neck's last land with it for half a width either side, two tapered tips 20 px
    /// long gone in one frame; now they wear back as the breach widens. (Not for a past being made, where nobody
    /// is watching and `markNeck` wants the neck's two sides to be the first node and the last.)
    private func cut(_ lo: Int, _ hi: Int, breach: Bool = false) -> [SIMD3<Float>] {
        let n = nodes.count, L = period
        let loop = (lo...hi).map { SIMD3(nodes[$0 % n].x + Float($0 / n) * L, nodes[$0 % n].y, nodes[$0 % n].half) }
        spare.removeAll(keepingCapacity: true)
        for k in hi...(lo + n) {
            var node = nodes[k % n]
            node.slide(Float(k / n) * L - (hi >= n ? L : 0))
            spare.append(node)
        }
        if breach, let near = spare.last, let far = spare.first { // the neck's two sides, the far one a period on
            for third: Float in [1 / 3, 2 / 3] {
                spare.append(Node(x: near.x + (far.x + L - near.x) * third, y: near.y + (far.y - near.y) * third, half: Self.breach))
            }
        }
        swap(&nodes, &spare)
        cutoffs += 1
        return loop
    }

    // MARK: The ground

    /// Leaves in `scratch` each texel's bank distance to the channel in `path`, for texels out to `reach` beyond its
    /// banks, and adds them to `list`. Each segment is bowed to pass through the middle of the cubic through its
    /// neighbours, so banks aren't faceted. Its width runs evenly from one node's to the next's, and its banks are
    /// the lines that touch the two nodes' circles, so where the width changes fast (a lake's silted end) the
    /// joints still meet. A segment visits only the slab of texels beside itself and a little past each end, enough
    /// to close the gap at the joint; a joint sharper than that allows for, or an open end, gets its own disc. It
    /// runs its inner loop across itself, along whichever of the grid's axes is nearer to that, where the bank
    /// distance changes by the same amount from texel to texel. Each segment is drawn in the period that puts it on
    /// screen. A stretch with no width (a dry lake) draws nothing. `bankDistance(at:)` is the long way, to check it by.
    private func band(_ count: Int, closed: Bool, reach: Float, into list: inout Texels) {
        let tex = texels, columns = columns, rows = rows, L = period, margin = Self.margin, limit = 0.5 + reach
        var found = list.count
        scratch.withUnsafeMutableBufferPointer { scratch in path.withUnsafeBufferPointer { p in list.items.withUnsafeMutableBufferPointer { items in
            func node(_ k: Int) -> SIMD3<Float> {
                if closed { return p[(k + count) % count] + [k < 0 ? -L : k >= count ? L : 0, 0, 0] }
                return k < 0 ? 2 * p[0] - p[1] : k >= count ? 2 * p[count - 1] - p[count - 2] : p[k]
            }
            func direction(_ from: SIMD3<Float>, _ to: SIMD3<Float>) -> SIMD2<Float> { simd_normalize(SIMD2(to.x - from.x, to.y - from.y) + [1e-12, 0]) }
            var behind = node(-1), a = node(0), b = node(1), last = direction(behind, a)
            for i in 0..<(closed ? count : count - 1) {
                let ahead = node(i + 2), heading = direction(a, b), next = direction(b, ahead)
                defer { (behind, a, b, last) = (a, b, ahead, heading) }
                let ex = b.x - a.x, ey = b.y - a.y, length2 = ex * ex + ey * ey + 1e-12, length = length2.squareRoot()
                guard max(a.z, b.z) + reach > 0 else { continue }
                // how far the cubic's middle stands to the right of the chord's
                let bow = ((a.x + b.x - behind.x - ahead.x) * ey - (a.y + b.y - behind.y - ahead.y) * ex) / (16 * length)
                let out = max(a.z, b.z) + reach + abs(bow)
                var along = (0.5 * (a.x + b.x) + margin) / L
                along -= along.rounded(.down)
                let ax = a.x + along * L - margin - 0.5 * (a.x + b.x), ay = a.y // in the period that holds the screen
                let turnIn = simd_dot(last, heading), turnOut = simd_dot(heading, next)
                // an end, or a turn of over 26 degrees, gets a disc round the node
                for end in 0..<2 where end == 0 ? (!closed && i == 0) || turnIn < 0.9 : !closed && i == count - 2 {
                    let cx = end == 0 ? ax : ax + ex, cy = end == 0 ? ay : ay + ey, half = end == 0 ? a.z : b.z, wide = half + reach
                    let x0 = max(Int(((cx - wide) * tex).rounded(.down)), 0), x1 = min(Int(((cx + wide) * tex).rounded(.up)), columns - 1)
                    let y0 = max(Int(((cy - wide) * tex).rounded(.down)), 0), y1 = min(Int(((cy + wide) * tex).rounded(.up)), rows - 1)
                    guard x0 <= x1, y0 <= y1 else { continue }
                    for ty in y0...y1 {
                        let gy = (Float(ty) + 0.5) / tex - cy
                        for tx in x0...x1 {
                            let gx = (Float(tx) + 0.5) / tex - cx, distance = (gx * gx + gy * gy).squareRoot() - half + 0.5, at = ty * columns + tx
                            if distance < limit, distance < scratch[at] {
                                if scratch[at] == .infinity { (items[found], found) = (Int32(at), found + 1) }
                                scratch[at] = distance
                            }
                        }
                    }
                }
                // The banks are the lines that touch both nodes' circles, so they lean in toward the narrower end, by
                // `lean` across for `level` along (Inigo Quilez's uneven capsule, iquilezles.org/articles/distfunctions2d)
                let lean = max(-0.9, min(0.9, (a.z - b.z) / length)), level = (1 - lean * lean).squareRoot()
                // past each end by the gap its joint leaves on the outside of the turn, by as far as the leaning
                // banks run on beyond the narrower end, and by half a texel
                func gap(_ turn: Float, _ narrowing: Float) -> Float {
                    let turn = min(max(turn, 0.9), 1)
                    return (out * (((1 - turn) / (1 + turn)).squareRoot() + max(narrowing, 0) / level) + 0.5 / tex) / length
                }
                let before = gap(turnIn, -lean), past = gap(turnOut, lean)
                // The inner loop runs down columns if the segment is nearer level, along rows if it is nearer upright
                let upright = abs(ey) > abs(ex), outerEnd = upright ? rows - 1 : columns - 1, innerEnd = upright ? columns - 1 : rows - 1
                let (o, t) = upright ? (ay, ax) : (ax, ay), (eo, et) = upright ? (ey, ex) : (ex, ey) // the outer and the inner axis
                let reachO = abs(eo) * max(before, past) + out * abs(et) / length
                let o0 = max(Int(((min(o, o + eo) - reachO) * tex).rounded(.down)), 0), o1 = min(Int(((max(o, o + eo) + reachO) * tex).rounded(.up)), outerEnd)
                guard o0 <= o1 else { continue }
                // along the segment (0 to 1) and off it to the right, at inner texel 0 of each outer line, and their steps
                let shareStep = et / length2 / tex, offStep = (upright ? ey : -ex) / length / tex, stride = upright ? 1 : columns
                for outer in o0...o1 {
                    let go = (Float(outer) + 0.5) / tex - o, gt = 0.5 / tex - t
                    let share0 = (go * eo + gt * et) / length2, off0 = upright ? (gt * ey - go * ex) / length : (go * ey - gt * ex) / length
                    var u = (-out - off0) / offStep, v = (out - off0) / offStep
                    var (from, to) = (min(u, v), max(u, v))
                    if abs(shareStep) > 1e-9 {
                        (u, v) = ((-before - share0) / shareStep, (1 + past - share0) / shareStep)
                        (from, to) = (max(from, min(u, v)), min(to, max(u, v)))
                    } else if share0 < -before || share0 > 1 + past { continue }
                    let first = max(Int(from.rounded(.up)), 0), final = min(Int(to.rounded(.down)), innerEnd)
                    guard first <= final else { continue }
                    var share = share0 + shareStep * Float(first), off = off0 + offStep * Float(first)
                    var at = upright ? outer * columns + first : first * columns + outer
                    for _ in first...final {
                        let distance: Float, along = share * length, aside = abs(off - 4 * share * (1 - share) * bow)
                        let place = level * along - lean * aside // which of the three it is nearest: a's circle, b's, or a bank
                        if place < 0 {
                            distance = (off * off + along * along).squareRoot() - a.z + 0.5
                        } else if place > level * length {
                            distance = (off * off + (along - length) * (along - length)).squareRoot() - b.z + 0.5
                        } else {
                            distance = level * aside + lean * along - a.z + 0.5
                        }
                        if distance < limit, distance < scratch[at] {
                            if scratch[at] == .infinity { (items[found], found) = (Int32(at), found + 1) }
                            scratch[at] = distance
                        }
                        (share, off, at) = (share + shareStep, off + offStep, at + stride)
                    }
                }
            }
        } } }
        list.count = found
    }

    /// The live channel's bank distance at a point on screen, the long way: every segment, each one split in two at
    /// the middle of the cubic through its neighbours and drawn as two straight pieces, which is how the prototype
    /// drew a bank. For the tests, to hold `band` and its bowed segments to.
    func bankDistance(at point: SIMD2<Float>) -> Float {
        let n = nodes.count, L = period
        func node(_ k: Int) -> SIMD3<Float> {
            let at = (k + n) % n
            return SIMD3(nodes[at].x + (k < 0 ? -L : k >= n ? L : 0), nodes[at].y, nodes[at].half)
        }
        func piece(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ shift: Float) -> Float {
            let e = SIMD2(b.x - a.x, b.y - a.y), length = simd_length(e) + 1e-9, p = point - SIMD2(a.x + shift, a.y)
            let along = simd_dot(p, e) / length, aside = abs(p.x * e.y - p.y * e.x) / length
            let lean = max(-0.9, min(0.9, (a.z - b.z) / length)), level = (1 - lean * lean).squareRoot(), place = level * along - lean * aside
            if place < 0 { return simd_length(p) - a.z + 0.5 }
            if place > level * length { return simd_length(p - e) - b.z + 0.5 }
            return level * aside + lean * along - a.z + 0.5
        }
        var nearest = Float.infinity
        for i in 0..<n {
            let behind = node(i - 1), a = node(i), b = node(i + 1), ahead = node(i + 2)
            let middle = (9 * (a + b) - behind - ahead) / 16
            var along = (0.5 * (a.x + b.x) + Self.margin) / L
            along -= along.rounded(.down)
            let shift = along * L - Self.margin - 0.5 * (a.x + b.x) // the period that holds the screen, as `band` has it
            nearest = min(nearest, piece(a, middle, shift), piece(middle, b, shift))
        }
        return nearest
    }

    /// Fills `banks` with the right bank (x, y) and the left bank (z, w) of each node of the channel in `path`, or
    /// of just the nodes in `only`, which may count on past the last node of a closed one.
    private func bankLines(_ count: Int, closed: Bool, only: Range<Int>? = nil) {
        let L = period
        if banks.count != count { banks = Array(repeating: .zero, count: count) }
        path.withUnsafeBufferPointer { p in
            for k in only ?? 0..<count {
                let at = k % count
                let behind = closed ? p[at == 0 ? count - 1 : at - 1] - [at == 0 ? L : 0, 0, 0] : p[max(at - 1, 0)]
                let ahead = closed ? p[at == count - 1 ? 0 : at + 1] + [at == count - 1 ? L : 0, 0, 0] : p[min(at + 1, count - 1)]
                let along = simd_normalize(SIMD2(ahead.x - behind.x, ahead.y - behind.y) + [1e-12, 0]) * p[at].z
                banks[at] = [p[at].x + along.y, p[at].y - along.x, p[at].x - along.y, p[at].y + along.x]
            }
        }
    }

    /// Stamps the texels whose centres lie in a quad, and wipes any hollow there, or with `hollow` makes them one.
    /// The quad's corners go round it, and the stamp runs from `from` on its first edge (a to b) to `to` on its
    /// third (c to d): the first is where a bank was, the third where it is now, and the ground between was left at
    /// times in between. With `from` and `to` the same it is a channel's ribbon, its banks the first and third
    /// edges. A `soft` edge is a bank the river may never come back to, the scarp the picture will show: texels up
    /// to one beyond it take a share of the stamp, less the further out, so the scarp comes out as smooth as the
    /// live river's and not in texel-sized stairs (it stands half a texel further out than it should, which
    /// nobody can see). Drawn in the period that puts it on screen: the cheap way to mark the ground, for a past
    /// nobody watched.
    private func fill(_ a: SIMD2<Float>, _ b: SIMD2<Float>, _ c: SIMD2<Float>, _ d: SIMD2<Float>, from: Float, to: Float, hollow: Bool = false,
                      soft: Bool = true, _ ground: UnsafeMutableBufferPointer<SIMD4<Float>>) {
        let tex = texels, L = period, ribbon = from == to, settled = Float((sweeping ? pastEnds : now) - base)
        // The first edge's line and the third's, as slopes in x and in y that give how far inside each a point is
        var first = simd_normalize(SIMD2(a.y - b.y, b.x - a.x) + [1e-12, 0]), third = simd_normalize(SIMD2(c.y - d.y, d.x - c.x) + [1e-12, 0])
        if simd_dot(c + d - a - b, first) < 0 { first = -first }
        if simd_dot(a + b - c - d, third) < 0 { third = -third }
        // what is scanned: the quad, and a texel beyond each soft edge
        let reach = soft ? 1 / tex : 0
        let (sa, sb) = (a - first * reach, b - first * reach), (sc, sd) = ribbon ? (c - third * reach, d - third * reach) : (c, d)
        let top = min(min(sa.y, sb.y), min(sc.y, sd.y)), bottom = max(max(sa.y, sb.y), max(sc.y, sd.y)) // (min of four would make an array)
        let y0 = max(Int((top * tex - 0.5).rounded(.up)), 0), y1 = min(Int((bottom * tex - 0.5).rounded(.down)), rows - 1)
        guard y0 <= y1 else { return }
        let middle = 0.25 * (a.x + b.x + c.x + d.x) + Self.margin, shift = -(middle / L).rounded(.down) * L
        for ty in y0...y1 {
            let y = (Float(ty) + 0.5) / tex
            let edges = (crossing(sa, sb, y), crossing(sb, sc, y), crossing(sc, sd, y), crossing(sd, sa, y)) // not numbers where the row misses an edge
            let left = Float.minimum(Float.minimum(edges.0, edges.1), Float.minimum(edges.2, edges.3))
            let right = Float.maximum(Float.maximum(edges.0, edges.1), Float.maximum(edges.2, edges.3))
            guard left <= right else { continue }
            let x0 = max(Int(((left + shift) * tex - 0.5).rounded(.up)), 0), x1 = min(Int(((right + shift) * tex - 0.5).rounded(.down)), columns - 1)
            guard x0 <= x1 else { continue }
            let x = (Float(x0) + 0.5) / tex - shift
            // texels inside the first edge and inside the third
            var inFirst = ((x - a.x) * first.x + (y - a.y) * first.y) * tex, inThird = ((x - c.x) * third.x + (y - c.y) * third.y) * tex
            for i in ty * columns + x0...ty * columns + x1 {
                let cover = 1 + (ribbon ? min(inFirst, inThird) : inFirst), within = max(inFirst, 0)
                let value = ribbon ? from : from + (to - from) * within / (within + abs(inThird) + 1e-9)
                if cover >= 1 {
                    (ground[i].x, ground[i].y) = (value, hollow ? min(ground[i].y, 0.3) : 1)
                } else if cover > 0 {
                    // (where the river has left no ground of its own, what is there is the older ground)
                    let own = ground[i].x == Self.never && !beneath.isEmpty ? settled - olderAge(i) : ground[i].x, old = max(own, value - 400)
                    ground[i].x = old + (value - old) * cover
                }
                (inFirst, inThird) = (inFirst + first.x, inThird + third.x)
            }
        }
    }

    /// Remembers where each node's banks are, for the next `sweep` to measure from.
    private func markBanks() {
        bankLines(trace(), closed: true)
        for i in nodes.indices { (nodes[i].right, nodes[i].left) = (banks[i].lowHalf, banks[i].highHalf) }
        sweptAt = Float(now - base)
    }

    /// Fills the cracks a swept past leaves: a texel, or a line of them one or two wide, that every strip missed
    /// and that is left older than the ground on both sides of it. Each stamp becomes the latest of the nine round
    /// it, and then the earliest of the nine round that, which closes anything under three texels wide and moves no
    /// scarp. (Where a bank swings round against a valley wall the strips, drawn between straight banks, leave fans
    /// of such cracks: 1% of the ground, measured against the same past kept the exact way.)
    private func closeCracks() {
        let columns = columns, count = columns * rows
        var stamps = [Float](repeating: 0, count: count), other = stamps
        ground.withUnsafeMutableBufferPointer { ground in stamps.withUnsafeMutableBufferPointer { a in other.withUnsafeMutableBufferPointer { b in
            for i in 0..<count { (a[i], b[i]) = (ground[i].x, ground[i].x) }
            // across and then up, each time; a row's end takes the next row's start for its neighbour, and the top
            // and bottom rows are left as they were, which only the screen's own edge can tell
            for i in 1..<count - 1 { b[i] = max(max(a[i - 1], a[i]), a[i + 1]) }
            for i in columns..<count - columns { a[i] = max(max(b[i - columns], b[i]), b[i + columns]) }
            for i in 1..<count - 1 { b[i] = min(min(a[i - 1], a[i]), a[i + 1]) }
            for i in columns..<count - columns { a[i] = min(min(b[i - columns], b[i]), b[i + columns]) }
            for i in 0..<count { ground[i].x = max(ground[i].x, a[i]) }
        } } }
    }

    /// Fills the pockets a swept past leaves: patches a few texels across that every strip missed, most of them in
    /// the bays where a bank swung round against a valley wall. They are left as blocks of older ground inside
    /// newer, or of ground the river never reached, which Light Mode draws as paper: a white block in the belt.
    /// They are too wide for `closeCracks`, whose way of closing squares off whatever it doesn't fill. Here each
    /// stamp is first made the latest within `reach` texels, and then brought back down as far as the ground lets
    /// it, a texel taking the earliest of the eight round it but never earlier than its own. Ground that joins,
    /// through ground as old, anything too wide for the first step to cover comes back exactly as it was, every
    /// scarp where it stood; what newer ground walls in on every side stays up, at the oldest of that wall. (A
    /// closing by reconstruction.)
    // ponytail: a pocket is filled level, where a real bar would slope, and only pockets older than their wall are
    // found. A block newer than all round it (a few a launch, three texels square, plain only in the old map)
    // would take the same done the other way up.
    private func fillPockets(reach: Int = 5) {
        let columns = columns, count = columns * rows, present = Float(now - base)
        var stamps = [Float](repeating: 0, count: count), other = stamps
        ground.withUnsafeMutableBufferPointer { ground in stamps.withUnsafeMutableBufferPointer { a in other.withUnsafeMutableBufferPointer { own in
            for i in 0..<count { (a[i], own[i]) = (ground[i].x, ground[i].x) }
            for _ in 0..<reach { // across and then up, as in `closeCracks`
                for i in 1..<count - 1 { own[i] = max(max(a[i - 1], a[i]), a[i + 1]) }
                for i in columns..<count - columns { a[i] = max(max(own[i - columns], own[i]), own[i + columns]) }
            }
            for i in 0..<count { own[i] = ground[i].x }
            // the ground's own edge is no wall: a pocket against it is open, and stays as it was
            for i in 0..<columns { (a[i], a[count - 1 - i]) = (own[i], own[count - 1 - i]) }
            for i in stride(from: 0, to: count, by: columns) { (a[i], a[i + columns - 1]) = (own[i], own[i + columns - 1]) }
            // down from the top and back up from the bottom until nothing moves: a stamp runs any distance along
            // the way a pass is going, so a few passes do it
            var moved = true
            while moved {
                moved = false
                for i in columns + 1..<count - columns - 1 where a[i] > own[i] {
                    let least = min(min(a[i - 1], a[i - columns]), min(a[i - columns - 1], a[i - columns + 1]))
                    if least < a[i] { (a[i], moved) = (max(least, own[i]), true) }
                }
                for i in stride(from: count - columns - 2, through: columns + 1, by: -1) where a[i] > own[i] {
                    let least = min(min(a[i + 1], a[i + columns]), min(a[i + columns - 1], a[i + columns + 1]))
                    if least < a[i] { (a[i], moved) = (max(least, own[i]), true) }
                }
            }
            // What is filled: ground the river never reached, or over twice as old as it would be raised to, which
            // is plainly of another time than its wall; and out from there the raised ground that touches it and
            // stands lower at all. So a block goes with its soft rim, and a hollow that is only a little older
            // than its wall is left whole: filled level, the shore of one with a sloping floor would be ragged
            // where there was none.
            var next = (0..<count).filter { a[$0] > own[$0] && (own[$0] == Self.never || present - own[$0] > 2 * (present - a[$0]) + 5) }
            while let i = next.popLast() {
                guard a[i] > own[i], own[i] == Self.never || Self.height(present - own[i]) - Self.height(present - a[i]) > 0.02 else { continue }
                (ground[i].x, own[i]) = (a[i], a[i])
                for step in [-columns - 1, -columns, -columns + 1, -1, 1, columns - 1, columns, columns + 1] { next.append(i + step) }
            }
        } } }
    }

    /// After a cutoff the river's first and last nodes are the two sides of the neck, and their banks have swung
    /// round to the new course: remembers them there, so the next `sweep` doesn't take the swing for ground left.
    private func markNeck() {
        let n = trace()
        bankLines(n, closed: true, only: n - 1..<n + 1)
        for i in [0, n - 1] { (nodes[i].right, nodes[i].left) = (banks[i].lowHalf, banks[i].highHalf) }
    }

    /// The cheap way to keep the stamps while a past is being made. Since the last sweep each bank has moved from
    /// one line to another. Where it moved in toward the river, the ground between the two lines is ground the
    /// river has left: its texels take the present time and lose any hollow. So a texel is written once, as the
    /// river leaves it, and nothing is worked out for the water in between. The stamp runs from the last sweep's
    /// time at the old line to now at the new one, so the sweeps can be far apart. Whole texels: a bank's furthest
    /// reach comes out stair-stepped, where `updateGround` records it to a fraction of a texel. With `loop`, only
    /// those segments, and nothing is remembered: for a loop about to be cut off, whose nodes won't see another sweep.
    private func sweep(loop: Range<Int>? = nil) {
        let L = period, stamp = Float(now - base), before = sweptAt
        bankLines(trace(), closed: true, only: loop.map { $0.lowerBound..<$0.upperBound + 1 })
        ground.withUnsafeMutableBufferPointer { ground in nodes.withUnsafeMutableBufferPointer { p in banks.withUnsafeBufferPointer { bank in
            let n = p.count
            for k in loop ?? 0..<n {
                let i = k % n, q = i == n - 1 ? 0 : i + 1, wrap = SIMD2<Float>(i == n - 1 ? L : 0, 0)
                let here = SIMD2(p[i].x, p[i].y), there = SIMD2(p[q].x, p[q].y) + wrap
                // a bank's strip, from where it was at each end of the segment to where it is, if it has moved in at either
                func strip(_ was: SIMD2<Float>, _ next: SIMD2<Float>, _ new: SIMD2<Float>, _ newNext: SIMD2<Float>) {
                    guard simd_dot(new - was, here - new) > 0 || simd_dot(newNext - next, there - newNext) > 0 else { return }
                    fill(was, next, newNext, new, from: before, to: stamp, ground)
                }
                strip(p[i].right, p[q].right + wrap, bank[i].lowHalf, bank[q].lowHalf + wrap)
                strip(p[i].left, p[q].left + wrap, bank[i].highHalf, bank[q].highHalf + wrap)
            }
            if loop == nil { for i in 0..<n { (p[i].right, p[i].left) = (bank[i].lowHalf, bank[i].highHalf) } }
        } } }
        if loop == nil { sweptAt = stamp }
    }

    /// Gives the ribbon between the banks of the channel in `path` the present time, and makes it a hollow if
    /// `hollow`: for a loop cut off in the distant past, whose banks are `soft`, scarps from now on.
    private func fillRibbon(_ count: Int, closed: Bool, hollow: Bool = false, soft: Bool = true) {
        bankLines(count, closed: closed)
        ground.withUnsafeMutableBufferPointer { ground in
            for i in 0..<(closed ? count : count - 1) {
                let q = (i + 1) % count, wrap = SIMD2<Float>(closed && i == count - 1 ? period : 0, 0)
                fill(banks[i].lowHalf, banks[q].lowHalf + wrap, banks[q].highHalf + wrap, banks[i].highHalf, from: Float(now - base), to: Float(now - base), hollow: hollow, soft: soft, ground)
            }
        }
    }

    /// Closes the hairline a swept past leaves along a bank the river has been leaving. `sweep` works from
    /// straight banks between the nodes and `updateGround` from bowed ones, so the bar a sweep built stops short
    /// of the river's bank, and the texels between keep whatever time they had. A texel on a bank (the river
    /// part-way across it, or within a texel beyond) takes the present time if the land next out from it is new
    /// (left within 8 T) and it is itself over 3 T older: older ground between a new bar and the water, which no
    /// river leaves. Taken from the outside in, so that a hairline two texels deep closes too. A bank the river
    /// is cutting has land of its own age next out, and is left as it is. (Every texel within one of either
    /// bank used to be given the present time for this. That made a texel of new land along each bank being cut
    /// as well: unseen while relief took the land beside water from two texels out, a light fringe once it took
    /// the land's own height, and a rim of the newest ink in the old map.)
    private func joinBars() {
        lakeBefore.count = 0 // a list to hand, as in `strand`
        band(trace(), closed: true, reach: 1 / texels, into: &lakeBefore)
        let stamp = Float(now - base), columns = columns, count = columns * rows, onBank = 0.5 - 0.5 / texels, out = 0.4 / texels
        ground.withUnsafeMutableBufferPointer { ground in scratch.withUnsafeMutableBufferPointer { scratch in
            let banks = lakeBefore.items[..<lakeBefore.count].map { Int($0) }.filter { scratch[$0] > onBank }.sorted { scratch[$0] > scratch[$1] }
            /// Whether texel `other` lies out from texel `i`, and is new land where `i` is older.
            func bar(_ other: Int, _ i: Int) -> Bool {
                other >= 0 && other < count && scratch[other] - scratch[i] > out && ground[other].x > stamp - 8 && ground[other].x - ground[i].x > 3
            }
            for i in banks {
                let column = i % columns
                if (column > 0 && bar(i - 1, i)) || (column < columns - 1 && bar(i + 1, i)) || bar(i - columns, i) || bar(i + columns, i) { ground[i].x = stamp }
            }
            for raw in lakeBefore.items[..<lakeBefore.count] { scratch[Int(raw)] = .infinity }
        } }
    }

    /// Puts the live river's nodes in `path`.
    private func trace() -> Int {
        path.removeAll(keepingCapacity: true)
        for node in nodes { path.append([node.x, node.y, node.half]) }
        return path.count
    }

    /// Puts a lake's nodes in `path` at their widths now. Each end silts up behind a front that moves in from it
    /// (`Lake.front`), the water tapering to nothing over the 2 widths ahead of the front; and over the second half
    /// of its life the whole lake narrows to nothing. A dry stretch gets a negative width, so nothing is drawn.
    /// Returns how many nodes, or 0 if the lake is all dry.
    private func trace(_ lake: Lake) -> Int {
        arcs.removeAll(keepingCapacity: true)
        path.removeAll(keepingCapacity: true)
        var arc: Float = 0, wet = false
        for (i, node) in lake.nodes.enumerated() {
            if i > 0 { arc += hypot(node.x - lake.nodes[i - 1].x, node.y - lake.nodes[i - 1].y) }
            arcs.append(arc)
        }
        func silted(_ from: Float, _ since: Double) -> Float { smoothstep(0, 1, (from - Lake.front(Float(now - since))) / 2 + 1) }
        let body = 1 - smoothstep(Float(0.5 * lakeLife), Float(lakeLife), Float(now - lake.born))
        for (i, node) in lake.nodes.enumerated() {
            let share = body * silted(arcs[i], lake.first) * silted(arc - arcs[i], lake.last)
            path.append([node.x, node.y, node.z * share - 0.15 * (1 - share)])
            wet = wet || share > 0
        }
        return wet ? path.count : 0
    }

    /// Parts a lake where the river has run over it: `covered` says when it covered a texel of a lake's, or nil. The
    /// lake becomes one lake for each stretch the river hasn't covered, each keeping the covered stretch beside it
    /// as far as that stretch's middle node, so on the frame it is made nothing is lost: what is under the river is
    /// still drawn, unseen, and what stands out beyond the river's bank is still water. Each new end then silts up
    /// from when it was covered, and the water beyond the bank goes as any lake's end goes. An end is never less
    /// silted than the lake already was there, or water would come back: where the old end's front had passed the
    /// new end, the new end's front starts as far in as the old one had reached. With `gone`, for a past being
    /// made, the river has been over the covered stretches and left again, so they are dropped, all but the node
    /// next to each stretch it never reached. Worn-out lakes are forgotten. A lake that goes is taken out of the
    /// ground here, and the pieces of a parted one are drawn by `drawLakes` in the same step.
    // ponytail: a stretch the live river lies along for longer than its end takes to silt up (3 widths in the first
    // T, then a quarter of a width a T) would show again, as water, if the river moved off it sideways. Not seen;
    // if it is, drop a covered node once the lake's whole width there is inside the river.
    private func trimLakes(gone: Bool = false, covered: (Int, Lake) -> Double?) {
        let L = period
        var at = 0
        while at < lakes.count {
            let lake = lakes[at], n = lake.nodes.count
            if now - lake.born > lakeLife {
                drop(at)
                continue
            }
            under.removeAll(keepingCapacity: true)
            var runs = 0 // of nodes the river hasn't covered
            for node in lake.nodes {
                var along = (node.x + Self.margin) / L
                along -= along.rounded(.down)
                let tx = Int(((along * L - Self.margin) * texels).rounded(.down)), ty = Int((node.y * texels).rounded(.down))
                under.append(tx >= 0 && tx < columns && ty >= 0 && ty < rows ? covered(ty * columns + tx, lake) ?? .nan : .nan)
                if under[under.count - 1].isNaN, under.count == 1 || !under[under.count - 2].isNaN { runs += 1 }
            }
            // Nothing to do for one stretch with the river over its ends, where it was cut off or parted; nor, live,
            // for a lake that is all under the river. A past drops what the river has been over, so it has more to do.
            let parted = gone ? (n < 3 ? runs == 0 : under[1..<n - 1].contains { !$0.isNaN }) : runs > 1
            guard parted else {
                at += 1
                continue
            }
            trims += 1
            drop(at)
            // how far along the lake each node is, and how far in from each end the silt has come
            arcs.removeAll(keepingCapacity: true)
            var arc: Float = 0
            for (i, node) in lake.nodes.enumerated() {
                if i > 0 { arc += hypot(node.x - lake.nodes[i - 1].x, node.y - lake.nodes[i - 1].y) }
                arcs.append(arc)
            }
            let silted = (Lake.front(Float(now - lake.first)), Lake.front(Float(now - lake.last)))
            /// When an end covered at `since` became one, for its silting: then, or as much earlier as puts its front
            /// where the old end's front, `past` beyond it already, has reached.
            func began(_ since: Double, _ past: Float) -> Double { past > Lake.front(Float(now - since)) ? now - Double(Lake.age(ofFront: past)) : since }
            var i = 0, from = 0 // where the next piece starts: the middle of the covered stretch before it
            while i < n {
                guard under[i].isNaN else {
                    i += 1
                    continue
                }
                var j = i, next = i
                while j + 1 < n, under[j + 1].isNaN { j += 1 }
                next = j + 1
                while next < n, !under[next].isNaN { next += 1 } // the next stretch the river hasn't covered, or the end
                // this piece runs to the middle of the covered stretch after it, or to the lake's end if that stretch is the last
                let lo = gone ? max(i - 1, 0) : from, hi = gone ? min(j + 1, n - 1) : next == n ? n - 1 : (j + next) / 2
                if hi > lo {
                    lakes.insert(Lake(nodes: Array(lake.nodes[lo...hi]), born: lake.born, first: lo == 0 ? lake.first : began(under[lo], silted.0 - arcs[lo]),
                                      last: hi == n - 1 ? lake.last : began(under[hi], silted.1 - (arc - arcs[hi]))), at: at)
                    at += 1
                }
                (i, from) = (next, hi)
            }
        }
    }

    /// How high relief draws land of an age above the river, 0 to 1: a bar is up out of the water within a couple
    /// of T, then silts up for ages. (Relief's shader has the same curve, `stands` in Meander.swift: keep the two
    /// in step.)
    static func height(_ age: Float) -> Float { 0.25 * (1 - exp(-age / 2.5)) + 0.75 * (1 - exp(-age / 90)) }

    /// The age at which land stands each 1,024th of the way up, by halving; and so the age for any height.
    private static let ages: [Float] = (0...1024).map { level in
        var (younger, older): (Float, Float) = (0, 2000)
        for _ in 0..<30 {
            let age = (younger + older) / 2
            if height(age) < Float(level) / 1024 { younger = age } else { older = age }
        }
        return older
    }
    static func age(standing height: Float) -> Float {
        let at = max(0, min(1023.999, height * 1024)), level = Int(at)
        return ages[level] + (ages[level + 1] - ages[level]) * (at - Float(level))
    }

    /// The stamp for a texel last left at `old`, a `share` of which is left again at `new`. Not that share of the
    /// way from one time to the other, as it was: land rises fast when it is new, so a texel a sixth of the way to
    /// old ground's age was drawn half as high as the old ground already, and a scarp above new land came out in
    /// texel-sized stairs. It is the time that leaves the texel standing as high as its two parts do between
    /// them, so that along a bank's furthest reach the height goes by how much of each texel the river covered.
    // ponytail: only the live river stamps this way. The swept past (`fill`, `strand`) still takes the share of
    // the time: its scarps are old by the first frame or soon worked over, and stamping them like this moved the
    // lines of the old map's settled scarps (a pixel in 300 of the launch picture by over 20 levels, in Fisk's
    // order). If a scarp made by the past shows in stairs beside new land, stamp those this way too.
    @inline(__always) private static func shared(_ old: Float, _ new: Float, _ share: Float) -> Float {
        max(old, new - age(standing: (1 - share) * height(new - old)))
    }

    /// Writes one texel's bytes.
    @inline(__always) private func write(_ i: Int, _ ground: UnsafeMutableBufferPointer<SIMD4<Float>>, _ pixels: UnsafeMutableBufferPointer<UInt8>) {
        let texel = ground[i], stamp = Int(max(0, min(65535, texel.x * 100)))
        pixels[i * 4] = UInt8(stamp >> 8)
        pixels[i * 4 + 1] = UInt8(stamp & 255)
        pixels[i * 4 + 2] = UInt8(max(0, min(255, 127.5 + (min(texel.z, texel.w) - 0.5) * texels / 4 * 255)))
        pixels[i * 4 + 3] = UInt8(max(0, min(255, (texel.y - 0.25) / 0.75 * 255)))
    }

    /// Takes lake `k`'s water out of the ground, leaving any other lake's that it lay over, and lists the texels it
    /// was on in `lakeBefore` for their bytes to be written.
    private func lift(_ k: Int) {
        let count = lakes[k].texels.count, box = lakes[k].box
        lakeBefore.count = count
        guard count > 0 else { return }
        ground.withUnsafeMutableBufferPointer { ground in
            lakes[k].texels.withUnsafeBufferPointer { old in lakeBefore.items.withUnsafeMutableBufferPointer { list in
                for j in 0..<count { (list[j], ground[Int(old[j])].w) = (old[j], Self.far) }
            } }
            for other in lakes.indices where other != k {
                let its = lakes[other].box
                guard its.x <= box.z, box.x <= its.z, its.y <= box.w, box.y <= its.w else { continue }
                lakes[other].texels.withUnsafeBufferPointer { at in lakes[other].distances.withUnsafeBufferPointer { distance in
                    for j in 0..<at.count { ground[Int(at[j])].w = min(ground[Int(at[j])].w, distance[j]) }
                } }
            }
        }
    }

    /// Takes lake `k` out of the ground and forgets it.
    private func drop(_ k: Int) {
        lift(k)
        ground.withUnsafeMutableBufferPointer { ground in pixels.withUnsafeMutableBufferPointer { pixels in
            for raw in lakeBefore.items[..<lakeBefore.count] { write(Int(raw), ground, pixels) }
        } }
        lakes.remove(at: k)
    }

    /// Draws lake `k` into the ground as it is now, with the river's own routine, in place of how it was last drawn.
    private func draw(_ k: Int) {
        lift(k)
        lakeTouched.count = 0
        let count = trace(lakes[k])
        if count > 1 { band(count, closed: false, reach: 2 / texels, into: &lakeTouched) }
        if count == 0 { lakes[k].born = -.infinity } // dry from end to end: `trimLakes` forgets it on the next step
        let found = lakeTouched.count, columns = Int32(columns)
        var box = SIMD4<Int32>(.max, .max, -1, -1)
        // its lists are taken out while they are written, so they aren't copied, and keep their room
        var (at, distances) = (lakes[k].texels, lakes[k].distances)
        (lakes[k].texels, lakes[k].distances) = ([], [])
        at.removeAll(keepingCapacity: true)
        at.append(contentsOf: lakeTouched.items[..<found])
        distances.removeAll(keepingCapacity: true)
        distances.append(contentsOf: repeatElement(0, count: found))
        ground.withUnsafeMutableBufferPointer { ground in scratch.withUnsafeMutableBufferPointer { scratch in pixels.withUnsafeMutableBufferPointer { pixels in
            at.withUnsafeBufferPointer { at in distances.withUnsafeMutableBufferPointer { distances in
                for j in 0..<found {
                    let raw = at[j], i = Int(raw), x = raw % columns, y = raw / columns
                    box = SIMD4(min(box.x, x), min(box.y, y), max(box.z, x), max(box.w, y))
                    distances[j] = scratch[i]
                    ground[i].w = min(ground[i].w, scratch[i])
                    scratch[i] = .infinity
                }
            } }
            for raw in lakeBefore.items[..<lakeBefore.count] { write(Int(raw), ground, pixels) }
            for raw in at { write(Int(raw), ground, pixels) }
        } } }
        (lakes[k].texels, lakes[k].distances, lakes[k].box, lakes[k].drawn) = (at, distances, box, now)
    }

    /// Keeps the lakes in the ground up to date, a few at a time: a lake changes slowly, so drawing every one on
    /// every step was most of a step's cost. A new lake, or a piece of one just parted, is drawn at once. Of the
    /// rest, the ones whose silting fronts have moved furthest since they were drawn go first, six a step at the
    /// most: a fresh lake is drawn every step, and with twenty lakes at the top of the Speed slider an old one
    /// every third or fourth, a quarter of a texel behind at the most. (Two a step was 0.2 ms cheaper, and an old
    /// lake's end then stood still for a second or two and moved at once.)
    private func drawLakes() {
        behind.removeAll(keepingCapacity: true)
        for k in lakes.indices {
            let drawn = lakes[k].drawn
            if drawn == -.infinity { draw(k) }
            let since = Float(drawn - max(lakes[k].first, lakes[k].last)) // its newer end has the faster front
            behind.append(drawn == -.infinity ? 0 : (Lake.front(since + Float(now - drawn)) - Lake.front(since)) * texels)
        }
        for _ in 0..<Self.lakesAStep {
            guard let furthest = behind.indices.max(by: { behind[$0] < behind[$1] }), behind[furthest] > Self.adrift else { break }
            draw(furthest)
            behind[furthest] = 0
        }
    }

    /// How far out the lakes' water in the ground is, at worst, from every lake drawn afresh, in widths: the check
    /// on `drawLakes`, for the tests.
    func lakesAdrift() -> Float {
        lakeTouched.count = 0
        for lake in lakes {
            let count = trace(lake)
            if count > 1 { band(count, closed: false, reach: 2 / texels, into: &lakeTouched) }
        }
        let limit = 0.5 + 1 / texels // a texel beyond the bank: further out a dry stretch still leaves its mark
        var worst: Float = 0
        for i in ground.indices {
            worst = max(worst, abs(min(scratch[i], limit) - min(ground[i].w, limit)))
            scratch[i] = .infinity
        }
        return worst
    }

    /// Brings the ground up to date with the river. Texels under the channel take the present time; one a bank is
    /// only part-way across takes its share of it (`shared`), so the furthest line a bank reached is recorded to
    /// a fraction of a texel and old scarps come out smooth, not stair-stepped. The river wipes any hollow it
    /// crosses and trims any lake.
    private func updateGround() {
        swap(&touched, &before)
        touched.count = 0
        band(trace(), closed: true, reach: 2 / texels, into: &touched)
        let tex = texels, stampNow = Float(now - base), far = Self.far, gone = beneath.isEmpty ? -.infinity : stampNow - Float(0.9 * stays)
        // Over half the river's texels are deep water, a third of a width inside the bank or more, and all alike:
        // the present time, no hollow, and bytes that are the same for every one of them
        let level = UInt32(max(0, min(65535, stampNow * 100))), deep = (level >> 8 | (level & 255) << 8 | 255 << 24).littleEndian
        ground.withUnsafeMutableBufferPointer { ground in scratch.withUnsafeMutableBufferPointer { scratch in pixels.withUnsafeMutableBufferPointer { pixels in
            for raw in before.items[..<before.count] where scratch[Int(raw)] == .infinity {
                ground[Int(raw)].z = far
                write(Int(raw), ground, pixels)
            }
            let words = UnsafeMutableRawPointer(pixels.baseAddress!)
            for raw in touched.items[..<touched.count] {
                let i = Int(raw), distance = scratch[i]
                scratch[i] = .infinity
                if distance < 1 / 3 {
                    (ground[i].x, ground[i].y, ground[i].z) = (stampNow, 2, distance)
                    words.storeBytes(of: deep, toByteOffset: i * 4, as: UInt32.self)
                    continue
                }
                let covered = max(0, min(1, 0.5 + (0.5 - distance) * tex)), was = max(0, min(1, 0.5 + (0.5 - ground[i].z) * tex))
                if covered >= 1 {
                    ground[i].x = stampNow
                } else if covered > was {
                    // (ground left so long ago that the older ground shows there is the older ground, for this)
                    ground[i].x = Self.shared(ground[i].x > gone ? ground[i].x : stampNow - olderAge(i), stampNow, (covered - was) / (1 - was))
                }
                ground[i].y = max(ground[i].y, 0.5 + 3 * (0.5 - distance))
                ground[i].z = distance
                write(i, ground, pixels)
            }
        } } }
        trimLakes { texel, _ in ground[texel].z < 0.5 ? now : nil }
        drawLakes()
        // a little after a move is due: by then `forget` has been round every row since
        if now - base > Self.memory + 5 + Self.turn + Self.slack { rebase() }
        forget()
    }

    /// How far the stamps' base moves at a time, in T: sixteen turns of a stamp's high byte (a turn is 256 of the
    /// bytes' levels, 2.56 T), which is as far as 16 bits leave room for beyond the ground's memory. At speed 1
    /// that is once in eight and a half minutes.
    static let turn = 16 * 2.56
    /// How long after a move is due the base waits, in T: `forget` sees to every row in fifty steps, 0.8 T of the
    /// longest, and no stamp may be under the move when it comes.
    static let slack = 1.0

    /// The oldest stamp there is now: `memory` and a little back. Ground the river left before then, or never
    /// reached, is kept at it, so such ground is all of one age and stays that age. Each step brings a fiftieth of
    /// the rows up to it (or all of them, with `everyRow`), so a texel is seen to every fifty steps, and its
    /// stamp rises by 0.8 T at most: where old ground meets ground with a past that is under a thousandth of the
    /// way from one colour to the other, and inside old ground a shader takes anything this old as the same.
    private func forget(everyRow: Bool = false) {
        let oldest = Float(now - base - Self.memory - 5), level = Int(oldest * 100)
        guard level > 0 else { return }
        let from = everyRow ? 0 : forgetting, to = everyRow ? rows : min(from + (rows + 49) / 50, rows), columns = columns
        ground.withUnsafeMutableBufferPointer { ground in pixels.withUnsafeMutableBufferPointer { pixels in
            for i in from * columns..<to * columns where ground[i].x < oldest {
                (ground[i].x, pixels[i * 4], pixels[i * 4 + 1]) = (oldest, UInt8(level >> 8), UInt8(level & 255))
            }
        } }
        if !everyRow { forgetting = to == rows ? 0 : to }
    }

    /// The stamps are counted from `base`, which moves up with the time so that 16 bits at 0.01 T a level always
    /// hold the ground's memory. A move takes every stamp down by the same amount, whole turns of the high byte,
    /// off the bytes themselves and nothing else: the low bytes stay, and neighbouring texels' high bytes differ
    /// as they did, so the GPU's smoothing between texels gives what it gave, less the move. (Moved by any other
    /// amount, the two bytes of neighbouring texels carry differently, and a sixth of relief's pixels shifted by a
    /// level or more: measured.) No stamp is under the move when it comes: `forget` has brought the oldest up by
    /// then. A shader has to work in ages, and take its cycles from the time itself, not from the stamps.
    func rebase() {
        let moves = Int((now - base - Self.memory - 5) / Self.turn), turns = moves * 16, shift = Float(Self.turn * Double(moves))
        guard moves > 0 else { return }
        base += Self.turn * Double(moves)
        ground.withUnsafeMutableBufferPointer { ground in pixels.withUnsafeMutableBufferPointer { pixels in
            for i in ground.indices {
                ground[i].x = ground[i].x == Self.never ? Self.never : max(ground[i].x - shift, 0)
                if Int(pixels[i * 4]) >= turns { pixels[i * 4] -= UInt8(turns) } else { (pixels[i * 4], pixels[i * 4 + 1]) = (0, 0) }
            }
        } }
    }

    /// A cut-off loop becomes a lake: its own nodes and half-widths, drawn from then on like the river, so on the
    /// cutoff frame the water is the same water. Its footprint is kept in the ground as a hollow. `stamping` is for
    /// a past being made by `sweep`, which only stamps ground the river moves off: the loop's texels take the time here.
    private func strand(_ loop: [SIMD3<Float>], lake: Bool = true, stamping: Bool = false) {
        path.removeAll(keepingCapacity: true)
        path.append(contentsOf: loop)
        lakeBefore.count = 0 // a list to hand: the lakes' last one is only read while they are being drawn
        band(loop.count, closed: false, reach: 0.3, into: &lakeBefore) // as far out as a hollow shows, and the read's two texels
        ground.withUnsafeMutableBufferPointer { ground in scratch.withUnsafeMutableBufferPointer { scratch in pixels.withUnsafeMutableBufferPointer { pixels in
            for raw in lakeBefore.items[..<lakeBefore.count] {
                let i = Int(raw)
                if stamping { // out to a texel beyond its banks, less the further out, as `fill` stamps a soft edge
                    let cover = 1 - (scratch[i] - 0.5) * texels, stamp = Float(now - base), old = max(ground[i].x, stamp - 400)
                    if cover > 0 { ground[i].x = old + (stamp - old) * min(cover, 1) }
                }
                ground[i].y = min(ground[i].y, scratch[i])
                scratch[i] = .infinity
                write(i, ground, pixels)
            }
        } } }
        if lake { lakes.append(Lake(nodes: loop, born: now, first: now, last: now)) }
    }

    // MARK: Running it

    /// One live step: move, cut through any neck that has closed, respace, and bring the ground up to date.
    private func step(_ eps: Float) {
        migrate(eps)
        while let neck = neck() { strand(cut(neck.lo, neck.hi, breach: true)) }
        respace()
        updateGround()
    }

    /// Seconds to a T at speed 1. (It was 25 until Dave's own screen was thought of: he found the Black Hole's first
    /// pace far too slow, and at 25 a glance at this river showed nothing moving.)
    public static let pace = 12.5
    /// The longest step, in T: at speeds 2 and 4. It moves the fastest bank a fiftieth of a width, a little over a
    /// pixel of the narrowest river on a 2x screen, and most banks a tenth of that.
    static let longest = 0.016

    /// Moves the river on by `seconds` of wallpaper time. It steps ten times a second, and twenty above speed 2 so
    /// that a step is never longer than `longest`; the steps are counted from the time gone by, so the river is
    /// the same whatever the frame rate. Returns whether it stepped: only then have `pixels` changed. `afterEach`
    /// is called after every step, for a caller that wants each step's ground and not only the last.
    @discardableResult public func advance(_ seconds: Double, speed: Double = 1, afterEach: () -> Void = {}) -> Bool {
        let rate = speed > 2 ? 20.0 : 10.0
        owed += seconds * rate
        var stepped = false
        while owed >= 1 - 1e-6 {
            owed -= 1
            step(Float(speed / Self.pace / rate))
            afterEach()
            stepped = true
        }
        return stepped
    }

    /// How long the older river runs, in T, and how old the last ground it left is: old enough that its courses
    /// are fainter than this river's own and no lighter than the oldest of them at the belt's edge, and young
    /// enough still to show. (At 40 T they were as bold as the belt's, with the belt's dark margin between; at
    /// 140, hard to see.)
    static let before = 140.0, settled = 90.0
    /// Where the older river never went, the ground is an older course still (`layBackdrop`): this much older
    /// than the course it is taken from, in T.
    static let older = 80.0
    /// How old the oldest of the older ground is, which is what neither course reached: a little older than
    /// anything they left, so that it lies among them as one more of them and not as a hole. (And half-way
    /// between two whole numbers of the old map's stages, 5 T and 11 T: flat ground of one age, on the line
    /// between two inks, came out in specks of both.)
    public static let ancient = settled + before + older + 47.5
    /// How far the older river's first line swings, as a share of the way from the valley's middle to its wall.
    static let swing: Float = 0.75

    /// Lays the older ground, `beneath`: what an older river left, so that the picture is floodplain to every
    /// edge from its first frame and stays so, with old courses, paler than this river's own, wherever this
    /// river's ground doesn't show. The older river is another `River`, with another seed and walls 4 widths past
    /// the top and bottom, started on a wide swing and run the cheap way for `before` T on a ground of half as
    /// many texels each way; its stamps are spread over this ground's texels smoothly (they are old, and soft does
    /// for them). Where it never went, in a corner or two, the ground is its own from half the screen along,
    /// turned top to bottom and `older` T older: an older course still. (Or, where it never went there either,
    /// as across the top and bottom of a tall screen, its own from half the screen up or down.) The little that
    /// none of those reached has an age too, `ancient`, so nothing in the picture is ground no river has made.
    /// The ages are not counted from any clock, so nothing ages them: a shader draws this ground the same for as
    /// long as the river runs.
    // ponytail: the corners are the same river's ground used twice, not a third river's, which would cost its
    // 30 ms at every launch. If a corner is ever recognised in the ground across from it, run one.
    private func layBackdrop() {
        let old = River(seed: seed &* 0x9E3779B97F4A7C15 &+ 0xD1B54A32D192ED03, across: across, up: up, texels: texels / 2, spacing: spacing, valley: valley, backdrop: true)
        // An older river's stamp s is ground `settled + before - s - old.base` T old. Its ground starts `older`
        // T short of `ancient`, not at nothing, so that its soft scarps shade into that and not into ground 400 T
        // older than they are, which would be a rim of the oldest ground round everything it never reached.
        let unreached = Float(Self.settled + Self.before - Self.ancient + Self.older - old.base), wide = old.columns, high = old.rows
        old.ground = Array(repeating: [unreached, 1, Self.far, Self.far], count: wide * high)
        old.age(distant: Self.before, recent: 0)
        var stamps = old.ground.map(\.x)
        for row in 0..<high { for column in 0..<wide where stamps[row * wide + column] == unreached {
            let other = old.ground[(high - 1 - row) * wide + (column + wide / 2) % wide].x, middle = old.ground[(row + high / 2) % high * wide + column].x
            stamps[row * wide + column] = (other != unreached ? other : middle) - Float(Self.older)
        } }
        beneath = Array(repeating: 255, count: columns * rows * 4)
        let oldest = unreached - Float(Self.older)
        stamps.withUnsafeBufferPointer { theirs in beneath.withUnsafeMutableBufferPointer { bytes in
            @inline(__always) func stamp(_ column: Int, _ row: Int) -> Float {
                theirs[min(max(row, 0), high - 1) * wide + min(max(column, 0), wide - 1)] - oldest
            }
            for row in 0..<rows {
                let v = (Float(row) + 0.5) * Float(high) / Float(rows) - 0.5, r = Int(v.rounded(.down)), fy = v - Float(r)
                for column in 0..<columns {
                    let u = (Float(column) + 0.5) * Float(wide) / Float(columns) - 0.5, c = Int(u.rounded(.down)), fx = u - Float(c)
                    let since = (stamp(c, r) * (1 - fx) + stamp(c + 1, r) * fx) * (1 - fy) + (stamp(c, r + 1) * (1 - fx) + stamp(c + 1, r + 1) * fx) * fy
                    let level = Int(max(0, min(65535, since * 100))), i = (row * columns + column) * 4
                    (bytes[i], bytes[i + 1]) = (UInt8(level >> 8), UInt8(level & 255))
                }
            }
        } }
    }

    /// Gives a new river a past, so the first frame is of a floodplain it has been working for an hour (300 T, at
    /// speed 1). The distant past is run cheaply: nodes a width apart and steps three times the coarse one. It's a
    /// busier river than the live one (it cuts off about three times as often), but what it leaves is old and pale.
    /// Then the recent past as the live river runs, in coarse steps. Necks are looked for and nodes respaced every
    /// other step, and the ground is kept by `sweep`, which stamps it as the river leaves it. (Bringing the ground
    /// up to date the live river's way every 12th step of the recent past was tried in its place: it took 160 ms
    /// where this takes 100, and left the bars in terraces, one to a visit, where they should be smooth.)
    public func age(distant: Double = 240, recent: Double = 60) {
        let end = now + distant + recent
        pastEnds = end
        if !backdrop { layBackdrop() }
        if distant > 0 {
            let fresh = spacing
            spacing = 1
            respace()
            markBanks()
            sweeping = true // from here a node `respace` drops has banks remembered, to sweep from
            for k in 1...Int(distant / 0.12) {
                migrate(0.12)
                while k % 2 == 0, let neck = neck() {
                    sweep(loop: neck.lo + nodes.count - 1..<neck.hi + nodes.count + 1)
                    path.removeAll(keepingCapacity: true)
                    path.append(contentsOf: cut(neck.lo, neck.hi))
                    fillRibbon(path.count, closed: false, hollow: end - now < 200) // an older hollow has faded by the end
                    markNeck()
                }
                if k % 2 == 0 { respace() }
                if k % 8 == 0 { sweep() }
            }
            spacing = fresh
            respace()
        } else {
            markBanks()
            sweeping = true
        }
        let steps = Int(recent / 0.04)
        for k in 1...max(steps, 1) where steps > 0 {
            migrate(0.04)
            while k % 2 == 0, let neck = neck() { // an older lake is dry by the end
                sweep(loop: neck.lo + nodes.count - 1..<neck.hi + nodes.count + 1)
                strand(cut(neck.lo, neck.hi), lake: Double(steps - k) * 0.04 < lakeLife, stamping: true)
                markNeck()
            }
            if k % 2 == 0 { respace() }
            if k % 12 == 0 { sweep() }
        }
        sweep()
        closeCracks()
        fillPockets()
        closeCracks() // the crumbs a pocket leaves where it was only part filled
        if backdrop { // only its stamps are wanted, with its last channel one more old course
            path.removeAll(keepingCapacity: true)
            for node in nodes { path.append([node.x, node.y, node.half]) }
            return fillRibbon(path.count, closed: true)
        }
        // the river's ribbon takes the present time, less half a texel at each bank, which leaves out every
        // texel with land in it: `trimLakes` reads those stamps, and `updateGround` sees to the banks
        path.removeAll(keepingCapacity: true)
        for node in nodes { path.append([node.x, node.y, node.half - 0.5 / texels]) }
        fillRibbon(path.count, closed: true, soft: false)
        joinBars()
        // where the river has been since a lake was born, the lake is gone, and its end there has been silting up since
        trimLakes(gone: true) { texel, lake in ground[texel].x > Float(lake.born - base) + 0.05 ? Double(ground[texel].x) + base : nil }
        sweeping = false
        updateGround()
        ground.withUnsafeMutableBufferPointer { ground in pixels.withUnsafeMutableBufferPointer { pixels in
            for i in ground.indices { write(i, ground, pixels) }
        } }
        forget(everyRow: true)
    }

    /// The river's length over the valley's.
    public var sinuosity: Float {
        nodes.indices.reduce(0) { sum, i in
            let q = (i + 1) % nodes.count
            return sum + hypot(nodes[q].x + (q == 0 ? period : 0) - nodes[i].x, nodes[q].y - nodes[i].y)
        } / period
    }
}
