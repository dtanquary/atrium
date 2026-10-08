import SpriteKit

// Rain on Glass following the weather: what the weather where you are does to a real window, from the live report
// (`LiveWeather`) and the physics of wet glass. The numbers and their sources are in docs/rain-on-glass.md.

/// On, the glass follows the weather where you are; off, it rains steadily, as it always has.
let rainFollow = Knob(key: "rain.weather", label: "Follow the weather", range: 0...1, standard: 0, section: "Weather", format: .toggle)
/// Which window: fog and frost form on the outside of double glazing, but on the inside of a single pane, which
/// the room keeps humid and the cold outside keeps cold.
let rainWindow = Knob(key: "rain.window", label: "Window", range: 0...1, standard: 0, section: "Weather",
                      format: .choice(["Double glazed", "Single pane"]), shownWhen: "rain.weather")
/// Each state by hand, to see frost or fog without waiting for the weather. Rain 1× is the steady rain.
let rainPreview = [
    Knob(key: "rain.preview", label: "Preview the weather", range: 0...1, standard: 0, section: "Preview", format: .toggle),
    Knob(key: "rain.previewRain", label: "Rain", range: 0...1.6, standard: 1, section: "Preview", format: .times, shownWhen: "rain.preview"),
    Knob(key: "rain.previewFog", label: "Fog", range: 0...1, standard: 0, section: "Preview", shownWhen: "rain.preview"),
    Knob(key: "rain.previewFrost", label: "Frost", range: 0...1, standard: 0, section: "Preview", shownWhen: "rain.preview"),
    Knob(key: "rain.previewSnow", label: "Snow", range: 0...1, standard: 0, section: "Preview", shownWhen: "rain.preview"),
]

/// What the weather outside is doing to the window. Every copy of the scene (each display, and Settings) shares
/// it, so they agree, and it lives across rebuilds and relaunches, since frost takes hours to grow.
@MainActor final class GlassWeather {
    static let shared = GlassWeather()

    /// What the scene draws.
    struct Glass: Equatable {
        /// Rain arriving on the glass, 1 being the steady rain the scene was made for, and what it was until it
        /// last changed, at `changed`.
        var rain = 1.0, before = 1.0, changed = Date.distantPast
        /// Once the rain has stopped, how far the drops left have dried, in mm² of diameter: a drop of d mm is gone
        /// at d² (research 4).
        var dried = 0.0
        /// When the sliders stopped, because the rain stopped or the glass froze; nil while they run.
        var stopped: Date?
        /// Drizzle mist on the outside, 0.3 in steady rain, and whether it's drizzle: fine beads that seldom run.
        var mist = 0.3, drizzle = false
        /// Condensation: the water fogging the pane, g/m². A veil at 0.05, white by 0.5, beads you can see
        /// from about 20, runners at 200.
        var water = 0.0
        /// Fern frost grown across the pane (0…1), and the share of drops frozen.
        var frost = 0.0, frozen = 0.0
        /// Snow arriving, 1 being moderate snow; how long a flake takes to melt, in seconds per mg of it (0 when
        /// the glass is freezing and flakes stay); and how big flakes are, in mm across.
        var snow = 0.0, melt = 0.0, flake = 5.0
        /// The glass's temperature, °C, and whether fog and frost are on the inside of the pane.
        var glass = 10.0, inside = false
        /// How wet the frost is as it melts, 0-1: grey and clear rather than white.
        var melting = 0.0

        /// What the shader needs compiled in for this state (see `GlassUniforms`): the rain and its drops, the
        /// rain's last change for 5 minutes after it (by then every bead has landed and every slider slid in since),
        /// drying once it stops, then fog, dew, snow and frost as they come.
        var features: Set<String> {
            var needs: Set<String> = ["WEATHER"]
            if rain > 0 || (before > 0 && dried < 16) || frozen > 0 { needs.insert("WATER") }
            if rain == 0 || (rain != before && abs(Date().timeIntervalSince(changed)) < 300) { needs.insert("CHANGE") }
            if rain == 0 { needs.insert("DRY") }
            if water > 0.02 { needs.insert("FOG") }
            if water > 40 { needs.insert("DEW") }
            if snow > 0 { needs.insert("SNOW") }
            if frost > 0 || frozen > 0 { needs.insert("FROST") }
            return needs
        }
    }

