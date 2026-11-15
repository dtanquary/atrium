import SpriteKit

/// The city of lights behind Rain on Glass's bokeh palettes, baked once into the three textures a photo backdrop
/// has (docs/rain-on-glass.md, The bake): the view out of focus as a lens focused on the glass sees it (`far`), the
/// view sharp, seen small and upside down in each drop (`near`), and the glow a misted pane spreads it into (`haze`).
/// The lights are laid out as a city lays them, seen from a window high over it: street lamps in rows that recede to
/// the horizon and cross streets that close up towards it, lit windows clustered on the buildings, and each light as
/// bright as the square of its distance leaves it, so a few are very bright and most are dim. Out of focus every
/// light is a disc of the one size, its light added up in linear light, so the bright ones bloom to white.
enum RainCity {
    /// The baked view's shape, a MacBook's, as the photos': other screens crop it.
    static let aspect: Float = 1512.0 / 982.0
    /// The radius of a light out of focus, in screen heights: the photos' 3% of the width.
    static let disc: Float = 0.03 * aspect
    /// The view: the horizon's height on the screen, the lens (screen heights at 1 m for a metre: the photos' 52
    /// degrees), and how far above the streets the window is, in metres.
    static let horizon: Float = 0.66, focal: Float = 1.035, eye: Float = 55
    /// The street the traffic crawls along, the only lights that move (the shader draws them), by its height on the
    /// screen: a cross street 150 m off.
    static let traffic: Float = horizon - focal * eye / 150

    /// One light: where it is on the screen (screen heights, from the bottom left), its colour, and how bright its
    /// disc is in linear light: 1 is a street lamp at the foot of the view.
    struct Light { var at: SIMD2<Float>, colour: SIMD3<Float>, power: Float }

    /// The lights of the city behind `rainPalettes[palette]`, each palette its own city, in its five tints, most to
    /// least common: lamps down the avenues and across the cross streets, windows on the buildings, signs, and a
    /// scatter of far ones along the horizon.
    static func lights(palette: Int) -> [Light] {
        let tints = rainPalettes[palette].lights
        var rng = SplitMix(state: UInt64(palette) + 1)
        func random(_ range: ClosedRange<Float>) -> Float { .random(in: range, using: &rng) }
        let nearest = focal * eye / horizon                  // metres to the street at the foot of the view
        let vanish = aspect * random(0.3...0.7)              // where the avenues meet the horizon
        var lights = [Light]()
        /// A light `x` m across, `y` m above the street and `z` m away: the square of its distance dimmer, and
        /// dimmer again through the rain between.
        func add(_ x: Float, _ y: Float, _ z: Float, _ tint: Int, _ watts: Float) {
            let at = SIMD2(vanish + focal * x / z, horizon + focal * (y - eye) / z)
            guard at.x > -disc, at.x < aspect + disc, at.y > -disc, at.y < 1 + disc else { return }
            lights.append(Light(at: at, colour: tints[tint], power: watts * (nearest / z) * (nearest / z) * exp((nearest - z) / 450)))
        }
        let reach: Float = 640                               // past this the lamps are the horizon's glow
        // avenues, receding: a lamp on each kerb by turns; one of them the main one, brighter and whiter
        let block = random(110...150), first = random(0...1) * block, main = Int.random(in: -1...1, using: &rng)
        for k in -6...6 {
            let x = (Float(k) + 0.5) * block - first, spacing: Float = k == main ? 26 : 32
            var z = nearest * 0.8 + random(0...spacing), side: Float = 1
            while z < reach {
                if random(0...1) > 0.1 { add(x + side * 7, 9, z, k == main ? 1 : 0, (k == main ? 2 : 1) * random(0.6...1.4)) }
                (z, side) = (z + spacing / 2 + random(-3...3), -side)
            }
        }
        // cross streets, closing up towards the horizon; the second is the one the traffic is on
        var z: Float = 100
        while z < reach {
            var x = -aspect * z / focal + random(0...30)
            while x < aspect * z / focal {
                if random(0...1) > 0.12 { add(x, 9, z + random(-5...5), z == 150 ? 1 : 0, random(0.6...1.4)) }
                x += random(22...38)
            }
            z += z < 150 ? 50 : random(90...140)
        }
        // buildings: a face of windows, some lit, most in the building's own light. A third are towers, far off,
        // floodlit and standing over the horizon, with a beacon on top
        for _ in 0..<Int.random(in: 18...24, using: &rng) {
            let tower = random(0...1) < 0.35, z = tower ? random(300...640) : random(110...450), x = random(-1...1) * aspect * z / focal
            let floors = tower ? Int.random(in: 16...40, using: &rng) : Int.random(in: 4...12, using: &rng), columns = Int.random(in: 4...8, using: &rng)
            let lit = random(0.15...0.4), u = random(0...1), tint = u < 0.5 ? 1 : u < 0.8 ? 0 : 3
            for floor in 0..<floors { for column in 0..<columns where random(0...1) < lit {
                add(x + Float(column) * 3.5, 3 + Float(floor) * 3.3, z, random(0...1) < 0.7 ? tint : Int.random(in: 0...3, using: &rng),
                    random(0.06...0.2) * (tower ? 4 : 1))
            } }
            if tower { add(x + Float(columns) * 1.75, Float(floors) * 3.3 + 6, z, 2, 3) }
        }
        // signs and signals at street level, in the rare colours, and far lights along the horizon, a few of them bright
        for _ in 0..<14 { let z = random(70...400); add(random(-1...1) * aspect * z / focal, random(3...8), z, random(0...1) < 0.65 ? 2 : 4, random(0.5...2)) }
        for _ in 0..<50 {
            let u = random(0...1), tint = u < 0.45 ? 0 : u < 0.65 ? 1 : u < 0.8 ? 2 : u < 0.93 ? 3 : 4
            lights.append(Light(at: [random(0...aspect), horizon - 0.07 * pow(random(0...1), 2) + random(-0.01...0.02)], colour: tints[tint],
                                power: min(0.012 / pow(random(0.001...1), 0.6), 0.5)))
        }
        return lights
    }

