import Foundation
import simd

/// Track is sampled every quarter unit along its centreline.
let step = 0.25
/// A bridge's clearance (a car's height and 2), and its ramps: a 1:6 toy grade either side.
let bridgeHeight = 7.0, ramp = 6 * bridgeHeight

/// A stretch of a loop's centreline: straight from `a` to `b` along `d`, or an arc round `c` of radius `r` turning
/// by `turn` radians. `s0` and `s1` are where it starts and ends along the loop.
struct Piece {
    enum Kind { case straight, arc }
    var kind: Kind, s0: Double, s1: Double
    var a = SIMD2<Double>.zero, b = SIMD2<Double>.zero, d = SIMD2<Double>.zero
    var c = SIMD2<Double>.zero, r = 0.0, turn = 0.0
}

/// A raster of 2-unit cells, for the rectangles a loop is drawn round.
struct Region {
    let w: Int, h: Int, off: SIMD2<Double>
    var cells: [Bool]
    static let q = 2.0

    init(w: Int, h: Int, off: SIMD2<Double>) { (self.w, self.h, self.off) = (w, h, off); cells = Array(repeating: false, count: w * h) }

    subscript(x: Int, y: Int) -> Bool {
        get { x >= 0 && x < w && y >= 0 && y < h && cells[y * w + x] }
        set { cells[y * w + x] = newValue }
    }

    var any: Bool { cells.contains(true) }

    /// Cells with all four neighbours set, `times` over.
    func eroded(_ times: Int) -> Region {
        var e = self
        for _ in 0..<times {
            let was = e
            for y in 0..<h { for x in 0..<w { e[x, y] = was[x, y] && was[x - 1, y] && was[x + 1, y] && was[x, y - 1] && was[x, y + 1] } }
        }
        return e
    }

    func contains(_ p: SIMD2<Double>) -> Bool {
        self[Int(floor((p.x - off.x) / Self.q)), Int(floor((p.y - off.y) / Self.q))]
    }
}

/// One loop of track. `s` runs the way its trains go.
final class Loop {
    let poly: [SIMD2<Double>]
    /// Samples a quarter unit apart, their distance along the loop (one more, closing it), unit tangents, and
    /// heights (a bridge's ramps).
    let P: [SIMD2<Double>], S: [Double], T: [SIMD2<Double>]
    var Z: [Double]
    let pieces: [Piece], rmin: Double
    var region: Region?
    /// The trains on it, by key: one, or two under block signals.
    var keys: [String] = []
    var L: Double { S[S.count - 1] }

    init(poly: [SIMD2<Double>], P: [SIMD2<Double>], S: [Double], pieces: [Piece], rmin: Double) {
        (self.poly, self.P, self.S, self.pieces, self.rmin) = (poly, P, S, pieces, rmin)
        let n = P.count
        T = (0..<n).map { normalize(P[($0 + 1) % n] - P[($0 + n - 1) % n]) }
        Z = Array(repeating: 0, count: n)
    }

    /// The sample index at or before `s` (wrapped onto the loop), and how far to the next.
    func index(_ s: Double) -> (i: Int, f: Double) {
        let s = wrap(s, L)
        var (lo, hi) = (0, S.count - 1)
        while hi - lo > 1 { let m = (lo + hi) / 2; if S[m] <= s { lo = m } else { hi = m } }
        return (lo, (s - S[lo]) / max(S[lo + 1] - S[lo], 1e-9))
    }

    /// Where the centreline is at `s` (with its height), and its unit tangent.
    func at(_ s: Double) -> (p: SIMD3<Double>, t: SIMD2<Double>) {
        let (i, f) = index(s), j = (i + 1) % P.count
        let xy = P[i] + (P[j] - P[i]) * f
        return ([xy.x, xy.y, Z[i] + (Z[j] - Z[i]) * f], T[i])
    }

