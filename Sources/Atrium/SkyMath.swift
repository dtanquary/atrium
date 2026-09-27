import Foundation
import simd

/// Just enough positional astronomy for a wallpaper: Sun and naked-eye planets to within ~0.5°, the Moon to 10″, and the
/// turn from sky to local horizon. Directions are unit vectors. Equatorial ones are J2000 (x → RA 0h, z → north
/// pole); horizon ones are (east, north, up).
enum Sky {
    typealias Vector = SIMD3<Double>

    static func julianDate(_ date: Date) -> Double { date.timeIntervalSince1970 / 86400 + 2440587.5 }

    /// Greenwich mean sidereal time, in degrees.
    static func siderealTime(_ jd: Double) -> Double {
        (280.46061837 + 360.98564736629 * (jd - 2451545)).truncatingRemainder(dividingBy: 360)
    }

    /// Unit vector for a longitude/latitude pair in degrees: RA/Dec, ecliptic, or geographic.
    static func direction(_ longitude: Double, _ latitude: Double) -> Vector {
        let (l, b) = (longitude * .pi / 180, latitude * .pi / 180)
        return [cos(b) * cos(l), cos(b) * sin(l), sin(b)]
    }

    /// Right ascension (0..<360) and declination, in degrees.
    static func raDec(_ v: Vector) -> (ra: Double, dec: Double) {
        let ra = atan2(v.y, v.x) * 180 / .pi
        return (ra < 0 ? ra + 360 : ra, asin(v.z / length(v)) * 180 / .pi)
    }

    private static let obliquity = 23.43928 * Double.pi / 180

    static func equatorial(fromEcliptic v: Vector) -> Vector {
        [v.x, v.y * cos(obliquity) - v.z * sin(obliquity), v.y * sin(obliquity) + v.z * cos(obliquity)]
    }

    /// J2000 equatorial → galactic (x → galactic centre, z → north galactic pole).
    static let galactic = simd_double3x3(rows: [
        [-0.0548755604, -0.8734370902, -0.4838350155],
        [0.4941094279, -0.4448296300, 0.7469822445],
        [-0.8676661490, -0.1980763734, 0.4559837762],
    ])

    /// Turns equatorial directions into horizon ones (east, north, up) for an observer, in degrees.
    // ponytail: ignores precession since J2000 (~0.35° by 2026), which shifts everything together
    static func horizonMatrix(jd: Double, latitude: Double, longitude: Double) -> simd_double3x3 {
        let lst = (siderealTime(jd) + longitude) * .pi / 180, lat = latitude * .pi / 180
        return simd_double3x3(rows: [
            [-sin(lst), cos(lst), 0],
            [-sin(lat) * cos(lst), -sin(lat) * sin(lst), cos(lat)],
            [cos(lat) * cos(lst), cos(lat) * sin(lst), sin(lat)],
        ])
    }

    /// Horizon direction from a ground observer to a point `altitude` km above a latitude/longitude.
    static func lookDirection(latitude: Double, longitude: Double,
                              toLatitude: Double, longitude toLongitude: Double, altitude: Double) -> Vector {
        let radius = 6371.0
        let d = direction(toLongitude, toLatitude) * (radius + altitude) - direction(longitude, latitude) * radius
        let (lat, lon) = (latitude * .pi / 180, longitude * .pi / 180)
        let east: Vector = [-sin(lon), cos(lon), 0]
        let north: Vector = [-sin(lat) * cos(lon), -sin(lat) * sin(lon), cos(lat)]
        return normalize([dot(d, east), dot(d, north), dot(d, direction(longitude, latitude))])
    }

    enum Planet: String, CaseIterable {
        case mercury = "Mercury", venus = "Venus", mars = "Mars", jupiter = "Jupiter", saturn = "Saturn"
    }

