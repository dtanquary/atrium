import Foundation
import simd

/// Maps the world (x, y, z; z up) to the screen and back: isometric 2:1, the layout on the world's axes so its
/// straights run on the diagonals.
struct RailView {
    let w: Int, h: Int
    /// A pixel's ray, toward the viewer: every world point along it projects to the same pixel.
    let ray: SIMD3<Double> = [1, 1, 1]

    func project(_ p: SIMD3<Double>) -> SIMD2<Double> { [p.x - p.y + Double(w) / 2, (p.x + p.y) / 2 + Double(h) / 2 - p.z] }

    /// Larger is nearer the viewer; only compared along one pixel's ray.
    func depth(_ p: SIMD3<Double>) -> Double { p.x + p.y + p.z }

    /// The depth where pixel (x, y)'s ray meets the plane at height z: flat things in one pixel share it, so
    /// coplanar layers never fight.
    func pixelDepth(_ x: Int, _ y: Int, _ z: Double) -> Double { 2 * (Double(y) + 0.5 - Double(h) / 2) + 3 * z }

    /// The world offset at a fixed height that moves the screen point by (dx, dy).
    func unproject(_ dx: Double, _ dy: Double) -> SIMD2<Double> { [dy + dx / 2, dy - dx / 2] }

    /// Where pixel (x, y)'s centre meets the ground.
    func ground(_ x: Int, _ y: Int) -> SIMD2<Double> {
        let (a, b) = (Double(x) + 0.5 - Double(w) / 2, Double(y) + 0.5 - Double(h) / 2)
        return [b + a / 2, b - a / 2]
    }

    /// The direction the Sun's light comes from: the left.
    let sun = normalize(SIMD3<Double>(-0.30, 0.60, 0.74))
}

/// A voxel model seen in one view: every pixel of its sprite, as offsets from the pixel its centre falls on.
struct Marched {
    var dx: [Int16] = [], dy: [Int16] = [], mat: [UInt16] = [], top: [Bool] = []
    var normal: [SIMD3<Double>] = []
    /// Depth relative to the model's foot.
    var dd: [Float] = []
    var count: Int { mat.count }

