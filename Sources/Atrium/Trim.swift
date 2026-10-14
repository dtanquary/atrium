import SpriteKit

/// Draws what it holds at a fraction of the screen's resolution and scales it up: a soft full-screen shader costs the
/// GPU by the pixel, so at 0.75 it shades about 56% of them, and at 0.5 a quarter. An effect node renders its children
/// into a texture at the scale they have inside it, then draws that texture at its own scale, so `content` is shrunk
/// by `scale` inside a node grown by its inverse, and its children keep the scene's coordinates. At 1 the effect is
/// off and they draw straight to the screen, exactly as with no trim at all. Drawing the texture costs a pass of its
/// own, 4–12% of the work of the shaders measured, and its memory: about 12 MB at 0.5 and 25 MB at 0.75.
final class TrimNode: SKEffectNode {
    /// What its children go in, in the scene's coordinates.
    let content = SKNode()
    /// The fraction of the screen's resolution it draws at (`Wallpaper.batteryScale`, set by `applyPowerState`).
    var scale: CGFloat = 1 {
        didSet {
            guard scale != oldValue else { return }
            shouldEnableEffects = scale < 1
            setScale(1 / scale)
            content.setScale(scale)
        }
    }

    override init() {
        super.init()
        shouldEnableEffects = false
        addChild(content)
    }

    required init?(coder: NSCoder) { fatalError("not used") }
}

/// A scene that draws its softest part in a `TrimNode`, which the view showing it sets to the wallpaper's
/// `batteryScale` while the trim applies (`Power.scale`).
@MainActor protocol Trimmable: SKScene {
    var trim: TrimNode { get }
}
