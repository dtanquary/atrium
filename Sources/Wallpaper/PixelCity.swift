import SpriteKit

@MainActor func pixelCity(size: CGSize) -> SKScene { PixelCity(size: size) }

/// A pixel-art skyline that follows the real sun and clock: dawn, day, dusk and night skies, windows lighting
/// up and going dark through the evening, traffic on the street, a blinking antenna and the odd plane.
/// Everything lives on a low-resolution canvas measured in art pixels, scaled up with nearest filtering.
final class PixelCity: SKScene {
    private let fixedTime: Date? // snapshot seam: show this moment instead of now
    private let w: Int, h: Int
    private let streetTop = 26 // buildings stand on this row; road and sidewalks are below it
    private let canvas = SKNode()
    private let backdrop = SKSpriteNode()
    private var skyline: [Building] = []
    private var stars: [(x: Int, y: Int, brightness: Float)] = []
    private var clouds: [Cloud] = []
    private var cars: [Car] = []
    private var carLooks: [(day: SKTexture, night: SKTexture, length: Int)] = []
    private let plane = SKSpriteNode()
    private let planeLights = SKNode()
    private let beacon = SKNode()

    private var night: Float = 0 // 0 in daylight … 1 at full dark
    private var hour = 12.0      // local clock, 0–24
    private var clock: TimeInterval = 0
    private var lastUpdate: TimeInterval?
    private var nextCar: [TimeInterval] = [0, 0]
    private var nextPlane = TimeInterval.random(in: 3...25)
    private var planeX: Float = 0, planeDirection: Float = 0

