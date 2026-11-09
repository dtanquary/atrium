import AppKit
import simd
import SpriteKit

@MainActor func kelpForest(size: CGSize) -> SKScene { KelpForest(size: size) }

/// A forest of giant kelp seen from inside it (docs/kelp-forest.md): clumps of rope-thin stipes rising from their
/// holdfasts into blue-green haze, a blade on a float every few centimetres up each, shafts of sunlight through the
/// canopy, and the whole forest swaying in the swell, dragged by the water rather than springing back. Each frond is a
/// chain of buoyant links in a sea of swell, slow surge and current (research-method.md §2), as the mock-ups Dave chose
/// moved it. The water is one shader; near fronds are a sprite a blade, posed every frame from their chain, and far
/// fronds a card a link with its blades drawn in, all from one texture of cards drawn at load, so they draw as one
/// batch. Colours are the look research's samples of real photos.
final class KelpForest: SKScene {
    nonisolated static let looks = [
        "Teal in Light Mode, dusk in Dark Mode", "Teal by day, dusk at night",
        "Golden in Light Mode, dusk in Dark Mode", "Golden by day, dusk at night",
        "Teal", "Golden", "Dusk",
    ]
    nonisolated static let views = ["Level through the forest", "Looking up into the canopy"]
    nonisolated static let knobs = [
        Knob(key: "kelp.look", label: "Look", range: 0...Double(looks.count - 1), standard: 0, section: "Look",
             format: .choice(looks)),
        Knob(key: "kelp.view", label: "View", range: 0...1, standard: 0, section: "Look", format: .choice(views)),
        Knob(key: "kelp.swell", label: "Swell", range: 0.25...2, standard: 1, section: "Sea", format: .times),
        Knob(key: "kelp.speed", label: "Speed", range: 0.5...2, standard: 1, section: "Sea", format: .times),
    ]

    // MARK: - Looks

    /// A light: the water's colour and clarity, the light, and the kelp, as a camera's white balance shows them
    /// (research-look.md §3), in linear light. `deep` is the water looking level at the camera's depth, `up` looking
    /// straight up; `kelp` a near blade lit from our side, `glow` one with the light coming through it.
    struct Look {
        var ext: SIMD3<Float>, deep: SIMD3<Float>, up: SIMD3<Float>, sky: SIMD3<Float>, sun: SIMD3<Float>
        var kelp: SIMD3<Float>, glow: SIMD3<Float>, sand: SIMD3<Float>
        var rays: Float, snow: Float, caustics: Float
        var expo: [Float] // by view: level, looking up (held to the look research's brightness caps)
        var sunElevation: Float // degrees

        func mixed(_ o: Look, _ t: Float) -> Look {
            func m(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> SIMD3<Float> { a + (b - a) * t }
            func f(_ a: Float, _ b: Float) -> Float { a + (b - a) * t }
            return Look(ext: m(ext, o.ext), deep: m(deep, o.deep), up: m(up, o.up), sky: m(sky, o.sky), sun: m(sun, o.sun),
                        kelp: m(kelp, o.kelp), glow: m(glow, o.glow), sand: m(sand, o.sand), rays: f(rays, o.rays),
                        snow: f(snow, o.snow), caustics: f(caustics, o.caustics),
                        expo: zip(expo, o.expo).map { f($0, $1) }, sunElevation: f(sunElevation, o.sunElevation))
        }
    }

    private static func lin(_ hex: Int) -> SIMD3<Float> {
        SIMD3(pow(Float(hex >> 16 & 255) / 255, 2.2), pow(Float(hex >> 8 & 255) / 255, 2.2), pow(Float(hex & 255) / 255, 2.2))
    }

    /// The Channel Islands' sunlit teal (NOAA's Cojo Anchorage, public domain), Patagonia's golden backlit forest
    /// (CC BY-SA 4.0) and Cape Town's deep blue at dusk (Strawberry Rocks, CC BY-SA 3.0), as research-look.md sampled them.
    static let teal = Look(ext: [0.16, 0.1, 0.09], deep: lin(0x18717E), up: lin(0x6EB4C4), sky: lin(0xD4ECF0), sun: lin(0xFFFFFF),
                           kelp: lin(0x8A7F24), glow: lin(0xB4A632), sand: lin(0xA89A78), rays: 1, snow: 0.3, caustics: 1,
                           expo: [0.8, 0.42], sunElevation: 60)
    static let golden = Look(ext: [0.14, 0.17, 0.3], deep: lin(0x4D2E02), up: lin(0xA88126), sky: lin(0xE8D8A0), sun: lin(0xFFF0C8),
                             kelp: lin(0x6C4202), glow: lin(0xC08A10), sand: lin(0x8A6A30), rays: 1.4, snow: 0.3, caustics: 1,
                             expo: [0.9, 0.45], sunElevation: 60)
    static let dusk = Look(ext: [0.12, 0.06, 0.045], deep: lin(0x001E3E), up: lin(0x01587C), sky: lin(0x046489), sun: lin(0x6090B0),
                           kelp: lin(0x050A12), glow: lin(0x0C2034), sand: lin(0x0A1A2A), rays: 0.5, snow: 0.12, caustics: 0,
                           expo: [0.2, 0.12], sunElevation: 4)

    // MARK: - Views

    /// Where the camera stands: metres above the floor, the water's depth, how far it's tipped up, and where the plants
    /// stand. Both as the mock-ups Dave chose (round 2's A and D).
    struct View { var camY: Double, depth: Double, pitch: Double, near: Double, far: Double, plants: Int }
    static let viewsAt = [View(camY: 2.5, depth: 12, pitch: 20, near: 6, far: 30, plants: 10),
                          View(camY: 2, depth: 10, pitch: 58, near: 3.5, far: 14, plants: 11)]

    // MARK: - State

    private var viewIndex: Int
    private var spot: View { Self.viewsAt[viewIndex] }
    private let fovTan = tan(32 * Double.pi / 180) // half the view's width, as a slope: 64° across
    private var cam: SIMD3<Double>
    private var sea: Sea
    private var fronds: [Frond] = []
    private var simTime = 0.0, lastTime: TimeInterval?
    private var rng: SplitMix
    private var atlas: Atlas!
    private let water = SKSpriteNode(color: .black, size: .zero)
    private var appearance: NSKeyValueObservation?
    private var sunLit = 1.0, lastSun = -100.0, shownLit: Float = -1

    // The look's uniforms, shared by the water and the kelp; set from the Look menu, eased as it changes.
    private let uExt = SKUniform(name: "u_ext", vectorFloat3: .zero), uDeep = SKUniform(name: "u_deep", vectorFloat3: .zero)
    private let uUp = SKUniform(name: "u_up", vectorFloat3: .zero), uSky = SKUniform(name: "u_sky", vectorFloat3: .zero)
    private let uSun = SKUniform(name: "u_sun", vectorFloat3: .zero), uKelp = SKUniform(name: "u_kelp", vectorFloat3: .zero)
    private let uGlow = SKUniform(name: "u_glow", vectorFloat3: .zero), uSand = SKUniform(name: "u_sand", vectorFloat3: .zero)
    private let uSunDir = SKUniform(name: "u_sundir", vectorFloat3: .zero)
    private let uLook = SKUniform(name: "u_look", vectorFloat4: .zero) // rays, snow, caustics, exposure
    private let uTime = SKUniform(name: "u_t", float: 0), uSurge = SKUniform(name: "u_surge", vectorFloat2: .zero)
    private let uPx: SKUniform

