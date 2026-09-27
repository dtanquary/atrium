import SpriteKit

@MainActor func crystals(size: CGSize) -> SKScene { Crystals(size: size) }

/// Vitamin C crystallising on a microscope slide between polarisers, melting and growing again. Each cycle bakes a
/// new set of crystals (`bake`): where each nucleates and when, and so when its growth front reaches every point.
/// The shader reveals that as the growth runs, colours it by the physics of polarised light (`michelLevy`), holds it,
/// then melts it back to the liquid, last-grown first, and the next cycle nucleates in the dark.
/// Dark Mode is crossed polarisers (black liquid); Light Mode is parallel ones (white liquid, complementary colours).
final class Crystals: SKScene {
    nonisolated static let knobs = [
        Knob(key: "crystals.cycle", label: "Cycle length", range: 2...30, standard: 7, section: "Crystals", format: .minutes),
        Knob(key: "crystals.size", label: "Crystal size", range: 0.5...2, standard: 1, section: "Crystals", format: .times),
        Knob(key: "crystals.thickness", label: "Thickness", range: 0.3...3, standard: 1, section: "Look", format: .times),
        Knob(key: "crystals.brightness", label: "Brightness", range: 0.3...1.5, standard: 1, section: "Look"),
        Knob(key: "crystals.stop", label: "Round field stop", range: 0...1, standard: 0, section: "Look", format: .toggle),
    ]

    /// A cycle, as fractions of its length: growing from 0 (about 3½ minutes of 7, the speed real ascorbic acid
    /// grows at), holding, melting from `meltAt` about four times as fast as it grew, then bare liquid until 1.
    private static let growPart = 0.55, meltAt = 0.82, meltPart = 0.15

    private var progress = Double(ProcessInfo.processInfo.environment["CRYSTALS_AT"] ?? "") ?? 0.3
    private var meltStart = meltAt, meltLength = meltPart
    private var bakedSize = 0.0
    private var next: Slide?, baking = false // the next cycle's crystals, baked in the background during the melt
    private var lastTime: TimeInterval?
    private var textures: [SKMutableTexture] = []
    private let grow = SKUniform(name: "u_grow", float: 0), level = SKUniform(name: "u_level", float: 2)
    private let scale = SKUniform(name: "u_scale", float: 1)
    private let thickness = SKUniform(name: "u_thickness", float: 1), brightness = SKUniform(name: "u_brightness", float: 1)
    private let stop = SKUniform(name: "u_stop", float: 0)

