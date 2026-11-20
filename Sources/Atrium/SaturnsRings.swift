import ImageIO
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

    /// Cycle, Fly Through, or one of the views held for good. Stored as 0 for Cycle, 1 to 6 for the views in `views`'
    /// order and 7 for Fly Through (added after the views, so their numbers kept their meanings), listed with Fly
    /// Through second.
    nonisolated static let view = Knob(key: "saturn.view", label: "View", range: 0...Double(views.count + 1), standard: 0, section: "View",
                                       format: .choice(["Cycle"] + views.map(\.name) + ["Fly Through"]), order: [0, views.count + 1] + Array(1...views.count))
    /// How long each view holds in Cycle, in minutes.
    nonisolated static let hold = Knob(key: "saturn.hold", label: "Hold each view", range: 1...30, standard: 8, section: "View",
                                       format: .minutes, shownWhen: view.key, shownAt: 0)
    /// Which face of the rings the camera is on: 0 the unlit (the B ring dark, the A and C rings glowing), 1 the lit,
    /// the standard since Dave found it the nicer (2026-11-19), 2 each in turn and 3 the lit in Light Mode and the
    /// unlit in Dark Mode (2026-11-20). The camera changes faces by flying through the ring plane, out past the rings
    /// (`crossing`). Listed Lit, Unlit, then the two that change.
    nonisolated static let face = Knob(key: "saturn.face", label: "Face", range: 0...3, standard: 1, section: "Look",
                                       format: .choice(["Unlit", "Lit", "Alternate", "Lit in Light Mode, unlit in Dark Mode"]), order: [1, 0, 2, 3])
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
    /// Saturn's north pole on the sky (J2000 equatorial), the IAU's: right ascension 40.589° − 0.036°T, declination
    /// 83.537° − 0.004°T, T in Julian centuries from J2000 (Archinal et al. 2018, the IAU WGCCRE report of 2015). The
    /// rings lie in Saturn's equator.
    nonisolated static func pole(_ jd: Double) -> Sky.Vector {
        let t = (jd - 2451545) / 36525
        return Sky.direction(40.589 - 0.036 * t, 83.537 - 0.004 * t)
    }

    /// The light on `date`: the Sun's height over the ring plane as seen from Saturn, in degrees (negative is south;
    /// kept at least 0.05° off the plane, more than the Sun's own radius there, 0.03°, as the shader divides by it),
    /// and the turn from a direction with the Sun at azimuth 0 round the pole, as the shader has it, to the frame
    /// Black Hole's star and glow files are in (`NightSky.toStars`), so each view's sky is the real one round its Sun.
    /// It moves about 0.3° a month, so it's read as the scene is built.
    nonisolated static func light(on date: Date) -> (up: Double, sky: simd_double3x3) {
        let jd = Sky.julianDate(date), pole = pole(jd), sun = Sky.sun(from: .saturn, jd)
        let height = asin(simd_dot(sun, pole)) * 180 / .pi
        let across = simd_normalize(sun - simd_dot(sun, pole) * pole)
        return (height < 0 ? min(height, -0.05) : max(height, 0.05),
                NightSky.toStars * simd_double3x3(columns: (across, simd_cross(pole, across), pole)))
    }

    /// How much more exposure the rings take when the Sun is lower over them than the 8.4° the exposures were set
    /// for, by how much less light reaches them (the sine of its height): to the 0.5 from the lit face, up to 10 times,
    /// and to the 0.75 from the unlit, up to 30, as light through the rings fades faster as the Sun nears their plane.
    /// Near the 2039 equinox the rings go dark, edge on to the Sun, and the views of rings alone would be all but
    /// empty: at 0.1° their 99th percentile fell to 17–21 of 255. Never less than 1: a higher Sun brightens them, as it
    /// really does, and keeps within the caps (docs/saturns-rings.md, The build so far, (d)). The planet's exposure is
    /// its own.
    // ponytail: a law fitted by eye to the dates measured (2038's 1.6° and the equinox's 0.1°), keeping the views of
    // rings alone within about a fifth of today's 99th percentile, not the rings' real photometry; work it out from
    // the slab's light if a date between looks too bright or too dark.
    nonisolated static func lift(_ sunUp: Double, lit: Bool) -> Double {
        min(max(pow(sin(8.4 * .pi / 180) / sin(abs(sunUp) * .pi / 180), lit ? 0.5 : 0.75), 1), lit ? 10 : 30)
    }

    /// The day the light is worked out for: `saturn.date` (YYYY-MM-DD, for pictures, not in Settings), else now.
    nonisolated static var date: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return UserDefaults.standard.string(forKey: "saturn.date").flatMap(formatter.date(from:)) ?? Date()
    }
    /// Daphnis's orbit, Mm from Saturn's centre.
    nonisolated static let daphnis = 136.504

    /// The numbers a frame is drawn from: a view's with its drift, or partway from one to another in a glide.
    struct Camera {
        var r, h, yaw, pitch, field, sun: Double
        /// The exposures, the rings' and the planet's: the view's for the face it's on, before Brightness.
        var exposure = SaturnsRings.unlit, planet = min(SaturnsRings.unlit, SaturnsRings.planetMost)
        /// Daphnis's distance ahead along the gap (Mm), and how much of it and its waves show (1 in its view, 0 elsewhere).
        var ahead = 0.0, moon = 0.0
        /// The face it's on, and how far it's turned about the way it looks, in degrees (only while it changes faces).
        var lit = false, roll = 0.0

        /// Where the camera is, its axes, and the way to the Sun, in Mm with Saturn at the origin, the ring plane at
        /// z = 0 and the camera on +x: on the face the Sun isn't on, or lit, the face it is on, which is the same view
        /// mirrored, so the plane is below on the screen from either face. `sunUp` is the Sun's height over the ring
        /// plane in degrees (as on 2026-11-18 unless given): the faces change sides when it crosses the plane. Seen
        /// level with the plane, the two faces' cameras look the same way, but turned half round from each other about
        /// it: a camera changing faces turns a quarter on the way to the plane and a quarter after, so the picture
        /// carries on through the change unbroken.
        func axes(sunUp: Double = -8.4) -> (at: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>, ahead: SIMD3<Double>, sun: SIMD3<Double>) {
            let side: Double = (sunUp < 0) != lit ? 1 : -1, (yaw, pitch) = (yaw * .pi / 180, pitch * .pi / 180)
            var ahead = cos(yaw) * SIMD3<Double>(-1, 0, 0) + sin(yaw) * SIMD3<Double>(0, 1, 0)
            ahead = simd_normalize(cos(pitch) * ahead + sin(pitch) * SIMD3(0, 0, -side))
            let right = simd_normalize(simd_cross(ahead, SIMD3(0, 0, side))), up = simd_cross(right, ahead)
            let (turn, height, round) = (roll * .pi / 180, sunUp * .pi / 180, sun * .pi / 180)
            return (SIMD3(r, 0, side * h), cos(turn) * right + sin(turn) * up, cos(turn) * up - sin(turn) * right, ahead,
                    SIMD3(cos(height) * cos(round), cos(height) * sin(round), sin(height)))
        }
    }

    /// The camera holding `view`, `drift` seconds into its drift (at Speed 1×). It drifts out and back over `swing`,
    /// easing at both ends; in Daphnis's view it drifts along the gap toward the moon over one `swing` and back over
    /// the next.
    nonisolated static func held(_ view: View, for drift: Double, lit: Bool = false) -> Camera {
        let exposure = lit ? view.lit : unlit
        var camera = Camera(r: view.r, h: view.h, yaw: view.yaw, pitch: view.pitch, field: view.field, sun: view.sun, exposure: exposure,
                            planet: lit ? exposure : min(exposure, planetMost), lit: lit)
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
        let (low, rise) = (log(a.h), log(b.h / a.h)), over = climb(a, b) { sin(.pi * $0) }
        /// The mean height from the start to `x` of the way.
        func mean(to x: Double) -> Double {
            (0..<32).reduce(0.0) { sum, i in
                let at = (Double(i) + 0.5) / 32 * x
                return sum + exp(low + rise * at + over * sin(.pi * at))
            } / 32 * x
        }
        let h = exp(low + rise * e + over * sin(.pi * e)), along = mean(to: e) / mean(to: 1)
        func mix(_ x: Double, _ y: Double) -> Double { x + (y - x) * e }
        return Camera(r: a.r + (b.r - a.r) * along, h: h, yaw: a.yaw + remainder(b.yaw - a.yaw, 360) * e, pitch: mix(a.pitch, b.pitch),
                      field: mix(a.field, b.field), sun: 180 + mix(clear(a.sun), clear(b.sun)), exposure: a.exposure * pow(b.exposure / a.exposure, e),
                      planet: a.planet * pow(b.planet / a.planet, e),
                      ahead: a.moon > 0 && b.moon > 0 ? mix(a.ahead, b.ahead) : a.moon > 0 ? a.ahead : b.ahead, moon: mix(a.moon, b.moon),
                      lit: a.lit, roll: mix(a.roll, b.roll))
    }

    /// How far a glide from `a` to `b` climbs, in the height's logarithm, at the top of a bump shaped `bump` (0 to 1
    /// over 0 to 1 of the way) on the straight line between their logarithms: enough that its mean height is what the
    /// ground's pace needs, the ground to cross at smoothstep's fastest (1.5 times its mean) over a glide's 120 s
    /// being no more than `calm` of it; none if it's high enough already. By halving.
    // ponytail: worked out again every frame, about 1,600 exponentials (microseconds); keep it for the glide if the
    // CPU a frame ever shows it.
    nonisolated static func climb(_ a: Camera, _ b: Camera, bump: (Double) -> Double) -> Double {
        let (low, rise) = (log(a.h), log(b.h / a.h)), need = 1.5 * abs(b.r - a.r) / (glide * calm)
        func mean(_ lift: Double) -> Double {
            (0..<32).reduce(0.0) { sum, i in let at = (Double(i) + 0.5) / 32; return sum + exp(low + rise * at + lift * bump(at)) } / 32
        }
        guard mean(0) < need else { return 0 }
        var (under, over) = (0.0, 6.0)
        for _ in 0..<24 { let mid = (under + over) / 2; if mean(mid) < need { under = mid } else { over = mid } }
        return over
    }

    /// The Sun's place round the planet in the space a glide moves it in: 0 to 360 with 0 at 180°, where its shadow
    /// would lie on the camera, so moving straight across it never goes there.
    nonisolated static func clear(_ sun: Double) -> Double { sun - 180 - 360 * ((sun - 180) / 360).rounded(.down) }

    /// Where the camera changes faces: level with the ring plane, 150 Mm out, Looking In's distance, past the A ring's
    /// edge (136.8 Mm) and the F ring (140.2), so the nearest ring is 8 Mm away and the rings are a hairline across
    /// the planet, as at an equinox; 200 m to one side of the plane, never on it (the shader divides by the height),
    /// where the shader has faded the hairline to a hundredth, so stepping through changes the picture by a level
    /// or two. Turned a quarter, so the hairline stands up the screen: the way it came (`leaving` false), or the way
    /// it goes on from the other face. Its exposures are halfway between Looking In's from the two faces, in light,
    /// so the two faces' pictures there are the same but for the hairline.
    nonisolated static func crossing(lit: Bool, leaving: Bool = false) -> Camera {
        let view = views[0], (litRings, unlitRings) = (view.lit, unlit), (litPlanet, unlitPlanet) = (view.lit, min(unlit, planetMost))
        return Camera(r: 150, h: 0.0002, yaw: view.yaw, pitch: 0, field: view.field, sun: view.sun, exposure: (litRings * unlitRings).squareRoot(),
                      planet: (litPlanet * unlitPlanet).squareRoot(), lit: lit, roll: leaving ? -90 : 90)
    }
    /// How often a held view changes faces under Alternate, in seconds.
    nonisolated static let crossEvery = 1800.0

    /// A view to glide to at random: never the one it's at or the one before.
    nonisolated static func next(after view: Int, previous: Int?) -> Int {
        views.indices.filter { $0 != view && $0 != previous }.randomElement()!
    }

    // MARK: Fly Through

    /// The order Fly Through takes the views in, round and round: of the orders that keep the two low views, over the
    /// Encke gap and Daphnis Close, side by side, the one whose loop is shortest at the even pace (`flightTime`
    /// measures them; docs/saturns-rings.md, The build so far, (e)).
    nonisolated static let flightOrder = [0, 1, 4, 5, 2, 3]
    /// How fast the fastest thing on screen moves along the loop at Speed 1×, in device px a second.
    nonisolated static let flightPace = 30.0

    /// The numbers the loop runs through smoothly, in the spaces it moves them in: r, the height's logarithm, yaw,
    /// pitch, field, the Sun in the space that avoids 180° (`clear`), the exposures' logarithms, and the turn.
    private nonisolated static func channels(_ camera: Camera) -> [Double] {
        [camera.r, log(camera.h), camera.yaw, camera.pitch, camera.field, clear(camera.sun), log(camera.exposure), log(camera.planet), camera.roll]
    }

    /// A loop's knots: the views in `order` from one face; or `alternating`, two laps, lit then unlit, each ending,
    /// after From Above, out past the rings at Looking In's distance, 2 Mm up (so the camera is out beyond them before
    /// it comes down: without it, it passed 100 km over the F ring's edge of the rings on the way), then at the
    /// crossing point, where it changes faces, before Looking In. A knot's turn counts on round (a quarter at a
    /// crossing, a half on the next lap, three quarters at the next crossing), so the turn runs on smoothly; the
    /// camera's own is that less the half turns of the crossings behind it (`path`).
    nonisolated static func route(order: [Int] = flightOrder, lit: Bool = false, alternating: Bool = false) -> [Camera] {
        guard alternating else { return order.map { held(views[$0], for: 0, lit: lit) } }
        return [true, false].enumerated().flatMap { lap, lit in
            var out = held(views[0], for: 0, lit: lit), across = crossing(lit: !lit)
            (out.h, out.pitch, out.roll, across.roll) = (2, 0, Double(lap) * 180, Double(lap) * 180 + 90)
            return order.map { view -> Camera in var camera = held(views[view], for: 0, lit: lit); camera.roll = Double(lap) * 180; return camera } + [out, across]
        }
    }

    /// The camera `t` of the way round a loop of `knots`, counted in knots (each whole number at one, so the picture
    /// at a view is that view's): a periodic cubic through the knots' numbers whose slope at each knot is the mean of
    /// the slopes either side (Catmull-Rom's), but for the distance out, the height and the turn level where the knot
    /// is a peak or a trough of that number and held to three times the gentler slope elsewhere (Fritsch and Carlson's
    /// limit), so they never overshoot the knots either side: Catmull-Rom's own took the camera from the Planet's Edge
    /// on past Daphnis Close and out beyond the A ring, half the screen empty, before it came back in to the Encke gap. Every number's rate goes on
    /// unbroken through each knot. The climb `between` makes in a glide between two knots is folded in as a bump of
    /// the height's logarithm that starts and ends level (sin²). The face is the knot's behind it (a crossing knot is
    /// on the far face), so it changes as the camera passes the crossing point, a kilometre off the plane. Daphnis
    /// fades in over the stretch to its view and out over the one after (smoothstep, level at each end), coming from
    /// 2 Mm ahead to 0.6 at its view, as in its tile, and on past the camera.
    nonisolated static func path(_ t: Double, knots: [Camera]) -> Camera {
        let n = knots.count, at = Int(t.rounded(.down)), u = t - Double(at)
        /// A knot, `i` on from the one behind, its turn counted on round past the end of the loop.
        func knot(_ i: Int) -> (camera: Camera, numbers: [Double]) {
            let k = at + i, laps = Double(Int((Double(k) / Double(n)).rounded(.down))), camera = knots[(k % n + n) % n]
            var numbers = channels(camera)
            numbers[8] += laps * 360 * (knots.contains { $0.roll != 0 } ? 1 : 0)
            return (camera, numbers)
        }
        let (k0, k1, k2, k3) = (knot(-1), knot(0), knot(1), knot(2)), (p0, p1, p2, p3) = (k0.numbers, k1.numbers, k2.numbers, k3.numbers)
        /// The slope at a knot, from the steps to it and from it: limited for the distance out, the height and the turn
        /// (`limited`), where overshooting would cross a ring's edge, the plane or level, and Catmull-Rom's own for the
        /// rest, so that where every limited number is at a peak or level at once (Looking In after a crossing) the
        /// others still move and the camera never stops.
        func slope(_ before: Double, _ after: Double, limited: Bool) -> Double {
            let mean = (before + after) / 2
            guard limited else { return mean }
            guard before * after > 0 else { return 0 }
            return mean.sign == .minus ? max(mean, 3 * max(before, after)) : min(mean, 3 * min(before, after))
        }
        let (h00, h10, h01, h11) = (2 * u * u * u - 3 * u * u + 1, u * u * u - 2 * u * u + u, 3 * u * u - 2 * u * u * u, u * u * u - u * u)
        var x = p1.indices.map { k in
            let limited = [0, 1, 8].contains(k)
            return h00 * p1[k] + h10 * slope(p1[k] - p0[k], p2[k] - p1[k], limited: limited) + h01 * p2[k]
                + h11 * slope(p2[k] - p1[k], p3[k] - p2[k], limited: limited)
        }
        x[1] += climb(k1.camera, k2.camera) { pow(sin(.pi * $0), 2) } * pow(sin(.pi * u), 2)
        // the turn the face behind takes as its own: a half for each crossing already passed
        let behind = 180 * ((p1[8] + 90) / 180).rounded(.down)
        var camera = Camera(r: x[0], h: exp(x[1]), yaw: x[2], pitch: x[3], field: x[4], sun: x[5] + 180, exposure: exp(x[6]), planet: exp(x[7]),
                            lit: k1.camera.lit, roll: x[8] - behind)
        let moons = knots.indices.filter { knots[$0].moon > 0 }
        if let off = moons.map({ (t - Double($0)) - Double(n) * ((t - Double($0)) / Double(n)).rounded() }).min(by: { abs($0) < abs($1) }) {
            let near = max(1 - abs(off), 0)
            (camera.moon, camera.ahead) = (near * near * (3 - 2 * near), 0.6 - 1.4 * off)
        }
        return camera
    }

    /// The camera `t` of the way round Fly Through's loop in `order`, from one face (tests and the order search).
    nonisolated static func path(_ t: Double, order: [Int] = flightOrder, lit: Bool = false) -> Camera { path(t, knots: route(order: order, lit: lit)) }

    /// The seconds Fly Through takes at Speed 1× to reach each 1/120 of the way between knots round a loop, from its
    /// start: each step's time is how far the fastest thing on screen moves over it (`motion`), over `flightPace`, so
    /// the pace is even on screen whatever the camera does, averaged with the six steps either side, so where the
    /// fastest thing changes from one to another (the shadow's edge coming into the frame) the camera's own speed
    /// changes over a few seconds, not in a frame: unaveraged, it changed five times over in a frame at From Above.
    /// The last is the loop's length.
    nonisolated static func flightTime(knots: [Camera]) -> [Double] {
        let steps = 120 * knots.count
        let times = (0..<steps).map { i in
            motion(path(Double(i) / 120, knots: knots), path(Double(i + 1) / 120, knots: knots), across: 24, up: 16) / flightPace
        }
        var seconds = [0.0]
        for i in 0..<steps { seconds.append(seconds.last! + (-6...6).reduce(0.0) { $0 + times[((i + $1) % steps + steps) % steps] } / 13) }
        return seconds
    }
    nonisolated static func flightTime(order: [Int] = flightOrder) -> [Double] { flightTime(knots: route(order: order)) }
    /// `flightTime` for the loop flown, worked out the first time it's flown (18 ms in release) and kept: 721 numbers;
    /// and for the two-lap loop Alternate flies, which changes faces once a lap (1,681 numbers).
    nonisolated static let flight = flightTime(), alternateFlight = flightTime(knots: route(alternating: true))
    nonisolated static let alternateKnots = route(alternating: true)

    /// The camera `seconds` round the loop at Speed 1×, from its start, round and round: the one-face loop from `lit`,
    /// or `alternating`, the two-lap loop that changes faces.
    // ponytail: the time is linear within each of the loop's steps, so its speed changes by a few percent from one to
    // the next, every 2 or 3 seconds, which no strip has shown; a smooth curve through the table if one is seen.
    nonisolated static func flying(_ seconds: Double, lit: Bool = false, alternating: Bool = false) -> Camera {
        let table = alternating ? alternateFlight : flight, length = table.last!, at = seconds - length * (seconds / length).rounded(.down)
        var (low, high) = (0, table.count - 1)
        while high - low > 1 { let mid = (low + high) / 2; if table[mid] <= at { low = mid } else { high = mid } }
        let step = table[high] - table[low], t = (Double(low) + (step > 0 ? (at - table[low]) / step : 0)) / 120
        return alternating ? path(t, knots: alternateKnots) : path(t, knots: route(lit: lit))
    }

    /// Where on a loop, in seconds at 1×, it passes `view`: on the lap from `lit`, for the two-lap loop.
    nonisolated static func flightSeconds(at view: Int, lit: Bool = true, alternating: Bool = false) -> Double {
        let at = flightOrder.firstIndex(of: view) ?? 0
        return alternating ? alternateFlight[120 * (at + (lit ? 0 : flightOrder.count + 2))] : flight[120 * at]
    }

    /// The view a loop passes next after `seconds` round it, on the face it's on there: past the crossing point, on the
    /// two-lap loop, the one before it, From Above, so the camera needn't change faces to get there.
    nonisolated static func nextOnLoop(_ seconds: Double, alternating: Bool = false) -> Int {
        let table = alternating ? alternateFlight : flight, length = table.last!, at = seconds - length * (seconds / length).rounded(.down)
        let knots = table.count / 120, next = (((table.firstIndex { $0 > at } ?? table.count - 1) + 119) / 120) % knots
        let lap = flightOrder.count + (alternating ? 2 : 0), index = next % lap
        return flightOrder[min(index, flightOrder.count - 1)]
    }

    /// How far the fastest thing on screen moves along the loop at its fastest, in device px a second at Speed 1×, as
    /// `saturnsRingsFlightKeepsAnEvenPace` measures it: a little over `flightPace`, within a step.
    nonisolated static let flightMost = 34.0

    /// How far the fastest thing on screen moves along the two-lap loop at its fastest, in device px a second at 1×.
    nonisolated static let alternateMost = 39.0

    /// The ceiling on battery while flying the two-lap loop at `speed`, by the same rule.
    nonisolated static func alternateRate(speed: Double) -> Int? {
        [10, 12, 15, 20].first { alternateMost * speed / Double($0) <= 2 }
    }

    /// The ceiling on battery while flying at `speed`, by the same rule as a hold's.
    nonisolated static func flightRate(speed: Double) -> Int? {
        [10, 12, 15, 20].first { flightMost * speed / Double($0) <= 2 }
    }

    /// The ceiling on battery while `view` holds at `speed`: the lowest of 10, 12, 15 and 20 fps at which its fastest
    /// thing moves 2 device px a frame or less (Sources/CLAUDE.md, Adding a scene), else none, for the battery's 30.
    nonisolated static func rate(_ view: View, speed: Double) -> Int? {
        [10, 12, 15, 20].first { view.pace * speed / Double($0) <= 2 }
    }

    /// How far the fastest thing on screen moves from camera `a` to camera `b`, in device pixels at 3024 × 1964: the
    /// points of the ring plane, the planet and the sky seen through a grid over the screen, found again from `b`. A
    /// point is also taken as turning with the Sun where something there does (the planet, whose night side and ring
    /// shadows do; the stars, which keep to the Sun's frame), and as
    /// moving with Daphnis where its waves are a tenth of a km or more, as the shader draws them; the larger counts.
    /// The battery rates are measured by it, and Fly Through's pace is set by it.
    nonisolated static func motion(_ a: Camera, _ b: Camera, across: Int = 48, up: Int = 32) -> Double {
        let (w, h) = (3024.0, 1964.0), (from, to) = (a.axes(), b.axes())
        let (lensA, lensB) = (tan(a.field / 2 * .pi / 180), tan(b.field / 2 * .pi / 180))
        func turned(_ p: SIMD3<Double>, by degrees: Double) -> SIMD3<Double> {
            let (c, s) = (cos(degrees * .pi / 180), sin(degrees * .pi / 180))
            return SIMD3(c * p.x - s * p.y, s * p.x + c * p.y, p.z)
        }
        /// Where `p` is on `b`'s screen in device pixels from the centre, a point if `far` is false, else a direction.
        func seen(_ p: SIMD3<Double>, far: Bool) -> SIMD2<Double>? {
            let q = far ? p : p - to.at, depth = simd_dot(q, to.ahead)
            guard depth > 1e-6 else { return nil }
            return SIMD2(simd_dot(q, to.right) / depth / lensB * w / 2, simd_dot(q, to.up) / depth / (lensB * h / w) * h / 2)
        }
        var most = 0.0
        for i in 0..<across {
            for j in 0..<up {
                let (x, y) = ((Double(i) + 0.5) / Double(across) * 2 - 1, (Double(j) + 0.5) / Double(up) * 2 - 1)
                let d = simd_normalize(from.right * x * lensA + from.up * y * lensA * h / w + from.ahead), c = from.at
                let k = 60.268 / 54.364, cs = SIMD3(c.x, c.y, c.z * k), ds = SIMD3(d.x, d.y, d.z * k)
                let (qa, qb, qc) = (simd_dot(ds, ds), simd_dot(cs, ds), simd_dot(cs, cs) - 60.268 * 60.268)
                let planet = qb * qb - qa * qc > 0 ? (-qb - (qb * qb - qa * qc).squareRoot()) / qa : Double.infinity
                let plane = -c.z / d.z, p = c + plane * d, r = (p.x * p.x + p.y * p.y).squareRoot()
                var moves: [(SIMD3<Double>, Bool)]
                if plane > 0, plane < planet, r > 72.2, r < 141.9 {
                    moves = [(p, false)]
                    let dr = abs(r - daphnis) * 1000
                    if a.moon + b.moon > 0, dr > 17.5, dr < 1050 {
                        // the wave's height there, as the shader has it (its moon.y at 1)
                        let phi = atan2(p.y, p.x) - a.ahead / daphnis, down = (-(r > daphnis ? 1.0 : -1.0) * phi)
                        let theta = 2 * .pi * (down - 2 * .pi * (down / (2 * .pi)).rounded(.down)) * 136504 / (3 * .pi * dr)
                        if 2.5 * pow(17.5 / dr, 2) * exp(-theta / 25) > 0.1 || exp(-(dr - 17.5) / 8 - theta / 25) > 0.1 {
                            moves.append((turned(p, by: (b.ahead - a.ahead) / daphnis * 180 / .pi), false))
                        }
                    }
                } else if planet < .infinity {
                    let q = c + planet * d
                    moves = [(q, false), (turned(q, by: b.sun - a.sun), false)]
                } else {
                    moves = [(turned(d, by: b.sun - a.sun), true)] // the stars keep to the Sun's frame
                }
                for (point, far) in moves {
                    guard let there = seen(point, far: far) else { return .infinity }
                    most = max(most, simd_distance(there, SIMD2(x * w / 2, y * h / 2)))
                }
            }
        }
        // The planet's shadow's two edges across the rings, which sweep round with the Sun: lines a few pixels wide that
        // a grid of rays mostly misses, so they're sampled along their length. Each lies 60,268 km (the planet's
        // radius) to one side of the line from the planet away from the Sun, whatever the Sun's height.
        let away = -simd_normalize(SIMD2(from.sun.x, from.sun.y)), aside = SIMD2(-away.y, away.x)
        for edge in [-1.0, 1.0] {
            for i in 0..<48 {
                let r = 72.2 + (141.9 - 72.2) * Double(i) / 47, flat = away * (r * r - 60.268 * 60.268).squareRoot() + aside * edge * 60.268
                let p = SIMD3(flat.x, flat.y, 0), q = p - from.at, depth = simd_dot(q, from.ahead)
                guard depth > 1e-6 else { continue }
                let here = SIMD2(simd_dot(q, from.right) / depth / lensA * w / 2, simd_dot(q, from.up) / depth / (lensA * h / w) * h / 2)
                guard abs(here.x) <= w / 2, abs(here.y) <= h / 2, let there = seen(turned(p, by: b.sun - a.sun), far: false) else { continue }
                most = max(most, simd_distance(there, here))
            }
        }
        return most
    }

    /// What the camera holds or glides to: a view, Fly Through's loop, or the crossing point, on its way to the other
    /// face and then on to `after`.
    private enum Goal: Equatable { case view(Int), loop, crossing }
    /// Holding `goal`, or gliding to it, since `since` on the scene's clock, `time`; `previous` is the view before.
    private enum Phase { case hold, glide(from: Origin) }
    /// Where a glide sets out from: a view still drifting on, as a hold ends, or the one-face loop still flying on, so
    /// the camera doesn't stop dead before it moves off; or a camera standing where it was, partway through a glide,
    /// on the two-lap loop (which might change faces under it) or at the crossing point.
    private enum Origin { case drifting(Int), flying, still(Camera) }
    private var phase = Phase.hold, goal: Goal, after = Goal.loop, previous: Int?, since: Double, time = 0.0, lastUpdate: TimeInterval?
    /// The face the camera is on, or will be once it has crossed; whether it flies the two-lap loop that changes faces
    /// (Fly Through under Alternate); when it last changed faces, on the scene's clock; and, in Cycle under Alternate,
    /// whether its next glide changes them (every other one does).
    private var lit: Bool, alternating: Bool, crossed = 0.0, crossNext = false
    /// How far round Fly Through's loop the camera is (or a glide onto or off it is aiming for), in seconds at 1×.
    private var loop = 0.0
    /// How far the drift has gone in the hold that's showing, or the one a glide sets out from: seconds at 1×.
    private var drift: Double
    /// The ceiling on battery: the view's at the Speed set while it holds, none while it glides, when the fastest
    /// thing on screen crosses 51 to 176 device px a second (`saturnsRingsMotionFitsTheBatteryRates`; docs/saturns-rings.md, Cost).
    private(set) var batteryRate: Int? { didSet { batteryRateChanged(from: oldValue) } }
    private let cam = SKUniform(name: "u_cam", vectorFloat3: .zero), rot = SKUniform(name: "u_rot", matrixFloat3x3: matrix_identity_float3x3)
    private let sunUniform = SKUniform(name: "u_sun", vectorFloat3: .zero), lens = SKUniform(name: "u_lens", vectorFloat2: .zero)
    private let moonUniform = SKUniform(name: "u_moon", vectorFloat2: .zero), starsUniform = SKUniform(name: "u_stars", float: 1)
    /// The Sun's height over the ring plane in degrees, for the day the scene was built (`light(on:)`).
    let sunUp: Double
    private let exposure = SKUniform(name: "u_exposure", float: 1), planetExposure = SKUniform(name: "u_planetExposure", float: 1)
    private let colours = (0..<5).map { SKUniform(name: "u_c\($0)", vectorFloat3: .zero) }
    /// The face whose colours are in `colours`.
    private var coloured: Bool?

    /// Starts holding `first` (the view picked in Settings, else one at random), `moment` seconds in (the
    /// `saturn.moment` default if nil, for pictures), or with `next`, gliding from it to `next`, `moment` seconds in
    /// (for tests), in the light of `date` (`SaturnsRings.date` if nil). With `fly` (or Fly Through picked), it flies
    /// the loop from `moment` times Speed round it, or from somewhere on it at random if no moment is given. It starts
    /// on the face Settings asks for, or the appearance does, or under Alternate the lit (the two-lap loop's lit lap).
    init(size: CGSize, from first: Int? = nil, to next: Int? = nil, fly: Bool = false, moment: Double? = nil, date: Date? = nil) {
        let pick = Int(Self.view.value), pinned = moment ?? (UserDefaults.standard.object(forKey: "saturn.moment") as? Double)
        let moment = pinned ?? 0, flies = fly || first == nil && pick == Self.views.count + 1
        goal = flies ? .loop : .view(first ?? ((1...Self.views.count).contains(pick) ? pick - 1 : Self.views.indices.randomElement()!))
        (lit, alternating) = (Self.wanted ?? true, flies && Int(Self.face.value) == 2)
        (since, drift) = (-moment, moment * Self.speed.value)
        if flies {
            let lap = alternating ? Self.alternateFlight[120 * (Self.flightOrder.count + 1)] : Self.flight.last!
            loop = pinned.map { $0 * Self.speed.value } ?? .random(in: 0..<lap)
        }
        let light = Self.light(on: date ?? Self.date)
        sunUp = light.up
        super.init(size: size)

        // ponytail: the first copy builds on the main thread in about 50 ms in release (the profile read 10, the
        // pyramid's bake 8.5, the star grid 6, the glow 8), about 150 while the HEIC decoder first starts; a second,
        // sharing the textures, in 8. Bake them off the main thread behind a still if a switch to it is seen to stall.
        // The profile is read on every build though the shader takes only its first radius, step and length: keep
        // those beside the shared pyramid first.
        let rings = RingProfile.load()
        let table = sharedTexture("saturn-rings-pyramid") { rings.pyramid() }
        // The real stars and the Milky Way's glow, Black Hole's (each 2,048 × 1,024, the stars 8 MB): the stars a
        // grid of cells, read at their centres.
        let catalogue = sharedTexture("blackhole-star-cells") {
            let cells = SKTexture(data: Data(BlackHole.starCells()), size: CGSize(width: BlackHole.skyCells.across, height: BlackHole.skyCells.up))
            cells.filteringMode = .nearest
            return cells
        }
        let glow = sharedTexture("saturn-rings-glow") {
            // At half its size, 1,024 across: a soft glow, magnified some 15 times on the screen even so, that reads
            // in 15 ms rather than 22 to 35 (with the HEIC decoder already running) and takes 2 MB rather than 8.
            let options = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 1024,
                           kCGImageSourceShouldCacheImmediately: true] as CFDictionary
            guard let source = CGImageSourceCreateWithURL(resource("blackhole-glow.heic") as CFURL, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
                return SKTexture(data: Data([0, 0, 0, 255]), size: CGSize(width: 1, height: 1))
            }
            return SKTexture(cgImage: image)
        }
        let turn = simd_float3x3(columns: (SIMD3<Float>(light.sky.columns.0), SIMD3<Float>(light.sky.columns.1), SIMD3<Float>(light.sky.columns.2)))
        let sprite = SKSpriteNode(color: .black, size: size)
        sprite.anchorPoint = .zero
        sprite.shader = SKShader(source: shaderCommon + saturnsRingsSource(rings), uniforms: [
            SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)]), SKUniform(name: "u_table", texture: table),
            cam, rot, sunUniform, lens, moonUniform, starsUniform, exposure, planetExposure,
            SKUniform(name: "u_catalogue", texture: catalogue), SKUniform(name: "u_galaxy", texture: glow),
            SKUniform(name: "u_sky", matrixFloat3x3: turn),
        ] + colours)
        addChild(sprite)

        if let next, case .view(let first) = goal { glide(to: .view(next), at: since, from: .drifting(first)) }
        advance()
        show()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func update(_ currentTime: TimeInterval) {
        let seconds = frameTime(currentTime, &lastUpdate)
        time += seconds
        drift += seconds * Self.speed.value
        loop += seconds * Self.speed.value
        advance()
        show()
    }

    /// The face Settings asks for now: nil under Alternate, which changes on its own.
    private static var wanted: Bool? {
        switch Int(face.value) {
        case 0: false
        case 2: nil
        case 3: !systemIsDark
        default: true
        }
    }

    /// The camera now.
    func camera() -> Camera {
        let there: Camera
        switch goal {
        case .view(let view): there = Self.held(Self.views[view], for: drift, lit: lit)
        case .loop: there = Self.flying(loop, lit: lit, alternating: alternating)
        case .crossing: there = Self.crossing(lit: lit)
        }
        guard case .glide(let origin) = phase else { return there }
        let from: Camera
        switch origin {
        case .drifting(let view): from = Self.held(Self.views[view], for: drift, lit: lit)
        case .flying: from = Self.flying(loop, lit: lit)
        case .still(let camera): from = camera
        }
        // onto a view as it begins to drift, or onto the loop as it flies on, so the camera arrives moving with it
        var to = there
        if case .view(let view) = goal { to = Self.held(Self.views[view], for: 0, lit: lit) }
        let u = min(max((time - since) / Self.glide, 0), 1)
        return Self.between(from, to, u * u * (3 - 2 * u))
    }

    /// Where a glide starting now sets out from.
    private var origin: Origin {
        guard case .hold = phase else { return .still(camera()) }
        switch goal {
        case .view(let view): return .drifting(view)
        case .loop: return alternating ? .still(camera()) : .flying
        case .crossing: return .still(camera())
        }
    }

    /// Moves the phase on, each change at the moment it's due, so the path is the same at any frame rate: to a hold
    /// once a glide is over, or at the crossing point, over to the other face and on; over to the other face when
    /// Settings or the appearance asks for it, from wherever the camera is; onto the loop (the two-lap one under
    /// Alternate), to a view picked in Settings, or off the loop for Cycle; under Alternate, over to the other face
    /// every half hour from a view held, and every other glide in Cycle; and in Cycle, toward a view at random once a
    /// hold is over.
    private func advance() {
        let pick = Int(Self.view.value), speed = Self.speed.value, holds = Self.hold.value.rounded() * 60
        let alternate = Int(Self.face.value) == 2, flies = pick == Self.views.count + 1, picked = (1...Self.views.count).contains(pick) ? pick - 1 : nil
        if goal == .loop, alternating, case .hold = phase { lit = camera().lit } // the two-lap loop changes faces on its own
        while true {
            if case .glide = phase, time - since >= Self.glide {
                if goal == .crossing {
                    // ponytail: a crossing is two glides, eased at both ends, so the camera rests at the crossing point
                    // a moment between them; one move through it (the loop's spline) if that's ever seen as a stop
                    lit.toggle()
                    crossed = since + Self.glide
                    (phase, goal, since) = (.glide(from: .still(Self.crossing(lit: lit, leaving: true))), after, since + Self.glide)
                } else {
                    (phase, since) = (.hold, since + Self.glide)
                    drift = (time - since) * speed
                }
            } else if goal == .crossing {
                // on the way to the crossing point it goes on there; what comes after follows Settings
                after = flies ? .loop : picked.map { .view($0) } ?? after
                break
            } else if let wanted = Self.wanted, wanted != lit {
                // over to the other face, then back to the view or the loop it was at or going to
                let from = origin
                (after, alternating) = (goal, false)
                glide(to: .crossing, at: time, from: from)
            } else if flies, goal != .loop || alternating != alternate {
                // onto the loop where it passes the view the camera is at or going to, on the face it's on
                let from = origin, view: Int
                if case .view(let at) = goal { view = at } else { view = Self.nextOnLoop(loop, alternating: alternating) }
                alternating = alternate
                loop = Self.flightSeconds(at: view, lit: lit, alternating: alternate)
                glide(to: .loop, at: time, from: from)
            } else if let picked, goal != .view(picked) {
                let from = origin
                alternating = false
                glide(to: .view(picked), at: time, from: from)
            } else if pick == 0, goal == .loop {
                // off the loop to the next view it would have passed, to hold there as Cycle does
                let next = Self.nextOnLoop(loop, alternating: alternating), from = origin
                alternating = false
                glide(to: .view(next), at: time, from: from)
            } else if alternate, let picked, case .hold = phase, time - crossed >= Self.crossEvery {
                after = .view(picked)
                glide(to: .crossing, at: time, from: .drifting(picked))
            } else if pick == 0, case .view(let view) = goal, case .hold = phase, time - since >= holds {
                let next = Self.next(after: view, previous: previous)
                if alternate && crossNext {
                    after = .view(next)
                    glide(to: .crossing, at: since + holds, from: .drifting(view))
                } else {
                    glide(to: .view(next), at: since + holds, from: .drifting(view))
                }
                crossNext = alternate && !crossNext
            } else {
                break
            }
        }
        guard case .hold = phase else { batteryRate = nil; return }
        switch goal {
        case .view(let view): batteryRate = Self.rate(Self.views[view], speed: speed)
        case .loop: batteryRate = alternating ? Self.alternateRate(speed: speed) : Self.flightRate(speed: speed)
        case .crossing: batteryRate = nil
        }
    }

    private func glide(to next: Goal, at moment: Double, from origin: Origin) {
        if case .view(let view) = goal { previous = view }
        phase = .glide(from: origin)
        (goal, since) = (next, moment)
    }

    /// Hands the camera, and the settings that change how it's drawn, to the shader.
    private func show() {
        let camera = camera(), lit = camera.lit, axes = camera.axes(sunUp: sunUp)
        let tangent = Float(tan(camera.field / 2 * .pi / 180)), brightness = Self.brightness.value
        cam.vectorFloat3Value = SIMD3<Float>(axes.at)
        rot.matrixFloat3x3Value = matrix_float3x3(columns: (SIMD3<Float>(axes.right), SIMD3<Float>(axes.up), SIMD3<Float>(axes.ahead)))
        sunUniform.vectorFloat3Value = SIMD3<Float>(axes.sun)
        lens.vectorFloat2Value = [tangent, tangent * Float(size.height / size.width)]
        moonUniform.vectorFloat2Value = [Float(camera.ahead / Self.daphnis), Float(camera.moon)]
        exposure.floatValue = Float(camera.exposure * brightness * Self.lift(sunUp, lit: lit))
        planetExposure.floatValue = Float(camera.planet * brightness)
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
        // Out past the rings, where the camera crosses their plane to change faces, they fade over its last 20 km to
        // it: seen edge on they are a sheet a pixel's fraction thick, and a band of whole pixels stood for it, which
        // jumped from one side of the horizon to the other as the camera went through.
        float edgeOn = length(c.xy) > 142.0 ? clamp(abs(c.z) / 0.02, 0.0, 1.0) : 1.0;
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
            eView = mix(1.0, eView, gap * edgeOn);
            lin = lin * eView + hueLin / max(luma(hueLin), 1e-4) * light * sunlit * gap * edgeOn * u_exposure;
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
        // The sky: near-black (luma 6), the Milky Way's glow (stored as its value to the 0.6: up to about 17 more at
        // the galactic centre, 7 at the 99th percentile) and the real stars, all behind whatever the rings let through.
        // `q` is the way to look with the Sun at azimuth 0 round the pole, `u_sky` turns it to the files' frame,
        // where longitude is atan(x, z) and latitude asin(y) across and up each (the star grid's cells 2,048 by 1,024).
        // Only where the sky shows: through the rings it shows a little almost everywhere, but where it shows less
        // than 1/60 the most the stars and glow add (30 of 255) is under half a level. (The glow file has no smaller
        // copies of itself, so it can be read in a branch.)
        vec3 glow = vec3(0.0), starLight = vec3(0.0);
        if (sky > 0.017 && u_stars > 0.0) {
            vec2 toSun = normalize(s.xy);
            vec3 q = vec3(toSun.x * d.x + toSun.y * d.y, toSun.x * d.y - toSun.y * d.x, d.z);
            vec3 there = u_sky * q;
            float lon = atan(there.x, there.z), lat = asin(clamp(there.y, -1.0, 1.0));
            vec2 place = vec2(lon / 6.2831853 + 0.5, lat / 3.1415927 + 0.5);
            glow = pow(texture2D(u_galaxy, place).rgb, vec3(1.667)) * 18.0 / 255.0;
            // The stars: any near enough to light this pixel is in a cell that comes within `reach` of it, a star's
            // radius in cells: one or two each way, but more across toward the files' poles, where a cell is narrower
            // than a star (to 6 either side, past which, within 3° of the poles, a star is cut). A cell is 0.003068
            // rad tall, and that times the cosine of the latitude wide; a star is a dot 0.9 points in radius,
            // at luma 30 for the brightest (its code 1, magnitude -1.5), falling as the square of the code, so 5 at
            // magnitude 6 and gone by 9. Its colour, from its temperature (Black Hole's place in its black-body
            // table, about 0.4 at 3,000 K to 0.7 at 10,000 K), only a hint at these levels.
            // ponytail: two colours by temperature, not Black Hole's black-body table (a fourth texture), as no star
            // passes luma 30; the table if they're ever drawn bright enough for colour to show. And a star within 3°
            // of the files' poles is cut, where its cells are too narrow to search: search further if one is seen.
            float perPt = u_size.x / (2.0 * u_lens.x), wide = 0.003068 * max(cos(lat), 0.001) * perPt, tall = 0.003068 * perPt;
            vec2 at = place * vec2(2048.0, 1024.0), reach = vec2(min(0.9 / wide, 6.0), 0.9 / tall);
            vec2 low = floor(at - reach), high = floor(at + reach);
            for (int j = 0; j < 2; j++) {
                if (low.y + float(j) > high.y) { break; }
                for (int i = 0; i < 13; i++) {
                    if (low.x + float(i) > high.x) { break; }
                    vec2 cell = low + vec2(float(i), float(j));
                    vec4 star = texture2D(u_catalogue, (vec2(mod(cell.x, 2048.0), clamp(cell.y, 0.0, 1023.0)) + 0.5) / vec2(2048.0, 1024.0));
                    if (star.b > 0.0) {
                        vec2 off = (cell + (star.rg * 255.0 + 0.5) / 256.0 - at) * vec2(wide, tall);
                        vec3 hue = mix(vec3(1.0, 0.85, 0.68), vec3(0.8, 0.88, 1.0), smoothstep(0.4, 0.7, star.a));
                        starLight += hue * smoothstep(0.9, 0.0, length(off)) * star.b * star.b * 30.0 / 255.0;
                    }
                }
            }
        }
        col += (6.0 / 255.0 + min(glow + starLight, vec3(30.0 / 255.0)) * u_stars) * sky; // the look report's cap
        col += 3.0 / 255.0 * (1.0 - sky);
        col += (hash21(v_tex_coord * u_size * 2.0) - 0.5) / 255.0;
        gl_FragColor = vec4(col, 1.0);
    }
    """
}
