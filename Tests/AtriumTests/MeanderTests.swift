import Foundation
@testable import MeanderRiver
import Testing
import simd

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
/// Settings page waits for on the main thread, and what a live step costs after it. (The river's module is built
/// optimised even in a debug build, so the times mean the same in both.)
@Test func riverGetsAPastQuickly() {
    func milliseconds(_ body: () -> Void) -> Double {
        let start = DispatchTime.now().uptimeNanoseconds
        body()
        return Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6
    }
    let seeds: [UInt64] = [11, 12, 13, 14, 15, 13] // the last one is looked at below
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
    #expect(times.min()! < 150, "the past took \(times) ms")
    // The banks in the ground against the long way, which splits each segment in two as the prototype did: near a
    // bank (two texels either side), at every fifth texel
    var off: [Float] = []
    for i in stride(from: 0, to: texels, by: 5) where abs(river.ground[i].z - 0.5) < 2 / river.texels {
        let point = SIMD2(Float(i % river.columns) + 0.5, Float(i / river.columns) + 0.5) / river.texels
        off.append(abs(river.bankDistance(at: point) - river.ground[i].z) * river.texels)
    }
    off.sort()
    print(String(format: "  its banks against the prototype's, at %d texels: half within %.3f of a texel, 99 in 100 within %.3f, the worst %.2f",
                 off.count, off[off.count / 2], off[off.count * 99 / 100], off.last!))
    #expect(off[off.count * 99 / 100] < 0.25 && off.last! < 1)
    // No cracks in the ground a past leaves: land that is over 3 T older than the land on both sides of it, across
    // or up, is a texel or two the sweep missed
    var cracks = 0, land = 0
    for y in 1..<river.rows - 1 { for x in 1..<river.columns - 1 {
        let i = y * river.columns + x, here = river.ground[i]
        guard min(here.z, here.w) > 0.5 + 2 / river.texels, here.x > 0 else { continue }
        land += 1
        func newer(_ a: Int, _ b: Int) -> Bool { river.ground[a].x > here.x + 3 && river.ground[b].x > here.x + 3 }
        if newer(i - 1, i + 1) || newer(i - river.columns, i + river.columns) { cracks += 1 }
    } }
    print(String(format: "  cracks in its ground: %d of %d land texels (%.2f%%)", cracks, land, 100 * Double(cracks) / Double(land)))
    #expect(Double(cracks) / Double(land) < 0.004)
    // then a minute of live steps, ten a second
    var steps: [Double] = []
    for _ in 0..<600 { steps.append(milliseconds { river.advance(0.1) }) }
    steps.sort()
    print(String(format: "  a live step with the ground and %d lakes: median %.2f ms, 99 in 100 under %.2f, the slowest of 600 %.2f; the lakes are at most %.2f texels out of date",
                 river.lakes.count, steps[300], steps[594], steps[599], river.lakesAdrift() * river.texels))
    #expect(steps[300] < 1.5)
}

/// Only a couple of lakes are drawn again on each step. Over 24 T at speed 4, long enough for every lake there at
/// the start to dry up and for others to be cut off, trimmed and run into each other, the lakes' water in the
/// ground is never half a texel from where drawing every lake afresh would put it: none is left behind when a lake
/// goes, and none is lost where two overlap.
@Test func riverKeepsItsLakesUpToDate() {
    let river = River(seed: 7, across: 27, up: 17.5, texels: 8)
    river.age(distant: 40, recent: 30)
    var worst: Float = 0, most = 0, born = river.cutoffs
    for _ in 0..<60 {
        for _ in 0..<50 { river.advance(0.05, speed: 4) }
        (worst, most) = (max(worst, river.lakesAdrift() * river.texels), max(most, river.lakes.count))
    }
    born = river.cutoffs - born
    print(String(format: "Meander's lakes over T 24 at speed 4: %d cut off, %d at once at most, never more than %.2f texels out of date", born, most, worst))
    #expect(born > 3 && worst < 0.5)
}
