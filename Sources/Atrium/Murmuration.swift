import SpriteKit

@MainActor func murmuration(size: CGSize) -> SKScene { Murmuration(size: size) }

/// The moments of a murmuration's evening, as the Sun's height in degrees: displays run from about an hour before
/// sunset, in golden haze, to half an hour after, in blue hour. Each has a white balance, as a photo would: the physical
/// sky, with only three wavelengths, turns violet in deep twilight where photos show blue.
private let evenings: [(name: String, sun: Double, balance: SIMD3<Float>)] = [
    ("Golden hour", 5, [0.9, 1, 1.08]), ("Sunset", 0.5, [0.88, 1, 1.1]), ("Afterglow", -2, [0.85, 1, 1.12]), ("Blue hour", -5, [0.68, 0.96, 1.3]),
]

/// Where the flock is watched from: a sunset photo each, its sky cut away. `horizon` is the rows from the top of the
/// photo down to the horizon (of its height); `sky` is the photo's own sky luminance (linear) just above the horizon,
/// which scales its land to our sky; `rough` is how far above the mirror image the water reflects the sky: a long
/// exposure of a wavy sea averages the sky well above the horizon, where calm water is a mirror. `waves` is how slow
/// ripples move the water: how far they bend its reflection, how fast they drift, and how much they brighten and darken
/// it, which is all the smooth long-exposure sea can show.
/// - Brighton's West Pier: "Tide bears the last glow - Brighton, UK" by sagesolar, CC BY 4.0,
///   https://commons.wikimedia.org/wiki/File:Tide_bears_the_last_glow_-_Brighton,_UK.jpg
/// - A marsh pond: "Sunset over a tundra pond" by USFWS Alaska, public domain,
///   https://commons.wikimedia.org/wiki/File:Sunset_over_a_tundra_pond_(53708107535).jpg
private let grounds: [(name: String, file: String, horizon: Float, sky: Float, rough: Float, waves: SIMD3<Float>)] = [
    ("Brighton West Pier", "murmuration-pier", 780.0 / 1533, 0.1252, 0.12, [0.012, 0.5, 0.12]),
    ("Marsh pond", "murmuration-marsh", 15.0 / 706, 0.2635, 0.005, [0.025, 1, 0.05]),
]

let murmurationKnobs = [
    Knob(key: "murmuration.evening", label: "Light", range: 0...4, standard: 0, section: "Scene",
         format: .choice(["Random"] + evenings.map(\.name))),
    Knob(key: "murmuration.ground", label: "Ground", range: 0...1, standard: 0, section: "Scene", format: .choice(grounds.map(\.name))),
    Knob(key: "murmuration.falcon", label: "Falcon attacks", range: 0...1, standard: 1, section: "Flock", format: .toggle),
    Knob(key: "murmuration.classic", label: "Show the old murmuration", range: 0...1, standard: 0, section: "Compare", format: .toggle),
]

/// A starling murmuration at sunset, seen from the shore: a physical sky, a real photo of Brighton's West Pier or a
/// marsh pond with its water reflecting that sky and the flock, and a flock simulated in metres with banked turns, so
/// it folds into dark bands and opens into pale sheets as it wheels. The Compare switch shows the old flat flock.
final class Murmuration: SKScene {
    private var flock: Flock?
    private var classic: ClassicMurmuration?
    private var lastTime: TimeInterval?
    private var built = (evening: -1.0, ground: -1.0, classic: -1.0)

