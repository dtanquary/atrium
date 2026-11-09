import AppKit
import simd
import SpriteKit

@MainActor func jellyfish(size: CGSize) -> SKScene { Jellyfish(size: size) }

/// Moon jellies or crystal jellies drifting in a tank, drawn by one shader a jelly rather than cut out of photos, and
/// moving as footage of real groups measured (docs/jellyfish/research-motion.md): each pulse a quick squeeze and a
/// slow re-opening, each bell turning and tumbling in 3D, the group swimming and carried round the tank in a slow
/// loop. Three looks: moon jellies in a lit blue tank, the same moon jellies with a steady blue glow (made up: no
/// jelly glows steadily), and crystal jellies under blue light with their fluorescent green rings. The Look menu can
/// follow Light and Dark Mode or the Sun where you are, the lit tank by day; between moon looks only the light
/// changes, and the crystal jellies fade in and out as their own group.
final class Jellyfish: SKScene {
    nonisolated static let looks = [
        "Lit tank in Light Mode, glow in Dark Mode", "Lit tank in Light Mode, crystal jellies in Dark Mode",
        "Lit tank by day, glow at night", "Lit tank by day, crystal jellies at night",
        "Lit tank", "Glow", "Crystal jellies",
    ]
    nonisolated static let knobs = [
        Knob(key: "jellyfish.look", label: "Look", range: 0...Double(looks.count - 1), standard: 0, section: "Look",
             format: .choice(looks)),
        Knob(key: "jellyfish.count", label: "Jellyfish", range: 0.5...1.5, standard: 1, format: .times),
        Knob(key: "jellyfish.speed", label: "Speed", range: 0.5...1.5, standard: 1, format: .times),
    ]
    /// Speed's 1x as a share of the real pace: Dave's pick from trying the slider.
    nonisolated static let pace = 0.8

    /// A species: its sizes and pulse, how it moves (research-motion.md: measured from footage of real groups), and
    /// the defines its shader is built with. A moon jelly pulses every 1.6 s at 15 cm, the squeeze 39% of it, and goes
    /// half a diameter a pulse, between the footage's 0.2 (a floor: measured against the group, which swims too) and a
    /// lone lab jelly's 0.57 (Gemmell 2013); a crystal jelly glides with its tentacles streaming behind and pulses in
    /// bursts.
    struct Species {
        var count: Int, diameter: ClosedRange<Double>, period: Double, perPulse: Double
        var share = 0.39, turnChance = 0.4, turnAngle = 0.2...0.7, wobble = 0.06, rock = 0.11, drift = 0.09
        var restChance = 0.03, rest = 6.0...10.0, sink = 0.002, righting = 0.055, sag = 0.15
        /// The sprite round the margin's centre, in bell radii, for a straight jelly; and the tentacles', arms' and
        /// spine's lengths and the tentacles' trailing speed (radii a second), as the shader has them.
        var width: Double, above: Double, tentacles: Double, arms: Double, trail = 3.0
        var spine: Double { max(tentacles, arms / 0.6) }
        var defines: [String: String]
    }

    static let moon = Species(count: 84, diameter: 0.12...0.25, period: 1.6, perPulse: 0.5, width: 2.6, above: 0.8,
                              tentacles: 0.32, arms: 1.0, defines: [
        "NT": "120", "TLEN": "0.32", "TW": "0.006", "SWAY": "0.25", "NOA": "4", "ALEN": "1.0", "AW": "0.17",
        "ASPREAD": "0.22", "ASWAY": "0.25", "TWIST": "3.0", "HEIGHT": "0.42", "RISE": "0.32", "SHRINK": "0.14",
        "NC": "32.0", "CANALSHARP": "10.0", "CANALK": "0.5", "GONADS": "1", "CONVERGE": "0.0", "TVARY": "0.0", "RING": "0",
    ])
    static let crystal = Species(count: 48, diameter: 0.08...0.2, period: 1.8, perPulse: 0.35, restChance: 0.25, rest: 0.8...3.0,
                                 righting: 0.02, sag: 0.05, width: 2.6, above: 0.7, tentacles: 7, arms: 0.35, defines: [
        "NT": "36", "TLEN": "7.0", "TW": "0.005", "SWAY": "0.06", "NOA": "1", "ALEN": "0.35", "AW": "0.3",
        "ASPREAD": "0.0", "ASWAY": "0.05", "TWIST": "1.5", "HEIGHT": "0.36", "RISE": "0.26", "SHRINK": "0.12",
        "NC": "60.0", "CANALSHARP": "16.0", "CANALK": "2.2", "GONADS": "0", "CONVERGE": "0.3", "TVARY": "0.7", "RING": "1",
    ])

