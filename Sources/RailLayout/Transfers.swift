import Foundation
import simd

/// An open track: the branch's ways out and in, a crossover, a tunnel's hidden siding. Samples a quarter unit apart,
/// flat.
final class RailPath {
    let P: [SIMD2<Double>], S: [Double], T: [SIMD2<Double>]
    /// A hidden siding in a tunnel: nothing on it is drawn.
    let hidden: Bool
    var L: Double { S[S.count - 1] }

    init(_ P: [SIMD2<Double>], hidden: Bool = false) {
        (self.P, self.hidden) = (P, hidden)
        var S = [0.0]
        for (a, b) in zip(P, P.dropFirst()) { S.append(S[S.count - 1] + length(b - a)) }
        self.S = S
        let n = P.count
        T = (0..<n).map { normalize(P[min($0 + 1, n - 1)] - P[max($0 - 1, 0)]) }
    }

    func at(_ u: Double) -> (p: SIMD3<Double>, t: SIMD2<Double>) {
        let u = min(max(u, 0), L)
        var (lo, hi) = (0, S.count - 1)
        while hi - lo > 1 { let m = (lo + hi) / 2; if S[m] <= u { lo = m } else { hi = m } }
        let f = (u - S[lo]) / max(S[hi] - S[lo], 1e-9), xy = P[lo] + (P[hi] - P[lo]) * f
        return ([xy.x, xy.y, 0], T[lo])
    }
}

/// A branch off one loop to the edge of the screen, for trains to leave and arrive by. Loops run one way, so it's a
/// wye: a facing turnout D where leaving trains curve off, a trailing turnout A, 2R further on, where arriving
/// trains join, the two quarter circles meeting at the apex M, where a third turnout puts them onto one straight that
/// runs off the screen.
struct Branch {
    let loop: Int, R: Double, sD: Double, sA: Double
    let D: SIMD2<Double>, A: SIMD2<Double>, M: SIMD2<Double>, d: SIMD2<Double>, n: SIMD2<Double>
    /// D, M and off the edge; in from the edge, M and A.
    let out: RailPath, inn: RailPath
    /// How far the curve out runs to M; how far the way in runs to M; where its home signal stands; how much of
    /// the straight is on the screen.
    let curve: Double, straight: Double, home: Double, shown: Double
}

/// A crossover: a connecting track that leaves loop `a` by a facing turnout at `sa` and joins loop `b` by a
/// trailing turnout at `sb`, both the way the loops run, so a train never reverses.
struct Link {
    let a: Int, b: Int, sa: Double, sb: Double, R: Double, path: RailPath
}

/// A tunnel's hidden yard on a loop no crossover could join: a facing turnout just inside one portal onto a hidden
/// siding a train runs into, and a trailing one just inside the other off a hidden siding its replacement comes out
/// of.
struct Yard {
    let loop: Int, sD: Double, sA: Double, out: RailPath, inn: RailPath
    var home: Double { inn.L - 8 }
}

/// A turnout the swaps set: the branch's facing one D, trailing one A and apex M, or one of a crossover's pair.
enum Turnout: Hashable { case D, A, M, link(Int) }

/// How far each turnout's switch rails run.
let switchLength = 10.0

extension Layout {
    /// The loops a train can leave from by the branch: its own, and those crossovers join to it.
    var joined: Set<Int> {
        guard let branch else { return [] }
        return Set([branch.loop] + links.map(\.a))
    }

    /// Whether a train this long and fast on loop `li` would, for some group of diamonds, always be in one of the
    /// group's zones: it would hold the group for good and starve the train waiting on the other loop.
    func covers(_ li: Int, length: Double, cruise: Double) -> Bool {
        let lp = loops[li], diamonds = cross.filter { $0.kind == .diamond }, approach = cruise * cruise / 16 + 10
        for g in Set(diamonds.map(\.group)) {
            let zones = diamonds.filter { $0.group == g }.compactMap { c in c.s(on: li).map { ($0 - length - c.half, $0 + c.half + approach) } }
            guard zones.count > 1 else { continue }
            if stride(from: 0, to: lp.L, by: 1).allSatisfy({ x in zones.contains { wrap(x - $0.0, lp.L) <= $0.1 - $0.0 } }) { return true }
        }
        return false
    }

