import Metal
import SpriteKit
import Testing
import UniformTypeIdentifiers
@testable import Atrium

/// For judging a wallpaper's `batteryScale`: renders each named wallpaper (which must be `Trimmable`) at full
/// resolution and at each trim, the same scene at the same moment, into `TRIM_SHOTS/<scene>/`: `full-<scale>.png`,
/// crops of its busiest 768 × 512 pixels (`TRIM_CROP=x,y` picks another), `crop-<scale>.png`, and of its brightest,
/// `subject-<scale>.png`; then a strip of frames 1/15 s apart, `strip-<scale>-<frame>.png`.
///
///     TRIM_SHOTS=/some/dir TRIM_SCENES="Nebula,Galaxy" swift test --filter trimShots
///     TRIM_SCALES="1,0.75,0.5" TRIM_STRIP=45 …   # the scales, and 3 s of strip
///     TRIM_DEFAULTS="sky.previewTime=1,sky.previewHour=22" TRIM_DIR=night …   # with Settings values, into <scene>-night/
///     TRIM_BENCH=8 …   # and the GPU's work at each scale (bench.txt)
@MainActor @Test(.enabled(if: ProcessInfo.processInfo.environment["TRIM_SHOTS"] != nil))
func trimShots() throws {
    let env = ProcessInfo.processInfo.environment
    let root = URL(fileURLWithPath: env["TRIM_SHOTS"]!)
    let names = (env["TRIM_SCENES"] ?? "Nebula").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    let scales = (env["TRIM_SCALES"] ?? "1,0.75,0.5").split(separator: ",").compactMap { Double($0) }
    let seconds = Double(env["TRIM_SECONDS"] ?? "") ?? 4
    let stripFrames = Int(env["TRIM_STRIP"] ?? "") ?? 6
    let settings = (env["TRIM_DEFAULTS"] ?? "").split(separator: ",").map { $0.split(separator: "=") }
    for pair in settings where pair.count == 2 {
        UserDefaults.standard.set(Double(pair[1]).map { $0 as Any } ?? String(pair[1]), forKey: String(pair[0]))
    }
    defer { for pair in settings { UserDefaults.standard.removeObject(forKey: String(pair[0])) } }

    let device = try #require(MTLCreateSystemDefaultDevice())
    let queue = try #require(device.makeCommandQueue())
    let size = CGSize(width: 1512, height: 982)
    let (w, h) = (Int(size.width) * 2, Int(size.height) * 2)
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared
    let texture = try #require(device.makeTexture(descriptor: descriptor))
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = texture
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store

    for name in names {
        let wallpaper = try #require(allScenes.first { $0.name == name }, "no wallpaper named \(name)")
        let dir = root.appendingPathComponent(name.lowercased().replacingOccurrences(of: " ", with: "-") + (env["TRIM_DIR"].map { "-" + $0 } ?? ""))
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let scene = wallpaper.make(size)
        let trim = try #require((scene as? Trimmable)?.trim, "\(name) has no trim")
        let renderer = SKRenderer(device: device)
        renderer.scene = scene
        let clock = ProcessInfo.processInfo.systemUptime + 1
        WallpaperTime.restart()
        func step(to frame: Int) {
            WallpaperTime.set(clock + Double(frame) / 30)
            renderer.update(atTime: clock + Double(frame) / 30)
        }
        func render() throws -> (pixels: [UInt32], gpu: Double) {
            let buffer = try #require(queue.makeCommandBuffer())
            renderer.render(withViewport: CGRect(x: 0, y: 0, width: w, height: h), commandBuffer: buffer, renderPassDescriptor: pass)
            buffer.commit()
            buffer.waitUntilCompleted()
            var pixels = [UInt32](repeating: 0, count: w * h)
            texture.getBytes(&pixels, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
            return (pixels, buffer.gpuEndTime - buffer.gpuStartTime)
        }
        let last = Int(seconds * 30)
        for frame in 0...last { step(to: frame) }

        var crop: (x: Int, y: Int)?, subject: (x: Int, y: Int)?
        if let pick = env["TRIM_CROP"]?.split(separator: ",").compactMap({ Int($0) }), pick.count == 2 { crop = (pick[0], pick[1]) }
        for scale in scales {
            trim.scale = scale
            let (pixels, _) = try render()
            save(pixels, w, h, CGRect(x: 0, y: 0, width: w, height: h), to: dir.appendingPathComponent("full-\(scale).png"))
            if crop == nil { crop = busiest(pixels, w, h) }
            if subject == nil { subject = busiest(pixels, w, h, brightest: true) }
            save(pixels, w, h, CGRect(x: crop!.x, y: crop!.y, width: 768, height: 512), to: dir.appendingPathComponent("crop-\(scale).png"))
            save(pixels, w, h, CGRect(x: subject!.x, y: subject!.y, width: 768, height: 512), to: dir.appendingPathComponent("subject-\(scale).png"))
        }
        if let rounds = Int(env["TRIM_BENCH"] ?? "") {
            // The median of frames drawn back to back, rounds of each scale in a fresh random order: busy, the GPU
            // holds a high clock, so its time follows the work. On the desktop its clock drops with the load, and its
            // time per second (the live cost test's) moved by as much as the trims, either way.
            var times: [Double: [Double]] = [:]
            for _ in 0..<rounds {
                for scale in scales.shuffled() {
                    trim.scale = scale
                    for frame in 0..<23 {
                        let time = try render().gpu
                        if frame >= 3 { times[scale, default: []].append(time) } // three to warm, then twenty
                    }
                }
            }
            let median = { (scale: Double) in (times[scale] ?? [0]).sorted()[(times[scale]?.count ?? 1) / 2] * 1000 }
            let line = scales.map { String(format: "%g: %.2f ms (%.0f%%)", $0, median($0), median($0) / median(scales[0]) * 100) }.joined(separator: ", ")
            try "\(name)\t\(line)\n".write(to: dir.appendingPathComponent("bench.txt"), atomically: true, encoding: .utf8)
            print("\(name), the GPU's work a frame: \(line)")
        }
        for frame in 0..<stripFrames {
            step(to: last + 2 * frame + 1)
            step(to: last + 2 * frame + 2)
            for scale in scales {
                trim.scale = scale
                save(try render().pixels, w, h, CGRect(x: crop!.x, y: crop!.y, width: 768, height: 512),
                     to: dir.appendingPathComponent("strip-\(scale)-\(frame).png"))
            }
        }
        print("\(name): crops at \(crop!.x),\(crop!.y) and \(subject!.x),\(subject!.y) → \(dir.path)")
    }
}

/// The top-left corner of the 768 × 512 pixels with the most fine detail (summed luminance steps), or the most light,
/// on a 128 px grid.
private func busiest(_ pixels: [UInt32], _ w: Int, _ h: Int, brightest: Bool = false) -> (x: Int, y: Int) {
    func luma(_ p: UInt32) -> Int { Int((p >> 16) & 255) * 3 + Int((p >> 8) & 255) * 6 + Int(p & 255) }
    var best = (x: 0, y: 0), most = -1
    for y in stride(from: 0, through: h - 512, by: 128) {
        for x in stride(from: 0, through: w - 768, by: 128) {
            var detail = 0
            for row in stride(from: y, to: y + 511, by: 2) {
                for column in stride(from: x, to: x + 767, by: 2) {
                    let i = row * w + column
                    detail += brightest ? luma(pixels[i]) : abs(luma(pixels[i + 1]) - luma(pixels[i])) + abs(luma(pixels[i + w]) - luma(pixels[i]))
                }
            }
            if detail > most { (most, best) = (detail, (x, y)) }
        }
    }
    return best
}

private func save(_ pixels: [UInt32], _ w: Int, _ h: Int, _ rect: CGRect, to url: URL) {
    let image = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                        provider: CGDataProvider(data: Data(bytes: pixels, count: w * h * 4) as CFData)!,
                        decode: nil, shouldInterpolate: false, intent: .defaultIntent)!.cropping(to: rect)!
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
}
