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
    /// `blur` points, like a camera's depth of field for things further back. Nil if the file's missing.
    static func photo(_ name: String, width: CGFloat, blur: CGFloat = 0) -> (texture: SKTexture, size: CGSize)? {
        guard var image = NSImage(contentsOf: resource(name + ".heic"))?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }
        let size = CGSize(width: width, height: width * CGFloat(image.height) / CGFloat(image.width))
        if blur > 0 { image = blurred(image, sigma: blur * CGFloat(image.width) / width) ?? image }
        let texture = paint(size) { ctx in
            ctx.interpolationQuality = .high
            ctx.draw(image, in: CGRect(origin: .zero, size: size))
        }
        return (texture, size)
    }

    private static let imaging = CIContext()

    private static func blurred(_ image: CGImage, sigma: CGFloat) -> CGImage? {
        let source = CIImage(cgImage: image)
        let soft = source.clampedToExtent().applyingGaussianBlur(sigma: sigma).cropped(to: source.extent)
        return imaging.createCGImage(soft, from: source.extent)
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

    /// A slow sway in the current, bending most at the top and lagging there, as a repeating warp action.
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
}
