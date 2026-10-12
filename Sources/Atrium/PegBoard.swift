import PegLattice
import SpriteKit

@MainActor func pegBoard(size: CGSize) -> SKScene { PegBoard(size: size) }

/// A black sheet of holes, edge to edge, with coloured translucent pegs pushed through it one at a time and lit from
/// behind. It shows one thing after another: a snow crystal grown from the middle in the order it freezes, or a
/// picture cut down to pegs and built outline first; each, once whole, under a slow light show; then the sheet
/// goes dark and is cleared for the next.
/// One shader draws every peg: for each pixel it works out the hole it is nearest by arithmetic, reads that hole's
/// colour and its place in the order from two small textures, and shades the peg's face from the distance to its
/// middle. The glow on the paper is a third texture, stamped on the CPU as pegs go in (`Glow`, in the PegLattice
/// module with the lattice, the crystal and the charts). docs/peg-board.md has the measurements of the real toy
/// that the numbers here come from, and the pictures' sources.
final class PegBoard: SKScene {
    nonisolated static let shows = Knob(key: "pegboard.shows", label: "Shows", range: 0...2, standard: 0, section: "Sheet",
                                        format: .choice(["Everything", "Patterns only", "Pictures only"]))
    nonisolated static let speed = Knob(key: "pegboard.speed", label: "Speed", range: 0.5...20, standard: 1, section: "Sheet", format: .times)
    /// Three sizes of peg, since every picture is cut for each: the real toy's own, half of it, and a third.
    nonisolated static let pegSize = Knob(key: "pegboard.size", label: "Peg size", range: 0...2, standard: 1, section: "Pegs",
                                          format: .choice(["Large", "Medium", "Small"]))
    /// From the plastic peg as measured (its bright rim, its moulded lip, the lamp showing through as a hot dot)
    /// down to a plain glowing disc: one number, which the shader turns into all of those.
    nonisolated static let softness = Knob(key: "pegboard.softness", label: "Softness", range: 0...1, standard: 0, section: "Pegs")
    nonisolated static let knobs = [shows, speed, pegSize, softness]

    /// The eight peg colours (red, pink, orange, yellow, green, blue, violet, clear) in two sets, sRGB: Vivid as
    /// measured from photographs of the real pegs, and Calm, the same with less colour, more even in lightness and
    /// a warmer clear peg. A hole's colour is its place in a set plus one; 0 is an empty hole.
    nonisolated static let sets: [(name: String, colours: [SIMD3<Float>])] = [
        ("Calm", [[188, 65, 50], [192, 65, 87], [201, 105, 56], [185, 159, 65], [66, 179, 66], [44, 95, 179], [138, 72, 178], [240, 204, 158]]),
        ("Vivid", [[200, 25, 10], [205, 25, 75], [220, 95, 10], [205, 170, 20], [0, 195, 25], [5, 80, 190], [140, 45, 190], [235, 215, 180]]),
    ]
    /// The sets as swatches (red, yellow, green, blue and clear). Random takes one of them for each new sheet.
    nonisolated static let palette = PaletteChoice(key: "pegboard.palette", options: sets.map { set in
        let swatch = [0, 3, 4, 5, 7].map { set.colours[$0] / 255 }
        return (set.name, swatch, swatch)
    }, standard: "Calm")
    /// A crystal's colours from its heart to its tips, by when each part froze: one family at a time.
    private static let families: [[UInt8]] = [[8, 8, 6, 6, 7, 7, 2, 6, 8], [8, 8, 4, 4, 3, 3, 1, 3, 8], [8, 8, 5, 5, 6, 6, 7, 6, 8]]
    /// Reiter's three numbers for crystals that come out well on a board this coarse: feathery, plump, narrow.
    private static let crystals: [(alpha: Float, beta: Float, gamma: Float)] = [(1, 0.5, 0.0005), (1, 0.35, 0.0035), (2, 0.3, 0.001), (1.5, 0.4, 0.006)]
    /// The pictures, each at up to three sizes (Resources/peg-board-charts.txt, credited in peg-board-credits.tsv).
    static let charts = PegLattice.charts(from: (try? String(contentsOf: resource("peg-board-charts.txt"), encoding: .utf8)) ?? "")
    /// The light shows: how the light varies over the sheet (in lobes round its middle; and in radians to the
    /// display's height, with the distance from the middle and across the sheet) and the seconds the pattern takes
    /// to come round. A lobe going round, rings leaving the middle, a band crossing.
    private static let lightShows: [(turn: Float, out: Float, across: Float, period: Double)] = [(1, 0, 0, 40), (0, 12.8, 0, 20), (0, 0, 7.7, 24)]

