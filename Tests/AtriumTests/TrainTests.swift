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

/// What keeps it calm at any speed: no lamp is laid on a ring that slides faster than `TrainWorld.bright` pixels a
/// second, none of the lane's poles on one faster than `thin`, and nothing that stands (a tree, a house) on one
/// faster than `broad`.
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
                if pace > TrainWorld.bright { #expect(!lit, "at \(times)× the ring \(TrainWorld.rings[ring]) m off slides \(pace) px/s and holds a lamp") }
                if pace > TrainWorld.thin { #expect(!pole, "at \(times)× the ring \(TrainWorld.rings[ring]) m off slides \(pace) px/s and holds a pole") }
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

/// No lamp jumps more than its own width between frames: at 30 frames a second and at 60, at any Speed, a ring slow
/// enough to hold lamps moves on by one pixel at most from one frame to the next.
@MainActor @Test func trainLampsMoveAPixelAtATime() {
    defer { UserDefaults.standard.removeObject(forKey: PixelWindowSeat.speed.key) }
    var most = 0
    for (k, (times, rate)) in [(0.5, 30.0), (1, 30), (1, 60), (1.5, 30), (2, 30), (4, 30), (10, 30)].enumerated() {
        UserDefaults.standard.set(times, forKey: PixelWindowSeat.speed.key)
        let scene = PixelTrain(size: CGSize(width: 1512, height: 982)), from = 4000 + Double(k) * 100
        scene.update(from)
        scene.update(from + 1 / rate)
        var last = scene.rings.map(\.first)
        for frame in 2...Int(rate * 3) {
            scene.update(from + Double(frame) / rate)
            for (ring, was) in zip(scene.rings, last) where ring.perMetre * PixelTrain.pace * times <= TrainWorld.bright {
                most = max(most, ring.first - was)
                #expect(ring.first - was <= 1, "at \(times)× and \(rate) frames a second the ring \(ring.away) m off, which can hold lamps, moved \(ring.first - was) px in a frame")
            }
            last = scene.rings.map(\.first)
        }
    }
    #expect(most == 1)
}

/// The same picture whatever the frame rate: after the same time from the same place, a scene stepped 15, 30 and
/// 60 times a second has painted the same pixels. Through countryside, and beside a lake, whose water goes by the
/// scene's clock.
@MainActor @Test func trainLooksTheSameAtAnyFrameRate() {
    let keys = [PixelWindowSeat.previewTime.key, PixelWindowSeat.previewHour.key, PixelTrain.scenery.key]
    defer { for key in keys { UserDefaults.standard.removeObject(forKey: key) } }
    for scenery in [1.0, 2] {
        for (key, value) in zip(keys, [1, 13, scenery]) { UserDefaults.standard.set(value, forKey: key) }
        var pictures: [[UInt32]] = []
        // (From an odd metre: 2.2 s at 1× is 29⅓ m, and from a whole one three rows of ground would end exactly on
        // a pixel's edge, where the last bit of a sum decides which side they fall.)
        let start = 52_000.37
        for (k, rate) in [15.0, 30, 60].enumerated() {
            PixelTrain.travelled = start
            let scene = PixelTrain(size: CGSize(width: 1512, height: 982)), from = 7000 + scenery * 1000 + Double(k) * 100
            scene.update(from) // the first frame only sets the clocks
            PixelTrain.travelled = start
            for frame in 1...Int(rate * 2.2) { scene.update(from + Double(frame) / rate) }
            pictures.append(scene.picture)
        }
        let differ = zip(pictures[0], pictures[2]).count { $0 != $1 } + zip(pictures[1], pictures[2]).count { $0 != $1 }
        #expect(differ == 0, "after 2.2 s, \(differ) pixels of the picture differ between 15, 30 and 60 frames a second")
    }
}

/// Moving the Speed slider lays nothing again: at the moment it moves the picture stays as it was, pole line
/// and all, though at 3× the line and the nearest trees are too fast to be laid. Only what comes into view from
/// then on goes by the new speed.
@MainActor @Test func trainKeepsItsCountryAsTheSpeedChanges() {
    let keys = [PixelWindowSeat.previewTime.key, PixelWindowSeat.previewHour.key, PixelTrain.scenery.key, PixelWindowSeat.speed.key]
    defer { for key in keys { UserDefaults.standard.removeObject(forKey: key) } }
    for (key, value) in zip(keys, [1, 13, 1, 1.0]) { UserDefaults.standard.set(value, forKey: key) }
    PixelTrain.travelled = 52_000
    let scene = PixelTrain(size: CGSize(width: 1512, height: 982))
    scene.update(6000)
    scene.update(6000 + 1 / 30.0)
    let before = scene.picture
    for speed in [3.0, 10, 0.5, 1] {
        UserDefaults.standard.set(speed, forKey: PixelWindowSeat.speed.key)
        #expect(scene.picture == before, "at \(speed)× \(zip(scene.picture, before).count { $0 != $1 }) pixels changed as the slider moved")
    }
    // Then, at 3×, the nearest ring empties from its leading edge as it slides, and no tree is left half laid: its
    // trees and firs come whole or not at all, so every column of the ring is either empty or as 1× would lay it.
    UserDefaults.standard.set(3.0, forKey: PixelWindowSeat.speed.key)
    for frame in 2...40 { scene.update(6000 + Double(frame) / 30) }
    #expect(scene.picture != before)
}

/// Films the train for docs/pixel-window-seat/train_strips.py: steps a scene at a frame rate and writes each frame
/// as the pane's own art pixels. No GPU, and nothing on screen.
///
///     TRAIN_FILM=/some/folder/name.bin TRAIN_FILM_FPS=15 TRAIN_FILM_SECONDS=6 TRAIN_FILM_AT=52000 \
///       TRAIN_FILM_DEFAULTS="seat.previewTime=1,seat.previewHour=23,seat.country=2,seat.speed=2" swift test --filter trainFilmsItself
///     TRAIN_FILM_SIZE=1080x1920 …   # a display of another size, in points (a 14-inch laptop's if not given)
///     TRAIN_FILM_THEN="seat.speed=3@2" …   # and a setting moved part way through, here the Speed slider after 2 s
@MainActor @Test(.enabled(if: ProcessInfo.processInfo.environment["TRAIN_FILM"] != nil)) func trainFilmsItself() throws {
    let env = ProcessInfo.processInfo.environment
    let settings = (env["TRAIN_FILM_DEFAULTS"] ?? "").split(separator: ",").map { $0.split(separator: "=") }.filter { $0.count == 2 }
    for pair in settings { UserDefaults.standard.set(Double(pair[1]) ?? 0, forKey: String(pair[0])) }
    defer { for pair in settings { UserDefaults.standard.removeObject(forKey: String(pair[0])) } }
    let rate = Double(env["TRAIN_FILM_FPS"] ?? "") ?? 30, frames = Int(rate * (Double(env["TRAIN_FILM_SECONDS"] ?? "") ?? 4))
    let start = Double(env["TRAIN_FILM_AT"] ?? "") ?? 52_000
    PixelTrain.travelled = start
    let size = (env["TRAIN_FILM_SIZE"] ?? "1512x982").split(separator: "x").compactMap { Double($0) }
    let scene = PixelTrain(size: CGSize(width: size[0], height: size[1]))
    scene.update(9000) // the first frame only sets the clocks
    PixelTrain.travelled = start
    var film = Data("\(scene.pane.w) \(scene.pane.h) \(frames) \(rate)\n".utf8)
    let then = (env["TRAIN_FILM_THEN"] ?? "").split(whereSeparator: { "=@".contains($0) })
    defer { if then.count == 3 { UserDefaults.standard.removeObject(forKey: String(then[0])) } }
    for frame in 1...frames {
        if then.count == 3, frame == Int(rate * (Double(then[2]) ?? 0)) { UserDefaults.standard.set(Double(then[1]) ?? 0, forKey: String(then[0])) }
        scene.update(9000 + Double(frame) / rate)
        scene.picture.withUnsafeBytes { film.append(contentsOf: $0) }
    }
    try film.write(to: URL(fileURLWithPath: env["TRAIN_FILM"]!))
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

/// Writes the carriage as it is painted, for docs/pixel-window-seat/train_match.py to set against the mock-ups'
/// painter and the saved sheets, byte for byte (the same two commands as `trainWritesItsCountry`). On a laptop's
/// canvas, the mock-ups' own, at their four hours: with the pane where they had it, 12 rows from the top, and where
/// the app puts it, a row lower.
@MainActor @Test(.enabled(if: ProcessInfo.processInfo.environment["TRAIN_MATCH"] != nil)) func trainWritesItsCarriage() throws {
    let folder = URL(fileURLWithPath: ProcessInfo.processInfo.environment["TRAIN_MATCH"]!)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let (w, h, glass, _) = PixelWindowSeat.pane(CGSize(width: 1512, height: 982))
    #expect((w, h) == (378, 246) && glass == (19, 12, 340, 221), "the Large window on a laptop is the mock-ups' pane, a row lower")
    for top in [12, h - glass.y - glass.h] {
        let carriage = PixelCarriage(w: w, h: h, glass: (glass.x, h - top - glass.h, glass.w, glass.h))
        for (hour, dim) in [("day", PixelCarriage.light(0)), ("sunset", 0.62), ("dusk", 0.34), ("night", PixelCarriage.light(1))] {
            try Data(carriage.picture(dim: dim)).write(to: folder.appendingPathComponent("carriage-plain-\(hour)-\(top).bin"))
        }
    }
}
