import Foundation
import simd

/// The time of year a layout is drawn in: its leaves, grass and water, after A Tree for the Year's calendar (a white
/// oak's, moved for latitude, and its grass greenness), which the scene works out and passes in; and whether snow
/// lies.
public struct RailSeason: Sendable, Equatable {
    /// The day of the year as a northern tree sees it (half a year on south of the equator).
    public let day: Double
    /// The oak's buds break, its leaves reach full size, colour starts and peaks, and it's bare.
    let breaks: Double, full: Double, onset: Double, peak: Double, bare: Double
    /// How green the grass is, 0 dormant straw to 1.
    let green: Double
    public let snow: Bool

    public init(day: Double, breaks: Double, full: Double, onset: Double, peak: Double, bare: Double, green: Double, snow: Bool) {
        (self.day, self.breaks, self.full, self.onset, self.peak, self.bare, self.green, self.snow) = (day, breaks, full, onset, peak, bare, green, snow)
    }

    /// Mid-July at 42°N.
    public static let summer = RailSeason(day: 196, breaks: 115, full: 144, onset: 278, peak: 301, bare: 318, green: 1, snow: false)

    enum Kind { case spring, summer, autumn, winter }
    var kind: Kind {
        if full <= day, day < onset { return .summer }
        if onset <= day, day < bare + 20 { return .autumn }
        return day >= bare + 20 || day < breaks ? .winter : .spring
    }

    /// The grass's three tones: straw greening with the season, olive through autumn's colour.
    var grass: [SIMD3<Float>] {
        let straw = RailArt.colour(0x9A8C5E), lush = RailArt.colour(0x5A9636), olive = RailArt.colour(0x7E8A44), g = Float(green)
        var base = straw + (lush - straw) * g
        if day > 200 { base += (olive - base) * Float(smoothstep(onset - 10, peak, day)) * g }
        return [base, base * SIMD3(0.93, 0.96, 0.9), base * SIMD3(1.06, 1.05, 1.06)]
    }

    var pond: SIMD3<Float> {
        RailArt.colour([.summer: 0x3C6E8A, .autumn: 0x355E74, .winter: 0x4A6470][kind] ?? 0x4F7F99)
    }

    /// A conifer's two greens.
    var conifer: (String, String) {
        switch kind {
        case .autumn: ("conifer_a", "conifer_dk")
        case .winter: ("conifer_w", "conifer_dk_w")
        default: ("conifer", "conifer_dk")
        }
    }

    /// The season's form of a grassy material (the hill, a bank): olive in autumn, straw in a dormant winter.
    func grassy(_ name: String) -> String {
        if kind == .autumn, day >= onset { return name + "_a" }
        if kind == .winter, green < 0.3 { return name + "_w" }
        return name
    }

    /// One crown cell's leaf on this day, or nil if it has fallen or not yet opened: each turns, browns and falls
    /// on its own day, the tops and some trees first; a quarter of the oaks hold a few dead leaves through winter.
    /// "green" is summer's, which the tree shades itself.
    func leaf(seed: Int, _ x: Int, _ y: Int, _ z: Int, nz: Int) -> String? {
        let d = day, fall = hsh(seed, x, y, z, 5), turn = hsh(seed, x, y, z, 6)
        let tree: Double = (hsh(seed, 1) - 0.5) * 12, cell: Double = (turn - 0.5) * 10 - 4 * Double(z) / Double(nz)
        let sh = tree + cell
        let held = hsh(seed, 3) < 0.25 && fall > 0.8
        guard d > (full + onset) / 2 else {
            if d < breaks + fall * 16 + 1.5 { return held ? "held_leaf" : nil }
            return d < full + 20 ? "leaf_lime" : "green"
        }
        let c = smoothstep(onset + sh, peak + sh, d), browned = smoothstep(peak + sh, bare + 10 + sh, d)
        if d >= peak - 4 + fall * (bare - peak + 4) + sh * 0.5 { return held && d > peak ? "held_leaf" : nil }
        let h = hsh(seed, 2), hue = h < 0.4 ? "wine" : h < 0.75 ? "orange" : "yellow"
        if browned > 0.5 { return "dead_leaf" }
        if c > 0.66 { return "aut_" + hue }
        return c > 0.25 ? "turn_" + hue : "green"
    }
}

func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
    let t = min(max((x - a) / (b - a), 0), 1)
    return t * t * (3 - 2 * t)
}
