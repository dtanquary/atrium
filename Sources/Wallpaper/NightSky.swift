import SpriteKit
import simd

@MainActor func nightSky(size: CGSize) -> SKScene { NightSky(size: size) }

/// The real sky above you right now, facing the equator: stars, Milky Way, constellations, planets, the Moon in
/// its true phase, the ISS, and the odd meteor. It stays a night sky but reacts to the Sun: deep blue by day with
/// only the brightest stars and planets, the Sun drawn when it's in view, and sunrise and sunset glow on time.
final class NightSky: SKScene {
    nonisolated static let knobs = [
        Knob(key: "sky.constellations", label: "Constellation lines", range: 0...1, standard: 1, section: "Show",
             format: .toggle),
        Knob(key: "sky.planetLabels", label: "Planet labels", range: 0...1, standard: 1, section: "Show", format: .toggle),
        Knob(key: "sky.previewTime", label: "Preview a time of day", range: 0...1, standard: 0, section: "Preview",
             format: .toggle),
        Knob(key: "sky.previewHour", label: "Time", range: 0...24, standard: 13, section: "Preview", format: .clock,
             shownWhen: "sky.previewTime"),
    ]

    private var stars: [(node: SKSpriteNode, position: Sky.Vector)] = []
    private var constellationLines: [[Sky.Vector]] = []
    private let constellations = SKShapeNode()
    private let starLayers = (0..<16).map { _ in SKNode() } // by half magnitude, so daylight can fade the faint ones
    private var planets: [(planet: Sky.Planet, node: SKSpriteNode, magnitude: Double)] = []
    private let sun = SKSpriteNode()
    private let sunGlow = SKSpriteNode()
    private let moon = SKSpriteNode(color: .white, size: CGSize(width: 46, height: 46))
    private let moonGlow = SKSpriteNode()
    private let moonLight = SKUniform(name: "u_light", vectorFloat3: [0, 0, 1])
    private let iss = SKSpriteNode()
    private let galacticUniform = SKUniform(name: "u_galactic", matrixFloat3x3: matrix_identity_float3x3)
    private let dayUniform = SKUniform(name: "u_day", float: 0)
    private let twilightUniform = SKUniform(name: "u_twilight", float: 0)
    private let sunUniform = SKUniform(name: "u_sun", vectorFloat3: [0, 0, 1])

    private var horizonY: CGFloat { size.height * 0.12 }
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
        starLayers.forEach(addChild)
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

        refresh()
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

    /// Shows or hides the constellation lines and planet labels as Settings says, and redraws for a preview time.
    @objc private func applySettings() {
        constellations.isHidden = Self.knobs[0].value < 0.5
        for planet in planets { planet.node.children.forEach { $0.isHidden = Self.knobs[1].value < 0.5 } } // their labels
        refresh()
    }

