import SpriteKit

@MainActor func beehive(size: CGSize) -> SKScene { Beehive(size: size) }

/// An observation hive behind glass: Langstroth medium frames stacked up the screen, edge to edge, the day's comb in
/// the bottom one drawn out from its top bar by the wall clock, filled with honey from the top and capped in
/// patches; the frames above are the days before, each the very comb that was drawn out that day, still closing its
/// last caps. At ten at night the next comb's first cells appear, and the stack slides up one frame over half an hour.
///
/// Ant Colony's way of working: each comb is baked from its day as one map, a texel a cell, of when the cell is drawn
/// out, filled and capped (`Comb`), and one shader compares that map with the comb's clock, so a frame costs the same
/// however far the day has gone. The stack is kept in a rasterised effect node, drawn again only when the clock moves
/// a step. docs/beehive.md has the plan, the measurements of real comb and frames these follow, and the sources.
///
/// The bars' wood is cut from Poly Haven's coated_pine_02 (CC0, https://polyhaven.com/a/coated_pine_02): eight
/// bands 48 pixels high through the middles of its boards, the scan's full 2,048 pixels (1,050 mm) across
/// (`Resources/beehive-wood.jpg`). The bees are cut from the USGS Bee Inventory and Monitoring Lab's photograph of a
/// worker from above, *Apis mellifera, light body, back, beltsville, md 2017-05-26-15.12* (Public Domain Mark 1.0,
/// https://www.flickr.com/photos/usgsbiml/34886290922/), as an atlas of ten poses with legs painted under it, drawn
/// by `docs/beehive/mock.swift` (`atlasOut`) at Large in the photograph's own light (`Resources/beehive-bees.png`).
final class Beehive: SKScene {
    /// The hour a comb begins: its first cells are drawn out from ten at night, a quarter of it by six.
    nonisolated static let dawn = 22.0
    /// The share of a comb drawn out by six in the morning (research-method.md §3).
    nonisolated static let s0 = 0.25

    /// The share of a comb drawn out `h` hours after six on its day: the quarter drawn overnight from ten (`h` from
    /// −8 to 0), then Ant Colony's curve over the rest, 44% of what is left by noon, 94% by midnight.
    nonisolated static func built(_ h: Double) -> Double {
        h < 0 ? s0 * max(0, 1 + h / 8) : s0 + (1 - s0) * AntColony.share(after: h)
    }

    /// The hour after six (negative before it) a comb reaches `share` drawn out: `built` backwards.
    nonisolated static func hour(of share: Double) -> Double {
        share <= s0 ? -(s0 - share) / s0 * 8 : 24 * (1 - (max(0, 1 - (share - s0) / (1 - s0))).squareRoot())
    }

    /// A comb by its day (a number like 20261120, for the comb begun at ten that night) and its turn in the day, 0
    /// for the day's own and 1 up for those that follow at a Speed above 1×, as Ant Colony's farms are.
    struct Key: Hashable {
        var day: Int, turn: Int
        /// The comb drawn out before this one: the turn before, or the day before's own.
        var previous: Key {
            guard turn == 0 else { return Key(day: day, turn: turn - 1) }
            var utc = Calendar(identifier: .gregorian)
            utc.timeZone = TimeZone(identifier: "UTC")!
            let date = utc.date(from: DateComponents(year: day / 10000, month: day / 100 % 100, day: day % 100 - 1))!
            let parts = utc.dateComponents([.year, .month, .day], from: date)
            return Key(day: parts.year! * 10000 + parts.month! * 100 + parts.day!, turn: 0)
        }
        var seed: UInt64 { UInt64(day * 100 + turn) }
    }

    /// A Langstroth medium frame at a size, in points (docs/beehive/mockups-round2.md: 6-1/4" side bars, a 3/4" top
    /// bar and a 3/8" bottom bar, checked against a cut list; 8 mm of bee space between frames, from the 6.4 to 9.5 mm
    /// a Langstroth hive keeps): `cell` across a cell's flats, a honey cell being 5.74 mm.
    struct Frames {
        let cell, ppm, topBar, bottomBar, comb, pitch: Double
        init(cell: Double) {
            (self.cell, ppm) = (cell, cell / 5.74)
            (topBar, bottomBar) = (19.05 * ppm, 9.525 * ppm)
            comb = 158.75 * ppm - topBar - bottomBar
            pitch = 158.75 * ppm + 8 * ppm
        }
        /// Where frame `k`'s comb begins, down from the top of a screen `high` points tall, with the stack at rest:
        /// the day's frame (0) has its bottom bar on the screen's lower edge, yesterday's (1) is above it.
        func top(_ k: Int, high: Double) -> Double { high - bottomBar - comb - Double(k) * pitch }
    }

    /// The light a look is drawn in (research-look.md §3, tuned in round 2 to its brightness caps), in sRGB 0 to 255.
    struct Palette {
        var wall, fresh, cap, glint, room, wood, floor: SIMD3<Double>
        /// Honey's transmittance a unit deep; and the lamp's strength near and far, and its colour far off.
        var honey: SIMD3<Double>, lamp: SIMD2<Double>, far: SIMD3<Double>
        /// The bees' light: the photograph's studio light dimmed to the lamp, and tinted.
        var bee: SIMD3<Double>
        /// Lit through from behind: the thin bases glow and the walls, seen edge on, are dark.
        var behind = false, shade = SIMD3<Double>(0, 0, 0)
    }
    nonisolated static let amber = Palette(wall: [132, 109, 67], fresh: [160, 130, 86], cap: [145, 109, 69], glint: [184, 164, 132],
                                           room: [14, 10, 7], wood: [90, 63, 30], floor: [120, 86, 40], honey: [0.95, 0.80, 0.62],
                                           lamp: [1.09, 0.68], far: [1.08, 0.94, 0.78], bee: SIMD3(1.0, 0.86, 0.68) * 0.62)

    /// The mean brightness of the wood strip (its luma, 0 to 1), so a bar takes the look's wood colour on average.
    nonisolated private static let woodLuma = 0.3724

    /// Which comb is in the bottom frame and how long since it began, by the wall clock: Ant Colony's `Cycle`, with
    /// days from ten at night. One is shared by every copy of the scene and kept in the defaults.
    private static var cycle: AntColony.Cycle?, saved: AntColony.Cycle?

