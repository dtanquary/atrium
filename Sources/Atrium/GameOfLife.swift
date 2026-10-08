import SpriteKit

@MainActor func gameOfLife(size: CGSize) -> SKScene { GameOfLife(size: size) }

/// Conway's Life on a wrap-around board, drawn as soft rounded cells whose colour drifts across the screen.
/// Dead cells fade out over a second or two. When the board settles into still lifes and blinkers, fresh soup is dropped in.
/// The Calm look runs slower and shows a long exposure of the board: each cell's average over a few seconds, so
/// blinkers and still lifes hold a steady glow and only real movement shows, melted into soft blobs.
final class GameOfLife: SKScene {
    nonisolated static let knobs = [
        Knob(key: "life.calm", label: "Calm", range: 0...1, standard: 1, section: "Look", format: .toggle),
        Knob(key: "life.speed", label: "Generations a second", range: 0.5...4, standard: 1.5, section: "Look", shownWhen: "life.calm"),
        Knob(key: "life.exposure", label: "Exposure (seconds)", range: 0...6, standard: 3, section: "Look", shownWhen: "life.calm"),
        Knob(key: "life.softness", label: "Softness", range: 0...1, standard: 1, section: "Look", shownWhen: "life.calm"),
    ]

    private let cellSize: CGFloat = 9
    private let classicInterval: TimeInterval = 0.14
    private var cols = 0, rows = 0
    private var cells: [UInt8] = [] // 1 alive, 0 dead
    private var next: [UInt8] = []
    private var pixels: [UInt8] = [] // RGBA; red is each cell's glow, which eases up while alive and fades after death
    private var exposed: [Float] = [] // Calm: each cell's average state over the last few seconds
    private let calm = SKUniform(name: "u_calm", float: 1), softness = SKUniform(name: "u_soft", float: 1)
    private var texture: SKMutableTexture!
    private var lastTime: TimeInterval?
    private var sinceStep: TimeInterval = 0
    private var quietSteps = 0
    /// Settings, read as they change rather than every frame.
    private var isCalm = true, interval: TimeInterval = 0.14, exposure = 3.0

