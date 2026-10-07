import SpriteKit
import simd

/// A reef tank seen through the glass, bright under its lamps: real fish, cut out of photos, schooling at three
/// depths around two islands of rock and coral, clownfish at home in their anemone, soft corals swaying in the
/// current, caustics rippling over white sand, and the mirror of the surface along the top. The photos are credited
/// in Resources/reef-credits.tsv; everything else is drawn in shaders.
final class FishTank: SKScene {
    /// One fish. It swims in the flat plane of its school's depth.
    struct Swimmer {
        let node: SKSpriteNode
        let shadow: SKSpriteNode // on the sand below
        let depth: Double        // its school's, give or take: a school has some thickness, for shadows
        let length: Double       // nose to tail, in points
        var position: SIMD2<Double>
        var velocity: SIMD2<Double>
        var facing: Double
        var wander = Double.random(in: 0..<(2 * .pi))
        var tilt = 0.0
        var stroke = Double.random(in: 0..<1) // how far through a tail beat, in beats
        var frame = -1
        var pulse = Double.random(in: 0..<1)  // how far through a burst-and-coast cycle, for species that swim so
        var coasting = false
        var bank = 1.0 // which way it rolls in a turn: 1 tips its flank up toward the lamp, -1 away
    }

    /// Fish of one species at one depth, which school together.
    private struct School {
        let species: Species
        let depth: CGFloat // 1 is the front of the tank, smaller is further back
        let cruise: Double // points per second
        let beat: [SKWarpGeometryGrid] // one tail beat of warp frames
        var members: [Int] = []
        var home: SIMD2<Double>? // a spot they keep near, like clownfish at their anemone
    }

    private enum Z {
        static let water: CGFloat = 0, sand: CGFloat = 1, shadows: CGFloat = 1.5, backReef: CGFloat = 2, farFish: CGFloat = 3, reef: CGFloat = 4
        static let midFish: CGFloat = 5, frontReef: CGFloat = 6, nearFish: CGFloat = 7, snow: CGFloat = 8, vignette: CGFloat = 9
    }

    /// Which tank is showing: the home reef tank, the Georgia Aquarium's Ocean Voyager window, or a sunlit reef
    /// flat in the open sea. Picked in Settings, or moved on by the tank shuffle.
    enum Tank: Int, CaseIterable {
        case reef, ocean, lagoon
        var name: String { ["Reef Tank", "Ocean Voyager", "Shallow Reef"][rawValue] }
        /// How much of the screen the floor takes, and how high the water goes: the reef tank's lid, the top of the
        /// Ocean Voyager window, and the lagoon's surface band, seen from below.
        var floor: CGFloat { [0.22, 0.16, 0.4][rawValue] }
        var ceiling: CGFloat { [0.9, 0.98, 0.76][rawValue] }
    }
    /// Fish Tank's settings: the tank, and whether and how often it moves to another by itself.
    nonisolated static let knobs = [
        Knob(key: "tank.kind", label: "Tank", range: 0...Double(Tank.allCases.count - 1), standard: 0, section: "Tank",
             format: .choice(Tank.allCases.map(\.name))),
        Knob(key: "tank.shuffle", label: "Move to another tank automatically", range: 0...1, standard: 0, section: "Tank", format: .toggle),
        Knob(key: "tank.shuffleMinutes", label: "Move every", range: 1...60, standard: 10, section: "Tank", format: .minutes,
             shownWhen: "tank.shuffle"),
    ]
    private static let movedKey = "tank.moved" // when the desktop last moved to another tank, on the wall clock
    private static var easing = false // the tank is changing by itself, so take the fade slowly

    let tank: Tank
    private var settings: [Double] = []
    private var retired = false // it has handed over to a scene of another tank, and is fading out
    private(set) var swimmers: [Swimmer] = []
    private var schools: [School] = []
    private var lastUpdate: TimeInterval?
    private var anemone = CGPoint.zero
    private var rockSpots: [CGPoint] = [] // where the shy species hang about, low by each island

