import SpriteKit

@MainActor func saturnsRingsScene(size: CGSize) -> SKScene { SaturnsRings(size: size) }

/// Saturn's rings from just above them, in today's sunlight: one shader that meets each pixel's ray with the ring
/// plane and the planet (docs/saturns-rings.md, How it works). The camera holds one of six views for a while, drifting
/// slowly, then glides to another at random, or holds the one picked in Settings; from the unlit face, or the lit.
final class SaturnsRings: SKScene, BatteryPaced {
    /// A view, from the mock-ups' sheet5-unlit (docs/saturns-rings/variants.py): how far the camera is from Saturn's
    /// centre and from the ring plane (Mm), which way it looks (degrees round from looking in at Saturn toward the
    /// rings' orbit, and down), how wide (degrees across), and where the Sun is round the planet from the camera
    /// (degrees). The camera keeps station against the Sun, so the light and the planet's shadow stay put while it
    /// holds a view.
    struct View {
        let name: String
        let r, h, yaw, pitch, field, sun: Double
        /// How far the camera drifts out from Saturn and back (Mm; negative is in), so the bands slide by. In Daphnis's
        /// view, how much nearer the moon comes along the Keeler gap.
        let drift: Double
        /// The exposure from the lit face, which puts the brightest real thing in view at a 99.9th of 172 to 190 of 255
        /// (the mock's own for each view; sheet 1's for B to E). From the unlit face every view takes `unlit`.
        let lit: Double
        /// How far the fastest thing on screen moves while it holds, in device px a second at Speed 1×, as
        /// `saturnsRingsMotionFitsTheBatteryRates` measures it: the battery's ceiling follows from it and Speed.
        let pace: Double
        /// Daphnis's distance ahead along the gap as a hold begins (Mm), in the view that shows it.
        var moon: Double?
    }

    /// The six views, in the order the View menu lists and stores them. The drift is 20 km/s at its fastest in the
    /// views 4 Mm up at Speed 1×, the pace the mock-ups' films found calm, and in proportion to the height in the view
    /// just above the Encke gap, so the bands under the camera cross the screen at about the same pace. Looking in and
    /// from above are held to 3 and 4 Mm, a few percent of the planet's distance, as their pictures are of the planet:
    /// at the same pace they would have swung it out of frame.
    nonisolated static let views = [
        View(name: "Looking In", r: 150, h: 12, yaw: 0, pitch: 24, field: 74, sun: 60, drift: 3, lit: 0.983, pace: 3.0),
        View(name: "Along to the Horizon", r: 126, h: 4, yaw: 70, pitch: 9, field: 70, sun: 234, drift: -3.06, lit: 2.441, pace: 7.7),
        View(name: "Along the Planet's Edge", r: 126, h: 4, yaw: 38, pitch: 7, field: 70, sun: 320, drift: -3.06, lit: 1.337, pace: 7.5),
        View(name: "From Above", r: 112, h: 40, yaw: 10, pitch: 38, field: 66, sun: 70, drift: -4, lit: 0.989, pace: 1.7),
        View(name: "Over the Encke Gap", r: 134.4, h: 1.6, yaw: 86, pitch: 17, field: 60, sun: 250, drift: 1.22, lit: 2.326, pace: 8.7),
        View(name: "Daphnis Close", r: 136.56, h: 0.12, yaw: 90, pitch: 20, field: 60, sun: 250, drift: 1.3, lit: 2.023, pace: 45.1, moon: 1.5),
    ]
    /// The exposure from the unlit face, the same in every view (the mock-ups' sheet 5), and the most the planet's own
    /// takes there, which keeps its lit side buttercream against the dim rings.
    nonisolated static let unlit = 1.478, planetMost = 1.52

    /// Cycle, or one of the views held for good. Stored as 0 for Cycle and 1 to 6 for the views in `views`' order.
    nonisolated static let view = Knob(key: "saturn.view", label: "View", range: 0...Double(views.count), standard: 0, section: "View",
                                       format: .choice(["Cycle"] + views.map(\.name)))
    /// How long each view holds in Cycle, in minutes.
    nonisolated static let hold = Knob(key: "saturn.hold", label: "Hold each view", range: 2...30, standard: 8, section: "View",
                                       format: .minutes, shownWhen: view.key, shownAt: 0)
    /// Which face of the rings the camera is on: 0 the unlit (the B ring dark, the A and C rings glowing), 1 the lit.
    nonisolated static let face = Knob(key: "saturn.face", label: "Face", range: 0...1, standard: 0, section: "Look",
                                       format: .choice(["Unlit", "Lit"]))
    /// The exposure, times the view's own.
    nonisolated static let brightness = Knob(key: "saturn.brightness", label: "Brightness", range: 0.5...2, standard: 1, section: "Look")
    nonisolated static let stars = Knob(key: "saturn.stars", label: "Stars", range: 0...1, standard: 1, section: "Look", format: .toggle)
    /// How fast the camera drifts while it holds a view (and Daphnis comes near): the drift's own clock. A hold and a
    /// glide keep their lengths.
    nonisolated static let speed = Knob(key: "saturn.speed", label: "Speed", range: 0...10, standard: 1, section: "Motion", format: .times)
    nonisolated static let knobs = [view, hold, face, brightness, stars, speed]

