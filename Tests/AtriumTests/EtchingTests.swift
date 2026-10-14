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

/// Every picture in the set has a route at both widths of line, or at the fine one alone where it is a muddle at the
/// standard line: then its name says so, and Random leaves it out while Detail is Standard. Each route decodes, to
/// the steps its heading promises, on the standard grid or the fine one of twice as many cells each way, and the
/// fine one takes the longer.
@MainActor @Test func etchingHasEveryPictureAtBothWidths() throws {
    #expect(Etching.pictures.count == 13 && Etching.picture.range.upperBound == 13)
    for (place, picture) in Etching.pictures.enumerated() {
        let alone = Etching.fineOnly[place], seconds = Etching.seconds.map { $0[place] }
        #expect(alone == picture.name.hasSuffix("(Fine only)"), "\(picture.name)")
        for (fine, grid) in [(false, 1024), (true, 2048)] where fine || !alone {
            let file = try Data(contentsOf: resource("etching-\(picture.file)\(fine ? "-fine" : "").route")), route = try #require(LineRoute(file), "\(picture.name)")
            #expect(route.columns == grid && route.rows == grid * 5 / 8 && route.x.count == route.steps + 1 && route.steps > 50_000, "\(picture.name), fine \(fine)")
            #expect(route.rect.x > 0 && route.rect.y > 0 && route.rect.x + route.rect.w < grid && route.rect.y + route.rect.h < grid * 5 / 8)
        }
        #expect(seconds[0] > 1200 && (alone ? seconds[1] == seconds[0] : seconds[1] > 1.3 * seconds[0]), "\(picture.name) takes \(seconds)")
    }
    #expect(Etching.fineOnly.count { $0 } == 1)
    #expect(Etching.choices(detailed: true) == Array(Etching.pictures.indices) && Etching.choices(detailed: false) == Etching.pictures.indices.filter { !Etching.fineOnly[$0] })
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
    var cycle = Etching.Cycle(picture: 0, before: nil, began: 1000, paced: 1, rested: 300, following: nil, picked: 0)
    func at(_ wall: Double, speed: Double = 1, pick: Int = 0) -> Etching.Cycle.Moment { cycle.moment(at: wall, speed: speed, rest: 300, pick: pick, seconds: seconds, another: next) }
    #expect(at(1000) == .init(picture: 0, before: nil, drawn: 0, cleared: 0, following: nil))
    #expect(at(1300).drawn == 0.5 && at(1600).drawn == 1)
    #expect(at(1899) == .init(picture: 0, before: nil, drawn: 1, cleared: 0, following: nil)) // resting, for 300 s
    #expect(at(1906) == .init(picture: 0, before: nil, drawn: 1, cleared: 0.5, following: 1)) // clearing, and the next is chosen
    #expect(at(1912) == .init(picture: 1, before: 0, drawn: 0, cleared: 0, following: nil)) // the next, over the first one's ghost
    // twice as fast from a third of the way through: still a third drawn, and done in half the time left
    #expect(abs(at(2012).drawn - 1 / 3) < 1e-9 && abs(at(2012, speed: 2).drawn - 1 / 3) < 1e-9 && abs(at(2062, speed: 2).drawn - 2 / 3) < 1e-9)
    // the third picture picked by name: this one clears at once, and that one follows, over and over
    _ = at(2063, speed: 2, pick: 3)
    let picked = at(2064, speed: 2, pick: 3)
    #expect(picked.picture == 1 && abs(picked.cleared - 1.0 / 12) < 1e-9 && picked.following == 2)
    #expect(at(2075, speed: 2, pick: 3) == .init(picture: 2, before: 1, drawn: 0, cleared: 0, following: nil))
    let again = at(2075 + 450 + 300 + 12, speed: 2, pick: 3) // 900 s at twice the speed, 300 s resting, 12 clearing
    #expect(again.picture == 2 && again.before == 2 && again.drawn < 0.01)
    // back to Random and away for a day: somewhere in a picture that isn't the one before it
    let later = at(2075 + 86_400, speed: 2, pick: 0)
    #expect(later.picture != later.before && later.drawn >= 0 && later.drawn <= 1 && cycle.began <= 2075 + 86_400)
    // the other width of line takes twice as long: the picture stays as far drawn as it was
    var other = Etching.Cycle(picture: 0, before: nil, began: 0, paced: 2, rested: 300, following: nil, picked: 0)
    other.stretch(at: 100, from: 600, to: 1200)
    #expect(other.moment(at: 100, speed: 2, rest: 300, pick: 0, seconds: [1200, 300, 900], another: next).drawn == 1.0 / 3)
}

