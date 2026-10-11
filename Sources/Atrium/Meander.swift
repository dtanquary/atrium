import MeanderRiver
import SpriteKit

@MainActor func meander(size: CGSize) -> SKScene { Meander(size: size) }

/// A river wandering across its floodplain, seen from above. Each bend grows and slides down the valley until its
/// neck closes; then the river cuts through, and the loop it leaves is an oxbow lake that silts up from its ends.
/// The ground remembers when the river last left every spot, and that memory is the picture: as lidar relief, where
/// land the river left long ago stands higher and darker and the bars it built show as fine ridges, or as an old
/// survey's map, each stage of the river's past in its own ink (after Fisk's 1944 plates of the Mississippi).
/// `River` (the MeanderRiver module) is the river and the ground, on the CPU; this is its texture and the two
/// shaders that read it. docs/meander.md has the model, the measurements and the sources.
final class Meander: SKScene {
    /// The two looks, as a menu; the rows that belong to one of them show while it is picked.
    nonisolated static let look = Knob(key: "meander.look", label: "Look", range: 0...1, standard: 0, section: "Look", format: .choice(["Relief", "Old map"]))
    /// Each look's colours, as swatches under the Look menu with Random first: relief's, then the old map's. With
    /// Random a scene picks one of them when it is built. A swatch is relief's river and two of its heights, or a
    /// map's paper and its inks.
    nonisolated static let palettes = [
        PaletteChoice(key: "meander.colors", options: reliefs.map { ($0.name, [$0.river, $0.heights[2].colour, $0.heights[5].colour], [$0.river, $0.heights[2].colour, $0.heights[5].colour]) },
                      shownWhen: look.key, shownAt: 0),
        PaletteChoice(key: "meander.inks", options: maps.map { ($0.name, [$0.dark.paper] + $0.dark.inks, [$0.light.paper] + $0.light.inks) }, shownWhen: look.key, shownAt: 1),
    ]
    /// The old map's two ways with its inks (see `map(rule:)`).
    nonisolated static let rule = Knob(key: "meander.rule", label: "Inks", range: 0...1, standard: 0, section: "Look",
                                       format: .choice(["Fixed to the land", "In Fisk's order"]), shownWhen: look.key, shownAt: 1)
    nonisolated static let bars = Knob(key: "meander.scroll", label: "Scroll bars", range: 0...2, standard: 1, section: "Look", format: .times,
                                       shownWhen: look.key, shownAt: 0)
    /// Points to a channel's width. The ground keeps 14 texels to it, so a bigger river costs less, not more.
    nonisolated static let width = Knob(key: "meander.size", label: "River size", range: 28...56, standard: 28, section: "River", format: .points)
    nonisolated static let speed = Knob(key: "meander.speed", label: "Speed", range: 0.25...4, standard: 1, section: "River", format: .times)
    /// How long the ground shows where the river has been, and how long a lake lasts, in minutes at speed 1 (4.8 T
    /// to the minute): 600 T, all the ground can remember, and 16 T.
    nonisolated static let memory = Knob(key: "meander.memory", label: "Old courses stay", range: 15...125, standard: 125, section: "River", format: .minutes)
    nonisolated static let lakes = Knob(key: "meander.lakes", label: "Lakes last", range: 1...10, standard: 16 / perMinute, section: "River", format: .minutes)
    /// T to a minute at speed 1.
    nonisolated private static let perMinute = 60 / River.pace
    nonisolated static let knobs = [look, rule, bars, width, speed, memory, lakes]

    /// A colour from its three bytes.
    nonisolated private static func tone(_ r: Float, _ g: Float, _ b: Float) -> SIMD3<Float> { SIMD3(r, g, b) / 255 }

    /// Relief's colours: the river, a lake once it has dulled, ground the river hasn't reached in memory, and the
    /// land's by its height above the river, from a new bar (0) to the oldest floodplain (1). Survey Blue is
    /// measured from a relative elevation model of the Sauk (Washington Geological Survey); the others are its
    /// lightness in another hue (docs/meander.md).
    nonisolated static let reliefs: [(name: String, river: SIMD3<Float>, wet: SIMD3<Float>, ground: SIMD3<Float>, heights: [(at: Float, colour: SIMD3<Float>)])] = [
        ("Survey Blue", tone(153, 200, 211), tone(52, 130, 151), tone(0, 22, 31),
         [(0, tone(120, 178, 192)), (0.10, tone(52, 130, 151)), (0.32, tone(24, 93, 115)), (0.52, tone(14, 76, 97)),
          (0.72, tone(10, 64, 83)), (0.90, tone(4, 46, 63)), (1, tone(1, 30, 42))]),
        ("Rainforest", tone(151, 202, 192), tone(52, 132, 113), tone(2, 21, 15),
         [(0, tone(118, 180, 166)), (0.10, tone(52, 132, 113)), (0.32, tone(24, 97, 80)), (0.52, tone(14, 80, 65)),
          (0.72, tone(8, 67, 54)), (0.90, tone(0, 47, 37)), (1, tone(1, 30, 22))]),
        ("Garnet", tone(210, 187, 173), tone(143, 108, 101), tone(30, 9, 13),
         [(0, tone(186, 156, 145)), (0.10, tone(143, 108, 101)), (0.32, tone(112, 70, 71)), (0.52, tone(100, 54, 59)),
          (0.72, tone(92, 42, 51)), (0.90, tone(81, 25, 38)), (1, tone(48, 14, 21))]),
        ("Amethyst", tone(217, 184, 172), tone(165, 100, 111), tone(25, 14, 28),
         [(0, tone(199, 155, 151)), (0.10, tone(165, 100, 111)), (0.32, tone(115, 65, 96)), (0.52, tone(92, 51, 79)),
          (0.72, tone(78, 44, 73)), (0.90, tone(58, 33, 63)), (1, tone(36, 20, 40))]),
    ]