    func piece(at s: Double) -> Piece {
        let s = wrap(s, L)
        return pieces.first { $0.s0 <= s && s < $0.s1 } ?? pieces[pieces.count - 1]
    }

    /// The signed distance along the loop from `b` to `a`, the short way round.
    func gap(_ a: Double, _ b: Double) -> Double { centred(a - b, L) }
}

/// `x` onto 0..<L.
func wrap(_ x: Double, _ L: Double) -> Double { let r = x.truncatingRemainder(dividingBy: L); return r < 0 ? r + L : r }
/// `x` onto -L/2..<L/2.
func centred(_ x: Double, _ L: Double) -> Double { wrap(x + L / 2, L) - L / 2 }

func wedge(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double { a.x * b.y - a.y * b.x }

/// Where two loops cross: on a diamond, both at grade, or a bridge, `upper` ramping over.
struct Crossing {
    enum Kind { case diamond, bridge }
    let a: Int, b: Int, sa: Double, sb: Double, angle: Double
    var kind = Kind.diamond, upper = -1
    /// Diamonds near enough along a loop that one train could block two are reserved together.
    var group = 0
    /// How far either side of the crossing point a train is in the box.
    var half: Double { 3.5 / sin(angle * .pi / 180) + 2 }

    func s(on loop: Int) -> Double? { loop == a ? sa : loop == b ? sb : nil }
}

/// The track: a loop for each train or two, and where they cross.
final class Layout {
    enum Plan { case twice, nest, beside, single }
    let view: RailView, seed: Int
    var lo = SIMD2<Double>.zero, hi = SIMD2<Double>.zero
    var loops: [Loop] = [], cross: [Crossing] = [], plan = Plan.single
    var trains: [String] { loops.flatMap(\.keys) }

    /// Loops for the trains, the largest radius first. Each is a union of 1-3 rectangles (on the world's axes,
    /// which in iso run on the diagonals), some corners cut at 45 degrees, every corner rounded. A train that gets
    /// no loop of its own may run on one behind another (at most two to a loop) under block signals, if `share`.
    init(seed: Int, view: RailView, trains: [String], share: Bool, tries: Int = 900) {
        self.view = view
        self.seed = seed
        var rng = Dice(seed)
        let (w, h) = (Double(view.w), Double(view.h)), margin = 10.0
        if view.iso {
            let side = w / 2 + h
            (lo, hi) = ([-side / 2, -side / 2], [side / 2, side / 2])
        } else {
            (lo, hi) = ([margin, margin], [w - margin, h - margin])
        }
        let (lo, hi) = (lo, hi)
        func onScreen(_ poly: [SIMD2<Double>]) -> Bool {
            poly.allSatisfy { let q = view.project([$0.x, $0.y, 0]); return q.x > margin && q.x < w - margin && q.y > margin && q.y < h - margin }
        }
        let order = trains.sorted { RailArt.trains[$0]!.minRadius > RailArt.trains[$1]!.minRadius }
        guard !order.isEmpty else { return }
        plan = order.count > 1 ? rng.pick([.twice, .twice, .nest, .beside]) : .single
        let span = hi - lo
        var first = (lo, hi)
        switch plan {
        case .twice: // room on one side of the first loop for the second to reach out
            let room = RailArt.trains[order[1]]!.minRadius + 30
            first = rng.chance(0.5) ? (lo, hi - [0, room]) : (lo + [0, room], hi)
        case .beside:
            let cut = lo.x + span.x * rng.uniform(0.5, 0.62)
            first = rng.chance(0.5) ? (lo, [cut, hi.y]) : ([lo.x + span.x - (cut - lo.x), lo.y], hi)
        default: break
        }
        for (ti, key) in order.enumerated() {
            let consist = RailArt.trains[key]!, R = consist.minRadius, short = R <= 32
            for attempt in 0..<(ti < 2 ? tries : short ? tries / 2 : tries / 4) { // a third loop if it fits
                var mode = Plan.single
                if !loops.isEmpty {
                    mode = [.twice: .twice, .nest: .nest][plan] ?? .beside
                    if loops.count > 1 || attempt > tries / 2 { mode = rng.pick(short ? [.nest, .nest, .beside, .twice] : [.twice, .nest, .beside]) }
                }
                var poly: [SIMD2<Double>], region: Region?
                if mode == .twice {
                    guard let p = Self.crossRect(&rng, loops[rng.below(loops.count)], R, lo, hi) else { continue }
                    poly = view.iso ? p : p.map { floor($0) + 0.5 }
                } else if view.iso, mode != .nest {
                    guard let p = Self.diamondRect(&rng, R, w, h) else { continue }
                    poly = p
                } else {
                    var inside: Region?
                    if mode == .nest {
                        guard let host = loops[rng.below(loops.count)].region else { continue }
                        inside = host.eroded(10)
                    }
                    let box = loops.isEmpty ? first : (lo, hi)
                    guard let r = Self.rectUnion(&rng, box.0, box.1, R, inside: inside) else { continue }
                    (poly, region) = (view.iso ? r.poly : r.poly.map { $0 + 0.5 }, r.region) // centrelines on pixel centres
                }
                if view.iso, !onScreen(poly) { continue }
                let f = Self.fillet(poly, 1.15 * R)
                guard f.rmin >= 0.98 * R, f.S[f.S.count - 1] >= 2.2 * consist.length else { continue }
                let loop = Loop(poly: poly, P: f.P, S: f.S, pieces: f.pieces, rmin: f.rmin)
                var found: [Crossing] = [], ok = true
                for (i, q) in loops.enumerated() {
                    guard let c = Self.crossings(q, loop) else { ok = false; break }
                    found += c.map { Crossing(a: i, b: loops.count, sa: $0.sa, sb: $0.sb, angle: $0.angle) }
                }
                guard ok else { continue }
                loop.region = region
                loop.keys = [key]
                loops.append(loop)
                cross += found
                break
            }
        }
        makeBridge()
        groupCrossings()
        if share {
            for key in order where !loops.contains(where: { $0.keys.contains(key) }) {
                let consist = RailArt.trains[key]!
                let fit = loops.indices.filter {
                    loops[$0].keys.count < 2 && loops[$0].rmin >= 0.98 * consist.minRadius
                        && Self.blockCount(loops[$0].L, sharedLengths($0, loops[$0].keys + [key])) != nil
                }
                fit.max { loops[$0].L < loops[$1].L }.map { loops[$0].keys.append(key) }
            }
            groupCrossings()
        }
    }

    /// What the blocks of loop `li` must hold for these trains. A train takes a diamond only with the blocks to clear
    /// it by its own length, so a loop with a diamond must hold one more train-length besides.
    func sharedLengths(_ li: Int, _ keys: [String]) -> [Double] {
        let lens = keys.map { RailArt.trains[$0]!.length + 2 }
        return lens + (cross.contains { $0.kind == .diamond && ($0.a == li || $0.b == li) } ? [lens.max()!] : [])
    }

    /// Blocks for trains sharing a one-way loop: at least 4, more than the trains, and more than all of them can
    /// hold at once (each spans at most ceil(length / block) + 1 blocks and reserves 1 ahead), so one is always
    /// free and they can't deadlock. Nil if the loop is too short.
    static func blockCount(_ L: Double, _ lengths: [Double]) -> Int? {
        (max(4, lengths.count + 2)...20).first { n in n > lengths.reduce(0) { $0 + Int(ceil($1 / (L / Double(n)))) + 2 } }
    }

    // MARK: drawing loops

    /// A loop round the union of 1-3 random rectangles within lo...hi, some corners cut at 45 degrees; nil if they
    /// make holes, touch only at a corner, or leave `inside`.
    static func rectUnion(_ rng: inout Dice, _ lo: SIMD2<Double>, _ hi: SIMD2<Double>, _ R: Double, inside: Region?) -> (poly: [SIMD2<Double>], region: Region)? {
        let q = Region.q, off = floor(lo / q) * q
        var reg = Region(w: Int(floor((hi.x - off.x) / q)) + 2, h: Int(floor((hi.y - off.y) / q)) + 2, off: off)
        for _ in 0..<rng.pick([1, 2, 2, 3]) {
            let w = rng.uniform(2 * R + 4, (hi.x - lo.x) * 0.92), h = rng.uniform(2 * R + 4, (hi.y - lo.y) * 0.92)
            var (x0, y0): (Double, Double)
            if reg.any {
                let set = reg.cells.indices.filter { reg.cells[$0] }, j = set[rng.below(set.count)]
                let (cx, cy) = (Double(j % reg.w) * q + off.x, Double(j / reg.w) * q + off.y)
                (x0, y0) = (cx - rng.uniform(0, w), cy - rng.uniform(0, h))
            } else {
                (x0, y0) = (rng.uniform(lo.x, hi.x - w), rng.uniform(lo.y, hi.y - h))
            }
            (x0, y0) = (max(lo.x, x0), max(lo.y, y0))
            let (x1, y1) = (min(hi.x, x0 + w), min(hi.y, y0 + h))
            guard x1 - x0 >= 2 * R + 4, y1 - y0 >= 2 * R + 4 else { continue }
            for y in Int(floor((y0 - off.y) / q))..<Int(floor((y1 - off.y) / q)) {
                for x in Int(floor((x0 - off.x) / q))..<Int(floor((x1 - off.x) / q)) { reg[x, y] = true }
            }
        }
        guard reg.any else { return nil }
        for y in -1..<reg.h { for x in -1..<reg.w { // corners touching only diagonally
            let (a, b, c, d) = (reg[x, y], reg[x + 1, y], reg[x, y + 1], reg[x + 1, y + 1])
            if a && d && !b && !c || b && c && !a && !d { return nil }
        } }
        guard var poly = outline(reg) else { return nil }
        if let inside {
            for j in reg.cells.indices where reg.cells[j] {
                if !inside.contains([Double(j % reg.w) * q + off.x + 1, Double(j / reg.w) * q + off.y + 1]) { return nil }
            }
        }
        var out: [SIMD2<Double>] = []
        let n = poly.count
        for k in 0..<n {
            let (p0, p1, p2) = (poly[(k + n - 1) % n], poly[k], poly[(k + 1) % n])
            let (l0, l1) = (length(p1 - p0), length(p2 - p1))
            let cut = rng.uniform(0.8 * R, 1.6 * R), take = rng.chance(0.4) && min(l0, l1) > 2 * cut + 2 * R
            if take { out += [p1 + (p0 - p1) / l0 * cut, p1 + (p2 - p1) / l1 * cut] } else { out.append(p1) }
        }
        poly = out
        return (poly, reg)
    }

    /// The corners of a region's boundary, as one loop clockwise on the screen; nil if it has holes or several pieces.
    static func outline(_ reg: Region) -> [SIMD2<Double>]? {
        var next: [SIMD2<Int>: SIMD2<Int>] = [:], start: SIMD2<Int>?
        for (edge, ends) in [((0, -1), (0, 0, 1, 0)), ((1, 0), (1, 0, 1, 1)), ((0, 1), (1, 1, 0, 1)), ((-1, 0), (0, 1, 0, 0))] {
            for y in 0..<reg.h { for x in 0..<reg.w where reg[x, y] && !reg[x + edge.0, y + edge.1] {
                let a = SIMD2(x + ends.0, y + ends.1)
                next[a] = SIMD2(x + ends.2, y + ends.3)
                if start == nil { start = a }
            } }
        }
        guard let start else { return nil }
        var loop = [start], at = next[start]!
        while at != start {
            loop.append(at)
            guard loop.count <= next.count, let n = next[at] else { return nil }
            at = n
        }
        guard loop.count == next.count else { return nil }
        let n = loop.count
        return (0..<n).compactMap { k in
            let (a, b, c) = (loop[(k + n - 1) % n], loop[k], loop[(k + 1) % n])
            return b &- a == c &- b ? nil : SIMD2(reg.off.x + Double(b.x) * Region.q, reg.off.y + Double(b.y) * Region.q)
        }
    }

    /// A closed path through the polygon sampled a quarter unit apart, each corner rounded by the largest arc up
    /// to `rmax` that fits: the samples, their distance along it, its pieces and the tightest radius.
    static func fillet(_ poly: [SIMD2<Double>], _ rmax: Double) -> (P: [SIMD2<Double>], S: [Double], pieces: [Piece], rmin: Double) {
        let n = poly.count
        let lens = (0..<n).map { length(poly[($0 + 1) % n] - poly[$0]) }
        let dirs = (0..<n).map { (poly[($0 + 1) % n] - poly[$0]) / lens[$0] }
        var t: [Double] = [], R: [Double] = [], turn: [Double] = []
        for k in 0..<n {
            let (din, dout) = (dirs[(k + n - 1) % n], dirs[k])
            let th = acos(max(-1, min(1, dot(din, dout))))
            let tt = min(rmax * tan(th / 2), lens[(k + n - 1) % n] / 2, lens[k] / 2)
            t.append(tt); R.append(tt / tan(th / 2)); turn.append((wedge(din, dout) < 0 ? -1 : 1) * th)
        }
        var pts: [SIMD2<Double>] = [], pieces: [Piece] = [], s = 0.0
        for k in 0..<n {
            let k1 = (k + 1) % n, d = dirs[k]
            let a = poly[k] + t[k] * d, b = poly[k1] - t[k1] * d, L = length(b - a)
            let m = max(1, Int((L / step).rounded()))
            for i in 0..<m { pts.append(a + (b - a) * Double(i) / Double(m)) }
            pieces.append(Piece(kind: .straight, s0: s, s1: s + L, a: a, b: b, d: d)); s += L
            let r = R[k1], sg: Double = turn[k1] < 0 ? -1 : 1, c = b + SIMD2(-d.y, d.x) * sg * r
            let a0 = atan2(b.y - c.y, b.x - c.x), arc = abs(turn[k1]) * r
            let ma = max(1, Int((arc / step).rounded()))
            for i in 0..<ma { let ang = a0 + turn[k1] * Double(i) / Double(ma); pts.append(c + r * SIMD2(cos(ang), sin(ang))) }
            pieces.append(Piece(kind: .arc, s0: s, s1: s + arc, c: c, r: r, turn: turn[k1])); s += arc
        }
        var S = [0.0]
        for i in 0..<pts.count { S.append(S[i] + length(pts[(i + 1) % pts.count] - pts[i])) }
        return (pts, S, pieces, R.min()!)
    }

    /// For iso: one rectangle on the world's axes (a corner or two cut) whose diamond fits the screen. A w by h
    /// rectangle spans w + h pixels across the screen and (w + h) / 2 down it.
    static func diamondRect(_ rng: inout Dice, _ R: Double, _ w: Double, _ h: Double, margin: Double = 12) -> [SIMD2<Double>]? {
        let room = min(w - 2 * margin, 2 * (h - 2 * margin))
        var a = rng.uniform(2 * R + 4, room - 2 * R - 4), b = rng.uniform(2 * R + 4, room - a)
        if rng.chance(0.5) { (a, b) = (b, a) }
        let su = (w / 2 - margin) - (a + b) / 2, sv = (h - 2 * margin) - (a + b) / 2
        guard su >= 0, sv >= 0 else { return nil }
        let u = rng.uniform(-su, su), v = rng.uniform(-sv, sv), (cx, cy) = ((u + v) / 2, (v - u) / 2)
        let pts: [SIMD2<Double>] = [[cx - a / 2, cy - b / 2], [cx + a / 2, cy - b / 2], [cx + a / 2, cy + b / 2], [cx - a / 2, cy + b / 2]]
        var out: [SIMD2<Double>] = []
        for k in 0..<4 {
            let (p, p0, p2) = (pts[k], pts[(k + 3) % 4], pts[(k + 1) % 4])
            let (l0, l1) = (length(p - p0), length(p2 - p)), cut = rng.uniform(0.8 * R, 1.4 * R)
            if rng.chance(0.35), min(l0, l1) > 2 * cut + 2 * R { out += [p + (p0 - p) / l0 * cut, p + (p2 - p) / l1 * cut] } else { out.append(p) }
        }
        return out
    }

    /// A rectangle whose two sides cross one of A's straights at right angles, a twice-around: it reaches into A
    /// and out of it.
    static func crossRect(_ rng: inout Dice, _ A: Loop, _ R: Double, _ lo: SIMD2<Double>, _ hi: SIMD2<Double>) -> [SIMD2<Double>]? {
        let straights = A.pieces.filter { $0.kind == .straight && (abs($0.d.x) < 1e-6 || abs($0.d.y) < 1e-6) && $0.s1 - $0.s0 > 2 * R + 2 + 28 }
        guard !straights.isEmpty else { return nil }
        let pc = rng.pick(straights), L = pc.s1 - pc.s0
        let width = rng.uniform(2 * R + 2, min(L - 28, 4 * R)), t1 = rng.uniform(14, L - 14 - width)
        let (p1, p2) = (pc.a + pc.d * t1, pc.a + pc.d * (t1 + width))
        var n = SIMD2(-pc.d.y, pc.d.x)
        if insidePoly(pc.a + pc.d * (t1 + width / 2) + n * 3, A.poly) { n = -n } // n points out of A
        let dOut = rng.uniform(R + 14, 3 * R), dIn = rng.uniform(R + 14, 2.6 * R)
        let pts = [p1 - n * dIn, p2 - n * dIn, p2 + n * dOut, p1 + n * dOut]
        return pts.allSatisfy { $0.x >= lo.x && $0.x <= hi.x && $0.y >= lo.y && $0.y <= hi.y } ? pts : nil
    }

    static func insidePoly(_ p: SIMD2<Double>, _ poly: [SIMD2<Double>]) -> Bool {
        var c = false
        for i in poly.indices {
            let (a, b) = (poly[i], poly[(i + 1) % poly.count])
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { c.toggle() }
        }
        return c
    }

    /// Every stretch where B comes within `near` of A must be one clean crossing: at 40 degrees or more, both
    /// straight 12 units either side. Where they cross (along A, along B, the angle), or nil if they come close
    /// anywhere else.
    static func crossings(_ A: Loop, _ B: Loop, near: Double = 14) -> [(sa: Double, sb: Double, angle: Double)]? {
        func samples(_ l: Loop) -> [SIMD2<Double>] { stride(from: 0, to: l.L, by: 1.0).map { let p = l.at($0).p; return SIMD2(p.x, p.y) } }
        let (pa, pb) = (samples(A), samples(B))
        // A's samples in cells of `near`, so each of B's looks only at its neighbours
        var cells: [SIMD2<Int>: [Int]] = [:]
        func cell(_ p: SIMD2<Double>) -> SIMD2<Int> { SIMD2(Int(floor(p.x / near)), Int(floor(p.y / near))) }
        for (i, p) in pa.enumerated() { cells[cell(p), default: []].append(i) }
        func nearest(_ p: SIMD2<Double>) -> (d: Double, i: Int) {
            var best = (d: Double.infinity, i: 0)
            let c = cell(p)
            for dy in -1...1 { for dx in -1...1 { for i in cells[c &+ SIMD2(dx, dy)] ?? [] {
                let d = length(pa[i] - p)
                if d < best.d { best = (d, i) }
            } } }
            return best
        }
        let found = pb.map(nearest)
        let close = found.indices.filter { found[$0].d < near }
        guard !close.isEmpty else { return [] }
        var runs: [[Int]] = [[close[0]]]
        for k in close.dropFirst() { if k == runs[runs.count - 1].last! + 1 { runs[runs.count - 1].append(k) } else { runs.append([k]) } }
        if runs.count > 1, runs[0][0] == 0, runs[runs.count - 1].last! == pb.count - 1 { runs[0] = runs.removeLast() + runs[0] }
        var out: [(Double, Double, Double)] = []
        for run in runs {
            let k = run.min { found[$0].d < found[$1].d }!
            guard found[k].d <= 1 else { return nil }
            let ja = found[k].i, (na, nb) = (pa.count, pb.count)
            let ta = pa[(ja + 1) % na] - pa[(ja + na - 1) % na], tb = pb[(k + 1) % nb] - pb[(k + nb - 1) % nb]
            let angle = acos(min(1, abs(dot(ta, tb)) / length(ta) / length(tb))) * 180 / .pi
            guard angle >= 40 else { return nil }
            for (Q, j) in [(pa, ja), (pb, k)] {
                let n = Q.count, u = Q[(j + 12) % n] - Q[j], v = Q[j] - Q[(j + n - 12) % n]
                guard abs(wedge(u, v)) <= 0.02 * length(u) * length(v) else { return nil }
            }
            out.append((Double(ja), Double(k), angle))
        }
        return out
    }

    // MARK: bridges and reservations

    /// One crossing of a pair that crosses twice becomes a bridge, the upper loop ramping up 1:6 either side, if
    /// its ramps are clear of every other crossing.
    private func makeBridge() {
        var pairs: [SIMD2<Int>: [Int]] = [:]
        for (i, c) in cross.enumerated() { pairs[SIMD2(c.a, c.b), default: []].append(i) }
        for key in pairs.keys.sorted(by: { ($0.x, $0.y) < ($1.x, $1.y) }) {
            let ids = pairs[key]!
            guard ids.count >= 2 else { continue }
            for ci in ids {
                let c = cross[ci]
                for (up, sUp) in [(c.a, c.sa), (c.b, c.sb)] {
                    let lp = loops[up], reach = 8 + ramp + 12
                    let clear = !cross.indices.contains { oi in
                        oi != ci && [(cross[oi].a, cross[oi].sa), (cross[oi].b, cross[oi].sb)].contains { $0.0 == up && abs(lp.gap($0.1, sUp)) < reach + 16 }
                    }
                    guard clear else { continue }
                    cross[ci].kind = .bridge
                    cross[ci].upper = up
                    for i in lp.Z.indices {
                        let d = abs(lp.gap(lp.S[i], sUp)), r = min(max((8 + ramp - d) / ramp, 0), 1)
                        lp.Z[i] = max(lp.Z[i], bridgeHeight * r * r * (3 - 2 * r))
                    }
                    return
                }
            }
        }
    }

    /// Diamonds closer than the longest train (and margins) along any loop are one reservation group.
    private func groupCrossings() {
        let ds = cross.indices.filter { cross[$0].kind == .diamond }
        let longest = trains.map { RailArt.trains[$0]!.length + 2 }.max() ?? 0
        var parent = Array(ds.indices)
        func find(_ i: Int) -> Int { var i = i; while parent[i] != i { i = parent[i] }; return i }
        for i in ds.indices { for j in (i + 1)..<ds.count {
            for (li, lp) in loops.enumerated() {
                guard let si = cross[ds[i]].s(on: li), let sj = cross[ds[j]].s(on: li) else { continue }
                if abs(lp.gap(si, sj)) < longest + 40 { parent[find(i)] = find(j) }
            }
        } }
        for (i, ci) in ds.enumerated() { cross[ci].group = find(i) }
    }
}
