import Metal
import SpriteKit
import Testing
import UniformTypeIdentifiers
@testable import Atrium

/// A view that isn't drawing (covered, locked, asleep) can't run a crossfade, which would leave the old scene in
/// place for the lock screen's still.
@MainActor @Test func coveredViewSwitchesSceneWithoutFading() {
    let view = WallpaperView(frame: CGRect(x: 0, y: 0, width: 64, height: 64))
    let old = SKScene(size: view.frame.size), new = SKScene(size: view.frame.size)
    view.presentScene(old)
    view.presentScene(new, transition: .crossFade(withDuration: 0.8))
    #expect(view.scene === new)
}

/// Renders every wallpaper offscreen at Retina size, saves a PNG to look at, and prints what a frame costs.
/// Fails if a scene comes out as one flat colour (e.g. a shader that didn't compile).
///
///     swift test                                                  # all scenes → $TMPDIR/atrium-snapshots
///     SNAPSHOT_SCENE="Live Sky" SNAPSHOT_SECONDS=20 swift test   # one scene, further into its animation
///     SNAPSHOT_DEFAULTS="gradient.ribbons=1,gradient.previewTime=1" swift test  # with Settings values
///     SNAPSHOT_APPEARANCE=light swift test                                      # in Light Mode
///     SNAPSHOT_SCENE="Fish Tank" SNAPSHOT_MOVIE=6 swift test    # then 6 s of frames at 15 fps, for a GIF
///     SNAPSHOT_MOVIE_FPS=30 …                                    # or at 30 fps, for the website's video
///
/// Only sceneDidLoad/init content shows up here: SKRenderer never calls didMove(to:).
@MainActor @Test func everySceneRenders() throws {
    let env = ProcessInfo.processInfo.environment
    let dir = URL(fileURLWithPath: env["SNAPSHOT_DIR"] ?? NSTemporaryDirectory() + "atrium-snapshots")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let seconds = Double(env["SNAPSHOT_SECONDS"] ?? "") ?? 4
    if let look = env["SNAPSHOT_APPEARANCE"] { NSApplication.shared.appearance = NSAppearance(named: look == "light" ? .aqua : .darkAqua) }
    let settings = (env["SNAPSHOT_DEFAULTS"] ?? "").split(separator: ",").map { $0.split(separator: "=") }
    for pair in settings where pair.count == 2 {
        UserDefaults.standard.set(Double(pair[1]).map { $0 as Any } ?? String(pair[1]), forKey: String(pair[0])) // numbers or names
    }
    defer { for pair in settings { UserDefaults.standard.removeObject(forKey: String(pair[0])) } }

    let device = try #require(MTLCreateSystemDefaultDevice())
    let queue = try #require(device.makeCommandQueue())
    let size = CGSize(width: 1512, height: 982) // 14" MacBook Pro, in points
    let (w, h) = (Int(size.width) * 2, Int(size.height) * 2)
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead]
    descriptor.storageMode = .shared

    for wallpaper in allScenes where env["SNAPSHOT_SCENE"].map({ $0 == wallpaper.name }) ?? true {
        let name = wallpaper.name
        let renderer = SKRenderer(device: device)
        renderer.scene = wallpaper.make(size)
        let texture = try #require(device.makeTexture(descriptor: descriptor))
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store

        // Run every frame at 30 fps so actions and emitters advance normally; time the last 30.
        // SKRenderer's first update runs on the system clock, so frame times must start after it or every later
        // update counts as the past and update(_:) barely runs.
        let frames = Int(seconds * 30), clock = ProcessInfo.processInfo.systemUptime + 1
        WallpaperTime.restart() // shaders' u_now counts from each scene's first frame, as it would on the desktop
        let movie = Int((Double(env["SNAPSHOT_MOVIE"] ?? "") ?? 0) * 30)
        let every = env["SNAPSHOT_MOVIE_FPS"] == "30" ? 1 : 2 // save every frame, or every other one for 15 fps
        let writes = DispatchGroup()
        var cpu = 0.0, gpu = 0.0
        for frame in 0...frames + movie {
            // Movie frames run in real time, so anything on the wall clock (the time of day) keeps pace with the scene.
            while frame > frames, ProcessInfo.processInfo.systemUptime < clock + Double(frame) / 30 { Thread.sleep(forTimeInterval: 0.002) }
            let start = CFAbsoluteTimeGetCurrent()
            WallpaperTime.set(clock + Double(frame) / 30)
            renderer.update(atTime: clock + Double(frame) / 30)
            let buffer = try #require(queue.makeCommandBuffer())
            renderer.render(withViewport: CGRect(x: 0, y: 0, width: w, height: h), commandBuffer: buffer, renderPassDescriptor: pass)
            buffer.commit()
            buffer.waitUntilCompleted()
            if frame > frames, frame % every == 0 {
                let pixels = read(texture, w, h), url = dir.appendingPathComponent(String(format: "%@-%03d.png", name, (frame - frames) / every))
                DispatchQueue.global().async(group: writes) { save(pixels, w, h, to: url) }
            }
            if frame > frames - 30, frame <= frames {
                let gpuTime = buffer.gpuEndTime - buffer.gpuStartTime
                gpu += gpuTime
                cpu += CFAbsoluteTimeGetCurrent() - start - gpuTime
            }
        }

        writes.wait()
        let pixels = read(texture, w, h)
        let colours = Set(stride(from: 0, to: pixels.count, by: 997).map { pixels[$0] })
        #expect(colours.count > 20, "\(name) rendered as a flat image")

        let url = dir.appendingPathComponent("\(name).png")
        save(pixels, w, h, to: url)

        print(String(format: "%@: cpu≈%.2f ms, gpu %.2f ms per frame → %@", name, cpu / 30 * 1000, gpu / 30 * 1000, url.path))
    }
}

