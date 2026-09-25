import SpriteKit

@MainActor func gameOfLife(size: CGSize) -> SKScene { GameOfLife(size: size) }

/// Conway's Life on a wrap-around board, drawn as soft rounded cells whose colour drifts across the screen.
/// Dead cells fade out over a second or two. When the board settles into still lifes and blinkers, fresh soup is dropped in.
final class GameOfLife: SKScene {
    private let cellSize: CGFloat = 9
    private let stepInterval: TimeInterval = 0.14
    private var cols = 0, rows = 0
    private var cells: [UInt8] = [] // 1 alive, 0 dead
    private var next: [UInt8] = []
    private var pixels: [UInt8] = [] // RGBA; red is each cell's glow, which eases up while alive and fades after death
    private var texture: SKMutableTexture!
    private var lastTime: TimeInterval?
    private var sinceStep: TimeInterval = 0
    private var quietSteps = 0

    override func sceneDidLoad() {
        backgroundColor = SKColor(red: 0.035, green: 0.04, blue: 0.075, alpha: 1)
        cols = Int((size.width / cellSize).rounded(.up))
        rows = Int((size.height / cellSize).rounded(.up))
        cells = (0..<cols * rows).map { _ in Double.random(in: 0..<1) < 0.28 ? 1 : 0 }
        next = cells
        pixels = cells.flatMap { [$0 * 255, 0, 0, 255] }

        texture = SKMutableTexture(size: CGSize(width: cols, height: rows))
        texture.filteringMode = .nearest
        let board = SKSpriteNode(texture: texture, size: CGSize(width: CGFloat(cols) * cellSize, height: CGFloat(rows) * cellSize))
        board.position = CGPoint(x: size.width / 2, y: size.height / 2)
        board.shader = SKShader(source: Self.cellShader, uniforms: [
            SKUniform(name: "u_grid", vectorFloat2: [Float(cols), Float(rows)]),
        ])
        addChild(board)
        upload()
    }

    override func update(_ currentTime: TimeInterval) {
        sinceStep += frameTime(currentTime, &lastTime)
        if sinceStep >= stepInterval {
            sinceStep = 0
            step()
        }
        upload()
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
    private func upload() {
        cells.withUnsafeBufferPointer { cells in
            pixels.withUnsafeMutableBufferPointer { pixels in
                for i in 0..<cells.count {
                    let g = Int(pixels[i * 4])
                    pixels[i * 4] = UInt8(cells[i] == 1 ? g + (255 - g) * 90 / 256 : g > 20 ? g - g * 16 / 256 : 0)
                }
            }
        }
        let bytes = pixels
        texture.modifyPixelData { data, length in
            bytes.withUnsafeBytes { data?.copyMemory(from: $0.baseAddress!, byteCount: min(length, $0.count)) }
        }
    }

    /// Samples each cell's glow at its centre and draws a rounded square with a soft halo, in a slowly drifting palette.
    private static let cellShader = """
        void main() {
            vec2 g = v_tex_coord * u_grid;
            float glow = texture2D(u_texture, (floor(g) + 0.5) / u_grid).r;

            vec2 f = abs(fract(g) - 0.5);
            float d = length(max(f - 0.2, 0.0)) - 0.16;
            float body = smoothstep(0.04, -0.04, d);
            float halo = smoothstep(0.5, -0.1, d) * 0.18;

            vec2 uv = v_tex_coord;
            vec3 hue = 0.5 + 0.5 * cos(6.2831 * (vec3(0.0, 0.33, 0.67) + uv.x * 0.45 + uv.y * 0.25 + u_time * 0.01));
            vec3 pastel = mix(hue, vec3(1.0), 0.35);

            vec3 bg = vec3(0.035, 0.04, 0.075) * (1.0 - 0.35 * length(uv - 0.5));
            float lit = pow(glow, 1.4);
            vec3 c = bg + pastel * lit * (body * 0.95 + halo);
            gl_FragColor = vec4(c, 1.0);
        }
        """
}
