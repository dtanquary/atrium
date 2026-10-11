import SpriteKit

@MainActor func blackHole(size: CGSize) -> SKScene { BlackHole(size: size) }

/// How light bends round a black hole that doesn't spin, as two small tables that depend on nothing but the hole
/// itself, so one pair serves every view. A ray stays in one plane and its shape depends on one number, `e`, one over
/// how far off centre it was aimed: (du/dφ)² = e² − u²(1 − u), with u one over the distance. The method is Eric
/// Bruneton's ("Real-time High-Quality Rendering of Non-Rotating Black Holes", 2020, arxiv.org/abs/2010.08735), cut
/// down for a camera that stays far out; docs/black-hole.md has it step by step.
///
/// Lengths are in Schwarzschild radii: the horizon is at 1, light circles at 1.5, the innermost stable orbit (the
/// disc's inner edge) is at 3, and a ray aimed nearer than √27/2 is swallowed.
enum Bending {
    /// A ray is swallowed when e² is more than this.
    static let swallowed = 4.0 / 27
    /// Table A is this many columns of `e` by rows of angle; table B this many values of `e`.
    static let raysSize = (across: 256, up: 128), turnsSize = 1024
    /// Table B holds the turn less a quarter circle (what a straight line would make), over this.
    static let turnsScale = 8.0

    /// A little more than a ray from infinity turns through before it's nearest the hole or inside the innermost
    /// orbit, whichever comes first: table A's rows run from no turn to this. (Bruneton's bound, as is table A's
    /// column for `e`, 1/(1 + 6e²): github.com/ebruneton/black_hole_shader, functions.glsl, BSD 3-Clause.)
    static func furthestTurn(_ e2: Double) -> Double { (1 + e2) / (1.0 / 3 + 2 * e2 * e2.squareRoot()) }

    /// One over the distance along a ray from infinity after it has turned through each of `turns` (rising), by
    /// Runge-Kutta on u″ = 1.5u² − u. Stops counting at 2, long since swallowed.
    static func ray(_ e: Double, at turns: [Double]) -> [Double] {
        var (u, slope, turned) = (0.0, e, 0.0)
        func bend(_ u: Double) -> Double { 1.5 * u * u - u }
        return turns.map { turn in
            guard u < 2 else { return 2 }
            let steps = max(1, Int(((turn - turned) / 0.002).rounded(.up))), h = (turn - turned) / Double(steps)
            for _ in 0..<steps where u < 2 {
                let (a1, b1) = (slope, bend(u))
                let (a2, b2) = (slope + 0.5 * h * b1, bend(u + 0.5 * h * a1))
                let (a3, b3) = (slope + 0.5 * h * b2, bend(u + 0.5 * h * a2))
                let (a4, b4) = (slope + h * b3, bend(u + h * a3))
                u += h / 6 * (a1 + 2 * a2 + 2 * a3 + a4)
                slope += h / 6 * (b1 + 2 * b2 + 2 * b3 + b4)
            }
            turned = turn
            return min(u, 2)
        }
    }

    /// The turn a ray that escapes has made, from infinity, by the time it's nearest the hole. That nearest point,
    /// uA, is the smallest positive root of e² = u²(1 − u) (Bruneton's eq. 9); writing u = uA(1 − s²) takes the
    /// square-root blow-up there out of ∫ du/√(e² − u² + u³), which is then summed at 2,000 midpoints.
    static func turnToNearest(_ e2: Double) -> Double {
        let nearest = 1.0 / 3 + 2.0 / 3 * sin(asin(min(max(2 * e2 / swallowed - 1, -1), 1)) / 3), n = 2000
        return (0..<n).reduce(0.0) { sum, i in
            let s = (Double(i) + 0.5) / Double(n), u = nearest * (1 - s * s)
            return sum + 2 * nearest.squareRoot() / (-(u * u + (nearest - 1) * u + nearest * (nearest - 1))).squareRoot()
        } / Double(n)
    }

    /// Where table B keeps a ray's `e`, 0 to 1: stretched so the turn's logarithmic blow-up at the shadow's edge
    /// (column 0) becomes a gentle curve (Bruneton's stretch, over half its range).
    static func turnsColumn(_ e2: Double) -> Double { 1 - 2 * (max(-log(max(1 - e2 / swallowed, 1e-30)), 0) / 50).squareRoot() }

    /// Table A, one over the distance (capped at ½, over ½) for each `e` across and angle up, rows from no turn.
    static let rays: [Double] = {
        let (w, h) = raysSize
        var table = [Double](repeating: 0, count: w * h)
        for i in 0..<w {
            let x = Double(i) / Double(w - 1), rows = (0..<h).map { Double($0) / Double(h - 1) }
            // A ray aimed dead at the hole (x = 0, e infinite) comes to u = e sin φ, half its row in these
            // coordinates; one infinitely far off (x = 1) never comes near.
            let column = x == 0 ? rows.map { $0 / 2 } : x == 1 ? rows.map { _ in 0 }
                : ray(((1 / x - 1) / 6).squareRoot(), at: rows.map { $0 * furthestTurn((1 / x - 1) / 6) })
            for j in 0..<h { table[j * w + i] = min(column[j], 0.5) * 2 }
        }
        return table
    }()

