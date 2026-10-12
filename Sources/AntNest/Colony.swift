import Foundation
import simd

/// An ant's build, in body lengths: x forward, y up, z to its left. Measured off a harvester ant (docs/ant-colony.md):
/// where each part of the body is and how big, where the legs leave it, each leg's three lengths, where each foot
/// rests, how high the body rides, and its stride.
public enum Build {
    /// Head, mesosoma, gaster: centre x and y, half length, half height, tilt in degrees.
    public static let head = (x: 0.300, y: 0.030, a: 0.108, b: 0.090, tilt: -20.0), chest = (x: 0.045, y: 0.028, a: 0.150, b: 0.066, tilt: 8.0)
    public static let gaster = (x: -0.345, y: -0.004, a: 0.158, b: 0.112, tilt: -6.0)
    /// The two nodes of the waist: x, y and radius.
    public static let waist = [(x: -0.125, y: 0.004, r: 0.034), (x: -0.188, y: 0.0, r: 0.040)]
    static let hips = [SIMD2(0.125, -0.030), SIMD2(0.045, -0.040), SIMD2(-0.045, -0.034)]
    static let femur = [0.21, 0.23, 0.28], tibia = [0.20, 0.23, 0.30], tarsus = [0.19, 0.21, 0.26]
    /// Where each foot rests: along the body, and out to the side.
    static let foot = [SIMD2(0.36, 0.30), SIMD2(0.03, 0.47), SIMD2(-0.38, 0.37)]
    /// How high the body's middle rides, how far the nose is pitched up (degrees), and a swinging foot's lift.
    public static let clear = 0.155, pitch = 5.0, lift = 0.07
    static let scape = 0.19, funiculus = 0.27
    /// Stride length at `pace` body lengths a second, and the share of a stride a foot is down: both measured on
    /// desert ants (Wahl, Pfeffer & Wittlinger 2015) and scaled to this ant's shorter legs.
    static func stride(at pace: Double) -> Double { 0.60 + 0.023 * pace }
    static func duty(at pace: Double) -> Double { max(0.5, 0.68 - 0.02 * pace) }
    /// Each leg's place in the stride: alternating tripods, the middle leg landing a little early and the hind late.
    static let offsets: [Double] = (0..<6).map { leg in
        let (left, k) = (leg < 3, leg % 3)
        return ((k != 1) == left ? 0.0 : 0.5) + [0.0, -0.03, 0.04][k]
    }
}

/// One ant: what it is doing, where it is in the nest, and where its body and feet are in the tank.
public struct Ant: Sendable {
    public enum State: Sendable { case walk, pause, idle, dig, drop, feel }
    enum Job: Equatable, Sendable { case none, dig(Int), dump, rest, wander }
    struct Leg: Sendable { var branch: Int, to: Double, hop: (branch: Int, at: Double)? }
    struct Foot: Sendable {
        /// Where it is planted, in cells; nil while it moves. And where it is now, in the body's own measure.
        var hold: SIMD2<Double>?, now = SIMD3<Double>(repeating: 0)
    }

    public let id: Int
    var branch = -1, at = 0.0, heading = 1.0, route: [Leg] = [], job = Job.none
    public internal(set) var state = State.pause
    var timer = 0.0, bout = 0.0, cool = 0.0, stalled = 0.0, tempo = 1.0
    /// Body lengths a second while it walks, and how far through a stride it is.
    var pace = 1.0, phase = 0.0
    /// Whether it has been put in the tank, the path its middle took (distance gone, point), and the way to the
    /// wall it walks on.
    var placed = false, trail: [(gone: Double, point: SIMD2<Double>)] = [], gone = 0.0, wall = SIMD2<Double>(0, 1)
    /// How far its middle is from the tunnel's centre line, in cells, to the left of the way the tunnel runs; and
    /// how far along the tunnel it has walked since that was last looked at.
    var lateral = 0.0, stepped = 0.0
    var ceiling = 0.0, crossing = 0, turning = 0.0, rolling = 0.0
    var feet: [Foot] = []

    /// The middle of its body, in cells (y down); which way it faces; and which way is up for it, away from the
    /// wall it stands on.
    public internal(set) var position = SIMD2<Double>(0, 0), forward = SIMD2<Double>(1, 0), up = SIMD2<Double>(0, -1)
    /// How far round it has turned when turning about, in radians (0 when not): the body is seen end on at a quarter
    /// turn either way, which is where its head and tail change places.
    public internal(set) var yaw = 0.0
    /// 1 when its feet are toward `up`'s other side as usual; on its way from -1 to 1 while it crosses from one wall
    /// of a tunnel to the other, which it does rolling over: it is the cosine of how far it has still to roll, so
    /// half-way it is seen from above, legs out to both sides, and then comes back the other way up.
    public internal(set) var flat = 1.0
    /// The antennae's clock, how far the head is dipped (digging, dropping), and whether it carries a grain.
    public internal(set) var feel = 0.0, nod = 0.0, carrying = false

    /// Its six claws in its own measure (left front, middle, hind, then right).
    public var claws: [SIMD3<Double>] { feet.map(\.now) }
    /// Where each planted foot is planted, in cells; nil for one in the air.
    public var holds: [SIMD2<Double>?] { feet.map(\.hold) }

