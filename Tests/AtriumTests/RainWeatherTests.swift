import Foundation
import ImageIO
import SpriteKit
import Testing
import UniformTypeIdentifiers
@testable import Atrium

/// Rain on Glass's weather physics against the numbers the research worked out (docs/rain-on-glass.md).
@Test func glassFollowsThePhysics() {
    #expect(abs(GlassWeather.vapour(20) - 17.3) < 0.1)                  // g/m³ of saturated air at 20 °C
    // a double glazed low-e pane at 10 °C with the dew point at 9: 2.1 °C below the air under a clear, calm sky,
    // 0.8 above it under cloud, so only the clear night fogs it
    let clear = GlassWeather.glassTemperature(air: 10, dewPoint: 9, cloud: 0, wind: 0, sunlight: 0, singlePane: false)
    let overcast = GlassWeather.glassTemperature(air: 10, dewPoint: 9, cloud: 1, wind: 0, sunlight: 0, singlePane: false)
    #expect(abs(clear - 10 + 2.1) < 0.6 && clear < 9)
    #expect(abs(overcast - 10 - 0.8) < 0.6)
    // a single pane's inside at −10 °C outside: a quarter of the way to the room, well below freezing
    #expect(GlassWeather.glassTemperature(air: -10, dewPoint: -12, cloud: 1, wind: 3, sunlight: 0, singlePane: true) == -2.5)
    // a lived-in room at 0 °C outside has a dew point of 9-12 °C (BS 5250)
    #expect((9...12).contains(GlassWeather.indoorDewPoint(outside: 0, dewPoint: -3)))
    // a 1 mm drop at 10 °C and 80% humidity dries in about 24 minutes in still air
    let dewPoint80 = 6.7 // °C, 80% at 10 °C
    let minutes = 1 / GlassWeather.drying(glass: 10, dewPoint: dewPoint80, wind: 0) / 60
    #expect(abs(minutes - 24) < 3)
    // 3.5 mm/h on a pane facing a 4 m/s wind is the steady rain the scene was made for; none is none
    #expect(abs(GlassWeather.rainAmount(mmPerHour: 3.5, wind: 4.2, code: 63) - 1) < 0.02)
    #expect(GlassWeather.rainAmount(mmPerHour: 0, wind: 4, code: 3) == 0)
    #expect(GlassWeather.rainAmount(mmPerHour: 0, wind: 4, code: 51) > 0)   // drizzle Open-Meteo rounds to 0
}

/// Before a backdrop is picked Settings shows Random and the scene opens on Hamburg, the look on the menu's tile.
/// Random (stored empty) starts on any photo, and both fade between the photos only; a pick is that pick.
@Test func rainOpensOnHamburgAndRotatesThePhotos() {
    #expect(rainBackdrops.standard == "" && rainBackdrop(picked: nil) == "Hamburg")
    #expect(rainBackdrop(picked: "City") == "City")
    let photos = Set(rainPhotos.map(\.name)), rolls = Set((0..<60).map { _ in rainBackdrop(picked: "") })
    #expect(rolls.count > 1 && rolls.isSubset(of: photos))
    #expect(Set(rainRotation) == photos)
}

/// Every palette's city is laid out as a city is, not sprinkled evenly: most of its lights are dim and a few are many
/// times brighter, and they crowd towards the horizon. One of them bakes, by night and by day, into three pictures
/// that aren't flat; `SNAPSHOT_DIR` keeps those to look at, and `RAIN_CITY` picks which palette's.
@MainActor @Test func rainCityIsLaidOutLikeACity() throws {
    for (index, palette) in rainPalettes.enumerated() {
        let lights = RainCity.lights(palette: index), powers = lights.map(\.power).sorted()
        #expect(lights.count > 150)
        #expect(powers[powers.count / 2] < 0.1 && powers[powers.count * 49 / 50] > 10 * powers[powers.count / 2], "\(palette.name)'s lights are all much the same")
        let high = lights.filter { $0.at.y > RainCity.horizon - 0.2 && $0.at.y < RainCity.horizon + 0.05 }.count
        #expect(high * 2 > lights.count, "\(palette.name)'s lights don't crowd towards the horizon")
    }
    let env = ProcessInfo.processInfo.environment, index = rainPalettes.firstIndex { $0.name == env["RAIN_CITY"] } ?? 0
    for night in [true, false] {
        let baked = RainCity.textures(palette: index, night: night)
        for (texture, name) in [(baked.far, "far"), (baked.near, "near"), (baked.haze, "haze")] {
            let image = texture.cgImage()
            let bytes = try #require(image.dataProvider?.data as Data?)
            #expect(Set(stride(from: 0, to: bytes.count - 4, by: 4 * 97).map { bytes[$0] }).count > 8, "the \(name) texture is flat")
            if let dir = env["SNAPSHOT_DIR"] {
                let url = URL(fileURLWithPath: dir).appendingPathComponent("city-\(rainPalettes[index].name)-\(night ? "night" : "day")-\(name).png")
                let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
                CGImageDestinationAddImage(destination, image, nil)
                CGImageDestinationFinalize(destination)
            }
        }
    }
}