    /// The shared cycle's comb at `wall`, and the hours since it began, moving the cycle on and saving it when it has
    /// gone on to another comb or the pace has changed (Ant Colony's `moment`, under Beehive's keys).
    private static func moment(at wall: Double, speed: Double) -> (key: Key, hours: Double) {
        let defaults = UserDefaults.standard
        if cycle == nil {
            if let comb = defaults.object(forKey: "beehive.comb") as? Int, let began = defaults.object(forKey: "beehive.began") as? Double {
                cycle = AntColony.Cycle(day: comb / 100, turn: comb % 100, began: began,
                                        paced: defaults.object(forKey: "beehive.paced") as? Double ?? max(speed, 1), dawn: dawn)
            } else { cycle = AntColony.Cycle(at: wall, speed: speed, dawn: dawn) }
        }
        let hours = cycle!.hours(at: wall, speed: speed)
        if cycle != saved {
            saved = cycle
            defaults.set(cycle!.day * 100 + cycle!.turn, forKey: "beehive.comb")
            defaults.set(cycle!.began, forKey: "beehive.began")
            defaults.set(cycle!.paced, forKey: "beehive.paced")
        }
        return (Key(day: cycle!.day, turn: cycle!.turn), hours)
    }

    /// The stack moves up by moving `mover`, a plain node: moving the rasterised node itself would draw it again
    /// every frame (0.91 ms of GPU against 0.19 to 0.40, measured in round 2).
    private let mover = SKNode(), kept = SKEffectNode(), swarm = SKNode()
    /// One frame of the stack as it is drawn: its comb's sprite and the uniforms the clock moves.
    private struct Drawn { let k: Int, comb: (state: SKUniform, place: SKUniform, skip: Double)?, bars: [(SKUniform, Double)] }
    private var drawn: [Drawn] = []
    /// The stack's combs, the day's first, and each comb baked for the size it is drawn at.
    private var keys: [Key] = [], combs: [Key: Comb] = [:]
    private var frames = Frames(cell: 14), palette = Beehive.amber
    /// What the stack was last laid out for: its combs, the part of it to draw (down from the top of the screen at
    /// rest, in points), and the step of the clock its uniforms were set at.
    private var laid: (keys: [Key], window: ClosedRange<Double>)?, step = -1
    /// What the pictures of it ask for as the scene is built: another day's comb (`beehive.day`, like 20261120) and
    /// the time of day (`beehive.hour`, 0 to 24 on the clock). With either it keeps a clock of its own and saves nothing.
    private var asked: (day: Int?, hour: Double?) = (nil, nil), own: AntColony.Cycle?
    /// The bees, and every cell of the frames laid out for them; whether a new comb has just gone in under the
    /// stack; when they were set going by the wall's clock and the sixtieths stepped since; the half minute of the
    /// comb's clock they last took stock at.
    private var colony: Bees?, world = Bees.World(), shifted = false, since = 0.0, ticked = 0, surveyed = -1
    /// Each bee's sprite, and what it was last shown as: its pose, its light, and whether it is placed at all.
    private var figures: [SKSpriteNode] = [], shown: [(pose: Bees.Pose, lit: Double, z: Double)?] = []
    private var poses: [SKTexture] = []

    override func sceneDidLoad() {
        backgroundColor = Self.colour(palette.room)
        kept.shouldRasterize = true
        mover.addChild(kept)
        swarm.zPosition = 1
        mover.addChild(swarm)
        let atlas = sharedTexture("beehive-bees.png"), n = Bees.Pose.allCases.count
        poses = (0..<n).map { SKTexture(rect: CGRect(x: Double($0) / Double(n), y: 0, width: 1 / Double(n), height: 1), in: atlas) }
        addChild(mover)
        let defaults = UserDefaults.standard
        asked = ((defaults.object(forKey: "beehive.day") as? Double).map { Int($0) }, defaults.object(forKey: "beehive.hour") as? Double)
    }

    private static func colour(_ c: SIMD3<Double>) -> NSColor { NSColor(srgbRed: c.x / 255, green: c.y / 255, blue: c.z / 255, alpha: 1) }

    override func update(_ currentTime: TimeInterval) {
        // The wall's clock by way of the frame's time, as Ant Colony has it, so the tests' frames are of their own moments.
        let wall = currentTime + Date.timeIntervalSinceReferenceDate - ProcessInfo.processInfo.systemUptime
        let speed = 1.0
        if asked.day != nil || asked.hour != nil, own == nil {
            let today = AntColony.day(at: wall, dawn: Self.dawn)
            let hours = asked.hour.map { ($0 - Self.dawn + 24).truncatingRemainder(dividingBy: 24) } ?? today.hours
            own = AntColony.Cycle(day: asked.day ?? today.day, turn: 0, began: currentTime - hours * 3600 / speed, paced: speed, dawn: Self.dawn)
        }
        let now: (key: Key, hours: Double)
        if own != nil {
            let hours = own!.hours(at: currentTime, speed: speed, daily: false)
            now = (Key(day: own!.day, turn: own!.turn), hours)
        } else { now = Self.moment(at: wall, speed: speed) }

        // The stack: the day's comb and those before it. A comb that begins while the scene runs goes in under the
        // ones on the screen, which move up, so the frame above is always the comb that was just in the bottom one.
        if keys.first != now.key {
            shifted = !keys.isEmpty
            keys = keys.isEmpty ? [now.key] : [now.key] + keys.prefix(6)
        }
        let hours = min(max(now.hours, 0), 24), high = Double(size.height)
        // The slide: the comb's first half hour (of its own clock, so half an hour divided by Speed), eased.
        let through = simd_smoothstep(0, 1, hours / 0.5)
        let window = through < 1 ? -frames.pitch...high : 0...high
        if laid?.keys != keys || laid?.window != window { lay(window, high: high) }
        let off = frames.pitch * (1 - through)
        if mover.position.y != -off { mover.position.y = -off }
        bees(wall: wall, hours: hours, seen: -off...(high - off), sliding: through < 1)

        // The combs' clock, in steps of ten seconds of their own: the stack is drawn again only then.
        let now10 = Int(hours * 360)
        guard now10 != step else { return }
        step = now10
        if through < 1 { for i in shown.indices { shown[i] = nil } } // the bees take the lamp's light where they now are
        for frame in drawn {
            if let comb = frame.comb {
                let h = hours - 8 + 24 * Double(frame.k), b = Self.built(h)
                comb.state.vectorFloat3Value = [Float(b), Float(h), Float(max(0.0015, Self.built(h + 1.5) - b))]
                comb.place.vectorFloat4Value = [Float(comb.skip), Float(frames.top(frame.k, high: high) - off), Float(size.width), Float(high)]
            }
            for (place, y) in frame.bars { place.vectorFloat4Value = [0, Float(y - off), Float(size.width), Float(high)] }
        }
    }

