import Foundation
import Testing
@testable import Atrium

/// Beehive's clock: a comb begins at ten at night, has a quarter drawn out by six, 58% at noon and all of it by six the
/// next morning; `hour(of:)` is `built` backwards. Its day runs from ten to ten (Ant Colony's `day(at:)` with another
/// dawn), and the comb before the first of a month is the last day of the month before's.
@MainActor @Test func beehiveDrawsACombADayFromTenAtNight() throws {
    #expect(Beehive.built(-8) == 0 && Beehive.built(0) == 0.25 && abs(Beehive.built(6) - 0.578) < 0.001 && Beehive.built(24) == 1)
    for share in [0.0, 0.1, 0.25, 0.6, 0.99] { #expect(abs(Beehive.built(Beehive.hour(of: share)) - share) < 1e-9) }
    #expect(Beehive.Key(day: 20261201, turn: 0).previous == Beehive.Key(day: 20261130, turn: 0))
    #expect(Beehive.Key(day: 20270101, turn: 0).previous == Beehive.Key(day: 20261231, turn: 0))
    #expect(Beehive.Key(day: 20261120, turn: 3).previous == Beehive.Key(day: 20261120, turn: 2))
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "America/Chicago"))
    func wall(_ day: Int, _ hour: Int) -> Double {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!.timeIntervalSinceReferenceDate
    }
    let late = AntColony.day(at: wall(20, 23), dawn: 22, calendar: calendar), before = AntColony.day(at: wall(21, 21), dawn: 22, calendar: calendar)
    #expect(late.day == 20261120 && abs(late.hours - 1) < 1e-9 && before.day == 20261120 && abs(before.hours - 23) < 1e-9)
    #expect(AntColony.day(at: wall(21, 22), dawn: 22, calendar: calendar).day == 20261121)
}

/// The cold: at 22 °C no bee is in the cluster; at 5 °C 85% of them are, on the day's comb.
@Test func beehiveBeesClusterInTheCold() {
    let ppm = 14 / 5.74, comb = Comb(seed: 2026112000, wide: 1512, high: 317.5, cell: 14)
    var bees = Bees(ppm: ppm)
    for i in comb.share.indices where comb.share[i] <= 1 {
        bees.world.at.append(comb.at[i] + SIMD2(0, 641))
        bees.world.share.append(comb.share[i])
        bees.world.fill.append(comb.fill[i])
        bees.world.cap.append(comb.cap[i])
        bees.world.ahead.append(0)
    }
    for (air, share) in [(22.0, 0.0), (5.0, 0.85)] {
        bees.survey(hours: 17, seen: 0...982, wide: 1512, air: air)
        bees.populate(499)
        let clustered = bees.bees.count { $0.state == .cluster }
        #expect(abs(Double(clustered) - share * 499) <= 1, "\(clustered) bees in the cluster at \(air) °C")
    }
}
