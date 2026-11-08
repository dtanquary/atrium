import SpriteKit

/// Sea Sparkle: a beach at night in a bloom of bioluminescent plankton (docs/sea-sparkle.md). One shader draws the
/// sky, the sea and the sand. Each wave is worked out by formula from four numbers the CPU hands it each frame (when it
/// passed its break line, its height, how its break point falls away either side of its peak, and where that peak is):
/// its crest comes in at sqrt(g h) over a plane beach, it breaks where its height reaches 0.78 of the depth, and its bore
/// of glowing foam runs in and up the sand. Nothing is stored between frames, so every frame rate draws the same picture.
@MainActor func seaSparkle(size: CGSize) -> SKScene { SeaSparkle(size: size) }

final class SeaSparkle: SKScene, Trimmable {
    // The knobs. Stored values are menu indices; their meanings are in docs/sea-sparkle.md → Settings.
    nonisolated static let view = Knob(key: "sparkle.view", label: "View", range: 0...3, standard: 0, section: "Shore",
                                       format: .choice(["From the beach", "At the water's edge", "From a bluff", "Along the beach"]))
    // ponytail: the swell held at a size; Live (Open-Meteo's marine feed at a real bloom beach) is a later step.
    nonisolated static let surf = Knob(key: "sparkle.surf", label: "Surf", range: 0...2, standard: 1, section: "Shore",
                                       format: .choice(["Small", "Moderate", "Big"]))
    nonisolated static let beach = Knob(key: "sparkle.beach", label: "Beach", range: 0...1, standard: 0, section: "Shore",
                                        format: .choice(["Gentle, spilling waves", "Steep, plunging waves"]))
    nonisolated static let headland = Knob(key: "sparkle.headland", label: "Headland", range: 0...1, standard: 0, section: "Shore", format: .toggle)
    nonisolated static let town = Knob(key: "sparkle.town", label: "Town lights", range: 0...1, standard: 0, section: "Shore", format: .toggle,
                                       shownWhen: "sparkle.headland")
    nonisolated static let light = Knob(key: "sparkle.light", label: "Light", range: 0...3, standard: 0, section: "Glow",
                                        format: .choice(["As video shows it", "As the eye sees it", "As a long exposure", "In points (Noctiluca)"]))
    nonisolated static let colour = Knob(key: "sparkle.colour", label: "Colour", range: 0...2, standard: 0, section: "Glow",
                                         format: .choice(["Cyan", "Azure", "Teal"]), hiddenWhen: "sparkle.light", hiddenAt: 1)
    // ponytail: a Moon held at a phase, in a fixed place; tonight's real Moon (SkyMath) is a later step.
    nonisolated static let moon = Knob(key: "sparkle.moon", label: "Moon", range: 0...2, standard: 0, section: "Sky",
                                       format: .choice(["None", "Half", "Full"]))
    nonisolated static let speed = Knob(key: "sparkle.speed", label: "Speed", range: 0.25...3, standard: 1, section: "Shore", format: .times)
    nonisolated static let knobs = [view, surf, beach, speed, headland, town, light, colour, moon]

    /// A level camera: horizon (fraction of the screen's height), focal length (screen heights), eye above the
    /// water (m), the shoreline's distance straight ahead (m), and how far it is turned from facing the sea (radians).
    struct View { var hz, F, E, D0, yaw: Double }
    nonisolated static let beachFace = 0.06 // the sand's slope above the waterline
    nonisolated static func standing(_ D0: Double) -> Double { 1.7 + D0 * beachFace } // eye height for someone on the sand
    nonisolated static let views = [
        View(hz: 0.66, F: 3.0, E: standing(14), D0: 14, yaw: 0),   // from the beach, a long lens
        View(hz: 0.56, F: 1.1, E: standing(6), D0: 6, yaw: 0),     // at the water's edge
        View(hz: 0.74, F: 1.1, E: 12, D0: 22, yaw: 0),             // from a bluff 12 m up
        View(hz: 0.56, F: 1.3, E: standing(8), D0: 8, yaw: 0.75),  // along the beach
    ]
    /// Breaker height (m) and period (s) for Small, Moderate and Big.
    nonisolated static let swells: [(height: Double, period: Double)] = [(0.6, 8), (1.3, 10), (2.2, 13)]

