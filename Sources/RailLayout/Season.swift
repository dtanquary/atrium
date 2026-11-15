import Foundation
import simd

/// The time of year a layout is drawn in: its leaves, grass and water, after a white oak's calendar (moved for
/// latitude, and its grass greenness), which the scene works out and passes in; and whether snow
/// lies.
public struct RailSeason: Sendable, Equatable {
    /// The day of the year as a northern tree sees it (half a year on south of the equator).
    public let day: Double
    /// The oak's buds break, its leaves reach full size, colour starts and peaks, and it's bare.
    let breaks: Double, full: Double, onset: Double, peak: Double, bare: Double
    /// How green the grass is, 0 dormant to 1.
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

    /// The grass's three tones: dormant grey-green greening with the season, olive through autumn's colour. (Full
    /// straw, #9A8C5E, made five months of the year a pale board the bare trees vanished into.)
    var grass: [SIMD3<Float>] {
        let straw = RailArt.colour(0x86885A), lush = RailArt.colour(0x62913F), olive = RailArt.colour(0x7E8A44), g = Float(green)
        var base = straw + (lush - straw) * g
        if day > 200 { base += (olive - base) * Float(smoothstep(onset - 10, peak, day)) * g }
        return [base, base * SIMD3(0.93, 0.96, 0.9), base * SIMD3(1.06, 1.05, 1.06)]
    }

    /// A field's colour on this day, and the other rows' colour where it grows in rows or lies in furrows; nil for
    /// grass. Each crop's year at 42°N, moved with the oak's spring before July and its autumn after.
    func crop(_ c: Fields.Crop) -> (SIMD3<Float>, SIMD3<Float>)? {
        // (day, colour, the other rows' colour)
        let soil: UInt32 = 0x6E5A42, furrow: UInt32 = 0x5E4C38, stubble: UInt32 = 0x9C8C64, weathered: UInt32 = 0x847A5E
        let year: [(Double, UInt32, UInt32)]
        switch c {
        case .grass, .meadow: return nil
        case .corn: year = [(0, weathered, weathered), (100, weathered, weathered), (110, soil, furrow), (155, soil, furrow), (170, 0x587A34, soil),
                            (190, 0x3F6A2A, 0x3A6226), (245, 0x3F6A2A, 0x3A6226), (270, 0xB09A5C, 0xA28E52), (290, stubble, stubble), (340, weathered, weathered)]
        case .soy: year = [(0, weathered, weathered), (110, weathered, weathered), (120, soil, furrow), (160, soil, furrow), (178, 0x6A9440, soil),
                           (200, 0x5A8A36, 0x548232), (250, 0x5A8A36, 0x548232), (265, 0xB4A044, 0xAA9640), (282, 0x8E7A58, 0x86724F), (305, stubble, stubble),
                           (345, weathered, weathered)]
        case .wheat: year = [(0, 0x6E7A4A, 0x66724A), (95, 0x6A8A40, 0x64823C), (125, 0x689A3C, 0x62923A), (160, 0x86983E, 0x7E903A), (175, 0xC2A852, 0xBAA04E),
                             (196, 0xC8AC56, 0xC0A452), (202, 0xBCAE7E, 0xB4A676), (262, 0xB4A676, 0xACA070), (275, soil, furrow), (300, 0x6E7A4A, 0x66724A)]
        case .barley: year = [(0, 0x6E7A4A, 0x66724A), (95, 0x6E8E44, 0x688640), (125, 0x74A044, 0x6E9840), (155, 0x9AA048, 0x929844), (170, 0xCCB868, 0xC4B064),
                              (192, 0xC8B470, 0xC0AC6A), (198, 0xC0B286, 0xB8AA7E), (262, 0xB4A880, 0xACA078), (275, soil, furrow), (300, 0x6E7A4A, 0x66724A)]
        case .rape: year = [(0, 0x5E7444, 0x586C40), (95, 0x5E8A3A, 0x588236), (112, 0xD4C43A, 0xCCBC36), (138, 0xD4C43A, 0xCCBC36), (150, 0x6A8A3A, 0x648236),
                            (185, 0x8A8250, 0x827A4A), (200, stubble, stubble), (235, soil, furrow), (255, 0x5E8A3A, 0x588236), (300, 0x5E7444, 0x586C40)]
        case .rice: year = [(0, 0x8C7E5A, 0x84765A), (110, soil, furrow), (122, 0x7E9CA8, 0x7696A2), (150, 0x7E9CA8, 0x7696A2), (165, 0x6E9A56, 0x7E9CA8),
                            (185, 0x5C9A3A, 0x569236), (240, 0x64983A, 0x5E9036), (255, 0xC8A848, 0xC0A044), (276, 0xC8A848, 0xC0A044), (286, 0xA89A70, 0xA09268),
                            (330, 0x8C7E5A, 0x84765A)]
        case .greens: year = [(0, soil, furrow), (120, soil, furrow), (140, 0x5E8E44, soil), (270, 0x5E8E44, soil), (290, soil, furrow)]
        }
        let d = ((day < 200 ? day - (breaks - 115) : day - (bare - 318)) + 365).truncatingRemainder(dividingBy: 365)
        let k = year.lastIndex { $0.0 <= d } ?? year.count - 1, a = year[k], b = year[(k + 1) % year.count]
        let span = (b.0 - a.0 + 365).truncatingRemainder(dividingBy: 365), t = Float(span > 0 ? min(max((d - a.0 + 365).truncatingRemainder(dividingBy: 365) / span, 0), 1) : 0)
        let mix = { (x: UInt32, y: UInt32) in RailArt.colour(x) + (RailArt.colour(y) - RailArt.colour(x)) * t }
        return (mix(a.1, b.1), mix(a.2, b.2))
    }

    /// The leaves a broadleaf has dropped round its foot: their colour, and how thickly they lie (0 to 1), from the
    /// time they start falling until a few weeks after the tree is bare, browning as they lie.
    func litter(seed: Int) -> (SIMD3<Float>, Float)? {
        let fallen = smoothstep(peak - 6, bare, day) * (1 - smoothstep(bare + 8, bare + 40, day))
        guard fallen > 0.05 else { return nil }
        let h = hsh(seed, 2), hue = RailArt.colour(h < 0.4 ? 0x7A2820 : h < 0.75 ? 0xC8641E : 0xD8A830)
        return ((hue + (RailArt.colour(0x987A5A) - hue) * Float(smoothstep(peak, bare + 12, day))) * 0.9, Float(fallen))
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

    /// The season's form of a grassy material (the hill, a bank): olive in autumn, grey-green in a dormant winter.
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
