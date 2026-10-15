import Foundation

/// Pixel Railway's materials, and every vehicle as slices: data only. Colours are from the railroads' own published
/// paint where there is one (Union Pacific's Armour Yellow and Harbor Mist Gray) and otherwise matched to photos;
/// docs/pixel-railway.md lists the sources. No heralds, numbers or lettering are drawn on anything.
///
/// A vehicle is a stack of layers, bottom (z = 0) to top. Each layer is `width` rows across the car (row 0 on its
/// left) of `length` characters along it, the front at the right end. A layer can be written short: one row is
/// every row; two are (edge, inner) for [edge, inner, inner, inner, edge]; three are (edge, mid, centre). `.` is
/// empty. Only the outside of a layer shows, so inner rows matter only on top. Characters name materials through
/// the vehicle's livery.
public enum RailArt {
    /// What a material does besides its colour: lit at night, takes snow, and so on.
    struct Flags: OptionSet, Sendable {
        let rawValue: UInt8
        static let window = Flags(rawValue: 1)      // lit at night
        static let dome = Flags(rawValue: 2)        // dome glass, half lit
        static let headlight = Flags(rawValue: 4)
        static let lamp = Flags(rawValue: 8)        // a lamp head, lit at night in the era's lamp colour
        static let snowTop = Flags(rawValue: 16)    // snow lies on its top faces
        static let snowAll = Flags(rawValue: 32)    // snow on every face (the hill, the banks)
    }

