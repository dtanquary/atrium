import SpriteKit

// Full-screen shader wallpapers, each one SKShader over the whole scene (see shaderScene in Scenes.swift).
// Shaders work in `p = v_tex_coord * vec2(aspect, 1)`: y runs 0...1 up the screen and x keeps the same scale,
// so shapes stay round on any display. `pts` is the same point in screen points, for pixel-sized detail.

/// Hashes, value noise, fbm and a star field shared by the shaders below.
private let common = """
float hash11(float x) { return fract(sin(x * 127.1) * 43758.5453); }

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
               mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = p * 2.03 + vec2(1.7, 9.2);
        a *= 0.5;
    }
    return v;
}

// One star per `cell`-point grid square, kept with probability `density`; most faint, a few bright, all twinkling.
float starField(vec2 pts, float cell, float density, float t) {
    vec2 id = floor(pts / cell);
    float h = hash21(id);
    if (h > density) { return 0.0; }
    vec2 off = (vec2(hash21(id + 1.9), hash21(id + 4.3)) - 0.5) * 0.7;
    float mag = pow(hash21(id + 7.7), 5.0);
    float d = length(fract(pts / cell) - 0.5 - off) * cell;
    float twinkle = 0.8 + 0.2 * sin(t * (1.0 + 3.0 * h) + h * 50.0);
    return (smoothstep(0.6 + 1.2 * mag, 0.0, d) + 0.3 * mag * exp(-d * 0.4)) * (0.3 + 0.9 * mag) * twinkle;
}

"""

/// Slowly drifting fields of navy, indigo, soft blue, teal and a touch of magenta. The quiet default.
@MainActor func flowingGradient(size: CGSize) -> SKScene {
    shaderScene(size: size, source: common + """
    // A soft gaussian pool of colour centred on c.
    float pool(vec2 p, vec2 c, float r) { float d = length(p - c) / r; return exp(-d * d); }

    // Each pool drifts on its own slow Lissajous path across the screen.
    vec2 drift(float t, float a, float b, float phase, float aspect) {
        return vec2(aspect * (0.5 + 0.5 * sin(t * a + phase)), 0.5 + 0.5 * cos(t * b + phase * 1.7));
    }

    void main() {
        float aspect = u_size.x / u_size.y;
        vec2 p = v_tex_coord * vec2(aspect, 1.0);
        float t = u_time * 0.04;
        // bend the plane with slow noise so pools flow and smear instead of sliding as circles
        p += 0.35 * (vec2(noise(p * 1.2 + t), noise(p * 1.2 - t + 5.2)) - 0.5);

        vec3 col = vec3(0.012, 0.016, 0.06);
        col = mix(col, vec3(0.05, 0.09, 0.30), pool(p, drift(t, 0.45, 0.55, 1.2, aspect), 0.60));
        col = mix(col, vec3(0.17, 0.10, 0.42), pool(p, drift(t, 0.70, 0.50, 0.0, aspect), 0.55));
        col = mix(col, vec3(0.03, 0.34, 0.40), pool(p, drift(t, 0.50, 0.80, 2.1, aspect), 0.45));
        col = mix(col, vec3(0.34, 0.55, 0.85), pool(p, drift(t, 0.60, 0.40, 4.0, aspect), 0.32));
        col = mix(col, vec3(0.45, 0.10, 0.40), 0.7 * pool(p, drift(t, 0.35, 0.65, 5.3, aspect), 0.28));

        col *= 1.0 - 0.45 * length(v_tex_coord - 0.5);            // vignette
        col += (hash21(v_tex_coord * u_size * 2.0) - 0.5) / 128.0;  // dither away 8-bit banding
        gl_FragColor = vec4(col, 1.0);
    }
    """)
}

