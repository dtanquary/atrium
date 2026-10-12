import Foundation
import LineRoute
import Metal
import SpriteKit
import Testing
@testable import Atrium

/// A shipped route decodes to the steps and the clock its bake printed (docs/etching/bake.py), never leaves
/// its grid and never lifts: each step is to a cell beside the last.
@Test func lineRouteDecodesToItsKnownLength() throws {
    let file = try Data(contentsOf: resource("etching-wave.route")), route = try #require(LineRoute(file))
    #expect(route.steps == 238_714 && route.x.count == 238_715 && (route.columns, route.rows) == (1024, 640))
    #expect(abs(route.clock - 123_131.2) < 1 && abs(route.t[route.steps] - route.clock) < 1, "clock \(route.t[route.steps]) against \(route.clock)")
    #expect(route.x.allSatisfy { $0 > 0 && $0 < 1024 } && route.y.allSatisfy { $0 > 0 && $0 < 640 })
    // eased by one step, two cells in a row are never more than a diagonal apart
    #expect((1...route.steps).allSatisfy { abs(route.x[$0] - route.x[$0 - 1]) < 1.01 && abs(route.y[$0] - route.y[$0 - 1]) < 1.01 })
    #expect(LineRoute(file.prefix(40)) == nil && LineRoute(Data("not a route at all, though long enough".utf8)) == nil)
    let heading = try #require(LineRoute(file, walking: false))
    #expect(heading.steps == route.steps && heading.x.isEmpty)
}

/// Every picture in the set has a route at both widths of line: each decodes, to the steps its heading promises,
/// on the standard grid or the fine one of twice as many cells each way, and the fine one takes the longer.
@MainActor @Test func etchingHasEveryPictureAtBothWidths() throws {
    for (place, picture) in Etching.pictures.enumerated() {
        for (fine, grid) in [(false, 1024), (true, 2048)] {
            let file = try Data(contentsOf: resource("etching-\(picture.file)\(fine ? "-fine" : "").route")), route = try #require(LineRoute(file), "\(picture.name)")
            #expect(route.columns == grid && route.rows == grid * 5 / 8 && route.x.count == route.steps + 1 && route.steps > 50_000, "\(picture.name), fine \(fine)")
            #expect(route.rect.x > 0 && route.rect.y > 0 && route.rect.x + route.rect.w < grid && route.rect.y + route.rect.h < grid * 5 / 8)
        }
        #expect(Etching.seconds[0][place] > 1200 && Etching.seconds[1][place] > 1.3 * Etching.seconds[0][place], "\(picture.name) takes \(Etching.seconds.map { $0[place] })")
    }
    // at the top of the Speed slider the longest, fine, is done in a few minutes
    #expect(Etching.seconds[1].max()! / Etching.speed.range.upperBound < 300)
}

/// A route stamped for a 14-inch screen: the line covers a fifth of it, the first row of bytes is the bottom of the
/// screen (where the stylus starts, at the frame's lower left corner, at the very start of the clock), and times
/// run on to the clock's end. Prints how long decoding and stamping take.
@Test func lineRouteStampsItsTextures() throws {
    let file = try Data(contentsOf: resource("etching-wave.route")), clock = ContinuousClock()
    var route: LineRoute!, stamped: LineRoute.Stamped!
    let decoding = clock.measure { route = LineRoute(file) }
    let (w, h) = (3024, 1964), scale = min(Double(w) / 1024, Double(h) / 640), (dx, dy) = ((Double(w) - 1024 * scale) / 2, (Double(h) - 640 * scale) / 2)
    let stamping = clock.measure { stamped = route.stamp(width: w, height: h, scale: scale, dx: dx, dy: dy) }
    func ms(_ span: Duration) -> Double { Double(span.components.attoseconds) / 1e15 + Double(span.components.seconds) * 1000 }
    let making = clock.measure { _ = SKTexture(data: stamped.when, size: CGSize(width: w, height: h)) }
    print(String(format: "Etching, the Wave for 3024 x 1964: decoded in %.0f ms, stamped in %.0f ms, made a texture in %.1f ms", ms(decoding), ms(stamping), ms(making)))
    // and the fine route, of four times the steps, at the same size
    let fine = try #require(LineRoute(try Data(contentsOf: resource("etching-wave-fine.route"))))
    let finer = clock.measure { _ = fine.stamp(width: w, height: h, scale: scale / 2, dx: dx, dy: dy) }
    print(String(format: "Etching, the Wave's fine route (%d steps) for 3024 x 1964: stamped in %.0f ms", fine.steps, ms(finer)))
    let when = [UInt8](stamped.when), again = [UInt8](stamped.more)
    func time(_ p: Int) -> Int { Int(when[p * 4]) << 16 | Int(when[p * 4 + 1]) << 8 | Int(when[p * 4 + 2]) }
    let drawn = (0..<w * h).filter { when[$0 * 4 + 3] > 127 }
    #expect(Double(drawn.count) / Double(w * h) > 0.12 && Double(drawn.count) / Double(w * h) < 0.3, "the line covers \(drawn.count) texels")
    #expect(drawn.allSatisfy { time($0) <= Int(LineRoute.end) } && drawn.map(time).max()! > Int(LineRoute.end * 0.999))
    // the start: cell (68, 619) of 640 rows, so near the bottom, which is the first rows of bytes
    let first = try #require(drawn.min { time($0) < time($1) }), (fx, fy) = (first % w, first / w)
    #expect(time(first) < 200 && abs(Double(fx) - (68.5 * scale + dx)) < 4 && abs(Double(fy) - (Double(h) - (619.5 * scale + dy))) < 4, "starts at \(fx), \(fy)")
    // going over a line again is recorded, later than its first drawing, for a good share of the line
    let twice = drawn.filter { again[$0 * 4] != 255 || again[$0 * 4 + 1] != 255 }
    #expect(Double(twice.count) / Double(drawn.count) > 0.2 && twice.allSatisfy { Int(again[$0 * 4]) << 8 | Int(again[$0 * 4 + 1]) >= time($0) >> 8 })
}

