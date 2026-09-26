import SpriteKit

@MainActor func fireflies(size: CGSize) -> SKScene { Fireflies(size: size) }

/// A meadow at blue hour full of fireflies, painted in gouache on canvas. Each firefly flies its own slow path over
/// the grass and flashes every few seconds as it goes, so the field twinkles the way a real one does.
final class Fireflies: SKScene {
    nonisolated static let knobs = [
        Knob(key: "fireflies.density", label: "Fireflies", range: 0.25...2, standard: 1, format: .times),
    ]

    /// One firefly, in metres: across from the middle of the view, up from the grass, and away from the eye.
    private struct Fly {
        let node: SKSpriteNode
        var x: CGFloat = 0, y: CGFloat = 0, d: CGFloat = 1
        var vx: CGFloat = 0, vd: CGFloat = 0 // its drift between flashes, m/s
        var next: CGFloat // when its next flash starts
        let period: CGFloat
    }

    // The view: the eye 1.2 m above the grass, the horizon at 46% of the height, a focal length of 1.2 heights.
    private let eye: CGFloat = 1.2, horizon: CGFloat = 0.46, focal: CGFloat = 1.2
    // The meadow runs from just below the screen back to the treeline, in metres. Grass is painted in bands.
    private let nearest: CGFloat = 2.5, treeline: CGFloat = 60, grassBands: [CGFloat] = [2.5, 3.4, 4.6, 6.2]
    private let flash: CGFloat = 1.4, pool = 1200 // twice the standard count, for the density knob

    private var flies: [Fly] = []
    private var time: TimeInterval = 0
    private var lastTime: TimeInterval?

