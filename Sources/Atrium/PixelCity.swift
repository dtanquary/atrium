import SpriteKit

@MainActor func pixelCity(size: CGSize) -> SKScene { PixelCity(size: size) }

/// A pixel-art city that follows the real sun and clock: dawn, day, dusk and night skies, windows lighting up and
/// going dark through the evening, traffic, a blinking beacon and the odd plane, with walls lit from wherever the
/// Sun really is. Everything lives on a low-resolution canvas measured in art pixels, scaled up with nearest
/// filtering. Settings picks the city (`City`): a downtown across water, one under mountains, a bridge over a bay,
/// a town up a hillside, the view over a sea of rooftops, an airport with aircraft coming and going, or a launch
/// site whose rockets lift off and whose boosters come back.
final class PixelCity: SKScene {
    nonisolated static let knobs = [
        Knob(key: "city.place", label: "City", range: 0...Double(City.allCases.count - 1), standard: 0, section: "City",
             format: .choice(City.allCases.map(\.name))),
        Knob(key: "city.shuffle", label: "Move to another city automatically", range: 0...1, standard: 0, section: "City",
             format: .toggle),
        Knob(key: "city.shuffleMinutes", label: "Move every", range: 1...60, standard: 10, section: "City", format: .minutes,
             shownWhen: "city.shuffle"),
        Knob(key: "city.looking", label: "Looking", range: 0...8, standard: 0, section: "City",
             format: .choice(["Toward the midday Sun", "North", "North-east", "East", "South-east", "South", "South-west", "West", "North-west"])),
        Knob(key: "city.flightsDay", label: "Flights by day", range: 0.25...3, standard: 1, section: "Airport", format: .times),
        Knob(key: "city.flightsNight", label: "Flights at night", range: 0.25...3, standard: 0.7, section: "Airport", format: .times),
        Knob(key: "city.wind", label: "Land and take off into the real wind", range: 0...1, standard: 1, section: "Airport",
             format: .toggle),
        Knob(key: "city.launches", label: "Launches", range: 0.25...3, standard: 1, section: "Spaceport", format: .times),
        Knob(key: "city.previewTime", label: "Preview a time of day", range: 0...1, standard: 0, section: "Preview",
             format: .toggle),
        Knob(key: "city.previewHour", label: "Time", range: 0...24, standard: 19, section: "Preview", format: .clock,
             shownWhen: "city.previewTime"),
    ]
    private enum K: Int { case view, shuffle, shuffleMinutes, looking, flightsDay, flightsNight, wind, launches, previewTime, previewHour }
    private static func knob(_ k: K) -> Double { knobs[k.rawValue].value }
    private var settings = PixelCity.knobs.map(\.value)
    private var retired = false // it has handed over to a scene of another city, and is fading out
    private static var easing = false // the city is changing by itself, so take the fade slowly
    /// When the city last changed, for the automatic move. It's the wall clock, saved, not time counted by this scene:
    /// the app's own Shuffle, a relaunch or a rebuild all make a new scene, and the wait has to carry across them.
    private static let movedKey = "city.movedAt"

    private let w: Int, h: Int
    private var city = City.waterfront
    private var ground = 26 // the row the city stands on
    private var streetBase: Int { ground - 26 } // where there's a street, its bottom row: road and sidewalks fill the 26 above
    private var waterRows = 0 // rows of water along the bottom, in the cities that have it
    private let quay = 6 // rows of quay wall above the water
    private var crest: [Int] = [] // for each column, the row where the sky begins: the horizon the Sun and Moon rise over
    private var skyBase = 26 // the lowest of those, where the sky's gradient starts
    private var downtown: Float = 0.5 // how far across the city's centre is
    private var ridges: [[Float]] = [] // the Foothills' mountains, far to near: each ridge's height above the ground by column
    private var farHaze: Float = 1 // how much of the usual haze the far row of buildings takes
    private var slope: [Float] = [] // Hillside Town's hill: how far the land stands above the quay at each column
    private var boats: [(node: SKSpriteNode, rows: [String], hull: RGB)] = []
    // The Overlook's life: steam from its vents, a flock of pigeons wheeling over the roofs, lights on the far towers.
    private var steam: [SKSpriteNode] = []
    private var flock: [(node: SKSpriteNode, lag: Float, offset: SIMD2<Float>)] = []
    private var towerLights: [SKSpriteNode] = []
    // The Airport: its aircraft, the rows their wheels stand on, where the stands are, and which way the runway is in use.
    private var flights: [Flight] = []
    private var runway = 0, taxiway = 0, apron = 0
    private var stands: [Int] = []
    private var runwayWay: Float = 1
    private(set) var movements = 0 // landings and take-offs (or lift-offs) so far, for the tests
    // The Spaceport: its pad, the boosters that come back, the crane that takes them away and the smoke of it all;
    // the layer they are painted into, which the lagoon mirrors; and the figures on the countdown clock.
    private var pad = Pad(), boosters: [Booster] = [], crane = Crane(), plume: [Puff] = []
    private var liftoffAt: TimeInterval = -1000, trailFrom: SIMD2<Float>?
    private var launchLayer = SKSpriteNode(), launchTexture: SKMutableTexture?, launchShown: [Int] = []
    private var smoke = Bytes(1, 1, floor: 0), density: [Float] = [], smokeTime: Float = 0, smokeMoved = false, smokeSteps = 0
    private var countdown = SKSpriteNode(), counted = ""
    private var hazeColour = RGB.zero // the horizon's colour, which far-off things fade toward
    private let canvas = SKNode()
    private let sky = SKSpriteNode()      // sky, stars, Sun and Moon…
    private let backdrop = SKSpriteNode() // …and the city in front, so clouds and planes pass between the two
    private var mirrored: [SKUniform] = []   // the sky and city textures the water reflects…
    private var waterTints: [SKUniform] = [] // …and the colours of deep water and of the glints on it
    // …and the things that move, which aren't in those paintings: each aircraft or boat, the freighter, and a strip
    // the traffic is painted into. For each, its picture and where it is (see `reflect`).
    private var mirrors: [(picture: SKUniform, place: SKUniform)] = []
    private var trafficStrip: SKMutableTexture?, trafficShown: [Int] = []
    private var skyline: [Building] = []
    private var parks: [(x: Int, width: Int)] = []
    private var stars: [(x: Int, y: Int, brightness: Float)] = []
    private var clouds: [Cloud] = []
    private var cars: [Car] = []
    private var carLooks: [(day: SKTexture, night: SKTexture, length: Int, height: Int)] = []
    private var carPictures: [(day: Pixels, night: Pixels)] = [] // the same, as pixels, for the water to mirror
    private var carPace: Float = 1, carGap: Float = 36 // far-off traffic crawls, and runs closer together
    private var plane = SKSpriteNode()
    private var planeLights = SKNode()
    private var beacon = SKNode()
    // Light on the waterfront's walls: what the sky gives every wall, and what the Sun or Moon adds to one facing it.
    private var ambient = RGB.one, keyFront = RGB.zero, keyLeft = RGB.zero, keyRight = RGB.zero, keyTop = RGB.zero
    private var behind = RGB.zero // the horizon's colour at our backs, which glass fronts mirror
    private let span = 260.0 // degrees of compass across the screen: wide, so sunrise and sunset stay in view all year
    private var facing = 180.0 // the compass bearing we look along
    private var sunAt = (elevation: 0.0, azimuth: 0.0)
    private var moonKey = (right: RGB.zero, left: RGB.zero, front: RGB.zero, top: RGB.zero)

    private var night: Float = 0 // 0 in daylight … 1 at full dark
    private var hour = 12.0      // local clock, 0–24
    private var clock: TimeInterval = 0
    private var lastUpdate: TimeInterval?
    private var nextCar: [TimeInterval] = [0, 0]
    private var nextPlane = TimeInterval.random(in: 3...25)
    private var planeX: Float = 0, planeDirection: Float = 0
    private var ship = SKSpriteNode(), shipX: Float = 0, shipDirection: Float = 0, nextShip = TimeInterval.random(in: 20...90)

    override init(size: CGSize) {
        let pixel = max(2, (size.height / 240).rounded()) // points per art pixel
        w = Int((size.width / pixel).rounded(.up))
        h = Int((size.height / pixel).rounded(.up))
        super.init(size: size)
        canvas.setScale(pixel)
        addChild(canvas)
        moveIfDue() // it may have been away, or the app closed, for longer than the wait
        settings = Self.knobs.map(\.value)
        layOut()
        redraw()
        run(.repeatForever(.sequence([.wait(forDuration: 30), .run { [weak self] in self?.redraw() }])))
        run(.repeatForever(.sequence([.wait(forDuration: 5), .run { [weak self] in self?.moveIfDue() }])))
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged),
                                               name: UserDefaults.didChangeNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func didMove(to view: SKView) {
        Location.shared.start()
        run(.repeatForever(.sequence([.run { [weak self] in self?.askTheWind() }, .wait(forDuration: 900)])))
    }

    /// Fetches the weather, for the wind, while the Airport is showing and Settings has it follow the real wind.
    /// It's the one request every weather wallpaper shares, and no other city makes it.
    private func askTheWind() {
        if city == .airport, Self.knob(.wind) > 0.5 { LiveWeather.shared.poll() }
    }

