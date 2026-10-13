import Foundation
import simd

/// A design made for the sheet, fresh from a seed: the holes in the order their pegs go in and, in step with them,
/// which of four tones each takes. The scene gives the tones colours: 0, 1 and 2 are three of one family and 3 is
/// the bright one, used sparingly.
public struct Pattern: Sendable {
    public var order: [Int] = [], tone: [UInt8] = []
}

/// The kinds of design shown in turn with the snow crystal (docs/peg-board.md, "The patterns", has how each reads at
/// each peg size, what else was tried, and why it was dropped).
public enum PatternKind: String, CaseIterable, Sendable {
    case reef, plate, blocks, triangles, hexaflake, pinwheel, rose
}

public func pattern(_ kind: PatternKind, on lattice: Lattice, using rng: inout some RandomNumberGenerator) -> Pattern {
    let sheet = Sheet(lattice)
    switch kind {
    case .reef: return reef(sheet, using: &rng)
    case .plate: return plate(sheet, using: &rng)
    case .blocks: return blocks(sheet, using: &rng)
    case .triangles: return triangles(sheet, using: &rng)
    case .hexaflake: return hexaflake(sheet, using: &rng)
    case .pinwheel: return pinwheel(sheet, using: &rng)
    case .rose: return rose(sheet, using: &rng)
    }
}

/// The sheet's holes by their place about its middle hole: (q, r) is q holes along the row and r rows up, each row
/// up lying half a hole further right, so that the six holes round one are one step away in `dirs`.
struct Sheet {
    /// A step to each of the six holes round one, counter-clockwise from the one to its right.
    static let dirs = [(1, 0), (0, 1), (-1, 1), (-1, 0), (0, -1), (1, -1)]
    let lattice: Lattice, c0: Int, r0: Int
    /// How far a design may reach from the middle, in pitches, and in whole rows and holes: three holes clear of
    /// every edge of the display, as the crystal keeps.
    let reach: Double, rows: Int, cols: Int
    /// How far q and r have to run to take in every hole within `reach` of the middle: further than `reach`, since
    /// the rows are closer together than the holes in one. (Run to `reach` only, a ring came out as a hexagon.)
    var span: Int { Int(reach * 2 / 3.0.squareRoot()) + 2 }

    init(_ lattice: Lattice) {
        self.lattice = lattice
        (c0, r0) = (lattice.cols / 2, lattice.rows / 2)
        (rows, cols) = ((lattice.rows - 7) / 2, (lattice.cols - 7) / 2)
        reach = min(Double(rows) * Lattice.rise, Double(cols)) - 0.25
    }

    /// The hole at (q, r), if it is on the sheet and `margin` holes clear of its edges.
    func hole(_ q: Int, _ r: Int, margin: Int = 3) -> Int? {
        let row = r0 + r
        guard row >= margin, row < lattice.rows - margin else { return nil }
        let col = c0 + q + (r + (r0 & 1) - (row & 1)) / 2
        guard col >= margin, col < lattice.cols - margin else { return nil }
        return row * lattice.cols + col
    }

    /// Where (q, r) is, in pitches from the middle hole.
    func place(_ q: Int, _ r: Int) -> SIMD2<Double> { [Double(q) + Double(r) / 2, Double(r) * Lattice.rise] }
}

/// Puts pegs down in order, one to a hole.
private struct Builder {
    let sheet: Sheet
    var taken: [Bool], made = Pattern()

    init(_ sheet: Sheet) {
        self.sheet = sheet
        taken = [Bool](repeating: false, count: sheet.lattice.count)
    }

    mutating func put(_ q: Int, _ r: Int, _ tone: Int, margin: Int = 3) {
        guard let hole = sheet.hole(q, r, margin: margin), !taken[hole] else { return }
        taken[hole] = true
        made.order.append(hole)
        made.tone.append(UInt8(tone))
    }
}

private func floorMod(_ a: Int, _ n: Int) -> Int { ((a % n) + n) % n }
private func power(_ base: Int, _ n: Int) -> Int { (0..<n).reduce(1) { value, _ in value * base } }

// MARK: Growth