    /// Marches each sprite pixel's ray down through the model, top first, from just above it: the first filled
    /// cell is what shows, and which of the cell's indices changed from the step before says which face. The
    /// model's footprint is centred on its position, turned by `heading`, and tipped by `slope` (rise per unit
    /// along) on a ramp. `smooth` shades every face as a top: the hill's steps would otherwise show as terraces
    /// wherever its width puts a step's front between two of the ray's samples (its grass is already lit by slope).
    /// `fine` takes four rays a pixel, for the trains: a pixel shows what most of them hit, and where two things
    /// tie, the one rarer in the whole sprite, so a stripe or a row of windows one voxel high doesn't break into
    /// dots at headings where it falls between pixel centres.
    init(_ g: Voxels, _ view: RailView, heading: Double, slope: Double = 0, smooth: Bool = false, fine: Bool = false) {
        let (lx, ly, lz) = (Double(g.nx), Double(g.ny), Double(g.nz))
        let (c, s) = (cos(heading), sin(heading)), (hx, hy) = (lx / 2, ly / 2)
        let lean = abs(slope) * hx
        var lo = SIMD2<Double>(repeating: .infinity), hi = SIMD2<Double>(repeating: -.infinity)
        let origin = view.project(.zero)
        for u in [-hx, hx] { for v in [-hy, hy] { for z in [min(0, -lean), lz + lean] {
            let p = view.project([u * c - v * s, u * s + v * c, z]) - origin
            lo = simd_min(lo, p); hi = simd_max(hi, p)
        } } }
        let (x0, y0) = (Int(floor(lo.x)) - 1, Int(floor(lo.y)) - 1), (x1, y1) = (Int(ceil(hi.x)) + 1, Int(ceil(hi.y)) + 1)
        let r = view.ray, zlo = min(0, -lean) - 0.5, tmax = lz + lean + 0.5
        let steps = Int(ceil((tmax - zlo) / 0.25 - 1e-9))
        typealias Hit = (m: UInt16, top: Bool, n: SIMD3<Double>, dd: Float)
        func cast(_ px: Int, _ py: Int, _ ox: Double = 0, _ oy: Double = 0) -> Hit? {
            let gxy = view.unproject(Double(px) + ox, Double(py) + oy)
            var prev = SIMD3<Int>(Int.min, Int.min, Int.min)
            for k in 0..<steps {
                let t = tmax - 0.25 * Double(k)
                let wx = gxy.x + t * r.x, wy = gxy.y + t * r.y, wz = t * r.z
                let u = wx * c + wy * s, v = -wx * s + wy * c, zl = wz - slope * u
                let cell = SIMD3(Int(floor(u + hx)), Int(floor(v + hy)), Int(floor(zl)))
                defer { prev = cell }
                guard cell.x >= 0, cell.x < g.nx, cell.y >= 0, cell.y < g.ny, cell.z >= 0, cell.z < g.nz else { continue }
                let m = g[cell.x, cell.y, cell.z]
                guard m > 0 else { continue }
                let first = k == 0
                let (dz, dyc, dxc) = (first ? false : cell.z != prev.z, first ? false : cell.y != prev.y, first ? false : cell.x != prev.x)
                let isTop = smooth || dz || first || !(dyc || dxc)
                var n = SIMD3<Double>.zero
                if isTop { n.z = 1 } else if dyc { n.y = Double((prev.y - cell.y).signum()) } else { n.x = Double((prev.x - cell.x).signum()) }
                // its depth as seen along the ray through the pixel's centre
                let at = SIMD3(gxy.x + t * r.x, gxy.y + t * r.y, t * r.z) - SIMD3(view.unproject(ox, oy), 0)
                return (m, isTop, [n.x * c - n.y * s, n.x * s + n.y * c, n.z], Float(view.depth(at)))
            }
            return nil
        }
        func add(_ px: Int, _ py: Int, _ h: Hit) {
            dx.append(Int16(px)); dy.append(Int16(py)); mat.append(h.m); top.append(h.top); normal.append(h.n); dd.append(h.dd)
        }
        guard fine else {
            for py in y0..<y1 { for px in x0..<x1 { if let h = cast(px, py) { add(px, py, h) } } }
            return
        }
        var pixels: [(px: Int, py: Int, hits: [Hit])] = [], seen = [Int](repeating: 0, count: RailArt.table.count + 1)
        for py in y0..<y1 { for px in x0..<x1 {
            let hits = [(-0.25, -0.25), (0.25, -0.25), (-0.25, 0.25), (0.25, 0.25)].compactMap { cast(px, py, $0.0, $0.1) }
            guard hits.count >= 2 else { continue }
            for h in hits { seen[Int(h.m)] += 1 }
            pixels.append((px, py, hits))
        } }
        for (px, py, hits) in pixels {
            var count = [UInt16: Int]()
            for h in hits { count[h.m, default: 0] += 1 }
            let most = count.values.max()!
            let pick = count.filter { $0.value == most }.keys.min { (seen[Int($0)], $0) < (seen[Int($1)], $1) }!
            add(px, py, hits.first { $0.m == pick }!)
        }
    }
}

/// The light a picture is drawn in: day or night, summer or snow, and the era's lamps.
struct RailLight {
    let night: Bool, winter: Bool
    let lamp: SIMD3<Float>
    static let window = RailArt.colour(0xFFAE54), headlight = RailArt.colour(0xFFD9A0)
    static let nightMul = SIMD3<Float>(0.25, 0.26, 0.36), nightAdd = SIMD3<Float>(18, 15, 34)
    static let shadow = SIMD3<Float>(0.80, 0.85, 0.92)

    init(night: Bool, winter: Bool, era: RailEra) {
        (self.night, self.winter) = (night, winter)
        lamp = RailArt.colour(era.look.lamp)
    }

    /// Top faces 1; sides by the Sun by day, a flat moonlight at night.
    func shade(_ n: SIMD3<Double>, _ view: RailView) -> Float {
        if night { return n.z > 0.5 ? 1 : 0.82 }
        let s = view.sun
        return Float((0.7 + 0.3 * max(0, dot(n, s))) / (0.7 + 0.3 * s.z))
    }

