import Foundation
import simd

/// The space station's Cupola, for Pixel Window Seat's Earth orbit (PixelOrbit.swift): a dome of seven windows on
/// the station's Earth-facing side, a round one with six trapezium panes round it, seen from Tranquility looking
/// straight down into it, or from inside it through a fisheye. `PixelOrbit` flies the Earth past; this is the
/// dome, worked out once for a canvas: its lens, which pixels look out, the inside's colours by day and in the
/// Earth's shadow, the bezels a low Sun glints on, and the station's hardware outside.
///
/// Everything is a shape in the dome's own axes, in metres from the round window's centre (x the way we fly, y to
/// starboard, z toward the Earth), put through the scene's lens and tested at each pixel's centre.
///
/// The windows' clear openings are ESA's (P. Deloo, "The ISS Cupola", 2009, slide 12:
/// https://esamultimedia.esa.int/docs/hsf_research/Climate_change_ISS_presentations/Cupola_Deloo.pdf). The panes'
/// lean, their distance from the axis, the recess's depth and the eye's 2.47 m are fitted to NASA's S130-E-009694
/// (https://images.nasa.gov/details/s130e009694) and are in no document. The colours and what is where are from
/// NASA's ISS038-E-013587 and ISS036-E-005944. docs/pixel-window-seat.md has the rest.
// ponytail: the dome is turned 30° from the real one's bearing so that a pane, not a bar, faces dead ahead, and the
// hardware outside stands at distances chosen to show in a pane (the doc lists what is true and what is not).
// Details an art pixel across (bolts, tags, labels, the bezel) stay that size on a canvas of any size, so on a
// portrait display, where the dome is half as big, they crowd it: scale them by the lens if that ever looks wrong.
struct PixelCupola {
    /// The round window's radius; a side pane's half short edge, half long edge, height and corner radius.
    static let round = 0.353, short = 0.200, long = 0.322, tall = 0.405, corner = 0.0324
    /// A side pane's short edge: how far from the axis and toward the Earth; and the pane's lean from the axis.
    static let edge = 0.505, edgeZ = -0.016, lean = 28.4 * Double.pi / 180
    /// How far out along its normal each opening's outer edge is, which is where the sky ends: side panes, and round.
    static let recess = 0.11, roundRecess = 0.10
    /// The warm light a low Sun puts on a bezel, and what the Earth's shadow does to the inside's colours.
    static let glint = tone(0xe9b06c), night = SIMD3(0.30, 0.35, 0.46)

    /// The view's lens over the whole canvas, and how far back from the round window the eye is.
    let lens: OrbitLens
    private let w: Int, h: Int, eye: Double

    // All by a pixel's index in the scene's picture, whose rows run from the bottom.
    /// Whether each pixel looks out through a window.
    private(set) var sky: [Bool] = []
    /// Every pixel the dome covers: its colour in sunlight and in the Earth's shadow.
    private(set) var inside: [(at: Int, day: UInt32, dark: UInt32)] = []
    /// The bezels' pixels, each with its direction from its own window's centre (to the right and up).
    private(set) var bezels: [(at: Int, x: Float, y: Float)] = []
    /// The station's hardware where it shows through a window: in the Sun, in a low Sun and in shadow.
    private(set) var hardware: [(at: Int, day: UInt32, low: UInt32, dark: UInt32)] = []

