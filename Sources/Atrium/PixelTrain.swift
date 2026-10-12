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
    /// What country the line runs through: whatever comes, or held on one kind. (A menu of the train's own: the
    /// airliner's has sceneries the train hasn't got yet, and its ocean is the train's lake.) The city across the
    /// water was added last, so it is stored last and listed beside the city.
    nonisolated static let scenery = Knob(key: "seat.country", label: "Scenery", range: 0...7, standard: 0, section: "Flight",
                                          format: .choice(["Changing", "Countryside", "A lake beside the line", "Mountains", "A city", "Snow", "Desert",
                                                           "A city across the water"]),
                                          order: [0, 1, 2, 3, 4, 7, 5, 6], shownWhen: "seat.orbit", shownAt: 2)
    nonisolated static let poles = Knob(key: "seat.poles", label: "Poles and wires beside the line", range: 0...1, standard: 1, section: "Flight",
                                        format: .toggle, shownWhen: "seat.orbit", shownAt: 2)
    /// The train's own settings, listed among the airliner's (`PixelWindowSeat.knobs`).
    nonisolated static let knobs = [scenery, poles, PixelCarriage.choice, TrainWeather.follow, TrainWeather.glass, TrainWeather.preview]

    /// 1× on Settings' Speed, in metres a second: 48 km/h, a slow scenic train.
    nonisolated static let pace = 48 / 3.6
    /// How high the eye is above the ground, in metres, and how far up the pane the horizon lies.
    nonisolated static let eye = 3.5, horizonUp = 0.3

    private let w: Int, h: Int // the canvas, in art pixels
    private let glass: (x: Int, y: Int, w: Int, h: Int) // the window's pane on it
    private let horizon: Int // the pane's row the horizon lies on, counted from its bottom; the rows below are ground
    private let windowSize: Int // Settings' Window, as the scene was built: 3 is none, the pane being the whole canvas
    private let windowOn = PixelOrbit.mode // Settings' pick of airliner, station or train, as the scene was built
    private var world: TrainWorld
    private(set) var rings: [TrainRing] = [] // far to near
    // What each ring shows: for each of its columns a strip of materials up from its foot, and how many of them are
    // in use. A column keeps its place in the ring from the moment it slides in until it slides out.
    private var strips: [UInt8] = [], tops: [UInt8] = []
    private var rows: [GroundRow] = []
    private var land: [UInt8], dash: [UInt8] // the ground rows' materials, and which tone of its dash each pixel takes
    private var sky: [UInt32] = []
    private(set) var picture: [UInt32] // the pane as last painted, its rows from the bottom
    private var ringColours: [UInt32] = [], groundColours: [UInt32] = [] // the colours of the moment, ready to copy
    private var lamp: UInt32 = 0, lights: UInt8 = 0 // a lamp's colour, and how far the evening has got: each comes on at its own draw
    private var lamps = [UInt32](repeating: 0, count: TrainMat.day.count) // a lit thing's colour by what it is: `lamp`, but for a few
    private var pole: UInt32 = 0, wire: UInt32 = 0 // the pole line's colours
    private let polesOn: Bool // Settings' Poles and wires, as the scene was built
    private let carriage: PixelCarriage // the cabin round the pane, by Settings' Carriage as the scene was built
    // From which pole on the line stands or doesn't: it is left out while it would slide too fast, and a change takes
    // hold beyond the pane's leading edge, so the line runs out or comes in at a pole and never blinks.
    private var strung: [(from: Int, on: Bool)] = []
    // The lake, by where a pixel is on the pane and not by what slides under it: each ground row's water in six
    // colours (flat, a ripple's light and its dark, the Sun's glitter, and under the image of what stands on the far
    // shore, dark and faint), and how likely the glitter is there.
    private var water: [UInt32], glint: [UInt8]
    private var skyline: [Int] // for each column of the pane, the row what stands beyond a lake's far shore reaches up to
    private var fronted: [Bool] // and whether the far shore there is a city's embankment
    private var reflected: [(column: Int, colour: UInt32)] = [] // the far shore's lamps as last painted, for their streaks in the water
    // The cloud (PixelTrainSky.swift): its five tones in this light, lightning's colour and how strongly it lights a
    // storm (0 with Settings' Lightning off), and a lake's water under a cloud's image, each row in the five tones.
    private var cloud: TrainCloud
    private var cloudTones: [UInt32] = [], bolt: UInt32 = 0, storms: Float = 0, mirrored: [UInt32] = []
    // The light as last worked out, and where the Sun is drawn in the sky while it is up. Cloud over the Sun cuts
    // its share of the light on the land, in thirty-seconds (`shade`), a step each sixteenth of a second
    // (`shadeTick`): about one level of 255 on the land at a time, where steps four times as big showed.
    private var daylight = (ambient: RGB.zero, key: RGB.zero, glow: RGB.zero, haze: RGB.zero)
    private var sunSpot: (x: Int, row: Int)?, shade = 0, shadeTick = 0
    private var hazed = 0.0 // how far off things fade to the horizon's colour, as the colours were last worked out (`reach`)
    // The weather (PixelTrainSky.swift) as the scene was built, or none. What it does to the picture: how fast
    // things fade into its air, as a share of them a metre (`murk`), and the colour they fade to (`mist`); the
    // cloud's tones for each row of sky, seen through that much air (`skyTones`); how far each row of ground has
    // faded, in parts of 256 (`fog`), and each ring's lamps, at half the rate (`lampFog`); the snow, in a colour
    // for each of its layers; and how brightly lightning lights it just now.
    private let weather: TrainWeather?
    private var murk = 0.0, mist: UInt32 = 0, skyTones: [UInt32] = [], fog: [UInt32] = [], lampFog: [UInt32] = []
    private var snow = TrainSnow(), flake: [UInt32] = [], flash: Float = 0
    private var rain: TrainGlass, wetLight: UInt32 = 0 // rain on the glass, and the colour of its bright side
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
        carriage = PixelCarriage(w: w, h: h, glass: glass, kind: Int(PixelCarriage.choice.value))
        world = TrainWorld(focal: Double(gh) * 1.2, eye: Self.eye, speed: Self.pace * PixelWindowSeat.speed.value)
        (world.scenery, polesOn) = (Int(Self.scenery.value), Self.poles.value > 0.5)
        (land, dash) = ([UInt8](repeating: 0, count: gw * horizon), [UInt8](repeating: 0, count: gw * horizon))
        (water, glint) = ([UInt32](repeating: 0, count: 6 * gw * horizon), [UInt8](repeating: 0, count: gw * horizon))
        (skyline, fronted) = ([Int](repeating: 0, count: gw), [Bool](repeating: false, count: gw))
        weather = TrainWeather.now
        cloud = TrainCloud(wide: gw, rows: gh - horizon, focal: Double(gh) * 1.2, clouds: Int(PixelWindowSeat.clouds.value), held: weather?.cover)
        rain = TrainGlass(speed: world.speed)
        mirrored = [UInt32](repeating: 0, count: 15 * horizon)
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
        settings = (PixelWindowSeat.knobs + Self.knobs).map(\.value)
        redraw()
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged),
                                               name: UserDefaults.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(weatherChanged), name: LiveWeather.changed, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Asks for the weather where you are every quarter hour while Settings follows it. (`LiveWeather` is shared,
    /// and fetches at most every ten minutes however many scenes ask.)
    override func didMove(to view: SKView) {
        Location.shared.start()
        run(.repeatForever(.sequence([.run { if TrainWeather.follow.value > 0.5 { LiveWeather.shared.poll() } }, .wait(forDuration: 900)])))
    }

    /// Repaints when one of the page's settings changes (the notification comes for every wallpaper's). Another
    /// window, another size of this one, another carriage, other scenery, other weather or the pole line put up or taken down is another scene: it
    /// dissolves into it with both still running, as the airliner's changes do. A change of speed is not: the
    /// country carries on as it is, and only what comes into view from then on is laid by the new speed.
    @objc private func settingsChanged() {
        let picked = (PixelWindowSeat.knobs + Self.knobs).map(\.value)
        guard picked != settings, !retired else { return }
        settings = picked
        if view != nil, TrainWeather.follow.value > 0.5 { LiveWeather.shared.poll() } // (switched on, it asks at once)
        let another = PixelOrbit.mode != windowOn || Int(PixelWindowSeat.window.value) != windowSize || Int(Self.scenery.value) != world.scenery
            || (Self.poles.value > 0.5) != polesOn || Int(PixelCarriage.choice.value) != carriage.kind
            || Int(PixelWindowSeat.clouds.value) != cloud.clouds || TrainWeather.now != weather
        guard another else { return redraw() }
        dissolve(over: 0.8)
    }

    /// A new report: where it comes to other weather than the scene was built under, the sky turns to it over a
    /// few seconds. (A report is rounded to a few kinds of weather, so most change nothing.)
    @objc private func weatherChanged() {
        if !retired, TrainWeather.now != weather { dissolve(over: 4) }
    }

    /// Hands over to a scene built by Settings as they are now, with both running while one fades into the other.
    private func dissolve(over seconds: TimeInterval) {
        guard let view else { return } // (with no view to hand over in, as in the tests, it stays as built)
        let fade = SKTransition.crossFade(withDuration: seconds)
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
        // out what would slide too fast to follow) and by the side the Sun is on, which things are lit from. Nothing
        // in view is laid again for a change of either: what comes into view from then on goes by the new one
        // (`advance`). With the Sun nearly straight ahead or behind, the side stays.
        let speed = Self.pace * PixelWindowSeat.speed.value, toSun = sin((above.sun.azimuth - above.facing) * .pi / 180)
        (world.speed, world.sun) = (speed, toSun > 0.25 ? 1 : toSun < -0.25 ? -1 : world.sun)

        // The sky's light and the Sun's on each material, with no veil of air in front of it as the airliner has. The
        // night is lifted, as the orbit's is: a true one from a train is a black pane. And while the Sun is low the
        // glow along the horizon lights the land too, two fifths of its colour: by the sky's light and the Sun's
        // alone the land went a dull green under the best sky of the day.
        let low = smoothstep(-10, -2, above.el) * smoothstep(12, 3, above.el)
        // The weather's air. Under cloud that has put the day out, distance fades to the cloud's grey and not the
        // sky's blue, and the horizon has no glow to give. After dark the cloud is darkened less and the air is
        // never thicker than 2 km, or a foggy night would be a black pane with no lamp in it.
        let gloom = Float(weather?.gloom ?? 0), tones = TrainCloud.tones(above.el, gloom: gloom * (1 - 0.7 * night))
        murk = weather.map { 1 / max($0.reach, 2000 * Double(night)) } ?? 0
        let air = weather == nil ? above.haze : mix(above.haze, tones[3] * mix(1, 1.5, night), gloom * 1.6)
        mist = pack(air)
        daylight = (above.ambient, above.key, above.haze * (0.4 * low * (1 - gloom)), air)
        // The sky through it: the air is a layer 600 m deep, so a row of sky near the horizon looks through far
        // more of it than one overhead, and is the mist's own colour.
        let through = (0..<glass.h - horizon).map { UInt32(256 * (1 - exp(-600 * (1 + pow(world.focal / Double($0 + 1), 2)).squareRoot() * murk))) }
        if murk > 0 {
            for (row, veil) in through.enumerated() { for i in (horizon + row) * glass.w..<(horizon + row + 1) * glass.w { sky[i] = blend(sky[i], mist, veil) } }
        }
        cloudTones = tones.map(pack)
        skyTones = through.flatMap { veil in cloudTones.map { blend($0, mist, veil) } }
        fog = (1...horizon).map { UInt32(256 * (1 - exp(-world.focal * Self.eye / Double($0) * murk))) }
        // Where the Sun is drawn, for the cloud that passes over it; or, with the Sun up but behind the train, the
        // sky overhead. A scene starts in whatever shade its sky gives it.
        let drawn = above.sunSpot, inPane = drawn.x >= 0 && drawn.x < glass.w && drawn.y >= horizon && drawn.y < glass.h
        sunSpot = above.sun.elevation <= 0 ? nil : inPane ? (drawn.x, drawn.y - horizon) : (glass.w / 2, glass.h - horizon - 1)
        if clock == 0 { shade = shadeWanted(with: Self.travelled) }
        hazed = reach
        relight()
        (bolt, storms) = (pack(rgb(214, 224, 255)), PixelWindowSeat.lightning.value > 0.5 ? mix(0.22, 0.8, night) : 0) // by day a flash hardly shows
        // The lake: each row of water is the sky that many rows above the horizon turned over (three parts in five
        // the row's middle tone, the rest its own pixel, so a breath of what is up there shows), deepened toward its
        // own blue as it nears us. Under the Sun, while its disc is in the sky, lies a path of its glitter.
        let (gw, gh) = (glass.w, glass.h), flat = gw * horizon
        let deep = mix(mix(rgb(34, 78, 118), rgb(70, 56, 92), low), rgb(10, 14, 32), night)
        let sunAt = above.sunSpot, shining = above.sun.elevation > -1 && sunAt.y >= horizon && sunAt.y < gh && sunAt.x >= 0 && sunAt.x < gw
        let sunlight = shining ? unpack(sky[sunAt.y * gw + sunAt.x]) : .zero
        for d in 1...horizon {
            let from = min(gh - 1, horizon + Int(Double(d) * 1.6)) * gw, above = (0..<gw).map { unpack(sky[from + $0]) }
            let middle = RGB(above.map(\.x).sorted()[gw / 2], above.map(\.y).sorted()[gw / 2], above.map(\.z).sorted()[gw / 2])
            for (tone, colour) in cloudTones.enumerated() { // and the same water with cloud up there, of each tone
                let c = mix(middle * 0.6 + unpack(colour) * 0.4, deep, 0.30 + 0.35 * min(1, Float(d) / Float(horizon)))
                for (ripple, brighter) in [Float(1), 1.1, 0.9].enumerated() { mirrored[(d - 1) * 15 + tone * 3 + ripple] = pack(c * brighter) }
            }
            for x in 0..<gw {
                let c = mix(middle * 0.6 + above[x] * 0.4, deep, 0.30 + 0.35 * min(1, Float(d) / Float(horizon))), at = (d - 1) * gw + x
                (water[at], water[flat + at], water[2 * flat + at], water[3 * flat + at]) = (pack(c), pack(c * 1.1), pack(c * 0.9), pack(c * 0.25 + sunlight * 0.75))
                water[4 * flat + at] = pack(c * 0.62) // under the far shore's hills, their mirror in place of the sky's
                water[5 * flat + at] = pack(c * 0.8) // and under a city's towers, what the ripples leave of theirs
                glint[at] = shining ? UInt8(255 * mix(0.75, 0.9, low) * exp(-abs(Float(x - sunAt.x)) / (5 + Float(d) * 0.45))) : 0
            }
        }
        // Lamps come on through dusk, each when the evening passes its own draw, as the airliner's do.
        (lamp, lights) = (pack(mix(rgb(255, 214, 150), rgb(255, 204, 128), night)), UInt8(min(255, night * 300)))
        for m in lamps.indices { lamps[m] = TrainMat.lit[UInt8(m)].map(pack) ?? lamp }
        lampFog = rings.map { UInt32(256 * (1 - exp(-$0.away * murk / 2))) } // (a light carries twice as far as a wall)
        // Snow: the cloud's own white, the nearest flakes most and the farthest half way to the air's colour.
        let white = mix(unpack(cloudTones[2]), RGB(repeating: 1), 0.5 * (1 - night)) * mix(1, 1.6, night)
        flake = [0.95, 0.75, 0.5].map { pack(mix(air, white, $0)) }
        wetLight = pack(mix(air, RGB(repeating: 1), 0.6 * (1 - 0.7 * night))) // water's bright side: the sky's light, turned over
        // The pole line, unless Settings has it off or it would cross the pane too fast to be calm. A change takes
        // hold two poles beyond the pane's leading edge, so every wire in view keeps both its poles.
        let poleSpace = world.focal / TrainWorld.poleAway, calm = polesOn && poleSpace * speed <= TrainWorld.poleLimit
        let ahead = Int(((Self.travelled + Double(gw / 2 + 8) / poleSpace) / TrainWorld.poleGap).rounded(.up)) + 1
        if strung.isEmpty { strung = [(.min, calm)] } else if strung.last!.on != calm { strung.append((ahead, calm)) }
        if strung.count > 1, strung[1].from < ahead - 4 - gw / Int(poleSpace * TrainWorld.poleGap) { strung.removeFirst() }
        if windowSize < 3 { paintFrame() }
        advance()
        compose()
    }

    /// The colours the country takes in the light as last worked out: the sky's light, the Sun's less what cloud
    /// hides of it (three fifths, with the Sun quite hidden), and the horizon's glow.
    private func relight() {
        let sun = daylight.key * (1 - 0.6 * Float(shade) / 32)
        // Weather that has put the day out dims the land by up to 45% (15% at night, which is lifted as it is) and
        // takes up to two fifths of its colour; and lightning lights it.
        let gloom = Float(weather?.gloom ?? 0), dim = 1 - gloom * mix(0.45, 0.15, night), flat = gloom * 0.4
        let light = (daylight.ambient + sun) * 0.78 * mix(1, 3.9, night) * dim + daylight.glow + rgb(214, 224, 255) * (flash * 0.28)
        let floor = rgb(9, 13, 27) * night, mats = TrainMat.day.count
        func lit(_ base: RGB) -> RGB {
            let c = pointwiseMin(base * light + floor, .one)
            return flat > 0 ? mix(c, RGB(repeating: (c.x + c.y + c.z) / 3), flat) : c
        }
        for (k, ring) in rings.enumerated() {
            let far = Float(1 - exp(-ring.away / hazed - ring.away * murk))
            for (m, base) in TrainMat.day.enumerated() { ringColours[k * mats + m] = pack(mix(lit(base), daylight.haze, far)) }
        }
        // The ground, in the five tones a dash can take in each of a row's kinds: the far fields, which have no
        // dashes unless they slide too fast to show as fields, and the four kinds of near field.
        for tones in 0..<5 {
            for level in 0..<5 {
                let lift = Float(level - 2) * (tones < 3 ? 0.03 : 0.045) + (tones > 0 && tones % 2 == 0 ? 0.022 : 0)
                for (m, base) in TrainMat.day.enumerated() { groundColours[((tones * 5) + level) * mats + m] = pack(lit(base * (1 + lift))) }
            }
        }
        (pole, wire) = (pack(lit(rgb(52, 44, 40))), pack(lit(rgb(44, 40, 40))))
    }

    /// How far off things fade to the horizon's colour where the train is, to the nearest 200 m. The country's colours
    /// are worked out again each time it changes (`compose`), so that the air thickens and thins a shade at a time as
    /// one country gives way to another, or a lake opens beside a city, and never in one step.
    private var reach: Double { (world.haze(Self.travelled) / 200).rounded() * 200 }

    /// How far cloud should be dimming the Sun's light, in thirty-seconds, with the train `x` metres along: a whole
    /// eighth or none, so that a cloud's ragged edge doesn't set it wavering.
    private func shadeWanted(with x: Double) -> Int { sunSpot.map { Int((cloud.hides($0, with: x) * 8).rounded()) * 4 } ?? 0 }

    /// How many pixels of the picture are lamps, and how big the picture is, for the tests: the night must never be
    /// without a lamp.
    var lit: Int { lights == 0 ? 0 : picture.count(where: Set(lamps).contains) }
    /// The same through weather: the pixels that are lamps with at least a third of their light left after the air.
    var litThroughWeather: Int {
        let seen = Set(rings.indices.filter { lampFog[$0] < 171 }.flatMap { ring in lamps.map { blend($0, mist, lampFog[ring]) } })
        return lights == 0 ? 0 : picture.count(where: seen.contains)
    }
    var pane: (w: Int, h: Int) { (glass.w, glass.h) }

    /// The carriage round the pane (PixelCarriage.swift), in the light of the moment.
    private func paintFrame() { cabin.texture = carriage.texture(night: Double(night), gloom: weather?.gloom ?? 0) }

    // MARK: - Motion (every frame)

    override func update(_ currentTime: TimeInterval) {
        let dt = min(max(currentTime - (lastUpdate ?? currentTime), 0), 0.1)
        lastUpdate = currentTime
        clock += dt
        if abs(Date().timeIntervalSince(redrawnAt)) >= 30 { redraw() }
        Self.travelled += min(max(currentTime - (Self.travelledAt ?? currentTime), 0), 0.1) * world.speed
        Self.travelledAt = currentTime
        if weather?.snow ?? 0 > 0 { snow.advance(by: dt, speed: world.speed, focal: world.focal) }
        if weather?.wet ?? 0 > 0 { rain.advance(by: dt, speed: world.speed, wide: glass.w) }
        // The near ground and the poles move several pixels a frame, so every frame is painted, 60 times a second at
        // most: at 30 a pole would step twice as far.
        if clock - painted >= 1 / 60.0 - 0.002 {
            advance()
            compose()
        }
    }

    /// Slides each ring and each row of ground on to where the train has got to, laying what comes into view.
    private func advance() {
        let gw = glass.w
        cloud.advance(to: Self.travelled)
        /// The columns to lay for a strip whose left edge was at `old` and is now at `first`: the new ones at its
        /// leading edge, or all of them if it is new or has jumped.
        func entering(_ old: Int, _ first: Int) -> Range<Int> { (old != .min && first > old && first - old < gw ? old + gw : first)..<first + gw }
        strips.withUnsafeMutableBufferPointer { strips in
            for k in rings.indices {
                let ring = rings[k], first = Int((Self.travelled * ring.perMetre).rounded(.down)) - gw / 2
                guard first != ring.first else { continue }
                // What comes into view from here on is laid by the speed and the Sun's side as they are now; what is
                // in view already keeps what it was laid by, until it has slid out.
                let new = entering(ring.first, first), now = TrainWorld.Laying(from: new.lowerBound, speed: world.speed, sun: world.sun)
                if new.lowerBound == first { rings[k].laid = [now] } else if ring.laid.last.map({ ($0.speed, $0.sun) != (now.speed, now.sun) }) ?? true { rings[k].laid.append(now) }
                if rings[k].laid.count > 1, rings[k].laid[1].from < first - 96 { rings[k].laid.removeFirst() }
                for n in new {
                    let slot = ((n % gw) + gw) % gw
                    tops[k * gw + slot] = world.column(k, n, into: strips.baseAddress! + ring.base + slot * ring.rows, by: rings[k].laid)
                }
                rings[k].first = first
            }
        }
        for r in rows.indices {
            let row = rows[r], first = Int((Self.travelled * row.perMetre).rounded(.down)) - gw / 2
            guard first != row.first else { continue }
            // A dash is as long as the speed makes it, so how far along its dashes a row has got is added up a pixel
            // at a time: a change of speed makes the dashes that come in longer or shorter, and moves none in view.
            let new = entering(row.first, first), long = world.dashLength(r + 1)
            var along = new.lowerBound == first ? Double(first) / long : row.dashed
            for n in new {
                let at = r * gw + ((n % gw) + gw) % gw
                (land[at], dash[at]) = world.ground(r + 1, n, dashed: along)
                along += 1 / long
            }
            (rows[r].first, rows[r].dashed) = (first, along)
        }
    }

    /// Paints the view: the sky, the ground a row at a time, then each ring from the farthest to the nearest, so
    /// that what stands in front hides what is behind.
    private func compose() {
        painted = clock
        let (gw, gh) = (glass.w, glass.h), mats = TrainMat.day.count
        if reach != hazed {
            hazed = reach
            relight()
        }
        // Cloud passing over the Sun dims the land, and gives it back, a step each sixteenth of a second: by where
        // the train was at that sixteenth, so that it goes the same at any frame rate.
        while shadeTick < Int(clock * 16) {
            shadeTick += 1
            let wanted = shadeWanted(with: Self.travelled - (clock - Double(shadeTick) / 16) * world.speed)
            if wanted != shade {
                shade += wanted > shade ? 1 : -1
                relight()
            }
        }
        let flashes = (0..<16).map { storms > 0 ? SeatWorld.lightning($0, at: clock) * storms : 0 }
        // A storm overhead: its lightning lights the land and all the cloud a little, and the cloud round the strike
        // a great deal.
        let strike = weather?.storm == true && storms > 0 ? TrainWeather.strike(at: clock) : (light: 0, across: 0, up: 0, draw: 0, forked: false)
        if strike.light != flash {
            flash = strike.light
            relight()
        }
        let struck = (x: Int(strike.across * Double(gw)), row: Int(strike.up * Double(cloud.rows)), light: flash)
        let tones = flash > 0 ? skyTones.map { blend($0, bolt, UInt32(flash * 50)) } : skyTones
        var above = [Int8](repeating: -1, count: gw) // the cloud's tones along the row of sky a row of water mirrors
        // How high what stands beyond a lake's far shore reaches, column by column, for the water to mirror; and
        // where that shore is a city's embankment, which its cap says.
        for i in 0..<gw { (skyline[i], fronted[i]) = (0, false) }
        for k in rings.indices where rings[k].away >= TrainWorld.farShore {
            var s = ((rings[k].first % gw) + gw) % gw
            let cap = rings[k].away == TrainWorld.farShore && rings[k].rows >= TrainWorld.embankment ? rings[k].base + TrainWorld.embankment - 1 : -1
            for i in 0..<gw {
                if cap >= 0 { fronted[i] = [TrainMat.quay, TrainMat.quayWhite].contains(strips[cap + s * rings[k].rows] & 127) }
                skyline[i] = max(skyline[i], rings[k].foot + Int(tops[k * gw + s]))
                s += 1
                if s == gw { s = 0 }
            }
        }
        picture.withUnsafeMutableBufferPointer { out in
            for i in horizon * gw..<gh * gw { out[i] = sky[i] }
            cloud.paint(into: out, horizon: horizon, tones: tones, bolt: bolt, flashes: flashes, strike: flash > 0 ? struck : nil)
            if strike.forked {
                TrainWeather.stroke(strike.draw, from: struck.x, struck.row, wide: gw) { x, row, main in
                    out[(horizon + row) * gw + x] = main ? bolt : blend(out[(horizon + row) * gw + x], bolt, 150)
                }
            }
            // The ground, and where a lake lies, its water: ripples a few pixels long that shimmer where they are and
            // don't slide (water has nothing in it to follow), each lighter, darker or plain for about a second, and
            // the Sun's glitter, reshuffled five times in two seconds. A row of water mirrors the row of the picture that
            // many rows above the horizon: the sky, or darkly, between its lighter ripples, the hills that stand there.
            // A city is not mirrored so, or its towers seem to go on down into the water: under its embankment lie three
            // rows of the shore's own dark image, the last of them in pieces; and under those only what the ripples
            // leave of a tower's, fainter, two fifths as long as the tower is tall and twelve rows at the most, fewer
            // of its pieces the farther down.
            let tick = Int(clock * 2.5), flat = gw * horizon
            for r in rows.indices {
                let row = rows[r], y = (horizon - 1 - r) * gw, at = r * gw, tones = row.tones * 5
                let d = r + 1, long = 3 + d / 5, lead = (d * 7) % long, shore = horizon + d * 8 / 5
                var s = ((row.first % gw) + gw) % gw, ripple = -1, tone = 0, sparkle: UInt8 = 0, mirrors = false, piece = 0.0
                for i in 0..<gw {
                    if land[at + s] == TrainMat.water {
                        // (What the water mirrors is the sky eight rows up for every five down: cloud, if cloud is there.)
                        if !mirrors { (mirrors, _) = (true, cloud.tones(min(d * 8 / 5, cloud.rows - 1), into: &above)) }
                        if (i + lead) / long != ripple {
                            ripple = (i + lead) / long
                            let draw = chance(ripple, d * 131 + (tick + ripple) / 3, 60)
                            (tone, sparkle) = (draw < 0.16 ? 1 : draw > 0.90 ? 2 : 0, scatter(ripple, d * 17 + tick, 61))
                            piece = chance(ripple, d * 53 + (tick + ripple) / 3, 63)
                        }
                        let shines = Int(sparkle) * 32 < Int(glint[at + i]) * (32 - shade) // (no glitter from a Sun behind cloud)
                        // (The far shore's hills stand before the cloud behind them, and their image is the darker.)
                        var image = shines ? 3 : -1
                        if !shines, tone != 1 {
                            if !fronted[i] {
                                if shore < skyline[i] { image = 4 }
                            } else if d <= 4 {
                                if d < 4 || piece < 0.5 { image = 4 }
                            } else {
                                let deep = min((skyline[i] - horizon) * 2 / 5, 12)
                                if d - 4 <= deep, piece < 0.75 - 0.6 * Double(d - 4) / Double(deep) { image = 5 }
                            }
                        }
                        out[y + i] = image >= 0 ? water[image * flat + at + i]
                            : above[i] < 0 ? water[tone * flat + at + i] : mirrored[r * 15 + Int(above[i]) * 3 + tone]
                    } else {
                        out[y + i] = groundColours[(tones + Int(dash[at + s])) * mats + Int(land[at + s])]
                    }
                    s += 1
                    if s == gw { s = 0 }
                }
                if fog[r] > 0 { for i in y..<y + gw { out[i] = blend(out[i], mist, fog[r]) } } // the weather's air over it
            }
            reflected.removeAll(keepingCapacity: true)
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
                                let glow = lampFog[k] == 0 ? lamps[Int(cell & 127)] : blend(lamps[Int(cell & 127)], mist, lampFog[k]) // through the weather's air
                                out[(ring.foot + up) * gw + i] = glow
                                if ring.away >= TrainWorld.farShore { reflected.append((i, glow)) }
                            } else if cell & 127 != 0, cell & 127 < TrainMat.lampSodium { // (a light with nothing drawn under it shows only when lit)
                                out[(ring.foot + up) * gw + i] = ringColours[colours + Int(cell & 127)]
                            }
                        }
                    }
                    s += 1
                    if s == gw { s = 0 }
                }
            }
            // Each lamp on a lake's far shore leaves a broken streak of its colour in the water under it, fainter toward us.
            let flicker = Int(clock * 2) * 31
            for (i, colour) in reflected {
                let glow = unpack(colour)
                for d in 1...min(13, horizon) where land[(d - 1) * gw + ((rows[d - 1].first + i) % gw + gw) % gw] == TrainMat.water
                    && chance(i, d + flicker, 71) < 0.5 - Double(d) * 0.055 {
                    let at = (horizon - d) * gw + i
                    out[at] = pack(unpack(out[at]) * 0.45 + glow * (0.55 * (1 - Float(d) / 16)))
                }
            }
            // Snow falling, in front of the country and behind the poles.
            if let heavy = weather?.snow, heavy > 0 {
                snow.flakes(heavy: heavy, wide: gw, high: gh) { x, y, layer in
                    out[y * gw + x] = flake[layer]
                    if layer == 0, x + 1 < gw { out[y * gw + x + 1] = flake[0] } // (the nearest are two pixels long)
                }
            }
            // The pole line, in front of it all: its wires let two thirds of themselves show.
            world.poleLine(at: Self.travelled, wide: gw, high: gh, horizon: horizon, where: { k in strung.last { $0.from <= k }?.on ?? false }) { x, y, standing in
                out[y * gw + x] = standing ? pole : blend(out[y * gw + x], wire, 166)
            }
            // Rain on the glass, over everything outside.
            if let wet = weather?.wet, wet > 0 { rain.paint(out, wide: gw, high: gh, wet: wet, clock: clock, mist: mist, light: wetLight) }
            // Last, what the carriage's lamp leaves in the glass: it lies in front of everything outside.
            if windowSize < 3 { carriage.reflect(out, ghost: PixelCarriage.light(Double(night), gloom: weather?.gloom ?? 0).ghost) }
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
    var laid: [TrainWorld.Laying] = [] // what its columns were laid by, oldest first
}

