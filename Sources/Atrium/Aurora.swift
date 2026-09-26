import SpriteKit

/// Aurora colours, bottom to top: lower fringe, body, upper, crown. All real emissions and their mixes: 557.7 nm oxygen
/// green (a yellow-green, hue about 95, as real photos record it), 630 nm oxygen red high up, nitrogen pink along the
/// lower edge in strong displays, nitrogen blue and violet where the top is sunlit, yellow where green and red
/// overlap, and the white of a faint display.
let auroraPalettes: [(name: String, colours: [SIMD3<Float>])] = [
    ("Green", [[0.58, 1.0, 0.5], [0.58, 1.0, 0.5], [0.45, 1.0, 0.6], [0.6, 0.25, 1.0]]),   // the classic
    ("Storm", [[1.0, 0.4, 0.75], [0.58, 1.0, 0.5], [0.8, 0.9, 0.45], [1.0, 0.25, 0.25]]),  // pink edge, green, red crown
    ("Red", [[0.58, 1.0, 0.5], [1.0, 0.35, 0.3], [1.0, 0.15, 0.2], [0.75, 0.1, 0.3]]),       // as seen from mid-latitudes
    ("Pink", [[1.0, 0.25, 0.6], [1.0, 0.45, 0.75], [0.75, 0.4, 1.0], [0.5, 0.25, 1.0]]),
    ("Purple", [[0.9, 0.3, 0.8], [0.6, 0.35, 1.0], [0.45, 0.3, 1.0], [0.8, 0.2, 0.5]]),
    ("Blue", [[0.25, 0.9, 0.7], [0.3, 0.6, 1.0], [0.35, 0.4, 1.0], [0.55, 0.3, 1.0]]),      // sunlit nitrogen
    ("Yellow", [[0.4, 1.0, 0.45], [0.8, 1.0, 0.35], [1.0, 0.8, 0.3], [1.0, 0.35, 0.25]]),   // green and red overlapping
    ("White", [[0.85, 1.0, 0.92], [0.8, 0.95, 0.9], [0.75, 0.85, 0.95], [0.65, 0.7, 0.95]]), // a faint display
]

/// The Green, Storm and Red colours before the photoreal pass, for the Compare switch.
/// ponytail: delete with the switch once Dave picks.
private let classicColours: [String: [SIMD3<Float>]] = [
    "Green": [[0.25, 1.0, 0.55], [0.2, 1.0, 0.5], [0.2, 0.85, 0.55], [0.6, 0.25, 1.0]],
    "Storm": [[1.0, 0.3, 0.6], [0.2, 1.0, 0.5], [0.7, 0.8, 0.35], [1.0, 0.15, 0.2]],
    "Red": [[0.3, 0.95, 0.5], [1.0, 0.35, 0.3], [1.0, 0.15, 0.2], [0.75, 0.1, 0.3]],
]

let auroraKnobs = [
    Knob(key: "aurora.speed", label: "Speed", range: 0...6, standard: 1, section: "Motion", format: .times),
    Knob(key: "aurora.classic", label: "Show the old curtains", range: 0...1, standard: 0, section: "Compare", format: .toggle),
] + gradeKnobs("aurora")