    /// A material's colour seen with this shade; snow lies on top faces of what takes it. `lit` says whether a
    /// window is lit tonight.
    func colour(_ m: UInt16, _ shade: Float, top: Bool, lit: Bool = true) -> SIMD3<Float> {
        let flags = RailArt.flags[Int(m)]
        var c = RailArt.rgb[Int(m)]
        if winter, flags.contains(.snowAll) || flags.contains(.snowTop) && top { c = RailArt.snowTone[Int(m)] }
        c *= shade
        if night {
            c = c * Self.nightMul + Self.nightAdd
            if flags.contains(.window), lit { c = Self.window * 0.92 }
            if flags.contains(.dome) { c = Self.window * 0.55 + c * 0.3 }
            if flags.contains(.headlight) { c = [255, 246, 220] }
            if flags.contains(.lamp) { c = simd_min(lamp * 1.1, SIMD3(repeating: 255)) }
        }
        return c
    }

    /// Ground colours by night.
    func ground(_ c: SIMD3<Float>) -> SIMD3<Float> { night ? c * Self.nightMul + Self.nightAdd : c }
}

/// A picture being built: colour and depth for every pixel.
struct Canvas {
    let w: Int, h: Int
    var rgb: [SIMD3<Float>], depth: [Float]

    init(w: Int, h: Int) {
        (self.w, self.h) = (w, h)
        rgb = Array(repeating: .zero, count: w * h)
        depth = Array(repeating: -1e9, count: w * h)
    }

    /// Plots where at least as near as what's there: the later of two at one depth wins.
    @inline(__always) mutating func put(_ x: Int, _ y: Int, _ c: SIMD3<Float>, _ d: Float) {
        guard x >= 0, x < w, y >= 0, y < h else { return }
        let i = y * w + x
        if d >= depth[i] - 1e-4 { rgb[i] = c; depth[i] = d }
    }

    /// A marched model with its foot at `at`, coloured in `light`.
    mutating func sprite(_ m: Marched, at p: SIMD3<Double>, _ view: RailView, _ light: RailLight, lit: Bool = true) {
        let q = view.project(p), ax = Int(floor(q.x)), ay = Int(floor(q.y))
        // depth as if the foot sat exactly on its pixel's ray, as the sprite was marched
        let base = Float(view.pixelDepth(ax, ay, p.z))
        for k in 0..<m.count {
            let shade = RailArt.flags[Int(m.mat[k])].contains(.flat) ? 0.92 : light.shade(m.normal[k], view)
            let c = light.colour(m.mat[k], shade, top: m.top[k], lit: lit)
            put(Int(m.dx[k]) + ax, Int(m.dy[k]) + ay, c, m.dd[k] + base)
        }
    }

    /// World points as single pixels, flat at their height, blended over what's there by `alpha`.
    mutating func points(_ ps: [SIMD3<Double>], _ c: SIMD3<Float>, _ view: RailView, eps: Double = 0.05, alpha: Float = 1) {
        for p in ps {
            let q = view.project(p), x = Int(floor(q.x)), y = Int(floor(q.y))
            guard x >= 0, x < w, y >= 0, y < h else { continue }
            let colour = alpha < 1 ? c * alpha + rgb[y * w + x] * (1 - alpha) : c
            put(x, y, colour, Float(view.pixelDepth(x, y, p.z) + eps))
        }
    }
}

/// Deterministic 0..<1 from integers, for anything that must come out the same in every view and light.
func hsh(_ keys: Int...) -> Double {
    var h: UInt64 = 0x9E37_79B9_7F4A_7C15
    for v in keys {
        h = (h ^ UInt64(UInt32(truncatingIfNeeded: v))) &* 0xBF58_476D_1CE4_E5B9
        h ^= h >> 29
    }
    return Double(h & 0xFF_FFFF) / Double(0x100_0000)
}

/// A seeded generator (SplitMix64) with the draws a layout needs: the same seed gives the same layout.
struct Dice {
    private var state: UInt64
    init(_ seed: Int) { state = UInt64(bitPattern: Int64(seed)) &* 0x9E37_79B9_7F4A_7C15 &+ 0x0123_4567_89AB_CDEF }
    private mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    /// From 0 up to, not including, 1.
    mutating func unit() -> Double { Double(next() >> 11) * 0x1p-53 }
    mutating func uniform(_ low: Double, _ high: Double) -> Double { low + (high - low) * unit() }
    /// 0 up to, not including, n.
    mutating func below(_ n: Int) -> Int { Int(unit() * Double(n)) }
    mutating func pick<T>(_ xs: [T]) -> T { xs[below(xs.count)] }
    mutating func chance(_ p: Double) -> Bool { unit() < p }
}

// MARK: - Scenery models (voxels: x along, y across, z up)

