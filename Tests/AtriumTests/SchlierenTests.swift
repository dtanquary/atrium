import SpriteKit
import Testing
@testable import Atrium

/// Schlieren's air takes a step of Speed/30 s every 30th of a second whatever the frame rate, so at 15 and 60 fps it
/// takes the same steps and comes out the same to the bit, and a 60 fps display doesn't step it twice as often.
@MainActor @Test func schlierenAirIsTheSameAtAnyFrameRate() {
    func air(fps: Int) -> [Float] {
        let scene = schlieren(size: CGSize(width: 320, height: 200)) as! Schlieren
        for frame in 0...fps * 2 / 5 { scene.update(1000 + Double(frame) / Double(fps)) } // 0.4 s
        let air = scene.air!
        return (0..<(air.fx + 2) * (air.fy + 2)).map { air.t[$0] }
    }
    #expect(air(fps: 15) == air(fps: 60))
}
