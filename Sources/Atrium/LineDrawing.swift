import LineRoute
import SpriteKit
import Synchronization

@MainActor func lineDrawing(size: CGSize) -> SKScene { LineDrawing(size: size) }

/// A picture drawn in one unbroken line on a screen of grey powder, as on the toy with two dials: the stylus scrapes
/// the powder off the back of the glass, so the line is the dark inside showing through, and it can never lift. An
/// old print's own outlines come first, then its shading as rows of hatching, the stylus going back along lines it
/// has drawn to get from place to place. The picture is a shipped route (`LineRoute`, made by
/// docs/line-drawing/bake.py), stamped once into a texture of when each texel is first drawn; the shader compares
/// that with a clock, so a frame costs one read however much is drawn. The clock is the wall's: the picture goes on
/// from where it was after a relaunch or Shuffle, and every display shows the same moment of it.
/// docs/line-drawing.md has the measurements of the real toy, the route's format and the sources.
final class LineDrawing: SKScene {
    /// Its name, in this one place: a working name until one is settled.
    nonisolated static let title = "Line Drawing"
    /// How many times faster than a careful hand: at 1 the stylus crosses a fortieth of the screen's width a
    /// second and a picture takes about two hours; at the top one is done in two minutes.
    nonisolated static let speed = Knob(key: "linedrawing.speed", label: "Speed", range: 1...60, standard: 1, section: "Drawing", format: .times)
    nonisolated static let knobs = [speed]

    /// Screen widths the stylus crosses in a second at speed 1: an eighth of a turn of a dial a second on the toy.
    private static let pace = 1.0 / 40
    /// Seconds a finished picture is left before it is begun again, the last few of them fading it out.
    // ponytail: the same picture again, from bare; the set of pictures, and a soft clearing between them, come next
    private static let rest = 60.0, clearing = 4.0

    /// The wall-clock moment, in seconds since the reference date, the picture would have been begun at the speed
    /// the slider is at (`paced`): shared by every copy of the scene, each display and Settings' preview, and kept
    /// in the defaults so the picture goes on from where it was. Moving the slider moves it, so the picture stays
    /// as far along as it is.
    private static var began: Double?, paced: Double?
    private static let saved = "linedrawing.began"

    /// The seconds of drawing done by the wall-clock moment `wall`, of a picture that takes `seconds` at speed 1,
    /// and how long it has been finished.
    private static func moment(at wall: Double, of seconds: Double, saving: Bool) -> (drawn: Double, rested: Double) {
        let speed = Self.speed.value, was = paced ?? speed
        var start = began ?? (saving ? UserDefaults.standard.object(forKey: saved) as? Double : nil) ?? wall
        if speed != was { // the slider moved: as much is drawn (or as long rested) as was, and it goes on at the new speed
            let since = wall - start, rested = max(since - seconds / was, 0)
            start = wall - min(since * was, seconds) / speed - rested
        }
        let round = seconds / speed + rest
        if wall - start >= round { start += ((wall - start) / round).rounded(.down) * round }
        if start != began || speed != was, saving { UserDefaults.standard.set(start, forKey: saved) }
        (began, paced) = (start, speed)
        return (min(max(wall - start, 0) * speed, seconds), max(wall - start - seconds / speed, 0))
    }

    /// The stamped route, handed from the thread that made it to the scene's next frame.
    private final class Landing: Sendable {
        private let stamped = Mutex<LineRoute.Stamped?>(nil), ready = DispatchSemaphore(value: 0)
        func arrive(_ made: LineRoute.Stamped?) { stamped.withLock { $0 = made }; ready.signal() }
        /// What has arrived, once. `waiting` holds the caller until it has: for the render tests, which draw their
        /// frames faster than a picture can be stamped.
        func take(waiting: Bool) -> LineRoute.Stamped? {
            if waiting { ready.wait(); ready.signal() }
            return stamped.withLock { made in defer { made = nil }; return made }
        }
    }

