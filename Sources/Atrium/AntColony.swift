import AntNest
import SpriteKit
import Synchronization

@MainActor func antColony(size: CGSize) -> SKScene { AntColony(size: size) }

/// A colony of ants digging its nest in a thin tank of blue gel, seen from the side with the display as its glass.
/// A farm lasts a day: at six in the morning the gel is whole and a few ants are on top of it; they sink a shaft,
/// branch it, open rooms, and carry what they dig up to lie round the mouths; by the next morning the nest is
/// finished, and another begins. The colony grows with its nest.
///
/// The nest is baked whole from the date (`Nest`, in the AntNest module): one map of when each cell is dug, as a
/// share of all the digging, so the shader shows the nest at any moment by comparing that map with one number and
/// a frame costs the same however much is dug. The number comes from the wall's clock (`farm`, `share`), so the
/// nest goes on from where it was after a relaunch or Shuffle, and every display shows the same moment of the
/// same nest. The ants are not what digs it: they are sent to the faces the map says are being worked
/// (`Colony`), and drawn as a body and its jointed legs, feet planted on the walls.
/// docs/ant-colony.md has the measurements of real ants and nests these follow, and the sources.
final class AntColony: SKScene {
    /// An ant's length on the display, in points, and in cells of the nest's map.
    nonisolated private static let antPoints = 22.0, antCells = 11.0
    /// The hour a farm begins.
    nonisolated static let dawn = 6.0

    /// The share of the digging done `hours` after a farm began: 8% in the first hour, 23% in three, 44% by noon,
    /// 75% by six in the evening and 94% by midnight, the last of it through the small hours. Real ants dig faster
    /// still at first (half of a day's digging in its first hour, docs/ant-colony.md), which would leave most of
    /// the day with nothing happening.
    nonisolated static func share(after hours: Double) -> Double {
        let left = 1 - min(max(hours / 24, 0), 1)
        return 1 - left * left
    }

