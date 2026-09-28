import SpriteKit

@MainActor func schlieren(size: CGSize) -> SKScene { Schlieren(size: size) }

/// Rising heat as a colour schlieren camera sees it, after the photos of Gary Settles, Andrew Davidhazy and Ted
/// Kinsman. Warm air is thinner, so it bends light: rays turn toward cooler air by ε = ∇φ, where φ, the optical path
/// through the heat, falls by (n0 − 1)(1 − T0/T) per metre of depth (Gladstone–Dale, n0 − 1 = 2.72e-4 at 20 °C). The
/// camera focuses its light source onto a colour filter, the "cutoff", so each point of the picture takes the colour
/// the filter has wherever that point's rays were bent to. The air comes from `AirSim`; the shader turns its gradient
/// into a bend, looks it up in the filter (baked with the blur of the source's own size, `filterTable`), and draws
/// objects as black silhouettes wrapped in the fringe their edges throw. The flames are drawn on top in their own
/// colour, as they give their own light.
final class Schlieren: SKScene {
    /// What's heating the air. `metres` is the frame's height; `depth` is how much hot air a ray crosses and `span` the
    /// filter's half-width in µrad, so a bend of `span` reaches the filter's outer colours. Candles saturate a 100–300
    /// µrad filter near the flame, as in the photos; a mug's plume bends light a tenth as much, so its rig is more
    /// sensitive (research notes in docs/schlieren.md).
    nonisolated static let sources: [(name: String, metres: Float, depth: Float, span: Float)] = [
        ("Candles", 0.13, 0.012, 450), ("Candle", 0.32, 0.02, 260), ("Mug", 0.34, 0.05, 90), ("Warm air", 0.4, 0.08, 120),
    ]
    nonisolated static let filters = ["Dark field", "Rainbow", "Bands", "Knife edge"]
    /// Each filter's rig as it was set in the photos: the rainbow and band shots run their plumes out to the filter's
    /// outer colours, the dark field and knife edge keep them softer.
    nonisolated static let filterGain: [Float] = [1, 2, 1.6, 1]
    nonisolated static let knobs = [
        Knob(key: "schlieren.source", label: "Heat", range: 0...Double(sources.count - 1), standard: 0, format: .choice(sources.map(\.name))),
        Knob(key: "schlieren.filter", label: "Filter", range: 0...Double(filters.count - 1), standard: 0, format: .choice(filters)),
        Knob(key: "schlieren.sensitivity", label: "Sensitivity", range: 0.3...3, standard: 1, format: .times),
        Knob(key: "schlieren.speed", label: "Speed", range: 0.03...0.5, standard: 0.1, format: .times),
        Knob(key: "schlieren.draft", label: "Draft", range: 0...1, standard: 0.35),
        Knob(key: "schlieren.mirror", label: "Round mirror", range: 0...1, standard: 0, format: .toggle),
    ] + gradeKnobs("schlieren")
    /// The filter's colours from one side to the other: [far left, left, centre, right, far right]. Bright-field
    /// filters show the centre as the background; a plume's left edge bends light left, its right edge right. After
    /// the photos where they're named, otherwise jewel tones.
    nonisolated static let palettes: [(name: String, colours: [SIMD3<Float>])] = [
        ("Candlelight", [[0.95, 0.45, 0.75], [0.20, 0.75, 0.85], [0.03, 0.05, 0.16], [1.00, 0.62, 0.15], [1.00, 0.88, 0.55]]), // Settles' dark bands
        ("Spectrum", [[1.00, 0.38, 0.10], [0.85, 0.25, 0.80], [0.12, 0.14, 0.72], [0.15, 0.85, 0.85], [0.75, 0.95, 0.20]]),    // Davidhazy's candles
        ("Tricolour", [[0.05, 0.12, 1.00], [0.05, 0.12, 1.00], [0.80, 0.03, 0.07], [0.10, 0.88, 0.25], [0.10, 0.88, 0.25]]),   // Settles' red field
        ("Pastel", [[0.60, 0.52, 0.95], [0.72, 0.72, 1.00], [0.36, 0.46, 0.90], [0.98, 0.94, 0.82], [1.00, 0.88, 0.55]]),      // Kinsman's blue mirror
        ("Ember", [[0.20, 0.90, 0.55], [0.80, 0.95, 0.25], [0.02, 0.01, 0.01], [1.00, 0.55, 0.06], [0.95, 0.12, 0.05]]),       // Settles' kettle
        ("Sapphire", [[0.55, 0.35, 0.95], [0.25, 0.55, 1.00], [0.02, 0.05, 0.18], [1.00, 0.75, 0.30], [1.00, 0.92, 0.70]]),
        ("Emerald", [[0.15, 0.55, 0.95], [0.10, 0.85, 0.75], [0.01, 0.12, 0.08], [0.95, 0.80, 0.30], [1.00, 0.55, 0.35]]),
        ("Amethyst", [[0.30, 0.70, 1.00], [0.50, 0.40, 1.00], [0.08, 0.02, 0.14], [1.00, 0.40, 0.70], [1.00, 0.75, 0.60]]),
    ]
    nonisolated static let paletteOptions = palettes.map { ($0.name, [$0.colours[1], $0.colours[2], $0.colours[3]], [$0.colours[1], lifted($0.colours[2]), $0.colours[3]]) }

