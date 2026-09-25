import SpriteKit

// Full-screen shader wallpapers, each one SKShader over the whole scene (see shaderScene in Scenes.swift).
// Shaders work in `p = v_tex_coord * vec2(aspect, 1)`: y runs 0...1 up the screen and x keeps the same scale,
// so shapes stay round on any display. `pts` is the same point in screen points, for pixel-sized detail.

/// Hashes, value noise, fbm and star fields shared by the shader scenes.
let shaderCommon = """
float hash11(float x) { return fract(sin(x * 127.1) * 43758.5453); }

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Four random numbers for a cell, from Dave Hoskins' "Hash without Sine" (MIT licence, shadertoy.com/view/4djSRW).
// hash21 repeats every 50 whole-number cells across and 100 up, which tiles a star field into a visible pattern;
// this one doesn't repeat for thousands of cells.
vec4 hash42(vec2 p) {
    vec4 p4 = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
    p4 += dot(p4, p4.wzxy + 33.33);
    return fract((p4.xxyz + p4.yzzw) * p4.zywx);
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
    vec4 r = hash42(floor(pts / cell));
    float h = r.x;
    if (h > density) { return 0.0; }
    vec2 off = (r.yz - 0.5) * 0.7;
    float mag = pow(r.w, 5.0);
    float d = length(fract(pts / cell) - 0.5 - off) * cell;
    float twinkle = 0.8 + 0.2 * sin(t * (1.0 + 3.0 * h) + h * 50.0);
    return (smoothstep(0.6 + 1.2 * mag, 0.0, d) + 0.3 * mag * exp(-d * 0.4)) * (0.3 + 0.9 * mag) * twinkle;
}

// A few bright foreground stars with four-point diffraction spikes; about half shimmer very gently and slowly.
float brightStar(vec2 pts, float cell, float t) {
    vec4 r = hash42(floor(pts / cell) + 31.0);
    float h = r.x;
    if (h > 0.18) { return 0.0; }
    vec2 d = (fract(pts / cell) - 0.5 - (r.yz - 0.5) * 0.6) * cell;
    float core = exp(-dot(d, d) * 0.15);
    float spikes = exp(-abs(d.x) * 1.2) * exp(-abs(d.y) * 0.06) + exp(-abs(d.y) * 1.2) * exp(-abs(d.x) * 0.06);
    float shimmer = h < 0.09 ? 0.93 + 0.07 * sin(t * (0.6 + 5.0 * h) + h * 90.0) : 1.0;
    return (core + 0.35 * spikes + 0.12 * exp(-length(d) * 0.08)) * (0.5 + 2.5 * h) * shimmer;
}

// The Look sliders from `gradeKnobs`, over a finished colour. Hue turns it around the grey axis (in degrees) and
// contrast is a power curve through `pivot`, the scene's typical level, so black stays black. At the defaults it's
// exactly the identity.
vec3 grade(vec3 col, float pivot, float hue, float saturation, float contrast, float brightness) {
    float a = hue * 0.01745;
    vec3 grey = vec3(0.57735);
    col = col * cos(a) + cross(grey, col) * sin(a) + grey * dot(grey, col) * (1.0 - cos(a));
    col = max(mix(vec3(dot(col, vec3(0.2126, 0.7152, 0.0722))), col, saturation), 0.0);
    return pivot * pow(col / pivot, vec3(contrast)) * brightness;
}

"""

/// The Look sliders for a plain shader scene, keyed under `prefix`. Pass their uniforms to `grade` in the shader.
func gradeKnobs(_ prefix: String) -> [Knob] {
    [
        Knob(key: prefix + ".brightness", label: "Brightness", range: 0.4...1.5, standard: 1, section: "Look"),
        Knob(key: prefix + ".contrast", label: "Contrast", range: 0.5...1.5, standard: 1, section: "Look"),
        Knob(key: prefix + ".saturation", label: "Saturation", range: 0...2, standard: 1, section: "Look"),
        Knob(key: prefix + ".hue", label: "Hue shift", range: -180...180, standard: 0, section: "Look"),
    ]
}

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

