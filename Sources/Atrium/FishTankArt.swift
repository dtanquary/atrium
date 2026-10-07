import CoreImage
import SpriteKit

/// One kind of animal in a tank, drawn from photo cut-outs (Resources/<tank>-*.heic, credited in the tank's
/// credits TSV), with the numbers that drive its swimming. The table is `Species.all`; add a line to add a species.
struct Species {
    let name: String
    /// The cut-outs to draw it from, facing right. A school mixes them, so its fish aren't clones.
    let photos: [String]
    /// Nose to tail tip, in points at depth 1: the young adults of a home reef tank, scaled together.
    let length: CGFloat
    /// Cruising speed, points per second at depth 1. The small, shy species hover more than they swim.
    let cruise: ClosedRange<Double>
    /// One tail beat, in seconds, at cruising speed.
    let beat: Double
    /// Burst and coast: a few quick tail beats, then a glide, as small reef fish swim. The cycle in seconds and the
    /// share of it spent beating. Nil swims steadily.
    var burst: (cycle: Double, share: Double)? = nil
    /// Gap each fish keeps from its schoolmates, in body lengths.
    var spacing = 1.9
    /// Where it stays: clownfish by their anemone, the small, shy species low by the rock, bottom sharks and rays
    /// on the sand, the rest anywhere.
    enum Haunt { case open, anemone, rock, sand }
    var haunt = Haunt.open
    /// How it swims: a wave from head to tail, or wings whose tips sweep up and down together (rays).
    enum Gait { case tail, wings }
    var gait = Gait.tail
    /// Lies still on the sand between short moves, using `burst` as the move-and-rest cycle (bottom sharks, rays).
    var rests = false
    /// How far past the screen edge it swims before turning, in body lengths: big animals leave the screen first,
    /// so they never turn round in view.
    var margin = 0.0
    /// The part of the water column it keeps to, 0 at the sand and 1 at the top: whale sharks cruise high, bottom
    /// sharks stay low.
    var height: ClosedRange<Double> = 0...1

    // The reef tank
    static let chromis = Species(name: "chromis", photos: (1...3).map { "reef-chromis-\($0)" }, length: 46, cruise: 40...54, beat: 0.3,
                                 burst: (1.3, 0.45), spacing: 1.3)
    static let yellowTang = Species(name: "yellow tang", photos: (1...4).map { "reef-yellowtang-\($0)" }, length: 88, cruise: 30...40, beat: 0.55)
    static let blueTang = Species(name: "blue tang", photos: (1...3).map { "reef-bluetang-\($0)" }, length: 100, cruise: 36...48, beat: 0.6)
    static let clownfish = Species(name: "clownfish", photos: (1...3).map { "reef-clownfish-\($0)" }, length: 54, cruise: 20...28, beat: 0.4,
                                   haunt: .anemone)
    static let royalGramma = Species(name: "royal gramma", photos: ["reef-gramma-2"], length: 44, cruise: 12...18, beat: 0.45, haunt: .rock)
    static let firefish = Species(name: "firefish", photos: (1...3).map { "reef-firefish-\($0)" }, length: 50, cruise: 10...16, beat: 0.35,
                                  burst: (2.4, 0.25), haunt: .rock) // hovers, then darts
    static let flameAngel = Species(name: "flame angelfish", photos: (1...3).map { "reef-flameangel-\($0)" }, length: 58, cruise: 18...26, beat: 0.45,
                                    haunt: .rock)

    // Ocean Voyager (Resources/ocean-*, credited in ocean-credits.tsv). Lengths are as drawn: the window is 19 m
    // wide and the screen shows about 11 m of it, so a 7 m whale shark near the glass spans most of the screen.
    static let whaleShark = Species(name: "whale shark", photos: (1...4).map { "ocean-whaleshark-\($0)" }, length: 760, cruise: 36...48, beat: 6,
                                    burst: (20, 0.5), spacing: 2.5, margin: 0.7, height: 0.45...0.95) // strokes, then glides
    static let manta = Species(name: "manta ray", photos: (1...4).map { "ocean-manta-\($0)" }, length: 420, cruise: 30...42, beat: 3.2,
                               burst: (14, 0.6), spacing: 2.5, gait: .wings, margin: 1, height: 0.25...0.95) // a few strokes, then a glide
    static let cownose = Species(name: "cownose ray", photos: (1...3).map { "ocean-cownose-\($0)" }, length: 120, cruise: 30...40, beat: 1.2,
                                 spacing: 1.1, gait: .wings, margin: 0.5, height: 0.1...0.5)
    static let trevally = Species(name: "golden trevally", photos: (1...4).map { "ocean-trevally-\($0)" }, length: 40, cruise: 25...35, beat: 0.4,
                                  burst: (1.5, 0.4), spacing: 2, height: 0.2...1)
    static let sandbar = Species(name: "sandbar shark", photos: ["ocean-sandbar-1"], length: 300, cruise: 30...40, beat: 1.6,
                                 spacing: 3, margin: 0.6, height: 0.15...0.6)
    static let zebraShark = Species(name: "zebra shark", photos: (1...2).map { "ocean-zebra-\($0)" }, length: 320, cruise: 14...20, beat: 2, burst: (40, 0.2),
                                    haunt: .sand, rests: true)
    static let guitarfish = Species(name: "bowmouth guitarfish", photos: ["ocean-guitarfish-1"], length: 300, cruise: 12...18, beat: 1.4, burst: (50, 0.15),
                                    haunt: .sand, rests: true)

