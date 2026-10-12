import simd
import SpriteKit

/// Pixel Window Seat in Earth orbit: the same window, on the International Space Station. The real Earth turns
/// below at the station's own pace, an orbit every 93 minutes with its sunrise and its sunset, under the real Sun,
/// Moon and stars, with a solar array wing where the airliner's wing was; or from the station's Cupola, the dome
/// of seven windows (PixelCupola.swift).
///
/// The ground is drawn as the airliner's is, in strips that slide by whole cells, but here a strip is a parallel
/// of the orbit (the ground a fixed distance to one side of the track) and it lies across the picture in a curve.
/// Each pixel of the pane is given its strip and its place along it once, when the scene is built (`lay`), and a
/// cell of ground is worked out once, as it slides into view (`advance`).
final class PixelOrbit: SKScene {
    /// Which window this is, a menu of three under the key the Earth orbit switch had before the train, so that a
    /// stored 1 is still the station: 0 the airliner, 1 the space station, 2 the train.
    nonisolated static let on = Knob(key: "seat.orbit", label: "Window on", range: 0...2, standard: 0, section: "View",
                                     format: .choice(["An airliner", "The space station", "A train"]), order: [0, 2, 1])
    nonisolated static let array = Knob(key: "seat.array", label: "Seat", range: 0...1, standard: 0, section: "View",
                                        format: .choice(["By the solar array", "Clear of it"]), shownWhen: "seat.orbit", shownAt: 1)
    nonisolated static let looking = Knob(key: "seat.orbitLooking", label: "Looking", range: 0...4, standard: 0, section: "View",
                                          format: .choice(["Out the side", "Ahead", "Straight down", "Into the Cupola", "From the Cupola"]),
                                          shownWhen: "seat.orbit", shownAt: 1)
    nonisolated static let realClouds = Knob(key: "seat.realClouds", label: "Today's real clouds", range: 0...1, standard: 0,
                                             section: "Flight", format: .toggle, shownWhen: "seat.orbit", shownAt: 1)
    nonisolated static let follow = Knob(key: "seat.follow", label: "Follow the real ISS", range: 0...1, standard: 0,
                                         section: "Flight", format: .toggle, shownWhen: "seat.orbit", shownAt: 1)
    nonisolated static let knobs = [on, array, looking, realClouds, follow]

    /// Settings' pick of window: 0 the airliner, 1 the space station, 2 the train.
    nonisolated static var mode: Int { on.value > 1.5 ? 2 : on.value > 0.5 ? 1 : 0 }

    /// Where the station is and what moment it is there. Every copy of the scene shares it, as the airliner's
    /// copies share their flight, so each display's window looks out over the same ground.
    static var orbit = Orbit.start()
    private static var orbitAt: TimeInterval?

    private let w: Int, h: Int // the canvas, in art pixels
    private let glass: (x: Int, y: Int, w: Int, h: Int) // the window's pane on it
    private let windowSize: Int, looks: Int // Settings' Window and Looking, as the scene was built
    private let dome: PixelCupola? // the Cupola, for the two ways of looking that are from it
    private let hardware: [(at: Int, day: UInt32, low: UInt32, dark: UInt32)] // what stands outside it, for the seat that sees it
    private let lens: OrbitLens
    private let eye: (ahead: Sky.Vector, right: Sky.Vector, up: Sky.Vector) // the camera, in the station's own axes

    // What each pixel of the pane looks at: its ring of ground (-1 for sky) and its place round it; which way the
    // ground there faces and which way we are from it, for the light and the Sun's glint; and its haze and dither.
    private var ringOf: [Int32], place: [Int32], facing: [SIMD3<Float>], toward: [SIMD3<Float>], slant: [Float]
    private var haze: [UInt8], dither: [UInt8]
    private var air: [(at: Int, height: Float, facing: SIMD3<Float>)] = [] // the pixels that look through the air at the limb
    private var rings: [Ring] = []
    private var cells: [UInt16] = []
    private var world: OrbitWorld
    private var wing: [(at: Int, part: UInt8)] = []
    private var reached = 0.0 // how far round the orbit this copy last saw the station
    private var paint = OrbitPaint()
    private var picture: [UInt32]
    private let texture: SKMutableTexture
    private let canvas = SKNode(), outside = SKSpriteNode(), cabin = SKSpriteNode()

    private var settings: [Double] = []
    private var retired = false // it has handed over to another scene, and is fading out
    private var paintEvery = 1 / 15.0
    private var clock: TimeInterval = 0, lastUpdate: TimeInterval?, painted: TimeInterval = -1
    private var sun = Sky.Vector(0, 0, 1), moon = Sky.Vector(0, 0, 1), moonLit = 0.5, skyAt = Date.distantPast
    /// Settings' Speed; or the real pace while following the real station, whatever the slider was left at, which
    /// Settings shows by greying it out at 1× (`Knob.lockedWhen`).
    private var pace: Double { Self.follow.value > 0.5 ? 1 : PixelWindowSeat.speed.value }

    override init(size: CGSize) {
        let pane = PixelWindowSeat.pane(size)
        (w, h, looks) = (pane.w, pane.h, Int(Self.looking.value))
        // (The Cupola has the whole canvas for its pane, as Window's None does: its dome is painted into the picture.)
        dome = looks > 2 ? PixelCupola(w: w, h: h, within: looks == 4) : nil
        hardware = Self.array.value < 0.5 ? dome?.hardware ?? [] : []
        (glass, windowSize) = dome == nil ? (pane.glass, pane.window) : ((0, 0, pane.w, pane.h), 3)
        let (gw, gh) = (glass.w, glass.h)
        lens = dome?.lens ?? OrbitLens(focal: Double(gh) * 1.2, fisheye: false, w: gw, h: gh) // the airliner's lens: 45° tall
        // Out of the left side as the airliner looks, nose to the right, tipped down until the Earth's edge lies where
        // the airliner's horizon does; or the same tip looking ahead; or straight down, with the way we fly to the
        // right, which is how both of the Cupola's views look too.
        let (yaw, pitch) = [(Double.pi / 2, 25.0), (0, 25), (Double.pi / 2, 90)][min(looks, 2)]
        let tip = pitch * .pi / 180
        let ahead = Sky.Vector(cos(tip) * cos(yaw), cos(tip) * sin(yaw), -sin(tip)), right = Sky.Vector(sin(yaw), -cos(yaw), 0)
        eye = (ahead, right, cross(right, ahead))
        let count = gw * gh
        (ringOf, place) = ([Int32](repeating: -1, count: count), [Int32](repeating: 0, count: count))
        (facing, toward) = ([SIMD3<Float>](repeating: .zero, count: count), [SIMD3<Float>](repeating: .zero, count: count))
        (slant, haze, dither) = ([Float](repeating: 0, count: count), [UInt8](repeating: 0, count: count), [UInt8](repeating: 0, count: count))
        picture = [UInt32](repeating: 0, count: count)
        texture = SKMutableTexture(size: CGSize(width: gw, height: gh))
        world = OrbitWorld(map: EarthMap.shared())
        super.init(size: size)
        canvas.setScale(max(2, (size.height / 240).rounded()))
        addChild(canvas)
        texture.filteringMode = .nearest
        outside.texture = texture
        outside.size = CGSize(width: gw, height: gh)
        outside.anchorPoint = .zero
        outside.position = CGPoint(x: glass.x, y: glass.y)
        (cabin.size, cabin.anchorPoint, cabin.zPosition, cabin.isHidden) = (CGSize(width: w, height: h), .zero, 2, windowSize == 3)
        canvas.addChild(outside)
        canvas.addChild(cabin)
        lay()
        layWing()
        reached = Self.orbit.along
        settings = PixelWindowSeat.knobs.map(\.value)
        if windowSize < 3 { paintFrame() }
        redraw()
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged),
                                               name: UserDefaults.didChangeNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func didMove(to view: SKView) {
        // The real station's place and today's clouds, each only while its switch is on. Both polls are shared and
        // go to the network only when their own data is stale, however many displays ask.
        run(.repeatForever(.sequence([.run { [weak self] in self?.poll() }, .wait(forDuration: 60)])))
    }