    private let landing = Landing(), sprite = SKSpriteNode()
    private let clock = SKUniform(name: "u_clock", float: 0), show = SKUniform(name: "u_show", float: 0)
    private let texels = SKUniform(name: "u_tex", vectorFloat2: [1, 1])
    /// A texel that was never drawn, until the route is stamped.
    private let when = SKUniform(name: "u_when", texture: SKTexture(data: Data([255, 255, 255, 0]), size: CGSize(width: 1, height: 1)))
    /// How long the picture takes at speed 1, in seconds; none if its route could not be read.
    private var seconds = 0.0
    /// Whether the route's texture is in, and the wall-clock moment it went in: the picture fades up from there.
    private var landed = false, shownAt: Double?
    /// The share of the picture drawn as the scene is built, where the tests and the previews ask for one
    /// (`linedrawing.drawn`); nothing of theirs is saved.
    private var asked = UserDefaults.standard.object(forKey: "linedrawing.drawn") as? Double
    private let saving = UserDefaults.standard.object(forKey: "linedrawing.drawn") == nil

    private static let grain: SKTexture = {
        let tile = SKTexture(data: LineRoute.grain(), size: CGSize(width: 512, height: 512))
        tile.filteringMode = .linear
        return tile
    }()

    override func sceneDidLoad() {
        let dark = systemIsDark
        backgroundColor = dark ? NSColor(srgbRed: 0.41, green: 0.42, blue: 0.41, alpha: 1) : NSColor(srgbRed: 0.6, green: 0.6, blue: 0.59, alpha: 1)
        // The display's own pixels, and a texel to each; from the 14-inch size up, a texel to two each way, which
        // is a pixel softer and a quarter of the memory (docs/line-drawing.md, "Cost").
        let factor = NSScreen.screens.first { $0.frame.size == size }?.backingScaleFactor ?? 2
        let pixels = SIMD2(Double(size.width * factor).rounded(), Double(size.height * factor).rounded())
        let half = pixels.x * pixels.y > 6_500_000, wide = Int(pixels.x) / (half ? 2 : 1), high = Int(pixels.y) / (half ? 2 : 1)
        func tone(_ r: Float, _ g: Float, _ b: Float) -> SIMD3<Float> { SIMD3(r, g, b) / 255 }
        sprite.size = size
        sprite.anchorPoint = .zero
        sprite.shader = SKShader(source: shaderCommon + Self.source(half: half), uniforms: [
            SKUniform(name: "u_px", vectorFloat2: [Float(pixels.x), Float(pixels.y)]), SKUniform(name: "u_grains", float: Float(2560 / pixels.x)),
            SKUniform(name: "u_grain", texture: Self.grain), texels, when, clock, show,
            // the powder in a lit room and a dim one, and the dark inside, a third as light (docs/line-drawing.md, "Look")
            SKUniform(name: "u_screen", vectorFloat3: dark ? tone(104, 106, 104) : tone(152, 154, 151)),
            SKUniform(name: "u_ink", vectorFloat3: dark ? tone(34, 35, 37) : tone(50, 52, 54))])
        addChild(sprite)

        guard let file = try? Data(contentsOf: resource("line-wave.route")), let heading = LineRoute(file, walking: false) else { return }
        seconds = heading.clock / (Double(heading.columns) * Self.pace)
        // The grid fitted to the screen and centred; a frame, later, would give it a smaller rectangle here.
        let scale = min(Double(wide) / Double(heading.columns), Double(high) / Double(heading.rows))
        let (dx, dy) = ((Double(wide) - Double(heading.columns) * scale) / 2, (Double(high) - Double(heading.rows) * scale) / 2)
        Task.detached(priority: .userInitiated) { [landing] in
            landing.arrive(LineRoute(file)?.stamp(width: wide, height: high, scale: scale, dx: dx, dy: dy))
        }
    }

