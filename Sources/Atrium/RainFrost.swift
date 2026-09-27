import SpriteKit

/// Fern frost for Rain on Glass, baked on the CPU. A stochastic branching walker grows stems in from the pane's
/// edges (the bottom first, the top last) and out from a few flaws, each sprouting side branches, fishbone at 60
/// degrees or feathery at a shallow angle, with smaller ones off those. Every tip stops short of other ice, as
/// vapour screening makes real ones do, so branches never cross. The bake is a texture of when each texel freezes,
/// as a fraction of the growth (R + G/255, carried off the ice so it filters smoothly and the grey fill can creep
/// in behind), and how strong the ice is there (B); the shader reveals it by the frost's progress and melts it by
/// running that backwards, last grown first. After research prototypes of diffusion-limited aggregation and a
/// phase field, which looked like coral and snowflakes; see docs/rain-on-glass.md.
enum RainFrost {
    /// Screen heights per millimetre: the screen shows 20 cm of glass.
    private static let mm = 0.005

    /// How one nucleus's crystals branch.
    private struct Style {
        var angle: Double, spacing: (Double, Double), speed: [Double], gap: [Double]
        var length: (ClosedRange<Double>, ClosedRange<Double>, ClosedRange<Double>), sprout: (Double, Double), follow: Double
        /// Side branches at 60 degrees, a comb of them down each stem.
        static let fishbone = Style(angle: .pi / 3, spacing: (1.0 * mm, 0.6 * mm), speed: [1, 0.55, 0.35], gap: [1.0 * mm, 0.7 * mm, 0.5 * mm],
                                    length: (0.12...0.55, 6 * mm...22 * mm, 1 * mm...4 * mm), sprout: (0.95, 0.7), follow: 0.3)
        /// Dense needles at a shallow angle, sweeping round with their stem.
        static func feather(_ angle: Double) -> Style {
            Style(angle: angle, spacing: (0.25 * mm, 0.5 * mm), speed: [1, 0.8, 0.3], gap: [0.8 * mm, 0.2 * mm, 0.3 * mm],
                  length: (0.1...0.45, 8 * mm...30 * mm, 0.5 * mm...1.5 * mm), sprout: (0.9, 0.2), follow: 0.9)
        }
    }

    /// A growing tip: where it is, its heading, its clock, and what it grows from.
    private struct Tip {
        var x, y, heading, t, speed: Double
        var generation: Int, id: Int32, ancestors: (Int32, Int32, Int32) // the last three, which it may touch
        var grown = 0.0, length: Double, nextBranch: Double, curl: Double, style: Style, grace: Double
    }

    /// The ice grown, as short segments, each with its branch and the times its ends froze.
    private struct Segments { var x0 = [Float](), y0 = [Float](), x1 = [Float](), y1 = [Float](), t0 = [Float](), t1 = [Float](), branch = [Int32]() }

    /// RGBA bytes for `width`×`height` texels over the whole screen, bottom row first: R + G/255 when the texel
    /// freezes (1 is when the last ice does, carried off the ice up to 1.3), B the ice's strength there, and A that
    /// blurred over a few texels, the soft fur of real frost. About 0.2 s at 2048×1332 on an M3 Max.
    nonisolated static func bake(seed: UInt64, width: Int, height: Int) -> [UInt8] {
        let (segments, generations, ends) = grow(seed: seed, aspect: Double(width) / Double(height))
        let (time, strength) = rasterize(segments, generations: generations, ends: ends, width: width, height: height)
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        let halo = blur(blur(strength, width, height), width, height)
        for k in 0..<width * height {
            let q = min(max(Double(time[k]) / 1.3, 0), 1) * 255, hi = q.rounded(.down)
            bytes[k * 4] = UInt8(hi)
            bytes[k * 4 + 1] = UInt8(((q - hi) * 255).rounded())
            bytes[k * 4 + 2] = UInt8(min(max(strength[k], 0), 1) * 255)
            bytes[k * 4 + 3] = UInt8(min(max(halo[k] * 2, 0), 1) * 255)
        }
        return bytes
    }

