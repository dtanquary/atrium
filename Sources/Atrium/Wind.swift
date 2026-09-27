import CoreLocation
import SpriteKit

@MainActor func wind(size: CGSize) -> SKScene { WindScene(size: size) }

/// The live wind around you, drawn as streaks flowing along it, after the hint.fm wind map and earth.nullschool.
/// The wind comes from `WindField` as a small texture. There are no particles on the CPU: every pixel traces the
/// wind upstream and asks whether a streak has just passed it (see `source`).
final class WindScene: SKScene {
    nonisolated static let knobs = [
        Knob(key: "wind.zoom", label: "Zoom", range: 0...2, standard: 1, section: "Map",
             format: .choice(["My town", "My region", "Half the continent"])),
        Knob(key: "wind.background", label: "Background", range: 0...2, standard: 1, section: "Map",
             format: .choice(["None", "Coastline", "Shaded relief"])),
        Knob(key: "wind.look", label: "Look", range: 0...1, standard: 1, section: "Streaks", format: .choice(["Comets", "Brush strokes"])),
        Knob(key: "wind.speed", label: "Speed", range: 0.25...4, standard: 1, section: "Streaks", format: .times),
        Knob(key: "wind.length", label: "Streak length", range: 0.25...2, standard: 1, section: "Streaks", format: .times),
        Knob(key: "wind.density", label: "Density", range: 0.1...1, standard: 0.6, section: "Streaks"),
    ]

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
    private var clockTime: Double = 0, lastUpdate: TimeInterval?, sinceField: TimeInterval = 0
    private var zoom = -1, background = -1, mapCentre = CLLocationCoordinate2D()
    private let dark = systemIsDark, base: SIMD3<Float>
    private let relief = SKSpriteNode(), coast = SKSpriteNode()
    private lazy var reliefShader = SKShader(source: Self.reliefSource, uniforms: [
        SKUniform(name: "u_base", vectorFloat3: base), SKUniform(name: "u_dark", float: dark ? 1 : 0),
    ])

