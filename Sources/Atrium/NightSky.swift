import SpriteKit
import simd

@MainActor func nightSky(size: CGSize) -> SKScene { NightSky(size: size) }

/// The real sky above you right now, facing the equator, as it would be with the daylight switched off: stars, the
/// Milky Way, constellations, planets, the Moon in its true phase, the ISS, and the odd meteor. It's dark at noon too,
/// with the Sun drawn among the stars it hides, and a warm band low toward it around sunrise and sunset.
final class NightSky: SKScene, BatteryPaced {
    /// 15 fps on battery, where the ISS, the fastest steady thing, moves up to 2.4 px a frame; the battery's rate
    /// while a meteor crosses, at 1,000 px a second, for its 0.7 s.
    var batteryRate: Int? = 15 { didSet { batteryRateChanged(from: oldValue) } }
    nonisolated static let knobs = [
        Knob(key: "sky.constellations", label: "Constellation lines", range: 0...1, standard: 1, section: "Show",
             format: .toggle),
        Knob(key: "sky.planetLabels", label: "Planet labels", range: 0...1, standard: 1, section: "Show", format: .toggle),
        Knob(key: "sky.landscape", label: "Show a landscape", range: 0...1, standard: 0, section: "Landscape",
             format: .toggle),
        Knob(key: "sky.ground", label: "Landscape", range: 0...Double(Landscape.allCases.count - 1), standard: 0,
             section: "Landscape", format: .choice(Landscape.allCases.map(\.name)), shownWhen: "sky.landscape"),
        Knob(key: "sky.previewTime", label: "Preview a time of day", range: 0...1, standard: 0, section: "Preview",
             format: .toggle),
        Knob(key: "sky.previewHour", label: "Time", range: 0...24, standard: 13, section: "Preview", format: .clock,
             shownWhen: "sky.previewTime"),
    ]

    private var stars: [(node: SKSpriteNode, position: Sky.Vector)] = []
    private var constellationLines: [[Sky.Vector]] = []
    private let constellations = SKShapeNode()
    private var planets: [(planet: Sky.Planet, node: SKSpriteNode)] = []
    private let sun = SKSpriteNode()
    private let sunGlow = SKSpriteNode()
    private let moon = SKSpriteNode(color: .white, size: CGSize(width: 46, height: 46))
    private let moonGlow = SKSpriteNode()
    private let moonLight = SKUniform(name: "u_light", vectorFloat3: [0, 0, 1])
    private let iss = SKSpriteNode()
    private let photoFrame = SKUniform(name: "u_toPhoto", matrixFloat3x3: matrix_identity_float3x3)
    private let twilightUniform = SKUniform(name: "u_twilight", float: 0)
    private let sunUniform = SKUniform(name: "u_sun", vectorFloat3: [0, 0, 1])

    /// The horizon's height on screen: `landHorizon` with a landscape, and the bottom edge without one, so the sky
    /// fills the screen and nothing in it is below the horizon.
    private var horizonY: CGFloat = 0
    private var landHorizon: CGFloat { size.height * 0.12 }
    private let horizonUniform = SKUniform(name: "u_horizon", float: 0)
    private let ground = SKNode()
    private var landscape: Landscape?
    private var compass: [SKLabelNode] = []
    /// Points per unit of stereographic plane, for a ~120° field of view across the screen.
    private var scale: Double { Double(size.width) / 2 / (2 * tan(120.0 / 4 * .pi / 180)) }
    /// The direction we face: south, or north from the southern hemisphere.
    private var facingSouth: Bool { Location.shared.coordinate.latitude >= 0 }
    private var toHorizon = matrix_identity_double3x3

