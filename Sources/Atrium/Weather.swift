import SpriteKit

@MainActor func weather(size: CGSize) -> SKScene { WeatherScene(size: size) }

/// Rolling hills under whatever the weather is doing outside right now, from Open-Meteo every 15 minutes:
/// sun or moon and stars, drifting clouds, drizzle, rain, snow, fog or a thunderstorm. Day or night follows the
/// real Sun where you are, checked every minute, so it's right offline too.
final class WeatherScene: SKScene {
    nonisolated static let knobs = [
        Knob(key: "weather.preview", label: "Preview the weather", range: 0...1, standard: 0, section: "Preview",
             format: .toggle),
        Knob(key: "weather.previewKind", label: "Weather", range: 0...7, standard: 5, section: "Preview",
             format: .choice(["Clear", "Partly cloudy", "Overcast", "Fog", "Drizzle", "Rain", "Snow", "Thunderstorm"]),
             shownWhen: "weather.preview"),
        Knob(key: "weather.previewHour", label: "Time", range: 0...24, standard: 13, section: "Preview", format: .clock,
             shownWhen: "weather.preview"),
    ]

    /// The current weather as Open-Meteo reports it.
    struct Conditions: Equatable {
        var code = 2          // WMO weather code
        var cloudCover = 40.0 // percent
        var wind = 10.0       // km/h
        var windFrom = 270.0  // degrees clockwise from north
        var highCloud = 0.0   // percent: cirrus
        var snowDepth = 0.0   // m of snow on the ground
        var visibility = 30000.0 // m
    }

    private var report: Conditions     // the latest live weather, or the pinned test state
    private var conditions: Conditions // what's on screen: `report`, or the Settings preview
    private let live: Bool
    private var lastUpdate: TimeInterval?
    private var viewpoint: SkyCamera
    private var sinceTrack = 0.0, sinceBake = 0.0, baking = false, skyDate = Date.distantPast

    // The sky shader's inputs; see `skyShader`.
    private let skyBefore = SKUniform(name: "u_before", texture: nil), skyAfter = SKUniform(name: "u_after", texture: nil)
    private let skyBlend = SKUniform(name: "u_blend", float: 1)
    private let cameraUniforms = (lens: SKUniform(name: "u_cam", vectorFloat4: .zero), forward: SKUniform(name: "u_fwd", vectorFloat3: .zero),
                                  right: SKUniform(name: "u_right", vectorFloat3: .zero))
    private let sunDirection = SKUniform(name: "u_sun", vectorFloat3: [0, 0, 1]), sunDisc = SKUniform(name: "u_disc", vectorFloat3: .zero)
    private let moonPlace = SKUniform(name: "u_moon", vectorFloat4: [0, 0, 0, 0]), moonLight = SKUniform(name: "u_moonLight", vectorFloat3: [0, 0, 1])
    private let moonColour = SKUniform(name: "u_moonCol", vectorFloat3: .zero), starsUniform = SKUniform(name: "u_stars", float: 0)
    private let groundLight = SKUniform(name: "u_light", vectorFloat3: [1, 1, 1]), groundHaze = SKUniform(name: "u_haze", float: 0.05)
    private let groundColour = SKUniform(name: "u_colour", float: 1), groundHazeLit = SKUniform(name: "u_hazeLit", float: 1)
    private let cloudLayer = SKUniform(name: "u_cloud", vectorFloat4: .zero), cloudWind = SKUniform(name: "u_wind", vectorFloat2: .zero)
    private let cloudSun = SKUniform(name: "u_sunCol", vectorFloat3: .zero), cloudAmbient = SKUniform(name: "u_amb", vectorFloat3: .zero)
    private let cirrus = SKUniform(name: "u_high", float: 0), cirrusSun = SKUniform(name: "u_highCol", vectorFloat3: .zero)
    private let fog = SKUniform(name: "u_fog", float: 0), snowCover = SKUniform(name: "u_snow", float: 0)
    private let flashAmount = SKUniform(name: "u_flash", float: 0), flashPlace = SKUniform(name: "u_flashPos", vectorFloat3: .zero)
    /// Under a deck: its underside's colour, and how much the horizon takes it on instead of the clear sky's.
    private let deck = SKUniform(name: "u_deck", vectorFloat4: .zero)
    /// Seconds, wrapping hourly: u_time grows with uptime, and at rain's speeds a float that large loses the streaks.
    private let clock = SKUniform(name: "u_clock", float: 0)
    private let precipitation = SKUniform(name: "u_precip", vectorFloat4: .zero)
    private let rainColour = SKUniform(name: "u_rainCol", vectorFloat3: .zero), snowColour = SKUniform(name: "u_snowCol", vectorFloat3: .zero)
    private static let moonTexture = SKTexture(imageNamed: resource("weather-moon.png").path)