    /// Now, or today at the preview hour while previewing a time of day.
    private var skyDate: Date {
        guard Self.knobs[2].value > 0.5 else { return Date() }
        return Calendar.current.startOfDay(for: Date()).addingTimeInterval(Self.knobs[3].value * 3600)
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

        // Daylight: the sky turns deep blue and everything fainter than `limit` fades out.
        let sunH = toHorizon * Sky.sun(jd)
        let sunAltitude = asin(sunH.z) * 180 / .pi
        let day = simd_smoothstep(-14, 4, sunAltitude)
        let limit = 6 - 4.5 * day // faintest magnitude still showing
        let visibility = { (magnitude: Double) in CGFloat(min(1, max(0, limit - magnitude))) }
        for (i, layer) in starLayers.enumerated() { layer.alpha = visibility(Double(i) / 2 - 1.75) }
        for star in stars { place(star.node, at: toHorizon * star.position) }
        for (planet, node, magnitude) in planets {
            place(node, at: toHorizon * Sky.planet(planet, jd))
            node.alpha = visibility(magnitude)
        }
        constellations.alpha = CGFloat(1 - day)

        // Sunrise and sunset glow peaks with the Sun just below the horizon.
        dayUniform.floatValue = Float(day)
        twilightUniform.floatValue = Float(simd_smoothstep(-16, -4, sunAltitude) * (1 - simd_smoothstep(4, 14, sunAltitude)))
        sunUniform.vectorFloat3Value = facingSouth ? [Float(-sunH.x), Float(sunH.z), Float(-sunH.y)]
                                                   : [Float(sunH.x), Float(sunH.z), Float(sunH.y)]
        place(sun, at: sunH)
        sunGlow.position = sun.position
        sunGlow.isHidden = sun.isHidden
        sun.colorBlendFactor = CGFloat(1 - simd_smoothstep(0, 12, sunAltitude)) // redder near the horizon

        let path = CGMutablePath()
        for strip in constellationLines {
            var drawing = false
            for point in strip {
                let h = toHorizon * point
                if h.z > 0, let p = project(h) {
                    drawing ? path.addLine(to: p) : path.move(to: p)
                    drawing = true
                } else {
                    drawing = false
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
        moonGlow.alpha = 0.5 * lit * (1 - 0.7 * day)
        if !moon.isHidden { moon.zRotation = screenAngle(from: moonH, toward: poleH) - .pi / 2 }


        // The Milky Way shader maps screen → sky → galactic: plane (right, up, forward) → horizon → equatorial → galactic.
        let basis = facingSouth
            ? simd_double3x3(columns: ([-1, 0, 0], [0, 0, 1], [0, -1, 0]))
            : simd_double3x3(columns: ([1, 0, 0], [0, 0, 1], [0, 1, 0]))
        let toGalactic = Sky.galactic * toHorizon.transpose * basis
        galacticUniform.matrixFloat3x3Value = simd_float3x3(columns: (SIMD3<Float>(toGalactic.columns.0),
                                                                     SIMD3<Float>(toGalactic.columns.1),
                                                                     SIMD3<Float>(toGalactic.columns.2)))
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
    private func starColour(_ bv: Double) -> NSColor {
        let stops: [(Double, SIMD3<Double>)] = [(-0.3, [0.66, 0.74, 1]), (0, [0.82, 0.87, 1]), (0.4, [1, 0.98, 0.95]),
                                                (0.8, [1, 0.92, 0.8]), (1.2, [1, 0.84, 0.66]), (2, [1, 0.72, 0.5])]
        let i = stops.lastIndex { $0.0 <= bv } ?? 0
        let (a, b) = (stops[i], stops[min(i + 1, stops.count - 1)])
        let c = b.0 > a.0 ? simd_mix(a.1, b.1, Sky.Vector(repeating: min(1, (bv - a.0) / (b.0 - a.0)))) : a.1
        return NSColor(red: c.x, green: c.y, blue: c.z, alpha: 1)
    }

    /// Lines of numbers from a Resources text file, skipping # comments.
    private func rows(_ file: String) -> [String] {
        ((try? String(contentsOf: resource(file), encoding: .utf8)) ?? "")
            .split(separator: "\n").filter { !$0.hasPrefix("#") }.map(String.init)
    }

    private func addStars() {
        for row in rows("stars.txt") {
            let f = row.split(separator: " ").compactMap { Double($0) }
            guard f.count == 4 else { continue }
            let star = SKSpriteNode(texture: glow)
            let diameter = max(2.2, 11 - 1.55 * f[2])
            star.size = CGSize(width: diameter, height: diameter)
            star.color = starColour(f[3])
            star.colorBlendFactor = 1
            star.alpha = min(1, max(0.35, 1.2 - 0.14 * f[2]))
            star.zPosition = 2
            if f[2] < 2 { // bright stars twinkle
                let dim = SKAction.fadeAlpha(to: star.alpha * 0.6, duration: .random(in: 0.15...0.5))
                let back = SKAction.fadeAlpha(to: star.alpha, duration: .random(in: 0.15...0.5))
                star.run(.repeatForever(.sequence([dim, back, .wait(forDuration: 0.5, withRange: 1.5)])))
            }
            starLayers[min(15, max(0, Int((f[2] + 2) * 2)))].addChild(star)
            stars.append((star, Sky.direction(f[0], f[1])))
        }
        constellationLines = rows("constellations.txt").map { line in
            line.split(separator: " ").compactMap { pair in
                let radec = pair.split(separator: ",").compactMap { Double($0) }
                return radec.count == 2 ? Sky.direction(radec[0], radec[1]) : nil
            }
        }
    }

    private func addPlanets() {
        // Diameter, colour, and a typical magnitude for fading them by day.
        // ponytail: fixed magnitudes; real ones swing with distance and phase (Mars most, ~-2.9 to +1.8)
        let looks: [Sky.Planet: (CGFloat, NSColor, Double)] = [
            .mercury: (7, NSColor(red: 1, green: 0.93, blue: 0.85, alpha: 1), 0),
            .venus: (13, NSColor(red: 1, green: 0.98, blue: 0.9, alpha: 1), -4.2),
            .mars: (9, NSColor(red: 1, green: 0.62, blue: 0.45, alpha: 1), 0.5),
            .jupiter: (12, NSColor(red: 1, green: 0.95, blue: 0.86, alpha: 1), -2.2),
            .saturn: (9, NSColor(red: 1, green: 0.9, blue: 0.7, alpha: 1), 0.7),
        ]
        for planet in Sky.Planet.allCases {
            let (diameter, colour, magnitude) = looks[planet]!
            let node = SKSpriteNode(texture: glow, size: CGSize(width: diameter, height: diameter))
            node.color = colour
            node.colorBlendFactor = 1
            node.zPosition = 3
            node.addChild(label(planet.rawValue, alpha: 0.4))
            addChild(node)
            planets.append((planet, node, magnitude))
        }
    }

    /// The Sun: a bright disc in a wide warm glow, drawn only when it's up and in view.
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
        moon.shader = SKShader(source: """
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
                float lit = smoothstep(-0.04, 0.08, dot(n, u_light));
                vec3 colour = surface * lit + vec3(0.03, 0.035, 0.05) * (1.0 - lit);
                float a = smoothstep(1.0, 0.93, r2);
                gl_FragColor = vec4(colour * a, a);
            }
            """, uniforms: [moonLight])
        moon.zPosition = 4
        addChild(moon)
    }

    /// Dark sky, brighter toward the horizon, with the Milky Way painted where it really is. By day it's deep blue
    /// and the Milky Way fades; around sunrise and sunset a warm band glows low toward the Sun.
    private func addSkyBackground() {
        let sky = SKSpriteNode(color: .black, size: size)
        sky.anchorPoint = .zero
        sky.shader = SKShader(source: """
            float hash(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
            float noise(vec3 x) {
                vec3 i = floor(x);
                vec3 f = fract(x);
                f = f * f * (3.0 - 2.0 * f);
                return mix(mix(mix(hash(i), hash(i + vec3(1.0, 0.0, 0.0)), f.x),
                               mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
                           mix(mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x),
                               mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
            }
            void main() {
                vec2 p = (v_tex_coord * u_size - vec2(0.5 * u_size.x, u_horizon)) / u_scale;
                float r2 = dot(p, p);
                vec3 d = vec3(4.0 * p, 4.0 - r2) / (4.0 + r2); // back onto the sphere: (right, up, forward)
                float height = smoothstep(-0.05, 0.7, d.y);
                vec3 night = mix(vec3(0.05, 0.065, 0.12), vec3(0.006, 0.01, 0.028), height);
                vec3 day = mix(vec3(0.15, 0.29, 0.52), vec3(0.03, 0.1, 0.3), height);
                vec3 colour = mix(night, day, u_day);

                vec3 g = u_galactic * d;
                float b = asin(clamp(g.z, -1.0, 1.0));
                float l = atan(g.y, g.x);
                float disc = exp(-b * b / 0.03) * (0.45 + 0.55 * cos(l) * cos(l * 0.5));
                float bulge = exp(-l * l / 0.2 - b * b / 0.05);
                float clouds = 0.5 * noise(g * 7.0) + 0.3 * noise(g * 17.0) + 0.2 * noise(g * 43.0);
                float lane = 1.0 - 0.75 * exp(-(b - 0.015) * (b - 0.015) / 0.0012) * smoothstep(1.6, 0.3, abs(l));
                colour += vec3(0.6, 0.62, 0.72) * 0.14 * (disc + bulge) * clouds * clouds * 1.6 * lane * (1.0 - u_day);

                // Sunrise and sunset: a warm band low in the sky, strongest toward the Sun's azimuth.
                float sunward = exp((dot(normalize(d.xz), normalize(u_sun.xz + vec2(0.0, 0.0001))) - 1.0) * 2.5);
                float low = exp(-max(d.y, 0.0) * 6.0);
                colour += u_twilight * low * (vec3(0.14, 0.07, 0.15) + vec3(0.95, 0.4, 0.1) * sunward);
                colour += u_day * 0.15 * pow(max(dot(d, u_sun), 0.0), 6.0) * vec3(0.7, 0.8, 1.0); // bright around the Sun

                colour += (hash(vec3(v_tex_coord * u_size, 1.0)) - 0.5) / 255.0; // dither away banding
                gl_FragColor = vec4(colour, 1.0);
            }
            """, uniforms: [
                SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)]),
                SKUniform(name: "u_horizon", float: Float(horizonY)),
                SKUniform(name: "u_scale", float: Float(scale)),
                galacticUniform, dayUniform, twilightUniform, sunUniform,
            ])
        addChild(sky)
    }

