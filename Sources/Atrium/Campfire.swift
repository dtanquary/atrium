import SpriteKit

@MainActor func campfire(size: CGSize) -> SKScene { Campfire(size: size) }

/// A campfire in a clearing at night: flames, embers and smoke from emitters, a stone ring and logs,
/// and a warm light on the ground and trees that flickers with the fire.
final class Campfire: SKScene {
    private var groundLight: SKSpriteNode!
    private var halo: SKSpriteNode!
    private var flames: [SKEmitterNode] = []
    private var time: TimeInterval = 0
    private var lastTime: TimeInterval?

    override func sceneDidLoad() {
        let w = size.width, h = size.height
        let fire = CGPoint(x: w * 0.5, y: h * 0.2)

        addChild(backdrop(size, [(0.3, rgb(0.08, 0.075, 0.14)), (0.6, rgb(0.03, 0.035, 0.09)), (1, rgb(0.01, 0.012, 0.04))]))
        addStars()

        let woods = treeline(width: w, base: h * 0.4, hills: h * 0.015, trees: h * 0.06...h * 0.15, spacing: 9...22,
                             color: rgb(0.025, 0.025, 0.045), pineChance: 0.8, resolution: 0.5)
        woods.zPosition = 2
        addChild(woods)
        let ground = SKSpriteNode(texture: verticalGradient([(0, rgb(0.03, 0.022, 0.02)), (0.75, rgb(0.025, 0.022, 0.035)), (1, rgb(0.025, 0.025, 0.045, 0))]),
                                  size: CGSize(width: w, height: h * 0.42))
        ground.anchorPoint = .zero
        ground.zPosition = 2.5
        addChild(ground)

        // Big pines framing the clearing, in front of the woods but still caught by the firelight.
        for (x0, heights) in [(CGFloat(0), [0.82, 0.62, 0.5]), (w * 0.72, [0.55, 0.86, 0.66])] {
            let side = paint(CGSize(width: w * 0.28, height: h * 0.95)) { ctx in
                ctx.setFillColor(rgb(0.015, 0.014, 0.025))
                for (i, tall) in heights.enumerated() {
                    pine(ctx, x: w * 0.28 * (0.12 + 0.36 * CGFloat(i)) + .random(in: -20...20), base: h * 0.26 + CGFloat(i % 2) * 14,
                         height: h * tall)
                }
            }
            let trees = SKSpriteNode(texture: side, size: CGSize(width: w * 0.28, height: h * 0.95))
            trees.anchorPoint = .zero
            trees.position = CGPoint(x: x0, y: 0)
            trees.zPosition = 3
            addChild(trees)
        }

        groundLight = SKSpriteNode(texture: radialGlow(diameter: 128, stops: [
            (0, rgb(1, 0.55, 0.22, 0.55)), (0.35, rgb(0.9, 0.35, 0.1, 0.22)), (1, rgb(0.6, 0.2, 0.05, 0)),
        ]), size: CGSize(width: w * 0.95, height: h * 0.5))
        groundLight.position = fire
        groundLight.blendMode = .add
        groundLight.zPosition = 4
        addChild(groundLight)

        addStones(around: fire, front: false, z: 5)
        addLogs(at: fire)
        addFlames(at: fire)
        addStones(around: fire, front: true, z: 8)
        addBench(at: CGPoint(x: w * 0.27, y: h * 0.12))
        addEmbersAndSmoke(at: fire)

        halo = SKSpriteNode(texture: radialGlow(diameter: 128, stops: [
            (0, rgb(1, 0.7, 0.35, 0.45)), (0.3, rgb(1, 0.45, 0.15, 0.15)), (1, rgb(1, 0.3, 0.1, 0)),
        ]), size: CGSize(width: 520, height: 520))
        halo.position = CGPoint(x: fire.x, y: fire.y + 70)
        halo.blendMode = .add
        halo.zPosition = 12
        addChild(halo)
        flicker()
    }