    /// Points from a hole to the next at each peg size: the real toy's quarter inch on a laptop's display, a half
    /// and a third of it.
    private static let pitches = [32.0, 16.0, 32.0 / 3]
    /// Pegs placed in a second at speed 1, and the seconds one takes to light up, at any speed, so that a faster
    /// build is a wider soft front and not a sparkle.
    private static let rate = 6.0, lighting = 1.0
    /// The scene moves in steps of a 960th of a second, however many a frame holds, so that it is the same at any
    /// frame rate. In steps: between two states of the glow (the shader shows the one turning into the other); a
    /// light show; the sheet going dark, and staying dark before the next thing begins.
    private static let second = 960, tickSteps = 240, showSteps = 60 * 960, fadeSteps = 3 * 960, clearSteps = 4 * 960
    /// How far a light show takes a peg down from full, and the seconds it takes to come in and to go.
    private static let depth = 0.4, eases = 3.0

    private(set) var lattice: Lattice!
    private var glow: Glow!
    /// The peg size it was built for; the holes in the order their pegs go in, each one's colour (0 for none), and
    /// the eight colours' light on this sheet.
    private(set) var built = -1, sequence: [Int] = [], pegs: [UInt8] = [], lights: [SIMD3<Float>] = []
    private var colourTexture: SKMutableTexture!, orderTexture: SKMutableTexture!, glowTextures: [SKMutableTexture] = []
    /// What the shader is told each frame: pegs placed so far, how many are lighting up at once, how far the older
    /// glow has turned into the newer, and how bright the whole sheet is; the light show's shape and where it has
    /// got to, and how deep it goes.
    private let state = SKUniform(name: "u_state", vectorFloat4: [0, Float(rate * lighting), 0, 1])
    private let wave = SKUniform(name: "u_wave", vectorFloat4: .zero), deep = SKUniform(name: "u_depth", float: 0)
    private let soft = SKUniform(name: "u_soft", float: 0)

    private enum Phase { case building, showing, clearing }
    /// What it is doing; the pegs begun, which the Speed slider hurries, and how many are lighting at once; steps
    /// into the show or the clear; the time not yet stepped, in seconds; and steps since the glow's last tick.
    private var phase = Phase.building, placed = 0.0, front = rate * lighting, since = 0, owed = 0.0, ticking = 0
    /// How many pegs the glow has; which texture holds its newer state, and which state of it each texture holds.
    private var glowing = 0, newest = 0, holds = [0, 0], made = 0
    /// Whether a picture is on the sheet (or a crystal), the pictures not yet shown this round, and the light show.
    private(set) var picture = false, unseen: [String] = [], show = lightShows[0]
    private var rng = SplitMix(state: 0)
    private var lastTime: TimeInterval?

