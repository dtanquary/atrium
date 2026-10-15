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
        static let flat = Flags(rawValue: 64)       // shaded flat: a bank's 1:1 steps would read as a checkerboard
    }

    /// Every material: name, colour and flags (W window, D dome glass, H headlight, L lamp, S snow on top, A snow
    /// all over, F flat). Index 0 is empty. The grassy ones have an autumn (`_a`) and a dormant winter (`_w`) form.
    static let table = materials + containerMaterials
    private static let materials: [(name: String, hex: UInt32, flags: Flags)] = [
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
        // transition freight, 1945-57 (estimates but for UP's)
        ("sf_blue", 0x1E2C5A, []), ("sf_frt_yellow", 0xF2B80A, []), ("roof_blk", 0x262626, []), ("nyc_dk", 0x3D4245, []),
        ("nyc_lt", 0xA3A6A4, []), ("prr_dgle", 0x1F2A23, []), ("prr_top", 0x2C3830, []), ("prr_car", 0x7A3A2A, []),
        ("sf_brown", 0x6A3427, []), ("sf_brown_dk", 0x582A20, []), ("sfrd", 0xEE9B2C, []), ("sfrd_dk", 0xCC8424, []),
        ("flat_deck", 0x7E6B54, []), ("lumber", 0xCBA978, []), ("lumber_lt", 0xD8BC90, []), ("nw_black", 0x212226, []),
        ("nw_ridge", 0x34363C, []), ("nw_smokebox", 0x4A4E54, []),
        // modern (estimates but for UP's published colours and CSX's blue)
        ("bnsf_orange", 0xE8641E, []), ("bnsf_yellow", 0xF4C20D, []), ("bnsf_black", 0x1C1C1C, []), ("truck_dk", 0x2A2A2A, []),
        ("up_yellow_m", 0xFFCC00, []), ("up_grey_m", 0x666666, []), ("csx_blue", 0x003462, []), ("csx_yellow", 0xF0B400, []),
        ("well", 0x4A4642, []), ("alum_car", 0xB9BAB4, []), ("rotary", 0xB5302A, []), ("coal_mod", 0x26231F, []),
        ("auto_white", 0xE6E6E2, []), ("auto_white_dk", 0xC4C4C0, []), ("auto_brown", 0x6B3A2A, []), ("auto_brown_dk", 0x5A3024, []),
        ("auto_roof", 0xA7A9AA, []), ("amtrak_silver", 0xBFC3C7, []), ("amtrak_roof", 0x8A8D90, []), ("amtrak_roof_lt", 0x9A9DA0, []),
        ("amtrak_stripe", 0x2B5C8A, []), ("amfleet", 0xC4C7CA, []), ("amfleet_roof", 0x8E9195, []), ("amtrak_red", 0xC8102E, []),
        ("alc_navy", 0x0E2A4F, []), ("alc_lblue", 0x3F7FC4, []), ("alc_white", 0xF4F4F4, []), ("alc_black", 0x111111, []),
        ("alc_roof", 0x4A4E54, []), ("p42_grey", 0xB9BDC1, []), ("p42_blue", 0x1F5A96, []),
        // road vehicles
        ("v40_maroon", 0x5A1E24, []), ("v50_cream", 0xEDE6D2, []), ("v50_turq", 0x4AA8A0, []), ("v_glass", 0x3A4650, []),
        ("v50_red", 0xB02A2A, []), ("v_white", 0xE8E8E6, []), ("v_black", 0x1C1C1E, []), ("v_grey", 0x6A6C70, []),
        ("v_silver", 0xA8AAAE, []), ("v_blue", 0x2A4A8A, []), ("v_red", 0xA82424, []),
        // buildings
        ("sp_wall", 0xD8B860, []), ("sp_trim", 0x6E4E30, []), ("sp_roof", 0x4E6A3A, .snowTop), ("brick", 0x8E4A3A, []),
        ("brick_dk", 0x74382C, []), ("slate", 0x4A5058, .snowTop), ("canopy", 0x6E6E6A, .snowTop),
        ("roof_green", 0x4E6A4A, .snowTop), ("roof_red", 0x8A4A3E, .snowTop), ("roof_black", 0x3A3A3C, .snowTop),
        ("roof_grey", 0x6E6E6A, .snowTop),
        ("wall_white", 0xE4E0D4, []), ("wall_cream", 0xE0D2A8, []), ("wall_yellow", 0xD8C080, []), ("wall_grey", 0xA8A49A, []),
        ("wall_blue", 0x8EA2B0, []), ("wall_brick", 0x9A5A44, []), ("door", 0x5A4232, []), ("house_win", 0x3C4650, .window),
        ("chimney", 0x7A4A3A, .snowTop), ("platform", 0xB0ACA4, .snowTop), ("platform_edge", 0xD8D4C8, .snowTop),
        ("wood_tank", 0x8A5A3A, []), ("wood_tank_dk", 0x6A4430, []), ("tank_roof", 0x4A3A2E, .snowTop), ("timber", 0x5A4632, []),
        ("conc_tower", 0xA8A49C, .snowTop), ("conc_dark", 0x8A8680, []), ("elevator", 0xC8C4B8, .snowTop), ("elevator_dk", 0xA8A498, []),
        ("freight_wall", 0x7A5A44, []), ("freight_door", 0x4A3828, []), ("dock", 0x6E5A44, .snowTop), ("tower_wall", 0x8E4A3A, []),
        ("silo", 0xD8D6D0, .snowTop), ("silo_dk", 0xB8B6B0, []), ("shelter_glass", 0x6A8090, []), ("shelter_roof", 0x5A5E64, .snowTop),
        ("roof_charcoal", 0x4A4A4C, .snowTop), ("roof_brown", 0x6A5A4C, .snowTop), ("roof_pale", 0xC8C8C4, .snowTop), ("wall_beige", 0xD8CCB4, []),
        // lineside
        ("post", 0x3A3634, []), ("post_white", 0xE8E4DC, []), ("pole", 0x5A4A3A, []), ("crossarm", 0x4A3C30, []),
        ("lamp", 0xF0E8D0, .lamp), ("sig_head", 0x1A1A1C, []), ("cl_head", 0x1A1A1C, []), ("concrete", 0xA8A49C, .snowTop), ("steel", 0x4E5258, []),
        ("steel_lt", 0x6A6E74, []), ("deck", 0x5A5650, .snowTop),
        // nature
        ("leaf", 0x4A6A24, .snowTop), ("leaf_lt", 0x6E8E3A, .snowTop), ("leaf_dk", 0x3E541A, .snowTop), ("trunk", 0x5A4232, []),
        ("conifer", 0x2A4628, .snowTop), ("conifer_dk", 0x22382A, .snowTop), ("twig", 0x3E3630, []), ("twig_lt", 0x948A80, []),
        ("hill", 0x557F33, .snowAll), ("hill_lt", 0x6A9440, .snowAll), ("hill_dk", 0x4A7230, .snowAll),
        ("tunnel", 0x121214, []), ("portal", 0x8A8884, .snowTop), ("bank", 0x6E8E3E, [.snowAll, .flat]), ("bank_dk", 0x58762F, [.snowAll, .flat]),
        // the seasons: new leaves, autumn's colours turning and full, dead and held leaves, conifers
        ("leaf_lime", 0x849236, .snowTop), ("aut_wine", 0x7A2820, .snowTop), ("aut_orange", 0xC8641E, .snowTop), ("aut_yellow", 0xD8A830, .snowTop),
        ("turn_wine", 0x624922, .snowTop), ("turn_orange", 0x896721, .snowTop), ("turn_yellow", 0x91892A, .snowTop),
        ("dead_leaf", 0x987A5A, .snowTop), ("held_leaf", 0xBCA480, .snowTop),
        ("conifer_a", 0x2A4426, .snowTop), ("conifer_w", 0x24382A, .snowTop), ("conifer_dk_w", 0x1E3024, .snowTop),
        ("hill_a", 0x7E8A44, .snowAll), ("hill_lt_a", 0x8E9A50, .snowAll), ("hill_dk_a", 0x6E783A, .snowAll),
        ("hill_w", 0x9A8C5E, .snowAll), ("hill_lt_w", 0xA89A68, .snowAll), ("hill_dk_w", 0x8A7C50, .snowAll),
        ("bank_a", 0x86924A, [.snowAll, .flat]), ("bank_dk_a", 0x6E783A, [.snowAll, .flat]),
        ("bank_w", 0xA09264, [.snowAll, .flat]), ("bank_dk_w", 0x857850, [.snowAll, .flat]),
    ]

    /// Double-stack boxes in plain colours, and each one's shaded side at 0.8.
    private static let containerMaterials: [(name: String, hex: UInt32, flags: Flags)] = containers.flatMap { name, hex in
        let dim: (UInt32) -> UInt32 = { UInt32(Double($0) * 0.8) }
        let dark: UInt32 = dim(hex >> 16 & 0xFF) << 16 | dim(hex >> 8 & 0xFF) << 8 | dim(hex & 0xFF)
        return [("cn_" + name, hex, Flags.snowTop), ("cn_" + name + "_dk", dark, Flags())]
    }

    /// Container colours, after the lines' own (all estimates); no names, marks or lettering.
    static let containers: [(String, UInt32)] = [("orange", 0xE8731E), ("yellow", 0xD9B23A), ("navy", 0x1F3A6B), ("blue", 0x2C5FA8),
                                                 ("magenta", 0xB5176F), ("green", 0x2F6E3F), ("maroon", 0x6E2430), ("white", 0xE8E8E4),
                                                 ("grey", 0xA9AEB2)]

    /// A material's index by name; 0 is empty.
    static let index: [String: UInt8] = Dictionary(uniqueKeysWithValues: table.enumerated().map { ($1.name, UInt8($0 + 1)) })
    /// Colours as floats, and flags, by index (0 is empty).
    static let rgb: [SIMD3<Float>] = [.zero] + table.map { colour($0.hex) }
    static let flags: [Flags] = [[]] + table.map(\.flags)
    /// The colour each material turns in snow, on the faces snow lies on.
    static let snowTone: [SIMD3<Float>] = [.zero] + table.map {
        let base = $0.name.hasSuffix("_a") || $0.name.hasSuffix("_w") ? String($0.name.dropLast(2)) : $0.name
        return colour(["hill": 0xE4EAF3, "hill_dk": 0xCCD6E6, "bank": 0xE4EAF3, "bank_dk": 0xD4DCEA][base] ?? 0xF4F6FA)
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
    /// How many vehicles at the front are its power (locomotives and tenders), which a train shortened to fit keeps.
    var power = 1

    init(key: String, name: String, era: RailEra, vehicles: [RailVehicle], cruise: Double, power: Int = 1) {
        (self.key, self.name, self.era, self.vehicles, self.cruise, self.power) = (key, name, era, vehicles, cruise, power)
        stops = !["bigboy", "gp9", "switcher", "up_f3", "sf_frt", "prr_gp9", "nw_a", "bnsf", "up_sd70", "csx"].contains(key)
    }
    /// Freight trains run through the station; passenger trains stop.
    var freight: Bool { !stops }
    /// Passenger trains stop at the station, and the New York Central's way freight at the freight house.
    var stops: Bool
    /// Nothing over 20 px: it takes the tightest curve, on a loop inside another.
    public var short: Bool { vehicles.allSatisfy { $0.length <= 20 } }
    /// Couplers and all, as the track sees it.
    var length: Double { Double(vehicles.reduce(0) { $0 + $1.length + 2 } - 2) }
    /// The tightest curve it looks right on: model-railway compression, half again the longest car and more.
    var minRadius: Double { max(32, 1.6 * Double(vehicles.map(\.length).max()!)) }

    /// Its caboose, last, if it has one.
    private var caboose: RailVehicle? { vehicles.last.flatMap { $0.name.lowercased().contains("caboose") ? $0 : nil } }
    /// The cars between its power and its caboose.
    var cars: Int { vehicles.count - power - (caboose == nil ? 0 : 1) }

    /// The same train with only its first `n` cars, keeping its power and caboose: a long train shortened to fit a
    /// layout. Its key carries the count, as "sf_frt#5".
    func shortened(to n: Int) -> Consist {
        var c = Consist(key: key.split(separator: "#")[0] + "#\(n)", name: name, era: era,
                        vehicles: Array(vehicles.prefix(power + n)) + (caboose.map { [$0] } ?? []), cruise: cruise, power: power)
        c.stops = stops
        return c
    }

    /// The most cars, five or more, it can keep and still be no longer than `length`; nil if it has no more than five
    /// cars to begin with or can't get that short.
    func cars(fitting length: Double) -> Int? {
        guard cars > 5 else { return nil }
        return stride(from: cars - 1, through: 5, by: -1).first { shortened(to: $0).length <= length }
    }
}

