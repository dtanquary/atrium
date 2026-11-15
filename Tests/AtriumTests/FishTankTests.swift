import SpriteKit
import Testing
@testable import Atrium

/// A blurred cut-out comes with a clear margin, and its blur fades out inside it: cropped to the photo's own box, the
/// blur was cut off there, and the back cluster's base stood on the sand in a razor-straight line.
@MainActor @Test func blurredCutOutFadesInsideItsMargin() throws {
    let plain = try #require(TankArt.photo("reef-rock-4", width: 200))
    let soft = try #require(TankArt.photo("reef-rock-4", width: 200, blur: 2))
    #expect(soft.size.width == plain.size.width + 2 * TankArt.margin(blur: 2))
    let image = try #require(soft.texture.cgImage())
    let (w, h) = (image.width, image.height)
    var alpha = [UInt8](repeating: 0, count: w * h)
    let ctx = try #require(CGContext(data: &alpha, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                     space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue))
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    let edge = (0..<w).flatMap { [alpha[$0], alpha[(h - 1) * w + $0]] } + (0..<h).flatMap { [alpha[$0 * w], alpha[$0 * w + w - 1]] }
    #expect(edge.max()! < 8) // the rock stands on its photo's bottom edge, solid there unless the blur has room
}

/// The caustics are light gathered into filaments: most of the floor is dimmer than the mean and a few texels many
/// times brighter. Rays bent too little would light it evenly, and too much would scatter it into noise.
@Test func causticLightGathersIntoFilaments() {
    let clock = ContinuousClock(), began = clock.now
    let light = TankArt.causticLight(512), took = clock.now - began
    let sorted = light.sorted(), mean = light.reduce(0, +) / Float(light.count)
    print("caustics baked in \(took)")
    #expect(abs(mean - 1) < 0.001)
    #expect(sorted[light.count / 2] < 0.8)       // the median: most of the floor is in the cells between filaments
    #expect(sorted[light.count * 99 / 100] > 4)  // the filaments' bright cores
}
