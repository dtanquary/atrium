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
/// it, which is all the smooth long-exposure sea can show. `perch` is where the flock goes down to roost at the end of
/// an evening (metres, from the eye): among the pier's legs, or into the reeds on the far shore.
/// - Brighton's West Pier: "Tide bears the last glow - Brighton, UK" by sagesolar, CC BY 4.0,
///   https://commons.wikimedia.org/wiki/File:Tide_bears_the_last_glow_-_Brighton,_UK.jpg
/// - A marsh pond: "Sunset over a tundra pond" by USFWS Alaska, public domain,
///   https://commons.wikimedia.org/wiki/File:Sunset_over_a_tundra_pond_(53708107535).jpg
private let grounds: [(name: String, file: String, horizon: Float, sky: Float, rough: Float, waves: SIMD3<Float>, perch: SIMD3<Float>)] = [
    ("Brighton West Pier", "murmuration-pier", 780.0 / 1533, 0.1252, 0.12, [0.03, 2.5, 0.22], [-26, 265, 8]),
    ("Marsh pond", "murmuration-marsh", 15.0 / 706, 0.2635, 0.005, [0.05, 3.5, 0.12], [30, 420, -1]),
]

private let lightKnob = Knob(key: "murmuration.light", label: "Light", range: 0...5, standard: 0, section: "Scene",
                             format: .choice(["Whole evening", "Random"] + evenings.map(\.name)))
private let lengthKnob = Knob(key: "murmuration.length", label: "Each evening lasts", range: 10...60, standard: 30,
                              section: "Scene", format: .minutes)
private let groundKnob = Knob(key: "murmuration.ground", label: "Ground", range: 0...1, standard: 0, section: "Scene",
                              format: .choice(grounds.map(\.name)))
private let falconKnob = Knob(key: "murmuration.falcon", label: "Falcon attacks", range: 0...1, standard: 1, section: "Flock", format: .toggle)
let murmurationKnobs = [lightKnob, lengthKnob, groundKnob, falconKnob]

/// One moment's light: the baked sky, and what the ground, the water and the birds take from it.
private struct Light: Sendable {
    var sky: SkyLight
    var balance: SIMD3<Float>          // the white balance for the Sun's height (see `evenings`)
    var sun: SIMD3<Float>, disc: SIMD3<Float>
    var horizon: SIMD3<Float>          // the sky's light just above the horizon, which lights the land
    var ink: SIMD3<Float>              // the birds' colour: the sky behind the flock, darkened
}

/// A starling murmuration at sunset, seen from the shore: a physical sky, a real photo of Brighton's West Pier or a
/// marsh pond with its water reflecting that sky and the flock, and a flock simulated in metres with banked turns, so
/// it folds into dark bands and opens into pale sheets as it wheels. With Light on Whole evening it plays out a whole
/// evening: feeder flocks arrive and merge, the light sinks from golden hour to blue hour, the swoops get lower, the
/// flock pours down to roost, and after a quiet spell a new evening fades in.
final class Murmuration: SKScene {
    private var flock: Flock?
    private var lastTime: TimeInterval?
    private var built = (light: -1.0, ground: -1.0)

    // The sky, crossfading from one bake to the next, and the uniforms that follow it.
    private let before = SKUniform(name: "u_before", texture: nil), after = SKUniform(name: "u_after", texture: nil)
    private let blend = SKUniform(name: "u_blend", float: 1), balance = SKUniform(name: "u_balance", vectorFloat3: .one)
    private let sun = SKUniform(name: "u_sun", vectorFloat3: .zero), disc = SKUniform(name: "u_disc", vectorFloat3: .zero)
    private let land = SKUniform(name: "u_land", vectorFloat3: .zero)
    private var eye = SkyCamera(aspect: 1.6, horizon: 0.3, facing: 0)
    private var shown: Light?, fade: (from: Light, to: Light, start: Double, seconds: Double)?
    private var groundSky: Float = 1, clock = 0.0, baking = false, lastBake = 0.0, lastInk = 0.0

    /// Where the evening is (seconds into it, of how long), while it plays out; nil for a fixed light.
    private var evening: (at: Double, length: Double)?
    private var arrivals: [(at: Double, count: Int)] = []