/// A layout's era: its trains, buildings, crossings and signals.
public enum RailEra: Int, CaseIterable, Sendable {
    case streamliners, steam, transition, modern
}

/// What an era puts by the line: ballast and ties; its street lamps' colour; what stands at the station; its level
/// crossing (a wigwag; flashers and short gates; today's gates with three lamps on the arm, over concrete panels);
/// its signals; whether a pole line runs along the road; its houses' walls and roofs; the buildings beside the line;
/// its share of conifers; and the scenery's dice.
struct EraLook {
    enum Station { case depot, brick, freight, shelter }
    enum Crossing { case wigwag, gates, modern }
    enum Signals { case semaphore, searchlight, colour }
    let ballast: UInt32, tie: UInt32, lamp: UInt32
    let station: Station, crossing: Crossing, signals: Signals, poles: Bool
    let walls: [String], roofs: [String], extras: [String], conifers: Double, dice: Int
    /// Concrete crossing panels and the joints between them, in place of planks.
    var panels: (UInt32, UInt32)? = nil

    static let walls = ["wall_white", "wall_cream", "wall_yellow", "wall_grey", "wall_blue", "wall_brick"]
    static let roofs = ["roof_green", "roof_red", "roof_black", "roof_grey"]
}

extension RailEra {
    var look: EraLook {
        switch self {
        // cinders, lightened to read, and creosoted ties; incandescent lamps
        case .steam: EraLook(ballast: 0x4E4844, tie: 0x3E3028, lamp: 0xFFAE54, station: .depot, crossing: .wigwag, signals: .semaphore,
                             poles: true, walls: EraLook.walls, roofs: EraLook.roofs, extras: [], conifers: 0.45, dice: 1)
        // granite and weathered ties; mercury lamps
        case .streamliners: EraLook(ballast: 0x8A8884, tie: 0x6A6058, lamp: 0xC8E4F0, station: .brick, crossing: .gates, signals: .searchlight,
                                    poles: true, walls: EraLook.walls, roofs: EraLook.roofs, extras: [], conifers: 0.35, dice: 2)
        // trap rock and creosoted ties; mercury lamps; a freight house and dock (every train is a freight)
        case .transition: EraLook(ballast: 0x55535A, tie: 0x3E3028, lamp: 0xC8E4F0, station: .freight, crossing: .gates, signals: .searchlight,
                                  poles: true, walls: EraLook.walls, roofs: EraLook.roofs, extras: ["coaling", "elevator", "tower"], conifers: 0.35, dice: 3)
        // granite and pale concrete ties; LED lamps; a low platform with a shelter; colour lights; no pole line
        case .modern: EraLook(ballast: 0x8A8884, tie: 0xB4B0A8, lamp: 0xFFD5A1, station: .shelter, crossing: .modern, signals: .colour,
                              poles: false, walls: ["wall_white", "wall_beige", "wall_grey", "wall_cream", "wall_blue"],
                              roofs: ["roof_charcoal", "roof_brown", "roof_pale", "roof_grey"], extras: ["silos"], conifers: 0.35, dice: 4,
                              panels: (0xB0ACA4, 0x77736C))
        }
    }
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
    // MARK: transition freight, 1945-57
    /// An F-unit cab, freight: a lower side, b middle, u upper, n nose sides, t nose top, R roof.
    static let fa = [
        trucks25,
        [r("a", 18) + "nnnnnn" + ".", r("a", 24) + "t", r("a", 24) + "h"],
        [r("b", 18) + "nnnnn" + "..", r("b", 23) + "t" + ".", r("b", 23) + "t" + "."],
        [r("u", 18) + "nccn" + "c" + "..", r("u", 22) + "c" + ".."],
        [r("R", 22) + "...", "RFFRFF" + r("R", 16) + "...", r("R", 11) + "ff" + r("R", 9) + "...", "RFFRFF" + r("R", 16) + "...", r("R", 22) + "..."],
    ]
    static let fb = [trucks25, [r("a", 25)], [r("b", 25)], [r("u", 25)],
                     [r("R", 25), "RFFRFF" + r("R", 19), r("R", 11) + "ff" + r("R", 12), "RFFRFF" + r("R", 19), r("R", 25)]]
    /// A GP9 run long hood forward, as the Pennsylvania ran them: the cab and short hood at the back.
    static let gp9Long = [
        ["...kkkkk" + r(".", 12) + "kkkkk..."], [r("b", 28)],
        ["...." + "bccb" + r(".", 20), r("b", 28), "h" + r("b", 26) + "h"],
        ["...." + "bccb" + r(".", 20), "...." + "bbbb" + r("R", 20), "...." + "bbbb" + r("R", 14) + "FFRFFR"],
        ["...." + "RRRR" + r(".", 20)],
    ]
    static let box24 = [
        [".kkk" + r(".", 16) + "kkk."], [r("R", 10) + "DDDD" + r("R", 10), r("R", 24)], [r("R", 10) + "DDDD" + r("R", 10), r("R", 24)],
        [r("R", 24)], [r("K", 24), r("K", 24), r("P", 24)],
    ]
    /// A bulkhead flat with lumber.
    static let flat = [[".kkk" + r(".", 14) + "kkk."], [r("e", 22)], ["e.llllll.llllll.llll.e"], ["e.LLLLLL.LLLLLL.LLLL.e"]]
    /// The N&W class A, 2-6-6-4: 121 ft 9 in with its tender, drawn 36 + 20 at about the Big Boy's squeeze (the split
    /// between engine and tender is an estimate). The cab over a four-wheel trailing truck, two sets of three drivers,
    /// one pair of leading wheels, the stack near the smokebox.
    static let classA = [
        ["..kkkk....ddrdddrdd..ddrdddrdd.kk.pp", "..." + r("k", 31) + "pp"],
        ["." + r("C", 7) + r("a", 24) + "xx..", "." + r("C", 7) + r("b", 24) + "xx.."],
        ["." + r("C", 7) + r(".", 28), "." + r("C", 7) + r("b", 24) + "xx..", "." + r("C", 7) + r("b", 24) + "xh.."],
        ["." + "CccCccC" + r(".", 28), "." + r("C", 7) + r("b", 24) + "xx..", "." + r("C", 7) + r("b", 24) + "xx.."],
        ["." + r("C", 7) + r(".", 28), "." + r("C", 7) + r("b", 24) + "x...", "." + r("C", 7) + r("B", 24) + "x..."],
        ["." + r("C", 7) + r(".", 28), "." + r("C", 7) + r(".", 28), "." + r("C", 7) + "...mmm......mm........mm...."],
    ]
    /// Twelve wheels, two three-axle trucks; the coal at the front, by the cab.
    static let tender12 = [
        ["..kkkkkk....kkkkkk.."], [r("b", 20)], [r("b", 20)], [r("b", 20)],
        [r("b", 20), r("b", 10) + "qqQqqqqQqq", "bbbHHbbbbb" + "qQqqqQqqqq", r("b", 10) + "qqqqQqqqqQ", r("b", 20)],
        [r(".", 20), r(".", 12) + "qqQqqq..", r(".", 12) + "qQqqqq.."],
    ]