    /// Every material: name, colour and flags (W window, D dome glass, H headlight, L lamp, S snow on top, A snow
    /// all over). Index 0 is empty.
    static let table: [(name: String, hex: UInt32, flags: Flags)] = [
        // running gear and shared
        ("truck", 0x2A2A2C, []), ("truckgrey", 0x6E6E6A, []), ("alum", 0xA8ABA8, []), ("cabglass", 0x2E3A44, []),
        ("window", 0x34404A, .window), ("headlight", 0xF4E8C0, .headlight), ("black", 0x2A2B2E, []),
        // Santa Fe warbonnet and stainless
        ("sf_silver", 0xB4B8B6, []), ("sf_roof", 0xA8ACAA, []), ("sf_flute", 0x8E9290, []), ("sf_flute_lt", 0xC4C8C6, []),
        ("sf_red", 0x9B2322, []), ("sf_yellow", 0xCF9608, []), ("fan", 0x3A3E40, []), ("fan_lt", 0x5A5E60, []),
        // Union Pacific (its published colours)
        ("up_yellow", 0xF2B800, []), ("up_grey", 0x635F56, []), ("up_grey_lt", 0x77736A, []), ("up_nose", 0x2E3B2A, []),
        ("up_red", 0xD10000, []), ("dome_glass", 0x5C7486, .dome),
        // Great Northern (estimates)
        ("gn_orange", 0xE0661E, []), ("gn_orange_car", 0xE27A2E, []), ("gn_green", 0x2F3B2A, []), ("gn_green_lt", 0x3E4C38, []),
        ("gn_gold", 0xC9A23A, []),
        // steam
        ("bb_black", 0x38414B, []), ("bb_smokebox", 0x737D85, []), ("bb_board", 0x4A525A, []), ("bb_drivers", 0x23272C, []),
        ("bb_dome", 0x2E353C, []), ("bb_rod", 0x8A9096, []), ("bb_ridge", 0x4C5660, []), ("coal", 0x353638, []),
        ("coal_glint", 0x6B7076, []), ("bell", 0xE9D4B3, []),
        ("sp_orange", 0xEE7030, []), ("sp_red", 0xC42530, []), ("sp_black", 0x25262A, []), ("sp_smokebox", 0x8E99BA, []),
        ("mw_grey", 0x838383, []), ("mw_top", 0x303143, []), ("mw_orange", 0xF07B47, []), ("mw_maroon", 0xAC5A60, []),
        ("mw_roof", 0x9A9A98, []),
        // freight (estimates)
        ("car_red", 0x6E3A2C, []), ("car_red_dk", 0x5A2E24, []), ("runboard", 0x9EA2A0, []), ("pfe_orange", 0xE8761E, []),
        ("pfe_orange_dk", 0xC8641A, []), ("pfe_roof", 0xA8ABA8, []), ("hatch", 0x6E7072, []), ("hopper", 0x2E2F33, []),
        ("coal_dk", 0x1B1B1D, []), ("coal_ridge", 0x34373C, []), ("tank", 0x1C1C1C, []), ("tank_hl", 0x3A3A3A, []),
        ("cab_yellow", 0xF2B800, []), ("cab_red", 0xB02A22, []),
        // road vehicles
        ("v40_maroon", 0x5A1E24, []), ("v50_cream", 0xEDE6D2, []), ("v50_turq", 0x4AA8A0, []), ("v_glass", 0x3A4650, []),
        // buildings
        ("sp_wall", 0xD8B860, []), ("sp_trim", 0x6E4E30, []), ("sp_roof", 0x4E6A3A, .snowTop), ("brick", 0x8E4A3A, []),
        ("brick_dk", 0x74382C, []), ("slate", 0x4A5058, .snowTop), ("canopy", 0x6E6E6A, .snowTop),
        ("roof_green", 0x4E6A4A, .snowTop), ("roof_red", 0x8A4A3E, .snowTop), ("roof_black", 0x3A3A3C, .snowTop),
        ("roof_grey", 0x6E6E6A, .snowTop),
        ("wall_white", 0xE4E0D4, []), ("wall_cream", 0xE0D2A8, []), ("wall_yellow", 0xD8C080, []), ("wall_grey", 0xA8A49A, []),
        ("wall_blue", 0x8EA2B0, []), ("wall_brick", 0x9A5A44, []), ("door", 0x5A4232, []), ("house_win", 0x3C4650, .window),
        ("chimney", 0x7A4A3A, .snowTop), ("platform", 0xB0ACA4, .snowTop), ("platform_edge", 0xD8D4C8, .snowTop),
        ("wood_tank", 0x8A5A3A, []), ("wood_tank_dk", 0x6A4430, []), ("tank_roof", 0x4A3A2E, .snowTop), ("timber", 0x5A4632, []),
        // lineside
        ("post", 0x3A3634, []), ("post_white", 0xE8E4DC, []), ("pole", 0x5A4A3A, []), ("crossarm", 0x4A3C30, []),
        ("lamp", 0xF0E8D0, .lamp), ("sig_head", 0x1A1A1C, []), ("concrete", 0xA8A49C, .snowTop), ("steel", 0x4E5258, []),
        ("steel_lt", 0x6A6E74, []), ("deck", 0x5A5650, .snowTop),
        // nature
        ("leaf", 0x4A6A24, .snowTop), ("leaf_lt", 0x6E8E3A, .snowTop), ("leaf_dk", 0x3E541A, .snowTop), ("trunk", 0x5A4232, []),
        ("conifer", 0x2A4628, .snowTop), ("conifer_dk", 0x22382A, .snowTop), ("twig", 0x3E3630, []), ("twig_mass", 0x6A5E54, []),
        ("hill", 0x557F33, .snowAll), ("hill_lt", 0x6A9440, .snowAll), ("hill_dk", 0x4A7230, .snowAll),
        ("tunnel", 0x121214, []), ("portal", 0x8A8884, .snowTop), ("bank", 0x6A8A3A, .snowAll),
    ]

    /// A material's index by name; 0 is empty.
    static let index: [String: UInt8] = Dictionary(uniqueKeysWithValues: table.enumerated().map { ($1.name, UInt8($0 + 1)) })
    /// Colours as floats, and flags, by index (0 is empty).
    static let rgb: [SIMD3<Float>] = [.zero] + table.map { colour($0.hex) }
    static let flags: [Flags] = [[]] + table.map(\.flags)
    /// The colour each material turns in snow, on the faces snow lies on.
    static let snowTone: [SIMD3<Float>] = [.zero] + table.map {
        colour(["hill": 0xE4EAF3, "hill_dk": 0xCCD6E6, "bank": 0xE4EAF3][$0.name] ?? 0xF4F6FA)
    }

    static func colour(_ hex: UInt32) -> SIMD3<Float> {
        SIMD3(Float(hex >> 16 & 0xFF), Float(hex >> 8 & 0xFF), Float(hex & 0xFF))
    }

