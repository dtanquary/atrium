import SpriteKit

@MainActor func pixelWindowSeat(size: CGSize) -> SKScene { PixelWindowSeat(size: size) }

/// The view from a window seat of an airliner that never lands, in Pixel City's pixel art. Outside is an endless
/// land made up as we go (`SeatWorld`): ocean, coast, city and farmland, under cloud that comes and goes, lit by the
/// real Sun and Moon where you are. The ground is drawn a row at a time: every row of the picture is a strip of the
/// world at one distance, which slides sideways by whole pixels at its own speed, the near rows fast and the far ones
/// barely at all. The cloud layer is a second set of strips nearer to us, its clouds standing up as columns.
final class PixelWindowSeat: SKScene {
    nonisolated static let seat = Knob(key: "seat.wing", label: "Seat", range: 0...1, standard: 0, section: "View",
                                       format: .choice(["Over the wing", "Ahead of the wing"]))
    nonisolated static let looking = Knob(key: "seat.looking", label: "Looking", range: 0...8, standard: 0, section: "View",
                                          format: .choice(["Toward the midday Sun", "North", "North-east", "East", "South-east", "South", "South-west", "West", "North-west"]))
    /// 1× is a real airliner, whose ground takes a minute and a half to cross the window: too still for a wallpaper,
    /// so it flies at three times that unless asked.
    nonisolated static let speed = Knob(key: "seat.speed", label: "Speed", range: 0.5...10, standard: 3, section: "Flight", format: .times)
    nonisolated static let scenery = Knob(key: "seat.scenery", label: "Scenery", range: 0...3, standard: 0, section: "Flight",
                                          format: .choice(["Changing", "Ocean", "City", "Countryside"]))
    nonisolated static let clouds = Knob(key: "seat.clouds", label: "Clouds", range: 0...4, standard: 0, section: "Flight",
                                         format: .choice(["Changing", "Clear", "Scattered", "Broken", "Overcast"]))
    nonisolated static let previewTime = Knob(key: "seat.previewTime", label: "Preview a time of day", range: 0...1, standard: 0,
                                              section: "Preview", format: .toggle)
    nonisolated static let previewHour = Knob(key: "seat.previewHour", label: "Time", range: 0...24, standard: 19, section: "Preview",
                                              format: .clock, shownWhen: "seat.previewTime")
    nonisolated static let knobs = [seat, looking, speed, scenery, clouds, previewTime, previewHour]

    /// How high we fly and where the cloud layer's base is, in km, and how fast, in km a second (Mach 0.78 or so).
    nonisolated static let cruise = 11.0, deck = 2.4, pace = 0.25
    /// How many pixels of contrail another airliner leaves behind it.
    private static let trail = 110

    private let w: Int, h: Int // the canvas, in art pixels
    private let glass: (x: Int, y: Int, w: Int, h: Int) // the window's pane on it
    private let horizon: Int // the pane's row the horizon lies on, counted from its bottom; the rows below are ground
    private var rows: [Row] = []
    private var world = SeatWorld()
    // What each row of ground shows, as rings a pane wide: a pixel keeps its place in the ring from the moment it
    // slides in until it slides out, so a row moving on a pixel costs one new pixel.
    private var land: [UInt8], glow: [UInt8], tall: [UInt8], cloud: [UInt8]
    private var sky: [UInt32], glint: [UInt8], picture: [UInt32], ceiling: [Int]
    private var wing: [(at: Int, part: UInt8, flash: UInt8)] = []
    private var paint = Paint()
    private let texture: SKMutableTexture
    private let canvas = SKNode(), outside = SKSpriteNode(), cabin = SKSpriteNode()