    override func sceneDidLoad() {
        backgroundColor = SKColor(red: 0.035, green: 0.04, blue: 0.075, alpha: 1)
        cols = Int((size.width / cellSize).rounded(.up))
        rows = Int((size.height / cellSize).rounded(.up))
        cells = (0..<cols * rows).map { _ in Double.random(in: 0..<1) < 0.28 ? 1 : 0 }
        next = cells
        pixels = cells.flatMap { [$0 * 255, 0, 0, 255] }
        exposed = cells.map(Float.init)

        texture = SKMutableTexture(size: CGSize(width: cols, height: rows))
        texture.filteringMode = .linear // Classic samples cell centres, which come out exact; Calm blends between them
        let board = SKSpriteNode(texture: texture, size: CGSize(width: CGFloat(cols) * cellSize, height: CGFloat(rows) * cellSize))
        board.position = CGPoint(x: size.width / 2, y: size.height / 2)
        board.shader = SKShader(source: Self.cellShader, uniforms: [
            SKUniform(name: "u_grid", vectorFloat2: [Float(cols), Float(rows)]), WallpaperTime.now, calm, softness,
        ])
        addChild(board)
        settingsChanged()
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: UserDefaults.didChangeNotification, object: nil)
        upload()
    }

    @objc private func settingsChanged() {
        isCalm = Self.knobs[0].value > 0.5
        calm.floatValue = isCalm ? 1 : 0
        softness.floatValue = Float(Self.knobs[3].value)
        interval = isCalm ? 1 / Self.knobs[1].value : classicInterval
        exposure = Self.knobs[2].value
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = frameTime(currentTime, &lastTime)
        sinceStep += dt
        if sinceStep >= interval {
            sinceStep = min(sinceStep - interval, interval) // the rest carries over, so it keeps its rate at any frame rate
            step()
        }
        if isCalm { expose(dt) } else { upload(dt) }
    }

    /// One generation, wrapping at the edges. Counts changed cells to spot a board that has gone quiet.
    private func step() {
        let cols = cols, rows = rows
        var changes = 0
        cells.withUnsafeBufferPointer { cur in
            next.withUnsafeMutableBufferPointer { nxt in
                for y in 0..<rows {
                    let up = (y + rows - 1) % rows * cols, mid = y * cols, down = (y + 1) % rows * cols
                    for x in 0..<cols {
                        let l = x == 0 ? cols - 1 : x - 1, r = x == cols - 1 ? 0 : x + 1
                        let n = cur[up + l] &+ cur[up + x] &+ cur[up + r] &+ cur[mid + l] &+ cur[mid + r]
                            &+ cur[down + l] &+ cur[down + x] &+ cur[down + r]
                        let alive: UInt8 = n == 3 || (n == 2 && cur[mid + x] == 1) ? 1 : 0
                        if alive != cur[mid + x] { changes += 1 }
                        nxt[mid + x] = alive
                    }
                }
            }
        }
        swap(&cells, &next)

        // ponytail: "quiet" = under 0.3% of cells changing for 12 generations; blinkers alone never trip a period detector
        quietSteps = changes < cells.count * 3 / 1000 ? quietSteps + 1 : 0
        if quietSteps >= 12 {
            quietSteps = 0
            for _ in 0..<3 { seed() }
        }
    }

    /// Drops a patch of random soup somewhere on the board.
    private func seed() {
        let cx = Int.random(in: 0..<cols), cy = Int.random(in: 0..<rows), radius = 9
        for dy in -radius...radius {
            for dx in -radius...radius where dx * dx + dy * dy <= radius * radius {
                let x = (cx + dx + cols) % cols, y = (cy + dy + rows) % rows
                cells[y * cols + x] = Double.random(in: 0..<1) < 0.4 ? 1 : 0
            }
        }
    }

    /// Eases every cell's glow toward its state (births bloom in, deaths leave a trail) and sends it to the GPU.
    /// Glow goes in the red channel; the shader does shape and colour.
    private func upload(_ dt: TimeInterval = 1.0 / 30) {
        // 90/256 of the way up and 16/256 down every 30th of a second, so trails last as long at any frame rate
        let rise = Int(256 * (1 - pow(1 - 90.0 / 256, dt * 30))), fall = Int(256 * (1 - pow(1 - 16.0 / 256, dt * 30)))
        cells.withUnsafeBufferPointer { cells in
            pixels.withUnsafeMutableBufferPointer { pixels in
                for i in 0..<cells.count {
                    let g = Int(pixels[i * 4])
                    pixels[i * 4] = UInt8(cells[i] == 1 ? g + (255 - g) * rise / 256 : g > 20 ? g - max(g * fall / 256, 1) : 0)
                }
            }
        }
        send()
    }

    /// Calm: eases each cell's average toward its state over the exposure time, into red, and a 3×3 blur of that into
    /// green, which the shader melts into blobs.
    private func expose(_ dt: TimeInterval) {
        let exposure = exposure, cols = cols, rows = rows
        let k = Float(exposure > 0.01 ? 1 - exp(-dt / exposure) : 1)
        cells.withUnsafeBufferPointer { cells in
            exposed.withUnsafeMutableBufferPointer { seen in
                pixels.withUnsafeMutableBufferPointer { pixels in
                    for i in 0..<cells.count {
                        seen[i] += (Float(cells[i]) - seen[i]) * k
                        pixels[i * 4] = UInt8(seen[i] * 255)
                    }
                    for y in 0..<rows {
                        let up = (y + rows - 1) % rows * cols, mid = y * cols, down = (y + 1) % rows * cols
                        for x in 0..<cols {
                            let l = x == 0 ? cols - 1 : x - 1, r = x == cols - 1 ? 0 : x + 1
                            let sum = (seen[up + l] + seen[up + r] + seen[down + l] + seen[down + r]) * 0.5
                                + seen[up + x] + seen[down + x] + seen[mid + l] + seen[mid + r] + seen[mid + x] * 2
                            pixels[(mid + x) * 4 + 1] = UInt8(min(sum / 8 * 255, 255))
                        }
                    }
                }
            }
        }
        send()
    }

    private func send() {
        let bytes = pixels
        texture.modifyPixelData { data, length in
            bytes.withUnsafeBytes { data?.copyMemory(from: $0.baseAddress!, byteCount: min(length, $0.count)) }
        }
    }

    /// Classic samples each cell's glow at its centre and draws a rounded square with a soft halo, in a slowly
    /// drifting rainbow. Calm draws the exposure the same way, blended by `u_soft` into blobs of the blurred exposure
    /// (smoothly interpolated between cells, so no grid shows), dimmer and in one family of jewel tones.
    private static let cellShader = """
        void main() {
            vec2 g = v_tex_coord * u_grid;
            vec4 cell = texture2D(u_texture, (floor(g) + 0.5) / u_grid);

            vec2 f = abs(fract(g) - 0.5);
            float d = length(max(f - 0.2, 0.0)) - 0.16;
            float body = smoothstep(0.04, -0.04, d);
            float halo = smoothstep(0.5, -0.1, d) * 0.18;

            vec2 uv = v_tex_coord;
            vec3 bg = vec3(0.035, 0.04, 0.075) * (1.0 - 0.35 * length(uv - 0.5));
            vec3 c;
            if (u_calm < 0.5) {
                vec3 hue = 0.5 + 0.5 * cos(6.2831 * (vec3(0.0, 0.33, 0.67) + uv.x * 0.45 + uv.y * 0.25 + u_now * 0.01));
                vec3 pastel = mix(hue, vec3(1.0), 0.35);
                c = bg + pastel * pow(cell.r, 1.4) * (body * 0.95 + halo);
            } else {
                // cubic B-spline between cells, in four linear taps (GPU Gems 2, ch. 20), so no grid shows
                vec2 p = g - 0.5, i = floor(p), s = p - i;
                vec2 w0 = (1.0 - s) * (1.0 - s) * (1.0 - s) / 6.0, w3 = s * s * s / 6.0;
                vec2 w1 = (4.0 - 6.0 * s * s + 3.0 * s * s * s) / 6.0, w2 = 1.0 - w0 - w1 - w3;
                vec2 g0 = w0 + w1, g1 = w2 + w3;
                vec2 h0 = (i - 0.5 + w1 / g0) / u_grid, h1 = (i + 1.5 + w3 / g1) / u_grid;
                float v = g0.y * (g0.x * texture2D(u_texture, h0).g + g1.x * texture2D(u_texture, vec2(h1.x, h0.y)).g)
                        + g1.y * (g0.x * texture2D(u_texture, vec2(h0.x, h1.y)).g + g1.x * texture2D(u_texture, h1).g);
                float blob = smoothstep(0.16, 0.3, v) * (0.5 + 0.5 * smoothstep(0.3, 0.6, v)) + smoothstep(0.0, 0.3, v) * 0.12;
                float lit = mix(pow(cell.r, 1.4) * (body * 0.9 + halo), blob, u_soft);

                float t = u_now * 0.012;
                float a = 0.5 + 0.5 * sin(uv.x * 2.3 + uv.y * 1.6 + t);
                float b = 0.5 + 0.5 * sin(uv.y * 2.0 - uv.x * 1.4 + t * 0.8 + 2.0);
                vec3 jewel = mix(mix(vec3(0.12, 0.40, 0.90), vec3(0.06, 0.58, 0.62), a), vec3(0.46, 0.28, 0.86), b * 0.55);
                vec3 core = mix(jewel, vec3(0.75, 0.88, 1.0), 0.4 * smoothstep(0.4, 0.8, v));
                c = bg + core * lit * 0.72;
            }
            gl_FragColor = vec4(c, 1.0);
        }
        """
}
