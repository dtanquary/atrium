import SpriteKit
import SwiftUI

/// A wallpaper: its entry in the menu and the Settings window, and how to build it for one display. Settings
/// are plain data, so giving a wallpaper sliders, switches or palettes only means filling in `knobs` or `palettes`.
struct Wallpaper {
    let name: String
    let icon: String // SF Symbol
    let tint: Color
    let blurb: String
    let make: @MainActor (CGSize) -> SKScene
    var knobs: [Knob] = []
    var palettes: PaletteChoice?
    /// Palettes that each go with one pick of one of its menus (`PaletteChoice.shownWhen` and `shownAt`), their
    /// swatches shown under that menu while it is at that pick: Meander's colours for relief and for the old map.
    /// The scene follows a pick as it does a knob; unlike `palettes`, nothing is rebuilt for it.
    var looks: [PaletteChoice] = []
    /// A line the scene keeps up to date in UserDefaults under `key` (what the live weather last said, say), shown
    /// under its knob `below` while that knob is 0, or on for a switch.
    var status: (key: String, below: String)?
    /// A Refresh Now button for its live data, if it has any.
    var refresh: Refresh?
    /// A section of its settings that goes by another title while one of its menus is at one pick: Pixel Window
    /// Seat's Flight is the train's Journey.
    var retitled: (section: String, title: String, when: String, at: Double)?
    /// Its scene changes between Light and Dark Mode by itself, while it runs: it watches the system's appearance
    /// and eases to its other look (Meander, whose river then carries on). The app builds no new scene for it
    /// when the appearance changes, as it does for every other wallpaper.
    var followsAppearance = false
    /// A ceiling in frames per second for when it runs slower than on mains power (on battery or in Low Power Mode,
    /// not with Full Speed on Battery), for a wallpaper whose motion is slow enough that a lower rate can't be seen:
    /// 10, 12, 15 or 20, which divide 60 and 120. A scene whose motion speeds up and slows down as it runs says so
    /// itself instead (`BatteryPaced`).
    var batteryRate: Int?
    /// The fraction of the screen's resolution its softest part draws at under the same condition as `batteryRate`,
    /// with Settings → Power's Lighter drawing on battery on: 0.75 or 0.5, for a wallpaper where side-by-side
    /// comparisons at 100% show no difference. Its scene adopts `Trimmable`.
    var batteryScale: CGFloat?
    /// Not good enough to show yet: left out of the menu, Settings, Shuffle and the welcome unless `unfinished` is set
    /// (`defaults write com.dtanquary.atrium unfinished -bool true`, then relaunch), but still built and render-tested.
    /// One that is parked, not being worked on, can be left hidden even then by name
    /// (`defaults write com.dtanquary.atrium unfinished.hide -array "A Tree for the Year"`).
    var unfinished = false

    /// The title a section of its settings goes by, given what the menu that can retitle it holds.
    func title(of section: String, holding pick: Double) -> String {
        retitled.map { $0.section == section && pick == $0.at ? $0.title : section } ?? section
    }
}

/// Refresh Now on a wallpaper's Settings page: `run` fetches its live data now, `available` says when it can next
/// (each source keeps its own cooldown, so it can't be used to hammer the service), and `updated` when the data it's
/// showing arrived.
struct Refresh {
    let run: @MainActor () -> Void
    let available: @MainActor () -> Date
    let updated: @MainActor () -> Date?

    /// Open-Meteo's weather where you are, shared by Weather, Dappled Light, Rain on Glass and A Tree for the Year.
    @MainActor static let weather = Refresh(run: { LiveWeather.shared.poll(force: true) },
                                            available: { LiveWeather.shared.available }, updated: { LiveWeather.shared.updated })
    /// Wind's forecast for the zoom picked.
    @MainActor static let wind = Refresh(run: { WindField.shared.poll(zoom: Int(WindScene.zoom.value), force: true) },
                                         available: { WindField.shared.available(zoom: Int(WindScene.zoom.value)) },
                                         updated: { WindField.shared.updated(zoom: Int(WindScene.zoom.value)) })
    /// Earth from Orbit's storms and cloud map.
    @MainActor static let earth = Refresh(run: {
        Storms.shared.poll(around: Location.shared.coordinate, force: true)
        Clouds.shared.poll(force: true)
    }, available: { max(Storms.shared.available, Clouds.shared.available) }, updated: { Storms.shared.updated })
    /// Pixel Spaceport's schedule of real launches.
    @MainActor static let launches = Refresh(run: { LaunchSchedule.shared.poll(force: true) },
                                             available: { LaunchSchedule.shared.available }, updated: { LaunchSchedule.shared.updated })
}