    init(size: CGSize, view index: Int? = nil) {
        viewIndex = index ?? Int(Self.knobs[1].value)
        cam = SIMD3(0, Self.viewsAt[viewIndex].camY, 0)
        let seed = UInt64(max(0, UserDefaults.standard.integer(forKey: "kelp.seed")))
        rng = SplitMix(state: seed != 0 ? seed : .random(in: 1...UInt64.max))
        sea = Sea(height: Self.knobs[2].value, depth: Self.viewsAt[viewIndex].depth, rng: &rng)
        uPx = SKUniform(name: "u_px", vectorFloat2: [Float(size.width * 2), Float(size.height * 2)])
        super.init(size: size)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func sceneDidLoad() {
        backgroundColor = .black
        setUp()
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: UserDefaults.didChangeNotification, object: nil)
        appearance = NSApplication.shared.observe(\.effectiveAppearance) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.settleLook(at: false) }
        }
    }

    /// Builds the water and a new forest for the view picked.
    private func setUp() {
        atlas = Atlas.shared()
        cam = SIMD3(0, spot.camY, 0)
        sea = Sea(height: Self.knobs[2].value, depth: spot.depth, rng: &rng)
        water.size = size
        water.anchorPoint = .zero
        water.zPosition = -1000
        water.shader = SKShader(source: defines + Self.common + Self.waterSource, uniforms: [
            uExt, uDeep, uUp, uSky, uSun, uKelp, uGlow, uSand, uSunDir, uLook, uTime, uSurge, uPx,
            SKUniform(name: "u_canopy", texture: sharedTexture("kelp-canopy") { Self.canopy() }),
        ])
        addChild(water)
        let kelp = SKShader(source: defines + Self.common + Self.kelpSource, uniforms: [
            uExt, uDeep, uUp, uSun, uKelp, uGlow, uSunDir, uLook, uTime, uPx,
        ])
        kelp.attributes = [SKAttribute(name: "a_card", type: .vectorFloat4), SKAttribute(name: "a_info", type: .vectorFloat4)]
        plant(with: kelp)
        settleLook(at: true)
        // Run the sea a while first, so the forest has settled into it: 30 s in steps of 1/30 s.
        for k in 0..<900 { step(at: simTime + Double(k - 900) / 30, dt: 1.0 / 30) }
        pose(at: simTime)
    }

    override func didMove(to view: SKView) {
        Location.shared.start()
        let scale = view.window?.backingScaleFactor ?? 2
        uPx.vectorFloat2Value = [Float(size.width * scale), Float(size.height * scale)]
    }

    @objc private func settingsChanged() {
        if Int(Self.knobs[1].value) != viewIndex {
            // A new view: a new forest seen from there.
            viewIndex = Int(Self.knobs[1].value)
            removeAllChildren()
            fronds = []
            setUp()
            return
        }
        sea.height = Self.knobs[2].value
        settleLook(at: false)
    }

    /// The view's fixed numbers, written into both shaders.
    private var defines: String {
        let d: [String: String] = [
            "TANH": "\(fovTan)", "ASPECT": "\(Double(size.height / size.width))", "PITCH": "\(spot.pitch * .pi / 180)",
            "CAMY": "\(spot.camY)", "DEPTH": "\(spot.depth)",
        ]
        return d.sorted { $0.key < $1.key }.map { "#define \($0.key) \($0.value)\n" }.joined()
    }

    // MARK: - The look

    /// What the Look menu asks for: which light look (teal or golden), and how far toward dusk (1 all dusk).
    private var wanted: (light: Look, dusk: Double) {
        switch Int(Self.knobs[0].value) {
        case 0: return (Self.teal, systemIsDark ? 1 : 0)
        case 1: return (Self.teal, 1 - sunLit)
        case 2: return (Self.golden, systemIsDark ? 1 : 0)
        case 3: return (Self.golden, 1 - sunLit)
        case 4: return (Self.teal, 0)
        case 5: return (Self.golden, 0)
        default: return (Self.teal, 1)
        }
    }

    /// The Sun's say where you are: full day, none at night, easing through civil twilight (as Jellyfish's).
    private func sun() -> Double {
        let here = Location.shared.coordinate, jd = Sky.julianDate(Date())
        let altitude = asin((Sky.horizonMatrix(jd: jd, latitude: here.latitude, longitude: here.longitude) * Sky.sun(jd)).z) * 180 / .pi
        return simd_smoothstep(-6, 1, altitude)
    }

    private var lightLook = KelpForest.teal, duskShown: Float = 0

    /// Brings the look toward what's wanted: at once when built, otherwise eased by `update`.
    private func settleLook(at once: Bool) {
        if simTime - lastSun > 60 || once { (sunLit, lastSun) = (sun(), simTime) }
        let target = wanted
        lightLook = target.light
        if once { duskShown = Float(target.dusk) }
        apply(lightLook.mixed(Self.dusk, duskShown))
    }

    private func apply(_ l: Look) {
        uExt.vectorFloat3Value = l.ext; uDeep.vectorFloat3Value = l.deep; uUp.vectorFloat3Value = l.up
        uSky.vectorFloat3Value = l.sky; uSun.vectorFloat3Value = l.sun; uKelp.vectorFloat3Value = l.kelp
        uGlow.vectorFloat3Value = l.glow; uSand.vectorFloat3Value = l.sand
        uLook.vectorFloat4Value = [l.rays, l.snow, l.caustics, l.expo[viewIndex]]
        // The Sun under water, bent toward the vertical by refraction, a little to one side of where we look.
        let zen = Double(90 - l.sunElevation) * .pi / 180, inWater = asin(sin(zen) / 1.333), az = 10 * Double.pi / 180
        uSunDir.vectorFloat3Value = SIMD3(Float(sin(inWater) * sin(az)), Float(cos(inWater)), Float(sin(inWater) * cos(az)))
    }

    // MARK: - The forest

    /// One frond: a chain of buoyant links from its plant's holdfast (research-method.md §2), and its sprites.
    private struct Frond {
        var base: SIMD3<Double>, len: Double, lean: SIMD3<Double>
        var p: [SIMD3<Double>], v: [SIMD3<Double>]
        var near: Bool
        var blades: [Blade] = [] // near fronds: a sprite a blade
        var stipe: [SKSpriteNode] = [] // near fronds: a sprite a link
        var cards: [SKSpriteNode] = [] // far fronds: a card for every two links, its blades drawn in
        var restPpm = 1.0
    }

    /// A near blade: where it is up its frond, its bearing round the stipe and lift away from it, its length.
    private struct Blade {
        let node: SKSpriteNode
        let at: Double, az: Double, el: Double, length: Double, seed: Double
    }

    static let links = 14

    /// Plants where the view's numbers say, more far than near as a forest in perspective has, each a holdfast and a
    /// clump of fronds fanning from it (research-method.md §1): the longest about 1.4 × the depth − 0.8 m, its last
    /// part lying on the surface; a third of them young and shorter.
    private func plant(with shader: SKShader) {
        let maxLen = 1.4 * spot.depth - 0.79
        let nearCut = spot.near + 2.5 // closer than this, a sprite a blade; beyond, cards
        for _ in 0..<spot.plants {
            let z = spot.near + (spot.far - spot.near) * pow(Double.random(in: 0...1, using: &rng), 1.5)
            let x = Double.random(in: -1...1, using: &rng) * (fovTan * z + 2)
            let near = z < nearCut
            let holdfast = SKSpriteNode(texture: atlas.holdfast)
            holdfast.shader = shader
            addChild(holdfast)
            var made: [Int] = []
            for _ in 0..<Int.random(in: 6...10, using: &rng) {
                let len = maxLen * (Double.random(in: 0...1, using: &rng) < 0.65 ? .random(in: 0.78...1.0, using: &rng) : .random(in: 0.2...0.75, using: &rng))
                let a = Double.random(in: 0...(2 * .pi), using: &rng), r = Double.random(in: 0.05...0.2, using: &rng)
                let base = SIMD3(x + .random(in: -0.12...0.12, using: &rng), 0, z + .random(in: -0.12...0.12, using: &rng))
                let lean = SIMD3(cos(a) * r, 0, sin(a) * r)
                var frond = Frond(base: base, len: len, lean: lean, p: rest(base, len, lean), v: Array(repeating: .zero, count: Self.links + 1), near: near)
                let mid = project(frond.p[Self.links / 2])
                frond.restPpm = mid.ppm
                let depthZ = CGFloat(-mid.dist)
                if near {
                    for _ in 0..<Self.links {
                        let s = SKSpriteNode(texture: atlas.stipe)
                        s.anchorPoint = CGPoint(x: 0.5, y: 0)
                        s.zPosition = depthZ
                        info(s, card: atlas.stipe, dist: mid.dist, height: len / 2, seed: 0)
                        s.shader = shader
                        addChild(s)
                        frond.stipe.append(s)
                    }
                    // A blade every 12 cm or so, few and small low down, a dense ruff high up [SBCNPP, FS85].
                    var u = 0.4
                    while u < len - 0.1 {
                        let high = simd_smoothstep(0.1, 0.7, u / len + (len < 8 ? 0.3 : 0))
                        if Double.random(in: 0...1, using: &rng) < 0.25 + 0.75 * high {
                            let card = Int.random(in: 0..<atlas.blades.count, using: &rng)
                            let length = Atlas.bladeLength * .random(in: 0.45...1, using: &rng) * (0.55 + 0.45 * high)
                            let node = SKSpriteNode(texture: atlas.blades[card])
                            node.anchorPoint = CGPoint(x: Atlas.bladeAnchor, y: 0.5)
                            let w = length / Atlas.bladeLength
                            node.size = CGSize(width: Atlas.bladeCard.width * w * mid.ppm / 2, height: Atlas.bladeCard.height * w * mid.ppm / 2)
                            node.zPosition = depthZ
                            info(node, card: atlas.blades[card], dist: mid.dist, height: u, seed: .random(in: 0...1, using: &rng))
                            node.shader = shader
                            addChild(node)
                            frond.blades.append(Blade(node: node, at: u, az: .random(in: 0...(2 * .pi), using: &rng),
                                                      el: 0.3 + pow(.random(in: 0...1, using: &rng), 2), length: length,
                                                      seed: .random(in: 0...100, using: &rng)))
                        }
                        u += .random(in: 0.07...0.17, using: &rng)
                    }
                } else {
                    for k in stride(from: 0, to: Self.links, by: 2) {
                        let f = Double(k) / Double(Self.links)
                        let set = f * len < 3 ? atlas.sparse : atlas.dense
                        let card = set[Int.random(in: 0..<set.count, using: &rng)]
                        let node = SKSpriteNode(texture: card)
                        node.anchorPoint = Atlas.cardAnchor
                        node.zPosition = depthZ
                        info(node, card: card, dist: mid.dist, height: (f + 1 / Double(Self.links)) * len, seed: .random(in: 0...1, using: &rng))
                        node.shader = shader
                        addChild(node)
                        frond.cards.append(node)
                    }
                }
                made.append(fronds.count)
                fronds.append(frond)
            }
            let at = project(SIMD3(x, 0, z))
            holdfast.position = CGPoint(x: at.px.x / 2, y: at.px.y / 2)
            holdfast.anchorPoint = CGPoint(x: 0.5, y: 0.1)
            holdfast.size = CGSize(width: Atlas.holdfastSize.width * at.ppm / 2, height: Atlas.holdfastSize.height * at.ppm / 2)
            holdfast.zPosition = CGFloat(-at.dist) + 0.01
            info(holdfast, card: atlas.holdfast, dist: at.dist, height: 0.2, seed: 0.5)
        }
    }

    /// Sets a sprite's fixed numbers for the kelp shader: the card's place in the texture, and how far off it is, how
    /// high, and a number of its own.
    // ponytail: fog and light are fixed at each sprite's place at rest; a near frond swaying ±1 m at 6 m changes its fog
    // by a few percent. Set them each frame (an attribute a sprite) if a near one is seen to glow or darken wrongly.
    private func info(_ node: SKSpriteNode, card: SKTexture, dist: Double, height: Double, seed: Double) {
        let r = card.textureRect()
        node.setValue(SKAttributeValue(vectorFloat4: [Float(r.minX), Float(r.minY), Float(r.width), Float(r.height)]), forAttribute: "a_card")
        node.setValue(SKAttributeValue(vectorFloat4: [Float(dist), Float(height), Float(seed), 0]), forAttribute: "a_info")
    }

    /// A frond at rest: up from its holdfast, leaning its own way, and whatever is longer than the water is deep lying
    /// on the surface downstream.
    private func rest(_ base: SIMD3<Double>, _ len: Double, _ lean: SIMD3<Double>) -> [SIMD3<Double>] {
        let up = simd_normalize(SIMD3(lean.x, 1, lean.z)), flat = simd_normalize(SIMD3(1, 0, 0.4) + lean)
        var points = [base]
        for i in 1...Self.links {
            let l = len / Double(Self.links), last = points[i - 1]
            var next = last + up * l
            if next.y > spot.depth - 0.05 { next = SIMD3(last.x, spot.depth - 0.05, last.z) + flat * l }
            points.append(next)
        }
        return points
    }

    // MARK: - Motion

    override func update(_ currentTime: TimeInterval) {
        let dt = frameTime(currentTime, &lastTime) * Self.knobs[3].value
        let step = 1.0 / 60
        // Steps of 1/60 s at fixed times, so the forest moves the same at any frame rate.
        let first = (simTime / step).rounded(.down) + 1
        simTime += dt
        for k in stride(from: first, through: (simTime / step).rounded(.down), by: 1).prefix(12) { self.step(at: k * step, dt: step) }
        // A change of look eases over a few seconds.
        let target = Float(wanted.dusk)
        if abs(target - duskShown) > 0.001 || shownLit < 0 {
            duskShown += (target - duskShown) * Float(min(1, dt / 1.5))
            lightLook = wanted.light
            apply(lightLook.mixed(Self.dusk, duskShown))
            shownLit = 1
        }
        if simTime - lastSun > 60 { settleLook(at: false) }
        pose(at: simTime)
    }

    /// Steps every frond: buoyancy, more high up where the floats are, and each frond's own slight lean away from the
    /// others in its plant; drag toward the water's velocity as |u − v|^0.6 (u − v); links that don't stretch; a little
    /// stiffness, so a slack frond curves rather than zigzags; and the surface, which it floats along.
    private func step(at t: Double, dt: Double) {
        let n = Self.links, top = spot.depth - 0.03
        for f in fronds.indices {
            let l = fronds[f].len / Double(n)
            let phases = sea.phases(at: fronds[f].base, t)
            var np = fronds[f].p
            for i in 1...n {
                let q = fronds[f].p[i], u = sea.flow(phases, y: q.y, t)
                let rel = u - fronds[f].v[i], r = simd_length(rel)
                let lift = (0.12 + 0.3 * Double(i) / Double(n)) * (SIMD3(0, 1, 0) + fronds[f].lean)
                fronds[f].v[i] += (lift + 2.0 * pow(r, 0.6) * rel) * dt
                np[i] = q + fronds[f].v[i] * dt
            }
            for _ in 0..<2 {
                for i in 1...n {
                    if i < n { np[i] += (0.5 * (np[i - 1] + np[i + 1]) - np[i]) * 0.075 }
                    let d = np[i] - np[i - 1]
                    np[i] = np[i - 1] + d * (l / max(simd_length(d), 1e-6))
                    np[i].y = min(max(np[i].y, 0.02), top)
                }
            }
            for i in 1...n { fronds[f].v[i] = (np[i] - fronds[f].p[i]) / dt }
            fronds[f].p = np
        }
    }

    /// Where a point is on the screen, in pixels at 2x from the bottom left; how far ahead it is, and how many pixels a
    /// metre there spans.
    private func project(_ p: SIMD3<Double>) -> (px: SIMD2<Double>, ppm: Double, dist: Double) {
        let rel = p - cam, pitch = spot.pitch * .pi / 180
        let zc = max(rel.y * sin(pitch) + rel.z * cos(pitch), 0.05), yc = rel.y * cos(pitch) - rel.z * sin(pitch)
        let w = Double(size.width) * 2, h = Double(size.height) * 2, aspect = h / w
        return (SIMD2(w / 2 + rel.x / zc / fovTan * w / 2, h / 2 + yc / zc / (fovTan * aspect) * h / 2), w / 2 / (fovTan * zc), simd_length(rel))
    }

    /// Poses every frond's sprites from its chain: stipes from node to node; each blade at its place, at its bearing
    /// and lift, streamed by the water's flow past it and fluttering by a few degrees, foreshortened where it points
    /// toward or away from us; far cards from node to node.
    private func pose(at t: Double) {
        let sh = sea.surfaceShift(t)
        uSurge.vectorFloat2Value = [Float(sh.x), Float(sh.y)]
        // ponytail: the snow, caustics and ripples jump once an hour where this wraps; carry their phase on the CPU if a jump shows
        uTime.floatValue = Float(t.truncatingRemainder(dividingBy: 3600))
        let w = Double(size.width) * 2, h = Double(size.height) * 2
        for f in fronds.indices {
            let fr = fronds[f]
            let pts = fr.p.map { project($0) }
            let xs = pts.map(\.px.x), ys = pts.map(\.px.y), reach = 1.2 * pts.map(\.ppm).max()!
            let shown = xs.max()! > -reach && xs.min()! < w + reach && ys.max()! > -reach && ys.min()! < h + reach
            if fr.near {
                for (k, s) in fr.stipe.enumerated() {
                    s.isHidden = !shown
                    guard shown else { continue }
                    let a = pts[k].px, b = pts[k + 1].px, d = b - a
                    s.position = CGPoint(x: a.x / 2, y: a.y / 2)
                    s.zRotation = atan2(-d.x, d.y)
                    s.size = CGSize(width: max(0.012 * pts[k].ppm, 1.2) / 2, height: simd_length(d) / 2 + 0.5)
                }
                // The water's flow past the frond on the screen, at a few places up it: 1 is about 15 cm/s.
                let phases = sea.phases(at: fr.base, t)
                let flows = stride(from: 0, through: Self.links, by: 2).map { k -> SIMD2<Double> in
                    let rel = (sea.flow(phases, y: fr.p[k].y, t) - fr.v[k]) / 0.15
                    return (project(fr.p[k] + rel * 0.2).px - pts[k].px) / (0.2 * pts[k].ppm)
                }
                for b in fr.blades {
                    b.node.isHidden = !shown
                    guard shown else { continue }
                    let x = b.at / fr.len * Double(Self.links), k = min(Int(x), Self.links - 1), frac = x - Double(k)
                    let at = pts[k].px + (pts[k + 1].px - pts[k].px) * frac
                    let ppm = pts[k].ppm + (pts[k + 1].ppm - pts[k].ppm) * frac
                    let tangent = simd_normalize(pts[k + 1].px - pts[k].px + SIMD2(0, 1e-6))
                    let normal = SIMD2(-tangent.y, tangent.x)
                    let fx = x / 2, fk = min(Int(fx), flows.count - 2), flow = flows[fk] + (flows[fk + 1] - flows[fk]) * (fx - Double(fk))
                    let az = b.az + 0.35 * sin(t * 0.45 + b.seed)
                    var dir = tangent * cos(b.el) + normal * sin(b.el) * cos(az) + flow * 0.8
                    let fore = simd_length(dir)
                    dir /= max(fore, 1e-6)
                    let flutter = 0.12 * sin(t * (1.1 + b.seed.truncatingRemainder(dividingBy: 1)) + b.seed + b.at * 2)
                    b.node.position = CGPoint(x: at.x / 2, y: at.y / 2)
                    b.node.zRotation = atan2(dir.y, dir.x) + flutter
                    b.node.xScale = min(max(fore, 0.25), 1) * ppm / fr.restPpm
                    b.node.yScale = ppm / fr.restPpm
                }
            } else {
                for (c, node) in fr.cards.enumerated() {
                    node.isHidden = !shown
                    guard shown else { continue }
                    let k = c * 2, a = pts[k].px, b = pts[min(k + 2, Self.links)].px, d = b - a
                    let ppm = pts[k + 1].ppm
                    node.position = CGPoint(x: a.x / 2, y: a.y / 2)
                    node.zRotation = atan2(-d.x, d.y)
                    node.size = CGSize(width: Atlas.cardSize.width * ppm / 2, height: Atlas.cardSize.height * simd_length(d) / Atlas.cardStipe / 2)
                }
            }
        }
    }

    // MARK: - The sea

    /// The sea (research-method.md §2): five swell components in a narrow band round a 12 s peak, so it comes in sets
    /// and never repeats; a slow surge of 100 to 160 s under them; and a weak current that wanders over minutes. Phases
    /// in Double, for days of running.
    struct Sea {
        struct Swell { var a: Double, omega: Double, k: Double, dir: SIMD2<Double>, phase: Double, sinhKH: Double }
        var swells: [Swell] = [], beat: (x: Double, omega: Double, phase: Double), current: (speed: Double, phase: Double)
        var height: Double, depth: Double

        init(height: Double, depth: Double, rng: inout SplitMix) {
            self.height = height
            self.depth = depth
            for _ in 0..<5 {
                let omega = 2 * .pi / (12 * Double.random(in: 0.88...1.12, using: &rng))
                var k = omega * omega / 9.81
                for _ in 0..<40 { k = omega * omega / (9.81 * tanh(k * depth)) } // ω² = g k tanh(k h)
                let bearing = 0.35 + Double.random(in: -0.3...0.3, using: &rng)
                swells.append(Swell(a: 0.158 * .random(in: 0.75...1.25, using: &rng), omega: omega, k: k,
                                    dir: SIMD2(cos(bearing), sin(bearing)), phase: .random(in: 0...(2 * .pi), using: &rng), sinhKH: sinh(k * depth)))
            }
            beat = (0.6, 2 * .pi / .random(in: 100...160, using: &rng), .random(in: 0...(2 * .pi), using: &rng))
            current = (0.015, .random(in: 0...(2 * .pi), using: &rng))
        }

        /// Each swell's phase at a place: worked out once a frond, as a frond is short beside the swell's length.
        func phases(at p: SIMD3<Double>, _ t: Double) -> [(c: Double, s: Double)] {
            swells.map { let ph = $0.k * ($0.dir.x * p.x + $0.dir.y * p.z) - $0.omega * t + $0.phase; return (cos(ph), sin(ph)) }
        }

        /// The water's velocity at height y, by linear wave theory, scaled by the Swell setting.
        func flow(_ phases: [(c: Double, s: Double)], y: Double, _ t: Double) -> SIMD3<Double> {
            var u = SIMD3<Double>.zero
            let y = min(max(y, 0), depth)
            for (s, ph) in zip(swells, phases) {
                let ky = s.k * y, ch = 1 + ky * ky / 2 + ky * ky * ky * ky / 24, sh = ky + ky * ky * ky / 6
                let horiz = s.a * s.omega * ch / s.sinhKH * ph.c
                u += SIMD3(s.dir.x * horiz, s.a * s.omega * sh / s.sinhKH * ph.s, s.dir.y * horiz)
            }
            u *= height
            u.x += height * beat.x * beat.omega * cos(beat.omega * t + beat.phase)
            let c = current.speed * (1 + 0.5 * sin(t / 420 + current.phase)), cb = 0.6 * sin(t / 900 + current.phase)
            return u + SIMD3(c * cos(cb), 0, c * sin(cb)) * (0.6 + 0.8 * y / depth)
        }

        /// How far the surface water is carried from rest, for the canopy and ripples drawn on it.
        func surfaceShift(_ t: Double) -> SIMD2<Double> {
            var d = SIMD2<Double>.zero
            for s in swells { d -= s.dir * (s.a * cosh(s.k * depth) / s.sinhKH * sin(s.phase - s.omega * t)) }
            return (d + SIMD2(beat.x * sin(beat.omega * t + beat.phase), 0)) * height
        }
    }

    /// Where the canopy lies on the surface, 0 open water to 1 thick, over 128 m round the camera at 50 cm a texel:
    /// patches drawn out along the swell, as the mock-up worked out per pixel. The same every time, so displays match.
    static func canopy() -> SKTexture {
        func hash(_ x: Float, _ y: Float) -> Float {
            var p = SIMD2(x, y) * SIMD2(123.34, 456.21)
            p -= p.rounded(.down)
            let d = simd_dot(p, p + 45.32)
            p += d
            let v = p.x * p.y
            return v - v.rounded(.down)
        }
        func noise(_ x: Float, _ y: Float) -> Float {
            let ix = x.rounded(.down), iy = y.rounded(.down), fx = x - ix, fy = y - iy
            let ux = fx * fx * (3 - 2 * fx), uy = fy * fy * (3 - 2 * fy)
            let a = hash(ix, iy) + (hash(ix + 1, iy) - hash(ix, iy)) * ux
            let b = hash(ix, iy + 1) + (hash(ix + 1, iy + 1) - hash(ix, iy + 1)) * ux
            return a + (b - a) * uy
        }
        func fbm(_ x: Float, _ y: Float) -> Float {
            var (s, a, px, py): (Float, Float, Float, Float) = (0, 0.5, x, y)
            for _ in 0..<4 { s += a * noise(px, py); px = px * 2.03 + 17.1; py = py * 2.03 + 9.3; a *= 0.5 }
            return s
        }
        let n = 256
        var bytes = [UInt8](repeating: 255, count: n * n * 4)
        for j in 0..<n {
            for i in 0..<n {
                let x = (Float(i) + 0.5) / Float(n) * 128 - 64, y = (Float(j) + 0.5) / Float(n) * 128 - 64
                let wx = noise(x * 0.17, y * 0.17), wy = noise(x * 0.17 + 5.2, y * 0.17 + 5.2)
                let v = simd_smoothstep(Float(0.47), 0.65, fbm(x * 0.22 + wx * 2, y * 0.34 + wy * 2))
                let k = (j * n + i) * 4
                bytes[k] = UInt8(v * 255); bytes[k + 1] = bytes[k]; bytes[k + 2] = bytes[k]
            }
        }
        let texture = SKTexture(data: Data(bytes), size: CGSize(width: n, height: n))
        texture.filteringMode = .linear
        return texture
    }

    // MARK: - Shaders

    /// Shared by the water and the kelp. Uniforms reach helpers only as arguments, so the look's colours are passed in.
    static let common = """
    float kHash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
    float kNoise(vec2 p) {
        vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
        return mix(mix(kHash(i), kHash(i + vec2(1.0, 0.0)), u.x), mix(kHash(i + vec2(0.0, 1.0)), kHash(i + vec2(1.0, 1.0)), u.x), u.y);
    }
    float kFbm(vec2 p) {
        float s = 0.0; float a = 0.5;
        for (int i = 0; i < 4; i++) { s += a * kNoise(p); p = p * 2.03 + vec2(17.1, 9.3); a *= 0.5; }
        return s;
    }
    // The way the camera looks through a point of the screen (uv 0 to 1, from the bottom left).
    vec3 rayDir(vec2 uv) {
        vec3 d = normalize(vec3((uv.x * 2.0 - 1.0) * TANH, (uv.y * 2.0 - 1.0) * TANH * ASPECT, 1.0));
        float c = cos(PITCH); float s = sin(PITCH);
        return vec3(d.x, d.y * c + d.z * s, -d.y * s + d.z * c);
    }
    // The canopy's blades seen from below: one in each cell of a 45 cm grid where the canopy is thick enough, about
    // 1.6 m by 15 cm, lying mostly along the swell. Returns cover, and how near the blade's middle (its edges glow).
    vec2 leaves(vec2 xz, float dens) {
        vec2 g = xz / 0.45;
        vec2 i = floor(g);
        float c = 0.0; float edge = 0.0;
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                vec2 id = i + vec2(float(x), float(y));
                float h = kHash(id * 1.31 + 7.0);
                vec2 ctr = id + vec2(kHash(id + 3.3), kHash(id + 8.1));
                float ang = 0.35 + (kHash(id + 5.9) - 0.5) * 1.8;
                vec2 dl = g - ctr;
                vec2 r = vec2(dl.x * cos(ang) + dl.y * sin(ang), -dl.x * sin(ang) + dl.y * cos(ang));
                r.y += 0.12 * sin(r.x * 3.0 + h * 9.0);
                float e = length(r / vec2(1.6, 0.13 + 0.06 * h));
                float on = step(h, dens * 1.6 - 0.2) * (1.0 - smoothstep(0.82, 1.0, e));
                edge = on > c ? e : edge;
                c = max(c, on);
            }
        }
        return vec2(c, edge);
    }
    // Sunlight at height y, as a share of what reaches the camera's depth.
    vec3 lightAt(float y, vec3 sun, vec3 ext) { return sun * exp(0.5 * dot(ext, vec3(0.333)) * (clamp(y, 0.0, DEPTH) - CAMY)); }
    // What an endless line of sight from height y sees of the water itself: brighter looking up and toward the Sun.
    vec3 waterCol(vec3 d, float y, vec3 deep, vec3 up, vec3 ext, vec3 sundir) {
        float yy = clamp(y + d.y * 5.0, 0.0, DEPTH);
        vec3 base = d.y < 0.0 ? mix(deep, deep * 0.5, smoothstep(0.0, 1.0, -d.y)) : mix(deep, up, smoothstep(0.0, 1.0, d.y));
        float f = pow(max(dot(d, sundir), 0.0), 5.0);
        return base * min(exp(0.25 * dot(ext, vec3(0.333)) * (yy - CAMY)), 1.35) * (1.0 + 0.6 * f);
    }
    """

    /// The water, the surface overhead with Snell's window and the canopy on it, the floor, the shafts of light let
    /// through the canopy's gaps, and marine snow: the mock-up's (docs/kelp-forest/mock.swift), with the look as
    /// uniforms.
    static let waterSource = """
    void main() {
        vec2 uv = v_tex_coord;
        vec3 d = rayDir(uv);
        float t = u_t;
        vec2 sw = u_surge;
        vec3 col = vec3(0.0);
        float dist = 400.0;
        if (d.y > 0.0) {
            float ts = (DEPTH - CAMY) / d.y;
            vec2 q = vec2(d.x, d.z) * ts - sw;
            vec2 g = 0.045 / (1.0 + ts * 0.08) * vec2(sin(q.x * 1.7 + t * 1.1) + 0.7 * sin(q.x * 1.1 + q.y * 2.3 - t * 1.4),
                                                      sin(q.y * 1.9 - t * 1.2) + 0.7 * sin(q.y * 1.3 - q.x * 2.1 + t * 0.9));
            vec3 n = normalize(vec3(-g.x, 1.0, -g.y));
            float c = dot(d, n);
            float win = smoothstep(0.6, 0.72, c);
            vec3 dr = normalize(d + 1.6 * (n - vec3(0.0, 1.0, 0.0)));
            float sd = max(dot(dr, u_sundir), 0.0);
            vec3 sky = u_sky * (0.55 + 0.45 * smoothstep(0.66, 1.0, c)) + u_sun * (exp((sd - 1.0) * 4000.0) * 1.2 + exp((sd - 1.0) * 30.0) * 0.35);
            vec3 below = waterCol(reflect(d, n), DEPTH, u_deep, u_up, u_ext, u_sundir) * 0.7;
            float thick = texture2D(u_canopy, q / 128.0 + 0.5).r;
            vec2 lv = vec2(thick * 0.55, 0.5);
            if (ts < 30.0 && thick > 0.05) { lv = leaves(q, thick); lv.x = mix(lv.x, thick * 0.55, smoothstep(10.0, 30.0, ts)); }
            // Lit from above through itself: deep gold where one blade lies, browner where many do, its margins paler.
            vec3 mat = u_glow * u_sky * (0.16 + 0.22 * lv.y * lv.y) * (1.0 - 0.6 * thick) + u_kelp * 0.05;
            col = mix(mix(below, sky, win), mat, lv.x * (0.75 + 0.25 * win));
            dist = ts;
        } else {
            float tf = CAMY / -d.y;
            vec2 p = vec2(d.x, d.z) * tf;
            float ripple = 0.9 + 0.1 * sin(p.x * 7.0 + 3.0 * kNoise(p * 1.3));
            float rock = smoothstep(0.55, 0.7, kFbm(p * 0.25));
            vec3 alb = mix(u_sand * ripple, u_sand * vec3(0.45, 0.42, 0.36), rock);
            float shade = 1.0 - 0.75 * texture2D(u_canopy, (p + u_sundir.xz / u_sundir.y * DEPTH - sw) / 128.0 + 0.5).r;
            float caus = pow(kNoise(p * 2.2 + vec2(t * 0.25, -t * 0.18)) * kNoise(p * 3.1 - vec2(t * 0.2, t * 0.3)) * 2.2, 2.0);
            col = alb * lightAt(0.0, u_sun, u_ext) * (0.25 + 0.75 * shade) * (0.75 + 0.9 * u_look.z * caus * shade) * (0.4 + 0.6 * u_sundir.y);
            dist = tf;
        }
        vec3 tr = exp(-u_ext * min(dist, 400.0));
        col = col * tr + waterCol(d, CAMY, u_deep, u_up, u_ext, u_sundir) * (1.0 - tr);
        // Shafts: sunlight let through the canopy's gaps and focused by the waves, parallel in the water and so
        // fanning out from the Sun on the screen.
        vec3 e1 = normalize(cross(u_sundir, vec3(0.0, 0.0, 1.0)));
        vec3 e2 = cross(u_sundir, e1);
        vec2 ang = normalize(vec2(dot(d, e1), dot(d, e2)) + vec2(1e-5, 0.0));
        float streak = kNoise(ang * 7.0 + vec2(t * 0.025, sw.x * 0.3)) * kNoise(ang * 19.0 + vec2(7.0, -t * 0.04 + sw.y));
        streak = mix(0.3, streak, smoothstep(0.02, 0.3, 1.0 - dot(d, u_sundir)));
        float r = min(dist, 6.0);
        vec3 Q = vec3(0.0, CAMY, 0.0) + d * r;
        float open = 1.0 - texture2D(u_canopy, (Q.xz + u_sundir.xz / u_sundir.y * (DEPTH - Q.y) - sw) / 128.0 + 0.5).r;
        float toward = 0.2 + 1.6 * pow(max(dot(d, u_sundir), 0.0), 3.0);
        col += u_look.x * u_sun * vec3(0.6, 0.9, 1.0) * lightAt(CAMY, u_sun, u_ext) * pow(streak, 2.5) * (0.3 + 0.7 * open)
            * (1.0 - exp(-0.1 * min(dist, 40.0))) * toward * 0.25;
        // Marine snow, lit by the water around it.
        float sn = 0.0;
        vec2 px = uv * u_px;
        for (int i = 0; i < 3; i++) {
            float cell = 40.0 + 46.0 * float(i);
            vec2 q = px / cell + vec2(sw.x * (0.6 + 0.5 * float(i)) + 0.05 * sin(t * 0.07 + float(i)), -t * (0.01 + 0.006 * float(i)));
            vec2 id = floor(q) + float(i) * 37.0;
            vec2 f = fract(q) - 0.5 - (vec2(kHash(id + 3.1), kHash(id + 7.7)) - 0.5) * 0.6;
            sn += step(kHash(id), 0.2) * exp(-dot(f, f) * cell * cell / (1.0 + 2.2 * float(i))) * (0.3 + 0.7 * kHash(id + 9.3)) * (0.4 + 0.5 * float(i));
        }
        col += u_look.y * sn * waterCol(vec3(0.0, 1.0, 0.0), CAMY, u_deep, u_up, u_ext, u_sundir) * 0.6;
        col *= u_look.w;
        gl_FragColor = vec4(pow(max(col, vec3(0.0)), vec3(1.0 / 2.2)) + (kHash(px) - 0.5) / 255.0, 1.0);
    }
    """

    /// Every kelp sprite: a card from the texture, whose red is how lit its tissue is from our side, green how much
    /// light comes through it (its thin margins most), and blue its floats and stalks; coloured by the look, glowing
    /// gold when we look toward the light, fogged by distance along its own line of sight.
    static let kelpSource = """
    void main() {
        vec2 local = (v_tex_coord - a_card.xy) / a_card.zw;
        vec4 c = texture2D(u_texture, a_card.xy + clamp(local, 0.0, 1.0) * a_card.zw);
        float alpha = c.a;
        vec4 out = vec4(0.0);
        // Most of a card is empty water: only its kelp is worth the light and the fog.
        if (alpha > 0.003) {
        vec3 m = c.rgb / max(alpha, 1e-3);
        vec2 suv = vec2(gl_FragCoord.x / u_px.x, 1.0 - gl_FragCoord.y / u_px.y);
        vec3 d = rayDir(suv);
        float back = smoothstep(-0.2, 0.9, dot(d, u_sundir));
        vec3 lit = lightAt(a_info.y, u_sun, u_ext);
        vec3 tint = mix(vec3(1.0), vec3(0.9, 1.0, 0.75), fract(a_info.z * 7.3) * 0.5);
        vec3 front = u_kelp * tint * lit * m.r;
        vec3 through = u_glow * tint * lit * (0.45 + 0.55 * m.g) * (0.5 + 0.5 * m.r);
        vec3 col = mix(front, through, back * 0.85 * (1.0 - m.b * 0.5));
        vec3 tr = exp(-u_ext * a_info.x);
        col = col * tr + waterCol(d, a_info.y, u_deep, u_up, u_ext, u_sundir) * (1.0 - tr);
        col *= u_look.w;
        out = vec4(pow(max(col, vec3(0.0)), vec3(1.0 / 2.2)) * alpha, alpha);
        }
        gl_FragColor = out;
    }
    """
}