    // MARK: modern
    /// A GE Evolution or EMD SD70ACe hood unit, compressed to 30: l sill, b lower hood side, B upper, m cab front, n nose top.
    static let hood30 = [
        ["..kkkkkk" + r(".", 14) + "kkkkkk.."], [r("l", 30)],
        [r(".", 21) + "bbbbbm" + "...", r("b", 26) + "m" + "bbb", r("b", 26) + "m" + "bbh"],
        [r(".", 21) + "BccccB" + "...", r("B", 26) + "m" + "nnn"],
        [r(".", 21) + "RRRRRR" + "...", r("R", 27) + "...", "FFRFFR" + r("R", 21) + "..."],
        [r(".", 30), r(".", 10) + "RRRRR" + r(".", 15)],
    ]
    /// BNSF's Heritage III: its black lower edge striped with yellow.
    static let hood30BNSF = [hood30[0], [r("yyll", 7) + "yy", r("l", 30)]] + Array(hood30[2...])
    /// A well car with a 40 ft box below and a 53 ft box on top.
    static let well = [
        ["kkk" + r("w", 22) + "kkk"], ["w" + r("A", 26) + "w"], ["." + r("AAa", 8) + "AA" + ".", "." + r("A", 26) + "."],
        [".." + r("CCc", 8) + "..", ".." + r("C", 24) + ".."], [".." + r("CCc", 8) + "..", ".." + r("C", 24) + ".."],
    ]
    /// An aluminium coal gondola, its rotary coupler end in red.
    static let gondola = [
        [".kkk" + r(".", 14) + "kkk."], ["r" + r("g", 21)], ["r" + r("g", 21), "r" + r("q", 20) + "g"],
        [r(".", 22), "..." + "qqqq" + "...." + "qqqq" + r(".", 7), "..." + "qQqq" + "...." + "qqQq" + r(".", 7)],
    ]
    static let autorack = [[".kkk" + r(".", 26) + "kkk."], [r("p", 34)], [r("pPp", 11) + "p", r("p", 34)], [r("pPp", 11) + "p", r("p", 34)],
                           [r("p", 34)], [r("r", 34)]]
    static let superliner = [
        ["..kkkk" + r(".", 20) + "kkkk.."], [r("s", 32)], ["s" + r("sws", 10) + "s", r("s", 32)], [r("B", 32), r("s", 32)], [r("s", 32)],
        ["s" + r("swws", 7) + "sss", r("s", 32)], [r("r", 32), r("r", 32), r("R", 32)],
    ]
    static let amfleet = [
        ["..kkkk" + r(".", 20) + "kkkk.."], [r("r", 32), r("s", 32)], ["B" + r("BwwB", 7) + "BBB", r("s", 32)], [r("s", 32)],
        [r("q", 32), r("q", 32), r("Q", 32)],
    ]
    /// A Siemens ALC-42 Charger.
    static let charger = [
        ["..kkkkkk" + r(".", 14) + "kkkkkk.."],
        [r("r", 29) + ".", r("r", 29) + "n", r("r", 29) + "h"],
        [r("N", 12) + "W" + r("L", 15) + "..", r("N", 12) + "W" + r("L", 16) + ".", r("N", 12) + "W" + r("L", 15) + "h" + "."],
        [r("N", 16) + "W" + r("N", 5) + "WKKKr" + "...", r("N", 22) + "KKKK" + "...."],
        [r("G", 25) + ".....", r("G", 25) + ".....", "GFFGFF" + r("G", 19) + "....."],
    ]
    /// A GE P42DC Genesis.
    static let genesis = [
        ["..kkkkk" + r(".", 15) + "kkkkk.."],
        [r("r", 28) + ".", r("e", 29), r("e", 28) + "h"],
        [r("e", 27) + "..", r("e", 28) + "."],
        ["BBBeBBBBeBBBBeBBBBeBBBB" + "cc" + "....", r("B", 25) + "...."],
        [r("B", 22) + ".......", r("B", 22) + ".......", "BFFBFFB" + r("B", 15) + "......."],
    ]
    /// A Ford "Big Job" stake-bed truck, 23 ft: the transition era's road vehicle.
    static let stakeTruck = [[r("a", 10)], ["bbbbbb..ga", "b....b..ga"], [r(".", 8) + "aa"]]

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

