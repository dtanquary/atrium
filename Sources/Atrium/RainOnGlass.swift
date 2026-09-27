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

/// How fast the water moves: every drop, bead and trail runs on `u_clock` at this many times real time.
let rainSpeed = Knob(key: "rain.speed", label: "Drip speed", range: 0.25...3, standard: 1, section: "Drops", format: .times)

/// Rain on Glass settings: on Random, fading to another backdrop every so often (shown under the backdrops), drip
/// speed, then the shared Look sliders.
let rainKnobs = [
    Knob(key: "rain.fade", label: "Fade to a new backdrop automatically", range: 0...1, standard: 1, section: "Colors", format: .toggle),
    Knob(key: "rain.fadeMinutes", label: "Every", range: 1...60, standard: 10, section: "Colors", format: .minutes,
         shownWhen: "rain.fade"),
    rainSpeed,
] + gradeKnobs("rain")

/// Photo backdrops, each baked (see docs/rain-on-glass.md) into a sharp view, seen small and upside down through
/// each drop, the same view defocused as a lens focused on the glass sees it, and the glow a misted pane spreads it
/// into. `night` is for Dark Mode, `day` for Light Mode; resources are `rain-<look>-near.jpg`, `-far.jpg` and
/// `-haze.jpg`, credited in `rain-credits.tsv`.
let rainPhotos: [(name: String, night: String, day: String)] = [
    ("Hamburg", "hamburg-night", "hamburg-day"),
    ("Riomaggiore", "riomaggiore-night", "riomaggiore-day"),
    ("Japan", "japan-night", "japan-day"),
    ("Forest", "forest-night", "forest-day"),
    ("Countryside", "countryside-night", "countryside-day"),
    ("Winter", "winter-night", "winter-day"),
    ("Lake", "lake-night", "lake-day"),
    ("Tropics", "tropics-night", "tropics-day"),
    ("Cabin", "cabin-night", "cabin-night"),
    ("Shanghai", "shanghai-night", "shanghai-night"),
]

/// Beads of water and drops sliding down a rainy window, each drop a little lens. Behind the glass is a photo
/// backdrop, or a city of out-of-focus lights in a palette: night in Dark Mode, an overcast day in Light Mode.
@MainActor func rainOnGlass(size: CGSize) -> SKScene {
    let names = rainPhotos.map(\.name) + rainPalettes.map(\.name)
    return rainScene(size: size, backdrop: UserDefaults.standard.string(forKey: "rain.palette").flatMap { names.contains($0) ? $0 : nil }
                                           ?? names.randomElement()!, clock: .random(in: 0..<1000))   // a fresh pane each time
}

/// The scene for one backdrop, with its water clock at `clock`. Left on Random, it fades to another one every few
/// minutes if Settings says so; the new scene takes over the clock, so the water carries on through the fade.
/// After about two hours of water it fades to a fresh pane of the same backdrop, which keeps the clock small enough
/// for the shader's Floats to place drops to the pixel.
@MainActor private func rainScene(size: CGSize, backdrop: String, clock: Double) -> SKScene {
    let scene = rainPhotos.first { $0.name == backdrop }.map { rainPhotoScene(size: size, name: systemIsDark ? $0.night : $0.day) }
        ?? rainBokehScene(size: size, palette: rainPalettes.first { $0.name == backdrop }!)
    let water = scene as! ShaderScene
    water.clockTime = clock
    let born = Date()
    // ponytail: counts from when the scene was built, covered time included; exact enough for "every 10 minutes"
    water.run(.repeatForever(.sequence([.wait(forDuration: 10), .run { [weak water] in
        guard let water, let view = water.view else { return }
        let fade = SKTransition.crossFade(withDuration: 4)
        fade.pausesIncomingScene = false   // both keep raining through the fade, in step on the same clock
        fade.pausesOutgoingScene = false
        if UserDefaults.standard.string(forKey: "rain.palette") ?? "" == "", rainKnobs[0].value > 0.5,
           Date().timeIntervalSince(born) >= rainKnobs[1].value.rounded() * 60 {
            let others = (rainPhotos.map(\.name) + rainPalettes.map(\.name)).filter { $0 != backdrop }
            view.presentScene(rainScene(size: water.size, backdrop: others.randomElement()!, clock: water.clockTime), transition: fade)
        } else if water.clockTime > 8000 {
            view.presentScene(rainScene(size: water.size, backdrop: backdrop, clock: .random(in: 0..<1000)), transition: fade)
        }
    }])))
    return scene
}

