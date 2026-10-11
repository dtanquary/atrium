import SpriteKit

/// The train's cloud (PixelTrain.swift): one layer 1.2 km up, seen from under it. Every row of the pane above the
/// horizon looks at the layer at one distance, the top rows nearly overhead and the lowest sixty kilometres off, so
/// each is a strip a pane wide that slides by whole pixels at its own slow pace, as the airliner's cloud rows do
/// seen from above. The fastest, at the top of the pane, moves under two pixels a second at 1×.
///
/// A cell is laid once, as it comes into view, from noise over the layer (the mock-ups' own, `sky` in
/// docs/pixel-window-seat/train.py): how thick the cloud is there says whether a pixel of it shows and in which of
/// its tones, by the pane's own 4 × 4 dither, so a cloud's edge is a clean dither wherever it has slid to.
struct TrainCloud {
    /// How high the layer's base is and how big its masses are, in metres, and which of the mock-ups' skies it is.
    static let base = 1200.0, scale = 2600.0, seed: UInt64 = 909
    /// Settings' Clouds as how much of the sky is cloud, 0 to 1: Clear, Scattered (the mock-ups' sky), Broken (the
    /// sky of their rain) and Overcast. The first, Changing, has none: the cover is then part of the country.
    static let covers: [Double?] = [nil, 0, 0.30, 0.62, 1]
    /// The pane's dither, as Pixel City's `bayer` has it: a pixel's threshold is this over sixteen, and a thirty-second.
    static let dither: [UInt32] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

    /// The pane's width, the rows of sky above its horizon, and the lens.
    let wide: Int, rows: Int, focal: Double
    /// Settings' Clouds.
    var clouds = 0
    // Each row's strip, a pane wide, and the pixel of it at the pane's left edge. A cell says, for each of the
    // sixteen thresholds of the dither, whether the cloud shows there and in which tone (`cell`). Painting is most
    // of the cloud's cost, so beside each cell is what it comes to where that needs no dither (`whole`: 0 for no
    // cloud, a tone and one for cloud of one tone all through, 255 for an edge), and each row knows how many of its
    // cells have cloud in them, since a clear sky's have none.
    private var cells: [UInt32], whole: [UInt8], firsts: [Int], clouded: [Int]

    init(wide: Int, rows: Int, focal: Double, clouds: Int) {
        (self.wide, self.rows, self.focal, self.clouds) = (wide, rows, focal, clouds)
        (cells, whole) = ([UInt32](repeating: 0, count: wide * rows), [UInt8](repeating: 0, count: wide * rows))
        (firsts, clouded) = ([Int](repeating: .min, count: rows), [Int](repeating: 0, count: rows))
    }

    /// How much of the sky is cloud over a spot of the layer, `wx` metres along the line and `away` out from it:
    /// Settings' Clouds, or left to change, weather 14 km across that the train runs into and out of in ten or
    /// twenty minutes, in the airliner's shares (clear a third of the way, a deck an eighth).
    func cover(_ wx: Double, _ away: Double) -> Double {
        Self.covers[clouds] ?? clip((fbm(wx / 14_000, away / 14_000, 2, 941) - 0.4) / 0.38)
    }

    /// Whether the cell at pixel `n` of the row `up` rows above the horizon is lit by a far-off thunderstorm, as
    /// seven bits: 0 if not; else how strongly (1 to 7, dithered between, so the light has no edge) above which of
    /// sixteen rhythms the storm flashes to (`SeatWorld.lightning`). One corner in four of a
    /// 20 km grid has a storm where the cloud there is thick, none nearer than 40 km. Its own cloud is down among the
    /// last rows above the horizon, behind any hill or wood, so what shows is its light on the underside of the
    /// layer: strongest over the storm, fading out 10 km to either side and beyond it, and 28 km toward us, which
    /// is a low, wide glow that reaches a sixth of the way up the sky.
    func storm(_ up: Int, _ n: Int) -> UInt32 {
        let away = Self.base * focal / Double(up), wx = Double(n) * Self.base / Double(up)
        let grid = 20_000.0, ix = Int((wx / grid).rounded()), aside = abs(wx - Double(ix) * grid) / 10_000
        let rough = (Double(Self.dither[(up & 3) * 4 + (n & 3)]) + 0.5) / 16
        var found = UInt32(0)
        for iz in max(2, Int(((away - 10_000) / grid).rounded(.up)))...max(2, Int(((away + 28_000) / grid).rounded(.down))) {
            let draw = hash(ix, iz, 957), toward = Double(iz) * grid - away, along = toward < 0 ? -toward / 10_000 : toward / 28_000
            guard draw & 3 == 0, aside < 1, along < 1, cover(Double(ix) * grid, Double(iz) * grid) > 0.5 else { continue }
            let strength = UInt32(7 * (1 - aside) * (1 - along) + rough)
            if strength > 0 { found = max(found, strength << 4 | UInt32(draw >> 8 & 15)) }
        }
        return found
    }

