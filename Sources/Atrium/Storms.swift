import CoreLocation

/// Where thunderstorms are around you, as Open-Meteo's weather models have them now (free, no key, CC BY 4.0): the
/// current weather code on a grid of points 4° apart, 40° of latitude by 56° of longitude centred on you, fetched
/// in one request. These are forecast storms, not observed strikes.
@MainActor final class Storms {
    static let shared = Storms()
    typealias Cell = (latitude: Double, longitude: Double)

    /// Grid points with a thunderstorm now (weather codes 95, 96 and 99).
    private(set) var cells: [Cell] = []
    private var lastPoll = Date.distantPast
    /// Seconds since the last poll.
    var age: TimeInterval { Date().timeIntervalSince(lastPoll) }

    /// Fetches the storms now, but at most every 10 minutes however many displays ask. Earth from Orbit calls this
    /// when a new cloud map lands, about every three hours, so the flashes match the clouds; Open-Meteo counts each of
    /// the 165 points as a call, so that's about 1,300 of its free 10,000 a day.
    func poll(around here: CLLocationCoordinate2D) {
        guard age > 600 else { return }
        lastPoll = Date()
        let points = stride(from: -20.0, through: 20, by: 4).flatMap { dlat in
            stride(from: -28.0, through: 28, by: 4).map { dlon in
                (min(max(here.latitude + dlat, -85), 85), remainder(here.longitude + dlon, 360))
            }
        }
        var url = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        url.queryItems = [
            URLQueryItem(name: "latitude", value: points.map { String(format: "%.2f", $0.0) }.joined(separator: ",")),
            URLQueryItem(name: "longitude", value: points.map { String(format: "%.2f", $0.1) }.joined(separator: ",")),
            URLQueryItem(name: "current", value: "weather_code"),
        ]
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url.url!),
                  let replies = try? JSONDecoder().decode([Reply].self, from: data) else { return }
            cells = replies.filter { $0.current.weatherCode >= 95 }.map { ($0.latitude, $0.longitude) }
        }
    }

    /// A made-up storm complex right over you, to see the lightning on demand.
    static func preview(around here: CLLocationCoordinate2D) -> [Cell] {
        [(0, 0), (0.9, 0.6), (-0.7, 1.1), (0.4, -1.2), (-0.5, -0.4)].map { (here.latitude + $0.0, here.longitude + $0.1) }
    }

    private struct Reply: Decodable {
        struct Current: Decodable {
            let weatherCode: Int
            enum CodingKeys: String, CodingKey { case weatherCode = "weather_code" }
        }
        let latitude: Double, longitude: Double, current: Current
    }
}