    static func mat(_ name: String) -> UInt8 { index[name]! }
}

/// A box of material indices, x along (the front at high x), y across, z up.
struct Voxels: Sendable {
    let nx: Int, ny: Int, nz: Int
    var cells: [UInt8]

    init(_ nx: Int, _ ny: Int, _ nz: Int) {
        (self.nx, self.ny, self.nz) = (nx, ny, nz)
        cells = [UInt8](repeating: 0, count: nx * ny * nz)
    }

    subscript(x: Int, y: Int, z: Int) -> UInt8 {
        get { cells[x + nx * (y + ny * z)] }
        set { cells[x + nx * (y + ny * z)] = newValue }
    }

    /// Fills x in `xs`, y in `ys`, z in `zs` (half-open, as Python's slices) with `m`.
    mutating func fill(_ xs: Range<Int>, _ ys: Range<Int>, _ zs: Range<Int>, _ m: UInt8) {
        for z in zs where z < nz { for y in ys where y < ny { for x in xs where x < nx { self[x, y, z] = m } } }
    }
}

/// A rail vehicle: its voxels, length in art pixels (2 ft each) and where its bogies sit.
struct RailVehicle: Sendable {
    let name: String
    let grid: Voxels
    /// The bogie centres' spacing as a fraction of the length (their pivots stand at ±bogies/2 of it).
    let bogies: Double
    var length: Int { grid.nx }

    init(_ name: String, _ layers: [[String]], _ livery: [Character: String], width: Int = 5, bogies: Double = 0.75) {
        self.name = name
        self.bogies = bogies
        let rows = layers.map { RailVehicle.expand($0, width) }
        let length = rows[0][0].count
        var grid = Voxels(length, width, rows.count)
        for (z, layer) in rows.enumerated() {
            for (r, row) in layer.enumerated() {
                precondition(row.count == length, "\(name): a row of \(row.count) in a car of \(length)")
                for (x, ch) in row.enumerated() where ch != "." { grid[x, r, z] = RailArt.mat(livery[ch]!) }
            }
        }
        self.grid = grid
    }

    private static func expand(_ rows: [String], _ width: Int) -> [String] {
        switch (width, rows.count) {
        case (5, 1): Array(repeating: rows[0], count: 5)
        case (5, 2): [rows[0], rows[1], rows[1], rows[1], rows[0]]
        case (5, 3): [rows[0], rows[1], rows[2], rows[1], rows[0]]
        case (3, 1): Array(repeating: rows[0], count: 3)
        case (3, 2): [rows[0], rows[1], rows[0]]
        default: rows
        }
    }
}

/// A train as it runs: its name in Settings, its era, its vehicles front first, and its cruising speed in art
/// pixels a second.
public struct Consist: Sendable {
    public let key: String, name: String, era: RailEra
    let vehicles: [RailVehicle], cruise: Double
    /// Freight trains run through the station; passenger trains stop.
    var freight: Bool { ["bigboy", "gp9", "switcher"].contains(key) }
    /// Nothing over 20 px: it takes the tightest curve, on a loop inside another.
    public var short: Bool { vehicles.allSatisfy { $0.length <= 20 } }
    /// Couplers and all, as the track sees it.
    var length: Double { Double(vehicles.reduce(0) { $0 + $1.length + 2 } - 2) }
    /// The tightest curve it looks right on: model-railway compression, half again the longest car and more.
    var minRadius: Double { max(32, 1.6 * Double(vehicles.map(\.length).max()!)) }
}

/// A layout's era: its trains, buildings, crossings and signals.
public enum RailEra: Int, CaseIterable, Sendable {
    case streamliners, steam
}

extension RailArt {
    // MARK: shapes (front at the right)
    private static func r(_ s: String, _ n: Int) -> String { String(repeating: s, count: n) }