enum Models {
    private static func m(_ name: String) -> UInt16 { RailArt.mat(name) }

    /// A gabled house, its ridge along x; windows along both long walls, a door on the -y side (the street's).
    static func house(_ w: Int, _ d: Int, wall: String, roof: String, seed: Int, walls: Int = 3) -> Voxels {
        var g = Voxels(w, d, walls + d / 2 + 2)
        g.fill(0..<w, 0..<d, 0..<walls, m(wall))
        for x in 1..<(w - 1) where x % 2 == 1 && hsh(seed, x) < 0.8 {
            g[x, 0, 1] = m("house_win"); g[x, d - 1, 1] = m("house_win")
        }
        g[w / 2, 0, 0] = m("door")
        for k in 0...(d / 2) where Double(k) <= Double(d - 1) / 2 { g.fill(0..<w, k..<(d - k), (walls + k)..<(walls + k + 1), m(roof)) }
        let cx = hsh(seed, 99) < 0.5 ? 1 : w - 2, top = walls + (d - 1) / 2
        g.fill(cx..<(cx + 1), (d / 2)..<(d / 2 + 1), walls..<(top + 2), m("chimney"))
        return g
    }

    /// A Southern Pacific style wooden combination depot: yellow walls, brown trim, a green hipped roof, a bay
    /// window toward the track (+y).
    static func depot() -> Voxels {
        let (w, d) = (16, 7)
        var g = Voxels(w, d, 7)
        g.fill(0..<w, 0..<6, 0..<3, m("sp_wall"))
        g.fill(0..<w, 0..<6, 0..<1, m("sp_trim"))
        g.fill(0..<1, 0..<6, 0..<3, m("sp_trim")); g.fill((w - 1)..<w, 0..<6, 0..<3, m("sp_trim"))
        g.fill(6..<10, 6..<7, 0..<3, m("sp_wall"))
        g.fill(7..<9, 6..<7, 1..<2, m("house_win"))
        for x in [2, 4, 11, 13] { g[x, 0, 1] = m("house_win"); g[x, 5, 1] = m("house_win") }
        g[5, 0, 0] = m("door"); g[10, 5, 0] = m("door")
        for k in 0..<4 { g.fill(k..<(w - k), k..<(d - k), (3 + k)..<(4 + k), m("sp_roof")) }
        return g
    }

    static func brickStation() -> Voxels {
        let (w, d) = (18, 7)
        var g = Voxels(w, d, 6)
        g.fill(0..<w, 0..<d, 0..<4, m("brick"))
        g.fill(0..<w, 0..<d, 0..<1, m("brick_dk"))
        for x in stride(from: 2, to: w - 2, by: 3) { g.fill(x..<(x + 1), 0..<1, 1..<3, m("house_win")); g.fill(x..<(x + 1), (d - 1)..<d, 1..<3, m("house_win")) }
        g.fill((w / 2)..<(w / 2 + 1), (d - 1)..<d, 0..<2, m("door"))
        g.fill(0..<w, 0..<d, 4..<5, m("slate"))
        g.fill(2..<(w - 2), 2..<(d - 2), 5..<6, m("slate"))
        return g
    }

    static func canopy(_ length: Int) -> Voxels {
        var g = Voxels(length, 5, 6)
        for x in stride(from: 1, to: length - 1, by: 6) { g.fill(x..<(x + 1), 2..<3, 0..<5, m("steel")) }
        g.fill(0..<length, 0..<5, 5..<6, m("canopy"))
        return g
    }

    /// 4 wide, its edge facing the track (+y).
    static func platform(_ length: Int) -> Voxels {
        var g = Voxels(length, 4, 1)
        g.fill(0..<length, 0..<4, 0..<1, m("platform"))
        g.fill(0..<length, 3..<4, 0..<1, m("platform_edge"))
        return g
    }

    static func waterTank() -> Voxels {
        var g = Voxels(7, 7, 12)
        for (x, y) in [(1, 1), (1, 5), (5, 1), (5, 5)] { g.fill(x..<(x + 1), y..<(y + 1), 0..<5, m("timber")) }
        for x in 0..<7 { for y in 0..<7 {
            let r = hypot(Double(x - 3), Double(y - 3))
            if r <= 3.2 { g.fill(x..<(x + 1), y..<(y + 1), 5..<10, m("wood_tank")); g[x, y, 6] = m("wood_tank_dk"); g[x, y, 8] = m("wood_tank_dk") }
            if r <= 2.4 { g[x, y, 10] = m("tank_roof") }
            if r <= 1.2 { g[x, y, 11] = m("tank_roof") }
        } }
        g[6, 3, 7] = m("timber") // the spout
        return g
    }