    /// Its legs and antennae as lines in the tank, in cells: for each leg the hip, knee, ankle and claw, and for
    /// each antenna its root, elbow and tip. The first three legs and the first antenna are the near side's.
    public func limbs(bodyLength bl: Double) -> (legs: [[SIMD2<Double>]], antennae: [[SIMD2<Double>]]) {
        func place(_ p: SIMD3<Double>) -> SIMD2<Double> { point(p, bodyLength: bl) }
        func pitched(_ x: Double, _ y: Double, _ z: Double) -> SIMD3<Double> { Self.pitched(x, y, z) }
        var legs: [[SIMD2<Double>]] = []
        for leg in 0..<min(6, feet.count) {
            let side = leg < 3 ? 1.0 : -1.0, k = leg % 3, out = k == 0 ? 1.0 : k == 1 ? 0.0 : -1.0
            let claw = feet[leg].now
            let ankle = claw - simd_normalize(SIMD3(0.45 * out, -0.30, 0.80 * side)) * (Build.tarsus[k] * 0.55), hip = pitched(Build.hips[k].x, Build.hips[k].y, side * 0.035)
            let knee = Self.knee(hip, ankle, Build.femur[k], Build.tibia[k] + Build.tarsus[k] * 0.45, toward: SIMD3(0.2 * out, 0.5, side))
            legs.append([hip, knee, ankle, claw].map(place))
        }
        var antennae: [[SIMD2<Double>]] = []
        let root = (x: Build.head.x + 0.07, y: Build.head.y + 0.045 - nod)
        for side in [1.0, -1.0] {
            let sweep = sin(feel + (side > 0 ? 0 : 2.1))
            let (a, b) = ((38 + 9 * sweep) * .pi / 180, (-32 + 16 * sin(feel * 1.7 + side)) * .pi / 180)
            let elbow = SIMD3(root.x + Build.scape * cos(a) * 0.8, root.y + Build.scape * sin(a), side * (0.05 + Build.scape * 0.6))
            let tip = elbow + SIMD3(Build.funiculus * cos(b) * 0.9, Build.funiculus * sin(b), side * Build.funiculus * (0.25 + 0.15 * sweep))
            antennae.append([pitched(root.x, root.y, side * 0.04), pitched(elbow.x, elbow.y, elbow.z), pitched(tip.x, tip.y, tip.z)].map(place))
        }
        return (legs, antennae)
    }

    /// Where a point of its own measure (forward, up, to its left) is in the tank, in cells, seen from the side:
    /// turned with it when it turns about, and rolled with it when it rolls over, when its left and right come
    /// round to where its up and down were (always the same way round in the tank, whichever wall `up` is from).
    public func point(_ p: SIMD3<Double>, bodyLength bl: Double) -> SIMD2<Double> {
        let across = SIMD2(forward.y, -forward.x) * (p.z * max(1 - flat * flat, 0).squareRoot())
        return position + (forward * (p.x * cos(yaw) + p.z * sin(yaw)) + up * (p.y * flat) + across) * bl
    }

    /// A point of the body as it is carried, nose up by `Build.pitch`.
    static func pitched(_ x: Double, _ y: Double, _ z: Double) -> SIMD3<Double> {
        let tilt = Build.pitch * .pi / 180
        return SIMD3(x * cos(tilt) - y * sin(tilt), x * sin(tilt) + y * cos(tilt), z)
    }

    /// Where a grain it carries is held, in front of its jaws, in cells.
    public func mouth(bodyLength bl: Double) -> SIMD2<Double> {
        point(Self.pitched(Build.head.x + Build.head.a * 0.78 + 0.07, Build.head.y - Build.head.b * 0.75 - 0.01 - nod, 0), bodyLength: bl)
    }

    /// The knee between a hip and an ankle for two bones of lengths `a` and `b`, bent toward `pole`.
    static func knee(_ hip: SIMD3<Double>, _ ankle: SIMD3<Double>, _ a: Double, _ b: Double, toward pole: SIMD3<Double>) -> SIMD3<Double> {
        let d = ankle - hip, far = max(simd_length(d), 1e-6), reach = min(max(far, abs(a - b) + 1e-4), a + b - 1e-4)
        let e = d / far, along = (reach * reach + a * a - b * b) / (2 * reach), h = max(a * a - along * along, 0).squareRoot()
        let side = pole - e * simd_dot(pole, e)
        return hip + e * along + side / max(simd_length(side), 1e-6) * h
    }
}

/// The ants living in a nest. They do not dig it: its history is baked (`Nest`), and at each share of the digging
/// the ants are sent to the faces that history says are being worked, a face nobody is at before any other task.
/// An ant goes to a face and digs, one at a time with up to two more waiting or on their way, carries a grain up
/// and drops it on the spoil, rests in a room, or wanders; it walks in bouts with stops; two that meet stop and
/// touch antennae, and one takes the other wall to pass (docs/ant-colony.md has the measured behaviour these
/// follow). The colony grows with its nest: a few ants at first, the number asked for when it is grown; and
/// someone is always walking.
///
/// How an ant is put in the tank. Its place in the nest is a point of a tunnel's centre line; its body's middle
/// is on the line across the tunnel through that point, as far toward the wall it walks on as leaves it riding
/// just clear of the wall (`berth`). That stretch of the line is open by construction, so a body's middle is
/// never over undug medium, and its head and gaster are kept clear wherever the tunnel leaves room. It faces the
/// way its middle has come over the last half body length, so it turns THROUGH a corner. Each foot is planted on
/// the wall itself and stays put while the body moves over it, then swings to its next hold; the stride is driven
/// by how far the body really moved. A foot never jumps (one out of reach steps to a new hold at a walking foot's
/// speed); turning about, the body goes round on the spot, seen end on half-way; crossing to the other wall of a
/// tunnel, it rolls over as it goes. Everything moves in sixtieths of a second, however many a frame holds, so it
/// is the same at any frame rate. Every ant is seen from the side.
// ponytail: in a real thin tank some ants walk on the glass and are seen from above; left out, because changing
// from one view to the other at a tunnel's mouth is a pop. Add them when a turn onto the glass is drawn.
public struct Colony: Sendable {
    public let nest: Nest
    public private(set) var ants: [Ant] = []
    /// Grains dropped on the spoil and still lying there: the column, and when.
    public private(set) var grains: [(x: Double, at: Double)] = []
    /// The number of ants when the nest is grown, how much they do (1 is the standard), and the seconds gone.
    public let most: Int
    public var activity = 1.0
    public private(set) var time = 0.0
    /// How many times an ant, held up two seconds, has given up what it was doing; and how many times one's middle
    /// has gone straight to where it belongs because the way there was not open (both for the tests).
    public private(set) var gaveUp = 0, leapt = 0
    /// The share of the digging done, as of the last moment stepped.
    public private(set) var share: Double
    private var dice: Dice
    private let bl: Double
    private var ways: [Int: [(at: Double, to: Int, toAt: Double, opened: Double)]] = [:]
    /// The furthest point each branch ever opens.
    private let last: [Int]
    public static let tick = 1.0 / 60

