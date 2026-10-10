import SpriteKit
import Testing
@testable import Atrium

/// The orbit is a circle with two rates, set going from one real fix of the ISS. Ten minutes on it should still be
/// where the real station was (a second fix from api.wheretheiss.at, taken 603 s after the first), and an orbit put
/// over a place should be over it.
@Test func orbitKeepsToTheRealStation() {
    var orbit = Orbit(date: Date(timeIntervalSince1970: 1_791_646_998), along: 331.37 * .pi / 180, node: 88.67 * .pi / 180)
    #expect(abs(orbit.under.longitude - 174.845) < 0.1) // the first fix: 22.20 S (a map's latitude), 174.845 E
    orbit.advance(603)
    let later = orbit.under // the second: 8.0816 N, 162.5478 W. `under` is measured from the Earth's centre: 8.03 N
    #expect(abs(later.latitude - 8.03) < 0.1, "at \(later.latitude)")
    #expect(abs(later.longitude + 162.548) < 0.1, "at \(later.longitude)")

    for (latitude, longitude, climbing) in [(33.0, 9.0, false), (-22.2, 174.8, true), (0.0, -150.0, true), (44.9, 100.0, false)] {
        let over = Orbit(date: Date(timeIntervalSince1970: 1_800_000_000), latitude: latitude, longitude: longitude, climbing: climbing)
        #expect(abs(over.under.latitude - latitude) < 0.25 && abs(remainder(over.under.longitude - longitude, 360)) < 0.01)
        var next = over
        next.advance(10)
        #expect((next.under.latitude > over.under.latitude) == climbing)
    }
}

/// An orbit takes about 93 minutes, reaches 51.6 degrees north and south, and comes back round 23 degrees further
/// west, so no two passes look down on the same ground.
@Test func orbitNeverRepeatsItsTrack() {
    var orbit = Orbit(date: Date(timeIntervalSince1970: 1_800_000_000), along: 0, node: 1)
    let start = orbit.under.longitude
    var highest = 0.0, seconds = 0.0
    repeat {
        orbit.advance(10)
        seconds += 10
        highest = max(highest, abs(orbit.under.latitude))
    } while orbit.along < 2 * .pi
    #expect(seconds > 5540 && seconds < 5600, "an orbit took \(seconds) s")
    #expect(highest > 51.4 && highest < 51.7)
    let west = remainder(start - orbit.under.longitude, 360)
    #expect(west > 22 && west < 25, "the track moved \(west) degrees west")
}

/// The baked map has the Earth where it is: sand in the Sahara, deep water in the Pacific, snow on Greenland, and
/// lamps in Paris and Cairo but none in the desert, whose pale sand the night map shows nearly as bright.
@Test func orbitMapKnowsItsPlaces() {
    let map = EarthMap()
    func at(_ latitude: Double, _ longitude: Double) -> (ground: Int, lamp: Int) {
        let byte = map.at(Sky.direction(longitude, latitude))
        return (Int(byte & 31), Int(byte >> 5))
    }
    #expect(at(25, 22).ground == 4 && at(25, 22).lamp == 0) // the Libyan desert: sand
    #expect(at(0, -140).ground == 0) // the Pacific: deep water
    #expect(at(71, -40).ground == 17) // Greenland: snow
    #expect(at(0, 22).ground == 14) // the Congo: forest
    #expect(at(48.86, 2.35).lamp >= 5 && at(30.05, 31.25).lamp >= 5) // Paris and Cairo
    #expect(map.bytes.contains { $0 & 31 > 17 } == false)
}