/// A reef: diffusion-limited aggregation (T. Witten and L. Sander, 1981) from the floor of the sheet. A peg at a
/// time wanders in from above at random and stops where it first touches the floor or what has grown from it, so
/// what grows is a row of branching things, never twice the same, each its own tone. A peg that touches stays with
/// `stick` chance, which below one thickens the branches. It stops at a count of pegs, about a quarter of the
/// holes under a height the seed picks: held to that height, it piled up along the line in a flat cap. It is a
/// walk a peg, and so the slow one: 0.4 s at Small pegs.
private func reef(_ sheet: Sheet, using rng: inout some RandomNumberGenerator) -> Pattern {
    let (cols, rows) = (sheet.lattice.cols, sheet.lattice.rows), stick = 0.3
    var stuck = [Bool](repeating: false, count: cols * rows), root = [Int](repeating: 0, count: cols * rows)
    var made = Pattern(), got = 0, trees = 0, launches = 0
    func inside(_ c: Int, _ r: Int) -> Bool { c >= 0 && c < cols && r >= 0 && r < rows }
    func step(_ c: Int, _ r: Int, _ d: Int) -> (Int, Int) {
        let odd = r & 1
        switch d {
        case 0: return (c + 1, r)
        case 1: return (c + odd, r + 1)
        case 2: return (c - 1 + odd, r + 1)
        case 3: return (c - 1, r)
        case 4: return (c - 1 + odd, r - 1)
        default: return (c + odd, r - 1)
        }
    }
    let most = Int(Double(cols - 2) * (Double(rows - 6) * Double.random(in: 0.4...0.6, using: &rng)) * 0.24)
    while made.order.count < most, launches < 400_000 {
        launches += 1
        // from a few rows above the tallest of it, anywhere along
        var (c, r) = (Int.random(in: 1...cols - 2, using: &rng), got + 6)
        walk: for _ in 0..<200_000 {
            let (nc, nr) = step(c, r, Int.random(in: 0..<6, using: &rng))
            // (the sides are walls: let round from one side to the other, a peg landed on the edge column behind
            // the branches that would have caught it, and a bare pole grew up the edge)
            if nr < 1 || nc < 1 || nc > cols - 2 { continue }
            if nr > got + 16 { break walk }
            if inside(nc, nr), stuck[nr * cols + nc] { continue }
            (c, r) = (nc, nr)
            var parent = -1
            for d in 0..<6 {
                let (ac, ar) = step(c, r, d)
                if inside(ac, ar), stuck[ar * cols + ac] { parent = ar * cols + ac; break }
            }
            guard parent >= 0 || r == 1, Double.random(in: 0..<1, using: &rng) < stick else { continue }
            guard r <= rows - 4 else { break walk } // three holes clear of the top: this one is lost
            let hole = r * cols + c
            stuck[hole] = true
            if parent >= 0 { root[hole] = root[parent] } else { trees += 1; root[hole] = trees }
            made.order.append(hole)
            made.tone.append(UInt8(root[hole] % 3))
            got = max(got, r - 1)
            break walk
        }
    }
    return made
}

/// A plate: one of Packard's snowflakes (N. Packard, "Lattice models for solidification and aggregation", 1986).
/// From one frozen hole, every hole freezes on the step it has one of the rule's numbers of frozen holes round it;
/// it grows until a hole would freeze off the sheet, and its pegs go in ring by ring, toned by when they froze. A
/// rule makes one shape only: the seed picks one of six rules.
private func plate(_ sheet: Sheet, using rng: inout some RandomNumberGenerator) -> Pattern {
    let rule = [[1], [1, 3], [1, 3, 5], [1, 2], [1, 5], [1, 3, 4, 5, 6]].randomElement(using: &rng)!
    let span = min(sheet.rows, sheet.cols) + 4, side = 2 * span + 1
    var when = [Int](repeating: -1, count: side * side)
    when[span * side + span] = 0
    var cells: [(step: Int, turn: Double, q: Int, r: Int)] = [(0, 0, 0, 0)], last = 0
    grow: for step in 1...2 * span {
        var fresh: [(Int, Int)] = []
        for r in -span + 1..<span { for q in -span + 1..<span where when[(r + span) * side + q + span] < 0 {
            let count = Sheet.dirs.count { when[(r + $0.1 + span) * side + q + $0.0 + span] >= 0 }
            if rule.contains(count) { fresh.append((q, r)) }
        } }
        guard !fresh.isEmpty, fresh.allSatisfy({ sheet.hole($0.0, $0.1) != nil }) else { break grow }
        for (q, r) in fresh {
            when[(r + span) * side + q + span] = step
            let p = sheet.place(q, r)
            cells.append((step, atan2(p.y, p.x), q, r))
        }
        last = step
    }
    cells.sort { ($0.step, $0.turn) < ($1.step, $1.turn) }
    var b = Builder(sheet)
    for cell in cells { b.put(cell.q, cell.r, cell.step == 0 ? 3 : min(cell.step * 3 / max(last, 1), 2)) }
    return b.made
}

// MARK: Geometric

