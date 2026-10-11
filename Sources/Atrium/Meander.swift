import Foundation
import simd

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
final class River {
    /// A list of texels, as indexes into the ground. Room for every texel, so the loop that fills it never has to
    /// grow it.
    private struct Texels {
        var items: [Int32], count = 0
        init(room: Int) { items = Array(repeating: 0, count: room) }
    }

    /// A node of the centreline: where it is and half the channel's width there. The rest is one step's working:
    /// the curvature at the node, the right-hand normal, and its part in the upstream average.
    struct Node {
        var x: Float, y: Float, half: Float
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
    struct Lake {
        var nodes: [SIMD3<Float>]
        var born: Double, first: Double, last: Double
    }

    /// Howard & Knutson's Ω and Γ, and α in widths: the fastest-growing bend is 8.24/α long, 11.3 widths.
    static let local: Float = -1, upstream: Float = 2.5, alpha: Float = 0.73
    /// No bank moves faster than this, in widths a T: it bounds the motion at a cutoff's kink.
    static let fastest: Float = 1.25
    /// Two stretches cut through when their centrelines are within this times their half-widths: banks touching.
    static let touching: Float = 1.04
    /// Valley out of sight beyond each end of the screen, in widths.
    static let margin: Float = 10
    /// A lake's life, and how long the ground remembers the river, in T.
    static let lakeLife = 16.0, memory = 600.0
    /// A stamp for ground the river has never covered.
    static let never: Float = -1e9

    /// The screen in widths, and texels a width.
    let across: Float, up: Float, texels: Float
    /// The ground's grid.
    let columns: Int, rows: Int
    var period: Float { across + 2 * Self.margin }

    private(set) var nodes: [Node] = []
    private(set) var lakes: [Lake] = []
    /// The time in T, and what the stamps count from (see `rebase`).
    private(set) var now = 0.0, base = 0.0
    private(set) var cutoffs = 0
    /// Nodes are kept 0.6 to 1.4 times this far apart.
    private var spacing: Float

    /// Per texel: the stamp (T since `base`), the hollow, the live channel's bank distance and the lakes'.
    private(set) var ground: [SIMD4<Float>]
    /// Four bytes a texel for a shader: the stamp in 16 bits at 0.01 T a level, then the water (the live channel or
    /// a lake, whichever is nearer; its bank at mid-range, two texels either side filling the byte), then the hollow
    /// over 0.25 to 1.
    private(set) var pixels: [UInt8]

    /// A bank distance for texels nowhere near a channel.
    private static let far: Float = 9
    private var spare: [Node] = []
    private var path: [SIMD3<Float>] = [], banks: [SIMD4<Float>] = [], arcs: [Float] = [], under: [Double] = []
    private var scratch: [Float]
    private var touched: Texels, before: Texels, lakeTouched: Texels, lakeBefore: Texels
    private var erosion: [Float] = [], erosionColumns = 0, erosionRows = 0, erosionCell: Float = 8
    private var walls: [Float] = []
    private var head: [Int32] = [], next: [Int32] = [], cell: [Int32] = []
    private var owed = 0.0
    /// When `sweep` last ran, as a stamp.
    private var sweptAt: Float = 0

