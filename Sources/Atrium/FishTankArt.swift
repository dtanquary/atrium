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
    /// How it swims: a wave from head to tail (small fish, and the whole-body wave of a nurse or zebra shark); a
    /// sweep, the tail swinging in and out of the plane of view so it foreshortens, with only a hint of up and
    /// down (sharks seen from the side); or wings whose tips sweep up and down together (rays).
    enum Gait { case tail, sweep, wings }
    var gait = Gait.tail
    /// Lies still on the sand between short moves, using `burst` as the move-and-rest cycle (bottom sharks, rays).
    var rests = false
    /// How far past the screen edge it swims before turning, in body lengths: big animals leave the screen first,
    /// so they never turn round in view.
    var margin = 0.0
    /// The part of the water column it keeps to, 0 at the sand and 1 at the top: whale sharks cruise high, bottom
    /// sharks stay low.
    var height: ClosedRange<Double> = 0...1
    /// How quickly it changes heading, pitch and the way it faces, 1 for a small fish: the giants have inertia.
    var agility = 1.0
    /// How much its burst-and-coast changes its speed, 1 for a small fish: a whale shark keeps its pace while
    /// its tail rests.
    var thrust = 1.0
    /// The pitch it holds at cruise, radians, nose up when positive: slow sharks swim a few degrees nose-up
    /// (Wilga & Lauder 2004: +4° to +11° at half a body length a second).
    var trim = 0.0
    /// How far it travels per beat, in body lengths, when set: the beat then follows the distance swum rather than
    /// the clock, so a slow giant doesn't thrash its tail while barely advancing (Webb & Keyes 1982: sharks
    /// stride 0.5–0.74 L a beat). 0 beats by `beat`, as the small fish do.
    var stride = 0.0

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
    static let whaleShark = Species(name: "whale shark", photos: (1...3).map { "ocean-whaleshark-\($0)" }, length: 760, cruise: 50...60, beat: 4.5,
                                    burst: (20, 0.65), spacing: 2.5, gait: .sweep, margin: 0.8, height: 0.35...0.8, agility: 0.12, thrust: 0.1, trim: 0.08,
                                    stride: 0.4)
    static let manta = Species(name: "manta ray", photos: (1...3).map { "ocean-manta-\($0)" }, length: 420, cruise: 40...50, beat: 3.4,
                               burst: (7, 0.5), spacing: 2.5, gait: .wings, margin: 1, height: 0.15...0.6, agility: 0.25, thrust: 0.15,
                               stride: 0.55) // one flap, then a glide
    static let cownose = Species(name: "cownose ray", photos: (1...3).map { "ocean-cownose-\($0)" }, length: 120, cruise: 30...40, beat: 1.2,
                                 spacing: 1.8, gait: .wings, margin: 0.5, height: 0.1...0.5, agility: 0.5, stride: 0.5)
    static let trevally = Species(name: "golden trevally", photos: (1...4).map { "ocean-trevally-\($0)" }, length: 40, cruise: 25...35, beat: 0.4,
                                  burst: (1.5, 0.4), spacing: 2, height: 0.2...1)
    static let sandbar = Species(name: "sandbar shark", photos: ["ocean-sandbar-1"], length: 300, cruise: 30...40, beat: 1.6,
                                 spacing: 3, gait: .sweep, margin: 0.6, height: 0.15...0.6, agility: 0.4, trim: 0.08, stride: 0.45)
    static let zebraShark = Species(name: "zebra shark", photos: (1...2).map { "ocean-zebra-\($0)" }, length: 320, cruise: 14...20, beat: 2, burst: (40, 0.2),
                                    haunt: .sand, rests: true)
    static let guitarfish = Species(name: "bowmouth guitarfish", photos: ["ocean-guitarfish-1"], length: 300, cruise: 12...18, beat: 1.4, burst: (50, 0.15),
                                    haunt: .sand, gait: .sweep, rests: true, agility: 0.4, stride: 0.45)

    // The shallow reef (Resources/lagoon-*, credited in lagoon-credits.tsv).
    static let blacktip = Species(name: "blacktip reef shark", photos: (1...3).map { "lagoon-blacktip-\($0)" }, length: 300, cruise: 28...36, beat: 1.1,
                                  spacing: 2.5, gait: .sweep, margin: 0.8, height: 0.05...0.7, agility: 0.4, trim: 0.06, stride: 0.45)
    static let nurseShark = Species(name: "nurse shark", photos: (1...2).map { "lagoon-nurse-\($0)" }, length: 380, cruise: 8...12, beat: 2, burst: (60, 0.1),
                                    haunt: .sand, rests: true, agility: 0.3)
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
    static func swimWarps(_ kind: Species, textureWidth: CGFloat, textureHeight: CGFloat) -> [SKWarpGeometryGrid] {
        let columns = kind.gait == .tail ? 8 : 12, frames = 24
        let source = (0...1).flatMap { row in (0...columns).map { SIMD2<Float>(Float($0) / Float(columns), Float(row)) } }
        let L = Double(kind.length), W = Double(textureWidth), H = Double(textureHeight)
        func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double { let t = min(max((x - a) / (b - a), 0), 1); return t * t * (3 - 2 * t) }
        return (0..<frames).map { frame in
            let phase = Double(frame) / Double(frames) * 2 * .pi
            let destination = source.map { p -> SIMD2<Float> in
                let u = Double(p.x), v = Double(p.y), s = 1 - u // u is 0 at the tail and 1 at the nose; s the other way
                var dx = 0.0, dy = 0.0 // points
                switch kind.gait {
                case .tail:
                    dy = L * (0.075 * s * s + 0.006) * sin(phase + 4.2 * u)
                case .sweep:
                    // A shark from the side (the motion research's recipe): a wave travelling tailward with under
                    // one wavelength on the body, bending from mid-body and steepest over the rear third, a small
                    // counter-yaw at the nose, the blade foreshortening twice a beat as it swings out of the plane
                    // of view, and the caudal blade swinging as one piece about the peduncle.
                    let env = pow(smoothstep(0.4, 1, s), 2), theta = phase - 5 * s
                    dy = L * (0.03 * env + 0.008 * pow(max(0, 1 - s / 0.25), 2)) * sin(theta)
                    dx = L * 0.06 * env * pow(sin(theta), 2)
                    if s > 0.78 {
                        let a = 0.105 * sin(phase - 3.9), rx = (u - 0.22) * W, ry = (v - 0.5) * H
                        dx += rx * cos(a) - ry * sin(a) - rx
                        dy += rx * sin(a) + ry * cos(a) - ry
                    }
                case .wings:
                    // A ray: the stroke runs from the wing base to the tip, the tip lagging and curling (Fish et al.
                    // 2016), quick up and slow down, the body between the wings still, the wings held a little
                    // above level on average.
                    let w = abs(u - 0.5) * 2, theta = phase - 1.3 * w, theta2 = theta + 0.3 * sin(theta)
                    dy = L * (0.2 * w * w * sin(theta2) + 0.06 * w * w)
                }
                return SIMD2(p.x + Float(dx / W), p.y + Float(dy / H))
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