/// Tumbling blocks: the sheet tiled with hexagons, each cut into three diamonds that the eye takes for the top and
/// two sides of a cube: the top bright, the left side one tone and the right another, or left dark. Whole cubes
/// only, laid from the middle out. The seed picks their size and whether the right side is dark.
private func blocks(_ sheet: Sheet, using rng: inout some RandomNumberGenerator) -> Pattern {
    let size = Int.random(in: max(2, Int(sheet.reach / 6.5))...max(3, Int(sheet.reach / 4.5)), using: &rng), period = 3 * size
    let shadow = Int.random(in: 0..<3, using: &rng) == 0, span = sheet.lattice.cols / period + 2
    let corners = [(1, 1), (-1, 2), (-2, 1), (-1, -1), (1, -2), (2, -1)]
    var centres: [(out: Double, turn: Double, i: Int, j: Int)] = []
    for j in -span...span { for i in -span...span where corners.allSatisfy({ sheet.hole(i * period + $0.0 * size, j * period + $0.1 * size) != nil }) {
        let p = sheet.place(i * period, j * period)
        centres.append((simd_length(p), atan2(p.y, p.x), i, j))
    } }
    centres.sort { ($0.out, $0.turn) < ($1.out, $1.turn) }
    // A cube's holes: those within its hexagon, which is upright (a corner straight up), and of the holes on an
    // edge two cubes share or a corner three share, the ones that fall to this cube by rule, so each hole has
    // one cube. Its faces meet along the lines from its middle to its upper two corners and its lowest.
    var cells: [(face: Int, down: Double, along: Double, q: Int, r: Int)] = []
    for r in -2 * size...2 * size { for q in -2 * size...2 * size {
        let (u, v, w) = (2 * q + r, -q - 2 * r, r - q), edge = 3 * size
        guard max(abs(u), abs(v), abs(w)) <= edge, min(u, v, w) > -edge || u == edge else { continue }
        let face = v < 0 && w >= 0 || (q, r) == (0, 0) ? 0 : u < 0 && v >= 0 ? 1 : 2, p = sheet.place(q, r)
        cells.append((face, -p.y, p.x, q, r))
    } }
    cells.sort { ($0.face, $0.down, $0.along) < ($1.face, $1.down, $1.along) }
    var b = Builder(sheet)
    for centre in centres {
        for cell in cells where !(shadow && cell.face == 2) {
            b.put(centre.i * period + cell.q, centre.j * period + cell.r, [3, 0, 1][cell.face])
        }
    }
    return b.made
}

// MARK: Fractals

/// Pascal's triangle with only the numbers a prime does not divide: for 2 it is Sierpinski's nested triangles,
/// which sit exactly on this lattice, and for 3 and 5 their cousins, toned by the remainder. It grows a row at a
/// time from its point, each row from its middle. The seed picks the prime and which way up it is.
private func triangles(_ sheet: Sheet, using rng: inout some RandomNumberGenerator) -> Pattern {
    let prime = [2, 2, 3, 3, 5].randomElement(using: &rng)!, down = Bool.random(using: &rng)
    let room = min(sheet.lattice.rows - 6, sheet.lattice.cols - 6)
    let sides = [2: [16, 32, 64, 96, 128], 3: [9, 18, 27, 54, 81, 108], 5: [10, 25, 50, 75, 100, 125]][prime]!
    let side = sides.last { $0 <= room } ?? sides[0], top = (side - 1) / 2
    var b = Builder(sheet), numbers = [1]
    for i in 0..<side {
        for j in (0...i).sorted(by: { abs(2 * $0 - i) < abs(2 * $1 - i) }) where numbers[j] != 0 {
            var tone = numbers[j] - 1
            if prime == 2 { // by which half of its own triangle it is in, at the scale of its row
                let scale = i == 0 ? 0 : Int.bitWidth - 1 - i.leadingZeroBitCount
                tone = i == 0 ? 3 : j >> scale & 1 == 0 ? 0 : scale % 2 == 0 ? 1 : 2
            }
            if down { b.put(top / 2 - (i - j), i - top, tone) } else { b.put(j - top / 2, top - i, tone) }
        }
        var next = [Int](repeating: 1, count: i + 2)
        if i >= 1 { for j in 1...i { next[j] = (numbers[j - 1] + numbers[j]) % prime } }
        numbers = next
    }
    return b.made
}

