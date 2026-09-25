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
        var isDay = true
        var cloudCover = 40.0 // percent
        var wind = 10.0       // km/h
    }

    private var report: Conditions     // the latest live weather, or the pinned test state
    private var conditions: Conditions // what's on screen: `report`, or the Settings preview
    private let live: Bool
    private var drifting: [(node: SKNode, speed: CGFloat)] = [] // clouds and fog banks, wrapped around in update
    private var lastUpdate: TimeInterval?
    private var viewpoint: SkyCamera
    private var sinceTrack = 0.0, sinceBake = 0.0, baking = false

    // The sky shader's inputs; see `skyShader`.
    private let skyBefore = SKUniform(name: "u_before", texture: nil), skyAfter = SKUniform(name: "u_after", texture: nil)
    private let skyBlend = SKUniform(name: "u_blend", float: 1)
    private let cameraUniforms = (lens: SKUniform(name: "u_cam", vectorFloat4: .zero), forward: SKUniform(name: "u_fwd", vectorFloat3: .zero),
                                  right: SKUniform(name: "u_right", vectorFloat3: .zero))
    private let sunDirection = SKUniform(name: "u_sun", vectorFloat3: [0, 0, 1]), sunDisc = SKUniform(name: "u_disc", vectorFloat3: .zero)
    private let moonPlace = SKUniform(name: "u_moon", vectorFloat4: [0, 0, 0, 0]), moonLight = SKUniform(name: "u_moonLight", vectorFloat3: [0, 0, 1])
    private let moonColour = SKUniform(name: "u_moonCol", vectorFloat3: .zero), starsUniform = SKUniform(name: "u_stars", float: 0)
    private static let moonTexture = SKTexture(imageNamed: resource("weather-moon.png").path)

    /// Pass `conditions` to pin the scene to one state (snapshots); leave it nil to follow the live weather.
    init(size: CGSize, conditions: Conditions? = nil) {
        report = conditions ?? Conditions(isDay: WeatherScene.sunIsUp())
        self.conditions = report
        live = conditions == nil
        viewpoint = SkyCamera(aspect: size.width / size.height, horizon: 0.4, facing: 1.5 * .pi)
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
        run(.repeatForever(.sequence([.wait(forDuration: 60), .run { [weak self] in
            guard let self else { return }
            report.isDay = WeatherScene.sunIsUp()
            redraw()
        }])))
    }

    /// The live weather, or while previewing, the kind and time of day picked in Settings.
    private var wanted: Conditions {
        guard live, Self.knobs[0].value > 0.5 else { return report }
        let kind = min(max(Int(Self.knobs[1].value), 0), 7)
        let hour = Calendar.current.startOfDay(for: Date()).addingTimeInterval(Self.knobs[2].value * 3600)
        return Conditions(code: [0, 2, 3, 45, 53, 63, 73, 95][kind], isDay: Self.sunIsUp(at: hour),
                          cloudCover: [5, 45, 100, 100, 100, 100, 100, 100][kind], wind: 15)
    }

    /// Rebuilds the scene if what it should show has changed.
    @objc private func redraw() {
        guard wanted != conditions else { return }
        conditions = wanted
        build()
    }

    /// Now, or today at the preview hour while previewing.
    private var now: Date {
        guard live, Self.knobs[0].value > 0.5 else { return Date() }
        return Calendar.current.startOfDay(for: Date()).addingTimeInterval(Self.knobs[2].value * 3600)
    }

    /// Whether the Sun is above the horizon where you are (its top edge, allowing for refraction).
    static func sunIsUp(at date: Date = Date()) -> Bool {
        let here = Location.shared.coordinate, jd = Sky.julianDate(date)
        let sun = Sky.horizonMatrix(jd: jd, latitude: here.latitude, longitude: here.longitude) * Sky.sun(jd)
        return sun.z > sin(-0.833 * .pi / 180)
    }

    /// Conditions from an Open-Meteo `current` reply, with day or night from the Sun rather than the reply.
    static func conditions(from reply: Data) -> Conditions? {
        struct Forecast: Decodable {
            struct Current: Decodable {
                let weatherCode: Int, cloudCover: Double, windSpeed: Double
                // Spelled out: .convertFromSnakeCase turns wind_speed_10m into windSpeed10M.
                enum CodingKeys: String, CodingKey {
                    case weatherCode = "weather_code", cloudCover = "cloud_cover", windSpeed = "wind_speed_10m"
                }
            }
            let current: Current
        }
        guard let now = try? JSONDecoder().decode(Forecast.self, from: reply).current else { return nil }
        return Conditions(code: now.weatherCode, isDay: sunIsUp(), cloudCover: now.cloudCover, wind: now.windSpeed)
    }

    /// Fetches the current weather and redraws the scene if it changed. Offline, it keeps showing what it has.
    private func refresh() {
        let spot = Location.shared.coordinate
        var url = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        url.queryItems = [URLQueryItem(name: "latitude", value: String(spot.latitude)),
                          URLQueryItem(name: "longitude", value: String(spot.longitude)),
                          URLQueryItem(name: "current", value: "weather_code,cloud_cover,wind_speed_10m")]
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
        drifting = []
        let kind = conditions.kind, day = conditions.isDay
        let palette = Palette(kind, day: day)
        addSky()

        addClouds(kind, palette: palette)

        let hills = landscape(palette, snowy: kind == .snow)
        hills.zPosition = 5
        addChild(hills)

        switch kind {
        case .fog: addFog(palette, density: 1)
        case .drizzle, .rain, .storm: addFog(palette, density: 0.25)
        case .snow: addFog(palette, density: 0.3)
        default: break
        }
        switch kind {
        case .drizzle: addRain(palette, rate: 90, speed: 520, scale: 0.6)
        case .rain: addRain(palette, rate: 200 + 300 * conditions.intensity, speed: 900, scale: 1)
        case .storm: addRain(palette, rate: 550, speed: 1000, scale: 1.1); addLightning()
        case .snow: addSnow(rate: 50 + 110 * conditions.intensity)
        default: break
        }
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
        ])
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
        skyBefore.textureValue = fade ? skyAfter.textureValue : light.texture
        skyAfter.textureValue = light.texture
        skyBlend.floatValue = fade ? 0 : 1
        let visible: Double = conditions.kind == .clear || conditions.kind == .partlyCloudy ? 1 : 0
        let moonUp: Double = light.moon.z > 0 ? min(light.moonPower / 2.5e-6, 1) : 0
        let dark = smoothstep(-0.07, -0.25, light.sun.z)
        starsUniform.floatValue = Float(dark * (1 - 0.6 * moonUp) * visible)
        sunDisc.vectorFloat3Value = light.sun.z > -0.02 ? SIMD3<Float>(light.sunColour) : .zero
        let night = smoothstep(0.05, -0.1, light.sun.z)
        moonColour.vectorFloat3Value = SIMD3<Float>(Atmosphere.shared.sunlight(viewpoint.height, light.moon.z) * (0.5 + 1.5 * night))
    }

    /// Moves the Sun and Moon to where they are now; they'd hop visibly if they only moved with each minute's bake.
    private func track() {
        let here = Location.shared.coordinate, jd = Sky.julianDate(now)
        let toHorizon = Sky.horizonMatrix(jd: jd, latitude: here.latitude, longitude: here.longitude)
        let sun = normalize(toHorizon * Sky.sun(jd)), moon = normalize(toHorizon * Sky.moon(jd))
        sunDirection.vectorFloat3Value = SIMD3<Float>(sun)
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
        // The Sun: a limb-darkened disc and a soft photographic glow.
        float ang = acos(clamp(dot(rd, u_sun), -1.0, 1.0));
        float disc = smoothstep(0.0050, 0.0044, ang);
        col += u_disc * (disc * 60.0 * (0.6 + 0.4 * sqrt(max(1.0 - ang * ang / 0.000022, 0.0))) + 0.25 * exp(-ang * 40.0) + 0.02 * exp(-ang * 8.0));
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
        col = sqrt(1.0 - exp(-col)); // film-like roll-off, then roughly sRGB
        gl_FragColor = vec4(col + (hash21(pts * 2.0) - 0.5) / 128.0, 1.0);
    }
    """

    /// Wisps on a fair day, a full deck when it's grey; bigger clouds sit closer and drift faster in the wind.
    private func addClouds(_ kind: Kind, palette: Palette) {
        let deck = [.overcast, .drizzle, .rain, .snow, .storm].contains(kind)
        let count = kind == .fog ? 0 : deck ? 16 : Int(conditions.cloudCover / 100 * 10)
        let looks = (0..<3).map { _ in cloudTexture(light: palette.cloudLight, shade: palette.cloudShade) }
        for _ in 0..<count {
            let scale = deck ? CGFloat.random(in: 1.3...2.1) : .random(in: 0.8...1.5)
            let cloud = SKSpriteNode(texture: looks.randomElement()!, size: CGSize(width: 340 * scale, height: 140 * scale))
            cloud.position = CGPoint(x: .random(in: 0...size.width),
                                     y: deck ? .random(in: size.height * 0.66...size.height * 1.02) : .random(in: size.height * 0.6...size.height * 0.92))
            cloud.alpha = deck ? .random(in: 0.85...1) : 0.95
            cloud.zPosition = 3 + scale / 10 // bigger (closer) clouds in front
            addChild(cloud)
            drifting.append((cloud, (4 + CGFloat(conditions.wind) * 0.5) * scale * .random(in: 0.8...1.2)))
        }
    }

    /// A haze that thickens toward the far hills, plus slow banks of mist drifting through.
    private func addFog(_ palette: Palette, density: CGFloat) {
        let haze = SKSpriteNode(texture: gradient([palette.fog.withAlpha(0.35 * density), palette.fog.withAlpha(0.8 * density),
                                                   palette.fog.withAlpha(0.55 * density), palette.fog.withAlpha(0.15 * density)]), size: size)
        haze.anchorPoint = .zero
        haze.zPosition = 6
        addChild(haze)
        guard density >= 1 else { return }
        let bank = paint(CGSize(width: 200, height: 60)) { ctx in
            ctx.scaleBy(x: 1, y: 0.3) // squash a round puff into a long bank
            let puff = CGGradient(colorsSpace: nil, colors: [palette.fog.cg(0.7), palette.fog.cg(0)] as CFArray, locations: nil)!
            ctx.drawRadialGradient(puff, startCenter: CGPoint(x: 100, y: 100), startRadius: 0, endCenter: CGPoint(x: 100, y: 100), endRadius: 100, options: [])
        }
        for i in 0..<5 {
            let mist = SKSpriteNode(texture: bank, size: CGSize(width: size.width * 0.9, height: size.height * 0.22))
            mist.position = CGPoint(x: .random(in: 0...size.width), y: size.height * (0.08 + 0.08 * CGFloat(i)))
            mist.zPosition = 6
            addChild(mist)
            drifting.append((mist, .random(in: 5...12)))
        }
    }

    /// Streaks falling at an angle that leans further with the wind.
    private func addRain(_ palette: Palette, rate: CGFloat, speed: CGFloat, scale: CGFloat) {
        let lean = min(CGFloat(conditions.wind) / 50, 1) * 0.45
        let rain = SKEmitterNode()
        rain.particleTexture = paint(CGSize(width: 2, height: 26)) { ctx in
            let streak = CGGradient(colorsSpace: nil, colors: [CGColor(gray: 1, alpha: 0), CGColor(gray: 1, alpha: 1)] as CFArray, locations: nil)!
            ctx.drawLinearGradient(streak, start: CGPoint(x: 1, y: 26), end: CGPoint(x: 1, y: 0), options: [])
        }
        rain.particleSize = CGSize(width: 2, height: 26)
        rain.particleBirthRate = rate
        rain.particleSpeed = speed
        rain.particleSpeedRange = speed * 0.2
        rain.emissionAngle = -.pi / 2 + lean
        rain.particleRotation = lean
        rain.particleLifetime = size.height * 1.15 / (speed * cos(lean))
        rain.particleScale = scale
        rain.particleScaleRange = 0.3
        rain.particleAlpha = conditions.isDay ? 0.45 : 0.3
        rain.particleColor = palette.rain.ns
        rain.particleColorBlendFactor = 1
        rain.position = CGPoint(x: size.width / 2 - tan(lean) * size.height / 2, y: size.height + 20)
        rain.particlePositionRange = CGVector(dx: size.width + tan(lean) * size.height, dy: 0)
        rain.zPosition = 8
        rain.advanceSimulationTime(TimeInterval(rain.particleLifetime)) // already raining when it appears
        addChild(rain)
    }

    private func addSnow(rate: CGFloat) {
        let snow = SKEmitterNode()
        snow.particleTexture = paint(CGSize(width: 12, height: 12)) { ctx in
            let flake = CGGradient(colorsSpace: nil, colors: [CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 0)] as CFArray, locations: [0.35, 1])!
            ctx.drawRadialGradient(flake, startCenter: CGPoint(x: 6, y: 6), startRadius: 0, endCenter: CGPoint(x: 6, y: 6), endRadius: 6, options: [])
        }
        snow.particleSize = CGSize(width: 12, height: 12)
        snow.particleBirthRate = rate
        snow.particleSpeed = 55
        snow.particleSpeedRange = 30
        snow.emissionAngle = -.pi / 2
        snow.xAcceleration = CGFloat(conditions.wind) * 0.6
        snow.particleLifetime = size.height / 35
        snow.particleScale = 0.6
        snow.particleScaleRange = 0.5
        snow.particleAlpha = conditions.isDay ? 0.95 : 0.7
        snow.position = CGPoint(x: size.width / 2 - CGFloat(conditions.wind) * 8, y: size.height + 10)
        snow.particlePositionRange = CGVector(dx: size.width * 1.4, dy: 0)
        let sway = SKAction.moveBy(x: 14, y: 0, duration: 1.4)
        sway.timingMode = .easeInEaseOut
        snow.particleAction = .repeatForever(.sequence([sway, sway.reversed()]))
        snow.zPosition = 8
        snow.advanceSimulationTime(TimeInterval(snow.particleLifetime))
        addChild(snow)
    }

    /// Every several seconds: a jagged bolt behind the hills and a double flicker across the whole sky.
    private func addLightning() {
        let flash = SKSpriteNode(color: NSColor(red: 0.85, green: 0.88, blue: 1, alpha: 1), size: size)
        flash.anchorPoint = .zero
        flash.alpha = 0
        flash.zPosition = 9
        addChild(flash)
        let strike = SKAction.run { [weak self, weak flash] in
            guard let self, let flash else { return }
            let bolt = CGMutablePath()
            var point = CGPoint(x: .random(in: self.size.width * 0.15...self.size.width * 0.85), y: self.size.height * 0.78)
            bolt.move(to: point)
            while point.y > self.size.height * 0.25 {
                point = CGPoint(x: point.x + .random(in: -40...40), y: point.y - .random(in: 20...55))
                bolt.addLine(to: point)
            }
            let node = SKShapeNode(path: bolt)
            node.strokeColor = NSColor(red: 0.92, green: 0.9, blue: 1, alpha: 1)
            node.lineWidth = 2.5
            node.glowWidth = 5
            node.zPosition = 4
            self.addChild(node)
            node.run(.sequence([.wait(forDuration: 0.12), .fadeOut(withDuration: 0.3), .removeFromParent()]))
            flash.run(.sequence([.fadeAlpha(to: 0.5, duration: 0.04), .fadeAlpha(to: 0.08, duration: 0.08),
                                 .fadeAlpha(to: 0.35, duration: 0.04), .fadeOut(withDuration: 0.5)]))
        }
        run(.sequence([.wait(forDuration: 2.5), .repeatForever(.sequence([strike, .wait(forDuration: 9, withRange: 10)]))]),
            withKey: "lightning")
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
        for (node, speed) in drifting {
            node.position.x += speed * dt
            let half = node.frame.width / 2
            if node.position.x - half > size.width { node.position.x = -half } // ponytail: wind always blows left to right
        }
    }

    // MARK: - Painting

    /// Three ranges of hills, hazier with distance, dotted with pines and round trees. Painted once per build.
    private func landscape(_ p: Palette, snowy: Bool) -> SKSpriteNode {
        let area = CGSize(width: size.width, height: size.height * 0.46)
        var rng = Seeded(state: 11) // the same hills and trees every time
        let texture = paint(area) { ctx in
            let ranges: [(base: CGFloat, freq: CGFloat, phase: CGFloat, colour: RGB, trees: Int, treeHeight: CGFloat)] = [
                (0.78, 1.3, 0.8, p.far, 0, 0),
                (0.52, 2.1, 2.4, p.mid, Int(area.width / 55), size.height * 0.05),
                (0.24, 1.6, 4.1, p.near, Int(area.width / 160), size.height * 0.11),
            ]
            for range in ranges {
                func ridge(_ x: CGFloat) -> CGFloat {
                    let t = x / area.width * .pi * 2 * range.freq
                    return area.height * (range.base + 0.1 * sin(t + range.phase) + 0.04 * sin(t * 2.7 + range.phase * 1.7))
                }
                let hill = CGMutablePath()
                hill.move(to: .zero)
                for x in stride(from: 0, through: area.width + 8, by: 8) { hill.addLine(to: CGPoint(x: x, y: ridge(x))) }
                hill.addLine(to: CGPoint(x: area.width + 8, y: 0))
                hill.closeSubpath()
                ctx.saveGState()
                ctx.addPath(hill)
                ctx.clip()
                let shade = CGGradient(colorsSpace: nil, colors: [(range.colour * 1.08).cg(), (range.colour * 0.82).cg()] as CFArray, locations: nil)!
                ctx.drawLinearGradient(shade, start: CGPoint(x: 0, y: area.height * (range.base + 0.14)), end: CGPoint(x: 0, y: 0), options: [])
                ctx.restoreGState()

                let treeColour = range.colour == p.mid ? mix(p.tree, p.mid, 0.35) : p.tree // distant trees fade into their hill
                for _ in 0..<range.trees {
                    let x = CGFloat.random(in: 0...area.width, using: &rng)
                    let y = ridge(x) - .random(in: 0...area.height * 0.08, using: &rng)
                    let height = range.treeHeight * .random(in: 0.6...1.2, using: &rng)
                    if Bool.random(using: &rng) || snowy {
                        pine(ctx, x: x, y: y, height: height, colour: treeColour, snow: snowy ? p.near : nil)
                    } else {
                        roundTree(ctx, x: x, y: y, height: height, colour: treeColour)
                    }
                }
            }
        }
        let node = SKSpriteNode(texture: texture, size: area)
        node.anchorPoint = .zero
        return node
    }

    private func pine(_ ctx: CGContext, x: CGFloat, y: CGFloat, height: CGFloat, colour: RGB, snow: RGB?) {
        ctx.setFillColor((colour * 0.6 + RGB(0.08, 0.04, 0)).cg())
        ctx.fill(CGRect(x: x - height * 0.035, y: y - height * 0.05, width: height * 0.07, height: height * 0.22))
        for tier in 0..<3 {
            let base = y + height * (0.14 + 0.24 * CGFloat(tier)), half = height * (0.28 - 0.06 * CGFloat(tier))
            let apex = CGPoint(x: x, y: base + height * 0.42)
            ctx.setFillColor(colour.cg())
            ctx.addLines(between: [CGPoint(x: x - half, y: base), CGPoint(x: x + half, y: base), apex])
            ctx.fillPath()
            if let snow {
                ctx.setFillColor(snow.cg())
                ctx.addLines(between: [CGPoint(x: x - half * 0.45, y: base + height * 0.23), CGPoint(x: x + half * 0.45, y: base + height * 0.23), apex])
                ctx.fillPath()
            }
        }
    }

    private func roundTree(_ ctx: CGContext, x: CGFloat, y: CGFloat, height: CGFloat, colour: RGB) {
        ctx.setFillColor((colour * 0.6 + RGB(0.1, 0.05, 0)).cg())
        ctx.fill(CGRect(x: x - height * 0.04, y: y - height * 0.05, width: height * 0.08, height: height * 0.45))
        for (dx, dy, r) in [(-0.14, 0.52, 0.2), (0.14, 0.55, 0.19), (0, 0.72, 0.24)] as [(CGFloat, CGFloat, CGFloat)] {
            ctx.setFillColor((colour * (dy > 0.6 ? 1.1 : 1)).cg()) // the crown catches more light
            ctx.fillEllipse(in: CGRect(x: x + dx * height - r * height, y: y + dy * height - r * height, width: r * height * 2, height: r * height * 2))
        }
    }

    /// A puffy cloud: overlapping ellipses, lit on top and shaded underneath, with soft edges.
    private func cloudTexture(light: RGB, shade: RGB) -> SKTexture {
        paint(CGSize(width: 340, height: 140)) { ctx in
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            ctx.setShadow(offset: .zero, blur: 10, color: light.cg(0.8))
            ctx.setFillColor(light.cg())
            ctx.addPath(CGPath(roundedRect: CGRect(x: 30, y: 20, width: 280, height: 34), cornerWidth: 17, cornerHeight: 17, transform: nil))
            ctx.fillPath() // flat base
            ctx.saveGState()
            ctx.clip(to: CGRect(x: 0, y: 20, width: 340, height: 120)) // cumulus have flat bottoms
            for i in 0..<9 { // a dome of puffs, biggest in the middle
                let r = (14 + 30 * sin(.pi * CGFloat(i) / 8)) * .random(in: 0.75...1.05)
                let x = 48 + CGFloat(i) * 30 + .random(in: -8...8)
                ctx.fillEllipse(in: CGRect(x: x - r, y: 22 + r * 0.9 - r, width: r * 2, height: r * 2))
            }
            ctx.restoreGState()
            ctx.setShadow(offset: .zero, blur: 0)
            ctx.setBlendMode(.sourceAtop)
            let underside = CGGradient(colorsSpace: nil, colors: [shade.cg(), shade.cg(0)] as CFArray, locations: nil)!
            ctx.drawLinearGradient(underside, start: CGPoint(x: 0, y: 20), end: CGPoint(x: 0, y: 70), options: [])
            ctx.endTransparencyLayer()
        }
    }

    /// A vertical gradient texture from bottom to top, stretched over whatever sprite uses it.
    private func gradient(_ colours: [CGColor]) -> SKTexture {
        paint(CGSize(width: 4, height: 256)) { ctx in
            let g = CGGradient(colorsSpace: nil, colors: colours as CFArray, locations: nil)!
            ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: 256), options: [])
        }
    }
}

// MARK: - Weather kinds and colours

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

    /// How hard it's coming down, 0…1, from the code's light, moderate and heavy variants.
    var intensity: CGFloat {
        [51, 56, 61, 66, 71, 77, 80, 85].contains(code) ? 0.35 : [53, 63, 73, 81].contains(code) ? 0.65 : 1
    }
}

/// Colours for one kind of weather. At night everything dims toward moonlit blue.
private struct Palette {
    var skyTop, skyBottom, far, mid, near, tree, cloudLight, cloudShade, fog, rain: RGB

    init(_ kind: Kind, day: Bool) {
        switch kind {
        case .clear, .partlyCloudy:
            (skyTop, skyBottom, far, mid, near, tree) = (rgb(74, 144, 226), rgb(182, 216, 242), rgb(140, 174, 182), rgb(106, 152, 98), rgb(74, 126, 66), rgb(38, 86, 52))
            (cloudLight, cloudShade) = (rgb(255, 255, 255), rgb(206, 216, 232))
        case .overcast:
            (skyTop, skyBottom, far, mid, near, tree) = (rgb(146, 154, 166), rgb(196, 200, 206), rgb(150, 160, 162), rgb(112, 138, 104), rgb(86, 114, 78), rgb(52, 80, 58))
            (cloudLight, cloudShade) = (rgb(212, 216, 222), rgb(156, 162, 174))
        case .fog:
            (skyTop, skyBottom, far, mid, near, tree) = (rgb(190, 194, 198), rgb(214, 216, 218), rgb(186, 190, 192), rgb(148, 162, 150), rgb(104, 126, 98), rgb(70, 92, 72))
            (cloudLight, cloudShade) = (rgb(222, 224, 226), rgb(196, 200, 204))
        case .drizzle, .rain:
            (skyTop, skyBottom, far, mid, near, tree) = (rgb(104, 114, 130), rgb(156, 164, 176), rgb(124, 136, 140), rgb(84, 112, 82), rgb(60, 94, 56), rgb(38, 68, 44))
            (cloudLight, cloudShade) = (rgb(150, 156, 168), rgb(98, 104, 118))
        case .snow:
            (skyTop, skyBottom, far, mid, near, tree) = (rgb(172, 182, 198), rgb(220, 224, 232), rgb(206, 214, 228), rgb(222, 228, 238), rgb(238, 242, 248), rgb(50, 78, 68))
            (cloudLight, cloudShade) = (rgb(218, 222, 230), rgb(176, 182, 196))
        case .storm:
            (skyTop, skyBottom, far, mid, near, tree) = (rgb(48, 54, 70), rgb(98, 104, 118), rgb(82, 94, 100), rgb(56, 78, 58), rgb(42, 62, 42), rgb(26, 46, 32))
            (cloudLight, cloudShade) = (rgb(94, 100, 116), rgb(52, 56, 70))
        }
        fog = mix(skyBottom, RGB(repeating: 1), 0.3)
        rain = rgb(206, 214, 228)
        guard !day else { return }
        let moonlit = RGB(0.22, 0.26, 0.42), tint = rgb(2, 3, 8)
        (far, mid, near, tree) = (far * moonlit + tint, mid * moonlit + tint, near * moonlit + tint, tree * moonlit + tint)
        (cloudLight, cloudShade) = (cloudLight * RGB(0.3, 0.33, 0.46), cloudShade * RGB(0.26, 0.28, 0.4))
        (fog, rain) = (fog * RGB(0.3, 0.34, 0.46), rain * 0.5)
        if kind == .clear || kind == .partlyCloudy {
            (skyTop, skyBottom) = (rgb(8, 12, 32), rgb(30, 44, 84))
        } else {
            (skyTop, skyBottom) = (skyTop * RGB(0.2, 0.22, 0.3), skyBottom * RGB(0.26, 0.28, 0.36)) // a low, dim ceiling
        }
    }
}

private typealias RGB = SIMD3<Double>

private func rgb(_ r: Int, _ g: Int, _ b: Int) -> RGB { RGB(Double(r), Double(g), Double(b)) / 255 }
private func mix(_ a: RGB, _ b: RGB, _ t: Double) -> RGB { a + (b - a) * t }
private func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
    let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
    return t * t * (3 - 2 * t)
}

private extension SIMD3<Double> {
    func cg(_ alpha: CGFloat = 1) -> CGColor { CGColor(srgbRed: Swift.min(x, 1), green: Swift.min(y, 1), blue: Swift.min(z, 1), alpha: alpha) }
    func withAlpha(_ alpha: CGFloat) -> CGColor { cg(alpha) }
    var ns: NSColor { NSColor(srgbRed: Swift.min(x, 1), green: Swift.min(y, 1), blue: Swift.min(z, 1), alpha: 1) }
}

/// Seeded random numbers (SplitMix64), so the hills and trees don't reshuffle every time the weather changes.
private struct Seeded: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
