import SpriteKit

@MainActor func campfire(size: CGSize) -> SKScene { Campfire(size: size) }

/// A campfire at night in a real forest clearing (a photo relit by the fire), under the real stars. The flames are
/// a small fluid simulation drawn with rising noise, coloured by blackbody light through a camera's response. Their
/// light, measured from the flames themselves, falls on the stones, the charred wood, the ground and the nearest
/// trees with the right distance, angle and shadows, and flickers as they do. A faint glow, warm smoke and heat
/// shimmer hang above them.
final class Campfire: SKScene {
    private let flames: Flames
    private let sparks: Sparks
    private let light = SKUniform(name: "u_light", vectorFloat4: [0, 0.35, 4.5, 1])
    private let clock = SKUniform(name: "u_clock", float: 0)
    private var glow: CGFloat = 1, lastTime: TimeInterval?, time = 0.0
    private let lens: FireCamera
    private var halos: [SKSpriteNode] = []

    override init(size: CGSize) {
        lens = FireCamera(screen: size)
        sparks = Sparks(scale: lens.scale(at: FireCamera.fire))
        flames = Flames(scale: lens.scale(at: FireCamera.fire) * 1.25)
        super.init(size: size)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func sceneDidLoad() {
        backgroundColor = .black
        addSky()
        addGround()
        let bed = coalBed(scale: lens.scale(at: FireCamera.fire), width: 0.95, depth: 0.95 * 0.36, clock: clock,
                          ash: SKUniform(name: "u_ash", vectorFloat3: [0.05, 0.03, 0.02]))
        bed.position = lens.project(FireCamera.fire + [0, 0.02, 0])
        bed.zPosition = 1
        addChild(bed)
        flames.position = lens.project(FireCamera.fire + [0, 0.1, 0])
        flames.zPosition = 2
        addChild(flames)
        sparks.position = lens.project(FireCamera.fire + [0, 0.1, 0])
        sparks.zPosition = 4
        addChild(sparks)
        addSmokeAndGlow()
    }

    override func didMove(to view: SKView) { Location.shared.start() }   // for the stars overhead

    override func update(_ currentTime: TimeInterval) {
        let dt = frameTime(currentTime, &lastTime)
        flames.advance(dt)
        sparks.advance(dt)
        time += dt
        clock.floatValue = Flames.shaderClock(time)
        // the light it casts: a steady fifth from the embers, the rest following the flames a little smoothed, from
        // where the flames are brightest
        glow += (flames.light - glow) * min(1, dt / 0.15)
        let c = flames.centre
        light.vectorFloat4Value = [Float(FireCamera.fire.x + c.x), Float(0.1 + c.y), Float(FireCamera.fire.z), Float(0.2 + 0.8 * glow)]
        for halo in halos { halo.alpha = (halo.userData?["strength"] as? CGFloat ?? 0) * (0.2 + 0.8 * glow) }
    }

    /// Warm smoke lit from below just over the flames, and the camera's glow round them (lit air and lens flare: a
    /// tight halo and a wide one). All faint, following the firelight: heavy glow is a tell of game fire.
    private func addSmokeAndGlow() {
        let scale = lens.scale(at: FireCamera.fire), base = lens.project(FireCamera.fire + [0, 0.1, 0])
        let smoke = SKSpriteNode(color: .black, size: CGSize(width: 1.6 * scale, height: 1.9 * scale))
        smoke.anchorPoint = CGPoint(x: 0.5, y: 0)
        smoke.position = base
        smoke.zPosition = 2.5
        smoke.blendMode = .add
        smoke.shader = SKShader(source: shaderCommon + """
        void main() {
            // metres: x across, h up from the flames' base; the haze starts at the tips (~0.5 m), rises ~1 m/s in a
            // cone widening 0.12 m per metre, and is gone by 1.5 m
            float x = (v_tex_coord.x - 0.5) * 1.6;
            float h = v_tex_coord.y * 1.9;
            float width = 0.22 + 0.12 * h;
            vec2 q = vec2(x / width * 1.5, h * 2.2 - u_clock * 1.1);
            float puffs = noise(q + vec2(noise(q * 0.7 + 3.0) * 1.5, 0.0)) * 0.7 + noise(q * 2.3 + 11.0) * 0.3;
            float haze = exp(-x * x / (width * width)) * smoothstep(0.35, 0.7, h) * smoothstep(1.6, 0.9, h) * puffs;
            float lit = u_light.w * 0.9 / (0.3 + h * h);                    // firelight from below, 1/r²
            vec3 col = vec3(1.0, 0.6, 0.5) * haze * lit * 0.022;
            gl_FragColor = vec4(col, 1.0);
        }
        """, uniforms: [light, clock])
        addChild(smoke)
        for (diameter, strength) in [(1.3, 0.1), (3.2, 0.045)] as [(CGFloat, CGFloat)] {
            let halo = SKSpriteNode(texture: radialGlow(diameter: 64, stops: [(0, rgb(1, 1, 1)), (0.35, rgb(1, 1, 1, 0.4)), (1, rgb(1, 1, 1, 0))]),
                                    size: CGSize(width: diameter * scale, height: diameter * scale * 0.85))
            halo.position = CGPoint(x: base.x, y: base.y + 0.3 * scale)
            halo.zPosition = 5
            halo.blendMode = .add
            halo.color = NSColor(red: 1, green: 0.58, blue: 0.28, alpha: 1)
            halo.colorBlendFactor = 1
            halo.alpha = strength
            halo.userData = ["strength": strength]
            halos.append(halo)
            addChild(halo)
        }
    }

    // MARK: Sky

    private func addSky() {
        let sky = SKSpriteNode(color: .black, size: size)
        sky.anchorPoint = .zero
        sky.zPosition = -1000
        sky.shader = SKShader(source: shaderCommon + """
        void main() {
            float h = v_tex_coord.y;
            // moonless: airglow and far towns low down, deep blue-black overhead; a faint tail of stars too dim to
            // be in the catalogue, clumped as real star fields are
            vec3 sky = mix(vec3(0.010, 0.012, 0.021), vec3(0.0022, 0.0030, 0.0065), smoothstep(0.35, 1.0, h));
            vec2 pts = v_tex_coord * u_size;
            float clump = 0.4 + 1.2 * noise(pts / 300.0 + 7.0);
            sky += vec3(0.8, 0.85, 1.0) * starField(pts, 6.0, 0.35 * clump, u_now) * 0.012;
            vec3 col = 1.0 - exp(-sky * 1.0);
            col = mix(col * 12.92, 1.055 * pow(col, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, col));
            gl_FragColor = vec4(col + (hash21(v_tex_coord * u_size * 2.0) - 0.5) / 255.0, 1.0);
        }
        """, uniforms: [SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)]), WallpaperTime.now])
        addChild(sky)
        let stars = StarField(camera: lens)
        stars.zPosition = -900
        addChild(stars)
    }

    // MARK: Ground

    /// The photo, relit, in two slices: everything behind the flames, then the stones and sticks in front of them
    /// (a sprite over just the fire bed; its texture coordinates are still the whole photo's).
    private func addGround() {
        let bed = CampfirePhoto.bedRect
        // heat shimmer: where the fire's base is in the photo's texture coordinates, and texture units per metre there
        let base = lens.project(FireCamera.fire + [0, 0.1, 0]), perMetre = lens.scale(at: FireCamera.fire)
        let left = size.width / 2 - lens.photoSize.width / 2
        let shimmer = SKUniform(name: "u_shimmer", vectorFloat4: [Float((base.x - left) / lens.photoSize.width), Float(base.y / lens.photoSize.height),
                                                                  Float(perMetre / lens.photoSize.width), Float(perMetre / lens.photoSize.height)])
        for front in [false, true] {
            let texture = front ? SKTexture(rect: bed, in: CampfirePhoto.albedo) : CampfirePhoto.albedo
            let ground = SKSpriteNode(texture: texture, size: front ? CGSize(width: lens.photoSize.width * bed.width, height: lens.photoSize.height * bed.height) : lens.photoSize)
            ground.anchorPoint = .zero
            ground.position = CGPoint(x: size.width / 2 - lens.photoSize.width / 2 + (front ? lens.photoSize.width * bed.minX : 0),
                                      y: front ? lens.photoSize.height * bed.minY : 0)
            ground.zPosition = front ? 3 : 0
            ground.shader = SKShader(source: shaderCommon + Self.groundSource, uniforms: [
                SKUniform(name: "u_aux", texture: CampfirePhoto.aux), SKUniform(name: "u_bed", texture: CampfirePhoto.bed),
                SKUniform(name: "u_bedRect", vectorFloat4: [Float(bed.minX), Float(bed.minY), Float(bed.maxX), Float(bed.maxY)]),
                SKUniform(name: "u_front", float: front ? 1 : 0), light, clock, shimmer,
            ])
            addChild(ground)
        }
    }

    /// Albedo is 2·tex^2.2 (sRGB at half scale); the aux map has log distance (1–400 m) in R and the world normal's
    /// x and y in G and B, which place each pixel in metres. It's lit by a point of firelight (1900 K through the
    /// camera's 3200 K balance, 1/r²), whose lower part the upright stones hide from the ground outside the ring,
    /// plus faint starlight. Wood inside the ring is charred black, and glows in its cracks near the embers.
    static let groundSource = """
    void main() {
        // heat shimmer: behind the column of hot air over the fire, the view wobbles by a pixel or so
        vec2 uv = v_tex_coord;
        if (u_front < 0.5) {
            float hx = (uv.x - u_shimmer.x) / u_shimmer.z, hy = (uv.y - u_shimmer.y) / u_shimmer.w;   // metres
            float column = exp(-hx * hx / 0.12) * smoothstep(0.3, 0.6, hy) * smoothstep(2.2, 1.0, hy);
            vec2 q = vec2(hx * 9.0, hy * 5.0 - u_clock * 7.0);
            uv += column * vec2(noise(q) - 0.5, noise(q + 5.3) - 0.5) * 0.0011;
        }
        vec4 photo = texture2D(u_texture, uv);
        vec3 aux = texture2D(u_aux, uv).rgb;
        float t = pow(400.0, aux.r);
        bool inBed = v_tex_coord.x > u_bedRect.x && v_tex_coord.x < u_bedRect.z && v_tex_coord.y > u_bedRect.y && v_tex_coord.y < u_bedRect.w;
        vec4 out = vec4(0.0);
        if ((inBed && t < 4.25) == (u_front > 0.5)) {
            vec3 alb = 2.0 * pow(photo.rgb / max(photo.a, 0.004), vec3(2.2));
            vec3 n = vec3(aux.g * 2.0 - 1.0, aux.b * 2.0 - 1.0, 0.0);
            n.z = -sqrt(max(0.0, 1.0 - n.x * n.x - n.y * n.y));
            // the ray through this pixel, from a camera 1.6 m up, pitched up 3°, 84° across 4096 px
            vec3 c = normalize(vec3((v_tex_coord - 0.5) * vec2(4096.0, 2660.0), 2274.5));
            vec3 d = vec3(c.x, c.y * 0.99863 + c.z * 0.05234, -c.y * 0.05234 + c.z * 0.99863);
            vec3 p = vec3(0.0, 1.6, 0.0) + d * t;
            vec3 toFire = u_light.xyz - p;
            float r2 = dot(toFire, toFire) + 0.16;                             // the flames are a broad source, not a point
            float facing = max((dot(n, normalize(toFire)) + 0.1) / 1.1, 0.0);
            // the ring's stones (0.39 m high at 0.72 m) hide the flames below this height from here
            // (the photo's own ground is always outside the ring, even where the depth estimate strays inside it)
            vec2 bed = inBed ? texture2D(u_bed, (v_tex_coord - u_bedRect.xy) / (u_bedRect.zw - u_bedRect.xy)).rg : vec2(0.0);
            float out_ = mix(max(length(p.xz - u_light.xz), 0.8), length(p.xz - u_light.xz), step(0.5, bed.g));
            float hidden = out_ > 0.76 ? p.y + (0.39 - p.y) * out_ / (out_ - 0.72) : 0.0;
            float seen = 0.2 + 0.8 * smoothstep(0.0, 1.0, (1.15 - hidden) / 1.05);   // the tall flames, and bounce off the far stones
            float wood = bed.r;
            alb = mix(alb, alb * 0.2 + 0.004, wood);                          // charred
            // plus light bounced off the lit ground and the far stones, which reaches faces turned away too
            vec3 col = alb * (vec3(1.0, 0.41, 0.09) * 2.6 * u_light.w * (facing * seen + 0.07) / r2 + vec3(0.0020, 0.0026, 0.0042));
            // embers in the charred wood near the bottom of the fire
            if (wood > 0.01) {
                vec2 q = p.xz * 60.0 + vec2(p.y * 40.0, 0.0);
                float cracks = smoothstep(0.35, 0.5, noise(q)) * smoothstep(0.55, 0.4, noise(q * 1.7 + 3.0));
                float heat = smoothstep(0.35, 0.05, p.y) * (0.7 + 0.3 * sin(u_clock * 1.3 + noise(q * 0.3) * 20.0));
                float kelvin = 820.0 + 200.0 * heat;
                vec3 bb = vec3(exp(-22800.0 * (1.0 / kelvin - 1.0 / 1300.0)), 0.165 * exp(-26600.0 * (1.0 / kelvin - 1.0 / 1300.0)), 0.0);
                col += wood * cracks * heat * bb * 1.2;
            }
            col = 1.0 - exp(-col * 1.4);
            col = mix(col * 12.92, 1.055 * pow(col, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, col));
            col += (hash21(v_tex_coord * 4096.0) - 0.5) / 255.0;
            out = vec4(col, 1.0) * photo.a;
        }
        gl_FragColor = out;
    }
    """
}