    static let redCab = RailVehicle("Red caboose", caboose, ["k": "truck", "y": "car_red", "w": "window", "R": "roof_black"])
    static let upF3a = RailVehicle("UP F3 A", fa, lv(truck, ["k": "truckgrey", "a": "up_yellow", "b": "up_yellow", "u": "up_yellow", "n": "up_yellow",
                                                         "t": "up_nose", "R": "up_grey", "F": "fan", "f": "fan_lt"]))
    static let upF3b = RailVehicle("UP F3 B", fb, lv(truck, ["k": "truckgrey", "a": "up_yellow", "b": "up_yellow", "u": "up_yellow", "R": "up_grey",
                                                         "F": "fan", "f": "fan_lt"]))
    /// Santa Fe freight: dark blue with a yellow nose and a yellow stripe low on the side (the one along the top is
    /// left out: a third of the side in yellow read as a wasp), and the blue roof of 1954 on, which reads from above as
    /// black did not.
    static let sfF7aFrt = RailVehicle("Santa Fe F7 A, freight", fa, lv(truck, ["a": "sf_frt_yellow", "b": "sf_blue", "u": "sf_blue", "n": "sf_frt_yellow",
                                                                           "t": "sf_frt_yellow", "R": "sf_blue", "F": "fan", "f": "fan_lt"]))
    static let sfF7bFrt = RailVehicle("Santa Fe F7 B, freight", fb, lv(truck, ["a": "sf_frt_yellow", "b": "sf_blue", "u": "sf_blue", "R": "sf_blue",
                                                                           "F": "fan", "f": "fan_lt"]))
    static let nycF7a = RailVehicle("NYC F7 A", fa, lv(truck, ["a": "nyc_dk", "b": "nyc_lt", "u": "nyc_dk", "n": "nyc_dk", "t": "nyc_dk", "R": "nyc_dk",
                                                           "F": "fan", "f": "fan_lt"]))
    static let prrGP9 = RailVehicle("PRR GP9", gp9Long, lv(truck, ["b": "prr_dgle", "R": "prr_top", "F": "fan"]))
    static let sfBox = RailVehicle("Santa Fe 50 ft boxcar", box24, ["k": "truck", "R": "sf_brown", "D": "sf_brown_dk", "K": "roof_blk", "P": "runboard"])
    static let sfrd = RailVehicle("SFRD reefer", reefer, ["k": "truck", "o": "sfrd", "d": "sfrd_dk", "A": "roof_blk", "h": "hatch"])
    static let flatcar = RailVehicle("Lumber flat", flat, ["k": "truck", "e": "flat_deck", "l": "lumber", "L": "lumber_lt"])
    static let n5c = RailVehicle("PRR N5c caboose", caboose, ["k": "truck", "y": "prr_car", "w": "window", "R": "roof_blk"])
    static let nwA = RailVehicle("N&W class A", classA, ["k": "bb_drivers", "d": "bb_drivers", "r": "bb_rod", "p": "black", "C": "nw_black",
                                                         "c": "cabglass", "a": "nw_ridge", "b": "nw_black", "B": "nw_ridge", "x": "nw_smokebox",
                                                         "h": "headlight", "m": "nw_ridge"], bogies: 0.7)
    static let nwTender = RailVehicle("N&W tender, 12 wheels", tender12, ["k": "truck", "b": "nw_black", "q": "coal", "Q": "coal_glint", "H": "nw_ridge"])
    static let bnsfES44 = RailVehicle("BNSF ES44AC", hood30BNSF, lv(truck, ["k": "truck_dk", "l": "bnsf_black", "y": "bnsf_yellow", "b": "bnsf_orange",
                                                                         "B": "bnsf_orange", "m": "bnsf_orange", "R": "bnsf_orange", "n": "bnsf_yellow",
                                                                         "F": "fan"]))
    static let upSD70 = RailVehicle("UP SD70ACe", hood30, lv(truck, ["k": "truckgrey", "l": "up_yellow_m", "b": "up_yellow_m", "B": "up_grey_m",
                                                                  "m": "up_yellow_m", "R": "up_grey_m", "n": "up_grey_m", "F": "fan"]))
    static let csxES44 = RailVehicle("CSX ES44AH", hood30, lv(truck, ["l": "csx_blue", "b": "csx_blue", "B": "csx_blue", "m": "csx_yellow",
                                                                   "R": "csx_blue", "n": "csx_yellow", "F": "fan"]))
    /// Each well car a different pair of boxes.
    static let wells = [("orange", "navy"), ("white", "maroon"), ("blue", "grey"), ("green", "orange"), ("magenta", "white"),
                        ("yellow", "blue"), ("grey", "green"), ("maroon", "yellow")].map { a, c in
        RailVehicle("Double-stack well car, \(a) and \(c)", well, ["k": "truck", "w": "well", "A": "cn_" + a, "a": "cn_" + a + "_dk",
                                                                 "C": "cn_" + c, "c": "cn_" + c + "_dk"])
    }
    static let gon = RailVehicle("Aluminium coal gondola", gondola, ["k": "truck", "g": "alum_car", "r": "rotary", "q": "coal_mod", "Q": "coal_glint"])
    static let autoW = RailVehicle("Autorack", autorack, ["k": "truck", "p": "auto_white", "P": "auto_white_dk", "r": "auto_roof"])
    static let autoB = RailVehicle("Autorack, brown", autorack, ["k": "truck", "p": "auto_brown", "P": "auto_brown_dk", "r": "auto_roof"])
    static let superlinerCar = RailVehicle("Superliner", superliner, lv(truck, ["s": "amtrak_silver", "B": "amtrak_stripe", "r": "amtrak_roof",
                                                                             "R": "amtrak_roof_lt"]))
    static let amfleetCar = RailVehicle("Amfleet I", amfleet, lv(truck, ["s": "amfleet", "B": "amtrak_stripe", "r": "amtrak_red", "q": "amfleet_roof",
                                                                      "Q": "amtrak_roof_lt"]))
    static let alc42 = RailVehicle("Amtrak ALC-42", charger, lv(truck, ["r": "amtrak_red", "n": "alc_navy", "N": "alc_navy", "L": "alc_lblue",
                                                                     "W": "alc_white", "K": "alc_black", "G": "alc_roof", "F": "fan"]))
    static let p42 = RailVehicle("Amtrak P42DC", genesis, lv(truck, ["r": "amtrak_red", "e": "p42_grey", "B": "p42_blue", "F": "fan"]))
    static let fordTruck = RailVehicle("Ford stake-bed truck", stakeTruck, ["a": "v50_red", "b": "flat_deck", "g": "v_glass"], width: 3, bogies: 0.6)

