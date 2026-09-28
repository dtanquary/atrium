import Metal
import SpriteKit
import simd

/// The Moon as it is right now from where you are: its real phase, libration and tilt, lit the way the Moon's dusty
/// ground reflects light, with earthshine on its dark side and copper in the Earth's shadow. It barely changes, so
/// `MoonBaker` renders it into a texture once a minute and the desktop only draws a sprite, turned each frame as the
/// sky turns so the viewer's zenith stays up. It's the Moon's live view in Solar System, which runs it nested in its own
/// scene.
final class TheMoon: SKScene {
    nonisolated static let knobs = [
        Knob(key: "moon.phase", label: "Phase", range: 0...8, standard: 0, section: "Look",
             format: .choice(["Real time where you are", "New", "Waxing crescent", "First quarter", "Waxing gibbous", "Full",
                              "Waning gibbous", "Last quarter", "Waning crescent"])),
        Knob(key: "moon.backdrop", label: "Backdrop", range: 0...2, standard: 1, section: "Look",
             format: .choice(["Black", "Stars", "Sky"])),
        Knob(key: "moon.size", label: "Size", range: 0.4...1, standard: 0.8, section: "Look"),
        Knob(key: "moon.brightness", label: "Brightness", range: 0.5...2, standard: 1, section: "Look", format: .times),
        Knob(key: "moon.earthshine", label: "Earthshine", range: 0...3, standard: 1, section: "Look", format: .times),
        Knob(key: "moon.preview", label: "Preview another day", range: 0...1, standard: 0, section: "Preview",
             format: .toggle),
        Knob(key: "moon.previewDays", label: "Days from now", range: 0...29.5, standard: 7, section: "Preview",
             shownWhen: "moon.preview"),
    ]

    /// The phases to pick instead of real time: moments in the lunation of January 2026, each 45° further from the
    /// Sun, found with SkyMath. New, the quarters and full match the published times to the minute.
    nonisolated static let phases = [2461059.3283, 2461063.1296, 2461066.6999, 2461070.0729, 2461073.4238, 2461077.0323,
                                     2461081.0309, 2461085.1420]

    private let turntable = SKNode() // the Moon and its stars, turned so the zenith is up
    private let moon = SKSpriteNode()
    private let stars = SKNode()
    private let sky = SKSpriteNode()
    private let baker = MoonBaker()
    private var seen: Sky.MoonView?
    private var needsBake = true

    /// Now, or some days on while previewing.
    private var date: Date {
        Date().addingTimeInterval(Self.knobs[5].value > 0.5 ? Self.knobs[6].value * 86400 : 0)
    }