    /// Whether a point on the ground shows on the screen, `m` beyond its edges (in by -m).
    func onScreen(_ p: SIMD2<Double>, _ m: Double) -> Bool {
        let q = view.project([p.x, p.y, 0])
        return q.x > -m && q.x < Double(view.w) + m && q.y > -m && q.y < Double(view.h) + m
    }

    /// The branch, on the straight that best leaves the screen soon, outward from its loop, its curves at the
    /// tightest radius any train that may arrive (`pool`, fit for the loop's curves and no longer than its trains),
    /// or the loop's own, can take; clear of the other loops and its own, and 40 from any crossing. Nil if none fits.
    func makeBranch(pool: [String], rng: inout Dice) -> Branch? {
        let longest = pool.map { RailArt.consist($0).length }.max() ?? 0
        var best: (score: Double, Branch)?
        for (li, lp) in loops.enumerated() {
            let maxLength = lp.keys.map { RailArt.consist($0).length }.max()!
            let cands = pool.map(RailArt.consist).filter { $0.minRadius <= lp.rmin / 0.98 + 1e-6 && $0.length <= maxLength + 1e-6 }
            let R = (lp.keys.map(RailArt.consist) + cands).map(\.minRadius).max()!
            let cs = cross.compactMap { $0.s(on: li) }
            for pc in lp.pieces where pc.kind == .straight && pc.s1 - pc.s0 >= 2 * R + 30 {
                for side in [1.0, -1.0] {
                    let n = SIMD2(-pc.d.y, pc.d.x) * side
                    if Self.insidePoly((pc.a + pc.b) / 2 + n * 4, lp.poly) { continue } // outward only
                    for t in stride(from: 14.0, to: pc.s1 - pc.s0 - 2 * R - 14, by: 6) {
                        let sD = pc.s0 + t, sA = sD + 2 * R
                        if cs.contains(where: { abs(centred($0 - sD, lp.L)) < 40 || abs(centred($0 - sA, lp.L)) < 40 }) { continue }
                        let D = pc.a + pc.d * t, A = D + pc.d * 2 * R, M = D + R * (n + pc.d)
                        guard onScreen(M, -6) else { continue }
                        let k = Int(R * .pi / 2 / step)
                        let curveOut = (0...k).map { j -> SIMD2<Double> in let a = Double(j) / Double(k) * .pi / 2; return D + R * n - R * cos(a) * n + R * sin(a) * pc.d }
                        let curveIn = (0...k).map { j -> SIMD2<Double> in let a = Double(j) / Double(k) * .pi / 2; return A + R * n - R * cos(a) * pc.d - R * sin(a) * n }
                        guard let last = (0..<Int(600 / step)).first(where: { !onScreen(M + n * Double($0) * step, 2) }) else { continue }
                        let line = (0..<(last + Int((longest + 40) / step))).map { M + n * Double($0) * step }
                        let seen = curveOut + curveIn + line[..<last]
                        let clear = loops.indices.allSatisfy { j in
                            let near = j == li ? Array(line[..<last]) : seen
                            return stride(from: 0, to: near.count, by: 4).allSatisfy { a in
                                stride(from: 0, to: loops[j].P.count, by: 8).allSatisfy { length(loops[j].P[$0] - near[a]) >= 12 }
                            }
                        }
                        guard clear else { continue }
                        let score = -Double(last) * step + rng.uniform(0, 30) + (lp.keys.count < 2 ? 40 : 0)
                        if let b = best, b.score >= score { continue }
                        let out = RailPath(curveOut + line.dropFirst()), inn = RailPath(line.reversed() + curveIn.dropFirst())
                        let curve = R * .pi / 2
                        best = (score, Branch(loop: li, R: R, sD: wrap(sD, lp.L), sA: wrap(sA, lp.L), D: D, A: A, M: M, d: pc.d, n: n, out: out, inn: inn,
                                              curve: curve, straight: inn.L - curve, home: inn.L - curve - 8, shown: Double(last) * step))
                    }
                }
            }
        }
        return best?.1
    }

