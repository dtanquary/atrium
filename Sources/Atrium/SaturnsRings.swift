import SpriteKit

/// Saturn's rings from just above their unlit face, running off to a horizon with the planet's edge rising at one
/// side, in today's sunlight: one shader that meets each pixel's ray with the ring plane and the planet
/// (docs/saturns-rings.md, How it works). For now one view, standing still: view C of the mock-ups, with the Sun
/// 8.4° south of the ring plane, as JPL Horizons gives it for 2026-11-18.
@MainActor func saturnsRingsScene(size: CGSize) -> SKScene {
    // ponytail: the profile is read on every build (10 ms in release, the pyramid's bake 8.5 ms more for the first
    // copy) though the shader takes only its first radius, step and length; keep those beside the shared pyramid if
    // building gets slow.
    let rings = RingProfile.load()
    let table = sharedTexture("saturn-rings-pyramid") { rings.pyramid() }

    // Mm, Saturn at the origin, the ring plane z = 0, the camera at +x. The camera is on the face the Sun isn't on,
    // 126 Mm out and 4 Mm up, looking 38° round from Saturn toward the orbit and 7° down, 70° across.
    // ponytail: the Sun fixed at 8.4° south, which drifts from the real one by about 0.3° a month (it climbs to 27° by
    // the 2032 solstice); from the date in step (d) of the build order.
    let (distance, height, yaw, pitch, field) = (126.0, 4.0, 38.0 * .pi / 180, 7.0 * .pi / 180, 70.0 * .pi / 180)
    let (sunUp, sunRound) = (-8.4 * .pi / 180, 320.0 * .pi / 180) // above the ring plane; round from the camera
    let side: Double = sunUp < 0 ? 1 : -1
    let camera = SIMD3<Double>(distance, 0, side * height)
    var ahead = cos(yaw) * SIMD3<Double>(-1, 0, 0) + sin(yaw) * SIMD3<Double>(0, 1, 0)
    ahead = simd_normalize(cos(pitch) * ahead + sin(pitch) * SIMD3(0, 0, -side))
    let right = simd_normalize(simd_cross(ahead, SIMD3(0, 0, side))), up = simd_cross(right, ahead)
    let sun = SIMD3<Float>(Float(cos(sunUp) * cos(sunRound)), Float(cos(sunUp) * sin(sunRound)), Float(sin(sunUp)))
    let lens = tan(field / 2)

    // The unlit face's colours, dark to light, from the ring pixels of Cassini's PIA09860 (research-look.md).
    let ramp = [0x140c0a, 0x503f31, 0x695442, 0x9a7d67, 0xf2cfa2].map {
        SIMD3<Float>(Float($0 >> 16 & 255), Float($0 >> 8 & 255), Float($0 & 255)) / 255
    }
    // The exposure that puts this view's brightest real thing at a 99.9th of about 177 of 255 (the mock-ups' sheet 4),
    // and the planet's own, which is held at the most that keeps its lit face buttercream (1.52).
    let exposure: Float = 1.478
    return shaderScene(size: size, source: shaderCommon + saturnsRingsSource(rings), uniforms: [
        SKUniform(name: "u_table", texture: table), SKUniform(name: "u_cam", vectorFloat3: SIMD3<Float>(camera)),
        SKUniform(name: "u_rot", matrixFloat3x3: matrix_float3x3(columns: (SIMD3<Float>(right), SIMD3<Float>(up), SIMD3<Float>(ahead)))),
        SKUniform(name: "u_sun", vectorFloat3: sun),
        SKUniform(name: "u_lens", vectorFloat2: [Float(lens), Float(lens * size.height / size.width)]),
        SKUniform(name: "u_exposure", float: exposure), SKUniform(name: "u_planetExposure", float: min(exposure, 1.52)),
    ] + ramp.enumerated().map { SKUniform(name: "u_c\($0.offset)", vectorFloat3: $0.element) })
}