/// The inside of a lava lamp: wax blobs rise off a molten pool, stretch, merge and sink, lit from below.
@MainActor func lavaLamp(size: CGSize) -> SKScene {
    shaderScene(size: size, source: common + """
    // Metaball field and its gradient in one pass: every blob adds r²/d², wax is wherever the sum passes 1.
    // Returns (f, df/dx, df/dy).
    vec3 field(vec2 p, float t, float aspect) {
        vec3 f = vec3(0.0);
        for (int i = 0; i < 9; i++) {
            float fi = float(i);
            float h1 = hash11(fi + 0.13);
            float h2 = hash11(fi + 0.57);
            float h3 = hash11(fi + 0.91);
            float r = 0.05 + 0.06 * h1;
            // each blob rises off the bottom pool, lingers near the top and sinks again
            float cycle = t * (0.05 + 0.05 * h2) + h3 * 6.2831;
            float y = 0.5 - 0.62 * cos(cycle);
            float x = aspect * (0.1 + 0.8 * fract(h2 * 7.3)) + 0.06 * sin(cycle * 1.7 + fi);
            float s2 = pow(1.0 + 0.5 * abs(sin(cycle)), 2.0);            // stretch tall while moving
            vec2 d = p - vec2(x, y);
            float q = d.x * d.x + d.y * d.y / s2;
            float v = r * r / q;
            f += vec3(v, -2.0 * v / q * d.x, -2.0 * v / q * d.y / s2);
        }
        // molten pool along the bottom
        float pool = max(p.y + 0.02 - 0.025 * sin(p.x * 5.0 + t * 0.2) - 0.02 * sin(p.x * 11.0 - t * 0.3), 0.001);
        float v = 0.0035 / (pool * pool);
        return f + vec3(v, 0.0, -2.0 * v / pool);
    }

    void main() {
        float aspect = u_size.x / u_size.y;
        vec2 p = v_tex_coord * vec2(aspect, 1.0);
        vec3 f = field(p, u_time, aspect);

        // liquid: deep plum, glowing warm toward the bulb at the bottom
        vec3 col = mix(vec3(0.30, 0.03, 0.10), vec3(0.05, 0.01, 0.06), smoothstep(0.0, 1.0, v_tex_coord.y));
        col += vec3(0.9, 0.25, 0.05) * 0.35 * smoothstep(0.35, 1.0, f.x);  // wax glow scattering in the liquid

        // 1/f is ~(d/r)² near a lone blob, so sqrt(1 - 1/f) is the height of a sphere: shade the wax as one.
        float g = 1.0 / f.x;
        float z = sqrt(max(1.0 - g, 0.0));
        vec3 n = normalize(vec3(-f.yz * g * g * 0.04 / max(z, 0.08), 1.0));
        float light = 0.6 + 0.4 * dot(n, normalize(vec3(-0.4, 0.5, 0.8)));
        vec3 wax = mix(vec3(0.7, 0.07, 0.04), vec3(1.0, 0.5, 0.1), z) * light;  // thin rim deep red, thick core orange
        wax += vec3(1.0, 0.85, 0.6) * pow(max(dot(n, normalize(vec3(-0.3, 0.4, 1.0))), 0.0), 30.0) * 0.3;
        wax *= 1.25 - 0.5 * v_tex_coord.y;                                // lit from the bulb below
        col = mix(col, wax, smoothstep(0.96, 1.04, f.x));

        // curved glass: darker at the sides, two soft vertical reflections
        float x = v_tex_coord.x;
        col *= 0.55 + 0.45 * sin(3.14159 * x);
        col += vec3(1.0, 0.8, 0.9) * (0.05 * exp(-pow((x - 0.18) / 0.025, 2.0)) + 0.025 * exp(-pow((x - 0.86) / 0.04, 2.0)));
        col += (hash21(v_tex_coord * u_size * 2.0) - 0.5) / 128.0;
        gl_FragColor = vec4(col, 1.0);
    }
    """)
}