    /// How far the flight has got, in km along its track, and the scene time that was true at. Every copy of the
    /// scene shares it, so each display's window, and Settings' preview, looks out over the same country. It starts
    /// from the clock: the flight goes on while nobody is watching. (`SEAT_AT=15500` in the environment starts it at
    /// that km instead, so a screenshot can be taken over the same country again.)
    static var flown = ProcessInfo.processInfo.environment["SEAT_AT"].flatMap(Double.init)
        ?? Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 4_000_000) * pace
    private static var flownAt: TimeInterval?
    private var settings: [Double] = []
    private var retired = false // it has handed over to a scene of another world, and is fading out
    private var kmPerSecond = PixelWindowSeat.pace
    private var night: Float = 0, sunUp: Float = 0
    private var clock: TimeInterval = 0, lastUpdate: TimeInterval?, painted: TimeInterval = -1
    // Another airliner, now and then, crossing far off at our height with its contrail behind it: where its nose is
    // on the pane, which way it's going, and how steeply its track lies across the picture.
    private var other: (x: Float, y: Float, way: Float, slant: Float)?
    var nextOther = TimeInterval.random(in: 15...70) // by the scene's clock (a test brings it on at once)
    private var redrawnAt = Date.distantPast // wall clock, as in Pixel City: a wallpaper paused through sunset catches up at once

    override init(size: CGSize) {
        let pixel = max(2, (size.height / 240).rounded()) // points per art pixel, as in Pixel City
        w = Int((size.width / pixel).rounded(.up))
        h = Int((size.height / pixel).rounded(.up))
        // One window, wider than a real one so it fills a wide screen, and no taller than a real one on a tall screen.
        var (gw, gh) = (max(w * 76 / 100, 16), max(h * 76 / 100, 16))
        gw = min(gw, gh * 8 / 5)
        gh = min(gh, gw * 29 / 20)
        glass = ((w - gw) / 2, (h - gh) / 2 + 3, gw, gh)
        horizon = gh * 62 / 100
        (land, glow, tall, cloud) = ([UInt8](repeating: 0, count: gw * horizon), [UInt8](repeating: 0, count: gw * horizon),
                                     [UInt8](repeating: 0, count: gw * horizon), [UInt8](repeating: 0, count: gw * horizon))
        (sky, glint, picture) = ([UInt32](repeating: 0, count: gw * gh), [UInt8](repeating: 0, count: gw * horizon), [UInt32](repeating: 0, count: gw * gh))
        ceiling = [Int](repeating: -1, count: gw)
        texture = SKMutableTexture(size: CGSize(width: gw, height: gh))
        super.init(size: size)
        canvas.setScale(pixel)
        addChild(canvas)
        texture.filteringMode = .nearest
        outside.texture = texture
        outside.size = CGSize(width: gw, height: gh)
        outside.anchorPoint = .zero
        outside.position = CGPoint(x: glass.x, y: glass.y)
        (cabin.size, cabin.anchorPoint, cabin.zPosition) = (CGSize(width: w, height: h), .zero, 2)
        canvas.addChild(outside)
        canvas.addChild(cabin)

        // The view's geometry. A row `d` pixels below the horizon looks at ground `cruise × focal / d` km away, where
        // a pixel spans `cruise / d` km: the horizon is taken a few pixels above where the ground stops (`dip`), as the
        // Earth's curve puts it, which also keeps the last rows from each spanning a thousand kilometres.
        let focal = Double(gh) * 1.2, dip = Double(gh) * 0.04
        rows = (0..<horizon).map { r in
            let d = Double(horizon - r) - 0.5 + dip
            let away = Self.cruise * focal / d, above = Self.cruise - Self.deck
            return Row(across: Self.cruise / d, away: away, deep: away / d, cloudAcross: above / d, cloudAway: above * focal / d,
                       cloudDeep: above * focal / (d * d), lift: Float(d / Self.cruise), haze: Float(0.1 + 0.9 * (1 - exp(-(away - 19) / 85))))
        }
        settings = Self.knobs.map(\.value)
        layWing()
        redraw()
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged),
                                               name: UserDefaults.didChangeNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func didMove(to view: SKView) { Location.shared.start() }

    /// Repaints when one of its own settings changes (the notification comes for every wallpaper's).
    @objc private func settingsChanged() {
        let picked = Self.knobs.map(\.value)
        guard picked != settings, !retired else { return }
        let another = Int(Self.scenery.value) != world.scenery || Int(Self.clouds.value) != world.weather
        settings = picked
        if another, let view { // a different world: dissolve into a new scene of it with both still running, never a cut
            let fade = SKTransition.crossFade(withDuration: 0.8)
            (fade.pausesIncomingScene, fade.pausesOutgoingScene) = (false, false)
            let next = PixelWindowSeat(size: size)
            next.scaleMode = scaleMode
            retired = true
            return view.presentScene(next, transition: fade)
        }
        layWing()
        redraw()
    }

    /// Now, or today at the preview hour while previewing.
    private var now: Date {
        guard Self.previewTime.value > 0.5 else { return Date() }
        return Calendar.current.startOfDay(for: Date()).addingTimeInterval(Self.previewHour.value * 3600)
    }

    // MARK: - The light (every 30 s)

    /// Works out everything that follows the clock: where the Sun and Moon are, the sky, and the colours the land,
    /// the cloud, the wing and the cabin take in that light. Every 30 s by the wall clock and when a setting changes.
    private func redraw() {
        redrawnAt = Date()
        kmPerSecond = Self.pace * Self.speed.value
        let (gw, gh) = (glass.w, glass.h)
        let spot = Location.shared.coordinate, jd = Sky.julianDate(now)
        let turn = Sky.horizonMatrix(jd: jd, latitude: spot.latitude, longitude: spot.longitude)
        func seen(_ v: Sky.Vector) -> (elevation: Double, azimuth: Double) {
            let v = turn * v // east, north, up
            return (asin(v.z) * 180 / .pi, (atan2(v.x, v.y) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360))
        }
        let sun = seen(Sky.sun(jd)), moon = seen(Sky.moon(jd, latitude: spot.latitude, longitude: spot.longitude).direction)
        let phase = Sky.moonPhase(jd)
        let el = Float(sun.elevation)
        night = smoothstep(4, -8, el)
        sunUp = smoothstep(-1, 6, el)
        let pick = Int(Self.looking.value), facing = pick == 0 ? (spot.latitude >= 0 ? 180.0 : 0) : Double(pick - 1) * 45

        // A change of scenery or cloud is a different world: every row is laid again.
        let (scenery, weather) = (Int(Self.scenery.value), Int(Self.clouds.value))
        if (scenery, weather) != (world.scenery, world.weather) {
            (world.scenery, world.weather) = (scenery, weather)
            for r in rows.indices { (rows[r].first, rows[r].cloudFirst) = (.min, .min) }
        }
        // Which way the Sun is, for the shadows clouds cast on the ground and on each other, and for their lit sides.
        let toSun = (sun.azimuth - facing) * .pi / 180 // 0 straight out of the window, positive toward the nose
        world.sun = el > 5 ? (SIMD2(sin(toSun), cos(toSun)), tan(Double(el) * .pi / 180)) : nil
        let sunSide = sunUp > 0.2 ? (sin(toSun) > 0.25 ? 1 : sin(toSun) < -0.25 ? -1 : 0) : 0

        // The sky, banded and dithered as Pixel City's is, and deeper overhead: there's less air above us.
        let (zenith, sunward) = PixelCity.skyColours(el, morning: sun.azimuth < 180)
        let top = zenith * mix(0.78, 1, night), low = smoothstep(-10, -2, el) * smoothstep(12, 3, el)
        let lilac = mix(top, rgb(226, 156, 176), 0.5)
        let span = 250.0 // degrees of compass across the pane: wide, so sunrise and sunset stay in view all year
        let horizons = (0..<gw).map { x -> RGB in
            let azimuth = facing + (Double(x) / Double(gw) - 0.5) * span
            return mix(sunward, lilac, Float(1 - cos((azimuth - sun.azimuth) * .pi / 180)) / 2 * low * 0.85)
        }
        func place(_ p: (elevation: Double, azimuth: Double)) -> (x: Int, y: Int) {
            let dx = (p.azimuth - facing + 540).truncatingRemainder(dividingBy: 360) - 180
            let rise = p.elevation < 0 ? p.elevation * 4 : pow(p.elevation / 60, 0.75) * Double(gh - horizon)
            return (Int(Double(gw) * (0.5 + dx / span)), horizon + Int(rise))
        }
        var px = Pixels(gw, gh)
        let sunSpot = place(sun), band: Float = 0.4
        let glare = smoothstep(-10, 0, el) * (1 - smoothstep(6, 20, el)) * 0.7 + 0.15 * smoothstep(0, 10, el)
        let glareColour = mix(rgb(255, 128, 64), rgb(255, 214, 150), smoothstep(-2, 10, el))
        let reach = mix(1, 0.35, smoothstep(4, 20, el))
        for y in horizon..<gh {
            let t = Float(y - horizon) / Float(gh - horizon)
            for x in 0..<gw {
                let d = bayer(x, y)
                var c = mix(horizons[x], top, pow(min(1, (t * 14 + (1 - band) / 2 + d * band).rounded(.down) / 14), 0.6))
                if glare > 0 {
                    let gx = Float(x - sunSpot.x) / (90 * reach), gy = Float(y - sunSpot.y) / (40 * reach)
                    c = mix(c, glareColour, (glare * exp(-(gx * gx + gy * gy)) * 5 + 0.3 + d * 0.4).rounded(.down) / 5)
                }
                px.plot(x, y, pointwiseMin(c, .one))
            }
        }
        var stars = SeededRandom(state: 1903)
        let starlight = smoothstep(-5, -12, el)
        for _ in 0..<(gw * (gh - horizon) / 110) {
            let x = Int.random(in: 0..<gw, using: &stars), y = Int.random(in: horizon + 2..<gh, using: &stars)
            let brightness = Float.random(in: 0.25...1, using: &stars)
            let a = starlight * brightness * smoothstep(0, 0.35, Float(y - horizon) / Float(gh - horizon))
            px.plot(x, y, rgb(255, 248, 232), a)
            if brightness > 0.93 { for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] { px.plot(x + dx, y + dy, rgb(200, 210, 255), a * 0.35) } }
        }
        let moonSpot = place(moon)
        if moon.elevation > -2 {
            // The Moon's disc, lit on the right while waxing as the northern hemisphere sees it.
            let r = 6, k = Float(1 - 2 * phase.lit), right = phase.waxing == (spot.latitude >= 0)
            for dy in -r...r {
                for dx in -r...r where dx * dx + dy * dy <= r * r + 2 {
                    let edge = k * max(0, 1 - Float(dy * dy) / Float(r * r)).squareRoot() * Float(r)
                    let lit = right ? Float(dx) > edge : Float(dx) < -edge
                    px.plot(moonSpot.x + dx, moonSpot.y + dy, lit ? rgb(242, 240, 222) : rgb(40, 46, 72), lit ? mix(0.5, 1, night) : 0.5 * night * night)
                }
            }
        }
        if sun.elevation > -3 {
            let colour = mix(rgb(255, 150, 80), rgb(255, 246, 214), smoothstep(0, 12, el))
            for dy in -5...5 { for dx in -5...5 where dx * dx + dy * dy <= 27 { px.plot(sunSpot.x + dx, sunSpot.y + dy, colour) } }
        }
        let skyBytes = px.bytes(topDown: false)
        skyBytes.withUnsafeBytes { sky = Array($0.bindMemory(to: UInt32.self)) }

        // Light on the land: what the sky gives it, plus the Sun from above, or the Moon by how much of it is lit.
        let moonlight = rgb(120, 140, 200) * Float(phase.lit) * smoothstep(0, 10, Float(moon.elevation)) * night
        let ambient = mix(mix(RGB(0.8, 0.84, 0.92), RGB(0.4, 0.4, 0.56), smoothstep(16, 0, el)), RGB(0.035, 0.045, 0.085), night)
        let key = PixelCity.sunColour(el) * (0.3 + 0.7 * sin(max(el, 0) * .pi / 180)) + moonlight * 0.1
        let haze = mix(horizons[gw / 2], top, 0.12), veil = mix(top, haze, 0.35) * mix(0.8, 0.25, night)
        paint = Paint(mats: Mat.day.count)
        paint.sunSide = sunSide
        for step in 0..<Paint.steps {
            let far = Float(step) / Float(Paint.steps - 1)
            for (m, base) in Mat.day.enumerated() {
                // Eleven km of air lie in front of even the nearest ground, and tint it all toward the sky's blue.
                let lit = mix(pointwiseMin(base * (ambient + key) * 0.84, .one), veil, 0.2)
                let shaded = mix(pointwiseMin(base * (ambient + key * 0.3) * 0.78, .one), veil, 0.2)
                paint.ground[(step * 2) * paint.mats + m] = pack(mix(lit, haze, far))
                paint.ground[(step * 2 + 1) * paint.mats + m] = pack(mix(shaded, haze, far))
            }
            // Cloud tops stay lit a little after the ground has lost the Sun, and never go quite black. Six tones,
            // from the deep shade under a cloud's overhang to the glare of a top facing the Sun.
            let high = PixelCity.sunColour(el + 4), floor = RGB(0.07, 0.08, 0.13) * night + moonlight * 0.22
            let tones = [RGB(0.5, 0.57, 0.74) * (ambient * 0.82 + high * 0.06), RGB(0.64, 0.7, 0.84) * (ambient * 0.82 + high * 0.14),
                         RGB(0.78, 0.82, 0.92) * (ambient * 0.82 + high * 0.28), RGB(0.88, 0.9, 0.96) * (ambient * 0.82 + high * 0.4),
                         RGB(0.95, 0.96, 0.98) * (ambient * 0.82 + high * 0.48), RGB(1, 1, 1) * (ambient * 0.82 + high * 0.56)]
            for (t, tone) in tones.enumerated() { paint.cloud[step * Paint.tones + t] = pack(mix(pointwiseMin(tone + floor, .one), haze, far * 0.8)) }
            for (g, lamp) in Mat.lamps.enumerated() { paint.lamp[step * 8 + g] = pack(mix(lamp, haze, far * 0.55)) }
        }
        paint.lights = UInt8(min(255, night * 300))
        paint.sparkle = pack(mix(rgb(255, 196, 120), rgb(255, 252, 240), smoothstep(0, 14, el)))
        paint.moonSparkle = pack(rgb(150, 164, 200))
        paint.window = pack(rgb(255, 214, 150))

        // The glitter path: the Sun's image in the water, straight below it, as scattered sparkles. Under the Moon
        // it's the same and far fainter.
        let moonUp = night * Float(phase.lit) * smoothstep(0, 8, Float(moon.elevation))
        let (body, strength): ((x: Int, y: Int), Float) = sunUp > 0.05 ? (sunSpot, sunUp) : (moonSpot, moonUp * 0.16)
        paint.byMoon = sunUp <= 0.05
        for r in 0..<horizon {
            let below = Float(horizon - r), mirror = Float(body.y - horizon) * 1.3 + 4
            let widthHere = 9 + below * 0.14, row = exp(-pow((below - mirror) / (26 + mirror * 0.5), 2)) + 0.25 * exp(-below / 30)
            for x in 0..<gw {
                let across = Float(x - body.x) / widthHere
                glint[r * gw + x] = UInt8(min(255, 130 * strength * min(1, row) * exp(-across * across)))
            }
        }

        // The wing, in the same light, and what the strobe at its tip makes of it.
        let metal = [RGB.zero, rgb(158, 166, 178), rgb(134, 143, 158), rgb(204, 210, 220), rgb(176, 184, 196), rgb(122, 131, 150), rgb(58, 86, 142),
                     rgb(112, 120, 136)]
        // The Sun still reaches the aircraft when it's 3.4° below the horizon of the ground under it.
        let cabinGlow = RGB(0.05, 0.05, 0.07) * night
        let onWing = ambient * 0.8 + PixelCity.sunColour(el + 3.4) * (0.3 + 0.7 * sin(max(el, 0) * .pi / 180)) * 0.55
        paint.wing = metal.map { pack(mix(pointwiseMin($0 * onWing + cabinGlow, .one), haze, 0.08)) }
        paint.wingFlash = metal.map { pack(pointwiseMin($0 * onWing + cabinGlow + RGB(0.2, 0.2, 0.22) * mix(0.15, 1, night), .one)) }
        paint.tip = pack(rgb(255, 60, 50))
        paint.tipOn = night > 0.25

        paintCabin(light: pointwiseMin(ambient + key * 0.5, .one), haze: haze)
        // Paint now, not at the next frame: a view that's frozen (Low Power Mode) or not drawing yet (Settings'
        // preview as it opens, the render tests' first frame) has no next frame, and would show an empty pane.
        advance()
        compose()
    }

    // MARK: - The cabin and the wing

    /// How far a canvas pixel is outside the pane's rounded outline, in pixels (negative inside it).
    private func outsidePane(_ x: Int, _ y: Int) -> Float {
        let a = Float(glass.w) / 2, b = Float(glass.h) / 2, round = min(a, b) * 0.58
        let qx = abs(Float(x) + 0.5 - (Float(glass.x) + a)) - a + round, qy = abs(Float(y) + 0.5 - (Float(glass.y) + b)) - b + round
        return (max(qx, 0) * max(qx, 0) + max(qy, 0) * max(qy, 0)).squareRoot() + min(max(qx, qy), 0) - round
    }

    /// The cabin wall around the window: dark, as a camera set for the daylight outside sees it, with the window's
    /// deep reveal catching the light that comes in, and the shade pulled a little way down.
    private func paintCabin(light: RGB, haze: RGB) {
        var px = Pixels(w, h)
        let wall = mix(rgb(44, 46, 56), rgb(22, 24, 34), night), rim = mix(rgb(70, 73, 86), rgb(34, 36, 50), night)
        let shade = mix(rgb(88, 90, 100), rgb(40, 42, 56), night), shadeEnd = glass.y + glass.h * 91 / 100
        let glow = mix(light, haze, 0.35) // the daylight on the reveal
        for y in 0..<h {
            for x in 0..<w {
                let d = outsidePane(x, y)
                if d < 0 {
                    if y >= shadeEnd { px.plot(x, y, y == shadeEnd ? shade * 0.72 : mix(shade, shade * 1.12, bayer(x, y) > Float(y - shadeEnd) / 14 ? 0 : 1)) }
                } else if d < 1.5 {
                    px.plot(x, y, rgb(16, 17, 24)) // the seal
                } else if d < 10 {
                    // The reveal is pale plastic sloping in toward the pane: its lower lip faces the sky and takes
                    // the daylight, and its upper one is in its own shadow.
                    let up = Float(y - (glass.y + glass.h / 2)) / Float(glass.h / 2)
                    let facing = smoothstep(0.95, -0.95, up), step = ((facing * 3 + bayer(x, y) * 0.9).rounded(.down)) / 3
                    let plastic = mix(rgb(92, 95, 108), rgb(210, 211, 214), step) * (d < 2.5 ? 0.72 : 1)
                    px.plot(x, y, pointwiseMin(plastic * (glow * 0.9 + RGB(0.16, 0.16, 0.2) * night), .one))
                } else if d < 12 {
                    px.plot(x, y, rim)
                } else {
                    // The wall curves away above and below, and is a little lighter beside the window.
                    let v = abs(Float(y) / Float(h) - 0.52) * 2, fall = ((v * v * 3 + bayer(x, y) * 0.7).rounded(.down)) / 4
                    px.plot(x, y, mix(wall, wall * 0.62, fall))
                }
            }
        }
        // The shade's handle, and seams in the wall panels either side.
        px.fill(glass.x + glass.w / 2 - glass.h / 10, shadeEnd + 2, glass.h / 5, 3, shade * 1.3)
        for x in [glass.x - 24, glass.x + glass.w + 23] { px.fill(x, 0, 1, h, wall * 0.7) }
        // The breather hole at the foot of the pane, with the frost that gathers round it.
        let (bx, by) = (glass.x + glass.w / 2, glass.y + 5)
        px.plot(bx, by, rgb(20, 22, 30), 0.9)
        for (dx, dy) in [(-2, 0), (2, 1), (-1, 1), (1, -1), (0, 2), (3, 0), (-3, 1)] { px.plot(bx + dx, by + dy, rgb(232, 238, 246), 0.3) }
        cabin.texture = px.texture()
    }

    /// Marks out the wing for the seat over it: a swept wing running from under the window out to its tip just
    /// below the horizon, with the winglet standing above it. We look out of the left side, so the nose is to the
    /// right and the wing sweeps back to the left.
    private func layWing() {
        wing = []
        guard Self.seat.value < 0.5 else { return }
        let (gw, gh) = (Float(glass.w), Float(glass.h))
        func inside(_ p: SIMD2<Float>, _ shape: [SIMD2<Float>]) -> Bool {
            var hit = false
            for i in shape.indices {
                let a = shape[i], b = shape[(i + 1) % shape.count]
                if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { hit.toggle() }
            }
            return hit
        }
        let lead: (SIMD2<Float>, SIMD2<Float>) = ([0.4, -0.02], [0.135, 0.54]), tip: SIMD2<Float> = [0.075, 0.524]
        let surface: [SIMD2<Float>] = [lead.0, lead.1, tip, [-0.05, 0.43], [-0.05, -0.05]]
        let winglet: [SIMD2<Float>] = [lead.1, tip, [0.036, 0.665], [0.06, 0.672]]
        for y in 0..<glass.h {
            for x in 0..<glass.w {
                let p = SIMD2((Float(x) + 0.5) / gw, (Float(y) + 0.5) / gh)
                var part: UInt8 = 0
                if inside(p, winglet) {
                    part = inside(p + [0.01, 0], winglet) ? 4 : 5 // its trailing edge is in shade
                    if p.y > 0.635 { part = 6 } // the airline's colour across its top
                } else if inside(p, surface) {
                    // How far back from the leading edge, as a share of the chord here: the edge itself is bright
                    // metal, and the flaps and spoilers behind show as darker panels.
                    let along = (p.y - lead.0.y) / (lead.1.y - lead.0.y), front = lead.0.x + (lead.1.x - lead.0.x) * along
                    let back = (front - p.x) / max(0.02, front - (-0.05 + (tip.x + 0.05) * along))
                    part = back < 0.08 ? 3 : back > 0.7 ? (back > 0.72 ? 2 : 7) : (back > 0.4 && back < 0.43) ? 7 : 1
                }
                guard part != 0 else { continue }
                let reach = simd_distance(p * [gw, gh], tip * [gw, gh])
                wing.append((y * glass.w + x, part, UInt8(255 * max(0, 1 - reach / 26))))
            }
        }
    }

    // MARK: - Motion (every frame)

    override func update(_ currentTime: TimeInterval) {
        let dt = min(max(currentTime - (lastUpdate ?? currentTime), 0), 0.1)
        lastUpdate = currentTime
        clock += dt
        if abs(Date().timeIntervalSince(redrawnAt)) >= 30 { redraw() }
        Self.flown += min(max(currentTime - (Self.flownAt ?? currentTime), 0), 0.1) * kmPerSecond
        Self.flownAt = currentTime
        advance()
        if var plane = other {
            plane.x += plane.way * Float(dt) * 5
            other = abs(plane.x - Float(glass.w) / 2) > Float(glass.w) / 2 + Float(Self.trail) ? nil : plane // its trail has left too
            if other == nil { nextOther = clock + .random(in: 60...240) }
        } else if clock >= nextOther {
            let way: Float = Bool.random() ? 1 : -1, sky = Float(glass.h - horizon)
            other = (way > 0 ? -2 : Float(glass.w) + 2, Float(horizon) + Float.random(in: sky * 0.14...sky * 0.62), way, Float.random(in: -0.03...0.05))
        }
        // Nothing here moves faster than a few pixels a second, so 30 pictures a second is plenty at any frame rate.
        if clock - painted >= 1 / 30.0 - 0.002 { compose() }
    }

    /// Slides each row on to where the flight has got to, laying the pixels that come into view.
    private func advance() {
        let gw = glass.w
        for r in rows.indices {
            let row = rows[r]
            let first = Int((Self.flown / row.across).rounded(.down)) - gw / 2
            if first != row.first {
                for n in (row.first != .min && first - row.first < gw ? row.first + gw : first)..<first + gw {
                    let k = r * gw + ((n % gw) + gw) % gw
                    (land[k], glow[k], tall[k]) = world.ground(Double(n) * row.across, row.away, n: n, row: r, across: row.across, deep: row.deep)
                }
                rows[r].first = first
            }
            let cloudFirst = Int((Self.flown / row.cloudAcross).rounded(.down)) - gw / 2
            if cloudFirst != row.cloudFirst {
                for n in (row.cloudFirst != .min && cloudFirst - row.cloudFirst < gw ? row.cloudFirst + gw : cloudFirst)..<cloudFirst + gw {
                    cloud[r * gw + ((n % gw) + gw) % gw] = world.cloud(Double(n) * row.cloudAcross, row.cloudAway, deep: row.cloudDeep)
                }
                rows[r].cloudFirst = cloudFirst
            }
        }
    }

    /// Paints the view: the sky, then the ground from the horizon toward us, the cloud layer the same way so that
    /// near clouds stand in front of far ones, and the wing over it all.
    private func compose() {
        painted = clock
        let (gw, gh) = (glass.w, glass.h), mats = paint.mats
        let tick = UInt32(truncatingIfNeeded: Int(clock * 3))
        let lightsOn = paint.lights > 0, towerRows = gh - 1
        picture.withUnsafeMutableBufferPointer { out in
            for i in horizon * gw..<gh * gw { out[i] = sky[i] }
            for r in stride(from: horizon - 1, through: 0, by: -1) {
                let row = rows[r], base = r * gw, hz = row.haze * Float(Paint.steps - 1)
                var s = ((row.first % gw) + gw) % gw
                for i in 0..<gw {
                    let k = base + s, m = Int(land[k])
                    let step = min(Paint.steps - 1, Int(hz + dither[(r & 3) * 4 + (i & 3)]))
                    var c = paint.ground[(step * 2 + (m >> 7)) * mats + (m & 127)]
                    let n = row.first + i
                    if m & 127 <= Int(Mat.lastWater), glint[base + i] != 0, scatter(n, r, tick) < glint[base + i] {
                        c = paint.byMoon ? paint.moonSparkle : paint.sparkle
                    }
                    if lightsOn, glow[k] != 0, scatter(n, r, 0) < paint.lights, scatter(n, r, tick >> 1) > 7 {
                        c = paint.lamp[step * 8 + Int(glow[k])]
                    }
                    out[base + i] = c
                    if tall[k] != 0 {
                        // A tower stands up from its foot as a column, its windows lit at night.
                        let top = min(towerRows, r + max(1, Int(Float(tall[k]) * row.lift * 0.03)))
                        if r < top {
                            let wall = paint.ground[(step * 2 + (m >> 7)) * mats + (m & 127)]
                            for y in r + 1...top {
                                out[y * gw + i] = lightsOn && (y &+ n) & 1 == 0 && scatter(n, y, 1) < 110 ? paint.window : wall
                            }
                            if !lightsOn { out[top * gw + i] = paint.ground[step * 2 * mats + Int(Mat.shed)] }
                        }
                    }
                    s += 1
                    if s == gw { s = 0 }
                }
            }
            // The cloud layer, nearest row first. A cloud stands up from its base as a column, so each column of the
            // picture remembers how high the clouds in front already reach (`ceiling`), and a cloud behind paints
            // only what shows above that.
            let above = Float(Self.cruise / (Self.cruise - Self.deck)), tones = Paint.tones
            for i in 0..<gw { ceiling[i] = -1 }
            for r in 0..<horizon {
                let row = rows[r], base = r * gw, lift = row.lift * above
                let step = min(Paint.steps - 1, Int(row.haze * Float(Paint.steps - 1) + 0.5)) * tones
                var s = ((row.cloudFirst % gw) + gw) % gw
                for i in 0..<gw {
                    let t = Int(cloud[base + s])
                    if t != 0 {
                        let height = Int(SeatWorld.heights[t & 31] * lift), top = min(gh - 1, r + height)
                        if top > ceiling[i] {
                            // Its top takes the light: brighter where the cloud is thick and where it faces the Sun,
                            // darker in another cloud's shadow. Its foot is the shaded face under the overhang.
                            var tone = 2 + (t >> 5 & 3) - (t & 128 != 0 ? 2 : 0)
                            if paint.sunSide != 0 {
                                let slope = (Int(cloud[base + (s + 1 == gw ? 0 : s + 1)] & 31) - Int(cloud[base + (s == 0 ? gw - 1 : s - 1)] & 31)) * paint.sunSide
                                tone += slope < -1 ? 1 : slope > 1 ? -1 : 0
                            }
                            let lit = min(max(tone, 1), tones - 1), foot = height < 3 ? r : r + height / 4, waist = height < 5 ? foot : r + height / 2
                            for y in max(r, ceiling[i] + 1)...top {
                                out[y * gw + i] = paint.cloud[step + (y < foot ? (y == r ? 0 : 1) : y < waist ? min(lit, 2) : lit)]
                            }
                            ceiling[i] = top
                        }
                    }
                    s += 1
                    if s == gw { s = 0 }
                }
            }
            // The other airliner: a contrail that thins out behind it, and at night only its lights.
            if let plane = other {
                for k in stride(from: Self.trail - 1, through: 0, by: -1) {
                    let x = Int(plane.x - plane.way * Float(k)), y = Int(plane.y - plane.slant * Float(k))
                    guard x >= 0, x < gw, y >= horizon, y < gh else { continue }
                    if k < 3 {
                        if !paint.tipOn { out[y * gw + x] = paint.wing[4] } else if k == 0 { out[y * gw + x] = clock.truncatingRemainder(dividingBy: 1.1) < 0.12 ? 0xFFFF_FFFF : paint.tip }
                    } else if !paint.tipOn || k < 30 {
                        let thin = UInt32(Float(paint.tipOn ? 40 : 200) * (1 - Float(k) / Float(Self.trail)) * (k < 8 ? Float(k) / 8 : 1))
                        out[y * gw + x] = blend(out[y * gw + x], paint.cloud[Paint.tones - 1], thin & ~31) // in a few flat steps
                    }
                }
            }
            // The wing, and the lights at its tip: a red one that stays on after dark, and a white strobe that
            // catches the few pixels of metal round it for a moment a little under once a second.
            let flash = clock.truncatingRemainder(dividingBy: 1.3) < 0.1
            for spot in wing {
                out[spot.at] = flash && spot.flash > 196 ? paint.wingFlash[Int(spot.part)] : paint.wing[Int(spot.part)]
                if spot.flash > 236, flash || paint.tipOn { out[spot.at] = flash ? 0xFFFF_FFFF : paint.tip }
            }
        }
        let shot = picture
        texture.modifyPixelData { data, length in
            shot.withUnsafeBytes { data?.copyMemory(from: $0.baseAddress!, byteCount: min(length, $0.count)) }
        }
    }
}