    public init(nest: Nest, most: Int, seed: UInt64, share: Double) {
        (self.nest, self.most, self.share, bl) = (nest, most, share, nest.bodyLength)
        dice = Dice(seed: seed ^ 0xA5A5_5A5A)
        for link in nest.links {
            ways[link.a, default: []].append((link.at, link.b, link.to, link.opened))
            ways[link.b, default: []].append((link.to, link.a, link.at, link.opened))
        }
        last = nest.branches.map { branch in branch.opened.lastIndex { $0 <= 1 } ?? 0 }
        for _ in 0..<count(at: share) { arrive(at: ashore(dice.uniform(0.08, 0.92) * Double(nest.cols))) }
    }

    /// How many ants the colony has when `share` of the digging is done: four on bare sand, all of them at the end.
    public func count(at share: Double) -> Int { max(min(4, most), min(most, Int((Double(most) * (0.15 + 0.85 * share)).rounded()))) }

    /// A place on the surface to stop at: column `x`, or the nearest a body length and a half from the middle of a
    /// mouth, where there is something to stand on.
    private func ashore(_ x: Double) -> Double {
        guard let mouth = nest.entrances.min(by: { abs($0 - x) < abs($1 - x) }), abs(x - mouth) < 1.5 * bl else { return x }
        return min(max(mouth + (x < mouth ? -1.5 : 1.5) * bl, 0), Double(nest.cols) - 1)
    }

    /// A new ant, on the surface at column `x`.
    private mutating func arrive(at x: Double) {
        var ant = Ant(id: ants.count)
        (ant.at, ant.heading, ant.timer) = (x, x < Double(nest.cols) / 2 ? 1 : -1, dice.uniform(0, 3))
        (ant.phase, ant.feel, ant.tempo) = (dice.unit(), dice.uniform(0, 6), dice.uniform(0.8, 1.25))
        ants.append(ant)
        settle(ants.count - 1)
    }

    /// One sixtieth of a second (`tick`), with `share` of the digging done at its end.
    public mutating func step(share: Double) { tick(share: share) }

    /// The ants as they would be found some minutes on, with `share` of the digging done: `seconds` of going about
    /// their work in steps of a tenth of a second, with nothing drawn, then two seconds at the usual pace so that
    /// feet are planted and bodies turned.
    public mutating func fastForward(_ seconds: Double, share: Double? = nil) {
        for _ in 0..<Int(seconds * 10) { tick(share: share ?? self.share, coarse: 0.1) }
        for _ in 0..<120 { tick(share: share ?? self.share) }
    }

    // MARK: - The network at a share of the digging

    /// How far along a branch is open: the index of its face.
    func reach(_ branch: Int, _ share: Double) -> Double {
        let opened = nest.branches[branch].opened
        var (low, high) = (0, opened.count)
        while low < high { let mid = (low + high) / 2; if opened[mid] <= share { low = mid + 1 } else { high = mid } }
        return Double(low) - 1
    }

    /// The branches being dug: each with the index of its face.
    public func faces(at share: Double) -> [(branch: Int, at: Double)] {
        nest.branches.indices.compactMap { k in
            let r = reach(k, share)
            return nest.branches[k].opened[0] <= share && r > 0.5 * bl && r < Double(last[k]) - 0.5 ? (k, r) : nil
        }
    }

    /// A route for an ant to a point of a branch over the ways open now. False if there is none.
    private func plan(_ ant: inout Ant, to branch: Int, at: Double) -> Bool {
        if ant.branch == branch { ant.route = [Ant.Leg(branch: branch, to: at, hop: nil)]; return true }
        var from: [Int: (branch: Int, at: Double, toAt: Double)] = [:], seen: Set<Int> = [ant.branch], queue = [ant.branch], head = 0
        while head < queue.count, !seen.contains(branch) {
            let b = queue[head]; head += 1
            for way in ways[b] ?? [] where !seen.contains(way.to) && way.opened <= share {
                if b >= 0, way.at > reach(b, share) - 0.3 * bl { continue }
                if way.to >= 0, way.toAt > reach(way.to, share) - 0.3 * bl { continue }
                from[way.to] = (b, way.at, way.toAt)
                seen.insert(way.to)
                queue.append(way.to)
            }
        }
        guard seen.contains(branch) else { return false }
        var legs = [Ant.Leg(branch: branch, to: at, hop: nil)], b = branch
        while let step = from[b] {
            legs.append(Ant.Leg(branch: step.branch, to: step.at, hop: (b, step.toAt)))
            b = step.branch
        }
        ant.route = legs.reversed()
        return true
    }