    /// A bright-field background in Light Mode: the same filter lit brighter and paler, as in Kinsman's photos.
    nonisolated static func lifted(_ c: SIMD3<Float>) -> SIMD3<Float> { simd_mix(c, SIMD3(0.92, 0.93, 0.97), SIMD3(repeating: 0.55)) }

    private let colours: [SIMD3<Float>]
    private let screen = SKSpriteNode()
    private var air: AirSim!
    private var field: SKMutableTexture!
    private var pixels: [UInt8] = []
    private var flames: [(node: SKSpriteNode, heater: Int)] = []
    private var shown = (source: -1, filter: -1)
    private var lastUpdate: TimeInterval?
    private var scale = CGPoint(x: 1, y: 1) // points per metre
    private let uniforms = (field: SKUniform(name: "u_field", texture: nil), mask: SKUniform(name: "u_mask", texture: nil),
                            filter: SKUniform(name: "u_filter", texture: nil), texel: SKUniform(name: "u_texel", vectorFloat2: .zero),
                            mtexel: SKUniform(name: "u_mtexel", vectorFloat2: .zero), gain: SKUniform(name: "u_gain", float: 0),
                            mirror: SKUniform(name: "u_mirror", float: 0), aspect: SKUniform(name: "u_aspect", float: 1),
                            tilt: SKUniform(name: "u_tilt", vectorFloat2: .zero), visible: SKUniform(name: "u_visible", float: 1))
    private let look = gradeKnobs("schlieren").map { SKUniform(name: "u_" + $0.key.split(separator: ".").last!, float: Float($0.value)) }