    /// The research's samples (research-look.md §2): the one light under a camera's white balance, and as the eye
    /// sees it in the dark (paler; colour vision fades in dim light, unchecked). sky, sea, sand, then the glow's edge,
    /// body, core and brightest foam.
    nonisolated static let palettes: [[Int]] = [
        [0x050d1c, 0x05070e, 0x141216, 0x0c2d37, 0x145f69, 0x137596, 0x378daf], // cyan
        [0x0d111a, 0x04060c, 0x100c14, 0x020732, 0x042564, 0x064891, 0x257faf], // azure
        [0x13131a, 0x06030c, 0x141210, 0x033734, 0x015464, 0x008c71, 0x01b99d], // teal
        [0x060a14, 0x04060b, 0x100f12, 0x101c2c, 0x24405a, 0x3a6584, 0x7d9fb8], // as the eye sees it
    ]
    /// Each Light pick: gain on the light, how long foam keeps glowing (a multiplier), how smooth the foam is
    /// (0 lace, 1 mist), and a lift of the sky as a long exposure gives; and whether it falls in points.
    nonisolated static let looks: [(gain: Double, fade: Double, smooth: Double, lift: Double, points: Bool)] = [
        (1, 1, 0, 0, false), (0.65, 1, 0.3, 0, false), (0.85, 3, 0.85, 0.45, false), (1, 0.8, 0, 0, true),
    ]

    let trim = TrimNode()
    private let shore: SKSpriteNode
    private let viewUniform = SKUniform(name: "u_view", vectorFloat4: .zero)
    private let beachUniform = SKUniform(name: "u_beach", vectorFloat4: .zero)
    private let moonUniform = SKUniform(name: "u_moon", vectorFloat4: .zero)
    private let landUniform = SKUniform(name: "u_land", vectorFloat4: .zero)
    private let lookUniform = SKUniform(name: "u_look", vectorFloat4: .zero)
    private let extraUniform = SKUniform(name: "u_glowc", vectorFloat4: .zero)
    private let waveUniforms = (0..<6).map { SKUniform(name: "u_w\($0)", vectorFloat4: .zero) }
    private var shaderKey = -1
    /// The waves: a train rolled from `seed`, each one worked out from its number as it's needed, so none is stored.
    private let seed = UInt64.random(in: 1...UInt64.max)
    private let groupPhase: (Double, Double), oblique: Double
    /// The wave that's breaking in view as the scene starts: its peak is put straight ahead.
    private var firstWave = 0
    /// The scene's own seconds, summed in Double at the Speed knob's rate.
    private var clock = 0.0
    private var lastUpdate: TimeInterval?