// MARK: - Supporting types

/// One row of ground and the strip of cloud layer the same row of the picture looks at: how many km of each a pixel
/// spans along the track, how far off it is and how many km deep the row is, how many pixels a km of height stands
/// up at that distance, how much haze lies in front of it, and which pixel of its endless strip is at the pane's
/// left edge.
private struct Row {
    let across: Double, away: Double, deep: Double
    let cloudAcross: Double, cloudAway: Double, cloudDeep: Double
    let lift: Float, haze: Float
    var first = Int.min, cloudFirst = Int.min
}

/// The colours of the moment, ready to copy into the picture: each material at each step of haze, in sunlight and
/// in a cloud's shadow; the cloud's tones; the lamps; and the wing.
private struct Paint {
    static let steps = 12, tones = 6
    var mats = 1
    var ground: [UInt32] = [], cloud = [UInt32](repeating: 0, count: steps * tones), lamp = [UInt32](repeating: 0, count: steps * 8)
    var wing: [UInt32] = [], wingFlash: [UInt32] = []
    var lights: UInt8 = 0 // how far the evening has got: a lamp comes on once this passes its own draw
    var sparkle: UInt32 = 0, moonSparkle: UInt32 = 0, window: UInt32 = 0, tip: UInt32 = 0
    var byMoon = false, tipOn = false
    var sunSide = 0 // 1 with the Sun toward the nose (the right of the picture), -1 toward the tail, 0 ahead, behind or down

