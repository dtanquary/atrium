import Foundation
import Testing
@testable import Wallpaper

/// A real Open-Meteo reply parses. A snake-case decoding strategy once turned wind_speed_10m into windSpeed10M,
/// which silently dropped every live update and left the scene on its default.
@MainActor @Test func parsesOpenMeteo() throws {
    let reply = #"{"current":{"time":"2026-09-25T01:30","interval":900,"weather_code":3,"is_day":0,"cloud_cover":100,"wind_speed_10m":12.4}}"#
    let conditions = try #require(WeatherScene.conditions(from: Data(reply.utf8)))
    #expect(conditions.code == 3)
    #expect(conditions.cloudCover == 100)
    #expect(conditions.wind == 12.4)
}