    /// One jelly in metres, seen by a camera 50° across from the origin, looking along +z: its place, the way its
    /// bell's apex points, its pulses (each a little different, a few followed by a rest) and its turns.
    private struct Jelly {
        let node: SKSpriteNode
        var p: SIMD3<Double>, axis: SIMD3<Double>, d: Double
        let seed: Double, amp: Double, basePeriod: Double
        var lastStart: Double, period: Double, nextStart: Double
        var turnAxis = SIMD3<Double>(1, 0, 0), turnAngle = 0.0, turnStart = -100.0, turnTime = 0.5
        var spin = SIMD3<Double>.zero // the axis's slow drift, rad/s
        var touchedAt = -100.0
        var history: [SIMD3<Double>] // the axis at every step as the camera sees it (pitched), a ring buffer
        var head = 0
    }

    /// A group of one species, in its own layer so the crystal jellies can fade in as the moon jellies fade out.
    private final class Group {
        let species: Species, shader: SKShader, fade = SKUniform(name: "u_fade", float: 0)
        var jellies: [Jelly] = []
        init(_ species: Species, _ shader: SKShader) { (self.species, self.shader) = (species, shader) }
    }

    private static let step = 1.0 / 60, kept = 600 // 10 s of the axis's history, for the longest tentacles
    private static let fov = 2 * tan(25 * Double.pi / 180) // view width per metre of depth
    private static let wallTurn = 0.6 // how fast a side's current turns a bell away, rad/s at the side
    private let current = 0.02 // the tank's current at its rim, m/s (display tanks run 1-3 cm/s: research-motion.md)
    private let pitch = 12 * Double.pi / 180 // looking a little up into the tank, as people do: more undersides show

    private let lit = SKUniform(name: "u_lit", float: 1), crystalShown = SKUniform(name: "u_crystal", float: 0)
    private let clock = SKUniform(name: "u_t", float: 0)
    private var groups: [Group] = []
    private var simTime = 0.0, lastTime: TimeInterval?, sunLit = 1.0, lastSun = -100.0, lastCount = Jellyfish.knobs[1].value
    /// Seeded from `jellyfish.seed` when it's set (for pictures that can be taken again), at random otherwise.
    private var rng = SplitMix(state: UInt64(max(0, UserDefaults.standard.integer(forKey: "jellyfish.seed"))).nonzero ?? .random(in: 1...UInt64.max))
    private var appearance: NSKeyValueObservation?

