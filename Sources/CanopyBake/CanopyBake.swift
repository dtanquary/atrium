import CoreGraphics
import Foundation
import ImageIO
import Synchronization
import simd

// Canopy's bake (docs/canopy.md): numeric code many times slower unoptimised, so it's a target of its own built
// with -O, as MeanderRiver and AntNest are. The wallpaper's scene is Sources/Atrium/Canopy.swift.

/// Where the leaves are in their year: the share out and their size (spring), how pale they still are, and the shares
/// turned and down (autumn), each 0 to 1.
public struct CanopySeason: Sendable {
    public var out = 1.0, size = 1.0, pale = 0.0, turned = 0.0, fallen = 0.0
    public init() {}
}

/// The canopy, made off the main thread (docs/canopy.md has how long it takes): the stand decoded, mirrored by the
/// seed (and turned a quarter for a portrait screen); sprays of scanned leaves grown on its fine twigs in three layers;
/// each leaf lit by the Sun through the layers and the crown above it and by the sky; the wood relit as bark in the
/// canopy's shade; all composited into one picture for the shader to lay over the sky.
public struct CanopyBake: Sendable {
    /// The stand's picture (HEIC with alpha, grey wood over its cover) and the scanned leaves' atlas (4 × 4 cells).
    public var stand: URL, leaves: URL
    /// The stand's pixels to a unit of tan, and its half-size in tan, across and up, as the screen sees it.
    public var perTan: Double, extent: SIMD2<Double>, portrait: Bool
    /// The Sun's direction (east, north, up), sunlight at the ground and the zenith's light, times the exposure.
    public var sun: SIMD3<Double>, sunlight: SIMD3<Double>, zenith: SIMD3<Double>
    public var season: CanopySeason, seed: UInt64

    public init(stand: URL, leaves: URL, perTan: Double, extent: SIMD2<Double>, portrait: Bool, sun: SIMD3<Double>, sunlight: SIMD3<Double>,
                zenith: SIMD3<Double>, season: CanopySeason, seed: UInt64) {
        (self.stand, self.leaves, self.perTan, self.extent, self.portrait) = (stand, leaves, perTan, extent, portrait)
        (self.sun, self.sunlight, self.zenith, self.season, self.seed) = (sun, sunlight, zenith, season, seed)
    }

    /// The canopy lit and composited, premultiplied, as sqrt(linear / 2), rows bottom first; how much canopy is near
    /// each point, an eighth the size; how much of the Sun shows through where it stands; how each point moves
    /// (`sway`, `freedom`, the size of the cover map); and the nearest layer of leaves alone, as the canopy is stored,
    /// which the canopy then leaves out; and whose leaf each pixel is (`ids`: the leaf's id in red and its spray's in
    /// blue for the canopy, in green and alpha for the nearest leaves, 0 for none; `idsKey` a hash of it, the same
    /// for the same map), with the share of the stand in leaf (`leafy`).
    public struct Made: Sendable {
        public let canopy: Data, width: Int, height: Int, cover: Data, coverWidth: Int, coverHeight: Int, sunShows: Double, sway: Data
        public let near: Data, ids: Data, idsKey: UInt64, leafy: Double
    }