    override func sceneDidLoad() {
        build()
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged),
                                               name: UserDefaults.didChangeNotification, object: nil)
    }

    /// The light, the ground and the Compare switch rebuild the scene; the falcon switch is read by the flock as it flies.
    @objc private func settingsChanged() {
        if built != (murmurationKnobs[0].value, murmurationKnobs[1].value, murmurationKnobs[3].value) { build() }
    }

    private func build() {
        removeAllChildren()
        flock = nil
        classic = nil
        built = (murmurationKnobs[0].value, murmurationKnobs[1].value, murmurationKnobs[3].value)
        if built.classic > 0.5 {
            let old = ClassicMurmuration(size: size)
            addChild(old)
            classic = old
            return
        }
        let ground = grounds[min(Int(built.ground), grounds.count - 1)]
        let photo = Self.photo(ground.file)
        // The photo spans the screen's width, standing on its bottom edge; its horizon sets the view's.
        let photoSize = photo.texture.size(), height = size.width * photoSize.height / max(photoSize.width, 1)
        let view = GroundView(size: size, horizon: Float(height / size.height) * (1 - ground.horizon))
        let pick = Int(built.evening)
        let evening = pick > 0 ? evenings[pick - 1] : evenings.randomElement()!
        let sky = addSky(view, sun: evening.sun, balance: evening.balance)
        let birds = Flock(view: view, ink: sky.ink)
        addChild(birds)
        flock = birds

        let land = SKSpriteNode(texture: photo.texture, size: CGSize(width: size.width, height: height))
        land.anchorPoint = .zero
        land.zPosition = 3
        land.shader = SKShader(source: shaderCommon + Self.groundShader, uniforms: [
            SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)]),
            SKUniform(name: "u_frame", float: Float(height / size.height)),
            SKUniform(name: "u_aux", texture: photo.aux), SKUniform(name: "u_sky", texture: sky.texture),
            SKUniform(name: "u_cam", vectorFloat4: sky.camera), SKUniform(name: "u_balance", vectorFloat3: evening.balance),
            SKUniform(name: "u_land", vectorFloat3: sky.horizon / ground.sky),
            SKUniform(name: "u_birds", texture: birds.reflection),
            SKUniform(name: "u_rough", float: ground.rough),
            SKUniform(name: "u_noise", texture: CloudNoise.texture), SKUniform(name: "u_waves", vectorFloat3: ground.waves),
        ])
        addChild(land)
    }

    /// The ground photos, decoded once each on first use: the cut-out photo and its aux map (R water, G reflectance ÷ 2).
    private static var photos: [String: (texture: SKTexture, aux: SKTexture)] = [:]
    private static func photo(_ file: String) -> (texture: SKTexture, aux: SKTexture) {
        if let cached = photos[file] { return cached }
        let pair = (SKTexture(image: NSImage(contentsOf: resource(file + ".heic")) ?? NSImage()),
                    SKTexture(image: NSImage(contentsOf: resource(file + "-aux.png")) ?? NSImage()))
        photos[file] = pair
        return pair
    }

    /// The land as photographed, scaled from the photo's sky to ours so it stays a near-black silhouette; the water as
    /// our sky mirrored in it, times the water's reflectance measured in the photo (which keeps its ripples), with the
    /// flock's reflection darkening it, all gently bent by slow ripples. Light is linear until the end, then tone-mapped
    /// like the sky.
    private static let groundShader = """
    vec2 nuv(vec2 p) { return (fract(p) * 256.0 + 0.5) / 257.0; }

    void main() {
        vec2 uv = vec2(v_tex_coord.x, v_tex_coord.y * u_frame);
        // Slow ripples on the water plane (the eye 2 m above it), from two layers of the baked noise drifting different
        // ways. On screen they shrink toward the horizon, and they fade out far away, where they'd only shimmer.
        float dip = max(u_cam.z - uv.y, 0.0) * 2.0 * u_cam.y;
        float dist = 2.0 / max(dip, 0.004);
        vec2 w = vec2((uv.x * 2.0 - 1.0) * u_cam.x * dist, dist);
        float t = u_time * u_waves.y;
        vec4 n1 = texture2D(u_noise, nuv(w * vec2(0.07, 0.11) + vec2(t * 0.004, t * 0.013)));
        vec4 n2 = texture2D(u_noise, nuv(w * vec2(0.13, 0.19) + vec2(-t * 0.009, t * 0.007)));
        vec2 slope = vec2(n1.r - n2.b, n1.b + n2.r - 1.0) * smoothstep(150.0, 40.0, dist);
        vec2 shift = slope * dip * u_waves.x;
        vec4 photo = texture2D(u_texture, v_tex_coord);
        vec3 aux = texture2D(u_aux, v_tex_coord).rgb;
        float ripples = texture2D(u_aux, v_tex_coord + vec2(shift.x, shift.y / u_frame)).g;
        // Land and pier: the photo's shading in our horizon's colour, keeping a little of its own, and darker than the
        // photo's long exposure made it, as a silhouette against a sunset is (under 4% of the sky in photos).
        vec3 shot = pow(photo.rgb / max(photo.a, 0.004), vec3(2.2));
        float lw = dot(u_land, vec3(0.2126, 0.7152, 0.0722));
        vec3 land = mix(dot(shot, vec3(0.2126, 0.7152, 0.0722)) * u_land, shot * lw, 0.3) * 0.35;
        // Waves tilt toward us, so rough water reflects sky higher than the mirror image, and a spread of it.
        float mirror = 2.0 * u_cam.z - uv.y;
        vec3 reflected = vec3(0.0);
        for (int i = 0; i < 3; i++) {
            float v = mirror + shift.y + u_rough * (0.3 + 0.5 * float(i));
            vec3 c4 = texture2D(u_sky, vec2(uv.x + shift.x, clamp((v - u_cam.w) / (1.0 - u_cam.w), 0.0, 1.0))).rgb;
            reflected += c4 * c4 * (4.0 / 3.0);
        }
        vec2 b = vec2(uv.x + shift.x, (uv.y - shift.y) / u_cam.z);
        float s = u_rough * 0.5;
        float birds = 0.4 * texture2D(u_birds, b).r + 0.3 * texture2D(u_birds, b + vec2(0.0, s)).r + 0.3 * texture2D(u_birds, b - vec2(0.0, s)).r;
        vec3 water = reflected * u_balance * ripples * 2.0 * (1.0 - birds * 0.9) * (1.0 + slope.y * u_waves.z);
        vec3 col = sqrt(1.0 - exp(-mix(land, water, aux.r)));
        gl_FragColor = vec4(col + (hash21(v_tex_coord * u_size * 2.0) - 0.5) / 128.0, 1.0) * photo.a;
    }
    """

    override func update(_ currentTime: TimeInterval) {
        let dt = frameTime(currentTime, &lastTime)
        flock?.step(Float(dt))
        classic?.step(dt)
    }

    /// A physical sky (Weather's `Atmosphere`) over the Somerset Levels on a winter evening, facing just left of the Sun.
    /// Returns the colour of the birds against it: the sky where the flock flies, at a tenth of its light, since a
    /// silhouette at a few hundred metres is darkened sky (tinted blue-grey under blue, brown under gold), not black.
    private func addSky(_ view: GroundView, sun elevation: Double, balance: SIMD3<Float>)
        -> (ink: SKColor, texture: SKTexture, camera: SIMD4<Float>, horizon: SIMD3<Float>) {
        let (lat, lon) = (51.16, -2.78)
        var date = Date(timeIntervalSince1970: 1_764_590_400) // 2025-12-01 12:00 UTC
        func sun(_ d: Date) -> Sky.Vector {
            let jd = Sky.julianDate(d)
            return normalize(Sky.horizonMatrix(jd: jd, latitude: lat, longitude: lon) * Sky.sun(jd))
        }
        while asin(sun(date).z) * 180 / .pi > elevation { date += 30 }
        let s = sun(date)
        var camera = SkyCamera(aspect: size.width / size.height, horizon: Double(view.horizon), facing: atan2(s.x, s.y) - 0.17)
        camera.height = 0.01
        let light = SkyLight.bake(camera: camera, date: date, latitude: lat, longitude: lon), texture = light.texture
        let lens = SIMD4<Float>(Float(camera.tanH), Float(camera.tanV), Float(camera.horizon), Float(light.bottom))
        let sky = SKSpriteNode(color: .black, size: size)
        sky.anchorPoint = .zero
        sky.shader = SKShader(source: shaderCommon + Self.skyShader, uniforms: [
            SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)]),
            SKUniform(name: "u_sky", texture: texture), SKUniform(name: "u_cam", vectorFloat4: lens),
            SKUniform(name: "u_fwd", vectorFloat3: SIMD3<Float>(camera.forward)),
            SKUniform(name: "u_right", vectorFloat3: SIMD3<Float>(camera.right)),
            SKUniform(name: "u_sun", vectorFloat3: SIMD3<Float>(s)),
            SKUniform(name: "u_disc", vectorFloat3: s.z > -0.02 ? SIMD3<Float>(light.sunColour) : .zero),
            SKUniform(name: "u_balance", vectorFloat3: balance),
        ])
        addChild(sky)

        // The sky's light (linear, as the shaders see it) along a row `v` up the screen, at one column or across it all.
        func glow(at v: Float, column: Int? = nil) -> SIMD3<Float> {
            let j = min(max(Int((v - Float(light.bottom)) / (1 - Float(light.bottom)) * Float(SkyLight.height)), 0), SkyLight.height - 1)
            let columns = column.map { [$0] } ?? Array(0..<SkyLight.width)
            var sum = SIMD3<Float>.zero
            for i in columns {
                let k = (j * SkyLight.width + i) * 4
                let c = SIMD3<Float>(Float(light.pixels[k]), Float(light.pixels[k + 1]), Float(light.pixels[k + 2])) / 255
                sum += c * c * 4 * balance
            }
            return sum / Float(columns.count)
        }
        let behind = glow(at: view.horizon + 0.3, column: SkyLight.width / 2) * 0.1
        let ink = (SIMD3<Float>(repeating: 1) - exp(-behind)).squareRoot()
        let horizon = glow(at: view.horizon + 0.01)
        return (SKColor(srgbRed: CGFloat(ink.x), green: CGFloat(ink.y), blue: CGFloat(ink.z), alpha: 1), texture, lens, horizon)
    }

    private static let skyShader = """
    void main() {
        vec2 uv = v_tex_coord;
        vec3 rd = normalize(u_right * ((uv.x * 2.0 - 1.0) * u_cam.x) + u_fwd + vec3(0.0, 0.0, (uv.y - u_cam.z) * 2.0 * u_cam.y));
        vec3 c4 = texture2D(u_sky, vec2(uv.x, max(uv.y - u_cam.w, 0.0) / (1.0 - u_cam.w))).rgb;
        vec3 col = c4 * c4 * 4.0 * u_balance;
        float ang = acos(clamp(dot(rd, u_sun), -1.0, 1.0));
        float disc = smoothstep(0.0050, 0.0044, ang);
        col += u_disc * (disc * 60.0 * (0.6 + 0.4 * sqrt(max(1.0 - ang * ang / 0.000022, 0.0))) + 0.25 * exp(-ang * 40.0) + 0.02 * exp(-ang * 8.0));
        col = sqrt(1.0 - exp(-col));
        gl_FragColor = vec4(col + (hash21(uv * u_size * 2.0) - 0.5) / 128.0, 1.0);
    }
    """
}