    /// A point of a branch's centre line and the way it runs there, in cells; for the surface (branch -1), the
    /// spoil's own line at column `at`.
    func line(_ branch: Int, _ at: Double) -> (point: SIMD2<Double>, along: SIMD2<Double>) {
        if branch < 0 {
            let x = min(max(at, 1.5), Double(nest.cols) - 2.5)
            let slope = -(nest.surface(x + 2.5, at: share) - nest.surface(x - 2.5, at: share)) / 5
            return (SIMD2(x, Double(nest.ground) - nest.surface(x, at: share)), simd_normalize(SIMD2(1, slope)))
        }
        let points = nest.branches[branch].points, s = min(max(at, 0), Double(points.count) - 1.001), i = Int(s)
        func run(_ i: Int) -> SIMD2<Double> { points[min(i + 4, points.count - 1)] - points[max(i - 3, 0)] }
        let along = simd_mix(run(i), run(i + 1), SIMD2(repeating: s - Double(i)))
        return (simd_mix(points[i], points[min(i + 1, points.count - 1)], SIMD2(repeating: s - Double(i))), simd_length(along) > 0 ? simd_normalize(along) : SIMD2(0, 1))
    }

    /// The distance in cells from `point` along `way` to the first cell of undug sand (or the side of the tank);
    /// `far` if there is none that near.
    func wall(from point: SIMD2<Double>, along way: SIMD2<Double>, upTo far: Double) -> Double {
        var d = 0.0
        while d < far {
            let p = point + way * d
            if p.y >= Double(nest.ground) || p.x < 0 || p.x >= Double(nest.cols), nest.solid(p.x, p.y, at: share) { return d }
            d += 0.4
        }
        return far
    }

    // MARK: - What an ant does

    /// A place along a branch to stop at with something to stand on: of a few tries, the first where a wall is
    /// where the tunnel's own should be, and not the mouth of a shaft in a room's floor.
    private mutating func footing(_ branch: Int, upTo reach: Double) -> Double {
        var at = 0.0
        for _ in 0..<5 {
            at = dice.uniform(0.5 * bl, max(reach - 0.6 * bl, 0.6 * bl))
            let on = line(branch, at), across = SIMD2(-on.along.y, on.along.x), radii = nest.branches[branch].radius
            let near = min(wall(from: on.point, along: across, upTo: 3 * bl), wall(from: on.point, along: -across, upTo: 3 * bl))
            if near < radii[min(Int(at), radii.count - 1)] + 0.4 * bl { break }
        }
        return at
    }

    private mutating func choose(_ n: Int) {
        var ant = ants[n]
        defer { ants[n] = ant }
        let open = nest.branches.indices.compactMap { k in let r = reach(k, share); return r > 1.4 * bl ? (branch: k, reach: r) : nil }
        var busy: [Int: Int] = [:]
        for other in ants { if case .dig(let face) = other.job { busy[face, default: 0] += 1 } }
        let free = faces(at: share).filter { busy[$0.branch, default: 0] < 3 }.sorted { busy[$0.branch, default: 0] < busy[$1.branch, default: 0] }
        let roll = dice.unit(), bare = free.first { busy[$0.branch] == nil }
        var found = false
        if !free.isEmpty, roll < 0.65 * activity || bare != nil {
            // a face nobody is at comes before any other task: a face is not left to dig itself
            let face = bare ?? free[0] // (and then the face with the fewest at it or on their way)
            ant.job = .dig(face.branch)
            found = plan(&ant, to: face.branch, at: max(face.at - (bare != nil ? 0.8 : 2.0) * bl, 0))
        }
        if !found, roll < 0.65 * activity + 0.2 {
            let rooms = open.filter { nest.branches[$0.branch].room }, places = rooms.isEmpty ? open : rooms
            ant.job = .rest
            if !places.isEmpty, dice.chance(0.85) {
                let place = places[dice.below(places.count)]
                found = plan(&ant, to: place.branch, at: footing(place.branch, upTo: place.reach))
            } else { found = plan(&ant, to: -1, at: ashore(dice.uniform(0.05, 0.95) * Double(nest.cols))) }
        }
        if !found {
            ant.job = .wander
            if !open.isEmpty, dice.chance(0.8) {
                let place = open[dice.below(open.count)]
                found = plan(&ant, to: place.branch, at: footing(place.branch, upTo: place.reach))
            }
            if !found { found = plan(&ant, to: -1, at: ashore(dice.uniform(0.05, 0.95) * Double(nest.cols))) }
        }
        guard found else { (ant.job, ant.state, ant.timer) = (.none, .pause, dice.uniform(1, 4)); return }
        (ant.state, ant.bout, ant.pace) = (.walk, dice.uniform(1.5, 5), dice.uniform(0.7, 1.4) * ant.tempo)
    }

    private mutating func arrived(_ n: Int) {
        switch ants[n].job {
        case .dig(let face):
            // one at a time at the face: the second waits two body lengths back until the first has left with its grain
            let spot = max(reach(face, share) - 0.8 * bl, 0)
            if ants.contains(where: { $0.id != n && $0.state == .dig && $0.branch == face }) {
                (ants[n].state, ants[n].timer) = (.pause, dice.uniform(1, 2.5))
            } else if ants[n].branch == face, ants[n].at < spot - 0.3 * bl {
                (ants[n].route, ants[n].state, ants[n].bout) = ([Ant.Leg(branch: face, to: spot, hop: nil)], .walk, dice.uniform(2, 5))
            } else { (ants[n].state, ants[n].timer) = (.dig, dice.uniform(10, 25)) }
        case .dump: (ants[n].state, ants[n].timer) = (.drop, 1.2)
        case .rest: (ants[n].state, ants[n].timer, ants[n].job) = (.idle, dice.uniform(20, 90) / max(activity, 0.2), .none)
        default: (ants[n].state, ants[n].timer, ants[n].job) = (.pause, dice.uniform(0.5, 3), .none)
        }
    }

    /// Sends an ant with a grain out to the spoil by the mouth nearest it.
    private mutating func carryOut(_ n: Int) {
        var ant = ants[n]
        (ant.nod, ant.carrying, ant.job) = (0, true, .dump)
        let mouth = nest.entrances.min { abs($0 - ant.position.x) < abs($1 - ant.position.x) } ?? 0
        let x = mouth + dice.sign() * dice.uniform(1.6, 3.6) * bl
        if !plan(&ant, to: -1, at: min(max(x, 2 * bl), Double(nest.cols) - 2 * bl)) { (ant.carrying, ant.job, ant.route) = (false, .none, []) }
        (ant.state, ant.bout, ant.pace) = (.walk, dice.uniform(3, 7), dice.uniform(0.8, 1.2) * ant.tempo)
        ants[n] = ant
    }

