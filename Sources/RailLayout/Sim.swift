import Foundation
import simd

/// Trains on their loops, the diamonds' and blocks' reservations, the station stops, the level crossing and a
/// car on the road, in fixed steps of 1/60 s. Deterministic: the same layout runs the same way.
struct Sim {
    static let dt = 1.0 / 60, accel = 8.0, dwell = 30.0, roadSpeed = 11.0 // px/s², s, px/s

    struct Train {
        let loop: Int, consist: Consist
        var s = 0.0, v: Double, waited = 0.0, stopped = 0.0, dwell = 0.0, served = false
        var length: Double { consist.length }
    }

    let lay: Layout, sc: Scenery
    var trains: [Train] = []
    var t = 0.0
    /// Which train holds each diamond group, and each block (loop, block).
    var holder: [Int: Int] = [:], blockHolder: [SIMD2<Int>: Int] = [:]
    let diamonds: [Crossing]
    var car: (s: Double, v: Double, waited: Double)?
    var road: (P: [SIMD2<Double>], S: [Double], stop: Double)?

    init(_ lay: Layout, _ sc: Scenery) {
        (self.lay, self.sc) = (lay, sc)
        for (li, lp) in lay.loops.enumerated() {
            for key in lp.keys { let c = RailArt.consist(key); trains.append(Train(loop: li, consist: c, v: c.cruise)) }
        }
        diamonds = lay.cross.filter { $0.kind == .diamond }
        place()
        setUpRoad()
    }

    /// Start positions: two on one loop with the passenger train at the platform and the other closing up behind;
    /// a wait at a diamond early on; a train coming up to the level crossing.
    private mutating func place() {
        var rng = Dice(lay.seed)
        for i in trains.indices { trains[i].s = rng.uniform(0, lay.loops[trains[i].loop].L) }
        var used = Set<Int>()
        for li in sc.blocks.keys.sorted() {
            let mine = trains.indices.filter { trains[$0].loop == li }
            let atStation = sc.station?.loop == li
            let a = atStation ? mine.first { !trains[$0].consist.freight } ?? mine[0] : mine[0], b = mine.first { $0 != a }!
            if atStation, !trains[a].consist.freight, let st = sc.station, !st.noStop {
                trains[a].s = st.sStop; trains[a].dwell = 10; trains[a].served = true
            } else {
                trains[a].s = rng.uniform(0, lay.loops[li].L)
            }
            trains[b].s = blockStart(li, trains[a].s - trains[a].length) - 4 - 46
            used.insert(li)
        }
        if let c = diamonds.first, !used.contains(c.a), !used.contains(c.b),
           let a = trains.firstIndex(where: { $0.loop == c.a }), let b = trains.firstIndex(where: { $0.loop == c.b }) {
            trains[a].s = c.sa + trains[a].length - 45
            trains[b].s = c.sb - c.half - 26
            used = [c.a, c.b]
        }
        for cr in sc.crossings {
            if let i = trains.firstIndex(where: { $0.loop == cr.loop }), !used.contains(cr.loop) { trains[i].s = cr.s - 30; used.insert(cr.loop) }
        }
    }

    /// The car on the road: timed to arrive at the stop line a second after the crossing first comes on.
    private mutating func setUpRoad() {
        guard let cr = sc.crossings.first, cr.road < sc.roads.count else { return }
        let P = sc.roads[cr.road]
        var S = [0.0]
        for (a, b) in zip(P, P.dropFirst()) { S.append(S[S.count - 1] + length(b - a)) }
        let k = P.indices.min { length(P[$0] - cr.p) < length(P[$1] - cr.p) }!
        road = (P, S, S[k] - 10.5)
        var probe = self
        var on: Double?
        for _ in 0..<Int(120 / Self.dt) {
            if probe.crossingOn { on = probe.t; break }
            probe.step()
        }
        car = (road!.stop - Self.roadSpeed * ((on ?? 6) + 1), Self.roadSpeed, 0)
    }

    // MARK: blocks

    func block(_ li: Int, _ x: Double) -> Int {
        let B = sc.blocks[li]!, s = wrap(x, lay.loops[li].L)
        return ((B.lastIndex { $0 <= s } ?? -1) + B.count) % B.count
    }

    func blockStart(_ li: Int, _ x: Double) -> Double { sc.blocks[li]![block(li, x)] }

    /// The blocks a train stands in, rear to front.
    func span(_ i: Int) -> [Int] {
        let tr = trains[i], n = sc.blocks[tr.loop]!.count
        var out = [block(tr.loop, tr.s - tr.length)]
        let front = block(tr.loop, tr.s)
        while out[out.count - 1] != front { out.append((out[out.count - 1] + 1) % n) }
        return out
    }

    func occupied(_ li: Int, _ k: Int) -> Bool { trains.indices.contains { trains[$0].loop == li && span($0).contains(k) } }

    /// Whether `train` is within `half` of `sc` (along its loop) or `approach` short of it, and how far ahead it is.
    func zone(_ i: Int, _ sc: Double, _ half: Double, _ approach: Double) -> (Bool, Double) {
        let tr = trains[i], a = centred(sc - tr.s, lay.loops[tr.loop].L)
        return (-(tr.length + half) <= a && a <= half + approach, a)
    }

    var crossingOn: Bool {
        sc.crossings.contains { cr in trains.indices.contains { trains[$0].loop == cr.loop && zone($0, cr.s, 4, 40).0 } }
    }

