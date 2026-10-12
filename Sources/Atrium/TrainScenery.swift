import Foundation

/// The kinds of country the train's line runs through. Farmland is `TrainWorld`'s own (PixelTrain.swift); the others
/// are laid here, each the mock-ups' painter line for line (docs/pixel-window-seat/train_scenery.py), as farmland is
/// train.py's, so that what they lay can be checked against the sheet Dave picked from byte for byte.
enum TrainCountry {
    case farmland, mountains, city, snow, desert

    /// What sets one country's hashes apart from another's, as in the mock-ups.
    var salt: UInt64 {
        switch self {
        case .farmland: 0
        case .mountains: 100_000
        case .snow: 200_000
        case .desert: 300_000
        case .city: 400_000
        }
    }

    /// How far off things have faded most of the way to the horizon's colour, in metres: mountain air is clear,
    /// and a city's is not.
    var haze: Double {
        switch self {
        case .farmland: TrainWorld.haze
        case .mountains: 60_000
        case .desert: 45_000
        case .snow: 40_000
        case .city: 16_000
        }
    }

    /// For each ring, how high the land can stand above the track, in metres (farmland's are `TrainWorld.rise`,
    /// and a city is level). The mountains' are the Alps' at their steepest, held all along the line; snow's are
    /// the fells of a high plateau, twice life size; the desert's a far range, then mesas and buttes, then dunes.
    var peaks: [Double] {
        switch self {
        case .mountains: Self.alps
        case .snow: Self.fells
        case .desert: Self.mesas
        case .farmland, .city: Self.level
        }
    }
    private static let alps: [Double] = [4800, 4500, 4200, 2600, 450, 130, 30, 9, 0, 0, 0], fells: [Double] = [2600, 2400, 2200, 1300, 300, 80, 26, 9, 0, 0, 0]
    private static let mesas: [Double] = [2200, 1500, 1100, 600, 90, 30, 6, 0, 0, 0, 0], level = [Double](repeating: 0, count: 11)

    /// What its rows of ground are made of. Mountains: alpine meadows, and a milky river with its gravel bank where
    /// farmland has a lane. A city: roofs and yards far off; nearer, the railway's own ground, ballast with the next
    /// lines' rails as level lines 19 to 34 m out and a brick wall where the lane was.
    /// Snow: a snowfield, drifted and wind-scoured, with frozen tarns far off, a ploughed road where the lane was and a
    /// snow fence 38 m out. Desert: ochre steppe and sand, and a dirt track with scrub beside it.
    var ground: TrainGround {
        switch self {
        case .farmland: Self.farm
        case .mountains: Self.valley
        case .city: Self.yards
        case .snow: Self.snowfield
        case .desert: Self.steppe
        }
    }
    private static let steppe = TrainGround(fields: [TrainMat.steppe, TrainMat.sand, TrainMat.steppe, TrainMat.steppeDry, TrainMat.sand, TrainMat.steppe,
                                                     TrainMat.steppeDry, TrainMat.steppe, TrainMat.sandShade, TrainMat.steppe],
                                            hedge: nil, lines: (TrainMat.scrubShade, TrainMat.scrub, TrainMat.track),
                                            far: (TrainMat.steppe, TrainMat.sand), near: (TrainMat.steppe, TrainMat.steppeDry), verge: TrainMat.sandShade,
                                            mixing: 50, salt: 300_000)
    private static let snowfield = TrainGround(fields: [TrainMat.snow, TrainMat.snow, TrainMat.snowShade, TrainMat.snow, TrainMat.ice, TrainMat.snow,
                                                        TrainMat.snowShade, TrainMat.snow, TrainMat.snow, TrainMat.ice],
                                               hedge: nil, lines: (TrainMat.snowShade, TrainMat.snowShade, TrainMat.road),
                                               far: (TrainMat.snow, TrainMat.snowShade), near: (TrainMat.snow, TrainMat.snow), verge: TrainMat.snowShade,
                                               rails: [38.0], rail: TrainMat.birch, mixing: 50, salt: 200_000)
    private static let farm = TrainGround(fields: TrainWorld.fields, hedge: TrainMat.hedge, lines: (TrainMat.hedge, TrainMat.hedgeLit, TrainMat.road),
                                          far: (TrainMat.ley, TrainMat.wheat), near: (TrainMat.pasture, TrainMat.crop), verge: TrainMat.verge, salt: 0)
    private static let valley = TrainGround(fields: [TrainMat.alp, TrainMat.pasture, TrainMat.alp, TrainMat.ley, TrainMat.alp, TrainMat.pasture,
                                                     TrainMat.stubble, TrainMat.alp, TrainMat.ley, TrainMat.pasture],
                                            hedge: TrainMat.hedge, lines: (TrainMat.rock, TrainMat.river, TrainMat.river),
                                            far: (TrainMat.alp, TrainMat.pasture), near: (TrainMat.pasture, TrainMat.alp), verge: TrainMat.verge, salt: 100_000)
    private static let yards = TrainGround(fields: [TrainMat.tar, TrainMat.concreteShade, TrainMat.tar, TrainMat.slate, TrainMat.tar, TrainMat.brickShade,
                                                    TrainMat.tar, TrainMat.concreteShade, TrainMat.slateShade, TrainMat.tar],
                                           hedge: nil, lines: (TrainMat.brickShade, TrainMat.brick, TrainMat.tar),
                                           far: (TrainMat.tar, TrainMat.ballast), near: (TrainMat.ballast, TrainMat.ballast), verge: TrainMat.ballast,
                                           rails: [19.0, 20.435, 33.0, 34.435], mixing: 50, salt: 400_000)
}