    /// The three textures for the city behind `rainPalettes[palette]`, by night or by day: under 90 ms.
    // ponytail: baked on the main thread as the scene is built; off it, as RainFrost's is, if that ever shows as a hitch
    @MainActor static func textures(palette: Int, night: Bool) -> (far: SKTexture, near: SKTexture, haze: SKTexture) {
        let tints = rainPalettes[palette].lights, sky = night ? rainPalettes[palette].night : rainPalettes[palette].day
        // by night the lights add up in linear light (a palette's tints are colours as the display shows them); by
        // day they only tint the overcast sky, the bright ones no more than the rest. The shader's traffic does the same.
        let lights = lights(palette: palette).map { Light(at: $0.at, colour: night ? decoded($0.colour) : $0.colour, power: $0.power) }
        let strength = lights.map { night ? $0.power : 0.6 * (1 - exp(-4 * $0.power)) }
        let glowing = decoded(tints[0] + tints[1]) * 0.025
        /// Each row's sky in a picture `h` rows tall blurred by `spread` screen heights: by day as the display shows
        /// it; by night in linear light, with the glow of the lamps too far off to tell apart, a band 0.032 deep
        /// under the horizon.
        func skies(_ h: Int, spread: Float) -> [SIMD3<Float>] {
            (0..<h).map { row in
                let y = (Float(row) + 0.5) / Float(h), t = min(max(y / 0.9, 0), 1), colour = sky[1] + (sky[0] - sky[1]) * (t * t * (3 - 2 * t))
                let wide = (0.001 + spread * spread).squareRoot()
                return night ? decoded(colour) + glowing * (0.032 / wide) * exp(-pow((y - horizon + 0.03) / wide, 2) / 2) : colour
            }
        }
        /// A texel's colour from the light summed there, (tint × strength, strength), over its row's sky. By day the
        /// lights tint the sky, however many lie over one another, no more than one bright one would.
        func shown(_ lit: SIMD4<Float>, _ sky: SIMD3<Float>) -> SIMD3<Float> {
            let rgb = SIMD3(lit.x, lit.y, lit.z)
            guard night else { return sky * exp3(-1.3 * (lit.w - 0.8 * rgb) * (lit.w > 0 ? (1 - exp(-lit.w)) / lit.w : 1)) }
            return encoded(1 - exp3(-(sky + rgb)))
        }
        let (fw, fh) = (768, 499), (nw, nh) = (256, 166), (hw, hh) = (128, 83)
        let sharp = points(lights, strength, nw, nh), glow = blurred(sharp, nw, nh, sigma: 0.035 * Float(nh))
        // far: every light a disc, soft at the edge and a little brighter round the rim, over a little of its glow
        var discs = [SIMD4<Float>](repeating: .zero, count: fw * fh)
        let r = disc * Float(fh), soft: Float = 3
        for (light, power) in zip(lights, strength) {
            let c = light.at * Float(fh), lit = SIMD4(light.colour * power, power)
            for row in max(Int(c.y - r), 0)..<max(min(Int(c.y + r) + 2, fh), 0) {
                for column in max(Int(c.x - r), 0)..<max(min(Int(c.x + r) + 2, fw), 0) {
                    let d = simd_length(SIMD2(Float(column), Float(row)) + 0.5 - c)
                    if d < r { discs[row * fw + column] += lit * min((r - d) / soft, 1) * (0.85 + 0.15 * min(max((d / r - 0.4) / 0.6, 0), 1)) }
                }
            }
        }
        var rows = skies(fh, spread: disc / 2)
        let far = texture(fw, fh) { column, row in
            shown(discs[row * fw + column] + 0.2 * sample(glow, nw, nh, (Float(column) + 0.5) / Float(fw), (Float(row) + 0.5) / Float(fh)), rows[row])
        }
        // near: the lights sharp, each a point (by day a dot) with the glow of what it lights round it
        rows = skies(nh, spread: 0)
        let near = texture(nw, nh) { column, row in shown(sharp[row * nw + column] * (night ? 1 : 0.02) + glow[row * nw + column], rows[row]) }
        // haze: all of it spread wide, the glow a misted pane scatters the view into
        let wide = blurred(points(lights, strength, hw, hh), hw, hh, sigma: 0.2 * Float(hh))
        rows = skies(hh, spread: 0.2)
        return (far, near, texture(hw, hh) { column, row in shown(wide[row * hw + column], rows[row]) })
    }

