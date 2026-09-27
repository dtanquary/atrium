import SpriteKit

@MainActor func lavaLamp(size: CGSize) -> SKScene { LavaLamp(size: size) }

/// The inside of a lava lamp, full screen. Wax heats in a molten pool over the bulb, rises up the middle as round
/// heads on stems that neck and pinch off, mostly sticks to the top for a while, then slides out and sinks near
/// the cooler sides, sometimes dripping off the top on a thread. It glows from within, lit by the bulb below. Each load rolls a jewel-tone colour pairing (or the one pinned in Settings) and its own
/// blobs; left running, it eases to another pairing every few minutes while the wax keeps moving.
final class LavaLamp: SKScene {
    nonisolated static let knobs = [
        Knob(key: "lava.speed", label: "Speed", range: 0.2...3, standard: 1, section: "Motion"),
        Knob(key: "lava.blobSize", label: "Blob size", range: 0.6...1.6, standard: 1, section: "Motion"),
        Knob(key: "lava.wobble", label: "Wobble", range: 0...0.04, standard: 0.018, section: "Motion"),
        Knob(key: "lava.glow", label: "Glow", range: 0...0.6, standard: 0.3, section: "Light"),
        Knob(key: "lava.bulb", label: "Bulb", range: 0.3...1.5, standard: 1, section: "Light"),
        Knob(key: "lava.opacity", label: "Wax opacity", range: 0.4...1, standard: 0.72, section: "Light"),
        Knob(key: "lava.cycleMinutes", label: "Change colors every", range: 0...30, standard: 8, section: "Colors",
             format: .minutes),
    ] + gradeKnobs("lava")

    /// Wax (thin and deep, thick and hot) and liquid (dark, bulb-lit): luminous jewel-tone wax in deep liquids,
    /// drawn from Flowing Gradient's palette so the two feel like a family, and the same hues in pale liquids for
    /// Light Mode.
    nonisolated static let palettes: [(name: String, dark: [SIMD3<Float>], light: [SIMD3<Float>])] = [
        ("Coral", [[0.55, 0.15, 0.20], [1.00, 0.58, 0.48], [0.03, 0.02, 0.08], [0.24, 0.12, 0.55]],
         [[0.85, 0.35, 0.35], [1.00, 0.62, 0.52], [0.62, 0.60, 0.80], [0.92, 0.90, 1.00]]),
        ("Soft Blue", [[0.10, 0.25, 0.60], [0.55, 0.80, 1.00], [0.01, 0.02, 0.06], [0.07, 0.12, 0.42]],
         [[0.20, 0.42, 0.85], [0.55, 0.78, 1.00], [0.60, 0.70, 0.85], [0.90, 0.95, 1.00]]),
        ("Magenta", [[0.45, 0.06, 0.35], [1.00, 0.45, 0.80], [0.03, 0.01, 0.07], [0.30, 0.15, 0.62]],
         [[0.70, 0.15, 0.50], [0.98, 0.50, 0.78], [0.75, 0.62, 0.78], [0.98, 0.90, 0.96]]),
        ("Teal", [[0.02, 0.30, 0.35], [0.45, 0.95, 0.92], [0.01, 0.02, 0.06], [0.10, 0.14, 0.45]],
         [[0.05, 0.48, 0.52], [0.40, 0.85, 0.82], [0.60, 0.72, 0.78], [0.90, 0.97, 0.98]]),
        ("Peach", [[0.60, 0.25, 0.12], [1.00, 0.74, 0.48], [0.04, 0.01, 0.05], [0.36, 0.10, 0.40]],
         [[0.90, 0.48, 0.25], [1.00, 0.75, 0.50], [0.80, 0.70, 0.65], [1.00, 0.96, 0.90]]),
        ("Lavender", [[0.30, 0.20, 0.65], [0.82, 0.72, 1.00], [0.01, 0.01, 0.05], [0.12, 0.10, 0.38]],
         [[0.45, 0.35, 0.85], [0.72, 0.62, 1.00], [0.66, 0.66, 0.86], [0.94, 0.94, 1.00]]),
        ("Rose", [[0.55, 0.20, 0.30], [1.00, 0.66, 0.64], [0.01, 0.04, 0.06], [0.03, 0.28, 0.36]],
         [[0.80, 0.35, 0.45], [1.00, 0.66, 0.66], [0.60, 0.76, 0.74], [0.90, 0.98, 0.96]]),
    ]