    private func poll() {
        if Self.follow.value > 0.5 { ISS.shared.poll() }
        if Self.realClouds.value > 0.5 {
            Clouds.shared.loadCache()
            Clouds.shared.poll()
        }
    }

    /// Any change but the speed is a different picture (another view, another window, other weather, or the
    /// airliner back): it dissolves into a new scene with both still running, as the airliner's changes do.
    @objc private func settingsChanged() {
        let picked = PixelWindowSeat.knobs.map(\.value)
        guard picked != settings, !retired else { return }
        let speedOnly = zip(PixelWindowSeat.knobs, zip(picked, settings)).allSatisfy { $0.key == PixelWindowSeat.speed.key || $1.0 == $1.1 }
        settings = picked
        if speedOnly { redraw() } else { handOver() }
    }

    /// Dissolves into a new scene, built for the settings and the orbit as they are now, with both still running.
    private func handOver() {
        guard let view, !retired else { return } // (with no view to hand over in, as in the tests, it stays as built)
        let fade = SKTransition.crossFade(withDuration: 0.8)
        (fade.pausesIncomingScene, fade.pausesOutgoingScene) = (false, false)
        let next = pixelWindowSeat(size: size)
        next.scaleMode = scaleMode
        retired = true
        view.presentScene(next, transition: fade)
    }

    // MARK: - The view's geometry (once)

