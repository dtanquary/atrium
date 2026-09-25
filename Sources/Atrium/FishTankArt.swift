import SpriteKit

/// The fish in the tank. Each is painted once per depth, facing right, with the numbers that drive its swimming.
enum Species: CaseIterable {
    case clownfish, blueTang, yellowTang, neonTetra, angelfish

    /// Nose to tail tip, in points at depth 1.
    var length: CGFloat {
        switch self {
        case .clownfish: 62
        case .blueTang: 84
        case .yellowTang: 64
        case .neonTetra: 27
        case .angelfish: 70
        }
    }

    /// Body height as a fraction of length.
    var bodyHeight: CGFloat {
        switch self {
        case .clownfish: 0.4
        case .blueTang: 0.5
        case .yellowTang: 0.72
        case .neonTetra: 0.28
        case .angelfish: 0.74
        }
    }

    /// How far the dorsal and anal fins reach past the body, as a fraction of length.
    var finReach: CGFloat {
        switch self {
        case .angelfish: 0.62
        case .yellowTang: 0.2
        default: 0.14
        }
    }

    /// Cruising speed, points per second at depth 1.
    var cruise: ClosedRange<Double> {
        switch self {
        case .clownfish: 24...32
        case .blueTang: 42...54
        case .yellowTang: 34...44
        case .neonTetra: 44...58
        case .angelfish: 18...26
        }
    }

    /// One tail beat, in seconds, at cruising speed.
    var beat: Double {
        switch self {
        case .clownfish: 0.42
        case .blueTang: 0.62
        case .yellowTang: 0.55
        case .neonTetra: 0.3
        case .angelfish: 0.95
        }
    }

    /// Gap each fish keeps from its schoolmates, in body lengths.
    var spacing: Double { self == .neonTetra ? 1.4 : 1.9 }
}

/// Everything the fish tank paints, once at launch, with Core Graphics (see `paint` in Scenes.swift).
/// `fog` blends a thing toward the water colour, for things further back.
enum TankArt {
    static let fogColour = rgb(0.035, 0.27, 0.39)

    /// Washes everything already painted toward the water colour, keeping its alpha.
    static func fog(_ ctx: CGContext, _ rect: CGRect, _ amount: CGFloat) {
        guard amount > 0 else { return }
        ctx.saveGState()
        ctx.setBlendMode(.sourceAtop)
        ctx.setFillColor(fogColour.copy(alpha: amount)!)
        ctx.fill(rect)
        ctx.restoreGState()
    }

