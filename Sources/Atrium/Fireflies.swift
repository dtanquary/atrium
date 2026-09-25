import SpriteKit

@MainActor func fireflies(size: CGSize) -> SKScene { Fireflies(size: size) }

/// A forest at dusk: treelines receding into violet fog, with fireflies drifting and blinking between them.
final class Fireflies: SKScene {
    private struct Firefly {
        let node: SKSpriteNode
        let home: CGPoint
        let wander: [CGFloat] // speeds and phases for the drift
        let period: CGFloat
        let offset: CGFloat
    }

    private var flies: [Firefly] = []
    private var time: TimeInterval = 0
    private var lastTime: TimeInterval?

    override func sceneDidLoad() {
        let w = size.width, h = size.height
        let fog = rgb(0.34, 0.27, 0.46)

        addChild(backdrop(size, [
            (0.25, rgb(0.62, 0.40, 0.52)), (0.5, rgb(0.33, 0.22, 0.45)), (0.8, rgb(0.12, 0.09, 0.26)), (1, rgb(0.05, 0.04, 0.14)),
        ]))
        addStars(count: 40, above: h * 0.6, maxAlpha: 0.6)

        // Far to near: each treeline is darker, larger and lower, with fog pooling at the foot of the ones behind it.
        let layers: [(base: CGFloat, trees: ClosedRange<CGFloat>, spacing: ClosedRange<CGFloat>, shade: CGFloat, pines: Double, clearing: ClosedRange<CGFloat>?)] = [
            (0.34, 0.10...0.20, 12...26, 0.25, 0.7, nil),
            (0.27, 0.16...0.30, 20...42, 0.5, 0.6, nil),
            (0.17, 0.26...0.46, 45...90, 0.75, 0.6, w * 0.42...w * 0.55),
            (0.05, 0.50...0.85, 150...300, 0.97, 1, w * 0.3...w * 0.68),
        ]
        for (i, layer) in layers.enumerated() {
            let color = mixRGB(fog, rgb(0.02, 0.015, 0.05), layer.shade)
            let strip = treeline(width: w, base: h * layer.base, hills: h * 0.025, trees: h * layer.trees.lowerBound...h * layer.trees.upperBound,
                                 spacing: layer.spacing, color: color, pineChance: layer.pines, clearing: layer.clearing,
                                 resolution: i < 2 ? 0.5 : 1)
            strip.zPosition = CGFloat(i * 10)
            addChild(strip)

            if i < layers.count - 1 {
                let mist = SKSpriteNode(texture: verticalGradient([(0, fog.copy(alpha: 0.55)!), (1, fog.copy(alpha: 0)!)]),
                                        size: CGSize(width: w, height: h * 0.16))
                mist.anchorPoint = .zero
                mist.position = CGPoint(x: 0, y: h * layers[i + 1].base - h * 0.01)
                mist.zPosition = CGFloat(i * 10 + 5)
                addChild(mist)
            }
        }

        let grass = grassFringe(width: w, height: h * 0.09, color: rgb(0.015, 0.01, 0.035))
        grass.zPosition = 45
        addChild(grass)

        // Fireflies live in the gaps between the nearer treelines, low to the ground.
        let glow = fireflyGlow()
        for _ in 0..<Int(w / 14) {
            let depth = [1, 2, 2, 3, 3, 3].randomElement()! // which treeline they hover in front of
            let scale = [0.35, 0.55, 0.8, 1.2][depth]
            let node = SKSpriteNode(texture: glow, size: CGSize(width: 64 * scale, height: 64 * scale))
            node.blendMode = .add
            node.zPosition = CGFloat(depth * 10 + 6)
            node.alpha = 0
            addChild(node)
            let floor = h * layers[depth].base
            flies.append(Firefly(node: node,
                                 home: CGPoint(x: .random(in: 0...w), y: .random(in: floor + 20...floor + h * 0.3)),
                                 wander: (0..<8).map { i in i < 4 ? .random(in: 0.05...0.25) : .random(in: 0...(2 * .pi)) },
                                 period: .random(in: 2.5...7), offset: .random(in: 0...7)))
        }
        place()
    }

    override func update(_ currentTime: TimeInterval) {
        time += frameTime(currentTime, &lastTime)
        place()
    }

    /// Lissajous-style drift around each firefly's home, plus a blink: dark most of the cycle, then a soft flash.
    private func place() {
        let t = CGFloat(time)
        for fly in flies {
            let v = fly.wander
            fly.node.position = CGPoint(x: fly.home.x + 60 * sin(v[0] * t + v[4]) + 25 * sin(v[1] * 2.3 * t + v[5]),
                                        y: fly.home.y + 30 * sin(v[2] * t + v[6]) + 12 * sin(v[3] * 3.1 * t + v[7]))
            let phase = (t + fly.offset).truncatingRemainder(dividingBy: fly.period) / 0.9
            fly.node.alpha = phase < 1 ? pow(sin(.pi * phase), 2) : 0.08
        }
    }

