import SpriteKit
import Testing
@testable import Atrium

/// "Randomly cycles between" its kinds of country: along the track each gets a fair share of the view, and none
/// goes on so long that the wallpaper seems stuck on it.
@Test func windowSeatCyclesScenery() {
    let world = SeatWorld()
    var shares = [Int](repeating: 0, count: 6), runs = [[Int]](repeating: [], count: 6), last = world.biome(0, 30), run = 0
    for km in 0..<40_000 {
        let biome = world.biome(Double(km), 30) // 30 km out: the middle of the near ground
        shares[biome] += 1
        if biome == last { run += 1 } else { runs[last].append(run); (last, run) = (biome, 1) }
    }
    // Ocean, city and countryside are what Dave first asked for; mountains, desert and snow came after.
    for (biome, (name, least)) in [("ocean", 15), ("city", 15), ("countryside", 10), ("mountains", 8), ("desert", 4), ("snow", 4)].enumerated() {
        let lengths = runs[biome].sorted()
        #expect(shares[biome] > least * 400, "\(name) is only \(shares[biome] / 400)% of the track")
        // At the standard 3× that's 45 km a minute: nine stretches in ten are over within nine minutes.
        #expect(lengths[lengths.count * 9 / 10] < 400, "\(name) often runs on for \(lengths[lengths.count * 9 / 10]) km")
    }
}

/// Every display gets a scene its own size, and Settings' preview a small one, with a window of any size or none:
/// each must build, fly on and paint.
@MainActor @Test func windowSeatFliesAtAnySize() {
    defer { UserDefaults.standard.removeObject(forKey: PixelWindowSeat.window.key) }
    for window in 0...3 {
        UserDefaults.standard.set(Double(window), forKey: PixelWindowSeat.window.key)
        for size in [CGSize(width: 1512, height: 982), CGSize(width: 1080, height: 1920), CGSize(width: 3440, height: 1440), CGSize(width: 300, height: 120), CGSize(width: 40, height: 30)] {
            let scene = PixelWindowSeat(size: size), start = PixelWindowSeat.flown
            for frame in 0...60 { scene.update(1000 + Double(frame) / 30) }
            #expect(PixelWindowSeat.flown - start > 1, "after two seconds at \(size) it has flown \(PixelWindowSeat.flown - start) km")
        }
    }
}

/// Lightning has to stay a far-off flicker: each storm dark nearly all the time, yet never dark for good.
@Test func windowSeatLightningIsRare() {
    for storm in 0..<16 {
        let lit = (0..<9000).filter { SeatWorld.lightning(storm, at: Double($0) / 30) > 0 }.count // five minutes, 30 times a second
        #expect(lit > 20 && lit < 900, "storm \(storm) is lit \(lit * 100 / 9000)% of the time")
    }
}
