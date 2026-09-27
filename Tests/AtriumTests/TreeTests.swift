import Foundation
import Testing
import TreeGrowth
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

    let planted = calendar.date(from: DateComponents(year: 2026, month: 9, day: 27))!
    let bud = oak.moved(latitude: 42, warmer: 0)
    #expect(bud.age(planted: planted, on: planted, latitude: 42) == 15)
    #expect(bud.age(planted: planted, on: calendar.date(from: DateComponents(year: 2027, month: 4, day: 20))!, latitude: 42) == 15)
    #expect(bud.age(planted: planted, on: calendar.date(from: DateComponents(year: 2027, month: 5, day: 1))!, latitude: 42) == 16)
    #expect(bud.age(planted: planted, on: calendar.date(from: DateComponents(year: 2036, month: 9, day: 27))!, latitude: 42) == 25)
    #expect(bud.age(planted: planted, on: calendar.date(from: DateComponents(year: 2026, month: 11, day: 1))!, latitude: -35) == 16) // southern spring
}

/// The same seed grows the same tree (it's this Mac's tree, every day), another seed a different one, and a year on
/// it's taller.
@Test func treeBakesTheSameTreeFromASeed() {
    let atlas = LeafAtlas(width: 8, height: 8, color: [UInt8](repeating: 255, count: 256), premultiplied: false, normal: nil, scatter: nil,
                          cells: [SIMD4(0, 0, 8, 8)])
    let bark = BarkImage(width: 1, height: 1, rgba: [128, 128, 128, 255])
    func bake(_ seed: UInt64, _ age: Int) -> TreeBake {
        TreeGrowth.bake(.whiteOak, seed: seed, age: age, pixels: SIMD2(1512, 982), atlas: atlas, bark: bark)
    }
    let a = bake(7, 15), b = bake(7, 15), c = bake(8, 15), older = bake(7, 16)
    #expect(a.slabs.map(\.woodLight) == b.slabs.map(\.woodLight) && a.slabs.map(\.leafSeed) == b.slabs.map(\.leafSeed))
    #expect(a.slabs.map(\.woodLight) != c.slabs.map(\.woodLight))
    #expect(older.height > a.height && a.leaves > 10_000)
}
