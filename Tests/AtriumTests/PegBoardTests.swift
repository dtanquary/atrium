import Foundation
import Metal
import SpriteKit
import Testing
@testable import Atrium
@testable import PegLattice

/// A snow crystal grown on the lattice is one crystal with six arms that stays on the sheet: turned a sixth of a
/// turn about the middle hole it lands on itself (but for a hole here and there, where two sums that should be
/// equal differ in their last bit and a hole freezes a step sooner on one arm), no hole within two of the display's
/// edge has a peg, and the order has every place once. At each of the three peg sizes, on a laptop's display.
@Test func snowCrystalHasSixArmsAndStaysOnTheSheet() {
    for pitch in [32, 16, 32.0 / 3] { for (alpha, beta, gamma) in [(1, 0.5, 0.0005), (1, 0.35, 0.0035), (2, 0.3, 0.001), (1.5, 0.4, 0.006)] as [(Float, Float, Float)] {
        let lattice = Lattice(width: 1512, height: 982, pitch: pitch)
        var rng = SplitMix(state: 5)
        let clock = ContinuousClock(), began = clock.now
        let crystal = snowCrystal(on: lattice, alpha: alpha, beta: beta, gamma: gamma, using: &rng)
        let took = clock.now - began
        let (c0, r0) = (lattice.cols / 2, lattice.rows / 2)
        var (turned, total, edge) = (0, 0, 0)
        for row in 0..<lattice.rows { for col in 0..<lattice.cols where crystal.order[row * lattice.cols + col] >= 0 {
            total += 1
            if row < 3 || row > lattice.rows - 4 || col < 3 || col > lattice.cols - 4 { edge += 1 }
            // to axial coordinates about the middle, a sixth of a turn, and back to a column and a row
            let (dr, q) = (row - r0, col - c0 - ((row - (row & 1)) - (r0 - (r0 & 1))) / 2), (q2, dr2) = (-dr, q + dr)
            let row2 = r0 + dr2, col2 = c0 + q2 + ((row2 - (row2 & 1)) - (r0 - (r0 & 1))) / 2
            if (0..<lattice.rows).contains(row2), (0..<lattice.cols).contains(col2), crystal.order[row2 * lattice.cols + col2] >= 0 { turned += 1 }
        } }
        print("Peg Board, a crystal at \(alpha), \(beta), \(gamma) on \(lattice.cols) by \(lattice.rows) holes: \(total) pegs, \(turned) of them on a peg when turned a sixth of a turn; grown in \(took)")
        #expect(total == crystal.count && total > 150 && edge == 0)
        #expect(Double(turned) > 0.97 * Double(total))
        #expect(Set(crystal.order.filter { $0 >= 0 }).count == total && crystal.order.max() == Int32(total - 1))
    } }
}

/// Every figure's charts are whole (the holes each says it has, of the eight colours or none), and there is one
/// for each peg size, which fits what a 13-inch laptop's display holds at that size and is the one the scene puts
/// up there: so every figure is offered at every size.
@MainActor @Test func pegBoardHasEveryFigureAtEverySize() throws {
    defer { ["pegboard.size", "pegboard.picture"].forEach(UserDefaults.standard.removeObject) }
    let figures = Dictionary(grouping: PegBoard.charts, by: \.name)
    #expect(figures.count == 11)
    for (name, charts) in figures {
        #expect(charts.count == 3, "\(name)")
        for (size, chart) in charts.sorted(by: { $0.pegs.count < $1.pegs.count }).prefix(3).enumerated() { // for Large pegs, Medium, Small
            let most = [(43, 30), (86, 61), (131, 93)][size], pegs = chart.pegs.count { $0 > 0 }
            #expect(chart.pegs.count == chart.cols * chart.rows && chart.pegs.allSatisfy { $0 <= 8 } && pegs > 150, "\(name)")
            #expect(chart.cols <= most.0 && chart.rows <= most.1, "\(name) is \(chart.cols) by \(chart.rows)")
            UserDefaults.standard.set(Double(size), forKey: "pegboard.size")
            UserDefaults.standard.set(name, forKey: "pegboard.picture")
            let scene = PegBoard(size: CGSize(width: 1512, height: 982))
            #expect(scene.picture && scene.sequence.count == pegs, "\(name) at peg size \(size)")
        }
    }
}