/// Aurora colours, bottom to top: lower fringe, body, upper, crown. All real emissions and their mixes: 557.7 nm oxygen
/// green, 630 nm oxygen red high up, nitrogen pink along the lower edge in strong displays, nitrogen blue and violet
/// where the top is sunlit, yellow where green and red overlap, and the white of a faint display.
let auroraPalettes: [(name: String, colours: [SIMD3<Float>])] = [
    ("Green", [[0.25, 1.0, 0.55], [0.2, 1.0, 0.5], [0.2, 0.85, 0.55], [0.6, 0.25, 1.0]]),   // the classic
    ("Storm", [[1.0, 0.3, 0.6], [0.2, 1.0, 0.5], [0.7, 0.8, 0.35], [1.0, 0.15, 0.2]]),      // pink edge, green, red crown
    ("Red", [[0.3, 0.95, 0.5], [1.0, 0.35, 0.3], [1.0, 0.15, 0.2], [0.75, 0.1, 0.3]]),       // as seen from mid-latitudes
    ("Pink", [[1.0, 0.25, 0.6], [1.0, 0.45, 0.75], [0.75, 0.4, 1.0], [0.5, 0.25, 1.0]]),
    ("Purple", [[0.9, 0.3, 0.8], [0.6, 0.35, 1.0], [0.45, 0.3, 1.0], [0.8, 0.2, 0.5]]),
    ("Blue", [[0.25, 0.9, 0.7], [0.3, 0.6, 1.0], [0.35, 0.4, 1.0], [0.55, 0.3, 1.0]]),      // sunlit nitrogen
    ("Yellow", [[0.4, 1.0, 0.45], [0.8, 1.0, 0.35], [1.0, 0.8, 0.3], [1.0, 0.35, 0.25]]),   // green and red overlapping
    ("White", [[0.85, 1.0, 0.92], [0.8, 0.95, 0.9], [0.75, 0.85, 0.95], [0.65, 0.7, 0.95]]), // a faint display
]

/// Curtains of aurora shading from one real colour to the next, fine vertical rays drifting through them, over a
/// snowy ridge under stars. The palette is pinned in Settings or rolled on each load.
@MainActor func aurora(size: CGSize) -> SKScene {
    let c = (auroraPalettes.first { $0.name == UserDefaults.standard.string(forKey: "aurora.palette") }
        ?? auroraPalettes.randomElement()!).colours
    return shaderScene(size: size, source: shaderCommon + """
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

        // three curtains: a folding lower edge with a bright rim, light fading upward through the palette,
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
            float pn = noise(vec2(x * 0.6 - t * 0.008, fi * 3.0 + 1.0));
            float patches = smoothstep(0.25, 0.7, pn);
            // colour by height above the edge, with the bands drifting up and down along the curtain
            float ch = h + (0.5 - pn) * 0.09;
            vec3 hue = mix(u_fringe, u_body, smoothstep(-0.01, 0.012, ch));
            hue = mix(hue, u_upper, smoothstep(0.03, 0.14, ch));
            hue = mix(hue, u_crown, smoothstep(0.12, 0.3, ch));
            aurora += hue * ((body + rim * 0.7 + tail) * rays + below) * patches * (1.0 - 0.25 * fi);
        }
        col += (1.0 - exp(-aurora * 0.9)) * smoothstep(1.05, 0.6, uv.y);   // soft clip where curtains overlap

        // far range: dark peaks, snow near the summits catching the aurora's light, mottled by gullies
        float far = 0.08 + 0.32 * peaks(p.x * 2.2, 2.0);
        float snowline = smoothstep(far - 0.14, far, uv.y) * (0.45 + 0.55 * noise(p * vec2(9.0, 16.0)));
        vec3 rock = mix(vec3(0.02, 0.035, 0.06), vec3(0.15, 0.22, 0.25), snowline) + u_body * 0.045;
        col = mix(col, rock, smoothstep(far + 0.0015, far - 0.0015, uv.y));

        // snowy foreground: rolling drifts catching the green light, with a little sparkle
        float near = 0.04 + 0.07 * noise(vec2(p.x * 1.1 + 7.0, 11.0)) + 0.015 * noise(vec2(p.x * 6.0, 3.0));
        vec3 snow = mix(vec3(0.05, 0.08, 0.1), vec3(0.2, 0.28, 0.31), smoothstep(near - 0.1, near, uv.y));
        snow *= 0.8 + 0.2 * noise(p * vec2(3.0, 20.0));
        snow += u_body * 0.07 + 0.35 * starField(uv * u_size + 3.0, 7.0, 0.08, t * 3.0);
        col = mix(col, snow, smoothstep(near + 0.0015, near - 0.0015, uv.y));

        col = grade(col, 0.3, u_hue, u_saturation, u_contrast, u_brightness);
        col += (hash21(v_tex_coord * u_size * 2.0) - 0.5) / 128.0;
        gl_FragColor = vec4(col, 1.0);
    }
    """, uniforms: [
        SKUniform(name: "u_fringe", vectorFloat3: c[0]), SKUniform(name: "u_body", vectorFloat3: c[1]),
        SKUniform(name: "u_upper", vectorFloat3: c[2]), SKUniform(name: "u_crown", vectorFloat3: c[3]),
    ], knobs: gradeKnobs("aurora"))
}