    /// Repaints when one of its own settings changes (the notification comes for every wallpaper's).
    @objc private func settingsChanged() {
        let picked = Self.knobs.map(\.value)
        guard picked != settings, !retired else { return }
        let moved = picked[K.view.rawValue] != settings[K.view.rawValue]
        // Picking a city by hand, or changing whether and how often it moves, starts the wait over.
        let restart = [K.view, .shuffle, .shuffleMinutes].contains { picked[$0.rawValue] != settings[$0.rawValue] }
        settings = picked
        if restart, !Self.easing { UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.movedKey) }
        if moved, let view { // another city: dissolve into a new scene of it with both still running, never a cut
            let fade = SKTransition.crossFade(withDuration: Self.easing ? 4 : 0.8)
            fade.pausesIncomingScene = false
            fade.pausesOutgoingScene = false
            let next = PixelCity(size: size)
            next.scaleMode = scaleMode
            retired = true
            return view.presentScene(next, transition: fade)
        }
        if moved { layOut() } // no view to fade in: the render tests
        if view != nil { askTheWind() } // in case that has just been switched on
        redraw()
    }

    /// Moves to another city if Settings has that on and the wait is up. Checked every few seconds, and when the
    /// scene is built: if Pixel City has been off the desktop for longer than the wait, it comes back as a new city.
    private func moveIfDue() {
        guard Self.knob(.shuffle) > 0.5, !retired else { return }
        let now = Date().timeIntervalSince1970
        guard let moved = UserDefaults.standard.object(forKey: Self.movedKey) as? Double else {
            return UserDefaults.standard.set(now, forKey: Self.movedKey) // just switched on: the wait starts here
        }
        if now - moved >= Self.knob(.shuffleMinutes).rounded() * 60 { moveOn() }
    }

    /// Moves to another city, picked at random. It saves the pick as Settings would, so every display's copy of the
    /// scene follows it and the City menu shows where we are.
    func moveOn() {
        guard !retired else { return }
        Self.easing = true
        defer { Self.easing = false }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.movedKey)
        let others = City.allCases.filter { $0.rawValue != Int(Self.knob(.view)) } // any but the one saved, which a new scene hasn't laid out yet
        UserDefaults.standard.set(Double(others.randomElement()!.rawValue), forKey: Self.knobs[K.view.rawValue].key)
    }

    /// The compass bearing we look along: toward the equator, where the Sun and Moon cross the sky, unless Settings
    /// picks one. Looking the other way puts the Sun at our backs, so it lights the fronts of the buildings.
    private func heading(_ latitude: Double) -> Double {
        let pick = Int(Self.knob(.looking))
        return pick == 0 ? (latitude >= 0 ? 180 : 0) : Double(pick - 1) * 45
    }

    /// Now, or today at the preview hour while previewing.
    private var now: Date {
        guard Self.knob(.previewTime) > 0.5 else { return Date() }
        return Calendar.current.startOfDay(for: Date()).addingTimeInterval(Self.knob(.previewHour) * 3600)
    }

    // MARK: - Layout (once)

    /// Generates everything that never changes: skyline, stars, cloud shapes, the car pool, antenna and plane.
    /// Run again when Settings picks another city.
    private func layOut() {
        canvas.removeAllChildren()
        (skyline, parks, stars, clouds, cars) = ([], [], [], [], [])
        (plane, planeLights, beacon, mirrored, waterTints, mirrors) = (SKSpriteNode(), SKNode(), SKNode(), [], [], [])
        (trafficStrip, trafficShown, launchTexture, plume, boosters) = (nil, [], nil, [], [])
        (nextCar, planeDirection, shipDirection, ship) = ([clock, clock], 0, 0, SKSpriteNode())
        city = City(rawValue: Int(Self.knob(.view))) ?? .waterfront
        waterRows = city == .waterfront ? Int(Float(h) * 0.21) : 0
        switch city {
        case .waterfront: ground = waterRows + quay + 26
        case .foothills: ground = Int(Float(h) * 0.27)
        case .bridge:
            ground = Int(Float(h) * 0.32) // the far shore: the bay fills everything below it
            waterRows = ground
        case .hillside:
            ground = Int(Float(h) * 0.26) // the sea's horizon, out past the harbour
            waterRows = ground
        case .overlook: ground = Int(Float(h) * 0.54) // the far skyline's feet: rooftops fill everything below
        case .airport:
            waterRows = Int(Float(h) * 0.215) // a bay, with the airfield along its far shore
            ground = waterRows + 25           // the far skyline's feet, behind the terminal
        case .spaceport:
            waterRows = Int(Float(h) * 0.235) // a lagoon between us and the pads, deep enough to mirror a lift-off
            ground = waterRows + 3            // a low shore of scrub
        }
        crest = Array(repeating: ground, count: w)
        (ridges, downtown, farHaze, slope, boats, steam, flock, towerLights, flights) = ([], 0.5, 1, [], [], [], [], [], [])
        for (node, z) in [(sky, 0.0), (backdrop, 2)] {
            node.anchorPoint = .zero
            node.size = CGSize(width: w, height: h)
            node.zPosition = z
            canvas.addChild(node)
        }
        var rng = SeededRandom(state: 2026)
        let tower: (x: Int, y: Int)
        switch city {
        case .waterfront: tower = layOutWaterfront(&rng)
        case .foothills: tower = layOutFoothills(&rng)
        case .bridge: tower = layOutBridge(&rng)
        case .hillside: tower = layOutHillside(&rng)
        case .overlook: tower = layOutOverlook(&rng)
        case .airport: tower = layOutAirport(&rng)
        case .spaceport: tower = layOutSpaceport(&rng)
        }
        skyBase = crest.min() ?? ground
        beacon.position = CGPoint(x: tower.x, y: tower.y)
        // A red aircraft light on a mast; on Hillside Town's lighthouse a white flash; on the Airport's tower the
        // beacon of a civil airfield, white and green by turns, 27 flashes a minute.
        let white = NSColor(red: 1, green: 0.96, blue: 0.8, alpha: 1), red = NSColor(red: 1, green: 0.25, blue: 0.2, alpha: 1)
        let flashes = city == .airport ? [white, NSColor(red: 0.3, green: 1, blue: 0.5, alpha: 1)] : [city == .hillside ? white : red]
        let (halo, lamp) = (SKSpriteNode(color: .clear, size: CGSize(width: 3, height: 3)), SKSpriteNode(color: .clear, size: CGSize(width: 1, height: 1)))
        beacon.addChild(halo)
        beacon.addChild(lamp)
        beacon.zPosition = 5
        beacon.run(.repeatForever(.sequence(flashes.flatMap { flash in
            [.run { (halo.color, lamp.color) = (flash.withAlphaComponent(0.3), flash) }, .fadeAlpha(to: 1, duration: 0), .wait(forDuration: 0.25),
             .fadeAlpha(to: 0.15, duration: 0), .wait(forDuration: flashes.count > 1 ? 1.95 : 1.25)]
        })))
        canvas.addChild(beacon)

        stars = (0..<170).map { _ in
            (Int.random(in: 0..<w, using: &rng), Int.random(in: skyBase + 30..<h, using: &rng), Float.random(in: 0.35...1, using: &rng))
        }

        for _ in 0..<3 {
            let cloud = Cloud(mask: cloudMask(&rng), x: Float.random(in: 0...Float(w), using: &rng),
                              speed: Float.random(in: 0.5...1.2, using: &rng))
            cloud.node.anchorPoint = CGPoint(x: 0.5, y: 0)
            cloud.node.size = CGSize(width: cloud.mask[0].count, height: cloud.mask.count)
            cloud.node.position.y = CGFloat(Int(Float(h) * Float.random(in: 0.68...0.88, using: &rng)))
            cloud.node.zPosition = 1
            canvas.addChild(cloud.node)
            clouds.append(cloud)
        }

        let paints = [rgb(196, 58, 52), rgb(58, 98, 186), rgb(222, 222, 216), rgb(236, 188, 48),
                      rgb(66, 138, 88), rgb(40, 40, 48), rgb(160, 166, 172)]
        let far = city != .waterfront && city != .hillside // traffic seen from miles off: a dash of paint, and at night just its lights
        carPictures = far ? paints.map { speck(2, body: $0) } + [speck(4, body: rgb(226, 226, 218))]
                          : paints.map { vehicle(sedan, body: $0) } + [vehicle(bus, body: rgb(228, 150, 40))]
        carLooks = carPictures.map { ($0.day.texture(), $0.night.texture(), $0.day.w, $0.day.h) }
        (carPace, carGap) = far ? (0.35, 7) : (1, 36)
        let lanes = city == .bridge ? [deck + 1, deck + 2] : city == .overlook ? [ground + 6, ground + 7]
            : city == .airport ? [apron + 2, apron + 3] // the service road along the terminal, behind the stands
            : far ? [ground - 16, ground - 14] : [streetBase + 5, streetBase + 13]
        for lane in 0...1 {
            // The town's lanes are too steep for traffic, and an apron has a few vans and tugs, not a road's worth.
            for _ in 0..<(city == .hillside || city == .spaceport ? 0 : city == .airport ? 3 : far ? 14 : 6) {
                let node = SKSpriteNode()
                node.anchorPoint = CGPoint(x: 0.5, y: 0)
                node.position.y = CGFloat(lanes[lane])
                node.zPosition = lane == 0 ? 4 : 3
                node.xScale = lane == 0 ? 1 : -1
                node.isHidden = true
                let beam = SKSpriteNode(texture: headlightBeam)
                beam.anchorPoint = CGPoint(x: 0, y: 0)
                beam.size = CGSize(width: 14, height: 4)
                beam.blendMode = .add // light on the road, not a grey shape in the air
                beam.zPosition = -0.5 // under the car ahead
                beam.isHidden = far
                node.addChild(beam)
                canvas.addChild(node)
                cars.append(Car(node: node, beam: beam, lane: lane))
            }
            // Start with a little traffic already on the road.
            for x in [Float(w) * 0.2, Float(w) * 0.65] where !cars.isEmpty { spawnCar(lane: lane, at: x + Float.random(in: -20...20)) }
        }

        plane.texture = art(["#...........",
                             "##..........",
                             "############",
                             "....###....."], ["#": rgb(222, 224, 230)])
        plane.size = CGSize(width: 12, height: 4)
        plane.anchorPoint = CGPoint(x: 0.5, y: 0)
        plane.zPosition = 1.5
        plane.isHidden = true
        for (x, y, colour, delay) in [(1, 0, NSColor.red, 0.0), (-6, 3, NSColor.white, 0.5)] {
            let light = SKSpriteNode(color: colour, size: CGSize(width: 1, height: 1))
            light.position = CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)
            light.run(.sequence([.wait(forDuration: delay), .repeatForever(.sequence([
                .fadeAlpha(to: 1, duration: 0), .wait(forDuration: 0.12), .fadeAlpha(to: 0, duration: 0), .wait(forDuration: 1.1),
            ]))]))
            planeLights.addChild(light)
        }
        plane.addChild(planeLights)
        canvas.addChild(plane)
        if waterRows > 0 { addWater() }
        if city == .airport { for flight in flights { canvas.addChild(flight.node) } } // in front of the water
        if city == .spaceport { for node in [launchLayer, countdown] { canvas.addChild(node) } }
        if city == .bridge { // a freighter that crosses the bay in front of the bridge now and then
            ship.anchorPoint = CGPoint(x: 0.5, y: 0)
            ship.size = CGSize(width: freighter[0].count, height: freighter.count)
            ship.position.y = CGFloat(ground - 36)
            ship.zPosition = 3
            ship.isHidden = true
            canvas.addChild(ship)
        }
    }

    /// The Waterfront city: a downtown that peaks in the middle and low flanks with gaps in them, where the Sun and
    /// Moon rise and set in view. Three rows deep: windowless towers in the haze, a far row, and a near row of four
    /// kinds of building, with a park here and there. Returns the top of the landmark's spire, for the beacon.
    private func layOutWaterfront(_ rng: inout SeededRandom) -> (x: Int, y: Int) {
        rng = SeededRandom(state: 2030) // picked from a handful for its skyline, and for parks where the Sun sets
        let room = Float(h - ground) // the sky above the street: heights are shares of it
        func downtown(_ x: Int) -> Float { 1 - smoothstep(0.12, 0.3, abs(Float(x) / Float(w) - 0.5)) }
        let colours: [Kind: [RGB]] = [
            .deco: [rgb(184, 170, 148), rgb(160, 152, 144), rgb(196, 178, 146), rgb(146, 148, 158)],
            .glass: [rgb(96, 150, 176), rgb(92, 128, 184), rgb(118, 160, 156)],
            .brick: [rgb(156, 88, 70), rgb(130, 94, 80), rgb(176, 126, 90), rgb(116, 82, 86), rgb(164, 144, 114)],
            .slab: [rgb(184, 180, 170), rgb(164, 168, 176), rgb(196, 184, 162)],
        ]

        var x = 0
        while x < w { // towers too far off to show windows, behind downtown only
            let d = downtown(x)
            if d > 0.15 {
                skyline.append(Building(x: x, width: Int.random(in: 8...14, using: &rng),
                                        height: Int(room * (0.2 + 0.42 * d * Float.random(in: 0.6...1, using: &rng))),
                                        colour: rgb(150, 156, 170), far: true, floor: 3, pitch: 2,
                                        roof: [Roof.plain, .plain, .setback, .antenna].randomElement(using: &rng)!,
                                        seed: rng.next(), kind: .haze))
            }
            x += Int.random(in: 9...16, using: &rng)
        }

        x = -5
        while x < w {
            let width = Int.random(in: 12...24, using: &rng), d = downtown(x + width / 2)
            if d < 0.3, Float.random(in: 0..<1, using: &rng) < 0.5 { // open sky on the flanks
                x += Int.random(in: 10...22, using: &rng)
                continue
            }
            let kind = [Kind.deco, .glass, .slab, .slab].randomElement(using: &rng)!
            let height = room * (mix(0.14, 0.34, d) + Float.random(in: 0..<1, using: &rng) * mix(0.12, 0.24, d))
            skyline.append(Building(x: x, width: width, height: Int(height), colour: colours[kind]!.randomElement(using: &rng)!,
                                    far: true, floor: 3, pitch: 2, roof: Roof.allCases.dropLast().randomElement(using: &rng)!,
                                    seed: rng.next(), kind: kind))
            x += width + [0, 0, 3, 4].randomElement(using: &rng)! // touching or a real gap: a 1-pixel one reads as a glitch
        }

        x = -3
        while x < w {
            let d = downtown(x + 12)
            if d < 0.3, Float.random(in: 0..<1, using: &rng) < 0.4 {
                let width = Int.random(in: 11...18, using: &rng)
                parks.append((x, width))
                x += width
                continue
            }
            let kind = (d > 0.6 ? [Kind.deco, .glass, .glass, .slab] : d > 0.2 ? [.slab, .brick, .deco, .glass]
                        : [.brick, .brick, .brick, .slab]).randomElement(using: &rng)!
            let width = kind == .brick ? Int.random(in: 16...24, using: &rng) : Int.random(in: 20...30, using: &rng)
            var height = room * (mix(0.12, 0.26, d) + Float.random(in: 0..<1, using: &rng) * mix(0.07, 0.28, d))
            if kind == .brick { height = min(height, room * 0.2) } // walk-ups stay low
            skyline.append(Building(x: x, width: width, height: max(Int(height), 16), colour: colours[kind]!.randomElement(using: &rng)!,
                                    far: false, floor: kind == .brick ? 6 : kind == .slab ? 5 : 4, pitch: kind == .brick ? 5 : 3,
                                    roof: Roof.allCases.dropLast().randomElement(using: &rng)!, seed: rng.next(), kind: kind))
            x += width + [0, 0, 0, 3].randomElement(using: &rng)!
        }

        // The landmark: a stone tower right of centre, well above the rest, with the beacon on its spire.
        let middle = skyline.indices.filter { !skyline[$0].far && abs(skyline[$0].x - w * 11 / 20) < 36 }
        let landmark = middle.max { skyline[$0].width < skyline[$1].width } ?? skyline.count - 1
        skyline[landmark].kind = .deco
        skyline[landmark].colour = colours[.deco]![0]
        (skyline[landmark].floor, skyline[landmark].pitch) = (4, 3)
        skyline[landmark].height = Int(room * 0.66)
        skyline[landmark].roof = .antenna
        let tower = skyline[landmark]
        return (tower.x + tower.width / 2, ground + tower.height + 18)
    }

    /// The Foothills city: three mountain ridges, and under them a far-off band of buildings with a small downtown
    /// left of centre. Returns the top of the landmark's mast, for the beacon.
    private func layOutFoothills(_ rng: inout SeededRandom) -> (x: Int, y: Int) {
        rng = SeededRandom(state: 2041)
        let room = Float(h - ground)
        (downtown, farHaze) = (0.36, 0.45)

        /// A jagged line `relief` tall standing on `base` (shares of the sky above the ground): octaves of noise, the
        /// first two folded so the peaks come to points.
        func ridge(base: Float, relief: Float, period: Int) -> [Float] {
            var line = [Float](repeating: base * room, count: w)
            var (span, gain) = (period, relief * room)
            for octave in 0..<5 {
                let knots = (0...w / span + 1).map { _ in Float.random(in: 0...1, using: &rng) }
                for x in 0..<w {
                    let v = knots[x / span] + (knots[x / span + 1] - knots[x / span]) * Float(x % span) / Float(span)
                    line[x] += gain * (octave < 2 ? 1 - abs(2 * v - 1) : v - 0.5)
                }
                (span, gain) = (max(2, span / 2), gain * 0.5)
            }
            return line
        }
        ridges = [ridge(base: 0.36, relief: 0.22, period: 110), ridge(base: 0.22, relief: 0.17, period: 80),
                  ridge(base: 0.07, relief: 0.12, period: 64)]
        for x in 0..<w { crest[x] = ground + Int(ridges.map { $0[x] }.max()!) }

        return layOutBand(&rng, spread: 0.2, tallest: 0.3, suburbs: true)
    }

    /// A far-off band of the Waterfront's far-row buildings, with windowless towers behind: a downtown `spread` either
    /// side of `downtown`, its landmark `tallest` of the sky above the ground, and low buildings with open ground
    /// across the rest if there are `suburbs`. Returns the top of the landmark's mast.
    private func layOutBand(_ rng: inout SeededRandom, spread: Float, tallest: Float, suburbs: Bool) -> (x: Int, y: Int) {
        let room = Float(h - ground)
        func centre(_ x: Int) -> Float { 1 - smoothstep(0.03, spread, abs(Float(x) / Float(w) - downtown)) }
        var x = 0
        while x < w { // windowless towers behind downtown
            let d = centre(x)
            if d > 0.2 {
                skyline.append(Building(x: x, width: Int.random(in: 6...10, using: &rng),
                                        height: Int(room * 0.27 * d * Float.random(in: 0.5...1, using: &rng)),
                                        colour: rgb(150, 156, 170), far: true, floor: 3, pitch: 2,
                                        roof: [Roof.plain, .plain, .antenna].randomElement(using: &rng)!, seed: rng.next(), kind: .haze))
            }
            x += Int.random(in: 7...12, using: &rng)
        }
        let colours: [Kind: [RGB]] = [
            .deco: [rgb(190, 176, 152), rgb(168, 160, 150)], .glass: [rgb(96, 150, 176), rgb(92, 128, 184), rgb(118, 160, 156)],
            .slab: [rgb(188, 184, 172), rgb(170, 172, 178), rgb(198, 184, 160), rgb(170, 132, 112)],
        ]
        x = -3
        while x < w {
            let width = Int.random(in: 8...16, using: &rng), d = centre(x + width / 2)
            if !suburbs, d <= 0 { // nothing but hills beyond the town
                x += width
                continue
            }
            if d < 0.15, Float.random(in: 0..<1, using: &rng) < 0.45 { // open ground between the suburbs
                x += Int.random(in: 6...16, using: &rng)
                continue
            }
            let kind = (d > 0.5 ? [Kind.deco, .glass, .glass, .slab] : [.slab, .slab, .glass]).randomElement(using: &rng)!
            let height = room * (mix(0.03, 0.1, d) + Float.random(in: 0..<1, using: &rng) * mix(0.03, 0.17, d))
            skyline.append(Building(x: x, width: width, height: max(Int(height), 5), colour: colours[kind]!.randomElement(using: &rng)!,
                                    far: true, floor: 3, pitch: 2, roof: Roof.allCases.dropLast().randomElement(using: &rng)!,
                                    seed: rng.next(), kind: kind))
            x += width + [0, 0, 3].randomElement(using: &rng)!
        }
        let landmark = skyline.indices.filter { skyline[$0].kind != .haze }.max { skyline[$0].height < skyline[$1].height }!
        skyline[landmark].kind = .deco
        skyline[landmark].colour = colours[.deco]![0]
        skyline[landmark].height = Int(room * tallest)
        skyline[landmark].roof = .antenna
        let tower = skyline[landmark]
        return (tower.x + tower.width / 2, ground + tower.height + 18)
    }

    /// The Long Bridge: a bay with a suspension bridge across it, hills on the far shore rising to a headland on
    /// the right, and a small city at their left end. Returns the top of the left tower, for the beacon.
    private func layOutBridge(_ rng: inout SeededRandom) -> (x: Int, y: Int) {
        rng = SeededRandom(state: 2052)
        (downtown, farHaze) = (0.13, 0.7)
        for x in 0..<w { crest[x] = ground + hill(x) }
        _ = layOutBand(&rng, spread: 0.16, tallest: 0.26, suburbs: false)
        return (towers[0], towerTop + 4)
    }

    /// Hillside Town: houses terraced up a hill that rises to the left from a harbour, a church at the top, and the
    /// open sea to the right beyond a breakwater. Returns the lighthouse's lantern, for the beacon.
    private func layOutHillside(_ rng: inout SeededRandom) -> (x: Int, y: Int) {
        rng = SeededRandom(state: 2063)
        downtown = 0.25
        let quayTop = harbour + 4
        slope = (0..<w).map { x in
            let rise = 1 - smoothstep(0.06, 0.66, Float(x) / Float(w))
            return Float(h) * 0.5 * pow(rise, 0.85) + (4 * sin(Float(x) * 0.09) + 2.5 * sin(Float(x) * 0.23 + 1)) * rise
        }
        for x in 0..<w { crest[x] = max(ground, quayTop + Int(slope[x]) + 8) }
        let walls = [rgb(238, 224, 194), rgb(242, 238, 228), rgb(230, 190, 124), rgb(230, 172, 150), rgb(196, 210, 220),
                     rgb(218, 156, 112), rgb(236, 208, 160)]
        for level in stride(from: 12, through: 0, by: -1) { // the highest terrace first, so nearer houses overlap those behind
            let lift = 1 + level * 10
            var x = Int.random(in: -6...0, using: &rng)
            while x < w, slope[max(x, 0)] > max(Float(lift) - 2, 0.5) { // while the hill stands this high here
                let width = Int.random(in: 9...15, using: &rng), base = quayTop + lift + Int.random(in: -1...1, using: &rng)
                guard slope[min(x + width, w - 1)] > max(Float(lift) - 7, 0.5) else { break }
                if Float.random(in: 0..<1, using: &rng) < 0.2 { // a gap in the row, with a cypress in it
                    skyline.append(Building(x: x + 1, width: 3, height: Int.random(in: 9...14, using: &rng), colour: rgb(38, 72, 54), far: false,
                                            floor: 0, pitch: 0, roof: .plain, seed: rng.next(), kind: .cypress, base: base))
                    x += Int.random(in: 4...7, using: &rng)
                    continue
                }
                skyline.append(Building(x: x, width: width, height: Int.random(in: level < 3 ? 11...15 : 8...12, using: &rng),
                                        colour: walls.randomElement(using: &rng)!, far: false, floor: 4, pitch: 4,
                                        roof: [Roof.plain, .plain, .ledge, .setback].randomElement(using: &rng)!, seed: rng.next(),
                                        kind: .house, base: base))
                x += width
            }
        }
        // Fishing boats and a sailing boat or two at their moorings off the quay, each bobbing in its own time.
        let end = slope.firstIndex { $0 <= 0.5 } ?? w
        for i in 0..<6 {
            let node = SKSpriteNode(), rows = i % 3 == 1 ? sailboat : fishingBoat
            node.anchorPoint = CGPoint(x: 0.5, y: 0)
            node.size = CGSize(width: rows[0].count, height: rows.count)
            node.position = CGPoint(x: end * (22 + i * 12) / 100 + Int.random(in: -5...5, using: &rng), y: harbour - 6 - (i % 3) * 3)
            node.xScale = i % 2 == 0 ? 1 : -1
            node.zPosition = 3 + CGFloat(2 - i % 3) * 0.1 // nearer boats in front
            let pause = { SKAction.wait(forDuration: 1.6, withRange: 1.2) }
            node.run(.repeatForever(.sequence([pause(), .moveBy(x: 0, y: 1, duration: 0), pause(), .moveBy(x: 0, y: -1, duration: 0)])))
            canvas.addChild(node)
            boats.append((node, rows, [rgb(232, 232, 224), rgb(60, 110, 150), rgb(170, 60, 52), rgb(50, 120, 100)][i % 4]))
        }
        return (w * 84 / 100 + 2, quayTop + 28)
    }

    /// The Overlook: a far skyline on the horizon, and below it five bands of buildings seen from above, each a front
    /// wall with its flat roof behind, smaller and closer together the farther off. Returns the top of the far
    /// landmark's mast, for the beacon.
    private func layOutOverlook(_ rng: inout SeededRandom) -> (x: Int, y: Int) {
        rng = SeededRandom(state: 2074)
        downtown = 0.42
        let tower = layOutBand(&rng, spread: 0.3, tallest: 0.44, suburbs: true)
        let walls = [rgb(150, 92, 76), rgb(176, 150, 118), rgb(138, 134, 132), rgb(196, 182, 158), rgb(120, 96, 90), rgb(160, 120, 96)]
        // Each band, far to near: the row it stands on, and the least and greatest width and wall height.
        for (row, widths, heights) in [(0.5, 5...9, 3...8), (0.44, 8...14, 6...14), (0.34, 14...24, 10...24), (0.2, 22...36, 16...34),
                                       (0.055, 34...56, 24...48)] as [(Float, ClosedRange<Int>, ClosedRange<Int>)] {
            var x = -Int.random(in: 0...widths.lowerBound, using: &rng)
            while x < w {
                let width = Int.random(in: widths, using: &rng)
                skyline.append(Building(x: x, width: width, height: Int.random(in: heights, using: &rng), colour: walls.randomElement(using: &rng)!,
                                        far: widths.upperBound < 30, floor: widths.upperBound < 12 ? 2 : widths.upperBound < 30 ? 3 : 4,
                                        pitch: max(2, width * 2 / 5), roof: .plain, seed: rng.next(), kind: .block,
                                        base: Int(Float(h) * row) + Int.random(in: -2...2, using: &rng)))
                x += width + (Float.random(in: 0..<1, using: &rng) < 0.3 ? max(2, widths.lowerBound / 5) : 0) // a street, now and then
            }
        }
        // Steam: wisps from the two stacks on our own roof and from one on each of three roofs nearby.
        let blocks = skyline.indices.filter { skyline[$0].kind == .block && skyline[$0].pitch >= 9 }
        var stacks = [(w * 31 / 100 + 1, 27), (w * 58 / 100 + 1, 27)]
        for share in [0.18, 0.74, 0.93] as [Float] {
            guard let i = blocks.min(by: { abs(Float(skyline[$0].x) - share * Float(w)) < abs(Float(skyline[$1].x) - share * Float(w)) }) else { continue }
            skyline[i].roof = .antenna // marks a roof with a steaming stack, which `drawBlock` draws
            stacks.append((stack(on: skyline[i]).x, stack(on: skyline[i]).y + 5))
        }
        for (x, y) in stacks {
            // Each puff swells, thins and leans downwind as it climbs, a whole pixel at a time, then starts again.
            for puff in 0..<3 {
                let node = SKSpriteNode()
                node.anchorPoint = CGPoint(x: 0.5, y: 0)
                node.zPosition = 3
                node.isHidden = true
                node.colorBlendFactor = 1
                let frames = puffs.enumerated().flatMap { i, frame in
                    [SKAction.run {
                        node.texture = frame
                        node.size = frame.size()
                        node.position = CGPoint(x: x + i, y: y + [0, 1, 4, 8, 13][i])
                        node.alpha = [0.55, 0.4, 0.28, 0.17, 0.08][i]
                        node.isHidden = false
                    }, .wait(forDuration: 0.9)]
                }
                node.run(.sequence([.wait(forDuration: Double(puff) * 1.6 + Double(x % 7) * 0.3),
                                    .repeatForever(.sequence(frames + [.run { node.isHidden = true }, .wait(forDuration: 0.3)]))]))
                canvas.addChild(node)
                steam.append(node)
            }
        }
        // Pigeons: a flock that wheels over the middle roofs by day, each bird beating its wings in its own time.
        let wings = [art(["#.#", ".#."], ["#": .one]), art([".#.", "#.#"], ["#": .one])]
        for _ in 0..<9 {
            let node = SKSpriteNode(texture: wings[0])
            node.size = CGSize(width: 3, height: 2)
            node.zPosition = 3.5
            node.colorBlendFactor = 1
            node.run(.repeatForever(.animate(with: wings, timePerFrame: .random(in: 0.2...0.32))))
            canvas.addChild(node)
            flock.append((node, Float.random(in: 0...0.9, using: &rng),
                          SIMD2(Float.random(in: -9...9, using: &rng), Float.random(in: -4...4, using: &rng))))
        }
        // Red lights on three of the far skyline's taller buildings, each blinking in its own slow time.
        let tall = skyline.indices.filter { skyline[$0].kind != .block && skyline[$0].kind != .haze && skyline[$0].roof != .antenna }
            .sorted { skyline[$0].height > skyline[$1].height }.prefix(3)
        for (n, i) in tall.enumerated() {
            let node = SKSpriteNode(color: NSColor(red: 1, green: 0.25, blue: 0.2, alpha: 1), size: CGSize(width: 1, height: 1))
            node.anchorPoint = .zero
            node.position = CGPoint(x: skyline[i].x + skyline[i].width / 2, y: ground + skyline[i].height)
            node.zPosition = 5
            node.run(.repeatForever(.sequence([.fadeAlpha(to: 1, duration: 0), .wait(forDuration: 1.1),
                                               .fadeAlpha(to: 0, duration: 0), .wait(forDuration: 1.3 + Double(n) * 0.45)])))
            canvas.addChild(node)
            towerLights.append(node)
        }
        return tower
    }

    /// The Airport: an airfield along the far shore of a bay. Nearest the water is the runway, then a taxiway, then
    /// the apron and its stands in front of a low terminal, with the control tower and hangars to its left; the
    /// city it serves is far off on the horizon. Returns the top of the tower, for the beacon.
    private func layOutAirport(_ rng: inout SeededRandom) -> (x: Int, y: Int) {
        rng = SeededRandom(state: 2085)
        (downtown, farHaze) = (0.12, 0.8)
        (runway, taxiway, apron) = (waterRows + 6, waterRows + 14, waterRows + 18)
        stands = [36, 52, 68].map { w * $0 / 100 }
        for x in 0..<w { crest[x] = ground + hill(x) }
        for x in terminal { crest[x] = max(crest[x], apron + 17) } // the Sun sets behind the terminal's roof
        _ = layOutBand(&rng, spread: 0.14, tallest: 0.2, suburbs: true)

        (facing, runwayWay) = (heading(Location.shared.coordinate.latitude), 1)
        runwayWay = windWay
        for i in 0..<4 { // two on their stands, one a few seconds out on the approach, one away
            var f = Flight()
            change(&f)
            (f.way, f.stand, f.berth) = (runwayWay, min(i * 2, 2), i < 2 ? 1 : 0)
            (f.phase, f.x) = i < 2 ? (.parked, Float(stands[i * 2])) : (.away, 0)
            f.until = clock + [.random(in: 25...50), .random(in: 150...260), 4, .random(in: 70...120)][i]
            (f.lamp.texture, f.lamp.size) = (art([".#.", "###", ".#."], ["#": .one]), CGSize(width: 3, height: 3))
            (f.lamp.alpha, f.lamp.blendMode) = (0.4, .add)
            for light in [f.wingtip, f.beacon, f.strobe, f.lamp] { f.node.addChild(light) }
            let flash = { (on: Double, off: Double) in
                SKAction.repeatForever(.sequence([.fadeAlpha(to: 1, duration: 0), .wait(forDuration: on), .fadeAlpha(to: 0, duration: 0), .wait(forDuration: off)]))
            }
            f.beacon.run(.sequence([.wait(forDuration: Double(i) * 0.3), flash(0.12, 1)]))
            f.strobe.run(.sequence([.wait(forDuration: Double(i) * 0.3 + 0.5), flash(0.07, 1.3)]))
            f.node.isHidden = true
            flights.append(f)
        }
        return (controlTower, apron + 4 + 61)
    }

    // The Airport's buildings: the columns the terminal runs between, and the column the control tower stands at.
    private var terminal: Range<Int> { w * 31 / 100..<w * 75 / 100 }
    private var controlTower: Int { w * 26 / 100 }

    /// The live wind's speed along the runway in km/h, from the right when positive, or nil if Settings has the
    /// Airport ignore it or no report has come in. We look along `facing`, so the right is 90° on from that.
    private var windAlong: Float? {
        guard Self.knob(.wind) > 0.5, let report = LiveWeather.shared.latest else { return nil }
        return Float(report.wind * cos((report.windFrom - facing - 90) * .pi / 180))
    }

    /// The way the runway should be in use, 1 for to the right: aircraft land and take off into the wind. It stays
    /// as it is until the wind along the runway reaches 9 km/h, the 5 knots at which a real airport goes by the wind
    /// (FAA AIM 4-3-6), and is to the right when there's no wind to go by.
    private var windWay: Float {
        guard let along = windAlong else { return 1 }
        return abs(along) < 9 ? runwayWay : along > 0 ? 1 : -1
    }

    /// How busy the Airport is: Settings' figure for the day or for the night, easing from one to the other between
    /// 5 and 7 in the morning and from 8 in the evening to midnight. Waits on a stand and away run down at this pace.
    private var flying: Double {
        let day = smoothstep(5, 7, Float(hour)) * (1 - smoothstep(20, 24, Float(hour)))
        return Double(mix(Float(Self.knob(.flightsNight)), Float(Self.knob(.flightsDay)), day))
    }

    /// For the tests: how many aircraft have the runway at this moment.
    var runwayCount: Int { flights.filter(\.onRunway).count }

    /// Where the steaming stack stands on one of the Overlook's roofs.
    private func stack(on b: Building) -> (x: Int, y: Int) {
        (b.x + b.width * 2 / 3, (b.base ?? ground) + b.height + b.pitch / 2)
    }

    /// A puff of steam at five ages: a dab at the vent, then a round cloud that swells as it thins. Round and whole:
    /// at this size a square reads as a stray block, and a puff with holes in it as a symbol.
    private lazy var puffs: [SKTexture] = [
        ["##"],
        [".##.", "####", ".##."],
        [".###.", "#####", "#####", ".###."],
        [".####.", "######", "######", "######", ".####."],
        ["..###..", ".#####.", "#######", "#######", ".#####.", "..###.."],
    ].map { art($0, ["#": .one]) }

    // The Long Bridge's shape: the columns its two towers stand at, the row of its roadway, and the row their tops reach.
    private var towers: [Int] { [w * 22 / 100, w * 78 / 100] }
    private var deck: Int { ground + 14 }
    private var harbour: Int { Int(Float(h) * 0.14) } // the waterline along Hillside Town's quay
    private var towerTop: Int { deck + (h - ground) * 36 / 100 }

    /// The row the bridge's main cable hangs at over this column: a parabola between the towers, and from each a
    /// nearly straight run down to an anchorage beyond the edge of the screen.
    private func cable(_ x: Int) -> Float {
        let (left, right) = (Float(towers[0]), Float(towers[1])), f = Float(x), high = Float(towerTop)
        if f < left { return mix(Float(deck + 1), high, pow(max(0, f + 30) / (left + 30), 1.25)) }
        if f > right { return mix(Float(deck + 1), high, pow(max(0, Float(w) + 30 - f) / (Float(w) + 30 - right), 1.25)) }
        let u = (f - (left + right) / 2) / ((right - left) / 2)
        return Float(deck + 4) + (high - Float(deck + 4)) * u * u
    }

    // Where the water mirrors about: the row things nearest us stand in it at (the bridge's towers, the town's quay,
    // short of the far shore), and the rows of quay or sea wall mirrored first, below that.
    private var mirrorLine: Int { city == .bridge ? ground - 12 : city == .hillside ? harbour : waterRows }
    private var wall: Int { city == .waterfront ? quay : city == .airport ? 4 : 0 }

    /// The water along the bottom: a shader that mirrors whatever stands above it (on the Waterfront, the quay and then
    /// the city), row by rippling row, and the things that move in front of that.
    private func addWater() {
        let node = SKSpriteNode(color: .black, size: CGSize(width: w, height: waterRows))
        node.anchorPoint = .zero
        node.zPosition = 2.5
        mirrored = [SKUniform(name: "u_sky", texture: nil), SKUniform(name: "u_city", texture: nil)]
        waterTints = [SKUniform(name: "u_deep", vectorFloat3: .zero), SKUniform(name: "u_glint", vectorFloat3: .zero)]
        // Aircraft or boats first, each at its own place in the list; then the freighter, or the layer everything
        // at the Spaceport moves in; last the traffic's strip.
        let things = flights.count + boats.count + (city == .bridge || city == .spaceport ? 1 : 0) + (cars.isEmpty ? 0 : 1)
        mirrors = (0..<things).map { (SKUniform(name: "u_thing\($0)", texture: nil), SKUniform(name: "u_place\($0)", vectorFloat4: [-999, 0, 1, 1])) }
        if let layer = launchTexture { // it stands on the shore, so it mirrors about the waterline
            mirrors[0].picture.textureValue = layer
            reflect(0, from: 0, foot: Float(mirrorLine), size: layer.size())
        }
        if !cars.isEmpty {
            // The strip is as tall as a bus on the Waterfront's street, where both lanes stand on the ground; one row
            // for the apron's vans; and on the Long Bridge the two rows of its deck, mirrored where the deck is.
            let rows = city == .waterfront ? bus.count : city == .bridge ? 2 : 1, strip = SKMutableTexture(size: CGSize(width: w, height: rows))
            trafficStrip = strip
            mirrors[things - 1].picture.textureValue = strip
            let foot = city == .bridge ? Float(mirrorLine) - Float(deck + 1 - mirrorLine) / 1.8 : Float(mirrorLine - wall)
            reflect(things - 1, from: 0, foot: foot, size: strip.size())
        }
        node.shader = SKShader(source: Self.waterShader(things: things), uniforms: mirrored + waterTints + mirrors.flatMap { [$0.picture, $0.place] } + [
            SKUniform(name: "u_canvas", vectorFloat2: [Float(w), Float(h)]),
            // The water's size; the line it mirrors about; and the rows of wall and then of street, which lies flat and
            // out of sight, above that.
            SKUniform(name: "u_water", vectorFloat4: [Float(w), Float(waterRows), Float(mirrorLine), Float(wall)]),
            SKUniform(name: "u_street", float: city == .waterfront ? 26 : city == .airport ? 18 : 0), // the airfield lies flat too
            WallpaperTime.now,
        ])
        canvas.addChild(node)
    }

    /// Tells the water's shader where one of the things it mirrors is: the column its picture starts from (its left
    /// edge, or its right when it's `turned` to face left), the water row its foot is mirrored at, and its size.
    /// Something floating is mirrored from its own waterline. Something on land is mirrored from the foot of the
    /// wall's image, as the buildings are, and lower by its height over the water's squash of 1.8 as it rises.
    private func reflect(_ i: Int, from x: Float, foot: Float, size: CGSize, turned: Bool = false, hidden: Bool = false) {
        guard mirrors.indices.contains(i) else { return }
        let place: SIMD4<Float> = hidden ? [-999, 0, 1, 1] : [x, foot, (turned ? -1 : 1) * Float(size.width), Float(size.height)]
        if mirrors[i].place.vectorFloat4Value != place { mirrors[i].place.vectorFloat4Value = place }
    }

    /// Paints the traffic into the strip the water mirrors, when any of it has moved: the far lane, then the near.
    private func mirrorTraffic() {
        guard let strip = trafficStrip else { return }
        let dark = night > 0.5, shown = cars.filter { !$0.node.isHidden }
        let now = shown.flatMap { [Int($0.x.rounded(.down)), $0.look, $0.lane] }
        guard now != trafficShown else { return }
        trafficShown = now
        var px = Pixels(Int(strip.size().width), Int(strip.size().height))
        for lane in [1, 0] {
            for car in shown where car.lane == lane {
                let look = dark ? carPictures[car.look].night : carPictures[car.look].day
                px.draw(look, x: Int(car.x.rounded(.down)) - look.w / 2, y: city == .bridge ? lane : 0, flipped: lane == 1)
            }
        }
        let bytes = px.bytes(topDown: false)
        strip.modifyPixelData { data, length in
            bytes.withUnsafeBytes { data?.copyMemory(from: $0.baseAddress!, byteCount: min(length, bytes.count)) }
        }
    }

    // ponytail: clouds and the high plane aren't mirrored: their images would fall off the bottom of the water, or
    // under the Dock. Mirror them like the rest if a city ever has deeper water.
    /// The water's shader, which mirrors the sky and the city and this many moving things. Those aren't in the
    /// city's painting, so each is mirrored from its own picture (`u_thing`), placed by `u_place`: the column it
    /// starts from, the water row its foot is mirrored at, and its size, the width negative when it faces left.
    private static func waterShader(things: Int) -> String {
        let things = (0..<things).reversed().map { i in // the traffic's strip first, so what stands in front of it covers it
            "vec2 q\(i) = vec2((p.x + shift + 0.5 - u_place\(i).x) / u_place\(i).z, (floor((u_place\(i).y - 1.0 - p.y) * squash) + 0.5) / u_place\(i).w);"
                + " vec4 t\(i) = texture2D(u_thing\(i), q\(i)) * step(0.0, q\(i).x) * step(q\(i).x, 1.0) * step(0.0, q\(i).y) * step(q\(i).y, 1.0);"
                + " c = c * (1.0 - t\(i).a) + t\(i).rgb;"
        }.joined(separator: "\n")
        return """
        void main() {
            vec2 p = floor(v_tex_coord * u_water.xy);   // this art pixel, counted from the water's bottom left
            float line = p.y < u_water.z ? u_water.z : u_water.y; // the waterline this row mirrors
            float d = line - 1.0 - p.y;                 // rows below it
            float near = 1.0 - p.y / u_water.y;         // 0 at the far edge of the water, 1 nearest us
            // Ripples slide each row sideways by whole pixels, wider toward us.
            float wave = sin(d * 1.1 + u_now * 1.1) + sin(d * 0.43 - u_now * 0.6);
            float shift = floor(wave * (0.3 + near * 1.3) + 0.5);
            // The mirror image: the quay wall if there is one, then what stands beyond it, squashed. Water beyond the
            // nearest things mirrors only the foot of the far shore, not those things over again.
            float squash = p.y < u_water.z ? 1.8 : 0.7;
            float row = line + (d < u_water.w ? d : u_water.w + u_street + (d - u_water.w) * squash);
            // Sampled at the centre of a whole pixel: a shader's texture is smoothed between pixels, nearest filter or not.
            vec2 uv = (vec2(p.x + shift, floor(min(row, u_canvas.y - 1.0))) + 0.5) / u_canvas;
            vec4 city = texture2D(u_city, uv);
            // Land across the water is painted a shade short of solid. It mirrors about the horizon, so the water this
            // side of the nearest shore doesn't mirror it a second time.
            city *= 1.0 - step(0.9, city.a) * step(city.a, 0.995) * step(p.y, u_water.z - 0.5);
            vec3 c = texture2D(u_sky, uv).rgb * (1.0 - city.a) + city.rgb;
            \(things)
            float bright = smoothstep(0.75, 1.0, max(c.r, max(c.g, c.b))); // the Sun, the Moon and lamps keep their shine
            c = mix(c, u_deep, (0.3 + 0.4 * near) * (1.0 - 0.7 * bright)) * (0.94 - 0.2 * near * (1.0 - bright));
            // Glints: short dashes of sky on every other row, drifting.
            float cell = floor((p.x + floor(u_now * (0.6 + near))) / 5.0);
            float chance = fract(sin(cell * 12.9898 + d * 78.233) * 43758.5453);
            c += u_glint * step(0.93, chance) * mod(d, 2.0) * 0.12;
            // Whatever the city's painting has standing in the water (a bridge's towers) shows over it.
            vec4 here = texture2D(u_city, (p + 0.5) / u_canvas);
            gl_FragColor = vec4(c * (1.0 - here.a) + here.rgb, 1.0);
        }
        """
    }

    // MARK: - Time of day (every 30 s)

    /// Repaints everything that follows the clock: sky, sun, moon, stars, buildings, windows and street lights,
    /// then recolours the clouds, cars and plane to match.
    private func redraw() {
        let now = now
        let spot = Location.shared.coordinate
        let sun = skyPosition(now, latitude: spot.latitude, longitude: spot.longitude)
        let moonAge = ((now.timeIntervalSince1970 - 947_182_440) / 86_400).truncatingRemainder(dividingBy: 29.530588853)
        let moonPhase = moonAge / 29.530588853 // 0 new, 0.5 full
        let moon = skyPosition(now, latitude: spot.latitude, longitude: spot.longitude, eclipticOffset: moonPhase * 360)
        let parts = Calendar.current.dateComponents([.hour, .minute], from: now)
        hour = Double(parts.hour ?? 12) + Double(parts.minute ?? 0) / 60
        let el = Float(sun.elevation)
        night = smoothstep(4, -8, el)
        let (top, sunward) = skyColours(el, morning: hour < 12)
        // Around a low Sun the horizon changes with the compass: orange under the Sun, and opposite it the pink band
        // over the Earth's shadow.
        let facing = heading(spot.latitude), low = smoothstep(-10, -2, el) * smoothstep(12, 3, el)
        let lilac = mix(top, rgb(226, 156, 176), 0.5)
        func horizonToward(_ azimuth: Double) -> RGB {
            mix(sunward, lilac, Float(1 - cos((azimuth - sun.azimuth) * .pi / 180)) / 2 * low * 0.85)
        }
        let horizons = (0..<w).map { horizonToward(facing + (Double($0) / Double(w) - 0.5) * span) }
        let horizon = horizons[w / 2]
        behind = horizonToward(facing + 180)
        var px = Pixels(w, h)

        // Sky: banded and dithered like old pixel art, glowing around a low sun.
        let band: Float = 0.4 // how much of each band is dithered into the next
        let sunSpot = place(sun, latitude: spot.latitude)
        let glow = smoothstep(-10, 0, el) * (1 - smoothstep(6, 20, el)) * 0.7 + 0.15 * smoothstep(0, 10, el)
        let glowColour = mix(rgb(255, 128, 64), rgb(255, 214, 150), smoothstep(-2, 10, el))
        let reach = mix(1, 0.35, smoothstep(4, 20, el)) // a low sun lights a wide band of sky, a high one a small halo
        for y in 0..<h {
            let t = max(0, Float(y - skyBase) / Float(h - skyBase))
            for x in 0..<w {
                let d = bayer(x, y)
                var c = mix(horizons[x], top, pow(min(1, (t * 14 + (1 - band) / 2 + d * band).rounded(.down) / 14), 0.6))
                if night > 0 { // the city's own glow in the night sky, strongest over downtown
                    let u = Float(x) / Float(w) - downtown
                    let lift = night * exp(-t * 3) * (0.5 + 0.5 * exp(-u * u / 0.08))
                    c = mix(c, rgb(104, 76, 112), (lift * 4.4 + 0.42 + d * 0.16).rounded(.down) / 8)
                }
                if glow > 0 {
                    let gx = Float(x - sunSpot.x) / (90 * reach), gy = Float(y - sunSpot.y) / (40 * reach)
                    // Flat rings, dithered only where two meet: dithering all the way across left a halo of loose dots.
                    c = mix(c, glowColour, (glow * exp(-(gx * gx + gy * gy)) * 5 + 0.3 + d * 0.4).rounded(.down) / 5)
                }
                px.plot(x, y, pointwiseMin(c, .one))
            }
        }

        let starlight = smoothstep(-5, -12, el)
        for star in stars where starlight > 0 {
            // The city's glow drowns the stars near the horizon.
            let clear = smoothstep(0.1, 0.6, Float(star.y - skyBase) / Float(h - skyBase)) * 0.8
            let a = starlight * star.brightness * clear
            px.plot(star.x, star.y, rgb(255, 248, 232), a)
            if star.brightness > 0.93 {
                for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] { px.plot(star.x + dx, star.y + dy, rgb(200, 210, 255), a * 0.35) }
            }
        }

        if moon.elevation > -3 {
            drawMoon(into: &px, at: place(moon, latitude: spot.latitude), phase: moonPhase, alpha: mix(0.5, 1, night))
        }
        if sun.elevation > -4 {
            let colour = mix(rgb(255, 150, 80), rgb(255, 246, 214), smoothstep(0, 12, el))
            for dy in -6...6 { for dx in -6...6 where dx * dx + dy * dy <= 38 { px.plot(sunSpot.x + dx, sunSpot.y + dy, colour) } }
        }

        sky.texture = px.texture()

        px = Pixels(w, h) // the city, clear wherever the sky shows through
        // The sky lights every wall evenly; the Sun, or the Moon after dark, lights the walls that face it.
        ambient = mix(mix(RGB(0.84, 0.86, 0.92), RGB(0.52, 0.48, 0.62), smoothstep(16, 0, el)), RGB(0.19, 0.2, 0.31), night)
        (self.facing, sunAt) = (facing, sun)
        moonKey = key(moon, rgb(120, 140, 200) * Float(1 - cos(2 * .pi * moonPhase)) * smoothstep(0, 10, Float(moon.elevation)) * night * 0.15)
        let sunKey = key(sun, sunColour(el))
        (keyRight, keyLeft) = (sunKey.right + moonKey.right, sunKey.left + moonKey.left)
        (keyFront, keyTop) = (sunKey.front + moonKey.front, sunKey.top + moonKey.top)
        switch city {
        case .waterfront, .bridge, .airport: drawHorizon(into: &px, zenith: top, horizon: horizon)
        case .foothills: drawMountains(into: &px, horizons: horizons)
        case .hillside:
            drawHorizon(into: &px, zenith: top, horizon: horizon)
            drawHill(into: &px)
        case .spaceport: break
        case .overlook:
            drawHorizon(into: &px, zenith: top, horizon: horizon)
            // The streets between the rooftops: tarmac by day, paler with distance; by night a dim warm glow, with
            // street lamps wherever a building doesn't hide them.
            var lamps = SeededRandom(state: 5)
            for y in 0..<ground {
                let far = Float(y) / Float(ground)
                px.fill(0, y, w, 1, mix(mix(lit(rgb(84, 86, 94), .zero), rgb(112, 78, 52), night * 0.4), horizon, far * 0.4))
            }
            for _ in 0..<420 where night > 0.15 {
                px.plot(Int.random(in: 0..<w, using: &lamps), Int.random(in: 14..<ground, using: &lamps), rgb(255, 214, 150), min(1, night * 1.6) * 0.85)
            }
        }
        for building in skyline {
            let haze = horizons[min(max(building.x + building.width / 2, 0), w - 1)] // the horizon behind it
            switch building.kind {
            case .house, .cypress: drawHouse(building, into: &px)
            case .block: drawBlock(building, into: &px, zenith: top, horizon: haze)
            default: drawTower(building, into: &px, zenith: top, horizon: haze)
            }
        }
        drawParks(into: &px)
        switch city {
        case .waterfront:
            drawStreet(into: &px)
            drawQuay(into: &px)
        case .foothills: drawPlain(into: &px, horizons: horizons)
        case .bridge:
            drawBridge(into: &px)
            ship.texture = afloat(freighter, hull: rgb(44, 56, 76), dark: night > 0.5)
            mirrors.first?.picture.textureValue = ship.texture
        case .hillside:
            drawHarbour(into: &px)
            for (i, boat) in boats.enumerated() {
                boat.node.texture = afloat(boat.rows, hull: boat.hull, dark: night > 0.5)
                mirrors[i].picture.textureValue = boat.node.texture
            }
        case .overlook:
            drawRooftop(into: &px)
            // Steam takes the light it rises through: white by day, warm at dusk, a grey shadow by night.
            let vapour = pointwiseMin(RGB(0.93, 0.94, 0.96) * (ambient + keyTop * 0.35), .one)
            for node in steam { node.color = NSColor(red: CGFloat(vapour.x), green: CGFloat(vapour.y), blue: CGFloat(vapour.z), alpha: 1) }
            for light in towerLights { light.isHidden = night < 0.4 }
            for bird in flock { bird.node.isHidden = night > 0.35 } // they roost at dusk
        case .airport:
            drawAirfield(into: &px, zenith: top, horizon: horizon)
            for i in flights.indices { dress(i) }
        case .spaceport:
            drawSpaceport(into: &px, zenith: top, horizon: horizon)
            (hazeColour, launchShown) = (horizon, []) // its moving things are painted again in this light
            paintSmoke()
        }
        backdrop.texture = px.texture()
        mirrored.first?.textureValue = sky.texture
        mirrored.last?.textureValue = backdrop.texture
        waterTints.first?.vectorFloat3Value = mix(top * 0.6, rgb(8, 22, 36), 0.35)
        waterTints.last?.vectorFloat3Value = horizon

        // Sprites that change colour with the light.
        let dusk = smoothstep(14, 2, el) * (1 - night)
        let light = mix(mix(rgb(250, 250, 252), horizon, dusk * 0.6), rgb(47, 50, 78), night)
        let shade = mix(mix(rgb(196, 206, 226), top, dusk * 0.5), rgb(29, 31, 54), night)
        for cloud in clouds { cloud.node.texture = cloud.texture(light: light, shade: shade) } // solid, so they hide the stars
        for car in cars { car.node.texture = night > 0.5 ? carLooks[car.look].night : carLooks[car.look].day }
        trafficShown = [] // so the strip the water mirrors is painted again in this light
        for car in cars { car.beam.alpha = CGFloat(smoothstep(0.3, 0.8, night)) }
        plane.color = NSColor(red: 0.05, green: 0.06, blue: 0.1, alpha: 1) // a dark silhouette after sunset
        plane.colorBlendFactor = CGFloat(night * 0.85)
        planeLights.alpha = CGFloat(mix(0.4, 1, night))
    }

    /// The Sun's light on a wall at this elevation in degrees: orange and strong when low, paler when high, gone below the horizon.
    private func sunColour(_ el: Float) -> RGB {
        mix(rgb(255, 126, 54), rgb(255, 240, 214), smoothstep(0, 20, el)) * smoothstep(-1.5, 5, el) * mix(0.95, 0.62, smoothstep(0, 20, el))
    }

    /// What a light of this colour in the sky adds to walls that face right, left and toward us, and to roof edges:
    /// each by the cosine of the angle between the light and that wall.
    private func key(_ body: (elevation: Double, azimuth: Double), _ colour: RGB) -> (right: RGB, left: RGB, front: RGB, top: RGB) {
        let bearing = Float(body.azimuth - facing) * .pi / 180 // 0 straight ahead, positive to the right
        let height = Float(max(body.elevation, 0)) * .pi / 180
        return (colour * max(0, sin(bearing)) * cos(height), colour * max(0, -sin(bearing)) * cos(height),
                colour * max(0, -cos(bearing)) * cos(height), colour * (0.3 + 0.7 * sin(height)))
    }

    /// Sky colours (zenith, horizon) for a sun elevation in degrees, from deep night through twilight to day.
    private func skyColours(_ el: Float, morning: Bool) -> (RGB, RGB) {
        let stops: [(Float, RGB, RGB)] = [
            (-18, rgb(6, 8, 22), rgb(28, 24, 50)),
            (-10, rgb(12, 14, 40), rgb(48, 36, 84)),
            (-4, rgb(34, 40, 98), rgb(172, 92, 112)),
            (0, rgb(58, 78, 148), rgb(250, 142, 82)),
            (6, rgb(78, 128, 198), rgb(250, 198, 140)),
            (15, rgb(66, 136, 226), rgb(166, 210, 244)),
        ]
        guard let upper = stops.firstIndex(where: { $0.0 > el }) else { return (stops[5].1, stops[5].2) }
        guard upper > 0 else { return (stops[0].1, stops[0].2) }
        let (a, b) = (stops[upper - 1], stops[upper])
        let t = (el - a.0) / (b.0 - a.0)
        var horizon = mix(a.2, b.2, t)
        if morning { horizon = mix(horizon, rgb(250, 176, 190), 0.35 * smoothstep(-12, -2, el) * smoothstep(12, 2, el)) } // dawn runs pinker than dusk
        return (mix(a.1, b.1, t), horizon)
    }

    /// Where a sky position lands on the canvas, looking along `heading` (toward the equator, east is on the left up north).
    private func place(_ p: (elevation: Double, azimuth: Double), latitude: Double) -> (x: Int, y: Int) {
        let dx = (p.azimuth - heading(latitude) + 540).truncatingRemainder(dividingBy: 360) - 180
        let x = Int(Double(w) * (0.5 + dx / span))
        // A low Sun or Moon gets more room than a high one, and they drop out of sight as soon as they set: behind the
        // skyline at that spot (`crest`), which they clear by the time they are 15 degrees up.
        let horizon = mix(Float(crest[min(max(x, 0), w - 1)]), Float(crest.max() ?? ground), smoothstep(0, 15, Float(p.elevation)))
        let rise = p.elevation < 0 ? p.elevation * 12 : pow(p.elevation / 70, 0.75) * Double(Float(h - 14) - horizon)
        return (x, Int(Double(horizon) + rise))
    }

    /// The moon's disc with its current phase lit on the right while waxing, the left while waning.
    private func drawMoon(into px: inout Pixels, at spot: (x: Int, y: Int), phase: Double, alpha: Float) {
        // ponytail: a thin crescent is drawn at least 1.6 pixels wide, or it breaks into specks at this size
        let r = 8, k = min(Float(cos(2 * .pi * phase)), 1 - 1.6 / 8)
        for dy in -r...r {
            for dx in -r...r {
                let nx = Float(dx) / Float(r), ny = Float(dy) / Float(r)
                guard nx * nx + ny * ny <= 1.05 else { continue }
                let edge = k * (max(0, 1 - ny * ny)).squareRoot()
                let lit = phase < 0.5 ? nx > edge : nx < -edge
                let crater = [(-4, 2), (-3, 2), (-4, 3), (-3, 3), (1, 4), (2, 4), (-1, -4), (0, -4), (-1, -3),
                              (4, -2), (4, -1), (-6, -1), (1, 0)].contains { $0 == (dx, dy) } // the maria, roughly
                if lit {
                    px.plot(spot.x + dx, spot.y + dy, crater ? rgb(200, 200, 186) : rgb(242, 240, 222), alpha)
                } else {
                    px.plot(spot.x + dx, spot.y + dy, rgb(40, 46, 72), alpha * 0.5 * night) // earthshine
                }
            }
        }
    }

    /// A wooden water tank on its legs, standing on a roof at `y`.
    private func drawTank(into px: inout Pixels, x: Int, y: Int, legs: RGB) {
        let wood = mix(rgb(120, 84, 60), rgb(24, 20, 24), night)
        px.fill(x, y, 1, 2, legs)
        px.fill(x + 3, y, 1, 2, legs)
        px.fill(x, y + 2, 4, 4, wood)
        px.fill(x + 1, y + 6, 2, 1, wood)
    }

    /// A wall of this colour in the waterfront's light: the sky's share, dimmed by `shade`, plus what the Sun or
    /// Moon adds to a wall facing them (`keyFront`, `keyLeft`, `keyRight` or `keyTop`).
    private func lit(_ colour: RGB, _ key: RGB, shade: Float = 1) -> RGB { pointwiseMin(colour * (ambient * shade + key), .one) }

    /// One waterfront building: its front, the sliver of side wall that perspective shows (wider toward the
    /// screen's edges, and sunlit or in shadow by where the Sun is), then the windows and roof of its kind.
    /// Lights come on a few neighbouring rooms at a time, so they fall in dashes rather than a scatter of squares.
    private func drawTower(_ b: Building, into px: inout Pixels, zenith: RGB, horizon: RGB) {
        var rng = SeededRandom(state: b.seed)
        let off = Float(b.x + b.width / 2) / Float(w) - 0.5
        let side = b.far ? min(1 + Int(abs(off) * 4), 2) : min(1 + Int(abs(off) * 9), 5)
        let onRight = off < 0 // left of centre, a building shows its right-hand wall
        let haze: Float = (b.kind == .haze ? 0.8 : b.far ? mix(0.42, 0.3, night) : 0) * farHaze, distance = mix(horizon, zenith, 0.3)
        func tone(_ c: RGB) -> RGB { mix(c, distance, haze) }
        let front = tone(lit(b.colour, keyFront)), flank = tone(lit(b.colour, onRight ? keyRight : keyLeft, shade: 0.72))
        let edge = tone(lit(b.colour, keyTop, shade: 1.1)), metal = tone(mix(rgb(70, 70, 80), rgb(14, 14, 22), night))
        let glass = tone(lit(b.colour * 0.45, .zero) + zenith * 0.2 + rgb(10, 14, 26) * night) // unlit windows mirror a little sky
        let base = ground, top = base + b.height, dark = night > 0.15, glow = min(1, night * 1.6)
        // Homes keep the evening's hours in warm light; offices empty out floor by floor, mostly in cool white.
        let homes = b.kind == .brick || (b.kind == .slab && rng.next() % 2 == 0)
        let warm = homes || b.kind == .deco || rng.next() % 3 == 0
        let share = officeShare

        /// A box: front wall, side wall and lit roof edge. Returns where its front wall starts and how wide that is.
        func block(_ x: Int, _ y: Int, _ width: Int, _ height: Int) -> (x: Int, width: Int) {
            let s = min(side, width / 3), fx = onRight ? x : x + s
            px.fill(fx, y, width - s, height, front)
            px.fill(onRight ? x + width - s : x, y, s, height, flank)
            px.fill(x, y + height - 1, width, 1, edge)
            return (fx, width - s)
        }
        /// One floor's windows from `x`: `count` of them `pitch` apart, each `width` by `rows`, lit in runs.
        /// With no `unlit` colour, dark windows are left as the wall behind them.
        func storey(_ x: Int, _ y: Int, count: Int, pitch: Int, width: Int, rows: Int, runs: ClosedRange<Int>, unlit: RGB?) {
            var i = 0
            while i < count {
                let run = Int.random(in: runs, using: &rng)
                let (r1, r2, r3) = (Float.random(in: 0..<1, using: &rng), Float.random(in: 0..<1, using: &rng), Float.random(in: 0..<1, using: &rng))
                let on = dark && (homes ? isLit(r1, r2, r3, home: 0.45) : r3 < share)
                let lamp = (warm ? mix(rgb(255, 190, 100), rgb(255, 226, 150), r1) : mix(rgb(176, 200, 232), rgb(226, 234, 240), r1)) * (0.6 + 0.4 * r2)
                if let colour = on ? mix(glass, tone(lamp), glow) : unlit {
                    for j in i..<min(i + run, count) { px.fill(x + j * pitch, y, width, rows, colour) }
                }
                i += run
            }
        }

        switch b.kind {
        case .house, .cypress, .block: break // drawn elsewhere
        case .haze:
            _ = block(b.x, base, b.width, b.height)
            if b.roof == .setback, b.width >= 10 { _ = block(b.x + 2, top, b.width - 4, 6) }
            if b.roof == .antenna { px.fill(b.x + b.width / 2, top, 1, 9, front) }
            for _ in 0..<b.height / 5 { // a few lights, too far off to tell the windows apart
                let x = Int.random(in: 1..<b.width - 1, using: &rng), y = Int.random(in: 3..<max(4, b.height - 2), using: &rng)
                let r = Float.random(in: 0..<1, using: &rng)
                if dark, r < share { px.plot(b.x + x, base + y, rgb(255, 214, 150), glow * 0.6) }
            }

        case .deco:
            // Stone tiers stepping in to a crown, the windows in tall strips between piers.
            let step = b.far ? 2 : 3, strip = b.far ? 1 : 2
            let tiers: [Float] = b.width >= 7 * step ? [0.58, 0.26, 0.16] : b.width >= 5 * step ? [0.68, 0.32] : [1]
            var (x, y, width) = (b.x, base, b.width)
            for (i, part) in tiers.enumerated() {
                let height = i == tiers.count - 1 ? top - y : Int(Float(b.height) * part)
                let f = block(x, y, width, height)
                for cy in stride(from: y + (y == base && !b.far ? 9 : 2), through: y + height - 1 - b.floor, by: b.floor) {
                    storey(f.x + 1, cy, count: (f.width - 1) / (strip + 1), pitch: strip + 1, width: strip, rows: b.floor - 1, runs: 1...4, unlit: glass)
                }
                (x, y, width) = (x + step, y + height, width - 2 * step)
            }
            if !b.far { // a tall lit doorway under a band of pale stone
                px.fill(b.x, base + 7, b.width, 1, edge)
                px.fill(b.x + b.width / 2 - 2, base, 4, 6, dark ? mix(glass, rgb(255, 214, 150), glow * 0.8) : glass)
            }
            if b.roof == .antenna || b.roof == .setback { // the crown
                for _ in 0..<2 where width >= 3 {
                    _ = block(x, y, width, 2)
                    (x, y, width) = (x + step - 1, y + 2, width - 2 * (step - 1))
                }
            }
            if b.roof == .antenna { px.fill(b.x + b.width / 2, y, 1, top + 18 - y, metal) }

        case .glass:
            // A curtain wall mirroring the sky behind us, zenith at its top and horizon at its foot, a dark line at every floor.
            let f = block(b.x, base, b.width, b.height)
            let bay = b.far ? 3 : 5, tint = lit(b.colour, keyFront)
            for row in 0..<b.height - 1 {
                let pane = tone(mix(mix(behind, zenith, 0.25 + 0.75 * Float(row) / Float(b.height)) * 0.82, tint, 0.38))
                px.fill(f.x, base + row, f.width, 1, row % b.floor == b.floor - 1 ? pane * 0.74 : pane)
            }
            for cy in stride(from: base + (b.far ? 0 : 8), through: top - 1 - b.floor, by: b.floor) {
                storey(f.x + 1, cy, count: (f.width - 1) / bay, pitch: bay, width: bay - 1, rows: b.floor - 1, runs: 2...6, unlit: nil)
            }
            for mx in stride(from: f.x + bay, to: f.x + f.width - 1, by: bay) { px.fill(mx, base, 1, b.height - 1, .zero, 0.14) } // mullions
            if !b.far { px.fill(f.x + 1, base, f.width - 2, 6, dark ? mix(glass, rgb(255, 214, 160), glow * 0.45) : glass * 0.8) } // the lobby
            let crown = tone(mix(zenith * 0.82, tint, 0.38))
            switch b.roof {
            case .setback: _ = block(b.x + 3, top, b.width - 6, 4) // plant room
            case .tank: // a slanted top
                for i in 0..<f.width / 3 { px.fill(onRight ? f.x : f.x + (i + 1) * 2, top + i, f.width - (i + 1) * 2, 1, crown) }
            case .ledge: px.fill(b.x + b.width / 3, top, 1, 8, metal)
            default: break
            }

        case .slab:
            // Concrete with ribbon windows, standing on columns over an open ground floor.
            let f = block(b.x, base, b.width, b.height)
            let rows = b.far ? 1 : 2
            for cy in stride(from: base + (b.far ? 3 : 9), through: top - 2 - rows, by: b.floor) {
                storey(f.x + 1, cy, count: (f.width - 2) / 3, pitch: 3, width: 3, rows: rows, runs: 1...4, unlit: glass)
            }
            if !b.far {
                px.fill(f.x, base, f.width, 6, front * 0.5)
                for cx in stride(from: f.x, to: f.x + f.width, by: 6) { px.fill(cx, base, 1, 6, front) }
            }
            switch b.roof {
            case .setback: _ = block(b.x + b.width / 2, top, 8, 4) // lift room
            case .tank where !b.far: drawTank(into: &px, x: b.x + b.width / 3, y: top, legs: metal)
            default: break
            }

        case .brick:
            // A walk-up: sash windows with sills under a cornice, and a shop below a striped awning.
            let f = block(b.x, base, b.width, b.height)
            px.fill(b.x - 1, top - 1, b.width + 2, 1, edge)
            px.fill(b.x, top - 2, b.width, 1, front * 0.76)
            let count = (f.width - 4) / b.pitch + 1, escape = Int.random(in: 0..<max(1, count - 1) * 2, using: &rng) // a fire escape on half of them
            for cy in stride(from: base + 11, through: top - 6, by: b.floor) {
                for j in 0..<count { px.fill(f.x + 2 + j * b.pitch, cy - 1, 2, 1, edge) } // sills
                storey(f.x + 2, cy, count: count, pitch: b.pitch, width: 2, rows: 3, runs: 1...2, unlit: glass)
                if escape < count - 1 { // a landing under two windows, and the ladder between them
                    px.fill(f.x + 1 + escape * b.pitch, cy - 1, b.pitch + 4, 1, metal)
                    px.fill(f.x + 5 + escape * b.pitch, cy, 1, b.floor - 1, metal)
                }
            }
            let closes = 20 + Float.random(in: 0..<3, using: &rng) // open from 7 until some time after 8 in the evening
            let awning = [rgb(176, 58, 52), rgb(52, 112, 84), rgb(58, 92, 150), rgb(206, 160, 60)].randomElement(using: &rng)!
            let shop = dark && Float(hour) >= 7 && Float(hour) < closes ? mix(glass, rgb(255, 214, 150), glow * 0.8) : glass
            px.fill(f.x + 1, base, f.width - 2, 6, shop)
            px.fill(f.x + 1, base + 5, f.width - 2, 1, shop * 0.7)
            px.fill(f.x + f.width / 2 - 1, base, 3, 5, front * 0.55) // the door
            for cx in f.x..<f.x + f.width { px.fill(cx, base + 6, 1, 2, lit((cx - f.x) / 2 % 2 == 0 ? awning : rgb(232, 226, 210), keyFront)) }
            switch b.roof {
            case .tank: drawTank(into: &px, x: b.x + b.width / 3, y: top, legs: metal)
            case .setback: _ = block(b.x + 3, top, 6, 4) // the stair head
            default: px.fill(b.x + b.width - 6, top, 2, 3, flank) // a chimney
            }
        }

        // Red lights on the corners of the taller roofs.
        if !b.far, b.kind != .deco, b.height > (h - ground) * 2 / 5 {
            for x in [b.x, b.x + b.width - 1] { px.plot(x, top, rgb(255, 60, 50), night) }
        }
    }

    /// The share of office floors lit at this hour: half of them at dusk, a few all night.
    private var officeShare: Float {
        let evening = Float(hour < 12 ? hour + 24 : hour) // runs the evening on past midnight
        if hour >= 5 && hour < 12 { return mix(0.08, 0.45, smoothstep(5.5, 8, Float(hour))) }
        return mix(0.5, 0.08, smoothstep(18, 24, evening))
    }

    /// How high the far shore's hills stand at this column: low behind the Waterfront, rising to a headland on the
    /// right behind the Long Bridge, and only on the right, across the water, from Hillside Town.
    private func hill(_ x: Int) -> Int {
        let f = Float(x), roll = 4.5 + 2.5 * sin(f * 0.023 + 1) + 1.6 * sin(f * 0.061 + 4) + 0.8 * sin(f * 0.13)
        switch city {
        case .bridge: return Int(roll * (1.7 + 3.2 * smoothstep(0.35, 0.95, f / Float(w))))
        case .hillside: return Int(roll * 1.6 * smoothstep(0.55, 0.8, f / Float(w))) // a headland across the water, right of the town
        default: return Int(roll)
        }
    }

    /// The far shore: hills in the haze, seen through the Waterfront's gaps and over its low roofs, and across the
    /// Long Bridge's bay.
    private func drawHorizon(into px: inout Pixels, zenith: RGB, horizon: RGB) {
        let land = mix(horizon * 0.82, zenith, 0.25)
        for x in 0..<w {
            px.fill(x, ground, 1, hill(x), land, city == .hillside ? 0.99 : 1) // see the water's shader for the 0.99
            if city == .bridge { px.fill(x, ground, 1, min(2, hill(x)), land * 0.8) } // the shore, darker at the water
        }
    }

    /// The Long Bridge: cables and their hangers, two towers standing in the bay, the roadway on its truss, and at
    /// night a string of lights along all of it.
    private func drawBridge(into px: inout Pixels) {
        let steel = rgb(100, 138, 134), base = ground - 12, lamp = rgb(255, 222, 160)
        let (front, shade, edge) = (lit(steel, keyFront), lit(steel * 0.6, .zero), lit(steel, keyTop, shade: 1.1))
        let dark = night > 0.15, glow = min(1, night * 1.6)
        var last = Int(cable(-1))
        for x in 0..<w {
            let y = Int(cable(x))
            px.fill(x, min(y, last), 1, abs(y - last) + 1, shade) // joined up where the cable runs steep
            if x % 6 == 0, y > deck + 2 {
                px.fill(x, deck + 1, 1, y - deck - 1, shade, 0.55) // a hanger…
                if dark { px.plot(x, y + 1, lamp, glow) }          // …and a light where it meets the cable
            }
            last = y
        }
        for tx in towers {
            let onRight = tx < w / 2 // as with the buildings, the side wall on show faces the middle of the screen
            let footing = lit(rgb(168, 162, 150), keyFront)
            px.fill(tx - 6, base - 2, 13, 5, footing)
            px.fill(tx - 6, base + 2, 13, 1, lit(rgb(190, 184, 170), keyTop))
            px.fill(tx - 6, base - 2, 13, 1, footing * 0.55)
            var (half, y) = (4, base + 3)
            for stage in 0..<3 { // the shaft narrows in three stages, with cross-braces as darker bands
                let height = stage == 2 ? towerTop + 2 - y : (towerTop - base) * 38 / 100
                px.fill(tx - half, y, half * 2 + 1, height, front)
                px.fill(onRight ? tx + half - 1 : tx - half, y, 2, height, lit(steel, onRight ? keyRight : keyLeft, shade: 0.72))
                px.fill(tx - half, y + height - 1, half * 2 + 1, 1, edge)
                for band in stride(from: y + 6, to: y + height - 3, by: 9) { px.fill(tx - half + 1, band, half * 2 - 1, 2, shade, 0.5) }
                (half, y) = (half - 1, y + height)
            }
            px.fill(tx - 1, y, 3, 2, edge)
            if dark { for i in 0..<30 { px.fill(tx - 3, deck + 2 + i, 7, 1, lamp, 0.32 * glow * (1 - Float(i) / 30)) } } // floodlit from the deck
            px.plot(tx, y + 2, rgb(255, 60, 50), night)
        }
        px.fill(0, deck - 5, w, 1, shade)
        for x in 0..<w { // the truss: verticals with a V between each pair
            let k = x % 6
            if k == 0 { px.fill(x, deck - 4, 1, 3, shade) }
            px.plot(x, deck - 1 - min(k, 6 - k), shade)
        }
        px.fill(0, deck - 1, w, 2, shade)
        px.fill(0, deck, w, 1, edge)
        for x in stride(from: 3, to: w, by: 8) where dark { px.plot(x, deck + 1, lamp, glow) }
    }

    /// A vessel from rows of characters, heading right. By night its hull is a shadow, and its windows and mast light
    /// show. The water mirrors it (see `reflect`).
    private func afloat(_ rows: [String], hull: RGB, dark: Bool) -> SKTexture {
        let dim = dark ? RGB(0.3, 0.32, 0.45) : .one
        return art(rows, [
            "H": hull * dim, "h": pointwiseMin(hull * 1.25 + 0.06, .one) * dim, "r": rgb(150, 52, 46) * dim,
            "W": rgb(226, 226, 218) * dim, "c": rgb(232, 230, 220) * dim, "s": rgb(240, 234, 214) * dim, "m": rgb(120, 124, 130) * dim,
            "a": rgb(172, 86, 62) * dim, "b": rgb(62, 130, 140) * dim, "d": rgb(196, 160, 72) * dim,
            "w": dark ? rgb(255, 220, 140) : rgb(70, 90, 110), "l": dark ? rgb(255, 250, 230) : rgb(120, 124, 130),
        ])
    }

    /// Hillside Town's hill, under the houses: scrub with a lit edge and outcrops of rock, and the church at its top.
    private func drawHill(into px: inout Pixels) {
        var rng = SeededRandom(state: 91)
        let quayTop = harbour + 4, scrub = rgb(124, 132, 88), sunlight = keyTop * 0.4
        for x in 0..<w where slope[x] > 0.5 {
            let top = quayTop + Int(slope[x])
            px.fill(x, quayTop, 1, top - quayTop, lit(scrub, sunlight))
            px.fill(x, top - 1, 1, 1, lit(scrub, keyTop, shade: 1.1))
            if rng.next() % 9 == 0 { px.fill(x, top - Int.random(in: 3...9, using: &rng), 3, 1, lit(rgb(170, 158, 134), sunlight)) }
        }
        // The church: a nave under a tiled roof, and a bell tower with a pointed cap and a cross.
        let cx = w * 15 / 100, base = quayTop + Int(slope[cx]) - 9
        let wall = rgb(240, 234, 220), tile = lit(rgb(190, 98, 68), keyTop * 0.6)
        px.fill(cx + 6, base, 17, 10, lit(wall, keyFront))
        for r in 0..<4 { px.fill(cx + 5 + r * 2, base + 10 + r, 19 - r * 4, 1, tile) }
        px.fill(cx + 13, base, 3, 5, lit(rgb(110, 76, 56), .zero)) // its door
        px.fill(cx, base, 7, 28, lit(wall, keyFront))
        px.fill(cx + 5, base, 2, 28, lit(wall, keyRight, shade: 0.72))
        let bells = night > 0.15 ? mix(rgb(40, 36, 40), rgb(255, 214, 150), min(1, night * 1.6) * 0.8) : lit(rgb(70, 62, 60), .zero)
        for x in [cx + 1, cx + 3] { px.fill(x, base + 20, 1, 4, bells) } // the belfry's openings
        for r in 0..<4 { px.fill(cx - 1 + r, base + 28 + r * 2, 9 - r * 2, 2, tile) }
        px.fill(cx + 3, base + 36, 1, 3, lit(rgb(70, 62, 60), .zero))
        px.fill(cx + 2, base + 37, 3, 1, lit(rgb(70, 62, 60), .zero))
    }

    /// One of Hillside Town's houses: pale walls that take the Sun's colour, shuttered windows, a door, and a tiled
    /// roof that is hipped, gabled or flat. Or the cypress standing in a gap between two.
    private func drawHouse(_ b: Building, into px: inout Pixels) {
        var rng = SeededRandom(state: b.seed)
        let base = b.base ?? ground, top = base + b.height, dark = night > 0.15, glow = min(1, night * 1.6)
        let onRight = b.x + b.width / 2 < w / 2, side = onRight ? keyRight : keyLeft
        guard b.kind == .house else { // a cypress: a dark spindle, lit down the Sun's side
            for row in 0..<b.height {
                let wide = row > 1 && row < b.height - 3
                px.fill(b.x + (wide ? 0 : 1), base + row, wide ? 3 : 1, 1, lit(b.colour, .zero))
                if wide { px.plot(onRight ? b.x + 2 : b.x, base + row, lit(b.colour, side * 0.5 + keyTop * 0.2)) }
            }
            return
        }
        let tile = [rgb(196, 100, 70), rgb(176, 88, 62), rgb(206, 122, 84)].randomElement(using: &rng)!
        let shutter = lit([rgb(60, 110, 96), rgb(70, 96, 140), rgb(120, 78, 60), rgb(150, 60, 56)].randomElement(using: &rng)!, keyFront)
        let front = lit(b.colour, keyFront), glass = lit(b.colour * 0.4, .zero) + rgb(10, 14, 26) * night
        px.fill(b.x, base, b.width, b.height, front)
        px.fill(onRight ? b.x + b.width - 2 : b.x, base, 2, b.height, lit(b.colour, side, shade: 0.72))
        px.fill(b.x, base, b.width, 1, front * 0.7) // its shadow on the terrace
        let columns = (b.width - 3) / 4, door = Int.random(in: 0..<max(1, columns), using: &rng), shuttered = rng.next() % 2 == 0
        for storey in 0..<(b.height - 2) / 4 {
            for i in 0..<columns {
                let x = b.x + 2 + i * 4, y = base + 2 + storey * 4
                let (r1, r2, r3) = (Float.random(in: 0..<1, using: &rng), Float.random(in: 0..<1, using: &rng), Float.random(in: 0..<1, using: &rng))
                if storey == 0, i == door {
                    px.fill(x, base + 1, 2, 3, shutter * 0.7)
                    continue
                }
                let on = dark && isLit(r1, r2, r3, home: 0.5)
                px.fill(x, y, 2, 2, on ? mix(glass, mix(rgb(255, 190, 100), rgb(255, 226, 150), r1) * (0.6 + 0.4 * r2), glow) : glass)
                if shuttered { px.fill(x - 1, y, 1, 2, shutter) }
            }
        }
        let roof = lit(tile, keyTop * 0.6), eaves = lit(tile * 0.74, .zero), ridge = lit(tile, keyTop, shade: 1.12)
        switch b.roof {
        case .setback: // flat, with a parapet
            px.fill(b.x, top, b.width, 1, lit(b.colour, keyTop, shade: 1.1))
        case .ledge: // a gable end toward us: wall up to the peak, under two slopes of tile
            for r in 0..<(b.width + 2) / 3 {
                let inset = r * 3 / 2
                px.fill(b.x + inset, top + r, b.width - inset * 2, 1, front)
                px.fill(b.x + inset - 1, top + r, 2, 1, roof)
                px.fill(b.x + b.width - inset - 1, top + r, 2, 1, eaves)
            }
        default: // hipped: eaves that overhang, then tiles stepping in to the ridge
            let rows = 3 + Int(rng.next() % 2)
            for r in 0..<rows { px.fill(b.x - 1 + r * 2, top + r, b.width + 2 - r * 4, 1, r == 0 ? eaves : r == rows - 1 ? ridge : roof) }
            if rng.next() % 3 == 0 { px.fill(b.x + 2, top + 1, 2, 3, lit(rgb(176, 156, 136), keyFront)) } // a chimney
        }
    }

    /// One of the Overlook's buildings, seen from above: its front wall with windows, its flat roof behind with a
    /// parapet, and whatever stands on the roof. Hazier the farther up the screen it stands.
    private func drawBlock(_ b: Building, into px: inout Pixels, zenith: RGB, horizon: RGB) {
        var rng = SeededRandom(state: b.seed)
        let base = b.base ?? ground, top = base + b.height, depth = b.pitch, dark = night > 0.15, glow = min(1, night * 1.6)
        let haze = Float(base) / Float(ground) * 0.5
        func tone(_ c: RGB) -> RGB { mix(c, horizon, haze) }
        let onRight = b.x + b.width / 2 < w / 2, side = min(1 + b.width / 12, 4), sideKey = onRight ? keyRight : keyLeft
        let front = tone(lit(b.colour, keyFront, shade: 0.8)), glass = tone(lit(b.colour * 0.4, .zero) + zenith * 0.16 + rgb(10, 14, 26) * night)
        px.fill(b.x, base, b.width, b.height, front)
        px.fill(onRight ? b.x + b.width - side : b.x, base, side, b.height, tone(lit(b.colour, sideKey, shade: 0.58)))
        let homes = rng.next() % 3 > 0, size = b.floor > 3 ? 2 : 1, share = officeShare
        for y in stride(from: base + 2, through: top - b.floor, by: b.floor) { // windows, lit a few neighbours at a time
            var x = b.x + 1 + (onRight ? 0 : side)
            while x < b.x + b.width - size - (onRight ? side : 0) {
                let run = Int.random(in: 1...3, using: &rng)
                let (r1, r2, r3) = (Float.random(in: 0..<1, using: &rng), Float.random(in: 0..<1, using: &rng), Float.random(in: 0..<1, using: &rng))
                let on = dark && (homes ? isLit(r1, r2, r3, home: 0.32) : r3 < share)
                let lamp = tone((homes ? mix(rgb(255, 190, 100), rgb(255, 226, 150), r1) : mix(rgb(160, 184, 216), rgb(200, 212, 224), r1)) * (0.55 + 0.4 * r2))
                for i in 0..<run where x + i * (size + 1) < b.x + b.width - size {
                    px.fill(x + i * (size + 1), y, size, b.floor - 1, on ? mix(glass, lamp, glow) : glass)
                }
                x += run * (size + 1)
            }
        }
        // The roof: the sky lights it more than any wall, so by day it is the brightest thing in view.
        let surface = [rgb(92, 94, 104), rgb(150, 144, 132), rgb(128, 86, 72), rgb(104, 122, 112), rgb(160, 160, 156), rgb(116, 114, 118),
                       rgb(92, 94, 104), rgb(134, 128, 120)].randomElement(using: &rng)!
        let roof = tone(lit(surface, keyTop * 0.45))
        px.fill(b.x, top, b.width, depth, roof)
        px.fill(b.x, top, b.width, 1, tone(lit(surface, keyTop * 0.8, shade: 1.2))) // the parapet's near edge, lit
        px.fill(b.x, top + depth - 1, b.width, 1, roof * 0.82)                 // and its far one
        guard depth >= 5 else { return }
        let metal = tone(mix(rgb(70, 70, 80), rgb(14, 14, 22), night)), fromRight = keyRight.sum() >= keyLeft.sum()
        if b.roof == .antenna { // a steaming stack (its steam is a sprite: see `layOutOverlook`)
            let at = stack(on: b)
            px.fill(at.x - 1, at.y, 3, 4, tone(lit(rgb(126, 128, 134), keyFront)))
            px.fill(at.x - 2, at.y + 4, 5, 1, metal)
        }
        for slot in 0..<b.width / 11 { // what stands on it, each with a shadow away from the Sun
            let x = b.x + 3 + slot * 11 + Int.random(in: 0...3, using: &rng), y = top + 1 + Int.random(in: 0...max(0, depth - 5), using: &rng)
            let shadow = roof * 0.7
            switch rng.next() % 7 {
            case 0:
                px.fill(fromRight ? x - 3 : x + 4, y, 3, 2, shadow)
                drawTank(into: &px, x: x, y: y, legs: metal)
            case 1: // a stair head
                px.fill(fromRight ? x - 2 : x + 5, y, 2, 2, shadow)
                px.fill(x, y, 5, 3, front)
                px.fill(x, y + 3, 5, 2, roof)
                px.fill(x + 2, y, 1, 2, glass)
            case 2: // air conditioning
                px.fill(fromRight ? x - 1 : x + 3, y, 1, 1, shadow)
                px.fill(x, y, 3, 2, tone(lit(rgb(190, 192, 196), keyTop * 0.6)))
                px.fill(x, y, 3, 1, tone(lit(rgb(120, 124, 130), .zero)))
            case 3: // a skylight
                px.fill(x, y, 4, 2, dark && rng.next() % 2 == 0 ? mix(glass, rgb(255, 214, 150), glow * 0.7) : tone(zenith * 0.8 + 0.1))
            case 4: // a roof garden
                px.fill(x, y, 6, 3, tone(lit(rgb(84, 126, 80), keyTop * 0.5)))
                px.plot(x + 1, y + 1, tone(lit(rgb(130, 160, 96), keyTop * 0.5)))
                px.plot(x + 4, y + 2, tone(lit(rgb(130, 160, 96), keyTop * 0.5)))
            case 5: // solar panels
                px.fill(x, y, 6, 2, tone(lit(rgb(44, 60, 104), keyTop * 0.4)))
                for i in [1, 3, 5] { px.plot(x + i, y + 1, tone(lit(rgb(90, 112, 160), keyTop * 0.4))) }
            default: break // bare roof
            }
        }
    }

    /// The roof the Overlook looks out from, along the bottom of the screen where the Dock sits: a dark parapet, a
    /// big water tank at one end, an aerial and two vents.
    private func drawRooftop(into px: inout Pixels) {
        let wall = lit(rgb(64, 60, 66), keyFront), coping = lit(rgb(110, 104, 106), keyTop * 0.6, shade: 1.1), dark = lit(rgb(40, 38, 44), .zero)
        // Far off, an expressway on piers across the foot of the skyline, for the traffic.
        let concrete = mix(lit(rgb(150, 150, 146), keyTop * 0.4), behind, 0.45)
        px.fill(0, ground + 5, w, 1, concrete)
        for x in stride(from: 5, to: w, by: 13) { px.fill(x, ground + 1, 1, 4, concrete * 0.8) }
        px.fill(0, 0, w, 13, wall)
        px.fill(0, 13, w, 2, coping)
        for x in stride(from: 0, to: w, by: 16) { px.fill(x, 0, 1, 13, dark) } // joints
        let tx = w * 6 / 100 // the tank: staves and hoops on a steel frame
        for x in [tx + 2, tx + 12, tx + 22] { px.fill(x, 15, 1, 12, dark) }
        px.fill(tx, 26, 26, 1, dark)
        for row in 0..<22 { px.fill(tx, 27 + row, 26, 1, lit(rgb(124, 86, 62), keyFront, shade: row % 7 == 3 ? 0.55 : 0.85)) }
        px.fill(tx + (keyRight.sum() >= keyLeft.sum() ? 22 : 0), 27, 4, 22, lit(rgb(124, 86, 62), max(keyRight, keyLeft), shade: 0.7))
        for r in 0..<5 { px.fill(tx - 1 + r * 3, 49 + r, 28 - r * 6, 1, lit(rgb(96, 68, 52), keyTop * 0.5)) } // its conical lid
        for x in [w * 31 / 100, w * 58 / 100] { // two steaming stacks: a pipe with a rain cap
            px.fill(x, 15, 3, 9, lit(rgb(120, 124, 130), keyFront))
            px.fill(x + (keyRight.sum() >= keyLeft.sum() ? 2 : 0), 15, 1, 9, lit(rgb(120, 124, 130), max(keyRight, keyLeft), shade: 0.7))
            px.fill(x - 1, 25, 5, 1, dark)
            px.fill(x, 26, 3, 1, dark)
        }
        let ax = w * 44 / 100 // an aerial
        px.fill(ax, 15, 1, 18, dark)
        for (y, half) in [(30, 4), (27, 3), (24, 2)] { px.fill(ax - half, y, half * 2 + 1, 1, dark) }
    }

    /// Hillside Town's harbour, in front of the houses: the quay with its lamps, the breakwater and its lighthouse,
    /// and far out a couple of sails.
    private func drawHarbour(into px: inout Pixels) {
        let quayTop = harbour + 4, end = slope.firstIndex { $0 <= 0.5 } ?? w, pier = w * 86 / 100
        let stone = lit(rgb(176, 166, 146), keyFront), lamp = rgb(255, 222, 160), glow = min(1, night * 1.6)
        px.fill(0, harbour, end + 2, 4, stone)
        px.fill(0, quayTop - 1, end + 2, 1, lit(rgb(196, 188, 170), keyTop))
        px.fill(0, harbour, end + 2, 1, stone * 0.55)
        px.fill(end + 2, harbour, pier - end - 2, 3, stone * 0.8) // the breakwater, lower and rougher
        px.fill(end + 2, harbour, pier - end - 2, 1, stone * 0.5)
        for x in stride(from: end + 4, to: pier, by: 5) { px.plot(x, harbour + 3, stone * 0.7) }
        for x in stride(from: 9, to: end, by: 18) { // lamps along the quay
            px.fill(x, quayTop, 1, 5, lit(rgb(60, 62, 68), .zero))
            px.plot(x, quayTop + 5, mix(rgb(120, 120, 112), lamp, night))
            guard night > 0.3 else { continue }
            for dy in -2...2 { for dx in -2...2 where dx * dx + dy * dy <= 5 { px.plot(x + dx, quayTop + 5 + dy, lamp, 0.22 * night) } }
        }
        // The lighthouse at the breakwater's end: white with two red bands, a gallery and a lantern.
        let lx = w * 84 / 100, white = rgb(238, 236, 228)
        px.fill(lx - 1, harbour + 3, 7, 2, stone)
        for row in 0..<22 {
            let paint = (row / 5) % 2 == 1 ? rgb(190, 62, 54) : white
            px.fill(lx, harbour + 5 + row, 5, 1, lit(paint, keyFront))
            px.fill(lx + (lx < w / 2 ? 4 : 0), harbour + 5 + row, 1, 1, lit(paint, lx < w / 2 ? keyRight : keyLeft, shade: 0.72))
        }
        px.fill(lx - 1, harbour + 27, 7, 1, lit(rgb(60, 62, 68), .zero))
        px.fill(lx + 1, harbour + 28, 3, 3, mix(lit(rgb(90, 110, 120), .zero), lamp, glow * 0.6))
        px.fill(lx, harbour + 31, 5, 1, lit(rgb(170, 60, 52), keyTop * 0.5))
        px.fill(lx + 2, harbour + 32, 1, 2, lit(rgb(60, 62, 68), .zero))
        for x in [w * 72 / 100, w * 94 / 100] { // sails, hull down on the horizon
            px.fill(x, ground, 2, 1, lit(white * 0.7, .zero), 0.99) // 0.99, like the far shore: see the water's shader
            px.fill(x, ground + 1, 1, 3, lit(white, keyFront), 0.99)
            px.fill(x + 1, ground + 1, 1, 2, lit(white, keyFront), 0.99)
        }
    }

    /// The Airport, in front of the far skyline and nearest last: trees along the airfield's far side, the hangars,
    /// the terminal and the control tower, the apron under its floodlights, the taxiway, the runway and the sea wall.
    private func drawAirfield(into px: inout Pixels, zenith: RGB, horizon: RGB) {
        let field = waterRows, base = apron + 4, dark = night > 0.15, glow = min(1, night * 1.6), lamp = rgb(255, 226, 170)
        let metal = mix(rgb(84, 88, 98), rgb(16, 16, 24), night)
        // The ground: grass from the sea wall back to the trees, the apron's concrete, two strips of tarmac.
        let grass = lit(rgb(116, 134, 84), keyTop * 0.5)
        px.fill(0, field, w, ground - field, grass)
        var rng = SeededRandom(state: 85)
        var x = -2
        while x < w { // trees along the far side
            let r = Int.random(in: 2...4, using: &rng)
            for dy in 0...r { px.fill(x - r + dy / 2, ground - 2 + dy, (r - dy / 2) * 2 + 1, 1, lit(rgb(52, 84, 58) * (dy == r ? 1.2 : 1), keyTop * 0.3)) }
            x += Int.random(in: 3...7, using: &rng)
        }
        px.fill(0, taxiway + 2, w * 82 / 100, base - taxiway - 2, mix(lit(rgb(168, 166, 158), keyTop * 0.5), rgb(40, 40, 52), night * 0.8))

        // Hangars: a wide door under a shallow curved roof, one of them open and lit at night.
        for (i, hx) in [w * 3 / 100, w * 13 / 100].enumerated() {
            let wide = w * 9 / 100, wall = [rgb(176, 180, 186), rgb(160, 170, 160)][i]
            px.fill(hx, base, wide, 11, lit(wall, keyFront))
            for r in 0..<4 { px.fill(hx + r * r, base + 11 + r, wide - 2 * r * r, 1, lit(wall * 0.9, keyTop, shade: 1.05)) }
            let door = dark && i == 1 ? mix(lit(wall * 0.5, .zero), rgb(255, 214, 150), glow * 0.7) : lit(wall * 0.55, .zero)
            px.fill(hx + 4, base, wide - 8, 9, door)
            for dx in stride(from: hx + 4, to: hx + wide - 4, by: 5) { px.fill(dx, base, 1, 9, lit(wall * 0.42, .zero)) }
        }

        // The terminal: a long glass front under a white roof, with a taller hall in the middle.
        let (left, right) = (terminal.lowerBound, terminal.upperBound), hall = (left + right) / 2 - 24..<(left + right) / 2 + 24
        var lights = SeededRandom(state: 86)
        func glazing(_ x0: Int, _ x1: Int, _ y: Int, _ rows: Int, share: Float) {
            for row in 0..<rows { // mirroring the sky at our backs by day
                px.fill(x0, y + row, x1 - x0, 1, mix(mix(behind, zenith, 0.3 + 0.7 * Float(row) / Float(rows)) * 0.8, lit(rgb(110, 156, 176), keyFront), 0.4))
            }
            for bay in stride(from: x0, to: x1, by: 6) { // and lit from inside after dark, a few bays at a time
                let r = Float.random(in: 0..<1, using: &lights)
                if dark, r < share { px.fill(bay + 1, y, min(5, x1 - bay - 1), rows, mix(rgb(255, 206, 130), rgb(255, 232, 180), r / share), glow * (0.55 + 0.35 * r)) }
                px.fill(bay, y, 1, rows, .zero, 0.25)
            }
        }
        // It never closes, but half its lights go off in the small hours.
        let open: Float = hour >= 5 && hour < 23.5 ? 0.9 : 0.45
        px.fill(left, base, right - left, 2, lit(rgb(150, 150, 146), keyFront))
        glazing(left, right, base + 2, 8, share: open)
        px.fill(left - 2, base + 10, right - left + 4, 2, lit(rgb(232, 232, 226), keyFront, shade: 0.8))
        px.fill(left - 2, base + 12, right - left + 4, 1, lit(rgb(240, 240, 234), keyTop, shade: 1.1))
        px.fill(hall.lowerBound, base + 13, hall.count, 1, lit(rgb(150, 150, 146), keyFront))
        glazing(hall.lowerBound, hall.upperBound, base + 14, 5, share: open)
        for r in 0..<3 { px.fill(hall.lowerBound - 2 + r * 3, base + 19 + r, hall.count + 4 - r * 6, 1, lit(rgb(240, 240, 234), keyTop, shade: r == 2 ? 1.1 : 0.9)) }
        for vent in [left + 14, left + 30, right - 20] { px.fill(vent, base + 13, 6, 2, lit(rgb(170, 172, 176), keyFront, shade: 0.85)) }

        // The control tower: a concrete shaft, a cab of dark glass leaning out under its roof, and the beacon's mast.
        let tx = controlTower, concrete = rgb(196, 192, 182), onRight = tx < w / 2
        px.fill(tx - 2, base, 5, 44, lit(concrete, keyFront))
        px.fill(onRight ? tx + 2 : tx - 2, base, 1, 44, lit(concrete, onRight ? keyRight : keyLeft, shade: 0.72))
        for y in stride(from: base + 6, to: base + 40, by: 8) { px.fill(tx - 1, y, 1, 3, lit(concrete * 0.5, .zero)) }
        for (r, half) in [(44, 3), (45, 4), (46, 5)] { px.fill(tx - half, base + r, half * 2 + 1, 1, lit(concrete * 0.9, keyFront)) }
        let cab = mix(mix(behind, zenith, 0.6) * 0.5, rgb(20, 44, 40), 0.4)
        for r in 0..<5 { px.fill(tx - 6 - r / 2, base + 47 + r, 13 + r / 2 * 2, 1, dark ? mix(cab, rgb(150, 190, 160), glow * 0.22) : cab) }
        for mx in [tx - 3, tx, tx + 3] { px.fill(mx, base + 47, 1, 5, .zero, 0.35) }
        px.fill(tx - 9, base + 52, 19, 1, lit(rgb(232, 232, 226), keyTop, shade: 1.1))
        px.fill(tx - 4, base + 53, 9, 2, lit(concrete * 0.85, keyFront))
        px.fill(tx, base + 55, 1, 6, metal)
        px.fill(tx + 3, base + 55, 1, 3, metal)
        px.plot(tx + 3, base + 58, rgb(255, 60, 50), night)

        // Floodlights over the stands: a mast between each pair, and at night a pool of light on the apron under it.
        for mx in (stands + [stands.last! + stands[1] - stands[0]]).map({ $0 - (stands[1] - stands[0]) / 2 }) {
            px.fill(mx, base - 1, 1, 22, metal)
            px.fill(mx - 2, base + 21, 5, 1, metal)
            px.fill(mx - 2, base + 20, 5, 1, mix(rgb(200, 200, 196), lamp, night))
            guard night > 0.3 else { continue }
            for (rx, a) in [(30, 0.1), (20, 0.1), (11, 0.12)] as [(Int, Float)] {
                for dy in 0...5 { let reach = rx * (6 - dy) / 6; px.fill(mx - reach, apron - 1 + dy, reach * 2 + 1, 1, lamp, a * night) }
            }
            for dy in -1...1 { px.fill(mx - 3, base + 20 + dy, 7, 1, lamp, 0.25 * night) }
        }

        // The taxiway, with a yellow line down it and blue lights along its edges.
        let tarmac = mix(rgb(86, 88, 96), rgb(20, 20, 30), night)
        px.fill(0, taxiway - 1, w, 3, tarmac)
        px.fill(0, taxiway, w, 1, mix(rgb(214, 190, 90), tarmac, 0.55 + 0.3 * night))
        for lx in stride(from: 4, to: w, by: 10) where dark {
            px.plot(lx, taxiway - 1, rgb(70, 120, 255), glow)
            px.plot(lx + 5, taxiway + 1, rgb(70, 120, 255), glow * 0.8)
        }
        // A windsock on the grass beyond the apron: streaming downwind, fully out at 28 km/h (a real one's 15 knots)
        // and drooping as the wind drops; limp when there's no wind to go by.
        let along = windAlong ?? 0, reach = min(6, Int(abs(along) / 28 * 6)), sx = w * 91 / 100, top = taxiway + 11
        px.fill(sx, taxiway + 2, 1, 10, metal)
        for i in 0..<6 {
            let out = min(i, reach), down = i - out // so far along the wind, then hanging
            let paint = lit(i / 2 % 2 == 0 ? rgb(238, 120, 44) : rgb(238, 236, 228), keyFront)
            px.plot(sx + (along > 0 ? -1 - out : 1 + out), top - down, paint)
            if i < 3 { px.plot(sx + (along > 0 ? -1 - out : 1 + out), top - down - 1, paint) }
        }
        px.plot(sx, top + 1, mix(metal, lamp, night))
        // The grass between the runway and the taxiway: signs that light up.
        for sx in [w * 22 / 100, w * 47 / 100, w * 81 / 100] {
            px.fill(sx, taxiway - 3, 3, 1, mix(rgb(214, 190, 60), rgb(255, 220, 110), night))
            px.plot(sx + 3, taxiway - 3, mix(rgb(170, 50, 44), rgb(255, 70, 60), night))
        }
        // The runway: white lines along its edges and dashes down the middle, rubber where the wheels come down, and
        // at night white lights along both edges.
        let asphalt = mix(rgb(66, 68, 76), rgb(14, 14, 22), night), paint = mix(rgb(226, 226, 220), rgb(96, 98, 112), night)
        px.fill(0, field + 4, w, 6, asphalt)
        px.fill(0, field + 4, w, 1, paint, 0.55)
        px.fill(0, field + 9, w, 1, paint, 0.4)
        for dx in stride(from: 3, to: w, by: 14) { px.fill(dx, runway + 1, 7, 1, paint, 0.7) }
        for share in [0.3, 0.7] as [Float] { // the touchdown zones
            let cx = Int(Float(w) * share)
            px.fill(cx - 24, runway, 48, 2, .zero, 0.22)
            for dx in [-18, -6, 6, 18] { px.fill(cx + dx - 2, runway + 2, 4, 1, paint, 0.7) }
        }
        for lx in stride(from: 2, to: w, by: 12) where dark {
            px.plot(lx, field + 4, rgb(255, 244, 214), glow)
            px.plot(lx + 6, field + 9, rgb(255, 244, 214), glow * 0.7)
        }
        // The sea wall: rough stone, dark and wet where it meets the water.
        let stone = lit(rgb(132, 128, 120), keyFront)
        px.fill(0, field, w, 4, stone)
        px.fill(0, field + 3, w, 1, lit(rgb(160, 156, 146), keyTop))
        px.fill(0, field, w, 1, stone * 0.5)
        for sx in 0..<w where rng.next() % 3 == 0 { px.plot(sx, field + 1 + Int(rng.next() % 2), stone * 0.78) }
    }

    /// The parks in the waterfront's gaps: a hedge and a few round trees, lit from the Sun's side.
    private func drawParks(into px: inout Pixels) {
        let leaf = rgb(72, 118, 70), fromRight = keyRight.sum() >= keyLeft.sum()
        let (bright, mid, shade) = (lit(leaf, keyTop, shade: 1.1), lit(leaf * 0.85, .zero), lit(leaf * 0.62, .zero))
        for park in parks {
            var rng = SeededRandom(state: UInt64(park.x + 1000))
            px.fill(park.x, ground, park.width, 2, shade) // hedge
            var x = park.x + 4
            while x < park.x + park.width - 2 {
                let r = Int.random(in: 3...5, using: &rng), cy = ground + 3 + r + Int.random(in: 0...2, using: &rng)
                px.fill(x, ground, 1, cy - ground, lit(rgb(84, 62, 48), .zero))
                for dy in -r...r {
                    for dx in -r...r where dx * dx + dy * dy <= r * r + 1 {
                        let facing = Float(fromRight ? dx : -dx) + Float(dy) * 1.2 // toward the light, and up
                        px.plot(x + dx, cy + dy, facing > Float(r) * 0.5 ? bright : facing < -Float(r) * 0.6 ? shade : mid)
                    }
                }
                x += r * 2 - 1 + Int.random(in: 0...2, using: &rng)
            }
        }
    }

    /// The quay wall the waterfront's street runs along: dressed stone, dark and wet where it meets the water.
    private func drawQuay(into px: inout Pixels) {
        let stone = lit(rgb(150, 142, 130), keyFront)
        px.fill(0, waterRows, w, quay, stone)
        px.fill(0, waterRows + quay - 1, w, 1, lit(rgb(172, 164, 150), keyTop)) // coping
        px.fill(0, waterRows, w, 1, stone * 0.55)
        for course in 0...1 {
            for x in stride(from: course * 7, to: w, by: 14) { px.fill(x, waterRows + 1 + course * 2, 1, 2, stone * 0.82) }
        }
    }

    /// The Foothills' mountains, far ridge first, hazier with distance. A face is sunlit or in shade by which way it
    /// slopes, read from the ridge line above it over a span that widens downhill, so shadows run down from the
    /// peaks in streaks. The Sun counts as higher the higher up a face is: the tops glow after the valley is in shade.
    private func drawMountains(into px: inout Pixels, horizons: [RGB]) {
        let tallest = ridges[0].max() ?? 1, snowLine = Float(h - ground) * 0.47
        // What the Sun and Moon add to faces at each height above the ground.
        let light = (0...Int(tallest) + 1).map { row in
            let lift = 5 * Double(row) / Double(tallest), sun = key((sunAt.elevation + lift, sunAt.azimuth), sunColour(Float(sunAt.elevation + lift)))
            return (right: sun.right + moonKey.right, left: sun.left + moonKey.left, front: sun.front + moonKey.front)
        }
        let rock = [rgb(98, 106, 128), rgb(96, 106, 116), rgb(66, 90, 78)], haze: [Float] = [0.36, 0.28, 0.14]
        // Even at noon one side of a peak is the brighter: the side the Sun is on.
        let fromRight = sin((sunAt.azimuth - facing) * .pi / 180) >= 0, (toward, away): (Float, Float) = (0.9, 0.68)
        for (k, ridge) in ridges.enumerated() {
            for x in 0..<w {
                let snowAt = snowLine + 5 * sin(Float(x) * 0.21) + 3 * sin(Float(x) * 0.53 + 1) + Float(k) * 14
                for row in 0..<Int(ridge[x]) {
                    let below = ridge[x] - Float(row), reach = min(2 + Int(below * 0.3), 16)
                    let slope = ridge[min(x + reach, w - 1)] - ridge[max(x - reach, 0)] // downhill to the right when negative
                    let stone = k < 2 && Float(row) > snowAt - below * 0.25 ? rgb(234, 238, 248) : rock[k]
                    let colour = slope < -Float(reach) * 0.25 ? lit(stone, light[row].right, shade: fromRight ? toward : away)
                        : slope > Float(reach) * 0.25 ? lit(stone, light[row].left, shade: fromRight ? away : toward)
                        : lit(stone, light[row].front, shade: 0.8)
                    px.plot(x, ground + row, mix(colour, horizons[x], haze[k]))
                }
            }
        }
    }

    /// The Foothills' valley floor in front of the city: fields, a highway, scattered houses and trees, and a dark
    /// line of pines along the bottom, where the Dock sits.
    private func drawPlain(into px: inout Pixels, horizons: [RGB]) {
        var rng = SeededRandom(state: 77)
        let grass = rgb(112, 134, 88), sunlight = keyTop * 0.5
        for y in 0..<ground { // paler and hazier toward the city, in six bands
            let far = (Float(y) / Float(ground) * 6).rounded(.down) / 6
            px.fill(0, y, w, 1, mix(lit(grass * mix(0.78, 1, far), sunlight), horizons[w / 2], far * far * 0.32))
        }
        for _ in 0..<34 { // fields
            let y = Int.random(in: 24..<ground - 3, using: &rng), far = Float(y) / Float(ground)
            let tint = [rgb(176, 166, 100), rgb(84, 116, 76), rgb(152, 132, 88), rgb(128, 150, 92)].randomElement(using: &rng)!
            px.fill(Int.random(in: -20..<w, using: &rng), y, Int(Float(Int.random(in: 16...60, using: &rng)) * (1.6 - far)),
                    y > ground - 12 ? 1 : Int.random(in: 1...3, using: &rng), mix(lit(tint, sunlight), horizons[w / 2], far * far * 0.32))
        }
        let road = mix(rgb(74, 74, 82), rgb(18, 18, 26), night)
        px.fill(0, ground - 17, w, 4, road)
        px.fill(0, ground - 15, w, 1, pointwiseMin(road * 1.5, .one)) // the median
        for _ in 0..<70 { // houses and trees, thicker toward the city
            let y = ground - 2 - Int(pow(Float.random(in: 0..<1, using: &rng), 1.6) * Float(ground - 36))
            let x = Int.random(in: 0..<w, using: &rng), r = Float.random(in: 0..<1, using: &rng)
            guard y < ground - 18 || y > ground - 12 else { continue } // not on the road
            if r < 0.45 {
                px.fill(x, y, 3, 2, lit(rgb(40, 76, 56), sunlight))
                px.fill(x + 1, y + 2, 1, 1, lit(rgb(40, 76, 56), sunlight))
            } else {
                px.fill(x, y, 3, 2, lit([rgb(214, 206, 190), rgb(190, 170, 150), rgb(170, 176, 186)][Int(r * 30) % 3], keyFront))
                px.fill(x, y + 2, 3, 1, lit(rgb(120, 70, 60), sunlight))
                if night > 0.15, isLit(r, Float.random(in: 0..<1, using: &rng), Float(Int(r * 1000) % 100) / 100, home: 0.6) {
                    px.plot(x + 1, y, rgb(255, 206, 130), min(1, night * 1.6))
                }
            }
        }
        // Pines along the bottom: a rolling bank of them, each a stack of narrowing rows, lit on the Sun's side.
        let pine = rgb(34, 58, 48), fromRight = keyRight.sum() >= keyLeft.sum()
        let (sunny, shady) = (lit(pine, (fromRight ? keyRight : keyLeft) * 0.35 + sunlight * 0.3), lit(pine * 0.8, .zero))
        var x = -2
        while x < w + 4 {
            let f = Float(x), bank = 9 + Int(5 * sin(f * 0.021 + 2) + 3 * sin(f * 0.068))
            let height = Int.random(in: 13...24, using: &rng), half = Int.random(in: 3...5, using: &rng)
            px.fill(x - half - 2, 0, half * 2 + 5, bank + 2, shady)
            for row in 0..<height {
                let reach = half * (height - row) / height + (row % 4 == 0 && row < height - 5 ? 1 : 0) // boughs step out every few rows
                px.fill(x - reach, bank + row, reach, 1, fromRight ? shady : sunny)
                px.fill(x, bank + row, reach + 1, 1, fromRight ? sunny : shady)
            }
            x += Int.random(in: 4...7, using: &rng)
        }
    }

    /// Whether a window with these three random draws has its light on at the current hour. `home` is the share of
    /// rooms that keep the evening's hours.
    private func isLit(_ a: Float, _ b: Float, _ c: Float, home: Float) -> Bool {
        if c > 0.97 { return true } // stairwells and night owls
        let evening = Float(hour < 12 ? hour + 24 : hour) // runs the evening on past midnight
        if c < home && evening >= 16.5 + a * 4.5 && evening < 21 + b * 6 { return true } // home 16:30–21:00, bed 21:00–03:00
        return c < 0.3 && Float(hour) >= 5.5 + a * 1.5 && Float(hour) < 7.5 + b * 1.5 // early risers
    }

    /// Sidewalks, road markings and street lamps that pool light onto the road at night. On the waterfront the
    /// near sidewalk is the quayside, behind a railing.
    private func drawStreet(into px: inout Pixels) {
        let y0 = streetBase
        let walk = mix(rgb(150, 146, 140), rgb(36, 36, 50), night)
        let road = mix(rgb(62, 62, 70), rgb(20, 20, 30), night)
        let pole = mix(rgb(56, 58, 64), rgb(10, 10, 16), night)
        px.fill(0, y0 + 21, w, 5, walk)
        px.fill(0, y0 + 21, w, 1, walk * 0.72)
        for x in stride(from: 0, to: w, by: 12) { px.fill(x, y0 + 22, 1, 4, walk * 0.9) } // paving joints
        px.fill(0, y0 + 4, w, 17, road)
        px.fill(0, y0, w, 4, walk)
        px.fill(0, y0 + 3, w, 1, pointwiseMin(walk * 1.12, .one))
        for x in stride(from: 0, to: w, by: 10) { px.fill(x, y0 + 12, 5, 1, mix(rgb(214, 200, 120), rgb(84, 80, 56), night)) }
        if city == .waterfront {
            for x in stride(from: 0, to: w, by: 6) { px.fill(x, y0, 1, 2, pole) }
            px.fill(0, y0 + 2, w, 1, pole)
        }

        let warm = rgb(255, 214, 140)
        for lx in stride(from: 12, to: w, by: 46) {
            px.fill(lx, y0 + 23, 1, 13, pole)
            px.fill(lx, y0 + 36, 4, 1, pole)
            px.fill(lx + 2, y0 + 35, 2, 1, mix(rgb(110, 110, 104), rgb(255, 238, 180), night))
            guard night > 0.3 else { continue }
            // A pool of light in three flat steps, brightest under the lamp.
            for (rx, ry, a) in [(13, 5, 0.1), (9, 3.5, 0.1), (5, 2, 0.12)] as [(Float, Float, Float)] {
                for dy in -6...6 {
                    for dx in -14...14 where (Float(dx) / rx) * (Float(dx) / rx) + (Float(dy) / ry) * (Float(dy) / ry) <= 1 {
                        px.plot(lx + 3 + dx, y0 + 19 + dy, warm, a * night)
                    }
                }
            }
            for dy in -2...2 { for dx in -2...3 where dx * dx + dy * dy <= 5 { px.plot(lx + 2 + dx, y0 + 35 + dy, warm, 0.25 * night) } }
        }
    }

    // MARK: - Motion (every frame)

    override func update(_ currentTime: TimeInterval) {
        let dt = Float(min(max(currentTime - (lastUpdate ?? currentTime), 0), 0.1))
        lastUpdate = currentTime
        clock += TimeInterval(dt)

        for i in cars.indices where !cars[i].node.isHidden {
            let direction: Float = cars[i].lane == 0 ? 1 : -1
            // Close up behind a slower car instead of driving through it.
            var speed = cars[i].cruise
            for j in cars.indices where j != i && cars[j].lane == cars[i].lane && !cars[j].node.isHidden {
                let gap = (cars[j].x - cars[i].x) * direction - (cars[i].length + cars[j].length) / 2
                if gap > 0 && gap < 6 { speed = min(speed, cars[j].speed) }
            }
            cars[i].speed = speed
            cars[i].x += direction * speed * dt
            cars[i].node.position.x = CGFloat(cars[i].x.rounded(.down))
            if cars[i].x < -30 || cars[i].x > Float(w + 30) { cars[i].node.isHidden = true }
        }
        for lane in 0...1 where clock >= nextCar[lane] {
            spawnCar(lane: lane, at: lane == 0 ? -20 : Float(w + 20))
        }

        mirrorTraffic()
        for (i, boat) in boats.enumerated() { // each from its own waterline, as it bobs
            let node = boat.node, turned = node.xScale < 0
            reflect(i, from: Float(node.position.x) + (turned ? 0.5 : -0.5) * Float(node.size.width), foot: Float(node.position.y),
                    size: node.size, turned: turned)
        }

        for i in clouds.indices {
            clouds[i].x += clouds[i].speed * dt
            if clouds[i].x - Float(clouds[i].mask[0].count) / 2 > Float(w) { clouds[i].x = -Float(clouds[i].mask[0].count) / 2 }
            clouds[i].node.position.x = CGFloat(clouds[i].x.rounded(.down))
        }

        if planeDirection == 0, clock >= nextPlane, city != .spaceport { // nothing flies over a launch site
            planeDirection = Bool.random() ? 1 : -1
            planeX = planeDirection > 0 ? -10 : Float(w + 10)
            plane.position.y = CGFloat(Int(Float(h) * Float.random(in: 0.8...0.93)))
            plane.xScale = CGFloat(planeDirection)
            plane.isHidden = false
        }
        for bird in flock { // one slow turn in 26 seconds, on a wide flat ring that itself drifts about
            let t = Float(clock), turn = t * 2 * .pi / 26 + bird.lag
            let x = Float(w) * 0.5 + 34 * sin(t / 41) + Float(w) * 0.19 * cos(turn) + bird.offset.x
            let y = Float(h) * 0.37 + 5 * sin(t / 29) + 9 * sin(turn) + bird.offset.y
            bird.node.position = CGPoint(x: CGFloat(x.rounded(.down)), y: CGFloat(y.rounded(.down)))
            // A wheeling flock flashes pale and dark as its birds bank toward the light and away.
            let shade = CGFloat(0.5 + 0.5 * sin(turn + 0.8)) * CGFloat(1 - night)
            bird.node.color = NSColor(white: 0.2 + 0.6 * shade, alpha: 1)
        }
        if city == .bridge {
            if shipDirection == 0, clock >= nextShip {
                shipDirection = Bool.random() ? 1 : -1
                shipX = shipDirection > 0 ? -20 : Float(w + 20)
                ship.xScale = CGFloat(shipDirection)
                ship.isHidden = false
            }
            shipX += shipDirection * 2.2 * dt
            ship.position.x = CGFloat(shipX.rounded(.down))
            reflect(0, from: shipX.rounded(.down) - shipDirection * Float(ship.size.width) / 2, foot: Float(ship.position.y), size: ship.size,
                    turned: shipDirection < 0, hidden: shipDirection == 0)
            if shipDirection != 0, shipX < -22 || shipX > Float(w + 22) {
                (shipDirection, ship.isHidden) = (0, true)
                nextShip = clock + .random(in: 90...240)
            }
        }
        if city == .airport { fly(dt) }
        if city == .spaceport { launch(dt) }
        if planeDirection != 0 {
            planeX += planeDirection * 7 * dt
            plane.position.x = CGFloat(planeX.rounded(.down))
            if planeX < -12 || planeX > Float(w + 12) {
                planeDirection = 0
                plane.isHidden = true
                nextPlane = clock + .random(in: 40...120)
            }
        }
    }

    /// Puts a parked car from the pool on the road at `x`, if the spot is clear, and schedules the next one.
    private func spawnCar(lane: Int, at x: Float) {
        guard !cars.contains(where: { $0.lane == lane && !$0.node.isHidden && abs($0.x - x) < carGap }),
              let i = cars.firstIndex(where: { $0.lane == lane && $0.node.isHidden }) else { return }
        let isBus = Float.random(in: 0..<1) < 0.1
        cars[i].look = isBus ? carLooks.count - 1 : Int.random(in: 0..<carLooks.count - 1)
        cars[i].cruise = (isBus ? .random(in: 11...14) : .random(in: 14...22)) * carPace
        cars[i].speed = cars[i].cruise
        cars[i].x = x
        let look = carLooks[cars[i].look]
        cars[i].length = Float(look.length)
        cars[i].node.texture = night > 0.5 ? look.night : look.day
        cars[i].node.size = CGSize(width: look.length, height: look.height)
        cars[i].beam.position = CGPoint(x: CGFloat(look.length) / 2 - 1, y: -1)
        cars[i].node.position.x = CGFloat(x.rounded(.down))
        cars[i].node.isHidden = false
        nextCar[lane] = clock + .random(in: 1.5...6) / traffic * (city == .airport ? 6 : 1)
    }

    // MARK: - The Airport's aircraft

    /// Moves the Airport's aircraft on through their rounds: down the approach and along the runway, off its far
    /// end and back along the taxiway to a stand, a wait there, on along the taxiway to the runway's other end,
    /// and away. One at a time has the runway, and all of them land and take off the same way, into the wind.
    private func fly(_ dt: Float) {
        let out: Float = 70, taxi: Float = 7 // how far past the screen's edge is out of sight; taxiing speed
        func edge(_ way: Float) -> Float { way > 0 ? -out : Float(w) + out } // where something heading that way comes in
        func gone(_ x: Float, _ way: Float) -> Bool { way > 0 ? x > Float(w) + out : x < -out }
        var clear = !flights.contains { $0.onRunway }
        let pace = flying
        // The runway changes direction only once the airfield has emptied, as a real one's traffic pauses for it.
        if flights.allSatisfy({ $0.phase == .away }) { runwayWay = windWay }
        for i in flights.indices {
            var f = flights[i]
            // Aircraft on the taxiway all go the same way; one holds while another is close ahead of it.
            let near = flights.indices.filter { $0 != i && flights[$0].taxiing && abs(flights[$0].x - f.x) < 80 }
            let held = near.contains { (flights[$0].x - f.x) * -f.way > 0 }
            // Time on a stand and time away run down at Settings' pace, so moving a slider shows at once, not at the next wait.
            if f.phase == .away || f.phase == .parked, clock < f.until { f.until += Double(dt) * (1 - pace) }
            switch f.phase {
            case .away: // back when its wait is over, the runway is clear and there's a stand for it
                let free = stands.indices.filter { stand in !flights.contains { (1...5).contains($0.phase.rawValue) && $0.stand == stand } }
                guard clock >= f.until, clear, runwayWay == windWay, let stand = free.randomElement() else { break }
                change(&f)
                (f.phase, f.stand, f.way, f.x, f.speed) = (.approach, stand, runwayWay, edge(runwayWay), 26)
                (f.slope, f.gear, f.berth, clear) = (0, true, 0, false)
            case .approach: // down a steady slope to the touchdown point, easing off with the nose up at the last
                f.x += f.way * f.speed * dt
                let left = (Float(w) * (0.5 - 0.2 * f.way) - f.x) * f.way
                f.height = left > 40 ? left * 0.105 : max(0, 4.2 * left * left / 1600)
                f.slope = left > 40 ? 0 : 0.06
                if left <= 0 { (f.phase, f.until, movements) = (.rollout, clock + 1.5, movements + 1) }
            case .rollout: // the nose comes down, and it slows along the runway and off its far end
                if clock >= f.until { f.slope = 0 }
                f.speed = max(10, f.speed - 1.3 * dt)
                f.x += f.way * f.speed * dt
                if gone(f.x, f.way) { (f.phase, f.until, clear) = (.vacated, clock + .random(in: 10...20), true) }
            case .vacated:
                if clock >= f.until, near.isEmpty { (f.phase, f.x, f.speed) = (.taxiIn, edge(-f.way), taxi) }
            case .taxiIn: // back along the taxiway, slowing as it pulls off onto its stand
                let left = (Float(stands[f.stand]) - f.x) * -f.way
                f.berth = 1 - min(max(left / 30, 0), 1)
                if !held { f.x -= f.way * min(taxi, 2.5 + left * 0.15) * dt }
                if left <= 0.5 { (f.phase, f.x, f.berth, f.until) = (.parked, Float(stands[f.stand]), 1, clock + .random(in: 150...330)) }
            case .parked: // its engines start a few seconds before it moves off
                if clock >= f.until, near.isEmpty { (f.phase, f.speed) = (.taxiOut, 0) }
            case .taxiOut: // off its stand, and on along the taxiway to the runway's other end
                f.speed = min(taxi, f.speed + 2 * dt)
                if !held { f.x -= f.way * f.speed * dt }
                f.berth = max(0, 1 - abs(f.x - Float(stands[f.stand])) / 30)
                if gone(f.x, -f.way) { (f.phase, f.until) = (.crossing, clock + .random(in: 8...16)) }
            case .crossing:
                if clock >= f.until, clear { (f.phase, f.x, f.speed, clear) = (.lineUp, edge(f.way), taxi + 2, false) }
            case .lineUp: // onto the runway, and a pause at the start of its run
                if (Float(w) * (0.5 - 0.4 * f.way) - f.x) * f.way > 0 {
                    f.x += f.way * f.speed * dt
                    f.until = clock + 4
                } else if clock >= f.until { (f.phase, f.speed) = (.takeoff, 0) }
            case .takeoff: // faster and faster, then the nose lifts, it leaves the ground and the wheels go up
                f.speed = min(36, f.speed + 3.5 * dt)
                f.x += f.way * f.speed * dt
                // ponytail: the nose goes no higher than 1 in 6, where the art still slides in clean steps; steeper
                // and its stripes break into checks. Draw a climbing aircraft by hand if it should pitch like a real one.
                if f.speed > 24 { f.slope = min(1 / 6, f.slope + 0.1 * dt) }
                if f.slope > 0.08 { f.height += f.speed * (f.slope * 1.25 - 0.02) * dt }
                f.gear = f.height < 12
                if gone(f.x, f.way) || f.height > Float(h) {
                    movements += 1
                    (f.phase, f.until, f.height, clear) = (.away, clock + .random(in: 40...150), 0, true)
                }
            }
            let y = f.onRunway ? Float(runway) + f.height : Float(taxiway) + f.berth * Float(apron - taxiway)
            f.node.position = CGPoint(x: CGFloat(f.x.rounded(.down)), y: CGFloat(y.rounded(.down)))
            let running = f.phase != .parked || clock > f.until - 8
            let look = [f.phase.rawValue, Int(f.slope * 50), f.gear ? 1 : 0, Int(f.berth * 4), running ? 1 : 0]
            let changed = look != f.look
            f.look = look
            flights[i] = f
            if changed { dress(i) }
            let up = (f.onRunway ? f.height.rounded(.down) : 0) - Float(flights[i].below) // its picture's foot, above the ground
            reflect(i, from: f.x.rounded(.down) - f.facing * Float(f.wheels), foot: Float(mirrorLine - wall) - up / 1.8, size: f.node.size,
                    turned: f.facing < 0, hidden: f.node.isHidden)
        }
    }

    /// A new aircraft for a flight: mostly airliners, some turboprops and one wide-body at most, in a livery of our
    /// own that no other aircraft on the airfield is wearing.
    private func change(_ f: inout Flight) {
        let heavy = flights.contains { $0.rows == widebody && $0.node !== f.node }
        f.rows = [airliner, airliner, airliner, airliner, turboprop, turboprop, heavy ? airliner : widebody].randomElement()!
        let liveries = [rgb(34, 120, 132), rgb(204, 84, 52), rgb(44, 62, 120), rgb(226, 176, 52), rgb(120, 60, 110), rgb(70, 140, 84)]
        f.accent = liveries.filter { paint in !flights.contains { $0.accent == paint } }.randomElement() ?? liveries[0]
        f.wheels = Array(f.rows.last!).firstIndex(of: "o") ?? 0
    }

    /// Gives an aircraft the look of this moment: its pitch and wheels, the light it stands in, the way it faces
    /// and which of its lights are on. The water mirrors the same picture.
    private func dress(_ i: Int) {
        let f = flights[i], slope = Float(Int(f.slope * 50)) / 50
        func lift(_ x: Int) -> Int { Int((Float(x - f.wheels) * slope).rounded()) }
        /// The column of the first or last of a character in the art, and its row counted up from the wheels.
        func find(_ ch: Character, last: Bool = false) -> (x: Int, y: Int) {
            let found = f.rows.enumerated().compactMap { r, row -> (x: Int, y: Int)? in
                let line = Array(row)
                return (last ? line.lastIndex(of: ch) : line.firstIndex(of: ch)).map { ($0, f.rows.count - 1 - r) }
            }
            return (last ? found.max { $0.x < $1.x } : found.min { $0.x < $1.x }) ?? (0, 0)
        }
        func spot(_ x: Int, _ y: Int) -> CGPoint { CGPoint(x: CGFloat(x - f.wheels) + 0.5, y: CGFloat(y + lift(x)) + 0.5) }
        let nose = find("o", last: true), tip = find("S"), mid = f.rows[0].count / 2
        let back = f.rows.count - (f.rows.firstIndex { Array($0)[mid] != "." } ?? 0) // its back, halfway along
        let landing = [.approach, .lineUp, .takeoff].contains(f.phase)
        // The light it stands in: the sky's and the Sun's, and at night the apron's floodlights once it's on its stand.
        let light = mix(ambient + keyFront + keyTop * 0.25, RGB(0.8, 0.74, 0.62), night * Float(Int(f.berth * 4)) / 4 * 0.6)
        let (texture, below) = aircraft(f.rows, accent: f.accent, slope: slope, gear: f.gear, wheels: f.wheels, light: light,
                                        lamp: landing ? (nose.x, nose.y + 1) : nil)
        let size = texture.size()
        (f.node.texture, f.node.size) = (texture, size)
        f.node.anchorPoint = CGPoint(x: CGFloat(f.wheels) / size.width, y: CGFloat(below) / size.height)
        flights[i].below = below
        if mirrors.indices.contains(i) { mirrors[i].picture.textureValue = texture }
        (f.beacon.position, f.lamp.position) = (spot(mid, back), spot(nose.x, nose.y + 1))
        (f.wingtip.position, f.strobe.position) = (spot(tip.x, tip.y), spot(tip.x, tip.y))
        f.node.xScale = CGFloat(f.facing)
        f.node.zPosition = f.onRunway ? 4.6 : f.berth > 0.5 ? 4.2 : 4.4
        f.node.isHidden = [.away, .vacated, .crossing].contains(f.phase)
        f.wingtip.color = f.facing > 0 ? NSColor(red: 0.2, green: 1, blue: 0.4, alpha: 1) : NSColor(red: 1, green: 0.2, blue: 0.15, alpha: 1)
        f.wingtip.alpha = CGFloat(night)
        f.beacon.isHidden = f.phase == .parked && clock <= f.until - 8
        f.strobe.isHidden = !f.onRunway
        f.lamp.isHidden = !landing
    }

    /// An aircraft from rows of characters, nose to the right, in this `light`, with its nose up by `slope` pixels
    /// for each pixel along: every column slides up or down whole pixels about the main wheels, which is how pixel
    /// art draws a shallow line. Without `gear` its wheels are up. Its cabin lights show after dark, and a landing
    /// light at `lamp` (a column, and a row above the wheels) if it has one on. Returns the picture and how far it
    /// reaches below the wheels.
    private func aircraft(_ rows: [String], accent: RGB, slope: Float, gear: Bool, wheels: Int, light: RGB,
                          lamp: (x: Int, y: Int)?) -> (texture: SKTexture, below: Int) {
        func lift(_ x: Int) -> Int { Int((Float(x - wheels) * slope).rounded()) }
        let width = rows[0].count, below = max(0, -lift(0)), height = rows.count + below + max(0, lift(width - 1))
        var paints: [Character: RGB] = [
            "W": rgb(236, 238, 240), "g": rgb(170, 176, 186), "c": accent, "T": accent, "h": rgb(200, 204, 212), "S": rgb(206, 210, 218),
            "s": rgb(150, 156, 168), "e": rgb(110, 116, 128), "E": rgb(196, 200, 208), "p": rgb(60, 62, 70), "w": rgb(70, 96, 130), "k": rgb(52, 70, 96),
        ]
        if gear { (paints["l"], paints["o"]) = (rgb(90, 94, 104), rgb(30, 30, 36)) }
        var px = Pixels(width, height)
        for (r, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() {
                let y = rows.count - 1 - r + below + lift(x)
                if let colour = paints[ch] { px.plot(x, y, pointwiseMin(colour * light, .one)) }
                if ch == "w" { px.plot(x, y, rgb(255, 220, 140), min(1, night * 1.6)) }
            }
        }
        if let lamp { px.plot(lamp.x, lamp.y + below + lift(lamp.x), rgb(255, 250, 235)) }
        return (px.texture(), below)
    }

    /// Relative traffic for the hour: quiet small hours, rush hours at 8 and 17.
    private var traffic: Double {
        let table = [0.15, 0.1, 0.08, 0.08, 0.1, 0.25, 0.6, 0.95, 1, 0.7, 0.6, 0.65,
                     0.7, 0.65, 0.65, 0.75, 0.9, 1, 0.9, 0.7, 0.55, 0.45, 0.35, 0.25]
        return table[Int(hour) % 24]
    }

    // MARK: - Art

    /// The pool of light a car throws on the road ahead: an ellipse lying on the tarmac, fading in three steps.
    private lazy var headlightBeam: SKTexture = {
        var px = Pixels(14, 4)
        for x in 0..<14 {
            for y in 0..<4 where (Float(x) - 6) * (Float(x) - 6) / 56 + (Float(y) - 1.5) * (Float(y) - 1.5) / 3.2 <= 1 {
                px.plot(x, y, rgb(255, 232, 170), x < 5 ? 0.34 : x < 10 ? 0.22 : 0.12)
            }
        }
        return px.texture()
    }()

    /// A vehicle drawn as `rows` and painted in `body`, by day and by night.
    private func vehicle(_ rows: [String], body: RGB) -> (day: Pixels, night: Pixels) {
        func look(_ dark: Bool) -> Pixels {
            let paint = dark ? body * RGB(0.46, 0.48, 0.62) : body
            return picture(rows, ["B": paint, "#": paint * 0.85, "d": paint * 0.65,
                                  "w": dark ? rgb(30, 36, 52) : rgb(150, 186, 216),
                                  "W": dark ? rgb(255, 220, 140) : rgb(150, 186, 216),
                                  "h": dark ? rgb(255, 250, 215) : rgb(232, 232, 218),
                                  "t": dark ? rgb(255, 50, 50) : rgb(150, 30, 30), "o": rgb(24, 24, 30)])
        }
        return (look(false), look(true))
    }

    /// A vehicle far off: a dash of paint by day, and by night only its tail light and headlight.
    private func speck(_ length: Int, body: RGB) -> (day: Pixels, night: Pixels) {
        (picture([String(repeating: "B", count: length)], ["B": body]),
         picture(["t" + String(repeating: ".", count: length - 2) + "h"], ["t": rgb(255, 50, 50), "h": rgb(255, 250, 215)]))
    }

    /// A cloud outline: a few overlapping circles with a flat base.
    private func cloudMask(_ rng: inout SeededRandom) -> [[Bool]] {
        let width = Int.random(in: 40...60, using: &rng) / 2 * 2, height = 16
        let puffs = (0..<6).map { _ in
            (x: Float.random(in: 9...Float(width - 9), using: &rng), y: Float.random(in: 4...7, using: &rng), r: Float.random(in: 4...7.5, using: &rng))
        }
        return (0..<height).map { y in
            (0..<width).map { x in
                let base = (Float(x) - Float(width) / 2) / (Float(width) / 2 - 1), rise = (Float(y) - 1) / 4
                return y >= 1 && (base * base + rise * rise <= 1 // a long flat body…
                    || puffs.contains { (Float(x) - $0.x) * (Float(x) - $0.x) + (Float(y) - $0.y) * (Float(y) - $0.y) <= $0.r * $0.r }) // …with puffs on top
            }
        }
    }

    // MARK: - The Spaceport

    // The Spaceport's places: the column the rocket stands at, the row of the pad's padDeck (the top of its mound),
    // the row a rocket's foot stands at on the launch mount, the hangar's left wall, and the columns of the two
    // landing zones.
    private var padX: Int { w * 46 / 100 }
    private var padDeck: Int { ground + 6 }
    private var mount: Int { padDeck + 4 }
    private var hangarX: Int { padX - 139 }
    private var zones: [Int] { [w * 77 / 100, w * 89 / 100] }

    /// The Spaceport: a launch site across a lagoon, seen from the bank the public watches from. Everything of its
    /// that moves is painted into one layer over the land, which the lagoon mirrors. Returns the top of the tower's
    /// mast, for the beacon.
    private func layOutSpaceport(_ rng: inout SeededRandom) -> (x: Int, y: Int) {
        downtown = 0.46
        for x in 0..<w { crest[x] = ground + 4 }
        // A rocket on the pad well into its count, so there's something to see at once, and a booster from the last
        // flight waiting for the crane, unless the rocket is a Falcon Heavy, whose two boosters need both zones.
        (pad, crane, plume, liftoffAt, trailFrom, launchShown) = (Pad(), Crane(), [], -1000, nil, [])
        (pad.phase, pad.until, pad.rocket, pad.flown) = (.count, clock + 24 * Self.knob(.launches), Self.nextRocket(), Bool.random())
        boosters = pad.rocket == .heavy ? [] : [Booster(phase: .landed, zone: 1, until: clock + 2)]
        let rows = h - waterRows, texture = SKMutableTexture(size: CGSize(width: w, height: rows))
        texture.filteringMode = .nearest
        (launchTexture, smoke) = (texture, Bytes(w, rows, floor: waterRows))
        launchLayer = SKSpriteNode(texture: texture)
        launchLayer.anchorPoint = .zero
        launchLayer.size = texture.size()
        launchLayer.position.y = CGFloat(waterRows)
        launchLayer.zPosition = 4.5
        countdown = SKSpriteNode()
        countdown.anchorPoint = .zero
        countdown.size = CGSize(width: 27, height: 5)
        countdown.position = CGPoint(x: w * 9 / 100 + 2, y: 14)
        countdown.zPosition = 3
        counted = ""
        return (padX + 11, padDeck + 74)
    }

    /// The Spaceport's fixed things: scrub along the far shore, a far-off assembly building, the hangar rockets
    /// are readied in, a tank farm, the pad on its mound with its tower and masts, and two landing zones; and on
    /// our side of the lagoon the bank people watch from, with its countdown clock.
    private func drawSpaceport(into px: inout Pixels, zenith: RGB, horizon: RGB) {
        var rng = SeededRandom(state: 96)
        func haze(_ c: RGB, _ t: Float = 0.22) -> RGB { mix(c, horizon, t) }
        let field = waterRows, glow = min(1, night * 1.6), lamp = rgb(255, 226, 170), red = rgb(255, 60, 50)
        let scrub = haze(lit(rgb(84, 108, 76), keyTop * 0.3)), trees = haze(lit(rgb(56, 84, 62), keyTop * 0.2))
        let steel = mix(haze(lit(rgb(96, 100, 110), .zero), 0.15), rgb(18, 18, 28), night * 0.85)
        px.fill(0, field, w, ground - field, scrub)
        for x in 0..<w where rng.next() % 10 < 7 { px.plot(x, field, haze(lit(rgb(206, 194, 160), keyTop * 0.4))) } // shell sand at the water's edge
        px.fill(0, ground, w, 2, haze(trees, 0.25)) // the far tree line

        // A far-off assembly building, tall and blank, in the haze behind the hangar.
        let hx = hangarX, wall = rgb(206, 208, 212)
        func far(_ c: RGB) -> RGB { haze(c, 0.55) }
        px.fill(hx - 34, ground, 26, 40, far(lit(wall, keyFront)))
        px.fill(hx - 34, ground, 3, 40, far(lit(wall, keyLeft, shade: 0.8)))
        px.fill(hx - 11, ground, 3, 40, far(lit(wall, keyRight, shade: 0.8)))
        for dx in [6, 11, 16] { px.fill(hx - 34 + dx, ground, 2, 33, far(lit(wall * 0.6, .zero))) } // its tall doors
        px.fill(hx - 8, ground, 14, 13, far(lit(wall * 0.92, keyFront)))

        // Clumps of palmetto and low trees along the shore, cleared round the hangar, the pad and the landing zones.
        var x = -3
        while x < w {
            let r = Int.random(in: 2...5, using: &rng)
            let cleared = (hx - 16..<hx + 56).contains(x) || (padX - 63..<padX + 57).contains(x) || (zones[0] - 28..<zones[1] + 26).contains(x)
            if !cleared || rng.next() % 8 == 0 {
                for dy in 0...r { px.fill(x - r + dy / 2, ground - 1 + dy, (r - dy / 2) * 2 + 1, 1, trees * (dy == r ? 1.18 : 1)) }
            }
            x += Int.random(in: 4...11, using: &rng)
        }
        // The road along the shore: the transporter's way to the pad, and the crane's to the landing zones.
        px.fill(0, field + 1, w, 1, mix(haze(lit(rgb(178, 172, 156), keyTop * 0.4)), rgb(30, 30, 40), night * 0.7))

        // The hangar: a long white shed with a tall door at the pad end, lit inside after dark.
        px.fill(hx, ground, 50, 12, haze(lit(rgb(222, 224, 226), keyFront)))
        px.fill(hx, ground, 50, 1, haze(lit(rgb(120, 124, 132), .zero)))
        px.fill(hx, ground + 9, 50, 1, haze(lit(rgb(70, 110, 170), keyFront)))
        for r in 0..<3 { px.fill(hx - 1 + r * 4, ground + 12 + r, 52 - r * 8, 1, haze(lit(rgb(196, 200, 206), keyTop))) }
        px.fill(hx + 34, ground, 13, 9, mix(haze(lit(rgb(70, 74, 84), .zero)), rgb(255, 214, 150), glow * 0.75))
        for dx in stride(from: hx + 3, to: hx + 30, by: 6) { px.fill(dx, ground + 5, 2, 2, mix(haze(lit(rgb(90, 110, 130), .zero)), lamp, glow * 0.6)) }

        // The tank farm: two tanks on their sides, and the liquid oxygen's sphere.
        let tank = haze(lit(rgb(236, 236, 232), keyFront + keyTop * 0.3))
        for tx in [padX - 79, padX - 69] {
            px.fill(tx, ground + 1, 8, 3, tank)
            px.fill(tx, ground + 1, 8, 1, tank * 0.78)
            for leg in [tx + 1, tx + 6] { px.plot(leg, ground, steel) }
        }
        for (dy, half) in [(1, 1), (2, 3), (3, 3), (4, 3), (5, 3), (6, 2), (7, 1)] {
            px.fill(padX - 51 - half, ground + dy, half * 2 + 1, 1, tank * (dy < 3 ? 0.8 : 1))
        }
        for leg in [padX - 53, padX - 49] { px.plot(leg, ground, steel) }

        // The pad: a mound with a long ramp on the hangar's side, the flame trench through it, and the launch mount.
        let earth = haze(lit(rgb(124, 132, 100), keyTop * 0.3), 0.15), concrete = haze(lit(rgb(196, 192, 180), keyTop * 0.5), 0.12)
        for r in 0..<6 { px.fill(padX - 55 + r * 5, ground + r, 96 - r * 7, 1, earth) }
        px.fill(padX - 25, padDeck - 1, 54, 1, concrete)
        px.fill(padX - 55, ground, 8, 1, concrete)
        for r in 0..<6 { px.fill(padX - 55 + r * 5, ground + r, 5, 1, concrete) } // the ramp's track
        px.fill(padX - 9, ground, 19, 4, mix(lit(rgb(52, 50, 52), .zero), rgb(12, 12, 18), night * 0.6))
        px.fill(padX - 4, padDeck, 9, 4, steel)

        // The tower beside the rocket: lattice steel with a padDeck every few rows, an arm out to the capsule, a mast.
        let tx = padX + 9
        for y in padDeck..<padDeck + 58 {
            let k = (y - padDeck) % 6
            px.plot(tx, y, steel)
            px.plot(tx + 4, y, steel)
            if k == 0 { px.fill(tx, y, 5, 1, steel) } else { px.plot(tx + (k < 4 ? k : 6 - k), y, steel, 0.8) }
        }
        px.fill(tx - 1, padDeck + 58, 7, 1, steel)
        px.fill(tx + 2, padDeck + 59, 1, 15, steel)
        px.fill(tx - 4, padDeck + 45, 4, 1, steel)
        for y in [padDeck + 18, padDeck + 36, padDeck + 54] { px.plot(tx + 4, y, mix(steel, red, night)) }
        // Lightning masts either side, and the water tower: a ball on a stem.
        for (mx, base) in [(padX - 27, padDeck), (padX + 31, ground)] {
            px.fill(mx, base, 1, 64, steel)
            for y in stride(from: 0, to: 14, by: 2) { px.plot(mx + (y % 4 == 0 ? 1 : -1), base + y, steel, 0.8) }
        }
        let wx = padX + 57
        px.fill(wx, ground, 2, 44, haze(lit(rgb(214, 216, 220), keyFront)))
        for (dy, half) in [(44, 2), (45, 4), (46, 5), (47, 5), (48, 5), (49, 4), (50, 2)] {
            px.fill(wx - half + 1, ground + dy, half * 2, 1, haze(lit(rgb(232, 232, 228) * (dy < 46 ? 0.82 : 1), keyFront + keyTop * 0.3)))
        }
        px.plot(wx, ground + 51, mix(steel, red, night))
        // Floodlights on the padDeck, which light the rocket after dark, and the pool of their light on the mound.
        for mx in [padX - 17, padX + 20] {
            px.fill(mx, padDeck, 1, 16, steel)
            px.fill(mx - 1, padDeck + 16, 3, 1, mix(rgb(200, 200, 196), lamp, night))
            for (dx, dy) in [(0, 1), (0, -1), (2, 0), (-2, 0), (1, 1), (-1, 1), (1, -1), (-1, -1)] { px.plot(mx + dx, padDeck + 16 + dy, lamp, 0.3 * night) }
        }
        for (reach, a) in [(34, 0.07), (22, 0.08), (12, 0.1)] as [(Int, Float)] where night > 0.3 {
            for dy in 0..<6 { px.fill(padX - reach * (6 - dy) / 6, ground + dy, reach * (6 - dy) / 6 * 2 + 1, 1, lamp, a * night) }
        }

        // The landing zones: a round of concrete seen edge on, lights round it at night; a hut and a mast between.
        for zone in zones {
            px.fill(zone - 17, ground, 35, 1, concrete)
            px.fill(zone - 17, ground - 1, 35, 1, concrete * 0.82)
            px.fill(zone - 3, ground, 7, 1, concrete * 0.7)
            for dx in [-17, -9, 9, 17] where night > 0.15 { px.plot(zone + dx, ground, rgb(255, 244, 214), glow) }
        }
        let between = (zones[0] + zones[1]) / 2
        px.fill(between - 3, ground, 7, 4, haze(lit(rgb(200, 200, 196), keyFront)))
        px.fill(between + 5, ground, 1, 14, steel)
        px.plot(between + 5, ground + 14, mix(steel, red, night))

        // Our side of the lagoon: a grass bank, in shadow against the water, and what stands on it.
        let grass = mix(lit(rgb(46, 66, 44), keyTop * 0.2), rgb(6, 8, 14), night * 0.6), shadow = grass * 0.5
        func top(_ x: Int) -> Int { 6 + Int(1.5 * sin(Float(x) * 0.05) + 1.2 * sin(Float(x) * 0.13 + 2)) }
        for x in 0..<w {
            px.fill(x, 0, 1, top(x), grass)
            if rng.next() % 10 < 3 { px.plot(x, top(x), grass * 0.85) }
        }
        // The countdown clock: a black board on two legs. Its figures are a sprite of their own (`countdown`).
        let cx = w * 9 / 100
        px.fill(cx, 12, 31, 9, rgb(10, 10, 14))
        for leg in [cx + 3, cx + 26] { px.fill(leg, 5, 2, 7, shadow) }
        // A flag on its pole.
        px.fill(cx + 44, 5, 1, 36, mix(lit(rgb(200, 200, 204), .zero), rgb(40, 40, 54), night))
        px.fill(cx + 45, 34, 9, 6, mix(lit(rgb(196, 64, 60), keyFront), rgb(30, 20, 30), night * 0.8))
        px.fill(cx + 45, 37, 4, 3, mix(lit(rgb(52, 70, 140), keyFront), rgb(16, 18, 34), night * 0.8))
        // People watching, in ones and twos, and a camera on its tripod.
        for (at, who) in [(96, person), (102, pointing), (112, person), (117, child), (121, person), (250, person), (256, person),
                          (268, pointing), (277, child), (281, person), (296, person), (301, person), (316, pointing)] {
            let x = at * w / 378
            px.draw(picture(who, ["#": shadow]), x: x, y: top(x) - 1)
        }
        let tripod = 131 * w / 378
        for i in 0...7 { for foot in [-3, 3] { px.plot(tripod + foot - foot * i / 7, 5 + i, shadow) } }
        px.fill(tripod - 1, 12, 4, 2, shadow)
        px.plot(tripod + 3, 13, shadow)
        // A cabbage palm at the right edge.
        px.fill(w - 20, 3, 2, 42, shadow)
        px.draw(picture(palm, ["#": shadow]), x: w - 28, y: 40)
    }

    /// The next rocket out of the hangar. They come in threes in a shuffled order, one of each three a Falcon Heavy
    /// and the others Falcon 9s, one of them as often as not under a capsule: so a Heavy's double landing is never
    /// more than four flights away, where a plain one-in-three chance could keep it away all evening. The order
    /// carries from scene to scene (the app's Shuffle and a move between cities build a new one each time), so
    /// short visits get their Heavy too.
    private static var hangar: [Rocket] = []
    private static func nextRocket() -> Rocket {
        if hangar.isEmpty { hangar = [.heavy, .falcon9, Bool.random() ? .dragon : .falcon9].shuffled() }
        return hangar.removeLast()
    }

    /// For the tests: whether two boosters have been given the same landing zone.
    var zoneShared: Bool { Set(boosters.map(\.zone)).count < boosters.count }

    /// The sky through a wide lens: how many rows up something `z` pixels above the ground is drawn, and how big.
    /// It's true to size for the first 60, then squeezed, so a rocket dwindles to a spark as it climbs and its trail
    /// arcs over, instead of leaving the top of the picture full size.
    private func lens(_ z: Float) -> (rows: Float, scale: Float) {
        z < 60 ? (z, 1) : (60 + 90 * log(1 + (z - 60) / 90), 1 / (1 + (z - 60) / 90))
    }

    /// Where the rocket's foot is `t` seconds after lift-off, and its size: straight up to clear the tower, then
    /// leaning over to the right as it gathers speed.
    private func ascent(_ t: Float) -> (x: Float, y: Float, scale: Float) {
        let z = t > 0 ? 0.65 * t * t * (1 + t / 40) : 0, (rows, scale) = lens(z)
        return (Float(padX) + 0.5 + 0.0094 * pow(max(z - 70, 0), 1.8) * scale, Float(mount) + rows, scale) // it leans once it's above the tower
    }

    /// Seconds from lift-off, negative through the count, while there's a rocket on the mount or on its way up.
    private var flightTime: Float? {
        pad.phase == .climb ? pad.t : pad.phase == .count ? -Float((pad.until - clock) / Self.knob(.launches)) : nil
    }

    /// Moves the Spaceport on through its round. A rocket rolls out of the hangar on its transporter, is stood up
    /// on the mount, fuels through a count and lifts off; its strongback is lowered and rolled back for the next.
    /// A minute later its booster comes back to a landing zone (a Falcon Heavy's two side boosters to both), and a
    /// crane comes for each and carries it away.
    private func launch(_ dt: Float) {
        let pace = Self.knob(.launches), rolled = Float(padX - hangarX - 34) // how far the transporter rolls, door to mount
        // Time in the hangar and the count run down at the pace Settings gives, so a change shows at once.
        if pad.phase == .hangar || pad.phase == .count, clock < pad.until { pad.until += Double(dt) * (1 - pace) }
        pad.t += dt
        switch pad.phase {
        case .hangar:
            if clock >= pad.until {
                pad.rocket = Self.nextRocket()
                pad.flown = Bool.random()
                (pad.phase, pad.t, pad.x) = (.rollOut, 0, 0)
            }
        case .rollOut:
            pad.x = min(pad.x + 3.5 * dt, rolled)
            if pad.x >= rolled { (pad.phase, pad.t) = (.raise, 0) }
        case .raise:
            if pad.t >= 18 { (pad.phase, pad.t, pad.until) = (.count, 0, clock + 70) }
        case .count:
            // Every booster needs a landing zone to come back to. If one from the last flight is still standing
            // on it, the count holds at ten seconds.
            let free = zones.indices.filter { zone in !boosters.contains { $0.zone == zone } }, need = pad.rocket == .heavy ? 2 : 1
            if free.count < need, pad.until - clock < 10 * pace { pad.until = clock + 10 * pace }
            if clock >= pad.until {
                (pad.phase, pad.t, liftoffAt, trailFrom) = (.climb, 0, clock, nil)
                movements += 1
                for (i, zone) in free.shuffled().prefix(need).sorted().enumerated() {
                    boosters.append(Booster(zone: zone, until: clock + 62 + Double(i) * 1.3))
                }
            }
        case .climb:
            if pad.t >= 21 { (pad.phase, pad.t) = (.rollBack, 0) } // out of sight, and the strongback is down
        case .rollBack:
            pad.x = max(pad.x - 5 * dt, 0)
            if pad.x <= 0 { (pad.phase, pad.until) = (.hangar, clock + .random(in: 50...110)) }
        }

        for i in boosters.indices {
            var b = boosters[i]
            switch b.phase {
            case .away:
                if clock >= b.until { (b.phase, b.z, b.v) = (.fall, 330, -34) }
            case .fall, .burn:
                if b.z <= 170 { b.phase = .burn }
                // The landing burn slows it at whatever rate stops it as it touches.
                if b.phase == .burn { b.v = min(b.v + b.v * b.v / (2 * max(b.z, 1)) * dt, -1.5) }
                b.z += b.v * dt
                if b.z <= 0 {
                    (b.phase, b.z, b.until) = (.landed, 0, clock + 14)
                    movements += 1
                    for _ in 0..<16 { dust(zone: b.zone) }
                }
            case .landed: break
            }
            boosters[i] = b
        }

        // The crane: in from the right for the booster nearest that edge, down with the hook, up a little, and away.
        let reach: Float = 33 // its hook hangs this far to its left
        switch crane.phase {
        case .away:
            if let zone = boosters.filter({ $0.phase == .landed && clock >= $0.until }).map(\.zone).max() {
                (crane.phase, crane.zone, crane.x) = (.driveIn, zone, Float(w) + 40)
            }
        case .driveIn:
            crane.x = max(crane.x - 5 * dt, Float(zones[crane.zone]) + reach)
            if crane.x <= Float(zones[crane.zone]) + reach { (crane.phase, crane.t) = (.hook, 0) }
        case .hook:
            crane.t += dt
            if crane.t >= 9 { crane.phase = .carry }
        case .carry:
            crane.x += 4 * dt
            if crane.x > Float(w) + 45 {
                boosters.removeAll { $0.zone == crane.zone }
                crane.phase = .away
            }
        }

        // Smoke moves in steps of a fifteenth of a second, as hand-drawn smoke would.
        smokeTime += dt
        let had = !plume.isEmpty, before = smokeTime
        while smokeTime >= 1 / 15 {
            smokeTime -= 1 / 15
            puff()
            for i in plume.indices {
                var p = plume[i]
                p.age += 1 / 15
                let drag = exp(Float(-1) / 15 / 2.6)
                p.vx *= drag
                p.vy = p.vy * drag + 0.06 * (p.r > 3 ? 1 : 0.3) // big clouds are warm, and rise
                let wind = 2.2 * (0.6 + 0.45 * sin(p.y / 31 + 1.3)) * min(1, p.age / 4) // it blows the way the clouds go, more at some heights
                p.x += (p.vx + wind) / 15
                p.y = max(p.y + p.vy / 15, Float(ground + 1))
                p.r = min(p.r + p.grow / 15, p.most)
                plume[i] = p
            }
            plume.removeAll { $0.age >= $0.life }
        }
        if smokeTime < before, had || !plume.isEmpty { smokeMoved = true }

        // The clock on our bank: the time to the next lift-off, or since the last for a minute and a half after it.
        let since = clock - liftoffAt, left: Double
        switch pad.phase {
        case .hangar: left = max(0, pad.until - clock) / pace + Double(rolled / 3.5) + 18 + 70 / pace
        case .rollOut: left = Double((rolled - pad.x) / 3.5) + 18 + 70 / pace
        case .raise: left = Double(18 - pad.t) + 70 / pace
        case .count: left = max(0, pad.until - clock) / pace
        case .climb, .rollBack: left = 0
        }
        let seconds = Int(since < 95 ? since : left.rounded(.up))
        let text = "T" + (since < 95 ? "+" : "-") + String(format: "%02d:%02d", min(seconds / 60, 99), seconds % 60)
        if text != counted {
            counted = text
            var px = Pixels(27, 5)
            for (i, figure) in text.enumerated() {
                for (row, bits) in (figures[figure] ?? []).enumerated() {
                    for bit in 0..<3 where bits & (4 >> bit) != 0 { px.plot(i * 4 + bit, 4 - row, rgb(255, 176, 60)) }
                }
            }
            countdown.texture = px.texture()
        }
    }

    /// Paints the Spaceport's layer once a frame's moving is done: the smoke if it has moved, then everything over
    /// it. It's apart from `update` so that a test can run the round through by `update` alone, and paint only now
    /// and then: the smoke is slow to paint in a debug build.
    override func didFinishUpdate() {
        guard city == .spaceport else { return }
        if smokeMoved {
            paintSmoke()
            (smokeMoved, smokeSteps) = (false, smokeSteps + 1)
        }
        paintLaunch()
    }

    /// One puff of smoke or steam.
    private func puff(_ x: Float, _ y: Float, _ vx: Float, _ vy: Float, _ r: Float, _ grow: Float, _ most: Float, _ life: Float) {
        plume.append(Puff(x: x, y: y, vx: vx, vy: vy, r: r, grow: grow, most: most, life: life))
    }

    /// Dust and smoke thrown out along the ground by a booster's flame as it comes down on a landing zone.
    private func dust(zone: Int) {
        let side: Float = Bool.random() ? 1 : -1
        puff(Float(zones[zone]) + side * .random(in: 2...20), Float(ground) + .random(in: 1...4), side * .random(in: 4...18), .random(in: 0...4),
             .random(in: 1.5...3), 0.8, .random(in: 3...6), 9)
    }

    /// Lets off the smoke of a fifteenth of a second (puffs let off together live about as long as each other, or
    /// the last of a cloud to go are left hanging as round dots): cold vapour from a fuelled rocket; at lift-off the deluge's
    /// steam, out of both ends of the flame trench and up round the mount; the trail a climbing rocket leaves; and
    /// the dust under a landing booster.
    private func puff() {
        let x = Float(padX) + 0.5, foot = Float(mount)
        if let t = flightTime {
            if t < -3, Int.random(in: 0..<6) == 0 {
                puff(x - 3, foot + .random(in: 28...33), .random(in: -3 ... -2), -0.6, 1, 0.25, 2.4, 5)
            }
            if t > -2.6, t < 7.5 {
                for side in [-1, 1] as [Float] {
                    for _ in 0..<(t < 5 ? 2 : 1) {
                        let big = Int.random(in: 0..<20) < 7
                        puff(x + side * .random(in: 6...12), Float(ground) + .random(in: 1...5), side * .random(in: 8...34) * (side > 0 ? 1.15 : 0.9),
                             .random(in: 0...9), .random(in: 2...3.2), .random(in: 0.9...1.8), big ? .random(in: 8...12) : .random(in: 4...7), .random(in: 16...21))
                    }
                }
                if Int.random(in: 0..<5) < 3 { puff(x + .random(in: -6...6), foot, .random(in: -6...6), .random(in: 3...10), 2, 1.2, .random(in: 4...7), 15) }
            }
            if t > 0.5 { // the trail, laid from where the flame ended a moment ago to where it ends now
                // That is back along the rocket's own axis, not straight below it: once it leans they aren't the same place.
                let now = ascent(t), next = ascent(t + 0.2), way = SIMD2(next.x - now.x, next.y - now.y)
                let back = -way / max((way * way).sum().squareRoot(), 0.001), end = SIMD2(now.x, now.y) + back * 30 * now.scale
                if let from = trailFrom, end.y < Float(h) + 8 {
                    let steps = max(1, Int(((end - from) * (end - from)).sum().squareRoot() / 1.5))
                    for i in 0..<steps {
                        let at = from + (end - from) * ((Float(i) + .random(in: 0..<1)) / Float(steps))
                        guard at.y > foot + 1 else { continue }
                        let blown = back * (Float.random(in: 1...5) * now.scale)
                        puff(at.x + .random(in: -0.7...0.7), at.y, blown.x + .random(in: -1.2...1.2), blown.y,
                             1.4 * now.scale + 1, 0.24, (3.2 * now.scale + 2.3) * .random(in: 0.85...1.2), .random(in: 52...60) * (0.55 + 0.45 * now.scale)) // the far end goes first
                    }
                }
                trailFrom = end
            }
        }
        for b in boosters where b.phase == .burn && b.z < 45 {
            for _ in 0..<(b.z < 12 ? 2 : 1) { dust(zone: b.zone) }
        }
    }

    /// Paints the smoke into its own canvas. Every puff adds a round hump to a field of density; where that is
    /// thick enough there is cloud, drawn in three flat tones: a rim lit from the Sun's side, the body, and a
    /// shaded underside. It takes the light it is in: the Sun's after sunset if it's high enough to be above the
    /// Earth's shadow, a flame's near one, the pad's floodlights by night.
    private func paintSmoke() {
        let rows = smoke.h, base = waterRows, w = w
        if density.count != w * rows { density = Array(repeating: 0, count: w * rows) }
        var (x0, x1, y0, y1) = (w, -1, rows, -1)
        density.withUnsafeMutableBufferPointer { field in
            field.update(repeating: 0)
            for p in plume {
                let k = min(1, p.age / 0.4) * (1 - smoothstep(0.55, 1, p.age / p.life)), inverse = 1 / (p.r * p.r)
                let left = max(Int(p.x - p.r) - 1, 0), right = min(Int(p.x + p.r) + 1, w - 1)
                let low = max(Int(p.y - p.r) - 1 - base, 0), high = min(Int(p.y + p.r) + 1 - base, rows - 1)
                guard left <= right, low <= high else { continue }
                for y in low...high {
                    let dy = Float(y + base) + 0.5 - p.y
                    var i = y * w + left, dx = Float(left) + 0.5 - p.x
                    for _ in left...right {
                        let d = 1 - (dx * dx + dy * dy) * inverse
                        if d > 0 { field[i] += d * k }
                        (i, dx) = (i + 1, dx + 1)
                    }
                }
                (x0, x1, y0, y1) = (min(x0, left), max(x1, right), min(y0, low), max(y1, high))
            }
        }
        smoke.rgba.withUnsafeMutableBufferPointer { $0.update(repeating: 0) }
        guard x0 <= x1, y0 <= y1 else { return }

        let steam = rgb(246, 246, 248), side = (keyRight - keyLeft).sum() >= 0 ? 1 : -1
        let tones = [pointwiseMin(steam * (ambient * 1.12 + keyTop * 0.5 + (keyRight + keyLeft) * 0.7), .one),
                     pointwiseMin(steam * (ambient * 0.98 + keyTop * 0.22), .one),
                     steam * ambient * 0.88 * RGB(0.92, 0.95, 1)]
        // After sunset the Sun still reaches what is high enough: the Earth's shadow climbs as the Sun sinks.
        let el = Float(sunAt.elevation), twilight = smoothstep(3, 0, el) * smoothstep(-11, -7, el)
        let shadow = Float(ground) + max(0, -el - 0.2) * 26
        let sunlit = [rgb(255, 232, 196), rgb(255, 186, 140), rgb(190, 120, 128)]
        let fires = flames()
        let flood = pad.phase == .count || pad.phase == .raise ? night : 0, floodlit: [Float] = [1, 0.9, 0.72]
        density.withUnsafeBufferPointer { field in
            smoke.rgba.withUnsafeMutableBufferPointer { out in
                for y in y0...y1 {
                    let up = twilight * smoothstep(shadow - 14, shadow + 14, Float(y + base))
                    let lights = (0..<3).map { mix(tones[$0], sunlit[$0], up) }
                    for x in x0...x1 {
                        let d = field[y * w + x]
                        guard d >= 0.14 else { continue }
                        // A rim toward the light where the cloud is much thinner that way, shade where it is much
                        // thinner the other way: by the ratio, so the tones follow a thick cloud's lobes without
                        // half of it falling into shade.
                        let tx = min(max(x + 2 * side, 0), w - 1), ax = min(max(x - 2 * side, 0), w - 1)
                        let toward = y + 2 < rows ? field[(y + 2) * w + tx] : 0, away = y >= 2 ? field[(y - 2) * w + ax] : 0
                        let tone = 1 + d > 1.22 * (1 + toward) ? 0 : 1 + d > 1.3 * (1 + away) ? 2 : 1
                        var c = lights[tone]
                        for fire in fires {
                            let dx = Float(x) - fire.x, dy = (Float(y + base) - fire.y) * 1.2
                            let heat = (1 - (dx * dx + dy * dy).squareRoot() / 46) * fire.power
                            if heat > 0 { c = mix(c, rgb(255, 168, 84) * (0.75 + 0.25 * c.sum() / 3), heat) }
                        }
                        if flood > 0 {
                            let dx = Float(x - padX), dy = Float(y + base - padDeck - 20) * 0.8
                            let near = (1 - (dx * dx + dy * dy).squareRoot() / 40) * flood
                            if near > 0 { c = mix(c, rgb(250, 246, 236) * floodlit[tone], near) }
                        }
                        let a: Float = d < 0.3 ? 0.4 : d < 0.5 ? 0.72 : 0.95, i = (y * w + x) * 4, k = a * 255
                        (out[i], out[i + 1], out[i + 2], out[i + 3]) = (UInt8(min(c.x, 1) * k), UInt8(min(c.y, 1) * k), UInt8(min(c.z, 1) * k), UInt8(k))
                    }
                }
            }
        }
    }

    /// The flames burning now: where each begins, which way its rocket leans, the size it's drawn at, how long and
    /// wide it is, and how strongly it lights the smoke round it.
    private func flames() -> [(x: Float, y: Float, angle: Float, scale: Float, length: Float, wide: Float, power: Float)] {
        let k = 0.35 + 0.65 * night
        var fires: [(x: Float, y: Float, angle: Float, scale: Float, length: Float, wide: Float, power: Float)] = []
        if let t = flightTime, t > -2.6 {
            let at = ascent(t), next = ascent(t + 0.2), z = at.y - Float(mount)
            if at.y < Float(h) + 40 {
                fires.append((at.x, at.y, atan2(next.x - at.x, next.y - at.y), at.scale, 36 * smoothstep(-2.6, -0.4, t),
                              pad.rocket == .heavy ? 7 : 3, min(1, k * (z < 110 ? 1.2 : 0.8)) * max(0.2, 1 - z / 160)))
            }
        }
        for b in boosters where b.phase == .burn {
            let (rows, scale) = lens(b.z)
            fires.append((Float(zones[b.zone]) + 0.5, Float(ground + 1) + rows + scale, 0, scale, 18, 2, 0.9 * k))
        }
        return fires
    }

    /// Paints the Spaceport's moving things into their layer, when any of them has moved a pixel: the smoke, the
    /// glare round each flame, the strongback, the rocket and its flame, the boosters and the crane, each in the
    /// light it stands in.
    private func paintLaunch() {
        guard let texture = launchTexture else { return }
        let fires = flames(), flicker = fires.isEmpty ? 0 : Int(clock * 12)
        // Where the strongback is, how far it leans (0 upright, a quarter turn back when it lies on its wheels),
        // and where a rocket on it has its foot.
        var hinge = SIMD2(Float(padX) + 0.5, Float(mount)), lean: Float = 0
        let lying = -Float.pi / 2
        switch pad.phase {
        case .hangar: break
        case .rollOut, .rollBack:
            // The ramp lifts it 6 rows over 30 columns; it rides on wheels at its foot and 40 columns behind.
            func track(_ x: Float) -> Float { Float(ground) + 6 * min(max((x - Float(padX - 55)) / 30, 0), 1) }
            let x = Float(hangarX + 34) + pad.x
            hinge = SIMD2(x.rounded(.down) + 0.5, (track(x) + 4).rounded(.down))
            lean = lying - atan2(track(x) - track(x - 40), 40)
        case .raise: lean = lying * (1 - smoothstep(0, 18, pad.t))
        case .count: lean = (flightTime ?? 0) > -20 ? -0.052 : 0 // it leans clear for the last of the count
        case .climb: lean = pad.t < 10 ? mix(-0.052, -0.66, smoothstep(0, 1.5, pad.t)) : mix(-0.66, lying, smoothstep(10, 21, pad.t))
        }
        let flying = pad.phase == .climb ? ascent(pad.t) : nil
        var shown = [smokeSteps, flicker, pad.phase.rawValue, Int(hinge.x), Int(hinge.y), Int(lean * 80), Int(crane.x), Int(crane.t * 2), crane.phase.rawValue]
        if let flying { shown += [Int(flying.x), Int(flying.y), Int(flying.scale * 60)] }
        for b in boosters { shown += [b.phase.rawValue, Int(lens(b.z).rows), Int(lens(b.z).scale * 40)] }
        guard shown != launchShown else { return }
        launchShown = shown

        var px = smoke
        for fire in fires where fire.length > 4 { // the glare round a flame
            let k = 0.35 + 0.65 * night, wide = 0.5 + fire.scale / 2
            for (r, a) in [(30, 0.045), (20, 0.07), (11, 0.11), (5, 0.16)] as [(Float, Float)] {
                let reach = Int(r * wide), cx = Int(fire.x), cy = Int(fire.y - 12 * fire.scale)
                for dy in -reach...reach { for dx in -reach...reach where dx * dx + dy * dy <= reach * reach { px.plot(cx + dx, cy + dy, rgb(255, 150, 70), a * k) } }
            }
        }
        let steel = mix(mix(lit(rgb(110, 114, 124), .zero), hazeColour, 0.12), rgb(22, 22, 32), night * 0.8)
        let dark = mix(lit(rgb(50, 50, 56), .zero), rgb(14, 14, 20), night * 0.7)
        let art = pad.rocket.art, soot = pad.flown && pad.rocket != .dragon ? 18 : 0
        if pad.phase != .hangar {
            px.clip = hangarX + 34..<w // what is still inside the hangar's door doesn't show
            // The strongback: a lattice spine beside the rocket, with arms out to hold it.
            let (ax, ay) = (sin(lean), cos(lean)), (qx, qy) = (cos(lean), -sin(lean)), off: Float = pad.rocket == .heavy ? -6 : -4
            let rolling = pad.phase == .rollOut || pad.phase == .rollBack
            for i in 0..<39 {
                let f = Float(i), sx = hinge.x + ax * f + qx * off, sy = hinge.y + ay * f + qy * off
                px.plot(Int(sx.rounded(.down)), Int(sy.rounded(.down)), steel)
                if i % 2 == 0 { px.plot(Int((sx - qx).rounded(.down)), Int((sy - qy).rounded(.down)), steel, 0.85) }
                if [15, 35, 36].contains(i) { for k in 1...2 { px.plot(Int((sx + qx * Float(k)).rounded(.down)), Int((sy + qy * Float(k)).rounded(.down)), steel) } }
                if rolling, i % 6 < 2 { px.plot(Int((sx - qx * 2).rounded(.down)), Int((sy - qy * 2).rounded(.down)), dark) } // its wheels
            }
            if pad.phase != .climb, pad.phase != .rollBack {
                let floodlit: Float = pad.phase == .rollOut ? 0 : 1
                stamp(art, into: &px, x: hinge.x, y: hinge.y, angle: pad.phase == .count ? 0 : lean, paint: rocketPaint(flood: floodlit), soot: soot)
            }
            px.clip = 0..<w
        }
        for (i, fire) in fires.enumerated() { // flames flicker, a dozen times a second
            let jitter = 0.9 + 0.2 * Float((flicker &+ i &* 7) &* 2_654_435_761 % 7) / 6
            flame(into: &px, x: fire.x, y: fire.y, angle: fire.angle, scale: fire.scale, length: fire.length * jitter, wide: fire.wide)
        }
        if let flying, let fire = fires.first, flying.y < Float(h) + 40 {
            stamp(art, into: &px, x: flying.x, y: flying.y, angle: fire.angle, scale: flying.scale, paint: rocketPaint(flood: 0), soot: soot, heat: 0.3 + 0.5 * night)
        }
        // The boosters: falling, burning down to the pad on their legs, standing there, or hanging from the crane's hook.
        let hookX = Int(crane.x.rounded(.down)) - 33, lifted = crane.phase == .hook ? max(0, min(crane.t - 5, 4)) : 4
        for b in boosters where b.phase != .away {
            let held = crane.phase.rawValue >= Crane.Phase.hook.rawValue && crane.zone == b.zone
            let (rows, scale) = lens(b.z), flying = b.phase == .fall || b.phase == .burn
            let x = held ? Float(hookX) + 0.5 : Float(zones[b.zone]) + 0.5, y = Float(ground + 1) + (held ? lifted.rounded(.down) : rows)
            let legs = flying ? b.z < 26 : !(held && crane.phase == .carry)
            stamp(legs ? landedArt : fallingArt, into: &px, x: x, y: y, scale: scale, paint: rocketPaint(flood: 0), soot: 18, heat: b.phase == .burn ? 0.85 : 0)
        }
        if crane.phase != .away {
            // The crane: a crawler with its boom up over the landing zone, and the hook on its line.
            let x = Int(crane.x.rounded(.down)), f = waterRows
            let paint = mix(mix(lit(rgb(226, 170, 44), keyFront), hazeColour, 0.15), rgb(40, 34, 30), night * 0.7)
            px.fill(x - 6, f + 1, 13, 2, dark)
            px.fill(x - 5, f + 3, 10, 4, paint)
            px.fill(x + 2, f + 5, 3, 3, paint * 0.8)
            px.fill(x + 3, f + 6, 2, 1, dark)
            px.fill(x + 4, f + 3, 3, 3, dark)
            px.line(x - 3, f + 6, hookX, f + 53, paint)
            px.line(x - 2, f + 6, hookX + 1, f + 53, paint * 0.75, every: 2)
            px.line(x + 3, f + 9, hookX, f + 53, dark, 0.7)
            px.fill(x + 3, f + 7, 1, 3, dark)
            // The hook hangs high until the crane is in place, comes down to the booster's top, and goes up with it.
            let drop = crane.phase == .driveIn ? 6 : crane.phase == .hook ? Int(mix(6, 18, crane.t / 5)) - Int(lifted) : 14
            px.line(hookX, f + 53, hookX, f + 53 - drop, dark, 0.9)
            px.fill(hookX - 1, f + 52 - drop, 3, 2, dark)
        }

        let bytes = px.rgba
        texture.modifyPixelData { data, length in
            bytes.withUnsafeBytes { data?.copyMemory(from: $0.baseAddress!, byteCount: min(length, bytes.count)) }
        }
    }

    /// White paint in the light a rocket stands in, for its lit side, its face and its shaded side; then its black,
    /// and its engine bells. On the pad after dark (`flood`) the floodlights have it.
    private func rocketPaint(flood: Float) -> [RGB] {
        let white = rgb(238, 238, 234), sunRight = (keyRight - keyLeft).sum() >= 0, lamp = rgb(255, 248, 232), on = flood * night
        let left = lit(white, keyLeft + keyFront, shade: sunRight ? 0.86 : 1.05) * (sunRight ? 0.86 : 1)
        let right = lit(white, keyRight + keyFront, shade: sunRight ? 1.05 : 0.86) * (sunRight ? 1 : 0.86)
        return [mix(left, lamp, on), mix(lit(white, keyFront), lamp * 0.92, on), mix(right, lamp * 0.7, on),
                mix(lit(rgb(34, 34, 38), .zero), rgb(20, 20, 26), 0.3), lit(rgb(60, 58, 60), .zero)]
    }

    /// Paints a rocket with the middle of its foot at (`x`, `y`), leaning `angle` radians right of upright, at
    /// `scale`. Each pixel under it looks up the art it falls on, so it turns and shrinks without gaps. A booster
    /// that has flown is sooty toward its foot (`soot`: for how many rows up), and takes a flame's light there (`heat`).
    private func stamp(_ art: [[UInt8]], into px: inout Bytes, x: Float, y: Float, angle: Float = 0, scale: Float = 1,
                       paint: [RGB], soot: Int = 0, heat: Float = 0) {
        let rows = art.count, wide = art[0].count, reach = Int(Float(rows + wide) * scale) + 2
        let (ax, ay) = (sin(angle), cos(angle)), (qx, qy) = (cos(angle), -sin(angle)), glare = rgb(255, 170, 90)
        for py in Int(y) - reach...Int(y) + reach {
            for column in Int(x) - reach...Int(x) + reach {
                let rx = Float(column) + 0.5 - x, ry = Float(py) + 0.5 - y
                let along = (rx * ax + ry * ay) / scale, across = (rx * qx + ry * qy) / scale + Float(wide) / 2
                guard along >= 0, across >= 0, Int(along) < rows, Int(across) < wide else { continue }
                let j = Int(along), tone = Int(art[rows - 1 - j][Int(across)])
                guard tone < paint.count else { continue }
                var c = paint[tone]
                if tone < 3, j < soot { c *= mix(0.5, 0.92, Float(j) / Float(soot)) }
                if heat > 0, j < 14 { c = mix(c, glare * (0.55 + 0.45 * c.sum() / 3), heat * (1 - Float(j) / 14)) }
                px.plot(column, py, c)
            }
        }
    }

    /// A flame from (`x`, `y`) back along a rocket's axis: white-hot down its middle, orange outside and toward its tip.
    private func flame(into px: inout Bytes, x: Float, y: Float, angle: Float, scale: Float, length: Float, wide: Float) {
        let (ax, ay) = (-sin(angle), -cos(angle)), (qx, qy) = (cos(angle), -sin(angle))
        let n = max(2, length * scale), w0 = max(1, wide * scale), reach = Int(n + w0) + 3
        guard length > 1 else { return }
        for py in Int(y) - reach...Int(y) + reach {
            for column in Int(x) - reach...Int(x) + reach {
                let rx = Float(column) + 0.5 - x, ry = Float(py) + 0.5 - y
                let along = rx * ax + ry * ay, across = abs(rx * qx + ry * qy)
                guard along >= 0, along < n else { continue }
                let u = along / n, half = (w0 / 2 + scale * sin(min(u * 4, 1) * .pi / 2)) * (1 - pow(u, 1.5)) + (u < 0.92 ? 0.35 : 0)
                guard across <= half else { continue }
                let hot = across < half * (0.62 - 0.5 * u) || (u < 0.25 && across < half - 0.9)
                px.plot(column, py, hot ? rgb(255, 252, 232) : mix(rgb(255, 220, 120), rgb(255, 120, 44), u * 1.15 + (across > half - 0.8 ? 0.25 : 0)))
            }
        }
        }
}