    /// Pass `conditions` to pin the scene to one state (snapshots); leave it nil to follow the live weather.
    init(size: CGSize, conditions: Conditions? = nil) {
        report = conditions ?? Conditions()
        self.conditions = report
        live = conditions == nil
        viewpoint = SkyCamera(aspect: size.width / size.height, horizon: 0.45, facing: 1.5 * .pi)
        super.init(size: size)
        self.conditions = wanted
        build()
        if live {
            NotificationCenter.default.addObserver(self, selector: #selector(redraw), name: UserDefaults.didChangeNotification, object: nil)
        }
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func didMove(to view: SKView) {
        guard live, action(forKey: "poll") == nil else { return }
        Location.shared.start()
        run(.sequence([.wait(forDuration: 2), // give a remembered location fix a moment to land
                       .repeatForever(.sequence([.run { [weak self] in self?.refresh() }, .wait(forDuration: 900)]))]),
            withKey: "poll")
    }

    /// The live weather, or while previewing, the kind and time of day picked in Settings.
    private var wanted: Conditions {
        guard live, Self.knobs[0].value > 0.5 else { return report }
        let kind = min(max(Int(Self.knobs[1].value), 0), 7)
        return Conditions(code: [0, 2, 3, 45, 53, 63, 73, 95][kind], cloudCover: [5, 45, 100, 100, 100, 100, 100, 100][kind], wind: 15, windFrom: 250,
                          highCloud: [30, 20, 0, 0, 0, 0, 0, 0][kind], snowDepth: kind == 6 ? 0.12 : 0, visibility: kind == 3 ? 400 : 30000)
    }

    /// Rebuilds the scene if the weather it should show has changed, crossfading from how it looked, or bakes the sky
    /// again at once if a preview moved the time of day.
    @objc private func redraw() {
        if wanted != conditions {
            let before = view?.texture(from: self)
            conditions = wanted
            build()
            guard let before else { return }
            let fade = SKSpriteNode(texture: before, size: size)
            fade.anchorPoint = .zero
            fade.zPosition = 100
            addChild(fade)
            fade.run(.sequence([.fadeOut(withDuration: 4), .removeFromParent()]))
        } else if abs(now.timeIntervalSince(skyDate)) > 120 {
            let here = Location.shared.coordinate
            show(SkyLight.bake(camera: viewpoint, date: now, latitude: here.latitude, longitude: here.longitude), fade: false)
            track()
        }
    }

    /// Now, or today at the preview hour while previewing.
    private var now: Date {
        guard live, Self.knobs[0].value > 0.5 else { return Date() }
        return Calendar.current.startOfDay(for: Date()).addingTimeInterval(Self.knobs[2].value * 3600)
    }

    /// Conditions from an Open-Meteo `current` reply.
    static func conditions(from reply: Data) -> Conditions? {
        struct Forecast: Decodable {
            struct Current: Decodable {
                let weatherCode: Int, cloudCover: Double, windSpeed: Double
                let windFrom: Double?, highCloud: Double?, snowDepth: Double?, visibility: Double? // not every model has them
                // Spelled out: .convertFromSnakeCase turns wind_speed_10m into windSpeed10M.
                enum CodingKeys: String, CodingKey {
                    case weatherCode = "weather_code", cloudCover = "cloud_cover", windSpeed = "wind_speed_10m"
                    case windFrom = "wind_direction_10m", highCloud = "cloud_cover_high", snowDepth = "snow_depth", visibility
                }
            }
            let current: Current
        }
        guard let now = try? JSONDecoder().decode(Forecast.self, from: reply).current else { return nil }
        return Conditions(code: now.weatherCode, cloudCover: now.cloudCover, wind: now.windSpeed,
                          windFrom: now.windFrom ?? 270, highCloud: now.highCloud ?? 0, snowDepth: now.snowDepth ?? 0,
                          visibility: now.visibility ?? 30000)
    }

    /// Fetches the current weather and redraws the scene if it changed. Offline, it keeps showing what it has.
    private func refresh() {
        let spot = Location.shared.coordinate
        var url = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        url.queryItems = [URLQueryItem(name: "latitude", value: String(spot.latitude)),
                          URLQueryItem(name: "longitude", value: String(spot.longitude)),
                          URLQueryItem(name: "current", value: "weather_code,cloud_cover,cloud_cover_high,wind_speed_10m,wind_direction_10m,snow_depth,visibility")]
        Task { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url.url!),
                  let latest = WeatherScene.conditions(from: data),
                  let self else { return }
            self.report = latest
            self.redraw()
        }
    }

    // MARK: - Building the scene

    /// Rebuilds everything for the current conditions.
    private func build() {
        removeAllChildren()
        removeAction(forKey: "lightning")
        addSky()
        addGround()
        addPrecipitation()
        if conditions.kind == .storm { addLightning() }
    }

    // MARK: - Sky

    /// The physical sky (see WeatherSky.swift), facing today's sunset: stars, and the real Sun and Moon.
    private func addSky() {
        let here = Location.shared.coordinate
        viewpoint.facing = Self.sunsetAzimuth(now, latitude: here.latitude)
        cameraUniforms.lens.vectorFloat4Value = [Float(viewpoint.tanH), Float(viewpoint.tanV), Float(viewpoint.horizon), Float(viewpoint.horizon - 0.06)]
        cameraUniforms.forward.vectorFloat3Value = SIMD3<Float>(viewpoint.forward)
        cameraUniforms.right.vectorFloat3Value = SIMD3<Float>(viewpoint.right)
        let sky = SKSpriteNode(color: .black, size: size)
        sky.anchorPoint = .zero
        sky.shader = SKShader(source: shaderCommon + Self.skyShader, uniforms: [
            SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)]), skyBefore, skyAfter, skyBlend,
            cameraUniforms.lens, cameraUniforms.forward, cameraUniforms.right, sunDirection, sunDisc, moonPlace, moonLight,
            moonColour, starsUniform, SKUniform(name: "u_moonTex", texture: Self.moonTexture),
            SKUniform(name: "u_noise", texture: CloudNoise.texture), cloudLayer, cloudWind, cloudSun, cloudAmbient, cirrus, cirrusSun, fog, deck, flashAmount, flashPlace,
        ])
        fog.floatValue = conditions.fog
        let clouds = conditions.clouds
        cloudLayer.vectorFloat4Value = SIMD4<Float>(clouds.cover, clouds.base, clouds.thickness, clouds.deck)
        cirrus.floatValue = clouds.cirrus
        snowCover.floatValue = Float(conditions.snowCover)
        // km/s, the way the wind blows (toward, not from)
        cloudWind.vectorFloat2Value = SIMD2<Float>(conditions.windToward) * Float(conditions.wind / 3600 * 0.6)
        addChild(sky)
        show(SkyLight.bake(camera: viewpoint, date: now, latitude: here.latitude, longitude: here.longitude), fade: false)
        track()
    }

    /// Bakes the sky for now off the main thread, then fades to it.
    private func bakeSky() {
        baking = true
        let (camera, date, here) = (viewpoint, now, Location.shared.coordinate)
        Task.detached(priority: .utility) {
            let light = SkyLight.bake(camera: camera, date: date, latitude: here.latitude, longitude: here.longitude)
            await MainActor.run { [weak self] in
                self?.show(light, fade: true)
                self?.baking = false
            }
        }
    }

    private func show(_ light: SkyLight, fade: Bool) {
        skyDate = light.date
        skyBefore.textureValue = fade ? skyAfter.textureValue : light.texture
        skyAfter.textureValue = light.texture
        skyBlend.floatValue = fade ? 0 : 1
        let visible: Double = conditions.kind == .clear || conditions.kind == .partlyCloudy ? 1 : 0
        let moonUp: Double = light.moon.z > 0 ? min(light.moonPower / 2.5e-6, 1) : 0
        let dark = smoothstep(-0.07, -0.25, light.sun.z)
        starsUniform.floatValue = Float(dark * (1 - 0.6 * moonUp) * visible)
        sunDisc.vectorFloat3Value = light.sun.z > -0.02 ? SIMD3<Float>(light.sunColour) : .zero
        cloudSun.vectorFloat3Value = SIMD3<Float>(light.sunAtCloud)
        // Rain shows the light around it; snow is white in whatever light there is. Tone-mapped like the shaders.
        func display(_ v: Sky.Vector) -> SIMD3<Float> { SIMD3<Float>((Sky.Vector(1, 1, 1) - exp(-v)).squareRoot()) }
        let around = light.ambient * 0.5 + light.sunColour * max(light.sun.z, 0) * 0.04
        rainColour.vectorFloat3Value = display(around * 0.8)
        snowColour.vectorFloat3Value = display(around * 1.6 + Sky.Vector(repeating: 0.002))
        // Low cloud at night glows faintly orange-grey with the lights of towns beneath it.
        let clouds = conditions.clouds, night = smoothstep(-0.02, -0.15, light.sun.z)
        let skyglow = Sky.Vector(0.4, 0.32, 0.24) * night * Double(clouds.deck) * Double(clouds.cover)
        cloudAmbient.vectorFloat3Value = SIMD3<Float>(light.ambient + skyglow)
        let underside = (light.sunAtCloud * max(light.sun.z, 0) * 0.07 + (light.ambient + skyglow) * 0.22) * exp(-0.5 * (Double(clouds.thickness) - 1))
        let underDeck: Float = conditions.kind == .fog ? 0.3 : clouds.cover > 0.9 ? 0.92 : clouds.deck * clouds.cover
        deck.vectorFloat4Value = SIMD4<Float>(SIMD3<Float>(underside), underDeck)
        let high = light.sun.z > -0.14 ? light.sun : light.moon, highPower = light.sun.z > -0.14 ? 1 : light.moonPower
        cirrusSun.vectorFloat3Value = SIMD3<Float>(Atmosphere.shared.sunlight(8, high.z) * highPower * light.exposure)
        // The ground photo was taken under an even overcast, so it's lit here as if its colours were that light's:
        // skylight, plus the Sun (or Moon) on the slopes that face it. Facing a low Sun we see the shaded sides of
        // the hills, so it adds little there; behind us, it lights them fully. Just after it rises, only some
        // slopes catch it.
        func direct(_ d: Sky.Vector) -> Double {
            let front = -dot(Sky.Vector(d.x, d.y, 0), viewpoint.forward)
            let facing = min(max(0.55 * d.z + 0.35 * front * (1 - d.z * d.z).squareRoot() + 0.15, 0), 1)
            return facing * (0.4 + 0.6 * smoothstep(0, 0.15, d.z))
        }
        let moonDirect = Atmosphere.shared.sunlight(viewpoint.height, light.moon.z) * light.moonPower * light.exposure
        var sunlit = light.ambient + light.sunColour * direct(light.sun) + moonDirect * direct(light.moon)
        // Under a deck of cloud the light is grey, even, and about half the day's.
        let overcast = conditions.cloudiness, global: Sky.Vector = light.ambient + light.sunColour * max(light.sun.z, 0)
        let grey = Sky.Vector(repeating: global.sum() / 3 * 0.5 * exp(-0.4 * (Double(clouds.thickness) - 1))) + skyglow * 0.4
        sunlit = sunlit * (1 - overcast) + grey * overcast
        // The eye adapts to the land as well as the sky: facing a sunset the hills go dark, but not black.
        let lit = sunlit / 7, brightness = (lit * Sky.Vector(0.2126, 0.7152, 0.0722)).sum()
        groundLight.vectorFloat3Value = SIMD3<Float>(lit * pow(max(brightness, 1e-5), -0.45) * (1 - 0.6 * smoothstep(-0.03, -0.2, light.sun.z)))
        // At night the eye sees less colour (the Purkinje shift), and the haze isn't lit from low down any more,
        // since the air near the ground is in the Earth's shadow while the high sky still glows.
        groundColour.floatValue = Float(smoothstep(0.002, 0.03, brightness) * (1 - 0.7 * smoothstep(-0.03, -0.2, light.sun.z)))
        groundHazeLit.floatValue = Float(0.3 + 0.7 * smoothstep(-0.08, 0, light.sun.z))
        let moonNight = smoothstep(0.05, -0.1, light.sun.z)
        moonColour.vectorFloat3Value = SIMD3<Float>(Atmosphere.shared.sunlight(viewpoint.height, light.moon.z) * (0.5 + 1.5 * moonNight))
    }

    /// Moves the Sun and Moon to where they are now; they'd hop visibly if they only moved with each minute's bake.
    private func track() {
        let here = Location.shared.coordinate, jd = Sky.julianDate(now)
        let toHorizon = Sky.horizonMatrix(jd: jd, latitude: here.latitude, longitude: here.longitude)
        let sun = normalize(toHorizon * Sky.sun(jd)), moon = normalize(toHorizon * Sky.moon(jd))
        sunDirection.vectorFloat3Value = SIMD3<Float>(sun.z > -0.14 ? sun : moon) // what lights the clouds
        guard let at = viewpoint.screen(moon), moon.z > -0.01 else { moonPlace.vectorFloat4Value = [0, 0, 0, 0]; return }
        // Light it from the real Sun, and turn it so its north points to the celestial pole, as in Live Sky.
        func angle(toward target: Sky.Vector) -> Double {
            let step = normalize(moon + (target - moon * dot(moon, target)) * 0.02)
            guard let next = viewpoint.screen(step) else { return 0 }
            return atan2((next.y - at.y) * size.height, (next.x - at.x) * size.width)
        }
        let north = angle(toward: normalize(toHorizon * Sky.Vector(0, 0, 1))), toSun = angle(toward: sun)
        let phase = acos(2 * Sky.moonPhase(jd).lit - 1) // the Sun–Moon–Earth angle
        moonLight.vectorFloat3Value = [Float(sin(phase) * cos(toSun)), Float(sin(phase) * sin(toSun)), Float(cos(phase))]
        moonPlace.vectorFloat4Value = [Float(at.x * size.width), Float(at.y * size.height), 15, Float(north - .pi / 2)]
    }

    /// Where the Sun sets today, in radians clockwise from north, so sunsets happen in view; due west where it
    /// doesn't set or doesn't rise.
    static func sunsetAzimuth(_ date: Date, latitude: Double) -> Double {
        let declination = asin(Sky.sun(Sky.julianDate(date)).z)
        let cosine = sin(declination) / cos(latitude * .pi / 180)
        return abs(cosine) < 1 ? 2 * .pi - acos(cosine) : 1.5 * .pi
    }

    /// The sky from its baked texture, crossfading into each new bake, with stars, the Sun and the Moon on top.
    /// Light is linear until the end, then tone-mapped like film.
    private static let skyShader = """
    vec3 decode(vec3 c) { return c * c * 4.0; }

    // Where to sample the baked tileable noise (CloudNoise) for point p. SKShader can't pass a sampler to a function,
    // so the fetches stay in main().
    vec2 nuv(vec2 p) { return (fract(p) * 256.0 + 0.5) / 257.0; }

    // Cloud density, 0…1, from two fetches: billows and fbm for the big shapes, and fine fbm drifting a little
    // differently so the clouds slowly change shape. `lod` fades detail with distance; `deck` 1 is a flat sheet.
    float cloudShape(vec4 a, vec4 b, float cover, float deck, float lod) {
        float shape = mix(a.g * 0.6 + a.r * 0.4, a.r * 0.5 + 0.35, deck);
        float d = shape + (b.b - 0.5) * 0.35 * (1.0 - lod) + (b.r - 0.5) * 0.12;
        return smoothstep(1.0 - cover, 1.0 - cover + mix(0.18, 0.5, deck), d);
    }

    // Henyey–Greenstein: how much light a cloud scatters forward, toward us when we face the Sun.
    float hg(float c, float g) { return (1.0 - g * g) / pow(1.0 + g * g - 2.0 * g * c, 1.5) * 0.0796; }

    void main() {
        vec2 uv = v_tex_coord;
        vec2 pts = uv * u_size;
        vec3 rd = normalize(u_right * ((uv.x * 2.0 - 1.0) * u_cam.x) + u_fwd + vec3(0.0, 0.0, (uv.y - u_cam.z) * 2.0 * u_cam.y));
        vec2 st = vec2(uv.x, max(uv.y - u_cam.w, 0.0) / (1.0 - u_cam.w));
        vec3 col = mix(decode(texture2D(u_before, st).rgb), decode(texture2D(u_after, st).rgb), u_blend);

        // Stars where the sky is dark enough, thinning toward the brighter horizon.
        if (u_stars > 0.0) {
            float s = starField(pts, 9.0, 0.35, u_time) + 0.6 * starField(pts + 300.0, 5.0, 0.25, u_time);
            col += vec3(0.9, 0.93, 1.0) * s * u_stars * 0.6 * clamp(1.0 - dot(col, vec3(0.3, 0.5, 0.2)) * 3.0, 0.0, 1.0);
        }
        // The Sun: a limb-darkened disc and a soft photographic glow, hidden by cloud below.
        float c = dot(rd, u_sun);
        float ang = acos(clamp(c, -1.0, 1.0));
        float disc = smoothstep(0.0050, 0.0044, ang);
        vec3 sunLight = u_disc * (disc * 60.0 * (0.6 + 0.4 * sqrt(max(1.0 - ang * ang / 0.000022, 0.0))) + 0.25 * exp(-ang * 40.0) + 0.02 * exp(-ang * 8.0));
        // The Moon: NASA's photo of the near side, lit from the real Sun, with a little earthshine on the dark part.
        vec2 m = (pts - u_moon.xy) / max(u_moon.z, 0.001);
        if (u_moon.z > 0.0 && dot(m, m) < 1.0) {
            float cs = cos(u_moon.w);
            float sn = sin(u_moon.w);
            vec4 surface = texture2D(u_moonTex, vec2(cs * m.x + sn * m.y, cs * m.y - sn * m.x) * 0.5 + 0.5);
            vec3 n = vec3(m, sqrt(max(1.0 - dot(m, m), 0.0)));
            float lit = smoothstep(-0.03, 0.06, dot(n, u_moonLight));
            col += surface.rgb * surface.rgb * u_moonCol * (lit + 0.015) * surface.a;
        }

        // Clouds: a flat layer at u_cloud.y km, seen in perspective, so they shrink and flatten toward the horizon.
        // Lit from three looks at the density: here, a little further along the ray (less cloud there means this is
        // a cloud's top edge on screen) and toward the Sun (cloud between here and the light).
        float T = 1.0;
        float flashTex = 1.0; // lightning lights the cloud's lumps unevenly
        vec3 cl = vec3(0.0);
        vec2 st0 = vec2(uv.x, (u_cam.z + 0.01 - u_cam.w) / (1.0 - u_cam.w));
        vec3 haze = mix(decode(texture2D(u_before, st0).rgb), decode(texture2D(u_after, st0).rgb), u_blend);
        haze = mix(min(haze, vec3(mix(40.0, 1.5, u_deck.a))), vec3(dot(min(haze, vec3(1.5)), vec3(0.3, 0.5, 0.2))) * 0.08 + u_deck.rgb * 0.9, u_deck.a); // as it looks under the deck
        if (rd.z > 0.0 && u_cloud.x > 0.0) {
            float tBase = u_cloud.y / rd.z;
            vec2 wind = u_wind * u_time;
            float lod = clamp(log2(tBase / 6.0) * 0.4, 0.0, 1.0);
            vec2 P = rd.xy * tBase + wind;
            vec2 toSun = u_sun.xy / max(length(u_sun.xy), 0.0001);
            vec4 na1 = texture2D(u_noise, nuv(P * 0.045));
            vec4 nb1 = texture2D(u_noise, nuv(P * 0.19 + na1.a * 0.3 + u_time * 0.00002));
            float d = cloudShape(na1, nb1, u_cloud.x, u_cloud.w, lod);
            vec2 Pu = P + normalize(rd.xy) * 0.35 * tBase / 6.0;
            vec4 na2 = texture2D(u_noise, nuv(Pu * 0.045));
            vec4 nb2 = texture2D(u_noise, nuv(Pu * 0.19 + na2.a * 0.3 + u_time * 0.00002));
            float du = cloudShape(na2, nb2, u_cloud.x, u_cloud.w, lod);
            vec2 Ps = P + toSun * 0.5;
            vec4 na3 = texture2D(u_noise, nuv(Ps * 0.045));
            vec4 nb3 = texture2D(u_noise, nuv(Ps * 0.19 + na3.a * 0.3 + u_time * 0.00002));
            float ds = cloudShape(na3, nb3, u_cloud.x, u_cloud.w, lod);
            // A deck is opaque, or the Sun's glow behind it shows through; heaped cloud has soft, thin edges.
            float a = (1.0 - exp(-d * mix(6.0, 14.0, u_cloud.w) * u_cloud.z)) * smoothstep(0.0, 0.03, rd.z);
            float thin = exp(-d * 3.0 * u_cloud.z);                      // light getting through
            float top = clamp((d - du) * 3.0 + 0.35, 0.0, 1.0);         // a cloud's top edge on screen
            float high = smoothstep(0.0, 0.35, u_sun.z);                 // the Sun above the clouds' sides
            float shadow = exp(-ds * 2.5 * u_cloud.z);                   // cloud between here and the Sun
            // Seen from below, bases are grey: sunlight diffused through the cloud plus skylight, about as bright as
            // the blue beside them. Faces lit by the Sun are white; toward the Sun we see dark sides with bright rims.
            float face = 0.55 - 0.45 * c;
            vec3 base = u_sunCol * max(u_sun.z, 0.0) * mix(mix(0.04, 0.07, u_cloud.w), 0.16, thin) + u_amb * 0.22;
            // A deck's underside is lumpy: rolls of thicker, darker cloud between thinner, brighter gaps. Thicker
            // decks are darker overall, down to a storm's slate.
            float lumps = na1.r * 0.55 + nb1.b * 0.3 + na1.g * 0.15;
            flashTex = 0.15 + 1.7 * smoothstep(0.3, 0.8, na1.g * 0.5 + nb1.r * 0.5);
            base *= mix(1.0, 0.55 + 0.9 * lumps, u_cloud.w) * exp(-0.5 * (u_cloud.z - 1.0));
            vec3 lit = u_sunCol * 0.3 * shadow;
            float litFrac = clamp(top * high * face * 1.5 + (1.0 - high) * face, 0.0, 1.0);
            cl = (mix(base, lit, litFrac) * (1.0 - 0.3 * u_cloud.w * d) + u_sunCol * shadow * thin * hg(c, 0.75) * 1.2) * a;
            T = 1.0 - a;
            // Distant cloud fades into the horizon haze, as a real sky ends in a pale band, not a cut-out edge. Under
            // a deck that band is the deck's own grey (u_deck), only a little brighter toward the Sun.
            float far = 1.0 - exp(-tBase / mix(45.0, 25.0, u_cloud.w));
            cl = mix(cl, haze * (1.0 - T), far);
        }
        // High cirrus at 8 km: fine streaks along the wind, still lit pink after sunset down here.
        if (rd.z > 0.0 && u_high > 0.0) {
            vec2 H = rd.xy * (8.0 / rd.z) + u_wind * u_time * 2.0;
            vec2 hs = vec2(H.x * 0.8 + H.y * 0.6, H.y * 0.8 - H.x * 0.6) * vec2(0.012, 0.09);
            vec4 h1 = texture2D(u_noise, nuv(hs));
            vec4 h2 = texture2D(u_noise, nuv(hs * vec2(3.1, 2.3) + h1.a * 0.2));
            float ci = smoothstep(1.0 - u_high, 1.2 - u_high, h1.r * 0.7 + h2.b * 0.3) * (0.3 + 0.7 * h2.r);
            ci *= smoothstep(0.02, 0.12, rd.z) * 0.55;
            cl = cl + T * ci * (u_highCol * (0.7 + 6.0 * hg(c, 0.8)) + u_amb * 0.35);
            T *= 1.0 - ci;
        }
        col = col * T + cl + sunLight * T;

        // Lightning inside the cloud: brightest in medium-thick cloud around the strike, a faint lift everywhere.
        if (u_flash > 0.0) {
            vec2 off = (uv - u_flashPos.xy) * vec2(u_size.x / u_size.y, 1.0);
            float glow = u_flash * exp(-dot(off, off) / u_flashPos.z) * flashTex;
            float cloudA = 1.0 - T;
            col += vec3(0.75, 0.8, 1.0) * (glow * (0.3 + cloudA * (1.0 - 0.5 * cloudA)) * 2.5 + u_flash * 0.05);
        }

        // Fog: optically thick, so it's grey-white whatever the sky's colour, and it swallows the low sky first.
        if (u_fog > 0.0) {
            vec3 fogCol = mix(haze, vec3(dot(haze, vec3(0.3, 0.5, 0.2))), 0.7) * 0.95;
            col = mix(col, fogCol, clamp(u_fog * 1.6, 0.0, 0.97) * smoothstep(u_cam.z + 1.2 * u_fog, u_cam.z - 0.05, uv.y));
        }
        col = sqrt(1.0 - exp(-col)); // film-like roll-off, then roughly sRGB
        gl_FragColor = vec4(col + (hash21(pts * 2.0) - 0.5) / 128.0, 1.0);
    }
    """

    // MARK: - Ground

    /// Fort Ord's green hills and oak woodland (BLM, public domain), with its sky cut out, and `weather-ground-aux`:
    /// red is how far away each point is (0 near, 1 at the skyline), green is where there are trees.
    private static let groundPhoto = SKTexture(image: NSImage(contentsOf: resource("weather-ground.heic")) ?? NSImage())
    private static let groundAux = SKTexture(image: NSImage(contentsOf: resource("weather-ground-aux.png")) ?? NSImage())

    /// The photo across the bottom of the screen, its top at 0.56 of the height, cropped at the bottom on wide
    /// screens rather than squeezing the sky. Relit for the light and weather, and hazed with distance.
    private func addGround() {
        let photo = Self.groundPhoto.size(), aspect = photo.width / max(photo.height, 1)
        let width = max(size.width, size.height * 0.56 * aspect), height = width / aspect
        let ground = SKSpriteNode(texture: Self.groundPhoto, size: CGSize(width: width, height: height))
        ground.anchorPoint = CGPoint(x: 0.5, y: 1)
        ground.position = CGPoint(x: size.width / 2, y: size.height * 0.56)
        ground.zPosition = 5
        let frame = SIMD4<Float>(Float((size.width - width) / 2 / size.width), Float((size.height * 0.56 - height) / size.height),
                                 Float(width / size.width), Float(height / size.height))
        ground.shader = SKShader(source: Self.groundShader, uniforms: [
            SKUniform(name: "u_aux", texture: Self.groundAux), SKUniform(name: "u_frame", vectorFloat4: frame),
            skyBefore, skyAfter, skyBlend, cameraUniforms.lens, groundLight, groundHaze, groundColour, groundHazeLit, fog, deck, flashAmount, snowCover,
        ])
        addChild(ground)
    }

    /// Lights the photo's colours as linear light, fades them toward grey-blue in dim light, then hazes each point
    /// toward the sky just above the horizon over it, more with distance. Premultiplied, like SpriteKit's textures.
    private static let groundShader = """
    vec3 decode(vec3 c) { return c * c * 4.0; }

    void main() {
        vec4 photo = texture2D(u_texture, v_tex_coord);
        vec3 aux = texture2D(u_aux, v_tex_coord).rgb;
        vec3 albedo = photo.rgb / max(photo.a, 0.004);
        // Snow on the ground: the open grass goes white, shaded by the photo's own light and shade so the hills keep
        // their form; the trees darken, lose colour and catch snow on their brighter parts.
        if (u_snow > 0.0) {
            float lum = dot(albedo, vec3(0.3, 0.59, 0.11));
            vec3 snowy = vec3(0.86, 0.89, 0.94) * clamp(pow(lum / 0.42, 0.55), 0.45, 1.08);
            vec3 trees = mix(vec3(lum), albedo, 0.35) * 0.62 + vec3(0.8, 0.83, 0.88) * smoothstep(0.3, 0.6, lum) * 0.35;
            float open = 1.0 - smoothstep(0.25, 0.75, aux.g);
            albedo = mix(albedo, mix(trees, snowy, open), u_snow * (0.55 + 0.45 * open));
        }
        vec3 land = albedo * albedo * (u_light + vec3(0.75, 0.8, 1.0) * u_flash * 0.15);
        float lum = dot(land, vec3(0.2126, 0.7152, 0.0722));
        land = mix(vec3(lum) * vec3(0.75, 0.88, 1.2), land, u_colour); // the Purkinje shift: moonlit fields look blue-grey
        vec2 screen = u_frame.xy + v_tex_coord * u_frame.zw;
        vec2 above = vec2(screen.x, (u_cam.z + 0.03 - u_cam.w) / (1.0 - u_cam.w));
        vec3 haze = mix(decode(texture2D(u_before, above).rgb), decode(texture2D(u_after, above).rgb), u_blend) * u_hazeLit;
        haze = mix(min(haze, vec3(mix(40.0, 1.5, u_deck.a))), vec3(dot(min(haze, vec3(1.5)), vec3(0.3, 0.5, 0.2))) * 0.08 + u_deck.rgb * 0.9, u_deck.a); // as it looks under the deck
        float far = aux.r / (1.0 - 0.9 * aux.r);
        float through = exp(-u_haze * far);
        land = land * through + haze * (1.0 - through);
        // Fog swallows the far hills first.
        vec3 fogCol = mix(haze, vec3(dot(haze, vec3(0.3, 0.5, 0.2))), 0.7) * 0.95;
        land = mix(land, fogCol, (1.0 - exp(-far * u_fog)) * 0.97);
        gl_FragColor = vec4(sqrt(1.0 - exp(-land)), 1.0) * photo.a;
    }
    """

    // MARK: - Rain and snow

    /// Rain or snow in layers of depth, drawn by one shader over everything. Drops and flakes take the colour of the
    /// light around them, so like real rain they show against the hills but hardly against the sky.
    private func addPrecipitation() {
        let amount = conditions.precipitation
        guard amount.rain > 0 || amount.snow > 0 else { return }
        let across = simd_dot(conditions.windToward, SIMD2(viewpoint.right.x, viewpoint.right.y)) // + blowing to the right
        precipitation.vectorFloat4Value = [Float(amount.rain), Float(amount.snow), Float(across * min(conditions.wind / 50, 1) * 0.35),
                                           Float(across * conditions.wind / 10)]
        let sheet = SKSpriteNode(color: .black, size: size)
        sheet.anchorPoint = .zero
        sheet.zPosition = 8
        sheet.shader = SKShader(source: shaderCommon + Self.precipitationShader, uniforms: [
            SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)]), clock, precipitation, rainColour, snowColour,
        ])
        addChild(sheet)
    }

    private static let precipitationShader = """
    void main() {
        vec2 pts = v_tex_coord * u_size;
        float t = u_clock;
        // Rain: four depths of streaks, sheared by the wind; far layers fine and dense, near ones long, soft and sparse.
        float rain = 0.0;
        if (u_precip.x > 0.0) {
            for (int i = 0; i < 4; i++) {
                float fi = float(i);
                float cell = 7.0 + fi * 9.0;
                vec2 p = pts + vec2(pts.y * u_precip.z, 0.0);
                p.y += t * (700.0 + fi * 350.0);
                vec2 g = vec2(cell, cell * (5.0 + fi * 2.0));
                vec2 id = floor(p / g);
                vec4 h = hash42(id + fi * 17.0);
                vec2 f = p / g - id;
                float w = (0.6 + fi * 0.5) / cell;
                float x = abs(f.x - 0.15 - 0.7 * h.x) / w;
                float y = f.y - h.y * 0.5;
                rain += step(h.z, u_precip.x * (0.55 - fi * 0.1)) * exp(-x * x) * smoothstep(0.0, 0.15, y) * smoothstep(0.5, 0.2, y) * (0.1 + 0.03 * fi);
            }
        }
        // Snow: five depths of flakes swaying down, the near ones big, soft and out of focus. Each stays inside its
        // cell, or it's clipped into a square.
        float snow = 0.0;
        if (u_precip.y > 0.0) {
            for (int i = 0; i < 5; i++) {
                float fi = float(i);
                float cell = 14.0 + fi * 16.0;
                vec2 p = pts + vec2(-t * u_precip.w * (2.0 + fi), t * (18.0 + fi * 14.0));
                vec2 id = floor(p / cell);
                vec4 h = hash42(id + fi * 31.0);
                float r = 0.8 + fi * fi * 0.35;
                float blur = 0.3 + fi * 0.12;
                float room = max(0.5 - r * (1.0 + blur) / cell - 0.08, 0.0);
                vec2 f = (fract(p / cell) - 0.5 - (h.xy - 0.5) * 2.0 * room * vec2(0.6, 1.0)) * cell;
                f.x += sin(t * (0.6 + h.z) + h.w * 6.28) * cell * room * 0.4;
                float d = length(f) / r;
                snow += step(h.w, u_precip.y * (0.7 - fi * 0.1)) * smoothstep(1.0 + blur, 1.0 - blur, d) * (0.8 - fi * 0.12);
            }
        }
        float a = clamp(rain, 0.0, 1.0);
        float b = clamp(snow, 0.0, 1.0);
        vec3 col = u_rainCol * a * (1.0 - b) + u_snowCol * b;
        gl_FragColor = vec4(col, a * (1.0 - b) + b);
    }
    """

    // MARK: - Lightning

    /// Now and then a flash inside the storm: one to four return strokes 40–80 ms apart that light the cloud from
    /// within around where it strikes (NOAA JetStream). Three in ten also show a branching bolt below the cloud; some
    /// are far off, lighting the horizon. Every 15–45 s, or 8–25 s in a heavy storm.
    private func addLightning() {
        let (least, most) = conditions.code == 95 ? (15.0, 45.0) : (8.0, 25.0)
        let strike = SKAction.run { [weak self] in self?.strike() }
        let pause = SKAction.wait(forDuration: (least + most) / 2, withRange: most - least)
        run(.sequence([.wait(forDuration: 3), .repeatForever(.sequence([strike, pause]))]), withKey: "lightning")
    }

    private var flash: (start: TimeInterval, strokes: [(at: Double, peak: Double)], bolt: SKSpriteNode?)?

    private func strike() {
        guard let start = lastUpdate else { return }
        let strokes = [(0.0, 1.0), (0.06, 0.7), (0.13, 0.9), (0.22, 0.5)].prefix(.random(in: 1...4))
            .map { (at: $0.0 + .random(in: -0.01...0.01), peak: $0.1) }
        let far = Double.random(in: 0...1) < 0.25
        let x = CGFloat.random(in: 0.1...0.9)
        flashPlace.vectorFloat3Value = [Float(x), Float(viewpoint.horizon + (far ? 0.02 : .random(in: 0.12...0.3))), far ? 0.08 : 0.02]
        var bolt: SKSpriteNode?
        if !far && Double.random(in: 0...1) < 0.3 {
            let height = size.height * CGFloat.random(in: 0.14...0.3)
            let node = SKSpriteNode(texture: Self.boltTexture(height: height), size: CGSize(width: height * 0.6, height: height))
            node.anchorPoint = CGPoint(x: 0.5, y: 0)
            node.position = CGPoint(x: x * size.width, y: size.height * (viewpoint.horizon - 0.03))
            node.zPosition = 4 // between the sky and the hills, which hide its foot
            node.blendMode = .add
            node.alpha = 0
            addChild(node)
            bolt = node
        }
        flash?.bolt?.removeFromParent()
        flash = (start, strokes, bolt)
    }

    /// Brightness of the flash `s` seconds in: each stroke decays in about 30 ms, with a glow of continuing current.
    private func flashBrightness(_ s: Double, _ strokes: [(at: Double, peak: Double)]) -> Double {
        strokes.reduce(s < 0.35 ? 0.08 : 0) { sum, stroke in s >= stroke.at ? sum + stroke.peak * exp(-(s - stroke.at) / 0.03) : sum }
    }

    /// A bolt by midpoint displacement with branches (after Reed & Wyvill 1994): a violet glow, a paler halo and a
    /// white core, fading out at the top where it leaves the cloud.
    private static func boltTexture(height: CGFloat) -> SKTexture {
        let size = CGSize(width: height * 0.6, height: height)
        var segments: [(CGPoint, CGPoint, CGFloat)] = [] // from, to, brightness
        func split(_ a: CGPoint, _ b: CGPoint, _ level: Int, _ brightness: CGFloat) {
            guard level > 0 else { segments.append((a, b, brightness)); return }
            let length = hypot(b.x - a.x, b.y - a.y)
            let mid = CGPoint(x: (a.x + b.x) / 2 + .random(in: -0.3...0.3) * length, y: (a.y + b.y) / 2 + .random(in: -0.1...0.1) * length)
            split(a, mid, level - 1, brightness)
            split(mid, b, level - 1, brightness)
            if Double.random(in: 0...1) < 0.35 * pow(0.6, Double(7 - level)) && brightness > 0.3 { // a fork, dimmer and shorter
                let angle = atan2(b.y - a.y, b.x - a.x) + (Bool.random() ? 1 : -1) * .random(in: 0.35...0.7)
                let reach = length * .random(in: 0.5...1.2)
                split(mid, CGPoint(x: mid.x + cos(angle) * reach, y: mid.y + sin(angle) * reach), max(level - 2, 1), brightness * 0.4)
            }
        }
        split(CGPoint(x: size.width * .random(in: 0.35...0.65), y: size.height), CGPoint(x: size.width * .random(in: 0.3...0.7), y: 0), 7, 1)
        return paint(size) { ctx in
            ctx.setLineCap(.round)
            for (width, alpha, colour) in [(14.0, 0.06, (0.6, 0.65, 1.0)), (5.0, 0.22, (0.75, 0.78, 1.0)), (1.4, 1.0, (0.97, 0.96, 1.0))] {
                for (a, b, brightness) in segments {
                    ctx.setStrokeColor(red: colour.0, green: colour.1, blue: colour.2, alpha: alpha * brightness)
                    ctx.setLineWidth(width * (0.5 + 0.5 * brightness))
                    ctx.move(to: a)
                    ctx.addLine(to: b)
                    ctx.strokePath()
                }
            }
            // fade the top into the cloud it comes from
            ctx.setBlendMode(.destinationOut)
            let fade = CGGradient(colorsSpace: nil, colors: [CGColor(gray: 0, alpha: 1), CGColor(gray: 0, alpha: 0)] as CFArray, locations: nil)!
            ctx.drawLinearGradient(fade, start: CGPoint(x: 0, y: size.height), end: CGPoint(x: 0, y: size.height * 0.75), options: [])
        }
    }

    // MARK: - Motion

    override func update(_ currentTime: TimeInterval) {
        let dt = CGFloat(min(max(currentTime - (lastUpdate ?? currentTime), 0), 0.1))
        lastUpdate = currentTime
        skyBlend.floatValue = min(skyBlend.floatValue + Float(dt) / 60, 1) // into the latest sky over a minute
        sinceTrack += dt
        sinceBake += dt
        if sinceTrack >= 1 { sinceTrack = 0; track() }
        if sinceBake >= 60 && !baking { sinceBake = 0; bakeSky() }
        clock.floatValue = (clock.floatValue + Float(dt)).truncatingRemainder(dividingBy: 3600)
        if let (start, strokes, bolt) = flash {
            let brightness = flashBrightness(currentTime - start, strokes)
            flashAmount.floatValue = Float(brightness)
            bolt?.alpha = CGFloat(min(brightness * 1.5, 1))
            if currentTime - start > 0.8 { bolt?.removeFromParent(); flash = nil; flashAmount.floatValue = 0 }
        }
    }
}