    override func update(_ currentTime: TimeInterval) {
        time += frameTime(currentTime, &lastTime)
        flicker()
    }

    /// Irregular brightness from a few unrelated sine waves, so the light never visibly loops.
    private func flicker() {
        let t = CGFloat(time)
        let f = 0.86 + 0.07 * sin(7.3 * t) + 0.05 * sin(12.9 * t + 1) + 0.03 * sin(23.1 * t + 2)
        groundLight.alpha = f
        groundLight.xScale = 0.97 + 0.03 * f
        halo.alpha = f
        for flame in flames { flame.xAcceleration = 35 * sin(1.7 * t) + 20 * sin(4.3 * t + 2) } // the flames lean and sway
    }

    private func addStars() {
        let dot = softDot()
        for i in 0..<Int(size.width / 6) {
            let star = SKSpriteNode(texture: dot, size: CGSize(width: 3, height: 3))
            star.setScale(.random(in: 0.5...1.3))
            star.alpha = .random(in: 0.15...0.85)
            star.position = CGPoint(x: .random(in: 0...size.width), y: .random(in: size.height * 0.42...size.height))
            star.zPosition = 1
            if i % 9 == 0 {
                let dim = SKAction.fadeAlpha(to: 0.15, duration: .random(in: 0.8...2.5))
                let bright = SKAction.fadeAlpha(to: star.alpha, duration: .random(in: 0.8...2.5))
                star.run(.repeatForever(.sequence([dim, bright])))
            }
            addChild(star)
        }
    }

