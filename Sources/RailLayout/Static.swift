import Foundation
import simd

/// The picture under the trains, by day and by night: ground, track, shadows or lamp pools, and every standing
/// thing, with the depth of each pixel for the trains to be drawn against. Rows from the top.
struct Statics {
    var day: [SIMD3<Float>], night: [SIMD3<Float>], depth: [Float]

    static let snowField: [UInt32] = [0xF4F6FA, 0xECF0F7, 0xF7F9FC]

    init(_ lay: Layout, _ sc: Scenery, era: RailEra, season: RailSeason) {
        let view = lay.view, (w, h) = (view.w, view.h), winter = season.snow
        let dayLight = RailLight(night: false, winter: winter, era: era), nightLight = RailLight(night: true, winter: winter, era: era)
        var base = Canvas(w: w, h: h)
        let ground = (0..<(w * h)).map { view.ground($0 % w, $0 / w) }
        base.rgb = Self.groundColours(lay, sc, ground, season: season)
        for y in 0..<h { for x in 0..<w { base.depth[y * w + x] = Float(view.pixelDepth(x, y, 0)) } }

        var things = sc.things + Scenery.bridges(lay, season: season)
        for hill in sc.hills {
            things.append(Thing(grid: Scenery.hillModel(hill, lay.loops[hill.loop], sun: view.sun, season: season), pos: hill.c, kind: .hill))
        }
        for i in things.indices where things[i].base == nil { things[i].base = (sc.hills.map { Scenery.hillHeight($0, things[i].pos) }.max() ?? 1) - 1 }
        // every loop, the branch and the crossovers, without their switch rails at the turnouts (drawn as they're set)
        var gaps: [Int: [(Double, Double)]] = [:]
        if let br = lay.branch { gaps[br.loop, default: []] += [(br.sD, br.sD + switchLength), (br.sA - switchLength, br.sA)] }
        for x in lay.links { gaps[x.a, default: []].append((x.sa, x.sa + switchLength)); gaps[x.b, default: []].append((x.sb - switchLength, x.sb)) }
        for (li, lp) in lay.loops.enumerated() {
            let g = gaps[li] ?? []
            Self.stampTrack(&base, lp.P, lp.T, lp.Z, sc.roads, view, era: era, winter: winter) { k in g.contains { wrap(lp.S[k] - $0.0, lp.L) <= $0.1 - $0.0 } }
        }
        var paths: [(RailPath, [(Double, Double)])] = lay.links.map { ($0.path, [(0, switchLength), ($0.path.L - switchLength, $0.path.L)]) }
        if let br = lay.branch {
            paths += [(br.out, [(0, switchLength), (br.curve - switchLength, br.curve)]), (br.inn, [(br.straight, br.straight + switchLength), (br.inn.L - switchLength, br.inn.L)])]
        }
        for (path, g) in paths {
            Self.stampTrack(&base, path.P, path.T, [Double](repeating: 0, count: path.P.count), sc.roads, view, era: era, winter: winter) { k in g.contains { $0.0 <= path.S[k] && path.S[k] <= $0.1 } }
        }

        var day = base, night = base
        night.rgb = base.rgb.map(nightLight.ground)
        let shade = Self.shadows(things, view, ground)
        for i in day.rgb.indices where shade[i] && day.depth[i] <= Float(view.pixelDepth(i % w, i / w, 0)) + 0.1 { day.rgb[i] *= RailLight.shadow } // on the ground only
        var pools = [Float](repeating: 0, count: w * h)
        for q in sc.lamps { Self.pool(&pools, q, view) }
        for i in pools.indices where pools[i] > 0 { night.rgb[i] += pools[i] * nightLight.lamp * 0.55 }
        for t in things {
            let m = Marched(t.grid, view, heading: t.heading, smooth: t.kind == .hill), at = SIMD3(t.pos.x, t.pos.y, t.base ?? 0)
            day.sprite(m, at: at, view, dayLight, lit: t.lit)
            night.sprite(m, at: at, view, nightLight, lit: t.lit)
        }
        for (a, b) in zip(sc.poles, sc.poles.dropFirst()) { // the pole line's wires
            let n = Int(length(b - a) * 2) + 2
            let pts = (0..<n).map { k -> SIMD3<Double> in
                let t = Double(k) / Double(n - 1), p = a + (b - a) * t
                return [p.x, p.y, 9.6 - 0.8 * sin(t * .pi)]
            }
            day.points(pts, [40, 40, 44], view, eps: 0, alpha: 0.45)
            night.points(pts, [20, 22, 30], view, eps: 0, alpha: 0.45)
        }
        (self.day, self.night, depth) = (day.rgb, night.rgb, day.depth)
    }

