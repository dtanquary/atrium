import SpriteKit

/// Real-looking flames, in one of two ways to compare: `simulated` runs two sheets of a small fluid simulation
/// (`FlameSim`), as a real fire is many flame sheets at different depths, and a shader adds sub-cell detail; otherwise
/// a procedural shader builds the flames from noise shaped by measured flame physics. Either way the flames'
/// temperature and soot go through a camera's response, so the colour comes from exposure and clipping as in a photo.
/// The node's position is the base of the flames. `light` and `centre` say how bright the flames are just now
/// (about 1 on average) and where their light comes from, in metres from the base, for lighting the scene.
final class Flames: SKSpriteNode {
    static let cells = (x: 64, y: 128), metres: Float = 1   // the simulated box is 1 m wide and 2 m tall
    private var sheets: [FlameSim] = []
    private let field = SKMutableTexture(size: CGSize(width: cells.x, height: cells.y))
    private let clock = SKUniform(name: "u_clock", float: 0)
    private var owed: Double = 0, average: Float = 1
    private(set) var light: CGFloat = 1, centre = SIMD2<Double>(0, 0.3)
    var isSimulated: Bool { !sheets.isEmpty }

    /// `scale` is points per metre at the fire.
    init(scale: CGFloat, simulated: Bool, exposure: Float = 10) {
        let h: CGFloat = 0.75                                        // the procedural flames' tallest tips, in metres
        super.init(texture: nil, color: .black,
                   size: simulated ? CGSize(width: scale, height: 1.3 * scale) : CGSize(width: 1.2 * h * scale, height: 1.4 * h * scale))
        anchorPoint = CGPoint(x: 0.5, y: simulated ? 0.15 / 1.3 : 0.05 / 1.4)
        blendMode = .add
        if simulated {
            sheets = [FlameSim(nx: Self.cells.x, ny: Self.cells.y, width: Self.metres), FlameSim(nx: Self.cells.x, ny: Self.cells.y, width: Self.metres)]
            field.filteringMode = .linear
            shader = SKShader(source: shaderCommon + Self.simulatedSource, uniforms: [
                SKUniform(name: "u_field", texture: field), clock, SKUniform(name: "u_exposure", float: exposure),
            ])
            for _ in 0..<90 { for sheet in sheets { sheet.step(1 / 30) } }   // already burning
            average = measure().total
            upload()
        } else {
            shader = SKShader(source: Self.proceduralSource, uniforms: [clock, SKUniform(name: "u_exposure", float: exposure)])
        }
        advance(0)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Runs the flames on for `dt` seconds of scene time; the simulation in fixed steps of 1/30 s.
    func advance(_ dt: Double) {
        guard !sheets.isEmpty else {
            clock.floatValue += Float(dt)
            // the procedural flames' height (L) and the puff at their base, as the shader has them
            let t = Double(clock.floatValue)
            let height = 1 + 0.12 * sin(2 * .pi * 0.21 * t) + 0.08 * sin(2 * .pi * 0.53 * t + 1)
            light = CGFloat(pow(height, 1.5) * (1 + 0.08 * sin(2 * .pi * 2.4 * t + 2 * sin(t * 0.7))))
            centre = [0.03 * sin(t * 1.3), 0.28 * height]
            return
        }
        owed = min(owed + dt, 2 / 30)
        guard owed >= 1 / 30 else { return }
        while owed >= 1 / 30 {
            for sheet in sheets { sheet.step(1 / 30) }
            owed -= 1 / 30
            clock.floatValue += 1 / 30
        }
        let m = measure()
        average += (m.total - average) * 0.002                        // a slow reference, ~15 s
        light = CGFloat(m.total / max(average, 1e-3))
        centre = [Double(m.centre.x), Double(m.centre.y)]
        upload()
    }

    /// Roughly the light the simulated flames give: fuel that's hot, weighted as the shader colours it, and where
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

    /// Per sheet: a rising noise warps the lookup by about a cell (the detail the grid is too coarse for), the soot
    /// edge is sharpened to a pixel or two, and temperature (720–1540 K) and soot depth give blackbody light, as seen
    /// by a camera white-balanced to 3200 K. The camera clips each channel on its own (red first, then green, then a
    /// little crosstalk lifts blue), which is what turns hot and thick flame pale yellow-white.
    static let simulatedSource = """
    void main() {
        vec2 grid = vec2(64.0, 128.0);
        vec2 cell = v_tex_coord * vec2(64.0, 128.0 * 0.65);             // the sprite shows the bottom 1.3 m
        float rise = u_clock * 1.5 * 64.0;                 // cells: the visible flame rises ~1.5 m/s
        float calm = clamp(cell.y / 20.0, 0.3, 1.0);       // steadier near the logs
        vec3 light = vec3(0.0);
        for (int i = 0; i < 2; i++) {
            float s = float(i) * 37.0;
            vec2 warp = vec2(noise(vec2(cell.x / 1.6 + s, (cell.y - rise) / 1.6)) - 0.5
                             + 0.4 * (noise(vec2(cell.x / 0.6 + s, (cell.y - rise * 1.3) / 0.6)) - 0.5),
                             0.5 * (noise(vec2(cell.x / 1.6 + s + 9.0, (cell.y - rise) / 1.6)) - 0.5)) * 1.4 * calm;
            vec4 f = texture2D(u_field, (cell + warp) / grid);
            float temp = (i == 0 ? f.r : f.b) * 1.2;
            float fuel = i == 0 ? f.g : f.a;
            // flame sheets finer than a cell: stretched noise rising with the flame moves the soot edge
            float sheets = 0.65 * noise(vec2(cell.x / 0.45 + s, (cell.y - rise) / 1.6))
                         + 0.35 * noise(vec2(cell.x / 0.225 + s, (cell.y - rise * 1.2) / 0.8)) - 0.5;
            float edge = fuel + 0.3 * sheets * clamp(cell.y / 12.0, 0.3, 1.0);
            float soot = smoothstep(0.1, 0.16, edge) * 0.95 + 0.05 * min(3.0 * fuel, 1.0);
            float kelvin = 720.0 + 820.0 * temp;
            vec3 bb = vec3(exp(-22800.0 * (1.0 / kelvin - 1.0 / 1300.0)), 0.165 * exp(-26600.0 * (1.0 / kelvin - 1.0 / 1300.0)), 0.0);
            light += (1.0 - exp(-4.0 * soot)) * bb;
        }
        // fade out toward the edges of the sprite, which crops the 2 m box to its bottom 1.3 m
        light *= smoothstep(1.0, 0.75, v_tex_coord.y) * smoothstep(0.0, 0.12, v_tex_coord.x) * smoothstep(1.0, 0.88, v_tex_coord.x);
        vec3 s = light * u_exposure / 1.414;
        s += 0.02 * (s.r + s.g + s.b);
        vec3 c = 1.0 - exp(-s);
        c = mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
        gl_FragColor = vec4(c, 1.0);
    }
    """
}

extension Flames {
    /// The procedural flames (research agent's port of its numpy model, after McCaffrey 1979 and Zukoski's
    /// intermittency): noise rising at the measured, accelerating speed of flame gas, tongues rooted at gaps in the
    /// logs, a travelling puff at 2.4 Hz, the top half coming and going, soot and temperature through the camera.
    /// Units: H, the tallest the tips reach.
    static let proceduralSource = """
    // Procedural campfire flame, port of flame2d.py. Units: H = visible max tip height. v_tex_coord spans the sprite.
    float h13(vec3 p) { p = fract(p * 0.1031); p += dot(p, p.zyx + 31.32); return fract((p.x + p.y) * p.z); }
    float vnoise(vec3 p) {
        vec3 i = floor(p); vec3 f = fract(p); f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
        float a = mix(mix(h13(i), h13(i + vec3(1,0,0)), f.x), mix(h13(i + vec3(0,1,0)), h13(i + vec3(1,1,0)), f.x), f.y);
        float b = mix(mix(h13(i + vec3(0,0,1)), h13(i + vec3(1,0,1)), f.x), mix(h13(i + vec3(0,1,1)), h13(i + vec3(1,1,1)), f.x), f.y);
        return mix(a, b, f.z) * 2.0 - 1.0;
    }
    // Octave k evolves 1.6^k faster (eddy turnover ~ size^(2/3)), not 2^k, so fine detail doesn't boil.
    float fbm5(vec3 p) { float s = 0.0; float a = 0.5; vec3 q = p;
        for (int i = 0; i < 5; i++) { s += a * vnoise(q + float(i) * 17.3); a *= 0.5; q = vec3(q.xy * 2.0, q.z * 1.6); }
        return s; }
    float fbm3(vec3 p) { float s = 0.0; float a = 0.5; vec3 q = p;
        for (int i = 0; i < 3; i++) { s += a * vnoise(q + float(i) * 17.3); a *= 0.5; q = vec3(q.xy * 2.0, q.z * 1.6); }
        return s; }
    float root(float xw, float xr, float wr, float q, float m, float z) {
        float d = (xw - xr * (1.0 - 0.7 * m)) / (wr * (1.0 + 0.4 * z)); return q * exp(-0.5 * d * d); }
    float rootw(float xw, float xr, float wr, float q, float m, float z) {
        float d = (xw - xr * (1.0 - 0.7 * m)) / (2.2 * wr * (1.0 + 0.6 * z)); return q * exp(-0.5 * d * d); }

    void main() {
        float x = (v_tex_coord.x - 0.5) * 1.2;          // -0.6..0.6 H
        float z = v_tex_coord.y * 1.4 - 0.05;          // -0.05..1.35 H
        float zp = max(z, 0.0);
        float U = 1.9; float zc = 0.4; float z0 = 0.02;
        float rise = zp < zc ? (2.0 * zc / U) * (sqrt((zp + z0) / zc) - sqrt(z0 / zc))
                             : (2.0 * zc / U) * (sqrt((zc + z0) / zc) - sqrt(z0 / zc)) + (zp - zc) / U;
        vec3 rad = vec3(0.0);
        for (int k = 0; k < 3; k++) {                  // motion blur over a 1/60 s shutter
            float t = u_clock - float(k) * (1.0 / 120.0);
            float zeta = U * (rise - t);
            float evo = 1.6 * t;
            float xw = x + (0.03 + 0.12 * zp) * fbm3(vec3(x * 3.0 + 5.0, zeta * 2.0, evo));
            float m = pow(clamp(zp / 0.55, 0.0, 1.0), 1.5);
            float E = root(xw, -0.20, 0.07, 0.8, m, zp) + root(xw, -0.07, 0.09, 1.0, m, zp)
                    + root(xw, 0.07, 0.08, 0.95, m, zp) + root(xw, 0.19, 0.06, 0.7, m, zp);
            float Ew = min(1.0, rootw(xw, -0.20, 0.07, 0.8, m, zp) + rootw(xw, -0.07, 0.09, 1.0, m, zp)
                    + rootw(xw, 0.07, 0.08, 0.95, m, zp) + rootw(xw, 0.19, 0.06, 0.7, m, zp));
            E = 1.0 - exp(-1.3 * E);
            float L = 0.8 * (1.0 + 0.12 * sin(6.2832 * 0.21 * t) + 0.08 * sin(6.2832 * 0.53 * t + 1.0));
            float V = 1.0 / (1.0 + exp((z / L - 1.0) / 0.18));
            float puff = 0.14 * sin(6.2832 * zeta / 0.79 + 4.8 * vnoise(vec3(0.5, zeta * 0.4, t * 0.3)));
            float n = fbm5(vec3(xw * 12.0, zeta * 2.4, evo));
            float F = E * V * (1.0 + puff) - 0.55 + 1.6 * n * Ew;
            float S = smoothstep(-0.02, 0.02, F);
            float streak = 0.55 + 0.9 * clamp(0.5 + 0.7 * vnoise(vec3(xw * 45.0 + 3.0, zeta * 3.0, evo * 2.0)), 0.0, 1.0);
            float tau = streak * 2.0 * S * (0.15 + 0.85 * pow(clamp(F / 0.45, 0.0, 1.0), 1.5)) * (0.4 + 0.6 * E) * clamp(z / 0.05, 0.0, 1.0);
            float T = 1390.0 - 260.0 * pow(zp, 1.2) - 90.0 * (1.0 - clamp(F / 0.3, 0.0, 1.0))
                    + 90.0 * fbm3(vec3(xw * 11.0 + 9.0, zeta * 5.0, evo * 1.5));
            vec3 bb = vec3(exp(-22800.0 * (1.0 / T - 1.0 / 1300.0)), 0.165 * exp(-26600.0 * (1.0 / T - 1.0 / 1300.0)), 0.0);
            rad += (1.0 - exp(-tau)) * bb;
            float blue = 0.03 * clamp(1.0 - z / 0.06, 0.0, 1.0) * smoothstep(-0.02, 0.02, z) * clamp(E * 1.3 - 0.3, 0.0, 1.0) * S;
            rad += blue * vec3(0.12, 0.22, 1.0);
        }
        vec3 s = u_exposure * rad / 3.0;
        s += 0.01 * (s.r + s.g + s.b);                  // sensor crosstalk
        vec3 c = 1.0 - exp(-s);                         // per-channel clip
        c = mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
        gl_FragColor = vec4(c, 1.0);                    // additive blend: alpha unused
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