    /// The dome on a canvas `w` by `h`: seen from 2.47 m up in Tranquility through the scene's own 45° lens, or
    /// from `within` it, 0.45 m from the round window, through a fisheye that takes in a half turn. Either lens is
    /// over the canvas's shorter side, so the whole dome fits a portrait display too.
    init(w: Int, h: Int, within: Bool) {
        let side = Double(min(w, h))
        (self.w, self.h, eye) = (w, h, within ? 0.45 : 2.47)
        lens = OrbitLens(focal: within ? side / .pi : side / (2 * tan(.pi / 8)), fisheye: within, w: w, h: h)
        let painted = paint(), outside = layHardware()
        func ours(_ i: Int) -> Int { (h - 1 - i / w) * w + i % w } // the painting's rows run from the top
        sky = (0..<w * h).map { painted.sky[ours($0)] }
        for i in 0..<w * h {
            if !painted.sky[i] {
                // At night the monitor and the keypad each keep one standby light.
                let glow: UInt32? = i == painted.glows.0 ? 0x3fbf6a : i == painted.glows.1 ? 0xd9902f : nil
                inside.append((ours(i), tone(painted.art[i]), glow.map { tone($0) } ?? tone(painted.art[i], times: Self.night)))
            } else if outside.there[i] {
                // In shadow a silhouette, with a faint rim where nothing stands between it and the middle of the picture.
                let x = i % w, y = i / w, sx = 2 * x + 1 < w ? 1 : 2 * x + 1 > w ? -1 : 0, sy = 2 * y + 1 < h ? 1 : 2 * y + 1 > h ? -1 : 0
                let rim = !outside.there[min(max(y + sy, 0), h - 1) * w + min(max(x + sx, 0), w - 1)]
                hardware.append((ours(i), tone(outside.art[i]), tone(outside.art[i], times: [1, 0.80, 0.62]),
                                 rim ? tone(0x3a4458) : tone(outside.art[i], times: [0.08, 0.10, 0.15], plus: 0x10141e)))
            }
        }
        bezels = painted.bezels.map { (ours($0.at), $0.x, -$0.y) }
    }

    /// The outline of a window: 0 to 5 the side panes, pane `k` facing 60° × k to starboard of dead ahead, and 6 the
    /// round one. `depth` metres out along its normal, and grown by `grow` in its own plane.
    static func window(_ k: Int, depth: Double = 0, grow: Double = 0) -> [Sky.Vector] {
        guard k < 6 else { return circle(round + grow, roundRecess / recess * depth) }
        // A trapezium with rounded corners in its own plane: across, and from its short edge to its long one.
        let (a, b, t, rho) = (short + grow, long + grow, tall + 2 * grow, corner + grow)
        let corners: [SIMD2<Double>] = [[-a, 0], [a, 0], [b, t], [-b, t]]
        let arcs = (0..<4).map { i -> [SIMD2<Double>] in
            let q = corners[i], before = normalize(corners[(i + 3) % 4] - q), after = normalize(corners[(i + 1) % 4] - q)
            let half = acos(min(max(dot(before, after), -1), 1)) / 2, centre = q + normalize(before + after) * rho / sin(half)
            let start = q + before * rho / tan(half) - centre, end = q + after * rho / tan(half) - centre
            let from = atan2(start.y, start.x), turn = remainder(atan2(end.y, end.x) - from, 2 * .pi)
            return (0...4).map { n -> SIMD2<Double> in
                let angle = from + turn * Double(n) / 4
                return centre + SIMD2(cos(angle), sin(angle)) * rho
            }
        }
        var outline: [SIMD2<Double>] = []
        for i in 0..<4 {
            let start = arcs[i][4], end = arcs[(i + 1) % 4][0]
            outline += arcs[i] + (1..<24).map { start + (end - start) * (Double($0) / 24) }
        }
        let faces = Double(k) * .pi / 3, (c, s) = (cos(faces), sin(faces))
        let origin: Sky.Vector = [edge * c, edge * s, edgeZ], across: Sky.Vector = [-s, c, 0]
        let up: Sky.Vector = [sin(lean) * c, sin(lean) * s, -cos(lean)], out: Sky.Vector = [cos(lean) * c, cos(lean) * s, sin(lean)]
        return outline.map { p -> Sky.Vector in origin + across * p.x + up * (p.y - grow) + out * depth }
    }

    // MARK: - Shapes to pixels

    /// Where a point of the dome falls in the picture, in pixels from its top left corner, or nil where the lens
    /// cannot put it. The eye is on the dome's axis looking at the Earth, with the way we fly to its right.
    private func spot(_ p: Sky.Vector) -> SIMD2<Double>? {
        lens.place(normalize([p.x, -p.y, p.z + eye])).map { [$0.x, Double(h) - $0.y] }
    }