/// Every wallpaper, finished or not. The list sorts itself by name, so the menu and Settings show them alphabetically
/// wherever an entry sits here.
@MainActor let allScenes: [Wallpaper] = [
    Wallpaper(name: "Fish Tank", icon: "fish.fill", tint: .teal, blurb: "A bright reef tank of real fish and corals.",
              make: { FishTank(size: $0) }, knobs: FishTank.knobs),
    Wallpaper(name: "Flowing Gradient", icon: "swirl.circle.righthalf.filled", tint: .pink,
              blurb: "Soft pools of color with silk ribbons that follow the Sun.", make: flowingGradient,
              knobs: FlowingGradient.knobs,
              palettes: PaletteChoice(key: "gradient.palette", options: FlowingGradient.paletteOptions)),
    Wallpaper(name: "Lava Lamp", icon: "lamp.table.fill", tint: .red, blurb: "Glowing wax rising and falling.",
              make: lavaLamp, knobs: LavaLamp.knobs,
              palettes: PaletteChoice(key: "lava.palette", options: LavaLamp.palettes.map { ($0.name, [$0.dark[3], $0.dark[1]], [$0.light[3], $0.light[1]]) })),
    Wallpaper(name: "Rain on Glass", icon: "cloud.rain.fill", tint: .gray, blurb: "Drops sliding down a rainy window.",
              make: rainOnGlass, knobs: rainKnobs,
              palettes: PaletteChoice(key: "rain.palette", options: rainPhotos.map { ($0.name, [], []) }
                                      + rainPalettes.map { ($0.name, [$0.night[1], $0.lights[0], $0.lights[1]], [$0.day[0], $0.lights[0], $0.lights[1]]) },
                                      standard: "City",
                                      photos: Dictionary(uniqueKeysWithValues: rainPhotos.map { ($0.name, ("rain-\($0.night)-far.jpg", "rain-\($0.day)-far.jpg")) }),
                                      title: "Backdrop"),
              status: (key: "rain.status", below: "rain.weather"), refresh: .weather),
    Wallpaper(name: "Aurora", icon: "mountain.2.fill", tint: .teal, blurb: "Northern lights over snowy peaks.", make: aurora, knobs: auroraKnobs,
              palettes: PaletteChoice(key: "aurora.palette", options: auroraPalettes.map { ($0.name, $0.colours.reversed(), $0.colours.reversed()) }), batteryRate: 15,
              batteryScale: 0.5),
    Wallpaper(name: "Nebula", icon: "sparkles", tint: .purple, blurb: "A new deep-space cloud every few minutes.",
              make: nebula, knobs: nebulaKnobs,
              palettes: PaletteChoice(key: "nebula.palette", options: nebulaPalettes.map { ($0.name, Array($0.colours[1...]), Array($0.colours[1...])) }), batteryRate: 15,
              batteryScale: 0.75),
    Wallpaper(name: "Galaxy", icon: "hurricane", tint: .indigo, blurb: "A spiral galaxy, after a real one, slowly turning.",
              make: galaxy, knobs: Galaxy.knobs,
              palettes: PaletteChoice(key: "galaxy.kind", options: Galaxy.kinds.map { ($0.name, [$0.colours[0], $0.colours[3], $0.colours[2]],
                                                                                     [$0.colours[0], $0.colours[3], $0.colours[2]]) }),
              batteryRate: 12, batteryScale: 0.75),
    Wallpaper(name: "Black Hole", icon: "circle.circle.fill", tint: .orange, blurb: "A black hole's glowing disc, bent round it by gravity.",
              make: blackHole, knobs: BlackHole.knobs, palettes: BlackHole.palette, batteryRate: 20),
    Wallpaper(name: "Meander", icon: "point.bottomleft.forward.to.point.topright.scurvepath", tint: .teal,
              blurb: "A river wandering across its floodplain, leaving its old courses behind.", make: meander, knobs: Meander.knobs, looks: Meander.palettes, followsAppearance: true,
              batteryRate: 12, batteryScale: 0.75),
    Wallpaper(name: "Etching", icon: "scribble.variable", tint: .gray, blurb: "Old etchings, engravings and woodcuts, drawn in one unbroken line.",
              make: etching, knobs: Etching.knobs, followsAppearance: true),
    Wallpaper(name: "Peg Board", icon: "circle.grid.3x3.fill", tint: .purple, blurb: "Glowing colored pegs on a black sheet, placed one at a time.",
              make: pegBoard, knobs: PegBoard.knobs, palettes: PegBoard.palette, batteryRate: 12),
    Wallpaper(name: "Ant Colony", icon: "ant.fill", tint: .blue, blurb: "Ants digging a new nest every day, seen through the glass.",
              make: antColony, knobs: AntColony.knobs, batteryRate: 20),
    Wallpaper(name: "Live Sky", icon: "moon.stars.fill", tint: .blue, blurb: "The real sky above you, right now.",
              make: liveSky, knobs: LiveSky.knobs, batteryScale: 0.5),
    Wallpaper(name: "Earth from Orbit", icon: "globe.americas.fill", tint: .cyan, blurb: "Day and night sweeping over the globe.",
              make: earthFromOrbit, knobs: EarthFromOrbit.knobs, refresh: .earth),
    Wallpaper(name: "Weather", icon: "cloud.sun.fill", tint: .blue, blurb: "Real hills under your live local weather.",
              make: weather, knobs: WeatherScene.knobs, status: (key: "weather.status", below: "weather.lock"), refresh: .weather),
    Wallpaper(name: "Pixel City", icon: "building.2.fill", tint: .pink, blurb: "A pixel-art skyline on your clock.",
              make: pixelCity, knobs: PixelCity.knobs),
    Wallpaper(name: "Pixel Spaceport", icon: "location.north.fill", tint: .orange, blurb: "A pixel-art launch site that never stops.",
              make: pixelSpaceport, knobs: PixelCity.spaceportKnobs, status: (key: "spaceport.status", below: "spaceport.live"), refresh: .launches),
    Wallpaper(name: "Pixel Window Seat", icon: "airplane", tint: .blue, blurb: "A pixel-art window seat on a plane, a train or the space station.",
              make: pixelWindowSeat, knobs: PixelWindowSeat.knobs,
              status: (key: "weather.status", below: TrainWeather.follow.key), // the train's weather
              retitled: PixelWindowSeat.journey),
    Wallpaper(name: "Fireflies", icon: "sparkle", tint: .yellow, blurb: "A meadow at blue hour, twinkling with fireflies.",
              make: fireflies, knobs: Fireflies.knobs, batteryRate: 20),
    Wallpaper(name: "Murmuration", icon: "bird.fill", tint: .brown, blurb: "Starlings swirling over a sunset.",
              make: murmuration, knobs: murmurationKnobs),
    Wallpaper(name: "Campfire", icon: "flame.fill", tint: .red, blurb: "A campfire in a forest clearing, under the real stars.",
              make: campfire, unfinished: true),
    Wallpaper(name: "Game of Life", icon: "square.grid.3x3.fill", tint: .orange, blurb: "Conway's cells that never die out.",
              make: gameOfLife, knobs: GameOfLife.knobs),
    Wallpaper(name: "Turing Patterns", icon: "circle.hexagongrid.fill", tint: .mint, blurb: "Coral, spots and stripes growing out of simple chemistry.",
              make: turingPatterns, knobs: TuringPatterns.knobs,
              palettes: PaletteChoice(key: "turing.palette", options: TuringPatterns.palettes.map { ($0.name, [$0.ink, $0.ink2, $0.glow], [$0.ink * 0.9, $0.ink2 * 0.9]) }),
              batteryRate: 15),
    Wallpaper(name: "Schlieren", icon: "heat.waves", tint: .red, blurb: "Rising heat made visible in color, as a schlieren camera sees it.",
              make: schlieren, knobs: Schlieren.knobs,
              palettes: PaletteChoice(key: "schlieren.palette", options: Schlieren.paletteOptions)),
    Wallpaper(name: "Wind", icon: "wind", tint: .cyan, blurb: "The live wind around you, streaming across the map.",
              make: wind, knobs: WindScene.knobs,
              palettes: PaletteChoice(key: "wind.palette", options: WindScene.paletteOptions, standard: "Midnight"), refresh: .wind),
    Wallpaper(name: "Dappled Light", icon: "leaf.fill", tint: .mint, blurb: "Sunlight through leaves on a plaster wall, from the real Sun.",
              make: dappledLight, knobs: DappledLight.knobs, status: (key: "weather.status", below: "dappled.weather"),
              refresh: .weather, batteryScale: 0.75),
    Wallpaper(name: "A Tree for the Year", icon: "tree.fill", tint: .green, blurb: "One tree on a hill, through your real seasons and weather.",
              make: treeForTheYear, knobs: TreeScene.treeKnobs, status: (key: "weather.status", below: "tree.lock"),
              refresh: .weather, unfinished: true),
    Wallpaper(name: "Deep Space Tour", icon: "star.circle.fill", tint: .blue,
              blurb: "Slow pans across the best real photos of nebulae, galaxies and the two black holes ever seen.", make: deepSpaceTour,
              knobs: Tour.deepSpace.knobs, palettes: Tour.deepSpace.showChoice, batteryRate: 20),
    Wallpaper(name: "Solar System Tour", icon: "smallcircle.filled.circle", tint: .orange,
              blurb: "Slow pans across the best photos of every world, with the live Sun and Moon.", make: solarSystemTour,
              knobs: Tour.solarSystem.knobs + ([TheSun.wavelengthKnob] + TheSun.knobs).map { $0.in("The Sun") } + TheMoon.knobs.map { $0.in("The Moon") },
              palettes: Tour.solarSystem.showChoice, batteryRate: 20),
].sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

