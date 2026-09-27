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
    /// A line the scene keeps up to date in UserDefaults under `key` (what the live weather last said, say), shown
    /// under its knob `below` while that knob is 0, or on for a switch.
    var status: (key: String, below: String)?
}

/// Every wallpaper, in menu order.
@MainActor let scenes: [Wallpaper] = [
    Wallpaper(name: "Fish Tank", icon: "fish.fill", tint: .teal, blurb: "A bright reef tank of real fish and corals.",
              make: { FishTank(size: $0) }),
    Wallpaper(name: "Flowing Gradient", icon: "swirl.circle.righthalf.filled", tint: .indigo,
              blurb: "Soft pools of color with silk ribbons that follow the Sun.", make: flowingGradient,
              knobs: FlowingGradient.knobs,
              palettes: PaletteChoice(key: "gradient.palette", options: FlowingGradient.paletteOptions)),
    Wallpaper(name: "Lava Lamp", icon: "lamp.table.fill", tint: .orange, blurb: "Glowing wax rising and falling.",
              make: lavaLamp, knobs: LavaLamp.knobs,
              palettes: PaletteChoice(key: "lava.palette", options: LavaLamp.palettes.map { ($0.name, [$0.dark[3], $0.dark[1]], [$0.light[3], $0.light[1]]) })),
    Wallpaper(name: "Rain on Glass", icon: "cloud.rain.fill", tint: .gray, blurb: "Drops sliding down a rainy window.",
              make: rainOnGlass, knobs: rainKnobs,
              palettes: PaletteChoice(key: "rain.palette", options: rainPhotos.map { ($0.name, [], []) }
                                      + rainPalettes.map { ($0.name, [$0.night[1], $0.lights[0], $0.lights[1]], [$0.day[0], $0.lights[0], $0.lights[1]]) },
                                      standard: "City",
                                      photos: Dictionary(uniqueKeysWithValues: rainPhotos.map { ($0.name, ("rain-\($0.night)-far.jpg", "rain-\($0.day)-far.jpg")) }),
                                      title: "Backdrop"),
              status: (key: "rain.status", below: "rain.weather")),
    Wallpaper(name: "Aurora", icon: "wind", tint: .green, blurb: "Northern lights over snowy peaks.", make: aurora, knobs: auroraKnobs,
              palettes: PaletteChoice(key: "aurora.palette", options: auroraPalettes.map { ($0.name, $0.colours.reversed(), $0.colours.reversed()) })),
    Wallpaper(name: "Nebula", icon: "sparkles", tint: .purple, blurb: "A new deep-space cloud every few minutes.",
              make: nebula, knobs: nebulaKnobs,
              palettes: PaletteChoice(key: "nebula.palette", options: nebulaPalettes.map { ($0.name, Array($0.colours[1...]), Array($0.colours[1...])) })),
    Wallpaper(name: "Galaxy", icon: "hurricane", tint: .indigo, blurb: "A spiral galaxy, after a real one, slowly turning.",
              make: galaxy, knobs: Galaxy.knobs,
              palettes: PaletteChoice(key: "galaxy.kind", options: Galaxy.kinds.map { ($0.name, [$0.colours[0], $0.colours[3], $0.colours[2]],
                                                                                     [$0.colours[0], $0.colours[3], $0.colours[2]]) })),
    Wallpaper(name: "Live Sky", icon: "moon.stars.fill", tint: .blue, blurb: "The real sky above you, right now.",
              make: liveSky, knobs: LiveSky.knobs),
    Wallpaper(name: "The Moon", icon: "moonphase.waxing.gibbous", tint: .gray, blurb: "The Moon as it looks from where you are, right now.",
              make: theMoon, knobs: TheMoon.knobs),
    Wallpaper(name: "Earth from Orbit", icon: "globe.americas.fill", tint: .cyan, blurb: "Day and night sweeping over the globe.",
              make: earthFromOrbit, knobs: EarthFromOrbit.knobs),
    Wallpaper(name: "Weather", icon: "cloud.sun.fill", tint: .blue, blurb: "Real hills under your live local weather.",
              make: weather, knobs: WeatherScene.knobs, status: (key: "weather.status", below: "weather.lock")),
    Wallpaper(name: "Pixel City", icon: "building.2.fill", tint: .pink, blurb: "A pixel-art skyline on your clock.",
              make: pixelCity),
    Wallpaper(name: "Fireflies", icon: "sparkle", tint: .yellow, blurb: "A meadow at blue hour, twinkling with fireflies.",
              make: fireflies, knobs: Fireflies.knobs),
    Wallpaper(name: "Murmuration", icon: "bird.fill", tint: .brown, blurb: "Starlings swirling over a sunset.",
              make: murmuration, knobs: murmurationKnobs),
    Wallpaper(name: "Campfire", icon: "flame.fill", tint: .red, blurb: "A campfire in a forest clearing, under the real stars.",
              make: campfire),
    Wallpaper(name: "Game of Life", icon: "square.grid.3x3.fill", tint: .orange, blurb: "Conway's cells that never die out.",
              make: gameOfLife, knobs: GameOfLife.knobs),
    Wallpaper(name: "Turing Patterns", icon: "circle.hexagongrid.fill", tint: .mint, blurb: "Coral, spots and stripes growing out of simple chemistry.",
              make: turingPatterns, knobs: TuringPatterns.knobs,
              palettes: PaletteChoice(key: "turing.palette", options: TuringPatterns.palettes.map { ($0.name, [$0.ink, $0.ink2, $0.glow], [$0.ink * 0.9, $0.ink2 * 0.9]) })),
    Wallpaper(name: "The Sun Today", icon: "sun.max.fill", tint: .orange, blurb: "The real Sun, from NASA's Solar Dynamics Observatory.",
              make: theSun, knobs: TheSun.knobs,
              palettes: PaletteChoice(key: "sun.wavelength", options: TheSun.wavelengths.map { ($0.name, $0.swatch, $0.swatch) }, title: "Wavelength")),
    Wallpaper(name: "Crystals", icon: "hexagon.fill", tint: .yellow, blurb: "Vitamin C crystallising under polarised light.",
              make: crystals, knobs: Crystals.knobs),
    Wallpaper(name: "Wind", icon: "wind", tint: .cyan, blurb: "The live wind around you, streaming across the map.",
              make: wind, knobs: WindScene.knobs,
              palettes: PaletteChoice(key: "wind.palette", options: WindScene.paletteOptions, standard: "Midnight")),
    Wallpaper(name: "Dappled Light", icon: "leaf.fill", tint: .green, blurb: "Sunlight through leaves on a plaster wall, from the real Sun.",
              make: dappledLight, knobs: DappledLight.knobs, status: (key: "weather.status", below: "dappled.weather")),
    Wallpaper(name: "A Tree for the Year", icon: "tree.fill", tint: .green, blurb: "One tree on a hill, through your real seasons and weather.",
              make: treeForTheYear, knobs: TreeScene.treeKnobs, status: (key: "weather.status", below: "tree.lock")),
]

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
    scene.addChild(sprite)
    NotificationCenter.default.addObserver(scene, selector: #selector(ShaderScene.applyKnobs),
                                           name: UserDefaults.didChangeNotification, object: nil)
    return scene
}

/// A `shaderScene`, which keeps its knob uniforms in step with Settings, and runs its clock if it has one.
final class ShaderScene: SKScene {
    var knobs: [(knob: Knob, uniform: SKUniform)] = []
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
