import Foundation
import Testing
@testable import Atrium

/// A real Open-Meteo reply parses. A snake-case decoding strategy once turned wind_speed_10m into windSpeed10M,
/// which silently dropped every live update and left the scene on its default.
@MainActor @Test func parsesOpenMeteo() throws {
    let reply = #"{"current":{"time":"2026-09-25T19:15","interval":900,"weather_code":1,"cloud_cover":49,"cloud_cover_high":3,"wind_speed_10m":12.4,"wind_direction_10m":73,"snow_depth":0.00,"visibility":33200.00}}"#
    let conditions = try #require(WeatherScene.conditions(from: Data(reply.utf8)))
    #expect(conditions.code == 1)
    #expect(conditions.cloudCover == 49)
    #expect(conditions.wind == 12.4)
    #expect(conditions.windFrom == 73)
    #expect(conditions.highCloud == 3)
    #expect(conditions.visibility == 33200)
    // Some weather models leave out the extras; the reply still counts.
    let bare = #"{"current":{"weather_code":3,"cloud_cover":100,"wind_speed_10m":5}}"#
    #expect(WeatherScene.conditions(from: Data(bare.utf8))?.snowDepth == 0)
}