    init(mats: Int = 1) {
        self.mats = mats
        ground = [UInt32](repeating: 0, count: Self.steps * 2 * mats)
    }
}

/// What a pixel of ground is made of. The top bit of the byte marks it as in a cloud's shadow.
enum Mat {
    static let deep: UInt8 = 0, sea: UInt8 = 1, shallows: UInt8 = 2, river: UInt8 = 3, lastWater: UInt8 = 3
    static let surf: UInt8 = 4, wake: UInt8 = 5, hull: UInt8 = 6, sand: UInt8 = 7
    static let grass: UInt8 = 8, crop: UInt8 = 9, wheat: UInt8 = 10, fallow: UInt8 = 11, soil: UInt8 = 12, meadow: UInt8 = 13
    static let pasture: UInt8 = 14, dry: UInt8 = 15, forest: UInt8 = 16, woods: UInt8 = 17, road: UInt8 = 18, roof: UInt8 = 19
    static let block: UInt8 = 20, blockPale: UInt8 = 21, blockDark: UInt8 = 22, park: UInt8 = 23, street: UInt8 = 24
    static let tower: UInt8 = 25, towerShade: UInt8 = 26, yard: UInt8 = 27, shed: UInt8 = 28, lane: UInt8 = 29
    /// Each one's colour in full daylight, before the haze.
    static let day: [RGB] = [
        rgb(22, 56, 104), rgb(28, 70, 120), rgb(52, 126, 148), rgb(40, 84, 118),
        rgb(226, 236, 240), rgb(128, 170, 196), rgb(236, 236, 232), rgb(208, 192, 152),
        rgb(96, 132, 72), rgb(70, 114, 62), rgb(198, 178, 98), rgb(170, 148, 106), rgb(126, 98, 74), rgb(124, 152, 86),
        rgb(106, 140, 82), rgb(184, 166, 120), rgb(42, 80, 56), rgb(54, 96, 62), rgb(176, 170, 156), rgb(156, 144, 136),
        rgb(98, 104, 118), rgb(128, 130, 138), rgb(78, 86, 102), rgb(84, 124, 76), rgb(152, 152, 154),
        rgb(160, 170, 190), rgb(66, 76, 102), rgb(74, 106, 78), rgb(214, 216, 220), rgb(142, 146, 112),
    ]
    /// The lamps a pixel can carry after dark: none, a dim and a full sodium orange, a bright one for the avenues,
    /// white for downtown and for ships, and a cool white.
    static let lamps: [RGB] = [.zero, rgb(196, 124, 60), rgb(250, 168, 84), rgb(255, 200, 120), rgb(255, 240, 214), rgb(214, 228, 255), .zero, .zero]
}

