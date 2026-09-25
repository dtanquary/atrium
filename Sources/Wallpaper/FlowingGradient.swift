import SpriteKit

/// Big, slowly drifting pools of navy, indigo, violet, soft blue, teal, magenta and a little dusky coral that
/// melt into one another with no visible edges. The quiet default.
@MainActor func flowingGradient(size: CGSize) -> SKScene {
    shaderScene(size: size, source: shaderCommon + """
    // A soft gaussian glow centred on c.
    float pool(vec2 p, vec2 c, float r) { float d = length(p - c) / r; return exp(-d * d); }

    // Each pool drifts on its own slow Lissajous path, roaming a little past the screen edges.
    vec2 drift(float t, float a, float b, float phase, float aspect) {
        return vec2(aspect * (0.5 + 0.6 * sin(t * a + phase)), 0.5 + 0.6 * cos(t * b + phase * 1.7));
    }

    void main() {
        float aspect = u_size.x / u_size.y;
        vec2 p = v_tex_coord * vec2(aspect, 1.0);
        float t = u_time * 0.04;
        // bend the plane with slow, broad noise so pools smear into each other instead of sliding as circles
        p += 0.5 * (vec2(noise(p * 0.9 + t), noise(p * 0.9 - t + 5.2)) - 0.5);

        // The pools add up like coloured light, so overlaps glow into new hues with no edge where one meets
        // another, and a soft exposure curve keeps bright overlaps from clipping while the gaps stay dark.
        vec3 light = vec3(0.02, 0.025, 0.09);
        light += vec3(0.07, 0.12, 0.42) * pool(p, drift(t, 0.45, 0.55, 1.2, aspect), 0.85); // navy
        light += vec3(0.24, 0.12, 0.60) * pool(p, drift(t, 0.70, 0.50, 0.0, aspect), 0.70); // indigo
        light += vec3(0.02, 0.48, 0.55) * pool(p, drift(t, 0.50, 0.80, 2.1, aspect), 0.62); // teal
        light += vec3(0.40, 0.70, 1.20) * pool(p, drift(t, 0.60, 0.40, 4.0, aspect), 0.50); // soft blue
        light += vec3(0.62, 0.12, 0.55) * pool(p, drift(t, 0.35, 0.65, 5.3, aspect), 0.50); // magenta
        light += vec3(0.36, 0.18, 0.78) * pool(p, drift(t, 0.55, 0.30, 3.1, aspect), 0.60); // violet
        light += vec3(0.70, 0.30, 0.30) * pool(p, drift(t, 0.28, 0.47, 0.7, aspect), 0.42); // dusky coral
        vec3 col = 1.0 - exp(-light * 0.6);

        col *= 1.0 - 0.45 * length(v_tex_coord - 0.5);            // vignette
        col += (hash21(v_tex_coord * u_size * 2.0) - 0.5) / 128.0;  // dither away 8-bit banding
        gl_FragColor = vec4(col, 1.0);
    }
    """)
}
