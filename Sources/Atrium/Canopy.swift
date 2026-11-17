import CanopyBake
import SpriteKit
import Synchronization
import simd

@MainActor func canopy(size: CGSize) -> SKScene { Canopy(size: size) }

/// Lying on the forest floor, looking straight up: a real bare stand, photographed straight up and keyed from its sky,
/// with scanned leaves grown on its twigs for the season at the real date and place, lit leaf by leaf by the light
/// through the leaves above them, against the real sky for this hour (`Atmosphere` through a camera pointed at the
/// zenith, 90° across the long side, head to the north). docs/canopy.md has the plan and what is built.
///
/// The sky is made with the scene; the stand is decoded and its leaves grown and lit off the main thread (`CanopyBake`,
/// a target of its own built with -O), and the canopy fades in over the sky when it lands. The render tests, with no
/// view, wait for it.
final class Canopy: SKScene {
    /// For pictures: a seed for the stand's mirroring and its leaves (unset or 0 for a new one each load), a day
    /// (`yyyy-MM-dd`) and an hour of the local clock (13.5 for half past one), each unset for now.
    static let pins = (seed: "canopy.seed", date: "canopy.date", hour: "canopy.hour")
    /// The stand: Poly Haven's Schachen Forest straight up, its sky keyed out by docs/canopy/stand.swift, 1512 px to a
    /// unit of tan, spanning ±1.1 across and ±0.75 up.
    nonisolated static let stand = (name: "canopy-schachen.heic", perTan: 1512.0, extent: SIMD2<Double>(1.1, 0.75))

    private let sprite = SKSpriteNode()
    private let show = SKUniform(name: "u_show", float: 0), sunShows = SKUniform(name: "u_sunshows", float: 0)
    private let canopyMap = SKUniform(name: "u_canopy", texture: Canopy.clear), coverMap = SKUniform(name: "u_cover", texture: Canopy.clear)
    private var landing: Landing?
    private var landed: TimeInterval?

    override init(size: CGSize) {
        super.init(size: size)
        let defaults = UserDefaults.standard, place = Location.shared.coordinate
        var seed = UInt64(max(defaults.integer(forKey: Self.pins.seed), 0))
        if seed == 0 { seed = .random(in: 1...UInt64(UInt32.max)) }
        let date = Self.moment(day: defaults.string(forKey: Self.pins.date), hour: defaults.object(forKey: Self.pins.hour) as? Double)
        let camera = Camera(size: size)
        let light = Light(camera: camera, date: date, latitude: place.latitude, longitude: place.longitude)
        let sky = SKTexture(data: Data(light.sky), size: CGSize(width: Light.width, height: Light.height))
        sky.filteringMode = .linear

        backgroundColor = .black
        sprite.size = size
        sprite.anchorPoint = .zero
        sprite.shader = SKShader(source: light.defines(camera) + Self.source,
                                 uniforms: [SKUniform(name: "u_sky", texture: sky), canopyMap, coverMap, show, sunShows])
        addChild(sprite)

        // ponytail: the light and the season are baked once, as the scene is made, and stay until the app rebuilds it
        // (after 12 hours, or as the displays sleep). Bake again every few minutes off the main thread, the same seed,
        // and swap it in, once the scene moves (step (b)) or if an afternoon's light lasting into the evening shows.
        let bake = CanopyBake(stand: resource(Self.stand.name), leaves: resource("dappled-leaves.png"), perTan: Self.stand.perTan,
                              extent: camera.extent, portrait: camera.portrait, sun: light.sun, sunlight: light.sunlight, zenith: light.zenith,
                              season: CanopySeason(date: date, latitude: place.latitude), seed: seed)
        let landing = Landing()
        self.landing = landing
        Task.detached(priority: .userInitiated) { landing.arrive(bake.make()) }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        Location.shared.start()
    }