    /// The cloud at pixel `n` of the row `up` rows above the horizon (1 for the lowest), packed: five counts of
    /// five bits, then a storm's seven. Of the dither's sixteen thresholds, taken from the lowest: how many the
    /// cloud shows at; how many of them take the edge's tone, and how many that or the middle tone; and where the
    /// cloud is a deck's body, how many take the body's white, and how many that or the paler grey of its belly.
    func cell(_ up: Int, _ n: Int) -> UInt32 {
        let j = Double(up), away = Self.base * focal / j, wx = Double(n) * Self.base / j, cover = cover(wx, away)
        guard cover > 0 else { return 0 }
        // Cloud is where the noise passes an edge that falls as the cover rises, thickening over a little way; and
        // none stands on the horizon itself, where the hills do.
        let puff = fbm(wx / Self.scale + 40, away / Self.scale, 4, Self.seed), edge = (1 - cover) * 0.74
        let thick = clip((puff - edge) / 0.16) * clip((j - 2) / 10)
        guard thick > 0.02 else { return 0 }
        // From below, a big cloud is grey where it is deep: not at all in a scattered sky, whose clouds are the
        // mock-ups' white ones; in a broken sky at the heart of each mass; and under a deck everywhere, with none of
        // its white left once the deck is whole.
        let grey = smooth((cover - 0.35) / 0.27), whole = 0.56 * smooth((cover - 0.62) / 0.28)
        let heavy = grey * (whole + (1 - whole) * clip((puff - edge - 0.16) / 0.3))
        var (shown, edges, middles, whites, pales) = (UInt32(0), UInt32(0), UInt32(0), UInt32(0), UInt32(0))
        for k in 0..<16 {
            let d = Double(k) / 16 + 1.0 / 32
            if thick > 0.02 + d * 0.10 { shown += 1 }
            let tone = Int(min(max(thick * 2.6 + (d - 0.5) * 0.5, 0), 2.999)), belly = Int(min(max(heavy * 2.4 + (d - 0.5) * 0.5, 0), 2.999))
            (edges, middles) = (edges + (tone < 1 ? 1 : 0), middles + (tone < 2 ? 1 : 0))
            (whites, pales) = (whites + (belly < 1 ? 1 : 0), pales + (belly < 2 ? 1 : 0))
        }
        return shown | edges << 5 | middles << 10 | whites << 15 | pales << 20 | storm(up, n) << 25
    }

    /// Which of the cloud's five tones a cell shows at a pixel whose dither is `k` (0 to 15): the edge's, the
    /// middle one, the body's white, a deck's pale belly or its dark one; or -1 where the sky shows through.
    @inline(__always) static func tone(_ cell: UInt32, _ k: UInt32) -> Int {
        guard k < cell & 31 else { return -1 }
        let tone = (k >= cell >> 5 & 31 ? 1 : 0) + (k >= cell >> 10 & 31 ? 1 : 0)
        return tone < 2 ? tone : 2 + (k >= cell >> 15 & 31 ? 1 : 0) + (k >= cell >> 20 & 31 ? 1 : 0)
    }

    /// The cloud's tone at the pane's column `x` of its sky row `row` (0 for the lowest), as last slid; -1 for none.
    func tone(_ row: Int, _ x: Int) -> Int {
        let cell = cells[row * wide + ((firsts[row] + x) % wide + wide) % wide]
        return cell == 0 ? -1 : Self.tone(cell, Self.dither[((rows - 1 - row) & 3) * 4 + (x & 3)])
    }

    /// A whole row's tones at once, a pane's width of them into `tones`, for the water that mirrors the row.
    func tones(_ row: Int, into tones: UnsafeMutablePointer<Int8>) {
        guard clouded[row] > 0 else { return tones.update(repeating: -1, count: wide) }
        let strip = row * wide, pattern = ((rows - 1 - row) & 3) * 4
        var slot = ((firsts[row] % wide) + wide) % wide
        for x in 0..<wide {
            let kept = whole[strip + slot]
            tones[x] = kept == 255 ? Int8(Self.tone(cells[strip + slot], Self.dither[pattern + (x & 3)])) : Int8(kept) - 1
            slot += 1
            if slot == wide { slot = 0 }
        }
    }

    /// How much of the Sun cloud hides, 0 to 1, with the train `x` metres along and the Sun drawn at the pane's
    /// column `at.x` of its sky row `at.row`: by the place itself, not by what the strips hold, so it is the same
    /// whenever it is asked.
    func hides(_ at: (x: Int, row: Int), with x: Double) -> Double {
        var hidden = 0.0
        for (dx, dy) in [(0, 0), (-3, 0), (3, 0), (0, -3), (0, 3)] {
            let up = min(max(at.row + dy, 0), rows - 1) + 1
            hidden += Double(cell(up, Int(((x * Double(up)) / Self.base).rounded(.down)) - wide / 2 + at.x + dx) & 31) / 80
        }
        return hidden
    }

