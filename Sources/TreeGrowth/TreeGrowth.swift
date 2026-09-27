import Foundation
import simd

// A Tree for the Year: grows a tree year by year from a seed and bakes it into depth slabs of data textures that one
// SKShader composites for any day, light and weather. A port of the prototype tree.py (v2); the functions keep its
// names and order, and every random number comes from the same hash, so a seed gives the same tree in both.
// Foundation and simd only, so it can run off the main thread.

typealias V3 = SIMD3<Double>

/// Every tunable of a species (tree.py's SPECIES). Lengths in metres, ages in years, colours sRGB 0-255.
/// The colours are the shader's; the bake only uses the growth, foliage, bark and composition values. Its calendar is
/// a `Phenology`.
public struct TreeSpecies: Sendable {
    // growth per year (USDA Silvics; crown width after Ek 1974)
    public var hRate = 0.4, hRateOld = 0.15, hSlow = SIMD2<Double>(30, 70)
    public var dbhRate = 0.9, crownA = 1.12, crownB = 0.221
    public var clearAges: [Double] = [0, 10, 30, 80], clearH: [Double] = [0.5, 0.5, 2.0, 4.0]
    public var planted = 15.0, transplant = 0.5
    public var widest = 0.4, topYoung = 1.35, topOld = 2.2, envNoise = 0.16
    public var matureAges = SIMD2<Double>(12, 60)
    public var leaderUntil = 35, leaderGap = 0.35, whorl = SIMD2<Int>(3, 5), whorlElev = SIMD2<Double>(40, 12)
    public var D = 0.16, di = 1.4, dk = 0.26, K = 5, dens = 60.0, youngDense = 1.5, replenish = 0.03
    public var perClump = 22, clumpSig = SIMD2<Double>(0.23, 0.53), shell = SIMD2<Double>(1.0, 0.35)
    public var tropUp = 0.16, wander = 0.2, crook = 0.2, zig = 0.12, redraw = 0.1
    public var e = 2.3, ring = 0.03, flare = 0.3
    // foliage
    public var leafLen = 0.125, leafZone = 0.88, shoots = 6.5, rosette = SIMD2<Int>(5, 9)   // leafZone off the 0.16 m internode grid
    // (at 5 x 0.16, dtip < leafZone flips on rounding)
    public var shootLen = SIMD2<Double>(0.04, 0.16), clump = SIMD2<Double>(1.6, 3.6)
    public var heldAges: [Double] = [0, 15, 40, 80], heldFrac: [Double] = [0.7, 0.65, 0.12, 0.06]
    // bark
    public var barkTile = SIMD2<Double>(0.45, 0.9), bark = SIMD3<Double>(128, 114, 96), twig = SIMD3<Double>(104, 94, 82)
    // colours, for the shader
    public var green: [SIMD3<Double>] = [[62, 84, 26], [72, 94, 30], [54, 76, 26]], under = SIMD3<Double>(150, 158, 138)
    public var rose = SIMD3<Double>(160, 128, 118), catkin = SIMD3<Double>(158, 146, 78), lime = SIMD3<Double>(132, 146, 54)
    public var autumn: [SIMD3<Double>] = [[130, 52, 42], [150, 66, 50], [136, 84, 58], [112, 60, 44]]
    public var youngRed = SIMD3<Double>(138, 78, 64), brown = SIMD3<Double>(112, 90, 64)
    public var held = SIMD3<Double>(152, 122, 90), buff = SIMD3<Double>(188, 164, 128), snow = 0.62
    // composition: tree height as a fraction of the screen, 37% at 15 easing toward 60%, and where the trunk stands
    public var frac = SIMD3<Double>(0.37, 0.23, 25), baseX = 0.40

    public init() {}

    public static let whiteOak = TreeSpecies()
}

/// Photo leaf cards: RGBA8 rows top-down, the cells this species uses, and optional normal and scatter maps of the
/// same size (RGBA8; scatter in red). Leaves are stem down in their cells.
public struct LeafAtlas: Sendable {
    var width: Int, height: Int
    var color: [UInt8], premultiplied: Bool
    var normal: [UInt8]?, scatter: [UInt8]?
    var cells: [SIMD4<Int>]   // x, y, width, height

    public init(width: Int, height: Int, color: [UInt8], premultiplied: Bool, normal: [UInt8]?, scatter: [UInt8]?, cells: [SIMD4<Int>]) {
        self.width = width; self.height = height; self.color = color; self.premultiplied = premultiplied
        self.normal = normal; self.scatter = scatter; self.cells = cells
    }
}

/// A bark photo, RGBA8 rows top-down: rows run along the branch, columns around it.
public struct BarkImage: Sendable {
    var width: Int, height: Int, rgba: [UInt8]

    public init(width: Int, height: Int, rgba: [UInt8]) { self.width = width; self.height = height; self.rgba = rgba }
}

/// One depth slab's four RGBA8 textures, rows bottom-up for SKTexture(data:size:):
/// leafLight = sqrt(left, right, back / 1.6), coverage; leafSeed = sqrt(ambient / 1.6), turn, fall|held, tint|underside;
/// woodLight = sqrt(bark lum x (left, right, back) / 0.35), coverage; woodExtra = sqrt(bark lum x ambient / 0.35), snow, 0, 0.
public struct TreeSlab: Sendable {
    public var leafLight: [UInt8], leafSeed: [UInt8], woodLight: [UInt8], woodExtra: [UInt8]
}

/// The baked tree. Slab 0 is the farthest, so a shader composites them in index order.
public struct TreeBake: Sendable {
    public var slabs: [TreeSlab]
    public var origin: SIMD2<Int>          // the crop's top-left corner in the canvas, pixels, y down
    public var size: SIMD2<Int>            // the crop's width and height
    public var trunkBase: SIMD2<Double>    // where the trunk meets the ground, canvas pixels, y down
    public var pixelsPerMetre: Double      // at the trunk, for wind
    public var height: Double              // metres
    public var liveNodes: Int, leaves: Int
    public var timings: [(String, Double)] // seconds per phase
}

/// The skeleton as grown: every node ever grown, its parent, the year it grew and the year it was shed.
struct TreeSkeleton: Sendable {
    var P: [V3], par: [Int], birth: [Double], deadAt: [Double]
    var stats: [(year: Int, nodes: Int, attractors: Int, seconds: Double)]
}

// MARK: - Random numbers, the same in Python and Swift

enum TreeRandom {
    static let g: UInt64 = 0x9E37_79B9_7F4A_7C15

    @inline(__always) static func mix(_ x: UInt64) -> UInt64 {
        var x = x &+ g
        x = (x ^ (x >> 30)) &* 0xBF58_476D_1CE4_E5B9
        x = (x ^ (x >> 27)) &* 0x94D0_49BB_1331_11EB
        return x ^ (x >> 31)
    }

    /// Uniform [0, 1) from a hash of (seed, stream, index, k).
    @inline(__always) static func uniform(_ seed: UInt64, _ stream: UInt64, _ i: Int, _ k: UInt64 = 0) -> Double {
        var x = mix(seed &* g &+ stream)
        x = mix(x &* g &+ UInt64(bitPattern: Int64(i)))
        x = mix(x &* g &+ k)
        return Double(x >> 11) * 0x1p-53
    }

    @inline(__always) static func normal(_ seed: UInt64, _ stream: UInt64, _ i: Int, _ k: UInt64 = 0) -> Double {
        let u1 = max(uniform(seed, stream, i, 2 * k), 1e-300), u2 = uniform(seed, stream, i, 2 * k + 1)
        return (-2 * log(u1)).squareRoot() * cos(2 * Double.pi * u2)
    }

    @inline(__always) static func normal3(_ seed: UInt64, _ stream: UInt64, _ i: Int) -> V3 {
        V3(normal(seed, stream, i, 0), normal(seed, stream, i, 1), normal(seed, stream, i, 2))
    }
}

// MARK: - Small maths, matching numpy's order of operations

