import SpriteKit

/// Real-looking flames. Two sheets of a small fluid simulation (`FlameSim`; a real fire is many flame sheets at
/// different depths) say where flame is and how hot, so the fire leans, puffs and pinches off as a real one does; a
/// shader draws the tongues and torn wisps inside that envelope with noise that rises at the measured, accelerating
/// speed of flame gas, and puts soot and temperature through a camera's response, so the colour comes from exposure
/// and clipping as in a photo. The node's position is the base of the flames. `light` and `centre` say how bright
/// the flames are just now (about 1 on average) and where their light comes from, in metres from the base.
final class Flames: SKSpriteNode {
    static let cells = (x: 64, y: 128), metres: Float = 1   // the simulated box is 1 m wide and 2 m tall
    private let sheets = [FlameSim(nx: cells.x, ny: cells.y, width: metres), FlameSim(nx: cells.x, ny: cells.y, width: metres)]
    private let field = SKMutableTexture(size: CGSize(width: cells.x, height: cells.y))
    private let clock = SKUniform(name: "u_clock", float: 0)
    private var owed: Double = 0, time: Double = 0, average: Float = 1
    private(set) var light: CGFloat = 1, centre = SIMD2<Double>(0, 0.3)

    /// `scale` is points per metre at the fire. The sprite shows the bottom 1.3 m of the simulated box.
    init(scale: CGFloat, exposure: Float = 10) {
        super.init(texture: nil, color: .black, size: CGSize(width: scale, height: 1.3 * scale))
        anchorPoint = CGPoint(x: 0.5, y: 0.15 / 1.3)
        blendMode = .add
        field.filteringMode = .linear
        shader = SKShader(source: Self.source, uniforms: [
            SKUniform(name: "u_field", texture: field), clock, SKUniform(name: "u_exposure", float: exposure),
        ])
        for _ in 0..<90 { for sheet in sheets { sheet.step(1 / 30) } }   // already burning
        average = measure().total
        upload()
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Runs the flames on for `dt` seconds of scene time; the simulation in fixed steps of 1/30 s.
    func advance(_ dt: Double) {
        owed = min(owed + dt, 2 / 30)
        guard owed >= 1 / 30 else { return }
        while owed >= 1 / 30 {
            for sheet in sheets { sheet.step(1 / 30) }
            owed -= 1 / 30
            time += 1 / 30
        }
        clock.floatValue = Self.shaderClock(time)
        let m = measure()
        average += (m.total - average) * 0.002                        // a slow reference, ~15 s
        light = CGFloat(m.total / max(average, 1e-3))
        centre = [Double(m.centre.x), Double(m.centre.y)]
        upload()
    }

    /// The scene time the shaders see, wrapped hourly. Summed as a Float it would stop moving within days, and even
    /// passed on from a Double, a Float big enough to count days makes the noise the shaders scroll with it coarse
    /// and jumpy. The wrap jumps the flame detail, haze and ember breathing to a new phase in one frame, which in a
    /// fire whose tongues turn over every frame or two passes for flicker.
    // ponytail: crossfade two phases across the wrap if it's ever caught
    static func shaderClock(_ time: Double) -> Float { Float(time.truncatingRemainder(dividingBy: 3600)) }

    /// Roughly the light the flames give: fuel that's hot, weighted as the shader colours it, and where
    /// its middle is.
    private func measure() -> (total: Float, centre: CGPoint) {
        var total: Float = 0, sx: Float = 0, sy: Float = 0
        for sheet in sheets {
            let w = sheet.w
            for y in stride(from: 1, through: sheet.ny, by: 2) { for x in stride(from: 1, through: sheet.nx, by: 2) {
                let k = y * w + x, t = sheet.temp[k]
                guard t > 0.3, sheet.fuel[k] > 0.05 else { continue }
                let e = min(sheet.fuel[k] * 6, 1) * exp(8 * (t - 1))     // steep in temperature, as blackbody light is
                total += e; sx += e * Float(x); sy += e * Float(y)
            } }
        }
        let n = Float(sheets.first?.nx ?? 64)
        return (total, total > 0 ? CGPoint(x: CGFloat(sx / total / n - 0.5), y: CGFloat(sy / total / n - 0.15)) : CGPoint(x: 0, y: 0.3))
    }

    /// Temperature and fuel of both sheets into one RGBA texture. The bytes are packed here and copied in when
    /// SpriteKit next draws, which may be on another thread.
    private func upload() {
        let (a, b) = (sheets[0], sheets[1]), nx = a.nx, w = a.w
        var bytes = [UInt8](repeating: 0, count: nx * a.ny * 4)
        for y in 0..<a.ny { for x in 0..<nx {
            let k = (y + 1) * w + x + 1, o = (y * nx + x) * 4
            bytes[o] = UInt8(min(a.temp[k] / 1.2, 1) * 255)
            bytes[o + 1] = UInt8(min(max(a.fuel[k], 0), 1) * 255)
            bytes[o + 2] = UInt8(min(b.temp[k] / 1.2, 1) * 255)
            bytes[o + 3] = UInt8(min(max(b.fuel[k], 0), 1) * 255)
        } }
        let packed = bytes
        field.modifyPixelData { data, length in packed.withUnsafeBytes { data?.copyMemory(from: $0.baseAddress!, byteCount: min(length, $0.count)) } }
    }

    /// Flame is where the simulation has hot fuel, cut into tongues and wisps by 5 octaves of noise (12/H across by
    /// 2.4/H up) read at the rising gas's travel time, with a 2–3 px soot edge (after the research agent's procedural
    /// recipe: McCaffrey 1979, Zukoski's intermittency). Temperature (930–1500 K from the simulation, cooler at thin
    /// edges) and soot depth give blackbody light as seen by a camera white-balanced to 3200 K, averaged over a 1/60 s
    /// shutter. The camera clips each channel on its own (red first, then green, then a little crosstalk lifts blue),
    /// which is what turns hot and thick flame pale yellow-white.
    static let source = """
    float h13(vec3 p) { p = fract(p * 0.1031); p += dot(p, p.zyx + 31.32); return fract((p.x + p.y) * p.z); }
    float vnoise(vec3 p) {
        vec3 i = floor(p); vec3 f = fract(p); f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
        float a = mix(mix(h13(i), h13(i + vec3(1.0, 0.0, 0.0)), f.x), mix(h13(i + vec3(0.0, 1.0, 0.0)), h13(i + vec3(1.0, 1.0, 0.0)), f.x), f.y);
        float b = mix(mix(h13(i + vec3(0.0, 0.0, 1.0)), h13(i + vec3(1.0, 0.0, 1.0)), f.x), mix(h13(i + vec3(0.0, 1.0, 1.0)), h13(i + vec3(1.0, 1.0, 1.0)), f.x), f.y);
        return mix(a, b, f.z) * 2.0 - 1.0;
    }
    // each octave evolves 1.6× faster than the last (eddies turn over as size^(2/3)); 2× would make fine detail boil
    float fbm(vec3 p, int octaves) {
        float s = 0.0; float a = 0.5; vec3 q = p;
        for (int i = 0; i < 5; i++) {
            if (i < octaves) { s += a * vnoise(q + float(i) * 17.3); }
            a *= 0.5; q = vec3(q.xy * 2.0, q.z * 1.6);
        }
        return s;
    }
    void main() {
        // metres in the 1 m × 2 m box (the sprite shows its bottom 1.3 m); fuel leaves the logs 0.15 m up.
        // Units of H, the tallest the tips reach (~0.75 m): x across, z up from the flames' base.
        float by = v_tex_coord.y * 1.3;
        float x = (v_tex_coord.x - 0.5) / 0.75;
        float z = max(by - 0.15, 0.0) / 0.75;
        // flame gas accelerates up from the fuel (u = U·sqrt(z/zc)), then rises at U: the noise is read at the time
        // the gas takes to reach this height, so its features speed up and stretch as real ones do
        float U = 1.9; float zc = 0.4; float z0 = 0.02;
        float rise = z < zc ? (2.0 * zc / U) * (sqrt((z + z0) / zc) - sqrt(z0 / zc))
                            : (2.0 * zc / U) * (sqrt((zc + z0) / zc) - sqrt(z0 / zc)) + (z - zc) / U;
        vec3 light = vec3(0.0);
        vec4 here = texture2D(u_field, vec2(v_tex_coord.x, by / 2.0));
        // most of the sprite is empty air: skip the noise there
        for (int k = 0; k < 2 && max(here.g, here.a) > 0.004; k++) {   // motion blur over a 1/60 s shutter
            float t = u_clock - float(k) / 120.0;
            float zeta = U * (rise - t);
            float evo = 1.6 * t;
            float xw = x + (0.02 + 0.06 * z) * fbm(vec3(x * 3.0 + 5.0, zeta * 2.0, evo), 3);
            // the simulation gives where flame is and how hot: its envelope moves, leans, puffs and pinches off
            // (read through a slight warp, so the 1.6 cm cells don't show through the sharp edges)
            vec2 cell = vec2(0.5 + xw * 0.75, by / 2.0) * vec2(64.0, 128.0);
            cell += vec2(vnoise(vec3(cell * 0.6, evo)), vnoise(vec3(cell * 0.6 + 7.0, evo))) * 0.8;
            vec4 f = texture2D(u_field, cell / vec2(64.0, 128.0));
            float fuel = max(f.g, f.a) * smoothstep(0.25, 0.55, max(f.r, f.b) * 1.2);   // soot glows only where hot
            float temp = max(f.r, f.b) * 1.2;
            float E = smoothstep(0.04, 0.4, fuel);
            float reach = smoothstep(0.02, 0.12, fuel);
            // and the noise the tongues and torn wisps inside it: 5 octaves, 12/H across by 2.4/H up
            float n = fbm(vec3(xw * 12.0, zeta * 2.4, evo), 5);
            float F = E - 0.5 + 1.45 * n * reach;
            float S = smoothstep(-0.02, 0.02, F);
            float streak = 0.55 + 0.9 * clamp(0.5 + 0.7 * vnoise(vec3(xw * 45.0 + 3.0, zeta * 3.0, evo * 2.0)), 0.0, 1.0);
            float tau = streak * 2.0 * S * (0.15 + 0.85 * pow(clamp(F / 0.45, 0.0, 1.0), 1.5)) * (0.4 + 0.6 * E);
            float kelvin = 930.0 + 470.0 * temp - 90.0 * (1.0 - clamp(F / 0.3, 0.0, 1.0))
                         + 90.0 * fbm(vec3(xw * 11.0 + 9.0, zeta * 5.0, evo * 1.5), 2);
            vec3 bb = vec3(exp(-22800.0 * (1.0 / kelvin - 1.0 / 1300.0)), 0.165 * exp(-26600.0 * (1.0 / kelvin - 1.0 / 1300.0)), 0.0);
            light += (1.0 - exp(-tau)) * bb;
        }
        light *= smoothstep(1.0, 0.8, v_tex_coord.y) * smoothstep(0.0, 0.1, v_tex_coord.x) * smoothstep(1.0, 0.9, v_tex_coord.x);
        vec3 s = light * u_exposure / 2.0;
        s += 0.01 * (s.r + s.g + s.b);
        vec3 c = 1.0 - exp(-s);
        c = mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
        gl_FragColor = vec4(c, 1.0);
    }
    """
}

/// What a camera white-balanced to 3200 K records from a blackbody at `kelvin`, `strength` times as bright as the
/// flames' reference: red first, then green clips, and crosstalk lifts blue. Display (sRGB) values.
func firePhoto(kelvin: CGFloat, strength: CGFloat, exposure: CGFloat = 10) -> SIMD3<Double> {
    let r = exp(-22800 * (1 / kelvin - 1 / 1300)), g = 0.165 * exp(-26600 * (1 / kelvin - 1 / 1300))
    var s = SIMD3<Double>(Double(r), Double(g), 0) * Double(strength * exposure)
    s += 0.01 * (s.x + s.y + s.z)
    let c = 1 - SIMD3<Double>(exp(-s.x), exp(-s.y), exp(-s.z))
    return SIMD3(c.x <= 0.0031308 ? 12.92 * c.x : 1.055 * pow(c.x, 1 / 2.4) - 0.055,
                 c.y <= 0.0031308 ? 12.92 * c.y : 1.055 * pow(c.y, 1 / 2.4) - 0.055,
                 c.z <= 0.0031308 ? 12.92 * c.z : 1.055 * pow(c.z, 1 / 2.4) - 0.055)
}

/// Sparks: flakes of burning bark and char carried up by the plume on curling paths, drawn as the short streaks a
/// 1/60 s shutter makes of them. A few leave every second and every 5–20 s a pocket of resin or steam pops out a
/// burst. As in real footage, most last well under a second and wink out rather than cooling through red.
final class Sparks: SKNode {
    private struct Spark { var x, y, vx, vy, age, life, heat, seed: CGFloat; var wink: CGFloat }
    private var sparks: [Spark?] = Array(repeating: nil, count: 48)
    private var sprites: [SKSpriteNode] = []
    private let scale: CGFloat
    private var time: CGFloat = 0, nextBurst: CGFloat = .random(in: 5...20), popping = 0