    /// ponytail: the canopy is at the stand's own 1512 px to a unit of tan, a 14" MacBook Pro's 2x, and is drawn
    /// softer on wider screens (a Studio Display's 1.7 times); and the bake holds about 175 MB while it runs (the
    /// stand, three layers and the canopy at full size). Grow the nearest layer at the screen's size if the softness
    /// shows, and drop each layer once lit if the peak matters.
    public func make() -> Made {
        let (sw, sh) = (Int(perTan * 2 * extent.x), Int(perTan * 2 * extent.y))
        var rng = SplitMix(state: seed)
        var wood = Self.decode(stand, sw, sh, portrait: portrait, flip: (Bool.random(using: &rng), Bool.random(using: &rng)))
        Self.clean(&wood, sw, sh)
        let (layers, owners) = Self.grow(on: wood, sw, sh, leaves: leaves, size: season.size, rng: &rng)
        let noise = Noise(rng: &rng, cell: 110), flecks = Noise(rng: &rng, cell: 60)

        // Each layer's cover where its leaves are on the tree this season. A leaf's key (its own value and the
        // patch it grows in) orders when it comes out, turns and falls.
        let n = sw * sh
        let cover: [[UInt8]] = layers.map { layer in
            var c = [UInt8](repeating: 0, count: n)
            c.withUnsafeMutableBufferPointer { C in
                nonisolated(unsafe) let C = C
                DispatchQueue.concurrentPerform(iterations: sh) { j in
                    for i in 0..<sw {
                        let p = j * sw + i, a = layer[p * 4 + 3]
                        guard a > 0 else { continue }
                        let key = 0.6 * Double(layer[p * 4]) / Double(a) + 0.4 * noise.at(i, j)
                        if key >= season.fallen && key <= season.out { C[p] = a }
                    }
                }
            }
            return c
        }
        // How thick the canopy is round each point, an eighth the size: for the light from above and the veil.
        let (ew, eh) = (sw / 8, sh / 8)
        var bulk = [Float](repeating: 0, count: ew * eh)
        for j in 0..<eh { for i in 0..<ew {
            var s: Float = 0
            for dj in stride(from: 0, to: 8, by: 2) { for di in stride(from: 0, to: 8, by: 2) {
                let p = (j * 8 + dj) * sw + i * 8 + di
                let leaves = (1 - Float(cover[0][p]) / 255) * (1 - Float(cover[1][p]) / 255) * (1 - Float(cover[2][p]) / 255)
                s += 1 - leaves * (1 - 0.6 * Float(wood[p * 4 + 3]) / 255)
            } }
            bulk[j * ew + i] = s / 16
        } }
        boxBlur(&bulk, ew, eh, 2)
        let crown = Grid(values: bulk, width: ew, height: eh, scale: 8)

        // The Sun's offset on the stand from one layer to the next, the layers being about 3 m apart some 18 m up.
        let sunUp = sun.z > 0
        let toward = SIMD2<Double>(-sun.x, -sun.y) / max(sun.z, 0.05) * perTan / 6
        let low = Float(min(length(toward) / (perTan / 6), 3)) // the lower the Sun, the more crown it crosses
        let sunE = SIMD3<Float>(sunlight) / .pi * (sunUp ? 1 : 0), sky = SIMD3<Float>(zenith) * 0.8
        let bark = Self.lin(0x2A2219) / Self.lum(Self.lin(0x2A2219)), zenithLum = Self.lum(SIMD3<Float>(zenith))
        let trans: Float = 0.085 // a leaf passes about 5-15% of the light on its top side (research-method.md §2)
        let hues = Hues(season)
        // ponytail: the nearest leaves are one picture (30 MB more on the GPU), not split in two by spray as
        // research-motion.md offered (30 more again); split them if neighbouring sprays should slide apart more
        var out = [UInt8](repeating: 0, count: n * 4), nearOut = [UInt8](repeating: 0, count: n * 4)
        out.withUnsafeMutableBufferPointer { O in nearOut.withUnsafeMutableBufferPointer { N in
            nonisolated(unsafe) let O = O, N = N
            DispatchQueue.concurrentPerform(iterations: sh) { j in
                for i in 0..<sw {
                    let p = j * sw + i
                    let c = SIMD3<Float>(Float(cover[0][p]), Float(cover[1][p]), Float(cover[2][p])) / 255
                    let w = Float(wood[p * 4 + 3]) / 255
                    if c.sum() + w == 0 { continue }
                    let (x, y) = (Double(i), Double(j))
                    let skyThrough = exp(-1.8 * crown.at(x, y))
                    var rgb = SIMD3<Float>.zero, alpha: Float = 0
                    func over(_ l: SIMD3<Float>, _ a: Float) { rgb = rgb * (1 - a) + l * a; alpha = alpha * (1 - a) + a }
                    func leaf(_ k: Int) {
                        guard c[k] > 0 else { return }
                        let a = Float(layers[k][p * 4 + 3])
                        let value = Float(layers[k][p * 4]) / a, tilt = Float(layers[k][p * 4 + 1]) / a, overlap = Float(layers[k][p * 4 + 2]) / a
                        // the Sun through the leaves of the layers above, then through the crown over them all
                        var through: Float = 1
                        for above in (k + 1)..<3 {
                            let s = Double(above - k), (ax, ay) = (Int(x + toward.x * s), Int(y + toward.y * s))
                            if ax >= 0, ay >= 0, ax < sw, ay < sh { through *= 1 - 0.9 * Float(cover[above][ay * sw + ax]) / 255 }
                        }
                        let s = Double(3 - k)
                        through *= exp(-(2.2 + 0.4 * low) * crown.at(x + toward.x * s, y + toward.y * s) * Float(3 - k) / 3)
                        through *= Float(0.3 + 1.4 * simd_smoothstep(0.3, 0.75, flecks.at(i, j))) // gaps in the crowns above
                        let deep = Float(2 - k) / 2 // the lowest layer is deepest in the crowns' shade
                        let tint = hues.leaf(value, Float(noise.at(i, j)))
                        // straight through in the Sun's beam, the brightest square to it; in the crown's shade,
                        // light that has come through other leaves already, greener and dimmer; and the sky's
                        let sunlit = (0.15 + 0.85 * tilt * tilt) * through, inner = 0.12 * (1 - through) * (1 - 0.5 * deep)
                        let own = (0.65 + 0.7 * (value * 5.37).truncatingRemainder(dividingBy: 1)) * (1 - 0.5 * overlap)
                        var l = tint * sunE * sunlit + hues.shade * sunE * inner + tint * sky * skyThrough * (1 - 0.5 * deep)
                        l *= trans * own
                        over(l, c[k])
                    }
                    leaf(2)
                    leaf(1)
                    if w > 0 { // the wood, relit as bark in the canopy's shade
                        let g = min(pow(Float(wood[p * 4]) / 255 / w, 2.2), 0.5)
                        over(bark * g * zenithLum * 1.6 * (0.3 + 0.7 * skyThrough), w)
                    }
                    let q = ((sh - 1 - j) * sw + i) * 4 // rows bottom first, as SKTexture(data:) reads them
                    func put(_ to: UnsafeMutableBufferPointer<UInt8>) {
                        for ch in 0..<3 { to[q + ch] = UInt8(min(sqrt(max(rgb[ch], 0) / 2), 1) * 255 + 0.5) }
                        to[q + 3] = UInt8(min(alpha, 1) * 255 + 0.5)
                    }
                    put(O)
                    (rgb, alpha) = (.zero, 0) // the nearest leaves alone, lit as they would be over the rest
                    leaf(0)
                    put(N)
                }
            }
        } }

        var near = [UInt8](repeating: 255, count: ew * eh * 4)
        for j in 0..<eh { for i in 0..<ew {
            let q = ((eh - 1 - j) * ew + i) * 4, v = UInt8(min(bulk[j * ew + i], 1) * 255)
            (near[q], near[q + 1], near[q + 2]) = (v, v, v)
        } }
        // how much of the Sun shows, from the canopy's thickness where it stands
        let sx = (-sun.x / max(sun.z, 1e-3) / extent.x * 0.5 + 0.5) * Double(sw)
        let sy = (0.5 - sun.y / max(sun.z, 1e-3) / extent.y * 0.5) * Double(sh)
        let shows = sunUp && sx > 0 && sy > 0 && sx < Double(sw) && sy < Double(sh) ? Double(1 - min(crown.at(sx, sy) * 1.4, 1)) : 0
        let ids = Self.ids(owners, cover: cover, wood: wood, canopy: out, near: nearOut, sw, sh)
        return Made(canopy: Data(out), width: sw, height: sh, cover: Data(near), coverWidth: ew, coverHeight: eh, sunShows: shows,
                    sway: Self.freedom(wood, sw, sh, trees: Self.trees(wood, sw, sh)), near: Data(nearOut),
                    ids: ids.map, idsKey: ids.key, leafy: ids.leafy)
    }

