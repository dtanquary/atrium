import CoreLocation
import Foundation
import Metal
import SpriteKit
import Testing
import CanopyBake
@testable import Atrium

/// Canopy's year at 42°N: coming out in May, in full leaf in July, turned and thinning in early November, bare in
/// January.
@Test func canopySeasons() {
    func on(_ month: Int, _ day: Int) -> CanopySeason {
        CanopySeason(date: Calendar.current.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!, latitude: 42)
    }
    let (may, july, november, january) = (on(5, 12), on(7, 15), on(11, 5), on(1, 15))
    #expect(may.out > 0.2 && may.out < 1 && may.pale > 0)
    #expect(july.out == 1 && july.turned == 0 && july.fallen == 0 && july.pale == 0)
    #expect(november.turned > 0.9 && november.fallen > 0.2 && november.fallen < 0.9)
    #expect(january.out == 0)
}

/// Settings' moment, on a November evening at 42°N: the real one unset; a time held, on the clock of a day of the
/// season held (July for summer, January south of the equator, with the trees as that season has them); and by Light
/// and Dark Mode the Sun's own hours: well up for the day, about 6° down for the dusk, 18° or more for the night.
@Test func canopySettingsPickTheMoment() {
    let calendar = Calendar.current, now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 21, hour: 19, minute: 30))!
    let (latitude, longitude) = (42.0, Double(TimeZone.current.secondsFromGMT(for: now)) / 240) // where the clock is the Sun's
    func moment(_ time: Int, season: Int = 0, dark: Bool = false, latitude: Double = latitude) -> Date {
        Canopy.moment(time: time, holdHour: 15, season: season, dark: dark, latitude: latitude, longitude: longitude, now: now)
    }
    func sun(_ date: Date) -> Double {
        let jd = Sky.julianDate(date)
        return normalize(Sky.horizonMatrix(jd: jd, latitude: latitude, longitude: longitude) * Sky.sun(jd)).z
    }
    #expect(abs(moment(0).timeIntervalSince(now)) < 1)
    let held = calendar.dateComponents([.month, .day, .hour], from: moment(3, season: 2))
    #expect(held.month == 7 && held.day == 15 && held.hour == 15)
    #expect(calendar.component(.month, from: moment(3, season: 2, latitude: -35)) == 1)
    let seasons = (1...4).map { CanopySeason(date: moment(3, season: $0), latitude: latitude) }
    #expect(seasons[0].out > 0.7 && seasons[0].pale > 0.5)
    #expect(seasons[1].out == 1 && seasons[1].turned == 0)
    #expect(seasons[2].turned > 0.95 && seasons[2].fallen < 0.3)
    #expect(seasons[3].out == 0)
    #expect(sun(moment(1)) > 0.3 && sun(moment(2)) > 0.3)
    #expect(abs(sun(moment(1, dark: true)) + 0.105) < 0.02)
    #expect(sun(moment(2, dark: true)) < -0.31)
    #expect(sun(moment(1, season: 2)) > 0.8) // a summer's day under a summer Sun
}

/// The shader works out how many cells each row of the stars' grid holds in single precision: it must agree with
/// `Canopy.cells(row:)` on every row, or stars land in the wrong cells.
@Test func canopyStarRowsAgree() {
    for row in 0..<Canopy.grid.height {
        let a = Float(min(abs(Double(row) - 179.5) + 0.5, 180)) * 0.0087266463
        #expect(Double(max((Float(719.5) * cos(a)).rounded(.down), 1)) == Canopy.cells(row: Double(row)), "row \(row)")
    }
}