/// Saturn's main rings every 8 km, from `Resources/saturn-rings.tsv` (docs/saturns-rings/profile.py made it; its
/// header has the sources): each radius's normal optical depth τ, from a Cassini UVIS occultation, and its particles'
/// brightness (ϖ₀P/4), from Voyager 2's lit-face picture.
// ponytail: 8 km a sample, 8,751 texels, near enough for view C, where a device pixel covers about 6 km of radius at
// the bottom edge and more everywhere else. The low, close views (E and F) draw 1-2 km a pixel near the bottom: a 4 km
// profile (16,384 texels, Metal's widest) if their near field looks soft.
struct RingProfile {
    /// The first radius and the step between samples, in Mm, the shader's unit.
    let start: Double, step: Double
    let tau: [Double], brightness: [Double]
    /// The pyramid holds exp(−τk) for k = 1, 2, 4 … 2048, each averaged over boxes 1, 2, 4 … 4096 texels wide.
    static let ks = 12, levels = 13

    static func load() -> RingProfile {
        let rows = ((try? String(contentsOf: resource("saturn-rings.tsv"), encoding: .utf8)) ?? "")
            .split(whereSeparator: \.isNewline).filter { !$0.hasPrefix("#") }
            .map { $0.split(separator: "\t").compactMap { Double($0) } }.filter { $0.count == 3 }
        guard rows.count > 1 else { return RingProfile(start: 72, step: 1, tau: [0, 0], brightness: [0, 0]) } // no rings
        return RingProfile(start: rows[0][0] / 1000, step: (rows[1][0] - rows[0][0]) / 1000, tau: rows.map { $0[1] }, brightness: rows.map { $0[2] })
    }

    /// The radial pyramid (research-method.md §4), a mip chain by radius: row (j, m) holds, for each texel, the mean
    /// of exp(−τ·2^j) over a box 2^m texels wide centred on it, as two bytes (red and green), and the mean brightness
    /// over the same box (blue, 255 for 0.5). The shader picks the row for each pixel's footprint and light path, so
    /// every pixel shows the exact average of the bands it covers, and none shimmer. Running sums read twice, which
    /// would need no pyramid, failed in SpriteKit for lack of precision.
    func pyramid() -> SKTexture {
        SKTexture(data: Data(pyramidBytes()), size: CGSize(width: tau.count, height: Self.ks * Self.levels))
    }

    /// The pyramid's texels, RGBA, row by row.
    func pyramidBytes() -> [UInt8] {
        let n = tau.count
        /// Running sums of `values`, from 0.
        func sums(_ values: [Double]) -> [Double] {
            var sums = [0.0]
            sums.reserveCapacity(values.count + 1)
            for value in values { sums.append(sums.last! + value) }
            return sums
        }
        /// The mean over `half` texels either side of texel `i`'s centre, from the running sums, `outside` past the ends.
        func mean(_ sums: [Double], _ i: Int, _ half: Double, outside: Double) -> Double {
            func at(_ x: Double) -> Double {
                if x <= 0 { return x * outside }
                if x >= Double(n) { return sums[n] + (x - Double(n)) * outside }
                let i0 = Int(x)
                return sums[i0] + (x - Double(i0)) * (sums[min(i0 + 1, n)] - sums[i0])
            }
            return (at(Double(i) + 0.5 + half) - at(Double(i) + 0.5 - half)) / (2 * half)
        }
        let brightnessSums = sums(brightness)
        let bright = (0..<Self.levels).map { m in
            (0..<n).map { UInt8(min(max(mean(brightnessSums, $0, Double(1 << m) / 2, outside: 0.2), 0), 0.5) / 0.5 * 255) }
        }
        var bytes = [UInt8](repeating: 255, count: n * Self.ks * Self.levels * 4)
        for j in 0..<Self.ks {
            let through = sums(tau.map { exp(-$0 * pow(2, Double(j))) })
            for m in 0..<Self.levels {
                let half = Double(1 << m) / 2
                for i in 0..<n {
                    let v = Int(min(max(mean(through, i, half, outside: 1), 0), 1) * 65535), at = ((j * Self.levels + m) * n + i) * 4
                    (bytes[at], bytes[at + 1], bytes[at + 2]) = (UInt8(v >> 8), UInt8(v & 255), bright[m][i])
                }
            }
        }
        return bytes
    }
}