    private func addStars(count: Int, above: CGFloat, maxAlpha: CGFloat) {
        let dot = softDot()
        for _ in 0..<count {
            let star = SKSpriteNode(texture: dot, size: CGSize(width: 3, height: 3))
            star.setScale(.random(in: 0.5...1.2))
            star.alpha = .random(in: 0.2...maxAlpha)
            star.position = CGPoint(x: .random(in: 0...size.width), y: .random(in: above...size.height))
            addChild(star)
        }
    }

    private func fireflyGlow() -> SKTexture {
        radialGlow(diameter: 64, stops: [
            (0, rgb(1, 1, 0.85)), (0.07, rgb(0.9, 1, 0.45)), (0.2, rgb(0.7, 0.95, 0.25, 0.35)), (0.5, rgb(0.55, 0.85, 0.15, 0.08)), (1, rgb(0.5, 0.8, 0.1, 0)),
        ])
    }
}

// MARK: - Shared by the nature scenes (Fireflies, Campfire, Murmuration, Game of Life)

/// Seconds since the previous frame, clamped so a paused or restarted clock (wake from sleep, a new time base) can't
/// produce a huge or negative jump.
func frameTime(_ now: TimeInterval, _ last: inout TimeInterval?) -> TimeInterval {
    defer { last = now }
    guard let last else { return 1.0 / 30 }
    return min(max(now - last, 0), 0.1)
}

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

func mixRGB(_ a: CGColor, _ b: CGColor, _ t: CGFloat) -> CGColor {
    let x = a.components!, y = b.components!
    return rgb(x[0] + (y[0] - x[0]) * t, x[1] + (y[1] - x[1]) * t, x[2] + (y[2] - x[2]) * t, x[3] + (y[3] - x[3]) * t)
}

/// A thin gradient texture, bottom (0) to top (1), for stretching over a sprite of any size.
func verticalGradient(_ stops: [(CGFloat, CGColor)]) -> SKTexture {
    paint(CGSize(width: 4, height: 256)) { ctx in
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: stops.map(\.1) as CFArray,
                                  locations: stops.map(\.0))!
        ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: 256), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }
}

/// A full-screen sky gradient, dithered so dark skies don't band.
@MainActor func backdrop(_ size: CGSize, _ stops: [(CGFloat, CGColor)]) -> SKSpriteNode {
    let sky = SKSpriteNode(texture: verticalGradient(stops), size: size)
    sky.anchorPoint = .zero
    sky.shader = ditherShader
    return sky
}

@MainActor private let ditherShader = SKShader(source: """
    void main() {
        vec4 c = texture2D(u_texture, v_tex_coord);
        float n = fract(sin(dot(gl_FragCoord.xy, vec2(12.9898, 78.233))) * 43758.5453);
        gl_FragColor = vec4(c.rgb + (n - 0.5) / 128.0, c.a);
    }
    """)

/// A round glow fading out from the centre, for light sources drawn with additive blending.
func radialGlow(diameter: CGFloat, stops: [(CGFloat, CGColor)]) -> SKTexture {
    paint(CGSize(width: diameter, height: diameter)) { ctx in
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: stops.map(\.1) as CFArray,
                                  locations: stops.map(\.0))!
        let c = CGPoint(x: diameter / 2, y: diameter / 2)
        ctx.drawRadialGradient(gradient, startCenter: c, startRadius: 0, endCenter: c, endRadius: diameter / 2, options: [])
    }
}

/// A small white dot with a soft edge: stars, embers, birds.
func softDot() -> SKTexture {
    radialGlow(diameter: 8, stops: [(0, rgb(1, 1, 1)), (0.45, rgb(1, 1, 1, 0.9)), (1, rgb(1, 1, 1, 0))])
}

