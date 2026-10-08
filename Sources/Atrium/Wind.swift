import CoreLocation
import SpriteKit

@MainActor func wind(size: CGSize) -> SKScene { WindScene(size: size) }

/// The live wind around you, drawn as streaks flowing along it, after the hint.fm wind map and earth.nullschool.
/// The wind comes from `WindField` as a small texture. There are no particles on the CPU: every pixel traces the
/// wind upstream and asks whether a streak has just passed it (see `source`).
final class WindScene: SKScene {
    nonisolated static let zoom = Knob(key: "wind.zoom", label: "Zoom", range: 0...2, standard: 1, section: "Map",
                                       format: .choice(["My town", "My region", "Half the continent"]))
    // a new key: the old one (None, Coastline, Shaded relief) would land on the wrong choices
    nonisolated static let background = Knob(key: "wind.map", label: "Background", range: 0...5, standard: 2, section: "Map",
                                             format: .choice(["None", "Shaded relief", "Earth by day", "Earth at night",
                                                              "Terrain and sea floor", "Satellite, yesterday"]))
    nonisolated static let opacity = Knob(key: "wind.mapOpacity", label: "Opacity", range: 0...1, standard: 0.35, section: "Map",
                                          shownWhen: background.key)
    nonisolated static let brightness = Knob(key: "wind.mapBrightness", label: "Brightness", range: 0.3...2, standard: 1, section: "Map",
                                             shownWhen: background.key)
    nonisolated static let saturation = Knob(key: "wind.mapSaturation", label: "Saturation", range: 0...1.5, standard: 0.8, section: "Map",
                                             shownWhen: background.key)
    nonisolated static let look = Knob(key: "wind.look", label: "Look", range: 0...1, standard: 1, section: "Streaks",
                                       format: .choice(["Comets", "Brush strokes"]))
    nonisolated static let speed = Knob(key: "wind.speed", label: "Speed", range: 0.25...4, standard: 1, section: "Streaks", format: .times)
    nonisolated static let length = Knob(key: "wind.length", label: "Streak length", range: 0.25...2, standard: 1, section: "Streaks", format: .times)
    nonisolated static let density = Knob(key: "wind.density", label: "Density", range: 0.1...1, standard: 0.6, section: "Streaks")
    nonisolated static let knobs = [zoom, background, opacity, brightness, saturation, look, speed, length, density]

    /// Calm to strong, for Dark Mode; Light Mode draws the same hues as ink.
    nonisolated static let palettes: [(name: String, stops: [SIMD3<Float>])] = [
        ("Midnight", [[0.16, 0.20, 0.62], [0.36, 0.28, 0.86], [0.30, 0.66, 1.00], [0.80, 0.94, 1.00]]),
        ("Sapphire", [[0.08, 0.22, 0.60], [0.10, 0.45, 0.85], [0.30, 0.75, 0.98], [0.85, 0.96, 1.00]]),
        ("Lagoon", [[0.04, 0.26, 0.42], [0.04, 0.52, 0.62], [0.30, 0.82, 0.78], [0.86, 1.00, 0.92]]),
        ("Amethyst", [[0.26, 0.12, 0.52], [0.50, 0.24, 0.80], [0.80, 0.46, 0.92], [1.00, 0.86, 0.96]]),
        ("Garnet", [[0.36, 0.08, 0.26], [0.70, 0.18, 0.34], [0.96, 0.50, 0.40], [1.00, 0.88, 0.72]]),
        ("Silver", [[0.30, 0.32, 0.36], [0.52, 0.55, 0.60], [0.76, 0.79, 0.84], [1.00, 1.00, 1.00]]),
    ]
    nonisolated static let paletteOptions = palettes.map { ($0.name, Array($0.stops[1...]), Array($0.stops[..<3])) }

    private let field = SKMutableTexture(size: CGSize(width: WindField.texels.x, height: WindField.texels.y))
    private let uniforms = (clock: SKUniform(name: "u_clock", float: 0), vmax: SKUniform(name: "u_vmax", float: 10),
                            rect: SKUniform(name: "u_rect", vectorFloat4: .zero), trail: SKUniform(name: "u_trail", float: 2),
                            density: SKUniform(name: "u_density", float: 0.6), brush: SKUniform(name: "u_brush", float: 1),
                            pace: SKUniform(name: "u_pace", float: 5))
    /// The background's kind (1 relief, 2 day, 3 night) and its sliders.
    private let ground = (kind: SKUniform(name: "u_kind", float: 0), opacity: SKUniform(name: "u_opacity", float: 0.35),
                          brightness: SKUniform(name: "u_brightness", float: 1), saturation: SKUniform(name: "u_saturation", float: 0.8))
    private var clockTime: Double = 0, lastUpdate: TimeInterval?, sinceField: TimeInterval = 0
    private var zoomShown = -1, backgroundShown = -1, mapCentre = CLLocationCoordinate2D()
    private let dark = systemIsDark, base: SIMD3<Float>
    private let map = SKSpriteNode()
    private lazy var mapShader = SKShader(source: Self.mapSource, uniforms: [
        SKUniform(name: "u_base", vectorFloat3: base), SKUniform(name: "u_dark", float: dark ? 1 : 0),
        ground.kind, ground.opacity, ground.brightness, ground.saturation,
    ])

