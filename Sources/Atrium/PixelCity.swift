import SpriteKit

@MainActor func pixelCity(size: CGSize) -> SKScene { PixelCity(size: size) }

/// A pixel-art skyline that follows the real sun and clock: dawn, day, dusk and night skies, windows lighting
/// up and going dark through the evening, traffic on the street, a blinking antenna and the odd plane.
/// Everything lives on a low-resolution canvas measured in art pixels, scaled up with nearest filtering.
/// Settings picks the city: Street, side-on from the kerb, or Waterfront, a downtown seen across water, its walls
/// lit from wherever the Sun really is.
final class PixelCity: SKScene {
    nonisolated static let knobs = [
        Knob(key: "city.view", label: "City", range: 0...Double(City.allCases.count - 1), standard: 1, section: "City",
             format: .choice(City.allCases.map(\.name))),
        Knob(key: "city.shuffle", label: "Move to another city automatically", range: 0...1, standard: 0, section: "City",
             format: .toggle),
        Knob(key: "city.shuffleMinutes", label: "Move every", range: 1...60, standard: 10, section: "City", format: .minutes,
             shownWhen: "city.shuffle"),
        Knob(key: "city.looking", label: "Looking", range: 0...8, standard: 0, section: "City",
             format: .choice(["Toward the midday Sun", "North", "North-east", "East", "South-east", "South", "South-west", "West", "North-west"])),
        Knob(key: "city.previewTime", label: "Preview a time of day", range: 0...1, standard: 0, section: "Preview",
             format: .toggle),
        Knob(key: "city.previewHour", label: "Time", range: 0...24, standard: 19, section: "Preview", format: .clock,
             shownWhen: "city.previewTime"),
    ]
    private enum K: Int { case view, shuffle, shuffleMinutes, looking, previewTime, previewHour }
    private static func knob(_ k: K) -> Double { knobs[k.rawValue].value }
    private var settings = PixelCity.knobs.map(\.value)
    private var retired = false // it has handed over to a scene of another city, and is fading out
    private static var easing = false // the city is changing by itself, so take the fade slowly

