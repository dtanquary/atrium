import Foundation
import Testing
import simd
@testable import Atrium

/// How many times a river's centreline crosses itself, every segment against every other but its neighbours.
private func crossings(_ river: River) -> Int {
    let n = river.nodes.count
    let points = (0...n).map { SIMD2(river.nodes[$0 % n].x + ($0 == n ? river.period : 0), river.nodes[$0 % n].y) }
    func side(_ a: SIMD2<Float>, _ b: SIMD2<Float>, _ c: SIMD2<Float>) -> Float { (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x) }
    var count = 0
    for i in 0..<n {
        for j in stride(from: i + 2, to: n, by: 1) where !(i == 0 && j == n - 1) {
            let (a, b, c, d) = (points[i], points[i + 1], points[j], points[j + 1])
            if side(a, b, c) * side(a, b, d) < 0, side(c, d, a) * side(c, d, b) < 0 { count += 1 }
        }
    }
    return count
}

/// The prototype's check, on the real thing: over 6,000 coarse steps (T 240) a straight river grows bends and cuts
/// loops off, never crosses itself, and stays between the valley's walls.
@Test func riverCutsOffLoopsAndNeverCrosses() {
    let river = River(seed: 3, across: 54, up: 35.07, texels: 14)
    for _ in 0..<12 {
        river.age(distant: 0, recent: 20)
        #expect(crossings(river) == 0, "crossed itself by T \(river.now)")
        #expect(river.nodes.allSatisfy { $0.x.isFinite && $0.y - $0.half > 0 && $0.y + $0.half < river.up }, "left the valley by T \(river.now)")
    }
    #expect(river.cutoffs > 5 && river.sinuosity > 1.5, "\(river.cutoffs) cutoffs, sinuosity \(river.sinuosity)")
    #expect(river.nodes.count > 150 && river.nodes.count < 1200)
}

/// Stepped by 1/15, 1/30 or 1/60 of a second for the same time, the river and the ground are the same to the last
/// bit: it steps by the time gone by, not by the frame. At speed 4 too, where it steps twice as often.
@Test func riverIsTheSameAtAnyFrameRate() {
    func run(_ frames: Double) -> River {
        let river = River(seed: 5, across: 27, up: 17.5, texels: 8) // a small valley, to keep a debug build quick
        river.age(distant: 40, recent: 30)
        for _ in 0..<Int(8 * frames) { river.advance(1 / frames) }
        for _ in 0..<Int(4 * frames) { river.advance(1 / frames, speed: 4) }
        return river
    }
    let (slow, usual, fast) = (run(15), run(30), run(60))
    #expect(slow.now > 70.9 && slow.now < 71.1, "T \(slow.now)") // 70, then 8 s at 25 s a T and 4 s at four times that
    for other in [usual, fast] {
        #expect(other.now == slow.now && other.nodes.count == slow.nodes.count)
        #expect(zip(other.nodes, slow.nodes).allSatisfy { $0.x == $1.x && $0.y == $1.y && $0.half == $1.half })
        #expect(other.pixels == slow.pixels)
    }
}

/// The stamps are 16 bits counted from a base that has to move up before they run out, after about 650 T. When
/// it does, ground the river has just left still reads as just left, and nothing reads as later than now.
@Test func riverMovesItsStampsUpBeforeTheyRunOut() {
    let river = River(seed: 9, across: 27, up: 17.5, texels: 8)
    river.age(distant: 640, recent: 20)
    #expect(river.base > 0 && river.now - river.base < 650, "base \(river.base) at T \(river.now)")
    let stamps = (0..<river.columns * river.rows).map { Double(Int(river.pixels[$0 * 4]) << 8 | Int(river.pixels[$0 * 4 + 1])) / 100 }
    let latest = stamps.max()!, sinceBase = river.now - river.base
    #expect(latest <= sinceBase + 0.01 && latest > sinceBase - 0.5, "the latest stamp is \(latest), and now is \(sinceBase)")
    #expect(stamps.count { $0 > 0 } > stamps.count / 3)
}

