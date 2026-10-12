import LineRoute
import SpriteKit
import Synchronization

@MainActor func etching(size: CGSize) -> SKScene { Etching(size: size) }

/// A picture drawn in one unbroken line on a screen of grey powder, as on the toy with two dials: the stylus scrapes
/// the powder off the back of the glass, so the line is the dark inside showing through, and it can never lift. An
/// old print's own outlines come first, then its shading as rows of hatching, the stylus going back along lines it
/// has drawn to get from place to place, which darkens them. A finished picture rests, clears as a shake would,
/// unevenly and leaving a ghost, and another begins over it.
///
/// A picture is a shipped route (`LineRoute`, made by docs/etching/bake.py), stamped once into two textures:
/// when each texel is first drawn, and when it is gone over again. The shader compares those with a clock, so a
/// frame costs the same however much is drawn. The clock is the wall's (`Cycle`): the picture goes on from where it
/// was after a relaunch or Shuffle, and every display shows the same moment of it.
/// docs/etching.md has the measurements of the real toy, the route's format and the sources.
final class Etching: SKScene {
    /// The set: each picture's name in the Picture menu, and its route's file (`etching-<file>.route`). Each one's
    /// source and licence is in Resources/etching-credits.tsv and docs/etching.md.
    nonisolated static let pictures: [(name: String, file: String)] = [
        ("The Great Wave", "wave"), ("The Rhinoceros", "rhinoceros"), ("A Flea", "flea"), ("Interlace", "interlace"),
        ("Flying Machine", "flyer"), ("Mishima Pass", "mishima"),
    ]
    /// Which picture: Random, a different one each time, or one of the set over and over. Picking one clears the
    /// screen for it there and then.
    nonisolated static let picture = Knob(key: "etching.picture", label: "Picture", range: 0...Double(pictures.count), standard: 0, section: "Drawing",
                                          format: .choice(["Random"] + pictures.map(\.name)))
    /// The line's width: the toy's own, about 1/700 of the screen's width, or half that, which holds twice the
    /// detail each way, takes about twice as long, and looks more like a fine pen than the toy (`etching-<file>-fine.route`).
    nonisolated static let detail = Knob(key: "etching.detail", label: "Detail", range: 0...1, standard: 0, section: "Drawing", format: .choice(["Standard", "Fine"]))
    /// How many times faster than a careful hand: at 1 the stylus crosses a fortieth of the screen's width a
    /// second and a picture takes up to two hours (four, fine); at the top one is done in two minutes (four).
    nonisolated static let speed = Knob(key: "etching.speed", label: "Speed", range: 1...60, standard: 1, section: "Drawing", format: .times)
    nonisolated static let knobs = [picture, detail, speed]

    /// A picture's route at one of the two widths of line.
    private static func route(_ picture: Int, fine: Bool) -> Data? { try? Data(contentsOf: resource("etching-\(pictures[picture].file)\(fine ? "-fine" : "").route")) }

    /// Screen widths the stylus crosses in a second at speed 1: an eighth of a turn of a dial a second on the toy.
    private static let pace = 1.0 / 40
    /// The share of the screen's height kept clear at the top: the menu bar's, which on a notched MacBook is 3.8%
    /// and would otherwise lie over the top of the picture's frame.
    nonisolated private static let bar = 0.04
    /// How long each picture takes at speed 1, in seconds, from its route's own clock, at the standard line's
    /// width and at the fine one's; none for one that can't be read.
    static let seconds: [[Double]] = [false, true].map { fine in
        pictures.indices.map { route($0, fine: fine).flatMap { LineRoute($0, walking: false) }.map { $0.clock / (Double($0.columns) * pace) } ?? 0 }
    }

    /// Which picture is on the screen and how far along it is, by the wall clock: it is drawn, rests, clears, and
    /// the next begins. One of these is shared by every copy of the scene, each display and Settings' preview, and
    /// kept in the defaults, so that the picture goes on from where it was whatever builds a scene.
    struct Cycle: Equatable {
        /// The picture being drawn and the one before it, whose ghost is left, by their places in the set.
        var picture: Int, before: Int?
        /// The wall-clock moment, in seconds since the reference date, this picture would have been begun at speed
        /// `paced`. Moving the Speed slider moves it, so the picture stays as far along as it is.
        var began: Double, paced: Double
        /// The picture to follow, chosen as this one starts to clear so that every display clears to the same one.
        var following: Int?
        /// The Picture menu's pick when last looked at: 0 for Random.
        var picked: Int