/// Made-up weather has to leave the ground in sight most of the time, and still be weather: cloud over a fifth
/// to two fifths of the Earth, and along a track few stretches the width of the window under a solid deck.
@MainActor @Test func orbitWeatherLeavesTheGroundInSight() {
    let world = OrbitWorld(map: EarthMap.shared())
    var random = SeededRandom(state: 7), cloudy = 0
    let day = Date(timeIntervalSince1970: 1_800_000_000)
    for _ in 0..<20_000 {
        let p = normalize(Sky.Vector(Double.random(in: -1...1, using: &random), Double.random(in: -1...1, using: &random), Double.random(in: -1...1, using: &random)))
        if world.cloud(p, finest: 2, day: day) > 0.5 { cloudy += 1 }
    }
    #expect(cloudy > 4000 && cloudy < 8000, "cloud over \(cloudy / 200)% of the Earth")
    // Three times round a tilted circle, a sample every 20 km: stretches of 1,500 km, the near ground's width.
    let track = stride(from: 0.0, to: 120_000, by: 20).map { km -> Bool in
        let a = km / Orbit.radius, lift = 0.9 * sin(a * 0.31)
        return world.cloud(Sky.Vector(cos(a) * cos(lift), sin(a) * cos(lift), sin(lift)), finest: 2, day: day) > 0.5
    }
    let stretches = stride(from: 0, to: track.count - 75, by: 25).map { start in track[start..<start + 75].count { $0 } }
    let solid = stretches.count { $0 > 64 }, clear = stretches.count { $0 < 8 }
    print("orbit weather: cloud over \(cloudy / 200)% of the Earth; of \(stretches.count) stretches \(solid) are solid and \(clear) clear")
    #expect(solid * 12 < stretches.count, "\(solid) of \(stretches.count) stretches are under solid cloud")
    #expect(clear * 2 < stretches.count && clear * 12 > stretches.count, "\(clear) of \(stretches.count) stretches are clear")
}

/// Following the real station means flying at its pace: Speed is ignored while Follow is on (and Settings greys
/// its slider out), where it used to stop following without a word unless the slider sat within a hair of 1×.
@MainActor @Test func orbitFollowsAtTheRealSpeed() {
    let keys = [PixelOrbit.on, PixelOrbit.follow, PixelWindowSeat.speed].map(\.key)
    defer { for key in keys { UserDefaults.standard.removeObject(forKey: key) } }
    func flown(follow: Bool) -> Double {
        for (key, value) in zip(keys, [1, follow ? 1 : 0, 10.0]) { UserDefaults.standard.set(value, forKey: key) }
        let scene = pixelWindowSeat(size: CGSize(width: 1512, height: 982)), start = PixelOrbit.orbit.along
        for frame in 0...60 { scene.update(2000 + Double(frame) / 30) }
        return (PixelOrbit.orbit.along - start) / (Orbit.pace * 2) // in two seconds, as a multiple of the real pace
    }
    let (free, following) = (flown(follow: false), flown(follow: true))
    #expect(abs(free - 10) < 0.5, "at 10× it flew \(free)×")
    #expect(abs(following - 1) < 0.05, "following, with Speed left at 10×, it flew \(following)×")
}

/// Every display gets a scene its own size, with a window of any size or none, looking any of its five ways: each
/// must build, fly on and paint. (On the tiny one the Cupola's dome is a few pixels across. Window does nothing from
/// the Cupola, so its two views are built for one.)
@MainActor @Test func orbitFliesAtAnySize() {
    UserDefaults.standard.set(1.0, forKey: PixelOrbit.on.key)
    defer { for knob in [PixelOrbit.on, PixelOrbit.looking, PixelWindowSeat.window] { UserDefaults.standard.removeObject(forKey: knob.key) } }
    for looking in 0...4 {
        UserDefaults.standard.set(Double(looking), forKey: PixelOrbit.looking.key)
        for window in looking < 3 ? [2, 3] : [3] {
            UserDefaults.standard.set(Double(window), forKey: PixelWindowSeat.window.key)
            for size in [CGSize(width: 1512, height: 982), CGSize(width: 1080, height: 1920), CGSize(width: 3440, height: 1440), CGSize(width: 40, height: 30)] {
                let scene = pixelWindowSeat(size: size), start = PixelOrbit.orbit.along
                #expect(scene is PixelOrbit)
                for frame in 0...60 { scene.update(1000 + Double(frame) / 30) }
                #expect(PixelOrbit.orbit.along - start > 0.002, "after two seconds at \(size) it has gone \(PixelOrbit.orbit.along - start) round")
            }
        }
    }
}

