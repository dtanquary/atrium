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
final class Canopy: SKScene {
    /// For pictures: a seed for the stand's mirroring and its leaves (unset or 0 for a new one each load), a day
    /// (`yyyy-MM-dd`) and an hour of the local clock (13.5 for half past one), each unset for now.
    static let pins = (seed: "canopy.seed", date: "canopy.date", hour: "canopy.hour")
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
    /// The sway, shared by both pictures: each group of trees' offset, two to a uniform, and the limbs' and the
    /// leaves' flutter (`Breeze`), set every frame.
    private let breeze: Breeze, motion: Motion
    private var job: Job?, fading: (start: TimeInterval, length: TimeInterval)?, ticked: TimeInterval = -.infinity
    /// The moment the latest bake shows, and the Sun's height then; whether the canopy has landed yet.
    private var shown: (moment: Date, sun: Double), landed = false

    /// `place` holds one for the tests; the scene follows `Location` without it.
    init(size: CGSize, place: CLLocationCoordinate2D? = nil) {
        let defaults = UserDefaults.standard, here = place ?? Location.shared.coordinate
        var seed = UInt64(max(defaults.integer(forKey: Self.pins.seed), 0))
        if seed == 0 { seed = .random(in: 1...UInt64(UInt32.max)) }
        let moment = Self.moment(day: defaults.string(forKey: Self.pins.date), hour: defaults.object(forKey: Self.pins.hour) as? Double)
        let camera = Camera(size: size), night = Night(), motion = Motion()
        let light = Light(camera: camera, date: moment, latitude: here.latitude, longitude: here.longitude)
        (lens, self.seed, self.place, self.night, shown) = (camera, seed, place, night, (moment, light.sun.z))
        (breeze, self.motion) = (Breeze(seed: seed), motion)
        (front, back) = (Picture(camera: camera, night: night, motion: motion), Picture(camera: camera, night: night, motion: motion))
        super.init(size: size)

        backgroundColor = .black
        for picture in [front, back] {
            picture.sprite.size = size
            picture.sprite.anchorPoint = .zero
            addChild(picture.sprite)
        }
        back.sprite.isHidden = true
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
        motion.set(breeze, at: currentTime, camera: lens)
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
        let job = Job(), (camera, seed, here, dark) = (lens, seed, here, !night.held)
        self.job = job
        Task.detached(priority: priority) {
            job.arrive(Self.bake(moment: moment, latitude: here.latitude, longitude: here.longitude, camera: camera, seed: seed,
                                 light: light, night: dark))
        }
    }

