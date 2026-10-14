import LineRoute
import SpriteKit
import Synchronization

@MainActor func etching(size: CGSize) -> SKScene { Etching(size: size) }

/// A picture drawn in one unbroken line, as on the toy with two dials, whose stylus can never lift. An old print's
/// own outlines come first, then its shading as rows of hatching, the stylus going back along lines it has drawn
/// to get from place to place, which darkens them. A finished picture rests, clears as a shake would, unevenly and
/// leaving a ghost, and another begins over it as the ghost fades. It is drawn on paper, on parchment, on a
/// blueprint's sheet, or on the toy's own screen of grey powder, where the stylus scrapes the powder off the back
/// of the glass and the line is the dark inside showing through (`surfaces`).
///
/// A picture is a shipped route (`LineRoute`, made by docs/etching/bake.py), stamped once into two textures:
/// when each texel is first drawn, and when it is gone over again. The shader compares those with a clock, so a
/// frame costs the same however much is drawn. The clock is the wall's (`Cycle`): the picture goes on from where it
/// was after a relaunch or Shuffle, and every display shows the same moment of it.
/// docs/etching.md has the measurements of the real toy, the route's format and the sources.
final class Etching: SKScene {
    /// The set: each picture's name in the Picture menu, and its route's file (`etching-<file>.route`). Each one's
    /// source and licence is in Resources/etching-credits.tsv and docs/etching.md. The menu's pick is stored by
    /// place, so a new picture goes at the end and none is moved; the menu lists them by name (`listed`).
    nonisolated static let pictures: [(name: String, file: String)] = [
        ("The Great Wave", "wave"), ("The Rhinoceros", "rhinoceros"), ("A Flea", "flea"), ("Interlace", "interlace"),
        ("Flying Machine", "flyer"), ("Mishima Pass", "mishima"),
        ("Velocipede", "velocipede"), ("Airship", "airship"), ("Polyhedra", "polyhedra"), ("Kajikazawa", "kajikazawa"),
        ("Twelve-Pointed Stars", "stars"), ("Woven Bands", "bands"), ("Pont Neuf (Fine only)", "pontneuf"),
        ("Villa Rotonda", "rotonda"), ("An Ant", "ant"), ("Crystal Palace Fanlight", "fanlight"), ("Crystal Palace", "crystal"),
        ("Tycho's Observatory", "stjerneborg"), ("Reflecting Telescope", "telescope"), ("Printing Press", "press"), ("Waterworks", "waterworks"),
        ("Paddle Steamer", "steamer"), ("Air Balloons", "balloons"), ("Cayley's Flying Machine", "cayley"), ("Road Engine", "roadengine"),
        ("Ship Draught", "draught"), ("Bridge Centres", "centres"),
        ("Leonardo's Aerial Screw", "screw"), ("Leonardo's Bear", "bear"), ("Leonardo's Wing", "wing"), ("Ramelli's Fountain", "fountain"),
        ("Glass Furnaces", "furnaces"), ("Peacock Clock", "peacocks"), ("Dragon Engine", "dragon"),
    ]
    /// The Picture menu's order, which is not the one its picks are stored by: Random, then every picture by its
    /// name, a leading "The", "A" or "An" left out of the comparison. Worked out from the names, so a new picture
    /// needs no placing.
    nonisolated static let listed: [Int] = {
        func sorting(_ name: String) -> String { ["The ", "A ", "An "].first { name.hasPrefix($0) }.map { String(name.dropFirst($0.count)) } ?? name }
        return [0] + pictures.indices.sorted { sorting(pictures[$0].name).localizedStandardCompare(sorting(pictures[$1].name)) == .orderedAscending }.map { $0 + 1 }
    }()
    /// The pictures that are whole or not at all, by their files: cut off at a display's edges one would lose what
    /// makes it (the Airship, both rounded ends of its hull), so it is fitted inside whatever Fill the screen says.
    nonisolated static let whole: Set = ["airship"]
    /// Which picture: Random, a different one each time, or one of the set over and over. Picking one clears the
    /// screen for it there and then.
    nonisolated static let picture = Knob(key: "etching.picture", label: "Picture", range: 0...Double(pictures.count), standard: 0, section: "Drawing",
                                          format: .choice(["Random"] + pictures.map(\.name)), order: listed)
    /// The line's width: the toy's own, about 1/700 of the screen's width, or half that, which holds twice the
    /// detail each way, takes about twice as long, and looks more like a fine pen than the toy (`etching-<file>-fine.route`).
    nonisolated static let detail = Knob(key: "etching.detail", label: "Detail", range: 0...1, standard: 0, section: "Drawing", format: .choice(["Standard", "Fine"]))
    /// How many times faster than a careful hand: at 1 the stylus crosses a fortieth of the screen's width a
    /// second as it draws and a picture takes up to an hour and a half (three, fine; four for the one that is
    /// fine only); at the top the longest is done in about four minutes.
    nonisolated static let speed = Knob(key: "etching.speed", label: "Speed", range: 1...60, standard: 1, section: "Drawing", format: .times)
    /// How long a finished picture is left to be looked at before it clears, whatever the Speed: one of `holds`.
    nonisolated static let hold = Knob(key: "etching.hold", label: "Hold when finished", range: 0...3, standard: 1, section: "Drawing",
                                       format: .choice(["10 seconds", "30 seconds", "1 minute", "5 minutes"]))
    /// The seconds each of that menu's picks stands for, and the picked one's.
    nonisolated static let holds = [10.0, 30, 60, 300]
    private static var rest: Double { holds[Int(hold.value)] }
    /// What the picture is drawn on, one of `surfaces`: paper, unless another is picked. Stored by place.
    nonisolated static let surface = Knob(key: "etching.surface", label: "Surface", range: 0...Double(surfaces.count - 1), standard: 0, section: "Drawing",
                                          format: .choice(surfaces.map(\.name)))
    /// Which of the surface's two tones: the light one, the dark one, whichever suits the system's appearance, or
    /// light by day and dark by night, by the real Sun where the Mac is. Light is the standard, as every mock-up
    /// was, whatever the system is in. The pick is stored by place, so a new one goes at the end.
    nonisolated static let screen = Knob(key: "etching.screen", label: "Screen", range: 0...3, standard: 0, section: "Drawing",
                                         format: .choice(["Light", "Dark", "Match System", "Follow Day and Night"]))
    /// Where `shade` goes with the Sun at an altitude in degrees, for Follow Day and Night: 0, the light tone, from
    /// 6° above the horizon, and 1, the dark one, from 6° below. `tint` eases `shade`, so the ground's darkness is
    /// a smoothstep between the two, dusk takes about an hour, and nothing steps.
    nonisolated static func nightfall(sun altitude: Double) -> Double { min(max(0.5 - altitude / 12, 0), 1) }
    /// The Sun's altitude in degrees at a wall-clock moment, where the Mac is (a guess from the time zone, without
    /// leave to know), worked out as Flowing Gradient's is. `etching.sun` stands in for it, for the tests and for
    /// pictures.
    private static func sun(at wall: Double) -> Double {
        if let asked = UserDefaults.standard.object(forKey: "etching.sun") as? Double { return asked }
        let here = Location.shared.coordinate, jd = Sky.julianDate(Date(timeIntervalSinceReferenceDate: wall))
        return asin((Sky.horizonMatrix(jd: jd, latitude: here.latitude, longitude: here.longitude) * Sky.sun(jd)).z) * 180 / .pi
    }
    /// Whether the picture is scaled up until it covers the display, what is over cut off at the edges, or is
    /// fitted inside it below the menu bar, with bare ground left beside it or above and below.
    nonisolated static let fill = Knob(key: "etching.fill", label: "Fill the screen", range: 0...1, standard: 1, section: "Drawing", format: .toggle)
    nonisolated static let knobs = [picture, detail, speed, hold, surface, screen, fill]

