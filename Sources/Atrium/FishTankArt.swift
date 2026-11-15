import CoreImage
import SpriteKit

/// The fish in the reef tank, each drawn from photo cut-outs (Resources/reef-*.heic, credited in reef-credits.tsv),
/// with the numbers that drive its swimming.
enum Species: CaseIterable {
    case chromis, yellowTang, blueTang, clownfish, royalGramma, firefish, flameAngel

    /// The cut-outs to draw it from, facing right. A school mixes them, so its fish aren't clones.
    var photos: [String] {
        switch self {
        case .chromis: (1...3).map { "reef-chromis-\($0)" }
        case .yellowTang: (1...4).map { "reef-yellowtang-\($0)" }
        case .blueTang: (1...3).map { "reef-bluetang-\($0)" }
        case .clownfish: (1...3).map { "reef-clownfish-\($0)" }
        case .royalGramma: ["reef-gramma-2"]
        case .firefish: (1...3).map { "reef-firefish-\($0)" }
        case .flameAngel: (1...3).map { "reef-flameangel-\($0)" }
        }
    }

    /// Nose to tail tip, in points at depth 1: the young adults of a home reef tank, scaled together.
    var length: CGFloat {
        switch self {
        case .chromis: 46
        case .yellowTang: 88
        case .blueTang: 100
        case .clownfish: 54
        case .royalGramma: 44
        case .firefish: 50
        case .flameAngel: 58
        }
    }

    /// Cruising speed, points per second at depth 1. The small, shy species hover more than they swim.
    var cruise: ClosedRange<Double> {
        switch self {
        case .chromis: 40...54
        case .yellowTang: 30...40
        case .blueTang: 36...48
        case .clownfish: 20...28
        case .royalGramma: 12...18
        case .firefish: 10...16
        case .flameAngel: 18...26
        }
    }

    /// One tail beat, in seconds, at cruising speed.
    var beat: Double {
        switch self {
        case .chromis: 0.3
        case .yellowTang: 0.55
        case .blueTang: 0.6
        case .clownfish: 0.4
        case .royalGramma, .flameAngel: 0.45
        case .firefish: 0.35
        }
    }

    /// Burst and coast: a few quick tail beats, then a glide, as small reef fish swim. The cycle in seconds and the
    /// share of it spent beating. Nil swims steadily.
    var burst: (cycle: Double, share: Double)? {
        switch self {
        case .chromis: (1.3, 0.45)
        case .firefish: (2.4, 0.25) // hovers, then darts
        default: nil
        }
    }

    /// Gap each fish keeps from its schoolmates, in body lengths.
    var spacing: Double { self == .chromis ? 1.3 : 1.9 }

    /// Where it stays: clownfish by their anemone, the small, shy species low by the rock, the rest anywhere.
    enum Haunt { case open, anemone, rock }
    var haunt: Haunt {
        switch self {
        case .clownfish: .anemone
        case .royalGramma, .firefish, .flameAngel: .rock
        default: .open
        }
    }
}