// MARK: - Supporting types

private enum Roof: CaseIterable { case plain, ledge, setback, tank, antenna }

/// The cities Settings can pick, in the menu's order. The pick is stored as its index, so add new ones at the end.
private enum City: Int, CaseIterable {
    case waterfront, foothills, bridge, hillside, overlook, airport, spaceport
    var name: String { ["Waterfront", "Foothills", "Long Bridge", "Hillside Town", "Overlook", "Airport", "Spaceport"][rawValue] }
}

/// What a building is: a windowless tower in the haze, a stone tower with setbacks, a glass curtain wall, a brick
/// walk-up over a shop, or a concrete slab with ribbon windows; in Hillside Town a house, or the cypress in a gap
/// between two; or one of the Overlook's buildings seen from above.
private enum Kind { case haze, deco, glass, brick, slab, house, cypress, block }

private struct Building {
    var x: Int, width: Int, height: Int
    var colour: RGB
    var far: Bool
    var floor: Int, pitch: Int // window spacing, vertical and horizontal
    var roof: Roof
    var seed: UInt64
    var kind: Kind
    var base: Int? // the row it stands on, for a house up a hillside; the ground otherwise
}

private struct Car {
    let node: SKSpriteNode
    let beam: SKSpriteNode
    let lane: Int // 0 near, heading right; 1 far, heading left
    var look = 0
    var x: Float = 0, cruise: Float = 0, speed: Float = 0, length: Float = 16
}

