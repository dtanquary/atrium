import Foundation

/// The kinds of country the train's line runs through. Farmland is `TrainWorld`'s own (PixelTrain.swift); the others
/// are laid here, each the mock-ups' painter line for line (docs/pixel-window-seat/train_scenery.py), as farmland is
/// train.py's, so that what they lay can be checked against the sheet Dave picked from byte for byte.
enum TrainCountry {
    case farmland, mountains, city, snow

    /// What sets one country's hashes apart from another's, as in the mock-ups.
    var salt: UInt64 { [.farmland: 0, .mountains: 100_000, .snow: 200_000, .city: 400_000][self]! }

    /// How far off things have faded most of the way to the horizon's colour, in metres: mountain air is clear,
    /// and a city's is not.
    var haze: Double { [.farmland: TrainWorld.haze, .mountains: 60_000, .snow: 40_000, .city: 16_000][self]! }

    /// For each ring, how high the land can stand above the track, in metres (farmland's are `TrainWorld.rise`,
    /// and a city is level). The mountains' are the Alps' at their steepest, held all along the line.
    /// Snow's are the fells of a high plateau, twice life size.
    var peaks: [Double] {
        self == .mountains ? [4800, 4500, 4200, 2600, 450, 130, 30, 9, 0, 0, 0] : self == .snow ? [2600, 2400, 2200, 1300, 300, 80, 26, 9, 0, 0, 0]
            : [Double](repeating: 0, count: 11)
    }

    /// What its rows of ground are made of. Mountains: alpine meadows, and a milky river with its gravel bank where
    /// farmland has a lane. A city: roofs and yards far off; nearer, the railway's own ground, ballast with the next
    /// lines' rails as level lines 19 to 34 m out and a brick wall where the lane was.
    /// Snow: a snowfield, drifted and wind-scoured, with frozen tarns far off, a ploughed road where the lane was and a
    /// snow fence 38 m out.
    var ground: TrainGround { [.farmland: Self.farm, .mountains: Self.valley, .city: Self.yards, .snow: Self.snowfield][self]! }
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
    static let passing: [TrainCountry] = [.mountains, .city, .snow]

    /// Where a place along the line lies. Held on a scenery by Settings, the line is all one country. Left to
    /// change, it is cut into stretches at uneven places: every other one is farmland, and each between draws its
    /// country, so the line always comes back to farmland and no country runs on into another of its kind.
    func country(_ wx: Double) -> TrainPlace {
        guard scenery == 0 else { return TrainPlace(kind: [3: .mountains, 4: .city, 5: .snow][scenery] ?? .farmland, edge: .infinity) }
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
    /// farmland's where two meet.
    func haze(_ wx: Double) -> Double {
        let place = country(wx)
        return Self.haze + (place.kind.haze - Self.haze) * place.relief(0)
    }

    /// How many rows a ring's strip needs for the tallest thing any other country stands there.
    func otherRows(_ ring: Int) -> Int {
        let ppm = perMetre(ring)
        let tallest = max(TrainCountry.mountains.peaks[ring], TrainCountry.snow.peaks[ring])
        return max(Int((34 * ppm).rounded(.up)) + 4 + Int((tallest * ppm).rounded(.up)), Int((max(Self.towers[ring], 17) * ppm).rounded(.up)) + 4)
    }

    /// How high a country's land stands above the track `wx` metres along, on a ring, in metres. Mountains: from
    /// 3.5 km out, sharp crests cut by side valleys, where the ranges behind show through; nearer, the valley
    /// floor's gentle swell.
    private func height(_ kind: TrainCountry, _ ring: Int, _ wx: Double, _ salt: UInt64) -> Double {
        let z = Self.rings[ring], top = kind.peaks[ring]
        guard top > 0 else { return 0 }
        if kind == .snow, z >= 7000 { // fells with a ridge to them, a crest every hundred pixels or so, in massifs
            let crest = ridged(wx / (z * 0.4), z / 9000, 4, salt), massif = clip((fbm(wx / (z * 2.0 + 8000), 3, 2, salt + 9) - 0.25) * 3)
            return top * clip(crest * 1.25 - 0.45) * (0.5 + 0.5 * massif)
        }
        if kind == .mountains, z >= 3500 {
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
        if kind == .snow {
            // A far fell is white on the flank turned to the Sun and in blue shadow on the other (by its broad shape
            // alone, so a flank is one piece), with dark rock where it is steep and in bands where the wind has bared
            // it. Nearer, snow over the swells, shadowed where they fall away, with rock and dwarf birch showing.
            let wide = z * 0.4, sunward = Double(when(n).sun)
            let lee = z >= 7000 && (ridged(Double(n + 4) / ppm / wide, z / 9000, 1, salt) - ridged(Double(n - 4) / ppm / wide, z / 9000, 1, salt)) * sunward < 0
            for up in 0..<face {
                let crust = fbm(wx / (z * 0.2 + 150), Double(up) / ppm / (z * 0.012 + 6), 3, salt + 62)
                if z >= 7000 {
                    let steep = abs(slope) >= 5 && unit(hash(n >> 1, up, salt + 6)) < 0.7 && up * 2 > swollen
                    cells[up] = steep || crust > 0.64 ? TrainMat.rockShade : lee ? TrainMat.snowShade : TrainMat.snow
                } else {
                    cells[up] = crust > 0.64 ? TrainMat.rockShade : crust < 0.31 ? TrainMat.birch : slope > -2 ? TrainMat.snow : TrainMat.snowShade
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
        if z >= 500, z <= 1800 { // fir woods along the land's top, where it is wooded: a plateau is bare but for its sheltered hollows
            let wooded = fbm(wx / 900, z / 300, 3, salt + 1), share = kind == .snow ? clip((wooded - 0.50 - 0.08) * 14) : clip((wooded - 0.50) * 9)
            let tall = Int(((10 + 14 * fbm(wx / 60, 1, 3, salt + 2)) * ppm * share * relief).rounded(.toNearestOrEven))
            top = min(face + tall, rows)
            for up in face..<top {
                cells[up] = kind == .snow ? (up < face + tall - 1 ? TrainMat.fir0 : TrainMat.snow) : unit(hash(n >> 1, up, salt + 3)) >= 0.35 ? TrainMat.fir0 : TrainMat.fir1
            }
        }
        guard z <= 7000 else { return UInt8(top) } // (the ranges beyond have no plots, and nothing lit)
        let plot = Self.plot[ring], here = Int((wx / plot).rounded(.down))
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
        let (far, near, reach) = kind == .snow ? (0.7, 0.2, 1e9) : (1.0, 0.3, 620.0) // how many far off and nearer, and how high up the land
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
        return UInt8(top)
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
