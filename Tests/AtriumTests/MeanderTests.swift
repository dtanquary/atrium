import Foundation
import Metal
import SpriteKit
import Synchronization
import Testing
import simd
@testable import Atrium
@testable import MeanderRiver

/// How many times a river's centreline crosses itself, every segment against every other but its neighbours.
private func crossings(_ river: River) -> Int {
    let n = river.nodes.count
    let points = (0...n).map { SIMD2(river.nodes[$0 % n].x + ($0 == n ? river.period : 0), river.nodes[$0 % n].y) }
    func side(_ a: SIMD2<Float>, _ b: SIMD2<Float>, _ c: SIMD2<Float>) -> Float { (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x) }
    var count = 0
    for i in 0..<n {
        for j in stride(from: i + 2, to: n, by: 1) where !(i == 0 && j == n - 1) {
            let (a, b, c, d) = (points[i], points[i + 1], points[j], points[j + 1])
            if side(a, b, c) * side(a, b, d) < 0, side(c, d, a) * side(c, d, b) < 0 { count += 1 }
        }
    }
    return count
}

/// The prototype's check, on the real thing: over 6,000 coarse steps (T 240) a straight river grows bends and cuts
/// loops off, never crosses itself, and stays between the valley's walls.
@Test func riverCutsOffLoopsAndNeverCrosses() {
    let river = River(seed: 3, across: 54, up: 35.07, texels: 14)
    for _ in 0..<12 {
        river.age(distant: 0, recent: 20)
        #expect(crossings(river) == 0, "crossed itself by T \(river.now)")
        #expect(river.nodes.allSatisfy { $0.x.isFinite && $0.y - $0.half > 0 && $0.y + $0.half < river.up }, "left the valley by T \(river.now)")
    }
    #expect(river.cutoffs > 5 && river.sinuosity > 1.5, "\(river.cutoffs) cutoffs, sinuosity \(river.sinuosity)")
    #expect(river.nodes.count > 150 && river.nodes.count < 1200)
}

/// Stepped by 1/15, 1/30 or 1/60 of a second for the same time, the river and the ground are the same to the last
/// bit: it steps by the time gone by, not by the frame. At speed 4 too, where it steps twice as often.
@Test func riverIsTheSameAtAnyFrameRate() {
    func run(_ frames: Double) -> River {
        let river = River(seed: 5, across: 27, up: 17.5, texels: 8) // a small valley, to keep a debug build quick
        river.age(distant: 40, recent: 30)
        for _ in 0..<Int(8 * frames) { river.advance(1 / frames) }
        for _ in 0..<Int(4 * frames) { river.advance(1 / frames, speed: 4) }
        return river
    }
    let (slow, usual, fast) = (run(15), run(30), run(60))
    #expect(slow.now > 71.8 && slow.now < 72.0, "T \(slow.now)") // 70, then 8 s at 12.5 s a T and 4 s at four times that
    for other in [usual, fast] {
        #expect(other.now == slow.now && other.nodes.count == slow.nodes.count)
        #expect(zip(other.nodes, slow.nodes).allSatisfy { $0.x == $1.x && $0.y == $1.y && $0.half == $1.half })
        #expect(other.pixels == slow.pixels)
    }
}

/// The stamps are 16 bits counted from a base that moves up with the time, a turn of the high byte at once, so
/// that they never run out. After 660 T it has moved; ground the river has just left still reads as just left,
/// nothing reads as later than now, and no stamp is older than the ground's memory and a turn.
@Test func riverMovesItsStampsUpBeforeTheyRunOut() {
    let river = River(seed: 9, across: 27, up: 17.5, texels: 8)
    river.age(distant: 640, recent: 20)
    let sinceBase = river.now - river.base, oldest = sinceBase - River.memory - 5
    #expect(river.base > 0 && oldest >= 0 && oldest < River.turn + 0.5, "base \(river.base) at T \(river.now)")
    let stamps = (0..<river.columns * river.rows).map { Double(Int(river.pixels[$0 * 4]) << 8 | Int(river.pixels[$0 * 4 + 1])) / 100 }
    let latest = stamps.max()!
    #expect(latest <= sinceBase + 0.01 && latest > sinceBase - 0.5, "the latest stamp is \(latest), and now is \(sinceBase)")
    #expect(stamps.min()! >= oldest - 0.011 && stamps.count { $0 > oldest + 0.011 } > stamps.count / 3)
}

/// A new river's past: by the first frame the ground has been worked edge to edge of the belt, the river and its
/// lakes are drawn as water, and hollows mark old channels. And how long that takes, which every load, shuffle and
/// Settings page waits for on the main thread, and what a live step costs after it. (The river's module is built
/// optimised even in a debug build, so the times mean the same in both.) The times are printed, and the past's is
/// held to 150 ms only with MEANDER_COSTS set (`measuring`).
@Test func riverGetsAPastQuickly() {
    func milliseconds(_ body: () -> Void) -> Double {
        let start = DispatchTime.now().uptimeNanoseconds
        body()
        return Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6
    }
    let seeds: [UInt64] = [11, 12, 13, 14, 15, 13] // the last one is looked at below
    var river = River(seed: 1, across: 54, up: 35.07, texels: 14), times: [Double] = []
    for seed in seeds {
        river = River(seed: seed, across: 54, up: 35.07, texels: 14)
        times.append(milliseconds { river.age() })
    }
    let texels = river.columns * river.rows
    let oldest = Float(river.now - river.base - River.memory - 5) // ground never reached is kept at this
    let stamped = river.ground.count { $0.x > oldest }
    let water = (0..<texels).count { river.pixels[$0 * 4 + 2] < 127 }, hollow = (0..<texels).count { river.pixels[$0 * 4 + 3] < 140 }
    let lakeWater = river.ground.count { $0.w < 0.5 }, width = 2 * river.nodes.reduce(0) { $0 + $1.half } / Float(river.nodes.count)
    print("Meander's past, T 240 coarse then T 60, for a 28 pt river: \(times.map { String(format: "%.0f", $0) }.joined(separator: ", ")) ms")
    print(String(format: "  the last: %d nodes, sinuosity %.2f, mean width %.2f, %d cutoffs, %d lakes; stamped %.0f%%, water %.1f%% (lakes %.1f%%), hollow %.1f%%",
                 river.nodes.count, river.sinuosity, width, river.cutoffs, river.lakes.count, 100 * Double(stamped) / Double(texels),
                 100 * Double(water) / Double(texels), 100 * Double(lakeWater) / Double(texels), 100 * Double(hollow) / Double(texels)))
    #expect(river.now > 299 && river.now < 301)
    #expect(Double(stamped) / Double(texels) > 0.5, "only \(stamped) of \(texels) texels have a past")
    #expect(Double(water) / Double(texels) > 0.03 && Double(water) / Double(texels) < 0.3)
    #expect(hollow > 0 && crossings(river) == 0)
    // the river's own nodes are under water, where they are on screen
    for node in river.nodes where node.x > 1 && node.x < river.across - 1 {
        let at = Int(node.y * river.texels) * river.columns + Int(node.x * river.texels)
        #expect(river.pixels[at * 4 + 2] < 127, "the node at \(node.x), \(node.y) is dry")
    }
    if let folder = ProcessInfo.processInfo.environment["MEANDER_DUMP"] { // the texture's bytes, to look at
        try? Data(river.pixels).write(to: URL(fileURLWithPath: folder).appendingPathComponent("meander-\(river.columns)x\(river.rows).rgba"))
    }
    #expect(!measuring || times.min()! < 150, "the past took \(times) ms")
    // The banks in the ground against the long way, which splits each segment in two as the prototype did: near a
    // bank (two texels either side), at every fifth texel
    var off: [Float] = []
    for i in stride(from: 0, to: texels, by: 5) where abs(river.ground[i].z - 0.5) < 2 / river.texels {
        let point = SIMD2(Float(i % river.columns) + 0.5, Float(i / river.columns) + 0.5) / river.texels
        off.append(abs(river.bankDistance(at: point) - river.ground[i].z) * river.texels)
    }
    off.sort()
    print(String(format: "  its banks against the prototype's, at %d texels: half within %.3f of a texel, 99 in 100 within %.3f, the worst %.2f",
                 off.count, off[off.count / 2], off[off.count * 99 / 100], off.last!))
    #expect(off[off.count * 99 / 100] < 0.25 && off.last! < 1)
    // No cracks in the ground a past leaves: land that is over 3 T older than the land on both sides of it, across
    // or up, is a texel or two the sweep missed
    var cracks = 0, land = 0
    for y in 1..<river.rows - 1 { for x in 1..<river.columns - 1 {
        let i = y * river.columns + x, here = river.ground[i]
        guard min(here.z, here.w) > 0.5 + 2 / river.texels, here.x > oldest else { continue }
        land += 1
        func newer(_ a: Int, _ b: Int) -> Bool { river.ground[a].x > here.x + 3 && river.ground[b].x > here.x + 3 }
        if newer(i - 1, i + 1) || newer(i - river.columns, i + river.columns) { cracks += 1 }
    } }
    print(String(format: "  cracks in its ground: %d of %d land texels (%.2f%%)", cracks, land, 100 * Double(cracks) / Double(land)))
    #expect(Double(cracks) / Double(land) < 0.004)
    // then a minute of live steps, ten a second
    var steps: [Double] = []
    for _ in 0..<600 { steps.append(milliseconds { river.advance(0.1) }) }
    steps.sort()
    print(String(format: "  a live step with the ground and %d lakes: median %.2f ms, 99 in 100 under %.2f, the slowest of 600 %.2f; the lakes are at most %.2f texels out of date",
                 river.lakes.count, steps[300], steps[594], steps[599], river.lakesAdrift() * river.texels))
    #expect(steps[300] < 1.5)
}