    mutating func step() {
        let dt = Self.dt, accel = Self.accel
        for i in trains.indices {
            let li = trains[i].loop, L = lay.loops[li].L
            let brake = trains[i].v * trains[i].v / (2 * accel) + 4
            var target: Double?
            func stop(at x: Double) { target = min(target ?? x, x) }
            var need: [Int: [(s: Double, a: Double, half: Double)]] = [:]
            for c in diamonds {
                guard let s0 = c.s(on: li) else { continue }
                let (inside, a) = zone(i, s0, c.half, brake + 6)
                if inside { need[c.group, default: []].append((s0, a, c.half)) }
            }
            for g in need.keys.sorted() {
                let list = need[g]!
                let free = holder[g] == nil
                if free {
                    holder[g] = i
                } else if holder[g] != i {
                    for d in list where d.a > d.half { stop(at: trains[i].s + d.a - d.half - 4) } // not yet in the box: wait at the home signal
                }
            }
            for g in holder.keys.sorted() where holder[g] == i && need[g] == nil { holder[g] = nil }
            if let B = sc.blocks[li] { // automatic block signals: into a block only when no other train holds it
                let n = B.count
                var want = span(i)
                let next = (want[want.count - 1] + 1) % n, ahead = wrap(B[next] - trains[i].s, L)
                if ahead <= brake + 6 { want.append(next) }
                for k in want {
                    let key = SIMD2(li, k)
                    if let who = blockHolder[key] {
                        if who != i, k == next { stop(at: trains[i].s + ahead - 4) }
                    } else {
                        blockHolder[key] = i
                    }
                }
                for key in blockHolder.keys where key.x == li && blockHolder[key] == i && !want.contains(key.y) { blockHolder[key] = nil }
            }
            if !trains[i].consist.freight, let st = sc.station, st.loop == li, !st.noStop { // passenger trains stop at the station
                let a = centred(st.sStop - trains[i].s, L)
                if trains[i].served, a < -60 { trains[i].served = false }
                if !trains[i].served, -0.5 <= a, a <= brake + 12 {
                    stop(at: trains[i].s + a)
                    if abs(a) < 0.5, trains[i].v < 0.05 { trains[i].dwell = Self.dwell; trains[i].served = true }
                }
            }
            if trains[i].dwell > 0 {
                trains[i].dwell -= dt; trains[i].v = 0; trains[i].stopped = 0 // a station stop isn't a hold
                continue
            }
            if let target {
                let gap = target - trains[i].s, allow = gap > 0.3 ? (2 * accel * gap).squareRoot() : 0
                trains[i].v = max(0, min(trains[i].consist.cruise, trains[i].v + accel * dt, allow))
            } else {
                trains[i].v = min(trains[i].consist.cruise, trains[i].v + accel * dt)
            }
            if trains[i].v < 0.05 { trains[i].waited += dt; trains[i].stopped += dt } else { trains[i].stopped = 0 }
            trains[i].s += trains[i].v * dt
        }
        if var c = car, let road {
            if crossingOn, c.s < road.stop {
                let gap = road.stop - c.s, allow = gap > 0.3 ? (4 * accel * gap).squareRoot() : 0
                c.v = max(0, min(Self.roadSpeed, c.v + accel * dt, allow))
            } else {
                c.v = min(Self.roadSpeed, c.v + accel * dt)
            }
            if c.v < 0.05 { c.waited += dt }
            c.s += c.v * dt
            if c.s > road.S[road.S.count - 1] + 10 { c.s = -10 }
            car = c
        }
        t += dt
        // keep s small, so days of running don't cost precision
        for i in trains.indices where trains[i].s > 4 * lay.loops[trains[i].loop].L { trains[i].s -= 2 * lay.loops[trains[i].loop].L }
    }

    /// Every vehicle: where its middle is (between its bogies, which ride the rails), its heading and slope, and
    /// whether it leads its train.
    func poses() -> [(vehicle: RailVehicle, c: SIMD3<Double>, heading: Double, slope: Double, lead: Bool)] {
        var out: [(RailVehicle, SIMD3<Double>, Double, Double, Bool)] = []
        for tr in trains {
            let lp = lay.loops[tr.loop]
            var d = 0.0
            for (k, v) in tr.consist.vehicles.enumerated() {
                let mid = tr.s - d - Double(v.length) / 2, b = v.bogies * Double(v.length)
                let f = lp.at(mid + b / 2).p, r = lp.at(mid - b / 2).p
                out.append((v, (f + r) / 2, atan2(f.y - r.y, f.x - r.x), (f.z - r.z) / max(b, 1e-6), k == 0))
                d += Double(v.length + 2)
            }
        }
        return out
    }

    /// The car's place, in its lane, and heading.
    func carPose() -> (p: SIMD3<Double>, heading: Double)? {
        guard let car, let road, road.P.count > 1 else { return nil }
        let S = road.S, P = road.P, s = car.s
        let k = min(max(S.firstIndex { $0 >= s } ?? S.count - 1, 1), P.count - 1)
        let f = min(max((s - S[k - 1]) / max(S[k] - S[k - 1], 1e-9), 0), 1)
        let t = normalize(P[k] - P[k - 1]), at = (s <= 0 ? P[0] : s >= S[S.count - 1] ? P[P.count - 1] : P[k - 1] + (P[k] - P[k - 1]) * f) + SIMD2(-t.y, t.x) * 1.8
        return ([at.x, at.y, 0], atan2(t.y, t.x))
    }
}