// MARK: - The cards

/// One texture of everything the kelp is drawn from, made once and shared (`sharedTexture`): blade cards, far cards
/// of two links of frond with their blades, a stipe and a holdfast. Its red is how lit the tissue is from our side
/// (its ridges and wrinkles), green how much light comes through it (most at its thin margins), blue a float, stalk or
/// stipe, which glow less; the kelp shader colours them by the look. Drawn in Core Graphics, a blade as the mock-up's:
/// a short stalk on its float, a long blade tapering to its tip, its margin crimped and toothed every 2 cm, ridges
/// across it every 3 cm (the close-up of a real blade, docs/kelp-forest.md Still open).
@MainActor struct Atlas {
    let texture: SKTexture
    let blades: [SKTexture], sparse: [SKTexture], dense: [SKTexture], stipe: SKTexture, holdfast: SKTexture

    /// A blade card is 1 m by 22 cm, the blade's base 3 cm in; a blade at full size is 92 cm long with its stalk.
    static let bladeCard = (width: 1.0, height: 0.22), bladeAnchor = 0.03, bladeLength = 0.92
    /// A far card is 2 m by 3.2 m, its two links of stipe 2.1 m long from 20 cm up.
    static let cardSize = (width: 2.0, height: 3.2), cardStipe = 2.1, cardAnchor = CGPoint(x: 0.5, y: 0.2 / 3.2)
    static let holdfastSize = (width: 0.8, height: 0.5)
    private static let (w, h) = (1280, 2048)