/// Never an empty night: a scene that starts on a September afternoon and is moved on to 11 pm (as its bakes every
/// five minutes would carry it) lands a second bake that shows stars through the gaps, a hundred or more, and none
/// through the leaves; and back at noon the stars are gone. Rendered as the desktop sees it, at 2x.
@MainActor @Test func canopyNightHasStars() throws {
    let defaults = UserDefaults.standard, pins = Canopy.pins
    defer { for key in [pins.seed, pins.date, pins.hour] { defaults.removeObject(forKey: key) } }
    defaults.set(3, forKey: pins.seed)
    defaults.set("2026-09-15", forKey: pins.date)
    defaults.set(15.5, forKey: pins.hour)
    // 42°N, at the longitude the clock keeps, so 11 pm on it is 11 pm by the Sun
    let zone = TimeZone.current
    let place = CLLocationCoordinate2D(latitude: 42, longitude: Double(zone.secondsFromGMT() - Int(zone.daylightSavingTimeOffset())) / 240)
    let size = CGSize(width: 1512, height: 982)
    var frames = try Frames(Canopy(size: size, place: place), size: size)
    frames.draw()
    let day = frames.stars()

    defaults.set(23.0, forKey: pins.hour)
    frames.draw(seconds: 2) // the next second's tick starts a bake for 11 pm,
    frames.draw()           // and this frame waits for it, lands it and shows it
    let night = frames.stars()
    // where the leaves and the wood are, from the same bake the scene made
    let camera = Canopy.Camera(size: size)
    let made = Canopy.bake(moment: Canopy.moment(day: "2026-09-15", hour: 23), latitude: place.latitude, longitude: place.longitude,
                           camera: camera, seed: 3, light: nil, night: false).made
    func cover(_ x: Int, _ y: Int) -> Int { // the canopy's alpha over a pixel of the picture (rows top first), the nearest leaves' over it
        let t = (SIMD2(Double(x) + 0.5, Double(frames.h - y) - 0.5) / SIMD2(Double(frames.w), Double(frames.h)) * 2 - 1) * camera.tan
        let q = t / (2 * camera.extent) + 0.5
        let (i, j) = (min(max(Int(q.x * Double(made.width)), 0), made.width - 1), min(max(Int(q.y * Double(made.height)), 0), made.height - 1))
        let (a, n) = (Int(made.canopy[(j * made.width + i) * 4 + 3]), Int(made.near[(j * made.width + i) * 4 + 3]))
        return 255 - (255 - a) * (255 - n) / 255
    }
    // the canopy's cover is the season's, the same all day, so it holds for the afternoon's picture too
    func clear(_ s: (x: Int, y: Int)) -> Bool { [(0, 0), (-6, 0), (6, 0), (0, -6), (0, 6)].allSatisfy { cover(s.x + $0.0, s.y + $0.1) == 0 } }
    func covered(_ s: (x: Int, y: Int)) -> Bool { [(0, 0), (-6, 0), (6, 0), (0, -6), (0, 6)].allSatisfy { cover(s.x + $0.0, s.y + $0.1) == 255 } }
    let (open, hidden) = (night.filter(clear), night.filter(covered))
    print("Canopy at 11 pm: \(open.count) stars in the open sky, \(hidden.count) under the leaves; at 3:30 pm \(day.filter(clear).count)")
    #expect(open.count >= 100, "an empty night")
    #expect(hidden.count <= open.count / 100, "stars showing through the leaves")
    #expect(day.filter(clear).count < 5, "stars by day")

    defaults.set(12.0, forKey: pins.hour)
    frames.draw(seconds: 2)
    frames.draw()
    #expect(frames.stars().filter(clear).count < 5, "stars left at noon")
}

