import SpriteKit
import RailLayout

@MainActor func pixelRailway(size: CGSize) -> SKScene { PixelRailway(size: size) }

/// Pixel Railway: a model railway in isometric pixel art, one to three trains of one era running on their
/// loops through the countryside, under the real Sun and, if Settings has it, the real snow where you are. A new
/// layout fades in every few hours. The layout, its scenery and the drawing are in the RailLayout module
/// (docs/pixel-railway.md); this is the canvas, the clock and Settings.
final class PixelRailway: SKScene {
    nonisolated static let count = Knob(key: "railway.trains", label: "Trains", range: 0...2, standard: 2, section: "Layout",
                                        format: .choice(["One", "Up to two", "Up to three"]))
    nonisolated static let every = Knob(key: "railway.every", label: "New layout every", range: 0...3, standard: 1, section: "Layout",
                                        format: .choice(["Hour", "3 hours", "6 hours", "Day"]))
    nonisolated static let swaps = Knob(key: "railway.swaps", label: "A train leaves and another comes", range: 0...3, standard: 1, section: "Layout",
                                        format: .choice(["Never", "Often", "Every few minutes", "Now and then"]))
    nonisolated static let mix = Knob(key: "railway.mix", label: "Trains come from every era ticked, not only the layout's", range: 0...1, standard: 1,
                                      section: "Eras", format: .toggle)
    nonisolated static let streamliners = Knob(key: "railway.streamliners", label: "US streamliners: Santa Fe, Union Pacific, Great Northern",
                                               range: 0...1, standard: 1, section: "Eras", format: .toggle)
    nonisolated static let steam = Knob(key: "railway.steam", label: "US steam: Union Pacific Big Boy, Southern Pacific Daylight, Milwaukee Road Hiawatha",
                                        range: 0...1, standard: 1, section: "Eras", format: .toggle)
    nonisolated static let transition = Knob(key: "railway.transition",
                                             label: "US transition freight: Union Pacific, Santa Fe, Pennsylvania, New York Central, Norfolk and Western",
                                             range: 0...1, standard: 1, section: "Eras", format: .toggle)
    nonisolated static let modern = Knob(key: "railway.modern", label: "US today: BNSF, Union Pacific, CSX, Amtrak", range: 0...1, standard: 1,
                                         section: "Eras", format: .toggle)
    nonisolated static let britishSteam = Knob(key: "railway.britishSteam",
                                               label: "Britain, age of steam: LNER A3 and A4, GWR Castle, LMS Coronation and 8F",
                                               range: 0...1, standard: 1, section: "Eras", format: .toggle)
    nonisolated static let britishDiesel = Knob(key: "railway.britishDiesel", label: "British InterCity: HST, Deltic, Class 47",
                                                range: 0...1, standard: 1, section: "Eras", format: .toggle)
    nonisolated static let germanAlps = Knob(key: "railway.germanAlps",
                                             label: "Germany and the Alps: DB 103 with the TEE Rheingold, V 200, class 01, SBB Crocodile",
                                             range: 0...1, standard: 1, section: "Eras", format: .toggle)
    nonisolated static let snow = Knob(key: "railway.snow", label: "Snow on the ground when there's snow where you are", range: 0...1, standard: 1,
                                       section: "Seasons", format: .toggle)
    nonisolated static let previewSnow = Knob(key: "railway.previewSnow", label: "Preview snow", range: 0...1, standard: 0, section: "Preview", format: .toggle)
    nonisolated static let previewDay = Knob(key: "railway.previewDay", label: "Preview a day of the year", range: 0...1, standard: 0, section: "Preview",
                                             format: .toggle)
    nonisolated static let day = Knob(key: "railway.day", label: "Day", range: 0...364, standard: 290, section: "Preview", format: .date,
                                      shownWhen: "railway.previewDay")
    nonisolated static let previewTime = Knob(key: "railway.previewTime", label: "Preview a time of day", range: 0...1, standard: 0, section: "Preview",
                                              format: .toggle)
    nonisolated static let previewHour = Knob(key: "railway.previewHour", label: "Time", range: 0...24, standard: 21, section: "Preview", format: .clock,
                                              shownWhen: "railway.previewTime")
    nonisolated static let knobs = [count, every, swaps, streamliners, steam, transition, modern, britishSteam, britishDiesel, germanAlps, mix, snow, previewDay, day, previewSnow, previewTime, previewHour]
    /// Settings' New Layout Now: every copy moves on to another layout at once, by a count added to the period's seed,
    /// and keeps it until the period's up.
    static let newLayout: (section: String, title: String, run: @MainActor () -> Void) = ("Layout", "New Layout Now", {
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: "railway.reroll") + 1, forKey: "railway.reroll")
    })
    /// Under the eras in Settings, the only place the railroads are named.
    nonisolated static let names = (section: "Eras", text: "Names say which real train each is drawn after. Atrium isn't affiliated with or endorsed by any railroad.")

    /// What a layout is built from: everything that, changed, makes a new one.
    struct Plan: Equatable {
        var seed: Int, w: Int, h: Int, pixel: CGFloat, era: RailEra, count: Int, season: RailSeason
        /// How many seconds between swaps (nil: none), and the eras arrivals come from.
        var swaps: ClosedRange<Double>?, eras: [RailEra]
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
    /// trains of that era, its art pixel one point smaller than Pixel City's (3 points on a 982-point-high screen), so
    /// there's room for long loops. `RAILWAY_SEED=` and `RAILWAY_ERA=` in the environment pin the layout, for the
    /// README's and the website's pictures.
    static func plan(_ size: CGSize, at date: Date = Date()) -> Plan {
        let pixel = max(2, (size.height / 240).rounded()) - 1 // points per art pixel
        let hours = [1.0, 3, 6, 24][Int(every.value)], pinned = ProcessInfo.processInfo.environment
        let seed = pinned["RAILWAY_SEED"].flatMap(Int.init)
            ?? Int(date.timeIntervalSince1970 / (hours * 3600)) &+ UserDefaults.standard.integer(forKey: "railway.reroll") &* 7919
        let ticked = [(streamliners, RailEra.streamliners), (steam, .steam), (transition, .transition), (modern, .modern), (britishSteam, .britishSteam),
                      (britishDiesel, .britishDiesel), (germanAlps, .germanAlps)].filter { $0.0.value > 0.5 }.map(\.1)
        let eras = ticked.isEmpty ? RailEra.allCases : ticked
        let era = pinned["RAILWAY_ERA"].flatMap { e in RailEra.allCases.first { "\($0)" == e } }
            ?? eras[Int((UInt64(truncatingIfNeeded: seed) &* 0x9E37_79B9_7F4A_7C15) >> 33) % eras.count]
        return Plan(seed: seed, w: Int((size.width / pixel).rounded(.up)), h: Int((size.height / pixel).rounded(.up)), pixel: pixel,
                    era: era, count: Int(count.value) + 1, season: season(date), swaps: [nil, 40...90, 120...180, 300...420][Int(swaps.value)],
                    eras: mix.value > 0.5 ? eras : [era])
    }

    /// The time of year where you are, or on the previewed day: A Tree for the Year's oak, moved for your latitude,
    /// and its grass; snow where the weather says a centimetre or more lies, or while previewing it. Whole days,
    /// so the leaves turn and fall a day at a time.
    static func season(_ date: Date) -> RailSeason {
        // to the nearest degree: each location fix comes back a few metres different, and the exact latitude moves the
        // oak's dates by a fraction of a day, which made every new scene's fix look like a new season and rebuild it
        // ponytail: a fix wobbling across a half degree could still flip it, once
        let latitude = Location.shared.coordinate.latitude.rounded()
        let when = previewDay.value > 0.5 ? Calendar.current.startOfDay(for: Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: date)))!)
            .addingTimeInterval(day.value * 86400 + 43200) : date
        let oak = Phenology.whiteOak.moved(latitude: latitude, warmer: 0), d = Phenology.day(when, latitude: latitude).rounded(.down)
        let snowing = snow.value > 0.5 && (LiveWeather.shared.latest?.snowDepth ?? 0) > 0.01
        return RailSeason(day: d, breaks: oak.breaks, full: oak.full, onset: oak.onset, peak: oak.peak, bare: oak.bare,
                          green: TreeScene.greenness(day: d, oak), snow: previewSnow.value > 0.5 || snowing)
    }

    nonisolated static func build(_ plan: Plan) -> Railway {
        Railway(seed: plan.seed, width: plan.w, height: plan.h, era: plan.era, count: plan.count, season: plan.season, swaps: plan.swaps,
                eras: plan.eras, mix: plan.eras.count > 1)
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
