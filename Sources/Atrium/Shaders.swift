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

// One star's light `d` points from its centre, from its cell's four random numbers `r`. A star can't draw outside
// its cell, so it and its glow fade out within `room`, the distance to the cell's nearest edge; cut off at the edge,
// the glow showed as a faint square around each bright star.
float starLight(float d, float room, vec4 r, float t) {
    float mag = pow(r.w, 5.0);
    float twinkle = 0.8 + 0.2 * sin(mod(t, 3600.0) * (1.0 + 3.0 * r.x) + r.x * 50.0); // hourly: a jump in a twinkle can't be seen
    return (smoothstep(min(0.6 + 1.2 * mag, room), 0.0, d) + 0.3 * mag * exp(-d * 0.4) * smoothstep(room, 0.0, d)) * (0.3 + 0.9 * mag) * twinkle;
}

// One star per `cell`-point grid square, kept with probability `density`; most faint, a few bright, all twinkling.
float starField(vec2 pts, float cell, float density, float t) {
    vec4 r = hash42(floor(pts / cell));
    if (r.x > density) { return 0.0; }
    vec2 off = (r.yz - 0.5) * 0.7;
    return starLight(length(fract(pts / cell) - 0.5 - off) * cell, (0.5 - max(abs(off.x), abs(off.y))) * cell, r, t);
}

