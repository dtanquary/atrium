import SpriteKit

/// Pixel Window Seat on a train: the same window, at a seat on a slow train, with the country sliding past under
/// the real Sun, Moon and stars for your clock and place.
///
/// A thing `Z` metres from the track stands `focal / Z` pixels a metre and slides `focal × speed / Z` pixels a
/// second, whatever its height. From 3.5 m up nearly all of the country is seen edge-on, so the picture is not the
/// airliner's map of the ground but rings of things standing at fixed distances (`TrainWorld.rings`). Each ring is a
/// strip a pane wide that slides by whole pixels and lays a column once, as it comes in at the leading edge, as the
/// airliner's rows do; under them the ground is drawn a row at a time. It is painted far to near, the near over
/// the far.
final class PixelTrain: SKScene {
    /// 1× on Settings' Speed, in metres a second: 48 km/h, a slow scenic train.
    nonisolated static let pace = 48 / 3.6
    /// How high the eye is above the ground, in metres, and how far up the pane the horizon lies.
    nonisolated static let eye = 3.5, horizonUp = 0.3

    private let w: Int, h: Int // the canvas, in art pixels
    private let glass: (x: Int, y: Int, w: Int, h: Int) // the window's pane on it
    private let horizon: Int // the pane's row the horizon lies on, counted from its bottom; the rows below are ground
    private let windowSize: Int // Settings' Window, as the scene was built: 3 is none, the pane being the whole canvas
    private var world: TrainWorld
    private(set) var rings: [TrainRing] = [] // far to near
    // What each ring shows: for each of its columns a strip of materials up from its foot, and how many of them are
    // in use. A column keeps its place in the ring from the moment it slides in until it slides out.
    private var strips: [UInt8] = [], tops: [UInt8] = []
    private var rows: [GroundRow] = []
    private var land: [UInt8], dash: [UInt8] // the ground rows' materials, and which tone of its dash each pixel takes
    private var sky: [UInt32] = [], picture: [UInt32]
    private var ringColours: [UInt32] = [], groundColours: [UInt32] = [] // the colours of the moment, ready to copy
    private var lamp: UInt32 = 0, lights: UInt8 = 0 // a lamp's colour, and how far the evening has got: each comes on at its own draw
    private let texture: SKMutableTexture
    private let canvas = SKNode(), outside = SKSpriteNode(), cabin = SKSpriteNode()