/// Only a couple of lakes are drawn again on each step. Over 24 T at speed 4, long enough for every lake there at
/// the start to dry up and for others to be cut off, trimmed and run into each other, the lakes' water in the
/// ground is never half a texel from where drawing every lake afresh would put it: none is left behind when a lake
/// goes, and none is lost where two overlap.
@Test func riverKeepsItsLakesUpToDate() {
    let river = River(seed: 7, across: 27, up: 17.5, texels: 8)
    river.age(distant: 40, recent: 30)
    var worst: Float = 0, most = 0, born = river.cutoffs
    for _ in 0..<30 {
        for _ in 0..<50 { river.advance(0.05, speed: 4) }
        (worst, most) = (max(worst, river.lakesAdrift() * river.texels), max(most, river.lakes.count))
    }
    born = river.cutoffs - born
    print(String(format: "Meander's lakes over T 24 at speed 4: %d cut off, %d at once at most, never more than %.2f texels out of date", born, most, worst))
    #expect(born > 3 && worst < 0.5)
}

/// Draws a scene offscreen as SpriteKit would on a display `w` by `h` pixels, and times each frame.
@MainActor private final class Offscreen {
    let renderer: SKRenderer, queue: MTLCommandQueue, target: MTLTexture, pass = MTLRenderPassDescriptor()
    let (w, h): (Int, Int)
    private let start = ProcessInfo.processInfo.systemUptime + 1 // the renderer's first update runs on the system's clock
    private var frames = 0

    init(_ scene: SKScene, _ w: Int, _ h: Int) throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        (renderer, queue, target) = (SKRenderer(device: device), try #require(device.makeCommandQueue()), try #require(device.makeTexture(descriptor: descriptor)))
        (self.w, self.h) = (w, h)
        renderer.scene = scene
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
    }

    /// The next frame, `rate` of them a second: the milliseconds its update took, the CPU's share of drawing it,
    /// and the GPU's.
    @discardableResult func frame(rate: Double = 30) throws -> (update: Double, draw: Double, gpu: Double) {
        let clock = ContinuousClock(), began = clock.now
        renderer.update(atTime: start + Double(frames) / rate)
        frames += 1
        let updated = clock.now, buffer = try #require(queue.makeCommandBuffer())
        renderer.render(withViewport: CGRect(x: 0, y: 0, width: w, height: h), commandBuffer: buffer, renderPassDescriptor: pass)
        buffer.commit()
        buffer.waitUntilCompleted()
        func ms(_ span: Duration) -> Double { Double(span.components.attoseconds) / 1e15 + Double(span.components.seconds) * 1000 }
        let gpu = (buffer.gpuEndTime - buffer.gpuStartTime) * 1000
        return (ms(updated - began), ms(clock.now - updated) - gpu, gpu)
    }

    /// The next frame's update with nothing drawn, for running a scene on to where something happens.
    func advance(rate: Double = 30) {
        renderer.update(atTime: start + Double(frames) / rate)
        frames += 1
    }

    /// What was drawn: each pixel's red, green, blue and alpha, top row first.
    var pixels: [SIMD4<UInt8>] { piece(x: 0, y: 0, w: w, h: h).map { [UInt8($0 >> 16 & 255), UInt8($0 >> 8 & 255), UInt8($0 & 255), UInt8($0 >> 24)] } }

    /// A piece of what was drawn, a pixel to a word (blue lowest), top row first; the piece is kept on the screen.
    func piece(x: Int, y: Int, w: Int, h: Int) -> [UInt32] {
        var raw = [UInt32](repeating: 0, count: w * h)
        target.getBytes(&raw, bytesPerRow: w * 4, from: MTLRegionMake2D(min(max(x, 0), self.w - w), min(max(y, 0), self.h - h), w, h), mipmapLevel: 0)
        return raw
    }
}

/// The share of pixels that differ by over 20 levels in any of red, green and blue between two pictures.
private func popped(_ a: [UInt32], _ b: [UInt32]) -> Double { changed(a, b).share }

/// That share, and how much the two pictures differ in all: the levels a pixel changes by (the most of its red,
/// green and blue), averaged over every pixel.
private func changed(_ a: [UInt32], _ b: [UInt32]) -> (share: Double, levels: Double) {
    var (count, sum) = (0, 0)
    a.withUnsafeBufferPointer { a in b.withUnsafeBufferPointer { b in
        for i in 0..<a.count where a[i] != b[i] {
            let (p, q) = (a[i], b[i])
            let most = max(abs(Int(p & 255) - Int(q & 255)), abs(Int(p >> 8 & 255) - Int(q >> 8 & 255)), abs(Int(p >> 16 & 255) - Int(q >> 16 & 255)))
            sum += most
            if most > 20 { count += 1 }
        }
    } }
    return (Double(count) / Double(a.count), Double(sum) / Double(a.count))
}

private func save(_ pixels: [UInt32], _ w: Int, _ h: Int, to url: URL) {
    guard let image = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                              provider: CGDataProvider(data: Data(bytes: pixels, count: w * h * 4) as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent),
          let to = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(to, image, nil)
    CGImageDestinationFinalize(to)
}

/// Whether a test may fail on how long something took: only with MEANDER_COSTS set, for a run made to measure on a
/// quiet Mac. An ordinary run prints the times and asks nothing of them: with other builds going, the same frames
/// took several times as long and failed every suite that ran then.
private let measuring = ProcessInfo.processInfo.environment["MEANDER_COSTS"] != nil

/// Settings for a river the tests can make twice: its seed, with any others on top.
private func seeded(_ seed: Double, _ others: [String: Double] = [:]) -> [String: Double] {
    ["meander.seed": seed].merging(others) { $1 }
}

/// With Settings values for the length of `body`, as the render test sets them, and each look's colours, which
/// Settings would otherwise pick at random for each scene, so that a picture can be made twice.
@MainActor private func with(_ settings: [String: Double], colours: [String] = ["Survey Blue", "Fisk 1944"], _ body: () throws -> Void) rethrows {
    defer { (settings.keys + Meander.palettes.map(\.key)).forEach(UserDefaults.standard.removeObject) }
    for (key, value) in settings { UserDefaults.standard.set(value, forKey: key) }
    for (palette, name) in zip(Meander.palettes, colours) { UserDefaults.standard.set(name, forKey: palette.key) }
    try body()
}