/// The Spaceport's launch pad, and where its round has got to.
private struct Pad {
    /// In the hangar; rolling out to the pad on its transporter; being stood up; fuelling, through the count;
    /// climbing away, while the strongback is lowered behind it; and that rolling back to the hangar.
    enum Phase: Int { case hangar, rollOut, raise, count, climb, rollBack }
    var phase = Phase.hangar
    var until: TimeInterval = 0 // when the wait in the hangar, or the count, ends
    var t: Float = 0            // seconds into this phase
    var x: Float = 0            // how far the transporter has rolled from the hangar's door
    var rocket = Rocket.falcon9, flown = false // a booster that has flown before is sooty
}

/// The rockets the Spaceport flies: a Falcon 9 under a fairing or a capsule, or a Falcon Heavy.
private enum Rocket {
    case falcon9, dragon, heavy
    var art: [[UInt8]] { self == .falcon9 ? falconArt : self == .dragon ? dragonArt : heavyArt }
}

/// A booster on its way back from a flight, or standing on its landing zone.
private struct Booster {
    /// Out of sight after lift-off; falling; slowing on its landing burn; and down, until the crane takes it away.
    enum Phase: Int { case away, fall, burn, landed }
    var phase = Phase.away
    var zone: Int
    var until: TimeInterval // when it comes back into sight, or when the crane may come for it
    var z: Float = 0, v: Float = 0 // its height over the landing zone, and how fast it is falling
}