    /// Which frost pattern grows, kept until the frost has all melted so it doesn't jump as scenes rebuild. 53 bits,
    /// so it saves exactly as a Double.
    private(set) var frostSeed = UInt64.random(in: 0..<(1 << 53))

    /// The live state, advanced by `advance()` from the live report.
    private var live = Glass()
    private var report: LiveWeather.Conditions?, reported = Date()
    /// The rain easing toward what's falling; the drops get it in steps (`Glass.rain`).
    private var flowing = 1.0
    private var last: Date?, lastSave = Date.distantPast, primed = false
    /// The preview's rain changes, so drops dry when the preview's rain is turned off.
    private var preview = Glass()

    private init() {
        NotificationCenter.default.addObserver(forName: LiveWeather.changed, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { (GlassWeather.shared.report, GlassWeather.shared.reported) = (LiveWeather.shared.latest, Date()) }
        }
        report = LiveWeather.shared.latest
        restore()
    }

    /// What the glass shows now: Settings' preview if it's on, else the live weather.
    var now: Glass { rainPreview[0].value > 0.5 ? preview : live }

    /// Brings the state up to now. Every scene calls this every second or so; it steps by the time since the last
    /// call, whoever made it.
    func advance() {
        let date = Date()
        let dt = min(date.timeIntervalSince(last ?? date), 3600) // a sleeping Mac catches up at most an hour
        last = date
        if rainPreview[0].value > 0.5 { stepPreview(dt, date) } else { stepLive(dt, date) }
    }

    // MARK: - Preview

    private func stepPreview(_ dt: Double, _ date: Date) {
        func knob(_ name: String) -> Double { rainPreview.first { $0.key == "rain.preview" + name }?.value ?? 0 }
        var glass = preview
        let frost = knob("Frost")
        glass.frost = frost
        glass.frozen = frost > 0 ? 1 : 0
        let rain = frost > 0 ? 0 : knob("Rain") // frozen glass: the drops left freeze in place
        if rain != glass.rain {
            (glass.before, glass.rain, glass.changed, glass.dried) = (glass.rain, rain, date, 0)
            glass.stopped = rain == 0 ? date : nil
        }
        if rain == 0, glass.frozen == 0 { glass.dried += Self.drying(glass: 12, dewPoint: 8, wind: 2) * dt }
        glass.mist = 0.3 * min(rain, 1)
        let fog = knob("Fog")
        glass.water = fog > 0 ? 0.05 * pow(4000, fog) : 0   // 0.25 white, 0.75 beads, 1 runners
        glass.snow = knob("Snow")
        glass.melt = frost > 0 ? 0 : 17 / 2.0
        glass.flake = frost > 0 ? 3 : 5
        glass.glass = frost > 0 ? -4 : 3
        glass.melting = 0
        glass.inside = rainWindow.value > 0.5
        preview = glass
    }

    // MARK: - Live