    /// Crossovers joining every loop it can to the branch's: for each loop not yet joined, a neighbour that is, and
    /// two connecting tracks, one each way. Each is a curve, a straight and a curve (the shortest that keeps clear
    /// of every other track) at the tightest radius any train fit for both loops needs; between parallel straights
    /// run the same way that's the usual crossover's S. Its turnouts keep clear of the diamonds, bridges and each
    /// other.
    func makeLinks(pool: [String]) -> [Link] {
        guard let branch else { return [] }
        let longest = pool.map { RailArt.consist($0).length }.max() ?? 0
        var busy: [(loop: Int, lo: Double, hi: Double)] = [(branch.loop, branch.sD - 30, branch.sA + 30)]
        var tracks: [[SIMD2<Double>]] = [branch.out.P.filter { onScreen($0, 4) } + branch.inn.P.filter { onScreen($0, 4) }]
        let keepOff = cross.flatMap { [($0.a, $0.sa), ($0.b, $0.sb)] }
        func free(_ li: Int, _ a: Double, _ b: Double) -> Bool {
            let lp = loops[li], (lo, hi) = (min(a, b), max(a, b))
            if keepOff.contains(where: { $0.0 == li && -(longest + 20) < wrap($0.1 - lo, lp.L) && wrap($0.1 - lo, lp.L) < hi - lo + 40 }) { return false }
            if lp.Z[Int(wrap(lo, lp.L) / step) % lp.Z.count] > 0 { return false }
            return !busy.contains { $0.loop == li && !(hi + 2 * switchLength < $0.lo || $0.hi + 2 * switchLength < lo) }
        }
        func spots(_ lp: Loop) -> [(s: Double, p: SIMD2<Double>, h: Double)] {
            lp.pieces.filter { $0.kind == .straight }.flatMap { pc in
                stride(from: switchLength + 4, to: pc.s1 - pc.s0 - switchLength - 4, by: 8).map { t in (pc.s0 + t, pc.a + pc.d * t, atan2(pc.d.y, pc.d.x)) }
            }
        }
        func near(_ pts: [SIMD2<Double>], _ other: [SIMD2<Double>], _ d: Double, by: Int = 8) -> Bool {
            stride(from: 0, to: pts.count, by: by).contains { i in stride(from: 0, to: other.count, by: 8).contains { length(other[$0] - pts[i]) < d } }
        }
        func link(_ X: Int, _ Y: Int) -> Link? {
            let lx = loops[X], ly = loops[Y], rmin = min(lx.rmin, ly.rmin) / 0.98 + 1e-6
            let fit = (pool + lx.keys + ly.keys).map(RailArt.consist).filter { $0.minRadius <= rmin }
            guard let R = fit.map(\.minRadius).max() else { return nil }
            var ways: [(L: Double, sa: Double, sb: Double, p: SIMD2<Double>, h: Double, way: Dubins)] = []
            let toY = spots(ly)
            for (sa, pa, ha) in spots(lx) {
                for (sb, pb, hb) in toY where length(pb - pa) <= 320 {
                    for way in Dubins.ways(pa, ha, pb, hb, R) where 0.15 <= way.a0 && way.a0 <= 2.2 && 0.15 <= way.a1 && way.a1 <= 2.2 {
                        ways.append((way.total, sa, sb, pa, ha, way))
                    }
                }
            }
            ways.sort { $0.L < $1.L }
            let reach = Int((sqrt(2 * R * 3) + 4) / step) // past where a turnout's diverging track is 3 off the main
            for w in ways.prefix(400) {
                guard free(X, w.sa, w.sa + 2 * switchLength), free(Y, w.sb - 2 * switchLength, w.sb) else { continue }
                let pts = w.way.points(w.p, w.h, R)
                if loops.indices.contains(where: { $0 != X && $0 != Y && near(pts, loops[$0].P, 9) }) { continue }
                if tracks.contains(where: { near(pts, $0, 9) }) { continue }
                // clear of its own two loops away from its turnouts, and off them in between
                let clash = [(lx, w.sa, -10.0, 2 * R), (ly, w.sb, -2 * R, 10.0)].contains { o, s, lo, hi in
                    let far = stride(from: 0, to: o.P.count, by: 4).filter { centred(o.S[$0] - s, o.L) < lo || centred(o.S[$0] - s, o.L) > hi }.map { o.P[$0] }
                    return near(pts, far, 6, by: 4)
                } || pts.count > 2 * reach && [lx, ly].contains { near(Array(pts[reach..<(pts.count - reach)]), $0.P, 2.6, by: 4) }
                if clash { continue }
                return Link(a: X, b: Y, sa: wrap(w.sa, lx.L), sb: wrap(w.sb, ly.L), R: R, path: RailPath(pts))
            }
            return nil
        }
        var links: [Link] = [], joined: Set<Int> = [branch.loop]
        for _ in loops.indices {
            for X in loops.indices where !joined.contains(X) {
                for Y in joined.sorted() {
                    guard let go = link(X, Y) else { continue }
                    busy += [(X, go.sa, go.sa + 2 * switchLength), (Y, go.sb - 2 * switchLength, go.sb)]
                    tracks.append(go.path.P)
                    guard let back = link(Y, X) else { busy.removeLast(2); tracks.removeLast(); continue }
                    busy += [(Y, back.sa, back.sa + 2 * switchLength), (X, back.sb - 2 * switchLength, back.sb)]
                    tracks.append(back.path.P)
                    links += [go, back]
                    joined.insert(X)
                    break
                }
            }
        }
        return links
    }
}

