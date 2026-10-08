import CoreLocation
import SpriteKit

@MainActor func dappledLight(size: CGSize) -> SKScene { DappledLight(size: size) }

/// Sunlight through a tree onto a plaster wall, lit by the real Sun where you are. Every gap between the leaves is a
/// pinhole camera, so the bright spots are images of the Sun: round, 0.0093 × the gap's distance across, stretched
/// by the angle the light meets the wall, and crescents during a real eclipse. Leaves near the wall cast sharp
/// shadows. Cloud cover and wind can come from the live weather; by night, a warm streetlight or moonlight at the real
/// phase. The wall can be plaster, limewash, brick or painted siding, or an oak floor in the open or by a window.
/// Made for Light Mode; in Dark Mode the white plaster is charcoal.
final class DappledLight: SKScene {
    /// What the light falls on: scans from Poly Haven and ambientCG (CC0, credited in dappled-credits.tsv). The
    /// albedo is greyscale, tinted by `colour` in linear light (`dark` in Dark Mode), or with none in its own colours.
    /// Its relief is the slope across and up (`-nx`, `-ny`) and, for relief deep enough to shade itself, `depth`
    /// metres of height (`-height`). It tiles every `tile` metres. A floor lies flat, the light coming from the top
    /// of the screen, through a window or in the open.
    struct Surface {
        let name: String, albedo: String, relief: String
        var colour: SIMD3<Float>?, dark: SIMD3<Float>?
        var tile: SIMD2<Float> = [2, 2]
        var depth: Float = 0
        var floor = false, window = false
    }
    nonisolated static let surfaces = [
        // Warm white stucco; in Dark Mode the same stucco in charcoal (the colour of Poly Haven's Plastered Wall 05),
        // which Dave picked over a dim white wall, dark green or terracotta.
        Surface(name: "White plaster", albedo: "plaster-albedo", relief: "plaster", colour: [0.693, 0.658, 0.630], dark: [0.060, 0.066, 0.074]),
        Surface(name: "Terracotta limewash", albedo: "limewash-albedo", relief: "plaster", colour: [0.530, 0.201, 0.142]), // F&B Red Earth
        Surface(name: "Clay plaster", albedo: "clay-albedo", relief: "clay", colour: [0.384, 0.290, 0.220]), // the scan's own colour
        Surface(name: "Whitewashed brick", albedo: "brick-albedo", relief: "brick", depth: 0.012),
        // Lap siding: each board's lip shades a line under it, wider the higher the Sun.
        Surface(name: "Sage siding", albedo: "siding-albedo", relief: "siding", colour: [0.216, 0.339, 0.276], tile: [2, 1], depth: 0.015),
        Surface(name: "Dusty blue siding", albedo: "siding-albedo", relief: "siding", colour: [0.344, 0.459, 0.573], tile: [2, 1], depth: 0.015),
        Surface(name: "Oak floor", albedo: "oak-albedo", relief: "oak", colour: [0.592, 0.379, 0.198], tile: [1.2, 1.2], floor: true),
        Surface(name: "Oak floor by a window", albedo: "oak-albedo", relief: "oak", colour: [0.592, 0.379, 0.198], tile: [1.2, 1.2],
                floor: true, window: true),
    ]

    nonisolated static let knobs = [
        Knob(key: "dappled.surface", label: "Surface", range: 0...Double(surfaces.count - 1), standard: 0, section: "Wall",
             format: .choice(surfaces.map(\.name))),
        Knob(key: "dappled.facing", label: "Wall faces", range: 0...8, standard: 0, section: "Wall",
             format: .choice(["Toward the Sun", "South", "South-west", "West", "North-west", "North", "North-east", "East", "South-east"])),
        Knob(key: "dappled.cover", label: "Leaf cover", range: 0...1, standard: 0.5, section: "Wall"),
        Knob(key: "dappled.twig", label: "Leaves near the wall", range: 0...1, standard: 1, section: "Wall", format: .toggle),
        // Clear by default, so a first look on a cloudy day still shows the dapples.
        Knob(key: "dappled.weather", label: "Weather", range: 0...3, standard: 1, section: "Light",
             format: .choice(["Live where you are", "Clear", "Partly cloudy", "Overcast"])),
        Knob(key: "dappled.night", label: "At night", range: 0...1, standard: 1, section: "Light",
             format: .choice(["Moonlight", "Streetlight"])),
        Knob(key: "dappled.sway", label: "Sway", range: 0...3, standard: 1, section: "Light", format: .times),
        Knob(key: "dappled.previewTime", label: "Preview a time of day", range: 0...1, standard: 0, section: "Preview",
             format: .toggle),
        Knob(key: "dappled.previewHour", label: "Time", range: 0...24, standard: 13, section: "Preview", format: .clock,
             shownWhen: "dappled.previewTime"),
        Knob(key: "dappled.previewEclipse", label: "Preview an eclipse", range: 0...1, standard: 0, section: "Preview",
             format: .toggle),
    ]
    private enum K: Int { case surface, facing, cover, twig, weather, night, sway, previewTime, previewHour, previewEclipse }
    private static func knob(_ k: K) -> Double { knobs[k.rawValue].value }

    typealias V = SIMD3<Double>
    /// Metres of wall across the screen, and how far each layer of leaves is from the wall: the far crown, whose
    /// shadow is a soft mass with round dapples in it, sprays of leaves soft at the edges, and a twig close enough to
    /// cast a sharp shadow.
    private static let wallWidth = 2.4, far = 5.0, mid = 1.2, near = 0.25

