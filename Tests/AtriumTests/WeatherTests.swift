import Foundation
import Testing
import simd
@testable import Atrium

/// A real Open-Meteo reply parses. A snake-case decoding strategy once turned wind_speed_10m into windSpeed10M,
/// which silently dropped every live update and left the scene on its default.
@MainActor @Test func parsesOpenMeteo() throws {
    let reply = #"{"current":{"time":"2026-09-25T19:15","interval":900,"weather_code":1,"cloud_cover":49,"cloud_cover_high":3,"wind_speed_10m":12.4,"wind_direction_10m":73,"snow_depth":0.00,"visibility":33200.00,"precipitation":0.00,"rain":0.00,"showers":0.00,"snowfall":0.00,"temperature_2m":18.3,"relative_humidity_2m":64,"dew_point_2m":11.4}}"#
    let conditions = try #require(LiveWeather.conditions(from: Data(reply.utf8)))
    #expect(conditions.code == 1)
    #expect(conditions.cloudCover == 49)
    #expect(conditions.wind == 12.4)
    #expect(conditions.windFrom == 73)
    #expect(conditions.highCloud == 3)
    #expect(conditions.visibility == 33200)
    #expect(conditions.temperature == 18.3)
    #expect(conditions.summary == "Clear (WMO 1) · 49% cloud · wind 12 km/h from ENE") // what Settings shows
    // Some weather models leave out the extras; the reply still counts.
    let bare = #"{"current":{"weather_code":3,"cloud_cover":100,"wind_speed_10m":5}}"#
    #expect(LiveWeather.conditions(from: Data(bare.utf8))?.snowDepth == 0)
}

/// Weather's stars turn with the sky. A star among them has to land on screen where the Sun and Moon's own path
/// (`Sky.horizonMatrix`, then `SkyCamera.screen`) puts its direction, and, looking west, sink as the minutes pass.
/// `place` is what `skyStars` does in the sky shader.
@Test func weatherStarsTurnWithTheSky() throws {
    let camera = SkyCamera(aspect: 1.5, horizon: 0.45, facing: 1.5 * .pi)
    let date = Date(timeIntervalSince1970: 1_790_000_000), later = date.addingTimeInterval(600)
    func toHorizon(_ date: Date) -> simd_double3x3 { Sky.horizonMatrix(jd: Sky.julianDate(date), latitude: 40, longitude: -90) }
    func place(_ star: Sky.Vector, _ date: Date) -> SIMD2<Double> {
        let lens = camera.amongStars(date, latitude: 40, longitude: -90).transpose * star
        return [0.5 + lens.x / lens.y / (2 * camera.tanH), camera.horizon + lens.z / lens.y / (2 * camera.tanV)]
    }
    let star = toHorizon(date).transpose * camera.ray(0.3, 0.8) // the star behind one point on screen
    #expect(distance(place(star, date), [0.3, 0.8]) < 1e-9)
    let moved = try #require(camera.screen(toHorizon(later) * star))
    #expect(distance(place(star, later), moved) < 1e-9)
    #expect(moved.y < 0.78 && moved.x > 0.3) // setting, down and to the north
}

/// Every cumulus in Weather's pool has its photo, and none of them is a tower but the one. A missing photo would draw
/// nothing: `packedCloud` falls back to an empty texture.
@MainActor @Test func weatherCloudsHaveTheirPhotos() {
    for cloud in WeatherScene.photoClouds {
        #expect(FileManager.default.fileExists(atPath: resource("weather-cloud-\(cloud.name).heic").path), "\(cloud.name)")
        #expect(cloud.lum.x < cloud.lum.y)
    }
    #expect(WeatherScene.photoClouds.filter(\.tower).count == 1)
}

/// The grass's year on Weather's hills: Fort Ord's own grass (linear R/G 0.75, B/G 0.29), multiplied by `grass`,
/// comes out as dormant straw (R/G 1.30, B/G 0.58, 1.6 times as bright) and at its peak as green (R/G 0.70, B/G 0.30).
@MainActor @Test func weatherGrassTurnsWithTheYear() {
    let fortOrd = SIMD3<Float>(0.75, 1, 0.29)
    for (g, rg, bg, bright) in [(0.0, 1.30, 0.58, 1.6), (1.0, 0.70, 0.30, 1.0)] {
        let m = WeatherScene.grass(greenness: g), lit = fortOrd * m * m
        #expect(abs(Double(lit.x / lit.y) - rg) < 0.01 && abs(Double(lit.z / lit.y) - bg) < 0.01)
        let luminance = { (c: SIMD3<Float>) in Double(0.2126 * c.x + 0.7152 * c.y + 0.0722 * c.z) }
        #expect(abs(luminance(lit) / luminance(fortOrd) - bright) < 0.01)
    }
}