    override func sceneDidLoad() {
        backgroundColor = .black
        addSkyBackground()
        addChild(constellations)
        constellations.strokeColor = NSColor(red: 0.55, green: 0.7, blue: 1, alpha: 0.1)
        constellations.lineWidth = 1
        constellations.zPosition = 1
        addStars()
        addPlanets()
        addSun()
        addMoon()
        iss.texture = glow
        iss.size = CGSize(width: 12, height: 12)
        iss.zPosition = 4
        iss.addChild(label("ISS", alpha: 0.6))
        addChild(iss)
        addHorizon()

        run(.repeatForever(.sequence([.wait(forDuration: 5), .run { [weak self] in self?.refresh() }])))
        applySettings()
        NotificationCenter.default.addObserver(self, selector: #selector(applySettings),
                                               name: UserDefaults.didChangeNotification, object: nil)
        run(.repeatForever(.sequence([.wait(forDuration: 45, withRange: 60), .run { [weak self] in self?.meteor() }])))
    }

    override func didMove(to view: SKView) {
        Location.shared.start()
        run(.repeatForever(.sequence([.run { ISS.shared.poll() }, .wait(forDuration: 60)])))
    }

    override func update(_ currentTime: TimeInterval) {
        let here = Location.shared.coordinate
        guard let station = ISS.shared.position(), station.sunlit else { iss.isHidden = true; return }
        let look = Sky.lookDirection(latitude: here.latitude, longitude: here.longitude,
                                     toLatitude: station.latitude, longitude: station.longitude, altitude: station.altitude)
        place(iss, at: look)
    }

    /// Shows or hides the constellation lines, planet labels and landscape as Settings says, and redraws for a
    /// preview time.
    @objc private func applySettings() {
        constellations.isHidden = Self.knobs[0].value < 0.5
        for planet in planets { planet.node.children.forEach { $0.isHidden = Self.knobs[1].value < 0.5 } } // their labels
        ground.isHidden = Self.knobs[2].value < 0.5
        let pick = Landscape.allCases[min(Int(Self.knobs[3].value), Landscape.allCases.count - 1)]
        if !ground.isHidden, pick != landscape { paintGround(pick) }
        horizonY = ground.isHidden ? 0 : landHorizon
        horizonUniform.floatValue = Float(horizonY)
        for letter in compass { letter.position.y = ground.isHidden ? 8 : landHorizon * 0.3 }
        refresh()
    }

    /// Now, or today at the preview hour while previewing a time of day.
    private var skyDate: Date {
        guard Self.knobs[4].value > 0.5 else { return Date() }
        return Calendar.current.startOfDay(for: Date()).addingTimeInterval(Self.knobs[5].value * 3600)
    }

    // MARK: Projection

    /// Stereographic projection centred on the horizon point we face, so the horizon is a straight line.
    private func project(_ h: Sky.Vector) -> CGPoint? {
        let forward = facingSouth ? -h.y : h.y, right = facingSouth ? -h.x : h.x
        guard 1 + forward > 0.2 else { return nil }
        let k = 2 / (1 + forward) * scale
        return CGPoint(x: Double(size.width) / 2 + k * right, y: Double(horizonY) + k * h.z)
    }

    /// Shows a node at a horizon direction if it's above the horizon and on screen.
    private func place(_ node: SKNode, at h: Sky.Vector) {
        guard h.z > -0.01, let point = project(h), frame.insetBy(dx: -30, dy: -30).contains(point) else {
            node.isHidden = true
            return
        }
        node.isHidden = false
        node.position = point
    }

    /// Screen angle of the direction from one sky point toward another, e.g. from the Moon toward the Sun.
    private func screenAngle(from a: Sky.Vector, toward b: Sky.Vector) -> CGFloat {
        let step = normalize(a + 0.01 * normalize(b - a * dot(a, b)))
        guard let p = project(a), let q = project(step) else { return 0 }
        return atan2(q.y - p.y, q.x - p.x)
    }