    /// A broadleaf tree on the season's day: a dark trunk forking into 3 or 4 branches up to a light, ragged crown
    /// of fine twigs (what shows when it's bare), with the leaves that are out laid over it.
    static func tree(seed: Int, season: RailSeason) -> Voxels {
        var rng = Dice(seed)
        let r = rng.uniform(2.2, 3.4), rz = rng.uniform(2.0, 2.8), c = rng.uniform(3.5, 5.0)
        let n = Int(2 * r) + 3, nz = Int(c + rz) + 2, mid = n / 2
        var g = Voxels(n, n, nz), crown: [(Int, Int, Int)] = []
        for x in 0..<n { for y in 0..<n { for z in 0..<nz {
            let dx = Double(x - mid) / r, dy = Double(y - mid) / r, dz = (Double(z) + 0.5 - c) / rz
            let e = dx * dx + dy * dy + dz * dz
            guard e <= 1 + 0.25 * (hsh(seed, x, y, z) - 0.5) else { continue }
            crown.append((x, y, z))
            if e > 0.5, hsh(seed, x, y, z, 4) < (Double(z) + 0.5 > c ? 0.65 : 0.4) { g[x, y, z] = m("twig_lt") }
        } } }
        let fork = max(2, Int(c - rz * 0.6))
        g.fill(mid..<(mid + 1), mid..<(mid + 1), 0..<(fork + 1), m("twig"))
        for k in 0..<(3 + rng.below(2)) {
            let a = rng.uniform(0, 2 * .pi) + Double(k) * 1.7
            for i in 0..<6 {
                let t = 0.15 + 0.8 * Double(i) / 5
                let x = Int((Double(mid) + cos(a) * r * 0.9 * t).rounded()), y = Int((Double(mid) + sin(a) * r * 0.9 * t).rounded())
                let z = Int((Double(fork) + (c + rz * 0.5 - Double(fork)) * t).rounded())
                if x >= 0, x < n, y >= 0, y < n, z >= 0, z < nz { g[x, y, z] = m("twig") }
            }
        }
        for (x, y, z) in crown {
            guard var leaf = season.leaf(seed: seed, x, y, z, nz: nz) else { continue }
            if leaf == "green" {
                let t = hsh(seed, x, y, z, 3)
                leaf = Double(z) + 0.5 > c + 0.4 * rz && t < 0.6 ? "leaf_lt" : t < 0.25 ? "leaf_dk" : "leaf"
            }
            g[x, y, z] = m(leaf)
        }
        return g
    }

    static func conifer(seed: Int, season: RailSeason) -> Voxels {
        let (lit, dark) = season.conifer
        var rng = Dice(seed)
        let height = 7 + rng.below(5), rb = rng.uniform(2.2, 3.0)
        let n = Int(2 * rb) + 3, mid = n / 2
        var g = Voxels(n, n, height)
        g[mid, mid, 0] = m("trunk")
        for z in 1..<height {
            let rr = rb * (1 - Double(z - 1) / Double(height - 1)) + 0.35
            for x in 0..<n { for y in 0..<n where hypot(Double(x - mid), Double(y - mid)) <= rr {
                g[x, y, z] = m(hsh(seed, x, y, z) < 0.3 ? dark : lit)
            } }
        }
        return g
    }

    /// A signal: a semaphore's tall post, a searchlight's two-high head, or a colour light's three lamps.
    static func signal(_ kind: EraLook.Signals) -> Voxels {
        switch kind {
        case .semaphore: return post(8)
        case .searchlight: return post(5, head: "sig_head")
        case .colour:
            var g = Voxels(1, 1, 8)
            g.fill(0..<1, 0..<1, 0..<5, m("post")); g.fill(0..<1, 0..<1, 5..<8, m("cl_head"))
            return g
        }
    }

    /// A freight house's timber dock, 4 wide, at car-floor height.
    static func dock(_ length: Int) -> Voxels {
        var g = Voxels(length, 4, 2)
        g.fill(0..<length, 0..<4, 0..<2, m("dock"))
        return g
    }