    override init(size: CGSize) {
        Self.moveIfDue() // off the desktop for longer than the shuffle's wait, it comes back as another tank
        tank = Tank(rawValue: Int(Self.knobs[0].value)) ?? .reef
        super.init(size: size)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Scales the art with the display, so a bigger screen gets a bigger tank rather than smaller fish.
    private var unit: CGFloat { min(max(size.height / 982, 0.8), 1.8) }
    private var sandHeight: CGFloat { size.height * tank.floor }
    /// Fish are drawn a little larger than life against the plants, so they read from across the room.
    private var fishUnit: CGFloat { unit * 1.2 }

    override func sceneDidLoad() {
        backgroundColor = .black
        switch tank {
        case .reef:
            addWater()
            addSand()
            addReef()
        case .ocean:
            addOceanWater()
            addSeabed(cell: 220, net: 0.3, ripples: 0, melt: 0.25)
            addOceanRocks()
        case .lagoon:
            addLagoonWater()
            addSeabed(cell: 90, net: 1.0, ripples: 0.07, melt: 0.5)
            addBommies()
        }
        addSchools()
        addMarineSnow()
        addVignette()
        for _ in 0..<150 { swim(1.0 / 30) } // let the schools gather before the first frame
        settings = Self.knobs.map(\.value)
        run(.repeatForever(.sequence([.wait(forDuration: 5), .run { [weak self] in self?.moveIfDue() }])))
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged),
                                               name: UserDefaults.didChangeNotification, object: nil)
    }

    override func update(_ currentTime: TimeInterval) {
        swim(frameTime(currentTime, &lastUpdate))
        castShadows()
    }

    // MARK: - Changing tank

    /// When Settings names another tank, dissolves into a new scene of it with both still running, never a cut.
    /// Picking one by hand, or changing whether and how often it moves, starts the shuffle's wait over.
    @objc private func settingsChanged() {
        let picked = Self.knobs.map(\.value)
        guard picked != settings, !retired else { return }
        if !Self.easing { UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.movedKey) }
        settings = picked
        guard let next = Tank(rawValue: Int(picked[0])), next != tank, let view else { return } // no view: the render tests
        let fade = SKTransition.crossFade(withDuration: Self.easing ? 4 : 0.8)
        fade.pausesIncomingScene = false
        fade.pausesOutgoingScene = false
        let scene = FishTank(size: size)
        scene.scaleMode = scaleMode
        retired = true
        view.presentScene(scene, transition: fade)
    }

    private func moveIfDue() {
        if !retired { Self.moveIfDue() }
    }

    /// Moves to another tank, picked at random, if Settings has that on and the wait is up. It saves the pick as
    /// Settings would, so every display's copy follows it and the Tank menu shows where we are.
    private static func moveIfDue() {
        guard knobs[1].value > 0.5 else { return }
        let now = Date().timeIntervalSince1970
        guard let moved = UserDefaults.standard.object(forKey: movedKey) as? Double else {
            return UserDefaults.standard.set(now, forKey: movedKey) // just switched on: the wait starts here
        }
        guard now - moved >= knobs[2].value.rounded() * 60 else { return }
        easing = true
        defer { easing = false }
        UserDefaults.standard.set(now, forKey: movedKey)
        let showing = Tank(rawValue: Int(knobs[0].value)) ?? .reef
        UserDefaults.standard.set(Double(Tank.allCases.filter { $0 != showing }.randomElement()!.rawValue), forKey: knobs[0].key)
    }

    // MARK: - Swimming

    /// The floor and ceiling a school keeps between: fish further back can't come as low, since the sand is nearer
    /// the eye there.
    private func bounds(_ depth: CGFloat, height: ClosedRange<Double> = 0...1) -> (floor: Double, ceiling: Double) {
        let low = sandLine(depth) + Double(30 * unit), high = Double(size.height * tank.ceiling - 30 * unit)
        return (low + (high - low) * height.lowerBound, low + (high - low) * height.upperBound)
    }

    /// Where the sand meets the plane a school swims in: further back, it's higher up the screen.
    private func sandLine(_ depth: CGFloat) -> Double {
        Double(sandHeight) * (1 - 0.65 * Double(min(max((depth - 0.55) / 0.5, 0), 1)))
    }

    /// Steers every fish: keep clear of schoolmates, match their heading, drift toward their middle, wander a
    /// little, and turn back from the walls just past the screen edges, the sand and the surface.
    private func swim(_ dt: Double) {
        let width = Double(size.width), wall = width * 0.1
        for school in schools {
            let body = Double(school.species.length * school.depth * fishUnit)
            let gap = body * school.species.spacing, sight = body * 6, push = school.cruise * 2.5
            let (floor, ceiling) = bounds(school.depth, height: school.species.height)
            let edge = body * school.species.margin // big animals leave the screen before the walls turn them
            let rests = school.species.rests, sand = sandLine(school.depth) + body * 0.1
            for i in school.members {
                let p = swimmers[i].position, v = swimmers[i].velocity
                var steer = SIMD2<Double>.zero, heading = SIMD2<Double>.zero, middle = SIMD2<Double>.zero, seen = 0.0
                // ponytail: O(n²) within a school, fine up to a few dozen fish per school
                for j in school.members where j != i {
                    let d = swimmers[j].position - p, distance = max(length(d), 0.001)
                    if distance < gap { steer -= d / distance * (gap - distance) / gap * school.cruise * 3 }
                    if distance < sight {
                        heading += swimmers[j].velocity
                        middle += swimmers[j].position
                        seen += 1
                    }
                }
                if seen > 0 {
                    steer += (heading / seen - v) * 0.9
                    steer += (middle / seen - p) * 0.25
                }
                swimmers[i].wander += Double.random(in: -1...1) * dt * 1.5
                steer += SIMD2(cos(swimmers[i].wander), 0.4 * sin(swimmers[i].wander)) * school.cruise * 0.45
                if let home = school.home { steer += (home - p) * 0.08 }
                steer.x += max(0, wall - width * 0.04 - edge - p.x) / wall * push
                steer.x -= max(0, p.x - (width * 1.04 - wall + edge)) / wall * push
                if !rests {
                    steer.y += max(0, floor + 60 - p.y) / 60 * push * 0.6
                    steer.y -= max(0, p.y - (ceiling - 60)) / 60 * push * 0.6
                }

                var velocity = v + steer * dt
                if let burst = school.species.burst { // thrust while beating, drag while gliding (or resting)
                    swimmers[i].pulse += dt / burst.cycle
                    swimmers[i].coasting = swimmers[i].pulse.truncatingRemainder(dividingBy: 1) >= burst.share
                    velocity += velocity / max(length(velocity), 0.001) * school.cruise * (swimmers[i].coasting ? -0.9 : 1.8) * dt
                }
                velocity.y *= 1 - 1.4 * dt // fish mostly swim level
                let speed = length(velocity)
                // A resting species settles to a stop on the sand between its moves, and slides along it. Too slow,
                // a fish swims on the way it faces (scaling the vector up kept a slow sideways drift going, so big
                // gliders slid backwards); too fast, it's reined in.
                let slowest = rests && swimmers[i].coasting ? 0 : school.cruise * 0.45
                if speed < slowest { velocity.x += (swimmers[i].facing >= 0 ? 1 : -1) * (slowest - speed) }
                else if speed > school.cruise * 1.35 { velocity *= school.cruise * 1.35 / speed }
                if rests { velocity.y = 0 }
                swimmers[i].velocity = velocity
                swimmers[i].position = rests ? SIMD2(p.x + velocity.x * dt, sand) : p + velocity * dt
                pose(i, in: school, dt: dt)
            }
        }
    }

    /// Faces, tilts and paces the tail beat of a fish from its velocity. Turning eases its width through zero, so
    /// it reads as the fish turning round rather than flipping.
    private func pose(_ i: Int, in school: School, dt: Double) {
        var fish = swimmers[i]
        let v = fish.velocity, cruise = school.cruise
        let target = v.x > cruise * 0.15 ? 1.0 : v.x < -cruise * 0.15 ? -1.0 : (fish.facing >= 0 ? 1 : -1)
        if fish.facing == -target { fish.bank = Bool.random() ? 1 : -1 } // a new turn: bank toward the lamp or away
        fish.facing += max(-dt * 2.5, min(dt * 2.5, target - fish.facing))
        let pitch = max(-0.3, min(0.3, atan2(v.y, max(abs(v.x), cruise * 0.5))))
        fish.tilt += (pitch - fish.tilt) * min(1, dt * 3)
        fish.node.position = CGPoint(x: fish.position.x, y: fish.position.y)
        fish.node.xScale = CGFloat(fish.facing) * school.depth * fishUnit
        fish.node.zRotation = CGFloat(fish.facing >= 0 ? fish.tilt : -fish.tilt)
        if fish.length > 30 || fish.frame < 0 { // the small fish of a cloud are lit once: it doesn't show on them
            framed(fish.node)
            illuminate(fish, in: school)
        }

        // The tail beats faster when swimming faster. Stepping through precomputed frames here, rather than an
        // SKAction whose speed changes every frame, which SpriteKit gets steadily slower at.
        fish.stroke += dt / school.species.beat * (0.55 + 0.8 * length(v) / cruise) * (fish.coasting ? 0.15 : 1) // tail still in a glide
        let frame = Int(fish.stroke * Double(school.beat.count)) % school.beat.count
        if frame != fish.frame {
            fish.frame = frame
            fish.node.warpGeometry = school.beat[frame]
        }
        swimmers[i] = fish
    }

    /// Lights a fish from where it swims and how it moves (see `photoShader`): brighter near the surface and under
    /// the middle of the lamp, its belly lit by the white sand when it swims low, and its flank flashing as it banks
    /// toward the lamp in a turn, or dimming as it banks away. Its shadow on the sand grows softer and fainter the
    /// higher it swims, and turns with it.
    private func illuminate(_ fish: Swimmer, in school: School) {
        let (floor, ceiling) = bounds(school.depth, height: school.species.height), sand = sandLine(CGFloat(fish.depth)), p = fish.position
        let lamp = tank == .reef ? exp(-pow((p.x / Double(size.width) - 0.5) / 0.6, 2)) : 1 // the lamp's pool, as in the water
        let high = min(max((p.y - floor) / (ceiling - floor), 0), 1)
        let turning = sin(.pi * (1 - abs(fish.facing))) * fish.bank
        let level = (0.85 + 0.2 * lamp) * (0.8 + 0.3 * high) * (1 + 0.25 * min(0, turning))
        let bounce = 0.3 * exp(-(p.y - sand) / Double(60 * unit))
        fish.node.setValue(SKAttributeValue(vectorFloat4: [1, Float(level), Float(0.3 * max(0, turning)), Float(bounce)]),
                           forAttribute: "a_fish")

        let above = max(0, p.y - sand), spread = 1 + 1.5 * above / Double(size.height), side = abs(fish.facing)
        let back = sand / Double(sandHeight) // fading out where the sand melts into the back panel
        fish.shadow.position = CGPoint(x: p.x, y: sand)
        fish.shadow.size = CGSize(width: fish.length * (0.25 + 0.75 * side) * spread, height: fish.length * (0.2 + 0.2 * (1 - side)) * spread)
        fish.shadow.alpha = 0.55 / (spread * spread) * (1 - min(max((back - 0.6) / 0.4, 0), 1))
    }

    /// Shades each fish under the strongest shadow from a fish above it in about the same plane: a band across its
    /// body, softer and fainter the further above the other fish is. One shadow per fish is plenty to read.
    private func castShadows() {
        for a in swimmers where a.length > 30 { // the small fish of a cloud neither cast nor catch them
            var best = SIMD4<Float>(0, 0, 1, 0) // centre x, half width, softness, strength
            // ponytail: O(n²) over every fish, fine for a few dozen
            for b in swimmers where b.length > 30 && b.position.y > a.position.y && abs(b.depth - a.depth) < 0.06
                && abs(b.position.x - a.position.x) < (a.length + b.length) * 0.6 {
                let drop = b.position.y - a.position.y
                let strength = 0.35 * (1 - abs(b.depth - a.depth) / 0.06) * exp(-drop / (b.length * 3))
                if strength > Double(best.w) {
                    best = SIMD4(Float(b.position.x), Float(b.length * 0.4 * (0.25 + 0.75 * abs(b.facing))),
                                 Float(b.length * 0.15 + drop * 0.25), Float(strength))
                }
            }
            a.node.setValue(SKAttributeValue(vectorFloat4: best), forAttribute: "a_shadow")
        }
    }

    private func addSchools() {
        // Species, school size, depth: a big school of chromis split over two depths, a few tangs, the clownfish
        // pair at their anemone, and the small, shy species low by the rock.
        let plan: [(Species, Int, CGFloat)] = switch tank {
        case .reef: [
            (.chromis, 14, 0.62), (.yellowTang, 3, 0.8), (.chromis, 12, 0.9), (.blueTang, 2, 0.95), (.clownfish, 2, 0.95),
            (.royalGramma, 1, 0.92), (.firefish, 2, 0.9), (.flameAngel, 1, 0.97), (.yellowTang, 1, 1.1),
        ]
        case .ocean: [ // small schools of trevally spread through the water as texture, the squadron, the big
            // animals, and the bottom-dwellers
            (.trevally, 14, 0.5), (.trevally, 14, 0.56), (.whaleShark, 1, 0.62), (.trevally, 14, 0.64), (.sandbar, 1, 0.72),
            (.trevally, 14, 0.74), (.cownose, 20, 0.75), (.manta, 1, 0.8), (.trevally, 14, 0.84), (.zebraShark, 1, 0.9),
            (.trevally, 14, 0.92), (.guitarfish, 1, 0.95), (.manta, 1, 1.0), (.whaleShark, 1, 1.05),
        ]
        case .lagoon: [
            (.blacktip, 1, 0.6), (.baitfish, 40, 0.7), (.blacktip, 2, 0.8), (.sergeantMajor, 8, 0.85), (.nurseShark, 1, 0.88),
            (.parrotfish, 1, 0.9), (.epaulette, 1, 0.93), (.butterflyfish, 2, 0.95), (.blueSpotRay, 1, 0.97), (.blacktip, 1, 1.0),
        ]
        }
        for (species, count, depth) in plan {
            let blur = max(0, 0.9 - depth) * 4 // the back school is a little out of focus
            let looks = species.photos.compactMap { TankArt.photo($0, width: species.length, blur: blur) }
            guard let first = looks.first else { continue }
            let (floor, ceiling) = bounds(depth, height: species.height)
            var school = School(species: species, depth: depth, cruise: .random(in: species.cruise) * Double(depth * unit),
                                beat: TankArt.swimWarps(species, textureHeight: first.size.height))
            switch species.haunt {
            case .anemone: school.home = SIMD2(Double(anemone.x), Double(anemone.y + 40 * unit))
            case .rock:
                let spot = rockSpots.randomElement() ?? CGPoint(x: size.width / 2, y: sandHeight)
                school.home = SIMD2(Double(spot.x), Double(spot.y))
            case .sand: school.home = SIMD2(Double.random(in: 0.15...0.85) * Double(size.width), sandLine(depth))
            case .open: break
            }
            let centre = school.home ?? SIMD2(Double.random(in: 0.15...0.85) * Double(size.width), .random(in: floor...ceiling))
            let heading = Bool.random() ? 1.0 : -1.0
            for _ in 0..<count {
                let look = looks.randomElement()!
                let node = SKSpriteNode(texture: look.texture, size: look.size)
                node.setScale(depth * fishUnit)
                node.zPosition = depth < 0.7 ? Z.farFish : depth < 1 ? Z.midFish : Z.nearFish
                node.subdivisionLevels = 1
                graded(node, fog: max(0, 0.9 - depth) * (tank == .reef ? 0.5 : 1.4), glow: 0.08)
                addChild(node)
                let shadow = SKSpriteNode(texture: shadowTexture, color: shadowColor, size: CGSize(width: 1, height: 1))
                shadow.colorBlendFactor = 1
                shadow.zPosition = Z.shadows
                addChild(shadow)
                let spread = Double(species.length * depth * fishUnit) * 2.5
                school.members.append(swimmers.count)
                swimmers.append(Swimmer(node: node, shadow: shadow, depth: Double(depth) + .random(in: -0.05...0.05),
                                        length: Double(species.length * depth * fishUnit),
                                        position: centre + SIMD2(.random(in: -spread...spread), .random(in: -spread...spread) * 0.5),
                                        velocity: SIMD2(heading * school.cruise, .random(in: -0.1...0.1) * school.cruise),
                                        facing: heading))
            }
            schools.append(school)
        }
    }

    // MARK: - Water, light and sand

    /// A reef tank's light: in Light Mode, daylight white-blue LEDs over a royal-blue back panel; in Dark Mode, the
    /// actinic blue of a reef tank's evening. The colours were sampled from real reef tank photos (the CAS Steinhart
    /// coral tank and a public-aquarium reef tank on Wikimedia Commons). `grade` tints the photo cut-outs, shot in
    /// white light, to the tank's light; `haze` is what things fade toward further back.
    private struct Lighting {
        let high, low, shimmer, sandNear, sandFar, grade, haze: SIMD3<Float>
        /// How strongly saturated pigments fluoresce: a touch under daylight LEDs, a lot under actinic blue.
        let fluoro: Float
        /// The lagoon's surface seen from below, where it mirrors the bottom.
        var mirror: SIMD3<Float> = .zero
        /// How much the sun's ripples play over the cut-outs: strong in the shallows, faint in a deep tank.
        var ripple: Float = 0.45
        static let day = Lighting(high: [0.05, 0.38, 0.90], low: [0.01, 0.12, 0.46],
                                  shimmer: [0.85, 0.95, 1.0], sandNear: [0.88, 0.84, 0.78], sandFar: [0.33, 0.45, 0.72],
                                  grade: [0.94, 0.98, 1.06], haze: [0.03, 0.26, 0.7], fluoro: 0.15)
        static let actinic = Lighting(high: [0.12, 0.14, 0.66], low: [0.02, 0.02, 0.2],
                                      shimmer: [0.6, 0.65, 1.0], sandNear: [0.5, 0.5, 0.9], sandFar: [0.16, 0.18, 0.52],
                                      grade: [0.45, 0.52, 1.05], haze: [0.07, 0.08, 0.4], fluoro: 1.5)
        // Ocean Voyager by day, sampled from visitors' photos of the window: cyan-blue lit from above, a pale floor
        // lit by the bottom lights. At night the aquarium dims to deep blue.
        static let ocean = Lighting(high: [0.18, 0.56, 0.79], low: [0.04, 0.39, 0.65],
                                    shimmer: [0.75, 0.92, 1.0], sandNear: [0.26, 0.44, 0.53], sandFar: [0.15, 0.35, 0.49],
                                    grade: [0.88, 0.98, 1.06], haze: [0.1, 0.46, 0.7], fluoro: 0, ripple: 0.25)
        static let oceanNight = Lighting(high: [0.06, 0.28, 0.5], low: [0.02, 0.12, 0.3],
                                         shimmer: [0.5, 0.7, 1.0], sandNear: [0.12, 0.26, 0.4], sandFar: [0.05, 0.18, 0.34],
                                         grade: [0.5, 0.65, 1.0], haze: [0.04, 0.22, 0.42], fluoro: 0, ripple: 0.2)
        // A reef flat in the sun, sampled from snorkellers' photos: turquoise water, white sand going turquoise-grey
        // by a few metres, the surface a darker mirror of the sand. At dusk, dimmer and bluer.
        static let lagoon = Lighting(high: [0.2, 0.64, 0.78], low: [0.08, 0.46, 0.6],
                                     shimmer: [0.95, 1.0, 1.0], sandNear: [0.8, 0.79, 0.74], sandFar: [0.23, 0.58, 0.65],
                                     grade: [0.97, 1.0, 1.0], haze: [0.1, 0.5, 0.62], fluoro: 0, mirror: [0.2, 0.5, 0.57], ripple: 0.8)
        static let lagoonDusk = Lighting(high: [0.08, 0.3, 0.46], low: [0.03, 0.2, 0.34],
                                         shimmer: [0.7, 0.8, 0.95], sandNear: [0.34, 0.4, 0.46], sandFar: [0.1, 0.28, 0.38],
                                         grade: [0.6, 0.72, 0.95], haze: [0.05, 0.24, 0.36], fluoro: 0, mirror: [0.1, 0.26, 0.34], ripple: 0.5)
    }
    private lazy var light: Lighting = switch tank {
        case .reef: systemIsDark ? .actinic : .day
        case .ocean: systemIsDark ? .oceanNight : .ocean
        case .lagoon: systemIsDark ? .lagoonDusk : .lagoon
    }

    /// The back panel and water: saturated blue, brightest high up under the lamps and falling off toward the ends
    /// and low down, faint LED shimmer on the back wall, faint rays from the lamp array, and the underside of the
    /// surface along the top, a mirror band reflecting the tank with a bright waterline.
    private func addWater() {
        let water = SKSpriteNode(color: .black, size: size)
        water.anchorPoint = .zero
        water.zPosition = Z.water
        water.shader = SKShader(source: shaderCommon + Self.caustics + Self.noise1 + """
            void main() {
                vec2 uv = v_tex_coord;
                vec2 pts = uv * u_size;
                float t = u_now;
                vec3 c = mix(u_low, u_high, smoothstep(0.05, 0.9, uv.y));
                float lamp = exp(-pow((uv.x - 0.5) / 0.6, 2.0)); // the lamp's pool of light, brightest mid-tank
                c *= 0.75 + 0.35 * lamp;

                // LED shimmer on the back wall, and faint rays from the lamp array, fading downward
                float high = smoothstep(0.2, 1.0, uv.y);
                c += u_shimmer * caustic(pts / 160.0, t * 0.6) * 0.025 * high;
                float rays = noise1(pts.x / 45.0 + sin(t * 0.1) * 1.5) * noise1(pts.x / 14.0 - t * 0.05 + 3.0);
                c += u_shimmer * smoothstep(0.3, 0.8, rays) * 0.05 * high * lamp;

                // The surface from below, a mirror: it reflects the lit water, so it's the same blue but brighter, crossed
                // by thin, crisp ripple highlights (caustic lines squashed flat by the angle), over a soft edge where it
                // meets the water, with the bright waterline above. A grey, blurry band here read as muddy.
                float band = smoothstep(0.94, 0.946, uv.y);
                if (band > 0.0) {
                    float lines = caustic(vec2(pts.x / 90.0, pts.y / 9.0), t * 0.8);
                    vec3 mirror = u_high * (1.2 + 0.15 * noise(vec2(pts.x * 0.01 + t * 0.05, pts.y * 0.05)));
                    mirror += u_shimmer * lines * 0.35;
                    c = mix(c, mirror, band);
                }
                c += u_shimmer * 0.25 * exp(-pow((uv.y - 0.943) * u_size.y / 2.0, 2.0)); // where mirror meets water
                c += u_shimmer * 0.5 * exp(-pow((uv.y - 0.975) * u_size.y / 3.0, 2.0));  // waterline
                c = mix(c, u_low * 0.4, smoothstep(0.978, 0.99, uv.y));                   // the lid above

                c += (fract(sin(dot(pts, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0; // dither
                gl_FragColor = vec4(c, 1.0);
            }
            """, uniforms: [
                SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)]),
                SKUniform(name: "u_high", vectorFloat3: light.high), SKUniform(name: "u_low", vectorFloat3: light.low),
                SKUniform(name: "u_shimmer", vectorFloat3: light.shimmer), WallpaperTime.now,
            ])
        addChild(water)
    }

    /// Smooth one-dimensional noise, for rays and shafts of light.
    private static let noise1 = """
        float hash1(float n) { return fract(sin(n * 127.1) * 43758.5453); }
        float noise1(float x) {
            float i = floor(x);
            float f = fract(x);
            return mix(hash1(i), hash1(i + 1.0), f * f * (3.0 - 2.0 * f));
        }

        """

    /// The Ocean Voyager window: cyan-blue water lit from the skylights above, shafts of light leaning down
    /// through it, the surface's shimmer far overhead, and the gallery's dark rim along the top. Colours sampled
    /// from visitors' photos of the window on Wikimedia Commons.
    private func addOceanWater() {
        let water = SKSpriteNode(color: .black, size: size)
        water.anchorPoint = .zero
        water.zPosition = Z.water
        water.shader = SKShader(source: shaderCommon + Self.caustics + Self.noise1 + """
            void main() {
                vec2 uv = v_tex_coord;
                vec2 pts = uv * u_size;
                float t = u_now;
                vec3 c = mix(u_low, u_high, smoothstep(0.0, 1.0, uv.y));
                c = mix(c, u_low * 0.6, pow(abs(uv.x - 0.5) * 2.0, 2.5) * 0.5); // navy in the far corners
                float high = smoothstep(0.3, 1.0, uv.y);
                float x = (pts.x - 0.5 * u_size.x) / (1.0 + 0.6 * (1.0 - uv.y)); // the shafts fan out from top centre
                float rays = noise1(x / 170.0 + sin(t * 0.05) * 2.0) * noise1(x / 60.0 - t * 0.03 + 3.0);
                c += u_shimmer * smoothstep(0.3, 0.85, rays) * 0.14 * high;
                c += u_shimmer * caustic(pts / 300.0, t * 0.35) * 0.012 * high;
                c = mix(c, u_low * 0.25, smoothstep(0.982, 1.0, uv.y));
                c += (fract(sin(dot(pts, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0; // dither
                gl_FragColor = vec4(c, 1.0);
            }
            """, uniforms: [
                SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)]),
                SKUniform(name: "u_high", vectorFloat3: light.high), SKUniform(name: "u_low", vectorFloat3: light.low),
                SKUniform(name: "u_shimmer", vectorFloat3: light.shimmer), WallpaperTime.now,
            ])
        addChild(water)
    }

    /// The lagoon from a snorkeller's eye: turquoise water hazing toward the horizon, faint shafts of sun, and the
    /// surface overhead seen from below, a mirror of the sandy bottom crossed by the sun's bright ripple lines,
    /// squashed flat toward the horizon and opening out overhead, with a bright line where it meets the water.
    /// Colours sampled from reef-flat photos on iNaturalist and Wikimedia Commons.
    private func addLagoonWater() {
        let water = SKSpriteNode(color: .black, size: size)
        water.anchorPoint = .zero
        water.zPosition = Z.water
        water.shader = SKShader(source: shaderCommon + Self.caustics + Self.noise1 + """
            void main() {
                vec2 uv = v_tex_coord;
                vec2 pts = uv * u_size;
                float t = u_now;
                float top = u_top;
                vec3 c = mix(u_low, u_high, smoothstep(0.0, top, uv.y));
                float high = smoothstep(0.1, top, uv.y);
                float x = pts.x + (top - uv.y) * u_size.y * 0.15;
                float rays = noise1(x / 200.0 + sin(t * 0.06) * 2.0) * noise1(x / 70.0 - t * 0.04 + 5.0);
                c += u_shimmer * smoothstep(0.35, 0.85, rays) * 0.08 * high;
                float band = smoothstep(top, top + 0.01, uv.y);
                if (band > 0.0) {
                    float v = (uv.y - top) / (1.0 - top);  // 0 at the horizon, 1 at the top of the screen
                    float squash = mix(10.0, 2.0, v);      // the ripples flatten toward the horizon
                    vec2 p = vec2(pts.x / 240.0 + t * 0.02, pts.y * squash / 240.0);
                    // long wavy streaks of light and dark, the swell's reflection, with sun glints on the ripples;
                    // paler overhead, where the sky's light comes through more directly
                    float waves = noise(p + vec2(0.0, t * 0.1)) * 0.55 + noise(p * 3.0 - vec2(t * 0.04, t * 0.2)) * 0.45;
                    float glint = caustic(vec2(pts.x / 90.0, pts.y * squash / 90.0), t * 0.5);
                    vec3 mirror = mix(u_mirror, u_high * 1.25, pow(v, 0.7) * 0.7) * (0.65 + 0.7 * waves);
                    mirror += u_shimmer * glint * 0.3 * (0.3 + 0.7 * v);
                    c = mix(c, mirror, band);
                }
                c += u_shimmer * 0.25 * exp(-pow((uv.y - top) * u_size.y / 3.0, 2.0));
                c += (fract(sin(dot(pts, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0; // dither
                gl_FragColor = vec4(c, 1.0);
            }
            """, uniforms: [
                SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)]),
                SKUniform(name: "u_top", float: Float(tank.ceiling + 0.02)),
                SKUniform(name: "u_high", vectorFloat3: light.high), SKUniform(name: "u_low", vectorFloat3: light.low),
                SKUniform(name: "u_mirror", vectorFloat3: light.mirror),
                SKUniform(name: "u_shimmer", vectorFloat3: light.shimmer), WallpaperTime.now,
            ])
        addChild(water)
    }

    /// A seabed for the open-water tanks: sand from white up front to the water's colour at the horizon, under
    /// the sun's caustic net (cells `cell` points across up front, `net` strong), with ripples in the sand
    /// (`ripples` deep) and melting into the water from `melt` of the way back.
    private func addSeabed(cell: Float, net: Float, ripples: Float, melt: Float) {
        let floorSize = CGSize(width: size.width, height: sandHeight)
        let sand = SKSpriteNode(color: .black, size: floorSize)
        sand.anchorPoint = .zero
        sand.zPosition = Z.sand
        sand.shader = SKShader(source: shaderCommon + Self.caustics + """
            void main() {
                vec2 pts = v_tex_coord * u_size;
                float back = v_tex_coord.y;
                vec3 s = mix(u_sandNear, u_sandFar, pow(back, 0.8));
                vec4 h = hash42(floor(pts * 2.0));
                float squash = mix(1.0, 0.3, back); // perspective
                float ripple = sin(pts.y / (24.0 * squash) + 2.0 * noise(vec2(pts.x * 0.012, pts.y * 0.03)));
                s *= 1.0 + u_ripples * ripple * (1.0 - 0.6 * back) + 0.05 * (h.x - 0.5) + 0.08 * (noise(pts * vec2(0.09, 0.25)) - 0.5);
                vec2 p = vec2(pts.x, pts.y * 2.6) / (u_cell * mix(1.0, 0.45, back));
                float light = caustic(p, u_now * 0.8) * 0.75 + caustic(p * 1.6 + 3.7, u_now * 1.1) * 0.3;
                s *= 1.0 + u_net * (light * 0.9 - 0.08) * (1.0 - 0.55 * back);
                s = mix(s, u_haze, smoothstep(u_melt, 1.0, back) * 0.85);
                gl_FragColor = vec4(s, 1.0);
            }
            """, uniforms: [
                SKUniform(name: "u_size", vectorFloat2: [Float(floorSize.width), Float(floorSize.height)]),
                SKUniform(name: "u_sandNear", vectorFloat3: light.sandNear), SKUniform(name: "u_sandFar", vectorFloat3: light.sandFar),
                SKUniform(name: "u_haze", vectorFloat3: light.haze), SKUniform(name: "u_cell", float: cell * Float(unit)),
                SKUniform(name: "u_net", float: net), SKUniform(name: "u_ripples", float: ripples), SKUniform(name: "u_melt", float: melt),
                WallpaperTime.now,
            ])
        addChild(sand)
    }

    /// Bright lines where the cells of a moving Voronoi pattern meet, like sunlight focused by surface waves.
    private static let caustics = """
        float caustic(vec2 p, float t) {
            // Bend the cell walls into wandering curves, at two scales.
            p += 0.3 * vec2(sin(p.y * 1.7 + t * 0.7) + 0.6 * sin(p.y * 3.3 - t * 0.9 + p.x),
                            sin(p.x * 1.5 - t * 0.6) + 0.6 * sin(p.x * 3.1 + t * 0.8 - p.y));
            vec2 i = floor(p);
            vec2 f = fract(p);
            float d1 = 8.0;
            float d2 = 8.0;
            for (int y = -1; y <= 1; y++) {
                for (int x = -1; x <= 1; x++) {
                    vec2 g = vec2(float(x), float(y));
                    vec2 h = fract(sin(vec2(dot(i + g, vec2(127.1, 311.7)), dot(i + g, vec2(269.5, 183.3)))) * 43758.5453);
                    float d = length(g + 0.5 + 0.42 * sin(t + 6.2831 * h) - f);
                    if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
                }
            }
            float edge = 1.0 - smoothstep(0.0, 0.1, d2 - d1);
            return edge * edge * 0.8 + (1.0 - smoothstep(0.0, 0.35, d2 - d1)) * 0.2;
        }

        """

    /// White aragonite sand: warm white up front under the lamp, going blue with distance, with fine grain and the
    /// lamp's shimmer rippling across it. The caustics multiply the sand they land on rather than adding white, so
    /// they brighten it the way real light does. Bigger up front, squashed by perspective.
    private func addSand() {
        let floorSize = CGSize(width: size.width, height: sandHeight)
        let sand = SKSpriteNode(color: .black, size: floorSize)
        sand.anchorPoint = .zero
        sand.zPosition = Z.sand
        sand.shader = SKShader(source: shaderCommon + Self.caustics + """
            void main() {
                vec2 pts = v_tex_coord * u_size;
                float back = v_tex_coord.y;
                vec3 s = mix(u_sandNear, u_sandFar, smoothstep(0.0, 1.0, back));
                vec4 h = hash42(floor(pts * 2.0));
                s *= 0.88 + 0.14 * noise(pts * vec2(0.18, 0.5)) + 0.1 * (h.x - 0.5); // grain and ripples in the sand
                vec2 p = vec2(pts.x, pts.y * 2.6) / mix(140.0, 60.0, back);
                float light = caustic(p, u_now * 0.7) * 0.75 + caustic(p * 1.7 + 3.7, u_now * 0.95) * 0.3;
                s *= 1.0 + light * 1.1 * (1.0 - 0.6 * back);
                s = mix(s, u_low, smoothstep(0.75, 1.0, back) * 0.5); // melting into the back panel
                gl_FragColor = vec4(s, 1.0);
            }
            """, uniforms: [
                SKUniform(name: "u_size", vectorFloat2: [Float(floorSize.width), Float(floorSize.height)]),
                SKUniform(name: "u_sandNear", vectorFloat3: light.sandNear), SKUniform(name: "u_sandFar", vectorFloat3: light.sandFar),
                SKUniform(name: "u_low", vectorFloat3: light.low), WallpaperTime.now,
            ])
        addChild(sand)
    }

    // MARK: - The reef

    /// Lights every photo cut-out as if it were in the tank. One shader shared by every fish and coral:
    /// - `u_grade` tints the white-light photos to the tank's light
    /// - things lower in the tank get a little less light, and the lamp's ripples dance over upper surfaces
    /// - under actinic blue, saturated pigments fluoresce in their own colours (`a_glow` for how much), while plain
    ///   stone just goes blue
    /// - `a_fog` fades things further back toward the back panel
    /// - fish only, set every frame: `a_fish` is (1, light level, flank flash, sand bounce), from `illuminate(_:in:)`,
    ///   lighting the back more than the belly as the lamp is overhead; `a_shadow` is a band cast by a fish above,
    ///   (centre x, half width, softness, strength), from `castShadows`
    ///
    /// `a_frame` says where the sprite is in the tank: the scene position of texture corner (0, 0), then the sprite's
    /// width (negative when flipped) and height, in points. Fish update it every frame.
    private lazy var photoShader: SKShader = {
        let shader = SKShader(source: """
            void main() {
                vec4 c = texture2D(u_texture, v_tex_coord);
                vec2 pts = a_frame.xy + v_tex_coord * a_frame.zw;
                float high = clamp(pts.y / u_height, 0.0, 1.0);
                float shade = a_shadow.w * (1.0 - smoothstep(a_shadow.y - a_shadow.z, a_shadow.y + a_shadow.z, abs(pts.x - a_shadow.x)));
                // two crossing, wandering waves: a cheap stand-in for caustics, plenty on small moving shapes
                float t = u_now;
                float ripple = pow(abs(sin(pts.x * 0.045 + 1.7 * sin(pts.y * 0.03 + t * 0.5) + t * 0.6)
                                     * sin(pts.y * 0.05 - 1.3 * sin(pts.x * 0.035 - t * 0.4) + t * 0.45)), 3.0)
                             * (0.3 + 0.7 * smoothstep(0.35, 1.0, v_tex_coord.y)) * (1.0 - shade);
                vec3 lit = c.rgb * u_grade * (0.82 + 0.28 * high) * (1.0 + ripple * u_ripple * (0.4 + 0.6 * high));
                float up = v_tex_coord.y;
                lit *= mix(1.0, a_fish.y * (0.8 + 0.4 * up) + a_fish.w * (1.0 - up), a_fish.x) * (1.0 - shade);
                lit += u_grade * c.a * a_fish.z * (0.3 + 0.7 * up) * (1.0 - shade);
                float saturation = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
                lit += c.rgb * saturation * a_glow * u_fluoro;
                gl_FragColor = vec4(mix(lit, u_haze * c.a, a_fog), c.a);
            }
            """, uniforms: [
                SKUniform(name: "u_grade", vectorFloat3: light.grade), SKUniform(name: "u_haze", vectorFloat3: light.haze),
                SKUniform(name: "u_fluoro", float: light.fluoro), SKUniform(name: "u_height", float: Float(size.height)),
                SKUniform(name: "u_ripple", float: light.ripple), WallpaperTime.now,
            ])
        shader.attributes = [SKAttribute(name: "a_fog", type: .float), SKAttribute(name: "a_glow", type: .float),
                             SKAttribute(name: "a_frame", type: .vectorFloat4), SKAttribute(name: "a_fish", type: .vectorFloat4),
                             SKAttribute(name: "a_shadow", type: .vectorFloat4)]
        return shader
    }()

    private func graded(_ node: SKSpriteNode, fog: CGFloat, glow: CGFloat) {
        node.shader = photoShader
        node.setValue(SKAttributeValue(float: Float(fog)), forAttribute: "a_fog")
        node.setValue(SKAttributeValue(float: Float(glow)), forAttribute: "a_glow")
        node.setValue(SKAttributeValue(vectorFloat4: .zero), forAttribute: "a_fish")
        node.setValue(SKAttributeValue(vectorFloat4: [0, 0, 1, 0]), forAttribute: "a_shadow")
        framed(node)
    }

    /// Tells the shader where the sprite is in the tank (see `photoShader`).
    private func framed(_ node: SKSpriteNode) {
        let w = node.size.width * node.xScale, h = node.size.height * node.yScale
        let corner = SIMD2<Float>(Float(node.position.x - node.anchorPoint.x * w), Float(node.position.y - node.anchorPoint.y * h))
        node.setValue(SKAttributeValue(vectorFloat4: [corner.x, corner.y, Float(w), Float(h)]), forAttribute: "a_frame")
    }

    /// Two islands of rock and coral, the way reefkeepers aquascape, with open sand between them for the fish to
    /// cross, and a soft, low cluster further back. Which cut-outs go where changes with each load.
    private func addReef() {
        cluster(at: CGPoint(x: size.width * .random(in: 0.42...0.58), y: sandHeight * 0.92), scale: 0.55, fog: 0.35,
                blur: 1.4, z: Z.backReef, anemone: false)
        let anemoneLeft = Bool.random()
        cluster(at: CGPoint(x: size.width * .random(in: 0.14...0.24), y: sandHeight * 0.55), scale: 1, fog: 0, blur: 0,
                z: Z.reef, anemone: anemoneLeft)
        cluster(at: CGPoint(x: size.width * .random(in: 0.76...0.86), y: sandHeight * 0.6), scale: 0.9, fog: 0.05, blur: 0,
                z: Z.reef, anemone: !anemoneLeft)
        // a colony right up against the glass in a front corner
        let corner = Bool.random() ? CGFloat.random(in: 0.02...0.08) : .random(in: 0.92...0.98)
        coral(["reef-brain-1", "reef-brain-2", "reef-brain-3", "reef-zoanthid-2"].randomElement()!, width: 230,
              at: CGPoint(x: size.width * corner, y: -12 * unit), z: Z.frontReef, sway: 0)
    }

    /// One island: a big rock with a smaller one stacked on it toward the open middle, a branching Acropora on top,
    /// soft corals on its shoulders swaying in the current, zoanthids on its face and a brain coral at its foot.
    /// `anemone` puts the clownfish's home on one shoulder. Everything is set on the rocks' real top edge, read from
    /// their silhouettes, so nothing floats however irregular the rock.
    private func cluster(at base: CGPoint, scale: CGFloat, fog: CGFloat, blur: CGFloat, z: CGFloat, anemone hasAnemone: Bool) {
        let side: CGFloat = base.x < size.width / 2 ? 1 : -1 // shoulders lean toward the open middle
        // Rock pieces: the live rock and the wide, low pile make bases, the tall porous piece stacks on top, and
        // the pale Porites boulder only suits the soft cluster at the back. No island repeats a piece.
        let back = z == Z.backReef
        let bottom = back ? ["reef-rock-4", "reef-rock-6"].randomElement()! : ["reef-rock-1", "reef-rock-4"].randomElement()!
        let stacked = ["reef-rock-3", "reef-rock-1", "reef-rock-4"].filter { $0 != bottom }.randomElement()!
        guard let rock = place(bottom, width: .random(in: 440...520) * scale, at: base, z: z, fog: fog, blur: blur, sway: 0)
        else { return }
        let w = rock.size.width, h = rock.size.height, sink = 12 * scale * unit
        var rocks = [(rock, TankArt.skyline(bottom))]
        /// The highest rock surface at x, or nil where there's no rock; `inset` keeps clear of thin, ragged edges.
        func surface(_ x: CGFloat) -> CGFloat? {
            rocks.compactMap { sprite, line -> CGFloat? in
                let width = sprite.size.width
                var u = (x - sprite.position.x) / width + 0.5
                if sprite.xScale < 0 { u = 1 - u }
                guard (0.06...0.94).contains(u), !line.isEmpty else { return nil }
                let top = line[min(Int(u * CGFloat(line.count)), line.count - 1)]
                return top > 0.12 ? sprite.position.y - 0.04 * sprite.size.height + top * sprite.size.height : nil
            }.max()
        }
        /// A spot on the rock near x: the nearest column toward the island's middle that has rock under it.
        func perch(_ x: CGFloat) -> CGPoint {
            for step in 0...12 {
                let tx = x + (base.x - x) * CGFloat(step) / 12
                if let y = surface(tx) { return CGPoint(x: tx, y: y - sink) }
            }
            return CGPoint(x: base.x, y: base.y + h * 0.5)
        }
        if let upper = place(stacked, width: w / unit * .random(in: 0.45...0.58),
                             at: perch(base.x + side * w * .random(in: 0.08...0.2)), z: z + 0.01, fog: fog, blur: blur, sway: 0) {
            // Settle it into the rock below rather than balancing it on the peak, so the island tops out around
            // mid-tank and its Acropora never reaches the surface.
            let cap = base.y + size.height * 0.36 * scale
            let excess = upper.position.y + upper.size.height * 0.96 - cap
            if excess > 0 { upper.position.y = max(upper.position.y - excess, base.y + h * 0.3) }
            framed(upper)
            rocks.append((upper, TankArt.skyline(stacked)))
            // the Acropora crowns the stacked rock, on its highest point
            let peak = stride(from: -0.3, through: 0.3, by: 0.05).map { upper.position.x + CGFloat($0) * upper.size.width }
                .max { (surface($0) ?? 0) < (surface($1) ?? 0) } ?? upper.position.x
            place(["reef-acropora-1", "reef-acropora-2"].randomElement()!, width: 320 * scale, at: perch(peak),
                  z: z + 0.02, fog: fog, blur: blur, sway: 0)
        }
        place(["reef-toadstool-1", "reef-toadstool-2", "reef-toadstool-3"].randomElement()!, width: 220 * scale,
              at: perch(base.x - side * w * 0.3), z: z + 0.03, fog: fog, blur: blur, sway: 0.03)
        if hasAnemone {
            let spot = perch(base.x + side * w * 0.36)
            place(["reef-anemone-1", "reef-anemone-2", "reef-anemone-3"].randomElement()!, width: 240 * scale,
                  at: spot, z: z + 0.04, fog: fog, blur: blur, sway: 0.05)
            self.anemone = spot
        } else {
            place(["reef-torch-1", "reef-torch-2", "reef-euphyllia-1", "reef-candycane-1"].randomElement()!, width: 210 * scale,
                  at: perch(base.x + side * w * 0.38), z: z + 0.04, fog: fog, blur: blur, sway: 0.04)
        }
        place(["reef-zoanthid-1", "reef-zoanthid-2"].randomElement()!, width: 110 * scale,
              at: CGPoint(x: base.x - side * w * 0.05, y: base.y + h * 0.22), z: z + 0.05, fog: fog, blur: blur, sway: 0)
        place(["reef-brain-1", "reef-brain-2", "reef-brain-3", "reef-porites-1"].randomElement()!, width: 170 * scale,
              at: CGPoint(x: base.x - side * w * 0.22, y: base.y - 20 * scale * unit), z: z + 0.06, fog: fog, blur: blur, sway: 0)
        if z == Z.reef { rockSpots.append(CGPoint(x: base.x + side * w * 0.55, y: base.y + h * 0.3)) }
    }

    /// A coral right up against the glass: sharp, and big.
    private func coral(_ name: String, width: CGFloat, at base: CGPoint, z: CGFloat, sway: CGFloat) {
        place(name, width: width, at: base, z: z, fog: 0, blur: 0, sway: sway)
    }

    /// Ocean Voyager's rockwork: ledges at the foot of the window's sides, far enough off to go blue and soft.
    private func addOceanRocks() {
        let ledges: [(x: CGFloat, name: String, width: CGFloat)] = [(0.06, "reef-rock-4", 0.36), (0.93, "reef-rock-1", 0.28)]
        for ledge in ledges {
            if let rock = place(ledge.name, width: size.width * ledge.width / unit, at: CGPoint(x: size.width * ledge.x, y: sandHeight * .random(in: 0.3...0.5)),
                                z: Z.backReef, fog: 0.7, blur: 2, sway: 0) { ground(rock, alpha: 0.3) }
        }
    }

    /// The lagoon's patch reef: a few coral heads standing on the sand, smaller, softer and bluer the further back.
    private func addBommies() {
        let heads = ["lagoon-porites-1", "lagoon-porites-2", "lagoon-porites-3", "lagoon-pocillopora-1", "lagoon-pocillopora-2", "lagoon-acrotable-1"].shuffled()
        let spots: [(x: CGFloat, depth: CGFloat)] = [(0.12, 0.65), (0.5, 0.58), (0.85, 0.72), (0.3, 0.9)]
        for (head, spot) in zip(heads, spots) {
            if let bommie = place(head, width: 380 * spot.depth, at: CGPoint(x: size.width * spot.x, y: sandLine(spot.depth)),
                                  z: spot.depth < 0.7 ? Z.backReef : Z.reef, fog: max(0, 0.95 - spot.depth) * 1.6,
                                  blur: max(0, 0.8 - spot.depth) * 4, sway: 0) {
                ground(bommie, alpha: 0.5)
                if spot.depth > 0.7 { rockSpots.append(CGPoint(x: bommie.position.x, y: bommie.position.y + bommie.size.height * 0.7)) }
            }
        }
    }

    /// A soft shadow on the sand under something standing on it, so it reads as set down rather than floating.
    private func ground(_ sprite: SKSpriteNode, alpha: CGFloat) {
        let shadow = SKSpriteNode(texture: shadowTexture, color: shadowColor, size: CGSize(width: sprite.size.width * 0.9, height: sprite.size.width * 0.14))
        shadow.colorBlendFactor = 1
        shadow.alpha = alpha
        shadow.position = CGPoint(x: sprite.position.x, y: sprite.position.y + sprite.size.height * 0.02)
        shadow.zPosition = Z.shadows
        addChild(shadow)
    }

    private lazy var shadowTexture = radialGlow(diameter: 32, stops: [(0, rgb(0, 0, 0)), (0.4, rgb(0, 0, 0, 0.7)), (1, rgb(0, 0, 0, 0))])
    /// Shadows on the sand are lit only by the blue of the water around them.
    private lazy var shadowColor: NSColor = {
        let shade = light.low * 0.5
        return NSColor(red: CGFloat(shade.x), green: CGFloat(shade.y), blue: CGFloat(shade.z), alpha: 1)
    }()

    /// Places one cut-out standing on `base`, graded to the tank's light, swaying from its foot by `sway` if it's
    /// soft. Returns the sprite.
    @discardableResult
    private func place(_ name: String, width: CGFloat, at base: CGPoint, z: CGFloat, fog: CGFloat, blur: CGFloat,
                       sway: CGFloat) -> SKSpriteNode? {
        guard let (texture, textureSize) = TankArt.photo(name, width: width * unit, blur: blur) else { return nil }
        let sprite = SKSpriteNode(texture: texture, size: textureSize)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.04)
        sprite.position = base
        if Bool.random() { sprite.xScale = -1 }
        sprite.zPosition = z
        graded(sprite, fog: fog, glow: name.hasPrefix("reef-rock") ? 0.1 : 1)
        if sway > 0 {
            sprite.subdivisionLevels = 1
            sprite.warpGeometry = SKWarpGeometryGrid(columns: 1, rows: 8)
            let action = TankArt.swayWarps(width: textureSize.width, height: textureSize.height, strength: sway,
                                           period: .random(in: 5...8))
            sprite.run(.sequence([.wait(forDuration: .random(in: 0...4)), action]))
        }
        addChild(sprite)
        return sprite
    }

    // MARK: - Snow and the edges

    /// Specks of organic matter drifting slowly through the whole tank.
    private func addMarineSnow() {
        let snow = SKEmitterNode()
        snow.particleTexture = softDot()
        snow.particleColor = NSColor(red: 0.8, green: 0.92, blue: 0.92, alpha: 1)
        snow.particleColorBlendFactor = 1
        snow.position = CGPoint(x: size.width / 2, y: size.height / 2)
        snow.particlePositionRange = CGVector(dx: size.width, dy: size.height)
        snow.particleBirthRate = 5
        snow.particleLifetime = 40
        snow.particleSpeed = 5
        snow.particleSpeedRange = 4
        snow.emissionAngleRange = 2 * .pi
        snow.yAcceleration = -0.5
        snow.particleScale = 0.3
        snow.particleScaleRange = 0.25
        snow.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 0.35, 0.35, 0], times: [0, 0.15, 0.85, 1])
        snow.zPosition = Z.snow
        snow.advanceSimulationTime(40)
        addChild(snow)
    }

    /// Darkens the corners, as if looking into the tank through its glass.
    private func addVignette() {
        let shade = SKSpriteNode(texture: paint(CGSize(width: 64, height: 64)) { ctx in
            let centre = CGPoint(x: 32, y: 32)
            let fade = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: [rgb(0, 0, 0, 0), rgb(0, 0, 0, 0), rgb(0, 0, 0, 0.45)] as CFArray, locations: [0, 0.6, 1])!
            ctx.drawRadialGradient(fade, startCenter: centre, startRadius: 0, endCenter: centre, endRadius: 45, options: [.drawsAfterEndLocation])
        }, size: size)
        shade.anchorPoint = .zero
        shade.zPosition = Z.vignette
        addChild(shade)
    }
}
