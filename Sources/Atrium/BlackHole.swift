import SpriteKit

@MainActor func blackHole(size: CGSize) -> SKScene { BlackHole(size: size) }

/// How light bends round a black hole that doesn't spin, as two small tables that depend on nothing but the hole
/// itself, so one pair serves every view. A ray stays in one plane and its shape depends on one number, `e`, one over
/// how far off centre it was aimed: (du/dφ)² = e² − u²(1 − u), with u one over the distance. The method is Eric
/// Bruneton's ("Real-time High-Quality Rendering of Non-Rotating Black Holes", 2020, arxiv.org/abs/2010.08735), cut
/// down for a camera that stays far out; docs/black-hole.md has it step by step.
///
/// Lengths are in Schwarzschild radii: the horizon is at 1, light circles at 1.5, the innermost stable orbit (the
/// disc's inner edge) is at 3, and a ray aimed nearer than √27/2 is swallowed.
enum Bending {
    /// A ray is swallowed when e² is more than this.
    static let swallowed = 4.0 / 27
    /// Table A is this many columns of `e` by rows of angle; table B this many values of `e`.
    static let raysSize = (across: 256, up: 128), turnsSize = 1024
    /// Table B holds the turn less a quarter circle (what a straight line would make), over this.
    static let turnsScale = 8.0

    /// A little more than a ray from infinity turns through before it's nearest the hole or inside the innermost
    /// orbit, whichever comes first: table A's rows run from no turn to this. (Bruneton's bound, as is table A's
    /// column for `e`, 1/(1 + 6e²): github.com/ebruneton/black_hole_shader, functions.glsl, BSD 3-Clause.)
    static func furthestTurn(_ e2: Double) -> Double { (1 + e2) / (1.0 / 3 + 2 * e2 * e2.squareRoot()) }

    /// One over the distance along a ray from infinity after it has turned through each of `turns` (rising), by
    /// Runge-Kutta on u″ = 1.5u² − u. Stops counting at 2, long since swallowed.
    static func ray(_ e: Double, at turns: [Double]) -> [Double] {
        var (u, slope, turned) = (0.0, e, 0.0)
        func bend(_ u: Double) -> Double { 1.5 * u * u - u }
        return turns.map { turn in
            guard u < 2 else { return 2 }
            let steps = max(1, Int(((turn - turned) / 0.002).rounded(.up))), h = (turn - turned) / Double(steps)
            for _ in 0..<steps where u < 2 {
                let (a1, b1) = (slope, bend(u))
                let (a2, b2) = (slope + 0.5 * h * b1, bend(u + 0.5 * h * a1))
                let (a3, b3) = (slope + 0.5 * h * b2, bend(u + 0.5 * h * a2))
                let (a4, b4) = (slope + h * b3, bend(u + h * a3))
                u += h / 6 * (a1 + 2 * a2 + 2 * a3 + a4)
                slope += h / 6 * (b1 + 2 * b2 + 2 * b3 + b4)
            }
            turned = turn
            return min(u, 2)
        }
    }

    /// The turn a ray that escapes has made, from infinity, by the time it's nearest the hole. That nearest point,
    /// uA, is the smallest positive root of e² = u²(1 − u) (Bruneton's eq. 9); writing u = uA(1 − s²) takes the
    /// square-root blow-up there out of ∫ du/√(e² − u² + u³), which is then summed at 2,000 midpoints.
    static func turnToNearest(_ e2: Double) -> Double {
        let nearest = 1.0 / 3 + 2.0 / 3 * sin(asin(min(max(2 * e2 / swallowed - 1, -1), 1)) / 3), n = 2000
        return (0..<n).reduce(0.0) { sum, i in
            let s = (Double(i) + 0.5) / Double(n), u = nearest * (1 - s * s)
            return sum + 2 * nearest.squareRoot() / (-(u * u + (nearest - 1) * u + nearest * (nearest - 1))).squareRoot()
        } / Double(n)
    }

    /// Where table B keeps a ray's `e`, 0 to 1: stretched so the turn's logarithmic blow-up at the shadow's edge
    /// (column 0) becomes a gentle curve (Bruneton's stretch, over half its range).
    static func turnsColumn(_ e2: Double) -> Double { 1 - 2 * (max(-log(max(1 - e2 / swallowed, 1e-30)), 0) / 50).squareRoot() }

