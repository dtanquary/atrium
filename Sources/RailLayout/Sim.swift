import Foundation
import simd

/// Trains on their loops, the diamonds' and blocks' reservations, the station stops, the level crossing and a car on
/// the road, and the swaps, in fixed steps of 1/60 s. Every few minutes a train is routed by crossovers to the
/// branch's loop and off the screen by the branch, and 10-25 s later another comes in by it and on to the loop the
/// first left; a loop no crossover joins swaps its train in its tunnel's hidden yard. A train's track is a list of
/// segments (a loop, or a branch, crossover or hidden siding) along its own coordinate; on the loop its front is on,
/// that coordinate is the loop's. Deterministic: the same layout runs the same way.
struct Sim {
    static let dt = 1.0 / 60, accel = 8.0, dwell = 30.0, roadSpeed = 11.0 // px/s², s, px/s
    /// The first swap, s; then out to in.
    static let firstSwap = 12.0, gap = 10.0...25.0

    /// A stretch of a train's track along its coordinate: on a loop (whose s is the coordinate plus `off`) or a path
    /// (from its start at `u0`).
    struct Seg {
        var u0: Double, u1: Double, off = 0.0
        let loop: Int?, path: RailPath?
    }

    /// A train's next way off its loop: a crossover, the branch, or its tunnel's hidden yard; or, arriving, in.
    enum Hop: Equatable { case link(Int), out, yard, arrive }

    struct Train {
        let id: Int, consist: Consist
        var loop: Int?, s = 0.0, v: Double, waited = 0.0, stopped = 0.0, dwell = 0.0, served = false
        var segs: [Seg], plan: [Hop] = [], held: [SIMD2<Int>] = []
        /// Where its path lands (loop, s), and where on its coordinate it turned off its loop.
        var entry: (loop: Int, s: Double)?, turn: Double?
        /// When it came, the loop it lives on, and whether an arriving train has been given the road.
        var since = 0.0, home: Int, cleared = false
        var length: Double { consist.length }

        init(id: Int, consist: Consist, loop: Int?, home: Int, t: Double = 0) {
            (self.id, self.consist, self.loop, self.home, since) = (id, consist, loop, home, t)
            v = consist.cruise
            segs = [Seg(u0: -.infinity, u1: .infinity, loop: loop, path: nil)]
        }
    }

    enum Swap { case idle, pending, gap, yard, arriving }

    let lay: Layout, sc: Scenery
    var trains: [Train] = []
    var t = 0.0
    /// Which train holds each diamond group, each block (loop, block), and each crossover.
    var holder: [Int: Int] = [:], blockHolder: [SIMD2<Int>: Int] = [:], linkHolder: [Int: Int] = [:]
    let diamonds: [Crossing]
    var car: (s: Double, v: Double, waited: Double)?
    var road: (P: [SIMD2<Double>], S: [Double], stop: Double)?
    /// The swaps: how long between them (nil: none), the trains that may arrive (`own` the layout's era's), what's
    /// happening and when the next thing does, who, which loop the train that left lived on, and who it was.
    let every: ClosedRange<Double>?, pool: [String], own: [String], wired: Bool
    var swap = Swap.idle, swapAt = Sim.firstSwap, swapWho: Int?, swapHome = 0, swaps = 0, left: String?
    /// The turnouts set for the diverging route (the apex M: set for arriving).
    var reversed: Set<Turnout> = []
    private var nextID = 0

    init(_ lay: Layout, _ sc: Scenery, every: ClosedRange<Double>? = nil, pool: [String] = [], own: [String] = [], wired: Bool = true) {
        (self.lay, self.sc, self.every, self.pool, self.own, self.wired) = (lay, sc, every, pool, own, wired)
        diamonds = lay.cross.filter { $0.kind == .diamond }
        for (li, lp) in lay.loops.enumerated() { for key in lp.keys { trains.append(newTrain(key, loop: li, home: li)) } }
        place()
        setUpRoad()
    }

    private mutating func newTrain(_ key: String, loop: Int?, home: Int) -> Train {
        nextID += 1
        let c = RailArt.consist(key)
        return Train(id: nextID, consist: wired ? c : c.lowered, loop: loop, home: home, t: t)
    }

