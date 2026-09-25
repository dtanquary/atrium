import SpriteKit

@MainActor func zenGarden(size: CGSize) -> SKScene { ZenGarden(size: size) }

/// A karesansui seen from above: raked sand, rings around a few mossy stones, and a rake that slowly works
/// across the garden stroke by stroke, leaving a new pattern behind it. A full redraw takes about ten minutes.
final class ZenGarden: SKScene {
    private let band: CGFloat = 104    // width of one rake stroke: 8 tines at the shader's 13 pt spacing
    private let rakeSpeed: CGFloat = 30 // pt/s
    private let margin: CGFloat = 140   // how far past the edge a stroke runs before turning
    private let rakeUniform = SKUniform(name: "u_rake", vectorFloat4: .zero)
    private let kindsUniform = SKUniform(name: "u_kinds", vectorFloat2: .zero)
    private var stones: [(center: CGPoint, radius: CGFloat)] = []
    private var rake: SKSpriteNode!
    private var time: TimeInterval = 0
    private var lastTime: TimeInterval?

    override func sceneDidLoad() {
        let w = size.width, h = size.height, u = min(w, h)
        stones = [
            (CGPoint(x: w * 0.27, y: h * 0.62), u * 0.075), (CGPoint(x: w * 0.338, y: h * 0.535), u * 0.036),
            (CGPoint(x: w * 0.68, y: h * 0.32), u * 0.09), (CGPoint(x: w * 0.765, y: h * 0.43), u * 0.042),
            (CGPoint(x: w * 0.53, y: h * 0.8), u * 0.028),
        ]

        let garden = SKSpriteNode(color: .black, size: size)
        garden.anchorPoint = .zero
        garden.shader = SKShader(source: Self.sandShader, uniforms: [
            SKUniform(name: "u_size", vectorFloat2: [Float(w), Float(h)]),
            SKUniform(name: "u_band", float: Float(band)),
            rakeUniform, kindsUniform,
        ] + stones.enumerated().map { i, s in
            SKUniform(name: "u_s\(i)", vectorFloat3: [Float(s.center.x), Float(s.center.y), Float(s.radius)])
        })
        addChild(garden)

        for stone in stones {
            let sprite = SKSpriteNode(texture: paintStone(radius: stone.radius), size: CGSize(width: stone.radius * 2.3, height: stone.radius * 2.3))
            sprite.position = stone.center
            sprite.zRotation = .random(in: 0...(2 * .pi))
            sprite.zPosition = 1
            addChild(sprite)
        }

        rake = SKSpriteNode(texture: paintRake(), size: CGSize(width: 320, height: band + 16))
        rake.anchorPoint = CGPoint(x: 300 / 320, y: 0.5) // the head
        rake.zPosition = 2
        addChild(rake)
        rakeTo(0)
    }

    override func update(_ currentTime: TimeInterval) {
        time += frameTime(currentTime, &lastTime)
        rakeTo(time)
    }

    /// Where the rake is at time `t`: strokes run left-to-right, then right-to-left, top band to bottom.
    /// Each full pass swaps in the next of three patterns (straight, rippled, long swells).
    private func rakeTo(_ t: TimeInterval) {
        let w = size.width, h = size.height
        let stroke = Double((w + 2 * margin) / rakeSpeed)
        let pass = Double((h / band).rounded(.up)) * stroke
        let elapsed = t + pass * 0.4 + stroke * 0.45 // start mid-pass and mid-stroke, so both patterns and the rake show
        let cycle = Int(elapsed / pass)
        let current = ((elapsed - Double(cycle) * pass) / stroke).rounded(.down)
        let progress = CGFloat((elapsed - Double(cycle) * pass - current * stroke) / stroke)
        let direction: CGFloat = Int(current) % 2 == 0 ? 1 : -1
        let x = direction > 0 ? -margin + progress * (w + 2 * margin) : w + margin - progress * (w + 2 * margin)

        rakeUniform.vectorFloat4Value = [Float(current), Float(x), Float(direction), 0]
        kindsUniform.vectorFloat2Value = [Float(cycle % 3), Float((cycle + 1) % 3)]

        let top = h - CGFloat(current) * band
        rake.position = CGPoint(x: x, y: top - band / 2)
        rake.xScale = direction
        // Lift the rake (fade it) over the stones' rings, which are raked separately.
        let clearance = stones.map { s in
            let dy = min(max(s.center.y, top - band), top) - s.center.y
            return hypot(x - s.center.x, dy) - s.radius - 5 * 13
        }.min()!
        rake.alpha = min(max(clearance / 40, 0), 1)
    }

