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

/// One loop of track. `s` runs the way its trains go.
final class Loop {
    let poly: [SIMD2<Double>]
    /// Samples a quarter unit apart, their distance along the loop (one more, closing it), unit tangents, and
    /// heights (a bridge's ramps).
    let P: [SIMD2<Double>], S: [Double], T: [SIMD2<Double>]
    var Z: [Double]
    let pieces: [Piece], rmin: Double
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
    /// How a loop sits by those before it: across one of their straights, inside one, or on its own.
    enum Plan { case twice, nest, beside, single }
    let view: RailView, seed: Int
    /// The world's corners that can come on the screen.
    let lo: SIMD2<Double>, hi: SIMD2<Double>
    var loops: [Loop] = [], cross: [Crossing] = []
    var trains: [String] { loops.flatMap(\.keys) }
    /// For swapping trains: the branch they leave and arrive by, and crossovers joining loops to its loop.
    var branch: Branch?, links: [Link] = []

    /// Loops for the trains, the largest radius first. Each is a rectangle on the world's axes (which run on the
    /// screen's diagonals), or half the time, if `notches`, one with notches out of its corners (an L, a T,
    /// steps or a cross), some corners cut at 45 degrees, every corner rounded. A train that gets no loop of its
    /// own may run on one behind another (at most two to a loop) under block signals, if `share`.
    init(seed: Int, view: RailView, trains: [String], share: Bool, notches: Bool = true, tries: Int = 900) {
        self.view = view
        self.seed = seed
        var rng = Dice(seed)
        let (w, h) = (Double(view.w), Double(view.h)), e = Self.edge
        let side = w / 2 + h
        (lo, hi) = (SIMD2(repeating: -side / 2), SIMD2(repeating: side / 2))
        let (lo, hi) = (lo, hi)
        func onScreen(_ poly: [SIMD2<Double>]) -> Bool {
            poly.allSatisfy { let q = view.project([$0.x, $0.y, 0]); return q.x > e.side - 2 && q.x < w - e.side + 2 && q.y > e.top - 2 && q.y < h - e.bottom + 2 }
        }
        let order = trains.sorted { RailArt.consist($0).minRadius > RailArt.consist($1).minRadius }
        guard !order.isEmpty else { return }
        let plan: Plan = order.count > 1 ? rng.pick([.twice, .twice, .nest, .beside]) : .single
        for (ti, key) in order.enumerated() {
            let consist = RailArt.consist(key), R = consist.minRadius, short = R <= 32
            let attempts = ti < 2 ? tries : short ? tries / 2 : tries / 4 // a third loop if it fits
            for attempt in 0..<attempts {
                var mode = Plan.single
                if !loops.isEmpty {
                    mode = [.twice: .twice, .nest: .nest][plan] ?? .beside
                    if loops.count > 1 || attempt > tries / 2 { mode = rng.pick(short ? [.nest, .nest, .beside, .twice] : [.twice, .nest, .beside]) }
                }
                let poly: [SIMD2<Double>]
                if mode == .nest { // the short train's tight inner loop
                    let host = rng.chance(0.6) ? loops.max { $0.L < $1.L }! : loops[rng.below(loops.count)]
                    guard let p = Self.innerRect(&rng, host, R) else { continue }
                    poly = p
                } else if mode == .twice {
                    guard let p = Self.crossRect(&rng, loops[rng.below(loops.count)], R, lo, hi) else { continue }
                    poly = p
                } else {
                    // the first loop big, the rest any size that fits; a shape gets a few goes before a plain loop
                    let least = loops.isEmpty ? 0.8 * (1 - Double(attempt) / Double(attempts)) : 0
                    var shaped: [SIMD2<Double>]?
                    if notches, rng.chance(0.75) { for _ in 0..<8 where shaped == nil { shaped = Self.loopRect(&rng, R, w, h, least: least, notches: true) } }
                    guard let p = shaped ?? Self.loopRect(&rng, R, w, h, least: least, notches: false) else { continue }
                    poly = p
                }
                if !onScreen(poly) { continue }
                let f = Self.fillet(poly, 1.15 * R)
                guard f.rmin >= 0.98 * R else { continue }
                // a loop 2.2 trains long; after half the tries, a long freight may drop cars to fit a shorter one
                var placed = key
                if f.S[f.S.count - 1] < 2.2 * consist.length {
                    guard attempt > attempts / 2, let n = consist.cars(fitting: f.S[f.S.count - 1] / 2.2) else { continue }
                    placed = consist.shortened(to: n).key
                }
                let loop = Loop(poly: poly, P: f.P, S: f.S, pieces: f.pieces, rmin: f.rmin)
                var found: [Crossing] = [], ok = true
                for (i, q) in loops.enumerated() {
                    guard let c = Self.crossings(q, loop) else { ok = false; break }
                    found += c.map { Crossing(a: i, b: loops.count, sa: $0.sa, sb: $0.sb, angle: $0.angle) }
                }
                guard ok else { continue }
                loop.keys = [placed]
                loops.append(loop)
                cross += found
                break
            }
        }
        makeBridge()
        groupCrossings()
        if share {
            let placed = Set(loops.flatMap(\.keys).map { String($0.split(separator: "#")[0]) })
            for key in order where !placed.contains(key) {
                // the longest loop with room behind its train, at full length or, failing that, shortened
                let consist = RailArt.consist(key)
                func fits(_ li: Int, _ joining: Consist) -> Bool {
                    let lens = loops[li].keys.map { RailArt.consist($0).length + 2 } + [joining.length + 2]
                    return Self.planBlocks(loops[li].L, lens, must: diamondZones(li, longest: lens.max()!)) != nil
                }
                let open = loops.indices.filter { loops[$0].keys.count < 2 && loops[$0].rmin >= 0.98 * consist.minRadius }
                if let li = open.filter({ fits($0, consist) }).max(by: { loops[$0].L < loops[$1].L }) {
                    loops[li].keys.append(key)
                } else if consist.cars > 5 {
                    let options = open.compactMap { li in
                        stride(from: consist.cars - 1, through: 5, by: -1).first { fits(li, consist.shortened(to: $0)) }.map { (li, $0) }
                    }
                    if let (li, n) = options.max(by: { $0.1 < $1.1 }) { loops[li].keys.append(consist.shortened(to: n).key) }
                }
            }
            groupCrossings()
        }
    }

