import SpriteKit
import simd

@MainActor func nightSky(size: CGSize) -> SKScene { NightSky(size: size) }

/// The real sky above you right now, facing the equator, with the atmosphere switched off so it's always
/// night: stars, Milky Way, constellations, planets, the Moon in its true phase, the ISS, and the odd meteor.
final class NightSky: SKScene {
    private var stars: [(node: SKSpriteNode, position: Sky.Vector)] = []
    private var constellationLines: [[Sky.Vector]] = []
    private let constellations = SKShapeNode()
    private var planets: [(planet: Sky.Planet, node: SKSpriteNode)] = []
    private let moon = SKSpriteNode(color: .white, size: CGSize(width: 46, height: 46))
    private let moonGlow = SKSpriteNode()
    private let moonLight = SKUniform(name: "u_light", vectorFloat3: [0, 0, 1])
    private let moonBadge = SKSpriteNode(color: .white, size: CGSize(width: 28, height: 28))
    private let moonBadgeName = SKLabelNode(fontNamed: "HelveticaNeue")
    private let moonBadgeDetail = SKLabelNode(fontNamed: "HelveticaNeue")
    private let iss = SKSpriteNode()
    private let galacticUniform = SKUniform(name: "u_galactic", matrixFloat3x3: matrix_identity_float3x3)

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
        addStars()
        addPlanets()
        addMoon()
        iss.texture = glow
        iss.size = CGSize(width: 12, height: 12)
        iss.zPosition = 4
        iss.addChild(label("ISS", alpha: 0.6))
        addChild(iss)
        addHorizon()

        refresh()
        run(.repeatForever(.sequence([.wait(forDuration: 5), .run { [weak self] in self?.refresh() }])))
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
        let jd = Sky.julianDate(Date())
        toHorizon = Sky.horizonMatrix(jd: jd, latitude: here.latitude, longitude: here.longitude)

        for star in stars { place(star.node, at: toHorizon * star.position) }
        for (planet, node) in planets { place(node, at: toHorizon * Sky.planet(planet, jd)) }

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
        // measured from the Moon's north, so the same shader serves the sky disc and the upright badge.
        let (moonH, poleH) = (toHorizon * Sky.moon(jd), toHorizon * Sky.Vector(0, 0, 1))
        let north = skyAngle(from: moonH, toward: poleH)
        let toSun = skyAngle(from: moonH, toward: toHorizon * Sky.sun(jd)) - north + .pi / 2
        let (lit, waxing) = Sky.moonPhase(jd)
        let phase = acos(2 * lit - 1) // Sun–Moon–Earth angle
        moonLight.vectorFloat3Value = [Float(sin(phase) * cos(toSun)), Float(sin(phase) * sin(toSun)), Float(cos(phase))]
        place(moon, at: moonH)
        moonGlow.position = moon.position
        moonGlow.isHidden = moon.isHidden
        moonGlow.alpha = 0.5 * lit
        if !moon.isHidden { moon.zRotation = screenAngle(from: moonH, toward: poleH) - .pi / 2 }

        // The badge shows the Moon as you'd see it facing it, head upright, even when it's out of view.
        moonBadge.zRotation = north - .pi / 2
        moonBadgeName.text = Sky.moonPhaseName(lit: lit, waxing: waxing)
        moonBadgeDetail.text = "\(Int((lit * 100).rounded()))% lit" + (moonH.z < 0 ? " · below the horizon" : "")

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
            addChild(star)
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

        // Bottom-left badge: the same disc, plus the phase in words.
        moonBadge.shader = moon.shader
        moonBadge.position = CGPoint(x: 36, y: horizonY * 0.42)
        moonBadge.zPosition = 7
        addChild(moonBadge)
        for (text, y, alpha) in [(moonBadgeName, 7.0, 0.55), (moonBadgeDetail, -8.0, 0.35)] {
            text.fontSize = 11
            text.fontColor = NSColor(white: 1, alpha: alpha)
            text.horizontalAlignmentMode = .left
            text.verticalAlignmentMode = .center
            text.position = CGPoint(x: 58, y: moonBadge.position.y + y)
            text.zPosition = 7
            addChild(text)
        }
    }

    /// Dark sky, brighter toward the horizon, with the Milky Way painted where it really is.
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
                vec3 colour = mix(vec3(0.05, 0.065, 0.12), vec3(0.006, 0.01, 0.028), smoothstep(-0.05, 0.7, d.y));

                vec3 g = u_galactic * d;
                float b = asin(clamp(g.z, -1.0, 1.0));
                float l = atan(g.y, g.x);
                float disc = exp(-b * b / 0.03) * (0.45 + 0.55 * cos(l) * cos(l * 0.5));
                float bulge = exp(-l * l / 0.2 - b * b / 0.05);
                float clouds = 0.5 * noise(g * 7.0) + 0.3 * noise(g * 17.0) + 0.2 * noise(g * 43.0);
                float lane = 1.0 - 0.75 * exp(-(b - 0.015) * (b - 0.015) / 0.0012) * smoothstep(1.6, 0.3, abs(l));
                colour += vec3(0.6, 0.62, 0.72) * 0.14 * (disc + bulge) * clouds * clouds * 1.6 * lane;

                colour += (hash(vec3(v_tex_coord * u_size, 1.0)) - 0.5) / 255.0; // dither away banding
                gl_FragColor = vec4(colour, 1.0);
            }
            """, uniforms: [
                SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)]),
                SKUniform(name: "u_horizon", float: Float(horizonY)),
                SKUniform(name: "u_scale", float: Float(scale)),
                galacticUniform,
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
