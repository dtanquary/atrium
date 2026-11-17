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
    func cover(_ x: Int, _ y: Int) -> UInt8 { // the canopy's alpha over a pixel of the picture (rows top first)
        let t = (SIMD2(Double(x) + 0.5, Double(frames.h - y) - 0.5) / SIMD2(Double(frames.w), Double(frames.h)) * 2 - 1) * camera.tan
        let q = t / (2 * camera.extent) + 0.5
        let (i, j) = (min(max(Int(q.x * Double(made.width)), 0), made.width - 1), min(max(Int(q.y * Double(made.height)), 0), made.height - 1))
        return made.canopy[(j * made.width + i) * 4 + 3]
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

/// The trees sway as bodies, not as a picture wobbling like water: two points 30-80 px apart inside one group of
/// crowns move together, and a point in another group moves apart from them as the two groups' breezes say. Measured in the drawn
/// frames, by matching a patch round each point from one frame to one 1.5 s later.
@MainActor @Test func canopyTreesSwayAsBodies() throws {
    let defaults = UserDefaults.standard, pins = Canopy.pins
    defer { for key in [pins.seed, pins.date, pins.hour] { defaults.removeObject(forKey: key) } }
    for (key, value) in [(pins.seed, 3 as Any), (pins.date, "2026-07-15"), (pins.hour, 15.5)] { defaults.set(value, forKey: key) }
    let size = CGSize(width: 1512, height: 982), camera = Canopy.Camera(size: size), place = CLLocationCoordinate2D(latitude: 42, longitude: -88)
    var frames = try Frames(Canopy(size: size, place: place), size: size)
    frames.draw()
    let made = Canopy.bake(moment: Canopy.moment(day: "2026-07-15", hour: 15.5), latitude: 42, longitude: -88, camera: camera, seed: 3,
                           light: nil, night: false).made
    let (ew, eh) = (made.coverWidth, made.coverHeight)
    // the cells of the sway map wholly in one group, as points on the screen (rows top first), on the leaves
    var cells: [[(x: Int, y: Int)]] = [[], [], [], []]
    for j in stride(from: 2, to: eh - 2, by: 3) { for i in stride(from: 2, to: ew - 2, by: 3) {
        let share = (0..<4).map { Double(made.sway[(j * ew + i) * 4 + $0]) / 255 }
        guard let g = share.firstIndex(where: { $0 > 0.97 }), share.reduce(0, +) - share[g] < 0.02 else { continue }
        let t = (SIMD2(Double(i) + 0.5, Double(j) + 0.5) / SIMD2(Double(ew), Double(eh)) - 0.5) * 2 * camera.extent
        let uv = t / camera.tan * 0.5 + 0.5
        guard abs(uv.x - 0.5) < 0.42, abs(uv.y - 0.5) < 0.4 else { continue }
        let (x, y) = (Int(uv.x * Double(frames.w)), Int((1 - uv.y) * Double(frames.h)))
        let (ci, cj) = (Int(Double(i) / Double(ew) * Double(made.width)), Int(Double(j) / Double(eh) * Double(made.height)))
        guard made.canopy[(cj * made.width + ci) * 4 + 3] > 200 else { continue }
        cells[g].append((x, y))
    }}
    let groups = (0..<4).filter { cells[$0].count >= 2 }
    try #require(groups.count >= 2, "no two groups wholly inside the screen")
    let (g, h) = (groups[0], groups[1])
    let a = cells[g][0], b = try #require(cells[g].dropFirst().first { (30...80).contains(hypot(Double($0.x - a.x), Double($0.y - a.y))) }), c = cells[h][0]
    // a moment when the two groups' breezes differ by 8 px or more
    let breeze = Canopy.Breeze(seed: 3)
    func gap(_ t0: Double, _ t1: Double) -> Double {
        let (o0, o1) = (breeze.offsets(t0), breeze.offsets(t1))
        return length((o1[g] - o0[g]) - (o1[h] - o0[h]))
    }
    var tries = 0
    while gap(frames.time, frames.time + 1.5) < 8, tries < 60 { frames.draw(seconds: 0.5); tries += 1 }
    let before = frames.grey(), t0 = frames.time
    frames.draw(seconds: 1.5)
    let after = frames.grey()
    func shift(_ p: (x: Int, y: Int)) -> SIMD2<Double> { // the patch's move from before to after, in pixels (x right, y down)
        var best = (cost: Float.infinity, d: SIMD2<Double>.zero)
        for dy in -20...20 { for dx in -20...20 {
            var cost: Float = 0
            for y in stride(from: p.y - 20, through: p.y + 20, by: 2) { for x in stride(from: p.x - 20, through: p.x + 20, by: 2) {
                let e = before[y * frames.w + x] - after[(y + dy) * frames.w + x + dx]
                cost += e * e
            }}
            if cost < best.cost { best = (cost, [Double(dx), Double(dy)]) }
        }}
        return best.d
    }
    let (sa, sb, sc) = (shift(a), shift(b), shift(c))
    let (o0, o1) = (breeze.offsets(t0), breeze.offsets(t0 + 1.5))
    let expected = (o1[g] - o0[g]) - (o1[h] - o0[h]) // the two groups' moves apart, in px at 2x on a 14" (x right, y up)
    print("Canopy's sway over 1.5 s: group \(g) at \(a) moved \(sa), at \(b) \(sb); group \(h) at \(c) \(sc); apart by \(expected) expected")
    // (within the limbs' own sway, 2.5 px either way, which differs a little from point to point)
    #expect(length(sa - sb) <= 4, "one group's crowns moved apart")
    #expect(length((sa - sc) - SIMD2(expected.x, -expected.y)) <= 4 + 0.15 * length(expected), "the groups didn't move as their breezes say")
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
    print("Canopy at 1512 x 982: built on the main thread in \(built.map(ms)), baked off it in \(ms(baked))")

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