    /// Lays the stack out afresh: each frame whose comb or bars fall inside `window` (down from the top of the screen
    /// with the stack at rest), its comb cut to the window, and its bars whole. The window is the screen, or the
    /// screen and a frame below it while the stack slides, so it is laid out twice a day.
    private func lay(_ window: ClosedRange<Double>, high: Double) {
        kept.removeAllChildren()
        drawn = []
        let wide = Double(size.width)
        var cells = Bees.World()
        var k = 0
        while frames.top(k, high: high) + frames.comb + frames.bottomBar > window.lowerBound {
            if k >= keys.count { keys.append(keys.last!.previous) }
            let top = frames.top(k, high: high), key = keys[k]
            let comb = combs[key] ?? Comb(seed: key.seed, wide: wide, high: frames.comb, cell: frames.cell)
            combs[key] = comb
            var bars: [(SKUniform, Double)] = []
            for (y, tall, bottom) in [(top - frames.topBar, frames.topBar, false), (top + frames.comb, frames.bottomBar, true)]
            where y < window.upperBound && y + tall > window.lowerBound {
                let place = SKUniform(name: "u_place", vectorFloat4: [0, Float(y), Float(wide), Float(high)])
                let bar = SKSpriteNode(color: .black, size: CGSize(width: wide, height: tall))
                bar.anchorPoint = .zero
                bar.position = CGPoint(x: 0, y: high - y - tall)
                var r = Rand(s: key.seed &* 977 &+ (bottom ? 1 : 0))
                bar.shader = SKShader(source: barSource, uniforms: [
                    SKUniform(name: "u_size", vectorFloat2: [Float(wide), Float(tall)]), place,
                    SKUniform(name: "u_cut", vectorFloat4: [Float(Int(r.next() * 8)), Float(r.next() * 1000), Float(tall / frames.ppm), Float(frames.ppm)]),
                    SKUniform(name: "u_wood", texture: sharedTexture("beehive-wood.jpg"))])
                kept.addChild(bar)
                bars.append((place, y))
            }
            let from = max(top, window.lowerBound), to = min(top + frames.comb, window.upperBound)
            for i in comb.share.indices where comb.share[i] <= 1 {
                cells.at.append(comb.at[i] + SIMD2(0, top))
                cells.share.append(comb.share[i])
                cells.fill.append(comb.fill[i])
                cells.cap.append(comb.cap[i])
                cells.ahead.append(24 * Double(k))
            }
            if to > from {
                let state = SKUniform(name: "u_state", vectorFloat3: [0, 0, 1]), place = SKUniform(name: "u_place", vectorFloat4: [0, 0, 0, 0])
                let sprite = SKSpriteNode(color: .black, size: CGSize(width: wide, height: to - from))
                sprite.anchorPoint = .zero
                sprite.position = CGPoint(x: 0, y: high - to)
                sprite.shader = SKShader(source: combSource, uniforms: [
                    SKUniform(name: "u_size", vectorFloat2: [Float(wide), Float(to - from)]), place, state,
                    SKUniform(name: "u_cells", vectorFloat3: [Float(comb.cols), Float(comb.rows), Float(frames.cell)]),
                    SKUniform(name: "u_warp", vectorFloat4: SIMD4<Float>(comb.warp)),
                    SKUniform(name: "u_map", texture: comb.texture())])
                kept.addChild(sprite)
                drawn.append(Drawn(k: k, comb: (state, place, from - top), bars: bars))
            } else if !bars.isEmpty {
                drawn.append(Drawn(k: k, comb: nil, bars: bars))
            }
            k += 1
        }
        keys = Array(keys.prefix(k))
        combs = combs.filter { keys.contains($0.key) }
        laid = (keys, window)
        (world, step, surveyed) = (cells, -1, -1)
        colony?.world = world
        for i in shown.indices { shown[i] = nil }
    }

    /// The bees: the colony made when the stack is first laid out, moved up with their frames when a new comb goes
    /// in, taking stock of the comb every half minute of its clock, and stepped in sixtieths of a second by the wall's
    /// clock (a second at the most in one frame: after a gap they go on from where they were).
    private func bees(wall: Double, hours: Double, seen: ClosedRange<Double>, sliding: Bool) {
        let wide = Double(size.width), high = Double(size.height)
        if colony == nil {
            var made = Bees(ppm: frames.ppm)
            made.world = world
            made.survey(hours: hours, seen: seen, wide: wide)
            let screen = wide * high / (frames.ppm * frames.ppm) / 100 // cm²
            made.populate(min(1200, Int((0.2 * screen).rounded())))
            (colony, since, ticked, surveyed, shifted) = (made, wall, 0, Int(hours * 120), false)
        }
        if shifted { colony!.shift(by: -frames.pitch); (shifted, surveyed) = (false, -1) }
        if Int(hours * 120) != surveyed { colony!.survey(hours: hours, seen: seen, wide: wide); surveyed = Int(hours * 120) }
        let due = Int(((wall - since) * 60).rounded())
        ticked = max(ticked, due - 60)
        while ticked < due { colony!.step(); ticked += 1 }

        // Each bee's sprite, set only where something has changed: a bee standing still costs nothing.
        let bees = colony!.bees, t = Double(ticked) / 60, ppm = frames.ppm, p = palette
        while figures.count < bees.count {
            let s = SKSpriteNode(texture: poses[Bees.Pose.stand.rawValue])
            s.colorBlendFactor = 1
            figures.append(s)
            shown.append(nil)
            swarm.addChild(s)
        }
        for (i, b) in bees.enumerated() {
            let s = figures[i], still = b.state != .walk && b.state != .work
            let pose = b.state == .work && b.job == .groom ? (Int(t / 1.5 + b.phase) % 2 == 0 ? Bees.Pose.groom : .stand) : b.pose
            if still, let was = shown[i], was.pose == pose { continue }
            if s.isHidden { s.isHidden = false }
            var at = b.at, turn = b.heading
            switch (b.state, b.job) { // small movements in place: a nod at the rim, a capper at work, a head in a cell
            case (.work, .build): at.x += cos(turn) * 0.5 * sin(t * 2.4 + b.phase) * ppm
            case (.work, .cap): turn += 0.12 * sin(t * 1.3 + b.phase); at.x += 0.3 * ppm * sin(t * 0.9 + b.phase)
            case (.work, .store): at.x += cos(turn) * 0.35 * ppm * sin(t * 1.1 + b.phase)
            default: break
            }
            s.position = CGPoint(x: at.x, y: high - at.y)
            s.zRotation = -turn
            let side = 1.5 * colony!.length * b.scale
            if s.size.width != side { s.size = CGSize(width: side, height: side) }
            let z = Double(i) * 0.001 + (b.state == .walk ? 10 : b.state == .festoon ? 5 : 0)
            let l = (p.lamp.x + (p.lamp.y - p.lamp.x) * min(1, hypot(at.x / wide + 0.1, (at.y - seen.lowerBound) / high + 0.2) / 1.4)) / p.lamp.x
            if shown[i]?.pose != pose { s.texture = poses[pose.rawValue] }
            if shown[i]?.z != z { s.zPosition = z }
            if shown[i].map({ abs($0.lit - l) > 0.02 }) ?? true {
                let c = p.bee * SIMD3(l, l * (1 - 0.1 * (1 - l)), l * (1 - 0.25 * (1 - l)))
                s.color = NSColor(srgbRed: c.x, green: c.y, blue: c.z, alpha: 1)
            }
            shown[i] = (pose, shown[i].map { abs($0.lit - l) > 0.02 ? l : $0.lit } ?? l, z)
        }
        for i in bees.count..<figures.count where !figures[i].isHidden { figures[i].isHidden = true }
    }