// MARK: - Weather kinds


private enum Kind { case clear, partlyCloudy, overcast, fog, drizzle, rain, snow, storm }

private extension WeatherScene.Conditions {
    var kind: Kind {
        switch code {
        case 0, 1: .clear
        case 3: .overcast
        case 45, 48: .fog
        case 51...57: .drizzle
        case 61...67, 80...82: .rain
        case 71...77, 85, 86: .snow
        case 95...99: .storm
        default: .partlyCloudy
        }
    }

    /// The cloud layer: how much of the sky it covers, its base and thickness in km, how flat a sheet it is (0 heaped
    /// cumulus, 1 a featureless deck), and high cirrus. After the cloud each kind of weather comes from: fair-weather
    /// cumulus, stratocumulus when overcast, stratus for drizzle, nimbostratus for rain and snow, cumulonimbus in storms.
    var clouds: (cover: Float, base: Float, thickness: Float, deck: Float, cirrus: Float) {
        let share = Float(cloudCover / 100)
        let cirrus = Float(min(highCloud / 100, 1) * 0.7)
        switch kind {
        case .clear: return (share * 0.5, 1.4, 0.8, 0, cirrus)
        case .partlyCloudy: return (0.15 + share * 0.5, 1.4, 1, 0.1, cirrus)
        case .overcast: return (0.97, 1.0, 1.3, 0.75, 0)
        case .fog: return (1, 0.3, 0.6, 1, 0)
        case .drizzle: return (1, 0.5, 1.6, 0.95, 0)
        case .rain: return (1, 0.8, 2.2, 0.9, 0)
        case .snow: return (1, 0.9, 1.8, 0.95, 0)
        case .storm: return (1, 1.0, 3.2, 0.6, 0)
        }
    }