/// The camera the backdrop was baked for, fitted to the screen: 1.6 m up, pitched up 3°, 84° across the photo's
/// 4096 pixels. World metres: x right, y up, z forward. The photo fills the screen from the bottom, cropping the top
/// or the sides.
struct FireCamera {
    static let fire = SIMD3<Double>(0, 0, 4.5)                              // middle of the stone ring, on the ground
    static let pixels = CGSize(width: 4096, height: 2660), focalPixels = 2274.5, pitch = 3 * Double.pi / 180, height = 1.6
    let photoSize: CGSize, focal: Double, centre: CGPoint

    init(screen: CGSize) {
        let s = max(screen.width / Self.pixels.width, screen.height / Self.pixels.height)
        photoSize = CGSize(width: Self.pixels.width * s, height: Self.pixels.height * s)
        focal = Self.focalPixels * Double(s)
        centre = CGPoint(x: screen.width / 2, y: photoSize.height / 2)
    }

    /// Where a world point lands on screen.
    func project(_ p: SIMD3<Double>) -> CGPoint {
        let y = p.y - Self.height
        let yc = y * cos(Self.pitch) - p.z * sin(Self.pitch), zc = y * sin(Self.pitch) + p.z * cos(Self.pitch)
        return CGPoint(x: centre.x + focal * p.x / zc, y: centre.y + focal * yc / zc)
    }

