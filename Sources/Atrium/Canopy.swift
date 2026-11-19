import CanopyBake
import CoreLocation
import SpriteKit
import Synchronization
import simd

@MainActor func canopy(size: CGSize) -> SKScene { Canopy(size: size) }

/// Lying on the forest floor, looking straight up: a real bare stand, photographed straight up and keyed from its sky,
/// with scanned leaves grown on its twigs for the season at the real date and place, lit leaf by leaf by the light
/// through the leaves above them, against the real sky for this hour (`Atmosphere` through a camera pointed at the
/// zenith, 90° across the long side, head to the north), and at night the real stars and the Milky Way through the
/// gaps. docs/canopy.md has the plan and what is built.
///
/// The first sky is made with the scene; everything else is baked off the main thread (`bake`): the stand decoded and
/// its leaves grown and lit (`CanopyBake`, a target of its own built with -O), the sky for the moment, and the stars
/// once night comes. Each bake lands in the picture behind and fades in over the one in front: the first as the canopy
/// appears, then one every five minutes for the real time, the same seed so the same stand and leaves, so afternoon
/// turns to dusk, the stars come out and morning comes without a rebuild. The render tests, with no view, wait for
/// the first.
final class Canopy: SKScene, BatteryPaced {
    /// For pictures: a seed for the stand's mirroring and its leaves (unset or 0 for a new one each load), a day
    /// (`yyyy-MM-dd`) and an hour of the local clock (13.5 for half past one), each unset for now; and for films, the
    /// mean wind in m/s (`Breeze.mean`).
    static let pins = (seed: "canopy.seed", date: "canopy.date", hour: "canopy.hour", wind: "canopy.wind")
    /// The stand: Poly Haven's Schachen Forest straight up, its sky keyed out by docs/canopy/stand.swift, 1512 px to a
    /// unit of tan, spanning ±1.1 across and ±0.75 up.
    nonisolated static let stand = (name: "canopy-schachen.heic", perTan: 1512.0, extent: SIMD2<Double>(1.1, 0.75))
    /// How far the moment shown may fall behind the clock before it is baked again, and how long a new bake takes to
    /// fade in: the first, or one far behind (the view was covered for a while), quickly.
    static let every: TimeInterval = 300, fade: (slow: TimeInterval, quick: TimeInterval) = (8, 1.2)

    private let lens: Camera, seed: UInt64, place: CLLocationCoordinate2D?
    /// The picture in front, and the one behind that the next bake lands in and fades in from.
    private var front: Picture, back: Picture
    private let night: Night
    /// The motion's uniforms, shared by both pictures, set every frame from the breeze.
    private let breeze: Breeze, motion: Motion
    /// The leaves falling in autumn, over both pictures.
    let leaves: Leaves
    /// The ceiling on battery, by the fastest thing moving (`rate`): 10-20 by the breeze, none while a leaf falls.
    var batteryRate: Int? = 12 { didSet { batteryRateChanged(from: oldValue) } }
    private var job: Job?, fading: (start: TimeInterval, length: TimeInterval)?, ticked: TimeInterval = -.infinity
    /// The moment the latest bake shows, and the Sun's height then; whether the canopy has landed yet.
    private var shown: (moment: Date, sun: Double), landed = false

    /// `place` holds one for the tests; the scene follows `Location` without it.
    init(size: CGSize, place: CLLocationCoordinate2D? = nil) {
        let defaults = UserDefaults.standard, here = place ?? Location.shared.coordinate
        var seed = UInt64(max(defaults.integer(forKey: Self.pins.seed), 0))
        if seed == 0 { seed = .random(in: 1...UInt64(UInt32.max)) }
        let moment = Self.moment(day: defaults.string(forKey: Self.pins.date), hour: defaults.object(forKey: Self.pins.hour) as? Double)
        let camera = Camera(size: size), night = Night(), motion = Motion(camera: camera)
        let light = Light(camera: camera, date: moment, latitude: here.latitude, longitude: here.longitude)
        (lens, self.seed, self.place, self.night, shown) = (camera, seed, place, night, (moment, light.sun.z))
        (breeze, self.motion, leaves) = (Breeze(seed: seed, mean: defaults.object(forKey: Self.pins.wind) as? Double ?? 4.3), motion, Leaves())
        (front, back) = (Picture(camera: camera, night: night, motion: motion), Picture(camera: camera, night: night, motion: motion))
        super.init(size: size)

        backgroundColor = .black
        for picture in [front, back] {
            picture.sprite.size = size
            picture.sprite.anchorPoint = .zero
            addChild(picture.sprite)
        }
        back.sprite.isHidden = true
        for node in leaves.nodes { addChild(node) }
        front.show(light, nil, sunShows: 0) // the sky at once, the canopy as it lands
        bake(moment, light: light, priority: .userInitiated)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        Location.shared.start()
    }

    override func update(_ currentTime: TimeInterval) {
        if let job, let baked = job.take(waiting: view == nil) {
            self.job = nil
            land(baked, at: currentTime)
        }
        if let fading { // the new picture over the old, at once in the tests
            let k = view == nil ? 1 : simd_smoothstep(0, 1, (currentTime - fading.start) / fading.length)
            back.sprite.alpha = k
            if k >= 1 { settle() }
        }
        if currentTime - ticked >= 1 {
            ticked = currentTime
            tick()
        }
        motion.set(breeze, at: currentTime, fps: view?.preferredFramesPerSecond ?? 30)
        leaves.step(currentTime, breeze: breeze, camera: lens, size: size)
        batteryRate = Self.rate(fastest: breeze.fastest(currentTime), night: front.starlight > 0.5, falling: leaves.falling > 0)
    }

    /// The lowest rate at which the fastest thing moves about 2 px a frame or less (at 2x on a 14" screen), which
    /// looks the same as 30 fps (`Breeze.fastest`, px a second); 10 at night, when black crowns move on a dark sky;
    /// and no ceiling while a leaf falls, at 100-300 px a second.
    static func rate(fastest: Double, night: Bool, falling: Bool) -> Int? {
        if falling { return nil }
        if night { return 10 }
        return [10, 12, 15, 20, 30].first { fastest / Double($0) <= 2 }
    }

    private var here: CLLocationCoordinate2D { place ?? Location.shared.coordinate }

