import Foundation
import Testing
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
