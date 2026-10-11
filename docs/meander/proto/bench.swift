// Meander's core in Swift, to time it: the river (Howard & Knutson migration, neck cutoffs, a period along the valley)
// and the per-step update of the fields a shader would read. A sketch for timing, checked against the Python
// prototype by eye (it writes its texture out); not the scene. swiftc -O bench.swift && ./bench
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
}

func smooth(_ t: Float) -> Float { let u = max(0, min(1, t)); return u * u * (3 - 2 * u) }

final class Meander {
    // lengths are in channel widths, time in T (the prototype's units)
    let sx: Float, sy: Float, tex: Float
    let pad: Float = 10, ds: Float = 0.5, alpha: Float = 0.73, crdist: Float = 1.04, rateCap: Float = 1.25
    let far: Float = 2
    var L: Float { sx + 2 * pad }
    var x: [Float] = [], y: [Float] = []
    var t: Float = 0, cuts = 0, steps = 0
    let tw: Int, th: Int
    var stamp: [Float], lake: [Float], live: [Float], scratch: [Float]
    var touched: [Int32] = [], before: [Int32] = []
    var pixels: [UInt8]
    var egrid: [Float] = [], ecols = 0, erows = 0, ecell: Float = 8
    var bandTexels = 0

    init(seed: UInt64, sx: Float, sy: Float, tex: Float) {
        self.sx = sx; self.sy = sy; self.tex = tex
        tw = Int((sx * tex).rounded()); th = Int((sy * tex).rounded())
        stamp = Array(repeating: -1e9, count: tw * th)
        lake = Array(repeating: 1, count: tw * th)
        live = Array(repeating: far, count: tw * th)
        scratch = Array(repeating: .infinity, count: tw * th)
        pixels = Array(repeating: 255, count: tw * th * 4)
        var rng = SplitMix(s: seed)
        let n = Int((L / ds).rounded())
        var phase: [Float] = [], amp: [Float] = []
        for k in 1..<40 { phase.append(rng.unit() * 2 * .pi); amp.append((rng.unit() + rng.unit() + rng.unit() - 1.5) * 0.5 / Float(k).squareRoot()) }
        for i in 0..<n {
            x.append(-pad + L * Float(i) / Float(n))
            var v: Float = sy / 2
            for k in 1..<40 { v += amp[k - 1] * sin(2 * .pi * Float(k) * Float(i) / Float(n) + phase[k - 1]) }
            y.append(v)
        }
        ecols = Int((L / 8).rounded()); ecell = L / Float(ecols); erows = Int(sy / ecell) + 3
        for _ in 0..<ecols * erows { egrid.append((rng.unit() + rng.unit() + rng.unit() + rng.unit() - 2) * 1.7) }
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

    /// One step of Howard & Knutson's migration: each node moves along its normal at minus its curvature plus 2.5
    /// times the curvature upstream, averaged with weights falling off as exp(-alpha * distance).
    func migrate(_ eps: Float) {
        let n = x.count, L = L, yc = sy / 2, ywall = sy / 2 - 3, cap = rateCap * eps
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
            if side * ny[i] * (bankY - yc) > 0 { e *= smooth((ywall - abs(bankY - yc)) / 6) } // the valley wall resists
            let d = max(-cap, min(cap, r * e * eps))
            x[i] += d * nx[i]; y[i] += d * ny[i]
        }
        t += eps; steps += 1
    }

