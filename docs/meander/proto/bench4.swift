// Meander's core in Swift, round 4, to time it: the river with a width that varies along it, lakes kept as polylines
// and drawn by the river's own distance routine into one water field, a hollow field, banks drawn from the centreline
// subdivided along its curve, and the launch history made of a cheap distant past then T 60 as the live river runs.
// A sketch for timing, checked against the Python prototype by eye (it writes its texture out); not the scene.
// swiftc -O bench4.swift -o bench4 && ./bench4
import Foundation
setvbuf(stdout, nil, _IOLBF, 0)

struct SplitMix { // any fixed generator will do here
    var s: UInt64
    mutating func unit() -> Float {
        s &+= 0x9E3779B97F4A7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return Float((z ^ (z >> 31)) >> 40) / Float(1 << 24)
    }
    mutating func normal() -> Float { (unit() + unit() + unit() + unit() - 2) * 1.732 }
}

func smooth(_ t: Float) -> Float { let u = max(0, min(1, t)); return u * u * (3 - 2 * u) }

/// A cut-off loop: its nodes and half-widths as they were, when it was cut off, and when each end became an end.
struct Lake { var x: [Float], y: [Float], h: [Float], born: Float, a: Float, b: Float }

final class Meander {
    // lengths are in channel widths, time in T (the prototype's units)
    let sx: Float, sy: Float, tex: Float
    let pad: Float = 10, alpha: Float = 0.73, crdist: Float = 1.04, far: Float = 9, lakeLife: Float = 16
    var ds: Float
    var L: Float { sx + 2 * pad }
    var x: [Float] = [], y: [Float] = [], hw: [Float] = []
    var t: Float = 0, cuts = 0, steps = 0 // ponytail: a Float clock is fine for a timing run; the scene's must be a Double, rebased
    let tw: Int, th: Int
    var stamp: [Float], hollow: [Float], live: [Float], lakeField: [Float], scratch: [Float]
    var touched: [Int32] = [], before: [Int32] = [], lakeTouched: [Int32] = []
    var pixels: [UInt8] // stamp in 16 bits, then the water field, then the hollow field
    var lakes: [Lake] = []
    var egrid: [Float] = [], ecols = 0, erows = 0, ecell: Float = 8
    var wallTable: [Float] = [] // how far each wall stands in, along the valley: 256 entries for the top, 256 for the bottom
    var bandTexels = 0, lakeTexels = 0

    init(seed: UInt64, sx: Float, sy: Float, tex: Float, ds: Float) {
        self.sx = sx; self.sy = sy; self.tex = tex; self.ds = ds
        tw = Int((sx * tex).rounded()); th = Int((sy * tex).rounded())
        stamp = Array(repeating: -1e9, count: tw * th)
        hollow = Array(repeating: 1, count: tw * th)
        live = Array(repeating: far, count: tw * th)
        lakeField = Array(repeating: far, count: tw * th)
        scratch = Array(repeating: .infinity, count: tw * th)
        pixels = Array(repeating: 255, count: tw * th * 4)
        var rng = SplitMix(s: seed)
        let n = Int((L / ds).rounded())
        var phase: [Float] = [], amp: [Float] = []
        for k in 1..<40 { phase.append(rng.unit() * 2 * .pi); amp.append(rng.normal() * 0.25 / Float(k).squareRoot()) }
        for i in 0..<n {
            x.append(-pad + L * Float(i) / Float(n))
            var v: Float = sy / 2
            for k in 1..<40 { v += amp[k - 1] * sin(2 * .pi * Float(k) * Float(i) / Float(n) + phase[k - 1]) }
            y.append(v); hw.append(0.5)
        }
        ecols = Int((L / 8).rounded()); ecell = L / Float(ecols); erows = Int(sy / ecell) + 3
        for _ in 0..<ecols * erows { egrid.append(rng.normal()) }
        for _ in 0..<2 {
            var a: [Float] = [], p: [Float] = []
            for k in 2..<8 { a.append(rng.normal() / Float(k).squareRoot()); p.append(rng.unit() * 2 * .pi) }
            for i in 0..<256 {
                var wave: Float = 0
                for k in 2..<8 { wave += a[k - 2] * sin(2 * .pi * Float(k) * Float(i) / 256 + p[k - 2]) }
                wallTable.append(2.5 * (1 + tanh(wave)))
            }
        }
    }