/// A city of out-of-focus lights behind the glass, in one of `rainPalettes`.
@MainActor private func rainBokehScene(size: CGSize, palette: (name: String, night: [SIMD3<Float>], day: [SIMD3<Float>], lights: [SIMD3<Float>])) -> SKScene {
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

    \(rainWater)

    void main() {
        \(rainDrops)

        // the fogged glass, cleared a little along fresh trails
        // (branches skip the extra city lookups on the dry glass, which is most of the screen)
        mat3 sky = mat3(u_top, u_low, vec3(0.0));
        mat3 a = mat3(u_l0, u_l1, u_l2);
        mat3 b = mat3(u_l3, u_l4, vec3(0.0));
        vec3 col = city(p, 1.0, t, sky, a, b, u_day);
        if (wiped > 0.0) { col = mix(col, city(p, 0.45, t, sky, a, b, u_day), wiped * 0.8); }
        // each drop is a lens (see rainPhotoScene): a sharp, upside-down view of a wide patch of the lights, with a
        // dark rim where light from outside is totally reflected
        if (drop.z > 0.0) {
            float sd = length(drop.xy);
            float sa = min(sd, 1.0) * 0.866;
            float bend = asin(min(1.333 * sa, 1.0)) - asin(sa);
            // (a little softer and brighter than sharp: the procedural city is mostly dark sky between its lights,
            // which would leave the drops as dark holes)
            vec3 through = city(p - drop.xy * drop.w - drop.xy / max(sd, 0.001) * bend / 0.9, 0.4, t, sky, a, b, u_day)
                         * mix(1.25, 1.05, u_day) * mix(0.98, 0.89, smoothstep(0.7, 0.87, sd));
            float aa = 1.0 / max(drop.w * u_size.y * 2.0, 1.0);
            through *= mix(1.0, mix(0.05, 0.15, u_day), smoothstep(0.87 - aa, 0.87 + aa, sd));
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
    ], knobs: gradeKnobs("rain"), speed: rainSpeed)
}