    override func sceneDidLoad() {
        backgroundColor = .black
        turntable.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(turntable)
        turntable.addChild(stars)
        moon.zPosition = 1
        turntable.addChild(moon)
        sky.anchorPoint = .zero
        sky.size = size
        sky.blendMode = .screen // the air lies in front of the Moon, and never clips its bright side
        sky.zPosition = 2
        addChild(sky)
        bake()
        run(.repeatForever(.sequence([.wait(forDuration: 60), .run { [weak self] in self?.needsBake = true }])))
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged),
                                               name: UserDefaults.didChangeNotification, object: nil)
    }

    override func didMove(to view: SKView) { Location.shared.start() }

    @objc private func settingsChanged() { needsBake = true } // Settings, or a new location fix

    override func update(_ currentTime: TimeInterval) {
        if needsBake { bake() }
        turntable.zRotation = upright(Sky.julianDate(date))
    }

    /// How far to turn the north-up Moon so the viewer's zenith is up: the parallactic angle, which swings through
    /// the night as the sky turns. A picked phase stays north up.
    private func upright(_ jd: Double) -> CGFloat {
        guard let seen, Self.knobs[0].value < 0.5 else { return 0 }
        let here = Location.shared.coordinate
        let lst = (Sky.siderealTime(jd) + here.longitude) * .pi / 180, lat = here.latitude * .pi / 180
        let zenith = Sky.Vector(cos(lat) * cos(lst), cos(lat) * sin(lst), sin(lat))
        return CGFloat(.pi / 2 - atan2(dot(zenith, seen.skyNorth), dot(zenith, -seen.skyEast))) // screen right is sky west
    }

    /// Lights the Moon for this minute, sizes it by its real distance, and lays out the backdrop behind it.
    private func bake() {
        needsBake = false
        let here = Location.shared.coordinate, jd = Sky.julianDate(date)
        let live = Sky.moonView(jd, latitude: here.latitude, longitude: here.longitude)
        // A picked phase is its fixed moment, seen from the Earth's centre as NASA's Dial-a-Moon shows it.
        let phase = min(max(Int(Self.knobs[0].value), 0), Self.phases.count)
        let seen = phase > 0 ? Sky.moonView(Self.phases[phase - 1]) : live
        self.seen = seen
        let diameter = Self.knobs[2].value * Double(min(size.width, size.height)) * 385_000 / seen.km // bigger at perigee
        let backdrop = Int(Self.knobs[1].value)
        stars.isHidden = backdrop == 0
        sky.isHidden = backdrop != 2
        moon.colorBlendFactor = 0
        if backdrop > 0 { placeStars(seen) }
        let skyLight = backdrop == 2 ? paintSky(jd, live) : 0 // the sky is live even when the phase isn't
        // Earthshine is far fainter than any lit sky, so it goes as the sky brightens.
        let side = min(Int(diameter * 2) + 4, 4096)
        moon.texture = baker.bake(seen, pixels: side, radius: diameter, brightness: Self.knobs[3].value,
                                  earthshine: Self.knobs[4].value * max(0, 1 - skyLight / 0.01))
        moon.size = CGSize(width: side / 2, height: side / 2)
    }

    /// The real stars around the Moon, faint, on a far wider scale than the Moon: about 40° of sky top to bottom.
    private func placeStars(_ seen: Sky.MoonView) {
        stars.removeAllChildren()
        stars.alpha = 1
        let scale = Double(size.height) / 2 / tan(20 * Double.pi / 180)
        let reach = Double(hypot(size.width, size.height)) / 2 / scale
        let (right, up) = (-seen.skyEast, seen.skyNorth)
        for star in LiveSky.catalogue {
            let forward = dot(star.direction, seen.toMoon)
            guard forward > 0.5 else { continue }
            let (x, y) = (dot(star.direction, right) / forward, dot(star.direction, up) / forward)
            guard x * x + y * y < reach * reach else { continue }
            let diameter = max(1.8, 5 - 0.6 * star.magnitude)
            let sprite = SKSpriteNode(texture: Self.glow, size: CGSize(width: diameter, height: diameter))
            sprite.position = CGPoint(x: x * scale, y: y * scale)
            sprite.color = LiveSky.starColour(star.bv)
            sprite.colorBlendFactor = 1
            sprite.alpha = min(0.85, max(0.3, 1 - 0.12 * star.magnitude))
            stars.addChild(sprite)
        }
    }

    private static let glow = paint(CGSize(width: 16, height: 16)) { ctx in
        let colours = [CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 0.35), CGColor(gray: 1, alpha: 0)] as CFArray
        ctx.drawRadialGradient(CGGradient(colorsSpace: nil, colors: colours, locations: [0, 0.3, 1])!,
                               startCenter: CGPoint(x: 8, y: 8), startRadius: 0, endCenter: CGPoint(x: 8, y: 8),
                               endRadius: 8, options: [])
    }

    /// The Sky backdrop: the physical sky where the Moon is (Weather's `Atmosphere`), deep blue at dusk and pale by
    /// day, laid over everything, and the Moon dimmed and warmed by the air it's seen through. Returns how bright
    /// the sky shows, 0…1.
    private func paintSky(_ jd: Double, _ seen: Sky.MoonView) -> Double {
        let here = Location.shared.coordinate
        let toHorizon = Sky.horizonMatrix(jd: jd, latitude: here.latitude, longitude: here.longitude)
        let sun = toHorizon * Sky.sun(jd), at = toHorizon * seen.toMoon
        // Below the horizon it's drawn as if it were as high above it, rather than as a black disc.
        // ponytail: that flips its tilt's reference too; fine while nobody can see the real one
        let (azimuth, altitude) = (atan2(at.x, at.y), max(abs(asin(at.z)), 0.02))
        func look(_ a: Double) -> SIMD3<Double> {
            let a = min(max(a, 0.02), 1.5)
            return [sin(azimuth) * cos(a), cos(azimuth) * cos(a), sin(a)]
        }
        let air = Atmosphere.shared
        let light = [-0.2, 0, 0.2].map { air.march(h0: 0.3, dir: look(altitude + $0), lights: [(sun, 1)]).light }
        let luminance = max(dot(light[1], [0.2126, 0.7152, 0.0722]), 1e-12)
        // Partial auto-exposure: a pale blue by day, deep blue at dusk, black by night.
        let exposure = 0.4 * pow(luminance / 0.1, 0.25) / luminance
        var bytes = [UInt8]()
        for colour in light { bytes += (0..<3).map { UInt8(min(pow(max(colour[$0] * exposure, 0), 1 / 2.2), 1) * 255) } + [255] }
        let texture = SKTexture(data: Data(bytes), size: CGSize(width: 1, height: 3))
        texture.filteringMode = .linear
        sky.texture = texture
        stars.alpha = CGFloat(1 - min(luminance * exposure / 0.12, 1))

        let through = air.sunlight(0.3, sin(altitude)) / air.sunlight(0.3, 1)
        moon.color = NSColor(red: pow(through.x, 1 / 2.2), green: pow(through.y, 1 / 2.2), blue: pow(through.z, 1 / 2.2), alpha: 1)
        moon.colorBlendFactor = 1
        return luminance * exposure
    }
}