/// What a country's rows of ground are made of: the crops of its far fields and what divides them, if anything; its
/// level lines, which stay still as the train goes (the three rows just beyond `TrainWorld.lane`, far to near, and
/// `rail` on the rows `rails` metres off); the near field's two crops beyond the lane and its two this side of it;
/// and the railway's own verge. `salt` sets its draws apart from another country's.
struct TrainGround {
    let fields: [UInt8], hedge: UInt8?, lines: (UInt8, UInt8, UInt8), far: (UInt8, UInt8), near: (UInt8, UInt8), verge: UInt8
    var rails: [Double] = [], rail = TrainMat.rail
    /// Over how many metres its near crops change into a neighbour's, dash by dash, where two countries meet: a
    /// hundred or so between two greens, a third of that where a city's ballast gives way to a field, which mixed
    /// as blotches of grey and green for six seconds.
    var mixing = 160.0
    let salt: UInt64
}

/// A place along the line: the country it lies in, and how many metres it is from where another begins (for ever,
/// while Settings holds the line to one scenery).
struct TrainPlace {
    let kind: TrainCountry, edge: Double
    var beside: TrainCountry? // the country beyond the nearer end of its stretch, if the line is left to change

    /// How far the land has risen there, 0 to 1, on a ring `z` metres off: toward each end of a stretch the land
    /// sinks to the level of the track, so that one country gives way to the next with no seam, over 3 km beside
    /// the line and wider far off, where the pane takes in more of it.
    func relief(_ z: Double) -> Double {
        guard edge < .infinity else { return 1 }
        let t = clip(edge / (3000 + 0.15 * z))
        return t * t * (3 - 2 * t)
    }
}

extension TrainWorld {
    /// Left to change, a country lasts about this far along the line: between two fifths and eight fifths of it,
    /// so from 11 minutes to three quarters of an hour at 1×.
    static let stretch = 22_000.0
    /// The countries Changing passes through between its stretches of farmland.
    static let passing: [TrainCountry] = [.mountains, .city, .snow, .desert]
    /// The country Settings' Scenery holds the line to, by its pick (a lake's is farmland, and the last is a city
    /// with a lake beside it).
    private static let held: [TrainCountry] = [.farmland, .farmland, .farmland, .mountains, .city, .snow, .desert, .city]

    /// Where a place along the line lies. Held on a scenery by Settings, the line is all one country. Left to
    /// change, it is cut into stretches at uneven places: every other one is farmland, and each between draws its
    /// country, so the line always comes back to farmland and no country runs on into another of its kind.
    func country(_ wx: Double) -> TrainPlace {
        guard scenery == 0 else { return TrainPlace(kind: Self.held.indices.contains(scenery) ? Self.held[scenery] : .farmland, edge: .infinity) }
        func begins(_ k: Int) -> Double { (Double(k) + 0.2 + 0.6 * unit(hash(k, 0, 7171))) * Self.stretch }
        let near = Int((wx / Self.stretch).rounded(.down)), k = wx >= begins(near) ? near : near - 1
        func kind(_ k: Int) -> TrainCountry { k & 1 == 0 ? .farmland : Self.passing[Int(unit(hash(k, 1, 7171)) * Double(Self.passing.count))] }
        let back = wx - begins(k), on = begins(k + 1) - wx
        return TrainPlace(kind: kind(k), edge: min(back, on), beside: kind(back < on ? k - 1 : k + 1))
    }

    /// Whether something can stand in a plot of track `at` metres along in the country `kind`: not in another
    /// country, nor close enough to where one begins to stand astride the two.
    func stands(_ at: Double, in kind: TrainCountry) -> Bool {
        let place = country(at)
        return place.kind == kind && place.edge > 60
    }

    /// How far off things have faded to the horizon's colour, where the train is: each country's own, and
    /// farmland's where two meet. A city across a lake stands in the lake's haze as well as its own, and fades at
    /// `overWater` of the distance, the nearer to that the wider the water has opened: its towers are then paler
    /// than the shore in front of them, and sit back.
    func haze(_ wx: Double) -> Double {
        let place = country(wx), far = Self.haze + (place.kind.haze - Self.haze) * place.relief(0)
        return place.kind == .city ? far * (1 - (1 - Self.overWater) * (1 - min(shore(wx), Self.farShore) / Self.farShore)) : far
    }
    static let overWater = 0.5

    /// How many rows a ring's strip needs for the tallest thing any other country stands there.
    func otherRows(_ ring: Int) -> Int {
        let ppm = perMetre(ring)
        let tallest = max(TrainCountry.mountains.peaks[ring], TrainCountry.snow.peaks[ring], TrainCountry.desert.peaks[ring])
        return max(Int((34 * ppm).rounded(.up)) + 4 + Int((tallest * ppm).rounded(.up)), Int((max(Self.towers[ring], 17) * ppm).rounded(.up)) + 4)
    }

    /// How high a country's land stands above the track `wx` metres along, on a ring, in metres. Mountains: from
    /// 3.5 km out, sharp crests cut by side valleys, where the ranges behind show through; nearer, the valley
    /// floor's gentle swell.
    private func height(_ kind: TrainCountry, _ ring: Int, _ wx: Double, _ salt: UInt64) -> Double {
        let z = Self.rings[ring], top = kind.peaks[ring]
        guard top > 0 else { return 0 }
        if kind == .desert, z >= 7000 { // a low rounded range farthest off; nearer, mesas: flat tops, steep sides, the plain between
            return z >= 60000 ? top * clip(fbm(wx / (z * 0.9), z / 4000, 4, salt) * 1.5 - 0.28) : top * clip((fbm(wx / (z * 0.7 + 2500), z / 4000, 4, salt) - 0.50) * 10)
        }
        if z >= 7000 || (kind == .mountains && z >= 3500) { // (the snow's far fells are the mountains' wall, at about half the height)
            let crest = ridged(wx / (z * 0.5 + 2500), z / 9000, 5, salt)
            let massif = clip((fbm(wx / (z * 1.6 + 5000), 3, 2, salt + 9) - 0.20) * 2.5)
            return top * clip(crest * 1.5 - 0.35) * (0.45 + 0.55 * massif)
        }
        return top * clip(fbm(wx / (z * 1.3) + 3, z / 2000, 3, salt + 60) * 1.7 - 0.42)
    }

