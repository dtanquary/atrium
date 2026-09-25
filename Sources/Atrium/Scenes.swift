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
}

/// Every wallpaper, in menu order.
@MainActor let scenes: [Wallpaper] = [
    Wallpaper(name: "Fish Tank", icon: "fish.fill", tint: .teal, blurb: "Schools of tropical fish in a sunlit tank.",
              make: { FishTank(size: $0) }),
    Wallpaper(name: "Flowing Gradient", icon: "swirl.circle.righthalf.filled", tint: .indigo,
              blurb: "Soft pools of color with silk ribbons that follow the Sun.", make: flowingGradient,
              knobs: FlowingGradient.knobs,
              palettes: PaletteChoice(key: "gradient.palette", options: FlowingGradient.paletteOptions, standard: "Midnight")),
    Wallpaper(name: "Lava Lamp", icon: "lamp.table.fill", tint: .orange, blurb: "Glowing wax rising and falling.",
              make: lavaLamp, knobs: LavaLamp.knobs,
              palettes: PaletteChoice(key: "lava.palette", options: LavaLamp.palettes.map { ($0.name, [$0.dark[3], $0.dark[1]], [$0.light[3], $0.light[1]]) })),
    Wallpaper(name: "Rain on Glass", icon: "cloud.rain.fill", tint: .gray, blurb: "Drops sliding down a rainy city window.",
              make: rainOnGlass,
              palettes: PaletteChoice(key: "rain.palette", options: rainPalettes.map { ($0.name, [$0.night[1], $0.lights[0], $0.lights[1]],
                                                                                       [$0.day[0], $0.lights[0], $0.lights[1]]) },
                                      standard: "City")),
    Wallpaper(name: "Aurora", icon: "wind", tint: .green, blurb: "Northern lights over snowy peaks.", make: aurora,
              palettes: PaletteChoice(key: "aurora.palette", options: auroraPalettes.map { ($0.name, $0.colours.reversed(), $0.colours.reversed()) })),
    Wallpaper(name: "Nebula", icon: "sparkles", tint: .purple, blurb: "A new deep-space cloud every few minutes.",
              make: nebula,
              palettes: PaletteChoice(key: "nebula.palette", options: nebulaPalettes.map { ($0.name, Array($0.colours[1...]), Array($0.colours[1...])) })),
    Wallpaper(name: "Galaxy", icon: "hurricane", tint: .indigo, blurb: "A spiral galaxy, after a real one, slowly turning.",
              make: galaxy, knobs: Galaxy.knobs,
              palettes: PaletteChoice(key: "galaxy.kind", options: Galaxy.kinds.map { ($0.name, [$0.colours[0], $0.colours[3], $0.colours[2]],
                                                                                     [$0.colours[0], $0.colours[3], $0.colours[2]]) })),
    Wallpaper(name: "Live Sky", icon: "moon.stars.fill", tint: .blue, blurb: "The real sky above you, right now.",
              make: liveSky, knobs: LiveSky.knobs),
    Wallpaper(name: "Earth from Orbit", icon: "globe.americas.fill", tint: .cyan, blurb: "Day and night sweeping over the globe.",
              make: earthFromOrbit, knobs: EarthFromOrbit.knobs),
    Wallpaper(name: "Weather", icon: "cloud.sun.fill", tint: .blue, blurb: "Hills under your live local weather.",
              make: weather),
    Wallpaper(name: "Pixel City", icon: "building.2.fill", tint: .pink, blurb: "A pixel-art skyline on your clock.",
              make: pixelCity),
    Wallpaper(name: "Fireflies", icon: "sparkle", tint: .yellow, blurb: "Fireflies in a foggy forest at dusk.",
              make: fireflies),
    Wallpaper(name: "Murmuration", icon: "bird.fill", tint: .brown, blurb: "Starlings swirling over a sunset.",
              make: murmuration),
    Wallpaper(name: "Campfire", icon: "flame.fill", tint: .red, blurb: "A crackling fire under the stars.", make: campfire),
    Wallpaper(name: "Game of Life", icon: "square.grid.3x3.fill", tint: .orange, blurb: "Conway's cells that never die out.",
              make: gameOfLife),
]

/// A scene that is one full-screen GPU shader. Besides SpriteKit's `u_time` and `v_tex_coord`, the shader
/// gets `u_size`, the scene size in points, for aspect-correct math.
@MainActor func shaderScene(size: CGSize, source: String, uniforms: [SKUniform] = []) -> SKScene {
    let scene = SKScene(size: size)
    let sprite = SKSpriteNode(color: .black, size: size)
    sprite.anchorPoint = .zero
    let sizeUniform = SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)])
    sprite.shader = SKShader(source: source, uniforms: [sizeUniform] + uniforms)
    scene.addChild(sprite)
    return scene
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
