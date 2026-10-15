import SpriteKit
import RailLayout

@MainActor func pixelRailway(size: CGSize) -> SKScene { PixelRailway(size: size) }

/// Pixel Railway: a model railway seen from above in pixel art, one to three trains of one era running on their
/// loops through the countryside, under the real Sun and, if Settings has it, the real snow where you are. A new
/// layout fades in every few hours. The layout, its scenery and the drawing are in the RailLayout module
/// (docs/pixel-railway.md); this is the canvas, the clock and Settings.
final class PixelRailway: SKScene {
    nonisolated static let look = Knob(key: "railway.view", label: "View", range: 0...1, standard: 0, section: "Layout",
                                       format: .choice(["Top-down", "Isometric"]))
    nonisolated static let scale = Knob(key: "railway.size", label: "Size", range: 0...2, standard: 1, section: "Layout",
                                        format: .choice(["Small", "Medium", "Large"]))
    nonisolated static let count = Knob(key: "railway.trains", label: "Trains", range: 0...2, standard: 2, section: "Layout",
                                        format: .choice(["One", "Up to two", "Up to three"]))
    nonisolated static let every = Knob(key: "railway.every", label: "New layout every", range: 0...3, standard: 1, section: "Layout",
                                        format: .choice(["Hour", "3 hours", "6 hours", "Day"]))
    nonisolated static let streamliners = Knob(key: "railway.streamliners", label: "US streamliners: Santa Fe, Union Pacific, Great Northern",
                                               range: 0...1, standard: 1, section: "Eras", format: .toggle)
    nonisolated static let steam = Knob(key: "railway.steam", label: "US steam: Union Pacific Big Boy, Southern Pacific Daylight, Milwaukee Road Hiawatha",
                                        range: 0...1, standard: 1, section: "Eras", format: .toggle)
    nonisolated static let snow = Knob(key: "railway.snow", label: "Snow on the ground when there's snow where you are", range: 0...1, standard: 1,
                                       section: "Seasons", format: .toggle)
    nonisolated static let previewSnow = Knob(key: "railway.previewSnow", label: "Preview snow", range: 0...1, standard: 0, section: "Preview", format: .toggle)
    nonisolated static let previewTime = Knob(key: "railway.previewTime", label: "Preview a time of day", range: 0...1, standard: 0, section: "Preview",
                                              format: .toggle)
    nonisolated static let previewHour = Knob(key: "railway.previewHour", label: "Time", range: 0...24, standard: 21, section: "Preview", format: .clock,
                                              shownWhen: "railway.previewTime")
    nonisolated static let knobs = [look, scale, count, every, streamliners, steam, snow, previewSnow, previewTime, previewHour]
    /// Under the eras in Settings, the only place the railroads are named.
    nonisolated static let names = (section: "Eras", text: "Names say which real train each is drawn after. Atrium isn't affiliated with or endorsed by any railroad.")

    /// What a layout is built from: everything that, changed, makes a new one.
    struct Plan: Equatable {
        var seed: Int, w: Int, h: Int, pixel: CGFloat, view: RailViewKind, era: RailEra, trains: [String], winter: Bool
    }

    private let plan: Plan
    private let railway: Railway
    private let texture: SKMutableTexture
    private var pixels: [UInt32]
    private var night: Float = 0, litAt = Date.distantPast, checkedAt = Date()
    private var last: TimeInterval?
    private var building = false, retired = false

    override convenience init(size: CGSize) {
        let plan = Self.plan(size)
        self.init(size: size, plan: plan, railway: Self.build(plan))
    }