    /// How easily the bank at a point erodes: a smooth random field, periodic along the valley.
    func erodibility(_ px: Float, _ py: Float) -> Float {
        var gx = (px + pad) / ecell; gx -= (gx / Float(ecols)).rounded(.down) * Float(ecols)
        let gy = max(0, min(Float(erows) - 1.001, py / ecell))
        let ix = min(Int(gx), ecols - 1), iy = Int(gy), jx = (ix + 1) % ecols, fx = gx - Float(ix), fy = gy - Float(iy)
        let v = (egrid[iy * ecols + ix] * (1 - fx) + egrid[iy * ecols + jx] * fx) * (1 - fy)
            + (egrid[(iy + 1) * ecols + ix] * (1 - fx) + egrid[(iy + 1) * ecols + jx] * fx) * fy
        return exp(0.5 * v)
    }

    /// One step of Howard & Knutson's migration, the valley walls, and the width easing toward 0.7 W on straight
    /// reaches and 1.5 W round the tightest bends.
    func migrate(_ eps: Float) {
        let n = x.count, L = L, yc = sy / 2, cap = 1.25 * eps, ease = 1 - exp(-eps / 1.5)
        var curv = [Float](repeating: 0, count: n), nx = curv, ny = curv, back = curv, weight = curv
        for i in 0..<n {
            let p = i == 0 ? n - 1 : i - 1, q = i == n - 1 ? 0 : i + 1
            let ax = x[i] - x[p] + (i == 0 ? L : 0), ay = y[i] - y[p]
            let bx = x[q] - x[i] + (i == n - 1 ? L : 0), by = y[q] - y[i]
            let la = (ax * ax + ay * ay).squareRoot(), lb = (bx * bx + by * by).squareRoot()
            let cx = ax + bx, cy = ay + by, lc = (cx * cx + cy * cy).squareRoot() + 1e-12
            curv[i] = 2 * (ax * by - ay * bx) / (la * lb * lc + 1e-12)
            nx[i] = cy / lc; ny[i] = -cx / lc
            back[i] = exp(-alpha * la); weight[i] = 0.5 * (la + lb)
        }
        var c: Float = 0, g: Float = 0
        for i in max(n - Int(16 / alpha / ds), 0)..<n { c = curv[i] * weight[i] + back[i] * c; g = weight[i] + back[i] * g }
        for i in 0..<n {
            c = curv[i] * weight[i] + back[i] * c; g = weight[i] + back[i] * g
            let r = -curv[i] + 2.5 * c / g, side: Float = r < 0 ? -1 : 1
            let bankX = x[i] + 0.5 * side * nx[i], bankY = y[i] + 0.5 * side * ny[i]
            var e = erodibility(bankX, bankY)
            if side * ny[i] * (bankY - yc) > 0 { // cutting toward a wall, which stands in by a different amount along the valley
                var u = (bankX + pad) / L; u -= u.rounded(.down)
                let standsIn = wallTable[(bankY > yc ? 0 : 256) + min(Int(u * 256), 255)]
                e *= smooth((yc - 1.5 - standsIn - abs(bankY - yc)) / 5)
            }
            var bend: Float = 0
            for k in -3...3 { bend += abs(curv[(i + k + n) % n]) }
            hw[i] += (0.5 * (0.7 + 0.8 * min(bend / 7 / 0.4, 1)) - hw[i]) * ease
            let d = max(-cap, min(cap, r * e * eps))
            x[i] += d * nx[i]; y[i] += d * ny[i]
        }
        t += eps; steps += 1
    }

