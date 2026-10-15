import Foundation
import simd

/// A model railway: one layout with its scenery and trains, drawn into a pixel canvas with the trains running.
public final class Railway {
    public let w: Int, h: Int
    let view: RailView, era: RailEra
    let layout: Layout, scenery: Scenery, statics: Statics
    var sim: Sim
    private var owed = 0.0
    /// Each vehicle as drawn at each heading (and slope), coloured by day and by night, made as first needed.
    private var bakes: [String: Painted] = [:]
    private let roadCar: RailVehicle
    /// The picture under the trains at the last night level drawn, packed, and that level.
    private var under: [UInt32] = [], underNight: Float = -1
    private var frame: [UInt32], depth: [Float]

    /// The trains running, by their names in Settings.
    public var names: [String] { layout.trains.map { RailArt.trains[$0]!.name } }

    /// Grows a layout from `seed` for up to `count` of the era's trains on a canvas `width` by `height` art
    /// pixels, lays its scenery, and draws what stands still. A layout often can't fit every train, or a station,
    /// so up to six are grown from seeds drawn from this one, now and then with a short train for an inner loop
    /// in place of the third, and the first with everything (else the one with most) is kept.
    public init(seed: Int, width: Int, height: Int, view kind: RailViewKind, era: RailEra, count: Int, season: RailSeason) {
        (w, h, self.era) = (width, height, era)
        view = RailView(kind: kind, w: width, h: height)
        var best: (score: Int, layout: Layout, scenery: Scenery)?
        for attempt in 0..<6 {
            let s = seed &* 8 &+ attempt
            var trains = Self.pick(era, count: count, seed: s)
            let short = RailArt.trains(of: era, short: true)
            if trains.count == 3, attempt % 3 == 2, !short.isEmpty { trains[2] = short[(s & 0xFFFF) % short.count].key }
            let layout = Layout(seed: s, view: view, trains: trains, share: true), scenery = Scenery(layout, era: era, season: season)
            let score = layout.trains.count * 2 + (scenery.station == nil ? 0 : 1)
            if best == nil || score > best!.score { best = (score, layout, scenery) }
            if score == trains.count * 2 + 1 { break }
        }
        (layout, scenery) = (best!.layout, best!.scenery)
        Self.hideIdleSignals(layout, scenery)
        statics = Statics(layout, scenery, era: era, season: season)
        sim = Sim(layout, scenery)
        roadCar = RailArt.roadCar(era)
        frame = Array(repeating: 0, count: width * height)
        depth = statics.depth
    }

    /// A loop two trains share needs many blocks for none of them ever to lock, but most of their signals would
    /// only ever show clear. So the trains are run for ten minutes first, and only the signals one of them stops at
    /// stay, with the starting signal past the platform; the rest are still in the running, just not drawn.
    static func hideIdleSignals(_ layout: Layout, _ scenery: Scenery) {
        guard !scenery.blocks.isEmpty else { return }
        var sim = Sim(layout, scenery), used = Set<SIMD2<Int>>()
        for _ in 0..<(600 * 60) {
            sim.step()
            for tr in sim.trains where tr.v < 0.05 && tr.dwell <= 0 {
                guard let B = scenery.blocks[tr.loop] else { continue }
                let L = layout.loops[tr.loop].L, k = B.indices.min { wrap(B[$0] - tr.s, L) < wrap(B[$1] - tr.s, L) }!
                if wrap(B[k] - tr.s, L) < 8 { used.insert(SIMD2(tr.loop, k)) }
            }
        }
        for i in scenery.signals.indices {
            guard case .block(let k) = scenery.signals[i].role else { continue }
            let li = scenery.signals[i].loop
            if k == 0, scenery.station?.loop == li { used.insert(SIMD2(li, k)) }
            scenery.signals[i].shown = used.contains(SIMD2(li, k))
        }
        scenery.things.removeAll { $0.guards.map { !used.contains($0) } ?? false }
    }

    /// Up to `count` of an era's main-line trains, picked by `seed`.
    static func pick(_ era: RailEra, count: Int, seed: Int) -> [String] {
        var rng = Dice(seed &* 31 &+ era.rawValue)
        var keys = RailArt.trains(of: era).map(\.key)
        for i in stride(from: keys.count - 1, to: 0, by: -1) { keys.swapAt(i, rng.below(i + 1)) }
        return Array(keys.prefix(count))
    }

    /// Runs the trains on by `dt` seconds, in fixed steps.
    public func advance(_ dt: Double) {
        owed = min(owed + dt, 0.25)
        while owed >= Sim.dt { sim.step(); owed -= Sim.dt }
    }