/// The crane that carries landed boosters away.
private struct Crane {
    /// Off to the right; driving in; lowering its hook and lifting; and carrying a booster off.
    enum Phase: Int { case away, driveIn, hook, carry }
    var phase = Phase.away
    var zone = 0
    var x: Float = 0, t: Float = 0
}

/// A puff of the Spaceport's smoke or steam: where it is and is going, its size and how big it will get, and its age.
private struct Puff {
    var x: Float, y: Float, vx: Float, vy: Float
    var r: Float, grow: Float, most: Float
    var age: Float = 0, life: Float
}

/// One of the Airport's aircraft, and where it is in its round.
@MainActor private struct Flight {
    /// Away; coming down the approach; rolling out; off the runway's end and round to the taxiway, out of sight;
    /// taxiing in; on its stand; taxiing out; round to the runway's other end; lining up; rolling and climbing away.
    enum Phase: Int { case away, approach, rollout, vacated, taxiIn, parked, taxiOut, crossing, lineUp, takeoff }
    let node = SKSpriteNode()
    let beacon = SKSpriteNode(color: NSColor(red: 1, green: 0.2, blue: 0.15, alpha: 1), size: CGSize(width: 1, height: 1)) // flashes while the engines run
    let strobe = SKSpriteNode(color: .white, size: CGSize(width: 1, height: 1)) // flashes on the runway and in the air
    let wingtip = SKSpriteNode(color: .green, size: CGSize(width: 1, height: 1)) // green on the right wing, red on the left
    let lamp = SKSpriteNode() // the landing light's glare
    var rows = airliner, accent = RGB.one
    var phase = Phase.away, until: TimeInterval = 0
    var way: Float = 1 // the way it lands and takes off: 1 to the right. It taxis the other way.
    var x: Float = 0, height: Float = 0, speed: Float = 0
    var slope: Float = 0, gear = true // how far its nose is up, in pixels per pixel along; whether its wheels are down
    var stand = 0, berth: Float = 0   // how far it has pulled off the taxiway onto its stand, 0…1
    var wheels = 0, below = 0         // the column its main wheels are in, and how far its picture reaches below them
    var look: [Int] = []              // what it was last dressed for

