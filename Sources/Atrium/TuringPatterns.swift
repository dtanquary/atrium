import SpriteKit

@MainActor func turingPatterns(size: CGSize) -> SKScene { TuringPatterns(size: size) }

/// Gray–Scott reaction–diffusion: two chemicals spreading at different rates, one feeding on the other, which is how
/// Turing (1952) proposed spots and stripes form in living things. It runs on the CPU at one cell per 5 points and
/// wraps at the edges. Drift wanders its feed and kill rates round the patterns in order, so it never settles:
/// coral branches, cells dividing into spots, spots swelling into a honeycomb of holes, then fingerprint stripes.
final class TuringPatterns: SKScene {
    /// Feed and kill rates for each pattern, from Pearson, "Complex Patterns in a Simple System" (Science, 1993) and
    /// Karl Sims' reaction–diffusion tutorial. Only the slow, settling kinds: the moving waves and spirals are too busy.
    /// In Drift order: each leg between neighbours stays inside the pattern-forming region, so nothing dies out.
    nonisolated static let patterns: [(name: String, f: Float, k: Float)] = [
        ("Coral", 0.0545, 0.062), ("Spots", 0.0367, 0.0649), ("Holes", 0.039, 0.058), ("Fingerprint", 0.029, 0.057),
    ]
    nonisolated static let knobs = [
        Knob(key: "turing.pattern", label: "Pattern", range: 0...Double(patterns.count), standard: 0,
             format: .choice(["Drift"] + patterns.map(\.name))),
        Knob(key: "turing.speed", label: "Speed", range: 0.25...3, standard: 1, format: .times),
    ]
    /// Jewel tones: two colours the pattern drifts between across the screen, and a highlight. The background is a
    /// deep shade of the first in Dark Mode, and paper tinted by it in Light Mode.
    nonisolated static let palettes: [(name: String, ink: SIMD3<Float>, ink2: SIMD3<Float>, glow: SIMD3<Float>)] = [
        ("Lagoon", [0.05, 0.50, 0.58], [0.10, 0.30, 0.75], [0.60, 0.95, 1.00]),
        ("Sapphire", [0.12, 0.28, 0.85], [0.36, 0.20, 0.80], [0.62, 0.78, 1.00]),
        ("Amethyst", [0.42, 0.20, 0.78], [0.66, 0.18, 0.55], [0.90, 0.72, 1.00]),
        ("Jade", [0.06, 0.52, 0.36], [0.04, 0.42, 0.52], [0.70, 1.00, 0.80]),
        ("Garnet", [0.70, 0.14, 0.28], [0.46, 0.14, 0.52], [1.00, 0.70, 0.62]),
        ("Amber", [0.78, 0.44, 0.10], [0.72, 0.22, 0.24], [1.00, 0.88, 0.60]),
    ]
    /// Steps each leg of Drift takes: 4 minutes at normal speed.
    private static let leg = 14_400.0

    private let cell: CGFloat = 5
    private let stepsPerSecond = 60.0
    private var cols = 0, rows = 0, stride = 0 // the grid has a one-cell border that mirrors the far edge, so it wraps
    private var a: [Float] = [], b: [Float] = [], nextA: [Float] = [], nextB: [Float] = []
    private var pixels: [UInt8] = [] // RGBA; red and green hold b as 16 bits, so the shader's smooth reads don't band
    private var texture: SKMutableTexture!
    private var lastTime: TimeInterval?
    private var owed = 0.0
    private var drift = Double.random(in: 0..<Double(patterns.count)) * leg // steps along Drift's loop; a new start each load