    /// Angle of the direction from sky point `a` toward `b`, as seen facing `a` with your head upright (0 = right).
    private func skyAngle(from a: Sky.Vector, toward b: Sky.Vector) -> Double {
        let up = a.z > 0.999 ? Sky.Vector(0, 1, 0) : normalize(Sky.Vector(0, 0, 1) - a * a.z)
        let t = b - a * dot(a, b)
        return atan2(dot(t, up), dot(t, cross(a, up)))
    }

    /// Recomputes every position for the current time and place.
    private func refresh() {
        let here = Location.shared.coordinate
        let jd = Sky.julianDate(skyDate)
        toHorizon = Sky.horizonMatrix(jd: jd, latitude: here.latitude, longitude: here.longitude)

        let sunH = toHorizon * Sky.sun(jd)
        let sunAltitude = asin(sunH.z) * 180 / .pi
        for star in stars { place(star.node, at: toHorizon * star.position) }
        for (planet, node) in planets { place(node, at: toHorizon * Sky.planet(planet, jd)) }

        // Sunrise and sunset glow peaks with the Sun just below the horizon.
        twilightUniform.floatValue = Float(simd_smoothstep(-16, -4, sunAltitude) * (1 - simd_smoothstep(4, 14, sunAltitude)))
        sunUniform.vectorFloat3Value = facingSouth ? [Float(-sunH.x), Float(sunH.z), Float(-sunH.y)]
                                                   : [Float(sunH.x), Float(sunH.z), Float(sunH.y)]
        place(sun, at: sunH)
        sunGlow.position = sun.position
        sunGlow.isHidden = sun.isHidden
        sun.colorBlendFactor = CGFloat(1 - simd_smoothstep(0, 12, sunAltitude)) // redder near the horizon

        // SpriteKit strokes the whole path again every frame, so leave out the lines it can't show: each unbroken
        // run of a constellation goes in whole (cutting one changes the pixels of the rest) or not at all, when every
        // segment of it is off one side of the screen, as is all of it while the lines are hidden.
        let path = CGMutablePath(), screen = frame.insetBy(dx: -30, dy: -30)
        func onScreen(_ a: CGPoint, _ b: CGPoint) -> Bool {
            max(a.x, b.x) >= screen.minX && min(a.x, b.x) <= screen.maxX && max(a.y, b.y) >= screen.minY && min(a.y, b.y) <= screen.maxY
        }
        for strip in constellationLines where !constellations.isHidden {
            var run: [CGPoint] = [], shows = false // the run above the horizon so far; whether any of it shows
            for point in strip + [nil] { // nil ends the last run
                let h = point.map { toHorizon * $0 }
                if let h, h.z > 0, let p = project(h) {
                    if let a = run.last, onScreen(a, p) { shows = true }
                    run.append(p)
                } else {
                    if shows { path.addLines(between: run) }
                    run = []; shows = false
                }
            }
        }
        constellations.path = path

        // Moon: turn the disc so its north points to the celestial pole, then light it from the Sun. The light is
        // measured from the Moon's north, so it holds however the disc is turned.
        let (moonH, poleH) = (toHorizon * Sky.moon(jd), toHorizon * Sky.Vector(0, 0, 1))
        let north = skyAngle(from: moonH, toward: poleH)
        let toSun = skyAngle(from: moonH, toward: sunH) - north + .pi / 2
        let lit = Sky.moonPhase(jd).lit
        let phase = acos(2 * lit - 1) // Sun–Moon–Earth angle
        moonLight.vectorFloat3Value = [Float(sin(phase) * cos(toSun)), Float(sin(phase) * sin(toSun)), Float(cos(phase))]
        place(moon, at: moonH)
        moonGlow.position = moon.position
        moonGlow.isHidden = moon.isHidden
        moonGlow.alpha = 0.5 * lit
        if !moon.isHidden { moon.zRotation = screenAngle(from: moonH, toward: poleH) - .pi / 2 }

        // The background maps screen → sky → the photo: plane (right, up, forward) → horizon → equatorial → its frame.
        let basis = facingSouth
            ? simd_double3x3(columns: ([-1, 0, 0], [0, 0, 1], [0, -1, 0]))
            : simd_double3x3(columns: ([1, 0, 0], [0, 0, 1], [0, 1, 0]))
        let toPhoto = Self.toPhoto * toHorizon.transpose * basis
        photoFrame.matrixFloat3x3Value = simd_float3x3(columns: (SIMD3<Float>(toPhoto.columns.0),
                                                                 SIMD3<Float>(toPhoto.columns.1),
                                                                 SIMD3<Float>(toPhoto.columns.2)))
    }