    /// Keeps nodes 0.6 to 1.4 ds apart, touching only the ones that need it.
    func respace() {
        var again = true
        while again {
            again = false
            let n = x.count
            var ox: [Float] = [], oy: [Float] = []
            ox.reserveCapacity(n + 8); oy.reserveCapacity(n + 8)
            var i = 0
            while i < n {
                let q = (i + 1) % n, wrap: Float = i == n - 1 ? L : 0
                let dx = x[q] + wrap - x[i], dy = y[q] - y[i], len = (dx * dx + dy * dy).squareRoot()
                ox.append(x[i]); oy.append(y[i])
                if len > 1.4 * ds { // split at the Catmull-Rom midpoint
                    let p = (i + n - 1) % n, r = (i + 2) % n
                    let x0 = x[p] - (i == 0 ? L : 0), x2 = x[q] + wrap, x3 = x[r] + (i + 2 >= n ? L : 0)
                    ox.append((-x0 + 9 * x[i] + 9 * x2 - x3) / 16); oy.append((-y[p] + 9 * y[i] + 9 * y[q] - y[r]) / 16)
                    again = true
                } else if len < 0.6 * ds && i < n - 1 { i += 1; again = true } // drop the next node
                i += 1
            }
            x = ox; y = oy
        }
        var mean: Float = 0
        for v in x { mean += v }
        let shift = L * ((mean / Float(x.count) - (L / 2 - pad)) / L).rounded()
        if shift != 0 { for i in x.indices { x[i] -= shift } }
    }

    /// Finds the closest two stretches of river nearer than `crdist` (by a grid of buckets) and drops the loop
    /// between them. Returns the loop, or nil.
    func cutoff() -> (x: [Float], y: [Float])? {
        let n = x.count, gap = Int(6 / ds), L = L
        let gw = Int(L / crdist), cell = L / Float(gw), gh = Int(sy / cell) + 3
        var head = [Int32](repeating: -1, count: gw * gh), next = [Int32](repeating: -1, count: n)
        var cellOf = [Int32](repeating: 0, count: n)
        for i in 0..<n {
            var u = (x[i] + pad) / L; u -= u.rounded(.down)
            let cx = min(Int(u * Float(gw)), gw - 1), cy = max(0, min(gh - 1, Int(y[i] / cell) + 1))
            cellOf[i] = Int32(cy * gw + cx); next[i] = head[cy * gw + cx]; head[cy * gw + cx] = Int32(i)
        }
        var best = crdist * crdist, lo = -1, hi = -1
        for i in 0..<n {
            let cx = Int(cellOf[i]) % gw, cy = Int(cellOf[i]) / gw
            for oy in -1...1 where cy + oy >= 0 && cy + oy < gh {
                for ox in -1...1 {
                    var j = Int(head[(cy + oy) * gw + (cx + ox + gw) % gw])
                    while j >= 0 {
                        if j != i {
                            var dx = x[j] - x[i]
                            let k = (dx / L).rounded(); dx -= k * L
                            let dy = y[j] - y[i], d2 = dx * dx + dy * dy
                            if d2 < best {
                                let other = j - Int(k) * n, hops = abs(other - i) // node j's copy that is near node i
                                if hops >= gap && hops <= n - gap { best = d2; lo = min(i, other); hi = max(i, other) }
                            }
                        }
                        j = Int(next[j])
                    }
                }
            }
        }
        guard lo != -1 else { return nil }
        if lo < 0 { lo += n; hi += n } else if lo >= n { lo -= n; hi -= n }
        func node(_ k: Int) -> (Float, Float) { (x[k % n] + Float(k / n) * L, y[k % n]) }
        var loopX: [Float] = [], loopY: [Float] = [], riverX: [Float] = [], riverY: [Float] = []
        for k in lo...hi { let p = node(k); loopX.append(p.0); loopY.append(p.1) }
        for k in hi...(lo + n) { let p = node(k); riverX.append(p.0 - (hi >= n ? L : 0)); riverY.append(p.1) }
        x = riverX; y = riverY; cuts += 1
        return (loopX, loopY)
    }