    override func sceneDidLoad() {
        backgroundColor = .black
        let water = SKSpriteNode(color: .black, size: size)
        water.anchorPoint = .zero
        water.zPosition = -10
        water.shader = SKShader(source: shaderCommon + Self.waterSource, uniforms: [
            lit, crystalShown, clock, SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)]),
        ])
        addChild(water)
        for species in [Self.moon, Self.crystal] {
            let defines = species.defines.sorted { $0.key < $1.key }.map { "#define \($0.key) \($0.value)\n" }.joined()
                + String(format: "#define SPLEN %.3f\n", species.spine)
            let group = Group(species, SKShader(source: defines + shaderCommon + Self.helpers + Self.medusaSource, uniforms: []))
            group.shader.uniforms = [lit, clock, group.fade]
            group.shader.attributes = ["a_box", "a_pose", "a_pulse", "a_sp1", "a_sp2"].map { SKAttribute(name: $0, type: .vectorFloat4) }
            groups.append(group)
        }
        settle(at: true)
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: UserDefaults.didChangeNotification, object: nil)
        appearance = NSApplication.shared.observe(\.effectiveAppearance) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.settle(at: false) }
        }
    }

    override func didMove(to view: SKView) {
        Location.shared.start()
    }

    @objc private func settingsChanged() {
        if Self.knobs[1].value != lastCount { // a new count: new groups, settled at once
            lastCount = Self.knobs[1].value
            for group in groups { empty(group) }
        }
        settle(at: false)
    }

    // MARK: - Which look

    /// What the Look menu asks for now: how lit the tank is (1 the lit tank, 0 the glow or the crystal jellies' dark),
    /// and how far the crystal jellies stand in for the moon jellies.
    private var wanted: (lit: Double, crystal: Double) {
        let pick = Int(Self.knobs[0].value)
        switch pick {
        case 0, 1: let day = systemIsDark ? 0.0 : 1; return (day, pick == 1 ? 1 - day : 0)
        case 2, 3: return (sunLit, pick == 3 ? 1 - sunLit : 0)
        case 4: return (1, 0)
        case 5: return (0, 0)
        default: return (0, 1)
        }
    }

    /// The Sun's say in the lit tank where you are: full by day, none at night, easing through civil twilight.
    private func sun() -> Double {
        let here = Location.shared.coordinate, jd = Sky.julianDate(Date())
        let altitude = asin((Sky.horizonMatrix(jd: jd, latitude: here.latitude, longitude: here.longitude) * Sky.sun(jd)).z) * 180 / .pi
        return simd_smoothstep(-6, 1, altitude)
    }

    /// Brings the look toward what's wanted: at once when the scene is built, otherwise eased by `update`. Groups
    /// that come into view are filled and set going; groups that have faded out are emptied.
    private func settle(at once: Bool) {
        if simTime - lastSun > 60 || once { (sunLit, lastSun) = (sun(), simTime) }
        let target = wanted
        if once {
            lit.floatValue = Float(target.lit)
            crystalShown.floatValue = Float(target.crystal)
        }
        for (i, group) in groups.enumerated() where group.jellies.isEmpty {
            if (i == 0 ? 1 - target.crystal : target.crystal) > 0.01 { fill(group) }
        }
    }

    // MARK: - The group

    /// Fills a group: spread through a tank as deep as the view on a jittered grid so they don't bunch by chance, more
    /// far than near, each bell pointing any way but more often up; then runs it 10 s so poses, pulses and tentacles
    /// are already under way.
    private func fill(_ group: Group) {
        let sp = group.species, n = max(1, Int((Double(sp.count) * Self.knobs[1].value).rounded()))
        let (near, far) = depths(sp), begin = simTime - 10
        let aspect = Double(size.width / size.height)
        let cols = Int((Double(n) * aspect).squareRoot().rounded(.up)), rows = (n + cols - 1) / cols
        var cells = Array(0..<(cols * rows)).shuffled(using: &rng)
        cells = Array(cells.prefix(n))
        for cell in cells {
            let z = near + (far - near) * pow(.random(in: 0...1, using: &rng), 0.7)
            let half = Self.fov * z / 2, d = Double.random(in: sp.diameter, using: &rng)
            let u = (Double(cell % cols) + .random(in: 0.2...0.8, using: &rng)) / Double(cols) * 2 - 1
            let w = (Double(cell / cols) + .random(in: 0.2...0.8, using: &rng)) / Double(rows) * 2 - 1
            let period = sp.period * pow(d / 0.15, 0.5) * .random(in: 0.8...1.3, using: &rng)
            let start = begin - .random(in: 0...period, using: &rng)
            let axis = norm(randomUnit() + SIMD3(0, 0.5, 0))
            let node = SKSpriteNode(color: .white, size: CGSize(width: 1, height: 1))
            node.blendMode = .add
            node.shader = group.shader
            addChild(node)
            group.jellies.append(Jelly(node: node, p: SIMD3(u * (0.85 * half - d / 2), w * 0.75 * half / aspect, z), axis: axis, d: d,
                                       seed: .random(in: 0...50, using: &rng), amp: .random(in: 0.85...1.1, using: &rng), basePeriod: period,
                                       lastStart: start, period: period, nextStart: start + period,
                                       history: Array(repeating: turned(axis, SIMD3(1, 0, 0), pitch), count: Self.kept)))
        }
        for k in 0..<600 { move(group, at: begin + Double(k) * Self.step) } // 10 s, ending now
    }

    private func empty(_ group: Group) {
        for jelly in group.jellies { jelly.node.removeFromParent() }
        group.jellies.removeAll()
    }

    /// How near and far the tank runs, by the animals' size, as a tank's window frames them. Deep, so a crowd is mostly
    /// small bells further back, as in the footage's tanks: going from 28 moon jellies to 56 raised the cost of drawing
    /// them by about half rather than doubling it. (Dave then chose 84.)
    private func depths(_ sp: Species) -> (Double, Double) {
        let scale = (sp.diameter.lowerBound + sp.diameter.upperBound) / 2 / 0.1
        return (0.65 * scale, 3.5 * scale)
    }

    // MARK: - Motion

    override func update(_ currentTime: TimeInterval) {
        let dt = frameTime(currentTime, &lastTime) * Self.knobs[2].value * Self.pace
        // Steps of 1/60 s at fixed times, so the scene moves the same at any frame rate.
        let first = (simTime / Self.step).rounded(.down) + 1
        simTime += dt
        let steps = Array(stride(from: first, through: (simTime / Self.step).rounded(.down), by: 1).prefix(12))
        let target = wanted
        let ease = min(1, dt / 1.5) // a change of look eases over a few seconds
        lit.floatValue += Float((target.lit - Double(lit.floatValue)) * ease)
        crystalShown.floatValue += Float((target.crystal - Double(crystalShown.floatValue)) * ease)
        // ponytail: the sway and the snow jump once an hour where this wraps; carry their phase on the CPU if a jump shows
        clock.floatValue = Float(simTime.truncatingRemainder(dividingBy: 3600))
        if simTime - lastSun > 60 { settle(at: false) }
        for (i, group) in groups.enumerated() {
            let shown = i == 0 ? 1 - crystalShown.floatValue : crystalShown.floatValue
            group.fade.floatValue = shown
            if shown < 0.002, !group.jellies.isEmpty, (i == 0 ? 1 - target.crystal : target.crystal) < 0.01 { empty(group) }
            if group.jellies.isEmpty { continue }
            for k in steps { move(group, at: k * Self.step) }
            place(group)
        }
    }

    /// Steps one group 1/60 s. Each pulse is a little longer or shorter than the last; some turn the bell in any
    /// direction, all wobble it, and a few are followed by a rest. Between, the axis drifts slowly, the bell turns
    /// toward the group's slow loop round the view (as the sine of how far off it is, so one pointing the other way
    /// comes round slowly), the tank's current carries it round and turns it with it, and neighbours and the tank's
    /// sides push it gently away and turn it from them. One that touches another stops pulsing for a moment, then
    /// turns away (Albert 2011, and one meeting filmed).
    private func move(_ group: Group, at now: Double) {
        let sp = group.species, (near, far) = depths(sp), dt = Self.step
        let aspect = Double(size.width / size.height), spin = current / (Self.fov * (near + far) / 4)
        for i in group.jellies.indices {
            var j = group.jellies[i]
            if now >= j.nextStart {
                j.lastStart = j.nextStart
                j.period = j.basePeriod * .random(in: 0.92...1.08, using: &rng)
                j.nextStart = j.lastStart + j.period
                let big = Double.random(in: 0...1, using: &rng) < sp.turnChance
                j.turnAngle = big ? .random(in: sp.turnAngle, using: &rng) * (Bool.random(using: &rng) ? -1 : 1) : sp.wobble * gauss()
                j.turnAxis = norm(cross(j.axis, randomUnit()))
                (j.turnStart, j.turnTime) = (j.lastStart, sp.share * j.period)
                if Double.random(in: 0...1, using: &rng) < sp.restChance { j.nextStart += .random(in: sp.rest, using: &rng) }
            }
            if now >= j.turnStart && now < j.turnStart + j.turnTime {
                j.axis = norm(turned(j.axis, j.turnAxis, j.turnAngle * dt / j.turnTime))
            }
            j.spin += -j.spin * (dt / 2) + SIMD3(gauss(), gauss(), gauss()) * (sp.drift * dt.squareRoot())
            j.spin -= j.axis * dot(j.spin, j.axis)
            let w = length(j.spin)
            if w > 1e-6 { j.axis = norm(turned(j.axis, j.spin / w, w * dt)) }
            let half = Self.fov * j.p.z / 2
            let (hx, hy) = (half * 0.92 - j.d / 2, half / aspect * 0.8) // the sides keep a whole bell in view
            // The bell is drawn round the group's slow loop: up one side, across the top, down the other and back
            // across the bottom (Albert 2011: one end of an aggregation swims up, the other down), weakly near the
            // middle. Drawn only upward, the group gathered in the top half and the upright ones pulsed against it.
            let loop = SIMD3(-0.5 * j.p.y / hy, j.p.x / hx, 1e-3), goal = norm(loop), pull = min(1, 1.5 * length(loop))
            let tilt = acos(max(-1, min(1, dot(j.axis, goal))))
            if tilt > 1e-3 && tilt < .pi - 1e-3 { j.axis = norm(turned(j.axis, norm(cross(j.axis, goal)), sp.righting * pull * sin(tilt) * dt)) }
            j.axis = norm(turned(j.axis, SIMD3(0, 0, 1), spin * dt))

            let tau = now - j.lastStart, swimming = tau < j.period
            var v = swimming ? j.axis * (Self.surge(tau, sp.share * j.period, j.period) * sp.perPulse * j.d * j.amp) : .zero
            v.y -= swimming ? sp.sink * 0.3 : sp.sink
            v += SIMD3(-j.p.y, j.p.x, 0) * spin // the tank's slow turn, round the view's middle
            // ponytail: every pair, every step (126 jellies at most, 1.5x); a grid of cells if the count ever grows much
            for k in group.jellies.indices where k != i {
                let gap = j.p - group.jellies[k].p, dist = length(gap), touch = (j.d + group.jellies[k].d) * 0.5
                if dist < touch {
                    v += norm(gap) * (touch - dist) * 0.8
                    if now - j.touchedAt > 6 {
                        j.touchedAt = now
                        let pause = Double.random(in: 1...2, using: &rng)
                        j.nextStart = max(j.nextStart, now + pause)
                        (j.turnAxis, j.turnAngle) = (norm(cross(j.axis, norm(gap))), .random(in: 0.8...1.5, using: &rng))
                        (j.turnStart, j.turnTime) = (now + pause / 2, 2)
                    }
                }
            }
            v.x -= max(0, abs(j.p.x) - hx) * copysign(0.3, j.p.x)
            v.y -= max(0, abs(j.p.y) - hy) * copysign(0.3, j.p.y)
            v.z += max(0, near - j.p.z) - max(0, j.p.z - far) * 0.3
            // Within a bell of a side, the tank's current along it turns the bell away, as a kreisel's wall flow does:
            // without it the loop carries them into the sides, and they ride round pressed against them.
            let reach = 1 * j.d, close = { (gap: Double) in max(0, min(1, 1 - gap / reach)) }
            let away = SIMD3(-copysign(close(hx - abs(j.p.x)), j.p.x), -copysign(close(hy - abs(j.p.y)), j.p.y), 0)
            if length(away) > 0.01, dot(j.axis, norm(away)) < 0.9 {
                j.axis = norm(turned(j.axis, norm(cross(j.axis, away)), Self.wallTurn * min(1, length(away)) * dt))
            }
            j.p += v * dt
            j.head = (j.head + 1) % Self.kept
            j.history[j.head] = turned(j.axis, SIMD3(1, 0, 0), pitch)
            group.jellies[i] = j
        }
    }

    /// The speed through one pulse, as a share of the pulse's distance a second: the surge while squeezing, and the
    /// softer second push of the vortex it recaptures while re-opening (Gemmell 2013), with no long coast.
    private static func surge(_ tau: Double, _ squeeze: Double, _ period: Double) -> Double {
        let open = period - squeeze, r0 = squeeze + 0.6 * open, push = max(0.5, 0.8 * open)
        var v = tau < squeeze + 0.25 ? pow(sin(.pi * tau / (squeeze + 0.25)), 2) : 0
        if tau > r0 && tau < r0 + push { v += 0.35 * pow(sin(.pi * (tau - r0) / push), 2) }
        let area = (squeeze + 0.25) / 2 + 0.35 * push / 2 // each sine-squared hump's area is half its width
        return v / area
    }

    /// Places a group's sprites: where each bell is on screen and how big, which way its axis points (a turn in the
    /// screen's plane and a tilt toward or away from us, rocking a few degrees in step with its pulse), its pulse,
    /// and the spine its tentacles hang along.
    private func place(_ group: Group) {
        let sp = group.species, w = Double(size.width), h = Double(size.height)
        for j in group.jellies {
            let k = w / (Self.fov * j.p.z), r = j.d / 2 * k // points per metre, and the bell's radius in points
            let phase = max(0, min(1, (simTime - j.lastStart) / j.period))
            let across = norm(cross(j.axis, SIMD3(sin(j.seed), 0.3, cos(j.seed))))
            let shown = turned(turned(j.axis, across, sp.rock * sin(2 * .pi * phase)), SIMD3(1, 0, 0), pitch)
            let heading = atan2(-shown.x, shown.y), tilt = asin(max(-0.97, min(0.97, -shown.z)))
            let pts = spine(j, sp, heading: heading)
            let reach = pts.map { abs($0.x) }.max()! + 1.4
            let width = max(sp.width, 2 * reach), above = sp.above + abs(sin(tilt))
            let hanging: Double = -pts[3].y * min(1, max(sp.tentacles, sp.arms) / sp.spine) + 0.4
            let below: Double = max(1 + abs(sin(tilt)), hanging)
            j.node.size = CGSize(width: width * r, height: (above + below) * r)
            j.node.anchorPoint = CGPoint(x: 0.5, y: below / (above + below))
            j.node.position = CGPoint(x: w / 2 + j.p.x * k, y: h / 2 + j.p.y * k)
            j.node.zRotation = heading
            let (near, far) = depths(sp)
            let fog = exp(-(j.p.z - near) / (far - near) * 0.9)
            let gap = j.nextStart - j.lastStart // a rest after this pulse makes the gap longer than the pulse
            j.node.setValue(SKAttributeValue(vectorFloat4: [Float(width), Float(above + below), Float(below), Float(0.5 / r)]), forAttribute: "a_box")
            j.node.setValue(SKAttributeValue(vectorFloat4: [Float(tilt), Float(j.seed), Float(fog), Float(j.amp)]), forAttribute: "a_pose")
            j.node.setValue(SKAttributeValue(vectorFloat4: [Float(simTime - j.lastStart), Float(gap), Float(sp.share * j.period),
                                                            Float((1 - sp.share) * j.period)]), forAttribute: "a_pulse")
            j.node.setValue(SKAttributeValue(vectorFloat4: [Float(pts[0].x), Float(pts[0].y), Float(pts[1].x), Float(pts[1].y)]), forAttribute: "a_sp1")
            j.node.setValue(SKAttributeValue(vectorFloat4: [Float(pts[2].x), Float(pts[2].y), Float(pts[3].x), Float(pts[3].y)]), forAttribute: "a_sp2")
        }
    }

    /// The spine the tentacles and arms hang along, in the sprite's own frame and bell radii: each bit of the trailing
    /// body hangs back along the way the bell's axis pointed when the margin passed it (a delay of its distance along
    /// over the trailing speed), sagging a little. Four points along its length, each kept lower than the last.
    private func spine(_ j: Jelly, _ sp: Species, heading: Double) -> [SIMD2<Double>] {
        var pos = SIMD3<Double>.zero, pts: [SIMD2<Double>] = []
        let steps = 16, ds = sp.spine / Double(steps), (c, s) = (cos(heading), sin(heading))
        for n in 1...steps {
            let back = min(Int((Double(n) - 0.5) * ds / sp.trail / Self.step), Self.kept - 1)
            let past = j.history[(j.head - back + Self.kept) % Self.kept]
            pos += norm(-past + SIMD3(0, -sp.sag, 0)) * ds
            if n % (steps / 4) == 0 {
                pts.append(SIMD2(pos.x * c + pos.y * s, min(-pos.x * s + pos.y * c, (pts.last?.y ?? 0) - 0.03 * sp.spine)))
            }
        }
        return pts
    }

    private func gauss() -> Double {
        (-2 * log(max(Double.random(in: 0...1, using: &rng), 1e-12))).squareRoot() * cos(2 * .pi * .random(in: 0...1, using: &rng))
    }

    private func randomUnit() -> SIMD3<Double> {
        let z = Double.random(in: -1...1, using: &rng), a = Double.random(in: 0...(2 * .pi), using: &rng), r = (1 - z * z).squareRoot()
        return SIMD3(r * cos(a), r * sin(a), z)
    }

    // MARK: - Shaders

    /// The water: the lit tank's blue, deeper toward the bottom, easing to the glow's black or the crystal tank's
    /// faint blue as the light goes, with marine snow drifting in it. Dithered, so the gradient doesn't band.
    private static let waterSource = """
    void main() {
        vec2 p = v_tex_coord * u_size * 2.0;
        vec3 tank = mix(vec3(0.01, 0.09, 0.26), vec3(0.09, 0.35, 0.86), v_tex_coord.y);
        vec3 dark = mix(vec3(0.0, 0.004, 0.012), vec3(0.0, 0.012, 0.03), v_tex_coord.y) * u_crystal;
        vec3 col = mix(dark, tank, u_lit);
        float s = 0.0;
        for (int i = 0; i < 3; i++) {
            float cell = 46.0 + 52.0 * float(i);
            vec2 q = p / cell + vec2(0.05 * sin(u_t * 0.05 + float(i)), u_t * (0.012 + 0.008 * float(i)));
            vec4 r = hash42(floor(q) + float(i) * 17.0);
            vec2 f = fract(q) - 0.5 - (r.yz - 0.5) * 0.6;
            s += step(r.x, 0.22) * exp(-dot(f, f) * cell * cell / (1.2 + 2.5 * float(i))) * (0.3 + 0.7 * r.w) * (0.5 + 0.5 * float(i));
        }
        col += (0.12 * u_lit + 0.05 * u_crystal * (1.0 - u_lit)) * s * vec3(0.8, 0.85, 0.9);
        gl_FragColor = vec4(col + (hash21(p) - 0.5) / 255.0, 1.0);
    }
    """

    private static let helpers = """
    float wrapf(float x, float y) { return x - y * floor(x / y); }
    // The bell's squeeze, 0 relaxed to 1 contracted, `ago` seconds before now: quick in, slow out. p: seconds since
    // this pulse began, the gap to the next (longer when a rest follows), the squeeze's and the re-opening's length.
    float squeezeAt(float ago, vec4 p) {
        float tau = wrapf(p.x - ago, p.y);
        return smoothstep(0.0, p.z, tau) * (1.0 - smoothstep(p.z, p.z + p.w, tau));
    }
    // A soft strand w wide at distance d, for pixels px wide, thinning in brightness rather than vanishing below a pixel.
    float strand(float d, float w, float px) {
        float ww = max(w, px);
        return (w / ww) * (1.0 - smoothstep(ww * 0.5, ww * 0.5 + px, abs(d)));
    }
    float cr(float a, float b, float c, float d, float f) {
        return b + 0.5 * f * (c - a + f * (2.0 * a - 5.0 * b + 4.0 * c - d + f * (3.0 * (b - c) + d - a)));
    }
    // Where the trailing body hangs at local height y (below the margin, y < 0): its sideways offset, and how far along
    // the spine it is. The spine is four points below the margin (a.xy, a.zw, b.xy, b.zw, bell radii, each lower than
    // the last), equally spaced along `len`, laid out by the CPU from where the bell's axis pointed a moment ago.
    // The spine's height `f` of the way along it, 0 at the margin.
    float spineY(float f, vec4 a, vec4 b) {
        float k = clamp(f * 4.0, 0.0, 4.0);
        return k < 1.0 ? a.y * k : k < 2.0 ? mix(a.y, a.w, k - 1.0) : k < 3.0 ? mix(a.w, b.y, k - 2.0) : mix(b.y, b.w, k - 3.0);
    }
    vec2 spineAt(float y, vec4 a, vec4 b, float len) {
        float x0 = -a.x, x1 = 0.0, x2 = a.x, x3 = a.z, x4 = b.x, x5 = b.z, x6 = 2.0 * b.z - b.x;
        vec2 r = vec2(0.0, -y);
        if (y < 0.0) {
            float f;
            if (y >= a.y) { f = y / min(a.y, -1e-4); r = vec2(cr(x0, x1, x2, x3, f), f * 0.25 * len); }
            else if (y >= a.w) { f = (y - a.y) / min(a.w - a.y, -1e-4); r = vec2(cr(x1, x2, x3, x4, f), (0.25 + 0.25 * f) * len); }
            else if (y >= b.y) { f = (y - a.w) / min(b.y - a.w, -1e-4); r = vec2(cr(x2, x3, x4, x5, f), (0.5 + 0.25 * f) * len); }
            else { f = (y - b.y) / min(b.w - b.y, -1e-4); r = vec2(f <= 1.0 ? cr(x3, x4, x5, x6, f) : mix(x4, x5, f), (0.75 + 0.25 * f) * len); }
        }
        return r;
    }
    """

    /// One jelly. The bell is marched through in 24 steps, so its rim is bright where the line of sight grazes the
    /// tissue rather than painted on; its margin lags the squeeze. Tentacles and oral arms hang along the spine, and
    /// each pixel looks at only the strands nearest it (four either side, front and back of the ring), so a hundred
    /// cost no more than eight. A moon jelly is drawn lit (`u_lit` 1) or glowing (0), or between as the light changes;
    /// a crystal jelly under a blue lamp, with its ring of fluorescent green points.
    private static let medusaSource = """
    void main() {
        vec2 q = vec2((v_tex_coord.x - 0.5) * a_box.x, v_tex_coord.y * a_box.y - a_box.z);
        float px = a_box.w, t = u_t;
        float tilt = a_pose.x, seed = a_pose.y, bright = a_pose.z, amp = a_pose.w;
        float S = amp * squeezeAt(0.0, a_pulse), Sm = amp * squeezeAt(0.15, a_pulse);
        float A = 1.0 - SHRINK * S, C = HEIGHT + RISE * S, Am = 1.0 - SHRINK * Sm;
        float cb = cos(tilt), sb = sin(tilt);
        float tissue = 0.0, skin = 0.0, organ = 0.0, ringPts = 0.0;
        float wide = max(A, Am) + 0.04, deep = wide * cb + C * abs(sb) + 0.04;
        if (abs(q.x) < wide && q.y > -wide * abs(sb) - 0.06 && q.y < C * cb + wide * abs(sb) + 0.04) {
            float dz = 2.0 * deep / 20.0;
            float jitter = hash21(v_tex_coord * 913.0 + seed);
            for (int i = 0; i < 20; i++) {
                float z = deep - dz * (float(i) + jitter);
                float Yb = q.y * cb + z * sb;
                float Zb = -q.y * sb + z * cb;
                float rho = length(vec2(q.x, Zb));
                float phi = atan(Zb, q.x);
                float hn = clamp(Yb / C, 0.0, 1.0);
                float outer = A * sqrt(max(1.0 - hn * hn, 0.0)) + (Am - A) * (1.0 - smoothstep(0.0, 0.27 * C, Yb));
                float inH = C * 0.55;
                float inner = A * 0.94 * sqrt(max(1.0 - (Yb / inH) * (Yb / inH), 0.0));
                float below = smoothstep(-0.015, 0.015, Yb);
                tissue += smoothstep(outer + 0.02, outer - 0.02, rho) * below * smoothstep(inner - 0.02, inner + 0.02, rho) * dz;
                float sk = (exp(-pow((rho - outer) / 0.035, 2.0)) + 0.5 * exp(-pow((rho - inner) / 0.035, 2.0)) * step(Yb, inH))
                    * below * smoothstep(C + 0.03, C - 0.01, Yb);
                skin += sk * (1.0 + CANALK * pow(abs(cos(phi * NC * 0.5)), CANALSHARP) * (1.0 - hn)) * dz;
                #if GONADS
                if (abs(Yb - inH * 0.95) < 0.25 && rho < 0.62 * A) for (int k = 0; k < 4; k++) {
                    float ang = 1.5708 * float(k) + 0.785;
                    vec2 d = vec2(q.x, Zb) - 0.34 * A * vec2(cos(ang), sin(ang));
                    float open = smoothstep(-0.95, -0.7, dot(normalize(d + 1e-4), vec2(cos(ang), sin(ang)))); // the gap faces the middle
                    organ += exp(-pow((length(d) - 0.16 * A) / 0.04, 2.0)) * open * exp(-pow((Yb - inH * 0.95) / 0.09, 2.0)) * dz * 5.0;
                }
                #endif
                #if RING
                float idx = floor(phi / 6.2832 * 100.0 + 0.5);
                float dphi = (phi - idx * 6.2832 / 100.0) * Am;
                ringPts += exp(-(pow(rho - outer, 2.0) + Yb * Yb + dphi * dphi) / 0.0006) * dz * 45.0;
                #endif
            }
        }
        // The strands nearest this pixel: where a strand's root would sit for this x, front and back of the ring.
        float tent = 0.0, arm = 0.0;
        vec2 mid = spineAt(q.y, a_sp1, a_sp2, SPLEN);
        float r0 = max((1.0 - CONVERGE * smoothstep(0.0, TLEN * 0.6, mid.y)), 0.2);
        float reach = Am * abs(sb) + 0.06;
        if (q.y < reach && q.y > spineY(TLEN / SPLEN, a_sp1, a_sp2) - reach - 0.1 && abs(q.x - mid.x) < r0 + 0.25)
        for (int side = 0; side < 2; side++) {
            float around = acos(clamp((q.x - mid.x) / r0, -1.0, 1.0)) / 6.2832 * float(NT);
            float centre = side == 0 ? around : float(NT) - around;
            for (int n = -2; n < 2; n++) {
                float fi = wrapf(floor(centre) + float(n), float(NT));
                float phi = 6.2832 * (fi + 0.4 * hash11(fi * 7.13 + seed)) / float(NT);
                float rootY = -Am * sin(phi) * sb;
                vec2 sp = spineAt(q.y - rootY, a_sp1, a_sp2, SPLEN);
                float s = sp.y, own = hash11(fi * 3.31 + seed * 0.7), tl = TLEN * (1.0 - TVARY * own * 0.6);
                float r = (1.0 - SHRINK * amp * squeezeAt(0.15 + s / 3.0, a_pulse)) * (1.0 - CONVERGE * smoothstep(0.0, TLEN * 0.6, s));
                float x = r * cos(phi) + sp.x + SWAY * s * (noise(vec2(s * 0.7 - t * 0.25, fi * 3.7 + seed)) - 0.5);
                float fade = smoothstep(-0.02, 0.06, s) * (1.0 - smoothstep(tl * 0.5, tl, s));
                tent += strand(q.x - x, TW * (1.0 - 0.6 * clamp(s / tl, 0.0, 1.0)), px) * fade * (0.7 + 0.3 * sin(phi))
                    * (1.0 - TVARY * 0.8 * hash11(fi * 9.7 + seed));
            }
        }
        if (q.y < C * 0.22 + 0.2 && q.y > spineY(ALEN / 0.6 / SPLEN, a_sp1, a_sp2) * 0.6 - reach - 0.15 && abs(q.x - 0.6 * mid.x) < 0.7)
        for (int k = 0; k < NOA; k++) {
            float fk = float(k);
            float phi = 1.5708 * fk + 0.785 + 0.3 * hash11(fk + seed);
            float rootY = C * 0.22 - 0.14 * sin(phi) * sb;
            vec2 sp = spineAt((q.y - rootY) / 0.6, a_sp1, a_sp2, SPLEN); // the arms trail slower than the tentacles
            float s = 0.6 * sp.y;
            float x = 0.14 * cos(phi) * (1.0 + 1.5 * amp * squeezeAt(s / 1.8, a_pulse) * min(s, 1.0)) + ASPREAD * s * cos(phi)
                + 0.6 * sp.x + ASWAY * s * (noise(vec2(s * 0.5 - t * 0.15, fk * 5.3 + seed)) - 0.5);
            float w = AW * (0.35 + 0.65 * abs(cos(s * TWIST + fk * 1.3 + t * 0.1))) * (1.0 - 0.5 * clamp(s / ALEN, 0.0, 1.0));
            float d = abs(q.x - x);
            float frill = 0.5 + noise(vec2(s * 9.0, fk * 11.0 + d * 30.0));
            float fade = smoothstep(-0.05, 0.1, s) * (1.0 - smoothstep(ALEN * 0.55, ALEN, s));
            arm += (0.12 * (1.0 - smoothstep(w * 0.5, w * 0.5 + px, d)) + 0.4 * exp(-pow((d - w * 0.45) / (0.25 * w + px), 2.0)) * frill) * fade;
        }
        #if RING
        // Crystal jellies under a blue lamp: the bell and strands faintly blue, the ring of points fluorescent green.
        vec3 body = vec3(0.3, 0.5, 1.0) * vec3(0.62, 0.71, 0.78);
        vec3 col = (body * (tissue * 0.22 + skin * 2.6 + organ * 1.5 + tent * 0.8 + arm * 0.7)) * 0.85 + vec3(0.0, 1.0, 0.76) * min(ringPts, 2.5) * 0.6;
        col = 0.59 * (vec3(1.0) - exp(-col * bright / 0.59));
        #else
        // Moon jellies: lit, pale against the tank's blue, or glowing; mixed by how lit the tank is.
        vec3 pale = vec3(0.45, 0.82, 1.0);
        vec3 litCol = (pale * vec3(0.82, 0.87, 0.95) * (tissue * 0.22 + skin * 2.6) + pale * vec3(0.84, 0.82, 0.96) * organ * 1.5
            + pale * vec3(0.8, 0.85, 0.95) * (tent * 0.8 + arm * 0.7)) * 0.5;
        vec3 glowCol = vec3(0.0, 0.64, 1.0) * (tissue * 0.18 + skin * 2.2 + organ * 0.9 + tent * 0.5 + arm * 0.4) * 0.55;
        vec3 col = mix(0.59 * (vec3(1.0) - exp(-glowCol * bright / 0.59)), 0.75 * (vec3(1.0) - exp(-litCol * bright / 0.75)), u_lit);
        #endif
        gl_FragColor = vec4(col * u_fade, 0.0);
    }
    """
}

private func length(_ v: SIMD3<Double>) -> Double { (v * v).sum().squareRoot() }
private func norm(_ v: SIMD3<Double>) -> SIMD3<Double> { v / max(length(v), 1e-9) }
private func dot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double { (a * b).sum() }
private func cross(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> SIMD3<Double> {
    SIMD3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
}
/// Rodrigues: v turned by `angle` about the unit axis k.
private func turned(_ v: SIMD3<Double>, _ k: SIMD3<Double>, _ angle: Double) -> SIMD3<Double> {
    v * cos(angle) + cross(k, v) * sin(angle) + k * dot(k, v) * (1 - cos(angle))
}

private extension UInt64 {
    var nonzero: UInt64? { self == 0 ? nil : self }
}