    /// How long a glide to the next view takes, and how long the drift takes to go out and back at Speed 1×, in
    /// seconds; Daphnis comes near over half that and goes back over the other half.
    nonisolated static let glide = 120.0, swing = 480.0
    /// The most a glide moves the camera along the rings, in heights a second: 0.02, so the ground under it crosses at
    /// most about 2% of the way to it a second.
    nonisolated static let calm = 0.02
    /// The Sun's height over the ring plane, in degrees (negative: south).
    // ponytail: fixed at 8.4° south, right for 2026-11-18, which drifts from the real one by about 0.3° a month (it
    // climbs to 27° by the 2032 solstice); from the date in step (d) of the build order.
    nonisolated static let sunUp = -8.4
    /// Daphnis's orbit, Mm from Saturn's centre.
    nonisolated static let daphnis = 136.504

    /// The numbers a frame is drawn from: a view's with its drift, or partway from one to another in a glide.
    struct Camera {
        var r, h, yaw, pitch, field, sun: Double
        /// The exposure: the view's for the face it's on, before Brightness.
        var exposure = SaturnsRings.unlit
        /// Daphnis's distance ahead along the gap (Mm), and how much of it and its waves show (1 in its view, 0 elsewhere).
        var ahead = 0.0, moon = 0.0

        /// Where the camera is, its axes, and the way to the Sun, in Mm with Saturn at the origin, the ring plane at
        /// z = 0 and the camera on +x: on the face the Sun isn't on, or with `lit`, the face it is on, which is the
        /// same view mirrored.
        func axes(lit: Bool = false) -> (at: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>, ahead: SIMD3<Double>, sun: SIMD3<Double>) {
            let side: Double = (SaturnsRings.sunUp < 0) != lit ? 1 : -1, (yaw, pitch) = (yaw * .pi / 180, pitch * .pi / 180)
            var ahead = cos(yaw) * SIMD3<Double>(-1, 0, 0) + sin(yaw) * SIMD3<Double>(0, 1, 0)
            ahead = simd_normalize(cos(pitch) * ahead + sin(pitch) * SIMD3(0, 0, -side))
            let right = simd_normalize(simd_cross(ahead, SIMD3(0, 0, side)))
            let (up, round) = (SaturnsRings.sunUp * .pi / 180, sun * .pi / 180)
            return (SIMD3(r, 0, side * h), right, simd_cross(right, ahead), ahead, SIMD3(cos(up) * cos(round), cos(up) * sin(round), sin(up)))
        }
    }

    /// The camera holding `view`, `drift` seconds into its drift (at Speed 1×). It drifts out and back over `swing`,
    /// easing at both ends; in Daphnis's view it drifts along the gap toward the moon over one `swing` and back over
    /// the next.
    nonisolated static func held(_ view: View, for drift: Double, lit: Bool = false) -> Camera {
        var camera = Camera(r: view.r, h: view.h, yaw: view.yaw, pitch: view.pitch, field: view.field, sun: view.sun, exposure: lit ? view.lit : unlit)
        if let moon = view.moon {
            (camera.ahead, camera.moon) = (moon - view.drift * (1 - cos(.pi * drift / swing)) / 2, 1)
        } else {
            camera.r += view.drift * (1 - cos(2 * .pi * drift / swing)) / 2
        }
        return camera
    }