/// The wood stays still and the leaves rustle (research-motion.md's Model 2): over a second
/// of midsummer, the screen's pixels well inside solid wood (none of it free in the bake's map round it, no near leaf
/// within 16 px to slide over it) change by next to nothing, and those on the nearest leaves where they are wholly free
/// change.
@MainActor @Test func canopyWoodStaysStill() throws {
    let defaults = UserDefaults.standard, pins = Canopy.pins
    defer { for key in [pins.seed, pins.date, pins.hour] { defaults.removeObject(forKey: key) } }
    for (key, value) in [(pins.seed, 3 as Any), (pins.date, "2026-07-15"), (pins.hour, 15.5)] { defaults.set(value, forKey: key) }
    let size = CGSize(width: 1512, height: 982), camera = Canopy.Camera(size: size)
    var frames = try Frames(Canopy(size: size, place: CLLocationCoordinate2D(latitude: 42, longitude: -88)), size: size)
    frames.draw()
    let made = Canopy.bake(moment: Canopy.moment(day: "2026-07-15", hour: 15.5), latitude: 42, longitude: -88, camera: camera, seed: 3,
                           light: nil, night: false).made
    let near = made.near
    let before = frames.grey()
    frames.draw(seconds: 1)
    let after = frames.grey()
    var (wood, leaves): ([Float], [Float]) = ([], [])
    for y in stride(from: 8, to: frames.h - 8, by: 3) { for x in stride(from: 8, to: frames.w - 8, by: 3) {
        let t = (SIMD2(Double(x) + 0.5, Double(frames.h - y) - 0.5) / SIMD2(Double(frames.w), Double(frames.h)) * 2 - 1) * camera.tan
        let q = t / (2 * camera.extent) + 0.5 // on the stand, rows bottom first as the bake's maps are
        let (i, j) = (Int(q.x * Double(made.width)), Int(q.y * Double(made.height))), p = (j * made.width + i) * 4
        let (ei, ej) = (Int(q.x * Double(made.coverWidth)), Int(q.y * Double(made.coverHeight)))
        func free(_ di: Int, _ dj: Int) -> UInt8 {
            made.sway[(min(max(ej + dj, 0), made.coverHeight - 1) * made.coverWidth + min(max(ei + di, 0), made.coverWidth - 1)) * 4]
        }
        func nearAt(_ di: Int, _ dj: Int) -> UInt8 { near[(min(max(j + dj, 0), made.height - 1) * made.width + min(max(i + di, 0), made.width - 1)) * 4 + 3] }
        let change = abs(before[y * frames.w + x] - after[y * frames.w + x])
        let round = [(-1, -1), (0, -1), (1, -1), (-1, 0), (0, 0), (1, 0), (-1, 1), (0, 1), (1, 1)]
        if made.canopy[p + 3] == 255, round.allSatisfy({ free($0.0, $0.1) == 0 }), round.allSatisfy({ nearAt($0.0 * 16, $0.1 * 16) == 0 }) {
            wood.append(change)
        }
        if free(0, 0) == 255, near[p + 3] == 255 { leaves.append(change) }
    } }
    let (still, rustle) = (wood.reduce(0, +) / Float(max(wood.count, 1)), leaves.reduce(0, +) / Float(max(leaves.count, 1)))
    print("Canopy over 1 s: \(wood.count) pixels on solid wood changed by \(still) of 255 on average, \(leaves.count) on free near leaves by \(rustle)")
    #expect(wood.count > 500 && leaves.count > 500)
    #expect(still < 1, "the wood moved")
    #expect(rustle > 4, "the leaves stood still")
}

/// Leaves fall only in the weeks they really fall, and only by day: none in July, some on a November afternoon at
/// 42°N (white oak's leaves coming down fast) over 30 s, and none that night.
@MainActor @Test func canopyLeavesFallInAutumn() throws {
    let defaults = UserDefaults.standard, pins = Canopy.pins
    defer { for key in [pins.seed, pins.date, pins.hour] { defaults.removeObject(forKey: key) } }
    let size = CGSize(width: 1512, height: 982), place = CLLocationCoordinate2D(latitude: 42, longitude: -88)
    for (day, hour, falls) in [("2026-07-15", 15.5, false), ("2026-11-05", 14.0, true), ("2026-11-05", 22.0, false)] {
        for (key, value) in [(pins.seed, 3 as Any), (pins.date, day), (pins.hour, hour)] { defaults.set(value, forKey: key) }
        let scene = Canopy(size: size, place: place)
        var frames = try Frames(scene, size: size), most = 0
        for _ in 0..<120 {
            frames.draw(seconds: 0.25)
            most = max(most, scene.leaves.falling)
        }
        print("Canopy on \(day) at \(hour): \(String(format: "%.1f", scene.leaves.rate)) leaves at once on average, at most \(most) seen in 30 s")
        #expect((most > 0) == falls, "\(day) at \(hour)")
    }
}

