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
        Knob(key: "crystals.speed", label: "Growth speed", range: 0.25...4, standard: 1, section: "Crystals", format: .times),
        Knob(key: "crystals.size", label: "Crystal size", range: 0.5...2, standard: 1, section: "Crystals", format: .times),
        Knob(key: "crystals.thickness", label: "Thickness", range: 0.3...3, standard: 1, section: "Look", format: .times),
        Knob(key: "crystals.brightness", label: "Brightness", range: 0.3...1.5, standard: 1, section: "Look"),
        Knob(key: "crystals.stop", label: "Round field stop", range: 0...1, standard: 0, section: "Look", format: .toggle),
    ]

    /// A cycle: the slide grows for `growSeconds` at Growth speed 1 (the speed real ascorbic acid grows at: 5–7 µm/s
    /// fills a 10× field in 3–4 minutes), holds for whatever Cycle length leaves (at least `shortestHold`), melts about
    /// four times as fast as it grew, and rests as bare liquid for `restSeconds` before new seeds.
    private static let growSeconds = 230.0, meltShare = 0.27, restSeconds = 13.0, shortestHold = 20.0

    private var grown = 0.0 // 0–1 as the fronts spread, and on to 1.3 while the last colour thickens in
    private var held = 0.0, melted = 0.0, rested = 0.0 // seconds, 0–1, seconds
    private var quickMelt = false // a new crystal size melts these in seconds
    private var bakedSize = 0.0
    private var next: Slide?, baking = false // the next cycle's crystals, baked in the background during the melt
    private var lastTime: TimeInterval?
    private var textures: [SKMutableTexture] = []
    private let grow = SKUniform(name: "u_grow", float: 0), level = SKUniform(name: "u_level", float: 2)
    private let scale = SKUniform(name: "u_scale", float: 1)
    private let thickness = SKUniform(name: "u_thickness", float: 1), brightness = SKUniform(name: "u_brightness", float: 1)
    private let stop = SKUniform(name: "u_stop", float: 0)

    private static func knob(_ name: String) -> Double { knobs.first { $0.key == "crystals." + name }!.value }

    override func sceneDidLoad() {
        backgroundColor = .black
        let texels = CGSize(width: (size.width / Self.cell).rounded(.up), height: (size.height / Self.cell).rounded(.up))
        textures = (0..<3).map { _ in SKMutableTexture(size: texels) }
        // Linear filtering blends everything smoothly, except the nucleus a texel belongs to: blending two crystals'
        // nuclei at a boundary gives a meaningless one, so the shader reads the four around each pixel and blends
        // what each crystal would show there instead.
        textures[0].filteringMode = .linear
        textures[2].filteringMode = .linear
        var rng = SplitMix(state: UInt64(ProcessInfo.processInfo.environment["CRYSTALS_SEED"] ?? "") ?? .random(in: 0...UInt64.max))
        show(Self.bake(texels: texels, size: size, crystalSize: Self.knob("size"), rng: &rng))
        // start partway into the cycle, growth about half done (or where CRYSTALS_AT, a fraction of the cycle, says)
        let at = Double(ProcessInfo.processInfo.environment["CRYSTALS_AT"] ?? "") ?? 0.3
        for _ in 0..<Int(at * Self.knob("cycle") * 60) { advance(1) }

        let lut = Self.michelLevy().flatMap { c in [c.x, c.y, c.z].map { UInt8(min(1, pow($0, 1 / 2.2)) * 255) } + [255] }
        let chart = SKTexture(data: Data(lut), size: CGSize(width: lut.count / 4, height: 1))
        chart.filteringMode = .linear
        let slide = SKSpriteNode(color: .black, size: size)
        slide.anchorPoint = .zero
        slide.shader = SKShader(source: Self.shader, uniforms: [
            SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)]),
            SKUniform(name: "u_texels", vectorFloat2: [Float(texels.width), Float(texels.height)]),
            SKUniform(name: "u_growth", texture: textures[0]), SKUniform(name: "u_nucleus", texture: textures[1]),
            SKUniform(name: "u_marks", texture: textures[2]), SKUniform(name: "u_chart", texture: chart),
            SKUniform(name: "u_dark", float: systemIsDark ? 1 : 0), grow, level, scale, thickness, brightness, stop,
        ])
        addChild(slide)
        update(0)
    }

    override func update(_ currentTime: TimeInterval) {
        advance(frameTime(currentTime, &lastTime))
        grow.floatValue = Float(grown)
        // the melt runs back down the arrival times, from just above the last grown (so nothing jumps) to below 0
        level.floatValue = melted > 0 ? Float((min(grown, 1) + 0.15) * (1 - melted) - 0.08) : 2
        thickness.floatValue = Float(Self.knob("thickness"))
        brightness.floatValue = Float(Self.knob("brightness"))
        stop.floatValue = Float(Self.knob("stop"))
    }

    /// Moves the cycle on by `dt` seconds. Each part runs at its own rate from the current settings, so moving a
    /// slider changes the pace from here on without jumping.
    private func advance(_ dt: Double) {
        let growTime = Self.growSeconds / Self.knob("speed"), meltTime = quickMelt ? 17 : growTime * Self.meltShare
        let hold = max(Self.knob("cycle") * 60 - growTime * (1 + Self.meltShare) - Self.restSeconds, Self.shortestHold)
        // a new crystal size melts these quickly now, and the next cycle grows the new size
        if Self.knob("size") != bakedSize, melted == 0 { (quickMelt, melted) = (true, 1e-9) }
        if melted == 0 {
            grown = min(grown + dt / growTime, 1.3)
            if grown >= 1 { held += dt }
            if held >= hold { melted = 1e-9 }
        } else if melted < 1 {
            melted = min(melted + dt / meltTime, 1)
        } else {
            rested += dt
        }
        if let slide = next, slide.crystalSize != Self.knob("size") { next = nil }
        if melted > 0, next == nil, !baking { bakeNext() }
        if rested >= Self.restSeconds, let slide = next { // else wait in the dark until it's baked
            (grown, held, melted, rested, quickMelt, next) = (0, 0, 0, 0, false, nil)
            show(slide)
        }
    }

    /// Bakes the next cycle's crystals off the main thread.
    private func bakeNext() {
        baking = true
        let texels = textures[0].size(), size = size, crystalSize = Self.knob("size"), seed = UInt64.random(in: 0...UInt64.max)
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
        let banded = random(0...1) < 0.25 ? random(0.15...0.3) : 0, bandPeriod = spacing * random(0.06...0.12)
        let film = (0..<5).map { _ in (k: 2 * .pi / (size.height * random(0.6...2)), a: random(0...(2 * .pi)), phase: random(0...(2 * .pi))) }

        func nucleus(x: Double, y: Double, born: Double, axis: Double, fan: Double, slope: ClosedRange<Double>) -> Nucleus {
            let speed = exp(random(-0.15...0.15)) * spacing, stretch = random(0...0.35), lobes = around(random(0.04...0.08), harmonics: 6...14)
            let reach = limited ? random(0.45...0.8) : 1e6, fingers = around(0.025, harmonics: 5...12)
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
                var first = Double.infinity, second = Double.infinity, owner = 0, rival = 0, rim = 0.0, rivalRim = 0.0
                var soonest = Double.infinity, nearest = 0, short = 0.0 // the front that would get here first if nothing stopped
                var closest = (left: -Double.infinity, k: 0, time: 0.0) // the crystal whose rim is nearest, for the liquid
                for (k, n) in nuclei.enumerated() {
                    let dx = x - n.x, dy = y - n.y
                    if n.born + (dx * dx + dy * dy).squareRoot() / fastest >= max(second, soonest) { continue }
                    let (time, left) = arrival(n, dx, dy)
                    if time < soonest { (soonest, nearest, short) = (time, k, left) }
                    if left > closest.left { closest = (left, k, time) }
                    guard left >= 0 else { continue }
                    if time < first {
                        (second, rival, rivalRim, first, owner, rim) = (first, owner, rim, time, k, left)
                    } else if time < second {
                        (second, rival, rivalRim) = (time, k, left)
                    }
                }
                // Liquid past a crystal's rim takes on the crystal that stopped nearest, so every field runs on
                // smoothly across the rim and the rim itself is where the signed distance to it crosses 0.
                let reached = first.isFinite
                if !reached { (first, owner, rim) = (closest.time, closest.k, closest.left) } else { latest = max(latest, first) }
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
                // Distance to the boundary with another crystal: where the next front ties with this one (the gap
                // between their arrival times over how fast it widens across it), where this one stops and the next
                // carries on, or where one that would have got here first stopped short.
                var gap = 8.0
                if reached, second.isFinite {
                    let o = nuclei[rival], od = max(((x - o.x) * (x - o.x) + (y - o.y) * (y - o.y)).squareRoot(), 1e-6), dd = max(d, 1e-6)
                    let pull = hypot((x - n.x) / dd - (x - o.x) / od, (y - n.y) / dd - (y - o.y) / od) / spacing
                    gap = min(gap, (second - first) / max(pull, 1e-9), rivalRim > rim ? rim * spacing : 8)
                }
                if reached, nearest != owner { gap = min(gap, -short * spacing) }
                marks[i * 4] = UInt8(min(max(gap, 0) / 8, 1) * 255)
                marks[i * 4 + 1] = UInt8((1 - banded * pow(band, 6)) * 255)
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
    /// so their spacing stays about the same, in broader bundles. Along a boundary the pixel is drawn as each
    /// crystal around it and blended, so boundaries are smooth rather than stepping with the texels.
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
        // Value noise that wraps every n cells across, for noise around a circle with no seam.
        float ring(vec2 p, float n) {
            vec2 i = floor(p), f = fract(p), u = f * f * (3.0 - 2.0 * f);
            float a = mod(i.x, n), b = mod(i.x + 1.0, n);
            return mix(mix(hashf(vec2(a, i.y)), hashf(vec2(b, i.y)), u.x), mix(hashf(vec2(a, i.y + 1.0)), hashf(vec2(b, i.y + 1.0)), u.x), u.y);
        }
        // What the crystal grown from `nuc` shows at `pts`: its light (x) and a factor on its retardation (y).
        vec2 crystal(vec2 pts, vec2 nuc, float scale) {
            vec2 off = pts - nuc;
            float r = length(off) + 0.001, a = atan(off.y, off.x) / 6.2832 + 0.5, rs = r / scale;
            float seed = dot(nuc, vec2(0.37, 0.61));
            float lv = log2(max(r, 6.0) / 6.0), fl = floor(lv), n = floor(44.0 * exp2(fl));
            float fib = mix(ring(vec2(a * n, r * 0.12 + seed + 31.0 * fl), n), ring(vec2(a * n * 2.0, r * 0.12 + seed + 31.0 * fl + 31.0), n * 2.0), lv - fl);
            float sheaf = ring(vec2(a * 11.0, r * 0.006 + seed), 11.0);
            float wob = (ring(vec2(a * 5.0, r * 0.01 + seed), 5.0) - 0.5) * 0.25 + (fib - 0.5) * 0.06;
            float ext = 0.5 + 0.5 * cos(4.0 * (a * 6.2832 + wob)) * mix(0.9, 0.5, smoothstep(0.0, 0.6, rs));
            float core = mix(0.35, 1.0, smoothstep(0.01, 0.04, rs));
            return vec2(ext * core * (0.78 + 0.44 * fib) * (0.85 + 0.3 * sheaf), 0.95 + 0.1 * fib);
        }
        vec2 nucleus(vec4 n, vec2 size) { return (vec2(n.r + n.g / 255.0, n.b + n.a / 255.0) * 1.5 - 0.25) * size; }
        void main() {
            vec2 pts = v_tex_coord * u_size;
            vec4 g = texture2D(u_growth, v_tex_coord), m = texture2D(u_marks, v_tex_coord);
            float arrive = (g.r + g.g / 255.0) / 0.95;
            float age = u_grow - arrive, left = u_level - arrive + (vnoise(pts * 0.03) - 0.5) * 0.06;
            float rim = (m.b - 0.5) * 16.0;
            float there = smoothstep(0.0, 0.004, min(u_grow, 1.01) - arrive) * smoothstep(0.0, 0.006, left);
            float solid = smoothstep(-0.5, 0.5, rim);
            float halo = smoothstep(-6.0, 0.0, rim);
            solid += (1.0 - solid) * 0.14 * halo * halo * halo; // a faint halo into the liquid, as slightly out of focus

            vec2 t = v_tex_coord * u_texels - 0.5, i = floor(t), f = t - i;
            vec4 n00 = texture2D(u_nucleus, (i + 0.5) / u_texels), n10 = texture2D(u_nucleus, (i + vec2(1.5, 0.5)) / u_texels);
            vec4 n01 = texture2D(u_nucleus, (i + vec2(0.5, 1.5)) / u_texels), n11 = texture2D(u_nucleus, (i + 1.5) / u_texels);
            vec2 c = crystal(pts, nucleus(n00, u_size), u_scale);
            float groove = smoothstep(0.04, 0.14, m.r);
            vec4 same = vec4(step(dot(abs(n10 - n00), vec4(1.0)), 0.0), step(dot(abs(n01 - n00), vec4(1.0)), 0.0),
                             step(dot(abs(n11 - n00), vec4(1.0)), 0.0), 1.0);
            if (same.x + same.y + same.z < 3.0) {
                // A boundary crosses this cell. Each texel's distance to it, signed by which side it's on, crosses 0
                // right on the boundary, so the pixel takes the crystal on its side (blended over a point) and the
                // groove follows the line exactly.
                vec4 other = same.x < 0.5 ? n10 : (same.y < 0.5 ? n01 : n11);
                vec4 dist = vec4(texture2D(u_marks, (i + vec2(1.5, 0.5)) / u_texels).r, texture2D(u_marks, (i + vec2(0.5, 1.5)) / u_texels).r,
                                 texture2D(u_marks, (i + 1.5) / u_texels).r, texture2D(u_marks, (i + 0.5) / u_texels).r) * 8.0 * (same * 2.0 - 1.0);
                float side = mix(mix(dist.w, dist.x, f.x), mix(dist.y, dist.z, f.x), f.y);
                c = mix(crystal(pts, nucleus(other, u_size), u_scale), c, smoothstep(-0.6, 0.6, side));
                groove = smoothstep(0.3, 1.1, abs(side));
            }

            float gam = (g.b + g.a / 255.0) * u_thickness * c.y
                      * (0.55 + 0.45 * smoothstep(0.0, 0.12, age)) * smoothstep(0.0, 0.05, left);
            vec3 chart = pow(texture2D(u_chart, vec2(clamp(gam, 0.0, 1.0), 0.5)).rgb, vec3(2.2));
            float fringe = 1.0 + 0.6 * exp(-max(rim, 0.0) / 0.8);
            vec3 lit = there * solid * c.x * chart * m.g * groove * fringe;

            vec2 d = pts - 0.5 * u_size;
            float rr = length(d) / (0.47 * u_size.y);
            float field = mix(1.0, smoothstep(1.0, 0.985, rr), u_stop) * (1.0 - 0.12 * min(rr * rr, 1.5));
            vec3 col = u_dark > 0.5 ? (lit * 0.32 + vec3(0.0006, 0.0008, 0.0013)) * u_brightness : (1.0 - lit) * 0.8 * u_brightness;
            col = pow(max(col * field, 0.0), vec3(1.0 / 2.2)) + (hashf(pts * 3.7) - 0.5) / 255.0;
            gl_FragColor = vec4(col, 1.0);
        }
        """
}