    /// Slides each row on to where the train has got to, `x` metres along, laying the cells that come into view.
    mutating func advance(to x: Double) {
        for row in 0..<rows {
            let first = Int(((x * Double(row + 1)) / Self.base).rounded(.down)) - wide / 2, old = firsts[row]
            guard first != old else { continue }
            for n in (old != .min && first > old && first - old < wide ? old + wide : first)..<first + wide {
                let at = row * wide + ((n % wide) + wide) % wide, new = cell(row + 1, n), one = Self.tone(new, 0)
                clouded[row] += (new == 0 ? 0 : 1) - (cells[at] == 0 ? 0 : 1)
                (cells[at], whole[at]) = (new, new == 0 ? 0 : one >= 0 && one == Self.tone(new, 15) ? UInt8(one + 1) : 255)
            }
            firsts[row] = first
        }
    }

    /// Paints the cloud over the sky of a picture whose horizon is on its row `horizon` (rows from the bottom), in
    /// its five `tones`. A cell in a storm is moved toward `bolt` by how near the storm's heart it is and how
    /// brightly its rhythm is lit just now (`flashes`, one for each of the sixteen).
    func paint(into out: UnsafeMutableBufferPointer<UInt32>, horizon: Int, tones: [UInt32], bolt: UInt32, flashes: [Float]) {
        cells.withUnsafeBufferPointer { cells in
            whole.withUnsafeBufferPointer { whole in
                for row in 0..<rows where clouded[row] > 0 {
                    let at = (horizon + row) * wide, strip = row * wide, pattern = ((rows - 1 - row) & 3) * 4
                    var slot = ((firsts[row] % wide) + wide) % wide
                    for x in 0..<wide {
                        let kept = whole[strip + slot]
                        if kept != 0 {
                            let cell = cells[strip + slot], tone = kept == 255 ? Self.tone(cell, Self.dither[pattern + (x & 3)]) : Int(kept) - 1
                            if tone >= 0 {
                                let flash = cell >> 25 == 0 ? 0 : flashes[Int(cell >> 25 & 15)] * Float(cell >> 29)
                                out[at + x] = flash > 0 ? blend(tones[tone], bolt, UInt32(min(flash * 36, 255))) : tones[tone]
                            }
                        }
                        slot += 1
                        if slot == wide { slot = 0 }
                    }
                }
            }
        }
    }

    /// The cloud's five tones for a Sun `el` degrees up, edge to dark belly. The first three are the mock-ups', at
    /// the four hours they were painted for: white by day, lit pink and gold from under at sunset, mauve at dusk,
    /// a little paler than the sky at night. A deck's belly is the edge's tone, greyed and darkened.
    static func tones(_ el: Float) -> [RGB] {
        let stops: [(Float, [RGB])] = [(-30, [rgb(20, 22, 38), rgb(28, 30, 50), rgb(40, 42, 66)]), (-15.5, [rgb(58, 54, 88), rgb(86, 74, 110), rgb(128, 100, 128)]),
                                       (-4.5, [rgb(120, 92, 122), rgb(206, 128, 112), rgb(252, 186, 132)]), (8, [rgb(168, 184, 212), rgb(206, 218, 236), rgb(244, 247, 252)])]
        let after = stops.firstIndex { $0.0 > el } ?? stops.count, a = stops[max(after - 1, 0)], b = stops[min(after, stops.count - 1)]
        let three = (0..<3).map { mix(a.1[$0], b.1[$0], a.0 == b.0 ? 0 : (el - a.0) / (b.0 - a.0)) }
        let grey = mix(three[0], RGB(repeating: (three[0].x + three[0].y + three[0].z) / 3), 0.35)
        return three + [grey * 0.98, grey * 0.8]
    }
}

@inline(__always) private func clip(_ v: Double) -> Double { min(max(v, 0), 1) }
@inline(__always) private func smooth(_ v: Double) -> Double { clip(v) * clip(v) * (3 - 2 * clip(v)) }

// The train's hash and noise, repeated from PixelTrain.swift, where they're private for the reason PixelCity.swift
// gives for `rgb`: the airliner and the orbit each have their own under the same names.
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

private func fbm(_ x: Double, _ z: Double, _ layers: Int, _ salt: UInt64) -> Double {
    var (sum, strength, x, z) = (0.0, 0.5, x, z)
    for layer in 0..<layers {
        sum += strength * noise(x, z, salt &+ UInt64(layer) &* 101)
        (strength, x, z) = (strength / 2, x * 2.03, z * 2.03)
    }
    return sum / (1 - strength * 2)
}

@inline(__always) private func blend(_ a: UInt32, _ b: UInt32, _ t: UInt32) -> UInt32 {
    let redBlue = ((a & 0xFF00FF) * (256 - t) + (b & 0xFF00FF) * t) >> 8 & 0xFF00FF
    return 0xFF00_0000 | redBlue | ((a & 0xFF00) * (256 - t) + (b & 0xFF00) * t) >> 8 & 0xFF00
}

private func rgb(_ r: Int, _ g: Int, _ b: Int) -> RGB { RGB(Float(r), Float(g), Float(b)) / 255 }