    static let trucks25 = ["..kkkkk..kkkkkkk..kkkkk.."]
    static let f7a = [
        trucks25,
        ["sssssssssssssssyrrrrrrrr.", "sssssssssssssssyrrrrrrrrr", "sssssssssssssssyrrrrrrrrh"],
        ["ssssssssssssssssyrrrrrr..", "ssssssssssssssssyrrrrrrr.", "ssssssssssssssssyrrrrrry."],
        ["sssssssssssssssssyrccrc..", "sssssssssssssssssyrrrrc..", "sssssssssssssssssyrrrrc.."],
        ["SSSSSSSSSSSSSSSSSyrrrr...", "SFFSFFSSSSSSSSSSSyrrrr...", "SSSSSSSSSSSffSSSSyrrrr...",
         "SFFSFFSSSSSSSSSSSyrrrr...", "SSSSSSSSSSSSSSSSSyrrrr..."],
    ]
    static let f7b = [
        trucks25, [r("s", 25)], [r("s", 25)],
        ["sssssssp" + r("s", 8) + "p" + r("s", 8), r("s", 25)],
        [r("S", 25), "SFFSFFSSSSSSSSSSSSSSSSSSS", "SSSSSSSSSSSffSSSSSSSSSSSS", "SFFSFFSSSSSSSSSSSSSSSSSSS", r("S", 25)],
    ]
    static let coachTrucks = ["..kkkk" + r(".", 18) + "kkkk.."]
    static let hiLevel = [
        coachTrucks, [r("d", 30), r("s", 30)], ["s" + r("swws", 7) + "s", r("s", 30)], [r("d", 30), r("s", 30)],
        ["s" + r("wwws", 7) + "s", r("s", 30)], [r("S", 30), r("L", 30), r("S", 30)],
    ]
    static let e9 = [
        ["..gggggg...kkkkkkkkkkkkk....gggggg."],
        [r("y", 34) + ".", r("y", 34) + "n"],
        [r("y", 33) + "..", r("y", 32) + "nn.", r("y", 32) + "nh."],
        [r("y", 27) + "ccycc...", r("y", 30) + "cc...", r("y", 30) + "cc..."],
        [r("G", 30) + ".....", "GffGffGGGGGfGGGGGGGGfGGGGGGGGG.....", r("G", 30) + ".....",
         "GffGffGGGGGfGGGGGGGGfGGGGGGGGG.....", r("G", 30) + "....."],
    ]
    /// A lightweight coach: skirt, window band, letterboard, roof.
    static let coach = [coachTrucks, [r("a", 30)], ["a" + r("awwa", 7) + "a", r("a", 30)], [r("b", 30)], [r("R", 30), r("R", 30), r("Q", 30)]]
    static let dome = Array(coach[..<4]) + [
        [r("R", 30), r("R", 30), r("Q", 30)],
        [r(".", 30), r(".", 10) + "RDDDDDDDDR" + r(".", 10), r(".", 10) + "RDDDDDDDDR" + r(".", 10),
         r(".", 10) + "RDDDDDDDDR" + r(".", 10), r(".", 30)],
    ]
    /// Great Northern's cars: an orange window band, green above and below.
    static let gnCoach = [coach[0], coach[1], ["o" + r("owwo", 7) + "o", r("o", 30)], coach[3], coach[4]]
    static let gnDome = [dome[0], dome[1], gnCoach[2], dome[3], dome[4], dome[5]]
    static let gnF7a = [
        trucks25,
        [r("o", 24) + ".", r("o", 25), r("o", 24) + "h"],
        [r("o", 23) + "..", r("o", 24) + ".", r("o", 24) + "."],
        [r("e", 17) + "yoccoc..", r("e", 17) + "yooooc..", r("e", 17) + "yooooc.."],
        [r("e", 17) + "yoooo...", "eFFeFF" + r("e", 11) + "yoooo...", r("e", 11) + "ff" + r("e", 4) + "yoooo...",
         "eFFeFF" + r("e", 11) + "yoooo...", r("e", 17) + "yoooo..."],
    ]
    static let gnF7b = [
        trucks25, [r("o", 25)], [r("o", 25)], [r("e", 25)],
        [r("e", 25), "eFFeFF" + r("e", 19), r("e", 11) + "ff" + r("e", 12), "eFFeFF" + r("e", 19), r("e", 25)],
    ]
    static let bigBoy = [
        ["...kkkk..ddrddddrdd..ddrddddrdd.kkkkpp", "..." + r("k", 33) + "pp"],
        ["." + r("C", 7) + r("a", 26) + "xx..", "." + r("C", 7) + r("b", 26) + "xx.."],
        ["." + r("C", 7) + r(".", 30), "." + r("C", 7) + r("b", 26) + "xx..", "." + r("C", 7) + r("b", 26) + "xh.."],
        ["." + "CccCccC" + r(".", 30), "." + r("C", 7) + r("b", 26) + "xx..", "." + r("C", 7) + r("b", 26) + "xx.."],
        ["." + r("C", 7) + r(".", 30), "." + r("C", 7) + r("b", 26) + "x...", "." + r("C", 7) + r("B", 26) + "x..."],
        ["." + r("C", 7) + r(".", 30), "." + r("C", 7) + r(".", 30), "." + r("C", 7) + "......mm......mmm......m......"],
    ]
    static let bigBoyTender = [
        ["..kkkk........kkkk.."], [r("b", 20)], [r("b", 20)], [r("b", 20)],
        [r("b", 20), r("b", 10) + "qqQqqqqQqq", "bbbHHbbbbb" + "qQqqqQqqqq", r("b", 10) + "qqqqQqqqqQ", r("b", 20)],
        [r(".", 20), r(".", 12) + "qqQqqq..", r(".", 12) + "qQqqqq.."],
    ]
    static let gs4 = [
        ["..kkk..Rddddddddddd...kkkk....pp", ".." + r("k", 28) + "pp"],
        [".RRRRRR" + r("o", 22) + "xx.", ".KKKKKK" + r("K", 22) + "xx."],
        [".KKKKKK" + r(".", 25), ".KKKKKK" + r("K", 22) + "xx.", ".KKKKKK" + r("K", 22) + "xh."],
        [".KccKcK" + r(".", 25), ".KKKKKK" + r("K", 22) + "xx.", ".KKKKKK" + r("K", 22) + "xx."],
        [".KKKKKK" + r(".", 25), ".KKKKKK" + r("K", 22) + "x..", ".KKKKKK" + r("K", 22) + "x.."],
        [r(".", 32), ".KKKKKK" + r(".", 25), ".KKKKKK" + "...KKKKKKKKKKKKKKKK.mm..."],
    ]
    static let gs4Tender = [
        ["..kkkk......kkkk.."], [r("R", 18)], [r("o", 18), r("K", 18)], [r("R", 18), r("K", 18)],
        [r("K", 18), r("K", 18), "KKKKHHKKKKKKKKKKKK"],
    ]
    static let daylight = [coachTrucks, [r("R", 30)], ["o" + r("owwo", 7) + "o", r("o", 30)], [r("R", 30)], [r("K", 30), r("K", 30), r("J", 30)]]
    /// Milwaukee Road's class F7 4-6-4, shrouded.
    static let hudson = [
        ["..kkk.....kkkkkkkkk..kkkk..kk.", ".." + r("G", 27) + "."],
        [r("G", 29) + ".", r("G", 30), r("G", 29) + "h"],
        [r("O", 28) + "..", r("O", 28) + "G.", r("O", 28) + "h."],
        ["GGGccGGGGGGGGGGGGGGGGGGGGG" + r("G", 2) + "..", r("G", 28) + "..", r("G", 28) + ".."],
        [r("G", 26) + "....", r("G", 26) + "....", r("T", 26) + "...."],
    ]
    static let hudsonTender = [["..kkkk......kkkk.."], [r("O", 18)], [r("M", 18)], [r("G", 18)], [r("G", 18), r("G", 18), r("T", 18)]]
    static let hiawatha = [coachTrucks, [r("O", 30)], ["M" + r("MwwM", 7) + "M", r("M", 30)], [r("O", 30)], [r("Q", 30)]]
    static let boxcar = [
        [".kkk" + r(".", 14) + "kkk."], [r("R", 9) + "DDDD" + r("R", 9), r("R", 22)], [r("R", 9) + "DDDD" + r("R", 9), r("R", 22)],
        [r("R", 22)], [r("R", 22), r("R", 22), r("P", 22)],
    ]
    static let reefer = [
        [".kkk" + r(".", 14) + "kkk."], [r("o", 9) + "dddd" + r("o", 9), r("o", 22)], [r("o", 9) + "dddd" + r("o", 9), r("o", 22)],
        [r("o", 22)], [r("A", 22), "AhA" + r("A", 16) + "AhA", r("A", 22)],
    ]
    static let hopper = [
        [".kkk" + r(".", 10) + "kkk."], [r("H", 18)], [r("H", 18)], [r("H", 18), "H" + r("q", 16) + "H"],
        [r(".", 18), r(".", 3) + "qQq" + r(".", 4) + "qgq" + r(".", 5), r(".", 3) + "QqQ" + r(".", 4) + "qQq" + r(".", 5)],
    ]
    static let tankCar = [
        [".kkk" + r(".", 12) + "kkk.", ".kkk" + r("k", 12) + "kkk."], [".TTTTTTTTTTTTTTTTTT.", r("T", 20)],
        [".TTTTTTTTTTTTTTTTTT.", r("T", 20)], [r(".", 20), ".TTTTTTTTTTTTTTTTTT.", ".JJJJJJJJJJJJJJJJJJ."],
        [r(".", 20), r(".", 20), r(".", 9) + "TT" + r(".", 9)],
    ]
    static let caboose = [
        [".kkk" + r(".", 8) + "kkk."], [r("y", 16)], [r("y", 16)], ["yywyyyyyyyyyywyy", r("y", 16)], [r("R", 16)],
        [r(".", 16), r(".", 6) + "ywwy" + r(".", 6), r(".", 6) + "yyyy" + r(".", 6)], [r(".", 16), r(".", 6) + "RRRR" + r(".", 6)],
    ]
    // MARK: short stock for a tight inner loop: nothing over 20 px, so its radius floor is 32
    /// A Budd Rail Diesel Car, fluted stainless, a cab at each end.
    static let rdc = [
        ["..kkk..........kkk.."], [r("d", 20), r("s", 20)], ["c" + "sswwsswwsswwsswwss" + "c", r("s", 20)],
        [r("s", 20), r("s", 20), r("s", 19) + "h"], [r("S", 20), "SffS" + r("L", 12) + "SffS", r("S", 20)],
    ]
    /// A hood unit: the long hood behind the cab, the short hood ahead, walkways either side.
    static let gp9 = [
        ["...kkkk......kkkk..."], [r("y", 20)], [r(".", 12) + "yccy" + "....", r("y", 20), r("y", 19) + "h"],
        [r(".", 12) + "GccG" + "....", r("G", 16) + "....", "GffGff" + r("G", 10) + "...."], [r(".", 12) + "GGGG" + "...."],
    ]
    static let box18 = [
        [".kkk" + r(".", 10) + "kkk."], [r("R", 7) + "DDDD" + r("R", 7), r("R", 18)], [r("R", 7) + "DDDD" + r("R", 7), r("R", 18)],
        [r("R", 18)], [r("R", 18), r("R", 18), r("P", 18)],
    ]
    /// An 0-6-0.
    static let switcher = [
        ["..ddrddrddd...kk.p", ".." + r("k", 15) + "p"], [".CCCC" + r("a", 11) + "xx", ".CCCC" + r("b", 11) + "xx"],
        [".CCCC" + r(".", 13), ".CCCC" + r("b", 11) + "xx", ".CCCC" + r("b", 11) + "xh"],
        [".CccC" + r(".", 13), ".CCCC" + r("b", 11) + "x.", ".CCCC" + r("B", 11) + "x."],
        [".CCCC" + r(".", 13), ".CCCC" + r(".", 13), ".CCCC" + "...mm....m..."],
    ]
    static let slopeTender = [[".kkk....kkk."], [r("b", 12)], [r("b", 12)], ["....bbbbbbbb", "....qqQqqqqq", "....qQqqqQqq"]]
    /// A road car, 3 wide.
    static let car = [["aaaaaaa"], [".gwwg..", ".rrrr.."]]