    /// Points per metre for something upright at a world point.
    func scale(at p: SIMD3<Double>) -> CGFloat { CGFloat(focal / (p.z * cos(Self.pitch))) }
}

/// The baked backdrop: "Hochsal Forest" (Poly Haven, CC0) with a scanned stone fire pit and dry branches (Poly
/// Haven, CC0) rendered into the same view. See docs/campfire.md for the bake.
@MainActor enum CampfirePhoto {
    static let albedo = SKTexture(image: NSImage(contentsOf: resource("campfire-ground.heic")) ?? NSImage())
    static let aux = SKTexture(image: NSImage(contentsOf: resource("campfire-ground-aux.png")) ?? NSImage())
    static let bed = SKTexture(image: NSImage(contentsOf: resource("campfire-bed.png")) ?? NSImage())
    /// The bed mask's place in the photo (R wood, G the pit and wood), in texture coordinates (origin bottom-left).
    static let bedRect = CGRect(x: 1640.0 / 4096, y: 1 - 2372.0 / 2660, width: 812.0 / 4096, height: 632.0 / 2660)
}

/// The real stars over the viewer right now (Live Sky's catalogue), seen through the campfire's camera turned to
/// face the equator. Faint stars are small
/// dim points and bright ones slightly larger, tinted by their colour, and all dim toward the horizon through
/// more air. Positions are refreshed every 10 s (the sky turns about 0.04° in that time).
final class StarField: SKNode {
    private var sprites: [SKSpriteNode] = []
    private let camera: FireCamera, limit: Double

