import Foundation

/// The international trains: Britain in the age of steam and of InterCity, Germany and the Alps, European high
/// speed and the Shinkansen. Written out from the mock-up's art.py (docs/pixel-railway.md says where each colour
/// comes from), its slices expanded to every row; no heralds, numbers or lettering.
extension RailArt {
    /// Their materials, and the lineside's.
    static let worldMaterials: [(name: String, hex: UInt32, flags: Flags)] = [
        ("v40_black", 0x1E1E22, []),
        ("v40_navy", 0x22304A, []),
        ("v40_green", 0x2E4A36, []),
        ("v40_tan", 0xA08A64, []),
        ("v50_coral", 0xE07A60, []),
        ("v50_yellow", 0xE8C850, []),
        ("v50_blue", 0x8AB0D0, []),
        ("tail", 0xC81E1E, []),
        ("stone", 0xB8B2A6, []),
        ("twig_mass", 0x6A5E54, []),
        ("rock", 0x8A8478, [.snowTop]),
        ("lner_green", 0x5A9A3C, []),
        ("lner_green_lt", 0x68A848, []),
        ("garter_blue", 0x1E3F7A, []),
        ("garter_blue_lt", 0x2A4C88, []),
        ("gwr_green", 0x2F6B3A, []),
        ("gwr_green_lt", 0x3A7846, []),
        ("brass", 0xD4AF37, []),
        ("copper", 0xB87333, []),
        ("lms_crimson", 0x8B1A32, []),
        ("lms_crimson_lt", 0x9A2A40, []),
        ("lms_gold", 0xD4A93C, []),
        ("red_wheel", 0xA8261E, []),
        ("loco_black", 0x1C1C1C, []),
        ("loco_ridge", 0x34363C, []),
        ("teak", 0x8B5A2B, []),
        ("teak_roof", 0xD6D2C8, [.snowTop]),
        ("choc", 0x4E2B1E, []),
        ("gwr_cream", 0xE9DCC0, []),
        ("coach_roof_lt", 0xB4B4AE, [.snowTop]),
        ("coach_roof_lt2", 0xC2C2BC, [.snowTop]),
        ("mineral", 0x8E8F88, []),
        ("bauxite", 0x774430, []),
        ("coal_uk", 0x262626, []),
        ("rail_blue", 0x1F4B61, []),
        ("warn_yellow", 0xF2C200, []),
        ("ic_grey", 0xB4B6B0, []),
        ("ic_roof", 0x4A4C4E, []),
        ("ic_roof_lt", 0x5A5C5E, []),
        ("brunswick", 0x1E3E2E, []),
        ("lime", 0x7FA35A, []),
        ("deltic_roof", 0x6E726E, []),
        ("deltic_cream", 0xE8E0C8, []),
        ("purpurrot", 0x701F29, []),
        ("tee_beige", 0xD1BC8A, []),
        ("tee_roof", 0x8F999F, []),
        ("tee_roof_lt", 0x9DA6AC, []),
        ("db_frame", 0x3A3C3E, []),
        ("v200_roof", 0xA5A5A5, []),
        ("chrom_green", 0x354733, []),
        ("dzug_roof", 0x8A8D8A, []),
        ("dzug_roof_lt", 0x989B98, []),
        ("db_black", 0x0A0A0A, []),
        ("db_ridge", 0x242628, []),
        ("db_red", 0xAB2524, []),
        ("croc_green", 0x2F4F3A, []),
        ("croc_roof", 0x7A7D7A, []),
        ("wagon_brown", 0x673831, []),
        ("wagon_brown_dk", 0x56302A, []),
        ("wagon_roof", 0x8A8C88, []),
        ("tgv_orange", 0xE8641B, []),
        ("tgv_grey", 0x8E9399, []),
        ("tgv_white", 0xF2F2F2, []),
        ("tgv_roof", 0xA0A4A8, []),
        ("ice_white", 0xCBD0CC, []),
        ("ice_roof_lt", 0xD8DCD8, []),
        ("orientrot", 0xAC323B, []),
        ("pastell", 0xA38995, []),
        ("ice_band", 0x1E1F21, []),
        ("vk_red", 0xC1121C, []),
        ("sbb_red", 0xD01F26, []),
        ("ew4_grey", 0xB8BCBC, []),
        ("ew4_dark", 0x4A4E52, []),
        ("loco_roof", 0x6E7276, []),
        ("flat_steel", 0x4A4C4E, []),
        ("jnr_cream", 0xECE0D1, []),
        ("jnr_blue", 0x003F6C, []),
        ("shin_roof", 0xA9ADB0, []),
        ("shin_roof_lt", 0xB8BCBE, []),
        ("n700_white", 0xF4F5F2, []),
        ("n700_roof", 0xC8CACC, []),
        ("tokiwa", 0x0B7A5C, []),
        ("hiun", 0xF2F2EE, []),
        ("tsutsuji", 0xE4467B, []),
        ("e6_crimson", 0xB5122B, []),
        ("e6_silver", 0xA9ADB0, []),
        ("ef210_blue", 0x1E4E9C, []),
        ("jrf_red", 0x8C2A3C, [.snowTop]),
        ("koki", 0x5A5A5C, []),
        ("panto", 0xB8BCC0, []),
        ("uk_cream", 0xE4DCC0, []),
        ("uk_grey", 0x8A8C88, []),
        ("v70_brown", 0x6A4A2E, []),
        ("v70_orange", 0xD07A2A, []),
        ("v70_beige", 0xC8B48A, []),
        ("v60_blue", 0x6A8AB0, []),
        ("v60_beige", 0xD8C8A0, []),
        ("v60_red", 0xA83A2A, []),
        ("kei_pearl", 0xECEAE4, []),
        ("kei_silver", 0xB0B2B4, []),
        ("kei_truck", 0x9A9A96, []),
        ("gate_red", 0xC8202A, []),
        ("stone_lt", 0xD8C8A0, [.snowTop]),
        ("stone_dk", 0x8A6E48, []),
        ("clay_tile", 0xA0503A, [.snowTop]),
        ("thatch", 0xA88A54, [.snowTop]),
        ("cotswold", 0xB0A07E, []),
        ("ibushi", 0x6A7078, [.snowTop]),
        ("sekishu", 0x8A3E2A, [.snowTop]),
        ("hedge", 0x3E5228, [.snowTop]),
        ("hedge_dk", 0x324420, [.snowTop]),
        ("hedge_w", 0x4A4A30, [.snowTop]),
        ("jp_yellow", 0xF2C400, []),
        ("jp_black", 0x1A1A1A, []),
        ("road_top", 0x57575A, [.snowTop, .flat]),
        ("box_glass", 0x3C4650, [.window]),
        ("mast", 0x5E6266, []),
    ]

