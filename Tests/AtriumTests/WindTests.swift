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
    #expect(points.count == WindField.cols * WindField.rows)
    #expect(points[0].latitude < here.latitude && points[0].longitude < here.longitude) // south-west first
    #expect(points[WindField.cols - 1].longitude > here.longitude) // then east along the row

    // a west wind of 10 m/s this hour, and a south wind of 10 m/s the next
    let reply = "[" + points.map { point in
        #"{"latitude":\#(point.latitude),"longitude":\#(point.longitude),"hourly":{"time":[1000,4600],"wind_speed_10m":[10,10],"wind_direction_10m":[270,180]}}"#
    }.joined(separator: ",") + "]"
    let forecast = try #require(WindField.forecast(from: Data(reply.utf8)))
    #expect(abs(forecast.centre.latitude - 42) < 0.01 && abs(forecast.centre.longitude + 88) < 0.01)
    #expect(abs(forecast.u[0][0] - 10) < 0.01 && abs(forecast.v[0][0]) < 0.01) // blowing toward the east
    #expect(abs(forecast.u[1][0]) < 0.01 && abs(forecast.v[1][0] - 10) < 0.01) // blowing toward the north
    #expect(WindField.forecast(from: Data("[]".utf8)) == nil)
}