    /// Gives every pixel of the pane its ray, and every pixel that meets the ground its ring. The ground is cut
    /// into strips, each a parallel of the orbit as wide as the finest pixel that looks at it, and a strip into
    /// cells as long as its finest pixel; where a strip runs off into the distance its pixels use rings of cells
    /// twice, four times, eight times as long, so that a pixel always shows about one cell.
    private func lay() {
        let (gw, gh) = (glass.w, glass.h), radius = Orbit.radius, far = Orbit.radius + Orbit.height
        var along = [Double](repeating: 0, count: gw * gh), across = [Double](repeating: .nan, count: gw * gh)
        for y in 0..<gh {
            for x in 0..<gw {
                let i = y * gw + x
                let through = lens.ray(x, y), ray = normalize(eye.ahead * through.z + eye.right * through.x + eye.up * through.y)
                let down = ray.z * far, reach = down * down - (far * far - radius * radius)
                dither[i] = UInt8(bayer(x, y) * 16)
                if dome?.sky[i] == false { continue } // the dome is in the way: no ground is laid for it
                if down < 0, reach >= 0 {
                    let run = -down - reach.squareRoot(), ground = (Sky.Vector(0, 0, far) + ray * run) / radius
                    (along[i], across[i]) = (atan2(ground.x, ground.z), asin(ground.y))
                    (facing[i], toward[i], slant[i]) = (SIMD3<Float>(ground), SIMD3<Float>(-ray), Float(-dot(ray, ground)))
                    // More air lies in front of ground seen slantwise: a tenth of full haze straight down, most of it at the limb.
                    let thick = 1 - exp(-0.085 / max(Double(slant[i]), 0.06))
                    haze[i] = UInt8(min(Double(OrbitPaint.hazes - 1), thick * Double(OrbitPaint.hazes - 1) + Double(bayer(x, y))))
                } else if down < 0 {
                    // Sky: how high above the ground the ray passes at its nearest, and which way the Earth faces there.
                    let nearest = Sky.Vector(0, 0, far) - ray * down, height = length(nearest) - radius
                    if height < Double(OrbitPaint.airTop) { air.append((i, Float(height), SIMD3<Float>(normalize(nearest)))) }
                }
            }
        }
        // How much of each angle one pixel spans, from its neighbours.
        func span(_ of: [Double], _ i: Int, _ x: Int, _ y: Int) -> Double {
            var most = 0.0
            for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] where x + dx >= 0 && x + dx < gw && y + dy >= 0 && y + dy < gh {
                let j = i + dy * gw + dx
                if !across[j].isNaN { most = max(most, abs(of[j] - of[i])) }
            }
            return most
        }
        let seen = (0..<gw * gh).filter { !across[$0].isNaN }
        guard let low = seen.map({ across[$0] }).min(), let high = seen.map({ across[$0] }).max() else { return }
        let finest = 0.5 / radius // no cell is finer than half a km
        // Strips: walk from one side of the view to the other, each as wide as the finest pixel there.
        let bins = 1024, width = max(high - low, 1e-9) / Double(bins)
        var fine = [Double](repeating: .infinity, count: bins + 1)
        var spans = [(along: Double, across: Double)](repeating: (0, 0), count: gw * gh)
        for i in seen {
            spans[i] = (max(span(along, i, i % gw, i / gw), finest), max(span(across, i, i % gw, i / gw), finest))
            let b = Int((across[i] - low) / width)
            fine[b] = min(fine[b], spans[i].across)
        }
        var edges = [low]
        while edges.last! < high {
            let b = min(bins, Int((edges.last! - low) / width))
            edges.append(edges.last! + (fine[b].isFinite ? fine[b] : width))
        }
        var strip = [Int](repeating: 0, count: gw * gh), shortest = [Double](repeating: .infinity, count: edges.count)
        for i in seen {
            var (a, b) = (0, edges.count - 1) // the strip whose edges lie either side
            while b - a > 1 {
                let m = (a + b) / 2
                if edges[m] <= across[i] { a = m } else { b = m }
            }
            strip[i] = a
            shortest[a] = min(shortest[a], spans[i].along)
        }
        // Rings: each strip at each length of cell its pixels need, as long as the stretch of it they look at.
        var index: [Int: Int] = [:], bounds: [(low: Int, high: Int)] = []
        for i in seen {
            let s = strip[i], level = min(7, max(0, Int((log2(spans[i].along / shortest[s]) + 0.5).rounded(.down))))
            let size = shortest[s] * Double(1 << level), k = Int((along[i] / size).rounded())
            let key = s * 8 + level
            if index[key] == nil {
                index[key] = rings.count
                let middle = (edges[s] + edges[min(s + 1, edges.count - 1)]) / 2
                rings.append(Ring(across: middle, size: size, wide: (edges[min(s + 1, edges.count - 1)] - edges[s]) * radius))
                bounds.append((k, k))
            }
            let r = index[key]!
            bounds[r] = (min(bounds[r].low, k), max(bounds[r].high, k))
            (ringOf[i], place[i]) = (Int32(r), Int32(k))
        }
        var base = 0
        for r in rings.indices {
            (rings[r].low, rings[r].count, rings[r].base) = (bounds[r].low, bounds[r].high - bounds[r].low + 1, base)
            base += rings[r].count
        }
        for i in seen { place[i] -= Int32(rings[Int(ringOf[i])].low) }
        cells = [UInt16](repeating: 0, count: base)
    }

    // MARK: - The light

    /// Works out what follows the clock slowly: where the Sun and Moon are among the stars, and the weather's
    /// settings. Every 30 s by the wall clock and when a setting changes; and paints, as the airliner's does, since
    /// a view that is frozen or not drawing yet never reaches `update`.
    private func redraw() {
        skyAt = Date()
        let jd = Sky.julianDate(Self.orbit.date)
        (sun, moon, moonLit) = (Sky.sun(jd), Sky.moon(jd), Sky.moonPhase(jd).lit)
        // Paint as often as the finest cells move on, and half as often again, between 15 and 30 times a second.
        let quickest = rings.map(\.size).min() ?? 1
        paintEvery = 1 / min(30, max(15, Orbit.pace * pace / quickest * 1.5))
        let weather = (Int(PixelWindowSeat.clouds.value), Self.realClouds.value > 0.5)
        if weather != (world.weather, world.real) {
            (world.weather, world.real) = weather
            for r in rings.indices { rings[r].first = .min }
        }
        if world.real { Clouds.shared.loadCache() }
        paint = OrbitPaint(moon: Float(moonLit), storms: PixelWindowSeat.lightning.value > 0.5)
        advance()
        compose()
    }

    /// The station's window in its module's wall: a dark seal, a ring of metal with its bolts, and the wall beyond,
    /// dark as a camera set for the Earth outside sees it.
    private func paintFrame() {
        var px = Pixels(w, h)
        let a = Float(glass.w) / 2, b = Float(glass.h) / 2, round = min(a, b) * 0.58
        for y in 0..<h {
            for x in 0..<w {
                // How far outside the pane's rounded outline, as the airliner's cabin measures it.
                let qx = abs(Float(x) + 0.5 - (Float(glass.x) + a)) - a + round, qy = abs(Float(y) + 0.5 - (Float(glass.y) + b)) - b + round
                let d = (max(qx, 0) * max(qx, 0) + max(qy, 0) * max(qy, 0)).squareRoot() + min(max(qx, qy), 0) - round
                guard d >= 0 else { continue }
                if d < 1.5 {
                    px.plot(x, y, rgb(6, 6, 9)) // the seal
                } else if d < 2.5 {
                    px.plot(x, y, rgb(84, 88, 100)) // the one bright line, where the inner bezel catches the light
                } else if d < 9 {
                    // The ring is lighter along its upper edge, where the module's lamps reach it.
                    let lit = d > 6.5 ? 0.82 : d < 3 ? 0.7 : 1 as Float
                    px.plot(x, y, rgb(54, 58, 68) * lit * (Float(y) > Float(glass.y) + b ? 1.1 : 0.9))
                    let run = qx <= 0 ? x - glass.x : qy <= 0 ? y - glass.y : 0 // along a straight side; none round the corners
                    if d > 4, d < 6, run % 18 == 9 { px.plot(x, y, rgb(112, 116, 128)) } // a bolt
                } else {
                    let v = abs(Float(y) / Float(h) - 0.52) * 2, fall = ((v * v * 3 + bayer(x, y) * 0.7).rounded(.down)) / 4
                    px.plot(x, y, mix(rgb(24, 26, 33), rgb(14, 15, 20), fall))
                }
            }
        }
        for x in [glass.x - 24, glass.x + glass.w + 23] { px.fill(x, 0, 1, h, rgb(13, 14, 18)) } // seams in the wall's panels
        cabin.texture = px.texture()
    }

    /// Marks out the solar array wing for the seat beside it: two blankets either side of a lattice mast, lying
    /// flat below the window and reaching out toward the limb (or, looking straight down, across the corner).
    // ponytail: a real wing stands across the truss and turns about it once an orbit, 4° a minute. This one lies along
    // our line of sight, where the airliner's wing is, and never moves: rolled about its length it stood up across
    // the view as a slab. Model the truss and its joint if it should ever be true to the station.
    private func layWing() {
        wing = []
        guard Self.array.value < 0.5, dome == nil else { return } // (from the Cupola it is the station's hardware that Seat shows)
        let (gw, gh) = (glass.w, glass.h)
        // In the camera's own axes (right, up, ahead), in metres.
        let root: Sky.Vector = looks == 2 ? [24, -12.5, 30] : [-8.5, -6.5, 14], tip: Sky.Vector = looks == 2 ? [7.5, -4.5, 30] : [-2.2, 0.3, 48]
        let length = simd.length(tip - root), axis = (tip - root) / length, half = 5.0
        let up: Sky.Vector = looks == 2 ? [0, 0, -1] : [0, 1, 0] // toward the camera's side of it
        let face = normalize(up - axis * dot(up, axis))
        let side = cross(axis, face)
        for y in 0..<gh {
            for x in 0..<gw {
                let ray = lens.ray(x, y)
                let fall = dot(ray, face)
                guard abs(fall) > 1e-6 else { continue }
                let t = dot(root, face) / fall
                guard t > 0 else { continue }
                let p = ray * t - root, u = dot(p, axis), v = dot(p, side)
                guard u >= 0, u <= length, abs(v) <= half else { continue }
                // Parts: 1 blanket, 2 a fold line across it, 3 the seam along it, 4 its lit rim, 5 the mast's lattice, 6 its gaps.
                var part: UInt8 = 1
                if abs(v) < 1.1 {
                    let weave = (u + v + 4).truncatingRemainder(dividingBy: 2.2), back = (u - v + 4).truncatingRemainder(dividingBy: 2.2)
                    part = abs(abs(v) - 0.95) < 0.15 || weave < 0.3 || back < 0.3 ? 5 : 6
                } else if abs(v) > half - 0.22 || u > length - 0.3 {
                    part = 4
                } else if abs(abs(v) - 3.05) < 0.1 {
                    part = 3
                } else if u.truncatingRemainder(dividingBy: 2.3) < 0.28 {
                    part = 2
                }
                wing.append((y * gw + x, part))
            }
        }
    }

    // MARK: - Motion (every frame)

    override func update(_ currentTime: TimeInterval) {
        let dt = min(max(currentTime - (lastUpdate ?? currentTime), 0), 0.1)
        lastUpdate = currentTime
        clock += dt
        Self.orbit.advance(min(max(currentTime - (Self.orbitAt ?? currentTime), 0), 0.1) * pace)
        Self.orbitAt = currentTime
        // With Follow on, the station is where the real one is. A fix far from where we are is a
        // jump, which every copy of the scene sees and dissolves across; after that each fix is a nudge. (Not near
        // the top of the orbit, where a hair of latitude is a long way round it.)
        if Self.follow.value > 0.5, let fix = ISS.shared.position(), abs(fix.latitude) < 45,
           let soon = ISS.shared.position(at: Date() + 5) {
            let real = Orbit(date: Date(), latitude: fix.latitude, longitude: fix.longitude, climbing: soon.latitude > fix.latitude)
            let (ahead, round) = (remainder(real.along - Self.orbit.along, 2 * .pi), remainder(real.node - Self.orbit.node, 2 * .pi))
            if abs(ahead) > 0.01 || abs(round) > 0.01 || abs(Self.orbit.date.timeIntervalSinceNow) > 5 {
                Self.orbit = real
            } else {
                (Self.orbit.along, Self.orbit.node, Self.orbit.date) = (Self.orbit.along + ahead * 0.05, Self.orbit.node + round * 0.05, Date())
            }
        }
        if abs(Self.orbit.along - reached) > 0.01 { handOver() }
        reached = Self.orbit.along
        if abs(Date().timeIntervalSince(skyAt)) >= 30 { redraw() }
        if clock - painted >= paintEvery - 0.002 {
            advance()
            compose()
        }
    }

    /// Slides each ring on to where the station has got to, laying the cells that come into view.
    // ponytail: a cell keeps the Earth as it was when it was laid, though the Earth turns on under the orbit, 43 km
    // while the near ground crosses the pane. So the ground slides 3° off its true heading, and the map is drawn with
    // a slight shear. Lay cells by where the Earth will be as they pass if anyone can ever tell.
    private func advance() {
        let orbit = Self.orbit, lands = orbit.lands
        let sunFixed = lands.turn * sun
        for r in rings.indices {
            let ring = rings[r], first = Int((orbit.along / ring.size).rounded(.down)) + ring.low
            guard first != ring.first else { continue }
            for n in (ring.first != .min && first - ring.first < ring.count && first > ring.first ? ring.first + ring.count : first)..<first + ring.count {
                let a = Double(n) * ring.size
                let spot = lands.turn * ((lands.node * cos(a) + lands.rise * sin(a)) * cos(ring.across) + lands.port * sin(ring.across))
                cells[ring.base + ((n % ring.count) + ring.count) % ring.count] = world.cell(spot, long: ring.size * Orbit.radius, wide: ring.wide, sun: sunFixed, day: orbit.date, n: n &+ r &* 7919)
            }
            rings[r].first = first
        }
    }

    /// Paints the view: the ground and its cloud by the light that falls on each pixel, the air along the limb, the
    /// stars, the Sun and the Moon, and the wing over it all; or, from the Cupola, the station's hardware and the dome.
    private func compose() {
        painted = clock
        let (gw, gh) = (glass.w, glass.h), orbit = Self.orbit, axes = orbit.axes
        func ours(_ v: Sky.Vector) -> Sky.Vector { [dot(v, axes.forward), dot(v, axes.port), dot(v, axes.up)] } // into the station's axes
        let s = SIMD3<Float>(ours(sun)), dip = Orbit.dip
        // How much of the Sun shows over the Earth's edge from the station, and how low it is: the wing's own light.
        let lift = asin(Double(s.z)) + dip, lit = Float(min(max(lift / 0.012 + 0.5, 0), 1)), low = Float(min(max(1 - lift / 0.12, 0), 1))
        // The wing shows its dark cells one day and its gold back the next. It changes at midnight, when either is
        // the same dark shape against the Earth.
        let lands = orbit.lands, noon = atan2(dot(sun, lands.rise), dot(sun, lands.node)) // where round the orbit the Sun stands highest
        let cellSide = Int(((orbit.along - noon) / (2 * .pi) + 0.5).rounded(.down)) & 1 == 0
        let tick = UInt32(truncatingIfNeeded: Int(clock * 3))
        let flashes = (0..<16).map { paint.storms ? SeatWorld.lightning($0, at: clock) : 0 }
        let mats = OrbitPaint.mats, hazes = OrbitPaint.hazes
        let space = pack(rgb(4, 5, 9))
        picture.withUnsafeMutableBufferPointer { out in
            for i in 0..<gw * gh {
                let r = Int(ringOf[i])
                guard r >= 0 else {
                    out[i] = space
                    continue
                }
                let ring = rings[r]
                var slot = Int(place[i]) + ((ring.first % ring.count) + ring.count) % ring.count
                if slot >= ring.count { slot -= ring.count }
                let cell = Int(cells[ring.base + slot]), n = facing[i]
                let sunward = n.x * s.x + n.y * s.y + n.z * s.z
                let step = (Int(paint.light[Int((sunward + 1) * 127.99)]) + Int(dither[i])) >> 4, hz = Int(haze[i])
                let kind = cell & 31, cloud = cell >> 8 & 3
                var c: UInt32
                if cloud != 0 {
                    c = paint.cloud[(min(OrbitPaint.lights - 1, step + 2) * hazes + hz) * 4 + cloud]
                    let storm = cell >> 11 & 15
                    if storm != 0, flashes[storm] > 0 { c = blend(c, paint.bolt, UInt32(flashes[storm] * (step < 6 ? 200 : 70))) }
                } else {
                    c = paint.ground[((step * 2 + (cell >> 10 & 1)) * hazes + hz) * mats + kind]
                    let lamp = cell >> 5 & 7
                    if lamp != 0, step < 5, scatter(i, slot, tick >> 2) > 6 {
                        c = paint.lamp[hz * 8 + lamp]
                    } else if kind < 4, step > 6 {
                        // The Sun's glint on water: sparkles where the sea would mirror the Sun to us, thickest at its image.
                        let v = toward[i], mirror = 2 * sunward * slant[i] - (v.x * s.x + v.y * s.y + v.z * s.z)
                        if mirror > 0.96, Float(scatter(i, 0, tick)) < (mirror - 0.96) * 6400 * (cell >> 10 & 1 == 0 ? 1 : 0.2) { c = paint.sparkle }
                    }
                }
                out[i] = c
            }
            // The air along the Earth's edge, seen edge-on: its colour by how high the ray passes and the light there.
            for spot in air {
                let sunward = spot.facing.x * s.x + spot.facing.y * s.y + spot.facing.z * s.z
                let step = (Int(paint.airLight[Int((sunward + 1) * 127.99)]) + Int(dither[spot.at])) >> 4
                let band = min(OrbitPaint.bands - 1, Int(spot.height / OrbitPaint.airTop * Float(OrbitPaint.bands) + Float(dither[spot.at]) / 16 - 0.5))
                out[spot.at] = paint.air[step * OrbitPaint.bands + max(band, 0)]
            }
            // The real stars, turning about the station as it goes round: bright ones always, the rest when we are
            // in the Earth's shadow, since a camera set for the sunlit Earth sees none.
            let dark = 1 - lit * 0.85
            func spot(_ v: Sky.Vector) -> (x: Int, y: Int)? { lens.spot([dot(v, eye.right), dot(v, eye.up), dot(v, eye.ahead)]) }
            for star in LiveSky.catalogue {
                let v = ours(star.direction)
                guard asin(v.z) > -dip + 0.05, let at = spot(v), ringOf[at.y * gw + at.x] < 0 else { continue } // clear of the Earth and its air
                let shine = Float(min(1, pow(2.512, 1.2 - star.magnitude) * 2.2 + 0.22)) * dark
                if shine > 0.1 { out[at.y * gw + at.x] = blend(out[at.y * gw + at.x], 0xFFFF_F4EC, UInt32(min(shine, 1) * 255)) }
            }
            func disc(_ v: Sky.Vector, radius: Int, _ colour: (Int, Int) -> UInt32?) {
                guard asin(v.z) > -dip - 0.01, let at = spot(v) else { return }
                for dy in -radius...radius {
                    for dx in -radius...radius where dx * dx + dy * dy <= radius * radius + 1 {
                        let (x, y) = (at.x + dx, at.y + dy)
                        if x >= 0, x < gw, y >= 0, y < gh, ringOf[y * gw + x] < 0, let c = colour(dx, dy) { out[y * gw + x] = c }
                    }
                }
            }
            // The Moon, by how much of it is lit; and the Sun. Out of the side the Sun rises and sets off the edge of
            // the window, so its bearing is squeezed toward the middle, as the airliner's is, to keep it in view.
            let moonHere = ours(moon), edge = Float(1 - 2 * moonLit) * 3
            disc(moonHere, radius: 3) { dx, dy in Float(dx) > edge * (1 - Float(dy * dy) / 9).squareRoot() ? 0xFFDE_F0F2 : nil }
            var sunHere = Sky.Vector(s)
            if looks == 0 {
                let bearing = atan2(sunHere.x, sunHere.y) * 0.3, level = (1 - sunHere.z * sunHere.z).squareRoot()
                sunHere = [level * sin(bearing), level * cos(bearing), sunHere.z]
            }
            if lit > 0, let at = spot(sunHere) {
                // Its glare, wide and warm while it is on the limb, and the disc.
                let reach = Float(4 + 9 * low), warm = blend(0xFFF6_FFFF, 0xFF58_B0FF, UInt32(low * 255))
                for y in max(0, at.y - 30)..<min(gh, at.y + 31) {
                    for x in max(0, at.x - 44)..<min(gw, at.x + 45) {
                        let dx = Float(x - at.x) / (reach * 1.5), dy = Float(y - at.y) / reach
                        let glow = exp(-(dx * dx + dy * dy)) * lit * (ringOf[y * gw + x] < 0 ? 1 : 0.35)
                        let steps = ((glow * 5 + Float(dither[y * gw + x]) / 16 * 0.8).rounded(.down)) / 5
                        if steps > 0 { out[y * gw + x] = blend(out[y * gw + x], warm, UInt32(min(steps, 1) * 230)) }
                    }
                }
                disc(sunHere, radius: 3) { _, _ in 0xFFFF_FFFF }
            }
            // The wing: its cells or its gold back, in the Sun, in the low Sun's colour, or in the Earth's shadow.
            let tones = cellSide ? paint.cells : paint.gold
            for spot in wing {
                let tone = tones[Int(spot.part)]
                out[spot.at] = blend(blend(tone.dark, tone.day, UInt32(lit * 255)), tone.low, UInt32(lit * low * 200))
            }
            // The Cupola: the hardware outside in the wing's three lights, then the dome over everything, as painted
            // while the station is in sunlight and dimmed in the Earth's shadow. A low Sun glints on the bezel across
            // each window from it.
            if let dome {
                for spot in hardware { out[spot.at] = blend(blend(spot.dark, spot.day, UInt32(lit * 255)), spot.low, UInt32(lit * low * 200)) }
                for spot in dome.inside { out[spot.at] = blend(spot.dark, spot.day, UInt32(lit * 256)) }
                let glint = UInt32(lit * low * 256), from = normalize(SIMD2(Float(dot(sunHere, eye.right)), Float(dot(sunHere, eye.up))))
                if glint > 0 {
                    for spot in dome.bezels where spot.x * from.x + spot.y * from.y < -0.45 { out[spot.at] = blend(out[spot.at], PixelCupola.glint, glint) }
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

/// The camera's lens over a pane `w` by `h` pixels, between a pixel and a direction in the camera's own axes (right,
/// up, ahead). Rectilinear, with `focal` in pixels per unit of tangent; or an equidistant fisheye, in pixels per
/// radian, which puts a direction as far from the pane's centre as its angle off the axis, and so sees behind itself.
struct OrbitLens {
    let focal: Double, fisheye: Bool, w: Int, h: Int

    /// The ray through a pixel's centre, of any length.
    @inline(__always) func ray(_ x: Int, _ y: Int) -> Sky.Vector {
        let (px, py) = (Double(x) + 0.5 - Double(w) / 2, Double(y) + 0.5 - Double(h) / 2)
        guard fisheye else { return [px, py, focal] }
        // (A pixel past the half turn, where the picture would fold back over itself, looks straight behind.)
        let off = (px * px + py * py).squareRoot(), angle = min(off / focal, .pi), turn = off > 0 ? sin(angle) / off : 0
        return [px * turn, py * turn, cos(angle)]
    }

    /// Where a unit direction falls on the pane, in pixels from its lower left corner, or nil where the lens cannot
    /// put it: beside or behind the rectilinear one, or straight behind the fisheye.
    @inline(__always) func place(_ v: Sky.Vector) -> (x: Double, y: Double)? {
        let px: Double, py: Double
        if fisheye {
            let off = (v.x * v.x + v.y * v.y).squareRoot()
            guard off > 0 || v.z > 0 else { return nil } // straight behind is the whole rim at once
            let scale = off > 0 ? atan2(off, v.z) * focal / off : 0
            (px, py) = (v.x * scale, v.y * scale)
        } else {
            guard v.z > 0.05 else { return nil }
            (px, py) = (v.x / v.z * focal, v.y / v.z * focal)
        }
        return (px + Double(w) / 2, py + Double(h) / 2)
    }

    /// The pixel a unit direction falls in, or nil when that is outside the pane.
    @inline(__always) func spot(_ v: Sky.Vector) -> (x: Int, y: Int)? {
        guard let at = place(v) else { return nil }
        let x = Int(at.x.rounded(.down)), y = Int(at.y.rounded(.down))
        return x >= 0 && x < w && y >= 0 && y < h ? (x, y) : nil
    }
}

/// One ring of ground: a strip of the Earth a fixed angle to one side of the track (`across`, in radians, toward
/// port), cut into cells `size` radians long and `wide` km across. `first` is the cell at the start of the
/// stretch the pane looks at, which is `count` cells long and begins `low` cells from the point under the station.
private struct Ring {
    let across: Double, size: Double, wide: Double
    var low = 0, count = 1, base = 0, first = Int.min
}

/// The station's orbit, as a circle tilted 51.63° that its node carries slowly westward, and the moment it is at.
/// It free-runs from one real fix of the ISS, so at the real speed it keeps near the real station for a while, and
/// drifts off as the real one is boosted: Follow the real ISS puts it back.
// ponytail: a circle with two rates, not SGP4: 0.04° from the real station ten minutes after its fix, unchecked beyond. Follow re-fixes it each minute.
struct Orbit {
    static let radius = 6371.0, height = 420.0, tilt = 51.63 * Double.pi / 180
    /// Radians a second along the orbit (an orbit from node to node in 92.9 minutes) and of the node's slide.
    static let pace = 5579.3 * Double.pi / 180 / 86400, nodePace = -4.95 * Double.pi / 180 / 86400
    /// How far below level the Earth's edge lies from up here: 20°.
    static let dip = acos(radius / (radius + height))

    var date: Date
    /// How far round from its northward crossing of the equator the station is, and where that crossing lies among
    /// the stars (the argument of latitude and the node's right ascension), in radians.
    var along: Double, node: Double

    /// The real ISS on 10 October 2026 at 15:43:18 UTC, from api.wheretheiss.at, flown on (or back) to now.
    /// (`ORBIT_OVER=33,9,down` and `ORBIT_DATE=2026-10-10T12:00:00Z` in the environment start it over a place at a
    /// moment instead, heading north unless it says down, so a screenshot can be taken there again.)
    static func start() -> Orbit {
        let env = ProcessInfo.processInfo.environment
        let date = env["ORBIT_DATE"].flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()
        if let over = env["ORBIT_OVER"]?.split(separator: ","), over.count >= 2, let lat = Double(over[0]), let lon = Double(over[1]) {
            var orbit = Orbit(date: date, latitude: lat, longitude: lon, climbing: over.count < 3 || over[2] != "down")
            if over.count > 3 { orbit.along += 2 * .pi } // (a fourth word: an orbit later, when the wing's other face is up)
            return orbit
        }
        var orbit = Orbit(date: Date(timeIntervalSince1970: 1_791_646_998), along: 331.37 * .pi / 180, node: 88.67 * .pi / 180)
        orbit.advance(date.timeIntervalSince(orbit.date))
        return orbit
    }

    init(date: Date, along: Double, node: Double) { (self.date, self.along, self.node) = (date, along, node) }

    /// The orbit that passes over a place at a moment, heading north or south.
    init(date: Date, latitude: Double, longitude: Double, climbing: Bool) {
        // (A map's latitude is measured from the ground's own slope; the orbit's from the Earth's centre.)
        let centred = atan(0.99330 * tan(latitude * .pi / 180))
        let rise = asin(min(max(sin(centred) / sin(Self.tilt), -1), 1)), along = climbing ? rise : .pi - rise
        let turned = (Sky.siderealTime(Sky.julianDate(date)) + longitude) * .pi / 180
        self.init(date: date, along: along, node: turned - atan2(sin(along) * cos(Self.tilt), cos(along)))
    }

    mutating func advance(_ seconds: Double) {
        date += seconds
        along += Self.pace * seconds
        node += Self.nodePace * seconds
    }

    /// The orbit's own directions among the stars: toward its northward crossing, a quarter turn on from there, and
    /// its pole, which is the station's port side; and the turn from the stars' frame to the Earth's own.
    var lands: (node: Sky.Vector, rise: Sky.Vector, port: Sky.Vector, turn: simd_double3x3) {
        let spin = -Sky.siderealTime(Sky.julianDate(date)) * .pi / 180
        return ([cos(node), sin(node), 0], [-sin(node) * cos(Self.tilt), cos(node) * cos(Self.tilt), sin(Self.tilt)],
                [sin(node) * sin(Self.tilt), -cos(node) * sin(Self.tilt), cos(Self.tilt)],
                simd_double3x3(rows: [[cos(spin), -sin(spin), 0], [sin(spin), cos(spin), 0], [0, 0, 1]]))
    }

    /// The station's own axes among the stars: the way it flies, its port side, and up.
    var axes: (forward: Sky.Vector, port: Sky.Vector, up: Sky.Vector) {
        let l = lands
        return (l.rise * cos(along) - l.node * sin(along), l.port, l.node * cos(along) + l.rise * sin(along))
    }

    /// The place under the station, in degrees.
    var under: (latitude: Double, longitude: Double) {
        let spot = lands.turn * axes.up
        return (asin(spot.z) * 180 / .pi, atan2(spot.y, spot.x) * 180 / .pi)
    }
}

/// NASA's Earth, as the orbit mode's world: a byte for every 4.9 km between 73° north and south, the ground's
/// material in its low five bits (`OrbitPaint.day`) and how brightly it's lit at night in its high three. Baked by
/// docs/pixel-window-seat/earth.py from the Blue Marble (September 2004, with topography and bathymetry) and the
/// Black Marble (2016), both NASA's and public domain. Held only while a scene is using it: 27 MB.
final class EarthMap {
    static let wide = 8192, high = 3322, edge = 73.0
    let bytes: [UInt8]
    @MainActor private static weak var held: EarthMap?

    @MainActor static func shared() -> EarthMap {
        if let held { return held }
        let map = EarthMap()
        held = map
        return map
    }

    init() {
        let packed = try? Data(contentsOf: resource("orbit-earth.lzfse")) as NSData
        let data = (try? packed?.decompressed(using: .lzfse)) as Data?
        bytes = data.map { [UInt8]($0) }.flatMap { $0.count == Self.wide * Self.high ? $0 : nil } ?? [UInt8](repeating: 0, count: Self.wide * Self.high)
    }

    /// The byte at a place on the unit sphere of the Earth's own frame (x through 0° N 0° E, z through the north pole).
    @inline(__always) func at(_ p: Sky.Vector) -> UInt8 {
        let lat = asin(min(max(p.z, -1), 1)) * 180 / .pi, lon = atan2(p.y, p.x) * 180 / .pi
        let y = min(max(Int((Self.edge - lat) / (2 * Self.edge) * Double(Self.high)), 0), Self.high - 1)
        return bytes[y * Self.wide + Int((lon + 180) / 360 * Double(Self.wide)) & (Self.wide - 1)]
    }
}

/// What lies at a place on the Earth: the map's ground and lamps, and the weather over it.
struct OrbitWorld {
    let map: EarthMap
    var weather = 0, real = false // Settings' Clouds, and whether the cloud is today's real map

    /// One cell of ground `long` by `wide` km at a place in the Earth's own frame: its material in bits 0 to 4, a
    /// lamp in 5 to 7, cloud in 8 and 9 (thin, broken, thick), a cloud's shadow in 10 and a storm's rhythm in 11 to 14.
    func cell(_ p: Sky.Vector, long: Double, wide: Double, sun: Sky.Vector, day: Date, n: Int) -> UInt16 {
        // A cell much bigger than the map's own takes the commonest of five places across it, so a far coast doesn't flicker.
        var byte = map.at(p)
        let big = max(long, wide)
        if big > 9 {
            let east = normalize(cross([0, 0, 1], p)), north = cross(p, east), reach = big / Orbit.radius * 0.3
            let found = [byte] + [east, -east, north, -north].map { map.at(normalize(p + $0 * reach)) }
            let ground = found.map { $0 & 31 }
            byte = (ground.max { a, b in ground.count { $0 == a } < ground.count { $0 == b } } ?? byte) | (found.map { $0 >> 5 }.max() ?? 0) << 5
        }
        var cell = UInt16(byte & 31)
        // Lamps: a lit cell by chance, one in seven where the map is dimmest and three in five in a city's heart.
        // Sodium orange, dim or full, with a bright one here and there, white downtown, and whole regions since
        // relit in cool white. (Far denser than a video camera sees from orbit, which is a black pane with a few
        // threads in it: this is the long exposures' look.)
        let glow = Int(byte >> 5), draw = hash(n, glow, 11)
        if glow > 0, Int(draw & 255) < 16 + glow * 20 {
            let pick = Int(draw >> 8 & 15)
            let lamp = glow >= 6 && pick < 5 ? 6 : glow >= 4 && pick < 6 ? 4 : pick < 4 ? 1 : noise(p, 700, 55) > 0.62 ? 7 : 2
            cell |= UInt16(lamp) << 5
        }
        let thick = cloud(p, finest: big, day: day)
        if thick > 0.5 {
            cell |= UInt16(thick > 0.8 ? 3 : thick > 0.63 ? 2 : 1) << 8
            // A storm in the thickest cloud, here and there: one of fifteen rhythms of lightning, by the place.
            let storm = noise(p, 300, 77)
            if thick > 0.74, storm > 0.66 { cell |= UInt16(1 + hash(Int((p.x * 21).rounded()), Int((p.y * 21).rounded()) &+ Int((p.z * 21).rounded()) &* 131, 5) % 15) << 11 }
        } else if dot(p, sun) > 0.1 {
            // A cloud's shadow: is there cloud where the Sun's light would come through the deck, 6 km up?
            let level = sun - p * dot(p, sun), reach = 6 / Orbit.radius / max(dot(p, sun), 0.1) * simd.length(level)
            if cloud(normalize(p + normalize(level) * reach), finest: big, day: day) > 0.58 { cell |= 1 << 10 }
        }
        return cell
    }

    /// Today's real cloud over a place, from the live map's small copy, smoothed between its pixels: they are 78 km
    /// across, and taken one at a time they show as squares 30 pixels wide.
    private static func live(latitude: Double, longitude: Double) -> Double? {
        MainActor.assumeIsolated {
            let step = 360.0 / 512, x = (longitude + 180) / step - 0.5, y = (90 - latitude) / step - 0.5
            let (west, north) = (x.rounded(.down), y.rounded(.down))
            var corners: [Double] = []
            for (dx, dy) in [(0.0, 0.0), (1, 0), (0, 1), (1, 1)] {
                guard let cover = Clouds.shared.cover(latitude: 90 - (north + dy + 0.5) * step, longitude: (west + dx + 0.5) * step - 180) else { return nil }
                corners.append(cover)
            }
            let (fx, fy) = (x - west, y - north)
            return (corners[0] + (corners[1] - corners[0]) * fx) * (1 - fy) + (corners[2] + (corners[3] - corners[2]) * fx) * fy
        }
    }

    /// How thick the cloud is over a place: none below a half, a solid deck by one. Weather systems a couple of
    /// thousand km across (made up, drifting east a little each day, or today's real ones), broken into puffs.
    func cloud(_ p: Sky.Vector, finest: Double, day: Date) -> Float {
        guard weather != 1 else { return 0 }
        var cover: Float
        if real, let live = Self.live(latitude: asin(p.z) * 180 / .pi, longitude: atan2(p.y, p.x) * 180 / .pi) {
            cover = smoothstep(0.42, 0.95, Float(live))
        } else {
            let drift = day.timeIntervalSince1970 / 86400 * 0.14, q = Sky.Vector(p.x * cos(drift) - p.y * sin(drift), p.x * sin(drift) + p.y * cos(drift), p.z)
            let bent = q + (Sky.Vector(Double(noise(q, 1500, 31)), Double(noise(q, 1500, 32)), Double(noise(q, 1500, 33))) - 0.5) * 0.09
            // Kept near the half at which cloud begins, so most of a system is a broken field and only its heart a deck.
            cover = 0.5 + (noise(bent, 2600, 41) * 0.34 + noise(bent, 1000, 42) * 0.36 + noise(bent, 380, 43) * 0.30 - 0.54) * 1.3
        }
        cover = [cover, 0, min(cover, 0.46), 0.52 + (cover - 0.5) * 0.4, 0.95][weather]
        // Clumps and puffs, down to the finest the cell can show: none smaller than its longer side, which it would
        // sample once along that side and show as speckle. So far cloud is smooth, and the limb clean.
        let puff = (finest < 56 ? noise(p, 70, 2) : 0.5) * 0.3 + (finest < 21 ? noise(p, 26, 3) : 0.5) * 0.35 + (finest < 9 ? noise(p, 11, 5) : 0.5) * 0.22 + (finest < 4 ? noise(p, 5, 9) : 0.5) * 0.13
        return cover + (puff - 0.5) * 0.9
    }
}

/// The colours, ready to copy into the picture: every material in each step of light and of haze, in the open and
/// in a cloud's shadow; cloud in its tones; the lamps; the air along the limb; and the wing.
private struct OrbitPaint {
    static let lights = 16, hazes = 12, bands = 14, mats = 18
    /// How high the air is drawn above the Earth's edge, in km: the airglow lies at 95.
    static let airTop: Float = 126
    /// Each material in full daylight, in the map's order: four depths of water, then land from pale sand through
    /// steppe, grass and forest to rock and snow. They are the airliner's own colours (`Mat.day`), by name.
    static let day: [RGB] = {
        var day = [Mat.deep, Mat.sea, Mat.sea, Mat.shallows, Mat.sandLight, Mat.duneShade, Mat.mesaLit, Mat.mesa, Mat.fallow, Mat.scrub,
                   Mat.pasture, Mat.grass, Mat.woods, Mat.pine, Mat.forest, Mat.rock, Mat.snowDim, Mat.snow].map { Mat.day[Int($0)] }
        day[2] = rgb(38, 96, 136) // a shelf sea, between the airliner's sea and its shallows
        return day
    }()
    /// What the light does to a colour at each step from deep night to a high Sun, and the haze's own colour there.
    /// Night is a moonlit one, lifted until sea, land and cloud can be told apart: a true one is black.
    static let shine: [RGB] = [RGB(0.13, 0.17, 0.31), RGB(0.19, 0.21, 0.36), RGB(0.30, 0.25, 0.35), RGB(0.50, 0.29, 0.23),
                               RGB(0.82, 0.57, 0.40), RGB(0.96, 0.81, 0.66), RGB(1.0, 0.96, 0.92), RGB(1.05, 1.03, 1.0)]
    static let veil: [RGB] = [RGB(0.05, 0.08, 0.17), RGB(0.07, 0.10, 0.20), RGB(0.15, 0.14, 0.24), RGB(0.42, 0.24, 0.20),
                              RGB(0.70, 0.48, 0.36), RGB(0.62, 0.66, 0.80), RGB(0.56, 0.73, 0.98), RGB(0.58, 0.75, 1.0)]
    /// The Sun's height over a place (as the cosine of its angle from overhead) at each of those eight.
    static let heights: [Float] = [-0.16, -0.09, -0.04, 0, 0.05, 0.13, 0.3, 0.6]

    var ground: [UInt32] = [], cloud: [UInt32] = [], lamp: [UInt32] = [], air: [UInt32] = []
    var light = [UInt8](repeating: 0, count: 256), airLight = [UInt8](repeating: 0, count: 256)
    var sparkle: UInt32 = 0, bolt: UInt32 = 0, storms = false
    var gold: [(day: UInt32, low: UInt32, dark: UInt32)] = [], cells: [(day: UInt32, low: UInt32, dark: UInt32)] = []

    init() {}

    init(moon: Float, storms: Bool) {
        self.storms = storms
        let (lights, hazes, mats, bands) = (Self.lights, Self.hazes, Self.mats, Self.bands)
        // Sixteen steps of light: the eight, and the seven half way between them.
        func at(_ table: [RGB], _ step: Int) -> RGB { (table[step / 2] + table[min((step + 1) / 2, table.count - 1)]) / 2 }
        let moonlight = 0.75 + 0.5 * moon // a full Moon's night is the brighter
        ground = [UInt32](repeating: 0, count: lights * 2 * hazes * mats)
        cloud = [UInt32](repeating: 0, count: lights * hazes * 4)
        lamp = [UInt32](repeating: 0, count: hazes * 8)
        let lamps = [RGB.zero, rgb(196, 124, 60), rgb(250, 168, 84), rgb(250, 168, 84), rgb(255, 200, 120), rgb(255, 200, 120), rgb(255, 240, 214), rgb(214, 228, 255)]
        for step in 0..<lights {
            let dim: Float = step < 5 ? moonlight : 1, shine = at(Self.shine, step) * dim, veil = at(Self.veil, step) * dim
            for hz in 0..<hazes {
                let far = Float(hz) / Float(hazes - 1)
                for (m, base) in Self.day.enumerated() {
                    ground[((step * 2) * hazes + hz) * mats + m] = pack(mix(base * shine, veil, far))
                    ground[((step * 2 + 1) * hazes + hz) * mats + m] = pack(mix(base * shine * RGB(0.62, 0.66, 0.78), veil, far))
                }
                for (t, tone) in [0, 0.76, 0.9, 1 as Float].enumerated() {
                    cloud[(step * hazes + hz) * 4 + t] = pack(mix(RGB(0.94, 0.96, 1) * tone * pointwiseMin(shine * 1.02, .one), veil, far * 0.8))
                }
                if step == 0 { for (g, colour) in lamps.enumerated() { lamp[hz * 8 + g] = pack(mix(colour, veil, far * 0.5)) } }
            }
        }
        // Where the Sun's height falls among the sixteen steps, in sixteenths of a step, so the dither can blend them.
        // The air at the limb is lit from further round than the ground under it: we see it from the side.
        for i in 0..<256 {
            let sunward = Float(i) / 127.5 - 1
            func steps(_ lead: Float) -> UInt8 {
                let x = sunward + lead
                guard let above = Self.heights.firstIndex(where: { $0 > x }) else { return 239 }
                guard above > 0 else { return 0 }
                let part = (x - Self.heights[above - 1]) / (Self.heights[above] - Self.heights[above - 1])
                return UInt8(min(239, (Float(above - 1) + part) * 32))
            }
            (light[i], airLight[i]) = (steps(0), steps(0.2))
        }
        // The air, by how high a ray passes, from photographs' own bands (docs/pixel-window-seat.md has them). By day
        // pale at the ground and blue above, gone by 60 km. Through sunrise and sunset the low air is in the Earth's
        // shadow, then red, orange and cream, white at 45 km, and blue above that. By night the green line of the
        // airglow 96 km up, over a dull orange layer, with a dark gap between that and the Earth.
        let space = rgb(4, 5, 9)
        func ramp(_ km: Float, _ stops: [(km: Float, colour: RGB)]) -> RGB {
            guard let next = stops.firstIndex(where: { $0.km > km }) else { return stops[stops.count - 1].colour }
            guard next > 0 else { return stops[0].colour }
            return mix(stops[next - 1].colour, stops[next].colour, (km - stops[next - 1].km) / (stops[next].km - stops[next - 1].km))
        }
        let daylit: [(km: Float, colour: RGB)] = [(0, rgb(196, 214, 230)), (10, rgb(149, 187, 219)), (20, rgb(90, 140, 200)), (32, rgb(27, 59, 96)), (46, rgb(12, 20, 32)), (58, space)]
        let dusky: [(km: Float, colour: RGB)] = [(8, rgb(43, 21, 16)), (20, rgb(117, 70, 32)), (27, rgb(182, 124, 67)), (31, rgb(224, 171, 102)), (36, rgb(246, 224, 172)),
                     (45, rgb(246, 246, 237)), (53, rgb(158, 201, 244)), (61, rgb(40, 120, 187)), (67, rgb(5, 78, 136)), (76, rgb(0, 20, 46)), (90, space)]
        let nightly: [(km: Float, colour: RGB)] = [(0, rgb(10, 16, 34)), (30, rgb(6, 9, 18)), (58, rgb(8, 9, 12)), (70, rgb(52, 46, 24)), (84, rgb(96, 88, 50)), (91, rgb(46, 52, 30)),
                       (96, rgb(84, 128, 74)), (101, rgb(40, 62, 40)), (108, space)]
        air = [UInt32](repeating: 0, count: lights * bands)
        for step in 0..<lights {
            let t = Float(step) / Float(lights - 1), day = smoothstep(0.42, 0.78, t), dusk = smoothstep(0.1, 0.4, t) * (1 - day)
            for band in 0..<bands {
                let km = (Float(band) + 0.5) / Float(bands) * Self.airTop
                let dark = mix(space, ramp(km, nightly), moonlight)
                air[step * bands + band] = pack(ramp(km, daylit) * day + ramp(km, dusky) * dusk + dark * (1 - day - dusk))
            }
        }
        sparkle = pack(rgb(255, 252, 240))
        bolt = pack(rgb(214, 224, 255))
        // The wing's parts (none, blanket, fold, seam, rim, lattice, gap), each in the Sun, in the low Sun, and in shadow.
        func tones(_ day: [RGB], _ low: [RGB], _ dark: [RGB]) -> [(day: UInt32, low: UInt32, dark: UInt32)] {
            day.indices.map { (pack(day[$0]), pack(low[$0]), pack(dark[$0])) }
        }
        // (In shadow both faces are one dark shape, so nobody sees which is up change at midnight.)
        let dark = [RGB.zero, rgb(24, 19, 22), rgb(30, 24, 27), rgb(40, 35, 41), rgb(68, 62, 74), rgb(56, 53, 61), rgb(9, 8, 10)]
        gold = tones([.zero, rgb(201, 153, 47), rgb(170, 122, 34), rgb(124, 81, 13), rgb(255, 229, 100), rgb(207, 199, 187), rgb(58, 42, 24)],
                     [.zero, rgb(224, 140, 44), rgb(186, 106, 30), rgb(122, 67, 16), rgb(255, 208, 112), rgb(217, 184, 144), rgb(58, 36, 18)], dark)
        cells = tones([.zero, rgb(27, 31, 58), rgb(52, 56, 84), rgb(143, 147, 168), rgb(230, 230, 238), rgb(216, 212, 204), rgb(42, 42, 48)],
                      [.zero, rgb(42, 28, 38), rgb(72, 50, 54), rgb(168, 128, 106), rgb(255, 217, 160), rgb(217, 184, 144), rgb(42, 32, 24)], dark)
    }
}

/// Smooth noise over the Earth, from 0 to 1, with one bump every `scale` km.
private func noise(_ p: Sky.Vector, _ scale: Double, _ salt: UInt64) -> Float {
    let q = p * (Orbit.radius / scale), cell = SIMD3<Double>(q.x.rounded(.down), q.y.rounded(.down), q.z.rounded(.down))
    var f = q - cell
    f = f * f * (3 - 2 * f)
    let (x, y, z) = (Int(cell.x), Int(cell.y), Int(cell.z))
    func corner(_ dx: Int, _ dy: Int, _ dz: Int) -> Double { Double(hash((x + dx) &* 73_856_093 ^ (z + dz) &* 83_492_791, y + dy, salt) & 0xFFFF) / 65535 }
    func blendX(_ dy: Int, _ dz: Int) -> Double { corner(0, dy, dz) + (corner(1, dy, dz) - corner(0, dy, dz)) * f.x }
    let near = blendX(0, 0) + (blendX(1, 0) - blendX(0, 0)) * f.y, far = blendX(0, 1) + (blendX(1, 1) - blendX(0, 1)) * f.y
    return Float(near + (far - near) * f.z)
}

// The airliner's own small helpers, repeated: they are private there, and `hash`, `pack` and `rgb` have namesakes
// in other files that a shared one would be mistaken for (PixelCity.swift says how that went).
@inline(__always) private func hash(_ x: Int, _ z: Int, _ salt: UInt64) -> UInt64 {
    var v = UInt64(bitPattern: Int64(x)) &* 0x9E37_79B9_7F4A_7C15 ^ UInt64(bitPattern: Int64(z)) &* 0xC2B2_AE3D_27D4_EB4F ^ salt &* 0x1656_67B1_9E37_79F9
    v = (v ^ (v >> 31)) &* 0xBF58_476D_1CE4_E5B9
    v = (v ^ (v >> 29)) &* 0x94D0_49BB_1331_11EB
    return v ^ (v >> 32)
}

@inline(__always) private func scatter(_ n: Int, _ row: Int, _ tick: UInt32) -> UInt8 {
    var v = UInt32(truncatingIfNeeded: n) &* 0x9E37_79B1 ^ UInt32(truncatingIfNeeded: row) &* 0x85EB_CA6B ^ tick &* 0xC2B2_AE35
    v = (v ^ (v >> 15)) &* 0x2C1B_3C6D
    return UInt8(truncatingIfNeeded: (v ^ (v >> 12)) >> 8)
}

@inline(__always) private func blend(_ a: UInt32, _ b: UInt32, _ t: UInt32) -> UInt32 {
    let redBlue = ((a & 0xFF00FF) * (256 - t) + (b & 0xFF00FF) * t) >> 8 & 0xFF00FF
    return 0xFF00_0000 | redBlue | ((a & 0xFF00) * (256 - t) + (b & 0xFF00) * t) >> 8 & 0xFF00
}

private func rgb(_ r: Int, _ g: Int, _ b: Int) -> RGB { RGB(Float(r), Float(g), Float(b)) / 255 }

private func pack(_ c: RGB) -> UInt32 {
    let c = pointwiseMin(pointwiseMax(c, .zero), .one) * 255
    return 0xFF00_0000 | UInt32(c.z) << 16 | UInt32(c.y) << 8 | UInt32(c.x)
}