    /// Lays column `n` of a ring in a country other than farmland, as `column` does farmland's: the land's height
    /// there and what covers its face, the woods along its top, whatever stands in that plot of track, the lane's
    /// poles, and the lights that show after dark. `relief` is how far the land has risen at this place.
    ///
    /// Mountains, a line along a high valley. From 3.5 km out the land is a wall: fir forest with alps in it up to
    /// about 1,050 m above the track, pasture to 1,400, then rock, and snow from each ring's own snowline, the faces
    /// turned from the Sun in shade. Nearer is the valley's floor: meadows in strips, patches of fir, farmland's
    /// villages with their church and grey-roofed timber chalets, and firs with a few broadleaves among them.
    ///
    /// Snow, a line over a bare plateau: fells, snow over the swells, cabins and snow-laden firs (see where each is laid).
    ///
    /// Desert and steppe. A low blue range 60 km off; mesas and buttes at 30, 15 and 7 km, banded in two reds over a
    /// skirt of scree; dunes and low rises nearer, with a little scrub; then scrub in clumps from 900 m in, thicker by
    /// the line, and where farmland has villages a camp of round felt tents, each with a door that glows after dark.
    func otherColumn(_ kind: TrainCountry, _ ring: Int, _ n: Int, into cells: UnsafeMutablePointer<UInt8>, by laid: [Laying], relief: Double) -> UInt8 {
        if kind == .city { return cityColumn(ring, n, into: cells, by: laid) }
        let z = Self.rings[ring], ppm = focal / z, wx = Double(n) / ppm, salt = UInt64(z) + kind.salt, rows = rows(ring)
        guard z >= Self.farShore || z <= shore(wx) else { return 0 } // out in a lake
        /// How fast the ring slid, in pixels a second, and which side the Sun was on, when column `n` came into view.
        func when(_ n: Int) -> (pace: Double, sun: Int) {
            let by = laid.last { $0.from <= n } ?? laid.first
            return (ppm * (by?.speed ?? speed), by?.sun ?? sun)
        }
        /// How high the land stands at a column, in pixels.
        func high(_ n: Int) -> Int { Int((height(kind, ring, Double(n) / ppm, salt) * relief * ppm).rounded(.toNearestOrEven)) }
        let pace = when(n).pace, swollen = high(n), face = min(swollen, rows)
        let slope = Double((high(n + 4) - high(n - 4)) * when(n).sun) // above 0 where the land's face is turned to the Sun
        if kind == .snow, z >= 7000 {
            // A far fell is the mountains' wall under snow: dark crags where the mountains have theirs and more of them
            // where it is steep, fir under snow at its foot, and the rest snow, in sunlight or in blue shadow. The
            // shadow lies in long ragged drifts, as the crags do: nearly all of a slope turned from the Sun and little
            // of one turned to it (the slope taken over sixteen columns, so that a flank is a piece and not stripes).
            let turned = min(max(Double((high(n + 8) - high(n - 8)) * when(n).sun) / 6, -1), 1), steep = clip(abs(slope) / 8)
            for up in 0..<face {
                let alt = Double(up) / ppm, draw = unit(hash(n >> 1, up, salt + 7)) - 0.5
                let crag = fbm(wx / (z * 0.05 + 300), alt / 110, 3, salt + 5)
                if alt < 220 + draw * 80 + (crag - 0.5) * 600 {
                    cells[up] = draw > 0.2 ? TrainMat.snow : TrainMat.fir0
                } else if crag > 0.70 - 0.12 * steep {
                    cells[up] = TrainMat.rockShade
                } else {
                    cells[up] = fbm(wx / (z * 0.08 + 500), alt / 160, 3, salt + 8) < 0.5 - 0.22 * turned ? TrainMat.snowShade : TrainMat.snow
                }
            }
        } else if kind == .snow { // nearer, snow over the swells, shadowed where they fall away, with rock and dwarf birch showing
            for up in 0..<face {
                let crust = fbm(wx / (z * 0.2 + 150), Double(up) / ppm / (z * 0.012 + 6), 3, salt + 62)
                cells[up] = crust > 0.64 ? TrainMat.rockShade : crust < 0.31 ? TrainMat.birch : slope > -2 ? TrainMat.snow : TrainMat.snowShade
            }
        } else if kind == .desert {
            let shade = clip(-slope / 4), banded = [1, 230.0, 120, 70, 1, 1, 1, 1, 1, 1, 1][ring] // how thick a mesa's bands are, in metres
            for up in 0..<face {
                let lit = unit(hash(n >> 1, up, salt + 6)) >= shade
                if z >= 60000 {
                    cells[up] = lit ? TrainMat.rock : TrainMat.rockShade
                } else if z >= 7000 {
                    let band = Int((Double(up) / ppm / banded).rounded(.down))
                    cells[up] = up * 10 < swollen * 3 ? (lit ? TrainMat.sand : TrainMat.sandShade) : !lit ? TrainMat.mesaShade : band % 2 == 0 ? TrainMat.mesa : TrainMat.mesaPale
                } else {
                    cells[up] = unit(hash(n, up, salt + 63)) < 0.06 ? TrainMat.scrub : lit ? TrainMat.sand : TrainMat.sandShade
                }
            }
        } else if z >= 3500 {
            let snowline = [2300.0, 2100, 1900, 1500, 99999][ring], shade = clip(-slope / 4), sunny = clip(0.30 + slope * 0.06)
            for up in 0..<face {
                // (Speckle is drawn two pixels at a time along a row, so that a ring sliding a pixel changes half as much of it.)
                let alt = Double(up) / ppm, lit = unit(hash(n >> 1, up, salt + 6)) >= shade, draw = unit(hash(n >> 1, up, salt + 7)) - 0.5
                let crag = fbm(wx / (z * 0.05 + 300), alt / 110, 3, salt + 5) // cliffs, clearings and gullies
                if alt > snowline + draw * 260 - (crag - 0.5) * 700 {
                    cells[up] = crag > 0.70 ? TrainMat.rockShade : lit ? TrainMat.snow : TrainMat.snowShade
                } else if alt < 1050 + draw * 160 + (crag - 0.5) * 500 { // the firs' lit tops, more of them toward the Sun
                    cells[up] = crag > 0.70 ? TrainMat.alp : draw + 0.5 < sunny ? TrainMat.fir1 : TrainMat.fir0
                } else if alt < 1400 + draw * 200 + (crag - 0.5) * 300 {
                    cells[up] = TrainMat.alp
                } else {
                    cells[up] = lit ? TrainMat.rock : TrainMat.rockShade
                }
            }
        } else if face > 0 {
            let long = [0, 0, 0, 0, 0, 300.0, 250, 230, 0, 0, 0][ring], deep = max(2, Double(swollen) / 3 + 0.5), meadows = kind.ground.fields
            for up in 0..<face {
                let band = (Double(up) / deep).rounded(.down), along = wx / long + band * 0.37
                let crop = meadows[Int(unit(hash(Int(along.rounded(.down)), Int(band), salt + 61)) * Double(meadows.count))]
                cells[up] = fbm(wx / (z * 0.2), Double(up) / 3, 3, salt + 62) > 0.63 ? TrainMat.fir0 : crop
            }
        }
        var top = face
        if z >= 500, z <= 1800, kind != .desert { // fir woods along the land's top, where it is wooded: a plateau is bare but for its sheltered hollows
            let wooded = fbm(wx / 900, z / 300, 3, salt + 1), share = kind == .snow ? clip((wooded - 0.50 - 0.08) * 14) : clip((wooded - 0.50) * 9)
            let tall = Int(((10 + 14 * fbm(wx / 60, 1, 3, salt + 2)) * ppm * share * relief).rounded(.toNearestOrEven))
            top = min(face + tall, rows)
            for up in face..<top {
                cells[up] = kind == .snow ? (up < face + tall - 1 ? TrainMat.fir0 : TrainMat.snow) : unit(hash(n >> 1, up, salt + 3)) >= 0.35 ? TrainMat.fir0 : TrainMat.fir1
            }
        }
        guard z <= 7000 else { return UInt8(top) } // (the ranges beyond have no plots, and nothing lit)
        let plot = kind == .desert ? Self.desertPlot[ring] : Self.plot[ring], here = Int((wx / plot).rounded(.down))
        if z <= 1800 {
            for c in here - 2...here + 2 {
                let draw = unit(hash(c, 1, salt + 30)), at = (Double(c) + unit(hash(c, 2, salt + 31))) * plot
                guard z >= Self.farShore || z <= shore(at), stands(at, in: kind) else { continue }
                let village = noise(at / 1400, 2, 4242), seed = Int(hash(c, 3, salt + 32) % (1 << 30)), size = unit(hash(c, 4, salt + 33))
                let stamp: Stamp, spired = kind == .mountains && z == 900 && village > 0.70 && draw < 0.2
                if kind == .snow { // cabins under snow, a few together or one alone, and snow-laden firs where it is sheltered
                    if village > 0.66, z >= 300, draw < [0, 0, 0, 0, 0, 0.6, 0.6, 0.55, 0.4, 0, 0][ring] {
                        stamp = Stamp.house(max(2, 4.5 * ppm), seed).recast(Self.cabin)
                    } else if z <= 500, draw < [0, 0, 0, 0, 0, 0, 0, 0.05, 0.06, 0.05, 0][ring] {
                        stamp = Stamp.house(max(2, 4.5 * ppm), seed).recast(Self.cabin)
                    } else if z <= 900, draw > 1 - min(max(0.03 + (fbm(at / 900, z / 300, 3, salt + 1) - 0.52) * 2.6, 0.02), 0.6) {
                        stamp = Stamp.fir((10 + 10 * size) * ppm).snowed
                    } else {
                        continue
                    }
                } else if kind == .desert { // a camp of tents, or a clump of scrub: a plot is short here, and the scrub thick by the line
                    if village > 0.69, z >= 180, z <= 500, draw < 0.5 {
                        stamp = .ger(3.2 * ppm)
                    } else if z <= 900, draw > 1 - [0, 0, 0, 0, 0, 0, 0.35, 0.42, 0.46, 0.5, 0.5][ring] * (0.5 + fbm(at / 900, z / 300, 3, salt + 1)) {
                        stamp = .bush((1.2 + 2.2 * size * size) * ppm, seed)
                    } else {
                        continue
                    }
                } else if spired {
                    stamp = .church(30 * ppm)
                } else if village > 0.64, z >= 300, draw < Self.housed[ring] {
                    stamp = Stamp.house(max(2, 5.0 * ppm), seed).recast(Self.chalet)
                } else if z <= 500, draw < Self.farmed[ring] {
                    stamp = Stamp.house(max(2, 5.5 * ppm), seed).recast(Self.chalet) // a farm, or a hay barn, on its own
                } else if z <= 900, draw > 1 - min(max(0.16 + (fbm(at / 900, z / 300, 3, salt + 1) - 0.45) * 2.2, 0.07), 0.7) {
                    stamp = unit(hash(c, 5, salt + 34)) < 0.25 ? .tree((8 + 7 * size) * ppm, seed) : .fir((13 + 13 * size) * ppm)
                } else {
                    continue
                }
                let left = Int((at * ppm).rounded(.toNearestOrEven)) - stamp.w / 2, entered = when(left) // (all of it goes by its left edge)
                let lift = Int(Double(swollen) * (0.35 + 0.65 * unit(hash(c, 6, salt + 35))))
                guard n >= left, n < left + stamp.w, lift + stamp.h <= rows, entered.pace <= (spired ? Self.thin : Self.broad) else { continue }
                for (y, material) in stamp.column(n - left, entered.sun).enumerated() where material != 0 {
                    let lamp = material == TrainMat.glass && z >= 180 && entered.pace <= Self.bright && unit(hash(seed + n - left, y, 55)) < 0.8
                    cells[lift + stamp.h - 1 - y] = material | (lamp ? 128 : 0)
                }
                top = max(top, lift + stamp.h)
            }
        }
        // A lane with its line of poles, where there is one.
        if z == 300, pace <= Self.thin, fbm(wx / 2400, 5, 2, 808 + kind.salt) > 0.50,
           Int(((wx / 42).rounded(.toNearestOrEven) * 42 * ppm).rounded(.toNearestOrEven)) == n {
            for up in 0..<min(7, rows) where cells[up] == 0 { cells[up] = TrainMat.pole }
            top = max(top, min(7, rows))
        }
        // Lights that show only after dark: far off, the windows of farms and huts low on the land's face; nearer, a
        // lamp in a yard.
        guard pace <= Self.bright else { return UInt8(top) }
        // (How many far off and nearer, and how high up the land: fewest in the desert.)
        let (far, near, reach) = kind == .snow ? (0.7, 0.2, 1e9) : kind == .desert ? (0.45, 0.14, 1e9) : (1.0, 0.3, 620.0)
        if z >= 1800, z <= 7000 {
            if unit(hash(n, 1, salt + 65)) < 0.06 * far * clip((noise(wx / 420, 6, salt + 64) - 0.5) * 4) {
                let up = Int(Double(min(swollen, Int(reach * ppm))) * unit(hash(n, 2, salt + 66)))
                if up < rows { (cells[up], top) = (cells[up] | 128, max(top, up + 1)) }
            }
        } else if z >= 180, z <= 900 {
            for c in here - 1...here + 1 where Int(((Double(c) + unit(hash(c, 8, salt + 37))) * plot * ppm).rounded(.toNearestOrEven)) == n {
                let up = swollen + Int(((4.0 + 3.0 * unit(hash(c, 9, salt + 38))) * ppm).rounded(.toNearestOrEven))
                if unit(hash(c, 7, salt + 36)) < near, up < rows { (cells[up], top) = (cells[up] | 128, max(top, up + 1)) }
            }
        }
        return UInt8(top)
    }

