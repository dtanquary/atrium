import SpriteKit

@MainActor func solarSystem(size: CGSize) -> SKScene { SolarSystem(size: size) }

/// A slow tour of the Sun's family in the best photos spacecraft and telescopes have taken: each world drifts and
/// zooms for a minute, then dissolves into the next. The tour moves from world to world rather than photo to photo,
/// so Saturn comes round no more often than Io, and each visit shows the next of its photos. The Sun and the Moon
/// are live: today's Sun from SDO (`TheSun`) and the Moon as it is right now (`TheMoon`), run inside this scene.
/// Settings can hold the tour on one world.
final class SolarSystem: SKScene {
    /// One view of a world, a row of `solar-photos.tsv`. A photo is a whole world on black, shown whole and never
    /// larger than its pixels allow, or a close-up that always fills the screen. `focus` is where the zoom heads, as
    /// fractions of the photo's width and height from its top left; `zoom` is how far, or 0 for the Zoom setting.
    struct View: Sendable {
        enum Kind: String, Sendable { case disc, closeup, live }
        let file: String, body: String, caption: String, kind: Kind
        let focus: SIMD2<Double>, zoom: Double
    }

    nonisolated static let views: [View] = ((try? String(contentsOf: resource("solar-photos.tsv"), encoding: .utf8)) ?? "")
        .split(separator: "\n").filter { !$0.hasPrefix("#") }.compactMap { line in
            let f = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 8, let kind = View.Kind(rawValue: f[6]) else { return nil }
            let n = f[7].split(separator: ",").compactMap { Double($0) }
            return View(file: f[0], body: f[1], caption: f[5], kind: kind,
                        focus: n.count >= 2 ? [n[0], n[1]] : [0.5, 0.5], zoom: n.count >= 3 ? n[2] : 0)
        }
    /// Every world, from the Sun outward, as the photo list orders them.
    nonisolated static let bodies = views.map(\.body).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }

    nonisolated static let knobs = [
        Knob(key: "solar.seconds", label: "Each view for", range: 20...300, standard: 60, section: "Tour", format: .seconds),
        Knob(key: "solar.zoom", label: "Zoom", range: 1...1.6, standard: 1.25, section: "Tour", format: .times),
        Knob(key: "solar.captions", label: "Names", range: 0...1, standard: 1, section: "Tour", format: .toggle),
        Knob(key: "solar.brightness", label: "Brightness", range: 0.4...1.2, standard: 1, section: "Tour", format: .times),
    ]
    /// The world the tour is held on, by name; empty tours them all.
    nonisolated static let bodyKey = "solar.body"
    /// The pick for Settings: every world, each with its thumbnail (`solar-thumb-<name>.jpg`).
    nonisolated static let bodyChoice = PaletteChoice(
        key: bodyKey, options: bodies.map { ($0, [[0.05, 0.07, 0.2], [0.3, 0.2, 0.45]], [[0.05, 0.07, 0.2], [0.3, 0.2, 0.45]]) },
        photos: Dictionary(uniqueKeysWithValues: bodies.map { ($0, (thumb($0), thumb($0))) }), title: "Show")
    nonisolated static func thumb(_ body: String) -> String {
        "solar-thumb-\(body.lowercased().replacingOccurrences(of: " ", with: "-")).jpg"
    }

    /// Seconds each dissolve takes; a view's motion runs on through its dissolve into the next.
    nonisolated private static let fade = 6.0
    /// The most a photo is ever magnified, in screen pixels per photo pixel: past this it would look soft.
    nonisolated private static let maxMagnification = 1.5

    /// A view on screen: its photo cut to what the motion shows (`texture`, and `region` of the photo in its pixels,
    /// y down), and the motion from `from` to `to`, each a centre in photo pixels and a scale in points per photo pixel.
    /// Live views have no photo; `scene` is theirs.
    private struct Shown {
        let view: View
        var texture: SKTexture?, region = CGRect.zero
        var from = SIMD3<Double>(), to = SIMD3<Double>()
        var scene: SKScene?
        /// When it began to show, in scene seconds; nil while it waits its turn.
        var start: Double?

        init(view: View, start: Double? = nil) { self.view = view; self.start = start }
        init(_ cut: Cut) {
            view = cut.view
            texture = SKTexture(cgImage: cut.image)
            region = cut.region
            (from, to) = (cut.from, cut.to)
        }
    }

    /// A photo planned and cut in the background, ready for `Shown`.
    private struct Cut: @unchecked Sendable { // ponytail: CGImage is immutable, so safe to hand across
        let view: View, image: CGImage, region: CGRect, from: SIMD3<Double>, to: SIMD3<Double>
    }

    // SpriteKit leaves a texture uniform undeclared while it's nil, so both start black.
    private let aUniform = SKUniform(name: "u_a", texture: SolarSystem.black), bUniform = SKUniform(name: "u_b", texture: SolarSystem.black)
    private static let black = SKTexture(data: Data(repeating: 0, count: 4), size: CGSize(width: 1, height: 1))
    /// Per view: texel offset x, y, texels per point, and the texture's width and height.
    private let aPlace = SKUniform(name: "u_pa", vectorFloat4: .zero), bPlace = SKUniform(name: "u_pb", vectorFloat4: .zero)
    private let aSize = SKUniform(name: "u_sa", vectorFloat2: [1, 1]), bSize = SKUniform(name: "u_sb", vectorFloat2: [1, 1])
    /// How far the dissolve to `next` has got, and whether each is a photo (1) or a live view showing through (0).
    private let fadeUniform = SKUniform(name: "u_fade", float: 0)
    private let opaqueUniform = SKUniform(name: "u_opaque", vectorFloat2: [1, 1])
    private let captionUniform = SKUniform(name: "u_caption", float: 0)
    private let brightnessUniform = SKUniform(name: "u_brightness", float: 1)

    private var current: Shown?
    private var next: Shown?
    private var loading = false
    private var time = 0.0
    private var lastUpdate: TimeInterval?
    private let caption = SKNode()
    private weak var host: SKView?
    /// Screen pixels per point, for how sharp a photo can be shown. The render test and the desktop are both 2x.
    private let pixelScale = Double(NSScreen.main?.backingScaleFactor ?? 2)

    private var seconds: Double { max(Self.knobs[0].value, Self.fade * 2) }
    /// Holds the motion at this point, 0 to 1, for snapshots of a photo's start or end (`solar.at`).
    private let still = UserDefaults.standard.object(forKey: "solar.at") as? Double

    override func sceneDidLoad() {
        backgroundColor = .black
        let sprite = SKSpriteNode(color: .black, size: size)
        sprite.anchorPoint = .zero
        sprite.zPosition = 1
        sprite.blendMode = .alpha // live views show through where the shader leaves it clear
        sprite.shader = SKShader(source: shaderCommon + Self.shader, uniforms: [
            SKUniform(name: "u_size", vectorFloat2: [Float(size.width), Float(size.height)]),
            aUniform, bUniform, aPlace, bPlace, aSize, bSize, fadeUniform, opaqueUniform, captionUniform, brightnessUniform,
        ])
        addChild(sprite)
        caption.zPosition = 2
        caption.position = CGPoint(x: 44, y: 60)
        caption.alpha = 0
        addChild(caption)
        applyKnobs()
        NotificationCenter.default.addObserver(self, selector: #selector(applyKnobs), name: UserDefaults.didChangeNotification, object: nil)

        // The first view straight away, so the wallpaper never opens on black, then the next in the background.
        guard let first = Self.pickNext(after: nil) else { return }
        var shown = Shown(view: first)
        if first.kind == .live { shown.scene = liveScene(first) } else if let cut = Self.cut(first, size: size, pixelScale: pixelScale, zoom: Self.knobs[1].value) { shown = Shown(cut) }
        shown.start = 0
        show(shown, in: 0)
        current = shown
        showCaption(first)
        if let still { time = still * (seconds + Self.fade) }
    }

    override func didMove(to view: SKView) {
        host = view
        for live in [current?.scene, next?.scene].compactMap({ $0 }) { live.didMove(to: view) }
    }

    @objc private func applyKnobs() {
        brightnessUniform.floatValue = Float(Self.knobs[3].value)
        if Self.knobs[2].value < 0.5 { caption.removeAllActions(); setCaption(0) }
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = frameTime(currentTime, &lastUpdate)
        if still == nil { time += dt }
        for live in [current?.scene, next?.scene].compactMap({ $0 }) { live.update(currentTime) }
        guard let current, let began = current.start else { return }
        place(current, in: 0)
        if next == nil, !loading, time - began > Self.fade { load() }
        guard var next else { return }
        if next.start == nil {
            guard time - began >= seconds else { return }
            next.start = time
            next.scene?.isHidden = false
            self.next = next
            hideCaption()
        }
        place(next, in: 1)
        let fade = min((time - (next.start ?? time)) / Self.fade, 1)
        fadeUniform.floatValue = Float(fade * fade * (3 - 2 * fade))
        guard fade >= 1 else { return }
        // The dissolve is done: the next view becomes the current one.
        if current.scene !== next.scene { current.scene?.removeFromParent() }
        show(next, in: 0)
        fadeUniform.floatValue = 0
        self.current = next
        self.next = nil
        showCaption(next.view)
    }

    /// Picks the next view and cuts its photo in the background, or builds its live scene, hidden until its turn.
    private func load() {
        guard let view = Self.pickNext(after: current?.view) else { return }
        if view.kind == .live {
            var shown = Shown(view: view)
            shown.scene = current?.view.file == view.file ? current?.scene : liveScene(view)
            shown.scene?.isHidden = current?.scene !== shown.scene
            show(shown, in: 1)
            next = shown
            return
        }
        loading = true
        let size = size, scale = pixelScale, zoom = Self.knobs[1].value
        Task { [weak self] in
            let cut = await Task.detached { Self.cut(view, size: size, pixelScale: scale, zoom: zoom) }.value
            guard let self else { return }
            loading = false
            guard let cut else { return }
            let shown = Shown(cut)
            show(shown, in: 1)
            next = shown
        }
    }

    /// A live view's scene, run inside this one: the host passes it each frame and the move to a view.
    private func liveScene(_ view: View) -> SKScene {
        let scene: SKScene = view.body == "The Moon" ? TheMoon(size: size) : TheSun(size: size)
        scene.zPosition = 0
        addChild(scene)
        if let host { scene.didMove(to: host) }
        return scene
    }

    /// Puts a view's texture in slot 0 (showing) or 1 (dissolving in).
    private func show(_ shown: Shown, in slot: Int) {
        (slot == 0 ? aUniform : bUniform).textureValue = shown.texture ?? Self.black
        let size = shown.texture?.size() ?? CGSize(width: 1, height: 1)
        (slot == 0 ? aSize : bSize).vectorFloat2Value = [Float(size.width), Float(size.height)]
        opaqueUniform.vectorFloat2Value[slot] = shown.view.kind == .live ? 0 : 1
        place(shown, in: slot)
    }

    /// Moves a photo along its path: the centre in a straight line, the scale evenly in ratio, over the view's time
    /// and its dissolve out.
    private func place(_ shown: Shown, in slot: Int) {
        guard let texture = shown.texture else { return }
        let u = min(max((time - (shown.start ?? time)) / (seconds + Self.fade), 0), 1)
        let centre = shown.from.xy + (shown.to.xy - shown.from.xy) * u
        let k = shown.from.z * pow(shown.to.z / shown.from.z, u) // points per photo pixel
        let s = Double(texture.size().width) / shown.region.width // texels per photo pixel
        let x = (centre.x - Double(size.width) / 2 / k - shown.region.minX) * s
        let y = (shown.region.maxY - centre.y - Double(size.height) / 2 / k) * s // the texture's rows run bottom up
        (slot == 0 ? aPlace : bPlace).vectorFloat4Value = [Float(x), Float(y), Float(s / k), 0]
    }

    private func showCaption(_ view: View) {
        caption.removeAllChildren()
        guard Self.knobs[2].value > 0.5 else { return }
        let title = SKLabelNode(attributedText: NSAttributedString(string: view.body, attributes: [
            .font: NSFont.systemFont(ofSize: 26, weight: .semibold), .foregroundColor: NSColor(white: 1, alpha: 0.82)]))
        let line = SKLabelNode(attributedText: NSAttributedString(string: liveCaption(view) ?? view.caption, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .regular), .foregroundColor: NSColor(white: 1, alpha: 0.6)]))
        for label in [title, line] {
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .baseline
            caption.addChild(label)
        }
        title.position.y = 24
        caption.run(.sequence([.wait(forDuration: 1.5), .customAction(withDuration: 3) { [weak self] _, t in
            self?.setCaption(Double(t) / 3)
        }]))
    }

    private func hideCaption() {
        let from = Double(caption.alpha)
        caption.run(.customAction(withDuration: 1.5) { [weak self] _, t in self?.setCaption(from * (1 - Double(t) / 1.5)) })
    }

    /// The caption, and the shadow the shader lays behind it so it reads over a bright photo.
    private func setCaption(_ alpha: Double) {
        caption.alpha = CGFloat(alpha)
        captionUniform.floatValue = Float(alpha)
    }

    /// What the live views show today: the Moon's phase is real unless one is picked.
    private func liveCaption(_ view: View) -> String? {
        guard view.body == "The Moon", view.kind == .live, TheMoon.knobs[0].value > 0.5,
              case .choice(let names) = TheMoon.knobs[0].format else { return nil }
        return "\(names[Int(TheMoon.knobs[0].value)]), from the Moon's real maps"
    }

    // MARK: Choosing the next view

    /// The next world and which of its views: the world held in Settings, or a world not seen lately, likelier the
    /// more views it has (up to three times); then that world's next view, in the order of the list, remembered
    /// across launches. `solar.photo` pins one photo by file name, for trying one out.
    nonisolated static func pickNext(after last: View?) -> View? {
        let defaults = UserDefaults.standard
        if let file = defaults.string(forKey: "solar.photo"), let pinned = views.first(where: { $0.file == file }) { return pinned }
        let held = defaults.string(forKey: bodyKey) ?? ""
        let recent = defaults.stringArray(forKey: "solar.recent") ?? []
        let body: String
        if bodies.contains(held) {
            body = held
        } else {
            // Two live views never meet: both show through, so their dissolve would be a double exposure.
            let live = Set(views.filter { $0.kind == .live }.map(\.body))
            let fresh = bodies.filter { !recent.suffix(bodies.count / 2).contains($0) && $0 != last?.body && !(last?.kind == .live && live.contains($0)) }
            let weighted = (fresh.isEmpty ? bodies : fresh).flatMap { b in Array(repeating: b, count: min(views.filter { $0.body == b }.count, 3)) }
            guard let pick = weighted.randomElement() else { return nil }
            body = pick
        }
        let own = views.filter { $0.body == body }
        var seen = defaults.dictionary(forKey: "solar.seen") as? [String: Int] ?? [:]
        var index = seen[body, default: 0] % own.count
        if own.count > 1, own[index].file == last?.file { index = (index + 1) % own.count }
        seen[body] = index + 1
        defaults.set(seen, forKey: "solar.seen")
        defaults.set(Array((recent.filter { $0 != body } + [body]).suffix(bodies.count / 2)), forKey: "solar.recent")
        return own[index]
    }

    // MARK: Framing

    /// Plans a photo's motion for a screen of `size` points and cuts out what it shows, scaled so the widest moment is
    /// one texel to a screen pixel (or the photo's own pixels, if it has fewer): after that it only ever magnifies, so
    /// fine detail like Saturn's ringlets never shimmers. Whole worlds fit 86% of the height, a little smaller and
    /// sharper if the photo is small, and drift halfway toward their focus; close-ups cover the screen and pan all
    /// the way to it. Half zoom in, half out.
    private nonisolated static func cut(_ view: View, size: CGSize, pixelScale: Double, zoom: Double) -> Cut? {
        guard let source = CGImageSourceCreateWithURL(resource(view.file) as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let (w, h) = (Double(image.width), Double(image.height))
        let (sw, sh) = (Double(size.width), Double(size.height))
        let z = view.zoom > 0 ? view.zoom : zoom
        let focus = view.focus * SIMD2(w, h), middle = SIMD2(w, h) / 2
        var wide: Double, tight: Double, fromCentre: SIMD2<Double>, toCentre: SIMD2<Double>
        func jitter(_ k: Double) -> SIMD2<Double> { SIMD2(.random(in: -1...1) * sw, .random(in: -1...1) * sh) * 0.04 / k }
        if view.kind == .closeup {
            wide = max(sw / w, sh / h)
            tight = max(min(wide * z, maxMagnification / pixelScale), wide)
            // Inside the photo at scale k: the centre can't come nearer an edge than half the screen.
            func inside(_ c: SIMD2<Double>, _ k: Double) -> SIMD2<Double> {
                simd_clamp(c, SIMD2(sw, sh) / (2 * k), SIMD2(w, h) - SIMD2(sw, sh) / (2 * k))
            }
            toCentre = inside(focus, tight)
            fromCentre = inside(middle * 2 - focus + jitter(wide), wide) // from the far side, so a wide photo pans across
        } else {
            wide = min(0.86 * sh / h, 0.94 * sw / w)
            tight = min(wide * z, maxMagnification / pixelScale)
            wide = tight / z
            toCentre = middle + (focus - middle) * 0.5 // only halfway, so the world stays whole and near the middle
            fromCentre = middle + jitter(wide)
        }
        var from: SIMD3<Double> = [fromCentre.x, fromCentre.y, wide], to: SIMD3<Double> = [toCentre.x, toCentre.y, tight]
        if Bool.random() { swap(&from, &to) }

        // Only the part of the photo the motion ever shows: the two ends' views cover everything between.
        func seen(_ f: SIMD3<Double>) -> CGRect {
            CGRect(x: f.x - sw / 2 / f.z, y: f.y - sh / 2 / f.z, width: sw / f.z, height: sh / f.z)
        }
        let region = seen(from).union(seen(to)).insetBy(dx: -4, dy: -4).integral
            .intersection(CGRect(x: 0, y: 0, width: w, height: h))
        let s = min(wide * pixelScale, 1) // texels per photo pixel
        let (tw, th) = (max(Int((region.width * s).rounded(.up)), 1), max(Int((region.height * s).rounded()), 1))
        guard !region.isEmpty, let part = image.cropping(to: region),
              let context = CGContext(data: nil, width: tw, height: th, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        context.interpolationQuality = .high
        context.draw(part, in: CGRect(x: 0, y: 0, width: tw, height: th))
        guard let cutImage = context.makeImage() else { return nil }
        return Cut(view: view, image: cutImage, region: CGRect(x: region.minX, y: region.minY, width: Double(tw) / s, height: Double(th) / s),
                   from: from, to: to)
    }

    /// Both views, each sampled with Catmull-Rom in nine bilinear taps (Sigg and Hadwiger's trick), which stays sharp
    /// as the photo slowly magnifies where plain bilinear would blur and pulse; black outside each photo. Live views
    /// leave their part clear. A soft shadow sits behind the caption.
    private static let shader = """
    vec3 crTaps(float t) { // the three tap positions along one axis, in texels
        float c = floor(t - 0.5) + 0.5, f = t - c;
        float w1 = 1.0 + f * f * (-2.5 + 1.5 * f), w2 = f * (0.5 + f * (2.0 - 1.5 * f));
        return vec3(c - 1.0, c + w2 / (w1 + w2), c + 2.0);
    }
    vec3 crWeights(float t) {
        float f = t - floor(t - 0.5) - 0.5;
        return vec3(f * (-0.5 + f * (1.0 - 0.5 * f)), 1.0 + f * f * (-2.5 + 1.5 * f) + f * (0.5 + f * (2.0 - 1.5 * f)),
                    f * f * (-0.5 + 0.5 * f));
    }
    float insideOf(vec2 t, vec2 size) { return step(0.0, t.x) * step(0.0, t.y) * step(t.x, size.x) * step(t.y, size.y); }

    void main() {
        vec2 pts = v_tex_coord * u_size;
        vec2 ta = u_pa.xy + pts * u_pa.z;
        vec3 px = crTaps(ta.x) / u_sa.x, py = crTaps(ta.y) / u_sa.y, wx = crWeights(ta.x), wy = crWeights(ta.y);
        vec3 a = (texture2D(u_a, vec2(px.x, py.x)).rgb * wx.x + texture2D(u_a, vec2(px.y, py.x)).rgb * wx.y + texture2D(u_a, vec2(px.z, py.x)).rgb * wx.z) * wy.x
               + (texture2D(u_a, vec2(px.x, py.y)).rgb * wx.x + texture2D(u_a, vec2(px.y, py.y)).rgb * wx.y + texture2D(u_a, vec2(px.z, py.y)).rgb * wx.z) * wy.y
               + (texture2D(u_a, vec2(px.x, py.z)).rgb * wx.x + texture2D(u_a, vec2(px.y, py.z)).rgb * wx.y + texture2D(u_a, vec2(px.z, py.z)).rgb * wx.z) * wy.z;
        a *= insideOf(ta, u_sa);
        vec3 b = vec3(0.0);
        if (u_fade > 0.0) {
            vec2 tb = u_pb.xy + pts * u_pb.z;
            px = crTaps(tb.x) / u_sb.x; py = crTaps(tb.y) / u_sb.y; wx = crWeights(tb.x); wy = crWeights(tb.y);
            b = (texture2D(u_b, vec2(px.x, py.x)).rgb * wx.x + texture2D(u_b, vec2(px.y, py.x)).rgb * wx.y + texture2D(u_b, vec2(px.z, py.x)).rgb * wx.z) * wy.x
              + (texture2D(u_b, vec2(px.x, py.y)).rgb * wx.x + texture2D(u_b, vec2(px.y, py.y)).rgb * wx.y + texture2D(u_b, vec2(px.z, py.y)).rgb * wx.z) * wy.y
              + (texture2D(u_b, vec2(px.x, py.z)).rgb * wx.x + texture2D(u_b, vec2(px.y, py.z)).rgb * wx.y + texture2D(u_b, vec2(px.z, py.z)).rgb * wx.z) * wy.z;
            b *= insideOf(tb, u_sb);
        }
        float oa = u_opaque.x * (1.0 - u_fade), ob = u_opaque.y * u_fade;
        vec3 col = max(a, 0.0) * oa + max(b, 0.0) * ob; // premultiplied: a live view shows through the rest
        float alpha = oa + ob;
        col *= u_brightness;
        vec2 fromCaption = (pts - vec2(150.0, 70.0)) / vec2(260.0, 90.0);
        float shade = u_caption * 0.45 * exp(-dot(fromCaption, fromCaption));
        col *= 1.0 - shade;
        alpha = max(alpha, shade);
        col += (hash21(pts * 2.0) - 0.5) / 255.0 * alpha;
        gl_FragColor = vec4(max(col, 0.0), alpha);
    }
    """
}

private extension SIMD3 where Scalar == Double {
    var xy: SIMD2<Double> { SIMD2(x, y) }
}

extension Knob {
    /// The same knob under another Settings section, for a scene shown inside another wallpaper.
    func `in`(_ section: String) -> Knob { var knob = self; knob.section = section; return knob }
}