    /// Keeps nodes 0.6 to 1.4 ds apart, touching only the ones that need it.
    func respace() {
        var again = true, passes = 0
        while again && passes < 4 { // four passes at most: dropping a node and splitting what's left can undo each other for ever
            again = false
            passes += 1
            let n = x.count
            var ox: [Float] = [], oy: [Float] = [], oh: [Float] = []
            ox.reserveCapacity(n + 8); oy.reserveCapacity(n + 8); oh.reserveCapacity(n + 8)
            var i = 0
            while i < n {
                let q = (i + 1) % n, wrap: Float = i == n - 1 ? L : 0
                let dx = x[q] + wrap - x[i], dy = y[q] - y[i], len = (dx * dx + dy * dy).squareRoot()
                ox.append(x[i]); oy.append(y[i]); oh.append(hw[i])
                if len > 1.4 * ds { // split at the Catmull-Rom midpoint
                    let p = (i + n - 1) % n, r = (i + 2) % n
                    let x0 = x[p] - (i == 0 ? L : 0), x2 = x[q] + wrap, x3 = x[r] + (i + 2 >= n ? L : 0)
                    ox.append((-x0 + 9 * x[i] + 9 * x2 - x3) / 16); oy.append((-y[p] + 9 * y[i] + 9 * y[q] - y[r]) / 16)
                    oh.append(0.5 * (hw[i] + hw[q]))
                    again = true
                } else if len < 0.6 * ds && i < n - 1 { i += 1; again = true } // drop the next node
                i += 1
            }
            x = ox; y = oy; hw = oh
        }
        var mean: Float = 0
        for v in x { mean += v }
        let shift = L * ((mean / Float(x.count) - (L / 2 - pad)) / L).rounded()
        if shift != 0 { for i in x.indices { x[i] -= shift } }
    }

    /// Finds the two stretches of river whose banks are closest and touching (by a grid of buckets) and drops the
    /// loop between them. Returns the loop, or nil.
    func cutoff() -> Lake? {
        let n = x.count, gap = Int(6 / ds), L = L, reach = crdist * 1.5
        let gw = Int(L / reach), cell = L / Float(gw), gh = Int(sy / cell) + 3
        var head = [Int32](repeating: -1, count: gw * gh), next = [Int32](repeating: -1, count: n)
        var cellOf = [Int32](repeating: 0, count: n)
        for i in 0..<n {
            var u = (x[i] + pad) / L; u -= u.rounded(.down)
            let cx = min(Int(u * Float(gw)), gw - 1), cy = max(0, min(gh - 1, Int(y[i] / cell) + 1))
            cellOf[i] = Int32(cy * gw + cx); next[i] = head[cy * gw + cx]; head[cy * gw + cx] = Int32(i)
        }
        var best: Float = 0, lo = -1, hi = -1
        for i in 0..<n {
            let cx = Int(cellOf[i]) % gw, cy = Int(cellOf[i]) / gw
            for oy in -1...1 where cy + oy >= 0 && cy + oy < gh {
                for ox in -1...1 {
                    var j = Int(head[(cy + oy) * gw + (cx + ox + gw) % gw])
                    while j >= 0 {
                        if j != i {
                            var dx = x[j] - x[i]
                            let k = (dx / L).rounded(); dx -= k * L
                            let dy = y[j] - y[i], d = (dx * dx + dy * dy).squareRoot(), between = d - crdist * (hw[i] + hw[j])
                            if between < best {
                                let other = j - Int(k) * n, hops = abs(other - i) // node j's copy that is near node i
                                if hops >= gap && hops <= n - gap { best = between; lo = min(i, other); hi = max(i, other) }
                            }
                        }
                        j = Int(next[j])
                    }
                }
            }
        }
        guard lo != -1 else { return nil }
        if lo < 0 { lo += n; hi += n } else if lo >= n { lo -= n; hi -= n }
        var loop = Lake(x: [], y: [], h: [], born: t, a: t, b: t), rx: [Float] = [], ry: [Float] = [], rh: [Float] = []
        for k in lo...hi { loop.x.append(x[k % n] + Float(k / n) * L); loop.y.append(y[k % n]); loop.h.append(hw[k % n]) }
        for k in hi...(lo + n) { rx.append(x[k % n] + Float(k / n) * L - (hi >= n ? L : 0)); ry.append(y[k % n]); rh.append(hw[k % n]) }
        x = rx; y = ry; hw = rh; cuts += 1
        return loop
    }