/// Each leaf moves as a piece of its own by the bake's map of whose leaf each point is (`CanopyBake.ids`): in July
/// nearly every point of the nearest leaves has a leaf's id and its spray's, and no point of solid wood (where the bare
/// stand's picture is solid) has one; bare in January there is none at all; and the map is the same later the same
/// day (its key), which lets the scene keep its texture.
@MainActor @Test func canopyLeavesHaveIds() {
    let camera = Canopy.Camera(size: CGSize(width: 1512, height: 982))
    func made(_ day: String, hour: Double = 13) -> CanopyBake.Made {
        Canopy.bake(moment: Canopy.moment(day: day, hour: hour), latitude: 42, longitude: -88, camera: camera, seed: 3, light: nil, night: false).made
    }
    let july = made("2026-07-15"), bare = made("2026-01-15")
    var (leaves, owned, wood, woodOwned) = (0, 0, 0, 0)
    var (ids, sprays) = (Set<UInt8>(), Set<UInt8>())
    for p in stride(from: 0, to: july.width * july.height * 4, by: 4) { // a pixel of the pictures and of the ids alike
        if july.near[p + 3] == 255 {
            leaves += 1
            if july.ids[p + 1] > 0, july.ids[p + 3] > 0 { owned += 1; ids.insert(july.ids[p + 1]); sprays.insert(july.ids[p + 3]) }
        }
        if bare.canopy[p + 3] == 255 { // bare, the picture is the wood alone
            wood += 1
            if july.ids[p] > 0 { woodOwned += 1 }
        }
    }
    print("Canopy's ids in July: \(owned) of \(leaves) points of the nearest leaves have one (\(ids.count) leaf ids, \(sprays.count) spray ids), "
          + "\(woodOwned) of \(wood) of solid wood; in leaf \(july.leafy) of the stand, \(bare.leafy) in January")
    #expect(leaves > 100_000 && Double(owned) > 0.9 * Double(leaves), "the nearest leaves have no ids")
    #expect(ids.count > 200 && sprays.count > 200)
    #expect(wood > 10_000 && woodOwned == 0, "the wood has leaves' ids")
    #expect(july.leafy > 0.2 && bare.leafy == 0 && bare.ids.allSatisfy { $0 == 0 })
    // the same leaves an hour and a half on, so the scene keeps the ids' texture from one bake to the next
    #expect(made("2026-07-15", hour: 14.5).idsKey == july.idsKey && bare.idsKey != july.idsKey)
}

/// The evergreens are needles, not bark (Dave: "why do i see these black spots on the trees"): bare in January at
/// midday, when the picture is the wood alone, a good share of its solid wood (the conifers' masses are most of it) is a
/// dark green, greener than it is red or blue by half, and visibly lit; the trunks and limbs stay bark, redder than green.
@MainActor @Test func canopyEvergreensAreGreen() {
    let camera = Canopy.Camera(size: CGSize(width: 1512, height: 982))
    let made = Canopy.bake(moment: Canopy.moment(day: "2026-01-15", hour: 12.5), latitude: 42, longitude: -88, camera: camera, seed: 3,
                           light: nil, night: false).made
    var (solid, green, bark, light) = (0, 0, 0, 0)
    for p in stride(from: 0, to: made.width * made.height * 4, by: 4) where made.canopy[p + 3] == 255 {
        let (r, g, b) = (Int(made.canopy[p]), Int(made.canopy[p + 1]), Int(made.canopy[p + 2]))
        solid += 1
        if g * 2 > r * 3, g * 2 > b * 3 { green += 1; light += g } else if r > g { bark += 1 }
    }
    print("Canopy's solid wood at a January midday: \(green) of \(solid) pixels needle green (green \(light / max(green, 1)) of 255 as stored), \(bark) bark")
    #expect(solid > 100_000 && green * 5 > solid * 2 && bark > 10_000, "the evergreens aren't green")
    #expect(light / max(green, 1) >= 18, "the evergreens are still black")
}