    /// Once a second: the stars turned to where the sky is now (a second's turn is a twelfth of a pixel at the zenith),
    /// and a new bake once the moment has moved on five minutes, except in the dark of night, when nothing but the
    /// stars changes and they turn by themselves.
    private func tick() {
        let defaults = UserDefaults.standard
        let moment = Self.moment(day: defaults.string(forKey: Self.pins.date), hour: defaults.object(forKey: Self.pins.hour) as? Double)
        let toHorizon = Sky.horizonMatrix(jd: Sky.julianDate(moment), latitude: here.latitude, longitude: here.longitude)
        if night.held { night.turn(toHorizon) }
        guard job == nil, fading == nil, abs(moment.timeIntervalSince(shown.moment)) >= Self.every else { return }
        let sun = normalize(toHorizon * Sky.sun(Sky.julianDate(moment))).z
        if max(sun, shown.sun) < -0.31 { return } // the Sun 18° down then and now: the same picture
        bake(moment)
    }

    /// Bakes the light, the canopy and (if night comes and they aren't held) the stars for `moment`, off the main thread.
    private func bake(_ moment: Date, light: Light? = nil, priority: TaskPriority = .utility) {
        let job = Job(), (camera, seed, here, dark, shapes) = (lens, seed, here, !night.held, leaves.nodes.first?.texture == nil)
        self.job = job
        Task.detached(priority: priority) {
            job.arrive(Self.bake(moment: moment, latitude: here.latitude, longitude: here.longitude, camera: camera, seed: seed,
                                 light: light, night: dark, shapes: shapes))
        }
    }

    /// Lays a bake in the picture behind and starts it fading in.
    private func land(_ baked: Baked, at time: TimeInterval) {
        if let stars = baked.textures.stars, let photo = baked.textures.photo { night.hold(stars, photo) }
        if night.held {
            night.turn(Sky.horizonMatrix(jd: Sky.julianDate(baked.moment), latitude: here.latitude, longitude: here.longitude))
        }
        back.show(baked.light, baked.textures, sunShows: baked.made.sunShows)
        leaves.take(baked.textures.leaves)
        leaves.season(baked.moment, latitude: here.latitude, light: baked.light)
        back.sprite.alpha = 0
        back.sprite.isHidden = false
        (back.sprite.zPosition, front.sprite.zPosition) = (1, 0)
        let quick = !landed || abs(baked.moment.timeIntervalSince(shown.moment)) > 900
        fading = (time, quick ? Self.fade.quick : Self.fade.slow)
        (shown, landed) = ((baked.moment, baked.light.sun.z), true)
    }

    /// The new picture is in: the old one lets go of its textures and goes behind, and by day the night's go too.
    private func settle() {
        front.clear()
        front.sprite.isHidden = true
        (front, back, fading) = (back, front, nil)
        if front.starlight == 0 { night.release() }
    }

