// wide.swift: many nests on many grids, looking for what would be a crash at every launch on one date, or an ant in
// the medium. From the repository's root:
//     swiftc -O Sources/AntNest/Nest.swift Sources/AntNest/Colony.swift docs/ant-colony/wide.swift -o /tmp/wide && /tmp/wide [dates]
// For each of twelve grids (the map a display gets at a size of ant) and each of `dates` seeds (90 unless given) it
// bakes the nest and runs its ants ten seconds at each of four ages with the digging going on fast, and ten more
// with the clock set back from half dug to a fifth half-way through. It counts ant-moments, bodies whose middle
// was in the medium, places that were not numbers or were off the tank, ants moved to their place at once (and how
// many of those were when the clock went back), the fewest mouths a nest had and the nests without a room; and the
// longest a nest and its ants took to be ready on each grid, with every core busy.
// The test antColonySurvivesManyDatesAndDisplays is the slim one that stays; docs/ant-colony.md has this one's numbers.
import Foundation
import simd
import Synchronization

@main struct Wide {
    struct Tally { var nests = 0, moments = 0, buried = 0, lost = 0, leapt = 0, back = 0, gaveUp = 0, fewestMouths = 99, roomless = 0, slowest = [String: Double]() }

    static func main() {
        let grids: [(String, Int, Int)] = [("14in M", 756, 491), ("14in S", 1279, 831), ("14in L", 462, 300), ("13in M", 640, 400), ("16in M", 864, 559),
            ("1080p M", 960, 540), ("portrait M", 540, 960), ("5K M", 1280, 720), ("5K S", 2166, 1218), ("6K M", 1504, 846), ("6K S", 2545, 1432), ("6K L", 919, 517)]
        let dates = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1]) ?? 90 : 90
        let tally = Mutex(Tally()), clock = ContinuousClock(), began = clock.now
        DispatchQueue.concurrentPerform(iterations: grids.count * dates) { job in
            let (name, cols, rows) = grids[job % grids.count], seed = UInt64(2026101200 + (job / grids.count) * 100)
            let start = clock.now
            let nest = Nest(seed: seed, cols: cols, rows: rows, bodyLength: 11), most = min(max(cols * rows / 121 / 128, 4), 100)
            var colony = Colony(nest: nest, most: most, seed: seed, share: 0.02)
            colony.fastForward(180)
            let ready = clock.now - start
            var mine = Tally()
            for (from, to) in [(0.02, 0.06), (0.3, 0.33), (0.7, 0.72), (0.99, 1.0), (0.5, 0.2)] { // (the last: the clock set back)
                if from != 0.02 { colony = Colony(nest: nest, most: most, seed: seed, share: from); colony.fastForward(60) }
                for tick in 1...600 {
                    colony.step(share: to < from ? (tick < 300 ? from : to) : from + (to - from) * Double(tick) / 600)
                    for ant in colony.ants {
                        mine.moments += 1
                        let at = ant.position
                        if !(at.x.isFinite && at.y.isFinite && ant.forward.x.isFinite && at.x > -1 && at.x < Double(cols) + 1 && at.y > -1 && at.y < Double(rows) + 1) { mine.lost += 1 }
                        if !colony.clear(at, ant.forward, middle: true) { mine.buried += 1 }
                    }
                }
                mine.leapt += colony.leapt
                mine.gaveUp += colony.gaveUp
                if to < from { mine.back += colony.leapt }
            }
            tally.withLock {
                $0.nests += 1; $0.moments += mine.moments; $0.buried += mine.buried; $0.lost += mine.lost
                $0.leapt += mine.leapt; $0.back += mine.back; $0.gaveUp += mine.gaveUp
                $0.fewestMouths = min($0.fewestMouths, nest.entrances.count)
                if !nest.branches.contains(where: { $0.room }) { $0.roomless += 1 }
                $0.slowest[name] = max($0.slowest[name] ?? 0, Double(ready.components.seconds) + Double(ready.components.attoseconds) / 1e18)
            }
        }
        let t = tally.withLock { $0 }
        print("\(t.nests) nests (\(grids.count) grids x \(dates) dates) in \(clock.now - began): \(t.moments) ant-moments; \(t.buried) middles in the medium; \(t.lost) places not a number or off the tank; \(t.leapt) moved at once, \(t.back) of them when the clock was set back; \(t.gaveUp) gave up; fewest mouths \(t.fewestMouths); \(t.roomless) nests without a room")
        print("the longest a nest and its ants took to be ready, by grid (seconds, with every core busy):", t.slowest.sorted { $0.key < $1.key }.map { "\($0.key) \(String(format: "%.2f", $0.value))" }.joined(separator: ", "))
    }
}
