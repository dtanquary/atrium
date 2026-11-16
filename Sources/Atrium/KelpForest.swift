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
final class KelpForest: SKScene, Trimmable {
    nonisolated static let looks = [
        "Teal in Light Mode, dusk in Dark Mode", "Teal by day, dusk at night",
        "Golden in Light Mode, dusk in Dark Mode", "Golden by day, dusk at night",
        "Teal", "Golden", "Dusk",
    ]
    nonisolated static let views = ["Level through the forest", "Looking up into the canopy", "Moving between the two"]
    nonisolated static let knobs = [
        Knob(key: "kelp.look", label: "Look", range: 0...Double(looks.count - 1), standard: 0, section: "Look",
             format: .choice(looks)),
        Knob(key: "kelp.view", label: "View", range: 0...Double(views.count - 1), standard: 0, section: "Look", format: .choice(views)),
        Knob(key: "kelp.swell", label: "Swell", range: 0.25...2, standard: 1, section: "Sea", format: .times),
        Knob(key: "kelp.speed", label: "Speed", range: 0.5...2, standard: 1, section: "Sea", format: .times),
        Knob(key: "kelp.fish", label: "Fish", range: 0...1, standard: 1, section: "Sea", format: .toggle),
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
                           kelp: lin(0x050A12), glow: lin(0x0C2034), sand: lin(0x0A1A2A), rays: 0.5, snow: 0, caustics: 0,
                           expo: [0.2, 0.12], sunElevation: 4)

    // MARK: - Views

    /// Where the camera stands: metres above the floor, the water's depth, how far it's tipped up, and where the plants
    /// stand. The first two as the mock-ups Dave chose (round 2's A and D). The third moves between them, as a diver
    /// looks up and back: it holds level for four minutes, tips up over 40 s, holds, and tips back, over one forest
    /// with plants both near (for looking up) and far (for looking level).
    struct View { var camY: Double, depth: Double, pitch: Double, near: Double, far: Double, plants: Int, up: Double? = nil }
    static let viewsAt = [View(camY: 2.5, depth: 12, pitch: 20, near: 6, far: 30, plants: 10),
                          View(camY: 2, depth: 10, pitch: 58, near: 3.5, far: 14, plants: 11),
                          View(camY: 2.5, depth: 12, pitch: 20, near: 4, far: 30, plants: 12, up: 58)]
    static let hold = 240.0, tilt = 40.0

    // MARK: - State

    private var viewIndex: Int
    private var spot: View { Self.viewsAt[viewIndex] }
    /// How far the camera is tipped up now, in degrees, and seconds of the cycle between level and looking up.
    private var pitch = 20.0, cycle = 0.0
    private var holdfasts: [(node: SKSpriteNode, at: SIMD3<Double>)] = []
    private var shownLook = KelpForest.teal
    private let fovTan = tan(32 * Double.pi / 180) // half the view's width, as a slope: 64° across
    private var cam: SIMD3<Double>
    private var sea: Sea
    private var fronds: [Frond] = []
    /// A fish of the school: its length, and how strong the slow water from behind must be before it turns round; where
    /// it is and where in the school it keeps to (metres); its heading (radians about the vertical, 0 along x), the way
    /// it faces into the slow water (0 or π) and its own veer from that; what's left of a dart; its tail's beats and
    /// bend (-1 to 1); the last step's place, heading and bend, which it is drawn between; and the fog its colour was
    /// last set for.
    private struct Fish {
        let node: SKSpriteNode, length: Double, turns: Double
        var p: SIMD3<Double>, spot: SIMD3<Double>, yaw: Double, into: Double, veer = 0.0, dart = 0.0, beat: Double, bend = 0.0
        var was: (p: SIMD3<Double>, yaw: Double, bend: Double), fogged = -1
    }
    private var fish: [Fish] = [], home = SIMD3<Double>.zero, fishOn = true, swamAt = 0.0
    private var simTime = 0.0, lastTime: TimeInterval?, lastCycle: TimeInterval?
    private var rng: SplitMix
    private var atlas: Atlas!
    private let water = SKSpriteNode(color: .black, size: .zero)
    /// Holds the water, the softest part, which draws at half the screen's resolution on battery (`Trimmable`), and
    /// the marine snow for then: specks a pixel or two across, which stay at the screen's own resolution over it.
    let trim = TrimNode()
    private let snow = SKSpriteNode(color: .black, size: .zero), uSpeck = SKUniform(name: "u_speck", vectorFloat3: .zero)
    private var appearance: NSKeyValueObservation?, trimmed: NSKeyValueObservation?
    private var sunLit = 1.0, lastSun = -100.0, shownLit: Float = -1
    /// Whether the far fronds' chains have stepped since their cards were posed, and the tilt everything was last
    /// posed at: far cards and holdfasts are left alone on a frame when neither has changed.
    private var farMoved = true, posedPitch = -1.0
    /// Leaves alone what can't be seen to change: blades off the screen, far cards whose chain hasn't stepped. Off
    /// only for the test that the picture is the same without it.
    var skipsUnseen = true