    /// An irregular rounded stone, lit from the upper left, with a little speckle.
    private func paintStone(radius r: CGFloat) -> SKTexture {
        let box = r * 2.3
        return paint(CGSize(width: box, height: box)) { ctx in
            let c = CGPoint(x: box / 2, y: box / 2)
            let points = (0..<12).map { i -> CGPoint in
                let a = CGFloat(i) / 12 * 2 * .pi, rr = r * .random(in: 0.88...1.08)
                return CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr)
            }
            let mid = { (i: Int) in CGPoint(x: (points[i % 12].x + points[(i + 1) % 12].x) / 2, y: (points[i % 12].y + points[(i + 1) % 12].y) / 2) }
            ctx.move(to: mid(0))
            for i in 1...12 { ctx.addQuadCurve(to: mid(i), control: points[i % 12]) }
            ctx.closePath()
            ctx.clip()
            let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                      colors: [rgb(0.66, 0.64, 0.6), rgb(0.42, 0.41, 0.39), rgb(0.2, 0.2, 0.2)] as CFArray, locations: [0, 0.55, 1])!
            ctx.drawRadialGradient(gradient, startCenter: CGPoint(x: c.x - r * 0.35, y: c.y + r * 0.4), startRadius: 0,
                                   endCenter: c, endRadius: r * 1.1, options: [.drawsAfterEndLocation])
            for _ in 0..<Int(r * 3) {
                ctx.setFillColor(CGColor(gray: .random(in: 0.15...0.8), alpha: 0.25))
                let s = CGFloat.random(in: 0.5...1.6)
                ctx.fillEllipse(in: CGRect(x: .random(in: 0...box), y: .random(in: 0...box), width: s, height: s))
            }
        }
    }

    /// A wooden rake seen from above: head across the stroke, tines peeking out behind it, handle trailing back.
    private func paintRake() -> SKTexture {
        let box = CGSize(width: 320, height: band + 16)
        return paint(box) { ctx in
            let mid = box.height / 2
            for (offset, color) in [(CGPoint(x: 7, y: -7), rgb(0, 0, 0, 0.18)), (.zero, rgb(0.52, 0.36, 0.2))] {
                ctx.setFillColor(color)
                ctx.fill(CGRect(x: 292 + offset.x, y: 8 + offset.y, width: 12, height: box.height - 16))
                ctx.saveGState()
                ctx.translateBy(x: 296 + offset.x, y: mid + offset.y)
                ctx.rotate(by: 0.32)
                ctx.fill(CGRect(x: -300, y: -3.5, width: 300, height: 7))
                ctx.restoreGState()
            }
            ctx.setFillColor(rgb(0.4, 0.27, 0.15))
            for i in 0..<8 { ctx.fill(CGRect(x: 288, y: 8 + 6.5 + CGFloat(i) * 13 - 2, width: 4, height: 4)) }
            ctx.setFillColor(rgb(0.66, 0.48, 0.3, 0.8))
            ctx.fill(CGRect(x: 293, y: 9, width: 3, height: box.height - 18)) // highlight on the lit edge
        }
    }

    /// Sand as a height field: grooves follow distance to the nearest stone inside the rings, and the current
    /// pattern elsewhere. Behind the rake (earlier bands, and this band behind its head) the next pattern shows.
    /// Lighting comes from the slope, sampled one point to the right and one up.
    private static let sandShader = """
        #define SPACING 13.0
        #define RINGS 5.0
        // SpriteKit only exposes uniforms inside main(), so helpers take them as arguments via these macros.
        #define NEAREST(q) nearest(q, u_s0, u_s1, u_s2, u_s3, u_s4)
        #define HEIGHT(q) height(q, NEAREST(q), u_rake, u_kinds, u_size.y, u_band)

        float nearest(vec2 p, vec3 a, vec3 b, vec3 c, vec3 d, vec3 e) {
            return min(min(min(length(p - a.xy) - a.z, length(p - b.xy) - b.z), min(length(p - c.xy) - c.z, length(p - d.xy) - d.z)),
                       length(p - e.xy) - e.z);
        }

        float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

        float noise(vec2 p) {
            vec2 i = floor(p), f = fract(p);
            f = f * f * (3.0 - 2.0 * f);
            return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
        }

        float lines(vec2 p, float kind) {
            float y = p.y;
            if (kind > 1.5) { y += 34.0 * sin(p.x / 210.0); }
            else if (kind > 0.5) { y += 9.0 * sin(p.x / 55.0); }
            return y / SPACING;
        }

        float groove(float u) { return pow(0.5 + 0.5 * cos(6.2831853 * u), 0.7); }

        // d: distance to the nearest stone's edge. rake: (current band, head x, direction, unused). kinds: (before, after).
        float height(vec2 p, float d, vec4 rake, vec2 kinds, float top, float bandWidth) {
            if (d < RINGS * SPACING) { return groove(max(d, 0.0) / SPACING); }
            float band = floor((top - p.y) / bandWidth);
            bool behind = rake.z > 0.0 ? p.x < rake.y : p.x > rake.y;
            bool raked = band < rake.x || (band == rake.x && behind);
            return groove(lines(p, raked ? kinds.y : kinds.x));
        }

        void main() {
            vec2 p = v_tex_coord * u_size;
            float h = HEIGHT(p);
            vec3 n = normalize(vec3((h - HEIGHT(p + vec2(1.0, 0.0))) * 2.4, (h - HEIGHT(p + vec2(0.0, 1.0))) * 2.4, 1.0));
            float diffuse = dot(n, normalize(vec3(-0.5, 0.65, 0.55)));

            float grain = hash(floor(p * 2.0));
            vec3 c = vec3(0.86, 0.81, 0.71) * (0.6 + 0.47 * diffuse) + (grain - 0.5) * 0.05;

            c *= 1.0 - 0.3 * smoothstep(20.0, -6.0, NEAREST(p - vec2(10.0, -10.0)));

            float edge = 18.0 * noise(p / 22.0) - 3.0;
            float moss = smoothstep(edge + 1.5, edge - 1.5, NEAREST(p));
            c = mix(c, mix(vec3(0.2, 0.3, 0.11), vec3(0.38, 0.5, 0.2), noise(p / 3.0)), moss);

            vec2 v = v_tex_coord - 0.5;
            c *= 1.0 - 0.3 * dot(v, v);
            gl_FragColor = vec4(c, 1.0);
        }
        """
}