    override init(size: CGSize) {
        let name = UserDefaults.standard.string(forKey: "wind.palette") ?? "Midnight" // empty is Random
        let stops = (Self.palettes.first { $0.name == name } ?? Self.palettes.randomElement()!).stops
        // a night sky tinted by the palette's calmest colour, or paper
        base = dark ? stops[0] * 0.2 + 0.055 : simd_mix(SIMD3(0.955, 0.953, 0.94), stops[1], SIMD3(repeating: 0.04))
        super.init(size: size)
        field.filteringMode = .linear
        backgroundColor = SKColor(red: CGFloat(base.x), green: CGFloat(base.y), blue: CGFloat(base.z), alpha: 1)
        for layer in [relief, coast] {
            layer.anchorPoint = .zero
            layer.size = size
            addChild(layer)
        }
        coast.zPosition = 1 // over the streaks, as nullschool draws it

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
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func didMove(to view: SKView) {
        guard action(forKey: "poll") == nil else { return }
        Location.shared.start()
        run(.sequence([.wait(forDuration: 2), // give a remembered location fix a moment to land
                       .repeatForever(.sequence([.run { [weak self] in self?.poll() }, .wait(forDuration: 300)]))]),
            withKey: "poll")
    }

    @objc private func applyKnobs() {
        uniforms.brush.floatValue = Float(Self.knobs[2].value)
        uniforms.trail.floatValue = Float(2 * Self.knobs[4].value)
        uniforms.density.floatValue = Float(Self.knobs[5].value)
        let wanted = (zoom: Int(Self.knobs[0].value), background: Int(Self.knobs[1].value))
        guard wanted.zoom != zoom || wanted.background != background else { return }
        let rezoom = wanted.zoom != zoom
        (zoom, background) = wanted
        drawMap()
        if rezoom {
            // the grid is 1.2 screen widths across and 0.8 up, centred on you
            let w = Float(size.width)
            uniforms.rect.vectorFloat4Value = [w / 2 - 0.6 * w, Float(size.height) / 2 - 0.4 * w, 1.2 * w, 0.8 * w]
            uniforms.pace.floatValue = [14, 8, 5][zoom] // pt/s per m/s: faster close up, as nullschool does, or a town looks frozen
            showField()
            if view != nil { poll() } // not from init: the render tests would fetch, from a guessed place, into the app's cache
        }
    }

    /// The coastline and relief for the zoom and where you are.
    private func drawMap() {
        mapCentre = WindField.shared.forecast(zoom: zoom).centre
        let map = WindMap(centre: mapCentre, kmAcross: WindField.spans[zoom], size: size)
        coast.texture = background == 0 ? nil : map.coastlines(width: background == 1 ? 0.9 : 0.7,
                                                               colour: dark ? CGColor(gray: 1, alpha: 0.25) : CGColor(gray: 0.1, alpha: 0.28))
        coast.isHidden = background == 0
        // the ground is the plain background colour without relief (SKRenderer, in the tests, ignores backgroundColor)
        relief.texture = background == 2 ? map.shadedRelief() : nil
        relief.shader = relief.texture == nil ? nil : reliefShader
        relief.color = backgroundColor
    }

    /// Relief as light and shade on the background: grey 205 is level ground or water.
    private static let reliefSource = """
    void main() {
        float s = clamp((texture2D(u_texture, v_tex_coord).r - 0.804) * 5.0, -1.0, 1.0);
        vec3 c = u_dark > 0.5 ? u_base * (1.4 + 0.9 * s) + max(s, 0.0) * 0.02 : u_base + s * 0.06;
        gl_FragColor = vec4(c, 1.0);
    }
    """

    private func poll() { WindField.shared.poll(zoom: zoom) { [weak self] in self?.showField() } }

    /// The wind now, blended between forecast hours, into the texture.
    private func showField() {
        let centre = WindField.shared.forecast(zoom: zoom).centre
        if centre.latitude != mapCentre.latitude || centre.longitude != mapCentre.longitude { drawMap() }
        let (bytes, vmax) = WindField.shared.texels(zoom: zoom, at: Date())
        uniforms.vmax.floatValue = vmax
        field.modifyPixelData { data, length in bytes.withUnsafeBytes { data?.copyMemory(from: $0.baseAddress!, byteCount: min(length, $0.count)) } }
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = frameTime(currentTime, &lastUpdate)
        // every streak's period divides an hour, so the clock wraps there without a jump
        clockTime = (clockTime + dt * Self.knobs[3].value).truncatingRemainder(dividingBy: 3600)
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

/// The 10 m wind on a grid around you, from Open-Meteo's hourly forecast (free, no key, CC BY 4.0): `cols` × `rows`
/// points over 1.2 screen widths by 0.8, at the zoom's span, in one request. One fetch serves every display, every
/// two hours for the zoom on screen. Each point counts as one of the free 10,000 calls a day, so that's at most
/// 4,600 a day; hourly would be 9,200, too close to the limit with Weather and Earth from Orbit's storms. The
/// forecast runs 12 hours ahead, so the wind still blends from hour to hour, keeps going offline, and the last
/// reply for each zoom is cached on disk so it shows at once.
@MainActor final class WindField {
    static let shared = WindField()
    static let cols = 24, rows = 16, texels = (x: 93, y: 61)
    /// Kilometres across the screen at each zoom.
    static let spans: [Double] = [100, 800, 3500]

    /// Hourly wind at each grid point, west to east then south to north, in m/s toward east and north, around `centre`.
    struct Forecast {
        var centre: CLLocationCoordinate2D, times: [Double] = [], u: [[Float]] = [], v: [[Float]] = []
    }
    private var forecasts: [Int: Forecast] = [:]
    private var lastTry: [Int: Date] = [:]

    private static func cache(_ zoom: Int) -> URL { URL.cachesDirectory.appending(path: "com.dtanquary.atrium/wind-\(zoom).json") }

    /// Fetches the forecast for a zoom if what we have is two hours old or for somewhere else, at most every
    /// 10 minutes however many displays ask. `done` runs once a new one has landed.
    func poll(zoom: Int, done: @escaping @MainActor () -> Void) {
        let here = Location.shared.coordinate, file = Self.cache(zoom), centre = forecast(zoom: zoom).centre
        let saved = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
        let spacing = Self.spans[zoom] / 111 / Double(Self.cols) // degrees, roughly
        let moved = abs(centre.latitude - here.latitude) > spacing || abs(remainder(centre.longitude - here.longitude, 360)) > spacing
        guard Date().timeIntervalSince(saved) > 7000 || moved, Date().timeIntervalSince(lastTry[zoom] ?? .distantPast) > 600 else { return }
        lastTry[zoom] = Date()
        let points = Self.points(around: here, zoom: zoom)
        var url = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        url.queryItems = [
            URLQueryItem(name: "latitude", value: points.map { String(format: "%.3f", $0.latitude) }.joined(separator: ",")),
            URLQueryItem(name: "longitude", value: points.map { String(format: "%.3f", $0.longitude) }.joined(separator: ",")),
            URLQueryItem(name: "hourly", value: "wind_speed_10m,wind_direction_10m"),
            URLQueryItem(name: "past_hours", value: "1"), URLQueryItem(name: "forecast_hours", value: "12"),
            URLQueryItem(name: "wind_speed_unit", value: "ms"), URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "cell_selection", value: "nearest"),
        ]
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url.url!), let forecast = Self.forecast(from: data) else { return }
            try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: file)
            forecasts[zoom] = forecast
            done()
        }
    }

    /// The grid's points around a place, in a local plate carrée: west to east, then south to north.
    static func points(around here: CLLocationCoordinate2D, zoom: Int) -> [CLLocationCoordinate2D] {
        let km = spans[zoom], perDegree = 111.32, stretch = cos(here.latitude * .pi / 180)
        return (0..<rows).flatMap { j in (0..<cols).map { i in
            let x = (Double(i) / Double(cols - 1) - 0.5) * 1.2 * km, y = (Double(j) / Double(rows - 1) - 0.5) * 0.8 * km
            return CLLocationCoordinate2D(latitude: min(max(here.latitude + y / perDegree, -89), 89),
                                          longitude: remainder(here.longitude + x / (perDegree * stretch), 360))
        } }
    }

    /// A forecast from an Open-Meteo reply for many points.
    static func forecast(from reply: Data) -> Forecast? {
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
            longitude: first + points.map { remainder($0.longitude - first, 360) }.reduce(0, +) / Double(points.count)), times: times)
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
        if let data = try? Data(contentsOf: Self.cache(zoom)), let cached = Self.forecast(from: data) {
            forecasts[zoom] = cached
            return cached
        }
        var u = [Float](), v = [Float]()
        for j in 0..<Self.rows { for i in 0..<Self.cols {
            let x = Float(i) / Float(Self.cols - 1) * 1.5 - 1.0, y = Float(j) / Float(Self.rows - 1) - 0.7
            let r2 = x * x + y * y, swirl = 9 * exp(-r2 * 2.2)
            u.append(5 - y * swirl - x * 1.5)
            v.append(x * swirl + 1.5 * sin(x * 2.5))
        } }
        return Forecast(centre: Location.shared.coordinate, times: [0], u: [u], v: [v])
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
            let gx = (Float(x) + 0.5) / Float(tx) * Float(Self.cols - 1), gy = (Float(y) + 0.5) / Float(ty) * Float(Self.rows - 1)
            let o = (y * tx + x) * 4
            bytes[o] = UInt8((min(max(0.5 + 0.5 * Self.catmullRom(u, gx, gy) / vmax, 0), 1) * 255).rounded())
            bytes[o + 1] = UInt8((min(max(0.5 + 0.5 * Self.catmullRom(v, gx, gy) / vmax, 0), 1) * 255).rounded())
        } }
        return (bytes, vmax)
    }

    /// Catmull–Rom interpolation of a grid at a point in grid units, clamped at the edges.
    private static func catmullRom(_ grid: [Float], _ x: Float, _ y: Float) -> Float {
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

/// The map under the streaks, from Natural Earth (public domain, naturalearthdata.com): its coastlines and lake
/// shores, and its 1:10m shaded relief. Both are drawn once, when the scene is built, in the wind's local plate
/// carrée: `kmAcross` fills the width, centred on `centre`.
struct WindMap {
    let centre: CLLocationCoordinate2D, kmAcross: Double, size: CGSize

    /// Coastlines and lake shores (ne_10m_coastline and ne_10m_lakes, simplified to 0.002°): records of an Int32
    /// count n, a Float32 bounding box (west, south, east, north), then n × Float32 (longitude, latitude).
    private static let coast = try? Data(contentsOf: resource("wind-coast.bin"), options: .alwaysMapped)
    /// The shaded relief (SR_HR, 60 px a degree, 3×3 median filtered) cut into 15° greyscale HEIC tiles: four Int32
    /// (15, 24 columns, 12 rows, pixels a degree), then an Int32 offset and length for each tile from the north-west,
    /// row by row; a length of 0 is open sea. Level ground and water are grey 205, lit slopes lighter and shaded
    /// ones darker. HEIC, since JPEG's blocks showed as a grid of faint boxes once magnified.
    private static let relief = try? Data(contentsOf: resource("wind-relief.bin"), options: .alwaysMapped)

    /// Points per degree east and north.
    private var scale: (x: Double, y: Double) {
        let perDegree = 111.32 * Double(size.width) / kmAcross
        return (perDegree * cos(centre.latitude * .pi / 180), perDegree)
    }

    func point(_ lon: Double, _ lat: Double) -> CGPoint {
        CGPoint(x: size.width / 2 + remainder(lon - centre.longitude, 360) * scale.x, y: size.height / 2 + (lat - centre.latitude) * scale.y)
    }

    /// The coastlines as lines on a clear texture.
    func coastlines(width: CGFloat, colour: CGColor) -> SKTexture {
        paint(size) { context in
            guard let data = Self.coast else { return }
            context.setStrokeColor(colour)
            context.setLineWidth(width)
            context.setLineJoin(.round)
            let view = CGRect(origin: .zero, size: size).insetBy(dx: -10, dy: -10)
            data.withUnsafeBytes { raw in
                var offset = 0
                while offset + 20 <= raw.count {
                    let n = Int(raw.load(fromByteOffset: offset, as: Int32.self))
                    let box = (0..<4).map { Double(raw.load(fromByteOffset: offset + 4 + $0 * 4, as: Float32.self)) }
                    let corners = [point(box[0], box[1]), point(box[2], box[3])]
                    let bounds = CGRect(x: corners[0].x, y: corners[0].y, width: 0, height: 0).union(CGRect(origin: corners[1], size: .zero))
                    // skip what wraps round the globe, and lakes too small to see
                    if bounds.intersects(view), bounds.width < size.width * 4, max(bounds.width, bounds.height) > 20 {
                        for i in 0..<n {
                            let at = offset + 20 + i * 8
                            let p = point(Double(raw.load(fromByteOffset: at, as: Float32.self)), Double(raw.load(fromByteOffset: at + 4, as: Float32.self)))
                            if i == 0 { context.move(to: p) } else { context.addLine(to: p) }
                        }
                        context.strokePath()
                    }
                    offset += 20 + n * 8
                }
            }
        }
    }

    /// The shaded relief as a greyscale texture at one pixel a point.
    func shadedRelief() -> SKTexture? {
        guard let data = Self.relief else { return nil }
        let (w, h) = (Int(size.width), Int(size.height))
        guard let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        context.setFillColor(gray: 206.0 / 255, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: w, height: h))
        context.interpolationQuality = .high
        data.withUnsafeBytes { raw in
            let int = { Int(raw.load(fromByteOffset: $0 * 4, as: Int32.self)) }
            let (degrees, cols, rows) = (Double(int(0)), int(1), int(2))
            let halfLon = Double(size.width) / 2 / scale.x, halfLat = Double(size.height) / 2 / scale.y
            let west = Int(floor((centre.longitude - halfLon + 180) / degrees)), east = Int(floor((centre.longitude + halfLon + 180) / degrees))
            let north = max(Int(floor((90 - centre.latitude - halfLat) / degrees)), 0)
            let south = min(Int(floor((90 - centre.latitude + halfLat) / degrees)), rows - 1)
            guard north <= south, east - west < cols else { return }
            for j in north...south { for i in west...east {
                let tile = j * cols + (i % cols + cols) % cols
                let (start, length) = (int(4 + tile * 2), int(5 + tile * 2))
                guard length > 0, let source = CGImageSourceCreateWithData(Data(raw[start..<start + length]) as CFData, nil),
                      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { continue }
                let lon = Double(i) * degrees - 180, lat = 90 - Double(j + 1) * degrees
                let corner = point(lon, lat)
                context.draw(image, in: CGRect(x: corner.x, y: corner.y, width: degrees * scale.x, height: degrees * scale.y))
            } }
        }
        return context.makeImage().map { SKTexture(cgImage: $0) }
    }
}