    // MARK: The shaders

    private static func v3(_ c: SIMD3<Double>) -> String { String(format: "vec3(%.4f, %.4f, %.4f)", c.x / 255, c.y / 255, c.z / 255) }

    /// The lamp beyond the upper left, by a point's place on the screen (`u_place.y` is where the sprite's top is,
    /// `zw` the screen's size, and `at` the point in the sprite's own points): a warm lamp that dims toward red, so the
    /// far side goes brown and never olive.
    private func lamp(_ at: String) -> String {
        let p = palette
        return """
            float lf = clamp(length(vec2(\(at).x, u_place.y + \(at).y) / u_place.zw - vec2(-0.1, -0.2)) / 1.4, 0.0, 1.0);
            vec3 lamp = mix(vec3(\(p.lamp.x)), vec3(\(p.lamp.y)) * vec3(\(p.far.x), \(p.far.y), \(p.far.z)), lf);
        """
    }

    /// A bar: the wood scan's light and dark in the look's wood colour (its own hue and its coating's glints left
    /// out), the upper arris lit by the lamp above and the lower in shade. `u_cut` is which band of the strip, how far
    /// along it in mm, and the bar's height in mm and the points to a mm. The strip repeats mirrored past its end.
    private var barSource: String {
        let tint = palette.wood / 255 / Self.woodLuma
        return """
        void main() {
            vec2 at = vec2(v_tex_coord.x, 1.0 - v_tex_coord.y) * u_size;
            float u = (at.x / u_cut.w + u_cut.y) * 1.951 / 2048.0;
            u = 1.0 - abs(mod(u, 2.0) - 1.0);
            float v = (u_cut.x + 0.5 + (at.y / u_cut.w - 0.5 * u_cut.z) * 1.951 / 48.0) / 8.0;
            vec3 w = vec3(dot(texture2D(u_wood, vec2(u, v)).rgb, vec3(0.2126, 0.7152, 0.0722))) * vec3(\(tint.x), \(tint.y), \(tint.z));
            w *= 1.0 + 0.14 * (1.0 - smoothstep(0.0, 1.6, at.y)) - 0.4 * (1.0 - smoothstep(0.0, 3.0, u_size.y - at.y));
        \(lamp("at"))
            gl_FragColor = vec4(w * lamp, 1.0);
        }
        """
    }

