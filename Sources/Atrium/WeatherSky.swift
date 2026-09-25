import SpriteKit
import simd

/// Sunlight through the air, after Hillaire's "A Scalable and Production Ready Sky and Atmosphere Rendering
/// Technique" (EGSR 2020): Rayleigh, Mie and ozone, single scattering plus his approximation of multiple scattering,
/// in km. Twilight, the Earth's shadow and the Belt of Venus come out of the physics, since sunlight is zero wherever
/// the Earth is in the way. Its tables take about 50 ms, so there's one, built on first use.
final class Atmosphere: Sendable {
    typealias V3 = SIMD3<Double>
    static let shared = Atmosphere()
    static let ground = 6360.0, top = 6460.0
    static let rayleigh = V3(5.802, 13.558, 33.1) * 1e-3 // per km at sea level
    static let ozone = V3(0.650, 1.881, 0.085) * 1e-3
    static let mieScatter = 3.996e-3, mieExtinct = 4.44e-3
    private let transmittance: [V3] // 64 heights × 256 view angles
    private let multiple: [V3]      // 32 heights × 32 Sun angles

    private init() {
        let t = (0..<64 * 256).map { i in Self.opticalTransmittance(Self.height(i / 256, 63), Double(i % 256) / 255 * 2 - 1) }
        transmittance = t
        multiple = (0..<32 * 32).map { i in Self.multipleScattering(Self.height(i / 32, 31), Double(i % 32) / 31 * 2 - 1, t) }
    }

    private static func height(_ i: Int, _ n: Int) -> Double { pow(Double(i) / Double(n), 2) * 100 }

    private static func extinction(_ h: Double) -> V3 {
        rayleigh * exp(-h / 8) + V3(repeating: mieExtinct * exp(-h / 1.2)) + ozone * max(0, 1 - abs(h - 25) / 15)
    }

    private static func distanceToTop(_ r: Double, _ mu: Double) -> Double { max(0, -r * mu + sqrt(max(r * r * (mu * mu - 1) + top * top, 0))) }
    private static func hitsGround(_ r: Double, _ mu: Double) -> Bool { mu < 0 && r * r * (mu * mu - 1) + ground * ground >= 0 }
    private static func distanceToGround(_ r: Double, _ mu: Double) -> Double { -r * mu - sqrt(max(r * r * (mu * mu - 1) + ground * ground, 0)) }

    private static func opticalTransmittance(_ h: Double, _ mu: Double) -> V3 {
        let r = ground + h
        if hitsGround(r, mu) { return .zero }
        let len = distanceToTop(r, mu), n = 40
        var depth = V3.zero
        for k in 0..<n {
            let t = (Double(k) + 0.5) / Double(n) * len
            depth += extinction(sqrt(r * r + t * t + 2 * r * t * mu) - ground) * (len / Double(n))
        }
        return exp(-depth)
    }

    private static func lookup(_ table: [V3], _ w: Int, _ rows: Int, _ h: Double, _ mu: Double) -> V3 {
        let y = sqrt(min(max(h, 0), 100) / 100) * Double(rows - 1), x = (min(max(mu, -1), 1) + 1) / 2 * Double(w - 1)
        let (x0, y0) = (min(Int(x), w - 2), min(Int(y), rows - 2))
        let (fx, fy) = (x - Double(x0), y - Double(y0))
        let a = table[y0 * w + x0] * (1 - fx) + table[y0 * w + x0 + 1] * fx
        let b = table[(y0 + 1) * w + x0] * (1 - fx) + table[(y0 + 1) * w + x0 + 1] * fx
        return a * (1 - fy) + b * fy
    }

    /// Sunlight left at height `h` km with the Sun at cos(zenith) `mu`: zero where the Earth is in the way.
    func sunlight(_ h: Double, _ mu: Double) -> V3 { Self.lookup(transmittance, 256, 64, h, mu) }