/// The view from the ground, in metres: x to the right, y away, z up from the eye. It's level, with the horizon a
/// straight line `horizon` of the way up the screen, 64° across like Weather's `SkyCamera`.
private struct GroundView {
    let size: CGSize, horizon: Float
    let tanH = Float(tan(32.0 * Double.pi / 180))

    /// Where a point lands on screen, in points, and how many points a metre spans there.
    func project(_ p: SIMD3<Float>) -> (x: Float, y: Float, perMetre: Float) {
        let k = Float(size.width) / (2 * tanH * max(p.y, 1))
        return (Float(size.width) / 2 + p.x * k, Float(size.height) * horizon + p.z * k, k)
    }
}

/// Starlings over the roost, after Hildenbrandt, Carere & Hemelrijk's StarDisplay (2010) and Ballerini et al. (2008),
/// in metres and seconds. Each agent is a parcel of birds reacting to its seven nearest neighbours: it keeps
/// its distance, lines up, holds to the flock's edge, cruises at 10 m/s and turns only by banking, so banked birds sink,
/// speed up and show the dark of their wings. Turns start at the leading edge and are copied bird to bird, sweeping
/// through the flock at about 15 m/s as real turns do (Attanasi et al. 2014). A falcon dives through now and then; the
/// birds it nearly catches roll away, and their neighbours copy the roll, sending dark bands across the flock
/// (Procaccini et al. 2011). Forces are StarDisplay's newtons over an 80 g bird.
private final class Flock: SKNode {
    private struct Bird {
        var p: SIMD3<Float>, v: SIMD3<Float>
        var force = SIMD3<Float>.zero                                 // steering, held between reactions
        var bank: Float = 0
        var turn: Float = 0, turning: Float = -1, turnRest: Float = 0 // a copied turn: its heading, its time so far
        var turnCue: Float = -1, cueTurn: Float = 0                   // seeing a neighbour turn, before copying it
        var zig: Float = -1, zigSide: Float = 0, zigSize: Float = 0   // a roll away from the falcon, and back
        var zigRest: Float = 0, zigCue: Float = -1, cueSide: Float = 0, cueSize: Float = 0
        var cell: Int32 = 0
    }

    private let view: GroundView
    private var birds: [Bird] = []
    private var sprites: [SKSpriteNode] = []
    private let atlas: [SKTexture]
    private var bucketStart = [Int32](repeating: 0, count: Flock.buckets + 1), bucketItems: [Int32] = []
    private var tick = 0, clock: Float = 0, nextTurn: Float = 7, nextFalcon: Float = 40
    private var falcon: (p: SIMD3<Float>, v: SIMD3<Float>, left: Float)?
    private var random: Xorshift
    /// The flock mirrored in the water: its ink splatted each frame over the screen below the horizon, for the ground's
    /// shader. Mirroring in level water flips a point about the horizon line on screen.
    let reflection = SKMutableTexture(size: reflectionSize)
    static let reflectionSize = CGSize(width: 384, height: 96)
    private var splat = [Float](repeating: 0, count: 384 * 96), bytes = [UInt8](repeating: 0, count: 384 * 96 * 4)
    private var touched = 0..<0 // the rows of the reflection that last held ink