    /// The pixel a place in the picture is in, if it is in the picture.
    private func pixel(_ p: SIMD2<Double>) -> (x: Int, y: Int)? {
        p.x >= 0 && p.y >= 0 && p.x < Double(w) && p.y < Double(h) ? (Int(p.x), Int(p.y)) : nil
    }

    /// A run of points in the picture, or none of them if the lens cannot put one: a shape that reaches behind the
    /// 45° lens is left out whole.
    private func placed(_ points: [Sky.Vector]) -> [SIMD2<Double>] {
        let found = points.compactMap(spot)
        return found.count == points.count ? found : []
    }

    /// The pixels whose centres lie inside an outline in the picture, row by row.
    private func cover(_ outline: [SIMD2<Double>]) -> [Bool] {
        var mask = [Bool](repeating: false, count: w * h), crossings: [Double] = []
        guard outline.count > 2, let top = outline.map(\.y).min(), let foot = outline.map(\.y).max() else { return mask }
        func whole(_ v: Double, _ most: Int) -> Int { Int(max(0, min(Double(most), v))) }
        let first = whole(top.rounded(.down), h)
        for y in first..<max(first, whole(foot.rounded(.up), h)) {
            let level = Double(y) + 0.5
            crossings.removeAll(keepingCapacity: true)
            for i in outline.indices {
                let a = outline[i], b = outline[(i + 1) % outline.count]
                if (a.y > level) != (b.y > level) { crossings.append((b.x - a.x) * (level - a.y) / (b.y - a.y + 1e-12) + a.x) }
            }
            crossings.sort()
            for pair in stride(from: 0, to: crossings.count - 1, by: 2) {
                let from = whole((crossings[pair] - 0.5).rounded(.up), w)
                for x in from..<max(from, whole((crossings[pair + 1] - 0.5).rounded(.up), w)) { mask[y * w + x] = true }
            }
        }
        return mask
    }

    /// The pixels inside a shape of the dome, given as its outline.
    private func fill(_ outline: [Sky.Vector]) -> [Bool] { cover(placed(outline)) }

    /// The pixels along a line through the dome, in order: four to a pixel of its length, or one every `step` pixels.
    private func trace(_ path: [Sky.Vector], step: Double = 0.25) -> [(x: Int, y: Int)] {
        let q = placed(path)
        var found: [(x: Int, y: Int)] = [], run = 0.0, n = 0.0
        for i in q.indices.dropLast() {
            let length = simd.length(q[i + 1] - q[i])
            while n * step < run + length {
                if let at = pixel(q[i] + (q[i + 1] - q[i]) * ((n * step - run) / length)) { found.append(at) }
                n += 1
            }
            run += length
        }
        return found
    }

    /// A mask with every pixel's four neighbours added, `times` over.
    private func grow(_ mask: [Bool], _ times: Int = 1) -> [Bool] {
        var mask = mask
        for _ in 0..<times {
            let was = mask
            for i in was.indices where was[i] {
                if i % w > 0 { mask[i - 1] = true }
                if i % w < w - 1 { mask[i + 1] = true }
                if i >= w { mask[i - w] = true }
                if i < was.count - w { mask[i + w] = true }
            }
        }
        return mask
    }

    /// A mask less the pixels along its edge.
    private func shrink(_ mask: [Bool]) -> [Bool] { grow(mask.map { !$0 }).map { !$0 } }

    // MARK: - The inside