@inline(__always) fileprivate func len3(_ v: V3) -> Double { (v.x * v.x + v.y * v.y + v.z * v.z).squareRoot() }
@inline(__always) fileprivate func unit(_ v: V3) -> V3 { v / max(len3(v), 1e-9) }
@inline(__always) fileprivate func dot3(_ a: V3, _ b: V3) -> Double { a.x * b.x + a.y * b.y + a.z * b.z }
@inline(__always) fileprivate func clamp(_ x: Double, _ lo: Double, _ hi: Double) -> Double { min(max(x, lo), hi) }
@inline(__always) fileprivate func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
    let t = clamp((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)
}
@inline(__always) fileprivate func cross3(_ a: V3, _ b: V3) -> V3 {
    V3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
}

/// np.interp
fileprivate func interp(_ x: Double, _ xs: [Double], _ ys: [Double]) -> Double {
    if x <= xs[0] { return ys[0] }
    if x >= xs[xs.count - 1] { return ys[ys.count - 1] }
    var i = 0
    while !(xs[i] <= x && x < xs[i + 1]) { i += 1 }
    return ys[i] + (ys[i + 1] - ys[i]) * (x - xs[i]) / (xs[i + 1] - xs[i])
}

/// numpy's sum for up to 128 values (8-way unrolled pairwise).
fileprivate func npsum(_ a: [Double]) -> Double {
    let n = a.count
    if n < 8 { var s = 0.0; for v in a { s += v }; return s }
    var r = Array(a[0..<8])
    var i = 8
    while i + 8 <= n { for k in 0..<8 { r[k] += a[i + k] }; i += 8 }
    var s = ((r[0] + r[1]) + (r[2] + r[3])) + ((r[4] + r[5]) + (r[6] + r[7]))
    while i < n { s += a[i]; i += 1 }
    return s
}

/// Smooth 3D noise, about [-1, 1], from n fixed plane waves.
struct PlaneWaves: Sendable {
    let k: [V3], ph: [Double], scale: Double

    init(seed: UInt64, stream: UInt64, n: Int, kmin: Double, kmax: Double) {
        k = (0..<n).map { j in unit(TreeRandom.normal3(seed, stream, j)) * (kmin + (kmax - kmin) * TreeRandom.uniform(seed, stream + 1, j)) }
        ph = (0..<n).map { j in 2 * Double.pi * TreeRandom.uniform(seed, stream + 2, j) }
        scale = (Double(n) / 2).squareRoot()
    }

    func callAsFunction(_ p: V3) -> Double {
        npsum((0..<k.count).map { j in sin(dot3(p, k[j]) + ph[j]) }) / scale
    }
}

// MARK: - Nearest-node queries on a uniform grid

struct NodeGrid {
    let lo: V3, cell: Double, n: SIMD3<Int>
    var start: [Int32], items: [Int32]

    init(_ points: [V3], ids: [Int], cell: Double) {
        self.cell = cell
        var lo = V3(repeating: .infinity), hi = V3(repeating: -.infinity)
        for i in ids { lo = pointwiseMin(lo, points[i]); hi = pointwiseMax(hi, points[i]) }
        if ids.isEmpty { lo = .zero; hi = .zero }
        self.lo = lo
        n = SIMD3<Int>(Int((hi.x - lo.x) / cell) + 1, Int((hi.y - lo.y) / cell) + 1, Int((hi.z - lo.z) / cell) + 1)
        var count = [Int32](repeating: 0, count: n.x * n.y * n.z + 1)
        var cellOf = [Int](repeating: 0, count: ids.count)
        for (j, i) in ids.enumerated() {
            let c = Self.index(points[i], lo, cell, n)
            cellOf[j] = c; count[c + 1] += 1
        }
        for c in 0..<(count.count - 1) { count[c + 1] += count[c] }
        var fill = count, items = [Int32](repeating: 0, count: ids.count)
        for (j, i) in ids.enumerated() { items[Int(fill[cellOf[j]])] = Int32(i); fill[cellOf[j]] += 1 }
        start = count; self.items = items
    }

    @inline(__always) static func index(_ p: V3, _ lo: V3, _ cell: Double, _ n: SIMD3<Int>) -> Int {
        let x = min(max(Int((p.x - lo.x) / cell), 0), n.x - 1)
        let y = min(max(Int((p.y - lo.y) / cell), 0), n.y - 1)
        let z = min(max(Int((p.z - lo.z) / cell), 0), n.z - 1)
        return (x * n.y + y) * n.z + z
    }

    /// The nearest point strictly within r (ties to the lower index), as cKDTree's query with distance_upper_bound.
    func nearest(_ q: V3, within r: Double, _ points: [V3]) -> (index: Int, distance: Double)? {
        var best = -1, bestD = r
        let a = q - lo
        let x0 = max(Int(floor((a.x - r) / cell)), 0), x1 = min(Int(floor((a.x + r) / cell)), n.x - 1)
        let y0 = max(Int(floor((a.y - r) / cell)), 0), y1 = min(Int(floor((a.y + r) / cell)), n.y - 1)
        let z0 = max(Int(floor((a.z - r) / cell)), 0), z1 = min(Int(floor((a.z + r) / cell)), n.z - 1)
        if x0 > x1 || y0 > y1 || z0 > z1 { return nil }
        for x in x0...x1 {
            for y in y0...y1 {
                for z in z0...z1 {
                    let c = (x * n.y + y) * n.z + z
                    for s in Int(start[c])..<Int(start[c + 1]) {
                        let i = Int(items[s]), d = len3(points[i] - q)
                        if d < bestD || (d == bestD && best >= 0 && i < best) { best = i; bestD = d }
                    }
                }
            }
        }
        return best >= 0 ? (best, bestD) : nil
    }
}

// MARK: - Growth

struct Envelope { var H: Double, base: Double, R: Double, top: Double }

extension TreeSpecies {
    func effAge(_ a: Double) -> Double {
        if a <= planted { return a }
        return planted + transplant * min(a - planted, 2) + max(0, a - planted - 2)
    }

    /// Height in m: hRate a year, slowing to hRateOld (integrated in quarter years).
    func height(_ a: Double) -> Double {
        let a = effAge(a)
        var h = 0.0, t = 0.125
        while t < a { h += 0.25 * (hRate - (hRate - hRateOld) * smoothstep(hSlow.x, hSlow.y, t)); t += 0.25 }
        return max(h, 0.3)
    }

    func dbh(_ a: Double) -> Double { dbhRate * effAge(a) }
    func width(_ a: Double) -> Double { min(crownA + crownB * dbh(a), 1.3 * height(a)) }
    func clear(_ a: Double) -> Double { interp(a, clearAges, clearH) }
    func maturity(_ a: Double) -> Double { smoothstep(matureAges.x, matureAges.y, a) }

    func envelope(_ a: Double) -> Envelope {
        let H = height(a)
        return Envelope(H: H, base: min(clear(a), 0.3 * H), R: width(a) / 2, top: topYoung + (topOld - topYoung) * maturity(a))
    }

    /// Crown radius factor at height y: an ellipse below the widest point, a superellipse above.
    func profile(_ E: Envelope, _ y: Double) -> Double {
        let t = (y - E.base) / max(E.H - E.base, 1e-6), t0 = widest
        if t < 0 || t > 1 { return 0 }
        if t < t0 { let q = (t0 - t) / t0; return clamp(1 - q * q, 0, 1).squareRoot() }
        let s = clamp((t - t0) / (1 - t0), 0, 1)
        return pow(clamp(1 - pow(s, E.top), 0, 1), 1 / E.top)
    }

    func volume(_ E: Envelope) -> Double {
        let terms = (0..<40).map { i -> Double in
            let y = E.base + (Double(i) + 0.5) / 40 * (E.H - E.base)
            let r = E.R * profile(E, y)
            return Double.pi * (r * r)
        }
        return npsum(terms) * (E.H - E.base) / 40
    }
}

/// The skeleton while it grows.
struct GrowingTree {
    var P: [V3] = [.zero], par: [Int] = [-1], birth: [Double] = [0], stem: [Bool] = [true]
    var lean: [V3] = [.zero], zig: [V3] = [.zero], limbBase: [Double] = [0], nkids: [Int] = [0], deadAt: [Double] = [1e9]