    private func stepLive(_ dt: Double, _ date: Date) {
        guard let report else {
            let failed = UserDefaults.standard.string(forKey: "weather.status").flatMap { $0.hasPrefix("Couldn't") ? $0 : nil }
            status(failed ?? "Waiting for the live weather…")
            return
        }
        let single = rainWindow.value > 0.5
        var glass = live
        glass.inside = single

        // the glass follows its steady temperature with the pane's thermal lag, starting there on the first report
        let sun = Self.sunlight(at: date)
        let settled = Self.glassTemperature(air: report.temperature, dewPoint: report.dewPoint, cloud: report.cloudCover / 100,
                                            wind: report.wind / 3.6, sunlight: sun, singlePane: single)
        glass.glass += (settled - glass.glass) * (primed ? 1 - exp(-dt / 900) : 1)
        primed = true
        let freezing = glass.glass < 0

        // rain and snow arriving: Open-Meteo's amounts are for the last 15 minutes. Showers come and go within
        // minutes, which those hide, so they're made up around the reported mean. The rain eases over a few
        // minutes, in steps the drops can follow (see beadLayer), and stops outright.
        let wet = (report.rain + report.showers) * 4, snowing = report.snowfall * 4
        let showery = report.showers > report.rain || report.code >= 80
        let target = freezing ? 0 : Self.rainAmount(mmPerHour: wet * (showery ? Self.shower(date) : 1), wind: report.wind / 3.6, code: report.code)
        flowing = target == 0 ? 0 : flowing == 0 ? max(target * 0.3, 0.15) : flowing + (target - flowing) * (1 - exp(-dt / 180))
        let rain = flowing < 0.05 ? 0 : abs(flowing - glass.rain) > 0.03 ? flowing : glass.rain
        if rain != glass.rain { (glass.before, glass.rain, glass.changed, glass.dried) = (glass.rain, rain, date, 0) }
        glass.stopped = rain > 0 ? nil : glass.stopped ?? glass.changed
        glass.drizzle = (51...57).contains(report.code) || (wet < 1 && report.showers == 0)
        glass.mist = 0.3 * min(rain, 1) * (glass.drizzle ? 1.5 : 1)
        glass.snow = Self.snowAmount(cmPerHour: snowing, wind: report.wind / 3.6)
        glass.melt = freezing ? 0 : 17 / max(glass.glass, 0.3)
        glass.flake = Self.flakeSize(air: report.temperature)

        // fog: water condensing on (or drying off) the side of the glass that's colder than the air's dew point
        let air = single ? Self.indoorDewPoint(outside: report.temperature, dewPoint: report.dewPoint) : report.dewPoint
        let breeze = single ? 3.0 : max(3, 4 + report.wind / 3.6)
        let flux = breeze / 1200 * (Self.vapour(air) - Self.vapour(glass.glass, overIce: freezing)) // g/m²/s
        if freezing {
            // frost: vapour deposits as ice on glass below its frost point, the ferns covering the pane in no less
            // than 2 hours however much vapour there is (the crystals only grow so fast); drier air sublimes them,
            // slowly. Drops supercool, then freeze one after another over a couple of minutes once the glass is
            // below −1 °C.
            glass.frost = min(max(glass.frost + min(flux / Self.frostWater, 1 / 7200) * dt, 0), 1)
            if glass.glass < -1 { glass.frozen = min(glass.frozen + dt / 120, 1) }
            glass.water = max(glass.water + min(flux, 0) * dt, 0)
            glass.melting = 0
        } else {
            // above freezing the frost melts, last grown first, in minutes: 13 at +1 °C, 6 at +5
            glass.water = min(max(glass.water + flux * dt, 0), 200)
            glass.melting = glass.frost > 0 ? 1 : 0
            glass.frost = max(glass.frost - (1 + glass.glass / 2) * 3 / 3600 * dt, 0)
            glass.frozen = max(glass.frozen - dt / 60, 0)
            if glass.frost == 0, glass.frozen == 0, live.frost > 0 || live.frozen > 0 { frostSeed = .random(in: 0..<(1 << 53)) } // a new pattern next time
            if rain == 0, glass.frozen == 0 {
                glass.dried += Self.drying(glass: glass.glass, dewPoint: report.dewPoint, wind: report.wind / 3.6) * dt
            }
        }
        live = glass
        status(describe(report, glass, fogging: flux > 0))
        if date.timeIntervalSince(lastSave) > 60 { save(date) }
    }