    /// Partway from `a` to `b`, `e` from 0 to 1 (eased in time). The height goes by its logarithm (it runs from 0.12 Mm
    /// to 40), and the distance out in step with the height, so the ground under the camera crosses the screen at a
    /// pace in proportion to the distance over the mean height. Where that would be more than `calm` at the glide's
    /// fastest, the camera climbs in the middle until it isn't: from Daphnis's view, 120 km up, to the Planet's Edge,
    /// 10.5 Mm along, it would otherwise skim the rings at 100 km/s. The yaw goes the short way round; the Sun goes
    /// round the side away from 180°, where the planet's shadow would lie on the camera and sweep across the rings
    /// under it in a second or two. The exposure goes by its logarithm too, in light, not in what the screen shows.
    nonisolated static func between(_ a: Camera, _ b: Camera, _ e: Double) -> Camera {
        let (low, rise) = (log(a.h), log(b.h / a.h))
        /// The mean height from the start to `x` of the way, with the middle raised by `lift` (a factor of e^lift).
        func mean(_ lift: Double, to x: Double = 1) -> Double {
            (0..<32).reduce(0.0) { sum, i in
                let at = (Double(i) + 0.5) / 32 * x
                return sum + exp(low + rise * at + lift * sin(.pi * at))
            } / 32 * x
        }
        // The mean height the ground's pace needs (smoothstep's fastest is 1.5 times its mean), by bisection.
        // ponytail: worked out again every frame, about 1,600 exponentials (microseconds); keep it for the glide if
        // the CPU a frame ever shows it.
        let need = 1.5 * abs(b.r - a.r) / (glide * calm)
        var (under, over) = (0.0, mean(0) < need ? 6.0 : 0.0)
        for _ in 0..<(over > 0 ? 24 : 0) { let mid = (under + over) / 2; if mean(mid) < need { under = mid } else { over = mid } }
        let h = exp(low + rise * e + over * sin(.pi * e)), along = mean(over, to: e) / mean(over)
        func mix(_ x: Double, _ y: Double) -> Double { x + (y - x) * e }
        func clear(_ sun: Double) -> Double { sun - 180 - 360 * ((sun - 180) / 360).rounded(.down) } // 0 to 360, 0 at 180°
        return Camera(r: a.r + (b.r - a.r) * along, h: h, yaw: a.yaw + remainder(b.yaw - a.yaw, 360) * e, pitch: mix(a.pitch, b.pitch),
                      field: mix(a.field, b.field), sun: 180 + mix(clear(a.sun), clear(b.sun)), exposure: a.exposure * pow(b.exposure / a.exposure, e),
                      ahead: a.moon > 0 && b.moon > 0 ? mix(a.ahead, b.ahead) : a.moon > 0 ? a.ahead : b.ahead, moon: mix(a.moon, b.moon))
    }

    /// A view to glide to at random: never the one it's at or the one before.
    nonisolated static func next(after view: Int, previous: Int?) -> Int {
        views.indices.filter { $0 != view && $0 != previous }.randomElement()!
    }

    /// The ceiling on battery while `view` holds at `speed`: the lowest of 10, 12, 15 and 20 fps at which its fastest
    /// thing moves 2 device px a frame or less (Sources/CLAUDE.md, Adding a scene), else none, for the battery's 30.
    nonisolated static func rate(_ view: View, speed: Double) -> Int? {
        [10, 12, 15, 20].first { view.pace * speed / Double($0) <= 2 }
    }

    /// Holding view `current`, or gliding to it, since `since` on the scene's clock, `time`; `previous` is the view before.
    private enum Phase { case hold, glide(from: Origin) }
    /// Where a glide sets out from: a view still drifting on, as a hold ends, so the camera doesn't stop dead before
    /// it moves off; or a camera standing where it was, when another view is picked partway through a glide.
    private enum Origin { case drifting(Int), still(Camera) }
    private var phase = Phase.hold, current: Int, previous: Int?, since: Double, time = 0.0, lastUpdate: TimeInterval?
    /// How far the drift has gone in the hold that's showing, or the one a glide sets out from: seconds at 1×.
    private var drift: Double
    /// The ceiling on battery: the view's at the Speed set while it holds, none while it glides, when the fastest
    /// thing on screen crosses 51 to 176 device px a second (`saturnsRingsMotionFitsTheBatteryRates`; docs/saturns-rings.md, Cost).
    private(set) var batteryRate: Int? { didSet { batteryRateChanged(from: oldValue) } }
    private let cam = SKUniform(name: "u_cam", vectorFloat3: .zero), rot = SKUniform(name: "u_rot", matrixFloat3x3: matrix_identity_float3x3)
    private let sunUniform = SKUniform(name: "u_sun", vectorFloat3: .zero), lens = SKUniform(name: "u_lens", vectorFloat2: .zero)
    private let moonUniform = SKUniform(name: "u_moon", vectorFloat2: .zero), starsUniform = SKUniform(name: "u_stars", float: 1)
    private let exposure = SKUniform(name: "u_exposure", float: 1), planetExposure = SKUniform(name: "u_planetExposure", float: 1)
    private let colours = (0..<5).map { SKUniform(name: "u_c\($0)", vectorFloat3: .zero) }
    /// The face whose colours are in `colours`.
    private var coloured: Bool?