/// Renders the lit Moon offscreen, north up and east left as it looks in the sky, into a texture for the scene's
/// sprite: a disc of `radius` pixels in a square `pixels` across. The shader does the costly part (shadows marched
/// over LOLA's heights) once a minute instead of every frame.
@MainActor final class MoonBaker {
    private static let device = MTLCreateSystemDefaultDevice()!
    private static let queue = device.makeCommandQueue()!
    private let renderer = SKRenderer(device: device)
    private let scene = SKScene(size: CGSize(width: 1, height: 1))
    private let sprite = SKSpriteNode(color: .black, size: CGSize(width: 1, height: 1))
    private let view = SKUniform(name: "u_view", matrixFloat3x3: matrix_identity_float3x3)
    private let sun = SKUniform(name: "u_sun", vectorFloat3: .zero)
    private let moonAt = SKUniform(name: "u_moonAt", vectorFloat3: .zero)
    private let axis = SKUniform(name: "u_axis", vectorFloat3: .zero)
    private let light = SKUniform(name: "u_light", vectorFloat4: .zero)
    private let disc = SKUniform(name: "u_disc", vectorFloat2: .zero)

    init() {
        scene.backgroundColor = .clear
        scene.addChild(sprite)
        sprite.shader = SKShader(source: Self.shader, uniforms: [
            view, sun, moonAt, axis, light, disc,
            SKUniform(name: "u_colour", texture: Self.colour), SKUniform(name: "u_terrain", texture: Self.terrain),
        ])
        renderer.scene = scene
    }

    func bake(_ seen: Sky.MoonView, pixels side: Int, radius: Double, brightness: Double, earthshine: Double) -> SKTexture {
        // The picture's axes (right = sky west, up = celestial north, out = toward the viewer) in the Moon's axes.
        let toMoon = seen.axes.transpose
        func f(_ v: Sky.Vector) -> SIMD3<Float> { SIMD3<Float>(toMoon * v) }
        view.matrixFloat3x3Value = simd_float3x3(columns: (f(-seen.skyEast), f(seen.skyNorth), f(-seen.toMoon)))
        sun.vectorFloat3Value = f(seen.toSun)
        moonAt.vectorFloat3Value = f(seen.position)
        axis.vectorFloat3Value = f(-seen.sunDirection)

        // Reflectance: McEwen's lunar-Lambert, Lommel-Seeliger (flat, no limb darkening) near full and more like
        // Lambert as the phase angle opens, times Hapke's opposition surge, which brightens the last day before full.
        let g = seen.phaseAngle * 180 / .pi
        let lommel = min(max(1 - 0.019 * g + 2.42e-4 * g * g - 1.46e-6 * g * g * g, 0.4), 1) // floored: its fit ends near 100°
        let surge = 1 + 0.25 / (1 + tan(seen.phaseAngle / 2) / 0.05) // about +25% at full
        // Exposed per phase, as a photographer would, so the brightest ground on a crescent looks as bright as at
        // quarter. Only the surge is left to show.
        let brightest = lommel + (1 - lommel) * (g < 90 ? 1 : sin(seen.phaseAngle))
        // Earthshine follows the Earth's own phase seen from the Moon (a Lambert sphere), steepened so it's gone by
        // quarter, as it is in any photo exposed for the sunlit side.
        let earth = Double.pi - seen.phaseAngle
        let earthPhase = (sin(earth) + (.pi - earth) * cos(earth)) / .pi
        // In an eclipse, exposed for the copper, as photos are, so what sunlight is left burns white.
        let centre = Sky.earthShadow(at: seen.position, sun: seen.sunDirection), moonRadius = 1737.4 / Sky.earthRadius
        let eclipse = min(max((centre.umbra + moonRadius - centre.off) / (2 * moonRadius), 0), 1)
        light.vectorFloat4Value = [Float(1.25 * brightness * surge / brightest), Float(lommel), Float(0.1 * earthshine * max(pow(earthPhase, 4) - 0.05, 0) / 0.95),
                                   Float(1 + 60 * eclipse)]
        disc.vectorFloat2Value = [Float(Double(side) / 2 / radius), Float(radius)]

        scene.size = CGSize(width: side, height: side)
        sprite.size = scene.size
        sprite.position = CGPoint(x: side / 2, y: side / 2)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: side, height: side, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        let target = Self.device.makeTexture(descriptor: descriptor)!
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        pass.colorAttachments[0].storeAction = .store
        renderer.update(atTime: CACurrentMediaTime())
        let buffer = Self.queue.makeCommandBuffer()!
        renderer.render(withViewport: CGRect(x: 0, y: 0, width: side, height: side), commandBuffer: buffer, renderPassDescriptor: pass)
        buffer.commit()
        buffer.waitUntilCompleted()

        var pixels = Data(count: side * side * 4)
        pixels.withUnsafeMutableBytes { target.getBytes($0.baseAddress!, bytesPerRow: side * 4, from: MTLRegionMake2D(0, 0, side, side), mipmapLevel: 0) }
        let image = CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: side * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                            provider: CGDataProvider(data: pixels as CFData)!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
        return SKTexture(cgImage: image)
    }