    /// The lean (kept along a limb, re-drawn at forks and now and then) and zigzag the next node would get.
    func newLean(_ S: TreeSpecies, _ seed: UInt64, _ p: Int) -> (V3, V3) {
        let c = P.count
        let lean = nkids[p] > 0 || TreeRandom.uniform(seed, 20, c) < S.redraw ? TreeRandom.normal3(seed, 21, c) * S.crook : self.lean[p]
        return (lean, TreeRandom.normal3(seed, 22, c) * S.zig)
    }

    @discardableResult
    mutating func add(_ S: TreeSpecies, _ seed: UInt64, _ p: Int, _ pos: V3, _ year: Double, stem isStem: Bool = false, lz: (V3, V3)? = nil) -> Int {
        let (l, z) = lz ?? newLean(S, seed, p)
        let c = P.count
        P.append(pos); par.append(p); birth.append(year); stem.append(isStem)
        lean.append(l); zig.append(z)
        limbBase.append(stem[p] ? P[p].y : limbBase[p]); nkids.append(0); nkids[p] += 1
        deadAt.append(1e9)
        return c
    }
}

public enum TreeGrowth {
    /// Inside the envelope (with lumps), and how deep inside, horizontally, in m.
    static func inside(_ S: TreeSpecies, _ E: Envelope, _ p: V3, _ lumps: PlaneWaves) -> (Bool, Double) {
        let rho = hypot(p.x, p.z)
        let lump = 1 + S.envNoise * lumps(unit(p - V3(0, (E.H + E.base) / 2, 0)))
        let lim = E.R * S.profile(E, p.y) * lump
        return (rho < lim, lim - rho)
    }

    /// This year's attractors: clumps in the new shell of the envelope, plus a little everywhere.
    static func attractors(_ S: TreeSpecies, _ seed: UInt64, _ year: Int, _ E: Envelope, _ prev: Envelope?, _ lumps: PlaneWaves) -> [V3] {
        let m = S.maturity(Double(year))
        let dens = S.dens * (1 + S.youngDense * (1 - m))
        let V0 = prev.map { S.volume($0) } ?? 0, V = S.volume(E)
        let n = Int(dens * max(V - V0, 0) + S.replenish * dens * V) + S.perClump
        let nc = max(1, n / S.perClump), nshell = Int(Double(nc) * 0.8)
        var cs: [V3] = []
        var j = 0
        let base = year << 24
        while cs.count < nc && j < 400 * nc {
            let shellOnly = cs.count < nshell && prev != nil
            for q in 0..<256 {
                let idx = base + j + q
                let c = V3((TreeRandom.uniform(seed, 10, idx, 0) * 2 - 1) * E.R,
                           E.base + TreeRandom.uniform(seed, 10, idx, 1) * (E.H - E.base),
                           (TreeRandom.uniform(seed, 10, idx, 2) * 2 - 1) * E.R)
                var ok = inside(S, E, c, lumps).0
                if ok && shellOnly { ok = !inside(S, prev!, c, lumps).0 }
                if ok && cs.count < nc { cs.append(c) }
            }
            j += 256
        }
        let sig = S.clumpSig.x + (S.clumpSig.y - S.clumpSig.x) * m
        let shell = max(S.shell.x, S.shell.y * E.R)
        var pts: [V3] = []
        for (ci, c) in cs.enumerated() {
            for q in 0..<S.perClump {
                let pid = base + ci * S.perClump + q
                let p = c + TreeRandom.normal3(seed, 11, pid) * sig
                let (ok, depth) = inside(S, E, p, lumps)
                if ok && (depth < shell || TreeRandom.uniform(seed, 12, pid) < 0.3) { pts.append(p) }
            }
        }
        return pts
    }

    /// Replay years 1...age: the envelope grows, new attractors fill its new shell, a young tree's leader and whorls
    /// extend, space colonisation continues from last year's skeleton, and limbs below the rising clear trunk are shed.
    static func colonize(_ S: TreeSpecies, seed: UInt64, age: Int) -> TreeSkeleton {
        let D = S.D, di = S.di, dk = S.dk
        let lumps = PlaneWaves(seed: seed, stream: 70, n: 9, kmin: 1.5, kmax: 3.5)
        var T = GrowingTree()
        T.add(S, seed, 0, V3(0, D, 0), 0.5, stem: true)
        var lead = 1
        var A: [V3] = []
        var prev: Envelope? = nil
        var stats: [(year: Int, nodes: Int, attractors: Int, seconds: Double)] = []
        for year in 1...max(age, 1) {
            let t0 = Date()
            let E = S.envelope(Double(year)), m = S.maturity(Double(year)), y = Double(year)
            let fresh = attractors(S, seed, year, E, prev, lumps)
            prev = E
            do {
                let alive = (0..<T.P.count).filter { T.deadAt[$0] > y }
                let grid = NodeGrid(T.P, ids: alive, cell: di)
                for a in fresh where grid.nearest(a, within: dk, T.P) == nil { A.append(a) }
            }
            // a young tree's leader keeps pace with the crown top, and puts out a whorl of level laterals each year
            if year < S.leaderUntil {
                let y0 = T.P.count
                var steps = 0
                while T.P[lead].y < E.H - S.leaderGap && steps < S.K {
                    let w = TreeRandom.normal3(seed, 30, T.P.count) * 0.12 - V3(T.P[lead].x, 0, T.P[lead].z) * 0.08
                    lead = T.add(S, seed, lead, T.P[lead] + D * unit(V3(0, 1, 0) + w), y - 1 + Double(steps + 1) / Double(S.K), stem: true)
                    steps += 1
                }
                if steps > 0 && T.P[lead].y > E.base + 0.3 {
                    let nw = S.whorl.x + Int(TreeRandom.uniform(seed, 31, year) * Double(S.whorl.y - S.whorl.x + 1))
                    let el = (S.whorlElev.x + (S.whorlElev.y - S.whorlElev.x) * m) * (Double.pi / 180)
                    for i in 0..<nw {
                        let az = 2.39996 * Double(i + year * 3) + 0.6 * TreeRandom.uniform(seed, 32, year * 16 + i)
                        let d = V3(cos(az) * cos(el), sin(el), sin(az) * cos(el))
                        T.add(S, seed, lead, T.P[lead] + D * d, y - 0.5)
                    }
                }
                if T.P.count > y0 && !A.isEmpty {
                    let grid = NodeGrid(T.P, ids: Array(y0..<T.P.count), cell: di)
                    A = A.filter { grid.nearest($0, within: dk, T.P) == nil }
                }
            }
            let trop = V3(0, S.tropUp * (1 - m) + 0.03, 0)
            for it in 0..<S.K {
                if A.isEmpty { break }
                let P = T.P
                let alive = (0..<P.count).filter { T.deadAt[$0] > y }
                let grid = NodeGrid(P, ids: alive, cell: di)
                var acc = [V3](repeating: .zero, count: P.count)
                var touched = [Bool](repeating: false, count: P.count)
                var any = false
                for a in A {
                    guard let hit = grid.nearest(a, within: di, P) else { continue }
                    acc[hit.index] += unit(a - P[hit.index]); touched[hit.index] = true; any = true
                }
                if !any { break }
                let n0 = T.P.count
                for g in 0..<P.count where touched[g] {
                    let wander = TreeRandom.normal3(seed, 40, (year * 16 + it) * 1_000_003 + g)
                    let d = unit(unit(acc[g]) + trop + S.wander * wander)
                    let lz = T.newLean(S, seed, g)
                    let pos = P[g] + D * unit(d + min(1.0, P[g].y / 1.5) * (lz.0 + lz.1))   // straight near the ground
                    if grid.nearest(pos, within: 0.45 * D, P) == nil {
                        T.add(S, seed, g, pos, y - 1 + Double(it + 1) / Double(S.K), lz: lz)
                    }
                }
                if T.P.count == n0 { break }
                let fresh = NodeGrid(T.P, ids: Array(n0..<T.P.count), cell: di)
                A = A.filter { fresh.nearest($0, within: dk, T.P) == nil }
            }
            // limbs below the rising clear trunk are shaded out and shed
            let c = S.clear(y)
            for i in 0..<T.P.count where !T.stem[i] && T.deadAt[i] > y && T.limbBase[i] < c { T.deadAt[i] = y }
            stats.append((year, T.P.count, A.count, Date().timeIntervalSince(t0)))
        }
        return TreeSkeleton(P: T.P, par: T.par, birth: T.birth, deadAt: T.deadAt, stats: stats)
    }

