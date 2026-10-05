import SpriteKit

@MainActor func pixelCity(size: CGSize) -> SKScene { PixelCity(size: size) }

/// A pixel-art skyline that follows the real sun and clock: dawn, day, dusk and night skies, windows lighting
/// up and going dark through the evening, traffic on the street, a blinking antenna and the odd plane.
/// Everything lives on a low-resolution canvas measured in art pixels, scaled up with nearest filtering.
/// Settings picks the city: Street, side-on from the kerb, or Waterfront, a downtown seen across water, its walls
/// lit from wherever the Sun really is.
final class PixelCity: SKScene {
    nonisolated static let knobs = [
        Knob(key: "city.view", label: "City", range: 0...1, standard: 1, section: "City",
             format: .choice(["Street", "Waterfront"])),
        Knob(key: "city.looking", label: "Looking", range: 0...8, standard: 0, section: "City",
             format: .choice(["Toward the midday Sun", "North", "North-east", "East", "South-east", "South", "South-west", "West", "North-west"])),
        Knob(key: "city.previewTime", label: "Preview a time of day", range: 0...1, standard: 0, section: "Preview",
             format: .toggle),
        Knob(key: "city.previewHour", label: "Time", range: 0...24, standard: 19, section: "Preview", format: .clock,
             shownWhen: "city.previewTime"),
    ]
    private enum K: Int { case view, looking, previewTime, previewHour }
    private static func knob(_ k: K) -> Double { knobs[k.rawValue].value }
    private var settings = PixelCity.knobs.map(\.value)

    private let w: Int, h: Int
    private var waterfront = false
    private var streetBase = 0 // the street's bottom row: the canvas's own, or above the water and quay on the waterfront
    private var streetTop: Int { streetBase + 26 } // buildings stand on this row; road and sidewalks are below it
    private var waterTop: Int { Int(Float(h) * 0.21) } // rows of water on the waterfront
    private let quay = 6 // rows of quay wall above the water
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
    private var carLooks: [(day: SKTexture, night: SKTexture, length: Int)] = []
    private var plane = SKSpriteNode()
    private var planeLights = SKNode()
    private var beacon = SKNode()
    // Light on the waterfront's walls: what the sky gives every wall, and what the Sun or Moon adds to one facing it.
    private var ambient = RGB.one, keyFront = RGB.zero, keyLeft = RGB.zero, keyRight = RGB.zero, keyTop = RGB.zero
    private var behind = RGB.zero // the horizon's colour at our backs, which glass fronts mirror
    private var span: Double { waterfront ? 260 : 200 } // degrees of compass across the screen

