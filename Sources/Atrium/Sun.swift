import SpriteKit

@MainActor func theSun(size: CGSize) -> SKScene { TheSun(size: size) }

/// The real Sun as NASA's Solar Dynamics Observatory saw it within the last hour or so, in one wavelength: a corona
/// of gold loops in 171 Å, the red chromosphere in 304, sunspots in visible light. Today's flares and sunspots show
/// up the day they happen. Motion is either a slow shimmer in the corona over the latest image, or a looping
/// time-lapse of the last three hours of real images, crossfaded; Settings switches between them, and between the
/// whole Sun and a close-up off one edge. Every image is turned to where the Sun has rotated by now, so the loop comes
/// round with nothing jumping.
final class TheSun: SKScene {
    /// The channels, each in the colours SDO publishes it in (SolarSoft's `aia_lct` tables, which Helioviewer applies).
    /// `source` is Helioviewer's source id. Swatches are the table at 25, 50 and 85%; visible light's are NASA's
    /// orange, from sunspot to limb to centre.
    nonisolated static let wavelengths: [(name: String, source: Int, swatch: [SIMD3<Float>])] = [
        ("171 Gold", 10, [[0.36, 0.25, 0.0], [0.73, 0.50, 0.0], [1.0, 0.85, 0.41]]),    // Fe IX, 0.6 MK: the quiet corona's loops
        ("193 Bronze", 11, [[0.50, 0.25, 0.06], [0.71, 0.50, 0.25], [0.92, 0.85, 0.73]]), // Fe XII, 1.2 MK: corona, dark coronal holes
        ("211 Purple", 12, [[0.50, 0.25, 0.36], [0.71, 0.50, 0.56], [0.92, 0.85, 0.85]]), // Fe XIV, 2 MK: active regions
        ("304 Red", 13, [[0.36, 0.0, 0.0], [0.73, 0.06, 0.0], [1.0, 0.72, 0.41]]),       // He II, 50,000 K: chromosphere, prominences
        ("131 Teal", 9, [[0.0, 0.36, 0.36], [0.06, 0.73, 0.73], [0.72, 1.0, 1.0]]),      // Fe XX, 10 MK: flares
        ("94 Green", 8, [[0.06, 0.36, 0.25], [0.25, 0.56, 0.50], [0.73, 0.85, 0.85]]),   // Fe XVIII, 6 MK: flares
        ("335 Blue", 14, [[0.06, 0.25, 0.50], [0.25, 0.50, 0.71], [0.73, 0.85, 0.92]]),  // Fe XVI, 2.5 MK: active regions
        ("Visible", 18, [[0.62, 0.08, 0.0], [0.91, 0.31, 0.01], [1.0, 0.69, 0.11]]),     // HMI continuum: the surface and sunspots
    ]
    nonisolated static let knobs = [
        Knob(key: "sun.motion", label: "Motion", range: 0...1, standard: 0, section: "View",
             format: .choice(["Shimmer over the latest image", "Time-lapse of the last 3 hours"])),
        Knob(key: "sun.framing", label: "Framing", range: 0...1, standard: 0, section: "View", format: .choice(["Whole Sun", "Close-up"])),
        // not `shownWhen: "sun.motion"`: KnobRow counts an unset gate as on, so it would show for Shimmer too
        Knob(key: "sun.speed", label: "Time-lapse speed", range: 0.25...8, standard: 1, section: "View", format: .times),
    ] + gradeKnobs("sun")