    /// Starts holding `first` (the view picked in Settings, else one at random), `moment` seconds in (the
    /// `saturn.moment` default if nil, for pictures), or with `next`, gliding from it to `next`, `moment` seconds in
    /// (for tests).
    init(size: CGSize, from first: Int? = nil, to next: Int? = nil, moment: Double? = nil) {
        let picked = Int(Self.view.value) - 1, moment = moment ?? UserDefaults.standard.double(forKey: "saturn.moment")
        current = first ?? (picked >= 0 ? picked : Self.views.indices.randomElement()!)
        (since, drift) = (-moment, moment * Self.speed.value)
        super.init(size: size)
        batteryRate = Self.rate(Self.views[current], speed: Self.speed.value)

        // ponytail: the profile is read on every build (10 ms in release, the pyramid's bake 8.5 ms more for the
        // first copy) though the shader takes only its first radius, step and length; keep those beside the shared
        // pyramid if building gets slow.
        let rings = RingProfile.load()
        let table = sharedTexture("saturn-rings-pyramid") { rings.pyramid() }
        let sprite = SKSpriteNode(color: .black, size: size)
        sprite.anchorPoint = .zero
        sprite.shader = SKShader(source: shaderCommon + saturnsRingsSource(rings), uniforms: [
            SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)]), SKUniform(name: "u_table", texture: table),
            cam, rot, sunUniform, lens, moonUniform, starsUniform, exposure, planetExposure,
        ] + colours)
        addChild(sprite)

        if let next { glide(to: next, at: since, from: .drifting(current)) }
        advance()
        show()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func update(_ currentTime: TimeInterval) {
        let seconds = frameTime(currentTime, &lastUpdate)
        time += seconds
        drift += seconds * Self.speed.value
        advance()
        show()
    }

    /// The camera now, from the unlit face or with `lit` the lit.
    func camera(lit: Bool) -> Camera {
        let held = Self.held(Self.views[current], for: drift, lit: lit)
        guard case .glide(let origin) = phase else { return held }
        let from: Camera
        switch origin {
        case .drifting(let view): from = Self.held(Self.views[view], for: drift, lit: lit)
        case .still(let camera): from = camera
        }
        let u = min(max((time - since) / Self.glide, 0), 1)
        return Self.between(from, Self.held(Self.views[current], for: 0, lit: lit), u * u * (3 - 2 * u))
    }

    /// Moves the phase on: to a glide toward the view picked in Settings, or in Cycle toward one at random once a
    /// hold is over, and to a hold once a glide is over, each at the moment it's due, so the path is the same at any
    /// frame rate.
    private func advance() {
        let picked = Int(Self.view.value) - 1, speed = Self.speed.value
        while true {
            if case .glide = phase, time - since >= Self.glide {
                (phase, since) = (.hold, since + Self.glide)
                drift = (time - since) * speed
            } else if picked >= 0, picked != current {
                if case .hold = phase { glide(to: picked, at: time, from: .drifting(current)) } else { glide(to: picked, at: time, from: .still(camera(lit: Self.face.value > 0.5))) }
            } else if picked < 0, case .hold = phase, time - since >= Self.hold.value.rounded() * 60 {
                glide(to: Self.next(after: current, previous: previous), at: since + Self.hold.value.rounded() * 60, from: .drifting(current))
            } else {
                break
            }
        }
        if case .hold = phase { batteryRate = Self.rate(Self.views[current], speed: speed) } else { batteryRate = nil }
    }

    private func glide(to next: Int, at moment: Double, from origin: Origin) {
        phase = .glide(from: origin)
        (previous, current, since) = (current, next, moment)
    }

    /// Hands the camera, and the settings that change how it's drawn, to the shader.
    private func show() {
        let lit = Self.face.value > 0.5, camera = camera(lit: lit), axes = camera.axes(lit: lit)
        let tangent = Float(tan(camera.field / 2 * .pi / 180)), brightness = Self.brightness.value
        cam.vectorFloat3Value = SIMD3<Float>(axes.at)
        rot.matrixFloat3x3Value = matrix_float3x3(columns: (SIMD3<Float>(axes.right), SIMD3<Float>(axes.up), SIMD3<Float>(axes.ahead)))
        sunUniform.vectorFloat3Value = SIMD3<Float>(axes.sun)
        lens.vectorFloat2Value = [tangent, tangent * Float(size.height / size.width)]
        moonUniform.vectorFloat2Value = [Float(camera.ahead / Self.daphnis), Float(camera.moon)]
        exposure.floatValue = Float(camera.exposure * brightness)
        planetExposure.floatValue = Float((lit ? camera.exposure : min(camera.exposure, Self.planetMost)) * brightness)
        starsUniform.floatValue = Float(Self.stars.value)
        if coloured != lit {
            coloured = lit
            // Each face's colours, dark to light, from the ring pixels of one Cassini photograph (research-look.md):
            // the lit face's PIA06485, the unlit face's PIA09860 from 5° below.
            let ramp = lit ? [0x1f1d24, 0x8a827f, 0x968e8d, 0xcebdb0, 0xe3d3c8] : [0x140c0a, 0x503f31, 0x695442, 0x9a7d67, 0xf2cfa2]
            for (uniform, hex) in zip(colours, ramp) {
                uniform.vectorFloat3Value = SIMD3<Float>(Float(hex >> 16 & 255), Float(hex >> 8 & 255), Float(hex & 255)) / 255
            }
        }
    }
}

