import Foundation
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