    // MARK: Building the scene

    private let glow = paint(CGSize(width: 16, height: 16)) { ctx in
        let colours = [CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 0.35), CGColor(gray: 1, alpha: 0)] as CFArray
        let gradient = CGGradient(colorsSpace: nil, colors: colours, locations: [0, 0.25, 1])!
        ctx.drawRadialGradient(gradient, startCenter: CGPoint(x: 8, y: 8), startRadius: 0,
                               endCenter: CGPoint(x: 8, y: 8), endRadius: 8, options: [])
    }

    private func label(_ text: String, alpha: CGFloat) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "HelveticaNeue")
        label.text = text
        label.fontSize = 11
        label.fontColor = NSColor(white: 1, alpha: alpha)
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .top
        label.position = CGPoint(x: 8, y: -5)
        return label
    }

    /// Screen colour for a B−V colour index: blue-white hot stars through to orange cool ones.
    nonisolated static func starColour(_ bv: Double) -> NSColor {
        let stops: [(Double, SIMD3<Double>)] = [(-0.3, [0.66, 0.74, 1]), (0, [0.82, 0.87, 1]), (0.4, [1, 0.98, 0.95]),
                                                (0.8, [1, 0.92, 0.8]), (1.2, [1, 0.84, 0.66]), (2, [1, 0.72, 0.5])]
        let i = stops.lastIndex { $0.0 <= bv } ?? 0
        let (a, b) = (stops[i], stops[min(i + 1, stops.count - 1)])
        let c = b.0 > a.0 ? simd_mix(a.1, b.1, Sky.Vector(repeating: min(1, (bv - a.0) / (b.0 - a.0)))) : a.1
        return NSColor(red: c.x, green: c.y, blue: c.z, alpha: 1)
    }

    /// Lines of numbers from a Resources text file, skipping # comments.
    nonisolated fileprivate static func rows(_ file: String) -> [String] {
        ((try? String(contentsOf: resource(file), encoding: .utf8)) ?? "")
            .split(separator: "\n").filter { !$0.hasPrefix("#") }.map(String.init)
    }

    /// The Yale Bright Star Catalogue to V 5.5: direction (J2000), V magnitude and B−V colour index. Campfire's sky
    /// uses it too.
    nonisolated static let catalogue: [(direction: Sky.Vector, magnitude: Double, bv: Double)] = rows("stars.txt").compactMap { row in
        let f = row.split(separator: " ").compactMap { Double($0) }
        return f.count == 4 ? (Sky.direction(f[0], f[1]), f[2], f[3]) : nil
    }

    private func addStars() {
        for (direction, magnitude, bv) in Self.catalogue {
            let star = SKSpriteNode(texture: glow)
            let diameter = max(2.2, 11 - 1.55 * magnitude)
            star.size = CGSize(width: diameter, height: diameter)
            star.color = Self.starColour(bv)
            star.colorBlendFactor = 1
            star.alpha = min(1, max(0.35, 1.2 - 0.14 * magnitude))
            star.zPosition = 2
            if magnitude < 2 { // bright stars twinkle
                let dim = SKAction.fadeAlpha(to: star.alpha * 0.6, duration: .random(in: 0.15...0.5))
                let back = SKAction.fadeAlpha(to: star.alpha, duration: .random(in: 0.15...0.5))
                star.run(.repeatForever(.sequence([dim, back, .wait(forDuration: 0.5, withRange: 1.5)])))
            }
            addChild(star)
            stars.append((star, direction))
        }
        constellationLines = Self.rows("constellations.txt").map { line in
            line.split(separator: " ").compactMap { pair in
                let radec = pair.split(separator: ",").compactMap { Double($0) }
                return radec.count == 2 ? Sky.direction(radec[0], radec[1]) : nil
            }
        }
    }

    private func addPlanets() {
        // ponytail: fixed sizes; real brightness swings with distance and phase (Mars most, magnitude -2.9 to +1.8)
        let looks: [Sky.Planet: (CGFloat, NSColor)] = [
            .mercury: (7, NSColor(red: 1, green: 0.93, blue: 0.85, alpha: 1)),
            .venus: (13, NSColor(red: 1, green: 0.98, blue: 0.9, alpha: 1)),
            .mars: (9, NSColor(red: 1, green: 0.62, blue: 0.45, alpha: 1)),
            .jupiter: (12, NSColor(red: 1, green: 0.95, blue: 0.86, alpha: 1)),
            .saturn: (9, NSColor(red: 1, green: 0.9, blue: 0.7, alpha: 1)),
        ]
        for planet in Sky.Planet.allCases {
            let (diameter, colour) = looks[planet]!
            let node = SKSpriteNode(texture: glow, size: CGSize(width: diameter, height: diameter))
            node.color = colour
            node.colorBlendFactor = 1
            node.zPosition = 3
            node.addChild(label(planet.rawValue, alpha: 0.4))
            addChild(node)
            planets.append((planet, node))
        }
    }

    /// The Sun: a bright disc in a wide warm glow, among the stars, drawn only when it's up and in view.
    private func addSun() {
        sunGlow.texture = glow
        sunGlow.size = CGSize(width: 360, height: 360)
        sunGlow.color = NSColor(red: 1, green: 0.85, blue: 0.6, alpha: 1)
        sunGlow.colorBlendFactor = 1
        sunGlow.alpha = 0.6
        sunGlow.zPosition = 3
        addChild(sunGlow)

        sun.texture = paint(CGSize(width: 48, height: 48)) { ctx in
            let colours = [CGColor(red: 1, green: 1, blue: 0.96, alpha: 1), CGColor(red: 1, green: 0.95, blue: 0.82, alpha: 1),
                           CGColor(red: 1, green: 0.9, blue: 0.7, alpha: 0)] as CFArray
            ctx.drawRadialGradient(CGGradient(colorsSpace: nil, colors: colours, locations: [0, 0.75, 1])!,
                                   startCenter: CGPoint(x: 24, y: 24), startRadius: 0,
                                   endCenter: CGPoint(x: 24, y: 24), endRadius: 24, options: [])
        }
        sun.size = CGSize(width: 48, height: 48)
        sun.color = NSColor(red: 1, green: 0.5, blue: 0.2, alpha: 1) // blended in as it nears the horizon
        sun.zPosition = 4
        addChild(sun)
    }

    private func addMoon() {
        moonGlow.texture = glow
        moonGlow.size = CGSize(width: 220, height: 220)
        moonGlow.color = NSColor(red: 0.8, green: 0.85, blue: 1, alpha: 1)
        moonGlow.colorBlendFactor = 1
        moonGlow.zPosition = 3
        addChild(moonGlow)

        // A sphere lit from u_light (in the disc's frame), with the big maria where they sit seen from the north.
        // ponytail: maria are hand-placed soft blobs; swap in a real albedo map for more fidelity
        moon.shader = SKShader(source: moonShade + """
            float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
            float noise(vec2 x) {
                vec2 i = floor(x);
                vec2 f = fract(x);
                f = f * f * (3.0 - 2.0 * f);
                return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
            }
            float mare(vec2 p, vec2 c, float r) {
                return smoothstep(r * 1.2, r * 0.4, length(p - c) + 0.5 * r * (noise(p * 7.0) - 0.5));
            }
            void main() {
                vec2 p = v_tex_coord * 2.0 - 1.0;
                float r2 = dot(p, p);
                vec3 n = vec3(p, sqrt(max(0.0, 1.0 - r2)));
                // Procellarum, Imbrium and Frigoris down the west; Serenitatis to Nectaris down the east.
                float dark = mare(p, vec2(-0.58, 0.05), 0.34) + mare(p, vec2(-0.45, -0.25), 0.22)
                    + mare(p, vec2(-0.28, 0.42), 0.30) + mare(p, vec2(-0.05, 0.68), 0.16)
                    + mare(p, vec2(0.20, 0.40), 0.18) + mare(p, vec2(0.34, 0.14), 0.21)
                    + mare(p, vec2(0.70, 0.30), 0.12) + mare(p, vec2(0.56, -0.13), 0.15)
                    + mare(p, vec2(0.34, -0.33), 0.11) + mare(p, vec2(-0.16, -0.36), 0.16)
                    + mare(p, vec2(-0.50, -0.40), 0.10);
                float mottle = 0.9 + 0.1 * noise(p * 22.0);
                vec3 surface = vec3(0.93, 0.91, 0.86) * (1.0 - 0.3 * min(dark, 1.0)) * mottle * (0.85 + 0.15 * n.z);
                // Light to display (a square root, as Weather's film curve does), with a little earthshine on the dark side.
                float lit = sqrt(moonShade(n, u_light));
                vec3 colour = surface * lit + vec3(0.03, 0.035, 0.05) * (1.0 - min(lit, 1.0));
                float a = smoothstep(1.0, 0.93, r2);
                gl_FragColor = vec4(colour * a, a);
            }
            """, uniforms: [moonLight])
        moon.zPosition = 4
        addChild(moon)
    }

    /// J2000 equatorial → the frame of the sky's photograph, `sky-milky-way.heic`: ESO/S. Brunier's panorama of the
    /// whole sky (eso0932a, CC BY 4.0), a plate carrée in galactic coordinates with the galactic centre in the middle.
    /// The photo sits 3.8° off true galactic coordinates. This turn, fitted to 516 of the catalogue's stars found in
    /// it, puts its stars under ours to within 0.14°, a point and a half on a 1512-point display.
    nonisolated static let toPhoto = simd_double3x3(rows: [
        [0.998018, 0.055626, -0.029440], [-0.055074, 0.998297, 0.019237], [0.030460, -0.017578, 0.999381],
    ]) * Sky.galactic

    /// Dark sky, a little lighter toward the horizon, behind a photograph of the real one turned to where it is now:
    /// the Milky Way and its dust, the Magellanic Clouds, Andromeda, the nebulae, and the stars too faint for the
    /// catalogue. Around sunrise and sunset a warm band glows low toward the Sun.
    private func addSkyBackground() {
        let sky = SKSpriteNode(color: .black, size: size)
        sky.anchorPoint = .zero
        sky.shader = SKShader(source: """
            float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
            void main() {
                vec2 p = (v_tex_coord * u_size - vec2(0.5 * u_size.x, u_horizon)) / u_scale;
                float r2 = dot(p, p);
                vec3 d = vec3(4.0 * p, 4.0 - r2) / (4.0 + r2); // back onto the sphere: (right, up, forward)
                float height = smoothstep(-0.05, 0.7, d.y);
                vec3 colour = mix(vec3(0.05, 0.065, 0.12), vec3(0.006, 0.01, 0.028), height);

                // The photo, less its own sky glow, dimming toward the horizon as the real sky does through more air.
                vec3 g = u_toPhoto * d;
                vec2 at = vec2(0.5 - atan(g.y, g.x) / 6.2831853, 0.5 + asin(clamp(g.z, -1.0, 1.0)) / 3.1415927);
                // A film's shoulder keeps the galactic centre from burning out while the fainter arms stay in sight.
                vec3 photo = max(texture2D(u_photo, at).rgb - 0.05, 0.0);
                colour += (1.0 - exp(-1.5 * photo)) * mix(0.45, 1.0, smoothstep(0.0, 0.3, d.y));

                // Sunrise and sunset: a warm band low in the sky, strongest toward the Sun's azimuth.
                float sunward = exp((dot(normalize(d.xz), normalize(u_sun.xz + vec2(0.0, 0.0001))) - 1.0) * 2.5);
                float low = exp(-max(d.y, 0.0) * 6.0);
                colour += u_twilight * low * (vec3(0.14, 0.07, 0.15) + vec3(0.95, 0.4, 0.1) * sunward);

                colour += (hash(v_tex_coord * u_size) - 0.5) / 255.0; // dither away banding
                gl_FragColor = vec4(colour, 1.0);
            }
            """, uniforms: [
                SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)]),
                horizonUniform,
                SKUniform(name: "u_scale", float: Float(scale)),
                SKUniform(name: "u_photo", texture: sharedTexture("sky-milky-way.heic")),
                photoFrame, twilightUniform, sunUniform,
            ])
        addChild(sky)
    }

    /// Paints a silhouette along the bottom, in place of the one before.
    private func paintGround(_ pick: Landscape) {
        landscape = pick
        let (width, horizon, scale) = (size.width, landHorizon, CGFloat(scale))
        let strip = CGSize(width: width, height: pick.height(horizon: horizon, scale: scale))
        let land = SKSpriteNode(texture: paint(strip) { ctx in
            ctx.setFillColor(CGColor(red: 0.008, green: 0.01, blue: 0.02, alpha: 1))
            pick.paint(ctx, width: width, horizon: horizon, scale: scale)
        }, size: strip)
        land.anchorPoint = .zero
        ground.removeAllChildren()
        ground.addChild(land)
    }

    /// The landscape's node, empty until `applySettings` has one to show, and faint compass points.
    private func addHorizon() {
        ground.zPosition = 6
        addChild(ground)

        let points = facingSouth ? ["SE", "S", "SW"] : ["NW", "N", "NE"]
        for (i, name) in points.enumerated() {
            let offset = CGFloat(i - 1) * 2 * tan(22.5 * .pi / 180) * CGFloat(scale)
            let letter = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
            letter.text = name
            letter.fontSize = 12
            letter.fontColor = NSColor(white: 1, alpha: i == 1 ? 0.3 : 0.18)
            letter.position.x = size.width / 2 + offset
            letter.zPosition = 7
            addChild(letter)
            compass.append(letter)
        }
    }

    /// A short bright streak across the upper sky.
    private func meteor() {
        let streak = SKSpriteNode(texture: paint(CGSize(width: 140, height: 2)) { ctx in
            let colours = [CGColor(gray: 1, alpha: 0), CGColor(gray: 1, alpha: 0.9)] as CFArray
            ctx.drawLinearGradient(CGGradient(colorsSpace: nil, colors: colours, locations: [0, 1])!,
                                   start: .zero, end: CGPoint(x: 140, y: 0), options: [])
        }, size: CGSize(width: 140, height: 2))
        let angle = CGFloat.random(in: -2.6 ... -0.5)
        streak.zRotation = angle
        streak.position = CGPoint(x: .random(in: size.width * 0.1...size.width * 0.9),
                                  y: .random(in: size.height * 0.5...size.height * 0.95))
        streak.alpha = 0
        streak.zPosition = 5
        addChild(streak)
        batteryRate = nil
        let travel = CGFloat.random(in: 180...360)
        streak.run(.sequence([
            .group([.moveBy(x: cos(angle) * travel, y: sin(angle) * travel, duration: 0.7),
                    .sequence([.fadeIn(withDuration: 0.1), .fadeOut(withDuration: 0.6)])]),
            .run { [weak self] in self?.batteryRate = 15 },
            .removeFromParent(),
        ]))
    }
}

