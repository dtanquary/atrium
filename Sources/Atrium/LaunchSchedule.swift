import Foundation

/// The next real launches, from Launch Library 2 by The Space Devs (free, no key), for Pixel Spaceport's Follow real
/// launches. One fetch is shared by every scene and display, so they agree and the calls stay few. The feed allows
/// 15 requests an hour from one address, and every Mac behind one router shares that, so a Mac asks about once an
/// hour, plus three times before each launch the Spaceport could fly: 12 minutes out (whether to clear the pad for
/// it), 3 (just before the roll-out commits) and 1 (a late hold). Call `poll()` now and then; read `launches`;
/// observe `changed`. Each fetch writes a line for Settings to `spaceport.status`.
@MainActor final class LaunchSchedule {
    static let shared = LaunchSchedule()
    /// Posted when a new list lands in `launches`.
    static let changed = Notification.Name("LaunchSchedule.changed")
    /// The time the Spaceport counts down by. The tests set it to run a count through in a moment.
    static var now: () -> Date = { Date() }

    /// A launch as the feed lists it.
    struct Launch: Equatable {
        /// Go for Launch, On Hold and Launch in Flight: the only statuses asked for, by Launch Library's ids.
        enum Status: Int { case go = 1, hold = 5, inFlight = 6 }
        var rocket: String  // the feed's name for the vehicle: "Falcon 9 Block 5"
        var mission: String // "Starlink Group 15-25"
        var net: Date       // T−0, as last given
        var status: Status
        /// Which of the Spaceport's rockets this is, as the end of its switch's key ("falcon9"), or nil for one it doesn't draw.
        var kind: String? { LaunchSchedule.kind(of: rocket, mission: mission) }
    }

    /// The launches the last reply listed, soonest first, holds included: the scene decides what to do with those.
    private(set) var launches: [Launch] = []
    /// When the last reply arrived.
    private(set) var updated: Date?
    private var lastPoll = Date.distantPast, throttledUntil = Date.distantPast
    /// When the next fetch is due (see above).
    private(set) var nextPoll = Date.distantPast
    /// When Refresh Now can next fetch.
    var available: Date { max(lastPoll + 120, throttledUntil) }

    /// Fetches when a fetch is due (see above), or now with `force` (Refresh Now, at most every 2 minutes).
    /// Offline or throttled, `launches` stays as it was, so a count already running still ends at the T−0 last seen.
    func poll(force: Bool = false) {
        let now = Date()
        guard now >= throttledUntil, force ? now.timeIntervalSince(lastPoll) >= 120 : now >= nextPoll else { return }
        (lastPoll, nextPoll) = (now, now + 3600) // until the reply says otherwise
        var url = URLComponents(string: "https://ll.thespacedevs.com/2.3.0/launches/upcoming/")!
        // Go, On Hold or In Flight, with a T−0 known to the minute or second; eight is enough to reach one the Spaceport draws.
        url.queryItems = [URLQueryItem(name: "status__ids", value: "1,5,6"), URLQueryItem(name: "net_precision__ids", value: "0,1"),
                          URLQueryItem(name: "limit", value: "8"), URLQueryItem(name: "mode", value: "list"), URLQueryItem(name: "ordering", value: "net")]
        Task {
            let time = Date().formatted(date: .omitted, time: .shortened)
            guard let (data, response) = try? await URLSession.shared.data(from: url.url!) else { status("Couldn't reach Launch Library at \(time)."); return }
            if (response as? HTTPURLResponse)?.statusCode == 429 {
                // "Request was throttled. Expected available in 1234 seconds."
                let wait = (String(data: data, encoding: .utf8) ?? "").split(whereSeparator: { !$0.isNumber }).compactMap { Double($0) }.first ?? 900
                throttledUntil = Date() + min(wait, 3600)
                status("Launch Library allows 15 requests an hour from one address and has had them; asking again at \(throttledUntil.formatted(date: .omitted, time: .shortened)).")
                return
            }
            guard let found = Self.launches(from: data) else { status("Couldn't read Launch Library's reply at \(time)."); return }
            set(found)
        }
    }

    /// Takes a reply's launches as the current ones and plans the next poll. The tests call it with their own.
    func set(_ found: [Launch], at now: Date = Date()) {
        (launches, updated) = (found, now)
        var due = now + 3600
        if let next = found.first(where: { $0.kind != nil && $0.net > now }) {
            for lead in [720.0, 180, 60] where next.net - lead > now + 30 { due = min(due, next.net - lead) }
        }
        nextPoll = due
        let credit = "Launch Library 2 by The Space Devs · updated \(now.formatted(date: .omitted, time: .shortened))"
        if let next = found.first(where: { $0.kind != nil }) {
            let when = next.status == .hold ? "on hold" : next.net.formatted(date: .abbreviated, time: .shortened)
            status("Next: \(next.rocket) · \(next.mission) · \(when) · \(credit)")
        } else {
            status("No launch of a rocket the Spaceport draws has a time yet · \(credit)")
        }
        NotificationCenter.default.post(name: Self.changed, object: nil)
    }

    /// The launches in a Launch Library `launches/upcoming` reply in list mode, soonest first.
    nonisolated static func launches(from reply: Data) -> [Launch]? {
        struct Page: Decodable {
            struct Row: Decodable {
                struct Status: Decodable { let id: Int }
                let name: String, net: String, status: Status
            }
            let results: [Row]
        }
        guard let rows = try? JSONDecoder().decode(Page.self, from: reply).results else { return nil }
        let iso = ISO8601DateFormatter()
        return rows.compactMap { row in
            guard let net = iso.date(from: row.net), let status = Launch.Status(rawValue: row.status.id) else { return nil }
            let parts = row.name.components(separatedBy: " | ") // "Falcon 9 Block 5 | Starlink Group 15-25"
            return Launch(rocket: parts[0], mission: parts.count > 1 ? parts[1] : "", net: net, status: status)
        }.sorted { $0.net < $1.net }
    }

    /// Which of the Spaceport's rockets a launch is, by the feed's name for the vehicle, as the end of the rocket's
    /// switch key; nil for one it doesn't draw (Nuri, Vega-C, Kuaizhou, Atlas V...). Any Long March stands in for
    /// our Long March 5 and any GSLV or PSLV for our LVM3, as Dave agreed; a Falcon 9 under a Dragon is told by its mission.
    nonisolated static func kind(of rocket: String, mission: String) -> String? {
        let name = rocket.lowercased()
        let kinds = [("falcon 9", "falcon9"), ("falcon heavy", "heavy"), ("starship", "starship"), ("soyuz", "soyuz"), ("long march", "longmarch"),
                     ("h3", "h3"), ("lvm", "lvm3"), ("gslv", "lvm3"), ("pslv", "lvm3"), ("ariane 6", "ariane6"), ("vulcan", "vulcan"),
                     ("new glenn", "newglenn"), ("electron", "electron"), ("sls", "sls"), ("space launch system", "sls")]
        guard let kind = kinds.first(where: { name.hasPrefix($0.0) })?.1 else { return nil }
        if kind == "falcon9", ["dragon", "crs", "crew"].contains(where: { mission.lowercased().contains($0) }) { return "dragon" }
        return kind
    }

    private func status(_ text: String) { UserDefaults.standard.set(text, forKey: "spaceport.status") }
}