    /// A polyline with a point added half-way along each segment, on the Catmull-Rom curve through its nodes, so
    /// banks drawn from it are not faceted.
    func curve(_ px: [Float], _ py: [Float], _ ph: [Float], closed: Bool) -> (x: [Float], y: [Float], h: [Float]) {
        let n = px.count, count = closed ? n : n - 1
        var ox: [Float] = [], oy: [Float] = [], oh: [Float] = []
        ox.reserveCapacity(2 * n); oy.reserveCapacity(2 * n); oh.reserveCapacity(2 * n)
        func at(_ k: Int) -> (Float, Float) {
            if closed { return (px[(k + n) % n] + (k < 0 ? -L : k >= n ? L : 0), py[(k + n) % n]) }
            if k < 0 { return (2 * px[0] - px[1], 2 * py[0] - py[1]) }
            if k >= n { return (2 * px[n - 1] - px[n - 2], 2 * py[n - 1] - py[n - 2]) }
            return (px[k], py[k])
        }
        for i in 0..<count {
            let a = at(i - 1), b = at(i), c = at(i + 1), d = at(i + 2)
            ox.append(b.0); oy.append(b.1); oh.append(ph[i])
            ox.append((-a.0 + 9 * b.0 + 9 * c.0 - d.0) / 16); oy.append((-a.1 + 9 * b.1 + 9 * c.1 - d.1) / 16)
            oh.append(0.5 * (ph[i] + ph[(i + 1) % n]))
        }
        if !closed { ox.append(px[n - 1]); oy.append(py[n - 1]); oh.append(ph[n - 1]) }
        return (ox, oy, oh)
    }

    /// Leaves in `scratch` each texel's bank distance to a channel (distance to its centreline, less the half-width
    /// there, plus 0.5: so 0.5 is the bank), for texels out to `r` beyond the banks, and lists them. `whole` checks
    /// every texel in each segment's bounding box. Otherwise each segment only visits the slab beside itself (plus
    /// a little past each end, enough to close the gap at a gentle joint), and a sharp joint or an open end gets its
    /// own disc.
    func band(_ px: [Float], _ py: [Float], _ ph: [Float], closed: Bool, r: Float, whole: Bool = false, into list: inout [Int32]) {
        let tex = tex, tw = tw, th = th, L = L, pad = pad, n = px.count, count = closed ? n : n - 1, inverse = 1 / tex
        var found: [Int32] = []
        found.reserveCapacity(60_000)
        defer { list.append(contentsOf: found) }
        scratch.withUnsafeMutableBufferPointer { scratch in px.withUnsafeBufferPointer { px in py.withUnsafeBufferPointer { py in ph.withUnsafeBufferPointer { ph in
            var lastX: Float = 0, lastY: Float = 0 // the segment before's direction
            if closed {
                let ex = px[0] + L - px[n - 1], ey = py[0] - py[n - 1], len = (ex * ex + ey * ey).squareRoot() + 1e-12
                lastX = ex / len; lastY = ey / len
            }
            for i in 0..<count {
                let q = (i + 1) % n
                var ax = px[i], bx = px[q] + (closed && i == n - 1 ? L : 0)
                let ay = py[i], by = py[q], ha = ph[i], hb = ph[q]
                let ex = bx - ax, ey = by - ay, len2 = ex * ex + ey * ey + 1e-12, inv = 1 / len2, len = len2.squareRoot()
                let sharp = (!closed && i == 0) || (lastX * ex + lastY * ey) < 0.96 * len
                lastX = ex / len; lastY = ey / len
                let reach = max(ha, hb) + r
                if reach <= 0 { continue } // a dry stretch of a lake
                let mid = 0.5 * (ax + bx)
                var u = (mid + pad) / L; u -= u.rounded(.down)
                let shift = u * L - pad - mid // draw the segment in the period that holds the screen
                ax += shift; bx += shift
                for pass in 0..<(sharp && !whole ? 2 : 1) {
                    // pass 1 is the disc round a sharp joint's node: a segment of no length
                    let fx = pass == 0 ? ex : 0, fy = pass == 0 ? ey : 0, finv = pass == 0 ? inv : 0, rise = pass == 0 ? hb - ha : 0
                    let endX = ax + fx, endY = ay + fy
                    let x0 = max(Int(((min(ax, endX) - reach) * tex).rounded(.down)), 0), x1 = min(Int(((max(ax, endX) + reach) * tex).rounded(.up)), tw - 1)
                    let y0 = max(Int(((min(ay, endY) - reach) * tex).rounded(.down)), 0), y1 = min(Int(((max(ay, endY) + reach) * tex).rounded(.up)), th - 1)
                    if x0 > x1 || y0 > y1 { continue }
                    let slab = pass == 0 && !whole, extra = (0.15 * reach * tex + 0.5) * inverse / len // past each end: enough for a 16 degree joint at this reach
                    for ty in y0...y1 {
                        let gy = (Float(ty) + 0.5) * inverse - ay, row = ty * tw
                        var lo = x0, hi = x1
                        if slab { // along the row, the share s along the segment and the distance off its line are both linear in x
                            var gMin = -Float.infinity, gMax = Float.infinity
                            if abs(ex) > 1e-6 {
                                let a = (-extra * len2 - gy * ey) / ex, b = ((1 + extra) * len2 - gy * ey) / ex
                                gMin = max(gMin, min(a, b)); gMax = min(gMax, max(a, b))
                            } else if gy * ey * inv < -extra || gy * ey * inv > 1 + extra { continue }
                            if abs(ey) > 1e-6 {
                                let a = (gy * ex - reach * len) / ey, b = (gy * ex + reach * len) / ey
                                gMin = max(gMin, min(a, b)); gMax = min(gMax, max(a, b))
                            } else if abs(gy * ex) > reach * len { continue }
                            if gMin > gMax { continue }
                            lo = max(lo, Int(((gMin + ax) * tex - 0.5).rounded(.up))); hi = min(hi, Int(((gMax + ax) * tex - 0.5).rounded(.down)))
                            if lo > hi { continue }
                        }
                        for tx in lo...hi {
                            let gx = (Float(tx) + 0.5) * inverse - ax
                            let s = max(0, min(1, (gx * fx + gy * fy) * finv)), qx = gx - s * fx, qy = gy - s * fy
                            let value = (qx * qx + qy * qy).squareRoot() - (ha + s * rise) + 0.5
                            if value < 0.5 + r && value < scratch[row + tx] {
                                if scratch[row + tx] == .infinity { found.append(Int32(row + tx)) }
                                scratch[row + tx] = value
                            }
                        }
                    }
                }
            }
        } } } }
    }

