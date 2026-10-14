import Foundation
import Testing
@testable import Atrium

/// `setIfChanged` writes, and so tells every observer, only when the value differs: the second of two equal writes
/// posts nothing. A suite of its own, so writes from other tests or a running Atrium aren't counted.
@Test func unchangedWritesPostNothing() {
    let name = "com.dtanquary.atrium.tests.\(UUID().uuidString)", defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    var posted = 0
    let observer = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: defaults, queue: nil) { _ in posted += 1 }
    defer { NotificationCenter.default.removeObserver(observer) }
    let values: [Any?] = ["Live: 3 °C · updated 8:44 PM", ["Saturn": 2, "Io": 1], ["Saturn", "Io"], 3.5, Date(timeIntervalSince1970: 1), nil]
    for (i, value) in values.enumerated() {
        let key = "key\(i)"
        defaults.set("something else", forKey: key)
        posted = 0
        defaults.setIfChanged(value, forKey: key)
        defaults.setIfChanged(value, forKey: key)
        #expect(posted == 1, "\(String(describing: value))")
        #expect(defaults.object(forKey: key) as? NSObject == value as? NSObject)
    }
}