    /// `scale` is points per metre at the fire, whose base is this node's origin.
    init(scale: CGFloat) {
        self.scale = scale
        super.init()
        let line = paint(CGSize(width: 32, height: 4)) { ctx in
            let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                               colors: [rgb(1, 1, 1), rgb(1, 1, 1, 0)] as CFArray, locations: [0, 1])!
            ctx.scaleBy(x: 8, y: 1)
            ctx.drawRadialGradient(g, startCenter: CGPoint(x: 2, y: 2), startRadius: 0, endCenter: CGPoint(x: 2, y: 2), endRadius: 2, options: [])
        }
        for _ in sparks.indices {
            let sprite = SKSpriteNode(texture: line)
            sprite.blendMode = .add
            sprite.colorBlendFactor = 1
            sprite.isHidden = true
            addChild(sprite)
            sprites.append(sprite)
        }
        for _ in 0..<60 { advance(1 / 30) }
    }

    required init?(coder: NSCoder) { fatalError() }

    func advance(_ dt: CGFloat) {
        time += dt
        if CGFloat.random(in: 0...1) < 3 * dt { spawn(burst: false) }          // ~3 a second
        if time > nextBurst { popping = Int.random(in: 20...40); nextBurst = time + .random(in: 5...20) }
        for _ in 0..<min(popping, 7) { spawn(burst: true); popping -= 1 }       // a pop spreads over ~0.2 s
        for i in sparks.indices {
            guard var s = sparks[i] else { continue }
            s.age += dt
            if s.age > s.life || s.age > s.wink { sparks[i] = nil; sprites[i].isHidden = true; continue }
            // the plume: ~2.5 m/s up through the flames, slowing above; eddies 5–20 cm push them about
            let rise = 2.6 / (1 + pow(max(s.y - 0.4, 0) / 1.2, 2))
            let t = time * 2 + s.seed
            let gust = 0.9 * (sin(t * 3.1 + s.y * 9) + 0.6 * sin(t * 5.3 + s.x * 13 + 2))
            s.vx += (gust - s.vx) * min(1, dt / 0.25)
            s.vy += (rise - s.vy) * min(1, dt / 0.25) - 1.0 * dt
            s.x += s.vx * dt; s.y += s.vy * dt
            sparks[i] = s
            let sprite = sprites[i], speed = hypot(s.vx, s.vy)
            let kelvin = s.heat - 120 * s.age / s.life
            let c = firePhoto(kelvin: kelvin, strength: 0.6)
            sprite.isHidden = false
            sprite.position = CGPoint(x: s.x * scale, y: s.y * scale)
            sprite.zRotation = atan2(s.vy, s.vx)
            sprite.size = CGSize(width: max(2, speed / 60 * scale), height: 1.6)
            sprite.color = NSColor(red: c.x, green: c.y, blue: c.z, alpha: 1)
            sprite.alpha = 1 - 0.5 * CGFloat(0.5 + 0.5 * sin(Double(time * 40 + s.seed * 7))) * min(1, s.age * 3)  // tumbling
        }
    }