    /// A comb (research-method.md §4, as round 2 drew it): the nearest cell of a pointy-topped lattice, bent by up to
    /// a third of a cell over about 26 cells, found by cube rounding, and its texel read at its centre. A cell being
    /// drawn out is a rounded pit with a thick pale rim, its walls rising over an hour and a half of the comb's clock;
    /// a drawn cell has a coping rim lit from the upper left, its floor pushed down by the cell's upward tilt with a
    /// band of upper wall above it, in three facets. Honey is the floor seen through the honey's depth (Beer–Lambert),
    /// with one still highlight once the cell is nearly full; a cap closes from the rim inward, flat, grainy, a little
    /// domed. Where nothing is drawn, the hive's dark back.
    ///
    /// `u_state` is the share drawn out, the hours since six on this comb's day, and the share drawn in an hour and a
    /// half (how deep the growing edge is); `u_map` holds a cell's share (16 bits) and its fill and cap times in
    /// quarter hours from six hours before six, 255 for never.
    private var combSource: String {
        let p = palette, back = p.behind
        return """
        float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
        float noise(vec2 p) {
            vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
            return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
        }
        void main() {
            vec2 at = vec2(v_tex_coord.x, 1.0 - v_tex_coord.y) * u_size, p = at + vec2(0.0, u_place.x);
            float cell = u_cells.z;
            vec2 lp = p + u_warp.x * 0.5 * vec2(sin(p.y * u_warp.y + u_warp.z) + 0.6 * sin((p.x * 0.7 + p.y * 0.4) * u_warp.y * 1.3 + u_warp.w),
                                                sin(p.x * u_warp.y * 0.9 + u_warp.w) + 0.6 * sin((p.x * 0.5 - p.y * 0.8) * u_warp.y * 1.1 + u_warp.z));
            float s = cell / 1.7320508;
            vec2 q = vec2((lp.x * 0.5773503 - lp.y / 3.0) / s, (lp.y * 2.0 / 3.0) / s);
            vec3 cube = vec3(q.x, q.y, -q.x - q.y);
            vec3 rc = floor(cube + 0.5);
            vec3 d = abs(rc - cube);
            if (d.x > d.y && d.x > d.z) { rc.x = -rc.y - rc.z; } else if (d.y > d.z) { rc.y = -rc.x - rc.z; }
            vec2 o = lp - vec2(s * 1.7320508 * (rc.x + rc.y * 0.5), s * 1.5 * rc.y);
            vec2 ao = abs(o);
            float apo = 0.5 * cell;
            float hexD = max(ao.x, 0.5 * ao.x + 0.8660254 * ao.y);
            vec4 m = texture2D(u_map, (vec2(rc.x + floor(rc.y * 0.5), rc.y) + 1.5) / u_cells.xy);
            float rnd = hash(rc.xy + 0.37);
            float built = u_state.x, hr = u_state.y, rise = u_state.z;
            float share = (m.r * 65280.0 + m.g * 255.0) / 65535.0;
            float present = step(share, built) * step(share, 0.9999);
            float wallH = clamp((built - share) / rise, 0.0, 1.0);
            float fromWall = apo - mix(hexD, length(o) * 0.96, 0.85 * (1.0 - wallH));
            present *= mix(smoothstep(-0.6, 0.2, fromWall), 1.0, wallH);
            fromWall = max(fromWall, 0.0);
            float fresh = 1.0 - clamp((built - share) / (rise * 4.0), 0.0, 1.0);
            float level = clamp((hr - (m.b * 63.75 - 6.0 + 0.25 * rnd)) / 1.5, 0.0, 1.0) * step(m.b, 0.999);
            float capP = clamp((hr - (m.a * 63.75 - 6.0 + 0.25 * rnd)) / 0.25, 0.0, 1.0) * step(m.a, 0.999);
            float aa = max(fwidth(fromWall), 0.05);
            float grain = noise(p * 0.45) * 0.6 + noise(p * 1.7) * 0.4;
            vec3 wax = mix(\(Self.v3(p.wall)), \(Self.v3(p.fresh)), fresh) * (0.9 + 0.2 * grain);
            // the coping at the mouth, thick and rough where the cell is new
            float rimW = 0.42 + (1.5 + 0.8 * grain) * (1.0 - wallH);
            float rim = 1.0 - smoothstep(rimW - aa, rimW + aa, fromWall);
            vec2 dir = o / max(length(o), 0.001);
            float rimLit = 1.0 + 0.18 * dot(dir, vec2(0.6, 0.8));
            // the floor, pushed down by the cell's upward tilt; above it a band of the upper inner wall
            float shift = (0.28 + 0.10 * rnd) * cell * wallH;
            vec2 of = o - vec2(0.0, shift);
            vec2 aof = abs(of);
            float floorIn = apo - rimW - max(aof.x, 0.5 * aof.x + 0.8660254 * aof.y);
            float onFloor = smoothstep(-aa, aa, floorIn);
            float face = max(max(dot(of, vec2(0.866, 0.5)), dot(of, vec2(-0.866, 0.5))), dot(of, vec2(0.0, -1.0)));
            float facet = dot(of, vec2(0.866, 0.5)) >= face ? 1.0 : (dot(of, vec2(-0.866, 0.5)) >= face ? 0.91 : 0.82);
            float band = clamp((fromWall - rimW) / max(shift, 0.3), 0.0, 1.0);
            float occl = 0.88 + 0.12 * smoothstep(0.0, 0.3 * apo, floorIn);
        \(back ? """
            vec3 floorC = \(Self.v3(p.shade)) * facet * occl * (0.85 + 0.3 * grain) * mix(1.0, 1.25, fresh);
            vec3 bandC = mix(floorC * 0.8, \(Self.v3(p.wall)) * 1.3, 1.0 - band);
            vec3 cellC = mix(bandC, floorC, onFloor);
            vec3 honey = floorC * pow(vec3(\(p.honey.x), \(p.honey.y), \(p.honey.z)), vec3(0.6 + 1.6 * level));
        """ : """
            vec3 floorC = mix(\(Self.v3(p.floor)), \(Self.v3(p.fresh)) * 0.8, fresh * 0.6) * facet * occl * (0.92 + 0.16 * grain);
            vec3 bandC = mix(wax * 0.8, \(Self.v3(p.floor)) * 0.66, band);
            vec3 cellC = mix(bandC, floorC, onFloor);
            vec3 honey = floorC * pow(vec3(\(p.honey.x), \(p.honey.y), \(p.honey.z)), vec3(0.4 + 1.0 * level));
        """)
            // nectar coats the cell and rises to the mouth; when full, one still highlight from the lamp
            float wet = smoothstep(0.0, 0.12, level);
            cellC = mix(cellC, mix(honey, honey * 0.8, (1.0 - onFloor) * (1.0 - smoothstep(0.5, 1.0, level))), wet);
            vec2 gl = o - vec2(-0.2, -0.24) * cell;
            cellC += \(Self.v3(p.glint)) * exp(-dot(gl, gl) / (0.012 * cell * cell)) * smoothstep(0.55, 1.0, level) * 0.7 * wet;
            // a cap closes from the rim inward: flat, grainy, a little domed, with a groove where it meets the wall
            float r0 = rimW + capP * (apo - rimW + 0.4);
            float capped = (1.0 - smoothstep(r0 - aa, r0 + aa, fromWall)) * step(0.001, capP);
            float dome = clamp(fromWall / apo, 0.0, 1.0);
            float groove = 1.0 - smoothstep(rimW, rimW + 1.1, fromWall);
            vec3 capC = \(Self.v3(p.cap)) * (0.80 + 0.24 * sqrt(dome) + 0.16 * (grain - 0.5)) * (1.0 - 0.22 * groove)
                      * (1.0 + 0.06 * dot(-dir, vec2(-0.6, -0.8)) * dome) * mix(1.0, 0.86, step(0.82, rnd));
            cellC = mix(cellC, capC, capped);
            vec3 combC = mix(cellC, wax * \(back ? "0.55" : "1.12") * rimLit, rim * mix(1.0, 0.4, capped * step(0.999, capP)));
            vec3 c = mix(\(Self.v3(p.room)) * (0.9 + 0.2 * noise(p * 0.02)), combC, present);
            // the top bar's soft shadow on the comb hung from it
            c *= 1.0 - 0.42 * (1.0 - smoothstep(0.0, 0.64 * cell, p.y));
        \(lamp("p"))
            gl_FragColor = vec4(c * lamp, 1.0);
        }
        """
    }
}

/// SplitMix64: the same comb for the same seed.
struct Rand {
    var s: UInt64
    mutating func next() -> Double {
        s &+= 0x9E37_79B9_7F4A_7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
    }
    mutating func range(_ r: ClosedRange<Double>) -> Double { r.lowerBound + (r.upperBound - r.lowerBound) * next() }
}

/// One comb, baked from its seed for a frame `wide` by `high` points (docs/beehive/mockups-round1.md and round 2's):
/// tongues hanging from the top bar, about one for each comb's height of bar so they join along it, each as high as it
/// is wide, pointed and then rounding, slowing as it nears the bottom, ragged by a cell or two at its edge. A cell's
/// rank in that growth is the share of the comb drawn out when it starts. Nectar arrives 2.2 to 4.3 hours after a
/// cell is drawn, from the top down and in patches, and fills over an hour and a half; the bottom 28% fills from the
/// evening into the next morning. Caps follow 2.7 to 5.9 hours after a cell is full, the top corners first; 2% of
/// cells are never capped. One texel a cell (`texture`), and for the bees each cell's place and times.
struct Comb {
    let cols, rows: Int
    /// The lattice's bend, the same here as in the shader: up to a third of a cell over about 26 cells.
    let warp: SIMD4<Double>
    /// Each cell's place in the frame (points, y down), the share drawn out when it starts (2 for a cell outside the
    /// frame), and the hours after six on its day it fills and is capped (99 for never).
    var at: [SIMD2<Double>], share: [Double], fill: [Double], cap: [Double]