    /// Keplerian elements then their rates per century: a (AU), e, I, L, long. perihelion, long. node (degrees).
    /// JPL "Approximate Positions of the Planets", table 1 (1800–2050): ssd.jpl.nasa.gov/planets/approx_pos.html
    private static let elements: [String: [Double]] = [
        "Mercury": [0.38709927, 0.20563593, 7.00497902, 252.25032350, 77.45779628, 48.33076593,
                    0.00000037, 0.00001906, -0.00594749, 149472.67411175, 0.16047689, -0.12534081],
        "Venus": [0.72333566, 0.00677672, 3.39467605, 181.97909950, 131.60246718, 76.67984255,
                  0.00000390, -0.00004107, -0.00078890, 58517.81538729, 0.00268329, -0.27769418],
        "Earth": [1.00000261, 0.01671123, -0.00001531, 100.46457166, 102.93768193, 0.0,
                  0.00000562, -0.00004392, -0.01294668, 35999.37244981, 0.32327364, 0.0],
        "Mars": [1.52371034, 0.09339410, 1.84969142, -4.55343205, -23.94362959, 49.55953891,
                 0.00001847, 0.00007882, -0.00813131, 19140.30268499, 0.44441088, -0.29257343],
        "Jupiter": [5.20288700, 0.04838624, 1.30439695, 34.39644051, 14.72847983, 100.47390909,
                    -0.00011607, -0.00013253, -0.00183714, 3034.74612775, 0.21252668, 0.20469106],
        "Saturn": [9.53667594, 0.05386179, 2.48599187, 49.95424423, 92.59887831, 113.66242448,
                   -0.00125060, -0.00050991, 0.00193609, 1222.49362201, -0.41897216, -0.28867794],
    ]

    /// Heliocentric J2000 ecliptic position in AU, `t` in Julian centuries since J2000.
    private static func heliocentric(_ body: String, _ t: Double) -> Vector {
        let el = elements[body]!
        let (a, e) = (el[0] + el[6] * t, el[1] + el[7] * t)
        let (i, perihelion, node) = ((el[2] + el[8] * t) * .pi / 180, el[4] + el[10] * t, el[5] + el[11] * t)
        let meanAnomaly = remainder(el[3] + el[9] * t - perihelion, 360) * .pi / 180
        var E = meanAnomaly + e * sin(meanAnomaly)
        for _ in 0..<5 { E -= (E - e * sin(E) - meanAnomaly) / (1 - e * cos(E)) }
        let (x, y) = (a * (cos(E) - e), a * sqrt(1 - e * e) * sin(E))
        let (w, o) = ((perihelion - node) * .pi / 180, node * .pi / 180)
        return [
            (cos(w) * cos(o) - sin(w) * sin(o) * cos(i)) * x + (-sin(w) * cos(o) - cos(w) * sin(o) * cos(i)) * y,
            (cos(w) * sin(o) + sin(w) * cos(o) * cos(i)) * x + (-sin(w) * sin(o) + cos(w) * cos(o) * cos(i)) * y,
            sin(w) * sin(i) * x + cos(w) * sin(i) * y,
        ]
    }

    private static func centuries(_ jd: Double) -> Double { (jd - 2451545) / 36525 }

    static func planet(_ planet: Planet, _ jd: Double) -> Vector {
        let t = centuries(jd)
        return normalize(equatorial(fromEcliptic: heliocentric(planet.rawValue, t) - heliocentric("Earth", t)))
    }

    static func sun(_ jd: Double) -> Vector {
        normalize(equatorial(fromEcliptic: -heliocentric("Earth", centuries(jd))))
    }

    /// Geocentric Moon, as a direction.
    // ponytail: no topocentric parallax, so the Moon can sit up to ~1° off its true place against the stars; use
    // `moon(_:latitude:longitude:)` where that matters (eclipses)
    static func moon(_ jd: Double) -> Vector { normalize(moonPosition(jd)) }