    /// Half of the stone ring: the back half sits behind the flames, the front half in front of them.
    private func addStones(around fire: CGPoint, front: Bool, z: CGFloat) {
        let box = CGSize(width: 260, height: 80)
        let texture = paint(box) { ctx in
            let count = 14
            for i in 0..<count {
                let angle = CGFloat(i) / CGFloat(count) * 2 * .pi + 0.1
                guard (sin(angle) < 0) == front else { continue }
                let c = CGPoint(x: box.width / 2 + 100 * cos(angle), y: box.height / 2 + 22 * sin(angle))
                let rect = CGRect(x: c.x - .random(in: 16...22), y: c.y - 11, width: .random(in: 32...44), height: .random(in: 20...27))
                ctx.saveGState()
                ctx.addEllipse(in: rect)
                ctx.clip()
                // Back stones face the fire (lit low); front stones only catch it on their top edge.
                let colors = front ? [rgb(0.06, 0.05, 0.05), rgb(0.42, 0.3, 0.22)] : [rgb(0.62, 0.42, 0.28), rgb(0.14, 0.11, 0.1)]
                let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: [0, 1])!
                ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: rect.minY), end: CGPoint(x: 0, y: rect.maxY), options: [])
                ctx.restoreGState()
            }
        }
        let stones = SKSpriteNode(texture: texture, size: box)
        stones.position = CGPoint(x: fire.x, y: fire.y - 6)
        stones.zPosition = z
        addChild(stones)
    }

    /// Logs leaning into a teepee over a bed of glowing coals.
    private func addLogs(at fire: CGPoint) {
        let box = CGSize(width: 220, height: 150)
        let texture = paint(box) { ctx in
            let base = CGPoint(x: box.width / 2, y: 22)
            let coals = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                   colors: [rgb(1, 0.55, 0.15), rgb(0.7, 0.15, 0.02, 0.8), rgb(0.3, 0.05, 0, 0)] as CFArray, locations: [0, 0.5, 1])!
            ctx.saveGState()
            ctx.scaleBy(x: 1, y: 0.3)
            ctx.drawRadialGradient(coals, startCenter: CGPoint(x: base.x, y: base.y / 0.3), startRadius: 0,
                                   endCenter: CGPoint(x: base.x, y: base.y / 0.3), endRadius: 80, options: [])
            ctx.restoreGState()

            ctx.setLineCap(.round)
            for (dx, top) in [(-70.0, 105.0), (64, 112), (-30, 128), (28, 122)] as [(CGFloat, CGFloat)] {
                let foot = CGPoint(x: base.x + dx, y: base.y - 6), tip = CGPoint(x: base.x + dx * 0.08, y: top)
                ctx.setStrokeColor(rgb(0.13, 0.07, 0.04))
                ctx.setLineWidth(22)
                ctx.strokeLineSegments(between: [foot, tip])
                ctx.setStrokeColor(rgb(0.8, 0.34, 0.08, 0.85)) // the side facing the flames
                ctx.setLineWidth(6)
                ctx.strokeLineSegments(between: [CGPoint(x: foot.x - dx * 0.06, y: foot.y + 4), CGPoint(x: tip.x - dx * 0.02, y: tip.y - 8)])
            }
        }
        let logs = SKSpriteNode(texture: texture, size: box)
        logs.anchorPoint = CGPoint(x: 0.5, y: 0)
        logs.position = CGPoint(x: fire.x, y: fire.y - 22)
        logs.zPosition = 6
        addChild(logs)
    }

    /// Two layers of flame: a wide orange body and a narrow white-hot core.
    private func addFlames(at fire: CGPoint) {
        // A soft teardrop, taller than wide, so each particle reads as a tongue of flame.
        let tongue = paint(CGSize(width: 32, height: 64)) { ctx in
            ctx.scaleBy(x: 1, y: 2)
            let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                      colors: [rgb(1, 1, 1), rgb(1, 1, 1, 0.45), rgb(1, 1, 1, 0)] as CFArray, locations: [0, 0.4, 1])!
            ctx.drawRadialGradient(gradient, startCenter: CGPoint(x: 16, y: 13), startRadius: 0, endCenter: CGPoint(x: 16, y: 16),
                                   endRadius: 16, options: [])
        }
        for core in [false, true] {
            let flames = SKEmitterNode()
            flames.particleTexture = tongue
            flames.particleSize = CGSize(width: 40, height: 80)
            flames.particleBirthRate = core ? 55 : 130
            flames.particleLifetime = core ? 0.55 : 0.95
            flames.particleLifetimeRange = 0.4
            flames.particlePositionRange = CGVector(dx: core ? 36 : 76, dy: 8)
            flames.emissionAngle = .pi / 2
            flames.emissionAngleRange = 0.2
            flames.particleSpeed = core ? 95 : 140
            flames.particleSpeedRange = 40
            flames.yAcceleration = 110
            flames.particleScale = core ? 0.6 : 1
            flames.particleScaleRange = 0.35
            flames.particleScaleSpeed = -0.85
            flames.particleAlpha = core ? 0.6 : 0.65
            flames.particleAlphaSpeed = -0.7
            flames.particleColorBlendFactor = 1
            flames.particleColorSequence = SKKeyframeSequence(
                keyframeValues: core
                    ? [NSColor(red: 1, green: 0.98, blue: 0.85, alpha: 1), NSColor(red: 1, green: 0.8, blue: 0.3, alpha: 1), NSColor(red: 1, green: 0.45, blue: 0.1, alpha: 1)]
                    : [NSColor(red: 1, green: 0.8, blue: 0.35, alpha: 1), NSColor(red: 1, green: 0.42, blue: 0.08, alpha: 1),
                       NSColor(red: 0.75, green: 0.12, blue: 0.02, alpha: 1), NSColor(red: 0.2, green: 0.02, blue: 0, alpha: 1)],
                times: core ? [0, 0.5, 1] : [0, 0.3, 0.65, 1])
            flames.particleBlendMode = .add
            flames.position = CGPoint(x: fire.x, y: fire.y + 4)
            flames.zPosition = 7
            flames.advanceSimulationTime(2)
            addChild(flames)
            self.flames.append(flames)
        }
    }

    private func addEmbersAndSmoke(at fire: CGPoint) {
        let embers = SKEmitterNode()
        embers.particleTexture = softDot()
        embers.particleSize = CGSize(width: 4, height: 4)
        embers.particleBirthRate = 7
        embers.particleLifetime = 4
        embers.particleLifetimeRange = 2
        embers.particlePositionRange = CGVector(dx: 50, dy: 10)
        embers.emissionAngle = .pi / 2
        embers.emissionAngleRange = 0.6
        embers.particleSpeed = 110
        embers.particleSpeedRange = 50
        embers.yAcceleration = -12
        embers.particleScaleRange = 0.5
        embers.particleColor = NSColor(red: 1, green: 0.6, blue: 0.2, alpha: 1)
        embers.particleColorBlendFactor = 1
        embers.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [1, 0.9, 0], times: [0, 0.6, 1])
        embers.particleBlendMode = .add
        let drift = SKAction.moveBy(x: 14, y: 0, duration: 0.7)
        drift.timingMode = .easeInEaseOut
        embers.particleAction = .repeatForever(.sequence([drift, drift.reversed()]))
        embers.position = CGPoint(x: fire.x, y: fire.y + 20)
        embers.zPosition = 10
        embers.advanceSimulationTime(6)
        addChild(embers)

        let smoke = SKEmitterNode()
        smoke.particleTexture = radialGlow(diameter: 64, stops: [(0, rgb(1, 1, 1, 0.8)), (1, rgb(1, 1, 1, 0))])
        smoke.particleSize = CGSize(width: 70, height: 70)
        smoke.particleBirthRate = 5
        smoke.particleLifetime = 9
        smoke.particlePositionRange = CGVector(dx: 30, dy: 10)
        smoke.emissionAngle = .pi / 2
        smoke.emissionAngleRange = 0.2
        smoke.particleSpeed = 38
        smoke.particleSpeedRange = 10
        smoke.xAcceleration = 4
        smoke.particleScale = 1
        smoke.particleScaleSpeed = 0.45
        smoke.particleColor = NSColor(red: 0.5, green: 0.45, blue: 0.45, alpha: 1)
        smoke.particleColorBlendFactor = 1
        smoke.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 0.09, 0], times: [0, 0.15, 1])
        smoke.position = CGPoint(x: fire.x, y: fire.y + 110)
        smoke.zPosition = 11
        smoke.advanceSimulationTime(9)
        addChild(smoke)
    }

    /// A fallen log to sit on, lit along the side that faces the fire.
    private func addBench(at spot: CGPoint) {
        let box = CGSize(width: 300, height: 50)
        let texture = paint(box) { ctx in
            let body = CGPath(roundedRect: CGRect(x: 6, y: 6, width: box.width - 12, height: 34), cornerWidth: 17, cornerHeight: 17, transform: nil)
            ctx.addPath(body)
            ctx.clip()
            let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                      colors: [rgb(0.04, 0.025, 0.02), rgb(0.12, 0.07, 0.04), rgb(0.34, 0.17, 0.08)] as CFArray,
                                      locations: [0, 0.6, 1])!
            ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 6), end: CGPoint(x: 0, y: 40),
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            ctx.resetClip()
            // Cut end facing us, with growth rings.
            ctx.setFillColor(rgb(0.2, 0.12, 0.07))
            ctx.fillEllipse(in: CGRect(x: 2, y: 6, width: 22, height: 34))
            ctx.setStrokeColor(rgb(0.1, 0.06, 0.03))
            ctx.setLineWidth(1.5)
            for inset in [5.0, 10.0] { ctx.strokeEllipse(in: CGRect(x: 2 + inset * 0.6, y: 6 + inset, width: 22 - inset * 1.2, height: 34 - inset * 2)) }
        }
        let bench = SKSpriteNode(texture: texture, size: box)
        bench.position = spot
        bench.zRotation = -0.05
        bench.zPosition = 9
        addChild(bench)
    }
}