/// Draws a Etching offscreen on a display `w` by `h` pixels at 2x, a frame at a time.
@MainActor private final class Screen {
    let renderer: SKRenderer, queue: MTLCommandQueue, target: MTLTexture, pass = MTLRenderPassDescriptor()
    let (w, h): (Int, Int)
    private let start = ProcessInfo.processInfo.systemUptime + 1 // the renderer's first update runs on the system's clock
    private var seconds = 0.0

    init(_ w: Int, _ h: Int) throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        (renderer, queue, target) = (SKRenderer(device: device), try #require(device.makeCommandQueue()), try #require(device.makeTexture(descriptor: descriptor)))
        (self.w, self.h) = (w, h)
        renderer.scene = Etching(size: CGSize(width: w / 2, height: h / 2))
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
    }

    /// The picture `after` more seconds: each pixel a word, blue lowest, top row first.
    func picture(after: Double) throws -> [UInt32] {
        seconds += after
        renderer.update(atTime: start + seconds)
        let buffer = try #require(queue.makeCommandBuffer())
        renderer.render(withViewport: CGRect(x: 0, y: 0, width: w, height: h), commandBuffer: buffer, renderPassDescriptor: pass)
        buffer.commit()
        buffer.waitUntilCompleted()
        var pixels = [UInt32](repeating: 0, count: w * h)
        target.getBytes(&pixels, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
        return pixels
    }

    /// A picture once the scene has settled: its route stamped and faded up.
    func settled() throws -> [UInt32] {
        for _ in 0..<3 { _ = try picture(after: 0.25) }
        return try picture(after: 0.25)
    }
}

/// With Settings values and the scene's own hooks for the length of `body`, as the render test sets them.
@MainActor private func with(_ settings: [String: Double], _ body: () throws -> Void) rethrows {
    defer { settings.keys.forEach(UserDefaults.standard.removeObject) }
    for (key, value) in settings { UserDefaults.standard.set(value, forKey: key) }
    try body()
}

/// How much line a picture holds: how far its pixels' blue falls below the screen's own, summed.
private func ink(_ pixels: [UInt32]) -> Int {
    let levels = pixels.map { Int($0 & 255) }, screen = levels.sorted()[levels.count * 9 / 10]
    return levels.reduce(0) { $0 + max(screen - $1 - 12, 0) }
}

/// The picture is the same whatever the frame rate: begun 40% drawn and run for two seconds at the top of the Speed
/// slider, drawn at 15, 30 and 60 frames a second, every pixel is the same; and it has moved on from where it began.
/// (The clock is the wall's, by way of each frame's own time, and the shader is told nothing else.)
@MainActor @Test func etchingLooksTheSameAtAnyFrameRate() throws {
    try with(["etching.drawn": 0.4, Etching.speed.key: 60, Etching.picture.key: 1]) {
        var pictures: [[UInt32]] = []
        for rate in [15.0, 30.0, 60.0] {
            let screen = try Screen(1512, 982)
            var begun: [UInt32] = []
            for frame in 0...Int(2 * rate) {
                let pixels = try screen.picture(after: frame == 0 ? 0 : 1 / rate)
                if frame == Int(rate) { begun = pixels } // a second in: the picture has faded up, and has a second still to run
                if frame == Int(2 * rate) { pictures.append(pixels) }
            }
            let moved = zip(begun, pictures.last!).count { $0 != $1 }
            #expect(moved > 300, "at \(rate) fps only \(moved) pixels changed in a second")
        }
        #expect(ink(pictures[0]) > 1512 * 982, "hardly any line: \(ink(pictures[0]))")
        #expect(pictures[1] == pictures[0] && pictures[2] == pictures[0], "the picture differs with the frame rate")
    }
}

/// A picture is drawn, rests, clears and gives way to the next, by the wall clock alone. Moving the Speed slider
/// leaves it as far along as it was; picking another picture clears this one for it there and then; Random never
/// draws the same picture twice running; and a Mac that was away for a day comes back to a picture part-way through.
@Test func etchingCycleFollowsTheClock() {
    let seconds = [600.0, 300, 900], next = { (was: Int) in (was + 1) % 3 }
    var cycle = Etching.Cycle(picture: 0, before: nil, began: 1000, paced: 1, following: nil, picked: 0)
    func at(_ wall: Double, speed: Double = 1, pick: Int = 0) -> Etching.Cycle.Moment { cycle.moment(at: wall, speed: speed, pick: pick, seconds: seconds, another: next) }
    #expect(at(1000) == .init(picture: 0, before: nil, drawn: 0, cleared: 0, following: nil))
    #expect(at(1300).drawn == 0.5 && at(1600).drawn == 1)
    #expect(at(1899) == .init(picture: 0, before: nil, drawn: 1, cleared: 0, following: nil)) // resting: 300 s at speed 1
    #expect(at(1906) == .init(picture: 0, before: nil, drawn: 1, cleared: 0.5, following: 1)) // clearing, and the next is chosen
    #expect(at(1912) == .init(picture: 1, before: 0, drawn: 0, cleared: 0, following: nil)) // the next, over the first one's ghost
    // twice as fast from a third of the way through: still a third drawn, and done in half the time left
    #expect(abs(at(2012).drawn - 1 / 3) < 1e-9 && abs(at(2012, speed: 2).drawn - 1 / 3) < 1e-9 && abs(at(2062, speed: 2).drawn - 2 / 3) < 1e-9)
    // the third picture picked by name: this one clears at once, and that one follows, over and over
    _ = at(2063, speed: 2, pick: 3)
    let picked = at(2064, speed: 2, pick: 3)
    #expect(picked.picture == 1 && abs(picked.cleared - 1.0 / 12) < 1e-9 && picked.following == 2)
    #expect(at(2075, speed: 2, pick: 3) == .init(picture: 2, before: 1, drawn: 0, cleared: 0, following: nil))
    let again = at(2075 + 450 + 150 + 12, speed: 2, pick: 3) // 900 s at twice the speed, 150 s resting, 12 clearing
    #expect(again.picture == 2 && again.before == 2 && again.drawn < 0.01)
    // back to Random and away for a day: somewhere in a picture that isn't the one before it
    let later = at(2075 + 86_400, speed: 2, pick: 0)
    #expect(later.picture != later.before && later.drawn >= 0 && later.drawn <= 1 && cycle.began <= 2075 + 86_400)
    // the other width of line takes twice as long: the picture stays as far drawn as it was
    var other = Etching.Cycle(picture: 0, before: nil, began: 0, paced: 2, following: nil, picked: 0)
    other.stretch(at: 100, from: 600, to: 1200)
    #expect(other.moment(at: 100, speed: 2, pick: 0, seconds: [1200, 300, 900], another: next).drawn == 1.0 / 3)
}

/// A finished picture clears to a faint ghost, and the next is drawn over it: full, half cleared, and the next
/// picture just begun hold less and less line, and the ghost holds some. Drawn too at a 5K display's size, where
/// the textures have a texel to two pixels each way and the shader reads four of them.
@MainActor @Test func etchingClearsToAGhost() throws {
    func drawn(_ hooks: [String: Double], _ w: Int = 1512, _ h: Int = 982) throws -> [UInt32] {
        var pixels: [UInt32] = []
        try with(hooks.merging([Etching.picture.key: 1]) { $1 }) { pixels = try Screen(w, h).settled() }
        return pixels
    }
    let full = ink(try drawn(["etching.drawn": 1])), clearing = ink(try drawn(["etching.cleared": 0.5]))
    #expect(full > 4 * 1512 * 982 && clearing < full * 3 / 4 && clearing > full / 8, "ink: full \(full), half cleared \(clearing)")
    // the ghost: the bare screen, a few levels darker along another picture's whole line and nowhere much darker
    let bare = try drawn(["etching.drawn": 0]), ghost = try drawn(["etching.drawn": 0, "etching.ghost": 1])
    let fainter = zip(bare, ghost).map { Int($0 & 255) - Int($1 & 255) }, lines = fainter.count { $0 >= 4 }
    #expect(lines > 1512 * 982 / 30 && fainter.max()! < 30 && fainter.min()! > -3, "the ghost darkens \(lines) pixels, by \(fainter.max()!) at the most")
    // and it is gone once the next picture is six minutes of drawing along: the picture is the one with no ghost under it
    #expect(try drawn(["etching.drawn": 0.1]) == drawn(["etching.drawn": 0.1, "etching.ghost": 1]))
    let big = ink(try drawn(["etching.drawn": 1], 5120, 2880)), share = Double(big) / Double(5120 * 2880) / (Double(full) / Double(1512 * 982))
    #expect(share > 0.7 && share < 1.4, "at 5K the picture holds \(share) of the line it does at 14 inches, pixel for pixel")
}

/// The fine line: the same picture from its fine route is drawn, with a thinner line (fewer pixels as dark as a
/// line's middle, though it holds more line). And at either width nothing is drawn in the top 4% of the screen,
/// which the menu bar covers.
@MainActor @Test func etchingDrawsTheFineLine() throws {
    func finished(fine: Double) throws -> [UInt32] {
        var pixels: [UInt32] = []
        try with(["etching.drawn": 1, Etching.picture.key: 2, Etching.detail.key: fine]) { pixels = try Screen(3024, 1964).settled() }
        return pixels
    }
    let standard = try finished(fine: 0), fine = try finished(fine: 1)
    func lines(_ pixels: [UInt32]) -> Int { pixels.count { $0 & 255 < 110 } }
    #expect(lines(fine) > 3024 * 1964 / 40 && fine != standard, "the fine picture has \(lines(fine)) pixels of line and the standard \(lines(standard))")
    // a thinner line has more edge to its middle: of the pixels a line touches, fewer are at full depth
    func solid(_ pixels: [UInt32]) -> Double { Double(pixels.count { $0 & 255 < 75 }) / Double(pixels.count { $0 & 255 < 125 }) }
    #expect(solid(fine) < solid(standard), "fully dark share of the line: fine \(solid(fine)), standard \(solid(standard))")
    for pixels in [standard, fine] { #expect(!pixels[..<(3024 * (1964 * 4 / 100))].contains { $0 & 255 < 110 }, "a line under the menu bar") }
}

/// The screen's level: its pixels' blue, at the nine-tenths mark.
private func level(_ pixels: [UInt32]) -> Int { pixels.map { Int($0 & 255) }.sorted()[pixels.count * 9 / 10] }

/// Set to Match System, the screen goes to the system's other mode by itself, under the picture: light, then two
/// seconds after Dark Mode comes on, the dim screen.
@MainActor @Test func etchingFollowsTheAppearance() throws {
    defer { NSApplication.shared.appearance = nil }
    try with(["etching.drawn": 0.3, Etching.powder.key: 2]) {
        NSApplication.shared.appearance = NSAppearance(named: .aqua)
        let screen = try Screen(756, 491), light = level(try screen.settled())
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        let partway = level(try screen.picture(after: 1.0 / 30))
        for _ in 0..<75 { _ = try screen.picture(after: 1.0 / 30) }
        let dim = level(try screen.picture(after: 1.0 / 30))
        #expect(abs(light - 154) < 8 && partway > dim + 20 && abs(dim - 105) < 8, "the screen's level: \(light) in Light Mode, \(partway) a frame after Dark Mode, \(dim) after")
    }
}

/// The screen is the one Settings asks for whatever the system's appearance: bright as it comes, in Dark Mode, and
/// dim when set to Dark, in Light Mode. Changing the setting eases the screen over, as the appearance does.
@MainActor @Test func etchingScreenIsTheOneAskedFor() throws {
    defer { NSApplication.shared.appearance = nil }
    try with(["etching.drawn": 0.3]) {
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        let screen = try Screen(756, 491), bright = level(try screen.settled())
        UserDefaults.standard.set(1.0, forKey: Etching.powder.key)
        defer { UserDefaults.standard.removeObject(forKey: Etching.powder.key) }
        let partway = level(try screen.picture(after: 1.0 / 30))
        for _ in 0..<75 { _ = try screen.picture(after: 1.0 / 30) }
        let dimmed = level(try screen.picture(after: 1.0 / 30))
        #expect(abs(bright - 154) < 8 && partway > dimmed + 20 && abs(dimmed - 105) < 8, "in Dark Mode the screen's level is \(bright) as it comes, \(partway) a frame after Dark is picked, \(dimmed) after")
        NSApplication.shared.appearance = NSAppearance(named: .aqua)
        let dim = level(try Screen(756, 491).settled())
        #expect(abs(dim - 105) < 8, "set to Dark in Light Mode the screen's level is \(dim)")
    }
}
