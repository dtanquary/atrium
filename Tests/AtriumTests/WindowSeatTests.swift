import SpriteKit
import Testing
@testable import Atrium

/// "Randomly cycles between water, city and countryside": along the track, each gets a fair share of the view, and
/// no kind of country goes on so long that the wallpaper seems stuck on it.
@Test func windowSeatCyclesScenery() {
    let world = SeatWorld()
    var shares = [0, 0, 0], runs: [[Int]] = [[], [], []], last = world.biome(0, 30), run = 0
    for km in 0..<40_000 {
        let biome = world.biome(Double(km), 30) // 30 km out: the middle of the near ground
        shares[biome] += 1
        if biome == last { run += 1 } else { runs[last].append(run); (last, run) = (biome, 1) }
    }
    for (biome, name) in ["ocean", "city", "countryside"].enumerated() {
        let lengths = runs[biome].sorted()
        #expect(shares[biome] > 8000, "\(name) is only \(shares[biome] / 400)% of the track")
        // At the standard 3× that's 45 km a minute: nine stretches in ten are over within nine minutes.
        #expect(lengths[lengths.count * 9 / 10] < 400, "\(name) often runs on for \(lengths[lengths.count * 9 / 10]) km")
    }
}

/// Every display gets a scene its own size, and Settings' preview a small one: each must build, fly on and paint.
@MainActor @Test func windowSeatFliesAtAnySize() {
    for size in [CGSize(width: 1512, height: 982), CGSize(width: 1080, height: 1920), CGSize(width: 3440, height: 1440), CGSize(width: 300, height: 120), CGSize(width: 40, height: 30)] {
        let scene = PixelWindowSeat(size: size), start = PixelWindowSeat.flown
        for frame in 0...60 { scene.update(1000 + Double(frame) / 30) }
        #expect(PixelWindowSeat.flown - start > 1, "after two seconds at \(size) it has flown \(PixelWindowSeat.flown - start) km")
    }
}