    // MARK: liveries
    private static let truck: [Character: String] = ["k": "truck", "g": "truckgrey", "h": "headlight", "c": "cabglass", "w": "window"]
    private static func lv(_ base: [Character: String], _ more: [Character: String]) -> [Character: String] { base.merging(more) { $1 } }

    static let sfF7a = RailVehicle("Santa Fe F7 A", f7a, lv(truck, ["s": "sf_silver", "S": "sf_roof", "r": "sf_red", "y": "sf_yellow", "F": "fan", "f": "fan_lt"]))
    static let sfF7b = RailVehicle("Santa Fe F7 B", f7b, lv(truck, ["s": "sf_silver", "S": "sf_roof", "F": "fan", "f": "fan_lt", "p": "sf_flute"]))
    static let sfHiLevel = RailVehicle("Hi-Level coach", hiLevel, lv(truck, ["s": "sf_silver", "d": "sf_flute", "S": "sf_roof", "L": "sf_flute_lt"]))
    static let upE9 = RailVehicle("UP E9", e9, lv(truck, ["y": "up_yellow", "G": "up_grey", "n": "up_nose", "f": "fan"]))
    static let upCoach = RailVehicle("UP coach", coach, lv(truck, ["k": "alum", "a": "up_yellow", "b": "up_grey", "R": "up_grey", "Q": "up_grey_lt"]))
    static let upDome = RailVehicle("UP Astra Dome", dome, lv(truck, ["k": "alum", "a": "up_yellow", "b": "up_grey", "R": "up_grey", "Q": "up_grey_lt", "D": "dome_glass"]))
    static let gnF7aCar = RailVehicle("GN F7 A", gnF7a, lv(truck, ["o": "gn_orange", "e": "gn_green", "y": "gn_gold", "F": "fan", "f": "fan_lt"]))
    static let gnF7bCar = RailVehicle("GN F7 B", gnF7b, lv(truck, ["o": "gn_orange", "e": "gn_green", "F": "fan", "f": "fan_lt"]))
    static let gnCoachCar = RailVehicle("GN coach", gnCoach, lv(truck, ["a": "gn_green", "b": "gn_green", "R": "gn_green", "Q": "gn_green_lt", "o": "gn_orange_car"]))
    static let gnDomeCar = RailVehicle("GN dome", gnDome, lv(truck, ["a": "gn_green", "b": "gn_green", "R": "gn_green", "Q": "gn_green_lt", "D": "dome_glass", "o": "gn_orange_car"]))
    static let bb = RailVehicle("Big Boy", bigBoy, ["k": "bb_drivers", "d": "bb_drivers", "r": "bb_rod", "p": "black", "C": "bb_black", "c": "cabglass",
                                                    "a": "bb_board", "b": "bb_black", "B": "bb_ridge", "x": "bb_smokebox", "h": "headlight", "m": "bb_dome"], bogies: 0.7)
    static let bbTender = RailVehicle("Big Boy tender", bigBoyTender, ["k": "truck", "b": "bb_black", "q": "coal", "Q": "coal_glint", "H": "bb_dome"])
    static let spGS4 = RailVehicle("SP GS-4", gs4, ["k": "truck", "d": "bb_drivers", "R": "sp_red", "p": "black", "o": "sp_orange", "K": "sp_black",
                                                    "x": "sp_smokebox", "c": "cabglass", "h": "headlight", "m": "bb_dome"], bogies: 0.7)
    static let spTender = RailVehicle("GS-4 tender", gs4Tender, ["k": "truck", "R": "sp_red", "o": "sp_orange", "K": "sp_black", "H": "bb_dome"])
    static let spCar = RailVehicle("Daylight coach", daylight, lv(truck, ["R": "sp_red", "o": "sp_orange", "K": "sp_black", "J": "bb_dome"]))
    static let mwHudson = RailVehicle("Milwaukee F7 4-6-4", hudson, ["k": "bb_drivers", "G": "mw_grey", "O": "mw_orange", "T": "mw_top", "c": "cabglass",
                                                                     "h": "headlight"], bogies: 0.7)
    static let mwTender = RailVehicle("Hiawatha tender", hudsonTender, ["k": "truck", "O": "mw_orange", "M": "mw_maroon", "G": "mw_grey", "T": "mw_top"])
    static let mwCar = RailVehicle("Hiawatha coach", hiawatha, lv(truck, ["O": "mw_orange", "M": "mw_maroon", "Q": "mw_roof"]))
    static let box = RailVehicle("40 ft boxcar", boxcar, ["k": "truck", "R": "car_red", "D": "car_red_dk", "P": "runboard"])
    static let pfe = RailVehicle("PFE reefer", reefer, ["k": "truck", "o": "pfe_orange", "d": "pfe_orange_dk", "A": "pfe_roof", "h": "hatch"])
    static let hop = RailVehicle("Twin hopper", hopper, ["k": "truck", "H": "hopper", "q": "coal_dk", "Q": "coal_ridge", "g": "coal_glint"])
    static let tank = RailVehicle("Tank car", tankCar, ["k": "truck", "T": "tank", "J": "tank_hl"])
    static let cab = RailVehicle("UP caboose", caboose, ["k": "truck", "y": "cab_yellow", "w": "window", "R": "cab_red"])

