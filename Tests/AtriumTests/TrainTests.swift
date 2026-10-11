import SpriteKit
import Testing
@testable import Atrium

/// Every display gets a scene its own size, with a window of any size or none: each must build, run on and paint.
@MainActor @Test func trainRunsAtAnySize() {
    defer { UserDefaults.standard.removeObject(forKey: PixelWindowSeat.window.key) }
    for window in 0...3 {
        UserDefaults.standard.set(Double(window), forKey: PixelWindowSeat.window.key)
        for size in [CGSize(width: 1512, height: 982), CGSize(width: 1080, height: 1920), CGSize(width: 3440, height: 1440), CGSize(width: 300, height: 120), CGSize(width: 40, height: 30)] {
            let scene = PixelTrain(size: size), start = PixelTrain.travelled
            for frame in 0...60 { scene.update(1000 + Double(frame) / 30) }
            #expect(PixelTrain.travelled - start > 25, "after two seconds at \(size) it has gone \(PixelTrain.travelled - start) m")
        }
    }
}

/// A thing Z metres from the track slides focal × speed / Z pixels a second, whatever its height: over two seconds
/// every ring moves on by that, to the pixel.
@MainActor @Test func trainSlidesByDistance() {
    let scene = PixelTrain(size: CGSize(width: 1512, height: 982))
    scene.update(3000) // the first frame only sets the clocks, and the second brings every ring up to them
    scene.update(3000 + 1 / 30.0)
    let before = scene.rings.map(\.first)
    for frame in 2...61 { scene.update(3000 + Double(frame) / 30) }
    for (ring, was) in zip(scene.rings, before) {
        let moved = ring.first - was, due = ring.perMetre * PixelTrain.pace * 2
        print(String(format: "train slide: the ring %.0f m off moved %d px in 2 s; focal × speed / Z × 2 is %.2f", ring.away, moved, due))
        #expect(abs(Double(moved) - due) <= 1, "the ring \(ring.away) m off moved \(moved) px in two seconds, not \(due)")
    }
}