/// The shortest curve-straight-curve ways of radius R from a point and heading to another (Dubins paths).
struct Dubins {
    /// Its turns (+1 left, -1 right), the first and last arcs' angles, the straight between, and the circles' centres.
    let s0: Double, s1: Double, a0: Double, a1: Double, straight: Double, c0: SIMD2<Double>, c1: SIMD2<Double>, phi: Double
    var total: Double { straight + R * (a0 + a1) }
    let R: Double

    static func ways(_ p0: SIMD2<Double>, _ h0: Double, _ p1: SIMD2<Double>, _ h1: Double, _ R: Double) -> [Dubins] {
        func left(_ h: Double) -> SIMD2<Double> { [-sin(h), cos(h)] }
        var out: [Dubins] = []
        for (s0, s1) in [(1.0, 1.0), (-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0)] {
            let c0 = p0 + s0 * R * left(h0), c1 = p1 + s1 * R * left(h1), v = c1 - c0, D = length(v)
            var phi = atan2(v.y, v.x), straight = D
            if s0 != s1 {
                guard D >= 2 * R else { continue }
                straight = (D * D - 4 * R * R).squareRoot()
                phi += s0 * atan2(2 * R, straight)
            }
            let a0 = wrap(s0 * (phi - h0), 2 * .pi), a1 = wrap(s1 * (h1 - phi), 2 * .pi)
            out.append(Dubins(s0: s0, s1: s1, a0: a0, a1: a1, straight: straight, c0: c0, c1: c1, phi: phi, R: R))
        }
        return out
    }

    /// Points every quarter unit along it.
    func points(_ p0: SIMD2<Double>, _ h0: Double, _ R: Double) -> [SIMD2<Double>] {
        func on(_ c: SIMD2<Double>, _ s: Double, _ h: Double) -> SIMD2<Double> { c - s * R * SIMD2(-sin(h), cos(h)) }
        var pts: [SIMD2<Double>] = []
        for t in stride(from: 0, to: a0 * R, by: step) { pts.append(on(c0, s0, h0 + s0 * t / R)) }
        let q0 = on(c0, s0, phi), u = SIMD2(cos(phi), sin(phi))
        for t in stride(from: 0, to: straight, by: step) { pts.append(q0 + t * u) }
        for t in stride(from: 0, to: a1 * R + step / 2, by: step) { pts.append(on(c1, s1, phi + s1 * t / R)) }
        return pts
    }
}