    /// Grass in the season's colours or snow, a pond (ice in winter), and roads, by day.
    static func groundColours(_ lay: Layout, _ sc: Scenery, _ ground: [SIMD2<Double>], season: RailSeason) -> [SIMD3<Float>] {
        let view = lay.view, w = view.w, winter = season.snow
        let tones = winter ? snowField.map(RailArt.colour) : season.grass
        var col = ground.map { p -> SIMD3<Float> in
            let n = sin(p.x / 9.1 + sin(p.y / 13.7)) * cos(p.y / 8.3 - p.x / 17.0) + 0.5 * sin((p.x + p.y) / 5.3)
            return n > 0.55 ? tones[1] : n < -0.75 ? tones[2] : tones[0]
        }
        if let pond = sc.pond {
            for (i, p) in ground.enumerated() {
                let d = length(p - pond.c)
                guard d < pond.r * 1.2 + 2 else { continue }
                let a = atan2(p.y - pond.c.y, p.x - pond.c.x), s = Double(pond.seed)
                let rr = pond.r * (1 + 0.12 * sin(3 * a + s) + 0.07 * sin(5 * a - s))
                if winter {
                    if d < rr { col[i] = RailArt.colour(0xBFD3E0) }
                    if d < rr - 2, sin(p.x / 4.1 + cos(p.y / 3.3)) * cos(p.y / 3.7 - p.x / 6.1) > 0.35 { col[i] = RailArt.colour(0xF4F6FA) }
                } else {
                    if d < rr + 1.2 { col[i] = tones[0] * 0.82 }
                    if d < rr { col[i] = season.pond }
                    if d < rr - 3.5 { col[i] = season.pond * 0.9 }
                    let g = sin(floor(p.x) * 12.9898 + floor(p.y) * 78.233) * 43758.5453
                    if d < rr - 2, g - floor(g) > 0.965 { col[i] = RailArt.colour(0x6E9AB4) }
                }
            }
        }
        // roads, worked out only near each stretch of one: asphalt, and at its edges the main road's gravel
        // shoulder or a street's kerbs (snow banks in winter), every road's edges before any asphalt so junctions
        // stay clear
        var asphalt = [Bool](repeating: false, count: ground.count), edge = [UInt32?](repeating: nil, count: ground.count)
        for (rd, half) in zip(sc.roads, sc.roadHalf) {
            let rim = half > 3 ? 1.0 : 0.8, rimColour: UInt32 = winter ? 0xC6D2E4 : half > 3 ? 0x8C8270 : 0xA8A49A
            for (a, b) in zip(rd, rd.dropFirst()) {
                let (lo, hi) = (simd_min(a, b) - 5, simd_max(a, b) + 5)
                var (x0, y0, x1, y1) = (Int.max, Int.max, Int.min, Int.min)
                for c in [lo, hi, SIMD2(lo.x, hi.y), SIMD2(hi.x, lo.y)] {
                    let q = view.project([c.x, c.y, 0])
                    (x0, y0, x1, y1) = (min(x0, Int(floor(q.x))), min(y0, Int(floor(q.y))), max(x1, Int(ceil(q.x))), max(y1, Int(ceil(q.y))))
                }
                let ab = b - a, l2 = max(dot(ab, ab), 1e-9)
                for y in clamped(y0, y1 + 1, view.h) { for x in clamped(x0, x1 + 1, w) {
                    let i = y * w + x, p = ground[i], t = min(max(dot(p - a, ab) / l2, 0), 1), d = length(p - a - t * ab)
                    if d < half { asphalt[i] = true } else if d < half + rim, edge[i] == nil { edge[i] = rimColour }
                } }
            }
        }
        for i in col.indices {
            if asphalt[i] { col[i] = RailArt.colour(winter ? 0x6E6C68 : 0x57575A) } else if let e = edge[i] { col[i] = RailArt.colour(e) }
        }
        return col
    }

