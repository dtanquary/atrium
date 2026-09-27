import SpriteKit

/// Rain on Glass colours: the sky behind the glass (top, then the glow low down) at night and by day, and five light
/// tints from most to least common. Every palette follows the system: lit up at night in Dark Mode, an overcast
/// day in Light Mode, where the same lights read as coloured blurs.
let rainPalettes: [(name: String, night: [SIMD3<Float>], day: [SIMD3<Float>], lights: [SIMD3<Float>])] = [
    ("City", [[0.015, 0.02, 0.05], [0.13, 0.08, 0.10]], [[0.90, 0.91, 0.93], [0.80, 0.79, 0.79]],     // sodium, warm white,
     [[1.0, 0.62, 0.28], [1.0, 0.85, 0.55], [1.0, 0.25, 0.2], [0.6, 0.75, 1.0], [0.3, 1.0, 0.6]]),   // tail lights, LEDs
    ("Neon", [[0.02, 0.01, 0.06], [0.12, 0.04, 0.16]], [[0.92, 0.90, 0.96], [0.84, 0.79, 0.88]],
     [[1.0, 0.2, 0.7], [0.2, 0.85, 1.0], [0.6, 0.35, 1.0], [0.3, 0.45, 1.0], [1.0, 0.7, 0.2]]),
    ("Blue Hour", [[0.02, 0.04, 0.10], [0.06, 0.10, 0.20]], [[0.86, 0.90, 0.96], [0.76, 0.81, 0.89]],
     [[0.8, 0.9, 1.0], [0.45, 0.65, 1.0], [1.0, 0.8, 0.5], [0.4, 0.9, 0.9], [1.0, 0.3, 0.3]]),
    ("Sunset", [[0.06, 0.02, 0.08], [0.22, 0.08, 0.06]], [[0.96, 0.90, 0.88], [0.93, 0.82, 0.76]],
     [[1.0, 0.72, 0.3], [1.0, 0.45, 0.45], [1.0, 0.55, 0.2], [0.75, 0.55, 1.0], [1.0, 0.9, 0.75]]),
    ("Harbor", [[0.01, 0.04, 0.06], [0.03, 0.10, 0.12]], [[0.87, 0.92, 0.92], [0.76, 0.84, 0.84]],   // channel markers
     [[0.3, 0.9, 0.85], [1.0, 0.85, 0.6], [0.3, 1.0, 0.5], [1.0, 0.3, 0.25], [1.0, 0.6, 0.3]]),
    ("Holiday", [[0.02, 0.02, 0.04], [0.10, 0.05, 0.04]], [[0.93, 0.93, 0.94], [0.84, 0.82, 0.80]],
     [[1.0, 0.8, 0.5], [1.0, 0.2, 0.2], [0.2, 0.9, 0.4], [1.0, 0.7, 0.25], [0.4, 0.55, 1.0]]),
    ("Graphite", [[0.02, 0.02, 0.025], [0.08, 0.08, 0.09]], [[0.92, 0.92, 0.93], [0.80, 0.80, 0.81]],
     [[0.95, 0.95, 1.0], [0.75, 0.78, 0.85], [0.85, 0.85, 0.85], [0.9, 0.85, 0.8], [0.7, 0.8, 0.95]]),
]