/// The wallpapers people see: all but the unfinished ones, unless `unfinished` is set for working on them, and
/// even then not those named in `unfinished.hide`.
@MainActor let scenes = allScenes.filter {
    !$0.unfinished || UserDefaults.standard.bool(forKey: "unfinished") && UserDefaults.standard.stringArray(forKey: "unfinished.hide")?.contains($0.name) != true
}

/// The wallpaper on first launch, and in place of a saved one that's since been cut.
@MainActor let defaultScene = scenes.first { $0.name == "Fish Tank" }!

/// Seconds for shaders to animate by, as `u_now`, in place of SpriteKit's `u_time`. `u_time` counts from app launch
/// and nothing resets it, so as a Float it coarsens: after a week of running it moves 16 times a second, and sines
/// of it turn to noise within a month. This counts from `restart()`, which the app calls when it rebuilds a
/// long-running wallpaper (`refreshIfStale` in main.swift), so it stays small. Every `WallpaperView` sets it as it
/// draws; the render tests leave it at 0, as `u_time` was there.
@MainActor enum WallpaperTime {
    static let now = SKUniform(name: "u_now", float: 0)
    private static var start: TimeInterval?, latest: TimeInterval = 0
    /// Seconds counted since the last restart, as of the last frame drawn.
    static var elapsed: TimeInterval { latest - (start ?? latest) }

