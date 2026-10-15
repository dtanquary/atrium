import Foundation
import simd

/// Something that stands on the layout: a voxel model at a place, turned to a heading, its foot at `base` (nil:
/// on the hill's slope, wherever that is).
struct Thing {
    enum Kind { case platform, station, canopy, lamp, tank, signal, house, crossing, pole, tree, deck, abutment, bank, hill }
    var grid: Voxels, pos: SIMD2<Double>, heading = 0.0, kind: Kind, lit = true, base: Double? = 0
    /// The block a signal's post guards, (loop, block), so a signal no train stops at can be taken out.
    var guards: SIMD2<Int>? = nil
}

/// A lineside signal: on a lone train's loop just past the platform (red while that train is just past it), at a
/// block's entrance on a loop two trains share, or at a diamond's home point.
struct Signal {
    enum Role { case lone, block(Int), home(group: Int), distant(of: Int) }
    let loop: Int, s: Double, role: Role, pos: SIMD2<Double>, heading: Double
    /// Drawn: a block signal no train is ever held at is left out, as it would only ever show clear.
    var shown = true
}

/// A road over the track: where, along which road, and the masts at each approach (place, heading, side).
struct RoadCrossing {
    let loop: Int, s: Double, p: SIMD2<Double>, road: Int, n: SIMD2<Double>
    var masts: [(pos: SIMD2<Double>, heading: Double, side: Double)] = []
}

/// A 1-unit raster over the layout and a margin round it, for where there's room.
struct Room {
    let o: SIMD2<Double>, nx: Int, ny: Int
    var occ: [Bool]

    init(_ lo: SIMD2<Double>, _ hi: SIMD2<Double>) {
        o = floor(lo) - 2
        nx = Int(ceil(hi.x - o.x)) + 3; ny = Int(ceil(hi.y - o.y)) + 3
        occ = Array(repeating: false, count: nx * ny)
    }

    func cell(_ p: SIMD2<Double>) -> (Int, Int)? {
        let (i, j) = (Int(floor(p.y - o.y)), Int(floor(p.x - o.x)))
        return i >= 0 && i < ny && j >= 0 && j < nx ? (i, j) : nil
    }

    mutating func mark(_ ps: [SIMD2<Double>], _ r: Double) {
        let R = Int(ceil(r))
        for p in ps { for dy in -R...R { for dx in -R...R where Double(dx * dx + dy * dy) <= r * r {
            if let (i, j) = cell(p + SIMD2(Double(dx), Double(dy))) { occ[i * nx + j] = true }
        } } }
    }

    func free(_ p: SIMD2<Double>) -> Bool { cell(p).map { !occ[$0.0 * nx + $0.1] } ?? false }
    func freeShare(_ ps: [SIMD2<Double>]) -> Double { Double(ps.filter(free).count) / Double(max(ps.count, 1)) }

    /// How far each cell is from the nearest marked one (chamfer, 1 and 1.414).
    func distance() -> [Double] {
        var d = occ.map { $0 ? 0.0 : 1e9 }
        let fw: [(Int, Int, Double)] = [(-1, -1, 1.414), (-1, 0, 1), (-1, 1, 1.414), (0, -1, 1)]
        for i in 0..<ny { for j in 0..<nx { for (di, dj, c) in fw {
            let (a, b) = (i + di, j + dj)
            if a >= 0, b >= 0, b < nx { d[i * nx + j] = min(d[i * nx + j], d[a * nx + b] + c) }
        } } }
        for i in stride(from: ny - 1, through: 0, by: -1) { for j in stride(from: nx - 1, through: 0, by: -1) { for (di, dj, c) in fw {
            let (a, b) = (i - di, j - dj)
            if a < ny, b >= 0, b < nx { d[i * nx + j] = min(d[i * nx + j], d[a * nx + b] + c) }
        } } }
        return d
    }
}

/// Points covering a rectangle `l` along by `w` across, centred on `c`.
func rectPoints(_ c: SIMD2<Double>, _ along: SIMD2<Double>, _ across: SIMD2<Double>, _ l: Double, _ w: Double, _ step: Double = 1) -> [SIMD2<Double>] {
    var out: [SIMD2<Double>] = []
    for v in stride(from: -w / 2, through: w / 2 + 0.01, by: step) { for u in stride(from: -l / 2, through: l / 2 + 0.01, by: step) { out.append(c + u * along + v * across) } }
    return out
}

/// Everything round the track, from the layout's seed: a station and its town, the road over the line and its
/// level crossing, a pond, a hill with a tunnel, signals, a pole line, lamps and trees.
final class Scenery {
    struct Station {
        let loop: Int, piece: Piece, side: Double, mid: SIMD2<Double>, L: Double, sStop: Double
        /// A train standing at the platform would hold a diamond, so trains run through instead.
        var noStop = false
    }
    struct Hill { let loop: Int, c: SIMD2<Double>, r: Double, h: Double, seed: Int }

    var things: [Thing] = [], roads: [[SIMD2<Double>]] = [], lamps: [SIMD2<Double>] = []
    /// Each road's half width: the main road 3.5 with a gravel shoulder, the town's streets 2.5 with kerbs.
    var roadHalf: [Double] = []
    var crossings: [RoadCrossing] = [], signals: [Signal] = [], poles: [SIMD2<Double>] = []
    var pond: (c: SIMD2<Double>, r: Double, seed: Int)?, hill: Hill?, station: Station?
    /// Where each block starts, on loops two trains share.
    var blocks: [Int: [Double]] = [:]