    /// Table A, one over the distance (capped at ½, over ½) for each `e` across and angle up, rows from no turn.
    static let rays: [Double] = {
        let (w, h) = raysSize
        var table = [Double](repeating: 0, count: w * h)
        for i in 0..<w {
            let x = Double(i) / Double(w - 1), rows = (0..<h).map { Double($0) / Double(h - 1) }
            // A ray aimed dead at the hole (x = 0, e infinite) comes to u = e sin φ, half its row in these
            // coordinates; one infinitely far off (x = 1) never comes near.
            let column = x == 0 ? rows.map { $0 / 2 } : x == 1 ? rows.map { _ in 0 }
                : ray(((1 / x - 1) / 6).squareRoot(), at: rows.map { $0 * furthestTurn((1 / x - 1) / 6) })
            for j in 0..<h { table[j * w + i] = min(column[j], 0.5) * 2 }
        }
        return table
    }()

    /// Table B, the turn to the nearest point for each `e` (see `turnsColumn`), less a quarter circle, over `turnsScale`.
    static let turns: [Double] = (0..<turnsSize).map { i in
        let x = Double(i) / Double(turnsSize - 1)
        guard x < 1 else { return 0 }
        let fromEdge = (1 - x) / 2
        return min(max((turnToNearest(swallowed * (1 - exp(-50 * fromEdge * fromEdge))) - .pi / 2) / turnsScale, 0), 1)
    }

    /// A table as RGBA bytes for a texture, each value 0...1 spread over `bytes` channels so the GPU's own smoothing
    /// between entries still gives the right answer: the first holds the value rounded to a byte, each next one
    /// what that rounding left over, centred on a half. The shader adds them back: hi + (lo − ½)/255, and so on.
    static func packed(_ table: [Double], bytes: Int) -> [UInt8] {
        var out = [UInt8](repeating: 255, count: table.count * 4)
        for (i, value) in table.enumerated() {
            var rest = value * 255
            for c in 0..<bytes {
                let byte = rest.rounded()
                out[i * 4 + c] = UInt8(min(max(byte, 0), 255))
                rest = (rest - byte + 0.5) * 255
            }
        }
        return out
    }
}

/// A black hole with a thin disc of glowing gas turning round it, all of it bent by the hole's gravity: the far side
/// of the disc lifts into a hump over the shadow and its underside shows as a ring below.
final class BlackHole: SKScene {
    /// The view: how far out the camera is, how far it's tilted from the disc's axis (90° is edge on), where the
    /// disc ends, and the field of view across the screen. Dave picked the one view; the size slider is the field.
    struct View {
        var distance = 40.0, tilt = 84.0, outer = 11.0, field = 56.0
    }

    private static let rays: SKTexture = {
        let texture = SKTexture(data: Data(Bending.packed(Bending.rays, bytes: 2)),
                                size: CGSize(width: Bending.raysSize.across, height: Bending.raysSize.up))
        texture.filteringMode = .linear
        return texture
    }()

    private static let turns: SKTexture = {
        let texture = SKTexture(data: Data(Bending.packed(Bending.turns, bytes: 3)), size: CGSize(width: Bending.turnsSize, height: 1))
        texture.filteringMode = .linear
        return texture
    }()

