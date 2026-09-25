import Foundation
import simd

/// Just enough positional astronomy for a wallpaper: Sun, Moon and naked-eye planets to within ~0.5°, and the
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

    /// Geocentric Moon from the Astronomical Almanac's low-precision series (~0.3°).
    // ponytail: no topocentric parallax, so the Moon can sit up to ~1° off its true place against the stars
    static func moon(_ jd: Double) -> Vector {
        let t = centuries(jd)
        func s(_ degrees: Double) -> Double { sin(degrees * .pi / 180) }
        let longitude = 218.32 + 481267.881 * t
            + 6.29 * s(135.0 + 477198.87 * t) - 1.27 * s(259.3 - 413335.36 * t) + 0.66 * s(235.7 + 890534.22 * t)
            + 0.21 * s(269.9 + 954397.74 * t) - 0.19 * s(357.5 + 35999.05 * t) - 0.11 * s(186.5 + 966404.03 * t)
        let latitude = 5.13 * s(93.3 + 483202.02 * t) + 0.28 * s(228.2 + 960400.89 * t)
            - 0.28 * s(318.3 + 6003.15 * t) - 0.17 * s(217.6 - 407332.21 * t)
        // The series is referred to the equinox of date; step back to J2000 by general precession.
        return equatorial(fromEcliptic: direction(longitude - 1.397 * t, latitude))
    }

    /// How much of the Moon's disc is lit (0...1), and whether it's waxing (east of the Sun along the ecliptic).
    static func moonPhase(_ jd: Double) -> (lit: Double, waxing: Bool) {
        let (moon, sun) = (moon(jd), sun(jd))
        return ((1 - dot(moon, sun)) / 2, dot(cross(sun, moon), equatorial(fromEcliptic: [0, 0, 1])) > 0)
    }
}