    private mutating func tick(share now: Double, coarse: Double? = nil) {
        let dt = coarse ?? Self.tick
        (share, time) = (now, time + dt)
        grains.removeAll { time - $0.at > 45 }
        // a new ant comes in along the surface from the side of the tank
        if ants.count < count(at: share), coarse != nil || dice.chance(dt / 4) { arrive(at: dice.chance(0.5) ? 0 : Double(nest.cols)) }
        for n in ants.indices {
            ants[n].feel += dt * (ants[n].state == .feel ? 12 : ants[n].state == .walk || ants[n].state == .dig ? 5 : 1.6)
            ants[n].cool = max(0, ants[n].cool - dt)
            while ants[n].branch >= 0, reach(ants[n].branch, share) < 0.5 { // its tunnel is not dug (the clock was set back): out to where it joins
                let branch = nest.branches[ants[n].branch]
                (ants[n].branch, ants[n].at, ants[n].route, ants[n].job, ants[n].placed) = (branch.parent, branch.at, [], .none, false)
            }
            if ants[n].branch >= 0 { ants[n].at = min(ants[n].at, max(reach(ants[n].branch, share) - 0.45 * bl, 0)) }
            if ants[n].turning > 0 { continue }
            switch ants[n].state {
            case .walk: walk(n, dt)
            case .dig:
                ants[n].timer -= dt
                ants[n].nod = 0.03 * (1 + sin(time * 2 * .pi * 2.2 + Double(n)))
                ants[n].at = max(min(reach(ants[n].branch, share) - 0.8 * bl, ants[n].at + 0.3 * bl * dt), 0) // creep on as the face moves
                if ants[n].timer <= 0 { carryOut(n) }
            case .drop:
                ants[n].timer -= dt
                ants[n].nod = 0.05 * sin(min(1, (1.2 - ants[n].timer) / 0.6) * .pi)
                if ants[n].carrying, ants[n].timer < 0.6 {
                    ants[n].carrying = false
                    grains.append((ants[n].position.x + ants[n].forward.x * 0.45 * bl, time))
                }
                if ants[n].timer <= 0 { (ants[n].nod, ants[n].job, ants[n].state, ants[n].timer) = (0, .none, .pause, dice.uniform(0.4, 1.5)) }
            case .pause, .idle, .feel:
                ants[n].timer -= dt
                guard ants[n].timer <= 0 else { break }
                if !ants[n].route.isEmpty { (ants[n].state, ants[n].bout) = (.walk, dice.uniform(1.5, 5)) }
                else if case .dig = ants[n].job { arrived(n) } // waiting its turn at a face: look again
                else { choose(n) }
            }
        }
        if coarse == nil { meetings() }
        // never all still: with a handful of ants there are moments when none is walking; then the one due to move soonest goes now
        if coarse == nil, !ants.contains(where: { $0.state == .walk }),
           let rested = ants.indices.filter({ ants[$0].state == .pause || ants[$0].state == .idle }).min(by: { ants[$0].timer < ants[$1].timer }) { ants[rested].timer = 0 }
        for n in ants.indices {
            if coarse != nil {
                if ants[n].turning > 0 { (ants[n].heading, ants[n].turning) = (-ants[n].heading, 0) } // run fast, an about turn is made at once
                settle(n)
            } else if ants[n].turning > 0 { turn(n, dt) } else { place(n, dt) }
        }
    }

    private mutating func walk(_ n: Int, _ dt: Double) {
        guard let leg = ants[n].route.first else { arrived(n); return }
        var ant = ants[n]
        defer { ants[n] = ant }
        ant.bout -= dt
        if ant.bout <= 0 {
            ant.bout = dice.uniform(1.5, 5)
            // a stop between bursts, less often on the way to a face or out with a grain
            if dice.chance(ant.job == .wander || ant.job == .rest ? 0.7 : 0.3) { (ant.state, ant.timer) = (.pause, dice.uniform(0.4, 3)); return }
        }
        guard leg.branch == ant.branch else { (ant.route, ant.job) = ([], ant.carrying ? .dump : .none); return } // the route no longer fits: think again
        let target = leg.branch >= 0 ? min(leg.to, reach(leg.branch, share) - 0.45 * bl) : leg.to
        let off = target - ant.at, toward = off >= 0 ? 1.0 : -1.0
        if toward != ant.heading, abs(off) > 0.3 * bl { ant.turning = 1; return } // about turn first (`turn`)
        // (one whose body is far behind its place in the nest goes slowly on, so the place does not run ahead of it)
        let move = ant.pace * (ant.carrying ? 0.8 : 1) * bl * dt * (ant.stalled > 0 ? 0.25 : 1)
        ant.stepped += min(abs(off), move)
        if abs(off) <= move {
            ant.at = target
            ant.route.removeFirst()
            if let hop = leg.hop {
                (ant.branch, ant.at, ant.lateral) = (hop.branch, hop.at, .nan)
                if let next = ant.route.first { ant.heading = next.to >= ant.at ? 1 : -1 }
            }
        } else { ant.at += toward * move }
    }

