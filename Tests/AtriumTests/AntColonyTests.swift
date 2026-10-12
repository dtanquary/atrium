import Foundation
import Metal
import SpriteKit
import Synchronization
import Testing
@testable import AntNest
@testable import Atrium

/// A date and a time give one nest. The same seed bakes the same map twice and another seed another; the map's
/// rank is what it says, the share of the digging done when a cell goes, so the dug area grows as the clock's
/// share does; a young colony works one or two faces and a grown one eight, from one mouth at first; and the
/// clock is the day Dave picked: a farm begins at six, has 8% dug by seven, 23% by nine, 44% at noon, 75% at six in
/// the evening and 94% at midnight.
@Test func antColonyBakesOneNestForADate() throws {
    let clock = ContinuousClock(), began = clock.now
    let nest = Nest(seed: 20261012, cols: 756, rows: 491, bodyLength: 11), took = clock.now - began
    let again = Nest(seed: 20261012, cols: 756, rows: 491, bodyLength: 11), other = Nest(seed: 20261013, cols: 756, rows: 491, bodyLength: 11)
    #expect(nest.rank == again.rank && nest.heap == again.heap && nest.bytes() == again.bytes() && nest.rank != other.rank)
    let sand = nest.cols * (nest.rows - nest.ground)
    print("Ant Colony, the nest of 2026-10-12 on \(nest.cols) by \(nest.rows) cells: baked in \(took); \(nest.dug) cells dug of \(sand), \(nest.branches.count { !$0.room }) tunnels, \(nest.branches.count { $0.room }) rooms, \(nest.entrances.count) mouths")
    #expect(nest.dug > sand / 5 && nest.dug < sand / 3 && nest.entrances.count >= 2 && nest.branches.contains { $0.room })
    for share in [0.05, 0.25, 0.5, 0.75, 1] {
        let open = nest.rank.count { Double($0) <= share }
        #expect(abs(Double(open) / Double(nest.dug) - share) < 0.01, "at \(share), \(open) cells are dug of \(nest.dug)")
    }
    #expect(Nest.faces(at: 0.02) == 1 && Nest.faces(at: 0.1) == 2 && Nest.faces(at: 1) == 8)
    #expect(nest.branches.count { $0.parent < 0 && $0.opened[0] <= 0.05 } == 1, "more than one shaft begun in the first twentieth")

    let shares = [0, 1, 3, 6, 12, 18, 24, 30].map { (AntColony.share(after: $0) * 100).rounded() }
    #expect(shares == [0, 8, 23, 44, 75, 94, 100, 100])
}