    /// A long, low freight house: brown board walls, a door to every car length on both sides, a low gable.
    static func freightHouse() -> Voxels {
        let (w, d) = (24, 8)
        var g = Voxels(w, d, 6)
        g.fill(0..<w, 0..<d, 0..<4, m("freight_wall"))
        for x in stride(from: 2, to: w - 2, by: 4) { for y in [0, d - 1] { g.fill(x..<(x + 2), y..<(y + 1), 0..<3, m("freight_door")) } }
        g.fill(0..<w, 0..<d, 4..<5, m("roof_brown"))
        g.fill(0..<w, 2..<(d - 2), 5..<6, m("roof_brown"))
        return g
    }

    /// Today's platform shelter: glass sides, a flat dark roof.
    static func shelter() -> Voxels {
        var g = Voxels(7, 3, 4)
        g.fill(0..<7, 0..<1, 0..<3, m("shelter_glass"))
        for x in [0, 6] { g.fill(x..<(x + 1), 0..<3, 0..<3, m("shelter_glass")) }
        g.fill(0..<7, 0..<3, 3..<4, m("shelter_roof"))
        return g
    }

    /// A concrete coaling tower (compressed: real ones stand 100 ft), its chutes reaching over the track (+y) above
    /// the trains, and a darker band where the bins are.
    static func coalingTower() -> Voxels {
        var g = Voxels(8, 10, 16)
        g.fill(0..<8, 0..<6, 0..<15, m("conc_tower"))
        g.fill(0..<8, 0..<6, 9..<11, m("conc_dark"))
        g.fill(1..<7, 1..<5, 15..<16, m("conc_dark"))
        for x in [2, 5] { g.fill(x..<(x + 1), 6..<10, 9..<10, m("steel")) }
        return g
    }

    /// A concrete grain elevator: a row of four bins and a taller headhouse at one end (heights compressed).
    static func elevator() -> Voxels {
        var g = Voxels(22, 6, 22)
        for b in 0..<4 {
            let cx = 2.5 + Double(b) * 5
            for x in (b * 5)..<(b * 5 + 5) { for y in 0..<6 where hypot(Double(x) + 0.5 - cx, Double(y) + 0.5 - 3) <= 2.6 {
                g.fill(x..<(x + 1), y..<(y + 1), 0..<16, m("elevator"))
            } }
        }
        g.fill(0..<22, 1..<5, 15..<16, m("elevator_dk")) // the gallery along the top
        g.fill(17..<22, 0..<6, 0..<21, m("elevator"))
        g.fill(17..<22, 0..<6, 21..<22, m("elevator_dk"))
        for z in [4, 9, 14, 19] { g[19, 5, z] = m("house_win") }
        return g
    }

    /// A two-storey interlocking tower: brick below, the operator's room above with windows all round, a hipped roof.
    static func interlockingTower() -> Voxels {
        var g = Voxels(7, 6, 10)
        g.fill(0..<7, 0..<6, 0..<7, m("tower_wall"))
        for x in [1, 3, 5] { for y in [0, 5] { g.fill(x..<(x + 1), y..<(y + 1), 4..<6, m("house_win")) } }
        for y in [1, 3, 4] { for x in [0, 6] { g.fill(x..<(x + 1), y..<(y + 1), 4..<6, m("house_win")) } }
        g.fill(3..<4, 0..<1, 0..<2, m("door"))
        for k in 0..<3 { g.fill(k..<(7 - k), k..<(6 - k), (7 + k)..<(8 + k), m("roof_black")) }
        return g
    }

    /// Today's concrete silos: three tall bins in a row and a leg up the middle.
    static func silos() -> Voxels {
        var g = Voxels(21, 7, 18)
        for b in 0..<3 {
            let cx = 3.5 + Double(b) * 7
            for x in (b * 7)..<(b * 7 + 7) { for y in 0..<7 {
                let r = hypot(Double(x) + 0.5 - cx, Double(y) + 0.5 - 3.5)
                if r <= 3.5 { g.fill(x..<(x + 1), y..<(y + 1), 0..<14, m("silo")) }
                if r <= 2.4 { g[x, y, 14] = m("silo_dk") }
            } }
        }
        g.fill(10..<12, 3..<5, 14..<18, m("silo_dk"))
        return g
    }