    /// Two walking toward each other in one tunnel stop a body length apart and touch antennae; a third of the time
    /// one then turns back, and otherwise one takes the other wall and they pass. And a walking ant goes round one
    /// standing in its way by the other wall.
    private mutating func meetings() {
        let walking = ants.indices.filter { ants[$0].state == .walk && ants[$0].cool <= 0 && ants[$0].placed && ants[$0].turning <= 0 }
        for (i, a) in walking.enumerated() { for b in walking[(i + 1)...] where ants[a].state == .walk && ants[b].state == .walk {
            guard ants[a].branch == ants[b].branch, ants[a].heading != ants[b].heading else { continue }
            let gap = (ants[b].at - ants[a].at) * ants[a].heading
            guard gap > 0, gap < 1.3 * bl else { continue }
            let long = dice.uniform(0.8, 2)
            for n in [a, b] { (ants[n].state, ants[n].timer, ants[n].cool) = (.feel, long, 7) }
            ants[b].crossing = 1
            if dice.chance(0.34), ants[a].job == .wander || ants[a].job == .rest { (ants[a].route, ants[a].job) = ([], .none) }
        } }
        for a in ants.indices where ants[a].state == .walk && ants[a].crossing == 0 && ants[a].cool <= 0 && ants[a].branch >= 0 {
            for b in ants.indices where b != a && ants[b].state != .walk && ants[b].branch >= 0 {
                let off = ants[b].position - ants[a].position
                guard simd_length(off) < 1.3 * bl, simd_dot(off, ants[a].forward) > 0.3 * bl, simd_dot(ants[a].wall, ants[b].wall) > 0.3 else { continue }
                (ants[a].crossing, ants[a].cool) = (1, 4)
                break
            }
        }
    }

    // MARK: - Where its body and its feet are

    /// Turning about on the spot: the body goes round through a half turn in 0.7 s, seen end on half-way, where
    /// head and tail change places, and its feet step round under it.
    private mutating func turn(_ n: Int, _ dt: Double) {
        guard ants[n].placed else { ants[n].turning = 0; return }
        let before = ants[n].turning
        ants[n].turning = max(0, before - dt / 0.7)
        if before > 0.5, ants[n].turning <= 0.5 { // head and tail change places
            (ants[n].trail, ants[n].forward, ants[n].heading) = ([], -ants[n].forward, -ants[n].heading)
        }
        let done = 1 - ants[n].turning
        ants[n].yaw = ants[n].turning <= 0 ? 0 : .pi * (done < 0.5 ? done : done - 1)
        for leg in ants[n].feet.indices { // every foot steps round to where it would rest, at a walking foot's speed
            ants[n].feet[leg].hold = nil
            step(&ants[n].feet[leg], toward: SIMD3(Build.foot[leg % 3].x, -Build.clear, (leg < 3 ? 1 : -1) * Build.foot[leg % 3].y), dt)
        }
    }

    /// A foot in the air goes toward `aim`, in the body's measure, no faster than a hurried step.
    private func step(_ foot: inout Ant.Foot, toward aim: SIMD3<Double>, _ dt: Double) {
        let off = aim - foot.now, far = simd_length(off), most = 6 * dt
        foot.now = far <= most ? aim : foot.now + off / far * most
    }

    /// Whether a body with its middle at `at`, facing `forward`, is clear of undug medium: its middle and, unless
    /// only the `middle` is asked about, its head and its gaster.
    public func clear(_ at: SIMD2<Double>, _ forward: SIMD2<Double>, middle only: Bool = false) -> Bool {
        for k in only ? [0.0] : [0.0, 0.3, -0.3] where nest.solid(at.x + forward.x * k * bl, at.y + forward.y * k * bl, at: share) { return false }
        return true
    }

    /// Where an ant's middle belongs for its place in the nest, the way to the wall it walks on, and the way the
    /// tunnel runs. On the surface it rides just above the spoil. In a tunnel it is on the line across the tunnel
    /// through its place, toward a wall by `Ant.lateral`: as far as leaves it riding just clear of that wall. The
    /// wall is the one it is on, if it has one; a floor before a ceiling; and after a ceiling walked too long, the
    /// floor; passing the mouth of another tunnel it does not go in. `lateral` changes as the ant walks, by no
    /// more than four fifths of what it walks (`dt` nil: at once), since an ant does not slide sideways; except
    /// that it never passes the room there is: what is open along that line. `under` is the way to the wall on
    /// the side of the tunnel it is on now, which is not `wall` while it crosses to the other one.
    private func berth(_ ant: inout Ant, _ dt: Double?) -> (at: SIMD2<Double>, wall: SIMD2<Double>, under: SIMD2<Double>, along: SIMD2<Double>, middle: SIMD2<Double>) {
        let ride = Build.clear * bl + 0.5
        defer { ant.stepped = 0 }
        if ant.branch < 0 {
            let on = line(-1, ant.at)
            ant.lateral = 0
            return (on.point - SIMD2(0, ride), SIMD2(0, 1), SIMD2(0, 1), on.along, on.point - SIMD2(0, ride))
        }
        let far = max(reach(ant.branch, share) - 0.1, 0), at = min(max(ant.at, 0), far)
        let on = line(ant.branch, at), across = SIMD2(-on.along.y, on.along.x)
        let radii = nest.branches[ant.branch].radius, local = radii[min(max(Int(at), 0), radii.count - 1)]
        let cap = min(3 * bl, 2.3 * local + 0.5 * bl)
        // the room to its left and to its right: here, and the least of it under the length of its body, which
        // does not sink into a pit narrower than it stands, and for a body length ahead, or as far as it is going,
        // so that it is on its way up a step in the floor before it is at it
        var room = [cap, cap], least = [cap, cap]
        let going = (ant.route.first.map { $0.branch == ant.branch ? abs($0.to - ant.at) : 0 } ?? 0) / bl
        for k in [0.0, 0.3, -0.3, min(0.65, going) * ant.heading, min(1, going) * ant.heading] where at + k * bl >= 0 && at + k * bl <= far || abs(k) < 0.5 {
            let here = k == 0 ? on : line(ant.branch, min(max(at + k * bl, 0), far))
            for side in 0...1 {
                let d = wall(from: here.point, along: SIMD2(-here.along.y, here.along.x) * (side == 0 ? 1 : -1), upTo: cap)
                if k == 0 { room[side] = d }
                least[side] = min(least[side], d)
            }
        }
        var best: (cost: Double, side: Int)?
        for side in 0...1 {
            let way = across * (side == 0 ? 1 : -1)
            // a wall where this tunnel's own should be, before one far off or none; a floor before a ceiling, and
            // more so after a ceiling walked too long; and the wall it is on before one it must roll over to reach
            var cost = (room[side] >= cap ? 2.2 * bl : min(abs(room[side] - local), 2 * bl)) + 0.7 * bl * max(0, -way.y) * (ant.ceiling > 3 * bl ? 4 : 1)
            if ant.placed { cost += 0.6 * bl * (1 - simd_dot(way, ant.wall)) }
            if ant.crossing == 1 { cost = -cost }
            if best == nil || cost < best!.cost { best = (cost, side) }
        }
        let side = best!.side, sign = side == 0 ? 1.0 : -1.0
        // (at the mouth of another tunnel, no further out than this one's own wall would be)
        let mouth = (ways[ant.branch] ?? []).contains { $0.opened <= share && abs($0.at - at) < 0.8 * bl }
        let want = sign * max((least[side] >= cap ? local : mouth ? min(least[side], local + 0.3 * bl) : least[side]) - ride, 0)
        if ant.lateral.isNaN { ant.lateral = simd_dot(ant.position - on.point, across) } // just turned into this tunnel: as it is
        if let dt { let most = 0.8 * ant.stepped + 0.15 * bl * dt; ant.lateral += min(max(want - ant.lateral, -most), most) } else { ant.lateral = want }
        ant.lateral = min(max(ant.lateral, -max(room[1] - ride, 0)), max(room[0] - ride, 0))
        // (the walls are met a little coarsely, so make sure: and where its head or its gaster would be in the wall, further off)
        while ant.lateral != 0, !clear(on.point + across * ant.lateral, ant.forward, middle: !ant.placed) { ant.lateral = abs(ant.lateral) > 0.3 ? ant.lateral - (ant.lateral > 0 ? 0.3 : -0.3) : 0 }
        return (on.point + across * ant.lateral, across * sign, across * (abs(ant.lateral) > 0.6 ? (ant.lateral > 0 ? 1 : -1) : sign), on.along, on.point)
    }