    /// Leaves in `scratch` the squared distance from each texel's centre to a polyline, for texels within `r` of
    /// it, and lists them. `whole` checks every texel in each segment's bounding box. Otherwise each segment only
    /// visits the slab beside itself (plus a texel and a half past each end, which covers the gap at a gentle
    /// joint), and a sharp joint gets its own disc: a third of the work for the same answer.
    func band(_ px: [Float], _ py: [Float], closed: Bool, r: Float, whole: Bool = false, into list: inout [Int32]) {
        let tex = tex, tw = tw, th = th, L = L, pad = pad, count = closed ? px.count : px.count - 1, r2 = r * r, inverse = 1 / tex
        var found: [Int32] = []
        found.reserveCapacity(60_000)
        defer { list.append(contentsOf: found) }
        scratch.withUnsafeMutableBufferPointer { scratch in px.withUnsafeBufferPointer { px in py.withUnsafeBufferPointer { py in
            var lastX: Float = 0, lastY: Float = 0 // the segment before's direction
            if closed { // the joint at node 0 is between the last segment and the first
                let n = px.count, ex = px[0] + L - px[n - 1], ey = py[0] - py[n - 1], len = (ex * ex + ey * ey).squareRoot() + 1e-12
                lastX = ex / len; lastY = ey / len
            }
            for i in 0..<count {
                let q = (i + 1) % px.count
                var ax = px[i], bx = px[q] + (closed && i == px.count - 1 ? L : 0)
                let ay = py[i], by = py[q]
                let mid = 0.5 * (ax + bx)
                var u = (mid + pad) / L; u -= u.rounded(.down)
                let shift = u * L - pad - mid // draw the segment in the period that holds the screen
                ax += shift; bx += shift
                let ex = bx - ax, ey = by - ay, len2 = ex * ex + ey * ey + 1e-12, inv = 1 / len2, len = len2.squareRoot()
                let sharp = (!closed && i == 0) || (lastX * ex + lastY * ey) < 0.96 * len // an open end, or a turn of more than about 16 degrees
                lastX = ex / len; lastY = ey / len
                for pass in 0..<(sharp && !whole ? 2 : 1) {
                    // pass 1 is the disc round a sharp joint's node: a segment of no length
                    let fx = pass == 0 ? ex : 0, fy = pass == 0 ? ey : 0, finv = pass == 0 ? inv : 0
                    let reach = pass == 0 ? r : r, endX = ax + fx, endY = ay + fy
                    let x0 = max(Int(((min(ax, endX) - reach) * tex).rounded(.down)), 0), x1 = min(Int(((max(ax, endX) + reach) * tex).rounded(.up)), tw - 1)
                    let y0 = max(Int(((min(ay, endY) - reach) * tex).rounded(.down)), 0), y1 = min(Int(((max(ay, endY) + reach) * tex).rounded(.up)), th - 1)
                    if x0 > x1 || y0 > y1 { continue }
                    let slab = pass == 0 && !whole, extra = 1.5 * inverse / len // how far past each end, as a share of the segment
                    for ty in y0...y1 {
                        let gy = (Float(ty) + 0.5) * inverse - ay, row = ty * tw
                        var lo = x0, hi = x1
                        if slab {
                            // along the row, the share s along the segment and the distance off its line are both linear in x
                            var gMin = -Float.infinity, gMax = Float.infinity
                            if abs(ex) > 1e-6 {
                                let a = (-extra * len2 - gy * ey) / ex, b = ((1 + extra) * len2 - gy * ey) / ex
                                gMin = max(gMin, min(a, b)); gMax = min(gMax, max(a, b))
                            } else if gy * ey * inv < -extra || gy * ey * inv > 1 + extra { continue }
                            if abs(ey) > 1e-6 {
                                let a = (gy * ex - r * len) / ey, b = (gy * ex + r * len) / ey
                                gMin = max(gMin, min(a, b)); gMax = min(gMax, max(a, b))
                            } else if abs(gy * ex) > r * len { continue }
                            if gMin > gMax { continue }
                            lo = max(lo, Int(((gMin + ax) * tex - 0.5).rounded(.up))); hi = min(hi, Int(((gMax + ax) * tex - 0.5).rounded(.down)))
                            if lo > hi { continue }
                        }
                        for tx in lo...hi {
                            let gx = (Float(tx) + 0.5) * inverse - ax
                            let s = max(0, min(1, (gx * fx + gy * fy) * finv)), qx = gx - s * fx, qy = gy - s * fy, d2 = qx * qx + qy * qy
                            if d2 < r2 && d2 < scratch[row + tx] {
                                if scratch[row + tx] == .infinity { found.append(Int32(row + tx)) }
                                scratch[row + tx] = d2
                            }
                        }
                    }
                }
            }
        } } }
    }