    /// A British signal box: a brick base, a glazed timber top with windows all round, a hipped slate roof (6 x 4).
    static func signalBox() -> Voxels {
        var g = Voxels(6, 4, 7)
        g.fill(0..<6, 0..<4, 0..<3, m("brick"))
        g.fill(0..<6, 0..<4, 3..<5, m("box_glass"))
        for x in [0, 5] { for y in [0, 3] { g.fill(x..<(x + 1), y..<(y + 1), 3..<5, m("timber")) } }
        g.fill(0..<6, 0..<4, 5..<6, m("slate"))
        g.fill(1..<5, 1..<3, 6..<7, m("slate"))
        return g
    }

    /// A small British country station: brick, a hipped slate roof, windows to the platform (+y), 12 x 5.
    static func britishStation() -> Voxels {
        let (w, d) = (12, 5)
        var g = Voxels(w, d, 6)
        g.fill(0..<w, 0..<d, 0..<3, m("brick"))
        for x in [2, 4, 7, 9] { g[x, 0, 1] = m("house_win"); g[x, d - 1, 1] = m("house_win") }
        g.fill(6..<7, (d - 1)..<d, 0..<2, m("door"))
        for k in 0..<3 { g.fill(k..<(w - k), k..<(d - k), (3 + k)..<(4 + k), m("slate")) }
        return g
    }

    /// A platform canopy on posts, its valance in light stone with dark stone posts (the GWR's colours).
    static func britishCanopy(_ length: Int) -> Voxels {
        var g = Voxels(length, 5, 6)
        for x in stride(from: 2, to: length - 1, by: 6) { g.fill(x..<(x + 1), 2..<3, 0..<5, m("stone_dk")) }
        g.fill(0..<length, 0..<5, 5..<6, m("slate"))
        for y in [0, 4] { for x in stride(from: 0, to: length, by: 2) { g[x, y, 4] = m("stone_lt") } } // the valance's cut edge
        return g
    }

    /// The white post a British crossing gate hangs on.
    static func gatepost() -> Voxels {
        var g = Voxels(1, 1, 3)
        g.fill(0..<1, 0..<1, 0..<3, m("post_white"))
        return g
    }

    /// A British half-barrier crossing's lights: a post with a head of lamps across the road (+y).
    static func lightMast() -> Voxels {
        var g = Voxels(1, 3, 5)
        g.fill(0..<1, 1..<2, 0..<4, m("post"))
        g.fill(0..<1, 0..<3, 3..<4, m("sig_head"))
        return g
    }

    /// A hedgerow: 2 wide, 2 high, darker underneath.
    static func hedge(_ length: Int, season: RailSeason) -> Voxels {
        var g = Voxels(length, 2, 2)
        g.fill(0..<length, 0..<2, 0..<1, m("hedge_dk"))
        g.fill(0..<length, 0..<2, 1..<2, m(season.kind == .winter ? "hedge_w" : "hedge"))
        return g
    }

    static func pole() -> Voxels {
        var g = Voxels(3, 1, 10)
        g.fill(1..<2, 0..<1, 0..<10, m("pole"))
        g.fill(0..<3, 0..<1, 9..<10, m("crossarm"))
        return g
    }

    static func lamp() -> Voxels {
        var g = Voxels(1, 1, 7)
        g.fill(0..<1, 0..<1, 0..<6, m("post"))
        g[0, 0, 6] = m("lamp")
        return g
    }

    /// A signal post `h` high, with a head on top if it has one.
    static func post(_ h: Int, head: String? = nil) -> Voxels {
        var g = Voxels(1, head == nil ? 1 : 2, h + (head == nil ? 0 : 2))
        g.fill(0..<1, 0..<1, 0..<h, m("post"))
        if let head { g.fill(0..<1, 0..<2, h..<(h + 2), m(head)) }
        return g
    }

    /// A crossbuck, edge-on from the track: a post and a white X across the road (y).
    static func crossbuck() -> Voxels {
        var g = Voxels(1, 5, 7)
        g.fill(0..<1, 2..<3, 0..<6, m("post"))
        for y in 0..<5 { for z in 2..<7 where abs(y - 2) == abs(z - 4) { g[0, y, z] = m("post_white") } }
        return g
    }

    static func flasher() -> Voxels {
        var g = crossbuck()
        g[0, 1, 2] = m("sig_head"); g[0, 3, 2] = m("sig_head")
        return g
    }
}