    // ponytail: 1,500 agents, each a parcel standing for about 40 birds (60,000 in all), which is what the CPU allows.
    // A parcel draws as ten dark specks rather than forty faint ones, which matches how photos show a flock's grain.
    private static let count = 1500
    private static let buckets = 8192  // a spatial hash of `cell`-metre cubes
    private static let cell: Float = 6
    private static let parcel: Float = 7 // metres across a parcel's sprite
    // Parcel scale: 40 birds in a parcel spread lengths by 40^(1/3) ≈ 3.4 over a bird's. Separation reaches 20 m.
    private static let core: Float = 0.68, reach: Float = 9.2
    private let roost = SIMD3<Float>(0, 220, 44), roostSize = SIMD2<Float>(55, 40)

    init(view: GroundView, ink: SKColor) {
        self.view = view
        atlas = Self.makeAtlas()
        let seed = ProcessInfo.processInfo.environment["MURMURATION_SEED"].flatMap(UInt64.init) ?? .random(in: 1...UInt64.max)
        random = Xorshift(seed: seed)
        super.init()
        for _ in 0..<Self.count {
            let a = random.unit() * 2 * .pi, r = random.unit().squareRoot()
            let p = roost + SIMD3(cos(a) * r * 60, sin(a) * r * 30, 18 * sin(1) + (random.unit() - 0.5) * 16)
            birds.append(Bird(p: p, v: SIMD3(10, random.unit() * 2 - 1, random.unit() * 0.6 - 0.3)))
            // Wings level or raised: at a few pixels a wingbeat can't be seen, and flipping between them only flickers.
            let sprite = SKSpriteNode(texture: atlas[Int(random.next() % 8)])
            sprite.color = ink
            sprite.colorBlendFactor = 1
            sprite.zPosition = 2
            addChild(sprite)
            sprites.append(sprite)
        }
        bucketItems = [Int32](repeating: 0, count: Self.count)
        reflection.filteringMode = .linear
        for _ in 0..<150 { simulate(1.0 / 30) } // settle into a flock first
        place()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func step(_ dt: Float) {
        let n = max(Int((dt * 30 - 0.1).rounded(.up)), 1) // one step a frame at 30 fps, two at 15
        for _ in 0..<n { simulate(dt / Float(n)) }
        place()
    }

    /// Four scatterings of ten birds, each with wings level (a dash along x) and wings raised (a small V), in one
    /// mipmapped texture so every parcel draws in one batch. A parcel is `parcel` metres across; birds are 0.4 m.
    private static func makeAtlas() -> [SKTexture] {
        let side: CGFloat = 64, perMetre = side / CGFloat(parcel)
        let sheet = paint(CGSize(width: side * 4, height: side * 2)) { ctx in
            ctx.setStrokeColor(rgb(0.03, 0.025, 0.035))
            ctx.setLineCap(.round)
            ctx.setLineWidth(0.15 * perMetre)
            for layout in 0..<4 {
                var rng = Xorshift(seed: UInt64(layout + 7))
                for _ in 0..<10 {
                    // Gaussian scatter, σ 1.3 m, so neighbouring parcels overlap into an even texture.
                    let r = CGFloat(min(sqrt(-2 * log(max(rng.unit(), 1e-4))) * 1.3, 3.3)), a = CGFloat(rng.unit() * 2 * .pi)
                    // Spans vary by wing pose as much as by distance: in photos the 90th percentile bird is twice the median.
                    let pose = CGFloat(exp((rng.unit() + rng.unit() + rng.unit() - 1.5) * 0.55))
                    let span = min(0.36 * pose, 0.8) * perMetre, tilt = CGFloat(rng.unit() - 0.5) * 1.2
                    for raised in 0..<2 {
                        ctx.saveGState()
                        ctx.translateBy(x: CGFloat(layout) * side + side / 2 + cos(a) * r * perMetre,
                                        y: CGFloat(raised) * side + side / 2 + sin(a) * r * perMetre)
                        ctx.rotate(by: tilt)
                        if raised == 0 {
                            ctx.move(to: CGPoint(x: -span / 2, y: 0)); ctx.addLine(to: CGPoint(x: span / 2, y: 0))
                        } else {
                            ctx.move(to: CGPoint(x: -span * 0.4, y: span * 0.25)); ctx.addLine(to: .zero)
                            ctx.addLine(to: CGPoint(x: span * 0.4, y: span * 0.25))
                        }
                        ctx.strokePath()
                        ctx.restoreGState()
                    }
                }
            }
        }
        sheet.usesMipmaps = true
        return (0..<8).map { i in
            SKTexture(rect: CGRect(x: CGFloat(i / 2) / 4, y: CGFloat(i % 2) / 2, width: 0.25, height: 0.5), in: sheet)
        }
    }

    /// Draws each parcel where it is, its wings turned as they'd look from here, darker the more wing we see
    /// (a level bird seen from below and to the side shows little; one rolled toward us shows all of it).
    private func place() {
        let up = SIMD3<Float>(0, 0, 1)
        let (cols, rows) = (Int(Self.reflectionSize.width), Int(Self.reflectionSize.height))
        let horizon = Float(view.size.height) * view.horizon, across = Float(view.size.width) / Float(cols)
        let texel = across * horizon / Float(rows) // points² per texel
        var low = rows, high = 0
        for i in 0..<birds.count {
            let b = birds[i], sprite = sprites[i]
            let ex = simd_normalize(b.v), ey = simd_normalize(simd_cross(up, ex) + SIMD3(0, 1e-6, 0))
            let ez = simd_cross(ex, ey) * cos(b.bank) + ey * sin(b.bank)
            let at = view.project(b.p), wing = view.project(b.p + simd_cross(ez, ex)), top = view.project(b.p + ez)
            var (wx, wy) = (wing.x - at.x, wing.y - at.y)
            if wx * (top.y - at.y) - wy * (top.x - at.x) < 0 { (wx, wy) = (-wx, -wy) } // raised wings point up the bird
            let facing = abs(simd_dot(ez, simd_normalize(b.p)))
            sprite.position = CGPoint(x: CGFloat(at.x), y: CGFloat(at.y))
            sprite.zRotation = CGFloat(atan2(wy, wx))
            sprite.setScale(CGFloat(Self.parcel * at.perMetre / 64))
            let alpha = 0.22 + 0.45 * facing
            sprite.alpha = CGFloat(alpha)
            // Its reflection: ten birds of about 0.06 m² each, spread over the texels it lands on.
            let below = 2 * horizon - at.y
            if below > 0 && below < horizon {
                let x = at.x / across, y = below / horizon * Float(rows)
                let (tx, ty) = (Int(x.rounded(.down)), Int(y))
                if x >= 0 && tx < cols - 1 && ty < rows - 1 {
                    let ink = alpha * 0.6 * at.perMetre * at.perMetre / texel, fx = x - Float(tx), fy = y - Float(ty)
                    splat[ty * cols + tx] += ink * (1 - fx) * (1 - fy); splat[ty * cols + tx + 1] += ink * fx * (1 - fy)
                    splat[(ty + 1) * cols + tx] += ink * (1 - fx) * fy; splat[(ty + 1) * cols + tx + 1] += ink * fx * fy
                    low = min(low, ty); high = max(high, ty + 2)
                }
            }
        }
        // Upload the reflection only while the flock is over the water, converting just the rows it touched now or last
        // frame, and once more to clear it after. Ink saturates as d / (1 + d), close to 1 − e^−d.
        let now = low < high ? low..<high : 0..<0
        guard !now.isEmpty || !touched.isEmpty else { return }
        let rowsToConvert = now.isEmpty ? touched : touched.isEmpty ? now : min(now.lowerBound, touched.lowerBound)..<max(now.upperBound, touched.upperBound)
        touched = now
        for k in rowsToConvert.lowerBound * cols..<rowsToConvert.upperBound * cols {
            bytes[k * 4] = UInt8(splat[k] / (1 + splat[k]) * 255)
            splat[k] = 0
        }
        let data = bytes
        reflection.modifyPixelData { pointer, length in
            data.withUnsafeBytes { pointer?.copyMemory(from: $0.baseAddress!, byteCount: min(length, $0.count)) }
        }
    }

    private func simulate(_ dt: Float) {
        tick += 1
        clock += dt
        let cell = Self.cell, buckets = Self.buckets, core = Self.core, reach = Self.reach
        let roost = roost, roostSize = roostSize, tick = tick
        // The roost height drifts over a few minutes, so the flock sometimes swoops low over the water.
        let height = roost.z + 18 * sin(clock * 0.035 + 1)
        let up = SIMD3<Float>(0, 0, 1), g: Float = 9.81
        var middle = SIMD3<Float>.zero, flow = SIMD3<Float>.zero
        for b in birds { middle += b.p; flow += b.v }
        middle /= Float(birds.count)

        // Every 7 s the bird furthest ahead starts a turn: back over the roost if the flock has wandered, otherwise a
        // swing of 60–150° either way. Its neighbours copy it, and theirs copy them. (Sooner and the waves overlap.)
        nextTurn -= dt
        if nextTurn < 0 {
            nextTurn = 7
            let ahead = simd_normalize(SIMD3(flow.x, flow.y, 0))
            var lead = 0, best = -Float.infinity
            for (i, b) in birds.enumerated() where simd_dot(b.p - middle, ahead) > best { best = simd_dot(b.p - middle, ahead); lead = i }
            let home = SIMD2(roost.x - middle.x, roost.y - middle.y) / roostSize
            let now = atan2(ahead.y, ahead.x)
            birds[lead].turn = simd_dot(home, home) > 0.5
                ? atan2(roost.y - middle.y, roost.x - middle.x) + random.unit() - 0.5
                : now + (random.unit() < 0.5 ? -1 : 1) * (1 + 1.6 * random.unit())
            birds[lead].turning = 0
            birds[lead].turnRest = 0
        }

        // The falcon: every minute or so it dives through the flock from above, at 22 m/s over 6 s.
        nextFalcon -= dt
        if nextFalcon < 0 && murmurationKnobs[1].value > 0.5 {
            nextFalcon = 45 + 45 * random.unit()
            let a = random.unit() * 2 * .pi, v = SIMD3(cos(a) * 22, sin(a) * 22, -4)
            falcon = (middle - v * 3, v, 6)
        }
        if var f = falcon {
            f.p += f.v * dt
            f.left -= dt
            falcon = f.left > 0 ? f : nil
        }
        let hawk = falcon?.p

        func key(_ x: Int, _ y: Int, _ z: Int) -> Int {
            Int(UInt32(truncatingIfNeeded: x &* 73856093 ^ y &* 19349663 ^ z &* 83492791) % UInt32(buckets))
        }
        func cellOf(_ p: SIMD3<Float>) -> (Int, Int, Int) {
            let q = (p / cell).rounded(.down)
            return (Int(q.x), Int(q.y), Int(q.z))
        }

        bucketStart.withUnsafeMutableBufferPointer { start in
            bucketItems.withUnsafeMutableBufferPointer { items in
                birds.withUnsafeMutableBufferPointer { birds in
                    // Bucket birds by spatial hash (counting sort).
                    for c in 0..<start.count { start[c] = 0 }
                    for i in 0..<birds.count {
                        let (x, y, z) = cellOf(birds[i].p)
                        birds[i].cell = Int32(key(x, y, z))
                        start[Int(birds[i].cell) + 1] += 1
                    }
                    for c in 1..<start.count { start[c] += start[c - 1] }
                    for i in 0..<birds.count {
                        let c = Int(birds[i].cell)
                        items[Int(start[c])] = Int32(i)
                        start[c] += 1
                    }
                    for c in stride(from: start.count - 1, to: 0, by: -1) { start[c] = start[c - 1] } // back to each bucket's start
                    start[0] = 0

                    var nearTuple = (Int32(0), Int32(0), Int32(0), Int32(0), Int32(0), Int32(0), Int32(0))
                    var distTuple = (Float(0), Float(0), Float(0), Float(0), Float(0), Float(0), Float(0))
                    withUnsafeMutableBytes(of: &nearTuple) { nb in
                    withUnsafeMutableBytes(of: &distTuple) { db in
                    let near = nb.bindMemory(to: Int32.self), dist = db.bindMemory(to: Float.self)
                    for i in 0..<birds.count {
                        var b = birds[i]
                        let speed = max(simd_length(b.v), 0.1), ex = b.v / speed
                        let ey = simd_normalize(simd_cross(up, ex) + SIMD3(0, 1e-6, 0)) // to the bird's left

                        // A parcel reacts every fifth step (1/6 s: a starling's 0.076 s scaled up to a parcel) and holds
                        // its steering in between.
                        if (tick + i) % 5 == 0 {
                            // The seven nearest, by insertion into a short sorted list, and how crowded it is within 6 m.
                            var found = 0, crowd = 0
                            let (cx, cy, cz) = cellOf(b.p)
                            for gz in cz - 1...cz + 1 { for gy in cy - 1...cy + 1 { for gx in cx - 1...cx + 1 {
                                let k = key(gx, gy, gz)
                                for s in Int(start[k])..<Int(start[k + 1]) {
                                    let j = items[s]
                                    if j == Int32(i) { continue }
                                    let d = birds[Int(j)].p - b.p
                                    let d2 = simd_dot(d, d)
                                    if d2 < cell * cell { crowd += 1 }
                                    if found == 7 && d2 >= dist[6] { continue }
                                    var m = min(found, 6)
                                    while m > 0 && dist[m - 1] > d2 { near[m] = near[m - 1]; dist[m] = dist[m - 1]; m -= 1 }
                                    near[m] = j; dist[m] = d2
                                    found = min(found + 1, 7)
                                }
                            } } }

                            // Separation all round; cohesion (for birds on the flock's edge, by their centrality) and
                            // alignment with those not in the blind cone behind. Seeing one of them turn or roll away is
                            // the cue to copy it.
                            var apart = SIMD3<Float>.zero, together = apart, headings = apart, centre = apart
                            var seen = 0, copyRoll: (side: Float, size: Float)?
                            for m in 0..<found {
                                let o = birds[Int(near[m])]
                                let d = dist[m].squareRoot() + 1e-4, u = (o.p - b.p) / d
                                centre += u
                                let x = max(d - core, 0) / reach
                                apart -= u * exp(-x * x)
                                if simd_dot(u, ex) > -0.707 {
                                    seen += 1
                                    if d > core { together += u }
                                    headings += o.v / max(simd_length(o.v), 0.01)
                                    if o.turning >= 0 && b.turning < 0 && b.turnRest <= 0 && b.turnCue < 0 { b.turnCue = 0.15; b.cueTurn = o.turn }
                                    if o.zig >= 0 && o.zig < 0.25 && b.zigRest <= 0 && b.zig < 0 && b.zigCue < 0 { copyRoll = (o.zigSide, o.zigSize) }
                                }
                            }
                            var force = SIMD3<Float>.zero
                            if found > 0 {
                                force += apart * (12.5 / Float(found))
                                if seen > 0 {
                                    let centrality = simd_length(centre) / Float(found)
                                    force += together * (centrality * 12.5 / Float(seen))
                                    let turn = headings - ex * Float(seen), l = simd_length(turn)
                                    if l > 1e-3 { force += turn / l * (6.25 * min(1, l / Float(seen) * 4)) }
                                }
                            }
                            // Few close neighbours means the thin edge: steer for the middle (Hoetzlein's Flock2), which
                            // keeps one flock with a crisp outline. A weak spring holds the roost's height.
                            force += simd_normalize(middle - b.p + SIMD3(0, 0, 1e-4)) * (12.5 * max(0, 1 - Float(crowd) / 12))
                            force.z -= (b.p.z - height) * 0.1
                            force += SIMD3(random.unit() - 0.5, random.unit() - 0.5, random.unit() - 0.5) * 0.25
                            if let hawk {
                                let away = b.p - hawk, d = simd_length(away)
                                if d < 25 { force += away / (d + 0.1) * (37.5 * (1 - d / 25)) } // scatter from it
                                if d < 20 && b.zigRest <= 0 && b.zig < 0 { b.zig = 0; b.zigSide = simd_dot(ey, away) > 0 ? 1 : -1; b.zigSize = 1.2 }
                            }
                            if b.turning >= 0 {
                                var off = b.turn - atan2(ex.y, ex.x)
                                off = atan2(sin(off), cos(off))
                                force += ey * (12.5 * min(max(off / 0.5, -1), 1))
                                if abs(off) < 0.17 || b.turning > 4 { b.turning = -1; b.turnRest = 4 }
                            }
                            if let roll = copyRoll, roll.size > 0.3 { b.zigCue = 0.15; b.cueSide = roll.side; b.cueSize = roll.size * 0.9 }
                            b.force = force
                        }

                        let force = b.force + ex * (10 - speed) // hold to the cruising speed, 10 m/s
                        if b.turning >= 0 { b.turning += dt }
                        b.turnRest -= dt
                        if b.turnCue >= 0 { b.turnCue -= dt; if b.turnCue < 0 { b.turning = 0; b.turn = b.cueTurn } }
                        if b.zigCue >= 0 { b.zigCue -= dt; if b.zigCue < 0 { b.zig = 0; b.zigSide = b.cueSide; b.zigSize = b.cueSize } }

                        // Fly: the sideways pull only sets the bank, rolling in fast and out slowly; lift ∝ speed² tilts
                        // with it, so a banked bird turns, sinks and speeds up, then climbs back as it levels. A zig
                        // rolls hard for 0.25 s and back, which is what shows as a dark band.
                        let pull = simd_dot(force, ey)
                        var want = min(max(atan(pull / g), -1.2), 1.2), roll: Float = abs(want) > abs(b.bank) ? 0.1 : 0.4
                        if b.zig >= 0 {
                            want = b.zig < 0.25 ? b.zigSide * b.zigSize : 0
                            roll = 0.06
                            b.zig += dt
                            if b.zig > 0.55 { b.zig = -1; b.zigRest = 1 }
                        }
                        b.zigRest -= dt
                        b.bank += (want - b.bank) * (1 - exp(-dt / roll))
                        let ez = simd_cross(ex, ey) * cos(b.bank) + ey * sin(b.bank)
                        let lift = g * speed * speed / 100
                        b.v += (force - ey * pull + ez * lift + ex * (g - lift) / 3.3 - up * g) * dt
                        birds[i] = b
                    }
                    } }
                    for i in 0..<birds.count { birds[i].p += birds[i].v * dt }
                }
            }
        }
    }
}

/// A small, fast random number generator (xorshift64*), since the system one is slow in a hot loop.
private struct Xorshift {
    var state: UInt64
    init(seed: UInt64) { state = seed | 1 }
    mutating func next() -> UInt64 {
        state ^= state >> 12; state ^= state << 25; state ^= state >> 27
        return state &* 2685821657736338717
    }
    /// A number in 0..<1.
    mutating func unit() -> Float { Float(next() >> 40) / Float(1 << 24) }
}

/// The murmuration before its photoreal pass, for the Compare switch: a painted sunset, and a flat flock simulated in
/// screen points, each boid drawn as a cluster of four dots.
private final class ClassicMurmuration: SKNode {
    private struct Bird { var x, y, z, vx, vy, vz: Float; var cell: Int32 }