    override func update(_ currentTime: TimeInterval) {
        // The wall's clock, by way of the frame's own time: the two run together, but the tests' frames come
        // faster than real ones and their pictures have to be of their own moments.
        let wall = currentTime + Date.timeIntervalSinceReferenceDate - ProcessInfo.processInfo.systemUptime
        if !landed, let stamped = landing.take(waiting: view == nil) {
            landed = true
            when.textureValue = SKTexture(data: stamped.when, size: CGSize(width: stamped.width, height: stamped.height))
            texels.vectorFloat2Value = [Float(stamped.width), Float(stamped.height)]
        }
        guard landed, seconds > 0 else { return }
        if let share = asked {
            (Self.began, Self.paced, asked) = (wall - min(max(share, 0), 1) * seconds / Self.speed.value, nil, nil)
        }
        let (drawn, rested) = Self.moment(at: wall, of: seconds, saving: saving)
        clock.floatValue = Float(drawn / seconds * LineRoute.end / 256)
        shownAt = shownAt ?? wall
        show.floatValue = Float(simd_smoothstep(0, 1, (wall - shownAt!) / 0.4) * (1 - simd_smoothstep(Self.rest - Self.clearing, Self.rest, rested)))
    }

    /// The shader: the texture of when each texel is first drawn against the clock, on the powder. A texture a
    /// shader reads is smoothed whatever its filtering is set to, and a time smoothed between a drawn texel and a
    /// bare one is a time when nothing happened, so every read is at a texel's centre. With a texel to each pixel
    /// that is one read; with a texel to two each way (`half`) it is the four round the pixel, each compared with
    /// the clock on its own and only then mixed.
    private static func source(half: Bool) -> String {
        let read = half ? """
            vec2 q = v_tex_coord * u_tex - 0.5, f = fract(q), b = floor(q);
            float a = 0.0;
            for (float j = 0.0; j < 1.5; j += 1.0) {
                for (float i = 0.0; i < 1.5; i += 1.0) {
                    vec4 w = texture2D(u_when, (clamp(b + vec2(i, j), vec2(0.0), u_tex - 1.0) + 0.5) / u_tex);
                    a += mix(1.0 - f.x, f.x, i) * mix(1.0 - f.y, f.y, j) * w.a * step(when24(w), u_clock);
                }
            }
        """ : """
            vec4 w = texture2D(u_when, (floor(v_tex_coord * u_tex) + 0.5) / u_tex);
            float a = w.a * step(when24(w), u_clock);
        """
        return """
        // When a texel was first drawn, from its three bytes: in 65,536ths of the picture's clock, to a 256th of one.
        float when24(vec4 w) { return floor(w.r * 255.0 + 0.5) * 256.0 + floor(w.g * 255.0 + 0.5) + floor(w.b * 255.0 + 0.5) / 256.0; }

        void main() {
        \(read)
            // The powder: its grain is its own size on the glass whatever the display's pixels (u_grains), with a
            // slow unevenness across the whole screen, light from the upper left, and a few bright specks.
            vec2 at = v_tex_coord * u_px * u_grains;
            float fine = (texture2D(u_grain, fract(at / 512.0)).r - 0.502) * 0.1275;
            float slow = (texture2D(u_grain, v_tex_coord).g - 0.502) * 0.1275;
            vec2 cell = floor(at / 48.0);
            vec4 h = hash42(cell);
            float speck = max(0.0, 1.0 - distance(at, (cell + 0.15 + 0.7 * h.xy) * 48.0) / 1.6);
            vec3 screen = u_screen * (1.0 + fine + slow + 0.05 * (v_tex_coord.y - v_tex_coord.x) + 0.3 * step(h.z, 0.12) * speck * speck);
            // The line: a first pass leaves it pale, and its scraped edge is a little ragged.
            a = clamp(a * (1.0 + 6.0 * fine), 0.0, 1.0) * 0.62 * u_show;
            gl_FragColor = vec4(mix(screen, u_ink, a), 1.0);
        }
        """
    }
}