    /// For each ring, how long a plot of desert is: short by the line, where scrub stands in clumps.
    static let desertPlot: [Double] = [0, 0, 0, 700, 420, 260, 60, 40, 26, 18, 13]
    /// For each ring, how long a plot of a city's ground is, and how tall the tallest thing on it, in metres.
    static let cityPlot: [Double] = [0, 0, 200, 120, 90, 70, 90, 70, 32, 21, 18], towers: [Double] = [0, 0, 420, 450, 380, 250, 95, 48, 15, 10, 7]

    /// Lays column `n` of a ring in a city, the line at grade through it. From 15 to 3.5 km off, towers where the
    /// city's centre is, a red light on the tallest; to 500 m, slabs and blocks of every size with sky between them;
    /// nearer, houses, low works and street trees. Concrete, brick and glass, each building with its own share of
    /// windows lit after dark, warm in homes and white in glass. Street lamps stand every 40 to 70 m from 900 m in,
    /// on posts from 300 m in. And far off the city's streets are a seam of lights along its foot. Toward where
    /// another country begins the buildings are lower.
    private func cityColumn(_ ring: Int, _ n: Int, into cells: UnsafeMutablePointer<UInt8>, by laid: [Laying]) -> UInt8 {
        let kind = TrainCountry.city, z = Self.rings[ring], ppm = focal / z, wx = Double(n) / ppm, salt = UInt64(z) + kind.salt, rows = rows(ring)
        guard z >= Self.farShore || z <= shore(wx) else { return 0 } // out in a lake
        func when(_ n: Int) -> (pace: Double, sun: Int) {
            let by = laid.last { $0.from <= n } ?? laid.first
            return (ppm * (by?.speed ?? speed), by?.sun ?? sun)
        }
        let pace = when(n).pace, plot = Self.cityPlot[ring], here = Int((wx / plot).rounded(.down))
        var top = 0
        for c in here - 2...here + 2 {
            let draw = unit(hash(c, 1, salt + 30)), at = (Double(c) + unit(hash(c, 2, salt + 31))) * plot, place = country(at)
            guard z >= Self.farShore || z <= shore(at), place.kind == kind, place.edge > 60 else { continue }
            let seed = Int(hash(c, 3, salt + 32) % (1 << 30)), size = unit(hash(c, 4, salt + 33)), wide = unit(hash(c, 6, salt + 35))
            let centre = clip((fbm(at / 5000, 7, 2, 5152) - 0.42) * 5), style = Int(unit(hash(c, 5, salt + 34)) * 3)
            let high = Self.towers[ring] * (0.30 + 0.70 * size * size) * place.relief(z)
            let low = z == 110 ? 0.6 : 1.0 // by the line stand only low things, sheds and garden trees: the city's lights show over them
            let stamp: Stamp, built: Bool // (a building's columns carry their own lit windows; a house's glass lights as farmland's does)
            if z >= 3500 {
                guard draw < 0.10 + 0.80 * centre else { continue }
                let tall = high * (0.45 + 0.55 * centre)
                (stamp, built) = (.block((26 + 30 * wide) * ppm, tall * ppm, seed, floor: 2, style: style == 1 ? 0 : style, light: tall > 120), true)
            } else if z >= 500 {
                guard draw < 0.78 else { continue }
                let tall = high * (0.55 + 0.45 * centre)
                (stamp, built) = (.block(plot * (0.40 + 0.75 * wide) * ppm, tall * ppm, seed, floor: 3.2 * ppm, style: style, light: tall > 90), true)
            } else if draw < 0.40 {
                (stamp, built) = (.house(max(2, (5.0 + 2.5 * size) * low * ppm), seed), false)
            } else if draw < 0.64 {
                (stamp, built) = (.block(plot * (0.7 + 0.6 * wide) * ppm, max(3, (4.5 + high * 0.8) * low * ppm), seed, floor: 3.2 * ppm, style: style % 2, light: false), true)
            } else if draw < 0.80 {
                (stamp, built) = (.tree((7 + 7 * size) * low * ppm, seed), false)
            } else {
                continue
            }
            let left = Int((at * ppm).rounded(.toNearestOrEven)) - stamp.w / 2, entered = when(left)
            guard n >= left, n < left + stamp.w, stamp.h <= rows, entered.pace <= Self.broad else { continue }
            let lights = z >= 180 && entered.pace <= Self.bright
            for (y, cell) in stamp.column(n - left, entered.sun).enumerated() where cell != 0 {
                let lamp = lights && (built ? cell > 127 : cell == TrainMat.glass && unit(hash(seed + n - left, y, 55)) < 0.8)
                cells[stamp.h - 1 - y] = cell & 127 | (lamp ? 128 : 0)
            }
            top = max(top, stamp.h)
        }
        // Street lamps, a sodium light 8.5 m up; on posts where they are near enough for one to show.
        if z >= 180, z <= 900, pace <= Self.thin {
            let gap = [70.0, 55, 45, 40][ring - 6], tall = Int((8.5 * ppm).rounded(.toNearestOrEven))
            if Int(((wx / gap).rounded(.toNearestOrEven) * gap * ppm).rounded(.toNearestOrEven)) == n, tall < rows, cells[tall] == 0 { // (one behind a building doesn't show)
                if z <= 300 { for up in 0..<tall where cells[up] == 0 { cells[up] = TrainMat.pole } }
                (cells[tall], top) = (TrainMat.lampSodium | (pace <= Self.bright ? 128 : 0), max(top, tall + 1))
            }
        }
        // The far city's streets and windows, seen edge-on: a seam of lights along its foot, most of them sodium.
        if z >= 1800, pace <= Self.bright {
            let dense = clip((fbm(wx / 9000, 3, 2, 5151) - 0.25) * 3.5)
            for (row, share) in [(0, 0.42), (1, 0.20), (2, 0.07)] where cells[row] == 0 && unit(hash(n, row, salt + 65)) < share * dense {
                let tint = unit(hash(n, row, salt + 66))
                cells[row] = (tint < 0.45 ? TrainMat.lampSodium : tint < 0.62 ? TrainMat.lampWhite : tint < 0.66 ? TrainMat.lampGreen : tint < 0.69 ? TrainMat.lampRed : 0) | 128
                top = max(top, row + 1)
            }
        }
        // Across a lake the city stands on a shore of its own, to within 60 m of where another country begins. And
        // for a kilometre beyond each end of the lake: from the train the far side is seen across the lake's corner
        // for some way past where the lake itself has ended.
        if z == Self.farShore, stands(wx, in: kind), stride(from: -1000.0, through: 1000, by: 250).contains(where: { shore(wx + $0) < .infinity }) {
            top = max(top, waterfront(n, into: cells, rows: rows, salt: salt, when: when))
        }
        return UInt8(top)
    }