    /// Whether a train could hold a diamond group for ever: on some loop, the stretches where its train needs the group
    /// (from braking distance short of each diamond to a train-length past it) join up all the way round, so it
    /// never lets go and the other loop's train starves. Such a layout is passed over.
    var starves: Bool {
        loops.indices.contains { li in
            let trains = loops[li].keys.map(RailArt.consist)
            return !trains.isEmpty && covers(li, length: trains.map(\.length).max()!, cruise: trains.map(\.cruise).max()!)
        }
    }

    /// Stretches of loop `li` where no block may begin: from a diamond's approach to a train-length past it, so a
    /// train never stands at a block signal holding a diamond (which, with a train waiting for that diamond, could
    /// lock them both).
    func diamondZones(_ li: Int, longest: Double) -> [(Double, Double)] {
        cross.filter { $0.kind == .diamond }.compactMap { c in c.s(on: li).map { ($0 - 40, $0 + longest + 12) } }
    }

    /// Where blocks begin for trains sharing a one-way loop of length L: the fewest blocks (4 or more, more than
    /// the trains) such that the trains together can never hold every one, each spanning at most ceil(length /
    /// shortest block) + 1 and reserving one ahead, so they can't lock. No block begins in a `must` zone, nor in a
    /// `prefer` one if that can be helped; a boundary that can't move out of one is left out, for a longer block.
    /// Nil if there's no such plan.
    static func planBlocks(_ L: Double, _ lens: [Double], must: [(Double, Double)], prefer: [(Double, Double)] = [], from b0: Double = 0) -> [Double]? {
        let least = max(4, lens.count + 1)
        func clear(_ x: Double, _ zones: [(Double, Double)]) -> Bool { zones.allSatisfy { !(0...($0.1 - $0.0)).contains(wrap(x - $0.0, L)) } }
        for zones in [must + prefer, must] {
            for n in least..<24 {
                let lb = L / Double(n)
                for shift in stride(from: 0.0, to: lb, by: 2) {
                    var bounds = Set<Double>()
                    for k in 0..<n {
                        let x = b0 + shift + Double(k) * lb
                        if let nudge = stride(from: 0.0, to: lb * 0.45, by: 1).first(where: { clear(x + $0, zones) }) {
                            bounds.insert((wrap(x + nudge, L) * 100).rounded() / 100)
                        }
                    }
                    guard bounds.count >= least else { continue }
                    let b = bounds.sorted(), gaps = zip(b, b.dropFirst() + [b[0] + L]).map { $1 - $0 }, shortest = gaps.min()!
                    if shortest > 1, b.count > lens.reduce(0, { $0 + Int(ceil($1 / shortest)) + 2 }) { return b }
                }
            }
        }
        return nil
    }