/// A seeded generator (SplitMix64), so one roll of the curtains can be rendered again while tuning.
private struct SplitMix: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// One periodic row of 4096 texels (plus a wrapped one) that the curtains read along their length:
/// R a fold curve (48 sines, amplitude falling as frequency^-1.4), G its slope, B a barcode of rays (soft bumps of
/// random width and strength), A how high each ray reaches. Returns the texture, its bytes and the slope's scale.
@MainActor private func auroraArc(_ rng: inout SplitMix) -> (SKTexture, [UInt8], Float) {
    let n = 4096
    var fold = [Double](repeating: 0, count: n), slope = fold, rays = fold, height = fold
    for _ in 0..<48 {
        let k = (3 * pow(80, Double.random(in: 0...1, using: &rng))).rounded()
        let a = pow(k, -1.4) * Double.random(in: 0.5...1, using: &rng), phase = Double.random(in: 0...(2 * .pi), using: &rng)
        for i in 0..<n {
            let x = 2 * .pi * k * Double(i) / Double(n) + phase
            fold[i] += a * sin(x)
            slope[i] += a * 2 * .pi * k * cos(x)
        }
    }
    var x = 0.0
    while x < Double(n) {
        let w = Double.random(in: 1.5...5, using: &rng), a = pow(Double.random(in: 0...1, using: &rng), 2)
        for d in -12...12 {
            let dx = (x.rounded() + Double(d)) - x
            rays[((Int(x.rounded()) + d) % n + n) % n] += a * exp(-dx * dx / (2 * w * w))
        }
        x += Double.random(in: 3...12, using: &rng)
    }
    for _ in 0..<24 {
        let k = (100 * pow(6, Double.random(in: 0...1, using: &rng))).rounded(), phase = Double.random(in: 0...(2 * .pi), using: &rng)
        for i in 0..<n { height[i] += sin(2 * .pi * k * Double(i) / Double(n) + phase) }
    }
    let fMax = fold.map(abs).max()!, sMax = slope.map(abs).max()!, rMax = rays.max()!, hMax = height.map(abs).max()!
    var bytes = [UInt8](repeating: 0, count: (n + 1) * 4)
    for i in 0...n {
        let j = i % n
        let v = [0.5 + 0.5 * fold[j] / fMax, 0.5 + 0.5 * slope[j] / sMax, rays[j] / rMax, 0.5 + 0.5 * height[j] / hMax]
        for c in 0..<4 { bytes[i * 4 + c] = UInt8(max(0, min(255, v[c] * 255))) }
    }
    let texture = SKTexture(data: Data(bytes), size: CGSize(width: n + 1, height: 1))
    texture.filteringMode = .linear
    return (texture, bytes, Float(sMax / fMax))
}

/// The sky's horizon (where the photo's eye level is) and the lens: tan of half the view across.
private let auroraHorizon: Float = 0.26, auroraLens: Float = 0.8

