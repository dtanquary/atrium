import SpriteKit

@MainActor func fireflies(size: CGSize) -> SKScene { Fireflies(size: size) }

/// A broad meadow at blue hour, a real photo relit for dusk, with fog drifting low over the grass and softening the
/// treeline. Fireflies glow as soft cream orbs, each flying its own slow path and flashing every few seconds, so
/// the field twinkles the way a real one does.
final class Fireflies: SKScene {
    nonisolated static let knobs = [
        Knob(key: "fireflies.density", label: "Fireflies", range: 0.25...2, standard: 1, format: .times),
        Knob(key: "fireflies.fog", label: "Fog", range: 0...1, standard: 0.5),
        Knob(key: "fireflies.speed", label: "Speed", range: 0.25...2, standard: 1, format: .times),
    ]

    /// One firefly, in metres: across from the middle of the view, up from the grass, and away from the eye.
    private struct Fly {
        let node: SKSpriteNode
        var x: CGFloat = 0, y: CGFloat = 0, d: CGFloat = 1
        var vx: CGFloat = 0, vd: CGFloat = 0 // its drift between flashes, m/s
        var next: CGFloat // when its next flash starts
        let period: CGFloat
    }

    // The view, fitted to the photo: the eye's height above the grass, the horizon as a fraction of the height, and
    // the focal length in screen heights. On a screen wider than the photo, the photo is scaled up from its top edge,
    // and the view with it. The meadow runs from just below the screen back to the treeline, in metres.
    private let eye = MeadowPhoto.eye, nearest = MeadowPhoto.nearest, treeline = MeadowPhoto.treeline
    private lazy var stretch = max(1, size.width / (size.height * MeadowPhoto.top * MeadowPhoto.aspect))
    private lazy var horizon = onScreen(MeadowPhoto.horizon)
    private lazy var focal = MeadowPhoto.focal * stretch
    private let flash: CGFloat = 3, pool = 800 // twice the standard count, for the density knob
    private let fog = SKUniform(name: "u_fog", float: Float(Fireflies.knobs[1].value))

    private var flies: [Fly] = []
    private var time: TimeInterval = 0
    private var lastTime: TimeInterval?

    override func sceneDidLoad() {
        meadow()
        let shader = SKShader(source: shaderCommon + Self.flySource)
        shader.attributes = [SKAttribute(name: "a_fly", type: .vectorFloat4)]
        for _ in 0..<pool {
            let node = SKSpriteNode(color: .white, size: CGSize(width: 1, height: 1))
            node.shader = shader
            node.isHidden = true
            addChild(node)
            var fly = Fly(node: node, next: .random(in: 0...10), period: .random(in: 6...10))
            spawn(&fly)
            flies.append(fly)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: UserDefaults.didChangeNotification, object: nil)
    }

    /// A height in the photo, as a fraction of the screen height.
    private func onScreen(_ v: CGFloat) -> CGFloat { MeadowPhoto.top - (MeadowPhoto.top - v) * stretch }

    @objc private func settingsChanged() { fog.floatValue = Float(Self.knobs[1].value) }