    /// An old map's sheet: its paper, the river (bare paper, a touch lighter), its line ink and the four inks of
    /// the river's stages.
    struct Sheet {
        var paper: SIMD3<Float>, river: SIMD3<Float>, line: SIMD3<Float>, inks: [SIMD3<Float>]
    }

    /// The old map's colours, in Light and in Dark Mode. Fisk 1944's Light sheet is measured from the legend of his
    /// plates: sage, salmon, grey-teal and straw on cream, and a brown line ink, not black. Sage, Salmon and Teal are
    /// one of those inks each, with a second shade a touch darker so that the stages still show. The Dark sheets are
    /// not his: a dark ground, and his inks brought to one lightness on it (docs/meander.md, "Palettes proposed").
    nonisolated static let maps: [(name: String, light: Sheet, dark: Sheet)] = [
        ("Fisk 1944",
         Sheet(paper: tone(235, 224, 196), river: tone(244, 237, 216), line: tone(89, 75, 59),
               inks: [tone(188, 199, 139), tone(215, 114, 97), tone(154, 180, 159), tone(221, 208, 123)]),
         Sheet(paper: tone(27, 24, 20), river: tone(166, 158, 138), line: tone(80, 76, 67),
               inks: [tone(100, 106, 74), tone(123, 65, 55), tone(82, 96, 84), tone(110, 104, 61)])),
        // one ink, in two shades a touch apart so that its stages still show
        ("Sage",
         Sheet(paper: tone(235, 224, 196), river: tone(244, 237, 216), line: tone(89, 75, 59), inks: [tone(188, 199, 139), tone(172, 186, 124)]),
         Sheet(paper: tone(27, 24, 20), river: tone(166, 158, 138), line: tone(80, 76, 67), inks: [tone(100, 106, 74), tone(86, 92, 62)])),
        ("Salmon",
         Sheet(paper: tone(235, 224, 196), river: tone(244, 237, 216), line: tone(89, 75, 59), inks: [tone(215, 114, 97), tone(198, 105, 89)]),
         Sheet(paper: tone(27, 24, 20), river: tone(166, 158, 138), line: tone(80, 76, 67), inks: [tone(163, 87, 74), tone(140, 75, 64)])),
        ("Teal",
         Sheet(paper: tone(235, 224, 196), river: tone(244, 237, 216), line: tone(89, 75, 59), inks: [tone(154, 180, 159), tone(142, 166, 146)]),
         Sheet(paper: tone(27, 24, 20), river: tone(166, 158, 138), line: tone(80, 76, 67), inks: [tone(91, 106, 94), tone(78, 91, 81)])),
    ]

    /// Texels to a channel's width: at the smallest river a texel is 2 points.
    private static let texels: Float = 14
    /// How long a stage of the old map lasts, in T: short when a stage's ink stays with its land for good (thin
    /// stripes), long when the whole sheet moves on to Fisk's next colours at each stage.
    private static let stages = [5.0, 11.0]

    private(set) var river: River!
    /// The ground as it was at the river's last two steps, and when each was: the picture is mixed from the two by
    /// how far the river is toward its next step, so a bank moves on every frame and not only when the river
    /// steps. Each step's bytes go to whichever holds the older.
    private var textures: [SKMutableTexture] = [], times = [0.0, 0.0], newest = 0
    private var ground: SKSpriteNode!
    private let clocks = SKUniform(name: "u_t", vectorFloat2: .zero), blend = SKUniform(name: "u_blend", float: 0)
    private let turns = SKUniform(name: "u_turns", vectorFloat4: .zero), settings = SKUniform(name: "u_knobs", vectorFloat4: .zero)
    private var lastTime: TimeInterval?
    /// What it was built and dressed with: the river's size, what Settings wanted the ground to wear, and the
    /// colours Random has picked for each look, which hold for the scene's life.
    private let built = Meander.width.value.rounded()
    private var dressed: [String] = [], map = false, stage = stages[0]
    private let lucky = (relief: Int.random(in: reliefs.indices), sheet: Int.random(in: maps.indices))
    /// Settings changes so far, so only the last of a quick run rebuilds; and whether it has handed over to a new scene.
    private var changes = 0, retired = false