/// The water on the glass, the same over every backdrop. Drop functions return (position inside the drop on a unit
/// disc, coverage, radius).
private let rainWater = """
// How far the slider in a column has travelled by time t (screen heights), after footage of rain on a window.
// It creeps in bursts: every 8-25 s it lurches 4-9 times over 2-6 s, 5-12% of the screen in all, then sits still.
// Every 12-40 s it swallows a bead and runs 15-40%, starting at once and slowing to a stop.
float ease(float x) { return 1.0 - (1.0 - x) * (1.0 - x); }

float travel(float t, vec4 r) {
    float burst = 8.0 + 17.0 * r.x, active = (2.0 + 4.0 * r.y) / burst, lurches = floor(4.0 + 6.0 * r.y);
    float run = 12.0 + 28.0 * r.z, far = 0.15 + 0.25 * r.w;
    float c = t / burst + r.z * 3.0, b = t / run + r.x * 5.0;
    float u = min(fract(c) / active, 1.0) * lurches;             // which lurch of the burst it's on
    float stairs = u >= lurches ? 1.0 : (floor(u) + ease(clamp(fract(u) * 2.5 - 1.5, 0.0, 1.0))) / lurches;
    float lb = clamp((fract(b) - 1.0 + far / run) * run / far, 0.0, 1.0);
    return (0.05 + 0.07 * r.w) * (floor(c) + stairs) + far * (floor(b) + ease(lb));
}

// The track down a column: every slider in it follows the same wavy line, as later drops run down old wet tracks.
// It stays within 0.016 of the column's middle, so a slider's trail and pearls never cross into the next column;
// only the edge of its body can, which `rainDrops` checks for.
float track(float y, float column, vec4 r, float w) {
    return (column + 0.5 + (r.y - 0.5) * 0.2) * w + (noise(vec2(y * 14.0, column * 7.3 + r.z * 50.0)) - 0.5) * 0.02;
}

// Where the slider over column `column` is: (x on its track, y, radius, speed); radius 0 for an empty column.
// It wraps from below the screen back to above it, so a new one slides in from the top.
vec4 sliderAt(float column, float t, float w, float seed) {
    vec4 r = hash42(vec2(column, seed));
    vec4 k = hash42(vec2(seed, column));
    float s = travel(t, r);
    float y = 1.12 - mod(s + k.x * 1.4, 1.4);
    float speed = (s - travel(t - 0.1, r)) * 10.0;
    return vec4(track(y, column, r, w), y, step(k.y, 0.7) * (0.009 + 0.008 * k.z), speed);
}

// Seconds since the slider over `column` last passed height y: its travel is searched back in time for where it
// was at y. Long ago is 999.
float sinceSlider(float y, float column, float t, float w, float seed) {
    vec4 r = hash42(vec2(column, seed));
    vec4 k = hash42(vec2(seed, column));
    float s = travel(t, r);
    float target = s - mod(s + k.x * 1.4 - (1.12 - y), 1.4);   // travel when it was at y
    float age = 999.0, before = 0.0, prev = s;
    for (int i = 0; i < 6; i++) {
        float tau = 0.6 * pow(3.0, float(i));                     // 0.6, 1.8, 5.4 … 146 s back
        float was = travel(t - tau, r);
        if (age > 998.0 && was <= target) { age = mix(before, tau, (prev - target) / max(prev - was, 1e-4)); }
        before = tau; prev = was;
    }
    return age;
}

// Static drops in one grid layer: each cell may hold a drop that lands at a random moment (fully formed, as
// impacts do) and stays until the slider `s` of p's column sweeps it up, or for its lifetime of 40-160 s. Big ones
// are taller than wide and lumpy where their edge snags on dirt. Returns (position in the drop on a unit disc,
// coverage, radius).
vec4 beadLayer(vec2 p, float cell, float rmin, float rmax, float share, float seed, float t, float lane, vec4 s) {
    vec2 id = floor(p / cell);
    vec4 h = hash42(id + seed);
    vec4 g = hash42(id + seed + 17.0);
    float r = mix(rmin, rmax, h.w * h.w);
    float tall = 1.0 + 0.4 * smoothstep(0.007, 0.016, r);
    vec2 c = (id + 0.5 + (h.yz - 0.5) * max(1.0 - 2.0 * r * tall / cell, 0.0)) * cell;
    vec2 d = (p - c) / vec2(r, r * tall);
    float edge = 1.0;
    if (rmax > 0.01) {
        float a = atan(d.y, d.x);
        edge += (0.045 * sin(3.0 * a + g.z * 6.28) + 0.025 * sin(5.0 * a + g.w * 6.28)) * smoothstep(0.006, 0.014, r);
    }
    float cover = smoothstep(edge, edge * 0.85, length(d)) * step(h.x, share);
    if (cover > 0.0) {
        float since = mod(t + g.y * 300.0, 40.0 + 120.0 * g.x);     // seconds since it landed
        // swept up if the slider of the bead's own column has passed since it landed (judged at its middle, so the
        // whole bead goes at once even where it straddles two columns)
        float column = floor(c.x / lane);
        vec4 sc = column == floor(p.x / lane) ? s : sliderAt(column, t, lane, 1.0);
        if (sc.z > 0.0 && abs(c.x - track(c.y, column, hash42(vec2(column, 1.0)), lane)) < sc.z + r
            && sinceSlider(c.y + sc.z, column, t, lane, 1.0) < since) { cover = 0.0; }
    }
    return vec4(d / edge, cover, r);
}

// The mist of specks too small to slide: one per cell, landing and drying at random; sweeping is handled by the
// caller, which fades them where a slider has just passed.
vec4 mistLayer(vec2 p, float t) {
    float cell = 0.016;
    vec2 id = floor(p / cell);
    vec4 h = hash42(id + 3.0);
    float r = 0.001 + 0.001 * h.w;
    vec2 d = (p - (id + 0.5 + (h.yz - 0.5) * 0.8) * cell) / r;
    float on = step(h.x, 0.5) * step(fract(t / (40.0 + 60.0 * h.w) + h.y), 0.8);
    return vec4(d, smoothstep(1.0, 0.8, length(d)) * on, r);
}

// The body of the slider `s` over `column` at p: a teardrop whose rounded front leads, with a tail that points
// upward and sharpens as it speeds up. Returns like beadLayer.
vec4 sliderBody(vec2 p, float column, float w, float seed, vec4 s) {
    vec2 d = vec2(p.x - track(p.y, column, hash42(vec2(column, seed)), w), p.y - s.y);
    float tail = 1.25 + 1.5 * clamp(s.w, 0.0, 1.0);
    if (d.y > 0.0) { d.x *= 1.0 + 0.6 * clamp(d.y / (s.z * tail), 0.0, 1.0); d.y /= tail; }
    return vec4(d / max(s.z, 1e-4), smoothstep(s.z, s.z * 0.85, length(d)) * step(0.0001, s.z), s.z);
}

// The slider over p's column (its body from sliderBody) and behind it the pearls it sheds along its track. Returns
// (position in the drop on a unit disc, coverage) and (radius, the thin wet line of the track, how clear of mist
// the track at p still is: 1 for 5 s after the slider passed, then misting over for 25 s).
mat3 sliderDrop(vec2 p, float t, float w, float seed, vec4 s) {
    float column = floor(p.x / w);
    vec4 r = hash42(vec2(column, seed));
    mat3 out3 = mat3(0.0);
    if (s.z > 0.0) {
        float x = track(p.y, column, r, w);
        out3[0] = sliderBody(p, column, w, seed, s).xyz;
        out3[1] = vec3(s.z, smoothstep(0.0025, 0.0, abs(p.x - x)) * 0.5, 0.0);
        float band = smoothstep(s.z * 0.8, s.z * 0.4, abs(p.x - x));
        if (band > 0.0) {
            float age = sinceSlider(p.y, column, t, w, seed);
            out3[1].z = band * smoothstep(30.0, 5.0, age);   // clear 5 s, mists over 25
            // pearls: about one per radius down the track, a fifth of the slider's width, each left as it passed
            // (aged as the track at p, which is within a radius of it)
            float k = floor(p.y / s.z);
            vec4 q = hash42(vec2(k, column) + seed);
            float pr = s.z * (0.15 + 0.15 * q.x) * step(q.y, 0.6);
            vec2 pd = vec2(p.x - x - (q.z - 0.5) * s.z * 0.5, p.y - (k + 0.5) * s.z) / max(pr, 1e-4);
            float pearl = smoothstep(1.0, 0.8, length(pd)) * step(0.3, age) * step(age, 120.0);
            if (pearl > out3[0].z) { out3[0] = vec3(pd, pearl); out3[1].x = pr; }
        }
    }
    return out3;
}
"""

