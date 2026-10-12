import Foundation
import LineRoute
import Metal
import SpriteKit
import Testing
@testable import Atrium

/// A shipped route decodes to the steps and the clock its bake printed (docs/line-drawing/bake.py), never leaves
/// its grid and never lifts: each step is to a cell beside the last.
@Test func lineRouteDecodesToItsKnownLength() throws {
    let file = try Data(contentsOf: resource("line-wave.route")), route = try #require(LineRoute(file))
    #expect(route.steps == 238_714 && route.x.count == 238_715 && (route.columns, route.rows) == (1024, 640))
    #expect(abs(route.clock - 174_451.7) < 1 && abs(route.t[route.steps] - route.clock) < 1, "clock \(route.t[route.steps]) against \(route.clock)")
    #expect(route.x.allSatisfy { $0 > 0 && $0 < 1024 } && route.y.allSatisfy { $0 > 0 && $0 < 640 })
    // eased by one step, two cells in a row are never more than a diagonal apart
    #expect((1...route.steps).allSatisfy { abs(route.x[$0] - route.x[$0 - 1]) < 1.01 && abs(route.y[$0] - route.y[$0 - 1]) < 1.01 })
    #expect(LineRoute(file.prefix(40)) == nil && LineRoute(Data("not a route at all, though long enough".utf8)) == nil)
    let heading = try #require(LineRoute(file, walking: false))
    #expect(heading.steps == route.steps && heading.x.isEmpty)
}

/// A route stamped for a 14-inch screen: the line covers a fifth of it, the first row of bytes is the bottom of the
/// screen (where the stylus starts, at the frame's lower left corner, at the very start of the clock), and times
/// run on to the clock's end. Prints how long decoding and stamping take.
@Test func lineRouteStampsItsTextures() throws {
    let file = try Data(contentsOf: resource("line-wave.route")), clock = ContinuousClock()
    var route: LineRoute!, stamped: LineRoute.Stamped!
    let decoding = clock.measure { route = LineRoute(file) }
    let (w, h) = (3024, 1964), scale = min(Double(w) / 1024, Double(h) / 640), (dx, dy) = ((Double(w) - 1024 * scale) / 2, (Double(h) - 640 * scale) / 2)
    let stamping = clock.measure { stamped = route.stamp(width: w, height: h, scale: scale, dx: dx, dy: dy) }
    func ms(_ span: Duration) -> Double { Double(span.components.attoseconds) / 1e15 + Double(span.components.seconds) * 1000 }
    let making = clock.measure { _ = SKTexture(data: stamped.when, size: CGSize(width: w, height: h)) }
    print(String(format: "Line Drawing, the Wave for 3024 x 1964: decoded in %.0f ms, stamped in %.0f ms, made a texture in %.1f ms", ms(decoding), ms(stamping), ms(making)))
    let when = [UInt8](stamped.when), again = [UInt8](stamped.again)
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

/// The picture is the same whatever the frame rate: begun 40% drawn and run for two seconds at the top of the Speed
/// slider, drawn at 15, 30 and 60 frames a second, every pixel is the same; and it has moved on from where it began.
/// (The clock is the wall's, by way of each frame's own time, and the shader is told nothing else.)
@MainActor @Test func lineDrawingLooksTheSameAtAnyFrameRate() throws {
    let keys = ["linedrawing.drawn": 0.4, LineDrawing.speed.key: 60.0]
    defer { keys.keys.forEach(UserDefaults.standard.removeObject) }
    for (key, value) in keys { UserDefaults.standard.set(value, forKey: key) }
    let device = try #require(MTLCreateSystemDefaultDevice()), queue = try #require(device.makeCommandQueue())
    let (w, h) = (1512, 982), descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    var pictures: [[UInt32]] = [], begun: [UInt32] = []
    for rate in [15.0, 30.0, 60.0] {
        let renderer = SKRenderer(device: device), target = try #require(device.makeTexture(descriptor: descriptor)), pass = MTLRenderPassDescriptor()
        renderer.scene = LineDrawing(size: CGSize(width: w / 2, height: h / 2))
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        let start = ProcessInfo.processInfo.systemUptime + 1 // the renderer's first update runs on the system's clock
        func picture(at frame: Int) throws -> [UInt32] {
            renderer.update(atTime: start + Double(frame) / rate)
            let buffer = try #require(queue.makeCommandBuffer())
            renderer.render(withViewport: CGRect(x: 0, y: 0, width: w, height: h), commandBuffer: buffer, renderPassDescriptor: pass)
            buffer.commit()
            buffer.waitUntilCompleted()
            var pixels = [UInt32](repeating: 0, count: w * h)
            target.getBytes(&pixels, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
            return pixels
        }
        for frame in 0...Int(2 * rate) {
            let pixels = try picture(at: frame)
            if frame == Int(rate) { begun = pixels } // a second in: the picture has faded up, and has a second still to run
            if frame == Int(2 * rate) { pictures.append(pixels) }
        }
        let moved = zip(begun, pictures.last!).count { $0 != $1 }
        #expect(moved > 300, "at \(rate) fps only \(moved) pixels changed in a second")
    }
    let dark = pictures[0].count { $0 & 255 < 90 }
    #expect(dark > w * h / 50, "only \(dark) pixels of line")
    #expect(pictures[1] == pictures[0] && pictures[2] == pictures[0], "the picture differs with the frame rate")
}