/// Canopy's ceiling on battery keeps the fastest motion to about 2 px a frame: 10-20 fps in the breeze (12 at its mean),
/// no more than 15 in light air, none in a strong wind's gusts, 10 at night, none while a leaf falls; and by day in
/// leaf never under 20, for the leaves' tremble.
@Test @MainActor func canopyBatteryRate() {
    func rates(_ mean: Double) -> [Int?] {
        let breeze = Canopy.Breeze(seed: 3, mean: mean)
        return stride(from: 0.0, to: 120, by: 0.5).map { Canopy.rate(fastest: breeze.fastest($0), night: false, falling: false) }
    }
    #expect(rates(4.3).allSatisfy { $0 != nil } && rates(4.3).contains(10) && rates(4.3).contains(12) && rates(4.3).contains(20))
    #expect(rates(2).allSatisfy { ($0 ?? 99) <= 15 })
    #expect(rates(12).contains(nil))
    #expect(Canopy.rate(fastest: 100, night: true, falling: false) == 10)
    #expect(Canopy.rate(fastest: 1, night: false, falling: true) == nil)
    #expect(Canopy.rate(fastest: 10, night: false, falling: false, leafy: true) == 20)
    #expect(Canopy.rate(fastest: 50, night: false, falling: false, leafy: true) == 30)
    #expect(Canopy.rate(fastest: 10, night: true, falling: false, leafy: true) == 10)
}

/// What building Canopy holds the main thread for, and its bake off it, at a 14" MacBook Pro's size: meaningful in a
/// release build: `CANOPY_LOAD=1 swift test -c release -Xswiftc -enable-testing --filter canopyLoad`. Then a bake for
/// later in the day (the light, the canopy and the night's stars, off the main thread), and what landing one costs the
/// main thread: the frame it lands on, against the frame after.
@MainActor @Test(.enabled(if: ProcessInfo.processInfo.environment["CANOPY_LOAD"] != nil)) func canopyLoad() throws {
    let clock = ContinuousClock(), size = CGSize(width: 1512, height: 982)
    let camera = Canopy.Camera(size: size), date = Canopy.moment(day: "2026-07-15", hour: 15.5)
    let light = Canopy.Light(camera: camera, date: date, latitude: 42, longitude: -88)
    let bake = CanopyBake(stand: resource(Canopy.stand.name), leaves: resource("dappled-leaves.png"), perTan: Canopy.stand.perTan,
                          extent: camera.extent, portrait: false, sun: light.sun, sunlight: light.sunlight, zenith: light.zenith,
                          season: CanopySeason(date: date, latitude: 42), seed: 3)
    var made: CanopyBake.Made?
    let baked = (0..<2).map { _ in clock.measure { made = bake.make() } }.min()!
    let built = (0..<3).map { _ in clock.measure { _ = Canopy(size: size) } }
    #expect(made.map { $0.canopy.count == $0.width * $0.height * 4 } == true)
    func ms(_ d: Duration) -> String { d.formatted(.units(allowed: [.milliseconds])) }
    var peak = rusage()
    getrusage(RUSAGE_SELF, &peak) // the most this process has held so far, the bakes' peak among it (bytes on macOS)
    print("Canopy at 1512 x 982: built on the main thread in \(built.map(ms)), baked off it in \(ms(baked)), "
          + "the process's peak \(peak.ru_maxrss / 1_000_000) MB")

    let night = Canopy.moment(day: "2026-07-15", hour: 22.5)
    func cpu() -> Double { // seconds of CPU this process has used, on every core
        var use = rusage()
        getrusage(RUSAGE_SELF, &use)
        return Double(use.ru_utime.tv_sec + use.ru_stime.tv_sec) + Double(use.ru_utime.tv_usec + use.ru_stime.tv_usec) / 1e6
    }
    var spent: [Double] = []
    let rebakes = [false, true, false].map { dark in
        let before = cpu()
        defer { spent.append(cpu() - before) }
        return clock.measure { _ = Canopy.bake(moment: night, latitude: 42, longitude: -88, camera: camera, seed: 3, light: nil, night: dark) }
    }
    let stars = clock.measure { _ = Canopy.starGrid() }
    let defaults = UserDefaults.standard, pins = Canopy.pins
    defer { for key in [pins.seed, pins.date, pins.hour] { defaults.removeObject(forKey: key) } }
    for (key, value) in [(pins.seed, 3 as Any), (pins.date, "2026-07-15"), (pins.hour, 15.5)] { defaults.set(value, forKey: key) }
    var frames = try Frames(Canopy(size: size, place: CLLocationCoordinate2D(latitude: 42, longitude: -88)), size: size)
    var landing: [Duration] = []
    // the first bake (by day), then one five minutes on, one into the night (with the stars and the Milky Way), one on
    // through the night, and one back to day (letting the night's textures go)
    for hour in [15.5, 15.6, 22.5, 22.6, 12.0] {
        defaults.set(hour, forKey: pins.hour)
        if hour != 15.5 { frames.draw(seconds: 2) } // its tick starts the bake
        Thread.sleep(forTimeInterval: 6) // and it arrives (at .utility) while we wait, so the next frame doesn't wait for it
        landing.append(frames.draw())
    }
    let steady = (0..<5).map { _ in frames.draw() }.min()!
    print("Canopy's bakes for later: \(rebakes.map(ms)) off the main thread (by day, with the night's textures (the stars' grid \(ms(stars))), by day), "
          + "\(spent.map { String(format: "%.2f", $0) }) s of CPU; "
          + "landing, the frame it lands on: \(landing.map(ms)) (first, day, into the night, night, back to day), against \(ms(steady)) for a frame")
}