    /// How many rows of a city's shore across a lake are embankment: a dark foot at the water, and a pale cap.
    static let embankment = 2

    /// Lays a city's shore across a lake over the bottom rows of column `n` of its nearest ring, in front of the feet
    /// of everything that stands there, so that the city stands on land and not in the water: an embankment, a dark
    /// foot at the water under a pale cap; on it, trees all along, a ragged line 14 to 34 m high in a park and half
    /// that behind a wharf's sheds (parks and wharves take turns, a kilometre or so of each); a wharf's sheds, and a
    /// crane here and there; boats moored along the wall where there is a marina, a white hull on the water and a
    /// mast; and the quay's lamps, along its cap and fewer in the two rows over it, which are the far shore's seam
    /// of lights after dark. Returns how many of the strip's rows it uses.
    private func waterfront(_ n: Int, into cells: UnsafeMutablePointer<UInt8>, rows: Int, salt: UInt64, when: (Int) -> (pace: Double, sun: Int)) -> Int {
        let ppm = focal / Self.farShore, wx = Double(n) / ppm, wall = Self.embankment, lights: UInt8 = when(n).pace <= Self.bright ? 128 : 0
        guard rows > wall + 1 else { return 0 }
        for up in 0..<wall { cells[up] = up == wall - 1 ? TrainMat.quay : TrainMat.quayShade }
        var top = wall
        func put(_ up: Int, _ cell: UInt8) { if up < rows { (cells[up], top) = (cell, max(top, up + 1)) } }
        let wharf = fbm(wx / 1100, 9, 2, salt + 80)
        let tall = Int(((14 + 20 * fbm(wx / 45, 1, 3, salt + 82)) * ppm * (0.55 + 0.45 * clip((0.56 - wharf) * 7))).rounded(.toNearestOrEven))
        for up in wall..<wall + tall {
            let crown = up == wall + tall - 1 && unit(hash(n >> 1, 0, salt + 83)) < 0.5
            put(up, crown || unit(hash(n >> 1, up, salt + 83)) < 0.2 ? TrainMat.leaf1 : TrainMat.leaf0)
        }
        let plot = 60.0, here = Int((wx / plot).rounded(.down))
        for c in here - 3...here + 3 {
            let draw = unit(hash(c, 1, salt + 84)), at = (Double(c) + unit(hash(c, 2, salt + 85))) * plot, busy = fbm(at / 1100, 9, 2, salt + 80)
            let seed = Int(hash(c, 3, salt + 86) % (1 << 30)), wide = unit(hash(c, 4, salt + 87)), high = unit(hash(c, 5, salt + 88))
            let stamp: Stamp
            guard stands(at, in: .city) else { continue }
            if busy > 0.50, draw < 0.55 {
                stamp = .shed((30 + 60 * wide) * ppm, (14 + 12 * high) * ppm + 1, seed)
            } else if busy > 0.54, draw > 0.92 {
                stamp = .crane((44 + 26 * wide) * ppm, (22 + 14 * high) * ppm, seed)
            } else {
                continue
            }
            let left = Int((at * ppm).rounded(.toNearestOrEven)) - stamp.w / 2
            guard n >= left, n < left + stamp.w else { continue }
            for (y, cell) in stamp.column(n - left, 1).enumerated() where cell != 0 { put(wall + stamp.h - 1 - y, cell & 127 | (cell & lights)) }
        }
        let berth = 22.0, slip = Int((wx / berth).rounded(.down))
        for c in slip - 2...slip + 2 {
            let at = (Double(c) + unit(hash(c, 2, salt + 90))) * berth
            guard noise(at / 600, 4, salt + 89) > 0.60, unit(hash(c, 1, salt + 91)) < 0.7 else { continue }
            let x = Int((at * ppm).rounded(.toNearestOrEven)), mast = 2 + Int(unit(hash(c, 3, salt + 92)) * 3)
            if n == x || n == x + 1 { cells[0] = TrainMat.white }
            if n == x { for up in wall..<wall + mast { put(up, TrainMat.whiteShade) } }
        }
        if unit(hash(n, 1, salt + 65)) < 0.36 { cells[wall - 1] = (unit(hash(n, 2, salt + 66)) >= 0.7 ? TrainMat.quayWhite : TrainMat.quay) | lights }
        for (row, share) in [(wall, 0.16), (wall + 1, 0.06)] where row < rows && unit(hash(n, row + 1, salt + 65)) < share {
            if cells[row] & 127 == 0 { put(row, cells[row] & 128 | (unit(hash(n, row + 2, salt + 66)) < 0.6 ? TrainMat.lampSodium : TrainMat.lampWhite)) }
            if cells[row] & 127 != TrainMat.whiteShade { cells[row] |= lights }
        }
        return top
    }