    /// Light scattered twice or more, per unit of scattering, at height h (Hillaire 2020 §5.5, 64 directions).
    private static func multipleScattering(_ h: Double, _ muS: Double, _ table: [V3]) -> V3 {
        let r = ground + h, sun = V3(sqrt(max(0, 1 - muS * muS)), 0, muS), n = 64
        var light = V3.zero, fms = V3.zero
        for i in 0..<n {
            let z = 1 - (Double(i) + 0.5) / Double(n) * 2, a = Double(i) * 2.39996
            let dir = V3(sqrt(1 - z * z) * cos(a), sqrt(1 - z * z) * sin(a), z)
            let down = hitsGround(r, z)
            let len = down ? distanceToGround(r, z) : distanceToTop(r, z)
            let steps = 20, dt = len / Double(steps)
            var through = V3(1, 1, 1)
            for k in 0..<steps {
                let p = V3(0, 0, r) + dir * ((Double(k) + 0.5) * dt)
                let rr = length(p), hh = rr - ground
                let ext = extinction(hh), scatter = rayleigh * exp(-hh / 8) + V3(repeating: mieScatter * exp(-hh / 1.2))
                let step = exp(-ext * dt), integral = (V3(1, 1, 1) - step) / ext
                light += through * scatter * lookup(table, 256, 64, hh, dot(p / rr, sun)) / (4 * .pi) * integral
                fms += through * scatter * integral
                through *= step
            }
            if down { light += through * lookup(table, 256, 64, 0, muS) * max(muS, 0) * 0.3 / .pi } // off the ground
        }
        return light / Double(n) / (V3(1, 1, 1) - fms / Double(n))
    }

    /// Light arriving along a ray from height `h0` in direction `dir` (z up), from each light (its direction and
    /// strength, the Sun being 1), and how much of what's behind gets through, out to `far` km or the sky's edge.
    func march(h0: Double, dir: V3, lights: [(V3, Double)], far: Double = .infinity, steps: Int = 32) -> (light: V3, through: V3) {
        let r = Self.ground + h0, mu = dir.z
        let len = min(Self.hitsGround(r, mu) ? Self.distanceToGround(r, mu) : Self.distanceToTop(r, mu), far)
        var through = V3(1, 1, 1), light = V3.zero, t0 = 0.0
        for k in 0..<steps {
            let t1 = len * pow(Double(k + 1) / Double(steps), 2) // denser near the eye, where the air is thickest
            let dt = t1 - t0, p = V3(0, 0, r) + dir * ((t0 + t1) / 2)
            t0 = t1
            let rr = length(p), hh = rr - Self.ground, up = p / rr
            let ext = Self.extinction(hh)
            let sr = Self.rayleigh * exp(-hh / 8), sm = Self.mieScatter * exp(-hh / 1.2)
            let step = exp(-ext * dt), integral = (V3(1, 1, 1) - step) / ext
            var scattered = V3.zero
            for (l, strength) in lights where strength > 0 {
                let c = dot(dir, l), muS = dot(up, l), g = 0.8
                let rayleighPhase = 3 / (16 * Double.pi) * (1 + c * c)
                let miePhase = 3 / (8 * Double.pi) * (1 - g * g) * (1 + c * c) / ((2 + g * g) * pow(1 + g * g - 2 * g * c, 1.5))
                scattered += ((sr * rayleighPhase + V3(repeating: sm * miePhase)) * sunlight(hh, muS)
                              + (sr + V3(repeating: sm)) * Self.lookup(multiple, 32, 32, hh, muS)) * strength
            }
            light += through * scattered * integral
            through *= step
        }
        return (light, through)
    }
}

/// The view: level, facing `facing` (radians clockwise from north), with a shifted lens so the horizon is a straight
/// line `horizon` of the way up the screen. Directions are in the horizon frame (east, north, up).
struct SkyCamera: Sendable {
    typealias V3 = SIMD3<Double>
    var aspect: Double
    var horizon: Double
    var facing: Double
    var tanH = tan(32.0 * .pi / 180) // half the horizontal field of view
    var height = 0.3                 // km above sea level

    var tanV: Double { tanH / aspect }
    var forward: V3 { V3(sin(facing), cos(facing), 0) }
    var right: V3 { V3(cos(facing), -sin(facing), 0) }

    /// The direction through a point on screen, 0…1 each way.
    func ray(_ u: Double, _ v: Double) -> V3 { normalize(right * ((u * 2 - 1) * tanH) + forward + V3(0, 0, (v - horizon) * 2 * tanV)) }

    /// Where a direction lands on screen, 0…1 each way, or nil if it's behind.
    func screen(_ d: V3) -> SIMD2<Double>? {
        let f = dot(d, forward)
        guard f > 0.01 else { return nil }
        return [0.5 + dot(d, right) / f / (2 * tanH), horizon + d.z / f / (2 * tanV)]
    }
}