/// The pictures go round: with pictures only, every figure goes up once before any comes again, and the next time
/// round they come in another order. And with everything shown, both kinds come. (A figure is known here by how
/// many pegs it has, which no two share at Large pegs.)
@MainActor @Test func pegBoardShowsEveryFigureInANewOrderEachRound() throws {
    let keys = ["pegboard.seed", "pegboard.size", "pegboard.shows", "pegboard.speed"]
    defer { keys.forEach(UserDefaults.standard.removeObject) }
    UserDefaults.standard.set(7, forKey: "pegboard.seed")
    UserDefaults.standard.set(0.0, forKey: "pegboard.size")
    UserDefaults.standard.set(20.0, forKey: "pegboard.speed")
    func things(_ count: Int, shows: Double) -> [(picture: Bool, pegs: Int)] { // what goes up, one after another
        UserDefaults.standard.set(shows, forKey: "pegboard.shows")
        let scene = PegBoard(size: CGSize(width: 1512, height: 982))
        var shown = [(scene.picture, scene.sequence.count)], time = 0.0
        while shown.count < count, time < 100.0 * Double(count) {
            time += 0.1
            let was = scene.phase
            scene.update(time)
            if was == .clearing, scene.phase == .building { shown.append((scene.picture, scene.sequence.count)) }
        }
        return shown
    }
    let figures = Set(PegBoard.charts.filter { $0.rows <= 30 }.map { chart in chart.pegs.count { $0 > 0 } })
    let shown = things(22, shows: 2)
    #expect(figures.count == 11 && shown.count == 22 && shown.allSatisfy(\.picture))
    let (first, second) = (shown.prefix(11).map(\.pegs), shown.suffix(11).map(\.pegs))
    #expect(Set(first) == figures && Set(second) == figures && first != second)
    let both = things(4, shows: 0)
    #expect(both.contains { $0.picture } && both.contains { !$0.picture })
}

/// Outline first: a picture's order has every peg once and no empty hole, and every peg on an edge of its colour
/// comes before any that is not.
@MainActor @Test func pegBoardBuildsAPictureOutlineFirst() throws {
    let chart = try #require(PegBoard.charts.first { $0.name == "sailboat" && $0.rows <= 30 })
    let order = outlineFirst(pegs: chart.pegs, cols: chart.cols, rows: chart.rows)
    #expect(order.count == chart.pegs.count { $0 > 0 } && Set(order).count == order.count && order.allSatisfy { chart.pegs[$0] > 0 })
    func inside(_ hole: Int) -> Bool { // all six holes round it hold its colour
        let (col, row) = (hole % chart.cols, hole / chart.cols), odd = row & 1
        return [(col - 1, row), (col + 1, row), (col - 1 + odd, row - 1), (col + odd, row - 1), (col - 1 + odd, row + 1), (col + odd, row + 1)].allSatisfy {
            (0..<chart.cols).contains($0.0) && (0..<chart.rows).contains($0.1) && chart.pegs[$0.1 * chart.cols + $0.0] == chart.pegs[hole]
        }
    }
    let first = try #require(order.firstIndex(where: inside)), last = try #require(order.lastIndex { !inside($0) })
    print("Peg Board, the sailboat at \(chart.cols) by \(chart.rows): \(order.count) pegs, the first \(first) of them its outlines")
    #expect(last < first && first > order.count / 5)
}