    private let wall = SKSpriteNode()
    private let proj = SKUniform(name: "u_proj", vectorFloat4: .zero), invL = SKUniform(name: "u_invL", float: 0)
    private let shiftFar = SKUniform(name: "u_shiftFar", vectorFloat2: .zero), shiftNear = SKUniform(name: "u_shiftNear", vectorFloat4: .zero)
    private let blur = SKUniform(name: "u_blur", vectorFloat4: .zero)
    private let source = SKUniform(name: "u_src", vectorFloat4: [0, 0, 0, 1]), terminator = SKUniform(name: "u_term", vectorFloat2: [1, 0])
    private let direct = SKUniform(name: "u_light", vectorFloat3: .zero), ambient = SKUniform(name: "u_amb", vectorFloat3: .zero)
    private let direction = SKUniform(name: "u_dir", vectorFloat3: [0, 0, 1])
    private let wind = SKUniform(name: "u_wind", vectorFloat4: .zero), twigPose = SKUniform(name: "u_twigPose", vectorFloat4: .zero)
    private let tint = SKUniform(name: "u_wall", vectorFloat3: .zero), night = SKUniform(name: "u_night", float: 0)
    private let albedo = SKUniform(name: "u_albedo", texture: nil), relief = SKUniform(name: "u_relief", texture: nil)
    /// The surface's tile size in metres, the depth of its relief, and 1 for a window.
    private let surfaceShape = SKUniform(name: "u_surface", vectorFloat4: .zero)

    /// The light as of the last `light()`: direct light at the wall (normal to the rays) and skylight, before
    /// clouds, and the exposure the eye has settled on.
    private var lit = (direct: V.zero, sky: V.zero, overcastSky: V.zero, exposure: 1.0)
    private var conditions = LiveWeather.Conditions(code: 1, cloudCover: 10, wind: 8)
    private var sinceLight = 0.0, clock = 0.0, lastUpdate: TimeInterval?
    /// The twig's base in the plane of its leaves, fixed when the surface is picked so its shadow starts on screen.
    private var twigBase = SIMD2<Double>.zero
    private var surface = surfaces[0]
    /// The albedo's tint in linear light, over the texture's mean, and whether it's the charcoal wall of Dark Mode.
    private var wallColour = SIMD3<Float>(repeating: 1), charcoal = false
    private let dark = systemIsDark