        /// Seconds a clearing takes, whatever the speed: a soft fade, never a flash.
        static let clearing = 12.0
        /// Seconds a finished picture is left to be looked at: five minutes at speed 1, less when it is hurried.
        static func rest(at speed: Double) -> Double { max(20, 300 / speed) }

        /// A moment of it: the picture and the one before; the share of it drawn; how far it has cleared (0 while
        /// it is drawn and rests); and the picture to follow, once it is clearing.
        struct Moment: Equatable {
            var picture: Int, before: Int?, drawn: Double, cleared: Double, following: Int?
        }

        /// The picture now takes `new` seconds at speed 1 where it took `old` (the other width of line): it stays
        /// the same share drawn, or as long rested.
        mutating func stretch(at wall: Double, from old: Double, to new: Double) {
            let since = wall - began, drawing = old / paced
            began = since < drawing && drawing > 0 ? wall - since / drawing * new / paced : wall - new / paced - (since - drawing)
        }

        /// Moves on to the wall-clock moment `wall`, given the slider's speed, the menu's pick, each picture's
        /// seconds at speed 1 and a way to choose another picture than the one given.
        mutating func moment(at wall: Double, speed: Double, pick: Int, seconds: [Double], another: (Int) -> Int) -> Moment {
            func whole(_ picture: Int) -> Double { seconds[picture] / speed + Self.rest(at: speed) + Self.clearing }
            if speed != paced { // as much is drawn, or as long rested, as was; it goes on from there at the new speed
                let since = wall - began, drawing = seconds[picture] / paced
                began = since < drawing ? wall - since * paced / speed : wall - seconds[picture] / speed - (since - drawing)
                paced = speed
            }
            if pick != picked { // a picture picked by name follows at once: this one clears now
                picked = pick
                following = pick > 0 ? pick - 1 : nil
                let untilClearing = seconds[picture] / speed + Self.rest(at: speed)
                if pick > 0, pick - 1 != picture, wall - began < untilClearing { began = wall - untilClearing }
            }
            var turns = 0
            while wall - began >= whole(picture) { // on to the next picture, as often as the clock says
                began += whole(picture)
                (before, picture, following) = (picture, following ?? (pick > 0 ? pick - 1 : another(picture)), nil)
                turns += 1
                if turns > 500 { began = wall } // away for weeks: begin afresh
            }
            let since = max(wall - began, 0), drawing = seconds[picture] / speed
            let cleared = min(max((since - drawing - Self.rest(at: speed)) / Self.clearing, 0), 1)
            if cleared > 0, following == nil { following = pick > 0 ? pick - 1 : another(picture) }
            return Moment(picture: picture, before: before, drawn: drawing > 0 ? min(since / drawing, 1) : 1, cleared: cleared, following: cleared > 0 ? following : nil)
        }
    }

    /// The one cycle every copy of the scene follows, the width of line it was last worked out for, and what of it
    /// was last saved.
    private static var cycle: Cycle?, fine: Bool?, saved: [String] = []

    /// The shared cycle's moment at `wall`, read from the defaults the first time and saved back whenever it moves
    /// to another picture or the slider moves it.
    private static func moment(at wall: Double) -> Cycle.Moment {
        let speed = Self.speed.value, pick = Int(Self.picture.value), defaults = UserDefaults.standard
        let detailed = Self.detail.value > 0.5, seconds = Self.seconds[detailed ? 1 : 0]
        func place(_ key: String) -> Int? { defaults.string(forKey: key).flatMap { file in pictures.firstIndex { $0.file == file } } }
        func another(than picture: Int) -> Int { pictures.indices.filter { $0 != picture && seconds[$0] > 0 }.randomElement() ?? picture }
        if cycle == nil {
            if let picture = place("etching.drawing"), let began = defaults.object(forKey: "etching.began") as? Double {
                cycle = Cycle(picture: picture, before: place("etching.before"), began: began, paced: speed, following: nil, picked: pick)
            } else {
                cycle = Cycle(picture: pick > 0 ? pick - 1 : another(than: -1), before: nil, began: wall, paced: speed, following: nil, picked: pick)
            }
        }
        if let was = fine, was != detailed { cycle!.stretch(at: wall, from: Self.seconds[was ? 1 : 0][cycle!.picture], to: seconds[cycle!.picture]) }
        fine = detailed
        let moment = cycle!.moment(at: wall, speed: speed, pick: pick, seconds: seconds, another: another)
        let now = [pictures[cycle!.picture].file, cycle!.before.map { pictures[$0].file } ?? "", String(cycle!.began)]
        if now != saved {
            saved = now
            defaults.set(now[0], forKey: "etching.drawing")
            defaults.set(now[1], forKey: "etching.before")
            defaults.set(cycle!.began, forKey: "etching.began")
        }
        return moment
    }