    override func sceneDidLoad() {
        backgroundColor = .black
        cols = Int((size.width / cell).rounded(.up))
        rows = Int((size.height / cell).rounded(.up))
        stride = cols + 2
        a = Array(repeating: 1, count: stride * (rows + 2))
        b = Array(repeating: 0, count: a.count)
        for _ in 0..<cols * rows / 800 { seed() }
        nextA = a
        nextB = b
        pixels = Array(repeating: 255, count: cols * rows * 4)

        texture = SKMutableTexture(size: CGSize(width: cols, height: rows))
        texture.filteringMode = .linear
        let board = SKSpriteNode(texture: texture, size: CGSize(width: CGFloat(cols) * cell, height: CGFloat(rows) * cell))
        board.position = CGPoint(x: size.width / 2, y: size.height / 2)
        let chosen = UserDefaults.standard.string(forKey: "turing.palette") ?? ""
        let palette = Self.palettes.first { $0.name == chosen } ?? Self.palettes.randomElement()!
        let (ink, ink2, glow) = systemIsDark ? (palette.ink, palette.ink2, palette.glow) : (palette.ink * 0.9, palette.ink2 * 0.9, simd_mix(palette.ink, .one, SIMD3(repeating: 0.5)))
        let paper = systemIsDark ? palette.ink * 0.1 : simd_mix(SIMD3(0.93, 0.92, 0.89), palette.ink, SIMD3(repeating: 0.06))
        board.shader = SKShader(source: Self.shader, uniforms: [
            SKUniform(name: "u_grid", vectorFloat2: [Float(cols), Float(rows)]), SKUniform(name: "u_paper", vectorFloat3: paper),
            SKUniform(name: "u_ink", vectorFloat3: ink), SKUniform(name: "u_ink2", vectorFloat3: ink2),
            SKUniform(name: "u_glow", vectorFloat3: glow), SKUniform(name: "u_dark", float: systemIsDark ? 1 : 0), WallpaperTime.now,
        ])
        addChild(board)
        upload()
    }

    /// A disc of the second chemical, from which a pattern grows. Smaller than 9 cells across, most die out. A little
    /// noise breaks its symmetry; much more shows as mottling in the lighting while it's young.
    private func seed() {
        let cx = Int.random(in: 1...cols), cy = Int.random(in: 1...rows)
        for y in cy - 5...cy + 5 where (1...rows).contains(y) {
            for x in cx - 5...cx + 5 where (1...cols).contains(x) && (x - cx) * (x - cx) + (y - cy) * (y - cy) <= 25 {
                a[y * stride + x] = 0.5
                b[y * stride + x] = Float.random(in: 0.24...0.26)
            }
        }
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = frameTime(currentTime, &lastTime)
        owed = min(owed + dt * stepsPerSecond * Self.knobs[1].value, 12)
        let steps = Int(owed)
        guard steps > 0 else { return }
        owed -= Double(steps)
        let pick = Int(Self.knobs[0].value)
        for _ in 0..<steps {
            let (f, k) = pick > 0 ? (Self.patterns[pick - 1].f, Self.patterns[pick - 1].k) : drifting()
            step(f: f, k: k)
        }
        upload()
    }

    /// Feed and kill rates along Drift's loop, easing from each pattern to the next.
    private func drifting() -> (Float, Float) {
        drift = (drift + 1).truncatingRemainder(dividingBy: Self.leg * Double(Self.patterns.count))
        let i = Int(drift / Self.leg), t = Float(drift / Self.leg) - Float(i), e = t * t * (3 - 2 * t)
        let from = Self.patterns[i], to = Self.patterns[(i + 1) % Self.patterns.count]
        return (from.f + (to.f - from.f) * e, from.k + (to.k - from.k) * e)
    }

    /// One step of Gray–Scott with Sims' constants: diffusion 1 and 0.5, a 3×3 Laplacian, a time step of 1.
    // ponytail: scalar Swift on the main thread, about 0.45 ms a step; if more speed or finer cells are wanted, the
    // branch-free rows vectorise, or it moves to a Metal compute pass
    private func step(f: Float, k: Float) {
        wrap(&a)
        wrap(&b)
        let cols = cols, rows = rows, s = stride
        a.withUnsafeBufferPointer { a in
            b.withUnsafeBufferPointer { b in
                nextA.withUnsafeMutableBufferPointer { na in
                    nextB.withUnsafeMutableBufferPointer { nb in
                        for y in 1...rows {
                            for i in y * s + 1...y * s + cols {
                                let la = (a[i - 1] + a[i + 1] + a[i - s] + a[i + s]) * 0.2
                                    + (a[i - s - 1] + a[i - s + 1] + a[i + s - 1] + a[i + s + 1]) * 0.05 - a[i]
                                let lb = (b[i - 1] + b[i + 1] + b[i - s] + b[i + s]) * 0.2
                                    + (b[i - s - 1] + b[i - s + 1] + b[i + s - 1] + b[i + s + 1]) * 0.05 - b[i]
                                let r = a[i] * b[i] * b[i]
                                na[i] = a[i] + la - r + f * (1 - a[i])
                                nb[i] = b[i] + 0.5 * lb + r - (k + f) * b[i]
                            }
                        }
                    }
                }
            }
        }
        swap(&a, &nextA)
        swap(&b, &nextB)
    }

