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

/// The dark field's filter: behind its stop only a dim glow of the centre colour, a bend's direction picking one of
/// the four colours round it (right, above, left, below), and brightness growing with the bend up to full strength.
@Test func schlierenDarkFieldColoursByDirectionAndBrightensWithTheBend() {
    let c = Schlieren.palettes[0].colours, n = Schlieren.filterSize, bytes = Schlieren.filterBytes(0, c)
    func at(_ x: Float, _ y: Float) -> SIMD3<Float> { // the table's colour for a bend of (x, y) half-widths
        let o = (Int((y + 2) / 4 * Float(n)) * n + Int((x + 2) / 4 * Float(n))) * 4
        return SIMD3(Float(bytes[o]), Float(bytes[o + 1]), Float(bytes[o + 2])) / 255
    }
    func near(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Bool { simd_reduce_max(simd_abs(a - b)) < 0.03 }
    #expect(near(at(1.5, 0), c[3]) && near(at(0, 1.5), c[4]) && near(at(-1.5, 0), c[1]) && near(at(0, -1.5), c[0]))
    let centre = at(0, 0)
    #expect(simd_reduce_max(centre) < 0.2 && centre.z > centre.x) // Candlelight's navy, dim
    let rising = stride(from: Float(0.1), through: 1, by: 0.1).map { at($0, 0).x } // red, toward amber
    #expect(zip(rising, rising.dropFirst()).allSatisfy { $0 <= $1 } && rising[1] < 0.5 && rising[6] > 0.95)
}
