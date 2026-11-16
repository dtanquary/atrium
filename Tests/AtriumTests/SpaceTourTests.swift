import Metal
import SpriteKit
import Testing
@testable import Atrium

/// Space Tour's caption, painted with its shadow, sits Margin in from the edges at every Position, and on whole
/// pixels so the painted text stays sharp.
@MainActor @Test func spaceTourCaptionKeepsToItsPlace() throws {
    let defaults = UserDefaults.standard
    defer { ["solar.photo", "solar.captionPlace", "solar.captionMargin", "solar.factsSeen"].forEach(defaults.removeObject) }
    defaults.set("solar-pluto-true.heic", forKey: "solar.photo")
    defaults.set(60.0, forKey: "solar.captionMargin")
    let size = CGSize(width: 1512, height: 982), scene = spaceTour(size: size)
    let caption = try #require(scene.children.first { $0.zPosition == 101 })
    for place in 0..<6 {
        defaults.set(Double(place), forKey: "solar.captionPlace")
        let frame = caption.calculateAccumulatedFrame(), text = frame.insetBy(dx: 40, dy: 40) // the shadow reaches 40 pt out
        let x = [text.minX - 60, text.midX - size.width / 2, size.width - 60 - text.maxX][place % 3]
        let y = place < 3 ? size.height - 60 - text.maxY : text.minY - 60
        #expect(abs(x) <= 1 && abs(y) <= 1, "Position \(place): \(text)")
        #expect((frame.minX * 2).rounded() == frame.minX * 2 && (frame.minY * 2).rounded() == frame.minY * 2)
    }
}

/// Soften bright photos leaves a photo at a mean level of 110 of 255 or less as it is, and dims a brighter one by
/// (110 / mean)^0.7.
@Test func spaceTourSoftensOnlyBrightPhotos() throws {
    func flat(_ level: CGFloat) throws -> CGImage {
        let context = try #require(CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(srgbRed: level / 255, green: level / 255, blue: level / 255, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        return try #require(context.makeImage())
    }
    #expect(PhotoTour.glare(try flat(40)) == 1)
    #expect(PhotoTour.glare(try flat(105)) == 1)
    #expect(abs(PhotoTour.glare(try flat(176)) - pow(110.0 / 176, 0.7)) < 0.01)
}

/// Held on the live Moon, Space Tour asks for 10 fps on battery once the caption has faded in, and hides the photo
/// layer over it; a photo keeps 20 for its pan.
@MainActor @Test func spaceTourRestsOnTheMoon() throws {
    let defaults = UserDefaults.standard
    defer { ["solar.photo", "solar.factsSeen"].forEach(defaults.removeObject) }
    let renderer = SKRenderer(device: try #require(MTLCreateSystemDefaultDevice()))
    for (photo, rate) in [("live-the-moon", 10), ("solar-pluto-true.heic", 20)] {
        defaults.set(photo, forKey: "solar.photo")
        let scene = try #require(spaceTour(size: CGSize(width: 1512, height: 982)) as? PhotoTour)
        #expect(scene.batteryRate == 20) // the caption is still to fade in
        renderer.scene = scene
        let clock = ProcessInfo.processInfo.systemUptime + 1 // after SKRenderer's own first update, as in the render test
        for frame in 0...180 { renderer.update(atTime: clock + Double(frame) / 30) }
        #expect(scene.batteryRate == rate, "\(photo)")
        #expect(scene.children.first { $0.zPosition == 100 }?.isHidden == (rate == 10))
    }
}