/// The shader: the ring plane and the planet in one pass, the rings lit as a thin layer that scatters once
/// (research-method.md §3), each band filtered to the pixel's footprint by the pyramid, the planet's shadow on the
/// rings and theirs on it, ringshine on its night side, then exposure, a soft knee and dither. Ported from
/// docs/saturns-rings/mock.swift less its moons' ripples and spokes.
private func saturnsRingsSource(_ rings: RingProfile) -> String {
    let rows = Double(RingProfile.ks * RingProfile.levels)
    /// Declares `v`, the mean of exp(−τk) over the footprint `w` texels either side of `u`, from the two rows of k
    /// round `k`, and `vAlb`, the particles' brightness there.
    func mean(_ v: String, _ u: String, _ w: String, _ k: String) -> String {
        "vec4 \(v)At = pyrAt(\(u), \(w), \(k)); vec4 \(v)0 = texture2D(u_table, \(v)At.xy); vec4 \(v)1 = texture2D(u_table, \(v)At.xz); float \(v) = mix(pyrOf(\(v)0), pyrOf(\(v)1), \(v)At.w); float \(v)Alb = \(v)0.b * 0.5;"
    }
    return """
    // Faint sparse stars, display values: luma 30 at most (the look report's cap).
    // ponytail: random, and fixed to the screen, which holds only while the camera stands still; the real catalogue,
    // fixed to the sky, from Black Hole's, once the camera turns (step (d) of the build order).
    float stars(vec2 pts) {
        vec4 r = hash42(floor(pts / 7.0));
        if (r.x > 0.05) { return 0.0; }
        vec2 off = (r.yz - 0.5) * 0.6;
        float d = length(fract(pts / 7.0) - 0.5 - off) * 7.0;
        return smoothstep(0.9, 0.0, d) * (0.25 + 0.75 * pow(r.w, 4.0)) * 30.0 / 255.0;
    }
    // Where the pyramid keeps the mean of exp(-tau k) over a box 2w texels wide, in the two rows of k round k.
    vec4 pyrAt(float u, float w, float k) {
        float m = clamp(log2(2.0 * w), 0.0, 11.999), j = clamp(log2(max(k, 1.0)), 0.0, 10.999), j0 = floor(j);
        return vec4(u / \(Double(rings.tau.count)), (j0 * 13.0 + m + 0.5) / \(rows), ((j0 + 1.0) * 13.0 + m + 0.5) / \(rows), j - j0);
    }
    float pyrOf(vec4 t) { return t.r * (255.0 * 256.0 / 65535.0) + t.g * (255.0 / 65535.0); }
    vec3 rampAt(float t, vec3 c0, vec3 c1, vec3 c2, vec3 c3, vec3 c4) {
        float x = clamp(t, 0.0, 1.0) * 4.0;
        vec3 c = mix(c0, c1, clamp(x, 0.0, 1.0));
        c = mix(c, c2, clamp(x - 1.0, 0.0, 1.0));
        c = mix(c, c3, clamp(x - 2.0, 0.0, 1.0));
        return mix(c, c4, clamp(x - 3.0, 0.0, 1.0));
    }
    float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

    void main() {
        vec2 ndc = (v_tex_coord - 0.5) * 2.0;
        vec3 d = normalize(u_rot * vec3(ndc.x * u_lens.x, ndc.y * u_lens.y, 1.0));
        vec3 c = u_cam, s = u_sun;
        float req = 60.268, k = 60.268 / 54.364;

        // the ring plane
        float tr = -c.z / d.z;
        vec3 p = c + tr * d;
        float r = length(p.xy);
        float u = (r - \(rings.start)) / \(rings.step);
        float w = max(0.5 * length(vec2(dfdx(u), dfdy(u))), 0.5);

        // the planet: an oblate spheroid, a sphere once z is stretched by k
        vec3 cs = vec3(c.xy, c.z * k), ds = vec3(d.xy, d.z * k);
        float A = dot(ds, ds), B = dot(cs, ds), C = dot(cs, cs) - req * req;
        float disc = B * B - A * C;
        float tp = disc > 0.0 ? (-B - sqrt(disc)) / A : 1e9;

        vec3 lin = vec3(0.0);   // light, before exposure: planet and rings in I/F
        float sky = 1.0;        // how much of the sky shows
        if (tp < 1e8) {
            vec3 h = c + tp * d;
            vec3 n = normalize(vec3(h.xy, h.z * k * k));
            float lat = asin(clamp(n.z, -1.0, 1.0));
            float mu0p = max(dot(n, s), 0.0), mup = max(-dot(n, d), 0.02);
            // buttercream belts and zones, the south a paler gold (PIA06193, PIA11141, PIA11478)
            // ponytail: drawn by latitude, not mapped; a Cassini map of the globe if a view close to it shows them as too regular
            float band = 0.5 + 0.5 * sin(lat * 23.0 + 0.7 * sin(lat * 9.0)) * (0.6 + 0.4 * sin(lat * 5.0 + 1.0));
            vec3 col = mix(vec3(0.66, 0.59, 0.44), vec3(0.82, 0.73, 0.59), band);
            col = mix(col, vec3(0.88, 0.79, 0.51), 0.25 * smoothstep(0.1, -0.6, lat));
            col = pow(col, vec3(2.2)); // the photographs' display colours, in linear light
            // the rings' shadow: the light that reaches here came through the ring plane at radius rq
            float ts = -h.z / s.z;
            float rq = length((h + ts * s).xy);
            float uq = (rq - \(rings.start)) / \(rings.step);
            float wq = max(0.5 * length(vec2(dfdx(uq), dfdy(uq))), 0.5);
            \(mean("eq", "uq", "wq", "1.0 / abs(s.z)"))
            float through = ts > 0.0 ? eq : 1.0;
            float lit = 0.42 * pow(mu0p, 0.9) * pow(mup, -0.1) * through;
            // ringshine: the rings' lit face lights the hemisphere on its side, their unlit face the other, dimmer
            float side = n.z * sign(s.z);
            float shine = 0.42 * 0.012 * (smoothstep(-0.2, 0.7, side) + 0.35 * smoothstep(-0.2, 0.7, -side));
            lin = (col / luma(col) * lit + vec3(2.25, 0.714, 0.148) * shine) * u_planetExposure; // #372110 in linear light, luma 1
            sky = 0.0;
        }
        if (tr > 0.0 && tr < tp && r > 72.2 && r < 141.9) {
            float mu = max(abs(d.z), 1e-4), mu0 = max(abs(s.z), 2e-3);
            float kv = 1.0 / mu, ks = 1.0 / mu0;
            \(mean("eView", "u", "w", "kv"))
            float light = 0.0, t = 0.0;
            if (c.z * s.z > 0.0) {
                \(mean("eBoth", "u", "w", "kv + ks"))
                light = eViewAlb * (1.0 - eBoth) * mu0 / (mu + mu0);
                t = light / (0.28 * mu0 / (mu + mu0));
            } else {
                float k2 = abs(kv - ks) < 0.1 * ks ? ks * 1.1 : kv;
                \(mean("eSun", "u", "w", "ks"))
                \(mean("eK2", "u", "w", "k2"))
                light = eViewAlb * (eSun - eK2) / (mu * (k2 - ks));
                // the most an unlit slab can pass at this angle, at tau = ln(k2/ks) / (k2 - ks)
                float best = log(k2 / ks) / (k2 - ks);
                t = light / (0.28 * (exp(-best * ks) - exp(-best * k2)) / (mu * (k2 - ks)));
            }
            // the planet's shadow: does the way to the Sun meet the spheroid? Soft over the Sun's width.
            vec3 ps = vec3(p.xy, 0.0), ss = normalize(vec3(s.xy, s.z * k));
            float b = dot(ps, ss);
            float miss = sqrt(max(dot(ps, ps) - b * b, 0.0));
            float sunlit = b < 0.0 ? smoothstep(req - 0.02 + b * 0.0005, req + 0.02 - b * 0.0005, miss) : 1.0;
            // the rings take the palette's colour at their brightness against a saturated B ring's
            vec3 hueLin = pow(rampAt(t * 0.95, u_c0, u_c1, u_c2, u_c3, u_c4), vec3(2.2));
            lin = lin * eView + hueLin / max(luma(hueLin), 1e-4) * light * sunlit * u_exposure;
            sky *= eView;
        }

        // exposure and a knee that stays nearly straight to luma 185 (Cassini's contrast kept) and never passes 214
        lin = max(lin, 0.0);
        vec3 col = pow(lin / sqrt(sqrt(1.0 + pow(lin / 0.68, vec3(4.0)))), vec3(0.4545));
        // the sky: near-black (luma 4-8) and faint stars, both behind whatever the rings let through
        col += (6.0 / 255.0 + stars(v_tex_coord * u_size)) * sky;
        col += 3.0 / 255.0 * (1.0 - sky);
        col += (hash21(v_tex_coord * u_size * 2.0) - 0.5) / 255.0;
        gl_FragColor = vec4(col, 1.0);
    }
    """
}
