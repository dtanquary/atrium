import AntNest
import SpriteKit
import Synchronization

@MainActor func antColony(size: CGSize) -> SKScene { AntColony(size: size) }

/// A colony of ants digging its nest in a thin tank seen from the side, with the display as its glass: a tank of
/// blue gel lit from below, of sand, or of earth. A farm lasts a day: at six in the morning the tank is whole and a few ants
/// are on top of it; they sink a shaft, branch it, open rooms, and carry what they dig up to lie round the mouths;
/// by the next morning the nest is finished, and another begins. The colony grows with its nest.
///
/// The nest is baked whole from the date (`Nest`, in the AntNest module): one map of when each cell is dug, as a
/// share of all the digging, so the shader shows the nest at any moment by comparing that map with one number and
/// a frame costs the same however much is dug. The number comes from the wall's clock (`farm`, `share`), so the
/// nest goes on from where it was after a relaunch or Shuffle, and every copy of the scene is at the same moment
/// of the same farm. (The nest itself is baked for a copy's own size, a tank as wide as its display: two displays
/// of one size show one nest, and two of different sizes, or Settings' preview, two nests of the one seed, each
/// as far dug as the other.) The ants are not what digs it: they are sent to the faces the map says are being worked
/// (`Colony`), and drawn as a body and its jointed legs, feet planted on the walls.
/// docs/ant-colony.md has the measurements of real ants and nests these follow, and the sources.
final class AntColony: SKScene {
    /// The tank's medium, every one Dave was shown: the blue gel lit from its base, deep and dim, or brighter with
    /// a bloom over each lamp; sand, dimmed and warm as a wallpaper wants it, or as white as the toy's; or earth.
    nonisolated static let look = Knob(key: "antcolony.look", label: "Look", range: 0...4, standard: 0, section: "Tank",
                                       format: .choice(["Gel", "Bright Gel", "Sand", "White Sand", "Earth"]))
    /// How fast a nest is dug: at 1 it takes the day, and at the top three hours. Moving it never moves the dig:
    /// the nest goes on from where it is at the new pace (`Cycle`). The ants walk no faster for it, so the faster
    /// the digging the more of it goes on with no ant at the face: the top is where a face that moves still has an
    /// ant digging at it two times in three at every hour of the day (measured: 79% of the time at 1, 70% at 8,
    /// and under two in three through the morning at 12; docs/ant-colony.md). At 8 the day's first shaft goes down
    /// an ant's length in thirteen seconds.
    nonisolated static let speed = Knob(key: "antcolony.speed", label: "Speed", range: 1...8, standard: 1, section: "Tank", format: .times)
    /// An ant's length: 13, 22 or 36 points (26, 44 or 72 of a Retina display's pixels). The tank is the display
    /// whatever the size, so smaller ants have a bigger nest to dig.
    nonisolated static let antSize = Knob(key: "antcolony.size", label: "Ant size", range: 0...2, standard: 1, section: "Ants",
                                          format: .choice(["Small", "Medium", "Large"]))
    /// How crowded the grown colony is: at 1, an ant to every 130 square ant lengths of tank, which is 24 on a
    /// 14-inch display at the middle size and 69 at the small one; and never more than ninety.
    // ponytail: an ant is eighteen sprites, a length of leg each, and each is placed and turned every frame it
    // walks: ninety ants are 2 ms of a frame's CPU on the largest display. One shader drawing a whole ant would
    // lift that.
    nonisolated static let crowd = Knob(key: "antcolony.ants", label: "Ants", range: 0.5...2, standard: 1, section: "Ants", format: .times)
    nonisolated static let knobs = [look, speed, antSize, crowd]

    /// An ant's length in points at each size, and in cells of the nest's map at every size.
    nonisolated private static let lengths = [13.0, 22.0, 36.0], antCells = 11.0
    /// The hour a day's first farm begins.
    nonisolated static let dawn = 6.0

    /// The share of the digging done `hours` after a farm began: 8% in the first hour, 23% in three, 44% by noon,
    /// 75% by six in the evening and 94% by midnight, the last of it through the small hours. Real ants dig faster
    /// still at first (half of a day's digging in its first hour, docs/ant-colony.md), which would leave most of
    /// the day with nothing happening.
    nonisolated static func share(after hours: Double) -> Double {
        let left = 1 - min(max(hours / 24, 0), 1)
        return 1 - left * left
    }