    /// The moment to show: now, or the pinned day and hour of the local clock.
    static func moment(day: String?, hour: Double?) -> Date {
        let calendar = Calendar.current, now = Date()
        var start = calendar.startOfDay(for: now)
        let parts = day?.split(separator: "-").compactMap { Int($0) } ?? []
        if parts.count == 3, let pinned = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) { start = pinned }
        let hours = hour ?? now.timeIntervalSince(calendar.startOfDay(for: now)) / 3600
        return calendar.date(byAdding: .second, value: Int(hours * 3600), to: start) ?? start
    }

    fileprivate static let clear = SKTexture(data: Data(count: 4), size: CGSize(width: 1, height: 1))

    /// One bake: the moment, its light and canopy, and their textures, made off the main thread too.
    struct Baked: Sendable {
        let moment: Date, light: Light, made: CanopyBake.Made, textures: Textures
    }

    /// A bake's textures: the sky, the canopy, its cover and its sway map, the nearest leaves, the
    /// falling leaves' shapes if asked for, and the night's if asked for and it is night, the stars' grid and Night
    /// Sky's photograph of the Milky Way (a 6000 × 3000 HEIC, 160 ms to decode).
    struct Textures: @unchecked Sendable { // made off the main thread, then only handed over
        let sky: SKTexture, canopy: SKTexture, cover: SKTexture, sway: SKTexture, near: SKTexture, stars: SKTexture?, photo: SKTexture?, leaves: [SKTexture]
    }

    /// Everything about one moment that takes time, off the main thread: the light (unless given), the canopy grown
    /// and lit by it for the season then, and the night's textures if `night` and the Sun is low enough for stars.
    // ponytail: each bake grows the whole canopy again (0.8 s, about 2 s of CPU across the cores, every five minutes
    // while the light changes) when only its light has; keep the grown layers between bakes (about 120 MB) if that
    // shows on the battery
    nonisolated static func bake(moment: Date, latitude: Double, longitude: Double, camera: Camera, seed: UInt64, light: Light?,
                                 night: Bool, shapes: Bool = false) -> Baked {
        let light = light ?? Light(camera: camera, date: moment, latitude: latitude, longitude: longitude)
        let made = CanopyBake(stand: resource(stand.name), leaves: resource("dappled-leaves.png"), perTan: stand.perTan,
                              extent: camera.extent, portrait: camera.portrait, sun: light.sun, sunlight: light.sunlight, zenith: light.zenith,
                              season: CanopySeason(date: moment, latitude: latitude), seed: seed).make()
        func texture(_ data: Data, _ width: Int, _ height: Int, _ filter: SKTextureFilteringMode = .linear) -> SKTexture {
            let texture = SKTexture(data: data, size: CGSize(width: width, height: height))
            texture.filteringMode = filter
            return texture
        }
        let dark = night && light.starlight > 0
        let textures = Textures(sky: texture(Data(light.sky), Light.width, Light.height), canopy: texture(made.canopy, made.width, made.height),
                                cover: texture(made.cover, made.coverWidth, made.coverHeight), sway: texture(made.sway, made.coverWidth, made.coverHeight),
                                near: texture(made.near, made.width, made.height),
                                stars: dark ? texture(Data(starGrid()), grid.width, grid.height, .nearest) : nil,
                                photo: dark ? SKTexture(image: NSImage(contentsOf: resource("sky-milky-way.heic")) ?? NSImage()) : nil,
                                leaves: shapes ? Leaves.shapes() : [])
        return Baked(moment: moment, light: light, made: made, textures: textures)
    }

    /// What a bake hands over, once. `waiting` holds the caller until it has: for the render tests, which draw their
    /// frames faster than a canopy is grown.
    private final class Job: Sendable {
        private let made = Mutex<Baked?>(nil), ready = DispatchSemaphore(value: 0)
        func arrive(_ thing: Baked) { made.withLock { $0 = thing }; ready.signal() }
        func take(waiting: Bool) -> Baked? {
            if waiting { ready.wait(); ready.signal() }
            return made.withLock { m in defer { m = nil }; return m }
        }
    }

    /// One whole picture: a sprite over the screen, with the sky, canopy and light of one bake and the night's stars.
    @MainActor private final class Picture {
        let sprite = SKSpriteNode(color: .white, size: .zero) // its alpha reaches the shader as v_color_mix.a
        private let sky = SKUniform(name: "u_sky", texture: Canopy.clear), canopy = SKUniform(name: "u_canopy", texture: Canopy.clear),
                    cover = SKUniform(name: "u_cover", texture: Canopy.clear), sway = SKUniform(name: "u_sway", texture: Canopy.clear),
                    near = SKUniform(name: "u_near", texture: Canopy.clear)
        private let sun = SKUniform(name: "u_sun", vectorFloat3: .zero), disc = SKUniform(name: "u_disc", vectorFloat3: .zero),
                    glow = SKUniform(name: "u_glow", vectorFloat3: .zero), stars = SKUniform(name: "u_night", float: 0)

        /// Its shader by day, and by night (with the stars), each sharing its uniforms.
        private let shaders: (day: SKShader, night: SKShader)

        init(camera: Camera, night: Night, motion: Motion) {
            let own = [sky, canopy, cover, sway, sun, disc, glow, near] + motion.uniforms
            shaders = (SKShader(source: camera.defines + Canopy.source(night: false), uniforms: own + [WallpaperTime.now]),
                       SKShader(source: camera.defines + Canopy.source(night: true), uniforms: own + [stars] + night.uniforms))
            sprite.shader = shaders.day
        }

        /// How strongly the stars show in it: 0 by day, 1 in the dark of night.
        var starlight: Float { stars.floatValue }

        /// A bake's light and textures; with no textures, the sky alone, made here, as the scene starts.
        func show(_ light: Light, _ textures: Textures?, sunShows: Double) {
            if let textures {
                (sky.textureValue, canopy.textureValue, cover.textureValue, sway.textureValue) = (textures.sky, textures.canopy, textures.cover, textures.sway)
                near.textureValue = textures.near
            } else {
                sky.textureValue = SKTexture(data: Data(light.sky), size: CGSize(width: Light.width, height: Light.height))
                sky.textureValue?.filteringMode = .linear
            }
            // the Sun, where it is up: a soft disc and a glow, as much as shows through the canopy where it stands
            let shows = light.sun.z > 0 ? sunShows : 0
            sun.vectorFloat3Value = SIMD3<Float>(Float(-light.sun.x), Float(light.sun.y), Float(light.sun.z))
            disc.vectorFloat3Value = SIMD3<Float>(light.sunlight * 4 * shows)
            glow.vectorFloat3Value = SIMD3<Float>(light.sunlight * 0.05 * shows)
            stars.floatValue = Float(light.starlight)
            let shader = light.starlight > 0 ? shaders.night : shaders.day
            if sprite.shader !== shader { sprite.shader = shader }
        }

        func clear() { for map in [sky, canopy, cover, sway, near] { map.textureValue = Canopy.clear } }
    }

    /// The motion's uniforms, shared by both pictures, set every frame from the breeze: step (b2)'s, from footage
    /// (docs/canopy/research-motion.md, Model 2): the wood still, the twigs and leaves rustling by how free they are,
    /// and the nearest leaves moving on their own over the rest. Its uniforms: the twigs' and leaves' rustle (`field`);
    /// the clock wrapped hourly, how far the crowns sway (px at 2x on a 14" screen) and how far the limbs are freed
    /// (`wind`); and how much the leaves' light flutters.
    @MainActor final class Motion {
        let wind = SKUniform(name: "u_wind", vectorFloat4: .zero), flutter = SKUniform(name: "u_flutter", float: 0)
        /// The rustle, a corner every 150 px of the stand (`Camera.field`), each moving on its own, in px at 2x on a 14"
        /// screen: the canopy's corners in the left half, the nearest leaves' in the right, each across in red and green
        /// and up in blue and alpha as 16 bits over ±64 px (high byte, low byte: a linear filter blends the two exactly,
        /// and SpriteKit read a half-float texture as bytes). The shader reads it once a pixel for each, blended smoothly
        /// between corners. Worked out here every frame, a few thousand sines: in the shader, at every pixel, it cost
        /// 2.5 ms of GPU a frame.
        let field: SKMutableTexture, cells: (x: Int, y: Int), fieldMap: SKUniform
        /// Each corner's four frequencies (Hz) and amplitudes, and its phases across and up, for the canopy and the nearest leaves.
        private let corners: [(f: SIMD4<Double>, amp: SIMD4<Double>, across: SIMD4<Double>, up: SIMD4<Double>)]
        private var texels: [UInt8]
        var uniforms: [SKUniform] { [fieldMap, wind, flutter] }

        /// Four sines on each axis at each corner, at random frequencies in 0.05-0.12, 0.13-0.3, 0.35-0.8 and 0.9-1.6
        /// Hz, amplitudes falling as f^-0.65, so about 82% of the displacement is below 0.5 Hz and 18% in 0.5-2 Hz,
        /// broadband with no common period (research-motion.md: 69-99% and 10-30% in a breeze); scaled so a field's
        /// RMS is about 0.74 of the reach.
        init(camera: Camera) {
            cells = camera.field
            field = SKMutableTexture(size: CGSize(width: cells.x * 2, height: cells.y))
            field.filteringMode = .linear
            fieldMap = SKUniform(name: "u_field", texture: field)
            texels = [UInt8](repeating: 128, count: cells.x * cells.y * 8)
            let (low, wide) = (SIMD4<Double>(0.05, 0.13, 0.35, 0.9), SIMD4<Double>(0.07, 0.17, 0.45, 0.7))
            corners = (0..<cells.x * cells.y * 2).map { _ in
                let f = low + wide * SIMD4((0..<4).map { _ in Double.random(in: 0..<1) })
                func phases() -> SIMD4<Double> { SIMD4((0..<4).map { _ in Double.random(in: 0..<2 * .pi) }) }
                return (f, SIMD4(f.indices.map { pow(f[$0], -0.65) / 6.17 }), phases(), phases())
            }
        }

        /// `fps`: the rate the view draws at; the flutter, at 1-3 Hz, fades out below 15 fps.
        func set(_ breeze: Breeze, at time: TimeInterval, fps: Int) {
            let u = breeze.wind(time), reach = Breeze.rustle(u), n = cells.x * cells.y
            for k in 0..<n * 2 { // the canopy's corners, then the nearest leaves', twice as far
                let c = corners[k], w = 2 * .pi * c.f * time
                var (x, y) = (0.0, 0.0)
                for i in 0..<4 { (x, y) = (x + c.amp[i] * sin(w[i] + c.across[i]), y + c.amp[i] * sin(w[i] + c.up[i])) }
                let i = k % n, r = reach * (k < n ? 1 : Breeze.nearer), at = ((i / cells.x) * cells.x * 2 + i % cells.x + (k < n ? 0 : cells.x)) * 4
                for (c, v) in [x * r, y * r].enumerated() {
                    let bits = UInt16(min(max((v + 64) / 128 * 65535, 0), 65535).rounded())
                    (texels[at + c * 2], texels[at + c * 2 + 1]) = (UInt8(bits >> 8), UInt8(bits & 255))
                }
            }
            texels.withUnsafeBytes { buffer in
                nonisolated(unsafe) let bytes = buffer // taken before modifyPixelData returns (Meander's send)
                field.modifyPixelData { data, length in data?.copyMemory(from: bytes.baseAddress!, byteCount: min(length, bytes.count)) }
            }
            wind.vectorFloat4Value = SIMD4(Float(time.truncatingRemainder(dividingBy: 3600)), 0, Float(Breeze.crowns(u)), Float(Breeze.limbsFree(u)))
            flutter.floatValue = Breeze.flicker * Float(simd_smoothstep(1.2, 2.6, u) * simd_smoothstep(10, 15, Double(fps)))
        }
    }

    /// Leaves falling, in the weeks they really fall: a few at once, more in a gust, each let go 7-9.5 m up and falling
    /// about 0.5 m/s with a falling leaf's swing, carried along by the breeze more than falling at the viewer,
    /// tumbling and turning over, and faded out before it comes nearer than 5.5 m. An 18 cm cell of the leaf scans
    /// (the leaf a little less), 14-25 points on a 14" screen, a little large for an oak's or a beech's: near, below the crowns, since 4-12 px leaves in the
    /// canopy's own bronze couldn't be seen (the round-1 film). Lit as a turned leaf with the light behind it. Plain sprites, their colour set as
    /// each is let go; only those in the air are posed, and none off the screen.
    @MainActor final class Leaves {
        static let pool = 12, across = 0.18, sink = 0.5
        let nodes: [SKSpriteNode]
        /// Each leaf in the air: when it was let go, where (metres across and up from straight overhead, and high),
        /// its own phase and spin.
        private var air: [(born: TimeInterval, at: SIMD2<Double>, high: Double, phase: Double, spin: Double)?]
        /// How many leaves fall at once on average, from the season (0 outside the weeks they fall), and their colours.
        private(set) var rate = 0.0
        private var tints: [SKColor] = [], last: TimeInterval?

        init() {
            nodes = (0..<Self.pool).map { _ in
                let node = SKSpriteNode(color: .white, size: CGSize(width: 1, height: 1)) // sized by its scale
                (node.colorBlendFactor, node.zPosition, node.isHidden) = (1, 2, true)
                return node
            }
            air = Array(repeating: nil, count: Self.pool)
        }

        /// The scans' oak and beech leaves, made off the main thread with a bake (the atlas's decode took 7 ms).
        nonisolated static func shapes() -> [SKTexture] {
            let atlas = NSImage(contentsOf: resource("dappled-leaves.png"))?.cgImage(forProposedRect: nil, context: nil, hints: nil)
            return (6..<16).compactMap { atlas?.cropping(to: CGRect(x: $0 % 4 * 256, y: $0 / 4 * 256, width: 256, height: 256)) }.map { SKTexture(cgImage: $0) }
        }

        /// Gives the leaves their shapes, the first time a bake brings them.
        func take(_ shapes: [SKTexture]) {
            guard nodes.first?.texture == nil, !shapes.isEmpty else { return }
            for (k, node) in nodes.enumerated() { node.texture = shapes[k % shapes.count] }
        }

        /// How many fall, from how fast the leaves are coming down this week (`CanopySeason`'s share down, a day either
        /// side): about one on the screen at a time as the colour starts, four as half come down, six in the last days;
        /// and their colour, from the light: a turned leaf, the Sun through it and the sky round it, as the canopy's are
        /// lit. None by night, when they couldn't be seen.
        func season(_ moment: Date, latitude: Double, light: Light) {
            let (a, b) = (CanopySeason(date: moment - 86_400, latitude: latitude), CanopySeason(date: moment + 86_400, latitude: latitude))
            let perDay = (b.fallen - a.fallen) / 2
            rate = light.sun.z > -0.03 && perDay > 0.001 ? min(4 * perDay / 0.03, 6) : 0
            let sun = SIMD3<Float>(light.sunlight) / .pi, sky = SIMD3<Float>(light.zenith)
            tints = [0x88743E, 0x9F894D, 0x9D9F40, 0xD29143, 0xB0743A].map { hex in
                let c = SIMD3<Float>(pow(Float(hex >> 16 & 255) / 255, 2.2), pow(Float(hex >> 8 & 255) / 255, 2.2), pow(Float(hex & 255) / 255, 2.2))
                let l = c / dot(c, SIMD3(0.2126, 0.7152, 0.0722)) * (sun * 0.7 + sky * 0.9) * 0.12
                let v = (SIMD3<Float>(repeating: 1) - exp(-l)).squareRoot() // the shader's tone curve
                return SKColor(red: CGFloat(v.x), green: CGFloat(v.y), blue: CGFloat(v.z), alpha: 1)
            }
        }

        /// How many are in the air.
        var falling: Int { air.reduce(0) { $0 + ($1 == nil ? 0 : 1) } }

        /// Lets go a leaf now and then, by the season's rate and the breeze's gusts, and poses those in the air.
        func step(_ time: TimeInterval, breeze: Breeze, camera: Camera, size: CGSize) {
            let dt = min(max(time - (last ?? time), 0), 0.5)
            last = time
            let strength = breeze.strength(time), wind = SIMD2(cos(breeze.heading), sin(breeze.heading)) * (0.3 + 0.9 * strength)
            // on average `rate` at once, each about 5.5 s in the air; three times as many at the top of a gust
            let gust = 0.4 + 2.6 * simd_smoothstep(0.6, 1, strength)
            if rate > 0, !tints.isEmpty, nodes.first?.texture != nil, Double.random(in: 0..<1) < rate * gust / 5.5 * dt, let free = air.firstIndex(where: { $0 == nil }) {
                let high = Double.random(in: 7...9.5)
                // somewhere over the screen, upwind of where it will drift to
                let spot = SIMD2(Double.random(in: -1...1) * camera.tan.x, Double.random(in: -1...1) * camera.tan.y) * high - wind * 3
                air[free] = (time, spot, high, .random(in: 0..<2 * .pi), .random(in: 0.5...1.2) * (Bool.random() ? 1 : -1))
                nodes[free].color = tints.randomElement()!
            }
            for k in air.indices {
                guard let leaf = air[k] else { continue }
                let age = time - leaf.born, node = nodes[k]
                // falling about 0.5 m/s, swinging as a falling leaf does, drifting with the breeze
                let high = leaf.high - Self.sink * age - 0.15 * sin(2.4 * age + leaf.phase)
                let at = leaf.at + wind * age + 0.3 * SIMD2(sin(1.3 * age + leaf.phase), cos(1.1 * age + leaf.phase))
                let fade = min(age / 1.5, 1) * simd_smoothstep(5.5, 6.5, high)
                let point = CGPoint(x: size.width / 2 + at.x / high * camera.scale, y: size.height / 2 + at.y / high * camera.scale)
                let side = Self.across / high * camera.scale
                guard fade > 0 || age < 1.5, point.x > -side, point.y > -side, point.x < size.width + side, point.y < size.height + side else {
                    air[k] = nil
                    node.isHidden = true
                    continue
                }
                node.isHidden = false
                node.position = point
                let turn = cos(1.6 * age + leaf.phase) // turning over, never quite edge on
                (node.xScale, node.yScale) = (side * (turn < 0 ? min(turn, -0.2) : max(turn, 0.2)), side)
                node.zRotation = leaf.spin * age + leaf.phase
                node.alpha = fade * 0.95
            }
        }
    }

    /// The breeze, until the live wind comes (step (d)): a heading from the seed, a mean wind (`canopy.wind`, m/s at
    /// 10 m, as Open-Meteo gives it; a breeze, Beaufort 3, unset), and a strength that swells and eases, 0.35 to 1,
    /// as gusts and lulls. It sets how far the twigs and leaves rustle, whether the limbs move and whether the
    /// crowns sway (research-motion.md, Settings it implies).
    struct Breeze {
        /// How much the leaves' light flickers, leaf by leaf, as they turn.
        static let flicker: Float = 0.2
        /// How far the twigs and leaves rustle at 4.3 m/s, and the crowns sway at 12 m/s, in px at 2x
        /// on a 14" screen (the shader's fields have an RMS of about 0.74 of it, research-motion's breeze an RMS drift
        /// of 2-4 px after 1 s).
        static let leafReach = 7.5, crownReach = 5.0
        /// How much further the nearest leaves move: nearer, and higher in the wind.
        static let nearer = 2.0
        let heading: Double, phases: [Double], mean: Double

        init(seed: UInt64, mean: Double = 4.3) {
            self.mean = mean
            var state = seed
            func next() -> Double { // SplitMix64's step, as the bake's
                state &+= 0x9E37_79B9_7F4A_7C15
                var z = (state ^ (state >> 30)) &* 0xBF58_476D_1CE4_E5B9
                z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
                return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
            }
            heading = next() * 2 * .pi
            phases = (0..<10).map { _ in next() * 2 * .pi } // the gusts' are the last two; the first eight were (b)'s sway's
        }

        /// How hard it blows at `time` (seconds), 0.35 to 1: a swell over about a minute and gusts over a quarter of one.
        func strength(_ time: TimeInterval) -> Double {
            min(max(0.62 + 0.22 * sin(2 * .pi * time / 61 + phases[8]) + 0.16 * sin(2 * .pi * time / 17 + phases[9]), 0.35), 1)
        }

        /// The wind at `time`, m/s: the mean, up to 1.6 times it in a gust and down to 0.56 in a lull, but never below
        /// `calm`.
        func wind(_ time: TimeInterval) -> Double { max(mean * strength(time) / 0.62, Self.calm) }

        /// The least wind it ever shows, m/s: Beaufort 2, "leaves rustle", so the canopy never looks still, whatever the
        /// wind, in still air and by night too (Dave, 2026-11-18: "just have there always be at least some subtle wind").
        static let calm = 2.0

        /// How far the twigs and leaves rustle in a wind of `u` m/s: growing as U^0.67, since a cherry tree's foliage
        /// moved "only by a factor of about 4" from 1 to 8 m/s (Tadrist et al. 2018 §3).
        static func rustle(_ u: Double) -> Double { leafReach * pow(max(u, 0) / 4.3, 0.67) }

        /// How far the crowns sway as bodies: not below Beaufort 5 (8.7 m/s, "small trees in leaf begin to sway"),
        /// then as U² (Jackson et al. 2021: deflection linear in the wind speed squared).
        static func crowns(_ u: Double) -> Double { crownReach * simd_smoothstep(8, 10.5, u) * (u / 12) * (u / 12) }

        /// How far the limbs are freed, 0 to 1: from Beaufort 4, "small branches moved".
        static func limbsFree(_ u: Double) -> Double { simd_smoothstep(5.5, 9, u) }

        /// The fastest thing moving, px a second at 2x on a 14" screen: the 95th percentile of the leaves' rustle (2
        /// times its reach a second, the field simulated), twice that for the nearest leaves, and the crowns' sway at
        /// 0.3 Hz.
        func fastest(_ time: TimeInterval) -> Double {
            let u = wind(time)
            return 2 * Self.rustle(u) * Self.nearer + 2.7 * Self.crowns(u)
        }
    }

    /// The night's textures, shared by both pictures and held only while one shows stars: Night Sky's photograph of
    /// the Milky Way and the stars' grid (`starGrid`), with the turns that take a direction through the lens to each.
    @MainActor private final class Night {
        let photo = SKUniform(name: "u_photo", texture: Canopy.clear), stars = SKUniform(name: "u_stars", texture: Canopy.clear)
        let toPhoto = SKUniform(name: "u_toPhoto", matrixFloat3x3: matrix_identity_float3x3)
        let toStars = SKUniform(name: "u_toStars", matrixFloat3x3: matrix_identity_float3x3)
        private(set) var held = false
        var uniforms: [SKUniform] { [photo, stars, toPhoto, toStars, WallpaperTime.now] }

        /// Takes the bake's, or the copies already shared (another display's, or Night Sky's photograph).
        func hold(_ grid: SKTexture, _ milkyWay: SKTexture) {
            stars.textureValue = sharedTexture("canopy-stars") { grid }
            photo.textureValue = sharedTexture("sky-milky-way.heic") { milkyWay }
            held = true
        }

        func release() { (photo.textureValue, stars.textureValue, held) = (Canopy.clear, Canopy.clear, false) }

        /// Turns both to the sky as it stands: the lens's directions (west, north, up) to the horizon's (east, north,
        /// up), back to J2000, and on to the photograph's frame and the stars'.
        func turn(_ toHorizon: simd_double3x3) {
            let toSky = toHorizon.transpose * simd_double3x3(diagonal: [-1, 1, 1])
            func float(_ m: simd_double3x3) -> simd_float3x3 {
                simd_float3x3(columns: (SIMD3<Float>(m.columns.0), SIMD3<Float>(m.columns.1), SIMD3<Float>(m.columns.2)))
            }
            toStars.matrixFloat3x3Value = float(NightSky.toStars * toSky)
            toPhoto.matrixFloat3x3Value = float(NightSky.toPhoto * toSky)
        }
    }

    /// The stars' grid: a row every half degree of latitude in the frame of Night Sky's fainter stars (`NightSky.toStars`),
    /// each with as many cells as keep them at least half a degree wide, so a star has a quarter of a degree (3.3 points
    /// at the middle of a 14" screen, more toward its edges) round it to shine in. A cell holds the brightest star in it: the Yale catalogue's
    /// to V 5.3 and the HYG database's from there to V 7, as Night Sky splits them. Its bytes are where in the cell the
    /// star sits (across, up), how bright it is (255 for V −1.5 down to 1 for V 7; 0 for no star) and its B−V (0 for
    /// −0.4 up to 255 for 2).
    // ponytail: a star that shares a cell with a brighter one is dropped, a few in a hundred and nearly all faint ones
    nonisolated static func starGrid() -> [UInt8] {
        let (w, h) = grid
        var cells = [UInt8](repeating: 0, count: w * h * 4)
        func add(_ round: Double, _ up: Double, _ magnitude: Double, _ colour: UInt8) {
            let y = min(max(up, 0) * Double(h), Double(h) - 0.001), across = Self.cells(row: y.rounded(.down))
            let x = min(max(round, 0) * across, across - 0.001)
            let at = (Int(y) * w + Int(x)) * 4, bright = UInt8(min(max((7 - magnitude) / 8.5 * 254 + 1, 1), 255))
            guard bright > cells[at + 2] else { return }
            cells[at..<at + 4] = [UInt8((x - x.rounded(.down)) * 256), UInt8((y - y.rounded(.down)) * 256), bright, colour]
        }
        for star in NightSky.catalogue where star.magnitude <= 5.3 {
            let s = NightSky.toStars * star.direction
            add(atan2(s.x, s.z) / (2 * .pi) + 0.5, asin(min(max(s.y, -1), 1)) / .pi + 0.5, star.magnitude,
                UInt8(min(max((star.bv + 0.4) / 2.4, 0), 1) * 255))
        }
        for star in NightSky.starFile() where star.magnitude > 5.3 && star.magnitude <= 7 {
            add(star.round, star.up, star.magnitude, star.colour)
        }
        return cells
    }

    nonisolated static let grid = (width: 720, height: 360)

    /// How many cells a row of the stars' grid holds: as many as keep them half a degree wide at its edge farther from
    /// the equator. The shader works out the same number; with 719.5 none of the 360 comes within a three-hundredth of
    /// a whole number, so the two can't disagree.
    nonisolated static func cells(row: Double) -> Double {
        max((719.5 * cos(min(abs(row - 179.5) + 0.5, 180) * .pi / 360)).rounded(.down), 1)
    }

    /// The shader, by day, or at `night` with the Milky Way and the stars in the gaps: two sources, so that the day's
    /// frame never pays for the night's (behind a branch on a uniform, it cost three times as much).
    static func source(night: Bool) -> String {
        shaderCommon + rustleSource + """
        float lumi(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
        void main() {
            vec2 uv = v_tex_coord;
            vec2 t = (uv * 2.0 - 1.0) * TAN;                 // tan units: x right (west), y up (north)
            vec2 q0 = t / (2.0 * EXTENT) + 0.5;              // the stand's picture
        \(motionSource)
            // the veil: by day, the sky in a gap paled toward silver near the leaves, as a bright gap in a crown looks
            float near = texture2D(u_cover, q).r;
            vec3 gap = mix(sky, vec3(0.86, 0.89, 0.97) * lumi(sky), 0.55 * smoothstep(0.08, 0.7, near)\(night ? " * (1.0 - u_night)" : ""));
            // the Sun: a soft disc where it shows, and a glow round it, no starburst
            vec3 d = normalize(vec3(t, 1.0));
            float ang = acos(clamp(dot(d, u_sun), -1.0, 1.0));
            gap += u_disc * (1.0 - smoothstep(0.004, 0.006, ang)) + u_glow * exp(-ang / 0.05);
        \(night ? Self.nightSource : "")
            vec3 col = gap * (1.0 - a) + canopy + u_glow * 0.25 * exp(-ang / 0.2);
            col = min(sqrt(1.0 - exp(-col)), vec3(240.0 / 255.0)); // Weather's film-like roll-off, roughly sRGB
            gl_FragColor = vec4(col + (fract(sin(dot(gl_FragCoord.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0, 1.0)
                * v_color_mix.a;
        }
        """
    }

    /// The motion (docs/canopy/research-motion.md, Model 2): the wood still, and each point free to move as far as the
    /// freedom map says (`CanopyBake.freedom`), by a field of its own about a spray and its twig across; in a strong
    /// wind the limbs freed too and the crowns swaying as bodies; the leaves' light flickering leaf by leaf. The nearest
    /// leaves are a picture of their own, moved twice as far by a field of their own over the rest, so gaps open and
    /// close inside the crowns and the leaves in front change.
    private static let motionSource = """
        vec2 p = q0 * STAND;                             // stand px, as px at 2x on a 14" screen
        vec4 loose = texture2D(u_sway, q0);              // how free: the twigs (r), with the limbs (g); along the trees (b)
        float m = mix(loose.r, loose.g, u_wind.w);
        vec2 crowns = loose.b * u_wind.z * sway(p / 700.0, u_wind.x);
        vec2 fc = p / 150.0, fi = floor(fc), ff = fract(fc);
        fc = fi + ff * ff * (3.0 - 2.0 * ff) + 0.5;              // the corners blended smoothly, by the filter
        vec4 rustle = texture2D(u_field, fc / vec2(2.0 * FIELD.x, FIELD.y));
        vec2 q = q0 - (m * ((rustle.xz * 65280.0 + rustle.yw * 255.0) / 512.0 - 64.0) + crowns) / STAND;
        vec3 sky = texture2D(u_sky, uv).rgb;
        sky = sky * sky * 4.0;
        vec4 c = texture2D(u_canopy, q);
        vec3 canopy = c.rgb * c.rgb * 2.0 * (1.0 + u_flutter * m * flutter(q * STAND / 14.0, u_wind.x));
        float a = c.a;
        // the nearest leaves, on twigs that move even by a limb, over the rest
        float mn = max(m, 0.5);
        vec4 nr = texture2D(u_field, (fc + vec2(FIELD.x, 0.0)) / vec2(2.0 * FIELD.x, FIELD.y));
        vec2 qn = q0 - (mn * ((nr.xz * 65280.0 + nr.yw * 255.0) / 512.0 - 64.0) + crowns) / STAND;
        vec4 n = texture2D(u_near, qn);
        canopy = n.rgb * n.rgb * 2.0 * (1.0 + u_flutter * mn * flutter(qn * STAND / 14.0 + 0.5, u_wind.x)) + canopy * (1.0 - n.a);
        a = n.a + a * (1.0 - n.a);
    """

    /// The fields the motion moves by besides the rustle (`Motion.field`), each on a grid whose corners move on
    /// their own and blend smoothly between, on the clock wrapped hourly with every frequency a whole number of cycles
    /// an hour, so the wrap can't be seen:
    /// - `sway`, the crowns as bodies in a strong wind, cells of 700 px, a sine on each axis at 0.15-0.3 Hz;
    /// - `flutter`, the leaves' light, cells of 14 px (a leaf), each at 1-3 Hz.
    private static let rustleSource = """
        vec2 swayAt(vec2 i, float now) {
            vec4 h = hash42(i + 91.0);
            return sin(6.2831853 * (fract(floor((0.15 + 0.15 * h.xy) * 3600.0) / 3600.0 * now) + h.zw));
        }
        vec2 sway(vec2 c, float now) {
            vec2 i = floor(c), f = fract(c);
            f = f * f * (3.0 - 2.0 * f);
            return mix(mix(swayAt(i, now), swayAt(i + vec2(1.0, 0.0), now), f.x), mix(swayAt(i + vec2(0.0, 1.0), now), swayAt(i + vec2(1.0, 1.0), now), f.x), f.y);
        }
        float flick(vec2 i, float now) {
            vec4 h = hash42(i + 13.0);
            return sin(6.2831853 * (fract(floor((1.0 + 2.0 * h.x) * 3600.0) / 3600.0 * now) + h.y));
        }
        float flutter(vec2 c, float now) {
            vec2 i = floor(c), f = fract(c);
            f = f * f * (3.0 - 2.0 * f);
            return mix(mix(flick(i, now), flick(i + vec2(1.0, 0.0), now), f.x), mix(flick(i + vec2(0.0, 1.0), now), flick(i + vec2(1.0, 1.0), now), f.x), f.y);
        }

    """

    /// The night's part of the shader: the Milky Way and the stars added to the sky in the gaps.
    private static let nightSource = """
        // the Milky Way, Night Sky's photograph with its own stars taken out, as it shows with the Sun well down
        // (the least of four reads round the pixel, which takes out the few bright stars the photograph keeps:
        // drawn beside ours, a tenth of a degree off, they looked like tails)
        vec3 g = u_toPhoto * d;
        vec2 at = vec2(0.5 - atan(g.y, g.x) / 6.2831853, 0.5 + asin(clamp(g.z, -1.0, 1.0)) / 3.1415927);
        vec2 e = vec2(2.5 / 6000.0, 2.5 / 3000.0);
        vec3 photo = min(min(texture2D(u_photo, at + e).rgb, texture2D(u_photo, at - e).rgb),
                         min(texture2D(u_photo, at + vec2(e.x, -e.y)).rgb, texture2D(u_photo, at - vec2(e.x, -e.y)).rgb));
        vec3 shine = (1.0 - exp(-1.5 * max(photo - 0.05, 0.0))) * MILKY * u_night;
        // the stars: any near enough to light this pixel is in one of the two cells nearest it in each of the two
        // rows nearest it, a quarter of a degree round it (`room`, in points); each drawn round on the screen
        // where its own direction lands
        float room = 0.0043 * SCALE;
        vec3 s = u_toStars * d;
        float round = atan(s.x, s.z) / 6.2831853 + 0.5;
        float row = (asin(clamp(s.y, -1.0, 1.0)) / 3.1415927 + 0.5) * 360.0;
        for (int k = 0; k < 4; k++) {
            float r = clamp(floor(row - 0.5) + floor(float(k) / 2.0), 0.0, 359.0);
            float across = max(floor(719.5 * cos(min(abs(r - 179.5) + 0.5, 180.0) * 0.0087266463)), 1.0);
            float cell = mod(floor(round * across - 0.5) + mod(float(k), 2.0), across);
            vec4 star = texture2D(u_stars, (vec2(cell, r) + 0.5) / vec2(720.0, 360.0));
            if (star.b > 0.0) {
                float lon = ((cell + (star.r * 255.0 + 0.5) / 256.0) / across - 0.5) * 6.2831853;
                float lat = ((r + (star.g * 255.0 + 0.5) / 256.0) / 360.0 - 0.5) * 3.1415927;
                vec3 w = vec3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon)) * u_toStars;
                float off = length(w.xy / w.z - t) * SCALE;               // points on the screen
                float m = 7.0 - (star.b * 255.0 - 1.0) / 254.0 * 8.5;    // its magnitude
                float bv = star.a * 2.4 - 0.4;
                vec3 hue = mix(mix(vec3(0.72, 0.8, 1.0), vec3(1.0, 0.97, 0.92), smoothstep(-0.2, 0.5, bv)),
                               vec3(1.0, 0.8, 0.6), smoothstep(0.6, 1.6, bv));
                float size = clamp(1.0 - 0.1 * m, 0.45, 1.0);
                float h = fract(star.r * 13.7 + star.g * 7.3);
                float twinkle = 0.8 + 0.2 * sin(mod(u_now, 3600.0) * (1.0 + 3.0 * h) + h * 50.0); // hourly: a jump in a twinkle can't be seen
                float halo = 0.25 * smoothstep(3.5, 0.0, m) * exp(-off / 1.3);
                shine += hue * clamp(1.15 - 0.13 * m, 0.15, 0.75) * (exp(-off * off / (2.0 * size * size)) + halo)
                    * smoothstep(room, 0.67 * room, off) * twinkle * u_night;
            }
        }
        vec3 v = min(shine, 0.97);
        gap += -log(1.0 - v * v);                      // so that it shows at about `shine` once tone-mapped
    """
}