    static let lnerA3 = RailVehicle("LNER A3", [
            [".kk.ddrddrddd.kk.kk.", ".kkkkkkkkkkkkkkkkkpp", ".kkkkkkkkkkkkkkkkkpp", ".kkkkkkkkkkkkkkkkkpp", ".kk.ddrddrddd.kk.kk."],
            [".CCCCaaaaaaaaaaaaaxx", ".CCCCbbbbbbbbbbbbbxx", ".CCCCbbbbbbbbbbbbbxx", ".CCCCbbbbbbbbbbbbbxx", ".CCCCaaaaaaaaaaaaaxx"],
            [".CCCC...............", ".CCCCbbbbbbbbbbbbbxx", ".CCCCbbbbbbbbbbbbbxh", ".CCCCbbbbbbbbbbbbbxx", ".CCCC..............."],
            [".CccC...............", ".CCCCbbbbbbbbbbbbbx.", ".CCCCBBBBBBBBBBBBBx.", ".CCCCbbbbbbbbbbbbbx.", ".CccC..............."],
            [".RRRR...............", ".RRRR...............", ".RRRR....m.....u....", ".RRRR...............", ".RRRR..............."]],
        ["B": "lner_green_lt", "C": "lner_green", "R": "loco_black", "a": "loco_black", "b": "lner_green", "c": "cabglass", "d": "lner_green", "h": "headlight", "k": "bb_drivers", "m": "lner_green", "p": "black", "r": "bb_rod", "u": "loco_black", "x": "loco_black"], bogies: 0.7)
    static let a3Tender = RailVehicle("A3 tender", [
            ["kk.kk..kk.kk", "kk.kk..kk.kk", "kk.kk..kk.kk", "kk.kk..kk.kk", "kk.kk..kk.kk"],
            ["bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb"],
            ["bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb"],
            ["bbbbbbbbbbbb", "bbbqqqqqqqqq", "bbbqqqqqqqqq", "bbbqqqqqqqqq", "bbbbbbbbbbbb"],
            ["bbbbbbbbbbbb", "bbbbbqQqqbbb", "bbbbbqQqqbbb", "bbbbbqQqqbbb", "bbbbbbbbbbbb"]],
        ["Q": "coal_glint", "b": "lner_green", "k": "truck", "q": "coal_uk"])
    static let lnerTeakCoach = RailVehicle("LNER teak coach", [
            ["..kkk.............kkk..", "..kkk.............kkk..", "..kkk.............kkk..", "..kkk.............kkk..", "..kkk.............kkk.."],
            ["aaaaaaaaaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaaaaaaaaa"],
            ["eewweewweewweewweewweee", "eeeeeeeeeeeeeeeeeeeeeee", "eeeeeeeeeeeeeeeeeeeeeee", "eeeeeeeeeeeeeeeeeeeeeee", "eewweewweewweewweewweee"],
            ["fffffffffffffffffffffff", "fffffffffffffffffffffff", "fffffffffffffffffffffff", "fffffffffffffffffffffff", "fffffffffffffffffffffff"],
            ["RRRRRRRRRRRRRRRRRRRRRRR", "RRRRRRRRRRRRRRRRRRRRRRR", "QQQQQQQQQQQQQQQQQQQQQQQ", "RRRRRRRRRRRRRRRRRRRRRRR", "RRRRRRRRRRRRRRRRRRRRRRR"]],
        ["Q": "coach_roof_lt2", "R": "teak_roof", "a": "teak", "c": "cabglass", "e": "teak", "f": "teak", "g": "truckgrey", "h": "headlight", "k": "truck", "w": "window"])
    static let lnerA4 = RailVehicle("LNER A4", [
            [".kkkrrr.rrr.rrr.kk.kk", ".kkkkkkkkkkkkkkkkkk..", ".kkkkkkkkkkkkkkkkkk..", ".kkkkkkkkkkkkkkkkkk..", ".kkkrrr.rrr.rrr.kk.kk"],
            [".CCCCvvvvvvvvvvvvv...", ".CCCCvvvvvvvvvvvvvvv.", ".CCCCvvvvvvvvvvvvvvvv", ".CCCCvvvvvvvvvvvvvvv.", ".CCCCvvvvvvvvvvvvv..."],
            [".CCCCbbbbbbbbbbbb....", ".CCCCbbbbbbbbbbbbbb..", ".CCCCbbbbbbbbbbbbbbbh", ".CCCCbbbbbbbbbbbbbb..", ".CCCCbbbbbbbbbbbb...."],
            [".CccC................", ".CCCCbbbbbbbbbbbbb...", ".CCCCbbbbbbbbbbbbbb..", ".CCCCbbbbbbbbbbbbb...", ".CccC................"],
            [".RRRR................", ".RRRR................", ".RRRRBBBBBBBBBBBBK...", ".RRRR................", ".RRRR................"]],
        ["B": "garter_blue_lt", "C": "garter_blue", "K": "loco_black", "R": "garter_blue", "b": "garter_blue", "c": "cabglass", "h": "headlight", "k": "bb_drivers", "p": "black", "r": "bb_rod", "v": "garter_blue", "x": "loco_black"], bogies: 0.7)
    static let a4Tender = RailVehicle("A4 tender", [
            ["kk.kk..kk.kk", "kk.kk..kk.kk", "kk.kk..kk.kk", "kk.kk..kk.kk", "kk.kk..kk.kk"],
            ["bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb"],
            ["bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb"],
            ["bbbbbbbbbbbb", "bbbqqqqqqqqq", "bbbqqqqqqqqq", "bbbqqqqqqqqq", "bbbbbbbbbbbb"],
            ["bbbbbbbbbbbb", "bbbbbqQqqbbb", "bbbbbqQqqbbb", "bbbbbqQqqbbb", "bbbbbbbbbbbb"]],
        ["Q": "coal_glint", "b": "garter_blue", "k": "truck", "q": "coal_uk"])
    static let gwrCastle = RailVehicle("GWR Castle", [
            ["..ddrddrddd.kk.kk.", ".kkkkkkkkkkkkkkkpp", ".kkkkkkkkkkkkkkkpp", ".kkkkkkkkkkkkkkkpp", "..ddrddrddd.kk.kk."],
            [".CCCaaaaaaaaaaaaxx", ".CCCbbbbbbbbbbbbxx", ".CCCbbbbbbbbbbbbxx", ".CCCbbbbbbbbbbbbxx", ".CCCaaaaaaaaaaaaxx"],
            [".CCC..............", ".CCCbbbbbbbbbbbbxx", ".CCCbbbbbbbbbbbbxh", ".CCCbbbbbbbbbbbbxx", ".CCC.............."],
            [".CcC..............", ".CCCbbbbbbbbbbbbx.", ".CCCBBBBBBBBBBBBx.", ".CCCbbbbbbbbbbbbx.", ".CcC.............."],
            [".RRR..............", ".RRR..............", ".RRR....g......u..", ".RRR..............", ".RRR.............."]],
        ["B": "gwr_green_lt", "C": "gwr_green", "R": "loco_black", "a": "loco_black", "b": "gwr_green", "c": "cabglass", "d": "gwr_green", "g": "brass", "h": "headlight", "k": "bb_drivers", "p": "black", "r": "bb_rod", "u": "copper", "x": "loco_black"], bogies: 0.7)
    static let castleTender = RailVehicle("Castle tender", [
            [".kk..kk..kk.", ".kk..kk..kk.", ".kk..kk..kk.", ".kk..kk..kk.", ".kk..kk..kk."],
            ["bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb"],
            ["bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb"],
            ["bbbbbbbbbbbb", "bbbqqqqqqqqq", "bbbqqqqqqqqq", "bbbqqqqqqqqq", "bbbbbbbbbbbb"],
            ["............", ".....qQqq...", ".....qQqq...", ".....qQqq...", "............"]],
        ["Q": "coal_glint", "b": "gwr_green", "k": "truck", "q": "coal_uk"])
    static let gwrChocolateAndCreamCoach = RailVehicle("GWR chocolate-and-cream coach", [
            ["..kkk.............kkk..", "..kkk.............kkk..", "..kkk.............kkk..", "..kkk.............kkk..", "..kkk.............kkk.."],
            ["aaaaaaaaaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaaaaaaaaa"],
            ["eewweewweewweewweewweee", "eeeeeeeeeeeeeeeeeeeeeee", "eeeeeeeeeeeeeeeeeeeeeee", "eeeeeeeeeeeeeeeeeeeeeee", "eewweewweewweewweewweee"],
            ["fffffffffffffffffffffff", "fffffffffffffffffffffff", "fffffffffffffffffffffff", "fffffffffffffffffffffff", "fffffffffffffffffffffff"],
            ["RRRRRRRRRRRRRRRRRRRRRRR", "RRRRRRRRRRRRRRRRRRRRRRR", "QQQQQQQQQQQQQQQQQQQQQQQ", "RRRRRRRRRRRRRRRRRRRRRRR", "RRRRRRRRRRRRRRRRRRRRRRR"]],
        ["Q": "coach_roof_lt2", "R": "coach_roof_lt", "a": "choc", "c": "cabglass", "e": "gwr_cream", "f": "gwr_cream", "g": "truckgrey", "h": "headlight", "k": "truck", "w": "window"])
    static let lmsPrincessCoronationStreamlined = RailVehicle("LMS Princess Coronation, streamlined", [
            [".kkkddrddrddd...kk.kk.", ".kkkkkkkkkkkkkkkkkkk..", ".kkkkkkkkkkkkkkkkkkk..", ".kkkkkkkkkkkkkkkkkkk..", ".kkkddrddrddd...kk.kk."],
            [".CCCCgggggggggggggg...", ".CCCCbbbbbbbbbbbbbbb..", ".CCCCgggggggggggggggg.", ".CCCCbbbbbbbbbbbbbbb..", ".CCCCgggggggggggggg..."],
            [".CCCCbbbbbbbbbbbbbb...", ".CCCCbbbbbbbbbbbbbbbb.", ".CCCCbbbbbbbbbbbbbbbbh", ".CCCCbbbbbbbbbbbbbbbb.", ".CCCCbbbbbbbbbbbbbb..."],
            [".CccC.................", ".CCCCbbbbbbbbbbbbbbb..", ".CCCCbbbbbbbbbbbbbbb..", ".CCCCbbbbbbbbbbbbbbb..", ".CccC................."],
            [".RRRR.................", ".RRRR.................", ".RRRRBBBBBBBBBBBBB....", ".RRRR.................", ".RRRR................."]],
        ["B": "lms_crimson_lt", "C": "lms_crimson", "R": "lms_crimson", "b": "lms_crimson", "c": "cabglass", "d": "lms_crimson", "g": "lms_gold", "h": "headlight", "k": "bb_drivers", "p": "black", "r": "bb_rod", "x": "loco_black"], bogies: 0.7)
    static let coronationTender = RailVehicle("Coronation tender", [
            ["kk.kk..kk.kk", "kk.kk..kk.kk", "kk.kk..kk.kk", "kk.kk..kk.kk", "kk.kk..kk.kk"],
            ["bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb"],
            ["bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb"],
            ["bbbbbbbbbbbb", "bbbqqqqqqqqq", "bbbqqqqqqqqq", "bbbqqqqqqqqq", "bbbbbbbbbbbb"],
            ["bbbbbbbbbbbb", "bbbbbqQqqbbb", "bbbbbqQqqbbb", "bbbbbqQqqbbb", "bbbbbbbbbbbb"]],
        ["Q": "coal_glint", "b": "lms_crimson", "k": "truck", "q": "coal_uk"])
    static let lmsCrimsonCoach = RailVehicle("LMS crimson coach", [
            ["..kkk.............kkk..", "..kkk.............kkk..", "..kkk.............kkk..", "..kkk.............kkk..", "..kkk.............kkk.."],
            ["aaaaaaaaaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaaaaaaaaa"],
            ["eewweewweewweewweewweee", "eeeeeeeeeeeeeeeeeeeeeee", "eeeeeeeeeeeeeeeeeeeeeee", "eeeeeeeeeeeeeeeeeeeeeee", "eewweewweewweewweewweee"],
            ["fffffffffffffffffffffff", "fffffffffffffffffffffff", "fffffffffffffffffffffff", "fffffffffffffffffffffff", "fffffffffffffffffffffff"],
            ["RRRRRRRRRRRRRRRRRRRRRRR", "RRRRRRRRRRRRRRRRRRRRRRR", "QQQQQQQQQQQQQQQQQQQQQQQ", "RRRRRRRRRRRRRRRRRRRRRRR", "RRRRRRRRRRRRRRRRRRRRRRR"]],
        ["Q": "coach_roof_lt2", "R": "coach_roof_lt", "a": "lms_crimson", "c": "cabglass", "e": "lms_crimson", "f": "lms_gold", "g": "truckgrey", "h": "headlight", "k": "truck", "w": "window"])
    static let lms8F = RailVehicle("LMS 8F", [
            [".ddrddrddrdd.kk.p", ".kkkkkkkkkkkkkkpp", ".kkkkkkkkkkkkkkpp", ".kkkkkkkkkkkkkkpp", ".ddrddrddrdd.kk.p"],
            [".CCCaaaaaaaaaaaxx", ".CCCbbbbbbbbbbbxx", ".CCCbbbbbbbbbbbxx", ".CCCbbbbbbbbbbbxx", ".CCCaaaaaaaaaaaxx"],
            [".CCC.............", ".CCCbbbbbbbbbbbxx", ".CCCbbbbbbbbbbbxh", ".CCCbbbbbbbbbbbxx", ".CCC............."],
            [".CcC.............", ".CCCbbbbbbbbbbbx.", ".CCCBBBBBBBBBBBx.", ".CCCbbbbbbbbbbbx.", ".CcC............."],
            [".RRR.............", ".RRR.............", ".RRR....m.....u..", ".RRR.............", ".RRR............."]],
        ["B": "loco_ridge", "C": "loco_black", "R": "loco_black", "a": "loco_black", "b": "loco_black", "c": "cabglass", "d": "bb_drivers", "h": "headlight", "k": "bb_drivers", "m": "loco_black", "p": "black", "r": "bb_rod", "u": "loco_black", "x": "loco_black"], bogies: 0.7)
    static let v8fTender = RailVehicle("8F tender", [
            [".kk..kk..kk.", ".kk..kk..kk.", ".kk..kk..kk.", ".kk..kk..kk.", ".kk..kk..kk."],
            ["bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb"],
            ["bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb", "bbbbbbbbbbbb"],
            ["bbbbbbbbbbbb", "bbbqqqqqqqqq", "bbbqqqqqqqqq", "bbbqqqqqqqqq", "bbbbbbbbbbbb"],
            ["............", ".....qQqq...", ".....qQqq...", ".....qQqq...", "............"]],
        ["Q": "coal_glint", "b": "loco_black", "k": "truck", "q": "coal_uk"])
    static let v16TMineralWagon = RailVehicle("16 t mineral wagon", [
            [".k...k.", ".k...k.", ".k...k.", ".k...k.", ".k...k."],
            ["MMMMMMM", "MMMMMMM", "MMMMMMM", "MMMMMMM", "MMMMMMM"],
            ["MMMMMMM", "MqqqqqM", "MqqqqqM", "MqqqqqM", "MMMMMMM"],
            [".......", "..qQq..", "..qQq..", "..qQq..", "......."]],
        ["M": "mineral", "Q": "coal_glint", "k": "truck", "q": "coal_uk"], bogies: 0.6)
    static let brBrakeVan = RailVehicle("BR brake van", [
            [".kk....kk.", ".kk....kk.", ".kk....kk.", ".kk....kk.", ".kk....kk."],
            ["BBBBBBBBBB", "BBBBBBBBBB", "BBBBBBBBBB", "BBBBBBBBBB", "BBBBBBBBBB"],
            ["B.BBwwBB.B", "..BBBBBB..", "..BBBBBB..", "..BBBBBB..", "B.BBwwBB.B"],
            [".RRRRRRRR.", ".RRRRRRRR.", ".RRRRRRRR.", ".RRRRRRRR.", ".RRRRRRRR."]],
        ["B": "bauxite", "R": "roof_black", "k": "truck", "w": "window"], bogies: 0.6)
    static let hstPowerCar = RailVehicle("HST power car", [
            ["..kkkk.........kkkk...", "..kkkk.........kkkk...", "..kkkk.........kkkk...", "..kkkk.........kkkk...", "..kkkk.........kkkk..."],
            ["yyyyyyyyyyyyyyyyyyyyy.", "yyyyyyyyyyyyyyyyyyyyyy", "yyyyyyyyyyyyyyyyyyyyyy", "yyyyyyyyyyyyyyyyyyyyyy", "yyyyyyyyyyyyyyyyyyyyy."],
            ["bbbbbbbbbbbbbbyyyyyy..", "bbbbbbbbbbbbbbyyyyyyy.", "bbbbbbbbbbbbbbyyyyyyyh", "bbbbbbbbbbbbbbyyyyyyy.", "bbbbbbbbbbbbbbyyyyyy.."],
            ["yyyyyyyyyyyyyyyycc....", "yyyyyyyyyyyyyyyycc....", "yyyyyyyyyyyyyyyycc....", "yyyyyyyyyyyyyyyycc....", "yyyyyyyyyyyyyyyycc...."],
            ["RRRRRRRRRRRRRRRR......", "RRRRRRRRRRRRRRRR......", "RRRRRRRRRRRRRRRR......", "RRRRRRRRRRRRRRRR......", "RRRRRRRRRRRRRRRR......"]],
        ["R": "ic_roof", "b": "rail_blue", "c": "cabglass", "g": "truckgrey", "h": "headlight", "k": "truck", "w": "window", "y": "warn_yellow"])
    static let mark3Coach = RailVehicle("Mark 3 coach", [
            ["..kkkk.................kkkk..", "..kkkk.................kkkk..", "..kkkk.................kkkk..", "..kkkk.................kkkk..", "..kkkk.................kkkk.."],
            ["bbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbb"],
            ["eewweewweewweewweewweewweewwe", "eeeeeeeeeeeeeeeeeeeeeeeeeeeee", "eeeeeeeeeeeeeeeeeeeeeeeeeeeee", "eeeeeeeeeeeeeeeeeeeeeeeeeeeee", "eewweewweewweewweewweewweewwe"],
            ["eeeeeeeeeeeeeeeeeeeeeeeeeeeee", "eeeeeeeeeeeeeeeeeeeeeeeeeeeee", "eeeeeeeeeeeeeeeeeeeeeeeeeeeee", "eeeeeeeeeeeeeeeeeeeeeeeeeeeee", "eeeeeeeeeeeeeeeeeeeeeeeeeeeee"],
            ["RRRRRRRRRRRRRRRRRRRRRRRRRRRRR", "RRRRRRRRRRRRRRRRRRRRRRRRRRRRR", "QQQQQQQQQQQQQQQQQQQQQQQQQQQQQ", "RRRRRRRRRRRRRRRRRRRRRRRRRRRRR", "RRRRRRRRRRRRRRRRRRRRRRRRRRRRR"]],
        ["Q": "ic_roof_lt", "R": "ic_roof", "b": "rail_blue", "c": "cabglass", "e": "ic_grey", "g": "truckgrey", "h": "headlight", "k": "truck", "w": "window"])
    static let hstPowerCarRear = RailVehicle("HST power car, rear", [
            ["...kkkk.........kkkk..", "...kkkk.........kkkk..", "...kkkk.........kkkk..", "...kkkk.........kkkk..", "...kkkk.........kkkk.."],
            [".yyyyyyyyyyyyyyyyyyyyy", "yyyyyyyyyyyyyyyyyyyyyy", "yyyyyyyyyyyyyyyyyyyyyy", "yyyyyyyyyyyyyyyyyyyyyy", ".yyyyyyyyyyyyyyyyyyyyy"],
            ["..yyyyyybbbbbbbbbbbbbb", ".yyyyyyybbbbbbbbbbbbbb", "hyyyyyyybbbbbbbbbbbbbb", ".yyyyyyybbbbbbbbbbbbbb", "..yyyyyybbbbbbbbbbbbbb"],
            ["....ccyyyyyyyyyyyyyyyy", "....ccyyyyyyyyyyyyyyyy", "....ccyyyyyyyyyyyyyyyy", "....ccyyyyyyyyyyyyyyyy", "....ccyyyyyyyyyyyyyyyy"],
            ["......RRRRRRRRRRRRRRRR", "......RRRRRRRRRRRRRRRR", "......RRRRRRRRRRRRRRRR", "......RRRRRRRRRRRRRRRR", "......RRRRRRRRRRRRRRRR"]],
        ["R": "ic_roof", "b": "rail_blue", "c": "cabglass", "g": "truckgrey", "h": "tail", "k": "truck", "w": "window", "y": "warn_yellow"])
    static let class55Deltic = RailVehicle("Class 55 Deltic", [
            ["..kkkkkk..........kkkkkk..", "..kkkkkk..........kkkkkk..", "..kkkkkk..........kkkkkk..", "..kkkkkk..........kkkkkk..", "..kkkkkk..........kkkkkk.."],
            ["llllllllllllllllllllllllll", "GGGGGGGGGGGGGGGGGGGGGGGGGG", "GGGGGGGGGGGGGGGGGGGGGGGGGG", "GGGGGGGGGGGGGGGGGGGGGGGGGG", "llllllllllllllllllllllllll"],
            ["yGGGGGGGGGGGGGGGGGGGGGGGGy", "yGGGGGGGGGGGGGGGGGGGGGGGGy", "hGGGGGGGGGGGGGGGGGGGGGGGGh", "yGGGGGGGGGGGGGGGGGGGGGGGGy", "yGGGGGGGGGGGGGGGGGGGGGGGGy"],
            ["...GcGGGGGGGGGGGGGGGGcG...", "...eGGGGGGGGGGGGGGGGGGe...", "...eGGGGGGGGGGGGGGGGGGe...", "...eGGGGGGGGGGGGGGGGGGe...", "...GcGGGGGGGGGGGGGGGGcG..."],
            ["...RRRRRRRRRRRRRRRRRRRR...", "...RRRRRRRRRRRRRRRRRRRR...", "...RFFRRRRRRRRRRRRRRFFR...", "...RRRRRRRRRRRRRRRRRRRR...", "...RRRRRRRRRRRRRRRRRRRR..."]],
        ["F": "fan", "G": "rail_blue", "R": "rail_blue", "c": "cabglass", "e": "warn_yellow", "g": "truckgrey", "h": "headlight", "k": "truck", "l": "rail_blue", "w": "window", "y": "warn_yellow"])
    static let mark1Coach = RailVehicle("Mark 1 coach", [
            ["..kkk...............kkk..", "..kkk...............kkk..", "..kkk...............kkk..", "..kkk...............kkk..", "..kkk...............kkk.."],
            ["bbbbbbbbbbbbbbbbbbbbbbbbb", "bbbbbbbbbbbbbbbbbbbbbbbbb", "bbbbbbbbbbbbbbbbbbbbbbbbb", "bbbbbbbbbbbbbbbbbbbbbbbbb", "bbbbbbbbbbbbbbbbbbbbbbbbb"],
            ["eewweewweewweewweewweewwe", "eeeeeeeeeeeeeeeeeeeeeeeee", "eeeeeeeeeeeeeeeeeeeeeeeee", "eeeeeeeeeeeeeeeeeeeeeeeee", "eewweewweewweewweewweewwe"],
            ["eeeeeeeeeeeeeeeeeeeeeeeee", "eeeeeeeeeeeeeeeeeeeeeeeee", "eeeeeeeeeeeeeeeeeeeeeeeee", "eeeeeeeeeeeeeeeeeeeeeeeee", "eeeeeeeeeeeeeeeeeeeeeeeee"],
            ["RRRRRRRRRRRRRRRRRRRRRRRRR", "RRRRRRRRRRRRRRRRRRRRRRRRR", "QQQQQQQQQQQQQQQQQQQQQQQQQ", "RRRRRRRRRRRRRRRRRRRRRRRRR", "RRRRRRRRRRRRRRRRRRRRRRRRR"]],
        ["Q": "ic_roof_lt", "R": "ic_roof", "b": "rail_blue", "c": "cabglass", "e": "ic_grey", "g": "truckgrey", "h": "headlight", "k": "truck", "w": "window"])
    static let class47 = RailVehicle("Class 47", [
            ["..kkkkkk........kkkkkk..", "..kkkkkk........kkkkkk..", "..kkkkkk........kkkkkk..", "..kkkkkk........kkkkkk..", "..kkkkkk........kkkkkk.."],
            ["bbbbbbbbbbbbbbbbbbbbbbbb", "bbbbbbbbbbbbbbbbbbbbbbbb", "bbbbbbbbbbbbbbbbbbbbbbbb", "bbbbbbbbbbbbbbbbbbbbbbbb", "bbbbbbbbbbbbbbbbbbbbbbbb"],
            ["ybbbbbbbbbbbbbbbbbbbbbby", "ybbbbbbbbbbbbbbbbbbbbbby", "hbbbbbbbbbbbbbbbbbbbbbbh", "ybbbbbbbbbbbbbbbbbbbbbby", "ybbbbbbbbbbbbbbbbbbbbbby"],
            ["yccbbbbbbbbbbbbbbbbbbccy", "ycbbbbbbbbbbbbbbbbbbbbcy", "ycbbbbbbbbbbbbbbbbbbbbcy", "ycbbbbbbbbbbbbbbbbbbbbcy", "yccbbbbbbbbbbbbbbbbbbccy"],
            ["RRRRRRRRRRRRRRRRRRRRRRRR", "RRRRRRRRRRRRRRRRRRRRRRRR", "RFFRRRRRRRRRRRRRRRRRRFFR", "RRRRRRRRRRRRRRRRRRRRRRRR", "RRRRRRRRRRRRRRRRRRRRRRRR"]],
        ["F": "fan", "R": "rail_blue", "b": "rail_blue", "c": "cabglass", "g": "truckgrey", "h": "headlight", "k": "truck", "w": "window", "y": "warn_yellow"])
    static let db103 = RailVehicle("DB 103", [
            ["..kkkkkk........kkkkkk..", "..kkkkkk........kkkkkk..", "..kkkkkk........kkkkkk..", "..kkkkkk........kkkkkk..", "..kkkkkk........kkkkkk.."],
            ["ffffffffffffffffffffffff", "rrrrrrrrrrrrrrrrrrrrrrrr", "rrrrrrrrrrrrrrrrrrrrrrrr", "rrrrrrrrrrrrrrrrrrrrrrrr", "ffffffffffffffffffffffff"],
            ["rrrrrrrrrrrrrrrrrrrrrrrr", "rrrrrrrrrrrrrrrrrrrrrrrr", "hrrrrrrrrrrrrrrrrrrrrrrh", "rrrrrrrrrrrrrrrrrrrrrrrr", "rrrrrrrrrrrrrrrrrrrrrrrr"],
            ["..ceeeeeeeeeeeeeeeeeec..", "..ceeeeeeeeeeeeeeeeeec..", "..ceeeeeeeeeeeeeeeeeec..", "..ceeeeeeeeeeeeeeeeeec..", "..ceeeeeeeeeeeeeeeeeec.."],
            ["...RRRRRRRRRRRRRRRRRR...", "...RRRRRRRRRRRRRRRRRR...", "...RRRRRRRRRRRRRRRRRR...", "...RRRRRRRRRRRRRRRRRR...", "...RRRRRRRRRRRRRRRRRR..."],
            ["........................", "........................", "......P.........P.......", "........................", "........................"],
            ["........................", "........................", "......P.........P.......", "........................", "........................"],
            ["........................", "......PP........PP......", "......PP........PP......", "......PP........PP......", "........................"]],
        ["P": "panto", "R": "tee_roof", "c": "cabglass", "e": "tee_beige", "f": "db_frame", "g": "truckgrey", "h": "headlight", "k": "truck", "r": "purpurrot", "w": "window"])
    static let teeRheingoldCar = RailVehicle("TEE Rheingold car", [
            ["..kkkk.....................kkkk..", "..kkkk.....................kkkk..", "..kkkk.....................kkkk..", "..kkkk.....................kkkk..", "..kkkk.....................kkkk.."],
            ["rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr", "rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr", "rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr", "rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr", "rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr"],
            ["eewweewweewweewweewweewweewweewwe", "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee", "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee", "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee", "eewweewweewweewweewweewweewweewwe"],
            ["eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee", "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee", "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee", "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee", "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"],
            ["RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR", "RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR", "QQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQ", "RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR", "RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR"]],
        ["Q": "tee_roof_lt", "R": "tee_roof", "c": "cabglass", "e": "tee_beige", "g": "truckgrey", "h": "headlight", "k": "truck", "r": "purpurrot", "w": "window"])
    static let teeRheingoldDomeCar = RailVehicle("TEE Rheingold dome car", [
            ["..kkkk.....................kkkk..", "..kkkk.....................kkkk..", "..kkkk.....................kkkk..", "..kkkk.....................kkkk..", "..kkkk.....................kkkk.."],
            ["rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr", "rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr", "rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr", "rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr", "rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr"],
            ["eewweewweewweewweewweewweewweewwe", "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee", "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee", "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee", "eewweewweewweewweewweewweewweewwe"],
            ["eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee", "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee", "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee", "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee", "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"],
            ["RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR", "RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR", "QQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQ", "RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR", "RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR"],
            [".................................", "..........RDDDDDDDDDDDR..........", "..........RDDDDDDDDDDDR..........", "..........RDDDDDDDDDDDR..........", "................................."]],
        ["D": "dome_glass", "Q": "tee_roof_lt", "R": "tee_roof", "c": "cabglass", "e": "tee_beige", "g": "truckgrey", "h": "headlight", "k": "truck", "r": "purpurrot", "w": "window"])
    static let dbV200 = RailVehicle("DB V 200", [
            ["..kkkk...........kkkk..", "..kkkk...........kkkk..", "..kkkk...........kkkk..", "..kkkk...........kkkk..", "..kkkk...........kkkk.."],
            ["fffffffffffffffffffffff", "rrrrrrrrrrrrrrrrrrrrrrr", "rrrrrrrrrrrrrrrrrrrrrrr", "rrrrrrrrrrrrrrrrrrrrrrr", "fffffffffffffffffffffff"],
            ["rrrrrrrrrrrrrrrrrrrrrrr", "rrrrrrrrrrrrrrrrrrrrrrr", "hrrrrrrrrrrrrrrrrrrrrrh", "rrrrrrrrrrrrrrrrrrrrrrr", "rrrrrrrrrrrrrrrrrrrrrrr"],
            [".crrrrrrrrrrrrrrrrrrrc.", ".crrrrrrrrrrrrrrrrrrrc.", ".crrrrrrrrrrrrrrrrrrrc.", ".crrrrrrrrrrrrrrrrrrrc.", ".crrrrrrrrrrrrrrrrrrrc."],
            [".fffffffffffffffffffff.", ".AAAAAAAAAAAAAAAAAAAAA.", ".AAAAAAAAAAAAAAAAAAAAA.", ".AAAAAAAAAAAAAAAAAAAAA.", ".fffffffffffffffffffff."]],
        ["A": "v200_roof", "c": "cabglass", "f": "db_frame", "g": "truckgrey", "h": "headlight", "k": "truck", "r": "purpurrot", "w": "window"])
    static let dbGreenCoach = RailVehicle("DB green coach", [
            ["..kkkk.....................kkkk..", "..kkkk.....................kkkk..", "..kkkk.....................kkkk..", "..kkkk.....................kkkk..", "..kkkk.....................kkkk.."],
            ["GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG", "GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG", "GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG", "GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG", "GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG"],
            ["GGwwGGwwGGwwGGwwGGwwGGwwGGwwGGwwG", "GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG", "GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG", "GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG", "GGwwGGwwGGwwGGwwGGwwGGwwGGwwGGwwG"],
            ["GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG", "GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG", "GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG", "GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG", "GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG"],
            ["RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR", "RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR", "QQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQ", "RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR", "RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR"]],
        ["G": "chrom_green", "Q": "dzug_roof_lt", "R": "dzug_roof", "c": "cabglass", "g": "truckgrey", "h": "headlight", "k": "truck", "w": "window"])
    static let dbClass01 = RailVehicle("DB class 01", [
            [".kk..ddrddrddd..kk.kk.", ".kkkkkkkkkkkkkkkkkkkpp", ".kkkkkkkkkkkkkkkkkkkpp", ".kkkkkkkkkkkkkkkkkkkpp", ".kk..ddrddrddd..kk.kk."],
            [".CCCCaaaaaaaaaaaaaaaxx", ".CCCCbbbbbbbbbbbbbbbxx", ".CCCCbbbbbbbbbbbbbbbxx", ".CCCCbbbbbbbbbbbbbbbxx", ".CCCCaaaaaaaaaaaaaaaxx"],
            [".CCCC.................", ".CCCCbbbbbbbbbbbbbbbxx", ".CCCCbbbbbbbbbbbbbbbxh", ".CCCCbbbbbbbbbbbbbbbxx", ".CCCC................."],
            [".CccC.................", ".CCCCbbbbbbbbbbbbbbbx.", ".CCCCBBBBBBBBBBBBBBBx.", ".CCCCbbbbbbbbbbbbbbbx.", ".CccC................."],
            [".RRRR.................", ".RRRR.................", ".RRRR...m....m.....u..", ".RRRR.................", ".RRRR................."]],
        ["B": "db_ridge", "C": "db_black", "R": "db_black", "a": "db_red", "b": "db_black", "c": "cabglass", "d": "db_red", "h": "headlight", "k": "bb_drivers", "m": "db_black", "p": "black", "r": "bb_rod", "u": "db_black", "x": "loco_black"], bogies: 0.7)
    static let v01Tender = RailVehicle("01 tender", [
            [".kk.kk..kk.kk.", ".kk.kk..kk.kk.", ".kk.kk..kk.kk.", ".kk.kk..kk.kk.", ".kk.kk..kk.kk."],
            ["aaaaaaaaaaaaaa", "bbbbbbbbbbbbbb", "bbbbbbbbbbbbbb", "bbbbbbbbbbbbbb", "aaaaaaaaaaaaaa"],
            ["bbbbbbbbbbbbbb", "bbbbbbbbbbbbbb", "bbbbbbbbbbbbbb", "bbbbbbbbbbbbbb", "bbbbbbbbbbbbbb"],
            ["bbbbbbbbbbbbbb", "bbbbqqqqqqqqqq", "bbbbqqqqqqqqqq", "bbbbqqqqqqqqqq", "bbbbbbbbbbbbbb"],
            ["..............", "......qQqq....", "......qQqq....", "......qQqq....", ".............."]],
        ["Q": "coal_glint", "a": "db_red", "b": "db_black", "k": "db_red", "q": "coal_uk"])
    static let sbbCrocodile = RailVehicle("SBB Crocodile", [
            [".kddrdd..........ddrddk.", ".kkkkkkkkkkkkkkkkkkkkkk.", ".kkkkkkkkkkkkkkkkkkkkkk.", ".kkkkkkkkkkkkkkkkkkkkkk.", ".kddrdd..........ddrddk."],
            [".......bbbbbbbbbb.......", "bbbbbbbbbbbbbbbbbbbbbbbb", "hbbbbbbbbbbbbbbbbbbbbbbh", "bbbbbbbbbbbbbbbbbbbbbbbb", ".......bbbbbbbbbb......."],
            [".......bbbbbbbbbb.......", "bbbbbbbbbbbbbbbbbbbbbbbb", "bbbbbbbbbbbbbbbbbbbbbbbb", "bbbbbbbbbbbbbbbbbbbbbbbb", ".......bbbbbbbbbb......."],
            [".......bcbbbbbbcb.......", ".......bbbbbbbbbb.......", ".......bbbbbbbbbb.......", ".......bbbbbbbbbb.......", ".......bcbbbbbbcb......."],
            [".......RRRRRRRRRR.......", ".......RRRRRRRRRR.......", ".......RRRRRRRRRR.......", ".......RRRRRRRRRR.......", ".......RRRRRRRRRR......."],
            ["........................", "........................", "........P.....P.........", "........................", "........................"],
            ["........................", "........................", "........P.....P.........", "........................", "........................"],
            ["........................", "........PP....PP........", "........PP....PP........", "........PP....PP........", "........................"]],
        ["P": "panto", "R": "croc_roof", "b": "croc_green", "c": "cabglass", "d": "bb_drivers", "g": "truckgrey", "h": "headlight", "k": "truck", "r": "bb_rod", "w": "window"], bogies: 0.6)
    static let goodsWagon = RailVehicle("Goods wagon", [
            [".kk......kk.", ".kk......kk.", ".kk......kk.", ".kk......kk.", ".kk......kk."],
            ["WWWWWWWWWWWW", "WWWWWWWWWWWW", "WWWWWWWWWWWW", "WWWWWWWWWWWW", "WWWWWWWWWWWW"],
            ["WWWWWDDWWWWW", "WWWWWWWWWWWW", "WWWWWWWWWWWW", "WWWWWWWWWWWW", "WWWWWDDWWWWW"],
            ["WWWWWWWWWWWW", "WWWWWWWWWWWW", "WWWWWWWWWWWW", "WWWWWWWWWWWW", "WWWWWWWWWWWW"],
            ["RRRRRRRRRRRR", "RRRRRRRRRRRR", "QQQQQQQQQQQQ", "RRRRRRRRRRRR", "RRRRRRRRRRRR"]],
        ["D": "wagon_brown_dk", "Q": "wagon_roof", "R": "wagon_roof", "W": "wagon_brown", "k": "truck"], bogies: 0.6)