    private var night: Float = 0 // 0 in daylight … 1 at full dark
    private var hour = 12.0      // local clock, 0–24
    private var clock: TimeInterval = 0
    private var lastUpdate: TimeInterval?
    private var nextCar: [TimeInterval] = [0, 0]
    private var nextPlane = TimeInterval.random(in: 3...25)
    private var planeX: Float = 0, planeDirection: Float = 0

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
        guard picked != settings else { return }
        if picked[K.view.rawValue] != settings[K.view.rawValue] { layOut() }
        settings = picked
        redraw()
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
        (nextCar, planeDirection) = ([clock, clock], 0)
        waterfront = Self.knob(.view) > 0.5
        streetBase = waterfront ? waterTop + quay : 0
        for (node, z) in [(sky, 0.0), (backdrop, 2)] {
            node.anchorPoint = .zero
            node.size = CGSize(width: w, height: h)
            node.zPosition = z
            canvas.addChild(node)
        }
        var rng = SeededRandom(state: 2026)
        let tower = waterfront ? layOutWaterfront(&rng) : layOutStreet(&rng)
        beacon.position = CGPoint(x: tower.x, y: tower.y)
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
                node.position.y = CGFloat(streetBase + (lane == 0 ? 5 : 13))
                node.zPosition = lane == 0 ? 4 : 3
                node.xScale = lane == 0 ? 1 : -1
                node.isHidden = true
                let beam = SKSpriteNode(texture: headlightBeam)
                beam.anchorPoint = CGPoint(x: 0, y: 0)
                beam.size = CGSize(width: 14, height: 4)
                beam.blendMode = .add // light on the road, not a grey shape in the air
                beam.zPosition = -0.5 // under the car ahead
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
        if waterfront { addWater() }
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
        return (tower.x + tower.width / 2, streetTop + tower.height + 18)
    }

    /// The Waterfront city: a downtown that peaks in the middle and low flanks with gaps in them, where the Sun and
    /// Moon rise and set in view. Three rows deep: windowless towers in the haze, a far row, and a near row of four
    /// kinds of building, with a park here and there. Returns the top of the landmark's spire, for the beacon.
    private func layOutWaterfront(_ rng: inout SeededRandom) -> (x: Int, y: Int) {
        rng = SeededRandom(state: 2030) // picked from a handful for its skyline, and for parks where the Sun sets
        let room = Float(h - streetTop) // the sky above the street: heights are shares of it
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
        return (tower.x + tower.width / 2, streetTop + tower.height + 18)
    }

    /// The water in front of the waterfront: a shader that mirrors the quay and the city above it, row by rippling row.
    private func addWater() {
        let node = SKSpriteNode(color: .black, size: CGSize(width: w, height: waterTop))
        node.anchorPoint = .zero
        node.zPosition = 2.5
        mirrored = [SKUniform(name: "u_sky", texture: nil), SKUniform(name: "u_city", texture: nil)]
        waterTints = [SKUniform(name: "u_deep", vectorFloat3: .zero), SKUniform(name: "u_glint", vectorFloat3: .zero)]
        node.shader = SKShader(source: Self.waterShader, uniforms: mirrored + waterTints + [
            SKUniform(name: "u_canvas", vectorFloat2: [Float(w), Float(h)]),
            SKUniform(name: "u_water", vectorFloat4: [Float(w), Float(waterTop), Float(streetTop), Float(quay)]),
            WallpaperTime.now,
        ])
        canvas.addChild(node)
    }

    // ponytail: only the backdrop is mirrored, so cars and clouds have no reflection; mirror their sprites if it shows
    private static let waterShader = """
    void main() {
        vec2 p = floor(v_tex_coord * u_water.xy);   // this art pixel, counted from the water's bottom left
        float d = u_water.y - 1.0 - p.y;            // rows below the quay
        float near = d / u_water.y;                 // 0 at the quay, 1 nearest us
        // Ripples slide each row sideways by whole pixels, wider toward us.
        float wave = sin(d * 1.1 + u_now * 1.1) + sin(d * 0.43 - u_now * 0.6);
        float shift = floor(wave * (0.3 + near * 1.3) + 0.5);
        // The mirror image: the quay wall, then the city from street level up, squashed. The street lies flat, out of sight.
        float row = d < u_water.w ? u_water.y + d : u_water.z + (d - u_water.w) * 1.8;
        vec2 uv = (vec2(p.x + shift, min(row, u_canvas.y - 1.0)) + 0.5) / u_canvas;
        vec4 city = texture2D(u_city, uv);
        vec3 c = texture2D(u_sky, uv).rgb * (1.0 - city.a) + city.rgb;
        c = mix(c, u_deep, 0.3 + 0.4 * near) * (0.94 - 0.2 * near);
        // Glints: short dashes of sky on every other row, drifting.
        float cell = floor((p.x + floor(u_now * (0.6 + near))) / 5.0);
        float chance = fract(sin(cell * 12.9898 + d * 78.233) * 43758.5453);
        c += u_glint * step(0.93, chance) * mod(d, 2.0) * 0.12;
        gl_FragColor = vec4(c, 1.0);
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
        let band: Float = waterfront ? 0.4 : 1 // how much of each band is dithered into the next
        let sunSpot = place(sun, latitude: spot.latitude)
        let glow = smoothstep(-10, 0, el) * (1 - smoothstep(6, 20, el)) * 0.7 + 0.15 * smoothstep(0, 10, el)
        let glowColour = mix(rgb(255, 128, 64), rgb(255, 214, 150), smoothstep(-2, 10, el))
        let reach = mix(1, 0.35, smoothstep(4, 20, el)) // a low sun lights a wide band of sky, a high one a small halo
        for y in 0..<h {
            let t = max(0, Float(y - streetTop) / Float(h - streetTop))
            for x in 0..<w {
                let d = bayer(x, y)
                var c = mix(horizons[x], top, pow(min(1, (t * 14 + (1 - band) / 2 + d * band).rounded(.down) / 14), 0.6))
                if waterfront, night > 0 { // the city's own glow in the night sky, strongest over downtown
                    let u = Float(x) / Float(w) - 0.5
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
            // Over the waterfront the city's glow drowns the stars near the horizon.
            let clear = waterfront ? smoothstep(0.1, 0.6, Float(star.y - streetTop) / Float(h - streetTop)) * 0.8 : 1
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
        (keyFront, keyLeft, keyRight, keyTop) = (.zero, .zero, .zero, .zero)
        for (body, colour) in [(sun, mix(rgb(255, 126, 54), rgb(255, 240, 214), smoothstep(0, 20, el)) * smoothstep(-1.5, 5, el) * mix(0.95, 0.62, smoothstep(0, 20, el))),
                               (moon, rgb(120, 140, 200) * Float(1 - cos(2 * .pi * moonPhase)) * smoothstep(0, 10, Float(moon.elevation)) * night * 0.15)] {
            let bearing = Float(body.azimuth - facing) * .pi / 180 // 0 straight ahead, positive to the right
            let height = Float(max(body.elevation, 0)) * .pi / 180
            keyRight += colour * max(0, sin(bearing)) * cos(height)
            keyLeft += colour * max(0, -sin(bearing)) * cos(height)
            keyFront += colour * max(0, -cos(bearing)) * cos(height)
            keyTop += colour * (0.3 + 0.7 * sin(height))
        }
        if waterfront {
            drawHorizon(into: &px, zenith: top, horizon: horizon)
        }
        for building in skyline {
            let haze = horizons[min(max(building.x + building.width / 2, 0), w - 1)] // the horizon behind it
            if building.kind == .box { draw(building, into: &px, horizon: haze) } else { drawTower(building, into: &px, zenith: top, horizon: haze) }
        }
        drawParks(into: &px)
        drawStreet(into: &px)
        if waterfront { drawQuay(into: &px) }
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
        let room = Double(h - streetTop - 14)
        guard waterfront else { return (Int(Double(w) * (0.5 + dx / span)), streetTop + Int(p.elevation / 70 * room)) }
        // The waterfront looks wider, so sunrise and sunset stay on screen all year, gives a low Sun or Moon more
        // room, and drops them out of sight as soon as they set.
        let lift = p.elevation < 0 ? p.elevation / 12 : pow(p.elevation / 70, 0.75)
        return (Int(Double(w) * (0.5 + dx / span)), streetTop + Int(lift * room))
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
        let haze: Float = b.kind == .haze ? 0.8 : b.far ? mix(0.42, 0.3, night) : 0, distance = mix(horizon, zenith, 0.3)
        func tone(_ c: RGB) -> RGB { mix(c, distance, haze) }
        let front = tone(lit(b.colour, keyFront)), flank = tone(lit(b.colour, onRight ? keyRight : keyLeft, shade: 0.72))
        let edge = tone(lit(b.colour, keyTop, shade: 1.1)), metal = tone(mix(rgb(70, 70, 80), rgb(14, 14, 22), night))
        let glass = tone(lit(b.colour * 0.45, .zero) + zenith * 0.2 + rgb(10, 14, 26) * night) // unlit windows mirror a little sky
        let base = streetTop, top = base + b.height, dark = night > 0.15, glow = min(1, night * 1.6)
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
        case .box: break
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
        if !b.far, b.kind != .deco, b.height > (h - streetTop) * 2 / 5 {
            for x in [b.x, b.x + b.width - 1] { px.plot(x, top, rgb(255, 60, 50), night) }
        }
    }

    /// The share of office floors lit at this hour: half of them at dusk, a few all night.
    private var officeShare: Float {
        let evening = Float(hour < 12 ? hour + 24 : hour) // runs the evening on past midnight
        if hour >= 5 && hour < 12 { return mix(0.08, 0.45, smoothstep(5.5, 8, Float(hour))) }
        return mix(0.5, 0.08, smoothstep(18, 24, evening))
    }

    /// The far shore behind the waterfront: low hills in the haze, seen through the gaps and over the low roofs.
    private func drawHorizon(into px: inout Pixels, zenith: RGB, horizon: RGB) {
        let hill = mix(horizon * 0.82, zenith, 0.25)
        for x in 0..<w {
            let f = Float(x)
            px.fill(x, streetTop, 1, Int(4.5 + 2.5 * sin(f * 0.023 + 1) + 1.6 * sin(f * 0.061 + 4) + 0.8 * sin(f * 0.13)), hill)
        }
    }

    /// The parks in the waterfront's gaps: a hedge and a few round trees, lit from the Sun's side.
    private func drawParks(into px: inout Pixels) {
        let leaf = rgb(72, 118, 70), fromRight = keyRight.sum() >= keyLeft.sum()
        let (bright, mid, shade) = (lit(leaf, keyTop, shade: 1.1), lit(leaf * 0.85, .zero), lit(leaf * 0.62, .zero))
        for park in parks {
            var rng = SeededRandom(state: UInt64(park.x + 1000))
            px.fill(park.x, streetTop, park.width, 2, shade) // hedge
            var x = park.x + 4
            while x < park.x + park.width - 2 {
                let r = Int.random(in: 3...5, using: &rng), cy = streetTop + 3 + r + Int.random(in: 0...2, using: &rng)
                px.fill(x, streetTop, 1, cy - streetTop, lit(rgb(84, 62, 48), .zero))
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
        px.fill(0, waterTop, w, quay, stone)
        px.fill(0, waterTop + quay - 1, w, 1, lit(rgb(172, 164, 150), keyTop)) // coping
        px.fill(0, waterTop, w, 1, stone * 0.55)
        for course in 0...1 {
            for x in stride(from: course * 7, to: w, by: 14) { px.fill(x, waterTop + 1 + course * 2, 1, 2, stone * 0.82) }
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
        if waterfront {
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
    private func vehicle(_ rows: [String], body: RGB) -> (day: SKTexture, night: SKTexture, length: Int) {
        func look(_ dark: Bool) -> SKTexture {
            let paint = dark ? body * RGB(0.46, 0.48, 0.62) : body
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

/// What a building is: the Street's plain block, or on the waterfront a windowless tower in the haze, a stone
/// tower with setbacks, a glass curtain wall, a brick walk-up over a shop, or a concrete slab with ribbon windows.
private enum Kind { case box, haze, deco, glass, brick, slab }

private struct Building {
    var x: Int, width: Int, height: Int
    var colour: RGB
    var far: Bool
    var floor: Int, pitch: Int // window spacing, vertical and horizontal
    var roof: Roof
    var seed: UInt64
    var kind = Kind.box
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