    init(size: CGSize, plan: Plan, railway: Railway) {
        (self.plan, self.railway) = (plan, railway)
        texture = SKMutableTexture(size: CGSize(width: plan.w, height: plan.h))
        texture.filteringMode = .nearest
        pixels = Array(repeating: 0, count: plan.w * plan.h)
        super.init(size: size)
        let canvas = SKSpriteNode(texture: texture, size: CGSize(width: CGFloat(plan.w) * plan.pixel, height: CGFloat(plan.h) * plan.pixel))
        canvas.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(canvas)
        night = nightNow()
        litAt = Date()
        paint()
        NotificationCenter.default.addObserver(self, selector: #selector(changed), name: UserDefaults.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(changed), name: LiveWeather.changed, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func didMove(to view: SKView) {
        Location.shared.start()
        run(.repeatForever(.sequence([.run { if Self.snow.value > 0.5 { LiveWeather.shared.poll() } }, .wait(forDuration: 900)])))
    }

    /// The layout for now: a new seed each period of Settings' New Layout Every, an era from those ticked, and the
    /// trains of that era, at the size Settings picks (Medium is Pixel City's pixel).
    static func plan(_ size: CGSize, at date: Date = Date()) -> Plan {
        let pixel = max(2, (size.height / 240).rounded()) + CGFloat(scale.value) - 1 // points per art pixel
        let hours = [1.0, 3, 6, 24][Int(every.value)]
        let seed = Int(date.timeIntervalSince1970 / (hours * 3600))
        let ticked = [(streamliners, RailEra.streamliners), (steam, .steam)].filter { $0.0.value > 0.5 }.map(\.1)
        let eras = ticked.isEmpty ? RailEra.allCases : ticked
        let era = eras[Int((UInt64(truncatingIfNeeded: seed) &* 0x9E37_79B9_7F4A_7C15) >> 33) % eras.count]
        let snowing = (LiveWeather.shared.latest?.snowDepth ?? 0) > 0.01 && snow.value > 0.5
        return Plan(seed: seed, w: Int((size.width / pixel).rounded(.up)), h: Int((size.height / pixel).rounded(.up)), pixel: pixel,
                    view: look.value > 0.5 ? .iso : .topDown, era: era, trains: Railway.pick(era, count: Int(count.value) + 1, seed: seed),
                    winter: previewSnow.value > 0.5 || snowing)
    }

    nonisolated static func build(_ plan: Plan) -> Railway {
        Railway(seed: plan.seed, width: plan.w, height: plan.h, view: plan.view, era: plan.era, trains: plan.trains, winter: plan.winter)
    }

    /// How dark it is, 0 by day to 1 at night, by the Sun where you are, or at the preview hour.
    private func nightNow() -> Float {
        let date = Self.previewTime.value > 0.5 ? Calendar.current.startOfDay(for: Date()).addingTimeInterval(Self.previewHour.value * 3600) : Date()
        let here = Location.shared.coordinate, jd = Sky.julianDate(date)
        let up = normalize(Sky.horizonMatrix(jd: jd, latitude: here.latitude, longitude: here.longitude) * Sky.sun(jd)).z
        return smoothstep(4, -8, Float(asin(min(max(up, -1), 1)) * 180 / .pi))
    }

    /// A setting or the weather changed: a new time of day shows at once; anything that makes another layout
    /// fades to it.
    @objc private func changed() {
        night = nightNow()
        rebuildIfNeeded()
    }

    /// Builds the layout for now off the main thread if it isn't the one showing, then fades to it.
    private func rebuildIfNeeded() {
        let next = Self.plan(size)
        guard next != plan, !building, !retired, view != nil else { return }
        building = true
        Task { [weak self] in
            let railway = await Task.detached(priority: .utility) { Self.build(next) }.value
            guard let self, !self.retired, let view = self.view, view.scene === self, Self.plan(self.size) == next else { self?.building = false; return }
            let scene = PixelRailway(size: self.size, plan: next, railway: railway)
            scene.scaleMode = self.scaleMode
            let fade = SKTransition.crossFade(withDuration: 2)
            fade.pausesIncomingScene = false
            fade.pausesOutgoingScene = false
            self.retired = true
            view.presentScene(scene, transition: fade)
        }
    }

    override func update(_ currentTime: TimeInterval) {
        railway.advance(frameTime(currentTime, &last))
        if Date().timeIntervalSince(litAt) > 30 { night = nightNow(); litAt = Date() }
        if Date().timeIntervalSince(checkedAt) > 5 { checkedAt = Date(); rebuildIfNeeded() } // a new period's layout
        paint()
    }

    private func paint() {
        pixels.withUnsafeMutableBufferPointer { railway.draw(night: night, into: $0) }
        pixels.withUnsafeBytes { buffer in
            nonisolated(unsafe) let bytes = buffer
            texture.modifyPixelData { data, length in data?.copyMemory(from: bytes.baseAddress!, byteCount: min(length, bytes.count)) }
        }
    }
}

extension Railway: @unchecked Sendable {} // built off the main thread, then only ever used on it