extension Canopy {
    typealias V3 = SIMD3<Double>

    /// The lens: a pinhole straight up, 90° across the long side, head to the north (screen right is west). For a
    /// portrait screen the stand is turned a quarter, so its long side runs up the screen.
    struct Camera: Sendable {
        var tan: SIMD2<Double>, extent: SIMD2<Double>, portrait: Bool
        /// Points on the screen to a unit of tan.
        var scale: Double
        /// The rustle's corners across and up the stand (`Motion.field`), one every 150 px, and one past each end.
        var field: (x: Int, y: Int) { (Int(stand.perTan * 2 * extent.x / 150) + 2, Int(stand.perTan * 2 * extent.y / 150) + 2) }
        init(size: CGSize) {
            portrait = size.height > size.width
            let long = Double(max(size.width, size.height))
            tan = [Double(size.width) / long, Double(size.height) / long]
            extent = portrait ? [stand.extent.y, stand.extent.x] : stand.extent
            scale = long / 2
        }
        /// The direction (east, north, up) through a point of the screen, 0…1 each way, y up.
        func ray(_ u: Double, _ v: Double) -> V3 { normalize(V3(-(u * 2 - 1) * tan.x, (v * 2 - 1) * tan.y, 1)) }

        /// The lens as the shader takes it, and how bright the Milky Way is drawn.
        var defines: String {
            """
            #define TAN vec2(\(tan.x), \(tan.y))
            #define EXTENT vec2(\(extent.x), \(extent.y))
            #define SCALE \(scale)
            #define STAND vec2(\(stand.perTan * 2 * extent.x), \(stand.perTan * 2 * extent.y))
            #define FIELD vec2(\(field.x).0, \(field.y).0)
            #define MILKY 0.5

            """
        }
    }