    var onRunway: Bool { [.approach, .rollout, .lineUp, .takeoff].contains(phase) }
    var taxiing: Bool { phase == .taxiIn || phase == .taxiOut }
    var facing: Float { taxiing || phase == .parked ? -way : way }
}

@MainActor private struct Cloud {
    let node = SKSpriteNode()
    let mask: [[Bool]] // rows from the bottom
    var x: Float
    let speed: Float

    /// Two-tone pixel cloud: shaded base, lit body, highlighted top edge.
    func texture(light: RGB, shade: RGB) -> SKTexture {
        var px = Pixels(mask[0].count, mask.count)
        for y in mask.indices {
            for x in mask[y].indices where mask[y][x] {
                let topEdge = y + 1 == mask.count || !mask[y + 1][x]
                px.plot(x, y, topEdge ? pointwiseMin(light * 1.05, .one) : y <= 3 ? shade : light)
            }
        }
        return px.texture()
    }
}

// The Spaceport's rockets, drawn standing, from the nose down: white paint on the lit side (l), the face (w) and
// the shaded side (s), black (K) and engine bells (n). About a metre and a half to the pixel, and half as slender
// as the real ones, which would be two pixels wide. `bytes` turns the letters into the numbers of `rocketPaint`'s
// five paints, and anything else into 255, for nothing.
private func tall(_ parts: [(String, Int)]) -> [String] { parts.flatMap { Array(repeating: $0.0, count: $0.1) } }
private func bytes(_ rows: [String]) -> [[UInt8]] { rows.map { $0.utf8.map { UInt8(Array("lwsKn".utf8).firstIndex(of: $0) ?? 255) } } }
private let falconRows = tall([("..w..", 1), (".lws.", 2), ("lwwss", 7), (".lws.", 5), (".KKK.", 3), (".lws.", 21), (".KwK.", 5), (".KKK.", 2)])
private let falconArt = bytes(falconRows)
private let dragonArt = bytes(tall([("..w..", 1), (".lws.", 2), (".lKs.", 3)]) + falconRows[10...])
/// A Falcon Heavy: the same rocket between two more first stages under nose cones.
private let heavyArt: [[UInt8]] = {
    let side = [".w.", ".w.", "lws", "lws"] + falconRows[18...].map { String($0.dropFirst().prefix(3)) }
    return bytes(falconRows.enumerated().map { i, row in
        let j = i - (falconRows.count - side.count), core = j >= 0 ? side[j] : "..."
        return row.first == "." ? core + row.dropFirst().prefix(3) + core : core.prefix(2) + row + core.dropFirst()
    })
}()
/// A booster by itself, coming home: its grid fins out, and its legs still folded or down.
private let fallingArt: [[UInt8]] = {
    var rows = falconRows[15...].map { "..." + $0 + "..." }
    rows[1] = "...KKKKK..."
    return bytes(rows)
}()
private let landedArt: [[UInt8]] = fallingArt.dropLast(6) + bytes(["....KwK....", "....KwK....", "...KlwsK...", "..K.lws.K..", ".K..KKK..K.", "K...n.n...K"])