    init(seed: UInt64, wide: Double, high: Double, cell: Double) {
        var rnd = Rand(s: seed &* 7919 &+ 17)
        warp = [cell * 0.33, 2 * .pi / (26 * cell), rnd.range(0...6.28), rnd.range(0...6.28)]
        cols = Int(wide / cell) + 4
        rows = Int(high / (cell * 0.8660254)) + 4
        let n = cols * rows
        (at, share, fill, cap) = (Array(repeating: .zero, count: n), Array(repeating: 2, count: n), Array(repeating: 99, count: n), Array(repeating: 99, count: n))
        func bend(_ x: Double, _ y: Double) -> SIMD2<Double> {
            [warp.x * 0.5 * (sin(y * warp.y + warp.z) + 0.6 * sin((x * 0.7 + y * 0.4) * warp.y * 1.3 + warp.w)),
             warp.x * 0.5 * (sin(x * warp.y * 0.9 + warp.w) + 0.6 * sin((x * 0.5 - y * 0.8) * warp.y * 1.1 + warp.z))]
        }
        /// Value noise, about `scale` points a feature.
        func noise(_ x: Double, _ y: Double, _ scale: Double, _ salt: UInt64) -> Double {
            func h(_ i: Int, _ j: Int) -> Double { var r = Rand(s: UInt64(bitPattern: Int64(i &* 73856093 ^ j &* 19349663)) ^ salt); return r.next() }
            let (u, v) = (x / scale, y / scale), (i, j) = (Int(floor(u)), Int(floor(v)))
            let (fx, fy) = (u - floor(u), v - floor(v)), (sx, sy) = (fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy))
            let a = h(i, j) + (h(i + 1, j) - h(i, j)) * sx, b = h(i, j + 1) + (h(i + 1, j + 1) - h(i, j + 1)) * sx
            return a + (b - a) * sy
        }
        let tongues = max(2, Int((wide / high).rounded())) + Int(rnd.next() * 1.999)
        let seeds = (0..<tongues).map { i in
            (x: wide * (Double(i) + rnd.range(0.25...0.75)) / Double(tongues), speed: rnd.range(0.85...1.15), delay: rnd.range(0...0.12) * high)
        }
        var arrival: [(Double, Int)] = []
        for r in 0..<rows { for c in 0..<cols {
            let i = r * cols + c, (lc, lr) = (Double(c - 1), Double(r - 1))
            let lattice = SIMD2(cell * lc + (r & 1 == 0 ? cell / 2 : 0), cell * 0.8660254 * lr)
            var p = lattice
            for _ in 0..<3 { p = lattice - bend(p.x, p.y) } // the frame's point the bend brings here
            at[i] = p
            guard p.x > -cell * 0.6, p.x < wide + cell * 0.6, p.y > -cell * 0.6, p.y < high + cell * 0.6 else { continue }
            let dy = max(0, p.y), late = max(0, dy - 0.72 * high), slow = dy + 1.6 * late * late / high
            var best = Double.infinity
            for s in seeds {
                let dx = p.x - s.x
                best = min(best, s.delay + ((dx * dx + 0.30 * slow * slow + 4 * cell * cell).squareRoot() + 0.22 * abs(dx) + 0.25 * slow) / s.speed)
            }
            arrival.append((best + (noise(p.x, p.y, cell * 4, seed) - 0.5) * 3 * cell + rnd.range(-0.4...0.4) * cell, i))
        }}
        arrival.sort { $0.0 < $1.0 }
        for (rank, a) in arrival.enumerated() {
            let i = a.1, s = Double(rank) / Double(arrival.count), p = at[i], drawn = Beehive.hour(of: s)
            share[i] = s
            let patch = noise(p.x, p.y, cell * 7, seed &+ 3)
            fill[i] = s >= 0.72 ? max(drawn + 2.2, 12 + 8 * (s - 0.72) / 0.28) + 1.6 * patch + rnd.range(0...0.5)
                                : drawn + 2.2 + 1.6 * patch + rnd.range(0...0.5)
            let corner = max(0, 1 - min(hypot(p.x, p.y), hypot(wide - p.x, p.y)) / (0.55 * wide))
            cap[i] = fill[i] + 2.7 + 3.2 * noise(p.x, p.y, cell * 6, seed &+ 5) - 2.2 * corner
            if rnd.next() < 0.02 { cap[i] = 99 }
        }
    }

    /// The map the shader reads, a texel a cell: the share (16 bits), then the fill and cap times in quarter hours
    /// from six hours before six (255: never, or past the two and a half days a frame is in the stack).
    func texture() -> SKTexture {
        func quarters(_ h: Double) -> UInt8 { h > 57 ? 255 : UInt8(max(0, min(254, ((h + 6) * 4).rounded()))) }
        var bytes = [UInt8](repeating: 255, count: share.count * 4)
        for i in share.indices {
            let v = share[i] > 1 ? 65535 : UInt16(min(65534, share[i] * 65535))
            (bytes[i * 4], bytes[i * 4 + 1], bytes[i * 4 + 2], bytes[i * 4 + 3]) = (UInt8(v >> 8), UInt8(v & 255), quarters(fill[i]), quarters(cap[i]))
        }
        let texture = SKTexture(data: Data(bytes), size: CGSize(width: cols, height: rows))
        texture.filteringMode = .nearest
        return texture
    }
}

/// The bees (research-method.md §2 and §5, at the numbers rounds 1 and 2 drew): 0.2 to a cm² of screen, each
/// cycling through a walk, a spell of work in place and a spell still, so that about one in eight is walking, at 2 to 5
/// mm a second by day and under half that by night, turning at most 45° a second and giving way to a bee just ahead.
/// They are sent to where the comb's map says work is: the cells being drawn out, filled and capped. A spell of work
/// lasts 20 to 90 seconds (a nod at the rim, a head in a filling cell, small movements over a cap, grooming), a still
/// spell 20 seconds to five minutes; at most two bees work a cell. A few sleep head first in empty cells, a few pairs
/// stand face to face passing food, and in the morning a share hang in festoons, chains of bees under the growing edge.
/// Stepped in sixtieths of a second, in the stack's points (down from the top of the screen with the stack at rest).
struct Bees {
    enum State { case walk, work, rest, cell, festoon, pair }
    enum Job { case none, build, store, cap, groom, hang, sleep }
    /// A frame of the atlas: four steps of a walk, standing, head first in a cell, the tip of an abdomen in one (a bee
    /// asleep), grooming, hanging in a festoon, fanning.
    enum Pose: Int, CaseIterable { case walk0, walk1, walk2, walk3, stand, headIn, tipIn, groom, festoon, fan }
    struct Bee {
        var at: SIMD2<Double>, heading: Double, scale: Double, phase: Double
        var state = State.rest, job = Job.none, pose = Pose.stand
        var timer = 0.0, walked = 0.0, speed = 0.0, target = SIMD2<Double>.zero, cell = -1, partner = -1
    }
    /// Every cell of the frames laid out: its place in the stack, its share, the hours it fills and is capped, and the
    /// hours its frame's clock is ahead of the day's (24 a frame up the stack).
    struct World { var at: [SIMD2<Double>] = [], share: [Double] = [], fill: [Double] = [], cap: [Double] = [], ahead: [Double] = [] }