/// Everything about the light at one moment that the shaders need: the sky as a small texture, and the colours of
/// sunlight, skylight and the horizon, all scaled by the exposure.
struct SkyLight: Sendable {
    typealias V3 = SIMD3<Double>
    /// The sky from `bottom` up the screen to its top, 128×96, stored as sqrt(v / 4) so values up to 4 (near the Sun)
    /// fit in 8 bits with fine steps in the dark.
    var pixels: [UInt8]
    var bottom: Double
    var sun: V3, moon: V3            // directions
    var sunColour: V3                // sunlight at the ground, times exposure
    var sunAtCloud: V3               // sunlight (or moonlight at night) up at the clouds
    var ambient: V3                  // skylight falling on the ground, times exposure
    var moonPower: Double            // the Moon's light, as a fraction of the Sun's
    var exposure: Double
    /// How bright the sky is, for fading stars: its luminance near the zenith before exposure.
    var skyLuminance: Double

    static let width = 128, height = 96

    /// The sky over `camera` at `date` where you are. About 20 ms, so it's baked off the main thread each minute.
    static func bake(camera: SkyCamera, date: Date, latitude: Double, longitude: Double) -> SkyLight {
        let air = Atmosphere.shared, jd = Sky.julianDate(date)
        let toHorizon = Sky.horizonMatrix(jd: jd, latitude: latitude, longitude: longitude)
        let sun = normalize(toHorizon * Sky.sun(jd)), moon = normalize(toHorizon * Sky.moon(jd))
        // Full moon is about 1/400,000 of sunlight, falling off steeply with phase (Krisciunas & Schaefer 1991).
        let moonPower = moon.z > -0.05 ? 2.5e-6 * pow(Sky.moonPhase(jd).lit, 3) : 0
        let lights: [(V3, Double)] = [(sun, 1), (moon, moonPower)]
        func luminance(_ v: V3) -> Double { dot(v, V3(0.2126, 0.7152, 0.0722)) }

        // Partial auto-exposure: the picture darkens as the light fades, but far less than the light does. The floor
        // stands in for airglow and starlight on a moonless night.
        var mean = 0.0
        for j in 0..<4 { for i in 0..<6 {
            let v = camera.horizon + (1 - camera.horizon) * (Double(j) + 0.5) / 4
            mean += luminance(air.march(h0: camera.height, dir: camera.ray((Double(i) + 0.5) / 6, v), lights: lights, steps: 16).light)
        } }
        mean = mean / 24 + 2e-7
        // and at night, a little further than that, so it looks like night rather than a long exposure
        let night = min(max((-0.03 - sun.z) / 0.17, 0), 1)
        let exposure = 0.7 * pow(mean, -0.88) * pow(0.05, -0.12) * (1 - 0.5 * night)

        let (w, h) = (width, height), bottom = camera.horizon - 0.06
        var pixels = [UInt8](repeating: 255, count: w * h * 4)
        pixels.withUnsafeMutableBufferPointer { buffer in
            let buffer = buffer
            DispatchQueue.concurrentPerform(iterations: h) { j in
                for i in 0..<w {
                    let (u, v) = ((Double(i) + 0.5) / Double(w), bottom + (1 - bottom) * (Double(j) + 0.5) / Double(h))
                    let light = air.march(h0: camera.height, dir: camera.ray(u, v), lights: lights).light * exposure
                    let k = (j * w + i) * 4
                    for c in 0..<3 { buffer[k + c] = UInt8(min(sqrt(max(light[c], 0) / 4), 1) * 255) }
                }
            }
        }
        let zenith = air.march(h0: camera.height, dir: normalize(V3(0, 0, 1) + camera.forward * 0.3), lights: lights, steps: 24).light
        let lightDir = sun.z > -0.14 ? sun : moon, power = sun.z > -0.14 ? 1 : moonPower
        return SkyLight(pixels: pixels, bottom: bottom, sun: sun, moon: moon,
                        sunColour: air.sunlight(camera.height, sun.z) * exposure,
                        sunAtCloud: air.sunlight(2, lightDir.z) * power * exposure,
                        ambient: zenith * .pi * 0.8 * exposure, moonPower: moonPower, exposure: exposure,
                        skyLuminance: luminance(zenith))
    }

    var texture: SKTexture {
        let texture = SKTexture(data: Data(pixels), size: CGSize(width: Self.width, height: Self.height))
        texture.filteringMode = .linear
        return texture
    }
}