    /// A stamped route, handed from the thread that made it to the scene's next frame.
    private final class Landing: Sendable {
        private let stamped = Mutex<LineRoute.Stamped?>(nil), ready = DispatchSemaphore(value: 0)
        func arrive(_ made: LineRoute.Stamped?) { stamped.withLock { $0 = made }; ready.signal() }
        /// What has arrived, once. `waiting` holds the caller until it has: for the render tests, which draw their
        /// frames faster than a picture can be stamped.
        func take(waiting: Bool) -> LineRoute.Stamped? {
            if waiting { ready.wait(); ready.signal() }
            return stamped.withLock { made in defer { made = nil }; return made }
        }
    }

    /// What a pair of textures holds: a picture's line at one width, and the ghost of the one before it.
    private struct Held: Equatable {
        var picture: Int, ghost: Int?, fine: Bool
    }

    private let sprite = SKSpriteNode()
    private let clock = SKUniform(name: "u_clock", float: 0), show = SKUniform(name: "u_show", float: 0), clear = SKUniform(name: "u_clear", float: 0)
    private let texels = SKUniform(name: "u_tex", vectorFloat2: [1, 1])
    /// A texel that was never drawn and holds no ghost, until a route is stamped.
    private let when = SKUniform(name: "u_when", texture: SKTexture(data: Data([255, 255, 255, 0]), size: CGSize(width: 1, height: 1)))
    private let more = SKUniform(name: "u_more", texture: SKTexture(data: Data([255, 255, 0, 255]), size: CGSize(width: 1, height: 1)))
    private let screen = SKUniform(name: "u_screen", vectorFloat3: .zero), ink = SKUniform(name: "u_ink", vectorFloat3: .zero)
    /// The textures' size, and the grid's fit in them: texels to a cell of the standard grid of 1024 by 640.
    private var wide = 1, high = 1
    /// What the textures hold; this picture's cover, at their size, for the next one's ghost; a stamp being made;
    /// and one made ahead for the picture to follow.
    private var held: Held?, cover: Data?, stamping: (of: Held, landing: Landing)?, made: (of: Held, stamped: LineRoute.Stamped)?
    /// The wall-clock moment the picture last went in on a bare screen: it fades up from there.
    private var shownAt: Double?, bare = true
    /// What the tests and the pictures of it ask for as a scene is built: the share drawn (`etching.drawn`), how
    /// far cleared (`etching.cleared`), and whether another picture's ghost lies under it (`etching.ghost`).
    /// With any of them the scene keeps a cycle of its own, begun at its first frame, and saves nothing.
    private var asked: (drawn: Double, cleared: Double, ghost: Bool)?, own: Cycle?
    /// The mode the screen is in, 0 in Light and 1 in Dark, and on its way to the system's; and the system's, watched.
    private var shade = 0.0, dark = false, appearance: NSKeyValueObservation?, lastWall: Double?

    private static let grain: SKTexture = {
        let tile = SKTexture(data: LineRoute.grain(), size: CGSize(width: 512, height: 512))
        tile.filteringMode = .linear
        return tile
    }()

    override func sceneDidLoad() {
        dark = systemIsDark
        shade = dark ? 1 : 0
        tint()
        appearance = NSApplication.shared.observe(\.effectiveAppearance) { [weak self] _, _ in MainActor.assumeIsolated { self?.dark = systemIsDark } }
        // The display's own pixels, and a texel to each; from the 14-inch size up, a texel to two each way, which
        // is a pixel softer and a quarter of the memory (docs/etching.md, "Cost").
        let factor = NSScreen.screens.first { $0.frame.size == size }?.backingScaleFactor ?? 2
        let pixels = SIMD2(Double(size.width * factor).rounded(), Double(size.height * factor).rounded())
        let half = pixels.x * pixels.y > 6_500_000
        (wide, high) = (Int(pixels.x) / (half ? 2 : 1), Int(pixels.y) / (half ? 2 : 1))
        sprite.size = size
        sprite.anchorPoint = .zero
        sprite.shader = SKShader(source: shaderCommon + Self.source(half: half), uniforms: [
            SKUniform(name: "u_px", vectorFloat2: [Float(pixels.x), Float(pixels.y)]), SKUniform(name: "u_grains", float: Float(2560 / pixels.x)),
            SKUniform(name: "u_grain", texture: Self.grain), texels, when, more, clock, show, clear, screen, ink])
        addChild(sprite)

        let defaults = UserDefaults.standard, hooks = ["etching.drawn", "etching.cleared", "etching.ghost"].map { defaults.object(forKey: $0) as? Double }
        if hooks.contains(where: { $0 != nil }) { asked = (min(max(hooks[0] ?? 0, 0), 1), min(max(hooks[1] ?? 0, 0), 1), (hooks[2] ?? 0) > 0.5) }
    }

