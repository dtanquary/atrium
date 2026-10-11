import Foundation

/// The kinds of country the train's line runs through. Farmland is `TrainWorld`'s own (PixelTrain.swift); the others
/// are laid here, each the mock-ups' painter line for line (docs/pixel-window-seat/train_scenery.py), as farmland is
/// train.py's, so that what they lay can be checked against the sheet Dave picked from byte for byte.
enum TrainCountry {
    case farmland, mountains

    /// What sets one country's hashes apart from another's, as in the mock-ups.
    var salt: UInt64 { self == .farmland ? 0 : 100_000 }

    /// How far off things have faded most of the way to the horizon's colour, in metres: mountain air is clear.
    var haze: Double { self == .farmland ? TrainWorld.haze : 60_000 }

    /// For each ring, how high the land can stand above the track, in metres (farmland's are `TrainWorld.rise`).
    /// The mountains' are the Alps' at their steepest, held all along the line.
    var peaks: [Double] { self == .farmland ? [] : [4800, 4500, 4200, 2600, 450, 130, 30, 9, 0, 0, 0] }

    /// What its rows of ground are made of. Mountains: alpine meadows, and a milky river with its gravel bank where
    /// farmland has a lane.
    var ground: TrainGround { self == .farmland ? Self.farm : Self.valley }
    private static let farm = TrainGround(fields: TrainWorld.fields, hedge: TrainMat.hedge, lines: (TrainMat.hedge, TrainMat.hedgeLit, TrainMat.road),
                                          far: (TrainMat.ley, TrainMat.wheat), near: (TrainMat.pasture, TrainMat.crop), verge: TrainMat.verge, salt: 0)
    private static let valley = TrainGround(fields: [TrainMat.alp, TrainMat.pasture, TrainMat.alp, TrainMat.ley, TrainMat.alp, TrainMat.pasture,
                                                     TrainMat.stubble, TrainMat.alp, TrainMat.ley, TrainMat.pasture],
                                            hedge: TrainMat.hedge, lines: (TrainMat.rock, TrainMat.river, TrainMat.river),
                                            far: (TrainMat.alp, TrainMat.pasture), near: (TrainMat.pasture, TrainMat.alp), verge: TrainMat.verge, salt: 100_000)
}

/// What a country's rows of ground are made of: the crops of its far fields and what divides them, if anything; its
/// level lines, which stay still as the train goes (the three rows just beyond `TrainWorld.lane`, far to near, and
/// `rail` on the rows `rails` metres off); the near field's two crops beyond the lane and its two this side of it;
/// and the railway's own verge. `salt` sets its draws apart from another country's.
struct TrainGround {
    let fields: [UInt8], hedge: UInt8?, lines: (UInt8, UInt8, UInt8), far: (UInt8, UInt8), near: (UInt8, UInt8), verge: UInt8
    var rails: [Double] = [], rail = TrainMat.rail
    let salt: UInt64
}

/// A place along the line: the country it lies in, and how many metres it is from where another begins (for ever,
/// while Settings holds the line to one scenery).
struct TrainPlace {
    let kind: TrainCountry, edge: Double

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
    static let passing: [TrainCountry] = [.mountains]

    /// Where a place along the line lies. Held on a scenery by Settings, the line is all one country. Left to
    /// change, it is cut into stretches at uneven places: every other one is farmland, and each between draws its
    /// country, so the line always comes back to farmland and no country runs on into another of its kind.
    func country(_ wx: Double) -> TrainPlace {
        guard scenery == 0 else { return TrainPlace(kind: scenery == 3 ? .mountains : .farmland, edge: .infinity) }
        func begins(_ k: Int) -> Double { (Double(k) + 0.2 + 0.6 * unit(hash(k, 0, 7171))) * Self.stretch }
        let near = Int((wx / Self.stretch).rounded(.down)), k = wx >= begins(near) ? near : near - 1
        let kind = k & 1 == 0 ? TrainCountry.farmland : Self.passing[Int(unit(hash(k, 1, 7171)) * Double(Self.passing.count))]
        return TrainPlace(kind: kind, edge: min(wx - begins(k), begins(k + 1) - wx))
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
        return Int((34 * ppm).rounded(.up)) + 4 + Int((TrainCountry.mountains.peaks[ring] * ppm).rounded(.up))
    }