    /// The tree in year a: which nodes are alive, tip counts, distance to the farthest tip, radii (pipe model), arc length.
    struct Structure {
        var alive: [Bool], tips: [Double], dtip: [Double], r: [Double], arc: [Double], height: Double
    }

    static func structure(_ S: TreeSpecies, _ T: TreeSkeleton, _ a: Double) -> Structure {
        let n = T.P.count
        let alive = (0..<n).map { T.birth[$0] <= a && T.deadAt[$0] > a }
        var hasKid = [Bool](repeating: false, count: n)
        for i in 1..<n where alive[i] { hasKid[T.par[i]] = true }
        var tips = [Double](repeating: 0, count: n), dtip = tips, seglen = tips
        for i in 1..<n { seglen[i] = len3(T.P[i] - T.P[T.par[i]]) }
        for i in stride(from: n - 1, through: 1, by: -1) where alive[i] {
            if !hasKid[i] { tips[i] = 1 }
            tips[T.par[i]] += tips[i]
            dtip[T.par[i]] = max(dtip[T.par[i]], dtip[i] + seglen[i])
        }
        let raw = (0..<n).map { pow(tips[$0], 1 / S.e) * min(1 + S.ring * (a - T.birth[$0]), 2.5) }
        let base = S.dbh(a) / 200, raw1 = max(raw[1], 1e-9)
        let r = (0..<n).map { raw[$0] * base / raw1 * (1 + S.flare * exp(-T.P[$0].y / 0.3)) }
        var arc = [Double](repeating: 0, count: n)
        for i in 1..<n { arc[i] = arc[T.par[i]] + seglen[i] }
        var h = -Double.infinity
        for i in 0..<n where alive[i] { h = max(h, T.P[i].y) }
        return Structure(alive: alive, tips: tips, dtip: dtip, r: r, arc: arc, height: h)
    }

    struct Leaves {
        var pos: [V3] = [], nrm: [V3] = [], axis: [V3] = [], node: [Int] = [], tint: [Double] = [], cell: [Int] = []
        var shoot: [Int] = [], lid: [Int] = []
        var shootBase: [V3] = [], shootTip: [V3] = [], twigBase: [V3] = [], twigTip: [V3] = []
        var ys: UInt64 = 0
    }

    /// This year's shoots, leaves and twigs, placed fresh from (seed, year).
    static func makeLeaves(_ S: TreeSpecies, _ T: TreeSkeleton, _ st: Structure, seed: UInt64, year: Int, cells: Int) -> Leaves {
        typealias R = TreeRandom
        let ys = R.mix(seed &* R.g &+ UInt64(year))
        let P = T.P, par = T.par
        let C = V3(0, 0.55 * st.height, 0), squash = V3(1, 0.5, 1)
        let waves = PlaneWaves(seed: seed, stream: 50, n: 12, kmin: S.clump.x, kmax: S.clump.y)
        var L = Leaves(); L.ys = ys
        var sn: [Int] = [], sid: [Int] = [], sdir: [V3] = []
        for i in 2..<P.count where st.alive[i] && st.dtip[i] < S.leafZone && st.r[i] < 0.025 {
            let clump = smoothstep(-0.5, 0.7, waves(P[i]))
            let lam = S.shoots * (0.05 + 0.95 * clump)
            let cnt = Int(floor(lam + R.uniform(ys, 1, i)))
            for k in 0..<max(cnt, 0) { sn.append(i); sid.append(i * 16 + k) }
        }
        for (s, i) in sn.enumerated() {
            let id = sid[s]
            let bdir = unit(P[i] - P[par[i]]), out = unit((P[i] - C) * squash)
            let d = unit(bdir + 0.6 * out + V3(0, 0.25, 0) + 0.7 * R.normal3(ys, 2, id))
            let base = P[par[i]] + (P[i] - P[par[i]]) * (0.2 + 0.8 * R.uniform(ys, 3, id))
            let tip = base + d * (S.shootLen.x + (S.shootLen.y - S.shootLen.x) * R.uniform(ys, 4, id))
            sdir.append(d); L.shootBase.append(base); L.shootTip.append(tip)
        }
        for (s, i) in sn.enumerated() {
            let id = sid[s]
            let nl = S.rosette.x + Int(floor(R.uniform(ys, 5, id) * Double(S.rosette.y - S.rosette.x + 1)))
            for j in 0..<nl {
                let lid = id * 32 + j
                let spoke = unit(R.normal3(ys, 6, lid) + 0.6 * sdir[s])
                let pos = L.shootTip[s] + spoke * S.leafLen * 0.3 + R.normal3(ys, 7, lid) * 0.035
                let lout = unit((pos - C) * squash)
                L.pos.append(pos)
                L.nrm.append(unit(V3(0, 1, 0) + 0.7 * lout + 0.7 * R.normal3(ys, 8, lid)))
                L.axis.append(unit(spoke + V3(0, -0.3, 0)))
                L.node.append(i); L.shoot.append(s); L.lid.append(lid)
                L.cell.append(min(Int(R.uniform(ys, 9, lid) * Double(cells)), cells - 1))
                L.tint.append(clamp(R.uniform(ys, 10, i) * 0.8 + R.uniform(ys, 11, lid) * 0.2, 0, 1))
            }
        }
        for (s, id) in sid.enumerated() {
            for q in 0..<2 {
                let tid = id * 4 + q
                let d = unit(sdir[s] + 0.9 * R.normal3(ys, 12, tid))
                L.twigBase.append(L.shootTip[s])
                L.twigTip.append(L.shootTip[s] + d * (0.05 + 0.1 * R.uniform(ys, 13, tid)))
            }
        }
        return L
    }
}

// MARK: - Light

/// Leaf area density on a voxel grid (blurred), and transmittance by marching toward a light.
struct LightGrid: Sendable {
    let lo: V3, cell: Double, n: SIMD3<Int>, g: [Double]

    init(_ pts: [V3], area: [Double], cell: Double) {
        var lo = V3(repeating: .infinity), hi = V3(repeating: -.infinity)
        for p in pts { lo = pointwiseMin(lo, p); hi = pointwiseMax(hi, p) }
        lo -= 1.5; hi += 1.5
        self.lo = lo; self.cell = cell
        let n = SIMD3<Int>(Int(ceil((hi.x - lo.x) / cell)), Int(ceil((hi.y - lo.y) / cell)), Int(ceil((hi.z - lo.z) / cell)))
        self.n = n
        var g = [Double](repeating: 0, count: n.x * n.y * n.z)
        for (i, p) in pts.enumerated() {
            let x = Int((p.x - lo.x) / cell), y = Int((p.y - lo.y) / cell), z = Int((p.z - lo.z) / cell)
            g[(x * n.y + y) * n.z + z] += area[i]
        }
        let inv = 1 / (cell * cell * cell)
        for i in g.indices { g[i] *= inv }
        self.g = Self.blur(g, n)
    }

    /// Separable Gaussian, sigma 0.6, radius 2, zero outside.
    static func blur(_ g: [Double], _ n: SIMD3<Int>) -> [Double] {
        var k = (-2...2).map { x in exp(-Double(x * x) / (2 * 0.6 * 0.6)) }
        let ks = k.reduce(0, +); k = k.map { $0 / ks }
        var src = g
        let strides = [n.y * n.z, n.z, 1], dims = [n.x, n.y, n.z]
        for ax in 0..<3 {
            var dst = [Double](repeating: 0, count: src.count)
            let st = strides[ax], dim = dims[ax]
            for i in 0..<src.count {
                let c = (i / st) % dim
                var s = 0.0
                for t in 0..<5 {
                    let o = c + t - 2
                    if o >= 0 && o < dim { s += k[t] * src[i + (t - 2) * st] } else { s += k[t] * 0 }
                }
                dst[i] = s
            }
            src = dst
        }
        return src
    }