/// The start of `main()`: the point `p` (1 = screen height), the drop over it, if any, and how much a trail has
/// wiped the fog there.
private let rainDrops = """
float aspect = u_size.x / u_size.y;
vec2 p = v_tex_coord * vec2(aspect, 1.0);
float t = u_clock;
// sliders run down columns this wide; static drops in three sizes: a mist of specks, beads, and a few big ones
float lane = 0.06;
vec4 s = sliderAt(floor(p.x / lane), t, lane, 1.0);
mat3 slide = sliderDrop(p, t, lane, 1.0, s);
float wiped = max(slide[1].y, slide[1].z);
vec4 drop = mistLayer(p, t);
drop.z *= 1.0 - slide[1].z;
vec4 bead = beadLayer(p, 0.04, 0.0025, 0.007, 0.6, 7.0, t, lane, s);
if (bead.z > drop.z) { drop = bead; }
bead = beadLayer(p, 0.09, 0.008, 0.022, 0.45, 11.0, t, lane, s);
if (bead.z > drop.z) { drop = bead; }
if (slide[0].z > drop.z) { drop = vec4(slide[0], slide[1].x); }
// right at a column's edge, the body of the next column's slider can reach over
float across = fract(p.x / lane) < 0.5 ? -1.0 : 1.0;
if (abs(fract(p.x / lane) - 0.5) * lane > 0.5 * lane - 0.005) {
    vec4 next = sliderBody(p, floor(p.x / lane) + across, lane, 1.0, sliderAt(floor(p.x / lane) + across, t, lane, 1.0));
    if (next.z > drop.z) { drop = next; }
}
"""