    static func set(_ time: TimeInterval) {
        if start == nil { start = time }
        latest = time
        now.floatValue = Float(elapsed)
    }

    static func restart() { start = nil }
}

/// A scene that can skip ahead to something worth looking at, for a wallpaper that starts from nothing (an empty
/// sheet, a bare screen). Settings asks it of the copy it runs behind a wallpaper's page (`LivePreview`), once, as
/// soon as that copy is made, so that the page's sliders can be judged at once. The desktop's copy is never asked.
@MainActor protocol HeadStart {
    func headStart()
}

/// A scene whose ceiling on battery (as `Wallpaper.batteryRate`) changes as it runs: lower through slow phases, none
/// through fast ones. While it's set, the view showing the scene holds to it in place of its wallpaper's; nil leaves
/// the wallpaper's. The scene sets it from the moment it's built, as a view reads it when the scene is presented, and
/// calls `batteryRateChanged(from:)` whenever it sets it, which tells the view only if it changed.
@MainActor protocol BatteryPaced: SKScene {
    var batteryRate: Int? { get }
}

extension BatteryPaced {
    /// Tells the views showing this scene, if `batteryRate` is no longer `old`. None does in the render tests.
    func batteryRateChanged(from old: Int?) {
        if batteryRate != old { NotificationCenter.default.post(name: .batteryRateChanged, object: self) }
    }
}

extension Notification.Name {
    /// Posted by a `BatteryPaced` scene whose `batteryRate` has changed.
    static let batteryRateChanged = Notification.Name("AtriumBatteryRateChanged")
}