    init(_ lay: Layout, era: RailEra, season: RailSeason) {
        let look = era.look
        var rng = Dice(lay.seed * 7919 + look.dice)
        var G = Room(lay.lo - 30, lay.hi + 30)
        for lp in lay.loops { G.mark(stride(from: 0, to: lp.P.count, by: 4).map { lp.P[$0] }, 6.5) }
        let trackOcc = G.occ
        let view = lay.view
        func onScreen(_ p: SIMD2<Double>, _ m: Double = 4) -> Bool {
            let q = view.project([p.x, p.y, 0])
            return q.x > -m && q.x < Double(view.w) + m && q.y > -m && q.y < Double(view.h) + m
        }
        let signalModel = Models.signal(look.signals)

        // the station, on the longest clear straight of a passenger loop
        var best: (score: Double, li: Int, pc: Piece, side: Double, L: Double)?
        for (li, lp) in lay.loops.enumerated() {
            let freight = lp.keys.allSatisfy { RailArt.consist($0).freight }
            let cs = lay.cross.compactMap { $0.s(on: li) }
            for pc in lp.pieces where pc.kind == .straight && pc.s1 - pc.s0 >= 76 {
                if cs.contains(where: { pc.s0 - 30 < $0 && $0 < pc.s1 + 30 }) { continue }
                if (Int(pc.s0 / step)..<min(Int(pc.s1 / step), lp.Z.count)).contains(where: { lp.Z[$0] > 0 }) { continue }
                for side in [1.0, -1.0] {
                    let n = SIMD2(-pc.d.y, pc.d.x) * side, mid = (pc.a + pc.b) / 2
                    let L = min(pc.s1 - pc.s0 - 44, 110) // room at one end for the road across
                    let probe = rectPoints(mid + n * 15, pc.d, n, L, 16, 2), plat = rectPoints(mid + n * 6, pc.d, n, L, 4, 2)
                    let town = rectPoints(mid + n * 32, pc.d, n, L + 30, 36, 2)
                    guard G.freeShare(probe) > 0.93, plat.allSatisfy({ onScreen($0, -1) }) else { continue }
                    let room = Double(town.filter { G.free($0) && onScreen($0, -4) }.count) / Double(town.count)
                    let score = L + 120 * room + rng.uniform(0, 30) - (freight ? 60 : 0)
                    if best == nil || score > best!.score { best = (score, li, pc, side, L) }
                }
            }
        }
        if let (_, li, pc, side, L) = best {
            let lp = lay.loops[li], d = pc.d, n = SIMD2(-d.y, d.x) * side, mid = (pc.a + pc.b) / 2
            let hF = atan2(d.y, d.x)
            // a platform 4 wide, 4 to 8 off the centreline, its edge facing the track; a freight house's dock instead
            let face = hF + (side > 0 ? .pi : 0) // +y toward the track
            if look.station == .freight {
                things.append(Thing(grid: Models.dock(Int(L)), pos: mid + n * 6, heading: face, kind: .platform))
            } else {
                things.append(Thing(grid: Models.platform(Int(L)), pos: mid + n * 6, heading: hF + (side < 0 ? .pi : 0), kind: .platform))
            }
            G.mark(rectPoints(mid + n * 6, d, n, L, 4), 1)
            let bpos = mid + n * 15
            switch look.station {
            case .depot: things.append(Thing(grid: Models.depot(), pos: bpos, heading: face, kind: .station))
            case .brick:
                things.append(Thing(grid: Models.brickStation(), pos: bpos, heading: face, kind: .station))
                things.append(Thing(grid: Models.canopy(Int(L * 0.6)), pos: mid + n * 6, heading: hF, kind: .canopy))
            case .freight: things.append(Thing(grid: Models.freightHouse(), pos: mid + n * 12.5, heading: face, kind: .station))
            case .shelter: things.append(Thing(grid: Models.shelter(), pos: mid + n * 6, heading: face, kind: .station, base: 1))
            case .british:
                things.append(Thing(grid: Models.britishStation(), pos: mid + n * 13, heading: face, kind: .station))
                things.append(Thing(grid: Models.britishCanopy(Int(L * 0.4)), pos: mid + n * 6, heading: hF, kind: .canopy))
            case .german: things.append(Thing(grid: Models.germanStation(), pos: mid + n * 14, heading: face, kind: .station))
            }
            G.mark(rectPoints(bpos, d, n, 20, 9), 1)
            for k in [-0.35, 0, 0.35] {
                let p = mid + d * (L * k) + n * 7.6
                things.append(Thing(grid: Models.lamp(), pos: p, kind: .lamp)); lamps.append(p)
            }
            if era == .steam {
                let tp = mid - d * (L / 2 + 8) + n * 11, spot = rectPoints(tp, d, n, 8, 8)
                if spot.allSatisfy(G.free), onScreen(tp) { things.append(Thing(grid: Models.waterTank(), pos: tp, heading: hF, kind: .tank)); G.mark(spot, 1) }
            }
            let sFar = pc.s0 + dot(mid - pc.a, d) + L / 2
            station = Station(loop: li, piece: pc, side: side, mid: mid, L: L, sStop: sFar - 2)
            if lp.keys.count < 2 { // a lone train's loop: one signal past the platform's far end
                let q = mid + d * (L / 2 + 4) - n * 5.5
                signals.append(Signal(loop: li, s: pc.s0 + dot(mid + d * (L / 2 + 4) - pc.a, d), role: .lone, pos: q, heading: hF))
                things.append(Thing(grid: signalModel, pos: q, heading: hF, kind: .signal))
            }

            // the main road: past the platform's far end, so a train standing at the platform clears it
            let cx = mid + d * (L / 2 + 9), sCross = pc.s0 + dot(cx - pc.a, d)
            if pc.s0 + 12 < sCross, sCross < pc.s1 - 12 {
                var halves: [[SIMD2<Double>]] = []
                for sgn in [1.0, -1.0] {
                    var pts = [cx]
                    for t in stride(from: 2.0, to: 400, by: 2) {
                        let p = cx + n * sgn * t
                        guard p.x > lay.lo.x - 20, p.x < lay.hi.x + 20, p.y > lay.lo.y - 20, p.y < lay.hi.y + 20, onScreen(p, 16) else { break }
                        // another track ahead: cross only at right angles on a straight, else stop short
                        if t > 12, let (lq, k) = lay.loops.lazy.compactMap({ lq -> (Loop, Int)? in
                            let k = Self.nearest(lq, p); return length(lq.P[k] - p) < 9 ? (lq, k) : nil
                        }).first {
                            let pp = lq.piece(at: lq.S[k])
                            if !(pp.kind == .straight && abs(dot(pp.d, n)) > 0.99 && min(lq.S[k] - pp.s0, pp.s1 - lq.S[k]) > 14 && lq.Z[k] == 0) {
                                if pts.count > 1 { pts.removeLast() }
                                break
                            }
                        }
                        pts.append(p)
                    }
                    halves.append(pts)
                }
                let line = halves[1].reversed() + halves[0].dropFirst()
                if line.count > 6 {
                    roads.append(Array(line)); roadHalf.append(3.5)
                    G.mark(Array(line), 4.5)
                }
                // level crossings: wherever the road meets a track
                for (lj, lq) in lay.loops.enumerated() {
                    for p in line {
                        let k = Self.nearest(lq, p)
                        if length(lq.P[k] - p) < 1.1, !crossings.contains(where: { $0.loop == lj && abs($0.s - lq.S[k]) < 5 }) {
                            crossings.append(RoadCrossing(loop: lj, s: lq.S[k], p: lq.P[k], road: roads.count - 1, n: n))
                        }
                    }
                }
                // a grid off the main road: streets parallel to the track at 22 and 50 either side, joined by cross
                // streets parallel to the main road where both reach
                if let main = roads.first {
                    var reach: [Double: (Double, Double)] = [:]
                    for t in [22.0, 50, -22, -50] {
                        let start = cx + n * t
                        guard main.contains(where: { length($0 - start) <= 1.5 }), abs(t) != 50 || reach[t < 0 ? -22 : 22] != nil else { continue }
                        var ext: [Double: Double] = [:]
                        for sgn in [1.0, -1.0] {
                            var ok = 0.0
                            for k in stride(from: 2.0, to: 72, by: 2) {
                                let p = start + d * sgn * k
                                if k >= 8, !rectPoints(p, d, n, 2, 9).allSatisfy(G.free) || !onScreen(p, -2) { break }
                                ok = k
                            }
                            ext[sgn] = ok > 16 ? ok : 0
                        }
                        guard ext[1]! + ext[-1]! >= 28 else { continue }
                        let pts = stride(from: -ext[-1]!, through: ext[1]!, by: 2).map { start + d * $0 }
                        roads.append(pts); roadHalf.append(2.5); reach[t] = (-ext[-1]!, ext[1]!)
                        G.mark(pts, 3.5)
                    }
                    for (t1, t2) in [(22.0, 50.0), (-22, -50)] {
                        guard let r1 = reach[t1], let r2 = reach[t2] else { continue }
                        let (lo, hi) = (max(r1.0, r2.0) + 6, min(r1.1, r2.1) - 6)
                        for k in [-34.0, 34, -66, 66] where lo <= k && k <= hi {
                            let (a, b) = (cx + n * t1 + d * k, cx + n * t2 + d * k), count = Int(abs(t2 - t1) / 2) + 1
                            let seg = (0..<count).map { a + (b - a) * Double($0) / Double(count - 1) }
                            let inner = seg.filter { min(length($0 - a), length($0 - b)) > 6 }
                            if !inner.isEmpty, inner.flatMap({ rectPoints($0, n, d, 2, 9) }).allSatisfy(G.free) {
                                roads.append(seg); roadHalf.append(2.5)
                                G.mark(seg, 3.5)
                            }
                        }
                    }
                }
                // houses along the streets, both sides, and along the main road
                var houses: [(c: SIMD2<Double>, dv: SIMD2<Double>, toward: SIMD2<Double>, w: Int, d: Int)] = []
                for (ri, rd) in roads.enumerated() where rd.count >= 4 {
                    let dv = normalize(rd[rd.count - 1] - rd[0]), nn = SIMD2(-dv.y, dv.x), total = length(rd[rd.count - 1] - rd[0])
                    for sside in [1.0, -1.0] {
                        var t = 6.0
                        while t < total - 6 {
                            let hw = 6 + rng.below(4), hd = 5 + rng.below(3)
                            let c = rd[0] + dv * (t + Double(hw) / 2) + nn * sside * (roadHalf[ri] + 2 + Double(hd) / 2)
                            let pts = rectPoints(c, dv, nn, Double(hw + 1), Double(hd))
                            if pts.allSatisfy({ G.free($0) && onScreen($0, 2) }), length(c - mid) < 150 {
                                houses.append((c, dv, nn * sside, hw, hd))
                                G.mark(rectPoints(c, dv, nn, Double(hw), Double(hd)), 1.2)
                            }
                            t += Double(hw + 2 + rng.below(4))
                        }
                    }
                }
                let (walls, roofs) = (look.walls, look.roofs)
                for (k, house) in houses.prefix(28).enumerated() {
                    // the door side (-y) faces the road: turned round if the road is on the other side
                    let facing = atan2(house.dv.y, house.dv.x) + (dot(house.toward, SIMD2(-house.dv.y, house.dv.x)) > 0 ? 0 : .pi)
                    let g = Models.house(house.w, house.d, wall: rng.pick(walls), roof: rng.pick(roofs), seed: k + lay.seed)
                    things.append(Thing(grid: g, pos: house.c, heading: facing, kind: .house, lit: hsh(k, lay.seed) < 0.75))
                }
                // street lamps along the side streets
                for rd in roads.dropFirst() {
                    for p in stride(from: 3, to: rd.count, by: 10).map({ rd[$0] }) {
                        let q = p + n * 4.5
                        if G.free(q) { things.append(Thing(grid: Models.lamp(), pos: q, kind: .lamp)); lamps.append(q); G.mark([q], 1) }
                    }
                }
                // crossbucks, or flashers with gates, on the right of each approach
                for i in crossings.indices {
                    let n = crossings[i].n
                    for sgn in [1.0, -1.0] {
                        let q = crossings[i].p + n * sgn * 7.5 + SIMD2(-n.y, n.x) * sgn * 5.5, hq = atan2(n.y, n.x)
                        let mast = switch look.crossing {
                        case .wigwag: Models.crossbuck()
                        case .britishGates: Models.gatepost()
                        case .britishHalfBarriers: Models.lightMast()
                        case .germanBarrier: Models.andreasCross()
                        default: Models.flasher()
                        }
                        things.append(Thing(grid: mast, pos: q, heading: hq, kind: .crossing))
                        crossings[i].masts.append((q, hq, sgn))
                    }
                    G.mark([crossings[i].p], 9)
                }
            }
        }

        // a pond: the biggest clear disc, inside a loop if it can be
        let dist = G.distance()
        var pondBest: (score: Double, p: SIMD2<Double>, d: Double)?
        for i in stride(from: 0, to: G.ny, by: 3) { for j in stride(from: 0, to: G.nx, by: 3) {
            let p = G.o + SIMD2(Double(j) + 0.5, Double(i) + 0.5), dd = dist[i * G.nx + j]
            guard dd >= 14, onScreen(p, -18) else { continue }
            let score = dd + (lay.loops.contains { Layout.insidePoly(p, $0.poly) } ? 12 : 0) + rng.uniform(0, 4)
            if pondBest == nil || score > pondBest!.score { pondBest = (score, p, dd) }
        } }
        if let pb = pondBest {
            let r = min(15, pb.d - 5)
            pond = (pb.p, r, lay.seed)
            G.mark([pb.p], r + 2)
        }

        // a hill with a tunnel through the middle of a long curve
        var hills: [(score: Double, li: Int, c: SIMD2<Double>, r: Double)] = []
        for (li, lp) in lay.loops.enumerated() {
            for pc in lp.pieces where pc.kind == .arc && abs(pc.turn) >= 80 * .pi / 180 {
                let sMid = (pc.s0 + pc.s1) / 2, k = min(Int(sMid / step), lp.P.count - 1)
                if (max(0, k - 200)..<min(k + 200, lp.Z.count)).contains(where: { lp.Z[$0] > 0 }) { continue }
                if lay.cross.contains(where: { c in c.s(on: li).map { abs($0 - sMid) < 80 } ?? false }) { continue }
                let pm = lp.P[k], out = normalize(pm - pc.c), rh = rng.uniform(24, 30), hc = pm - out * rh * 0.15
                let disc = rectPoints(hc, [1, 0], [0, 1], 2 * rh + 6, 2 * rh + 6, 2).filter { length($0 - hc) <= rh + 3 }
                let others = lay.loops.enumerated().filter { $0.offset != li }.map(\.element)
                if others.contains(where: { lq in stride(from: 0, to: lq.P.count, by: 4).contains { length(lq.P[$0] - hc) < rh + 10 } }) { continue }
                // roads, buildings, the pond: not under the hill
                if disc.contains(where: { p in G.cell(p).map { G.occ[$0.0 * G.nx + $0.1] && !trackOcc[$0.0 * G.nx + $0.1] } ?? false }) { continue }
                if let st = station, st.loop == li, length(st.mid - hc) < rh + st.L / 2 + 10 { continue }
                guard Double(disc.filter { onScreen($0, -6) }.count) / Double(disc.count) > 0.95 else { continue }
                hills.append((rng.uniform(0, 1) + abs(pc.turn), li, hc, rh))
            }
        }
        if let h = hills.max(by: { $0.score < $1.score }) {
            hill = Hill(loop: h.li, c: h.c, r: h.r, h: rng.uniform(13, 16), seed: lay.seed)
        }

        // home signals at the diamonds, on the right 14 short of them
        for c in lay.cross where c.kind == .diamond {
            for (li, s0) in [(c.a, c.sa), (c.b, c.sb)] {
                let lp = lay.loops[li], k = min(Int(wrap(s0 - 14, lp.L) / step), lp.P.count - 1), t = lp.T[k]
                let q = lp.P[k] + SIMD2(-t.y, t.x) * 5.5, hq = atan2(t.y, t.x)
                signals.append(Signal(loop: li, s: s0, role: .home(group: c.group), pos: q, heading: hq))
                things.append(Thing(grid: signalModel, pos: q, heading: hq, kind: .signal))
            }
        }

        // blocks on loops two trains share, a signal at each block's entrance: none from a diamond's approach to a
        // train-length past it, and if it can be helped none where a train held at one would stand on the road, at
        // the platform or in the tunnel
        for (li, lp) in lay.loops.enumerated() where lp.keys.count >= 2 {
            let lens = lp.keys.map { RailArt.consist($0).length + 2 }, longest = lens.max()!
            var prefer = crossings.filter { $0.loop == li }.map { ($0.s - 10, $0.s + longest + 10) }
            if let st = station, st.loop == li {
                prefer.append((st.sStop - st.L - 6, st.sStop + 6))
                // a train standing at the platform mustn't hold a diamond either: then trains run through
                if lay.diamondZones(li, longest: 0).contains(where: { wrap(st.sStop - $0.0, lp.L) <= longest + 45 }) { station!.noStop = true }
            }
            if let hill, hill.loop == li {
                for k in stride(from: 0, to: lp.P.count, by: 32) where Self.hillHeight(hill, lp.P[k]) >= 8 { prefer.append((lp.S[k] - 8, lp.S[k] + 8)) }
            }
            let b0 = station.flatMap { $0.loop == li ? $0.sStop + 8 : nil } ?? 0
            func plan(_ b0: Double) -> [Double]? { Layout.planBlocks(lp.L, lens, must: lay.diamondZones(li, longest: longest), prefer: prefer, from: b0) }
            guard let bounds = plan(b0) ?? plan(0) else { lp.keys.removeLast(); continue } // (the layout checked from 0)
            blocks[li] = bounds
            for (k, x) in bounds.enumerated() {
                let (p, t) = lp.at(x), q = SIMD2(p.x, p.y) + SIMD2(-t.y, t.x) * 5.5, hq = atan2(t.y, t.x)
                signals.append(Signal(loop: li, s: x, role: .block(k), pos: q, heading: hq))
                things.append(Thing(grid: signalModel, pos: q, heading: hq, kind: .signal, guards: SIMD2(li, k)))
            }
        }

        placeExtras(lay, &G, &rng, look.extras, onScreen)

        // overhead line: a mast every 70 along each loop, on the side away from the signals (or the platform)
        if look.wire {
            for (li, lp) in lay.loops.enumerated() {
                let side = station.map { $0.loop == li && $0.side < 0 } == true ? 1.0 : -1.0
                for x in stride(from: 10.0, to: lp.L - 10, by: 70) {
                    let (p, t) = lp.at(x), n = SIMD2(-t.y, t.x), q = SIMD2(p.x, p.y) + n * side * 4.5
                    if let hill, Self.hillHeight(hill, q) > 0.5 { continue }
                    if roads.contains(where: { rd in zip(rd, rd.dropFirst()).contains { Self.segmentDistance(q, $0.0, $0.1) < 5 } }) { continue }
                    if lay.loops.indices.contains(where: { j in j != li && stride(from: 0, to: lay.loops[j].P.count, by: 4).contains { length(lay.loops[j].P[$0] - q) < 4.5 } }) { continue }
                    if lay.cross.contains(where: { c in c.kind == .bridge && c.s(on: li).map { abs(centred(x - $0, lp.L)) < 14 } == true }) { continue }
                    things.append(Thing(grid: Models.mast(), pos: SIMD2(p.x, p.y) + n * side * 2.5, heading: atan2(t.y, t.x) + (side > 0 ? 0 : .pi),
                                        kind: .pole, base: p.z))
                }
            }
        }

        // a pole line along the main road
        if let rd = roads.first, look.poles {
            let dv = normalize(rd[rd.count - 1] - rd[0]), nn = SIMD2(-dv.y, dv.x)
            for p in stride(from: 0, to: rd.count, by: 8).map({ rd[$0] }) {
                let q = p - nn * 6.5
                guard lay.loops.allSatisfy({ length($0.P[Self.nearest($0, q)] - q) > 7 }), onScreen(q, 8) else { continue }
                poles.append(q)
            }
            for q in poles { things.append(Thing(grid: Models.pole(), pos: q, heading: atan2(nn.y, nn.x), kind: .pole)); G.mark([q], 2) }
        }

        if look.hedges { placeHedges(lay, &G, &rng, onScreen, season: season) }

        // trees: dart throwing in what's left, thicker in clumps (fewer among hedgerows)
        if let hill { G.mark([hill.c], hill.r + 1) }
        let gap = G.distance()
        var trees: [SIMD2<Double>] = []
        for _ in 0..<6000 where trees.count < (look.hedges ? 100 : 230) {
            let p = SIMD2(rng.uniform(G.o.x, G.o.x + Double(G.nx)), rng.uniform(G.o.y, G.o.y + Double(G.ny)))
            guard let (i, j) = G.cell(p), gap[i * G.nx + j] >= 4, onScreen(p, 4) else { continue }
            let clump = 0.5 + 0.5 * sin(p.x / 23 + Double(lay.seed)) * cos(p.y / 19 - Double(lay.seed))
            if rng.unit() > 0.05 + 0.95 * clump * clump * clump { continue }
            if trees.contains(where: { length($0 - p) < 6 }) { continue }
            trees.append(p)
        }
        for (k, p) in trees.enumerated() {
            let conifer = hsh(k, lay.seed, 5) < look.conifers
            let g = conifer ? Models.conifer(seed: k * 31 + lay.seed, season: season) : Models.tree(seed: k * 31 + lay.seed, season: season)
            things.append(Thing(grid: g, pos: p, kind: .tree))
        }
        if let hill { // a few conifers on the hill
            var hr = Dice(lay.seed + 5)
            for k in 0..<5 {
                let a = hr.uniform(0, 2 * .pi), rr = hr.uniform(0.2, 0.6) * hill.r
                things.append(Thing(grid: Models.conifer(seed: 900 + k + lay.seed, season: season), pos: hill.c + rr * SIMD2(cos(a), sin(a)), kind: .tree, base: nil))
            }
        }
    }