    private func spawn(burst: Bool) {
        guard let i = sparks.firstIndex(where: { $0 == nil }) else { return }
        let angle = CGFloat.random(in: burst ? 0.5...(.pi - 0.5) : 1.1...(.pi - 1.1)), speed = burst ? CGFloat.random(in: 2...4) : .random(in: 0.8...1.5)
        let life = exp(CGFloat.random(in: log(0.25)...log(1.2)))
        sparks[i] = Spark(x: .random(in: -0.18...0.18), y: .random(in: 0.3...0.55), vx: speed * cos(angle), vy: speed * sin(angle),
                          age: 0, life: life, heat: .random(in: 1300...1400), seed: .random(in: 0...100),
                          wink: .random(in: 0...1) < 0.5 ? .random(in: 0.3...1) * life : .infinity)
    }
}

/// The bed of embers under the flames, seen at a slant: blocks of charcoal 1–3 cm across (Voronoi cells) with
/// hotter cracks between them, each block breathing ±40 K on its own slow rhythm, hottest under the flames
/// (~1050 K) and cooling to grey ash toward the rim. Same blackbody-through-a-camera colour as the flames. Drawn
/// over the ground with alpha, so ash and dark char cover it and glowing parts add light.
func coalBed(scale: CGFloat, width: CGFloat, depth: CGFloat, clock: SKUniform, ash: SKUniform) -> SKSpriteNode {
    let bed = SKSpriteNode(color: .black, size: CGSize(width: width * scale, height: depth * scale))
    bed.shader = SKShader(source: shaderCommon + """
    vec2 cellPoint(vec2 c) { return c + 0.15 + 0.7 * hash42(c).xy; }
    void main() {
        vec2 q = (v_tex_coord - 0.5) * 2.0;                      // -1..1 across the bed's ellipse
        float r = length(q);
        vec2 p = v_tex_coord * u_cells;                          // in coal blocks (~2 cm)
        // nearest two cell points (F1, F2) for the cracks
        vec2 i = floor(p);
        float f1 = 9.0; float f2 = 9.0; vec2 id = vec2(0.0);
        for (int y = -1; y <= 1; y++) { for (int x = -1; x <= 1; x++) {
            vec2 c = i + vec2(float(x), float(y));
            float d = length(p - cellPoint(c));
            if (d < f1) { f2 = f1; f1 = d; id = c; } else if (d < f2) { f2 = d; }
        } }
        vec4 h = hash42(id + 7.0);
        float core = exp(-r * r * 2.2);                          // hottest under the flames
        float breathe = sin(u_clock * (1.9 + 4.0 * h.y) + 30.0 * h.z) * 0.6 + 0.4 * sin(u_clock * (0.7 + h.x) + 9.0 * h.w);
        float face = 780.0 + 270.0 * core + 60.0 * (h.x - 0.5) + 40.0 * breathe;
        float crack = 1.0 - smoothstep(0.02, 0.08, f2 - f1);
        float kelvin = face + 120.0 * crack * smoothstep(0.1, 0.6, core + 0.2);
        vec3 bb = vec3(exp(-22800.0 * (1.0 / kelvin - 1.0 / 1300.0)), 0.165 * exp(-26600.0 * (1.0 / kelvin - 1.0 / 1300.0)), 0.0);
        vec3 s = u_exposure * 0.9 * bb;
        s += 0.01 * (s.r + s.g + s.b);
        vec3 glow = 1.0 - exp(-s);
        // cooler blocks wear a film of grey ash, lit a little by the fire
        float ashy = smoothstep(880.0, 800.0, face) * (1.0 - crack);
        vec3 col = glow * (1.0 - 0.7 * ashy) + u_ash * ashy * (0.6 + 0.4 * h.w);
        col = mix(col * 12.92, 1.055 * pow(col, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, col));
        float a = smoothstep(1.0, 0.75, r + 0.12 * (noise(p * 0.7) - 0.5));
        gl_FragColor = vec4(col * a, a);
    }
    """, uniforms: [clock, ash, SKUniform(name: "u_exposure", float: 10),
                    SKUniform(name: "u_cells", vectorFloat2: [Float(width / 0.02), Float(depth * 3.5 / 0.02)])])
    return bed
}