    /// `checks` draws the prototype's test pattern in place of the picture, for the test that compares the two:
    /// checks on the disc in distance and angle, and 5° squares on the sky (docs/black-hole/proto/render.py).
    init(size: CGSize, view: View = View(), checks: Bool = false) {
        super.init(size: size)
        let tilt = Float(view.tilt * .pi / 180)
        let sprite = SKSpriteNode(color: .black, size: size)
        sprite.anchorPoint = .zero
        sprite.shader = SKShader(source: Self.source, uniforms: [
            SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)]),
            SKUniform(name: "u_rays", texture: Self.rays), SKUniform(name: "u_turns", texture: Self.turns),
            SKUniform(name: "u_view", vectorFloat4: [Float(1 / view.distance), sin(tilt), cos(tilt), Float(1 / view.outer)]),
            SKUniform(name: "u_lens", float: Float(tan(view.field * .pi / 360))),
            SKUniform(name: "u_checks", float: checks ? 1 : 0),
        ])
        addChild(sprite)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private static let source = """
    // Where table A keeps a ray's distance: its e across, how far it has turned up (see Bending in BlackHole.swift).
    vec2 raysAt(float e2, float turn) {
        float furthest = (1.0 + e2) / (1.0 / 3.0 + 2.0 * e2 * sqrt(e2));
        return vec2((255.0 / (1.0 + 6.0 * e2) + 0.5) / 256.0, (clamp(turn / furthest, 0.0, 1.0) * 127.0 + 0.5) / 128.0);
    }

    // One over the distance, from table A's two bytes.
    float inverseRadius(vec4 t) { return (t.r + (t.g - 0.5) / 255.0) * 0.5; }

    // Which of table B's 1,024 entries keeps a ray's turn to its nearest point (a whole number is an entry's own
    // value), and that turn from an entry's three bytes.
    float turnsAt(float e2) { return clamp(1.0 - 2.0 * sqrt(max(-log(max(1.0 - e2 * 6.75, 1e-12)), 0.0) / 50.0), 0.0, 1.0) * 1023.0; }
    float turnToNearest(vec4 t) { return (t.r + (t.g - 0.5) / 255.0 + (t.b - 0.5) / 65025.0) * 8.0 + 1.5707963; }

    void main() {
        // The pixel's ray in the camera's frame (right, up, toward the hole), as a direction y round the hole on
        // screen and the sine of its angle off the hole. u_view: one over the camera's distance, the sine and
        // cosine of the tilt, one over the disc's outer edge.
        vec2 q = (v_tex_coord - 0.5) * vec2(2.0, 2.0 * u_size.y / u_size.x) * u_lens;
        float off2 = dot(q, q);
        vec2 y = q / max(sqrt(off2), 1e-6);
        float uc = u_view.x;
        float e = uc * sqrt(1.0 - uc) * sqrt(1.0 + off2) / max(sqrt(off2), 1e-5);
        float e2 = e * e;
        bool escapes = e2 < 0.14814815;
        // The turn it has already made on its way in from infinity to the camera (first order in the hole's size,
        // good to 1e-5 with the camera 30 radii or more out), then to its nearest point.
        float w = sqrt(max(e2 - uc * uc, 1e-12));
        float toCamera = asin(min(uc / e, 1.0)) - 0.5 * uc * uc * uc * uc / (w * (2.0 * e2 - uc * uc + 2.0 * e * w));
        // Table B is read at the entries either side and mixed here: the GPU's own smoothing places a reading only
        // to about a 35th of an entry, which put the sky a tenth of a pixel out.
        float column = turnsAt(min(e2, 0.14814815));
        float entry = min(floor(column), 1022.0);
        float toNearest = mix(turnToNearest(texture2D(u_turns, vec2((entry + 0.5) / 1024.0, 0.5))),
                              turnToNearest(texture2D(u_turns, vec2((entry + 1.5) / 1024.0, 0.5))), column - entry);
        float furthest = (1.0 + e2) / (1.0 / 3.0 + 2.0 * e2 * sqrt(e2));
        // The disc's plane cuts the ray's plane along a line this far round from the camera.
        float cut = mod(atan(-u_view.z, u_view.y * y.y), 3.1415927);

        // The ray can meet the disc once before its nearest point and once after: the second is found by mirroring
        // about the nearest point. The second holds the disc's far side arching over the hole (no half-turns), its
        // underside (one) and every finer ring.
        float turn0 = toCamera + cut;
        float u0 = inverseRadius(texture2D(u_rays, raysAt(e2, turn0)));
        bool hit0 = turn0 < furthest && (!escapes || turn0 < toNearest) && u0 <= 1.0 / 3.0 && u0 >= u_view.w;
        float left = 2.0 * toNearest - toCamera - cut;
        float turn1 = mod(left, 3.1415927);
        float halfTurns = floor(left / 3.1415927);
        float u1 = inverseRadius(texture2D(u_rays, raysAt(e2, turn1)));
        bool hit1 = escapes && left > 0.0 && turn1 < toNearest && turn1 < furthest && u1 <= 1.0 / 3.0 && u1 >= u_view.w;

        // Where it leaves for the sky, if it escapes.
        float away = 2.0 * toNearest - toCamera;
        vec3 sky = vec3(sin(away) * y, -cos(away));
        // The disc's plane in the camera's frame: across the screen, and toward the camera.
        vec3 across = vec3(1.0, 0.0, 0.0);
        vec3 near = vec3(0.0, -u_view.z, -u_view.y);
        vec3 axis = vec3(0.0, u_view.y, -u_view.z);

        vec3 col = vec3(0.0);
        if (u_checks > 0.5) {
            // the prototype's checks: on the first part of the disc met, in distance and angle; on the sky, 5° squares
            float round = hit0 ? cut : cut + halfTurns * 3.1415927;
            vec3 at = vec3(sin(round) * y, -cos(round)) / (hit0 ? u0 : u1);
            float disc = 0.25 + 0.75 * mod(floor(length(at) * 1.5) + floor(atan(dot(at, across), dot(at, near)) / 0.2617994), 2.0);
            float squares = 0.12 + 0.3 * mod(floor(atan(dot(sky, across), dot(sky, near)) * 11.459156)
                                             + floor(asin(clamp(dot(sky, axis), -1.0, 1.0)) * 11.459156), 2.0);
            col = vec3(hit0 || hit1 ? disc : escapes ? squares : 0.0);
        }
        gl_FragColor = vec4(col, 1.0);
    }
    """
}