    /// Whose leaf each pixel is, rows bottom first, so the shader can move a leaf as one piece: for the canopy, the id
    /// of the leaf in front (the middle layer's where it is on the tree this season, else the far one's; none where
    /// wood covers a quarter or more, which is drawn over them) in red and its spray's in blue; for the nearest leaves
    /// the same in green and alpha; 1 to 255, 0 for none. Open sky within 2 px of a leaf (its picture under a fifth
    /// covered) takes that leaf's, so a leaf can move out over the sky. And a hash of the map, and the share of the
    /// stand in leaf.
    static func ids(_ owners: [[UInt8]], cover: [[UInt8]], wood: [UInt8], canopy: [UInt8], near: [UInt8], _ sw: Int, _ sh: Int) -> (map: Data, key: UInt64, leafy: Double) {
        var own = [UInt8](repeating: 0, count: sw * sh * 4)
        own.withUnsafeMutableBufferPointer { O in
            nonisolated(unsafe) let O = O
            DispatchQueue.concurrentPerform(iterations: sh) { j in
                for i in 0..<sw {
                    let p = j * sw + i, o = ((sh - 1 - j) * sw + i) * 4
                    if wood[p * 4 + 3] <= 64 { // a twig a quarter covering it or more stays with the wood
                        let k = cover[1][p] > 127 && owners[1][p * 2] > 0 ? 1 : 2
                        if cover[k][p] > 127 { (O[o], O[o + 2]) = (owners[k][p * 2], owners[k][p * 2 + 1]) }
                    }
                    if cover[0][p] > 127 { (O[o + 1], O[o + 3]) = (owners[0][p * 2], owners[0][p * 2 + 1]) }
                }
            }
        }
        var leafy = 0
        for p in 0..<sw * sh where own[p * 4] > 0 || own[p * 4 + 1] > 0 { leafy += 1 }
        for _ in 0..<2 { // out over the sky, a pixel at a time
            let from = own
            own.withUnsafeMutableBufferPointer { O in
                nonisolated(unsafe) let O = O
                DispatchQueue.concurrentPerform(iterations: sh) { j in
                    for i in 0..<sw {
                        let o = (j * sw + i) * 4
                        for c in 0..<2 where from[o + c] == 0 && (c == 0 ? canopy[o + 3] : near[o + 3]) < 51 {
                            var at = o
                            if i + 1 < sw, from[o + 4 + c] > 0 { at = o + 4 }
                            else if i > 0, from[o - 4 + c] > 0 { at = o - 4 }
                            else if j + 1 < sh, from[o + sw * 4 + c] > 0 { at = o + sw * 4 }
                            else if j > 0, from[o - sw * 4 + c] > 0 { at = o - sw * 4 }
                            (O[o + c], O[o + c + 2]) = (from[at + c], from[at + c + 2])
                        }
                    }
                }
            }
        }
        var key: UInt64 = 0xCBF2_9CE4_8422_2325 // FNV-1a, a word at a time
        own.withUnsafeBytes { for word in $0.bindMemory(to: UInt64.self) { key = (key ^ word) &* 0x100_0000_01B3 } }
        return (Data(own), key, Double(leafy) / Double(sw * sh))
    }