    private let wavelength = TheSun.wavelengths.first { $0.name == UserDefaults.standard.string(forKey: "sun.wavelength") }
        ?? TheSun.wavelengths.randomElement()!
    // The frame showing and the one it's fading to (by `u_fade`), each cropped to what the framing shows: `u_crop`
    // and `u_cropNext` are the part of SDO's image each holds, as x, y, width and height from 0 to 1.
    private lazy var frameUniform = SKUniform(name: "u_frame", texture: placeholder())
    private lazy var nextUniform = SKUniform(name: "u_next", texture: frameUniform.textureValue)
    private let cropUniform = SKUniform(name: "u_crop", vectorFloat4: [0, 0, 1, 1])
    private let cropNextUniform = SKUniform(name: "u_cropNext", vectorFloat4: [0, 0, 1, 1])
    private let fadeUniform = SKUniform(name: "u_fade", float: 0)
    private let discUniform = SKUniform(name: "u_disc", vectorFloat3: .zero)
    // Hours of the Sun's rotation to turn each frame by, to bring it to now, and the tilt of its axis toward us.
    private let ageUniform = SKUniform(name: "u_age", float: 0)
    private let ageNextUniform = SKUniform(name: "u_ageNext", float: 0)
    private let tiltUniform = SKUniform(name: "u_tilt", float: sunTilt(at: Date()))
    private let knobUniforms = TheSun.knobs.map { ($0, SKUniform(name: "u_" + $0.key.split(separator: ".").last!, float: Float($0.value))) }
    /// The frame in `u_frame` and the framing it's cropped for; whether a change is loading or fading; and the frame
    /// in `u_next` once it's loaded, with how far the crossfade to it has got.
    private var showing: URL?
    private var framing = 0
    private var busy = false
    private var next: (url: URL, crop: SIMD4<Float>, framing: Int, seam: Bool)?
    private var progress = 0.0
    private var lastUpdate: TimeInterval?
    /// When the newest cached frame was taken, kept by `advance()` so the frame loop needn't list the cache.
    private var newest = Date()
    private var timeLapse: Bool { Self.knobs[0].value > 0.5 }

