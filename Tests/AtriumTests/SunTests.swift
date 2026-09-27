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
