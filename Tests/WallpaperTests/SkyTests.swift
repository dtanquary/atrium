import Foundation
import Testing
import simd
@testable import Wallpaper

private let newYear2026 = 2461041.5 // 2026-01-01 00:00 UTC

/// Sun, Moon and planets against JPL Horizons (geocentric, astrometric J2000) at 2026-01-01 00:00 UTC.
@Test(arguments: [
    ("Sun", 281.10570, -23.04308), ("Moon", 63.51648, 26.33621), ("Mercury", 268.13109, -23.99489),
    ("Venus", 279.66547, -23.64468), ("Mars", 283.48904, -23.75166), ("Jupiter", 112.72933, 22.03458),
    ("Saturn", 357.04711, -3.74068),
])
func matchesHorizons(body: String, ra: Double, dec: Double) {
    let v = switch body {
    case "Sun": Sky.sun(newYear2026)
    case "Moon": Sky.moon(newYear2026)
    default: Sky.planet(Sky.Planet(rawValue: body)!, newYear2026)
    }
    let error = acos(min(1, dot(v, Sky.direction(ra, dec)))) * 180 / .pi
    #expect(error < 1, "\(body) is \(error)° off: got \(Sky.raDec(v))")
}

@Test func polarisSitsAtTheObserversLatitude() {
    let polaris = Sky.direction(37.954, 89.264)
    for latitude in [-10.0, 20, 40, 65] {
        let up = (Sky.horizonMatrix(jd: newYear2026, latitude: latitude, longitude: -100) * polaris).z
        #expect(abs(asin(up) * 180 / .pi - latitude) < 1)
    }
    let overhead = Sky.lookDirection(latitude: 40, longitude: -100, toLatitude: 40, longitude: -100, altitude: 420)
    #expect(overhead.z > 0.9999)
}