    /// How far the train has got, in metres along its line, and the scene time that was true at. Every copy of the
    /// scene shares it, as the airliner's copies share their flight, so each display's window looks out over the
    /// same country. It starts from the clock: the train runs on while nobody is watching. (`TRAIN_AT=52000` in the
    /// environment starts it at that metre instead, so a picture can be taken of the same country again.)
    static var travelled = ProcessInfo.processInfo.environment["TRAIN_AT"].flatMap(Double.init)
        ?? Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 4_000_000) * pace
    private static var travelledAt: TimeInterval?
    private var settings: [Double] = []
    private var retired = false // it has handed over to another scene, and is fading out
    private var night: Float = 0
    private var clock: TimeInterval = 0, lastUpdate: TimeInterval?, painted: TimeInterval = -1
    private var redrawnAt = Date.distantPast // wall clock, as the airliner's: a wallpaper paused through sunset catches up at once

    override init(size: CGSize) {
        (w, h, glass, windowSize) = PixelWindowSeat.pane(size)
        let (gw, gh) = (glass.w, glass.h)
        horizon = gh - Int((Double(gh) * (1 - Self.horizonUp)).rounded())
        world = TrainWorld(focal: Double(gh) * 1.2, eye: Self.eye, speed: Self.pace * PixelWindowSeat.speed.value)
        (land, dash) = ([UInt8](repeating: 0, count: gw * horizon), [UInt8](repeating: 0, count: gw * horizon))
        picture = [UInt32](repeating: 0, count: gw * gh)
        texture = SKMutableTexture(size: CGSize(width: gw, height: gh))
        super.init(size: size)
        canvas.setScale(max(2, (size.height / 240).rounded())) // points per art pixel, as in Pixel City
        addChild(canvas)
        texture.filteringMode = .nearest
        outside.texture = texture
        outside.size = CGSize(width: gw, height: gh)
        outside.anchorPoint = .zero
        outside.position = CGPoint(x: glass.x, y: glass.y)
        (cabin.size, cabin.anchorPoint, cabin.zPosition, cabin.isHidden) = (CGSize(width: w, height: h), .zero, 2, windowSize == 3)
        canvas.addChild(outside)
        canvas.addChild(cabin)

        for k in TrainWorld.rings.indices {
            let perMetre = world.perMetre(k), tall = world.rows(k)
            rings.append(TrainRing(away: TrainWorld.rings[k], perMetre: perMetre, rows: tall,
                                   foot: horizon - Int((Self.eye * perMetre).rounded(.toNearestOrEven)), base: strips.count))
            strips += [UInt8](repeating: 0, count: tall * gw)
        }
        tops = [UInt8](repeating: 0, count: rings.count * gw)
        rows = (1...horizon).map { GroundRow(perMetre: Double($0) / Self.eye, tones: world.tones($0)) }
        ringColours = [UInt32](repeating: 0, count: rings.count * TrainMat.day.count)
        groundColours = [UInt32](repeating: 0, count: 25 * TrainMat.day.count)
        settings = PixelWindowSeat.knobs.map(\.value)
        redraw()
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged),
                                               name: UserDefaults.didChangeNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func didMove(to view: SKView) { Location.shared.start() }

    /// Repaints when one of the page's settings changes (the notification comes for every wallpaper's). Another
    /// window, or another size of this one, is another scene: it dissolves into it with both still running, as the
    /// airliner's changes do.
    @objc private func settingsChanged() {
        let picked = PixelWindowSeat.knobs.map(\.value)
        guard picked != settings, !retired else { return }
        settings = picked
        let another = PixelOrbit.mode != 2 || Int(PixelWindowSeat.window.value) != windowSize
        guard another else { return redraw() }
        guard let view else { return } // (with no view to hand over in, as in the tests, it stays as built)
        let fade = SKTransition.crossFade(withDuration: 0.8)
        (fade.pausesIncomingScene, fade.pausesOutgoingScene) = (false, false)
        let next = pixelWindowSeat(size: size)
        next.scaleMode = scaleMode
        retired = true
        view.presentScene(next, transition: fade)
    }

    /// Now, or today at the preview hour while previewing.
    private var now: Date {
        guard PixelWindowSeat.previewTime.value > 0.5 else { return Date() }
        return Calendar.current.startOfDay(for: Date()).addingTimeInterval(PixelWindowSeat.previewHour.value * 3600)
    }

    // MARK: - The light (every 30 s)

    /// Works out everything that follows the clock: the sky, and the colours the country and the carriage take in
    /// its light. Every 30 s by the wall clock and when a setting changes; and paints, as the airliner's does, since
    /// a view that is frozen or not drawing yet never reaches `update`.
    private func redraw() {
        redrawnAt = Date()
        let spot = Location.shared.coordinate
        let above = SeatSky(now, latitude: spot.latitude, longitude: spot.longitude, looking: Int(PixelWindowSeat.looking.value),
                            w: glass.w, h: glass.h, horizon: horizon, bands: glass.h - glass.h * 62 / 100) // the airliner's sky, and on up
        (night, sky) = (above.night, above.picture)
        // What is laid goes by the speed (the near ground's dashes are as long as it makes them, and a ring leaves
        // out what would slide too fast to follow) and by the side the Sun is on, which things are lit from: a
        // change of either lays everything again. With the Sun nearly straight ahead or behind, the side stays.
        let speed = Self.pace * PixelWindowSeat.speed.value, toSun = sin((above.sun.azimuth - above.facing) * .pi / 180)
        let side = toSun > 0.25 ? 1 : toSun < -0.25 ? -1 : world.sun
        if (speed, side) != (world.speed, world.sun) {
            (world.speed, world.sun) = (speed, side)
            for k in rings.indices { rings[k].first = .min }
            for r in rows.indices { rows[r].first = .min }
        }

        // The sky's light and the Sun's on each material, with no veil of air in front of it as the airliner has. The
        // night is lifted, as the orbit's is: a true one from a train is a black pane.
        let light = (above.ambient + above.key) * 0.78 * mix(1, 3.9, night), floor = rgb(9, 13, 27) * night
        let mats = TrainMat.day.count
        for (k, ring) in rings.enumerated() {
            let far = Float(1 - exp(-ring.away / TrainWorld.haze))
            for (m, base) in TrainMat.day.enumerated() { ringColours[k * mats + m] = pack(mix(pointwiseMin(base * light + floor, .one), above.haze, far)) }
        }
        // The ground, in the five tones a dash can take in each of a row's four kinds of near field (and one flat
        // tone further off).
        for tones in 0..<5 {
            for level in 0..<5 {
                let lift = tones == 0 ? 0 : Float(level - 2) * (tones < 3 ? 0.03 : 0.045) + (tones % 2 == 0 ? 0.022 : 0)
                for (m, base) in TrainMat.day.enumerated() { groundColours[((tones * 5) + level) * mats + m] = pack(base * (1 + lift) * light + floor) }
            }
        }
        // Lamps come on through dusk, each when the evening passes its own draw, as the airliner's do.
        (lamp, lights) = (pack(mix(rgb(255, 214, 150), rgb(255, 204, 128), night)), UInt8(min(255, night * 300)))
        if windowSize < 3 { paintFrame() }
        advance()
        compose()
    }

    /// How many pixels of the picture are lamps, for the tests: the night must never be without one.
    var lit: Int { lights == 0 ? 0 : picture.count { $0 == lamp } }

    /// The carriage round the pane, plain: its wall, a pale frame with the light along its top edge, and a dark
    /// gasket round glass with small corners.
    private func paintFrame() {
        var px = Pixels(w, h)
        let dim = mix(1, 0.22, night)
        let wall = rgb(52, 56, 72) * dim, frame = rgb(122, 126, 142) * dim, lit = rgb(150, 154, 168) * dim, gasket = rgb(20, 22, 30) * dim
        for y in 0..<h {
            for x in 0..<w {
                let d = PixelWindowSeat.outside(glass, x, y, round: 6)
                guard d >= 0 else { continue }
                px.plot(x, y, d < 1 ? gasket : d >= 5 ? wall : d >= 3 && y >= glass.y + glass.h + 3 ? lit : frame)
            }
        }
        cabin.texture = px.texture()
    }

    // MARK: - Motion (every frame)

    override func update(_ currentTime: TimeInterval) {
        let dt = min(max(currentTime - (lastUpdate ?? currentTime), 0), 0.1)
        lastUpdate = currentTime
        clock += dt
        if abs(Date().timeIntervalSince(redrawnAt)) >= 30 { redraw() }
        Self.travelled += min(max(currentTime - (Self.travelledAt ?? currentTime), 0), 0.1) * world.speed
        Self.travelledAt = currentTime
        // The near ground moves several pixels a frame, so there is always something to paint: 30 times a second at most.
        if clock - painted >= 1 / 30.0 - 0.002 {
            advance()
            compose()
        }
    }

    /// Slides each ring and each row of ground on to where the train has got to, laying what comes into view.
    private func advance() {
        let gw = glass.w
        /// The columns to lay for a strip whose left edge was at `old` and is now at `first`: the new ones at its
        /// leading edge, or all of them if it is new or has jumped.
        func entering(_ old: Int, _ first: Int) -> Range<Int> { (old != .min && first > old && first - old < gw ? old + gw : first)..<first + gw }
        strips.withUnsafeMutableBufferPointer { strips in
            for k in rings.indices {
                let ring = rings[k], first = Int((Self.travelled * ring.perMetre).rounded(.down)) - gw / 2
                guard first != ring.first else { continue }
                for n in entering(ring.first, first) {
                    let slot = ((n % gw) + gw) % gw
                    tops[k * gw + slot] = world.column(k, n, into: strips.baseAddress! + ring.base + slot * ring.rows)
                }
                rings[k].first = first
            }
        }
        for r in rows.indices {
            let row = rows[r], first = Int((Self.travelled * row.perMetre).rounded(.down)) - gw / 2
            guard first != row.first else { continue }
            for n in entering(row.first, first) {
                let at = r * gw + ((n % gw) + gw) % gw
                (land[at], dash[at]) = world.ground(r + 1, n)
            }
            rows[r].first = first
        }
    }

    /// Paints the view: the sky, the ground a row at a time, then each ring from the farthest to the nearest, so
    /// that what stands in front hides what is behind.
    private func compose() {
        painted = clock
        let (gw, gh) = (glass.w, glass.h), mats = TrainMat.day.count
        picture.withUnsafeMutableBufferPointer { out in
            for i in horizon * gw..<gh * gw { out[i] = sky[i] }
            for r in rows.indices {
                let row = rows[r], y = (horizon - 1 - r) * gw, at = r * gw, tones = row.tones * 5
                var s = ((row.first % gw) + gw) % gw
                for i in 0..<gw {
                    out[y + i] = groundColours[(tones + Int(dash[at + s])) * mats + Int(land[at + s])]
                    s += 1
                    if s == gw { s = 0 }
                }
            }
            for k in rings.indices {
                let ring = rings[k], colours = k * mats, low = max(0, -ring.foot), room = gh - ring.foot
                var s = ((ring.first % gw) + gw) % gw
                for i in 0..<gw {
                    let top = min(Int(tops[k * gw + s]), room)
                    if top > low {
                        let column = ring.base + s * ring.rows
                        for up in low..<top where strips[column + up] != 0 {
                            let cell = strips[column + up]
                            if cell > 127, lights > 0, scatter(ring.first + i, up, 70 + UInt64(k)) <= lights {
                                out[(ring.foot + up) * gw + i] = lamp
                            } else if cell & 127 != 0 { // (a lamp with nothing drawn under it shows only when lit)
                                out[(ring.foot + up) * gw + i] = ringColours[colours + Int(cell & 127)]
                            }
                        }
                    }
                    s += 1
                    if s == gw { s = 0 }
                }
            }
        }
        let shot = picture
        texture.modifyPixelData { data, length in
            shot.withUnsafeBytes { data?.copyMemory(from: $0.baseAddress!, byteCount: min(length, $0.count)) }
        }
    }
}