/// The picture is the same whatever the frame rate, all the way round: drawn at 15, 30 and 60 frames a second,
/// every pixel is the same part-way through a build (after six seconds at speed 1 and one at speed 8), a minute on
/// (the build done, the light show under way), and a minute after that (the sheet cleared and the next thing
/// built). The display is a small one, which a thing of two or three hundred pegs fills. Twice: with whatever
/// comes first, and with a reef first, the one kind of pattern that is made on another thread.
@MainActor @Test(arguments: ["", "reef"]) func pegBoardLooksTheSameAtAnyFrameRate(first: String) throws {
    defer { ["pegboard.seed", "pegboard.speed", "pegboard.pattern"].forEach(UserDefaults.standard.removeObject) }
    UserDefaults.standard.set(7, forKey: "pegboard.seed")
    if !first.isEmpty { UserDefaults.standard.set(first, forKey: "pegboard.pattern") }
    let device = try #require(MTLCreateSystemDefaultDevice()), queue = try #require(device.makeCommandQueue())
    let (w, h) = (1512, 982)
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    var pictures: [[[UInt32]]] = []
    for rate in [15.0, 30.0, 60.0] {
        UserDefaults.standard.set(1.0, forKey: "pegboard.speed")
        let renderer = SKRenderer(device: device), target = try #require(device.makeTexture(descriptor: descriptor)), pass = MTLRenderPassDescriptor()
        let scene = PegBoard(size: CGSize(width: w / 2, height: h / 2))
        #expect(first.isEmpty || (!scene.picture && scene.kind?.rawValue == first))
        renderer.scene = scene
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        let start = ProcessInfo.processInfo.systemUptime + 1 // the renderer's first update runs on the system's clock
        var frames = 0.0
        func run(_ seconds: Double) { for _ in 0..<Int(seconds * rate) { renderer.update(atTime: start + frames / rate); frames += 1 } }
        func picture() throws -> [UInt32] {
            for _ in 0..<2 { // with no more time gone by, and twice for the shader's sake
                renderer.update(atTime: start + (frames - 1) / rate)
                let buffer = try #require(queue.makeCommandBuffer())
                renderer.render(withViewport: CGRect(x: 0, y: 0, width: w, height: h), commandBuffer: buffer, renderPassDescriptor: pass)
                buffer.commit()
                buffer.waitUntilCompleted()
            }
            var raw = [UInt32](repeating: 0, count: w * h)
            target.getBytes(&raw, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
            return raw
        }
        renderer.update(atTime: start) // the first frame counts as a 30th of a second at any rate
        frames = 1
        run(6)
        UserDefaults.standard.set(8.0, forKey: "pegboard.speed")
        run(1)
        var taken = [try picture()]
        for _ in 0..<2 {
            run(60)
            taken.append(try picture())
        }
        pictures.append(taken)
    }
    let lit = pictures[0].map { picture in picture.count { max($0 & 255, $0 >> 8 & 255, $0 >> 16 & 255) > 30 } }
    print("Peg Board\(first.isEmpty ? "" : ", a \(first) first,") at 7 s, 67 s and 127 s, speed 8 from 6 s: \(lit) of \(w * h) pixels are lit")
    #expect(lit[0] > 2000 && Double(lit[1]) > 1.5 * Double(lit[0]) && pictures[0][2] != pictures[0][1])
    for moment in 0..<3 {
        #expect(pictures[1][moment] == pictures[0][moment] && pictures[2][moment] == pictures[0][moment], "picture \(moment) differs with the frame rate")
    }
}

/// The sheet follows Settings while it runs: another peg size is another sheet of holes, there and then; and where
/// Shows no longer allows what is on the sheet, the sheet clears (four seconds) for something it does allow. And
/// the largest picture goes up without holding a frame for long.
@MainActor @Test func pegBoardFollowsItsSettings() throws {
    let keys = ["pegboard.seed", "pegboard.size", "pegboard.shows", "pegboard.picture"]
    defer { keys.forEach(UserDefaults.standard.removeObject) }
    UserDefaults.standard.set(7, forKey: "pegboard.seed")
    UserDefaults.standard.set(1.0, forKey: "pegboard.shows") // patterns only
    let scene = PegBoard(size: CGSize(width: 1512, height: 982)), renderer = SKRenderer(device: try #require(MTLCreateSystemDefaultDevice()))
    renderer.scene = scene
    let start = ProcessInfo.processInfo.systemUptime + 1
    var frames = 0.0
    func run(_ seconds: Double) { for _ in 0..<Int(seconds * 30) { renderer.update(atTime: start + frames / 30); frames += 1 } }
    run(1)
    #expect(scene.built == 1 && scene.lattice.cols == 97 && !scene.picture && scene.children.count == 1)
    UserDefaults.standard.set(2.0, forKey: "pegboard.size")
    #expect(scene.built == 2 && scene.lattice.cols == 144 && !scene.picture && scene.children.count == 1)
    UserDefaults.standard.set(2.0, forKey: "pegboard.shows") // pictures only
    #expect(!scene.picture)
    run(4.5)
    #expect(scene.picture && scene.sequence.count > 1500)
    UserDefaults.standard.set(1.0, forKey: "pegboard.shows")
    run(4.5)
    #expect(!scene.picture)
    UserDefaults.standard.set(0.0, forKey: "pegboard.size")
    UserDefaults.standard.set(2.0, forKey: "pegboard.shows")
    #expect(scene.lattice.cols == 50)
    run(4.5)
    // (at Large pegs: one of the charts cut for them, 43 holes by 30 at the most)
    #expect(scene.picture && PegBoard.charts.contains { chart in chart.cols <= 43 && chart.rows <= 30 && chart.pegs.count { $0 > 0 } == scene.sequence.count })

    UserDefaults.standard.set(2.0, forKey: "pegboard.size")
    UserDefaults.standard.set("butterfly", forKey: "pegboard.picture")
    let clock = ContinuousClock(), began = clock.now, big = PegBoard(size: CGSize(width: 1512, height: 982)), took = clock.now - began
    print("Peg Board, its largest picture (\(big.sequence.count) pegs) put up in \(took)")
    #expect(big.picture && big.sequence.count > 5000)
}

/// The clear is a fade with nothing sudden at its end: by the time the sheet is dark its pegs have gone with their
/// light, so the last picture of one thing and the first of the next are the same empty sheet, to within a level.
/// (When the pegs stayed, as black shapes over the dots, every one of them vanished on that frame.) And it is a
/// fade through all three of its seconds: the pegs' brightness on the screen falls in each quarter of it by
/// about a quarter of the whole: 19%, 24%, 29% and 28%. (Eased in and out it fell 12%, 32%, 40% and 16%, and read
/// as half as long.)
@MainActor @Test func pegBoardClearsWithoutAPop() throws {
    defer { ["pegboard.seed", "pegboard.speed"].forEach(UserDefaults.standard.removeObject) }
    UserDefaults.standard.set(7, forKey: "pegboard.seed")
    UserDefaults.standard.set(20.0, forKey: "pegboard.speed")
    let device = try #require(MTLCreateSystemDefaultDevice()), queue = try #require(device.makeCommandQueue())
    let (w, h) = (1512, 982)
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    let renderer = SKRenderer(device: device), target = try #require(device.makeTexture(descriptor: descriptor)), pass = MTLRenderPassDescriptor()
    let scene = PegBoard(size: CGSize(width: w / 2, height: h / 2))
    renderer.scene = scene
    pass.colorAttachments[0].texture = target
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    let start = ProcessInfo.processInfo.systemUptime + 1
    var frames = 0.0
    func step() { renderer.update(atTime: start + frames / 60); frames += 1 }
    func picture() throws -> [UInt32] {
        for _ in 0..<2 {
            renderer.update(atTime: start + (frames - 1) / 60)
            let buffer = try #require(queue.makeCommandBuffer())
            renderer.render(withViewport: CGRect(x: 0, y: 0, width: w, height: h), commandBuffer: buffer, renderPassDescriptor: pass)
            buffer.commit()
            buffer.waitUntilCompleted()
        }
        var raw = [UInt32](repeating: 0, count: w * h)
        target.getBytes(&raw, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
        return raw
    }
    func most(_ a: [UInt32], _ b: [UInt32]) -> Int {
        zip(a, b).reduce(0) { worst, pair in
            max(worst, abs(Int(pair.0 & 255) - Int(pair.1 & 255)), abs(Int(pair.0 >> 8 & 255) - Int(pair.1 >> 8 & 255)), abs(Int(pair.0 >> 16 & 255) - Int(pair.1 >> 16 & 255)))
        }
    }
    while scene.phase != .showing { step() }
    let lit = try picture()
    while scene.phase != .clearing { step() }
    var fading = [try picture()] // at the start of the three seconds of going dark, and at each quarter of them
    for _ in 0..<4 {
        for _ in 0..<45 { step() }
        fading.append(try picture())
    }
    let going = fading[2]
    for _ in 0..<30 { step() } // dark, half a second before the next thing begins
    let dark = try picture()
    while scene.phase == .clearing { step() }
    let begun = try picture() // the frame the next thing began on
    func bright(_ picture: [UInt32]) -> Int { picture.count { max($0 & 255, $0 >> 8 & 255, $0 >> 16 & 255) > 60 } }
    print("Peg Board's clear: \(bright(lit)) bright pixels lit, \(bright(going)) half-way through going dark, \(bright(dark)) dark; the next thing's first frame differs from the dark one by \(most(dark, begun)) of 255 at the most")
    #expect(bright(lit) > 20000 && bright(going) < bright(lit) && bright(going) > 0 && bright(dark) == 0)
    #expect(most(dark, begun) <= 2, "something on the sheet changed as the next thing began")
    // how bright the pegs are: the mean, over the pixels that were bright when lit, of each one's brightest channel
    let pegs = lit.indices.filter { max(lit[$0] & 255, lit[$0] >> 8 & 255, lit[$0] >> 16 & 255) > 60 }
    let levels = fading.map { picture in pegs.reduce(0.0) { $0 + Double(max(picture[$1] & 255, picture[$1] >> 8 & 255, picture[$1] >> 16 & 255)) } / Double(pegs.count) }
    let falls = (0..<4).map { (levels[$0] - levels[$0 + 1]) / (levels[0] - levels[4]) }
    print("Peg Board's clear, the pegs' brightness at each quarter of it:", levels.map { String(format: "%.0f", $0) }.joined(separator: " "),
          "of 255; each quarter's share of the fall:", falls.map { String(format: "%.0f%%", $0 * 100) }.joined(separator: " "))
    #expect(falls.allSatisfy { $0 > 0.15 && $0 < 0.35 })
}

/// The copy Settings runs behind its page gets a head start, which the desktop's does not: asked as `LivePreview`
/// asks it, the sheet is whole and under its light show on its first frame, and whole again after a change of peg
/// size; a scene not asked has only its first peg begun.
@MainActor @Test func pegBoardGivesSettingsAHeadStart() throws {
    let keys = ["pegboard.seed", "pegboard.size"]
    defer { keys.forEach(UserDefaults.standard.removeObject) }
    UserDefaults.standard.set(7, forKey: "pegboard.seed")
    let device = try #require(MTLCreateSystemDefaultDevice()), queue = try #require(device.makeCommandQueue())
    let (w, h) = (1512, 982)
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    func firstFrame(of scene: SKScene) throws -> Int { // how many of its pixels are bright
        let renderer = SKRenderer(device: device), target = try #require(device.makeTexture(descriptor: descriptor)), pass = MTLRenderPassDescriptor()
        renderer.scene = scene
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        let start = ProcessInfo.processInfo.systemUptime + 1
        for _ in 0..<2 {
            renderer.update(atTime: start)
            let buffer = try #require(queue.makeCommandBuffer())
            renderer.render(withViewport: CGRect(x: 0, y: 0, width: w, height: h), commandBuffer: buffer, renderPassDescriptor: pass)
            buffer.commit()
            buffer.waitUntilCompleted()
        }
        var raw = [UInt32](repeating: 0, count: w * h)
        target.getBytes(&raw, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
        return raw.count { max($0 & 255, $0 >> 8 & 255, $0 >> 16 & 255) > 60 }
    }
    let desktop = PegBoard(size: CGSize(width: w / 2, height: h / 2)), page = PegBoard(size: CGSize(width: w / 2, height: h / 2))
    let asked: SKScene = page
    (asked as? HeadStart)?.headStart()
    #expect(page.phase == .showing && desktop.phase == .building && page.sequence == desktop.sequence)
    let (empty, whole) = (try firstFrame(of: desktop), try firstFrame(of: page))
    UserDefaults.standard.set(0.0, forKey: "pegboard.size")
    #expect(page.built == 0 && page.phase == .showing && desktop.built == 0 && desktop.phase == .building)
    let larger = try firstFrame(of: page)
    print("Peg Board's first frame: \(empty) bright pixels on the desktop's copy, \(whole) on Settings' own, and \(larger) on it after a change to Large pegs")
    #expect(empty < 500 && whole > 20000 && larger > 20000)
}

/// Every kind of pattern, at each peg size on a laptop's display and from six seeds, lays each hole once, every
/// peg on the display and in one of the four tones, and is more than a handful of pegs; and the six are not one
/// picture, whatever order its pegs go in. Printed for docs/peg-board.md: how many pegs each is, how many pictures
/// the six are, and how long it took to make. (The seeds are ones whose first number is spread evenly from 0 to 1,
/// since a kind's first choice, of a size or a rule, is made with it: seeds 1 to 3 made the same choice.)
@Test func pegBoardPatternsFitTheSheet() {
    for pitch in [32, 16, 32.0 / 3] {
        let lattice = Lattice(width: 1512, height: 982, pitch: pitch)
        for kind in PatternKind.allCases {
            var counts: [Int] = [], took: [Double] = [], pictures = Set<[Int]>()
            for seed in [41, 61, 14, 12, 42, 32] as [UInt64] {
                var rng = SplitMix(state: seed)
                let clock = ContinuousClock(), began = clock.now
                let made = pattern(kind, on: lattice, using: &rng), span = clock.now - began
                took.append(Double(span.components.attoseconds) / 1e15 + Double(span.components.seconds) * 1000)
                counts.append(made.order.count)
                pictures.insert(zip(made.order, made.tone).map { $0 * 4 + Int($1) }.sorted())
                #expect(made.order.count == made.tone.count && Set(made.order).count == made.order.count, "\(kind) lays a hole twice")
                #expect(made.tone.allSatisfy { $0 < 4 })
                #expect(made.order.allSatisfy { (1...lattice.cols - 2).contains($0 % lattice.cols) && (1...lattice.rows - 2).contains($0 / lattice.cols) }, "\(kind) is off the display")
                #expect(made.order.count >= 60, "\(kind) at a pitch of \(pitch) from seed \(seed) is \(made.order.count) pegs")
            }
            #expect(pictures.count >= 2, "\(kind) at a pitch of \(pitch) is the same picture from six seeds")
            print(String(format: "Peg Board's %@ on %d by %d holes: %d to %d pegs, %d pictures from six seeds; made in %.1f ms at the most", kind.rawValue,
                         lattice.cols - 2, lattice.rows - 2, counts.min()!, counts.max()!, pictures.count, took.max()!))
        }
    }
}

/// The kinds of pattern take turns: the snow crystal and the seven others each come once, in some order, before any
/// comes again; the order is a new one each round; none follows itself, across rounds either; and a new sheet
/// never opens on a reef, which is made on another thread and would have to be waited for. Three rounds at Large
/// pegs and the slider's top speed, and the first thing of forty sheets.
@MainActor @Test func pegBoardShowsEveryKindOfPatternInTurn() {
    let keys = ["pegboard.seed", "pegboard.size", "pegboard.shows", "pegboard.speed"]
    defer { keys.forEach(UserDefaults.standard.removeObject) }
    UserDefaults.standard.set(1.0, forKey: "pegboard.shows") // patterns only
    UserDefaults.standard.set(0.0, forKey: "pegboard.size")
    UserDefaults.standard.set(20.0, forKey: "pegboard.speed")
    UserDefaults.standard.set(7, forKey: "pegboard.seed")
    let scene = PegBoard(size: CGSize(width: 1512, height: 982)), every = Set(PatternKind.allCases as [PatternKind?] + [nil])
    var shown = [scene.kind], time = 100.0, was = scene.phase
    while shown.count < 25 {
        time += 0.1
        scene.update(time)
        if was == .clearing, scene.phase == .building { shown.append(scene.kind) }
        was = scene.phase
    }
    let rounds = (0..<3).map { Array(shown[$0 * 8..<$0 * 8 + 8]) }
    print("Peg Board's patterns, three rounds:", rounds.map { $0.map { $0?.rawValue ?? "crystal" }.joined(separator: " ") }.joined(separator: " | "), "| then", shown[24]?.rawValue ?? "crystal")
    #expect(every.count == 8 && rounds.allSatisfy { Set($0) == every }, "a kind came twice before another had come once")
    #expect(Set(rounds).count == 3, "two rounds went in the same order")
    #expect(zip(shown, shown.dropFirst()).allSatisfy { $0 != $1 }, "a kind followed itself")

    var first = Set<PatternKind?>()
    for seed in 1...40 {
        UserDefaults.standard.set(seed, forKey: "pegboard.seed")
        first.insert(PegBoard(size: CGSize(width: 1512, height: 982)).kind)
    }
    #expect(!first.contains(.reef) && first.count == 7, "of forty sheets, the first things were \(first.map { $0?.rawValue ?? "crystal" }.sorted())")
}

/// Draws the sheet as it would be on a display of 1512 by 982 points, `width` pixels across, with Settings values
/// as the render test takes them ("key=value,key=value"), and saves it (.png or .jpg). `moment` is seconds from
/// the start; or, like "40%", that far through the first thing's build; or "whole", with Settings' head start: all
/// of it at once, before its light show has begun; or, like "film 25", every other frame of that many seconds at
/// 30 frames a second, saved as a folder of numbered PNGs. Drawn at the size it is shown at, because a still
/// reduced afterwards shows a weave in the dotted sheet. Gives back how many pegs the first thing has.
@MainActor @discardableResult private func drawPegBoard(to url: URL, width w: Int, moment: String, defaults: String) throws -> Int {
    let settings = defaults.split(separator: ",").map { $0.split(separator: "=") }.filter { $0.count == 2 }
    for pair in settings { UserDefaults.standard.set(Double(pair[1]).map { $0 as Any } ?? String(pair[1]), forKey: String(pair[0])) }
    defer { for pair in settings { UserDefaults.standard.removeObject(forKey: String(pair[0])) } }
    let h = w * 982 / 1512
    let device = try #require(MTLCreateSystemDefaultDevice()), queue = try #require(device.makeCommandQueue())
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    let renderer = SKRenderer(device: device), target = try #require(device.makeTexture(descriptor: descriptor)), pass = MTLRenderPassDescriptor()
    let scene = PegBoard(size: CGSize(width: 1512, height: 982)), pegs = scene.sequence.count
    if moment == "whole" { scene.headStart() }
    renderer.scene = scene
    pass.colorAttachments[0].texture = target
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    func save(to url: URL) throws {
        var raw = [UInt32](repeating: 0, count: w * h)
        target.getBytes(&raw, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
        let image = try #require(CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                         bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                                         provider: CGDataProvider(data: Data(bytes: raw, count: w * h * 4) as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let kind = url.pathExtension == "jpg" ? "public.jpeg" : "public.png"
        let file = try #require(CGImageDestinationCreateWithURL(url as CFURL, kind as CFString, 1, nil))
        CGImageDestinationAddImage(file, image, [kCGImageDestinationLossyCompressionQuality: 0.7] as CFDictionary)
        #expect(CGImageDestinationFinalize(file))
    }
    func draw() throws {
        let buffer = try #require(queue.makeCommandBuffer())
        renderer.render(withViewport: CGRect(x: 0, y: 0, width: w, height: h), commandBuffer: buffer, renderPassDescriptor: pass)
        buffer.commit()
        buffer.waitUntilCompleted()
    }
    let start = ProcessInfo.processInfo.systemUptime + 1
    if moment.hasPrefix("film ") {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        for frame in 0..<Int((Double(moment.dropFirst(5)) ?? 10) * 30) {
            renderer.update(atTime: start + Double(frame) / 30)
            guard frame % 2 == 0 else { continue }
            try draw()
            try save(to: url.appendingPathComponent(String(format: "%04d.png", frame / 2)))
        }
        return pegs
    }
    // a peg takes a second to light, so a build is whole a second after its last peg is begun
    let share = moment.hasSuffix("%") ? (Double(moment.dropLast()) ?? 100) / 100 : 0
    let seconds = moment == "whole" ? 0 : moment.hasSuffix("%") ? share * Double(pegs) / (6 * PegBoard.speed.value) + (share >= 1 ? 1.3 : 0) : Double(moment) ?? 30
    for frame in 0...Int(seconds * 30) + 1 {
        renderer.update(atTime: start + Double(min(frame, Int(seconds * 30))) / 30)
        if frame >= Int(seconds * 30) { try draw() } // drawn at the end only, twice for the shader's sake
    }
    try save(to: url)
    return pegs
}

/// With PEGBOARD_STILL set to a file: one picture of the sheet (`drawPegBoard`), PEGBOARD_STILL_WIDTH pixels across
/// (1600 for docs/images, 1200 for Settings' preview), after SNAPSHOT_SECONDS with SNAPSHOT_DEFAULTS, or with
/// Settings' head start first where PEGBOARD_HEAD_START is set.
@MainActor @Test(.enabled(if: ProcessInfo.processInfo.environment["PEGBOARD_STILL"] != nil))
func pegBoardStill() throws {
    let env = ProcessInfo.processInfo.environment
    try drawPegBoard(to: URL(fileURLWithPath: env["PEGBOARD_STILL"]!), width: Int(env["PEGBOARD_STILL_WIDTH"] ?? "") ?? 1600,
                     moment: env["PEGBOARD_HEAD_START"] != nil ? "whole" : env["SNAPSHOT_SECONDS"] ?? "30", defaults: env["SNAPSHOT_DEFAULTS"] ?? "")
}

/// With PEGBOARD_STILLS set to a file of jobs, a line each of "file, width, moment, defaults" with tabs between:
/// draws them all in one run (`drawPegBoard`), and prints how many pegs each had.
@MainActor @Test(.enabled(if: ProcessInfo.processInfo.environment["PEGBOARD_STILLS"] != nil))
func pegBoardStills() throws {
    let jobs = try String(contentsOfFile: ProcessInfo.processInfo.environment["PEGBOARD_STILLS"]!, encoding: .utf8)
    for job in jobs.split(separator: "\n").map({ $0.split(separator: "\t", omittingEmptySubsequences: false).map(String.init) }) where job.count == 4 {
        let pegs = try drawPegBoard(to: URL(fileURLWithPath: job[0]), width: Int(job[1]) ?? 1512, moment: job[2], defaults: job[3])
        print("Peg Board still \(URL(fileURLWithPath: job[0]).lastPathComponent): \(pegs) pegs")
    }
}