    override init(size: CGSize) {
        super.init(size: size)
        wall.size = size
        wall.anchorPoint = .zero
        wall.shader = SKShader(source: shaderCommon + Self.shaderSource, uniforms: [
            SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)]),
            SKUniform(name: "u_mpp", float: Float(Self.wallWidth / size.width)),
            albedo, relief, surfaceShape, SKUniform(name: "u_noise", texture: CloudNoise.texture),
            SKUniform(name: "u_canopy", texture: Self.canopy), SKUniform(name: "u_twig", texture: Self.twig),
            proj, invL, shiftFar, shiftNear, blur, source, terminator, direct, ambient, direction, wind, twigPose, tint, night,
            WallpaperTime.now,
        ])
        addChild(wall)
        conditions = wanted
        pickSurface()
        update(0)
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: UserDefaults.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: LiveWeather.changed, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func didMove(to view: SKView) {
        guard action(forKey: "poll") == nil else { return }
        Location.shared.start()
        run(.sequence([.wait(forDuration: 2), // give a remembered location fix a moment to land
                       .repeatForever(.sequence([.run { LiveWeather.shared.poll() }, .wait(forDuration: 900)]))]),
            withKey: "poll")
    }

    @objc private func settingsChanged() {
        conditions = wanted
        if Self.surfaces[surfaceIndex].name != surface.name { pickSurface() } else { light() }
    }

    private var surfaceIndex: Int { min(max(Int(Self.knob(.surface).rounded()), 0), Self.surfaces.count - 1) }

    /// Puts the chosen surface into the shader and works out the light on it, with the twig's shadow back on screen.
    private func pickSurface() {
        surface = Self.surfaces[surfaceIndex]
        let textures = Self.textures(surface)
        albedo.textureValue = textures.albedo
        relief.textureValue = textures.relief
        surfaceShape.vectorFloat4Value = [surface.tile.x, surface.tile.y, surface.depth, surface.window ? 1 : 0]
        charcoal = dark && surface.dark != nil
        wallColour = ((charcoal ? surface.dark : nil) ?? surface.colour).map { $0 / textures.mean } ?? [1, 1, 1]
        light()
        twigBase = SIMD2(0.42, 0.33) * SIMD2(Self.wallWidth, Self.wallWidth * size.height / size.width) - shift(Self.near)
    }

    /// The live weather, or what Settings locks it to. Before the first report, a mostly clear day with a breeze.
    private var wanted: LiveWeather.Conditions {
        switch Int(Self.knob(.weather)) {
        case 1: LiveWeather.Conditions(code: 0, cloudCover: 0, wind: 8)
        case 2: LiveWeather.Conditions(code: 2, cloudCover: 45, wind: 12)
        case 3: LiveWeather.Conditions(code: 3, cloudCover: 100, wind: 12)
        default: LiveWeather.shared.latest ?? LiveWeather.Conditions(code: 1, cloudCover: 10, wind: 8)
        }
    }

    /// Now, or today at the preview hour while previewing.
    private var now: Date {
        guard Self.knob(.previewTime) > 0.5 else { return Date() }
        return Calendar.current.startOfDay(for: Date()).addingTimeInterval(Self.knob(.previewHour) * 3600)
    }

    // MARK: - The light

    /// The wall's frame in (east, north, up): the way it faces, and right and up as seen looking at it. Toward the Sun,
    /// it turns to face `light` (the Sun, or the Moon by moonlight), so the light falls whenever that's up. A floor
    /// faces up, with the way the wall would face (the window's, or the light's) at the top of the screen.
    private func wallFrame(facing light: V) -> (out: V, right: V, up: V) {
        let choice = Self.knob(.facing).rounded()
        let level = SIMD2(light.x, light.y)
        let out = choice < 0.5 && length(level) > 1e-6 ? V(normalize(level).x, normalize(level).y, 0)
            : V(sin((135 + 45 * choice) * .pi / 180), cos((135 + 45 * choice) * .pi / 180), 0)
        if surface.floor { return (V(0, 0, 1), V(out.y, -out.x, 0), out) }
        return (out, V(-out.y, out.x, 0), V(0, 0, 1))
    }

    /// The light falling from `from` (a unit vector in the wall's frame: right, up, out), in wall metres: how far the
    /// shadow of something `depth` metres out from the wall lands from it.
    private var from = V(0, 0.5, 0.87)
    private func shift(_ depth: Double) -> SIMD2<Double> { -SIMD2(from.x, from.y) * depth / max(from.z, 0.25) }

    /// Works out where the light comes from and how strong and what colour it is, from the real Sun, Moon and weather.
    /// Runs every second and on any change in Settings or the weather.
    private func light() {
        let date = now, jd = Sky.julianDate(date), here = Location.shared.coordinate
        let toHorizon = Sky.horizonMatrix(jd: jd, latitude: here.latitude, longitude: here.longitude)
        let sun = normalize(toHorizon * Sky.sun(jd))
        let moonSeen = Sky.moon(jd, latitude: here.latitude, longitude: here.longitude)
        let moon = normalize(toHorizon * moonSeen.direction)
        let air = Atmosphere.shared
        let altitude = asin(sun.z) * 180 / .pi
        let isNight = altitude < -1.5
        // Below the horizon neither light shows, so turning from the Sun to the Moon there can't be seen.
        let wallFrame = self.wallFrame(facing: isNight && Self.knob(.night) < 0.5 ? moon : sun)
        func onWall(_ v: V) -> V { V(dot(v, wallFrame.right), dot(v, wallFrame.up), dot(v, wallFrame.out)) }

        // Skylight on the wall: blue by day, fading through twilight to the glow of towns. Photos of leaf shadows on
        // walls put sunlit wall at 7–8 times the shade by day, 4 at golden hour.
        let skyDay = V(0.80, 0.88, 1.0) * 0.075 * sqrt(max(sun.z, 0) + 0.02)
        let skyDusk = V(0.72, 0.79, 1.0) * 0.0106 * exp(min(altitude, 0) / 3.2)
        var sky = (altitude > 0 ? skyDay : skyDusk) + V(0.9, 0.85, 0.8) * 3e-7
        var overcastSky = V(0.93, 0.95, 1.0) * (0.3 * pow(max(sun.z + 0.05, 0), 0.8) + 0.004 * exp(min(altitude, 0) / 3.2)) + V(1, 0.8, 0.6) * 5e-7

        // The source of direct light: the Sun by day; by night the Moon (its phase cut into each image) or a lamp.
        var toward = sun, radius = 0.2666 * .pi / 180 / (1 - 0.0167 * cos((357.53 + 0.98560028 * (jd - 2451545)) * .pi / 180))
        var strength = pow(air.sunlight(0.2, sun.z), V(repeating: 2)) // the low air is hazier than the model's, so twice the path
        var mask = SIMD4<Float>(0, 0, 0, 1)
        var term = SIMD2<Float>(1, 0)
        if !isNight {
            // The Moon over the Sun, seen from here; or a partial eclipse to preview.
            let moonRadius = asin(1737.4 / moonSeen.km)
            let (e1, e2) = basis(sun)
            var offset = SIMD2(dot(moon, e1), dot(moon, e2)) / radius
            var ratio = moonRadius / radius
            let preview = Self.knob(.previewEclipse) > 0.5
            if preview { (offset, ratio) = (SIMD2(0.55, 0.45), 1.02) }
            if (preview || dot(moon, sun) > 0.99) && length(offset) < 1 + ratio {
                mask = SIMD4(Float(offset.x), Float(offset.y), Float(ratio), 1)
                let covered = Self.overlap(1, ratio, length(offset)) / .pi
                strength *= 1 - covered
                sky *= 1 - 0.97 * covered
                overcastSky *= 1 - 0.97 * covered
            }
        } else if Self.knob(.night) > 0.5 {
            // A streetlight up to the left, warm, on from a little after sunset.
            toward = wallFrame.right * -0.55 + wallFrame.up * 0.35 + wallFrame.out * 0.76
            toward = normalize(toward)
            radius = 0.008 // a 20 cm globe 12 m away
            strength = V(1.0, 0.55, 0.2) * 0.002 * smoothstep(-1.5, -4, altitude) // sodium orange
            sky += strength * 0.06
        } else {
            // Moonlight: a 2.5-millionth of sunlight at full, falling off faster than the lit fraction, and each
            // gap's image is the Moon's phase.
            let lit = (1 - dot(moon, sun)) / 2
            toward = moon
            radius = asin(1737.4 / moonSeen.km)
            strength = air.sunlight(0.2, moon.z) * 2.5e-6 * pow(lit, 2.5)
            sky += strength * 0.15
            let (e1, e2) = basis(moon)
            let toSun = SIMD2(dot(sun, e1), dot(sun, e2))
            term = SIMD2<Float>(normalize(toSun))
            mask = SIMD4(0, 0, 0, Float(-dot(sun, moon)))
        }

        let seen = onWall(toward)
        from = seen
        // The source is in front of the wall, above the horizon, and on the window's side.
        let lights = seen.z > 0.02 && toward.z > -0.01 && (!surface.window || seen.y > 0.02)
        let cosine = max(seen.z, 0)
        let fade = smoothstep(0.02, 0.12, cosine) // grazing light fades rather than stopping at an edge
        // Sunlight bounced off the ground and everything around warms the shade, most at golden hour when the sky is dim.
        if !isNight { sky += strength * 0.05 * pow(1 - max(sun.z, 0), 3) }
        lit = (lights ? strength * fade : .zero, sky, overcastSky, 1)

        // The sky offset (in source radii) that each metre of wall sees through a gap, per metre of path from it.
        let (e1, e2) = basis(toward)
        let m = [dot(wallFrame.right, e1), dot(wallFrame.up, e1), dot(wallFrame.right, e2), dot(wallFrame.up, e2)].map { -$0 / radius }
        proj.vectorFloat4Value = SIMD4<Float>(m.map(Float.init))
        let path = { (depth: Double) in depth / max(cosine, 0.25) }
        invL.floatValue = Float(1 / path(Self.far))
        let (s0, s1, s2) = (shift(Self.far), shift(Self.mid), shift(Self.near))
        shiftFar.vectorFloat2Value = SIMD2<Float>(Float(s0.x), Float(s0.y))
        shiftNear.vectorFloat4Value = SIMD4<Float>(Float(s1.x), Float(s1.y), Float(s2.x), Float(s2.y))
        // The other way, for the soft leaves' blur: where on their plane each part of the source's image is seen.
        let k = -path(Self.mid) / (m[0] * m[3] - m[1] * m[2])
        blur.vectorFloat4Value = SIMD4<Float>([m[3], -m[1], -m[2], m[0]].map { Float($0 * k) })
        source.vectorFloat4Value = mask
        terminator.vectorFloat2Value = term
        direction.vectorFloat3Value = SIMD3<Float>(seen)
        night.floatValue = Float(smoothstep(-3, -10, altitude) * (Self.knob(.night) > 0.5 ? 0.3 : 1)) // lamplight stays warm

        // The eye adapts: the wall's brightness follows the light only as its 0.18th power, and dims further at night.
        let cloudy = conditions.sunshine == .overcast
        let scene = (cloudy ? overcastSky : sky + lit.direct * cosine * 0.5)
        let luminance = max(dot(scene, V(0.2126, 0.7152, 0.0722)), 1e-9)
        let streetlight = Self.knob(.night) > 0.5 ? 0.25 : 0 // lamplight is bright for its size, so the eye stays dimmer
        lit.exposure = 1.8 * pow(luminance / 0.33, -0.82) / 0.33 * (1 - (0.5 + streetlight) * smoothstep(-3, -10, altitude))
        // A charcoal wall would go black by night, so in Dark Mode the glow of the sky is five times as strong on it.
        if charcoal {
            let glow = 1 + 4 * smoothstep(-3, -10, altitude)
            (lit.sky, lit.overcastSky) = (lit.sky * glow, lit.overcastSky * glow)
        }
        tint.vectorFloat3Value = wallColour
    }

    /// Two unit vectors square to `v` and to each other, the first level, for measuring offsets in the sky around it.
    private func basis(_ v: V) -> (V, V) {
        let e1 = normalize(cross(V(0, 0, 1), v) + V(1e-9, 0, 0))
        return (e1, cross(v, e1))
    }

    /// The area two circles of radius `a` and `b` share, their centres `d` apart.
    private static func overlap(_ a: Double, _ b: Double, _ d: Double) -> Double {
        if d >= a + b { return 0 }
        if d <= abs(a - b) { return .pi * min(a, b) * min(a, b) }
        let x = (d * d + a * a - b * b) / (2 * d), y = sqrt(max(a * a - x * x, 0))
        return a * a * acos(x / a) + b * b * acos((d - x) / b) - d * y
    }

    // MARK: - Motion

    override func update(_ currentTime: TimeInterval) {
        let dt = frameTime(currentTime, &lastUpdate)
        clock += dt
        sinceLight += dt
        if sinceLight >= 1 { sinceLight = 0; light() }

        // Clouds: on a partly cloudy day the Sun goes in and out, softening the dapples into diffuse light as a cloud
        // thickens over it, for as much of the time as the sky is covered.
        let sunny: Double
        switch conditions.sunshine {
        case .clear: sunny = 1
        case .overcast: sunny = 0
        case .partlyCloudy: sunny = smoothstep(conditions.cloudCover / 100 - 0.12, conditions.cloudCover / 100 + 0.12, Self.slowNoise(clock / 70))
        }
        let sky = lit.sky * sunny + lit.overcastSky * (1 - sunny)
        direct.vectorFloat3Value = SIMD3<Float>(lit.direct * sunny * lit.exposure)
        ambient.vectorFloat3Value = SIMD3<Float>(sky * lit.exposure)

        // Wind sways the branches, more in gusts, and past a light breeze the leaves flutter.
        let breeze = conditions.wind * (0.75 + 0.5 * Self.slowNoise(clock / 12 + 40)), sway = Self.knob(.sway)
        let amplitude = min(0.01 * pow(breeze / 10, 1.4), 0.05) * sway
        let flutter = min(max((breeze - 5) / 15, 0), 1) * 0.35 * min(sway, 1.5)
        wind.vectorFloat4Value = SIMD4<Float>(Float(amplitude), Float(flutter), Float(1 - sunny), Float(Self.knob(.cover)))
        let angle = 2.55 + min(0.012 * breeze / 10, 0.05) * sway * (sin(clock * 3.3) + 0.6 * sin(clock * 5.1 + 1))
        twigPose.vectorFloat4Value = SIMD4<Float>(Float(twigBase.x), Float(twigBase.y), Float(angle), Float(Self.knob(.twig)))
    }

    /// Smooth value noise over time, 0…1.
    private static func slowNoise(_ t: Double) -> Double {
        func hash(_ i: Double) -> Double { let s = sin(i * 127.1 + 311.7) * 43758.5453; return s - s.rounded(.down) }
        let i = t.rounded(.down), f = t - i, u = f * f * (3 - 2 * f)
        return hash(i) * (1 - u) + hash(i + 1) * u
    }

    // MARK: - Textures

    /// The last surface's textures, kept for every display and the Settings preview; only one surface's at a time,
    /// since each is 32 MB.
    private static var loaded: (key: String, albedo: SKTexture, relief: SKTexture, mean: Float)?

    /// A surface's albedo, and its relief packed as slope across in red, slope up in green and height in blue, from
    /// greyscale HEICs (a colour HEIC's chroma subsampling ruins packed channels); and the albedo's mean in linear
    /// light, which the tint is divided by.
    static func textures(_ surface: Surface) -> (albedo: SKTexture, relief: SKTexture, mean: Float) {
        let key = surface.albedo + "+" + surface.relief
        if let loaded, loaded.key == key { return (loaded.albedo, loaded.relief, loaded.mean) }
        func image(_ name: String) -> CGImage? {
            NSImage(contentsOf: resource("dappled-\(name).heic"))?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }
        let colour = image(surface.albedo)
        let (w, h) = (colour?.width ?? 1, colour?.height ?? 1)
        /// Draws `image` into 8-bit pixels, four to a pixel in colour or one in grey.
        func pixels(_ image: CGImage?, colour: Bool) -> [UInt8] {
            var bytes = [UInt8](repeating: 128, count: w * h * (colour ? 4 : 1))
            guard let image else { return bytes }
            bytes.withUnsafeMutableBytes { buffer in
                CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * (colour ? 4 : 1),
                          space: colour ? CGColorSpaceCreateDeviceRGB() : CGColorSpaceCreateDeviceGray(),
                          bitmapInfo: colour ? CGImageAlphaInfo.noneSkipLast.rawValue : CGImageAlphaInfo.none.rawValue)!
                    .draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            }
            return bytes
        }
        func texture(_ bytes: [UInt8]) -> SKTexture {
            var bytes = bytes
            return SKTexture(cgImage: CGContext(data: &bytes, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!.makeImage()!)
        }

        let albedo = pixels(colour, colour: true)
        let linear = (0..<256).map { pow(Double($0) / 255, 2.2) }
        var sum = 0.0
        for i in stride(from: 0, to: albedo.count, by: 4) {
            sum += 0.2126 * linear[Int(albedo[i])] + 0.7152 * linear[Int(albedo[i + 1])] + 0.0722 * linear[Int(albedo[i + 2])]
        }
        var relief = [UInt8](repeating: 255, count: w * h * 4)
        let maps = ["nx", "ny"] + (surface.depth > 0 ? ["height"] : [])
        for (channel, map) in maps.enumerated() {
            let plane = pixels(image(surface.relief + "-" + map), colour: false)
            for i in 0..<w * h { relief[i * 4 + channel] = plane[i] }
        }
        let result = (albedo: texture(albedo), relief: texture(relief), mean: Float(sum / Double(w * h)))
        loaded = (key, result.albedo, result.relief, result.mean)
        return result
    }

    /// The tree's shadow-casters, 3 m square and tiling, laid out afresh each launch from real maple, oak or beech
    /// leaves (ambientCG's leaf scans, CC0), one kind of tree at a time. Red holds sprays of leaves on their twigs,
    /// green the far crown: denser clumps of smaller leaves, blurred into the soft masses that the Sun, 5 m on, makes
    /// of them; blue the crown's much softer shadow from the sky.
    private static let canopy: SKTexture = {
        let n = 1024, metres = 3.0
        guard let atlas = NSImage(contentsOf: resource("dappled-leaves.png"))?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return SKTexture(cgImage: CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!.makeImage()!)
        }
        let cells = (0..<16).compactMap { atlas.cropping(to: CGRect(x: $0 % 4 * 256, y: $0 / 4 * 256, width: 256, height: 256)) }
        let kinds = [Array(0..<6), Array(6..<10), Array(10..<16)].randomElement()! // maple, oak or beech
        func context() -> CGContext {
            let context = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n, space: CGColorSpaceCreateDeviceGray(),
                                    bitmapInfo: CGImageAlphaInfo.none.rawValue)!
            context.scaleBy(x: Double(n) / metres, y: Double(n) / metres)
            context.setStrokeColor(gray: 1, alpha: 1)
            context.setLineCap(.round)
            return context
        }
        /// Draws a leaf with its stem's end at `at`, pointing along `angle`, white on black, wrapped so the layer tiles.
        func leaf(_ context: CGContext, at: CGPoint, angle: Double, length: Double) {
            let side = length * 256 / 240, cell = cells[kinds.randomElement()!]
            for dx in [-metres, 0, metres] {
                for dy in [-metres, 0, metres] where at.x + dx > -0.2 && at.x + dx < metres + 0.2 && at.y + dy > -0.2 && at.y + dy < metres + 0.2 {
                    context.saveGState()
                    context.translateBy(x: at.x + dx, y: at.y + dy)
                    context.rotate(by: angle - .pi / 2)
                    context.draw(cell, in: CGRect(x: -side / 2, y: -side * 0.03, width: side, height: side))
                    context.restoreGState()
                }
            }
        }
        func line(_ context: CGContext, from: CGPoint, to: CGPoint, width: Double) {
            context.setLineWidth(width)
            for dx in [-metres, 0, metres] {
                for dy in [-metres, 0, metres] {
                    context.move(to: CGPoint(x: from.x + dx, y: from.y + dy))
                    context.addLine(to: CGPoint(x: to.x + dx, y: to.y + dy))
                }
            }
            context.strokePath()
        }
        func pixels(_ context: CGContext) -> [Float] {
            UnsafeBufferPointer(start: context.data!.assumingMemoryBound(to: UInt8.self), count: n * n).map(Float.init)
        }
        /// Wrapped box blurs, across then down; three passes are close to a Gaussian.
        func blurred(_ image: [Float], radius: Int, passes: Int) -> [Float] {
            var image = image
            for _ in 0..<passes {
                for pass in 0..<2 {
                    var out = image
                    for line in 0..<n {
                        func at(_ i: Int) -> Int { let i = (i % n + n) % n; return pass == 0 ? line * n + i : i * n + line }
                        var sum = (-radius...radius).reduce(Float(0)) { $0 + image[at($1)] }
                        for i in 0..<n {
                            out[at(i)] = sum / Float(2 * radius + 1)
                            sum += image[at(i + radius + 1)] - image[at(i - radius)]
                        }
                    }
                    image = out
                }
            }
            return image
        }

        // Sprays: twigs off a few branches, leaves set alternately along each twig and one at its tip.
        let sprayContext = context()
        for _ in 0..<5 {
            var at = CGPoint(x: .random(in: 0..<metres), y: .random(in: 0..<metres))
            var heading = Double.random(in: 0..<(2 * .pi))
            for _ in 0..<7 {
                heading += .random(in: -0.5...0.5)
                let twig = Double.random(in: 0.18...0.4), side: Double = Bool.random() ? 1 : -1
                let out = heading + side * .random(in: 0.5...1.1)
                let tip = CGPoint(x: at.x + cos(out) * twig, y: at.y + sin(out) * twig)
                line(sprayContext, from: at, to: tip, width: 0.004)
                var k = 0.25
                while k < 1 {
                    let node = CGPoint(x: at.x + cos(out) * twig * k, y: at.y + sin(out) * twig * k)
                    let flip: Double = Int(k * 10) % 2 == 0 ? 1 : -1
                    leaf(sprayContext, at: node, angle: out + flip * .random(in: 0.5...1.0), length: .random(in: 0.08...0.13))
                    k += .random(in: 0.14...0.24)
                }
                leaf(sprayContext, at: tip, angle: out + .random(in: -0.2...0.2), length: .random(in: 0.09...0.13))
                let step = Double.random(in: 0.15...0.3)
                let next = CGPoint(x: at.x + cos(heading) * step, y: at.y + sin(heading) * step)
                line(sprayContext, from: at, to: next, width: 0.012)
                at = next
            }
        }
        // A little blur, so the taps that blur the sprays by the Sun's image don't ghost the thinnest twigs.
        let sprays = blurred(pixels(sprayContext), radius: 1, passes: 2)

        // The far crown: clumps of leaves along a few limbs, dense at their hearts and thinning out, with sky between.
        let crownContext = context()
        for _ in 0..<5 {
            var at = CGPoint(x: .random(in: 0..<metres), y: .random(in: 0..<metres))
            var heading = Double.random(in: 0..<(2 * .pi))
            for _ in 0..<6 {
                let radius = Double.random(in: 0.1...0.24)
                for _ in 0..<Int(radius * radius * 3000) {
                    let r = radius * abs(Double.random(in: -1...1) + Double.random(in: -1...1)) * 0.6, a = Double.random(in: 0..<(2 * .pi))
                    leaf(crownContext, at: CGPoint(x: at.x + cos(a) * r, y: at.y + sin(a) * r), angle: a + .random(in: -1...1),
                         length: .random(in: 0.06...0.1))
                }
                heading += .random(in: -0.9...0.9)
                let step = Double.random(in: 0.15...0.3)
                at = CGPoint(x: at.x + cos(heading) * step, y: at.y + sin(heading) * step)
            }
        }
        // The Sun, 5 m past these leaves, blurs them by about 2 cm.
        let crown = blurred(pixels(crownContext), radius: 7, passes: 3)
        // The crown's shadow from the sky, for when there's no sun: blurred about 12 cm. The sky, a huge source, would
        // really blur a crown 5 m out over metres into an even grey; this keeps the tree readable under cloud.
        let skyShadow = blurred(crown, radius: 40, passes: 3)

        var bytes = [UInt8](repeating: 255, count: n * n * 4)
        for i in 0..<n * n {
            bytes[i * 4] = UInt8(min(sprays[i], 255))
            bytes[i * 4 + 1] = UInt8(min(crown[i], 255))
            bytes[i * 4 + 2] = UInt8(min(skyShadow[i] * 1.3, 255))
        }
        let context = CGContext(data: &bytes, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        return SKTexture(cgImage: context.makeImage()!)
    }()

    /// A twig of three serrated leaves (ambientCG LeafSet005, CC0), for the sharp shadow near the wall.
    private static let twig = SKTexture(imageNamed: resource("dappled-twig.png").path)

    // MARK: - Shader

    private static let shaderSource = """
    // One gap's image of the light: `q` is the offset in the sky, in the source's radii, from the image's centre, and
    // `r` the gap's radius in the same units, which blurs the image by as much. The Moon
    // (src.xy, radius src.z) bites into it during an eclipse; a moon source shows its phase (src.w, the cosine of
    // the phase angle, with `term` pointing to its bright limb).
    float sunImage(vec2 q, float r, vec4 src, vec2 term, float px) {
        float d = length(q);
        float soft = r + px;
        float lit = 1.0 - smoothstep(1.0 - soft, 1.0 + soft, d);
        lit *= (0.4 + 0.6 * sqrt(max(1.0 - d * d, 0.0))) * 1.25; // limb darkening, averaging 1 over the disc
        if (src.z > 0.0) { lit *= smoothstep(src.z - soft, src.z + soft, length(q - src.xy)); }
        if (src.w < 0.999) {
            float u = dot(q, term);
            float v = dot(q, vec2(-term.y, term.x));
            lit *= smoothstep(-soft, soft, u + src.w * sqrt(max(1.0 - v * v, 0.0)));
        }
        return lit;
    }

    // Gaps in the far crown, one to a 2 × 2 cell of sky offset (so every image is round here); the fluttering ones blink.
    float pinholes(vec2 g, float open, float flutter, float t, vec4 src, vec2 term, float px) {
        vec2 cell = floor(g * 0.5);
        float sum = 0.0;
        for (int j = -1; j <= 1; j++) {
            for (int i = -1; i <= 1; i++) {
                vec2 c = cell + vec2(float(i), float(j));
                vec4 h = hash42(c);
                float r = h.z < 0.78 - 0.4 * open ? 0.0 : (0.1 + 0.3 * h.z) * (0.5 + 0.5 * open);
                // A gap's image is as bright as the gap's area over the image's, so pinhole-sized gaps make dim images,
                // but photos show the dapples at 0.7–1.6 times the median spot: the visible ones are the wider gaps.
                float bright = fract(h.z * 13.7 + h.w * 5.3);
                float gain = mix(0.2, 1.0, bright * bright) * (1.0 - flutter * step(0.6, h.w) * (0.5 + 0.5 * sin(mod(t, 3600.0) * (15.0 + 20.0 * h.w) + h.w * 80.0))); // wrapped: a fast flutter coarsens first
                float size = 0.65 + 0.8 * fract(h.z * 7.31 + h.w * 3.7);   // gaps 3.3 to 7.3 m out: the nearer, the smaller
                if (r > 0.02) { sum += gain * sunImage((g - (c + 0.2 + 0.6 * h.xy) * 2.0) / size, r / size, src, term, px / size); }
            }
        }
        return sum;
    }

    void main() {
        vec2 p = (v_tex_coord - 0.5) * u_size * u_mpp;   // metres on the wall from the middle of the screen
        float t = u_now;

        // The surface: albedo, and the slope of its grain for the light to rake across.
        vec2 st = fract(p / u_surface.xy);
        vec3 albedo = pow(texture2D(u_albedo, st).rgb, vec3(2.2)) * u_wall;
        vec4 rel = texture2D(u_relief, st);
        vec2 slope = rel.rg * 2.0 - 1.0;
        vec3 normal = vec3(slope, sqrt(max(1.0 - dot(slope, slope), 0.0)));
        // Deep relief (siding's laps, brick's mortar) shades itself: march toward the light up through its height.
        float relit = 1.0;
        if (u_surface.z > 0.0) {
            vec2 run = u_dir.xy / max(u_dir.z, 0.08) * u_surface.z * 0.125;
            for (int k = 1; k <= 8; k++) {
                float hk = texture2D(u_relief, fract((p + run * float(k)) / u_surface.xy)).b;
                relit = min(relit, smoothstep(-0.04, 0.04, rel.b + float(k) * 0.125 - hk));
            }
        }

        // Branches sway, each part of the tree in its own phase.
        float phase = texture2D(u_noise, fract(p * 0.21 + 0.37)).a * 14.0;
        vec2 sway = u_wind.x * vec2(sin(t * 2.7 + phase) + 0.5 * sin(t * 1.3 + phase * 1.7),
                                    0.6 * cos(t * 2.1 + phase * 0.8) + 0.3 * sin(t * 0.9 + phase * 2.3));

        // The far crown: a soft mass of shade, with round images of the source where it has gaps.
        vec2 cf = p - u_shiftFar + sway * 0.6;
        float density = texture2D(u_canopy, fract(cf * 0.29 + vec2(0.13, 0.61))).g;
        float crown = smoothstep(0.1, 0.6, density + u_wind.w - 0.5);
        float far = 1.0 - crown;
        if (crown > 0.01) {
            float px = u_mpp * 0.5 * length(u_proj.xy) * u_invL;
            vec2 g = vec2(dot(u_proj.xy, cf), dot(u_proj.zw, cf)) * u_invL;
            far += crown * min(pinholes(g, 1.0 - smoothstep(0.4, 1.0, density), u_wind.y, t, u_src, u_term, px), 1.0);
        }
        far = mix(far, 1.0 - 0.7 * crown, u_wind.z);   // behind thin cloud the dapples blur into the shade

        // Sprays of leaves nearer the wall: their shadow blurred over the source's image, tap by tap, each tap dropped
        // where the Moon covers the Sun.
        vec2 cm = p - u_shiftNear.xy + sway;
        float leaf = 0.0;
        float weight = 0.0;
        for (int k = 0; k < 7; k++) {
            float a = float(k) * 1.0472 + 0.3;
            vec2 d = k == 0 ? vec2(0.0) : 0.7 * vec2(cos(a), sin(a));
            float w = 1.0;
            if (u_src.z > 0.0) { w = step(u_src.z, length(d - u_src.xy)); }
            vec2 tap = cm + vec2(dot(u_blur.xy, d), dot(u_blur.zw, d));
            leaf += w * texture2D(u_canopy, fract(tap * 0.33 + vec2(0.71, 0.29))).r;
            weight += w;
        }
        leaf = smoothstep(0.0, 1.0, leaf / max(weight, 0.001) * (0.6 + u_wind.w * 0.8));

        // The twig near the wall: a sharp shadow, swaying about its base.
        vec2 local = p - u_shiftNear.zw - u_twigPose.xy + sway * 0.5;
        float ca = cos(u_twigPose.z);
        float sa = sin(u_twigPose.z);
        vec2 uv = vec2(ca * local.x + sa * local.y, -sa * local.x + ca * local.y) / vec2(0.44, 0.55) + vec2(0.66, 0.0);
        float twig = 0.0;
        if (uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0) { twig = texture2D(u_twig, uv).a * u_twigPose.w; }

        float sunlit = far * (1.0 - leaf) * (1.0 - twig) * relit;
        // The crown also hides part of the sky: a soft shadow straight back from where the tree really is (a little low,
        // since the sky is brightest overhead), which is all there is to see under cloud or with the Sun behind the wall.
        vec2 cs = p + sway * 0.6 + vec2(0.0, 0.2);   // looking 0.2 m up the tree puts its shadow 0.2 m low
        float hidden = smoothstep(0.1, 0.8, texture2D(u_canopy, fract(cs * 0.29 + vec2(0.13, 0.61))).b + u_wind.w - 0.5);
        vec3 amb = u_amb * (1.0 - 0.5 * hidden);
        if (u_surface.w > 0.0) {
            // Through a window in the wall past the top of the screen, 1.2 m wide and 0.8 m tall in three by two panes,
            // its sill 0.8 m up: follow the ray toward the light back to the wall, and see if it passes through a pane.
            // The view is centred on the patch of light, wherever the Sun puts it.
            vec3 d = u_dir.y > 0.02 ? u_dir : vec3(0.0, 0.8, 0.6);
            float tc = 1.2 / d.z;                                // along the ray from mid-screen to the window's middle
            float t = (tc * d.y - p.y) / d.y;
            vec2 a = vec2(p.x + (t - tc) * d.x, t * d.z - 0.8); // across the window from its middle, and up from its sill
            float soft = 0.0047 * t * length(d) + 0.002;        // the Sun's half-width blurs the edges by the distance
            float inside = smoothstep(-soft, soft, 0.6 - abs(a.x)) * smoothstep(-soft, soft, a.y) * smoothstep(-soft, soft, 0.8 - a.y);
            vec2 m = abs(fract(vec2(a.x / 0.4 + 0.5, a.y / 0.4)) - 0.5) * 0.4;
            sunlit *= inside * smoothstep(0.02 - soft, 0.02 + soft, min(m.x, m.y)) * step(0.02, u_dir.y);
            // The room is lit by the sky through the window: dimmer and warmer than outdoors, brightest where the light
            // comes in, which is all there is under cloud. The tree's shadow from the sky doesn't reach in here.
            float glow = smoothstep(-0.25, 0.25, 0.6 - abs(a.x)) * smoothstep(-0.3, 0.2, a.y) * smoothstep(-0.3, 0.2, 0.8 - a.y);
            amb = u_amb * vec3(1.0, 0.9, 0.78) * (0.25 + 0.9 * glow);
        }
        vec3 light = amb + u_light * sunlit * max(dot(normal, u_dir), 0.0);
        vec3 col = sqrt(1.0 - exp(-albedo * light));
        col = mix(col, dot(col, vec3(0.3, 0.6, 0.1)) * vec3(0.8, 0.9, 1.15), u_night * 0.6); // blue by moonlight
        col += (hash21(v_tex_coord * u_size * 2.0) - 0.5) / 255.0;
        gl_FragColor = vec4(col, 1.0);
    }
    """
}

private extension LiveWeather.Conditions {
    enum Sunshine { case clear, partlyCloudy, overcast }
    /// How the sky lets the Sun through: clear, broken cloud it goes in and out of, or none at all.
    var sunshine: Sunshine {
        switch code {
        case 0, 1: cloudCover > 30 ? .partlyCloudy : .clear
        case 2: .partlyCloudy
        default: code >= 80 && code <= 82 ? .partlyCloudy : .overcast // showers come and go; fog, drizzle, rain and snow don't
        }
    }
}

private func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
    let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
    return t * t * (3 - 2 * t)
}