    /// The farm of a moment of the wall's clock: the day it began on, as a number like 20261012, which is its
    /// seed, and the hours since it did.
    nonisolated static func farm(at wall: Double, calendar: Calendar = .current) -> (day: Int, hours: Double) {
        let morning = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: wall - dawn * 3600))
        let parts = calendar.dateComponents([.year, .month, .day], from: morning)
        let began = morning.timeIntervalSinceReferenceDate + dawn * 3600
        return ((parts.year ?? 0) * 10000 + (parts.month ?? 0) * 100 + (parts.day ?? 0), (wall - began) / 3600)
    }

    /// A farm as it comes off the thread that baked it: the nest, its ants some minutes into their work, the map
    /// and the spoil's heights as the shader reads them, and what the shader is told of each cell's surroundings
    /// at `quantum`.
    private struct Made: Sendable {
        var day: Int, nest: Nest, colony: Colony, map: Data, heap: Data, near: Data, quantum: Int
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

    /// One ant's sprites: its body, the eighteen lengths of its legs and four of its antennae, and the grain it
    /// may carry.
    @MainActor private final class Figure {
        let node = SKNode(), body = SKSpriteNode(texture: AntColony.silhouette), grain = SKSpriteNode(texture: AntColony.dot)
        let lines = (0..<22).map { _ in SKSpriteNode(texture: AntColony.line) }

        init() {
            let side = AntColony.silhouette.size().width / 2 // (painted at 2x)
            body.size = CGSize(width: side, height: side)
            body.zPosition = 1
            for (k, line) in lines.enumerated() {
                (line.color, line.colorBlendFactor) = (AntColony.dark, 1)
                line.zPosition = (k < 18 ? k < 9 : k < 20) ? 2 : 0 // the near side's over the body, the far side's under it
                node.addChild(line)
            }
            (grain.color, grain.colorBlendFactor, grain.zPosition) = (AntColony.crumb, 1, 3)
            grain.size = CGSize(width: 0.17 * AntColony.antPoints, height: 0.15 * AntColony.antPoints)
            node.addChild(body)
            node.addChild(grain)
        }
    }

    /// An ant against the gel is a shape with the light behind it; and a crumb of gel.
    private static let dark = NSColor(srgbRed: 5 / 255, green: 9 / 255, blue: 16 / 255, alpha: 1)
    private static let crumb = NSColor(srgbRed: 118 / 255, green: 172 / 255, blue: 240 / 255, alpha: 1)

    /// The body from the side, head to the right and feet down, its middle at the middle of a square 2.6 body
    /// lengths a side: gaster, the two nodes of the waist, mesosoma, head and jaws (`Build`), carried nose up.
    private static let silhouette: SKTexture = {
        let side = (2.6 * antPoints).rounded(.up)
        return paint(CGSize(width: side, height: side)) { context in
            context.translateBy(x: side / 2, y: side / 2)
            context.scaleBy(x: antPoints, y: antPoints)
            context.rotate(by: Build.pitch * .pi / 180)
            context.setFillColor(dark.cgColor)
            func blob(_ x: Double, _ y: Double, _ a: Double, _ b: Double, _ tilt: Double) {
                context.saveGState()
                context.translateBy(x: x, y: y)
                context.rotate(by: tilt * .pi / 180)
                context.fillEllipse(in: CGRect(x: -a, y: -b, width: 2 * a, height: 2 * b))
                context.restoreGState()
            }
            for part in [Build.gaster, Build.chest, Build.head] { blob(part.x, part.y, part.a, part.b, part.tilt) }
            for node in Build.waist { blob(node.x, node.y, node.r, node.r, 0) }
            blob(Build.head.x + Build.head.a * 0.78, Build.head.y - Build.head.b * 0.75, 0.035, 0.022, -50)
        }
    }()
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
    /// The nest's map, the spoil's heights and the surroundings: a single texel each until a nest lands, by when
    /// nothing is shown.
    private let map = SKUniform(name: "u_map", texture: SKTexture(data: Data([255, 255, 255, 255]), size: CGSize(width: 1, height: 1)))
    private let heap = SKUniform(name: "u_heap", texture: SKTexture(data: Data([0, 0, 255, 255]), size: CGSize(width: 1, height: 1)))
    private let near = SKUniform(name: "u_near", texture: SKTexture(data: Data([255, 255, 128, 255]), size: CGSize(width: 1, height: 1)))
    /// The tank in cells, a cell in points, and a pixel in points.
    private var cols = 1, rows = 1, cell = 2.0, pixel = 0.5
    /// The farm on the screen, and its ants' sprites and the grains they have dropped.
    private var day: Int?, nest: Nest?, colony: Colony?, figures: [Figure] = [], crumbs: [SKSpriteNode] = []
    /// A farm being baked; the surroundings being worked out for a later share of the digging; and the share the
    /// shader has them for, in 4000ths.
    private var baking: (day: Int, landing: Landing<Made>)?, shading: (quantum: Int, landing: Landing<Data>)?, shaded = -1
    /// When the farm on the screen landed, by the wall's clock and in the farm's own hours, and the sixtieths of a
    /// second its ants have been stepped through since; and the time of the scene's first frame.
    private var since = (wall: 0.0, hours: 0.0), ticked = 0, first: TimeInterval?
    /// What the tests and the pictures of it ask for as a scene is built: the farm of another day
    /// (`antcolony.day`, a number like 20261012) and the hours it has been going at the scene's first frame
    /// (`antcolony.hour`), from where it then runs.
    private var asked: (day: Int?, hour: Double?) = (nil, nil)

    override func sceneDidLoad() {
        let factor = NSScreen.screens.first { $0.frame.size == size }?.backingScaleFactor ?? 2
        // The map has a cell for every two points across the display, and as many rows as cover it.
        cols = max(Int((size.width / (Self.antPoints / Self.antCells)).rounded()), 8)
        cell = size.width / Double(cols)
        rows = max(Int((size.height / cell).rounded(.up)), 8)
        pixel = 1 / factor
        let ground = max(Int(Double(rows) * 0.17), Int(3 * Self.antCells)) // (where `Nest` puts it)
        medium.size = CGSize(width: size.width, height: Double(rows) * cell)
        medium.anchorPoint = CGPoint(x: 0, y: 1)
        medium.position = CGPoint(x: 0, y: size.height)
        medium.shader = SKShader(source: shaderCommon + Self.gel, uniforms: [
            SKUniform(name: "u_cells", vectorFloat3: [Float(cols), Float(rows), Float(ground)]), SKUniform(name: "u_bl", float: Float(Self.antCells)),
            SKUniform(name: "u_px", float: Float(size.width * factor)), SKUniform(name: "u_grain", texture: Self.grain), map, heap, near, dug, fade, show])
        addChild(medium)
        swarm.zPosition = 1
        addChild(swarm)
        backgroundColor = .black

        let defaults = UserDefaults.standard
        asked = ((defaults.object(forKey: "antcolony.day") as? Double).map { Int($0) }, defaults.object(forKey: "antcolony.hour") as? Double)
    }

    /// Starts baking the farm of `day`, with `share` of its digging done, off the main thread: the nest (70 ms for
    /// a 14-inch display), its ants ten minutes into their work, and the textures.
    private func bake(_ day: Int, share: Double) {
        let landing = Landing<Made>(), (cols, rows) = (cols, rows)
        baking = (day, landing)
        Task.detached(priority: .userInitiated) {
            let nest = Nest(seed: UInt64(day), cols: cols, rows: rows, bodyLength: Self.antCells)
            // (as many ants, grown, as leaves each about 130 square body lengths of tank: 24 on a 14-inch display)
            let most = max(Int(Double(cols * rows) / (Self.antCells * Self.antCells) / 128), 8)
            var colony = Colony(nest: nest, most: most, seed: UInt64(day), share: share)
            colony.fastForward(600)
            let quantum = Int(share * 4000)
            landing.arrive(Made(day: day, nest: nest, colony: colony, map: nest.bytes(), heap: nest.heights(), near: nest.surroundings(at: Double(quantum) / 4000), quantum: quantum))
        }
    }

    /// Where a point of the tank, in cells from its top left, is in the scene.
    private func point(_ at: SIMD2<Double>) -> CGPoint { CGPoint(x: at.x * cell, y: size.height - at.y * cell) }

    override func update(_ currentTime: TimeInterval) {
        // The wall's clock, by way of the frame's own time: the two run together, but the tests' frames come
        // faster than real ones and their pictures have to be of their own moments.
        let wall = currentTime + Date.timeIntervalSinceReferenceDate - ProcessInfo.processInfo.systemUptime
        let opened = first ?? currentTime
        first = opened
        var now = Self.farm(at: wall)
        if let asked = asked.day { now.day = asked }
        if let asked = asked.hour { now.hours = asked + (currentTime - opened) / 3600 }
        let share = Self.share(after: now.hours)

        // The farm for this day: baked when the scene is made, and again each morning at six.
        // ponytail: the finished farm gives way to the new one through black, in under half a second (`u_show`).
        // A crossfade needs both farms' textures at once; add it if the cut at six is ever noticed.
        if day != now.day, baking?.day != now.day { bake(now.day, share: share) }
        if let job = baking, let made = job.landing.take(waiting: view == nil) {
            let extent = CGSize(width: made.nest.cols, height: made.nest.rows)
            map.textureValue = SKTexture(data: made.map, size: extent)
            heap.textureValue = SKTexture(data: made.heap, size: CGSize(width: made.nest.cols, height: Nest.levels + 1))
            fade.floatValue = Float(made.nest.dug) / 10
            near.textureValue = SKTexture(data: made.near, size: extent)
            (day, nest, colony, baking, shading, shaded, since, ticked) = (made.day, made.nest, made.colony, nil, nil, made.quantum, (wall, now.hours), 0)
        }
        guard let nest, var colony else { return }
        defer { self.colony = colony }

        // The ants, in sixtieths of a second counted from when the farm landed, each with the share dug at its own
        // moment, so that they are where they are whatever the frame rate. After a gap (the display asleep, the
        // wallpaper covered) they are moved on without being watched, by two minutes at the most.
        let due = Int(((wall - since.wall) * 60).rounded())
        if due - ticked > 30 {
            colony.fastForward(min(Double(due - ticked) / 60, 120), share: share)
        } else if due > ticked {
            for tick in (ticked + 1)...due { colony.step(share: Self.share(after: since.hours + Double(tick) / 216_000)) }
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
        dug.floatValue = Float(share)
        show.floatValue = Float(simd_smoothstep(0, 1, (wall - since.wall) / 0.4 + (view == nil ? 1 : 0)))
        swarm.alpha = CGFloat(show.floatValue)

        // The ants and the grains they have dropped.
        while figures.count < colony.ants.count {
            figures.append(Figure())
            swarm.addChild(figures.last!.node)
        }
        for (n, figure) in figures.enumerated() {
            figure.node.isHidden = n >= colony.ants.count
            if n < colony.ants.count { pose(figure, as: colony.ants[n], bodyLength: nest.bodyLength) }
        }
        while crumbs.count < colony.grains.count {
            let crumb = SKSpriteNode(texture: Self.dot, color: Self.crumb, size: CGSize(width: 0.17 * Self.antPoints, height: 0.15 * Self.antPoints))
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
    /// over as it rolls, its nose dipped as it digs; each length of leg and antenna between its joints.
    private func pose(_ figure: Figure, as ant: Ant, bodyLength: Double) {
        let forward = CGVector(dx: ant.forward.x, dy: -ant.forward.y), up = CGVector(dx: ant.up.x, dy: -ant.up.y)
        let left: CGFloat = forward.dx * up.dy - forward.dy * up.dx >= 0 ? 1 : -1 // whether up is to the left of the way it faces
        figure.body.position = point(ant.position)
        figure.body.zRotation = atan2(forward.dy, forward.dx) - left * 3 * ant.nod
        // (end on it is a third as long as it is from the side; rolled over it is as thick seen from above)
        figure.body.xScale = max(cos(ant.yaw), 0.3)
        figure.body.yScale = left * (ant.flat < 0 ? -1 : 1) * max(abs(ant.flat), 0.85)
        figure.grain.isHidden = !ant.carrying
        figure.grain.position = point(ant.mouth(bodyLength: bodyLength))

        let limbs = ant.limbs(bodyLength: bodyLength)
        var next = 0
        func draw(_ joints: [SIMD2<Double>], widths: [Double]) {
            for (k, width) in widths.enumerated() where next < figure.lines.count {
                let (a, b) = (point(joints[k]), point(joints[k + 1])), line = figure.lines[next]
                // (a leg thinner than a pixel is drawn a pixel wide and that much fainter)
                let wide = width * Self.antPoints, thick = max(wide, pixel)
                line.position = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                line.zRotation = atan2(b.y - a.y, b.x - a.x)
                line.size = CGSize(width: hypot(b.x - a.x, b.y - a.y) + thick, height: 2 * thick)
                line.alpha = min(wide / pixel, 1)
                next += 1
            }
        }
        for leg in limbs.legs { draw(leg, widths: [0.034, 0.024, 0.016]) }
        next = 18
        for antenna in limbs.antennae { draw(antenna, widths: [0.020, 0.017]) }
    }

    /// The gel: a deep blue slab lit by lamps in its base, after the toy's gel tanks (docs/ant-colony.md has the
    /// two photographs it is matched to). The gel glows brighter toward the lamps; a tunnel is a frosted, paler
    /// tube with light gathered into a bright line at its edge, a halo in the gel beside it, a sheen and beads
    /// along its wet wall; small bubbles hang in the gel; what is dug lies on top as pale crumbs; and the air above
    /// is dark but for the glow that leaks up, against which an ant on the heap is a shape.
    ///
    /// A texture a shader reads is smoothed whatever its filtering is set to, and a rank smoothed between a dug
    /// cell and one never dug is a rank nothing has. So the map is read at the centres of the four cells round the
    /// pixel, each is compared with the share dug on its own (open by the time an ant may stand in it, and opening
    /// over the digging of the twenty cells before that, so a face creeps and never jumps a cell), and only then
    /// are they mixed; the edge is a pixel and a half soft by the mix's own slope. The spoil's top is its height
    /// read from `u_heap`. What cannot be had from a read or two (how near a wall is, and which way it faces) is
    /// in `u_near`.
    private static let gel = """
    float sq(float x) { return x * x; }

    void main() {
        // This pixel in cells from the tank's top left; in the air or below the ground line; pixels to a cell,
        // and to one of the pixels this was drawn for (an ant 44 of them long).
        vec2 cell = vec2(v_tex_coord.x, 1.0 - v_tex_coord.y) * u_cells.xy;
        float ground = u_cells.z, above = step(cell.y, ground), ppc = u_px / u_cells.x, px = u_bl * ppc / 44.0;

        // Dug: the four cells round this pixel (none of them above the ground line), each open or not.
        vec2 p = vec2(cell.x, max(cell.y, ground + 0.5)) - 0.5, base = floor(p), f = p - base;
        vec4 open;
        for (int k = 0; k < 4; k++) {
            vec2 corner = base + vec2(mod(float(k), 2.0), floor(float(k) / 2.0)) + 0.5;
            vec4 t = texture2D(u_map, vec2(corner.x, u_cells.y - corner.y) / u_cells.xy);
            float rank = (floor(t.r * 255.0 + 0.5) * 256.0 + floor(t.g * 255.0 + 0.5)) / 32767.5;
            open[k] = clamp((rank - u_dug) * u_fade - 1.0, -1.0, 1.0);
        }
        float s = mix(mix(open[0], open[1], f.x), mix(open[2], open[3], f.x), f.y);
        vec2 slope = vec2(mix(open[1] - open[0], open[3] - open[2], f.y), mix(open[2] - open[0], open[3] - open[1], f.x)) / ppc;
        float solid = clamp(0.5 + s / max(length(slope), 0.000001) / 1.5, 0.0, 1.0);
        // Buried: under the spoil's top at this column, at this share of the digging.
        vec2 level = vec2(v_tex_coord.x, (u_dug * 256.0 + 0.5) / 257.0);
        vec4 h0 = texture2D(u_heap, level), h1 = texture2D(u_heap, level + vec2(1.0 / u_px, 0.0));
        vec2 top = (vec2(h0.r, h1.r) * 65280.0 + vec2(h0.g, h1.g) * 255.0) / 65535.0 * 64.0;
        float buried = clamp(0.5 + (top.x - (ground - cell.y)) * ppc / sqrt(1.0 + sq((top.y - top.x) * ppc)) / 1.5, 0.0, 1.0);
        solid = mix(solid, buried, above);

        vec4 q = texture2D(u_near, vec2(cell.x, u_cells.y - cell.y) / u_cells.xy);
        float close = q.r, wide = q.g, lit = q.b * 2.0 - 1.0, hug = q.a;

        // Grain: a tile of noise, a texel of it to a 44th of an ant, and the same tile far larger for slow blots.
        vec2 g = cell / u_bl * 44.0;
        vec4 n = (texture2D(u_grain, fract(g / 256.0)) - 0.5) * 6.0;
        vec4 slow = (texture2D(u_grain, fract(g / 6144.0)) - 0.5) * 6.0;
        vec4 h = hash42(floor(g));

        float x = v_tex_coord.x, down = 1.0 - v_tex_coord.y;
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
        colour *= 1.0 - 0.38 * (sq(x - 0.5) + sq(down - 0.5));
        gl_FragColor = vec4(clamp(colour, 0.0, 1.0) * u_show, 1.0);
    }
    """
}