    @inline(__always) func sample(_ q: V3) -> Double {
        let fx = floor(q.x), fy = floor(q.y), fz = floor(q.z)
        let tx = q.x - fx, ty = q.y - fy, tz = q.z - fz
        let ix = Int(fx), iy = Int(fy), iz = Int(fz)
        var out = 0.0
        for dx in 0...1 {
            let x = ix + dx
            if x < 0 || x >= n.x { continue }
            let wx = dx == 1 ? tx : 1 - tx
            for dy in 0...1 {
                let y = iy + dy
                if y < 0 || y >= n.y { continue }
                let wy = dy == 1 ? ty : 1 - ty
                for dz in 0...1 {
                    let z = iz + dz
                    if z < 0 || z >= n.z { continue }
                    let wz = dz == 1 ? tz : 1 - tz
                    out += wx * wy * wz * g[(x * n.y + y) * n.z + z]
                }
            }
        }
        return out
    }

    /// exp(-G * optical depth) from p toward d. Steps outside the grid add exactly nothing, so they're skipped.
    func trans(_ p: V3, _ d: V3, start: Double = 0.3, step: Double = 0.25, maxd: Double = 30, G: Double = 0.35) -> Double {
        let count = Int(ceil((maxd - start) / step))
        let q0 = (p - lo) / cell - 0.5, dq = d / cell
        var sLo = -Double.infinity, sHi = Double.infinity
        for a in 0..<3 {
            let lim = Double([n.x, n.y, n.z][a])
            if dq[a] == 0 {
                if q0[a] <= -1 || q0[a] >= lim { return 1 }
            } else {
                let s1 = (-1 - q0[a]) / dq[a], s2 = (lim - q0[a]) / dq[a]
                sLo = max(sLo, min(s1, s2)); sHi = min(sHi, max(s1, s2))
            }
        }
        if sHi < sLo { return 1 }
        let i0 = max(0, Int(floor((sLo - start) / step)) - 1), i1 = min(count - 1, Int(ceil((sHi - start) / step)) + 1)
        var tau = 0.0
        if i0 <= i1 {
            for i in i0...i1 {
                let s = start + Double(i) * step
                tau += sample((p + d * s - lo) / cell - 0.5)
            }
        }
        return exp(-G * tau * step)
    }

    static func skyDirs(_ n: Int) -> [V3] {
        (0..<n).map { k in
            let z = ((Double(k) + 0.5) / Double(n)).squareRoot(), a = Double(k) * 2.39996, s = (1 - z * z).squareRoot()
            return V3(cos(a) * s, z, sin(a) * s)
        }
    }

    func sky(_ p: V3, _ n: Int) -> Double {
        var acc = 0.0
        for d in Self.skyDirs(n) { acc += trans(p, d, step: 0.35) }
        return acc / Double(n)
    }
}

fileprivate let lightL = unit(V3(-0.62, 0.72, -0.35))   // Sun upper left, behind the viewer
fileprivate let lightR = unit(V3(0.62, 0.72, -0.35))    // upper right, behind
fileprivate let lightB = unit(V3(0.30, 0.20, 1.0))      // ahead and low: golden hour, backlit

/// Runs body(i) for 0..<n across the cores, in chunks.
fileprivate func parallel(_ n: Int, chunk: Int = 256, _ body: @Sendable (Range<Int>) -> Void) {
    let chunks = (n + chunk - 1) / chunk
    DispatchQueue.concurrentPerform(iterations: chunks) { c in body(c * chunk..<min(n, (c + 1) * chunk)) }
}

/// A buffer that parallel chunks write disjoint parts of.
fileprivate struct SharedBuffer<T>: @unchecked Sendable {
    let p: UnsafeMutablePointer<T>
    init(_ n: Int, _ v: T) { p = .allocate(capacity: n); p.initialize(repeating: v, count: n) }
    subscript(i: Int) -> T { get { p[i] } nonmutating set { p[i] = newValue } }
    func array(_ n: Int) -> [T] { let a = Array(UnsafeBufferPointer(start: p, count: n)); p.deallocate(); return a }
}

// MARK: - Leaf cards and bark

struct CardKey: Hashable, Sendable { var cell: Int, s2: Int, ang: Int, fs: Int }

struct Card: Sendable {
    var R: Int, a: [Float], lum: [Float], n: [SIMD3<Float>], sc: [Float]
}

/// One atlas cell, ready to sample: alpha, luminance over its median (detail), normal, scatter, the leaf's extent.
struct CardSource: Sendable {
    var w: Int, h: Int, a: [Float], lum: [Float], n: [SIMD3<Float>], sc: [Float], L: Double, cy: Double, cx: Double

    init(_ atlas: LeafAtlas, _ r: SIMD4<Int>) {
        w = r.z; h = r.w
        a = []; lum = []; n = []; sc = []
        a.reserveCapacity(w * h)
        var ymin = Int.max, ymax = Int.min, xmin = Int.max, xmax = Int.min
        for y in 0..<h {
            for x in 0..<w {
                let o = ((r.y + y) * atlas.width + r.x + x) * 4
                let al = Float(atlas.color[o + 3]) / 255
                var rgb = SIMD3<Float>(Float(atlas.color[o]), Float(atlas.color[o + 1]), Float(atlas.color[o + 2])) / 255
                if atlas.premultiplied && al > 0 { rgb = simd_min(rgb / al, SIMD3(repeating: 1)) }
                let l = powf(rgb.x, 2.2) * 0.3 + powf(rgb.y, 2.2) * 0.59 + powf(rgb.z, 2.2) * 0.11
                a.append(al); lum.append(l)
                if let nm = atlas.normal {
                    n.append(SIMD3<Float>(Float(nm[o]), Float(nm[o + 1]), Float(nm[o + 2])) / 255 * 2 - 1)
                } else { n.append(SIMD3(0, 0, 1)) }
                sc.append(atlas.scatter.map { Float($0[o]) / 255 } ?? 0.5)
                if al > 0.5 { ymin = min(ymin, y); ymax = max(ymax, y); xmin = min(xmin, x); xmax = max(xmax, x) }
            }
        }
        var solid: [Float] = []
        for i in 0..<(w * h) where a[i] > 0.5 { solid.append(lum[i]) }
        solid.sort()
        let med = solid.isEmpty ? 1 : (solid.count % 2 == 1 ? solid[solid.count / 2] : (solid[solid.count / 2 - 1] + solid[solid.count / 2]) / 2)
        for i in lum.indices { lum[i] = min(max(lum[i] / med, 0.45), 1.5) }
        L = Double(max(ymax - ymin + 1, 1)); cy = Double(ymin + ymax) / 2; cx = Double(xmin + xmax) / 2
    }

    /// The card at a size (2x px), angle (32 steps) and foreshortening (5 steps), 3x supersampled.
    func card(_ key: CardKey) -> Card {
        let L = Double(key.s2) / 2, th = Double(key.ang) / 32 * 2 * Double.pi, f = max(0.18, (Double(key.fs) + 0.5) / 5)
        let R = Int(ceil(L * 0.6)) + 1, ss = 3, sz = 2 * R + 1
        var A = [Float](repeating: 0, count: sz * sz), lu = A, sca = A, nn = [SIMD3<Float>](repeating: .zero, count: sz * sz)
        let ct = cos(th), st = sin(th)
        for iy in 0..<(sz * ss) {
            let Y = (Double(iy - R * ss) + 0.5) / Double(ss) - 0.5
            for ix in 0..<(sz * ss) {
                let X = (Double(ix - R * ss) + 0.5) / Double(ss) - 0.5
                let u = (ct * X + st * Y) / (L * f), v = (-st * X + ct * Y) / L
                guard abs(u) < 0.7 && abs(v) < 0.7 else { continue }
                let py = Int(clamp(floor(cy - v * self.L), 0, Double(h - 1))), px = Int(clamp(floor(cx + u * self.L), 0, Double(w - 1)))
                let o = py * w + px, al = a[o]
                let t = (iy / ss) * sz + ix / ss
                A[t] += al; lu[t] += lum[o] * al; nn[t] += n[o] * al; sca[t] += sc[o] * al
            }
        }
        for t in 0..<(sz * sz) {
            let m = A[t] / 9, w = max(m, 1e-6)
            lu[t] = m > 0 ? lu[t] / 9 / w : 1
            nn[t] = nn[t] / 9 / w
            sca[t] = m > 0 ? sca[t] / 9 / w : 0
            A[t] = m
        }
        return Card(R: R, a: A, lum: lu, n: nn, sc: sca)
    }
}