    override func sceneDidLoad() {
        let sizeUniform = SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)])
        // Measured down the painting: olive grass, the darkest ground, a violet-indigo band, slate teal at the top.
        func hex(_ v: Int) -> CGColor { rgb(CGFloat(v >> 16) / 255, CGFloat(v >> 8 & 255) / 255, CGFloat(v & 255) / 255) }
        let sky = SKSpriteNode(texture: verticalGradient([
            (0, hex(0x3f3e26)), (0.1, hex(0x3b3b20)), (0.2, hex(0x383a21)), (0.25, hex(0x3a3a28)), (0.28, hex(0x312f25)),
            (0.37, hex(0x2d2c29)), (0.44, hex(0x2f302b)), (0.47, hex(0x2e2f2f)), (0.53, hex(0x2b2a33)), (0.62, hex(0x292935)),
            (0.72, hex(0x2f3a40)), (0.78, hex(0x344448)), (0.845, hex(0x3f5258)), (0.91, hex(0x445b64)), (1, hex(0x526973)),
        ]), size: size)
        sky.anchorPoint = .zero
        sky.zPosition = -1000
        sky.shader = SKShader(source: shaderCommon + Self.skySource, uniforms: [sizeUniform, SKUniform(name: "u_horizon", float: Float(horizon))])
        addChild(sky)

        for (a, b) in zip(grassBands, grassBands.dropFirst()) { addChild(grass(from: a, to: b)) }

        let canvas = SKSpriteNode(color: .gray, size: size)
        canvas.anchorPoint = .zero
        canvas.zPosition = 1000
        canvas.blendMode = .multiplyX2
        canvas.shader = SKShader(source: shaderCommon + Self.canvasSource, uniforms: [sizeUniform])
        addChild(canvas)

        let shader = SKShader(source: shaderCommon + Self.flySource)
        shader.attributes = [SKAttribute(name: "a_fly", type: .vectorFloat3)]
        for _ in 0..<pool {
            let node = SKSpriteNode(color: .white, size: CGSize(width: 1, height: 1))
            node.shader = shader
            node.isHidden = true
            addChild(node)
            var fly = Fly(node: node, next: .random(in: 0...6), period: .random(in: 4.5...6.5))
            spawn(&fly)
            flies.append(fly)
        }
    }

    override func update(_ currentTime: TimeInterval) {
        time += frameTime(currentTime, &lastTime)
        let t = CGFloat(time), active = Int(CGFloat(pool) / 2 * Self.knobs[0].value)
        for i in flies.indices where t >= flies[i].next {
            let u = (t - flies[i].next) / flash
            if u >= 1 || i >= active {
                rest(&flies[i])
                continue
            }
            // A slow flash while it swoops, a little dip then a climb, as Photinus does: held, with quick fades, since
            // paint caught half faded reads as a khaki blot.
            let fly = flies[i], s = u * flash
            fly.node.position = project(fly.x + fly.vx * s, fly.y + 0.1 * (1.6 * u * u - 0.6 * u), fly.d + fly.vd * s)
            fly.node.alpha = smoothstep(0, 0.08, u) * (1 - smoothstep(0.85, 1, u))
            fly.node.isHidden = false
        }
    }

    /// Where a point in the meadow lands on screen.
    private func project(_ x: CGFloat, _ y: CGFloat, _ d: CGFloat) -> CGPoint {
        let f = size.height * focal
        return CGPoint(x: size.width / 2 + f * x / d, y: size.height * horizon + f * (y - eye) / d)
    }

    /// Puts a firefly somewhere new, heading any way. Where it lands on screen follows the painting: thickest just
    /// over the grass tops, thinning up into the dark band, none in the upper sky. It's then placed in the meadow at
    /// the distance that puts it there: below eye height over the field, or above it against the sky.
    private func spawn(_ fly: inout Fly) {
        let f = size.height * focal, level = size.height * horizon
        let counts: [CGFloat] = [16, 56, 59, 42, 28, 18, 5] // dots in each tenth of the height, from the bottom
        var pick = CGFloat.random(in: 0..<counts.reduce(0, +)), tenth = 0
        while pick >= counts[tenth] { pick -= counts[tenth]; tenth += 1 }
        let target = (CGFloat(tenth) + .random(in: 0...1)) * 0.1 * size.height
        fly.y = target < level ? .random(in: 0.1...eye - 0.15) : .random(in: eye + 0.2...eye + 1.5)
        fly.d = min(max(f * abs(fly.y - eye) / max(abs(target - level), 2), nearest), treeline)
        let reach = size.width / 2 / f * fly.d * 1.1
        fly.x = .random(in: -reach...reach)
        let heading = CGFloat.random(in: 0...(2 * .pi)), speed = CGFloat.random(in: 0.04...0.12)
        fly.vx = cos(heading) * speed
        fly.vd = sin(heading) * speed
        dress(fly)
    }

    /// After a flash: dark again, flying on and turning a little until the next, or somewhere new once it's out of view.
    private func rest(_ fly: inout Fly) {
        fly.node.isHidden = true
        let gap = fly.period * .random(in: 0.85...1.15), turn = CGFloat.random(in: -0.8...0.8)
        fly.x += fly.vx * gap
        fly.d += fly.vd * gap
        fly.next += gap
        (fly.vx, fly.vd) = (fly.vx * cos(turn) - fly.vd * sin(turn), fly.vx * sin(turn) + fly.vd * cos(turn))
        if fly.d < nearest || fly.d > treeline || abs(project(fly.x, 0, fly.d).x - size.width / 2) > size.width * 0.55 {
            spawn(&fly)
        } else {
            dress(fly)
        }
    }

    /// Dresses a firefly as one of the painting's marks. Dabs are sized as measured there (a median of 1% of the
    /// height across, with a long tail of big ones), only a little bigger nearer, each with a faint glow of paint.
    /// Some of the bigger ones sit in a pale stain. Far ones are dim. Now and then there's a stain with no dab in
    /// it, a firefly out of focus.
    private func dress(_ fly: Fly) {
        let spread = (CGFloat.random(in: -1...1) + .random(in: -1...1) + .random(in: -1...1)) * 0.45
        var r = size.height * 0.005 * exp(spread) * min(max(pow(8 / fly.d, 0.3), 0.75), 1.3)
        let big = r > size.height * 0.005, roll = CGFloat.random(in: 0...1)
        let kind: CGFloat
        if roll < 0.04 {
            kind = 5 // a ghost stain
            r = size.height * .random(in: 0.0075...0.028)
        } else if fly.d > 25 {
            kind = 4 // dim and far
            r = .random(in: 1...1.6)
        } else {
            kind = CGFloat.random(in: 0...1) < (big ? 0.2 : 0.03) ? 1 : 0
        }
        let extent = r * [2.7, 4.4, 0, 0, 1.1, 1.3][Int(kind)] + 1
        fly.node.size = CGSize(width: extent * 2, height: extent * 2)
        fly.node.zPosition = 100 - fly.d
        fly.node.setValue(SKAttributeValue(vectorFloat3: [Float(r), Float(extent), Float(kind + .random(in: 0..<0.99))]), forAttribute: "a_fly")
    }

    /// Grass rooted between two distances, as the painting's strokes: near-vertical tapered dabs of olive or (one in
    /// six) bluish sage, in clumps of three to eight, mostly leaning a touch right. There's no highlight at the tips;
    /// the light comes from dry-brush skips along each stroke (`bristleSource`). Further clumps sink toward the ground.
    private func grass(from a: CGFloat, to b: CGFloat) -> SKSpriteNode {
        let f = size.height * focal, ground = size.height * horizon, tallest: CGFloat = 0.4
        let height = min(ground + f * (tallest - eye) / b + 4, size.height)
        func hex(_ v: Int) -> CGColor { rgb(CGFloat(v >> 16) / 255, CGFloat(v >> 8 & 255) / 255, CGFloat(v & 255) / 255) }
        let sages = [hex(0x56614e), hex(0x56614e), hex(0x5e6955), hex(0x6d7c69), hex(0x829480), hex(0x5c6f5f)], soil = hex(0x3a3b25)
        let texture = paint(CGSize(width: size.width / 2, height: height / 2)) { ctx in
            ctx.scaleBy(x: 0.5, y: 0.5) // half resolution softens the strokes
            for _ in 0..<Int(22 * size.width / f * (b * b - a * a) / 2) {
                let d = sqrt(a * a + .random(in: 0...1) * (b * b - a * a)), haze = (d - a) / (b - a) * 0.25 + (a - grassBands[0]) / 6
                let clump = CGFloat.random(in: -10...size.width + 10), sway = CGFloat.random(in: -0.12...0.2)
                let paint = mixRGB(CGFloat.random(in: 0...1) < 0.16 ? hex(0x5c6f5f) : sages.randomElement()!, soil, min(haze, 0.8))
                for _ in 0..<Int.random(in: 3...8) {
                    // Roots buried at random depths, so the bases don't line up along the band.
                    let tall = f * .random(in: 0.18...tallest) / d, wide = f * .random(in: 0.006...0.011) / d
                    let x = clump + f * .random(in: -0.04...0.04) / d, root = ground - f * eye / d - tall * .random(in: 0...0.35)
                    let lean = tall * (sway + .random(in: -0.1...0.1))
                    ctx.setFillColor(paint.copy(alpha: .random(in: 0.8...0.95))!)
                    // A flick of the brush: pointed at both ends, widest a third of the way up.
                    ctx.move(to: CGPoint(x: x, y: root))
                    ctx.addQuadCurve(to: CGPoint(x: x + lean, y: root + tall), control: CGPoint(x: x + lean * 0.3 - wide * 2, y: root + tall * 0.35))
                    ctx.addQuadCurve(to: CGPoint(x: x, y: root), control: CGPoint(x: x + lean * 0.3 + wide * 2, y: root + tall * 0.3))
                    ctx.fillPath()
                }
            }
        }
        let sprite = SKSpriteNode(texture: texture, size: CGSize(width: size.width, height: height))
        sprite.anchorPoint = .zero
        sprite.zPosition = 100 - (a + b) / 2
        sprite.shader = SKShader(source: shaderCommon + Self.bristleSource,
                                 uniforms: [SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(height)])])
        return sprite
    }

    /// The painted sky and field: the gradient from the painting, laid on in broad strokes across, with a soft
    /// treeline dabbed in along the horizon.
    private static let skySource = """
    void main() {
        vec2 pts = v_tex_coord * u_size;
        float stroke = noise(pts * vec2(0.003, 0.05)) + 0.5 * noise(pts * vec2(0.008, 0.11));
        vec3 c = texture2D(u_texture, vec2(0.5, v_tex_coord.y + (stroke - 0.75) * 0.03)).rgb;
        c *= 0.96 + 0.08 * noise(pts * vec2(0.02, 0.25));
        float crown = u_horizon + 0.03 + 0.05 * fbm(vec2(pts.x * 0.004, 1.0)) + 0.012 * noise(vec2(pts.x * 0.04, 5.0));
        crown += 0.006 * (noise(pts * vec2(0.08, 0.3)) - 0.5);
        float trees = smoothstep(crown + 0.003, crown - 0.003, v_tex_coord.y) * smoothstep(u_horizon - 0.05, u_horizon, v_tex_coord.y);
        c = mix(c, vec3(0.115, 0.125, 0.15) * (0.9 + 0.2 * noise(pts * 0.05)), trees * 0.9);
        gl_FragColor = vec4(c, 1.0);
    }
    """

    /// Dry-brush marks along the grass strokes: streaks where the bristles left less paint.
    private static let bristleSource = """
    void main() {
        vec2 pts = v_tex_coord * u_size;
        gl_FragColor = texture2D(u_texture, v_tex_coord) * (0.6 + 0.4 * noise(pts * vec2(0.6, 0.035)));
    }
    """

    /// The canvas, multiplied over everything at 2x, so 0.5 leaves a colour as it is. As measured in the painting:
    /// mostly a fine speckle at about a point, a faint weave of threads about 5 pt apart, and paint mottled over
    /// 10–40 pt.
    private static let canvasSource = """
    void main() {
        vec2 pts = v_tex_coord * u_size;
        float speck = hash42(floor(pts)).x - 0.5;
        float weave = sin(pts.x * 1.26) * sin(pts.y * 1.09);
        float mottle = noise(pts * 0.04) + 0.5 * noise(pts * 0.1) - 0.75;
        gl_FragColor = vec4(vec3(0.5 * (1.0 + 0.2 * speck + 0.025 * weave + 0.06 * mottle)), 1.0);
    }
    """

    /// A firefly as one of the painting's marks, faded by the node's alpha. `a_fly` is its radius and the sprite's
    /// half-width in points, then its kind plus a seed in the fraction: 0 a cream dab with a soft, slightly wobbly
    /// edge and a faint glow of paint around it, 1 the same in a stain, 4 a dim far dab, and 5 a stain alone. A stain
    /// is a flat, pale grey-teal wash about 2.6 times the dab's size, a little off centre, with a ragged edge and
    /// grainy pigment. (Torn dry-brush bursts with spatter, measured in the painting, read as paint splatters.)
    private static let flySource = """
    void main() {
        float r0 = a_fly.x, kind = floor(a_fly.z), seed = fract(a_fly.z) * 64.0;
        float ghost = step(4.5, kind), dim = step(3.5, kind) * (1.0 - ghost), stained = max(mod(kind, 2.0) * (1.0 - dim), ghost);
        vec2 q = (v_tex_coord - 0.5) * 2.0 * a_fly.y;
        float r = length(q);
        vec2 dir = q / max(r, 0.001);
        float edge = r0 * (0.92 + 0.16 * noise(dir * 1.5 + seed));
        float dab = smoothstep(edge + 0.5 + 0.2 * r0, edge - 0.3 * r0, r) * (1.0 - ghost);
        float glow = 0.16 * smoothstep(r0 * 2.6, r0 * 0.8, r) * (1.0 - ghost) * (1.0 - dim);
        vec2 s = q - (vec2(hash11(seed), hash11(seed + 3.0)) - 0.5) * 0.5 * r0 * (1.0 - ghost);
        float rs = length(s);
        vec2 ds = s / max(rs, 0.001);
        float reach = mix(r0 * 2.6, r0, ghost) * (0.85 + 0.3 * noise(ds * 2.0 + seed) + 0.12 * noise(ds * 7.0 + seed));
        float stain = smoothstep(reach, reach * 0.8, rs) * (1.0 + 0.15 * smoothstep(reach * 0.5, 0.0, rs))
                    * (0.8 + 0.4 * hash42(floor(q * 0.7) + seed).x) * stained;
        vec4 under = vec4(0.353, 0.416, 0.416, 1.0) * 0.3 * stain;
        under = vec4(1.0, 0.94, 0.7, 1.0) * glow + under * (1.0 - glow);
        vec4 paint = vec4(mix(vec3(0.996, 0.941, 0.612), vec3(0.612, 0.576, 0.424), dim), 1.0) * dab;
        gl_FragColor = (under * (1.0 - paint.a) + paint) * v_color_mix.a;
    }
    """
}

private func smoothstep(_ a: CGFloat, _ b: CGFloat, _ x: CGFloat) -> CGFloat {
    let t = min(max((x - a) / (b - a), 0), 1)
    return t * t * (3 - 2 * t)
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