    /// NASA's CGI Moon Kit (svs.gsfc.nasa.gov/4720, public domain), cut to the near side (longitude −100…100°, all
    /// latitudes) at 16 pixels a degree: the LROC colour map, and LOLA's surface normals (east, north) and heights
    /// (−10…+11 km over 1737.4 km) packed into one texture. See docs/the-moon.md for how they were made.
    // ponytail: kept for the app's life once the Moon has shown (about 75 MB with mipmaps); free them when another
    // wallpaper takes over if memory ever matters
    private static let colour: SKTexture = {
        let texture = SKTexture(image: NSImage(contentsOf: resource("moon-colour.heic")) ?? NSImage())
        texture.usesMipmaps = true
        return texture
    }()

    private static let terrain: SKTexture = {
        let channels = ["moon-east.heic", "moon-north.heic", "moon-height.heic"].map { grey($0) }
        let (w, h) = (channels[0].width, channels[0].height)
        var rgba = [UInt8](repeating: 255, count: w * h * 4)
        rgba.withUnsafeMutableBufferPointer { out in
            for (c, channel) in channels.enumerated() where channel.width == w && channel.height == h {
                for y in 0..<h { for x in 0..<w { out[((h - 1 - y) * w + x) * 4 + c] = channel.bytes[y * w + x] } } // rows run bottom up
            }
        }
        let texture = SKTexture(data: Data(rgba), size: CGSize(width: w, height: h))
        texture.usesMipmaps = true
        return texture
    }()

