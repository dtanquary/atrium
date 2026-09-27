import Foundation
import Testing
import simd
@testable import Atrium

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

/// Moon's lit fraction and waxing/waning against Horizons' Illu% and S-O-T /T (trails the Sun) or /L (leads it).
@Test(arguments: [(newYear2026, 0.9139877, true), (newYear2026 + 9, 0.5653140, false)])
func moonPhaseMatchesHorizons(jd: Double, lit: Double, waxing: Bool) {
    let phase = Sky.moonPhase(jd)
    #expect(abs(phase.lit - lit) < 0.02, "lit \(phase.lit), expected \(lit)")
    #expect(phase.waxing == waxing)
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

/// Real total and annular eclipses, seen from the path: at the published greatest eclipse the Moon, placed from where
/// the viewer stands, sits on the Sun (within 30″ of the Sun's 960″ radius).
@Test(arguments: [("2024-04-08T18:42:39Z", 32.78, -96.80), ("2017-08-21T18:28:00Z", 36.16, -86.78),
                  ("2023-10-14T16:36:00Z", 35.08, -106.65), ("2026-08-12T18:27:00Z", 43.36, -5.85)])
func eclipsesLineUp(time: String, latitude: Double, longitude: Double) {
    let jd = Sky.julianDate(ISO8601DateFormatter().date(from: time)!)
    let best = stride(from: -120.0, through: 120, by: 5).map { seconds in
        let moon = Sky.moon(jd + seconds / 86400, latitude: latitude, longitude: longitude).direction
        return acos(min(dot(moon, Sky.sun(jd + seconds / 86400)), 1)) * 180 / .pi * 3600
    }.min()!
    #expect(best < 50, "the Moon passes \(best)″ from the Sun's centre")
    // Without parallax it misses by a good part of a degree.
    #expect(acos(min(dot(Sky.moon(jd), Sky.sun(jd)), 1)) * 180 / .pi > 0.4)
}