    /// A track's samples P (tangents T, heights Z): a bed 7 units wide, a tie every 2 units, rails a unit either side
    /// of the centreline (gauge 2.35 pixels at 2 ft a pixel) but where `bare` (at a turnout, drawn as it's set), and
    /// planks for the bed and ties where a road crosses.
    static func stampTrack(_ canvas: inout Canvas, _ P: [SIMD2<Double>], _ T: [SIMD2<Double>], _ Z: [Double], _ roads: [[SIMD2<Double>]],
                           _ view: RailView, era: RailEra, winter: Bool, bare: (Int) -> Bool = { _ in false }) {
        let snow = RailArt.colour(0xD8DCE0)
        let look = era.look
        let bed = winter ? snow : RailArt.colour(look.ballast)
        let tie = (winter ? snow : RailArt.colour(look.tie)) * 0.65 + bed * 0.35
        // planks where a road crosses, or today's concrete panels 8 ft long with dark joints between
        let rail = RailArt.colour(winter ? 0x4A4642 : 0xA8A8A8), planks = RailArt.colour(look.panels?.0 ?? 0x5A4632)
        let joint = look.panels.map { RailArt.colour($0.1) }
        let onRoad = P.map { p in roads.contains { rd in zip(rd, rd.dropFirst()).contains { a, b in
            let ab = b - a, t = min(max(dot(p - a, ab) / max(dot(ab, ab), 1e-9), 0), 1)
            return length(p - a - t * ab) < 3.6
        } } }
        // Within one pixel the track's nearest surface wins, and on it the rail over the tie over the bed: on a ramp
        // a pixel spans a little height, which would otherwise let the bed bury the rails.
        var near = [Double](repeating: -.infinity, count: canvas.w * canvas.h), marks: [(i: Int, d: Double, layer: Double, c: SIMD3<Float>)] = []
        func stamp(_ offsets: [Double], _ layer: Double, _ which: (Int) -> SIMD3<Float>?) {
            for i in P.indices {
                guard let c = which(i) else { continue }
                let nrm = SIMD2(-T[i].y, T[i].x)
                for o in offsets {
                    let q = P[i] + o * nrm, s = view.project([q.x, q.y, Z[i]]), x = Int(floor(s.x)), y = Int(floor(s.y))
                    guard x >= 0, x < canvas.w, y >= 0, y < canvas.h else { continue }
                    let k = y * canvas.w + x, d = view.pixelDepth(x, y, Z[i])
                    near[k] = max(near[k], d)
                    marks.append((k, d, layer, c))
                }
            }
        }
        let wide = stride(from: -3.5, through: 3.5, by: 0.5).map { $0 }, ties = stride(from: -2.5, through: 2.5, by: 0.5).map { $0 }
        stamp(wide, 0) { onRoad[$0] ? nil : bed }
        stamp(wide, 1) { onRoad[$0] ? planks : nil }
        if let joint { stamp(wide, 1.5) { $0 % 16 == 0 && onRoad[$0] ? joint : nil } }
        stamp(ties, 2) { $0 % 8 == 0 && !onRoad[$0] ? tie : nil }
        let bare = P.indices.map(bare)
        stamp([-1, 1], 3) { bare[$0] ? nil : rail }
        var pick = [(layer: Double, d: Double, c: SIMD3<Float>)?](repeating: nil, count: near.count)
        for m in marks where m.d >= near[m.i] - 0.6 {
            if let p = pick[m.i], (p.layer, p.d) > (m.layer, m.d) { continue }
            pick[m.i] = (m.layer, m.d, m.c)
        }
        for (k, p) in pick.enumerated() { if let p { canvas.put(k % canvas.w, k / canvas.w, p.c, Float(near[k] + 0.01 * (p.layer + 1))) } }
    }

    /// Ground points the Sun can't see: every voxel of every standing thing dropped along the Sun's rays onto a
    /// 1-unit raster, gaps of a cell filled.
    static func shadows(_ things: [Thing], _ view: RailView, _ ground: [SIMD2<Double>]) -> [Bool] {
        let s = view.sun
        let lo = ground.reduce(SIMD2(repeating: Double.infinity), simd_min), hi = ground.reduce(SIMD2(repeating: -Double.infinity), simd_max)
        let (x0, y0) = (floor(lo.x) - 2, floor(lo.y) - 2), nx = Int(ceil(hi.x - x0)) + 4, ny = Int(ceil(hi.y - y0)) + 4
        var R = [Bool](repeating: false, count: nx * ny)
        for t in things {
            let g = t.grid, (c, sn) = (cos(t.heading), sin(t.heading)), base = t.base ?? 0
            for z in 0..<g.nz { for y in 0..<g.ny { for x in 0..<g.nx where g[x, y, z] > 0 {
                let u = Double(x) + 0.5 - Double(g.nx) / 2, v = Double(y) + 0.5 - Double(g.ny) / 2, wz = Double(z) + 0.5 + base
                let gx = t.pos.x + u * c - v * sn - wz * s.x / s.z, gy = t.pos.y + u * sn + v * c - wz * s.y / s.z
                let (i, j) = (Int(floor(gy - y0)), Int(floor(gx - x0)))
                if i >= 0, i < ny, j >= 0, j < nx { R[i * nx + j] = true }
            } } }
        }
        func at(_ i: Int, _ j: Int) -> Bool { R[((i % ny + ny) % ny) * nx + (j % nx + nx) % nx] }
        var filled = R
        for i in 0..<ny { for j in 0..<nx where !R[i * nx + j] { filled[i * nx + j] = at(i - 1, j) && at(i + 1, j) || at(i, j - 1) && at(i, j + 1) } }
        return ground.map { p in
            let (i, j) = (min(max(Int(floor(p.y - y0)), 0), ny - 1), min(max(Int(floor(p.x - x0)), 0), nx - 1))
            return filled[i * nx + j]
        }
    }

    /// A lamp's pool of light on the ground at night, in three rings: the brighter where two meet.
    static func pool(_ pools: inout [Float], _ q: SIMD2<Double>, _ view: RailView) {
        let c = view.project([q.x, q.y, 0])
        for y in clamped(Int(c.y) - 12, Int(c.y) + 12, view.h) { for x in clamped(Int(c.x) - 22, Int(c.x) + 22, view.w) {
            let d = length(view.ground(x, y) - q)
            let k: Float = d < 3.5 ? 0.55 : d < 6.5 ? 0.32 : d < 9.5 ? 0.14 : 0
            pools[y * view.w + x] = max(pools[y * view.w + x], k)
        } }
    }
}

/// lo..<hi, kept within 0..<n.
func clamped(_ lo: Int, _ hi: Int, _ n: Int) -> Range<Int> { let a = max(lo, 0), b = min(hi, n); return a < b ? a..<b : 0..<0 }