    /// The Moon as seen from a place on the ground, which parallax moves up to 1° from where it is from the Earth's
    /// centre: a direction, and its distance in km.
    static func moon(_ jd: Double, latitude: Double, longitude: Double) -> (direction: Vector, km: Double) {
        let lst = (siderealTime(jd) + longitude) * .pi / 180, lat = latitude * .pi / 180
        let here = Vector(cos(lat) * cos(lst), cos(lat) * sin(lst), sin(lat)) * 6371 // spherical Earth
        let away = moonPosition(jd) - here
        return (normalize(away), length(away))
    }

    /// Geocentric Moon in km, J2000, from the main terms of ELP-2000/82 (Meeus, "Astronomical Algorithms", ch. 47),
    /// good to about 10″: real eclipses come out within 20″ and a minute or so of their published times.
    static func moonPosition(_ jd: Double) -> Vector {
        let t = centuries(jd + 69.0 / 86400) // Terrestrial Time, about 69 s ahead of UTC in the 2020s
        func angle(_ degrees: Double) -> Double { degrees * .pi / 180 }
        let L = 218.3164477 + 481267.88123421 * t - 0.0015786 * t * t
        let D = 297.8501921 + 445267.1114034 * t - 0.0018819 * t * t
        let M = 357.5291092 + 35999.0502909 * t - 0.0001536 * t * t
        let Mm = 134.9633964 + 477198.8675055 * t + 0.0087414 * t * t
        let F = 93.2720950 + 483202.0175233 * t - 0.0036539 * t * t
        let (a1, a2, a3) = (119.75 + 131.849 * t, 53.09 + 479264.290 * t, 313.45 + 481266.484 * t)
        let e = 1 - 0.002516 * t - 0.0000074 * t * t // the Earth's orbit slowly rounding
        var (l, r, b) = (0.0, 0.0, 0.0)
        for term in moonTerms {
            let arg = angle(term[0] * D + term[1] * M + term[2] * Mm + term[3] * F), scale = pow(e, abs(term[1]))
            l += term[4] * scale * sin(arg)
            r += term[5] * scale * cos(arg)
        }
        for term in moonLatitudeTerms {
            b += term[4] * pow(e, abs(term[1])) * sin(angle(term[0] * D + term[1] * M + term[2] * Mm + term[3] * F))
        }
        l += 3958 * sin(angle(a1)) + 1962 * sin(angle(L - F)) + 318 * sin(angle(a2))
        b += -2235 * sin(angle(L)) + 382 * sin(angle(a3)) + 175 * sin(angle(a1 - F)) + 175 * sin(angle(a1 + F))
            + 127 * sin(angle(L - Mm)) - 115 * sin(angle(L + Mm))
        // The series is referred to the equinox of date; step back to J2000 by general precession.
        return equatorial(fromEcliptic: direction(L + l / 1e6 - 1.3969713 * t, b / 1e6)) * (385000.56 + r / 1000)
    }