/// The farm by the wall clock (`AntColony.Cycle`). A day runs from six to six. From a fresh install at Speed 1 it
/// is exactly the day's wall-clock farm. Moving Speed never moves the dig, up or down: as much is dug as was, and
/// it goes on from there at the new pace. Above 1 the next farm begins as each ends; at 1 a farm begins only at
/// six, so a nest finished early stays finished until then. A relaunch, which has only the four saved numbers,
/// finds the same place; after months away it is the day's own farm again; and a clock set back leaves the farm
/// whole and waiting.
@Test func antColonySpeedNeverMovesTheDig() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "America/Chicago"))
    func wall(_ day: Int, _ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Double {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute, second: second))!.timeIntervalSinceReferenceDate
    }
    let (before, six) = (AntColony.day(at: wall(12, 5, 59), calendar: calendar), AntColony.day(at: wall(12, 6), calendar: calendar))
    #expect(before.day == 20261011 && abs(before.hours - 23 - 59.0 / 60) < 1e-6 && six.day == 20261012 && six.hours == 0)

    var cycle = AntColony.Cycle(at: wall(12, 13, 30), speed: 1, calendar: calendar)
    func hours(_ day: Int, _ hour: Int, _ minute: Int = 0, _ second: Int = 0, speed: Double) -> Double {
        cycle.hours(at: wall(day, hour, minute, second), speed: speed, calendar: calendar)
    }
    #expect(cycle == AntColony.Cycle(day: 20261012, turn: 0, began: wall(12, 6), paced: 1))
    #expect(abs(hours(12, 13, 30, speed: 1) - 7.5) < 1e-9)
    // Speed to 4 at half past one: still seven and a half hours dug; an hour on, eleven and a half.
    #expect(abs(hours(12, 13, 30, speed: 4) - 7.5) < 1e-9 && abs(hours(12, 14, 30, speed: 4) - 11.5) < 1e-9 && cycle.turn == 0)
    // It ends 16.5 farm-hours on, at 17:37:30, and the day's next begins there.
    #expect(abs(hours(12, 17, 37, 29, speed: 4) - 24) < 0.002 && cycle.turn == 0)
    #expect(abs(hours(12, 17, 38, speed: 4) - 4 * 30.0 / 3600) < 1e-9 && cycle.day == 20261012 && cycle.turn == 1)
    // Back to 1 at six in the evening: an hour and a half dug, and it goes on at the day's pace; at six, the day's own.
    #expect(abs(hours(12, 18, speed: 4) - 1.5) < 1e-9 && abs(hours(12, 18, speed: 1) - 1.5) < 1e-9)
    #expect(abs(hours(13, 5, 59, speed: 1) - 1.5 - 11 - 59.0 / 60) < 1e-9 && cycle.day == 20261012 && cycle.turn == 1)
    #expect(hours(13, 6, speed: 1) == 0 && cycle == AntColony.Cycle(day: 20261013, turn: 0, began: wall(13, 6), paced: 1))

    // A nest hurried at 8 from six to half past eight, twenty hours' digging, and then left at 1 is done at half
    // past twelve, and stays done, the same nest, until six.
    #expect(hours(13, 6, speed: 8) == 0 && abs(hours(13, 8, 30, speed: 8) - 20) < 1e-9 && abs(hours(13, 8, 30, speed: 1) - 20) < 1e-9)
    #expect(abs(hours(13, 12, 30, speed: 1) - 24) < 1e-9)
    #expect(hours(13, 20, speed: 1) > 24 && hours(14, 5, 59, speed: 1) > 24 && cycle.day == 20261013 && cycle.turn == 0)
    #expect(hours(14, 6, speed: 1) == 0 && cycle.day == 20261014 && cycle.turn == 0)

    // A relaunch at Speed 4 has the farm, when it would have begun and at what pace, and is where it was.
    _ = hours(14, 9, speed: 4)
    var relaunched = AntColony.Cycle(day: cycle.day, turn: cycle.turn, began: cycle.began, paced: cycle.paced)
    #expect(relaunched.hours(at: wall(14, 9, 45), speed: 4, calendar: calendar) == (hours(14, 9, 45, speed: 4)) && relaunched == cycle)
    // Ten hours off at Speed 4: it is on a later farm of the same day, part dug.
    let later = relaunched.hours(at: wall(14, 19, 45), speed: 4, calendar: calendar)
    #expect(relaunched.day == 20261014 && relaunched.turn >= 1 && later >= 0 && later < 24)
    // The clock set back to before that farm began: the same farm, whole and waiting.
    let turn = relaunched.turn
    #expect(relaunched.hours(at: wall(14, 9), speed: 4, calendar: calendar) == 0 && relaunched.day == 20261014 && relaunched.turn == turn)
    // Sixteen days off, some 66 farms on: one of that day's, part dug. Two hundred days off: the day's own farm again, as
    // far along as the wall clock has it.
    let weeks = relaunched.hours(at: wall(31, 9), speed: 4, calendar: calendar)
    #expect(relaunched.day == 20261031 && relaunched.turn >= 1 && weeks >= 0 && weeks < 24)
    #expect(abs(relaunched.hours(at: wall(31, 9) + 200 * 86400, speed: 4, calendar: calendar) - 3) < 1e-9 && relaunched.day == 20270519 && relaunched.turn == 0)
}