    override init(size: CGSize) {
        let name = UserDefaults.standard.string(forKey: "wind.palette") ?? "Midnight" // empty is Random
        let stops = (Self.palettes.first { $0.name == name } ?? Self.palettes.randomElement()!).stops
        // a night sky tinted by the palette's calmest colour, or paper
        base = dark ? stops[0] * 0.2 + 0.055 : simd_mix(SIMD3(0.955, 0.953, 0.94), stops[1], SIMD3(repeating: 0.04))
        super.init(size: size)
        field.filteringMode = .linear
        backgroundColor = SKColor(red: CGFloat(base.x), green: CGFloat(base.y), blue: CGFloat(base.z), alpha: 1)
        map.anchorPoint = .zero
        map.size = size
        addChild(map)

        // drawn at half resolution: an effect node renders its children at their own scale, then scales the result up
        let half = SKEffectNode()
        half.shouldEnableEffects = true
        half.setScale(2)
        let streaks = SKSpriteNode(color: .clear, size: CGSize(width: size.width / 2, height: size.height / 2))
        streaks.anchorPoint = .zero
        streaks.shader = SKShader(source: Self.source, uniforms: [
            SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)]),
            SKUniform(name: "u_field", texture: field), uniforms.clock, uniforms.vmax, uniforms.rect, uniforms.trail, uniforms.density, uniforms.brush, uniforms.pace,
            SKUniform(name: "u_dark", float: dark ? 1 : 0), SKUniform(name: "u_noise", texture: Self.noise),
        ] + stops.indices.map { SKUniform(name: "u_c\($0)", vectorFloat3: stops[$0]) })
        half.addChild(streaks)
        addChild(half)
        applyKnobs()
        NotificationCenter.default.addObserver(self, selector: #selector(applyKnobs), name: UserDefaults.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(forecastLanded), name: WindField.changed, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    @objc private func forecastLanded() { showField() }

    override func didMove(to view: SKView) {
        guard action(forKey: "poll") == nil else { return }
        Location.shared.start()
        run(.sequence([.wait(forDuration: 2), // give a remembered location fix a moment to land
                       .repeatForever(.sequence([.run { [weak self] in self?.poll() }, .wait(forDuration: 300)]))]),
            withKey: "poll")
        fetchEarth()
    }

    @objc private func applyKnobs() {
        uniforms.brush.floatValue = Float(Self.look.value)
        uniforms.trail.floatValue = Float(2 * Self.length.value)
        uniforms.density.floatValue = Float(Self.density.value)
        ground.opacity.floatValue = Float(Self.opacity.value)
        ground.brightness.floatValue = Float(Self.brightness.value)
        ground.saturation.floatValue = Float(Self.saturation.value)
        let wanted = (zoom: Int(Self.zoom.value), background: Int(Self.background.value))
        guard wanted.zoom != zoomShown || wanted.background != backgroundShown else { return }
        let rezoom = wanted.zoom != zoomShown
        (zoomShown, backgroundShown) = wanted
        drawMap()
        fetchEarth()
        if rezoom {
            // the grid is 1.2 screen widths across and 0.8 up, centred on you
            let w = Float(size.width)
            uniforms.rect.vectorFloat4Value = [w / 2 - 0.6 * w, Float(size.height) / 2 - 0.4 * w, 1.2 * w, 0.8 * w]
            uniforms.pace.floatValue = [14, 8, 5][zoomShown] // pt/s per m/s: faster close up, as nullschool does, or a town looks frozen
            showField()
            if view != nil { poll() } // not from init: the render tests would fetch, from a guessed place, into the app's cache
        }
    }

    private var place: WindMap { WindMap(centre: mapCentre, kmAcross: WindField.spans[zoomShown], size: size) }

    /// The relief or Earth image for the zoom and where you are, from what's on disk. A plain sprite of the
    /// background colour without one (SKRenderer, in the tests, ignores backgroundColor).
    private func drawMap() {
        mapCentre = WindField.shared.forecast(zoom: zoomShown).centre
        map.texture = backgroundShown == 1 ? place.shadedRelief() : place.earth(Imagery.layers(backgroundShown))
        map.shader = map.texture == nil ? nil : mapShader
        map.color = backgroundColor
        ground.kind.floatValue = backgroundShown == 1 ? 0 : backgroundShown == 3 ? 2 : 1 // shade, an image, or lights
    }

    /// Downloads the Earth tiles the view is missing, while on screen, then draws them.
    private func fetchEarth() {
        guard view != nil else { return }
        if backgroundShown == 5 { Imagery.forgetOtherDays() }
        let missing = place.earthTiles(Imagery.layers(backgroundShown)).filter { !FileManager.default.fileExists(atPath: $0.file.path) }
        guard !missing.isEmpty else { return }
        EarthTiles.shared.fetch(missing.map { ($0.remote, $0.file) }) { [weak self] in self?.drawMap() }
    }

    /// The background under the streaks, with Brightness and Saturation applied to the image. `u_kind` 0 is relief:
    /// light and shade on the background colour (grey 205 is level ground or water), Opacity its strength. 1 is an
    /// image (Earth by day, terrain, the satellite), laid over the background at the Opacity, or in Light Mode printed
    /// on the paper lightened, since dark greens at a third turned the paper muddy. 2 is the night's lights, added, or
    /// in Light Mode printed as ink.
    private static let mapSource = """
    void main() {
        vec3 raw = texture2D(u_texture, v_tex_coord).rgb;
        vec3 t = raw * u_brightness;
        t = max(mix(vec3(dot(t, vec3(0.2126, 0.7152, 0.0722))), t, u_saturation), 0.0);
        vec3 c;
        if (u_kind < 0.5) {
            float s = clamp((raw.r - 0.804) * 5.0, -1.0, 1.0) * u_opacity / 0.35;
            c = u_dark > 0.5 ? u_base * (1.4 + 0.9 * s) * u_brightness : u_base + s * 0.06 * u_brightness;
        } else if (u_kind < 1.5) {
            c = u_dark > 0.5 ? mix(u_base, t, u_opacity) : u_base * mix(vec3(1.0), min(t * 2.2, vec3(1.0)), u_opacity);
        } else {
            c = u_dark > 0.5 ? u_base + t * u_opacity : u_base * (1.0 - t * u_opacity);
        }
        gl_FragColor = vec4(c, 1.0);
    }
    """

    private func poll() {
        WindField.shared.poll(zoom: zoomShown)
        fetchEarth() // tiles that failed offline
    }

    /// The wind now, blended between forecast hours, into the texture.
    private func showField() {
        let centre = WindField.shared.forecast(zoom: zoomShown).centre
        if centre.latitude != mapCentre.latitude || centre.longitude != mapCentre.longitude {
            drawMap()
            fetchEarth()
        }
        let (bytes, vmax) = WindField.shared.texels(zoom: zoomShown, at: Date())
        uniforms.vmax.floatValue = vmax
        field.modifyPixelData { data, length in bytes.withUnsafeBytes { data?.copyMemory(from: $0.baseAddress!, byteCount: min(length, $0.count)) } }
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = frameTime(currentTime, &lastUpdate)
        // every streak's period divides an hour, so the clock wraps there without a jump
        clockTime = (clockTime + dt * Self.speed.value).truncatingRemainder(dividingBy: 3600)
        uniforms.clock.floatValue = Float(clockTime)
        sinceField += dt
        if sinceField > 5 {
            sinceField = 0
            showField()
        }
    }

    /// Four random bytes for each cell of the shader's lattice, 256² cells, read unfiltered.
    private static let noise: SKTexture = {
        let texture = SKTexture(data: Data((0..<256 * 256 * 4).map { _ in UInt8.random(in: 0...255) }), size: CGSize(width: 256, height: 256))
        texture.filteringMode = .nearest
        return texture
    }()

    /// Stateless particles, a take on oriented line integral convolution. Streaks start from spots on a lattice of
    /// 5 pt cells, turned 23° so it lines up with no wind (`u_noise` says which cells have one, where, and its
    /// phase). Each spot sends a streak downstream once a `period`, which lives `life` seconds. Each pixel walks up
    /// to 64 steps of 0.8–1.5 pt upstream along the wind, adding up the time the air takes to reach it (`tau`). A
    /// spot the walk passes within a point of says when its latest streak's head went by here, and the pixel glows
    /// by how recently that was: a comet with a fading tail, 1 pt wide, that speeds up and bends exactly with the
    /// wind. Spots keep more than half a step plus a line's width from their cell's edges, so a walk can't miss one.
    /// On screen 1 m/s is 5 pt/s times the Speed setting, which only changes how fast `u_clock` runs, so moving
    /// the slider never makes streaks jump; the streaks look the same at any speed.
    static let source = shaderCommon + """
    void main() {
        vec2 pts = v_tex_coord * u_size;
        vec2 here = (texture2D(u_field, (pts - u_rect.xy) / u_rect.zw).rg - 0.5) * 2.0 * u_vmax;
        float windHere = length(here);
        // Comets live 2.25 tails and their whole tail fades as they die; brush strokes stop after 0.45–1.5 tails
        // and the stroke then fades where it lies, as hint.fm's do
        float life = (u_brush > 0.5 ? 1.5 : 2.25) * u_trail, reach = 96.0;
        float period = 3600.0 / floor(3600.0 / (life + (u_brush > 0.5 ? 3.0 * u_trail : 0.5))); // divides an hour, where the clock wraps
        float cellSize = 5.0, margin = 0.28;
        mat2 turn = mat2(0.921, 0.389, -0.389, 0.921);
        vec2 q = pts;
        vec2 vel = vec2(0.0);
        float tau = 0.0, dist = 0.0, sum = 0.0, film = 0.0;
        for (int k = 0; k < 64; k++) {
            if (k - 2 * (k / 2) == 0) { vel = (texture2D(u_field, (q - u_rect.xy) / u_rect.zw).rg - 0.5) * 2.0 * u_vmax * u_pace; }
            float speed = max(length(vel), 0.3);
            vec2 dir = vel / speed;
            float h = clamp(speed * 0.06, 0.8, 1.5);
            vec2 cell = floor(turn * (q - dir * (h * 0.5)) / cellSize);
            vec4 r = texture2D(u_noise, fract((cell + 0.5) / 256.0));
            if (r.x < u_density * 0.3) {
                vec2 spot = (cell + margin + (1.0 - 2.0 * margin) * r.yz) * cellSize * turn;
                vec2 rel = spot - q;
                float along = -dot(rel, dir);
                if (along >= 0.0 && along < h) {
                    float ts = tau + along / speed;
                    float x = u_clock + period * r.w - ts;
                    float a = x - period * floor(x / period);
                    float lived = life * (0.3 + 0.7 * fract(r.w * 13.7));
                    float b = exp(-a / u_trail) * smoothstep(0.0, 0.4, ts) * (u_brush > 0.5
                            ? smoothstep(lived, lived * 0.85, ts) * smoothstep(reach, reach * 0.7, dist + along)
                            : smoothstep(life, life * 0.6, ts + a) * smoothstep(reach, reach * 0.7, dist + along + a * windHere * u_pace));
                    float line = smoothstep(0.85, 0.25, length(rel + dir * along)) * (0.55 + 0.45 * r.x / (u_density * 0.3));
                    sum += b * line;
                    // a faint film where streaks have passed, like the residue 8-bit fading leaves on the references
                    film += line * exp(-a / (6.0 * u_trail));
                }
            }
            tau += h / speed;
            dist += h;
            q -= dir * h;
        }
        // colour and brightness by speed, against the strongest wind in the forecast (hint.fm scales to the day's too)
        float s = sqrt(clamp(windHere / max(u_vmax, 8.0), 0.0, 1.0)) * 3.0;
        // where the wind converges particles would crowd together, so streaks there are brighter, and dimmer where it spreads
        vec2 e = vec2(20.0, 0.0);
        float div = texture2D(u_field, (pts + e.xy - u_rect.xy) / u_rect.zw).r - texture2D(u_field, (pts - e.xy - u_rect.xy) / u_rect.zw).r
                  + texture2D(u_field, (pts + e.yx - u_rect.xy) / u_rect.zw).g - texture2D(u_field, (pts - e.yx - u_rect.xy) / u_rect.zw).g;
        float crowd = clamp(-div * 2.0 * u_vmax / max(windHere, 1.0), -1.0, 1.0);
        // brightness saturates at half the day's strongest wind, as hint.fm's does, so every day has highlights
        float fast = clamp(windHere / (0.5 * max(u_vmax, 8.0)), 0.0, 1.0);
        float glow = (1.0 - exp(-2.2 * sum * (1.0 + 0.8 * crowd))) * (0.4 + 0.6 * fast) + 0.06 * min(film, 1.0);
        glow = min(glow, 1.0);
        vec3 c = s < 1.0 ? mix(u_c0, u_c1, s) : (s < 2.0 ? mix(u_c1, u_c2, s - 1.0) : mix(u_c2, u_c3, s - 2.0));
        if (u_dark < 0.5) { c = c / max(max(c.r, c.g), c.b) * (0.6 - 0.08 * s); } // ink, deeper where it's windier
        gl_FragColor = vec4(c * glow, glow);
    }
    """
}

