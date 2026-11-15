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

/// Before a backdrop is picked the scene shows the one Settings shows as picked: Hamburg, the look on the menu's
/// tile. Random (stored empty) rolls any of them, and a pick is that pick.
@Test func rainStartsOnItsStandardBackdrop() {
    #expect(rainBackdrops.standard == "Hamburg" && rainBackdrop(picked: nil) == "Hamburg")
    #expect(rainBackdrop(picked: "City") == "City")
    #expect(Set((0..<40).map { _ in rainBackdrop(picked: "") }).count > 1)
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