    // MARK: drawing loops

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

    /// How far loops keep from the screen's edges, in art pixels: clear of the menu bar at the top and the Dock at the
    /// bottom, so no train runs under them. ponytail: fixed for a Dock at the bottom; read the screen's visible frame
    /// if one at the side, or hidden, matters.
    static let edge = (side: 12.0, top: 20.0, bottom: 20.0)

    /// For iso: a loop round a rectangle on the world's axes, at least `least` of the biggest. An a by b rectangle
    /// spans a + b pixels across the screen and (a + b) / 2 down it, so one that fits whole leaves the screen's corners
    /// empty; this one may be as big as the screen's height and half its width again, and any corner that runs off
    /// the screen is cut off square to that edge (across or up the screen), so a loop can run near all four edges. With
    /// `notches`, notches come out of other corners (one makes an L, two on one side a T, two at opposite corners
    /// steps, all four a cross), or bays out of the middle of a side (a U) or of two opposite sides (an H, a model
    /// railway's dogbone), which lengthen the loop by twice their depth. A notch or bay is at least a curve's width
    /// (2R + 4) each way, and every straight keeps that much, so each step can be rounded. Some plain corners are cut
    /// at 45 degrees.
    static func loopRect(_ rng: inout Dice, _ R: Double, _ w: Double, _ h: Double, least: Double, notches: Bool) -> [SIMD2<Double>]? {
        // on the screen: |x - y| <= U, and x + y from vTop to vBottom (a point's y on the screen is (x + y) / 2 + h / 2)
        let U = w / 2 - edge.side, (vTop, vBottom) = (2 * edge.top - h, h - 2 * edge.bottom), V = (vBottom - vTop) / 2
        let gap = 2 * R + 4, side0 = notches ? 2 * gap : gap, hi = 2 * V + U, lo = max(2 * side0, least * hi)
        guard hi > lo else { return nil }
        let span = rng.uniform(lo, hi), a0 = rng.uniform(side0, span - side0)
        let (a, b) = rng.chance(0.5) ? (a0, span - a0) : (span - a0, a0)
        let sv = max(V - span / 2, 0) + 0.1 * span, su = max(U - span / 2, 0) + 0.15 * span
        let v = (vTop + vBottom) / 2 + rng.uniform(-sv, sv), u = rng.uniform(-su, su), (cx, cy) = ((u + v) / 2, (v - u) / 2)
        // corners: 0 at the top of the screen, 1 at the right, 2 at the bottom, 3 at the left; side k runs from corner k
        let pts: [SIMD2<Double>] = [[cx - a / 2, cy - b / 2], [cx + a / 2, cy - b / 2], [cx + a / 2, cy + b / 2], [cx - a / 2, cy + b / 2]]
        let sides = [a, b, a, b]
        func off(_ e: Double) -> Double { e > 0 ? max(e, R) : 0 }
        let forced = [off(vTop - v + span / 2), off(u + span / 2 - U), off(v + span / 2 - vBottom), off(span / 2 - U - u)] // how far each runs off
        var notched = Set<Int>(), baySides: [Int] = []
        if notches {
            let turn = rng.below(4), shape = rng.pick([[0], [0], [0, 1], [0, 2], [0, 1, 2, 3], [], [], []])
            if shape.isEmpty {
                baySides = rng.chance(0.5) ? [turn] : [turn % 2, turn % 2 + 2]
            } else {
                notched = Set(shape.map { ($0 + turn) % 4 }).filter { forced[$0] == 0 }
                guard !notched.isEmpty else { return nil }
            }
        }
        // what each corner takes from the side behind it and the side after it
        var take = [(back: Double, on: Double)](repeating: (0, 0), count: 4)
        for k in 0..<4 {
            let back = (k + 3) % 4
            if notched.contains(k) {
                func depth(_ side: Int, _ shared: Bool) -> Double? {
                    let room = sides[side] - gap - forced[side] - forced[(side + 1) % 4], most = shared ? room / 2 : room
                    return most >= gap ? rng.uniform(gap, most) : nil
                }
                guard let nIn = depth(back, notched.contains(back)), let nOut = depth(k, notched.contains((k + 1) % 4)) else { return nil }
                take[k] = (nIn, nOut)
            } else if forced[k] > 0 {
                take[k] = (forced[k], forced[k])
            } else {
                let c = rng.uniform(0.8 * R, 1.4 * R)
                if rng.chance(0.35) { take[k] = (c, c) }
            }
        }
        for k in 0..<4 where sides[k] - take[k].on - take[(k + 1) % 4].back < gap { // too little straight left
            for e in [k, (k + 1) % 4] where !notched.contains(e) && forced[e] == 0 { take[e] = (0, 0) }
            if sides[k] - take[k].on - take[(k + 1) % 4].back < gap { return nil }
        }
        // each bay: where along its side it starts and ends, and how deep it reaches in
        var bays: [Int: (s0: Double, s1: Double, depth: Double)] = [:]
        for k in baySides {
            let from = take[k].on + gap, to = sides[k] - take[(k + 1) % 4].back - gap
            let across = sides[(k + 1) % 4], most = baySides.count == 2 ? (across - gap) / 2 : across - gap
            guard to - from >= gap, most >= gap else { return nil }
            let width = rng.uniform(gap, to - from), s0 = rng.uniform(from, to - width)
            bays[k] = (s0, s0 + width, rng.uniform(gap, most))
        }
        var out: [SIMD2<Double>] = []
        for k in 0..<4 {
            let p = pts[k], tIn = normalize(pts[(k + 3) % 4] - p), tOut = normalize(pts[(k + 1) % 4] - p)
            if notched.contains(k) {
                out += [p + tIn * take[k].back, p + tIn * take[k].back + tOut * take[k].on, p + tOut * take[k].on]
            } else if take[k].back > 0 {
                out += [p + tIn * take[k].back, p + tOut * take[k].on]
            } else {
                out.append(p)
            }
            if let bay = bays[k] {
                let inward = normalize(pts[(k + 2) % 4] - pts[(k + 1) % 4])
                out += [p + tOut * bay.s0, p + tOut * bay.s0 + inward * bay.depth, p + tOut * bay.s1 + inward * bay.depth, p + tOut * bay.s1]
            }
        }
        return out
    }