    init(size: CGSize, at fixedTime: Date? = nil) {
        self.fixedTime = fixedTime
        let pixel = max(2, (size.height / 240).rounded()) // points per art pixel
        w = Int((size.width / pixel).rounded(.up))
        h = Int((size.height / pixel).rounded(.up))
        super.init(size: size)
        canvas.setScale(pixel)
        addChild(canvas)
        backdrop.anchorPoint = .zero
        backdrop.size = CGSize(width: w, height: h)
        canvas.addChild(backdrop)
        layOut()
        redraw()
        run(.repeatForever(.sequence([.wait(forDuration: 30), .run { [weak self] in self?.redraw() }])))
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func didMove(to view: SKView) {
        Location.shared.start()
    }

    // MARK: - Layout (once)

    /// Generates everything that never changes: skyline, stars, cloud shapes, the car pool, antenna and plane.
    private func layOut() {
        var rng = SeededRandom(state: 2026)
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
        beacon.position = CGPoint(x: tower.x + tower.width / 2, y: streetTop + tower.height + 18)
        beacon.addChild(SKSpriteNode(color: NSColor(red: 1, green: 0.2, blue: 0.2, alpha: 0.3), size: CGSize(width: 3, height: 3)))
        beacon.addChild(SKSpriteNode(color: NSColor(red: 1, green: 0.25, blue: 0.2, alpha: 1), size: CGSize(width: 1, height: 1)))
        beacon.zPosition = 5
        beacon.run(.repeatForever(.sequence([.fadeAlpha(to: 1, duration: 0), .wait(forDuration: 0.25),
                                             .fadeAlpha(to: 0.15, duration: 0), .wait(forDuration: 1.25)])))
        canvas.addChild(beacon)

        stars = (0..<170).map { _ in
            (Int.random(in: 0..<w, using: &rng), Int.random(in: streetTop + 30..<h, using: &rng), Float.random(in: 0.35...1, using: &rng))
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
        carLooks = paints.map { vehicle(sedan, body: $0) } + [vehicle(bus, body: rgb(228, 150, 40))]
        for lane in 0...1 {
            for _ in 0..<6 {
                let node = SKSpriteNode()
                node.anchorPoint = CGPoint(x: 0.5, y: 0)
                node.position.y = CGFloat(lane == 0 ? 5 : 13)
                node.zPosition = lane == 0 ? 4 : 3
                node.xScale = lane == 0 ? 1 : -1
                node.isHidden = true
                let beam = SKSpriteNode(texture: headlightBeam)
                beam.anchorPoint = CGPoint(x: 0, y: 0)
                beam.size = CGSize(width: 12, height: 5)
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
        plane.zPosition = 2
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
    }

    // MARK: - Time of day (every 30 s)

    /// Repaints everything that follows the clock: sky, sun, moon, stars, buildings, windows and street lights,
    /// then recolours the clouds, cars and plane to match.
    private func redraw() {
        let now = fixedTime ?? Date()
        let spot = Location.shared.coordinate
        let sun = skyPosition(now, latitude: spot.latitude, longitude: spot.longitude)
        let moonAge = ((now.timeIntervalSince1970 - 947_182_440) / 86_400).truncatingRemainder(dividingBy: 29.530588853)
        let moonPhase = moonAge / 29.530588853 // 0 new, 0.5 full
        let moon = skyPosition(now, latitude: spot.latitude, longitude: spot.longitude, eclipticOffset: moonPhase * 360)
        let parts = Calendar.current.dateComponents([.hour, .minute], from: now)
        hour = Double(parts.hour ?? 12) + Double(parts.minute ?? 0) / 60
        let el = Float(sun.elevation)
        night = smoothstep(4, -8, el)
        let (top, horizon) = skyColours(el, morning: hour < 12)
        var px = Pixels(w, h)

        // Sky: banded and dithered like old pixel art, glowing around a low sun.
        let sunSpot = place(sun, latitude: spot.latitude)
        let glow = smoothstep(-10, 0, el) * (1 - smoothstep(6, 20, el)) * 0.7 + 0.15 * smoothstep(0, 10, el)
        let glowColour = mix(rgb(255, 128, 64), rgb(255, 214, 150), smoothstep(-2, 10, el))
        let reach = mix(1, 0.35, smoothstep(4, 20, el)) // a low sun lights a wide band of sky, a high one a small halo
        for y in 0..<h {
            let t = max(0, Float(y - streetTop) / Float(h - streetTop))
            for x in 0..<w {
                let d = bayer(x, y)
                var c = mix(horizon, top, pow(min(1, (t * 14 + d).rounded(.down) / 14), 0.6))
                if glow > 0 {
                    let gx = Float(x - sunSpot.x) / (90 * reach), gy = Float(y - sunSpot.y) / (40 * reach)
                    c = mix(c, glowColour, (glow * exp(-(gx * gx + gy * gy)) * 5 + d).rounded(.down) / 5)
                }
                px.plot(x, y, pointwiseMin(c, .one))
            }
        }

        let starlight = smoothstep(-5, -12, el)
        for star in stars where starlight > 0 {
            let a = starlight * star.brightness
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

        for building in skyline { draw(building, into: &px, horizon: horizon) }
        drawStreet(into: &px)
        backdrop.texture = px.texture()

        // Sprites that change colour with the light.
        let dusk = smoothstep(14, 2, el) * (1 - night)
        let light = mix(mix(rgb(250, 250, 252), horizon, dusk * 0.6), rgb(64, 68, 100), night)
        let shade = mix(mix(rgb(196, 206, 226), top, dusk * 0.5), rgb(38, 40, 66), night)
        for cloud in clouds {
            cloud.node.texture = cloud.texture(light: light, shade: shade)
            cloud.node.alpha = CGFloat(mix(0.95, 0.7, night))
        }
        for car in cars { car.node.texture = night > 0.5 ? carLooks[car.look].night : carLooks[car.look].day }
        for car in cars { car.beam.alpha = CGFloat(smoothstep(0.3, 0.8, night)) }
        plane.color = NSColor(red: 0.05, green: 0.06, blue: 0.1, alpha: 1) // a dark silhouette after sunset
        plane.colorBlendFactor = CGFloat(night * 0.85)
        planeLights.alpha = CGFloat(mix(0.4, 1, night))
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

    /// Where a sky position lands on the canvas, looking toward the equator (so east is on the left up north).
    private func place(_ p: (elevation: Double, azimuth: Double), latitude: Double) -> (x: Int, y: Int) {
        let dx = (p.azimuth - (latitude >= 0 ? 180 : 0) + 540).truncatingRemainder(dividingBy: 360) - 180
        return (Int(Double(w) * (0.5 + dx / 200)), streetTop + Int(p.elevation / 70 * Double(h - streetTop - 14)))
    }

    /// The moon's disc with its current phase lit on the right while waxing, the left while waning.
    private func drawMoon(into px: inout Pixels, at spot: (x: Int, y: Int), phase: Double, alpha: Float) {
        let r = 5, k = Float(cos(2 * .pi * phase))
        for dy in -r...r {
            for dx in -r...r {
                let nx = Float(dx) / Float(r), ny = Float(dy) / Float(r)
                guard nx * nx + ny * ny <= 1.1 else { continue }
                let edge = k * (max(0, 1 - ny * ny)).squareRoot()
                let lit = phase < 0.5 ? nx > edge : nx < -edge
                let crater = [(-2, 1), (1, 2), (-1, -2), (2, -1), (-3, -1)].contains { $0 == (dx, dy) }
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
        if b.far { facade = mix(facade, horizon, mix(0.42, 0.3, night)) }
        let metal = mix(rgb(70, 70, 80), rgb(14, 14, 22), night)
        let top = streetTop + b.height
        px.fill(b.x, streetTop, b.width, b.height, facade)
        px.fill(b.x + b.width - 1, streetTop, 1, b.height, facade * 0.8)
        px.fill(b.x, top - 1, b.width, 1, pointwiseMin(facade * 1.15, .one))

        switch b.roof {
        case .plain: break
        case .ledge: px.fill(b.x - 1, top - 2, b.width + 2, 1, facade * 0.75)
        case .setback:
            px.fill(b.x + 3, top, b.width - 6, 6, facade)
            px.fill(b.x + b.width - 4, top, 1, 6, facade * 0.8)
        case .tank where !b.far:
            let tx = b.x + b.width / 3
            px.fill(tx, top, 1, 2, metal)
            px.fill(tx + 3, top, 1, 2, metal)
            px.fill(tx, top + 2, 4, 4, mix(rgb(120, 84, 60), rgb(24, 20, 24), night))
            px.fill(tx + 1, top + 6, 2, 1, mix(rgb(120, 84, 60), rgb(24, 20, 24), night))
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
        for y in stride(from: streetTop + 3, through: top - 3 - size, by: b.floor) {
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

    /// Whether a window with these three random draws has its light on at the current hour.
    private func isLit(_ a: Float, _ b: Float, _ c: Float) -> Bool {
        if c > 0.97 { return true } // stairwells and night owls
        let evening = Float(hour < 12 ? hour + 24 : hour) // runs the evening on past midnight
        if c < 0.65 && evening >= 16.5 + a * 4.5 && evening < 21 + b * 6 { return true } // home 16:30–21:00, bed 21:00–03:00
        return c < 0.3 && Float(hour) >= 5.5 + a * 1.5 && Float(hour) < 7.5 + b * 1.5 // early risers
    }

    /// Sidewalks, road markings and street lamps that pool light onto the road at night.
    private func drawStreet(into px: inout Pixels) {
        let walk = mix(rgb(150, 146, 140), rgb(36, 36, 50), night)
        let road = mix(rgb(62, 62, 70), rgb(20, 20, 30), night)
        px.fill(0, 21, w, 5, walk)
        px.fill(0, 21, w, 1, walk * 0.72)
        for x in stride(from: 0, to: w, by: 12) { px.fill(x, 22, 1, 4, walk * 0.9) } // paving joints
        px.fill(0, 4, w, 17, road)
        px.fill(0, 0, w, 4, walk)
        px.fill(0, 3, w, 1, pointwiseMin(walk * 1.12, .one))
        for x in stride(from: 0, to: w, by: 10) { px.fill(x, 12, 5, 1, mix(rgb(214, 200, 120), rgb(84, 80, 56), night)) }

        let warm = rgb(255, 214, 140)
        for lx in stride(from: 12, to: w, by: 46) {
            let pole = mix(rgb(56, 58, 64), rgb(10, 10, 16), night)
            px.fill(lx, 23, 1, 13, pole)
            px.fill(lx, 36, 4, 1, pole)
            px.fill(lx + 2, 35, 2, 1, mix(rgb(110, 110, 104), rgb(255, 238, 180), night))
            guard night > 0.3 else { continue }
            // A pool of light in three flat steps, brightest under the lamp.
            for (rx, ry, a) in [(13, 5, 0.1), (9, 3.5, 0.1), (5, 2, 0.12)] as [(Float, Float, Float)] {
                for dy in -6...6 {
                    for dx in -14...14 where (Float(dx) / rx) * (Float(dx) / rx) + (Float(dy) / ry) * (Float(dy) / ry) <= 1 {
                        px.plot(lx + 3 + dx, 19 + dy, warm, a * night)
                    }
                }
            }
            for dy in -2...2 { for dx in -2...3 where dx * dx + dy * dy <= 5 { px.plot(lx + 2 + dx, 35 + dy, warm, 0.25 * night) } }
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
        guard !cars.contains(where: { $0.lane == lane && !$0.node.isHidden && abs($0.x - x) < 36 }),
              let i = cars.firstIndex(where: { $0.lane == lane && $0.node.isHidden }) else { return }
        let isBus = Float.random(in: 0..<1) < 0.1
        cars[i].look = isBus ? carLooks.count - 1 : Int.random(in: 0..<carLooks.count - 1)
        cars[i].cruise = isBus ? .random(in: 11...14) : .random(in: 14...22)
        cars[i].speed = cars[i].cruise
        cars[i].x = x
        let look = carLooks[cars[i].look]
        cars[i].length = Float(look.length)
        cars[i].node.texture = night > 0.5 ? look.night : look.day
        cars[i].node.size = CGSize(width: look.length, height: isBus ? 10 : 7)
        cars[i].beam.position = CGPoint(x: CGFloat(look.length) / 2, y: isBus ? 2 : 1)
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

    private lazy var headlightBeam: SKTexture = {
        var px = Pixels(12, 5)
        for x in 0..<12 {
            for y in 0..<5 where abs(y - 2) <= (x < 3 ? 0 : x < 7 ? 1 : 2) {
                px.plot(x, y, rgb(255, 240, 180), x < 3 ? 0.4 : x < 7 ? 0.22 : 0.1)
            }
        }
        return px.texture()
    }()

    /// Day and night textures for a vehicle drawn as `rows`, painted in `body`.
    private func vehicle(_ rows: [String], body: RGB) -> (day: SKTexture, night: SKTexture, length: Int) {
        func look(_ dark: Bool) -> SKTexture {
            let paint = dark ? body * RGB(0.35, 0.37, 0.5) : body
            return art(rows, ["B": paint, "#": paint * 0.85, "d": paint * 0.65,
                              "w": dark ? rgb(30, 36, 52) : rgb(150, 186, 216),
                              "W": dark ? rgb(255, 220, 140) : rgb(150, 186, 216),
                              "h": dark ? rgb(255, 250, 215) : rgb(232, 232, 218),
                              "t": dark ? rgb(255, 50, 50) : rgb(150, 30, 30), "o": rgb(24, 24, 30)])
        }
        return (look(false), look(true), rows[0].count)
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

private struct Building {
    var x: Int, width: Int, height: Int
    var colour: RGB
    var far: Bool
    var floor: Int, pitch: Int // window spacing, vertical and horizontal
    var roof: Roof
    var seed: UInt64
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
