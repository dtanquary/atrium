import SpriteKit
import simd

@MainActor func flowingGradient(size: CGSize) -> SKScene { FlowingGradient(size: size) }

/// Big, slowly drifting pools of colour that melt into one another with no visible edges, silk ribbons folding
/// through them, and a fine film grain. In Dark Mode the pools glow like coloured light in the dark; in Light Mode
/// they're watercolour washes on pale paper, with the silk as a white sheen. The mood follows the real Sun: warmer
/// around sunrise and sunset, deeper and cooler at night, a touch brighter at noon. Every knob is live in Settings,
/// and the palette can be pinned there.
final class FlowingGradient: SKScene {
    /// Its Settings. Each drives the shader uniform named `u_` plus the last part of its key.
    nonisolated static let knobs = [
        Knob(key: "gradient.brightness", label: "Brightness", range: 0.2...1.2, standard: 0.6, section: "Look"),
        Knob(key: "gradient.speed", label: "Flow speed", range: 0...3, standard: 1, section: "Look"),
        Knob(key: "gradient.poolSize", label: "Pool size", range: 0.5...1.8, standard: 1, section: "Look"),
        Knob(key: "gradient.ribbonsOn", label: "Show ribbons", range: 0...1, standard: 1, section: "Silk Ribbons",
             format: .toggle),
        Knob(key: "gradient.ribbons", label: "Strength", range: 0...1, standard: 0.5, section: "Silk Ribbons",
             shownWhen: "gradient.ribbonsOn"),
        Knob(key: "gradient.ribbonWidth", label: "Width", range: 0.3...2.5, standard: 1, section: "Silk Ribbons",
             shownWhen: "gradient.ribbonsOn"),
        Knob(key: "gradient.grain", label: "Amount", range: 0...1, standard: 0.35, section: "Film Grain"),
        Knob(key: "gradient.grainSize", label: "Size", range: 1...4, standard: 1.5, section: "Film Grain"),
        Knob(key: "gradient.followDay", label: "Follow the day", range: 0...1, standard: 0.7, section: "Time of Day"),
        Knob(key: "gradient.previewTime", label: "Preview a time of day", range: 0...1, standard: 0, section: "Time of Day",
             format: .toggle),
        Knob(key: "gradient.previewHour", label: "Time", range: 0...24, standard: 19, section: "Time of Day",
             format: .clock, shownWhen: "gradient.previewTime"),
    ]

    /// Seven pool colours (for Dark Mode, as light) over a background. Slots 4 and 6 are the warm ones that swell
    /// at golden hour. Light Mode derives its washes from the same hues with `pastel`.
    nonisolated static let palettes: [(name: String, base: SIMD3<Float>, pools: [SIMD3<Float>])] = [
        ("Midnight", [0.02, 0.025, 0.09], [[0.07, 0.12, 0.42], [0.24, 0.12, 0.60], [0.02, 0.48, 0.55], [0.40, 0.70, 1.20],
                                          [0.62, 0.12, 0.55], [0.36, 0.18, 0.78], [0.70, 0.30, 0.30]]),
        ("Aurora", [0.01, 0.03, 0.05], [[0.02, 0.20, 0.22], [0.05, 0.45, 0.30], [0.02, 0.50, 0.60], [0.40, 1.10, 0.80],
                                       [0.45, 0.15, 0.70], [0.10, 0.30, 0.70], [0.60, 0.20, 0.60]]),
        ("Sunset", [0.05, 0.02, 0.05], [[0.25, 0.06, 0.28], [0.40, 0.10, 0.45], [0.75, 0.20, 0.35], [1.10, 0.70, 0.35],
                                       [0.85, 0.15, 0.40], [0.30, 0.10, 0.55], [1.00, 0.40, 0.20]]),
        ("Ocean", [0.01, 0.03, 0.07], [[0.02, 0.10, 0.35], [0.05, 0.20, 0.60], [0.02, 0.45, 0.55], [0.40, 0.90, 1.10],
                                      [0.15, 0.35, 0.85], [0.10, 0.55, 0.45], [0.30, 0.45, 0.90]]),
        ("Blush", [0.05, 0.03, 0.04], [[0.30, 0.10, 0.20], [0.50, 0.18, 0.35], [0.75, 0.35, 0.40], [1.10, 0.80, 0.65],
                                      [0.85, 0.30, 0.45], [0.40, 0.20, 0.45], [1.00, 0.55, 0.35]]),
        ("Graphite", [0.02, 0.02, 0.025], [[0.12, 0.13, 0.16], [0.22, 0.23, 0.28], [0.18, 0.22, 0.26], [0.55, 0.60, 0.70],
                                          [0.30, 0.28, 0.30], [0.20, 0.20, 0.30], [0.40, 0.36, 0.34]]),
    ]

