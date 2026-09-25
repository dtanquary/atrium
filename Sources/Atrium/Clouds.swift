import AppKit
import SpriteKit

/// Today's clouds over the whole Earth, from Live Cloud Maps (clouds.matteason.co.uk: CC0, contains modified EUMETSAT
/// data): an equirectangular greyscale map, redrawn there every three hours from satellite images. The last map is
/// cached on disk, so clouds show at once, offline, and when they're switched back on.
@MainActor final class Clouds {
    static let shared = Clouds()

    private let url = URL(string: "https://clouds.matteason.co.uk/images/4096x2048/clouds.jpg")!
    private let file = URL.cachesDirectory.appending(path: "com.dtanquary.atrium/clouds.jpg")
    private var lastCheck = Date.distantPast

    /// The latest map, shared by every display; nil before one loads, or while clouds are off.
    private(set) var texture: SKTexture?
    /// Goes up each time a map loads, so scenes know to fade to it.
    private(set) var version = 0
    /// A small copy of the map for looking up cloud on the CPU, 512×256, top row at 90° N.
    private var small: [UInt8] = []

    /// Shows the cached map, if there is one and none is showing yet.
    func loadCache() {
        guard texture == nil, let image = NSImage(contentsOf: file) else { return }
        show(image)
    }

    /// Checks for a new map, but only once the cached one is over three hours old (the source's own cadence), and
    /// at most hourly however many displays ask; this isn't data worth hurrying. The ETag turns an unchanged map
    /// into a tiny 304 reply, which restarts the three hours.
    func poll() {
        let saved = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
        guard Date().timeIntervalSince(saved) > 3 * 3600, Date().timeIntervalSince(lastCheck) > 3600 else { return }
        lastCheck = Date()
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        if saved != .distantPast, let tag = UserDefaults.standard.string(forKey: "clouds.etag") {
            request.setValue(tag, forHTTPHeaderField: "If-None-Match")
        }
        Task {
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let http = response as? HTTPURLResponse else { return }
            if http.statusCode == 304 {
                try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path)
            }
            guard http.statusCode == 200, let image = NSImage(data: data) else { return }
            try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: file)
            UserDefaults.standard.set(http.value(forHTTPHeaderField: "ETag"), forKey: "clouds.etag")
            if EarthFromOrbit.knobs[1].value > 0.5 { show(image) } // switched off meanwhile: just keep the file
        }
    }

    /// Lets the map go while clouds are switched off; `loadCache()` brings it back.
    func release() {
        texture = nil
        small = []
    }

    /// How cloudy the map is at a place, 0...1; nil without a map.
    func cover(latitude: Double, longitude: Double) -> Double? {
        guard !small.isEmpty else { return nil }
        let x = Int((longitude + 180) / 360 * 512) & 511
        let y = min(max(Int((90 - latitude) / 180 * 256), 0), 255)
        return Double(small[y * 512 + x]) / 255
    }

    private func show(_ image: NSImage) {
        let map = SKTexture(image: image)
        map.usesMipmaps = true
        texture = map
        version += 1
        if let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
           let context = CGContext(data: nil, width: 512, height: 256, bitsPerComponent: 8, bytesPerRow: 512,
                                   space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) {
            context.draw(cg, in: CGRect(x: 0, y: 0, width: 512, height: 256))
            small = Array(UnsafeBufferPointer(start: context.data!.assumingMemoryBound(to: UInt8.self), count: 512 * 256))
        }
    }
}