    override func sceneDidLoad() {
        backgroundColor = .black
        let sprite = SKSpriteNode(color: .black, size: size)
        sprite.anchorPoint = .zero
        sprite.shader = SKShader(source: shaderCommon + Self.shader, uniforms: [
            SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)]), WallpaperTime.now,
            frameUniform, nextUniform, cropUniform, cropNextUniform, fadeUniform, discUniform, ageUniform, ageNextUniform, tiltUniform,
            SKUniform(name: "u_visible", float: wavelength.source == 18 ? 1 : 0),
        ] + knobUniforms.map(\.1))
        addChild(sprite)
        framing = Int(Self.knobs[1].value)
        discUniform.vectorFloat3Value = disc(framing)
        if let url = frames.last, let image = decode(url, crop(framing)) { // the cache, straight away
            frameUniform.textureValue = texture(image)
            cropUniform.vectorFloat4Value = crop(framing)
            showing = url
            newest = SunImages.date(url)
        }
        turnToNow()
        NotificationCenter.default.addObserver(self, selector: #selector(applyKnobs), name: UserDefaults.didChangeNotification, object: nil)
        run(.repeatForever(.sequence([.wait(forDuration: 1), .run { [weak self] in self?.advance() }])))
    }

    /// Turns both frames to now, and runs the crossfade: over 30 s to a new image, 6 s a step in the time-lapse at 1×
    /// and three steps from now back round to three hours ago, 3 s from the placeholder, and none to a new framing.
    override func update(_ currentTime: TimeInterval) {
        let dt = frameTime(currentTime, &lastUpdate)
        turnToNow()
        guard let next else { return }
        let seconds = next.framing != framing ? 0 : showing == nil ? 3
            : timeLapse ? 6 / Self.knobs[2].value * (next.seam ? 3 : 1) : 30
        progress = seconds > 0 ? min(progress + dt / seconds, 1) : 1
        fadeUniform.floatValue = Float(progress)
        guard progress >= 1 else { return }
        frameUniform.textureValue = nextUniform.textureValue
        cropUniform.vectorFloat4Value = next.crop
        discUniform.vectorFloat3Value = disc(next.framing)
        fadeUniform.floatValue = 0
        showing = next.url
        framing = next.framing
        self.next = nil
        busy = false
        advance() // the time-lapse runs on without a pause
    }

    override func didMove(to view: SKView) {
        run(.repeatForever(.sequence([.run { [weak self] in
            guard let self else { return }
            SunImages.shared.poll(wavelength.source, width: width, history: timeLapse)
        }, .wait(forDuration: 60)])))
    }

    @objc private func applyKnobs() { for (knob, uniform) in knobUniforms { uniform.floatValue = Float(knob.value) } }

    /// The disc's centre and radius in points: the whole Sun, or a close-up rising off the bottom right.
    private func disc(_ framing: Int) -> SIMD3<Float> {
        let (w, h) = (Float(size.width), Float(size.height))
        return framing == 0 ? [w * 0.5, h * 0.5, h * 0.38] : [w * 0.78, h * -0.35, h * 1.05]
    }

    /// The part of SDO's image a framing shows, with a little room for the shimmer, as x, y, width, height from 0 to 1.
    /// The disc's radius is 0.3895 of the image's width.
    private func crop(_ framing: Int) -> SIMD4<Float> {
        let d = disc(framing), pad: Float = 0.03
        let lo = (SIMD2<Float>(-d.x, -d.y) / d.z - pad) * 0.3895 + 0.5
        let hi = (SIMD2<Float>(Float(size.width) - d.x, Float(size.height) - d.y) / d.z + pad) * 0.3895 + 0.5
        let a = simd_clamp(lo, .zero, .one), b = simd_clamp(hi, .zero, .one)
        return [a.x, a.y, b.x - a.x, b.y - a.y]
    }

    /// Images twice the disc's size on screen (at 2x Retina) come in 4096 pixels, else 2048: the whole Sun on a
    /// laptop is 2048, the close-up 4096.
    private var width: Int { disc(Int(Self.knobs[1].value)).z * 2 > 0.3895 * 2048 * 1.15 ? 4096 : 2048 }

    /// The cached frames at the width the framing wants, or at the other width until those arrive.
    private var frames: [URL] {
        let wanted = SunImages.shared.frames(wavelength.source, width: width)
        return wanted.isEmpty ? SunImages.shared.frames(wavelength.source, width: 6144 - width) : wanted
    }

    /// How long ago each frame was taken, for the shader to turn it on by the Sun's rotation since: to now, or if the
    /// images have gone stale (offline, say), to 4 hours after the newest, so none turns far.
    private func turnToNow() {
        let now = min(Date(), newest.addingTimeInterval(4 * 3600))
        ageUniform.floatValue = showing.map { Float(now.timeIntervalSince(SunImages.date($0)) / 3600) } ?? 0
        ageNextUniform.floatValue = next.map { Float(now.timeIntervalSince(SunImages.date($0.url)) / 3600) } ?? 0
    }

    /// Starts the next change once the last is done: to a new framing, to a newer image when one lands, or in the
    /// time-lapse, on to the next frame, and from now back round to the oldest.
    private func advance() {
        let frames = frames, framing = Int(Self.knobs[1].value)
        newest = frames.last.map(SunImages.date) ?? Date()
        guard !busy else { return }
        var target = frames.last, seam = false
        if timeLapse, frames.count > 1 {
            let at = showing.flatMap { frames.firstIndex(of: $0) } ?? frames.count - 1
            seam = at == frames.count - 1
            target = frames[seam ? 0 : at + 1]
        }
        guard let target, target != showing || framing != self.framing else { return }
        busy = true
        let crop = crop(framing)
        Task { [weak self] in
            let image = await Task.detached { decode(target, crop) }.value
            guard let self else { return }
            guard let image else { busy = false; return }
            nextUniform.textureValue = texture(image)
            cropNextUniform.vectorFloat4Value = crop
            progress = 0
            next = (target, crop, framing, seam)
        }
    }

    /// Stands in until the first image arrives: a dim disc in the wavelength's colour, sized like one of SDO's.
    private func placeholder() -> SKTexture {
        let c = wavelength.source == 18 ? SIMD3<Float>(0.4, 0.4, 0.4) : wavelength.swatch[0] // visible light is tinted in the shader
        return paint(CGSize(width: 128, height: 128)) { ctx in
            ctx.setFillColor(CGColor(red: CGFloat(c.x), green: CGFloat(c.y), blue: CGFloat(c.z), alpha: 1))
            ctx.fillEllipse(in: CGRect(x: 64 - 49.9, y: 64 - 49.9, width: 99.8, height: 99.8))
        }
    }

    private func texture(_ image: CGImage) -> SKTexture {
        let texture = SKTexture(cgImage: image)
        texture.usesMipmaps = true // smooth in the small Settings preview
        return texture
    }

    private static let shader = """
    // SDO's visible-light images come in grey; NASA shows them orange, from red sunspots to a golden centre.
    vec3 visibleLight(float v) {
        vec3 c = vec3(0.62, 0.08, 0.0) * smoothstep(0.0, 0.25, v);
        c = mix(c, vec3(0.91, 0.31, 0.01), smoothstep(0.25, 0.47, v));
        c = mix(c, vec3(0.99, 0.57, 0.0), smoothstep(0.47, 0.75, v));
        return mix(c, vec3(1.0, 0.69, 0.11), smoothstep(0.75, 0.86, v));
    }

    // Where a point on the disc (d, in solar radii) was `hours` earlier, before the Sun's rotation carried it west
    // along its latitude: 13.7° a day at the equator, 10° near the poles (synodic, after Snodgrass and Ulrich 1990),
    // about an axis tipped `tilt` radians toward us. A point that was then round the far side keeps its place.
    vec2 turnBack(vec2 d, float hours, float tilt) {
        float z = sqrt(max(1.0 - dot(d, d), 0.0)), ct = cos(tilt), st = sin(tilt);
        vec3 p = vec3(d.x, d.y * ct + z * st, z * ct - d.y * st); // y along the Sun's axis
        float s2 = p.y * p.y; // sin² of the latitude
        float a = (13.72 - 2.39 * s2 - 1.78 * s2 * s2) * 0.01745 / 24.0 * hours, c = cos(a), s = sin(a);
        p = vec3(p.x * c - p.z * s, p.y, p.z * c + p.x * s);
        return p.y * st + p.z * ct < 0.0 ? d : vec2(p.x, p.y * ct - p.z * st);
    }

    void main() {
        vec2 pts = v_tex_coord * u_size;
        vec2 d = (pts - u_disc.xy) / u_disc.z; // in solar radii
        float r = length(d);

        // Shimmer: off the disc, the corona flickers very slowly in fine radial streaks, like streamers, that drift
        // outward about a third of a solar radius a minute, and wavers a little. Two layers, so no noise cells show.
        float s = (1.0 - u_motion) * smoothstep(0.97, 1.1, r);
        vec2 dir = d / max(r, 0.001);
        d *= 1.0 + s * 0.01 * (noise(dir * 5.0 + vec2(3.0, r * 2.0 - u_now * 0.012)) - 0.5);
        float streaks = noise(dir * 18.0 + vec2(0.0, r * 2.5 - u_now * 0.015)) * 0.6
                      + noise(dir * 9.0 + vec2(7.0, r * 1.5 - u_now * 0.01)) * 0.4 - 0.5;

        // The images end 1.28 radii out, so past 1.2 the corona carries on from there, fading as it does in 193
        // (by e every 0.07 radii): streamers smeared radially, which is how they run.
        // Each frame is turned on to now, so the time-lapse shows only what changed, and loops round without a jump.
        vec2 dNow = d * min(1.0, 1.2 / r);
        vec2 uv = 0.5 + (r < 1.0 ? turnBack(d, u_age, u_tilt) : dNow) * 0.3895; // the disc's radius is 0.3895 of the image
        vec2 uvNext = 0.5 + (r < 1.0 ? turnBack(d, u_ageNext, u_tilt) : dNow) * 0.3895;
        vec3 col = mix(texture2D(u_frame, (uv - u_crop.xy) / u_crop.zw).rgb, texture2D(u_next, (uvNext - u_cropNext.xy) / u_cropNext.zw).rgb, u_fade);
        col *= 1.0 + s * 0.35 * streaks;
        if (u_visible > 0.5) { col = visibleLight(dot(col, vec3(0.3333))); }
        col *= exp(-max(r - 1.2, 0.0) * 14.0);

        col = grade(col, 0.3, u_hue, u_saturation, u_contrast, u_brightness);
        col += (hash21(pts * 2.0) - 0.5) / 128.0;
        gl_FragColor = vec4(col, 1.0);
    }
    """
}