    override init(size: CGSize) {
        let chosen = UserDefaults.standard.string(forKey: "schlieren.palette") ?? ""
        colours = (Self.palettes.first { $0.name == chosen } ?? Self.palettes.randomElement()!).colours
        super.init(size: size)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func sceneDidLoad() {
        backgroundColor = .black
        screen.size = size
        screen.anchorPoint = .zero
        uniforms.aspect.floatValue = Float(size.width / size.height)
        // the light doesn't quite focus on the filter's centre everywhere, so the background drifts a little across it
        uniforms.tilt.vectorFloat2Value = [Float.random(in: -0.15...0.15), Float.random(in: -0.08...0.08)]
        screen.shader = SKShader(source: shaderCommon + Self.shader, uniforms: [
            uniforms.field, uniforms.mask, uniforms.filter, uniforms.texel, uniforms.mtexel, uniforms.gain, uniforms.mirror,
            uniforms.aspect, uniforms.tilt, uniforms.visible, WallpaperTime.now,
        ] + look)
        addChild(screen)
        applySettings()
        NotificationCenter.default.addObserver(self, selector: #selector(applySettings), name: UserDefaults.didChangeNotification, object: nil)
    }

    @objc private func applySettings() {
        let source = Int(Self.knobs[0].value), filter = Int(Self.knobs[1].value)
        if source != shown.source { build(source) }
        if filter != shown.filter {
            uniforms.filter.textureValue = Self.filterTable(filter, systemIsDark || filter == 0 ? colours : colours.enumerated().map { $0 == 2 ? Self.lifted($1) : $1 })
        }
        shown = (source, filter)
        let s = Self.sources[source]
        // bend in filter half-widths per unit of ∇(T0/T) per fine cell: (n0 − 1)·depth / span / cell size
        uniforms.gain.floatValue = 2.72e-4 * s.depth / (s.span * 1e-6) / air.cell * Float(Self.knobs[2].value) * Self.filterGain[filter]
        uniforms.mirror.floatValue = Float(Self.knobs[5].value)
        for (uniform, knob) in zip(look, gradeKnobs("schlieren")) { uniform.floatValue = Float(knob.value) }
    }

    // MARK: The scene

    /// Sets up the air, the objects' silhouettes and the flames for heat source `source`.
    private func build(_ source: Int) {
        let metres = Self.sources[source].metres
        // the air runs on above the frame, so the plume leaves the picture without meeting the sim's edge
        let rows = 64, above = 8, cols = max(16, Int((Float(rows) * Float(size.width / size.height)).rounded()))
        let width = Float(cols) * metres / Float(rows) // the grid's width, which the screen stretches over (< 1% off)
        scale = CGPoint(x: size.width / CGFloat(width), y: size.height / CGFloat(metres))
        air = AirSim(nx: cols, ny: rows + above, height: metres * Float(rows + above) / Float(rows), fine: 3)
        uniforms.visible.floatValue = Float(rows) / Float(rows + above)
        var shapes: [(CGContext) -> Void] = []

        switch source {
        case 0: // four birthday candles in a huddle, as in Davidhazy's photo
            for (x, top) in [(0.40, 0.13), (0.47, 0.17), (0.54, 0.115), (0.61, 0.15)] as [(Float, Float)] {
                addCandle(x: x * width, top: top * metres, radius: 0.0032, flame: (0.006, 0.016), into: &shapes)
            }
        case 1: // one taper, as in Settles' and Kinsman's photos (NIST's: 21 mm across, a 42 mm flame)
            addCandle(x: 0.5 * width, top: 0.13 * metres, radius: 0.0105, flame: (0.011, 0.034), into: &shapes)
        case 2: // a mug of coffee at 70 °C: its surface and walls warm the air (θ = ΔT/T0)
            let x = 0.5 * width, r: Float = 0.042, h: Float = 0.095, base: Float = 0.01
            air.addSolid(x0: x - r, x1: x + r, y0: 0, y1: base + h)
            air.heaters.append(.init(x: x, y: base + h - 0.003, width: 2 * r * 0.9, height: 0.005, heat: 0.15, flame: false, ripple: 0.4))
            for side: Float in [-1, 1] {
                air.heaters.append(.init(x: x + side * (r + 0.001), y: base + 0.01, width: 0.002, height: h - 0.012, heat: 0.05, flame: false))
            }
            shapes.append { ctx in
                let cx = CGFloat(x), r = CGFloat(r), h = CGFloat(h), base = CGFloat(base)
                ctx.addPath(CGPath(roundedRect: CGRect(x: cx - r, y: -0.01, width: 2 * r, height: base + h + 0.01), cornerWidth: 0.008, cornerHeight: 0.008, transform: nil))
                ctx.fillPath()
                ctx.setLineWidth(0.009)
                ctx.strokeEllipse(in: CGRect(x: cx + r - 0.012, y: base + h * 0.25, width: 0.042, height: h * 0.55))
            }
        default: // warm air rising off a radiator's top along the bottom of the frame, hotter in wandering patches
            let top: Float = 0.018
            air.addSolid(x0: 0, x1: width, y0: 0, y1: top)
            for i in 0..<5 {
                air.heaters.append(.init(x: (0.1 + 0.2 * Float(i)) * width, y: top, width: 0.06, height: 0.006, heat: 0.2, flame: false, ripple: 0.6))
            }
            air.cool = 0.35
            shapes.append { ctx in
                ctx.addPath(CGPath(roundedRect: CGRect(x: -0.01, y: -0.01, width: CGFloat(width) + 0.02, height: CGFloat(top) + 0.01),
                                   cornerWidth: 0.004, cornerHeight: 0.004, transform: nil))
                ctx.fillPath()
            }
        }

        air.wander = source == 3
        let mask = paint(CGSize(width: size.width / 2, height: size.height / 2)) { ctx in
            ctx.setFillColor(rgb(0, 0, 0))
            ctx.fill(CGRect(origin: .zero, size: self.size))
            ctx.scaleBy(x: self.scale.x / 2, y: self.scale.y / 2)
            ctx.setFillColor(rgb(1, 1, 1))
            ctx.setStrokeColor(rgb(1, 1, 1))
            for shape in shapes { shape(ctx) }
        }
        mask.filteringMode = .linear
        uniforms.mask.textureValue = mask
        uniforms.mtexel.vectorFloat2Value = [Float(1 / size.width), Float(1 / size.height)]

        for _ in 0..<90 { air.step(1 / 60) } // already burning
        field = SKMutableTexture(size: CGSize(width: air.fx, height: air.fy))
        field.filteringMode = .linear
        pixels = Array(repeating: 255, count: air.fx * air.fy * 4)
        uniforms.field.textureValue = field
        uniforms.texel.vectorFloat2Value = [1 / Float(air.fx), 1 / Float(air.fy)]
        upload()

        for flame in flames { flame.node.removeFromParent() }
        flames = air.heaters.indices.filter { air.heaters[$0].flame }.map { i in
            let h = air.heaters[i]
            let node = SKSpriteNode(texture: Self.flameTexture, size: CGSize(width: CGFloat(h.width) * scale.x * 1.5, height: CGFloat(h.height) * scale.y * 1.5))
            node.anchorPoint = CGPoint(x: 0.5, y: 0.08)
            node.blendMode = .add
            node.zPosition = 1
            addChild(node)
            return (node, i)
        }
    }

    /// A candle `radius` metres round with its top `top` metres up, as a silhouette with a wick, and its flame
    /// (width and height in metres) as heat.
    private func addCandle(x: Float, top: Float, radius: Float, flame: (Float, Float), into shapes: inout [(CGContext) -> Void]) {
        air.addSolid(x0: x - radius, x1: x + radius, y0: 0, y1: top)
        air.heaters.append(.init(x: x, y: top + 0.002, width: flame.0, height: flame.1, heat: 3, flame: true))
        shapes.append { ctx in
            let cx = CGFloat(x), r = CGFloat(radius), t = CGFloat(top)
            ctx.addPath(CGPath(roundedRect: CGRect(x: cx - r, y: -r, width: 2 * r, height: t + r), cornerWidth: r * 0.25, cornerHeight: r * 0.25, transform: nil))
            ctx.fillPath()
            ctx.setLineWidth(0.0007)
            ctx.move(to: CGPoint(x: cx, y: t))
            ctx.addQuadCurve(to: CGPoint(x: cx + 0.0012, y: t + 0.005), control: CGPoint(x: cx - 0.0004, y: t + 0.003))
            ctx.strokePath()
        }
    }

    override func update(_ currentTime: TimeInterval) {
        var left = frameTime(currentTime, &lastUpdate) * Self.knobs[3].value
        air.draftStrength = Float(Self.knobs[4].value) * 0.06 // m/s: a still room's air moves at 0.05–0.1
        while left > 1e-6 {
            let dt = min(left, 1.0 / 30)
            air.step(Float(dt))
            left -= dt
        }
        upload()
        // the flames lean with the air round them and breathe with the sim's flicker
        for (node, i) in flames {
            let h = air.heaters[i], wind = air.velocity(atX: h.x, y: h.y + h.height * 0.5)
            node.zRotation = CGFloat(-atan2(wind.x, max(wind.y, 0.3) + 0.3)) * 0.8
            node.yScale = CGFloat(air.flicker(i))
            node.position = CGPoint(x: CGFloat(h.x) * scale.x, y: CGFloat(h.y) * scale.y)
        }
    }

    /// Sends T0/T (1 in room air, 0.25 in flame) to the texture as 16 bits, so the shader's gradient doesn't band.
    private func upload() {
        let fx = air.fx, fy = air.fy, fw = air.fw, t = air.t
        pixels.withUnsafeMutableBufferPointer { px in
            for y in 0..<fy {
                for x in 0..<fx {
                    let m = 1 / (1 + max(t[(y + 1) * fw + x + 1], 0)), v = Int(m * 65535), o = (y * fx + x) * 4
                    px[o] = UInt8(v >> 8)
                    px[o + 1] = UInt8(v & 255)
                }
            }
        }
        let bytes = pixels
        field.modifyPixelData { data, length in bytes.withUnsafeBytes { data?.copyMemory(from: $0.baseAddress!, byteCount: min(length, $0.count)) } }
    }

    // MARK: Filter, flame and shader

    /// What the camera sees for a bend of (x, y) filter half-widths, over ±2 half-widths: the filter's colour
    /// averaged over the light source's image as the bend slides it across, a slit for the strips and knife edge, a
    /// pinhole round the dark field's stop. The bands end in an opaque holder, so their strongest bends go black; the
    /// rainbow's and dark field's outer colours run on, as round the flames in Davidhazy's and Settles' photos.
    nonisolated static func filterTable(_ filter: Int, _ c: [SIMD3<Float>]) -> SKTexture {
        let n = 128
        var source: [SIMD2<Float>] = []
        if filter == 0 { // a disc of points, spread evenly by the golden angle
            for i in 0..<48 {
                let a = Float(i) * 2.39996, r: Float = 0.13 * ((Float(i) + 0.5) / 48).squareRoot()
                source.append(SIMD2(r * cos(a), r * sin(a)))
            }
        } else {
            for i in 0..<24 { source.append(SIMD2((Float(i) / 23 - 0.5) * 0.24, 0)) }
        }
        func smooth(_ e0: Float, _ e1: Float, _ x: Float) -> Float { let t = min(max((x - e0) / (e1 - e0), 0), 1); return t * t * (3 - 2 * t) }
        func ramp(_ x: Float) -> SIMD3<Float> { // the five colours at −1, −0.5, 0, 0.5, 1
            let u = min(max((x + 1) * 2, 0), 3.999), i = Int(u), f = smooth(0, 1, u - Float(i))
            return simd_mix(c[i], c[i + 1], SIMD3(repeating: f))
        }
        func transmit(_ p: SIMD2<Float>) -> SIMD3<Float> {
            switch filter {
            case 0: // a round stop, ringed by the left colours on the left and the right colours on the right
                let r = simd_length(p), side = smooth(-0.7, 0.7, p.x / max(r, 1e-4))
                let inner = simd_mix(c[1], c[3], SIMD3(repeating: side)), outer = simd_mix(c[0], c[4], SIMD3(repeating: side))
                return simd_mix(inner, outer, SIMD3(repeating: smooth(0.35, 1.3, r))) * smooth(0.18, 0.2, r)
            case 1: // a continuous strip, as in rainbow schlieren, its end colours running on to the edge
                return ramp(p.x)
            case 2: // coloured strips, with the thin dark gaps between an LED's dies
                let x = abs(p.x), band = x < 0.3 ? 2 : x < 0.9 ? (p.x < 0 ? 1 : 3) : x < 1.4 ? (p.x < 0 ? 0 : 4) : -1
                let gap = min(abs(x - 0.3), abs(x - 0.9), abs(x - 1.4)) < 0.035 ? Float(0.15) : 1
                return band < 0 ? .zero : c[band] * gap
            default: // a knife edge graded from dark to clear: relief, tinted by the palette
                let t = smooth(-1.2, 1.2, p.x), shade = simd_mix(c[2], c[1], SIMD3(repeating: 0.5)) * 0.4
                return t < 0.5 ? simd_mix(shade, c[2], SIMD3(repeating: t * 2)) : simd_mix(c[2], simd_mix(c[3], .one, SIMD3(repeating: 0.4)), SIMD3(repeating: t * 2 - 1))
            }
        }
        var bytes = [UInt8](repeating: 255, count: n * n * 4)
        for j in 0..<n {
            for i in 0..<n {
                let d = SIMD2(Float(i) + 0.5, Float(j) + 0.5) / Float(n) * 4 - 2
                var sum = SIMD3<Float>.zero
                for s in source { sum += transmit(d + s) }
                let col = simd_clamp(sum / Float(source.count), .zero, .one), o = (j * n + i) * 4
                (bytes[o], bytes[o + 1], bytes[o + 2]) = (UInt8(col.x * 255), UInt8(col.y * 255), UInt8(col.z * 255))
            }
        }
        let texture = SKTexture(data: Data(bytes), size: CGSize(width: n, height: n))
        texture.filteringMode = .linear
        return texture
    }

    /// A candle flame as the camera sees it: a white-hot core blown out to white, a yellow and orange rim, and the
    /// faint blue where it starts, drawn upright with its base near the bottom.
    private static let flameTexture: SKTexture = paint(CGSize(width: 32, height: 96)) { ctx in
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        func blob(_ rect: CGRect, _ colours: [CGColor], _ stops: [CGFloat]) {
            ctx.saveGState()
            ctx.translateBy(x: rect.midX, y: rect.midY)
            ctx.scaleBy(x: rect.width / rect.height, y: 1)
            let gradient = CGGradient(colorsSpace: space, colors: colours as CFArray, locations: stops)!
            ctx.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: rect.height / 2, options: [])
            ctx.restoreGState()
        }
        blob(CGRect(x: 1, y: 2, width: 30, height: 92), [rgb(1, 0.6, 0.25, 0.7), rgb(1, 0.45, 0.15, 0.3), rgb(1, 0.4, 0.1, 0)], [0, 0.55, 1])
        blob(CGRect(x: 6, y: 8, width: 20, height: 70), [rgb(1, 1, 0.97), rgb(1, 0.97, 0.8), rgb(1, 0.85, 0.45, 0.9), rgb(1, 0.6, 0.2, 0)], [0, 0.45, 0.75, 1])
        blob(CGRect(x: 10, y: 4, width: 12, height: 18), [rgb(0.35, 0.45, 1, 0.55), rgb(0.3, 0.4, 1, 0)], [0, 1])
    }

    private static let shader = """
    float air(vec4 t) { return (t.r * 65280.0 + t.g * 255.0) / 65535.0; }

    void main() {
        vec2 p = v_tex_coord;
        // the bend: rays turn toward cooler, denser air, by the gradient of T0/T (the air runs on above the frame)
        vec2 e = u_texel, a = vec2(p.x, p.y * u_visible);
        float l = air(texture2D(u_field, a - vec2(e.x, 0.0))), r = air(texture2D(u_field, a + vec2(e.x, 0.0)));
        float b = air(texture2D(u_field, a - vec2(0.0, e.y))), t = air(texture2D(u_field, a + vec2(0.0, e.y)));
        float c = air(texture2D(u_field, a));
        vec2 bend = vec2(r - l, t - b) * 0.5 * u_gain;
        // room air is never quite still: faint, slow mottling everywhere
        float now = mod(u_now, 3600.0);
        vec2 q = p * vec2(u_aspect, 1.0) * 2.5;
        bend += vec2(noise(q + vec2(now * 0.03, now * 0.05)) - 0.5, noise(q * 1.3 + vec2(7.1, now * 0.04)) - 0.5) * 0.05;
        bend += u_tilt * (p - 0.5);
        // an object's edge throws light sharply aside, so silhouettes wear the filter's outer colours as a rim
        vec2 m = u_mtexel;
        float mask = texture2D(u_mask, p).r;
        bend += vec2(texture2D(u_mask, p + vec2(m.x, 0.0)).r - texture2D(u_mask, p - vec2(m.x, 0.0)).r,
                     texture2D(u_mask, p + vec2(0.0, m.y)).r - texture2D(u_mask, p - vec2(0.0, m.y)).r) * -1.6;
        // the round mirror: its rim bends light outward, like a lens edge
        vec2 d = (p - 0.5) * vec2(u_aspect, 1.0);
        float rad = length(d), field = 1.0;
        if (u_mirror > 0.5) {
            field = smoothstep(0.482, 0.476, rad);
            bend += d / max(rad, 1e-4) * smoothstep(0.44, 0.48, rad) * 0.8;
        }
        vec3 col = texture2D(u_filter, clamp(0.5 + bend * 0.25, 0.001, 0.999)).rgb;
        // a little shadowgraph: slight defocus turns curvature into light and shade
        col *= clamp(1.0 + (l + r + b + t - 4.0 * c) * u_gain * 0.6, 0.6, 1.6);
        col *= (1.0 - mask) * field * (1.0 - 0.18 * rad * rad);
        col = grade(col, 0.3, u_hue, u_saturation, u_contrast, u_brightness);
        gl_FragColor = vec4(col, 1.0);
    }
    """
}

/// The air in front of the camera: FlameSim's stable fluids (Stam 1999, with vorticity confinement) on a coarse grid,
/// carrying θ = ΔT/T0 on a grid three times finer by MacCormack advection, so the thin edges schlieren shows survive.
/// Positions are in metres from the bottom-left. Hot air rises by g·θ/(1 + θ) against the room's mean, so the open
/// edges can't build up a drift of the whole field; drag and cooling stand in for the third dimension a 2D slice
/// lacks, where a real plume spreads and dilutes.
final class AirSim {
    /// A source of heat: a flame (a teardrop of hot gas `heat` hot, in a halo of warmed air) or a warm patch.
    struct Heater { var x, y, width, height, heat: Float; var flame: Bool; var ripple: Float = 0 }