    /// The powder and the dark inside, for the mode the screen is in: 152 of 255 in a lit room and 104 in a dim
    /// one, the line a third as light (docs/etching.md, "Look").
    private func tint() {
        func tone(_ r: Float, _ g: Float, _ b: Float) -> SIMD3<Float> { SIMD3(r, g, b) / 255 }
        let mix = SIMD3<Float>(repeating: Float(simd_smoothstep(0, 1, shade)))
        screen.vectorFloat3Value = simd_mix(tone(152, 154, 151), tone(104, 106, 104), mix)
        ink.vectorFloat3Value = simd_mix(tone(50, 52, 54), tone(34, 35, 37), mix)
    }

    /// Starts stamping a picture's route over its ghost, off the main thread. The ghost's cover is the one the
    /// scene has if that picture is on the screen now; otherwise its route is stamped first, for the cover alone.
    private func stamp(_ wanted: Held) {
        let landing = Landing(), (across, down) = (wide, high)
        let files = [wanted.picture, wanted.ghost].map { place in place.flatMap { Self.route($0, fine: wanted.fine) } }
        let known = wanted.ghost == held?.picture && wanted.fine == held?.fine ? cover : nil
        stamping = (wanted, landing)
        Task.detached(priority: .userInitiated) {
            // The grid fitted to the screen below the menu bar's band and centred there; a frame, later, would
            // give it a smaller rectangle here.
            func stamped(_ file: Data?, over ghost: Data?) -> LineRoute.Stamped? {
                guard let route = file.flatMap({ LineRoute($0) }) else { return nil }
                let top = Self.bar * Double(down), scale = min(Double(across) / Double(route.columns), (Double(down) - top) / Double(route.rows))
                return route.stamp(width: across, height: down, scale: scale, dx: (Double(across) - Double(route.columns) * scale) / 2,
                                   dy: top + (Double(down) - top - Double(route.rows) * scale) / 2, over: ghost)
            }
            landing.arrive(stamped(files[0], over: known ?? stamped(files[1], over: nil)?.cover))
        }
    }

    override func update(_ currentTime: TimeInterval) {
        // The wall's clock, by way of the frame's own time: the two run together, but the tests' frames come
        // faster than real ones and their pictures have to be of their own moments.
        let wall = currentTime + Date.timeIntervalSinceReferenceDate - ProcessInfo.processInfo.systemUptime
        let passed = min(max(wall - (lastWall ?? wall), 0), 0.1)
        lastWall = wall
        if shade != (dark ? 1 : 0) { // to the system's other mode over two seconds, as Meander goes
            shade = dark ? min(shade + passed / 2, 1) : max(shade - passed / 2, 0)
            tint()
        }

        let speed = Self.speed.value, pick = Int(Self.picture.value), fine = Self.detail.value > 0.5, seconds = Self.seconds[fine ? 1 : 0]
        if let asked, own == nil {
            let picture = pick > 0 ? pick - 1 : 0, count = Self.pictures.count, drawing = seconds[picture] / speed
            let since = asked.cleared > 0 ? drawing + Cycle.rest(at: speed) + asked.cleared * Cycle.clearing : asked.drawn * drawing
            own = Cycle(picture: picture, before: asked.ghost ? (picture + 1) % count : nil, began: wall - since, paced: speed,
                        following: asked.cleared > 0 ? (picture + 2) % count : nil, picked: pick)
        }
        let moment = own?.moment(at: wall, speed: speed, pick: pick, seconds: seconds) { ($0 + 1) % Self.pictures.count } ?? Self.moment(at: wall)

        // The textures for this moment, and, once the picture is clearing, the ones for the picture to follow, so
        // that it can begin on the frame the clearing ends.
        let now = Held(picture: moment.picture, ghost: moment.before, fine: fine), next = moment.following.map { Held(picture: $0, ghost: moment.picture, fine: fine) }
        if let job = stamping, let stamped = job.landing.take(waiting: view == nil && job.of == now) {
            (made, stamping) = ((job.of, stamped), nil)
        }
        if held != now, let ready = made, ready.of == now {
            when.textureValue = SKTexture(data: ready.stamped.when, size: CGSize(width: ready.stamped.width, height: ready.stamped.height))
            more.textureValue = SKTexture(data: ready.stamped.more, size: CGSize(width: ready.stamped.width, height: ready.stamped.height))
            texels.vectorFloat2Value = [Float(ready.stamped.width), Float(ready.stamped.height)]
            (held, cover, made) = (now, ready.stamped.cover, nil)
            if bare { shownAt = wall }
        }
        if let wanted = held != now ? now : next, stamping?.of != wanted, made?.of != wanted { stamp(wanted) }
        // (the same picture at the other width of line stays up, as far drawn, until its own textures land)
        bare = held?.picture != now.picture || held?.ghost != now.ghost

        clock.floatValue = Float(moment.drawn * LineRoute.end / 256)
        clear.floatValue = Float(moment.cleared)
        show.floatValue = bare ? 0 : Float(simd_smoothstep(0, 1, (wall - (shownAt ?? wall)) / 0.4))
    }

