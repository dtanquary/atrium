import Foundation
import Synchronization
import Testing
@testable import Atrium

/// The sample day's records read as the research's reader (docs/seismograph/mseed.py, checked against the records'
/// own check values) reads them, and the long-period band shows the M6.6's train: over a row's spacing in the hour
/// and a half after 15:30 on the 16th (US Central), and the quiet small hours inside a third of a row.
@Test func seismographReadsARealDayAndFindsItsQuake() throws {
    let records = MiniSEED.records(try Data(contentsOf: resource(Seismograph.sample.file)))
    #expect(records.count == 929 && records.allSatisfy { $0.id == "NL.HGN.02.LHZ" && $0.rate == 1 })
    #expect(records.reduce(0) { $0 + $1.samples.count } == 194_641)
    #expect(Array(records[0].samples.prefix(5)) == [96, -988, -174, 2042, 1023] && Array(records[100].samples.suffix(3)) == [1374, 1983, 1097])
    #expect(abs(records[0].start - 1_794_700_642.0695) < 0.001) // 2026-11-14 23:57:22.0695 UTC

    var ground = Ground()
    for record in records { ground.add(record) }
    let trace = ground.trace(sensitivity: 1), midnight = Seismograph.sample.midnight - ground.start
    func peak(_ from: Double, _ to: Double) -> Float { trace[(midnight + Int(from * 3600))..<(midnight + Int(to * 3600))].map(abs).max() ?? 0 }
    #expect(peak(15.5, 17) > 1 && peak(2, 6) < 0.33)
}

/// The live path, against EarthScope itself, only when asked (`SEISMO_LIVE=1`): the station list finds NW.L44A
/// nearest a place by Chicago, SeedLink sends its records from an hour ago, and the archive serves the hour
/// before that. Each record read is the station's LHZ at a sample a second.
@Test(.enabled(if: ProcessInfo.processInfo.environment["SEISMO_LIVE"] != nil)) func seismographStreamsAStationLive() async throws {
    #expect(SeismicStation.all.count > 500)
    let station = try #require(SeismicStation.nearest(latitude: 42.2, longitude: -87.9))
    #expect(station.id == "NW.L44A.00.LHZ")
    let now = Date().timeIntervalSince1970
    let got = Mutex<[SeismicRecord]>([]), ended = Mutex(false)
    let link = SeedLink(station: station, from: now - 3600, record: { r in got.withLock { $0.append(r) } }, ended: { ended.withLock { $0 = true } })
    for _ in 0..<60 where got.withLock({ $0.count }) < 2 { try await Task.sleep(for: .seconds(1)) }
    link.cancel()
    let records = got.withLock { $0 }
    #expect(records.count >= 2 && records.allSatisfy { $0.id == station.id && $0.rate == 1 })
    if let last = records.last { #expect(now - (last.start + Double(last.samples.count)) < 900) } // under a quarter of an hour behind
    let archived = await SeismicFeed.archive(station, from: now - 7200, to: now - 3600)
    #expect(archived.reduce(0) { $0 + $1.samples.count } > 3000)
}

/// The feed as the scene drives it, only when asked (`SEISMO_LIVE=1`): attached and moved on each frame, it picks the
/// nearest station, fills the two days the sheet shows from the archive, says so in its status line, and lets it all
/// go when the last scene leaves.
@MainActor @Test(.enabled(if: ProcessInfo.processInfo.environment["SEISMO_LIVE"] != nil)) func seismographFeedFillsTwoDays() async throws {
    let feed = SeismicFeed.shared
    feed.attach()
    for _ in 0..<300 where feed.hours < Seismograph.liveHours {
        feed.tick(Date().timeIntervalSince1970, live: true)
        try await Task.sleep(for: .milliseconds(100))
    }
    #expect(feed.hours >= Seismograph.liveHours && feed.station != nil)
    #expect(UserDefaults.standard.string(forKey: "seismograph.status")?.hasPrefix("Live from \(feed.station!.network).\(feed.station!.code)") == true)
    print("seismograph feed:", feed.station!.id, feed.hours, "hours;", UserDefaults.standard.string(forKey: "seismograph.status") ?? "")
    feed.detach()
    #expect(feed.station == nil && feed.ground.counts.isEmpty)
}
