import Foundation

/// When a white oak does what through the year, as days of the year (1 for 1 January) in northern Illinois at 42°N,
/// from USA National Phenology Network records (40–45°N, 2010–2025). Pixel Railway takes its seasons from it. It was
/// made for A Tree for the Year, cut on 2026-11-14: that wallpaper's doc, in git history before the cut, has the
/// research behind these dates and the grass's year.
struct Phenology: Sendable, Equatable {
    /// Buds swell, break, and the leaves reach full size.
    var swell, breaks, full: Double
    /// Colour starts, peaks, half the leaves are down, and the tree is bare.
    var onset, peak, half, bare: Double

    static let whiteOak = Phenology(swell: 105, breaks: 115, full: 144, onset: 278, peak: 301, half: 313, bare: 318)

    /// These dates where you are: spring comes about 4 days later for each degree further from the equator and autumn
    /// about 3 days sooner (Hopkins' rule, which the Japan Meteorological Agency's normals bear out), and `warmer`
    /// degrees C of calibration brings spring 4 days a degree sooner and autumn 5 later. Each shift stops at 45 days,
    /// and latitudes are held to 28°–50°, since below about 30° warm winters don't chill the buds and the rule breaks
    /// down.
    /// ponytail: latitude alone is right in eastern North America and Japan but 6–10 weeks off in western Europe,
    /// which the Gulf Stream warms; local spring and autumn temperature normals (a cached Open-Meteo archive fetch)
    /// would fix it: 4·(5.5 − T[Mar–Apr]) days for spring and 5·(T[Oct–Nov] − 8.5) for autumn.
    func moved(latitude: Double, warmer: Double) -> Phenology {
        let l = min(max(abs(latitude), 28), 50)
        let spring = min(max(4 * (l - 42) - 4 * warmer, -45), 45), autumn = min(max(-3 * (l - 42) + 5 * warmer, -45), 45)
        return Phenology(swell: swell + spring, breaks: breaks + spring, full: full + spring,
                         onset: onset + autumn, peak: peak + autumn, half: half + autumn, bare: bare + autumn)
    }

    /// The day of the year at `date`, 1 to 366 with the time of day as a fraction, as a northern tree would see it:
    /// half a year on south of the equator, so the southern spring falls where the northern one does.
    static func day(_ date: Date, latitude: Double) -> Double {
        guard let year = Calendar.current.dateInterval(of: .year, for: date) else { return 1 }
        let day = date.timeIntervalSince(year.start) / 86400, length = year.duration / 86400
        return (latitude < 0 ? (day + length / 2).truncatingRemainder(dividingBy: length) : day) + 1
    }

    /// How green the grass is on day `d`, 0 dormant straw to 1 at its peak in May and June, after photos and
    /// PhenoCam records of northern Illinois and Wisconsin grass: it greens up from about three weeks before the
    /// oak's buds break (half green as they do) to ten days after, so the ground is green under a still-bare tree; it
    /// cures a little in late summer; and it stays green until the hard freezes a few days after the tree is bare,
    /// then fades to straw over four weeks.
    /// ponytail: no droughts; a dry spell browns unwatered grass about every other summer at 42°N, which a few weeks
    /// of Open-Meteo rain and evaporation would show.
    static func greenness(day d: Double, _ c: Phenology) -> Double {
        guard d > 200 else { return smoothstep(c.breaks - 24, c.breaks + 10, d) }
        return (1 - 0.15 * smoothstep(190, 225, d) * (1 - smoothstep(250, 290, d))) * (1 - smoothstep(c.bare + 2, c.bare + 30, d))
    }
}

private func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
    let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
    return t * t * (3 - 2 * t)
}