/// Rain on a window with a photo behind it, focused on the glass. Behind it, the camera's defocus (`far`); drizzle
/// mist on the glass scatters part of that into a wide glow (`haze`), except where a slider has just swept it.
/// Each drop is a strong lens showing the sharp view (`near`) upside down, with a dark rim where light from outside
/// can't get through. Numbers are from measured footage and the optics of a water cap on glass; see the doc.
@MainActor private func rainPhotoScene(size: CGSize, name: String) -> SKScene {
    func texture(_ level: String) -> SKTexture { SKTexture(image: NSImage(contentsOf: resource("rain-\(name)-\(level).jpg")) ?? NSImage()) }
    let far = texture("far")
    let night: Float = name.hasSuffix("night") ? 1 : 0
    return shaderScene(size: size, source: shaderCommon + """
    \(rainWater)

    void main() {
        \(rainDrops)

        // the photo covers the screen, cropped to fit
        vec2 fit = vec2(min(aspect / u_photoAspect, 1.0), min(u_photoAspect / aspect, 1.0));
        vec2 uv = (v_tex_coord - 0.5) * fit + 0.5;
        vec3 camera = texture2D(u_far, uv).rgb;
        float mist = 0.3 * (1.0 - wiped);
        vec3 col = mix(camera, texture2D(u_haze, uv).rgb, mist) + vec3(0.02, 0.017, 0.014) * mist * u_night;
        // at night each speck of mist holds a pinpoint of the brightest lights, so the glass around them glitters
        vec4 g = hash42(floor(v_tex_coord * u_size * 2.0));
        col += step(g.x, 0.02) * g.y * mist * 2.0 * max(camera - 0.4, 0.0) * u_night;

        // a drop is a lens with a 60 degree contact angle: at radius s it bends the view by `bend` towards its
        // middle, so it shows a wide patch of the scene, sharp and upside down; past s = 0.87 the light is
        // totally reflected inside it and only the dark room shows
        if (drop.z > 0.0) {
            float sd = length(drop.xy);
            float sa = min(sd, 1.0) * 0.866;
            float bend = asin(min(1.333 * sa, 1.0)) - asin(sa);
            vec2 centre = (p - drop.xy * drop.w) / vec2(aspect, 1.0);
            vec2 at = (centre - 0.5) * fit + 0.5 - drop.xy / max(sd, 0.001) * bend / u_fov * vec2(1.0 / u_photoAspect, 1.0);
            vec3 through = texture2D(u_near, clamp(at, 0.0, 1.0)).rgb * mix(0.98, 0.89, smoothstep(0.7, 0.87, sd));
            float aa = 1.0 / max(drop.w * u_size.y * 2.0, 1.0);
            through *= mix(1.0, mix(0.15, 0.05, u_night), smoothstep(0.87 - aa, 0.87 + aa, sd));
            col = mix(col, through, drop.z);
        }

        col = grade(col, 0.5, u_hue, u_saturation, u_contrast, u_brightness);
        col += (hash21(v_tex_coord * u_size * 2.0) - 0.5) / 128.0;
        gl_FragColor = vec4(col, 1.0);
    }
    """, uniforms: [
        SKUniform(name: "u_far", texture: far), SKUniform(name: "u_near", texture: texture("near")),
        SKUniform(name: "u_haze", texture: texture("haze")), SKUniform(name: "u_night", float: night),
        SKUniform(name: "u_photoAspect", float: Float(far.size().width / max(far.size().height, 1))),
        SKUniform(name: "u_fov", float: 0.9),   // the photos' height in radians (about 52 degrees)
    ], knobs: gradeKnobs("rain"), speed: rainSpeed)
}