    /// How free each point of the stand is to move, an eighth the size, rows bottom first, as `trees` is: in red, 0 on
    /// solid wood (trunks, limbs from about 8 px across, the evergreens' masses: 4 px blocks over 85% covered, blurred
    /// as `grow` blurs them, so a dense knot of twigs on its own doesn't count) rising to 1 at 40 px from it, so thin
    /// twigs are held where they leave their limb and swing further out; in green the same from trunks alone (solid
    /// wood 40 px across or more, 80 px to free), for a wind that moves the limbs; in blue how far along its tree a
    /// point is (the sum of `trees`' four shares), for the crowns swaying as bodies in a strong wind.
    static func freedom(_ wood: [UInt8], _ sw: Int, _ sh: Int, trees: Data) -> Data {
        let (w, h) = (sw / 4, sh / 4)
        var thick = [Float](repeating: 0, count: w * h)
        for j in 0..<h { for i in 0..<w {
            var s = 0
            for dj in 0..<4 { for di in 0..<4 { s += Int(wood[((j * 4 + dj) * sw + i * 4 + di) * 4 + 3]) } }
            thick[j * w + i] = s > 16 * 255 * 85 / 100 ? 1 : 0
        } }
        boxBlur(&thick, w, h, 3) // a line of solid blocks 3 wide comes to 0.39, 2 wide 0.27, 1 wide 0.14, one alone 0.02
        let solid = thick.map { $0 > 0.22 } // from 8 px across: a limb that bent along its length read as rubber
        // trunks: solid wood whose middle is 5 blocks (20 px) or more from its edge, grown back out to its edge
        let core = distance(to: solid.map { !$0 }, w, h).map { $0 >= 5 }, trunks = distance(to: core, w, h).map { $0 <= 5 }
        let (twigs, limbs) = (distance(to: solid, w, h), distance(to: trunks, w, h))
        let (ew, eh) = (sw / 8, sh / 8)
        var out = [UInt8](repeating: 0, count: ew * eh * 4)
        for j in 0..<eh { for i in 0..<ew {
            var (a, b): (Float, Float) = (0, 0)
            for dj in 0..<2 { for di in 0..<2 {
                let k = min(j * 2 + dj, h - 1) * w + min(i * 2 + di, w - 1)
                a += simd_smoothstep(0, 10, twigs[k]) / 4 // 40 px: at 80 the bare stand's twigs, nearly all within it of a limb, barely moved
                b += simd_smoothstep(0, 20, limbs[k]) / 4
            } }
            let q = ((eh - 1 - j) * ew + i) * 4
            let along = (0..<4).reduce(0) { $0 + Int(trees[q + $1]) }
            (out[q], out[q + 1], out[q + 2], out[q + 3]) = (UInt8(a * 255 + 0.5), UInt8(b * 255 + 0.5), UInt8(min(along, 255)), 255)
        } }
        return Data(out)
    }

    /// How far each cell is from the nearest cell that is `true`, in cells (a chamfer of 1 and 1.4, two passes); far off where none is.
    static func distance(to set: [Bool], _ w: Int, _ h: Int) -> [Float] {
        var d = set.map { $0 ? Float(0) : 1e6 }
        for j in 0..<h { for i in 0..<w {
            let k = j * w + i
            if i > 0 { d[k] = min(d[k], d[k - 1] + 1) }
            if j > 0 { d[k] = min(d[k], d[k - w] + 1); if i > 0 { d[k] = min(d[k], d[k - w - 1] + 1.4) }; if i < w - 1 { d[k] = min(d[k], d[k - w + 1] + 1.4) } }
        } }
        for j in stride(from: h - 1, through: 0, by: -1) { for i in stride(from: w - 1, through: 0, by: -1) {
            let k = j * w + i
            if i < w - 1 { d[k] = min(d[k], d[k + 1] + 1) }
            if j < h - 1 { d[k] = min(d[k], d[k + w] + 1); if i < w - 1 { d[k] = min(d[k], d[k + w + 1] + 1.4) }; if i > 0 { d[k] = min(d[k], d[k + w - 1] + 1.4) } }
        } }
        return d
    }