    /// Paints the inside of the dome as it is by day, rows from the top, in 0xRRGGBB: the black plate with its bolts
    /// round seven windows, each in its ridged recess with a copper line and a silver bezel; a blue handle on every
    /// bar, two tan bags, tags and labels; round the base the long blue rail, the monitor, the keypad, the hand
    /// controller, a crew patch and two hoses; and beyond it the hatch's ring and Tranquility's dark. Also which
    /// pixels are left as sky, the bezels' pixels (each with its direction from its window's centre, x right and y
    /// down), and the two pixels that glow at night.
    private func paint() -> (art: [UInt32], sky: [Bool], bezels: [(at: Int, x: Float, y: Float)], glows: (Int?, Int?)) {
        let count = w * h
        var art = [UInt32](repeating: 0x0b0c10, count: count) // the dome's wall
        func put(_ colour: UInt32, _ mask: [Bool]) { for i in 0..<count where mask[i] { art[i] = colour } }
        func put(_ colour: UInt32, where on: (Int) -> Bool) { for i in 0..<count where on(i) { art[i] = colour } }
        func plot(_ at: (x: Int, y: Int), _ colour: UInt32) { art[at.y * w + at.x] = colour }
        func azimuth(_ i: Int) -> Double { // which way round the dome's axis a pixel lies, in degrees from dead ahead
            let turn = atan2(Double(i / w) + 0.5 - Double(h) / 2, Double(i % w) + 0.5 - Double(w) / 2) * 180 / .pi
            return turn < 0 ? turn + 360 : turn
        }

        // Each window is open from its inner outline, at the room, to its outer one, at the glass: sky where both are.
        let inner = (0..<7).map { fill(Self.window($0)) }, outer = (0..<7).map { fill(Self.window($0, depth: Self.recess)) }
        let middle = (0..<7).map { fill(Self.window($0, depth: Self.recess / 2)) }
        var opening = [Bool](repeating: false, count: count), sky = opening, copper = opening, bezel = opening
        var rings: [[Bool]] = []
        for k in 0..<7 {
            let one = grow(inner[k]), two = grow(one)
            rings.append(two)
            for i in 0..<count {
                if inner[k][i] { (opening[i], sky[i]) = (true, sky[i] || outer[k][i]) }
                if one[i], !inner[k][i] { copper[i] = true }
                if two[i], !one[i] { bezel[i] = true }
            }
        }

        // The plate the windows are set in, to the base ring's lip; and the wall's panels beyond, barely lit.
        let plate = fill(circle(0.80, -0.42)), lip = grow(plate), clear = grow(lip)
        put(0x101216, plate)
        put(0x16181d, shrink(plate))
        put(0x2a2e36) { lip[$0] && !plate[$0] }
        for a in stride(from: 15.0, to: 360, by: 30) {
            let panel = fill(wall(a, 13, -0.53, -1.0))
            put(0x101217) { panel[$0] && !clear[$0] }
        }
        // Round the base: the long blue rail in six lengths with silver ends, and two braided hoses.
        let rail = fill(circle(0.86, -0.47)), railEdge = grow(rail), railTop = grow(railEdge)
        func along(_ i: Int) -> Double { abs((azimuth(i) + 30).truncatingRemainder(dividingBy: 60) - 30) }
        put(0x083c71) { railEdge[$0] && !rail[$0] && along($0) < 23 }
        put(0x1c7fb5) { railTop[$0] && !railEdge[$0] && along($0) < 23 }
        put(0x8b9094) { railTop[$0] && !rail[$0] && abs(along($0) - 23) < 1.2 }
        for (from, to, high, low) in [(4.0, 24.0, -0.50, -0.80), (196, 216, -0.52, -0.84)] {
            let hose = (0..<200).map { n -> Sky.Vector in polar(0.9, from + (to - from) * Double(n) / 199, high + (low - high) * pow(Double(n) / 199, 2)) }
            for at in trace(hose) { plot(at, (at.x + at.y) % 4 < 2 ? 0x6f6b66 : 0x45433f) }
        }
        // The workstation: a glossy monitor aft, with the Sun's glare in it; the keypad's box; a crew patch; and the
        // hand controller in its guard.
        let monitor = fill(wall(180, 9, -0.50, -0.74)), glass = shrink(monitor), screen = (0..<count).filter { glass[$0] }
        put(0x363a3d, monitor)
        if !screen.isEmpty {
            let cx = Double(screen.reduce(0) { $0 + $1 % w }) / Double(screen.count), cy = Double(screen.reduce(0) { $0 + $1 / w }) / Double(screen.count) - 4
            for i in screen {
                let glare = hypot(Double(i % w) - cx, (Double(i / w) - cy) / 1.4)
                art[i] = glare < 1.6 ? 0xe6eaec : glare < 3.2 ? 0xaab1b8 : 1.2 - glare / 9 > Double(bayer(i % w, i / w)) ? 0x4b5259 : 0x15181b
            }
        }
        let keypad = fill(wall(322, 6.5, -0.50, -0.66))
        put(0x8f8e86, keypad)
        put(0x6a6963, shrink(keypad))
        for a in [317.6, 320.5, 323.4, 326.3] { put(0x2c2c29, fill(wall(a, 0.8, -0.555, -0.605))) }
        for (r, colour) in [(0.062, 0xa8302a), (0.040, 0xd9d4c4), (0.020, 0x2c4f8f)] as [(Double, UInt32)] {
            put(colour, fill(disc(polar(0.90, 152, -0.62), polar(1, 242, 0), [0, 0, 1], r)))
        }
        put(0x4a4e52, fill(wall(28, 3.2, -0.50, -0.62)))
        let stick = trace(line(polar(0.90, 28, -0.56), polar(0.76, 28, -0.60)))
        for at in stick { plot(at, at == stick.last! ? 0x8b9094 : 0x1b1c1e) }

        // Bolts: a row round every window, one every four pixels, on bare plate only.
        let nearby = grow(opening, 2), near = grow(nearby)
        func bare(_ i: Int) -> Bool { plate[i] && !near[i] }
        for k in 0..<7 {
            let row = Self.window(k, grow: 0.04)
            for at in trace(row + [row[0]], step: 4) where bare(at.y * w + at.x) { plot(at, 0x6f7578) }
        }
        // Two tan bags strapped between the round window and the panes to port, lit from the upper left.
        for a in [284.0, 318] {
            let c = polar(0.447, a + 3, -0.02), long = polar(0.125, a + 97, 0), wide = polar(0.047, a + 7, 0)
            let cloth = fill(cut([c - long - wide, c + long - wide, c + long + wide, c - long + wide]))
            func bag(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < w && y < h && cloth[y * w + x] && !nearby[y * w + x] }
            for i in 0..<count where bag(i % w, i / w) {
                art[i] = !bag(i % w - 1, i / w - 1) ? 0xc8ac94 : !bag(i % w + 1, i / w + 1) ? 0x5e4638 : 0x8d6d59
            }
            for at in trace(line(c + long * 0.24 - wide, c + long * 0.24 + wide)) where bag(at.x, at.y) { plot(at, 0x2a2320) }
        }
        // White labels, three pixels each.
        for (k, part) in [(0, 0.30), (1, 0.62), (2, 0.12), (3, 0.80), (4, 0.36), (5, 0.58), (6, 0.20), (6, 0.70)] {
            let row = Self.window(k, grow: 0.065)
            guard let at = spot(row[Int(part * Double(row.count))]).flatMap(pixel), at.x >= 1, at.x < w - 1 else { continue }
            if (-1...1).allSatisfy({ bare(at.y * w + at.x + $0) }) { for dx in -1...1 { plot((at.x + dx, at.y), 0xd8dde0) } }
        }
        // Each window, from the glass to the room: the recess's wall in two steps, the copper line, the silver bezel.
        for k in 0..<7 {
            put(0x1e2021) { inner[k][$0] && !outer[k][$0] }
            put(0x3f4243) { inner[k][$0] && middle[k][$0] && !outer[k][$0] }
        }
        put(0x736f6c) { bezel[$0] && !opening[$0] }
        put(0xa25134) { copper[$0] && !opening[$0] }
        // Orange tags: a pixel on the bezel and one on the plate beside it.
        let centres = (0..<7).map { k -> SIMD2<Double>? in spot(Self.window(k).reduce(.zero, +) / Double(Self.window(k).count)) }
        for (k, part) in [(0, 0.12), (0, 0.66), (1, 0.40), (2, 0.08), (2, 0.71), (3, 0.33), (4, 0.55), (5, 0.15), (5, 0.90), (6, 0.07), (6, 0.44), (6, 0.81)] {
            let row = Self.window(k)
            guard let q = spot(row[Int(part * Double(row.count))]), let centre = centres[k], q != centre else { continue }
            for step in [1.6, 2.6] {
                if let at = pixel(q + normalize(q - centre) * step), !opening[at.y * w + at.x], !copper[at.y * w + at.x] { plot(at, 0xc8691e) }
            }
        }
        // One short blue handle lying along each bar, with silver ends, lit from the upper left.
        for k in 0..<6 {
            let ends = placed([0.28, 0.70].map { polar(0.537 + 0.228 * $0, 30 + 60 * Double(k), -0.016 - 0.357 * $0) })
            guard ends.count == 2, ends[0] != ends[1] else { continue }
            let length = simd.length(ends[1] - ends[0]), run = (ends[1] - ends[0]) / length
            let side = run.x - run.y < 0 ? SIMD2(-run.y, run.x) : SIMD2(run.y, -run.x)
            let low = pointwiseMin(ends[0], ends[1]) - 2, high = pointwiseMax(ends[0], ends[1]) + 3 // the handle's own corner of the picture
            for y in Int(max(0, min(Double(h), low.y)))..<Int(max(0, min(Double(h), max(low.y, high.y)))) {
                for x in Int(max(0, min(Double(w), low.x)))..<Int(max(0, min(Double(w), max(low.x, high.x)))) {
                    let p = SIMD2(Double(x) + 0.5, Double(y) + 0.5) - ends[0], s = dot(p, run), t = dot(p, side)
                    if s >= 0, s <= length, abs(t) <= 1 { art[y * w + x] = s < 1.2 || s > length - 1.2 ? 0x9aa0a4 : t > 0 ? 0x1c7fb5 : 0x0c4f92 }
                }
            }
        }
        // The hatch we look through (behind the eye from within, so only in the corners): its grey ring, and Tranquility's dark.
        let hole = fill(circle(0.64, -1.30)), ring = fill(circle(0.672, -1.30)), rim = grow(hole)
        put(0x1c2226) { !hole[$0] }
        put(0x2b3237) { rim[$0] && !hole[$0] }
        put(0x060709) { !ring[$0] }

        var glints: [(at: Int, x: Float, y: Float)] = []
        for k in 0..<7 {
            guard let centre = centres[k] else { continue }
            for i in 0..<count where bezel[i] && !opening[i] && rings[k][i] {
                let from = SIMD2(Double(i % w) + 0.5, Double(i / w) + 0.5) - centre, far = max(simd.length(from), 1)
                glints.append((i, Float(from.x / far), Float(from.y / far)))
            }
        }
        // A standby light on the second row from the foot of the monitor, and of the keypad, half way along it.
        func glow(_ mask: [Bool]) -> Int? {
            let solid = (0..<count).filter { mask[$0] && !sky[$0] }
            guard let foot = solid.last.map({ $0 / w }) else { return nil }
            let row = solid.filter { $0 / w == foot - 1 }
            return row.isEmpty ? nil : (row[(row.count - 1) / 2] + row[row.count / 2]) / 2
        }
        return (art, sky, glints, (glow(monitor), glow(keypad)))
    }