/// Hold when finished: a finished picture rests for the time picked, the same at any Speed, then clears over its
/// twelve seconds and gives way. Moving the menu never changes the picture, never moves how far it is drawn and
/// never drops the screen into the middle of a clearing: while a picture is drawn nothing changes; while it rests, a
/// longer pick keeps it resting and a shorter one whose time is already past starts the clearing from its
/// beginning, there and then; and a clearing goes on from where it is.
@Test func etchingHoldsAFinishedPicture() {
    typealias Moment = Etching.Cycle.Moment
    let seconds = [600.0, 300, 900], next = { (was: Int) in (was + 1) % 3 }, whole = Moment(picture: 0, before: nil, drawn: 1, cleared: 0, following: nil)
    #expect(Etching.hold.label == "Hold when finished" && Etching.hold.format == .choice(["10 seconds", "30 seconds", "1 minute", "5 minutes"]))
    #expect(Etching.holds == [10, 30, 60, 300] && Etching.holds[Int(Etching.hold.standard)] == 30 && Etching.hold.range == 0...3)
    for rest in Etching.holds {
        for speed in [1, Etching.speed.range.upperBound] {
            var cycle = Etching.Cycle(picture: 0, before: nil, began: 0, paced: speed, rested: rest, following: nil, picked: 0)
            func at(_ wall: Double) -> Moment { cycle.moment(at: wall, speed: speed, rest: rest, pick: 0, seconds: seconds, another: next) }
            let drawing = 600 / speed
            #expect(at(drawing) == whole && at(drawing + rest - 0.01) == whole, "held for \(rest) s at speed \(speed)")
            #expect(abs(at(drawing + rest + 6).cleared - 0.5) < 1e-9 && at(drawing + rest + 12.01).picture == 1, "held for \(rest) s at speed \(speed)")
        }
    }
    /// A picture of 600 s begun at 0 and held for `old` seconds: the moment at `wall`, the moment on the next frame
    /// with the menu moved to `new`, and a way to look at it later.
    func moved(at wall: Double, from old: Double, to new: Double) -> (was: Moment, now: Moment, later: (Double) -> Moment) {
        var cycle = Etching.Cycle(picture: 0, before: nil, began: 0, paced: 1, rested: old, following: nil, picked: 0)
        let was = cycle.moment(at: wall, speed: 1, rest: old, pick: 0, seconds: seconds, another: next)
        let now = cycle.moment(at: wall, speed: 1, rest: new, pick: 0, seconds: seconds, another: next)
        return (was, now, { later in var cycle = cycle; return cycle.moment(at: later, speed: 1, rest: new, pick: 0, seconds: seconds, another: next) })
    }
    for (old, new) in [(30.0, 300.0), (300, 10), (10, 30)] { // while it is drawn: nothing changes, and it rests the new time when done
        let drawing = moved(at: 300, from: old, to: new)
        #expect(drawing.was == Moment(picture: 0, before: nil, drawn: 0.5, cleared: 0, following: nil) && drawing.now == drawing.was, "\(old) to \(new) s while drawing")
        #expect(drawing.later(600 + new - 0.01) == whole && abs(drawing.later(600 + new + 6).cleared - 0.5) < 1e-9)
    }
    // resting, 20 s in: a longer pick keeps it resting, for the new time in all
    let longer = moved(at: 620, from: 30, to: 300)
    #expect(longer.was == whole && longer.now == whole && longer.later(899.99) == whole && abs(longer.later(906).cleared - 0.5) < 1e-9)
    // a shorter one not yet past does the same
    let shorter = moved(at: 620, from: 300, to: 30)
    #expect(shorter.was == whole && shorter.now == whole && shorter.later(629.99) == whole && abs(shorter.later(636).cleared - 0.5) < 1e-9)
    // a shorter one already past, 100 s in: the clearing starts from its beginning, now, and the next picture follows it
    let past = moved(at: 700, from: 300, to: 30)
    #expect(past.was == whole && past.now == whole && abs(past.later(700.12).cleared - 0.01) < 1e-9 && abs(past.later(706).cleared - 0.5) < 1e-9)
    #expect(past.later(711.99).picture == 0 && past.later(712.01).picture == 1 && past.later(712.01).before == 0 && past.later(712.01).cleared == 0)
    // clearing, half-way: it goes on from there, to the same picture, whichever way the menu moves
    for new in [10.0, 60, 300] {
        let clearing = moved(at: 636, from: 30, to: new)
        #expect(clearing.was == Moment(picture: 0, before: nil, drawn: 1, cleared: 0.5, following: 1), "\(clearing.was)")
        #expect(clearing.now.picture == 0 && clearing.now.drawn == 1 && abs(clearing.now.cleared - 0.5) < 1e-9 && clearing.now.following == 1, "30 to \(new) s while clearing: \(clearing.now)")
        #expect(abs(clearing.later(639).cleared - 0.75) < 1e-9 && clearing.later(642.01).picture == 1)
    }
}