    private let w: Int, h: Int
    private var city = City.waterfront
    private var classic: Bool { city == .street } // the Street keeps its first, simpler sky and light
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
    private let canvas = SKNode()
    private let sky = SKSpriteNode()      // sky, stars, Sun and Moon…
    private let backdrop = SKSpriteNode() // …and the city in front, so clouds and planes pass between the two
    private var mirrored: [SKUniform] = []   // the sky and city textures the water reflects…
    private var waterTints: [SKUniform] = [] // …and the colours of deep water and of the glints on it
    private var skyline: [Building] = []
    private var parks: [(x: Int, width: Int)] = []
    private var stars: [(x: Int, y: Int, brightness: Float)] = []
    private var clouds: [Cloud] = []
    private var cars: [Car] = []
    private var carLooks: [(day: SKTexture, night: SKTexture, length: Int, height: Int)] = []
    private var carPace: Float = 1, carGap: Float = 36 // far-off traffic crawls, and runs closer together
    private var plane = SKSpriteNode()
    private var planeLights = SKNode()
    private var beacon = SKNode()
    // Light on the waterfront's walls: what the sky gives every wall, and what the Sun or Moon adds to one facing it.
    private var ambient = RGB.one, keyFront = RGB.zero, keyLeft = RGB.zero, keyRight = RGB.zero, keyTop = RGB.zero
    private var behind = RGB.zero // the horizon's colour at our backs, which glass fronts mirror
    private var span: Double { classic ? 200 : 260 } // degrees of compass across the screen
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
        layOut()
        redraw()
        run(.repeatForever(.sequence([.wait(forDuration: 30), .run { [weak self] in self?.redraw() }])))
        waitToMove()
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged),
                                               name: UserDefaults.didChangeNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func didMove(to view: SKView) {
        Location.shared.start()
    }

    /// Repaints when one of its own settings changes (the notification comes for every wallpaper's).
    @objc private func settingsChanged() {
        let picked = Self.knobs.map(\.value)
        guard picked != settings, !retired else { return }
        let moved = picked[K.view.rawValue] != settings[K.view.rawValue]
        settings = picked
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
        redraw()
        waitToMove()
    }

    /// Starts the wait for the automatic move over again, if Settings has it on: any change to these settings does,
    /// picking a city by hand included.
    private func waitToMove() {
        removeAction(forKey: "move")
        guard Self.knob(.shuffle) > 0.5 else { return }
        run(.sequence([.wait(forDuration: Self.knob(.shuffleMinutes).rounded() * 60), .run { [weak self] in self?.moveOn() }]), withKey: "move")
    }

    /// Moves to another city, picked at random. It saves the pick as Settings would, so every display's copy of the
    /// scene follows it and the City menu shows where we are.
    func moveOn() {
        guard !retired else { return }
        Self.easing = true
        defer { Self.easing = false }
        UserDefaults.standard.set(Double(City.allCases.filter { $0 != city }.randomElement()!.rawValue), forKey: Self.knobs[K.view.rawValue].key)
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
        (plane, planeLights, beacon, mirrored, waterTints) = (SKSpriteNode(), SKNode(), SKNode(), [], [])
        (nextCar, planeDirection, shipDirection, ship) = ([clock, clock], 0, 0, SKSpriteNode())
        city = City(rawValue: Int(Self.knob(.view))) ?? .waterfront
        waterRows = city == .waterfront ? Int(Float(h) * 0.21) : 0
        switch city {
        case .street: ground = 26
        case .waterfront: ground = waterRows + quay + 26
        case .foothills: ground = Int(Float(h) * 0.27)
        case .bridge:
            ground = Int(Float(h) * 0.32) // the far shore: the bay fills everything below it
            waterRows = ground
        case .hillside:
            ground = Int(Float(h) * 0.26) // the sea's horizon, out past the harbour
            waterRows = ground
        case .overlook: ground = Int(Float(h) * 0.54) // the far skyline's feet: rooftops fill everything below
        }
        crest = Array(repeating: ground, count: w)
        (ridges, downtown, farHaze, slope, boats) = ([], 0.5, 1, [], [])
        for (node, z) in [(sky, 0.0), (backdrop, 2)] {
            node.anchorPoint = .zero
            node.size = CGSize(width: w, height: h)
            node.zPosition = z
            canvas.addChild(node)
        }
        var rng = SeededRandom(state: 2026)
        let tower: (x: Int, y: Int)
        switch city {
        case .street: tower = layOutStreet(&rng)
        case .waterfront: tower = layOutWaterfront(&rng)
        case .foothills: tower = layOutFoothills(&rng)
        case .bridge: tower = layOutBridge(&rng)
        case .hillside: tower = layOutHillside(&rng)
        case .overlook: tower = layOutOverlook(&rng)
        }
        skyBase = crest.min() ?? ground
        beacon.position = CGPoint(x: tower.x, y: tower.y)
        // A red aircraft light on a mast, or on Hillside Town's lighthouse a white flash.
        let flash = city == .hillside ? NSColor(red: 1, green: 0.96, blue: 0.8, alpha: 1) : NSColor(red: 1, green: 0.25, blue: 0.2, alpha: 1)
        beacon.addChild(SKSpriteNode(color: flash.withAlphaComponent(0.3), size: CGSize(width: 3, height: 3)))
        beacon.addChild(SKSpriteNode(color: flash, size: CGSize(width: 1, height: 1)))
        beacon.zPosition = 5
        beacon.run(.repeatForever(.sequence([.fadeAlpha(to: 1, duration: 0), .wait(forDuration: 0.25),
                                             .fadeAlpha(to: 0.15, duration: 0), .wait(forDuration: 1.25)])))
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
        let far = city == .foothills || city == .bridge // traffic seen from miles off: a car is a dash of paint, and at night just its lights
        carLooks = far ? paints.map { speck(2, body: $0) } + [speck(4, body: rgb(226, 226, 218))]
                       : paints.map { vehicle(sedan, body: $0) } + [vehicle(bus, body: rgb(228, 150, 40))]
        (carPace, carGap) = far ? (0.35, 7) : (1, 36)
        let lanes = city == .bridge ? [deck + 1, deck + 2] : far ? [ground - 16, ground - 14] : [streetBase + 5, streetBase + 13]
        for lane in 0...1 {
            for _ in 0..<(city == .hillside || city == .overlook ? 0 : far ? 14 : 6) { // no road in view in those two
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
            for x in [Float(w) * 0.2, Float(w) * 0.65] { spawnCar(lane: lane, at: x + Float.random(in: -20...20)) }
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
        if city == .bridge { // a freighter that crosses the bay in front of the bridge now and then
            ship.anchorPoint = CGPoint(x: 0.5, y: 0)
            ship.size = CGSize(width: freighter[0].count, height: freighter.count + 4)
            ship.position.y = CGFloat(ground - 40)
            ship.zPosition = 3
            ship.isHidden = true
            canvas.addChild(ship)
        }
    }

    /// The Street city: a far and a near row of plain blocks. Returns the top of the landmark's mast, for the beacon.
    private func layOutStreet(_ rng: inout SeededRandom) -> (x: Int, y: Int) {
        let farPalette = [rgb(118, 128, 150), rgb(136, 142, 160), rgb(108, 116, 138)]
        let nearPalette = [rgb(122, 106, 98), rgb(150, 140, 128), rgb(104, 116, 134),
                           rgb(168, 150, 120), rgb(92, 96, 108), rgb(140, 96, 84)]
        for far in [true, false] {
            var x = far ? -4 : -3
            while x < w {
                let width = far ? Int.random(in: 12...28, using: &rng) : Int.random(in: 14...34, using: &rng)
                let height = Float(h) * (far ? Float.random(in: 0.22...0.45, using: &rng) : Float.random(in: 0.1...0.38, using: &rng))
                skyline.append(Building(x: x, width: width, height: Int(height),
                                        colour: (far ? farPalette : nearPalette).randomElement(using: &rng)!, far: far,
                                        floor: far ? 3 : Int.random(in: 4...5, using: &rng),
                                        pitch: far ? 2 : Int.random(in: 3...4, using: &rng),
                                        roof: Roof.allCases.dropLast().randomElement(using: &rng)!, seed: rng.next()))
                x += width + Int.random(in: 0...(far ? 2 : 4), using: &rng)
            }
        }

        // The landmark: a near tower well above the rest, with a blinking beacon on its mast.
        let middle = skyline.indices.filter { !skyline[$0].far && abs(skyline[$0].x - w * 3 / 5) < 40 }
        let landmark = middle.max { skyline[$0].width < skyline[$1].width } ?? skyline.count - 1
        skyline[landmark].height = Int(Float(h) * 0.5)
        skyline[landmark].roof = .antenna
        let tower = skyline[landmark]
        return (tower.x + tower.width / 2, ground + tower.height + 18)
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
            node.size = CGSize(width: rows[0].count, height: rows.count + 3)
            node.position = CGPoint(x: end * (22 + i * 12) / 100 + Int.random(in: -5...5, using: &rng), y: harbour - 9 - (i % 3) * 3)
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
        // Steam from the two vents on our own roof, a puff at a time, each stepping up a pixel as it thins.
        for (vent, x) in [w * 31 / 100, w * 58 / 100].enumerated() {
            for puff in 0..<3 {
                let node = SKSpriteNode(color: NSColor(white: 0.92, alpha: 1), size: CGSize(width: 2, height: 2))
                node.anchorPoint = .zero
                node.zPosition = 3
                node.alpha = 0
                let rise = (0..<8).flatMap { step in
                    [SKAction.wait(forDuration: 0.5), .run { node.position.y += 1; node.alpha = 0.5 * (1 - CGFloat(step) / 8) }]
                }
                node.run(.sequence([.wait(forDuration: Double(puff) * 1.4 + Double(vent) * 0.7),
                                    .repeatForever(.sequence([.run { node.position = CGPoint(x: x, y: 22); node.alpha = 0.5 }] + rise))]))
                canvas.addChild(node)
            }
        }
        return tower
    }

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

    /// The water along the bottom: a shader that mirrors whatever stands above it (on the Waterfront, the quay and then
    /// the city), row by rippling row.
    private func addWater() {
        let node = SKSpriteNode(color: .black, size: CGSize(width: w, height: waterRows))
        node.anchorPoint = .zero
        node.zPosition = 2.5
        mirrored = [SKUniform(name: "u_sky", texture: nil), SKUniform(name: "u_city", texture: nil)]
        waterTints = [SKUniform(name: "u_deep", vectorFloat3: .zero), SKUniform(name: "u_glint", vectorFloat3: .zero)]
        node.shader = SKShader(source: Self.waterShader, uniforms: mirrored + waterTints + [
            SKUniform(name: "u_canvas", vectorFloat2: [Float(w), Float(h)]),
            // The water's size; the row things nearest us stand in the water at (the bridge's towers, the town's quay,
            // short of the far shore); and the rows of quay wall and of street, which lies flat and out of sight, above it.
            SKUniform(name: "u_water", vectorFloat4: [Float(w), Float(waterRows), Float(city == .bridge ? ground - 12 : city == .hillside ? harbour : waterRows),
                                                      Float(city == .waterfront ? quay : 0)]),
            SKUniform(name: "u_street", float: city == .waterfront ? 26 : 0),
            WallpaperTime.now,
        ])
        canvas.addChild(node)
    }

    // ponytail: only the backdrop is mirrored, so cars and clouds have no reflection; mirror their sprites if it shows
    private static let waterShader = """
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
        let band: Float = classic ? 1 : 0.4 // how much of each band is dithered into the next
        let sunSpot = place(sun, latitude: spot.latitude)
        let glow = smoothstep(-10, 0, el) * (1 - smoothstep(6, 20, el)) * 0.7 + 0.15 * smoothstep(0, 10, el)
        let glowColour = mix(rgb(255, 128, 64), rgb(255, 214, 150), smoothstep(-2, 10, el))
        let reach = mix(1, 0.35, smoothstep(4, 20, el)) // a low sun lights a wide band of sky, a high one a small halo
        for y in 0..<h {
            let t = max(0, Float(y - skyBase) / Float(h - skyBase))
            for x in 0..<w {
                let d = bayer(x, y)
                var c = mix(horizons[x], top, pow(min(1, (t * 14 + (1 - band) / 2 + d * band).rounded(.down) / 14), 0.6))
                if !classic, night > 0 { // the city's own glow in the night sky, strongest over downtown
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
            let clear = classic ? 1 : smoothstep(0.1, 0.6, Float(star.y - skyBase) / Float(h - skyBase)) * 0.8
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
        case .street: break
        case .waterfront: drawHorizon(into: &px, zenith: top, horizon: horizon)
        case .foothills: drawMountains(into: &px, horizons: horizons)
        case .bridge: drawHorizon(into: &px, zenith: top, horizon: horizon)
        case .hillside:
            drawHorizon(into: &px, zenith: top, horizon: horizon)
            drawHill(into: &px)
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
            case .box: draw(building, into: &px, horizon: haze)
            case .house, .cypress: drawHouse(building, into: &px)
            case .block: drawBlock(building, into: &px, zenith: top, horizon: haze)
            default: drawTower(building, into: &px, zenith: top, horizon: haze)
            }
        }
        drawParks(into: &px)
        switch city {
        case .street: drawStreet(into: &px)
        case .waterfront:
            drawStreet(into: &px)
            drawQuay(into: &px)
        case .foothills: drawPlain(into: &px, horizons: horizons)
        case .bridge:
            drawBridge(into: &px)
            ship.texture = afloat(freighter, hull: rgb(44, 56, 76), dark: night > 0.5)
        case .hillside:
            drawHarbour(into: &px)
            for boat in boats { boat.node.texture = afloat(boat.rows, hull: boat.hull, dark: night > 0.5) }
        case .overlook: drawRooftop(into: &px)
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
        guard !classic else { return (x, ground + Int(p.elevation / 70 * Double(h - ground - 14))) }
        // Beyond the Street the view is wider, so sunrise and sunset stay on screen all year, a low Sun or Moon gets
        // more room, and they drop out of sight as soon as they set: behind the skyline at that spot (`crest`), which
        // they clear by the time they are 15 degrees up.
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

    /// One building: facade, shading, roof furniture and a grid of windows lit by the evening schedule.
    private func draw(_ b: Building, into px: inout Pixels, horizon: RGB) {
        var facade = mix(b.colour, b.colour * RGB(0.16, 0.17, 0.28) + rgb(4, 4, 10), night)
        facade = pointwiseMin(facade + b.colour * keyFront, .one) // a Sun or Moon at our backs lights the fronts
        if b.far { facade = mix(facade, horizon, mix(0.42, 0.3, night)) }
        let metal = mix(rgb(70, 70, 80), rgb(14, 14, 22), night)
        let top = ground + b.height
        px.fill(b.x, ground, b.width, b.height, facade)
        px.fill(b.x + b.width - 1, ground, 1, b.height, facade * 0.8)
        px.fill(b.x, top - 1, b.width, 1, pointwiseMin(facade * 1.15, .one))

        switch b.roof {
        case .plain: break
        case .ledge: px.fill(b.x - 1, top - 2, b.width + 2, 1, facade * 0.75)
        case .setback:
            px.fill(b.x + 3, top, b.width - 6, 6, facade)
            px.fill(b.x + b.width - 4, top, 1, 6, facade * 0.8)
        case .tank where !b.far: drawTank(into: &px, x: b.x + b.width / 3, y: top, legs: metal)
        case .tank: break
        case .antenna:
            let mx = b.x + b.width / 2
            px.fill(b.x + 3, top, b.width - 6, 4, facade)
            px.fill(mx, top + 4, 1, 14, metal)
            px.fill(mx - 1, top + 9, 3, 1, metal)
            px.fill(mx - 1, top + 13, 3, 1, metal)
        }

        var rng = SeededRandom(state: b.seed)
        let size = b.far ? 1 : 2
        let glass = mix(facade * 0.55 + rgb(12, 18, 34), facade * 0.72, night)
        for y in stride(from: ground + 3, through: top - 3 - size, by: b.floor) {
            for x in stride(from: b.x + 2, through: b.x + b.width - 2 - size, by: b.pitch) {
                let (r1, r2, r3) = (Float.random(in: 0..<1, using: &rng), Float.random(in: 0..<1, using: &rng), Float.random(in: 0..<1, using: &rng))
                var colour = glass
                if night > 0.15 && isLit(r1, r2, r3) {
                    let lamp: RGB = r3 < 0.08 ? rgb(150, 182, 255) : r3 < 0.14 ? rgb(236, 240, 224) : mix(rgb(255, 196, 104), rgb(255, 228, 150), r1)
                    colour = mix(glass, lamp, min(1, night * 1.6) * (b.far ? 0.8 : 1))
                }
                px.fill(x, y, size, size, colour)
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
        case .box, .house, .cypress, .block: break // drawn elsewhere
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

    /// A vessel from rows of characters, heading right, with a faint reflection under it (the water doesn't mirror
    /// sprites). By night its hull is a shadow, and its windows and mast light show.
    private func afloat(_ rows: [String], hull: RGB, dark: Bool) -> SKTexture {
        let dim = dark ? RGB(0.3, 0.32, 0.45) : .one, mirrored = min(4, rows.count / 2)
        let paints: [Character: RGB] = [
            "H": hull * dim, "h": pointwiseMin(hull * 1.25 + 0.06, .one) * dim, "r": rgb(150, 52, 46) * dim,
            "W": rgb(226, 226, 218) * dim, "c": rgb(232, 230, 220) * dim, "s": rgb(240, 234, 214) * dim, "m": rgb(120, 124, 130) * dim,
            "a": rgb(172, 86, 62) * dim, "b": rgb(62, 130, 140) * dim, "d": rgb(196, 160, 72) * dim,
            "w": dark ? rgb(255, 220, 140) : rgb(70, 90, 110), "l": dark ? rgb(255, 250, 230) : rgb(120, 124, 130),
        ]
        var px = Pixels(rows[0].count, rows.count + mirrored)
        for (r, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() {
                guard let colour = paints[ch] else { continue }
                let y = rows.count - 1 - r
                px.plot(x, y + mirrored, colour)
                if y < mirrored { px.plot(x, mirrored - 1 - y, colour * 0.6, 0.45) }
            }
        }
        return px.texture()
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
        px.fill(0, 0, w, 13, wall)
        px.fill(0, 13, w, 2, coping)
        for x in stride(from: 0, to: w, by: 16) { px.fill(x, 0, 1, 13, dark) } // joints
        let tx = w * 6 / 100 // the tank: staves and hoops on a steel frame
        for x in [tx + 2, tx + 12, tx + 22] { px.fill(x, 15, 1, 12, dark) }
        px.fill(tx, 26, 26, 1, dark)
        for row in 0..<22 { px.fill(tx, 27 + row, 26, 1, lit(rgb(124, 86, 62), keyFront, shade: row % 7 == 3 ? 0.55 : 0.85)) }
        px.fill(tx + (keyRight.sum() >= keyLeft.sum() ? 22 : 0), 27, 4, 22, lit(rgb(124, 86, 62), max(keyRight, keyLeft), shade: 0.7))
        for r in 0..<5 { px.fill(tx - 1 + r * 3, 49 + r, 28 - r * 6, 1, lit(rgb(96, 68, 52), keyTop * 0.5)) } // its conical lid
        for x in [w * 31 / 100, w * 58 / 100] { // vents
            px.fill(x - 1, 15, 4, 5, lit(rgb(120, 124, 130), keyFront))
            px.fill(x - 2, 20, 6, 1, dark)
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
    private func isLit(_ a: Float, _ b: Float, _ c: Float, home: Float = 0.65) -> Bool {
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

        for i in clouds.indices {
            clouds[i].x += clouds[i].speed * dt
            if clouds[i].x - Float(clouds[i].mask[0].count) / 2 > Float(w) { clouds[i].x = -Float(clouds[i].mask[0].count) / 2 }
            clouds[i].node.position.x = CGFloat(clouds[i].x.rounded(.down))
        }

        if planeDirection == 0, clock >= nextPlane {
            planeDirection = Bool.random() ? 1 : -1
            planeX = planeDirection > 0 ? -10 : Float(w + 10)
            plane.position.y = CGFloat(Int(Float(h) * Float.random(in: 0.8...0.93)))
            plane.xScale = CGFloat(planeDirection)
            plane.isHidden = false
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
            if shipDirection != 0, shipX < -22 || shipX > Float(w + 22) {
                (shipDirection, ship.isHidden) = (0, true)
                nextShip = clock + .random(in: 90...240)
            }
        }
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
        nextCar[lane] = clock + .random(in: 1.5...6) / traffic
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

    /// Day and night textures for a vehicle drawn as `rows`, painted in `body`.
    private func vehicle(_ rows: [String], body: RGB) -> (day: SKTexture, night: SKTexture, length: Int, height: Int) {
        func look(_ dark: Bool) -> SKTexture {
            let paint = dark ? body * RGB(0.46, 0.48, 0.62) : body
            return art(rows, ["B": paint, "#": paint * 0.85, "d": paint * 0.65,
                              "w": dark ? rgb(30, 36, 52) : rgb(150, 186, 216),
                              "W": dark ? rgb(255, 220, 140) : rgb(150, 186, 216),
                              "h": dark ? rgb(255, 250, 215) : rgb(232, 232, 218),
                              "t": dark ? rgb(255, 50, 50) : rgb(150, 30, 30), "o": rgb(24, 24, 30)])
        }
        return (look(false), look(true), rows[0].count, rows.count)
    }

    /// A vehicle far off: a dash of paint by day, and by night only its tail light and headlight.
    private func speck(_ length: Int, body: RGB) -> (day: SKTexture, night: SKTexture, length: Int, height: Int) {
        (art([String(repeating: "B", count: length)], ["B": body]),
         art(["t" + String(repeating: ".", count: length - 2) + "h"], ["t": rgb(255, 50, 50), "h": rgb(255, 250, 215)]), length, 1)
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
}

// MARK: - Supporting types

private enum Roof: CaseIterable { case plain, ledge, setback, tank, antenna }

/// The cities Settings can pick, in the menu's order. The pick is stored as its index, so add new ones at the end.
private enum City: Int, CaseIterable {
    case street, waterfront, foothills, bridge, hillside, overlook
    var name: String { ["Street", "Waterfront", "Foothills", "Long Bridge", "Hillside Town", "Overlook"][rawValue] }
}

/// What a building is: the Street's plain block; on the waterfront a windowless tower in the haze, a stone tower
/// with setbacks, a glass curtain wall, a brick walk-up over a shop, or a concrete slab with ribbon windows; or in
/// Hillside Town a house, or the cypress in a gap between two; or one of the Overlook's buildings seen from above.
private enum Kind { case box, haze, deco, glass, brick, slab, house, cypress, block }

private struct Building {
    var x: Int, width: Int, height: Int
    var colour: RGB
    var far: Bool
    var floor: Int, pitch: Int // window spacing, vertical and horizontal
    var roof: Roof
    var seed: UInt64
    var kind = Kind.box
    var base: Int? // the row it stands on, for a house up a hillside; the ground otherwise
}

private struct Car {
    let node: SKSpriteNode
    let beam: SKSpriteNode
    let lane: Int // 0 near, heading right; 1 far, heading left
    var look = 0
    var x: Float = 0, cruise: Float = 0, speed: Float = 0, length: Float = 16
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
private func art(_ rows: [String], _ palette: [Character: RGB]) -> SKTexture {
    var px = Pixels(rows[0].count, rows.count)
    for (r, row) in rows.enumerated() {
        for (x, ch) in row.enumerated() { if let c = palette[ch] { px.plot(x, rows.count - 1 - r, c) } }
    }
    return px.texture()
}

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

    func texture() -> SKTexture {
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        for y in 0..<h {
            for x in 0..<w {
                let p = rgba[y * w + x], o = ((h - 1 - y) * w + x) * 4 // image rows run top-down
                let premultiplied = pointwiseMin(SIMD3(p.x, p.y, p.z), .one) * p.w * 255
                (bytes[o], bytes[o + 1], bytes[o + 2], bytes[o + 3]) = (UInt8(premultiplied.x), UInt8(premultiplied.y), UInt8(premultiplied.z), UInt8(p.w * 255))
            }
        }
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