    let nx: Int, ny: Int, w: Int, h: Float
    let fx: Int, fy: Int, fw: Int, cell: Float
    private let r: Int
    private var u, v, p, div, curl, a, b, temp: UnsafeMutablePointer<Float>
    private(set) var t: UnsafeMutablePointer<Float>
    private var t1, t2, ox, oy, lo, hi: UnsafeMutablePointer<Float>
    private var solid: [Bool]
    var heaters: [Heater] = [] { didSet { stamps = [:] } }
    private var stamps: [Int: (x0: Int, y0: Int, cols: Int, values: [Float])] = [:]
    var draftStrength: Float = 0.02
    var wander = false
    private var draft: [Float], time: Float = 0
    /// How fast warm air mixes away, per second: a 2D slice can't spread sideways in depth, as real plumes do.
    var cool: Float = 1
    private let buoyancy: Float = 9.8, vorticity: Float = 2, iterations = 16, drag: Float = 1.2, diffuse: Float = 3e-5

    init(nx: Int, ny: Int, height: Float, fine: Int) {
        self.nx = nx; self.ny = ny; w = nx + 2; h = height / Float(ny)
        r = fine; fx = nx * fine; fy = ny * fine; fw = fx + 2; cell = h / Float(fine)
        func field(_ n: Int) -> UnsafeMutablePointer<Float> { let f = UnsafeMutablePointer<Float>.allocate(capacity: n); f.initialize(repeating: 0, count: n); return f }
        let n = (nx + 2) * (ny + 2), m = (fx + 2) * (fy + 2)
        u = field(n); v = field(n); p = field(n); div = field(n); curl = field(n); a = field(n); b = field(n); temp = field(n)
        t = field(m); t1 = field(m); t2 = field(m); ox = field(m); oy = field(m); lo = field(m); hi = field(m)
        solid = Array(repeating: false, count: n)
        draft = Array(repeating: 0, count: ny + 2)
    }