/// The ground reaches a shader as the river wrote it: all four bytes of every texel, the fourth too, which
/// SpriteKit would treat as how see-through a picture is and which here is the hollows. A texture that can be
/// changed is drawn a pixel to a texel by a shader that passes the bytes on, and they come back the same, the
/// river's first row at the bottom of the screen. And the bytes are taken while `modifyPixelData` is being called,
/// not later: the scene hands it the river's own buffer, which the next step writes on.
@MainActor @Test func meanderGroundReachesTheShader() throws {
    let river = River(seed: 5, across: 27, up: 17.5, texels: 8)
    river.age(distant: 40, recent: 30)
    let (w, h) = (river.columns, river.rows), texture = SKMutableTexture(size: CGSize(width: w, height: h)), taken = Mutex(false)
    let bytes = river.pixels
    texture.modifyPixelData { data, length in
        bytes.withUnsafeBytes { data?.copyMemory(from: $0.baseAddress!, byteCount: min(length, $0.count)) }
        taken.withLock { $0 = true }
    }
    #expect(taken.withLock { $0 }, "the bytes were not taken during the call")
    let scene = SKScene(size: CGSize(width: w, height: h)), sprite = SKSpriteNode(texture: texture, size: scene.size), fourth = SKUniform(name: "u_fourth", float: 0)
    sprite.anchorPoint = .zero
    sprite.shader = SKShader(source: "void main() { vec4 t = texture2D(u_texture, v_tex_coord); gl_FragColor = u_fourth > 0.5 ? vec4(t.a, t.a, t.a, 1.0) : vec4(t.rgb, 1.0); }",
                             uniforms: [fourth])
    scene.addChild(sprite)
    let screen = try Offscreen(scene, w, h)
    for _ in 0..<2 { try screen.frame() } // the first frame can go by before a shader has compiled
    let colours = screen.pixels
    fourth.floatValue = 1
    try screen.frame()
    let hollows = screen.pixels
    var wrong = 0
    for y in 0..<h { for x in 0..<w {
        let texel = ((h - 1 - y) * w + x) * 4, drawn = colours[y * w + x]
        if drawn.x != bytes[texel] || drawn.y != bytes[texel + 1] || drawn.z != bytes[texel + 2] || hollows[y * w + x].x != bytes[texel + 3] { wrong += 1 }
    } }
    #expect(wrong == 0, "\(wrong) of \(w * h) texels reached the shader changed")
    #expect(Set(stride(from: 3, to: bytes.count, by: 4).map { bytes[$0] }).count > 50) // and the fourth byte was worth checking
}

/// Each look is a shader of its own, put together as text that only the GPU's compiler ever checks. All three draw
/// a picture, and not the same one: relief, the old map with each stage's ink fixed to its land, and in Fisk's
/// order. So does every colourway among Settings' swatches, relief's and the map's, in Light Mode and in Dark; and
/// relief in Light is on paper, where in Dark its unworked ground is the darkest thing.
@MainActor @Test func meanderDrawsEveryLook() throws {
    var pictures: [[SIMD4<UInt8>]] = []
    func draw(_ settings: [String: Double], relief: String = "Survey Blue", sheet: String = "Fisk 1944") throws {
        try with(seeded(7, settings), colours: [relief, sheet]) {
            let screen = try Offscreen(Meander(size: CGSize(width: 756, height: 491)), 756, 491)
            for _ in 0..<2 { try screen.frame() }
            pictures.append(screen.pixels)
        }
        #expect(Set(stride(from: 0, to: pictures.last!.count, by: 97).map { pictures.last![$0] }).count > 20, "\(settings) in \(relief) and \(sheet) drew a flat picture")
        // A shader that didn't compile leaves the ground's own bytes on the screen, which are no flat picture: but
        // their blue is the water byte, full wherever there is no water near, as in the corner
        #expect(pictures.last![756 * 5 + 5].z < 240, "\(settings) in \(relief) and \(sheet) drew the ground's bytes, not a picture")
    }
    for look: [String: Double] in [[:], ["meander.look": 1], ["meander.look": 1, "meander.rule": 1]] { try draw(look) }
    #expect(pictures[0] != pictures[1] && pictures[1] != pictures[2])
    let before = NSApplication.shared.appearance
    defer { NSApplication.shared.appearance = before }
    for name in [NSAppearance.Name.aqua, .darkAqua] {
        NSApplication.shared.appearance = NSAppearance(named: name)
        for relief in Meander.reliefs {
            try draw([:], relief: relief.name)
            let corner = pictures.last![756 * 5 + 5] // ground the river never reached
            #expect(name == .aqua ? corner.y > 200 : corner.y < 60, "\(relief.name) in \(name.rawValue): its unworked ground is \(corner)")
        }
        for sheet in Meander.maps { for rule in 0...1 { try draw(["meander.look": 1, "meander.rule": Double(rule)], sheet: sheet.name) } }
    }
    #expect(Set(pictures.dropFirst(3).map { $0[$0.count / 2 + 378] }).count > 12) // the colourways differ, by the pixel in the middle
}

/// Swatches under a menu (`Wallpaper.looks`) hang together, for every wallpaper that has them: each set names a
/// menu among its wallpaper's knobs and a pick that menu has, no two sets share a pick or a key (nor a knob's), and
/// every swatch has colours for both modes. Only Meander has them so far: every other wallpaper's page is as it was.
@MainActor @Test func swatchesUnderAMenuHangTogether() {
    for wallpaper in allScenes where !wallpaper.looks.isEmpty {
        for look in wallpaper.looks {
            let menu = wallpaper.knobs.first { $0.key == look.shownWhen }, pick = look.shownAt ?? -1
            if case .choice(let names)? = menu?.format {
                #expect(names.indices.contains(Int(pick)) && pick == pick.rounded(), "\(look.key) hangs on pick \(pick) of \(names)")
            } else {
                Issue.record("\(look.key) hangs on \(look.shownWhen ?? "nothing"), which is no menu of \(wallpaper.name)'s")
            }
            #expect(!look.options.isEmpty && look.options.allSatisfy { !$0.dark.isEmpty && !$0.light.isEmpty } && Set(look.options.map(\.name)).count == look.options.count)
            #expect(look.standard.isEmpty || look.options.contains { $0.name == look.standard })
        }
        let keys = wallpaper.looks.map(\.key) + wallpaper.knobs.map(\.key) + [wallpaper.palettes?.key].compactMap { $0 }
        #expect(Set(keys).count == keys.count, "\(wallpaper.name) stores two settings under one key")
        #expect(Set(wallpaper.looks.map { "\($0.shownWhen ?? "") \($0.shownAt ?? -1)" }).count == wallpaper.looks.count, "\(wallpaper.name) has two sets of swatches for one pick")
    }
    #expect(allScenes.filter { !$0.looks.isEmpty }.map(\.name) == ["Meander"]) // a new one: look at its Settings page, then add it here
}