    /// Table B, the turn to the nearest point for each `e` (see `turnsColumn`), less a quarter circle, over `turnsScale`.
    static let turns: [Double] = (0..<turnsSize).map { i in
        let x = Double(i) / Double(turnsSize - 1)
        guard x < 1 else { return 0 }
        let fromEdge = (1 - x) / 2
        return min(max((turnToNearest(swallowed * (1 - exp(-50 * fromEdge * fromEdge))) - .pi / 2) / turnsScale, 0), 1)
    }

    /// A table as RGBA bytes for a texture, each value 0...1 spread over `bytes` channels so the GPU's own smoothing
    /// between entries still gives the right answer: the first holds the value rounded to a byte, each next one
    /// what that rounding left over, centred on a half. The shader adds them back: hi + (lo − ½)/255, and so on.
    static func packed(_ table: [Double], bytes: Int) -> [UInt8] {
        var out = [UInt8](repeating: 255, count: table.count * 4)
        for (i, value) in table.enumerated() {
            var rest = value * 255
            for c in 0..<bytes {
                let byte = rest.rounded()
                out[i * 4 + c] = UInt8(min(max(byte, 0), 255))
                rest = (rest - byte + 0.5) * 255
            }
        }
        return out
    }
}

/// The colour of a glowing body by its temperature, as a screen shows it: Planck's spectrum through the eye's three
/// responses (the CIE 1931 curves in Wyman, Sloan & Shirley's analytic fit, jcgt.org/published/0002/02/01) to sRGB,
/// its strongest channel at full. Below about 1,900 K the true colour is redder than a screen can show and is
/// clipped to its nearest.
enum BlackBody {
    /// Where the colour sits on the CIE chart (x, y).
    static func chromaticity(_ kelvin: Double) -> SIMD2<Double> {
        let c = seen(kelvin)
        return [c.x, c.y] / (c.x + c.y + c.z)
    }

    /// CIE X, Y, Z of the glow, to any scale.
    private static func seen(_ kelvin: Double) -> SIMD3<Double> {
        func lobe(_ nm: Double, _ peak: Double, _ below: Double, _ above: Double) -> Double {
            let t = (nm - peak) / (nm < peak ? below : above)
            return exp(-0.5 * t * t)
        }
        return stride(from: 380.0, through: 780, by: 5).reduce(SIMD3<Double>.zero) { sum, nm in
            let glow = 1 / (pow(nm / 500, 5) * (exp(1.4388e7 / (nm * kelvin)) - 1)) // Planck, wavelength in nm
            return sum + glow * SIMD3(1.056 * lobe(nm, 599.8, 37.9, 31.0) + 0.362 * lobe(nm, 442.0, 16.0, 26.7) - 0.065 * lobe(nm, 501.1, 20.4, 26.2),
                                      0.821 * lobe(nm, 568.8, 46.9, 40.5) + 0.286 * lobe(nm, 530.9, 16.3, 31.1),
                                      1.217 * lobe(nm, 437.0, 11.8, 36.0) + 0.681 * lobe(nm, 459.0, 26.0, 13.8))
        }
    }

    /// The colour as sRGB values, the strongest 1.
    static func colour(_ kelvin: Double) -> SIMD3<Double> {
        let c = seen(kelvin)
        var rgb = SIMD3(3.2406 * c.x - 1.5372 * c.y - 0.4986 * c.z, -0.9689 * c.x + 1.8758 * c.y + 0.0415 * c.z,
                        0.0557 * c.x - 0.2040 * c.y + 1.0570 * c.z)
        rgb = pointwiseMax(rgb, .zero) / rgb.max()
        func encoded(_ c: Double) -> Double { c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1 / 2.4) - 0.055 }
        return [encoded(rgb.x), encoded(rgb.y), encoded(rgb.z)]
    }

    /// The shader's table of them: 256 colours from `coldest` to `hottest`, evenly spaced in the temperature's log.
    static let coldest = 500.0, hottest = 40000.0
    static let table: [UInt8] = (0..<256).flatMap { i in
        let c = colour(coldest * pow(hottest / coldest, Double(i) / 255))
        return [c.x, c.y, c.z, 1].map { UInt8(($0 * 255).rounded()) }
    }
}

/// A black hole with a thin disc of glowing gas turning round it, all of it bent by the hole's gravity: the far side
/// of the disc lifts into a hump over the shadow, its underside shows as a ring below, and the side turning toward
/// us is the brighter. Seen nearly edge on, the one view. The gas is hottest a little out from the disc's inner
/// edge and cools outward, and its colour is that of a glowing body at each temperature; the three disc colours
/// are three temperatures. Streaks in it are knots of gas drawn out by the disc's own shear: the inside laps the
/// outside, so each knot winds into an arc, and new ones are born as the old thin away.
final class BlackHole: SKScene {
    /// The view: how far out the camera is, how far it's tilted from the disc's axis (90° is edge on), where the
    /// disc ends, and the field of view across the screen. Dave picked the one view; the size slider is the field.
    struct View {
        var distance = 40.0, tilt = 84.0, outer = 11.0, field = 56.0
    }