    /// The day a moment of the wall's clock belongs to (a day runs from six to six), as a number like 20261012;
    /// the moment that day began, in seconds since the reference date; and the hours since.
    nonisolated static func day(at wall: Double, calendar: Calendar = .current) -> (day: Int, six: Double, hours: Double) {
        let morning = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: wall - dawn * 3600))
        let parts = calendar.dateComponents([.year, .month, .day], from: morning), six = morning.timeIntervalSinceReferenceDate + dawn * 3600
        return ((parts.year ?? 0) * 10000 + (parts.month ?? 0) * 100 + (parts.day ?? 0), six, (wall - six) / 3600)
    }

    /// Which farm is on the tank and how long it has been going, by the wall clock. One of these is shared by
    /// every copy of the scene, each display and Settings' preview, and kept in the defaults, so that the farm
    /// goes on from where it was whatever builds a scene, at any Speed.
    ///
    /// A nest takes 24 hours divided by Speed. At Speed 1 a farm begins at six and only at six: from a fresh
    /// install it is exactly the day's wall-clock farm, and a nest finished early (Speed has been higher) stays
    /// finished, its ants about, until six. Above 1 the next farm begins as each ends. Moving Speed never moves
    /// the dig: as much is dug as was, and it goes on from there at the new pace.
    struct Cycle: Equatable {
        /// The farm: the day it began on, and its turn in that day, 0 for the one that begins at six and 1 up for
        /// those that follow as each ends. A day and a turn are a farm's seed.
        var day: Int, turn: Int
        /// The wall-clock moment, in seconds since the reference date, this farm would have begun at speed
        /// `paced`. Moving the Speed slider moves it, so that the nest stays as far dug as it is.
        var began: Double, paced: Double

        init(day: Int, turn: Int, began: Double, paced: Double) { (self.day, self.turn, self.began, self.paced) = (day, turn, began, paced) }

        /// The day's own farm, as far along as the wall clock has it, to go on at `speed`.
        init(at wall: Double, speed: Double, calendar: Calendar = .current) {
            let today = AntColony.day(at: wall, calendar: calendar)
            self.init(day: today.day, turn: 0, began: wall - today.hours * 3600 / max(speed, 1), paced: max(speed, 1))
        }

        /// Moves on to the wall-clock moment `wall`, given the slider's speed, and gives the hours the farm has
        /// been going, of its own 24 (more, for a finished nest waiting for six). A scene with a clock of its own
        /// (a test's, Settings' head start) is not `daily`: no farm of its is the day's, and its farms are told
        /// apart by their turn alone.
        mutating func hours(at wall: Double, speed slider: Double, daily: Bool = true, calendar: Calendar = .current) -> Double {
            let speed = max(slider, 1)
            if speed != paced { // as much is dug as was, a finished nest being finished; it goes on from there at the new speed
                began = wall - min(max(wall - began, 0) * paced, 86400) / speed
                paced = speed
            }
            let today = daily ? AntColony.day(at: wall, calendar: calendar) : nil
            if let today, speed == 1, today.day != day { (day, turn, began) = (today.day, 0, today.six) } // at six, the day's own farm
            var turns = 0
            while speed > 1, (wall - began) * speed >= 86400 { // above 1, on to the next farm as often as the clock says
                began += 86400 / speed
                let next = daily ? AntColony.day(at: began, calendar: calendar).day : day
                (day, turn, turns) = (next, daily && next != day ? 1 : turn + 1, turns + 1)
                if turns > 500, daily { self = Cycle(at: wall, speed: speed, calendar: calendar) } // away for weeks: the day's own farm, as far along as it is
            }
            return max(wall - began, 0) * speed / 3600
        }
    }

    /// The one cycle every copy of the scene follows, and what of it was last saved.
    private static var cycle: Cycle?, saved: Cycle?

    /// The shared cycle's farm at `wall`, and the hours it has been going: read from the defaults the first time
    /// (so a relaunch finds its place at any Speed: the farm, when it would have begun, and at what pace), and
    /// saved back whenever it moves on to another farm or the slider moves it.
    private static func moment(at wall: Double) -> (day: Int, turn: Int, hours: Double) {
        let speed = Self.speed.value, defaults = UserDefaults.standard
        if cycle == nil {
            if let farm = defaults.object(forKey: "antcolony.farm") as? Int, let began = defaults.object(forKey: "antcolony.began") as? Double {
                cycle = Cycle(day: farm / 100, turn: farm % 100, began: began, paced: defaults.object(forKey: "antcolony.paced") as? Double ?? max(speed, 1))
            } else { cycle = Cycle(at: wall, speed: speed) }
        }
        let hours = cycle!.hours(at: wall, speed: speed)
        if cycle != saved {
            saved = cycle
            defaults.set(cycle!.day * 100 + cycle!.turn, forKey: "antcolony.farm")
            defaults.set(cycle!.began, forKey: "antcolony.began")
            defaults.set(cycle!.paced, forKey: "antcolony.paced")
        }
        return (cycle!.day, cycle!.turn, hours)
    }

    /// What a farm on the screen was baked for: its day and turn, the size of its ants, and how many of them.
    private struct Key: Equatable, Sendable {
        var day: Int, turn: Int, size: Int, most: Int
    }

    /// A farm as it comes off the thread that baked it: the nest, its ants some minutes into their work, and the
    /// map and the spoil's heights as the shader reads them. (What the shader is told of each cell's surroundings
    /// follows a moment later, as it does all day: a fifth of a second for the largest tank, while the picture is
    /// still fading up.)
    private struct Made: Sendable {
        var key: Key, nest: Nest, colony: Colony, map: Data, heap: Data
    }

    /// Something made on another thread, handed to the scene's next frame.
    private final class Landing<Thing: Sendable>: Sendable {
        private let thing = Mutex<Thing?>(nil), ready = DispatchSemaphore(value: 0)
        func arrive(_ made: Thing) { thing.withLock { $0 = made }; ready.signal() }
        /// What has arrived, once. `waiting` holds the caller until it has: for the render tests, which draw their
        /// frames faster than a nest can be baked.
        func take(waiting: Bool) -> Thing? {
            if waiting { ready.wait(); ready.signal() }
            return thing.withLock { made in defer { made = nil }; return made }
        }
    }

    /// How the ants are drawn: against the gel each is a shape with the light behind it; on sand and in earth it
    /// is a red harvester lit from above, its far legs darker, with a shadow on the pane behind it. `gain` dims
    /// the dim sand's ants with their sand.
    private struct Style: Equatable {
        var lit: Bool, length: Double, gain: Double

        func tone(_ r: Double, _ g: Double, _ b: Double, _ by: Double = 1) -> NSColor {
            NSColor(srgbRed: min(r * by * gain / 255, 1), green: min(g * by * gain / 255, 1), blue: min(b * by * gain / 255, 1), alpha: 1)
        }
        var limb: NSColor { lit ? tone(150, 80, 40, 0.8) : tone(5, 9, 16) }
        var farLimb: NSColor { lit ? tone(150, 80, 40, 0.5) : tone(5, 9, 16) }
        /// A grain in its jaws or dropped on the spoil: a crumb of the gel, or of the sand.
        var grain: NSColor { lit ? tone(222, 212, 194) : tone(118, 172, 240) }
    }

    /// One ant's sprites: its body, the lengths of its legs (three to a leg for the largest ants, two for the
    /// others, whose feet are too small to show a bend) and four of its antennae, the grain it may carry and, on sand, its
    /// body's shadow. And how it stood when they were last placed, so that an ant standing still costs nothing.
    @MainActor private final class Figure {
        let node = SKNode(), body: SKSpriteNode, shadow: SKSpriteNode?, grain = SKSpriteNode(texture: AntColony.dot)
        let lines: [SKSpriteNode], joints: Int
        /// How wide each line is drawn, in points: a leg thinner than a pixel is drawn a pixel wide and that much
        /// fainter. Its width and its faintness are set once; only its place, turn and length change.
        let thick: [Double]
        var stood: (at: SIMD2<Double>, facing: SIMD2<Double>, turn: SIMD3<Double>, claws: [SIMD3<Double>])?

        init(_ style: Style, pixel: Double) {
            let leg = style.length < 30 ? [0.034, 0.022] : [0.034, 0.024, 0.016]
            let wide = ((0..<6).flatMap { _ in leg } + [0.020, 0.017, 0.020, 0.017]).map { $0 * style.length }
            (joints, thick) = (leg.count, wide.map { max($0, pixel) })
            lines = wide.map { _ in SKSpriteNode(texture: AntColony.line) }
            let side = AntColony.side(style.length)
            body = SKSpriteNode(texture: AntColony.body(style), size: CGSize(width: side, height: side))
            body.zPosition = 1
            shadow = style.lit ? SKSpriteNode(texture: AntColony.body(Style(lit: false, length: style.length, gain: 1)), size: body.size) : nil
            if let shadow {
                (shadow.alpha, shadow.zPosition) = (0.38, -1)
                node.addChild(shadow)
            }
            for (k, line) in lines.enumerated() {
                let near = k < 6 * joints ? k < 3 * joints : k < 6 * joints + 2 // the near side's go over the body, the far side's under it
                (line.color, line.colorBlendFactor, line.zPosition) = (near ? style.limb : style.farLimb, 1, near ? 2 : 0)
                (line.size, line.alpha) = (CGSize(width: 1, height: 2 * thick[k]), min(wide[k] / pixel, 1))
                node.addChild(line)
            }
            (grain.color, grain.colorBlendFactor, grain.zPosition) = (style.grain, 1, 3)
            grain.size = CGSize(width: 0.17 * style.length, height: 0.15 * style.length)
            node.addChild(body)
            node.addChild(grain)
        }
    }

    /// The side of the square a body is painted in, in points: 2.6 body lengths.
    private static func side(_ length: Double) -> Double { (2.6 * length).rounded(.up) }

    /// The body from the side, head to the right and feet down, its middle at the middle of its square: gaster,
    /// the two nodes of the waist, mesosoma, head and jaws (`Build`), carried nose up. Against the gel it is flat
    /// and dark; on sand each part is dark below, its own red, lighter above and glinting, with the gaster's
    /// bands and an eye. Painted once for each style.
    private static func body(_ style: Style) -> SKTexture {
        if let made = bodies.first(where: { $0.style == style }) { return made.texture }
        let side = side(style.length)
        let texture = paint(CGSize(width: side, height: side)) { context in
            context.translateBy(x: side / 2, y: side / 2)
            context.scaleBy(x: style.length, y: style.length)
            context.rotate(by: Build.pitch * .pi / 180)
            func blob(_ x: Double, _ y: Double, _ a: Double, _ b: Double, _ tilt: Double, _ colour: NSColor) {
                context.saveGState()
                context.translateBy(x: x, y: y)
                context.rotate(by: tilt * .pi / 180)
                context.setFillColor(colour.cgColor)
                context.fillEllipse(in: CGRect(x: -a, y: -b, width: 2 * a, height: 2 * b))
                context.restoreGState()
            }
            func part(_ x: Double, _ y: Double, _ a: Double, _ b: Double, _ tilt: Double, _ rgb: (Double, Double, Double)) {
                guard style.lit else { blob(x, y, a, b, tilt, style.tone(5, 9, 16)); return }
                blob(x, y, a, b, tilt, style.tone(rgb.0, rgb.1, rgb.2, 0.5))
                blob(x, y + 0.18 * b, 0.94 * a, 0.80 * b, tilt, style.tone(rgb.0, rgb.1, rgb.2, 0.82))
                blob(x + 0.04 * a, y + 0.44 * b, 0.70 * a, 0.44 * b, tilt, style.tone(rgb.0, rgb.1, rgb.2, 1.08))
                blob(x + 0.16 * a, y + 0.62 * b, 0.28 * a, 0.13 * b, tilt, style.tone(236, 196, 150).withAlphaComponent(0.5))
            }
            // (measured off a harvester ant in a toy farm: its mesosoma and head, and its darker gaster)
            let (red, dark) = ((150.0, 72.0, 30.0), (122.0, 54.0, 24.0))
            for node in Build.waist { part(node.x, node.y, node.r, node.r, 0, red) }
            part(Build.gaster.x, Build.gaster.y, Build.gaster.a, Build.gaster.b, Build.gaster.tilt, dark)
            part(Build.chest.x, Build.chest.y, Build.chest.a, Build.chest.b, Build.chest.tilt, red)
            part(Build.head.x, Build.head.y, Build.head.a, Build.head.b, Build.head.tilt, red)
            blob(Build.head.x + Build.head.a * 0.78, Build.head.y - Build.head.b * 0.75, 0.035, 0.022, -50, style.lit ? style.tone(122, 54, 24, 0.7) : style.tone(5, 9, 16))
            if style.lit {
                blob(Build.head.x + 0.02, Build.head.y + 0.012, 0.02, 0.017, 0, style.tone(122, 54, 24, 0.35))
                context.setStrokeColor(style.tone(122, 54, 24, 0.6).cgColor)
                context.setLineWidth(0.012)
                for f in [-0.25, 0.22] {
                    context.move(to: CGPoint(x: Build.gaster.x + f * Build.gaster.a, y: Build.gaster.y + 0.85 * Build.gaster.b))
                    context.addLine(to: CGPoint(x: Build.gaster.x + (f - 0.05) * Build.gaster.a, y: Build.gaster.y - 0.85 * Build.gaster.b))
                }
                context.strokePath()
            }
        }
        bodies.append((style, texture))
        return texture
    }
    private static var bodies: [(style: Style, texture: SKTexture)] = []

    /// A length of leg: a band half the texture's height, so that a sprite twice as high as the leg is wide has
    /// soft sides (a sprite's own edge is not smoothed).
    private static let line: SKTexture = paint(CGSize(width: 2, height: 4)) { context in
        context.setFillColor(.white)
        context.fill(CGRect(x: 0, y: 1, width: 2, height: 2))
    }
    private static let dot: SKTexture = paint(CGSize(width: 8, height: 8)) { context in
        context.setFillColor(.white)
        context.fillEllipse(in: CGRect(x: 0.5, y: 0.5, width: 7, height: 7))
    }
    private static let grain: SKTexture = {
        let tile = SKTexture(data: Nest.grain(), size: CGSize(width: 256, height: 256))
        tile.filteringMode = .linear
        return tile
    }()

    private let medium = SKSpriteNode(), swarm = SKNode()
    /// The share dug; how many times that share a cell's rank is from it, for the shader to open a cell over the
    /// digging of the twenty before it; and the whole picture's fade up when a farm lands.
    private let dug = SKUniform(name: "u_dug", float: 0), fade = SKUniform(name: "u_fade", float: 1), show = SKUniform(name: "u_show", float: 0)
    /// The tank in cells and the row of its ground line, for the shader.
    private let cells = SKUniform(name: "u_cells", vectorFloat3: [1, 1, 0])
    /// The nest's map, the spoil's heights and the surroundings: a single texel each until a nest lands, by when
    /// nothing is shown.
    private let map = SKUniform(name: "u_map", texture: SKTexture(data: Data([255, 255, 255, 255]), size: CGSize(width: 1, height: 1)))
    private let heap = SKUniform(name: "u_heap", texture: SKTexture(data: Data([0, 0, 255, 255]), size: CGSize(width: 1, height: 1)))
    private let near = SKUniform(name: "u_near", texture: nowhere)
    /// The surroundings of a cell deep in the medium, as one texel: what the shader has until a nest's own arrive.
    private static let nowhere = SKTexture(data: Data([255, 255, 128, 255]), size: CGSize(width: 1, height: 1))
    /// A cell and a pixel in points, and each look's shader, made when first wanted.
    private var cell = 2.0, pixel = 0.5, shaders: [Int: SKShader] = [:]
    /// The farm on the screen, and its ants' sprites, in the style they were made in, and the grains they have dropped.
    private var key: Key?, nest: Nest?, colony: Colony?, figures: [Figure] = [], crumbs: [SKSpriteNode] = [], style: Style?
    /// A farm being baked; the surroundings being worked out for a later share of the digging; and the share the
    /// shader has them for, in 4000ths.
    private var baking: (key: Key, landing: Landing<Made>)?, shading: (quantum: Int, landing: Landing<Data>)?, shaded = -1
    /// When the ants on the screen were last set going: by the wall's clock, in the farm's own hours, and at what
    /// speed; the sixtieths of a second they have been stepped through since; and when the picture last faded up.
    private var since = (wall: 0.0, hours: 0.0, speed: 1.0), ticked = 0, shown = 0.0
    /// What the tests and the pictures of it ask for as a scene is built: the farm of another day
    /// (`antcolony.day`, a number like 20261012) and the hours it has been going at the scene's first frame
    /// (`antcolony.hour`). With either the scene keeps a cycle of its own, begun at its first frame by the frame's
    /// clock, and saves nothing.
    private var asked: (day: Int?, hour: Double?) = (nil, nil), own: Cycle?

    override func sceneDidLoad() {
        pixel = 1 / (NSScreen.screens.first { $0.frame.size == size }?.backingScaleFactor ?? 2)
        medium.anchorPoint = CGPoint(x: 0, y: 1)
        medium.position = CGPoint(x: 0, y: size.height)
        medium.isHidden = true
        addChild(medium)
        swarm.zPosition = 1
        addChild(swarm)
        backgroundColor = .black

        let defaults = UserDefaults.standard
        asked = ((defaults.object(forKey: "antcolony.day") as? Double).map { Int($0) }, defaults.object(forKey: "antcolony.hour") as? Double)
    }

    /// The shader for a look, by its place in the Look menu.
    private func shader(_ look: Int) -> SKShader {
        if let made = shaders[look] { return made }
        let made = SKShader(source: shaderCommon + Self.source(look), uniforms: [
            cells, SKUniform(name: "u_bl", float: Float(Self.antCells)), SKUniform(name: "u_px", float: Float(size.width / pixel)),
            SKUniform(name: "u_grain", texture: Self.grain), map, heap, near, dug, fade, show])
        shaders[look] = made
        return made
    }

    /// Starts baking a farm, with `share` of its digging done, off the main thread: the nest (70 ms for a 14-inch
    /// display at the middle size), its ants three minutes into their work, and the textures. The map has eleven
    /// cells to an ant's length across the display, and as many rows as cover it.
    private func bake(_ key: Key, share: Double) {
        let landing = Landing<Made>(), cols = max(Int((size.width / (Self.lengths[key.size] / Self.antCells)).rounded()), 8)
        let rows = max(Int((size.height / (size.width / Double(cols))).rounded(.up)), 8), seed = UInt64(key.day * 100 + key.turn)
        baking = (key, landing)
        Task.detached(priority: .userInitiated) {
            let nest = Nest(seed: seed, cols: cols, rows: rows, bodyLength: Self.antCells)
            var colony = Colony(nest: nest, most: key.most, seed: seed, share: share)
            colony.fastForward(180)
            landing.arrive(Made(key: key, nest: nest, colony: colony, map: nest.bytes(), heap: nest.heights()))
        }
    }

    /// Where a point of the tank, in cells from its top left, is in the scene.
    private func point(_ at: SIMD2<Double>) -> CGPoint { CGPoint(x: at.x * cell, y: size.height - at.y * cell) }

    override func update(_ currentTime: TimeInterval) {
        // The wall's clock, by way of the frame's own time: the two run together, but the tests' frames come
        // faster than real ones and their pictures have to be of their own moments.
        let wall = currentTime + Date.timeIntervalSinceReferenceDate - ProcessInfo.processInfo.systemUptime
        let speed = max(Self.speed.value, 1), size = min(max(Int(Self.antSize.value), 0), 2), look = Int(Self.look.value)
        if asked.day != nil || asked.hour != nil, own == nil {
            let today = Self.day(at: wall)
            own = Cycle(day: asked.day ?? today.day, turn: 0, began: currentTime - (asked.hour ?? today.hours) * 3600 / speed, paced: speed)
        }
        var now = (day: 0, turn: 0, hours: 0.0)
        if own != nil {
            let hours = own!.hours(at: currentTime, speed: speed, daily: false)
            now = (own!.day, own!.turn, hours)
        } else { now = Self.moment(at: wall) }
        let share = Self.share(after: now.hours)

        // The farm for this moment: baked when the scene is made, when a farm gives way to the next, and when
        // Settings asks for another size of ant or another number of them (an ant, grown, to every 130 square ant
        // lengths of tank, times Ants, and ninety at the most).
        // ponytail: a finished farm gives way to the next through black, in under half a second (`u_show`). A
        // crossfade needs both farms' textures at once; add it if the cut is ever noticed.
        let room = Double(self.size.width * self.size.height) / (Self.lengths[size] * Self.lengths[size])
        let wanted = Key(day: now.day, turn: now.turn, size: size, most: min(max(Int((room / 128 * Self.crowd.value).rounded()), 4), 90))
        if key != wanted, baking == nil { bake(wanted, share: share) }
        if let job = baking, let made = job.landing.take(waiting: view == nil) {
            let extent = CGSize(width: made.nest.cols, height: made.nest.rows)
            map.textureValue = SKTexture(data: made.map, size: extent)
            heap.textureValue = SKTexture(data: made.heap, size: CGSize(width: made.nest.cols, height: Nest.levels + 1))
            near.textureValue = Self.nowhere
            fade.floatValue = Float(made.nest.dug) / 10
            cells.vectorFloat3Value = [Float(made.nest.cols), Float(made.nest.rows), Float(made.nest.ground)]
            cell = Double(self.size.width) / Double(made.nest.cols)
            medium.size = CGSize(width: self.size.width, height: Double(made.nest.rows) * cell)
            // (the same nest with another number of ants goes on as it was; another nest fades up)
            if key?.day != made.key.day || key?.turn != made.key.turn || key?.size != made.key.size { shown = wall }
            (key, nest, colony, baking, shading, shaded) = (made.key, made.nest, made.colony, nil, nil, -1)
            (since, ticked) = ((wall, now.hours, speed), 0)
        }
        // (while the next farm is baked, the one on the screen stays as it was)
        guard let nest, var colony, let key, key.day == wanted.day, key.turn == wanted.turn else { return }
        defer { self.colony = colony }

        // The ants, in sixtieths of a second counted from when they were set going, each with the share dug at
        // its own moment, so that they are where they are whatever the frame rate; set going again from here
        // when Speed changes the pace. After a gap (the display asleep, the wallpaper covered) they are moved on
        // without being watched, by two minutes at the most.
        if speed != since.speed || abs(now.hours - since.hours - (wall - since.wall) * speed / 3600) > 0.01 { (since, ticked) = ((wall, now.hours, speed), 0) }
        let due = Int(((wall - since.wall) * 60).rounded())
        if due - ticked > 30 {
            colony.fastForward(min(Double(due - ticked) / 60, 120), share: share)
        } else if due > ticked {
            for tick in (ticked + 1)...due {
                let hours = since.hours + Double(tick) * speed / 216_000
                colony.step(share: Self.share(after: hours), soon: Self.share(after: hours + speed / 60))
            }
        }
        ticked = max(due, ticked)

        // What the shader is told of each cell's surroundings goes a 4000th of the digging at a time, worked out
        // off the main thread (13 ms).
        let quantum = Int(share * 4000)
        if let job = shading, let data = job.landing.take(waiting: view == nil && job.quantum == quantum) {
            near.textureValue = SKTexture(data: data, size: CGSize(width: nest.cols, height: nest.rows))
            (shaded, shading) = (job.quantum, nil)
        }
        if shaded != quantum, shading == nil {
            let landing = Landing<Data>()
            shading = (quantum, landing)
            Task.detached(priority: .utility) { landing.arrive(nest.surroundings(at: Double(quantum) / 4000)) }
            if view == nil, let data = landing.take(waiting: true) { // (the tests' pictures are of their own moments)
                near.textureValue = SKTexture(data: data, size: CGSize(width: nest.cols, height: nest.rows))
                (shaded, shading) = (quantum, nil)
            }
        }

        // The look: its shader, and the ants to suit it (shapes against the gel, lit in sand and in earth, and
        // dimmed with the dim sand).
        let pick = min(max(look, 0), 4)
        if medium.shader !== shader(pick) { medium.shader = shader(pick) }
        medium.isHidden = false
        dug.floatValue = Float(share)
        show.floatValue = Float(simd_smoothstep(0, 1, (wall - shown) / 0.4 + (view == nil ? 1 : 0)))
        swarm.alpha = CGFloat(show.floatValue)

        // The ants and the grains they have dropped, made afresh when the look or the size changes.
        let wantedStyle = Style(lit: pick >= 2, length: Self.lengths[key.size], gain: pick == 2 ? 0.86 : 1)
        if style != wantedStyle {
            swarm.removeAllChildren()
            (figures, crumbs, style) = ([], [], wantedStyle)
        }
        while figures.count < colony.ants.count {
            figures.append(Figure(wantedStyle, pixel: pixel))
            swarm.addChild(figures.last!.node)
        }
        for (n, figure) in figures.enumerated() {
            figure.node.isHidden = n >= colony.ants.count
            if n < colony.ants.count { pose(figure, as: colony.ants[n], bodyLength: nest.bodyLength, length: wantedStyle.length) }
        }
        while crumbs.count < colony.grains.count {
            let crumb = SKSpriteNode(texture: Self.dot, color: wantedStyle.grain, size: CGSize(width: 0.17 * wantedStyle.length, height: 0.15 * wantedStyle.length))
            crumb.colorBlendFactor = 1
            crumbs.append(crumb)
            swarm.addChild(crumb)
        }
        for (n, crumb) in crumbs.enumerated() {
            crumb.isHidden = n >= colony.grains.count
            guard n < colony.grains.count else { continue }
            let grain = colony.grains[n]
            crumb.position = point(SIMD2(grain.x, Double(nest.ground) - nest.surface(grain.x, at: share) - 0.07 * nest.bodyLength))
            crumb.alpha = CGFloat(min((45 - (colony.time - grain.at)) / 5, 1)) // it lies 45 seconds, and is then part of the heap
        }
    }

    /// Puts an ant's sprites where it is: the body turned the way it faces, shortened as it turns about and turned
    /// over as it rolls, its nose dipped as it digs; each length of leg and antenna between its joints; and its
    /// shadow, where it has one, down and to the right on the pane behind.
    private func pose(_ figure: Figure, as ant: Ant, bodyLength: Double, length: Double) {
        let forward = CGVector(dx: ant.forward.x, dy: -ant.forward.y), up = CGVector(dx: ant.up.x, dy: -ant.up.y)
        let left: CGFloat = forward.dx * up.dy - forward.dy * up.dx >= 0 ? 1 : -1 // whether up is to the left of the way it faces
        figure.body.position = point(ant.position)
        figure.body.zRotation = atan2(forward.dy, forward.dx) - left * 3 * ant.nod
        // (end on it is a third as long as it is from the side; rolled over it is as thick seen from above)
        figure.body.xScale = max(cos(ant.yaw), 0.3)
        figure.body.yScale = left * (ant.flat < 0 ? -1 : 1) * max(abs(ant.flat), 0.85)
        if let shadow = figure.shadow {
            shadow.position = CGPoint(x: figure.body.position.x + 0.10 * length, y: figure.body.position.y - 0.18 * length)
            (shadow.zRotation, shadow.xScale, shadow.yScale) = (figure.body.zRotation, figure.body.xScale, figure.body.yScale)
        }
        figure.grain.isHidden = !ant.carrying
        figure.grain.position = point(ant.mouth(bodyLength: bodyLength))

        // Its legs, unless it stands as it did; its antennae always, which are never still.
        let limbs = ant.limbs(bodyLength: bodyLength), stance = (ant.position, ant.forward, SIMD3(ant.flat, ant.yaw, ant.nod), ant.claws)
        let still = figure.stood.map { $0.at == stance.0 && $0.facing == stance.1 && $0.turn == stance.2 && $0.claws == stance.3 } ?? false
        figure.stood = stance
        var next = 0
        func draw(_ joints: [SIMD2<Double>]) {
            for k in 0..<joints.count - 1 where next < figure.lines.count {
                let (a, b) = (point(joints[k]), point(joints[k + 1])), line = figure.lines[next]
                line.position = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                line.zRotation = atan2(b.y - a.y, b.x - a.x)
                line.xScale = hypot(b.x - a.x, b.y - a.y) + figure.thick[next]
                next += 1
            }
        }
        if !still { for leg in limbs.legs { draw(figure.joints == 3 ? leg : [leg[0], leg[1], leg[3]]) } }
        next = 6 * figure.joints
        for antenna in limbs.antennae { draw(antenna) }
    }

    /// The shader for a look. All begin the same way, with what is dug and what is buried.
    ///
    /// A texture a shader reads is smoothed whatever its filtering is set to, and a rank smoothed between a dug
    /// cell and one never dug is a rank nothing has. So the map is read at the centres of the four cells round the
    /// pixel, each is compared with the share dug on its own (open by the time an ant may stand in it, and opening
    /// over the digging of the twenty cells before that, so a face creeps and never jumps a cell), and only then
    /// are they mixed; the edge is a pixel and a half soft by the mix's own slope. The spoil's top is its height
    /// read from `u_heap`. What cannot be had from a read or two (how near a wall is, and which way it faces) is
    /// in `u_near`. In sand the place the map is read at is the middle of the grain the pixel is in, so that a
    /// grain is there whole or not at all, and an edge is a crumbling one; in earth it is pushed about by the
    /// soil's own grain, half a grain deep.
    ///
    /// Each look is its own source, the two gels and the two sands as well: a variant behind a uniform can move
    /// pixels where it never runs (Sources/CLAUDE.md).
    private static func source(_ look: Int) -> String {
        let place = [2: grains, 3: grains, 4: "    vec2 at = cell + 0.035 * u_bl * n.rg * step(ground + 0.5, cell.y);"][look] ?? "    vec2 at = cell;"
        let picture = [gelLook, brightGelLook,
                       sandLook(sand: "vec3(0.860, 0.790, 0.680)", pane: "vec3(0.557, 0.502, 0.431)", tone: "0.66"),
                       sandLook(sand: "vec3(0.905, 0.868, 0.800)", pane: "vec3(0.560, 0.562, 0.560)", tone: "1.12"), earthLook][look]
        return """
        float sq(float x) { return x * x; }

        void main() {
            // This pixel in cells from the tank's top left; pixels to a cell, and to one of the pixels this was
            // drawn for (an ant 44 of them long).
            vec2 cell = vec2(v_tex_coord.x, 1.0 - v_tex_coord.y) * u_cells.xy;
            float ground = u_cells.z, ppc = u_px / u_cells.x, px = u_bl * ppc / 44.0;

            // Grain: a tile of noise, a texel of it to a 44th of an ant, and the same tile far larger for slow blots.
            vec2 g = cell / u_bl * 44.0;
            vec4 n = (texture2D(u_grain, fract(g / 256.0)) - 0.5) * 6.0;
            vec4 slow = (texture2D(u_grain, fract(g / 6144.0)) - 0.5) * 6.0;
            vec4 h = hash42(floor(g));

        \(place)
            // Dug: the four cells round that place (none of them above the ground line), each open or not.
            vec2 p = vec2(at.x, max(at.y, ground + 0.5)) - 0.5, base = floor(p), f = p - base;
            vec4 open;
            for (int k = 0; k < 4; k++) {
                vec2 corner = base + vec2(mod(float(k), 2.0), floor(float(k) / 2.0)) + 0.5;
                vec4 t = texture2D(u_map, vec2(corner.x, u_cells.y - corner.y) / u_cells.xy);
                float rank = (floor(t.r * 255.0 + 0.5) * 256.0 + floor(t.g * 255.0 + 0.5)) / 32767.5;
                open[k] = clamp((rank - u_dug) * u_fade - 1.0, -1.0, 1.0);
            }
            float above = step(at.y, ground);
            float s = mix(mix(open[0], open[1], f.x), mix(open[2], open[3], f.x), f.y);
            vec2 slope = vec2(mix(open[1] - open[0], open[3] - open[2], f.y), mix(open[2] - open[0], open[3] - open[1], f.x)) / ppc;
            float solid = clamp(0.5 + s / max(length(slope), 0.000001) / 1.5, 0.0, 1.0);
            // Buried: under the spoil's top at this column, at this share of the digging; and what of that was
            // carried up, not poured.
            vec2 level = vec2(at.x / u_cells.x, (u_dug * 256.0 + 0.5) / 257.0);
            vec4 h0 = texture2D(u_heap, level), h1 = texture2D(u_heap, level + vec2(1.0 / u_px, 0.0)), h2 = texture2D(u_heap, vec2(level.x, 0.5 / 257.0));
            vec3 top = (vec3(h0.r, h1.r, h2.r) * 65280.0 + vec3(h0.g, h1.g, h2.g) * 255.0) / 65535.0 * 64.0;
            float buried = clamp(0.5 + (top.x - (ground - at.y)) * ppc / sqrt(1.0 + sq((top.y - top.x) * ppc)) / 1.5, 0.0, 1.0);
            float spoil = above * clamp((ground - at.y - top.z) * ppc, 0.0, 1.0);
            solid = mix(solid, buried, above);

            vec4 q = texture2D(u_near, vec2(cell.x, u_cells.y - cell.y) / u_cells.xy);
            float close = q.r, wide = q.g, lit = q.b * 2.0 - 1.0, hug = q.a;
            float x = v_tex_coord.x, down = 1.0 - v_tex_coord.y;

        \(picture)
            colour *= 1.0 - 0.38 * (sq(x - 0.5) + sq(down - 0.5));
            gl_FragColor = vec4(clamp(colour, 0.0, 1.0) * u_show, 1.0);
        }
        """
    }

    /// The gel as Dave chose it from the mock-ups, after the toy's gel tanks: a deep blue slab lit by lamps in its
    /// base, glowing brighter toward them; a tunnel is a frosted, paler tube with light gathered into a bright
    /// line at its edge, a halo in the gel beside it, a sheen and beads along its wet wall; small bubbles hang in
    /// the gel; what is dug lies on top as pale crumbs; and the air above is dark but for the glow that leaks up,
    /// against which an ant on the heap is a shape.
    private static let gelLook = """
            float lamps = exp(-sq((x - 0.13) / 0.10)) + exp(-sq((x - 0.37) / 0.10)) + exp(-sq((x - 0.62) / 0.10)) + exp(-sq((x - 0.87) / 0.10));
            float d = clamp((cell.y - ground) / (u_cells.y - ground), 0.0, 1.0);
            float glow = (0.40 + 0.46 * pow(d, 1.5) + 0.78 * lamps * pow(d, 2.4)) * (1.0 + 0.05 * slow.b + 0.03 * slow.r);

            // The gel, with the light gathered beside a tunnel, and its bubbles: one to a square in six, a dark ring
            // with a glint on the lamps' side.
            vec3 body = vec3(0.035, 0.212, 0.808) * glow + vec3(0.235, 0.471, 0.980) * 0.09 * (1.0 - d);
            body += vec3(0.275, 0.667, 1.0) * 0.34 * pow(clamp((1.0 - wide) * 2.0, 0.0, 1.0), 1.6) * (0.5 + 0.7 * glow);
            float square = 0.9 * u_bl;
            vec2 box = floor(cell / square);
            vec4 b = hash42(box + 7.0), b2 = hash42(box + 91.0);
            float radius = u_bl * mix(mix(0.018, 0.05, b2.y), mix(0.05, 0.11, b2.y), step(0.85, b2.x)) * ppc;
            vec2 off = (cell - (box + 0.15 + 0.7 * b.xy) * square) * ppc;
            float has = step(b.z, 0.17) * step(ground + 0.3 * u_bl, cell.y);
            float ring = exp(-sq((length(off) - radius) / (0.8 * px))) * min(1.0, radius / (2.0 * px)) * has;
            float glint = exp(-sq(length(off + vec2(0.3, -0.45) * radius) / max(0.45 * radius, 0.7 * px))) * has;
            body = body * (1.0 - 0.5 * ring) + vec3(0.745, 0.922, 1.0) * 0.55 * glint * (0.4 + glow);

            // A tunnel: frosted, paler toward its walls, with the bright line at its edge, a sheen and beads.
            float frost = 1.0 + 0.10 * n.r + 0.045 * n.b + 0.04 * n.a, by = clamp(wide * 2.0, 0.0, 1.0);
            vec3 tube = (vec3(0.149, 0.439, 0.925) * glow * (0.80 + 0.34 * clamp(wide * 2.4, 0.0, 1.0)) + 0.04) * frost;
            float sparks = step(0.990 - 0.05 * by * by, h.x);
            float sheen = clamp(1.0 - abs(wide - 0.30) / 0.14, 0.0, 1.0) * sq(clamp(0.5 + 0.6 * n.b, 0.0, 1.0)) * (0.65 + 0.35 * lit);
            float rim = pow(clamp(1.0 - abs(close - 0.42) / 0.30, 0.0, 1.0), 1.5);
            float beads = clamp(n.b - 0.7, 0.0, 1.6) * pow(by, 1.5);
            tube += vec3(0.690, 0.945, 0.984) * (0.50 * rim + 0.30 * sheen + 0.32 * sparks + 0.42 * beads) * (0.45 + 0.75 * glow);

            // Above the ground: the crumbs, and the dark air with the glow that hugs the heap.
            vec3 crumbs = vec3(0.463, 0.675, 0.941) * (0.36 + 0.07 * n.b + 0.05 * n.a + 0.22 * step(0.9965, h.y) + 0.30 * clamp((1.0 - close) * 2.0, 0.0, 1.0)) * (0.8 + 0.5 * lamps);
            float height = clamp((ground - cell.y) / (3.0 * u_bl), 0.0, 4.0);
            vec3 air = vec3(0.063, 0.133, 0.337) * exp(-height * 1.6) * (0.55 + 0.6 * lamps) + vec3(0.220, 0.463, 0.910) * 0.75 * pow(hug, 1.15) * (0.7 + 0.5 * lamps) + vec3(0.008, 0.012, 0.031);

            vec3 colour = mix(mix(tube, air, above), mix(body, crumbs, above), solid) * 0.85;
            colour += 0.010 * exp(-sq((x - 0.30 - 0.38 * down) / 0.06)) * vec3(0.784, 0.882, 1.0); // a reflection in the glass
    """

    /// The gel nearer its photograph (docs/ant-colony.md, photograph 6), and brighter than the mock-ups were: a
    /// bloom of faint rays over each lamp, and tubes that are the gel's own blue a little paler, with bubbles
    /// frothing at their walls.
    private static let brightGelLook = """
            // The lamps in the base: their light through the gel, and the bloom over each, a hot core with rays.
            float d = clamp((cell.y - ground) / (u_cells.y - ground), 0.0, 1.0), lamps = 0.0, cores = 0.0, bloom = 0.0;
            for (int k = 0; k < 4; k++) {
                float across = x - 0.13 - 0.2467 * float(k), slant = across / (1.12 - d);
                float lamp = exp(-sq(across / 0.10)), core = exp(-sq(across / 0.040));
                float rays = 0.88 + 0.24 * (0.5 + 0.5 * sin(slant * 70.0 + 4.0 * sin(slant * 17.0 + float(k))));
                lamps += lamp;
                cores += core;
                bloom += (0.70 * lamp * pow(d, 2.2) + 1.1 * core * pow(d, 4.5)) * rays;
            }
            float glow = (0.46 + 0.48 * pow(d, 1.5) + 0.60 * lamps * pow(d, 2.4)) * (1.0 + 0.05 * slow.b + 0.03 * slow.r);

            // The gel, bluer and brighter in the bloom, with the light gathered beside a tunnel, and its bubbles:
            // one to a square in four, a dark ring with a glint on the lamps' side.
            vec3 body = vec3(0.035, 0.212, 0.808) * glow + vec3(0.235, 0.471, 0.980) * 0.09 * (1.0 - d) + vec3(0.10, 0.58, 1.0) * bloom + vec3(0.80, 0.95, 1.0) * 0.9 * cores * pow(d, 9.0);
            body += vec3(0.275, 0.667, 1.0) * 0.34 * pow(clamp((1.0 - wide) * 2.0, 0.0, 1.0), 1.6) * (0.5 + 0.7 * glow);
            float square = 0.9 * u_bl;
            vec2 box = floor(cell / square);
            vec4 b = hash42(box + 7.0), b2 = hash42(box + 91.0);
            float radius = u_bl * mix(mix(0.018, 0.05, b2.y), mix(0.05, 0.11, b2.y), step(0.85, b2.x)) * ppc;
            vec2 off = (cell - (box + 0.15 + 0.7 * b.xy) * square) * ppc;
            float has = step(b.z, 0.25) * step(ground + 0.3 * u_bl, cell.y);
            float ring = exp(-sq((length(off) - radius) / (0.8 * px))) * min(1.0, radius / (2.0 * px)) * has;
            float glint = exp(-sq(length(off + vec2(0.3, -0.45) * radius) / max(0.45 * radius, 0.7 * px))) * has;
            body = body * (1.0 - 0.5 * ring) + vec3(0.745, 0.922, 1.0) * 0.55 * glint * (0.4 + glow);

            // A tunnel is a tube of air in glass: the gel behind it shows through, a little paler; its wall is
            // torn into bubbles that catch the light, larger ones at the wall and a fine froth either side of it,
            // with a line of light at the very rim and a sheen along the tube.
            float by = clamp(wide * 2.0, 0.0, 1.0), wet = 0.45 + 0.75 * glow + 0.6 * bloom;
            vec3 tube = (body * 1.04 + vec3(0.06, 0.17, 0.36) * (0.25 + 0.5 * glow)) * (1.0 + 0.03 * n.r + 0.05 * n.b);
            vec2 big = cell / (0.15 * u_bl), small = cell / (0.08 * u_bl);
            vec4 b4 = hash42(floor(big) + 5.0), s4 = hash42(floor(small) + 9.0);
            float span = length(fract(big) - 0.25 - 0.5 * b4.xy), reach = 0.16 + 0.14 * b4.w;
            float blister = (exp(-sq((span - reach) / 0.045)) * 0.7 + exp(-sq(length(fract(big) - 0.25 - 0.5 * b4.xy + vec2(0.3, -0.4) * reach) / 0.07))) * step(b4.z, 0.62);
            float fine = max(0.0, 1.0 - length(fract(small) - 0.25 - 0.5 * s4.xy) * 3.0) * step(s4.z, 0.8);
            float nearby = clamp(1.0 - abs(close - 0.40) / 0.34, 0.0, 1.0);
            float froth = nearby * (0.9 * blister + 0.9 * fine), inside = 0.5 * blister * step(b4.w, 0.3) + 0.3 * fine * step(s4.w, 0.2);
            float sparks = step(0.992 - 0.04 * by * by, h.x);
            float sheen = clamp(1.0 - abs(wide - 0.30) / 0.14, 0.0, 1.0) * sq(clamp(0.5 + 0.6 * n.b, 0.0, 1.0)) * (0.65 + 0.35 * lit);
            float rim = pow(clamp(1.0 - abs(close - 0.42) / 0.30, 0.0, 1.0), 1.5);
            tube += vec3(0.72, 0.95, 1.0) * (0.30 * rim + 0.30 * sheen + 0.30 * sparks + 1.25 * froth + inside) * wet;
            body += vec3(0.72, 0.95, 1.0) * 0.8 * froth * wet;
            float bubble = fine;

            // Above the ground: the crumbs, and the dark air with the glow that hugs the heap.
            vec3 crumbs = vec3(0.463, 0.675, 0.941) * (0.36 + 0.07 * n.b + 0.05 * n.a + 0.22 * step(0.9965, h.y) + 0.30 * clamp((1.0 - close) * 2.0, 0.0, 1.0) + 0.5 * bubble * step(s4.w, 0.5)) * (0.8 + 0.5 * lamps);
            float height = clamp((ground - cell.y) / (3.0 * u_bl), 0.0, 4.0);
            vec3 air = vec3(0.063, 0.133, 0.337) * exp(-height * 1.6) * (0.55 + 0.6 * lamps) + vec3(0.220, 0.463, 0.910) * 0.75 * pow(hug, 1.15) * (0.7 + 0.5 * lamps) + vec3(0.008, 0.012, 0.031);

            vec3 colour = mix(mix(tube, air, above), mix(body, crumbs, above), solid) * 0.85;
            colour += 0.010 * exp(-sq((x - 0.30 - 0.38 * down) / 0.06)) * vec3(0.784, 0.882, 1.0); // a reflection in the glass
    """

    /// The sand's grains: a tenth of an ant across, scattered one to a square with no lattice to them (a lattice
    /// shows as a weave when the picture is drawn at half size). This finds the grain a pixel is in, the nearest
    /// of the nine squares round it, which is where the map is then read; and the next nearest, for how big the
    /// grain can be without running into it.
    private static let grains = """
            vec2 gp = cell / (0.10 * u_bl), middle = gp, next = gp;
            float away = 9.0, second = 9.0;
            vec4 mine = vec4(0.0);
            for (int k = 0; k < 9; k++) {
                vec2 square = floor(gp) + vec2(mod(float(k), 3.0), floor(float(k) / 3.0)) - 1.0;
                vec4 r = hash42(square + 17.0);
                vec2 c = square + 0.06 + 0.88 * r.xy;
                float d = length(gp - c);
                if (d < away) { second = away; next = middle; away = d; middle = c; mine = r; }
                else if (d < second) { second = d; next = c; }
            }
            vec2 at = middle * 0.10 * u_bl;
    """

    /// Sand between two panes an ant's length apart, lit by one lamp up and to the left: grains lit from the
    /// lamp's side, a few of them dark and a few glinting; a tunnel is a trough, its wall curving back from the
    /// front pane to the back one, dark under its upper lip and lit on its floor, and in its middle the back pane
    /// shows with the lip's shadow across it and loose grains lying on it, most of them along the floors. `sand`
    /// and `pane` are the colours of a grain and of the pane behind, and `tone` how bright the whole is: the
    /// mock-ups' warm sand at two thirds, or the toy's white sand as photographed (photograph 1).
    private static func sandLook(sand: String, pane: String, tone: String) -> String {
        """
            // A grain: a bead as big as its neighbour lets it be, brighter on the lamp's side, a few of them dark
            // and a few glinting; and between the beads the shadowed ones behind.
            vec3 sand = \(sand) * (1.0 - clamp(slow.b - 0.6, 0.0, 2.0) * vec3(0.0, 0.018, 0.045));
            vec4 more = hash42(floor(middle) + 53.0);
            float size = clamp(0.49 * length(middle - next), 0.24, 0.56), bead = clamp((size - away) * 0.10 * u_bl * ppc / 1.3 + 0.5, 0.0, 1.0);
            float lamp = dot((gp - middle) / size, vec2(-0.5, -0.86));
            float shade = (0.90 + 0.11 * mine.w + 0.12 * lamp) * (1.0 + 0.035 * n.b + 0.03 * slow.r) * (1.0 - 0.30 * step(more.x, 0.03));
            vec3 grain = sand * shade + 0.30 * step(0.955, more.y) * clamp(1.0 - 3.0 * length((gp - middle) / size - vec2(-0.3, -0.4)), 0.0, 1.0);
            vec3 between = sand * (0.74 + 0.04 * n.b);
            float edge = clamp((1.0 - close) * 2.0, 0.0, 1.0); // the sand's last grains before a tunnel
            grain *= 1.0 - 0.16 * edge * clamp(-lit, 0.0, 1.0) + 0.08 * edge * clamp(lit, 0.0, 1.0);

            // The trough: the wall as it curves back, then the back pane and the room behind it, with the upper
            // lip's shadow across it; and the grains left lying, most of them along the floors.
            float depth = clamp((0.5 - wide) / 0.40, 0.0, 1.0);
            vec3 wall = sand * (0.74 + 0.26 * lit) * (1.0 - 0.50 * depth) * (0.80 + 0.20 * bead) * (1.0 + 0.05 * n.r);
            float lip = texture2D(u_near, vec2(cell.x - 0.20 * u_bl, u_cells.y - cell.y + 0.36 * u_bl) / u_cells.xy).r;
            vec3 room = \(pane) * (1.0 + 0.06 * slow.b + 0.02 * n.b) * (1.05 - 0.25 * down);
            vec3 hollow = mix(wall, room * (1.0 - 0.38 * lip), pow(depth, 1.5));
            float floors = clamp(wide * 2.4, 0.0, 1.0) * (0.35 + 0.65 * clamp(lit, 0.0, 1.0));
            float loose = step(more.z, 0.03 + 0.55 * sq(floors)) * bead * (1.0 - above);
            hollow = mix(hollow, grain * 0.93, loose);
            // The air above the sand: the same pane, dimmer toward the lid.
            hollow = mix(hollow, room * (1.0 - 0.45 * clamp((ground - cell.y) / ground, 0.0, 1.0)), step(cell.y, ground) * (1.0 - loose));

            // A grain that is there shows as its bead; round the bead, the shadowed sand behind it, or at an edge
            // the tunnel.
            vec3 face = mix(mix(hollow, between, smoothstep(0.35, 0.75, close)), grain, bead);
            vec3 colour = mix(hollow, face, solid) * (1.12 - 0.42 * length(vec2((x - 0.22) * 1.1, down + 0.05))) * \(tone);
            colour += 0.014 * (exp(-sq((x - 0.30 - 0.38 * down) / 0.06)) + 0.5 * exp(-sq((x - 0.43 - 0.38 * down) / 0.02))) * vec3(1.0, 0.957, 0.882); // reflections in the pane
        """
    }

    /// Earth, after a home-made nest in fine yellow-brown soil (photograph 8): the soil too fine to show a grain,
    /// in clumps, lit from the upper left; a tunnel is dark, the soil behind it in the shadow of its upper lip,
    /// with crumbs left on the pane beside its walls and a little light on its floor; the room above is dark.
    /// The ants are not dimmed with it, or they would not be seen in its tunnels.
    private static let earthLook = """
            vec3 soil = vec3(0.725, 0.561, 0.373) * (1.0 - clamp(slow.b - 0.5, 0.0, 2.0) * vec3(0.03, 0.045, 0.06));
            vec3 face = soil * (1.0 + 0.085 * n.r + 0.05 * n.b + 0.03 * slow.r) * (1.0 + 0.07 * n.g + 0.04 * n.a) * (1.0 + 0.04 * spoil);
            float edge = clamp((1.0 - close) * 2.0, 0.0, 1.0); // the soil's last crumbs before a tunnel
            face *= 1.0 - 0.20 * edge * clamp(-lit, 0.0, 1.0) + 0.08 * edge * clamp(lit, 0.0, 1.0);

            float depth = clamp((0.5 - wide) / 0.40, 0.0, 1.0);
            float lip = texture2D(u_near, vec2(cell.x - 0.16 * u_bl, u_cells.y - cell.y + 0.30 * u_bl) / u_cells.xy).r;
            vec3 back = vec3(0.361, 0.275, 0.180) * (1.0 + 0.04 * n.r + 0.05 * slow.b) * (1.0 - 0.5 * lip) * (1.0 + 0.45 * clamp(lit, 0.0, 1.0) * clamp(wide * 2.4, 0.0, 1.0));
            vec3 wall = soil * (0.60 + 0.22 * lit) * (1.0 - 0.45 * depth) * (1.0 + 0.06 * n.r);
            vec3 hollow = mix(wall, back, pow(depth, 1.2));
            hollow = mix(hollow, face * 0.78, step(h.x, 0.55 * pow(clamp(close * 1.6, 0.0, 1.0), 1.5)));
            hollow = mix(hollow, vec3(0.078, 0.075, 0.078) * (1.25 - 0.5 * down), step(cell.y, ground));

            vec3 colour = mix(hollow, face, solid) * 0.60;
            colour += 0.012 * exp(-sq((x - 0.25 - 0.35 * down) / 0.07)) * vec3(1.0, 0.957, 0.882); // a reflection in the pane
    """
}

extension AntColony: HeadStart {
    /// For the copy Settings runs behind its page: early in a farm the tank is all but whole and at its end
    /// nothing is being dug, and neither shows what Look, Ant size or Ants do. So when under three tenths of the
    /// digging is done, or over nine, that copy is given three in the afternoon of the day's first farm (three
    /// fifths dug), and goes on from there at Speed's pace. The desktop's copy keeps the wall's clock.
    func headStart() {
        let hours = asked.hour ?? Self.moment(at: Date.timeIntervalSinceReferenceDate).hours
        if !(0.3...0.9).contains(Self.share(after: hours)) { asked.hour = 9 }
    }
}