    /// Fills the ribbon between a channel's banks, texel centres in or out and nothing finer: for the distant past.
    /// `stamping` gives every texel the present time and wipes its hollow; otherwise it marks the ribbon as a hollow.
    func ribbon(_ px: [Float], _ py: [Float], _ ph: [Float], closed: Bool, stamping: Bool) {
        let n = px.count, count = closed ? n : n - 1, tex = tex, tw = tw, th = th, L = L, pad = pad, t = t
        var nx = [Float](repeating: 0, count: n), ny = nx
        for i in 0..<n {
            let p = closed ? (i + n - 1) % n : max(i - 1, 0), q = closed ? (i + 1) % n : min(i + 1, n - 1)
            let cx = px[q] - px[p] + (closed ? (i == 0 ? L : 0) + (i == n - 1 ? L : 0) : 0), cy = py[q] - py[p]
            let len = (cx * cx + cy * cy).squareRoot() + 1e-12
            nx[i] = cy / len; ny[i] = -cx / len
        }
        stamp.withUnsafeMutableBufferPointer { stamp in hollow.withUnsafeMutableBufferPointer { hollow in
            for i in 0..<count {
                let q = (i + 1) % n, wrap: Float = closed && i == n - 1 ? L : 0
                let mid = 0.5 * (px[i] + px[q] + wrap)
                var u = (mid + pad) / L; u -= u.rounded(.down)
                let shift = u * L - pad - mid
                let cornersX = [px[i] + ph[i] * nx[i] + shift, px[q] + wrap + ph[q] * nx[q] + shift, px[q] + wrap - ph[q] * nx[q] + shift, px[i] - ph[i] * nx[i] + shift]
                let cornersY = [py[i] + ph[i] * ny[i], py[q] + ph[q] * ny[q], py[q] - ph[q] * ny[q], py[i] - ph[i] * ny[i]]
                let y0 = max(Int((cornersY.min()! * tex - 0.5).rounded(.up)), 0), y1 = min(Int((cornersY.max()! * tex - 0.5).rounded(.down)), th - 1)
                if y0 > y1 { continue }
                for ty in y0...y1 {
                    let yy = (Float(ty) + 0.5) / tex
                    var left = Float.infinity, right = -Float.infinity
                    for e in 0..<4 {
                        let f = (e + 1) % 4, ya = cornersY[e], yb = cornersY[f]
                        if (ya - yy) * (yb - yy) <= 0 && ya != yb {
                            let xx = cornersX[e] + (yy - ya) / (yb - ya) * (cornersX[f] - cornersX[e])
                            left = min(left, xx); right = max(right, xx)
                        }
                    }
                    if left > right { continue }
                    let x0 = max(Int((left * tex - 0.5).rounded(.up)), 0), x1 = min(Int((right * tex - 0.5).rounded(.down)), tw - 1)
                    if x0 > x1 { continue }
                    if stamping { for tx in x0...x1 { stamp[ty * tw + tx] = t; hollow[ty * tw + tx] = 1 } }
                    else { for tx in x0...x1 { hollow[ty * tw + tx] = min(hollow[ty * tw + tx], 0.3) } }
                }
            }
        } }
    }