    var bees: [Bee] = []
    var world = World()
    /// The cells by what is being done at them, as of the last survey; and the bees working each.
    private var building: [Int] = [], filling: [Int] = [], capping: [Int] = [], empty: [Int] = [], drawn: [Int] = [], edge: [Int] = []
    private var taken: [Int: Int] = [:]
    private var rng = Rand(s: 0x5EED_B33)
    /// A bee's length in points, and points to a millimetre; how slowly they go (1 by day, 0.45 by night); how many
    /// should be hanging in festoons; and the part of the stack on the screen.
    let length: Double, ppm: Double
    private(set) var pace = 1.0, hanging = 0.0
    /// How many should be hanging in festoons now.
    var festoons: Int { Int(hanging * Double(bees.count)) }
    private var seen = 0.0...1.0, wide = 1.0

    init(ppm: Double) { (self.ppm, length) = (ppm, 12 * ppm) }

    /// Takes stock of the comb at `hours` since the day's comb began, with `seen` the part of the stack on the screen:
    /// which cells are being drawn out, filled and capped, which are empty, and the day's frame's lower edge, where
    /// festoons hang. Done every half minute of the comb's clock.
    mutating func survey(hours: Double, seen: ClosedRange<Double>, wide: Double) {
        (self.seen, self.wide) = (seen, wide)
        let clock = (Beehive.dawn + hours).truncatingRemainder(dividingBy: 24)
        pace = clock >= 21 || clock < 6 ? 0.45 : 1
        (building, filling, capping, empty, drawn, edge) = ([], [], [], [], [], [])
        for i in world.share.indices {
            let h = hours - 8 + world.ahead[i], built = Beehive.built(h), p = world.at[i]
            guard world.share[i] <= built, p.x > 4, p.x < wide - 4, p.y > seen.lowerBound + 4, p.y < seen.upperBound - 4 else { continue }
            drawn.append(i)
            if h < 24, world.share[i] > built - max(Beehive.built(h + 1.5) - built, 0.004) { building.append(i) }
            if h >= world.fill[i], h < world.fill[i] + 1.5 { filling.append(i) }
            if h >= world.cap[i] - 0.4, h < world.cap[i] + 0.25 { capping.append(i) }
            if h < world.fill[i] { empty.append(i) }
        }
        let cell = length / 12 * 5.74, row = cell * 0.866
        let below = Set(drawn.map { SIMD2(Int(world.at[$0].x / cell), Int(world.at[$0].y / row)) })
        edge = building.filter {
            let p = world.at[$0]
            return !below.contains(SIMD2(Int(p.x / cell), Int(p.y / row) + 2)) && p.y < seen.upperBound - length
        }
        hanging = edge.isEmpty ? 0 : 0.18 * (1 - min(1, max(0, (Beehive.built(hours - 8) - 0.3) / 0.45)))
        taken = taken.filter { $0.value > 0 }
    }

    /// The colony made afresh, `count` bees in a mix of what they do (`survey` first): about 13% walking, 40% working,
    /// a few asleep in cells and in pairs, festoons under the edge, and the rest still.
    mutating func populate(_ count: Int) {
        bees = []
        taken = [:]
        let hanging = Int(self.hanging * Double(count))
        for _ in 0..<count {
            var b = Bee(at: .zero, heading: rng.range(0...6.283), scale: rng.range(0.95...1.05), phase: rng.range(0...100))
            let r = rng.next(), k = rng.next(), job: Job = k < 0.3 ? .build : k < 0.65 ? .store : k < 0.85 ? .cap : .groom
            b.at = restPlace()
            if r < 0.13 {
                startWalk(&b)
            } else if r < 0.53, settle(&b, at: job) {
                b.timer = rng.range(5...90) / pace
            } else if r > 0.93, let c = pick(empty) {
                (b.state, b.pose, b.at, b.timer) = (.cell, .tipIn, world.at[c], rng.range(0...3600) / pace)
            } else {
                (b.state, b.timer) = (.rest, rng.range(0...300) / pace)
                // ponytail: pairs are made only here, when the colony is, so they thin out over a day; a bee settling to
                // rest beside another could pair with it if they're missed
                if r > 0.90, let j = bees.indices.last, bees[j].state == .rest {
                    // face to face with the bee before, passing food
                    (b.state, bees[j].state, b.partner, bees[j].partner) = (.pair, .pair, j, bees.count)
                    b.heading = bees[j].heading + .pi
                    b.at = bees[j].at + SIMD2(cos(bees[j].heading), sin(bees[j].heading)) * length * 0.82
                    b.timer = rng.range(2...10)
                    bees[j].timer = b.timer
                }
            }
            bees.append(b)
        }
        // festoons: curtains of two or three strands hanging from the edge, three to six bees deep, heads up
        var placed = 0
        for i in bees.indices where placed < hanging && bees[i].state == .rest {
            guard let spot = hang() else { break }
            var b = bees[i]
            (b.at, b.target, b.job) = (spot, spot, .hang)
            arrive(&b)
            bees[i] = b
            placed += 1
        }
    }

    /// Where a bee would hang to join a festoon under the edge near `near` (or anywhere along it), or nil: under an edge
    /// cell, below the bees already hanging there, two or three abreast.
    private mutating func hang(near: SIMD2<Double>? = nil) -> SIMD2<Double>? {
        let anchors = edge.filter { near == nil || simd_distance(world.at[$0], near!) < 10 * length }
        guard let a = pick(anchors).map({ world.at[$0] }) else { return nil }
        let there = bees.count { ($0.state == .festoon || $0.job == .hang) && abs($0.target.x - a.x) < 0.7 * length && $0.target.y > a.y }
        let strands = 2 + Int(a.x / length) % 2, row = there / strands, strand = there % strands
        guard row < 6 else { return nil }
        let taper = 1 - Double(row) / 7
        return a + SIMD2((Double(strand) - Double(strands - 1) / 2) * length * 0.42 * taper + rng.range(-0.15...0.15) * length,
                         length * (0.3 + 0.55 * Double(row)) + rng.range(-0.1...0.1) * length)
    }

    private mutating func pick(_ list: [Int]) -> Int? { list.isEmpty ? nil : list[Int(rng.next() * Double(list.count)) % list.count] }

    /// A cell being worked that has room for one more bee (two at most), or nil.
    private mutating func pickTask(_ list: [Int]) -> Int? {
        for _ in 0..<10 { if let i = pick(list), taken[i, default: 0] < 2 { taken[i, default: 0] += 1; return i } }
        return nil
    }

