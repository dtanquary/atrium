import Foundation
import Metal
import SpriteKit
import Testing
@testable import Atrium
@testable import PegLattice

/// A snow crystal grown on the lattice is one crystal with six arms that stays on the sheet: turned a sixth of a
/// turn about the middle hole it lands on itself (but for a hole here and there, where two sums that should be
/// equal differ in their last bit and a hole freezes a step sooner on one arm), no hole within two of the display's
/// edge has a peg, and the order has every place once.
@Test func snowCrystalHasSixArmsAndStaysOnTheSheet() {
    let lattice = Lattice(width: 1512, height: 982, pitch: 16)
    for (alpha, beta, gamma) in [(1, 0.5, 0.0005), (1, 0.35, 0.0035), (2, 0.3, 0.001), (1.5, 0.4, 0.006)] as [(Float, Float, Float)] {
        var rng = SplitMix(state: 5)
        let crystal = snowCrystal(on: lattice, alpha: alpha, beta: beta, gamma: gamma, using: &rng)
        let (c0, r0) = (lattice.cols / 2, lattice.rows / 2)
        var (turned, total, edge) = (0, 0, 0)
        for row in 0..<lattice.rows { for col in 0..<lattice.cols where crystal.order[row * lattice.cols + col] >= 0 {
            total += 1
            if row < 3 || row > lattice.rows - 4 || col < 3 || col > lattice.cols - 4 { edge += 1 }
            // to axial coordinates about the middle, a sixth of a turn, and back to a column and a row
            let (dr, q) = (row - r0, col - c0 - ((row - (row & 1)) - (r0 - (r0 & 1))) / 2), (q2, dr2) = (-dr, q + dr)
            let row2 = r0 + dr2, col2 = c0 + q2 + ((row2 - (row2 & 1)) - (r0 - (r0 & 1))) / 2
            if (0..<lattice.rows).contains(row2), (0..<lattice.cols).contains(col2), crystal.order[row2 * lattice.cols + col2] >= 0 { turned += 1 }
        } }
        print("Peg Board, a crystal at \(alpha), \(beta), \(gamma): \(total) pegs, \(turned) of them on a peg when turned a sixth of a turn")
        #expect(total == crystal.count && total > 200 && edge == 0)
        #expect(Double(turned) > 0.97 * Double(total))
        #expect(Set(crystal.order.filter { $0 >= 0 }).count == total && crystal.order.max() == Int32(total - 1))
    }
}

/// The picture is the same whatever the frame rate: after the same six seconds at speed 1 and three more at speed 4
/// (where the glow's ticks come twice a frame at 15 frames a second), drawn at 15, 30 and 60 frames a second, every
/// pixel is the same, and the crystal is part-built (some of the display is lit, most of it is not).
@MainActor @Test func pegBoardLooksTheSameAtAnyFrameRate() throws {
    defer { ["pegboard.seed", "pegboard.speed"].forEach(UserDefaults.standard.removeObject) }
    UserDefaults.standard.set(7, forKey: "pegboard.seed")
    let device = try #require(MTLCreateSystemDefaultDevice()), queue = try #require(device.makeCommandQueue())
    let (w, h) = (1512, 982)
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    var pictures: [[UInt32]] = []
    for rate in [15.0, 30.0, 60.0] {
        UserDefaults.standard.set(1.0, forKey: "pegboard.speed")
        let renderer = SKRenderer(device: device), target = try #require(device.makeTexture(descriptor: descriptor)), pass = MTLRenderPassDescriptor()
        renderer.scene = PegBoard(size: CGSize(width: w / 2, height: h / 2))
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        let start = ProcessInfo.processInfo.systemUptime + 1 // the renderer's first update runs on the system's clock
        var frames = 0.0
        for _ in 0...Int(6 * rate) { renderer.update(atTime: start + frames / rate); frames += 1 }
        UserDefaults.standard.set(4.0, forKey: "pegboard.speed")
        for _ in 0..<Int(3 * rate) { renderer.update(atTime: start + frames / rate); frames += 1 }
        for _ in 0..<2 { // drawn at the end only, with no more time gone by, and twice for the shader's sake
            renderer.update(atTime: start + (frames - 1) / rate)
            let buffer = try #require(queue.makeCommandBuffer())
            renderer.render(withViewport: CGRect(x: 0, y: 0, width: w, height: h), commandBuffer: buffer, renderPassDescriptor: pass)
            buffer.commit()
            buffer.waitUntilCompleted()
        }
        var raw = [UInt32](repeating: 0, count: w * h)
        target.getBytes(&raw, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
        pictures.append(raw)
    }
    let lit = pictures[0].count { $0 >> 8 & 255 > 60 }
    print("Peg Board after 6 s at 1x and 3 s at 4x: \(lit) of \(w * h) pixels are lit")
    #expect(lit > 2000 && lit < w * h / 10)
    #expect(pictures[1] == pictures[0] && pictures[2] == pictures[0], "the picture differs with the frame rate")
}
