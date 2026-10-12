// probe.swift: what the ants do in a nest, measured with nothing drawn. From the repository's root:
//     swiftc -O Sources/AntNest/Nest.swift Sources/AntNest/Colony.swift docs/ant-colony/probe.swift -o /tmp/probe && /tmp/probe [seed]
// It bakes the nest of a seed on a 14-inch display's grid (756 by 491 cells, an ant 11 of them long), then at four
// ages of the day lets ten minutes go by at the day's own pace and prints: how often a tunnel's face that moved had an ant
// digging at it, or near it; where the ants' time went; how many planted feet were on the medium; how often a
// walking ant had no wall within a length and a half under it; and what a sixtieth of a second costs.
// docs/ant-colony.md quotes these figures ("Still open", "Cost").
import Foundation
import simd

/// The share of the digging done `hours` into a farm (AntColony.share).
func share(_ hours: Double) -> Double { let left = 1 - min(max(hours / 24, 0), 1); return 1 - left * left }

@main struct Probe {
    static func main() {
        let seed = CommandLine.arguments.count > 1 ? UInt64(CommandLine.arguments[1]) ?? 2026101200 : 2026101200
        let clock = ContinuousClock()
        var baked: Nest?
        let bake = clock.measure { baked = Nest(seed: seed, cols: 756, rows: 491, bodyLength: 11) }
        let nest = baked!, bl = nest.bodyLength
        let sand = nest.cols * (nest.rows - nest.ground)
        print("seed \(seed): baked in \(bake); \(nest.branches.count { !$0.room }) tunnels, \(nest.branches.count { $0.room }) rooms, \(nest.links.count) ways between them, \(nest.entrances.count) mouths; \(100 * nest.dug / sand)% of the medium dug")

        for hours in [0.5, 3.0, 9.0, 16.0] {
            var colony = Colony(nest: nest, most: 24, seed: seed, share: share(hours))
            colony.fastForward(600)
            var (moved, dug, near, held, onMedium, walking, bare) = (0, 0, 0, 0, 0, 0, 0)
            var states: [String: Int] = [:], reaches: [Int: Double] = [:]
            let took = clock.measure {
                for tick in 1...36000 {
                    let u = share(hours + Double(tick) / 216_000)
                    colony.step(share: u)
                    guard tick % 30 == 0 else { continue }
                    for face in colony.faces(at: u) where !nest.branches[face.branch].room {
                        let was = reaches[face.branch] ?? face.at
                        reaches[face.branch] = face.at
                        guard face.at > was else { continue } // it went on in the last half second
                        moved += 1
                        let tip = nest.branches[face.branch].points[Int(face.at)]
                        if colony.ants.contains(where: { $0.state == .dig && simd_distance($0.position, tip) < 2.5 * bl }) { dug += 1 }
                        if colony.ants.contains(where: { simd_distance($0.position, tip) < 2.5 * bl }) { near += 1 }
                    }
                    for ant in colony.ants {
                        states["\(ant.state)", default: 0] += 1
                        for (leg, hold) in ant.holds.enumerated() where ant.claws[leg].y < -0.01 {
                            guard let hold else { continue }
                            held += 1
                            if (-1...1).contains(where: { dx in (-1...1).contains { dy in nest.solid(hold.x + Double(dx), hold.y + Double(dy), at: u) } }) { onMedium += 1 }
                        }
                        guard ant.state == .walk, ant.position.y > Double(nest.ground) else { continue }
                        walking += 1
                        var d = 0.0
                        while d < 1.5 * bl, !nest.solid(ant.position.x - ant.up.x * d, ant.position.y - ant.up.y * d, at: u) { d += 0.4 }
                        if d >= 1.5 * bl { bare += 1 }
                    }
                }
            }
            let all = Double(states.values.reduce(0, +))
            print(String(format: "%4.1f h, %2d ants: a face moved %d times, with an ant digging at it %d%% and one near it %d%%; feet on the medium %d%%; walking with no wall under it %d%%;", hours, colony.ants.count, moved, 100 * dug / max(moved, 1), 100 * near / max(moved, 1), 100 * onMedium / max(held, 1), 100 * bare / max(walking, 1)),
                  states.sorted { $0.key < $1.key }.map { "\($0.key) \(Int((100 * Double($0.value) / all).rounded()))%" }.joined(separator: ", ") + ";", "a sixtieth of a second \(took / 36000); \(colony.leapt) leapt, \(colony.gaveUp) gave up")
        }
    }
}