/// The northern lights as they are: sheets of light about a kilometre thick hanging along the magnetic field, 100 km
/// up at their lower edge and a few hundred km away, seen in perspective from the ground. Each pixel's line of sight
/// meets each curtain in closed form, and the height it meets it at sets the colour (green low, the palette's upper
/// and crown colours higher) and brightness; folds brighten where the sheet is seen edge-on, rays converge toward the
/// magnetic zenith, and the air dims and reddens what's low. Over a grey-teal airglow, with clumped, coloured stars,
/// and a real snowy range lit by it. A new arrangement on each load; the palette is pinned in Settings or rolled.
@MainActor func aurora(size: CGSize) -> SKScene {
    let pick = auroraPalettes.first { $0.name == UserDefaults.standard.string(forKey: "aurora.palette") } ?? auroraPalettes.randomElement()!
    let c = pick.colours, old = classicColours[pick.name] ?? c
    var rng = SplitMix(state: UInt64(ProcessInfo.processInfo.environment["AURORA_SEED"] ?? "") ?? .random(in: 0...UInt64.max))
    let (arc, bytes, slope) = auroraArc(&rng)
    // Up to four curtains, each along a line on the ground `dist` km away whose normal points `angle` from north: one
    // main arc, often a second and sometimes a third, all far enough off that their lower edges clear the summits.
    var dist = SIMD4<Float>(), angle = dist, lum = dist, low = dist, thick = dist
    let main = Float.random(in: -0.35...0.35, using: &rng)
    for i in 0..<4 {
        dist[i] = i == 0 ? .random(in: 220...330, using: &rng) : .random(in: 180...380, using: &rng)
        angle[i] = main + .random(in: -0.25...0.25, using: &rng)
        lum[i] = i == 0 ? 1 : (Float.random(in: 0...1, using: &rng) < [0, 0.45, 0.2, 0][i] ? .random(in: 0.3...0.7, using: &rng) : 0)
        low[i] = .random(in: 98...110, using: &rng)
        thick[i] = .random(in: 3...12, using: &rng)
    }
    func linear(_ v: SIMD3<Float>) -> SIMD3<Float> { SIMD3(pow(v.x, 2.2), pow(v.y, 2.2), pow(v.z, 2.2)) }
    let scene = shaderScene(size: size, source: shaderCommon + """
    vec2 arcAt(float x) { return vec2((fract(x) * 4096.0 + 0.5) / 4097.0, 0.5); }

    void main() {
        float aspect = u_size.x / u_size.y;
        vec2 uv = v_tex_coord;
        vec2 p = uv * vec2(aspect, 1.0);
        float t = u_time;
        vec3 col = vec3(0.0);
        if (u_classic > 0.5) {
            col = mix(vec3(0.02, 0.05, 0.08), vec3(0.004, 0.008, 0.03), smoothstep(0.1, 1.0, uv.y));
            col += vec3(0.85, 0.9, 1.0) * starField(uv * u_size, 11.0, 0.3, t);
            vec3 aurora = vec3(0.0);
            for (int i = 0; i < 3; i++) {
                float fi = float(i);
                float x = p.x * (0.6 + 0.25 * fi) + fi * 3.1;
                float fold = sin(x * 2.4 + t * 0.04 + fi * 1.7) + 0.6 * sin(x * 5.3 - t * 0.03 + fi);
                float edge = 0.5 + 0.1 * fi + 0.045 * fold + 0.08 * (noise(vec2(x * 0.7 + t * 0.01, fi * 4.0)) - 0.5);
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
                float ch = h + (0.5 - pn) * 0.09;
                vec3 hue = mix(u_old0, u_old1, smoothstep(-0.01, 0.012, ch));
                hue = mix(hue, u_old2, smoothstep(0.03, 0.14, ch));
                hue = mix(hue, u_old3, smoothstep(0.12, 0.3, ch));
                aurora += hue * ((body + rim * 0.7 + tail) * rays + below) * patches * (1.0 - 0.25 * fi);
            }
            col += (1.0 - exp(-aurora * 0.9)) * smoothstep(1.12, 0.72, uv.y);
        } else {
            // a level camera facing north, its eye level where the photo's is
            vec3 dir = vec3((uv.x - 0.5) * 2.0 * u_lens, max(uv.y - u_horizon, 0.001) * 2.0 * u_lens / aspect, 1.0);
            float hor = length(dir.xz);
            vec2 hd = dir.xz / hor;
            float tanEl = dir.y / hor;
            float el = atan(tanEl);
            // air mass (Kasten and Young): low light is dimmed, reddened and softened by haze
            float X = 1.0 / (sin(el) + 0.50572 * pow(el * 57.2958 + 6.07995, -1.6364));
            vec3 ext = exp(-0.921 * X * vec3(0.10, 0.15, 0.25));
            float ax = clamp((X - 1.0) / 20.0, 0.0, 1.0);

            vec3 light = vec3(0.0);
            for (int i = 0; i < 4; i++) {
                if (u_lum[i] > 0.0) {
                    float fi = float(i);
                    float cp = cos(u_angle[i]);
                    float sp = sin(u_angle[i]);
                    float co = hd.y * cp + hd.x * sp;                 // cos of our heading from the curtain's normal
                    float sn = hd.x * cp - hd.y * sp;
                    // the sheet leans 11 degrees toward us along the field, so higher up we meet it nearer
                    float den = max(co + 0.2 * cp * tanEl, 0.02);
                    float l = (u_dist[i] + 20.0 * cp) / den * sn;      // km along the curtain
                    vec4 f1 = texture2D(u_arc, arcAt(l / 3000.0 + fi * 0.27 + u_phase * 0.0002));
                    vec4 f2 = texture2D(u_arc, arcAt(l / 500.0 + fi * 0.61 - u_phase * 0.0007));
                    float fold = (f1.r - 0.5) * 90.0 + (f2.r - 0.5) * 14.0;
                    float m = u_slope * ((f1.g - 0.5) * 90.0 / 3000.0 + (f2.g - 0.5) * 14.0 / 500.0);
                    float num = u_dist[i] + fold + 20.0 * cp;
                    float s = max(num, 0.0) / den;
                    float h = s * tanEl + s * s / 12742.0;             // the height we see, over a round Earth
                    float seen = smoothstep(0.02, 0.08, den) * smoothstep(0.0, 5.0, num);
                    // rays: read at each ray's foot, so they lean together up the field lines
                    float rx = (s * sn - 0.2 * (h - 100.0) * sp) / u_rayScale + fi * 0.13 + u_phase * 0.000025;
                    vec4 r = texture2D(u_arc, arcAt(rx));
                    r.ba = mix(r.ba, vec2(0.3, 0.5), smoothstep(1.0, 4.0, fwidth(rx) * 4096.0));   // finer than a pixel
                    // seen from below, the line of sight crosses the slab over a range of heights, which blurs it
                    float pfh = min(sqrt(1.0 + m * m) / sqrt((co - m * sn) * (co - m * sn) + 0.04), 3.0);
                    float sh = u_thick[i] * tanEl * pfh;
                    r.ba = mix(r.ba, vec2(0.3, 0.5), smoothstep(4.0, 25.0, sh));
                    float patches = 0.4 + 0.6 * smoothstep(0.2, 0.75, texture2D(u_arc, arcAt(l / 2500.0 + fi * 0.37 + u_phase * 0.00002)).r);
                    float dh = h - u_low[i];
                    // the emission rises over a few km at the lower edge and fades with height, smoothly: any step or
                    // corner at the edge draws a hairline along it
                    float green = (dh < 0.0 ? exp(-dh * dh / (30.0 + 2.0 * sh * sh + 400.0 * ax))
                                            : exp((4.0 - sqrt(dh * dh + 16.0)) / (10.0 + 25.0 * r.a * r.a)))
                                  * (1.0 - u_rays + 2.0 * u_rays * r.b);
                    float red = exp(-(h - 240.0) * (h - 240.0) / 3600.0);
                    float glow = (0.015 + 0.1 * ax) * exp(-abs(dh) / (15.0 + 100.0 * ax));   // scattered around the edge
                    float path = pfh * min(length(dir) / hor, 3.0) * patches * u_lum[i] * seen;
                    // the thin fringe under the edge only tints what it covers: seen through a deep slab it averages away
                    vec3 hue = mix(u_body, u_fringe, (1.0 - smoothstep(-4.0, 3.0, dh)) * 4.0 / (4.0 + sh));
                    hue = mix(hue, u_upper, smoothstep(20.0, 70.0, dh));
                    // the crown: oxygen red (or the palette's top colour) high up, too slow to show rays
                    light += (hue * (green + glow) + u_crown * u_red * red) * path;
                }
            }
            // airglow, grey-teal and brighter toward the horizon, then stars: a faint tail and a few bright ones,
            // clumped as real star fields are, each from orange to blue-white; all through the tone curve of a photo
            vec3 sky = mix(vec3(0.016, 0.022, 0.025), vec3(0.0052, 0.007, 0.0116), 1.0 - exp(-el * 5.0));
            vec2 pts = uv * u_size;
            float clump = 0.35 + 1.3 * noise(p * 3.5 + 17.0);
            float star = starField(pts, 11.0, 0.3 * clump, t) * 0.2 + starField(pts + 5.0, 6.0, 0.35 * clump, t) * 0.05;
            vec3 tint = mix(vec3(1.0, 0.75, 0.5), vec3(0.8, 0.88, 1.0), hash21(floor(pts / 11.0) + 3.0));
            col = 1.0 - exp(-(sky + (star * tint + light * u_gain) * ext));
            col = pow(col, vec3(1.0 / 2.2));
        }
        col = grade(col, 0.3, u_hue, u_saturation, u_contrast, u_brightness);
        col += (hash21(v_tex_coord * u_size * 2.0) - 0.5) / 128.0;
        gl_FragColor = vec4(col, 1.0);
    }
    """, uniforms: [
        SKUniform(name: "u_fringe", vectorFloat3: linear(c[0])), SKUniform(name: "u_body", vectorFloat3: linear(c[1])),
        SKUniform(name: "u_upper", vectorFloat3: linear(c[2])), SKUniform(name: "u_crown", vectorFloat3: linear(c[3])),
        SKUniform(name: "u_old0", vectorFloat3: old[0]), SKUniform(name: "u_old1", vectorFloat3: old[1]),
        SKUniform(name: "u_old2", vectorFloat3: old[2]), SKUniform(name: "u_old3", vectorFloat3: old[3]),
        SKUniform(name: "u_arc", texture: arc), SKUniform(name: "u_slope", float: slope),
        SKUniform(name: "u_dist", vectorFloat4: dist), SKUniform(name: "u_angle", vectorFloat4: angle),
        SKUniform(name: "u_lum", vectorFloat4: lum), SKUniform(name: "u_low", vectorFloat4: low),
        SKUniform(name: "u_thick", vectorFloat4: thick),
        SKUniform(name: "u_horizon", float: auroraHorizon), SKUniform(name: "u_lens", float: auroraLens),
        SKUniform(name: "u_rayScale", float: 20000), SKUniform(name: "u_rays", float: 0.15),
        SKUniform(name: "u_red", float: ["Storm": 0.1, "Red": 0.08][pick.name] ?? 0.02), SKUniform(name: "u_gain", float: 0.7),
    ], knobs: auroraKnobs)
    let sky = AuroraLight(arc: bytes, slope: slope, dist: dist, angle: angle, lum: lum)
    let phase = SKUniform(name: "u_phase", float: 0), poolA = SKUniform(name: "u_poolA", vectorFloat4: .zero)
    let poolB = SKUniform(name: "u_poolB", vectorFloat4: .zero), glow = SKUniform(name: "u_glow", vectorFloat3: .zero)
    (scene.children.first as? SKSpriteNode)?.shader?.addUniform(phase)
    // The aurora's light on the land: starlight and airglow everywhere, plus the curtains' own colour, strongest on
    // open ground under the brightest stretch of the arc.
    func unit(_ v: SIMD3<Float>) -> SIMD3<Float> { v / max((v * [0.2126, 0.7152, 0.0722]).sum(), 1e-4) }
    let tint = unit(0.7 * linear(c[1]) + 0.3 * linear(c[2]))
    func light() {
        let pool = sky.pool()
        poolA.vectorFloat4Value = SIMD4(pool[0..<4]); poolB.vectorFloat4Value = SIMD4(pool[4..<8])
        glow.vectorFloat3Value = [0.016, 0.022, 0.025] + tint * 0.004 * pool.reduce(0, +) / 8
    }
    light()
    scene.addChild(auroraGround(size: size, grade: (scene as! ShaderScene).knobs.map(\.uniform) + [
        poolA, poolB, glow, SKUniform(name: "u_star", vectorFloat3: unit([0.55, 0.72, 1.0]) * 0.02),
        SKUniform(name: "u_aurora", vectorFloat3: tint * 0.016),
    ]))
    // the curtains' clock, in scene time so it stops while the wallpaper is hidden; their light is re-measured each second
    // 1× is a real display's pace: folds drifting 0.35-0.6 km/s along the arc, rays 0.5 km/s
    let speed = (scene as! ShaderScene).knobs.first { $0.knob.key == "aurora.speed" }!.uniform
    var last: CGFloat = 0, since: Float = 0
    scene.run(.repeatForever(.customAction(withDuration: 60) { _, elapsed in
        let dt = Float(elapsed >= last ? elapsed - last : elapsed)
        last = elapsed
        sky.phase += dt * speed.floatValue
        phase.floatValue = sky.phase
        since += dt
        if since >= 1 { since = 0; light() }
    }))
    return scene
}