    /// A cabin is farmland's house in red or tarred timber under a snowed roof.
    private static let cabin = [TrainMat.white: TrainMat.falu, TrainMat.whiteShade: TrainMat.faluShade, TrainMat.stone: TrainMat.falu,
                                TrainMat.stoneShade: TrainMat.faluShade, TrainMat.brick: TrainMat.chalet, TrainMat.brickShade: TrainMat.chaletShade,
                                TrainMat.roof: TrainMat.snow, TrainMat.roofShade: TrainMat.snowShade, TrainMat.slate: TrainMat.snow, TrainMat.slateShade: TrainMat.snowShade]
    /// A chalet is farmland's house in dark timber under grey shingles.
    private static let chalet = [TrainMat.brick: TrainMat.chalet, TrainMat.brickShade: TrainMat.chaletShade,
                                 TrainMat.roof: TrainMat.slate, TrainMat.roofShade: TrainMat.slateShade]
}

extension Stamp {
    /// A waterfront shed or warehouse `wide` by `high` pixels: a dark wall under a pale roof, with a row of windows
    /// if it is tall enough to have one, three in five of them lit after dark (a cell's top bit).
    static func shed(_ wide: Double, _ high: Double, _ seed: Int) -> Stamp {
        let w = max(3, Int(wide)), h = max(2, Int(high))
        let (wall, roof) = [(TrainMat.brickShade, TrainMat.whiteShade), (TrainMat.concreteShade, TrainMat.stone), (TrainMat.chaletShade, TrainMat.slate),
                            (TrainMat.concreteShade, TrainMat.whiteShade)][Int(unit(hash(seed, 2, 21)) * 4)]
        return Stamp(w: w, h: h) { x, _ in
            var column = [UInt8](repeating: wall, count: h)
            column[0] = roof
            if h >= 3, x >= 1, x < w - 1, (x - 1) % 3 == 0 { column[1] = TrainMat.glass | (unit(hash(seed + x, 1, 55)) < 0.6 ? 128 : 0) }
            return column
        }
    }

