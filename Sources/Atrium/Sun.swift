import SpriteKit

/// The real Sun as NASA's Solar Dynamics Observatory saw it within the last hour or so, in one wavelength: a corona
/// of gold loops in 171 Å, the red chromosphere in 304, sunspots in visible light. Today's flares and sunspots show
/// up the day they happen. Brought to life: plasma pulses out along the bright loops, active regions flicker, the
/// corona streams outward, and every few minutes one of today's active regions flares or a prominence erupts off the
/// limb. Settings compares that with the still image, and the whole Sun with a close-up off one edge. It's the Sun's live
/// view in Solar System Tour, which runs it nested in its own scene.
final class TheSun: SKScene {
    /// The channels, each in the colours SDO publishes it in (SolarSoft's `aia_lct` tables, which Helioviewer applies).
    /// `source` is Helioviewer's source id. Swatches are the table at 25, 50 and 85%; visible light's are NASA's
    /// orange, from sunspot to limb to centre.
    nonisolated static let wavelengths: [(name: String, source: Int, swatch: [SIMD3<Float>])] = [
        ("171 Gold", 10, [[0.36, 0.25, 0.0], [0.73, 0.50, 0.0], [1.0, 0.85, 0.41]]),    // Fe IX, 0.6 MK: the quiet corona's loops
        ("193 Bronze", 11, [[0.50, 0.25, 0.06], [0.71, 0.50, 0.25], [0.92, 0.85, 0.73]]), // Fe XII, 1.2 MK: corona, dark coronal holes
        ("211 Purple", 12, [[0.50, 0.25, 0.36], [0.71, 0.50, 0.56], [0.92, 0.85, 0.85]]), // Fe XIV, 2 MK: active regions
        ("304 Red", 13, [[0.36, 0.0, 0.0], [0.73, 0.06, 0.0], [1.0, 0.72, 0.41]]),       // He II, 50,000 K: chromosphere, prominences
        ("131 Teal", 9, [[0.0, 0.36, 0.36], [0.06, 0.73, 0.73], [0.72, 1.0, 1.0]]),      // Fe XX, 10 MK: flares
        ("94 Green", 8, [[0.06, 0.36, 0.25], [0.25, 0.56, 0.50], [0.73, 0.85, 0.85]]),   // Fe XVIII, 6 MK: flares
        ("335 Blue", 14, [[0.06, 0.25, 0.50], [0.25, 0.50, 0.71], [0.73, 0.85, 0.92]]),  // Fe XVI, 2.5 MK: active regions
        ("Visible", 18, [[0.62, 0.08, 0.0], [0.91, 0.31, 0.01], [1.0, 0.69, 0.11]]),     // HMI continuum: the surface and sunspots
    ]
    nonisolated static let knobs = [
        Knob(key: "sun.motion", label: "Motion", range: 0...1, standard: 1, section: "View",
             format: .choice(["Still, with a shimmer at the edge", "Alive: flowing loops, flares and eruptions"])),
        Knob(key: "sun.framing", label: "Framing", range: 0...1, standard: 0, section: "View", format: .choice(["Whole Sun", "Close-up"])),
        Knob(key: "sun.events", label: "A flare or eruption every", range: 0...20, standard: 5, section: "View", format: .minutes),
        Knob(key: "sun.life", label: "Liveliness", range: 0...2, standard: 1, section: "View"),
    ] + gradeKnobs("sun")

    /// The wavelength, picked when the scene is built: 0 is Random.
    nonisolated static let wavelengthKnob = Knob(key: "sun.light", label: "Wavelength", range: 0...Double(wavelengths.count), standard: 0,
                                                 section: "View", format: .choice(["Random"] + wavelengths.map(\.name)))