/// The 10 m wind on a grid around you, from Open-Meteo's hourly forecast (free, no key, CC BY 4.0), over 1.2 screen
/// widths by 0.8 at the zoom's span, in one request: the next 24 hours, fetched every 6 hours for the zoom on screen
/// (or now, with Refresh Now), serving every display. Open-Meteo counts each point as one of its free 10,000 calls a
/// day, so the grid is as coarse as each zoom allows: 12 × 8 for a town (points 9 km apart, as fine as the models
/// there), and 24 × 16 for a region or half the continent, where 12 × 8 lost real structure: a low's tight spiral
/// became a broad bend, and a region's eddies and fast lanes over lakes smoothed away (both checked side by side,
/// 2026-09-30). That's at most 384 or 1,536 calls a day. The wind blends from hour to hour, keeps going offline, and
/// the last reply for each zoom is cached on disk so it shows at once.
@MainActor final class WindField {
    static let shared = WindField()
    /// Posted when a new forecast lands.
    static let changed = Notification.Name("WindField.changed")
    static let texels = (x: 93, y: 61)
    /// Kilometres across the screen at each zoom.
    static let spans: [Double] = [100, 800, 3500]
    /// How long a forecast serves before the next, and how soon Refresh Now can ask again.
    static let every: TimeInterval = 6 * 3600, cooldown: TimeInterval = 15 * 60