    /// A dockside crane `high` pixels tall: a mast with a jib `reach` pixels out to one side at its top, its hook
    /// hanging from the end, and a stub the other way; and a red light over it.
    static func crane(_ high: Double, _ reach: Double, _ seed: Int) -> Stamp {
        let h = max(4, Int(high)), out = max(2, Int(reach)), left = unit(hash(seed, 3, 22)) < 0.5, mast = left ? out : 1
        return Stamp(w: out + 2, h: h + 1) { x, _ in
            var column = [UInt8](repeating: x == mast ? TrainMat.pole : 0, count: h + 1)
            (column[0], column[1]) = (x == mast ? TrainMat.lampRed | 128 : 0, TrainMat.pole)
            if x == (left ? 0 : out + 1) { column[2] = TrainMat.pole }
            return column
        }
    }

    /// A city building `wide` by `high` pixels with a storey every `floor` of them: concrete, brick or glass by its
    /// `style`, one end in shade, a darker edge to its roof, and its windows in rows. A cell's top bit marks a window
    /// that is lit after dark: each building has its own share of them. With a `light` it is a row taller, for the
    /// red light above its roof.
    static func block(_ wide: Double, _ high: Double, _ seed: Int, floor: Double, style: Int, light: Bool) -> Stamp {
        let (wall, shade, window) = [(TrainMat.concrete, TrainMat.concreteShade, TrainMat.glass), (TrainMat.brick, TrainMat.brickShade, TrainMat.glass),
                                     (TrainMat.tower, TrainMat.towerShade, TrainMat.glassCool)][style]
        let w = max(1, Int(wide)), h = max(2, Int(high)), side = w >= 4 ? max(1, w / 4) : 0, above = light ? 1 : 0
        let pitch = max(2, Int(floor.rounded(.toNearestOrEven))), tall = pitch < 4 ? 1 : 2 // a window's height
        let share = 0.10 + 0.55 * unit(hash(seed, 8, 27)) * unit(hash(seed, 9, 28)) // how much of the building is up
        return Stamp(w: w, h: h + above) { x, sun in
            var column = [UInt8](repeating: 0, count: h + above)
            let shaded = side > 0 && (sun > 0 ? x < side : x >= w - side)
            for y in 0..<h { column[above + y] = y == 0 || shaded ? shade : wall }
            if w < 3 || (x % 2 == 1 && x < w - 1) {
                for y in stride(from: h > 3 ? 2 : 1, to: h - tall, by: pitch) {
                    let lit: UInt8 = unit(hash(seed + x, y, 55)) < share ? 128 : 0
                    for k in 0..<tall { column[above + y + k] = window | lit }
                }
            }
            if light, x == w / 2 { column[0] = TrainMat.lampRed | 128 }
            return column
        }
    }

