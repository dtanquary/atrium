import Foundation
import Testing
@testable import Atrium

/// Reads a real Helioviewer `getClosestImage` reply (AIA 171, 2026-09-27).
@Test func sunFrameParses() throws {
    let reply = #"{"id":"192465369","date":"2026-09-27 01:08:45","name":"AIA 171","scale":0.6014741692396856,"width":4096,"height":4096,"rsun":1595.488}"#
    let frame = try #require(SunImages.frame(Data(reply.utf8)))
    #expect(frame.id == "192465369")
    #expect(frame.date == Date(timeIntervalSince1970: 1_790_471_325)) // 01:08:45 UTC
    #expect(SunImages.frame(Data(#"{"error":"No images"}"#.utf8)) == nil)
}

/// The Sun's north pole tips furthest toward us in early September and away in early March, 7.25° each way.
@Test func sunTiltFollowsTheYear() {
    func degrees(_ iso: String) -> Double { Double(sunTilt(at: try! Date(iso, strategy: .iso8601))) * 180 / .pi }
    #expect(abs(degrees("2026-09-08T00:00:00Z") - 7.25) < 0.1)
    #expect(abs(degrees("2026-03-07T00:00:00Z") + 7.25) < 0.1)
    #expect(abs(degrees("2026-06-06T00:00:00Z")) < 0.3)
}

/// Reads real replies from SWPC's GOES flare feed: a C flare isn't shown, an M flare is while under way and for an
/// hour after it ends, and one still under way four hours on is a stale feed.
@MainActor @Test func realFlaresParse() throws {
    let c = #"[{"time_tag": "2026-11-16T14:49:00Z", "satellite": 18, "current_class": "B5.7", "begin_time": "2026-11-16T11:25:00Z", "begin_class": "B6.0", "max_time": "2026-11-16T11:36:00Z", "max_class": "C2.3", "end_time": "2026-11-16T11:40:00Z", "end_class": "C1.3"}]"#
    let m = #"[{"time_tag": "2026-11-11T21:06:00Z", "begin_time": "2026-11-11T21:06:00Z", "begin_class": "C1.2", "max_time": "2026-11-11T21:21:00Z", "max_class": "M1.7", "end_time": "2026-11-11T21:29:00Z", "end_class": "C9.5", "satellite": 18}]"#
    let small = try #require(SunImages.flare(Data(c.utf8))), big = try #require(SunImages.flare(Data(m.utf8)))
    #expect(small.name == "C2.3" && !small.isNow(small.peak))
    #expect(big.name == "M1.7" && big.peak == Date(timeIntervalSince1970: 1_794_432_060)) // 21:21 UTC
    #expect(big.isNow(big.end!.addingTimeInterval(50 * 60)) && !big.isNow(big.end!.addingTimeInterval(70 * 60)))
    let underWay = try #require(SunImages.flare(Data(m.replacingOccurrences(of: #""end_time": "2026-11-11T21:29:00Z", "#, with: "").utf8)))
    #expect(underWay.end == nil && underWay.caption == "an M1.7 flare under way")
    #expect(underWay.isNow(underWay.begin.addingTimeInterval(3600)) && !underWay.isNow(underWay.begin.addingTimeInterval(5 * 3600)))
    #expect(SunImages.flare(Data("[]".utf8)) == nil)
}