    @inline(__always) func pack(_ v: Float, _ lo: Float, _ hi: Float) -> UInt8 { UInt8(max(0, min(255, (v - lo) / (hi - lo) * 255))) }

    /// Writes one texel's bytes: the stamp in 16 bits at 0.01 T a level, the water field (the live channel or a lake,
    /// whichever is nearer) with its bank at mid-range and two texels either side, and the hollow field over 0.25 to 1.
    @inline(__always) func write(_ i: Int) {
        let s = Int(max(0, min(65535, stamp[i] * 100)))
        pixels[i * 4] = UInt8(s >> 8); pixels[i * 4 + 1] = UInt8(s & 255)
        pixels[i * 4 + 2] = pack(min(live[i], lakeField[i]), 0.5 - 2 / tex, 0.5 + 2 / tex)
        pixels[i * 4 + 3] = pack(hollow[i], 0.25, 1)
    }

    func writeAll() { for i in 0..<tw * th { write(i) } }

    /// A lake's half-widths now: each end silts up behind a front that moves in from it, and the whole lake narrows
    /// to nothing over the second half of its life. A dry stretch gets a negative width, so nothing is drawn.
    func widths(_ k: Lake) -> [Float] {
        var arc: [Float] = [0]
        for i in 1..<k.x.count { arc.append(arc[i - 1] + hypot(k.x[i] - k.x[i - 1], k.y[i] - k.y[i - 1])) }
        func end(_ dist: Float, _ since: Float) -> Float {
            let age = t - since, front = 3.2 * (1 - exp(-age / 0.6)) + 0.25 * age
            return smooth((dist - front) / 2 + 1)
        }
        let body = 1 - smooth((t - k.born - 0.5 * lakeLife) / (0.5 * lakeLife))
        return k.h.indices.map { i in
            let m = body * end(arc[i], k.a) * end(arc[arc.count - 1] - arc[i], k.b)
            return k.h[i] * m - 0.15 * (1 - m)
        }
    }

    /// Drops the lake nodes the live channel now covers (`covered` says which texels those are): a lake ends at the
    /// outermost node still under the river, and one the river cuts through becomes two.
    func trimLakes(covered: (Int) -> Bool) {
        var out: [Lake] = []
        for k in lakes where t - k.born <= lakeLife {
            let n = k.x.count
            var under = [Bool](repeating: false, count: n), any = false
            for i in 0..<n {
                var u = (k.x[i] + pad) / L; u -= u.rounded(.down)
                let ix = Int(((u * L - pad) * tex).rounded(.down)), iy = Int((k.y[i] * tex).rounded(.down))
                if ix >= 0 && ix < tw && iy >= 0 && iy < th && covered(iy * tw + ix) { under[i] = true; any = true }
            }
            if !any { out.append(k); continue }
            var i = 0
            while i < n {
                if under[i] { i += 1; continue }
                var j = i
                while j + 1 < n && !under[j + 1] { j += 1 }
                let lo = max(i - 1, 0), hi = min(j + 1, n - 1)
                if hi > lo {
                    out.append(Lake(x: Array(k.x[lo...hi]), y: Array(k.y[lo...hi]), h: Array(k.h[lo...hi]), born: k.born,
                                    a: lo == 0 ? k.a : t, b: hi == n - 1 ? k.b : t))
                }
                i = j + 1
            }
        }
        lakes = out
    }