    /// A surface to draw on, in its light tone and its dark one: the bare ground and the line gone over (sRGB, as
    /// shares of 255), and the ground's tooth (`source`): a pixel's own noise and the soft tooth, each as one
    /// standard deviation of the ground's level, and how far a fibre is from it. A dark ground's tooth is the
    /// greater share of it, to be about as many levels. On three of the dark tones the line is the lighter of the
    /// two: chalk on charcoal paper, and the white line of a blueprint.
    struct Surface: Sendable {
        typealias Tones = (light: SIMD3<Float>, dark: SIMD3<Float>)
        var name: String
        var ground: Tones, line: Tones, tooth: Tones

        /// This surface a share of the way to another, for easing from the one to the other.
        func mixed(with other: Surface, _ share: Float) -> Surface {
            func mix(_ a: Tones, _ b: Tones) -> Tones { (simd_mix(a.light, b.light, SIMD3(repeating: share)), simd_mix(a.dark, b.dark, SIMD3(repeating: share))) }
            return Surface(name: other.name, ground: mix(ground, other.ground), line: mix(line, other.line), tooth: mix(tooth, other.tooth))
        }
    }
    nonisolated private static func tone(_ r: Float, _ g: Float, _ b: Float) -> SIMD3<Float> { SIMD3(r, g, b) / 255 }
    /// The surfaces, in the Surface menu's order, which is stored by place: a new one goes at the end. Powder is
    /// the toy's own screen, whose levels docs/etching.md measures against photos of the real one.
    nonisolated static let surfaces = [
        Surface(name: "Paper", ground: (tone(236, 230, 216), tone(58, 56, 53)), line: (tone(36, 33, 31), tone(228, 224, 214)), tooth: ([0.009, 0.008, 0.025], [0.020, 0.024, 0.05])),
        Surface(name: "Parchment", ground: (tone(216, 199, 165), tone(74, 58, 42)), line: (tone(62, 42, 27), tone(232, 216, 184)), tooth: ([0.011, 0.010, 0.032], [0.020, 0.024, 0.05])),
        Surface(name: "Blueprint", ground: (tone(226, 232, 238), tone(24, 60, 116)), line: (tone(38, 72, 138), tone(232, 240, 248)), tooth: ([0.009, 0.008, 0.025], [0.020, 0.024, 0.05])),
        Surface(name: "Powder", ground: (tone(152, 154, 151), tone(104, 106, 104)), line: (tone(50, 52, 54), tone(34, 35, 37)), tooth: ([0.009, 0.008, 0.025], [0.013, 0.015, 0.035])),
    ]