    /// Lays a bake in the picture behind and starts it fading in.
    private func land(_ baked: Baked, at time: TimeInterval) {
        if let stars = baked.textures.stars, let photo = baked.textures.photo { night.hold(stars, photo) }
        if night.held {
            night.turn(Sky.horizonMatrix(jd: Sky.julianDate(baked.moment), latitude: here.latitude, longitude: here.longitude))
        }
        back.show(baked.light, baked.textures, sunShows: baked.made.sunShows)
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

    /// A bake's textures: the sky, the canopy and its cover, and the night's if they were asked for and it is night,
    /// the stars' grid and Night Sky's photograph of the Milky Way (a 6000 × 3000 HEIC, 160 ms to decode).
    struct Textures: @unchecked Sendable { // made off the main thread, then only handed over
        let sky: SKTexture, canopy: SKTexture, cover: SKTexture, sway: SKTexture, stars: SKTexture?, photo: SKTexture?
    }

    /// Everything about one moment that takes time, off the main thread: the light (unless given), the canopy grown
    /// and lit by it for the season then, and the night's textures if `night` and the Sun is low enough for stars.
    // ponytail: each bake grows the whole canopy again (0.8 s, about 2 s of CPU across the cores, every five minutes
    // while the light changes) when only its light has; keep the grown layers between bakes (about 120 MB) if that
    // shows on the battery
    nonisolated static func bake(moment: Date, latitude: Double, longitude: Double, camera: Camera, seed: UInt64, light: Light?,
                                 night: Bool) -> Baked {
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
                                stars: dark ? texture(Data(starGrid()), grid.width, grid.height, .nearest) : nil,
                                photo: dark ? SKTexture(image: NSImage(contentsOf: resource("sky-milky-way.heic")) ?? NSImage()) : nil)
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
                    cover = SKUniform(name: "u_cover", texture: Canopy.clear), sway = SKUniform(name: "u_sway", texture: Canopy.clear)
        private let sun = SKUniform(name: "u_sun", vectorFloat3: .zero), disc = SKUniform(name: "u_disc", vectorFloat3: .zero),
                    glow = SKUniform(name: "u_glow", vectorFloat3: .zero), stars = SKUniform(name: "u_night", float: 0)

        /// Its shader by day, and by night (with the stars), each sharing its uniforms.
        private let shaders: (day: SKShader, night: SKShader)

        init(camera: Camera, night: Night, motion: Motion) {
            let own = [sky, canopy, cover, sway, sun, disc, glow] + motion.uniforms
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

        func clear() { for map in [sky, canopy, cover, sway] { map.textureValue = Canopy.clear } }
    }

    /// The sway's uniforms, shared by both pictures, set every frame from the breeze: each group of trees' offset in the
    /// stand's picture (two groups to a uniform), and the limbs' phases, their reach and the leaves' flutter.
    @MainActor final class Motion {
        let a = SKUniform(name: "u_swayA", vectorFloat4: .zero), b = SKUniform(name: "u_swayB", vectorFloat4: .zero)
        let limb = SKUniform(name: "u_limb", vectorFloat4: .zero)
        var uniforms: [SKUniform] { [a, b, limb] }

        func set(_ breeze: Breeze, at time: TimeInterval, camera: Camera) {
            let o = breeze.offsets(time), strength = Float(breeze.strength(time))
            let per = SIMD2<Double>(1, 1) / (stand.perTan * 2 * camera.extent) // a pixel (at 2x on a 14" screen) in the picture
            func pair(_ k: Int) -> (Float, Float, Float, Float) {
                (Float(o[k].x * per.x), Float(o[k].y * per.y), Float(o[k + 1].x * per.x), Float(o[k + 1].y * per.y))
            }
            let (p, q) = (pair(0), pair(2))
            a.vectorFloat4Value = SIMD4(p.0, p.1, p.2, p.3)
            b.vectorFloat4Value = SIMD4(q.0, q.1, q.2, q.3)
            limb.vectorFloat4Value = SIMD4(Float((2 * .pi * 0.47 * time).truncatingRemainder(dividingBy: 2 * .pi)),
                                           Float((2 * .pi * 0.53 * time).truncatingRemainder(dividingBy: 2 * .pi)),
                                           Float(Breeze.limbs * per.x) * strength, Breeze.flutter * strength)
        }
    }

    /// The breeze, until the live wind comes (step (d)): a heading from the seed, and a strength that swells and
    /// eases, 0.35 to 1, under which each of the four groups of trees sways at its own pace in 0.17-0.33 Hz (the
    /// in-leaf range, research-method.md §2), mostly along the wind and a little across it.
    struct Breeze {
        /// How far the crowns sway at full strength, and their limbs on their own, in pixels at 2x on a 14" screen;
        /// and how much the leaves' light flutters.
        static let reach = 18.0, limbs = 2.0, flutter: Float = 0.12
        static let along = [0.17, 0.21, 0.25, 0.29], across = [0.19, 0.24, 0.28, 0.33]
        let heading: Double, phases: [Double]

        init(seed: UInt64) {
            var state = seed
            func next() -> Double { // SplitMix64's step, as the bake's
                state &+= 0x9E37_79B9_7F4A_7C15
                var z = (state ^ (state >> 30)) &* 0xBF58_476D_1CE4_E5B9
                z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
                return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
            }
            heading = next() * 2 * .pi
            phases = (0..<10).map { _ in next() * 2 * .pi }
        }

        /// How hard it blows at `time` (seconds), 0.35 to 1: a swell over about a minute and gusts over a quarter of one.
        func strength(_ time: TimeInterval) -> Double {
            min(max(0.62 + 0.22 * sin(2 * .pi * time / 61 + phases[8]) + 0.16 * sin(2 * .pi * time / 17 + phases[9]), 0.35), 1)
        }

        /// Each group's offset at `time`, in pixels at 2x on a 14" screen (x right, y up).
        func offsets(_ time: TimeInterval) -> [SIMD2<Double>] {
            let reach = Self.reach * strength(time), (c, s) = (cos(heading), sin(heading))
            return (0..<4).map { k in
                let along = sin(2 * .pi * Self.along[k] * time + phases[k]), across = 0.35 * sin(2 * .pi * Self.across[k] * time + phases[k + 4])
                return SIMD2(along * c - across * s, along * s + across * c) * reach
            }
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
        """
        float lumi(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
        void main() {
            vec2 uv = v_tex_coord;
            vec2 t = (uv * 2.0 - 1.0) * TAN;                 // tan units: x right (west), y up (north)
            vec2 q0 = t / (2.0 * EXTENT) + 0.5;              // the stand's picture
            // the sway: each point moves with its group of trees by its share of each (u_sway), so the crowns move as
            // bodies and the trunks bend, and with its limbs a little on their own
            vec4 tree = texture2D(u_sway, q0);
            vec2 q = q0 - tree.x * u_swayA.xy - tree.y * u_swayA.zw - tree.z * u_swayB.xy - tree.w * u_swayB.zw
                - (tree.x + tree.y + tree.z + tree.w) * u_limb.z * vec2(sin(u_limb.x + dot(q0, vec2(23.0, 9.0))), sin(u_limb.y + dot(q0, vec2(-8.0, 19.0))));
            vec3 sky = texture2D(u_sky, uv).rgb;
            sky = sky * sky * 4.0;
            vec4 c = texture2D(u_canopy, q);
            vec3 canopy = c.rgb * c.rgb * 2.0;
            float a = c.a;
            // the flutter: leaves turning in the breeze catch the light and lose it, patch by patch, each about a spray
            // across (a change of light, not of place)
            vec2 fc = q * STAND / 24.0, fi = floor(fc), ff = fract(fc);
            ff = ff * ff * (3.0 - 2.0 * ff);
            vec4 hh = fract(sin(vec4(dot(fi, vec2(127.1, 311.7)), dot(fi + vec2(1.0, 0.0), vec2(127.1, 311.7)),
                                     dot(fi + vec2(0.0, 1.0), vec2(127.1, 311.7)), dot(fi + vec2(1.0, 1.0), vec2(127.1, 311.7)))) * 43758.5453);
            vec4 fl = sin(mod(u_now, 3600.0) * (4.0 + 5.0 * hh) + 37.0 * hh); // hourly: a jump in a flutter can't be seen
            canopy *= 1.0 + u_limb.w * mix(mix(fl.x, fl.y, ff.x), mix(fl.z, fl.w, ff.x), ff.y);
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