    /// A greyscale image's own 8-bit values, top row first, drawn in its own colour space so nothing converts them:
    /// they're normals and heights, not colours.
    nonisolated private static func grey(_ name: String) -> (width: Int, height: Int, bytes: [UInt8]) {
        guard let source = CGImageSourceCreateWithURL(resource(name) as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width,
                                      space: image.colorSpace ?? CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { return (1, 1, [128]) }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return (image.width, image.height, Array(UnsafeBufferPointer(start: context.data!.assumingMemoryBound(to: UInt8.self), count: image.width * image.height)))
    }

    private static let shader = """
        vec2 mapAt(vec3 d) { return vec2(atan(d.y, d.x) * 0.2864789 + 0.5, asin(clamp(d.z, -1.0, 1.0)) * 0.3183099 + 0.5); }

        void main() {
            vec2 p = (v_tex_coord * 2.0 - 1.0) * u_disc.x;
            float r2 = dot(p, p);
            vec3 n = u_view * vec3(p, sqrt(max(1.0 - r2, 0.0))); // this spot on the Moon, in its own axes
            vec2 uv = mapAt(n);
            vec4 ground = texture2D(u_terrain, uv);
            vec3 albedo = pow(texture2D(u_colour, uv).rgb, vec3(2.2));
            vec3 east = normalize(vec3(-n.y, n.x, 0.0) + vec3(0.0, 1e-6, 0.0));
            vec3 north = cross(n, east);
            vec2 slope = ground.rg * 2.0 - 1.0;
            vec3 normal = normalize(slope.x * east + slope.y * north + sqrt(max(1.0 - dot(slope, slope), 0.0)) * n);

            // Shadows: the highest ground toward the Sun, out about 200 km over the curve, against the Sun's height.
            // The same toward the viewer finds ground hidden behind a rise; what shows there instead is the rise's
            // sunward face, lit when the Sun is behind the viewer, so shadows hide at full moon as they really do.
            vec3 toViewer = u_view * vec3(0.0, 0.0, 1.0);
            float sunUp = dot(n, u_sun), viewUp = dot(n, toViewer);
            vec3 toward = normalize(u_sun - n * sunUp + vec3(1e-6)), towardViewer = normalize(toViewer - n * viewUp + vec3(1e-6));
            float here = 1727.4 + ground.b * 21.0, horizon = -1.0, viewHorizon = -1.0, a = 0.0008;
            for (int i = 0; i < 20; i++) {
                vec3 q = n * cos(a) + toward * sin(a), v = n * cos(a) + towardViewer * sin(a);
                horizon = max(horizon, dot(normalize(q * (1727.4 + texture2D(u_terrain, mapAt(q)).b * 21.0) - n * here), n));
                viewHorizon = max(viewHorizon, dot(normalize(v * (1727.4 + texture2D(u_terrain, mapAt(v)).b * 21.0) - n * here), n));
                a *= 1.28;
            }
            float sunlit = smoothstep(-0.0047, 0.0047, sunUp - horizon); // the Sun is 0.27° in radius
            sunlit = max(sunlit, 1.0 - smoothstep(-0.003, 0.003, viewUp - viewHorizon));

            // Lunar-Lambert: u_light.y of Lommel-Seeliger, the rest Lambert.
            normal = normalize(mix(n, normal, smoothstep(0.0, 0.1, dot(normal, toViewer)))); // slopes facing away are out of sight
            float mu0 = max(dot(normal, u_sun), 0.0), mu = max(dot(normal, toViewer), 0.0);
            float shade = u_light.y * 2.0 * mu0 / (mu0 + mu + 1e-4) + (1.0 - u_light.y) * mu0;

            // The Earth's shadow, in Earth radii. In the umbra, only sunsets all round the Earth's rim reach the
            // Moon: copper, brighter toward the edge, with a blue fringe where that light skims the ozone.
            vec3 at = u_moonAt + n * 0.2724;
            float along = dot(at, u_axis);
            float off = along > 0.0 ? length(at - along * u_axis) : 1000.0;
            float umbra = 1.02 - along * 0.0046098, penumbra = 1.02 + along * 0.0046951;
            float direct = along > 0.0 ? clamp((off - umbra) / (penumbra - umbra), 0.0, 1.0) : 1.0;
            float edge = clamp(off / umbra, 0.0, 1.0);
            vec3 copper = vec3(1.0, 0.38, 0.12) * (0.08 + edge * edge * edge) + vec3(0.03, 0.12, 0.15) * smoothstep(0.85, 1.0, edge);

            // LROC's colour, toned down to what the eye sees, with the contrast of NASA's own renders (Dial-a-Moon).
            albedo = pow(mix(vec3(dot(albedo, vec3(0.2126, 0.7152, 0.0722))), albedo, 0.5), vec3(1.37));
            vec3 x = albedo * (u_light.x * shade * sunlit * mix(copper, vec3(u_light.w), direct) + u_light.z * vec3(0.7, 0.88, 1.25));
            x = min(x, 0.8) + 0.2 * (1.0 - exp(-max(x - 0.8, 0.0) / 0.2)); // linear, then a soft shoulder to white
            vec3 colour = pow(x, vec3(1.0 / 2.2));
            colour += (fract(sin(dot(v_tex_coord * 4096.0, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0;
            float alpha = clamp((1.0 - sqrt(r2)) * u_disc.y + 0.5, 0.0, 1.0);
            gl_FragColor = vec4(colour * alpha, alpha);
        }
        """
}

extension Sky {
    /// The Moon's body axes in J2000 equatorial coordinates: columns toward 0° longitude, 90° east, and its north
    /// pole. By Cassini's laws (Meeus ch. 53) the pole sits 1.54° from the ecliptic's, on the far side from the
    /// orbit's, and the prime meridian faces the Earth's mean direction, so libration falls out of the real orbit.
    // ponytail: optical libration only; the physical libration left out is under 0.04°
    static func moonAxes(_ jd: Double) -> simd_double3x3 {
        let t = (jd + 69.0 / 86400 - 2451545) / 36525, degree = Double.pi / 180 // TT, as in moonPosition
        let node = (125.0445479 - 1934.1362891 * t) * degree, F = (93.2720950 + 483202.0175233 * t) * degree
        let tilt = 1.54242 * degree
        let pole = Vector(-sin(tilt) * sin(node), sin(tilt) * cos(node), cos(tilt))
        let q = Vector(cos(node), sin(node), 0), r = cross(pole, q) // the orbit's ascending node, and 90° on
        let meridian = -(cos(F) * q + sin(F) * r)
        // Ecliptic of date → J2000 as moonPosition does it: general precession in longitude, then onto the equator.
        let p = -1.3969713 * t * degree
        func j2000(_ v: Vector) -> Vector { equatorial(fromEcliptic: [v.x * cos(p) - v.y * sin(p), v.x * sin(p) + v.y * cos(p), v.z]) }
        return simd_double3x3(columns: (j2000(meridian), j2000(cross(pole, meridian)), j2000(pole)))
    }

