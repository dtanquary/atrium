import PegLattice
import SpriteKit

@MainActor func pegBoard(size: CGSize) -> SKScene { PegBoard(size: size) }

/// A black sheet of holes, edge to edge, with coloured translucent pegs pushed through it one at a time and lit from
/// behind: a snow crystal grows from the middle in the order it freezes. One shader draws every peg: for each pixel
/// it works out the hole it is nearest by arithmetic, reads that hole's colour and its place in the order from two
/// small textures, and shades the peg's face from the distance to its middle. The glow on the paper is a third
/// texture, stamped on the CPU as pegs go in (`Glow`, in the PegLattice module with the lattice and the crystal).
/// docs/peg-board.md has the measurements of the real toy that the numbers here come from, and the sources.
final class PegBoard: SKScene {
    nonisolated static let speed = Knob(key: "pegboard.speed", label: "Speed", range: 0.5...8, standard: 1, section: "Pegs", format: .times)
    /// From the plastic peg as measured (its bright rim, its moulded lip, the lamp showing through as a hot dot)
    /// down to a plain glowing disc: one number, which the shader turns into all of those.
    nonisolated static let softness = Knob(key: "pegboard.softness", label: "Softness", range: 0...1, standard: 0, section: "Pegs")
    nonisolated static let knobs = [speed, softness]

    /// The eight peg colours (red, pink, orange, yellow, green, blue, violet, clear), sRGB. A hole's colour is its
    /// place here plus one; 0 is an empty hole.
    // ponytail: the calmer set only; the set measured from photographs of the real pegs joins it as a second palette
    static let colours: [SIMD3<Float>] = [[188, 65, 50], [192, 65, 87], [201, 105, 56], [185, 159, 65], [66, 179, 66], [44, 95, 179], [138, 72, 178], [240, 204, 158]]
    /// A crystal's colours from its heart to its tips, by when each part froze: one family at a time.
    private static let families: [[UInt8]] = [[8, 8, 6, 6, 7, 7, 2, 6, 8], [8, 8, 4, 4, 3, 3, 1, 3, 8], [8, 8, 5, 5, 6, 6, 7, 6, 8]]
    /// Reiter's three numbers for crystals that come out well on a board this coarse: feathery, plump, narrow.
    private static let crystals: [(alpha: Float, beta: Float, gamma: Float)] = [(1, 0.5, 0.0005), (1, 0.35, 0.0035), (2, 0.3, 0.001), (1.5, 0.4, 0.006)]

    /// Points from a hole to the next: half the real toy's quarter inch, on a laptop's display.
    // ponytail: one size; the toy's own and a third come with the pictures, which are cut for each
    private static let pitch = 16.0
    /// Pegs placed in a second at speed 1; the seconds one takes to light up, at any speed, so that a faster build
    /// is a wider soft front and not a sparkle; and the seconds, at speed 1, between two states of the glow (the
    /// shader shows the one turning into the other).
    private static let rate = 6.0, lighting = 1.0, tick = 0.25

    private var lattice: Lattice!
    private var glow: Glow!
    /// The holes in the order their pegs go in, and each one's colour (0 for none).
    private var sequence: [Int] = [], pegs: [UInt8] = []
    private var colourTexture: SKMutableTexture!, orderTexture: SKMutableTexture!, glowTextures: [SKMutableTexture] = []
    /// What the shader is told each frame: pegs placed so far, how many are lighting up at once, and how far the
    /// older glow has turned into the newer.
    private let state = SKUniform(name: "u_state", vectorFloat3: [0, Float(rate * lighting), 0])
    private let soft = SKUniform(name: "u_soft", float: 0)
    /// The scene's own seconds, which the Speed slider stretches; how many of the glow's ticks have been made; how
    /// many pegs the glow has; which texture holds its newer state, and which state of it each texture holds.
    private var clock = 0.0, ticks = 0, glowing = 0, newest = 0, holds = [0, 0], made = 0
    private var lastTime: TimeInterval?

