import Foundation

/// Where the ISS is, from api.wheretheiss.at (free, no key). Each poll fetches the next 90 seconds of
/// positions, so scenes polling once a minute can interpolate smoothly in between.
@MainActor final class ISS {
    static let shared = ISS()

    private struct Fix: Decodable {
        let latitude: Double, longitude: Double, altitude: Double, timestamp: Double
        let visibility: String
    }

    private var track: [Fix] = []
    private var lastPoll = Date.distantPast

    /// Fetches fresh positions, at most every 50 s however many scenes and displays ask.
    func poll() {
        guard Date().timeIntervalSince(lastPoll) > 50 else { return }
        lastPoll = Date()
        let now = Int(Date().timeIntervalSince1970)
        let stamps = stride(from: now, through: now + 90, by: 10).map(String.init).joined(separator: ",")
        let url = URL(string: "https://api.wheretheiss.at/v1/satellites/25544/positions?timestamps=\(stamps)")!
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let fixes = try? JSONDecoder().decode([Fix].self, from: data) else { return }
            track = fixes
        }
    }

    /// Latitude/longitude (degrees), altitude (km) and whether it's in sunlight; nil without fresh data.
    func position(at date: Date = Date()) -> (latitude: Double, longitude: Double, altitude: Double, sunlit: Bool)? {
        let t = date.timeIntervalSince1970
        guard let i = track.firstIndex(where: { $0.timestamp > t }), i > 0 else { return nil }
        let (a, b) = (track[i - 1], track[i])
        let f = (t - a.timestamp) / (b.timestamp - a.timestamp)
        return (a.latitude + (b.latitude - a.latitude) * f,
                a.longitude + remainder(b.longitude - a.longitude, 360) * f,
                a.altitude + (b.altitude - a.altitude) * f,
                (f < 0.5 ? a : b).visibility == "daylight")
    }
}