/// The endless country under the flight: for any spot, in km along the track (`x`) and out from it (`z`), what is
/// there. Everything comes from hashes of the place, so nothing is stored and no two stretches are alike.
struct SeatWorld {
    /// Settings' Scenery (0 for whatever comes, then ocean, city, countryside) and Clouds (0 for whatever comes,
    /// then clear to overcast).
    var scenery = 0, weather = 0
    /// Which way the Sun is across the ground, and how steeply its light comes down (rise over run); nil when it's
    /// too low to cast a shadow worth drawing.
    var sun: (toward: SIMD2<Double>, slope: Double)?

    /// How high the land stands, in the noise's own units: below 0 is sea.
    func shore(_ x: Double, _ z: Double) -> Float {
        let lean: Float = scenery == 1 ? -0.2 : scenery >= 2 ? 0.3 : 0.045
        return fbm(x / 150, z / 150, 4, 11) - 0.5 + (fbm(x / 12, z / 12, 2, 13) - 0.5) * 0.035 + lean
    }

    /// How built-up the land is, 0 to 1: farmland below 0.5, suburbs to 0.6, city above, downtown from 0.7.
    func urban(_ x: Double, _ z: Double) -> Float {
        let natural = noise(x / 80, z / 80, 21) * 0.75 + noise(x / 24, z / 24, 22) * 0.25 + 0.05
        return scenery == 2 ? max(natural + 0.1, 0.61) : scenery == 3 ? natural - 0.45 : natural
    }