    /// Redraws every lake into the lake field with the river's own routine.
    func drawLakes() {
        for raw in lakeTouched { lakeField[Int(raw)] = far }
        let old = lakeTouched
        lakeTouched.removeAll(keepingCapacity: true)
        for k in lakes {
            let c = curve(k.x, k.y, widths(k), closed: false)
            band(c.x, c.y, c.h, closed: false, r: 2 / tex, into: &lakeTouched)
        }
        for raw in lakeTouched { lakeField[Int(raw)] = scratch[Int(raw)]; scratch[Int(raw)] = .infinity }
        for raw in old { write(Int(raw)) }
        for raw in lakeTouched { write(Int(raw)) }
        lakeTexels = lakeTouched.count
    }

    /// Brings the fields up to date with the river: the live channel's band, the time each texel was last under
    /// water (a share of the way there for texels a bank is part-way across), hollows wiped, lakes trimmed and drawn.
    func updateFields(lakes redraw: Bool = true) {
        swap(&touched, &before)
        touched.removeAll(keepingCapacity: true)
        let c = curve(x, y, hw, closed: true)
        band(c.x, c.y, c.h, closed: true, r: 2 / tex, into: &touched)
        let tex = tex, t = t, far = far
        for raw in before where scratch[Int(raw)] == .infinity { live[Int(raw)] = far; write(Int(raw)) }
        stamp.withUnsafeMutableBufferPointer { stamp in hollow.withUnsafeMutableBufferPointer { hollow in
        live.withUnsafeMutableBufferPointer { live in scratch.withUnsafeMutableBufferPointer { scratch in
            for raw in touched {
                let i = Int(raw), d = scratch[i]
                let now = max(0, min(1, 0.5 + (0.5 - d) * tex)), was = max(0, min(1, 0.5 + (0.5 - live[i]) * tex))
                if now >= 1 { stamp[i] = t } else if now > was {
                    let old = max(stamp[i], t - 400)
                    stamp[i] = old + (t - old) * (now - was) / (1 - was)
                }
                hollow[i] = max(hollow[i], 0.5 + 3 * (0.5 - d))
                live[i] = d
                scratch[i] = .infinity
            }
        } } } }
        for raw in touched { write(Int(raw)) }
        bandTexels = touched.count
        trimLakes { self.live[$0] < 0.5 }
        if redraw { drawLakes() }
    }

    /// One step. `crude` is the distant past: the ribbon is stamped every fourth step and nothing finer is kept.
    /// With `fields`, every cut-off loop becomes a lake and a hollow, and the fields are brought up to date if `update`.
    func step(_ eps: Float, fields: Bool, crude: Bool = false, update: Bool = true, lakes redraw: Bool = true) {
        migrate(eps)
        while let loop = cutoff() {
            guard fields || crude else { continue }
            if crude { ribbon(loop.x, loop.y, loop.h, closed: false, stamping: false) } else {
                var list: [Int32] = []
                let c = curve(loop.x, loop.y, loop.h, closed: false)
                band(c.x, c.y, c.h, closed: false, r: 0.5, into: &list)
                for raw in list { hollow[Int(raw)] = min(hollow[Int(raw)], scratch[Int(raw)]); scratch[Int(raw)] = .infinity; write(Int(raw)) }
            }
            lakes.append(loop)
        }
        respace()
        if crude {
            if steps % 4 == 0 { ribbon(x, y, hw, closed: true, stamping: true); let t = t; trimLakes { self.stamp[$0] == t } }
        } else if fields && update { updateFields(lakes: redraw) }
    }

    var sinuosity: Float {
        var arc: Float = 0
        for i in x.indices { let q = (i + 1) % x.count; arc += hypot(x[q] + (q == 0 ? L : 0) - x[i], y[q] - y[i]) }
        return arc / L
    }
}

func time(_ label: String, _ count: Int, _ body: () -> Void) -> Double {
    let start = DispatchTime.now().uptimeNanoseconds
    body()
    let ms = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6
    print(String(format: "%@: %.1f ms total, %.3f ms a step", label, ms, ms / Double(count)))
    return ms
}

let widthPoints = CommandLine.arguments.count > 1 ? Float(CommandLine.arguments[1])! : 28 // the river's width on screen
let past = CommandLine.arguments.count > 2 ? Float(CommandLine.arguments[2])! : 300        // T of distant past
let every = CommandLine.arguments.count > 3 ? Int(CommandLine.arguments[3])! : 8           // fields every so many steps in the T 60 after it
let river = Meander(seed: 11, sx: 1512 / widthPoints, sy: 982 / widthPoints, tex: widthPoints / 2, ds: 1)
print("river \(widthPoints) pt wide: screen \(river.sx) x \(river.sy) widths, texture \(river.tw) x \(river.th)")