/// The scene rests by its menu, at any Speed. A finished picture 16 s on: held for 10 seconds, at the top of the
/// Speed slider, it is half cleared; held for the 30 it comes with, at either end of the slider, it is whole, and
/// half cleared 36 s on.
@MainActor @Test func etchingRestsForTheTimePicked() throws {
    /// The line a finished picture holds as it lands, and `later` seconds after it was finished.
    func line(_ later: Double, _ settings: [String: Double]) throws -> (whole: Int, later: Int) {
        var found = (0, 0)
        try with(settings.merging(["etching.drawn": 1, Etching.picture.key: 1]) { $1 }) {
            let screen = try Screen(756, 491)
            _ = try screen.picture(after: 0.25) // the scene's first frame, when its cycle begins
            for _ in 0..<3 { _ = try screen.picture(after: 0.25) }
            found = (ink(try screen.picture(after: 0.25)), ink(try screen.picture(after: later - 1)))
        }
        return found
    }
    let top = Etching.speed.range.upperBound
    let short = try line(16, [Etching.hold.key: 0, Etching.speed.key: top])
    #expect(short.whole > 756 * 491 && short.later < short.whole * 3 / 4 && short.later > short.whole / 8, "held for 10 s, the line 16 s on: \(short)")
    for speed in [1, top] {
        let resting = try line(16, [Etching.speed.key: speed]), clearing = try line(36, [Etching.speed.key: speed])
        #expect(resting.later == resting.whole, "as it comes, at speed \(speed), the line 16 s on: \(resting)")
        #expect(clearing.later < clearing.whole * 3 / 4 && clearing.later > clearing.whole / 8, "as it comes, at speed \(speed), the line 36 s on: \(clearing)")
    }
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
/// line's middle, though it holds more line). And at either width, fitted inside the screen, nothing is drawn in
/// its top 4%, which the menu bar covers.
@MainActor @Test func etchingDrawsTheFineLine() throws {
    func finished(fine: Double) throws -> [UInt32] {
        var pixels: [UInt32] = []
        try with(["etching.drawn": 1, Etching.picture.key: 2, Etching.detail.key: fine, Etching.fill.key: 0]) { pixels = try Screen(3024, 1964).settled() }
        return pixels
    }
    let standard = try finished(fine: 0), fine = try finished(fine: 1)
    func lines(_ pixels: [UInt32]) -> Int { pixels.count { $0 & 255 < 110 } }
    #expect(lines(fine) > 3024 * 1964 / 40 && fine != standard, "the fine picture has \(lines(fine)) pixels of line and the standard \(lines(standard))")
    // a thinner line has more edge to its middle: of the pixels a line touches, fewer are at full depth (of Paper's
    // blue, 216 on bare ground and 31 on a line gone over: three quarters of the way, of those a quarter of the way)
    func solid(_ pixels: [UInt32]) -> Double { Double(pixels.count { $0 & 255 < 72 }) / Double(pixels.count { $0 & 255 < 166 }) }
    #expect(solid(fine) < solid(standard), "fully dark share of the line: fine \(solid(fine)), standard \(solid(standard))")
    for pixels in [standard, fine] { #expect(!pixels[..<(3024 * (1964 * 4 / 100))].contains { $0 & 255 < 110 }, "a line under the menu bar") }
    // a picture that ships fine only is drawn, and the same, whatever Detail says
    func alone(detail: Double) throws -> [UInt32] {
        var pixels: [UInt32] = []
        let place = try #require(Etching.fineOnly.firstIndex(of: true))
        try with(["etching.drawn": 1, Etching.picture.key: Double(place + 1), Etching.detail.key: detail]) { pixels = try Screen(1512, 982).settled() }
        return pixels
    }
    let asStandard = try alone(detail: 0), asFine = try alone(detail: 1)
    #expect(lines(asStandard) > 1512 * 982 / 20 && asStandard == asFine, "the fine-only picture has \(lines(asStandard)) pixels of line at Standard")
}

/// The ground's level: the middle pixel's blue, which is bare ground whichever of the line and the ground is the
/// lighter. Paper's, which Etching starts on, is 216 in its light tone and 53 in its dark one.
private func level(_ pixels: [UInt32]) -> Int { pixels.map { Int($0 & 255) }.sorted()[pixels.count / 2] }

/// A picture's pixels as colours, red, green and blue of 255: every `step`th of them.
private func colours(_ pixels: [UInt32], every step: Int = 1) -> [SIMD3<Float>] {
    stride(from: 0, to: pixels.count, by: step).map { SIMD3(Float(pixels[$0] >> 16 & 255), Float(pixels[$0] >> 8 & 255), Float(pixels[$0] & 255)) }
}

/// The colour in the middle of some, channel by channel: the bare ground's, the line being the lesser part.
private func middle(_ colours: [SIMD3<Float>]) -> SIMD3<Float> {
    SIMD3(colours.map(\.x).sorted()[colours.count / 2], colours.map(\.y).sorted()[colours.count / 2], colours.map(\.z).sorted()[colours.count / 2])
}

/// Set to Match System, the screen goes to the system's other mode by itself, under the picture: light, then two
/// seconds after Dark Mode comes on, the dark tone.
@MainActor @Test func etchingFollowsTheAppearance() throws {
    defer { NSApplication.shared.appearance = nil }
    try with(["etching.drawn": 0.3, Etching.screen.key: 2]) {
        NSApplication.shared.appearance = NSAppearance(named: .aqua)
        let screen = try Screen(756, 491), light = level(try screen.settled())
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        let partway = level(try screen.picture(after: 1.0 / 30))
        for _ in 0..<75 { _ = try screen.picture(after: 1.0 / 30) }
        let dim = level(try screen.picture(after: 1.0 / 30))
        #expect(abs(light - 216) < 8 && partway > dim + 20 && abs(dim - 53) < 8, "the ground's level: \(light) in Light Mode, \(partway) a frame after Dark Mode, \(dim) after")
    }
}

/// The tone is the one Settings asks for whatever the system's appearance: light as it comes, in Dark Mode, and
/// dark when set to Dark, in Light Mode. Changing the setting eases the screen over, as the appearance does.
@MainActor @Test func etchingScreenIsTheOneAskedFor() throws {
    defer { NSApplication.shared.appearance = nil }
    try with(["etching.drawn": 0.3]) {
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        let screen = try Screen(756, 491), bright = level(try screen.settled())
        UserDefaults.standard.set(1.0, forKey: Etching.screen.key)
        defer { UserDefaults.standard.removeObject(forKey: Etching.screen.key) }
        let partway = level(try screen.picture(after: 1.0 / 30))
        for _ in 0..<75 { _ = try screen.picture(after: 1.0 / 30) }
        let dimmed = level(try screen.picture(after: 1.0 / 30))
        #expect(abs(bright - 216) < 8 && partway > dimmed + 20 && abs(dimmed - 53) < 8, "in Dark Mode the ground's level is \(bright) as it comes, \(partway) a frame after Dark is picked, \(dimmed) after")
        NSApplication.shared.appearance = NSAppearance(named: .aqua)
        let dim = level(try Screen(756, 491).settled())
        #expect(abs(dim - 53) < 8, "set to Dark in Light Mode the ground's level is \(dim)")
    }
}

/// Follow Day and Night, the Screen menu's last pick, after the three that were there: the ground is light with the
/// Sun 6° or more above the horizon, dark with it as far below, and half-way between with it on the horizon, by a
/// smoothstep (`nightfall` is where the shade goes, which `tint` eases). The Sun is `etching.sun`'s here. As it sets
/// the screen follows it, within half a minute and then over two seconds.
@MainActor @Test func etchingFollowsDayAndNight() throws {
    #expect(Etching.screen.format == .choice(["Light", "Dark", "Match System", "Follow Day and Night"]) && Etching.screen.range == 0...3 && Etching.screen.standard == 0)
    #expect(Etching.nightfall(sun: 10) == 0 && Etching.nightfall(sun: 0) == 0.5 && Etching.nightfall(sun: -10) == 1)
    #expect(Etching.nightfall(sun: 6) == 0 && Etching.nightfall(sun: 3) == 0.25 && Etching.nightfall(sun: -6) == 1)
    defer { NSApplication.shared.appearance = nil }
    NSApplication.shared.appearance = NSAppearance(named: .darkAqua) // which this pick takes no notice of
    func screen(sun: Double) throws -> Int {
        var found = 0
        try with(["etching.drawn": 0.3, Etching.screen.key: 3, "etching.sun": sun]) { found = level(try Screen(756, 491).settled()) }
        return found
    }
    let day = try screen(sun: 10), night = try screen(sun: -10), dusk = try screen(sun: 0)
    #expect(abs(day - 216) < 8 && abs(night - 53) < 8 && abs(2 * dusk - day - night) < 6, "the ground's level with the Sun at 10°, 0° and -10°: \(day), \(dusk), \(night)")
    try with(["etching.drawn": 0.3, Etching.screen.key: 3, "etching.sun": 10]) {
        let screen = try Screen(756, 491), bright = level(try screen.settled())
        UserDefaults.standard.set(-10.0, forKey: "etching.sun")
        let before = level(try screen.picture(after: 20)), partway = level(try screen.picture(after: 11)) // looked up every 30 s
        for _ in 0..<25 { _ = try screen.picture(after: 0.1) }
        let dimmed = level(try screen.picture(after: 0.1))
        #expect(before == bright && partway > dimmed + 20 && dimmed == night, "the Sun gone down: \(bright), \(before) 20 s on, \(partway) once it is looked up, \(dimmed) after")
    }
}

/// The Surface menu, above Screen: Paper, which Etching starts on, Parchment, Blueprint and Powder. A bare screen of
/// each, in its light tone and its dark one, is the colour its entry gives, to a couple of levels; is not flat, by
/// the render test's own measure (more than 20 colours among some 6,000 pixels); and is clean: averaged over blocks
/// 56 pixels square, which take in as much as a 16-pixel blur, neighbouring blocks differ by under 0.3% of the
/// level. (Neighbours, so that the light from the upper left, which is the same step from each block to the next,
/// is left out. Blurred by 16 pixels, the cloudy powder these replaced spread by 1.2% of its level and these by
/// 0.06% to 0.17%: docs/etching.md.)
@MainActor @Test func etchingSurfacesHaveTheirGrounds() throws {
    #expect(Etching.surface.format == .choice(["Paper", "Parchment", "Blueprint", "Powder"]) && Etching.surface.range == 0...3 && Etching.surface.standard == 0)
    #expect(Etching.knobs.map(\.label) == ["Picture", "Detail", "Speed", "Hold when finished", "Surface", "Screen", "Fill the screen"])
    let (w, h, block) = (1512, 982, 56)
    for (place, surface) in Etching.surfaces.enumerated() {
        for dark in [false, true] {
            var pixels: [UInt32] = []
            try with(["etching.drawn": 0, Etching.picture.key: 1, Etching.surface.key: Double(place), Etching.screen.key: dark ? 1 : 0]) { pixels = try Screen(w, h).settled() }
            let ground = middle(colours(pixels, every: 31)), table = (dark ? surface.ground.dark : surface.ground.light) * 255
            let varied = Set(stride(from: 0, to: pixels.count, by: 251).map { pixels[$0] }).count
            // the blocks' mean green, row by row, clear of the line's first step at the lower left; then each from its neighbour
            let means = (0..<h / block).map { by in (3..<w / block).map { bx in
                (0..<block * block).reduce(0) { $0 + Float(pixels[(by * block + $1 / block) * w + bx * block + $1 % block] >> 8 & 255) } / Float(block * block)
            } }
            let steps = means.flatMap { row in zip(row, row.dropFirst()).map { $1 - $0 } }, mean = steps.reduce(0, +) / Float(steps.count)
            let spread = (steps.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Float(steps.count) / 2).squareRoot() / ground.y * 100
            #expect(simd_reduce_max(simd_abs(ground - table)) <= 2 && varied > 20 && spread < 0.3,
                    "\(surface.name), \(dark ? "dark" : "light"): the ground is \(ground) for \(table), with \(varied) colours, and its blocks' spread is \(spread)%")
        }
    }
}

/// How far the line gone over is from the bare ground, in levels, the mean of red, green and blue, and whether it is
/// the lighter: the pixel a hundredth from the far end, every picture here having more line gone over than that.
private func contrast(_ pixels: [UInt32]) -> (levels: Float, lighter: Bool) {
    let some = colours(pixels, every: 7), ground = middle(some)
    let far = some.map { simd_reduce_add($0 - ground) / 3 }.sorted { abs($0) < abs($1) }[some.count * 99 / 100]
    return (abs(far), far > 0)
}

/// Picking another surface eases the ground, the line and the tooth over to it in two seconds, under the picture,
/// with nothing rebuilt: from Paper to Powder the ground is part of the way a second in and Powder's after, and the
/// line is all still there.
@MainActor @Test func etchingChangesSurface() throws {
    func lines(_ pixels: [UInt32]) -> Int { pixels.count { $0 & 255 < 110 } }
    try with(["etching.drawn": 0.7, Etching.picture.key: 1]) {
        let screen = try Screen(1512, 982), paper = try screen.settled()
        UserDefaults.standard.set(3.0, forKey: Etching.surface.key)
        defer { UserDefaults.standard.removeObject(forKey: Etching.surface.key) }
        for _ in 0..<29 { _ = try screen.picture(after: 1.0 / 30) }
        let partway = try screen.picture(after: 1.0 / 30)
        for _ in 0..<32 { _ = try screen.picture(after: 1.0 / 30) }
        let powder = try screen.picture(after: 1.0 / 30), still = try screen.picture(after: 1)
        #expect(abs(level(paper) - 216) < 4 && abs(level(partway) - 183) < 8 && abs(level(powder) - 151) < 4, "the ground's level: \(level(paper)), \(level(partway)) a second in, \(level(powder)) after")
        #expect(contrast(paper).levels > 150 && contrast(powder).levels > 80 && !contrast(powder).lighter, "the line is \(contrast(paper)) from Paper's ground and \(contrast(powder)) from Powder's")
        // (as dark as that, which on Powder's darker ground more of a line's soft edge is)
        #expect(lines(paper) > 1512 * 982 / 12 && abs(lines(powder) - lines(paper)) < lines(paper) / 5, "pixels of line: \(lines(paper)) on Paper, \(lines(powder)) on Powder")
        // settled: nothing more moves but the stylus, a second's worth
        #expect(level(still) == level(powder) && zip(powder, still).count { $0 != $1 } < 1512 * 982 / 100)
    }
}

/// The line reads through dusk. On Paper, Parchment and Blueprint the line is darker than the ground in the light
/// tone and lighter in the dark one, so it does not go by the shade, which would leave it the ground's own colour
/// half-way: it is the light tone's line until the shade is past a half and the dark tone's after. Under Follow Day
/// and Night with the Sun half a degree up and half a degree down, on every surface, the line gone over is 60
/// levels or more from the ground, and on those three it is the darker before sunset and the lighter after. And in
/// a running scene it crosses by itself, in two seconds, once the Sun is down.
@MainActor @Test func etchingLineReadsThroughDusk() throws {
    for (place, surface) in Etching.surfaces.enumerated() {
        for sun in [0.5, -0.5] {
            var found = (levels: Float(0), lighter: false)
            try with(["etching.drawn": 0.7, Etching.picture.key: 1, Etching.surface.key: Double(place), Etching.screen.key: 3, "etching.sun": sun]) { found = contrast(try Screen(1512, 982).settled()) }
            let chalk = simd_reduce_add(surface.line.dark - surface.ground.dark) > 0
            #expect(found.levels >= 60 && found.lighter == (chalk && sun < 0), "\(surface.name), the Sun at \(sun)°: the line is \(found.levels) levels from the ground, lighter \(found.lighter)")
        }
    }
    try with(["etching.drawn": 0.7, Etching.picture.key: 1, Etching.screen.key: 3, "etching.sun": 0.5]) {
        let screen = try Screen(1512, 982), before = contrast(try screen.settled())
        UserDefaults.standard.set(-0.5, forKey: "etching.sun")
        _ = try screen.picture(after: 31)
        for _ in 0..<25 { _ = try screen.picture(after: 0.1) }
        let after = contrast(try screen.picture(after: 0.1))
        #expect(before.levels >= 60 && !before.lighter && after.levels >= 60 && after.lighter, "Paper as the Sun goes down: the line is \(before) from the ground, then \(after)")
    }
}

/// Fill the screen, which is on unless it is turned off: a picture squarer than the display (the Interlace, 1.21
/// wide for 1 high, on a 14-inch screen's 1.54) is scaled up until it covers it, so its line runs off the top and
/// the bottom; on the same screen turned upright, off the left and the right. Turned off, the picture is fitted
/// inside as it was: nothing is drawn at any edge, nor in the top 4%. And a picture kept whole (the Airship, wider
/// than the screen, which filling would cut at both ends) is fitted inside whichever way the switch is.
@MainActor @Test func etchingFillsTheScreen() throws {
    func finished(_ file: String, _ w: Int, _ h: Int, _ settings: [String: Double] = [:]) throws -> [UInt32] {
        var pixels: [UInt32] = []
        let picture = Double(try #require(Etching.pictures.firstIndex { $0.file == file }) + 1)
        try with(settings.merging(["etching.drawn": 1, Etching.picture.key: picture]) { $1 }) { pixels = try Screen(w, h).settled() }
        return pixels
    }
    /// Pixels of line in the outer hundredth of a screen at its left, right, top and bottom.
    func edges(_ pixels: [UInt32], _ w: Int, _ h: Int) -> [Int] {
        func lines(_ xs: Range<Int>, _ ys: Range<Int>) -> Int { ys.reduce(0) { sum, y in sum + xs.count { pixels[y * w + $0] & 255 < 110 } } }
        return [lines(0..<w / 100, 0..<h), lines(w - w / 100..<w, 0..<h), lines(0..<w, 0..<h / 100), lines(0..<w, h - h / 100..<h)]
    }
    let (w, h) = (3024, 1964), wide = edges(try finished("interlace", w, h), w, h), upright = edges(try finished("interlace", h, w), h, w)
    #expect(wide[2] > 2000 && wide[3] > 2000 && upright[0] > 2000 && upright[1] > 2000, "pixels of line at the left, right, top and bottom: \(wide), and upright \(upright)")
    let fitted = try finished("interlace", w, h, [Etching.fill.key: 0])
    #expect(edges(fitted, w, h) == [0, 0, 0, 0] && !fitted[..<(w * (h * 4 / 100))].contains { $0 & 255 < 110 }, "fitted, a line at an edge or under the menu bar")
    let whole = try finished("airship", w, h), asFitted = try finished("airship", w, h, [Etching.fill.key: 0])
    #expect(Etching.whole.contains("airship") && edges(whole, w, h) == [0, 0, 0, 0] && whole == asFitted,
            "the Airship with Fill the screen on has line at its edges, \(edges(whole, w, h)), or is not as it is fitted")
}

/// What shows of a route stamped for a display `w` by `h`, fitted or filling: the longest stretch, in seconds at
/// speed 1, in which no texel of the line changes (none is drawn and none gone over), from the first moment to the
/// last change; and how long the drawing takes there. The texels the menu bar covers don't show.
private func stillness(_ route: LineRoute, _ w: Int, _ h: Int, fill: Bool) -> (longest: Double, drawing: Double) {
    let at = Etching.placement(of: route, across: w, down: h, fill: fill)
    let stamped = route.stamp(width: w, height: h, scale: at.scale, dx: at.dx, dy: at.dy, covered: at.covered)
    // every change marked at its time, to 16 of the 24 bits' units: 5 to 9 ms
    var marks = [Bool](repeating: false, count: 1 << 20), last = 0
    stamped.when.withUnsafeBytes { (when: UnsafeRawBufferPointer) in stamped.more.withUnsafeBytes { (more: UnsafeRawBufferPointer) in marks.withUnsafeMutableBufferPointer { marks in
        for p in 0..<w * Int(Double(h) - at.covered) where when[p * 4 + 3] > 127 { // bottom row first: the menu bar's are the last
            let drawn = Int(when[p * 4]) << 16 | Int(when[p * 4 + 1]) << 8 | Int(when[p * 4 + 2]), again = Int(more[p * 4]) << 16 | Int(more[p * 4 + 1]) << 8 | Int(more[p * 4 + 3])
            marks[drawn >> 4] = true
            last = max(last, drawn)
            if again != 0xFF_FFFF { marks[again >> 4] = true; last = max(last, again) }
        }
    } } }
    var longest = 0, run = 0
    for mark in marks[...(last >> 4)] {
        run = mark ? 0 : run + 1
        longest = max(longest, run)
    }
    let seconds = route.clock / LineRoute.end / (Double(route.columns) / 40) // to a unit, the stylus crossing a fortieth of the grid a second
    return (Double(longest * 16) * seconds, Double(last) * seconds)
}

/// A picture that fills the screen is cut off at the display's edges and runs under the menu bar, and nothing waits
/// for the stylus while it is out there or under it. For every route a picture ships, on a 14-inch screen with
/// Fill the screen on: the longest stretch in which nothing that shows changes is under two and a half seconds,
/// and the drawing is done no later than fitted. Prints both for each, filling and fitted. (That a spell be no
/// longer than fitted is not asked: one texel changing in the middle of a run splits it, so that compares noise.)
@MainActor @Test func etchingNeverWaitsOutOfSight() throws {
    for (place, picture) in Etching.pictures.enumerated() {
        for fine in [false, true] where fine || !Etching.fineOnly[place] {
            let route = try #require(LineRoute(try Data(contentsOf: resource("etching-\(picture.file)\(fine ? "-fine" : "").route"))))
            let fitted = stillness(route, 3024, 1964, fill: false), filled = stillness(route, 3024, 1964, fill: Etching.fills(place, asked: true))
            let found = String(format: "%@%@: still for %.2f s at the most filling the screen and %.2f s fitted; drawn in %.1f min and %.1f", picture.name, fine ? ", fine" : "",
                               filled.longest, fitted.longest, filled.drawing / 60, fitted.drawing / 60)
            print("Etching, \(found)")
            #expect(filled.longest < 2.5 && filled.drawing <= fitted.drawing, "\(found)")
        }
    }
}
