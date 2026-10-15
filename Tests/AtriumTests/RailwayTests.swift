import Foundation
import ImageIO
import simd
import Testing
import UniformTypeIdentifiers
@testable import RailLayout

/// Snow lying in mid-January.
private let snowy = RailSeason(day: 15, breaks: 115, full: 144, onset: 278, peak: 301, bare: 318, green: 0, snow: true)

/// Writes a railway's picture, enlarged `scale` times, to $TMPDIR/atrium-railway/`name`.png.
private func save(_ railway: Railway, night: Float, _ name: String, scale: Int = 3) throws {
    let (w, h) = (railway.w, railway.h)
    var px = [UInt32](repeating: 0, count: w * h)
    px.withUnsafeMutableBufferPointer { railway.draw(night: night, into: $0) }
    var big = [UInt32](repeating: 0, count: w * h * scale * scale)
    for y in 0..<(h * scale) { for x in 0..<(w * scale) { big[y * w * scale + x] = px[(h - 1 - y / scale) * w + x / scale] } } // rows from the bottom
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("atrium-railway")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let data = big.withUnsafeBytes { Data($0) }
    let image = CGImage(width: w * scale, height: h * scale, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * scale * 4,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                        provider: CGDataProvider(data: data as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    let out = CGImageDestinationCreateWithURL(dir.appendingPathComponent("\(name).png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(out, image, nil)
    CGImageDestinationFinalize(out)
}

/// A layout on Dave's laptop (378 by 246 art pixels), in each view and era, by day, at night and in snow, written
/// out to look at; how long each takes to build; and the trains still moving after ten minutes.
@Test func railwayDrawsALayout() throws {
    let seed = Int(ProcessInfo.processInfo.environment["RAILWAY_SEED"] ?? "6")!
    for kind in [RailViewKind.topDown, .iso] {
        for era in RailEra.allCases {
            for winter in [false, true] {
                let clock = ContinuousClock(), began = clock.now
                let railway = Railway(seed: seed, width: 378, height: 246, view: kind, era: era, count: 3, season: winter ? snowy : .summer)
                let took = clock.now - began
                let name = "\(kind == .iso ? "iso" : "tq")-\(era == .steam ? "steam" : "streamliners")\(winter ? "-snow" : "")"
                print("Pixel Railway \(name), seed \(seed): built in \(took); \(railway.names.joined(separator: ", "))")
                railway.advance(8)
                try save(railway, night: 0, name)
                if !winter { try save(railway, night: 1, name + "-night") }
            }
        }
    }
}

/// One layout through the year at 42°N, to look at: autumn's peak and a bare winter without snow.
@Test func railwayFollowsTheSeasons() throws {
    let seed = Int(ProcessInfo.processInfo.environment["RAILWAY_SEED"] ?? "6")!
    for (name, day, green) in [("autumn", 301.0, 1.0), ("bare", 15, 0)] {
        let season = RailSeason(day: day, breaks: 115, full: 144, onset: 278, peak: 301, bare: 318, green: green, snow: false)
        let railway = Railway(seed: seed, width: 378, height: 246, view: .topDown, era: .streamliners, count: 3, season: season)
        railway.advance(8)
        try save(railway, night: 0, "tq-streamliners-\(name)")
    }
}

/// With its retries a top-down layout nearly always fits three trains and a station, and the trains never lock:
/// over ten simulated minutes, never all standing (but at a platform) for 10 s, and none held at a signal for 2
/// minutes. Prints how often each view and era fits everything, and how long a railway takes to build.
@Test func railwayFitsItsTrainsAndNeverLocks() throws {
    for kind in [RailViewKind.topDown, .iso] {
        for era in RailEra.allCases {
            var (all, stations, longest, took) = (0, 0, 0.0, Duration.zero)
            let clock = ContinuousClock()
            for seed in 1...20 {
                let began = clock.now
                let railway = Railway(seed: seed, width: 378, height: 246, view: kind, era: era, count: 3, season: .summer)
                took += clock.now - began
                if railway.layout.trains.count == 3 { all += 1 }
                if railway.scenery.station != nil { stations += 1 }
                var sim = railway.sim, still = 0.0
                for _ in 0..<(600 * 60) {
                    sim.step()
                    still = sim.trains.allSatisfy { $0.v < 0.05 && $0.dwell <= 0 } ? still + Sim.dt : 0
                    #expect(still < 10, "\(kind) \(era) seed \(seed): every train standing at \(sim.t) s")
                    longest = max(longest, sim.trains.map(\.stopped).max()!)
                    if still >= 10 { break }
                }
                #expect(longest < 120, "\(kind) \(era) seed \(seed): a train held \(longest) s")
            }
            print("Pixel Railway \(kind) \(era): 3 trains on \(all)/20, a station on \(stations)/20, longest hold \(Int(longest)) s, built in \(took / 20) each")
            if kind == .topDown { #expect(all >= 16 && stations >= 16) }
        }
    }
}

/// Cars with one-voxel stripes and window rows at every other heading, drawn with one ray a pixel and with four,
/// enlarged, to $TMPDIR/atrium-railway/stripes.png: the four-ray rows should keep their stripes unbroken.
@Test func railwayStripesHold() throws {
    let cars = [RailArt.upCoach, RailArt.gnCoachCar, RailArt.upE9, RailArt.mwCar]
    let (cell, scale) = (44, 4), headings = Array(stride(from: 0, to: 32, by: 1))
    let (w, h) = (cell * headings.count, cell * cars.count * 4)
    var px = [UInt32](repeating: 0xFF3A_9A5E, count: w * h)
    for (vi, kind) in [RailViewKind.topDown, .iso].enumerated() {
        let view = RailView(kind: kind, w: cell, h: cell)
        for (ci, car) in cars.enumerated() {
            for (fi, fine) in [false, true].enumerated() {
                for (k, q) in headings.enumerated() {
                    let m = Marched(car.grid, view, heading: Double(q) * 2 * .pi / 64, fine: fine), p = Painted(m, view, era: .streamliners)
                    let ox = k * cell + cell / 2, oy = ((vi * cars.count + ci) * 2 + fi) * cell + cell / 2
                    var depth = [Float](repeating: -1e9, count: cell * cell)
                    for i in 0..<p.count {
                        let (x, y) = (Int(p.dx[i]) + cell / 2, Int(p.dy[i]) + cell / 2)
                        guard x >= 0, x < cell, y >= 0, y < cell, p.dd[i] >= depth[y * cell + x] else { continue }
                        depth[y * cell + x] = p.dd[i]
                        px[(oy - cell / 2 + y) * w + ox - cell / 2 + x] = p.day[i]
                    }
                }
            }
        }
    }
    var big = [UInt32](repeating: 0, count: w * h * scale * scale)
    for y in 0..<(h * scale) { for x in 0..<(w * scale) { big[y * w * scale + x] = px[(y / scale) * w + x / scale] } }
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("atrium-railway")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let image = CGImage(width: w * scale, height: h * scale, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * scale * 4,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                        provider: CGDataProvider(data: big.withUnsafeBytes { Data($0) } as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    let out = CGImageDestinationCreateWithURL(dir.appendingPathComponent("stripes.png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(out, image, nil)
    CGImageDestinationFinalize(out)
}

/// For choosing between the views: three layouts in each, side by side, one sheet per era, to
/// $TMPDIR/atrium-railway/compare-<era>.png (top-down on the left, isometric on the right, a layout to a row).
/// Each view grows its own layout from the same seed, so a row is two different railways.
@Test func railwayComparesTheViews() throws {
    guard ProcessInfo.processInfo.environment["RAILWAY_COMPARE"] != nil else { return }
    let (w, h, scale, gap) = (378, 246, 2, 24), seeds = [101, 202, 303]
    for era in RailEra.allCases {
        let (W, H) = (2 * w * scale + 3 * gap, seeds.count * h * scale + (seeds.count + 1) * gap)
        var sheet = [UInt32](repeating: 0xFFF1_F4F6, count: W * H)
        for (row, seed) in seeds.enumerated() {
            for (col, kind) in [RailViewKind.topDown, .iso].enumerated() {
                let railway = Railway(seed: seed, width: w, height: h, view: kind, era: era, count: 3, season: .summer)
                railway.advance(20)
                var px = [UInt32](repeating: 0, count: w * h)
                px.withUnsafeMutableBufferPointer { railway.draw(night: 0, into: $0) }
                let (ox, oy) = (gap + col * (w * scale + gap), gap + row * (h * scale + gap))
                for y in 0..<(h * scale) { for x in 0..<(w * scale) { sheet[(oy + y) * W + ox + x] = px[(h - 1 - y / scale) * w + x / scale] } }
            }
        }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("atrium-railway")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let image = CGImage(width: W, height: H, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: W * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                            provider: CGDataProvider(data: sheet.withUnsafeBytes { Data($0) } as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let out = CGImageDestinationCreateWithURL(dir.appendingPathComponent("compare-\(era).png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(out, image, nil)
        CGImageDestinationFinalize(out)
    }
}
