import SpriteKit
import Testing
@testable import Atrium

/// Runs the moon jellies for two minutes and measures them on screen as docs/jellyfish/research-motion.md measured
/// footage, then checks they get somewhere as they pulse and fill the tank rather than gathering at the top (where,
/// drawn only upward, they once pulsed against it going nowhere: 56% of them in the top third).
///
///     JELLY_SEED=7 JELLY_LOOK=6 swift test --filter jellyfishMove   # another layout, or the crystal jellies
@MainActor @Test func jellyfishMoveAsFootage() {
    let env = ProcessInfo.processInfo.environment
    UserDefaults.standard.set(Int(env["JELLY_SEED"] ?? "") ?? 22, forKey: "jellyfish.seed")
    UserDefaults.standard.set(Int(env["JELLY_LOOK"] ?? "") ?? 4, forKey: "jellyfish.look")
    UserDefaults.standard.set(1 / Jellyfish.pace, forKey: "jellyfish.speed") // the real pace, as the footage was
    defer { ["jellyfish.seed", "jellyfish.look", "jellyfish.speed"].forEach(UserDefaults.standard.removeObject) }
    let size = CGSize(width: 1512, height: 982), scene = Jellyfish(size: size)
    let fps = 30.0
    var frames: [[(p: CGPoint, d: Double, tilt: Double, heading: Double)]] = []
    for f in 0...Int(120 * fps) {
        scene.update(1000 + Double(f) / fps)
        frames.append(scene.children.compactMap { $0 as? SKSpriteNode }.filter { $0.zPosition > -10 }.map { node in
            let box = node.value(forAttributeNamed: "a_box")!.vectorFloat4Value, pose = node.value(forAttributeNamed: "a_pose")!.vectorFloat4Value
            return (node.position, Double(1 / box.w), Double(pose.x), Double(node.zRotation)) // a_box.w is 0.5 / the bell's radius
        })
    }
    // Speed over 1 s in each jelly's own diameters, less the group's median step, as the handheld footage had to be.
    let n = frames[0].count, w = Int(fps)
    var relative: [Double] = [], fromVertical: [Double] = [], top = 0, bottom = 0, all = 0
    for f in stride(from: w, to: frames.count, by: w / 3) {
        let step = (0..<n).map { CGPoint(x: frames[f][$0].p.x - frames[f - w][$0].p.x, y: frames[f][$0].p.y - frames[f - w][$0].p.y) }
        let (mx, my) = (step.map(\.x).sorted()[n / 2], step.map(\.y).sorted()[n / 2])
        for (i, jelly) in frames[f].enumerated() {
            relative.append(hypot(step[i].x - mx, step[i].y - my) / jelly.d)
            if abs(sin(jelly.tilt)) < 0.55 { // side-on: the axis line's angle from vertical
                let a = abs(jelly.heading.truncatingRemainder(dividingBy: .pi)) * 180 / .pi
                fromVertical.append(min(a, 180 - a))
            }
            all += 1
            if jelly.p.y > size.height * 2 / 3 { top += 1 } else if jelly.p.y < size.height / 3 { bottom += 1 }
        }
    }
    let speed = relative.sorted()[relative.count / 2], (upper, lower) = (Double(top) / Double(all), Double(bottom) / Double(all))
    print(String(format: "jellyfish: %.2f diameters/s relative to the group (footage 0.14, lone jellies 0.3-0.4); top third %.0f%%, " +
                 "bottom third %.0f%%; side-on bells %.0f° from vertical (footage 26°)",
                 speed, 100 * upper, 100 * lower, fromVertical.sorted()[fromVertical.count / 2]))
    #expect(speed > 0.1 && speed < 0.4)
    #expect(upper < 0.45 && lower > 0.15)
}