    // The shallow reef (Resources/lagoon-*, credited in lagoon-credits.tsv).
    static let blacktip = Species(name: "blacktip reef shark", photos: (1...3).map { "lagoon-blacktip-\($0)" }, length: 300, cruise: 28...36, beat: 1.1,
                                  spacing: 2.5, margin: 0.8, height: 0.05...0.7)
    static let nurseShark = Species(name: "nurse shark", photos: (1...2).map { "lagoon-nurse-\($0)" }, length: 380, cruise: 8...12, beat: 2, burst: (60, 0.1),
                                    haunt: .sand, rests: true)
    static let epaulette = Species(name: "epaulette shark", photos: (1...2).map { "lagoon-epaulette-\($0)" }, length: 160, cruise: 10...16, beat: 1,
                                   burst: (25, 0.3), haunt: .sand, rests: true)
    static let blueSpotRay = Species(name: "blue-spotted ray", photos: (1...2).map { "lagoon-ray-\($0)" }, length: 140, cruise: 10...15, beat: 0.6,
                                     burst: (35, 0.2), haunt: .sand, rests: true) // a wave runs back along its fin edge
    static let baitfish = Species(name: "baitfish", photos: (1...3).map { "lagoon-baitfish-\($0)" }, length: 36, cruise: 35...45, beat: 0.3,
                                  burst: (1.3, 0.45), spacing: 1.2, height: 0.4...1)
    static let sergeantMajor = Species(name: "sergeant major", photos: (1...2).map { "lagoon-sergeant-\($0)" }, length: 60, cruise: 20...28, beat: 0.45,
                                       haunt: .rock)
    static let parrotfish = Species(name: "parrotfish", photos: (1...2).map { "lagoon-parrotfish-\($0)" }, length: 150, cruise: 16...22, beat: 0.6)
    static let butterflyfish = Species(name: "butterflyfish", photos: (1...2).map { "lagoon-butterflyfish-\($0)" }, length: 60, cruise: 18...24, beat: 0.4,
                                       haunt: .rock)
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

    /// The top edge of a cut-out: for each of `samples` columns from left to right, the height of its highest solid
    /// pixel as a fraction of the image's height (0 where the column is empty). For setting things on a rock.
    static func skyline(_ name: String, samples: Int = 48) -> [CGFloat] {
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
        // Outside the image is transparent, not its edge pixels repeated: a cut-out cropped to its alpha bounds
        // touches its edges, and clamping smeared those into a faint box beside it.
        let source = CIImage(cgImage: image)
        let soft = source.applyingGaussianBlur(sigma: sigma).cropped(to: source.extent)
        return imaging.createCGImage(soft, from: source.extent)
    }

    /// One beat as warp frames. A tail: a wave travelling from head to tail, swinging the tail most. Wings: both
    /// tips sweep up and down together, the body between them still, as a ray flaps.
    static func swimWarps(_ kind: Species, textureHeight: CGFloat) -> [SKWarpGeometryGrid] {
        let columns = 8, frames = 20
        let source = (0...1).flatMap { row in (0...columns).map { SIMD2<Float>(Float($0) / Float(columns), Float(row)) } }
        return (0..<frames).map { frame in
            let phase = Double(frame) / Double(frames) * 2 * .pi
            let destination = source.map { p -> SIMD2<Float> in
                let u = Double(p.x) // 0 at the tail, 1 at the nose
                let swing: Double = switch kind.gait {
                case .tail: (0.075 * pow(1 - u, 2) + 0.006) * sin(phase + 4.2 * u)
                case .wings: 0.09 * pow(abs(u - 0.5) * 2, 2) * sin(phase)
                }
                return SIMD2(p.x, p.y + Float(swing * Double(kind.length) / Double(textureHeight)))
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