/// Decodes the part of an image file given by `crop` (x, y, width, height from 0 to 1, from the bottom left) into a
/// bitmap of its own, off the main thread, so the first frame drawn with it doesn't stall and the rest of a 4096-pixel
/// image isn't kept.
nonisolated func decode(_ url: URL, _ crop: SIMD4<Float>) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
    let (w, h) = (CGFloat(image.width), CGFloat(image.height))
    let rect = CGRect(x: CGFloat(crop.x) * w, y: CGFloat(crop.y) * h, width: CGFloat(crop.z) * w, height: CGFloat(crop.w) * h)
    guard let context = CGContext(data: nil, width: Int(rect.width), height: Int(rect.height), bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { return nil }
    context.draw(image, in: CGRect(x: -rect.minX, y: -rect.minY, width: w, height: h))
    return context.makeImage()
}

/// The Sun's B0 angle in radians: how far its north pole tips toward us, from +7.25° in early September to −7.25° in
/// early March, from the Sun's ecliptic longitude and the node of its equator (Meeus, Astronomical Algorithms, ch. 29).
nonisolated func sunTilt(at date: Date) -> Float {
    let days = date.timeIntervalSince1970 / 86400 - 10957.5, rad = Double.pi / 180 // days since J2000
    let anomaly = (357.528 + 0.9856003 * days) * rad
    let longitude = (280.46 + 0.9856474 * days + 1.915 * sin(anomaly) + 0.02 * sin(2 * anomaly)) * rad
    let node = (75.76 + 1.397 * days / 36525) * rad
    return Float(asin(sin(longitude - node) * sin(7.25 * rad)))
}