    /// The live report and what it's doing to the glass, for Settings: "Live: 3 °C, dew point 1 °C, 0.8 mm/h of
    /// rain, 100% cloud · the glass is 3 °C: rain · updated 8:44 PM".
    private func describe(_ report: LiveWeather.Conditions, _ glass: Glass, fogging: Bool) -> String {
        var weather = [String(format: "%.0f °C, dew point %.0f °C", report.temperature, report.dewPoint)]
        let wet = (report.rain + report.showers) * 4, snow = report.snowfall * 4
        if wet > 0 { weather.append(String(format: "%.1f mm/h of rain", wet)) }
        if snow > 0 { weather.append(String(format: "%.1f cm/h of snow", snow)) }
        weather.append("\(Int(report.cloudCover.rounded()))% cloud")
        var on = [String]()
        if glass.rain > 0 { on.append("rain") } else if glass.before > 0, glass.dried < 16, glass.frozen == 0 { on.append("drops drying") }
        if glass.water > 0.05 { on.append(glass.water > 20 ? "dew" : fogging ? "fogging" : "clearing") }
        if glass.frost > 0.005 { on.append(glass.glass < 0 ? "frost growing" : "frost melting") }
        if glass.frozen > 0.5 { on.append("frozen drops") }
        if glass.snow > 0 { on.append(glass.melt > 0 ? "snow melting" : "snow") }
        return "Live: " + weather.joined(separator: ", ") + String(format: " · the glass is %.0f °C", glass.glass)
            + (on.isEmpty ? ", dry" : ": " + on.joined(separator: ", ")) + " · updated "
            + reported.formatted(date: .omitted, time: .shortened)
    }

    /// Settings' status line, written only when it changes: each write tells every scene that settings changed.
    private func status(_ text: String) {
        if UserDefaults.standard.string(forKey: "rain.status") != text { UserDefaults.standard.set(text, forKey: "rain.status") }
    }

    // MARK: - Physics

    /// Saturation vapour density over water, or over ice below 0 °C, g/m³ (Magnus, WMO 2008).
    nonisolated static func vapour(_ t: Double, overIce: Bool = false) -> Double {
        let e = overIce ? 611.2 * exp(22.46 * t / (272.62 + t)) : 611.2 * exp(17.62 * t / (243.12 + t)) // Pa
        return 1000 * e / (461.5 * (t + 273.15))
    }

    /// The glass's temperature once it settles, °C: the outside of a double glazed low-e pane, which radiates to
    /// the sky (a clear night takes it 2 °C below the air) and gets a little warmth from the room and the Sun; or
    /// the inside of a single pane, a quarter of the way from the cold outside to the room (research 1a and 1b).
    nonisolated static func glassTemperature(air: Double, dewPoint: Double, cloud: Double, wind: Double, sunlight: Double,
                                             singlePane: Bool) -> Double {
        if singlePane { return air + 0.25 * (20 - air) + 0.2 * sunlight }
        let clear = 0.711 + 0.56 * dewPoint / 100 + 0.73 * pow(dewPoint / 100, 2)       // Martin & Berdahl
        let sky = clear + (1 - clear) * 0.9 * min(max(cloud, 0), 1)
        let radiated = 0.5 * 0.84 * 5.67e-8 * pow(air + 273.15, 4) * (1 - sky)         // W/m², half the view is sky
        let convection = max(3, 4 + wind), room = 1.15                                    // W/m²K
        return air + (room * (20 - air) - radiated + sunlight) / (convection + 4.6 + room)
    }

    /// The inside air's dew point for a single pane: outside air plus what a lived-in room adds, 6 g/m³ below
    /// freezing outside, falling to none at 20 °C (ISO 13788).
    nonisolated static func indoorDewPoint(outside: Double, dewPoint: Double) -> Double {
        let density = vapour(dewPoint) + 6 * min(max((20 - outside) / 20, 0), 1)
        let pressure = density / 1000 * 461.5 * 293.15, x = log(pressure / 611.2)          // Pa at 20 °C
        return 243.12 * x / (17.62 - x)
    }

    /// W/m² of sunlight the pane absorbs: a few percent of what falls on it, less under cloud.
    static func sunlight(at date: Date) -> Double {
        let here = Location.shared.coordinate, jd = Sky.julianDate(date)
        let up = normalize(Sky.horizonMatrix(jd: jd, latitude: here.latitude, longitude: here.longitude) * Sky.sun(jd)).z
        return 30 * max(up, 0) * (1 - 0.75 * (LiveWeather.shared.latest?.cloudCover ?? 50) / 100)
    }