    override func sceneDidLoad() {
        backgroundColor = .black
        lattice = Lattice(width: size.width, height: size.height, pitch: Self.pitch)
        glow = Glow(for: lattice)
        func texture(_ width: Int, _ height: Int, smooth: Bool) -> SKMutableTexture {
            let texture = SKMutableTexture(size: CGSize(width: width, height: height))
            texture.filteringMode = smooth ? .linear : .nearest
            return texture
        }
        colourTexture = texture(lattice.cols, lattice.rows, smooth: false)
        orderTexture = texture(lattice.cols, lattice.rows, smooth: false)
        glowTextures = (0..<2).map { _ in texture(glow.width, glow.height, smooth: true) }
        for texture in glowTextures { send(glow.bytes, to: texture) }
        grow()

        let sheet = SKSpriteNode(color: .black, size: size)
        sheet.anchorPoint = .zero
        sheet.shader = SKShader(source: Self.shader, uniforms: [
            SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)]),
            SKUniform(name: "u_lattice", vectorFloat3: [Float(lattice.pitch), Float(lattice.origin.x), Float(lattice.origin.y)]),
            SKUniform(name: "u_grid", vectorFloat2: [Float(lattice.cols), Float(lattice.rows)]),
            SKUniform(name: "u_pegs", texture: colourTexture), SKUniform(name: "u_order", texture: orderTexture),
            SKUniform(name: "u_glow0", texture: glowTextures[0]), SKUniform(name: "u_glow1", texture: glowTextures[1]), state, soft,
        ])
        addChild(sheet)
        settingsChanged()
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: UserDefaults.didChangeNotification, object: nil)
    }

    @objc private func settingsChanged() { soft.floatValue = Float(Self.softness.value) }

    /// A new snow crystal for the sheet: its pegs' colours and the order they go in, sent to the shader.
    private func grow() {
        // ("pegboard.seed" is for the tests, which want the same crystal twice; nothing else sets it.)
        let seed = UInt64(max(UserDefaults.standard.integer(forKey: "pegboard.seed"), 0))
        var rng = SplitMix(state: seed > 0 ? seed : .random(in: 1...UInt64.max))
        let kind = Self.crystals.randomElement(using: &rng)!, family = Self.families.randomElement(using: &rng)!
        let crystal = snowCrystal(on: lattice, alpha: kind.alpha, beta: kind.beta, gamma: kind.gamma, using: &rng)
        sequence = [Int](repeating: 0, count: crystal.count)
        pegs = [UInt8](repeating: 0, count: lattice.count)
        var colourBytes = [UInt8](repeating: 0, count: lattice.count * 4), orderBytes = [UInt8](repeating: 255, count: lattice.count * 4)
        for hole in 0..<lattice.count where crystal.order[hole] >= 0 {
            let place = Int(crystal.order[hole])
            sequence[place] = hole
            pegs[hole] = family[min(Int(crystal.age[hole] * Float(family.count)), family.count - 1)]
            // The colour goes as the square root of its light, so that 8 bits keep the dark end; the place in
            // three bytes, since a big display at small pegs has more than 65,535 holes.
            let light = Self.light(of: pegs[hole])
            for c in 0..<3 {
                colourBytes[hole * 4 + c] = UInt8((light[c].squareRoot() * 255).rounded())
                orderBytes[hole * 4 + c] = UInt8(place >> (8 * (2 - c)) & 255)
            }
            colourBytes[hole * 4 + 3] = 255
        }
        send(colourBytes, to: colourTexture)
        send(orderBytes, to: orderTexture)
    }

    /// A peg colour as linear light, from its number.
    private static func light(of colour: UInt8) -> SIMD3<Float> {
        let c = colours[Int(colour) - 1] / 255
        return SIMD3((0..<3).map { c[$0] <= 0.04045 ? c[$0] / 12.92 : pow((c[$0] + 0.055) / 1.055, 2.4) })
    }

    /// How much less of the lamp reaches a peg toward the sheet's corners, as one bulb behind the middle gives.
    private func lamp(at hole: Int) -> Float {
        let display = SIMD2(Double(size.width), Double(size.height)), from = lattice.point(hole % lattice.cols, hole / lattice.cols) - display / 2
        return Float(1 / (1 + 0.35 * simd_length_squared(from) / (simd_length_squared(display) / 4) / 0.2025))
    }

    private func send(_ bytes: [UInt8], to texture: SKMutableTexture) {
        bytes.withUnsafeBytes { buffer in
            nonisolated(unsafe) let bytes = buffer
            texture.modifyPixelData { data, length in data?.copyMemory(from: bytes.baseAddress!, byteCount: min(length, bytes.count)) }
        }
    }

    /// Everything goes by the scene's own clock, in 960ths of a second so that the frame rate's own way of adding
    /// time up can't show: the pegs placed, which the shader lights by their place in the order; and the glow,
    /// which is stamped a tick at a time so that it too is the same at any frame rate.
    override func update(_ currentTime: TimeInterval) {
        let speed = Self.speed.value, front = Self.rate * Self.lighting * speed // pegs lighting up at once
        clock += frameTime(currentTime, &lastTime) * speed
        let now = (clock * 960).rounded() / 960
        while Double(ticks + 1) * Self.tick <= now {
            ticks += 1
            tick(placed: Double(ticks) * Self.tick * Self.rate - front / 2)
        }
        let toward = Float(((now / Self.tick - Double(ticks)) * 256).rounded(.down) / 256)
        state.vectorFloat3Value = [Float(min(now * Self.rate, Double(sequence.count) + front)), Float(front), newest == 1 ? toward : 1 - toward]
    }

    /// One tick of the glow: the pegs that have come half-way to full since the last (the first `placed` of them,
    /// which may be a fraction) are stamped into it, and it goes to the texture holding its older state, which
    /// becomes the newer. A peg's glow so comes up over a tick, while the peg is about half lit. Once both textures
    /// hold every peg, nothing more is sent.
    private func tick(placed: Double) {
        let due = min(Int(max(placed, -1) + 1), sequence.count)
        if glowing < due {
            for hole in sequence[glowing..<due] { glow.stamp(col: hole % lattice.cols, row: hole / lattice.cols, colour: Self.light(of: pegs[hole]) * lamp(at: hole)) }
            (glowing, made) = (due, made + 1)
        }
        newest = 1 - newest
        guard holds[newest] != made else { return }
        send(glow.bytes, to: glowTextures[newest])
        holds[newest] = made
    }

    /// The whole board in one pass. A pixel belongs to the nearer of two holes, the nearest in the row below it and
    /// in the row above; that hole's peg, if it has one and its turn has come, is a disc shaded by the distance to
    /// its (slightly crooked) middle, coming in over the first quarter of the time it takes to light. Round it is black paper with a faint dot at every empty hole, lit by the glow.
    /// `u_soft` is the Softness slider: it takes the rim, the lip and the hot dot away, brings the glow up and
    /// widens the peg's outline. Light is linear until the last two lines.
    private static let shader = """
        vec4 hash42(vec2 p) {
            vec4 p4 = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
            p4 += dot(p4, p4.wzxy + 33.33);
            return fract((p4.xxyz + p4.yzzw) * p4.zywx);
        }
        float bump(float x, float s) { return exp(-(x / s) * (x / s)); }
        void main() {
            float S = 0.8660254, R = 0.47;                    // a row's height and a peg's radius, in pitches
            vec2 p = v_tex_coord * u_size;
            float px = u_lattice.x / fwidth(p.x);             // device pixels to a pitch
            vec2 uv = vec2(p.x - u_lattice.y, (p.y - u_lattice.z) / S) / u_lattice.x;

            float ja = floor(uv.y), jb = ja + 1.0;
            float offa = 0.5 * (ja - 2.0 * floor(ja * 0.5)), offb = 0.5 - offa;
            float ia = floor(uv.x - offa + 0.5), ib = floor(uv.x - offb + 0.5);
            vec2 oa = vec2(uv.x - ia - offa, (uv.y - ja) * S), ob = vec2(uv.x - ib - offb, (uv.y - jb) * S);
            float upper = step(dot(ob, ob), dot(oa, oa));
            vec2 cell = mix(vec2(ia, ja), vec2(ib, jb), upper);
            vec4 h = hash42(cell);
            vec2 o = mix(oa, ob, upper) - (h.xy - 0.5) * 0.11;
            float d = length(o), r = d / R;

            vec4 peg = texture2D(u_pegs, (cell + 0.5) / u_grid);
            float place = floor(dot(texture2D(u_order, (cell + 0.5) / u_grid).rgb, vec3(16711680.0, 65280.0, 255.0)) + 0.5);
            float turn = (u_state.x - place) / u_state.y;
            float has = step(0.5, peg.a) * smoothstep(0.0, 0.25, turn);   // it comes in with its light: an unlit peg is a black blot on the glow
            float lit = smoothstep(0.0, 1.0, turn);

            float rim = 1.0 - 0.7 * u_soft, bulb = 0.35 * (1.0 - u_soft);
            vec2 gc = (uv * 4.0 + 2.5) / (4.0 * u_grid);
            vec3 g0 = texture2D(u_glow0, gc).rgb, g1 = texture2D(u_glow1, gc).rgb;
            vec3 glow = mix(g0 * g0, g1 * g1, u_state.z) * 0.0625 * (1.0 + 3.0 * u_soft);

            vec2 mid = p - 0.5 * u_size;
            float lamp = 1.0 / (1.0 + 0.35 * dot(mid, mid) / (0.25 * dot(u_size, u_size)) / 0.2025);
            float fine = 0.8 / (R * px);                      // nothing is drawn thinner than a pixel
            float body = (0.40 + 0.12 * (1.0 - r * r)) * (1.0 - 0.45 * rim * bump(r - 0.80, max(0.07, fine)))
                       + rim * (0.75 * bump(r - 0.93, max(0.04, fine)) + 0.10 * bump(r - 0.66, max(0.025, fine)));
            body *= 1.0 - (1.0 - rim) * 0.6 * r * r * r;
            float q = length(o - (h.zw - 0.5) * 0.55 * R) / R;
            float core = exp((fract(h.x * 7.31 + h.z * 3.17) - 0.5) * 2.6) * bulb * (3.0 * bump(q, max(0.16, fine)) + 0.35 * bump(q, 0.47));
            vec3 colour = peg.rgb * peg.rgb;
            vec3 warm = (0.5 * max(colour.r, max(colour.g, colour.b)) + (colour.r + colour.g + colour.b) / 6.0) * vec3(1.0, 0.67, 0.35);
            vec3 face = (colour * body + (0.35 * colour + 0.65 * warm) * core) * (lit * lamp * exp((h.y - 0.5) * 0.5)) + 0.6 * glow;
            float cover = clamp((1.0 - r) * R * px / mix(1.2, 3.0, u_soft) + 0.5, 0.0, 1.0) * has;

            float hole = clamp((0.21 - d) / 0.05, 0.0, 1.0) * (1.0 - has);
            float grain = 0.9 + 0.2 * hash42(floor(p * px / u_lattice.x)).x;
            vec3 paper = grain * (0.0015 + glow) * (1.0 + 2.2 * hole);

            vec3 c = mix(paper, face, cover) * (1.8 - 0.2 * u_soft);
            c = 1.0 - exp(-(c + 0.25 * max(max(c.r, max(c.g, c.b)) - 1.5, 0.0)));   // hot cores bleach toward white
            gl_FragColor = vec4(mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)), 1.0);
        }
        """
}