/// Where the curtains are and how bright, as the shader draws them, kept on the CPU so the ground can be lit by
/// them: `pool()` is the light from the arc above each of 8 strips across the screen, from the curtains' brightness,
/// folds and patches along their lower edges (their rays and heights barely matter to the land).
@MainActor private final class AuroraLight {
    let arc: [UInt8], slope: Float, dist: SIMD4<Float>, angle: SIMD4<Float>, lum: SIMD4<Float>
    var phase: Float = 0

    init(arc: [UInt8], slope: Float, dist: SIMD4<Float>, angle: SIMD4<Float>, lum: SIMD4<Float>) {
        (self.arc, self.slope, self.dist, self.angle, self.lum) = (arc, slope, dist, angle, lum)
    }

    /// The arc texture at `x` (wrapping), as the shader's `texture2D(u_arc, arcAt(x))` reads it, to the nearest texel.
    private func at(_ x: Float) -> SIMD4<Float> {
        let i = Int((x - x.rounded(.down)) * 4096) % 4096 * 4
        return SIMD4(Float(arc[i]), Float(arc[i + 1]), Float(arc[i + 2]), Float(arc[i + 3])) / 255
    }

    func pool() -> [Float] {
        (0..<8).map { k in
            let hx = (Float(k) + 0.5) / 8 * 2 * auroraLens - auroraLens, norm = (hx * hx + 1).squareRoot()
            let hd = SIMD2(hx / norm, 1 / norm)
            var b: Float = 0
            for i in 0..<4 where lum[i] > 0 {
                let fi = Float(i), cp = cos(angle[i]), sp = sin(angle[i])
                let co = hd.y * cp + hd.x * sp, sn = hd.x * cp - hd.y * sp
                let den = max(co + 0.06 * cp, 0.02), l = (dist[i] + 20 * cp) / den * sn
                let f1 = at(l / 3000 + fi * 0.27 + phase * 0.0002), f2 = at(l / 500 + fi * 0.61 - phase * 0.0007)
                let m = slope * ((f1.y - 0.5) * 90 / 3000 + (f2.y - 0.5) * 14 / 500)
                let pfh = min((1 + m * m).squareRoot() / ((co - m * sn) * (co - m * sn) + 0.04).squareRoot(), 3)
                let patch = at(l / 2500 + fi * 0.37 + phase * 0.00002).x
                let patches = 0.4 + 0.6 * simd_smoothstep(0.2, 0.75, patch)
                b += lum[i] * pfh * patches * simd_smoothstep(0.02, 0.08, den)
            }
            return b
        }
    }
}