// MARK: - Supporting types

/// One ring of the country: everything `away` metres from the track, as a strip a pane wide and `rows` tall whose
/// foot stands on the pane's row `foot` (counted from its bottom), where a metre stands `perMetre` pixels. `first`
/// is the pixel of its endless strip at the pane's left edge, and `base` is where its columns begin in the scene's
/// store of them.
struct TrainRing {
    let away: Double, perMetre: Double, rows: Int, foot: Int, base: Int
    var first = Int.min
}

/// One row of ground: how many pixels a metre along the track spans there, which tones its dashes take (0 for the
/// far fields, which have none), and the pixel of its endless strip at the pane's left edge.
private struct GroundRow {
    let perMetre: Double, tones: Int
    var first = Int.min
}

/// What a pixel of the country is made of: 0 is nothing, and shows what is behind. The numbers are the mock-ups'
/// (docs/pixel-window-seat/train.py), so a strip can be compared with theirs byte for byte.
enum TrainMat {
    static let leaf0: UInt8 = 1, leaf1: UInt8 = 2, leaf2: UInt8 = 3, trunk: UInt8 = 4, fir0: UInt8 = 5, fir1: UInt8 = 6
    static let white: UInt8 = 7, whiteShade: UInt8 = 8, brick: UInt8 = 9, brickShade: UInt8 = 10, stone: UInt8 = 11, stoneShade: UInt8 = 12
    static let roof: UInt8 = 13, roofShade: UInt8 = 14, slate: UInt8 = 15, slateShade: UInt8 = 16, glass: UInt8 = 17, door: UInt8 = 18
    static let hedge: UInt8 = 19, hedgeLit: UInt8 = 20, road: UInt8 = 21, pole: UInt8 = 22
    static let wheat: UInt8 = 23, pasture: UInt8 = 24, crop: UInt8 = 25, fallow: UInt8 = 26, rape: UInt8 = 27, ley: UInt8 = 28, stubble: UInt8 = 29
    static let verge: UInt8 = 30, ballast: UInt8 = 31
    /// Each one's colour in full daylight, before the haze.
    static let day: [RGB] = [
        .zero, rgb(40, 78, 50), rgb(60, 106, 58), rgb(94, 138, 68), rgb(64, 52, 46), rgb(32, 64, 54), rgb(48, 88, 66),
        rgb(228, 222, 206), rgb(176, 176, 178), rgb(164, 100, 80), rgb(120, 74, 66), rgb(176, 166, 150), rgb(130, 124, 118),
        rgb(150, 72, 58), rgb(112, 56, 52), rgb(88, 92, 108), rgb(64, 68, 84), rgb(58, 66, 88), rgb(70, 52, 44),
        rgb(50, 90, 48), rgb(70, 112, 56), rgb(128, 126, 126), rgb(58, 50, 46),
        rgb(208, 190, 116), rgb(118, 164, 88), rgb(90, 144, 76), rgb(152, 124, 94), rgb(214, 200, 96), rgb(150, 180, 108), rgb(190, 170, 124),
        rgb(86, 128, 70), rgb(120, 112, 104),
    ]
}