/// A full-width strip of tree silhouettes on rolling ground, solid down to the bottom of the screen.
/// `resolution` below 1 paints a smaller texture and stretches it, which softens distant layers and saves memory.
@MainActor func treeline(width: CGFloat, base: CGFloat, hills: CGFloat, trees: ClosedRange<CGFloat>, spacing: ClosedRange<CGFloat>,
                         color: CGColor, pineChance: Double, clearing: ClosedRange<CGFloat>? = nil,
                         resolution: CGFloat = 1) -> SKSpriteNode {
    let height = base + hills + trees.upperBound * 1.05
    let phase = CGFloat.random(in: 0...100), wavelength = CGFloat.random(in: 260...420)
    let ground = { (x: CGFloat) in base + hills * (sin(x / wavelength + phase) + 0.5 * sin(x / wavelength * 2.7 + phase * 1.3)) / 1.5 }
    let texture = paint(CGSize(width: width * resolution, height: height * resolution)) { ctx in
        ctx.scaleBy(x: resolution, y: resolution)
        ctx.setFillColor(color)
        ctx.move(to: .zero)
        for x in stride(from: 0, through: width + 20, by: 20) { ctx.addLine(to: CGPoint(x: x, y: ground(x))) }
        ctx.addLine(to: CGPoint(x: width + 20, y: 0))
        ctx.fillPath()
        var x = CGFloat.random(in: -30...0)
        while x < width + 30 {
            let h = CGFloat.random(in: trees)
            if clearing?.contains(x) == true {
                // leave it open
            } else if Double.random(in: 0..<1) < pineChance {
                pine(ctx, x: x, base: ground(x), height: h)
            } else {
                broadleaf(ctx, x: x, base: ground(x), height: h)
            }
            x += CGFloat.random(in: spacing)
        }
    }
    let sprite = SKSpriteNode(texture: texture, size: CGSize(width: width, height: height))
    sprite.anchorPoint = .zero
    return sprite
}

/// A conifer: short trunk and stacked, drooping tiers that narrow toward a spire.
func pine(_ ctx: CGContext, x: CGFloat, base: CGFloat, height: CGFloat) {
    ctx.fill(CGRect(x: x - height * 0.018, y: base - 4, width: height * 0.036, height: height * 0.3))
    let tiers = 8
    for i in 0..<tiers {
        let t = CGFloat(i) / CGFloat(tiers)
        let y = base + height * (0.1 + 0.78 * t)
        let half = height * 0.2 * (1 - t * 0.88) * .random(in: 0.85...1.15)
        let rise = height * 0.2
        ctx.move(to: CGPoint(x: x - half, y: y - rise * 0.12))
        ctx.addQuadCurve(to: CGPoint(x: x, y: y + rise), control: CGPoint(x: x - half * 0.35, y: y + rise * 0.2))
        ctx.addQuadCurve(to: CGPoint(x: x + half, y: y - rise * 0.12), control: CGPoint(x: x + half * 0.35, y: y + rise * 0.2))
        ctx.closePath()
    }
    ctx.fillPath()
}

/// A leafy tree: trunk, a couple of limbs, and a ragged canopy built from many small overlapping clumps.
func broadleaf(_ ctx: CGContext, x: CGFloat, base: CGFloat, height: CGFloat) {
    let trunk = height * 0.022
    ctx.fill(CGRect(x: x - trunk, y: base - 4, width: trunk * 2, height: height * 0.6))
    let r = height * 0.17, cy = base + height * 0.68
    for side in [-1.0, 1.0] {
        ctx.move(to: CGPoint(x: x, y: base + height * 0.35))
        ctx.addLine(to: CGPoint(x: x + side * r * 0.9, y: cy - r * 0.2))
        ctx.addLine(to: CGPoint(x: x + side * r * 0.9 + trunk * 0.8, y: cy - r * 0.2))
        ctx.addLine(to: CGPoint(x: x + trunk * 0.5, y: base + height * 0.3))
        ctx.fillPath()
    }
    for _ in 0..<40 {
        let angle = CGFloat.random(in: 0...(2 * .pi)), reach = sqrt(CGFloat.random(in: 0...1))
        let cx = x + cos(angle) * reach * r * 1.3, cy = cy + sin(angle) * reach * r * 0.95
        let rr = r * .random(in: 0.12...0.3)
        ctx.fillEllipse(in: CGRect(x: cx - rr, y: cy - rr, width: rr * 2, height: rr * 2))
    }
}

/// Blades of grass along the bottom edge, as a silhouette strip.
@MainActor func grassFringe(width: CGFloat, height: CGFloat, color: CGColor) -> SKSpriteNode {
    let texture = paint(CGSize(width: width, height: height)) { ctx in
        ctx.setFillColor(color)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height * 0.18))
        for _ in 0..<Int(width / 2.5) {
            let x = CGFloat.random(in: 0...width), tall = height * .random(in: 0.2...1) * .random(in: 0.4...1)
            let lean = CGFloat.random(in: -0.35...0.35) * tall, w = CGFloat.random(in: 1.2...3)
            ctx.move(to: CGPoint(x: x - w, y: 0))
            ctx.addQuadCurve(to: CGPoint(x: x + lean, y: tall), control: CGPoint(x: x, y: tall * 0.6))
            ctx.addQuadCurve(to: CGPoint(x: x + w, y: 0), control: CGPoint(x: x + w * 0.5, y: tall * 0.5))
            ctx.fillPath()
        }
    }
    let sprite = SKSpriteNode(texture: texture, size: CGSize(width: width, height: height))
    sprite.anchorPoint = .zero
    return sprite
}