    /// Meeus table 47.A: multiples of D, M, M′ and F, then the longitude (1e-6°) and distance (m) terms.
    private static let moonTerms: [[Double]] = [
        [0, 0, 1, 0, 6288774, -20905355], [2, 0, -1, 0, 1274027, -3699111], [2, 0, 0, 0, 658314, -2955968],
        [0, 0, 2, 0, 213618, -569925], [0, 1, 0, 0, -185116, 48888], [0, 0, 0, 2, -114332, -3149],
        [2, 0, -2, 0, 58793, 246158], [2, -1, -1, 0, 57066, -152138], [2, 0, 1, 0, 53322, -170733],
        [2, -1, 0, 0, 45758, -204586], [0, 1, -1, 0, -40923, -129620], [1, 0, 0, 0, -34720, 108743],
        [0, 1, 1, 0, -30383, 104755], [2, 0, 0, -2, 15327, 10321], [0, 0, 1, 2, -12528, 0],
        [0, 0, 1, -2, 10980, 79661], [4, 0, -1, 0, 10675, -34782], [0, 0, 3, 0, 10034, -23210],
        [4, 0, -2, 0, 8548, -21636], [2, 1, -1, 0, -7888, 24208], [2, 1, 0, 0, -6766, 30824],
        [1, 0, -1, 0, -5163, -8379], [1, 1, 0, 0, 4987, -16675], [2, -1, 1, 0, 4036, -12831],
        [2, 0, 2, 0, 3994, -10445], [4, 0, 0, 0, 3861, -11650], [2, 0, -3, 0, 3665, 14403],
        [0, 1, -2, 0, -2689, -7003], [2, 0, -1, 2, -2602, 0], [2, -1, -2, 0, 2390, 10056],
        [1, 0, 1, 0, -2348, 6322], [2, -2, 0, 0, 2236, -9884], [0, 1, 2, 0, -2120, 5751],
        [0, 2, 0, 0, -2069, 0], [2, -2, -1, 0, 2048, -4950], [2, 0, 1, -2, -1773, 4130],
        [2, 0, 0, 2, -1595, 0], [4, -1, -1, 0, 1215, -3958], [0, 0, 2, 2, -1110, 0],
        [3, 0, -1, 0, -892, 3258], [2, 1, 1, 0, -810, 2616], [4, -1, -2, 0, 759, -1897],
        [0, 2, -1, 0, -713, -2117], [2, 2, -1, 0, -700, 2354], [2, 1, -2, 0, 691, 0],
        [2, -1, 0, -2, 596, 0], [4, 0, 1, 0, 549, -1423], [0, 0, 4, 0, 537, -1117],
        [4, -1, 0, 0, 520, -1571], [1, 0, -2, 0, -487, -1739], [2, 1, 0, -2, -399, 0],
        [0, 0, 2, -2, -381, -4421], [1, 1, 1, 0, 351, 0], [3, 0, -2, 0, -340, 0],
        [4, 0, -3, 0, 330, 0], [2, -1, 2, 0, 327, 0], [0, 2, 1, 0, -323, 1165],
        [1, 1, -1, 0, 299, 0], [2, 0, 3, 0, 294, 0], [2, 0, -1, -2, 0, 8752],
    ]

    /// Meeus table 47.B, its 30 largest terms: multiples of D, M, M′ and F, then the latitude term (1e-6°).
    private static let moonLatitudeTerms: [[Double]] = [
        [0, 0, 0, 1, 5128122], [0, 0, 1, 1, 280602], [0, 0, 1, -1, 277693], [2, 0, 0, -1, 173237],
        [2, 0, -1, 1, 55413], [2, 0, -1, -1, 46271], [2, 0, 0, 1, 32573], [0, 0, 2, 1, 17198],
        [2, 0, 1, -1, 9266], [0, 0, 2, -1, 8822], [2, -1, 0, -1, 8216], [2, 0, -2, -1, 4324],
        [2, 0, 1, 1, 4200], [2, 1, 0, -1, -3359], [2, -1, -1, 1, 2463], [2, -1, 0, 1, 2211],
        [2, -1, -1, -1, 2065], [0, 1, -1, -1, -1870], [4, 0, -1, -1, 1828], [0, 1, 0, 1, -1794],
        [0, 0, 0, 3, -1749], [0, 1, -1, 1, -1565], [1, 0, 0, 1, -1491], [0, 1, 1, 1, -1475],
        [0, 1, 1, -1, -1410], [0, 1, 0, -1, -1344], [1, 0, 0, -1, -1335], [0, 0, 3, 1, 1107],
        [4, 0, 0, -1, 1021], [4, 0, -1, 1, 833],
    ]

    /// How much of the Moon's disc is lit (0...1), and whether it's waxing (east of the Sun along the ecliptic).
    static func moonPhase(_ jd: Double) -> (lit: Double, waxing: Bool) {
        let (moon, sun) = (moon(jd), sun(jd))
        return ((1 - dot(moon, sun)) / 2, dot(cross(sun, moon), equatorial(fromEcliptic: [0, 0, 1])) > 0)
    }
}