    /// Draws the layout with its trains where they are now into `out` (premultiplied RGBA, rows from the bottom,
    /// as a mutable texture takes them), `night` from 0 (day) to 1.
    public func draw(night: Float, into out: UnsafeMutableBufferPointer<UInt32>) {
        let night = (night * 32).rounded() / 32
        if night != underNight {
            under = zip(statics.day, statics.night).map { pack($0 + ($1 - $0) * night) }
            underNight = night
        }
        frame.withUnsafeMutableBufferPointer { f in under.withUnsafeBufferPointer { f.baseAddress!.update(from: $0.baseAddress!, count: $0.count) } }
        depth.withUnsafeMutableBufferPointer { d in statics.depth.withUnsafeBufferPointer { d.baseAddress!.update(from: $0.baseAddress!, count: $0.count) } }
        let poses = sim.poses()
        if night > 0 { for p in poses where p.lead { headlight(p.c, p.heading, Double(p.vehicle.length), night) } }
        for p in poses { sprite(p.vehicle, p.c, p.heading, (p.slope * 8).rounded() / 8, night) }
        if let (at, heading) = sim.carPose() {
            sprite(roadCar, at, heading, 0, night)
            if night > 0.5 {
                let t = SIMD2(cos(heading), sin(heading)), n = SIMD2(-t.y, t.x)
                for e in [-1.0, 1.0] { let q = SIMD2(at.x, at.y) + t * 3.6 + n * e * 0.8; point([q.x, q.y, 0.8], [255, 240, 200]) }
            }
        }
        crossingParts(night)
        signalParts(night)
        for y in 0..<h { // rows from the bottom
            frame.withUnsafeBufferPointer { src in
                (out.baseAddress! + (h - 1 - y) * w).update(from: src.baseAddress! + y * w, count: w)
            }
        }
    }

    // MARK: drawing the moving things

    private func pack(_ c: SIMD3<Float>) -> UInt32 {
        let q = simd_clamp(c.rounded(.toNearestOrEven), SIMD3(repeating: 0), SIMD3(repeating: 255))
        return UInt32(q.x) | UInt32(q.y) << 8 | UInt32(q.z) << 16 | 0xFF00_0000
    }

    private func unpack(_ p: UInt32) -> SIMD3<Float> { SIMD3(Float(p & 0xFF), Float(p >> 8 & 0xFF), Float(p >> 16 & 0xFF)) }

    @inline(__always) private func put(_ x: Int, _ y: Int, _ c: UInt32, _ d: Float) {
        guard x >= 0, x < w, y >= 0, y < h else { return }
        let i = y * w + x
        if d >= depth[i] - 1e-4 { frame[i] = c; depth[i] = d }
    }

    private func point(_ p: SIMD3<Double>, _ c: SIMD3<Float>, eps: Double = 0.05) {
        let q = view.project(p), x = Int(floor(q.x)), y = Int(floor(q.y))
        put(x, y, pack(c), Float(view.pixelDepth(x, y, p.z) + eps))
    }

    /// A vehicle at the nearest of 64 headings, its middle at `c`.
    private func sprite(_ v: RailVehicle, _ c: SIMD3<Double>, _ heading: Double, _ slope: Double, _ night: Float) {
        let q = Int((heading / (2 * .pi / 64)).rounded()) & 63
        let key = "\(v.name) \(q) \(slope)"
        let painted = bakes[key] ?? {
            let p = Painted(Marched(v.grid, view, heading: Double(q) * 2 * .pi / 64, slope: slope, fine: true), view, era: era)
            bakes[key] = p
            return p
        }()
        let s = view.project(c), ax = Int(floor(s.x)), ay = Int(floor(s.y)), base = Float(view.pixelDepth(ax, ay, c.z))
        for k in 0..<painted.count {
            let colour = night == 0 ? painted.day[k] : night == 1 ? painted.night[k] : pack(unpack(painted.day[k]) + (unpack(painted.night[k]) - unpack(painted.day[k])) * night)
            put(Int(painted.dx[k]) + ax, Int(painted.dy[k]) + ay, colour, painted.dd[k] + base)
        }
    }

    /// A lead vehicle's headlight on the ground ahead of it at night.
    private func headlight(_ c: SIMD3<Double>, _ heading: Double, _ length: Double, _ night: Float) {
        let t = SIMD2(cos(heading), sin(heading)), n = SIMD2(-t.y, t.x), front = SIMD2(c.x, c.y) + t * length / 2
        let mid = view.project([front.x + t.x * 11, front.y + t.y * 11, 0])
        let head = RailLight.headlight * 0.55 * night
        for y in clamped(Int(mid.y) - 14, Int(mid.y) + 14, h) { for x in clamped(Int(mid.x) - 26, Int(mid.x) + 26, w) {
            let i = y * w + x
            guard statics.depth[i] <= Float(view.pixelDepth(x, y, 0)) + 0.06 else { continue } // on the ground only
            let r = view.ground(x, y) - front, along = dot(r, t), across = abs(dot(r, n))
            guard along > 0, along < 22, across < 2 + along * 0.22 else { continue }
            let k: Float = along < 8 ? 0.5 : along < 15 ? 0.3 : 0.15
            frame[i] = pack(unpack(frame[i]) + head * k)
        }
        }
    }