/// Draws a scene with SKRenderer at 2x, as the render test does, timing each frame's update and render on the main
/// thread, and finds the stars in the last.
@MainActor private struct Frames {
    let renderer: SKRenderer, queue: MTLCommandQueue, texture: MTLTexture, w: Int, h: Int
    var time = ProcessInfo.processInfo.systemUptime + 1

    init(_ scene: SKScene, size: CGSize) throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        (w, h) = (Int(size.width) * 2, Int(size.height) * 2)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        (renderer, queue, texture) = (SKRenderer(device: device), try #require(device.makeCommandQueue()), try #require(device.makeTexture(descriptor: descriptor)))
        renderer.scene = scene
    }

    /// One frame, `seconds` after the last; what it held the main thread for, up to the GPU's taking it.
    @discardableResult mutating func draw(seconds: Double = 1.0 / 30) -> Duration {
        time += seconds
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        let buffer = queue.makeCommandBuffer()!
        let held = ContinuousClock().measure {
            renderer.update(atTime: time)
            renderer.render(withViewport: CGRect(x: 0, y: 0, width: w, height: h), commandBuffer: buffer, renderPassDescriptor: pass)
            buffer.commit()
        }
        buffer.waitUntilCompleted()
        return held
    }

    /// The last frame's brightness, 0 to 255 a pixel, rows top first.
    func grey() -> [Float] {
        var pixels = [UInt32](repeating: 0, count: w * h)
        texture.getBytes(&pixels, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
        return pixels.map { Float($0 & 255) * 0.0722 + Float($0 >> 8 & 255) * 0.7152 + Float($0 >> 16 & 255) * 0.2126 }
    }

    /// The stars in the last frame: each pixel as bright as the 8 round it and brighter by 15 of 255 or more than an
    /// even ring of sky 3 px away (the brightest of R, G and B; a gap among leaves has no even ring), as (x, y) with
    /// rows top first.
    func stars() -> [(x: Int, y: Int)] {
        var pixels = [UInt32](repeating: 0, count: w * h)
        texture.getBytes(&pixels, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
        let v = pixels.map { Int(max($0 & 255, $0 >> 8 & 255, $0 >> 16 & 255)) }
        let near = [-w - 1, -w, -w + 1, -1, 1, w - 1, w, w + 1], ring = [-3, 3, -3 * w, 3 * w, -2 * w - 2, -2 * w + 2, 2 * w - 2, 2 * w + 2]
        var found: [(x: Int, y: Int)] = []
        for y in 4..<h - 4 { for x in 4..<w - 4 {
            let p = y * w + x, c = v[p]
            guard c >= 40 else { continue }
            var (sum, low, high) = (0, 255, 0)
            for o in ring { let r = v[p + o]; sum += r; low = min(low, r); high = max(high, r) }
            guard c - sum / 8 >= 15, high - low <= 8, near.allSatisfy({ c >= v[p + $0] }) else { continue }
            found.append((x, y))
        } }
        return found
    }
}