/// The countdown clock's figures, three pixels by five, as rows of bits from the top.
private let figures: [Character: [UInt8]] = [
    "0": [7, 5, 5, 5, 7], "1": [2, 6, 2, 2, 7], "2": [7, 1, 7, 4, 7], "3": [7, 1, 7, 1, 7], "4": [5, 5, 7, 1, 1], "5": [7, 4, 7, 1, 7],
    "6": [7, 4, 7, 5, 7], "7": [7, 1, 1, 1, 1], "8": [7, 5, 7, 5, 7], "9": [7, 5, 7, 1, 7], "T": [7, 2, 2, 2, 2], "-": [0, 0, 7, 0, 0],
    "+": [0, 2, 7, 2, 0], ":": [0, 2, 0, 2, 0],
]

// The people on the Spaceport's bank, in silhouette, and the crown of its palm.
private let person = [".##.", ".##.", "####", "####", ".##.", ".##.", ".#.#", ".#.#"]
private let pointing = [".##..#", ".##.#.", "####..", "###...", ".##...", ".##...", ".#.#..", ".#.#.."]
private let child = ["##", "##", "##", "##", "##"]
private let palm = [
    "......#...#.......",
    "...##..#.#..###...",
    "..#..#.###.#...#..",
    ".#..########....#.",
    "#..#.######.##...#",
    "#.#..######...#..#",
    "..#.#.####.#...#..",
    ".#..#..##...#..#..",
    ".#.....##....#....",
    ".......##.........",
]