    /// A picture's route at one of the two widths of line.
    private static func route(_ picture: Int, fine: Bool) -> Data? {
        try? Data(contentsOf: resource("etching-\(pictures[picture].file)\(fine || fineOnly[picture] ? "-fine" : "").route"))
    }
    /// Whether a picture ships with no route for the standard line, being a muddle at that width: it is drawn
    /// fine whatever Detail says, its name in the menu says so, and Random draws it only while Detail is Fine.
    static let fineOnly: [Bool] = pictures.map { !FileManager.default.fileExists(atPath: resource("etching-\($0.file).route").path) }
    /// The pictures Random may draw at one width of line.
    static func choices(detailed: Bool) -> [Int] {
        pictures.indices.filter { seconds[detailed ? 1 : 0][$0] > 0 && (detailed || !fineOnly[$0]) }
    }

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

    /// Where a route's grid goes in textures `across` by `down` texels: the texels to a cell, the grid's top left
    /// corner in from the textures' own, and the texels at the top that the menu bar covers with line under them.
    /// Fitted, the whole grid is inside, below the menu bar's band and centred there (a frame, later, would give
    /// it a smaller rectangle here). Filling, the picture's own rectangle on the grid covers the textures, centred:
    /// what is over lies outside them, and its top is under the menu bar, and a step takes no time in either.
    /// Whether a picture fills the screen when Fill the screen is `asked` for: all do but those kept whole.
    nonisolated static func fills(_ picture: Int, asked: Bool) -> Bool { asked && !whole.contains(pictures[picture].file) }
    nonisolated static func placement(of route: LineRoute, across: Int, down: Int, fill: Bool) -> (scale: Double, dx: Double, dy: Double, covered: Double) {
        let (w, h) = (Double(across), Double(down)), rect = route.rect, top = bar * h
        guard fill else {
            let scale = min(w / Double(route.columns), (h - top) / Double(route.rows))
            return (scale, (w - Double(route.columns) * scale) / 2, top + (h - top - Double(route.rows) * scale) / 2, 0)
        }
        let scale = max(w / Double(rect.w), h / Double(rect.h))
        return (scale, w / 2 - (Double(rect.x) + Double(rect.w) / 2) * scale, h / 2 - (Double(rect.y) + Double(rect.h) / 2) * scale, top)
    }