/// The ground is laid by a pixel's ray and the stars are put by a direction's pixel, so the two must agree: each
/// pixel's own ray falls back in it, through either lens, and the fisheye places what lies behind the camera.
@Test func orbitLensComesBackToItsPixel() {
    for lens in [OrbitLens(focal: 589, fisheye: false, w: 756, h: 491), OrbitLens(focal: 250, fisheye: false, w: 61, h: 41),
                 OrbitLens(focal: 491 / .pi, fisheye: true, w: 756, h: 491), OrbitLens(focal: 20, fisheye: true, w: 61, h: 41)] {
        var missed = 0
        for y in 0..<lens.h {
            for x in 0..<lens.w {
                let back = lens.spot(normalize(lens.ray(x, y)))
                if back?.x != x || back?.y != y { missed += 1 }
            }
        }
        #expect(missed == 0, "\(missed) pixels of a \(lens.fisheye ? "fisheye" : "rectilinear") lens \(lens.w) wide")
    }
    let behind = OrbitLens(focal: 491 / .pi, fisheye: true, w: 756, h: 491).spot(normalize([1, 0, -1])) // 135° off the axis, to the right
    #expect(behind?.x == 378 + 368 && behind?.y == 245)
}

/// The Cupola's dome on a laptop's canvas, from Tranquility and from within: seven separate windows of sky, the
/// round one in the middle and as wide as the mock-ups Dave picked (82 and 90 pixels of sky), each inside a copper
/// line that nothing painted later has broken.
@Test func cupolaHasSevenWindows() {
    let (w, h) = (378, 246)
    for (within, across) in [(false, 82), (true, 90)] {
        let dome = PixelCupola(w: w, h: h, within: within)
        var day = [UInt32?](repeating: nil, count: w * h)
        for spot in dome.inside { day[spot.at] = spot.day }
        #expect(dome.sky.indices.allSatisfy { dome.sky[$0] == (day[$0] == nil) }, "every pixel is sky or the dome's, not both")
        // Each stretch of sky, and how far the room spreads from it without crossing a copper pixel.
        var window = [Int](repeating: -1, count: w * h), room = window, windows: [[Int]] = []
        func spread(from start: Int, into found: inout [Int], as mark: Int, over open: (Int) -> Bool) -> [Int] {
            var reached = [start], next = 0
            found[start] = mark
            while next < reached.count {
                let i = reached[next]
                next += 1
                for j in [i - 1, i + 1, i - w, i + w] where j >= 0 && j < w * h && abs(j % w - i % w) <= 1 && found[j] < 0 && open(j) {
                    found[j] = mark
                    reached.append(j)
                }
            }
            return reached
        }
        for i in 0..<w * h where dome.sky[i] && window[i] < 0 { windows.append(spread(from: i, into: &window, as: windows.count) { dome.sky[$0] }) }
        #expect(windows.count == 7, "\(windows.count) windows \(within ? "from within" : "from Tranquility")")
        let copper: UInt32 = 0xFF34_51A2 // #a25134, as the picture packs it
        for (k, sky) in windows.enumerated() {
            let reached = spread(from: sky[0], into: &room, as: k) { day[$0] != copper }
            #expect(reached.count < sky.count * 3, "the copper line round window \(k) is broken: the room spreads to \(reached.count) pixels")
        }
        // The round window is the one over the canvas's centre.
        let round = window[h / 2 * w + w / 2]
        let row = (0..<w).filter { window[h / 2 * w + $0] == round }, column = (0..<h).filter { window[$0 * w + w / 2] == round }
        #expect(round >= 0 && row.count == across, "the round window is \(row.count) pixels of sky across")
        #expect(row.first! + row.last! == w - 1 && column.first! + column.last! == h - 1, "the round window is centred")
    }
}