    private static let red = SIMD3<Float>(255, 42, 26), green = SIMD3<Float>(48, 224, 160)

    /// The level crossing's flashers and gates (streamliners) or wigwags (steam), working while a train is near.
    private func crossingParts(_ night: Float) {
        let on = sim.crossingOn, phase = Int(sim.t / 0.75) % 2
        for cr in scenery.crossings {
            for m in cr.masts {
                let a = SIMD2(cos(m.heading), sin(m.heading)), across = SIMD2(-a.y, a.x)
                if era == .streamliners {
                    for (e, lit) in [(-1.0, on && phase == 0), (1.0, on && phase == 1)] {
                        let q = m.pos + across * e
                        point([q.x, q.y, 2.5], lit ? Self.red : [40, 12, 10])
                    }
                    let ang = on ? 0 : 1.35 // the gate arm over the approach lane: down while the crossing is on
                    for k in 1...6 {
                        let q = m.pos + across * m.side * (-Double(k) * cos(ang))
                        point([q.x, q.y, 3.2 + Double(k) * sin(ang)], k % 2 == 1 ? [232, 228, 220] : [200, 32, 42])
                    }
                } else {
                    let swing = on ? sin(sim.t * 2 * .pi * 0.7) * 0.6 : 0 // a disc on a pendulum
                    for k in 1...3 {
                        let q = m.pos + across * sin(swing) * Double(k)
                        point([q.x, q.y, 7.5 - Double(k) * cos(swing)], [30, 30, 30])
                    }
                    if on { let q = m.pos + across * sin(swing) * 3; point([q.x, q.y, 7.5 - 3 * cos(swing)], Self.red) }
                }
            }
        }
    }

    /// Each signal's aspect: a searchlight's red or green, or a semaphore's arm level for stop and raised for clear.
    private func signalParts(_ night: Float) {
        for sg in scenery.signals where sg.shown {
            guard let mine = sim.trains.firstIndex(where: { $0.loop == sg.loop }) else { continue }
            let stop: Bool
            switch sg.role {
            case .block(let k): stop = sim.occupied(sg.loop, k)
            case .lone:
                let tr = sim.trains[mine], L = layout.loops[sg.loop].L
                let past = centred(tr.s - tr.length - sg.s, L), over = centred(tr.s - sg.s, L)
                stop = 0 <= past && past < 70 || 0 <= over && over < tr.length
            case .home(let group): stop = sim.holder[group].map { $0 != mine } ?? false
            }
            // the lamp just in front of the head, toward oncoming trains, so the head doesn't hide it
            let p = sg.pos, face = p - SIMD2(cos(sg.heading), sin(sg.heading)) * 0.8
            if era == .streamliners {
                point([face.x, face.y, 6], stop ? Self.red : Self.green, eps: 0.6)
            } else {
                let t = SIMD2(cos(sg.heading), sin(sg.heading)), n = SIMD2(-t.y, t.x), ang = stop ? 0.0 : 1.0
                for k in 1...3 {
                    let q = p - n * Double(k) * cos(ang)
                    point([q.x, q.y, 7.5 + Double(k) * sin(ang)], k < 3 ? [200, 30, 30] : [232, 228, 220])
                }
                if night > 0.5 { point([face.x, face.y, 6.5], stop ? Self.red : Self.green, eps: 0.6) }
            }
        }
    }
}

/// A vehicle's sprite at one heading, ready to draw: each pixel's offset and depth, and its colour by day and by
/// night, packed.
struct Painted {
    var dx: [Int16] = [], dy: [Int16] = [], dd: [Float] = [], day: [UInt32] = [], night: [UInt32] = []
    var count: Int { dx.count }

    init(_ m: Marched, _ view: RailView, era: RailEra) {
        let lights = [RailLight(night: false, winter: false, era: era), RailLight(night: true, winter: false, era: era)]
        func pack(_ c: SIMD3<Float>) -> UInt32 {
            let q = simd_clamp(c.rounded(.toNearestOrEven), SIMD3(repeating: 0), SIMD3(repeating: 255))
            return UInt32(q.x) | UInt32(q.y) << 8 | UInt32(q.z) << 16 | 0xFF00_0000
        }
        for k in 0..<m.count {
            dx.append(m.dx[k]); dy.append(m.dy[k]); dd.append(m.dd[k])
            let (a, b) = (lights[0], lights[1])
            day.append(pack(a.colour(m.mat[k], a.shade(m.normal[k], view), top: m.top[k])))
            night.append(pack(b.colour(m.mat[k], b.shade(m.normal[k], view), top: m.top[k])))
        }
    }
}