    private let knobUniforms: [String: SKUniform]
    private let colours = ["u_waxDeep", "u_waxHot", "u_liquidDeep", "u_liquidLit"].map { SKUniform(name: $0, vectorFloat3: .zero) }
    private let phase = SKUniform(name: "u_phase", float: 0)
    /// The wax, one column each: eight heads as (x, y, radius, stretch), then their stems as (anchor x, anchor y,
    /// radius, 1 / the head's radius). The shader would pay a quarter of a millisecond to divide by the radius itself.
    private let blobs = (0..<4).map { SKUniform(name: "u_blobs\($0)", matrixFloat4x4: matrix_identity_float4x4) }
    private let seed = Double(ProcessInfo.processInfo.environment["LAVA_SEED"] ?? "") ?? .random(in: 0...100) // fixed, to compare looks
    private var time = 0.0 // the phase, kept in Double so the layout stays smooth after days of running
    private var flowSpeed = 1.0
    private var blobSize = 1.0
    private var lastUpdate: TimeInterval?
    private var cycleMinutes: Double?
    private var current = 0 // the palette showing, or being faded to

    private var set: [[SIMD3<Float>]] { Self.palettes.map { systemIsDark ? $0.dark : $0.light } }

    override init(size: CGSize) {
        knobUniforms = Dictionary(uniqueKeysWithValues: Self.knobs.map {
            ($0.key, SKUniform(name: "u_" + $0.key.split(separator: ".").last!, float: Float($0.standard)))
        })
        super.init(size: size)
        current = Self.palettes.firstIndex { $0.name == UserDefaults.standard.string(forKey: "lava.palette") }
            ?? Self.palettes.indices.randomElement()!
        for (uniform, colour) in zip(colours, set[current]) { uniform.vectorFloat3Value = colour }

        let sprite = SKSpriteNode(color: .black, size: size)
        sprite.anchorPoint = .zero
        sprite.shader = SKShader(source: shaderCommon + Self.source, uniforms: [
            SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)]),
            phase, SKUniform(name: "u_pivot", float: systemIsDark ? 0.3 : 0.7), // the grade's contrast pivot
        ] + colours + blobs + Array(knobUniforms.values))
        addChild(sprite)

        applySettings()
        NotificationCenter.default.addObserver(self, selector: #selector(applySettings),
                                               name: UserDefaults.didChangeNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func update(_ currentTime: TimeInterval) {
        if let last = lastUpdate { // integrated, so speed changes don't jump
            time += min(max(currentTime - last, 0), 0.5) * flowSpeed
            phase.floatValue = Float(time)
        }
        lastUpdate = currentTime
        layBlobs()
    }

    /// Where every blob is at the current phase. It's the same for every pixel, so it's worked out once a frame
    /// here rather than in the shader, which only sums the wax; that halves the GPU cost. A pure function of the
    /// phase, so it looks the same at any frame rate.
    private func layBlobs() {
        func hash(_ x: Double) -> Double { let v = sin(x * 127.1) * 43758.5453; return v - v.rounded(.down) }
        // Height along a trip (0..1): it rests in the pool, rises, lingers at the top as it cools, then sinks back
        // more slowly than it rose.
        func height(_ s: Double) -> Double { simd_smoothstep(0.06, 0.40, s) - simd_smoothstep(0.56, 0.94, s) }
        let aspect = size.width / size.height
        var heads: [SIMD4<Float>] = [], stems: [SIMD4<Float>] = []
        for i in 0..<8 {
            let fi = Double(i) + seed
            // One trip every 60-110 s, each with its own size, lane and height, so no path ever repeats.
            let u = time / (60 + 50 * hash(fi + 0.57)) + hash(fi + 0.91)
            let trip = u.rounded(.down), s = u - trip
            let h1 = hash(fi + 0.13 + trip * 7.31), h2 = hash(fi + 0.37 + trip * 3.17), h3 = hash(fi + 0.71 + trip * 5.03)
            // Pea-sized droplets to fist-sized heads, shrinking away while buried in the pool so a new trip never pops.
            let r = (0.028 + 0.1 * h1 * h1) * blobSize * simd_smoothstep(0, 0.05, s) * (1 - simd_smoothstep(0.95, 1, s))
            let ceiling = h2 < 0.65 // most reach the top and stick there a while
            let top = ceiling ? 1 - 0.45 * r : 0.5 + 0.35 * h2
            let h = height(s), speed = (height(s + 0.01) - height(s - 0.01)) * 12 // about +1 rising, -0.8 sinking
            let y = -0.05 + (top + 0.05) * h
            // It rises over the bulb, slides out along the top, and sinks toward the nearer, cooler wall.
            let rise = aspect * (0.3 + 0.4 * h3)
            let sink = min(max(rise + (rise < aspect / 2 ? -1 : 1) * aspect * (0.1 + 0.12 * h1), aspect * 0.07), aspect * 0.93)
            let x = simd_mix(rise, sink, simd_smoothstep(0.40, 0.66, s)) + 0.02 * sin(time * 0.03 + fi * 2)
            // Heads stay round: pancaked against the top while parked there, a little long as they drip.
            let parked = simd_smoothstep(0.34, 0.42, s) * (1 - simd_smoothstep(0.56, 0.66, s)) * (ceiling ? 1 : 0.3)
            heads.append(SIMD4(Float(x), Float(y), Float(r), Float((1 - 0.38 * parked) * (1 + 0.12 * max(-speed, 0)))))
            // Its stem: a column off the pool that thins and pinches off under the rising head (squared, so a thin
            // thread goes quickly rather than hanging on as a string), or a thread off the top as it starts to sink.
            let neck = 1 - simd_smoothstep(0.16, 0.32, s)
            let drip = ceiling ? r * 0.4 * simd_smoothstep(0.54, 0.6, s) * (1 - simd_smoothstep(0.62, 0.72, s)) : 0
            let perRadius = Float(1 / max(r, 0.001))
            stems.append(s < 0.5 ? SIMD4(Float(rise), -0.02, Float(r * 0.7 * neck * neck), perRadius)
                                 : SIMD4(Float(x), 1.02, Float(drip), perRadius))
        }
        let columns = heads + stems
        for (k, uniform) in blobs.enumerated() {
            uniform.matrixFloat4x4Value = simd_float4x4(columns[4 * k], columns[4 * k + 1], columns[4 * k + 2], columns[4 * k + 3])
        }
    }

    /// Pushes the Settings sliders into the shader, and (re)schedules the colour cycle when its timing changes.
    @objc private func applySettings() {
        for knob in Self.knobs { knobUniforms[knob.key]?.floatValue = Float(knob.value) }
        flowSpeed = Self.knobs[0].value
        blobSize = Self.knobs[1].value
        layBlobs()
        let pinned = !(UserDefaults.standard.string(forKey: "lava.palette") ?? "").isEmpty
        let minutes = pinned ? 0 : Self.knobs[6].value.rounded()
        guard minutes != cycleMinutes else { return }
        cycleMinutes = minutes
        removeAction(forKey: "cycle")
        guard minutes > 0 else { return }
        run(.repeatForever(.sequence([.wait(forDuration: minutes * 60), .run { [weak self] in self?.cycle() }])),
            withKey: "cycle")
    }

    /// Eases every colour to another pairing over a minute, while the wax keeps moving. The pairing is tracked by
    /// index, since a finished blend isn't bit-for-bit the colours it aimed at.
    // ponytail: a straight RGB blend, so opposite pairings pass through a muddier middle; blend in a
    // perceptual space if that minute ever looks dull
    private func cycle() {
        let from = colours.map(\.vectorFloat3Value)
        current = set.indices.filter { $0 != current }.randomElement()!
        let to = set[current]
        run(.customAction(withDuration: 60) { [colours] _, elapsed in
            let k = Float(simd_smoothstep(0, 1, Double(elapsed) / 60))
            for (i, uniform) in colours.enumerated() { uniform.vectorFloat3Value = simd_mix(from[i], to[i], SIMD3(repeating: k)) }
        })
    }

    private static let source = """
    // One metaball r²/d², measured in a frame stretched sy times taller, with its gradient: (v, dv/dx, dv/dy).
    vec3 ball(vec2 p, vec2 c, float r, float sy) {
        vec2 d = p - c;
        float q = d.x * d.x + d.y * d.y / (sy * sy) + 0.00001;
        float v = r * r / q;
        return vec3(v, -2.0 * v / q * d.x, -2.0 * v / q * d.y / (sy * sy));
    }

    // A stem from an anchor a, on the pool or the top, to a head at b: thick at the anchor and thinner under the
    // head, so it necks just below it. Softened to 2r²/(d² + r²): still 1 at its radius, but it peaks at 2 on the
    // axis instead of spiking, so no bright seam runs up the middle and no dimple shows where it ends in the head.
    vec3 stem(vec2 p, vec2 a, vec2 b, float r) {
        vec2 ab = b - a;
        float h = clamp(dot(p - a, ab) / (dot(ab, ab) + 0.00001), 0.0, 1.0);
        vec2 d = p - a - ab * h;
        float rr = r * (1.0 - 0.7 * h);
        float w = dot(d, d) + rr * rr + 0.00015; // the constant keeps a vanishing thread's gradient from spiking
        float v = 2.0 * rr * rr / w;
        return vec3(v, -2.0 * v / w * d);
    }

    void main() {
        float aspect = u_size.x / u_size.y;
        float t = u_phase;
        vec2 p = v_tex_coord * vec2(aspect, 1.0);
        float x = v_tex_coord.x;
        float y = v_tex_coord.y;
        // a slow wobble in space so wax edges are soft and irregular, not perfect ellipses
        vec2 wobble = vec2(noise(p * 5.0 + t * 0.06), noise(p * 5.0 - t * 0.05 + 7.3)) - 0.5;
        vec2 q = p + u_wobble * wobble;

        // The wax field and its gradient (f), from the heads and stems laid out by layBlobs() plus the pool; wax
        // is wherever it passes 1. Alongside it, lp: each head's offset from its centre in radii, weighted by its
        // share of the field, so lp / f says where this pixel sits inside its blob (y from -1 underneath to +1 on
        // top), smoothly even where blobs merge. Column indices are clamped, since both sides of a ?: may be read.
        vec3 f = vec3(0.0);
        vec2 lp = vec2(0.0);
        for (int i = 0; i < 8; i++) {
            vec4 h = i < 4 ? u_blobs0[min(i, 3)] : u_blobs1[max(i - 4, 0)];
            vec4 k = i < 4 ? u_blobs2[min(i, 3)] : u_blobs3[max(i - 4, 0)];
            vec3 b = ball(q, h.xy, h.z, h.w);
            f += b + stem(q, k.xy, h.xy, k.z);
            lp += b.x * (q - h.xy) * k.w;
        }
        // the molten pool: a nearly flat surface, the heads resting in it make the bumps. Its lp only counts
        // below the surface, so the top of the pool stays pale and hot rather than dimming like the top of a blob.
        float surface = 0.03 + 0.006 * sin(q.x * 4.0 + t * 0.1) + 0.004 * sin(q.x * 9.0 - t * 0.13);
        float pd = max(q.y - surface, 0.002);
        float pv = 0.0028 / (pd * pd);
        f += vec3(pv, 0.0, -2.0 * pv / pd);
        lp += pv * vec2(0.0, clamp((q.y - surface) / 0.05, -1.0, 0.0));

        // Liquid: dark, lit by the bulb in a soft cone rising from the bottom, with the wax's own glow scattering
        // into it around every blob.
        float cone = exp(-pow((x - 0.5) / 0.6, 2.0)) * pow(1.0 - y, 1.3);
        vec3 col = mix(u_liquidDeep, u_liquidLit, 0.15 + 0.95 * cone * u_bulb);
        col += u_waxHot * u_glow * smoothstep(0.2, 1.0, f.x) * (1.2 - y);

        // Wax. 1/f is about (d/r)² near a blob, so sqrt(1 - 1/f) is its thickness: 0 at the edge, 1 in the core.
        float z = sqrt(max(1.0 - 1.0 / f.x, 0.0));
        vec2 dl = lp / f.x;
        // How much wax the light passes through: rises from the edge and levels off, so overlapping balls
        // don't show as hot spots where the field spikes at their centres.
        float thick = 1.0 - exp(-max(f.x - 1.0, 0.0) * 0.9);
        float heat = 1.0 - smoothstep(0.0, 0.95, y);
        // The only light is the bulb underneath, so each blob glows brightest on its underside and dims toward its
        // top, with the thick core still glowing from within. Satin wax, so a soft limb rather than a dark outline.
        float under = smoothstep(0.9, -0.9, dl.y);
        vec3 wax = mix(u_waxDeep, u_waxHot, clamp(0.15 + 0.5 * under + 0.25 * heat + 0.3 * thick, 0.0, 1.0));
        wax *= 0.7 + 0.4 * under + 0.2 * heat; // tops fall to the deep colour rather than darkening to brown
        wax *= 0.85 + 0.15 * z;
        wax += u_waxHot * (0.12 + 0.25 * heat) * thick * thick;                        // hot core glow
        wax += u_waxHot * 0.45 * pow(1.0 - z, 3.0) * under * (0.4 + heat);             // bulb through the thin underside
        vec3 n = normalize(vec3(dl * (1.0 - 0.7 * thick), z + 0.3));
        wax += vec3(0.06) * pow(max(dot(n, normalize(vec3(-0.35, 0.45, 0.82))), 0.0), 10.0); // faint satin sheen

        // A smooth edge one pixel wide, from the field's gradient. Thin wax is translucent, so the liquid's colour
        // shows through near the edge instead of a hard outline.
        float edge = clamp((f.x - 1.0) / (length(f.yz) * 0.75 / u_size.y + 0.0001) + 0.5, 0.0, 1.0);
        col = mix(col, wax, edge * (u_opacity + (1.0 - u_opacity) * smoothstep(0.0, 0.5, thick)));

        // Curved glass: darker toward the sides, with two soft vertical window reflections.
        col *= 0.62 + 0.38 * sin(3.14159 * x);
        col += vec3(0.035 * exp(-pow((x - 0.16) / 0.02, 2.0)) + 0.02 * exp(-pow((x - 0.87) / 0.035, 2.0)));
        col = grade(col, u_pivot, u_hue, u_saturation, u_contrast, u_brightness);
        col += (hash21(v_tex_coord * u_size * 2.0) - 0.5) / 128.0;
        gl_FragColor = vec4(col, 1.0);
    }
    """
}