    /// Which picture is on the screen and how far along it is, by the wall clock: it is drawn, rests, clears, and
    /// the next begins. One of these is shared by every copy of the scene, each display and Settings' preview, and
    /// kept in the defaults, so that the picture goes on from where it was whatever builds a scene.
    struct Cycle: Equatable {
        /// The picture being drawn and the one before it, whose ghost is left, by their places in the set.
        var picture: Int, before: Int?
        /// The wall-clock moment, in seconds since the reference date, this picture would have been begun at speed
        /// `paced`, and the seconds it rests once drawn. Moving the Speed slider moves `began`, so the picture stays
        /// as far along as it is; another pick of the rest moves it only for a picture that is past resting.
        var began: Double, paced: Double, rested: Double
        /// The picture to follow, chosen as this one starts to clear so that every display clears to the same one.
        var following: Int?
        /// The Picture menu's pick when last looked at: 0 for Random.
        var picked: Int

        /// Seconds a clearing takes, whatever the speed: a soft fade, never a flash.
        static let clearing = 12.0
        /// Seconds of drawing, at speed 1, over which the ghost of the picture before fades away under the new one.
        static let ghosting = 360.0

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

        /// Moves on to the wall-clock moment `wall`, given the slider's speed, the seconds a finished picture rests,
        /// the menu's pick, each picture's seconds at speed 1 and a way to choose another picture than the one given.
        mutating func moment(at wall: Double, speed: Double, rest: Double, pick: Int, seconds: [Double], another: (Int) -> Int) -> Moment {
            func whole(_ picture: Int) -> Double { seconds[picture] / speed + rest + Self.clearing }
            if speed != paced { // as much is drawn, or as long rested, as was; it goes on from there at the new speed
                let since = wall - began, drawing = seconds[picture] / paced
                began = since < drawing ? wall - since * paced / speed : wall - seconds[picture] / speed - (since - drawing)
                paced = speed
            }
            if rest != rested { // a clearing goes on from where it is; a picture that has rested the new time clears from now
                let past = wall - began - seconds[picture] / speed
                if past >= rested { began += rested - rest } else if past > rest { began = wall - seconds[picture] / speed - rest }
                rested = rest
            }
            if pick != picked { // a picture picked by name follows at once: this one clears now
                picked = pick
                following = pick > 0 ? pick - 1 : nil
                let untilClearing = seconds[picture] / speed + rest
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
            let cleared = min(max((since - drawing - rest) / Self.clearing, 0), 1)
            if cleared > 0, following == nil { following = pick > 0 ? pick - 1 : another(picture) }
            return Moment(picture: picture, before: before, drawn: drawing > 0 ? min(since / drawing, 1) : 1, cleared: cleared, following: cleared > 0 ? following : nil)
        }
    }

    /// The one cycle every copy of the scene follows, the width of line it was last worked out for, and what of it
    /// was last saved.
    private static var cycle: Cycle?, fine: Bool?, saved: [String] = []