    /// A box blur 7 texels wide, across then down; twice is close to a Gaussian.
    private static func blur(_ v: [Float], _ w: Int, _ h: Int) -> [Float] {
        var across = v, out = v
        for row in 0..<h {
            var sum: Float = 0
            for col in -3..<(w + 3) {
                if col + 3 < w { sum += v[row * w + col + 3] }
                if col - 4 >= 0 { sum -= v[row * w + col - 4] }
                if col >= 0, col < w { across[row * w + col] = sum / 7 }
            }
        }
        for col in 0..<w {
            var sum: Float = 0
            for row in -3..<(h + 3) {
                if row + 3 < h { sum += across[(row + 3) * w + col] }
                if row - 4 >= 0 { sum -= across[(row - 4) * w + col] }
                if row >= 0, row < h { out[row * w + col] = sum / 7 }
            }
        }
        return out
    }

    /// Grows the frost, 0.4 mm a step for the fastest tips, until every tip has stopped.
    private static func grow(seed: UInt64, aspect: Double) -> (Segments, [Int8], [Float]) {
        var rng = SplitMix(state: seed)
        func random(_ range: ClosedRange<Double>) -> Double { Double.random(in: range, using: &rng) }
        func normal(_ sd: Double) -> Double { sd * (-2 * log(random(1e-12...1))).squareRoot() * cos(2 * .pi * random(0...1)) }
        let cell = 0.5 * mm, gw = Int(aspect / cell) + 2, gh = Int(1 / cell) + 2
        var owner = [Int32](repeating: -1, count: gw * gh)                 // which branch holds each 0.5 mm cell
        var generations: [Int8] = [], tips: [Tip] = [], segments = Segments()
        func style() -> Style { random(0...1) < 0.5 ? .feather(random(0.3...0.6)) : .fishbone }
        func stem(_ x: Double, _ y: Double, _ heading: Double, _ t: Double, _ speed: Double, _ length: Double, _ curl: Double, _ style: Style) {
            tips.append(Tip(x: x, y: y, heading: heading, t: t, speed: speed, generation: 0, id: Int32(generations.count), ancestors: (-1, -1, -1),
                            length: length, nextBranch: style.spacing.0 * random(0.5...1.2), curl: curl, style: style, grace: 1.2 * mm))
            generations.append(0)
        }
        // the frame: stems every few mm, aimed inward, the bottom (the coldest glass) first and the top last,
        // then a dense fringe of short ones
        let edges: [(at: (Double) -> (Double, Double), inward: Double, length: Double, every: ClosedRange<Double>, start: ClosedRange<Double>)] = [
            ({ ($0 * aspect, 0) }, .pi / 2, aspect, 2 * mm...6 * mm, 0...0.04),
            ({ (0, $0) }, 0, 1, 4 * mm...10 * mm, 0.02...0.15),
            ({ (aspect, $0) }, .pi, 1, 4 * mm...10 * mm, 0.02...0.15),
            ({ ($0 * aspect, 1) }, -.pi / 2, aspect, 6 * mm...20 * mm, 0.1...0.3),
        ]
        for edge in edges {
            var u = random(edge.every) / 2
            while u < edge.length {
                let (x, y) = edge.at(u / edge.length), look = style()
                stem(x, y, edge.inward + normal(0.5), random(edge.start), random(0.7...1.3), random(look.length.0), normal(2), look)
                u += random(edge.every)
            }
            u = 0
            while u < edge.length {
                let (x, y) = edge.at(u / edge.length)
                stem(x, y, edge.inward + normal(0.6), random(edge.start), random(0.3...0.6), random(1 * mm...7 * mm), 0, style())
                u += random(1.2 * mm...2.5 * mm)
            }
        }
        // flaws in the glass: stars along one crystal's six directions
        for _ in 0..<Int.random(in: 4...8, using: &rng) {
            let x = random(0.1...(aspect - 0.1)), y = random(0.1...0.9), t = random(0.05...0.5), turn = random(0...(.pi / 3)), look = style()
            for k in 0..<6 where random(0...1) < 0.75 {
                stem(x, y, turn + Double(k) * .pi / 3 + normal(0.12), t, random(0.6...1.1), random(0.04...0.2), normal(2), look)
            }
        }

        let dt = 0.4 * mm, wander = [1.0, 0.35, 0.35]
        var now = 0.0, active = tips, next: [Tip] = []
        while !active.isEmpty {
            now += dt
            next.removeAll(keepingCapacity: true)
            for var tip in active {
                if tip.t > now { next.append(tip); continue }
                let look = tip.style, step = tip.speed * dt
                tip.heading += tip.curl * step + wander[tip.generation] * step.squareRoot() * normal(1)
                let c = cos(tip.heading), s = sin(tip.heading), nx = tip.x + step * c, ny = tip.y + step * s
                var stop = !(0...aspect).contains(nx) || !(0...1).contains(ny) || tip.grown >= tip.length
                if !stop, tip.grown > tip.grace {
                    // other ice just ahead, or a little to either side, stops it
                    let gap = look.gap[tip.generation]
                    for (ahead, side) in [(1.0, 0.0), (0.5, 0.0), (0.6, 0.5), (0.6, -0.5)] {
                        let cx = Int((nx + gap * (ahead * c - side * s)) / cell), cy = Int((ny + gap * (ahead * s + side * c)) / cell)
                        guard cx >= 0, cx < gw, cy >= 0, cy < gh else { continue }
                        let o = owner[cy * gw + cx]
                        if o >= 0, o != tip.id, o != tip.ancestors.0, o != tip.ancestors.1, o != tip.ancestors.2 { stop = true; break }
                    }
                }
                if stop { continue }
                let t1 = tip.t + dt
                segments.x0.append(Float(tip.x)); segments.y0.append(Float(tip.y)); segments.x1.append(Float(nx)); segments.y1.append(Float(ny))
                segments.t0.append(Float(tip.t)); segments.t1.append(Float(t1)); segments.branch.append(tip.id)
                owner[Int(ny / cell) * gw + Int(nx / cell)] = tip.id
                owner[Int((tip.y + ny) / 2 / cell) * gw + Int((tip.x + nx) / 2 / cell)] = tip.id
                tip.grown += step
                if tip.generation < 2, tip.grown >= tip.nextBranch {
                    for side in [-1.0, 1.0] where random(0...1) < (tip.generation == 0 ? look.sprout.0 : look.sprout.1) {
                        // now and then a side branch off a stem grows into a stem of its own
                        let generation = tip.generation == 0 && random(0...1) < 0.03 ? 0 : tip.generation + 1
                        let speed = tip.speed * (generation == 0 ? 0.85 : look.speed[generation] / look.speed[tip.generation])
                        let length = generation == 0 ? 0.5 * random(look.length.0)
                            : random(generation == 1 ? look.length.1 : look.length.2) * exp(normal(0.35))
                        next.append(Tip(x: nx, y: ny, heading: tip.heading + side * look.angle + normal(0.05), t: t1, speed: speed,
                                        generation: generation, id: Int32(generations.count), ancestors: (tip.id, tip.ancestors.0, tip.ancestors.1),
                                        length: length * tip.speed.squareRoot(), nextBranch: (generation == 0 ? look.spacing.0 : look.spacing.1) * random(0.5...1.2),
                                        curl: tip.curl * look.follow, style: look, grace: 0.6 * mm))
                        generations.append(Int8(generation))
                    }
                    tip.nextBranch = tip.grown + (tip.generation == 0 ? look.spacing.0 : look.spacing.1) * random(0.6...1.4)
                }
                tip.x = nx; tip.y = ny; tip.t = t1
                next.append(tip)
            }
            swap(&active, &next)
        }
        var ends = [Float](repeating: 0, count: generations.count)
        for i in segments.branch.indices { ends[Int(segments.branch[i])] = max(ends[Int(segments.branch[i])], segments.t1[i]) }
        return (segments, generations, ends)
    }