/// Nebula colours: background, main gas, secondary gas and hot core, each after a real kind of nebula and what
/// glows in it: hydrogen-alpha crimson, doubly ionised oxygen teal, hydrogen-beta blue, starlight off dust.
let nebulaPalettes: [(name: String, colours: [SIMD3<Float>])] = [
    ("Emission", [[0.08, 0.01, 0.02], [0.85, 0.10, 0.12], [0.20, 0.45, 0.60], [1.0, 0.75, 0.60]]),   // like Lagoon: Hα red, OIII core
    ("Reflection", [[0.01, 0.02, 0.08], [0.15, 0.30, 0.80], [0.45, 0.60, 0.95], [0.90, 0.95, 1.0]]), // like the Pleiades: blue dust
    ("Planetary", [[0.01, 0.04, 0.06], [0.80, 0.15, 0.12], [0.05, 0.55, 0.60], [0.85, 1.0, 0.95]]),  // like Helix: red rim, OIII teal
    ("Dusty", [[0.06, 0.03, 0.01], [0.70, 0.45, 0.15], [0.20, 0.35, 0.75], [1.0, 0.85, 0.60]]),      // like Rho Ophiuchi: amber, blue
    ("Hubble", [[0.02, 0.06, 0.08], [0.75, 0.52, 0.18], [0.05, 0.45, 0.55], [1.0, 0.90, 0.70]]),     // like the Pillars: SII gold, OIII teal
    ("Dark Cloud", [[0.015, 0.012, 0.01], [0.40, 0.27, 0.16], [0.22, 0.25, 0.30], [0.75, 0.66, 0.52]]), // like the Shark: dim dust
    ("Oxygen", [[0.0, 0.03, 0.03], [0.10, 0.70, 0.50], [0.15, 0.45, 0.75], [0.85, 1.0, 0.92]]),       // like NGC 3242: OIII green, Hβ blue
]

/// Deep-space gas clouds cut by dark dust lanes, drifting very slowly. Every load rolls a new one: its own cloud
/// structure, scale, palette (unless one is pinned in Settings), star field, and the band the cloud lies along.
/// Left running, it dissolves into a freshly rolled one every few minutes.
@MainActor func nebula(size: CGSize) -> SKScene {
    let palette = (nebulaPalettes.first { $0.name == UserDefaults.standard.string(forKey: "nebula.palette") }
        ?? nebulaPalettes.randomElement()!).colours
    let uniforms = [
        SKUniform(name: "u_seed", vectorFloat2: [.random(in: 0...100), .random(in: 0...100)]),
        SKUniform(name: "u_zoom", float: .random(in: 1.2...1.9)),
        SKUniform(name: "u_band", vectorFloat3: [.random(in: 0.38...0.62), .random(in: -0.6...0.6), .random(in: 0.26...0.4)]),
        SKUniform(name: "u_base", vectorFloat3: palette[0]),
        SKUniform(name: "u_dense", vectorFloat3: palette[1]),
        SKUniform(name: "u_accent", vectorFloat3: palette[2]),
        SKUniform(name: "u_hot", vectorFloat3: palette[3]),
    ]
    let scene = shaderScene(size: size, source: shaderCommon + """
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
        col += vec3(1.0, 0.92, 0.85) * brightStar(pts + vec2(u_time * 0.2, 0.0), 180.0, u_time);

        col = grade(col, 0.3, u_hue, u_saturation, u_contrast, u_brightness);
        col += (hash21(v_tex_coord * u_size * 2.0) - 0.5) / 128.0;
        gl_FragColor = vec4(col, 1.0);
    }
    """, uniforms: uniforms, knobs: gradeKnobs("nebula"))

    // Hand over to a new nebula with a long dissolve, both still drifting, so there's never a cut.
    // ponytail: the dissolve renders both nebulas, about double the GPU cost while it lasts
    scene.run(.sequence([.wait(forDuration: 8 * 60), .run { [weak scene] in
        let fade = SKTransition.crossFade(withDuration: 90)
        fade.pausesIncomingScene = false
        fade.pausesOutgoingScene = false
        scene?.view?.presentScene(nebula(size: size), transition: fade)
    }]))
    return scene
}
