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

/// Every picture's charts are whole (the holes each says it has, of the eight colours or none), fit what a
/// 13-inch laptop's display holds at their size, and have a line in the credits; and there is a chart at each size.
/// The figures drawn for the app (docs/peg-board/draw.py: the charts under its heading in the file) are its own
/// work, so they have no line there, and each is at all three sizes.
@MainActor @Test func pegBoardChartsAreWholeAndCredited() throws {
    let credits = try String(contentsOf: resource("peg-board-credits.tsv"), encoding: .utf8).split(separator: "\n").filter { !$0.hasPrefix("#") }
        .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(String.init) }
    #expect(credits.allSatisfy { $0.count == 5 && $0[4].hasPrefix("https://") && ["CC0", "CC BY 4.0"].contains($0[3]) })
    let charts = PegBoard.charts, file = try String(contentsOf: resource("peg-board-charts.txt"), encoding: .utf8)
    let drawn = PegLattice.charts(from: String(file[try #require(file.range(of: "\n# Figures drawn for the app")).lowerBound...])).map(\.name)
    let cut = charts.map(\.name).filter { !drawn.contains($0) }
    #expect(cut.count == 32 && Set(cut) == Set(credits.map { $0[0] }))
    #expect(drawn.count == 24 && Set(drawn).allSatisfy { name in drawn.count { $0 == name } == 3 })
    for chart in charts {
        #expect(chart.pegs.count == chart.cols * chart.rows && chart.pegs.allSatisfy { $0 <= 8 } && chart.pegs.count { $0 > 0 } > 150, "\(chart.name)")
        #expect([(43, 30), (86, 61), (131, 93)].contains { chart.cols <= $0.0 && chart.rows <= $0.1 }, "\(chart.name) is \(chart.cols) by \(chart.rows)")
    }
    for most in [(43, 30), (86, 61), (131, 93)] { #expect(charts.contains { $0.cols <= most.0 && $0.rows <= most.1 && $0.rows > most.1 * 2 / 3 }) }
    #expect(Set(charts.filter { $0.cols <= 43 && $0.rows <= 30 }.map(\.name)).count >= 7, "Large pegs have fewer than seven pictures")
}

/// Outline first: a picture's order has every peg once and no empty hole, and every peg on an edge of its colour
/// comes before any that is not.
@MainActor @Test func pegBoardBuildsAPictureOutlineFirst() throws {
    let chart = try #require(PegBoard.charts.first { $0.name == "great-wave" && $0.cols < 86 })
    let order = outlineFirst(pegs: chart.pegs, cols: chart.cols, rows: chart.rows)
    #expect(order.count == chart.pegs.count { $0 > 0 } && Set(order).count == order.count && order.allSatisfy { chart.pegs[$0] > 0 })
    func inside(_ hole: Int) -> Bool { // all six holes round it hold its colour
        let (col, row) = (hole % chart.cols, hole / chart.cols), odd = row & 1
        return [(col - 1, row), (col + 1, row), (col - 1 + odd, row - 1), (col + odd, row - 1), (col - 1 + odd, row + 1), (col + odd, row + 1)].allSatisfy {
            (0..<chart.cols).contains($0.0) && (0..<chart.rows).contains($0.1) && chart.pegs[$0.1 * chart.cols + $0.0] == chart.pegs[hole]
        }
    }
    let first = try #require(order.firstIndex(where: inside)), last = try #require(order.lastIndex { !inside($0) })
    print("Peg Board, the Wave at \(chart.cols) by \(chart.rows): \(order.count) pegs, the first \(first) of them its outlines")
    #expect(last < first && first > order.count / 5)
}

/// The picture is the same whatever the frame rate, all the way round: drawn at 15, 30 and 60 frames a second,
/// every pixel is the same part-way through a build (after six seconds at speed 1 and one at speed 8), a minute on
/// (the build done, the light show under way), and a minute after that (the sheet cleared and the next thing
/// built). The display is a small one, which a thing of two or three hundred pegs fills.
@MainActor @Test func pegBoardLooksTheSameAtAnyFrameRate() throws {
    defer { ["pegboard.seed", "pegboard.speed"].forEach(UserDefaults.standard.removeObject) }
    UserDefaults.standard.set(7, forKey: "pegboard.seed")
    let device = try #require(MTLCreateSystemDefaultDevice()), queue = try #require(device.makeCommandQueue())
    let (w, h) = (1512, 982)
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    var pictures: [[[UInt32]]] = []
    for rate in [15.0, 30.0, 60.0] {
        UserDefaults.standard.set(1.0, forKey: "pegboard.speed")
        let renderer = SKRenderer(device: device), target = try #require(device.makeTexture(descriptor: descriptor)), pass = MTLRenderPassDescriptor()
        renderer.scene = PegBoard(size: CGSize(width: w / 2, height: h / 2))
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
    print("Peg Board at 7 s, 67 s and 127 s, speed 8 from 6 s: \(lit) of \(w * h) pixels are lit")
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
    UserDefaults.standard.set("flea", forKey: "pegboard.picture")
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

/// With PEGBOARD_STILL set to a file (.png or .jpg): one picture of the sheet on a display of 1512 by 982 points,
/// drawn PEGBOARD_STILL_WIDTH pixels across (1600 for docs/images, 1200 for Settings' preview), after
/// SNAPSHOT_SECONDS with SNAPSHOT_DEFAULTS as the render test takes them (and given Settings' head start first,
/// with PEGBOARD_HEAD_START set). Drawn at the size it is shown at, because
/// a still reduced afterwards shows a weave in the dotted sheet.
@MainActor @Test(.enabled(if: ProcessInfo.processInfo.environment["PEGBOARD_STILL"] != nil))
func pegBoardStill() throws {
    let env = ProcessInfo.processInfo.environment, url = URL(fileURLWithPath: env["PEGBOARD_STILL"]!)
    let settings = (env["SNAPSHOT_DEFAULTS"] ?? "").split(separator: ",").map { $0.split(separator: "=") }.filter { $0.count == 2 }
    for pair in settings { UserDefaults.standard.set(Double(pair[1]).map { $0 as Any } ?? String(pair[1]), forKey: String(pair[0])) }
    defer { for pair in settings { UserDefaults.standard.removeObject(forKey: String(pair[0])) } }
    let w = Int(env["PEGBOARD_STILL_WIDTH"] ?? "") ?? 1600, h = w * 982 / 1512, seconds = Double(env["SNAPSHOT_SECONDS"] ?? "") ?? 30
    let device = try #require(MTLCreateSystemDefaultDevice()), queue = try #require(device.makeCommandQueue())
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    let renderer = SKRenderer(device: device), target = try #require(device.makeTexture(descriptor: descriptor)), pass = MTLRenderPassDescriptor()
    let scene = PegBoard(size: CGSize(width: 1512, height: 982))
    if env["PEGBOARD_HEAD_START"] != nil { scene.headStart() }
    renderer.scene = scene
    pass.colorAttachments[0].texture = target
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    let start = ProcessInfo.processInfo.systemUptime + 1
    for frame in 0...Int(seconds * 30) + 1 {
        renderer.update(atTime: start + Double(min(frame, Int(seconds * 30))) / 30)
        guard frame >= Int(seconds * 30) else { continue } // drawn at the end only, twice for the shader's sake
        let buffer = try #require(queue.makeCommandBuffer())
        renderer.render(withViewport: CGRect(x: 0, y: 0, width: w, height: h), commandBuffer: buffer, renderPassDescriptor: pass)
        buffer.commit()
        buffer.waitUntilCompleted()
    }
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