    init(camera: FireCamera, limit: Double = 5.5) {
        self.camera = camera; self.limit = limit
        super.init()
        refresh()
        run(.repeatForever(.sequence([.wait(forDuration: 10), .run { [weak self] in self?.refresh() }])))
    }

    required init?(coder: NSCoder) { fatalError() }

    private static let dot = paint(CGSize(width: 8, height: 8)) { ctx in
        let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                           colors: [rgb(1, 1, 1), rgb(1, 1, 1, 0.5), rgb(1, 1, 1, 0)] as CFArray, locations: [0, 0.3, 1])!
        ctx.drawRadialGradient(g, startCenter: CGPoint(x: 4, y: 4), startRadius: 0, endCenter: CGPoint(x: 4, y: 4), endRadius: 4, options: [])
    }

    private func refresh() {
        let here = Location.shared.coordinate
        let toHorizon = Sky.horizonMatrix(jd: Sky.julianDate(Date()), latitude: here.latitude, longitude: here.longitude)
        let south = here.latitude >= 0
        var n = 0
        for star in LiveSky.catalogue where star.magnitude <= limit {
            let h = toHorizon * star.direction
            let forward = south ? -h.y : h.y, right = south ? -h.x : h.x
            guard h.z > 0.02, forward > 0.1 else { continue }
            let p = camera.project([right * 1000, FireCamera.height + h.z * 1000, forward * 1000])
            guard p.x > -4, p.x < camera.centre.x * 2 + 4, p.y > 0, p.y < camera.photoSize.height + 4 else { continue }
            if n == sprites.count {
                let s = SKSpriteNode(texture: Self.dot)
                s.colorBlendFactor = 1
                s.blendMode = .add
                addChild(s)
                sprites.append(s)
            }
            let s = sprites[n]
            n += 1
            // flux relative to a 2nd-magnitude star, square-rooted for the eye; through 1/sin(altitude) airmasses at
            // 0.25 magnitudes each
            let extinction = pow(10, -0.1 * (1 / max(h.z, 0.05) - 1))
            let flux = pow(10, -0.4 * (star.magnitude - 2)) * extinction
            let d = max(1.3, min(5, 1.3 + 1.2 * log10(1 + flux * 3)))
            s.size = CGSize(width: d, height: d)
            s.position = p
            let c = LiveSky.starColour(star.bv).usingColorSpace(.sRGB)!
            s.color = NSColor(red: 0.5 + 0.5 * c.redComponent, green: 0.5 + 0.5 * c.greenComponent, blue: 0.5 + 0.5 * c.blueComponent, alpha: 1)
            s.alpha = min(1, 0.12 + 0.55 * sqrt(flux))
            s.isHidden = false
        }
        for s in sprites[n...] { s.isHidden = true }
    }
}