/// A city out of focus behind a rainy window: beads of water and drops sliding down, each drop a little lens
/// showing the lights sharper. Night in Dark Mode, an overcast day in Light Mode, in the palette from Settings.
@MainActor func rainOnGlass(size: CGSize) -> SKScene {
    let palette = rainPalettes.first { $0.name == UserDefaults.standard.string(forKey: "rain.palette") }
        ?? rainPalettes.randomElement()!
    let sky = systemIsDark ? palette.night : palette.day
    let l = palette.lights
    return shaderScene(size: size, source: shaderCommon + """
    // One layer of bokeh lights, one per grid cell. blur 1 = out of focus (big soft discs), 0 = sharp points.
    // Returns (tint * strength, strength); the tints come in as matrix columns since only main() sees uniforms.
    vec4 bokeh(vec2 p, float cell, float blur, float seed, mat3 a, mat3 b) {
        vec2 id = floor(p / cell);
        float h = hash21(id + seed);
        if (h < 0.45) { return vec4(0.0); }
        vec2 off = (vec2(hash21(id + seed + 1.3), hash21(id + seed + 2.7)) - 0.5) * 0.5;
        float r = (0.13 + 0.12 * hash21(id + seed + 4.1)) * mix(0.25, 1.0, blur);
        float d = length(fract(p / cell) - 0.5 - off);
        float disc = smoothstep(r, r - mix(0.015, 0.1, blur), d) * (0.75 + 0.25 * smoothstep(r * 0.4, r, d));
        float k = hash21(id + seed + 6.6);
        vec3 tint = k < 0.45 ? a[0] : k < 0.65 ? a[1] : k < 0.8 ? a[2] : k < 0.93 ? b[0] : b[1];
        return vec4(tint, 1.0) * disc * (0.25 + 0.5 * h) * mix(1.6, 1.0, blur);
    }

    // The street behind the glass: light-polluted haze low down, lights mostly in the lower half, and a band of
    // traffic crawling along. `sky` holds the top and low colours; `day` is 1 in Light Mode.
    vec3 city(vec2 p, float blur, float t, mat3 sky, mat3 a, mat3 b, float day) {
        vec3 col = mix(sky[1], sky[0], smoothstep(0.0, 0.9, p.y));
        float low = smoothstep(0.95, 0.25, p.y);
        float lane1 = (p.y - 0.27) / 0.06;
        float lane2 = (p.y - 0.2) / 0.05;
        vec4 lights = bokeh(p, 0.19, blur, 1.0, a, b) * low
                    + bokeh(p + vec2(0.37, 0.11), 0.13, blur, 7.0, a, b) * low * 0.8
                    + bokeh(p * mat2(0.8, 0.6, -0.6, 0.8) + vec2(3.1, 0.7), 0.09, blur, 23.0, a, b) * low * 0.6
                    + bokeh(p + vec2(t * 0.012, 0.0), 0.08, blur, 13.0, a, b) * exp(-lane1 * lane1)
                    + bokeh(p - vec2(t * 0.009, 0.0), 0.07, blur, 19.0, a, b) * exp(-lane2 * lane2) * 0.8;
        // night: lights add on, and condensation scatters them into a haze.
        // day: the same lights read as coloured blurs, and fog whitens the glass.
        vec3 night = col + sky[1] * 0.55 * low * blur + lights.rgb;
        vec3 lit = col * exp(-1.3 * (lights.a - 0.8 * lights.rgb));
        return mix(night, mix(lit, vec3(1.0), 0.15 * blur), day);
    }

    // Condensation: a bead per small cell that slowly forms and evaporates.
    // Drop functions return (position inside the drop on a unit disc, coverage, radius).
    vec4 beads(vec2 p, float t) {
        float cell = 0.03;
        vec2 id = floor(p / cell);
        float h = hash21(id);
        vec2 off = (vec2(hash21(id + 1.7), hash21(id + 3.1)) - 0.5) * 0.45;
        float life = fract(t * 0.02 + h);
        float r = (0.1 + 0.22 * pow(hash21(id + 5.3), 3.0)) * smoothstep(0.0, 0.1, life) * smoothstep(1.0, 0.8, life);
        r *= step(0.3, h);
        vec2 d = (fract(p / cell) - 0.5 - off) / max(r, 0.001);
        return vec4(d, smoothstep(1.0, 0.8, length(d)), r * cell);
    }

    // The big drop in p's column, (x, y, radius): one per column, sliding down in stick-slip lurches.
    vec3 slider(vec2 p, float t, float w, float seed) {
        float column = floor(p.x / w);
        float h = hash11(column * 3.7 + seed);
        float ph = t * (0.04 + 0.06 * h) + h * 10.0;
        float y = 1.15 - fract(ph + 0.12 * sin(ph * 6.2831)) * 1.35;       // lurch, pause, lurch
        float x = (column + 0.5 + (h - 0.5) * 0.4) * w + 0.004 * sin(p.y * 35.0 + h * 20.0);
        return vec3(x, y, w * (0.14 + 0.08 * h) * step(0.3, hash11(column + seed * 2.0)));
    }

    // How much a slider's trail has wiped the fog at p.
    float trail(vec2 p, vec3 s) {
        float above = p.y - s.y;
        return step(0.0, above) * smoothstep(0.3, 0.0, above) * smoothstep(s.z, s.z * 0.4, abs(p.x - s.x));
    }

    // The slider under p, or one of the beads it left behind, shrinking with age.
    vec4 drops(vec2 p, vec3 s, float w, float seed) {
        float r = s.z;
        vec2 d = p - s.xy;
        d.y /= d.y > 0.0 ? 1.5 : 1.0;                                      // teardrop: tail stretches upward
        vec4 drop = vec4(d / max(r, 0.001), smoothstep(r, r * 0.85, length(d)), r);

        float column = floor(p.x / w);
        float above = p.y - s.y;
        float spacing = r * 1.6;
        float k = floor(above / spacing);
        float br = r * (0.2 + 0.25 * hash21(vec2(column, k) + seed)) * smoothstep(0.3, 0.05, above) * step(1.0, k);
        vec2 bd = vec2(p.x - s.x + (hash21(vec2(k, column)) - 0.5) * r * 0.6, (fract(above / spacing) - 0.5) * spacing);
        vec4 bead = vec4(bd / max(br, 0.0001), smoothstep(br, br * 0.8, length(bd)) * trail(p, s), br);
        return bead.z > drop.z ? bead : drop;
    }

    void main() {
        float aspect = u_size.x / u_size.y;
        vec2 p = v_tex_coord * vec2(aspect, 1.0);
        float t = u_time;

        vec4 drop = beads(p, t);
        vec3 s1 = slider(p, t, 0.1, 1.0);
        vec2 p2 = p + vec2(0.043, 0.0);
        vec3 s2 = slider(p2, t * 0.85, 0.065, 9.0);
        vec4 big = drops(p, s1, 0.1, 1.0);
        if (big.z > drop.z) { drop = big; }
        big = drops(p2, s2, 0.065, 9.0);
        if (big.z > drop.z) { drop = big; }
        float wiped = max(trail(p, s1), trail(p2, s2));

        // the fogged glass, cleared a little along fresh trails
        // (branches skip the extra city lookups on the dry glass, which is most of the screen)
        mat3 sky = mat3(u_top, u_low, vec3(0.0));
        mat3 a = mat3(u_l0, u_l1, u_l2);
        mat3 b = mat3(u_l3, u_l4, vec3(0.0));
        vec3 col = city(p, 1.0, t, sky, a, b, u_day);
        if (wiped > 0.0) { col = mix(col, city(p, 0.45, t, sky, a, b, u_day), wiped * 0.8); }
        // each drop is a small lens: a flipped, sharper view of the lights around it,
        // darker toward its rim, with a highlight up-left
        // ponytail: a fixed-width lens, not real refraction; enough to read as water
        if (drop.z > 0.0) {
            vec3 through = city(p - drop.xy * 0.07, 0.2, t, sky, a, b, u_day) * mix(1.3, 1.05, u_day)
                         + u_low * 0.4 * (1.0 - u_day) * smoothstep(0.95, 0.25, p.y);
            through *= 1.0 - 0.5 * smoothstep(0.5, 1.0, length(drop.xy));
            through += 0.25 * smoothstep(0.35, 0.0, length(drop.xy - vec2(-0.35, 0.4)));
            col = mix(col, through, drop.z);
        }

        col = grade(col, mix(0.3, 0.7, u_day), u_hue, u_saturation, u_contrast, u_brightness);
        col += (hash21(v_tex_coord * u_size * 2.0) - 0.5) / 128.0;
        gl_FragColor = vec4(col, 1.0);
    }
    """, uniforms: [
        SKUniform(name: "u_top", vectorFloat3: sky[0]), SKUniform(name: "u_low", vectorFloat3: sky[1]),
        SKUniform(name: "u_l0", vectorFloat3: l[0]), SKUniform(name: "u_l1", vectorFloat3: l[1]),
        SKUniform(name: "u_l2", vectorFloat3: l[2]), SKUniform(name: "u_l3", vectorFloat3: l[3]),
        SKUniform(name: "u_l4", vectorFloat3: l[4]), SKUniform(name: "u_day", float: systemIsDark ? 0 : 1),
    ], knobs: gradeKnobs("rain"))
}