    /// Rain arriving on the glass, 1 being the steady rain the scene was made for: about 3.5 mm/h on a pane facing
    /// the weather. The drops hitting a window grow only as the rate^0.45 (Marshall-Palmer drop sizes), and with
    /// the wind that drives them at it (research 5). Open-Meteo rounds to 0.4 mm/h, so drizzle codes count as 0.2.
    nonisolated static func rainAmount(mmPerHour: Double, wind: Double, code: Int) -> Double {
        let rate = max(mmPerHour, (51...57).contains(code) ? 0.2 : 0)
        guard rate > 0 else { return 0 }
        return min(max(pow(rate / 3.5, 0.45) * min(max(0.5 + 0.12 * wind, 0.5), 1.5), 0.15), 1.5)
    }

    /// A shower's burst or lull for the 5 minutes around `date`, as a multiple of the reported mean.
    nonisolated static func shower(_ date: Date) -> Double {
        let slot = (date.timeIntervalSince1970 / 300).rounded(.down)
        let h = (sin(slot * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1).magnitude
        return h < 0.35 ? 0.2 : h < 0.7 ? 1 : 2.5
    }

    /// Snow landing on the glass, 1 being about 10 flakes per screen a second: the visible flakes in the air
    /// (Gunn & Marshall 1958: about 240 per m³ at 1 mm/h of water, growing slowly with the rate) times the wind
    /// carrying them at the pane (a third of the 10 m wind, at least 0.3 m/s), half of them caught, over the
    /// 0.04 m² of glass on screen. Open-Meteo's cm of snow are 0.7 of its mm of water.
    nonisolated static func snowAmount(cmPerHour: Double, wind: Double) -> Double {
        guard cmPerHour > 0 else { return 0 }
        let visible = min(240 * pow(cmPerHour / 0.7, 0.55), 350), across = max(0.3 * wind, 0.3)
        return min(visible * across * 0.5 * 0.04 / 10, 1.5)
    }

    /// How big snowflakes are, mm across, by the air's temperature: small crystals in hard cold, aggregates of
    /// several near freezing, wet clumps just above it (Stewart et al. 2015).
    nonisolated static func flakeSize(air: Double) -> Double {
        air < -10 ? 2 : air < -5 ? 3 : air < -1 ? 5 : 8
    }

    /// How fast drops left on the glass dry, in mm² of diameter a second: a drop d mm across lasts 45·d²/(S·E)
    /// minutes, where S is how much more vapour the glass could hold than the air has (g/m³) and E is how much a
    /// breeze at the pane speeds it up (research 4, after Hu & Larson 2002). Air wetter than the glass dries nothing.
    nonisolated static func drying(glass: Double, dewPoint: Double, wind: Double) -> Double {
        max(vapour(glass) - vapour(dewPoint), 0) * min(1 + 1.5 * 0.25 * wind, 5) / 45 / 60
    }

    /// Water (g/m²) that frosts the whole pane: a clear night's supply at −5 °C covers it in about 2 hours.
    private static let frostWater = 12.0

    // MARK: - Keeping it

    /// Saves the live state, so a relaunch carries on (frost takes hours); a state more than a day old is dropped.
    private func save(_ date: Date) {
        lastSave = date
        UserDefaults.standard.set([date.timeIntervalSince1970, live.glass, live.water, live.frost, live.frozen, live.dried, live.rain,
                                   live.changed.timeIntervalSince1970, Double(frostSeed)], forKey: "rain.glass")
    }

    private func restore() {
        guard let saved = UserDefaults.standard.array(forKey: "rain.glass") as? [Double], saved.count == 9,
              Date().timeIntervalSince1970 - saved[0] < 86400 else { return }
        (live.glass, live.water, live.frost, live.frozen, live.dried) = (saved[1], saved[2], saved[3], saved[4], saved[5])
        (live.rain, live.before, live.changed, flowing) = (saved[6], saved[6], Date(timeIntervalSince1970: saved[7]), saved[6])
        live.stopped = live.rain > 0 ? nil : live.changed
        frostSeed = UInt64(saved[8])
        last = Date(timeIntervalSince1970: saved[0])
        primed = true
    }
}

/// One scene's view of `GlassWeather`: the uniforms its shader reads, with the weather's dates turned into times on
/// the scene's own water clock, and which parts of the weather its shader was built with. A scene has one only
/// while the weather is followed or previewed; without it, the shader is built without the weather, exactly as it
/// always was.
@MainActor final class GlassUniforms {
    /// The shader's switches, each a `#define` of 0 or 1. Each part costs GPU time even when it's idle (together
    /// 0.4 ms a frame), so only what the glass shows now is compiled in, and a dry pane draws no water at all.
    static let switches = ["WEATHER", "WATER", "CHANGE", "DRY", "FOG", "DEW", "SNOW", "FROST"]

