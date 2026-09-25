import SpriteKit
import simd

@MainActor func earthFromOrbit(size: CGSize) -> SKScene { EarthFromOrbit(size: size) }

/// The whole Earth seen from high above you, like a geostationary satellite: the real day/night line sweeping
/// across it, today's clouds, lightning in the storms around you, city lights on the night side, sun glint on the
/// oceans, and the ISS with its orbit.
final class EarthFromOrbit: SKScene {
    nonisolated static let knobs = [
        Knob(key: "earth.iss", label: "ISS tracking", range: 0...1, standard: 1, section: "Show", format: .toggle),
        Knob(key: "earth.clouds", label: "Live clouds", range: 0...1, standard: 1, section: "Show", format: .toggle),
        Knob(key: "earth.lightning", label: "Lightning in storms near you", range: 0...1, standard: 1, section: "Show", format: .toggle),
        Knob(key: "earth.previewStorm", label: "Preview a storm overhead", range: 0...1, standard: 0, section: "Show",
             format: .toggle, shownWhen: "earth.lightning"),
    ]

    private let globe = SKSpriteNode()
    private let sunUniform = SKUniform(name: "u_sun", vectorFloat3: [1, 0, 0])
    private let basisUniform = SKUniform(name: "u_basis", matrixFloat3x3: matrix_identity_float3x3)
    // The cloud map, and the one before it while fading to a new one; a blank texture is no clouds.
    private static let noClouds = paint(CGSize(width: 1, height: 1)) { _ in }
    private let cloudsUniform = SKUniform(name: "u_clouds", texture: noClouds)
    private let cloudsBeforeUniform = SKUniform(name: "u_cloudsBefore", texture: noClouds)
    private let cloudFadeUniform = SKUniform(name: "u_cloudFade", float: 1)
    private var cloudsOn = false
    private var cloudVersion = 0
    private var cloudFadeStart: TimeInterval?
    private static let flash = paint(CGSize(width: 32, height: 32)) { ctx in // bright core, soft glow through the cloud
        let colours = [CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 0.35), CGColor(gray: 1, alpha: 0)] as CFArray
        ctx.drawRadialGradient(CGGradient(colorsSpace: nil, colors: colours, locations: [0, 0.12, 1])!,
                               startCenter: CGPoint(x: 16, y: 16), startRadius: 0,
                               endCenter: CGPoint(x: 16, y: 16), endRadius: 16, options: [])
    }
    private var nextFlash: TimeInterval = 0
    private var sunDirection = Sky.Vector(1, 0, 0)
    private let iss = SKSpriteNode()
    private let issLabel = SKLabelNode(fontNamed: "HelveticaNeue")
    private let orbit = SKShapeNode()
    /// Earth-fixed axes of the view: east, north, and toward us.
    private var basis = matrix_identity_double3x3
    private var orbitDrawn: TimeInterval = 0

    private var radius: CGFloat { size.height * 0.43 }
    private var centre: CGPoint { CGPoint(x: size.width * 0.58, y: size.height * 0.48) }
    private let margin: CGFloat = 1.12 // globe sprite extends past the disc for the atmosphere

    override func sceneDidLoad() {
        backgroundColor = .black
        addStars()
        addGlobe()
        if Self.knobs[1].value > 0.5 { // clouds from the cache straight away, no fade
            cloudsOn = true
            Clouds.shared.loadCache()
            cloudsUniform.textureValue = Clouds.shared.texture ?? Self.noClouds
            cloudVersion = Clouds.shared.version
        }

        orbit.strokeColor = NSColor(red: 0.6, green: 0.8, blue: 1, alpha: 0.25)
        orbit.lineWidth = 1
        orbit.zPosition = 2
        addChild(orbit)
        iss.texture = paint(CGSize(width: 16, height: 16)) { ctx in
            let colours = [CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 0.3), CGColor(gray: 1, alpha: 0)] as CFArray
            ctx.drawRadialGradient(CGGradient(colorsSpace: nil, colors: colours, locations: [0, 0.3, 1])!,
                                   startCenter: CGPoint(x: 8, y: 8), startRadius: 0,
                                   endCenter: CGPoint(x: 8, y: 8), endRadius: 8, options: [])
        }
        iss.size = CGSize(width: 14, height: 14)
        iss.zPosition = 3
        iss.isHidden = true
        // The label is a sibling, not a child, so the marker's pulse doesn't scale or fade it.
        issLabel.text = "ISS"
        issLabel.fontSize = 11
        issLabel.fontColor = NSColor(white: 1, alpha: 0.5)
        issLabel.horizontalAlignmentMode = .left
        issLabel.verticalAlignmentMode = .center
        issLabel.zPosition = 3
        addChild(issLabel)
        let ping = SKAction.group([.scale(to: 2.2, duration: 1.6), .fadeAlpha(to: 0.2, duration: 1.6)])
        iss.run(.repeatForever(.sequence([ping, .group([.scale(to: 1, duration: 0), .fadeAlpha(to: 1, duration: 0)])])))
        addChild(iss)

        refresh()
        run(.repeatForever(.sequence([.wait(forDuration: 30), .run { [weak self] in self?.refresh() }])))
    }

    override func didMove(to view: SKView) {
        Location.shared.start()
        run(.repeatForever(.sequence([.run { if Self.knobs[0].value > 0.5 { ISS.shared.poll() } }, .wait(forDuration: 60)])))
        run(.repeatForever(.sequence([.run { if Self.knobs[1].value > 0.5 { Clouds.shared.poll() } }, .wait(forDuration: 900)])))
        run(.repeatForever(.sequence([.run { if Self.knobs[2].value > 0.5 { Storms.shared.poll(around: Location.shared.coordinate) } },
                                      .wait(forDuration: 900)])))
    }

    override func update(_ currentTime: TimeInterval) {
        updateClouds(currentTime)
        updateLightning(currentTime)
        guard Self.knobs[0].value > 0.5, // ISS tracking on
              let now = ISS.shared.position(), let later = ISS.shared.position(at: Date(timeIntervalSinceNow: 20)) else {
            iss.isHidden = true
            issLabel.isHidden = true
            orbit.path = nil
            return
        }
        let here = station(now), ahead = station(later)
        iss.isHidden = !visible(here)
        iss.position = screen(here)
        issLabel.isHidden = iss.isHidden
        issLabel.position = CGPoint(x: iss.position.x + 10, y: iss.position.y)
        guard currentTime - orbitDrawn > 5 || orbit.path == nil else { return } // the ring barely moves
        orbitDrawn = currentTime

        // ponytail: orbit ring from two fixes in Earth-fixed axes, so it ignores Earth's spin (~3° tilt error)
        let normal = normalize(cross(here, ahead)), start = normalize(here)
        let path = CGMutablePath()
        var drawing = false
        for step in 0...180 {
            let angle = Double(step) / 180 * 2 * .pi
            let point = (start * cos(angle) + cross(normal, start) * sin(angle)) * length(here)
            if visible(point) {
                drawing ? path.addLine(to: screen(point)) : path.move(to: screen(point))
                drawing = true
            } else {
                drawing = false
            }
        }
        orbit.path = path
    }

    /// Follows the Live clouds switch, and fades between maps over a minute: to a new one when it lands, in from the
    /// cache when clouds are switched on, and out when they're switched off, letting the map go.
    private func updateClouds(_ currentTime: TimeInterval) {
        let on = Self.knobs[1].value > 0.5
        if on != cloudsOn {
            cloudsOn = on
            if on {
                Clouds.shared.loadCache()
                Clouds.shared.poll()
            } else {
                fadeClouds(to: Self.noClouds, currentTime)
                Clouds.shared.release()
            }
        }
        if on, cloudVersion != Clouds.shared.version, let map = Clouds.shared.texture {
            cloudVersion = Clouds.shared.version
            fadeClouds(to: map, currentTime)
        }
        guard let start = cloudFadeStart else { return }
        cloudFadeUniform.floatValue = Float(min((currentTime - start) / 60, 1))
        if currentTime - start > 60 {
            cloudFadeStart = nil
            cloudsBeforeUniform.textureValue = cloudsUniform.textureValue // lets the old map go
        }
    }

    private func fadeClouds(to map: SKTexture, _ currentTime: TimeInterval) {
        cloudsBeforeUniform.textureValue = cloudsUniform.textureValue
        cloudsUniform.textureValue = map
        cloudFadeStart = currentTime
    }

    /// Flashes in the storms around you, about one every 5 s per storm cell (at most one a second): a stroke or three
    /// lighting the cloud tops from inside, bright on the night side and faint by day.
    private func updateLightning(_ currentTime: TimeInterval) {
        guard Self.knobs[2].value > 0.5, currentTime > nextFlash else { return }
        let here = Location.shared.coordinate
        let cells = Storms.shared.cells + (Self.knobs[3].value > 0.5 ? Storms.preview(around: here) : [])
        guard let cell = cells.randomElement() else {
            nextFlash = currentTime + 5
            return
        }
        nextFlash = currentTime - log(Double.random(in: 0.001...1)) * 5 / Double(min(cells.count, 5))

        // lightning lives in the thickest cloud, so try a few spots around the cell and take the cloudiest
        let spread = 1.2, stretch = 1 / max(cos(cell.latitude * .pi / 180), 0.2)
        let spots = (0..<6).map { _ in
            (latitude: cell.latitude + .random(in: -spread...spread), longitude: cell.longitude + .random(in: -spread...spread) * stretch)
        }
        let spot = spots.max { (Clouds.shared.cover(latitude: $0.latitude, longitude: $0.longitude) ?? 0)
            < (Clouds.shared.cover(latitude: $1.latitude, longitude: $1.longitude) ?? 0) }!
        let point = Sky.direction(spot.longitude, spot.latitude)
        guard (basis.transpose * point).z > 0.05 else { return }
        let dark = min(max((0.1 - simd_dot(point, sunDirection)) / 0.2, 0), 1)
        let strength = CGFloat(0.3 + 0.7 * dark)

        let bolt = SKSpriteNode(texture: Self.flash)
        let size = CGFloat.random(in: 14...34)
        bolt.size = CGSize(width: size, height: size)
        bolt.color = NSColor(red: 0.8, green: 0.87, blue: 1, alpha: 1)
        bolt.colorBlendFactor = 1
        bolt.blendMode = .add
        bolt.alpha = 0
        bolt.zPosition = 1.5
        bolt.position = screen(point)
        var strokes: [SKAction] = []
        for _ in 0..<Int.random(in: 1...3) {
            strokes += [.fadeAlpha(to: strength * .random(in: 0.6...1), duration: 0.03),
                        .fadeAlpha(to: strength * 0.15, duration: .random(in: 0.06...0.15))]
        }
        addChild(bolt)
        bolt.run(.sequence(strokes + [.fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    /// Earth-fixed position of the ISS, in Earth radii.
    private func station(_ fix: (latitude: Double, longitude: Double, altitude: Double, sunlit: Bool)) -> Sky.Vector {
        Sky.direction(fix.longitude, fix.latitude) * (1 + fix.altitude / 6371)
    }

    /// In front of the globe, or beside it where the globe doesn't hide it.
    private func visible(_ p: Sky.Vector) -> Bool {
        let v = basis.transpose * p
        return v.z > 0 || v.x * v.x + v.y * v.y > 1
    }

    private func screen(_ p: Sky.Vector) -> CGPoint {
        let v = basis.transpose * p
        return CGPoint(x: centre.x + CGFloat(v.x) * radius, y: centre.y + CGFloat(v.y) * radius)
    }

    /// Points the view at the viewer's location and moves the Sun to where it is now.
    private func refresh() {
        let here = Location.shared.coordinate
        let (lat, lon) = (here.latitude * .pi / 180, here.longitude * .pi / 180)
        basis = simd_double3x3(columns: ([-sin(lon), cos(lon), 0],
                                         [-sin(lat) * cos(lon), -sin(lat) * sin(lon), cos(lat)],
                                         Sky.direction(here.longitude, here.latitude)))
        basisUniform.matrixFloat3x3Value = simd_float3x3(columns: (SIMD3<Float>(basis.columns.0),
                                                                  SIMD3<Float>(basis.columns.1),
                                                                  SIMD3<Float>(basis.columns.2)))
        // The subsolar point: the Sun's declination, and its right ascension less Greenwich sidereal time.
        let jd = Sky.julianDate(Date())
        let sun = Sky.raDec(Sky.sun(jd))
        sunDirection = Sky.direction(sun.ra - Sky.siderealTime(jd), sun.dec)
        sunUniform.vectorFloat3Value = SIMD3<Float>(sunDirection)
    }

    private func addGlobe() {
        func texture(_ name: String) -> SKTexture {
            let texture = SKTexture(image: NSImage(contentsOf: resource(name)) ?? NSImage())
            texture.usesMipmaps = true
            return texture
        }
        globe.texture = texture("earth-day.jpg")
        globe.size = CGSize(width: radius * 2 * margin, height: radius * 2 * margin)
        globe.position = centre
        globe.zPosition = 1
        // Earth textures: NASA Blue Marble, September 2004 (day) and Black Marble 2016 (night lights), both public domain.
        // Clouds come live from Clouds.shared.
        globe.shader = SKShader(source: """
            void main() {
                vec2 p = (v_tex_coord * 2.0 - 1.0) * u_margin;
                float r = length(p);
                vec3 w = u_basis * vec3(p, sqrt(max(0.0, 1.0 - r * r))); // Earth-fixed surface point
                vec2 uv = vec2(atan(w.y, w.x) / 6.2831853 + 0.5, asin(clamp(w.z, -1.0, 1.0)) / 3.1415927 + 0.5);
                vec3 day = texture2D(u_texture, uv).rgb;
                vec3 night = texture2D(u_night, uv).rgb;

                // the map reads thin haze and cold ground as faint grey, so only real cloud decks go opaque
                float cloud = mix(texture2D(u_cloudsBefore, uv).r, texture2D(u_clouds, uv).r, u_cloudFade);
                cloud = smoothstep(0.42, 0.95, cloud);

                float sun = dot(w, u_sun);
                float daylight = smoothstep(-0.12, 0.1, sun) * (0.25 + 0.95 * max(sun, 0.0));
                // a little earthshine keeps the night side's shape, and shows the clouds there faintly
                vec3 colour = mix(day, vec3(0.8, 0.82, 0.86), cloud * 0.95) * (daylight + 0.03);
                vec3 lights = night * night * vec3(1.0, 0.82, 0.55) * 2.2;
                colour += lights * (1.0 - smoothstep(-0.2, 0.02, sun)) * (1.0 - 0.8 * cloud); // cloud dims, not hides

                float ocean = smoothstep(0.02, 0.12, day.b - day.r) * (1.0 - cloud);
                vec3 towardUs = u_basis * vec3(0.0, 0.0, 1.0);
                colour += vec3(1.0, 0.95, 0.85) * ocean * pow(max(dot(w, normalize(u_sun + towardUs)), 0.0), 90.0) * 0.6;

                float edge = 1.0 - sqrt(max(0.0, 1.0 - r * r));
                vec3 air = vec3(0.35, 0.6, 1.0);
                colour = mix(colour, air * daylight, pow(edge, 3.0) * 0.6);

                float disc = smoothstep(1.0, 0.997, r);
                float rimSun = smoothstep(-0.35, 0.3, dot(normalize(u_basis * vec3(p, 0.0)), u_sun));
                float halo = exp(-max(r - 1.0, 0.0) * 40.0) * (1.0 - disc) * rimSun * 0.8;
                gl_FragColor = vec4(colour * disc + air * halo, max(disc, halo));
            }
            """, uniforms: [
                SKUniform(name: "u_night", texture: texture("earth-night.jpg")),
                SKUniform(name: "u_margin", float: Float(margin)),
                sunUniform,
                basisUniform,
                cloudsUniform,
                cloudsBeforeUniform,
                cloudFadeUniform,
            ])
        addChild(globe)
    }

    /// A still starfield: no atmosphere up here, so nothing twinkles.
    private func addStars() {
        let dot = paint(CGSize(width: 8, height: 8)) { ctx in
            let colours = [CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 0)] as CFArray
            ctx.drawRadialGradient(CGGradient(colorsSpace: nil, colors: colours, locations: [0, 1])!,
                                   startCenter: CGPoint(x: 4, y: 4), startRadius: 0,
                                   endCenter: CGPoint(x: 4, y: 4), endRadius: 4, options: [])
        }
        for _ in 0..<Int(size.width * size.height / 2500) {
            let star = SKSpriteNode(texture: dot)
            let brightness = pow(Double.random(in: 0...1), 3)
            let diameter = 1.5 + 3 * brightness
            star.size = CGSize(width: diameter, height: diameter)
            star.alpha = 0.25 + 0.75 * brightness
            star.color = NSColor(red: 0.85 + .random(in: 0...0.15), green: 0.9, blue: 0.85 + .random(in: 0...0.15), alpha: 1)
            star.colorBlendFactor = 1
            star.position = CGPoint(x: .random(in: 0...size.width), y: .random(in: 0...size.height))
            addChild(star)
        }
    }
}