    /// How the Moon looks from a place on the ground, or from the Earth's centre when `place` is nil (as NASA's
    /// Dial-a-Moon shows it). Vectors are J2000 equatorial.
    struct MoonView {
        var toMoon: Vector            // from the viewer, unit
        var km: Double                // from the viewer
        var axes: simd_double3x3      // see moonAxes
        var toSun: Vector             // from the Moon, unit
        var position: Vector          // the Moon from the Earth's centre, in Earth radii (for the Earth's shadow)
        var sunDirection: Vector      // the Sun from the Earth, unit

        /// Selenographic longitude (east positive) and latitude of a direction from the Moon's centre, in degrees.
        func onMoon(_ v: Vector) -> (longitude: Double, latitude: Double) {
            let b = axes.transpose * v
            return (atan2(b.y, b.x) * 180 / .pi, asin(b.z / length(b)) * 180 / .pi)
        }

        /// Where the viewer is overhead on the Moon: its libration in longitude and latitude.
        var libration: (longitude: Double, latitude: Double) { onMoon(-toMoon) }
        var subsolar: (longitude: Double, latitude: Double) { onMoon(toSun) }
        /// Sun–Moon–viewer angle, in radians: 0 at full moon.
        var phaseAngle: Double { acos(min(max(dot(toSun, -toMoon), -1), 1)) }
        var lit: Double { (1 + cos(phaseAngle)) / 2 }

        /// Celestial north and east on the sky at the Moon, as the viewer sees it.
        var skyNorth: Vector { cross(toMoon, skyEast) }
        var skyEast: Vector { normalize(cross(Vector(0, 0, 1), toMoon)) }
        /// Position angle of the Moon's north pole, degrees east of celestial north (0..<360).
        var positionAngle: Double {
            let pole = axes.columns.2, angle = atan2(dot(pole, skyEast), dot(pole, skyNorth)) * 180 / .pi
            return angle < 0 ? angle + 360 : angle
        }
    }

    static let earthRadius = 6378.137 // km, equatorial, as eclipse predictions use it

    static func moonView(_ jd: Double, latitude: Double? = nil, longitude: Double? = nil) -> MoonView {
        let position = moonPosition(jd), sun = sun(jd)
        var (toMoon, km) = (normalize(position), length(position))
        if let latitude, let longitude { (toMoon, km) = moon(jd, latitude: latitude, longitude: longitude) }
        let toSun = normalize(sun * 149_597_870.7 - position) // the Moon sees the Sun from 1/400 AU off our line
        return MoonView(toMoon: toMoon, km: km, axes: moonAxes(jd), toSun: toSun, position: position / earthRadius,
                        sunDirection: sun)
    }

    /// Where a point `at` (Earth radii from the Earth's centre) sits in the Earth's shadow: its distance from the
    /// shadow's axis, and the umbra's and penumbra's radii there. The Earth is taken 2% larger for its atmosphere,
    /// as eclipse tables do (Chauvenet). On the Sun's side of the Earth there's no shadow, so `off` is infinite.
    static func earthShadow(at point: Vector, sun: Vector) -> (off: Double, umbra: Double, penumbra: Double) {
        let along = dot(point, -sun), off = along > 0 ? length(point + sun * along) : .infinity
        let sunRadius = 696_000 / earthRadius, au = 149_597_870.7 / earthRadius
        return (off, 1.02 - along * (sunRadius - 1) / au, 1.02 + along * (sunRadius + 1) / au)
    }
}
