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