    /// The shared cycle's moment at `wall`, read from the defaults the first time and saved back whenever it moves
    /// to another picture or a setting moves it.
    private static func moment(at wall: Double) -> Cycle.Moment {
        let speed = Self.speed.value, pick = Int(Self.picture.value), defaults = UserDefaults.standard
        let detailed = Self.detail.value > 0.5, seconds = Self.seconds[detailed ? 1 : 0]
        func place(_ key: String) -> Int? { defaults.string(forKey: key).flatMap { file in pictures.firstIndex { $0.file == file } } }
        func another(than picture: Int) -> Int { choices(detailed: detailed).filter { $0 != picture }.randomElement() ?? picture }
        if cycle == nil {
            if let picture = place("etching.drawing"), let began = defaults.object(forKey: "etching.began") as? Double {
                cycle = Cycle(picture: picture, before: place("etching.before"), began: began, paced: speed, rested: rest, following: nil, picked: pick)
            } else {
                cycle = Cycle(picture: pick > 0 ? pick - 1 : another(than: -1), before: nil, began: wall, paced: speed, rested: rest, following: nil, picked: pick)
            }
        }
        if let was = fine, was != detailed { cycle!.stretch(at: wall, from: Self.seconds[was ? 1 : 0][cycle!.picture], to: seconds[cycle!.picture]) }
        fine = detailed
        let moment = cycle!.moment(at: wall, speed: speed, rest: rest, pick: pick, seconds: seconds, another: another)
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

    /// What a pair of textures holds: a picture's line at one width, fitted or filling, and the ghost of the one
    /// before it.
    private struct Held: Equatable {
        var picture: Int, ghost: Int?, fine: Bool, fill: Bool
    }

    private let sprite = SKSpriteNode()
    private let clock = SKUniform(name: "u_clock", float: 0), show = SKUniform(name: "u_show", float: 0), clear = SKUniform(name: "u_clear", float: 0)
    /// How much of the ghost is left.
    private let ghost = SKUniform(name: "u_ghost", float: 1)
    private let texels = SKUniform(name: "u_tex", vectorFloat2: [1, 1])
    /// A texel that was never drawn and holds no ghost, until a route is stamped.
    private let when = SKUniform(name: "u_when", texture: SKTexture(data: Data([255, 255, 255, 0]), size: CGSize(width: 1, height: 1)))
    private let more = SKUniform(name: "u_more", texture: SKTexture(data: Data([255, 255, 0, 255]), size: CGSize(width: 1, height: 1))) // (never gone over, no ghost)
    /// The bare ground, the line gone over, and the ground's tooth, as `tint` sets them.
    private let ground = SKUniform(name: "u_ground", vectorFloat3: .zero), ink = SKUniform(name: "u_ink", vectorFloat3: .zero), tooth = SKUniform(name: "u_tooth", vectorFloat3: .zero)
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
    /// How far the ground is from its light tone, 0, to its dark one, 1, on its way to the one Settings asks for;
    /// how far the line is, which crosses by itself (`update`); and the system's appearance, watched, for Match
    /// System.
    private var shade = 0.0, inked = 0.0, dark = false, appearance: NSKeyValueObservation?, lastWall: Double?
    /// The surface on the screen, which is the one picked in Settings but for the two seconds after another is
    /// picked: then it is part of the way there (`turned`, from 0 to 1) from what was on the screen at that moment.
    private var shown = surfaces[0], from = surfaces[0], picked = 0, turned = 1.0
    /// For Follow Day and Night: where the Sun last put the shade, the wall-clock moment it was looked up (none
    /// while another pick is the one chosen), and whether the Mac has been asked where it is.
    private var night = 0.0, sunAt: Double?, located = false
    /// The shade Settings asks for: Light's or Dark's, Dark Mode's under Match System, or the Sun's.
    private var wanted: Double {
        switch Int(Self.screen.value) {
        case 0: 0
        case 1: 1
        case 2: dark ? 1 : 0
        default: night
        }
    }

    private static let grain: SKTexture = {
        let tile = SKTexture(data: LineRoute.grain(), size: CGSize(width: 512, height: 512))
        tile.filteringMode = .linear
        return tile
    }()

    override func sceneDidLoad() {
        picked = min(Int(Self.surface.value), Self.surfaces.count - 1)
        (shown, from) = (Self.surfaces[picked], Self.surfaces[picked])
        dark = systemIsDark
        night = Self.screen.value > 2.5 ? Self.nightfall(sun: Self.sun(at: Date.timeIntervalSinceReferenceDate)) : 0
        shade = wanted
        inked = shade > 0.5 ? 1 : 0
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
            SKUniform(name: "u_px", vectorFloat2: [Float(pixels.x), Float(pixels.y)]), SKUniform(name: "u_grain", texture: Self.grain),
            texels, when, more, clock, show, clear, ghost, ground, ink, tooth])
        addChild(sprite)