/// A small 2D fire: stable fluids (Stam 1999) with buoyancy and vorticity confinement, and fuel that burns into heat
/// (after Nguyen, Fedkiw and Jensen 2002). `nx`×`ny` cells of `h` metres, y up, open on every side: the box starts
/// inside the log pile, so air comes up from below as well as in from the sides.
/// Every field lives on a grid with a one-cell ghost border, so the loops need no edge cases.
final class FlameSim {
    let nx: Int, ny: Int, w: Int, h: Float
    let u, v, temp, fuel, p, div, a, b, curl, damp: UnsafeMutablePointer<Float>
    var buoyancy: Float = 1.0 * 9.8, vorticity: Float = 28, burn: Float = 1.2, cool: Float = 5, iterations = 12
    /// Where fuel gas comes out of the logs, in cells.
    var patches: [SIMD2<Float>] = []
    private var time: Float = 0

    init(nx: Int, ny: Int, width: Float) {
        self.nx = nx; self.ny = ny; w = nx + 2; h = width / Float(nx)
        let n = (nx + 2) * (ny + 2)
        func field() -> UnsafeMutablePointer<Float> { let f = UnsafeMutablePointer<Float>.allocate(capacity: n); f.initialize(repeating: 0, count: n); return f }
        u = field(); v = field(); temp = field(); fuel = field(); p = field(); div = field(); a = field(); b = field(); curl = field(); damp = field()
        for y in 1...ny { for x in 1...nx {
            let e = Float(min(min(x - 1, nx - x), ny - y, y + 3))
            damp[y * w + x] = 0.995 * (0.85 + 0.15 * pow(min(e / 8, 1), 2))   // still air far from the fire
        } }
        for _ in 0..<32 {
            let r = (Float.random(in: 0...1), Float.random(in: 0...1))
            let x = 0.5 + (r.0 - 0.5) * 0.7
            patches.append([1 + x * Float(nx), 1 + (0.15 + r.1 * 0.12 * (1 - 2 * abs(r.0 - 0.5))) * Float(nx)])
        }
    }