    override func sceneDidLoad() {
        build()
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged),
                                               name: UserDefaults.didChangeNotification, object: nil)
    }

    /// The light and the ground rebuild the scene; the evening's length and the falcon switch are read as it runs.
    @objc private func settingsChanged() {
        if built != (lightKnob.value, groundKnob.value) { build() }
        if evening != nil { evening?.length = lengthKnob.value * 60 }
    }

    private func build() {
        removeAllChildren()
        flock = nil
        fade = nil
        built = (lightKnob.value, groundKnob.value)
        let ground = grounds[min(Int(built.ground), grounds.count - 1)]
        let photo = Self.photo(ground.file)
        // The photo spans the screen's width, standing on its bottom edge; its horizon sets the view's.
        let photoSize = photo.texture.size(), height = size.width * photoSize.height / max(photoSize.width, 1)
        let view = GroundView(size: size, horizon: Float(height / size.height) * (1 - ground.horizon))
        groundSky = ground.sky

        // Face 10° left of where the Sun sets, so it goes down right of centre.
        let setting = Self.sunDirection(at: Self.date(sunAt: 0))
        eye = SkyCamera(aspect: size.width / size.height, horizon: Double(view.horizon), facing: atan2(setting.x, setting.y) - 0.17)
        eye.height = 0.01

        // Whole evening starts somewhere in the middle of the display, so the sky is never empty on load.
        let pick = Int(built.light)
        let elevation: Double
        if pick == 0 {
            let length = lengthKnob.value * 60
            let start = Double(ProcessInfo.processInfo.environment["MURMURATION_EVENING"] ?? "") ?? .random(in: 0.12...0.7)
            evening = (start * length, length)
            elevation = Self.sunHeight(start)
        } else {
            evening = nil
            elevation = pick == 1 ? evenings.randomElement()!.sun : evenings[pick - 2].sun
        }
        arrivals = []
        show(Self.light(camera: eye, elevation: elevation, horizon: view.horizon), fade: 0)
        lastBake = clock

        addSky()
        let birds = Flock(view: view, ink: color(shown!.ink), perch: ground.perch)
        addChild(birds)
        flock = birds

        let land = SKSpriteNode(texture: photo.texture, size: CGSize(width: size.width, height: height))
        land.anchorPoint = .zero
        land.zPosition = 3
        land.shader = SKShader(source: shaderCommon + Self.groundShader, uniforms: [
            SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)]),
            SKUniform(name: "u_frame", float: Float(height / size.height)),
            SKUniform(name: "u_aux", texture: photo.aux), before, after, blend,
            SKUniform(name: "u_cam", vectorFloat4: lens), balance, self.land,
            SKUniform(name: "u_birds", texture: birds.reflection),
            SKUniform(name: "u_rough", float: ground.rough),
            SKUniform(name: "u_noise", texture: CloudNoise.texture), SKUniform(name: "u_waves", vectorFloat3: ground.waves),
        ])
        addChild(land)
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = frameTime(currentTime, &lastTime)
        clock += dt
        if var e = evening, let flock {
            e.at += dt
            let phase = e.at / e.length
            if phase >= 1 {
                // A new evening: the light dissolves back to golden hour over 40 s, then the feeders start arriving.
                e.at = 0
                flock.clearSky()
                arrivals = Self.schedule()
                bake(at: Self.sunHeight(0), fade: 40)
            } else {
                // The light sinks with the evening, baked every 20 s off the main thread and faded between bakes.
                if !baking && clock - lastBake >= 20 { bake(at: Self.sunHeight(phase), fade: 20) }
                while let next = arrivals.first, e.at >= next.at {
                    flock.arrive(next.count)
                    arrivals.removeFirst()
                }
                // As the light fails the swoops get lower, over the water; then the flock goes down to roost.
                flock.dip = Float(25 * min(max((phase - 0.72) / 0.14, 0), 1))
                flock.roosting = phase > 0.86
                flock.roostRate = Float(1500 / (0.08 * e.length))
            }
            evening = e
        }
        applyFade()
        flock?.step(Float(dt))
    }

    // MARK: - The light

    /// The Sun's height in degrees `phase` of the way through the evening: from golden hour, 4° up, to blue hour, 4.5°
    /// down, about the last half hour of a real display and the first twenty minutes after sunset.
    private static func sunHeight(_ phase: Double) -> Double { 4 - 8.5 * phase }

    /// The Somerset Levels on a winter evening (1 December 2025), when the Sun is at `elevation` degrees.
    private static let place = (latitude: 51.16, longitude: -2.78)
    nonisolated private static func date(sunAt elevation: Double) -> Date {
        var date = Date(timeIntervalSince1970: 1_764_590_400) // 12:00 UTC, before the Sun starts down
        while asin(sunDirection(at: date).z) * 180 / .pi > elevation { date += 20 }
        return date
    }

    nonisolated private static func sunDirection(at date: Date) -> Sky.Vector {
        let jd = Sky.julianDate(date)
        return normalize(Sky.horizonMatrix(jd: jd, latitude: place.latitude, longitude: place.longitude) * Sky.sun(jd))
    }

    /// Bakes the physical sky (Weather's `Atmosphere`) for the Sun at `elevation`, and reads from it the light the
    /// land, the water and the birds take. The birds are the sky behind the flock at a tenth of its light, since a
    /// silhouette a few hundred metres off is darkened sky (blue-grey under blue, brown under gold), not black.
    nonisolated private static func light(camera: SkyCamera, elevation: Double, horizon: Float) -> Light {
        let date = date(sunAt: elevation), s = sunDirection(at: date)
        let sky = SkyLight.bake(camera: camera, date: date, latitude: place.latitude, longitude: place.longitude)
        // The white balance, between the named evenings' by the Sun's height.
        var balance = evenings[0].balance
        for (a, b) in zip(evenings, evenings.dropFirst()) where elevation <= a.sun {
            balance = a.balance + (b.balance - a.balance) * Float(min((a.sun - elevation) / (a.sun - b.sun), 1))
        }
        func glow(at v: Float, column: Int? = nil) -> SIMD3<Float> {
            let row = Int((v - Float(sky.bottom)) / (1 - Float(sky.bottom)) * Float(SkyLight.height))
            let j = min(max(row, 0), SkyLight.height - 1)
            let columns = column.map { [$0] } ?? Array(0..<SkyLight.width)
            var sum = SIMD3<Float>.zero
            for i in columns {
                let k = (j * SkyLight.width + i) * 4
                let c = SIMD3<Float>(Float(sky.pixels[k]), Float(sky.pixels[k + 1]), Float(sky.pixels[k + 2])) / 255
                sum += c * c * 4 * balance
            }
            return sum / Float(columns.count)
        }
        let behind = glow(at: horizon + 0.3, column: SkyLight.width / 2) * 0.1
        return Light(sky: sky, balance: balance, sun: SIMD3<Float>(s), disc: s.z > -0.02 ? SIMD3<Float>(sky.sunColour) : .zero,
                     horizon: glow(at: horizon + 0.01), ink: (SIMD3<Float>(repeating: 1) - exp(-behind)).squareRoot())
    }

    private func bake(at elevation: Double, fade seconds: Double) {
        baking = true
        lastBake = clock
        let (eye, horizon) = (eye, Float(eye.horizon))
        Task.detached(priority: .utility) {
            let light = Murmuration.light(camera: eye, elevation: elevation, horizon: horizon)
            await MainActor.run { [weak self] in
                self?.show(light, fade: seconds)
                self?.baking = false
            }
        }
    }

    /// Fades from the light on screen to a new one over `seconds` (at once when 0).
    private func show(_ light: Light, fade seconds: Double) {
        let texture = light.sky.texture
        before.textureValue = seconds > 0 ? after.textureValue ?? texture : texture
        after.textureValue = texture
        fade = (shown ?? light, light, clock, seconds)
        shown = light
        applyFade()
    }

    /// Blends everything that follows the light between the two bakes on screen; the birds' colour every half second.
    private func applyFade() {
        guard let fade else { return }
        let k = Float(fade.seconds > 0 ? min(max((clock - fade.start) / fade.seconds, 0), 1) : 1)
        func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> SIMD3<Float> { a + (b - a) * k }
        blend.floatValue = k
        balance.vectorFloat3Value = mix(fade.from.balance, fade.to.balance)
        disc.vectorFloat3Value = fade.from.disc + (fade.to.disc - fade.from.disc) * (k * k * k) // late, not in the old sky
        sun.vectorFloat3Value = fade.to.sun
        land.vectorFloat3Value = mix(fade.from.horizon, fade.to.horizon) / groundSky
        if clock - lastInk >= 0.5 || k >= 1 {
            lastInk = clock
            flock?.setInk(color(mix(fade.from.ink, fade.to.ink)))
        }
        if k >= 1 { self.fade = nil }
    }

    private func color(_ c: SIMD3<Float>) -> SKColor { SKColor(srgbRed: CGFloat(c.x), green: CGFloat(c.y), blue: CGFloat(c.z), alpha: 1) }

    private var lens: SIMD4<Float> {
        SIMD4(Float(eye.tanH), Float(eye.tanV), Float(eye.horizon), Float(shown?.sky.bottom ?? eye.horizon - 0.06))
    }

    /// When the feeder flocks of a new evening arrive (seconds in) and how many birds each brings: a big first group,
    /// then smaller ones every 20–30 s for about four minutes, 1,500 in all.
    private static func schedule() -> [(at: Double, count: Int)] {
        var left = 1500, at = 25.0, out: [(at: Double, count: Int)] = [(at, 320)]
        left -= 320
        while left > 0 {
            at += .random(in: 18...32)
            let count = min(left, left < 160 ? left : .random(in: 90...200))
            out.append((at, count))
            left -= count
        }
        return out
    }

    private func addSky() {
        let sky = SKSpriteNode(color: .black, size: size)
        sky.anchorPoint = .zero
        sky.shader = SKShader(source: shaderCommon + Self.skyShader, uniforms: [
            SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)]),
            before, after, blend, SKUniform(name: "u_cam", vectorFloat4: lens),
            SKUniform(name: "u_fwd", vectorFloat3: SIMD3<Float>(eye.forward)),
            SKUniform(name: "u_right", vectorFloat3: SIMD3<Float>(eye.right)),
            sun, disc, balance,
        ])
        addChild(sky)
    }

    private static let skyShader = """
    void main() {
        vec2 uv = v_tex_coord;
        vec3 rd = normalize(u_right * ((uv.x * 2.0 - 1.0) * u_cam.x) + u_fwd + vec3(0.0, 0.0, (uv.y - u_cam.z) * 2.0 * u_cam.y));
        vec2 st = vec2(uv.x, max(uv.y - u_cam.w, 0.0) / (1.0 - u_cam.w));
        vec3 c4 = mix(texture2D(u_before, st).rgb, texture2D(u_after, st).rgb, u_blend);
        vec3 col = c4 * c4 * 4.0 * u_balance;
        float ang = acos(clamp(dot(rd, u_sun), -1.0, 1.0));
        float disc = smoothstep(0.0050, 0.0044, ang);
        col += u_disc * (disc * 60.0 * (0.6 + 0.4 * sqrt(max(1.0 - ang * ang / 0.000022, 0.0))) + 0.25 * exp(-ang * 40.0) + 0.02 * exp(-ang * 8.0));
        col = sqrt(1.0 - exp(-col));
        gl_FragColor = vec4(col + (hash21(uv * u_size * 2.0) - 0.5) / 128.0, 1.0);
    }
    """

    // MARK: - The ground

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
        vec2 slope = vec2(n1.r - n2.b, n1.b + n2.r - 1.0) * smoothstep(400.0, 60.0, dist);
        vec2 shift = slope * dip * u_waves.x;
        // Fine wavelets, stretched across the view as wind ripples are, drifting toward us; only on the nearer water,
        // where a pixel still spans less than one of them.
        vec4 n3 = texture2D(u_noise, nuv(w * vec2(0.3, 0.9) + vec2(t * 0.02, t * 0.12)));
        float wavelets = (n3.g - 0.5) * smoothstep(45.0, 12.0, dist);
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
            vec2 st = vec2(uv.x + shift.x, clamp((v - u_cam.w) / (1.0 - u_cam.w), 0.0, 1.0));
            vec3 c4 = mix(texture2D(u_before, st).rgb, texture2D(u_after, st).rgb, u_blend);
            reflected += c4 * c4 * (4.0 / 3.0);
        }
        vec2 b = vec2(uv.x + shift.x, (uv.y - shift.y) / u_cam.z);
        float s = u_rough * 0.5;
        float birds = 0.4 * texture2D(u_birds, b).r + 0.3 * texture2D(u_birds, b + vec2(0.0, s)).r + 0.3 * texture2D(u_birds, b - vec2(0.0, s)).r;
        vec3 water = reflected * u_balance * ripples * 2.0 * (1.0 - birds * 0.9) * (1.0 + (slope.y + wavelets) * u_waves.z);
        vec3 col = sqrt(1.0 - exp(-mix(land, water, aux.r)));
        gl_FragColor = vec4(col + (hash21(v_tex_coord * u_size * 2.0) - 0.5) / 128.0, 1.0) * photo.a;
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
        var state: UInt8 = 1                                          // 0 not here (yet, or roosting), 1 flying, 2 going down
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
    /// Late in the evening: metres the flock's height is lowered (the swoops get lower as the light fails), then whether
    /// it's going down to roost, pouring from its underside to `perch`, under the pier or into the far reeds.
    var dip: Float = 0, roosting = false
    /// Birds (parcels) a second that may leave for the roost: the descent takes the same share of any evening.
    var roostRate: Float = 10
    private let perch: SIMD3<Float>
    private var nextDown: Float = 0, downBudget: Float = 0
    /// Birds in the air, and whether any are on their way down.
    private(set) var flying = Flock.count, falling = 0
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

    init(view: GroundView, ink: SKColor, perch: SIMD3<Float>) {
        self.view = view
        self.perch = perch
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

    /// An empty sky, for the start of a new evening.
    func clearSky() {
        for i in birds.indices { birds[i].state = 0 }
        roosting = false
        dip = 0
    }

    /// A feeder flock of `count` birds flies in from beyond one side of the view, toward the roost.
    func arrive(_ count: Int) {
        let side: Float = random.unit() < 0.5 ? -1 : 1
        let y = roost.y + (random.unit() - 0.3) * 90
        let centre = SIMD3(side * (y * view.tanH + 40), y, roost.z + (random.unit() - 0.3) * 30)
        let heading = simd_normalize(SIMD3(roost.x - centre.x, roost.y - centre.y, 0))
        let size = 25 * pow(Float(count) / 300, 1.0 / 3)
        var left = count
        for i in birds.indices where left > 0 && birds[i].state == 0 {
            let a = random.unit() * 2 * .pi, r = random.unit().squareRoot() * size
            let p = centre + SIMD3(cos(a) * r, sin(a) * r * 0.7, (random.unit() - 0.5) * size * 0.4)
            birds[i] = Bird(p: p, v: heading * 10 + SIMD3(random.unit() - 0.5, random.unit() - 0.5, 0))
            left -= 1
        }
    }

    /// The birds' colour: the sky behind them, darkened (see `Murmuration.light`).
    func setInk(_ ink: SKColor) {
        for sprite in sprites { sprite.color = ink }
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
            if sprite.isHidden != (b.state == 0) { sprite.isHidden = b.state == 0 }
            if b.state == 0 { continue }
            let ex = simd_normalize(b.v), ey = simd_normalize(simd_cross(up, ex) + SIMD3(0, 1e-6, 0))
            let ez = simd_cross(ex, ey) * cos(b.bank) + ey * sin(b.bank)
            let at = view.project(b.p), wing = view.project(b.p + simd_cross(ez, ex)), top = view.project(b.p + ez)
            var (wx, wy) = (wing.x - at.x, wing.y - at.y)
            if wx * (top.y - at.y) - wy * (top.x - at.x) < 0 { (wx, wy) = (-wx, -wy) } // raised wings point up the bird
            let facing = abs(simd_dot(ez, simd_normalize(b.p)))
            sprite.position = CGPoint(x: CGFloat(at.x), y: CGFloat(at.y))
            sprite.zRotation = CGFloat(atan2(wy, wx))
            sprite.setScale(CGFloat(Self.parcel * at.perMetre / 64))
            let alpha = (0.22 + 0.45 * facing) * min(max((b.p.z - perch.z) / 6, 0), 1) // fading into the roost
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
        let height = roost.z + 18 * sin(clock * 0.035 + 1) - dip
        let up = SIMD3<Float>(0, 0, 1), g: Float = 9.81
        var middle = SIMD3<Float>.zero, flow = SIMD3<Float>.zero
        flying = 0
        falling = 0
        for b in birds {
            if b.state == 1 { middle += b.p; flow += b.v; flying += 1 }
            if b.state == 2 { falling += 1 }
        }
        middle = flying > 0 ? middle / Float(flying) : roost
        if flying == 0 { flow = SIMD3(1, 0, 0) }

        // Going down to roost: the lowest birds lead, and their neighbours follow them (below), so a funnel pours from
        // the flock's underside, at `roostRate` birds a second: two or three minutes, as real ones take. The last few
        // go together.
        let roosting = roosting, perch = perch
        var budget = roosting ? min(downBudget + roostRate * dt, 30) : 0
        nextDown -= dt
        if roosting && flying > 0 && nextDown < 0 && budget >= 1 {
            nextDown = 1 / (0.3 * roostRate)
            var lowest = -1
            for (i, b) in birds.enumerated() where b.state == 1 && (lowest < 0 || b.p.z < birds[lowest].p.z) { lowest = i }
            if lowest >= 0 { birds[lowest].state = 2; budget -= 1 }
            if flying < 60 { for i in birds.indices where birds[i].state == 1 { birds[i].state = 2 } }
        }

        // Every 7 s the bird furthest ahead starts a turn: back over the roost if the flock has wandered, otherwise a
        // swing of 60–150° either way. Its neighbours copy it, and theirs copy them. (Sooner and the waves overlap.)
        nextTurn -= dt
        if nextTurn < 0 && flying > 0 {
            nextTurn = 7
            let ahead = simd_normalize(SIMD3(flow.x, flow.y, 0))
            var lead = 0, best = -Float.infinity
            for (i, b) in birds.enumerated() where b.state == 1 && simd_dot(b.p - middle, ahead) > best {
                best = simd_dot(b.p - middle, ahead)
                lead = i
            }
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
        if nextFalcon < 0 && falconKnob.value > 0.5 && flying > 300 && !roosting {
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
                    for i in 0..<birds.count where birds[i].state != 0 {
                        let (x, y, z) = cellOf(birds[i].p)
                        birds[i].cell = Int32(key(x, y, z))
                        start[Int(birds[i].cell) + 1] += 1
                    }
                    for c in 1..<start.count { start[c] += start[c - 1] }
                    for i in 0..<birds.count where birds[i].state != 0 {
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
                    for i in 0..<birds.count where birds[i].state != 0 {
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
                                    if roosting && o.state == 2 && b.state == 1 && budget >= 1 && random.unit() < 0.05 {
                                        b.state = 2
                                        budget -= 1
                                    }
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
                            // keeps one flock with a crisp outline. A weak spring holds the roost's height. Birds going
                            // down to roost dive for the perch instead, keeping only their distance from each other.
                            if b.state == 2 {
                                force = apart * (12.5 / Float(max(found, 1))) + simd_normalize(perch - b.p) * 15
                            } else {
                                force += simd_normalize(middle - b.p + SIMD3(0, 0, 1e-4)) * (12.5 * max(0, 1 - Float(crowd) / 12))
                                force.z -= (b.p.z - height) * 0.1
                            }
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

                        let force = b.force + ex * ((b.state == 2 ? 14 : 10) - speed) // cruise at 10 m/s, faster diving
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
                    downBudget = budget
                    for i in 0..<birds.count where birds[i].state != 0 {
                        birds[i].p += birds[i].v * dt
                        if birds[i].state == 2 && birds[i].p.z < perch.z { birds[i].state = 0 } // roosting
                    }
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