/// A scene that is one full-screen GPU shader. Besides `u_now` (see `WallpaperTime`) and `v_tex_coord`, the shader
/// gets `u_size`, the scene size in points, for aspect-correct math, and a float for each knob, named `u_` plus
/// the last part of its key, that follows Settings live.
/// With a `speed` knob, the shader also gets `u_clock`: seconds that run that many times as fast as real ones, summed
/// frame by frame so moving the slider never makes it jump.
@MainActor func shaderScene(size: CGSize, source: String, uniforms: [SKUniform] = [], knobs: [Knob] = [], speed: Knob? = nil) -> SKScene {
    let scene = ShaderScene(size: size)
    scene.knobs = knobs.map { ($0, SKUniform(name: "u_" + $0.key.split(separator: ".").last!, float: Float($0.value))) }
    scene.clock = speed.map { (SKUniform(name: "u_clock", float: 0), $0) }
    let sprite = SKSpriteNode(color: .black, size: size)
    sprite.anchorPoint = .zero
    let sizeUniform = SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)])
    sprite.shader = SKShader(source: source, uniforms: [sizeUniform] + uniforms + scene.knobs.map(\.uniform) + [scene.clock?.uniform].compactMap { $0 }
                             + (source.contains("u_now") ? [WallpaperTime.now] : []))
    scene.sprite = sprite
    scene.trim.content.addChild(sprite)
    scene.addChild(scene.trim)
    NotificationCenter.default.addObserver(scene, selector: #selector(ShaderScene.applyKnobs),
                                           name: UserDefaults.didChangeNotification, object: nil)
    return scene
}

/// A `shaderScene`, which keeps its knob uniforms in step with Settings, and runs its clock if it has one. Its
/// `batteryRate` is its wallpaper's unless the scene's maker sets one (Rain on Glass, once its drops have stopped).
final class ShaderScene: SKScene, BatteryPaced, Trimmable {
    /// The full-screen sprite its shader draws on, in `trim`.
    var sprite: SKSpriteNode!
    let trim = TrimNode()
    var knobs: [(knob: Knob, uniform: SKUniform)] = []
    var batteryRate: Int? { didSet { batteryRateChanged(from: oldValue) } }
    var clock: (uniform: SKUniform, speed: Knob)?
    /// The clock's time, summed in Double so it keeps counting after days (a Float stops once each frame's step
    /// rounds away); the shader gets it as a Float, so keep it small where the shader needs it precise.
    var clockTime: Double = 0 { didSet { clock?.uniform.floatValue = Float(clockTime) } }
    private var lastUpdate: TimeInterval?

    @objc func applyKnobs() { for (knob, uniform) in knobs { uniform.floatValue = Float(knob.value) } }

    override func update(_ currentTime: TimeInterval) {
        guard let clock else { return }
        clockTime += frameTime(currentTime, &lastUpdate) * clock.speed.value
    }
}

/// Whether macOS is in Dark Mode. Scenes with light and dark looks read it when they're built; the app rebuilds
/// the current scene when the appearance changes.
@MainActor var systemIsDark: Bool {
    NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
}

/// Draws a texture with Core Graphics at 2x so it stays sharp on Retina. Origin is bottom-left, like SpriteKit.
/// The texture's pixel size is double `size`, so give sprites their size explicitly.
func paint(_ size: CGSize, _ draw: (CGContext) -> Void) -> SKTexture {
    let context = CGContext(data: nil, width: Int(size.width * 2), height: Int(size.height * 2),
                            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.scaleBy(x: 2, y: 2)
    draw(context)
    return SKTexture(cgImage: context.makeImage()!)
}

/// A file from Sources/Atrium/Resources: inside the .app when built with build.sh, else straight from the source tree.
func resource(_ name: String) -> URL {
    Bundle.main.url(forResource: name, withExtension: nil)
        ?? URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Resources/\(name)")
}

/// A texture shared by every scene that shows it (a display's and Settings' copy, or a scene and the one crossfading
/// in), and let go with the last: drawn by `make`, else the picture `name` in Resources. A wallpaper's photo is tens
/// of MB once decoded, and again on the GPU. Kept in statics for good once shown, a tour of every wallpaper (Shuffle's)
/// left 300 MB of texture pixels alone that no scene was using. Hold it in a local while building, or it may be let
/// go and drawn twice.
@MainActor func sharedTexture(_ name: String, make: (() -> SKTexture)? = nil) -> SKTexture {
    if let texture = sharedTextures.object(forKey: name as NSString) { return texture }
    let texture = make?() ?? SKTexture(image: NSImage(contentsOf: resource(name)) ?? NSImage())
    sharedTextures.setObject(texture, forKey: name as NSString)
    return texture
}

@MainActor private let sharedTextures = NSMapTable<NSString, SKTexture>.strongToWeakObjects()