    private let wavelength = TheSun.wavelengthKnob.value > 0.5
        ? TheSun.wavelengths[min(Int(TheSun.wavelengthKnob.value), TheSun.wavelengths.count) - 1] : TheSun.wavelengths.randomElement()!
    // The frame showing and the one it's fading to (by `u_fade`), each cropped to what the framing shows: `u_crop`
    // and `u_cropNext` are the part of SDO's image each holds, as x, y, width and height from 0 to 1.
    private lazy var frameUniform = SKUniform(name: "u_frame", texture: placeholder())
    private lazy var nextUniform = SKUniform(name: "u_next", texture: frameUniform.textureValue)
    /// A copy of the frame showing, 16 times smaller: blurred, to find where its active regions' cores are.
    private lazy var blurUniform = SKUniform(name: "u_blur", texture: frameUniform.textureValue)
    private let cropUniform = SKUniform(name: "u_crop", vectorFloat4: [0, 0, 1, 1])
    private let cropNextUniform = SKUniform(name: "u_cropNext", vectorFloat4: [0, 0, 1, 1])
    private let fadeUniform = SKUniform(name: "u_fade", float: 0)
    private let discUniform = SKUniform(name: "u_disc", vectorFloat3: .zero)
    // Hours of the Sun's rotation to turn each frame by, to bring it to now, and the tilt of its axis toward us.
    private let ageUniform = SKUniform(name: "u_age", float: 0)
    private let ageNextUniform = SKUniform(name: "u_ageNext", float: 0)
    private let tiltUniform = SKUniform(name: "u_tilt", float: sunTilt(at: Date()))
    // The flare (x, y in solar radii, seconds since it began, strength) and eruption (angle round the limb, seconds,
    // strength, size in solar radii) under way; a strength of 0 is none.
    private let flareUniform = SKUniform(name: "u_flare", vectorFloat4: .zero)
    private let eruptionUniform = SKUniform(name: "u_eruption", vectorFloat4: .zero)
    /// The knobs the shader reads, as live uniforms.
    private let knobUniforms = ([TheSun.knobs[0], TheSun.knobs[3]] + TheSun.knobs[4...])
        .map { ($0, SKUniform(name: "u_" + $0.key.split(separator: ".").last!, float: Float($0.value))) }
    /// The frame in `u_frame`, the framing it's cropped for, the brightest knots on its disc, and whether a change is
    /// loading or fading; then the frame in `u_next` once it's loaded, with how far the crossfade to it has got.
    private var showing: URL?
    private var framing = 0
    private var spots: [SIMD2<Float>] = []
    private var busy = false
    private var next: (url: URL, crop: SIMD4<Float>, framing: Int, blur: SKTexture, spots: [SIMD2<Float>])?
    private var progress = 0.0
    private var lastUpdate: TimeInterval?
    /// When the newest cached frame was taken, kept by `advance()` so the frame loop needn't list the cache.
    private var newest = Date()
    /// Seconds to the next flare or eruption: the first soon after the wallpaper appears (at once with `sun.nextEvent`
    /// set, for trying them out), then every few minutes.
    private var untilEvent = UserDefaults.standard.string(forKey: "sun.nextEvent") == nil ? Double.random(in: 10...25) : 1
    private var alive: Bool { Self.knobs[0].value > 0.5 }