/// The country beside the line: what stands at a column of a ring, and what lies at a pixel of a row of ground.
/// Everything comes from hashes of the place, as `SeatWorld`'s country does, so nothing is stored and every display
/// sees the same land. It is the mock-ups' painter (docs/pixel-window-seat/train.py) line for line and in the same
/// arithmetic, rounding included, so that what it lays can be checked against the pictures Dave picked from
/// (`trainWritesItsCountry`, in TrainTests.swift).
struct TrainWorld {
    /// How far each ring stands from the track, in metres, far to near.
    static let rings: [Double] = [60000, 30000, 15000, 7000, 3500, 1800, 900, 500, 300, 180, 110]
    /// For each ring, how high the land can swell there, in metres (the nearest three are level with the track),
    /// and how long a field on that swell's face is.
    static let rise: [Double] = [0, 0, 0, 520, 230, 90, 34, 12, 0, 0, 0], fieldLength: [Double] = [0, 0, 0, 520, 380, 300, 250, 230, 0, 0, 0]
    /// The crops a field can be under, some of them twice as likely.
    static let fields = [TrainMat.wheat, TrainMat.pasture, TrainMat.crop, TrainMat.fallow, TrainMat.ley, TrainMat.pasture, TrainMat.stubble,
                         TrainMat.crop, TrainMat.rape, TrainMat.ley]
    /// For each ring, how long a plot of track is, which can hold one thing (a tree, a house, a church); of the
    /// plots in a village, the share that hold a house; and of the plots anywhere, the share that hold a farm.
    static let plot: [Double] = [0, 0, 0, 700, 420, 260, 150, 90, 60, 44, 34]
    static let housed: [Double] = [0, 0, 0, 0, 0, 0.8, 0.75, 0.7, 0.5, 0, 0], farmed: [Double] = [0, 0, 0, 0, 0, 0, 0, 0.07, 0.09, 0.07, 0]
    /// A lane and its hedge run beside the line this far out; nearer than `verge` is the railway's own grass.
    /// Things fade to the horizon's colour over `haze` metres.
    static let lane = 62.0, verge = 15.0, haze = 26_000.0
    /// What keeps it calm at any speed, in pixels a second: thin things (a pole, a lamp, a hedge's end, a spire)
    /// are laid only where they slide no faster than `thin`, and broad ones (a tree, a house) no faster than `broad`.
    /// At 1× the fastest thin thing is a field's hedge 103 m out, at 34, and the nearest ring's trees are at 32.
    static let thin = 36.0, broad = 60.0

    /// The lens, in pixels per unit of tangent; the eye's height above the ground, in metres; and the train's speed
    /// in metres a second, which sets how long the near ground's dashes are and what is too fast to lay.
    let focal: Double, eye: Double
    var speed: Double
    /// Which side things are lit from: 1 from the right of the picture, -1 from the left.
    var sun = 1