    /// How much of the sky below us is cloud here, 0 to 1.
    func cover(_ x: Double, _ z: Double) -> Float {
        switch weather {
        case 1: 0
        case 2: 0.34
        case 3: 0.62
        case 4: 1
        default: min(max((fbm(x / 260, z / 260, 2, 41) - 0.4) / 0.38, 0), 1)
        }
    }

    /// 0 for ocean, 1 for city, 2 for countryside: what the land is called here.
    func biome(_ x: Double, _ z: Double) -> Int { shore(x, z) < 0 ? 0 : urban(x, z) > 0.55 ? 1 : 2 }

    /// The heights a cloud's byte can name, in km above the cloud layer's base: fine steps for fair-weather clouds
    /// a few hundred metres tall, coarse ones for towers of several km.
    static let heights: [Float] = (0..<32).map { Float($0 * $0) / 961 * 6.5 }

    /// The cloud over a spot of the cloud layer: how far its top stands above the layer's base, in km (0 where
    /// there's none), and how thick and so how bright it is there, 0 to 3. `deep` is how many km the picture's row
    /// spans there: seen nearly edge-on, far cloud hides the gaps between its clouds.
    private func cloudTop(_ x: Double, _ z: Double, deep: Double) -> (km: Float, body: Int) {
        let cover = cover(x, z)
        guard cover > 0.02 else { return (0, 0) }
        let puff = fbm(x / 3.4, z / 3.4, 3, 51) * 0.7 + noise(x / 15, z / 15, 55) * 0.3
        let t = puff - mix(0.8, 0.3, cover) + min(0.22, Float(deep) * 0.03)
        guard t > 0 else { return (0, 0) }
        // Fair-weather clouds are low and flat; a full deck rolls; and here and there one towers.
        // ponytail: towers stand only in the far rows, where they are small. Up close a column of one tone reads as a
        // block of ice, not a cloud: a near one would need its own lumpy drawing.
        let towering = smoothstep(0.78, 0.93, noise(x / 30, z / 30, 57)) * smoothstep(0.25, 0.6, cover) * smoothstep(0.5, 1.6, Float(deep))
        let km = 0.06 + min(t * 4, 1) * (mix(0.45, 0.6, cover) + 0.35 * noise(x / 9, z / 9, 58) * cover) + towering * 7 * min(t, 0.4) * (0.6 + 0.8 * noise(x / 2.2, z / 2.2, 60))
        return (km, min(3, Int(t * 14 + 0.6 * noise(x / 1.1, z / 1.1, 59))))
    }

