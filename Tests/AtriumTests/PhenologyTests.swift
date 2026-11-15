import Foundation
import Testing
@testable import Atrium

/// At 42°N the calendar is the reference; further north spring is later and autumn sooner; south of the equator the
/// season is half a year on; and the season's day never jumps, even across New Year or in the southern hemisphere.
@Test func phenologyFollowsLatitude() {
    let oak = Phenology.whiteOak
    #expect(oak.moved(latitude: 42, warmer: 0) == oak)
    let north = oak.moved(latitude: 46, warmer: 0)
    #expect(north.breaks == oak.breaks + 16 && north.peak == oak.peak - 12)
    #expect(oak.moved(latitude: 90, warmer: 0) == oak.moved(latitude: 50, warmer: 0)) // held to 28°–50°
    #expect(oak.moved(latitude: -42, warmer: 1).breaks == oak.breaks - 4)

    let calendar = Calendar.current
    let june = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21))!
    let december = calendar.date(from: DateComponents(year: 2026, month: 12, day: 21))!
    #expect(abs(Phenology.day(december, latitude: -35) - Phenology.day(june, latitude: 35)) < 1.5)

    for latitude in [42.0, -35] {
        var previous = Phenology.day(calendar.date(from: DateComponents(year: 2025, month: 12, day: 1))!, latitude: latitude)
        for hour in stride(from: 1.0, through: 24 * 400, by: 1) {
            let day = Phenology.day(calendar.date(from: DateComponents(year: 2025, month: 12, day: 1))!.addingTimeInterval(hour * 3600), latitude: latitude)
            let step = day - previous
            #expect(abs(step - 1.0 / 24) < 0.01 || day < 1.1, "day \(day) after \(previous) at \(latitude)°")
            previous = day
        }
    }
}