        let defaults = UserDefaults.standard, hooks = ["etching.drawn", "etching.cleared", "etching.ghost"].map { defaults.object(forKey: $0) as? Double }
        if hooks.contains(where: { $0 != nil }) { asked = (min(max(hooks[0] ?? 0, 0), 1), min(max(hooks[1] ?? 0, 0), 1), (hooks[2] ?? 0) > 0.5) }
    }

    /// Asks where the Mac is, once, and only while the Screen follows the Sun: the first time, macOS asks leave.
    private func locate() {
        guard !located, view != nil, Self.screen.value > 2.5 else { return }
        located = true
        Location.shared.start()
    }

    override func didMove(to view: SKView) { locate() }

    /// The ground, its tooth and the line, for the surface on the screen and where each is between its two tones.
    private func tint() {
        func eased(_ tones: Surface.Tones, _ along: Double) -> SIMD3<Float> { simd_mix(tones.light, tones.dark, SIMD3(repeating: Float(simd_smoothstep(0, 1, along)))) }
        ground.vectorFloat3Value = eased(shown.ground, shade)
        tooth.vectorFloat3Value = eased(shown.tooth, shade)
        ink.vectorFloat3Value = eased(shown.line, inked)
    }

    /// Starts stamping a picture's route over its ghost, off the main thread. The ghost's cover is the one the
    /// scene has if that picture is on the screen now; otherwise its route is stamped first, for the cover alone.
    private func stamp(_ wanted: Held) {
        let landing = Landing(), (across, down) = (wide, high)
        let places = [wanted.picture, wanted.ghost], files = places.map { place in place.flatMap { Self.route($0, fine: wanted.fine) } }
        let known = wanted.ghost == held?.picture && wanted.fine == held?.fine && wanted.fill == held?.fill ? cover : nil
        stamping = (wanted, landing)
        Task.detached(priority: .userInitiated) {
            func stamped(_ which: Int, over ghost: Data?) -> LineRoute.Stamped? {
                guard let place = places[which], let route = files[which].flatMap({ LineRoute($0) }) else { return nil }
                let at = Self.placement(of: route, across: across, down: down, fill: Self.fills(place, asked: wanted.fill))
                return route.stamp(width: across, height: down, scale: at.scale, dx: at.dx, dy: at.dy, covered: at.covered, over: ghost)
            }
            landing.arrive(stamped(0, over: known ?? stamped(1, over: nil)?.cover))
        }
    }

