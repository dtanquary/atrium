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

    /// Kinds of spiral, each after a real galaxy: how many arms, their pitch angle in degrees, the bar's length and
    /// the bulge's size (in disc radii, 0 for no bar), how ragged the arms are (0 grand design, 1 flocculent), dust,
    /// the tilt range in degrees from face-on, and colours: bulge, old disc stars, young arm stars, and the
    /// hydrogen-alpha pink of star-forming knots, after each one's Hubble and ground-based portraits.
    nonisolated static let kinds: [(name: String, arms: Float, pitch: Float, bar: Float, bulge: Float, ragged: Float,
                                    dust: Float, tilt: ClosedRange<Float>, colours: [SIMD3<Float>])] = [
        ("Whirlpool", 2, 20, 0, 0.07, 0.15, 1.2, 10...30,       // M51: the classic grand design, strung with knots
         [[1.0, 0.80, 0.55], [0.85, 0.82, 0.80], [0.50, 0.68, 1.0], [1.0, 0.32, 0.55]]),
        ("Pinwheel", 4, 28, 0, 0.05, 0.6, 0.8, 0...20,          // M101: face-on, many open, lopsided arms
         [[1.0, 0.88, 0.70], [0.82, 0.84, 0.92], [0.48, 0.66, 1.0], [1.0, 0.40, 0.62]]),
        ("Andromeda", 2, 9, 0, 0.14, 0.6, 1.4, 58...70,         // M31: big golden bulge, tight dusty arms, steeply tilted
         [[1.0, 0.78, 0.50], [0.95, 0.80, 0.62], [0.58, 0.72, 1.0], [1.0, 0.45, 0.50]]),
        ("Milky Way", 2, 13, 0.28, 0.09, 0.3, 1.2, 0...35,      // ours, from outside: a short bar and two main arms
         [[1.0, 0.84, 0.58], [0.90, 0.85, 0.78], [0.60, 0.75, 1.0], [1.0, 0.38, 0.50]]),
        ("Great Barred", 2, 18, 0.42, 0.06, 0.1, 1.0, 20...45,  // NGC 1300: a long bar with open arms off its ends
         [[1.0, 0.74, 0.45], [0.76, 0.78, 0.90], [0.45, 0.64, 1.0], [1.0, 0.40, 0.60]]),
        ("Triangulum", 3, 32, 0, 0.03, 0.85, 0.6, 35...55,      // M33: flocculent, blue, rich in star-forming knots
         [[1.0, 0.90, 0.76], [0.78, 0.82, 0.96], [0.50, 0.70, 1.0], [1.0, 0.34, 0.52]]),
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
            SKUniform(name: "u_arms", vectorFloat2: [kind.ragged, kind.dust]),
            SKUniform(name: "u_core", vectorFloat3: kind.colours[0]), SKUniform(name: "u_disc", vectorFloat3: kind.colours[1]),
            SKUniform(name: "u_young", vectorFloat3: kind.colours[2]), SKUniform(name: "u_knots", vectorFloat3: kind.colours[3]),
            phase,
        ] + Array(knobUniforms.values))
        addChild(sprite)

        applySettings()
        NotificationCenter.default.addObserver(self, selector: #selector(applySettings),
                                               name: UserDefaults.didChangeNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

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

    // One star per cell of the turning disc, kept with probability `keep`, drawn as a round point on screen: `m`
    // takes a step in the disc to screen points. Returns (brightness, a random number for its colour).
    vec2 discStar(vec2 g, float cell, float seed, float keep, mat2 m) {
        vec4 h = hash42(floor(g / cell) + seed);
        if (h.x > keep) { return vec2(0.0); }
        float d = length(m * ((fract(g / cell) - 0.5 - (h.yz - 0.5) * 0.4) * cell));
        float mag = pow(h.w, 4.0);
        return vec2(exp(-d * d * (1.6 - mag)) * (0.3 + 1.6 * mag), h.x / max(keep, 0.0001)); // h.x is uniform below keep
    }

    // A star-forming knot, glowing hydrogen around the young cluster that lights it, in a cell where `keep` allows,
    // round on screen like discStar; 1.2 to 4.5 points across, mostly small. Returns (glow, cluster).
    vec2 knot(vec2 g, float cell, float keep, mat2 m) {
        vec4 h = hash42(floor(g / cell) + 41.0);
        if (h.x > keep) { return vec2(0.0); }
        float l = length(m * ((fract(g / cell) - 0.5 - (h.yz - 0.5) * 0.3) * cell)) / (1.2 + 3.3 * pow(h.w, 3.0));
        return vec2(exp(-l * l), exp(-l * l * 6.0)) * (0.3 + 0.7 * h.x / max(keep, 0.0001));
    }

    void main() {
        float aspect = u_size.x / u_size.y;
        vec2 p = v_tex_coord * vec2(aspect, 1.0);
        vec2 pts = v_tex_coord * u_size + u_seed * 97.0; // the seed moves the star field too

        // Behind it all, seen through the disc: stars in two layers of different sizes and angles, bunched into
        // loose clusters and thinner patches, and far-off galaxies.
        float crowd = 0.25 + 1.5 * smoothstep(0.2, 0.8, noise(pts / 160.0));
        vec3 col = vec3(0.004, 0.004, 0.012)
                 + starLayer(pts, 5.0, mat2(1.0, 0.0, 0.0, 1.0), 0.16 * crowd, u_time)
                 + starLayer(pts, 17.0, mat2(0.76, 0.64, -0.64, 0.76), 0.3 * crowd, u_time)
                 + vec3(1.0, 0.9, 0.8) * farGalaxy(pts, 110.0);

        // Screen to galaxy: e runs along the major axis, and undoing the tilt gives d in the disc's plane (mirrored
        // for clockwise spin), in galaxy radii. g turns with the disc, so the pattern stands still in it.
        vec2 c = (p - u_centre) / u_radius;
        vec2 e = vec2(u_pa.x * c.x + u_pa.y * c.y, u_pa.x * c.y - u_pa.y * c.x);
        vec2 d = vec2(e.x, e.y * u_spin / u_tilt);
        float r = length(d);
        if (r < 1.6) { // everything fades out by here; beyond it there's only sky
            vec2 g = turn(d, -u_phase);
            float arms = u_shape.x;
            float bar = u_shape.z;
            float bulgeR = u_shape.w;
            float ragged = u_arms.x;
            float r0 = max(bar, bulgeR * 1.6); // the arms start at the bar's ends, or the bulge's edge

            // Swirled space: turning each radius by its log winds straight rays into logarithmic spirals, so the arms
            // are rays here and noise sampled here is sheared along them into streaks and lanes.
            vec2 q = turn(g, log(max(r, r0 * 0.35) / r0) * u_shape.y);
            float warp = fbm(q * 2.2 + u_seed) - 0.5;
            float ph = arms * atan(q.y, q.x) + warp * (2.0 + 5.0 * ragged);
            // Stars stream through the arms the way the disc turns. Gas piles up and turns to dust on the way in,
            // along the arm's inner edge; new stars and knots light up just past the crest.
            float crest = pow(0.5 + 0.5 * cos(ph), 4.0 - 2.0 * ragged);
            float young = pow(0.5 + 0.5 * cos(ph - 0.4), 8.0);
            crest *= mix(1.0, smoothstep(0.3, 0.7, noise(q * 5.0 + u_seed.yx)), ragged); // flocculent arms break up
            // star clouds: lumpy in the disc itself, not swirled, so the arms read as clusters rather than brush strokes
            float lumps = noise(g * 16.0 + u_seed) * 0.6 + noise(mat2(0.8, 0.6, -0.6, 0.8) * g * 41.0 - u_seed) * 0.4;
            float clump = smoothstep(0.2, 0.9, lumps);

            float disc = exp(-r / 0.38) * smoothstep(1.5, 0.7, r);
            float zone = smoothstep(r0 * 0.8, r0 * 1.4, r) * exp(-r * 1.4) * smoothstep(1.35, 0.85, r);

            // Dust: sharp broken lanes along the arms' inner edges, and thin threads (ridges of the swirled noise)
            // feathering through the disc, reddening what's behind.
            float dt = fbm(q * 6.0 + u_seed * 1.3 + 3.0);
            float lane = pow(0.5 + 0.5 * cos(ph + 0.45 + (dt - 0.5) * 2.5), 18.0) * smoothstep(0.25, 0.8, lumps + dt - 0.5);
            float threads = pow(1.0 - abs(2.0 * dt - 1.0), 6.0);
            float dust = (lane * 1.6 + threads * (0.05 + 0.8 * crest))
                       * smoothstep(r0 * 0.3, r0 * 0.9, r) * smoothstep(1.25, 0.5, r) * u_arms.y * u_dust;
            vec3 absorb = exp(-dust * vec3(0.6, 0.8, 1.05));

            // the bar: a flat-ended bar of old stars in the disc
            float bx = g.x / max(bar, 0.001);
            float by = g.y / max(bar * 0.2, 0.001);
            bx *= bx;
            float barLight = step(0.001, bar) * exp(-bx * bx - by * by);

            vec3 old = mix(u_core, u_disc, smoothstep(0.05, 0.6, r)); // older, yellower stars toward the middle
            vec3 light = old * disc * 0.8 + u_core * barLight * 0.9
                       + mix(u_disc, u_young, 0.8) * crest * zone * (0.45 + 1.3 * clump)
                       + u_young * young * zone * clump * 0.8;

            // Resolved stars twinkling in the disc as it turns, drawn as pinpoints on screen: blue giants along the
            // arms, a sprinkle of older stars between them.
            float pt = 1.0 / (u_radius * u_size.y);
            mat2 m = mat2(1.0, 0.0, 0.0, u_tilt) * mat2(cos(u_phase), sin(u_phase), -sin(u_phase), cos(u_phase)) / pt;
            vec2 s1 = discStar(g, 4.0 * pt / u_tilt, 3.0, clamp(crest * zone * clump * 3.0 + disc * 0.08, 0.0, 0.5), m);
            vec2 s2 = discStar(g, 11.0 * pt / u_tilt, 11.0, clamp(young * zone * clump * 3.0, 0.0, 0.4), m);
            light += mix(old, u_young, step(0.3, s1.y) * smoothstep(0.1, 0.5, crest)) * s1.x * 0.3 + u_young * s2.x * 0.8;
            light *= absorb;

            // knots come in groups along the arms, just past the crest
            float groups = smoothstep(0.45, 0.8, noise(g * 7.0 + u_seed.yx));
            vec2 k = knot(g, 22.0 * pt / u_tilt, clamp(young * zone * groups * 6.0, 0.0, 0.8), m);
            light += (u_knots * k.x + mix(u_young, vec3(1.0), 0.5) * k.y) * sqrt(absorb);

            // The bulge: a rounder cloud of old stars and a bright nucleus. The disc cuts through its middle, so half
            // its light comes through the dust, more on the near side when the galaxy is tilted.
            float rb = length(vec2(e.x, e.y / mix(u_tilt, 1.0, 0.6))) / bulgeR;
            float bulge = 4.0 * exp(-3.67 * sqrt(rb)) + 2.0 * exp(-rb * rb * 60.0);
            float behind = clamp(0.5 - 0.5 * e.y / bulgeR * sqrt(1.0 - u_tilt * u_tilt), 0.0, 1.0);
            light += u_core * bulge * (1.0 - behind + behind * absorb) + u_core * 0.06 * exp(-r * 2.0) * smoothstep(1.6, 1.1, r); // and a faint halo

            col = col * absorb + 1.0 - exp(-light * u_brightness * 1.2);
        }
        col += vec3(1.0, 0.92, 0.85) * brightStar(pts, 180.0, u_time); // foreground stars, in our own galaxy
        col += (hash21(v_tex_coord * u_size * 2.0) - 0.5) / 128.0;
        gl_FragColor = vec4(col, 1.0);
    }
    """
}