    deinit { for f in [u, v, temp, fuel, p, div, a, b, curl, damp] { f.deallocate() } }

    func step(_ dt: Float) {
        let nx = nx, ny = ny, w = w
        // fuel gas leaving the wood, already burning. Each gap in the logs lets it out in its own gusts (smooth
        // random, six a second), and the whole bed puffs together at about 2 Hz as the base vortex sheds (Cetegen
        // and Ahmed 1993): with both, the flames' area and height flicker as much and as fast as in real footage.
        let n = w * (ny + 2)
        for i in 0..<n { a[i] = 0 }
        let puff = 1 + 0.2 * sin(2 * .pi * 2 * time + 1.5 * sin(time * 0.9) + sin(time * 2.3))
        for (i, s) in patches.enumerated() {
            let g = time * 6 + Float(i) * 17.3, k = g.rounded(.down), f = g - k, e = f * f * (3 - 2 * f)
            let amp = puff * (0.25 + 0.75 * (gust(k, i) * (1 - e) + gust(k + 1, i) * e))
            for y in max(1, Int(s.y) - 4)...min(ny, Int(s.y) + 4) { for x in max(1, Int(s.x) - 4)...min(nx, Int(s.x) + 4) {
                let dx = (Float(x) - s.x) / 1.5, dy = (Float(y) - s.y) / 1.5
                a[y * w + x] += amp * exp(-dx * dx - dy * dy)
            } }
        }
        for i in 0..<n where a[i] > 0.001 {
            let q = min(a[i], 1.2)
            fuel[i] = max(fuel[i], q); temp[i] = max(temp[i], 0.9 * q)
        }
        let decay = exp(-cool * dt), lift = dt * buoyancy, rate = burn * dt
        for y in 1...ny { for x in 1...nx {
            let k = y * w + x
            let burnt = min(fuel[k], rate * max(fuel[k], 0.05))
            fuel[k] -= burnt
            temp[k] = min((temp[k] + 2 * burnt) * decay, 1.2)
            v[k] += lift * temp[k]
        } }
        confine(dt)
        for y in 1...ny { for x in 1...nx {
            let k = y * w + x
            u[k] = min(max(u[k] * damp[k], -4), 4); v[k] = min(max(v[k] * damp[k], -3), 6)
        } }
        project()
        advect(u, into: a, dt); advect(v, into: b, dt)
        swapContents(u, a); swapContents(v, b)
        advect(temp, into: a, dt); advect(fuel, into: b, dt)
        swapContents(temp, a); swapContents(fuel, b)
        time += dt
    }