    /// How far along its tree each point of the stand is, for the crowns' sway in a strong wind (`freedom` sums the
    /// four channels), an eighth the size, rows bottom first: in each of R, G, B and A, the share of one of four groups
    /// of trees. Each trunk or limb where it enters at the picture's edge (a run of solid wood along the border) is a
    /// tree; its label is flooded along the wood, so every twig goes with the trunk it is joined to by the shortest
    /// path, then out into the sky and leaves round it from the nearest wood; trees round the edge in turn go to groups
    /// 0, 1, 2, 3, 0, .... A point's share grows with how far along its tree it is from the edge, none at the trunk's
    /// foot and all of it from 700 px on.
    // ponytail: still step (b)'s map of four groups, each blurred and rounded apart and summed by `freedom`, so the
    // ramp stays as it was to the byte; one channel would do once the crowns' sway is retuned
    static func trees(_ wood: [UInt8], _ sw: Int, _ sh: Int) -> Data {
        let (w, h) = (sw / 4, sh / 4) // a quarter the size: the most of each 4 px block, and its mean
        var most = [Float](repeating: 0, count: w * h), mean = most
        for j in 0..<h { for i in 0..<w {
            var (m, s) = (0, 0)
            for dj in 0..<4 { for di in 0..<4 { let a = Int(wood[((j * 4 + dj) * sw + i * 4 + di) * 4 + 3]); m = max(m, a); s += a } }
            (most[j * w + i], mean[j * w + i]) = (Float(m) / 255, Float(s) / 16 / 255)
        } }
        var label = [Int32](repeating: -1, count: w * h), along = [Float](repeating: 0, count: w * h), queue: [Int] = []
        // the border, clockwise from the top left
        let border = Array(0..<w) + (1..<h).map { $0 * w + w - 1 } + stride(from: w - 2, through: 0, by: -1).map { (h - 1) * w + $0 }
            + stride(from: h - 2, through: 1, by: -1).map { $0 * w }
        var run: Int32 = -1, inside = false
        for k in border {
            if mean[k] > 0.6 {
                if !inside { run += 1 }
                inside = true
                label[k] = run
                queue.append(k)
            } else { inside = false }
        }
        if run > 0, label[border[0]] >= 0, label[border[border.count - 1]] >= 0 { // a run across the start is one tree
            for k in border where label[k] == run { label[k] = 0 }
        }
        var head = 0
        func flood(wood: Bool) { // breadth first, 8-connected: along the wood, counting its steps, or out from it
            while head < queue.count {
                let k = queue[head], (i, j) = (k % w, k / w)
                head += 1
                for y in max(j - 1, 0)...min(j + 1, h - 1) { for x in max(i - 1, 0)...min(i + 1, w - 1) {
                    let p = y * w + x
                    guard label[p] < 0, !wood || most[p] > 0.1 else { continue }
                    (label[p], along[p]) = (label[k], along[k] + (wood ? (x != i && y != j ? 1.41 : 1) : 0))
                    queue.append(p)
                } }
            }
        }
        if queue.isEmpty { return Data(count: (sw / 8) * (sh / 8) * 4) } // no trees: nothing sways
        flood(wood: true)
        queue = (0..<(w * h)).filter { label[$0] >= 0 }
        head = 0
        flood(wood: false)
        // an eighth the size: each group's share, blurred so neighbouring trees part smoothly
        let (ew, eh) = (sw / 8, sh / 8)
        var groups = [[Float]](repeating: [Float](repeating: 0, count: ew * eh), count: 4)
        for j in 0..<eh { for i in 0..<ew {
            for dj in 0..<2 { for di in 0..<2 {
                let k = min(j * 2 + dj, h - 1) * w + min(i * 2 + di, w - 1)
                groups[Int(label[k]) % 4][j * ew + i] += min(along[k] * 4 / 700, 1) / 4
            } }
        } }
        for g in 0..<4 { boxBlur(&groups[g], ew, eh, 3) }
        var out = [UInt8](repeating: 0, count: ew * eh * 4)
        for j in 0..<eh { for i in 0..<ew {
            let q = ((eh - 1 - j) * ew + i) * 4
            for g in 0..<4 { out[q + g] = UInt8(min(groups[g][j * ew + i], 1) * 255 + 0.5) }
        } }
        return Data(out)
    }