    /// The era's buildings beside the line, each on a straight with its +y side to the track, clear of everything placed
    /// so far: a coaling tower with a water tank beyond it, a grain elevator or silos, and an interlocking tower beside a
    /// diamond (only where there is one). Each is left out if no spot is clear.
    private func placeExtras(_ lay: Layout, _ G: inout Room, _ rng: inout Dice, _ names: [String], _ onScreen: (SIMD2<Double>, Double) -> Bool) {
        guard !names.isEmpty else { return }
        // the model, its footprint along and across the track, the footprint's centre from the track, and how much
        // nearer the track the model's centre is (the coaling tower's chutes reach out over it)
        let extras: [String: (make: () -> Voxels, along: Double, across: Double, off: Double, shift: Double)] = [
            "coaling": (Models.coalingTower, 8, 6, 12, 2), "elevator": (Models.elevator, 22, 6, 12, 0),
            "silos": (Models.silos, 21, 7, 12.5, 0), "tower": (Models.interlockingTower, 7, 6, 11, 0),
            "signalbox": (Models.signalBox, 6, 4, 10, 0),
        ]
        let up = { (p: SIMD2<Double>) in -lay.view.project([p.x, p.y, 0]).y } // how far up the screen
        if let hill { G.mark([hill.c], hill.r + 2) }
        let diamonds = lay.cross.filter { $0.kind == .diamond }.map { x in lay.loops[x.a].P[Int(x.sa / step) % lay.loops[x.a].P.count] }
        for name in names {
            // a tower stands by a diamond, a signal box by the level crossing; neither without one
            let targets = name == "tower" ? diamonds : name == "signalbox" ? crossings.map(\.p) : []
            guard let e = extras[name], targets.isEmpty == !["tower", "signalbox"].contains(name) else { continue }
            var best: (score: Double, c: SIMD2<Double>, d: SIMD2<Double>, n: SIMD2<Double>, side: Double)?
            for lp in lay.loops {
                for pc in lp.pieces where pc.kind == .straight {
                    let L = pc.s1 - pc.s0
                    for t in stride(from: e.along / 2 + 4, to: L - e.along / 2 - 4, by: 4) {
                        if lp.Z[Int((pc.s0 + t) / step) % lp.Z.count] > 0 { continue }
                        for side in [1.0, -1.0] {
                            let d = pc.d, n = SIMD2(-d.y, d.x) * side, c = pc.a + d * t + n * e.off
                            let body = rectPoints(c, d, n, e.along + 2, e.across + 2)
                            guard body.allSatisfy({ G.free($0) && onScreen($0, -2) }) else { continue }
                            var score = rng.uniform(0, 10)
                            if up(c) > up(c - n * e.off) { score += 15 } // behind the track, so it stands clear of it
                            if !targets.isEmpty { // as near its diamond or level crossing as it can stand
                                let near = targets.map { length(c - $0) }.min()!
                                if near > 40 { continue }
                                score -= near
                            } else if let st = station { // away from the platform or freight house
                                score += min(length(c - st.mid), 120) / 6
                            }
                            if best == nil || score > best!.score { best = (score, c, d, n, side) }
                        }
                    }
                }
            }
            guard let b = best else { continue }
            let face = atan2(b.d.y, b.d.x) + (b.side > 0 ? .pi : 0)
            things.append(Thing(grid: e.make(), pos: b.c - b.n * e.shift, heading: face, kind: .station))
            G.mark(rectPoints(b.c, b.d, b.n, e.along + 1, e.across + 1), 1.5)
            if name == "coaling" { // its water tank a little further along, if there is room
                for k in [14.0, -14, 22, -22] {
                    let q = b.c + b.d * k + b.n * (11.5 - e.off), spot = rectPoints(q, b.d, b.n, 9, 9)
                    if spot.allSatisfy({ G.free($0) && onScreen($0, -2) }) {
                        things.append(Thing(grid: Models.waterTank(), pos: q, heading: face, kind: .tank))
                        G.mark(rectPoints(q, b.d, b.n, 8, 8), 1.5)
                        break
                    }
                }
            }
        }
    }