    // The look's uniforms, shared by the water and the kelp; set from the Look menu, eased as it changes.
    private let uExt = SKUniform(name: "u_ext", vectorFloat3: .zero), uDeep = SKUniform(name: "u_deep", vectorFloat3: .zero)
    private let uUp = SKUniform(name: "u_up", vectorFloat3: .zero), uSky = SKUniform(name: "u_sky", vectorFloat3: .zero)
    private let uSun = SKUniform(name: "u_sun", vectorFloat3: .zero), uKelp = SKUniform(name: "u_kelp", vectorFloat3: .zero)
    private let uGlow = SKUniform(name: "u_glow", vectorFloat3: .zero), uSand = SKUniform(name: "u_sand", vectorFloat3: .zero)
    private let uSunDir = SKUniform(name: "u_sundir", vectorFloat3: .zero)
    private let uLook = SKUniform(name: "u_look", vectorFloat4: .zero) // rays, snow, caustics, exposure
    /// The tilt (radians), the exposure, and the tilt's cosine and sine, which every pixel of both shaders would
    /// otherwise work out for itself: in one uniform, so a tilting frame marks the kelp's sprites once.
    private let uView = SKUniform(name: "u_view", vectorFloat4: .zero)
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
        // The snow changes hands as the trim comes on or goes off.
        trimmed = trim.observe(\.shouldEnableEffects) { [weak self] _, _ in
            MainActor.assumeIsolated { if let self { self.apply(self.shownLook) } }
        }
    }

    /// Builds the water and a new forest for the view picked.
    private func setUp() {
        atlas = Atlas.shared()
        cam = SIMD3(0, spot.camY, 0)
        pitch = spot.pitch
        cycle = UserDefaults.standard.double(forKey: "kelp.cycleAt") // for pictures: seconds into the cycle
        sea = Sea(height: Self.knobs[2].value, depth: spot.depth, rng: &rng)
        water.size = size
        water.anchorPoint = .zero
        water.shader = SKShader(source: defines + Self.common + Self.waterSource, uniforms: [
            uExt, uDeep, uUp, uSky, uSun, uKelp, uGlow, uSand, uSunDir, uLook, uView, uTime, uSurge, uPx,
            SKUniform(name: "u_canopy", texture: sharedTexture("kelp-canopy") { Self.canopy() }),
        ])
        if water.parent == nil { trim.content.addChild(water) }
        trim.zPosition = -1000
        addChild(trim)
        snow.size = size
        snow.anchorPoint = .zero
        snow.zPosition = -999
        snow.shader = SKShader(source: defines + Self.common + Self.snowSource, uniforms: [uSpeck, uTime, uSurge, uPx, uView, uDeep, uUp, uExt, uSunDir])
        addChild(snow)
        let kelp = SKShader(source: defines + Self.common + Self.kelpSource, uniforms: [
            uExt, uDeep, uUp, uSun, uKelp, uGlow, uSunDir, uView, uPx,
        ])
        plant(with: kelp)
        school(with: kelp)
        settleLook(at: true)
        // Run the sea a while first, so the forest has settled into it and the fish have schooled: 30 s in steps of 1/30 s.
        for k in 0..<900 {
            step(at: simTime + Double(k - 900) / 30, dt: 1.0 / 30, farDt: 1.0 / 30)
            swim(at: simTime + Double(k - 900) / 30, dt: 1.0 / 30)
        }
        (farMoved, posedPitch) = (true, -1)
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
            holdfasts = []
            fish = []
            setUp()
            return
        }
        sea.height = Self.knobs[2].value
        if fishOn != (Self.knobs[4].value > 0.5) { (fishOn, farMoved) = (!fishOn, true) }
        settleLook(at: false)
    }

    /// The view's fixed numbers, written into both shaders.
    private var defines: String {
        let d: [String: String] = [
            "TANH": "\(fovTan)", "ASPECT": "\(Double(size.height / size.width))",
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

    /// Sets the look's uniforms, only those that changed: each change marks every sprite using the shader, and the
    /// kelp's are thousands (sending them all every frame cost about 0.7 ms each, sampled live).
    private func apply(_ l: Look) {
        func set(_ u: SKUniform, _ v: SIMD3<Float>) { if u.vectorFloat3Value != v { u.vectorFloat3Value = v } }
        func set4(_ u: SKUniform, _ v: SIMD4<Float>) { if u.vectorFloat4Value != v { u.vectorFloat4Value = v } }
        set(uExt, l.ext); set(uDeep, l.deep); set(uUp, l.up); set(uSky, l.sky); set(uSun, l.sun)
        set(uKelp, l.kelp); set(uGlow, l.glow); set(uSand, l.sand)
        // The exposure goes with how far the camera is tipped up: looking up into the light needs less.
        let up = Float(simd_clamp((pitch - 20) / (58 - 20), 0, 1)), expo = l.expo[0] + (l.expo[1] - l.expo[0]) * up
        set4(uView, [Float(pitch * .pi / 180), expo, Float(cos(pitch * .pi / 180)), Float(sin(pitch * .pi / 180))])
        shownLook = l
        // The Sun under water, bent toward the vertical by refraction, a little to one side of where we look.
        let zen = Double(90 - l.sunElevation) * .pi / 180, inWater = asin(sin(zen) / 1.333), az = 10 * Double.pi / 180
        set(uSunDir, SIMD3(Float(sin(inWater) * sin(az)), Float(cos(inWater)), Float(sin(inWater) * cos(az))))
        // The water draws its own snow, but for when it's drawn at a lower resolution than the screen's (on battery):
        // then a sprite over it does, given the light a speck adds (the shader's `waterCol` looking straight up).
        let coarse = trim.shouldEnableEffects
        set4(uLook, [l.rays, coarse ? 0 : l.snow, l.caustics, expo])
        show(snow, coarse && l.snow > 0)
        if !snow.isHidden {
            let lift = min(exp(0.25 * (l.ext.sum() / 3) * Float(min(5, spot.depth - spot.camY))), 1.35) * (1 + 0.6 * Float(pow(cos(inWater), 5)))
            set(uSpeck, l.snow * 0.6 * expo * lift * l.up)
        }
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
        // Each sprite's light, fixed at load: the canopy's shade along the line to the Sun above it (the day looks'
        // Sun, bent as `apply` bends it), times a spread of its own, so the kelp sits darker than its water with
        // sunlit plants among shaded ones, as the mock-ups Dave chose had it (mock.swift's frond shader).
        let zen = Double(90 - Self.teal.sunElevation) * .pi / 180, az = 10 * Double.pi / 180
        let toSun = SIMD2(sin(az), cos(az)) * tan(asin(sin(zen) / 1.333))
        func shade(_ p: [SIMD3<Double>], _ f: Double) -> Double {
            let x = f * Double(Self.links), k = min(Int(x), Self.links - 1), q = p[k] + (p[k + 1] - p[k]) * (x - Double(k))
            let at = SIMD2(q.x, q.z) + toSun * (spot.depth - q.y)
            return 0.3 + 0.7 * (1 - Double(Self.canopy(Float(at.x), Float(at.y))))
        }
        func spread(_ seed: Double) -> Double { 0.45 + 0.65 * (seed * 61.3).truncatingRemainder(dividingBy: 1) }
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
                    for _ in 0..<Self.links / 2 {
                        let s = SKSpriteNode(texture: atlas.stipe)
                        s.anchorPoint = CGPoint(x: 0.5, y: 0)
                        s.zPosition = depthZ
                        info(s, dist: mid.dist, height: len / 2, seed: 0, light: 0.7 * shade(frond.p, 0.5))
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
                            node.anchorPoint = Atlas.bladeFoot(card)
                            let w = length / Atlas.bladeLength
                            node.size = CGSize(width: Atlas.bladeCard.width * w * mid.ppm / 2, height: Atlas.bladeCard.height * w * mid.ppm / 2)
                            node.zPosition = depthZ
                            let seed = Double.random(in: 0...1, using: &rng), az = Double.random(in: 0...(2 * .pi), using: &rng)
                            let el = 0.3 + pow(Double.random(in: 0...1, using: &rng), 2), own = Double.random(in: 0...100, using: &rng)
                            // One on our side of its stipe is in the stipe's shadow when we look toward the light.
                            let behind = 0.35 + 0.65 * simd_smoothstep(-0.7, 0.5, -sin(az))
                            info(node, dist: mid.dist, height: u, seed: seed, light: spread(seed) * shade(frond.p, u / len) * behind)
                            node.shader = shader
                            addChild(node)
                            frond.blades.append(Blade(node: node, at: u, az: az, el: el, length: length, seed: own))
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
                        let seed = Double.random(in: 0...1, using: &rng)
                        info(node, dist: mid.dist, height: (f + 1 / Double(Self.links)) * len, seed: seed,
                             light: spread(seed) * shade(frond.p, f + 1 / Double(Self.links)))
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
            info(holdfast, dist: at.dist, height: 0.2, seed: 0.5, light: 0.8 * shade([SIMD3(x, 0, z), SIMD3(x, 1, z)], 0))
            holdfasts.append((holdfast, SIMD3(x, 0, z)))
        }
    }

    /// A loose school of three dozen blacksmith (*Chromis punctipinnis*), 18 to 25 cm long, about 11 m off along the
    /// view: the fish whose colour sits inside the water's (research-method.md §3, research-look.md item 7), so fogged
    /// they are dark blue-grey slivers. Cards from the atlas in the kelp's one batch, under its shader.
    private func school(with shader: SKShader) {
        let tip = spot.pitch * .pi / 180
        home = cam + SIMD3(0, sin(tip), cos(tip)) * 11
        home.y = min(max(home.y, 2), spot.depth - 1.5)
        fishOn = Self.knobs[4].value > 0.5
        let into = sea.drift(y: home.y, simTime - 30).x > 0 ? Double.pi : 0
        for _ in 0..<36 {
            let node = SKSpriteNode(texture: atlas.fish[0])
            node.shader = shader
            addChild(node)
            let at = home + SIMD3(Double.random(in: -1...1, using: &rng), .random(in: -0.35...0.35, using: &rng), .random(in: -1...1, using: &rng))
            fish.append(Fish(node: node, length: Atlas.fishLength * .random(in: 0.72...1, using: &rng), turns: .random(in: 0.003...0.025, using: &rng),
                             p: at, spot: at, yaw: into, into: into, beat: .random(in: 0...1, using: &rng), was: (at, into, 0)))
        }
    }

    /// Blacksmith hang in the water column picking plankton, facing into the current, rather than cruising. Each faces
    /// into the slow water (the slow surge and the current, not each swell) along the surge, across the view, and turns
    /// round only once that plainly comes from behind, each at its own moment, so a turn ripples through the school;
    /// holds its place in the school against the slow water and three fifths of the swell, ahead with its tail and a
    /// little back or aside with its fins, so the school sways with the surge less than the kelp, each fish along its
    /// own length; veers a little on its own; and every few seconds darts ahead at a plankter and coasts. Its tail beats
    /// as fast as it swims ahead through the water, wider the harder. Speeds in m/s; stepped every 1/30 s at fixed
    /// times and drawn between the last two steps (`was`), so it swims the same at any frame rate.
    private func swim(at t: Double, dt: Double) {
        let u = sea.flow(sea.phases(at: home, t), y: home.y, t), slow = sea.drift(y: home.y, t).x
        let gap = 0.35, root = dt.squareRoot()
        swamAt = t
        for i in fish.indices {
            var f = fish[i]
            f.was = (f.p, f.yaw, f.bend)
            // ponytail: the school faces along x only, into the slow water's share along it; the current's own bearing
            // (up to 34° off x) is left out so the fish stay side on. Face its bearing if a view ever looks along it.
            if slow * cos(f.into) > f.turns { f.into = slow > 0 ? .pi : 0 }
            f.veer += -f.veer * dt / 5 + Double.random(in: -1...1, using: &rng) * 0.33 * root // about ±0.3, over seconds
            if Double.random(in: 0...1, using: &rng) < dt / 6 {
                f.dart = .random(in: 0.25...0.45, using: &rng)
                f.veer += .random(in: -0.4...0.4, using: &rng)
            }
            f.dart *= exp(-dt / 0.35)
            // A fish yaws round, at up to 3 radians a second; it never rolls or tips over.
            f.yaw += min(max(remainder(f.into + f.veer - f.yaw, 2 * .pi) * 4 * dt, -3 * dt), 3 * dt)
            // Its place in the school wanders over a minute or so, and it keeps clear of its neighbours.
            let spread = SIMD3(0.58, 0.2, 0.58) * 0.32 * root
            f.spot += (home - f.spot) * dt / 60 + SIMD3(Double.random(in: -1...1, using: &rng), .random(in: -1...1, using: &rng),
                                                        .random(in: -1...1, using: &rng)) * spread
            var want = (f.spot - f.p) * 0.3 - u * 0.6
            // ponytail: O(n²), fine for a few dozen fish
            for j in fish.indices where j != i {
                let d = fish[j].p - f.p, r = max(simd_length(d), 0.001)
                if r < gap { want -= d / r * (gap - r) * 2 }
            }
            let h = SIMD3(cos(f.yaw), 0, sin(f.yaw)), ahead = min(max(simd_dot(want, h), -0.1), 0.35) + f.dart
            var aside = want - h * simd_dot(want, h)
            aside *= min(1, 0.06 / max(simd_length(SIMD2(aside.x, aside.z)), 1e-6))
            aside.y = min(max(want.y, -0.04), 0.04)
            f.p += (h * ahead + aside + u) * dt
            f.p.y = min(max(f.p.y, 0.5), spot.depth - 0.5)
            let thrust = max(ahead, 0) // backing is the fins' work
            f.beat += dt * min(max(thrust / (0.6 * f.length), 0.8), 5)
            f.bend = min(0.25 + thrust / 0.3, 1) * sin(2 * .pi * f.beat)
            fish[i] = f
        }
    }

    /// Sets a sprite's fixed numbers for the kelp shader, carried in its colour (the shader's `v_color_mix`): how far
    /// off it is (to 64 m), how high (to 16 m), and in blue its light (to 1.2, in 16 steps) with a number of its own
    /// (0 to 1) in the middle of each step, clear of its edges however the channel rounds. Not as attributes: SpriteKit
    /// crashed copying thousands of sprites' attribute values while taking the lock screen's still (docs/kelp-forest.md,
    /// Dave's feedback).
    // ponytail: fog and light are fixed at each sprite's place at rest; a near frond swaying ±1 m at 6 m changes its fog
    // by a few percent, and its canopy's shade with it. Set them each frame (its colour) if a near one is seen to glow or
    // darken wrongly.
    private func info(_ node: SKSpriteNode, dist: Double, height: Double, seed: Double, light: Double) {
        node.color = NSColor(red: min(dist / 64, 1), green: min(max(height, 0) / 16, 1), blue: Self.blue(light: light, seed: seed), alpha: 1)
        node.colorBlendFactor = 1
    }

    /// The blue of a sprite's colour: its light in steps of 0.08 to 1.2, read back by the shader's `floor(info.z)`, and
    /// its own number between 0.2 and 0.8 of a step, by `fract(info.z)`.
    nonisolated static func blue(light: Double, seed: Double) -> Double {
        ((min(max(light, 0), 1.2) * 12.5).rounded() + 0.2 + 0.6 * seed) / 16
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
        // Far fronds every other step, as steps of 1/30 s: far off, a 30th of a second's sway is under a pixel or two.
        for k in stride(from: first, through: (simTime / step).rounded(.down), by: 1).prefix(12) {
            let far = Int(k) % 2 == 0
            self.step(at: k * step, dt: step, farDt: far ? 2 * step : nil)
            if far { swim(at: k * step, dt: 2 * step) }
            farMoved = farMoved || far
        }
        // A change of look eases over a few seconds.
        let target = Float(wanted.dusk)
        if abs(target - duskShown) > 0.001 || shownLit < 0 {
            duskShown += (target - duskShown) * Float(min(1, dt / 1.5))
            lightLook = wanted.light
            apply(lightLook.mixed(Self.dusk, duskShown))
            shownLit = 1
        }
        if simTime - lastSun > 60 { settleLook(at: false) }
        if let up = spot.up {
            // Level, then tipping up, looking up, then tipping back, in real seconds whatever the Speed.
            cycle = (cycle + frameTime(currentTime, &lastCycle)).truncatingRemainder(dividingBy: 2 * (Self.hold + Self.tilt))
            let into = cycle - Self.hold, back = cycle - 2 * Self.hold - Self.tilt
            let f = into < 0 ? 0 : back < 0 ? simd_smoothstep(0, Self.tilt, into) : 1 - simd_smoothstep(0, Self.tilt, back)
            pitch = spot.pitch + (up - spot.pitch) * f
            apply(shownLook)
        }
        pose(at: simTime)
    }

    /// Steps every frond: buoyancy, more high up where the floats are, and each frond's own slight lean away from the
    /// others in its plant; drag toward the water's velocity as |u − v|^0.6 (u − v); links that don't stretch; a little
    /// stiffness, so a slack frond curves rather than zigzags; and the surface, which it floats along.
    private func step(at t: Double, dt near: Double, farDt: Double?) {
        let n = Self.links, top = spot.depth - 0.03
        for f in fronds.indices {
            guard let dt = fronds[f].near ? near : farDt else { continue }
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
    private func project(_ p: SIMD3<Double>) -> (px: SIMD2<Double>, ppm: Double, dist: Double, ahead: Double) {
        let rel = p - cam, pitch = self.pitch * .pi / 180
        let ahead = rel.y * sin(pitch) + rel.z * cos(pitch), zc = max(ahead, 0.05), yc = rel.y * cos(pitch) - rel.z * sin(pitch)
        let w = Double(size.width) * 2, h = Double(size.height) * 2, aspect = h / w
        return (SIMD2(w / 2 + rel.x / zc / fovTan * w / 2, h / 2 + yc / zc / (fovTan * aspect) * h / 2), w / 2 / (fovTan * zc), simd_length(rel), ahead)
    }

    /// Hides or shows a sprite, touching it only if that changes: every set tells SpriteKit's observers.
    private func show(_ node: SKNode, _ on: Bool) { if node.isHidden == on { node.isHidden = !on } }

    /// Poses every frond's sprites from its chain: stipes from node to node; each blade at its place, at its bearing
    /// and lift, streamed by the water's flow past it and fluttering by a few degrees, foreshortened where it points
    /// toward or away from us; far cards from node to node.
    private func pose(at t: Double) {
        let sh = sea.surfaceShift(t)
        uSurge.vectorFloat2Value = [Float(sh.x), Float(sh.y)]
        // ponytail: the snow, caustics and ripples jump once an hour where this wraps; carry their phase on the CPU if a jump shows
        uTime.floatValue = Float(t.truncatingRemainder(dividingBy: 3600))
        // A holdfast moves on the screen only as the camera tips, and a far frond's cards only then or when its chain
        // has stepped, which at 60 fps is every other frame and at 120 one in four.
        let tipped = pitch != posedPitch || !skipsUnseen, farStill = !tipped && !farMoved
        (posedPitch, farMoved) = (pitch, false)
        if tipped {
            for (node, at) in holdfasts {
                let p = project(at)
                show(node, p.ahead > 0.3)
                node.position = CGPoint(x: p.px.x / 2, y: p.px.y / 2)
                node.size = CGSize(width: Atlas.holdfastSize.width * p.ppm / 2, height: Atlas.holdfastSize.height * p.ppm / 2)
            }
        }
        let w = Double(size.width) * 2, h = Double(size.height) * 2, nearest = 0.3
        var pts = [(px: SIMD2<Double>, ppm: Double, dist: Double, ahead: Double)](repeating: (.zero, 0, 0, 0), count: Self.links + 1)
        for f in fronds.indices {
            let fr = fronds[f]
            if farStill && !fr.near { continue }
            var lo = SIMD2(Double.infinity, .infinity), hi = -lo, reach = 0.0
            for k in 0...Self.links {
                pts[k] = project(fr.p[k])
                lo = simd_min(lo, pts[k].px); hi = simd_max(hi, pts[k].px); reach = max(reach, 1.2 * pts[k].ppm)
            }
            let shown = hi.x > -reach && lo.x < w + reach && hi.y > -reach && lo.y < h + reach
            // A link passing near or behind the camera (looking up, the near fronds' lower parts) projects nowhere
            // sensible: it and its blades are hidden rather than flung across the screen.
            func clear(_ k: Int) -> Bool { shown && pts[k].ahead > nearest && pts[min(k + 1, Self.links)].ahead > nearest }
            if fr.near {
                // A stipe sprite for every two links, and the blades placed along the same straight runs.
                for (j, s) in fr.stipe.enumerated() {
                    let k = j * 2, a = pts[k].px, b = pts[k + 2].px, d = b - a
                    let lo = simd_min(a, b), hi = simd_max(a, b), span = skipsUnseen ? 0.012 * max(pts[k].ppm, pts[k + 2].ppm) + 4 : .infinity
                    let on = clear(k) && pts[k + 2].ahead > nearest && hi.x > -span && lo.x < w + span && hi.y > -span && lo.y < h + span
                    show(s, on)
                    guard on else { continue }
                    s.position = CGPoint(x: a.x / 2, y: a.y / 2)
                    s.zRotation = atan2(-d.x, d.y)
                    s.size = CGSize(width: max(0.012 * pts[k].ppm, 1.2) / 2, height: simd_length(d) / 2 + 0.5)
                }
                guard shown else { for b in fr.blades { show(b.node, false) }; continue }
                // The water's flow past the frond on the screen, at a few places up it: 1 is about 15 cm/s.
                let phases = sea.phases(at: fr.base, t)
                var flows = [SIMD2<Double>](repeating: .zero, count: Self.links / 2 + 1)
                for j in flows.indices {
                    let k = j * 2, rel = (sea.flow(phases, y: fr.p[k].y, t) - fr.v[k]) / 0.15
                    flows[j] = (project(fr.p[k] + rel * 0.2).px - pts[k].px) / (0.2 * pts[k].ppm)
                }
                for b in fr.blades {
                    let x = b.at / fr.len * Double(Self.links), k = min(Int(x / 2) * 2, Self.links - 2), frac = (x - Double(k)) / 2
                    let at = pts[k].px + (pts[k + 2].px - pts[k].px) * frac
                    let ppm = pts[k].ppm + (pts[k + 2].ppm - pts[k].ppm) * frac
                    // Most of a near frond is above or beside the screen (its ruff most of all): a blade whose foot is
                    // farther off the screen than its card can reach isn't worth posing.
                    let span = skipsUnseen ? b.length * ppm * Atlas.bladeReach + 2 : .infinity
                    let on = clear(k) && pts[k + 2].ahead > nearest && at.x > -span && at.x < w + span && at.y > -span && at.y < h + span
                    show(b.node, on)
                    guard on else { continue }
                    let tangent = simd_normalize(pts[k + 2].px - pts[k].px + SIMD2(0, 1e-6))
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
                    // Its width follows only its distance, which changes slowly: set when it has moved a percent.
                    let ys = ppm / fr.restPpm
                    if abs(b.node.yScale - ys) > 0.01 * ys { b.node.yScale = ys }
                }
            } else {
                for (c, node) in fr.cards.enumerated() {
                    let k = c * 2, on = clear(k) && pts[min(k + 2, Self.links)].ahead > nearest
                    show(node, on)
                    guard on else { continue }
                    let a = pts[k].px, b = pts[min(k + 2, Self.links)].px, d = b - a
                    let ppm = pts[k + 1].ppm
                    node.position = CGPoint(x: a.x / 2, y: a.y / 2)
                    node.zRotation = atan2(-d.x, d.y)
                    node.size = CGSize(width: Atlas.cardSize.width * ppm / 2, height: Atlas.cardSize.height * simd_length(d) / Atlas.cardStipe / 2)
                }
            }
        }
        // The fish every frame, between their last two steps: each shows its side, mirrored as it faces left, as long
        // as its heading is across the view and down to a fifth of that end on (its narrow front); belly down, tipped
        // by its heading's slope on the screen up to 20° side on and not at all end on, so a turn is a yaw and never a
        // fish standing on its nose; its tail bent as it beats; and fogged by how far off it is now.
        let a = min(max((t - swamAt) * 30, 0), 1)
        for i in fish.indices {
            let f = fish[i], p = f.was.p + (f.p - f.was.p) * a, yaw = f.was.yaw + remainder(f.yaw - f.was.yaw, 2 * .pi) * a
            let at = project(p), nose = project(p + SIMD3(cos(yaw), 0, sin(yaw)) * f.length)
            let on = fishOn && at.ahead > 0.5 && nose.ahead > 0.5
            show(f.node, on)
            guard on else { continue }
            let d = nose.px - at.px, full = f.length * at.ppm, scale = f.length / Atlas.fishLength * at.ppm / 2, side = d.x < 0 ? -1.0 : 1.0
            f.node.position = CGPoint(x: at.px.x / 2, y: at.px.y / 2)
            f.node.zRotation = side * min(max(atan2(d.y, abs(d.x)), -0.35), 0.35) * min(abs(d.x) / full, 1)
            f.node.zPosition = CGFloat(-at.dist)
            f.node.size = CGSize(width: Atlas.fishCard.width * scale * min(max(abs(d.x) / full, 0.2), 1), height: Atlas.fishCard.height * scale)
            if (f.node.xScale < 0) != (side < 0) { f.node.xScale = -f.node.xScale }
            let bend = f.was.bend + (f.bend - f.was.bend) * a
            let pose = atlas.fish[Int(((bend + 1) / 2 * Double(atlas.fish.count - 1)).rounded())]
            if f.node.texture !== pose { f.node.texture = pose }
            let fog = Int(at.dist * 4) * 1000 + Int(p.y * 16)
            if fog != f.fogged { info(f.node, dist: at.dist, height: p.y, seed: 0, light: 0.8); fish[i].fogged = fog }
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
            return u * height + drift(y: y, t)
        }

        /// The water's slow part at height y: the slow surge and the current, without the swell.
        func drift(y: Double, _ t: Double) -> SIMD3<Double> {
            let c = current.speed * (1 + 0.5 * sin(t / 420 + current.phase)), cb = 0.6 * sin(t / 900 + current.phase)
            return SIMD3(height * beat.x * beat.omega * cos(beat.omega * t + beat.phase), 0, 0) + SIMD3(c * cos(cb), 0, c * sin(cb)) * (0.6 + 0.8 * y / depth)
        }

        /// How far the surface water is carried from rest, for the canopy and ripples drawn on it.
        func surfaceShift(_ t: Double) -> SIMD2<Double> {
            var d = SIMD2<Double>.zero
            for s in swells { d -= s.dir * (s.a * cosh(s.k * depth) / s.sinhKH * sin(s.phase - s.omega * t)) }
            return (d + SIMD2(beat.x * sin(beat.omega * t + beat.phase), 0)) * height
        }
    }

    /// How thick the canopy is over a point of the surface (x and z in metres from the camera), 0 open water to 1 thick:
    /// patches drawn out along the swell, as the mock-up worked out per pixel. The same every time, so displays match.
    nonisolated static func canopy(_ x: Float, _ y: Float) -> Float {
        func fbm(_ x: Float, _ y: Float) -> Float {
            var (s, a, px, py): (Float, Float, Float, Float) = (0, 0.5, x, y)
            for _ in 0..<4 { s += a * kelpNoise(px, py); px = px * 2.03 + 17.1; py = py * 2.03 + 9.3; a *= 0.5 }
            return s
        }
        let wx = kelpNoise(x * 0.17, y * 0.17), wy = kelpNoise(x * 0.17 + 5.2, y * 0.17 + 5.2)
        return simd_smoothstep(Float(0.47), 0.65, fbm(x * 0.22 + wx * 2, y * 0.34 + wy * 2))
    }

    /// The canopy over 128 m round the camera at 50 cm a texel, for the shaders.
    static func canopy() -> SKTexture {
        let n = 256
        var bytes = [UInt8](repeating: 255, count: n * n * 4)
        for j in 0..<n {
            for i in 0..<n {
                let x = (Float(i) + 0.5) / Float(n) * 128 - 64, y = (Float(j) + 0.5) / Float(n) * 128 - 64
                let v = canopy(x, y)
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
    // The way the camera looks through a point of the screen (uv 0 to 1, from the bottom left), tipped up by the
    // angle whose cosine and sine are `tip`.
    vec3 rayDir(vec2 uv, vec2 tip) {
        vec3 d = normalize(vec3((uv.x * 2.0 - 1.0) * TANH, (uv.y * 2.0 - 1.0) * TANH * ASPECT, 1.0));
        return vec3(d.x, d.y * tip.x + d.z * tip.y, -d.y * tip.y + d.z * tip.x);
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
    // Marine snow at a pixel: specks a pixel or two across in three layers, drifting up and carried by the surge.
    float snowAt(vec2 px, vec2 sw, float t) {
        float sn = 0.0;
        for (int i = 0; i < 3; i++) {
            float cell = 40.0 + 46.0 * float(i);
            vec2 q = px / cell + vec2(sw.x * (0.6 + 0.5 * float(i)) + 0.05 * sin(t * 0.07 + float(i)), -t * (0.01 + 0.006 * float(i)));
            vec2 id = floor(q) + float(i) * 37.0;
            vec2 f = fract(q) - 0.5 - (vec2(kHash(id + 3.1), kHash(id + 7.7)) - 0.5) * 0.6;
            sn += step(kHash(id), 0.2) * exp(-dot(f, f) * cell * cell / (1.0 + 2.2 * float(i))) * (0.3 + 0.7 * kHash(id + 9.3)) * (0.4 + 0.5 * float(i));
        }
        return sn;
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
        vec3 d = rayDir(uv, u_view.zw);
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
            // Past 60 m the water lets through under half a level of the floor in any look: it is all fog, and not
            // worth its sand and caustics (on a 16:10 screen that is all of the floor the level view shows).
            if (tf < 60.0) {
                vec2 p = vec2(d.x, d.z) * tf;
                float ripple = 0.9 + 0.1 * sin(p.x * 7.0 + 3.0 * kNoise(p * 1.3));
                float rock = smoothstep(0.55, 0.7, kFbm(p * 0.25));
                vec3 alb = mix(u_sand * ripple, u_sand * vec3(0.45, 0.42, 0.36), rock);
                float shade = 1.0 - 0.75 * texture2D(u_canopy, (p + u_sundir.xz / u_sundir.y * DEPTH - sw) / 128.0 + 0.5).r;
                float caus = pow(kNoise(p * 2.2 + vec2(t * 0.25, -t * 0.18)) * kNoise(p * 3.1 - vec2(t * 0.2, t * 0.3)) * 2.2, 2.0);
                col = alb * lightAt(0.0, u_sun, u_ext) * (0.25 + 0.75 * shade) * (0.75 + 0.9 * u_look.z * caus * shade) * (0.4 + 0.6 * u_sundir.y);
            }
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
        // Marine snow, lit by the water around it; none at dusk, where it couldn't be seen.
        vec2 px = uv * u_px;
        if (u_look.y > 0.0) {
            col += u_look.y * snowAt(px, sw, t) * waterCol(vec3(0.0, 1.0, 0.0), CAMY, u_deep, u_up, u_ext, u_sundir) * 0.6;
        }
        col *= u_look.w;
        gl_FragColor = vec4(pow(max(col, vec3(0.0)), vec3(1.0 / 2.2)) + (kHash(px) - 0.5) / 255.0, 1.0);
    }
    """

    /// The marine snow by itself, for when the water is drawn at a lower resolution than the screen's: added to the
    /// picture (its alpha is nothing) as the water would have shown it, adding the speck's light to its own.
    static let snowSource = """
    void main() {
        float sn = snowAt(v_tex_coord * u_px, u_surge, u_t);
        vec3 add = vec3(0.0);
        if (sn > 0.002) {
            vec3 behind = waterCol(rayDir(v_tex_coord, u_view.zw), CAMY, u_deep, u_up, u_ext, u_sundir) * u_view.y;
            add = pow(behind + u_speck * sn, vec3(1.0 / 2.2)) - pow(behind, vec3(1.0 / 2.2));
        }
        gl_FragColor = vec4(add, 0.0);
    }
    """

    /// Every kelp sprite: a card from the texture, whose red is how lit its tissue is from our side, green how much
    /// light comes through it (its thin margins most, as the mock-up's `through`), and blue its floats and stalks; coloured by the look, glowing
    /// gold when we look toward the light, fogged by distance along its own line of sight.
    static let kelpSource = """
    void main() {
        vec4 c = texture2D(u_texture, v_tex_coord);
        vec3 info = v_color_mix.rgb * vec3(64.0, 16.0, 16.0); // how far off, how high; its light and a number of its own
        float own = clamp((fract(info.z) - 0.2) / 0.6, 0.0, 1.0);
        float alpha = c.a;
        vec4 out = vec4(0.0);
        // Most of a card is empty water: only its kelp is worth the light and the fog.
        if (alpha > 0.003) {
        vec3 m = c.rgb / max(alpha, 1e-3);
        vec2 suv = vec2(gl_FragCoord.x / u_px.x, 1.0 - gl_FragCoord.y / u_px.y);
        vec3 d = rayDir(suv, u_view.zw);
        float back = smoothstep(-0.2, 0.9, dot(d, u_sundir));
        vec3 lit = lightAt(info.y, u_sun, u_ext) * floor(info.z) / 12.5;
        vec3 tint = mix(vec3(1.0), vec3(0.9, 1.0, 0.75), fract(own * 7.3) * 0.5);
        vec3 front = u_kelp * tint * lit * m.r;
        vec3 through = u_glow * tint * lit * m.g;
        vec3 col = mix(front, through, back * 0.85 * (1.0 - m.b * 0.5));
        vec3 tr = exp(-u_ext * info.x);
        col = col * tr + waterCol(d, info.y, u_deep, u_up, u_ext, u_sundir) * (1.0 - tr);
        col *= u_view.y;
        out = vec4(pow(max(col, vec3(0.0)), vec3(1.0 / 2.2)) * alpha, alpha);
        }
        gl_FragColor = out;
    }
    """
}

/// The shaders' `kHash` and `kNoise` on the CPU, for the canopy and the blades drawn at load.
private func kelpHash(_ x: Float, _ y: Float) -> Float {
    var p = SIMD2(x, y) * SIMD2(123.34, 456.21)
    p -= p.rounded(.down)
    let d = simd_dot(p, p + 45.32)
    p += d
    let v = p.x * p.y
    return v - v.rounded(.down)
}
private func kelpNoise(_ x: Float, _ y: Float) -> Float {
    let ix = x.rounded(.down), iy = y.rounded(.down), fx = x - ix, fy = y - iy
    let ux = fx * fx * (3 - 2 * fx), uy = fy * fy * (3 - 2 * fy)
    let a = kelpHash(ix, iy) + (kelpHash(ix + 1, iy) - kelpHash(ix, iy)) * ux
    let b = kelpHash(ix, iy + 1) + (kelpHash(ix + 1, iy + 1) - kelpHash(ix, iy + 1)) * ux
    return a + (b - a) * uy
}

// MARK: - The cards

/// One texture of everything the kelp is drawn from, made once and shared (`sharedTexture`): blade cards, far cards
/// of two links of frond with their blades, a stipe and a holdfast. Its red is how lit the tissue is from our side
/// (its blisters, ridges and twist), green how much light comes through it (most at its thin margins), blue a float,
/// stalk or stipe, which glow less; the kelp shader colours them by the look. The blades are drawn a pixel at a time
/// as the mock-up's frond shader drew them (`blade`), the stipes and holdfasts in Core Graphics.
@MainActor struct Atlas {
    let texture: SKTexture
    let blades: [SKTexture], sparse: [SKTexture], dense: [SKTexture], stipe: SKTexture, holdfast: SKTexture, fish: [SKTexture]

    /// A blade card is 1 m by 33 cm at 400 px a metre, the blade's base 3 cm in from its end and 44 px in from the side
    /// it bows away from; a blade at full size is 92 cm long with its stalk and float, bowed by up to an eighth of its
    /// length at its middle, half the cards one way and half the other, so its chord lies along the card.
    static let bladeCard = (width: 1.0, height: 0.33), bladeAnchor = 0.03, bladeLength = 0.92
    static let bladeCards = 24, bladeSide = 44.0 / 132
    /// How far a blade card's farthest corner is from the blade's foot, in blade lengths.
    static let bladeReach = hypot(bladeCard.width * (1 - bladeAnchor), bladeCard.height * (1 - bladeSide)) / bladeLength
    /// A far card is 2 m by 3.2 m, its two links of stipe 2.1 m long from 20 cm up.
    static let cardSize = (width: 2.0, height: 3.2), cardStipe = 2.1, cardAnchor = CGPoint(x: 0.5, y: 0.2 / 3.2)
    static let holdfastSize = (width: 0.8, height: 0.5)
    /// A fish card is 30 by 16 cm, a blacksmith 25 cm long across its middle, facing the way of the card; one for each
    /// of seven bends of its tail, from one side to the other.
    static let fishCard = (width: 0.3, height: 0.16), fishLength = 0.25, fishBends = 7
    private static let (w, h) = (2048, 2048)

    /// Where a blade card's foot is: even cards bow up, odd ones down.
    static func bladeFoot(_ card: Int) -> CGPoint { CGPoint(x: bladeAnchor, y: card % 2 == 0 ? bladeSide : 1 - bladeSide) }

    static func shared() -> Atlas {
        let texture = sharedTexture("kelp-cards") { draw() }
        func sub(_ x: Int, _ y: Int, _ cw: Int, _ ch: Int) -> SKTexture {
            SKTexture(rect: CGRect(x: Double(x) / Double(w), y: Double(y) / Double(h), width: Double(cw) / Double(w), height: Double(ch) / Double(h)), in: texture)
        }
        return Atlas(texture: texture,
                     blades: (0..<bladeCards).map { sub(1240 + $0 / 12 * 404, $0 % 12 * 136, 400, 132) },
                     sparse: (0..<3).map { sub($0 * 410, 720, 400, 640) },
                     dense: (0..<3).map { sub($0 * 410, 1370, 400, 640) },
                     stipe: sub(412, 2, 8, 28), holdfast: sub(430, 0, 240, 150), fish: (0..<fishBends).map { sub(0, $0 * 68, 120, 64) })
    }

    /// Draws the whole texture, the same every time (its own fixed seed), so copies on two displays match.
    private static func draw() -> SKTexture {
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        // Rows from the bottom, as SpriteKit's textures run.
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)
        var rng = SplitMix(state: 0x6B65_6C70)
        let pixels = ctx.data!.assumingMemoryBound(to: UInt8.self)
        // Blade cards, in two columns at the right: each blade's chord along its card from its base 3 cm in, at 400 px a
        // metre, bowed up (even cards) or down. A bowed blade's chord is a little shorter than the blade.
        for i in 0..<bladeCards {
            let curl = Float(i % 2 == 0 ? 1 : -1) * .random(in: 0.12...0.55, using: &rng)
            let foot = bladeFoot(i), x0 = 1240 + i / 12 * 404, y0 = i % 12 * 136
            blade(pixels, base: [Float(x0) + 12, Float(y0) + Float(foot.y) * 132], angle: 0,
                  length: Float(bladeLength) / (1 + curl * curl / 6), curl: curl, width: .random(in: 0.05...0.085, using: &rng),
                  ppm: 400, shade: .random(in: 0.8...1, using: &rng), seed: rng.next())
        }
        // A stipe and a holdfast.
        ctx.setFillColor(CGColor(red: 0.55, green: 0.41, blue: 0.6, alpha: 1))
        ctx.fill(CGRect(x: 413, y: 0, width: 6, height: 32))
        for _ in 0..<40 {
            let r = CGFloat.random(in: 6...22, using: &rng), x = CGFloat.random(in: 470...630, using: &rng)
            let top = 140 - abs(x - 550) * 1.4
            let y = CGFloat.random(in: 4...max(8, top), using: &rng)
            ctx.setFillColor(CGColor(red: .random(in: 0.35...0.6, using: &rng), green: 0.37, blue: 0.5, alpha: 1))
            ctx.fillEllipse(in: CGRect(x: x - r, y: y - r * 0.6, width: 2 * r, height: 1.2 * r))
        }
        // A blacksmith 25 cm long, at 400 px a metre, in seven bends of its tail from one side to the other: deep in the
        // body with a forked tail, dark (red), letting no light through (green) and never glowing (blue). The tail and
        // the narrow of the body before it swing about a point 42% along, so the body bends into the stroke.
        for k in 0..<fishBends {
            let flick = 0.2 * (2 * CGFloat(k) / CGFloat(fishBends - 1) - 1)
            let L: CGFloat = 100, ox: CGFloat = 10, oy = CGFloat(k * 68) + 32, root = CGPoint(x: ox + 0.42 * L, y: oy)
            func tail(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                let dx = ox + x * L - root.x, dy = y * L
                return CGPoint(x: root.x + dx * cos(flick) - dy * sin(flick), y: root.y + dx * sin(flick) + dy * cos(flick))
            }
            let body = CGMutablePath()
            body.move(to: CGPoint(x: ox + L, y: oy + 0.01 * L))
            body.addQuadCurve(to: tail(0.25, 0.055), control: CGPoint(x: ox + 0.58 * L, y: oy + 0.42 * L))
            for (x, y) in [(0.02, 0.2), (0.12, 0.0), (0.02, -0.2), (0.25, -0.055)] as [(CGFloat, CGFloat)] { body.addLine(to: tail(x, y)) }
            body.addQuadCurve(to: CGPoint(x: ox + L, y: oy - 0.01 * L), control: CGPoint(x: ox + 0.55 * L, y: oy - 0.36 * L))
            body.closeSubpath()
            ctx.addPath(body)
            ctx.setFillColor(CGColor(red: 0.15, green: 0.05, blue: 1, alpha: 1))
            ctx.fillPath()
        }
        // Far cards: two links of frond with their blades, sparse (low on a frond) and dense (the ruff), at 200 px a metre.
        for (y0, dense) in [(720, false), (1370, true)] {
            for col in 0..<3 {
                let ox = CGFloat(col * 410), oy = CGFloat(y0), ppm: CGFloat = 200
                let stalkX = ox + 200, from = oy + 0.2 * ppm, to = from + 2.1 * ppm
                var blades: [(at: CGFloat, az: Double, el: Double, len: Double, hw: Double, shade: Double, seed: UInt64)] = []
                var u: CGFloat = 0.05
                while u < 2.1 {
                    if dense || Double.random(in: 0...1, using: &rng) < 0.35 {
                        blades.append((u, .random(in: 0...(2 * .pi), using: &rng), 0.3 + pow(.random(in: 0...1, using: &rng), 2),
                                       (dense ? 0.92 : 0.55) * .random(in: 0.5...1, using: &rng), .random(in: 0.05...0.085, using: &rng),
                                       .random(in: 0.8...1, using: &rng), rng.next()))
                    }
                    u += dense ? .random(in: 0.06...0.14, using: &rng) : .random(in: 0.1...0.2, using: &rng)
                }
                // Those leaning away from us first, in the stipe's shadow; then the stipe; then those toward us.
                func draw(_ b: (at: CGFloat, az: Double, el: Double, len: Double, hw: Double, shade: Double, seed: UInt64), dim: Double) {
                    let dx = sin(b.el) * cos(b.az), dy = cos(b.el), fore = (dx * dx + dy * dy).squareRoot()
                    blade(pixels, base: [Float(stalkX), Float(from + b.at * ppm)], angle: Float(atan2(dy, dx)), length: Float(b.len * fore),
                          curl: Float(sin(b.az * 3) * 0.5), width: Float(b.hw * (0.4 + 0.6 * abs(cos(b.az * 1.7)))),
                          ppm: Float(ppm), shade: Float(b.shade * dim), seed: b.seed)
                }
                for b in blades where sin(b.az) > 0 { draw(b, dim: 0.55) }
                ctx.setFillColor(CGColor(red: 0.5, green: 0.39, blue: 0.6, alpha: 1))
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

    /// One blade laid over the texture's pixels (premultiplied, rows from the bottom), as the mock-up's frond shader drew
    /// one (docs/kelp-forest/mock.swift): from its base along `angle`, its chord `length` metres at `ppm` pixels a metre,
    /// bowed to one side by `curl` of its chord (a quarter of that at its middle), so it is a sickle and not a spear. A
    /// short stalk, a pear-shaped float 7 by 2.5 cm, then the blade, twisting so it narrows to its edge here and there and
    /// shows first one face and then the other; its margin crimped and toothed every 2 cm; its tissue blistered, with
    /// ridges across it about 3 cm apart lit on one side and shaded on the other, and streaks along it; some tips worn
    /// away. Red is how lit it is from our side, green how much light comes through it (most at its thin margins), blue
    /// its float and stalk, which glow less.
    private static func blade(_ pixels: UnsafeMutablePointer<UInt8>, base: SIMD2<Float>, angle: Float, length: Float, curl: Float,
                              width: Float, ppm: Float, shade: Float, seed: UInt64) {
        var rng = SplitMix(state: seed)
        let h3 = Float.random(in: 0...1, using: &rng), h4 = Float.random(in: 0...1, using: &rng), hs = Float.random(in: 0...1, using: &rng)
        let chord = length * ppm, dir = SIMD2(cos(angle), sin(angle)), nrm = SIMD2(-dir.y, dir.x)
        let tip: Float = h3 > 0.6 ? 1 - 0.3 * h4 : 1, foot = min(0.08 / length, 0.3) // the blade proper starts past its float
        let reach = width * 1.25 * ppm + 2, bow = curl * chord / 4
        // Ridges and teeth fade out where they would be under a pixel or two.
        let ridges = simd_clamp(0.03 * ppm / 6 - 0.3, 0, 1), teeth = simd_clamp(0.022 * ppm / 4 - 0.5, 0, 1)
        var lo = SIMD2<Float>(repeating: .infinity), hi = -lo
        for (s, t) in [(Float(0), min(0, bow) - reach), (chord, min(0, bow) - reach), (0, max(0, bow) + reach), (chord, max(0, bow) + reach)] {
            let p = base + dir * s + nrm * t
            lo = simd_min(lo, p); hi = simd_max(hi, p)
        }
        guard hi.x >= 0, hi.y >= 0, lo.x < Float(w), lo.y < Float(h) else { return }
        for y in max(0, Int(lo.y))...min(h - 1, Int(hi.y)) {
            for x in max(0, Int(lo.x))...min(w - 1, Int(hi.x)) {
                let p = SIMD2(Float(x) + 0.5, Float(y) + 0.5) - base
                let a = simd_dot(p, dir) / chord
                guard a > -0.01, a < 1 else { continue }
                let slope = curl * (1 - 2 * a)
                let off = (simd_dot(p, nrm) - curl * chord * a * (1 - a)) / (1 + slope * slope).squareRoot() // pixels across
                guard abs(off) < reach else { continue }
                let m = a * length, side: Float = off > 0 ? 1 : -1
                var c = SIMD3<Float>.zero, alpha: Float = 0
                func over(_ colour: SIMD3<Float>, _ cover: Float) { c = colour * cover + c * (1 - cover); alpha = cover + alpha * (1 - cover) }
                let ab = (a - foot) / (tip - foot)
                if ab > 0 && ab < 1 {
                    let tw = h3 * 6.283 + a * (0.8 + 2.2 * h4), facing = 0.25 + 0.75 * abs(cos(tw)).squareRoot()
                    var prof = simd_smoothstep(0, 0.25, ab) * (1 - simd_smoothstep(0.55, 1, ab) * 0.92) * (1 - simd_smoothstep(0.97, 1, ab))
                    prof *= 1 + 0.07 * sin(m * 55 + hs * 20) + 0.05 * sin(m * 23 + hs * 7) + 0.08 * (kelpNoise(m * 30, hs * 9 + side * 3) - 0.5)
                    let tooth = m / 0.022 + side * 0.5
                    prof *= 1 - 0.07 * (tooth - tooth.rounded(.down)) * teeth
                    let hw = width * facing * prof * ppm
                    let cover = simd_clamp(hw + 0.5 - abs(off), 0, 1) * min(1, hw / 0.8)
                    if cover > 0 {
                        let across = off / max(hw, 1e-3)
                        var rug = kelpNoise(m * 26, across * 3 + hs * 50) * 0.6 + kelpNoise(m * 70, across * 6 + hs * 20) * 0.4
                        rug *= 1 - ridges * 0.28 * (1 - sin((m + 0.012 * sin(across * 2.5 + hs * 9)) * 210 + hs * 30))
                        let streak = 0.85 + 0.15 * kelpNoise(m * 3, across * 9 + hs * 11), thin = max(1 - abs(across), 0)
                        let front: Float = shade * (0.5 + 0.5 * rug) * streak * (0.4 + 0.6 * facing) * (0.9 + 0.1 * sin(tw))
                        let through: Float = (0.55 + 0.45 * (1 - 0.6 * thin)) * (0.6 + 0.4 * rug) * streak * (1 - 0.35 * a) * (0.55 + 0.45 * facing)
                        over(SIMD3(front, through, 0), cover)
                    }
                }
                // Its float, narrow at the stalk and widest toward the blade, a little paler than the blade.
                let u = (m - 0.008) / 0.07
                if u > 0 && u < 1 {
                    let r = 0.0145 * pow(sin(.pi * u), 0.6) * (0.55 + 0.45 * u) * ppm
                    over(SIMD3(min(1, shade * 1.05), 0.55, 1), simd_clamp(r + 0.5 - abs(off), 0, 1))
                }
                if m < 0.012 { over(SIMD3(shade * 0.7, 0.3, 1), simd_clamp(max(0.004 * ppm, 0.6) + 0.5 - abs(off), 0, 1)) }
                guard alpha > 0 else { continue }
                let k = (y * w + x) * 4
                for (i, v) in [c.x, c.y, c.z, 1].enumerated() {
                    pixels[k + i] = UInt8(min(255, (v * (i == 3 ? alpha : 1) * 255 + Float(pixels[k + i]) * (1 - alpha)).rounded()))
                }
            }
        }
    }
}