    /// The cloud standing over a spot of the cloud layer, as a byte: 0 for none; else its height in the low five
    /// bits (an index into `heights`), how bright its top is in the next two, and the top bit set where a taller
    /// cloud toward the Sun shades it.
    func cloud(_ x: Double, _ z: Double, deep: Double) -> UInt8 {
        let top = cloudTop(x, z, deep: deep)
        guard top.km > 0 else { return 0 }
        var shaded = false
        if let sun, deep < 3 {
            for reach in [0.7, 1.8] where !shaded {
                shaded = cloudTop(x + sun.toward.x * reach, z + sun.toward.y * reach, deep: deep).km > top.km + Float(reach * sun.slope) + 0.08
            }
        }
        return UInt8(min(31, max(1, Int((top.km / 6.5).squareRoot() * 31 + 0.5)))) | UInt8(top.body << 5) | (shaded ? 128 : 0)
    }

    /// What the ground is at a spot: its material (with the top bit set in a cloud's shadow), the lamp it carries
    /// at night, and how tall it stands, in steps of 20 m. `n` and `row` name the pixel, for its own random numbers;
    /// `across` and `deep` are the km it spans, so that things too small to see at that distance are left out.
    func ground(_ x: Double, _ z: Double, n: Int, row: Int, across: Double, deep: Double) -> (land: UInt8, glow: UInt8, tall: UInt8) {
        var (land, glow, tall) = surface(x, z, n: n, row: row, across: across, deep: deep)
        if land <= Mat.lastWater, glow != 4 { glow = 0 }
        // ponytail: a shadow keeps the Sun it slid in with, which in the far rows can be several minutes old. They are
        // too small there to tell; lay the far rows again now and then if shadows ever need to be right.
        if let sun, deep < 1.4, land != Mat.surf {
            let reach = (PixelWindowSeat.deck + 0.4) / sun.slope
            if cloudTop(x + sun.toward.x * reach, z + sun.toward.y * reach, deep: 0).km > 0 { land |= 128 }
        }
        if tall != 0, deep > 0.5 { tall = 0 }
        return (land, glow, tall)
    }

    private func surface(_ x: Double, _ z: Double, n: Int, row: Int, across: Double, deep: Double) -> (UInt8, UInt8, UInt8) {
        let speck = unit(hash(n, row, 7)), fleck = unit(hash(n, row, 8)) // random numbers for this pixel alone
        let high = shore(x, z)
        if high < 0 {
            // A ship now and then, drawn far larger than life, with its wake trailing along the track.
            let lane = 11.0, (cx, cz) = ((x / lane).rounded(.down), (z / lane).rounded(.down))
            let draw = hash(Int(cx), Int(cz), 61)
            if unit(draw) < 0.3, high < -0.03, across < 0.3 {
                let sx = (cx + 0.2 + 0.6 * Double(unit(hash(Int(cx), Int(cz), 62)))) * lane
                let sz = (cz + 0.2 + 0.6 * Double(unit(hash(Int(cx), Int(cz), 63)))) * lane
                let along = (x - sx) * (draw & 1 == 0 ? 1 : -1)
                if abs(z - sz) < deep / 2 {
                    if along >= 0, along < max(0.4, across * 2) { return (Mat.hull, 4, 0) }
                    if along < 0, along > -2.4 { return (Mat.wake, 0, 0) }
                }
            }
            if high > -0.0012, deep < 0.9 { return (Mat.surf, 0, 0) }
            let water = high > -0.016 ? Mat.shallows : high > -0.05 ? Mat.sea : Mat.deep
            return (speck < 0.003 && deep < 0.5 ? Mat.surf : water, 0, 0) // a whitecap
        }
        if high < 0.002, deep < 1.2 { return (Mat.sand, 0, 0) }
        if deep < 1.6, onLine(x, z, scale: 90, layers: 3, salt: 23, width: max(0.4, deep * 0.9, across)) { return (Mat.river, 0, 0) }
        let built = urban(x, z)
        // A highway now and then, winding across town and country alike.
        if deep < 1.2, onLine(x, z, scale: 45, layers: 2, salt: 47, width: max(0.09, deep * 0.9, across * 0.9)) {
            return (Mat.road, built > 0.5 ? 3 : fleck < 0.35 ? 1 : 0, 0)
        }
        if built > 0.6 {
            // City: avenues every 1.3 km with blocks between them, some of them parks, and towers downtown. The
            // avenues show only up close; further off the blocks alone make the pattern.
            let side = 1.3, (bx, bz) = ((x / side).rounded(.down), (z / side).rounded(.down))
            // Lamps by district: the old sodium orange, or the white of streets since relit.
            let relit = noise(x / 11, z / 11, 48) > 0.56
            if (x - bx * side < across && across < side / 8) || (z - bz * side < deep && deep < side / 4) {
                return (Mat.street, (n &+ row) & 1 == 0 ? (relit ? 4 : 3) : 1, 0)
            }
            let core = smoothstep(0.7, 0.82, built)
            if core > 0, deep < 0.4 {
                // Downtown's towers, three pixels wide up close: two in the light and one in shade.
                let plot = 1.1, (tx, tz) = ((x / plot).rounded(.down), (z / plot).rounded(.down)), draw = hash(Int(tx), Int(tz), 33)
                let (ox, oz) = (x - (tx + 0.5 * Double(unit(draw >> 3))) * plot, z - tz * plot)
                if unit(draw) < core * 0.6, ox >= 0, ox < across * 3, oz < deep {
                    let height = (0.1 + 0.3 * unit(hash(Int(tx), Int(tz), 34))) * (0.4 + core)
                    return (ox < across * 2 ? Mat.tower : Mat.towerShade, 4, UInt8(height * 50))
                }
            }
            let kind = unit(hash(Int(bx), Int(bz), 31)), lamp: UInt8 = fleck < 0.1 + core * 0.2 ? (relit || fleck < core * 0.1 ? 5 : fleck < 0.04 ? 2 : 1) : 0
            if deep > side { return (kind < 0.3 ? Mat.blockDark : Mat.block, fleck < 0.2 + core * 0.15 ? (relit ? 5 : 2) : 0, 0) }
            if kind < 0.07 { return (speck < 0.2 ? Mat.woods : Mat.park, 0, 0) }
            // Districts: works and warehouses with big pale roofs, or streets of houses under trees.
            if noise(x / 6, z / 6, 36) < 0.3 { return (speck < 0.1 ? Mat.shed : speck < 0.3 ? Mat.block : Mat.blockPale, lamp, 0) }
            return (speck < 0.025 ? Mat.shed : speck < 0.14 ? Mat.yard : speck < 0.22 ? Mat.blockPale : kind < 0.5 ? Mat.blockDark : Mat.block, lamp, 0)
        }
        if built > 0.5 {
            // Suburbs: roofs thinning out among the trees, with a main road every couple of km.
            let side = 2.6, (bx, bz) = ((x / side).rounded(.down), (z / side).rounded(.down))
            if (x - bx * side < across && across < side / 4) || (z - bz * side < deep && deep < side / 3) { return (Mat.street, 2, 0) }
            if speck < (built - 0.5) * 5 { return (Mat.roof, fleck < 0.5 ? 1 : 0, 0) }
            return (unit(hash(Int((x / 0.65).rounded(.down)), Int((z / 0.65).rounded(.down)), 35)) < 0.4 ? Mat.woods : Mat.yard, 0, 0)
        }
        // Countryside: forest in irregular patches, and between them fields a section at a time.
        let wooded = fbm(x / 26, z / 26, 3, 37)
        if wooded > 0.62 { return (speck < 0.25 ? Mat.woods : Mat.forest, 0, 0) }
        let arid = noise(x / 140, z / 140, 38) > 0.55
        if deep > 1.3 { return (arid ? Mat.dry : Mat.pasture, 0, 0) } // too far off to tell one field from the next
        let side = 1.6, (sx, sz) = ((x / side).rounded(.down), (z / side).rounded(.down))
        let (fx, fz) = (x - sx * side, z - sz * side), draw = hash(Int(sx), Int(sz), 39)
        // A town every so often, and a farm's yard light in some sections.
        let parish = 16.0, (px, pz) = ((x / parish).rounded(.down), (z / parish).rounded(.down)), town = hash(Int(px), Int(pz), 43)
        if unit(town) < 0.6 {
            let centre = SIMD2((px + 0.2 + 0.6 * Double(unit(hash(Int(px), Int(pz), 44)))) * parish, (pz + 0.2 + 0.6 * Double(unit(hash(Int(px), Int(pz), 45)))) * parish)
            let size = 0.7 + 1.2 * Double(unit(hash(Int(px), Int(pz), 46))), off = simd_distance(SIMD2(x, z), centre) / size
            if off < 1, Double(speck) < 0.75 * (1 - off) { return (Mat.roof, fleck < 0.6 ? 2 : 0, 0) }
        }
        if (fx < across && across < side / 5) || (fz < deep && deep < side / 4) { return (Mat.lane, 0, 0) }
        let lamp: UInt8 = unit(draw) < 0.3 && abs(fx - 0.8) < across / 2 && abs(fz - 0.6) < deep / 2 ? 1 : 0
        // The section is one field, two, or four, each with its own crop; where it's dry, some are irrigated circles.
        let split = Int(draw >> 8 & 3), half = side / 2
        let part = (split & 1 != 0 && fx > half ? 1 : 0) + (split & 2 != 0 && fz > half ? 2 : 0)
        let crops: [UInt8] = arid ? [Mat.wheat, Mat.fallow, Mat.dry, Mat.soil, Mat.wheat, Mat.pasture, Mat.dry, Mat.fallow]
                                  : [Mat.grass, Mat.crop, Mat.meadow, Mat.pasture, Mat.crop, Mat.soil, Mat.grass, Mat.wheat]
        let crop = crops[Int(hash(Int(sx) &* 4 &+ part, Int(sz), 40) & 7)]
        if arid, draw >> 12 & 3 == 0 {
            let (qx, qz) = (fx.truncatingRemainder(dividingBy: half) - half / 2, fz.truncatingRemainder(dividingBy: half) - half / 2)
            return (qx * qx + qz * qz < 0.36 * 0.36 ? Mat.crop : Mat.dry, lamp, 0)
        }
        return (crop, lamp, 0)
    }
}