    /// Copies each edge into the border beyond the opposite edge.
    private func wrap(_ g: inout [Float]) {
        let s = stride, cols = cols, rows = rows
        for y in 1...rows {
            g[y * s] = g[y * s + cols]
            g[y * s + cols + 1] = g[y * s + 1]
        }
        for x in 0..<s {
            g[x] = g[rows * s + x]
            g[(rows + 1) * s + x] = g[s + x]
        }
    }

    /// Sends b to the texture, and reseeds if the pattern has died out, which no pattern here should do.
    private func upload() {
        let cols = cols, rows = rows, s = stride
        var peak: Float = 0
        b.withUnsafeBufferPointer { b in
            pixels.withUnsafeMutableBufferPointer { px in
                for y in 0..<rows {
                    for x in 0..<cols {
                        let value = b[(y + 1) * s + x + 1], v = Int(min(max(value * 2, 0), 1) * 65535), o = (y * cols + x) * 4
                        peak = max(peak, value)
                        px[o] = UInt8(v >> 8)
                        px[o + 1] = UInt8(v & 255)
                    }
                }
            }
        }
        if peak < 0.05 { for _ in 0..<cols * rows / 800 { seed() } }
        let bytes = pixels
        texture.modifyPixelData { data, length in
            bytes.withUnsafeBytes { data?.copyMemory(from: $0.baseAddress!, byteCount: min(length, $0.count)) }
        }
    }

    private static let shader = """
        void main() {
            // cubic B-spline between cells, in four linear taps (GPU Gems 2, ch. 20), so no grid shows
            vec2 p = v_tex_coord * u_grid - 0.5, i = floor(p), s = p - i;
            vec2 w0 = (1.0 - s) * (1.0 - s) * (1.0 - s) / 6.0, w3 = s * s * s / 6.0;
            vec2 w1 = (4.0 - 6.0 * s * s + 3.0 * s * s * s) / 6.0, w2 = 1.0 - w0 - w1 - w3;
            vec2 g0 = w0 + w1, g1 = w2 + w3;
            vec2 h0 = (i - 0.5 + w1 / g0) / u_grid, h1 = (i + 1.5 + w3 / g1) / u_grid;
            vec4 t00 = texture2D(u_texture, h0), t10 = texture2D(u_texture, vec2(h1.x, h0.y));
            vec4 t01 = texture2D(u_texture, vec2(h0.x, h1.y)), t11 = texture2D(u_texture, h1);
            vec4 t = g0.y * (g0.x * t00 + g1.x * t10) + g1.y * (g0.x * t01 + g1.x * t11);
            float v = (t.r * 65280.0 + t.g * 255.0) / 65535.0;

            // the pattern as a softly lit relief, like brain coral: v is its height, lit from the upper left
            float body = smoothstep(0.25, 0.45, v);
            vec3 n = normalize(vec3(-dfdx(v) * 28.0, -dfdy(v) * 28.0, 1.0));
            vec3 l = normalize(vec3(-0.45, 0.55, 0.7));
            float diffuse = clamp(0.55 + 0.6 * dot(n, l), 0.0, 1.3);
            float sheen = pow(max(dot(reflect(-l, n), vec3(0.0, 0.0, 1.0)), 0.0), 16.0);
            float ridge = smoothstep(0.45, 0.8, v);
            vec2 uv = v_tex_coord;
            vec3 ink = mix(u_ink, u_ink2, 0.5 + 0.5 * sin(uv.x * 2.2 - uv.y * 1.5 + u_now * 0.01));
            vec3 surface = mix(ink * 0.55, mix(ink, u_glow, 0.35), ridge) * diffuse;
            vec3 c = mix(u_paper, surface, body) + u_glow * sheen * body * 0.18 + ink * smoothstep(0.02, 0.35, v) * 0.08 * u_dark;
            float vignette = 1.0 - 0.3 * length(uv - 0.5);
            gl_FragColor = vec4(u_dark > 0.5 ? c * vignette : c, 1.0);
        }
        """
}