/// The silhouettes Night Sky can stand on, named as Settings lists them. It stores the pick by its place here, so add
/// new ones at the end.
enum Landscape: String, CaseIterable {
    case pines = "Pine ridge", monument = "Monument Valley", tetons = "Teton Range", shiprock = "Shiprock",
         tower = "Devils Tower", fuji = "Mount Fuji"

    var name: String { rawValue }

    /// A real skyline, from `sky-<case>.txt` (made by docs/night-sky/horizon.py): degrees right of the view's centre
    /// and degrees above the horizon, as seen from the place its header names. Empty for the pines, which are drawn.
    var profile: [(azimuth: CGFloat, altitude: CGFloat)] {
        NightSky.rows("sky-\(self).txt").compactMap { row in
            let f = row.split(separator: " ").compactMap { Double($0) }
            return f.count == 2 ? (f[0] * .pi / 180, f[1] * .pi / 180) : nil
        }
    }

    /// How tall its strip is: room for its tallest feature. `horizon` is the true horizon's height in points, and
    /// `scale` the sky's points per unit of its stereographic plane.
    func height(horizon: CGFloat, scale: CGFloat) -> CGFloat {
        switch self {
        case .pines: horizon + 60
        default: horizon + 1.35 * scale * sin(profile.map(\.altitude).max() ?? 0) + 2 // 1.35: the projection's stretch at the edges
        }
    }