    /// How many pixels a metre stands, and spans along the track, at a ring.
    func perMetre(_ ring: Int) -> Double { focal / Self.rings[ring] }

    /// How many rows a ring's strip needs for the tallest thing that can stand there.
    func rows(_ ring: Int) -> Int {
        let z = Self.rings[ring], ppm = focal / z
        let most = z >= 15000 ? (z >= 30000 ? 2600 : 950) * ppm + 1 : (34 * ppm).rounded(.up) + 3 + Self.rise[ring] * ppm
        return min(max(Int(most.rounded(.up)), 2), 255)
    }

    /// Lays column `n` of a ring into `cells`, its foot first: far off, a hill or a range as a line of heights,
    /// wooded, farmed or under snow; nearer, the land's own swell with its hedged fields and the woods along its
    /// top, and on it whatever stands in that plot of track: a tree, a fir, a house, a church. A cell's top bit marks
    /// a lamp: a window, or a light in a far town, that comes on after dark. Returns how many of the strip's rows
    /// the column uses.
    func column(_ ring: Int, _ n: Int, into cells: UnsafeMutablePointer<UInt8>) -> UInt8 {
        let z = Self.rings[ring], ppm = focal / z, wx = Double(n) / ppm, salt = UInt64(z), rows = rows(ring)
        cells.update(repeating: 0, count: rows)
        if z >= 15000 {
            let high: Double
            if z >= 30000 {
                let ridge = 1 - abs(2 * fbm(wx / 26000, z / 9000, 5, salt) - 1)
                high = 2600 * (ridge * ridge) * clip((fbm(wx / 90000, 3, 2, salt + 9) - 0.42) * 5)
            } else {
                high = 950 * clip(fbm(wx / (z * 0.9), z / 4000, 4, salt) * 1.5 - 0.28)
            }
            let top = min(Int((high * ppm).rounded(.toNearestOrEven)), rows)
            guard top > 0 else { return 0 }
            let wooded = fbm(wx / (z * 0.12), 7, 3, salt + 5)
            for up in 0..<top {
                let wood = wooded + (unit(hash(n, up, salt + 6)) - 0.5) * 0.25
                if z >= 30000 {
                    let snow = Double(up) > 1700 * ppm + (unit(hash(n, up, salt + 7)) - 0.5) * 2
                    cells[up] = snow ? TrainMat.white : wood > 0.55 ? TrainMat.slate : TrainMat.slateShade
                } else {
                    cells[up] = wood > 0.58 ? TrainMat.leaf0 : wood > 0.42 ? TrainMat.crop : TrainMat.pasture
                }
            }
            return UInt8(top)
        }
        // The swell's face: fields in strips that follow it, each with a hedge at its end, and patches of wood; and
        // where a town lies, its lamps.
        let pace = ppm * speed // how fast this ring slides, in pixels a second
        let rise = Self.rise[ring], swell = rise == 0 ? 0 : rise * clip(fbm(wx / (z * 1.3) + 3, z / 2000, 3, salt + 60) * 1.7 - 0.42)
        let swollen = Int((swell * ppm).rounded(.toNearestOrEven)), face = min(swollen, rows)
        if face > 0 {
            let long = Self.fieldLength[ring], deep = max(2, Double(swollen) / 3 + 0.5)
            let town = z >= 1800 && pace <= Self.thin && noise(wx / 1400, 2, 4242) > 0.62
            for up in 0..<face {
                let band = (Double(up) / deep).rounded(.down), along = wx / long + band * 0.37
                let crop = Self.fields[Int(unit(hash(Int(along.rounded(.down)), Int(band), salt + 61)) * Double(Self.fields.count))]
                cells[up] = fbm(wx / (z * 0.2), Double(up) / 3, 3, salt + 62) > 0.63 ? TrainMat.leaf0 : crop
                if abs(along - along.rounded(.toNearestOrEven)) * long * ppm < 0.6 { cells[up] = TrainMat.hedge }
                if town, unit(hash(n, up, salt + 63)) < 0.035 { cells[up] |= 128 }
            }
        }
        var top = face
        // Woods along its top, where the country is wooded: a ragged line too far off to tell one tree from the next.
        if z >= 500 {
            let wooded = fbm(wx / 900, z / 300, 3, salt + 1)
            let tall = Int(((10 + 14 * fbm(wx / 60, 1, 3, salt + 2)) * ppm * clip((wooded - 0.50) * 9)).rounded(.toNearestOrEven))
            top = min(face + tall, rows)
            for up in face..<top { cells[up] = unit(hash(n, up, salt + 3)) < 0.35 ? TrainMat.leaf1 : TrainMat.leaf0 }
        }
        // What stands in the plots of track round this column, one thing to a plot, the later over the earlier: a
        // church or houses where a village lies (the same villages on every ring), a farm on its own, or a tree, more
        // of them where the country is wooded. Each stands on the swell's face.
        let plot = Self.plot[ring], here = Int((wx / plot).rounded(.down))
        if pace <= Self.broad, z <= 1800 {
            for c in here - 2...here + 2 {
                let draw = unit(hash(c, 1, salt + 30)), at = (Double(c) + unit(hash(c, 2, salt + 31))) * plot
                let village = noise(at / 1400, 2, 4242), seed = Int(hash(c, 3, salt + 32) % (1 << 30))
                let stamp: Stamp
                if z == 900, village > 0.70, draw < 0.2 {
                    guard pace <= Self.thin else { continue }
                    stamp = .church(30 * ppm, sun)
                } else if village > 0.64, draw < Self.housed[ring] {
                    stamp = .house(max(2, 5.0 * ppm), seed, sun)
                } else if draw < Self.farmed[ring] {
                    stamp = .house(max(2, 5.5 * ppm), seed, sun)
                } else if z <= 900, draw > 1 - min(max(0.18 + (fbm(at / 900, z / 300, 3, salt + 1) - 0.45) * 2.2, 0.08), 0.8) {
                    let high = 9 + 9 * unit(hash(c, 4, salt + 33))
                    stamp = unit(hash(c, 5, salt + 34)) < 0.2 ? .fir(high * 1.2 * ppm, sun) : .tree(high * ppm, seed, sun)
                } else {
                    continue
                }
                let left = Int((at * ppm).rounded(.toNearestOrEven)) - stamp.w / 2
                let lift = Int(Double(swollen) * (0.35 + 0.65 * unit(hash(c, 6, salt + 35))))
                guard n >= left, n < left + stamp.w, lift + stamp.h <= rows else { continue }
                for (y, material) in stamp.column(n - left).enumerated() where material != 0 {
                    let up = lift + stamp.h - 1 - y
                    cells[up] = cells[up] & 128 | material
                    if material == TrainMat.glass, pace <= Self.thin, unit(hash(seed + n - left, y, 55)) < 0.8 { cells[up] |= 128 }
                }
                top = max(top, lift + stamp.h)
            }
        }
        // A lane with its line of poles, where there is one: the only poles on a ring, far enough off to be calm.
        if z == 300, pace <= Self.thin, fbm(wx / 2400, 5, 2, 808) > 0.50,
           Int(((wx / 42).rounded(.toNearestOrEven) * 42 * ppm).rounded(.toNearestOrEven)) == n {
            for up in 0..<min(7, rows) where cells[up] == 0 { cells[up] = TrainMat.pole }
            top = max(top, min(7, rows))
        }
        // Lights that show only after dark, lamps with nothing drawn under them, so that a night with no village in
        // view still has something to rest on: far off, the windows of farms too small to draw, a few together, on
        // the swell's face or at its foot; nearer, a lamp in a farm's yard, 4 to 7 m up.
        guard pace <= Self.thin else { return UInt8(top) }
        if z >= 1800 {
            if unit(hash(n, 1, salt + 65)) < 0.06 * clip((noise(wx / 420, 6, salt + 64) - 0.5) * 4) {
                let up = Int(Double(swollen) * unit(hash(n, 2, salt + 66)))
                if up < rows { (cells[up], top) = (cells[up] | 128, max(top, up + 1)) }
            }
        } else if z >= 180 {
            for c in here - 1...here + 1 where Int(((Double(c) + unit(hash(c, 8, salt + 37))) * plot * ppm).rounded(.toNearestOrEven)) == n {
                let up = swollen + Int(((4.0 + 3.0 * unit(hash(c, 9, salt + 38))) * ppm).rounded(.toNearestOrEven))
                if unit(hash(c, 7, salt + 36)) < 0.3, up < rows { (cells[up], top) = (cells[up] | 128, max(top, up + 1)) }
            }
        }
        return UInt8(top)
    }