    override func sceneDidLoad() {
        backgroundColor = .black
        let sprite = SKSpriteNode(color: .black, size: size)
        sprite.anchorPoint = .zero
        sprite.shader = SKShader(source: shaderCommon + Self.shader, uniforms: [
            SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)]), WallpaperTime.now,
            frameUniform, nextUniform, blurUniform, cropUniform, cropNextUniform, fadeUniform, discUniform, ageUniform, ageNextUniform, tiltUniform,
            flareUniform, eruptionUniform, SKUniform(name: "u_lo", vectorFloat3: wavelength.swatch[0]),
            SKUniform(name: "u_mid", vectorFloat3: wavelength.swatch[1]), SKUniform(name: "u_hot", vectorFloat3: wavelength.swatch[2]),
            SKUniform(name: "u_visible", float: wavelength.source == 18 ? 1 : 0),
        ] + knobUniforms.map(\.1))
        addChild(sprite)
        framing = Int(Self.knobs[1].value)
        discUniform.vectorFloat3Value = disc(framing)
        if let url = frames.last, let decoded = decode(url, crop(framing)) { // the cache, straight away
            frameUniform.textureValue = texture(decoded.image)
            blurUniform.textureValue = SKTexture(cgImage: decoded.blur)
            cropUniform.vectorFloat4Value = crop(framing)
            showing = url
            spots = decoded.spots
            newest = SunImages.date(url)
        }
        turnToNow()
        NotificationCenter.default.addObserver(self, selector: #selector(applyKnobs), name: UserDefaults.didChangeNotification, object: nil)
        run(.repeatForever(.sequence([.wait(forDuration: 1), .run { [weak self] in self?.advance() }])))
    }

    override func didMove(to view: SKView) {
        run(.repeatForever(.sequence([.run { [weak self] in
            guard let self else { return }
            SunImages.shared.poll(wavelength.source, width: width)
        }, .wait(forDuration: 60)])))
    }

    @objc private func applyKnobs() { for (knob, uniform) in knobUniforms { uniform.floatValue = Float(knob.value) } }

    /// Turns both frames to now, runs the crossfade (30 s to a new image, 3 s from the placeholder, none to a new
    /// framing), and the flares and eruptions.
    override func update(_ currentTime: TimeInterval) {
        let dt = frameTime(currentTime, &lastUpdate)
        turnToNow()
        updateEvents(dt)
        guard let next else { return }
        let seconds = next.framing != framing ? 0 : showing == nil ? 3 : 30.0
        progress = seconds > 0 ? min(progress + dt / seconds, 1) : 1
        fadeUniform.floatValue = Float(progress)
        guard progress >= 1 else { return }
        frameUniform.textureValue = nextUniform.textureValue
        blurUniform.textureValue = next.blur
        cropUniform.vectorFloat4Value = next.crop
        discUniform.vectorFloat3Value = disc(next.framing)
        fadeUniform.floatValue = 0
        showing = next.url
        framing = next.framing
        spots = next.spots
        self.next = nil
        busy = false
    }

    /// Counts down to the next flare or eruption while the Sun is alive, and ages the ones under way. A shorter
    /// interval in Settings applies at once.
    private func updateEvents(_ dt: Double) {
        flareUniform.vectorFloat4Value.z += Float(dt)
        eruptionUniform.vectorFloat4Value.y += Float(dt)
        let every = Self.knobs[2].value * 60
        guard alive, every > 29, wavelength.source != 18 else { return } // visible light shows neither
        untilEvent = min(untilEvent - dt, every * 1.5)
        guard untilEvent <= 0 else { return }
        untilEvent = every * .random(in: 0.5...1.5)
        startEvent()
    }

    /// A flare at one of the brightest knots on the disc, today's active regions, or an eruption off the limb, above
    /// one of them if it's near the edge. Both only where the framing shows them.
    private func startEvent() {
        let d = disc(framing)
        func onScreen(_ p: SIMD2<Float>) -> Bool {
            let pts = SIMD2(d.x, d.y) + p * d.z
            return pts.x > 40 && pts.y > 40 && pts.x < Float(size.width) - 40 && pts.y < Float(size.height) - 40
        }
        let forced = UserDefaults.standard.string(forKey: "sun.nextEvent") // "flare" or "eruption", for trying them out
        let knots = spots.filter(onScreen)
        if forced != "eruption", let knot = knots.prefix(4).randomElement(), forced == "flare" || Double.random(in: 0...1) < 0.6 {
            flareUniform.vectorFloat4Value = [knot.x, knot.y, 0, .random(in: 0.6...1)]
            return
        }
        let nearEdge = knots.filter { simd_length($0) > 0.75 }.map { atan2($0.y, $0.x) }
        let limb = (0..<48).map { Float($0) / 48 * 2 * .pi }.filter { onScreen([cos($0), sin($0)]) }
        guard let angle = nearEdge.randomElement() ?? limb.randomElement() else { return }
        eruptionUniform.vectorFloat4Value = [angle, 0, .random(in: 0.7...1), .random(in: 0.14...0.24)]
    }

    /// How long ago each frame was taken, for the shader to turn it on by the Sun's rotation since: to now, or if the
    /// images have gone stale (offline, say), to 4 hours after the newest, so none turns far.
    private func turnToNow() {
        let now = min(Date(), newest.addingTimeInterval(4 * 3600))
        ageUniform.floatValue = showing.map { Float(now.timeIntervalSince(SunImages.date($0)) / 3600) } ?? 0
        ageNextUniform.floatValue = next.map { Float(now.timeIntervalSince(SunImages.date($0.url)) / 3600) } ?? 0
    }

    /// The disc's centre and radius in points: the whole Sun, or a close-up rising off the bottom right.
    private func disc(_ framing: Int) -> SIMD3<Float> {
        let (w, h) = (Float(size.width), Float(size.height))
        return framing == 0 ? [w * 0.5, h * 0.5, h * 0.38] : [w * 0.78, h * -0.35, h * 1.05]
    }

    /// The part of SDO's image a framing shows, with a little room for the shimmer, as x, y, width, height from 0 to 1.
    /// The disc's radius is 0.3895 of the image's width.
    private func crop(_ framing: Int) -> SIMD4<Float> {
        let d = disc(framing), pad: Float = 0.03
        let lo = (SIMD2<Float>(-d.x, -d.y) / d.z - pad) * 0.3895 + 0.5
        let hi = (SIMD2<Float>(Float(size.width) - d.x, Float(size.height) - d.y) / d.z + pad) * 0.3895 + 0.5
        let a = simd_clamp(lo, .zero, .one), b = simd_clamp(hi, .zero, .one)
        return [a.x, a.y, b.x - a.x, b.y - a.y]
    }

    /// Images twice the disc's size on screen (at 2x Retina) come in 4096 pixels, else 2048: the whole Sun on a
    /// laptop is 2048, the close-up 4096.
    private var width: Int { disc(Int(Self.knobs[1].value)).z * 2 > 0.3895 * 2048 * 1.15 ? 4096 : 2048 }

    /// The cached frames at the width the framing wants, or at the other width until those arrive.
    private var frames: [URL] {
        let wanted = SunImages.shared.frames(wavelength.source, width: width)
        return wanted.isEmpty ? SunImages.shared.frames(wavelength.source, width: 6144 - width) : wanted
    }

    /// Starts the next change once the last is done: to a new framing, or to a newer image when one lands.
    private func advance() {
        let frames = frames, framing = Int(Self.knobs[1].value)
        newest = frames.last.map(SunImages.date) ?? Date()
        guard !busy, let target = frames.last, target != showing || framing != self.framing else { return }
        busy = true
        let crop = crop(framing)
        Task { [weak self] in
            let decoded = await Task.detached { decode(target, crop) }.value
            guard let self else { return }
            guard let decoded else { busy = false; return }
            nextUniform.textureValue = texture(decoded.image)
            cropNextUniform.vectorFloat4Value = crop
            progress = 0
            next = (target, crop, framing, SKTexture(cgImage: decoded.blur), decoded.spots)
        }
    }

    /// Stands in until the first image arrives: a dim disc in the wavelength's colour, sized like one of SDO's.
    private func placeholder() -> SKTexture {
        let c = wavelength.source == 18 ? SIMD3<Float>(0.4, 0.4, 0.4) : wavelength.swatch[0] // visible light is tinted in the shader
        return paint(CGSize(width: 128, height: 128)) { ctx in
            ctx.setFillColor(CGColor(red: CGFloat(c.x), green: CGFloat(c.y), blue: CGFloat(c.z), alpha: 1))
            ctx.fillEllipse(in: CGRect(x: 64 - 49.9, y: 64 - 49.9, width: 99.8, height: 99.8))
        }
    }

    private func texture(_ image: CGImage) -> SKTexture {
        let texture = SKTexture(cgImage: image)
        texture.usesMipmaps = true // smooth in the small Settings preview
        return texture
    }

    private static let shader = """
    // SDO's visible-light images come in grey; NASA shows them orange, from red sunspots to a golden centre.
    vec3 visibleLight(float v) {
        vec3 c = vec3(0.62, 0.08, 0.0) * smoothstep(0.0, 0.25, v);
        c = mix(c, vec3(0.91, 0.31, 0.01), smoothstep(0.25, 0.47, v));
        c = mix(c, vec3(0.99, 0.57, 0.0), smoothstep(0.47, 0.75, v));
        return mix(c, vec3(1.0, 0.69, 0.11), smoothstep(0.75, 0.86, v));
    }

    // Where a point on the disc (d, in solar radii) was `hours` earlier, before the Sun's rotation carried it west
    // along its latitude: 13.7° a day at the equator, 10° near the poles (synodic, after Snodgrass and Ulrich 1990),
    // about an axis tipped `tilt` radians toward us. A point that was then round the far side keeps its place.
    vec2 turnBack(vec2 d, float hours, float tilt) {
        float z = sqrt(max(1.0 - dot(d, d), 0.0)), ct = cos(tilt), st = sin(tilt);
        vec3 p = vec3(d.x, d.y * ct + z * st, z * ct - d.y * st); // y along the Sun's axis
        float s2 = p.y * p.y; // sin² of the latitude
        float a = (13.72 - 2.39 * s2 - 1.78 * s2 * s2) * 0.01745 / 24.0 * hours, c = cos(a), s = sin(a);
        p = vec3(p.x * c - p.z * s, p.y, p.z * c + p.x * s);
        return p.y * st + p.z * ct < 0.0 ? d : vec2(p.x, p.y * ct - p.z * st);
    }

    void main() {
        vec2 pts = v_tex_coord * u_size;
        vec2 d = (pts - u_disc.xy) / u_disc.z; // in solar radii
        float r = length(d);
        float life = u_motion * u_life * (1.0 - u_visible); // the ambient motion; visible light has no loops

        // Shimmer: off the disc, the corona flickers very slowly in fine radial streaks, like streamers, that drift
        // outward about a third of a solar radius a minute, and wavers a little. Two layers, so no noise cells show.
        // Alive, it streams out three times as fast and flickers more.
        float s = smoothstep(0.97, 1.1, r) * (1.0 + life * 0.6);
        float drift = u_now * (1.0 + life * 2.0);
        vec2 dir = d / max(r, 0.001);
        d *= 1.0 + s * 0.01 * (noise(dir * 5.0 + vec2(3.0, r * 2.0 - drift * 0.012)) - 0.5);
        float streaks = noise(dir * 18.0 + vec2(0.0, r * 2.5 - drift * 0.015)) * 0.6
                      + noise(dir * 9.0 + vec2(7.0, r * 1.5 - drift * 0.01)) * 0.4 - 0.5;

        // The images end 1.28 radii out, so past 1.2 the corona carries on from there, fading as it does in 193
        // (by e every 0.07 radii): streamers smeared radially, which is how they run. Each frame is turned on to now.
        vec2 dNow = d * min(1.0, 1.2 / r);
        vec2 uv = 0.5 + (r < 1.0 ? turnBack(d, u_age, u_tilt) : dNow) * 0.3895; // the disc's radius is 0.3895 of the image
        vec2 uvNext = 0.5 + (r < 1.0 ? turnBack(d, u_ageNext, u_tilt) : dNow) * 0.3895;
        vec2 tc = (uv - u_crop.xy) / u_crop.zw;
        vec3 col = mix(texture2D(u_frame, tc).rgb, texture2D(u_next, (uvNext - u_cropNext.xy) / u_cropNext.zw).rgb, u_fade);
        col *= 1.0 + s * 0.35 * streaks;

        // Alive: plasma pulses out along the bright loops, away from the active regions' cores, and the regions
        // flicker. A blurred copy (`u_blur`, 16 times smaller) finds the cores: its slope points the flow downhill,
        // and whatever is brighter than it is a loop.
        if (life > 0.0 && r < 1.3) {
            vec3 w = vec3(0.2126, 0.7152, 0.0722);
            vec2 e = vec2(0.012) / u_crop.zw; // 0.03 solar radii
            float blur = texture2D(u_blur, tc).r;
            vec2 slope = vec2(texture2D(u_blur, tc + vec2(e.x, 0.0)).r - texture2D(u_blur, tc - vec2(e.x, 0.0)).r,
                              texture2D(u_blur, tc + vec2(0.0, e.y)).r - texture2D(u_blur, tc - vec2(0.0, e.y)).r);
            vec2 away = -slope / (length(slope) + 0.0001);
            float loop = smoothstep(0.02, 0.2, dot(col, w) - blur) * smoothstep(0.01, 0.06, length(slope));
            float pulse = noise(vec2(dot(d, away) * 60.0 - u_now * 0.5, dot(d, vec2(-away.y, away.x)) * 22.0));
            float flicker = noise(d * 9.0 + vec2(u_now * 0.04, 3.0));
            col *= 1.0 + life * (0.6 * loop * (pulse - 0.45) + 0.3 * smoothstep(0.15, 0.45, blur) * (flicker - 0.5));
        }

        // A flare (u_flare: x, y, seconds, strength): the loops there flash within seconds and fade over a minute,
        // with a soft bloom, AIA's diagonal diffraction cross at the peak, and a faint wave spreading over the disc.
        float fa = u_flare.z;
        float flare = u_flare.w * (1.0 - exp(-fa / 3.0)) * exp(-fa / 35.0);
        vec2 fd = d - u_flare.xy;
        float f2 = dot(fd, fd);
        col *= 1.0 + flare * 3.0 * exp(-f2 / 0.004);
        col += u_hot * flare * (0.3 * exp(-f2 / 0.01) + 0.08 * exp(-f2 / 0.12));
        vec2 x = vec2(fd.x + fd.y, fd.x - fd.y) * 0.7071;
        col += u_hot * flare * flare * 0.25 * (exp(-abs(x.x) * 300.0 - abs(x.y) * 5.0) + exp(-abs(x.y) * 300.0 - abs(x.x) * 5.0));
        col *= 1.0 + 0.15 * u_flare.w * exp(-pow((sqrt(f2) - 0.012 * fa) / 0.03, 2.0)) * exp(-fa / 25.0) * step(r, 1.0);

        // An eruption (u_eruption: angle round the limb, seconds, strength, size): an arch of plasma, its feet on the
        // limb, swells, then lifts away faster and faster, a ragged tube of threads running along it, and fades over
        // about two minutes. It's coloured through the channel's own table, dark to mid to hot as it brightens.
        float ea = u_eruption.y;
        if (u_eruption.z > 0.0 && ea < 240.0) { // only while one is under way: the threads' fbm is the costly part
            vec2 n = vec2(cos(u_eruption.x), sin(u_eruption.x));
            vec2 q = vec2(dot(d - n, vec2(-n.y, n.x)), dot(d - n, n)); // across, and height above the limb
            float size = u_eruption.w * (1.0 + 0.006 * ea), top = size * 0.8 + 0.003 * ea + 0.00008 * ea * ea;
            q += (vec2(noise(q * 3.0 / size + 3.1), noise(q * 3.0 / size + 7.7)) - 0.5) * size * 0.12; // a ragged outline
            vec2 arch = vec2(q.x / size, q.y / top);
            float along = atan(arch.y, arch.x), ring = length(arch) - 1.0; // along: 0 at one foot to π at the other
            float thick = 0.16 + 0.16 * noise(vec2(along * 2.5, u_eruption.x * 3.0));
            float threads = fbm(vec2(along * 3.0 + u_eruption.x * 5.0, ring * 18.0 - ea * 0.01));
            float g = (exp(-ring * ring / (thick * thick)) * (0.5 + 2.5 * threads * threads) + 0.3 * exp(-ring * ring * 4.0)) * step(0.0, q.y)
                    * u_eruption.z * smoothstep(0.0, 12.0, ea) * exp(-ea / 60.0) * smoothstep(0.99, 1.03, r);
            float c = min(g * 0.7, 1.0); // mostly mid: only the densest threads reach the table's hot end
            col += (c < 0.5 ? mix(u_lo, u_mid, c * 2.0) : mix(u_mid, u_hot, c * 2.0 - 1.0)) * min(g, 1.2);
        }

        if (u_visible > 0.5) { col = visibleLight(dot(col, vec3(0.3333))); }
        col *= exp(-max(r - 1.2, 0.0) * 14.0);

        col = grade(col, 0.3, u_hue, u_saturation, u_contrast, u_brightness);
        col += (hash21(pts * 2.0) - 0.5) / 128.0;
        gl_FragColor = vec4(col, 1.0);
    }
    """
}