    /// Hedgerows round fields of 40 to 64, about a third of the field edges left open, broken wherever anything else
    /// stands, a tree in some.
    private func placeHedges(_ lay: Layout, _ G: inout Room, _ rng: inout Dice, _ onScreen: (SIMD2<Double>, Double) -> Bool, season: RailSeason) {
        if let hill { G.mark([hill.c], hill.r + 2) }
        let size = [Double(G.nx), Double(G.ny)]
        var lines: [[Double]] = []
        for axis in 0..<2 {
            var xs: [Double] = [], x = G.o[axis] + rng.uniform(4, 40)
            while x < G.o[axis] + size[axis] { xs.append(x); x += rng.uniform(40, 64) }
            lines.append(xs)
        }
        for axis in 0..<2 {
            let other = 1 - axis, cuts = [G.o[other]] + lines[other] + [G.o[other] + size[other]]
            for x in lines[axis] {
                for (t0, t1) in zip(cuts, cuts.dropFirst()) {
                    if rng.chance(0.35) { continue }
                    let P = stride(from: t0 + 0.5, to: t1, by: 1).map { t -> SIMD2<Double> in axis == 0 ? [x, t] : [t, x] }
                    let ok = P.map { G.free($0) && onScreen($0, 2) }
                    var a = 0
                    while a < P.count {
                        guard ok[a] else { a += 1; continue }
                        var b = a
                        while b < P.count, ok[b] { b += 1 }
                        if b - a >= 8 {
                            let c = (P[a] + P[b - 1]) / 2
                            things.append(Thing(grid: Models.hedge(b - a, season: season), pos: c, heading: axis == 0 ? .pi / 2 : 0, kind: .tree))
                            for p in stride(from: a + 3, to: b - 3, by: 11).map({ P[$0] }) where rng.chance(0.4) {
                                things.append(Thing(grid: Models.tree(seed: Int(p.x * 7 + p.y * 13) + lay.seed, season: season), pos: p, kind: .tree))
                            }
                            G.mark(stride(from: a, to: b, by: 2).map { P[$0] }, 1)
                        }
                        a = b
                    }
                }
            }
        }
    }