/// Loads the tank's photo cut-outs and builds the warps that swim and sway them.
enum TankArt {
    /// A photo cut-out from Resources, drawn `width` points wide with its height from its shape, and softened by
    /// `blur` points, like a camera's depth of field for things further back. A blurred one comes with a clear
    /// `margin(blur:)` all round, included in its size, so its blur isn't cut off straight at the photo's edge.
    /// Nil if the file's missing.
    @MainActor static func photo(_ name: String, width: CGFloat, blur: CGFloat = 0) -> (texture: SKTexture, size: CGSize)? {
        // Drawn at the nearest sixteenth of an octave, SpriteKit scaling the last 2% at most, so a reef laid out
        // again at slightly different sizes finds most of its cut-outs already drawn.
        let drawnWidth = exp2((log2(width) * 16).rounded() / 16), key = "\(name) \(drawnWidth) \(blur)" as NSString
        let m = 2 * margin(blur: blur)
        if let texture = drawn.object(forKey: key), let aspect = aspects[name] { return (texture, CGSize(width: width + m, height: width * aspect + m)) }
        guard var image = NSImage(contentsOf: file(name, pixels: 2 * drawnWidth))?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }
        let aspect = CGFloat(image.height) / CGFloat(image.width), drawnSize = CGSize(width: drawnWidth + m, height: drawnWidth * aspect + m)
        aspects[name] = aspect
        if blur > 0 { image = blurred(image, sigma: blur * CGFloat(image.width) / drawnWidth) ?? image }
        let texture = paint(drawnSize) { ctx in
            ctx.interpolationQuality = .high
            ctx.draw(image, in: CGRect(origin: .zero, size: drawnSize))
        }
        drawn.setObject(texture, forKey: key)
        return (texture, CGSize(width: width + m, height: width * aspect + m))
    }

    /// The picture to draw a cut-out `pixels` wide from: `<name>-big.heic`, a sharper copy, where there is one and the
    /// cut-out is drawn over 1.2 times the width of `<name>.heic`, as big displays draw the live rock and the tenuis
    /// Acropora; else `<name>.heic`. The big ones take about four times as long to decode, which laptops, drawing
    /// them at about their size, would pay on every tank built for no gain.
    static func file(_ name: String, pixels: CGFloat) -> URL {
        let small = resource(name + ".heic"), big = resource(name + "-big.heic")
        guard FileManager.default.fileExists(atPath: big.path), let source = CGImageSourceCreateWithURL(small as CFURL, nil),
              let width = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])?[kCGImagePropertyPixelWidth] as? Int
        else { return small }
        return pixels > 1.2 * CGFloat(width) ? big : small
    }

    /// The clear margin round a cut-out blurred by `blur` points: three sigma, where the blur has faded out.
    static func margin(blur: CGFloat) -> CGFloat { 3 * blur }

    /// The lamp's light on the tank's floor, focused by the rippled surface: filaments that fork, bunch into bright
    /// knots and fade out, as real caustics do. One tile that repeats, 512 texels plus a wrapped row and column, about
    /// 16 cells of light across, with the light over 8 times the mean in red, green and blue. Baked once while any
    /// tank shows it.
    @MainActor static func caustics() -> SKTexture {
        sharedTexture("fish tank caustics") {
            let n = 512, light = causticLight(n)
            var bytes = [UInt8](repeating: 255, count: (n + 1) * (n + 1) * 4)
            for y in 0...n {
                for x in 0...n {
                    let v = UInt8((min(light[y % n * n + x % n] / 8, 1) * 255).rounded()), i = (y * (n + 1) + x) * 4
                    (bytes[i], bytes[i + 1], bytes[i + 2]) = (v, v, v)
                }
            }
            let texture = SKTexture(data: Data(bytes), size: CGSize(width: n + 1, height: n + 1))
            texture.filteringMode = .linear
            return texture
        }
    }

    /// The light under a rippled surface on a tile `n` texels across, relative to its mean: rays sent straight down
    /// through a surface of summed sines are bent by its slope, and counting where they land gives the light.
    static func causticLight(_ n: Int) -> [Float] {
        var rng = SplitMix(state: 3)
        var waves: [(m: Float, k: Float, phase: Float, height: Float)] = [] // whole waves across the tile, so it repeats
        while waves.count < 24 {
            let m = Int.random(in: -20...20, using: &rng), k = Int.random(in: -20...20, using: &rng)
            let length = Float(m * m + k * k).squareRoot()
            if (5...20).contains(length) {
                waves.append((Float(m), Float(k), .random(in: 0..<(2 * .pi), using: &rng), 1 / (length * length)))
            }
        }
        // The surface's slope at each texel corner, sin(a + b) taken apart so each wave costs no sines per texel.
        var gx = [Float](repeating: 0, count: n * n), gy = gx
        for w in waves {
            let a = (0..<n).map { 2 * Float.pi * w.m * Float($0) / Float(n) }
            let b = (0..<n).map { 2 * Float.pi * w.k * Float($0) / Float(n) + w.phase }
            let (sa, ca, sb, cb) = (a.map(sin), a.map(cos), b.map(sin), b.map(cos))
            for y in 0..<n {
                for x in 0..<n {
                    let s = w.height * (sa[x] * cb[y] + ca[x] * sb[y])
                    gx[y * n + x] -= s * w.m
                    gy[y * n + x] -= s * w.k
                }
            }
        }
        let rms = (zip(gx, gy).reduce(0) { $0 + $1.0 * $1.0 + $1.1 * $1.1 } / Float(n * n)).squareRoot()
        let reach = 0.011 * Float(n) / rms // texels a ray is bent per unit of slope: just past the first focus
        // Four rays to a texel, each landing where the slope there sends it, shared between the four texels round it.
        var light = [Float](repeating: 0, count: n * n)
        func wrap(_ i: Int) -> Int { (i % n + n) % n }
        for j in 0..<(2 * n) {
            for i in 0..<(2 * n) {
                let px = (Float(i) + 0.5) / 2, py = (Float(j) + 0.5) / 2
                let x0 = Int(px), y0 = Int(py), fx = px - Float(x0), fy = py - Float(y0)
                let (c0, c1, c2, c3) = (y0 * n + x0, y0 * n + wrap(x0 + 1), wrap(y0 + 1) * n + x0, wrap(y0 + 1) * n + wrap(x0 + 1))
                let (w0, w1, w2, w3) = ((1 - fx) * (1 - fy), fx * (1 - fy), (1 - fx) * fy, fx * fy)
                let lx = px - 0.5 + reach * (gx[c0] * w0 + gx[c1] * w1 + gx[c2] * w2 + gx[c3] * w3)
                let ly = py - 0.5 + reach * (gy[c0] * w0 + gy[c1] * w1 + gy[c2] * w2 + gy[c3] * w3)
                let lx0 = Int(lx.rounded(.down)), ly0 = Int(ly.rounded(.down)), ux = lx - Float(lx0), uy = ly - Float(ly0)
                light[wrap(ly0) * n + wrap(lx0)] += (1 - ux) * (1 - uy)
                light[wrap(ly0) * n + wrap(lx0 + 1)] += ux * (1 - uy)
                light[wrap(ly0 + 1) * n + wrap(lx0)] += (1 - ux) * uy
                light[wrap(ly0 + 1) * n + wrap(lx0 + 1)] += ux * uy
            }
        }
        return light.map { $0 / 4 }
    }

    /// The cut-outs as drawn, while any tank still shows them: a tank built for a new setting takes most of the
    /// one it replaces' rather than drawing all 40-odd again, about 10 ms each on the main thread. Held weakly, so
    /// they go with the last tank.
    @MainActor private static let drawn = NSMapTable<NSString, SKTexture>.strongToWeakObjects()
    @MainActor private static var aspects: [String: CGFloat] = [:]

    /// The top edge of a cut-out: for each of `samples` columns from left to right, the height of its highest solid
    /// pixel as a fraction of the image's height (0 where the column is empty). For setting things on a rock.
    @MainActor static func skyline(_ name: String, samples: Int = 48) -> [CGFloat] {
        if let line = skylines["\(name) \(samples)"] { return line }
        let line = readSkyline(name, samples: samples)
        skylines["\(name) \(samples)"] = line
        return line
    }

    /// A few hundred bytes each, kept: each costs a decode.
    @MainActor private static var skylines: [String: [CGFloat]] = [:]

    private static func readSkyline(_ name: String, samples: Int) -> [CGFloat] {
        guard let image = NSImage(contentsOf: resource(name + ".heic"))?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return [] }
        let rows = max(8, samples * image.height / max(image.width, 1))
        var alpha = [UInt8](repeating: 0, count: samples * rows)
        guard let ctx = CGContext(data: &alpha, width: samples, height: rows, bitsPerComponent: 8, bytesPerRow: samples,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue)
        else { return [] }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: samples, height: rows))
        return (0..<samples).map { x in // the bitmap's first row is the image's top
            (0..<rows).first { alpha[$0 * samples + x] > 128 }.map { CGFloat(rows - $0) / CGFloat(rows) } ?? 0
        }
    }

    private static let imaging = CIContext()

    private static func blurred(_ image: CGImage, sigma: CGFloat) -> CGImage? {
        let source = CIImage(cgImage: image)
        // Not clamped: that smeared a cut-out's edges into a faint box beside it. Cropped to its own box, the blur
        // was cut off there, leaving the back cluster's base and sides razor-straight.
        let padded = source.extent.insetBy(dx: -margin(blur: sigma), dy: -margin(blur: sigma))
        return imaging.createCGImage(source.applyingGaussianBlur(sigma: sigma).cropped(to: padded), from: padded)
    }

    /// One tail beat as warp frames: a wave travelling from head to tail, swinging the tail most.
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

    /// A slow sway in the current, bending most at the top and lagging there, as a repeating warp action. `phase` sets
    /// where its second, quicker sway starts.
    static func swayWarps(width: CGFloat, height: CGFloat, strength: CGFloat, period: Double, phase second: Double) -> SKAction {
        let rows = 8, frames = 16
        let source = (0...rows).flatMap { row in (0...1).map { SIMD2<Float>(Float($0), Float(row) / Float(rows)) } }
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
}
