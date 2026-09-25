import SpriteKit

/// Every wallpaper in the menu, in menu order. `make` builds one scene for a display of the given size.
@MainActor let scenes: [(name: String, make: @MainActor (CGSize) -> SKScene)] = [
    ("Fish Tank", { FishTank(size: $0) }),
    ("Flowing Gradient", flowingGradient),
    ("Lava Lamp", lavaLamp),
    ("Rain on Glass", rainOnGlass),
    ("Aurora", aurora),
    ("Nebula", nebula),
    ("Night Sky", nightSky),
    ("Earth from Orbit", earthFromOrbit),
    ("Weather", weather),
    ("Pixel City", pixelCity),
    ("Fireflies", fireflies),
    ("Murmuration", murmuration),
    ("Campfire", campfire),
    ("Zen Garden", zenGarden),
    ("Game of Life", gameOfLife),
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

/// A file from Sources/Wallpaper/Resources: inside the .app when built with build.sh, else straight from the source tree.
func resource(_ name: String) -> URL {
    Bundle.main.url(forResource: name, withExtension: nil)
        ?? URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Resources/\(name)")
}
