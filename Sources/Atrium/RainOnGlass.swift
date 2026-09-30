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

/// Rain on Glass settings: on Random, fading to another backdrop every so often (shown under the backdrops), the
/// weather (RainWeather.swift), drip speed, the shared Look sliders, then previews of the weather.
let rainKnobs = [
    Knob(key: "rain.fade", label: "Fade to a new backdrop automatically", range: 0...1, standard: 1, section: "Colors", format: .toggle),
    Knob(key: "rain.fadeMinutes", label: "Fade every", range: 1...60, standard: 10, section: "Colors", format: .minutes,
         shownWhen: "rain.fade"),
    rainFollow, rainWindow, rainSpeed,
] + gradeKnobs("rain") + rainPreview

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
    // the shader is built with only what the glass needs now (see GlassUniforms), and without the weather at all
    // while it's off, exactly as it always was; the scene rebuilds, crossfading, when that changes
    let features = GlassUniforms.wanted
    let weather = features.contains("WEATHER") ? GlassUniforms(features) : nil
    let scene = rainPhotos.first { $0.name == backdrop }.map { rainPhotoScene(size: size, name: systemIsDark ? $0.night : $0.day, weather: weather) }
        ?? rainBokehScene(size: size, palette: rainPalettes.first { $0.name == backdrop }!, weather: weather)
    let water = scene as! ShaderScene
    water.clockTime = clock
    weather?.apply(to: water)
    water.run(.repeatForever(.sequence([.wait(forDuration: 1), .run { [weak water] in
        guard let water else { return }
        if GlassUniforms.wanted != features, let view = water.view {
            view.presentScene(rainScene(size: water.size, backdrop: backdrop, clock: water.clockTime), transition: .crossFade(withDuration: 1))
        } else {
            weather?.apply(to: water)
        }
    }])))
    let born = Date()
    // ponytail: counts from when the scene was built, covered time included; exact enough for "every 10 minutes"
    water.run(.repeatForever(.sequence([.wait(forDuration: 10), .run { [weak water] in
        weather?.poll()
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
@MainActor private func rainBokehScene(size: CGSize, palette: (name: String, night: [SIMD3<Float>], day: [SIMD3<Float>], lights: [SIMD3<Float>]),
                                       weather: GlassUniforms?) -> SKScene {
    let sky = systemIsDark ? palette.night : palette.day
    let l = palette.lights
    return shaderScene(size: size, source: GlassUniforms.defines(weather) + shaderCommon + """
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
    // traffic crawling along. `sky` holds the top and low colours; `day` is 1 in Light Mode; `haze` is how much
    // the mist on the glass scatters (`blur` in steady rain).
    vec3 city(vec2 p, float blur, float t, mat3 sky, mat3 a, mat3 b, float day, float haze) {
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
        vec3 night = col + sky[1] * 0.55 * low * haze + lights.rgb;
        vec3 lit = col * exp(-1.3 * (lights.a - 0.8 * lights.rgb));
        return mix(night, mix(lit, vec3(1.0), 0.15 * haze), day);
    }

    \(rainWater)

    void main() {
        \(rainDrops)

        // the fogged glass, cleared a little along fresh trails
        // (branches skip the extra city lookups on the dry glass, which is most of the screen)
        mat3 sky = mat3(u_top, u_low, vec3(0.0));
        mat3 a = mat3(u_l0, u_l1, u_l2);
        mat3 b = mat3(u_l3, u_l4, vec3(0.0));
        #if WEATHER
        float mist = u_glass.x / 0.3;
        #else
        float mist = 1.0;
        #endif
        vec3 col = city(p, 1.0, t, sky, a, b, u_day, mist);
        if (wiped > 0.0) { col = mix(col, city(p, 0.45, t, sky, a, b, u_day, 0.45 * mist), wiped * 0.8); }
        // the lights scattered by anything on the glass: a glow at night, milky by day
        vec3 glow = (a * vec3(0.45, 0.2, 0.15) + b * vec3(0.13, 0.07, 0.0)) * 0.5 + u_low * 1.5;
        vec3 veil = mix(mix(u_low, u_top, smoothstep(0.0, 0.9, p.y)) + glow * smoothstep(1.0, 0.1, p.y), mix(u_top, vec3(1.0), 0.3), u_day);
        #if SNOW
        col = mix(col, mix(veil * 1.2 + 0.05, vec3(0.95), u_day), falling);
        #endif
        #if FOG
        // condensation (see fogCover): on the outside of the pane the trails wipe it and the drops sit on top, on the
        // inside it covers them
        float fog = fogCover(p, u_glass.y, u_pane.x);
        col = mix(col, veil, fog * (1.0 - u_pane.x) * (1.0 - wiped));
        #endif
        // each drop is a lens (see rainPhotoScene): a sharp, upside-down view of a wide patch of the lights, with a
        // dark rim where light from outside is totally reflected
        #if FOG || SNOW || FROST
        dewy = dewy || drop.w < 0.004;   // behind fog, snow or frost a small drop's view is lost in the haze anyway
        #endif
        if (drop.z > 0.0) {
            float sd = length(drop.xy);
        #if DRY
            float sin60 = mix(0.866, 0.174, flattened(drop.w, rain.w)), k = 0.866 / sin60;  // flatter as it dries
        #else
            float sin60 = 0.866, k = 1.0;
        #endif
            float sa = min(sd, 1.0) * sin60;
            float bend = asin(min(1.333 * sa, 1.0)) - asin(sa);
            // (a little softer and brighter than sharp: the procedural city is mostly dark sky between its lights,
            // which would leave the drops as dark holes; a dew bead, a few pixels across, just holds the glow)
            vec3 through = mix(u_low, u_top, 0.5 + 0.5 * drop.y) + glow * 0.5 * (1.0 - u_day);
            if (!dewy) { through = city(p - drop.xy * drop.w - drop.xy / max(sd, 0.001) * bend / 0.9, 0.4, t, sky, a, b, u_day, 0.4 * mist); }
            through *= mix(1.25, 1.05, u_day) * mix(0.98, 0.89, smoothstep(0.7 * k, 0.87 * k, sd));
            float aa = 1.0 / max(drop.w * u_size.y * 2.0, 1.0), dark = mix(0.05, 0.15, u_day);
        #if FROST
            // frozen: cloudy ice that loses the sharp view, with a frosted rim that catches the light
            float frozen = step(fract(drop.w * 7919.0), u_glass.w);
            through = mix(through, veil * 1.3 + mix(0.04, 0.35, u_day), frozen * 0.65);
            dark = mix(dark, 1.4, frozen);
        #endif
            through *= mix(1.0, dark, smoothstep(0.87 * k - aa, 0.87 * k + aa, sd));
            col = mix(col, through, drop.z);
        }
        #if FOG
        col = mix(col, veil, fog * u_pane.x);
        #endif
        #if SNOW
        col = mix(col, mix(veil * 1.6 + 0.06, vec3(0.92), u_day), white);
        #endif
        #if FROST
        vec2 frost = frostAt(texture2D(u_frostMap, v_tex_coord), p, u_glass.z);
        vec3 lit = mix(veil, vec3(dot(veil, vec3(0.3, 0.59, 0.11))), 0.3);   // (ice scatters every colour alike)
        vec3 ice = mix(1.0 - exp(-lit * (0.5 + 2.6 * frost.x)) + 0.02, vec3(0.86, 0.9, 0.95) * 0.85, u_day);
        col = mix(col, mix(ice, veil, u_pane.w * 0.6), frost.y * (0.9 - 0.5 * u_pane.w));
        vec4 glint = hash42(floor(v_tex_coord * u_size * 2.0) + 5.0);
        col += step(glint.x, 0.004) * frost.x * glint.y * mix(glow * 3.0, vec3(0.5), u_day);
        #endif

        col = grade(col, mix(0.3, 0.7, u_day), u_hue, u_saturation, u_contrast, u_brightness);
        col += (hash21(v_tex_coord * u_size * 2.0) - 0.5) / 128.0;
        gl_FragColor = vec4(col, 1.0);
    }
    """, uniforms: [
        SKUniform(name: "u_top", vectorFloat3: sky[0]), SKUniform(name: "u_low", vectorFloat3: sky[1]),
        SKUniform(name: "u_l0", vectorFloat3: l[0]), SKUniform(name: "u_l1", vectorFloat3: l[1]),
        SKUniform(name: "u_l2", vectorFloat3: l[2]), SKUniform(name: "u_l3", vectorFloat3: l[3]),
        SKUniform(name: "u_l4", vectorFloat3: l[4]), SKUniform(name: "u_day", float: systemIsDark ? 0 : 1),
    ] + (weather?.all ?? []), knobs: gradeKnobs("rain"), speed: rainSpeed)
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

// A drop's radius as it dries: `dried` (from GlassWeather) is how far drying has gone, in mm² of diameter, and a
// drop of d mm lasts until it reaches d², or 16 for the big ones, which hang tall on the glass holding no more than
// a 4 mm drop would. Its edge stays put while it flattens, for 80% of that, then it shrinks away (Hu & Larson
// 2002). 1 mm is 0.005 screen heights.
float drying(float r0, float dried) {
    if (dried > 0.0) { r0 *= sqrt(clamp((1.0 - dried / min(160000.0 * r0 * r0, 16.0)) * 5.0, 0.0, 1.0)); }
    return r0;
}

// How far a drop has flattened as it dries, 0-1: its contact angle falls from 60 to 10 degrees over the first 80%
// of its life. The lenses use it.
float flattened(float r, float dried) { return clamp(dried / min(160000.0 * r * r, 16.0) / 0.8, 0.0, 1.0); }

// The sliders' clock: the water's clock t until `stop`, when the rain stops or the glass freezes, and then they
// coast to a halt within a couple of seconds, as runners do once nothing feeds them.
float sliderTime(float t, float stop) { return t < stop ? t : stop + 1.5 * (1.0 - exp((stop - t) / 1.5)); }

// Where the slider over column `column` is at slider time t: (x on its track, y, radius, speed); radius 0 for an
// empty column. It wraps from below the screen back to above it, so a new one slides in from the top. 70% of
// columns hold one in steady rain, and with the weather, `rain` (see rainDrops) times as many, and `runs` times
// that (drizzle seldom runs). The radius is before any drying, which sliderBody applies: done here, where every
// use of the radius sees it, it cost 0.22 ms a frame.
vec4 sliderAt(float column, float t, float w, float seed, vec4 rain, float runs) {
    vec4 r = hash42(vec2(column, seed));
    vec4 k = hash42(vec2(seed, column));
    float s = travel(t, r);
    float y = 1.12 - mod(s + k.x * 1.4, 1.4);
    float speed = (s - travel(t - 0.1, r)) * 10.0;
#if WEATHER
    float began = rain.x > 0.0 ? rain.x : rain.y;   // once the rain stops, every slider left is from before
    return vec4(track(y, column, r, w), y, step(k.y, 0.7 * began * runs) * (0.009 + 0.008 * k.z), speed);
#else
    return vec4(track(y, column, r, w), y, step(k.y, 0.7) * (0.009 + 0.008 * k.z), speed);
#endif
}

// The slider `s` over p's own column, counted by the rain it slid in with: a slider already on the glass when the
// rain last changed keeps the rain from before (sliderAt already knows that once the rain has stopped). Only p's own column is checked (once a pixel; in sliderAt, which
// runs up to four times a pixel, it cost 0.22 ms); a neighbour's counts by the rain now.
vec4 sliderRain(vec4 s, float column, float t, float seed, vec4 rain, float runs) {
    if (rain.x != rain.y && rain.x > 0.0) {
        vec4 r = hash42(vec2(column, seed));
        vec4 k = hash42(vec2(seed, column));
        if (floor((travel(t, r) + k.x * 1.4) / 1.4) <= floor((travel(rain.z, r) + k.x * 1.4) / 1.4)) {
            s.z = step(k.y, 0.7 * rain.y * runs) * (0.009 + 0.008 * k.z);
        }
    }
    return s;
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
// are taller than wide and lumpy where their edge snags on dirt. `share` of cells hold one in steady rain, scaled
// by the rain it landed in; where none has landed since the rain last changed, the one from before stays, and
// dries once the rain has stopped. `ts` is the sliders' clock. Returns (position in the drop on a unit disc,
// coverage, radius).
vec4 beadLayer(vec2 p, float cell, float rmin, float rmax, float share, float seed, float t, float ts, float lane, vec4 s, vec4 rain, float runs) {
    vec2 id = floor(p / cell);
    vec4 h = hash42(id + seed);
    vec4 g = hash42(id + seed + 17.0);
    float r0 = mix(rmin, rmax, h.w * h.w);
    float tall = 1.0 + 0.4 * smoothstep(0.007, 0.016, r0);
    vec2 c = (id + 0.5 + (h.yz - 0.5) * max(1.0 - 2.0 * r0 * tall / cell, 0.0)) * cell;
    float life = 40.0 + 120.0 * g.x;
    float since = mod(t + g.y * 300.0, life);                      // seconds since it landed
#if CHANGE
    float landed = t - since > rain.z ? rain.x : rain.y;
    if (t - since > rain.z && h.x >= share * rain.x) { since += life * ceil((t - since - rain.z) / life); landed = rain.y; }
#else
    float landed = rain.x;
#endif
#if DRY
    float r = max(drying(r0, rain.w), 1e-5);
#else
    float r = r0;
#endif
    vec2 d = (p - c) / vec2(r, r * tall);
    float edge = 1.0;
    if (rmax > 0.01) {
        float a = atan(d.y, d.x);
        edge += (0.045 * sin(3.0 * a + g.z * 6.28) + 0.025 * sin(5.0 * a + g.w * 6.28)) * smoothstep(0.006, 0.014, r0);
    }
    float cover = smoothstep(edge, edge * 0.85, length(d)) * step(h.x, share * landed);
#if DRY
    cover *= step(2e-5, r);
#endif
    if (cover > 0.0) {
        // swept up if the slider of the bead's own column has passed since it landed (judged at its middle, so the
        // whole bead goes at once even where it straddles two columns)
        float column = floor(c.x / lane);
        vec4 sc = column == floor(p.x / lane) ? s : sliderAt(column, ts, lane, 1.0, rain, runs);
        if (sc.z > 0.0 && abs(c.x - track(c.y, column, hash42(vec2(column, 1.0)), lane)) < sc.z + r
            && sinceSlider(c.y + sc.z, column, ts, lane, 1.0) < since - (t - ts)) { cover = 0.0; }
    }
    return vec4(d / edge, cover, r);
}

// The mist of specks too small to slide: one per cell, landing and drying at random while it rains (`fine` times
// as many in drizzle), and once it stops, the ones left drying for good; sweeping is handled by the caller, which
// fades them where a slider has just passed.
vec4 mistLayer(vec2 p, float t, vec4 rain, float fine) {
    float cell = 0.016;
    vec2 id = floor(p / cell);
    vec4 h = hash42(id + 3.0);
#if DRY
    float r = max(drying(0.001 + 0.001 * h.w, rain.w), 1e-5);
    float tm = rain.x > 0.0 ? t : min(t, rain.z);
    float on = step(h.x, min(0.5 * (rain.x > 0.0 ? rain.x : rain.y) * fine, 0.5 * max(fine, 1.0))) * step(fract(tm / (40.0 + 60.0 * h.w) + h.y), 0.8) * step(2e-5, r);
#else
    float r = 0.001 + 0.001 * h.w;
    float on = step(h.x, min(0.5 * rain.x * fine, 0.5 * max(fine, 1.0))) * step(fract(t / (40.0 + 60.0 * h.w) + h.y), 0.8);
#endif
    vec2 d = (p - (id + 0.5 + (h.yz - 0.5) * 0.8) * cell) / r;
    return vec4(d, smoothstep(1.0, 0.8, length(d)) * on, r);
}

// The body of the slider `s` over `column` at p: a teardrop whose rounded front leads, with a tail that points
// upward and sharpens as it speeds up, dried by `dried`. Returns like beadLayer.
vec4 sliderBody(vec2 p, float column, float w, float seed, vec4 s, float dried) {
#if DRY
    s.z = drying(s.z, dried);
#endif
    vec2 d = vec2(p.x - track(p.y, column, hash42(vec2(column, seed)), w), p.y - s.y);
    float tail = 1.25 + 1.5 * clamp(s.w, 0.0, 1.0);
    if (d.y > 0.0) { d.x *= 1.0 + 0.6 * clamp(d.y / (s.z * tail), 0.0, 1.0); d.y /= tail; }
    return vec4(d / max(s.z, 1e-4), smoothstep(s.z, s.z * 0.85, length(d)) * step(0.0001, s.z), s.z);
}

// The slider over p's column (its body from sliderBody) and behind it the pearls it sheds along its track. Returns
// (position in the drop on a unit disc, coverage) and (radius, the thin wet line of the track, how clear of mist
// the track at p still is: 1 for 5 s after the slider passed, then misting over for 25 s). `ts` is the sliders'
// clock, and `dried` how far drops have dried (rain.w).
mat3 sliderDrop(vec2 p, float t, float ts, float w, float seed, vec4 s, float dried) {
    float column = floor(p.x / w);
    vec4 r = hash42(vec2(column, seed));
    mat3 out3 = mat3(0.0);
    if (s.z > 0.0) {
        float x = track(p.y, column, r, w);
        float wide = s.z;
        out3[0] = sliderBody(p, column, w, seed, s, dried).xyz;
#if DRY
        out3[1] = vec3(drying(s.z, dried), smoothstep(0.0025, 0.0, abs(p.x - x)) * 0.5, 0.0);
#else
        out3[1] = vec3(s.z, smoothstep(0.0025, 0.0, abs(p.x - x)) * 0.5, 0.0);
#endif
        float band = smoothstep(wide * 0.8, wide * 0.4, abs(p.x - x));
        if (band > 0.0) {
            float age = sinceSlider(p.y, column, ts, w, seed) + (t - ts);
            out3[1].z = band * smoothstep(30.0, 5.0, age);   // clear 5 s, mists over 25
            // pearls: about one per radius down the track, a fifth of the slider's width, each left as it passed
            // (aged as the track at p, which is within a radius of it)
            float k = floor(p.y / wide);
            vec4 q = hash42(vec2(k, column) + seed);
#if DRY
            float pr = drying(wide * (0.15 + 0.15 * q.x), dried) * step(q.y, 0.6);
#else
            float pr = wide * (0.15 + 0.15 * q.x) * step(q.y, 0.6);
#endif
            vec2 pd = vec2(p.x - x - (q.z - 0.5) * wide * 0.5, p.y - (k + 0.5) * wide) / max(pr, 1e-4);
            float pearl = smoothstep(1.0, 0.8, length(pd)) * step(0.3, age) * step(age, 120.0);
            if (pearl > out3[0].z) { out3[0] = vec3(pd, pearl); out3[1].x = pr; }
        }
    }
    return out3;
}

// How much condensation scatters at p, 0-0.7, from the water fogging the pane in g/m² (GlassWeather): white by
// 0.5 g/m², but never more than 70%, as the glass between droplets passes the view straight through. It's
// thicker in patches, so it comes and goes unevenly, and on the inside of a single pane (`inside` 1) it starts
// low down, at the cold bottom edge where the room's air falls.
float fogCover(vec2 p, float water, float inside) {
    float w = water * (0.55 + 0.9 * noise(p * 3.0 + 7.1)) * mix(1.0, 0.3 + 2.4 * smoothstep(0.8, 0.0, p.y), inside);
    return 0.7 * (1.0 - exp(-w / 0.3));
}

// Dew: condensation grown into beads big enough to see, from about 40 g/m², tiny lenses that grow in place with a
// mean contact radius of 6 µm per g/m² (0.00003 screen heights). Returns like beadLayer.
vec4 dewLayer(vec2 p, float water) {
    float cell = 0.008;
    vec2 id = floor(p / cell);
    vec4 h = hash42(id + 29.0);
    float r = min(0.00003 * water * (0.3 + 1.4 * h.w * h.w), cell * 0.35);
    vec2 d = (p - (id + 0.5 + (h.yz - 0.5) * (1.0 - 2.0 * r / cell)) * cell) / r;
    return vec4(d, smoothstep(1.0, 0.8, length(d)) * step(h.x, 0.85), r);
}

// A snowflake's lace at q (in units of its radius, from its middle): six arms with side branches at 60 degrees,
// shorter towards the tips, as dendrites grow. Up to 1 on the ice.
float lace(vec2 q) {
    float rho = length(q);
    float a = mod(atan(q.y, q.x), 1.0472) - 0.5236;           // folded into one arm
    vec2 f = vec2(cos(a), abs(sin(a))) * rho;                 // along the arm, and out from it
    float k = fract((f.x - f.y * 0.577) / 0.2);
    float branch = smoothstep(0.06, 0.02, abs(k - 0.5) * 0.17) * step(f.y, 0.4 * (1.0 - f.x));
    return max(max(smoothstep(0.08, 0.03, f.y), branch) * smoothstep(1.0, 0.8, rho), smoothstep(0.22, 0.1, rho));
}

// Snow on the glass. `snow` is (amount, seconds per mg a flake takes to melt or 0 on freezing glass, flake size in
// mm, 0). Flakes land at random; on glass above freezing each goes glassy from its tips, collapses into a flat
// lens and leaves a bead of its water, which stays a while (melt time 17 s per mg per degree, after Locatelli &
// Hobbs' flake masses; see the doc). On freezing glass they stay white until the wind takes them. Returns the drop
// like sliderDrop ([0] position and coverage, [1].x radius), and in [1].y how white the ice is.
mat3 snowLayer(vec2 p, float t, vec4 snow) {
    float cell = 0.035;
    vec2 id = floor(p / cell);
    vec4 h = hash42(id + 41.0);
    mat3 out3 = mat3(0.0);
    if (h.x < 0.6 * min(snow.x, 1.5)) {
        float size = min(snow.z * (0.6 + 0.8 * h.w), 5.5), r = size * 0.0025;   // mm across; screen heights
        vec2 c = (id + 0.5 + (h.yz - 0.5) * (1.0 - 2.2 * r / cell)) * cell;
        if (length(p - c) > max(r, 0.0032) * 1.1) { return out3; }              // the flake, or the bead it leaves
        vec4 g = hash42(id + 43.0);
        float mass = 0.073 * pow(size, 1.4), bead = 0.0028 * pow(size, 0.43);  // mg; its water, 1.1·D^0.43 mm across
        float life = 40.0 + 80.0 * g.x, since = mod(t + g.y * 500.0, life);
        float melted = snow.y > 0.0 ? since / (snow.y * mass) : 0.0;
        float spin = g.z * 6.28;
        float white = 0.0;
        if (melted < 0.8) {
            vec2 q = mat2(cos(spin), sin(spin), -sin(spin), cos(spin)) * (p - c) / r;
            // an aggregate is several dendrites tangled together
            float ice = lace(q * (1.0 + 0.1 * melted));
            if (size > 2.5) { ice = max(ice, max(lace(q * 1.6 + vec2(0.45, 0.2)), lace(q.yx * 1.8 - vec2(0.3, 0.4)))); }
            white = ice * smoothstep(1.0 - 0.7 * melted, 0.7 - 0.7 * melted, length(q)) * (1.0 - smoothstep(0.1, 0.8, melted));
            white *= snow.y > 0.0 ? 1.0 : smoothstep(life, life * 0.85, since);  // frozen: blown away in the end
        }
        // its water, gathering into a bead as it melts
        float rb = mix(r * 0.6, bead, smoothstep(0.3, 1.0, melted)) * step(0.3, melted);
        vec2 d = (p - c) / max(rb, 1e-5);
        out3[0] = vec3(d, smoothstep(1.0, 0.85, length(d)) * step(1e-5, rb));
        out3[1] = vec3(rb, white * 0.9, 0.0);
    }
    return out3;
}

// Fern frost from its baked map (RainFrost) at p, as it has grown by `frost` (0-1): each texel shows once the
// growth reaches it, thin and faint at the young tips and whiter behind them, furred by the map's blurred copy of
// itself (A), with fine grey granular frost filling the gaps ever more thickly, till the pane is nearly white. The
// ferns are all there by 0.7, and the rest of the way fills the middle of the pane. Melting runs it backwards,
// last grown first. Returns (the ice, how much of the view it covers).
vec2 frostAt(vec4 map, vec2 p, float frost) {
    float grown = 1.4 * frost - (map.r + map.g / 255.0) * 1.3;   // in the bake's time, where the last fern is 1
    float ice = (map.b + 0.5 * map.a) * smoothstep(0.0, 0.004, grown) * mix(0.5, 1.0, smoothstep(0.0, 0.05, grown));
    float fill = smoothstep(0.0, 0.08, grown) * (0.2 + 0.65 * smoothstep(0.05, 0.5, grown)) * (0.6 + 0.4 * noise(p * 700.0));
    return vec2(min(ice, 1.0), clamp(ice + fill, 0.0, 1.0));
}

// Snow falling beyond the glass, far out of focus: faint soft discs drifting down at about 0.3 of the screen a
// second (a flake falls at 1 m/s a few metres away).
float snowfall(vec2 p, float t, float amount) {
    vec2 q = p + vec2(0.03 * sin(t * 0.3), t * 0.28);
    vec2 id = floor(q / 0.11);
    vec4 h = hash42(id + 51.0);
    float r = 0.11 * (0.1 + 0.3 * h.w * h.w);
    return step(h.x, 0.4 * min(amount, 1.5)) * smoothstep(r, r * 0.3, length(q - (id + 0.5 + (h.yz - 0.5) * 0.7) * 0.11)) * 0.05;
}
"""

/// The start of `main()`: the point `p` (1 = screen height), the drop over it, if any, and how much a trail has
/// wiped the fog there.
private let rainDrops = """
float aspect = u_size.x / u_size.y;
vec2 p = v_tex_coord * vec2(aspect, 1.0);
float t = u_clock;
#if WEATHER
// the rain on the glass (1 = steady), what it was until it last changed, when that was on the clock, and how far
// the drops left have dried since it stopped (mm² of diameter), from GlassWeather; and sliders and specks of mist
// for the kind of rain, 1 and 1 in steady rain
vec4 rain = u_rain;
float runs = u_pane.z, fine = u_pane.y;
#else
vec4 rain = vec4(1.0, 1.0, -1e6, 0.0);   // the steady rain, as always
float runs = 1.0, fine = 1.0;
#endif
#if DRY
float ts = sliderTime(t, u_stop);        // the sliders' clock
#else
float ts = t;
#endif
float wiped = 0.0;
vec4 drop = vec4(0.0);
#if WATER
// sliders run down columns this wide; static drops in three sizes: a mist of specks, beads, and a few big ones
float lane = 0.06;
vec4 s = sliderAt(floor(p.x / lane), ts, lane, 1.0, rain, runs);
#if CHANGE
s = sliderRain(s, floor(p.x / lane), ts, 1.0, rain, runs);
#endif
mat3 slide = sliderDrop(p, t, ts, lane, 1.0, s, rain.w);
wiped = max(slide[1].y, slide[1].z);
drop = mistLayer(p, t, rain, fine);
drop.z *= 1.0 - slide[1].z;
vec4 bead = beadLayer(p, 0.04, 0.0025, 0.007, 0.6, 7.0, t, ts, lane, s, rain, runs);
if (bead.z > drop.z) { drop = bead; }
bead = beadLayer(p, 0.09, 0.008, 0.022, 0.45, 11.0, t, ts, lane, s, rain, runs);
if (bead.z > drop.z) { drop = bead; }
if (slide[0].z > drop.z) { drop = vec4(slide[0], slide[1].x); }
// right at a column's edge, the body of the next column's slider can reach over
float across = fract(p.x / lane) < 0.5 ? -1.0 : 1.0;
if (abs(fract(p.x / lane) - 0.5) * lane > 0.5 * lane - 0.005) {
    vec4 beside = sliderAt(floor(p.x / lane) + across, ts, lane, 1.0, rain, runs);
#if CHANGE
    beside = sliderRain(beside, floor(p.x / lane) + across, ts, 1.0, rain, runs);
#endif
    vec4 next = sliderBody(p, floor(p.x / lane) + across, lane, 1.0, beside, rain.w);
    if (next.z > drop.z) { drop = next; }
}
#endif
bool dewy = false;   // a dew bead: too small for the bokeh city to work out its view (rainBokehScene)
#if DEW
if (u_glass.y > 40.0) { vec4 dew = dewLayer(p, u_glass.y); if (dew.z > drop.z) { drop = dew; dewy = true; } }
#endif
// snow landing on the glass: white lace, and the beads it melts into; and snow falling beyond it
float white = 0.0, falling = 0.0;
#if SNOW
mat3 flake = snowLayer(p, t, u_snow);
if (flake[0].z > drop.z) { drop = vec4(flake[0], flake[1].x); }
white = flake[1].y;
falling = snowfall(p, t, u_snow.x);
#endif
"""

/// Rain on a window with a photo behind it, focused on the glass. Behind it, the camera's defocus (`far`); drizzle
/// mist on the glass scatters part of that into a wide glow (`haze`), except where a slider has just swept it.
/// Each drop is a strong lens showing the sharp view (`near`) upside down, with a dark rim where light from outside
/// can't get through. Numbers are from measured footage and the optics of a water cap on glass; see the doc.
@MainActor private func rainPhotoScene(size: CGSize, name: String, weather: GlassUniforms?) -> SKScene {
    func texture(_ level: String) -> SKTexture { SKTexture(image: NSImage(contentsOf: resource("rain-\(name)-\(level).jpg")) ?? NSImage()) }
    let far = texture("far")
    let night: Float = name.hasSuffix("night") ? 1 : 0
    return shaderScene(size: size, source: GlassUniforms.defines(weather) + shaderCommon + """
    \(rainWater)

    void main() {
        \(rainDrops)

        // the photo covers the screen, cropped to fit
        vec2 fit = vec2(min(aspect / u_photoAspect, 1.0), min(u_photoAspect / aspect, 1.0));
        vec2 uv = (v_tex_coord - 0.5) * fit + 0.5;
        vec3 camera = texture2D(u_far, uv).rgb;
        vec3 haze = texture2D(u_haze, uv).rgb;
        #if SNOW
        camera = mix(camera, haze * 1.3 + mix(0.05, 0.5, 1.0 - u_night), falling);   // snow falling beyond the glass
        #endif
        #if WEATHER
        float mist = u_glass.x * (1.0 - wiped);
        #else
        float mist = 0.3 * (1.0 - wiped);
        #endif
        vec3 col = mix(camera, haze, mist) + vec3(0.02, 0.017, 0.014) * mist * u_night;
        // the scene scattered by anything on the glass: its glow, lit a little by the room, milky by day
        vec3 veil = haze + mix(vec3(0.03, 0.025, 0.02), 0.12 * (1.0 - haze), 1.0 - u_night);
        #if FOG
        // condensation (see fogCover): on the outside of the pane the trails wipe it and the drops sit on top, on the
        // inside it covers them
        float fog = fogCover(p, u_glass.y, u_pane.x);
        col = mix(col, veil, fog * (1.0 - u_pane.x) * (1.0 - wiped));
        mist += 0.5 * fog;
        #endif
        // at night each speck of mist holds a pinpoint of the brightest lights, so the glass around them glitters
        vec4 g = hash42(floor(v_tex_coord * u_size * 2.0));
        col += step(g.x, 0.02) * g.y * mist * 2.0 * max(camera - 0.4, 0.0) * u_night;

        // a drop is a lens with a 60 degree contact angle: at radius s it bends the view by `bend` towards its
        // middle, so it shows a wide patch of the scene, sharp and upside down; past s = 0.87 the light is
        // totally reflected inside it and only the dark room shows. Drying, it flattens into a weak lens with no rim.
        if (drop.z > 0.0) {
            float sd = length(drop.xy);
        #if DRY
            float sin60 = mix(0.866, 0.174, flattened(drop.w, rain.w)), k = 0.866 / sin60;
        #else
            float sin60 = 0.866, k = 1.0;
        #endif
            float sa = min(sd, 1.0) * sin60;
            float bend = asin(min(1.333 * sa, 1.0)) - asin(sa);
            vec2 centre = (p - drop.xy * drop.w) / vec2(aspect, 1.0);
            vec2 at = (centre - 0.5) * fit + 0.5 - drop.xy / max(sd, 0.001) * bend / u_fov * vec2(1.0 / u_photoAspect, 1.0);
            vec3 through = texture2D(u_near, clamp(at, 0.0, 1.0)).rgb * mix(0.98, 0.89, smoothstep(0.7 * k, 0.87 * k, sd));
            float aa = 1.0 / max(drop.w * u_size.y * 2.0, 1.0), dark = mix(0.15, 0.05, u_night);
        #if FROST
            // frozen: cloudy ice that loses the sharp view, with a frosted rim that catches the light
            float frozen = step(fract(drop.w * 7919.0), u_glass.w);
            through = mix(through, haze * 1.3 + mix(0.04, 0.35, 1.0 - u_night), frozen * 0.65);
            dark = mix(dark, 1.4, frozen);
        #endif
            through *= mix(1.0, dark, smoothstep(0.87 * k - aa, 0.87 * k + aa, sd));
            col = mix(col, through, drop.z);
        }
        #if FOG
        col = mix(col, veil, fog * u_pane.x);
        #endif
        #if SNOW
        // snowflakes on the glass: ice lit from behind by the scene, and a little by the room
        col = mix(col, haze * 1.4 + mix(vec3(0.06), vec3(0.45), 1.0 - u_night), white);
        #endif
        #if FROST
        // fern frost (frostAt): ice scatters the light behind it forward, so at night it glows with the lamps near it
        // and is dim away from them; by day it's white to blue-grey; melting, it goes grey and clear. It glints
        // where it catches a bright light.
        vec2 frost = frostAt(texture2D(u_frostMap, v_tex_coord), p, u_glass.z);
        vec3 lit = mix(haze, vec3(dot(haze, vec3(0.3, 0.59, 0.11))), 0.3);   // (ice scatters every colour alike)
        vec3 ice = mix(1.0 - exp(-lit * (0.5 + 2.6 * frost.x)) + vec3(0.02, 0.018, 0.016), vec3(0.86, 0.9, 0.95) * (0.75 + 0.3 * haze), 1.0 - u_night);
        col = mix(col, mix(ice, haze, u_pane.w * 0.6), frost.y * (0.9 - 0.5 * u_pane.w));
        col += step(g.x, 0.004) * frost.x * g.y * mix(max(camera - 0.3, 0.0) * 4.0, vec3(0.5), 1.0 - u_night);
        #endif

        col = grade(col, 0.5, u_hue, u_saturation, u_contrast, u_brightness);
        col += (hash21(v_tex_coord * u_size * 2.0) - 0.5) / 128.0;
        gl_FragColor = vec4(col, 1.0);
    }
    """, uniforms: [
        SKUniform(name: "u_far", texture: far), SKUniform(name: "u_near", texture: texture("near")),
        SKUniform(name: "u_haze", texture: texture("haze")), SKUniform(name: "u_night", float: night),
        SKUniform(name: "u_photoAspect", float: Float(far.size().width / max(far.size().height, 1))),
        SKUniform(name: "u_fov", float: 0.9),   // the photos' height in radians (about 52 degrees)
    ] + (weather?.all ?? []), knobs: gradeKnobs("rain"), speed: rainSpeed)
}