    /// The grid's columns and rows at a zoom.
    static func grid(_ zoom: Int) -> (cols: Int, rows: Int) { zoom == 0 ? (12, 8) : (24, 16) }

    /// Hourly wind at each grid point, west to east then south to north, in m/s toward east and north, around `centre`.
    struct Forecast {
        var centre: CLLocationCoordinate2D, cols: Int, rows: Int, times: [Double] = [], u: [[Float]] = [], v: [[Float]] = []
    }
    private var forecasts: [Int: Forecast] = [:]
    private var lastTry: [Int: Date] = [:]

    private static func cache(_ zoom: Int) -> URL { URL.cachesDirectory.appending(path: "com.dtanquary.atrium/wind-\(zoom).json") }

    /// Fetches the forecast for a zoom once what we have is `every` old or for somewhere else, at most every 10 minutes
    /// however many displays ask; or now with `force` (Refresh Now), if the last try was over `cooldown` ago. Posts
    /// `changed` once a new one has landed.
    func poll(zoom: Int, force: Bool = false) {
        let here = Location.shared.coordinate, file = Self.cache(zoom), centre = forecast(zoom: zoom).centre
        let spacing = Self.spans[zoom] / 111 / Double(Self.grid(zoom).cols) // degrees, roughly
        let moved = abs(centre.latitude - here.latitude) > spacing || abs(remainder(centre.longitude - here.longitude, 360)) > spacing
        // made up (nothing on disk, or a cache from another grid, which forecast(zoom:) doesn't keep) counts as stale
        let stale = forecasts[zoom] == nil || abs(Date().timeIntervalSince(updated(zoom: zoom) ?? .distantPast)) > Self.every
        let since = abs(Date().timeIntervalSince(lastTry[zoom] ?? .distantPast))
        guard force ? since > Self.cooldown : since > 600 && (stale || moved) else { return }
        lastTry[zoom] = Date()
        let points = Self.points(around: here, zoom: zoom)
        var url = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        url.queryItems = [
            URLQueryItem(name: "latitude", value: points.map { String(format: "%.2f", $0.latitude) }.joined(separator: ",")), // ~1 km, as Weather
            URLQueryItem(name: "longitude", value: points.map { String(format: "%.2f", $0.longitude) }.joined(separator: ",")),
            URLQueryItem(name: "hourly", value: "wind_speed_10m,wind_direction_10m"),
            URLQueryItem(name: "past_hours", value: "1"), URLQueryItem(name: "forecast_hours", value: "24"),
            URLQueryItem(name: "wind_speed_unit", value: "ms"), URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "cell_selection", value: "nearest"),
        ]
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url.url!), let forecast = Self.forecast(from: data, zoom: zoom)
            else { return }
            try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: file)
            forecasts[zoom] = forecast
            NotificationCenter.default.post(name: Self.changed, object: nil)
        }
    }

    /// When the forecast on disk for a zoom arrived.
    func updated(zoom: Int) -> Date? {
        (try? Self.cache(zoom).resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    /// When Refresh Now can next fetch a zoom.
    func available(zoom: Int) -> Date { (lastTry[zoom] ?? .distantPast) + Self.cooldown }

    /// The grid's points around a place, in a local plate carrée: west to east, then south to north.
    static func points(around here: CLLocationCoordinate2D, zoom: Int) -> [CLLocationCoordinate2D] {
        let km = spans[zoom], perDegree = 111.32, stretch = cos(here.latitude * .pi / 180), (cols, rows) = grid(zoom)
        return (0..<rows).flatMap { j in (0..<cols).map { i in
            let x = (Double(i) / Double(cols - 1) - 0.5) * 1.2 * km, y = (Double(j) / Double(rows - 1) - 0.5) * 0.8 * km
            return CLLocationCoordinate2D(latitude: min(max(here.latitude + y / perDegree, -89), 89),
                                          longitude: remainder(here.longitude + x / (perDegree * stretch), 360))
        } }
    }

    /// A forecast from an Open-Meteo reply for a zoom's grid of points.
    static func forecast(from reply: Data, zoom: Int) -> Forecast? {
        let (cols, rows) = grid(zoom)
        struct Point: Decodable {
            struct Hourly: Decodable {
                let time: [Double], speed: [Double?], from: [Double?]
                enum CodingKeys: String, CodingKey { case time, speed = "wind_speed_10m", from = "wind_direction_10m" }
            }
            let latitude: Double, longitude: Double, hourly: Hourly
        }
        guard let points = try? JSONDecoder().decode([Point].self, from: reply), points.count == cols * rows,
              let times = points.first?.hourly.time, !times.isEmpty else { return nil }
        // the middle of the grid; the reply's points are the model's cells nearest the ones asked for
        let first = points[0].longitude
        var forecast = Forecast(centre: CLLocationCoordinate2D(
            latitude: points.map(\.latitude).reduce(0, +) / Double(points.count),
            longitude: first + points.map { remainder($0.longitude - first, 360) }.reduce(0, +) / Double(points.count)),
            cols: cols, rows: rows, times: times)
        for h in times.indices {
            var u = [Float](), v = [Float]()
            for point in points {
                let speed = h < point.hourly.speed.count ? point.hourly.speed[h] ?? 0 : 0
                let from = (h < point.hourly.from.count ? point.hourly.from[h] ?? 0 : 0) * .pi / 180
                u.append(Float(-speed * sin(from)))
                v.append(Float(-speed * cos(from)))
            }
            forecast.u.append(u)
            forecast.v.append(v)
        }
        return forecast
    }

    /// The forecast for a zoom, from memory or the disk cache, or a made-up breeze with a low to the north-east.
    func forecast(zoom: Int) -> Forecast {
        if let known = forecasts[zoom] { return known }
        if let data = try? Data(contentsOf: Self.cache(zoom)), let cached = Self.forecast(from: data, zoom: zoom) {
            forecasts[zoom] = cached
            return cached
        }
        var u = [Float](), v = [Float](), (cols, rows) = Self.grid(zoom)
        for j in 0..<rows { for i in 0..<cols {
            let x = Float(i) / Float(cols - 1) * 1.5 - 1.0, y = Float(j) / Float(rows - 1) - 0.7
            let r2 = x * x + y * y, swirl = 9 * exp(-r2 * 2.2)
            u.append(5 - y * swirl - x * 1.5)
            v.append(x * swirl + 1.5 * sin(x * 2.5))
        } }
        return Forecast(centre: Location.shared.coordinate, cols: cols, rows: rows, times: [0], u: [u], v: [v])
    }

    /// The wind at a moment, blended between forecast hours, smoothly upsampled (Catmull–Rom) to `texels` as
    /// RGBA bytes: east and north in red and green, 0.5 for calm, ±1 for `vmax`, the strongest wind in the forecast.
    func texels(zoom: Int, at date: Date) -> (bytes: [UInt8], vmax: Float) {
        let forecast = forecast(zoom: zoom), t = date.timeIntervalSince1970, times = forecast.times
        let h = max((times.lastIndex { $0 <= t } ?? 0), 0), next = min(h + 1, times.count - 1)
        let f = Float(next > h ? min(max((t - times[h]) / (times[next] - times[h]), 0), 1) : 0)
        let u = zip(forecast.u[h], forecast.u[next]).map { $0 + ($1 - $0) * f }
        let v = zip(forecast.v[h], forecast.v[next]).map { $0 + ($1 - $0) * f }
        var vmax: Float = 3
        for k in forecast.u.indices { for i in forecast.u[k].indices { vmax = max(vmax, hypot(forecast.u[k][i], forecast.v[k][i])) } }

        let (tx, ty) = Self.texels
        var bytes = [UInt8](repeating: 255, count: tx * ty * 4)
        for y in 0..<ty { for x in 0..<tx {
            let gx = (Float(x) + 0.5) / Float(tx) * Float(forecast.cols - 1), gy = (Float(y) + 0.5) / Float(ty) * Float(forecast.rows - 1)
            let o = (y * tx + x) * 4, size = (forecast.cols, forecast.rows)
            bytes[o] = UInt8((min(max(0.5 + 0.5 * Self.catmullRom(u, size, gx, gy) / vmax, 0), 1) * 255).rounded())
            bytes[o + 1] = UInt8((min(max(0.5 + 0.5 * Self.catmullRom(v, size, gx, gy) / vmax, 0), 1) * 255).rounded())
        } }
        return (bytes, vmax)
    }

    /// Catmull–Rom interpolation of a grid of `size` columns and rows at a point in grid units, clamped at the edges.
    private static func catmullRom(_ grid: [Float], _ size: (cols: Int, rows: Int), _ x: Float, _ y: Float) -> Float {
        let (cols, rows) = size
        func weights(_ t: Float) -> [Float] {
            [((-t + 2) * t - 1) * t / 2, ((3 * t - 5) * t * t + 2) / 2, ((-3 * t + 4) * t + 1) * t / 2, (t - 1) * t * t / 2]
        }
        let ix = Int(x), iy = Int(y), wx = weights(x - Float(ix)), wy = weights(y - Float(iy))
        var sum: Float = 0
        for b in 0..<4 {
            let row = min(max(iy + b - 1, 0), rows - 1) * cols
            for a in 0..<4 { sum += wx[a] * wy[b] * grid[row + min(max(ix + a - 1, 0), cols - 1)] }
        }
        return sum
    }
}

/// The map under the streaks, drawn once per zoom and place in the wind's local plate carrée: `kmAcross` fills the
/// width, centred on `centre`. Natural Earth's shaded relief ships with the app; NASA's Earth imagery is downloaded
/// as needed and kept on disk.
struct WindMap {
    let centre: CLLocationCoordinate2D, kmAcross: Double, size: CGSize

    /// Natural Earth's 1:10m shaded relief (SR_HR, 60 px a degree, public domain, naturalearthdata.com), 3×3 median
    /// filtered and cut into 15° greyscale HEIC tiles: four Int32 (15, 24 columns, 12 rows, pixels a degree), then an
    /// Int32 offset and length for each tile from the north-west, row by row; a length of 0 is open sea. Level ground
    /// and water are grey 205, lit slopes lighter and shaded ones darker. HEIC, since JPEG's blocks showed as a grid
    /// of faint boxes once magnified.
    private static let relief = try? Data(contentsOf: resource("wind-relief.bin"), options: .alwaysMapped)

    /// Points per degree east and north.
    private var scale: (x: Double, y: Double) {
        let perDegree = 111.32 * Double(size.width) / kmAcross
        return (perDegree * cos(centre.latitude * .pi / 180), perDegree)
    }

    func point(_ lon: Double, _ lat: Double) -> CGPoint {
        CGPoint(x: size.width / 2 + remainder(lon - centre.longitude, 360) * scale.x, y: size.height / 2 + (lat - centre.latitude) * scale.y)
    }

    /// The view's extent in tiles `degrees` across, numbered from 180° W and 90° N.
    private func tiles(_ degrees: Double) -> (columns: ClosedRange<Int>, rows: ClosedRange<Int>) {
        let halfLon = Double(size.width) / 2 / scale.x, halfLat = Double(size.height) / 2 / scale.y
        let west = Int(floor((centre.longitude - halfLon + 180) / degrees)), east = Int(floor((centre.longitude + halfLon + 180) / degrees))
        let north = Int(floor((90 - centre.latitude - halfLat) / degrees)), south = Int(floor((90 - centre.latitude + halfLat) / degrees))
        return (west...max(east, west), max(north, 0)...max(south, north, 0))
    }

    /// A context at one pixel a point, with tiles drawn into it at their places.
    private func draw(grey: Bool, fill: CGFloat, tiles: [(degrees: Double, column: Int, row: Int, image: CGImage)]) -> SKTexture? {
        let (w, h) = (Int(size.width), Int(size.height))
        guard let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: grey ? CGColorSpaceCreateDeviceGray() : CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: grey ? CGImageAlphaInfo.none.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        context.setFillColor(CGColor(gray: fill, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: w, height: h))
        context.interpolationQuality = .high
        for tile in tiles {
            let corner = point(Double(tile.column) * tile.degrees - 180, 90 - Double(tile.row + 1) * tile.degrees)
            context.draw(tile.image, in: CGRect(x: corner.x, y: corner.y, width: tile.degrees * scale.x, height: tile.degrees * scale.y))
        }
        return context.makeImage().map { SKTexture(cgImage: $0) }
    }

    /// The shaded relief as a greyscale texture.
    func shadedRelief() -> SKTexture? {
        guard let data = Self.relief else { return nil }
        return data.withUnsafeBytes { raw in
            let int = { Int(raw.load(fromByteOffset: $0 * 4, as: Int32.self)) }
            let (degrees, cols) = (Double(int(0)), int(1))
            let span = tiles(degrees)
            let images: [(Double, Int, Int, CGImage)] = span.rows.filter { $0 < int(2) }.flatMap { j in span.columns.compactMap { i in
                let tile = j * cols + (i % cols + cols) % cols
                let (start, length) = (int(4 + tile * 2), int(5 + tile * 2))
                guard length > 0, let source = CGImageSourceCreateWithData(Data(raw[start..<start + length]) as CFData, nil),
                      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
                return (degrees, i, j, image)
            } }
            return draw(grey: true, fill: 206.0 / 255, tiles: images)
        }
    }

    /// The Earth tiles the view needs, coarsest layer first, each layer at the level that gives about a pixel a point,
    /// or its finest; a finer layer only where the coarser one runs out of detail.
    func earthTiles(_ layers: [Imagery]) -> [(level: Int, column: Int, row: Int, base: Bool, remote: URL, file: URL)] {
        let wanted = max(Int(ceil(log2(scale.y * 288 / 512))), 0)
        var found: [(Int, Int, Int, Bool, URL, URL)] = []
        for (k, layer) in layers.enumerated() where k == 0 || layer.over || wanted > layers[k - 1].finest {
            let level = min(wanted, layer.finest), degrees = 288 / pow(2, Double(level))
            let span = tiles(degrees), last = (columns: Int(ceil(360 / degrees)) - 1, rows: Int(ceil(180 / degrees)) - 1)
            for j in span.rows where j <= last.rows { for i in span.columns where i >= 0 && i <= last.columns {
                let tile = layer.tile(level: level, row: j, column: i)
                found.append((level, i, j, k == 0, tile.remote, tile.file))
            } }
        }
        return found
    }

    /// NASA's Earth imagery from the tiles on disk; nil before any have downloaded.
    func earth(_ layers: [Imagery]) -> SKTexture? {
        let images: [(Double, Int, Int, CGImage)] = earthTiles(layers).compactMap { tile in
            guard let source = CGImageSourceCreateWithURL(tile.file as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
            // a finer layer's black is where it has no data (Landsat's sea), so the layer under it shows there
            return (288 / pow(2, Double(tile.level)), tile.column, tile.row,
                    tile.base ? image : image.copy(maskingColorComponents: [0, 6, 0, 6, 0, 6]) ?? image)
        }
        return images.isEmpty ? nil : draw(grey: false, fill: 0, tiles: images)
    }
}

/// NASA imagery from GIBS, the Global Imagery Browse Services (public domain; no key), in geographic tiles of 512 px:
/// a level-n tile is 288/2ⁿ degrees across, counted from 180° W and 90° N. Most of it never changes, so tiles are kept
/// for good; the satellite's are kept for its one day.
struct Imagery {
    let name: String, path: String, format: String, finest: Int
    /// Drawn over the layer under it at every zoom, not only where that one runs out of detail.
    var over = false

    /// Blue Marble Next Generation: a cloud-free Earth, 500 m a pixel.
    static let blueMarble = Imagery(name: "day", path: "BlueMarble_NextGeneration/default/500m", format: "jpeg", finest: 7)
    /// Landsat, from the Global Web-Enabled Landsat Data (NASA and USGS, 2000): 30 m a pixel, for the town zoom, where
    /// Blue Marble's pixels are 7 points across. Its sea is black.
    static let landsat = Imagery(name: "landsat", path: "Landsat_WELD_CorrectedReflectance_TrueColor_Global_Annual/default/2000-12-01/31.25m",
                                 format: "jpeg", finest: 11)
    /// Black Marble: the city lights at night, from VIIRS in 2016, 500 m a pixel.
    static let blackMarble = Imagery(name: "night", path: "VIIRS_Black_Marble/default/2016-01-01/500m", format: "png", finest: 7)

    /// Blue Marble's shaded relief with the sea floor: a physical map, 500 m a pixel.
    static let terrain = Imagery(name: "terrain", path: "BlueMarble_ShadedRelief_Bathymetry/default/500m", format: "jpeg", finest: 7)
    /// Yesterday as NOAA-20's VIIRS saw it, with its real clouds (NASA LANCE corrected reflectance, 250 m a pixel):
    /// today's is still being filled in, pass by pass. Its black gaps between passes show Blue Marble under it.
    static var satellite: Imagery {
        Imagery(name: "satellite/\(yesterday)", path: "VIIRS_NOAA20_CorrectedReflectance_TrueColor/default/\(yesterday)/250m",
                format: "jpeg", finest: 8, over: true)
    }
    private static var yesterday: String { Date(timeIntervalSinceNow: -86400).ISO8601Format(.iso8601.year().month().day()) }

    /// Deletes the satellite's earlier days.
    static func forgetOtherDays() {
        let folder = URL.cachesDirectory.appending(path: "com.dtanquary.atrium/earth/satellite")
        for day in (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [] where day != yesterday {
            try? FileManager.default.removeItem(at: folder.appending(path: day))
        }
    }

    /// The layers for a Background choice, coarsest first: a finer layer adds detail at the town zoom.
    static func layers(_ background: Int) -> [Imagery] {
        [[], [], [blueMarble, landsat], [blackMarble], [terrain, landsat], [blueMarble, satellite]][min(max(background, 0), 5)]
    }

    /// A tile's address, and where it's kept.
    func tile(level: Int, row: Int, column: Int) -> (remote: URL, file: URL) {
        (URL(string: "https://gibs.earthdata.nasa.gov/wmts/epsg4326/best/\(path)/\(level)/\(row)/\(column).\(format)")!,
         URL.cachesDirectory.appending(path: "com.dtanquary.atrium/earth/\(name)/\(level)/\(row)-\(column).\(format)"))
    }
}

/// Downloads GIBS tiles to disk, once each however many displays ask, and tells everyone who asked when a batch lands.
@MainActor final class EarthTiles {
    static let shared = EarthTiles()
    private var pending: Set<URL> = []
    private var waiting: [@MainActor () -> Void] = []

    func fetch(_ tiles: [(remote: URL, file: URL)], done: @escaping @MainActor () -> Void) {
        waiting.append(done)
        let wanted = tiles.filter { !pending.contains($0.file) }
        guard !wanted.isEmpty else { return }
        pending.formUnion(wanted.map(\.file))
        Task {
            await withTaskGroup(of: Void.self) { group in
                for tile in wanted {
                    group.addTask {
                        guard let (data, response) = try? await URLSession.shared.data(from: tile.remote),
                              (response as? HTTPURLResponse)?.statusCode == 200 else { return }
                        try? FileManager.default.createDirectory(at: tile.file.deletingLastPathComponent(), withIntermediateDirectories: true)
                        try? data.write(to: tile.file)
                    }
                }
            }
            pending.subtract(wanted.map(\.file))
            let calls = waiting
            waiting = []
            for call in calls { call() }
        }
    }
}