/// A new river's past: by the first frame the ground has been worked edge to edge of the belt, the river and its
/// lakes are drawn as water, and hollows mark old channels. And how long that takes, which every load, shuffle and
/// Settings page waits for on the main thread, and what a live step costs after it: timed in an optimised build only.
@Test func riverGetsAPastQuickly() {
    func milliseconds(_ body: () -> Void) -> Double {
        let start = DispatchTime.now().uptimeNanoseconds
        body()
        return Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6
    }
    #if DEBUG
    let seeds: [UInt64] = [13]
    #else
    let seeds: [UInt64] = [11, 12, 13, 14, 15, 13] // the last one is looked at below
    #endif
    var river = River(seed: 1, across: 54, up: 35.07, texels: 14), times: [Double] = []
    for seed in seeds {
        river = River(seed: seed, across: 54, up: 35.07, texels: 14)
        times.append(milliseconds { river.age() })
    }
    let texels = river.columns * river.rows
    let stamped = (0..<texels).count { river.pixels[$0 * 4] != 0 || river.pixels[$0 * 4 + 1] != 0 }
    let water = (0..<texels).count { river.pixels[$0 * 4 + 2] < 127 }, hollow = (0..<texels).count { river.pixels[$0 * 4 + 3] < 140 }
    let lakeWater = river.ground.count { $0.w < 0.5 }, width = 2 * river.nodes.reduce(0) { $0 + $1.half } / Float(river.nodes.count)
    print("Meander's past, T 240 coarse then T 60, for a 28 pt river: \(times.map { String(format: "%.0f", $0) }.joined(separator: ", ")) ms")
    print(String(format: "  the last: %d nodes, sinuosity %.2f, mean width %.2f, %d cutoffs, %d lakes; stamped %.0f%%, water %.1f%% (lakes %.1f%%), hollow %.1f%%",
                 river.nodes.count, river.sinuosity, width, river.cutoffs, river.lakes.count, 100 * Double(stamped) / Double(texels),
                 100 * Double(water) / Double(texels), 100 * Double(lakeWater) / Double(texels), 100 * Double(hollow) / Double(texels)))
    #expect(river.now > 299 && river.now < 301)
    #expect(Double(stamped) / Double(texels) > 0.5, "only \(stamped) of \(texels) texels have a past")
    #expect(Double(water) / Double(texels) > 0.03 && Double(water) / Double(texels) < 0.3)
    #expect(hollow > 0 && crossings(river) == 0)
    // the river's own nodes are under water, where they are on screen
    for node in river.nodes where node.x > 1 && node.x < river.across - 1 {
        let at = Int(node.y * river.texels) * river.columns + Int(node.x * river.texels)
        #expect(river.pixels[at * 4 + 2] < 127, "the node at \(node.x), \(node.y) is dry")
    }
    if let folder = ProcessInfo.processInfo.environment["MEANDER_DUMP"] { // the texture's bytes, to look at
        try? Data(river.pixels).write(to: URL(fileURLWithPath: folder).appendingPathComponent("meander-\(river.columns)x\(river.rows).rgba"))
    }
    #if !DEBUG
    #expect(times.min()! < 150, "the past took \(times) ms")
    // The recent past kept exactly instead, to compare; then a minute of live steps, ten a second
    let exact = River(seed: 13, across: 54, up: 35.07, texels: 14)
    print(String(format: "  with the recent past's ground kept exactly, every 12th step: %.0f ms", milliseconds { exact.age(exactEvery: 12) }))
    var steps: [Double] = []
    for _ in 0..<600 { steps.append(milliseconds { river.advance(0.1) }) }
    steps.sort()
    print(String(format: "  a live step with the ground and %d lakes: median %.2f ms, slowest of 600 %.2f ms", river.lakes.count, steps[300], steps[599]))
    #expect(steps[300] < 2)
    #endif
}