    /// Brings the fields up to date with the river: the live channel's distance band, the time each texel was
    /// last under water (a share of the way there for texels a bank is part-way across), and lakes eaten.
    /// The texture holds the stamp as 16 bits in red and green, and the lake's and the live channel's bank distance
    /// in blue and alpha, each spanning two texels either side of the bank.
    func updateFields() {
        swap(&touched, &before)
        touched.removeAll(keepingCapacity: true)
        band(x, y, closed: true, r: 0.5 + 2 / tex, into: &touched)
        let tex = tex, t = t, far = far, scale = tex / 4 * 255
        stamp.withUnsafeMutableBufferPointer { stamp in lake.withUnsafeMutableBufferPointer { lake in
        live.withUnsafeMutableBufferPointer { live in scratch.withUnsafeMutableBufferPointer { scratch in
        pixels.withUnsafeMutableBufferPointer { px in
            for raw in before where scratch[Int(raw)] == .infinity { live[Int(raw)] = far; px[Int(raw) * 4 + 3] = 255 }
            for raw in touched {
                let i = Int(raw), d = scratch[i].squareRoot()
                let now = max(0, min(1, 0.5 + (0.5 - d) * tex)), was = max(0, min(1, 0.5 + (0.5 - live[i]) * tex))
                if now >= 1 { stamp[i] = t } else if now > was {
                    let old = max(stamp[i], t - 400)
                    stamp[i] = old + (t - old) * (now - was) / (1 - was)
                }
                lake[i] = max(lake[i], 1 - d)
                live[i] = d
                scratch[i] = .infinity
                let s = Int(max(0, min(65535, stamp[i] * 100)))
                px[i * 4] = UInt8(s >> 8); px[i * 4 + 1] = UInt8(s & 255)
                px[i * 4 + 2] = UInt8(max(0, min(255, 127.5 + (lake[i] - 0.5) * scale)))
                px[i * 4 + 3] = UInt8(max(0, min(255, 127.5 + (d - 0.5) * scale)))
            }
        } } } } }
        bandTexels = touched.count
    }

    /// The cut-off loop keeps the channel's own distance field as a lake.
    func makeLake(_ loop: (x: [Float], y: [Float])) {
        var list: [Int32] = []
        band(loop.x, loop.y, closed: false, r: 0.5 + 2 / tex, into: &list)
        for raw in list {
            let i = Int(raw)
            lake[i] = min(lake[i], scratch[i].squareRoot())
            scratch[i] = .infinity
            pixels[i * 4 + 2] = UInt8(max(0, min(255, 127.5 + (lake[i] - 0.5) * tex / 4 * 255)))
        }
    }

    func step(_ eps: Float, fields: Bool) {
        migrate(eps)
        while let loop = cutoff() { if fields { makeLake(loop) } }
        respace()
        if fields { updateFields() }
    }

    var sinuosity: Float {
        var arc: Float = 0
        for i in x.indices { let q = (i + 1) % x.count; arc += hypot(x[q] + (q == 0 ? L : 0) - x[i], y[q] - y[i]) }
        return arc / L
    }
}

func time(_ label: String, _ count: Int, _ body: () -> Void) {
    let start = DispatchTime.now().uptimeNanoseconds
    body()
    let ms = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6
    print(String(format: "%@: %.1f ms total, %.3f ms a step", label, ms, ms / Double(count)))
}

