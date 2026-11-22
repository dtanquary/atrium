import Foundation
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
