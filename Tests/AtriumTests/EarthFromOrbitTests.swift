import Foundation
import Testing
@testable import Atrium

/// The stars behind Earth from Orbit are the sky straight down from you, seen as from inside it like any sky: with
/// Orion behind the Earth, Betelgeuse stands above Rigel and to its left (the sky's east), and the nadir is behind
/// the globe's centre. A mirrored or turned sky fails here.
@Test func starsBehindTheEarthAreTheSkyBelow() throws {
    let (latitude, sidereal) = (0.0, 264.0) // the nadir at RA 84°, Dec 0: Orion's belt
    let nadir = try #require(EarthFromOrbit.behind(Sky.direction(84, 0), latitude: latitude, sidereal: sidereal))
    #expect(abs(nadir.x) < 1e-9 && abs(nadir.y) < 1e-9)
    let betelgeuse = try #require(EarthFromOrbit.behind(Sky.direction(88.79, 7.41), latitude: latitude, sidereal: sidereal))
    let rigel = try #require(EarthFromOrbit.behind(Sky.direction(78.63, -8.20), latitude: latitude, sidereal: sidereal))
    #expect(betelgeuse.y > rigel.y && betelgeuse.x < rigel.x)
    #expect(EarthFromOrbit.behind(Sky.direction(264, 0), latitude: latitude, sidereal: sidereal) == nil) // overhead
}

/// Earth from Orbit shows the month's Blue Marble, so every month needs its map: one missing would leave the globe
/// blank for that month alone.
@Test func earthHasAMapForEveryMonth() {
    for month in 1...12 {
        #expect(FileManager.default.fileExists(atPath: resource(EarthFromOrbit.dayMap(month: month)).path), "month \(month)")
    }
}
