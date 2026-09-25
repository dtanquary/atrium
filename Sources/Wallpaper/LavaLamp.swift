import SpriteKit

/// The inside of a lava lamp, full screen. Wax heats in a molten pool at the bottom, rises as stretched teardrops
/// that pinch off on thin necks, slumps wide as it cools near the top, and sinks back. It glows from within, lit
/// by the bulb below. Each load rolls a classic lamp colour pairing and its own blobs. Left running, the lamp
/// eases to another pairing every few minutes while the wax keeps moving.
@MainActor func lavaLamp(size: CGSize) -> SKScene {
    // Wax (thin and deep, thick and hot) and liquid (dark, bulb-lit), after real lamp pairings.
    let palettes: [[SIMD3<Float>]] = [
        [[0.55, 0.08, 0.02], [1.00, 0.55, 0.12], [0.05, 0.005, 0.02], [0.40, 0.04, 0.08]], // orange in red
        [[0.45, 0.02, 0.03], [0.95, 0.22, 0.12], [0.10, 0.05, 0.00], [0.62, 0.40, 0.06]],  // red in yellow, the 1963 original
        [[0.05, 0.10, 0.45], [0.35, 0.65, 1.00], [0.03, 0.01, 0.06], [0.30, 0.08, 0.45]],  // blue in violet
        [[0.05, 0.35, 0.08], [0.55, 1.00, 0.35], [0.00, 0.02, 0.06], [0.05, 0.18, 0.50]],  // green in blue
        [[0.55, 0.06, 0.28], [1.00, 0.50, 0.75], [0.04, 0.01, 0.06], [0.30, 0.06, 0.42]],  // pink in purple
        [[0.55, 0.62, 0.70], [1.00, 0.98, 0.94], [0.00, 0.02, 0.07], [0.05, 0.25, 0.60]],  // white in blue
        [[0.25, 0.05, 0.40], [0.72, 0.40, 0.95], [0.05, 0.04, 0.03], [0.55, 0.45, 0.30]],  // purple in clear
        [[0.60, 0.40, 0.00], [1.00, 0.90, 0.35], [0.03, 0.00, 0.05], [0.35, 0.05, 0.40]],  // yellow in purple
    ]
    let colours = zip(["u_waxDeep", "u_waxHot", "u_liquidDeep", "u_liquidLit"], palettes.randomElement()!)
        .map { SKUniform(name: $0, vectorFloat3: $1) }
    let seed = SKUniform(name: "u_seed", float: .random(in: 0...100))

    let scene = shaderScene(size: size, source: shaderCommon + """
    // Height of a blob along its trip (phase 0..1): it rests in the pool, rises, lingers at the top as it cools,
    // then sinks back more slowly than it rose.
    float height(float s) { return smoothstep(0.06, 0.42, s) - smoothstep(0.52, 0.96, s); }

    // One metaball r²/d², measured in a frame stretched sy times taller, with its gradient: (v, dv/dx, dv/dy).
    vec3 ball(vec2 p, vec2 c, float r, float sy) {
        vec2 d = p - c;
        float q = d.x * d.x + d.y * d.y / (sy * sy) + 0.00001;
        float v = r * r / q;
        return vec3(v, -2.0 * v / q * d.x, -2.0 * v / q * d.y / (sy * sy));
    }

    // The whole wax field and its gradient. Wax is wherever it passes 1. The pool along the bottom joins in, so
    // blobs rise off it on necks, and each blob drags a smaller tail behind its motion so rising wax trails a neck
    // that thins and pinches off, and sinking wax drips from above.
    vec3 field(vec2 p, float t, float aspect, float seed) {
        vec3 f = vec3(0.0);
        for (int i = 0; i < 8; i++) {
            float fi = float(i) + seed;
            float h1 = hash11(fi + 0.13);
            float h2 = hash11(fi + 0.57);
            float h3 = hash11(fi + 0.91);
            float r = 0.045 + 0.075 * h1 * h1;                          // mostly small, a few big
            float s = fract(t / (55.0 + 50.0 * h2) + h3);                // one trip every 55-105 s
            float h = height(s);
            float speed = (height(s + 0.01) - height(s - 0.01)) * 12.0;  // about +1 rising, -0.8 sinking
            float y = mix(-0.06, 0.62 + 0.3 * h2, h);                   // resting blobs sit down in the pool
            float x = aspect * (0.08 + 0.84 * fract(h3 * 13.7)) + 0.05 * sin(t * 0.02 + fi * 2.0);
            // moving wax stretches tall; resting at the top it slumps wide
            float sy = 1.0 + 0.9 * abs(speed) - 0.3 * smoothstep(0.85, 1.0, h) * (1.0 - min(abs(speed), 1.0));
            f += ball(p, vec2(x, y), r, sy);
            f += ball(p, vec2(x, y - 1.8 * r * speed), r * 0.55, sy);
        }
        // the molten pool: a gently heaving surface near the bottom
        float surface = 0.03 + 0.018 * sin(p.x * 4.0 + t * 0.15) + 0.01 * sin(p.x * 9.0 - t * 0.22);
        float d = max(p.y - surface, 0.002);
        float v = 0.0028 / (d * d);
        return f + vec3(v, 0.0, -2.0 * v / d);
    }

    void main() {
        float aspect = u_size.x / u_size.y;
        float t = u_time;
        vec2 p = v_tex_coord * vec2(aspect, 1.0);
        float x = v_tex_coord.x;
        float y = v_tex_coord.y;
        // a slow wobble in space so wax edges are soft and irregular, not perfect ellipses
        vec2 wobble = vec2(noise(p * 5.0 + t * 0.06), noise(p * 5.0 - t * 0.05 + 7.3)) - 0.5;
        vec3 f = field(p + 0.018 * wobble, t, aspect, u_seed);

        // Liquid: dark, lit by the bulb in a soft cone rising from the bottom, with the wax's own glow scattering
        // into it around every blob.
        float cone = exp(-pow((x - 0.5) / 0.6, 2.0)) * pow(1.0 - y, 1.3);
        vec3 col = mix(u_liquidDeep, u_liquidLit, 0.15 + 0.95 * cone);
        col += u_waxHot * 0.3 * smoothstep(0.2, 1.0, f.x) * (1.2 - y);

        // Wax. 1/f is about (d/r)² near a blob, so sqrt(1 - 1/f) is its thickness: 0 at the edge, 1 in the core.
        float g = 1.0 / f.x;
        float z = sqrt(max(1.0 - g, 0.0));
        // How much wax the light passes through: rises from the edge and levels off, so overlapping balls
        // don't show as hot spots where the field spikes at their centres.
        float thick = 1.0 - exp(-max(f.x - 1.0, 0.0) * 0.9);
        // Curvature mostly near the edge: deep inside, overlapping balls would otherwise dimple the surface.
        vec3 n = normalize(vec3(-f.yz * g * g * 0.05 / max(z, 0.08) * (1.0 - 0.8 * thick), 1.0));
        float heat = 1.0 - smoothstep(0.0, 0.95, y);
        // subsurface: thick, hot wax glows light from within, thin edges run deep and saturated
        vec3 wax = mix(u_waxDeep, u_waxHot, thick * (0.6 + 0.4 * heat));
        wax += u_waxHot * 0.3 * thick * thick * heat;                                          // hot core glow
        wax *= 0.72 + 0.35 * max(dot(n, normalize(vec3(0.0, -0.8, 0.6))), 0.0) + 0.25 * heat; // lit from below
        wax += u_waxHot * pow(1.0 - z, 3.0) * max(-n.y, 0.0) * 0.6 * (0.4 + heat);          // bulb through thin undersides
        wax += vec3(0.12) * pow(max(dot(n, normalize(vec3(-0.35, 0.45, 0.82))), 0.0), 18.0); // satin sheen, not glass

        // A smooth edge one pixel wide, from the field's gradient. Thin wax is translucent, so the liquid's colour
        // shows through near the edge instead of a hard outline.
        float edge = clamp((f.x - 1.0) / (length(f.yz) * 0.75 / u_size.y + 0.0001) + 0.5, 0.0, 1.0);
        col = mix(col, wax, edge * (0.72 + 0.28 * smoothstep(0.0, 0.5, thick)));

        // Curved glass: darker toward the sides, with two soft vertical window reflections.
        col *= 0.62 + 0.38 * sin(3.14159 * x);
        col += vec3(0.035 * exp(-pow((x - 0.16) / 0.02, 2.0)) + 0.02 * exp(-pow((x - 0.87) / 0.035, 2.0)));
        col += (hash21(v_tex_coord * u_size * 2.0) - 0.5) / 128.0;
        gl_FragColor = vec4(col, 1.0);
    }
    """, uniforms: colours + [seed])

    // Every few minutes ease every colour to another pairing over a minute, while the wax keeps moving.
    // ponytail: a straight RGB blend, so opposite pairings pass through a muddier middle; blend in a
    // perceptual space if that minute ever looks dull
    scene.run(.repeatForever(.sequence([.wait(forDuration: 8 * 60), .run { [weak scene] in
        let from = colours.map(\.vectorFloat3Value)
        let to = palettes.filter { $0[1] != from[1] }.randomElement()!
        scene?.run(.customAction(withDuration: 60) { _, elapsed in
            let k = Float(simd_smoothstep(0, 1, Double(elapsed) / 60))
            for (i, uniform) in colours.enumerated() { uniform.vectorFloat3Value = simd_mix(from[i], to[i], SIMD3(repeating: k)) }
        })
    }])))
    return scene
}