    /// Rolling hills and a ragged treeline along the bottom, with faint compass points.
    private func addHorizon() {
        let (width, height) = (size.width, horizonY + 60)
        let ground = SKSpriteNode(texture: paint(CGSize(width: width, height: height)) { ctx in
            ctx.setFillColor(CGColor(red: 0.008, green: 0.01, blue: 0.02, alpha: 1))
            let ridge = { (x: CGFloat) in self.horizonY * (0.72 + 0.16 * sin(x / 260 + 1) + 0.08 * sin(x / 83)) }
            let hills = CGMutablePath()
            hills.move(to: .zero)
            for x in stride(from: 0, through: width + 4, by: 4) { hills.addLine(to: CGPoint(x: x, y: ridge(x))) }
            hills.addLine(to: CGPoint(x: width + 4, y: 0))
            ctx.addPath(hills)
            ctx.fillPath()

            // Stands of conifers along the higher stretches: stacked tiers, varied heights and gaps.
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
        }, size: CGSize(width: width, height: height))
        ground.anchorPoint = .zero
        ground.zPosition = 6
        addChild(ground)

        let points = facingSouth ? ["SE", "S", "SW"] : ["NW", "N", "NE"]
        for (i, name) in points.enumerated() {
            let offset = CGFloat(i - 1) * 2 * tan(22.5 * .pi / 180) * CGFloat(scale)
            let letter = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
            letter.text = name
            letter.fontSize = 12
            letter.fontColor = NSColor(white: 1, alpha: i == 1 ? 0.3 : 0.18)
            letter.position = CGPoint(x: size.width / 2 + offset, y: horizonY * 0.3)
            letter.zPosition = 7
            addChild(letter)
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
        let travel = CGFloat.random(in: 180...360)
        streak.run(.sequence([
            .group([.moveBy(x: cos(angle) * travel, y: sin(angle) * travel, duration: 0.7),
                    .sequence([.fadeIn(withDuration: 0.1), .fadeOut(withDuration: 0.6)])]),
            .removeFromParent(),
        ]))
    }
}