    override func update(_ currentTime: TimeInterval) {
        // The wall's clock, by way of the frame's own time: the two run together, but the tests' frames come
        // faster than real ones and their pictures have to be of their own moments.
        let wall = currentTime + Date.timeIntervalSinceReferenceDate - ProcessInfo.processInfo.systemUptime
        let passed = min(max(wall - (lastWall ?? wall), 0), 0.1)
        lastWall = wall
        if Self.screen.value < 2.5 {
            sunAt = nil
        } else if wall - (sunAt ?? -.infinity) >= 30 { // in which the Sun climbs or sinks an eighth of a degree at the most
            locate()
            (night, sunAt) = (Self.nightfall(sun: Self.sun(at: wall)), wall)
        }
        // To another tone, or another surface, over two seconds, under the picture, as Meander goes to the system's
        // other mode. The ground goes by the shade. The line has its own way across, to the dark tone's once the
        // shade is past a half and to the light tone's short of it: on three surfaces it is darker than the ground
        // in one tone and lighter in the other, and going by the shade it would be the ground's own colour, and the
        // picture gone, half-way through, which at dusk is a quarter of an hour.
        // ponytail: crossing, the line still passes through the ground's colour, for an instant of its two seconds;
        // take it round by another colour, or dip the whole picture, if that blink is ever seen at sunset.
        func toward(_ aim: Double, from value: Double) -> Double { abs(aim - value) <= passed / 2 ? aim : value + (aim > value ? passed / 2 : -passed / 2) }
        let chosen = min(Int(Self.surface.value), Self.surfaces.count - 1), lined = shade > 0.5 ? 1.0 : 0.0
        if chosen != picked { (from, picked, turned) = (shown, chosen, 0) }
        if shade != wanted || inked != lined || turned < 1 {
            (shade, inked, turned) = (toward(wanted, from: shade), toward(lined, from: inked), toward(1, from: turned))
            shown = from.mixed(with: Self.surfaces[picked], Float(simd_smoothstep(0, 1, turned)))
            tint()
        }

        let speed = Self.speed.value, rest = Self.rest, pick = Int(Self.picture.value), fine = Self.detail.value > 0.5, seconds = Self.seconds[fine ? 1 : 0]
        if let asked, own == nil {
            let picture = pick > 0 ? pick - 1 : 0, count = Self.pictures.count, drawing = seconds[picture] / speed
            let since = asked.cleared > 0 ? drawing + rest + asked.cleared * Cycle.clearing : asked.drawn * drawing
            own = Cycle(picture: picture, before: asked.ghost ? (picture + 1) % count : nil, began: wall - since, paced: speed, rested: rest,
                        following: asked.cleared > 0 ? (picture + 2) % count : nil, picked: pick)
        }
        let moment = own?.moment(at: wall, speed: speed, rest: rest, pick: pick, seconds: seconds) { ($0 + 1) % Self.pictures.count } ?? Self.moment(at: wall)

        // The textures for this moment, and, once the picture is clearing, the ones for the picture to follow, so
        // that it can begin on the frame the clearing ends.
        let fill = Self.fill.value > 0.5
        let now = Held(picture: moment.picture, ghost: moment.before, fine: fine, fill: fill), next = moment.following.map { Held(picture: $0, ghost: moment.picture, fine: fine, fill: fill) }
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
        // (the same picture at the other width of line, or the other fit, stays up, as far drawn, until its own textures land)
        bare = held?.picture != now.picture || held?.ghost != now.ghost

        clock.floatValue = Float(moment.drawn * LineRoute.end / 256)
        clear.floatValue = Float(moment.cleared)
        ghost.floatValue = Float(1 - simd_smoothstep(0, 1, moment.drawn * seconds[moment.picture] / Cycle.ghosting))
        show.floatValue = bare ? 0 : Float(simd_smoothstep(0, 1, (wall - (shownAt ?? wall)) / 0.4))
    }