    /// A place to rest: any drawn cell.
    private mutating func restPlace() -> SIMD2<Double> {
        (pick(drawn).map { world.at[$0] } ?? SIMD2(wide / 2, (seen.lowerBound + seen.upperBound) / 2)) + SIMD2(rng.range(-0.4...0.4), rng.range(-0.4...0.4)) * length / 2
    }

    /// Puts a bee to `job` at a cell for it, if one is free, posed for it.
    private mutating func settle(_ b: inout Bee, at job: Job) -> Bool {
        let list = job == .build ? building : job == .store ? filling : job == .cap ? capping : drawn
        guard let c = job == .groom ? pick(list) : pickTask(list) else { return false }
        (b.at, b.state, b.job, b.cell) = (world.at[c], .work, job, job == .groom ? -1 : c)
        b.pose = job == .store ? .headIn : job == .groom ? .groom : .stand
        if job == .store { b.heading = -.pi / 2 + rng.range(-0.7...0.7) }
        if job == .build { b.at += SIMD2(rng.range(-0.15...0.15) * length, length * 0.2) }
        return true
    }

    /// Sets a bee walking: to a cell being worked a short walk away (2.5 to 7 bee lengths), to join a festoon while
    /// there are too few, to sleep in an empty cell now and then, or anywhere drawn.
    private mutating func startWalk(_ b: inout Bee) {
        (b.state, b.job, b.cell) = (.walk, .none, -1)
        var goal: SIMD2<Double>?
        let hangingNow = bees.count { $0.state == .festoon || $0.job == .hang }
        if hangingNow < festoons, rng.next() < 0.4, let spot = hang(near: b.at) { (goal, b.job) = (spot, .hang) }
        if goal == nil, rng.next() < 0.04, let c = pick(empty.filter { simd_distance(world.at[$0], b.at) < 7 * length }) { (goal, b.job) = (world.at[c], .sleep) }
        for _ in 0..<12 where goal == nil {
            let r = rng.next(), job: Job = r < 0.3 ? .build : r < 0.6 ? .store : r < 0.75 ? .cap : .groom
            let list = job == .build ? building : job == .store ? filling : job == .cap ? capping : drawn
            guard let i = r < 0.75 ? pickTask(list) : pick(list) else { continue }
            let d = simd_distance(world.at[i], b.at)
            if d > 2.5 * length && d < 7 * length { (goal, b.job) = (world.at[i], job) } else if r < 0.75 { taken[i, default: 1] -= 1 }
        }
        if goal == nil { goal = b.at + SIMD2(rng.range(-1...1), rng.range(-1...1)) * length }
        b.target = goal!
        if b.job != .hang {
            b.target.x = min(max(b.target.x, length), wide - length)
            b.target.y = min(max(b.target.y, seen.lowerBound + length * 0.6), seen.upperBound - length * 0.6)
        }
        b.speed = rng.range(2...5) * ppm * pace
    }

    /// What a bee does at the end of a walk: works, if it went to work, two times in three; hangs, sleeps, or rests.
    private mutating func arrive(_ b: inout Bee) {
        switch b.job {
        case .hang:
            (b.state, b.pose, b.timer) = (.festoon, .festoon, rng.range(600...2400) / pace)
            b.heading = -.pi / 2 + rng.range(-0.55...0.55)
        case .sleep:
            (b.state, b.pose, b.timer) = (.cell, .tipIn, rng.range(600...3600) / pace)
        case .none:
            (b.state, b.pose, b.timer) = (.rest, .stand, exp(rng.range(log(20)...log(300))) / pace)
        default:
            if rng.next() < 0.62 {
                (b.state, b.timer) = (.work, rng.range(20...90) / pace)
                b.pose = b.job == .store ? .headIn : b.job == .groom ? .groom : .stand
                if b.job == .store { b.heading = -.pi / 2 + rng.range(-0.7...0.7) }
            } else {
                if b.cell >= 0 { taken[b.cell, default: 1] -= 1 }
                (b.state, b.job, b.cell, b.pose, b.timer) = (.rest, .none, -1, .stand, exp(rng.range(log(20)...log(300))) / pace)
            }
        }
    }

    /// Moves the whole colony by `by` points down the stack: when a new comb goes in under the stack and every frame
    /// moves up one, the bees go with their frames.
    mutating func shift(by: Double) {
        for i in bees.indices { bees[i].at.y += by; bees[i].target.y += by; bees[i].cell = -1 }
        taken = [:]
    }

    /// One sixtieth of a second.
    mutating func step() {
        let dt = 1.0 / 60, turn = Double.pi / 4 * dt
        // The bees by squares of the stack a bee long, so that a walker giving way looks only at the nine round it.
        let low = seen.lowerBound - 6 * length, cols = Int(wide / length) + 3, rows = Int((seen.upperBound - low) / length) + 8
        var first = [Int](repeating: -1, count: cols * rows), after = [Int](repeating: -1, count: bees.count)
        func square(_ p: SIMD2<Double>) -> (Int, Int) {
            (min(max(Int(p.x / length) + 1, 0), cols - 1), min(max(Int((p.y - low) / length), 0), rows - 1))
        }
        for i in bees.indices {
            let (c, r) = square(bees[i].at)
            (after[i], first[r * cols + c]) = (first[r * cols + c], i)
        }
        for i in bees.indices {
            var b = bees[i]
            switch b.state {
            case .walk:
                let to = b.target - b.at
                var d = atan2(to.y, to.x) - b.heading
                d = atan2(sin(d), cos(d))
                var v = b.speed
                let (c, r) = square(b.at), forward = SIMD2(cos(b.heading), sin(b.heading))
                for row in max(r - 1, 0)...min(r + 1, rows - 1) {
                    for col in max(c - 1, 0)...min(c + 1, cols - 1) {
                        var j = first[row * cols + col]
                        while j >= 0 {
                            let o = bees[j].at - b.at, ahead = simd_dot(o, forward), side = forward.x * o.y - forward.y * o.x
                            if j != i, ahead > 0, ahead < length * 0.8, abs(side) < length * 0.35 { v *= 0.3; d -= side >= 0 ? 0.8 : -0.8 }
                            j = after[j]
                        }
                    }
                }
                b.heading += max(-turn, min(turn, d))
                b.at += SIMD2(cos(b.heading), sin(b.heading)) * v * dt
                b.walked += v * dt
                b.pose = Pose(rawValue: Int(b.walked / (length * 0.42 / 4)) & 3)!
                if simd_length(b.target - b.at) < length * 0.3 { b.at = b.target; arrive(&b) }
            case .work, .rest, .pair, .cell, .festoon:
                b.timer -= dt
                if b.timer <= 0 {
                    if b.state == .work, b.cell >= 0 { taken[b.cell, default: 1] -= 1 }
                    b.partner = -1
                    startWalk(&b)
                }
            }
            bees[i] = b
        }
    }
}
