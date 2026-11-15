import SpriteKit
import Testing
@testable import Atrium

/// Kelp Forest leaves alone what can't be seen to change: blades and stipes off the screen, and far cards whose
/// chain hasn't stepped. Every sprite that reaches the screen must sit just where it does with that turned off, at
/// 60 fps, where far fronds step every other frame: looking up, and in the moving view, level and as it starts to tip.
@MainActor @Test(arguments: [1, 2]) func kelpSkipsOnlyTheUnseen(view: Int) {
    UserDefaults.standard.set(5, forKey: "kelp.seed")
    UserDefaults.standard.set(239.6, forKey: "kelp.cycleAt") // the moving view holds level for 0.4 s more, then tips
    defer { for key in ["kelp.seed", "kelp.cycleAt"] { UserDefaults.standard.removeObject(forKey: key) } }
    let size = CGSize(width: 756, height: 491), screen = CGRect(origin: .zero, size: size)
    let skipping = KelpForest(size: size, view: view), posingAll = KelpForest(size: size, view: view)
    posingAll.skipsUnseen = false
    for frame in 1...45 {
        skipping.update(1000 + Double(frame) / 60)
        posingAll.update(1000 + Double(frame) / 60)
    }
    #expect(skipping.children.count == posingAll.children.count && skipping.children.count > 500)
    var seen = 0, hidden = 0
    for case let (a as SKSpriteNode, b as SKSpriteNode) in zip(skipping.children, posingAll.children) {
        guard !b.isHidden, b.frame.intersects(screen) else { hidden += a.isHidden ? 1 : 0; continue }
        seen += 1
        // A blade's width is set only when it has moved a percent, so the two may differ by that.
        let same = !a.isHidden && a.position == b.position && a.zRotation == b.zRotation
            && abs(a.frame.width - b.frame.width) <= 0.025 * b.frame.width + 0.01 && abs(a.frame.height - b.frame.height) <= 0.025 * b.frame.height + 0.01
        #expect(same, "view \(view): a sprite on the screen at \(b.position) was left unposed")
        if !same { break }
    }
    #expect(seen > 300 && hidden > 100, "view \(view): \(seen) on the screen, \(hidden) left alone") // or nothing was tested
}

/// A kelp sprite's light and its own number share its colour's blue channel: both come back as the shader reads
/// them, the light to within half a step and the number to within 6%, even with the channel rounded to 8 bits.
@Test func kelpLightSharesItsChannel() {
    var worst = (light: 0.0, seed: 0.0)
    for light in stride(from: 0.0, through: 1.2, by: 0.005) {
        for seed in stride(from: 0.0, through: 1.0, by: 0.02) {
            let b = (KelpForest.blue(light: light, seed: seed) * 255).rounded() / 255 * 16
            worst.light = max(worst.light, abs(b.rounded(.down) / 12.5 - light))
            worst.seed = max(worst.seed, abs((b - b.rounded(.down) - 0.2) / 0.6 - seed))
        }
    }
    #expect(worst.light <= 0.0401 && worst.seed < 0.06, "\(worst)")
}

/// On battery the water draws at half resolution and its marine snow, specks a pixel or two across, moves to a sprite
/// of its own over it at full resolution, and back as the trim goes off; dusk has no snow to move.
@MainActor @Test func kelpSnowStaysSharpWhenTrimmed() throws {
    defer { UserDefaults.standard.removeObject(forKey: "kelp.look") }
    for (look, snows) in [(4.0, true), (6.0, false)] { // teal, dusk
        UserDefaults.standard.set(look, forKey: "kelp.look")
        let scene = KelpForest(size: CGSize(width: 320, height: 200), view: 0)
        let water = try #require(scene.trim.content.children.first as? SKSpriteNode)
        let sprite = try #require(scene.children.compactMap { $0 as? SKSpriteNode }.first { $0.shader?.uniformNamed("u_speck") != nil })
        func waterSnows() -> Bool { water.shader!.uniformNamed("u_look")!.vectorFloat4Value.y > 0 }
        #expect(sprite.isHidden && waterSnows() == snows)
        scene.trim.scale = 0.5
        #expect(sprite.isHidden != snows && !waterSnows(), "look \(look): the snow didn't move to its sprite")
        scene.trim.scale = 1
        #expect(sprite.isHidden && waterSnows() == snows, "look \(look): the snow didn't come back to the water")
    }
}
