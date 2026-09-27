import Foundation
import SpriteKit
import Testing
@testable import Atrium

/// The interference colours land where the Michel-Lévy chart has them: black at zero, first-order white near 250 nm,
/// the first-order red (the "sensitive tint", magenta-violet) at 551 nm, second-order blue at 650 and green at 800.
@Test func michelLevyColours() {
    let chart = Crystals.michelLevy()
    func at(_ nm: Double) -> SIMD3<Double> { chart[Int((nm / Crystals.michelLevyRange * Double(chart.count - 1)).rounded())] }
    #expect(at(0).max() < 0.001)
    #expect(at(260).min() > 0.8)                                    // first-order white
    let tint = at(551)
    #expect(tint.x > tint.y && tint.z > tint.y)                     // magenta-violet: no green
    let blue = at(650)
    #expect(blue.z > blue.x && blue.z > blue.y)
    let green = at(800)
    #expect(green.y > green.x && green.y > green.z)
    #expect(chart.allSatisfy { $0.min() >= 0 })                     // gamut-mapped, never negative
}

/// A baked slide: every texel is crystal or liquid, the growth runs from 0 to 1, and there's more crystal than liquid.
@Test func crystalsBake() {
    var rng = SplitMix(state: 7)
    let baked = Crystals.bake(texels: CGSize(width: 200, height: 130), size: CGSize(width: 400, height: 260), crystalSize: 1, rng: &rng)
    let arrivals = stride(from: 0, to: baked.growth.count, by: 4).map { (Double(baked.growth[$0]) + Double(baked.growth[$0 + 1]) / 255) / 255 / 0.95 }
    #expect(arrivals.allSatisfy { $0 >= 0 && $0 <= 1.06 })
    #expect(arrivals.filter { $0 <= 1 }.max()! > 0.999)
    #expect(arrivals.filter { $0 <= 1 }.count > arrivals.count / 2)
}

/// The slide runs through its cycle, and the next one, baked in the background during the melt, takes over at the end.
/// It steps the clock rather than shortening Cycle length, because tests run in parallel and the render test reads it.
@MainActor @Test func crystalsCycle() async throws {
    let scene = crystals(size: CGSize(width: 400, height: 260))
    let grow = try #require((scene.children.first as? SKSpriteNode)?.shader?.uniformNamed("u_grow"))
    var time = 0.0, restarts = 0, last = grow.floatValue
    for step in 0..<Int(Crystals.knobs[0].value * 60 * 10 * 3.2) { // over three cycles in 0.1 s frames
        time += 0.1
        scene.update(time)
        if grow.floatValue < last { restarts += 1 }
        last = grow.floatValue
        if step % 50 == 0 { try await Task.sleep(for: .milliseconds(5)) } // lets the background bake land
    }
    #expect(restarts >= 3)
}