let widthPoints = CommandLine.arguments.count > 1 ? Float(CommandLine.arguments[1])! : 28 // the river's width on screen
let texel: Float = 2 // points
let river = Meander(seed: 11, sx: 1512 / widthPoints, sy: 982 / widthPoints, tex: widthPoints / texel)
print("river \(widthPoints) pt wide: screen \(river.sx) x \(river.sy) widths, texture \(river.tw) x \(river.th), \(river.x.count) nodes")

if CommandLine.arguments.count > 2 { // history mode: T of coarse steps, the fields brought up to date every `every` steps
    let span = Float(CommandLine.arguments[2])!, every = Int(CommandLine.arguments[3])!, count = Int(span / 0.04)
    time("launch history: T \(span), \(count) coarse steps, fields every \(every)", count) {
        for k in 1...count { river.step(0.04, fields: false); if k % every == 0 { river.updateFields() } }
    }
    print("  nodes \(river.x.count), sinuosity \(river.sinuosity), cutoffs \(river.cuts), band \(river.bandTexels) texels")
    FileManager.default.createFile(atPath: "history-\(Int(widthPoints))-\(Int(span))-\(every).rgba", contents: Data(river.pixels))
    exit(0)
}
// the history made at launch: coarse steps, fields every step
time("launch history, 1500 coarse steps (T 60) with fields", 1500) { for _ in 0..<1500 { river.step(0.04, fields: true) } }
print("  nodes \(river.x.count), sinuosity \(river.sinuosity), cutoffs \(river.cuts), band \(river.bandTexels) texels")
time("1500 more coarse steps without fields", 1500) { for _ in 0..<1500 { river.step(0.04, fields: false) } }
river.updateFields()
// live: 10 steps a second at 75 s a T
let live: Float = 1.0 / 75 / 10
time("live steps with fields", 3000) { for _ in 0..<3000 { river.step(live, fields: true) } }
time("live steps, river only", 3000) { for _ in 0..<3000 { river.step(live, fields: false) } }
river.updateFields()
do { // the slab band must agree with checking every texel in the box
    var a: [Int32] = [], b: [Int32] = []
    river.band(river.x, river.y, closed: true, r: 0.5 + 2 / river.tex, whole: true, into: &a)
    let exact = river.scratch
    for i in a { river.scratch[Int(i)] = .infinity }
    river.band(river.x, river.y, closed: true, r: 0.5 + 2 / river.tex, into: &b)
    var worst: Float = 0
    for i in a { worst = max(worst, abs(exact[Int(i)].squareRoot() - min(river.scratch[Int(i)], 4).squareRoot())) }
    for i in b { river.scratch[Int(i)] = .infinity }
    print("  slab band against whole boxes: \(a.count) and \(b.count) texels, worst difference \(worst) widths")
    if !(a.count == b.count && worst < 1e-4) { print("  MISMATCH: the slab band misses texels here") }
}
time("field update alone", 1000) { for _ in 0..<1000 { river.updateFields() } }
var sink: [Int32] = []
time("  of which the distance band (slabs)", 1000) { for _ in 0..<1000 { sink.removeAll(keepingCapacity: true); river.band(river.x, river.y, closed: true, r: 0.5 + 2 / river.tex, into: &sink); for i in sink { river.scratch[Int(i)] = .infinity } } }
time("  the distance band over whole boxes", 1000) { for _ in 0..<1000 { sink.removeAll(keepingCapacity: true); river.band(river.x, river.y, closed: true, r: 0.5 + 2 / river.tex, whole: true, into: &sink); for i in sink { river.scratch[Int(i)] = .infinity } } }
var copy = river.pixels
time("copying the texture's bytes (\(river.pixels.count / 1024) KB)", 1000) { for _ in 0..<1000 { copy = river.pixels; copy[0] &+= 1 } }
print("  nodes \(river.x.count), sinuosity \(river.sinuosity), cutoffs \(river.cuts), band \(river.bandTexels) texels, T \(river.t)")
FileManager.default.createFile(atPath: "fields-\(Int(widthPoints)).rgba", contents: Data(river.pixels))
