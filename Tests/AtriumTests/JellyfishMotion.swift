import Metal
import SpriteKit
import Testing
@testable import Atrium

/// Runs the moon jellies for two minutes and measures them on screen as docs/jellyfish/research-motion.md measured
/// footage, then checks they get somewhere as they pulse and fill the tank rather than gathering at the top (where,
/// drawn only upward, they once pulsed against it going nowhere: 56% of them in the top third), and that few face us:
/// a bell facing the camera pulses without getting anywhere on screen, and a fifth of them did where footage has a
/// tenth, until their axes were eased toward the glass.
///
/// The pulse itself no longer follows the display footage's (a stroke every 1.6 s, 0.2 of a diameter each at least):
/// on Dave's word that they pulsed a lot for how far they went, a stroke comes every 2.5 s, as wild ones of this size
/// pulse, and carries 0.6 of a diameter. So what is held to the footage is the speed across the screen, not the beat;
/// `jellyfishGlideBetweenStrokes` checks how a stroke is spent.
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
    var relative: [Double] = [], fromVertical: [Double] = [], top = 0, bottom = 0, all = 0, facing = 0, faster = 0, along = 0
    for f in stride(from: w, to: frames.count, by: w / 3) {
        let step = (0..<n).map { CGPoint(x: frames[f][$0].p.x - frames[f - w][$0].p.x, y: frames[f][$0].p.y - frames[f - w][$0].p.y) }
        let (mx, my) = (step.map(\.x).sorted()[n / 2], step.map(\.y).sorted()[n / 2])
        for (i, jelly) in frames[f].enumerated() {
            let (dx, dy) = (step[i].x - mx, step[i].y - my)
            relative.append(hypot(dx, dy) / jelly.d)
            if abs(sin(jelly.tilt)) > 0.75 { facing += 1 } else if relative.last! > 0.12 { // the faster ones: along their axis line?
                faster += 1
                if abs(-sin(jelly.heading) * dx + cos(jelly.heading) * dy) > cos(.pi / 6) * hypot(dx, dy) { along += 1 }
            }
            if abs(sin(jelly.tilt)) < 0.55 { // side-on: the axis line's angle from vertical
                let a = abs(jelly.heading.truncatingRemainder(dividingBy: .pi)) * 180 / .pi
                fromVertical.append(min(a, 180 - a))
            }
            all += 1
            if jelly.p.y > size.height * 2 / 3 { top += 1 } else if jelly.p.y < size.height / 3 { bottom += 1 }
        }
    }
    let speed = relative.sorted()[relative.count / 2], (upper, lower) = (Double(top) / Double(all), Double(bottom) / Double(all))
    let faceOn = Double(facing) / Double(all)
    print(String(format: "jellyfish: %.2f diameters/s relative to the group (footage 0.14, lone jellies 0.3-0.4); top third %.0f%%, " +
                 "bottom third %.0f%%; side-on bells %.0f° from vertical (footage 26°); facing us %.0f%% (footage 10%%); " +
                 "of the faster ones, %.0f%% travel within 30° of their axis (footage 53%%)",
                 speed, 100 * upper, 100 * lower, fromVertical.sorted()[fromVertical.count / 2], 100 * faceOn, 100 * Double(along) / Double(max(1, faster))))
    #expect(speed > 0.1 && speed < 0.4)
    #expect(upper < 0.45 && lower > 0.15)
    #expect(faceOn < 0.15)
    #expect(Double(along) / Double(max(1, faster)) < 0.76) // 78% at seed 22 before the tank's eddies carried them off it
}

/// The trailing parts lie in the water going past the bell: at twice its mean speed they stream out long, at rest they
/// bunch, and while the bell skids through a turn they trail between its axis and the way it is going. They used to
/// hang along the axis alone, the same length whatever the bell did.
@MainActor @Test func jellyfishArmsStreamAndBunch() {
    let sp = Jellyfish.moon, up = SIMD3<Double>(0, 1, 0), d = 0.15, mean = sp.perPulse / sp.period
    let fast = Jellyfish.trailing(up, way: up * 2 * mean * d, d: d, mean: mean, sp), resting = Jellyfish.trailing(up, way: .zero, d: d, mean: mean, sp)
    #expect(fast.w > 1.2 && resting.w < 0.8)
    let skid = Jellyfish.trailing(up, way: SIMD3(mean * d, 0, 0), d: d, mean: mean, sp) // turned to up, still going right
    #expect(skid.x < 0 && skid.y < 0)
}