/// A night city out of focus behind a rainy window: beads of water and drops sliding down,
/// each drop a little lens showing the lights sharper.
@MainActor func rainOnGlass(size: CGSize) -> SKScene {
    shaderScene(size: size, source: common + """
    // One layer of bokeh lights, one per grid cell. blur 1 = out of focus (big soft discs), 0 = sharp points.
    vec3 bokeh(vec2 p, float cell, float blur, float seed) {
        vec2 id = floor(p / cell);
        float h = hash21(id + seed);
        if (h < 0.45) { return vec3(0.0); }
        vec2 off = (vec2(hash21(id + seed + 1.3), hash21(id + seed + 2.7)) - 0.5) * 0.5;
        float r = (0.13 + 0.12 * hash21(id + seed + 4.1)) * mix(0.25, 1.0, blur);
        float d = length(fract(p / cell) - 0.5 - off);
        float disc = smoothstep(r, r - mix(0.015, 0.1, blur), d) * (0.75 + 0.25 * smoothstep(r * 0.4, r, d));
        float k = hash21(id + seed + 6.6);
        vec3 tint = k < 0.45 ? vec3(1.0, 0.62, 0.28) : k < 0.65 ? vec3(1.0, 0.85, 0.55)
                  : k < 0.8 ? vec3(1.0, 0.25, 0.2) : k < 0.93 ? vec3(0.6, 0.75, 1.0) : vec3(0.3, 1.0, 0.6);
        return tint * disc * (0.25 + 0.5 * h) * mix(1.6, 1.0, blur);
    }

    // The street behind the glass: warm light-polluted haze low down, lights mostly in the lower half,
    // and a band of traffic crawling along.
    vec3 city(vec2 p, float blur, float t) {
        vec3 col = mix(vec3(0.13, 0.08, 0.10), vec3(0.015, 0.02, 0.05), smoothstep(0.0, 0.9, p.y));
        float low = smoothstep(0.95, 0.25, p.y);
        col += vec3(0.07, 0.045, 0.04) * low * blur;                       // condensation scatters light into a haze
        col += bokeh(p, 0.19, blur, 1.0) * low;
        col += bokeh(p + vec2(0.37, 0.11), 0.13, blur, 7.0) * low * 0.8;
        col += bokeh(p * mat2(0.8, 0.6, -0.6, 0.8) + vec2(3.1, 0.7), 0.09, blur, 23.0) * low * 0.6;
        col += bokeh(p + vec2(t * 0.012, 0.0), 0.08, blur, 13.0) * exp(-pow((p.y - 0.27) / 0.06, 2.0));
        col += bokeh(p - vec2(t * 0.009, 0.0), 0.07, blur, 19.0) * exp(-pow((p.y - 0.2) / 0.05, 2.0)) * 0.8;
        return col;
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
        vec3 col = city(p, 1.0, t);
        if (wiped > 0.0) { col = mix(col, city(p, 0.45, t), wiped * 0.8); }
        // each drop is a small lens: a flipped, sharper view of the lights around it,
        // darker toward its rim, with a highlight up-left
        // ponytail: a fixed-width lens, not real refraction; enough to read as water
        if (drop.z > 0.0) {
            vec3 through = city(p - drop.xy * 0.07, 0.2, t) * 1.3 + vec3(0.05, 0.035, 0.035) * smoothstep(0.95, 0.25, p.y);
            through *= 1.0 - 0.5 * smoothstep(0.5, 1.0, length(drop.xy));
            through += 0.25 * smoothstep(0.35, 0.0, length(drop.xy - vec2(-0.35, 0.4)));
            col = mix(col, through, drop.z);
        }

        col += (hash21(v_tex_coord * u_size * 2.0) - 0.5) / 128.0;
        gl_FragColor = vec4(col, 1.0);
    }
    """)
}