    /// A distant signal 36 before each stop signal drawn, at caution while that one is at danger (Britain's steam era).
    func addDistants(_ lay: Layout) {
        for (i, sg) in signals.enumerated() where sg.shown {
            if case .distant = sg.role { continue }
            let lp = lay.loops[sg.loop]
            let home: Double = if case .home = sg.role { 14 } else { 0 }
            let x = wrap(sg.s - home - 36, lp.L), (p, t) = lp.at(x), q = SIMD2(p.x, p.y) + SIMD2(-t.y, t.x) * 5.5, hq = atan2(t.y, t.x)
            signals.append(Signal(loop: sg.loop, s: x, role: .distant(of: i), pos: q, heading: hq))
            things.append(Thing(grid: Models.signal(.semaphore), pos: q, heading: hq, kind: .signal, base: p.z))
        }
    }

    /// The sample of `loop` nearest `p`.
    static func nearest(_ loop: Loop, _ p: SIMD2<Double>) -> Int {
        var (best, k) = (Double.infinity, 0)
        for i in loop.P.indices { let d = length_squared(loop.P[i] - p); if d < best { (best, k) = (d, i) } }
        return k
    }

    /// How far `p` is from the segment a–b.
    static func segmentDistance(_ p: SIMD2<Double>, _ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        let ab = b - a, t = min(max(dot(p - a, ab) / max(length_squared(ab), 1e-12), 0), 1)
        return length(p - (a + ab * t))
    }