    deinit { for f in [u, v, p, div, curl, a, b, temp, t, t1, t2, ox, oy, lo, hi] { f.deallocate() } }

    /// Marks a box the air can't flow through (a candle, a mug).
    func addSolid(x0: Float, x1: Float, y0: Float, y1: Float) {
        for y in 1...ny { for x in 1...nx {
            let cx = (Float(x) - 0.5) * h, cy = (Float(y) - 0.5) * h
            if cx >= x0 - h * 0.5 && cx <= x1 + h * 0.5 && cy <= y1 && cy >= y0 { solid[y * w + x] = true }
        } }
    }

    /// How tall flame `i` stands just now: steady in still air, a percent or two of breathing.
    func flicker(_ i: Int) -> Float { 1 + 0.025 * sin(time * 9 + Float(i) * 2.1) * sin(time * 2.3 + Float(i)) }

    /// The air's velocity at a point, m/s, draft included.
    func velocity(atX x: Float, y: Float) -> SIMD2<Float> {
        let cx = min(max(x / h + 0.5, 1), Float(nx)), cy = min(max(y / h + 0.5, 1), Float(ny))
        let k = Int(cy) * w + Int(cx)
        return [u[k] + draft[Int(cy)], v[k]]
    }

    func step(_ dt: Float) {
        let nx = nx, ny = ny, w = w, fw = fw
        // a still room's air drifts back and forth every few seconds, a little differently at each height, which
        // sets a plume swaying and kinks it into turbulence
        let sway = 0.65 * sin(time * 0.9) + 0.35 * sin(time * 2.3 + 1.3)
        for y in 0...ny + 1 {
            let z = (Float(y) - 0.5) * h
            draft[y] = draftStrength * (sway + 0.5 * sin(z * 25 - time * 1.7) * (0.6 + 0.4 * sin(time * 0.37)))
        }
        if wander {
            for i in heaters.indices { heaters[i].x += 0.004 * dt * sin(time * 0.4 + Float(i) * 1.7) }
        }
        heat()
        // coarse temperature, the mean of each block of fine cells, and the lift it gives against the room's mean
        let inv = 1 / Float(r * r)
        var mean: Float = 0
        for y in 1...ny { for x in 1...nx {
            var s: Float = 0
            for j in 0..<r { let row = ((y - 1) * r + j + 1) * fw + (x - 1) * r + 1; for i in 0..<r { s += t[row + i] } }
            let th = s * inv
            temp[y * w + x] = th / (1 + th)
            mean += temp[y * w + x]
        } }
        mean /= Float(nx * ny)
        let lift = dt * buoyancy, keep = exp(-drag * dt)
        for y in 1...ny { for x in 1...nx {
            let k = y * w + x
            v[k] += lift * (temp[k] - mean)
        } }
        confine(dt)
        for k in 0..<w * (ny + 2) {
            if solid[k] { u[k] = 0; v[k] = 0 } else { u[k] = min(max(u[k] * keep, -4), 4); v[k] = min(max(v[k] * keep, -4), 4) }
        }
        project()
        // the room's air is still far from the heat: no drift of the whole field, which open edges can't hold back
        var mu: Float = 0, mv: Float = 0
        for y in 1...ny { for x in 1...nx { mu += u[y * w + x]; mv += v[y * w + x] } }
        mu /= Float(nx * ny); mv /= Float(nx * ny)
        for y in 1...ny { for x in 1...nx { let k = y * w + x; u[k] = solid[k] ? 0 : u[k] - mu; v[k] = solid[k] ? 0 : v[k] - mv } }
        advect(u, into: a, dt); advect(v, into: b, dt)
        swap(&u, &a); swap(&v, &b)
        advectFine(dt)
        // warm air mixes out, spreading and cooling; flame gas, hundreds of degrees hotter, mixes down to a few hundred
        // within a couple of centimetres (θ ≈ 1 by the flame's tip, NIST), so the plume above is broad and smooth
        let passes = max(1, Int((diffuse * dt / (cell * cell) / 0.24).rounded(.up))) // explicit diffusion is stable to 0.25
        let decay = exp(-cool * dt / Float(passes)), c = diffuse * dt / (cell * cell) / Float(passes)
        let quench = 1 - exp(-12 * dt / Float(passes))
        for _ in 0..<passes {
            for y in 1...fy { for x in 1...fx {
                let k = y * fw + x
                let mixed = t[k] + c * (t[k - 1] + t[k + 1] + t[k - fw] + t[k + fw] - 4 * t[k])
                t2[k] = (mixed - max(mixed - 0.8, 0) * quench) * decay
            } }
            swap(&t, &t2)
        }
        time += dt
    }