    static func shared() -> Atlas {
        let texture = sharedTexture("kelp-cards") { draw() }
        func sub(_ x: Int, _ y: Int, _ cw: Int, _ ch: Int) -> SKTexture {
            SKTexture(rect: CGRect(x: Double(x) / Double(w), y: Double(y) / Double(h), width: Double(cw) / Double(w), height: Double(ch) / Double(h)), in: texture)
        }
        return Atlas(texture: texture,
                     blades: (0..<8).map { sub(0, $0 * 88, 400, 88) },
                     sparse: (0..<3).map { sub($0 * 410, 720, 400, 640) },
                     dense: (0..<3).map { sub($0 * 410, 1370, 400, 640) },
                     stipe: sub(412, 2, 8, 28), holdfast: sub(430, 0, 240, 150))
    }

    /// Draws the whole texture, the same every time (its own fixed seed), so copies on two displays match.
    private static func draw() -> SKTexture {
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        // Rows from the bottom, as SpriteKit's textures run.
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)
        var rng = SplitMix(state: 0x6B65_6C70)
        // Blade cards: eight blades, each along its card from its base 3 cm in, at 400 px a metre.
        for i in 0..<8 {
            let y = CGFloat(i * 88) + 44
            blade(ctx, base: CGPoint(x: 12, y: y), angle: 0, length: 0.92, curl: .random(in: -0.15...0.15, using: &rng),
                  halfWidth: .random(in: 0.045...0.075, using: &rng), ppm: 400, shade: .random(in: 0.4...0.75, using: &rng), seed: Double(i) * 7.1)
        }
        // A stipe and a holdfast.
        ctx.setFillColor(CGColor(red: 0.55, green: 0.15, blue: 0.6, alpha: 1))
        ctx.fill(CGRect(x: 413, y: 0, width: 6, height: 32))
        for _ in 0..<40 {
            let r = CGFloat.random(in: 6...22, using: &rng), x = CGFloat.random(in: 470...630, using: &rng)
            let top = 140 - abs(x - 550) * 1.4
            let y = CGFloat.random(in: 4...max(8, top), using: &rng)
            ctx.setFillColor(CGColor(red: .random(in: 0.35...0.6, using: &rng), green: 0.1, blue: 0.5, alpha: 1))
            ctx.fillEllipse(in: CGRect(x: x - r, y: y - r * 0.6, width: 2 * r, height: 1.2 * r))
        }
        // Far cards: two links of frond with their blades, sparse (low on a frond) and dense (the ruff), at 200 px a metre.
        for (row, (y0, dense)) in [(720, false), (1370, true)].enumerated() {
            for col in 0..<3 {
                let ox = CGFloat(col * 410), oy = CGFloat(y0), ppm: CGFloat = 200
                let stalkX = ox + 200, from = oy + 0.2 * ppm, to = from + 2.1 * ppm
                var blades: [(at: CGFloat, az: Double, el: Double, len: Double, hw: CGFloat, shade: CGFloat)] = []
                var u: CGFloat = 0.05
                while u < 2.1 {
                    if dense || Double.random(in: 0...1, using: &rng) < 0.35 {
                        blades.append((u, .random(in: 0...(2 * .pi), using: &rng), 0.3 + pow(.random(in: 0...1, using: &rng), 2),
                                       (dense ? 0.92 : 0.55) * .random(in: 0.5...1, using: &rng), .random(in: 0.045...0.075, using: &rng),
                                       .random(in: 0.4...0.75, using: &rng)))
                    }
                    u += dense ? .random(in: 0.06...0.14, using: &rng) : .random(in: 0.1...0.2, using: &rng)
                }
                // Those leaning away from us first, in the stipe's shadow; then the stipe; then those toward us.
                func draw(_ b: (at: CGFloat, az: Double, el: Double, len: Double, hw: CGFloat, shade: CGFloat), dim: CGFloat) {
                    let dx = sin(b.el) * cos(b.az), dy = cos(b.el), fore = (dx * dx + dy * dy).squareRoot()
                    blade(ctx, base: CGPoint(x: stalkX, y: from + b.at * ppm), angle: atan2(dy, dx), length: b.len * fore,
                          curl: CGFloat(sin(b.az * 3)) * 0.12, halfWidth: b.hw * CGFloat(0.4 + 0.6 * abs(cos(b.az * 1.7))),
                          ppm: ppm, shade: b.shade * dim, seed: Double(b.at) * 31 + Double(row))
                }
                for b in blades where sin(b.az) > 0 { draw(b, dim: 0.55) }
                ctx.setFillColor(CGColor(red: 0.5, green: 0.12, blue: 0.6, alpha: 1))
                ctx.fill(CGRect(x: stalkX - 1.2, y: from, width: 2.4, height: to - from))
                for b in blades where sin(b.az) <= 0 { draw(b, dim: 1) }
            }
        }
        let bytes = Data(bytes: ctx.data!, count: w * h * 4)
        let texture = SKTexture(data: bytes, size: CGSize(width: w, height: h))
        texture.usesMipmaps = true
        texture.filteringMode = .linear
        return texture
    }

    /// One blade, from its base along `angle`, in pixels at `ppm` a metre.
    private static func blade(_ ctx: CGContext, base: CGPoint, angle: CGFloat, length: Double, curl: CGFloat, halfWidth: CGFloat,
                              ppm: CGFloat, shade: CGFloat, seed: Double) {
        let L = CGFloat(length) * ppm, dir = CGPoint(x: cos(angle), y: sin(angle)), nrm = CGPoint(x: -dir.y, y: dir.x)
        func point(_ a: CGFloat, _ off: CGFloat) -> CGPoint {
            let c = curl * a * a * L
            return CGPoint(x: base.x + dir.x * a * L + nrm.x * (c + off), y: base.y + dir.y * a * L + nrm.y * (c + off))
        }
        func profile(_ a: CGFloat, _ side: CGFloat) -> CGFloat {
            let m = Double(a) * length
            if a < 0.05 { return 0.004 * ppm }
            let ab = (a - 0.05) / 0.95
            var p = simd_smoothstep(0, 0.25, ab) * (1 - simd_smoothstep(0.55, 1, ab) * 0.92)
            p *= 1 + 0.07 * CGFloat(sin(m * 55 + seed)) + 0.05 * CGFloat(sin(m * 23 + seed * 0.3 + Double(side)))
            p *= 1 - 0.07 * CGFloat((m / 0.022 + (side > 0 ? 0 : 0.5)).truncatingRemainder(dividingBy: 1))
            return max(p * halfWidth * ppm, 0.004 * ppm)
        }
        let n = 80
        let path = CGMutablePath()
        path.move(to: point(0, 0))
        for i in 0...n { let a = CGFloat(i) / CGFloat(n); path.addLine(to: point(a, profile(a, 1))) }
        for i in stride(from: n, through: 0, by: -1) { let a = CGFloat(i) / CGFloat(n); path.addLine(to: point(a, -profile(a, -1))) }
        path.closeSubpath()
        ctx.addPath(path)
        ctx.setFillColor(CGColor(red: shade, green: 0.25, blue: 0, alpha: 1))
        ctx.fillPath()
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        // Its thin margins let the most light through.
        ctx.addPath(path)
        ctx.setLineWidth(halfWidth * ppm * 0.5)
        ctx.setStrokeColor(CGColor(red: shade, green: 0.95, blue: 0, alpha: 0.6))
        ctx.strokePath()
        // Ridges across it about 3 cm apart, wandering.
        ctx.setLineWidth(max(1, 0.006 * ppm))
        ctx.setStrokeColor(CGColor(red: shade * 0.55, green: 0.15, blue: 0, alpha: 0.45))
        var m = 0.06
        while m < length {
            let a = CGFloat(m / length), wob = CGFloat(sin(m * 40 + seed)) * 0.01 * ppm
            ctx.move(to: point(a, -halfWidth * ppm * 1.2))
            ctx.addLine(to: point(a + wob / L, halfWidth * ppm * 1.2))
            m += 0.03 * Double.random(in: 0.8...1.2, using: &ridges)
        }
        ctx.strokePath()
        ctx.restoreGState()
        // The float at its foot.
        let f = point(0.035 / CGFloat(length), 0)
        ctx.setFillColor(CGColor(red: 0.85, green: 0.3, blue: 1, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: f.x - 0.02 * ppm, y: f.y - 0.011 * ppm, width: 0.04 * ppm, height: 0.022 * ppm))
    }

    nonisolated(unsafe) private static var ridges = SplitMix(state: 7)
}