private func read(_ texture: MTLTexture, _ w: Int, _ h: Int) -> [UInt32] {
    var pixels = [UInt32](repeating: 0, count: w * h)
    texture.getBytes(&pixels, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
    return pixels
}

private func save(_ pixels: [UInt32], _ w: Int, _ h: Int, to url: URL) {
    let image = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                        provider: CGDataProvider(data: Data(bytes: pixels, count: w * h * 4) as CFData)!,
                        decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
}

/// Pixel City lays itself out again when Settings picks another city: every one must build, and going back to the
/// first must leave nothing of the others behind.
@MainActor @Test func pixelCitySwitchesCity() {
    defer { UserDefaults.standard.removeObject(forKey: "city.place") }
    let scene = pixelCity(size: CGSize(width: 800, height: 500))
    let nodes = (Array(0...Int(PixelCity.knobs[0].range.upperBound)) + [0]).map { view in
        UserDefaults.standard.set(Double(view), forKey: "city.place") // posts the change the scene listens for
        return scene.children[0].children.count
    }
    #expect(nodes.allSatisfy { $0 > 8 } && nodes.last == nodes.first) // the Spaceport has fewest: its moving things share one node
}

/// Pixel City's automatic move goes to a different city every time and saves it, so Settings and every display
/// follow; in a view, it hands over to a new scene of that city.
@MainActor @Test func pixelCityMovesOn() {
    defer { UserDefaults.standard.removeObject(forKey: "city.place") }
    let view = WallpaperView(frame: CGRect(x: 0, y: 0, width: 400, height: 250))
    view.presentScene(PixelCity(size: view.frame.size))
    for _ in 0..<12 {
        let before = PixelCity.knobs[0].value, scene = view.scene as? PixelCity
        scene?.moveOn()
        #expect(PixelCity.knobs[0].value != before && view.scene !== scene && view.scene is PixelCity)
    }
}

/// With the automatic move on, Pixel City comes back as another city if the wait ran out while it was off the desktop
/// (the app's own Shuffle builds it afresh each time), and as the same one if it didn't.
@MainActor @Test func pixelCityMovesWhileAway() {
    defer { for key in ["city.place", "city.shuffle", "city.movedAt"] { UserDefaults.standard.removeObject(forKey: key) } }
    UserDefaults.standard.set(1.0, forKey: "city.shuffle")
    UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "city.movedAt")
    let before = PixelCity.knobs[0].value
    _ = PixelCity(size: CGSize(width: 400, height: 250))
    #expect(PixelCity.knobs[0].value == before)
    UserDefaults.standard.set(Date().timeIntervalSince1970 - 3600, forKey: "city.movedAt")
    _ = PixelCity(size: CGSize(width: 400, height: 250))
    #expect(PixelCity.knobs[0].value != before)
}