    /// Each light's energy (its disc's brightness times the disc's area) dropped on the texel it's over, as the
    /// brightness of that texel: the lights in focus. Bottom row first.
    private static func points(_ lights: [Light], _ strength: [Float], _ w: Int, _ h: Int) -> [SIMD4<Float>] {
        var out = [SIMD4<Float>](repeating: .zero, count: w * h)
        let energy = Float.pi * disc * disc * Float(h * h)
        for (light, power) in zip(lights, strength) {
            let column = Int(light.at.x * Float(h)), row = Int(light.at.y * Float(h))
            if column >= 0, column < w, row >= 0, row < h { out[row * w + column] += SIMD4(light.colour * power, power) * energy }
        }
        return out
    }

    /// A Gaussian blur of `sigma` texels, across then up.
    private static func blurred(_ v: [SIMD4<Float>], _ w: Int, _ h: Int, sigma: Float) -> [SIMD4<Float>] {
        let reach = Int(3 * sigma), kernel = (-reach...reach).map { exp(-Float($0 * $0) / (2 * sigma * sigma)) }
        let weights = kernel.map { $0 / kernel.reduce(0, +) }
        var across = [SIMD4<Float>](repeating: .zero, count: w * h), out = across
        for row in 0..<h { for column in 0..<w {
            var sum = SIMD4<Float>()
            for k in max(-reach, -column)...min(reach, w - 1 - column) { sum += v[row * w + column + k] * weights[k + reach] }
            across[row * w + column] = sum
        } }
        for row in 0..<h { for column in 0..<w {
            var sum = SIMD4<Float>()
            for k in max(-reach, -row)...min(reach, h - 1 - row) { sum += across[(row + k) * w + column] * weights[k + reach] }
            out[row * w + column] = sum
        } }
        return out
    }

    /// `v` at (x, y) of the way across and up, smoothed between its texels.
    private static func sample(_ v: [SIMD4<Float>], _ w: Int, _ h: Int, _ x: Float, _ y: Float) -> SIMD4<Float> {
        let fx = min(max(x * Float(w) - 0.5, 0), Float(w - 1)), fy = min(max(y * Float(h) - 0.5, 0), Float(h - 1))
        let x0 = Int(fx), y0 = Int(fy), x1 = min(x0 + 1, w - 1), y1 = min(y0 + 1, h - 1), tx = fx - Float(x0), ty = fy - Float(y0)
        return (v[y0 * w + x0] * (1 - tx) + v[y0 * w + x1] * tx) * (1 - ty) + (v[y1 * w + x0] * (1 - tx) + v[y1 * w + x1] * tx) * ty
    }

    /// A texture of `w`×`h` texels, each the colour `colour` gives for its column and row (the bottom row first).
    @MainActor private static func texture(_ w: Int, _ h: Int, colour: (Int, Int) -> SIMD3<Float>) -> SKTexture {
        var bytes = [UInt8](repeating: 255, count: w * h * 4)
        for row in 0..<h { for column in 0..<w {
            let c = simd_clamp(colour(column, row), .zero, .one) * 255
            (bytes[(row * w + column) * 4], bytes[(row * w + column) * 4 + 1], bytes[(row * w + column) * 4 + 2]) = (UInt8(c.x), UInt8(c.y), UInt8(c.z))
        } }
        return SKTexture(data: Data(bytes), size: CGSize(width: w, height: h))
    }

    private static func exp3(_ v: SIMD3<Float>) -> SIMD3<Float> { [exp(v.x), exp(v.y), exp(v.z)] }
    /// sRGB to linear light and back.
    static func decoded(_ c: SIMD3<Float>) -> SIMD3<Float> {
        func f(_ x: Float) -> Float { x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4) }
        return [f(c.x), f(c.y), f(c.z)]
    }
    private static func encoded(_ c: SIMD3<Float>) -> SIMD3<Float> {
        func f(_ x: Float) -> Float { x <= 0.0031308 ? x * 12.92 : 1.055 * pow(x, 1 / 2.4) - 0.055 }
        return [f(c.x), f(c.y), f(c.z)]
    }
}