    /// Holds each heater's air at its temperature. A flame is a teardrop of gas at ~1150 K (θ = 3), and above it the
    /// first few centimetres of its plume: a cone that starts as wide as the flame and widens and cools as it rises
    /// (θ ≈ 1 by the tip, NIST), after which the sim carries it on. That gives the V the photos show at the base. Flames
    /// are stamped from a table made once; warm patches, which ripple, are drawn each step.
    private func heat() {
        let fw = fw, cell = cell
        for (i, f) in heaters.enumerated() {
            if f.flame {
                if stamps[i] == nil { stamps[i] = stamp(f) }
                let (x0, y0, cols, values) = stamps[i]!
                var j = 0
                for y in y0..<y0 + values.count / cols {
                    let row = y * fw
                    for x in x0..<x0 + cols { t[row + x] = max(t[row + x], values[j]); j += 1 }
                }
                continue
            }
            let x0 = max(1, Int((f.x - f.width) / cell)), x1 = min(fx, Int((f.x + f.width) / cell) + 1)
            let y0 = max(1, Int((f.y - f.height) / cell)), y1 = min(fy, Int((f.y + 2 * f.height) / cell) + 1)
            guard x0 <= x1, y0 <= y1 else { continue }
            for y in y0...y1 { for x in x0...x1 {
                let px = (Float(x) - 0.5) * cell - f.x, py = (Float(y) - 0.5) * cell - f.y
                let ex = max(abs(px) - f.width * 0.5, 0) / (cell * 2), ey = max(abs(py - f.height * 0.5) - f.height * 0.5, 0) / (cell * 2)
                // a warm surface sheds its heat from a few wandering spots, not evenly
                let spots = f.ripple * (sin(px * 260 + time * 0.7) * sin(px * 97 - time * 0.45 + Float(i)))
                let k = y * fw + x
                t[k] = max(t[k], f.heat * exp(-ex * ex - ey * ey) * (1 + spots))
            } }
        }
    }