/// Saturn's main rings every 8 km, from `Resources/saturn-rings.tsv` (docs/saturns-rings/profile.py made it; its
/// header has the sources): each radius's normal optical depth τ, from a Cassini UVIS occultation, and its particles'
/// brightness (ϖ₀P/4), from Voyager 2's lit-face picture.
// ponytail: 8 km a sample, 8,751 texels, near enough for view C, where a device pixel covers about 6 km of radius at
// the bottom edge and more everywhere else. The close views draw finer near the bottom, E about 1.6 km a pixel and F
// about 0.1 km, so their near fields are the profile smoothed, as in the tiles Dave picked: a 4 km profile (16,384
// texels, Metal's widest) if they look soft.
struct RingProfile {
    /// The first radius and the step between samples, in Mm, the shader's unit.
    let start: Double, step: Double
    let tau: [Double], brightness: [Double]
    /// The pyramid holds exp(−τk) for k = 1, 2, 4 … 2048, each averaged over boxes 1, 2, 4 … 4096 texels wide.
    static let ks = 12, levels = 13

    static func load() -> RingProfile {
        let rows = ((try? String(contentsOf: resource("saturn-rings.tsv"), encoding: .utf8)) ?? "")
            .split(whereSeparator: \.isNewline).filter { !$0.hasPrefix("#") }
            .map { $0.split(separator: "\t").compactMap { Double($0) } }.filter { $0.count == 3 }
        guard rows.count > 1 else { return RingProfile(start: 72, step: 1, tau: [0, 0], brightness: [0, 0]) } // no rings
        return RingProfile(start: rows[0][0] / 1000, step: (rows[1][0] - rows[0][0]) / 1000, tau: rows.map { $0[1] }, brightness: rows.map { $0[2] })
    }

    /// The radial pyramid (research-method.md §4), a mip chain by radius: row (j, m) holds, for each texel, the mean
    /// of exp(−τ·2^j) over a box 2^m texels wide centred on it, as two bytes (red and green), and the mean brightness
    /// over the same box (blue, 255 for 0.5). The shader picks the row for each pixel's footprint and light path, so
    /// every pixel shows the exact average of the bands it covers, and none shimmer. Running sums read twice, which
    /// would need no pyramid, failed in SpriteKit for lack of precision.
    func pyramid() -> SKTexture {
        SKTexture(data: Data(pyramidBytes()), size: CGSize(width: tau.count, height: Self.ks * Self.levels))
    }

    /// The pyramid's texels, RGBA, row by row.
    func pyramidBytes() -> [UInt8] {
        let n = tau.count
        /// Running sums of `values`, from 0.
        func sums(_ values: [Double]) -> [Double] {
            var sums = [0.0]
            sums.reserveCapacity(values.count + 1)
            for value in values { sums.append(sums.last! + value) }
            return sums
        }
        /// The mean over `half` texels either side of texel `i`'s centre, from the running sums, `outside` past the ends.
        func mean(_ sums: [Double], _ i: Int, _ half: Double, outside: Double) -> Double {
            func at(_ x: Double) -> Double {
                if x <= 0 { return x * outside }
                if x >= Double(n) { return sums[n] + (x - Double(n)) * outside }
                let i0 = Int(x)
                return sums[i0] + (x - Double(i0)) * (sums[min(i0 + 1, n)] - sums[i0])
            }
            return (at(Double(i) + 0.5 + half) - at(Double(i) + 0.5 - half)) / (2 * half)
        }
        let brightnessSums = sums(brightness)
        let bright = (0..<Self.levels).map { m in
            (0..<n).map { UInt8(min(max(mean(brightnessSums, $0, Double(1 << m) / 2, outside: 0.2), 0), 0.5) / 0.5 * 255) }
        }
        var bytes = [UInt8](repeating: 255, count: n * Self.ks * Self.levels * 4)
        for j in 0..<Self.ks {
            let through = sums(tau.map { exp(-$0 * pow(2, Double(j))) })
            for m in 0..<Self.levels {
                let half = Double(1 << m) / 2
                for i in 0..<n {
                    let v = Int(min(max(mean(through, i, half, outside: 1), 0), 1) * 65535), at = ((j * Self.levels + m) * n + i) * 4
                    (bytes[at], bytes[at + 1], bytes[at + 2]) = (UInt8(v >> 8), UInt8(v & 255), bright[m][i])
                }
            }
        }
        return bytes
    }
}