/// The Tetons in winter from Teton Point (NPS photo by A. Falgoust, public domain,
/// commons.wikimedia.org/wiki/File:Teton_Point_Turnout_in_Winter_(52098766554).jpg) with the sky cut out, stored as its
/// albedo at half scale: its own daylight, haze and colour cast were taken out offline. `aurora-ground-aux` holds each
/// point's distance in red (log, estimated with Depth Anything V2) and open snow in green.
@MainActor private enum AuroraGround {
    static let photo = SKTexture(image: NSImage(contentsOf: resource("aurora-ground.heic")) ?? NSImage())
    static let aux = SKTexture(image: NSImage(contentsOf: resource("aurora-ground-aux.png")) ?? NSImage())
    /// Where the highest summit sits: down from the top of the photo as a fraction of its height, and up the screen.
    static let summit = 60.0 / 1390, peak = 0.38
}

/// The snowy range and the flats in front of it, as seen on a real long exposure: lit by starlight and by the aurora
/// above each part of it (`u_poolA`/`u_poolB`, from `AuroraLight`), bluer and greyer as the eye sees in the dark,
/// hazing into the glow above the skyline with distance, and glinting where near snow catches the light.
@MainActor private func auroraGround(size: CGSize, grade: [SKUniform]) -> SKNode {
    let photo = AuroraGround.photo.size(), aspect = photo.width / max(photo.height, 1)
    let peak = size.height * AuroraGround.peak, summit = AuroraGround.summit
    let width = max(size.width, peak / (1 - summit) * aspect), height = width / aspect
    let top = peak + summit * height
    let ground = SKSpriteNode(texture: AuroraGround.photo, size: CGSize(width: width, height: height))
    ground.anchorPoint = CGPoint(x: 0.5, y: 1)
    ground.position = CGPoint(x: size.width / 2, y: top)
    ground.zPosition = 1
    ground.shader = SKShader(source: shaderCommon + """
    void main() {
        vec4 photo = texture2D(u_texture, v_tex_coord);
        vec2 aux = texture2D(u_aux, v_tex_coord).rg;
        vec3 albedo = 2.0 * pow(photo.rgb / max(photo.a, 0.004), vec3(2.2));
        vec2 pts = u_frame.xy + v_tex_coord * u_frame.zw;
        // the aurora hangs in the north, above and beyond the range: open snow faces up into its light, while the
        // faces of the range we see are turned away from it and get little but starlight
        float px = pts.x / u_width * 8.0 - 0.5;
        float pool = dot(max(1.0 - abs(px - vec4(0.0, 1.0, 2.0, 3.0)), 0.0), u_poolA)
                   + dot(max(1.0 - abs(px - vec4(4.0, 5.0, 6.0, 7.0)), 0.0), u_poolB);
        float open = mix(0.25, 1.0, smoothstep(0.92, 0.8, aux.r));
        vec3 col = albedo * (u_star + u_aurora * pool * open);
        col = mix(col, dot(col, vec3(0.2126, 0.7152, 0.0722)) * vec3(0.78, 0.92, 1.2), 0.3);   // Purkinje
        float far = (pow(32.0, aux.r) - 1.0) / 3.1;
        col = mix(col, u_glow, 1.0 - exp(-0.06 * far));
        // crystals on the near snow catching the light, twinkling slowly
        float glint = starField(pts, 3.0, 0.15, u_time * 3.0) * aux.g * smoothstep(0.6, 0.1, aux.r);
        col += glint * vec3(0.85, 0.95, 1.0) * 0.3;
        col = grade(pow(col, vec3(1.0 / 2.2)), 0.3, u_hue, u_saturation, u_contrast, u_brightness);
        col += (hash21(pts * 2.0) - 0.5) / 128.0;
        gl_FragColor = vec4(col, 1.0) * photo.a;
    }
    """, uniforms: [
        SKUniform(name: "u_aux", texture: AuroraGround.aux), SKUniform(name: "u_width", float: Float(size.width)),
        SKUniform(name: "u_frame", vectorFloat4: [Float((size.width - width) / 2), Float(top - height), Float(width), Float(height)]),
    ] + grade)
    return ground
}