    /// Where an ant's middle was half a body length back along the path it took; nil if it has not come a sixth
    /// of one.
    private func back(of ant: Ant, from now: SIMD2<Double>) -> SIMD2<Double>? {
        let trail = ant.trail, far = 0.5 * bl
        for k in stride(from: trail.count - 1, through: 0, by: -1) {
            let d = simd_distance(trail[k].point, now)
            guard d >= far else { continue }
            let next = k + 1 < trail.count ? trail[k + 1].point : now, nearer = simd_distance(next, now)
            return simd_mix(trail[k].point, next, SIMD2(repeating: min(max((d - far) / max(d - nearer, 1e-6), 0), 1)))
        }
        if let first = trail.first, simd_distance(first.point, now) > far / 3 { return first.point }
        return nil
    }

    /// Puts an ant down where it is in the nest with no path behind it: when it arrives, is moved, or time is run
    /// fast.
    private mutating func settle(_ n: Int) {
        var ant = ants[n]
        defer { ants[n] = ant }
        (ant.trail, ant.crossing, ant.turning, ant.yaw, ant.stalled, ant.rolling, ant.flat, ant.placed) = ([], 0, 0, 0, 0, 0, 1, false)
        let to = berth(&ant, nil)
        (ant.position, ant.wall, ant.forward, ant.placed) = (to.at, to.wall, to.along * ant.heading, true)
        ant.up = SIMD2(ant.forward.y, -ant.forward.x)
        if simd_dot(ant.up, to.wall) > 0 { ant.up = -ant.up }
        ant.feet = (0..<6).map { leg in
            let grip = hold(ant, leg, Build.foot[leg % 3].x)
            return Ant.Foot(hold: grip, now: own(ant, grip, leg))
        }
    }