    override func sceneDidLoad() {
        backgroundColor = .black
        let texels = CGSize(width: (size.width / Self.cell).rounded(.up), height: (size.height / Self.cell).rounded(.up))
        textures = (0..<3).map { _ in SKMutableTexture(size: texels) }
        // Linear filtering blends everything smoothly, except the nucleus a texel belongs to: blending two crystals'
        // nuclei at a boundary gives a meaningless one, so each pixel takes its nearest texel's, and the boundary's
        // groove covers the step that leaves.
        textures[0].filteringMode = .linear
        textures[2].filteringMode = .linear
        var rng = SplitMix(state: UInt64(ProcessInfo.processInfo.environment["CRYSTALS_SEED"] ?? "") ?? .random(in: 0...UInt64.max))
        show(Self.bake(texels: texels, size: size, crystalSize: Self.knobs[1].value, rng: &rng))

        let lut = Self.michelLevy().flatMap { c in [c.x, c.y, c.z].map { UInt8(min(1, pow($0, 1 / 2.2)) * 255) } + [255] }
        let chart = SKTexture(data: Data(lut), size: CGSize(width: lut.count / 4, height: 1))
        chart.filteringMode = .linear
        let slide = SKSpriteNode(color: .black, size: size)
        slide.anchorPoint = .zero
        slide.shader = SKShader(source: Self.shader, uniforms: [
            SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)]),
            SKUniform(name: "u_growth", texture: textures[0]), SKUniform(name: "u_nucleus", texture: textures[1]),
            SKUniform(name: "u_marks", texture: textures[2]), SKUniform(name: "u_chart", texture: chart),
            SKUniform(name: "u_dark", float: systemIsDark ? 1 : 0), grow, level, scale, thickness, brightness, stop,
        ])
        addChild(slide)
        update(0)
    }

    override func update(_ currentTime: TimeInterval) {
        progress += frameTime(currentTime, &lastTime) / (Self.knobs[0].value * 60)
        // a new crystal size melts these quickly now, and the next cycle grows the new size
        if Self.knobs[1].value != bakedSize, progress < meltStart { (meltStart, meltLength) = (progress, 0.04) }
        if let slide = next, slide.crystalSize != Self.knobs[1].value { next = nil }
        if progress >= meltStart, next == nil, !baking { bakeNext() }
        let end = meltStart + meltLength + 1 - Self.meltAt - Self.meltPart
        if progress >= end {
            if let slide = next { // else wait in the dark until it's baked
                (progress, meltStart, meltLength, next) = (0, Self.meltAt, Self.meltPart, nil)
                show(slide)
            } else {
                progress = end
            }
        }
        let grown = min(progress, meltStart) / Self.growPart, melted = min(max(0, progress - meltStart) / meltLength, 1)
        grow.floatValue = Float(grown)
        // the melt runs back down the arrival times, from just above the last grown (so nothing jumps) to below 0
        level.floatValue = melted > 0 ? Float((min(grown, 1) + 0.15) * (1 - melted) - 0.08) : 2
        thickness.floatValue = Float(Self.knobs[2].value)
        brightness.floatValue = Float(Self.knobs[3].value)
        stop.floatValue = Float(Self.knobs[4].value)
    }

    /// Bakes the next cycle's crystals off the main thread.
    private func bakeNext() {
        baking = true
        let texels = textures[0].size(), size = size, crystalSize = Self.knobs[1].value, seed = UInt64.random(in: 0...UInt64.max)
        Task { [weak self] in
            let slide = await Task.detached(priority: .utility) {
                var rng = SplitMix(state: seed)
                return Crystals.bake(texels: texels, size: size, crystalSize: crystalSize, rng: &rng)
            }.value
            self?.next = slide
            self?.baking = false
        }
    }

    /// Puts baked crystals on the slide.
    private func show(_ slide: Slide) {
        bakedSize = slide.crystalSize
        scale.floatValue = Float(slide.spacing)
        for (texture, bytes) in zip(textures, [slide.growth, slide.nucleus, slide.marks]) {
            texture.modifyPixelData { pixels, length in
                bytes.withUnsafeBytes { pixels?.copyMemory(from: $0.baseAddress!, byteCount: min(length, $0.count)) }
            }
        }
    }

    /// Points per texel of the baked textures. The crystals' fine fibres are drawn by the shader, not baked.
    private static let cell: CGFloat = 2

    /// One crystal: where and when it nucleates, how fast its front moves in each direction, how long it can keep
    /// growing before the liquid runs out of material, and how thick it is.
    private struct Nucleus {
        var x, y, born: Double
        var speed: [Double] // points per unit of growth time, in 64 directions around
        var reach: [Double] // growth time until it stops, in the same directions (1e6 if it never does)
        var retard, slope: Double
        var bands: [Double] // how the growth bands wander around the circle, as a factor on distance
    }

    /// One cycle's crystals, baked: three RGBA textures, and the typical crystal's size in points.
    struct Slide: Sendable {
        var growth, nucleus, marks: [UInt8]
        var spacing, crystalSize: Double
    }

    /// One cycle's crystals as three RGBA textures, `texels` in size, plus the typical crystal's size in points.
    /// SpriteKit's mutable textures only take bytes, so a value that needs more than 8 bits is split over two
    /// channels as v = hi + lo/255: linear filtering is linear in each channel, so the shader's sum is the
    /// filtered value at 16-bit precision.
    /// - `growth`: when the front arrives, as a fraction of the growth ×0.95 (up to 1 in the liquid); retardation, as
    ///   a coordinate into `michelLevy`.
    /// - `nucleus`: where the crystal's nucleus is, x then y, as fractions of the screen (+0.25, /1.5).
    /// - `marks`: distance to the boundary with another crystal (0–8 points, for its groove); a shade for the
    ///   thin growth bands of banded crystals; and the signed distance to the rim where the crystal stops (−8 to 8
    ///   points, +0.5 as 0.5), which is negative in the liquid beyond.
    ///
    /// Nuclei follow Johnson–Mehl: most form in the open liquid early on, a few more later and some on the rims of
    /// crystals already growing, and each front moves at a steady speed until it meets another (a straight boundary
    /// if they were born together, a curve if not) or runs out of material (a rim, with the liquid dark beyond).
    /// ponytail: every texel checks every nucleus, ~0.2 s at the standard size and 0.8 s at the smallest (release, 14"
    /// screen). Only the first slide bakes on the main thread; a coarse grid of candidate nuclei would cut it.
    nonisolated static func bake(texels: CGSize, size: CGSize, crystalSize: Double, rng: inout SplitMix) -> Slide {
        func random(_ range: ClosedRange<Double>) -> Double { Double.random(in: range, using: &rng) }
        let w = Int(texels.width), h = Int(texels.height), sx = size.width / Double(w), sy = size.height / Double(h)
        let spacing = 0.36 * size.height * crystalSize, turns = 64

        /// A smooth random wobble around the circle, `amount` either side of 1.
        func around(_ amount: Double, harmonics: ClosedRange<Int>) -> [Double] {
            let waves: [(k: Double, phase: Double, a: Double)] = (0..<5).map { _ in
                (Double(Int.random(in: harmonics, using: &rng)), random(0...(2 * .pi)), random(0.3...1))
            }
            let total = waves.reduce(0.0) { $0 + $1.a }
            return (0..<turns).map { i in
                let angle = 2 * .pi * Double(i) / Double(turns)
                let sum = waves.reduce(0.0) { $0 + $1.a * sin($1.k * angle + $1.phase) }
                return 1 + amount * sum / total
            }
        }

        // One tint dominates each slide, as in real micrographs, from how thick the film dried: first-order grey-white
        // (1–2 µm), straw and gold (3 µm), or now and then the second order's violet, blue and sky (4–5 µm).
        let tint = [120.0...280, 280...450, 280...450, 280...450, 480...720].randomElement(using: &rng)!
        let limited = random(0...1) < 0.75 // the crystals stop short of each other, leaving pools of liquid
        let banded = random(0...1) < 0.3 ? random(0.2...0.45) : 0, bandPeriod = spacing * random(0.06...0.12)
        let film = (0..<5).map { _ in (k: 2 * .pi / (size.height * random(0.6...2)), a: random(0...(2 * .pi)), phase: random(0...(2 * .pi))) }

        func nucleus(x: Double, y: Double, born: Double, axis: Double, fan: Double, slope: ClosedRange<Double>) -> Nucleus {
            let speed = exp(random(-0.15...0.15)) * spacing, stretch = random(0...0.35), lobes = around(random(0.04...0.08), harmonics: 6...14)
            let reach = limited ? random(0.45...0.8) : 1e6, fingers = around(0.035, harmonics: 8...24)
            return Nucleus(x: x, y: y, born: born, speed: (0..<turns).map { i in
                let a = 2 * .pi * Double(i) / Double(turns) - axis
                return speed * lobes[i] * (1 - stretch * sin(a) * sin(a)) * (1 - fan * (1 - cos(a)) / 2)
            }, reach: fingers.map { reach * $0 }, retard: random(tint) / michelLevyRange, slope: random(slope),
                            bands: around(0.08, harmonics: 3...12))
        }
        /// Growth time for `n`'s front to reach (dx, dy) from it, and how long it could keep going there.
        func arrival(_ n: Nucleus, _ dx: Double, _ dy: Double) -> (time: Double, left: Double) {
            let f = (atan2(dy, dx) / (2 * .pi) + 1) * Double(turns), i = Int(f) % turns, j = (i + 1) % turns, t = f - f.rounded(.down)
            let speed = n.speed[i] + (n.speed[j] - n.speed[i]) * t, reach = n.reach[i] + (n.reach[j] - n.reach[i]) * t
            let time = (dx * dx + dy * dy).squareRoot() / speed
            return (n.born + time, reach - time)
        }
        func firstArrival(_ nuclei: [Nucleus], _ x: Double, _ y: Double) -> Double {
            nuclei.map { arrival($0, x - $0.x, y - $0.y) }.filter { $0.left >= 0 }.map(\.time).min() ?? .infinity
        }

        // Nuclei in the open, half at once and the rest tailing off, each thickest over its centre; sometimes one
        // well ahead of the rest. Then a few on the rims of growing crystals, growing outward as fans paler at the root.
        let margin = 0.15, count = Int((1 + 2 * margin) * (1 + 2 * margin) * size.width * size.height / (spacing * spacing))
        var nuclei: [Nucleus] = []
        for k in 0..<max(count * 2 / 3, 2) {
            let x = random(-margin...(1 + margin)) * size.width, y = random(-margin...(1 + margin)) * size.height
            let born = k == 0 && random(0...1) < 0.5 ? -0.12 : random(0...1) < 0.5 ? random(0...0.05) : min(-0.19 * log(random(0.001...1)), 0.42)
            if firstArrival(nuclei, x, y) > born {
                nuclei.append(nucleus(x: x, y: y, born: born, axis: random(0...(2 * .pi)), fan: random(0...0.3), slope: -0.45...0.15))
            }
        }
        for _ in 0..<count / 4 {
            let parent = nuclei.randomElement(using: &rng)!, a = random(0...(2 * .pi))
            let (time, left) = arrival(parent, cos(a), sin(a)) // growth time per point of distance, and to where it stops
            let stops = left + time - parent.born, born = parent.born + min(random(0.1...0.4), stops + random(0.1...0.2))
            let r = min(born - parent.born, stops) / (time - parent.born) + 3
            let x = parent.x + r * cos(a), y = parent.y + r * sin(a)
            if firstArrival(nuclei, x, y) > born { nuclei.append(nucleus(x: x, y: y, born: born, axis: a, fan: random(0.5...0.9), slope: 0...0.4)) }
        }
        let earliest = nuclei.map(\.born).min()!, fastest = nuclei.flatMap(\.speed).max()!

        // Per texel: the first front to arrive, the one after it (the boundary is where they tie), and the owner's rim.
        var growth = [UInt8](repeating: 0, count: w * h * 4), place = growth, marks = growth
        var arrivals = [Double](repeating: 0, count: w * h)
        func put(_ bytes: inout [UInt8], _ i: Int, _ v: Double) {
            let q = min(max(v, 0), 1) * 255, hi = q.rounded(.down)
            bytes[i] = UInt8(hi)
            bytes[i + 1] = UInt8(((q - hi) * 255).rounded())
        }
        var latest = 0.0
        for row in 0..<h {
            let y = (Double(row) + 0.5) * sy
            for col in 0..<w {
                let x = (Double(col) + 0.5) * sx
                var first = Double.infinity, second = Double.infinity, owner = 0, rival = 0, rim = 0.0
                var soonest = Double.infinity, nearest = 0, short = 0.0 // the front that would get here first if nothing stopped
                for (k, n) in nuclei.enumerated() {
                    let dx = x - n.x, dy = y - n.y
                    if n.born + (dx * dx + dy * dy).squareRoot() / fastest >= max(second, soonest) { continue }
                    let (time, left) = arrival(n, dx, dy)
                    if time < soonest { (soonest, nearest, short) = (time, k, left) }
                    guard left >= 0 else { continue }
                    if time < first { (second, rival, first, owner, rim) = (first, owner, time, k, left) } else if time < second { (second, rival) = (time, k) }
                }
                // Liquid past a crystal's rim takes on the crystal that stopped nearest, so every field runs on
                // smoothly across the rim and the rim itself is where the signed distance to it crosses 0.
                if !first.isFinite { (first, owner, rim) = (soonest, nearest, short) } else { latest = max(latest, first) }
                let i = row * w + col, n = nuclei[owner]
                put(&place, i * 4, (n.x / size.width + 0.25) / 1.5)
                put(&place, i * 4 + 2, (n.y / size.height + 0.25) / 1.5)
                arrivals[i] = first
                marks[i * 4 + 2] = UInt8((min(max(rim * spacing / 16, -0.5), 0.5) + 0.5) * 255)
                let d = ((x - n.x) * (x - n.x) + (y - n.y) * (y - n.y)).squareRoot()
                let thick = 1 + 0.1 * film.reduce(0) { $0 + sin($1.k * (x * cos($1.a) + y * sin($1.a)) + $1.phase) } / Double(film.count) * 2.2
                let retard = n.retard * thick * (1 + n.slope * (d / spacing - 0.5)) * (1 + 0.3 * exp(-max(rim, 0) * spacing / 3))
                put(&growth, i * 4 + 2, retard)
                let a = (atan2(y - n.y, x - n.x) / (2 * .pi) + 1) * Double(turns)
                let wander = n.bands[Int(a) % turns] + (n.bands[(Int(a) + 1) % turns] - n.bands[Int(a) % turns]) * (a - a.rounded(.down))
                let band = 0.5 + 0.5 * cos(2 * .pi * pow(d * wander / bandPeriod, 0.85)) // wavy, closer together further out
                // distance to the boundary: the gap between the two arrival times over how fast it widens across it
                let o = nuclei[rival], od = max(((x - o.x) * (x - o.x) + (y - o.y) * (y - o.y)).squareRoot(), 1e-6), dd = max(d, 1e-6)
                let pull = hypot((x - n.x) / dd - (x - o.x) / od, (y - n.y) / dd - (y - o.y) / od) / spacing
                marks[i * 4] = UInt8(min(second.isFinite ? (second - first) / max(pull, 1e-9) / 8 : 1, 1) * 255)
                marks[i * 4 + 1] = UInt8((1 - banded * pow(band, 12)) * 255)
                marks[i * 4 + 3] = 255
            }
        }
        for i in 0..<w * h { put(&growth, i * 4, 0.95 * (arrivals[i] - earliest) / (latest - earliest)) }
        return Slide(growth: growth, nucleus: place, marks: marks, spacing: spacing, crystalSize: crystalSize)
    }

    /// Retardation at the right-hand end of `michelLevy`, in nanometres.
    nonisolated static let michelLevyRange = 3000.0

    /// The Michel-Lévy chart: the colour of a crystal at 45° between crossed polarisers, for retardations of 0 to
    /// `michelLevyRange` nm in `n` steps, as linear sRGB where 1 is the lamp's white seen through parallel
    /// polarisers with no crystal. Each wavelength λ comes through as sin²(πΓ/λ) of a 3200 K halogen lamp; that
    /// spectrum is summed by the CIE 1931 observer (the multi-lobe fit of Wyman, Sloan and Shirley, JCGT 2013), turned
    /// into sRGB and white-balanced to the lamp, as a camera would. Colours outside sRGB (low-order yellows and
    /// violets) are desaturated toward their own luminance. Parallel polarisers show 1 minus this.
    /// ponytail: ignores the dispersion of birefringence, which shifts the high orders a little in real crystals.
    nonisolated static func michelLevy(_ n: Int = 1024) -> [SIMD3<Double>] {
        func lobe(_ x: Double, _ mu: Double, _ below: Double, _ above: Double) -> Double {
            let t = (x - mu) / (x < mu ? below : above)
            return exp(-t * t / 2)
        }
        let toRGB = [SIMD3(3.2406, -1.5372, -0.4986), SIMD3(-0.9689, 1.8758, 0.0415), SIMD3(0.0557, -0.2040, 1.0570)]
        let spectrum: [(l: Double, lamp: Double, xyz: SIMD3<Double>)] = stride(from: 380.0, through: 780, by: 5).map { l in
            let x: Double = 1.056 * lobe(l, 599.8, 37.9, 31.0) + 0.362 * lobe(l, 442.0, 16.0, 26.7) - 0.065 * lobe(l, 501.1, 20.4, 26.2)
            let y: Double = 0.821 * lobe(l, 568.8, 46.9, 40.5) + 0.286 * lobe(l, 530.9, 16.3, 31.1)
            let z: Double = 1.217 * lobe(l, 437.0, 11.8, 36.0) + 0.681 * lobe(l, 459.0, 26.0, 13.8)
            return (l, pow(l, -5) / (exp(1.4388e7 / (l * 3200)) - 1), SIMD3(x, y, z))
        }
        func rgb(_ transmit: (Double) -> Double) -> SIMD3<Double> {
            let xyz = spectrum.reduce(SIMD3<Double>()) { $0 + $1.xyz * $1.lamp * transmit($1.l) }
            return SIMD3(toRGB.map { ($0 * xyz).sum() })
        }
        let white = rgb { _ in 1 }
        return (0..<n).map { i in
            let retardation = michelLevyRange * Double(i) / Double(n - 1)
            let c = rgb { l in pow(sin(.pi * retardation / l), 2) } / white
            let luma = (c * SIMD3(0.2126, 0.7152, 0.0722)).sum(), low = c.min()
            return low < 0 ? simd_max(luma + (c - luma) * (luma / (luma - low)), .zero) : c
        }
    }

    /// Per pixel: the baked crystal under it, if its front has passed and it hasn't melted; the angle of its fibres,
    /// which point straight out from its nucleus, against the polarisers (brightness goes as sin² of twice that, so
    /// every crystal shows a dark cross along the polarisers, crisp at the centre and filling in toward the rim as the
    /// fibres splay); and its colour from the chart, by retardation. The colour thickens up behind the front, as the
    /// film deposits, and thins at a melting edge. Fine fibres, drawn here at screen resolution, branch as they spread
    /// so their spacing stays about the same.
    private static let shader = """
        float hashf(vec2 p) {
            vec3 q = fract(vec3(p.xyx) * 0.1031);
            q += dot(q, q.yzx + 33.33);
            return fract((q.x + q.y) * q.z);
        }
        float vnoise(vec2 p) {
            vec2 i = floor(p), f = fract(p), u = f * f * (3.0 - 2.0 * f);
            return mix(mix(hashf(i), hashf(i + vec2(1.0, 0.0)), u.x), mix(hashf(i + vec2(0.0, 1.0)), hashf(i + vec2(1.0, 1.0)), u.x), u.y);
        }
        void main() {
            vec2 pts = v_tex_coord * u_size;
            vec4 g = texture2D(u_growth, v_tex_coord), n = texture2D(u_nucleus, v_tex_coord), m = texture2D(u_marks, v_tex_coord);
            float arrive = (g.r + g.g / 255.0) / 0.95;
            vec2 off = pts - (vec2(n.r + n.g / 255.0, n.b + n.a / 255.0) * 1.5 - 0.25) * u_size;
            float r = length(off) + 0.001, th = atan(off.y, off.x), rs = r / u_scale;

            float age = u_grow - arrive, left = u_level - arrive + (vnoise(pts * 0.03) - 0.5) * 0.06;
            float rim = (m.b - 0.5) * 16.0;
            float solid = smoothstep(0.0, 0.004, min(u_grow, 1.01) - arrive) * smoothstep(0.0, 0.006, left) * smoothstep(-0.5, 0.5, rim);

            float lv = log2(max(r, 6.0) / 6.0), fl = floor(lv);
            float k = 14.0 * exp2(fl);
            vec2 seed = off - pts; // the nucleus, so each crystal has its own fibres
            float fib = mix(vnoise(vec2(th * k, r * 0.35) + seed * 0.37), vnoise(vec2(th * k * 2.0, r * 0.35) + seed * 0.37 + 31.0), lv - fl);
            fib = fib * 0.75 + 0.25 * hashf(floor(vec2(th * k * 2.0, r * 0.5)) + seed);
            float wob = (vnoise(vec2(th * 3.0, r * 0.01) + seed) - 0.5) * 0.25 + (fib - 0.5) * 0.12;
            float ext = 0.5 - 0.5 * cos(4.0 * (th + wob)) * mix(0.9, 0.5, smoothstep(0.0, 0.6, rs));

            float gam = (g.b + g.a / 255.0) * u_thickness * (0.92 + 0.16 * fib)
                      * (0.55 + 0.45 * smoothstep(0.0, 0.12, age)) * smoothstep(0.0, 0.05, left);
            vec3 chart = pow(texture2D(u_chart, vec2(clamp(gam, 0.0, 1.0), 0.5)).rgb, vec3(2.2));
            float core = mix(0.3, 1.0, smoothstep(0.015, 0.045, rs + (vnoise(off * 0.4) - 0.5) * 0.02));
            float groove = smoothstep(0.1, 0.3, m.r);
            float fringe = 1.0 + 0.7 * exp(-max(rim, 0.0) / 0.8);
            vec3 lit = solid * ext * chart * (0.6 + 0.8 * fib) * m.g * groove * core * fringe;

            vec2 c = pts - 0.5 * u_size;
            float rr = length(c) / (0.47 * u_size.y);
            float field = mix(1.0, smoothstep(1.0, 0.985, rr), u_stop) * (1.0 - 0.12 * min(rr * rr, 1.5));
            vec3 col = u_dark > 0.5 ? (lit * 0.32 + vec3(0.0006, 0.0008, 0.0013)) * u_brightness : (1.0 - lit) * 0.8 * u_brightness;
            col = pow(max(col * field, 0.0), vec3(1.0 / 2.2)) + (hashf(pts * 3.7) - 0.5) / 255.0;
            gl_FragColor = vec4(col, 1.0);
        }
        """
}