/// Green-to-violet curtains of aurora, fine vertical rays drifting through them, over a snowy ridge under stars.
@MainActor func aurora(size: CGSize) -> SKScene {
    shaderScene(size: size, source: common + """
    // Ridged noise: sharp mountain peaks.
    float peaks(float x, float seed) {
        float v = 0.0;
        float a = 0.5;
        for (int i = 0; i < 4; i++) {
            v += a * (1.0 - abs(noise(vec2(x, seed)) * 2.0 - 1.0));
            x *= 2.2;
            a *= 0.45;
        }
        return v;
    }

    void main() {
        float aspect = u_size.x / u_size.y;
        vec2 uv = v_tex_coord;
        vec2 p = uv * vec2(aspect, 1.0);
        float t = u_time;

        vec3 col = mix(vec3(0.02, 0.05, 0.08), vec3(0.004, 0.008, 0.03), smoothstep(0.1, 1.0, uv.y));
        col += vec3(0.85, 0.9, 1.0) * starField(uv * u_size, 11.0, 0.3, t);

        // three curtains: a folding lower edge with a bright rim, light fading upward into violet,
        // fine rays sheared along the folds, and patches that come and go along their length
        vec3 aurora = vec3(0.0);
        for (int i = 0; i < 3; i++) {
            float fi = float(i);
            float x = p.x * (0.6 + 0.25 * fi) + fi * 3.1;
            float fold = sin(x * 2.4 + t * 0.04 + fi * 1.7) + 0.6 * sin(x * 5.3 - t * 0.03 + fi);
            float edge = 0.4 + 0.1 * fi + 0.06 * fold + 0.14 * (noise(vec2(x * 0.7 + t * 0.01, fi * 4.0)) - 0.5);
            float h = uv.y - edge;
            float rim = exp(-abs(h) * 70.0);
            float body = smoothstep(-0.004, 0.004, h) * exp(-max(h, 0.0) * 9.0);
            float tail = smoothstep(0.02, 0.1, h) * exp(-max(h, 0.0) * 4.0) * 0.4;
            float below = exp(min(h, 0.0) * 30.0) * 0.15;
            float rx = x * 45.0 + fold * 3.0 + t * 0.15;
            float rays = noise(vec2(rx, fi * 5.0 + t * 0.05)) * 0.7 + noise(vec2(rx * 2.3, fi * 9.0)) * 0.3;
            rays = 0.25 + 1.4 * rays * rays;
            float patches = smoothstep(0.25, 0.7, noise(vec2(x * 0.6 - t * 0.008, fi * 3.0 + 1.0)));
            vec3 green = vec3(0.2, 1.0, 0.5);
            aurora += (green * ((body + rim * 0.7) * rays + below) + vec3(0.6, 0.25, 1.0) * tail * rays)
                    * patches * (1.0 - 0.25 * fi);
        }
        col += (1.0 - exp(-aurora * 0.9)) * smoothstep(1.05, 0.6, uv.y);   // soft clip where curtains overlap

        // far range: dark peaks, snow near the summits catching the aurora's light, mottled by gullies
        float far = 0.08 + 0.32 * peaks(p.x * 2.2, 2.0);
        float snowline = smoothstep(far - 0.14, far, uv.y) * (0.45 + 0.55 * noise(p * vec2(9.0, 16.0)));
        vec3 rock = mix(vec3(0.02, 0.035, 0.06), vec3(0.15, 0.22, 0.25), snowline) + vec3(0.0, 0.04, 0.025);
        col = mix(col, rock, smoothstep(far + 0.0015, far - 0.0015, uv.y));

        // snowy foreground: rolling drifts catching the green light, with a little sparkle
        float near = 0.04 + 0.07 * noise(vec2(p.x * 1.1 + 7.0, 11.0)) + 0.015 * noise(vec2(p.x * 6.0, 3.0));
        vec3 snow = mix(vec3(0.05, 0.08, 0.1), vec3(0.2, 0.28, 0.31), smoothstep(near - 0.1, near, uv.y));
        snow *= 0.8 + 0.2 * noise(p * vec2(3.0, 20.0));
        snow += vec3(0.01, 0.07, 0.04) + 0.35 * starField(uv * u_size + 3.0, 7.0, 0.08, t * 3.0);
        col = mix(col, snow, smoothstep(near + 0.0015, near - 0.0015, uv.y));

        col += (hash21(v_tex_coord * u_size * 2.0) - 0.5) / 128.0;
        gl_FragColor = vec4(col, 1.0);
    }
    """)
}