// A few bright foreground stars with four-point diffraction spikes; about half shimmer very gently and slowly.
float brightStar(vec2 pts, float cell, float t) {
    vec4 r = hash42(floor(pts / cell) + 31.0);
    float h = r.x;
    if (h > 0.18) { return 0.0; }
    vec2 d = (fract(pts / cell) - 0.5 - (r.yz - 0.5) * 0.6) * cell;
    float core = exp(-dot(d, d) * 0.15);
    float spikes = exp(-abs(d.x) * 1.2) * exp(-abs(d.y) * 0.06) + exp(-abs(d.y) * 1.2) * exp(-abs(d.x) * 0.06);
    float shimmer = h < 0.09 ? 0.93 + 0.07 * sin(mod(t, 3600.0) * (0.6 + 5.0 * h) + h * 90.0) : 1.0;
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

/// How brightly the Sun lights a point on the Moon's disc, for the small Moons in Weather and Night Sky: McEwen's
/// lunar-Lambert, as in The Moon. A full Moon is flat to the limb; at other phases the light fades toward the
/// terminator, as it does in the sky. `n` is the surface normal and `l` points at the Sun, with the viewer along +z.
let moonShade = """
float moonShade(vec3 n, vec3 l) {
    float g = acos(clamp(l.z, -1.0, 1.0)) * 57.29578;
    float lommel = clamp(1.0 - 0.019 * g + 2.42e-4 * g * g - 1.46e-6 * g * g * g, 0.4, 1.0);
    float mu0 = max(dot(n, l), 0.0);
    return lommel * 2.0 * mu0 / (mu0 + n.z + 1e-4) + (1.0 - lommel) * mu0;
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

/// Nebula's settings: how often it changes to a new one, then the Look sliders, and how crisp its dust lanes are
/// (0, the standard, is their soft look before it had the slider).
let nebulaKnobs = [
    Knob(key: "nebula.every", label: "New nebula every", range: 0...30, standard: 8, section: "Change", format: .minutes),
] + gradeKnobs("nebula") + [
    Knob(key: "nebula.detail", label: "Crisp dust lanes", range: 0...1, standard: 0, section: "Look"),
]

/// Deep-space gas clouds cut by dark dust lanes, drifting very slowly. Every load rolls a new one: its own cloud
/// structure, scale, palette (unless one is pinned in Settings), star field, and the band the cloud lies along.
/// Left running, it changes to a freshly rolled one every few minutes (see `NebulaCycle`).
@MainActor func nebula(size: CGSize) -> SKScene {
    let cycle = NebulaCycle()
    let scene = shaderScene(size: size, source: shaderCommon + """
    // Galaxy's star layer: one layer of background stars on a grid turned by `a`, so layers of different sizes never
    // line up into a lattice, kept where `keep` allows. Mostly faint: only the big, sparse layers hold bright stars,
    // with a soft halo. Colours run from orange dwarfs through white to blue giants.
    // ponytail: a copy of Galaxy's (Galaxy.swift); move both into shaderCommon when a third scene wants it
    vec3 starLayer(vec2 pts, float cell, mat2 a, float keep, float t) {
        vec2 q = a * pts / cell;
        vec4 h = hash42(floor(q));
        if (h.x > keep) { return vec3(0.0); }
        vec4 k = hash42(floor(q) + 57.0);
        vec2 d = (fract(q) - 0.5 - (h.yz - 0.5) * 0.7) * cell;
        float mag = pow(h.w, 6.0) * min(cell / 17.0, 1.0);
        float r = 0.4 + 1.1 * mag;
        float glow = exp(-dot(d, d) / (r * r)) + 0.3 * mag * exp(-length(d) / (0.06 * cell));
        float twinkle = 0.88 + 0.12 * sin(mod(t, 3600.0) * (0.6 + 2.0 * k.x) + k.y * 40.0); // hourly, as in starField
        vec3 tint = mix(mix(vec3(0.72, 0.82, 1.0), vec3(1.0, 0.97, 0.94), smoothstep(0.0, 0.3, k.z)),
                        vec3(1.0, 0.72, 0.5), smoothstep(0.55, 1.0, k.z));
        return tint * glow * (0.12 + 2.0 * mag) * twinkle;
    }

    // The field stars behind the gas, as in Galaxy's sky: two layers of different sizes and angles, bunched into loose
    // clusters and thinner patches by one broad noise.
    vec3 fieldStars(vec2 pts, float t) {
        float crowd = 0.25 + 1.5 * smoothstep(0.2, 0.8, noise(pts / 160.0));
        return starLayer(pts, 5.0, mat2(1.0, 0.0, 0.0, 1.0), 0.16 * crowd, t)
             + starLayer(pts, 17.0, mat2(0.76, 0.64, -0.64, 0.76), 0.3 * crowd, t);
    }

    // One nebula: its glow (rgb) and how much of the field stars behind it it hides (a). As `clip` rises from -0.2 to
    // 1.2 it dissolves, the thin outer gas and fine filaments first and the densest knots last; lowered again, the same
    // nebula condenses from its knots outward. It clips a smoother measure than the gas itself, mostly the broad warp
    // field, or it breaks into specks.
    vec4 nebulaAt(vec2 uv, float aspect, float t, vec2 seed, float zoom, vec3 shape, vec3 base, vec3 dense, vec3 accent,
                  vec3 hot, float clip, float detail) {
        // domain-warped fbm: the warp vector w folds the clouds into filaments
        vec2 q = uv * vec2(aspect, 1.0) * zoom + seed + vec2(t, t * 0.4);
        vec2 w = vec2(fbm(q + vec2(0.0, 1.3)), fbm(q + vec2(5.2, 8.1)));
        float gas = fbm(q + 1.8 * w + vec2(t * 0.5, 0.0));
        float dust = noise(q * 2.2 + 2.5 * w + 11.0) * 0.6 + noise(q * 4.7 + 3.0 * w) * 0.4;

        // ponytail: a band (height, slope, width from `shape`) so the cloud always crosses the screen
        float band = exp(-pow((uv.y - shape.x + shape.y * (uv.x - 0.5)) / shape.z, 2.0));
        float g = gas * 0.7 + band * 0.4;

        vec3 c = mix(base, dense, smoothstep(0.4, 0.8, g));
        c = mix(c, accent, smoothstep(0.42, 0.62, w.x) * 0.9);
        c = mix(c, hot, 0.8 * smoothstep(0.45, 0.65, g * w.y * 1.1));
        // measured over the visible gas of several rolls it runs 0.5 to 0.85, stretched here to 0 to 1
        float thick = clamp((g * 0.55 + (w.x + w.y) * 0.3 + band * 0.1 - 0.5) / 0.35, 0.0, 1.0);
        float keep = smoothstep(clip - 0.15, clip + 0.15, thick); // all of it while clip is -0.2 or less
        float density = smoothstep(0.25, 0.8, g) * keep;
        // The light follows the gas on past where density stops rising (g 0.8), or the brightest body flattens into one
        // tone: from g 0.7 up it dims a little below g 0.84 and brightens above it, about as much as the whole cloud.
        float glow = density * density * 2.2 * max(1.0 + 4.0 * (g - 0.84) * smoothstep(0.7, 0.8, g), 0.5);
        vec3 neb = 1.0 - exp(-c * glow);                                     // soft clip keeps bright cores from blowing out
        // Dark dust lanes. With `detail` (Crisp dust lanes, 0 to 1) a lane's edge takes the gas's own folds and narrows
        // from a blur tens of points wide to a crisp silhouette, and a thin rim just outside it is lit in the hot colour
        // where dense, hot gas lies beside it, as the Pillars' edges are lit by the stars they face. At 0 it's the soft
        // lanes from before the slider.
        float edge = dust + (gas - 0.5) * 0.4 * detail;
        float lo = 0.5 + 0.07 * detail;
        float lane = smoothstep(lo, 0.72 - 0.07 * detail, edge);
        neb *= 1.0 - 0.85 * lane;
        float rim = smoothstep(lo - 0.03, lo, edge) * (1.0 - lane) * smoothstep(0.3, 0.6, g * w.y * 1.1)
                  * smoothstep(0.5, 0.75, gas) * density * detail * 0.8;
        neb += (1.0 - neb) * (1.0 - exp(-hot * rim));                        // soft-clipped like the gas
        // The gas dims the stars behind it a little; a lane across the gas is dust in front of them and hides nearly
        // all of them. Only where there's gas to see it against, or open sky would be punched with starless holes.
        float hide = mix(0.6 * density, 0.9, lane * smoothstep(0.1, 0.5, density));
        return vec4(neb + c * 0.07 * band * keep, hide);                     // plus a faint wash around the cloud
    }

    void main() {
        float aspect = u_size.x / u_size.y;
        float t = u_now * 0.005; // one screen height of drift every ~5 minutes
        vec2 uv = v_tex_coord;
        vec2 pts = uv * u_size;

        // While it changes (u_mix 0 to 1 over 90 s), the next nebula is drawn too: the old one dissolves from its edges
        // inward over the first three quarters while the new one condenses out of its densest knots over the last
        // three quarters, evenly, so halfway the densest quarter or so of each is showing.
        float clipNow = mix(-0.2, 1.2, clamp(u_mix / 0.75, 0.0, 1.0));
        vec4 now = nebulaAt(uv, aspect, t, u_seed, u_zoom, u_band, u_base, u_dense, u_accent, u_hot, clipNow, u_detail);
        // each nebula has its own star field, moved by its seed; they swap over as it changes
        vec2 ptsNow = pts + u_seed * 97.0;
        vec3 field = fieldStars(ptsNow, u_now);
        float bright = brightStar(ptsNow + vec2(u_now * 0.2, 0.0), 180.0, u_now);
        vec4 next = vec4(0.0);
        if (u_mix > 0.0) { // only while changing, so the rest of the time it costs no more than one nebula
            float clipNext = mix(1.2, -0.2, clamp((u_mix - 0.25) / 0.75, 0.0, 1.0));
            next = nebulaAt(uv, aspect, t, u_seed2, u_zoom2, u_band2, u_base2, u_dense2, u_accent2, u_hot2, clipNext, u_detail);
            vec2 ptsNext = pts + u_seed2 * 97.0;
            field = mix(field, fieldStars(ptsNext, u_now), u_mix);
            bright = mix(bright, brightStar(ptsNext + vec2(u_now * 0.2, 0.0), 180.0, u_now), u_mix);
        }
        // screened, not added, or where the two overlap their light flares white
        vec4 neb = vec4(1.0 - (1.0 - now.rgb) * (1.0 - next.rgb), max(now.a, next.a));

        vec3 col = vec3(0.004, 0.004, 0.012) + neb.rgb;
        col += field * (1.0 - neb.a);
        col += vec3(1.0, 0.92, 0.85) * bright;

        col = grade(col, 0.3, u_hue, u_saturation, u_contrast, u_brightness);
        col += (hash21(v_tex_coord * u_size * 2.0) - 0.5) / 128.0;
        gl_FragColor = vec4(col, 1.0);
    }
    """, uniforms: cycle.now + cycle.next + [cycle.mix], knobs: nebulaKnobs)
    // Every 5 s it checks whether it's time for a new one, so a new "every" in Settings applies straight away. The
    // checks are SKActions, so they pause while the wallpaper is covered.
    scene.run(.repeatForever(.sequence([.wait(forDuration: 5), .run { [weak scene, cycle] in
        guard let scene, let change = cycle.tick(5) else { return }
        scene.run(change)
    }])))
    return scene
}

/// Hands one nebula over to a freshly rolled one every few minutes, as Settings says: the uniforms for the one
/// showing (`now`) and the next, which the shader draws together during the 90 s change (`mix` 0 to 1).
@MainActor private final class NebulaCycle {
    let now = NebulaCycle.uniforms(""), next = NebulaCycle.uniforms("2")
    let mix = SKUniform(name: "u_mix", float: 0)
    private var waited = 0.0, changing = false

    init() {
        // ("nebula.seed" is for the tests, which want the same roll twice; nothing else sets it.)
        let seed = UInt64(max(UserDefaults.standard.integer(forKey: "nebula.seed"), 0))
        var rng = SplitMix(state: seed > 0 ? seed : .random(in: 1...UInt64.max))
        Self.roll(now, using: &rng)
    }

    /// seed, zoom, band, then the palette's background, main gas, secondary gas and hot core
    private static func uniforms(_ suffix: String) -> [SKUniform] {
        [SKUniform(name: "u_seed" + suffix, vectorFloat2: .zero), SKUniform(name: "u_zoom" + suffix, float: 1.5),
         SKUniform(name: "u_band" + suffix, vectorFloat3: [0.5, 0, 0.3])]
            + ["u_base", "u_dense", "u_accent", "u_hot"].map { SKUniform(name: $0 + suffix, vectorFloat3: .zero) }
    }

    /// A new nebula: a new region of the endless noise field, its scale, the band it lies along (height, slope,
    /// width), and a palette, unless one is pinned.
    private static func roll(_ set: [SKUniform], using rng: inout some RandomNumberGenerator) {
        let palette = (nebulaPalettes.first { $0.name == UserDefaults.standard.string(forKey: "nebula.palette") }
            ?? nebulaPalettes.randomElement(using: &rng)!).colours
        set[0].vectorFloat2Value = [.random(in: 0...100, using: &rng), .random(in: 0...100, using: &rng)]
        set[1].floatValue = .random(in: 1.2...1.9, using: &rng)
        set[2].vectorFloat3Value = [.random(in: 0.38...0.62, using: &rng), .random(in: -0.6...0.6, using: &rng), .random(in: 0.26...0.4, using: &rng)]
        for i in 0..<4 { set[3 + i].vectorFloat3Value = palette[i] }
    }

    /// Time passing; returns the change to run once it's due.
    func tick(_ seconds: Double) -> SKAction? {
        let every = nebulaKnobs[0].value * 60
        guard !changing, every > 29 else { waited = 0; return nil }
        waited += seconds
        guard waited >= every else { return nil }
        changing = true
        var rng = SystemRandomNumberGenerator()
        Self.roll(next, using: &rng)
        let mix = mix
        return .sequence([.customAction(withDuration: 90) { _, elapsed in mix.floatValue = Float(elapsed / 90) },
                          .run { [weak self] in self?.finish() }])
    }

    /// The next nebula becomes the one showing.
    private func finish() {
        now[0].vectorFloat2Value = next[0].vectorFloat2Value
        now[1].floatValue = next[1].floatValue
        for i in 2..<7 { now[i].vectorFloat3Value = next[i].vectorFloat3Value }
        mix.floatValue = 0
        waited = 0
        changing = false
    }
}
