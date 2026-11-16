import CoreGraphics
import CoreLocation
import Foundation
import Testing
@testable import Atrium

/// A many-point Open-Meteo reply, shaped like a real one (an array in the order asked, each with its hourly wind),
/// becomes a forecast: directions the wind comes from turn into east and north components, and the grid's centre
/// is found, which is where the map is drawn.
@MainActor @Test func parsesWindGrid() throws {
    let here = CLLocationCoordinate2D(latitude: 42, longitude: -88)
    let points = WindField.points(around: here, zoom: 1)
    #expect(points.count == WindField.grid(1).cols * WindField.grid(1).rows)
    #expect(points[0].latitude < here.latitude && points[0].longitude < here.longitude) // south-west first
    #expect(points[WindField.grid(1).cols - 1].longitude > here.longitude) // then east along the row

    // a west wind of 10 m/s this hour, and a south wind of 10 m/s the next
    let reply = "[" + points.map { point in
        #"{"latitude":\#(point.latitude),"longitude":\#(point.longitude),"hourly":{"time":[1000,4600],"wind_speed_10m":[10,10],"wind_direction_10m":[270,180]}}"#
    }.joined(separator: ",") + "]"
    let forecast = try #require(WindField.forecast(from: Data(reply.utf8), zoom: 1))
    #expect(abs(forecast.centre.latitude - 42) < 0.01 && abs(forecast.centre.longitude + 88) < 0.01)
    #expect(abs(forecast.u[0][0] - 10) < 0.01 && abs(forecast.v[0][0]) < 0.01) // blowing toward the east
    #expect(abs(forecast.u[1][0]) < 0.01 && abs(forecast.v[1][0] - 10) < 0.01) // blowing toward the north
    #expect(WindField.forecast(from: Data("[]".utf8), zoom: 1) == nil)
}

/// The Earth background asks GIBS for tiles at about a pixel a point: Blue Marble at level 5 for half the continent and
/// 7 (its finest) for the region; for a town, Landsat at level 10 over Blue Marble, since Blue Marble runs out of detail.
@MainActor @Test func earthTileLevels() {
    let here = CLLocationCoordinate2D(latitude: 42, longitude: -88), size = CGSize(width: 1512, height: 982)
    let levels = { (km: Double) in Set(WindMap(centre: here, kmAcross: km, size: size).earthTiles(Imagery.layers(2)).map(\.level)) }
    #expect(levels(3500) == [5])
    #expect(levels(800) == [7])
    #expect(levels(100) == [7, 10])
    // yesterday's satellite goes over Blue Marble at every zoom, at its finest (8) in a town
    let satellite = { (km: Double) in Set(WindMap(centre: here, kmAcross: km, size: size).earthTiles(Imagery.layers(5)).map(\.level)) }
    #expect(satellite(3500) == [5] && satellite(100) == [7, 8])
    let town = WindMap(centre: here, kmAcross: 100, size: size).earthTiles(Imagery.layers(2))
    #expect(town.filter(\.base).count == 2 && town.count == 20) // 42° N falls on a Blue Marble tile edge: 2 of them, 18 of Landsat's
    // the tile over the centre: 288/2^7 = 2.25° tiles from 180° W and 90° N
    #expect(town.contains { $0.remote.path.hasSuffix("BlueMarble_NextGeneration/default/500m/7/21/40.jpeg") })
}

/// The day map's sharpening brings out an edge and leaves broad areas, and the image's size, as they were.
@Test func windMapSharpensEdgesNotLevels() throws {
    let (w, h) = (64, 32)
    var grey = [UInt8](repeating: 51, count: w * h) // 0.2 on the left, 0.3 on the right
    for y in 0..<h { for x in w / 2..<w { grey[y * w + x] = 77 } }
    let context = try #require(CGContext(data: &grey, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                         space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue))
    let image = try #require(context.makeImage())
    let sharp = try #require(WindMap.sharpened(image))
    #expect(sharp.width == w && sharp.height == h)
    var out = [UInt8](repeating: 0, count: w * h)
    let reader = try #require(CGContext(data: &out, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                        space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue))
    reader.draw(sharp, in: CGRect(x: 0, y: 0, width: w, height: h))
    let row = Array(out[(h / 2) * w..<(h / 2 + 1) * w])
    #expect(row[w / 2 - 1] < 46 && row[w / 2] > 82) // darker and lighter either side of the edge
    #expect(abs(Int(row[1]) - 51) <= 2 && abs(Int(row[w - 2]) - 77) <= 2) // far from it, the levels are kept
}