    nonisolated static let size = Knob(key: "blackhole.size", label: "Size", range: 0.65...1.5, standard: 1, section: "Look", format: .times)
    nonisolated static let speed = Knob(key: "blackhole.speed", label: "Speed", range: 0...4, standard: 1, section: "Motion", format: .times)
    /// Brightness is the exposure before the stretch, as Galaxy's is. Beaming is how much of the Doppler shift
    /// shows: at 1 the side coming toward us is as much hotter and brighter as relativity makes it.
    nonisolated static let knobs = [
        size,
        Knob(key: "blackhole.brightness", label: "Brightness", range: 0.4...1.8, standard: 1, section: "Look"),
        Knob(key: "blackhole.beaming", label: "Beaming", range: 0...1, standard: 1, section: "Look"),
        Knob(key: "blackhole.streaks", label: "Streaks", range: 0...1, standard: 0.7, section: "Look"),
        speed,
        Knob(key: "blackhole.stars", label: "Stars", range: 0...2, standard: 1, section: "Sky"),
        Knob(key: "blackhole.milkyway", label: "Milky Way", range: 0...2, standard: 1, section: "Sky"),
    ]

    /// The disc's colours, each the temperature of its hottest ring in kelvin, and the exposure that suits it.
    nonisolated static let heats: [(name: String, kelvin: Double, exposure: Double)] = [
        ("Orange", 3300, 1), ("White-gold", 6200, 2), ("Blue-white", 15000, 1.6),
    ]
    /// Their swatches: the gas's colour out in the disc, at its hottest ring, and on the side coming toward us.
    static let palette = PaletteChoice(key: "blackhole.heat", options: heats.map { heat in
        let swatches = [0.6, 1, 1.25].map { SIMD3<Float>(BlackBody.colour(heat.kelvin * $0)) }
        return (heat.name, swatches, swatches)
    }, standard: "Orange", title: "Disc")

    /// Disc time is in the hole's own unit, the time light takes to cross its radius. The inner edge goes round in
    /// 2π√54 of them, and at speed 1 in three minutes (Dave's pick). For scale, the same orbit round the Milky Way's
    /// own black hole takes 33 minutes.
    private static let unitsPerSecond = 2 * Double.pi * 54.0.squareRoot() / 180
    /// How long a generation of streaks lasts, in that unit (3 minutes 54 at speed 1). Three overlap, a third of a
    /// life apart. The shader's weights have the same 60 written in.
    private static let life = 60.0

    private static let rays = table(Bending.packed(Bending.rays, bytes: 2), Bending.raysSize.across, Bending.raysSize.up)
    private static let turns = table(Bending.packed(Bending.turns, bytes: 3), Bending.turnsSize, 1)
    private static let heat = table(BlackBody.table, 256, 1)

    private static func table(_ bytes: [UInt8], _ across: Int, _ up: Int) -> SKTexture {
        let texture = SKTexture(data: Data(bytes), size: CGSize(width: across, height: up))
        texture.filteringMode = .linear
        return texture
    }

    /// The gas's knots as they are born, before any shear: four octaves of noise, one in each channel from coarse
    /// to fine, 512 across for one turn of the disc and 256 up for 0.4π in the log of the distance. The coarsest
    /// has 10 cells round and 6 up, each next octave twice that, so a knot starts three times as long round the
    /// disc as it is deep: with isotropic ones the streaks came out as soft blobs. It repeats both ways, with one
    /// more row and column that are the first again, so smoothing never meets a seam.
    private static let gas: SKTexture = {
        let (w, h) = (512, 256)
        func hash(_ x: Int, _ y: Int, _ octave: Int) -> Double {
            var n = UInt32(truncatingIfNeeded: x &* 374761393 &+ y &* 668265263 &+ octave &* 2246822519)
            n = (n ^ (n >> 13)) &* 1274126177
            return Double(n ^ (n >> 16)) / Double(UInt32.max)
        }
        var bytes = [UInt8](repeating: 0, count: (w + 1) * (h + 1) * 4)
        for y in 0...h { for x in 0...w { for octave in 0..<4 {
            let (round, deep) = (10 << octave, 6 << octave)
            let (u, v) = (Double(x % w) / Double(w) * Double(round), Double(y % h) / Double(h) * Double(deep))
            let (i, j) = (Int(u), Int(v))
            let (s, t) = ((u - Double(i)) * (u - Double(i)) * (3 - 2 * (u - Double(i))), (v - Double(j)) * (v - Double(j)) * (3 - 2 * (v - Double(j))))
            let value = (hash(i, j, octave) * (1 - s) + hash((i + 1) % round, j, octave) * s) * (1 - t)
                + (hash(i, (j + 1) % deep, octave) * (1 - s) + hash((i + 1) % round, (j + 1) % deep, octave) * s) * t
            bytes[(y * (w + 1) + x) * 4 + octave] = UInt8(value * 255)
        } } }
        return table(bytes, w + 1, h + 1)
    }()

    /// The sky's frame, for the stars and the Milky Way alike: longitude across and latitude up, with 0, 0 straight
    /// through the hole from the camera. docs/black-hole/sky.py bakes both files already turned to it.
    static let skyCells = (across: 2048, up: 1024)

