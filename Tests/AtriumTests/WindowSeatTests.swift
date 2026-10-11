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
        // At the standard 1× that's 15 km a minute: nine stretches in ten are over within 27 minutes.
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
            #expect(PixelWindowSeat.flown - start > 0.4, "after two seconds at \(size) it has flown \(PixelWindowSeat.flown - start) km")
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

/// The rows Settings lists for a stored `seat.orbit`, by key, with every other switch as it comes.
private func listed(_ knobs: [Knob], window: Double) -> [String] {
    func held(_ key: String?) -> Double { key == PixelOrbit.on.key ? window : knobs.first { $0.key == key }?.standard ?? 0 }
    return knobs.filter { $0.shows(gate: held($0.shownWhen), hide: held($0.hiddenWhen)) }.map(\.key)
}

/// Until the train is ready to be seen, the page is the one people have: the Earth orbit switch, and under it the
/// airliner's rows or the station's. With `unfinished` set the switch is a menu of three under the same key, so a
/// stored 1 is still the station, and the train lists the rows it shares with the airliner.
@MainActor @Test func windowSeatOffersTheTrainOnlyUnfinished() {
    let shipped = PixelWindowSeat.rows(train: false), offered = PixelWindowSeat.rows(train: true)
    let airliner = ["seat.orbit", "seat.wing", "seat.window", "seat.looking", "seat.speed", "seat.scenery", "seat.clouds", "seat.lightning", "seat.previewTime"]
    let station = ["seat.orbit", "seat.array", "seat.window", "seat.orbitLooking", "seat.speed", "seat.follow", "seat.clouds", "seat.realClouds", "seat.lightning"]
    #expect(shipped[0].label == "Earth orbit" && shipped[0].format == .toggle && shipped[0].range == 0...1)
    #expect(listed(shipped, window: 0) == airliner)
    #expect(listed(shipped, window: 1) == station)
    #expect(offered[0].format == .choice(["An airliner", "The space station", "A train"]) && offered[0].order == [0, 2, 1])
    #expect(listed(offered, window: 0) == airliner)
    #expect(listed(offered, window: 1) == station)
    #expect(listed(offered, window: 2) == airliner.filter { $0 != "seat.wing" })
    #expect(zip(shipped, offered).dropFirst().allSatisfy { $0.key == $1.key && $0.label == $1.label && $0.format == $1.format })

    // What is stored: 1 is the station either way, and 2 the train only where the train is offered.
    let key = PixelOrbit.on.key, size = CGSize(width: 1512, height: 982)
    defer { UserDefaults.standard.removeObject(forKey: key) }
    for (stored, switched, picked) in [(0.0, 0.0, 0.0), (1, 1, 1), (2, 1, 2)] {
        UserDefaults.standard.set(stored, forKey: key)
        #expect(shipped[0].value == switched && offered[0].value == picked)
        #expect(pixelWindowSeat(size: size) is PixelOrbit == (PixelOrbit.mode == 1), "a stored \(stored) opened the wrong window")
    }
    UserDefaults.standard.set(1.0, forKey: key)
    #expect(pixelWindowSeat(size: size) is PixelOrbit)
    // The slider that Follow the real ISS holds is held only while the station is the window.
    #expect(Knob.on(1, at: PixelOrbit.follow.shownAt) && !Knob.on(2, at: PixelOrbit.follow.shownAt) && !Knob.on(0, at: PixelOrbit.follow.shownAt))
}
