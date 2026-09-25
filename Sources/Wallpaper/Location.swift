import CoreLocation

/// Where the viewer is, for scenes that show the real sky or weather. Call `start()` from a scene's
/// `didMove(to:)`; read `coordinate` whenever you recompute. The last fix is remembered across launches.
@MainActor final class Location: NSObject, CLLocationManagerDelegate {
    static let shared = Location()

    private let manager = CLLocationManager()
    private(set) var coordinate: CLLocationCoordinate2D

    override init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "latitude") != nil {
            coordinate = CLLocationCoordinate2D(latitude: defaults.double(forKey: "latitude"),
                                                longitude: defaults.double(forKey: "longitude"))
        } else {
            // ponytail: guess from the time zone until CoreLocation answers; latitude can be ~15° off
            coordinate = CLLocationCoordinate2D(latitude: 40, longitude: Double(TimeZone.current.secondsFromGMT()) / 240)
        }
        super.init()
        manager.delegate = self
    }

    func start() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization() // answer arrives in locationManagerDidChangeAuthorization
        } else {
            manager.requestLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_: CLLocationManager) {
        MainActor.assumeIsolated {
            if manager.authorizationStatus == .authorizedAlways { manager.requestLocation() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let fix = locations.last?.coordinate else { return }
        MainActor.assumeIsolated {
            coordinate = fix
            UserDefaults.standard.set(fix.latitude, forKey: "latitude")
            UserDefaults.standard.set(fix.longitude, forKey: "longitude")
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {}
}