/// Bark photo luminance, mean 1.
fileprivate func barkLuminance(_ b: BarkImage) -> [Float] {
    var l = [Float](repeating: 0, count: b.width * b.height)
    for i in l.indices {
        let r = powf(Float(b.rgba[i * 4]) / 255, 2.2), g = powf(Float(b.rgba[i * 4 + 1]) / 255, 2.2), bl = powf(Float(b.rgba[i * 4 + 2]) / 255, 2.2)
        l[i] = r * 0.3 + g * 0.59 + bl * 0.11
    }
    let mean = l.reduce(0, +) / Float(l.count)
    return l.map { $0 / mean }
}

/// Each leaf on screen: position and depth, which side faces us, its card's axes, angle, foreshortening and size.
struct LeafFrames: Sendable {
    var lx: [Double] = [], ly: [Double] = [], lz: [Double] = [], facing: [Double] = [], ang: [Double] = [], fs: [Double] = []
    var size: [Double] = [], ns: [V3] = [], ax: [V3] = [], bx: [V3] = []

    init(_ L: TreeGrowth.Leaves, _ cam: TreeCamera, leafLen: Double) {
        for i in 0..<L.pos.count {
            let q = cam.project(L.pos[i])
            let f = dot3(L.nrm[i], unit(cam.C - L.pos[i]))
            let sg: Double = f > 0 ? 1 : (f < 0 ? -1 : 0)
            let n = L.nrm[i] * sg
            let a = unit(L.axis[i] - n * dot3(L.axis[i], n))
            let q2 = cam.project(L.pos[i] + 0.05 * a)
            lx.append(q.x); ly.append(q.y); lz.append(q.z); facing.append(f)
            ns.append(n); ax.append(a); bx.append(unit(cross3(n, a)) * sg)
            ang.append(atan2(q2.y - q.y, q2.x - q.x) - Double.pi / 2)
            fs.append(clamp(abs(f), 0.18, 1)); size.append(leafLen * cam.F / q.z)
        }
    }
}

// MARK: - Camera

/// Level camera. The trunk base stands at (baseX, groundY); the horizon is a line the caller gives (both fractions of
/// the height from the bottom). The tree's screen height follows frac(age).
struct TreeCamera: Sendable {
    let horizon: Double, base: SIMD2<Double>, d: Double, F: Double, C: V3

    init(_ S: TreeSpecies, _ W: Int, _ H: Int, height: Double, age: Double, horizon h: Double, groundY: Double) {
        let frac = S.frac.x + S.frac.y * (1 - exp(-(age - 15) / S.frac.z))
        horizon = Double(H) * (1 - h); base = SIMD2(S.baseX * Double(W), Double(H) * (1 - groundY))
        let b = base.y - horizon
        let eye = b * height / (frac * Double(H))
        d = 4.5 * height + 20; F = b / eye * d
        C = V3(0, eye, -d)
    }

    @inline(__always) func project(_ p: V3) -> (x: Double, y: Double, z: Double) {
        let rel = p - C
        return (base.x + F * rel.x / rel.z, horizon - F * rel.y / rel.z, rel.z)
    }
}

// MARK: - Bake

extension TreeGrowth {
    /// Grows the tree to `age` and bakes it for a canvas of `pixels` (e.g. 3024x1964 at 2x): 3 depth slabs of 4 RGBA8
    /// textures each, cropped to the tree. `horizon` and `groundY` are fractions of the height from the bottom.
    public static func bake(_ S: TreeSpecies, seed: UInt64, age: Int, pixels: SIMD2<Int>, horizon: Double = 0.30,
                     groundY: Double = 0.2123, atlas: LeafAtlas, bark: BarkImage, slabs nslab: Int = 3) -> TreeBake {
        var timings: [(String, Double)] = []
        var clock = Date()
        func lap(_ name: String) { timings.append((name, Date().timeIntervalSince(clock))); clock = Date() }
        let T = colonize(S, seed: seed, age: age)
        lap("grow")
        return bake(S, T, seed: seed, age: age, pixels: pixels, horizon: horizon, groundY: groundY, atlas: atlas, bark: bark,
                    slabs: nslab, timings: timings)
    }

