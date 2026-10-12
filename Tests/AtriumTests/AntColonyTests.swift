import Foundation
import Metal
import SpriteKit
import Testing
@testable import AntNest
@testable import Atrium

/// A date and a time give one nest. The same seed bakes the same map twice and another seed another; the map's
/// rank is what it says, the share of the digging done when a cell goes, so the dug area grows as the clock's
/// share does; a young colony works one or two faces and a grown one eight, from one mouth at first; and the
/// clock is the day Dave picked: a farm begins at six, has 8% dug by seven, 23% by nine, 44% at noon, 75% at six in
/// the evening and 94% at midnight, and the moment before six belongs to the farm of the day before; and with
/// Speed at 4 there are four farms to the day, one after another.
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
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "America/Chicago"))
    func farm(_ day: Int, _ hour: Int, _ minute: Int, speed: Double = 1) throws -> (day: Int, turn: Int, hours: Double) {
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)))
        return AntColony.farm(at: date.timeIntervalSinceReferenceDate, speed: speed, calendar: calendar)
    }
    let (before, at, late) = (try farm(12, 5, 59), try farm(12, 6, 0), try farm(13, 0, 0))
    #expect(before.day == 20261011 && abs(before.hours - 23.0 - 59.0 / 60) < 1e-6 && at.day == 20261012 && at.hours == 0 && late.day == 20261012 && late.hours == 18)
    #expect(before.turn == 0 && at.turn == 0 && late.turn == 0)
    // At four farms a day the day's second begins at noon, and at 13:30 is a quarter of its way through its own day.
    let (noon, after, last) = (try farm(12, 12, 0, speed: 4), try farm(12, 13, 30, speed: 4), try farm(13, 5, 59, speed: 4))
    #expect(noon.day == 20261012 && noon.turn == 1 && noon.hours == 0 && after.turn == 1 && after.hours == 6 && last.day == 20261012 && last.turn == 3)
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

/// The picture is the same whatever the frame rate: drawn at 15, 30 and 60 frames a second, every pixel is the
/// same four seconds into the farm of one day at nine in the morning, ants and all; a second scene given the same
/// day and hour shows the same nest; and nine hours on there is more of it. The same again in white sand with the
/// smallest ants, twice as many of them, at the top speed. And each look is its own: the gel blue, the sand pale,
/// the white sand paler.
@MainActor @Test func antColonyLooksTheSameAtAnyFrameRate() throws {
    let keys = ["antcolony.day", "antcolony.hour", "antcolony.look", "antcolony.size", "antcolony.ants", "antcolony.speed"]
    defer { keys.forEach(UserDefaults.standard.removeObject) }
    UserDefaults.standard.set(20261012.0, forKey: "antcolony.day")
    let device = try #require(MTLCreateSystemDefaultDevice()), queue = try #require(device.makeCommandQueue())
    let (w, h) = (1512, 982)
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    func picture(hour: Double, rate: Double) throws -> [UInt32] {
        UserDefaults.standard.set(hour, forKey: "antcolony.hour")
        let renderer = SKRenderer(device: device), target = try #require(device.makeTexture(descriptor: descriptor)), pass = MTLRenderPassDescriptor()
        renderer.scene = AntColony(size: CGSize(width: w / 2, height: h / 2))
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        let start = ProcessInfo.processInfo.systemUptime + 1 // the renderer's first update runs on the system's clock
        for frame in 0...Int(4 * rate) { renderer.update(atTime: start + Double(frame) / rate) }
        for _ in 0..<2 { // with no more time gone by, and twice for the shader's sake
            renderer.update(atTime: start + 4)
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
    UserDefaults.standard.set(1.0, forKey: "antcolony.look")
    let sand = try [3.0, 12].map { try picture(hour: $0, rate: 30) }, tunnels = sand.map { count($0) { r, g, b in abs(r - b) <= 3 && r > 30 } }
    print("Ant Colony at nine in the morning: \(ants) pixels of ant below the top of the gel; \(tunnels[0]) pixels of tunnel in sand, and at six in the evening \(tunnels[1])")
    #expect(ants > 150 && tunnels[0] > 20000 && Double(tunnels[1]) > 1.8 * Double(tunnels[0]))

    func mean(_ picture: [UInt32]) -> SIMD3<Double> {
        picture[(w * h / 4)...].reduce(into: SIMD3<Double>()) { $0 += SIMD3(Double($1 >> 16 & 255), Double($1 >> 8 & 255), Double($1 & 255)) } / Double(w * h * 3 / 4)
    }
    let dim = mean(sand[0])
    for (key, value) in [("antcolony.look", 2.0), ("antcolony.size", 0), ("antcolony.ants", 2), ("antcolony.speed", 8)] { UserDefaults.standard.set(value, forKey: key) }
    let white = try [15.0, 60.0].map { try picture(hour: 3, rate: $0) }, blue = mean(pictures[0]), bright = mean(white[0])
    #expect(white[1] == white[0], "white sand with small ants at speed 8: the picture at 60 frames a second is not the one at 15")
    print("Ant Colony below the top of the tank, mean red, green and blue: gel \(blue), sand \(dim), white sand \(bright)")
    #expect(blue.z > 2 * blue.x && dim.x > dim.z && dim.x > 80 && bright.x > 1.3 * dim.x)
}