    /// The sky, then the meadow photo in slices by distance, near to far, so fireflies fly behind nearer grass. The
    /// last slice runs to the trees and beyond, behind every firefly.
    private func meadow() {
        let sky = SKSpriteNode(color: .black, size: size)
        sky.anchorPoint = .zero
        sky.zPosition = -1000
        sky.shader = SKShader(source: shaderCommon + Self.skySource, uniforms: [
            SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)]),
            SKUniform(name: "u_horizon", float: Float(onScreen(MeadowPhoto.skyline))), fog,
        ])
        addChild(sky)

        let width = size.height * MeadowPhoto.top * MeadowPhoto.aspect * stretch, height = width / MeadowPhoto.aspect
        let shared = [
            SKUniform(name: "u_aux", texture: MeadowPhoto.aux), fog,
            SKUniform(name: "u_frame", vectorFloat2: [Float(size.height * MeadowPhoto.top - height), Float(height)]),
            SKUniform(name: "u_ground", vectorFloat2: [Float(size.height * onScreen(MeadowPhoto.foot)),
                                                       Float(size.height * (onScreen(MeadowPhoto.skyline) - onScreen(MeadowPhoto.foot)))]),
        ]
        let cuts: [CGFloat] = [0, 5, 9, 16, 28, 1e4]
        for (a, b) in zip(cuts, cuts.dropFirst()) {
            let slice = SKSpriteNode(texture: MeadowPhoto.photo, size: CGSize(width: width, height: height))
            slice.anchorPoint = CGPoint(x: 0.5, y: 1)
            slice.position = CGPoint(x: size.width / 2, y: size.height * MeadowPhoto.top)
            slice.zPosition = b > 1e3 ? -500 : 100 - (a + b) / 2
            slice.shader = SKShader(source: shaderCommon + Self.groundSource, uniforms: shared + [
                SKUniform(name: "u_slice", vectorFloat2: [Float(MeadowPhoto.depth(a)), Float(MeadowPhoto.depth(b))]),
            ])
            addChild(slice)
        }
    }

    override func update(_ currentTime: TimeInterval) {
        time += frameTime(currentTime, &lastTime) * Self.knobs[2].value // Speed runs the scene's clock faster or slower
        let t = CGFloat(time), active = Int(CGFloat(pool) / 2 * Self.knobs[0].value)
        for i in flies.indices where t >= flies[i].next {
            let u = (t - flies[i].next) / flash
            if u >= 1 || i >= active {
                rest(&flies[i])
                continue
            }
            // A slow glow while it drifts, rising a little as Photinus does at the end of its swoop: easing in over a
            // third of it, and out over nearly half.
            let fly = flies[i], s = u * flash
            fly.node.position = project(fly.x + fly.vx * s, fly.y + 0.03 * (1.6 * u * u - 0.6 * u), fly.d + fly.vd * s)
            fly.node.alpha = smoothstep(0, 0.35, u) * (1 - smoothstep(0.55, 1, u))
            fly.node.isHidden = false
        }
    }

    /// Where a point in the meadow lands on screen.
    private func project(_ x: CGFloat, _ y: CGFloat, _ d: CGFloat) -> CGPoint {
        let f = size.height * focal
        return CGPoint(x: size.width / 2 + f * x / d, y: size.height * horizon + f * (y - eye) / d)
    }

    /// Puts a firefly somewhere new, heading any way. Most are spread evenly over the meadow's area, so there are many
    /// more far off than near, crowding toward the treeline as in photos of real fields; a third are spread evenly by
    /// distance, to fill the middle of the field. Most fly low over the grass; the few above eye height show against
    /// the trees.
    private func spawn(_ fly: inout Fly) {
        fly.d = CGFloat.random(in: 0...1) < 0.35 ? .random(in: nearest...treeline)
            : sqrt(nearest * nearest + .random(in: 0...1) * (treeline * treeline - nearest * nearest))
        let reach = size.width / 2 / (size.height * focal) * fly.d * 1.1
        fly.x = .random(in: -reach...reach)
        fly.y = 0.15 + 1.6 * pow(.random(in: 0...1), 2)
        let heading = CGFloat.random(in: 0...(2 * .pi)), speed = CGFloat.random(in: 0.02...0.05)
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

    /// How much of a firefly's light gets through the fog at distance `d`, as the ground shader fogs the meadow.
    private func clearness(_ d: CGFloat) -> CGFloat {
        exp(-CGFloat(fog.floatValue) * (0.1 + 2.2 * pow(max(MeadowPhoto.depth(d), 0), 2)))
    }

    /// Dresses a firefly as a soft orb, its glow about 4.5 cm across in the world, so it shrinks with distance to a
    /// point by the treeline. Near ones sometimes sit in a pale halo, and now and then there's a halo alone, a
    /// firefly out of focus.
    private func dress(_ fly: Fly) {
        let spread = (CGFloat.random(in: -1...1) + .random(in: -1...1) + .random(in: -1...1)) * 0.3
        let f = size.height * focal, near = fly.d < 12, roll = CGFloat.random(in: 0...1)
        var r = min(max(f * 0.045 / fly.d * exp(spread), 1), 9)
        let kind: CGFloat = near && roll < 0.25 ? 5 : near && roll < 0.45 ? 1 : 0
        if kind == 5 { r = f * .random(in: 0.05...0.12) / fly.d }
        let extent = r * [2.7, 4.4, 0, 0, 0, 1.3][Int(kind)] + 1
        fly.node.size = CGSize(width: extent * 2, height: extent * 2)
        fly.node.zPosition = 100 - fly.d
        fly.node.setValue(SKAttributeValue(vectorFloat4: [Float(r), Float(extent), Float(kind + .random(in: 0..<0.99)), Float(clearness(fly.d))]),
                          forAttribute: "a_fly")
    }

    /// A blue-hour sky: deep blue overhead, paler toward the treeline with a faint warm afterglow, the first stars, and
    /// fog lightening it low down.
    private static let skySource = """
    void main() {
        vec2 pts = v_tex_coord * u_size;
        float h = clamp((v_tex_coord.y - u_horizon) / (1.0 - u_horizon), 0.0, 1.0);
        vec3 c = mix(vec3(0.055, 0.07, 0.10), vec3(0.010, 0.017, 0.048), pow(h, 0.55));
        c += exp(-h * 7.0) * vec3(0.05, 0.028, 0.016) * (0.7 + 0.3 * v_tex_coord.x);
        c += starField(pts, 16.0, 0.05, u_time) * smoothstep(0.1, 0.6, h) * 0.02 * (1.0 - u_fog);
        c = mix(c, vec3(0.05, 0.062, 0.085), u_fog * 0.6 * exp(-h * 6.0));
        c = pow(c, vec3(1.0 / 2.2)) + (hash21(pts * 2.0) - 0.5) / 128.0;
        gl_FragColor = vec4(c, 1.0);
    }
    """

    /// One slice of the meadow photo, the part between two distances (`u_slice`, as log distance). The photo is albedo
    /// at half scale with its daylight taken out offline; here it's lit by a dim blue skylight, a little bluer and
    /// greyer as the eye sees in the dark. Fog is clear close by and thickens with the square of the log distance.
    /// It hugs the ground, thinning up the trees
    /// (`u_ground` is where they stand and how tall they are, in points), in wisps that drift slowly.
    private static let groundSource = """
    void main() {
        vec4 photo = texture2D(u_texture, v_tex_coord);
        float far = texture2D(u_aux, v_tex_coord).r;
        float keep = step(u_slice.x, far) * (1.0 - step(u_slice.y, far));
        vec3 col = 2.0 * pow(photo.rgb / max(photo.a, 0.004), vec3(2.2)) * vec3(0.03, 0.036, 0.042);
        col = mix(col, dot(col, vec3(0.2126, 0.7152, 0.0722)) * vec3(0.78, 0.92, 1.2), 0.15);
        float y = u_frame.x + v_tex_coord.y * u_frame.y;
        float low = 1.0 - 0.85 * smoothstep(u_ground.x, u_ground.x + 0.7 * u_ground.y, y);
        vec2 w = vec2(v_tex_coord.x * 7.0 + u_time * 0.004, v_tex_coord.y * 20.0);
        float wisps = 0.6 + 0.8 * noise(w + vec2(2.0 * noise(w * 0.5 + u_time * 0.01), 0.0));
        float mist = 1.0 - exp(-u_fog * (0.1 + 2.2 * far * far) * wisps * low);
        col = mix(col, vec3(0.04, 0.05, 0.07), mist);
        col = pow(col, vec3(1.0 / 2.2)) + (hash21(v_tex_coord * 4096.0) - 0.5) / 128.0;
        gl_FragColor = vec4(col, 1.0) * photo.a * keep;
    }
    """

    /// A firefly as a soft orb, faded by the node's alpha and by the fog in front of it (`a_fly.w`). `a_fly` is its
    /// radius and the sprite's half-width in points, then its kind plus a seed in the fraction: 0 a cream orb with a
    /// soft, slightly wobbly edge and a faint glow around it, 1 the same in a halo, and 5 a halo
    /// alone. A halo is a flat, pale grey-teal wash about 2.6 times the orb's size, a little off centre, with a ragged
    /// edge and a grainy texture.
    private static let flySource = """
    void main() {
        float r0 = a_fly.x, kind = floor(a_fly.z), seed = fract(a_fly.z) * 64.0;
        float ghost = step(4.5, kind), stained = max(mod(kind, 2.0), ghost);
        vec2 q = (v_tex_coord - 0.5) * 2.0 * a_fly.y;
        float r = length(q);
        vec2 dir = q / max(r, 0.001);
        float edge = r0 * (0.92 + 0.16 * noise(dir * 1.5 + seed));
        float dab = smoothstep(edge + 0.5 + 0.2 * r0, edge - 0.3 * r0, r) * (1.0 - ghost);
        float glow = 0.16 * smoothstep(r0 * 2.6, r0 * 0.8, r) * (1.0 - ghost);
        vec2 s = q - (vec2(hash11(seed), hash11(seed + 3.0)) - 0.5) * 0.5 * r0 * (1.0 - ghost);
        float rs = length(s);
        vec2 ds = s / max(rs, 0.001);
        float reach = mix(r0 * 2.6, r0, ghost) * (0.85 + 0.3 * noise(ds * 2.0 + seed) + 0.12 * noise(ds * 7.0 + seed));
        float stain = smoothstep(reach, reach * 0.8, rs) * (1.0 + 0.15 * smoothstep(reach * 0.5, 0.0, rs))
                    * (0.8 + 0.4 * hash42(floor(q * 0.7) + seed).x) * stained;
        vec4 under = vec4(0.353, 0.416, 0.416, 1.0) * 0.3 * stain;
        under = vec4(1.0, 0.94, 0.7, 1.0) * glow + under * (1.0 - glow);
        vec4 paint = vec4(0.996, 0.941, 0.612, 1.0) * dab;
        gl_FragColor = (under * (1.0 - paint.a) + paint) * v_color_mix.a * a_fly.w;
    }
    """
}