    // MARK: - The outside

    /// Marks out the station's hardware as the dome sees it, lit from one side for good: the round window's own
    /// shutter, a drum on an arm folded back beyond the bar to starboard; a Soyuz close by and a Progress further
    /// off, hanging toward the Earth aft; and the tip of a gold array forward and to port. `art` is 0xRRGGBB, rows
    /// from the top, wherever `there` says something stands.
    // ponytail: sizes are real and distances are not (each is chosen so the thing shows at a pane's outer part), the
    // light never moves, and a cylinder is filled as the outline of its two ends, which the fisheye should bend.
    // Kibo, Canadarm2 and the modules added since 2016 are left out. Model the station if it should be true.
    private func layHardware() -> (art: [UInt32], there: [Bool]) {
        var art = [UInt32](repeating: 0, count: w * h), there = [Bool](repeating: false, count: w * h)
        func put(_ mask: [Bool], _ colour: UInt32) { for i in mask.indices where mask[i] { (art[i], there[i]) = (colour, true) } }
        let sun = normalize(Sky.Vector(0.35, -0.25, -0.9)), from = Sky.Vector(0, 0, -eye), down = Sky.Vector(0, 0, 1)

        /// A cylinder between two points, in three tones: shaded, plain and lit.
        func cylinder(_ p0: Sky.Vector, _ p1: Sky.Vector, _ r: Double, _ tones: [UInt32]) {
            let axis = normalize(p1 - p0), toEye = from - (p0 + p1) / 2, facing = normalize(toEye - axis * dot(toEye, axis))
            let side = cross(axis, facing) * (dot(cross(axis, facing), sun) < 0 ? -1 : 1) // across it, toward the Sun
            func strip(_ a: Double, _ b: Double) -> [Bool] {
                let edge = (0..<9).map { n -> Sky.Vector in
                    let turn = (a + (b - a) * Double(n) / 8) * .pi / 180
                    return (facing * cos(turn) + side * sin(turn)) * r
                }
                return cover(hull(placed(edge.map { p0 + $0 } + edge.map { p1 + $0 })))
            }
            put(cover(hull(placed(disc(p0, facing, side, r) + disc(p1, facing, side, r)))), tones[1])
            put(strip(20, 85), tones[2])
            put(strip(-85, -35), tones[0])
            for (end, out) in [(p0, -axis), (p1, axis)] where dot(from - end, out) > 0 { // the end we can see
                put(fill(disc(end, facing, side, r)), dot(out, sun) > 0.2 ? tones[2] : tones[1])
            }
        }
        /// A solar panel: a flat sheet from `c`, ruled across into cells, with a spine along it.
        func panel(_ c: Sky.Vector, _ along: Sky.Vector, _ across: Sky.Vector, _ cells: Int, _ tones: [UInt32]) {
            put(fill(cut([c - across, c + along - across, c + along + across, c + across])), tones[1])
            for n in 0...cells {
                let rule = c + along * (Double(n) / Double(cells))
                for at in trace(line(rule - across, rule + across)) { (art[at.y * w + at.x], there[at.y * w + at.x]) = (tones[0], true) }
            }
            for at in trace(line(c, c + along)) where there[at.y * w + at.x] { art[at.y * w + at.x] = tones[0] }
        }

        let dark: [UInt32] = [0x3d4148, 0x7c8289, 0xb4b9be], pale: [UInt32] = [0x7b8086, 0xc3c7c9, 0xeef0f0], gold: [UInt32] = [0x5a4526, 0xa98a4e, 0xd9bd7c]
        // The Progress and the Soyuz: azimuth, metres off, how far toward the Earth it reaches, its radius and a panel's length.
        for (az, off, reach, r, span) in [(195.0, 30.0, 9.6, 1.2, 2.6), (168, 15, 6.2, 1.15, 2.4)] {
            let c = polar(off, az, 0), across = polar(1, az + 90, 0)
            for way in [-1.0, 1] { panel(c + down * (reach - 1.1) + across * (way * r), across * (way * span), down * 0.7, 4, gold) }
            cylinder(c - down, c + down * (reach - 4.4), r * 0.9, dark) // the orbital module, docked
            cylinder(c + down * (reach - 4.4), c + down * (reach - 2.3), r * 0.8, pale) // the descent module
            cylinder(c + down * (reach - 2.3), c + down * (reach - 0.5), r, dark) // the service module
            cylinder(c + down * (reach - 0.5), c + down * reach, r * 0.75, pale)
        }
        panel(polar(30, 287, 10.5), polar(9, 150, -16), polar(3.2, 240, 0), 7, [0x7a5a1e, 0xc9973f, 0xf0c66a]) // the array, hanging in from above

        // The shutter: a drum 0.42 m in radius, hinged beyond the bar at 90° and folded back 12° (it stands like this in ISS038-E-040615).
        let r = 0.42, fold = 12 * Double.pi / 180, across = polar(1, 180, 0), shaded = dot(across, sun) < 0 ? across : -across
        let out = polar(cos(fold), 90, -sin(fold)), c = polar(0.58, 90, 0.12) + out * (r + 0.02)
        func face(_ radius: Double, toward off: Double = 0) -> [Bool] { fill(disc(c + shaded * off, out, across, radius)) }
        cylinder(c, c + polar(sin(fold), 90, cos(fold)) * 0.15, r, [0x5b4a3b, 0xaba59e, 0xcdc8c0])
        let whole = face(r), lit = face(r, toward: -0.35 * r), plain = face(0.86 * r), dim = face(r, toward: 0.9 * r)
        put(whole, 0x5b4a3b) // its rim, shaded on one side and lit on the other
        put(whole.indices.map { whole[$0] && lit[$0] }, 0xcdc8c0)
        put(plain, 0xaba59e)
        put(plain.indices.map { plain[$0] && dim[$0] }, 0x8e877e)
        for a in [-0.5, 0.5] { // a seam each side of the arm
            for at in trace(line(c + across * (a * r) - out * (0.7 * r), c + across * (a * r) + out * (0.7 * r))) where whole[at.y * w + at.x] { art[at.y * w + at.x] = 0x7d7468 }
        }
        put(face(0.2 * r), 0x5b4a3b) // the hub the arm holds
        return (art, there)
    }
}