/// A scene drawn offscreen, a pixel a point: its pixels, top row first.
@MainActor private func drawn(_ scene: SKScene) throws -> [UInt32] {
    let device = try #require(MTLCreateSystemDefaultDevice()), queue = try #require(device.makeCommandQueue())
    let (w, h) = (Int(scene.size.width), Int(scene.size.height))
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    let texture = try #require(device.makeTexture(descriptor: descriptor)), pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = texture
    pass.colorAttachments[0].storeAction = .store
    let renderer = SKRenderer(device: device)
    renderer.scene = scene
    for _ in 0..<2 { // the first frame can go by before a shader has compiled
        renderer.update(atTime: ProcessInfo.processInfo.systemUptime)
        let buffer = try #require(queue.makeCommandBuffer())
        renderer.render(withViewport: CGRect(x: 0, y: 0, width: w, height: h), commandBuffer: buffer, renderPassDescriptor: pass)
        buffer.commit()
        buffer.waitUntilCompleted()
    }
    var pixels = [UInt32](repeating: 0, count: w * h)
    texture.getBytes(&pixels, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
    return pixels
}

/// Each kind of weather is its own build of the shader, compiled only as it's first drawn, where a mistake is a
/// black screen that `swift build` can't see: every one draws a picture, over a photo and over a city (whose traffic
/// is one more).
@MainActor @Test func rainDrawsInEveryWeather() throws {
    let keys = ["rain.palette", "rain.seed", "rain.preview", "rain.previewRain", "rain.previewFog", "rain.previewSnow", "rain.previewFrost"]
    defer { keys.forEach(UserDefaults.standard.removeObject) }
    UserDefaults.standard.set(500.0, forKey: "rain.seed")
    var kept = [SKScene]() // (so the city is baked once)
    for backdrop in ["Hamburg", "City"] {
        for weather in [[:], ["Fog": 0.5], ["Fog": 1], ["Snow": 1], ["Frost": 0.6], ["Rain": 0]] as [[String: Double]] {
            keys.dropFirst(2).forEach(UserDefaults.standard.removeObject)
            UserDefaults.standard.set(backdrop, forKey: "rain.palette")
            if !weather.isEmpty { UserDefaults.standard.set(1.0, forKey: "rain.preview") }
            for (name, value) in weather { UserDefaults.standard.set(value, forKey: "rain.preview" + name) }
            let scene = rainOnGlass(size: CGSize(width: 300, height: 200))
            kept.append(scene)
            let pixels = try drawn(scene)
            #expect(Set(stride(from: 0, to: pixels.count, by: 97).map { pixels[$0] }).count > 20, "\(backdrop) with \(weather) drew a flat picture")
        }
    }
}

/// Dew isn't on a grid. Row by row down the picture, how much edge there is across the row: beads in level rows make
/// that rise and fall once a row, so a row of pixels is like the one a row of beads below it and unlike the one half
/// a row of beads below. With no level rows, neither.
@MainActor @Test func rainDewIsNotInRows() throws {
    let keys = ["rain.palette", "rain.seed", "rain.preview", "rain.previewFog"]
    defer { keys.forEach(UserDefaults.standard.removeObject) }
    for (key, value) in zip(keys, ["Hamburg", 500.0, 1.0, 1.0] as [Any]) { UserDefaults.standard.set(value, forKey: key) }
    let (w, h) = (1500, 2000), pixels = try drawn(rainOnGlass(size: CGSize(width: w, height: h)))
    let edges = (0..<h).map { row in
        (1..<w).reduce(0.0) { $0 + abs(Double(pixels[row * w + $1] >> 8 & 255) - Double(pixels[row * w + $1 - 1] >> 8 & 255)) }
    }
    /// How alike the edges of two rows `lag` apart are, -1 to 1.
    func alike(_ lag: Int) -> Double {
        let a = Array(edges.dropLast(lag)), b = Array(edges.dropFirst(lag)), ma = a.reduce(0, +) / Double(a.count), mb = b.reduce(0, +) / Double(b.count)
        let cross = zip(a, b).reduce(0.0) { $0 + ($1.0 - ma) * ($1.1 - mb) }
        return cross / (a.reduce(0.0) { $0 + ($1 - ma) * ($1 - ma) } * b.reduce(0.0) { $0 + ($1 - mb) * ($1 - mb) }).squareRoot()
    }
    let row = Int((0.008 * Double(h)).rounded()) // a row of beads, in pixels
    #expect(alike(row) - alike(row / 2) < 0.15, "rows \(row) apart are \(alike(row)) alike, and half that apart \(alike(row / 2))")
}

/// Following the weather, the view behind the glass is by day or by night by the real Sun where you are, whatever the
/// system's appearance, so the hour behind the glass is the one its rain is falling in; not following, it's Dark
/// Mode's night and Light Mode's day, as it always was.
@MainActor @Test func rainFollowsTheSunWithTheWeather() {
    let keys = ["rain.palette", "rain.weather", "rain.sun", "rain.status"]
    defer { keys.forEach(UserDefaults.standard.removeObject) }
    func night() -> Float? {
        (rainOnGlass(size: CGSize(width: 300, height: 200)) as? ShaderScene)?.sprite.shader?.uniformNamed("u_night")?.floatValue
    }
    UserDefaults.standard.set("Hamburg", forKey: "rain.palette")
    UserDefaults.standard.set(30.0, forKey: "rain.sun")
    #expect(night() == (systemIsDark ? 1 : 0)) // the Sun doesn't count until the weather is followed
    UserDefaults.standard.set(1.0, forKey: "rain.weather")
    #expect(night() == 0)
    UserDefaults.standard.set(-1.0, forKey: "rain.sun") // lamps aren't lit at sunset
    #expect(night() == 0)
    UserDefaults.standard.set(-10.0, forKey: "rain.sun")
    #expect(night() == 1)
}
