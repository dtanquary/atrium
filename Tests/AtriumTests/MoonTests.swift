import Foundation
import ImageIO
import Testing
import simd
@testable import Atrium

/// The Moon's phase, libration and tilt against NASA's Dial-a-Moon for 2026 (svs.gsfc.nasa.gov/5587, geocentric,
/// from svs.gsfc.nasa.gov/api/dialamoon/<time>): lit %, distance km, subsolar and sub-Earth longitude and latitude,
/// and the position angle of the axis. They agree to 0.03°, about the physical libration left out.
@Test(arguments: [
    ("2026-01-03T10:00:00Z", 99.86, 362307.0, 3.219, -1.306, 3.251, -5.579, 4.814),
    ("2026-02-20T18:00:00Z", 12.22, 374471.0, 135.312, -0.231, -3.941, -3.763, 338.221),
    ("2026-05-25T03:00:00Z", 67.17, 389606.0, 76.766, 1.548, 6.81, 2.202, 21.835),
    ("2026-07-08T12:00:00Z", 42.55, 375008.0, -105.235, 1.096, -6.73, -5.393, 339.132),
    ("2026-09-26T12:00:00Z", 99.9, 380234.0, -2.417, -0.874, -4.988, -3.516, 337.843),
    ("2026-11-13T21:00:00Z", 18.4, 405641.0, 128.141, -1.557, -1.055, 4.528, 355.964),
])
func moonMatchesDialAMoon(time: String, lit: Double, km: Double, sunLon: Double, sunLat: Double,
                          earthLon: Double, earthLat: Double, positionAngle: Double) {
    let view = Sky.moonView(Sky.julianDate(ISO8601DateFormatter().date(from: time)!))
    func off(_ a: Double, _ b: Double) -> Double { abs(remainder(a - b, 360)) }
    #expect(abs(view.lit * 100 - lit) < 0.3, "lit \(view.lit * 100)%")
    #expect(abs(view.km - km) < 100, "\(view.km) km")
    #expect(off(view.libration.longitude, earthLon) < 0.05 && off(view.libration.latitude, earthLat) < 0.05,
            "libration \(view.libration), expected \(earthLon), \(earthLat)")
    #expect(off(view.subsolar.longitude, sunLon) < 0.05 && off(view.subsolar.latitude, sunLat) < 0.05,
            "subsolar \(view.subsolar), expected \(sunLon), \(sunLat)")
    #expect(off(view.positionAngle, positionAngle) < 0.05, "position angle \(view.positionAngle)")
}

/// The total lunar eclipse of 2026-03-03: Dial-a-Moon has 98% of the disc in the umbra at 11:00 UTC, and totality
/// from 11:04. At the new moon a fortnight earlier it's on the Sun's side of the Earth, where there's no shadow.
@Test func eclipseCoversTheMoon() {
    func covered(_ time: String) -> Double {
        let view = Sky.moonView(Sky.julianDate(ISO8601DateFormatter().date(from: time)!))
        let (a, b) = (view.skyEast, view.skyNorth), radius = 1737.4 / Sky.earthRadius
        var (inside, total) = (0, 0)
        for x in stride(from: -1.0, through: 1, by: 0.02) { for y in stride(from: -1.0, through: 1, by: 0.02) where x * x + y * y <= 1 {
            let shadow = Sky.earthShadow(at: view.position + (a * x + b * y) * radius, sun: view.sunDirection)
            inside += shadow.off < shadow.umbra ? 1 : 0
            total += 1
        } }
        return Double(inside) / Double(total)
    }
    #expect(abs(covered("2026-03-03T11:00:00Z") - 0.9807) < 0.03)
    #expect(covered("2026-03-03T11:33:00Z") == 1)
    #expect(covered("2026-02-17T11:00:00Z") == 0)
}


/// For comparing renders side by side with Dial-a-Moon's images: `MOON_COMPARE=<dir> swift test --filter moonRenders`
/// saves the baked Moon for the dates above, geocentric and north up like theirs, at their scale (0.35 pixels an
/// arcsecond on 730 pixels).
@MainActor @Test func moonRenders() throws {
    guard let dir = ProcessInfo.processInfo.environment["MOON_COMPARE"] else { return }
    let baker = MoonBaker()
    for time in ["2026-01-03T10:00", "2026-02-20T18:00", "2026-03-03T11:00", "2026-05-25T03:00", "2026-07-08T12:00",
                 "2026-09-26T12:00", "2026-11-13T21:00"] {
        let seen = Sky.moonView(Sky.julianDate(ISO8601DateFormatter().date(from: time + ":00Z")!))
        let radius = asin(1737.4 / seen.km) * 180 / .pi * 3600 * 0.35
        let image = baker.bake(seen, pixels: 730, radius: radius, brightness: 1, earthshine: 1).cgImage()
        let url = URL(fileURLWithPath: dir).appendingPathComponent(time + ".png")
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }
}