    /// The real stars (the HYG catalogue to magnitude 11, Resources/blackhole-stars.lzfse) as a grid the shader can
    /// find a star in: one cell every 0.18° of the sky, holding at most one star, the brightest that falls in it.
    // ponytail: 4,589 of the 115,562 stars (4%) share a cell with a brighter one and are dropped, mostly faint ones
    // in the Milky Way's crowds. A grid twice as fine would keep nearly all, for four times the 8 MB.
    /// A cell's bytes are where in it the star sits (across, up), how bright it is (0 for no star, then 255 for
    /// magnitude −1.5 down to 1 for 11) and where the black-body table keeps its colour.
    static let starCells: [UInt8] = {
        let (w, h) = skyCells
        var cells = [UInt8](repeating: 0, count: w * h * 4)
        let packed = try? Data(contentsOf: resource("blackhole-stars.lzfse")) as NSData
        let bytes = ((try? packed?.decompressed(using: .lzfse)) as Data?).map { [UInt8]($0) } ?? [], count = bytes.count / 6
        func place(_ run: Int, _ i: Int, _ size: Int) -> Double {
            min(Double(Int(bytes[run * 2 * count + 2 * i]) | Int(bytes[run * 2 * count + 2 * i + 1]) << 8) / 65535 * Double(size), Double(size) - 0.001)
        }
        for i in 0..<count {
            let (x, y) = (place(0, i, w), place(1, i, h)), at = (Int(y) * w + Int(x)) * 4
            let bright = UInt8(max(255 - Int(bytes[4 * count + i]), 1))
            guard bright > cells[at + 2] else { continue }
            // its colour: B−V (the byte is −0.4...2) to kelvin by Ballesteros's formula (2012), to the table's place for it
            let bv = Double(bytes[5 * count + i]) / 255 * 2.4 - 0.4, kelvin = 4600 * (1 / (0.92 * bv + 1.7) + 1 / (0.92 * bv + 0.62))
            let hue = log(kelvin / BlackBody.coldest) / log(BlackBody.hottest / BlackBody.coldest) * 255
            cells[at..<at + 4] = [UInt8((x - x.rounded(.down)) * 256), UInt8((y - y.rounded(.down)) * 256), bright, UInt8(min(max(hue, 0), 255))]
        }
        return cells
    }()

    private static let catalogue = table(starCells, skyCells.across, skyCells.up)

    /// The Milky Way with its own stars taken out (ESO/S. Brunier's panorama, Resources/blackhole-glow.heic), stored
    /// lighter than it is. It has smaller copies of itself for where the hole squeezes the whole sky into a few pixels.
    private static let glow: SKTexture = {
        let texture = SKTexture(image: NSImage(contentsOf: resource("blackhole-glow.heic")) ?? NSImage())
        texture.usesMipmaps = true
        return texture
    }()

    private let knobUniforms: [String: SKUniform]
    private let lens = SKUniform(name: "u_lens", float: 0.5)
    private let age = SKUniform(name: "u_age", vectorFloat3: .zero)
    private let seedRound = SKUniform(name: "u_seedRound", vectorFloat3: .zero), seedDeep = SKUniform(name: "u_seedDeep", vectorFloat3: .zero)
    private let field: Double?
    /// Where the disc's clock stands, and where in the endless run of streak generations this scene began.
    private var discTime = Double.random(in: 0..<life)
    private let firstGeneration = Int.random(in: 0..<10000)
    private var lastUpdate: TimeInterval?