/// What keeps it calm at any speed: nothing thin (a lamp, the lane's poles) is laid on a ring that slides faster
/// than `TrainWorld.thin` pixels a second, and nothing that stands (a tree, a house) on one faster than `broad`.
@Test func trainNothingThinIsFast() {
    var standing = 0, lamps = 0
    for times in [0.5, 1, 1.5, 2, 3, 4, 6, 8, 10] {
        let world = TrainWorld(focal: 265.2, eye: 3.5, speed: PixelTrain.pace * times)
        for ring in 3..<TrainWorld.rings.count {
            let rows = world.rows(ring), pace = world.perMetre(ring) * world.speed
            var column = [UInt8](repeating: 0, count: rows)
            for n in stride(from: 100_000, to: 106_000, by: 1) {
                _ = column.withUnsafeMutableBufferPointer { world.column(ring, n, into: $0.baseAddress!) }
                let lit = column.contains { $0 > 127 }, pole = column.contains { $0 & 127 == TrainMat.pole }
                let stands = column.contains { [TrainMat.trunk, TrainMat.fir0, TrainMat.fir1, TrainMat.glass, TrainMat.white, TrainMat.brick, TrainMat.roof].contains($0 & 127) }
                (standing, lamps) = (standing + (stands ? 1 : 0), lamps + (lit ? 1 : 0))
                if pace > TrainWorld.thin { #expect(!lit && !pole, "at \(times)× the ring \(TrainWorld.rings[ring]) m off slides \(pace) px/s and holds a lamp or a pole") }
                if pace > TrainWorld.broad { #expect(!stands, "at \(times)× the ring \(TrainWorld.rings[ring]) m off slides \(pace) px/s and has something standing on it") }
            }
        }
    }
    #expect(standing > 1000 && lamps > 100, "the test saw \(standing) columns with something standing and \(lamps) with a lamp")
}

/// The night must never be a black pane: along an hour of track, every minute's view has lamps in it, as the
/// painter shows it, with what stands in front hiding what is behind. Through countryside, and beside a lake.
@MainActor @Test func trainNightIsNeverBlack() {
    let keys = [PixelWindowSeat.previewTime.key, PixelWindowSeat.previewHour.key, PixelTrain.scenery.key]
    defer { for key in keys { UserDefaults.standard.removeObject(forKey: key) } }
    for (scenery, name) in [(1.0, "countryside"), (2, "a lake")] {
        for (key, value) in zip(keys, [1, 23, scenery]) { UserDefaults.standard.set(value, forKey: key) }
        let scene = PixelTrain(size: CGSize(width: 1512, height: 982))
        var seen: [Int] = []
        for minute in 0...60 {
            PixelTrain.travelled = 52_000 + Double(minute) * PixelTrain.pace * 60
            scene.update(5000 + Double(minute))
            if minute > 0 { seen.append(scene.lit) } // (the first frame only sets the clocks)
        }
        print("train night, \(name): lamp pixels in view, a minute apart: \(seen)")
        #expect(seen.allSatisfy { $0 > 0 }, "through \(name), \(seen.count { $0 == 0 }) of an hour's minutes have no lamp in view")
    }
}

/// Left to change, the country has lakes beside the line for a fair share of it, and neither they nor the country
/// between go on so long that the wallpaper seems stuck: at 1× the train covers 800 m a minute.
@Test func trainPassesLakes() {
    let world = TrainWorld(focal: 265.2, eye: 3.5, speed: PixelTrain.pace)
    var beside = 0, runs: [Bool: [Int]] = [true: [], false: []], last = false, run = 0
    for step in 0..<20_000 { // 2,000 km, a sample every 100 m
        let lake = world.shore(Double(step) * 100) < 20
        beside += lake ? 1 : 0
        if lake == last { run += 1 } else { runs[last]!.append(run); (last, run) = (lake, 1) }
    }
    let lakes = runs[true]!.sorted(), country = runs[false]!.sorted()
    print("train lakes: beside \(beside / 200)% of the line; a lake is \(lakes[lakes.count / 2] / 10) km at the median and \(lakes[lakes.count * 9 / 10] / 10) at the ninetieth percentile; the country between \(country[country.count / 2] / 10) and \(country[country.count * 9 / 10] / 10)")
    #expect(beside > 3000 && beside < 9000, "a lake lies beside \(beside / 200)% of the line")
    #expect(lakes[lakes.count * 9 / 10] < 200 && country[country.count * 9 / 10] < 400, "a stretch often runs on too long")
}

/// Writes what the world lays at the mock-ups' own lens and places, for docs/pixel-window-seat/train_match.py to
/// set against the mock-ups' painter byte for byte:
///
///     TRAIN_MATCH=/some/folder swift test --filter trainWritesItsCountry
///     python3 docs/pixel-window-seat/train_match.py /some/folder
@Test(.enabled(if: ProcessInfo.processInfo.environment["TRAIN_MATCH"] != nil)) func trainWritesItsCountry() throws {
    let folder = URL(fileURLWithPath: ProcessInfo.processInfo.environment["TRAIN_MATCH"]!)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    var world = TrainWorld(focal: 265, eye: 3.5, speed: 13.3) // the Large pane, its horizon 30% up
    world.scenery = 1 // countryside, as the sheets' was
    let wide = 340, ground = 66
    for x in [52000.0, 52137.25, 3.0, 1_234_567.5] {
        for ring in TrainWorld.rings.indices {
            let rows = world.rows(ring), first = Int((x * world.perMetre(ring)).rounded(.down)) - wide / 2
            var strip = [UInt8](repeating: 0, count: rows * wide), column = [UInt8](repeating: 0, count: rows)
            for i in 0..<wide {
                let top = Int(column.withUnsafeMutableBufferPointer { world.column(ring, first + i, into: $0.baseAddress!) })
                #expect(column[top...].allSatisfy { $0 == 0 }, "column \(first + i) of the ring \(TrainWorld.rings[ring]) m off stands above its top")
                for up in 0..<rows { strip[up * wide + i] = column[up] }
            }
            try Data(strip).write(to: folder.appendingPathComponent("ring-\(Int(TrainWorld.rings[ring]))-\(x).bin"))
        }
        var rows = [UInt8](repeating: 0, count: 2 * ground * wide) // the materials, then the dashes' tones
        for d in 1...ground {
            let first = Int((x * (Double(d) / world.eye)).rounded(.down)) - wide / 2
            for i in 0..<wide { (rows[(d - 1) * wide + i], rows[(ground + d - 1) * wide + i]) = world.ground(d, first + i) }
        }
        try Data(rows).write(to: folder.appendingPathComponent("ground-\(x).bin"))
        var line = [UInt8](repeating: 0, count: wide * 221) // the pole line: 1 for a wire, 2 for a pole, rows from the bottom
        world.poleLine(at: x, wide: wide, high: 221, horizon: ground) { line[$1 * wide + $0] = $2 ? 2 : max(line[$1 * wide + $0], 1) }
        try Data(line).write(to: folder.appendingPathComponent("poles-\(x).bin"))
    }
}
