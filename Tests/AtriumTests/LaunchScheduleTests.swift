import Foundation
import Testing
@testable import Atrium

/// Launch Library 2's list-mode reply, as saved on 2026-10-07 and trimmed to what's read, parses to launches soonest
/// first, dropping the statuses not asked for and any T−0 known only to the hour; and the feed's names for vehicles map
/// to the Spaceport's rockets.
@MainActor @Test func launchScheduleReadsLaunchLibrary() throws {
    let reply = #"{"count":5,"next":null,"results":[{"id":"a","name":"Falcon 9 Block 5 | Starlink Group 15-25","status":{"id":1,"name":"Go for Launch","abbrev":"Go"},"net":"2026-10-10T23:00:00Z","net_precision":{"id":1,"abbrev":"MIN"},"window_start":"2026-10-10T23:00:00Z"},{"id":"b","name":"Nuri | NeonSat-2 to 6","status":{"id":1,"abbrev":"Go"},"net":"2026-10-07T03:23:00Z","net_precision":{"id":1,"abbrev":"MIN"}},{"id":"c","name":"Long March 12 | Unknown Payload","status":{"id":5,"abbrev":"Hold"},"net":"2026-10-09T19:25:00Z","net_precision":{"id":1,"abbrev":"MIN"}},{"id":"e","name":"Long March 2D | Hourly","status":{"id":1,"abbrev":"Go"},"net":"2026-10-09T20:00:00Z","net_precision":{"id":2,"abbrev":"HR"}},{"id":"d","name":"Oddity","status":{"id":2,"abbrev":"TBD"},"net":"2026-10-31T00:00:00Z"}]}"#
    let launches = try #require(LaunchSchedule.launches(from: Data(reply.utf8)))
    #expect(launches.map(\.rocket) == ["Nuri", "Long March 12", "Falcon 9 Block 5"], "\(launches)")
    #expect(launches.map(\.kind) == [nil, "longmarch", "falcon9"] && launches[1].status == .hold && launches[2].mission == "Starlink Group 15-25")
    #expect(launches[2].net == ISO8601DateFormatter().date(from: "2026-10-10T23:00:00Z"))
    let names: [(String, String, String?)] = [("Falcon 9 Block 5", "CRS2 SpX-35 (Dragon)", "dragon"), ("Falcon 9 Block 5", "Crew-14", "dragon"), ("Falcon Heavy", "", "heavy"),
                                             ("Starship", "", "starship"), ("Soyuz 2.1b", "", "soyuz"), ("LVM-3 (GSLV Mk III)", "", "lvm3"), ("PSLV-XL", "", "lvm3"),
                                             ("H3-24", "", "h3"), ("Ariane 64", "", "ariane6"), ("Vulcan VC6L", "", "vulcan"), ("New Glenn", "", "newglenn"),
                                             ("Electron", "", "electron"), ("SLS Block 1", "", "sls"), ("Vega-C", "", nil), ("Atlas V 551", "", nil), ("Kuaizhou-1A", "", nil)]
    for (name, mission, kind) in names { #expect(LaunchSchedule.kind(of: name, mission: mission) == kind, "\(name)") }
}

/// After a reply the next fetch is planned for 12, 3 and 1 minutes before the next launch the Spaceport draws, and
/// an hour on otherwise. (`set` only plans; `poll` fetches when due, so nothing here touches the network.)
@MainActor @Test func launchSchedulePlansItsPolls() {
    let now = Date(), schedule = LaunchSchedule.shared
    defer { schedule.set([], at: now) }
    func launch(_ rocket: String, in seconds: TimeInterval) -> LaunchSchedule.Launch { .init(rocket: rocket, mission: "", net: now + seconds, status: .go) }
    schedule.set([launch("Nuri", in: 600), launch("Falcon 9 Block 5", in: 1800)], at: now)
    #expect(schedule.nextPoll == now + 1800 - 720)
    schedule.set([launch("Falcon 9 Block 5", in: 150)], at: now)
    #expect(schedule.nextPoll == now + 150 - 60)
    schedule.set([launch("Falcon 9 Block 5", in: 20), launch("Electron", in: 7200)], at: now)
    #expect(schedule.nextPoll == now + 3600)
    #expect((UserDefaults.standard.string(forKey: "spaceport.status") ?? "").hasPrefix("Next: Falcon 9 Block 5"))
}

/// A rehearsal planted through its defaults key goes into the list without a fetch, stays there when a real reply
/// replaces the rest, and is dropped a minute after its T−0.
@MainActor @Test func launchScheduleKeepsARehearsal() {
    let now = Date(), schedule = LaunchSchedule.shared
    defer { schedule.set([], at: now + 1000); UserDefaults.standard.removeObject(forKey: "spaceport.rehearse") }
    UserDefaults.standard.set(240, forKey: "spaceport.rehearse")
    schedule.poll()
    #expect(schedule.launches.map(\.mission) == ["Rehearsal"] && UserDefaults.standard.object(forKey: "spaceport.rehearse") == nil)
    let real = LaunchSchedule.Launch(rocket: "Electron", mission: "Real", net: now + 7200, status: .go)
    schedule.set([real], at: now + 60)
    #expect(schedule.launches.map(\.mission) == ["Rehearsal", "Real"])
    schedule.set([real], at: now + 240 + 61)
    #expect(schedule.launches.map(\.mission) == ["Real"])
}