    static func hillHeight(_ hill: Hill, _ p: SIMD2<Double>) -> Double {
        let d = length(p - hill.c) / hill.r, a = atan2(p.y - hill.c.y, p.x - hill.c.x), s = Double(hill.seed)
        let wobble = 1 + 0.08 * sin(3 * a + s) + 0.05 * sin(5 * a - 2 * s)
        guard d < wobble else { return 0 }
        return hill.h * pow(max(0, min(1, 1 - (d / wobble) * (d / wobble))), 0.75)
    }

    /// The hill as voxel columns, with a cutting up to each portal, a stone headwall and a dark bore; its grass
    /// lighter on the slopes facing the Sun.
    static func hillModel(_ hill: Hill, _ loop: Loop, sun: SIMD3<Double>, season: RailSeason) -> Voxels {
        let n = Int(2 * hill.r + 6), top = Int(ceil(hill.h)) + 3
        var g = Voxels(n, n, top)
        func at(_ i: Int, _ j: Int) -> SIMD2<Double> { hill.c + SIMD2(Double(i) - Double(n) / 2 + 0.5, Double(j) - Double(n) / 2 + 0.5) }
        var h = [Double](repeating: 0, count: n * n)
        for i in 0..<n { for j in 0..<n { h[i * n + j] = hillHeight(hill, at(i, j)) } }
        let near = loop.P.indices.filter { length(loop.P[$0] - hill.c) < hill.r + 6 }
        let ht = near.map { hillHeight(hill, loop.P[$0]) }
        let portals = (1..<max(ht.count, 1)).filter { (ht[$0] >= 8) != (ht[$0 - 1] >= 8) }
        for i in 0..<n { for j in 0..<n {
            let tz = Int(h[i * n + j].rounded())
            guard tz > 0 else { continue }
            // np.gradient: central differences inside, one-sided at the edges
            func slope(_ a: Int, _ b: Int, _ along: Bool) -> Double {
                let (lo, hi) = along ? ((max(a - 1, 0), b), (min(a + 1, n - 1), b)) : ((a, max(b - 1, 0)), (a, min(b + 1, n - 1)))
                let span = Double(along ? hi.0 - lo.0 : hi.1 - lo.1)
                return (h[hi.0 * n + hi.1] - h[lo.0 * n + lo.1]) / max(span, 1)
            }
            let normal = normalize(SIMD3(-slope(i, j, true), -slope(i, j, false), 1)), lit = dot(normal, sun)
            g.fill(i..<(i + 1), j..<(j + 1), 0..<tz, RailArt.mat(season.grassy(lit > 0.86 ? "hill_lt" : lit > 0.6 ? "hill" : "hill_dk")))
            var (k, dt) = (0, Double.infinity)
            for (q, idx) in near.enumerated() { let d = length(at(i, j) - loop.P[idx]); if d < dt { (k, dt) = (q, d) } }
            let hk = near.isEmpty ? 0 : ht[k]
            let pd = portals.map { Double(abs(k - $0)) * step }.min() ?? 1e9
            if dt < 4.5, hk < 8 {
                g.fill(i..<(i + 1), j..<(j + 1), 0..<top, 0) // the cutting
            } else if dt < 6.5, pd < 1.3 {
                g.fill(i..<(i + 1), j..<(j + 1), 0..<max(tz, 9), RailArt.mat("portal")) // the headwall
                if dt < 3.5 { g.fill(i..<(i + 1), j..<(j + 1), 0..<6, RailArt.mat("tunnel")) }
            } else if dt < 3.5, hk >= 8 {
                g.fill(i..<(i + 1), j..<(j + 1), 0..<6, RailArt.mat("tunnel"))
            }
        } }
        return g
    }