// MARK: - Shapes

/// A point `r` metres from the dome's axis, `az` degrees to starboard of dead ahead, `z` toward the Earth.
private func polar(_ r: Double, _ az: Double, _ z: Double) -> Sky.Vector { [r * cos(az * .pi / 180), r * sin(az * .pi / 180), z] }

/// A circle about the dome's axis, and a disc anywhere, as outlines.
private func circle(_ r: Double, _ z: Double) -> [Sky.Vector] { (0..<240).map { polar(r, Double($0) * 1.5, z) } }
private func disc(_ c: Sky.Vector, _ a: Sky.Vector, _ b: Sky.Vector, _ r: Double) -> [Sky.Vector] {
    (0..<48).map { c + (a * cos(Double($0) * .pi / 24) + b * sin(Double($0) * .pi / 24)) * r }
}

/// A closed outline with every edge cut into sixteen, so the fisheye can bend it; and a line as 200 points.
private func cut(_ outline: [Sky.Vector]) -> [Sky.Vector] {
    outline.indices.flatMap { i in (0..<16).map { outline[i] + (outline[(i + 1) % outline.count] - outline[i]) * Double($0) / 16 } }
}
private func line(_ a: Sky.Vector, _ b: Sky.Vector) -> [Sky.Vector] { (0..<200).map { a + (b - a) * Double($0) / 199 } }