    /// A rectangle inside another loop, at least `clear` from its track all round: a loop in a loop.
    static func innerRect(_ rng: inout Dice, _ host: Loop, _ R: Double, clear: Double = 22) -> [SIMD2<Double>]? {
        let lo = host.P.reduce(SIMD2(repeating: Double.infinity), simd_min), hi = host.P.reduce(SIMD2(repeating: -Double.infinity), simd_max)
        let span = hi - lo - 2 * clear
        guard min(span.x, span.y) >= 2 * R + 4 else { return nil }
        let w = rng.uniform(2 * R + 4, min(span.x, 6 * R)), h = rng.uniform(2 * R + 4, min(span.y, 6 * R))
        let x0 = rng.uniform(lo.x + clear, hi.x - clear - w), y0 = rng.uniform(lo.y + clear, hi.y - clear - h)
        let pts: [SIMD2<Double>] = [[x0, y0], [x0 + w, y0], [x0 + w, y0 + h], [x0, y0 + h]]
        let edge = (0..<4).flatMap { k in (0..<12).map { pts[k] + (pts[(k + 1) % 4] - pts[k]) * Double($0) / 11 } }
        guard edge.allSatisfy({ insidePoly($0, host.poly) }) else { return nil }
        let track = stride(from: 0, to: host.P.count, by: 4).map { host.P[$0] }
        return edge.allSatisfy { q in track.allSatisfy { length($0 - q) >= clear } } ? pts : nil
    }

    /// A rectangle whose two sides cross one of A's straights at right angles, a twice-around: it reaches into A
    /// and out of it.
    static func crossRect(_ rng: inout Dice, _ A: Loop, _ R: Double, _ lo: SIMD2<Double>, _ hi: SIMD2<Double>) -> [SIMD2<Double>]? {
        let straights = A.pieces.filter { $0.kind == .straight && (abs($0.d.x) < 1e-6 || abs($0.d.y) < 1e-6) && $0.s1 - $0.s0 > 2 * R + 2 + 28 }
        guard !straights.isEmpty else { return nil }
        let pc = rng.pick(straights), L = pc.s1 - pc.s0
        let width = rng.uniform(2 * R + 2, min(L - 28, 6 * R)), t1 = rng.uniform(14, L - 14 - width)
        let (p1, p2) = (pc.a + pc.d * t1, pc.a + pc.d * (t1 + width))
        var n = SIMD2(-pc.d.y, pc.d.x)
        if insidePoly(pc.a + pc.d * (t1 + width / 2) + n * 3, A.poly) { n = -n } // n points out of A
        let dOut = rng.uniform(R + 14, 5 * R), dIn = rng.uniform(R + 14, 4 * R)
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
        let longest = trains.map { RailArt.consist($0).length + 2 }.max() ?? 0
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