/// Whether a spot lies on a winding line `width` km wide: the line along which noise of this `scale` crosses its
/// middle value. Rivers and highways are drawn this way, so they run on for ever without being stored anywhere.
private func onLine(_ x: Double, _ z: Double, scale: Double, layers: Int, salt: UInt64, width: Double) -> Bool {
    let here = fbm(x / scale, z / scale, layers, salt) - 0.5
    guard abs(here) < 0.03 else { return false }
    // How fast the noise changes here says how far off the line is.
    let step = 0.25, east = fbm((x + step) / scale, z / scale, layers, salt) - 0.5 - here, north = fbm(x / scale, (z + step) / scale, layers, salt) - 0.5 - here
    return abs(here) < Float(width / 2 / step) * (east * east + north * north).squareRoot()
}

/// A well-mixed hash of a pair of whole numbers.
@inline(__always) private func hash(_ x: Int, _ z: Int, _ salt: UInt64) -> UInt64 {
    var v = UInt64(bitPattern: Int64(x)) &* 0x9E37_79B9_7F4A_7C15 ^ UInt64(bitPattern: Int64(z)) &* 0xC2B2_AE3D_27D4_EB4F ^ salt &* 0x1656_67B1_9E37_79F9
    v = (v ^ (v >> 31)) &* 0xBF58_476D_1CE4_E5B9
    v = (v ^ (v >> 29)) &* 0x94D0_49BB_1331_11EB
    return v ^ (v >> 32)
}

/// A hash as a number from 0 up to 1.
@inline(__always) private func unit(_ v: UInt64) -> Float { Float(v >> 40) / 16_777_216 }

/// A cheap random byte for a pixel of a row at a tick of the clock, for sparkles and for which lamps are lit.
@inline(__always) private func scatter(_ n: Int, _ row: Int, _ tick: UInt32) -> UInt8 {
    var v = UInt32(truncatingIfNeeded: n) &* 0x9E37_79B1 ^ UInt32(truncatingIfNeeded: row) &* 0x85EB_CA6B ^ tick &* 0xC2B2_AE35
    v = (v ^ (v >> 15)) &* 0x2C1B_3C6D
    return UInt8(truncatingIfNeeded: (v ^ (v >> 12)) >> 8)
}

/// Smooth noise from 0 to 1, with one bump per unit.
private func noise(_ x: Double, _ z: Double, _ salt: UInt64) -> Float {
    let (fx, fz) = (x.rounded(.down), z.rounded(.down)), (ix, iz) = (Int(fx), Int(fz))
    var (u, v) = (Float(x - fx), Float(z - fz))
    (u, v) = (u * u * (3 - 2 * u), v * v * (3 - 2 * v))
    let a = unit(hash(ix, iz, salt)), b = unit(hash(ix + 1, iz, salt)), c = unit(hash(ix, iz + 1, salt)), d = unit(hash(ix + 1, iz + 1, salt))
    return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v
}

/// Noise with finer noise laid over it, each layer half the size and half the strength of the last; 0 to 1.
private func fbm(_ x: Double, _ z: Double, _ layers: Int, _ salt: UInt64) -> Float {
    var (sum, strength, x, z) = (Float(0), Float(0.5), x, z)
    for layer in 0..<layers {
        sum += strength * noise(x, z, salt &+ UInt64(layer) &* 101)
        (strength, x, z) = (strength / 2, x * 2.03, z * 2.03)
    }
    return sum / (1 - strength * 2)
}

/// The 4×4 ordered-dither thresholds, for stepping haze between its bands.
private let dither: [Float] = (0..<16).map { bayer($0 % 4, $0 / 4) }

/// One packed colour moved toward another by `t` parts in 256.
@inline(__always) private func blend(_ a: UInt32, _ b: UInt32, _ t: UInt32) -> UInt32 {
    let redBlue = ((a & 0xFF00FF) * (256 - t) + (b & 0xFF00FF) * t) >> 8 & 0xFF00FF
    return 0xFF00_0000 | redBlue | ((a & 0xFF00) * (256 - t) + (b & 0xFF00) * t) >> 8 & 0xFF00
}

private func rgb(_ r: Int, _ g: Int, _ b: Int) -> RGB { RGB(Float(r), Float(g), Float(b)) / 255 } // as in PixelCity.swift, which says why

private func pack(_ c: RGB) -> UInt32 {
    let c = pointwiseMin(pointwiseMax(c, .zero), .one) * 255
    return 0xFF00_0000 | UInt32(c.z) << 16 | UInt32(c.y) << 8 | UInt32(c.x)
}