/// Pixel City's Airport keeps its aircraft going round: over twenty minutes of a day's flying there are landings and
/// take-offs, and never two aircraft on the runway at once.
@MainActor @Test func pixelCityAirportKeepsMoving() throws {
    guard case .choice(let cities) = PixelCity.knobs[0].format else { return }
    let settings = ["city.place": Double(try #require(cities.firstIndex(of: "Airport"))), "city.previewTime": 1, "city.previewHour": 12, "city.wind": 0]
    defer { settings.keys.forEach(UserDefaults.standard.removeObject) }
    for (key, value) in settings { UserDefaults.standard.set(value, forKey: key) }
    let scene = PixelCity(size: CGSize(width: 800, height: 500))
    var crowded = false
    for step in 0..<12_000 { // a tenth of a second at a time
        scene.update(Double(step) / 10)
        crowded = crowded || scene.runwayCount > 1
    }
    #expect(scene.movements >= 8 && !crowded, "\(scene.movements) landings and take-offs")
}

/// Pixel City's Spaceport keeps going round: over twenty minutes at twice its usual pace there are lift-offs and
/// landings, and no booster is sent back to a landing zone the last one is still standing on. Its layer is painted
/// every two seconds, not every step: its smoke is slow to paint in a debug build.
@MainActor @Test func pixelCitySpaceportKeepsLaunching() throws {
    guard case .choice(let cities) = PixelCity.knobs[0].format else { return }
    let settings = ["city.place": Double(try #require(cities.firstIndex(of: "Spaceport"))), "city.previewTime": 1, "city.previewHour": 12, "city.launches": 2]
    defer { settings.keys.forEach(UserDefaults.standard.removeObject) }
    for (key, value) in settings { UserDefaults.standard.set(value, forKey: key) }
    let scene = PixelCity(size: CGSize(width: 800, height: 500))
    var shared = false, flown = Set<String>()
    for step in 0..<12_000 { // a tenth of a second at a time
        scene.update(Double(step) / 10)
        if step % 20 == 0 { scene.didFinishUpdate() }
        shared = shared || scene.zoneShared
        flown.insert(scene.rocketName)
    }
    #expect(scene.movements >= 8 && !shared && flown.count >= 4, "\(scene.movements) lift-offs and landings, of \(flown.sorted())")
}

/// The Spaceport flies only the rockets Settings has switched on: with every switch off but one, that one every time.
@MainActor @Test func pixelCitySpaceportFliesTheRocketsPicked() throws {
    guard case .choice(let cities) = PixelCity.knobs[0].format else { return }
    var settings = ["city.place": Double(try #require(cities.firstIndex(of: "Spaceport"))), "city.launches": 3]
    for knob in PixelCity.knobs where knob.key.hasPrefix("city.rocket.") { settings[knob.key] = knob.key == "city.rocket.saturn" ? 1 : 0 }
    defer { settings.keys.forEach(UserDefaults.standard.removeObject) }
    for (key, value) in settings { UserDefaults.standard.set(value, forKey: key) }
    let scene = PixelCity(size: CGSize(width: 800, height: 500))
    var flown = Set<String>()
    for step in 0..<6_000 {
        scene.update(Double(step) / 10)
        flown.insert(scene.rocketName)
    }
    #expect(flown == ["SATURN V"] && scene.movements >= 3, "\(scene.movements) lift-offs, of \(flown.sorted())")
}

/// Starship has a pad of its own at the Spaceport: with only it switched on, it lifts off and its booster comes back
/// to the tower again and again, and nothing else is ever on the pad.
@MainActor @Test func pixelCitySpaceportCatchesStarship() throws {
    guard case .choice(let cities) = PixelCity.knobs[0].format else { return }
    var settings = ["city.place": Double(try #require(cities.firstIndex(of: "Spaceport"))), "city.launches": 3]
    for knob in PixelCity.knobs where knob.key.hasPrefix("city.rocket.") { settings[knob.key] = knob.key == "city.rocket.starship" ? 1 : 0 }
    defer { settings.keys.forEach(UserDefaults.standard.removeObject) }
    for (key, value) in settings { UserDefaults.standard.set(value, forKey: key) }
    let scene = PixelCity(size: CGSize(width: 800, height: 500))
    var flown = Set<String>()
    for step in 0..<7_200 {
        scene.update(Double(step) / 10)
        if step % 20 == 0 { scene.didFinishUpdate() }
        flown.insert(scene.rocketName)
    }
    #expect(flown == ["STARSHIP"] && scene.movements >= 4, "\(scene.movements) lift-offs and catches, of \(flown.sorted())")
}

/// The Shuttle's orbiter comes home to the Spaceport's runway after each of its flights: with only the Shuttle
/// switched on, seven and a half minutes at the Spaceport's busiest see three lift-offs and two landings.
@MainActor @Test func pixelCitySpaceportBringsTheOrbiterHome() throws {
    guard case .choice(let cities) = PixelCity.knobs[0].format else { return }
    var settings = ["city.place": Double(try #require(cities.firstIndex(of: "Spaceport"))), "city.launches": 3]
    for knob in PixelCity.knobs where knob.key.hasPrefix("city.rocket.") { settings[knob.key] = knob.key == "city.rocket.shuttle" ? 1 : 0 }
    defer { settings.keys.forEach(UserDefaults.standard.removeObject) }
    for (key, value) in settings { UserDefaults.standard.set(value, forKey: key) }
    let scene = PixelCity(size: CGSize(width: 800, height: 500))
    for step in 0..<4_500 {
        scene.update(Double(step) / 10)
        if step % 20 == 0 { scene.didFinishUpdate() }
    }
    #expect(scene.rocketName == "SHUTTLE" && scene.movements >= 5, "\(scene.movements) lift-offs and landings")
}
