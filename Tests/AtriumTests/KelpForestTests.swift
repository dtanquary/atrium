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