    /// The stand's picture, mirrored by `flip` and turned a quarter for a portrait screen, as premultiplied RGBA,
    /// row 0 at the top.
    static func decode(_ url: URL, _ w: Int, _ h: Int, portrait: Bool, flip: (Bool, Bool)) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return bytes }
        bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                          space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            context.translateBy(x: CGFloat(w) / 2, y: CGFloat(h) / 2)
            context.scaleBy(x: flip.0 ? -1 : 1, y: flip.1 ? -1 : 1)
            if portrait { context.rotate(by: .pi / 2) }
            let (iw, ih) = (CGFloat(image.width), CGFloat(image.height))
            context.draw(image, in: CGRect(x: -iw / 2, y: -ih / 2, width: iw, height: ih))
        }
        return bytes
    }

    /// The stand's matte put right. The key left faint specks of its clouds' edges in the open sky, a few pixels and
    /// a few percent of cover each: only a piece of wood joined through pixels at least 2% covered, with some of it
    /// surely wood (a third covered or more) and 150 pixels' worth in all, is kept, so the finest twigs stay with
    /// their limbs and the specks go. And the key
    /// left the evergreens' masses part-covered where sky glinted through their needles, which showed as soft, lighter
    /// patches against the dusk: inside a mass, part cover is made solid, the holes kept.
    // ponytail: done in every bake (110-135 ms off the main thread), not once in the shipped HEIC; clean the HEIC
    // itself in docs/canopy/stand.swift if a second stand comes or the bake's time matters
    static func clean(_ wood: inout [UInt8], _ w: Int, _ h: Int) {
        let n = w * h
        var seen = [Bool](repeating: false, count: n), queue = [Int32]()
        queue.reserveCapacity(n / 2)
        wood.withUnsafeMutableBufferPointer { W in
            for start in 0..<n where !seen[start] && W[start * 4 + 3] >= 5 {
                // one piece of wood, breadth first through pixels 2% covered, 8-connected
                queue.removeAll(keepingCapacity: true)
                queue.append(Int32(start))
                seen[start] = true
                var head = 0, sure = false, cover = 0
                while head < queue.count {
                    let k = Int(queue[head]), (i, j) = (k % w, k / w), a = W[k * 4 + 3]
                    head += 1
                    sure = sure || a >= 85
                    cover += Int(a)
                    for y in max(j - 1, 0)...min(j + 1, h - 1) { for x in max(i - 1, 0)...min(i + 1, w - 1) {
                        let p = y * w + x
                        if !seen[p] && W[p * 4 + 3] >= 5 { seen[p] = true; queue.append(Int32(p)) }
                    } }
                }
                // a speck: nothing in it surely wood, or all of it less than 150 pixels' worth
                if !sure || cover < 150 * 255 { for k in queue { for c in 0..<4 { W[Int(k) * 4 + c] = 0 } } }
            }
            for k in 0..<n where !seen[k] { for c in 0..<4 { W[k * 4 + c] = 0 } } // under 2%
            // the evergreens' masses: where nearly every 4 px block round a point, over about 20 px, is all but
            // covered (a haze of twigs, however dense, has gaps between)
            let (qw, qh) = (w / 4, h / 4)
            var dense = [Float](repeating: 0, count: qw * qh)
            for j in 0..<qh { for i in 0..<qw {
                var s = 0
                for dj in 0..<4 { for di in 0..<4 { s += Int(W[((j * 4 + dj) * w + i * 4 + di) * 4 + 3]) } }
                dense[j * qw + i] = s > 16 * 255 * 8 / 10 ? 1 : 0
            } }
            boxBlur(&dense, qw, qh, 2)
            let mass = Grid(values: dense, width: qw, height: qh, scale: 4)
            for j in 0..<h { for i in 0..<w {
                let k = (j * w + i) * 4, a = Float(W[k + 3]) / 255
                guard a > 0.3, a < 1 else { continue }
                // part-covered needles made solid; the holes between them, where no wood shows, kept
                let to = a + (1 - a) * simd_smoothstep(0.7, 0.95, mass.at(Double(i), Double(j))) * simd_smoothstep(0.3, 0.8, a)
                let v = UInt8(min(Float(W[k]) / 255 / a * to, 1) * 255 + 0.5) // the wood's own shade
                (W[k], W[k + 1], W[k + 2], W[k + 3]) = (v, v, v, UInt8(to * 255 + 0.5))
            } }
        }
    }

    /// Three layers of sprays (farthest last), each RGBA at the stand's size, row 0 at the top: a leaf's own value
    /// in red and how square it is to the light in green, premultiplied by its cover. Sprays grow in clumps where the
    /// stand is a haze of fine twigs; trunks, limbs and the evergreens' solid masses grow none. The nearer the
    /// layer, the bigger its sprays on screen. And for each layer, whose leaf is in front at each pixel, row 0 at the
    /// top: two bytes, the leaf's id and its spray's (1 to 255, hashed from which spray it is and
    /// which leaf of it; 0 for none), drawn spray by spray in the same order from each stamp's map of its leaves.
    static func grow(on wood: [UInt8], _ sw: Int, _ sh: Int, leaves: URL, size: Double, rng: inout SplitMix) -> (layers: [[UInt8]], owners: [[UInt8]]) {
        // where the twigs are, a quarter the size
        let (qw, qh) = (sw / 4, sh / 4)
        var m = [Float](repeating: 0, count: qw * qh)
        for j in 0..<qh { for i in 0..<qw {
            var s = 0
            for dj in 0..<4 { for di in 0..<4 { s += Int(wood[((j * 4 + dj) * sw + i * 4 + di) * 4 + 3]) } }
            m[j * qw + i] = Float(s) / 16 / 255
        } }
        var thick = m.map { $0 > 0.85 ? Float(1) : 0 }
        boxBlur(&thick, qw, qh, 3)
        var twigs = (0..<m.count).map { k in m[k] > 0.03 ? min(m[k] * 2.5, 1) * (1 - simd_smoothstep(0.55, 0.8, thick[k])) : 0 }
        boxBlur(&twigs, qw, qh, 6, passes: 3)
        let top = max(twigs.sorted()[Int(Double(twigs.count - 1) * 0.98)], 1e-6)
        let dens = Grid(values: twigs.map { min($0 / top, 1) }, width: qw, height: qh, scale: 4)

        let stamps = Self.stamps(leaves, rng: &rng), holes = Noise(rng: &rng, cell: 45)
        let seeds = (0..<3).map { _ in rng.next() }
        let layers = Mutex([[UInt8]](repeating: [], count: 3)), owners = Mutex([[UInt8]](repeating: [], count: 3))
        let n = Self.stampSide
        DispatchQueue.concurrentPerform(iterations: 3) { k in
            var r = SplitMix(state: seeds[k])
            var bytes = [UInt8](repeating: 0, count: sw * sh * 4), owner = [UInt8](repeating: 0, count: sw * sh * 2)
            bytes.withUnsafeMutableBytes { buffer in
                guard let context = CGContext(data: buffer.baseAddress, width: sw, height: sh, bitsPerComponent: 8, bytesPerRow: sw * 4,
                                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
                context.interpolationQuality = .medium
                let spray = [62.0, 50.0, 40.0][k] * size, sprays = 10_000
                var placed = 0, tries = 0
                while placed < sprays && tries < sprays * 40 {
                    tries += 1
                    let (cx, cy) = (Double.random(in: 0..<Double(sw), using: &r), Double.random(in: 0..<Double(sh), using: &r))
                    // the twigs' density, less the holes between clumps, so sky shows through the crowns
                    let d = Double(dens.at(cx, cy)) - 0.35 * holes.at(Int(cx), Int(cy))
                    if Double.random(in: 0..<1, using: &r) > min(max((d - 0.02) / 0.4, 0), 1) { continue }
                    for _ in 0..<Int.random(in: 4...9, using: &r) { // a clump round a point on the twigs
                        let a = Double.random(in: 0..<2 * .pi, using: &r), rr = spray * 0.9 * Double.random(in: 0..<1, using: &r).squareRoot()
                        let (x, y) = (cx + cos(a) * rr, cy + sin(a) * rr)
                        guard x > 0, y > 0, x < Double(sw), y < Double(sh), dens.at(x, y) > 0.03 else { continue }
                        placed += 1
                        let s = spray * Double.random(in: 0.8...1.2, using: &r)
                        let turn = Double.random(in: 0..<2 * .pi, using: &r), stamp = stamps[Int.random(in: 0..<stamps.count, using: &r)]
                        context.saveGState()
                        context.translateBy(x: x, y: Double(sh) - y)
                        context.rotate(by: turn)
                        context.draw(stamp.image, in: CGRect(x: -s / 2, y: -s / 2, width: s, height: s))
                        context.restoreGState()
                        // the same spray into the map of whose leaf is in front: each pixel of its box turned back
                        // into the stamp, y up there and rows top first here
                        let (c, sn, reach) = (cos(turn), sin(turn), s * 0.7072), which = UInt32(k * 100_003 + placed)
                        let sprayID = Self.id(which), scale = Double(n) / s
                        let across = max(Int(x - reach), 0)...max(min(Int(x + reach), sw - 1), 0)
                        for j in max(Int(y - reach), 0)...max(min(Int(y + reach), sh - 1), 0) {
                            let (dx, dy) = (Double(across.lowerBound) + 0.5 - x, y - Double(j) - 0.5)
                            var (u, v) = (((c * dx + sn * dy) / s + 0.5) * Double(n), (0.5 - (c * dy - sn * dx) / s) * Double(n))
                            for i in across {
                                if u >= 0, v >= 0, u < Double(n), v < Double(n) {
                                    let leaf = stamp.leaf[Int(v) * n + Int(u)]
                                    if leaf > 0 { (owner[(j * sw + i) * 2], owner[(j * sw + i) * 2 + 1]) = (Self.id(which &* 16 &+ UInt32(leaf)), sprayID) }
                                }
                                (u, v) = (u + c * scale, v + sn * scale)
                            }
                        }
                    }
                }
            }
            layers.withLock { $0[k] = bytes }
            owners.withLock { $0[k] = owner }
        }
        return (layers.withLock { $0 }, owners.withLock { $0 })
    }

    /// Sprays of 9-13 leaves cut from Dappled Light's scanned atlas, on a twig 96 px long: each leaf a random value
    /// in red and a random tilt in green, and in blue where two leaves of the spray overlap (light through both);
    /// and which of its leaves is in front at each pixel (`leaf`, 1 up, rows top first; 0 where none covers half).
    static func stamps(_ url: URL, rng: inout SplitMix) -> [(image: CGImage, leaf: [UInt8])] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let atlas = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return [] }
        let side = atlas.width / 4, n = stampSide
        let cells = (0..<16).compactMap { atlas.cropping(to: CGRect(x: $0 % 4 * side, y: $0 / 4 * side, width: side, height: side)) }
        guard !cells.isEmpty, let leaf = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n, space: CGColorSpaceCreateDeviceGray(),
                                                    bitmapInfo: CGImageAlphaInfo.none.rawValue), let mask = leaf.data else { return [] }
        return (0..<32).compactMap { _ in
            var px = [Float](repeating: 0, count: n * n * 4) // value, tilt, cover so far, cover summed
            var front = [UInt8](repeating: 0, count: n * n)
            let a0 = Double.random(in: 0..<2 * .pi, using: &rng)
            let base = CGPoint(x: Double(n) / 2 - cos(a0) * 36, y: Double(n) / 2 - sin(a0) * 36)
            for k in 0..<Int.random(in: 9...13, using: &rng) {
                let t = Double(k) / 12, side: Double = k % 2 == 0 ? 1 : -1, len = Double.random(in: 16...24, using: &rng)
                leaf.setFillColor(gray: 0, alpha: 1)
                leaf.fill(CGRect(x: 0, y: 0, width: n, height: n)) // the leaf's white on black is its cover
                leaf.saveGState()
                leaf.translateBy(x: base.x + cos(a0) * 72 * t, y: base.y + sin(a0) * 72 * t)
                leaf.rotate(by: a0 + side * Double.random(in: 0.5...1.1, using: &rng) - .pi / 2)
                leaf.draw(cells[Int.random(in: 0..<cells.count, using: &rng)], in: CGRect(x: -len / 2, y: -len * 0.03, width: len, height: len))
                leaf.restoreGState()
                let (value, tilt) = (Float.random(in: 0.02...1, using: &rng), Float.random(in: 0...1, using: &rng))
                let a = mask.assumingMemoryBound(to: UInt8.self)
                for i in 0..<n * n where a[i] > 0 {
                    let m = Float(a[i]) / 255, o = i * 4
                    px[o] = value * m + px[o] * (1 - m)
                    px[o + 1] = tilt * m + px[o + 1] * (1 - m)
                    px[o + 2] = m + px[o + 2] * (1 - m)
                    px[o + 3] += m
                    if a[i] > 127 { front[i] = UInt8(k + 1) }
                }
            }
            // premultiplied: value and tilt by the cover, overlap (a second leaf's share) likewise
            let bytes = (0..<n * n).flatMap { i -> [UInt8] in
                let c = min(px[i * 4 + 2], 1), overlap = min(max(px[i * 4 + 3] - 1, 0), 1)
                return [px[i * 4], px[i * 4 + 1], overlap * c, c].map { UInt8(min($0, 1) * 255 + 0.5) }
            }
            guard let provider = CGDataProvider(data: Data(bytes) as CFData),
                  let image = CGImage(width: n, height: n, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: n * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider,
                                      decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { return nil }
            return (image, front)
        }
    }

    /// A stamp's side, px.
    static let stampSide = 96

    /// An id, 1 to 255, hashed from a number.
    static func id(_ v: UInt32) -> UInt8 {
        var x = v &* 0x9E37_79B1
        x ^= x >> 15
        x = x &* 0x85EB_CA77
        x ^= x >> 13
        return UInt8(x % 255 + 1)
    }

    static func lin(_ hex: Int) -> SIMD3<Float> {
        SIMD3(pow(Float(hex >> 16 & 255) / 255, 2.2), pow(Float(hex >> 8 & 255) / 255, 2.2), pow(Float(hex & 255) / 255, 2.2))
    }
    static func lum(_ v: SIMD3<Float>) -> Float { dot(v, SIMD3(0.2126, 0.7152, 0.0722)) }
}