    static let worldTrains: [Consist] = [
        Consist(key: "a3", name: "LNER A3 with teak coaches", era: .britishSteam, vehicles: [lnerA3, a3Tender, lnerTeakCoach, lnerTeakCoach, lnerTeakCoach, lnerTeakCoach], cruise: 17, power: 2),
        Consist(key: "a4", name: "LNER A4 with teak coaches", era: .britishSteam, vehicles: [lnerA4, a4Tender, lnerTeakCoach, lnerTeakCoach, lnerTeakCoach, lnerTeakCoach], cruise: 19, power: 2),
        Consist(key: "castle", name: "GWR Castle with chocolate-and-cream coaches", era: .britishSteam, vehicles: [gwrCastle, castleTender, gwrChocolateAndCreamCoach, gwrChocolateAndCreamCoach, gwrChocolateAndCreamCoach, gwrChocolateAndCreamCoach], cruise: 16, power: 2),
        Consist(key: "coronation", name: "LMS Princess Coronation with crimson coaches", era: .britishSteam, vehicles: [lmsPrincessCoronationStreamlined, coronationTender, lmsCrimsonCoach, lmsCrimsonCoach, lmsCrimsonCoach, lmsCrimsonCoach], cruise: 18, power: 2),
        Consist(key: "s8f", name: "LMS 8F with mineral wagons", era: .britishSteam, vehicles: [lms8F, v8fTender, v16TMineralWagon, v16TMineralWagon, v16TMineralWagon, v16TMineralWagon, v16TMineralWagon, v16TMineralWagon, v16TMineralWagon, v16TMineralWagon, v16TMineralWagon, v16TMineralWagon, brBrakeVan], cruise: 11, power: 2),
        Consist(key: "hst", name: "HST with Mark 3 coaches", era: .britishDiesel, vehicles: [hstPowerCar, mark3Coach, mark3Coach, mark3Coach, mark3Coach, hstPowerCarRear], cruise: 20),
        Consist(key: "deltic", name: "Class 55 Deltic with blue and grey coaches", era: .britishDiesel, vehicles: [class55Deltic, mark1Coach, mark1Coach, mark1Coach, mark1Coach], cruise: 18),
        Consist(key: "c47", name: "Class 47 with mineral wagons", era: .britishDiesel, vehicles: [class47, v16TMineralWagon, v16TMineralWagon, v16TMineralWagon, v16TMineralWagon, v16TMineralWagon, v16TMineralWagon, v16TMineralWagon, v16TMineralWagon, v16TMineralWagon, v16TMineralWagon, brBrakeVan], cruise: 12),
        Consist(key: "tee", name: "DB 103 with the TEE Rheingold", era: .germanAlps, vehicles: [db103, teeRheingoldCar, teeRheingoldDomeCar, teeRheingoldCar, teeRheingoldCar], cruise: 19),
        Consist(key: "v200", name: "DB V 200 with green coaches", era: .germanAlps, vehicles: [dbV200, dbGreenCoach, dbGreenCoach, dbGreenCoach, dbGreenCoach], cruise: 16),
        Consist(key: "db01", name: "DB class 01 with green coaches", era: .germanAlps, vehicles: [dbClass01, v01Tender, dbGreenCoach, dbGreenCoach, dbGreenCoach, dbGreenCoach], cruise: 16, power: 2),
        Consist(key: "croc", name: "SBB Crocodile with goods wagons", era: .germanAlps, vehicles: [sbbCrocodile, goodsWagon, goodsWagon, goodsWagon, goodsWagon, goodsWagon, goodsWagon, goodsWagon, goodsWagon, goodsWagon, goodsWagon], cruise: 10),
    ]
}