/// The meadow photo: "Field at dusk" by Tristan Ferne (CC BY 2.0), a young wheat field running to a leafy treeline,
/// cut and baked offline: sky cut out, daylight and colour cast taken out, stored as albedo at half scale. Its aux
/// map holds log distance in red (Depth Anything V2; 0 nearest, 1 at 32 times as far) and open field in green.
/// Heights are fractions of the height up from the bottom, with the photo's top edge at `top` on a 1512×982 screen.
@MainActor private enum MeadowPhoto {
    static let photo = SKTexture(image: NSImage(contentsOf: resource("fireflies-meadow.heic")) ?? NSImage())
    static let aux = SKTexture(image: NSImage(contentsOf: resource("fireflies-meadow-aux.png")) ?? NSImage())
    static let aspect = photo.size().width / max(photo.size().height, 1)
    /// The photo's top edge, the treeline's top (median) and its foot, and the ground plane's horizon.
    static let top: CGFloat = 0.549, skyline: CGFloat = 0.487, foot: CGFloat = 0.317, horizon: CGFloat = 0.3585
    /// Fitted from the lens (16 mm on a GF1) and the ground plane `v = horizon − 0.3387/D` over the open field, for
    /// an eye 1.5 m up: the focal length in screen heights, and metres per unit of the depth map's distance `D`.
    static let focal: CGFloat = 1.424, eye: CGFloat = 1.5, scale: CGFloat = 6.3
    /// Where fireflies fly: from just in front of the bottom edge (about 6 m away) back to the treeline's foot.
    static let nearest: CGFloat = 3, treeline: CGFloat = 50
    /// Metres as the aux map's log distance.
    static func depth(_ d: CGFloat) -> CGFloat { d <= 0 ? -1 : log(max(d / scale, 1e-3)) / log(32) }
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