    /// The way the wind blows, as a unit vector (east, north).
    var windToward: SIMD2<Double> {
        let toward = (windFrom + 180) * .pi / 180
        return [sin(toward), cos(toward)]
    }

    /// Snow lying on the ground, 0…1: a dusting at 1 cm, fully white by 5 cm.
    var snowCover: Double { min(max(snowDepth / 0.05, 0), 1) }

    /// How hard it's raining and snowing, 0…1 each.
    var precipitation: (rain: Double, snow: Double) {
        switch kind {
        case .drizzle: (0.3 * intensity + 0.1, 0)
        case .rain: (0.35 + 0.6 * intensity, 0)
        case .storm: (1, 0)
        case .snow: (0, 0.3 + 0.7 * intensity)
        default: (0, 0)
        }
    }

    /// How thick the fog or mist is, 0…1.
    var fog: Float {
        switch kind {
        case .fog: Float(min(max(1.6 - 0.4 * log10(max(visibility, 50)), 0.35), 0.9)) // 0.9 at 100 m, 0.4 at 1 km
        case .drizzle: 0.25
        case .rain, .storm: Float(0.1 + 0.15 * intensity)
        case .snow: Float(0.15 + 0.2 * intensity)
        default: 0
        }
    }

    /// How much the cloud evens out the light, 0 (clear) to 1 (a full deck).
    var cloudiness: Double {
        switch kind {
        case .clear: 0
        case .partlyCloudy: cloudCover / 100 * 0.4
        default: 1
        }
    }

    /// How hard it's coming down, 0…1, from the code's light, moderate and heavy variants.
    var intensity: CGFloat {
        [51, 56, 61, 66, 71, 77, 80, 85].contains(code) ? 0.35 : [53, 63, 73, 81].contains(code) ? 0.65 : 1
    }
}

private func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
    let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
    return t * t * (3 - 2 * t)
}