/// Deep-space gas clouds cut by dark dust lanes, drifting very slowly. Every load rolls a new one: its own cloud
/// structure, scale, palette, star field, and the band the cloud lies along.
@MainActor func nebula(size: CGSize) -> SKScene {
    // Background, main gas, secondary gas and hot-core colours, each after a real kind of nebula and what glows in
    // it: hydrogen-alpha crimson, doubly ionised oxygen teal, hydrogen-beta blue, starlight scattered off dust.
    let palettes: [[SIMD3<Float>]] = [
        [[0.08, 0.01, 0.02], [0.85, 0.10, 0.12], [0.20, 0.45, 0.60], [1.0, 0.75, 0.60]],  // emission, like Lagoon: Hα red, OIII core
        [[0.01, 0.02, 0.08], [0.15, 0.30, 0.80], [0.45, 0.60, 0.95], [0.90, 0.95, 1.0]],  // reflection, like the Pleiades: blue dust
        [[0.01, 0.04, 0.06], [0.80, 0.15, 0.12], [0.05, 0.55, 0.60], [0.85, 1.0, 0.95]],  // planetary, like Helix: red rim, OIII teal
        [[0.06, 0.03, 0.01], [0.70, 0.45, 0.15], [0.20, 0.35, 0.75], [1.0, 0.85, 0.60]],  // dusty, like Rho Ophiuchi: amber and blue
        [[0.02, 0.06, 0.08], [0.75, 0.52, 0.18], [0.05, 0.45, 0.55], [1.0, 0.90, 0.70]],  // Hubble palette, like the Pillars: SII gold, OIII teal
    ]
    let palette = palettes.randomElement()!
    let uniforms = [
        SKUniform(name: "u_seed", vectorFloat2: [.random(in: 0...100), .random(in: 0...100)]),
        SKUniform(name: "u_zoom", float: .random(in: 1.2...1.9)),
        SKUniform(name: "u_band", vectorFloat3: [.random(in: 0.38...0.62), .random(in: -0.6...0.6), .random(in: 0.26...0.4)]),
        SKUniform(name: "u_base", vectorFloat3: palette[0]),
        SKUniform(name: "u_dense", vectorFloat3: palette[1]),
        SKUniform(name: "u_accent", vectorFloat3: palette[2]),
        SKUniform(name: "u_hot", vectorFloat3: palette[3]),
    ]
    return shaderScene(size: size, source: common + """
    // A few bright foreground stars with four-point diffraction spikes.
    float brightStar(vec2 pts, float cell) {
        vec2 id = floor(pts / cell);
        float h = hash21(id + 31.0);
        if (h > 0.18) { return 0.0; }
        vec2 d = (fract(pts / cell) - 0.5 - (vec2(hash21(id + 2.2), hash21(id + 5.5)) - 0.5) * 0.6) * cell;
        float core = exp(-dot(d, d) * 0.15);
        float spikes = exp(-abs(d.x) * 1.2) * exp(-abs(d.y) * 0.06) + exp(-abs(d.y) * 1.2) * exp(-abs(d.x) * 0.06);
        return (core + 0.35 * spikes + 0.12 * exp(-length(d) * 0.08)) * (0.5 + 2.5 * h);
    }

    void main() {
        float aspect = u_size.x / u_size.y;
        vec2 p = v_tex_coord * vec2(aspect, 1.0);
        float t = u_time * 0.005; // one screen height of drift every ~5 minutes

        // domain-warped fbm: the warp vector w folds the clouds into filaments
        vec2 q = p * u_zoom + u_seed + vec2(t, t * 0.4);
        vec2 w = vec2(fbm(q + vec2(0.0, 1.3)), fbm(q + vec2(5.2, 8.1)));
        float gas = fbm(q + 1.8 * w + vec2(t * 0.5, 0.0));
        float dust = noise(q * 2.2 + 2.5 * w + 11.0) * 0.6 + noise(q * 4.7 + 3.0 * w) * 0.4;

        // ponytail: a band (height, slope, width from u_band) so the cloud always crosses the screen
        float band = exp(-pow((v_tex_coord.y - u_band.x + u_band.y * (v_tex_coord.x - 0.5)) / u_band.z, 2.0));
        float g = gas * 0.7 + band * 0.4;

        vec3 c = mix(u_base, u_dense, smoothstep(0.4, 0.8, g));
        c = mix(c, u_accent, smoothstep(0.42, 0.62, w.x) * 0.9);
        c = mix(c, u_hot, 0.8 * smoothstep(0.45, 0.65, g * w.y * 1.1));
        float density = smoothstep(0.25, 0.8, g);
        vec3 neb = 1.0 - exp(-c * density * density * 2.2);                // soft clip keeps bright cores from blowing out
        neb *= 1.0 - 0.85 * smoothstep(0.5, 0.72, dust);                     // dark dust lanes

        vec2 pts = v_tex_coord * u_size + u_seed * 97.0; // the seed moves the star field too
        vec3 col = vec3(0.004, 0.004, 0.012) + neb + c * 0.07 * band; // faint wash around the cloud
        col += vec3(0.8, 0.85, 1.0) * starField(pts, 7.0, 0.3, u_time) * (1.0 - 0.6 * density);
        col += vec3(1.0, 0.92, 0.85) * brightStar(pts + vec2(u_time * 0.2, 0.0), 180.0);

        col += (hash21(v_tex_coord * u_size * 2.0) - 0.5) / 128.0;
        gl_FragColor = vec4(col, 1.0);
    }
    """, uniforms: uniforms)
}