    override func sceneDidLoad() {
        backgroundColor = .black
        // ("meander.seed" is for the tests, which want the same river twice; nothing else sets it.)
        let seed = UInt64(max(UserDefaults.standard.integer(forKey: "meander.seed"), 0))
        river = River(seed: seed > 0 ? seed : .random(in: 1...UInt64.max), across: Float(size.width / built), up: Float(size.height / built), texels: Self.texels)
        river.lakeLife = Self.lakes.value * Self.perMinute
        river.age()
        textures = (0..<2).map { _ in
            let texture = SKMutableTexture(size: CGSize(width: river.columns, height: river.rows))
            texture.filteringMode = .linear
            return texture
        }
        ground = SKSpriteNode(texture: textures[0], size: size)
        ground.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(ground)
        dress()
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: UserDefaults.didChangeNotification, object: nil)
    }

    /// What Settings wants the ground to wear: the look, the old map's rule, and each look's colours by name (none
    /// is Random).
    private static var wanted: [String] {
        [look, rule].map { "\($0.value)" } + palettes.map { UserDefaults.standard.string(forKey: $0.key) ?? "" }
    }

    /// Gives the ground the look Settings asks for: a shader of its own for relief and for each of the old map's
    /// rules, with the colours picked. The river is the same river, so a look can be changed while it runs.
    private func dress() {
        dressed = Self.wanted
        map = Self.look.value > 0.5
        let rule = Int(Self.rule.value)
        stage = Self.stages[rule]
        var uniforms = [SKUniform(name: "u_grid", vectorFloat2: [Float(river.columns), Float(river.rows)]), SKUniform(name: "u_other", texture: textures[1]),
                        clocks, blend, turns, settings]
        if map {
            let sheets = Self.maps[Self.maps.firstIndex { $0.name == dressed[3] } ?? lucky.sheet], sheet = systemIsDark ? sheets.dark : sheets.light
            uniforms += [SKUniform(name: "u_paper", vectorFloat3: sheet.paper), SKUniform(name: "u_river", vectorFloat3: sheet.river),
                         SKUniform(name: "u_line", vectorFloat3: sheet.line), SKUniform(name: "u_stage", float: Float(stage))]
            // four inks; a sheet of two takes them in turn
            uniforms += (0..<4).map { SKUniform(name: "u_ink\($0)", vectorFloat3: sheet.inks[$0 % sheet.inks.count]) }
        } else {
            let relief = Self.reliefs[Self.reliefs.firstIndex { $0.name == dressed[2] } ?? lucky.relief]
            // the land's colour by height, 256 across
            let ramp = (0..<256).flatMap { level -> [UInt8] in
                let height = Float(level) / 255, above = relief.heights.firstIndex { $0.at >= height } ?? relief.heights.count - 1
                let (lo, hi) = (relief.heights[max(above - 1, 0)], relief.heights[above])
                let colour = simd_mix(lo.colour, hi.colour, SIMD3(repeating: hi.at > lo.at ? (height - lo.at) / (hi.at - lo.at) : 0))
                return [UInt8(colour.x * 255 + 0.5), UInt8(colour.y * 255 + 0.5), UInt8(colour.z * 255 + 0.5), 255]
            }
            let heights = SKTexture(data: Data(ramp), size: CGSize(width: 256, height: 1))
            heights.filteringMode = .linear
            uniforms += [SKUniform(name: "u_heights", texture: heights), SKUniform(name: "u_river", vectorFloat3: relief.river),
                         SKUniform(name: "u_wet", vectorFloat3: relief.wet), SKUniform(name: "u_ground", vectorFloat3: relief.ground),
                         SKUniform(name: "u_oldest", vectorFloat3: relief.heights[relief.heights.count - 2].colour)]
        }
        ground.shader = SKShader(source: shaderCommon + Self.reads + (map ? Self.map(rule: rule) : Self.relief), uniforms: uniforms)
        tune()
        if times == [0, 0] { for _ in 0..<2 { upload() } } // a new scene: both grounds are the river's first
        show()
    }

    /// The sliders a shader or the river follows as they move: texels to a point of the screen (the river's size),
    /// how long old courses stay in T, the scroll bars' strength, and a lake's life in T.
    private func tune() {
        river.lakeLife = Self.lakes.value * Self.perMinute
        settings.vectorFloat4Value = [Float(Double(river.columns) / size.width), Float(min(Self.memory.value * Self.perMinute, River.memory)), Float(Self.bars.value), Float(river.lakeLife)]
    }

    /// When Settings changes: the sliders at once, a new look as soon as it is asked for, and a new size of river,
    /// which is a new river, once the slider has rested a moment: it dissolves into a scene built to it, both still
    /// running. By the clock, not an action, which a frozen view would hold.
    @objc private func settingsChanged() {
        guard !retired else { return }
        tune()
        if Self.wanted != dressed { dress() }
        guard Self.width.value.rounded() != built else { return }
        changes += 1
        let change = changes
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.3))
            if let self, change == changes { handOver() }
        }
    }

    /// Hands over to a new scene with a river of the size Settings now asks for, if that isn't this one's.
    func handOver() {
        guard !retired, Self.width.value.rounded() != built, let view else { return } // no view: the render tests
        retired = true
        let fade = SKTransition.crossFade(withDuration: 0.8)
        (fade.pausesIncomingScene, fade.pausesOutgoingScene) = (false, false)
        let next = Meander(size: size)
        next.scaleMode = scaleMode
        view.presentScene(next, transition: fade)
    }

    override func update(_ currentTime: TimeInterval) {
        river.advance(frameTime(currentTime, &lastTime), speed: Self.speed.value) { upload() }
        show()
    }

    /// Sends the ground's bytes to the texture holding the older of the last two steps, with the time since the
    /// stamps' base as it now is, from which the shader works out that ground's ages. (Each ground has its own, so
    /// the two can be mixed across a move of the base, `River.rebase`.)
    func upload() {
        newest = 1 - newest
        // The river's own buffer, not a copy of it: SpriteKit takes the bytes before `modifyPixelData` returns
        // (meanderGroundReachesTheShader checks that it does), and the river next writes on them a step later
        river.pixels.withUnsafeBytes { buffer in
            nonisolated(unsafe) let bytes = buffer
            textures[newest].modifyPixelData { data, length in data?.copyMemory(from: bytes.baseAddress!, byteCount: min(length, bytes.count)) }
        }
        times[newest] = river.now
        var since = clocks.vectorFloat2Value
        since[newest] = Float(river.now - river.base)
        clocks.vectorFloat2Value = since
    }

    /// Tells the shader, on every frame, how to mix the two grounds: by how far the river is toward its next step,
    /// so the picture is of the river a step ago moving on to where it is now. And how far through each of its
    /// cycles that moment is: relief's two scroll-bar spacings and the sets of them, or the map's swales and its
    /// stages, counted in fours for its four inks (and from 160, so a stage's number is never below nothing). The
    /// cycles are in the time itself, not the time since the base, so nothing moves when the base does.
    private func show() {
        // in 256ths, so the frame rate's own way of adding the time up can't show in the last bits of the picture
        let toward = (min(max(river.owed, 0), 1) * 256).rounded(.down) / 256, now = times[1 - newest] + toward * (times[newest] - times[1 - newest])
        blend.floatValue = Float(newest == 1 ? toward : 1 - toward)
        func turn(_ period: Double) -> Float { Float(now / period - (now / period).rounded(.down)) }
        turns.vectorFloat4Value = map ? [turn(1.4), 0, 0, turn(stage * 4) * 4 + 160] : [turn(0.7), turn(1.1326), turn(2.9), 0]
    }

    /// The start of both shaders: the ground read smoothly, and what both looks need from it.
    private static let reads = """
    // Soft noise from -1 to 1, one random number a cell.
    float lumps(vec2 q) {
        vec2 i = floor(q), f = fract(q), u = f * f * (3.0 - 2.0 * f);
        return mix(mix(hash42(i).x, hash42(i + vec2(1.0, 0.0)).x, u.x),
                   mix(hash42(i + vec2(0.0, 1.0)).x, hash42(i + vec2(1.0, 1.0)).x, u.x), u.y) * 2.0 - 1.0;
    }

    // How land `j` stages old is inked in Fisk's order: which of the four inks (x) and how much of it (y). The four
    // newest stages are solid, each in its own ink; then four runs of four stages in one ink, paler by the stage;
    // then the last ink fading out.
    vec2 inked(float j) {
        j = clamp(j, 0.0, 60.0);
        if (j < 3.5) { return vec2(j, 1.0); }
        if (j > 19.5) { return vec2(3.0, 0.23 * max(0.0, 1.0 - (j - 19.0) / 34.0)); }
        float run = floor((j - 4.0) / 4.0), within = j - 4.0 - 4.0 * run;
        return vec2(run < 0.5 ? 2.0 : run < 1.5 ? 1.0 : run < 2.5 ? 0.0 : 3.0, within < 0.5 ? 0.65 : within < 1.5 ? 0.5 : within < 2.5 ? 0.4 : 0.23);
    }

    // How high land of an age stands above the river, 0 to 1 (a bar is up out of the water within a couple of T,
    // then silts up for ages), and how far it is gone back to ground the river never made, given how long old
    // courses stay: relief's two readings of an age, as its shader works them out for the smooth read.
    vec2 stands(float age, float memory) {
        float gone = clamp((age - 0.8 * memory) / (0.18 * memory), 0.0, 1.0);
        return vec2(0.25 * (1.0 - exp(-age / 2.5)) + 0.75 * (1.0 - exp(-age / 90.0)), gone * gone * (3.0 - 2.0 * gone));
    }

    vec3 pick(float which, vec3 a, vec3 b, vec3 c, vec3 d) { return which < 0.5 ? a : which < 1.5 ? b : which < 2.5 ? c : d; }

    void main() {
        // cubic B-spline between texels, in four linear taps (GPU Gems 2, ch. 20), so no grid shows
        vec2 p = v_tex_coord * u_grid - 0.5, i = floor(p), s = p - i;
        vec2 w0 = (1.0 - s) * (1.0 - s) * (1.0 - s) / 6.0, w3 = s * s * s / 6.0;
        vec2 w1 = (4.0 - 6.0 * s * s + 3.0 * s * s * s) / 6.0, w2 = 1.0 - w0 - w1 - w3;
        vec2 g0 = w0 + w1, g1 = w2 + w3;
        vec2 h0 = (i - 0.5 + w1 / g0) / u_grid, h1 = (i + 1.5 + w3 / g1) / u_grid;
        vec4 a00 = texture2D(u_texture, h0), a10 = texture2D(u_texture, vec2(h1.x, h0.y));
        vec4 a01 = texture2D(u_texture, vec2(h0.x, h1.y)), a11 = texture2D(u_texture, h1);
        vec4 b00 = texture2D(u_other, h0), b10 = texture2D(u_other, vec2(h1.x, h0.y));
        vec4 b01 = texture2D(u_other, vec2(h0.x, h1.y)), b11 = texture2D(u_other, h1);
        // Two grounds, the river's last two steps, read alike and mixed by how far the river is toward its next
        // (`u_blend` is the second's share), so every frame is a new picture. Bank distances mix into a bank part
        // of the way; ages are mixed as ages, each ground's from its own time since the base.
        vec4 ground1 = g0.y * (g0.x * a00 + g1.x * a10) + g1.y * (g0.x * a01 + g1.x * a11);
        vec4 ground2 = g0.y * (g0.x * b00 + g1.x * b10) + g1.y * (g0.x * b01 + g1.x * b11);
        vec4 t = mix(ground1, ground2, u_blend);
        // and its slopes a texel, across and up, from the same four taps: the taps are that far apart
        vec2 apart = (h1 - h0) * u_grid;
        vec4 across = mix(g0.y * (a10 - a00) + g1.y * (a11 - a01), g0.y * (b10 - b00) + g1.y * (b11 - b01), u_blend) / apart.x;
        vec4 up = mix(g0.x * (a01 - a00) + g1.x * (a11 - a10), g0.x * (b01 - b00) + g1.x * (b11 - b10), u_blend) / apart.y;
        float bank = (t.b - 0.5) * 4.0;  // texels from the nearest bank, below 0 in the water
        float low = 0.25 + 0.75 * t.a;   // an old channel's bank distance, in widths
        // How long ago the river left here, in T, and that time's slope a texel. Ground it left longer ago than it
        // remembers, or never reached, is all ground1 age and dead flat. From here on the shader works in ages only,
        // and in where the present falls in each cycle (`u_turns`): the stamps themselves count from a base that
        // moves, and nothing may change when it does.
        float past = mix(u_t.x - (ground1.r * 65280.0 + ground1.g * 255.0) / 100.0, u_t.y - (ground2.r * 65280.0 + ground2.g * 255.0) / 100.0, u_blend);
        vec2 slope = vec2(across.r * 65280.0 + across.g * 255.0, up.r * 65280.0 + up.g * 255.0) / 100.0 * (1.0 - smoothstep(604.5, 605.0, past));
        past = min(past, 605.0);
        vec2 shore = vec2(across.b, up.b); // points away from the water
        shore /= max(length(shore), 0.0001);
        // texels to a pixel, across and up, from the GPU's own slopes, which are one value to a block of four pixels:
        // good enough for this. `pt` is texels to a point of the screen (half a one, at the smallest river), and
        // `pts` is where this is in points, for grain and mottling that keep their size whatever the river's.
        vec2 perPixel = vec2(dfdx(p.x), dfdy(p.y));
        float pixel = abs(perPixel.x), pt = u_knobs.x;
        vec2 pts = p / pt;

        // At a bank the smooth read is a blend of the water's stamp and the land's. So the stamp is read twice more:
        // two texels into the water, for the water's own age (none for the river, a lake's for a lake), and two
        // texels out, for the land beside a bank, so a cut bank is a clean step up to old ground.
        vec2 inward = v_tex_coord - 2.0 * shore / u_grid, outward = v_tex_coord + 2.0 * shore / u_grid;
        vec4 in1 = texture2D(u_texture, inward), in2 = texture2D(u_other, inward), out1 = texture2D(u_texture, outward), out2 = texture2D(u_other, outward);
        float wetAge = clamp(mix(u_t.x - (in1.r * 65280.0 + in1.g * 255.0) / 100.0, u_t.y - (in2.r * 65280.0 + in2.g * 255.0) / 100.0, u_blend), 0.0, 605.0);
        float beside = min(mix(u_t.x - (out1.r * 65280.0 + out1.g * 255.0) / 100.0, u_t.y - (out2.r * 65280.0 + out2.g * 255.0) / 100.0, u_blend), 605.0);
        float nearing = clamp((bank - 0.5) / 1.4, 0.0, 1.0);
        float near = 1.0 - nearing * nearing * (3.0 - 2.0 * nearing), age = mix(past, beside, near);
        // the age's slope a texel, taking the land beside a bank as level
        vec2 older = (near - 1.0) * slope - (beside - past) * 6.0 * nearing * (1.0 - nearing) / 1.4 * 4.0 * vec2(across.b, up.b);
        float water = 1.0 - smoothstep(-0.6 * pixel, 0.6 * pixel, bank);
        vec2 middle = v_tex_coord - 0.5;

    """

    /// Lidar relief, coloured by height above the river: the river and the bars at its level are the lightest
    /// thing, land darkens as it builds up, and there are no outlines.
    private static let relief = """
        // height above the river, 0 to 1: a bar is up out of the water within a couple of T, then silts up for ages
        float height = 0.25 * (1.0 - exp(-age / 2.5)) + 0.75 * (1.0 - exp(-age / 90.0));
        vec2 rise = (0.1 * exp(-age / 2.5) + 0.75 / 90.0 * exp(-age / 90.0)) * older; // its slope a texel
        // Ground the river has not reached in memory (as long as Settings has old courses stay): not flat, but
        // nothing like a river's work either, and what the river made there fades out of it.
        float gone = clamp((age - 0.8 * u_knobs.y) / (0.18 * u_knobs.y), 0.0, 1.0), wild = gone * gone * (3.0 - 2.0 * gone);
        vec2 fading = 6.0 * gone * (1.0 - gone) / (0.18 * u_knobs.y) * older; // and that's slope a texel
        // A scarp with new land at its foot, where the river has drawn back from a bank it was cutting (as it does
        // in the seconds after a cutoff). The height is steep in age at first, so the smooth read's mix of ages came
        // out nearly as high as the old ground wherever it had any old ground in it: the scarp in texel-sized
        // stairs. There the height is mixed from the sixteen texels' own heights instead, by the same weights, and
        // its slope from them. Only on a slope with new land among the sixteen, and not within a texel and a half
        // of water (all of it from two texels off): settled ground is drawn as it was, and so is every bank, where the
        // water's own texels would come into the mix as land at the river's level and show as a light rim.
        // (Everything that decides it is mixed by those weights too, which fall to nothing as a texel goes out of
        // reach: the least or the most of the four reads changes at once there, and that showed as a chequerboard.)
        float drop = length(slope), scarp = smoothstep(0.25, 1.0, drop) * smoothstep(1.4, 2.0, bank);
        if (scarp > 0.0 && past - 3.0 * drop < 20.0) {
            vec4 wx = vec4(w0.x, w1.x, w2.x, w3.x), wy = vec4(w0.y, w1.y, w2.y, w3.y);
            vec2 d0 = -0.5 * (1.0 - s) * (1.0 - s), d1 = 1.5 * s * s - 2.0 * s, d3 = 0.5 * s * s, d2 = -d0 - d1 - d3; // the weights' slopes
            vec4 dx = vec4(d0.x, d1.x, d2.x, d3.x), dy = vec4(d0.y, d1.y, d2.y, d3.y);
            float mixed = 0.0;
            vec2 sloped = vec2(0.0);
            vec4 ends = vec4(0.0); // for the lowest, the highest, the furthest gone and the youngest of them, softly
            for (int row = 0; row < 4; row++) {
                for (int column = 0; column < 4; column++) {
                    vec2 texel = (i + vec2(float(column), float(row)) - 0.5) / u_grid;
                    vec4 one = texture2D(u_texture, texel), other = texture2D(u_other, texel);
                    float aged = clamp(mix(u_t.x - (one.r * 65280.0 + one.g * 255.0) / 100.0, u_t.y - (other.r * 65280.0 + other.g * 255.0) / 100.0, u_blend), 0.0, 605.0);
                    vec2 its = stands(aged, u_knobs.y);
                    mixed += wx[column] * wy[row] * its.x;
                    sloped += vec2(dx[column] * wy[row], wx[column] * dy[row]) * its.x;
                    ends += wx[column] * wy[row] * exp(vec4(-30.0 * its.x, 30.0 * (its.x - 1.0), 30.0 * (its.y - 1.0), -0.5 * aged));
                }
            }
            scarp *= 1.0 - smoothstep(8.0, 20.0, -2.0 * log(ends.w)); // all of it where the youngest is under 8 T old, none over 20
            // The ground is as far gone as the furthest gone of the sixteen, by how far the height is from the
            // lowest of them to the highest: mixed from the texels' own, which are gone or not, the edge of ground
            // the river never made came out in stairs too.
            float lowest = -log(ends.x) / 30.0, share = (1.0 + log(ends.z) / 30.0) / max(1.0 + log(ends.y) / 30.0 - lowest, 0.02);
            float lost = clamp((mixed - lowest) * share, 0.0, 1.0);
            // beside water the land is still the land two texels out, as a cut bank's is
            vec2 land = stands(beside, u_knobs.y), stepped = 6.0 * nearing * (1.0 - nearing) / 1.4 * 4.0 * vec2(across.b, up.b);
            height = mix(height, mix(mixed, land.x, near), scarp);
            wild = mix(wild, mix(lost, land.y, near), scarp);
            rise = mix(rise, (1.0 - near) * sloped - (land.x - mixed) * stepped, scarp);
            fading = mix(fading, (1.0 - near) * share * sloped - (land.y - lost) * stepped, scarp);
        }
        // an old channel stays low for a long while, but never at once: a lake first
        float dip = clamp((0.66 - low) / 0.12, 0.0, 1.0), settled = smoothstep(2.0, 12.0, wetAge) * exp(-wetAge / 140.0);
        float sunk = 0.14 * smoothstep(0.1, 0.4, height) * (1.0 - water) * settled;
        // The ground's slope a texel is worked out beside each part of its height, not taken from the GPU's slopes
        // of the height: those are one value to a block of four pixels, which dotted every scarp, and they made a
        // sixth of the picture flicker by a level whenever the stamps' base moved.
        vec2 tilt = 0.35 * (1.0 - wild) * (rise + sunk * 6.0 * dip * (1.0 - dip) / 0.12 * 0.75 * vec2(across.a, up.a));
        height -= sunk * dip * dip * (3.0 - 2.0 * dip);
        // Scroll bars: old bank lines, so contours of the stamp. Two spacings beating, uneven in strength, and low;
        // and sets of them, arcs that show at a glance. Where the lines would be too fine to draw, or across a
        // scarp, the ground is flat. Settings has their strength.
        float steep = 6.2832 * length(slope) * 0.5; // how far half a texel takes the stamp, as an angle for a period of 1 T
        float bars = u_knobs.z * (1.0 - wild) * (1.0 - smoothstep(0.7, 1.5, steep / 0.7)) * (0.55 + 0.34 * lumps(pts / 70.0 + 5.0)) * (0.35 + 0.65 * exp(-age / 150.0));
        float sets = u_knobs.z * (1.0 - wild) * 0.9 * (1.0 - smoothstep(0.7, 1.5, steep / 2.9)) * (0.5 + 0.5 * exp(-age / 200.0));
        vec3 turn = 6.2832 * fract(u_turns.xyz - past / vec3(0.7, 1.1326, 2.9)) + vec3(0.0, 1.3, 0.7);
        float scroll = bars * (0.6 * cos(turn.x) + 0.4 * cos(turn.y)) + sets * cos(turn.z);
        tilt -= 0.03 * (bars * (0.6 * sin(turn.x) / 0.7 + 0.4 * sin(turn.y) / 1.1326) + sets * sin(turn.z) / 2.9) * 6.2832 * slope;
        float rough = 0.75 * (0.6 * lumps(pts / 60.0) + 0.3 * lumps(pts / 22.0 + 9.0) + 0.1 * lumps(pts / 8.0 + 17.0));
        tilt += 0.05 * (rough * fading + wild * vec2(dfdx(rough), dfdy(rough)) / perPixel);
        vec3 col = texture2D(u_heights, vec2((clamp(height + 0.02 * scroll, 0.0, 1.0) * 255.0 + 0.5) / 256.0, 0.5)).rgb;
        col = mix(col, mix(u_ground, u_oldest, smoothstep(-0.1, 0.55, rough)), wild);
        // light from the upper left on the fine relief only, and none within a few pixels of water: no rims
        tilt *= -5.0;
        float shade = (dot(tilt, vec2(-0.55, 0.62)) + 0.56) / sqrt(dot(tilt, tilt) + 1.0) - 0.56;
        col *= clamp(1.0 + 0.9 * shade * smoothstep(0.25, 1.9, bank), 0.72, 1.3);
        // Water the river has left dulls a little over its first few T: a lake. And it dulls to the colour of a new
        // bar in its shallows, within two texels of its banks, and all of it over the second half of its life, so
        // that a lake silted down to a sliver is dull right through and doesn't shine like a highlight. Where the
        // water is deep its age is the smooth read's, so a lake shades into the river it lies against.
        float still = mix(wetAge, past, smoothstep(0.8, 1.8, -bank)), lake = smoothstep(0.3, 4.0, still);
        float dull = 0.35 * lake + 0.65 * max(smoothstep(0.5 * u_knobs.w, u_knobs.w, still), lake * (1.0 - smoothstep(0.5, 2.0, -bank)));
        col = mix(col, mix(u_river, u_wet, dull), water);
        gl_FragColor = vec4(col * (1.0 - 0.44 * dot(middle, middle)) * 0.86, 1.0);
    }
    """

    /// A map of the river's old courses: each spot is inked for the stage in which the river last left it. The
    /// live river is bare paper between two bank lines; a lake keeps that line when new, and it thins. With `rule`
    /// 0 a stage's ink stays with its land for good, the four inks in turn, and only pales with age. With 1 land is
    /// inked as Fisk inks land that many stages old, and the whole sheet slides on to the next colours over the last
    /// third of every stage.
    private static func map(rule: Int) -> String {
        let inks = rule == 0 ? """
            float cover = kept * (1.0 - 0.35 * clamp((old - 1.5) / 1.5, 0.0, 1.0) - 0.15 * clamp((old - 3.0) / 3.0, 0.0, 1.0) - 0.1 * clamp((old - 6.0) / 6.0, 0.0, 1.0)
                - 0.17 * clamp((old - 12.0) / 18.0, 0.0, 1.0) - 0.11 * clamp((old - 30.0) / 60.0, 0.0, 1.0) - 0.12 * clamp((old - 90.0) / 30.0, 0.0, 1.0));
            vec3 col = mix(paper, mix(pick(mod(number - 1.0, 4.0), u_ink0, u_ink1, u_ink2, u_ink3), pick(mod(number, 4.0), u_ink0, u_ink1, u_ink2, u_ink3), newer) * grain, cover);
        """ : """
            // land in this stage, and in the one before it and the one before that, as Fisk inks land that old
            float slide = smoothstep(0.67, 1.0, fract(u_turns.w)), ago = floor(u_turns.w) - number;
            vec2 one = inked(ago), two = inked(ago + 1.0), three = inked(ago + 2.0);
            vec3 first = mix(paper, pick(one.x, u_ink0, u_ink1, u_ink2, u_ink3) * grain, one.y * kept);
            vec3 second = mix(paper, pick(two.x, u_ink0, u_ink1, u_ink2, u_ink3) * grain, two.y * kept);
            vec3 third = mix(paper, pick(three.x, u_ink0, u_ink1, u_ink2, u_ink3) * grain, three.y * kept);
            float cover = kept * mix(mix(two.y, three.y, slide), mix(one.y, two.y, slide), newer);
            vec3 col = mix(mix(second, third, slide), mix(first, second, slide), newer);
        """
        return """
            // how many stages ago the river left here, and in which stage, counted so that the present is `u_turns.w`
            float old = past / u_stage, staged = u_turns.w - old;
            float grain = 1.0 + 0.023 * lumps(pts / 3.0) + 0.019 * lumps(pts / 40.0 + 3.0);
            vec3 paper = u_paper * grain;
            // Where one stage meets the next its ink is mixed with the last one's across a pixel (`newer` is this
            // stage's share), so the edge is smooth under its line, and a spot on it can't turn from one ink to
            // the other on the last bits of its age. `rise` is stages to a point of the screen.
            float rise = length(slope) * pt / u_stage + 1e-9, mixed = staged + 0.5 * rise * pixel / pt;
            float number = floor(mixed), newer = clamp((mixed - number) / (rise * pixel / pt), 0.0, 1.0);
            // the inks go from ground the river has forgotten, as long as Settings has old courses stay
            float kept = 1.0 - smoothstep(0.8 * u_knobs.y, 0.98 * u_knobs.y, past);
        \(inks)
            // thin lines where one stage meets the next and along old scarps; faint ridge-and-swale lines inside a stage
            // (none on ground that is dead flat, a cut-off loop's bed say: left all at once, it might be all on a line)
            float part = staged - floor(staged), sloping = min(rise * 1e4, 1.0);
            float edge = max(1.0 - smoothstep(0.2, 0.8, min(part, 1.0 - part) / rise), smoothstep(1.75, 4.0, rise * u_stage)) * sloping * (0.25 + 0.75 * smoothstep(0.0, 0.5, cover));
            float swale = fract(u_turns.x - past / 1.4), fine = rise * u_stage / 1.4;
            float hatch = (1.0 - smoothstep(0.15, 0.6, min(swale, 1.0 - swale) / fine)) * (1.0 - smoothstep(0.22, 0.4, fine)) * cover * sloping;
            col = mix(col, u_line, clamp(0.45 * edge + 0.12 * hatch, 0.0, 1.0));
            col = mix(col, u_river * grain, water);
            // the river, and a lake for its first few T, wear the full bank line
            float off = abs(bank) / pt, fresh = 1.0 - smoothstep(0.5, 6.0, wetAge);
            col = mix(col, u_line, max((1.0 - smoothstep(0.3, 1.3, off)) * 0.7, (1.0 - smoothstep(0.5, 1.5, off)) * fresh));
            gl_FragColor = vec4(col * (1.0 - 0.32 * dot(middle, middle)), 1.0);
        }
        """
    }
}
