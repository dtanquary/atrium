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
    /// Settings' Clouds; and the weather's own cover where the sky follows the weather (`TrainWeather`), which then
    /// counts instead.
    var clouds = 0, held: Double?
    // Each row's strip, a pane wide, and the pixel of it at the pane's left edge. A cell says, for each of the
    // sixteen thresholds of the dither, whether the cloud shows there and in which tone (`cell`). Painting is most
    // of the cloud's cost, so beside each cell is what it comes to where that needs no dither (`whole`: 0 for no
    // cloud, a tone and one for cloud of one tone all through, 255 for an edge), and each row knows how many of its
    // cells have cloud in them, since a clear sky's have none.
    private var cells: [UInt32], whole: [UInt8], firsts: [Int], clouded: [Int]

    init(wide: Int, rows: Int, focal: Double, clouds: Int, held: Double? = nil) {
        (self.wide, self.rows, self.focal, self.clouds, self.held) = (wide, rows, focal, clouds, held)
        (cells, whole) = ([UInt32](repeating: 0, count: wide * rows), [UInt8](repeating: 0, count: wide * rows))
        (firsts, clouded) = ([Int](repeating: .min, count: rows), [Int](repeating: 0, count: rows))
    }

    /// How much of the sky is cloud over a spot of the layer, `wx` metres along the line and `away` out from it:
    /// Settings' Clouds, or left to change, weather 14 km across that the train runs into and out of in ten or
    /// twenty minutes, in the airliner's shares (clear a third of the way, a deck an eighth).
    func cover(_ wx: Double, _ away: Double) -> Double {
        held ?? Self.covers[clouds] ?? clip((fbm(wx / 14_000, away / 14_000, 2, 941) - 0.4) / 0.38)
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
    /// `tones`: its five for each row of sky, the lowest row's first. A cell in a far-off storm is moved toward
    /// `bolt` by how near the storm's heart it is and how brightly its rhythm is lit just now (`flashes`, one for
    /// each of the sixteen). A storm overhead lights the cloud round where it strikes, `strike.light` of the way to
    /// `bolt` at the place itself, fading out by 150 pixels to either side and 90 above and below (the layer is seen
    /// aslant), more where the cloud is thin and in steps of the dither.
    func paint(into out: UnsafeMutableBufferPointer<UInt32>, horizon: Int, tones: [UInt32], bolt: UInt32, flashes: [Float],
               strike: (x: Int, row: Int, light: Float)? = nil) {
        cells.withUnsafeBufferPointer { cells in
            whole.withUnsafeBufferPointer { whole in
                for row in 0..<rows where clouded[row] > 0 {
                    let at = (horizon + row) * wide, strip = row * wide, pattern = ((rows - 1 - row) & 3) * 4, own = row * 5
                    let struck = strike.flatMap { abs(row - $0.row) < 90 ? $0 : nil }
                    var slot = ((firsts[row] % wide) + wide) % wide
                    for x in 0..<wide {
                        let kept = whole[strip + slot]
                        if kept != 0 {
                            let cell = cells[strip + slot], k = Self.dither[pattern + (x & 3)], tone = kept == 255 ? Self.tone(cell, k) : Int(kept) - 1
                            if tone >= 0 {
                                let flash = cell >> 25 == 0 ? 0 : flashes[Int(cell >> 25 & 15)] * Float(cell >> 29)
                                var colour = flash > 0 ? blend(tones[own + tone], bolt, UInt32(min(flash * 36, 255))) : tones[own + tone]
                                if let struck {
                                    let dx = Float(x - struck.x) * 0.6, dy = Float(row - struck.row), near = 1 - (dx * dx + dy * dy).squareRoot() / 90
                                    if near > 0 {
                                        let thin = 0.7 + 0.6 * Float(cell >> 20 & 31) / 16 // (a deck's dark belly lets less through)
                                        colour = blend(colour, bolt, min(UInt32(struck.light * near * near * thin * 6 + Float(k) / 16) * 40, 230))
                                    }
                                }
                                out[at + x] = colour
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
    /// a little paler than the sky at night. A deck's belly is the edge's tone, greyed and darkened. Under weather
    /// that has put the day out by `gloom` (0 to 1) they are all darker and nearer slate, a storm's by half.
    static func tones(_ el: Float, gloom: Float = 0) -> [RGB] {
        let stops: [(Float, [RGB])] = [(-30, [rgb(20, 22, 38), rgb(28, 30, 50), rgb(40, 42, 66)]), (-15.5, [rgb(58, 54, 88), rgb(86, 74, 110), rgb(128, 100, 128)]),
                                       (-4.5, [rgb(120, 92, 122), rgb(206, 128, 112), rgb(252, 186, 132)]), (8, [rgb(168, 184, 212), rgb(206, 218, 236), rgb(244, 247, 252)])]
        let after = stops.firstIndex { $0.0 > el } ?? stops.count, a = stops[max(after - 1, 0)], b = stops[min(after, stops.count - 1)]
        let three = (0..<3).map { mix(a.1[$0], b.1[$0], a.0 == b.0 ? 0 : (el - a.0) / (b.0 - a.0)) }
        let grey = mix(three[0], RGB(repeating: (three[0].x + three[0].y + three[0].z) / 3), 0.35), five = three + [grey * 0.98, grey * 0.8]
        guard gloom > 0 else { return five }
        return five.map { tone in
            let level = (tone.x + tone.y + tone.z) / 3
            return mix(tone, RGB(0.9, 0.94, 1.04) * level, gloom * 0.7) * (1 - 0.5 * gloom * gloom)
        }
    }
}

/// The weather over the train: what the sky and the light do, whatever country lies under them. With Settings'
/// Follow the weather where you are it is the report for where you are (`LiveWeather`), while Clouds is left on
/// Changing: a cloud picked there holds the sky. Preview the weather shows each kind by hand, which is also how it
/// is tested, since the tests never fetch.
struct TrainWeather: Equatable {
    static let follow = Knob(key: "seat.weather", label: "Follow the weather where you are", range: 0...1, standard: 1, section: "Flight",
                             format: .toggle, shownWhen: "seat.orbit", shownAt: 2)
    static let preview = Knob(key: "seat.previewWeather", label: "Preview the weather", range: 0...7, standard: 0, section: "Preview",
                              format: .choice(["Off", "Clear", "Hazy", "Fog", "Overcast", "Rain", "Snow", "A thunderstorm"]),
                              shownWhen: "seat.orbit", shownAt: 2)
    /// What each pick of the preview's menu shows, from Clear on.
    static let previews = [TrainWeather(), TrainWeather(reach: 2000), TrainWeather(cover: 1, reach: 400, gloom: 0.5), TrainWeather(cover: 1, gloom: 0.4),
                           TrainWeather(cover: 1, reach: 2000, gloom: 0.7), TrainWeather(cover: 1, reach: 1000, gloom: 0.5, snow: 2.0 / 3),
                           TrainWeather(cover: 1, reach: 2000, gloom: 1, storm: true)]
    /// The reaches a report is rounded to, so that the air is one of a few kinds and changes seldom.
    static let reaches = [400.0, 1000, 2000, 4000]

    /// How much of the sky is cloud, 0 to 1 in eighths, by `TrainCloud.covers`' measure.
    var cover = 0.0
    /// How far off a thing has faded into the air, in metres, as `TrainWorld.haze` is: at that distance a third of
    /// it is left. Without end in clear air, which leaves the country's own haze as it is.
    var reach = Double.infinity
    /// How far cloud and what falls from it have put the day out, 0 to 1: the land dimmer and greyer under it, the
    /// cloud darker, and distance fading to the cloud's grey and not the sky's blue.
    var gloom = 0.0
    /// Snow falling, 0 to 1.
    var snow = 0.0
    /// A thunderstorm overhead.
    var storm = false

    /// The weather a report comes to (WMO codes: 45 and 48 fog, 51 to 67 and 80 to 82 rain, 71 to 77, 85 and 86
    /// snow, 95 and up thunder). What falls needs a deck to fall from, whatever cover came with it. The reach is
    /// the reported visibility over 3.9, since visibility is how far off a thing's contrast is down to a fiftieth
    /// (Koschmieder); from 16 km of it the air counts as clear.
    init(_ report: LiveWeather.Conditions) {
        let code = report.code, thunder = code >= 95, snowing = (71...77).contains(code) || code == 85 || code == 86
        let raining = (51...67).contains(code) || (80...82).contains(code) || thunder, foggy = code == 45 || code == 48
        cover = (max(report.cloudCover / 100, raining || snowing || foggy ? 1 : 0) * 8).rounded() / 8
        // (A report can say rain, snow or fog and still give the visibility of a clear day.)
        let seen = min(report.visibility, foggy ? 1500 : .infinity, snowing ? 5000 : .infinity, thunder ? 5000 : raining ? 12_000 : .infinity) / 3.9
        reach = seen >= 16_000 / 3.9 ? .infinity : Self.reaches.min { abs(log($0 / seen)) < abs(log($1 / seen)) }!
        let wet = min(report.rain + report.showers, 1) // (in mm a quarter hour: 1 is 4 mm an hour, a steady rain)
        gloom = thunder ? 1 : raining ? ((0.6 + 0.2 * wet) * 10).rounded() / 10 : snowing || foggy ? 0.5 : cover == 1 ? 0.4 : cover > 0.8 ? 0.2 : 0
        snow = snowing ? min(max((report.snowfall * 6).rounded(.up), 1), 3) / 3 : 0 // (in thirds, of 2 cm an hour or more)
        storm = thunder
    }

    init(cover: Double = 0, reach: Double = .infinity, gloom: Double = 0, snow: Double = 0, storm: Bool = false) {
        (self.cover, self.reach, self.gloom, self.snow, self.storm) = (cover, reach, gloom, snow, storm)
    }

    /// The weather for a scene built now: the preview's; or the report's, with the switch on, Clouds left on
    /// Changing and a report in; or none, and then the sky is Settings' Clouds alone, as it was before weather.
    @MainActor static var now: TrainWeather? {
        let pick = Int(preview.value)
        if pick > 0 { return previews[pick - 1] }
        guard follow.value > 0.5, PixelWindowSeat.clouds.value == 0, let report = LiveWeather.shared.latest else { return nil }
        return TrainWeather(report)
    }

    /// A storm overhead's lightning at scene time `t`: how brightly it lights the cloud and the land just now, 0
    /// to 1 in eighths; where it strikes, as shares of the pane's width and of its sky's height, with a number to
    /// draw its path by; and whether the stroke itself shows, which it does in three of five, the rest being light
    /// inside the cloud. One strike to every seven seconds, at its own moment in them: full for an eighth of a
    /// second, gone in under half, and in half of them once more, weaker, half a second on; then nothing for a
    /// second at least. So the whole pane never flashes more than twice in a second, inside what is safe to look
    /// at (three, WCAG 2.3.1).
    static func strike(at t: Double) -> (light: Float, across: Double, up: Double, draw: Int, forked: Bool) {
        let turn = Int(t / 7), draw = hash(turn, 0, 961), since = t - Double(turn) * 7 - unit(draw) * 5.5
        let again = since - 0.5, twice = draw & 1 == 0
        let light = since < 0 ? 0 : since < 0.12 ? 1 : since < 0.42 ? 0.7 * (0.42 - since) / 0.3
            : twice && again >= 0 && again < 0.08 ? 0.7 : twice && again >= 0.08 && again < 0.3 ? 0.5 * (0.3 - again) / 0.22 : 0
        let shows = (since >= 0 && since < 0.16) || (twice && again >= 0 && again < 0.08)
        return (Float((light * 8).rounded() / 8), 0.12 + 0.76 * unit(hash(turn, 1, 961)), 0.4 + 0.3 * unit(hash(turn, 2, 961)), turn, shows && draw >> 8 % 5 < 3)
    }

    /// The stroke of strike `draw`, from the cloud at the pane's column `x` of its sky row `top` (0 for the lowest)
    /// down to the horizon, in a pane `wide` across: each of its pixels as a column, a row and whether it is the
    /// stroke itself or its fainter branch. It comes down in short runs, each straight down or at 45 degrees to
    /// one side.
    static func stroke(_ draw: Int, from x: Int, _ top: Int, wide: Int, _ plot: (Int, Int, Bool) -> Void) {
        let fork = top * 2 / 3 - Int(hash(draw, 3, 961) % 12)
        var x = x, branch = x, lean = hash(draw, 4, 961) & 1 == 0 ? 1 : -1
        for row in stride(from: top, through: 0, by: -1) {
            x += Int(hash(row / 4, draw, 962) % 3) - 1
            if x >= 0, x < wide { plot(x, row, true) }
            if row == fork { branch = x }
            if row < fork, row > fork - 34 {
                branch += hash(row / 3, draw, 963) % 3 == 0 ? 0 : lean
                if branch >= 0, branch < wide, branch != x { plot(branch, row, false) }
            }
            if row % 16 == 0 { lean = hash(row, draw, 964) & 3 == 0 ? -lean : lean }
        }
    }
}

/// Snow falling past the train's window, in three layers of flakes. By the train's own law a flake `away` metres
/// off slides `focal × speed / away` pixels a second and sinks `focal × fall / away`: level but for one part in
/// nine at 1×, steeper as the train slows. A flake nearer than 120 m would cross too fast to follow (`TrainWorld.
/// thin`), so the nearest are there, or farther off at a speed where even that is too fast; the others are twice
/// and four times as far, smaller and slower.
///
/// How far each layer has slid and sunk is added up as the train goes, so a change of speed bends the flakes'
/// paths and moves none of them. Where a flake is comes from a hash of its place in its layer.
struct TrainSnow {
    /// How far off the three layers are at least, in metres; how big each one's plots are, in pixels, with a flake
    /// to a plot at most; and how fast snow falls, in metres a second.
    static let away = [120.0, 240, 480], plots = [20, 14, 10], fall = 1.5
    private var slid = [0.0, 0, 0], sunk = [0.0, 0, 0]

    /// Carries the flakes on by `dt` seconds of a train at `speed` metres a second, seen through a lens of `focal`.
    mutating func advance(by dt: Double, speed: Double, focal: Double) {
        for layer in 0..<3 {
            let away = Self.away[layer] * max(1, focal * speed / (TrainWorld.thin * Self.away[0]))
            (slid[layer], sunk[layer]) = (slid[layer] + dt * focal * speed / away, sunk[layer] + dt * focal * Self.fall / away)
        }
    }

    /// Each flake in a pane `wide` by `high`, snowing `heavy` (0 to 1): its column, its row from the bottom, and
    /// its layer, 0 for the nearest.
    func flakes(heavy: Double, wide: Int, high: Int, _ plot: (Int, Int, Int) -> Void) {
        for layer in 0..<3 {
            let size = Self.plots[layer], dx = Int(slid[layer]), dy = Int(sunk[layer]), share = heavy * 0.7
            for j in dy / size...(dy + high - 1) / size {
                for i in dx / size...(dx + wide - 1) / size {
                    let draw = hash(i, j, 970 + UInt64(layer))
                    guard unit(draw) < share else { continue }
                    let x = i * size + Int(draw & 255) % size - dx, y = j * size + Int(draw >> 8 & 255) % size - dy
                    if x >= 0, x < wide, y >= 0, y < high { plot(x, y, layer) }
                }
            }
        }
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
