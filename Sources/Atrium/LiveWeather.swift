import CoreLocation

/// The weather where you are right now, from Open-Meteo (free, no key, CC BY 4.0), shared by every scene and display
/// that shows it, so they agree and the calls stay few. Call `poll()` from a scene's periodic action, read `latest`,
/// and observe `LiveWeather.changed` for new reports. Each fetch also writes a line for Settings to `weather.status`.
@MainActor final class LiveWeather {
    static let shared = LiveWeather()
    /// Posted when a new report lands in `latest`.
    static let changed = Notification.Name("LiveWeather.changed")

    /// The current weather as Open-Meteo reports it.
    struct Conditions: Equatable {
        var code = 2          // WMO weather code
        var cloudCover = 40.0 // percent
        var wind = 10.0       // km/h
        var windFrom = 270.0  // degrees clockwise from north
        var highCloud = 0.0   // percent: cirrus
        var snowDepth = 0.0   // m of snow on the ground
        var visibility = 30000.0 // m
        var precipitationTotal = 0.0 // mm in the preceding 15 minutes (Open-Meteo's `current` interval): rain, showers and snow as water
        var rain = 0.0        // mm in the preceding 15 minutes, from weather fronts
        var showers = 0.0     // mm in the preceding 15 minutes, from convective showers
        var snowfall = 0.0    // cm in the preceding 15 minutes
        var temperature = 15.0 // °C at 2 m
        var humidity = 70.0   // percent at 2 m
        var dewPoint = 10.0   // °C at 2 m
    }

    /// The last report, or nil before the first one lands.
    private(set) var latest: Conditions?
    /// When the last report arrived.
    private(set) var updated: Date?
    private var lastPoll = Date.distantPast
    /// When Refresh Now can next fetch.
    var available: Date { lastPoll + 300 }

    /// Fetches the weather now, but at most every 10 minutes however many scenes ask, or 5 with `force` (Refresh Now).
    /// Offline, `latest` stays as it was.
    func poll(force: Bool = false) {
        guard Date().timeIntervalSince(lastPoll) > (force ? 300 : 600) else { return }
        lastPoll = Date()
        let spot = Location.shared.coordinate
        var url = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        // 0.01° (about a kilometre) is finer than the forecast, and says no more than that about where you are
        url.queryItems = [URLQueryItem(name: "latitude", value: String(format: "%.2f", spot.latitude)),
                          URLQueryItem(name: "longitude", value: String(format: "%.2f", spot.longitude)),
                          URLQueryItem(name: "current", value: "weather_code,cloud_cover,cloud_cover_high,wind_speed_10m,wind_direction_10m,snow_depth,visibility,"
                                           + "precipitation,rain,showers,snowfall,temperature_2m,relative_humidity_2m,dew_point_2m")]
        Task {
            let time = Date().formatted(date: .omitted, time: .shortened)
            guard let (data, _) = try? await URLSession.shared.data(from: url.url!), let report = Self.conditions(from: data) else {
                let last = UserDefaults.standard.string(forKey: "weather.status") ?? ""
                UserDefaults.standard.set("Couldn't reach Open-Meteo at \(time). " + last.replacingOccurrences(of: #"^Couldn't reach.*?\. "#, with: "", options: .regularExpression),
                                          forKey: "weather.status")
                return
            }
            UserDefaults.standard.set("Live: \(report.summary) · \(Self.place(spot)) · updated \(time)", forKey: "weather.status")
            latest = report
            updated = Date()
            NotificationCenter.default.post(name: Self.changed, object: nil)
        }
    }

    /// Conditions from an Open-Meteo `current` reply.
    static func conditions(from reply: Data) -> Conditions? {
        struct Forecast: Decodable {
            struct Current: Decodable {
                let weatherCode: Int, cloudCover: Double, windSpeed: Double
                // Not every weather model has these.
                let windFrom: Double?, highCloud: Double?, snowDepth: Double?, visibility: Double?, precipitation: Double?, rain: Double?
                let showers: Double?, snowfall: Double?, temperature: Double?, humidity: Double?, dewPoint: Double?
                // Spelled out: .convertFromSnakeCase turns wind_speed_10m into windSpeed10M.
                enum CodingKeys: String, CodingKey {
                    case weatherCode = "weather_code", cloudCover = "cloud_cover", windSpeed = "wind_speed_10m"
                    case windFrom = "wind_direction_10m", highCloud = "cloud_cover_high", snowDepth = "snow_depth", visibility
                    case precipitation, rain, showers, snowfall, temperature = "temperature_2m", humidity = "relative_humidity_2m"
                    case dewPoint = "dew_point_2m"
                }
            }
            let current: Current
        }
        guard let now = try? JSONDecoder().decode(Forecast.self, from: reply).current else { return nil }
        let standard = Conditions()
        return Conditions(code: now.weatherCode, cloudCover: now.cloudCover, wind: now.windSpeed,
                          windFrom: now.windFrom ?? standard.windFrom, highCloud: now.highCloud ?? 0, snowDepth: now.snowDepth ?? 0,
                          visibility: now.visibility ?? standard.visibility, precipitationTotal: now.precipitation ?? 0,
                          rain: now.rain ?? 0, showers: now.showers ?? 0, snowfall: now.snowfall ?? 0,
                          temperature: now.temperature ?? standard.temperature, humidity: now.humidity ?? standard.humidity,
                          dewPoint: now.dewPoint ?? standard.dewPoint)
    }

    /// Where the weather is for, as 42.18°N 88.41°W.
    private static func place(_ spot: CLLocationCoordinate2D) -> String {
        String(format: "%.2f°%@ %.2f°%@", abs(spot.latitude), spot.latitude >= 0 ? "N" : "S", abs(spot.longitude), spot.longitude >= 0 ? "E" : "W")
    }
}