    override func sceneDidLoad() {
        backgroundColor = .black
        // ("pegboard.seed" is for the tests, which want the same sheets twice; nothing else sets it.)
        let seed = UInt64(max(UserDefaults.standard.integer(forKey: "pegboard.seed"), 0))
        rng = SplitMix(state: seed > 0 ? seed : .random(in: 1...UInt64.max))
        // The first thing is the other kind from this: either, where both are shown. ("pegboard.picture" is for the
        // tests and for stills: the picture to put up first.)
        picture = UserDefaults.standard.string(forKey: "pegboard.picture") == nil && Bool.random(using: &rng)
        build()
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: UserDefaults.didChangeNotification, object: nil)
    }

    /// The sheet at the peg size Settings asks for: its holes, its textures and the sprite that draws them, and
    /// the first thing on it.
    private func build() {
        removeAllChildren()
        built = Int(Self.pegSize.value)
        lattice = Lattice(width: size.width, height: size.height, pitch: Self.pitches[built])
        glow = Glow(for: lattice)
        func texture(_ width: Int, _ height: Int, smooth: Bool) -> SKMutableTexture {
            let texture = SKMutableTexture(size: CGSize(width: width, height: height))
            texture.filteringMode = smooth ? .linear : .nearest
            return texture
        }
        colourTexture = texture(lattice.cols, lattice.rows, smooth: false)
        orderTexture = texture(lattice.cols, lattice.rows, smooth: false)
        glowTextures = (0..<2).map { _ in texture(glow.width, glow.height, smooth: true) }
        let sheet = SKSpriteNode(color: .black, size: size)
        sheet.anchorPoint = .zero
        sheet.shader = SKShader(source: Self.shader, uniforms: [
            SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)]),
            SKUniform(name: "u_lattice", vectorFloat3: [Float(lattice.pitch), Float(lattice.origin.x), Float(lattice.origin.y)]),
            SKUniform(name: "u_grid", vectorFloat2: [Float(lattice.cols), Float(lattice.rows)]),
            SKUniform(name: "u_pegs", texture: colourTexture), SKUniform(name: "u_order", texture: orderTexture),
            SKUniform(name: "u_glow0", texture: glowTextures[0]), SKUniform(name: "u_glow1", texture: glowTextures[1]), state, wave, deep, soft,
        ])
        addChild(sheet)
        soft.floatValue = Float(Self.softness.value)
        begin()
        tell()
    }

    /// When Settings changes: the softness at once; another peg size is another sheet; and where Shows no longer
    /// allows what is on the sheet, the sheet clears now for something it does.
    @objc private func settingsChanged() {
        soft.floatValue = Float(Self.softness.value)
        if Int(Self.pegSize.value) != built { build() } else if picture != wantsPicture(after: !picture), phase != .clearing { (phase, since) = (.clearing, 0) }
    }

    /// Each picture at the largest size that fits on this sheet's holes, if any does.
    private var fitting: [Chart] {
        Dictionary(grouping: Self.charts.filter { $0.cols <= lattice.cols - 2 && $0.rows <= lattice.rows - 2 }, by: \.name)
            .values.compactMap { $0.max { $0.pegs.count < $1.pegs.count } }.sorted { $0.name < $1.name }
    }

    /// Whether the next thing is a picture, after one that was or wasn't: Shows' pick, or turn about where it is
    /// everything; and never where no picture fits.
    private func wantsPicture(after last: Bool) -> Bool {
        let shows = Int(Self.shows.value)
        return (shows == 2 || (shows == 0 && !last)) && !fitting.isEmpty
    }

    /// The next thing on an empty sheet: a picture's pegs in outline-first order or a new snow crystal's in the
    /// order it froze, in the colours Settings names, all sent to the shader, and the light show it will have.
    private func begin() {
        picture = wantsPicture(after: picture)
        pegs = [UInt8](repeating: 0, count: lattice.count)
        if picture, let chart = chart() {
            // in the middle, on an even row, so that the chart's offset rows are the sheet's
            let (col0, row0) = ((lattice.cols - chart.cols) / 2, (lattice.rows - chart.rows) / 2 & ~1)
            for row in 0..<chart.rows { for col in 0..<chart.cols { pegs[(row0 + row) * lattice.cols + col0 + col] = chart.pegs[row * chart.cols + col] } }
            sequence = outlineFirst(pegs: pegs, cols: lattice.cols, rows: lattice.rows)
        } else {
            let kind = Self.crystals.randomElement(using: &rng)!, family = Self.families.randomElement(using: &rng)!
            let crystal = snowCrystal(on: lattice, alpha: kind.alpha, beta: kind.beta, gamma: kind.gamma, using: &rng)
            sequence = [Int](repeating: 0, count: crystal.count)
            for hole in 0..<lattice.count where crystal.order[hole] >= 0 {
                sequence[Int(crystal.order[hole])] = hole
                pegs[hole] = family[min(Int(crystal.age[hole] * Float(family.count)), family.count - 1)]
            }
        }
        let named = UserDefaults.standard.string(forKey: Self.palette.key) ?? Self.palette.standard
        let set = Self.sets.first { $0.name == named } ?? Self.sets.randomElement(using: &rng)! // no name is Random
        lights = set.colours.map { colour in SIMD3((0..<3).map { c in
            let v = colour[c] / 255
            return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }) }
        show = Self.lightShows.randomElement(using: &rng)!

        var colourBytes = [UInt8](repeating: 0, count: lattice.count * 4), orderBytes = [UInt8](repeating: 255, count: lattice.count * 4)
        for (place, hole) in sequence.enumerated() {
            // The colour goes as the square root of its light, so that 8 bits keep the dark end; the place in
            // three bytes, since a big display at small pegs has more than 65,535 holes.
            let light = lights[Int(pegs[hole]) - 1]
            for c in 0..<3 {
                colourBytes[hole * 4 + c] = UInt8((light[c].squareRoot() * 255).rounded())
                orderBytes[hole * 4 + c] = UInt8(place >> (8 * (2 - c)) & 255)
            }
            colourBytes[hole * 4 + 3] = 255
        }
        send(colourBytes, to: colourTexture)
        send(orderBytes, to: orderTexture)
        glow.clear()
        for texture in glowTextures { send(glow.bytes, to: texture) }
        (phase, placed, since, glowing, made, holds) = (.building, 0, 0, 0, made + 1, [made + 1, made + 1])
    }

    /// The next picture: each in turn, in a new order every round.
    private func chart() -> Chart? {
        let fitting = fitting
        if let asked = UserDefaults.standard.string(forKey: "pegboard.picture"), made == 0, let chart = fitting.first(where: { $0.name == asked }) { return chart }
        if unseen.isEmpty { unseen = fitting.map(\.name).shuffled(using: &rng) }
        guard let name = unseen.popLast() else { return nil }
        return fitting.first { $0.name == name }
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

    override func update(_ currentTime: TimeInterval) {
        owed += frameTime(currentTime, &lastTime)
        let steps = Int((owed * Double(Self.second)).rounded()), speed = Self.speed.value
        owed -= Double(steps) / Double(Self.second)
        for _ in 0..<steps { step(speed) }
        tell()
    }

    /// One 960th of a second. Pegs are begun at the Speed slider's pace until all are lit; then the light show, and
    /// the clear, take the time they take at any speed; and then the next thing begins. Every quarter second, a
    /// tick of the glow.
    private func step(_ speed: Double) {
        switch phase {
        case .building:
            front = Self.rate * Self.lighting * speed
            placed += Self.rate * speed / Double(Self.second)
            if placed >= Double(sequence.count) + front { (phase, since) = (.showing, 0) }
        case .showing:
            since += 1
            if since >= Self.showSteps { (phase, since) = (.clearing, 0) }
        case .clearing:
            since += 1
            if since >= Self.clearSteps { begin() }
        }
        ticking += 1
        if ticking == Self.tickSteps {
            ticking = 0
            tick()
        }
    }

    /// One tick of the glow: the pegs that have come half-way to full since the last are stamped into it, and it
    /// goes to the texture holding its older state, which becomes the newer. A peg's glow so comes up over a tick,
    /// while the peg is about half lit. Once both textures hold every peg, nothing more is sent.
    private func tick() {
        let due = min(max(Int((placed - front / 2).rounded(.down)) + 1, 0), sequence.count)
        if glowing < due {
            for hole in sequence[glowing..<due] { glow.stamp(col: hole % lattice.cols, row: hole / lattice.cols, colour: lights[Int(pegs[hole]) - 1] * lamp(at: hole)) }
            (glowing, made) = (due, made + 1)
        }
        newest = 1 - newest
        guard holds[newest] != made else { return }
        send(glow.bytes, to: glowTextures[newest])
        holds[newest] = made
    }

    /// Tells the shader where things have got to.
    private func tell() {
        func ease(_ x: Double) -> Double { let t = min(max(x, 0), 1); return t * t * (3 - 2 * t) }
        let seconds = Double(since) / Double(Self.second), toward = Float(ticking) / Float(Self.tickSteps)
        var (level, depth, turned) = (1.0, 0.0, 0.0)
        switch phase {
        case .building: break
        case .showing:
            depth = Self.depth * ease(seconds / Self.eases) * ease((Double(Self.showSteps / Self.second) - seconds) / Self.eases)
            turned = (seconds / show.period).truncatingRemainder(dividingBy: 1)
        case .clearing: level = 1 - ease(seconds / Double(Self.fadeSteps / Self.second))
        }
        state.vectorFloat4Value = [Float(min(placed, Double(sequence.count) + front)), Float(front), newest == 1 ? toward : 1 - toward, Float(level)]
        wave.vectorFloat4Value = [show.turn, show.out, show.across, Float(turned * 2 * .pi)]
        deep.floatValue = Float(depth)
    }

    /// The whole board in one pass. A pixel belongs to the nearer of two holes, the nearest in the row below it and
    /// in the row above; that hole's peg, if it has one and its turn has come, is a disc shaded by the distance to
    /// its (slightly crooked) middle, coming in over the first quarter of the time it takes to light. Round it is
    /// black paper with a faint dot at every empty hole, lit by the glow. `u_soft` is the Softness slider: it takes
    /// the rim, the lip and the hot dot away, brings the glow up and widens the peg's outline. `mode` is the light
    /// show, which dims pegs and glow together by where they are on the sheet. Light is linear until the last two lines.
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
            vec2 mid = p - 0.5 * u_size, m = mid / u_size.y;
            float mode = u_state.w * (1.0 - u_depth * (1.0 - cos(u_wave.x * atan(m.y, m.x) + u_wave.y * length(m) + u_wave.z * (m.x + 0.5 * m.y) - u_wave.w)));
            float lit = smoothstep(0.0, 1.0, turn) * mode;

            float rim = 1.0 - 0.7 * u_soft, bulb = 0.35 * (1.0 - u_soft);
            vec2 gc = (uv * 4.0 + 2.5) / (4.0 * u_grid);
            vec3 g0 = texture2D(u_glow0, gc).rgb, g1 = texture2D(u_glow1, gc).rgb;
            vec3 glow = mix(g0 * g0, g1 * g1, u_state.z) * 0.0625 * (1.0 + 3.0 * u_soft) * mode;

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