    /// The switches a scene should be built with now: the weather's (following or previewing it), or the steady
    /// rain's.
    static var wanted: Set<String> {
        guard rainFollow.value > 0.5 || rainPreview[0].value > 0.5 else { return ["WATER"] }
        GlassWeather.shared.advance()
        return GlassWeather.shared.now.features
    }

    /// The `#define`s that start the shader's source.
    static func defines(_ weather: GlassUniforms?) -> String {
        switches.map { "#define \($0) \((weather?.features ?? ["WATER"]).contains($0) ? 1 : 0)\n" }.joined()
    }

    let features: Set<String>
    init(_ features: Set<String>) { self.features = features }

    /// (rain now, before it last changed, when it changed on the water clock, how far the drops left have dried)
    let rain = SKUniform(name: "u_rain", vectorFloat4: [1, 1, -1e6, 0])
    /// When the sliders stopped, on the water clock.
    let stop = SKUniform(name: "u_stop", float: 1e9)
    /// (drizzle mist, condensed water g/m², frost grown, share of drops frozen)
    let glass = SKUniform(name: "u_glass", vectorFloat4: [0.3, 0, 0, 0])
    /// (snow arriving, seconds per mg a flake takes to melt or 0 on freezing glass, flake size in mm, 0)
    let snow = SKUniform(name: "u_snow", vectorFloat4: .zero)
    /// (1 if fog and frost are on the inside, specks of mist and sliders for the kind of rain: 1 and 1 in steady
    /// rain, more specks and fewer sliders in drizzle, how wet the frost is as it melts)
    let pane = SKUniform(name: "u_pane", vectorFloat4: [0, 1, 1, 0])
    /// The frost's pattern (RainFrost), or no ice anywhere until it's baked.
    let frostMap = SKUniform(name: "u_frostMap", texture: SKTexture(data: Data([255, 255, 0, 255]), size: CGSize(width: 1, height: 1)))
    var all: [SKUniform] { [rain, stop, glass, snow, pane, frostMap] }
    private var clocks: [Date: Float] = [:]
    private var started = false

    /// Sets the uniforms for now. Called when the scene is built and every second after.
    func apply(to scene: ShaderScene) {
        let weather = GlassWeather.shared
        weather.advance()
        let now = weather.now
        var used: [Date: Float] = [:]
        func clock(_ date: Date) -> Float {
            let at = clocks[date] ?? Float(max(scene.clockTime - Date().timeIntervalSince(date) * rainSpeed.value, scene.clockTime - 5000))
            used[date] = at
            return at
        }
        rain.vectorFloat4Value = [Float(now.rain), Float(now.before), clock(now.changed), Float(now.dried)]
        stop.floatValue = now.stopped.map(clock) ?? 1e9
        clocks = used
        glass.vectorFloat4Value = [Float(now.mist), Float(now.water), Float(now.frost), Float(now.frozen)]
        snow.vectorFloat4Value = [Float(now.snow), Float(now.melt), Float(now.flake), 0]
        pane.vectorFloat4Value = [now.inside ? 1 : 0, now.drizzle ? 2 : 1, now.drizzle ? 0.3 : 1, Float(now.melting)]
        if features.contains("FROST"), let map = RainFrost.texture(seed: weather.frostSeed, size: scene.size), frostMap.textureValue !== map {
            frostMap.textureValue = map
        }
    }

    /// Starts the live services while following: location once, and the weather, which polls at most every
    /// 10 minutes however often it's asked.
    func poll() {
        guard rainFollow.value > 0.5 else { return }
        if !started { Location.shared.start() }
        started = true
        LiveWeather.shared.poll()
    }
}