    /// Which tones the dashes of the ground row `d` rows under the horizon take: 0 beyond 100 m, where there are
    /// none; else 1 or 2 for a field and 3 or 4 for the verge, the rows banded three at a time.
    func tones(_ d: Int) -> Int {
        let z = eye * focal / Double(d)
        return z > 100 ? 0 : (z > Self.verge ? 1 : 3) + (d / 3) % 2
    }

    /// What lies at pixel `n` of the ground row `d` rows under the horizon, and which of the five tones of its
    /// dash it takes. Beyond 100 m, fields a stretch of track long in belts of distance, hedged. Nearer, one crop
    /// for a long way, a lane and its hedge, then the railway's grass, all drawn out into soft dashes each at least
    /// twice as long as its row moves in a thirtieth of a second, so nothing in them can strobe.
    func ground(_ d: Int, _ n: Int) -> (land: UInt8, dash: UInt8) {
        let z = eye * focal / Double(d), ppm = Double(d) / eye, wx = Double(n) / ppm
        if z > 100 {
            let belt = d <= 1 ? 0 : d <= 2 ? 1 : d <= 4 ? 2 : 3, long = 230.0 + 60 * Double(belt)
            let along = wx / long + Double(belt) * 0.37, field = Int(along.rounded(.down))
            if ppm * speed <= Self.thin, abs(along - along.rounded(.toNearestOrEven)) * long < max(1.5, 1.2 / ppm),
               unit(hash(field, belt, 4101)) < 0.6 { return (TrainMat.hedge, 2) }
            return (Self.fields[Int(unit(hash(field, belt, 4100)) * Double(Self.fields.count))], 2)
        }
        let lane = Int((eye * focal / Self.lane).rounded(.toNearestOrEven))
        let land = d == lane - 2 ? TrainMat.hedge : d == lane - 1 ? TrainMat.hedgeLit : d == lane ? TrainMat.road
            : z > Self.lane ? (fbm(wx / 1500, 0.5, 2, 4200) > 0.5 ? TrainMat.ley : TrainMat.wheat)
            : z > Self.verge ? (fbm(wx / 1900, 1.5, 2, 4201) > 0.5 ? TrainMat.pasture : TrainMat.crop) : TrainMat.verge
        let long = max(10, 2.2 * speed * ppm / 30)
        return (land, UInt8(min(max((fbm(Double(n) / long, Double(d) / 3, 2, 4300) * 5).rounded(.down), 0), 4)))
    }
}