    /// `checks` draws the prototype's test pattern in place of the picture, for the test that compares the two:
    /// checks on the disc in distance and angle, and 5° squares on the sky (docs/black-hole/proto/render.py). With
    /// a `view` the picture holds to it; without, it's Dave's view at the size Settings gives.
    init(size: CGSize, view: View? = nil, checks: Bool = false) {
        // Size and Speed are worked out here, not in the shader (and "u_size" is the scene's own).
        knobUniforms = Dictionary(uniqueKeysWithValues: Self.knobs.filter { $0.key != Self.size.key && $0.key != Self.speed.key }.map {
            ($0.key, SKUniform(name: "u_" + $0.key.split(separator: ".").last!, float: Float($0.standard)))
        })
        field = view?.field
        super.init(size: size)
        let view = view ?? View(), tilt = Float(view.tilt * .pi / 180)
        let picked = UserDefaults.standard.string(forKey: Self.palette.key) ?? Self.palette.standard
        let heat = Self.heats.first { $0.name == picked } ?? Self.heats.randomElement()!

        let sprite = SKSpriteNode(color: .black, size: size)
        sprite.anchorPoint = .zero
        sprite.shader = SKShader(source: shaderCommon + Self.source, uniforms: [
            SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)]),
            SKUniform(name: "u_rays", texture: Self.rays), SKUniform(name: "u_turns", texture: Self.turns),
            SKUniform(name: "u_heat", texture: Self.heat), SKUniform(name: "u_gas", texture: Self.gas),
            SKUniform(name: "u_catalogue", texture: Self.catalogue), SKUniform(name: "u_glow", texture: Self.glow),
            SKUniform(name: "u_view", vectorFloat4: [Float(1 / view.distance), sin(tilt), cos(tilt), Float(1 / view.outer)]),
            SKUniform(name: "u_peak", vectorFloat2: [Float(heat.kelvin), Float(heat.exposure)]),
            SKUniform(name: "u_checks", float: checks ? 1 : 0),
            lens, age, seedRound, seedDeep,
        ] + knobUniforms.values)
        addChild(sprite)

        applySettings()
        turnDisc(by: 0)
        NotificationCenter.default.addObserver(self, selector: #selector(applySettings),
                                               name: UserDefaults.didChangeNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func update(_ currentTime: TimeInterval) {
        turnDisc(by: frameTime(currentTime, &lastUpdate) * Self.speed.value)
    }

    /// Moves the disc's clock on by `seconds` at speed 1, and tells the shader each streak generation's age and
    /// which stretch of the noise it's cut from. A generation is born with no weight, counts most at half its life
    /// and has faded out by the end of it, when the next takes its place from another part of the noise.
    private func turnDisc(by seconds: Double) {
        discTime += seconds * Self.unitsPerSecond
        var (ages, round, deep) = (SIMD3<Float>.zero, SIMD3<Float>.zero, SIMD3<Float>.zero)
        for k in 0..<3 {
            let lived = discTime / Self.life + Double(k) / 3, generation = firstGeneration + Int(lived) * 3 + k
            ages[k] = Float((lived - lived.rounded(.down)) * Self.life)
            // two random numbers from the generation's own number (the fractional parts of its multiples of two irrationals)
            round[k] = Float((Double(generation) * 0.6180339887).truncatingRemainder(dividingBy: 1))
            deep[k] = Float((Double(generation) * 0.7548776662).truncatingRemainder(dividingBy: 1))
        }
        (age.vectorFloat3Value, seedRound.vectorFloat3Value, seedDeep.vectorFloat3Value) = (ages, round, deep)
    }

    /// Pushes the Settings sliders into the shader. Size is the field of view: the hole is `size` times as wide.
    @objc private func applySettings() {
        for knob in Self.knobs { knobUniforms[knob.key]?.floatValue = Float(knob.value) }
        lens.floatValue = Float(tan((field ?? View().field) * .pi / 360) / (field == nil ? Self.size.value : 1))
    }

    private static let source = """
    // Where table A keeps a ray's distance: its e across, how far it has turned up (see Bending in BlackHole.swift).
    vec2 raysAt(float e2, float turn) {
        float furthest = (1.0 + e2) / (1.0 / 3.0 + 2.0 * e2 * sqrt(e2));
        return vec2((255.0 / (1.0 + 6.0 * e2) + 0.5) / 256.0, (clamp(turn / furthest, 0.0, 1.0) * 127.0 + 0.5) / 128.0);
    }

    // One over the distance, from table A's two bytes.
    float inverseRadius(vec4 t) { return (t.r + (t.g - 0.5) / 255.0) * 0.5; }

    // Which of table B's 1,024 entries keeps a ray's turn to its nearest point (a whole number is an entry's own
    // value), and that turn from an entry's three bytes.
    float turnsAt(float e2) { return clamp(1.0 - 2.0 * sqrt(max(-log(max(1.0 - e2 * 6.75, 1e-12)), 0.0) / 50.0), 0.0, 1.0) * 1023.0; }
    float turnToNearest(vec4 t) { return (t.r + (t.g - 0.5) / 255.0 + (t.b - 0.5) / 65025.0) * 8.0 + 1.5707963; }

    // How hot the disc is at a distance (one over it, u), against its hottest ring: the fourth root of the light a
    // thin disc gives off (Novikov & Thorne; Page & Thorne 1974), nothing at the inner edge and most at 4.8 radii.
    float discHeat(float u) {
        float x = sqrt(2.0 / u);
        float flux = x - 2.4494897 + 0.8660254 * log((x + 1.7320508) * 0.7174389 / ((x - 1.7320508) * 4.1815405));
        return sqrt(sqrt(max(flux, 0.0) * 8726.7 / (x * x * x * x * x * (x * x - 3.0))));
    }

    // Where the black-body table keeps a temperature's colour.
    vec2 heatAt(float kelvin) { return vec2((clamp(log(kelvin / 500.0) / 4.3820266, 0.0, 1.0) * 255.0 + 0.5) / 256.0, 0.5); }

    // Where the gas's noise is read: `round` in turns of the disc, `deep` in the log of the distance.
    vec2 gasAt(float round, float deep) {
        return (fract(vec2(round, deep / 1.2566371)) * vec2(512.0, 256.0) + 0.5) / vec2(513.0, 257.0);
    }

    // One generation's streaks, about ±0.3, from the noise's four octaves (coarse to fine). `cells` is how many of the
    // coarsest octave's cells a pixel spans; an octave fades out as its cells shrink toward a pixel, so fine streaks
    // seen edge on, or wound tight by age, melt into the glow instead of flickering.
    float streaks(vec4 n, float cells) {
        vec4 keep = 1.0 - smoothstep(vec4(0.2), vec4(0.55), cells * vec4(1.0, 2.0, 4.0, 8.0));
        return dot((n - 0.5) * keep, vec4(1.0, 0.7, 0.5, 0.35));
    }

    // A star's light `off` pixels from where it's drawn. `code` is the grid's byte for its brightness (1 at magnitude
    // −1.5, falling to 0 at 11) and `gain` the Stars slider times how far the hole has magnified it. A magnitude 9
    // star peaks at 0.22 before the stretch; brighter ones are wider as well as brighter. `room` is how far round a
    // star the pixels are sure to find it in the grid: its light is gone by there, and where the hole squeezes the
    // sky so hard that there's no room for it, it shrinks and dims instead of showing as a cut-off square.
    float starLight(float off, float code, float room, float gain) {
        float bright = 0.22 * exp(11.51 * code - 1.842) * gain;
        float fits = min(0.85 * (1.0 + 0.25 * log(1.0 + bright)), room / 2.2);
        float drawn = max(fits, 0.55);
        return bright * (fits * fits / (drawn * drawn)) * exp(-off * off / (drawn * drawn)) * (1.0 - smoothstep(0.6 * room, room, off));
    }

    // How much hotter or cooler a streak is than the disc round it (`gas` 0 to 1; no change at a half): a knot of
    // gas shines up to 12 times as bright as a lane between knots, and since brightness goes as the fourth power of
    // temperature, a knot is a quarter hotter than the disc round it and so whiter, a lane a third cooler and redder.
    float streakHeat(float gas) { return sqrt(sqrt((0.1 + 1.1 * pow(gas, 1.6)) / 0.46)); }

    // The light of the disc where a ray meets it, already times its opacity, and that opacity. `hue` is the gas's
    // colour there, `seen` its temperature against the hottest ring's as it reaches us, `gas` its streaks (0 to 1).
    // The disc thins out over the last 42% of its radius, and stops short at the innermost orbit.
    vec4 discLight(vec3 hue, float seen, float gas, float u, float outer) {
        float fade = clamp((1.0 - outer / u) / 0.42, 0.0, 1.0);
        float there = clamp((1.0 / u - 3.0) / 0.12, 0.0, 1.0) * clamp(fade * sqrt(fade) * (1.6 + 1.2 * gas), 0.0, 1.0);
        float glow = seen * seen;
        return vec4(hue * (glow * glow * there), there);
    }

    void main() {
        // The pixel's ray in the camera's frame (right, up, toward the hole), as a direction y round the hole on
        // screen and the sine of its angle off the hole. u_view: one over the camera's distance, the sine and
        // cosine of the tilt, one over the disc's outer edge.
        vec2 q = (v_tex_coord - 0.5) * vec2(2.0, 2.0 * u_size.y / u_size.x) * u_lens;
        float off2 = dot(q, q);
        vec2 y = q / max(sqrt(off2), 1e-6);
        float uc = u_view.x;
        float e = uc * sqrt(1.0 - uc) * sqrt(1.0 + off2) / max(sqrt(off2), 1e-5);
        float e2 = e * e;
        bool escapes = e2 < 0.14814815;
        // The turn it has already made on its way in from infinity to the camera (first order in the hole's size,
        // good to 1e-5 with the camera 30 radii or more out), then to its nearest point.
        float w = sqrt(max(e2 - uc * uc, 1e-12));
        float toCamera = asin(min(uc / e, 1.0)) - 0.5 * uc * uc * uc * uc / (w * (2.0 * e2 - uc * uc + 2.0 * e * w));
        // Table B is read at the entries either side and mixed here: the GPU's own smoothing places a reading only
        // to about a 35th of an entry, which put the sky a tenth of a pixel out.
        float column = turnsAt(min(e2, 0.14814815));
        float entry = min(floor(column), 1022.0);
        float before = turnToNearest(texture2D(u_turns, vec2((entry + 0.5) / 1024.0, 0.5)));
        float after = turnToNearest(texture2D(u_turns, vec2((entry + 1.5) / 1024.0, 0.5)));
        float toNearest = mix(before, after, column - entry);
        // How much further round a ray one pixel over goes, in radians. Toward the shadow's edge it grows without
        // end, and with every half-turn more comes another, thinner image of the disc.
        // (fwidth is the only slope SKShader has, the sum across and up: 4/π too much on average, taken off here.)
        float crowding = 2.0 * abs(after - before) * fwidth(column) * 0.785;
        float furthest = (1.0 + e2) / (1.0 / 3.0 + 2.0 * e2 * sqrt(e2));
        // The disc's plane cuts the ray's plane along a line this far round from the camera.
        float cut = mod(atan(-u_view.z, u_view.y * y.y), 3.1415927);

        // The ray can meet the disc once before its nearest point and once after: the second is found by mirroring
        // about the nearest point. The second holds the disc's far side arching over the hole (no half-turns), its
        // underside (one) and every finer ring.
        // ponytail: table A is left to the GPU's own smoothing, which puts the disc about a 20th of a pixel out. Read
        // its four entries and mix them here, as table B's two are, if the streaks ever look stepped (6 more reads).
        // ponytail: the light is taken to cross the disc in no time; the delay would only warp the streaks a little.
        float turn0 = toCamera + cut;
        float u0 = inverseRadius(texture2D(u_rays, raysAt(e2, turn0)));
        bool hit0 = turn0 < furthest && (!escapes || turn0 < toNearest) && u0 <= 1.0 / 3.0 && u0 >= u_view.w;
        float left = 2.0 * toNearest - toCamera - cut;
        float turn1 = mod(left, 3.1415927);
        float halfTurns = floor(left / 3.1415927);
        float u1 = inverseRadius(texture2D(u_rays, raysAt(e2, turn1)));
        bool hit1 = escapes && left > 0.0 && turn1 < toNearest && turn1 < furthest && u1 <= 1.0 / 3.0 && u1 >= u_view.w;

        // Where it leaves for the sky, if it escapes.
        float away = 2.0 * toNearest - toCamera;
        vec3 sky = vec3(sin(away) * y, -cos(away));
        // The disc's plane in the camera's frame: across the screen, and toward the camera.
        vec3 across = vec3(1.0, 0.0, 0.0);
        vec3 near = vec3(0.0, -u_view.z, -u_view.y);
        vec3 axis = vec3(0.0, u_view.y, -u_view.z);
        // Where each meeting is in the disc, and how much of the disc one pixel takes in there: `deep` in the log
        // of the distance, `wide` in turns. (Worked out for every pixel, since a slope can't be taken inside a branch.)
        float round1 = cut + halfTurns * 3.1415927;
        vec2 on0 = vec2(sin(cut) * y.x, cos(cut) * u_view.y - sin(cut) * y.y * u_view.z) / max(u0, 1e-4);   // across, toward the camera
        vec2 on1 = vec2(sin(round1) * y.x, cos(round1) * u_view.y - sin(round1) * y.y * u_view.z) / max(u1, 1e-4);
        float deep0 = -log(3.0 * max(u0, 1e-4));
        float deep1 = -log(3.0 * max(u1, 1e-4));
        float grain0 = fwidth(deep0);
        float grain1 = fwidth(deep1);
        float wide0 = length(fwidth(on0)) * u0 / 6.2831853;
        float wide1 = length(fwidth(on1)) * u1 / 6.2831853;
        // The sky where the ray leaves for, as longitude and latitude in the scene's frame, and the Milky Way there.
        // (Read for every pixel: a texture with smaller copies of itself can't be read inside a branch either.)
        float lon = atan(sky.x, sky.z);
        float lat = asin(clamp(sky.y, -1.0, 1.0));
        vec3 glow = texture2D(u_glow, vec2(lon / 6.2831853 + 0.5, lat / 3.1415927 + 0.5)).rgb;
        float pixel = fwidth(q.x);   // one pixel, in the units of q

        vec3 col = vec3(0.0);
        if (u_checks > 0.5) {
            // the prototype's checks: on the first part of the disc met, in distance and angle; on the sky, 5° squares
            vec2 on = hit0 ? on0 : on1;
            float disc = 0.25 + 0.75 * mod(floor(length(on) * 1.5) + floor(atan(on.x, on.y) / 0.2617994), 2.0);
            float squares = 0.12 + 0.3 * mod(floor(atan(dot(sky, across), dot(sky, near)) * 11.459156)
                                             + floor(asin(clamp(dot(sky, axis), -1.0, 1.0)) * 11.459156), 2.0);
            col = vec3(hit0 || hit1 ? disc : escapes ? squares : 0.0);
        } else {
            // The gas turns about the disc's axis so that the left comes toward us. `lean` is how far the light's
            // own turning about the hole goes with the gas's: it sets the Doppler shift, the same for every image.
            float lean = -y.x * u_view.y;
            // each streak generation's weight: none at birth and at the end, most at half its life
            vec3 weight = (1.0 - cos(u_age * (6.2831853 / 60.0))) / 3.0;
            vec4 light = vec4(0.0);   // rgb, and how much of what lies behind is hidden

            if (hit1) {
                float spin = sqrt(0.5 * u1 * u1 * u1) / 6.2831853;   // turns a unit of time, by Kepler
                float round = atan(on1.y, on1.x) / 6.2831853;
                vec3 run = spin * u_age;                              // how far each generation's gas has run since birth
                vec3 cells = 10.0 * (wide1 + 1.5 * run * grain1);
                float pattern = dot(weight, vec3(streaks(texture2D(u_gas, gasAt(round + run.x + u_seedRound.x, deep1 + u_seedDeep.x)), max(cells.x, grain1 * 4.8)),
                                                 streaks(texture2D(u_gas, gasAt(round + run.y + u_seedRound.y, deep1 + u_seedDeep.y)), max(cells.y, grain1 * 4.8)),
                                                 streaks(texture2D(u_gas, gasAt(round + run.z + u_seedRound.z, deep1 + u_seedDeep.z)), max(cells.z, grain1 * 4.8))));
                float gas = smoothstep(0.0, 1.0, 0.5 + pattern * 2.1 * u_streaks);
                float seen = pow(sqrt(1.0 - 1.5 * u1) / (1.0 - sqrt(0.5 * u1 * u1 * u1) * lean / e), u_beaming) * discHeat(u1) * streakHeat(gas);
                light = discLight(texture2D(u_heat, heatAt(seen * u_peak.x)).rgb, seen, gas, u1, u_view.w);
            }
            // At the shadow's edge the images of the disc pile up thinner than pixels. Drawn one by one they come out
            // as stray dots, so there they give way to what they average to: a quarter of every half-turn is lit,
            // and it comes to 0.14 of the disc's light at 5 radii. That is the hairline round the shadow.
            // ponytail: 0.14 was worked out for a disc from 3 to 11 radii; a view with another outer edge needs its own.
            float piled = smoothstep(0.6, 1.4, crowding);
            if (escapes && piled > 0.0) {
                float seen = pow(0.83666 / (1.0 - 0.063246 * lean / e), u_beaming) * 0.998 * streakHeat(0.5);
                light = mix(light, vec4(0.14 * discLight(texture2D(u_heat, heatAt(seen * u_peak.x)).rgb, seen, 0.5, 0.2, u_view.w).rgb, 0.2), piled);
            }
            if (hit0) {
                float spin = sqrt(0.5 * u0 * u0 * u0) / 6.2831853;
                float round = atan(on0.y, on0.x) / 6.2831853;
                vec3 run = spin * u_age;
                vec3 cells = 10.0 * (wide0 + 1.5 * run * grain0);
                float pattern = dot(weight, vec3(streaks(texture2D(u_gas, gasAt(round + run.x + u_seedRound.x, deep0 + u_seedDeep.x)), max(cells.x, grain0 * 4.8)),
                                                 streaks(texture2D(u_gas, gasAt(round + run.y + u_seedRound.y, deep0 + u_seedDeep.y)), max(cells.y, grain0 * 4.8)),
                                                 streaks(texture2D(u_gas, gasAt(round + run.z + u_seedRound.z, deep0 + u_seedDeep.z)), max(cells.z, grain0 * 4.8))));
                float gas = smoothstep(0.0, 1.0, 0.5 + pattern * 2.1 * u_streaks);
                float seen = pow(sqrt(1.0 - 1.5 * u0) / (1.0 - sqrt(0.5 * u0 * u0 * u0) * lean / e), u_beaming) * discHeat(u0) * streakHeat(gas);
                vec4 front = discLight(texture2D(u_heat, heatAt(seen * u_peak.x)).rgb, seen, gas, u0, u_view.w);
                light = vec4(front.rgb + (1.0 - front.a) * light.rgb, 1.0 - (1.0 - front.a) * (1.0 - light.a));
            }

            // Behind the disc, where the ray gets away: the Milky Way's glow (stored as its value to the 0.6) and the
            // catalogue's stars.
            vec3 behind = vec3(0.0);
            if (escapes && light.a < 0.996) {
                behind = pow(glow, vec3(3.667)) * (3.2 * u_milkyway);
                // How the hole stretches the sky here. Leaving at an angle `away` round the hole, a ray one step
                // further out on screen leaves `outward` times that step further round; so a step on the sky along
                // the ring's radius, or round the ring, is this many pixels on screen.
                float tand = sqrt(off2);
                float sind = tand / sqrt(1.0 + off2);
                float swing = max(-log(max(1.0 - e2 * 6.75, 1e-12)), 1e-9);
                float outward = 2.0 * (after - before) * 1023.0 * 6.75 / (50.0 * sqrt(swing / 50.0) * max(1.0 - e2 * 6.75, 1e-9)) * 2.0 * e2 / tand
                              - 1.0 / sqrt((1.0 + off2) * max(1.0 - uc - sind * sind, 1e-6));
                float side = abs(sin(away)) < 1e-4 ? 1e-4 : sin(away);   // (nought dead behind the hole, where a star is a ring)
                float alongPx = (1.0 + off2) / (outward * pixel);
                float roundPx = tand / (side * pixel);
                float magnified = min(sind / abs(outward * side), 6.0);
                // a cell east, and a cell north, as pixels on screen
                float level = sqrt(max(1.0 - sky.y * sky.y, 1e-6));
                vec3 ring = vec3(cos(away) * y, sin(away));
                vec3 east = vec3(sky.z, 0.0, -sky.x) / level;
                vec3 north = vec3(-sky.y * sky.x, level * level, -sky.y * sky.z) / level;
                vec2 eastPx = vec2(dot(east, ring) * alongPx, (y.x * east.y - y.y * east.x) * roundPx) * (0.0030680 * level);
                vec2 northPx = vec2(dot(north, ring) * alongPx, (y.x * north.y - y.y * north.x) * roundPx) * 0.0030680;
                float room = 0.5 * abs(eastPx.x * northPx.y - eastPx.y * northPx.x) / max(max(length(eastPx), length(northPx)), 1e-6);
                // the four cells round this pixel's place on the sky: any star near enough to light it is in one
                // ponytail: the stretch is taken at the pixel, which keeps a star round except right at the ring
                // dead behind the hole, where one or two come out as short dashes. Fine while the sky stands still.
                vec2 place = vec2(lon / 6.2831853 + 0.5, lat / 3.1415927 + 0.5) * vec2(2048.0, 1024.0);
                vec2 corner = floor(place - 0.5);
                for (int k = 0; k < 4; k++) {
                    vec2 cell = corner + vec2(mod(float(k), 2.0), floor(float(k) / 2.0));
                    vec4 star = texture2D(u_catalogue, (vec2(mod(cell.x, 2048.0), clamp(cell.y, 0.0, 1023.0)) + 0.5) / vec2(2048.0, 1024.0));
                    if (star.b > 0.0) {
                        vec2 step = cell + (star.rg * 255.0 + 0.5) / 256.0 - place;
                        vec3 hue = mix(vec3(1.0), texture2D(u_heat, vec2((star.a * 255.0 + 0.5) / 256.0, 0.5)).rgb, 0.7);
                        behind += hue * starLight(length(step.x * eastPx + step.y * northPx), star.b, room, u_stars * magnified);
                    }
                }
            }
            // Galaxy's stretch, asinh on brightness with the colour kept: it lifts the disc's faint outer part, holds
            // the bright side without bleaching it and leaves black black. Brightness here is the strongest channel,
            // not Galaxy's weighted sum, so the three disc colours expose alike; and the curve reaches full short of
            // the brightest gas, where red clips first, then green, so it goes yellow-white as in the mock-ups.
            vec3 x = light.rgb * (u_brightness * u_peak.y * 8.0) + (1.0 - light.a) * behind;
            float most = max(x.r, max(x.g, x.b)) + 0.0001;
            col = min(x * (log(20.0 * most + sqrt(400.0 * most * most + 1.0)) / 5.8) / most, 1.0); // asinh(20 most) / asinh(165)
            // dithered against banding, but not where nothing shines: the shadow stays exactly black
            col += (hash21(v_tex_coord * u_size * 2.0) - 0.5) / 128.0 * step(0.0005, most);
        }
        gl_FragColor = vec4(col, 1.0);
    }
    """
}
