import SpriteKit

@MainActor func galaxy(size: CGSize) -> SKScene { Galaxy(size: size) }

/// A spiral galaxy turning slowly in deep space. Each load rolls one after a real galaxy (or the kind pinned in
/// Settings) with its own tilt, orientation, spin and star field. Its arms are logarithmic spirals made of star
/// clouds, with dust lanes along their inner edges and pink star-forming knots just past them, around a glowing
/// bulge and, for barred kinds, a bar. The disc's own stars sparkle as it turns. Left running, it dissolves into
/// a new galaxy every few minutes.
final class Galaxy: SKScene {
    nonisolated static let rotation = Knob(key: "galaxy.rotation", label: "Rotation speed", range: 0...4, standard: 1,
                                           section: "Motion")
    nonisolated static let cycleMinutes = Knob(key: "galaxy.cycleMinutes", label: "New galaxy every", range: 0...30,
                                               standard: 10, section: "Colors", format: .minutes)
    nonisolated static let knobs = [
        Knob(key: "galaxy.brightness", label: "Brightness", range: 0.4...1.8, standard: 1, section: "Look"),
        Knob(key: "galaxy.dust", label: "Dust", range: 0...2, standard: 1, section: "Look"),
        rotation, cycleMinutes,
    ]

    /// Kinds of spiral, each after a real galaxy: how many arms and how strong every other one is (below 1 for minor
    /// arms between the major ones), their pitch angle in degrees, the bar's length and
    /// the bulge's size (in disc radii, 0 for no bar), how ragged the arms are (0 grand design, 1 flocculent), dust,
    /// the tilt range in degrees from face-on (around the real one), and colours: bulge, old disc stars, young arm
    /// stars, and the hydrogen-alpha pink of H II regions. The colours were sampled from ESA/Hubble, ESO and NASA
    /// portraits (M51 heic0506a, M101 heic0602a, M31, NGC 1300 heic0501a, M33 eso1424a) as the stretch shows them.
    nonisolated static let kinds: [(name: String, arms: Float, minor: Float, pitch: Float, bar: Float, bulge: Float,
                                    ragged: Float, dust: Float, tilt: ClosedRange<Float>, colours: [SIMD3<Float>])] = [
        ("Whirlpool", 2, 1, 19, 0, 0.05, 0.2, 1.3, 15...25,        // M51 (i ≈ 20°): the classic grand design, strung with H II
         [[1.0, 0.91, 0.80], [0.94, 0.90, 0.87], [0.72, 0.86, 1.0], [1.0, 0.42, 0.50]]),
        ("Pinwheel", 4, 1, 27, 0, 0.03, 0.55, 0.8, 10...25,        // M101 (i ≈ 18°): face-on, many open, lopsided arms
         [[1.0, 0.93, 0.86], [0.95, 0.93, 0.93], [0.70, 0.82, 1.0], [1.0, 0.50, 0.60]]),
        ("Andromeda", 2, 1, 8, 0, 0.13, 0.5, 1.2, 72...77,         // M31 (i ≈ 77°): cream bulge, dusty arms, mauve outskirts
         [[1.0, 0.90, 0.78], [0.86, 0.78, 0.86], [0.74, 0.76, 1.0], [1.0, 0.50, 0.70]]),
        ("Milky Way", 4, 0.45, 13, 0.28, 0.09, 0.3, 1.2, 0...35, // ours, from outside: a short bar, two major arms off
                                                                  // its ends (Scutum-Centaurus, Perseus), two minor between
         [[1.0, 0.90, 0.76], [0.92, 0.88, 0.84], [0.72, 0.84, 1.0], [1.0, 0.45, 0.55]]),
        ("Great Barred", 2, 1, 17, 0.45, 0.05, 0.1, 1.0, 40...50,  // NGC 1300 (i ≈ 50°): a long bar with open arms off its ends
         [[1.0, 0.90, 0.84], [0.93, 0.90, 0.97], [0.72, 0.84, 1.0], [1.0, 0.50, 0.60]]),
        ("Triangulum", 2, 1, 30, 0, 0.015, 0.9, 0.6, 50...56,      // M33 (i ≈ 55°): a flocculent patchwork, rich in H II
         [[1.0, 0.96, 0.90], [0.88, 0.90, 1.0], [0.74, 0.86, 1.0], [1.0, 0.50, 0.56]]),
    ]