/// The shader: the ring plane and the planet in one pass, the rings lit as a thin layer that scatters once
/// (research-method.md §3), each band filtered to the pixel's footprint by the pyramid, the planet's shadow on the
/// rings and theirs on it, ringshine on its night side, Daphnis and its waves, then exposure, a soft knee and dither.
/// Ported from docs/saturns-rings/mock.swift, less Pan's ripple and the spokes, with Daphnis's numbers written in.
private func saturnsRingsSource(_ rings: RingProfile) -> String {
    let rows = Double(RingProfile.ks * RingProfile.levels)
    /// Declares `v`, the mean of exp(−τk) over the footprint `w` texels either side of `u`, from the two rows of k
    /// round `k`, and `vAlb`, the particles' brightness there.
    func mean(_ v: String, _ u: String, _ w: String, _ k: String) -> String {
        "vec4 \(v)At = pyrAt(\(u), \(w), \(k)); vec4 \(v)0 = texture2D(u_table, \(v)At.xy); vec4 \(v)1 = texture2D(u_table, \(v)At.xz); float \(v) = mix(pyrOf(\(v)0), pyrOf(\(v)1), \(v)At.w); float \(v)Alb = \(v)0.b * 0.5;"
    }
    return """
    // Faint sparse stars, display values: luma 30 at most (the look report's cap), fixed to the sky so they turn
    // with the camera in a glide. q is the way to look with the Sun at azimuth 0, perPt the points to a radian. The
    // sky is a cube, each face in cells 0.0065 across (7 points at 70 degrees across, the mock-ups' grid).
    // ponytail: random stars; the real catalogue and Milky Way from Black Hole's in step (d) of the build order.
    float stars(vec3 q, float perPt) {
        vec3 a = abs(q);
        vec2 f = a.x >= max(a.y, a.z) ? q.yz / a.x : a.y >= a.z ? q.xz / a.y : q.xy / a.z;
        float face = a.x >= max(a.y, a.z) ? 1.0 + sign(q.x) : a.y >= a.z ? 3.0 + sign(q.y) : 5.0 + sign(q.z);
        vec2 g = f / 0.0065;
        vec4 r = hash42(floor(g) + vec2(face * 400.0, 0.0));
        if (r.x > 0.05) { return 0.0; }
        vec2 off = (r.yz - 0.5) * 0.6;
        float d = length(fract(g) - 0.5 - off) * 0.0065 * perPt;
        return smoothstep(0.9, 0.0, d) * (0.25 + 0.75 * pow(r.w, 4.0)) * 30.0 / 255.0;
    }
    // Where the pyramid keeps the mean of exp(-tau k) over a box 2w texels wide, in the two rows of k round k.
    vec4 pyrAt(float u, float w, float k) {
        float m = clamp(log2(2.0 * w), 0.0, 11.999), j = clamp(log2(max(k, 1.0)), 0.0, 10.999), j0 = floor(j);
        return vec4(u / \(Double(rings.tau.count)), (j0 * 13.0 + m + 0.5) / \(rows), ((j0 + 1.0) * 13.0 + m + 0.5) / \(rows), j - j0);
    }
    float pyrOf(vec4 t) { return t.r * (255.0 * 256.0 / 65535.0) + t.g * (255.0 / 65535.0); }
    vec3 rampAt(float t, vec3 c0, vec3 c1, vec3 c2, vec3 c3, vec3 c4) {
        float x = clamp(t, 0.0, 1.0) * 4.0;
        vec3 c = mix(c0, c1, clamp(x, 0.0, 1.0));
        c = mix(c, c2, clamp(x - 1.0, 0.0, 1.0));
        c = mix(c, c3, clamp(x - 2.0, 0.0, 1.0));
        return mix(c, c4, clamp(x - 3.0, 0.0, 1.0));
    }
    float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

    void main() {
        vec2 ndc = (v_tex_coord - 0.5) * 2.0;
        vec3 d = normalize(u_rot * vec3(ndc.x * u_lens.x, ndc.y * u_lens.y, 1.0));
        vec3 c = u_cam, s = u_sun;
        float req = 60.268, k = 60.268 / 54.364;

        // the ring plane, and Daphnis's ripple: a shift of radius (and a squeeze of the streamlines) downstream of it.
        // u_moon is how far ahead of the camera it is (radians round Saturn) and how much of it shows.
        float tr = -c.z / d.z;
        vec3 p = c + tr * d;
        float r = length(p.xy);
        float crowd = 1.0, tilt = 0.0, gap = 1.0;
        float dr = (r - 136.504) * 1000.0;                                   // km from Daphnis's orbit
        if (u_moon.y > 0.0 && abs(dr) > 17.5 && abs(dr) < 1050.0) {         // the Keeler gap's edges are 17.5 km from it
            float phi = atan(p.y, p.x) - u_moon.x;
            float down = mod(-sign(dr) * phi, 6.2831853);                    // radians downstream of the moon
            float lambda = 9.424778 * abs(dr);                               // 3 pi |dr| (Showalter et al. 1986)
            float theta = 6.2831853 * down * 136504.0 / lambda;              // the wake's phase
            // the edges pushed 2.5 km (worked out from Daphnis's mass, unchecked), standing 1 km tall (PIA11654)
            float a = 2.5 * u_moon.y * pow(17.5 / abs(dr), 2.0) * exp(-theta / 25.0);
            r -= a * sin(theta) / 1000.0;
            crowd = clamp(1.0 + a * cos(theta) * theta / abs(dr), 0.5, 2.0);
            // the edge waves stand up out of the plane: their slope turns each crest toward or away from the Sun
            float rise = u_moon.y * exp(-(abs(dr) - 17.5) / 8.0) * exp(-theta / 25.0);
            vec2 along = normalize(vec2(-p.y, p.x)) * -sign(dr);
            tilt = rise * 6.2831853 / lambda * cos(theta) * dot(normalize(s.xy), along);
        }
        float u = (r - \(rings.start)) / \(rings.step);
        float w = max(0.5 * length(vec2(dfdx(u), dfdy(u))), 0.5);
        // Daphnis's gap, drawn sharp from its own edges rather than the 8 km profile: real gap edges are sharper than
        // any camera has resolved (research-look.md). Antialiased over the pixel's footprint in km.
        if (u_moon.y > 0.0) {
            float off = abs(r - 136.504) * 1000.0, fw = max(0.5 * length(vec2(dfdx(r), dfdy(r))) * 1000.0, 0.01);
            gap = mix(1.0, smoothstep(17.5 - fw, 17.5 + fw, off), u_moon.y);
        }

        // the planet: an oblate spheroid, a sphere once z is stretched by k
        vec3 cs = vec3(c.xy, c.z * k), ds = vec3(d.xy, d.z * k);
        float A = dot(ds, ds), B = dot(cs, ds), C = dot(cs, cs) - req * req;
        float disc = B * B - A * C;
        float tp = disc > 0.0 ? (-B - sqrt(disc)) / A : 1e9;

        // Daphnis itself, a small grey ball 3.8 km across in its gap
        vec3 mc = vec3(cos(u_moon.x), sin(u_moon.x), 0.0) * 136.504;
        vec3 oc = c - mc;
        float mb = dot(oc, d), mdisc = mb * mb - dot(oc, oc) + 0.0038 * 0.0038;
        float tm = (u_moon.y > 0.0 && mdisc > 0.0) ? -mb - sqrt(mdisc) : 1e9;

        vec3 lin = vec3(0.0);   // light, before exposure: planet and rings in I/F
        float sky = 1.0;        // how much of the sky shows
        if (tp < 1e8) {
            vec3 h = c + tp * d;
            vec3 n = normalize(vec3(h.xy, h.z * k * k));
            float lat = asin(clamp(n.z, -1.0, 1.0));
            float mu0p = max(dot(n, s), 0.0), mup = max(-dot(n, d), 0.02);
            // buttercream belts and zones, the south a paler gold (PIA06193, PIA11141, PIA11478)
            // ponytail: drawn by latitude, not mapped; a Cassini map of the globe if a view close to it shows them as too regular
            float band = 0.5 + 0.5 * sin(lat * 23.0 + 0.7 * sin(lat * 9.0)) * (0.6 + 0.4 * sin(lat * 5.0 + 1.0));
            vec3 col = mix(vec3(0.66, 0.59, 0.44), vec3(0.82, 0.73, 0.59), band);
            col = mix(col, vec3(0.88, 0.79, 0.51), 0.25 * smoothstep(0.1, -0.6, lat));
            col = pow(col, vec3(2.2)); // the photographs' display colours, in linear light
            // the rings' shadow: the light that reaches here came through the ring plane at radius rq
            float ts = -h.z / s.z;
            float rq = length((h + ts * s).xy);
            float uq = (rq - \(rings.start)) / \(rings.step);
            float wq = max(0.5 * length(vec2(dfdx(uq), dfdy(uq))), 0.5);
            \(mean("eq", "uq", "wq", "1.0 / abs(s.z)"))
            float through = ts > 0.0 ? eq : 1.0;
            float lit = 0.42 * pow(mu0p, 0.9) * pow(mup, -0.1) * through;
            // ringshine: the rings' lit face lights the hemisphere on its side, their unlit face the other, dimmer
            float side = n.z * sign(s.z);
            float shine = 0.42 * 0.012 * (smoothstep(-0.2, 0.7, side) + 0.35 * smoothstep(-0.2, 0.7, -side));
            lin = (col / luma(col) * lit + vec3(2.25, 0.714, 0.148) * shine) * u_planetExposure; // #372110 in linear light, luma 1
            sky = 0.0;
        }
        if (tr > 0.0 && tr < tp && r > 72.2 && r < 141.9) {
            float mu = max(abs(d.z), 1e-4), mu0 = max(abs(s.z) + tilt, 2e-3);
            float kv = 1.0 / mu, ks = 1.0 / mu0;
            \(mean("eView", "u", "w", "kv * crowd"))
            float light = 0.0, t = 0.0;
            if (c.z * s.z > 0.0) {
                \(mean("eBoth", "u", "w", "(kv + ks) * crowd"))
                light = eViewAlb * (1.0 - eBoth) * mu0 / (mu + mu0);
                t = light / (0.28 * mu0 / (mu + mu0));
            } else {
                float k2 = abs(kv - ks) < 0.1 * ks ? ks * 1.1 : kv;
                \(mean("eSun", "u", "w", "ks * crowd"))
                \(mean("eK2", "u", "w", "k2 * crowd"))
                light = eViewAlb * (eSun - eK2) / (mu * (k2 - ks));
                // the most an unlit slab can pass at this angle, at tau = ln(k2/ks) / (k2 - ks)
                float best = log(k2 / ks) / (k2 - ks);
                t = light / (0.28 * (exp(-best * ks) - exp(-best * k2)) / (mu * (k2 - ks)));
            }
            // the planet's shadow: does the way to the Sun meet the spheroid? Soft over the Sun's width.
            vec3 ps = vec3(p.xy, 0.0), ss = normalize(vec3(s.xy, s.z * k));
            float b = dot(ps, ss);
            float miss = sqrt(max(dot(ps, ps) - b * b, 0.0));
            float sunlit = b < 0.0 ? smoothstep(req - 0.02 + b * 0.0005, req + 0.02 - b * 0.0005, miss) : 1.0;
            // the rings take the palette's colour at their brightness against a saturated B ring's
            vec3 hueLin = pow(rampAt(t * 0.95, u_c0, u_c1, u_c2, u_c3, u_c4), vec3(2.2));
            eView = mix(1.0, eView, gap);
            lin = lin * eView + hueLin / max(luma(hueLin), 1e-4) * light * sunlit * gap * u_exposure;
            sky *= eView;
        }
        if (tm < min(tp, tr > 0.0 ? tr : 1e9)) {
            vec3 n = normalize(c + tm * d - mc);
            // a dark icy moonlet, about as bright as the A ring
            // ponytail: it and its waves fade over a glide into or out of its view, while the camera is a few hundred
            // km to Mm off and they are a few pixels; place it on its real orbit in every view if the fade ever shows.
            lin = mix(lin, vec3(0.12 * max(dot(n, s), 0.0) + 0.002) * u_planetExposure, u_moon.y);
            sky *= 1.0 - u_moon.y;
        }

        // exposure and a knee that stays nearly straight to luma 185 (Cassini's contrast kept) and never passes 214
        lin = max(lin, 0.0);
        vec3 col = pow(lin / sqrt(sqrt(1.0 + pow(lin / 0.68, vec3(4.0)))), vec3(0.4545));
        // the sky: near-black (luma 4-8) and faint stars, both behind whatever the rings let through
        vec2 toSun = normalize(s.xy);
        vec3 q = vec3(toSun.x * d.x + toSun.y * d.y, toSun.x * d.y - toSun.y * d.x, d.z);
        col += (6.0 / 255.0 + stars(q, u_size.x / (2.0 * u_lens.x)) * u_stars) * sky;
        col += 3.0 / 255.0 * (1.0 - sky);
        col += (hash21(v_tex_coord * u_size * 2.0) - 0.5) / 255.0;
        gl_FragColor = vec4(col, 1.0);
    }
    """
}
