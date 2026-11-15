import SpriteKit
import Testing
@testable import Atrium

/// The light near fireflies cast on the grass comes and goes with their glow: at 15 fps no light jumps by more than
/// the glow itself moves in a frame (a light handed to a fly mid-glow would pop in), and the eight are used.
@MainActor @Test func grassLightNeverPops() {
    UserDefaults.standard.set(2, forKey: "fireflies.seed")
    defer { UserDefaults.standard.removeObject(forKey: "fireflies.seed") }
    let scene = Fireflies(size: CGSize(width: 1512, height: 982))
    let strengths = { scene.lamps.flatMap { lamp in (0..<4).map { lamp.matrixFloat4x4Value[$0].w } } }
    var last = strengths(), brightest: Float = 0
    for frame in 0..<(15 * 40) {
        scene.update(Double(frame) / 15)
        let now = strengths()
        #expect(zip(now, last).allSatisfy { abs($0 - $1) < 0.15 }, "a light popped at frame \(frame)")
        brightest = max(brightest, now.max() ?? 0)
        last = now
    }
    #expect(brightest > 0.5)
}

/// Fireflies fly over the photo's own ground: where the field rises above the ground plane (far off, to the right)
/// they're lifted, not left inside it over nearer grass, and where trees stand in the way (the left, past 40 m)
/// they aren't lifted over them.
@MainActor @Test func firefliesFlyOverTheField() {
    let scene = Fireflies(size: CGSize(width: 1512, height: 982))
    let across = { (fraction: CGFloat, d: CGFloat) in (fraction - 0.5) * 1512 / (982 * 1.424) * d } // metres, by the lens
    #expect(scene.lift(across(0.95, 30), 30) > 0.3)
    #expect(scene.lift(across(0.05, 45), 45) == 0)
    #expect(scene.lift(across(0.3, 20), 20) == 0)
}