    /// How high a country's land stands above the track `wx` metres along, on a ring, in metres. Mountains: from
    /// 3.5 km out, sharp crests cut by side valleys, where the ranges behind show through; nearer, the valley
    /// floor's gentle swell.
    private func height(_ kind: TrainCountry, _ ring: Int, _ wx: Double, _ salt: UInt64) -> Double {
        let z = Self.rings[ring], top = kind.peaks[ring]
        guard top > 0 else { return 0 }
        if z >= 3500 {
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
        if z >= 3500 {
            let snowline = [2300.0, 2100, 1900, 1500, 99999][ring], shade = clip(-slope / 4), sunny = clip(0.30 + slope * 0.06)
            for up in 0..<face {
                let alt = Double(up) / ppm, lit = unit(hash(n, up, salt + 6)) >= shade, draw = unit(hash(n, up, salt + 7)) - 0.5
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
        if z >= 500, z <= 1800 { // fir woods along the land's top, where the valley is wooded
            let wooded = fbm(wx / 900, z / 300, 3, salt + 1)
            let tall = Int(((10 + 14 * fbm(wx / 60, 1, 3, salt + 2)) * ppm * clip((wooded - 0.50) * 9) * relief).rounded(.toNearestOrEven))
            top = min(face + tall, rows)
            for up in face..<top { cells[up] = unit(hash(n, up, salt + 3)) >= 0.35 ? TrainMat.fir0 : TrainMat.fir1 }
        }
        guard z <= 7000 else { return UInt8(top) } // (the ranges beyond have no plots, and nothing lit)
        let plot = Self.plot[ring], here = Int((wx / plot).rounded(.down))
        if z <= 1800 {
            for c in here - 2...here + 2 {
                let draw = unit(hash(c, 1, salt + 30)), at = (Double(c) + unit(hash(c, 2, salt + 31))) * plot
                guard z >= Self.farShore || z <= shore(at), stands(at, in: kind) else { continue }
                let village = noise(at / 1400, 2, 4242), seed = Int(hash(c, 3, salt + 32) % (1 << 30)), size = unit(hash(c, 4, salt + 33))
                let stamp: Stamp, spired = z == 900 && village > 0.70 && draw < 0.2
                if spired {
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
        if z >= 1800, z <= 7000 {
            if unit(hash(n, 1, salt + 65)) < 0.06 * clip((noise(wx / 420, 6, salt + 64) - 0.5) * 4) {
                let up = Int(Double(min(swollen, Int(620 * ppm))) * unit(hash(n, 2, salt + 66)))
                if up < rows { (cells[up], top) = (cells[up] | 128, max(top, up + 1)) }
            }
        } else if z >= 180, z <= 900 {
            for c in here - 1...here + 1 where Int(((Double(c) + unit(hash(c, 8, salt + 37))) * plot * ppm).rounded(.toNearestOrEven)) == n {
                let up = swollen + Int(((4.0 + 3.0 * unit(hash(c, 9, salt + 38))) * ppm).rounded(.toNearestOrEven))
                if unit(hash(c, 7, salt + 36)) < 0.3, up < rows { (cells[up], top) = (cells[up] | 128, max(top, up + 1)) }
            }
        }
        return UInt8(top)
    }

    /// A chalet is farmland's house in dark timber under grey shingles.
    private static let chalet = [TrainMat.brick: TrainMat.chalet, TrainMat.brickShade: TrainMat.chaletShade,
                                 TrainMat.roof: TrainMat.slate, TrainMat.roofShade: TrainMat.slateShade]
}

extension Stamp {
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
