import AppKit
import SpriteKit

/// Today's clouds over the whole Earth, from Live Cloud Maps (clouds.matteason.co.uk: CC0, contains modified EUMETSAT
/// data): an equirectangular greyscale map, redrawn there every three hours from satellite images. The last map is
/// cached on disk, so clouds show at launch and offline.
@MainActor final class Clouds {
    static let shared = Clouds()

    private let url = URL(string: "https://clouds.matteason.co.uk/images/4096x2048/clouds.jpg")!
    private let file = URL.cachesDirectory.appending(path: "com.dtanquary.atrium/clouds.jpg")
    private var lastPoll = Date.distantPast

    /// The latest map, shared by every display; nil before the first download.
    private(set) var texture: SKTexture?
    /// Goes up each time a new map lands, so scenes know to fade to it.
    private(set) var version = 0

    private init() {
        if let image = NSImage(contentsOf: file) { show(image) }
    }

    /// Checks for a new map, at most every 25 minutes however many displays ask. The ETag makes an unchanged map
    /// a tiny 304 reply rather than another 1.5 MB download.
    func poll() {
        guard Date().timeIntervalSince(lastPoll) > 25 * 60 else { return }
        lastPoll = Date()
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        if texture != nil, let tag = UserDefaults.standard.string(forKey: "clouds.etag") {
            request.setValue(tag, forHTTPHeaderField: "If-None-Match")
        }
        Task {
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let image = NSImage(data: data) else { return }
            try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: file)
            UserDefaults.standard.set(http.value(forHTTPHeaderField: "ETag"), forKey: "clouds.etag")
            show(image)
        }
    }

    private func show(_ image: NSImage) {
        let map = SKTexture(image: image)
        map.usesMipmaps = true
        texture = map
        version += 1
    }
}