    /// The shader: the textures of when each texel is first drawn and gone over again, against the clock, on the
    /// ground. A texture a shader reads is smoothed whatever its filtering is set to, and a time smoothed between
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
                    line += share * w.a * (0.62 * step(when24(w), u_clock) + 0.38 * step(again24(m), u_clock));
                    cover += share * w.a;
                    ghost += share * m.b;
                }
            }
        """ : """
            vec2 tc = (floor(v_tex_coord * u_tex) + 0.5) / u_tex;
            vec4 w = texture2D(u_when, tc), m = texture2D(u_more, tc);
            float line = w.a * (0.62 * step(when24(w), u_clock) + 0.38 * step(again24(m), u_clock));
            float cover = w.a, ghost = m.b;
        """
        return """
        // When a texel was first drawn, from three of its bytes, in 65,536ths of the picture's clock to a 256th of
        // one; and when it was gone over again, the same from the other texture's (its blue is the ghost).
        float when24(vec4 w) { return floor(w.r * 255.0 + 0.5) * 256.0 + floor(w.g * 255.0 + 0.5) + floor(w.b * 255.0 + 0.5) / 256.0; }
        float again24(vec4 m) { return floor(m.r * 255.0 + 0.5) * 256.0 + floor(m.g * 255.0 + 0.5) + floor(m.a * 255.0 + 0.5) / 256.0; }

        void main() {
        \(read)
            // The ground's tooth, at the display's own pixels whatever their size, so nothing in it is ever
            // magnified: a pixel's own noise; a soft tooth two or three pixels across; and sparse fibres a pixel
            // wide, one to a cell of each of two lattices of unlike pitch. The soft tooth is the grain tile's red,
            // read a texel to a pixel, twice, and from another part of the tile in each cell of each lattice, so
            // that nothing repeats. A pixel far from its cell's fibre skips the working out: most of them, and
            // half the cost. Nothing is larger than a fibre but the light from the upper left, of 2% each way.
            vec2 px = floor(v_tex_coord * u_px), at = px + 0.5, cell = floor(at / 53.0);
            vec4 n = hash42(px), h = hash42(cell + 17.0);
            float soft = texture2D(u_grain, (mod(px + floor(h.zw * 512.0), 512.0) + 0.5) / 512.0).r - 1.004, fibres = 0.0;
            vec2 d = at - (cell + 0.16 + 0.68 * h.xy) * 53.0;
            if (dot(d, d) < 72.0) {
                vec2 along = normalize(vec2(h.z, fract(h.z * 64.0)) - 0.5);
                float reach = 3.0 + 4.0 * fract(h.w * 16.0);
                fibres += (step(0.5, h.w) * 2.0 - 1.0) * max(0.0, 1.0 - length(d - along * clamp(dot(d, along), -reach, reach)));
            }
            at += 400.0;
            cell = floor(at / 61.0);
            h = hash42(cell + 130.0);
            soft += texture2D(u_grain, (mod(px + floor(h.zw * 512.0), 512.0) + 0.5) / 512.0).r;
            d = at - (cell + 0.16 + 0.68 * h.xy) * 61.0;
            if (dot(d, d) < 72.0) {
                vec2 along = normalize(vec2(h.z, fract(h.z * 64.0)) - 0.5);
                float reach = 3.0 + 4.0 * fract(h.w * 16.0);
                fibres += (step(0.5, h.w) * 2.0 - 1.0) * max(0.0, 1.0 - length(d - along * clamp(dot(d, along), -reach, reach)));
            }
            float tooth = u_tooth.x * (n.x + n.y - 1.0) * 2.449 + u_tooth.y * soft * 5.635 + u_tooth.z * fibres;
            // A line drawn once is pale and one gone over is the line's own tone. Clearing lays the ground back,
            // sooner in some places than others (by the tile's slow unevenness, stretched over the screen: a
            // pattern in time, never seen at rest), down to a faint ghost of the whole line, which then fades
            // away under the next picture's first minutes (u_ghost).
            float slow = (texture2D(u_grain, v_tex_coord).g - 0.502) * 0.0765;
            float gone = smoothstep(0.0, 0.4, u_clear - 0.6 * clamp(0.5 + slow * 20.0, 0.0, 1.0));
            float a = max(mix(line, 0.08 * cover, gone), 0.08 * ghost * u_ghost * (1.0 - gone)) * u_show;
            // The tooth is the ground's: a line darker than the ground takes it in its own measure, so its tone
            // is even, and one lighter than the ground takes no more levels of it than the ground has.
            vec3 tone = mix(u_ground, u_ink, a);
            gl_FragColor = vec4(tone * (1.0 + 0.02 * (v_tex_coord.y - v_tex_coord.x)) + tooth * min(tone, u_ground), 1.0);
        }
        """
    }
}