    /// The light at one moment: the sky as a small picture (stored as sqrt(v / 4), 128 × 96), and the Sun's light and
    /// the zenith's, all times the exposure, which holds the zenith's brightest channel at about 175 of 255 by day and
    /// lets it go dark at night as Weather's does.
    struct Light: Sendable {
        static let width = 128, height = 96
        var sky: [UInt8], sun: V3, sunlight: V3, zenith: V3

        /// How strongly the stars show: from none with the Sun 4° down to all of them at 14.5°, as in Weather.
        var starlight: Double { simd_smoothstep(-0.07, -0.25, sun.z) }

        init(camera: Camera, date: Date, latitude: Double, longitude: Double) {
            let air = Atmosphere.shared, jd = Sky.julianDate(date)
            let sun = normalize(Sky.horizonMatrix(jd: jd, latitude: latitude, longitude: longitude) * Sky.sun(jd))
            // a floor of airglow and starlight, so a moonless night is the deep blue of Night Sky's, not black
            let glow = V3(0.06, 0.25, 1.3) * 5e-8, balance = Self.balance(sun.z)
            let zenith = air.march(h0: 0.3, dir: V3(0, 0, 1), lights: [(sun, 1)]).light, up = zenith + glow
            let luminance = dot(up, V3(0.2126, 0.7152, 0.0722)) + 2e-7
            let night = min(max((-0.03 - sun.z) / 0.17, 0), 1)
            let exposure = min(0.62 / (up.max() + 2e-7), 0.7 * pow(luminance, -0.88) * pow(0.05, -0.12) * (1 - 0.5 * night))
            var pixels = [UInt8](repeating: 255, count: Self.width * Self.height * 4)
            pixels.withUnsafeMutableBufferPointer { buffer in
                nonisolated(unsafe) let buffer = buffer // each row writes only its own pixels
                DispatchQueue.concurrentPerform(iterations: Self.height) { j in
                    for i in 0..<Self.width {
                        let d = camera.ray((Double(i) + 0.5) / Double(Self.width), (Double(j) + 0.5) / Double(Self.height))
                        let l = (air.march(h0: 0.3, dir: d, lights: [(sun, 1)]).light * balance + glow) * exposure
                        for c in 0..<3 { buffer[(j * Self.width + i) * 4 + c] = UInt8(min(sqrt(max(l[c], 0) / 4), 1) * 255) }
                    }
                }
            }
            (sky, self.sun, sunlight, self.zenith) = (pixels, sun, air.sunlight(0.3, sun.z) * balance * exposure, (zenith * balance + glow) * exposure)
        }