/// A hexaflake: a hole and the six round it, then that seven-fold thing and six copies of it round it three times
/// as far out, and so on. As many levels as fit; where there is room it is drawn twice the size, each point a
/// cluster of seven. It is laid as it is made: the middle flake of each level, then the six round it in turn.
/// Toned by how many levels a point is the middle one at.
private func hexaflake(_ sheet: Sheet, using rng: inout some RandomNumberGenerator) -> Pattern {
    let room = min(sheet.rows, sheet.cols)
    var levels = 1
    while (power(3, levels + 1) - 1) / 2 <= room { levels += 1 }
    let double = power(3, levels) <= room, first = Int.random(in: 0..<6, using: &rng)
    var b = Builder(sheet)
    func lay(_ level: Int, _ q: Int, _ r: Int, _ middles: Int) {
        guard level >= 0 else {
            let tone = middles == levels ? 3 : min(middles, 2)
            if double { for d in [(0, 0)] + Sheet.dirs { b.put(2 * q + d.0, 2 * r + d.1, tone) } } else { b.put(q, r, tone) }
            return
        }
        lay(level - 1, q, r, middles + 1)
        for k in 0..<6 {
            let d = Sheet.dirs[(first + k) % 6]
            lay(level - 1, q + d.0 * power(3, level), r + d.1 * power(3, level), middles)
        }
    }
    lay(levels - 1, 0, 0, 0)
    return b.made
}

// MARK: Spirals and flowers

/// A pinwheel: a few spiral arms of even width winding out from a bright hub, each its own tone, growing outward
/// together. The seed picks how many, which way they wind and how tightly.
private func pinwheel(_ sheet: Sheet, using rng: inout some RandomNumberGenerator) -> Pattern {
    let arms = Int.random(in: 2...5, using: &rng), handed = Bool.random(using: &rng) ? 1.0 : -1.0
    let apart = sheet.reach / 3.2 * Double.random(in: 0.85...1.25, using: &rng), start = Double.random(in: 0..<1, using: &rng)
    var cells: [(out: Double, turn: Double, q: Int, r: Int, tone: Int)] = []
    let span = sheet.span
    for r in -span...span { for q in -span...span {
        let p = sheet.place(q, r), out = simd_length(p)
        guard out <= sheet.reach else { continue }
        let turn = atan2(p.y, p.x), phase = Double(arms) * (turn / (2 * .pi) + start) - handed * out / apart
        if out < 1.2 { cells.append((out, turn, q, r, 3)) } else if phase - phase.rounded(.down) < 0.5 {
            let arm = floorMod(Int(phase.rounded(.down)), arms)
            cells.append((out, turn, q, r, arms % 2 == 0 ? arm % 2 : arm % 3))
        }
    } }
    cells.sort { ($0.out, $0.turn) < ($1.out, $1.turn) }
    var b = Builder(sheet)
    for cell in cells { b.put(cell.q, cell.r, cell.tone) }
    return b.made
}

/// A flower seen from above: a bright middle, a ring of short petals and a ring of long ones between them, each
/// petal a lens with dark between it and the next. It opens from the middle out. The seed picks how many petals
/// (never six) and turns it.
private func rose(_ sheet: Sheet, using rng: inout some RandomNumberGenerator) -> Pattern {
    let petals = (sheet.reach < 18 ? [5, 7, 8] : [7, 8, 9, 10, 12]).randomElement(using: &rng)!
    let turned = Double.random(in: 0..<2 * .pi, using: &rng), full = sheet.reach, heart = max(1.6, full * 0.12)
    /// Whether a place `out` from the middle at `turn` is on one of a ring of petals that run from `near` to `far`.
    func onPetal(_ out: Double, _ turn: Double, from near: Double, to far: Double, offset: Double) -> Bool {
        guard out > near, out < far else { return false }
        let between = 2 * Double.pi / Double(petals), along = (out - near) / (far - near)
        let aside = abs((turn - turned - offset * between).remainder(dividingBy: between)) * out
        return aside <= 0.43 * between * (near + 0.5 * (far - near)) * pow(sin(.pi * pow(along, 1.4)), 0.5)
    }
    var cells: [(out: Double, turn: Double, q: Int, r: Int, tone: Int)] = []
    let span = sheet.span
    for r in -span...span { for q in -span...span {
        let p = sheet.place(q, r), out = simd_length(p), turn = atan2(p.y, p.x)
        if out <= heart { cells.append((out, turn, q, r, 3)) }
        else if onPetal(out, turn, from: heart + 0.5, to: full * 0.56, offset: 0.5) { cells.append((out, turn, q, r, 1)) }
        else if onPetal(out, turn, from: full * 0.3, to: full, offset: 0) { cells.append((out, turn, q, r, 0)) }
    } }
    cells.sort { ($0.out, $0.turn) < ($1.out, $1.turn) }
    var b = Builder(sheet)
    for cell in cells { b.put(cell.q, cell.r, cell.tone) }
    return b.made
}