    static let rdcCar = RailVehicle("Budd RDC", rdc, lv(truck, ["s": "sf_silver", "d": "sf_flute", "S": "sf_roof", "L": "sf_flute_lt", "f": "fan"]))
    static let upGP9 = RailVehicle("UP GP9", gp9, lv(truck, ["y": "up_yellow", "G": "up_grey", "f": "fan"]))
    static let shortBox = RailVehicle("Short boxcar", box18, ["k": "truck", "R": "car_red", "D": "car_red_dk", "P": "runboard"])
    static let sw = RailVehicle("0-6-0 switcher", switcher, ["k": "bb_drivers", "d": "bb_drivers", "r": "bb_rod", "p": "black", "C": "bb_black", "c": "cabglass",
                                                             "a": "bb_board", "b": "bb_black", "B": "bb_ridge", "x": "bb_smokebox", "h": "headlight", "m": "bb_dome"], bogies: 0.6)
    static let swTender = RailVehicle("Slope-back tender", slopeTender, ["k": "truck", "b": "bb_black", "q": "coal", "Q": "coal_glint"])

    static func roadCar(_ era: RailEra) -> RailVehicle {
        let (body, roof) = era == .steam ? ("v40_maroon", "v40_maroon") : ("v50_turq", "v50_cream")
        return RailVehicle("road car", car, ["a": body, "g": "v_glass", "w": "v_glass", "r": roof], width: 3, bogies: 0.6)
    }