    override init(size: CGSize) {
        var rng = SplitMix(state: seed)
        groupPhase = (Double.random(in: 0..<1, using: &rng) * 6.28, Double.random(in: 0..<1, using: &rng) * 6.28)
        oblique = (Double.random(in: 0..<1, using: &rng) - 0.5) * 0.008
        shore = SKSpriteNode(color: .black, size: size)
        super.init(size: size)
        backgroundColor = .black
        shore.anchorPoint = .zero
        // ponytail: all of it in the trim, so on battery the stars and sparkles soften with the rest; a sharp layer of
        // their own (the method research measured 0.33 ms for the split) if that shows side by side.
        trim.content.addChild(shore)
        addChild(trim)
        // Start 3 s after the biggest of a few waves breaks, its peak straight ahead, so there's a break to see at once.
        let swell = Self.swells[Int(Self.surf.value)]
        firstWave = (3...9).max { wave($0, swell).hb < wave($1, swell).hb }!
        clock = wave(firstWave, swell).tb + 3
        applyKnobs()
        place()
        NotificationCenter.default.addObserver(self, selector: #selector(applyKnobs), name: UserDefaults.didChangeNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Wave number k: when its crest passes the break line it would have on a plain beach, its breaker height, how
    /// fast its break point comes in either side of its peak (the peel), and its peak's place along the shore (m).
    /// Sets: a group of bigger waves about every seven, under a slower swell of groups, and a little of each wave's own.
    private func wave(_ k: Int, _ swell: (height: Double, period: Double)) -> (tb: Double, hb: Double, peel: Double, peak: Double) {
        var rng = SplitMix(state: seed &+ UInt64(bitPattern: Int64(k)) &* 0x9E37_79B9_7F4A_7C15)
        let kd = Double(k)
        let env = 0.78 + 0.32 * sin(2 * .pi * kd / 7 + groupPhase.0) + 0.14 * sin(2 * .pi * kd / 17.3 + groupPhase.1) + 0.18 * (Double.random(in: 0..<1, using: &rng) - 0.5)
        let tb = kd * swell.period + (Double.random(in: 0..<1, using: &rng) - 0.5) * 0.44 * swell.period
        let peel = Double.random(in: 0..<1, using: &rng) < 0.2 ? 0.0005 + 0.0015 * Double.random(in: 0..<1, using: &rng) : 0.004 + 0.008 * Double.random(in: 0..<1, using: &rng)
        let peak = k == firstWave ? 0 : (Double.random(in: 0..<1, using: &rng) - 0.5) * 100
        return (tb, swell.height * max(0.35, env), peel, peak)
    }

    @objc private func applyKnobs() {
        let v = Self.views[Int(Self.view.value)]
        let swell = Self.swells[Int(Self.surf.value)]
        let tanb = Self.beach.value > 0.5 ? 0.07 : 0.03
        let iribarren = tanb / (swell.height / (9.81 * swell.period * swell.period / (2 * .pi))).squareRoot() // under 0.5 spills
        let light = Int(Self.light.value), look = Self.looks[light]
        let moonUp = [0, 0.5, 1][Int(Self.moon.value)]
        let aspect = size.width / max(size.height, 1)
        viewUniform.vectorFloat4Value = f4(v.hz, v.F, v.E, v.D0)
        beachUniform.vectorFloat4Value = f4(v.yaw, tanb, Self.beachFace, min(1, max(0, (iribarren - 0.3) / 0.4)))
        moonUniform.vectorFloat4Value = f4(pow(moonUp, 1.6), -0.35 * aspect, 0.2, moonUp)
        landUniform.vectorFloat4Value = f4(Self.headland.value, 0.2 * aspect, 0.1, Self.town.value)
        lookUniform.vectorFloat4Value = f4(look.gain, look.fade, look.smooth, look.lift)
        extraUniform.vectorFloat4Value = f4(oblique, Double(seed % 97), 0, look.points ? 1 : 0)
        // The colours are written into the shader, so a new pick of Colour or Light builds it afresh.
        let key = light == 1 ? 3 : Int(Self.colour.value)
        guard key != shaderKey else { return }
        shaderKey = key
        var source = shaderCommon + Self.source
        for (name, hex) in zip(["SKY_C", "SEA_C", "SAND_C", "EDGE_C", "BODY_C", "CORE_C", "FOAM_C"], Self.palettes[key]) {
            source = source.replacingOccurrences(of: name, with: String(format: "vec3(%.4f, %.4f, %.4f)",
                                                 Double(hex >> 16 & 255) / 255, Double(hex >> 8 & 255) / 255, Double(hex & 255) / 255))
        }
        shore.shader = SKShader(source: source, uniforms: [
            SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)]), WallpaperTime.now,
            viewUniform, beachUniform, moonUniform, landUniform, lookUniform, extraUniform,
            SKUniform(name: "u_noise", texture: CloudNoise.texture),
        ] + waveUniforms)
    }

    override func update(_ currentTime: TimeInterval) {
        clock += frameTime(currentTime, &lastUpdate) * Self.speed.value
        place()
    }

    /// Hands the shader the six waves that matter now: the newest that has come within sight and the five before it,
    /// each as its age in seconds, worked out here in Double so no clock grows in the shader.
    private func place() {
        let swell = Self.swells[Int(Self.surf.value)]
        let tanb = Self.beach.value > 0.5 ? 0.07 : 0.03
        let k = (9.81 * tanb).squareRoot() / 2
        var newest = Int(clock / swell.period) + 4
        while newest > 0 {
            let w = wave(newest, swell), sb = w.hb / (0.78 * tanb)
            if clock > w.tb - ((4.5 * sb).squareRoot() - sb.squareRoot()) / k { break }
            newest -= 1
        }
        for (i, uniform) in waveUniforms.enumerated() {
            let w = wave(newest - i, swell)
            uniform.vectorFloat4Value = f4(clock - w.tb, w.hb, w.peel, w.peak)
        }
    }

    private func f4(_ a: Double, _ b: Double, _ c: Double, _ d: Double) -> vector_float4 { [Float(a), Float(b), Float(c), Float(d)] }

    /// The shore: a level camera, each pixel below the horizon a point on the sea or the sand found from its angle
    /// below the horizon. Each wave's crest, a straight line along the shore, moves in at sqrt(g h), so where it is
    /// at any moment is closed form (research-method.md §3). It breaks furthest out at its peak and nearer in either
    /// side, so the break runs along the crest; a sandbar's gaps let it in further. Unbroken it is a dark face; broken
    /// it is a wall of foam that glows, brightest at its top, with a soft halo of spray, and leaves lace that fades.
    /// Its swash runs up the sand and back. The wet sand and the sea mirror the glow.
    private static let source = """
    float vnoise(float x) { float i = floor(x); float f = fract(x); f = f * f * (3.0 - 2.0 * f); return mix(hash11(i), hash11(i + 1.0), f); }

    // Where to sample the baked tileable noise (CloudNoise, 257 texels with the first repeated) for point p.
    vec2 nuv(vec2 p) { return (fract(p) * 256.0 + 0.5) / 257.0; }

    // How a bore glows `tb` seconds after it broke: lit over a second or so, then fading as it weakens (research-look.md §1:
    // the lit area grows for 1.5 s, peaks about 2.3 s in, and is at 56% 2.8 s later). A tail of a third stays while it
    // still churns into fresh water on its way in (my reading of the footage, not measured: a tunable).
    float boreGlow(float tb, float fade) {
        return smoothstep(0.0, 1.3, tb) * (0.32 + 0.68 * exp(-max(tb - 1.2, 0.0) / (4.8 * fade)));
    }

    // The glow's colour for a level of light: edge, body, core, then the palest foam.
    vec3 ramp(float L, vec3 edge, vec3 body, vec3 core, vec3 foam) {
        vec3 c = edge * smoothstep(0.0, 0.25, L);
        c = mix(c, body, smoothstep(0.2, 0.55, L));
        c = mix(c, core, smoothstep(0.5, 0.8, L));
        return mix(c, foam, smoothstep(0.78, 1.0, L));
    }

    void main() {
        vec2 uv = v_tex_coord;
        vec2 pts = uv * u_size;
        float aspect = u_size.x / u_size.y;
        float t = u_now;
        float hz = u_view.x, F = u_view.y, E = u_view.z, D0 = u_view.w;
        float yaw = u_beach.x, tanb = u_beach.y, tanB = u_beach.z, plunge = u_beach.w;
        float oblique = u_glowc.x;
        float y = uv.y - hz, x = (uv.x - 0.5) * aspect;
        float moon = u_moon.x;

        // The sky: a night gradient, a little paler toward the horizon, the stars, a headland and the town on it.
        float up = max(y, 0.0);
        vec3 skyTop = mix(SKY_C, vec3(0.125, 0.172, 0.235), moon * 0.8) + SKY_C * u_look.w * 1.6;
        vec3 skyLow = skyTop * 1.3 + vec3(0.004, 0.006, 0.010) * (1.0 + u_look.w * 3.0);
        vec3 col = mix(skyLow, skyTop, smoothstep(0.0, 0.3, up));
        float q = x / F * sin(yaw) + cos(yaw);      // how fast the ground runs seaward along this pixel's ray
        float p = x / F * cos(yaw) - sin(yaw);      // and along the shore
        if (y > 0.0) {
            // ponytail: hashed stars, not the catalogue's real ones for the place and hour (Live Sky's), a later step.
            float stars = starField(pts, 7.0, 0.3, t) * smoothstep(0.0, 0.06, up) * (1.0 - 0.75 * moon);
            col += vec3(0.75, 0.8, 0.9) * stars * 0.5;
            vec2 md = vec2(x - u_moon.y, y - u_moon.z);
            float r = length(md);
            // The Moon at its real size (half a degree), lit on its right by its phase (u_moon.w, the lit fraction).
            float R = 0.0044 * F;
            float lit = step(md.x / R, 1.0) * step((1.0 - 2.0 * u_moon.w) * sqrt(max(1.0 - md.y * md.y / (R * R), 0.0)), md.x / R);
            col += vec3(0.85, 0.85, 0.8) * step(0.001, moon) * (smoothstep(R, R * 0.85, r) * mix(0.03, 0.95, lit) + 0.05 * moon * exp(-r * 10.0));
            if (u_land.x > 0.0) {
                // A headland on the right, far off: a ridge rising from the sea, and a few lights along its foot.
                float xs = x - u_land.y;
                float ridge = u_land.z * smoothstep(0.0, 0.35, xs) * (0.75 + 0.25 * vnoise(xs * 9.0) + 0.1 * vnoise(xs * 31.0));
                if (y < ridge) {
                    col = mix(vec3(0.008, 0.010, 0.014), vec3(0.03, 0.035, 0.045), moon);
                    if (u_land.w > 0.0) {
                        vec2 cell = floor(pts / vec2(3.0, 2.0));
                        vec4 r4 = hash42(cell + 17.0);
                        float town = step(r4.x, 0.22) * smoothstep(ridge * 0.55, ridge * 0.1, y) * smoothstep(0.03, 0.08, xs) * smoothstep(0.4, 0.2, xs);
                        vec2 f = fract(pts / vec2(3.0, 2.0)) - 0.5;
                        col += vec3(0.34, 0.24, 0.12) * town * exp(-dot(f, f) * 10.0) * (0.5 + 0.5 * r4.y);
                    }
                }
            }
        } else {
            float m = -y / F;                         // the ray's drop per metre
            float dFlat = E / m;                      // where it meets the sea's level
            float sFlat = dFlat * q - D0;             // metres seaward of the shoreline there
            float k = sqrt(9.81 * tanb) * 0.5;
            float gs = 9.81 * tanB;

            // The nearest wave face the ray meets, the light on the flat where it meets none, and the glow mirrored there.
            float bestD = dFlat, faceU = -1.0, faceH = 0.0, faceA = 0.0, faceGlow = 0.0, faceTau = -10.0;
            float trail = 0.0, swashEdge = 0.0, wetAge = 1000.0, swashCover = 0.0, refl = 0.0, halo = 0.0, haloD = 0.0;
            float A0 = dFlat * p;
            for (int i = 0; i < 6; i++) {
                vec4 w = i == 0 ? u_w0 : (i == 1 ? u_w1 : (i == 2 ? u_w2 : (i == 3 ? u_w3 : (i == 4 ? u_w4 : u_w5))));
                if (w.y <= 0.0) { continue; }
                float sbN = w.y / (0.78 * tanb);
                // Twice: once where the ray meets the sea, once where it meets this wave's crest.
                float A = A0, sc = 0.0, tau = 0.0, sb = sbN, tt = 0.0;
                for (int pass = 0; pass < 2; pass++) {
                    float bar = vnoise(A / 40.0 + u_glowc.y) * 2.0 - 1.0;
                    sb = sbN * (1.0 + 0.2 * bar) * mix(0.4, 1.0, smoothstep(-0.8, -0.5, bar)) * (0.3 + 0.7 * exp(-abs(A - w.w) * w.z * 1.4));
                    tt = w.x - oblique * A;
                    float r = sqrt(sbN) - k * tt;
                    sc = r > 0.0 ? r * r : 0.0;
                    tau = tt - (sqrt(sbN) - sqrt(sb)) / k + 0.3 * (vnoise(A * 0.35 + w.w * 7.0) - 0.5);   // a ragged edge to the break
                    A = (sc + D0) / max(q, 0.05) * p;
                }
                float broken = smoothstep(-0.25, 0.25, tau);
                float Hn = w.y * pow(sb / max(sc, sb), 0.25) * smoothstep(4.5 * sbN, 2.2 * sbN, sc);
                float Hb = w.y * mix(1.0, 0.3 + 0.5 * clamp(sc / sb, 0.0, 1.0), smoothstep(0.0, 1.6, tau));
                float lump = 0.75 + 0.3 * vnoise(A * 0.35 + w.w) + 0.18 * vnoise(A * 1.7 - w.w * 3.0) * broken;   // the foam's lumpy top
                Hb *= lump;
                float Hh = mix(Hn, Hb, smoothstep(-0.2, 1.4, tau)) * smoothstep(0.0, 0.5, sc);   // the pile builds behind the break
                float wf = Hh * mix(mix(7.0, 1.3, smoothstep(-8.0, 0.0, tau)), 0.9, broken);
                float bright = pow(w.y, 0.7) * u_look.x;
                float glowNow = boreGlow(tau, u_look.y) * broken;
                if (q > 0.05 && Hh > 0.02) {
                    // Where the ray meets this wave's face, a straight slope from its foot to its crest.
                    float dA = (sc - wf + D0) / q, wd = wf / q, dC = dA + wd;
                    float d = (E + Hh * dA / wd) / (m + Hh / wd);
                    float u = (d - dA) / wd;
                    if (u >= 0.0 && u <= 1.0 && d < bestD) {
                        bestD = d; faceU = u; faceH = Hh; faceA = A; faceTau = tau;
                        float lip = plunge * smoothstep(-0.45, 0.0, tau) * exp(-max(tau, 0.0) / 0.6) * smoothstep(0.8, 0.97, u);
                        float spill = (1.0 - plunge) * smoothstep(-1.2, 0.0, tau) * smoothstep(1.0 - 0.35 * smoothstep(-1.2, 1.0, tau), 1.0, u) * (1.0 - broken);
                        faceGlow = (glowNow * (0.3 + 0.7 * u * u) + 1.8 * lip + 0.9 * spill) * bright;
                    }
                    // Spray over a breaking crest: a soft halo where the ray passes just above it.
                    float over = E - m * dC - Hh / lump * 0.95;
                    if (over > 0.0 && dC < dFlat) {
                        float hl = (glowNow + plunge * smoothstep(-0.45, 0.0, tau) * exp(-max(tau, 0.0) / 0.8)) * bright
                                 * exp(-over / (0.1 + 0.2 * Hh));
                        if (hl > halo) { halo = hl; haloD = dC; }
                    }
                    // The same face mirrored where the ray meets the flat.
                    float dR = (Hh * dA / wd - m * dFlat) / (Hh / wd - m);
                    float uR = (dR - dA) / wd;
                    if (dA > dFlat && uR >= 0.0 && uR <= 1.0 && Hh / wd > m) {
                        refl = max(refl, glowNow * (0.3 + 0.7 * uR * uR) * bright);
                    }
                }
                // On the flat: the foam a bore left behind it, fading.
                if (sFlat > 0.0 && sFlat < sb && tau > 0.0) {
                    float tp = (sqrt(sb) - sqrt(sFlat)) / k;   // seconds after breaking that the bore passed here
                    float since = tau - tp;
                    if (since > 0.0) { trail += boreGlow(tp, u_look.y) * exp(-since / (2.2 * u_look.y)) * bright; }
                }
                // The swash: up the sand and back, its edge glowing, the sand it wets sparkling as it drains.
                float ts = tt - sqrt(sbN) / k;
                float u0 = sqrt(9.81 * 0.35 * w.y);
                float xr = max(u0 * ts - 0.5 * gs * ts * ts, 0.0);
                float run = u0 * u0 / (2.0 * gs);
                float dur = 2.0 * u0 / gs;
                if (sFlat < 0.0 && ts > 0.0) {
                    float upSand = -sFlat;
                    if (ts < dur && upSand < xr) {
                        swashCover = 1.0;
                        swashEdge += exp(-pow((upSand - xr) / 0.4, 2.0)) * smoothstep(dur * 0.6, 0.0, ts) * bright;
                        trail += 0.15 * exp(-ts / 2.5) * bright;
                    }
                    if (upSand < run) { wetAge = min(wetAge, max(ts - (u0 - sqrt(max(u0 * u0 - 2.0 * gs * upSand, 0.0))) / gs, 0.0)); }
                }
            }

            // What the ray met.
            float s = bestD * q - D0;
            float A = faceU >= 0.0 ? faceA : bestD * p;
            float onSand = step(s, 0.0) * step(faceU, -0.5) * (1.0 - swashCover);
            float wet = exp(-wetAge / 25.0);
            vec4 n1 = texture2D(u_noise, nuv(faceU >= 0.0 ? vec2(A * 0.07, faceU * faceH * 0.3 - faceTau * 0.2) : vec2(A * 0.07, s * 0.1)));
            vec4 n2 = texture2D(u_noise, nuv(faceU >= 0.0 ? vec2(A * 0.17, faceU * faceH * 0.75 - faceTau * 0.3) + n1.rb * 0.2 : vec2(A * 0.19, s * 0.27) + n1.rb * 0.2));
            // The sea between waves: a little of the sky's light off the water, more toward the horizon, broken by ripples.
            float graze = exp(-m * 8.0);
            vec3 sea = mix(SEA_C, vec3(0.09, 0.10, 0.133), moon * 0.6) + skyLow * (0.06 + 0.6 * graze) * (0.6 + 0.8 * n2.b);
            vec3 seaFace = sea * mix(1.0, 0.55, smoothstep(-6.0, 0.0, faceTau) * (1.0 - step(0.0, faceTau)) * smoothstep(0.0, 0.9, faceU));
            vec3 sandCol = mix(SAND_C, vec3(0.15, 0.133, 0.157), moon * 0.7) * (0.85 + 0.3 * n2.b);
            sandCol = mix(sandCol, sea * 0.9, wet * 0.85);
            vec3 base = onSand > 0.5 ? sandCol : (faceU >= 0.0 ? seaFace : sea);

            // Foam: billows rolling up a face, lace on the flat that thins as it ages (u_look.z smooths both to mist).
            float billow = smoothstep(0.25, 0.8, n1.g * 0.6 + n2.g * 0.5);
            float lace = smoothstep(0.55, 0.2, n1.g) * 0.8 + smoothstep(0.5, 0.25, n2.g) * 0.4;
            lace *= smoothstep(0.25, 0.6, n1.r + 0.2);
            float face = mix(0.3 + 0.9 * billow, 0.8, u_look.z);
            float flat = mix(0.12 + 1.1 * lace, 0.55, u_look.z);
            float light = faceU >= 0.0 ? faceGlow * face : trail * flat;
            light += swashEdge * (0.5 + 0.6 * n2.g);
            light += halo * 0.45 * step(haloD, bestD + 0.01) * (0.7 + 0.3 * n1.r);
            light += refl * mix(0.3, 0.55, wet * onSand + swashCover) * (0.4 + 0.8 * n2.b) * step(faceU, -0.5);

            // Noctiluca: the light broken into points, each cell flashing once in a while (research-look.md §1).
            if (u_glowc.w > 0.5) {
                vec2 cell = floor(pts / 2.0);
                vec4 r = hash42(cell + floor(t * 2.0 + hash21(cell) * 7.0) * 13.0);
                light = light * 0.2 + step(r.x, clamp(light * 0.3, 0.0, 0.5)) * (1.0 + 1.6 * r.y);
            }
            // Points on wet sand where the swash drained (Noctiluca's sparkle, sparse and dim).
            vec4 sr = hash42(floor(pts / 1.5));
            float spark = step(sr.x, 0.016) * exp(-wetAge / 9.0) * step(s, 0.0) * step(faceU, -0.5)
                        * pow(0.5 + 0.5 * sin(t * (1.0 + 2.0 * sr.y) + sr.z * 40.0), 6.0) * u_look.x;

            float L = 1.0 - exp(-light * 0.9);
            col = base + ramp(L, EDGE_C, BODY_C, CORE_C, FOAM_C) + FOAM_C * spark * 1.2;
            // The Moon's glitter path, broken by the ripples.
            if (moon > 0.0 && s > 0.0 && faceU < 0.0) {
                float path = exp(-pow((x - u_moon.y) / (0.015 + 0.6 * m), 2.0));
                col += vec3(0.6, 0.62, 0.62) * moon * path * pow(n2.b, 5.0) * 2.0;
            }
        }
        col += (hash21(pts * 2.0) - 0.5) / 255.0;
        gl_FragColor = vec4(col, 1.0);
    }
    """
}