/// One row of ground: how many pixels a metre along the track spans there, which tones its dashes take (0 for the
/// far fields), the pixel of its endless strip at the pane's left edge, and how far along its dashes, in dashes, the
/// next pixel to come into view is.
private struct GroundRow {
    let perMetre: Double, tones: Int
    var first = Int.min, dashed = 0.0
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
    /// A lake's water, in the ground rows only: it has no colour of its own, and takes the sky's (`PixelTrain.water`).
    static let water: UInt8 = 32
    /// The other countries' (TrainScenery.swift): rock, snow and ice, an alp's grass, a chalet's timber, a glacier's
    /// river; a cabin's red paint and a dwarf birch's twigs; sand, steppe grass, scrub, a mesa's bands and a dirt
    /// track; a city's concrete, glass towers, tar and rails. `glassCool` is a window that lights white. A city's shore
    /// across a lake is an embankment, a dark foot under a pale cap, which is the same stone twice: a lamp that stands
    /// on `quay` lights sodium, and one on `quayWhite` white. The last four are lights with nothing drawn under them
    /// by day: a street lamp, a red light on a tower, a green sign, a white lamp.
    static let rock: UInt8 = 33, rockShade: UInt8 = 34, snow: UInt8 = 35, snowShade: UInt8 = 36, ice: UInt8 = 37, alp: UInt8 = 38
    static let chalet: UInt8 = 39, chaletShade: UInt8 = 40, river: UInt8 = 41, falu: UInt8 = 42, faluShade: UInt8 = 43, birch: UInt8 = 44
    static let sand: UInt8 = 45, sandShade: UInt8 = 46, steppe: UInt8 = 47, steppeDry: UInt8 = 48, scrub: UInt8 = 49, scrubShade: UInt8 = 50
    static let mesa: UInt8 = 51, mesaShade: UInt8 = 52, mesaPale: UInt8 = 53, track: UInt8 = 54
    static let concrete: UInt8 = 55, concreteShade: UInt8 = 56, tower: UInt8 = 57, towerShade: UInt8 = 58, tar: UInt8 = 59, rail: UInt8 = 60
    static let glassCool: UInt8 = 61, quayShade: UInt8 = 62, quay: UInt8 = 63, quayWhite: UInt8 = 64
    static let lampSodium: UInt8 = 65, lampRed: UInt8 = 66, lampGreen: UInt8 = 67, lampWhite: UInt8 = 68
    /// What colour a lit thing is after dark, where it isn't a lamp's own warm one.
    static let lit: [UInt8: RGB] = [glassCool: rgb(222, 232, 255), lampWhite: rgb(222, 232, 255), lampSodium: rgb(255, 172, 94),
                                    lampRed: rgb(255, 88, 72), lampGreen: rgb(118, 230, 212), quay: rgb(255, 172, 94), quayWhite: rgb(222, 232, 255)]
    /// Each one's colour in full daylight, before the haze.
    static let day: [RGB] = [
        .zero, rgb(40, 78, 50), rgb(60, 106, 58), rgb(94, 138, 68), rgb(64, 52, 46), rgb(32, 64, 54), rgb(48, 88, 66),
        rgb(228, 222, 206), rgb(176, 176, 178), rgb(164, 100, 80), rgb(120, 74, 66), rgb(176, 166, 150), rgb(130, 124, 118),
        rgb(150, 72, 58), rgb(112, 56, 52), rgb(88, 92, 108), rgb(64, 68, 84), rgb(58, 66, 88), rgb(70, 52, 44),
        rgb(50, 90, 48), rgb(70, 112, 56), rgb(128, 126, 126), rgb(58, 50, 46),
        rgb(208, 190, 116), rgb(118, 164, 88), rgb(90, 144, 76), rgb(152, 124, 94), rgb(214, 200, 96), rgb(150, 180, 108), rgb(190, 170, 124),
        rgb(86, 128, 70), rgb(120, 112, 104), .zero,
        rgb(140, 136, 140), rgb(98, 98, 114), rgb(236, 240, 250), rgb(160, 180, 222), rgb(200, 222, 238), rgb(134, 172, 84),
        rgb(118, 82, 58), rgb(86, 62, 48), rgb(150, 196, 200), rgb(150, 52, 46), rgb(108, 42, 42), rgb(128, 116, 118),
        rgb(218, 188, 136), rgb(178, 146, 110), rgb(192, 170, 106), rgb(168, 152, 98), rgb(122, 128, 88), rgb(94, 102, 76),
        rgb(178, 110, 82), rgb(136, 84, 74), rgb(200, 140, 98), rgb(200, 176, 136),
        rgb(152, 152, 158), rgb(114, 116, 126), rgb(90, 116, 146), rgb(62, 84, 114), rgb(72, 74, 82), rgb(156, 156, 166),
        rgb(58, 66, 88), rgb(62, 64, 74), rgb(198, 192, 178), rgb(198, 192, 178), .zero, .zero, .zero, .zero,
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
    /// What keeps it calm at any speed, in pixels a second: a lamp is laid only where it slides no faster than
    /// `bright` (a pixel a frame at 30 frames a second), other thin things (a pole, a hedge's end, a spire) no faster
    /// than `thin`, and broad ones (a tree, a house, a field) no faster than `broad`. At 1× the fastest lamp is at 20,
    /// the fastest thin thing is a field's hedge 103 m out, at 34, and the nearest ring's trees are at 32.
    static let bright = 30.0, thin = 36.0, broad = 60.0

    /// What a ring's things are laid by, from one of its columns on: the train's speed and the side the Sun was on
    /// when that column came into view. A thing wider than a column goes by where its left edge is, so a change of
    /// speed never leaves half a tree.
    struct Laying { let from: Int, speed: Double, sun: Int }

    /// The line of telegraph poles beside the track, which Dave picked from the mock-ups' film: `poleAway` metres
    /// out, a pole every `poleGap` metres and `poleTall` high. It is nearer than anything a ring holds, the one near
    /// thing with a shape: at 1× a pole crosses the pane in 2.7 s, one every 3.75 s. It is left out where it would
    /// slide faster than `poleLimit` pixels a second (from 1.8×), when a pole would cross in under a second and a half.
    static let poleAway = 28.0, poleGap = 50.0, poleTall = 8.2, poleLimit = 230.0

    /// The lens, in pixels per unit of tangent; the eye's height above the ground, in metres; and the train's speed
    /// in metres a second, which sets how long the near ground's dashes are and what is too fast to lay.
    let focal: Double, eye: Double
    var speed: Double
    /// Which side things are lit from: 1 from the right of the picture, -1 from the left.
    var sun = 1
    /// Settings' Scenery: 0 for whatever comes, 1 for countryside, 2 for a lake beside the line, 3 for mountains,
    /// 4 for a city, 5 for snow, 6 for desert, 7 for a city with a lake beside the line.
    var scenery = 0
    /// A lake's far shore is the ring this far off, and those beyond it: nearer rings stand on our side of the water.
    static let farShore = 1800.0
    /// How much more readily a lake lies beside a city than beside other country, left to change (see `shore`).
    static let harbour = 0.07

    /// How far from the track the land reaches before a lake begins, at a place along the line: no way at all where
    /// a lake lies beside the line, and for ever where there is none. Left to change, lakes lie along a third of the
    /// line, about 5 km of it at a time (six minutes at 1×) with 8 km of country between, and at each end the shore
    /// closes in on the track over a few hundred metres. A city has more water beside it than other country, by
    /// `harbour`, since its lights across a lake are the best the night has: none more at its edge, where it
    /// meets farmland, and all of it from 3 km in.
    func shore(_ wx: Double) -> Double {
        guard scenery == 0 else { return scenery == 2 || scenery == 7 ? 0 : .infinity }
        var lake = fbm(wx / 5000, 11, 2, 5150) - 0.57
        guard lake > -Self.harbour else { return .infinity }
        let place = country(wx)
        if place.kind == .city { lake += Self.harbour * place.relief(0) }
        guard lake > 0 else { return .infinity }
        let near = 1 - min(lake / 0.04, 1)
        return Self.farShore * near * near
    }

    /// How many pixels a metre stands, and spans along the track, at a ring.
    func perMetre(_ ring: Int) -> Double { focal / Self.rings[ring] }

    /// How many rows a ring's strip needs for the tallest thing that can stand there.
    func rows(_ ring: Int) -> Int {
        let z = Self.rings[ring], ppm = focal / z
        let most = z >= 15000 ? (z >= 30000 ? 2600 : 950) * ppm + 1 : (34 * ppm).rounded(.up) + 3 + Self.rise[ring] * ppm
        return min(max(Int(most.rounded(.up)), 2, otherRows(ring)), 255)
    }

    /// Lays column `n` of a ring into `cells`, its foot first: far off, a hill or a range as a line of heights,
    /// wooded, farmed or under snow; nearer, the land's own swell with its hedged fields and the woods along its
    /// top, and on it whatever stands in that plot of track: a tree, a fir, a house, a church. A cell's top bit marks
    /// a lamp: a window, or a light in a far town, that comes on after dark. `laid` is what the ring's columns are
    /// laid by (the speed and the Sun's side as they are, if nothing is given). Returns how many of the strip's rows
    /// the column uses.
    func column(_ ring: Int, _ n: Int, into cells: UnsafeMutablePointer<UInt8>, by laid: [Laying] = []) -> UInt8 {
        let z = Self.rings[ring], ppm = focal / z, wx = Double(n) / ppm, salt = UInt64(z), rows = rows(ring)
        cells.update(repeating: 0, count: rows)
        let land = country(wx), relief = land.relief(z) // (1 unless Scenery is left to change: the land sinks where one country meets the next)
        if land.kind != .farmland, land.kind != .city || z < 30000 { // (a city lies in farmland, under its far hills)
            return otherColumn(land.kind, ring, n, into: cells, by: laid, relief: relief)
        }
        if z >= 15000 {
            let high: Double
            if z >= 30000 {
                let ridge = 1 - abs(2 * fbm(wx / 26000, z / 9000, 5, salt) - 1)
                high = 2600 * (ridge * ridge) * clip((fbm(wx / 90000, 3, 2, salt + 9) - 0.42) * 5)
            } else {
                high = 950 * clip(fbm(wx / (z * 0.9), z / 4000, 4, salt) * 1.5 - 0.28)
            }
            let top = min(Int((high * relief * ppm).rounded(.toNearestOrEven)), rows)
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
        guard z >= Self.farShore || z <= shore(wx) else { return 0 } // out in a lake
        /// How fast the ring slid, in pixels a second, and which side the Sun was on, when column `n` came into view.
        func when(_ n: Int) -> (pace: Double, sun: Int) {
            let by = laid.last { $0.from <= n } ?? laid.first
            return (ppm * (by?.speed ?? speed), by?.sun ?? sun)
        }
        let pace = when(n).pace
        let rise = Self.rise[ring], swell = rise == 0 ? 0 : rise * clip(fbm(wx / (z * 1.3) + 3, z / 2000, 3, salt + 60) * 1.7 - 0.42) * relief
        let swollen = Int((swell * ppm).rounded(.toNearestOrEven)), face = min(swollen, rows)
        if face > 0 {
            let long = Self.fieldLength[ring], deep = max(2, Double(swollen) / 3 + 0.5)
            let town = z >= 1800 && pace <= Self.bright && noise(wx / 1400, 2, 4242) > 0.62
            for up in 0..<face {
                let band = (Double(up) / deep).rounded(.down), along = wx / long + band * 0.37
                let crop = Self.fields[Int(unit(hash(Int(along.rounded(.down)), Int(band), salt + 61)) * Double(Self.fields.count))]
                cells[up] = fbm(wx / (z * 0.2), Double(up) / 3, 3, salt + 62) > 0.63 ? TrainMat.leaf0 : crop
                if pace <= Self.thin, abs(along - along.rounded(.toNearestOrEven)) * long * ppm < 0.6 { cells[up] = TrainMat.hedge }
                if town, unit(hash(n, up, salt + 63)) < 0.035 { cells[up] |= 128 }
            }
        }
        var top = face
        // Woods along its top, where the country is wooded: a ragged line too far off to tell one tree from the next.
        if z >= 500 {
            let wooded = fbm(wx / 900, z / 300, 3, salt + 1)
            let tall = Int(((10 + 14 * fbm(wx / 60, 1, 3, salt + 2)) * ppm * clip((wooded - 0.50) * 9) * relief).rounded(.toNearestOrEven))
            top = min(face + tall, rows)
            for up in face..<top { cells[up] = unit(hash(n, up, salt + 3)) < 0.35 ? TrainMat.leaf1 : TrainMat.leaf0 }
        }
        // What stands in the plots of track round this column, one thing to a plot, the later over the earlier: a
        // church or houses where a village lies (the same villages on every ring), a farm on its own, or a tree, more
        // of them where the country is wooded. Each stands on the swell's face.
        let plot = Self.plot[ring], here = Int((wx / plot).rounded(.down))
        if z <= 1800 {
            for c in here - 2...here + 2 {
                let draw = unit(hash(c, 1, salt + 30)), at = (Double(c) + unit(hash(c, 2, salt + 31))) * plot
                guard z >= Self.farShore || z <= shore(at) else { continue } // its plot is in the water, though this column isn't
                guard stands(at, in: .farmland) else { continue } // or in another country, or astride the two
                let village = noise(at / 1400, 2, 4242), seed = Int(hash(c, 3, salt + 32) % (1 << 30))
                let stamp: Stamp, spired = z == 900 && village > 0.70 && draw < 0.2
                if spired {
                    stamp = .church(30 * ppm)
                } else if village > 0.64, draw < Self.housed[ring] {
                    stamp = .house(max(2, 5.0 * ppm), seed)
                } else if draw < Self.farmed[ring] {
                    stamp = .house(max(2, 5.5 * ppm), seed)
                } else if z <= 900, draw > 1 - min(max(0.18 + (fbm(at / 900, z / 300, 3, salt + 1) - 0.45) * 2.2, 0.08), 0.8) {
                    let high = 9 + 9 * unit(hash(c, 4, salt + 33))
                    stamp = unit(hash(c, 5, salt + 34)) < 0.2 ? .fir(high * 1.2 * ppm) : .tree(high * ppm, seed)
                } else {
                    continue
                }
                let left = Int((at * ppm).rounded(.toNearestOrEven)) - stamp.w / 2, entered = when(left) // (all of it goes by its left edge)
                let lift = Int(Double(swollen) * (0.35 + 0.65 * unit(hash(c, 6, salt + 35))))
                guard n >= left, n < left + stamp.w, lift + stamp.h <= rows, entered.pace <= (spired ? Self.thin : Self.broad) else { continue }
                for (y, material) in stamp.column(n - left, entered.sun).enumerated() where material != 0 {
                    let up = lift + stamp.h - 1 - y
                    cells[up] = cells[up] & 128 | material
                    if material == TrainMat.glass, entered.pace <= Self.bright, unit(hash(seed + n - left, y, 55)) < 0.8 { cells[up] |= 128 }
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
        guard pace <= Self.bright else { return UInt8(top) }
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

    /// Draws the pole line for a pane `wide` by `high` whose horizon is on its row `horizon`, with the train `x`
    /// metres along: `plot` is given each pixel by its column and its row (from the bottom), and whether it is a
    /// pole's or a wire's. Two wires, one on the cross-arm and one under it, rise to each pole and sag between.
    /// `strung` says whether the line has a pole at each place along it, counted in poles: all of them, if not given.
    func poleLine(at x: Double, wide: Int, high: Int, horizon: Int, where strung: (Int) -> Bool = { _ in true }, _ plot: (Int, Int, Bool) -> Void) {
        let ppm = focal / Self.poleAway, gap = Self.poleGap * ppm, first = Int((x * ppm).rounded(.down)) - wide / 2
        // (In rows down from the pane's top, as the mock-ups count them, so that a wire rounds the way theirs does.)
        let foot = high - horizon + Int((eye * ppm).rounded(.toNearestOrEven)), top = foot - Int((Self.poleTall * ppm).rounded(.toNearestOrEven))
        /// Whether pole `k` of the line stands on land: a lake that comes in nearer than the line has none.
        func stands(_ k: Int) -> Bool { strung(k) && shore(Double(k) * Self.poleGap) > Self.poleAway && country(Double(k) * Self.poleGap).kind != .city }
        let pole = Int((Double(first) / gap).rounded(.down)), standing = (pole - 1...pole + wide / max(Int(gap), 1) + 2).map(stands)
        for i in 0..<wide {
            let spans = Double(first + i) / gap, along = spans - spans.rounded(.down), sag = 4 * along * (1 - along)
            let span = Int(spans.rounded(.down)) - pole + 1 // (a wire hangs only between two poles that stand)
            guard standing.indices.contains(span + 1), standing[span], standing[span + 1] else { continue }
            for (under, drop) in [(3.0, 5.0), (9.0, 6.0)] {
                let y = Int((Double(top) + under + drop * sag).rounded(.toNearestOrEven))
                if y >= 0, y < high { plot(i, high - 1 - y, false) }
            }
        }
        for k in pole - 1...Int((Double(first + wide) / gap).rounded(.down)) + 1 where stands(k) {
            let at = Int((Double(k) * gap).rounded(.toNearestOrEven)) - first
            for y in top..<foot where y >= 0 && y < high {
                let arm = y == top + 2 || y == top + 3 // the cross-arm, twelve pixels across
                for x in at - (arm ? 5 : 0)..<at + (arm ? 7 : 2) where x >= 0 && x < wide { plot(x, high - 1 - y, true) }
            }
        }
    }

    /// Which tones the dashes of the ground row `d` rows under the horizon take: 0 beyond 100 m, where there are
    /// none; else 1 or 2 for a field and 3 or 4 for the verge, the rows banded three at a time.
    func tones(_ d: Int) -> Int {
        let z = eye * focal / Double(d)
        return z > 100 ? 0 : (z > Self.verge ? 1 : 3) + (d / 3) % 2
    }

    /// How many pixels long a dash of the ground row `d` rows under the horizon is: at least twice as far as the row
    /// moves in a thirtieth of a second, so nothing in it can strobe.
    func dashLength(_ d: Int) -> Double { max(10, 2.2 * speed * (Double(d) / eye) / 30) }

    /// What lies at pixel `n` of the ground row `d` rows under the horizon, and which of the five tones of its
    /// dash it takes. Beyond 100 m, fields a stretch of track long in belts of distance, hedged. Nearer, or where a
    /// row slides too fast to show its fields, one crop for a long way, a lane and its hedge, then the railway's
    /// grass, all drawn out into soft dashes. `dashed` is how far along the row's dashes the pixel is, in dashes: by
    /// its place, if not given, which is right at one steady speed.
    func ground(_ d: Int, _ n: Int, dashed: Double? = nil) -> (land: UInt8, dash: UInt8) {
        let z = eye * focal / Double(d), ppm = Double(d) / eye, wx = Double(n) / ppm, pace = ppm * speed
        if z > shore(wx) { return (TrainMat.water, 0) }
        let look = country(wx).kind.ground // what this country's rows are made of
        if z > 100, pace <= Self.broad {
            let belt = d <= 1 ? 0 : d <= 2 ? 1 : d <= 4 ? 2 : 3, long = 230.0 + 60 * Double(belt)
            let along = wx / long + Double(belt) * 0.37, field = Int(along.rounded(.down))
            // A field is all one country's, the one its middle lies in: where two countries meet, the far fields end at
            // their own edges, each belt at another place, and not along one line square to the track.
            let look = scenery == 0 ? country((Double(field) + 0.5 - Double(belt) * 0.37) * long).kind.ground : look
            if let hedge = look.hedge, pace <= Self.thin, abs(along - along.rounded(.toNearestOrEven)) * long < max(1.5, 1.2 / ppm),
               unit(hash(field, belt, 4101 + look.salt)) < 0.6 { return (hedge, 2) }
            return (look.fields[Int(unit(hash(field, belt, 4100 + look.salt)) * Double(look.fields.count))], 2)
        }
        let tone = fbm(dashed ?? Double(n) / dashLength(d), Double(d) / 3, 2, 4300)
        // One crop for a long way means for a long time: above 1× a crop is as many times longer as the train is
        // faster, so one still lasts a couple of minutes, and its end is drawn out, the two crops by turns, dash by
        // dash, for a few seconds, where a hard edge would sweep the whole near field in a blink. (Faster in steps of
        // a half again, so that a drag of the Speed slider changes the crops' length a few times and not at every
        // tick: each change can start a new crop at the leading edge.)
        let faster = pow(1.5, (log(max(1, speed / PixelTrain.pace)) / log(1.5)).rounded()), soft = faster > 1 ? (tone - 0.5) * 0.06 : 0
        let lane = Int((eye * focal / Self.lane).rounded(.toNearestOrEven))
        // Where two countries meet, the near field's crops change dash by dash over a hundred metres: changing at one
        // column, they swept the near field as a hard-edged wedge. (Held to one scenery, both are the same country.)
        let place = country(wx), crops = country(wx + (tone - 0.5) * min(look.mixing, place.beside?.ground.mixing ?? look.mixing)).kind.ground
        let land = d == lane - 2 ? look.lines.0 : d == lane - 1 ? look.lines.1 : d == lane ? look.lines.2
            : look.rails.contains { Int((eye * focal / $0).rounded(.toNearestOrEven)) == d } ? look.rail
            : z > Self.lane ? (fbm(wx / (1500 * faster), 0.5, 2, 4200 + crops.salt) + soft > 0.5 ? crops.far.0 : crops.far.1)
            : z > Self.verge ? (fbm(wx / (1900 * faster), 1.5, 2, 4201 + crops.salt) + soft > 0.5 ? crops.near.0 : crops.near.1) : crops.verge
        return (land, UInt8(min(max((tone * 5).rounded(.down), 0), 4)))
    }
}

/// A small drawn thing that stands on a ring, `w` pixels wide and `h` tall: `column` gives one of its columns, its
/// top first, 0 where it is see-through. They are the mock-ups' own (train.py), and lit from the side `sun` says:
/// 1 from the right.
struct Stamp {
    let w: Int, h: Int, column: (_ x: Int, _ sun: Int) -> [UInt8]

    /// A broadleaf tree `tall` pixels high: a ragged round crown in three tones over a trunk.
    static func tree(_ tall: Double, _ seed: Int) -> Stamp {
        let h = max(3, Int(tall)), w = max(3, Int((Double(h) * (0.62 + 0.22 * unit(hash(seed, 1, 5)))).rounded(.toNearestOrEven)))
        let crown = h - max(1, Int((Double(h) * 0.24).rounded(.toNearestOrEven))), cy = Double(crown - 1) / 2, cx = Double(w - 1) / 2
        let stem = Int(cx)..<Int(cx) + (h < 20 ? 1 : 2)
        return Stamp(w: w, h: h) { x, sun in
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
    static func fir(_ tall: Double) -> Stamp {
        let h = max(4, Int(tall)), w = max(3, Int((Double(h) * 0.42).rounded(.toNearestOrEven)) | 1), cx = w / 2
        return Stamp(w: w, h: h) { x, sun in
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
    static func house(_ eaves: Double, _ seed: Int) -> Stamp {
        let walls = [(TrainMat.white, TrainMat.whiteShade), (TrainMat.brick, TrainMat.brickShade), (TrainMat.stone, TrainMat.stoneShade)][Int(unit(hash(seed, 2, 21)) * 3)]
        let roofs = unit(hash(seed, 3, 22)) < 0.55 ? (TrainMat.roof, TrainMat.roofShade) : (TrainMat.slate, TrainMat.slateShade)
        let wall = max(2, Int(eaves)), w = max(4, Int((Double(wall) * (1.5 + 0.9 * unit(hash(seed, 4, 23)))).rounded(.toNearestOrEven)))
        let roof = max(2, Int((Double(wall) * 0.7).rounded(.toNearestOrEven))), hipped = unit(hash(seed, 5, 24)) < 0.5
        let chimney = unit(hash(seed, 6, 25)) < 0.6 && w > 5 ? (unit(hash(seed, 7, 26)) < 0.5 ? w - 2 : 1) : -1
        return Stamp(w: w, h: wall + roof) { x, sun in
            var column = [UInt8](repeating: 0, count: wall + roof)
            let shade = sun > 0 ? 0..<max(1, w / 4) : w - max(1, w / 4)..<w, firstWindow = 1 + (sun > 0 ? w / 4 : 0), between = max(2, wall / 2 + 1)
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
    static func church(_ tall: Double) -> Stamp {
        let h = max(6, Int(tall)), nave = max(2, h / 3), tower = max(2, h / 5), spire = h - Int(Double(h) * 0.62)
        return Stamp(w: max(4, Int(Double(h) * 0.9)) + tower, h: h) { x, sun in
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

/// A random byte for a pixel, and a random number from 0 up to 1. (Inside the scene, `hash` is the object's own.)
@inline(__always) private func scatter(_ x: Int, _ z: Int, _ salt: UInt64) -> UInt8 { UInt8(truncatingIfNeeded: hash(x, z, salt) >> 56) }
@inline(__always) private func chance(_ x: Int, _ z: Int, _ salt: UInt64) -> Double { unit(hash(x, z, salt)) }

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

/// One packed colour moved toward another by `t` parts in 256.
@inline(__always) private func blend(_ a: UInt32, _ b: UInt32, _ t: UInt32) -> UInt32 {
    let redBlue = ((a & 0xFF00FF) * (256 - t) + (b & 0xFF00FF) * t) >> 8 & 0xFF00FF
    return 0xFF00_0000 | redBlue | ((a & 0xFF00) * (256 - t) + (b & 0xFF00) * t) >> 8 & 0xFF00
}

private func rgb(_ r: Int, _ g: Int, _ b: Int) -> RGB { RGB(Float(r), Float(g), Float(b)) / 255 } // as in PixelCity.swift, which says why

private func unpack(_ c: UInt32) -> RGB { RGB(Float(c & 255), Float(c >> 8 & 255), Float(c >> 16 & 255)) / 255 }

private func pack(_ c: RGB) -> UInt32 {
    let c = pointwiseMin(pointwiseMax(c, .zero), .one) * 255
    return 0xFF00_0000 | UInt32(c.z) << 16 | UInt32(c.y) << 8 | UInt32(c.x)
}