    /// A repeatable random number in 0...1 for gust `k` of patch `i`.
    private func gust(_ k: Float, _ i: Int) -> Float {
        let v = sin(k * 127.1 + Float(i) * 311.7) * 43758.5453
        return v - v.rounded(.down)
    }

    private func swapContents(_ x: UnsafeMutablePointer<Float>, _ y: UnsafeMutablePointer<Float>) {
        let n = w * (ny + 2)
        for i in 0..<n { let t = x[i]; x[i] = y[i]; y[i] = t }
    }

    /// Vorticity confinement: puts back the small swirls that the coarse grid smooths away.
    private func confine(_ dt: Float) {
        let nx = nx, ny = ny, w = w, k0 = 0.5 / h, s = dt * vorticity * h
        for y in 1...ny { for x in 1...nx {
            let k = y * w + x
            curl[k] = k0 * ((v[k + 1] - v[k - 1]) - (u[k + w] - u[k - w]))
        } }
        for y in 2..<ny { for x in 2..<nx {
            let k = y * w + x
            let gx = abs(curl[k + 1]) - abs(curl[k - 1]), gy = abs(curl[k + w]) - abs(curl[k - w])
            let n = s * curl[k] / ((gx * gx + gy * gy).squareRoot() + 1e-9)
            u[k] += gy * n
            v[k] -= gx * n
        } }
    }