    private static func gradient(_ colours: [CGColor], _ locations: [CGFloat]? = nil) -> CGGradient {
        CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colours as CFArray, locations: locations)!
    }

    /// Rays fanning out from `origin`, clipped to `shape`: the fine bones in a fin.
    private static func rays(_ ctx: CGContext, in shape: CGPath, from origin: CGPoint, reach: CGFloat, colour: CGColor) {
        ctx.saveGState()
        ctx.addPath(shape)
        ctx.clip()
        ctx.setStrokeColor(colour)
        ctx.setLineWidth(0.6)
        for angle in stride(from: 0.0, to: 2 * Double.pi, by: 0.07) {
            ctx.move(to: origin)
            ctx.addLine(to: CGPoint(x: origin.x + reach * cos(angle), y: origin.y + reach * sin(angle)))
        }
        ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: - Fish

    /// A fish facing right: tail and fins behind a body shaded dark back to pale belly, its markings, a gill line,
    /// a translucent pectoral fin and an eye with a catchlight. Returns the texture and its size in points.
    static func fish(_ kind: Species, fog amount: CGFloat) -> (texture: SKTexture, size: CGSize) {
        let length = kind.length, bh = length * kind.bodyHeight, reach = length * kind.finReach
        let size = CGSize(width: length * 1.06, height: bh + 2 * reach + 8)
        let x = { (t: CGFloat) in length * 0.03 + t * length } // 0 = tail tip, 1 = nose
        let cy = size.height / 2, top = cy + bh / 2, bottom = cy - bh / 2
        let point = { (t: CGFloat, y: CGFloat) in CGPoint(x: x(t), y: cy + y * bh) }

        let (back, belly, finColour, finAlpha): (CGColor, CGColor, CGColor, CGFloat) = switch kind {
        case .clownfish: (rgb(0.92, 0.36, 0.04), rgb(1, 0.6, 0.2), rgb(0.97, 0.45, 0.08), 0.92)
        case .blueTang: (rgb(0.04, 0.17, 0.58), rgb(0.2, 0.46, 0.92), rgb(0.08, 0.26, 0.75), 0.88)
        case .yellowTang: (rgb(0.95, 0.74, 0.04), rgb(1, 0.92, 0.38), rgb(0.97, 0.8, 0.12), 0.85)
        case .neonTetra: (rgb(0.4, 0.42, 0.33), rgb(0.86, 0.88, 0.9), rgb(0.9, 0.95, 1), 0.28)
        case .angelfish: (rgb(0.55, 0.6, 0.64), rgb(0.93, 0.94, 0.96), rgb(0.86, 0.89, 0.93), 0.42)
        }
        let edged = kind == .clownfish || kind == .blueTang // fins with black margins

        let body = CGMutablePath()
        let tang = kind == .yellowTang // a steep forehead down to a long, low snout
        body.move(to: point(0.19, 0.1))
        body.addCurve(to: tang ? point(1, -0.14) : point(1, 0.04), control1: CGPoint(x: x(0.42), y: top + bh * 0.17),
                      control2: tang ? CGPoint(x: x(0.8), y: top - bh * 0.05) : CGPoint(x: x(0.9), y: top + bh * 0.02))
        body.addCurve(to: point(0.19, -0.1), control1: tang ? CGPoint(x: x(0.86), y: bottom + bh * 0.2) : CGPoint(x: x(0.92), y: bottom + bh * 0.04),
                      control2: CGPoint(x: x(0.45), y: bottom - bh * 0.17))
        body.closeSubpath()

        let spread = bh * (kind == .angelfish ? 0.55 : kind == .neonTetra ? 0.42 : 0.5)
        let tail = CGMutablePath()
        tail.move(to: point(0.23, 0.08))
        if kind == .clownfish || kind == .yellowTang { // a rounded fan
            tail.addCurve(to: point(0.23, -0.08), control1: CGPoint(x: x(-0.07), y: cy + spread * 1.15),
                          control2: CGPoint(x: x(-0.07), y: cy - spread * 1.15))
        } else { // forked
            tail.addQuadCurve(to: CGPoint(x: x(0), y: cy + spread), control: CGPoint(x: x(0.13), y: cy + spread * 0.3))
            tail.addQuadCurve(to: CGPoint(x: x(0.075), y: cy), control: CGPoint(x: x(0.06), y: cy + spread * 0.4))
            tail.addQuadCurve(to: CGPoint(x: x(0), y: cy - spread), control: CGPoint(x: x(0.06), y: cy - spread * 0.4))
            tail.addQuadCurve(to: point(0.23, -0.08), control: CGPoint(x: x(0.13), y: cy - spread * 0.3))
        }
        tail.closeSubpath()

        /// A dorsal (up) or anal fin from `front` back to `rear` along the body, peaking at `tip`, swept back.
        func fin(_ front: CGFloat, _ rear: CGFloat, tip: CGFloat, reach r: CGFloat, up: Bool) -> CGPath {
            let s: CGFloat = up ? 1 : -1, edge = bh / 2 + r * length
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x(front), y: cy + s * bh * 0.3))
            path.addCurve(to: CGPoint(x: x(tip), y: cy + s * edge), control1: CGPoint(x: x(front - 0.02), y: cy + s * (bh / 2 + r * length * 0.7)),
                          control2: CGPoint(x: x(tip + 0.12), y: cy + s * edge))
            path.addCurve(to: CGPoint(x: x(rear), y: cy + s * bh * 0.3), control1: CGPoint(x: x(tip - 0.05), y: cy + s * (edge - r * length * 0.25)),
                          control2: CGPoint(x: x(rear - 0.03), y: cy + s * bh * 0.42))
            path.closeSubpath()
            return path
        }
        let (dorsal, anal): (CGPath, CGPath) = switch kind {
        case .clownfish: (fin(0.74, 0.26, tip: 0.44, reach: 0.12, up: true), fin(0.5, 0.27, tip: 0.36, reach: 0.1, up: false))
        case .blueTang: (fin(0.8, 0.24, tip: 0.42, reach: 0.1, up: true), fin(0.62, 0.24, tip: 0.38, reach: 0.08, up: false))
        case .yellowTang: (fin(0.76, 0.24, tip: 0.44, reach: 0.2, up: true), fin(0.62, 0.24, tip: 0.42, reach: 0.18, up: false))
        case .neonTetra: (fin(0.56, 0.44, tip: 0.44, reach: 0.11, up: true), fin(0.46, 0.28, tip: 0.3, reach: 0.08, up: false))
        case .angelfish: (fin(0.64, 0.3, tip: 0.1, reach: 0.62, up: true), fin(0.6, 0.3, tip: 0.12, reach: 0.58, up: false))
        }
        let fins = [tail, dorsal, anal]

        let texture = paint(size) { ctx in
            // Fins and tail first, so the body sits over their roots.
            for (i, shape) in fins.enumerated() {
                let colour = kind == .blueTang && i == 0 ? rgb(0.98, 0.8, 0.1) : finColour
                ctx.addPath(shape)
                ctx.setFillColor(colour.copy(alpha: i == 0 ? max(finAlpha, 0.5) : finAlpha)!)
                ctx.fillPath()
                rays(ctx, in: shape, from: point(0.5, 0), reach: length, colour: rgb(0, 0, 0, 0.12))
                ctx.addPath(shape)
                ctx.setStrokeColor(edged ? rgb(0.02, 0.02, 0.05, 0.9) : rgb(0, 0, 0, 0.12))
                ctx.setLineWidth(edged ? 1.4 : 0.6)
                ctx.strokePath()
            }
            if kind == .angelfish { // long trailing pelvic filaments
                ctx.setStrokeColor(rgb(0.8, 0.84, 0.88, 0.6))
                ctx.setLineWidth(1.2)
                for dx: CGFloat in [0, 0.03] {
                    ctx.move(to: CGPoint(x: x(0.66 - dx), y: bottom + bh * 0.08))
                    ctx.addQuadCurve(to: CGPoint(x: x(0.36 - dx), y: bottom - length * 0.5),
                                     control: CGPoint(x: x(0.62 - dx), y: bottom - length * 0.3))
                }
                ctx.strokePath()
            }

            // Body: countershaded, then markings, a soft sheen for roundness, and a darker wrist before the tail.
            ctx.saveGState()
            ctx.addPath(body)
            ctx.clip()
            ctx.drawLinearGradient(gradient([belly, back]), start: CGPoint(x: 0, y: bottom), end: CGPoint(x: 0, y: top), options: [])
            markings(ctx, kind, x: x, cy: cy, bh: bh, length: length)
            ctx.drawRadialGradient(gradient([rgb(1, 1, 1, 0.26), rgb(1, 1, 1, 0)]), startCenter: point(0.68, 0.2), startRadius: 0,
                                   endCenter: point(0.68, 0.2), endRadius: bh * 0.75, options: [])
            ctx.drawLinearGradient(gradient([rgb(0, 0, 0, 0.18), rgb(0, 0, 0, 0)]), start: CGPoint(x: x(0.18), y: cy),
                                   end: CGPoint(x: x(0.45), y: cy), options: [])
            ctx.restoreGState()
            if kind == .angelfish { // its stripes run on into the fins
                ctx.saveGState()
                ctx.addPath(dorsal)
                ctx.addPath(anal)
                ctx.clip()
                for (t, w) in [(0.56, 0.08), (0.32, 0.06)] as [(CGFloat, CGFloat)] {
                    ctx.setFillColor(rgb(0.05, 0.05, 0.07, 0.5))
                    ctx.fill(CGRect(x: x(t - w / 2), y: 0, width: w * length, height: size.height))
                }
                ctx.restoreGState()
            }

            ctx.setStrokeColor(rgb(0, 0, 0, 0.28)) // gill cover
            ctx.setLineWidth(max(0.6, length * 0.012))
            ctx.move(to: point(0.74, 0.3))
            ctx.addQuadCurve(to: point(0.74, -0.3), control: point(0.68, 0))
            ctx.strokePath()
            ctx.addPath(body)
            ctx.setStrokeColor(rgb(0, 0, 0, 0.3))
            ctx.setLineWidth(0.8)
            ctx.strokePath()

            ctx.saveGState() // pectoral fin, over the body
            ctx.translateBy(x: x(0.64), y: cy - bh * 0.1)
            ctx.rotate(by: -0.4)
            let pectoral = CGRect(x: -length * 0.08, y: -length * 0.03, width: length * 0.16, height: length * 0.06)
            ctx.setFillColor(finColour.copy(alpha: 0.45)!)
            ctx.fillEllipse(in: pectoral)
            ctx.setStrokeColor(rgb(0, 0, 0, 0.15))
            ctx.setLineWidth(0.5)
            ctx.strokeEllipse(in: pectoral)
            ctx.restoreGState()

            let eye = point(kind == .yellowTang ? 0.8 : 0.86, 0.1), r = max(1.9, length * 0.045)
            let iris: CGColor = switch kind {
            case .clownfish: rgb(0.85, 0.45, 0.1)
            case .angelfish: rgb(0.75, 0.2, 0.12)
            case .neonTetra: rgb(0.75, 0.78, 0.8)
            default: rgb(0.12, 0.12, 0.16)
            }
            ctx.setFillColor(iris)
            ctx.fillEllipse(in: CGRect(x: eye.x - r, y: eye.y - r, width: 2 * r, height: 2 * r))
            ctx.setFillColor(rgb(0.02, 0.02, 0.03))
            ctx.fillEllipse(in: CGRect(x: eye.x - r * 0.65, y: eye.y - r * 0.65, width: 1.3 * r, height: 1.3 * r))
            ctx.setFillColor(rgb(1, 1, 1, 0.9))
            ctx.fillEllipse(in: CGRect(x: eye.x + r * 0.05, y: eye.y + r * 0.1, width: 0.55 * r, height: 0.55 * r))

            fog(ctx, CGRect(origin: .zero, size: size), amount)
        }
        return (texture, size)
    }

    /// Each species' pattern, drawn inside the body clip.
    private static func markings(_ ctx: CGContext, _ kind: Species, x: (CGFloat) -> CGFloat, cy: CGFloat, bh: CGFloat, length: CGFloat) {
        func point(_ t: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x(t), y: cy + y * bh) }
        switch kind {
        case .clownfish: // three white bands edged in black, the middle one bulging forward
            for (t, w, bulge) in [(0.76, 0.1, -0.05), (0.5, 0.11, 0.07), (0.235, 0.05, 0.0)] as [(CGFloat, CGFloat, CGFloat)] {
                let band = CGMutablePath()
                band.move(to: point(t - w / 2, 1))
                band.addQuadCurve(to: point(t - w / 2, -1), control: point(t - w / 2 + bulge, 0))
                band.addLine(to: point(t + w / 2, -1))
                band.addQuadCurve(to: point(t + w / 2, 1), control: point(t + w / 2 + bulge, 0))
                band.closeSubpath()
                ctx.addPath(band)
                ctx.setFillColor(rgb(0.98, 0.97, 0.94))
                ctx.fillPath()
                ctx.addPath(band)
                ctx.setStrokeColor(rgb(0.03, 0.02, 0.02))
                ctx.setLineWidth(1.5)
                ctx.strokePath()
            }
        case .blueTang: // the black "palette" sweeping from the eye to the tail and looping back
            ctx.setStrokeColor(rgb(0.02, 0.02, 0.06, 0.95))
            ctx.setLineCap(.round)
            ctx.setLineWidth(bh * 0.17)
            ctx.move(to: point(0.84, 0.24))
            ctx.addQuadCurve(to: point(0.22, 0.02), control: point(0.5, 0.62))
            ctx.strokePath()
            ctx.setLineWidth(bh * 0.1)
            ctx.move(to: point(0.3, 0.16))
            ctx.addQuadCurve(to: point(0.64, -0.1), control: point(0.36, -0.2))
            ctx.strokePath()
        case .yellowTang: // the white scalpel spine by the tail
            ctx.setFillColor(rgb(1, 1, 0.96, 0.95))
            ctx.fillEllipse(in: CGRect(x: x(0.2), y: cy - length * 0.012, width: length * 0.06, height: length * 0.024))
        case .neonTetra: // red lower rear, iridescent blue stripe with a glow
            ctx.saveGState()
            ctx.clip(to: CGRect(x: 0, y: 0, width: x(1.1), height: cy - bh * 0.02))
            ctx.drawLinearGradient(gradient([rgb(0.92, 0.1, 0.14), rgb(0.92, 0.1, 0.14, 0)]),
                                   start: CGPoint(x: x(0.3), y: 0), end: CGPoint(x: x(0.66), y: 0), options: [.drawsBeforeStartLocation])
            ctx.restoreGState()
            ctx.setLineCap(.round)
            for (width, alpha) in [(0.42, 0.3), (0.2, 1.0)] as [(CGFloat, CGFloat)] {
                ctx.setStrokeColor(rgb(0.2, 0.82, 1, alpha))
                ctx.setLineWidth(bh * width)
                ctx.move(to: point(0.84, 0.12))
                ctx.addLine(to: point(0.24, 0.04))
                ctx.strokePath()
            }
        case .angelfish: // black vertical bars, the first through the eye
            ctx.setFillColor(rgb(0.05, 0.05, 0.07, 0.62))
            for (t, w) in [(0.86, 0.05), (0.56, 0.08), (0.32, 0.06)] as [(CGFloat, CGFloat)] {
                ctx.fill(CGRect(x: x(t - w / 2), y: cy - bh, width: w * length, height: 2 * bh))
            }
        }
    }

    /// One tail beat as warp frames: a wave runs from head to tail, swinging the tail most and the head barely.
    static func swimWarps(_ kind: Species, textureHeight: CGFloat) -> [SKWarpGeometryGrid] {
        let columns = 8, frames = 20
        let source = (0...1).flatMap { row in (0...columns).map { SIMD2<Float>(Float($0) / Float(columns), Float(row)) } }
        return (0..<frames).map { frame in
            let phase = Double(frame) / Double(frames) * 2 * .pi
            let destination = source.map { p -> SIMD2<Float> in
                let u = Double(p.x) // 0 at the tail, 1 at the nose
                let swing = Double(kind.length) * (0.075 * pow(1 - u, 2) + 0.006) / Double(textureHeight)
                return SIMD2(p.x, p.y + Float(swing * sin(phase + 4.2 * u)))
            }
            return SKWarpGeometryGrid(columns: columns, rows: 1, sourcePositions: source, destinationPositions: destination)
        }
    }

    // MARK: - Plants

    enum Plant: CaseIterable {
        case kelp, redKelp, grass, stems, anemone
    }

    /// A clump of one plant, base at the bottom centre of the texture. Returns the texture and its size in points.
    static func plant(_ kind: Plant, height: CGFloat, fog amount: CGFloat) -> (texture: SKTexture, size: CGSize) {
        let size = CGSize(width: height * (kind == .anemone ? 1.6 : 0.5), height: height)
        let texture = paint(size) { ctx in
            let mid = size.width / 2
            switch kind {
            case .kelp, .redKelp:
                let (dark, light): (CGColor, CGColor) = kind == .kelp
                    ? [(rgb(0.08, 0.32, 0.14), rgb(0.42, 0.72, 0.3)), (rgb(0.22, 0.3, 0.08), rgb(0.6, 0.66, 0.26))].randomElement()!
                    : [(rgb(0.3, 0.05, 0.08), rgb(0.78, 0.24, 0.22)), (rgb(0.22, 0.07, 0.28), rgb(0.62, 0.32, 0.68))].randomElement()!
                for _ in 0..<Int.random(in: 3...5) {
                    blade(ctx, base: mid + .random(in: -0.12...0.12) * size.width, height: height * .random(in: 0.6...0.98),
                          width: height * .random(in: 0.05...0.08), lean: .random(in: -0.35...0.35) * size.width,
                          dark: dark, light: light)
                }
            case .grass:
                let tint = CGFloat.random(in: 0...0.15)
                for _ in 0..<14 {
                    blade(ctx, base: mid + .random(in: -0.2...0.2) * size.width, height: height * .random(in: 0.55...1),
                          width: .random(in: 4...7), lean: .random(in: -0.5...0.5) * size.width,
                          dark: rgb(0.06, 0.28 + tint, 0.12), light: rgb(0.35, 0.7 + tint, 0.32))
                }
            case .stems: // bushy stems, green low down and red toward the tips, like Rotala
                for _ in 0..<7 {
                    let base = mid + .random(in: -0.22...0.22) * size.width, tall = height * .random(in: 0.5...1)
                    let lean = CGFloat.random(in: -0.25...0.25) * size.width
                    ctx.setStrokeColor(rgb(0.16, 0.34, 0.14))
                    ctx.setLineWidth(1.4)
                    ctx.move(to: CGPoint(x: base, y: 0))
                    ctx.addQuadCurve(to: CGPoint(x: base + lean, y: tall), control: CGPoint(x: base, y: tall * 0.5))
                    ctx.strokePath()
                    for i in stride(from: 0.04, to: 1.02, by: 0.026) as StrideTo<CGFloat> {
                        let p = CGPoint(x: base + lean * i * i, y: tall * i), leaf = height * 0.032 * (1.2 - 0.45 * i)
                        let colour = mixRGB(rgb(0.22, 0.52, 0.2), rgb(0.95, 0.35, 0.38), pow(i, 1.3) * .random(in: 0.85...1))
                        for up in [0.45 + 0.8 * i, .pi - 0.45 - 0.8 * i] { // a pair, pointing more upward near the tip
                            ctx.saveGState()
                            ctx.translateBy(x: p.x, y: p.y)
                            ctx.rotate(by: up + .random(in: -0.15...0.15))
                            let shape = CGRect(x: 0, y: -leaf * 0.3, width: leaf, height: leaf * 0.6)
                            ctx.setFillColor(colour)
                            ctx.fillEllipse(in: shape)
                            ctx.setStrokeColor(rgb(0, 0, 0, 0.15))
                            ctx.setLineWidth(0.5)
                            ctx.strokeEllipse(in: shape)
                            ctx.restoreGState()
                        }
                    }
                }
            case .anemone: // a squat column crowned with tan tentacles and pink bulb tips
                ctx.setFillColor(rgb(0.45, 0.28, 0.3))
                ctx.fillEllipse(in: CGRect(x: mid - height * 0.25, y: -height * 0.1, width: height * 0.5, height: height * 0.4))
                ctx.setLineCap(.round)
                for i in 0..<60 {
                    let angle = CGFloat.pi * (0.08 + 0.84 * CGFloat(i) / 59) + .random(in: -0.06...0.06)
                    let reach = height * .random(in: 0.55...0.85)
                    let root = CGPoint(x: mid + cos(angle) * height * 0.18, y: height * 0.2)
                    let tip = CGPoint(x: root.x + cos(angle) * reach * 0.9, y: root.y + sin(angle) * reach * 0.8)
                    ctx.setStrokeColor(mixRGB(rgb(0.6, 0.48, 0.36), rgb(0.78, 0.6, 0.48), .random(in: 0...1)))
                    ctx.setLineWidth(height * 0.06)
                    ctx.move(to: root)
                    ctx.addQuadCurve(to: tip, control: CGPoint(x: root.x + cos(angle) * reach * 0.2, y: tip.y))
                    ctx.strokePath()
                    ctx.setFillColor(rgb(0.86, 0.38, 0.6))
                    let r = height * 0.045
                    ctx.fillEllipse(in: CGRect(x: tip.x - r, y: tip.y - r, width: 2 * r, height: 2 * r))
                }
            }
            fog(ctx, CGRect(origin: .zero, size: size), amount)
        }
        return (texture, size)
    }

    /// A tapering, gently waving ribbon from the bottom of the texture, dark at the base and light at the tip,
    /// with a paler midrib.
    private static func blade(_ ctx: CGContext, base: CGFloat, height: CGFloat, width: CGFloat, lean: CGFloat,
                              dark: CGColor, light: CGColor) {
        let steps = 24, wiggle = CGFloat.random(in: 0...(2 * .pi))
        let spine = (0...steps).map { i -> (CGPoint, CGFloat) in
            let v = CGFloat(i) / CGFloat(steps)
            let p = CGPoint(x: base + lean * v * v + sin(v * 5 + wiggle) * width * 0.4, y: height * v)
            return (p, width * (1 - pow(v, 2.2)) * (0.75 + 0.25 * sin(v * .pi)) / 2 + 0.4)
        }
        let path = CGMutablePath()
        path.addLines(between: spine.map { CGPoint(x: $0.0.x - $0.1, y: $0.0.y) } + spine.reversed().map { CGPoint(x: $0.0.x + $0.1, y: $0.0.y) })
        path.closeSubpath()
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.drawLinearGradient(gradient([dark, light]), start: .zero, end: CGPoint(x: 0, y: height), options: [])
        ctx.restoreGState()
        ctx.addPath(path)
        ctx.setStrokeColor(rgb(0, 0, 0, 0.18))
        ctx.setLineWidth(0.6)
        ctx.strokePath()
        ctx.addLines(between: spine.map(\.0))
        ctx.setStrokeColor(rgb(1, 1, 0.8, 0.14))
        ctx.setLineWidth(0.8)
        ctx.strokePath()
    }

    /// Sway as warp frames: bending grows from the base to the tip, with the tip lagging a little.
    static func swayWarps(width: CGFloat, height: CGFloat, strength: CGFloat, period: Double) -> SKAction {
        let rows = 8, frames = 16
        let source = (0...rows).flatMap { row in (0...1).map { SIMD2<Float>(Float($0), Float(row) / Float(rows)) } }
        let second = Double.random(in: 0...(2 * .pi))
        let warps = (0...frames).map { frame in
            let phase = Double(frame) / Double(frames) * 2 * .pi
            let destination = source.map { p -> SIMD2<Float> in
                let v = Double(p.y)
                let bend = pow(v, 1.6) * sin(phase - 1.3 * v) + 0.3 * v * v * sin(2 * phase + second)
                return SIMD2(p.x + Float(Double(strength * height / width) * bend), p.y)
            }
            return SKWarpGeometryGrid(columns: 1, rows: rows, sourcePositions: source, destinationPositions: destination)
        }
        let times = (0...frames).map { NSNumber(value: period * Double($0) / Double(frames)) }
        return .repeatForever(SKAction.animate(withWarps: warps, times: times)!)
    }

    // MARK: - Hardscape

    /// A rounded stone lit from above, mottled, with a little algae on top. Flat along the bottom where it sits.
    static func rock(_ size: CGSize, fog amount: CGFloat) -> SKTexture {
        let tone = CGFloat.random(in: 0...1)
        let (dark, light) = (mixRGB(rgb(0.2, 0.2, 0.22), rgb(0.28, 0.22, 0.18), tone), mixRGB(rgb(0.62, 0.62, 0.6), rgb(0.7, 0.6, 0.5), tone))
        return paint(size) { ctx in
            let centre = CGPoint(x: size.width / 2, y: size.height * 0.42), n = 11
            let points = (0..<n).map { i -> CGPoint in
                let a = CGFloat(i) / CGFloat(n) * 2 * .pi, r = CGFloat.random(in: 0.78...1)
                let down = sin(a) < 0 ? 0.72 : 1 // a flatter, still rounded underside to sit on
                return CGPoint(x: centre.x + cos(a) * size.width * 0.48 * r, y: centre.y + sin(a) * size.height * 0.56 * r * down)
            }
            let path = CGMutablePath() // smooth closed curve through the midpoints
            let mids = (0..<n).map { CGPoint(x: (points[$0].x + points[($0 + 1) % n].x) / 2, y: (points[$0].y + points[($0 + 1) % n].y) / 2) }
            path.move(to: mids[n - 1])
            for i in 0..<n { path.addQuadCurve(to: mids[i], control: points[i]) }
            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip()
            ctx.drawLinearGradient(gradient([dark, light]), start: CGPoint(x: 0, y: size.height * 0.1),
                                   end: CGPoint(x: size.width * 0.15, y: size.height * 0.95), options: [])
            ctx.setStrokeColor(rgb(0, 0, 0, 0.12)) // faint strata
            ctx.setLineWidth(1)
            for row in stride(from: size.height * 0.15, to: size.height, by: size.height * .random(in: 0.13...0.2)) as StrideTo<CGFloat> {
                let tilt = CGFloat.random(in: -0.1...0.1) * size.height
                ctx.move(to: CGPoint(x: 0, y: row))
                ctx.addQuadCurve(to: CGPoint(x: size.width, y: row + tilt), control: CGPoint(x: size.width / 2, y: row + tilt + .random(in: -4...4)))
            }
            ctx.strokePath()
            for _ in 0..<Int(size.width * size.height / 120) {
                let r = CGFloat.random(in: 0.5...(size.width * 0.05))
                ctx.setFillColor(Bool.random() ? rgb(0, 0, 0, 0.1) : rgb(1, 1, 1, 0.07))
                ctx.fillEllipse(in: CGRect(x: .random(in: 0...size.width), y: .random(in: 0...size.height), width: r, height: r * 0.7))
            }
            ctx.setFillColor(rgb(0.25, 0.45, 0.2, 0.45)) // algae where the light lands
            for _ in 0..<5 {
                let w = size.width * .random(in: 0.1...0.3)
                ctx.fillEllipse(in: CGRect(x: .random(in: size.width * 0.15...size.width * 0.7), y: size.height * .random(in: 0.7...0.9),
                                           width: w, height: w * 0.35))
            }
            ctx.drawLinearGradient(gradient([rgb(0, 0, 0, 0.35), rgb(0, 0, 0, 0)]), start: .zero,
                                   end: CGPoint(x: 0, y: size.height * 0.35), options: [])
            ctx.restoreGState()
            fog(ctx, CGRect(origin: .zero, size: size), amount)
        }
    }

    /// A weathered branch lying on its side: a thick tapering trunk, a few limbs and a stub reaching up, lit
    /// from above, with bark grain and knots.
    static func driftwood(_ size: CGSize, fog amount: CGFloat) -> SKTexture {
        paint(size) { ctx in
            let limbs: [(CGPoint, CGPoint, CGPoint, CGFloat, CGFloat)] = [ // from, via, to, thickness at each end
                (CGPoint(x: 0.15, y: 0.3), CGPoint(x: 0.14, y: 0.45), CGPoint(x: 0.08, y: 0.55), 0.1, 0.06),
                (CGPoint(x: 0.38, y: 0.36), CGPoint(x: 0.46, y: 0.72), CGPoint(x: 0.33, y: 0.97), 0.13, 0.035),
                (CGPoint(x: 0.66, y: 0.33), CGPoint(x: 0.76, y: 0.58), CGPoint(x: 0.9, y: 0.78), 0.1, 0.03),
                (CGPoint(x: 0.09, y: 0.2), CGPoint(x: 0.5, y: 0.44), CGPoint(x: 0.95, y: 0.17), 0.3, 0.1),
            ]
            for (from, via, to, thick, thin) in limbs {
                let steps = 60
                let spine = (0...steps).map { i -> (CGPoint, CGFloat) in
                    let t = CGFloat(i) / CGFloat(steps), u = 1 - t
                    let p = CGPoint(x: (u * u * from.x + 2 * u * t * via.x + t * t * to.x) * size.width,
                                    y: (u * u * from.y + 2 * u * t * via.y + t * t * to.y) * size.height)
                    let knobble = 1 + 0.12 * sin(t * 23 + thick * 40)
                    return (p, (thick + (thin - thick) * t) * size.height * knobble / 2)
                }
                // The limb is a chain of overlapping discs: an even round tube with rounded ends at any angle.
                let path = CGMutablePath()
                for (p, r) in spine { path.addEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)) }
                let normals = spine.indices.map { i -> CGVector in
                    let a = spine[max(i - 1, 0)].0, b = spine[min(i + 1, steps)].0
                    let (dx, dy) = (b.x - a.x, b.y - a.y), l = max(hypot(dx, dy), 0.001)
                    return CGVector(dx: -dy / l, dy: dx / l)
                }
                ctx.saveGState()
                ctx.addPath(path)
                ctx.clip()
                ctx.drawLinearGradient(gradient([rgb(0.2, 0.15, 0.11), rgb(0.42, 0.34, 0.25), rgb(0.62, 0.54, 0.43)], [0, 0.55, 1]),
                                       start: CGPoint(x: 0, y: spine.map(\.0.y).min()! - thick * size.height / 2),
                                       end: CGPoint(x: 0, y: spine.map(\.0.y).max()! + thick * size.height / 2), options: [])
                ctx.setLineWidth(0.8) // grain running along the wood
                for lane in stride(from: -0.8, through: 0.8, by: 0.27) as StrideThrough<CGFloat> {
                    ctx.setStrokeColor(rgb(0.12, 0.09, 0.06, .random(in: 0.15...0.3)))
                    ctx.addLines(between: spine.indices.map { i in
                        let (p, r) = spine[i], wobble = r * lane + .random(in: -0.6...0.6)
                        return CGPoint(x: p.x + normals[i].dx * wobble, y: p.y + normals[i].dy * wobble)
                    })
                    ctx.strokePath()
                }
                ctx.setFillColor(rgb(0.14, 0.1, 0.07, 0.6))
                for _ in 0..<2 {
                    let (p, r) = spine[Int.random(in: 5...(steps - 5))]
                    ctx.fillEllipse(in: CGRect(x: p.x - r * 0.35, y: p.y - r * 0.25, width: r * 0.7, height: r * 0.5))
                }
                ctx.restoreGState()
            }
            fog(ctx, CGRect(origin: .zero, size: size), amount)
        }
    }

    /// The sand floor, seen from the side: its back edge rolls gently and fades into the water, with grains,
    /// pebbles and soft ripples up front.
    static func sand(_ size: CGSize) -> SKTexture {
        paint(size) { ctx in
            let edge = { (x: CGFloat) in size.height * (0.93 + 0.035 * sin(x / 230 + 1) + 0.02 * sin(x / 71)) }
            let path = CGMutablePath()
            path.move(to: .zero)
            for x in stride(from: 0, through: size.width + 8, by: 8) { path.addLine(to: CGPoint(x: x, y: edge(x))) }
            path.addLine(to: CGPoint(x: size.width + 8, y: 0))
            path.closeSubpath()
            ctx.addPath(path)
            ctx.clip()
            ctx.drawLinearGradient(gradient([rgb(0.74, 0.64, 0.47), rgb(0.55, 0.5, 0.4), rgb(0.12, 0.3, 0.36)], [0, 0.55, 1]),
                                   start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            for _ in 0..<Int(size.width * size.height / 40) {
                let y = CGFloat.random(in: 0...size.height), near = 1 - y / size.height
                let r = CGFloat.random(in: 0.4...1.3) * (0.5 + near)
                ctx.setFillColor(Bool.random() ? rgb(0.3, 0.24, 0.16, 0.22 * near) : rgb(1, 0.96, 0.85, 0.2 * near))
                ctx.fillEllipse(in: CGRect(x: .random(in: 0...size.width), y: y, width: r, height: r * 0.8))
            }
            for _ in 0..<Int(size.width / 14) { // pebbles, bigger toward the front
                let y = size.height * pow(.random(in: 0...1), 1.6) * 0.8, near = 1 - y / size.height
                let w = CGFloat.random(in: 3...9) * (0.4 + near), p = CGRect(x: .random(in: 0...size.width), y: y, width: w, height: w * 0.6)
                ctx.saveGState()
                ctx.addEllipse(in: p)
                ctx.clip()
                ctx.drawLinearGradient(gradient([mixRGB(rgb(0.3, 0.27, 0.24), rgb(0.12, 0.3, 0.36), 1 - near),
                                                 mixRGB(rgb(0.78, 0.74, 0.68), rgb(0.12, 0.3, 0.36), 1 - near)]),
                                       start: CGPoint(x: 0, y: p.minY), end: CGPoint(x: 0, y: p.maxY), options: [])
                ctx.restoreGState()
            }
            ctx.setStrokeColor(rgb(0.25, 0.2, 0.12, 0.08)) // ripples
            ctx.setLineWidth(1.5)
            for row in stride(from: 6, to: size.height * 0.7, by: 11) as StrideTo<CGFloat> {
                ctx.move(to: CGPoint(x: 0, y: row))
                for x in stride(from: 0, through: size.width, by: 12) {
                    ctx.addLine(to: CGPoint(x: x, y: row + 2.5 * sin(x / 40 + row)))
                }
            }
            ctx.strokePath()
        }
    }

    /// Distant rocks along the back of the tank, lost in the haze.
    static func farRocks(_ size: CGSize) -> SKTexture {
        paint(size) { ctx in
            var x = CGFloat.random(in: -40...0)
            while x < size.width + 40 {
                let w = CGFloat.random(in: 80...220), h = size.height * .random(in: 0.35...1)
                let rock = CGMutablePath()
                rock.move(to: CGPoint(x: x - w / 2, y: 0))
                rock.addCurve(to: CGPoint(x: x + .random(in: -0.15...0.15) * w, y: h),
                              control1: CGPoint(x: x - w * 0.5, y: h * 0.7), control2: CGPoint(x: x - w * 0.3, y: h))
                rock.addCurve(to: CGPoint(x: x + w / 2, y: 0), control1: CGPoint(x: x + w * 0.35, y: h), control2: CGPoint(x: x + w * 0.5, y: h * 0.6))
                ctx.saveGState()
                ctx.addPath(rock)
                ctx.clip()
                ctx.drawLinearGradient(gradient([rgb(0.05, 0.2, 0.28), rgb(0.1, 0.33, 0.42)]), start: .zero,
                                       end: CGPoint(x: 0, y: h), options: [])
                ctx.restoreGState()
                x += w * .random(in: 0.45...0.8)
            }
        }
    }

    /// A bubble: a thin bright rim, a faint fill and a catchlight.
    static func bubble() -> SKTexture { paint(CGSize(width: 16, height: 16)) { ctx in
        let ring = CGRect(x: 1, y: 1, width: 14, height: 14)
        ctx.setFillColor(rgb(0.8, 0.95, 1, 0.12))
        ctx.fillEllipse(in: ring)
        ctx.setStrokeColor(rgb(0.9, 1, 1, 0.75))
        ctx.setLineWidth(1)
        ctx.strokeEllipse(in: ring)
        ctx.setFillColor(rgb(1, 1, 1, 0.9))
        ctx.fillEllipse(in: CGRect(x: 4, y: 9, width: 3.5, height: 2.5))
    } }
}