/// Full-disc images of the Sun from NASA's Solar Dynamics Observatory, through the ESA/NASA Helioviewer Project's API:
/// 2048 or 4096 pixels square, in SDO's standard colours and without captions. AIA's are about 50 minutes behind real time,
/// HMI's visible light 2–3 hours. SDO's own "latest" JPEGs carry a caption, and since 21 September 2026 a fault in
/// SDO's data storage has frozen them. Frames are cached on disk as `sun/<width>/<source>-<unix time>.jpg`, so the
/// last ones show at once and offline.
@MainActor final class SunImages {
    static let shared = SunImages()

    private let folder = URL.cachesDirectory.appending(path: "com.dtanquary.atrium/sun")
    private let api = "https://api.helioviewer.org/v2/"
    private var lastCheck: [String: Date] = [:]

    /// A channel's cached frames at a width, oldest first.
    func frames(_ source: Int, width: Int) -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: folder.appending(path: "\(width)"), includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("\(source)-") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent } // unix times keep 10 digits until 2286
    }

    /// Fetches a channel's newest frame, at most every 15 minutes however many displays ask (about SDO's own
    /// cadence), or 30 for 4096-pixel images, which run 1–2 MB; with `history`, it also fills in the three hours
    /// before it at 15-minute steps. Images never change
    /// once published, so only frames it doesn't have are downloaded; frames over 3½ hours older than the newest
    /// are deleted. Failures are silent and leave the cache as it was.
    func poll(_ source: Int, width: Int, history: Bool) {
        let key = "\(source) \(width) \(history)"
        guard Date().timeIntervalSince(lastCheck[key] ?? .distantPast) > Double(width) / 2048 * 900 else { return }
        lastCheck[key] = Date()
        Task {
            guard let newest = await closest(source, to: Date()), await download(newest, source, width) else { return }
            for step in 1...12 where history {
                let time = newest.date.addingTimeInterval(-Double(step) * 900)
                guard !frames(source, width: width).contains(where: { abs(Self.date($0).timeIntervalSince(time)) < 450 }) else { continue }
                guard let frame = await closest(source, to: time), await download(frame, source, width) else { return }
            }
            for url in frames(source, width: width) where Self.date(url) < newest.date.addingTimeInterval(-3.5 * 3600) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    /// The frame nearest a time: its id and when it was taken.
    private func closest(_ source: Int, to time: Date) async -> (id: String, date: Date)? {
        guard let url = URL(string: api + "getClosestImage/?date=\(time.ISO8601Format())&sourceId=\(source)"),
              let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return Self.frame(data)
    }

    /// Reads a `getClosestImage` reply: the image's id, and when it was taken from its date in UTC.
    nonisolated static func frame(_ reply: Data) -> (id: String, date: Date)? {
        guard let json = try? JSONSerialization.jsonObject(with: reply) as? [String: Any],
              let id = json["id"] as? String, let stamp = json["date"] as? String, // "2026-09-27 01:08:45"
              let date = try? Date(stamp.replacingOccurrences(of: " ", with: "T") + "Z", strategy: .iso8601) else { return nil }
        return (id, date)
    }

    /// Saves a frame unless it's already cached; false if it couldn't be.
    private func download(_ frame: (id: String, date: Date), _ source: Int, _ width: Int) async -> Bool {
        let file = folder.appending(path: "\(width)/\(source)-\(Int(frame.date.timeIntervalSince1970)).jpg")
        if FileManager.default.fileExists(atPath: file.path) { return true }
        guard let url = URL(string: api + "downloadImage/?id=\(frame.id)&width=\(width)&type=jpg"),
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200, NSImage(data: data) != nil else { return false }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        return (try? data.write(to: file, options: .atomic)) != nil
    }

    /// When a cached frame was taken, from its name.
    nonisolated static func date(_ url: URL) -> Date {
        Date(timeIntervalSince1970: Double(url.deletingPathExtension().lastPathComponent.split(separator: "-").last ?? "") ?? 0)
    }
}