/// Meander's settings hang together: a row that shows for one look hangs on a pick the Look menu has, and a menu's
/// range is its list. And the scene follows them as it runs: a new look or new colours at once, on the same river; a new
/// size of river by handing over to a new scene (which it does once the slider has rested; here it is told to at
/// once, so that no other test runs while these settings are held). Colours that aren't a swatch's name are Random.
/// The Look sliders change the picture, and leave it as it was once they are back.
@MainActor @Test func meanderFollowsItsSettings() throws {
    for knob in Meander.knobs {
        if let gate = knob.shownWhen {
            let menu = Meander.knobs.first { $0.key == gate }, pick = knob.shownAt ?? -1
            #expect(menu?.range.contains(pick) == true && pick == pick.rounded(), "\(knob.key) hangs on \(gate) at \(pick)")
        }
        if case .choice(let names) = knob.format { #expect(knob.range == 0...Double(names.count - 1), "\(knob.key)'s menu") }
        #expect(knob.range.contains(knob.standard))
    }
    let keys = Meander.knobs.map(\.key) + Meander.palettes.map(\.key) + ["meander.seed"]
    defer { keys.forEach(UserDefaults.standard.removeObject) }
    for (key, value) in seeded(7) { UserDefaults.standard.set(value, forKey: key) }
    for (palette, name) in zip(Meander.palettes, ["Survey Blue", "Fisk 1944"]) { UserDefaults.standard.set(name, forKey: palette.key) }
    let view = WallpaperView(frame: CGRect(x: 0, y: 0, width: 378, height: 245)), scene = Meander(size: view.frame.size)
    view.presentScene(scene)
    let screen = try Offscreen(scene, 756, 490), river = scene.river!
    for _ in 0..<2 { try screen.frame() }
    var pictures = [screen.pixels]
    let changes: [(String, Any)] = [("meander.look", 1.0), ("meander.rule", 1.0), ("meander.inks", "Sage"), ("meander.look", 0.0), ("meander.colors", "Garnet"), ("meander.scroll", 0.0), ("meander.memory", 15.0)]
    for (key, value) in changes {
        UserDefaults.standard.set(value, forKey: key)
        for _ in 0..<2 { try screen.frame(rate: 1e9) } // the new shader's first frame, and no time gone by
        pictures.append(screen.pixels)
        #expect(pictures.last! != pictures[pictures.count - 2], "nothing changed when \(key) became \(value)")
    }
    #expect(scene.river === river && view.scene === scene)
    // The Look sliders, each off its standard value in turn; and with all four back the picture is the one there
    // was, every pixel: the shader has the grade only while one of them is moved.
    let ungraded = pictures.last!
    for (grade, value) in zip(Meander.grades, [1.3, 1.3, 0.4, 90.0]) {
        UserDefaults.standard.set(value, forKey: grade.key)
        for _ in 0..<2 { try screen.frame(rate: 1e9) }
        pictures.append(screen.pixels)
        #expect(pictures.last! != pictures[pictures.count - 2], "nothing changed when \(grade.key) became \(value)")
    }
    Meander.grades.map(\.key).forEach(UserDefaults.standard.removeObject)
    for _ in 0..<2 { try screen.frame(rate: 1e9) }
    #expect(screen.pixels == ungraded, "the picture with the Look sliders back at their standard values isn't the one before they moved")
    // a name no swatch has, as an older version's might be, is Random: it draws, with one of relief's colours
    UserDefaults.standard.set("Gone", forKey: "meander.colors")
    for _ in 0..<2 { try screen.frame(rate: 1e9) }
    #expect(screen.pixels[756 * 5 + 5].z < 240)
    UserDefaults.standard.set(56.0, forKey: "meander.size")
    #expect(view.scene === scene) // not while the slider may still be moving
    scene.handOver()
    let next = try #require(view.scene as? Meander)
    #expect(next !== scene && abs(next.river.columns * 2 - river.columns) <= 1, "\(next.river.columns) columns after \(river.columns)")
}

/// What Meander costs a frame on a 14" MacBook Pro's screen, for docs/meander.md: a frame the river steps on and
/// one it doesn't, each as its update, the CPU's share of drawing it (on a step frame SpriteKit sends the ground's
/// bytes to the GPU there) and the GPU's; and the copy of the bytes alone. Each look at speed 1 and 60 frames a
/// second, where one frame in six carries a step; then relief at the top of the Speed slider, twenty steps a
/// second, at 60 frames a second and at 15, where a frame carries one step or two. Printed; a step frame is held
/// to 3 ms of GPU and 5 of CPU only with MEANDER_COSTS set (`measuring`).
@MainActor @Test func meanderFrameCosts() throws {
    func middle(_ times: [Double]) -> Double { times.isEmpty ? .nan : times.sorted()[times.count / 2] }
    let runs: [(name: String, settings: [String: Double], rate: Double)] = [
        ("relief", [:], 60), ("old map", ["meander.look": 1], 60), ("old map in Fisk's order", ["meander.look": 1, "meander.rule": 1], 60),
        ("relief at 4x", ["meander.speed": 4], 60), ("relief at 4x and 15 fps", ["meander.speed": 4], 15),
    ]
    for run in runs {
        try with(seeded(13, run.settings)) {
            let scene = Meander(size: CGSize(width: 1512, height: 982)), screen = try Offscreen(scene, 3024, 1964)
            for _ in 0..<Int(run.rate) { try screen.frame(rate: run.rate) }
            var costs: [Int: [(update: Double, draw: Double, gpu: Double)]] = [:] // by how many steps the frame carried
            for _ in 0..<Int(6 * run.rate) {
                let before = scene.river.now, cost = try screen.frame(rate: run.rate)
                costs[Int(((scene.river.now - before) / (Meander.speed.value / River.pace / (Meander.speed.value > 2 ? 20 : 10))).rounded()), default: []].append(cost)
            }
            let clock = ContinuousClock()
            let copies = (0..<50).map { _ in Double(clock.measure { scene.upload() }.components.attoseconds) / 1e15 }
            for (steps, frames) in costs.sorted(by: { $0.key < $1.key }) {
                print(String(format: "Meander, %@, a frame with %d step%@ (%d of them): update %.2f ms, drawing %.2f ms of CPU and %.2f ms of GPU", run.name, steps, steps == 1 ? "" : "s",
                             frames.count, middle(frames.map(\.update)), middle(frames.map(\.draw)), middle(frames.map(\.gpu))))
            }
            print(String(format: "  the ground's %d bytes copied to the texture in %.3f ms", scene.river.pixels.count, middle(copies)))
            let stepped = costs.filter { $0.key > 0 }.flatMap(\.value)
            #expect(stepped.count > 40)
            #expect(!measuring || middle(stepped.map(\.gpu)) < 3 && middle(stepped.map { $0.update + $0.draw }) < 5)
        }
    }
}

/// Something the river does that could show as a jump: where on the screen (in widths), on which frame of a run,
/// and what that frame's update cost.
private struct Happening {
    var cutoff: Bool, frame: Int, at: SIMD2<Float>, update: Double
}

/// How much of its width a lake still has at each node, from 1 to none, by the rule it silts up by (`River.trace`).
private func wetness(_ lake: River.Lake, at now: Double, life: Double) -> [Float] {
    var arcs: [Float] = [0]
    for (a, b) in zip(lake.nodes, lake.nodes.dropFirst()) { arcs.append(arcs.last! + hypot(b.x - a.x, b.y - a.y)) }
    func smooth(_ x: Float) -> Float { let t = min(max(x, 0), 1); return t * t * (3 - 2 * t) }
    let body = 1 - smooth(Float(now - lake.born - 0.5 * life) / Float(0.5 * life))
    return arcs.map { body * smooth(($0 - River.Lake.front(Float(now - lake.first))) / 2 + 1) * smooth((arcs.last! - $0 - River.Lake.front(Float(now - lake.last))) / 2 + 1) }
}

/// A seeded Meander on a 14" screen run at `rate` frames a second with nothing drawn, until it has had both a
/// cutoff and a re-crossing worth looking at, by the prototype's rules: a loop over 8 widths long cut off at a neck
/// 6 widths inside the screen, and a lake over 2 T old parted by the river where it still had over half its water,
/// 8 widths inside the screen, on a frame with no cutoff. Also the plain step frames' update times, to set the two
/// beside.
@MainActor private func happenings(_ settings: [String: Double], rate: Double, within seconds: Double) throws -> (found: [Happening], plain: [Double]) {
    var found: [Happening] = [], plain: [Double] = []
    try with(settings) {
        let scene = Meander(size: CGSize(width: 1512, height: 982)), screen = try Offscreen(scene, 16, 16), river = scene.river!, clock = ContinuousClock()
        func onScreen(_ node: SIMD3<Float>, inside: Float) -> SIMD2<Float>? {
            var along = (node.x + 10) / river.period
            along -= along.rounded(.down)
            let x = along * river.period - 10
            return x > inside && x < river.across - inside && node.y > inside && node.y < river.up - inside ? [x, node.y] : nil
        }
        for frame in 0..<Int(seconds * rate) where found.count < 2 {
            let (cutoffs, trims, lakes, now) = (river.cutoffs, river.trims, river.lakes, river.now)
            let update = Double(clock.measure { screen.advance(rate: rate) }.components.attoseconds) / 1e15
            if river.cutoffs > cutoffs, !found.contains(where: \.cutoff), let lake = river.lakes.last {
                let length = zip(lake.nodes, lake.nodes.dropFirst()).reduce(Float(0)) { $0 + simd_distance($1.0, $1.1) }
                if length > 8, let at = onScreen(0.5 * (lake.nodes[0] + lake.nodes[lake.nodes.count - 1]), inside: 6) { found.append(Happening(cutoff: true, frame: frame, at: at, update: update)) }
            } else if river.trims > trims, river.cutoffs == cutoffs, !found.contains(where: { !$0.cutoff }) {
                // where a lake was parted, one piece ends on the node the next begins on, as none did before
                func same(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Bool { a.x == b.x && a.y == b.y }
                func joints(_ lakes: [River.Lake]) -> [SIMD3<Float>] { lakes.map { $0.nodes[0] }.filter { start in lakes.contains { same($0.nodes[$0.nodes.count - 1], start) } } }
                let already = joints(lakes)
                if let joint = joints(river.lakes).first(where: { new in !already.contains { same($0, new) } }),
                   let whole = lakes.first(where: { now - $0.born > 2 && $0.nodes.contains { same($0, joint) } }),
                   wetness(whole, at: now, life: river.lakeLife)[whole.nodes.firstIndex { same($0, joint) }!] > 0.5, let at = onScreen(joint, inside: 8) {
                    found.append(Happening(cutoff: false, frame: frame, at: at, update: update))
                }
            } else if river.now != now, river.cutoffs == cutoffs, river.trims == trims {
                plain.append(update)
            }
        }
    }
    return (found, plain)
}

/// The same run again, drawn from a second before a happening to two seconds after: the greatest share
/// of a window 14 widths square round it that changes by over 20 levels from one frame to the next, and on which
/// frame after the happening's own (0) that was; the share on the happening's own frame; and the share on a
/// middling frame, which is the river's ordinary motion (a bank that moves a third of a pixel changes the pixels
/// along it by that much). With a folder, the window's frames from two before to five after are saved side by
/// side, and the worst frame beside the one before it, to look at.
@MainActor private func pop(_ settings: [String: Double], rate: Double, at happening: Happening, saveTo folder: URL? = nil, named name: String = "") throws
    -> (share: Double, frame: Int, own: Double, middling: Double) {
    var worst = (share: 0.0, frame: 0), own = 0.0, shares: [Double] = []
    try with(settings) {
        let scene = Meander(size: CGSize(width: 1512, height: 982)), screen = try Offscreen(scene, 3024, 1964), side = 784 // 14 widths of 28 pt at 2x
        let (x, y) = (Int(happening.at.x * 56) - side / 2, 1964 - Int(happening.at.y * 56) - side / 2)
        let lead = Int(rate)
        for _ in 0..<happening.frame - lead { screen.advance(rate: rate) }
        var last: [UInt32] = [], strip = [UInt32](repeating: 0, count: side * 8 * side), pair = [UInt32](repeating: 0, count: folder == nil ? 0 : side * 3 * side)
        for frame in -lead...Int(2 * rate) {
            try screen.frame(rate: rate)
            let now = screen.piece(x: x, y: y, w: side, h: side)
            if !last.isEmpty, frame > -lead + 2 { // the first frames can go by before the shader has compiled
                let share = popped(last, now)
                shares.append(share)
                if frame == 0 { own = share }
                if share > worst.share {
                    worst = (share, frame)
                    if folder != nil { // the frame before, the frame, and the frame with what changed by over 20 levels in pink
                        for row in 0..<side {
                            pair.replaceSubrange(row * 3 * side..<(row * 3 + 1) * side, with: last[row * side..<(row + 1) * side])
                            pair.replaceSubrange((row * 3 + 1) * side..<(row * 3 + 2) * side, with: now[row * side..<(row + 1) * side])
                            for x in 0..<side { pair[(row * 3 + 2) * side + x] = popped([last[row * side + x]], [now[row * side + x]]) > 0 ? 0xFFFF00FF : now[row * side + x] }
                        }
                    }
                }
            }
            if (-2...5).contains(frame) { for row in 0..<side { strip.replaceSubrange((row * 8 + frame + 2) * side..<(row * 8 + frame + 3) * side, with: now[row * side..<(row + 1) * side]) } }
            last = now
        }
        if let folder {
            save(strip, side * 8, side, to: folder.appendingPathComponent("\(name).png"))
            save(pair, side * 3, side, to: folder.appendingPathComponent("\(name)-worst.png"))
        }
    }
    let moving = shares.filter { $0 > 0 }.sorted() // the frames the river stepped on
    return (worst.share, worst.frame, own, moving.isEmpty ? 0 : moving[moving.count / 2])
}

/// Nothing pops. Through a cutoff and through the river running back over a lake, in both looks, no frame changes
/// more than 0.3% of the pixels near it by over 20 levels: the loop goes on being drawn as the same water when it
/// is cut off, and a lake the river parts loses nothing on that frame. At speed 1 and 15 frames a second, a river
/// whose first of each comes within half a minute. With MEANDER_STRIPS set to a folder: another river too, the top
/// of the Speed slider, 30 and 60 frames a second and Fisk's order; the frames round each are saved there, and what the
/// cutoff's and the re-crossing's frames cost is printed beside an ordinary step's. At the top of the slider a
/// bank can move over a pixel a frame, so the river's ordinary motion is past 0.3% on its own: there the
/// happening's own frame has to be within 0.3% of a middling frame's.
@MainActor @Test func meanderDoesNotPop() throws {
    let folder = ProcessInfo.processInfo.environment["MEANDER_STRIPS"].map { URL(fileURLWithPath: $0) }
    var looks: [(name: String, settings: [String: Double])] = [("relief", [:]), ("old map", ["meander.look": 1])]
    var runs: [(seed: Double, speed: Double, rate: Double)] = [(7, 1, 15)]
    if folder != nil {
        looks.append(("old map in Fisk's order", ["meander.look": 1, "meander.rule": 1]))
        runs += [(7, 1, 30), (7, 1, 60), (7, 4, 15), (13, 1, 15), (13, 4, 15)]
    }
    for run in runs {
        let river = String(format: "Meander %.0f at %.0fx and %.0f fps", run.seed, run.speed, run.rate), pace = ["meander.speed": run.speed]
        let (found, plain) = try happenings(seeded(run.seed, pace), rate: run.rate, within: run.seed == 7 && run.speed == 1 ? 60 : 600)
        #expect(found.count == 2, "\(river) had \(found.count) of a cutoff and a re-crossing to look at")
        for happening in found {
            let kind = happening.cutoff ? "a cutoff" : "a re-crossing"
            if folder != nil {
                print(String(format: "%@, %@ %.0f s in at (%.1f, %.1f) widths: its frame's update took %.2f ms, a plain step's %.2f (median of %d)",
                             river, kind, Double(happening.frame) / run.rate, happening.at.x, happening.at.y, happening.update, plain.sorted()[plain.count / 2], plain.count))
            }
            for look in looks {
                let worst = try pop(seeded(run.seed, look.settings.merging(pace) { $1 }), rate: run.rate, at: happening, saveTo: folder,
                                    named: "\(kind.dropFirst(2))-\(Int(run.seed))-\(Int(run.speed))x-\(look.name.replacingOccurrences(of: " ", with: "-"))-\(Int(run.rate))fps")
                print(String(format: "%@, %@, %@: at most %.3f%% of the window changes by over 20 levels, on frame %+d; on its own frame %.3f%%, on a middling frame %.3f%%",
                             river, kind, look.name, 100 * worst.share, worst.frame, 100 * worst.own, 100 * worst.middling))
                #expect(run.speed > 1 ? worst.own - worst.middling < 0.003 : worst.share < 0.003, "\(kind) in \(look.name), \(river)")
            }
        }
    }
}

/// The picture is the same whatever the frame rate: after the same six seconds at speed 1 and three more at the top
/// of the Speed slider, where the river steps twenty times a second, drawn at 15, 30 and 60 frames a second, every
/// pixel of both looks is the same. (The river steps by the time gone by, and the shader is told nothing but what
/// the river has done.)
@MainActor @Test func meanderLooksTheSameAtAnyFrameRate() throws {
    for look: [String: Double] in [[:], ["meander.look": 1]] {
        try with(seeded(7, look.merging(["meander.speed": 1]) { $1 })) {
            var pictures: [[SIMD4<UInt8>]] = [], times: [Double] = []
            for rate in [15.0, 30.0, 60.0] {
                UserDefaults.standard.set(1.0, forKey: "meander.speed")
                let scene = Meander(size: CGSize(width: 756, height: 491)), screen = try Offscreen(scene, 1512, 982)
                for _ in 0...Int(6 * rate) { screen.advance(rate: rate) }
                UserDefaults.standard.set(4.0, forKey: "meander.speed")
                for _ in 0..<Int(3 * rate) { screen.advance(rate: rate) }
                for _ in 0..<2 { try screen.frame(rate: 1e9) } // drawn at the end only, with no more time gone by, and twice for the shader's sake
                pictures.append(screen.pixels)
                times.append(scene.river.now)
            }
            #expect(times[0] > 301.3 && times[1] == times[0] && times[2] == times[0], "T \(times)") // 300, then 6 s at 12.5 s a T and 3 s at four times that
            #expect(pictures[1] == pictures[0] && pictures[2] == pictures[0], "the look \(look) differs with the frame rate")
        }
    }
}

/// When the stamps' base moves up, the picture stays as it was. The scene is run at four times its pace until a
/// move is nearly due, drawn, the base moved with the river standing still, and drawn again, in all three looks:
/// the second picture is mixed from one ground that counts from the old base and one that counts from the new.
/// Every age the shader works out is the same number as before but for its last bits, so a pixel in a few thousand
/// rounds the other way, by one level and never more: measured 2026-10-11 on a picture of 1,484,784 pixels, 397
/// in relief, 344 and 138 in the old map's two rules, where an ordinary step of the river changes 20,000 to
/// 49,000; on this test's smaller picture, 9 to 14. Before the shader worked in ages, and the base moved by whole
/// turns of the high byte, it was a sixth of them; and before the old map mixed its inks across a stage's edge,
/// half a dozen pixels on such an edge turned from one ink to the other, by up to 15 levels.
@MainActor @Test func meanderShowsNothingWhenItsStampsMoveUp() throws {
    for look: [String: Double] in [[:], ["meander.look": 1], ["meander.look": 1, "meander.rule": 1]] {
        try with(seeded(7, look.merging(["meander.speed": 4]) { $1 })) {
            let scene = Meander(size: CGSize(width: 504, height: 328)), screen = try Offscreen(scene, 1008, 656), river = scene.river! // a small screen, to get there quickly
            while river.now - river.base < River.memory + 5 + River.turn + River.slack - 0.05 { screen.advance(rate: 10) }
            scene.upload() // both of the grounds the picture is mixed from are now the river as it stands
            for _ in 0..<2 { try screen.frame(rate: 1e6) } // twice for the shader's sake, with no time gone by
            let before = screen.pixels, base = river.base, now = river.now
            river.rebase()
            scene.upload()
            try screen.frame(rate: 1e6)
            let most = zip(before, screen.pixels).map { pair in (0..<3).map { abs(Int(pair.0[$0]) - Int(pair.1[$0])) }.max()! }
            let changed = most.count { $0 > 0 }
            print("Meander, the stamps' base moved by \(river.base - base) T, look \(look): \(changed) of \(most.count) pixels changed, \(most.count { $0 > 1 }) by more than a level, the most by \(most.max()!)")
            #expect(river.base == base + River.turn && river.now == now, "the base moved from \(base) to \(river.base)")
            #expect(changed < most.count / 2000 && most.max()! <= 2, "\(changed) of \(most.count) pixels changed when the base moved, the most by \(most.max()!), in the look \(look)")
        }
    }
}

/// With MEANDER_FILM set to a folder: half an hour from a fresh launch at speed 1 on a 14" screen. A frame every
/// 30 s of the first ten minutes is saved there in relief, and the old map at the start, five minutes and ten, to
/// see the live river work over the ground its launch left. Printed, for docs/meander.md: how far the river's
/// centreline moves in ten seconds, in points (each node on screen to the nearest of the river ten seconds on),
/// how often a loop is cut off on screen, and how much of the land with a past the live river has worked over.
/// Then the same figures for a quarter of an hour at the top of the Speed slider.
@MainActor @Test func meanderFilm() throws {
    guard let folder = ProcessInfo.processInfo.environment["MEANDER_FILM"].map({ URL(fileURLWithPath: $0) }) else { return }
    for (name, look, seconds): (String, [String: Double], Int) in [("relief", [:], 1800), ("old-map", ["meander.look": 1], 600), ("relief-4x", ["meander.speed": 4], 900)] {
        try with(seeded(13, look)) {
            let scene = Meander(size: CGSize(width: 1512, height: 982)), screen = try Offscreen(scene, 3024, 1964), river = scene.river!
            var was: [SIMD2<Float>] = [], moved: [Float] = [], cuts: [Int] = [], lakes: [Int] = []
            for second in 0...seconds {
                if name != "relief-4x", second <= 600, second % (name == "relief" ? 30 : 300) == 0 {
                    for _ in 0..<(second == 0 ? 2 : 1) { try screen.frame(rate: 1e6) } // drawn with no time gone by
                    save(screen.piece(x: 0, y: 0, w: 3024, h: 1964), 3024, 1964, to: folder.appendingPathComponent(String(format: "%@-%02dm%02d.png", name, second / 60, second % 60)))
                }
                if name != "old-map", second % 10 == 0 {
                    // every segment of the river now, in this period and the ones either side
                    let n = river.nodes.count, points = (0...n).map { SIMD2(river.nodes[$0 % n].x + ($0 == n ? river.period : 0), river.nodes[$0 % n].y) }
                    for p in was {
                        var nearest = Float.infinity
                        for shift in [-river.period, 0, river.period] { for i in 0..<n {
                            let a = points[i] + [shift, 0], e = points[i + 1] + [shift, 0] - a, t = min(max(simd_dot(p - a, e) / simd_length_squared(e), 0), 1)
                            nearest = min(nearest, simd_distance(p, a + t * e))
                        } }
                        moved.append(nearest * 28)
                    }
                    was = river.nodes.filter { $0.x > 0 && $0.x < river.across }.map { [$0.x, $0.y] }
                    lakes.append(river.lakes.count)
                    if [60, 300, 600, 900, 1800].contains(second) {
                        let launch = Float(300.05 - river.base), oldest = Float(river.now - river.base - River.memory - 5)
                        let land = river.ground.filter { min($0.z, $0.w) > 0.5 && $0.x > oldest }
                        print(String(format: "  after %2d min the live river has worked over %.0f%% of the land with a past", second / 60, 100 * Double(land.count { $0.x > launch }) / Double(land.count)))
                    }
                }
                let before = river.cutoffs
                for _ in 0..<10 { screen.advance(rate: 10) } // a second, a step at a time
                if river.cutoffs > before, let lake = river.lakes.last {
                    var along = (lake.nodes[0].x + 10) / river.period
                    along -= along.rounded(.down)
                    if along * river.period - 10 > 0, along * river.period - 10 < river.across { cuts.append(second) }
                }
            }
            if name != "old-map" {
                moved.sort()
                print(String(format: "Meander, %@, over %d minutes: in 10 s the river moves a median %.1f pt, 9 nodes in 10 under %.1f, 99 in 100 under %.1f, the most %.1f (of %d)",
                             name, seconds / 60, moved[moved.count / 2], moved[moved.count * 9 / 10], moved[moved.count * 99 / 100], moved.last!, moved.count))
                print("  cutoffs with a neck on screen: \(cuts.count), at \(cuts.map { "\($0 / 60):" + String(format: "%02d", $0 % 60) }); lakes at once: \(lakes.min()!) to \(lakes.max()!)")
            }
        }
    }
}

/// A bank moves on every frame, not only on the frames the river steps on: the picture is mixed from the river's
/// last two steps by how far it is toward the next. Over a fifth of a second at 60 frames a second, where the
/// river steps twice, every frame differs from the one before it.
///
/// And how smoothly, on the picture itself, with MEANDER_SMOOTH set to a folder: four seconds at 60 frames a
/// second on a 14" screen, in relief, at the top of the Speed slider and at speed 1. On every 24th row of the
/// picture each cut bank is found to a fraction of a pixel (where the green of the picture crosses from the
/// river's to old land's within a few pixels) and followed from frame to frame. Printed, for the banks that move
/// at least two pixels in that time: on what share of frames a bank doesn't move (under a tenth of its own average
/// move), its greatest jump in one frame, and that jump over its average move. Twelve frames round the fastest
/// bank are saved. Before those, for both looks: how sharp twelve frames running are, mixed and not.
@MainActor @Test func meanderMovesSmoothly() throws {
    try with(seeded(13)) {
        let screen = try Offscreen(Meander(size: CGSize(width: 756, height: 491)), 1512, 982)
        for _ in 0..<6 { try screen.frame(rate: 60) }
        var last = screen.piece(x: 0, y: 0, w: 1512, h: 982), moved = 0
        for _ in 0..<12 {
            try screen.frame(rate: 60)
            let now = screen.piece(x: 0, y: 0, w: 1512, h: 982)
            if now != last { moved += 1 }
            last = now
        }
        #expect(moved == 12, "the picture changed on \(moved) of 12 frames")
    }
    guard let folder = ProcessInfo.processInfo.environment["MEANDER_SMOOTH"].map({ URL(fileURLWithPath: $0) }) else { return }
    // Whether mixing two steps softens anything: how sharp the whole picture is on twelve frames running, as the
    // levels a pixel's green differs by from the pixel beside it, averaged. At 4x one frame in three is of a single
    // step, unmixed, and at 1x one in six: if a mix were softer, the others would come out lower than those.
    for (look, settings): (String, [String: Double]) in [("relief", [:]), ("old map", ["meander.look": 1])] {
        for speed in [4.0, 1.0] {
            try with(seeded(13, settings.merging(["meander.speed": speed]) { $1 })) {
                let (w, h) = (3024, 1964), scene = Meander(size: CGSize(width: w / 2, height: h / 2)), screen = try Offscreen(scene, w, h)
                for _ in 0..<60 { try screen.frame(rate: 60) }
                var sharp: [String] = []
                for _ in 0..<12 {
                    try screen.frame(rate: 60)
                    let picture = screen.piece(x: 0, y: 0, w: w, h: h)
                    var sum = 0
                    picture.withUnsafeBufferPointer { p in for i in 1..<w * h where i % w != 0 { sum += abs(Int(p[i] >> 8 & 255) - Int(p[i - 1] >> 8 & 255)) } }
                    sharp.append(String(format: "%.4f", Double(sum) / Double((w - 1) * h)))
                }
                print("Meander, \(look) at \(Int(speed))x and 60 fps, how sharp twelve frames running are:", sharp.joined(separator: " "))
            }
        }
    }
    for speed in [4.0, 1.0] {
        try with(seeded(13, ["meander.speed": speed])) {
            let (w, h) = (3024, 1964), scene = Meander(size: CGSize(width: w / 2, height: h / 2)), screen = try Offscreen(scene, w, h)
            for _ in 0..<60 { try screen.frame(rate: 60) }
            let rows = Array(stride(from: 12, to: h, by: 24))
            var tracks: [(row: Int, at: [Double])] = [], pictures: [[UInt32]] = []
            for frame in 0..<240 {
                try screen.frame(rate: 60)
                let picture = screen.piece(x: 0, y: 0, w: w, h: h)
                if frame < 12 { pictures.append(picture) }
                var found: [Int: [Double]] = [:] // each row's banks
                picture.withUnsafeBufferPointer { p in
                    for row in rows {
                        func green(_ x: Int) -> Int { Int(p[row * w + x] >> 8 & 255) }
                        var x = 4
                        while x < w - 5 {
                            let (a, b) = (green(x), green(x + 1))
                            // the river is over 150 and old land under 85; a cut bank goes from one to the other in a few pixels
                            if (a - 115) * (b - 115) <= 0, a != b, max(green(x - 3), green(x + 4)) > 150, min(green(x - 3), green(x + 4)) < 85 {
                                found[row, default: []].append(Double(x) + Double(a - 115) / Double(a - b))
                                x += 6
                            }
                            x += 1
                        }
                    }
                }
                if frame == 0 {
                    tracks = found.flatMap { row, places in places.map { (row, [$0]) } }
                } else {
                    tracks = tracks.compactMap { track in
                        guard let next = found[track.row]?.min(by: { abs($0 - track.at.last!) < abs($1 - track.at.last!) }), abs(next - track.at.last!) < 4 else { return nil }
                        return (track.row, track.at + [next])
                    }
                }
            }
            let moving = tracks.filter { abs($0.at.last! - $0.at[0]) >= 2 }
            var still: [Double] = [], jumps: [Double] = [], against: [Double] = []
            for track in moving {
                let moves = zip(track.at, track.at.dropFirst()).map { abs($1 - $0) }
                let average = moves.reduce(0, +) / Double(moves.count)
                still.append(Double(moves.count { $0 < 0.1 * average }) / Double(moves.count))
                jumps.append(moves.max()!)
                against.append(moves.max()! / average)
            }
            func middle(_ values: [Double]) -> Double { values.isEmpty ? .nan : values.sorted()[values.count / 2] }
            print(String(format: "Meander at %.0fx, 60 fps, %d banks that moved 2 px or more in 4 s (of %d followed): a bank holds still on %.0f%% of frames (the middle one; from %.0f%% to %.0f%%); its greatest jump is %.2f px (the middle one) and %.2f at the most; the greatest jump is %.1f times its average move (the middle one)",
                         speed, moving.count, tracks.count, 100 * middle(still), 100 * (still.min() ?? .nan), 100 * (still.max() ?? .nan), middle(jumps), jumps.max() ?? .nan, middle(against)))
            // the fastest of them, twelve frames, 96 px square, three times life size
            if let fastest = moving.max(by: { abs($0.at.last! - $0.at[0]) < abs($1.at.last! - $1.at[0]) }) {
                let side = 96, x0 = min(max(Int(fastest.at[0]) - side / 2, 0), w - side), y0 = min(max(fastest.row - side / 2, 0), h - side)
                var strip = [UInt32](repeating: 0, count: side * 3 * 12 * side * 3)
                for (k, picture) in pictures.enumerated() { for y in 0..<side * 3 { for x in 0..<side * 3 {
                    strip[y * side * 3 * 12 + k * side * 3 + x] = picture[(y0 + y / 3) * w + x0 + x / 3]
                } } }
                save(strip, side * 3 * 12, side * 3, to: folder.appendingPathComponent(String(format: "bank-%.0fx.png", speed)))
                print("  the fastest: row \(fastest.row), from \(fastest.at[0]) by", zip(fastest.at, fastest.at.dropFirst()).prefix(13).map { String(format: "%+.2f", $1 - $0) }.joined(separator: " "))
            }
        }
    }
}

/// The transitions, frame by frame, at the top of the Speed slider and at speed 1: with MEANDER_TRANSITIONS set to a
/// folder, a cutoff and a lake being parted are filmed at 60 frames a second from a fifth of a second before to two
/// seconds after, in relief and the old map. Printed for each: how much the window round it changes from every
/// frame to the next (the levels a pixel changes by, averaged over the window, times a thousand), so that a jerk
/// shows as one frame far above its neighbours; and the greatest of those over the middle one. Saved: the middle
/// of the window on every sixth frame, twice life size, to look at.
@MainActor @Test func meanderTransitions() throws {
    guard let folder = ProcessInfo.processInfo.environment["MEANDER_TRANSITIONS"].map({ URL(fileURLWithPath: $0) }) else { return }
    for speed in [4.0, 1.0] {
        let (found, _) = try happenings(seeded(13, ["meander.speed": speed]), rate: 60, within: 600)
        for happening in found {
            for (look, settings): (String, [String: Double]) in [("relief", [:]), ("old-map", ["meander.look": 1])] {
                try with(seeded(13, settings.merging(["meander.speed": speed]) { $1 })) {
                    let scene = Meander(size: CGSize(width: 1512, height: 982)), screen = try Offscreen(scene, 3024, 1964), side = 784, crop = 300
                    let (x, y) = (Int(happening.at.x * 56) - side / 2, 1964 - Int(happening.at.y * 56) - side / 2)
                    for _ in 0..<happening.frame - 24 { screen.advance(rate: 60) }
                    var last: [UInt32] = [], series: [Double] = [], tiles: [[UInt32]] = []
                    for frame in -24...120 {
                        try screen.frame(rate: 60)
                        let now = screen.piece(x: x, y: y, w: side, h: side)
                        if frame >= -11 { series.append(changed(last, now).levels * 1000) }
                        if frame >= -12, (frame + 12) % 6 == 0 { tiles.append(now) }
                        last = now
                    }
                    let kind = happening.cutoff ? "cutoff" : "parting", middle = series.sorted()[series.count / 2], most = series.max()!
                    print(String(format: "Meander at %.0fx and 60 fps, a %@ in %@: a frame changes the window by %.0f at the most (frame %+d) and %.0f on a middling frame, %.1f times; from 11 frames before: %@",
                                 speed, kind, look, most, series.firstIndex(of: most)! - 11, middle, most / middle, series.prefix(48).map { String(format: "%.0f", $0) }.joined(separator: " ")))
                    var strip = [UInt32](repeating: 0, count: crop * 2 * tiles.count * crop * 2), from = (side - crop) / 2
                    for (k, tile) in tiles.enumerated() { for row in 0..<crop * 2 { for column in 0..<crop * 2 {
                        strip[row * crop * 2 * tiles.count + k * crop * 2 + column] = tile[(from + row / 2) * side + from + column / 2]
                    } } }
                    save(strip, crop * 2 * tiles.count, crop * 2, to: folder.appendingPathComponent(String(format: "%@-%@-%.0fx.png", kind, look, speed)))
                }
            }
        }
    }
}

/// How far edges in a picture stray from smooth lines, in pixels: the measure of a scarp drawn in texel-sized
/// stairs. `picture` is `side` pixels square and `texel` pixels to a texel. Along every row, and then every column,
/// an edge is where the green of the picture differs by 20 levels or more between three texels one way and three
/// the other, placed to a fraction of a pixel where it is half-way between the two; `counts` says whether an edge
/// at a pixel is one to measure, given whether it was found along a row. Edges are followed from line to line,
/// and each point is held against the parabola that best fits the six texels of edge round it. Returns how many
/// points, how far off they are (root mean square) and the furthest.
private func ripple(_ picture: [UInt32], side: Int, texel: Int, counts: (_ x: Int, _ y: Int, _ alongRow: Bool) -> Bool) -> (points: Int, rms: Double, worst: Double) {
    let reach = 3 * texel
    // a parabola fitted by least squares to evenly spaced points has, at their middle, this weighted sum of them
    let places = (-reach...reach).map(Double.init), squares = places.map { $0 * $0 }.reduce(0, +), fourths = places.map { $0 * $0 * $0 * $0 }.reduce(0, +)
    let weights = places.map { (fourths - squares * $0 * $0) / (Double(places.count) * fourths - squares * squares) }
    var (count, sum, worst) = (0, 0.0, 0.0)
    for turned in [false, true] {
        func green(_ along: Int, _ line: Int) -> Int { Int(picture[turned ? along * side + line : line * side + along] >> 8 & 255) }
        var edges: [[Double]] = [], open: [Int] = [] // every edge so far, and the ones the last line was on
        for line in 0..<side {
            var reached: [Int] = [], along = reach
            while along < side - reach - 1 {
                let (before, after) = (green(along - reach, line), green(along + reach, line)), middle = Double(before + after) / 2
                let (here, next) = (Double(green(along, line)), Double(green(along + 1, line)))
                if abs(after - before) >= 20, (here - middle) * (next - middle) <= 0, here != next, turned ? counts(line, along, false) : counts(along, line, true) {
                    let place = Double(along) + (here - middle) / (here - next)
                    if let edge = open.first(where: { abs(edges[$0].last! - place) <= Double(texel) && !reached.contains($0) }) {
                        edges[edge].append(place)
                        reached.append(edge)
                    } else {
                        edges.append([place])
                        reached.append(edges.count - 1)
                    }
                    along += texel
                }
                along += 1
            }
            open = reached
        }
        for edge in edges where edge.count > 2 * reach {
            for middle in reach..<edge.count - reach {
                let off = abs(edge[middle] - zip(weights, edge[middle - reach...middle + reach]).reduce(0) { $0 + $1.0 * $1.1 })
                (count, sum, worst) = (count + 1, sum + off * off, max(worst, off))
            }
        }
    }
    return (count, count > 0 ? (sum / Double(count)).squareRoot() : .nan, worst)
}

/// A scarp with new land at its foot is a smooth line and not texel-sized stairs. After a cutoff the river draws
/// back fast from the bank it was cutting at the neck, and leaves land a few seconds old against the old ground it
/// had been cutting into: the place where relief's stairs showed. At the top of the Speed slider, the edges of
/// such scarps in the window round each of river 13's first three cutoffs, two, three and four seconds after it,
/// stray from smooth lines by under 0.4 of a pixel (`ripple`; a scarp here is an edge with no water within two
/// texels, land under 5 T old two texels to one side of it and land over 10 T older two texels to the other). They
/// strayed by 0.7. With MEANDER_SCARP set to a folder: the same at the largest river too, and the windows saved.
@MainActor @Test func meanderScarpIsSmooth() throws {
    let folder = ProcessInfo.processInfo.environment["MEANDER_SCARP"].map { URL(fileURLWithPath: $0) }
    for size in folder == nil ? [28.0] : [28.0, 56.0] {
        try with(seeded(13, ["meander.speed": 4, "meander.size": size])) {
            let scene = Meander(size: CGSize(width: 1512, height: 982)), screen = try Offscreen(scene, 3024, 1964), river = scene.river!
            let side = 784, texel = 3024 / river.columns
            var (points, squares, worst) = (0, 0.0, 0.0)
            for cutoff in 1...3 {
                // on to the next loop cut off well inside the screen: `neck` is the middle of where it was cut, in widths
                var neck: SIMD2<Float>?
                for _ in 0..<36000 where neck == nil {
                    let cutoffs = river.cutoffs
                    screen.advance(rate: 60)
                    guard river.cutoffs > cutoffs, let lake = river.lakes.last else { continue }
                    let middle = 0.5 * (lake.nodes[0] + lake.nodes[lake.nodes.count - 1])
                    var along = (middle.x + 10) / river.period
                    along -= along.rounded(.down)
                    let x = along * river.period - 10
                    if x > 4, x < river.across - 4, middle.y > 4, middle.y < river.up - 4 { neck = [x, middle.y] }
                }
                let at = try #require(neck)
                let x0 = min(max(Int(at.x * Float(size * 2)) - side / 2, 0), 3024 - side), y0 = min(max(1964 - Int(at.y * Float(size * 2)) - side / 2, 0), 1964 - side)
                for seconds in 2...4 {
                    for _ in 0..<(seconds == 2 ? 119 : 59) { screen.advance(rate: 60) }
                    try screen.frame(rate: 60)
                    let picture = screen.piece(x: x0, y: y0, w: side, h: side), pixels = river.pixels, since = Float(river.now - river.base)
                    /// The ground's texel under a pixel of the window and `columns`, `rows` texels on: whether it is dry
                    /// for two texels round, and its age.
                    func ground(_ x: Int, _ y: Int, _ columns: Int, _ rows: Int) -> (dry: Bool, age: Float) {
                        let column = min(max((x0 + x) / texel + columns, 0), river.columns - 1), row = min(max(river.rows - 1 - (y0 + y) / texel + rows, 0), river.rows - 1)
                        let texel = (row * river.columns + column) * 4
                        return (pixels[texel + 2] >= 248, since - Float(Int(pixels[texel]) << 8 | Int(pixels[texel + 1])) / 100)
                    }
                    let measured = ripple(picture, side: side, texel: texel) { x, y, alongRow in
                        let (one, other) = (ground(x, y, alongRow ? -2 : 0, alongRow ? 0 : -2).age, ground(x, y, alongRow ? 2 : 0, alongRow ? 0 : 2).age)
                        return ground(x, y, 0, 0).dry && min(one, other) < 5 && abs(one - other) > 10
                    }
                    if measured.points > 0 { (points, squares, worst) = (points + measured.points, squares + measured.rms * measured.rms * Double(measured.points), max(worst, measured.worst)) }
                    if let folder { save(picture, side, side, to: folder.appendingPathComponent(String(format: "scarp-%.0fpt-%d-%ds.png", size, cutoff, seconds))) }
                }
            }
            let rms = (squares / Double(max(points, 1))).squareRoot()
            print(String(format: "Meander at 4x, a %.0f pt river, 2 to 4 s after each of three cutoffs: %d points of scarp above new land stray from a smooth line by %.2f px (root mean square), %.2f at the most",
                         size, points, rms, worst))
            if size == 28 { #expect(points > 300 && rms < 0.4, "\(points) points, \(rms) px") }
        }
    }
}