        /// A camera's white balance for the Sun's height `z` (its sine): none by day, and from the Sun on the horizon
        /// to 4° down, red cut to 0.16 and green to 0.7. With only three wavelengths the physical sky's zenith turns
        /// violet in the blue hour, (107, 93, 151) with the Sun 6° down, where photos show a deep blue (research-look.md
        /// §2's Blue hour, hues 208-228°). Murmuration's `evenings` met the same. Applied to the sunlit sky and the
        /// light it gives the leaves, after the exposure is set, so only the hue changes; not to the night's floor of
        /// airglow, already tuned blue.
        static func balance(_ z: Double) -> V3 { V3(1, 1, 1) + (V3(0.16, 0.7, 1) - V3(1, 1, 1)) * simd_smoothstep(0, -0.07, z) }
    }
}

extension CanopySeason {
    /// The season at `date` where you are, from white oak's calendar moved to the latitude (`Phenology`). The same
    /// order runs through it all, so the leaves that turn first fall first.
    init(date: Date, latitude: Double) {
        self.init()
        let c = Phenology.whiteOak.moved(latitude: latitude, warmer: 0), d = Phenology.day(date, latitude: latitude)
        func ramp(_ a: Double, _ b: Double) -> Double { min(max((d - a) / (b - a), 0), 1) }
        if d < 200 {
            out = ramp(c.breaks, c.full)
            size = 0.55 + 0.45 * ramp(c.breaks, c.full)
            pale = 1 - ramp(c.full - 10, c.full + 20)
        } else {
            turned = simd_smoothstep(c.onset - 6, c.peak, d)
            fallen = d < c.peak ? 0.15 * ramp(c.onset, c.peak) : d < c.half ? 0.15 + 0.35 * ramp(c.peak, c.half) : 0.5 + 0.5 * ramp(c.half, c.bare)
        }
    }
}
