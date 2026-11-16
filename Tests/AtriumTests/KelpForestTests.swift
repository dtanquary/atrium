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

/// Every blade card holds its whole blade, bowed, crimped and at its widest: nothing reaches the card's edges, where
/// it would be cut off, and each card has a blade in it.
@MainActor @Test func kelpBladesStayInTheirCards() throws {
    let image = try #require(Atlas.shared().texture.cgImage())
    let (w, h) = (image.width, image.height)
    var rgba = [UInt8](repeating: 0, count: w * h * 4)
    let ctx = try #require(CGContext(data: &rgba, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                     space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    for card in Atlas.shared().blades {
        let r = card.textureRect(), x0 = Int((r.minX * Double(w)).rounded()), x1 = Int((r.maxX * Double(w)).rounded()) - 1
        let y0 = Int((r.minY * Double(h)).rounded()), y1 = Int((r.maxY * Double(h)).rounded()) - 1
        func alpha(_ x: Int, _ y: Int) -> UInt8 { rgba[((h - 1 - y) * w + x) * 4 + 3] } // drawn rows run from the top
        let edge = (x0...x1).map { max(alpha($0, y0), alpha($0, y1)) }.max()! | (y0...y1).map { alpha(x1, $0) }.max()!
        let inside = (x0...x1).reduce(0) { n, x in n + (y0...y1).filter { alpha(x, $0) > 128 }.count }
        #expect(edge == 0 && inside > 2000, "card at \(x0), \(y0): \(edge) at its edges, \(inside) pixels of blade")
    }
}

/// The school of blacksmith stays together in view as it swims (a minute in, most of it is on the screen), and the
/// Fish switch takes it away.
@MainActor @Test func kelpSchoolStaysInView() {
    UserDefaults.standard.set(5, forKey: "kelp.seed")
    defer { for key in ["kelp.seed", "kelp.fish"] { UserDefaults.standard.removeObject(forKey: key) } }
    let size = CGSize(width: 756, height: 491), screen = CGRect(origin: .zero, size: size)
    let scene = KelpForest(size: size, view: 0), cards = Atlas.shared().fish.map { $0.textureRect() }
    let fish = scene.children.compactMap { $0 as? SKSpriteNode }.filter { node in cards.contains { $0 == node.texture?.textureRect() } }
    for frame in 1...600 { scene.update(1000 + Double(frame) / 10) }
    #expect(fish.count == 36)
    let seen = fish.filter { !$0.isHidden && screen.contains($0.position) }.count
    #expect(seen > 24, "\(seen) of \(fish.count) fish on the screen after a minute")
    UserDefaults.standard.set(0, forKey: "kelp.fish")
    scene.update(1060.1)
    #expect(fish.filter { !$0.isHidden }.isEmpty)
}

/// The fish swim alike at any frame rate, and smoothly: at 30 and 120 fps every fish is in the same place and faces the
/// same way at the same moment, and at 120 fps they move on every frame, not only when their 1/30 s step comes round.
@MainActor @Test func kelpFishSwimSmoothlyAtAnyRate() {
    UserDefaults.standard.set(5, forKey: "kelp.seed")
    defer { UserDefaults.standard.removeObject(forKey: "kelp.seed") }
    let size = CGSize(width: 756, height: 491), cards = Atlas.shared().fish.map { $0.textureRect() }
    func school(_ scene: KelpForest) -> [SKSpriteNode] {
        scene.children.compactMap { $0 as? SKSpriteNode }.filter { node in cards.contains { $0 == node.texture?.textureRect() } }
    }
    let slow = KelpForest(size: size, view: 0), fast = KelpForest(size: size, view: 0), a = school(slow), b = school(fast)
    slow.update(1000)
    fast.update(1000)
    var worst = 0.0, still = 0, last = b.map(\.position)
    for frame in 1...360 { // 3 s at 120 fps
        fast.update(1000 + Double(frame) / 120)
        if b.map(\.position) == last { still += 1 }
        last = b.map(\.position)
        guard frame % 4 == 0 else { continue }
        slow.update(1000 + Double(frame) / 120)
        for (p, q) in zip(a, b) {
            worst = max(worst, hypot(p.position.x - q.position.x, p.position.y - q.position.y))
            #expect(p.xScale == q.xScale, "a fish faces the other way at 30 fps")
        }
    }
    #expect(a.count == 36 && worst < 0.1 && still == 0, "\(worst) pt apart at 30 and 120 fps; \(still) frames of 360 at 120 fps without a move")
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