    /// A Light Mode wash of a colour: its hue at full strength, mixed a little over halfway to white.
    nonisolated static func pastel(_ c: SIMD3<Float>) -> SIMD3<Float> {
        simd_mix(c / max(c.max(), 0.001), .one, SIMD3(repeating: 0.55))
    }

    /// Swatches for Settings: indigo, highlight and the two warm slots of each palette, in both looks.
    nonisolated static let paletteOptions = palettes.map { palette in
        let swatch = [1, 3, 4, 6].map { palette.pools[$0] }
        return (name: palette.name, dark: swatch, light: swatch.map(pastel))
    }

    private let knobUniforms: [String: SKUniform]
    private let phase = SKUniform(name: "u_phase", float: 0)
    private let golden = SKUniform(name: "u_golden", float: 0)
    private let night = SKUniform(name: "u_night", float: 0)
    private let noon = SKUniform(name: "u_noon", float: 0)
    private var flowSpeed = 1.0
    private var lastUpdate: TimeInterval?

    override init(size: CGSize) {
        knobUniforms = Dictionary(uniqueKeysWithValues: Self.knobs.map {
            ($0.key, SKUniform(name: "u_" + $0.key.split(separator: ".").last!, float: Float($0.standard)))
        })
        super.init(size: size)
        // The pinned palette (Midnight unless changed), or a random one if Settings says Random.
        let chosen = UserDefaults.standard.string(forKey: "gradient.palette") ?? "Midnight"
        let palette = Self.palettes.first { $0.name == chosen } ?? Self.palettes.randomElement()!
        let dark = systemIsDark
        let base = dark ? palette.base : simd_mix(.one, Self.pastel(palette.pools[1]), SIMD3(repeating: 0.06)) // tinted paper
        let colours = palette.pools.enumerated().map { i, c in SKUniform(name: "u_c\(i)", vectorFloat3: dark ? c : Self.pastel(c)) }

        let sprite = SKSpriteNode(color: .black, size: size)
        sprite.anchorPoint = .zero
        sprite.shader = SKShader(source: shaderCommon + Self.source, uniforms: [
            SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)]),
            SKUniform(name: "u_base", vectorFloat3: base), SKUniform(name: "u_lightMode", float: dark ? 0 : 1),
            phase, golden, night, noon,
        ] + colours + Array(knobUniforms.values))
        addChild(sprite)

        applySettings()
        NotificationCenter.default.addObserver(self, selector: #selector(applySettings),
                                               name: UserDefaults.didChangeNotification, object: nil)
        run(.repeatForever(.sequence([.wait(forDuration: 60), .run { [weak self] in self?.applySettings() }])))
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func didMove(to view: SKView) {
        Location.shared.start()
    }

    override func update(_ currentTime: TimeInterval) {
        defer { lastUpdate = currentTime }
        guard let last = lastUpdate else { return }
        // Integrated rather than u_time * speed, so moving the speed slider never makes the pools jump.
        phase.floatValue += Float(min(max(currentTime - last, 0), 0.5) * 0.04 * flowSpeed)
    }

    /// Pushes the Settings sliders and the Sun's mood into the shader. Runs on any settings change and every minute.
    @objc private func applySettings() {
        for knob in Self.knobs { knobUniforms[knob.key]?.floatValue = Float(knob.value) }
        flowSpeed = Self.knobs[1].value

        var date = Date()
        if Self.knobs[9].value > 0.5 { // previewing a time of day
            date = Calendar.current.startOfDay(for: date).addingTimeInterval(Self.knobs[10].value * 3600)
        }
        let here = Location.shared.coordinate, jd = Sky.julianDate(date)
        let sun = Sky.horizonMatrix(jd: jd, latitude: here.latitude, longitude: here.longitude) * Sky.sun(jd)
        let altitude = asin(sun.z) * 180 / .pi
        golden.floatValue = Float(exp(-pow((altitude - 2) / 8, 2))) // peaks with the Sun on the horizon
        night.floatValue = Float(1 - simd_smoothstep(-18, -4, altitude))
        noon.floatValue = Float(simd_smoothstep(15, 55, altitude))
    }

    private static let source = """
    // A soft gaussian glow centred on c.
    float pool(vec2 p, vec2 c, float r) { float d = length(p - c) / r; return exp(-d * d); }

    // Each pool drifts on its own slow Lissajous path, roaming a little past the screen edges.
    vec2 drift(float t, float a, float b, float phase, float aspect) {
        return vec2(aspect * (0.5 + 0.6 * sin(t * a + phase)), 0.5 + 0.6 * cos(t * b + phase * 1.7));
    }

    // A silk ribbon along a slow wave: fine strands that spread apart and pinch together as the ribbon twists, so
    // bright folds travel along it, wrapped in a soft glow.
    float ribbon(vec2 p, float t, float y0, float amp, float freq, float phase, float width) {
        float y = y0 + amp * sin(p.x * freq + t + phase) + 0.05 * sin(p.x * freq * 2.7 - t * 1.4 + phase);
        float twist = cos(p.x * freq * 0.8 - t * 0.9 + phase * 1.7);
        float d = p.y - y;
        float thin = 0.006 * width + 0.003;
        float strands = 0.0;
        for (int k = 0; k < 5; k++) {
            float e = (d - (float(k) - 2.0) * 0.03 * width * twist) / thin;
            strands += exp(-e * e);
        }
        float g = d / (0.07 * width * (0.35 + 0.65 * abs(twist)));
        return strands * 0.18 * (0.4 + 0.6 * (1.0 - abs(twist))) + 0.25 * exp(-g * g);
    }

    void main() {
        float aspect = u_size.x / u_size.y;
        vec2 p = v_tex_coord * vec2(aspect, 1.0);
        float t = u_phase;
        // bend the plane with slow, broad noise so pools smear into each other instead of sliding as circles
        vec2 q = p + 0.5 * (vec2(noise(p * 0.9 + t), noise(p * 0.9 - t + 5.2)) - 0.5);
        float r = u_poolSize;

        // Mood from the Sun: golden hour feeds the coral and magenta, night deepens and cools, noon lifts it.
        float golden = u_golden * u_followDay;
        float night = u_night * u_followDay;
        float noon = u_noon * u_followDay;

        // Seven pools, each drifting on its own path; slots 4 and 6 are the warm ones that swell at golden hour.
        float w0 = pool(q, drift(t, 0.45, 0.55, 1.2, aspect), 0.85 * r);
        float w1 = pool(q, drift(t, 0.70, 0.50, 0.0, aspect), 0.70 * r);
        float w2 = pool(q, drift(t, 0.50, 0.80, 2.1, aspect), 0.62 * r);
        float w3 = pool(q, drift(t, 0.60, 0.40, 4.0, aspect), 0.50 * r);
        float w4 = pool(q, drift(t, 0.35, 0.65, 5.3, aspect), 0.50 * r) * (1.0 + 0.8 * golden);
        float w5 = pool(q, drift(t, 0.55, 0.30, 3.1, aspect), 0.60 * r);
        float w6 = pool(q, drift(t, 0.28, 0.47, 0.7, aspect), 0.42 * r) * (1.0 + 2.0 * golden);
        float silk = u_ribbonsOn * u_ribbons * (ribbon(q, t * 1.3, 0.62, 0.16, 1.6, 0.0, u_ribbonWidth)
                                               + 0.8 * ribbon(q, t * 1.1, 0.36, 0.13, 2.1, 2.4, u_ribbonWidth));
        vec3 col;
        if (u_lightMode < 0.5) {
            // Dark Mode: the pools add up like coloured light, so overlaps glow into new hues with no edge, and a
            // soft exposure curve keeps bright overlaps from clipping while the gaps stay dark.
            vec3 light = u_base + u_c0 * w0 + u_c1 * w1 + u_c2 * w2 + u_c3 * w3 + u_c4 * w4 + u_c5 * w5 + u_c6 * w6;
            light *= mix(vec3(1.0), vec3(0.85, 0.9, 1.15), night) * mix(vec3(1.0), vec3(1.12, 0.97, 0.88), golden);
            light += silk * (light * 2.5 + vec3(0.05, 0.06, 0.12)); // silk: light folding through, tinted by what's beneath
            float exposure = u_brightness * (1.0 - 0.35 * night) * (1.0 + 0.25 * noon);
            col = 1.0 - exp(-light * exposure);
            col *= 1.0 - 0.45 * length(v_tex_coord - 0.5); // vignette
        } else {
            // Light Mode: each pool is a watercolour wash on pale paper, absorbing the light its colour lacks, so
            // overlaps deepen into new hues. Night deepens the washes a little; golden hour warms the paper.
            vec3 ink = (1.0 - u_c0) * w0 + (1.0 - u_c1) * w1 + (1.0 - u_c2) * w2 + (1.0 - u_c3) * w3
                     + (1.0 - u_c4) * w4 + (1.0 - u_c5) * w5 + (1.0 - u_c6) * w6;
            col = u_base * exp(-ink * (0.3 / u_brightness) * (1.0 + 0.3 * night - 0.15 * noon));
            col *= mix(vec3(1.0), vec3(1.03, 0.99, 0.94), golden) * mix(vec3(1.0), vec3(0.95, 0.97, 1.02), night);
            col = mix(col, vec3(1.0), clamp(silk * 0.9, 0.0, 0.8)); // silk: a white sheen
            col *= 1.0 - 0.12 * length(v_tex_coord - 0.5); // soft vignette
        }

        // Film grain: fine and fixed, stronger in the lights like real film; it also hides 8-bit banding.
        float g = hash21(floor(v_tex_coord * u_size * 2.0 / u_grainSize)) - 0.5;
        col += g * (1.0 / 128.0 + u_grain * (0.02 + 0.1 * dot(col, vec3(0.3, 0.5, 0.2))));
        gl_FragColor = vec4(col, 1.0);
    }
    """
}
