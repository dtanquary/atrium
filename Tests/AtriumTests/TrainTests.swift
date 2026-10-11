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

/// Writes what the world lays at the mock-ups' own lens and places, for docs/pixel-window-seat/train_match.py to
/// set against the mock-ups' painter byte for byte:
///
///     TRAIN_MATCH=/some/folder swift test --filter trainWritesItsCountry
///     python3 docs/pixel-window-seat/train_match.py /some/folder
@Test(.enabled(if: ProcessInfo.processInfo.environment["TRAIN_MATCH"] != nil)) func trainWritesItsCountry() throws {
    let folder = URL(fileURLWithPath: ProcessInfo.processInfo.environment["TRAIN_MATCH"]!)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let world = TrainWorld(focal: 265, eye: 3.5, speed: 13.3), wide = 340, ground = 66 // the Large pane, its horizon 30% up
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
    }
}