    /// Companion galaxies seen beside some kinds, as in their photos: position along and across the major axis in
    /// galaxy radii, radius, brightness, and how round (1) or flattened it looks. M51 has NGC 5195 off the end of an
    /// arm, partly behind it; M31 has compact M32 just off its disc and the larger, fainter M110 further out.
    nonisolated static let companions: [String: [(at: SIMD2<Float>, radius: Float, brightness: Float, round: Float)]] = [
        "Whirlpool": [([1.15, 0.4], 0.12, 1.1, 0.85)],
        "Andromeda": [([0.12, -0.5], 0.025, 1.5, 0.8), ([-0.3, 0.85], 0.1, 0.25, 0.5)],
    ]

    private let knobUniforms: [String: SKUniform]
    private let phase = SKUniform(name: "u_phase", float: 0)
    private var turnRate = 1.0
    private var lastUpdate: TimeInterval?
    private var scheduledCycle: Double?

    override init(size: CGSize) {
        knobUniforms = Dictionary(uniqueKeysWithValues: Self.knobs.map {
            ($0.key, SKUniform(name: "u_" + $0.key.split(separator: ".").last!, float: Float($0.standard)))
        })
        super.init(size: size)
        let kind = Self.kinds.first { $0.name == UserDefaults.standard.string(forKey: "galaxy.kind") } ?? Self.kinds.randomElement()!
        let tilt = cos(Float.random(in: kind.tilt) * .pi / 180)
        // Tilted galaxies lie near level so they fit the screen; face-on ones can point any way.
        let angle = Float.random(in: -1...1) * (0.4 + (.pi - 0.4) * tilt * tilt * tilt) + (Bool.random() ? .pi : 0)
        let aspect = Float(size.width / size.height)

        let sprite = SKSpriteNode(color: .black, size: size)
        sprite.anchorPoint = .zero
        sprite.shader = SKShader(source: shaderCommon + Self.source, uniforms: [
            SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)]),
            SKUniform(name: "u_seed", vectorFloat2: [.random(in: 0...100), .random(in: 0...100)]),
            SKUniform(name: "u_centre", vectorFloat2: [aspect * .random(in: 0.44...0.56), .random(in: 0.46...0.54)]),
            SKUniform(name: "u_radius", float: .random(in: 0.36...0.44)),
            SKUniform(name: "u_pa", vectorFloat2: [cos(angle), sin(angle)]),
            SKUniform(name: "u_tilt", float: tilt),
            SKUniform(name: "u_spin", float: Bool.random() ? 1 : -1),
            SKUniform(name: "u_shape", vectorFloat4: [kind.arms, 1 / tan(kind.pitch * .pi / 180), kind.bar, kind.bulge]),
            SKUniform(name: "u_arms", vectorFloat3: [kind.ragged, kind.dust, kind.minor]),
            SKUniform(name: "u_core", vectorFloat3: kind.colours[0]), SKUniform(name: "u_disc", vectorFloat3: kind.colours[1]),
            SKUniform(name: "u_young", vectorFloat3: kind.colours[2]), SKUniform(name: "u_knots", vectorFloat3: kind.colours[3]),
            phase,
        ] + companionUniforms(kind.name) + Array(knobUniforms.values))
        addChild(sprite)

        applySettings()
        NotificationCenter.default.addObserver(self, selector: #selector(applySettings),
                                               name: UserDefaults.didChangeNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Two companion slots for the shader, (x, y, radius, brightness) and roundness; an empty slot has no brightness.
    private func companionUniforms(_ kind: String) -> [SKUniform] {
        let found = Self.companions[kind] ?? []
        return (0..<2).flatMap { (i: Int) -> [SKUniform] in
            let c = i < found.count ? found[i] : (at: SIMD2<Float>(0, 0), radius: Float(1), brightness: Float(0), round: Float(1))
            return [SKUniform(name: "u_comp\(i)", vectorFloat4: [c.at.x, c.at.y, c.radius, c.brightness]),
                    SKUniform(name: "u_round\(i)", float: c.round)]
        }
    }

    override func update(_ currentTime: TimeInterval) {
        defer { lastUpdate = currentTime }
        guard let last = lastUpdate else { return }
        // One turn every 12 minutes at speed 1. Integrated, so moving the slider never makes it jump.
        // ponytail: the disc turns as one piece; real discs shear (inner parts faster), which would wind the
        // pattern up forever unless blended between two phases, flow-map style

        let step = min(max(currentTime - last, 0), 0.5) * 2 * .pi / 720 * turnRate
        phase.floatValue = Float((Double(phase.floatValue) + step).truncatingRemainder(dividingBy: 2 * .pi))
    }

    /// Pushes the Settings sliders into the shader, and (re)schedules the next galaxy when its timing changes.
    @objc private func applySettings() {
        for knob in Self.knobs { knobUniforms[knob.key]?.floatValue = Float(knob.value) }
        turnRate = Self.rotation.value
        let pinned = !(UserDefaults.standard.string(forKey: "galaxy.kind") ?? "").isEmpty
        let minutes = pinned ? 0 : Self.cycleMinutes.value.rounded()
        guard minutes != scheduledCycle else { return }
        scheduledCycle = minutes
        removeAction(forKey: "cycle")
        guard minutes > 0 else { return }
        run(.sequence([.wait(forDuration: minutes * 60), .run { [weak self] in self?.handOver() }]), withKey: "cycle")
    }

    /// Dissolves into a newly rolled galaxy with both still turning, so there's never a cut.
    // ponytail: the dissolve renders both galaxies, about double the GPU cost while it lasts
    private func handOver() {
        let fade = SKTransition.crossFade(withDuration: 90)
        fade.pausesIncomingScene = false
        fade.pausesOutgoingScene = false
        view?.presentScene(Galaxy(size: size), transition: fade)
    }

    private static let source = """
    // v turned anticlockwise by a.
    vec2 turn(vec2 v, float a) {
        float c = cos(a);
        float s = sin(a);
        return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
    }

    // One layer of background stars on a grid turned by `a`, so layers of different sizes never line up into a
    // lattice, kept where `keep` allows. Mostly faint: only the big, sparse layers hold bright stars, with a soft halo.
    // Colours run from orange dwarfs through white to blue giants.
    vec3 starLayer(vec2 pts, float cell, mat2 a, float keep, float t) {
        vec2 q = a * pts / cell;
        vec4 h = hash42(floor(q));
        if (h.x > keep) { return vec3(0.0); }
        vec4 k = hash42(floor(q) + 57.0);
        vec2 d = (fract(q) - 0.5 - (h.yz - 0.5) * 0.7) * cell;
        float mag = pow(h.w, 6.0) * min(cell / 17.0, 1.0);
        float r = 0.4 + 1.1 * mag;
        float glow = exp(-dot(d, d) / (r * r)) + 0.3 * mag * exp(-length(d) / (0.06 * cell));
        float twinkle = 0.88 + 0.12 * sin(t * (0.6 + 2.0 * k.x) + k.y * 40.0);
        vec3 tint = mix(mix(vec3(0.72, 0.82, 1.0), vec3(1.0, 0.97, 0.94), smoothstep(0.0, 0.3, k.z)),
                        vec3(1.0, 0.72, 0.5), smoothstep(0.55, 1.0, k.z));
        return tint * glow * (0.12 + 2.0 * mag) * twinkle;
    }

    // A faint, far-off galaxy: a tiny tilted smudge in about one cell in eight.
    float farGalaxy(vec2 pts, float cell) {
        vec2 id = floor(pts / cell);
        vec4 h = hash42(id + 71.0);
        if (h.x > 0.12) { return 0.0; }
        vec4 k = hash42(id + 13.0);
        vec2 d = turn((fract(pts / cell) - 0.5 - (h.yz - 0.5) * 0.6) * cell, k.x * 6.28);
        d.y /= 0.2 + 0.8 * k.y;
        float l = length(d) / (1.0 + 2.5 * h.w);
        return 0.12 * exp(-l * l) + 0.04 * exp(-l * 1.5);
    }

    // One star per cell of the turning disc, kept with probability `keep`, drawn as a round point on screen about
    // 1.5 px across, like the photos' resolved stars: `m` takes a step in the disc to screen points. It can sit
    // almost anywhere in its cell, so the stars never line up into a grid. Returns (brightness, a random number
    // for its colour).
    vec2 discStar(vec2 g, float cell, float seed, float keep, mat2 m) {
        vec4 h = hash42(floor(g / cell) + seed);
        if (h.x > keep) { return vec2(0.0); }
        float d = length(m * ((fract(g / cell) - 0.5 - (h.yz - 0.5) * 0.8) * cell));
        float mag = pow(h.w, 2.5);
        return vec2(exp(-d * d * (4.5 - 2.5 * mag)) * (0.3 + 1.6 * mag), h.x / max(keep, 0.0001)); // h.x is uniform below keep
    }

    // A star-forming knot, glowing hydrogen around the young cluster that lights it, in a cell where `keep` allows,
    // round on screen like discStar; 0.8 to 3.2 points across, mostly small, so it stays inside its cell rather
    // than showing as a clipped half-moon. Returns (glow, cluster).
    vec2 knot(vec2 g, float cell, float keep, mat2 m) {
        vec4 h = hash42(floor(g / cell) + 41.0);
        if (h.x > keep) { return vec2(0.0); }
        float l = length(m * ((fract(g / cell) - 0.5 - (h.yz - 0.5) * 0.3) * cell)) / (0.8 + 2.4 * pow(h.w, 3.0));
        return vec2(exp(-l * l * 2.0), exp(-l * l * 8.0)) * (0.3 + 0.7 * h.x / max(keep, 0.0001));
    }

    // An elliptical companion galaxy: a broad, smooth cloud of old stars with a small bright middle. `o` is (x, y,
    // radius, brightness) along and across the major axis, in galaxy radii; `round` flattens it across.
    float companion(vec2 e, vec4 o, float round) {
        vec2 v = e - o.xy;
        float rc = length(vec2(v.x, v.y / round)) / max(o.z, 0.001);
        return o.w * (exp(-2.5 * rc) + 0.6 * exp(-rc * rc * 30.0));
    }

    // shaderCommon's fbm cut to its first three octaves, the same ones, for bending the arms: the two finest only
    // added sub-pixel wiggles, for two noise lookups a pixel. Their average (0.047) is added back so arms don't shift.
    float fbm3(vec2 p) {
        vec2 p1 = p * 2.03 + vec2(1.7, 9.2);
        return 0.5 * noise(p) + 0.25 * noise(p1) + 0.125 * noise(p1 * 2.03 + vec2(1.7, 9.2)) + 0.047;
    }

    // fbm and a ridged multifractal from the same five noise samples, octaves turned so the value-noise grid never
    // lines up. Returns (fbm, ridges): the ridges are thin, connected filaments, 0 to about 1.
    vec2 fbmRidge(vec2 p) {
        float v = 0.0;
        float ridges = 0.0;
        float a = 0.5;
        float w = 1.0;
        for (int i = 0; i < 5; i++) {
            float n = noise(p);
            v += a * n;
            float rr = 1.0 - abs(2.0 * n - 1.0);
            rr *= rr;
            ridges += a * rr * w;
            w = clamp(rr * 2.0, 0.0, 1.0);
            p = mat2(1.6, 1.2, -1.2, 1.6) * p + vec2(1.7, 9.2);
            a *= 0.5;
        }
        return vec2(v, ridges);
    }

    void main() {
        float aspect = u_size.x / u_size.y;
        vec2 p = v_tex_coord * vec2(aspect, 1.0);
        vec2 pts = v_tex_coord * u_size + u_seed * 97.0; // the seed moves the star field too

        // Behind it all, seen through the disc: stars in two layers of different sizes and angles, bunched into
        // loose clusters and thinner patches, and far-off galaxies.
        float crowd = 0.25 + 1.5 * smoothstep(0.2, 0.8, noise(pts / 160.0));
        vec3 col = vec3(0.031, 0.035, 0.043) // a Hubble frame's sky sits at 4-27/255, not black
                 + starLayer(pts, 5.0, mat2(1.0, 0.0, 0.0, 1.0), 0.16 * crowd, u_time)
                 + starLayer(pts, 17.0, mat2(0.76, 0.64, -0.64, 0.76), 0.3 * crowd, u_time)
                 + vec3(1.0, 0.9, 0.8) * farGalaxy(pts, 110.0);

        // Screen to galaxy: e runs along the major axis, and undoing the tilt gives d in the disc's plane (mirrored
        // for clockwise spin), in galaxy radii. g turns with the disc, so the pattern stands still in it.
        vec2 c = (p - u_centre) / u_radius;
        vec2 e = vec2(u_pa.x * c.x + u_pa.y * c.y, u_pa.x * c.y - u_pa.y * c.x);
        vec2 d = vec2(e.x, e.y * u_spin / u_tilt);
        float r = length(d);
        // the disc has a little thickness, so steep tilts fade to a soft ellipse instead of a sharp one
        float rt = length(vec2(e.x, e.y / sqrt(u_tilt * u_tilt + 0.0225 * (1.0 - u_tilt * u_tilt))));
        vec3 light = vec3(0.0);
        vec3 absorb = vec3(1.0);
        vec3 vivid = vec3(0.0); // H II light added after the stretch
        // A steeply tilted galaxy also has a rounder glow around it (below), so it gets a rounder region to draw in.
        float rh = length(vec2(e.x, e.y / mix(u_tilt, 1.0, 0.3)));
        if ((u_tilt < 0.5 ? rh : rt) < 1.6) { // everything fades out by here; beyond it there's only sky
            vec2 g = turn(d, -u_phase);
            float arms = u_shape.x;
            float bar = u_shape.z;
            float bulgeR = u_shape.w;
            float ragged = u_arms.x;
            float r0 = max(bar, bulgeR * 1.6); // the arms start at the bar's ends, or the bulge's edge
            float los = min(1.0 / u_tilt, 4.5); // light's path through the disc grows with tilt
            // Tilted past about 60°, the disc's squashed so hard that arm edges and dust lanes turn razor-thin on
            // screen, where the real one (M31) is a soft glow: its disc is thick and its arms smear together.
            // `steep` softens arms, lanes and filaments and adds a thick-disc glow, for such kinds only.
            float steep = smoothstep(0.5, 0.25, u_tilt);

            // Swirled space: turning each radius by its log winds straight rays into logarithmic spirals, so the arms
            // are rays here and noise sampled here is sheared along them into streaks and lanes. The dust noise gets
            // a swirl wound no tighter than a 45° pitch, so its texture is stretched no more than about 2:1, as in the
            // photos, instead of into brushed streaks (8:1 at M51's 19°, 47:1 at M31's 8°).
            float lr = log(max(r, r0 * 0.35) / r0);
            vec2 q = turn(g, lr * u_shape.y);
            vec2 qn = turn(g, lr * min(u_shape.y, 1.0));
            float warp = fbm3(q * 2.2 + u_seed) - 0.5;
            float aq = atan(q.y, q.x);
            float ph = arms * aq + warp * (2.0 + 5.0 * ragged);
            // Each arm has its own strength, so the pattern is lopsided like real ones. Stars stream through the arms
            // the way the disc turns: gas piles up into dust on the arm's inner edge, new stars light hydrogen pink
            // right beside it, and the young blue stars run just past the crest.
            // Every other arm is a minor one for kinds like the Milky Way.
            float armN = mod(floor(ph / 6.2832 + 0.5), arms);
            float armAmp = (0.6 + 0.4 * hash21(vec2(armN, u_seed.x))) * mix(1.0, u_arms.z, mod(armN, 2.0));
            float soft = mix(1.0, 0.4, steep);
            float crest = pow(0.5 + 0.5 * cos(ph), (4.0 - 2.0 * ragged) * soft) * armAmp;
            float young = pow(0.5 + 0.5 * cos(ph - 0.35), 8.0 * soft) * armAmp;
            float hii = pow(0.5 + 0.5 * cos(ph + 0.2), 10.0 * soft) * armAmp;
            // Ragged arms break up. Flocculent kinds (M33) go further, to a patchwork of short arm segments: noise in
            // swirled space is already sheared into spiral streaks, so its peaks make them, and young stars and H II
            // regions follow the patches instead of whole arms.
            float n5 = noise(q * 5.0 + u_seed.yx);
            float floc = ragged * ragged;
            crest *= mix(1.0, smoothstep(0.3, 0.7, n5), ragged);
            if (floc > 0.1) { // only ragged kinds pay for the patchwork
                float patches = smoothstep(0.45, 0.8, n5 * 0.6 + noise(q * 11.0 - u_seed) * 0.4) * armAmp;
                crest = mix(crest, max(crest * 0.35, patches), floc);
                young = mix(young, patches, floc);
                hii = mix(hii, patches, floc);
            }
            // star clouds: lumpy in the disc itself, not swirled, so the arms read as clusters rather than brush strokes
            float lumps = noise(g * 16.0 + u_seed) * 0.5 + noise(mat2(0.8, 0.6, -0.6, 0.8) * g * 47.0 - u_seed) * 0.5;
            float clump = smoothstep(0.2, 0.9, lumps);

            // Light comes from a smooth exponential disc that the arms brighten two to three times over, as in Hubble
            // images, not from arms on a dark disc. That soft, bright disc with no edge is what reads as a photograph.
            float inArms = smoothstep(r0 * 0.8, r0 * 1.5, r) * mix(1.0, smoothstep(1.25, 0.9, r), steep); // no bright rim
            float disc = exp(-rt / 0.4) * smoothstep(1.4, 0.85, rt); // photos drop off faster from about 3/4 of the way out
            float arm = crest * inArms * (0.5 + 0.9 * clump);

            // Dust: narrow broken lanes on the arms' inner edges, feathers leaving them at a pitch 35° steeper, a web of
            // thin filaments everywhere down to the nucleus, and for barred kinds, lanes along the bar's leading edges.
            vec2 fr = fbmRidge(qn * 6.0 + u_seed * 1.3 + 3.0);
            float dt = fr.x;
            float lp = ph + 0.45 + (dt - 0.5) * 2.5;
            float lc = 0.5 + 0.5 * cos(lp);
            float along = lc > 0.6 ? noise(qn * 40.0 + u_seed) : 0.5; // only matters near a lane
            float lane = pow(lc, 14.0 * mix(1.0, 0.7, steep)) * smoothstep(0.25, 0.8, lumps + dt - 0.5)
                       * mix(0.45, 1.0, smoothstep(0.3, 0.7, along)); // thicker and thinner along its length
            // Inside that faint band, the photos' lanes have narrow dark cores, 3–8 px wide, set by distance in the
            // disc rather than by phase, and broken into pieces along the lane (unbroken, they read as ink cracks).
            // They're widened on steep tilts, which would otherwise squash them to hairlines.
            float perp = r / arms / sqrt(1.0 + u_shape.y * u_shape.y); // disc radii across the arm per radian of phase
            float lw = (0.004 + 0.006 * lumps) * (1.0 + 1.5 * steep);
            float l1 = (lp - 6.2832 * floor(lp / 6.2832 + 0.5)) * perp / lw;
            float core = exp(-l1 * l1) * smoothstep(0.3, 0.7, along) * smoothstep(0.25, 0.8, lumps + dt - 0.5);
            float tp = 1.0 / u_shape.y;              // tan(pitch)
            float kf = (1.0 - tp * 0.7) / (tp + 0.7); // cot(pitch + 35°)
            float fu = 18.0 * (aq - (u_shape.y - kf) * lr) / 6.2832 + (dt - 0.5) * 0.8;
            float phw = ph - 6.2832 * floor(ph / 6.2832 + 0.5);
            float feather = pow(0.5 + 0.5 * cos(6.2832 * fu), 8.0) * step(0.45, hash21(vec2(mod(floor(fu + 0.5), 18.0), u_seed.y)))
                          * smoothstep(-1.8, -0.3, phw) * smoothstep(0.7, 0.4, phw) * smoothstep(0.3, 0.55, dt);
            float web = smoothstep(0.25, 0.7, fr.y) * mix(1.0, 0.4, steep); // the 45° swirl thins it, so a lower threshold
            float ax = abs(g.x) / max(bar, 0.001);
            float barY = (g.y - sign(g.x) * bar * (0.1 + 0.15 * ax * ax)) / (0.02 + 0.02 * dt);
            float barLane = step(0.001, bar) * exp(-barY * barY) * smoothstep(0.1, 0.35, ax) * smoothstep(1.1, 0.8, ax) * smoothstep(0.3, 0.6, dt + 0.2);
            float barZone = mix(1.0, smoothstep(bar * 0.7, bar * 1.1, r), step(0.001, bar)); // only its own lanes
            float dust = ((lane * 0.7 + core * 0.8) * (1.0 - 0.7 * floc) + feather * 0.7 * (1.0 - ragged)) * smoothstep(r0 * 0.5, r0 * 0.95, r)
                       + barLane * 0.9 + web * (0.25 + 0.9 * crest) * smoothstep(0.015, 0.06, r) * barZone;
            dust *= smoothstep(1.3, 0.5, r) * u_arms.y * u_dust * los;
            // Dust sits in a thin layer in the midplane: it reddens what's behind it, while a third of the old disc's
            // stars lie in front, so lanes redden rather than go black.
            absorb = exp(-dust * vec3(0.65, 0.8, 1.0)); // rust, as the photos' lanes measure
            vec3 screen = mix(absorb, vec3(1.0), 0.3);

            // the bar: a flat-ended bar of old stars in the disc
            float bx = g.x / max(bar, 0.001);
            float by = g.y / max(bar * 0.3, 0.001);
            bx *= bx;
            float barLight = step(0.001, bar) * exp(-bx * bx - by * by);

            // older, yellower stars toward the middle; bluer in the arms and the outskirts. A tilted disc looks
            // brighter, since each line of sight passes through more of it.
            vec3 old = mix(u_core, u_disc, smoothstep(0.05, 0.7, r));
            vec3 tint = mix(old, u_young, clamp(arm * 0.7 + 0.6 * smoothstep(0.4, 1.1, r), 0.0, 1.0)); // teal outskirts
            float boost = sqrt(los);
            // the thick disc's glow: rounder and broader than the thin disc, so a steep galaxy sits in a soft haze
            float haze = exp(-rh / 0.45) * smoothstep(1.6, 1.0, rh) * steep;
            // Photos have fine texture everywhere, about ±25% at 1–10 px, where a smooth disc reads as airbrushed.
            // (A third octave at 3 px was dropped for cost: the grain below covers that scale.)
            float tex = 0.7 + 0.6 * (0.55 * lumps + 0.45 * noise(mat2(0.6, -0.8, 0.8, 0.6) * g * 110.0 + u_seed.yx));
            light = (tint * (disc * 0.84 * tex + haze * 0.12) + u_core * barLight * 0.9) * boost * screen
                  + (tint * disc * 3.5 * arm * tex + u_young * young * inArms * clump * disc * 1.2) * boost * absorb;

            // Resolved stars twinkling in the disc as it turns, drawn as pinpoints on screen: a fine grain of stars
            // that follows the light, and blue giants just past the crests.
            float pt = 1.0 / (u_radius * u_size.y);
            mat2 m = mat2(1.0, 0.0, 0.0, u_tilt) * mat2(cos(u_phase), sin(u_phase), -sin(u_phase), cos(u_phase)) / pt;
            vec2 s1 = discStar(g, 2.2 * pt / u_tilt, 3.0, clamp(crest * inArms * 4.0 * smoothstep(1.4, 0.9, r) + disc * 0.6, 0.0, 0.85), m);
            float giants = clamp(young * inArms * clump * 2.0, 0.0, 0.3) * smoothstep(1.4, 1.0, r);
            vec2 s2 = giants > 0.002 ? discStar(g, 11.0 * pt / u_tilt, 11.0, giants, m) : vec2(0.0); // only near the arms
            light += (mix(old, u_young, smoothstep(0.05, 0.4, crest)) * s1.x * min(disc * (1.5 + 3.0 * arm), 0.3) + u_young * s2.x * 0.5) * absorb;

            // H II regions: in complexes, strung along the arm's inner edge between the dust lane and the crest,
            // dimmer toward the outskirts
            vec2 k = vec2(0.0);
            float strung = hii * inArms * smoothstep(1.2, 0.8, r);
            if (strung > 0.002) { // they only sit in a narrow band along each arm, so skip the lookups elsewhere
                float groups = smoothstep(0.3, 0.7, noise(g * 9.0 + u_seed.yx));
                k = knot(g, 16.0 * pt / u_tilt, clamp(strung * groups * 12.0, 0.0, 0.9), m);
            }
            // Hubble images keep H-alpha saturated, so part of the pink glow goes on after the stretch.
            float fade = 0.25 + 0.75 * smoothstep(1.2, 0.3, r);
            light += (u_knots * k.x * 1.5 + mix(u_young, vec3(1.0), 0.5) * k.y * 1.5) * sqrt(absorb) * fade;
            vivid = u_knots * k.x * 0.7 * sqrt(absorb) * fade;
        }
        // The bulge: a rounder cloud of old stars and a bright nucleus, broad and bright enough for the stretch below
        // (fitted to M51's profile). The disc cuts through its middle, so half its light comes through the dust, more
        // on the near side when the galaxy is tilted. It's outside the branch so its faint outskirts never meet its edge.
        float bulgeW = u_shape.w * 1.7; // its light spreads wider than the size the arms start from
        float rb = length(vec2(e.x, e.y / mix(u_tilt, 1.0, 0.6))) / bulgeW;
        float bulge = 20.0 * exp(-3.67 * sqrt(rb)) + 1.5 * exp(-rb * rb * 60.0);
        float behind = clamp(0.5 - 0.5 * e.y / bulgeW * sqrt(1.0 - u_tilt * u_tilt), 0.0, 1.0);
        light += u_core * bulge * (1.0 - behind + behind * absorb);
        // companions, behind the disc's dust where they overlap it (most kinds have none)
        if (u_comp0.w > 0.0) {
            light += u_core * (companion(e, u_comp0, u_round0) + companion(e, u_comp1, u_round1)) * absorb;
        }

        // Hubble-style stretch: asinh on brightness lifts the faint outer disc and holds the core without bleaching
        // its colour; the brightest parts pale toward white, as on a real sensor. K = 20 fits M51's radial profile
        // within 5% from 0.1 to 0.7 of its radius (K = 6 was off by 15%).
        vec3 x = light * u_brightness;
        float lum = dot(x, vec3(0.3, 0.5, 0.2)) + 0.0001;
        float stretched = log(20.0 * lum + sqrt(400.0 * lum * lum + 1.0)) / 6.17; // asinh(20 lum) / asinh(240)
        vec3 photo = min(x * stretched / lum, 1.0);
        col = col * absorb + mix(photo, vec3(stretched), 0.5 * smoothstep(0.55, 1.0, stretched)); // highlights pale
        col += vivid * u_brightness;
        // Photos carry grain everywhere, stronger where it's brighter (shot noise), and faint in the sky. It's
        // fixed to the screen, like a sensor's, while the galaxy turns beneath it.
        vec4 grain = hash42(floor(v_tex_coord * u_size * 2.0));
        col += (grain.x + grain.y - 1.0) * (0.008 + 0.02 * sqrt(stretched));
        col += vec3(1.0, 0.92, 0.85) * brightStar(pts, 180.0, u_time); // foreground stars, in our own galaxy
        col += (hash21(v_tex_coord * u_size * 2.0) - 0.5) / 128.0;
        gl_FragColor = vec4(col, 1.0);
    }
    """
}