extension CanopyBake {
    /// The colour of the light through a leaf, as hues of luminance 1, sampled from photos (research-look.md §2):
    /// Summer glow's greens, paler in spring, turning through Beech bronze with a little sugar maple.
    struct Hues: Sendable {
        let season: CanopySeason
        let summer = [0x99AE44, 0xB6C06D].map(Self.hue), spring = Self.hue(0xB9C25E), shade = Self.hue(0x3C521A)
        let autumn = [0x736230, 0x88743E, 0x9F894D, 0x9D9F40, 0xD29143].map(Self.hue)
        init(_ season: CanopySeason) { self.season = season }

        static func hue(_ hex: Int) -> SIMD3<Float> { let c = CanopyBake.lin(hex); return c / CanopyBake.lum(c) }

        /// A leaf's colour from its own value and its patch's: those that turn first fall first.
        func leaf(_ value: Float, _ patch: Float) -> SIMD3<Float> {
            let h = (value * 13.71).truncatingRemainder(dividingBy: 1)
            var c = summer[0] + (summer[1] - summer[0]) * h
            c += (spring - c) * Float(season.pale)
            let key = 0.6 * value + 0.4 * patch
            let turned = min(max((Float(season.turned) - key) / 0.12 + 0.5, 0), 1)
            let pick = (value * 7.31).truncatingRemainder(dividingBy: 1)
            let au = autumn[pick < 0.3 ? 0 : pick < 0.55 ? 1 : pick < 0.8 ? 2 : pick < 0.93 ? 3 : 4]
            return c + (au - c) * turned
        }
    }