/// A small drawn thing that stands on a ring, `w` pixels wide and `h` tall: `column` gives one of its columns, its
/// top first, 0 where it is see-through. They are the mock-ups' own (train.py), and lit from the side `sun` says:
/// 1 from the right.
private struct Stamp {
    let w: Int, h: Int, column: (Int) -> [UInt8]

    /// A broadleaf tree `tall` pixels high: a ragged round crown in three tones over a trunk.
    static func tree(_ tall: Double, _ seed: Int, _ sun: Int) -> Stamp {
        let h = max(3, Int(tall)), w = max(3, Int((Double(h) * (0.62 + 0.22 * unit(hash(seed, 1, 5)))).rounded(.toNearestOrEven)))
        let crown = h - max(1, Int((Double(h) * 0.24).rounded(.toNearestOrEven))), cy = Double(crown - 1) / 2, cx = Double(w - 1) / 2
        let stem = Int(cx)..<Int(cx) + (h < 20 ? 1 : 2)
        return Stamp(w: w, h: h) { x in
            var column = [UInt8](repeating: 0, count: h)
            for y in 0..<crown {
                let down = (Double(y) - cy) / (Double(crown) / 2 + 0.3), across = (Double(x) - cx) / (Double(w) / 2 + 0.3)
                guard down * down + across * across < 0.80 + 0.36 * unit(hash(x + seed * 7, y, 11)) else { continue }
                let lit = (Double(x) - cx) * Double(sun) / (Double(w) / 2) * 0.7 - (Double(y) - cy) / (Double(crown) / 2) * 0.9
                    + (unit(hash(x, y + seed, 13)) - 0.5) * 0.7
                column[y] = lit > 0.55 ? TrainMat.leaf2 : lit > -0.35 ? TrainMat.leaf1 : TrainMat.leaf0
            }
            if stem.contains(x) { for y in crown - 1..<h { column[y] = TrainMat.trunk } }
            return column
        }
    }

    /// A fir `tall` pixels high: boughs that step out every third row, lit on one side, on a foot of trunk.
    static func fir(_ tall: Double, _ sun: Int) -> Stamp {
        let h = max(4, Int(tall)), w = max(3, Int((Double(h) * 0.42).rounded(.toNearestOrEven)) | 1), cx = w / 2
        return Stamp(w: w, h: h) { x in
            var column = [UInt8](repeating: 0, count: h)
            for y in 0..<h - 1 {
                let half = Int((Double(y + 1) / Double(h - 1) * (Double(w) / 2) * (0.75 + 0.25 * (Double(y % 3) / 2))).rounded(.toNearestOrEven))
                if abs(x - cx) <= half { column[y] = (x - cx) * sun > 0 ? TrainMat.fir1 : TrainMat.fir0 }
            }
            if x == cx { column[h - 1] = TrainMat.trunk }
            return column
        }
    }

    /// A house whose eaves are `eaves` pixels up: a wall of render, brick or stone with its windows, one end in
    /// shade, under a tiled or slated roof that is hipped or shows a gable, and often a chimney.
    static func house(_ eaves: Double, _ seed: Int, _ sun: Int) -> Stamp {
        let walls = [(TrainMat.white, TrainMat.whiteShade), (TrainMat.brick, TrainMat.brickShade), (TrainMat.stone, TrainMat.stoneShade)][Int(unit(hash(seed, 2, 21)) * 3)]
        let roofs = unit(hash(seed, 3, 22)) < 0.55 ? (TrainMat.roof, TrainMat.roofShade) : (TrainMat.slate, TrainMat.slateShade)
        let wall = max(2, Int(eaves)), w = max(4, Int((Double(wall) * (1.5 + 0.9 * unit(hash(seed, 4, 23)))).rounded(.toNearestOrEven)))
        let roof = max(2, Int((Double(wall) * 0.7).rounded(.toNearestOrEven))), hipped = unit(hash(seed, 5, 24)) < 0.5
        let shade = sun > 0 ? 0..<max(1, w / 4) : w - max(1, w / 4)..<w
        let chimney = unit(hash(seed, 6, 25)) < 0.6 && w > 5 ? (unit(hash(seed, 7, 26)) < 0.5 ? w - 2 : 1) : -1
        let firstWindow = 1 + (sun > 0 ? w / 4 : 0), between = max(2, wall / 2 + 1)
        return Stamp(w: w, h: wall + roof) { x in
            var column = [UInt8](repeating: 0, count: wall + roof)
            for y in roof..<roof + wall { column[y] = shade.contains(x) ? walls.1 : walls.0 }
            for y in 0..<roof {
                let inset = hipped ? Int((Double(roof - 1 - y) * 0.9).rounded(.toNearestOrEven)) : 0
                if x >= inset, x < w - inset { column[y] = y > 0 ? roofs.0 : roofs.1 }
            }
            if wall >= 4 {
                if x >= firstWindow, x < w - 1, (x - firstWindow) % between == 0 {
                    for y in roof + wall / 3..<roof + wall / 3 + max(1, wall / 4) { column[y] = TrainMat.glass }
                }
            } else if x == w / 2 + (sun > 0 ? 1 : -1) {
                column[roof + wall / 2 - (wall > 2 ? 1 : 0)] = TrainMat.glass
            }
            if x == chimney, max(0, roof / 3 - 1) < roof / 2 + 1 { for y in max(0, roof / 3 - 1)..<roof / 2 + 1 { column[y] = TrainMat.brickShade } }
            return column
        }
    }