/// Decodes the part of an image file given by `crop` (x, y, width, height from 0 to 1, from the bottom left) into a
/// bitmap of its own, off the main thread, so the first frame drawn with it doesn't stall and the rest of a 4096-pixel
/// image isn't kept. Also makes a grey copy of that part 16 times smaller, which drawn with linear filtering is a blur,
/// and finds the brightest knots on the disc, today's active regions, brightest first, in solar radii from its
/// centre: local maxima in a 48-pixel copy, where the disc is 19 pixels across its radius.
nonisolated func decode(_ url: URL, _ crop: SIMD4<Float>) -> (image: CGImage, blur: CGImage, spots: [SIMD2<Float>])? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
    let (w, h) = (CGFloat(image.width), CGFloat(image.height))
    let rect = CGRect(x: CGFloat(crop.x) * w, y: CGFloat(crop.y) * h, width: CGFloat(crop.z) * w, height: CGFloat(crop.w) * h)
    guard let context = CGContext(data: nil, width: Int(rect.width), height: Int(rect.height), bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue),
          let small = CGContext(data: nil, width: 48, height: 48, bitsPerComponent: 8, bytesPerRow: 48,
                                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
    else { return nil }
    context.draw(image, in: CGRect(x: -rect.minX, y: -rect.minY, width: w, height: h))
    small.interpolationQuality = .medium
    small.draw(image, in: CGRect(x: 0, y: 0, width: 48, height: 48))
    let v = UnsafeBufferPointer(start: small.data!.assumingMemoryBound(to: UInt8.self), count: 48 * 48) // top row first
    var knots: [(p: SIMD2<Float>, v: UInt8)] = []
    for y in 1..<47 {
        for x in 1..<47 where (-1...1).allSatisfy({ dy in (-1...1).allSatisfy { dx in v[(y + dy) * 48 + x + dx] <= v[y * 48 + x] } }) {
            let p = SIMD2<Float>((Float(x) + 0.5) / 48 - 0.5, 0.5 - (Float(y) + 0.5) / 48) / 0.3895
            if simd_length(p) < 0.97 { knots.append((p, v[y * 48 + x])) }
        }
    }
    guard let cropped = context.makeImage(),
          let blur = CGContext(data: nil, width: max(Int(rect.width) / 16, 1), height: max(Int(rect.height) / 16, 1), bitsPerComponent: 8,
                               bytesPerRow: 0, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
    blur.interpolationQuality = .high
    blur.draw(cropped, in: CGRect(x: 0, y: 0, width: blur.width, height: blur.height))
    return (cropped, blur.makeImage()!, knots.sorted { $0.v > $1.v }.prefix(8).map(\.p))
}

/// The Sun's B0 angle in radians: how far its north pole tips toward us, from +7.25° in early September to −7.25° in
/// early March, from the Sun's ecliptic longitude and the node of its equator (Meeus, Astronomical Algorithms, ch. 29).
nonisolated func sunTilt(at date: Date) -> Float {
    let days = date.timeIntervalSince1970 / 86400 - 10957.5, rad = Double.pi / 180 // days since J2000
    let anomaly = (357.528 + 0.9856003 * days) * rad
    let longitude = (280.46 + 0.9856474 * days + 1.915 * sin(anomaly) + 0.02 * sin(2 * anomaly)) * rad
    let node = (75.76 + 1.397 * days / 36525) * rad
    return Float(asin(sin(longitude - node) * sin(7.25 * rad)))
}

/// Full-disc images of the Sun from NASA's Solar Dynamics Observatory, through the ESA/NASA Helioviewer Project's API:
/// 2048 or 4096 pixels square, in SDO's standard colours and without captions. AIA's are about 50 minutes behind real time,
/// HMI's visible light 2–3 hours. SDO's own "latest" JPEGs carry a caption, and since 21 September 2026 a fault in
/// SDO's data storage has frozen them. Frames are cached on disk as `sun/<width>/<source>-<unix time>.jpg`, so the
/// last ones show at once and offline.
@MainActor final class SunImages {
    static let shared = SunImages()

    private let folder = URL.cachesDirectory.appending(path: "com.dtanquary.atrium/sun")
    private let api = "https://api.helioviewer.org/v2/"
    private var lastCheck: [String: Date] = [:]

    /// A channel's cached frames at a width, oldest first.
    func frames(_ source: Int, width: Int) -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: folder.appending(path: "\(width)"), includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("\(source)-") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent } // unix times keep 10 digits until 2286
    }

    /// Fetches a channel's newest frame, at most every 15 minutes however many displays ask (about SDO's own
    /// cadence), or 30 for 4096-pixel images, which run 1–2 MB. Images never change once published, so a frame it
    /// has is never fetched again. It keeps the newest two, one to show and one another display may still be fading
    /// from. Failures are silent and leave the cache as it was.
    func poll(_ source: Int, width: Int) {
        let key = "\(source) \(width)"
        guard Date().timeIntervalSince(lastCheck[key] ?? .distantPast) > Double(width) / 2048 * 900 else { return }
        lastCheck[key] = Date()
        Task {
            guard let newest = await closest(source, to: Date()), await download(newest, source, width) else { return }
            for url in frames(source, width: width).dropLast(2) { try? FileManager.default.removeItem(at: url) }
        }
    }

    /// The frame nearest a time: its id and when it was taken.
    private func closest(_ source: Int, to time: Date) async -> (id: String, date: Date)? {
        guard let url = URL(string: api + "getClosestImage/?date=\(time.ISO8601Format())&sourceId=\(source)"),
              let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return Self.frame(data)
    }

    /// Reads a `getClosestImage` reply: the image's id, and when it was taken from its date in UTC.
    nonisolated static func frame(_ reply: Data) -> (id: String, date: Date)? {
        guard let json = try? JSONSerialization.jsonObject(with: reply) as? [String: Any],
              let id = json["id"] as? String, let stamp = json["date"] as? String, // "2026-09-27 01:08:45"
              let date = try? Date(stamp.replacingOccurrences(of: " ", with: "T") + "Z", strategy: .iso8601) else { return nil }
        return (id, date)
    }

    /// Saves a frame unless it's already cached; false if it couldn't be.
    private func download(_ frame: (id: String, date: Date), _ source: Int, _ width: Int) async -> Bool {
        let file = folder.appending(path: "\(width)/\(source)-\(Int(frame.date.timeIntervalSince1970)).jpg")
        if FileManager.default.fileExists(atPath: file.path) { return true }
        guard let url = URL(string: api + "downloadImage/?id=\(frame.id)&width=\(width)&type=jpg"),
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200, NSImage(data: data) != nil else { return false }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        return (try? data.write(to: file, options: .atomic)) != nil
    }

    /// When a cached frame was taken, from its name.
    nonisolated static func date(_ url: URL) -> Date {
        Date(timeIntervalSince1970: Double(url.deletingPathExtension().lastPathComponent.split(separator: "-").last ?? "") ?? 0)
    }
}