    /// One sixtieth of a second of an ant's body and feet.
    private mutating func place(_ n: Int, _ dt: Double) {
        guard ants[n].placed, !ants[n].feet.isEmpty else { settle(n); return }
        var ant = ants[n]
        defer { ants[n] = ant }
        let walking = ant.state == .walk, from = ant.position, to = berth(&ant, dt)
        if ant.crossing == 1 { ant.crossing = 2 }
        if ant.crossing == 2, ant.cool < 3 { ant.crossing = 0 }
        // Its middle goes toward where it belongs no faster than a hurried walk. Where the straight way there is
        // not open (a corner between two tunnels) it goes toward the middle of the tunnel, or as much of the way
        // as is across or up and down alone; and if none of those is open it is there at once, never in the medium.
        let limit = (walking ? 2.6 * ant.pace : 0.6) * bl * dt
        func toward(_ goal: SIMD2<Double>) -> SIMD2<Double> { let off = goal - from, far = simd_length(off); return far <= limit ? goal : from + off / far * limit }
        let straight = toward(to.at)
        let ways = [straight, toward(to.middle), SIMD2(straight.x, from.y), SIMD2(from.x, straight.y)]
        var now = ways.first { clear($0, ant.forward, middle: true) } ?? to.at
        if now == to.at, now != straight { leapt += 1 }
        if simd_distance(now, from) < 0.01, simd_distance(to.at, from) > 0.3 * bl { (now, leapt) = (to.at, leapt + 1) } // (nowhere to go but there)
        let went = simd_distance(now, from)
        ant.gone += went
        if went > 0.05 { ant.trail.append((ant.gone, now)) }
        while ant.trail.count > 2, ant.trail[1].gone < ant.gone - 2 * bl || ant.trail.count > 200 { ant.trail.removeFirst() }
        // It faces the way it has come, turning no faster than seven radians a second.
        // (where that is far from the way the tunnel runs, or would put its head or its gaster in the medium, the
        // way the tunnel runs)
        var forward = ant.forward
        if var facing = back(of: ant, from: now).map({ simd_normalize(now - $0) }) ?? (clear(now, forward) ? nil : forward) {
            if simd_dot(facing, to.along * ant.heading) < 0.5 || !clear(now, facing) { facing = to.along * ant.heading }
            forward = facing
            let turn = atan2(ant.forward.x * forward.y - ant.forward.y * forward.x, simd_dot(ant.forward, forward)), most = 7 * dt
            if abs(turn) > most { let a = atan2(ant.forward.y, ant.forward.x) + (turn > 0 ? most : -most); forward = SIMD2(cos(a), sin(a)) }
        }
        // Up is away from the wall it walks on: when that becomes the other wall, over it rolls (`Ant.flat`).
        var up = SIMD2(forward.y, -forward.x)
        if simd_dot(up, ant.up) < 0 { up = -up }
        if simd_dot(up, to.under) > 0.35 { (up, ant.rolling) = (-up, ant.rolling > 0 ? 1 - ant.rolling : 1) }
        ant.flat = ant.rolling > 0 ? -cos(.pi * (1 - ant.rolling)) : 1
        ant.rolling = max(0, ant.rolling - dt / 0.35)
        if ant.branch >= 0 { ant.ceiling = to.wall.y < -0.5 ? ant.ceiling + went : 0 }
        (ant.position, ant.forward, ant.up, ant.wall) = (now, forward, up, to.wall)
        // Held up (its middle far from where it belongs) for two seconds, it thinks of something else, keeping any
        // grain it carries.
        ant.stalled = walking && simd_distance(now, to.at) > 0.4 * bl ? ant.stalled + dt : 0
        if ant.stalled > 2 {
            (ant.route, ant.job, ant.state, ant.timer, ant.stalled) = ([], ant.carrying ? .dump : .none, .pause, dice.uniform(0.3, 1), 0)
            gaveUp += 1
        }
        if ant.rolling > 0 { // rolling over: every foot steps round to where it would rest
            for leg in ant.feet.indices {
                ant.feet[leg].hold = nil
                step(&ant.feet[leg], toward: SIMD3(Build.foot[leg % 3].x, -Build.clear, (leg < 3 ? 1 : -1) * Build.foot[leg % 3].y), dt)
            }
        } else { feet(&ant, moved: went, walking: walking, dt) }
    }

    /// A foothold for a leg, `along` body lengths ahead of the body's middle: the point of the wall under the body there.
    private func hold(_ ant: Ant, _ leg: Int, _ along: Double) -> SIMD2<Double> {
        let under = ant.position + ant.forward * along * bl
        if ant.branch < 0 { return SIMD2(under.x, Double(nest.ground) - nest.surface(under.x, at: share)) }
        let far = (Build.clear + 0.45) * bl, d = wall(from: under, along: -ant.up, upTo: far)
        return under - ant.up * (d >= far - 0.01 ? Build.clear * bl : d) // nothing to stand on there: where a floor would be
    }

    /// A point of the tank in the ant's own measure (forward, up, sideways), for a leg.
    private func own(_ ant: Ant, _ point: SIMD2<Double>, _ leg: Int) -> SIMD3<Double> {
        let off = (point - ant.position) / bl
        return SIMD3(simd_dot(off, ant.forward), simd_dot(off, ant.up), (leg < 3 ? 1 : -1) * Build.foot[leg % 3].y)
    }

    private func feet(_ ant: inout Ant, moved: Double, walking: Bool, _ dt: Double) {
        let stride = Build.stride(at: ant.pace), duty = Build.duty(at: ant.pace), reach = stride * duty
        if walking { ant.phase = (ant.phase + moved / (stride * bl)).truncatingRemainder(dividingBy: 1) }
        for leg in 0..<6 {
            let k = leg % 3, rest = Build.foot[k], side = leg < 3 ? 1.0 : -1.0
            let p = (ant.phase + Build.offsets[leg] + 1).truncatingRemainder(dividingBy: 1), down = p < duty || !walking
            var foot = ant.feet[leg], released = false
            if let held = foot.hold {
                foot.now = own(ant, held, leg)
                let hip = Build.hips[k], far = simd_length(SIMD3(foot.now.x - hip.x, foot.now.y - hip.y, foot.now.z))
                // it lets go at the end of its stance, or when the hold is further than the leg is long, or up over its back
                if !down || far > 1.1 * (Build.femur[k] + Build.tibia[k] + Build.tarsus[k]) || foot.now.y > 0.04 || abs(foot.now.x - rest.x) > reach + 0.3 { (foot.hold, released) = (nil, true) }
            }
            if foot.hold == nil {
                if down { // reaching for its hold; planted once it is there
                    let along = walking ? rest.x + reach * (0.5 - min(p, duty) / duty) : min(max(foot.now.x, rest.x - 0.2), rest.x + 0.2)
                    let grip = hold(ant, leg, along), aim = own(ant, grip, leg)
                    step(&foot, toward: aim, dt)
                    if !released, simd_distance(foot.now, aim) < 0.02 { (foot.hold, foot.now) = (grip, aim) } // (not in the sixtieth it let go: a planted foot is never seen to move)
                } else { // swinging forward, lifted
                    let q = (p - duty) / (1 - duty)
                    step(&foot, toward: SIMD3(rest.x - reach / 2 + reach * q * q * (3 - 2 * q), -Build.clear + Build.lift * sin(.pi * q), side * rest.y), dt)
                }
            }
            ant.feet[leg] = foot
        }
    }
}