    override func update(_ currentTime: TimeInterval) {
        if let job = landing, let made = job.take(waiting: view == nil) {
            let canopy = SKTexture(data: made.canopy, size: CGSize(width: made.width, height: made.height))
            let cover = SKTexture(data: made.cover, size: CGSize(width: made.coverWidth, height: made.coverHeight))
            canopy.filteringMode = .linear
            cover.filteringMode = .linear
            canopyMap.textureValue = canopy
            coverMap.textureValue = cover
            sunShows.floatValue = Float(made.sunShows)
            (landing, landed) = (nil, currentTime)
        }
        if let landed { // the canopy fades in over the sky as it lands, at once in the tests
            let shown = Float(view == nil ? 1 : simd_smoothstep(0, 1, (currentTime - landed) / 1.2))
            if show.floatValue != shown { show.floatValue = shown }
        }
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

    private static let clear = SKTexture(data: Data(count: 4), size: CGSize(width: 1, height: 1))

    /// What the bake hands over, once. `waiting` holds the caller until it has: for the render tests, which draw their
    /// frames faster than a canopy is grown.
    private final class Landing: Sendable {
        private let made = Mutex<CanopyBake.Made?>(nil), ready = DispatchSemaphore(value: 0)
        func arrive(_ thing: CanopyBake.Made) { made.withLock { $0 = thing }; ready.signal() }
        func take(waiting: Bool) -> CanopyBake.Made? {
            if waiting { ready.wait(); ready.signal() }
            return made.withLock { m in defer { m = nil }; return m }
        }
    }

    static let source = """
    float lumi(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
    void main() {
        vec2 uv = v_tex_coord;
        vec2 t = (uv * 2.0 - 1.0) * TAN;                 // tan units: x right (west), y up (north)
        vec2 q = t / (2.0 * EXTENT) + 0.5;               // the stand's picture
        vec3 sky = texture2D(u_sky, uv).rgb;
        sky = sky * sky * 4.0;
        vec4 c = texture2D(u_canopy, q);
        vec3 canopy = c.rgb * c.rgb * 2.0 * u_show;
        float a = c.a * u_show;
        // the veil: the sky in a gap paled toward silver near the leaves, as a bright gap in a crown looks
        float near = texture2D(u_cover, q).r * u_show;
        vec3 gap = mix(sky, vec3(0.86, 0.89, 0.97) * lumi(sky), 0.55 * smoothstep(0.08, 0.7, near));
        // the Sun: a soft disc where it shows, and a glow round it, no starburst
        vec3 d = normalize(vec3(t, 1.0));
        float ang = acos(clamp(dot(d, SUNDIR), -1.0, 1.0));
        gap += u_sunshows * (SUNDISC * (1.0 - smoothstep(0.004, 0.006, ang)) + SUNGLOW * exp(-ang / 0.05));
        vec3 col = gap * (1.0 - a) + canopy + u_sunshows * SUNGLOW * 0.25 * exp(-ang / 0.2);
        col = min(sqrt(1.0 - exp(-col)), vec3(240.0 / 255.0)); // Weather's film-like roll-off, roughly sRGB
        gl_FragColor = vec4(col + (fract(sin(dot(gl_FragCoord.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0, 1.0);
    }
    """
}

extension Canopy {
    typealias V3 = SIMD3<Double>

    /// The lens: a pinhole straight up, 90° across the long side, head to the north (screen right is west). For a
    /// portrait screen the stand is turned a quarter, so its long side runs up the screen.
    struct Camera: Sendable {
        var tan: SIMD2<Double>, extent: SIMD2<Double>, portrait: Bool
        init(size: CGSize) {
            portrait = size.height > size.width
            let long = Double(max(size.width, size.height))
            tan = [Double(size.width) / long, Double(size.height) / long]
            extent = portrait ? [stand.extent.y, stand.extent.x] : stand.extent
        }
        /// The direction (east, north, up) through a point of the screen, 0…1 each way, y up.
        func ray(_ u: Double, _ v: Double) -> V3 { normalize(V3(-(u * 2 - 1) * tan.x, (v * 2 - 1) * tan.y, 1)) }
    }

    /// The light at one moment: the sky as a small picture (stored as sqrt(v / 4), 128 × 96), and the Sun's light and
    /// the zenith's, all times the exposure, which holds the zenith's brightest channel at about 175 of 255 by day and
    /// lets it go dark at night as Weather's does.
    struct Light: Sendable {
        static let width = 128, height = 96
        var sky: [UInt8], sun: V3, sunlight: V3, zenith: V3

        init(camera: Camera, date: Date, latitude: Double, longitude: Double) {
            let air = Atmosphere.shared, jd = Sky.julianDate(date)
            let sun = normalize(Sky.horizonMatrix(jd: jd, latitude: latitude, longitude: longitude) * Sky.sun(jd))
            // a floor of airglow and starlight, so a moonless night is deep blue, not black
            let glow = V3(0.6, 0.8, 1.6) * 5e-8
            let up = air.march(h0: 0.3, dir: V3(0, 0, 1), lights: [(sun, 1)]).light + glow
            let luminance = dot(up, V3(0.2126, 0.7152, 0.0722)) + 2e-7
            let night = min(max((-0.03 - sun.z) / 0.17, 0), 1)
            let exposure = min(0.62 / (up.max() + 2e-7), 0.7 * pow(luminance, -0.88) * pow(0.05, -0.12) * (1 - 0.5 * night))
            var pixels = [UInt8](repeating: 255, count: Self.width * Self.height * 4)
            pixels.withUnsafeMutableBufferPointer { buffer in
                nonisolated(unsafe) let buffer = buffer // each row writes only its own pixels
                DispatchQueue.concurrentPerform(iterations: Self.height) { j in
                    for i in 0..<Self.width {
                        let d = camera.ray((Double(i) + 0.5) / Double(Self.width), (Double(j) + 0.5) / Double(Self.height))
                        let l = (air.march(h0: 0.3, dir: d, lights: [(sun, 1)]).light + glow) * exposure
                        for c in 0..<3 { buffer[(j * Self.width + i) * 4 + c] = UInt8(min(sqrt(max(l[c], 0) / 4), 1) * 255) }
                    }
                }
            }
            (sky, self.sun, sunlight, zenith) = (pixels, sun, air.sunlight(0.3, sun.z) * exposure, up * exposure)
        }

        func defines(_ camera: Camera) -> String {
            func v3(_ v: V3) -> String { String(format: "vec3(%.6f, %.6f, %.6f)", v.x, v.y, v.z) }
            return """
            #define TAN vec2(\(camera.tan.x), \(camera.tan.y))
            #define EXTENT vec2(\(camera.extent.x), \(camera.extent.y))
            #define SUNDIR \(v3(V3(-sun.x, sun.y, sun.z)))
            #define SUNDISC \(v3(sun.z > 0 ? sunlight * 4 : .zero))
            #define SUNGLOW \(v3(sun.z > 0 ? sunlight * 0.05 : .zero))

            """
        }
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