    /// Smooth noise in 0…1 over the stand, one random value every `cell` pixels: the patches that turn and fall together.
    struct Noise: Sendable {
        let values: [Double], cell: Double, columns = 64
        init(rng: inout SplitMix, cell: Double) {
            values = (0..<64 * 64).map { _ in Double.random(in: 0..<1, using: &rng) }
            self.cell = cell
        }
        func at(_ i: Int, _ j: Int) -> Double {
            let (x, y) = (Double(i) / cell, Double(j) / cell), (x0, y0) = (Int(x), Int(y))
            var (fx, fy) = (x - Double(x0), y - Double(y0))
            (fx, fy) = (fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy))
            func v(_ a: Int, _ b: Int) -> Double { values[(b % columns) * columns + a % columns] }
            return (v(x0, y0) * (1 - fx) + v(x0 + 1, y0) * fx) * (1 - fy) + (v(x0, y0 + 1) * (1 - fx) + v(x0 + 1, y0 + 1) * fx) * fy
        }
    }

    /// A small map of the stand, `scale` stand pixels to its own, read smoothly at stand pixels.
    struct Grid: Sendable {
        let values: [Float], width: Int, height: Int, scale: Double
        func at(_ x: Double, _ y: Double) -> Float {
            let fx = min(max(x / scale - 0.5, 0), Double(width - 1)), fy = min(max(y / scale - 0.5, 0), Double(height - 1))
            let (x0, y0) = (min(Int(fx), width - 2), min(Int(fy), height - 2)), (ax, ay) = (Float(fx) - Float(x0), Float(fy) - Float(y0))
            let a = values[y0 * width + x0] * (1 - ax) + values[y0 * width + x0 + 1] * ax
            let b = values[(y0 + 1) * width + x0] * (1 - ax) + values[(y0 + 1) * width + x0 + 1] * ax
            return a * (1 - ay) + b * ay
        }
    }
}

/// A box blur of a float plane, `passes` times (three is close to a Gaussian), in place.
private func boxBlur(_ a: inout [Float], _ w: Int, _ h: Int, _ r: Int, passes: Int = 2) {
    var tmp = [Float](repeating: 0, count: a.count)
    for _ in 0..<passes {
        a.withUnsafeMutableBufferPointer { A in tmp.withUnsafeMutableBufferPointer { T in
                nonisolated(unsafe) let A = A, T = T
                DispatchQueue.concurrentPerform(iterations: h) { y in
                    var s: Float = 0
                    for x in -r...r { s += A[y * w + min(max(x, 0), w - 1)] }
                    for x in 0..<w {
                        T[y * w + x] = s / Float(2 * r + 1)
                        s += A[y * w + min(x + r + 1, w - 1)] - A[y * w + max(x - r, 0)]
                    }
                }
                DispatchQueue.concurrentPerform(iterations: w) { x in
                    var s: Float = 0
                    for y in -r...r { s += T[min(max(y, 0), h - 1) * w + x] }
                    for y in 0..<h {
                        A[y * w + x] = s / Float(2 * r + 1)
                        s += T[min(y + r + 1, h - 1) * w + x] - T[max(y - r, 0) * w + x]
                    }
                }
            } }
    }
}

/// SplitMix64, as Aurora's: the same grove for the same seed.
struct SplitMix: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