    /// The shader: the textures of when each texel is first drawn and gone over again, against the clock, on the
    /// powder. A texture a shader reads is smoothed whatever its filtering is set to, and a time smoothed between
    /// a drawn texel and a bare one is a time when nothing happened, so every read is at a texel's centre. With a
    /// texel to each pixel that is one read of each texture; with a texel to two each way (`half`) it is the four
    /// round the pixel, each compared with the clock on its own and only then mixed.
    private static func source(half: Bool) -> String {
        let read = half ? """
            vec2 q = v_tex_coord * u_tex - 0.5, f = fract(q), b = floor(q);
            float line = 0.0, cover = 0.0, ghost = 0.0;
            for (float j = 0.0; j < 1.5; j += 1.0) {
                for (float i = 0.0; i < 1.5; i += 1.0) {
                    vec2 tc = (clamp(b + vec2(i, j), vec2(0.0), u_tex - 1.0) + 0.5) / u_tex;
                    vec4 w = texture2D(u_when, tc), m = texture2D(u_more, tc);
                    float share = mix(1.0 - f.x, f.x, i) * mix(1.0 - f.y, f.y, j);
                    line += share * w.a * (0.62 * step(when24(w), u_clock) + 0.38 * step(when16(m), floor(u_clock)));
                    cover += share * w.a;
                    ghost += share * m.b;
                }
            }
        """ : """
            vec2 tc = (floor(v_tex_coord * u_tex) + 0.5) / u_tex;
            vec4 w = texture2D(u_when, tc), m = texture2D(u_more, tc);
            float line = w.a * (0.62 * step(when24(w), u_clock) + 0.38 * step(when16(m), floor(u_clock)));
            float cover = w.a, ghost = m.b;
        """
        return """
        // When a texel was first drawn, from its three bytes, in 65,536ths of the picture's clock to a 256th of
        // one; and when it was gone over again, from two, in whole ones.
        float when24(vec4 w) { return floor(w.r * 255.0 + 0.5) * 256.0 + floor(w.g * 255.0 + 0.5) + floor(w.b * 255.0 + 0.5) / 256.0; }
        float when16(vec4 m) { return floor(m.r * 255.0 + 0.5) * 256.0 + floor(m.g * 255.0 + 0.5); }

        void main() {
        \(read)
            // The powder: its grain is its own size on the glass whatever the display's pixels (u_grains), with a
            // slow unevenness across the whole screen, light from the upper left, and a few bright specks.
            vec2 at = v_tex_coord * u_px * u_grains;
            float fine = (texture2D(u_grain, fract(at / 512.0)).r - 0.502) * 0.1275;
            float slow = (texture2D(u_grain, v_tex_coord).g - 0.502) * 0.1275;
            vec2 cell = floor(at / 48.0);
            vec4 h = hash42(cell);
            float speck = max(0.0, 1.0 - distance(at, (cell + 0.15 + 0.7 * h.xy) * 48.0) / 1.6);
            vec3 screen = u_screen * (1.0 + fine + slow + 0.05 * (v_tex_coord.y - v_tex_coord.x) + 0.3 * step(h.z, 0.12) * speck * speck);
            // A line drawn once is pale and one gone over is the dark inside. Clearing lays the powder back, sooner
            // in some places than others (by the slow unevenness), down to a faint ghost of the whole line; and
            // the ghost that was under it, of the picture before, goes for good.
            float gone = smoothstep(0.0, 0.4, u_clear - 0.6 * clamp(0.5 + slow * 12.0, 0.0, 1.0));
            float a = max(mix(line, 0.08 * cover, gone), 0.08 * ghost * (1.0 - gone));
            a = clamp(a * (1.0 + 6.0 * fine), 0.0, 1.0) * u_show;
            gl_FragColor = vec4(mix(screen, u_ink, a), 1.0);
        }
        """
    }
}