    static func bake(_ S: TreeSpecies, _ T: TreeSkeleton, seed: UInt64, age: Int, pixels: SIMD2<Int>, horizon: Double,
                     groundY: Double, atlas: LeafAtlas, bark: BarkImage, slabs nslab: Int, timings t0: [(String, Double)] = []) -> TreeBake {
        var timings = t0
        var clock = Date()
        func lap(_ name: String) { timings.append((name, Date().timeIntervalSince(clock))); clock = Date() }
        let W = pixels.x, H = pixels.y, a = Double(age)
        let st = structure(S, T, a)
        let Lf = makeLeaves(S, T, st, seed: seed, year: age, cells: atlas.cells.count)
        let P = T.P, par = T.par, r = st.r, arc = st.arc
        // segments: live branches, then shoots (from partway along their parent), then side twigs
        let live = (1..<P.count).filter { st.alive[$0] }
        let tw = 0.0028
        let S0 = live.map { P[par[$0]] } + Lf.shootBase + Lf.twigBase
        let P1 = live.map { P[$0] } + Lf.shootTip + Lf.twigTip
        let ns = Lf.shootTip.count, nt = Lf.twigTip.count
        let R0 = live.map { r[par[$0]] } + [Double](repeating: tw, count: ns) + [Double](repeating: tw * 0.7, count: nt)
        let R1 = live.map { r[$0] } + [Double](repeating: tw * 0.7, count: ns) + [Double](repeating: tw * 0.45, count: nt)
        let A0 = live.map { arc[par[$0]] } + [Double](repeating: 0, count: ns + nt)
        let A1 = live.map { arc[$0] } + [Double](repeating: 0, count: ns + nt)
        let nseg = P1.count
        let cam = TreeCamera(S, W, H, height: st.height, age: a, horizon: horizon, groundY: groundY)
        lap("structure and leaves")
        // light through the canopy
        let area = S.leafLen * S.leafLen * 0.36
        let grid = LightGrid(Lf.pos, area: [Double](repeating: area, count: Lf.pos.count), cell: 0.15)
        let nl = Lf.pos.count
        let bTL = SharedBuffer(nl, 0.0), bTR = SharedBuffer(nl, 0.0), bTB = SharedBuffer(nl, 0.0), bAO = SharedBuffer(nl, 0.0)
        parallel(nl, chunk: 128) { range in
            for i in range {
                bTL[i] = grid.trans(Lf.pos[i], lightL); bTR[i] = grid.trans(Lf.pos[i], lightR)
                bTB[i] = grid.trans(Lf.pos[i], lightB); bAO[i] = grid.sky(Lf.pos[i], 10)
            }
        }
        let TL = bTL.array(nl), TR = bTR.array(nl), TB = bTB.array(nl), AO = bAO.array(nl)
        let mid = (0..<nseg).map { 0.5 * (P1[$0] + S0[$0]) }
        let w0 = SharedBuffer(nseg, 0.0), w1 = SharedBuffer(nseg, 0.0), w2 = SharedBuffer(nseg, 0.0), wao = SharedBuffer(nseg, 0.0)
        parallel(nseg, chunk: 128) { range in
            for i in range {
                w0[i] = grid.trans(mid[i], lightL); w1[i] = grid.trans(mid[i], lightR)
                let b = grid.trans(mid[i], lightB); w2[i] = b * b; wao[i] = grid.sky(mid[i], 6)
            }
        }
        let WT0 = w0.array(nseg), WT1 = w1.array(nseg), WT2 = w2.array(nseg), WAO = wao.array(nseg)
        lap("light")
        // slabs and crop
        var xmin = Double.infinity, xmax = -Double.infinity, zmin = Double.infinity, zmax = -Double.infinity
        for i in 0..<P.count where st.alive[i] { xmin = min(xmin, P[i].x); xmax = max(xmax, P[i].x); zmin = min(zmin, P[i].z); zmax = max(zmax, P[i].z) }
        let Rm = ((xmax - xmin) + (zmax - zmin)) / 4 + 0.5
        let edges: [Double] = nslab == 3 ? [-1e9, -0.25, 0.25, 1e9] : [-1e9, -0.45, -0.12, 0.12, 0.45, 1e9]
        func slabOf(_ z: Double) -> Int {
            let x = (z - cam.d) / Rm
            var k = 0
            while k < edges.count && edges[k] <= x { k += 1 }
            return nslab - 1 - min(max(k - 1, 0), nslab - 1)    // 0 = farthest
        }
        var bx = (Double.infinity, -Double.infinity), by = (Double.infinity, -Double.infinity)
        for p in P1 + Lf.pos { let q = cam.project(p); bx = (min(bx.0, q.x), max(bx.1, q.x)); by = (min(by.0, q.y), max(by.1, q.y)) }
        let x0 = max(Int(floor(bx.0)) - 24, 0), y0 = max(Int(floor(by.0)) - 24, 0)
        let x1 = min(Int(ceil(bx.1)) + 24, W), y1 = min(Int(ceil(by.1)) + 24, H)
        let w = x1 - x0, h = y1 - y0
        // cards
        let sources = atlas.cells.map { CardSource(atlas, $0) }
        let barkL = barkLuminance(bark)
        let lumw = V3(0.3, 0.59, 0.11)
        func lin(_ c: SIMD3<Double>) -> V3 { V3(pow(c.x / 255, 2.2), pow(c.y / 255, 2.2), pow(c.z / 255, 2.2)) }
        let barkAlb = dot3(lin(S.bark), lumw), twigAlb = dot3(lin(S.twig), lumw)
        // leaf geometry on screen, and the seeds
        let F = LeafFrames(Lf, cam, leafLen: S.leafLen)
        let (lx, ly, lz, facing, nsv, Ax, Bx) = (F.lx, F.ly, F.lz, F.facing, F.ns, F.ax, F.bx)
        func meanStd(_ x: [Double]) -> (Double, Double) {
            let m = x.reduce(0, +) / Double(x.count)
            let v = x.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(x.count)
            return (m, v.squareRoot())
        }
        let expo = (0..<nl).map { clamp(0.6 * (TL[$0] + TR[$0]) / 2 + 0.4 * AO[$0], 0, 1) }
        let relh = (0..<nl).map { clamp(Lf.pos[$0].y / st.height, 0, 1) }
        let (em, es) = meanStd(expo), (hm, hs) = meanStd(relh)
        let ys = Lf.ys
        // the sunny outer crown and the top turn first, whole branch sectors together; held leaves low and inside
        let turn = (0..<nl).map { i -> Double in
            var anc = Lf.node[i]
            for _ in 0..<10 where anc > 1 { anc = par[anc] }
            let er = (expo[i] - em) / (es + 1e-6), hr = (relh[i] - hm) / (hs + 1e-6)
            let x = -0.8 * er - 0.8 * hr + TreeRandom.normal(ys, 20, anc) + 0.25 * TreeRandom.normal(ys, 21, Lf.lid[i])
            return 1 / (1 + exp(-x))
        }
        let score = (0..<nl).map { 0.9 * (1 - relh[$0]) + 0.35 * (1 - expo[$0]) + 0.12 * TreeRandom.normal(ys, 22, Lf.shoot[$0]) }
        let heldFrac = interp(a, S.heldAges, S.heldFrac)
        let sorted = score.sorted()
        let qpos = (1 - heldFrac) * Double(nl - 1), qlo = Int(floor(qpos)), qhi = min(qlo + 1, nl - 1)
        let threshold = nl > 0 ? sorted[qlo] + (sorted[qhi] - sorted[qlo]) * (qpos - Double(qlo)) : 0
        let fall = (0..<nl).map { i in
            score[i] > threshold ? 0.8 + 0.2 * TreeRandom.uniform(ys, 23, Lf.lid[i]) : 0.78 * TreeRandom.uniform(ys, 24, Lf.lid[i])
        }
        // cards needed, made in parallel
        let keyOf = (0..<nl).map { i -> CardKey in
            let a32 = Int(floor(F.ang[i] / (2 * Double.pi) * 32))
            return CardKey(cell: Lf.cell[i], s2: Int((F.size[i] * 2).rounded(.toNearestOrEven)), ang: ((a32 % 32) + 32) % 32, fs: Int(F.fs[i] * 5))
        }
        let keys = Array(Set(keyOf.filter { $0.s2 > 0 }))
        let made = SharedBuffer<Card?>(keys.count, nil)
        parallel(keys.count, chunk: 8) { range in for j in range { made[j] = sources[keys[j].cell].card(keys[j]) } }
        let cards = Dictionary(uniqueKeysWithValues: zip(keys, made.array(keys.count).map { $0! }))
        // per-slab work lists; leaves in painter's order, far to near, stable
        let proj0 = S0.map { cam.project($0) }, proj1 = P1.map { cam.project($0) }
        let order = (0..<nl).sorted { lz[$0] > lz[$1] || (lz[$0] == lz[$1] && $0 < $1) }
        let segsOf = (0..<nslab).map { k in (0..<nseg).filter { slabOf(0.5 * (proj0[$0].z + proj1[$0].z)) == k } }
        let leavesOf = (0..<nslab).map { k in order.filter { slabOf(lz[$0]) == k } }
        lap("seeds and cards")
        // rasterise each slab on its own core: wood (z-buffered, with snow caps), then leaves depth-tested against it
        let npx = w * h
        let out = SharedBuffer<TreeSlab?>(nslab, nil)
        DispatchQueue.concurrentPerform(iterations: nslab) { k in
            var wl = [SIMD4<Float>](repeating: .zero, count: npx), wa = [Float](repeating: 0, count: npx)
            var wlum = wa, snow = wa, wz = [Float](repeating: .infinity, count: npx)
            var la = [SIMD4<Float>](repeating: .zero, count: npx), lcov = wa, lb = [SIMD3<Float>](repeating: .zero, count: npx)
            for i in segsOf[k] {
                let s = proj0[i], p = proj1[i]
                let za = s.z, zb = p.z
                let pa = SIMD2(s.x - Double(x0), s.y - Double(y0)), pb = SIMD2(p.x - Double(x0), p.y - Double(y0))
                let ra = R0[i] * cam.F / za, rb = R1[i] * cam.F / zb
                let rm = max(ra, rb)
                let cap = rm < 1 ? min(0.4 + 0.6 * rm, 4.0) : min(0.9 + 0.7 * rm, 6.0)
                let bx0 = max(Int(floor(min(pa.x, pb.x) - rm - cap - 1.5)), 0), by0 = max(Int(floor(min(pa.y, pb.y) - rm - cap - 1.5)), 0)
                let bx1 = min(Int(ceil(max(pa.x, pb.x) + rm + cap + 1.5)), w), by1 = min(Int(ceil(max(pa.y, pb.y) + rm + cap + 1.5)), h)
                if bx1 <= bx0 || by1 <= by0 { continue }
                let d = pb - pa, L2 = max(d.x * d.x + d.y * d.y, 1e-9), Ls = L2.squareRoot()
                let perp = SIMD2(-d.y, d.x) / Ls
                let upsign: Double = perp.y > 0 ? -1 : 1
                let ax = unit(P1[i] - S0[i]), level = max(0, 1 - abs(ax.y) * 1.15)
                let groundAt = cam.horizon + cam.F * cam.C.y / za
                let V = unit(cam.C - mid[i])
                var side = unit(cross3(ax, V)), front = unit(cross3(side, ax))
                if dot3(front, V) < 0 { front = -front }
                let s2a = cam.project(mid[i] + 0.01 * side), s2b = cam.project(mid[i])
                if (s2a.x - s2b.x) * perp.x + (s2a.y - s2b.y) * perp.y < 0 { side = -side }
                let covScale = min(1.0, 2 * rm)
                @inline(__always) func coverage(_ X: Int, _ Y: Int) -> (t: Double, across: Double, dist: Double, rr: Double, cov: Double, capc: Double) {
                    let xc = Double(X) + 0.5, yc = Double(Y) + 0.5
                    let below = clamp(groundAt - (yc + Double(y0)) + 0.5, 0, 1)
                    let t = clamp(((xc - pa.x) * d.x + (yc - pa.y) * d.y) / L2, 0, 1)
                    let cx = pa.x + t * d.x, cy = pa.y + t * d.y
                    let rr = ra + (rb - ra) * t
                    let across = (xc - cx) * perp.x + (yc - cy) * perp.y
                    let dist = hypot(xc - cx, yc - cy)
                    let cov = clamp(rr - dist + 0.5, 0, 1) * covScale * below
                    let upd = upsign * across - rr
                    let capc = clamp(1 - abs(upd - cap * 0.3) / (cap * 0.8 + 0.5), 0, 1) * (dist < rr + cap + 0.5 ? 1 : 0) * below
                    return (t, across, dist, rr, cov, capc)
                }
                var visible = false
                scan: for Y in by0..<by1 { for X in bx0..<bx1 { let c = coverage(X, Y); if c.cov > 0.01 || c.capc > 0.01 { visible = true; break scan } } }
                if !visible { continue }
                for Y in by0..<by1 {
                    for X in bx0..<bx1 {
                        let (t, across, _, rr, cov, capc) = coverage(X, Y)
                        if cov == 0 && capc == 0 { continue }                // a no-op in the numpy version too
                        let u = clamp(across / max(rr, 1e-3), -1, 1)
                        let cu = (1 - u * u).squareRoot()
                        let nrm = u * side + cu * front
                        let lL = WT0[i] * max(dot3(nrm, lightL), 0), lR = WT1[i] * max(dot3(nrm, lightR), 0)
                        let rim = pow(1 - cu, 3) * clamp(dot3(nrm, lightB) + 0.5, 0, 1.5) * 0.8      // back-lit wood: only a rim
                        let lB = WT2[i] * (max(dot3(nrm, lightB), 0) + rim)
                        let amb = WAO[i] * (0.6 + 0.4 * nrm.y) + 0.15 * max(-nrm.y, 0) + 0.06              // + light off the ground
                        let rmet = R0[i] + (R1[i] - R0[i]) * t
                        var lum = twigAlb
                        if rm > 1 {
                            let around = rmet * asin(u) + Double(i % 7) * 0.11
                            let along = A0[i] + t * (A1[i] - A0[i])
                            let row = ((Int(along / S.barkTile.y * Double(bark.height)) % bark.height) + bark.height) % bark.height
                            let col = ((Int(around / S.barkTile.x * Double(bark.width)) % bark.width) + bark.width) % bark.width
                            lum = barkAlb * Double(barkL[row * bark.width + col])
                        }
                        var snowv = level * (cov > 0.5 ? clamp(nrm.y * 1.6 - 0.2, 0, 1) : capc)
                        if rm < 1 { snowv *= 0.5 }                          // twigs only grey over; limbs get the line
                        let zz = (za + (zb - za) * t) - rmet * cu
                        let o = Y * w + X
                        let closer = zz < Double(wz[o])
                        let c = Float(closer ? cov : 0)
                        wl[o] = wl[o] * (1 - c) + SIMD4<Float>(Float(lL), Float(lR), Float(lB), Float(amb)) * c
                        wlum[o] = wlum[o] * (1 - c) + Float(lum) * c
                        if closer { wa[o] = max(wa[o], Float(cov)) }
                        if closer || cov < 0.01 { snow[o] = max(snow[o], Float(snowv) * (cov + capc > 0.01 ? 1 : 0)) }
                        if closer && cov > 0.5 { wz[o] = Float(zz) }
                    }
                }
            }
            let trans = 0.3
            for i in leavesOf[k] {
                let key = keyOf[i]
                guard key.s2 > 0, let cd = cards[key] else { continue }
                let cx = Int((lx[i] - Double(x0)).rounded(.toNearestOrEven)), cy = Int((ly[i] - Double(y0)).rounded(.toNearestOrEven))
                let ya = cy - cd.R, xa = cx - cd.R, sz = 2 * cd.R + 1
                if ya < 0 || xa < 0 || ya + sz > h || xa + sz > w { continue }
                let tb2 = TB[i] * TB[i]
                let seed = SIMD3<Float>(Float(turn[i]), Float(fall[i]), Float(Lf.tint[i] * 0.49 + (facing[i] < 0 ? 0.51 : 0)))
                for yy in 0..<sz {
                    for xx in 0..<sz {
                        let t = yy * sz + xx, o = (ya + yy) * w + xa + xx
                        var A = Double(cd.a[t])
                        if !(lz[i] < Double(wz[o])) { A = 0 }
                        if A == 0 { continue }
                        let nt = cd.n[t]
                        let nn = unit(Double(nt.x) * 0.6 * Bx[i] + Double(nt.y) * 0.6 * Ax[i] + max(Double(nt.z), 0.3) * nsv[i])
                        let lum = Double(cd.lum[t]), sc = Double(cd.sc[t])
                        func lit(_ Tk: Double, _ Lk: V3) -> Double {
                            let c = dot3(nn, Lk)
                            return Tk * (max(c, 0) + trans * (0.4 + 0.6 * sc) * max(-c, 0)) * lum
                        }
                        let v = SIMD4<Float>(Float(lit(TL[i], lightL)), Float(lit(TR[i], lightR)), Float(lit(tb2, lightB)),
                                             Float(AO[i] * (0.65 + 0.35 * nn.y) * lum))
                        let Af = Float(A)
                        la[o] = la[o] * (1 - Af) + v * Af
                        lcov[o] = lcov[o] * (1 - Af) + Af
                        if A > 0.4 { lb[o] = seed }
                    }
                }
            }
            out[k] = pack(w: w, h: h, wl: wl, wa: wa, wlum: wlum, snow: snow, la: la, lcov: lcov, lb: lb)
        }
        let packed = out.array(nslab).map { $0! }
        lap("rasterise and pack")
        return TreeBake(slabs: packed, origin: SIMD2(x0, y0), size: SIMD2(w, h), trunkBase: cam.base,
                        pixelsPerMetre: cam.F / cam.d, height: st.height, liveNodes: live.count + 1, leaves: nl, timings: timings)
    }