    /// Draws the segments as antialiased capsules, thinner by generation and tapering over a branch's last 2 mm,
    /// each texel keeping the time the ice nearest it froze. Then carries that time off the ice with an exact
    /// distance transform (Felzenszwalb & Huttenlocher), adding a growth-time unit per 0.25 screen heights, so the
    /// field is smooth everywhere. Returns times scaled so the last ice is 1, and strengths.
    private static func rasterize(_ s: Segments, generations: [Int8], ends: [Float], width w: Int, height h: Int) -> ([Float], [Float]) {
        let texel = 1 / Float(h), widths = [0.5, 0.3, 0.2].map { Float($0 * mm) }, speeds: [Float] = [1, 0.55, 0.35]
        var strength = [Float](repeating: 0, count: w * h), time = [Float](repeating: .infinity, count: w * h)
        var rng = SplitMix(state: 7)
        let jitter = generations.map { _ in Float.random(in: 0.6...1, using: &rng) }
        for i in s.branch.indices {
            let b = Int(s.branch[i]), g = Int(generations[b])
            let left = (ends[b] - s.t1[i]) * speeds[g] / Float(2 * mm)
            let wide = widths[g] * min(max(0.35 + left, 0.35), 1) / texel, reach = wide / 2 + 1
            let bright = [Float(1), 0.85, 0.7][g] * jitter[b] * min(wide, 1)
            let ax = s.x0[i] / texel, ay = s.y0[i] / texel, bx = s.x1[i] / texel, by = s.y1[i] / texel
            let dx = bx - ax, dy = by - ay, length2 = max(dx * dx + dy * dy, 1e-6)
            for row in max(0, Int(min(ay, by) - reach))...min(h - 1, Int(max(ay, by) + reach)) {
                for col in max(0, Int(min(ax, bx) - reach))...min(w - 1, Int(max(ax, bx) + reach)) {
                    let qx = Float(col) + 0.5 - ax, qy = Float(row) + 0.5 - ay
                    let f = min(max((qx * dx + qy * dy) / length2, 0), 1)
                    let ex = qx - f * dx, ey = qy - f * dy
                    let cover = min(max(wide / 2 + 0.5 - (ex * ex + ey * ey).squareRoot(), 0), 1)
                    if cover <= 0 { continue }
                    let k = row * w + col
                    strength[k] = max(strength[k], cover * bright)
                    time[k] = min(time[k], s.t0[i] + f * (s.t1[i] - s.t0[i]))
                }
            }
        }
        // the distance to the nearest ice, and which texel that is: columns, then rows
        var distance = [Float](repeating: 0, count: w * h), nearest = [Int32](repeating: -1, count: w * h)
        let far: Float = 1e20
        func pass(_ n: Int, _ f: (Int) -> Float, _ from: (Int) -> Int32, _ out: (Int, Float, Int32) -> Void) {
            var v = [Int](repeating: 0, count: n), z = [Float](repeating: 0, count: n + 1), k = 0
            let fs = (0..<n).map(f)
            guard let first = fs.firstIndex(where: { $0 < far }) else { for q in 0..<n { out(q, far, -1) }; return }
            v[0] = first; z[0] = -.infinity; z[1] = .infinity
            for q in (first + 1)..<max(n, first + 1) where fs[q] < far {
                func meet() -> Float { ((fs[q] + Float(q * q)) - (fs[v[k]] + Float(v[k] * v[k]))) / Float(2 * q - 2 * v[k]) }
                var sx = meet()
                while sx <= z[k] { k -= 1; sx = meet() }
                k += 1; v[k] = q; z[k] = sx; z[k + 1] = .infinity
            }
            k = 0
            for q in 0..<n {
                while z[k + 1] < Float(q) { k += 1 }
                out(q, Float((q - v[k]) * (q - v[k])) + fs[v[k]], from(v[k]))
            }
        }
        for col in 0..<w {
            pass(h, { time[$0 * w + col].isFinite ? 0 : far }, { Int32($0 * w + col) }) { row, d, n in
                distance[row * w + col] = d; nearest[row * w + col] = n
            }
        }
        let columns = distance, owners = nearest
        for row in 0..<h {
            pass(w, { columns[row * w + $0] }, { owners[row * w + $0] }) { col, d, n in distance[row * w + col] = d; nearest[row * w + col] = n }
        }
        let last = time.filter(\.isFinite).max() ?? 1
        var carried = [Float](repeating: 1.3, count: w * h)
        for k in 0..<w * h where nearest[k] >= 0 { carried[k] = (time[Int(nearest[k])] + distance[k].squareRoot() * texel / 0.25) / last }
        return (carried, strength)
    }

    /// Textures already baked, by seed and size, and the ones baking.
    @MainActor private static var baked: [String: SKTexture] = [:], baking: Set<String> = []

    /// The frost for a screen of `size` points, or nil while it bakes off the main thread (it's asked again each
    /// second). One texel per 0.15 mm of glass, like 1.5 screen pixels.
    @MainActor static func texture(seed: UInt64, size: CGSize) -> SKTexture? {
        let h = min(1332, Int(size.height * 1.36)), w = Int((Double(h) * size.width / max(size.height, 1)).rounded())
        let key = "\(seed) \(w)×\(h)"
        if let texture = baked[key] { return texture }
        guard !baking.contains(key) else { return nil }
        baking.insert(key)
        Task {
            let bytes = await Task.detached(priority: .utility) { bake(seed: seed, width: w, height: h) }.value
            let texture = SKTexture(data: Data(bytes), size: CGSize(width: w, height: h))
            texture.filteringMode = .linear
            if baked.count > 3 { baked.removeAll() } // ponytail: only the latest few seeds and screens are ever in use
            baked[key] = texture
            baking.remove(key)
        }
        return nil
    }
}