    /// Makes the flow incompressible: red-black SOR for the pressure, warm-started from the last frame. The ghost
    /// border holds 0 all round, for open air.
    private func project() {
        let nx = nx, ny = ny, w = w, h = h
        for y in 1...ny { for x in 1...nx {
            let k = y * w + x
            div[k] = -0.5 * h * (u[k + 1] - u[k - 1] + v[k + w] - v[k - w])
        } }
        let omega: Float = 1.8
        for _ in 0..<iterations {
            for colour in 0..<2 {
                for y in 1...ny {
                    var k = y * w + 1 + (y + colour) & 1
                    let end = y * w + nx
                    while k <= end {
                        p[k] += omega * ((div[k] + p[k + 1] + p[k - 1] + p[k + w] + p[k - w]) * 0.25 - p[k])
                        k += 2
                    }
                }
            }
        }
        let g = 0.5 / h
        for y in 1...ny { for x in 1...nx {
            let k = y * w + x
            u[k] -= g * (p[k + 1] - p[k - 1])
            v[k] -= g * (p[k + w] - p[k - w])
        } }
    }

    /// Semi-Lagrangian: each cell takes the value found back along the flow, bilinearly.
    private func advect(_ q: UnsafeMutablePointer<Float>, into o: UnsafeMutablePointer<Float>, _ dt: Float) {
        let nx = nx, ny = ny, w = w, s = dt / h, maxX = Float(nx) - 0.001, maxY = Float(ny) - 0.001
        for y in 1...ny { for x in 1...nx {
            let k = y * w + x
            let fx = min(max(Float(x) - u[k] * s, 1), maxX), fy = min(max(Float(y) - v[k] * s, 1), maxY)
            let x0 = Int(fx), y0 = Int(fy), tx = fx - Float(x0), ty = fy - Float(y0)
            let i = y0 * w + x0
            let bottom = q[i] + (q[i + 1] - q[i]) * tx, top = q[i + w] + (q[i + w + 1] - q[i + w]) * tx
            o[k] = bottom + (top - bottom) * ty
        } }
    }
}