    /// Every train, by key.
    public static let trains: [String: Consist] = Dictionary(uniqueKeysWithValues: [
        Consist(key: "santafe", name: "Santa Fe F7 warbonnet with Hi-Levels", era: .streamliners,
                vehicles: [sfF7a, sfF7b, sfHiLevel, sfHiLevel, sfHiLevel], cruise: 18),
        Consist(key: "up", name: "Union Pacific E9 with an Astra Dome", era: .streamliners, vehicles: [upE9, upCoach, upDome, upCoach], cruise: 17),
        Consist(key: "gn", name: "Great Northern F7 streamliner", era: .streamliners,
                vehicles: [gnF7aCar, gnF7bCar, gnCoachCar, gnDomeCar, gnCoachCar], cruise: 16),
        Consist(key: "bigboy", name: "Union Pacific Big Boy, mixed freight", era: .steam,
                vehicles: [bb, bbTender, box, pfe, hop, hop, tank, box, pfe, cab], cruise: 13),
        Consist(key: "gs4", name: "Southern Pacific GS-4 Daylight", era: .steam, vehicles: [spGS4, spTender, spCar, spCar, spCar], cruise: 17),
        Consist(key: "hiawatha", name: "Milwaukee Road Hiawatha", era: .steam, vehicles: [mwHudson, mwTender, mwCar, mwCar, mwCar], cruise: 18),
        // short trains, for a tight inner loop
        Consist(key: "rdc", name: "Budd RDC pair", era: .streamliners, vehicles: [rdcCar, rdcCar], cruise: 15),
        Consist(key: "gp9", name: "Union Pacific GP9 local", era: .streamliners, vehicles: [upGP9, shortBox, hop, shortBox], cruise: 12),
        Consist(key: "switcher", name: "0-6-0 switcher with short cars", era: .steam, vehicles: [sw, swTender, shortBox, hop], cruise: 11),
    ].map { ($0.key, $0) })

    /// Each era's trains, in the order a layout tries them: the main line's, or the short ones for an inner loop.
    public static func trains(of era: RailEra, short: Bool = false) -> [Consist] {
        trains.values.filter { $0.era == era && $0.short == short }.sorted { $0.key < $1.key }
    }
}
