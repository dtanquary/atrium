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
        Knob(key: "sky.planetLabels", label: "Labels", range: 0...1, standard: 1, section: "Show", format: .toggle),
        Knob(key: "sky.comets", label: "Comets (made up)", range: 0...1, standard: 0, section: "Show", format: .toggle),
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
    private let comet = SKSpriteNode(color: .white, size: .zero)
    private let cometLook = SKUniform(name: "u_look", vectorFloat2: [0, 1]) // how bright, and which way its dust tail curls
    /// What's worth pointing out in the sky's photograph, by right ascension and declination (J2000, degrees).
    private static let sights: [(name: String, ra: Double, dec: Double)] = [
        ("Orion Nebula", 83.82, -5.39), ("Rosette Nebula", 97.98, 4.95), ("Pleiades", 56.75, 24.12),
        ("Beehive Cluster", 130.1, 19.67), ("Andromeda Galaxy", 10.68, 41.27), ("Double Cluster", 34.75, 57.13),
        ("North America Nebula", 314.75, 44.33), ("Lagoon Nebula", 270.9, -24.38),
        ("Center of the Milky Way", 266.42, -29.01), ("Omega Centauri", 201.7, -47.48), ("Carina Nebula", 161.27, -59.68),
        ("Coalsack", 192.5, -62.5), ("Large Magellanic Cloud", 80.89, -69.76), ("Small Magellanic Cloud", 13.19, -72.83),
    ]
    /// Their names, each on an empty node at its place.
    private let sightNames = SKNode()
    /// Each meteor shower's radiant, ringed and named while the shower is active and its radiant is up.
    private let radiants = SKNode()
    /// Each shower's radiant in horizon coordinates, and how many of its meteors an hour reach this sky now.
    private var falling: [(radiant: Sky.Vector, hourly: Double)] = []
    private let photoFrame = SKUniform(name: "u_toPhoto", matrixFloat3x3: matrix_identity_float3x3)
    private let starFrame = SKUniform(name: "u_toStars", matrixFloat3x3: matrix_identity_float3x3)
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
        addComet()
        sightNames.zPosition = 3
        addChild(sightNames)
        for sight in Self.sights {
            let spot = SKNode()
            spot.addChild(label(sight.name, alpha: 0.3))
            sightNames.addChild(spot)
        }
        radiants.zPosition = 3
        addChild(radiants)
        for shower in Self.showers {
            let ring = SKShapeNode(circleOfRadius: 3)
            ring.strokeColor = NSColor(white: 1, alpha: 0.3)
            ring.addChild(label(shower.name, alpha: 0.4))
            radiants.addChild(ring)
        }
        addHorizon()

        run(.repeatForever(.sequence([.wait(forDuration: 5), .run { [weak self] in self?.refresh() }])))
        applySettings()
        NotificationCenter.default.addObserver(self, selector: #selector(applySettings),
                                               name: UserDefaults.didChangeNotification, object: nil)
        awaitMeteor()
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

    /// Shows or hides the constellation lines, labels and landscape as Settings says, and redraws for a preview time.
    @objc private func applySettings() {
        constellations.isHidden = Self.knobs[0].value < 0.5
        for planet in planets { planet.node.children.forEach { $0.isHidden = Self.knobs[1].value < 0.5 } } // their labels
        radiants.isHidden = Self.knobs[1].value < 0.5
        sightNames.isHidden = radiants.isHidden
        ground.isHidden = Self.knobs[3].value < 0.5
        let pick = Landscape.allCases[min(Int(Self.knobs[4].value), Landscape.allCases.count - 1)]
        if !ground.isHidden, pick != landscape { paintGround(pick) }
        horizonY = ground.isHidden ? 0 : landHorizon
        horizonUniform.floatValue = Float(horizonY)
        for letter in compass { letter.position.y = ground.isHidden ? 8 : landHorizon * 0.3 }
        refresh()
    }

    /// Now, or today at the preview hour while previewing a time of day.
    private var skyDate: Date {
        guard Self.knobs[5].value > 0.5 else { return Date() }
        return Calendar.current.startOfDay(for: Date()).addingTimeInterval(Self.knobs[6].value * 3600)
    }

    // MARK: Projection

    /// Stereographic projection centred on the horizon point we face, so the horizon is a straight line.
    private func project(_ h: Sky.Vector) -> CGPoint? {
        let forward = facingSouth ? -h.y : h.y, right = facingSouth ? -h.x : h.x
        guard 1 + forward > 0.2 else { return nil }
        let k = 2 / (1 + forward) * scale
        return CGPoint(x: Double(size.width) / 2 + k * right, y: Double(horizonY) + k * h.z)
    }

    /// The horizon direction under a point on screen: `project` backwards.
    private func unproject(_ point: CGPoint) -> Sky.Vector {
        let (x, y) = ((Double(point.x) - Double(size.width) / 2) / scale, (Double(point.y) - Double(horizonY)) / scale)
        let r2 = x * x + y * y
        let (right, up, forward) = (4 * x / (4 + r2), 4 * y / (4 + r2), (4 - r2) / (4 + r2))
        return facingSouth ? [-right, -forward, up] : [right, forward, up]
    }

    /// Shows a node at a horizon direction if it's above the horizon and on screen, its name on whichever side of it
    /// has the room.
    private func place(_ node: SKNode, at h: Sky.Vector) {
        guard h.z > -0.01, let point = project(h), frame.insetBy(dx: -30, dy: -30).contains(point) else {
            node.isHidden = true
            return
        }
        node.isHidden = false
        node.position = point
        guard let name = node.children.first as? SKLabelNode else { return }
        let left = point.x + 12 + name.frame.width > size.width
        guard left != (name.horizontalAlignmentMode == .right) else { return } // the ISS comes through here every frame
        name.horizontalAlignmentMode = left ? .right : .left
        name.position.x = left ? -8 : 8
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
        for (sight, spot) in zip(Self.sights, sightNames.children) { place(spot, at: toHorizon * Sky.direction(sight.ra, sight.dec)) }

        // The made-up comet, while one is passing and Settings has them on: its tails stream away from the Sun, and
        // it shrinks as it fades. The sprite holds the head a tenth of the way along.
        if Self.knobs[2].value > 0.5, let visitor = Self.comet(jd, north: here.latitude >= 0) {
            let at = toHorizon * visitor.direction, long = visitor.tail * visitor.bright * .pi / 180 * scale * 1.15 / 0.9
            place(comet, at: at)
            comet.size = CGSize(width: long, height: long / 2)
            comet.zRotation = screenAngle(from: at, toward: sunH) + .pi
            cometLook.vectorFloat2Value = [Float(visitor.bright), Float(visitor.curl)]
        } else {
            comet.isHidden = true
        }

        // Meteor showers: each one's radiant, named while it gives two an hour or more, and how many of its meteors
        // reach this sky, fewer the lower its radiant stands.
        let sunLongitude = Sky.sunLongitude(jd)
        falling = zip(Self.showers, radiants.children).map { shower, ring in
            let radiant = toHorizon * Sky.direction(shower.ra, shower.dec)
            let hourly = Self.hourly(shower, sunLongitude: sunLongitude)
            place(ring, at: radiant)
            if hourly < 2 { ring.isHidden = true }
            return (radiant, hourly * max(0, radiant.z))
        }

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

        // The background maps screen → sky → the photo, and the fainter stars' grid: plane (right, up, forward) →
        // horizon → equatorial → each one's frame.
        let basis = facingSouth
            ? simd_double3x3(columns: ([-1, 0, 0], [0, 0, 1], [0, -1, 0]))
            : simd_double3x3(columns: ([1, 0, 0], [0, 0, 1], [0, 1, 0]))
        for (uniform, frame) in [(photoFrame, Self.toPhoto), (starFrame, Self.toStars)] {
            let turn = frame * toHorizon.transpose * basis
            uniform.matrixFloat3x3Value = simd_float3x3(columns: (SIMD3<Float>(turn.columns.0), SIMD3<Float>(turn.columns.1),
                                                                  SIMD3<Float>(turn.columns.2)))
        }
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

    /// A comet that isn't there, for whoever turns Comets on in Settings: one visits for ten days in every 37,
    /// counted from 11 November 2026, in the evening sky and the morning sky by turns. It closes from 75° to 45° from
    /// the Sun, brightening, and draws away again, on the side of the Sun's path that stands higher for a viewer in
    /// the north or the south, so it's well up in this view at dusk or dawn (a real one keeps nearer the Sun, which
    /// from here sets beyond the screen's edge). Nil between visits. Real comets were looked at first: one bright
    /// enough for this sky comes for a few weeks in a year or two (docs/night-sky.md).
    nonisolated static func comet(_ jd: Double, north: Bool = true) -> (direction: Sky.Vector, bright: Double, tail: Double, curl: Double)? {
        let days = jd - 2461355.5, visit = (days / 37).rounded(.down), passed = (days - visit * 37) / 10
        guard passed < 1 else { return nil }
        func chance(_ n: Double) -> Double { // 0 to 1, this visit's own
            let x = sin(visit * 12.9898 + n * 78.233) * 43758.5453
            return x - x.rounded(.down)
        }
        let evening = visit.truncatingRemainder(dividingBy: 2) == 0, apart = 45 + 30 * (1 - sin(.pi * passed))
        let longitude = Sky.sunLongitude(jd) + (evening ? apart : -apart) // east of the Sun sets after it
        let latitude = (north ? 1 : -1) * (4 + 14 * chance(1)) + (chance(2) - 0.5) * 12 * (2 * passed - 1)
        return (Sky.equatorial(fromEcliptic: Sky.direction(longitude, latitude)), pow(sin(.pi * passed), 0.6),
                14 + 12 * chance(3), chance(4) < 0.5 ? -1 : 1)
    }

    /// The comet's picture: a greenish head, a thin straight blue tail of gas and a broad pale one of dust that curls
    /// to one side, all added to the sky behind. Along the sprite, 0 is the head and 1 the tails' end.
    private func addComet() {
        comet.anchorPoint = CGPoint(x: 0.1, y: 0.5)
        comet.zPosition = 3
        comet.isHidden = true
        comet.shader = SKShader(source: """
            void main() {
                vec2 p = vec2(v_tex_coord.x - 0.1, (v_tex_coord.y - 0.5) * 0.5) / 0.9;
                float along = max(p.x, 0.0);
                float end = smoothstep(0.0, 0.03, p.x) * (1.0 - smoothstep(0.7, 1.0, p.x));
                float head = exp(-dot(p, p) / 0.0002) + 0.6 * exp(-dot(p, p) / 0.002);
                float gasWide = 0.006 + 0.02 * along;
                float gas = exp(-p.y * p.y / (gasWide * gasWide)) * exp(-1.6 * along) * end;
                float curled = p.y - u_look.y * 0.16 * along * along;
                float dustWide = 0.012 + 0.1 * along;
                float dust = exp(-curled * curled / (dustWide * dustWide)) * exp(-2.2 * along) * end;
                vec3 colour = vec3(0.75, 1.0, 0.9) * head + vec3(0.5, 0.68, 1.0) * 0.6 * gas + vec3(1.0, 0.94, 0.84) * 0.8 * dust;
                gl_FragColor = vec4(colour * u_look.x, 0.0);
            }
            """, uniforms: [cometLook])
        addChild(comet)
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

        // NASA's map of the near side (Weather's), north up, on a sphere lit from u_light in the disc's frame.
        moon.shader = SKShader(source: moonShade + """
            void main() {
                vec2 p = v_tex_coord * 2.0 - 1.0;
                float r2 = dot(p, p);
                vec3 n = vec3(p, sqrt(max(0.0, 1.0 - r2)));
                // Light to display (a square root, as Weather's film curve does), and earthshine on the dark side:
                // faint and blue, with the seas still showing in it.
                float lit = sqrt(moonShade(n, u_light));
                vec3 surface = texture2D(u_map, v_tex_coord).rgb;
                vec3 colour = surface * (1.9 * lit + vec3(0.2, 0.23, 0.32) * (1.0 - min(lit, 1.0)));
                float a = smoothstep(1.0, 0.93, r2);
                gl_FragColor = vec4(colour * a, a);
            }
            """, uniforms: [moonLight, SKUniform(name: "u_map", texture: sharedTexture("weather-moon.png"))])
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

    /// J2000 equatorial → the frame the fainter stars' file is in (Black Hole's `blackhole-stars.lzfse`, which
    /// docs/black-hole/sky.py bakes already turned to that scene's view): there a star's longitude is atan2(x, z)
    /// and its latitude asin(y).
    nonisolated static let toStars = simd_double3x3(rows: [
        [0.739411, -0.372160, 0.561042], [-0.372160, 0.468501, 0.801252], [0.561042, 0.801252, -0.207912],
    ]) * Sky.galactic

    /// The stars too faint for sprites: the HYG catalogue's 113,000 from magnitude 5.3 to 11, as a grid the shader
    /// can find a star in, so each is drawn as a sharp point however large the screen. A row every 0.18° of latitude,
    /// in bands of 32; a band's rows hold as many cells as make them 0.18° wide at its edge nearer the equator
    /// (2,048 round the middle, 200 in the last band), so a star has about the same room to shine all over the sky. A
    /// cell holds at most one star, the brightest that falls in it: where it sits in the cell (across, up), how
    /// bright (1 for magnitude 11 up to 255 for 5.3; 0 for no star) and its B−V colour (0 for −0.4 up to 255 for 2).
    // ponytail: stars that share a cell with a brighter one are dropped, a few in a hundred, in the Milky Way's crowds
    nonisolated static func starGrid() -> [UInt8] {
        let (w, h) = (2048, 1024)
        var cells = [UInt8](repeating: 0, count: w * h * 4)
        let packed = try? Data(contentsOf: resource("blackhole-stars.lzfse")) as NSData
        let bytes = ((try? packed?.decompressed(using: .lzfse)) as Data?).map { [UInt8]($0) } ?? [], count = bytes.count / 6
        for i in 0..<count {
            let magnitude = Double(bytes[4 * count + i]) / 255 * 12.5 - 1.5
            guard magnitude > 5.3 else { continue } // the brighter ones are sprites
            func place(_ run: Int) -> Double { Double(Int(bytes[run * 2 * count + 2 * i]) | Int(bytes[run * 2 * count + 2 * i + 1]) << 8) / 65535 }
            let y = min(place(1) * Double(h), Double(h) - 0.001)
            let across = Self.cells(row: y.rounded(.down)), x = min(place(0) * across, across - 0.001)
            let at = (Int(y) * w + Int(x)) * 4, bright = UInt8(max(1, (11 - magnitude) / 5.7 * 255))
            guard bright > cells[at + 2] else { continue }
            cells[at..<at + 4] = [UInt8((x - x.rounded(.down)) * 256), UInt8((y - y.rounded(.down)) * 256), bright, bytes[5 * count + i]]
        }
        return cells
    }

    /// How many cells a row of the star grid holds. The shader works out the same number: the band is a whole number
    /// and none of the sixteen cosines comes within a tenth of the next whole number, so the two can't disagree.
    nonisolated static func cells(row: Double) -> Double {
        (2048 * cos((abs(row - 511.5) / 32).rounded(.down) * 32 * .pi / 1024)).rounded(.down)
    }

    /// Dark sky, a little lighter toward the horizon, behind the real one turned to where it is now: a photograph
    /// for what's spread out (the Milky Way and its dust, the Magellanic Clouds, Andromeda, the nebulae) and the
    /// catalogue's grid for the stars too faint for sprites. Around sunrise and sunset a warm band glows low toward
    /// the Sun.
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
                float air = mix(0.45, 1.0, smoothstep(0.0, 0.3, d.y));
                colour += (1.0 - exp(-1.5 * photo)) * air;

                // The fainter stars, from the catalogue's grid: any star near enough to light this pixel is in one
                // of the two cells nearest it in each of the two rows nearest it. This projection keeps shapes, so
                // a round star stays round, and `points` is how many screen points a radian of sky covers here.
                vec3 s = u_toStars * d;
                float lat = asin(clamp(s.y, -1.0, 1.0));
                float round = atan(s.x, s.z) / 6.2831853 + 0.5;
                float row = (lat / 3.1415927 + 0.5) * 1024.0;
                float points = u_scale * (4.0 + r2) / 4.0;
                for (int k = 0; k < 4; k++) {
                    float r = clamp(floor(row - 0.5) + floor(float(k) / 2.0), 0.0, 1023.0);
                    float across = floor(2048.0 * cos(floor(abs(r - 511.5) / 32.0) * 0.09817477));
                    float c = mod(floor(round * across - 0.5) + mod(float(k), 2.0), across);
                    vec4 star = texture2D(u_stars, (vec2(c, r) + 0.5) / vec2(2048.0, 1024.0));
                    if (star.b > 0.0) {
                        float east = (c + (star.r * 255.0 + 0.5) / 256.0) / across - round;
                        vec2 off = vec2((east - floor(east + 0.5)) * 6.2831853 * cos(lat),
                                        ((r + (star.g * 255.0 + 0.5) / 256.0) / 1024.0 - 0.5) * 3.1415927 - lat) * points;
                        float bv = star.a * 2.4 - 0.4;
                        vec3 hue = mix(mix(vec3(0.72, 0.8, 1.0), vec3(1.0, 0.97, 0.92), smoothstep(-0.2, 0.5, bv)),
                                       vec3(1.0, 0.8, 0.6), smoothstep(0.6, 1.6, bv));
                        float size = 0.3 + 0.22 * star.b;
                        colour += hue * air * (0.07 + 0.5 * star.b * star.b) * exp(-dot(off, off) / (2.0 * size * size));
                    }
                }

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
                SKUniform(name: "u_stars", texture: sharedTexture("sky-stars") {
                    let grid = SKTexture(data: Data(Self.starGrid()), size: CGSize(width: 2048, height: 1024))
                    grid.filteringMode = .nearest
                    return grid
                }),
                photoFrame, starFrame, twilightUniform, sunUniform,
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

    typealias Shower = (name: String, peak: Double, before: Double, after: Double, ra: Double, dec: Double, rate: Double)

    /// The year's main meteor showers, from the International Meteor Organization's Working List of Visual Meteor
    /// Showers (its 2026 calendar, table 5): the Sun's ecliptic longitude at the peak (J2000, degrees), the days it's
    /// active before and after, the radiant's right ascension and declination, and the meteors an hour at the peak
    /// with the radiant overhead.
    nonisolated static let showers: [Shower] = [
        ("Quadrantids", 283.15, 6, 9, 230, 49, 80), ("Lyrids", 32.32, 8, 8, 271, 34, 18),
        ("Eta Aquariids", 45.5, 17, 22, 338, -1, 50), ("Delta Aquariids", 128, 19, 23, 340, -16, 25),
        ("Perseids", 140, 27, 11, 48, 58, 100), ("Orionids", 208, 19, 17, 95, 16, 20),
        ("Southern Taurids", 223, 46, 15, 52, 15, 7), ("Northern Taurids", 230, 23, 28, 58, 22, 5),
        ("Leonids", 235.27, 11, 13, 152, 22, 15), ("Geminids", 262.2, 10, 6, 112, 33, 150),
        ("Ursids", 270.7, 5, 4, 217, 76, 10),
    ]

    /// How many meteors an hour a shower gives with its radiant overhead and the Sun at `sunLongitude`: its peak rate
    /// at its peak, falling to one an hour at each end of its activity, and none beyond.
    // ponytail: a straight line in the logarithm from the peak to each end, and a radiant that stays put. Real showers
    // keep a low base under a sharper peak and their radiants drift a degree a day: give each its own curve if the
    // nights either side of a peak need to be right.
    nonisolated static func hourly(_ shower: Shower, sunLongitude: Double) -> Double {
        let days = ((sunLongitude - shower.peak + 540).truncatingRemainder(dividingBy: 360) - 180) / 0.9856
        let span = days < 0 ? shower.before : shower.after
        return abs(days) > span ? 0 : pow(shower.rate, 1 - abs(days) / span)
    }

    /// Lights a meteor after a wait, again and again. Away from any shower a dark sky really gives about 8 an hour;
    /// here that's 80, one every 45 s or so. A shower adds to it, by less than in life: at the Geminids' peak, 150 an
    /// hour on top of the 8 comes to one every 5 s, not every 2.
    private func awaitMeteor() {
        let wait = 45 / pow(falling.reduce(8) { $0 + $1.hourly } / 8, 0.7)
        run(.sequence([.wait(forDuration: wait, withRange: wait * 4 / 3), .run { [weak self] in
            self?.meteor()
            self?.awaitMeteor()
        }]))
    }

    private let streak = paint(CGSize(width: 140, height: 2)) { ctx in
        let colours = [CGColor(gray: 1, alpha: 0), CGColor(gray: 1, alpha: 0.9)] as CFArray
        ctx.drawLinearGradient(CGGradient(colorsSpace: nil, colors: colours, locations: [0, 1])!,
                               start: .zero, end: CGPoint(x: 140, y: 0), options: [])
    }

    /// A short bright streak across the upper sky: out of a shower's radiant as often as that shower's share of the
    /// meteors falling now, straight away from it and further the further round the sky it is (one near its radiant
    /// is coming almost at you), and otherwise any way down.
    private func meteor() {
        let node = SKSpriteNode(texture: streak, size: CGSize(width: 140, height: 2))
        node.position = CGPoint(x: .random(in: size.width * 0.1...size.width * 0.9),
                                y: .random(in: size.height * 0.5...size.height * 0.95))
        var (angle, travel) = (CGFloat.random(in: -2.6 ... -0.5), CGFloat.random(in: 180...360))
        var lot = Double.random(in: 0..<falling.reduce(8) { $0 + $1.hourly }) // 8 an hour belong to no shower
        if let shower = falling.first(where: { lot -= $0.hourly; return lot < 0 }) {
            let here = unproject(node.position), away = here * dot(here, shower.radiant) - shower.radiant
            let turn = Double.random(in: 0.2...0.4) * length(away) // 11° to 23° of sky, a quarter of the way round
            if length(away) > 0.1, let end = project(normalize(here + normalize(away) * tan(turn))) {
                (angle, travel) = (atan2(end.y - node.position.y, end.x - node.position.x),
                                   hypot(end.x - node.position.x, end.y - node.position.y))
            }
        }
        node.zRotation = angle
        node.alpha = 0
        node.zPosition = 5
        addChild(node)
        batteryRate = nil
        node.run(.sequence([
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