    /// The deck over the lower line, its abutments, and a grassy bank under each ramp.
    static func bridges(_ lay: Layout, season: RailSeason) -> [Thing] {
        var out: [Thing] = []
        for c in lay.cross where c.kind == .bridge {
            let up = lay.loops[c.upper], sUp = c.a == c.upper ? c.sa : c.sb
            let (p, t) = up.at(sUp), hd = atan2(t.y, t.x)
            var g = Voxels(18, 9, 3)
            g.fill(0..<18, 0..<9, 0..<1, RailArt.mat("deck"))
            for y in [0, 8] { g.fill(0..<18, y..<(y + 1), 1..<3, RailArt.mat("steel")); for x in stride(from: 0, to: 18, by: 3) { g.fill(x..<(x + 1), y..<(y + 1), 1..<3, RailArt.mat("steel_lt")) } }
            out.append(Thing(grid: g, pos: [p.x, p.y], heading: hd, kind: .deck, base: bridgeHeight - 1))
            for e in [-1.0, 1.0] {
                let q = up.at(sUp + e * 10).p
                var a = Voxels(3, 9, Int(bridgeHeight))
                a.fill(0..<3, 0..<9, 0..<Int(bridgeHeight), RailArt.mat("concrete"))
                out.append(Thing(grid: a, pos: [q.x, q.y], heading: hd, kind: .abutment))
            }
            // the bank under each ramp: one smooth heightfield, its top just under the track, sloping 1:1 at the
            // sides, kept clear of the line beneath
            let q = stride(from: sUp - 8 - ramp - 2, to: sUp + 8 + ramp + 2, by: 0.5).filter { abs($0 - sUp) >= 11.5 }.map { up.at($0).p }.filter { $0.z > 0.3 }
            guard !q.isEmpty else { continue }
            let lo = q.reduce(SIMD2(repeating: Double.infinity)) { simd_min($0, SIMD2($1.x, $1.y)) }, hi = q.reduce(SIMD2(repeating: -Double.infinity)) { simd_max($0, SIMD2($1.x, $1.y)) }
            let (x0, y0) = (floor(lo.x) - 12, floor(lo.y) - 12), nx = Int(ceil(hi.x) + 12 - x0), ny = Int(ceil(hi.y) + 12 - y0)
            let others = lay.loops.indices.filter { $0 != c.upper }.flatMap { j in stride(from: 0, to: lay.loops[j].P.count, by: 2).map { lay.loops[j].P[$0] } }
            var top = [Int](repeating: 0, count: nx * ny), inner = [Bool](repeating: false, count: nx * ny)
            for i in 0..<nx { for j in 0..<ny {
                let p = SIMD2(x0 + Double(i) + 0.5, y0 + Double(j) + 0.5)
                var (dmin, zt) = (Double.infinity, 0.0)
                for t in q { let d = length(SIMD2(t.x, t.y) - p); if d < dmin { (dmin, zt) = (d, t.z) } }
                var h = dmin <= 4.5 ? zt - 0.15 : zt - 0.15 - (dmin - 4.5)
                if h >= 1, others.contains(where: { length($0 - p) < 5.5 }) { h = 0 }
                top[i + nx * j] = Int(floor(max(h, 0))); inner[i + nx * j] = dmin <= 4.5
            } }
            guard let tallest = top.max(), tallest >= 1 else { continue }
            var b = Voxels(nx, ny, tallest)
            let (bank, flank) = (RailArt.mat(season.grassy("bank")), RailArt.mat(season.grassy("bank_dk")))
            for i in 0..<nx { for j in 0..<ny { for z in 0..<top[i + nx * j] { b[i, j, z] = inner[i + nx * j] ? bank : flank } } }
            out.append(Thing(grid: b, pos: [x0 + Double(nx) / 2, y0 + Double(ny) / 2], kind: .bank))
        }
        return out
    }
}