/// One moon jelly's speed through a run of pulses: each stroke carries it the distance it should, and it glides on
/// between them, never under 0.3 of its mean speed nor over 2.3 times it (a real one peaks at about twice: Gemmell
/// 2013). Its speed used to be set afresh from the pulse's phase, and fell to nothing for a quarter of every pulse.
@MainActor @Test func jellyfishGlideBetweenStrokes() {
    let sp = Jellyfish.moon, reach = sp.perPulse * 0.15
    var way = SIMD3<Double>.zero, speeds: [Double] = []
    for k in 0..<Int(10 * sp.period / Jellyfish.step) {
        let t = Double(k) * Jellyfish.step
        way = Jellyfish.carried(way, axis: SIMD3(0, 1, 0), tau: t.truncatingRemainder(dividingBy: sp.period), period: sp.period, reach: reach, sp)
        if t >= 5 * sp.period { speeds.append(way.y) }
    }
    let mean = speeds.reduce(0, +) / Double(speeds.count)
    #expect(abs(mean * sp.period / reach - 1) < 0.03)
    #expect(speeds.min()! > 0.3 * mean && speeds.max()! < 2.3 * mean)
}

/// Draws the lit tank and the crystal jellies twice, the second time with half a bell radius of room added round
/// every sprite's box, and checks the two pictures match. The box is cut close to what the shader draws, since every
/// pixel of it costs: so a part that grows (a longer fringe, a wider margin) has to grow the box with it, or it is
/// cut off square. A few pixels differ by rounding, where a strand's edge falls; a cut differs by hundreds.
@MainActor @Test func jellyfishBoxHoldsWhatIsDrawn() throws {
    let device = try #require(MTLCreateSystemDefaultDevice()), queue = try #require(device.makeCommandQueue())
    let (w, h) = (1512, 982) // a pixel a point: enough to see a cut, and a quarter of the bytes to compare
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    let texture = try #require(device.makeTexture(descriptor: descriptor)), pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = texture
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    defer { ["jellyfish.seed", "jellyfish.look"].forEach(UserDefaults.standard.removeObject); Jellyfish.slack = 0 }
    for look in [4, 6] { // the lit tank's moon jellies, and the crystal jellies
        UserDefaults.standard.set(22, forKey: "jellyfish.seed")
        UserDefaults.standard.set(look, forKey: "jellyfish.look")
        func picture(slack: Double) throws -> [UInt8] {
            Jellyfish.slack = slack
            let renderer = SKRenderer(device: device)
            renderer.scene = Jellyfish(size: CGSize(width: w, height: h))
            renderer.update(atTime: 1000)
            let buffer = try #require(queue.makeCommandBuffer())
            renderer.render(withViewport: CGRect(x: 0, y: 0, width: w, height: h), commandBuffer: buffer, renderPassDescriptor: pass)
            buffer.commit()
            buffer.waitUntilCompleted()
            var pixels = [UInt8](repeating: 0, count: w * h * 4)
            texture.getBytes(&pixels, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
            return pixels
        }
        let tight = try picture(slack: 0), roomy = try picture(slack: 0.5)
        let differing = zip(tight, roomy).count { abs(Int($0) - Int($1)) > 6 }
        print("jellyfish look \(look): \(differing) of the picture's bytes differ with a roomier box")
        #expect(differing < 50)
    }
}

/// The jellies' light is added to the lit tank's blue, as light through glass, and screened on the dark looks' black,
/// where added it piled overlapping bells into the brightest thing on screen; screened on the blue, they went milky.
@MainActor @Test func jellyfishScreensInTheDark() {
    defer { ["jellyfish.seed", "jellyfish.look"].forEach(UserDefaults.standard.removeObject) }
    UserDefaults.standard.set(22, forKey: "jellyfish.seed")
    for (look, blend) in [(4, SKBlendMode.add), (5, .screen), (6, .screen)] { // the lit tank, the glow, the crystal jellies
        UserDefaults.standard.set(look, forKey: "jellyfish.look")
        let jellies = Jellyfish(size: CGSize(width: 1512, height: 982)).children.compactMap { $0 as? SKSpriteNode }.filter { $0.zPosition > -10 }
        #expect(!jellies.isEmpty && jellies.allSatisfy { $0.blendMode == blend })
    }
}