    /// A flame and the start of its plume, as θ on the fine cells round it: its first cell and the table's width.
    private func stamp(_ f: Heater) -> (x0: Int, y0: Int, cols: Int, values: [Float]) {
        let rise = f.height * 2.5, spread: Float = 0.3 // the cone's height, and how fast it widens
        let reach = f.width + (f.width * 0.5 + spread * rise) * 2
        let x0 = max(1, Int((f.x - reach) / cell)), x1 = min(fx, Int((f.x + reach) / cell) + 1)
        let y0 = max(1, Int((f.y - f.width) / cell)), y1 = min(fy, Int((f.y + f.height + rise) / cell) + 1)
        guard x0 <= x1, y0 <= y1 else { return (1, 1, 1, []) }
        var values: [Float] = []
        for y in y0...y1 { for x in x0...x1 {
            let px = (Float(x) - 0.5) * cell - f.x, py = (Float(y) - 0.5) * cell - f.y
            let dy = (py - f.height * 0.45) / (f.height * 0.55), e = px * px / (f.width * f.width * 0.25) + dy * dy
            let flame = e < 1 ? f.heat * (1 - e * e) : 0
            // the cone: from the flame's middle up, a Gaussian across that widens as it cools, fading in below
            let z = max(py - f.height * 0.5, 0), width = f.width * 0.5 + spread * z
            let fade = py < 0 ? exp(-py * py / (f.width * f.width * 0.1)) : 1
            let cone = 1.1 / (1 + 2.5 * z / f.height) * exp(-px * px / (width * width)) * fade * max(1 - z / rise, 0)
            values.append(max(flame, cone))
        } }
        return (x0, y0, x1 - x0 + 1, values)
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

    /// Makes the flow incompressible: red-black SOR for the pressure, warm-started from the last step. Open air all
    /// round: pressure 0 past the edges, and velocity copied into the ghost ring so flow through an edge isn't divergence.
    private func project() {
        let nx = nx, ny = ny, w = w, h = h
        for f in [u, v] {
            for x in 1...nx { f[x] = f[w + x]; f[(ny + 1) * w + x] = f[ny * w + x] }
            for y in 0...ny + 1 { f[y * w] = f[y * w + 1]; f[y * w + nx + 1] = f[y * w + nx] }
        }
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

    /// Semi-Lagrangian on the coarse grid, draft included.
    private func advect(_ q: UnsafeMutablePointer<Float>, into o: UnsafeMutablePointer<Float>, _ dt: Float) {
        let nx = nx, ny = ny, w = w, s = dt / h, maxX = Float(nx) - 0.001, maxY = Float(ny) - 0.001
        for y in 1...ny { let d = draft[y]; for x in 1...nx {
            let k = y * w + x
            let fx = min(max(Float(x) - (u[k] + d) * s, 1), maxX), fy = min(max(Float(y) - v[k] * s, 1), maxY)
            let x0 = Int(fx), y0 = Int(fy), tx = fx - Float(x0), ty = fy - Float(y0)
            let i = y0 * w + x0
            let bottom = q[i] + (q[i + 1] - q[i]) * tx, top = q[i + w] + (q[i + w + 1] - q[i + w]) * tx
            o[k] = bottom + (top - bottom) * ty
        } }
    }

    /// MacCormack on the fine grid (Selle et al. 2008), limited to the cells it read so it can't overshoot, with the
    /// velocity read bilinearly from the coarse grid. Past the edges is room air.
    private func advectFine(_ dt: Float) {
        let fx = fx, fy = fy, fw = fw, w = w, rr = Float(r), s = dt / cell, nx = nx, ny = ny
        let maxX = Float(fx) + 0.999, maxY = Float(fy) + 0.999
        for y in 1...fy {
            let cy = min(max((Float(y) - 0.5) / rr + 0.5, 1), Float(ny) - 0.001)
            let cy0 = Int(cy), ty = cy - Float(cy0), d = draft[cy0] + (draft[cy0 + 1] - draft[cy0]) * ty
            for x in 1...fx {
                let cx = min(max((Float(x) - 0.5) / rr + 0.5, 1), Float(nx) - 0.001)
                let cx0 = Int(cx), tx = cx - Float(cx0), i = cy0 * w + cx0
                let ub = u[i] + (u[i + 1] - u[i]) * tx, ut = u[i + w] + (u[i + w + 1] - u[i + w]) * tx
                let vb = v[i] + (v[i + 1] - v[i]) * tx, vt = v[i + w] + (v[i + w + 1] - v[i + w]) * tx
                let k = y * fw + x
                ox[k] = ((ub + (ut - ub) * ty) + d) * s; oy[k] = (vb + (vt - vb) * ty) * s
                let px = min(max(Float(x) - ox[k], 0), maxX), py = min(max(Float(y) - oy[k], 0), maxY)
                let x0 = Int(px), y0 = Int(py), ax = px - Float(x0), ay = py - Float(y0), j = y0 * fw + x0
                let q00 = t[j], q10 = t[j + 1], q01 = t[j + fw], q11 = t[j + fw + 1]
                let bottom = q00 + (q10 - q00) * ax, top = q01 + (q11 - q01) * ax
                t1[k] = bottom + (top - bottom) * ay
                lo[k] = min(min(q00, q10), min(q01, q11)); hi[k] = max(max(q00, q10), max(q01, q11))
            }
        }
        for y in 1...fy { for x in 1...fx {
            let k = y * fw + x
            let px = min(max(Float(x) + ox[k], 0), maxX), py = min(max(Float(y) + oy[k], 0), maxY)
            let x0 = Int(px), y0 = Int(py), ax = px - Float(x0), ay = py - Float(y0), j = y0 * fw + x0
            let bottom = t1[j] + (t1[j + 1] - t1[j]) * ax, top = t1[j + fw] + (t1[j + fw + 1] - t1[j + fw]) * ax
            t2[k] = min(max(t1[k] + 0.5 * (t[k] - (bottom + (top - bottom) * ay)), lo[k]), hi[k])
        } }
        swap(&t, &t2)
        // room air comes in at the bottom and sides; at the top, air leaves as it is
        for x in 0..<fw { t[x] = 0; t[(fy + 1) * fw + x] = t[fy * fw + x] }
        for y in 0..<fy + 1 { t[y * fw] = 0; t[y * fw + fx + 1] = 0 }
    }
}
