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