/// What the ants must never do, watched every sixtieth of a second for half a minute at four ages of three nests,
/// with the digging going on forty times and more as fast as the day's clock runs it: no ant's middle is ever over undug
/// medium, and its head or its gaster hardly ever; a planted foot does not move; no body goes further in a
/// sixtieth of a second than a quarter of its length (a walk is a sixtieth of one); none gives up what it was
/// doing more than now and then; and someone is always walking.
@Test func antColonyKeepsItsAntsOutOfTheMedium() {
    var (watched, buried, poking, walked, ticks, gaveUp, leapt) = (0, 0, 0, 0, 0, 0, 0), (slid, jump) = (0.0, 0.0)
    let clock = ContinuousClock(), began = clock.now
    for seed in [20261012, 20261013, 7] as [UInt64] {
        let nest = Nest(seed: seed, cols: 756, rows: 491, bodyLength: 11)
        for (from, to) in [(0.02, 0.05), (0.3, 0.33), (0.7, 0.72), (0.99, 1)] {
            var colony = Colony(nest: nest, most: 24, seed: seed, share: from)
            colony.fastForward(300)
            var before = colony.ants
            for tick in 1...1800 {
                colony.step(share: from + (to - from) * Double(tick) / 1800)
                for (n, ant) in colony.ants.enumerated() {
                    watched += 1
                    if !colony.clear(ant.position, ant.forward, middle: true) { buried += 1 }
                    if !colony.clear(ant.position, ant.forward) { poking += 1 }
                    guard n < before.count else { continue }
                    jump = max(jump, simd_distance(before[n].position, ant.position) / nest.bodyLength)
                    for leg in 0..<6 { if let was = before[n].holds[leg], let now = ant.holds[leg] { slid = max(slid, simd_distance(was, now)) } }
                }
                ticks += 1
                if colony.ants.contains(where: { $0.state == .walk }) { walked += 1 }
                before = colony.ants
            }
            (gaveUp, leapt) = (gaveUp + colony.gaveUp, leapt + colony.leapt)
        }
    }
    print("Ant Colony, \(watched) ant-moments in \(clock.now - began): \(buried) with a middle over undug medium, \(poking) with a head or gaster over it; the furthest a planted foot moved \(slid) cells, and a body in a sixtieth of a second \(String(format: "%.3f", jump)) of its length; \(gaveUp) gave up and \(leapt) leapt; someone walking in \(walked) of \(ticks) moments")
    #expect(buried == 0)
    #expect(Double(poking) < 0.005 * Double(watched))
    #expect(slid == 0)
    #expect(jump < 0.25)
    #expect(gaveUp <= 6 && leapt <= 12)
    #expect(Double(walked) > 0.97 * Double(ticks))
}

/// A nest is baked from the date every morning, so a trap on one date is a crash at every launch that day. Six
/// dates on six grids (a 14-inch display's at each size of ant, a portrait display's, a 13-inch's and a 5K's), each
/// at four ages of its day and once with the clock set back under its ants: nothing traps, every ant is somewhere
/// in the tank, no ant's middle is in the medium, and every nest has a mouth. (The wide run of this, 1,080 nests
/// on twelve grids, is in docs/ant-colony.md.)
@Test func antColonySurvivesManyDatesAndDisplays() {
    let grids = [(756, 491), (1279, 831), (462, 300), (540, 960), (640, 400), (1280, 720)]
    let seeds: [UInt64] = [2026101200, 2026103101, 2027010100, 2027022800, 2027070403, 2028022900]
    let tally = Mutex((nests: 0, moments: 0, buried: 0, lost: 0, mouths: 99))
    let clock = ContinuousClock(), began = clock.now
    DispatchQueue.concurrentPerform(iterations: grids.count * seeds.count) { job in
        let (cols, rows) = grids[job % grids.count], seed = seeds[job / grids.count]
        let nest = Nest(seed: seed, cols: cols, rows: rows, bodyLength: 11), most = min(max(cols * rows / 121 / 128, 4), 100)
        var (moments, buried, lost) = (0, 0, 0)
        for (from, to) in [(0.02, 0.06), (0.3, 0.33), (0.7, 0.72), (0.99, 1), (0.5, 0.2)] {
            var colony = Colony(nest: nest, most: most, seed: seed, share: from)
            colony.fastForward(60)
            for tick in 1...300 {
                colony.step(share: to < from ? (tick < 150 ? from : to) : from + (to - from) * Double(tick) / 300) // (set back in one go)
                for ant in colony.ants {
                    moments += 1
                    let at = ant.position
                    if !(at.x.isFinite && at.y.isFinite && ant.forward.x.isFinite && at.x > -1 && at.x < Double(cols) + 1 && at.y > -1 && at.y < Double(rows) + 1) { lost += 1 }
                    if !colony.clear(at, ant.forward, middle: true) { buried += 1 }
                }
            }
        }
        tally.withLock { $0 = ($0.nests + 1, $0.moments + moments, $0.buried + buried, $0.lost + lost, min($0.mouths, nest.entrances.count)) }
    }
    let all = tally.withLock { $0 }
    print("Ant Colony, \(all.nests) nests on \(grids.count) grids in \(clock.now - began): \(all.moments) ant-moments, \(all.buried) with a middle in the medium, \(all.lost) off the tank or nowhere; fewest mouths \(all.mouths)")
    #expect(all.nests == 36 && all.moments > 400_000 && all.buried == 0 && all.lost == 0 && all.mouths >= 1)
}