// launch: the distant past cheaply, then T 60 as the live river runs it
var launch = 0.0
let old = Int(past / 0.12)
launch += time("distant past: T \(past), \(old) steps of 0.12 T, nodes 1 W apart, ribbon every 4th", max(old, 1)) { for _ in 0..<old { river.step(0.12, fields: false, crude: true) } }
print("  nodes \(river.x.count), sinuosity \(river.sinuosity), cutoffs \(river.cuts), lakes \(river.lakes.count)")
river.ds = 0.5
river.respace()
launch += time("then T 60: 1500 steps of 0.04 T, nodes 0.5 W apart, fields every \(every)th, lakes drawn once", 1500) { for k in 1...1500 { river.step(0.04, fields: true, update: k % every == 0, lakes: false) }; river.drawLakes() } // lakes are trimmed throughout, drawn once at the end
launch += time("every texel's bytes written once", 1) { river.writeAll() }
print(String(format: "LAUNCH: %.0f ms", launch))
print("  nodes \(river.x.count), sinuosity \(river.sinuosity), cutoffs \(river.cuts), lakes \(river.lakes.count), band \(river.bandTexels) texels, lake band \(river.lakeTexels) texels")
FileManager.default.createFile(atPath: "launch-\(Int(widthPoints))-\(Int(past)).rgba", contents: Data(river.pixels))

// live: 10 steps a second at 25 s a T
let live: Float = 1.0 / 25 / 10
_ = time("live steps, fields and every lake redrawn each step", 2000) { for _ in 0..<2000 { river.step(live, fields: true) } }
print("  nodes \(river.x.count), cutoffs \(river.cuts), lakes \(river.lakes.count), band \(river.bandTexels) texels, lake band \(river.lakeTexels) texels")
_ = time("live steps, lakes redrawn every 10th step", 2000) { for k in 0..<2000 { river.step(live, fields: true, lakes: k % 10 == 0) } }
_ = time("live steps, river only", 2000) { for _ in 0..<2000 { river.step(live, fields: false) } }
river.updateFields()
do { // the slab band must agree with checking every texel in the box
    var a: [Int32] = [], b: [Int32] = []
    let c = river.curve(river.x, river.y, river.hw, closed: true)
    river.band(c.x, c.y, c.h, closed: true, r: 2 / river.tex, whole: true, into: &a)
    let exact = river.scratch
    for i in a { river.scratch[Int(i)] = .infinity }
    river.band(c.x, c.y, c.h, closed: true, r: 2 / river.tex, into: &b)
    // With a width that varies along the river the two can differ at the band's outer rim: a texel just inside the
    // rim by one segment's end cap can be just outside it by the next segment's own slab. So compare the texels both
    // found, and say how far beyond the bank the nearest texel only one found is.
    var worst: Float = 0, nearestMissed = Float.infinity, missed = 0
    for i in a {
        if river.scratch[Int(i)] == .infinity { missed += 1; nearestMissed = min(nearestMissed, exact[Int(i)]) }
        else { worst = max(worst, abs(exact[Int(i)] - river.scratch[Int(i)])) }
    }
    for i in b { river.scratch[Int(i)] = .infinity }
    print("  slab band against whole boxes: \(a.count) and \(b.count) texels; where both have one, worst difference \(worst) W; \(missed) only in the whole-box band, the nearest of them \((nearestMissed - 0.5) * river.tex) texels beyond the bank (the band is 2 wide)")
}
_ = time("field update alone (river band, stamps, hollows, trim, lakes)", 1000) { for _ in 0..<1000 { river.updateFields() } }
_ = time("  without redrawing lakes", 1000) { for _ in 0..<1000 { river.updateFields(lakes: false) } }
var copy = river.pixels
_ = time("copying the texture's bytes (\(river.pixels.count / 1024) KB)", 1000) { for _ in 0..<1000 { copy = river.pixels; copy[0] &+= 1 } }
FileManager.default.createFile(atPath: "live-\(Int(widthPoints)).rgba", contents: Data(river.pixels))
