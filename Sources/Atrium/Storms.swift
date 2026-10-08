import CoreLocation

/// Where thunderstorms are around you, as Open-Meteo's weather models forecast them hour by hour (free, no key, CC BY
/// 4.0): the weather code on a grid of points 4° apart, 40° of latitude by 56° of longitude centred on you, for the
/// next 24 hours, fetched in one request every 6 hours (or now, with Refresh Now). These are forecast storms, not
/// observed strikes. Open-Meteo counts each of the 165 points as a call, so that's at most 660 of its free 10,000 a
/// day. Thunderstorms are small, so the grid stays this fine: a coarser one would find fewer, not coarser, storms.
@MainActor final class Storms {
    static let shared = Storms()
    typealias Cell = (latitude: Double, longitude: Double)
    /// How long a forecast serves before the next, and how soon Refresh Now can ask again.
    static let every: TimeInterval = 6 * 3600, cooldown: TimeInterval = 15 * 60

    /// Each grid point's weather code, hour by hour at `times`.
    private var forecast: (times: [Double], points: [(cell: Cell, codes: [Int])]) = ([], [])
    /// When the last forecast arrived.
    private(set) var updated: Date?
    private var lastTry = Date.distantPast

    /// Grid points with a thunderstorm this hour (weather codes 95, 96 and 99). None once the forecast has run out
    /// (offline for a day), rather than its last hour's storms for good.
    var cells: [Cell] {
        let now = Date().timeIntervalSince1970
        guard let hour = forecast.times.lastIndex(where: { $0 <= now }), now < forecast.times[hour] + 3600 else { return [] }
        return forecast.points.filter { hour < $0.codes.count && $0.codes[hour] >= 95 }.map(\.cell)
    }

    /// When Refresh Now can next fetch.
    var available: Date { lastTry + Self.cooldown }

    /// Fetches the storms once the forecast is `every` old, at most every 10 minutes however many displays ask; or
    /// now with `force` (Refresh Now), if the last try was over `cooldown` ago.
    func poll(around here: CLLocationCoordinate2D, force: Bool = false) {
        let since = abs(Date().timeIntervalSince(lastTry))
        guard force ? since > Self.cooldown : since > 600 && abs(Date().timeIntervalSince(updated ?? .distantPast)) > Self.every else { return }
        lastTry = Date()
        let points = stride(from: -20.0, through: 20, by: 4).flatMap { dlat in
            stride(from: -28.0, through: 28, by: 4).map { dlon in
                (min(max(here.latitude + dlat, -85), 85), remainder(here.longitude + dlon, 360))
            }
        }
        var url = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        url.queryItems = [
            URLQueryItem(name: "latitude", value: points.map { String(format: "%.2f", $0.0) }.joined(separator: ",")),
            URLQueryItem(name: "longitude", value: points.map { String(format: "%.2f", $0.1) }.joined(separator: ",")),
            URLQueryItem(name: "hourly", value: "weather_code"), URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "past_hours", value: "1"), URLQueryItem(name: "forecast_hours", value: "24"),
        ]
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url.url!),
                  let replies = try? JSONDecoder().decode([Reply].self, from: data), let times = replies.first?.hourly.time else { return }
            forecast = (times, replies.map { ((latitude: $0.latitude, longitude: $0.longitude), $0.hourly.codes.map { $0 ?? 0 }) })
            updated = Date()
        }
    }

    /// A made-up storm complex right over you, to see the lightning on demand.
    static func preview(around here: CLLocationCoordinate2D) -> [Cell] {
        [(0, 0), (0.9, 0.6), (-0.7, 1.1), (0.4, -1.2), (-0.5, -0.4)].map { (here.latitude + $0.0, here.longitude + $0.1) }
    }

    private struct Reply: Decodable {
        struct Hourly: Decodable {
            let time: [Double], codes: [Int?]
            enum CodingKeys: String, CodingKey { case time, codes = "weather_code" }
        }
        let latitude: Double, longitude: Double, hourly: Hourly
    }
}