    /// Start positions: two on one loop with the passenger train at the platform and the other closing up behind;
    /// a wait at a diamond early on; a train coming up to the level crossing.
    private mutating func place() {
        var rng = Dice(lay.seed)
        for i in trains.indices { trains[i].s = rng.uniform(0, lay.loops[trains[i].loop!].L) }
        var used = Set<Int>()
        for li in sc.blocks.keys.sorted() {
            let mine = trains.indices.filter { trains[$0].loop == li }
            guard mine.count >= 2 else { continue } // a loop on the swaps' routes has blocks even with one train
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

    /// The blocks from `lo` to `hi` along loop `li`, in order.
    func walk(_ li: Int, _ lo: Double, _ hi: Double) -> [Int] {
        let n = sc.blocks[li]!.count, last = block(li, hi)
        var out = [block(li, lo)]
        while out[out.count - 1] != last { out.append((out[out.count - 1] + 1) % n) }
        return out
    }

    /// Every block a train stands in, on each loop it's on, and those it was given ahead.
    func standsIn(_ tr: Train) -> [SIMD2<Int>] {
        var out = tr.held
        for g in tr.segs {
            guard let li = g.loop, sc.blocks[li] != nil else { continue }
            let lo = max(tr.s - tr.length, g.u0), hi = min(tr.s, g.u1)
            if lo <= hi { out += walk(li, lo + g.off, hi + g.off).map { SIMD2(li, $0) } }
        }
        return out
    }

    func occupied(_ li: Int, _ k: Int) -> Bool { trains.contains { standsIn($0).contains(SIMD2(li, k)) } }

    /// Whether `train` is within `half` of `sc` (along its loop) or `approach` short of it, and how far ahead it is.
    func zone(_ i: Int, _ sc: Double, _ half: Double, _ approach: Double) -> (Bool, Double) {
        let tr = trains[i]
        guard let li = tr.loop else { return (false, 0) }
        let a = centred(sc - tr.s, lay.loops[li].L)
        return (-(tr.length + half) <= a && a <= half + approach, a)
    }

    var crossingOn: Bool {
        sc.crossings.contains { cr in trains.indices.contains { trains[$0].loop == cr.loop && zone($0, cr.s, 4, 40).0 } }
    }

    // MARK: running

    mutating func step() {
        let dt = Self.dt
        if every != nil { swapTrains() }
        var i = 0
        while i < trains.count {
            guard advance(i) else { continue } // it ran off the edge or into the yard
            defer { i += 1 }
            let brake = trains[i].v * trains[i].v / (2 * Self.accel) + 4
            var target: Double?
            func stop(at x: Double?) { if let x { target = min(target ?? x, x) } }
            guard let li = trains[i].loop else { // its front on a branch or crossover path
                stop(at: onPath(i, brake))
                stop(at: holdBlocks(i, brake))
                move(i, target)
                continue
            }
            let L = lay.loops[li].L
            var need: [Int: [(s: Double, a: Double, half: Double)]] = [:]
            for c in diamonds {
                guard let s0 = c.s(on: li) else { continue }
                let (inside, a) = zone(i, s0, c.half, brake + 6)
                if inside { need[c.group, default: []].append((s0, a, c.half)) }
            }
            for g in need.keys.sorted() {
                if holder[g] == nil {
                    holder[g] = trains[i].id
                } else if holder[g] != trains[i].id {
                    for d in need[g]! where d.a > d.half { stop(at: trains[i].s + d.a - d.half - 4) } // not yet in the box: wait at the home signal
                }
            }
            for g in holder.keys.sorted() where holder[g] == trains[i].id && need[g] == nil { holder[g] = nil }
            stop(at: holdBlocks(i, brake))
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
            if !trains[i].plan.isEmpty, trains[i].turn == nil { stop(at: route(i)) }
            move(i, target)
        }
        if var c = car, let road {
            if crossingOn, c.s < road.stop {
                let gap = road.stop - c.s, allow = gap > 0.3 ? (4 * Self.accel * gap).squareRoot() : 0
                c.v = max(0, min(Self.roadSpeed, c.v + Self.accel * dt, allow))
            } else {
                c.v = min(Self.roadSpeed, c.v + Self.accel * dt)
            }
            if c.v < 0.05 { c.waited += dt }
            c.s += c.v * dt
            if c.s > road.S[road.S.count - 1] + 10 { c.s = -10 }
            car = c
        }
        t += dt
        // keep s small, so days of running don't cost precision
        for i in trains.indices where trains[i].segs.count == 1 {
            guard let li = trains[i].loop, trains[i].s > 4 * lay.loops[li].L else { continue }
            trains[i].s -= 2 * lay.loops[li].L
        }
    }

    private mutating func move(_ i: Int, _ target: Double?) {
        let dt = Self.dt, accel = Self.accel
        if let target {
            let gap = target - trains[i].s, allow = gap > 0.3 ? (2 * accel * gap).squareRoot() : 0
            trains[i].v = max(0, min(trains[i].consist.cruise, trains[i].v + accel * dt, allow))
        } else {
            trains[i].v = min(trains[i].consist.cruise, trains[i].v + accel * dt)
        }
        if trains[i].v < 0.05 { trains[i].waited += dt; trains[i].stopped += dt } else { trains[i].stopped = 0 }
        trains[i].s += trains[i].v * dt
    }

    /// Automatic block signals: hold every block it stands in (on each loop) and was given; into the next block on its
    /// front loop only when no other train holds it, unless it turns off before then. Where to stop, if anywhere.
    private mutating func holdBlocks(_ i: Int, _ brake: Double) -> Double? {
        let tr = trains[i], id = tr.id
        var want = Set(standsIn(tr)), next: SIMD2<Int>?, ahead = 0.0
        if let li = tr.loop, let B = sc.blocks[li] {
            let k = (block(li, tr.s) + 1) % B.count
            ahead = wrap(B[k] - tr.s, lay.loops[li].L)
            let turns = tr.turn.map { ahead > $0 - tr.s } ?? false
            if ahead <= brake + 6, !turns { next = SIMD2(li, k); want.insert(next!) }
        }
        var target: Double?
        for key in want {
            if let who = blockHolder[key] {
                if who != id, key == next { target = tr.s + ahead - 4 }
            } else {
                blockHolder[key] = id
            }
        }
        for key in blockHolder.keys where blockHolder[key] == id && !want.contains(key) { blockHolder[key] = nil }
        return target
    }

    /// Take the blocks `ks` in order as each comes free, keeping those taken (as a train holds its block while it
    /// waits for the next, so a queue on the loop can't starve it): true once it has them all.
    private mutating func claim(_ i: Int, _ ks: [SIMD2<Int>]) -> Bool {
        for k in ks where !trains[i].held.contains(k) {
            if occupied(k.x, k.y) || blockHolder[k].map({ $0 != trains[i].id }) == true { return false }
            blockHolder[k] = trains[i].id
            trains[i].held.append(k)
        }
        return true
    }

    /// At coordinate `u` its front leaves its loop for `path`; then onto `entry`, or off the edge.
    private mutating func divert(_ i: Int, _ u: Double, _ path: RailPath, _ entry: (loop: Int, s: Double)?) {
        trains[i].segs[trains[i].segs.count - 1].u1 = u
        trains[i].segs.append(Seg(u0: u, u1: u + path.L, loop: nil, path: path))
        (trains[i].entry, trains[i].turn) = (entry, u)
    }

    private mutating func letGo(_ id: Int) {
        for g in holder.keys where holder[g] == id { holder[g] = nil }
    }

    /// Keep its segments up to date: onto the next loop when its front reaches a path's end (its coordinate moved
    /// to that loop's), and drop what its rear has passed, setting points back and freeing reservations. False if it
    /// has run off the edge or all into the yard, and is gone.
    private mutating func advance(_ i: Int) -> Bool {
        var tr = trains[i]
        if let g = tr.segs.last, g.path != nil, tr.s >= g.u1, let (Y, sY) = tr.entry {
            let delta = sY - g.u1
            tr.s += delta
            for k in tr.segs.indices { tr.segs[k].u0 += delta; tr.segs[k].u1 += delta; tr.segs[k].off -= delta }
            tr.segs.append(Seg(u0: sY, u1: .infinity, loop: Y, path: nil))
            (tr.entry, tr.turn, tr.cleared) = (nil, nil, false)
            if !tr.plan.isEmpty { tr.plan.removeFirst() }
        }
        tr.loop = (tr.segs.first { $0.u0 <= tr.s && tr.s < $0.u1 } ?? tr.segs[tr.segs.count - 1]).loop
        let rear = tr.s - tr.length
        while tr.segs.count > 1, tr.segs[0].u1 <= rear {
            let h = tr.segs.removeFirst()
            if let path = h.path {
                if let x = lay.links.firstIndex(where: { $0.path === path }) {
                    linkHolder[x] = nil; reversed.remove(.link(x)); tr.held = []
                } else if path === lay.branch?.inn {
                    reversed.remove(.A); tr.held = []
                } else if sc.yards.values.contains(where: { $0.inn === path }) {
                    tr.held = []
                }
            } else if tr.segs[0].path === lay.branch?.out {
                reversed.remove(.D)
            }
        }
        trains[i] = tr
        let last = tr.segs[tr.segs.count - 1]
        let gone = last.path === lay.branch?.out && rear >= last.u1 - 2, hidden = last.path?.hidden == true && last.path !== yardIn(of: last.path) && rear >= last.u0 + 1
        guard gone || hidden else { return true }
        for key in blockHolder.keys where blockHolder[key] == tr.id { blockHolder[key] = nil }
        letGo(tr.id)
        trains.remove(at: i)
        if gone {
            var rng = Dice(lay.seed &* 17 &+ swaps)
            (swap, swapAt) = (.gap, t + rng.uniform(Self.gap.lowerBound, Self.gap.upperBound))
        } else {
            (swap, swapAt) = (.yard, t)
        }
        return false
    }

    /// The path itself if it's a yard's way out of the tunnel (trains come off it, they don't vanish into it).
    private func yardIn(of path: RailPath?) -> RailPath? { sc.yards.values.first { $0.inn === path }?.inn }

    /// Its next hop off this loop: within 60 of the turnout, take it if it's free, else stop short of it. For a
    /// crossover: the crossover itself and the two blocks from where it lands, as at a diamond's home signal.
    private mutating func route(_ i: Int) -> Double? {
        guard let li = trains[i].loop, let hop = trains[i].plan.first else { return nil }
        let L = lay.loops[li].L
        let sT: Double
        switch hop {
        case .out: sT = lay.branch!.sD
        case .yard: sT = sc.yards[li]!.sD
        case .link(let x): sT = lay.links[x].sa
        case .arrive: return nil
        }
        let a = wrap(sT - trains[i].s, L)
        guard 0 < a, a < 60 else { return nil }
        switch hop {
        case .yard:
            letGo(trains[i].id)
            divert(i, trains[i].s + a, sc.yards[li]!.out, nil)
            left = trains[i].consist.key
        case .out:
            letGo(trains[i].id)
            divert(i, trains[i].s + a, lay.branch!.out, nil)
            reversed.insert(.D); reversed.remove(.M)
            left = trains[i].consist.key
        case .link(let x):
            let link = lay.links[x], kY = block(link.b, link.sb), n = sc.blocks[link.b]!.count
            guard linkHolder[x].map({ $0 == trains[i].id }) ?? true, claim(i, [SIMD2(link.b, kY), SIMD2(link.b, (kY + 1) % n)]) else { return trains[i].s + a - 4 }
            linkHolder[x] = trains[i].id; reversed.insert(.link(x))
            divert(i, trains[i].s + a, link.path, (link.b, link.sb))
        case .arrive: break
        }
        return nil
    }

    /// Its front on a path: an arriving train stops at the branch's home signal (or out of sight in the yard)
    /// until it has the junction and the two blocks from where it joins the loop.
    private mutating func onPath(_ i: Int, _ brake: Double) -> Double? {
        guard !trains[i].cleared, let g = trains[i].segs.last, let path = g.path else { return nil }
        let home: Double, B: Int, sA: Double
        if let br = lay.branch, path === br.inn {
            (home, B, sA) = (br.home, br.loop, br.sA)
        } else if let y = sc.yards.values.first(where: { $0.inn === path }) {
            (home, B, sA) = (y.home, y.loop, y.sA)
        } else {
            return nil
        }
        let gap = g.u0 + home - trains[i].s
        guard gap <= brake + 6 else { return nil }
        let kA = block(B, sA), n = sc.blocks[B]!.count
        if claim(i, [SIMD2(B, kA), SIMD2(B, (kA + 1) % n)]) {
            trains[i].cleared = true
            if path === lay.branch?.inn { reversed.insert(.A); reversed.insert(.M) }
            return nil
        }
        return trains[i].s + gap
    }

    /// Whether an arriving train has been given the road onto the layout by the branch's home signal.
    var branchClear: Bool { trains.contains { $0.cleared && $0.segs.last?.path === lay.branch?.inn } }

    // MARK: swaps

    /// The crossovers from loop `from` to loop `to`, breadth first; nil if there's no way.
    func hops(_ from: Int, _ to: Int) -> [Int]? {
        var prev: [Int: Int?] = [from: nil], todo = [from]
        while !todo.isEmpty, prev[to] == nil {
            let li = todo.removeFirst()
            for (x, link) in lay.links.enumerated() where link.a == li && prev[link.b] == nil { prev[link.b] = x; todo.append(link.b) }
        }
        guard prev[to] != nil else { return nil }
        var out: [Int] = [], li = to
        while let x = prev[li] ?? nil { out.append(x); li = lay.links[x].a }
        return out.reversed()
    }

    /// Who arrives: half the time one of the layout's own era, else one from the whole pool; never one on the layout,
    /// nor (if there's a choice) the one that just left; fit for every loop and crossover on its way (and the
    /// branch's curves if it comes by the branch), and never one whose diamond zones would cover its loop.
    private func arrival(_ way: [Int], _ links: [Int]?, _ rng: inout Dice) -> String {
        let here = Set(trains.map { $0.consist.key.split(separator: "#")[0] })
        func fits(_ k: String) -> Bool {
            let c = RailArt.consist(k)
            if here.contains(Substring(k)) || lay.covers(way[way.count - 1], length: c.length, cruise: c.cruise) { return false }
            if way.contains(where: { c.minRadius > lay.loops[$0].rmin / 0.98 + 1e-6 || c.length > (sc.planLength[$0] ?? 0) + 1e-6 }) { return false }
            if let links, let br = lay.branch, c.minRadius > br.R + 1e-6 { return false }
            return (links ?? []).allSatisfy { c.minRadius <= lay.links[$0].R + 1e-6 }
        }
        let lists = rng.chance(0.5) ? [own, pool] : [pool, own]
        for keys in lists {
            let c = keys.filter { fits($0) && $0 != left }
            if !c.isEmpty { return rng.pick(c.sorted()) }
        }
        let c = Set(pool + own).filter(fits)
        return c.isEmpty ? left ?? trains[0].consist.key : rng.pick(c.sorted())
    }

    /// Every few minutes pick the train that's been on the layout longest (farthest from the branch first): if its
    /// loop is joined to the branch and the way out has room on every loop it passes (`capacity`), route it by
    /// crossovers off by the branch, and 10-25 s after it has gone send its replacement in, back to the loop it
    /// left; if its loop can't reach the branch but has a tunnel, it runs into the hidden yard and, once its last car
    /// is in, its replacement comes out.
    private mutating func swapTrains() {
        guard let every else { return }
        var rng = Dice(lay.seed &* 31 &+ swaps)
        switch swap {
        case .idle where t >= swapAt:
            var count: [Int: Int] = [:]
            for tr in trains { if let li = tr.loop { count[li, default: 0] += 1 } }
            var best: (key: (Double, Int, Int), i: Int, plan: [Hop], ahead: Double)?
            for (i, tr) in trains.enumerated() where tr.plan.isEmpty && tr.segs.count == 1 {
                guard let li = tr.loop else { continue }
                let plan: [Hop], first: Double, far: Int
                if let br = lay.branch, let xs = hops(li, br.loop), !xs.contains(where: { x in
                    count[lay.links[x].b, default: 0] >= sc.capacity[lay.links[x].b] ?? 2 || tr.length > (sc.planLength[lay.links[x].b] ?? 0) + 1e-6
                }) {
                    (plan, first, far) = (xs.map { .link($0) } + [.out], xs.first.map { lay.links[$0].sa } ?? br.sD, xs.count)
                } else if let y = sc.yards[li] {
                    (plan, first, far) = ([.yard], y.sD, 0)
                } else {
                    continue
                }
                let key = (tr.since, -far, tr.id)
                if best == nil || key < best!.key { best = (key, i, plan, wrap(first - tr.s, lay.loops[li].L)) }
            }
            guard let best, best.ahead >= 70 else { return } // the oldest goes; if it's too close to its turnout, wait
            trains[best.i].plan = best.plan
            (swap, swapWho, swapHome) = (.pending, trains[best.i].id, trains[best.i].loop!)
        case .gap where t >= swapAt:
            guard let br = lay.branch else { return }
            let xs = hops(br.loop, swapHome) ?? []
            var tr = newTrain(arrival([br.loop] + xs.map { lay.links[$0].b }, xs, &rng), loop: nil, home: swapHome)
            tr.segs = [Seg(u0: 0, u1: br.inn.L, loop: nil, path: br.inn)]
            (tr.entry, tr.s, tr.plan) = ((br.loop, br.sA), tr.length + 2, [.arrive] + xs.map { .link($0) })
            trains.append(tr)
            (swap, swapWho) = (.arriving, tr.id)
        case .yard:
            guard let y = sc.yards[swapHome] else { swap = .idle; return }
            var tr = newTrain(arrival([swapHome], nil, &rng), loop: nil, home: swapHome)
            tr.segs = [Seg(u0: 0, u1: y.inn.L, loop: nil, path: y.inn)]
            (tr.entry, tr.s, tr.plan) = ((swapHome, y.sA), tr.length + 2, [.arrive])
            trains.append(tr)
            (swap, swapWho) = (.arriving, tr.id)
        case .arriving:
            if let tr = trains.first(where: { $0.id == swapWho }), !(tr.plan.isEmpty && tr.segs.count == 1) { return }
            swaps += 1
            var next = Dice(lay.seed &* 31 &+ swaps)
            (swap, swapAt) = (.idle, t + next.uniform(every.lowerBound, every.upperBound))
        default: break
        }
    }

    // MARK: drawing

    /// Where a train's track is at its coordinate `x`, on whichever loop or path that is, and whether it's hidden.
    func at(_ tr: Train, _ x: Double) -> (p: SIMD3<Double>, t: SIMD2<Double>, hidden: Bool) {
        let g = tr.segs.first { $0.u0 <= x && x < $0.u1 } ?? (x < tr.segs[0].u0 ? tr.segs[0] : tr.segs[tr.segs.count - 1])
        if let li = g.loop { let (p, t) = lay.loops[li].at(x + g.off); return (p, t, false) }
        let (p, t) = g.path!.at(x - g.u0)
        return (p, t, g.path!.hidden)
    }

    /// Every vehicle that shows: where its middle is (between its bogies, which ride the rails), its heading and
    /// slope, and whether it leads its train.
    func poses() -> [(vehicle: RailVehicle, c: SIMD3<Double>, heading: Double, slope: Double, lead: Bool)] {
        var out: [(RailVehicle, SIMD3<Double>, Double, Double, Bool)] = []
        for tr in trains {
            var d = 0.0
            for (k, v) in tr.consist.vehicles.enumerated() {
                let mid = tr.s - d - Double(v.length) / 2, b = v.bogies * Double(v.length)
                let f = at(tr, mid + b / 2), r = at(tr, mid - b / 2)
                d += Double(v.length) + (k + 1 < tr.consist.vehicles.count ? Double(Consist.gap(v, tr.consist.vehicles[k + 1])) : 2)
                if f.hidden || r.hidden { continue }
                out.append((v, (f.p + r.p) / 2, atan2(f.p.y - r.p.y, f.p.x - r.p.x), (f.p.z - r.p.z) / max(b, 1e-6), k == 0))
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
