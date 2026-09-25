import SpriteKit
import simd

@MainActor func flowingGradient(size: CGSize) -> SKScene { FlowingGradient(size: size) }

/// Big, slowly drifting pools of navy, indigo, violet, soft blue, teal, magenta and a little dusky coral that melt
/// into one another with no visible edges, silk ribbons of light folding through them, and a fine film grain. The
/// mood follows the real Sun: warmer around sunrise and sunset, deeper and cooler at night, a touch brighter at
/// noon. Every knob is live in the Settings window.
final class FlowingGradient: SKScene {
    /// Sliders in the Settings window. Each drives the shader uniform named `u_` plus the last part of its key.
    nonisolated static let knobs = [
        Knob(key: "gradient.brightness", label: "Brightness", range: 0.2...1.2, standard: 0.6),
        Knob(key: "gradient.speed", label: "Flow speed", range: 0...3, standard: 1),
        Knob(key: "gradient.poolSize", label: "Pool size", range: 0.5...1.8, standard: 1),
        Knob(key: "gradient.ribbons", label: "Silk ribbons", range: 0...1, standard: 0.5),
        Knob(key: "gradient.ribbonWidth", label: "Ribbon width", range: 0.3...2.5, standard: 1),
        Knob(key: "gradient.grain", label: "Film grain", range: 0...1, standard: 0.35),
        Knob(key: "gradient.grainSize", label: "Grain size", range: 1...4, standard: 1.5),
        Knob(key: "gradient.followDay", label: "Follow the day", range: 0...1, standard: 0.7),
    ]
    /// Shows this hour today instead of now, while `gradient.previewTime` is on.
    nonisolated static let previewHour = Knob(key: "gradient.previewHour", label: "Time of day", range: 0...24, standard: 19)

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
        let sprite = SKSpriteNode(color: .black, size: size)
        sprite.anchorPoint = .zero
        let sizeUniform = SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)])
        sprite.shader = SKShader(source: shaderCommon + Self.source,
                                 uniforms: [sizeUniform, phase, golden, night, noon] + Array(knobUniforms.values))
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
        if UserDefaults.standard.bool(forKey: "gradient.previewTime") {
            date = Calendar.current.startOfDay(for: date).addingTimeInterval(Self.previewHour.value * 3600)
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

        // The pools add up like coloured light, so overlaps glow into new hues with no edge where one meets
        // another, and a soft exposure curve keeps bright overlaps from clipping while the gaps stay dark.
        vec3 light = vec3(0.02, 0.025, 0.09);
        light += vec3(0.07, 0.12, 0.42) * pool(q, drift(t, 0.45, 0.55, 1.2, aspect), 0.85 * r); // navy
        light += vec3(0.24, 0.12, 0.60) * pool(q, drift(t, 0.70, 0.50, 0.0, aspect), 0.70 * r); // indigo
        light += vec3(0.02, 0.48, 0.55) * pool(q, drift(t, 0.50, 0.80, 2.1, aspect), 0.62 * r); // teal
        light += vec3(0.40, 0.70, 1.20) * pool(q, drift(t, 0.60, 0.40, 4.0, aspect), 0.50 * r); // soft blue
        light += vec3(0.62, 0.12, 0.55) * (1.0 + 0.8 * golden) * pool(q, drift(t, 0.35, 0.65, 5.3, aspect), 0.50 * r); // magenta
        light += vec3(0.36, 0.18, 0.78) * pool(q, drift(t, 0.55, 0.30, 3.1, aspect), 0.60 * r); // violet
        light += vec3(0.70, 0.30, 0.30) * (1.0 + 2.0 * golden) * pool(q, drift(t, 0.28, 0.47, 0.7, aspect), 0.42 * r); // coral
        light *= mix(vec3(1.0), vec3(0.85, 0.9, 1.15), night) * mix(vec3(1.0), vec3(1.12, 0.97, 0.88), golden);

        // Silk ribbons: light folding through the colour, tinted by whatever lies beneath them.
        float silk = ribbon(q, t * 1.3, 0.62, 0.16, 1.6, 0.0, u_ribbonWidth)
                   + 0.8 * ribbon(q, t * 1.1, 0.36, 0.13, 2.1, 2.4, u_ribbonWidth);
        light += u_ribbons * silk * (light * 2.5 + vec3(0.05, 0.06, 0.12));

        float exposure = u_brightness * (1.0 - 0.35 * night) * (1.0 + 0.25 * noon);
        vec3 col = 1.0 - exp(-light * exposure);
        col *= 1.0 - 0.45 * length(v_tex_coord - 0.5); // vignette

        // Film grain: fine and fixed, stronger in the lights like real film; it also hides 8-bit banding.
        float g = hash21(floor(v_tex_coord * u_size * 2.0 / u_grainSize)) - 0.5;
        col += g * (1.0 / 128.0 + u_grain * (0.02 + 0.1 * dot(col, vec3(0.3, 0.5, 0.2))));
        gl_FragColor = vec4(col, 1.0);
    }
    """
}