private let sedan = [
    "....######......",
    "...#ww#wwww#....",
    "..#www#wwwww#...",
    "BBBBBBBBBBBBBBBh",
    "tBBBBBBBBBBBBBBB",
    "ddooodddddooodd.",
    "..ooo.....ooo...",
]

private let freighter = [
    "....l.........................",
    "...WWWW.......................",
    "...wWwW.......................",
    "...WWWW..aaaa.bbbb.dddd.aaaa..",
    "...wWwW..aaaa.bbbb.dddd.aaaa..",
    "HHHHHHHHHHHHHHHHHHHHHHHHHHHHHH",
    ".HHHHHHHHHHHHHHHHHHHHHHHHHHHH.",
    "..rrrrrrrrrrrrrrrrrrrrrrrrrr..",
]

private let fishingBoat = [
    "....m.......",
    "....m.......",
    "...ccc......",
    "...cwc......",
    "hhhhhhhhhhhh",
    ".HHHHHHHHHH.",
    "..HHHHHHHH..",
]

private let sailboat = [
    "....m.....",
    "....ms....",
    "....mss...",
    "....msss..",
    "....m.....",
    "hhhhhhhhhh",
    ".HHHHHHHH.",
]

private let bus = [
    ".BBBBBBBBBBBBBBBBBBBBBBBB.",
    "BBBBBBBBBBBBBBBBBBBBBBBBBB",
    "BWWWBWWWBWWWBWWWBWWWBwwwwB",
    "BWWWBWWWBWWWBWWWBWWWBwwwwB",
    "BBBBBBBBBBBBBBBBBBBBBBBBBB",
    "BBBBBBBBBBBBBBBBBBBBBBBBBh",
    "tBBBBBBBBBBBBBBBBBBBBBBBBB",
    "dddddddddddddddddddddddddd",
    "ddoooddddddddddddddooodddd",
    "..ooo..............ooo....",
]

// The Airport's aircraft, nose to the right. T is the fin and c the stripe along the side, both in the airline's
// colour; w the cabin's windows and k the flight deck's; S and s the wing; e an engine; l and o legs and wheels.
private let airliner = [
    ".TTT......................................",
    ".TTTT.....................................",
    ".TTTTT....................................",
    "..TTTTT...................................",
    "..TTTTTT..................................",
    "...TTTTTT.................................",
    "...TTTTTTTT...............................",
    "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW......",
    "hhhhhWWwWwwwwwwwwwWwwwwwwwwWwwwwwwWWkkW...",
    "..WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW.",
    ".....ccccccccSSSSSSSSSccccccccccccccccccc.",
    ".........ggggggggsssssssssgggggggggggg....",
    "..................ll..eeeeeE.......l......",
    ".................ooo...............o......",
]

private let turboprop = [
    "hhhhh.........................",
    "..TT..........................",
    "..TTT.........................",
    "...TTT......SSSSSSSSS.........",
    "...TTTT......eeeeeeeEp........",
    "WWWWWWWWWWWWWWWWWWWWWpWWW.....",
    ".WWWwwwwwwwwwwwwwwwwwpwwWkkW..",
    "...WWWWWWWWWWWWWWWWWWpWWWWWWW.",
    ".....cccccccccccccccccccccccc.",
    ".......ggggggggggggggpggggg...",
    ".............oo..........o....",
]

private let widebody = [
    "..TTT.......................................................",
    "..TTTT......................................................",
    "..TTTTT.....................................................",
    "...TTTTT....................................................",
    "...TTTTTT...................................................",
    "....TTTTTT..................................................",
    "....TTTTTTT.................................................",
    "....TTTTTTTT................................................",
    ".....TTTTTTTTT..............................................",
    ".WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW.......",
    "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW.....",
    "hhhhhhhhWwwWwwwwwwwwwwWwwwwwwwwwwwwwWwwwwwwwwwwwwWwwwwWkkkW.",
    "...WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW",
    ".....WWWWWWWWWWWWWWSSSSSSSSSSSSWWWWWWWWWWWWWWWWWWWWWWWWWWWWW",
    "........ccccccccccccccSSSSSSSSSSSScccccccccccccccccccccccc..",
    "............ggggggggggggggsssssssssssgggggggggggggggggg.....",
    "........................ll.....eeeeeeeE............l........",
    ".......................oooo....eeeeeeeE............o........",
    ".......................oooo.................................",
]

// MARK: - Pixel canvas

private typealias RGB = SIMD3<Float>

private func rgb(_ r: Int, _ g: Int, _ b: Int) -> RGB { RGB(Float(r), Float(g), Float(b)) / 255 }
private func mix(_ a: RGB, _ b: RGB, _ t: Float) -> RGB { a + (b - a) * min(max(t, 0), 1) }
private func mix(_ a: Float, _ b: Float, _ t: Float) -> Float { a + (b - a) * min(max(t, 0), 1) }
private func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
    let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
    return t * t * (3 - 2 * t)
}

/// 4×4 ordered-dither threshold in 0..<1, for banded pixel-art gradients.
private func bayer(_ x: Int, _ y: Int) -> Float {
    let matrix: [Float] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
    return (matrix[(y & 3) * 4 + (x & 3)] + 0.5) / 16
}

/// Pixel art from rows of characters, top row first; characters missing from `palette` are transparent.
private func picture(_ rows: [String], _ palette: [Character: RGB]) -> Pixels {
    var px = Pixels(rows[0].count, rows.count)
    for (r, row) in rows.enumerated() {
        for (x, ch) in row.enumerated() { if let c = palette[ch] { px.plot(x, rows.count - 1 - r, c) } }
    }
    return px
}

private func art(_ rows: [String], _ palette: [Character: RGB]) -> SKTexture { picture(rows, palette).texture() }

/// A small straight-alpha RGBA canvas, origin bottom-left like SpriteKit, that becomes a nearest-filtered texture.
private struct Pixels {
    let w: Int, h: Int
    private var rgba: [SIMD4<Float>]

    init(_ w: Int, _ h: Int) {
        self.w = w
        self.h = h
        rgba = Array(repeating: .zero, count: w * h)
    }

    mutating func plot(_ x: Int, _ y: Int, _ c: RGB, _ a: Float = 1) {
        guard x >= 0, y >= 0, x < w, y < h, a > 0 else { return }
        let i = y * w + x, below = rgba[i]
        let alpha = a + below.w * (1 - a)
        let colour = (c * a + RGB(below.x, below.y, below.z) * below.w * (1 - a)) / alpha
        rgba[i] = SIMD4(colour, alpha)
    }

    mutating func fill(_ x: Int, _ y: Int, _ width: Int, _ height: Int, _ c: RGB, _ a: Float = 1) {
        for yy in y..<y + max(height, 0) { for xx in x..<x + max(width, 0) { plot(xx, yy, c, a) } } // plot clips
    }

    /// Paints another canvas onto this one with its bottom left at (`x`, `y`), mirrored left to right if `flipped`.
    mutating func draw(_ other: Pixels, x: Int, y: Int, flipped: Bool = false) {
        for j in 0..<other.h {
            for i in 0..<other.w {
                let p = other.rgba[j * other.w + i]
                plot(x + (flipped ? other.w - 1 - i : i), y + j, RGB(p.x, p.y, p.z), p.w)
            }
        }
    }

    /// Premultiplied RGBA bytes, rows from the top as an image has them, or from the bottom as a mutable texture does.
    func bytes(topDown: Bool) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        for y in 0..<h {
            for x in 0..<w {
                let p = rgba[y * w + x], o = ((topDown ? h - 1 - y : y) * w + x) * 4
                let premultiplied = pointwiseMin(SIMD3(p.x, p.y, p.z), .one) * p.w * 255
                (bytes[o], bytes[o + 1], bytes[o + 2], bytes[o + 3]) = (UInt8(premultiplied.x), UInt8(premultiplied.y), UInt8(premultiplied.z), UInt8(p.w * 255))
            }
        }
        return bytes
    }

    func texture() -> SKTexture {
        let bytes = bytes(topDown: true)
        let image = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                            provider: CGDataProvider(data: Data(bytes) as CFData)!,
                            decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        return texture
    }
}

/// A canvas of premultiplied bytes with its rows from the bottom, as a mutable texture takes them. The Spaceport
/// paints its moving things into one many times a second, which `Pixels`' floats would make slow. `floor` is the
/// canvas row its bottom row stands for, and nothing is painted outside the columns of `clip`.
private struct Bytes {
    let w: Int, h: Int, floor: Int
    var rgba: [UInt8]
    var clip: Range<Int>

    init(_ w: Int, _ h: Int, floor: Int) {
        (self.w, self.h, self.floor, clip) = (w, h, floor, 0..<w)
        rgba = Array(repeating: 0, count: w * h * 4)
    }

    mutating func plot(_ x: Int, _ y: Int, _ c: RGB, _ a: Float = 1) {
        let row = y - floor
        guard x >= clip.lowerBound, x < clip.upperBound, row >= 0, row < h, a > 0 else { return }
        let i = (row * w + x) * 4, keep = 1 - a, k = a * 255
        rgba[i] = UInt8(min(max(c.x, 0), 1) * k + Float(rgba[i]) * keep)
        rgba[i + 1] = UInt8(min(max(c.y, 0), 1) * k + Float(rgba[i + 1]) * keep)
        rgba[i + 2] = UInt8(min(max(c.z, 0), 1) * k + Float(rgba[i + 2]) * keep)
        rgba[i + 3] = UInt8(k + Float(rgba[i + 3]) * keep)
    }

    mutating func fill(_ x: Int, _ y: Int, _ width: Int, _ height: Int, _ c: RGB, _ a: Float = 1) {
        for yy in y..<y + max(height, 0) { for xx in x..<x + max(width, 0) { plot(xx, yy, c, a) } }
    }

    /// A line one pixel wide, or dotted: only every so many of its pixels.
    mutating func line(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ c: RGB, _ a: Float = 1, every: Int = 1) {
        let n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in stride(from: 0, through: n, by: every) {
            let t = Float(i) / Float(n)
            plot(x0 + Int((Float(x1 - x0) * t).rounded()), y0 + Int((Float(y1 - y0) * t).rounded()), c, a)
        }
    }
}

/// Seeded random numbers (SplitMix64), so the skyline comes out the same on every redraw and every display.
private struct SeededRandom: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Elevation and azimuth (degrees, azimuth clockwise from north) of the sun, or of a point `eclipticOffset` degrees
/// further east along the ecliptic, which is close enough to place the moon. Low precision (~1°), fine for pixels.
private func skyPosition(_ date: Date, latitude: Double, longitude: Double, eclipticOffset: Double = 0) -> (elevation: Double, azimuth: Double) {
    let rad = Double.pi / 180
    let d = (date.timeIntervalSince1970 - 946_728_000) / 86_400 // days since J2000
    let g = (357.529 + 0.98560028 * d) * rad
    let l = (280.459 + 0.98564736 * d + 1.915 * sin(g) + 0.020 * sin(2 * g) + eclipticOffset) * rad
    let e = 23.439 * rad
    let ra = atan2(cos(e) * sin(l), cos(l)), dec = asin(sin(e) * sin(l))
    let hourAngle = (280.46061837 + 360.98564736629 * d + longitude) * rad - ra
    let lat = latitude * rad
    let el = asin(sin(lat) * sin(dec) + cos(lat) * cos(dec) * cos(hourAngle))
    let az = atan2(-sin(hourAngle), tan(dec) * cos(lat) - sin(lat) * cos(hourAngle))
    return (el / rad, (az / rad + 360).truncatingRemainder(dividingBy: 360))
}
