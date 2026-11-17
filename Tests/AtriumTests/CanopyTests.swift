import Foundation
import SpriteKit
import Testing
import CanopyBake
@testable import Atrium

/// Canopy's year at 42°N: coming out in May, in full leaf in July, turned and thinning in early November, bare in
/// January.
@Test func canopySeasons() {
    func on(_ month: Int, _ day: Int) -> CanopySeason {
        CanopySeason(date: Calendar.current.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!, latitude: 42)
    }
    let (may, july, november, january) = (on(5, 12), on(7, 15), on(11, 5), on(1, 15))
    #expect(may.out > 0.2 && may.out < 1 && may.pale > 0)
    #expect(july.out == 1 && july.turned == 0 && july.fallen == 0 && july.pale == 0)
    #expect(november.turned > 0.9 && november.fallen > 0.2 && november.fallen < 0.9)
    #expect(january.out == 0)
}

/// What building Canopy holds the main thread for, and its bake off it, at a 14" MacBook Pro's size: meaningful in a
/// release build: `CANOPY_LOAD=1 swift test -c release -Xswiftc -enable-testing --filter canopyLoad`.
@MainActor @Test(.enabled(if: ProcessInfo.processInfo.environment["CANOPY_LOAD"] != nil)) func canopyLoad() {
    let clock = ContinuousClock(), size = CGSize(width: 1512, height: 982)
    let camera = Canopy.Camera(size: size), date = Canopy.moment(day: "2026-07-15", hour: 15.5)
    let light = Canopy.Light(camera: camera, date: date, latitude: 42, longitude: -88)
    let bake = CanopyBake(stand: resource(Canopy.stand.name), leaves: resource("dappled-leaves.png"), perTan: Canopy.stand.perTan,
                          extent: camera.extent, portrait: false, sun: light.sun, sunlight: light.sunlight, zenith: light.zenith,
                          season: CanopySeason(date: date, latitude: 42), seed: 3)
    var made: CanopyBake.Made?
    let baked = (0..<2).map { _ in clock.measure { made = bake.make() } }.min()!
    let built = (0..<3).map { _ in clock.measure { _ = Canopy(size: size) } }
    #expect(made.map { $0.canopy.count == $0.width * $0.height * 4 } == true)
    print("Canopy at 1512 x 982: built on the main thread in \(built.map { $0.formatted(.units(allowed: [.milliseconds])) }), baked off it in \(baked.formatted(.units(allowed: [.milliseconds])))")
}