    private let size: CGSize
    private var flock: [Bird] = []
    private var sprites: [SKSpriteNode] = []
    private var cellStart: [Int32] = [], cellItems: [Int32] = []
    private var cols = 0, rows = 0, layers = 0
    private var time: TimeInterval = 0

    private let neighbourRadius: Float = 40
    private let personalSpace: Float = 20
    private let depth: Float = 400 // the grid covers z in ±depth; the flock stays well inside it
    private let focal: Float = 1300 // perspective strength; nearer birds (z > 0) draw bigger

    init(size: CGSize) {
        self.size = size
        super.init()
        let w = size.width, h = size.height
        addChild(backdrop(size, [
            (0, rgb(1, 0.72, 0.45)), (0.12, rgb(0.98, 0.56, 0.42)), (0.32, rgb(0.78, 0.43, 0.5)),
            (0.6, rgb(0.42, 0.34, 0.54)), (1, rgb(0.16, 0.18, 0.37)),
        ]))
        addSunAndClouds()

        let horizon = treeline(width: w, base: h * 0.08, hills: h * 0.012, trees: h * 0.015...h * 0.05, spacing: 5...16,
                               color: rgb(0.14, 0.08, 0.14), pineChance: 0.25, resolution: 0.5)
        horizon.zPosition = 3
        addChild(horizon)
        let reeds = grassFringe(width: w, height: h * 0.07, color: rgb(0.08, 0.045, 0.08))
        reeds.zPosition = 4
        addChild(reeds)

        cols = Int(Float(w) / neighbourRadius) + 3
        rows = Int(Float(h) / neighbourRadius) + 3
        layers = Int(2 * depth / neighbourRadius) + 1
        cellStart = [Int32](repeating: 0, count: cols * rows * layers + 1)

        // ponytail: each simulated bird is drawn as a little cluster of four, so ~1,300 boids read as ~5,000 starlings
        let count = Int(w * h / 1100)
        let ink = rgb(0.06, 0.04, 0.08)
        let cluster = paint(CGSize(width: 12, height: 12)) { ctx in
            ctx.setFillColor(ink)
            for (x, y, r) in [(3.0, 4.0, 1.1), (8.5, 3.0, 1.0), (6.0, 8.5, 1.15), (10.0, 9.0, 0.9)] as [(CGFloat, CGFloat, CGFloat)] {
                ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
            }
        }
        for _ in 0..<count {
            let a = Float.random(in: 0...(2 * .pi)), r = sqrt(Float.random(in: 0...1))
            flock.append(Bird(x: Float(w) * 0.45 + cos(a) * r * 300, y: Float(h) * 0.62 + sin(a) * r * 110,
                              z: .random(in: -150...150), vx: .random(in: 90...130), vy: .random(in: -15...15), vz: .random(in: -15...15), cell: 0))
            let sprite = SKSpriteNode(texture: cluster, size: CGSize(width: 12, height: 12))
            sprite.zRotation = .random(in: 0...(2 * .pi))
            sprite.alpha = 0.85
            sprite.zPosition = 2
            addChild(sprite)
            sprites.append(sprite)
        }
        cellItems = [Int32](repeating: 0, count: count)
        place()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func step(_ dt: TimeInterval) {
        time += dt
        simulate(Float(dt))
        place()
    }

    private func place() {
        let cx = Float(size.width / 2), cy = Float(size.height / 2)
        for (bird, sprite) in zip(flock, sprites) {
            let s = focal / (focal - bird.z)
            sprite.position = CGPoint(x: CGFloat(cx + (bird.x - cx) * s), y: CGFloat(cy + (bird.y - cy) * s))
            sprite.setScale(CGFloat(s))
        }
    }

    /// One step of the flock. Neighbours come from a 3D grid of `neighbourRadius` cells, capped at 10 per bird
    /// (starlings track about seven), so the cost stays linear in flock size.
    private func simulate(_ dt: Float) {
        let w = Float(size.width), h = Float(size.height), t = Float(time)
        let cols = cols, rows = rows, layers = layers, radius = neighbourRadius, space = personalSpace, depth = depth

        // Where the flock is drawn toward, and how tightly it holds together, both wander slowly.
        let targetX = w * (0.5 + 0.2 * sin(0.061 * t) + 0.06 * sin(0.17 * t + 1))
        let targetY = h * (0.56 + 0.1 * sin(0.093 * t + 2))
        let cohesion: Float = 0.4 + 0.2 * sin(0.05 * t)

        // The falcon: every 26 s it crosses the sky for 5 s, passing through where the flock was when it started.
        let cycle = t.truncatingRemainder(dividingBy: 26)
        var falcon: (x: Float, y: Float)?
        if cycle > 19 {
            let p = (cycle - 19) / 5 * 1.6 - 0.8, angle = Float(Int(t / 26) % 7) * 0.9
            falcon = (targetX + cos(angle) * p * w * 0.6, targetY + sin(angle) * p * h * 0.4)
        }

        cellStart.withUnsafeMutableBufferPointer { start in
            cellItems.withUnsafeMutableBufferPointer { items in
                flock.withUnsafeMutableBufferPointer { birds in
                    // Bucket birds into grid cells (counting sort).
                    for c in 0..<start.count { start[c] = 0 }
                    for i in 0..<birds.count {
                        let cx = min(max(Int(birds[i].x / radius) + 1, 0), cols - 1)
                        let cy = min(max(Int(birds[i].y / radius) + 1, 0), rows - 1)
                        let cz = min(max(Int((birds[i].z + depth) / radius), 0), layers - 1)
                        birds[i].cell = Int32((cz * rows + cy) * cols + cx)
                        start[Int(birds[i].cell) + 1] += 1
                    }
                    for c in 1..<start.count { start[c] += start[c - 1] }
                    var fill = Array(start)
                    for i in 0..<birds.count {
                        let c = Int(birds[i].cell)
                        items[Int(fill[c])] = Int32(i)
                        fill[c] += 1
                    }

                    for i in 0..<birds.count {
                        var b = birds[i]
                        var ax: Float = 0, ay: Float = 0, az: Float = 0
                        var sx: Float = 0, sy: Float = 0, sz: Float = 0 // neighbours' summed position
                        var ux: Float = 0, uy: Float = 0, uz: Float = 0 // and velocity
                        var seen = 0
                        let c = Int(b.cell), cx = c % cols, cy = c / cols % rows, cz = c / (cols * rows)
                        search: for gz in max(cz - 1, 0)...min(cz + 1, layers - 1) {
                          for gy in max(cy - 1, 0)...min(cy + 1, rows - 1) {
                            for gx in max(cx - 1, 0)...min(cx + 1, cols - 1) {
                                let cell = (gz * rows + gy) * cols + gx
                                for k in Int(start[cell])..<Int(start[cell + 1]) {
                                    let j = Int(items[k])
                                    if j == i { continue }
                                    let o = birds[j]
                                    let dx = b.x - o.x, dy = b.y - o.y, dz = b.z - o.z
                                    let d2 = dx * dx + dy * dy + dz * dz
                                    if d2 > radius * radius { continue }
                                    let d = d2.squareRoot() + 0.01
                                    if d < space {
                                        let push = 900 * (1 - d / space) / d
                                        ax += dx * push; ay += dy * push; az += dz * push
                                    }
                                    sx += o.x; sy += o.y; sz += o.z
                                    ux += o.vx; uy += o.vy; uz += o.vz
                                    seen += 1
                                    if seen == 10 { break search }
                                }
                            }
                          }
                        }
                        if seen > 0 {
                            let n = Float(seen)
                            ax += (ux / n - b.vx) * 2.4 + (sx / n - b.x) * cohesion
                            ay += (uy / n - b.vy) * 2.4 + (sy / n - b.y) * cohesion
                            az += (uz / n - b.vz) * 2.4 + (sz / n - b.z) * cohesion
                        }
                        // Steer toward the target at a constant pull, which turns the flock without squeezing it to a point.
                        let tx = targetX - b.x, ty = targetY - b.y, td = (tx * tx + ty * ty).squareRoot() + 1
                        ax += tx / td * 45
                        ay += ty / td * 45
                        az -= b.z * 0.35

                        // Soft walls keep the flock in the sky and on screen, with room for perspective to push near birds outward.
                        ay += max(0, h * 0.3 - b.y) * 4 - max(0, b.y - h * 0.82) * 4
                        ax += max(0, w * 0.12 - b.x) * 4 - max(0, b.x - w * 0.88) * 4

                        if let falcon {
                            let dx = b.x - falcon.x, dy = b.y - falcon.y, d = (dx * dx + dy * dy).squareRoot() + 0.01
                            if d < 130 {
                                let flee = 1100 * (1 - d / 130) / d
                                ax += dx * flee; ay += dy * flee
                            }
                        }

                        b.vx += ax * dt; b.vy += ay * dt; b.vz += az * dt
                        let speed = (b.vx * b.vx + b.vy * b.vy + b.vz * b.vz).squareRoot()
                        let clamped = min(max(speed, 90), 170)
                        b.vx *= clamped / speed; b.vy *= clamped / speed; b.vz *= clamped / speed
                        birds[i] = b
                    }
                    for i in 0..<birds.count {
                        birds[i].x += birds[i].vx * dt
                        birds[i].y += birds[i].vy * dt
                        birds[i].z += birds[i].vz * dt
                    }
                }
            }
        }
    }

    private func addSunAndClouds() {
        let w = size.width, h = size.height
        let glow = SKSpriteNode(texture: radialGlow(diameter: 128, stops: [
            (0, rgb(1, 0.95, 0.8, 0.9)), (0.08, rgb(1, 0.85, 0.6, 0.7)), (0.3, rgb(1, 0.65, 0.4, 0.25)), (1, rgb(1, 0.5, 0.3, 0)),
        ]), size: CGSize(width: h * 0.9, height: h * 0.9))
        glow.position = CGPoint(x: w * 0.7, y: h * 0.1)
        glow.blendMode = .add
        glow.zPosition = 1
        addChild(glow)

        let streak = radialGlow(diameter: 64, stops: [(0, rgb(1, 1, 1, 0.9)), (0.5, rgb(1, 1, 1, 0.4)), (1, rgb(1, 1, 1, 0))])
        for _ in 0..<7 {
            let cloud = SKSpriteNode(texture: streak, size: CGSize(width: .random(in: 300...700), height: .random(in: 14...34)))
            cloud.position = CGPoint(x: .random(in: 0...w), y: h * .random(in: 0.18...0.5))
            cloud.color = NSColor(red: 1, green: .random(in: 0.6...0.8), blue: .random(in: 0.55...0.7), alpha: 1)
            cloud.colorBlendFactor = 1
            cloud.alpha = .random(in: 0.2...0.45)
            cloud.zPosition = 1
            addChild(cloud)
        }
    }
}