    /// The four RGBA8 textures of a slab (see TreeSlab), rows bottom-up.
    static func pack(w: Int, h: Int, wl: [SIMD4<Float>], wa: [Float], wlum: [Float], snow: [Float],
                     la: [SIMD4<Float>], lcov: [Float], lb: [SIMD3<Float>]) -> TreeSlab {
        var leafL = [UInt8](repeating: 0, count: w * h * 4), leafS = leafL, woodL = leafL, woodX = leafL
        @inline(__always) func u8(_ x: Float) -> UInt8 { UInt8(min(max(x, 0), 1) * 255 + 0.5) }
        @inline(__always) func q(_ v: Float, _ s: Float) -> Float { (min(max(v / s, 0), 1)).squareRoot() }
        for y in 0..<h {
            for x in 0..<w {
                let i = y * w + x, o = ((h - 1 - y) * w + x) * 4
                let A = lcov[i], ll = la[i] / max(A, 1e-4)
                leafL[o] = u8(q(ll.x, 1.6)); leafL[o + 1] = u8(q(ll.y, 1.6)); leafL[o + 2] = u8(q(ll.z, 1.6)); leafL[o + 3] = u8(A)
                leafS[o] = u8(q(ll.w, 1.6)); leafS[o + 1] = u8(lb[i].x); leafS[o + 2] = u8(lb[i].y); leafS[o + 3] = u8(lb[i].z)
                let a = wa[i], wv = wl[i] / max(a, 1e-4), lum = wlum[i] / max(a, 1e-4)
                woodL[o] = u8(q(lum * wv.x, 0.35)); woodL[o + 1] = u8(q(lum * wv.y, 0.35)); woodL[o + 2] = u8(q(lum * wv.z, 0.35))
                woodL[o + 3] = u8(a)
                woodX[o] = u8(q(lum * wv.w, 0.35)); woodX[o + 1] = u8(snow[i])
            }
        }
        return TreeSlab(leafLight: leafL, leafSeed: leafS, woodLight: woodL, woodExtra: woodX)
    }
}