    /// Paints it in the context's fill colour, `width` points across.
    func paint(_ ctx: CGContext, width: CGFloat, horizon: CGFloat, scale: CGFloat) {
        switch self {
        case .pines:
            // Rolling hills, with stands of conifers along the higher stretches: stacked tiers, varied heights and gaps.
            let ridge = { (x: CGFloat) in horizon * (0.72 + 0.16 * sin(x / 260 + 1) + 0.08 * sin(x / 83)) }
            ctx.move(to: .zero)
            for x in stride(from: 0, through: width + 4, by: 4) { ctx.addLine(to: CGPoint(x: x, y: ridge(x))) }
            ctx.addLine(to: CGPoint(x: width + 4, y: 0))
            ctx.fillPath()
            var x: CGFloat = 0
            while x < width {
                if sin(x / 210) + 0.5 * sin(x / 53) > 0.35 {
                    let (tall, y) = (CGFloat.random(in: 16...46), ridge(x) - 3)
                    for tier in 0..<4 {
                        let (base, top) = (y + tall * CGFloat(tier) * 0.2, y + tall * (0.45 + CGFloat(tier) * 0.19))
                        let half = tall * 0.2 * (1 - CGFloat(tier) * 0.2)
                        ctx.move(to: CGPoint(x: x - half, y: base))
                        ctx.addLine(to: CGPoint(x: x, y: top))
                        ctx.addLine(to: CGPoint(x: x + half, y: base))
                    }
                    ctx.addRect(CGRect(x: x - 1, y: y - 4, width: 2, height: 8))
                    ctx.fillPath()
                }
                x += .random(in: 5...13)
            }
        default:
            // A real skyline goes through the sky's own projection, so it stands as wide and as tall as it would
            // among these stars. Its ends are carried out to the screen's edges.
            let points = profile.map { p in
                let k = 2 / (1 + cos(p.altitude) * cos(p.azimuth)) * scale
                return CGPoint(x: width / 2 + k * cos(p.altitude) * sin(p.azimuth), y: horizon + k * sin(p.altitude))
            }
            guard let first = points.first, let last = points.last else { return }
            ctx.move(to: CGPoint(x: -2, y: 0))
            ctx.addLine(to: CGPoint(x: -2, y: first.y))
            points.forEach(ctx.addLine)
            ctx.addLine(to: CGPoint(x: width + 2, y: last.y))
            ctx.addLine(to: CGPoint(x: width + 2, y: 0))
            ctx.fillPath()
        }
    }
}