    /// A straight river with small wiggles, from which the bends grow, and the ground it will write on.
    init(seed: UInt64, across: Float, up: Float, texels: Float, spacing: Float = 0.5) {
        (self.across, self.up, self.texels, self.spacing) = (across, up, texels, spacing)
        columns = Int((across * texels).rounded())
        rows = Int((up * texels).rounded())
        ground = Array(repeating: [Self.never, 1, Self.far, Self.far], count: columns * rows)
        scratch = Array(repeating: .infinity, count: columns * rows)
        pixels = Array(repeating: 255, count: columns * rows * 4)
        (touched, before, lakeTouched, lakeBefore) = (Texels(room: columns * rows), Texels(room: columns * rows), Texels(room: columns * rows), Texels(room: columns * rows))
        var rng = SplitMix(state: seed)
        func unit() -> Float { Float.random(in: 0..<1, using: &rng) }
        func normal() -> Float { (unit() + unit() + unit() + unit() - 2) * 1.732 } // near enough a bell curve

        let L = period, count = Int((L / spacing).rounded())
        let waves = (1..<40).map { k in (size: normal() * 0.25 / Float(k).squareRoot(), phase: unit() * 2 * .pi, k: Float(k)) }
        nodes.reserveCapacity(2048)
        spare.reserveCapacity(2048)
        for i in 0..<count {
            let along = Float(i) / Float(count)
            nodes.append(Node(x: -Self.margin + L * along, y: waves.reduce(up / 2) { $0 + $1.size * sin(2 * .pi * $1.k * along + $1.phase) }, half: 0.5))
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
        let n = nodes.count, L = period, middle = up / 2, cap = Self.fastest * eps, ease = 1 - exp(-eps / 1.5)
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
                    soft *= smoothstep(0, 5, middle - 1.5 - standsIn - abs(bankY - middle))
                }
                p[i].half += (0.5 * (0.7 + 0.8 * min(bend / 2.8, 1)) - p[i].half) * ease // bend is seven nodes' curvature
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
                        i += 1
                    }
                    i += 1
                }
                return true
            }
            guard changed else { break }
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
    /// later, and its closing segment is then the way through the neck.
    private func cut(_ lo: Int, _ hi: Int) -> [SIMD3<Float>] {
        let n = nodes.count, L = period
        let loop = (lo...hi).map { SIMD3(nodes[$0 % n].x + Float($0 / n) * L, nodes[$0 % n].y, nodes[$0 % n].half) }
        spare.removeAll(keepingCapacity: true)
        for k in hi...(lo + n) {
            var node = nodes[k % n]
            node.slide(Float(k / n) * L - (hi >= n ? L : 0))
            spare.append(node)
        }
        swap(&nodes, &spare)
        cutoffs += 1
        return loop
    }

    // MARK: The ground

    /// Leaves in `scratch` each texel's bank distance to the channel in `path`, for texels out to `reach` beyond its
    /// banks, and adds them to `list`. Each segment is bowed to pass through the middle of the cubic through its
    /// neighbours, so banks aren't faceted, and its width runs evenly from one node's to the next's. A segment
    /// visits only the slab of texels beside itself and a little past each end, enough to close the gap at the
    /// joint; a sharp joint or an open end gets its own disc. It runs its inner loop across itself, along whichever
    /// of the grid's axes is nearer to that, where the bank distance changes by the same amount from texel to texel.
    /// Each segment is drawn in the period that puts it on screen. A stretch with no width (a dry lake) draws nothing.
    // ponytail: where two stretches of different width meet, at a fresh cutoff, this is up to 0.05 to 0.09 widths
    // off checking every segment against every texel (measured in the prototype's sketch), until the widths ease
    // together (about 1.5 T). The exhaustive version costs twice; use it if that step in the bank ever shows.
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
                if (!closed && i == 0) || turnIn < 0.96 { // an end, or a turn of over 16 degrees: a disc round the node
                    let wide = a.z + reach
                    let x0 = max(Int(((ax - wide) * tex).rounded(.down)), 0), x1 = min(Int(((ax + wide) * tex).rounded(.up)), columns - 1)
                    let y0 = max(Int(((ay - wide) * tex).rounded(.down)), 0), y1 = min(Int(((ay + wide) * tex).rounded(.up)), rows - 1)
                    if x0 <= x1, y0 <= y1 {
                        for ty in y0...y1 {
                            let gy = (Float(ty) + 0.5) / tex - ay
                            for tx in x0...x1 {
                                let gx = (Float(tx) + 0.5) / tex - ax, distance = (gx * gx + gy * gy).squareRoot() - a.z + 0.5, at = ty * columns + tx
                                if distance < limit, distance < scratch[at] {
                                    if scratch[at] == .infinity { (items[found], found) = (Int32(at), found + 1) }
                                    scratch[at] = distance
                                }
                            }
                        }
                    }
                }
                // past each end by the gap its joint leaves on the outside of the turn, and half a texel
                let turn = min(max(min(turnIn, turnOut), 0.9), 1), past = (out * ((1 - turn) / (1 + turn)).squareRoot() + 0.5 / tex) / length
                // The inner loop runs down columns if the segment is nearer level, along rows if it is nearer upright
                let upright = abs(ey) > abs(ex), outerEnd = upright ? rows - 1 : columns - 1, innerEnd = upright ? columns - 1 : rows - 1
                let (o, t) = upright ? (ay, ax) : (ax, ay), (eo, et) = upright ? (ey, ex) : (ex, ey) // the outer and the inner axis
                let reachO = abs(eo) * past + out * abs(et) / length
                let o0 = max(Int(((min(o, o + eo) - reachO) * tex).rounded(.down)), 0), o1 = min(Int(((max(o, o + eo) + reachO) * tex).rounded(.up)), outerEnd)
                guard o0 <= o1 else { continue }
                // along the segment (0 to 1) and off it to the right, at inner texel 0 of each outer line, and their steps
                let shareStep = et / length2 / tex, offStep = (upright ? ey : -ex) / length / tex, stride = upright ? 1 : columns, rise = b.z - a.z
                for outer in o0...o1 {
                    let go = (Float(outer) + 0.5) / tex - o, gt = 0.5 / tex - t
                    let share0 = (go * eo + gt * et) / length2, off0 = upright ? (gt * ey - go * ex) / length : (go * ey - gt * ex) / length
                    var u = (-out - off0) / offStep, v = (out - off0) / offStep
                    var (from, to) = (min(u, v), max(u, v))
                    if abs(shareStep) > 1e-9 {
                        (u, v) = ((-past - share0) / shareStep, (1 + past - share0) / shareStep)
                        (from, to) = (max(from, min(u, v)), min(to, max(u, v)))
                    } else if share0 < -past || share0 > 1 + past { continue }
                    let first = max(Int(from.rounded(.up)), 0), final = min(Int(to.rounded(.down)), innerEnd)
                    guard first <= final else { continue }
                    var share = share0 + shareStep * Float(first), off = off0 + offStep * Float(first)
                    var at = upright ? outer * columns + first : first * columns + outer
                    for _ in first...final {
                        let distance: Float
                        if share < 0 {
                            distance = (off * off + share * share * length2).squareRoot() - a.z + 0.5
                        } else if share > 1 {
                            distance = (off * off + (share - 1) * (share - 1) * length2).squareRoot() - b.z + 0.5
                        } else {
                            distance = abs(off - 4 * share * (1 - share) * bow) - (a.z + share * rise) + 0.5
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
    /// times in between. Whole texels, nothing finer, and drawn in the period that puts it on screen: the cheap way
    /// to mark the ground, for a past nobody watched.
    private func fill(_ a: SIMD2<Float>, _ b: SIMD2<Float>, _ c: SIMD2<Float>, _ d: SIMD2<Float>, from: Float, to: Float, hollow: Bool = false,
                      _ ground: UnsafeMutableBufferPointer<SIMD4<Float>>) {
        let tex = texels, L = period
        let top = min(a.y, b.y, c.y, d.y), bottom = max(a.y, b.y, c.y, d.y)
        let y0 = max(Int((top * tex - 0.5).rounded(.up)), 0), y1 = min(Int((bottom * tex - 0.5).rounded(.down)), rows - 1)
        guard y0 <= y1 else { return }
        let middle = 0.25 * (a.x + b.x + c.x + d.x) + Self.margin, shift = -(middle / L).rounded(.down) * L
        // How far a point is from the first edge's line and from the third's, each a slope in x and in y
        let first = simd_normalize(SIMD2(a.y - b.y, b.x - a.x) + [1e-12, 0]), third = simd_normalize(SIMD2(c.y - d.y, d.x - c.x) + [1e-12, 0])
        for ty in y0...y1 {
            let y = (Float(ty) + 0.5) / tex
            let edges = (crossing(a, b, y), crossing(b, c, y), crossing(c, d, y), crossing(d, a, y)) // not numbers where the row misses an edge
            let left = Float.minimum(Float.minimum(edges.0, edges.1), Float.minimum(edges.2, edges.3))
            let right = Float.maximum(Float.maximum(edges.0, edges.1), Float.maximum(edges.2, edges.3))
            guard left <= right else { continue }
            let x0 = max(Int(((left + shift) * tex - 0.5).rounded(.up)), 0), x1 = min(Int(((right + shift) * tex - 0.5).rounded(.down)), columns - 1)
            guard x0 <= x1 else { continue }
            let x = (Float(x0) + 0.5) / tex - shift
            var fromFirst = (x - a.x) * first.x + (y - a.y) * first.y, fromThird = (x - c.x) * third.x + (y - c.y) * third.y
            for i in ty * columns + x0...ty * columns + x1 {
                let share = from == to ? 0 : abs(fromFirst) / (abs(fromFirst) + abs(fromThird) + 1e-9)
                (ground[i].x, ground[i].y) = (from + (to - from) * share, hollow ? min(ground[i].y, 0.3) : 1)
                (fromFirst, fromThird) = (fromFirst + first.x / tex, fromThird + third.x / tex)
            }
        }
    }

    /// Remembers where each node's banks are, for the next `sweep` to measure from.
    private func markBanks() {
        bankLines(trace(), closed: true)
        for i in nodes.indices { (nodes[i].right, nodes[i].left) = (banks[i].lowHalf, banks[i].highHalf) }
        sweptAt = Float(now - base)
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
    /// `hollow`: for a loop cut off in the distant past.
    private func fillRibbon(_ count: Int, closed: Bool, hollow: Bool = false) {
        bankLines(count, closed: closed)
        ground.withUnsafeMutableBufferPointer { ground in
            for i in 0..<(closed ? count : count - 1) {
                let q = (i + 1) % count, wrap = SIMD2<Float>(closed && i == count - 1 ? period : 0, 0)
                fill(banks[i].lowHalf, banks[q].lowHalf + wrap, banks[q].highHalf + wrap, banks[i].highHalf, from: Float(now - base), to: Float(now - base), hollow: hollow, ground)
            }
        }
    }

    /// Puts the live river's nodes in `path`.
    private func trace() -> Int {
        path.removeAll(keepingCapacity: true)
        for node in nodes { path.append([node.x, node.y, node.half]) }
        return path.count
    }

    /// Puts a lake's nodes in `path` at their widths now. Each end silts up behind a front that moves in from it,
    /// 1.2 widths in the first T or so and then a quarter of a width a T, the water tapering to nothing over the 2
    /// widths ahead of the front; and over the second half of its life the whole lake narrows to nothing. A dry
    /// stretch gets a negative width, so nothing is drawn. Returns how many nodes, or 0 if the lake is all dry.
    private func trace(_ lake: Lake) -> Int {
        arcs.removeAll(keepingCapacity: true)
        path.removeAll(keepingCapacity: true)
        var arc: Float = 0, wet = false
        for (i, node) in lake.nodes.enumerated() {
            if i > 0 { arc += hypot(node.x - lake.nodes[i - 1].x, node.y - lake.nodes[i - 1].y) }
            arcs.append(arc)
        }
        func silted(_ from: Float, _ since: Double) -> Float {
            let age = Float(now - since)
            return smoothstep(0, 1, (from - 3.2 * (1 - exp(-age / 0.6)) - 0.25 * age) / 2 + 1)
        }
        let body = 1 - smoothstep(Float(0.5 * Self.lakeLife), Float(Self.lakeLife), Float(now - lake.born))
        for (i, node) in lake.nodes.enumerated() {
            let share = body * silted(arcs[i], lake.first) * silted(arc - arcs[i], lake.last)
            path.append([node.x, node.y, node.z * share - 0.15 * (1 - share)])
            wet = wet || share > 0
        }
        return wet ? path.count : 0
    }

    /// Drops the lake nodes the river has covered: `covered` says when it covered a texel of a lake's, or nil. A lake
    /// then ends at the outermost node the river covered, so its water runs into the river's and no end shows; a
    /// lake the river cuts through becomes two. A new end starts silting up from when it was covered, which for the
    /// live river is now, so nothing vanishes on the frame it is made. Worn-out lakes are forgotten.
    private func trimLakes(covered: (Int, Lake) -> Double?) {
        let L = period
        var at = 0
        while at < lakes.count {
            let lake = lakes[at], n = lake.nodes.count
            if now - lake.born > Self.lakeLife {
                lakes.remove(at: at)
                continue
            }
            under.removeAll(keepingCapacity: true)
            for node in lake.nodes {
                var along = (node.x + Self.margin) / L
                along -= along.rounded(.down)
                let tx = Int(((along * L - Self.margin) * texels).rounded(.down)), ty = Int((node.y * texels).rounded(.down))
                under.append(tx >= 0 && tx < columns && ty >= 0 && ty < rows ? covered(ty * columns + tx, lake) ?? .nan : .nan)
            }
            guard under.contains(where: { !$0.isNaN }) else {
                at += 1
                continue
            }
            lakes.remove(at: at)
            var i = 0
            while i < n { // each run of nodes not under the river, with the covered node beside it kept at either end
                guard under[i].isNaN else {
                    i += 1
                    continue
                }
                var j = i
                while j + 1 < n, under[j + 1].isNaN { j += 1 }
                let lo = max(i - 1, 0), hi = min(j + 1, n - 1)
                if hi > lo {
                    lakes.insert(Lake(nodes: Array(lake.nodes[lo...hi]), born: lake.born, first: lo == 0 ? lake.first : under[lo],
                                      last: hi == n - 1 ? lake.last : under[hi]), at: at)
                    at += 1
                }
                i = j + 1
            }
        }
    }

    /// Writes one texel's bytes.
    @inline(__always) private func write(_ i: Int, _ ground: UnsafeMutableBufferPointer<SIMD4<Float>>, _ pixels: UnsafeMutableBufferPointer<UInt8>) {
        let texel = ground[i], stamp = Int(max(0, min(65535, texel.x * 100)))
        pixels[i * 4] = UInt8(stamp >> 8)
        pixels[i * 4 + 1] = UInt8(stamp & 255)
        pixels[i * 4 + 2] = UInt8(max(0, min(255, 127.5 + (min(texel.z, texel.w) - 0.5) * texels / 4 * 255)))
        pixels[i * 4 + 3] = UInt8(max(0, min(255, (texel.y - 0.25) / 0.75 * 255)))
    }

    /// Redraws every lake into the ground with the river's own routine.
    private func drawLakes() {
        swap(&lakeTouched, &lakeBefore)
        lakeTouched.count = 0
        ground.withUnsafeMutableBufferPointer { ground in for raw in lakeBefore.items[..<lakeBefore.count] { ground[Int(raw)].w = Self.far } }
        for lake in lakes {
            let count = trace(lake)
            if count > 1 { band(count, closed: false, reach: 2 / texels, into: &lakeTouched) }
        }
        ground.withUnsafeMutableBufferPointer { ground in scratch.withUnsafeMutableBufferPointer { scratch in pixels.withUnsafeMutableBufferPointer { pixels in
            for raw in lakeTouched.items[..<lakeTouched.count] {
                ground[Int(raw)].w = scratch[Int(raw)]
                scratch[Int(raw)] = .infinity
            }
            for raw in lakeBefore.items[..<lakeBefore.count] { write(Int(raw), ground, pixels) }
            for raw in lakeTouched.items[..<lakeTouched.count] { write(Int(raw), ground, pixels) }
        } } }
    }

    /// Brings the ground up to date with the river. Texels under the channel take the present time; one a bank is
    /// only part-way across takes that share of the way to it, so the furthest line a bank reached is recorded to
    /// a fraction of a texel and old scarps come out smooth, not stair-stepped. The river wipes any hollow it
    /// crosses and trims any lake. `drawing` is false while a history is being made and nobody is looking: then
    /// the band is only as wide as the stamps need, and no bytes are written.
    private func updateGround(drawing: Bool = true) {
        swap(&touched, &before)
        touched.count = 0
        band(trace(), closed: true, reach: (drawing ? 2 : 0.5) / texels, into: &touched)
        let tex = texels, stampNow = Float(now - base), far = Self.far
        ground.withUnsafeMutableBufferPointer { ground in scratch.withUnsafeMutableBufferPointer { scratch in pixels.withUnsafeMutableBufferPointer { pixels in
            for raw in before.items[..<before.count] where scratch[Int(raw)] == .infinity {
                ground[Int(raw)].z = far
                if drawing { write(Int(raw), ground, pixels) }
            }
            for raw in touched.items[..<touched.count] {
                let i = Int(raw), distance = scratch[i]
                let covered = max(0, min(1, 0.5 + (0.5 - distance) * tex)), was = max(0, min(1, 0.5 + (0.5 - ground[i].z) * tex))
                if covered >= 1 {
                    ground[i].x = stampNow
                } else if covered > was {
                    let old = max(ground[i].x, stampNow - 400)
                    ground[i].x = old + (stampNow - old) * (covered - was) / (1 - was)
                }
                ground[i].y = max(ground[i].y, 0.5 + 3 * (0.5 - distance))
                ground[i].z = distance
                scratch[i] = .infinity
                if drawing { write(i, ground, pixels) }
            }
        } } }
        trimLakes { texel, _ in ground[texel].z < 0.5 ? now : nil }
        if drawing { drawLakes() }
        if now - base > 650 { rebase() }
    }

    /// The stamps are counted from `base`, and 16 bits at 0.01 T a level hold 655 T of them. So before they run
    /// out the base moves up and every stamp down by the same amount, older ones than the ground remembers
    /// stopping at none. A shader that draws anything periodic in the stamp has to be told the base.
    private func rebase() {
        let shift = Float(now - base - Self.memory - 5)
        base += Double(shift)
        ground.withUnsafeMutableBufferPointer { ground in pixels.withUnsafeMutableBufferPointer { pixels in
            for i in ground.indices {
                ground[i].x = ground[i].x == Self.never ? Self.never : max(ground[i].x - shift, 0)
                write(i, ground, pixels)
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
                if stamping, scratch[i] < 0.5 + 1 / texels { ground[i].x = Float(now - base) } // and a texel beyond, as at the end of `age`
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
        while let neck = neck() { strand(cut(neck.lo, neck.hi)) }
        respace()
        updateGround()
    }

    /// Moves the river on by `seconds` of wallpaper time. At speed 1 a T takes 25 seconds. It steps ten times a
    /// second (twenty above speed 2, so a step stays under a pixel), counted from the time gone by, so the river is
    /// the same whatever the frame rate. Returns whether it stepped: only then have `pixels` changed.
    @discardableResult func advance(_ seconds: Double, speed: Double = 1) -> Bool {
        let rate = speed > 2 ? 20.0 : 10.0
        owed += seconds * rate
        var stepped = false
        while owed >= 1 - 1e-6 {
            owed -= 1
            step(Float(speed / 25 / rate))
            stepped = true
        }
        return stepped
    }

    /// Gives a new river a past, so the first frame is of a floodplain it has been working for two hours (300 T, at
    /// speed 1). The distant past is run cheaply: nodes a width apart and steps three times the coarse one. It's a
    /// busier river than the live one (it cuts off about three times as often), but what it leaves is old and pale.
    /// Then the recent past as the live river runs, in coarse steps. Necks are looked for and nodes respaced every
    /// other step. The ground is kept by `sweep`; or, with `exactEvery`, the recent past's by `updateGround` every
    /// so many steps, which is smoother at the scarps and costs half as much again.
    func age(distant: Double = 240, recent: Double = 60, exactEvery: Int = 0) {
        let end = now + distant + recent
        if distant > 0 {
            let fresh = spacing
            spacing = 1
            respace()
            markBanks()
            for k in 1...Int(distant / 0.12) {
                migrate(0.12)
                while k % 2 == 0, let neck = neck() {
                    sweep(loop: neck.lo..<neck.hi)
                    path.removeAll(keepingCapacity: true)
                    path.append(contentsOf: cut(neck.lo, neck.hi))
                    fillRibbon(path.count, closed: false, hollow: end - now < 200) // an older hollow has faded by the end
                }
                if k % 2 == 0 { respace() }
                if k % 8 == 0 { sweep() }
            }
            spacing = fresh
            respace()
        } else {
            markBanks()
        }
        let steps = Int(recent / 0.04)
        if exactEvery > 0 { updateGround(drawing: false) }
        for k in 1...max(steps, 1) where steps > 0 {
            migrate(0.04)
            while k % 2 == 0, let neck = neck() { // an older lake is dry by the end
                if exactEvery == 0 { sweep(loop: neck.lo..<neck.hi) }
                strand(cut(neck.lo, neck.hi), lake: Double(steps - k) * 0.04 < Self.lakeLife, stamping: true)
            }
            if k % 2 == 0 { respace() }
            if exactEvery > 0 {
                if k % exactEvery == 0 { updateGround(drawing: false) }
            } else if k % 12 == 0 { sweep() }
        }
        if exactEvery == 0 {
            // `sweep` works from straight banks between the nodes and `updateGround` from bowed ones, so give the
            // river's ribbon and a texel beyond it the present time, or a hairline of old ground is left between them
            sweep()
            path.removeAll(keepingCapacity: true)
            for node in nodes { path.append([node.x, node.y, node.half + 1 / texels]) }
            fillRibbon(path.count, closed: true)
            // where the river has been since a lake was born, the lake is gone, and its end there has been silting up since
            trimLakes { texel, lake in ground[texel].x > Float(lake.born - base) + 0.05 ? Double(ground[texel].x) + base : nil }
        }
        updateGround()
        ground.withUnsafeMutableBufferPointer { ground in pixels.withUnsafeMutableBufferPointer { pixels in
            for i in ground.indices { write(i, ground, pixels) }
        } }
    }

    /// The river's length over the valley's.
    var sinuosity: Float {
        nodes.indices.reduce(0) { sum, i in
            let q = (i + 1) % nodes.count
            return sum + hypot(nodes[q].x + (q == 0 ? period : 0) - nodes[i].x, nodes[q].y - nodes[i].y)
        } / period
    }
}