    /// The road vehicle, by era and seed: a 1940s or 1950s car, a stake-bed truck, or today's cars, mostly white.
    static func roadVehicle(_ era: RailEra, seed: Int) -> RailVehicle {
        let paint: [(String, String)]
        switch era {
        case .steam: paint = [("v40_maroon", "v40_maroon")]
        case .streamliners: paint = [("v50_turq", "v50_cream")]
        case .transition: return fordTruck
        case .modern: paint = ["v_white", "v_white", "v_white", "v_black", "v_grey", "v_silver", "v_blue", "v_red"].map { ($0, $0) }
        }
        let (body, roof) = paint[Int(hsh(seed, 77) * Double(paint.count))]
        return RailVehicle("road car, \(body)", car, ["a": body, "g": "v_glass", "w": "v_glass", "r": roof], width: 3, bogies: 0.6)
    }

    /// Every train, by key.
    public static let trains: [String: Consist] = Dictionary(uniqueKeysWithValues: [
        Consist(key: "santafe", name: "Santa Fe F7 warbonnet with Hi-Levels", era: .streamliners,
                vehicles: [sfF7a, sfF7b, sfHiLevel, sfHiLevel, sfHiLevel], cruise: 18),
        Consist(key: "up", name: "Union Pacific E9 with an Astra Dome", era: .streamliners, vehicles: [upE9, upCoach, upDome, upCoach], cruise: 17),
        Consist(key: "gn", name: "Great Northern F7 streamliner", era: .streamliners,
                vehicles: [gnF7aCar, gnF7bCar, gnCoachCar, gnDomeCar, gnCoachCar], cruise: 16),
        Consist(key: "bigboy", name: "Union Pacific Big Boy, mixed freight", era: .steam,
                vehicles: [bb, bbTender, box, pfe, hop, hop, tank, box, pfe, cab], cruise: 13, power: 2),
        Consist(key: "gs4", name: "Southern Pacific GS-4 Daylight", era: .steam, vehicles: [spGS4, spTender, spCar, spCar, spCar], cruise: 17),
        Consist(key: "hiawatha", name: "Milwaukee Road Hiawatha", era: .steam, vehicles: [mwHudson, mwTender, mwCar, mwCar, mwCar], cruise: 18),
        // short trains, for a tight inner loop
        Consist(key: "rdc", name: "Budd RDC pair", era: .streamliners, vehicles: [rdcCar, rdcCar], cruise: 15),
        Consist(key: "gp9", name: "Union Pacific GP9 local", era: .streamliners, vehicles: [upGP9, shortBox, hop, shortBox], cruise: 12),
        Consist(key: "switcher", name: "0-6-0 switcher with short cars", era: .steam, vehicles: [sw, swTender, shortBox, hop], cruise: 11),
        // transition freight, 1945-57: freights all but the New York Central's way freight, which stops at the freight
        // house as a passenger train does at a station; speeds differ a little, so a train sharing a loop sometimes
        // closes up on the one ahead and waits at a signal
        Consist(key: "up_f3", name: "Union Pacific F3 with PFE reefers", era: .transition,
                vehicles: [upF3a, upF3b] + Array(repeating: pfe, count: 7) + [cab], cruise: 13, power: 2),
        Consist(key: "sf_frt", name: "Santa Fe F7 freight", era: .transition,
                vehicles: [sfF7aFrt, sfF7bFrt, sfBox, sfrd, sfBox, sfrd, sfBox, sfrd, sfBox, redCab], cruise: 15, power: 2),
        Consist(key: "prr_gp9", name: "Pennsylvania GP9 with coal hoppers", era: .transition,
                vehicles: [prrGP9] + Array(repeating: hop, count: 7) + [n5c], cruise: 11),
        Consist(key: "nyc_f7", name: "New York Central F7 way freight", era: .transition,
                vehicles: [nycF7a, box, tank, flatcar, box, tank, flatcar, box, redCab], cruise: 14),
        Consist(key: "nw_a", name: "Norfolk and Western class A, hopper drag", era: .transition,
                vehicles: [nwA, nwTender] + Array(repeating: hop, count: 9) + [redCab], cruise: 12, power: 2),
        // modern
        Consist(key: "bnsf", name: "BNSF ES44AC Heritage III, double-stacks", era: .modern, vehicles: [bnsfES44] + wells, cruise: 15),
        Consist(key: "up_sd70", name: "Union Pacific SD70ACe, coal gondolas", era: .modern, vehicles: [upSD70] + Array(repeating: gon, count: 8), cruise: 12),
        Consist(key: "csx", name: "CSX ES44AH, autoracks and tank cars", era: .modern,
                vehicles: [csxES44, autoW, autoB, autoW, tank, tank, autoB, tank, tank], cruise: 14),
        Consist(key: "amtrak_alc", name: "Amtrak ALC-42 Phase VII, Superliners", era: .modern,
                vehicles: [alc42] + Array(repeating: superlinerCar, count: 4), cruise: 17),
        Consist(key: "amtrak_p42", name: "Amtrak P42 Phase V, Amfleet I", era: .modern, vehicles: [p42] + Array(repeating: amfleetCar, count: 5), cruise: 18),
    ].map { ($0.key, $0) })

    /// A train by key, shortened if its key says so ("sf_frt#5").
    static func consist(_ key: String) -> Consist {
        let parts = key.split(separator: "#"), base = trains[String(parts[0])]!
        return parts.count > 1 ? base.shortened(to: Int(parts[1])!) : base
    }

    /// Each era's trains, in the order a layout tries them: the main line's, or the short ones for an inner loop.
    public static func trains(of era: RailEra, short: Bool = false) -> [Consist] {
        trains.values.filter { $0.era == era && $0.short == short }.sorted { $0.key < $1.key }
    }
}