/// The picture is the same whatever the frame rate: drawn at 15, 30 and 60 frames a second, every pixel is the
/// same four seconds into the farm of one day at nine in the morning, ants and all; a second scene given the same
/// day and hour shows the same nest; and nine hours on there is more of it. The same again in white sand with the
/// smallest ants, twice as many of them, at the top speed. And each of the five looks is its own: the gels blue
/// and one brighter, the sand warm, the white sand paler, the earth brown. And the copy Settings runs behind its page opens on a nest worth judging its settings by.
@MainActor @Test func antColonyLooksTheSameAtAnyFrameRate() throws {
    let keys = ["antcolony.day", "antcolony.hour", "antcolony.look", "antcolony.size", "antcolony.ants", "antcolony.speed"]
    defer { keys.forEach(UserDefaults.standard.removeObject) }
    UserDefaults.standard.set(20261012.0, forKey: "antcolony.day")
    let device = try #require(MTLCreateSystemDefaultDevice()), queue = try #require(device.makeCommandQueue())
    let (w, h) = (1512, 982)
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    func picture(hour: Double, rate: Double, headStart: Bool = false, then change: (() -> Void)? = nil, for more: Double = 0) throws -> [UInt32] {
        UserDefaults.standard.set(hour, forKey: "antcolony.hour")
        let renderer = SKRenderer(device: device), target = try #require(device.makeTexture(descriptor: descriptor)), pass = MTLRenderPassDescriptor()
        let scene = AntColony(size: CGSize(width: w / 2, height: h / 2))
        if headStart { scene.headStart() }
        renderer.scene = scene
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        let start = ProcessInfo.processInfo.systemUptime + 1 // the renderer's first update runs on the system's clock
        for frame in 0...Int(4 * rate) { renderer.update(atTime: start + Double(frame) / rate) }
        change?()
        for frame in 0..<Int(more * rate) { renderer.update(atTime: start + 4 + Double(frame + 1) / rate) }
        for _ in 0..<2 { // with no more time gone by, and twice for the shader's sake
            renderer.update(atTime: start + 4 + more)
            let buffer = try #require(queue.makeCommandBuffer())
            renderer.render(withViewport: CGRect(x: 0, y: 0, width: w, height: h), commandBuffer: buffer, renderPassDescriptor: pass)
            buffer.commit()
            buffer.waitUntilCompleted()
        }
        var raw = [UInt32](repeating: 0, count: w * h)
        target.getBytes(&raw, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
        return raw
    }
    let pictures = try [15.0, 30.0, 60.0].map { try picture(hour: 3, rate: $0) }
    #expect(pictures[1] == pictures[0], "the picture at 30 frames a second is not the one at 15")
    #expect(pictures[2] == pictures[0], "the picture at 60 frames a second is not the one at 15")
    // An ant is the darkest thing below the top of the gel; and in sand a tunnel is the grey of the pane behind it,
    // where the sand is warm.
    func count(_ picture: [UInt32], _ wanted: (Int, Int, Int) -> Bool) -> Int {
        picture[(w * h / 4)...].count { wanted(Int($0 >> 16 & 255), Int($0 >> 8 & 255), Int($0 & 255)) }
    }
    let ants = count(pictures[0]) { r, g, b in r < 30 && g < 30 && b < 40 }
    UserDefaults.standard.set(3.0, forKey: "antcolony.look")
    let sand = try [3.0, 12].map { try picture(hour: $0, rate: 30) }, tunnels = sand.map { count($0) { r, g, b in abs(r - b) <= 3 && r > 30 } }
    print("Ant Colony at nine in the morning: \(ants) pixels of ant below the top of the gel; \(tunnels[0]) pixels of tunnel in sand, and at six in the evening \(tunnels[1])")
    #expect(ants > 150 && tunnels[0] > 20000 && Double(tunnels[1]) > 1.8 * Double(tunnels[0]))
    // Settings' own copy, made ten minutes into a farm, shows the middle of its day; one made at noon is left as it is.
    let young = try [false, true].map { count(try picture(hour: 0.17, rate: 30, headStart: $0)) { r, g, b in abs(r - b) <= 3 && r > 30 } }
    let noon = try [false, true].map { try picture(hour: 6, rate: 30, headStart: $0) }
    print("Ant Colony ten minutes into a farm: \(young[0]) pixels of tunnel on the desktop, \(young[1]) behind its Settings page")
    #expect(young[0] < 6000 && young[1] > 80000 && noon[0] == noon[1])

    // Speed never moves the dig: the frame after it goes from 1 to 8, or from 8 to 1, there is as much tunnel as the
    // frame before (to a five-hundredth); a minute on at 8 there is more.
    func speed(_ value: Double) { UserDefaults.standard.set(value, forKey: "antcolony.speed") }
    func tunnel(_ picture: [UInt32]) -> Double { Double(count(picture) { r, g, b in abs(r - b) <= 3 && r > 30 }) }
    let slow = tunnel(sand[0]), up = tunnel(try picture(hour: 3, rate: 30, then: { speed(8) }, for: 1.0 / 30)), on = tunnel(try picture(hour: 3, rate: 30, then: { speed(8) }, for: 60))
    let fast = tunnel(try picture(hour: 3, rate: 30)), down = tunnel(try picture(hour: 3, rate: 30, then: { speed(1) }, for: 1.0 / 30))
    speed(1)
    print("Ant Colony, tunnel in white sand at nine: \(slow) pixels at Speed 1, \(up) the frame after Speed goes to 8, \(on) a minute on; \(fast) at Speed 8, \(down) the frame after it goes back to 1")
    #expect(abs(up - slow) < 0.002 * slow && on > 1.02 * slow && abs(down - fast) < 0.002 * fast)

    func mean(_ picture: [UInt32]) -> SIMD3<Double> {
        picture[(w * h / 4)...].reduce(into: SIMD3<Double>()) { $0 += SIMD3(Double($1 >> 16 & 255), Double($1 >> 8 & 255), Double($1 & 255)) } / Double(w * h * 3 / 4)
    }
    // The five looks, by their places in the menu: Gel, Bright Gel, Sand, White Sand, Earth.
    let looks = try (0...4).map { look -> SIMD3<Double> in
        UserDefaults.standard.set(Double(look), forKey: "antcolony.look")
        return mean(try picture(hour: 3, rate: 30))
    }
    print("Ant Colony below the top of the tank, mean red, green and blue: gel \(looks[0]), bright gel \(looks[1]), sand \(looks[2]), white sand \(looks[3]), earth \(looks[4])")
    #expect(looks[0].z > 2 * looks[0].x && looks[1].z > 1.1 * looks[0].z, "the gels are not blue, or the bright one no brighter")
    #expect(looks[2].x > 1.15 * looks[2].z && looks[2].x > 70 && looks[3].x > 1.3 * looks[2].x, "the sand is not warm, or the white sand no whiter")
    #expect(looks[4].x > 1.4 * looks[4].z && looks[4].x / looks[4].z > looks[2].x / looks[2].z, "the earth is not brown, or no browner than sand")
    for (key, value) in [("antcolony.look", 3.0), ("antcolony.size", 0), ("antcolony.ants", 2), ("antcolony.speed", 8)] { UserDefaults.standard.set(value, forKey: key) }
    let white = try [15.0, 60.0].map { try picture(hour: 3, rate: $0) }
    #expect(white[1] == white[0], "white sand with small ants at speed 8: the picture at 60 frames a second is not the one at 15")
}