    /// A village church `tall` pixels high in all: a nave under a slate roof, with a tower and its spire at one end.
    static func church(_ tall: Double, _ sun: Int) -> Stamp {
        let h = max(6, Int(tall)), nave = max(2, h / 3), tower = max(2, h / 5), spire = h - Int(Double(h) * 0.62)
        return Stamp(w: max(4, Int(Double(h) * 0.9)) + tower, h: h) { x in
            var column = [UInt8](repeating: 0, count: h)
            if x >= tower {
                for y in h - nave - max(1, nave / 2)..<h { column[y] = y < h - nave ? TrainMat.slate : TrainMat.stone }
            } else {
                for y in spire..<h { column[y] = sun > 0 ? TrainMat.stoneShade : TrainMat.stone }
                for y in 0..<spire where !(tower == 2 && y < spire / 2) || x == (sun < 0 ? 0 : 1) { column[y] = TrainMat.slateShade }
            }
            return column
        }
    }
}

@inline(__always) private func clip(_ v: Double) -> Double { min(max(v, 0), 1) }

/// A well-mixed hash of a pair of whole numbers: the airliner's (PixelWindowSeat.swift), and the mock-ups'.
@inline(__always) private func hash(_ x: Int, _ z: Int, _ salt: UInt64) -> UInt64 {
    var v = UInt64(bitPattern: Int64(x)) &* 0x9E37_79B9_7F4A_7C15 ^ UInt64(bitPattern: Int64(z)) &* 0xC2B2_AE3D_27D4_EB4F ^ salt &* 0x1656_67B1_9E37_79F9
    v = (v ^ (v >> 31)) &* 0xBF58_476D_1CE4_E5B9
    v = (v ^ (v >> 29)) &* 0x94D0_49BB_1331_11EB
    return v ^ (v >> 32)
}

/// A hash as a number from 0 up to 1.
@inline(__always) private func unit(_ v: UInt64) -> Double { Double(v >> 40) / 16_777_216 }

/// A random byte for a pixel. (Inside the scene, `hash` is the object's own.)
@inline(__always) private func scatter(_ x: Int, _ z: Int, _ salt: UInt64) -> UInt8 { UInt8(truncatingIfNeeded: hash(x, z, salt) >> 56) }

/// Smooth noise from 0 to 1, with one bump per unit. In doubles where the airliner's is in floats, as the mock-ups'
/// was.
private func noise(_ x: Double, _ z: Double, _ salt: UInt64) -> Double {
    let (fx, fz) = (x.rounded(.down), z.rounded(.down)), (ix, iz) = (Int(fx), Int(fz))
    var (u, v) = (x - fx, z - fz)
    (u, v) = (u * u * (3 - 2 * u), v * v * (3 - 2 * v))
    let a = unit(hash(ix, iz, salt)), b = unit(hash(ix + 1, iz, salt)), c = unit(hash(ix, iz + 1, salt)), d = unit(hash(ix + 1, iz + 1, salt))
    return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v
}

/// Noise with finer noise laid over it, each layer half the size and half the strength of the last; 0 to 1.
private func fbm(_ x: Double, _ z: Double, _ layers: Int, _ salt: UInt64) -> Double {
    var (sum, strength, x, z) = (0.0, 0.5, x, z)
    for layer in 0..<layers {
        sum += strength * noise(x, z, salt &+ UInt64(layer) &* 101)
        (strength, x, z) = (strength / 2, x * 2.03, z * 2.03)
    }
    return sum / (1 - strength * 2)
}

private func rgb(_ r: Int, _ g: Int, _ b: Int) -> RGB { RGB(Float(r), Float(g), Float(b)) / 255 } // as in PixelCity.swift, which says why

private func pack(_ c: RGB) -> UInt32 {
    let c = pointwiseMin(pointwiseMax(c, .zero), .one) * 255
    return 0xFF00_0000 | UInt32(c.z) << 16 | UInt32(c.y) << 8 | UInt32(c.x)
}