    /// A clump of desert scrub `tall` pixels high and about twice as wide: a low ragged mound, lit on top and on the
    /// Sun's side.
    static func bush(_ tall: Double, _ seed: Int) -> Stamp {
        let h = max(1, Int(tall)), w = max(2, Int((Double(h) * (1.5 + 0.9 * unit(hash(seed, 1, 5)))).rounded(.toNearestOrEven))), cx = Double(w - 1) / 2
        return Stamp(w: w, h: h) { x, sun in
            (0..<h).map { y in
                let down = (Double(y) - Double(h - 1)) / (Double(h) + 0.3), across = (Double(x) - cx) / (Double(w) / 2 + 0.3)
                guard down * down + across * across < 0.78 + 0.34 * unit(hash(x + seed * 7, y, 11)) else { return 0 }
                let lit = (Double(x) - cx) * Double(sun) / (Double(w) / 2) * 0.8 - (Double(y) - Double(h - 1) / 2) / (Double(h) / 2 + 0.5) * 0.8
                    + (unit(hash(x, y + seed, 13)) - 0.5) * 0.6
                return lit > 0.1 ? TrainMat.scrub : TrainMat.scrubShade
            }
        }
    }

    /// A herder's round felt tent `tall` pixels high: a low white dome, shaded on the side away from the Sun, with a
    /// door toward it that glows after dark.
    static func ger(_ tall: Double) -> Stamp {
        let h = max(2, Int(tall)), w = max(4, Int((Double(h) * 2.1).rounded(.toNearestOrEven))), cx = Double(w - 1) / 2
        return Stamp(w: w, h: h) { x, sun in
            var column = (0..<h).map { y -> UInt8 in
                let down = (Double(y) - Double(h - 1)) / (Double(h) + 0.2), across = (Double(x) - cx) / (Double(w) / 2 + 0.2)
                guard down * down + across * across < 1 else { return 0 }
                return (Double(x) - cx) * Double(sun) > -Double(w) / 5 ? TrainMat.white : TrainMat.whiteShade
            }
            if x == Int(cx) + (sun > 0 ? 1 : 0) { for y in h - 1 - (h > 2 ? 1 : 0)..<h { column[y] = TrainMat.glass } }
            return column
        }
    }

    /// A fir with snow lying on its boughs: on its lit side all but every third row, and its tip.
    var snowed: Stamp {
        Stamp(w: w, h: h) { x, sun in
            column(x, sun).enumerated().map { y, cell in cell != 0 && (y < 2 || (cell == TrainMat.fir1 && y % 3 != 2)) ? TrainMat.snow : cell }
        }
    }

    /// The same stamp with some of its materials changed for others.
    func recast(_ others: [UInt8: UInt8]) -> Stamp { Stamp(w: w, h: h) { x, sun in column(x, sun).map { others[$0] ?? $0 } } }
}

// The country's own arithmetic, as in PixelTrain.swift, where each is private: the mock-ups', in doubles.

@inline(__always) private func clip(_ v: Double) -> Double { min(max(v, 0), 1) }

@inline(__always) private func hash(_ x: Int, _ z: Int, _ salt: UInt64) -> UInt64 {
    var v = UInt64(bitPattern: Int64(x)) &* 0x9E37_79B9_7F4A_7C15 ^ UInt64(bitPattern: Int64(z)) &* 0xC2B2_AE3D_27D4_EB4F ^ salt &* 0x1656_67B1_9E37_79F9
    v = (v ^ (v >> 31)) &* 0xBF58_476D_1CE4_E5B9
    v = (v ^ (v >> 29)) &* 0x94D0_49BB_1331_11EB
    return v ^ (v >> 32)
}

@inline(__always) private func unit(_ v: UInt64) -> Double { Double(v >> 40) / 16_777_216 }

private func noise(_ x: Double, _ z: Double, _ salt: UInt64) -> Double {
    let (fx, fz) = (x.rounded(.down), z.rounded(.down)), (ix, iz) = (Int(fx), Int(fz))
    var (u, v) = (x - fx, z - fz)
    (u, v) = (u * u * (3 - 2 * u), v * v * (3 - 2 * v))
    let a = unit(hash(ix, iz, salt)), b = unit(hash(ix + 1, iz, salt)), c = unit(hash(ix, iz + 1, salt)), d = unit(hash(ix + 1, iz + 1, salt))
    return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v
}

/// Layers of noise, each half the size and half the strength of the last, 0 to 1; `folded` at its middle, it comes
/// to sharp crests.
private func layered(_ x: Double, _ z: Double, _ layers: Int, _ salt: UInt64, folded: Bool) -> Double {
    var (sum, strength, x, z) = (0.0, 0.5, x, z)
    for layer in 0..<layers {
        let value = noise(x, z, salt &+ UInt64(layer) &* 101)
        sum += strength * (folded ? 1 - abs(2 * value - 1) : value)
        (strength, x, z) = (strength / 2, x * 2.03, z * 2.03)
    }
    return sum / (1 - strength * 2)
}

private func fbm(_ x: Double, _ z: Double, _ layers: Int, _ salt: UInt64) -> Double { layered(x, z, layers, salt, folded: false) }
private func ridged(_ x: Double, _ z: Double, _ layers: Int, _ salt: UInt64) -> Double { layered(x, z, layers, salt, folded: true) }