/// A flat panel on the dome's wall, `half` degrees either side of `az`, between two heights.
private func wall(_ az: Double, _ half: Double, _ z0: Double, _ z1: Double) -> [Sky.Vector] {
    cut([polar(0.90, az - half, z0), polar(0.90, az + half, z0), polar(0.90, az + half, z1), polar(0.90, az - half, z1)])
}

/// The convex outline round some points in the picture (Andrew's monotone chain).
private func hull(_ points: [SIMD2<Double>]) -> [SIMD2<Double>] {
    let sorted = Set(points.map { SIMD2(($0.x * 1000).rounded(), ($0.y * 1000).rounded()) }).sorted { ($0.x, $0.y) < ($1.x, $1.y) }
    func half(_ points: [SIMD2<Double>]) -> [SIMD2<Double>] {
        var chain: [SIMD2<Double>] = []
        for p in points {
            while chain.count > 1, case let (a, b) = (chain[chain.count - 2], chain[chain.count - 1]), (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x) <= 0 { chain.removeLast() }
            chain.append(p)
        }
        return Array(chain.dropLast())
    }
    return (half(sorted) + half(sorted.reversed())).map { $0 / 1000 }
}

/// A colour given as 0xRRGGBB, each channel scaled and another colour added, as the scene's picture packs it.
private func tone(_ hex: UInt32, times: SIMD3<Double> = .one, plus: UInt32 = 0) -> UInt32 {
    func channel(_ shift: UInt32, _ scale: Double) -> UInt32 { UInt32(min(255, Double(hex >> shift & 255) * scale + Double(plus >> shift & 255) + 0.5)) }
    return 0xFF00_0000 | channel(0, times.z) << 16 | channel(8, times.y) << 8 | channel(16, times.x)
}
