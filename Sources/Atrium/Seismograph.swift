import LineRoute
import SpriteKit
import Synchronization

@MainActor func seismograph(size: CGSize) -> SKScene { Seismograph(size: size) }

/// A day of the ground's motion drawn by a pen on a sheet, a row each half hour, as a seismic drum recorder draws
/// it: mostly the fine, even tremble of the ocean's microseism, and now and then a quake's train of slow waves
/// tangling a few rows. Today is written over yesterday's faint line, so the sheet always holds a day. The line is
/// a station's real record in the long-period band (`Ground.trace`), on Etching's ground and in its tones: a dimmed
/// cream chart by day and a sheet of smoked paper, scratched pale, by night.
///
/// The sheet is stamped once off the main thread into one texture at the display's pixels: for each texel, how much
/// of today's line covers it and in which row, and the same of yesterday's. A texel's time is its row and its
/// column, so the shader shows today's line where that time is behind the pen and yesterday's where it is ahead, and
/// a frame costs the same at any hour. docs/seismograph.md has the research, the mock-ups and Dave's choices.
final class Seismograph: SKScene {
    /// Which of the two looks: Light (the chart), Dark (smoked paper), whichever suits the system's appearance, or
    /// light by day and dark by night by the real Sun where the Mac is. Stored by place, as Etching's Screen is.
    nonisolated static let look = Knob(key: "seismograph.look", label: "Appearance", range: 0...3, standard: 2, section: "Sheet",
                                       format: .choice(["Light", "Dark", "Match System", "Follow Day and Night"]), order: [2, 3, 0, 1])
    /// How far the pen swings for the ground's motion: at 1, the quiet line trembles about a fifth of a row either
    /// way, as real records are scaled to their own station's noise (research-method.md, §3).
    nonisolated static let sensitivity = Knob(key: "seismograph.sensitivity", label: "Sensitivity", range: 0.25...2, standard: 1, section: "Sheet", format: .times)
    /// Minutes of the day in each row: 15 is the USGS's own records' pace, 60 NCEDC's. Stored by place.
    nonisolated static let minutes = Knob(key: "seismograph.minutes", label: "Minutes a row", range: 0...2, standard: 1, section: "Sheet",
                                          format: .choice(["15", "30", "60"]))
    /// Whether the sheet is the nearest station's own, live, or the sample day. Its status line says which station,
    /// how far, and how far behind the pen runs (`SeismicFeed.status`).
    nonisolated static let live = Knob(key: "seismograph.live", label: "Live from the nearest station", range: 0...1, standard: 1, section: "Station", format: .toggle)
    nonisolated static let knobs = [look, sensitivity, minutes, live]
    /// Hours of the last two days a station has to have sent before its sheet replaces the sample day's: the ring
    /// keeps only an hour or two, so with the archive down the sheet would be nearly bare for most of a day.
    // ponytail: the sample day until then, not today's rows over it; mix them if the archive is often down
    static let liveHours = 12.0
    nonisolated static let rowMinutes = [15.0, 30, 60]

    /// The two looks, as one of Etching's surfaces with a light tone and a dark: Chart, a cream dimmed for a sheet
    /// that is nearly all ground (its median is 207 of 255 where Etching's Paper's is 235), under black-brown ink; and
    /// Smoked, soot with a pale scratch (research-look.md, §3).
    nonisolated static let paper = Etching.Surface(name: "Chart", ground: (tone(208, 200, 184), tone(34, 33, 31)), line: (tone(46, 40, 36), tone(196, 192, 184)),
                                                   tooth: ([0.009, 0.008, 0.025], [0.030, 0.034, 0.06]))
    nonisolated private static func tone(_ r: Float, _ g: Float, _ b: Float) -> SIMD3<Float> { SIMD3(r, g, b) / 255 }

    /// A real day for when no station's own has come: NL.HGN in the Netherlands (KNMI's network, CC BY 4.0), its
    /// records of 15 and 16 November 2026 as ORFEUS served them, the sheet's days in US Central time. The 16th has
    /// the train of an M6.6 in the Banda Sea, 117° away, from about 15:30.
    nonisolated static let sample = (file: "seismograph-sample.mseed", midnight: 1_794_808_800) // 2026-11-16 00:00 UTC-6

    /// Where the rows go on a display `wide` by `high` texels, at `scale` texels to a device pixel, and how the pen
    /// writes on them. Margins are shares of the screen: the top clears the menu bar, the left holds the hours.
    struct Layout: Sendable, Equatable {
        var wide: Int, high: Int, scale: Double, minutes: Double
        var seconds: Double { minutes * 60 }
        var lines: Int { Int(86400 / seconds) }
        var top: Double { Double(high) * 0.06 }
        var left: Double { (Double(wide) * 0.05).rounded() }
        var right: Double { (Double(wide) * 0.97).rounded() }
        var spacing: Double { (Double(high) * 0.91) / Double(lines) }
        /// The pen's width; the swing at which it stops, in rows, as a drum's pen stops; and the clock's pips, in rows.
        var pen: Double { 2 * scale }
        static let clip = 2.5, pips = 0.12
        /// How much thinner and paler a fast stroke is, as ink lays less of itself down where the pen moves quickly;
        /// and yesterday's line, as a share of the way from the ground to the ink.
        static let fade = 0.4, old: Float = 0.28
    }

    /// A day's sheet, ready to stamp: its layout, and today's and yesterday's line, in rows, a sample a second
    /// from the sheet's midnight, NaN where there was a gap or nothing has come.
    struct Sheet: Sendable {
        var layout: Layout, today: [Float], yesterday: [Float]

        /// The pen's offset at a sheet time in seconds, in rows, up positive: the ground's motion, running straight
        /// from one sample to the next, eased into the clip (a hard stop drew big swings as square-topped pulses),
        /// and the clock's pips (MEQ-800: 1 s each minute, 2 s each hour, 10 s at noon and midnight).
        static func deflection(_ t: Double, _ data: [Float]) -> Double? {
            let i = Int(t.rounded(.down)), f = t - Double(i)
            guard i >= 0, i + 1 < data.count, !data[i].isNaN, !data[i + 1].isNaN else { return nil }
            var v = Layout.clip * tanh((Double(data[i]) * (1 - f) + Double(data[i + 1]) * f) / Layout.clip)
            let s = t.truncatingRemainder(dividingBy: 60)
            if s < (t.truncatingRemainder(dividingBy: 43200) < 60 ? 10 : t.truncatingRemainder(dividingBy: 3600) < 60 ? 2 : 1) { v += Layout.pips }
            return v
        }

        /// The texture's bytes, its rows from the bottom up: red, how much of today's line covers a texel; green,
        /// the row that drew it; blue and alpha, the same of yesterday's. The hours in the margin are today's, in
        /// row 0 left of the rows' start, so they are always drawn.
        func stamp() -> [UInt8] {
            let (w, h) = (layout.wide, layout.high)
            var bytes = [UInt8](repeating: 0, count: w * h * 4)
            let cols = Int(layout.right - layout.left), colSec = layout.seconds / Double(cols), pen = layout.pen
            for (channel, data) in [(0, today), (2, yesterday)] where !data.isEmpty {
                for line in 0..<layout.lines {
                    let base = layout.top + (Double(line) + 0.5) * layout.spacing
                    for c in 0..<cols {
                        // the line's reach over this column and half a pen either side, its two ends and every sample between
                        let t0 = Double(line) * layout.seconds + (Double(c) - pen / 2) * colSec, t1 = t0 + (1 + pen) * colSec
                        var lo = Double.infinity, hi = -Double.infinity, t = t0.rounded(.up)
                        for at in [t0, t1] { if let v = Self.deflection(at, data) { lo = min(lo, v); hi = max(hi, v) } }
                        while t < t1 { if let v = Self.deflection(t, data) { lo = min(lo, v); hi = max(hi, v) }; t += 1 }
                        guard lo <= hi else { continue }
                        let fall = Double(c) / Double(cols) * layout.spacing // the helix: each row falls a row along its length
                        let yTop = base + fall - hi * layout.spacing - pen / 2, yBottom = base + fall - lo * layout.spacing + pen / 2
                        let ink = 1 - Layout.fade * (1 - min(1, 2.5 * pen / (yBottom - yTop)))
                        let x = Int(layout.left) + c
                        let first = max(Int(yTop.rounded(.down)), 0), last = min(Int(yBottom.rounded(.up)), h - 1)
                        guard first <= last else { continue }
                        for y in first...last {
                            let cover = max(0, min(Double(y + 1), yBottom) - max(Double(y), yTop)) * ink
                            let i = ((h - 1 - y) * w + x) * 4 + channel, a = UInt8(min(255, cover * 255 + 0.5))
                            if a > bytes[i] { (bytes[i], bytes[i + 1]) = (a, UInt8(line)) }
                        }
                    }
                }
            }
            // the hours, in a pencil's grey, in the left margin
            let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w, space: CGColorSpaceCreateDeviceGray(),
                                    bitmapInfo: CGImageAlphaInfo.none.rawValue)!
            let font = CTFontCreateWithName("Helvetica" as CFString, max(layout.spacing * 0.42, 15 * layout.scale), nil)
            let every = layout.lines > 48 ? 7200.0 : 3600
            for line in 0..<layout.lines where (Double(line) * layout.seconds).truncatingRemainder(dividingBy: every) == 0 {
                let text = CTLineCreateWithAttributedString(NSAttributedString(string: String(format: "%02d", Int(Double(line) * layout.seconds / 3600)),
                                                                               attributes: [.font: font, .foregroundColor: CGColor(gray: 1, alpha: 1)]))
                let bounds = CTLineGetBoundsWithOptions(text, .useGlyphPathBounds)
                context.textPosition = CGPoint(x: layout.left - bounds.width - 24 * layout.scale,
                                               y: Double(h) - (layout.top + (Double(line) + 0.5) * layout.spacing) - bounds.height / 2)
                CTLineDraw(text, context)
            }
            let gray = context.data!.bindMemory(to: UInt8.self, capacity: w * h), margin = Int(layout.left)
            for y in 0..<h { for x in 0..<margin where gray[y * w + x] > 0 { bytes[((h - 1 - y) * w + x) * 4] = gray[y * w + x] / 2 } }
            return bytes
        }
    }

    /// A sheet and its stamp, handed from the thread that made them to the scene's next frame (Etching's `Landing`).
    private final class Landing: Sendable {
        private let made = Mutex<(sheet: Sheet, bytes: [UInt8])?>(nil), ready = DispatchSemaphore(value: 0)
        func arrive(_ sheet: Sheet, _ bytes: [UInt8]) { made.withLock { $0 = (sheet, bytes) }; ready.signal() }
        /// What has arrived, once; `waiting` holds the caller until it has, for the render tests.
        func take(waiting: Bool) -> (sheet: Sheet, bytes: [UInt8])? {
            if waiting { ready.wait(); ready.signal() }
            return made.withLock { made in defer { made = nil }; return made }
        }
    }

    /// What a stamp is of: the layout, the sensitivity, the sheet's midnight and the data's version (-1, the sample).
    private struct Held: Equatable { var layout: Layout, sensitivity: Double, midnight: Int, version: Int }

    /// The sample day, decoded once and shared.
    nonisolated private static let sampleGround: Ground = {
        var ground = Ground()
        for record in MiniSEED.records((try? Data(contentsOf: resource(sample.file))) ?? Data()) { ground.add(record) }
        return ground
    }()

    private let sprite = SKSpriteNode()
    private let sheetTexture = SKUniform(name: "u_sheet", texture: SKTexture(data: Data([0, 0, 0, 0]), size: CGSize(width: 1, height: 1)))
    private let texels = SKUniform(name: "u_tex", vectorFloat2: [1, 1]), rows = SKUniform(name: "u_rows", vectorFloat2: [0, 1])
    /// The pen: its time in rows from the sheet's top, and where its tip is in device pixels.
    private let penAt = SKUniform(name: "u_at", float: 0), tip = SKUniform(name: "u_pen", vectorFloat2: [-100, -100])
    private let ground = SKUniform(name: "u_ground", vectorFloat3: .zero), ink = SKUniform(name: "u_ink", vectorFloat3: .zero), tooth = SKUniform(name: "u_tooth", vectorFloat3: .zero)
    private var pixels = SIMD2<Double>(1, 1), half = false
    /// The sheet on the screen and the stamp being made.
    private var held: Held?, sheet: Sheet?, stamping: (of: Held, landing: Landing)?
    /// How far the ground is from its light tone to its dark, and the line, as Etching's are (`tint`); the system's
    /// appearance, watched; where the Sun last put the shade, and when.
    private var shade = 0.0, inked = 0.0, dark = false, appearance: NSKeyValueObservation?, lastWall: Double?
    private var night = 0.0, sunAt: Double?, located = false
    private var wanted: Double {
        switch Int(Self.look.value) {
        case 0: 0
        case 1: 1
        case 2: dark ? 1 : 0
        default: night
        }
    }

    private static let grain: SKTexture = {
        let tile = SKTexture(data: LineRoute.grain(), size: CGSize(width: 512, height: 512))
        tile.filteringMode = .linear
        return tile
    }()

    override func sceneDidLoad() {
        backgroundColor = .black
        dark = systemIsDark
        night = Self.look.value > 2.5 ? Etching.nightfall(sun: Self.sun(at: Date.timeIntervalSinceReferenceDate)) : 0
        shade = wanted
        inked = shade > 0.5 ? 1 : 0
        tint()
        appearance = NSApplication.shared.observe(\.effectiveAppearance) { [weak self] _, _ in MainActor.assumeIsolated { self?.dark = systemIsDark } }
        // the display's own pixels, and a texel to each; above 6.5 million, a texel to two each way, as Etching's
        let factor = NSScreen.screens.first { $0.frame.size == size }?.backingScaleFactor ?? 2
        pixels = SIMD2(Double(size.width * factor).rounded(), Double(size.height * factor).rounded())
        half = pixels.x * pixels.y > 6_500_000
        sprite.size = size
        sprite.anchorPoint = .zero
        sprite.shader = SKShader(source: shaderCommon + Self.source(half: half, pen: 2), uniforms: [
            SKUniform(name: "u_px", vectorFloat2: [Float(pixels.x), Float(pixels.y)]), SKUniform(name: "u_grain", texture: Self.grain),
            sheetTexture, texels, rows, penAt, tip, ground, ink, tooth])
        addChild(sprite)
    }

    override func didMove(to view: SKView) {
        locate()
        if Self.live.value > 0.5 { Location.shared.start() } // the nearest station: macOS asks leave the first time
        SeismicFeed.shared.attach()
    }

    override func willMove(from view: SKView) { SeismicFeed.shared.detach() }

    /// Asks where the Mac is, once, and only while the look follows the Sun: the first time, macOS asks leave.
    private func locate() {
        guard !located, view != nil, Self.look.value > 2.5 else { return }
        located = true
        Location.shared.start()
    }

    /// The Sun's altitude in degrees where the Mac is, as Etching's; `seismograph.sun` stands in for it in pictures.
    private static func sun(at wall: Double) -> Double {
        if let asked = UserDefaults.standard.object(forKey: "seismograph.sun") as? Double { return asked }
        let here = Location.shared.coordinate, jd = Sky.julianDate(Date(timeIntervalSinceReferenceDate: wall))
        return asin((Sky.horizonMatrix(jd: jd, latitude: here.latitude, longitude: here.longitude) * Sky.sun(jd)).z) * 180 / .pi
    }

    private func tint() {
        func eased(_ tones: Etching.Surface.Tones, _ along: Double) -> SIMD3<Float> { simd_mix(tones.light, tones.dark, SIMD3(repeating: Float(simd_smoothstep(0, 1, along)))) }
        ground.vectorFloat3Value = eased(Self.paper.ground, shade)
        tooth.vectorFloat3Value = eased(Self.paper.tooth, shade)
        ink.vectorFloat3Value = eased(Self.paper.line, inked)
    }

    /// The sheet's midnight (seconds since 1970) and the pen's time on it, in seconds: live, today's, the pen
    /// `SeismicFeed.behind` the clock; else the sample day's, the pen at the Mac's time of day (or `seismograph.hour`,
    /// for pictures).
    // ponytail: a sheet is 24 hours from local midnight, so on the two days a year the clocks change the last hour's
    // label is an hour out; give the sheet 23 or 25 rows' worth then if anyone notices
    private func moment(at wall: Double, live: Bool) -> (midnight: Int, pen: Double) {
        let now = Date(timeIntervalSinceReferenceDate: wall - (live ? SeismicFeed.behind : 0)), midnight = Calendar.current.startOfDay(for: now)
        if live { return (Int(midnight.timeIntervalSince1970), now.timeIntervalSince(midnight)) }
        let hours = UserDefaults.standard.object(forKey: "seismograph.hour") as? Double
        return (Self.sample.midnight, hours.map { $0 * 3600 } ?? now.timeIntervalSince(midnight))
    }

    override func update(_ currentTime: TimeInterval) {
        let wall = currentTime + Date.timeIntervalSinceReferenceDate - ProcessInfo.processInfo.systemUptime
        let passed = min(max(wall - (lastWall ?? wall), 0), 0.1)
        lastWall = wall
        // the look, eased over two seconds as Etching's is, the line crossing on its own once the ground is past half
        if Self.look.value < 2.5 {
            sunAt = nil
        } else if wall - (sunAt ?? -.infinity) >= 30 {
            locate()
            (night, sunAt) = (Etching.nightfall(sun: Self.sun(at: wall)), wall)
        }
        func toward(_ aim: Double, from value: Double) -> Double { abs(aim - value) <= passed / 2 ? aim : value + (aim > value ? passed / 2 : -passed / 2) }
        let lined = shade > 0.5 ? 1.0 : 0.0
        if shade != wanted || inked != lined {
            (shade, inked) = (toward(wanted, from: shade), toward(lined, from: inked))
            tint()
        }

        // the sheet: stamped again when a setting, the day or the data changes
        let feed = SeismicFeed.shared
        feed.tick(wall + Date.timeIntervalBetween1970AndReferenceDate, live: Self.live.value > 0.5)
        let live = Self.live.value > 0.5 && feed.hours >= Self.liveHours
        let (midnight, pen) = moment(at: wall, live: live)
        let minutes = Self.rowMinutes[Int(Self.minutes.value)], scale = half ? 0.5 : 1
        let layout = Layout(wide: Int(pixels.x * scale), high: Int(pixels.y * scale), scale: scale, minutes: minutes)
        let wanted = Held(layout: layout, sensitivity: Self.sensitivity.value, midnight: midnight, version: live ? feed.version : -1)
        if held != wanted, stamping?.of != wanted {
            let landing = Landing(), ground = live ? feed.ground : Self.sampleGround, sensitivity = wanted.sensitivity
            stamping = (wanted, landing)
            Task.detached(priority: .userInitiated) {
                let trace = ground.trace(sensitivity: sensitivity)
                func day(from: Int) -> [Float] {
                    let i = from - ground.start
                    return (0..<86400).map { i + $0 >= 0 && i + $0 < trace.count ? trace[i + $0] : .nan }
                }
                let sheet = Sheet(layout: layout, today: day(from: midnight), yesterday: day(from: midnight - 86400))
                landing.arrive(sheet, sheet.stamp())
            }
        }
        if let job = stamping, let made = job.landing.take(waiting: view == nil && held == nil) { // the render tests wait for their first
            let texture = SKTexture(data: Data(made.bytes), size: CGSize(width: made.sheet.layout.wide, height: made.sheet.layout.high))
            texture.filteringMode = .nearest
            sheetTexture.textureValue = texture
            texels.vectorFloat2Value = [Float(made.sheet.layout.wide), Float(made.sheet.layout.high)]
            rows.vectorFloat2Value = [Float(made.sheet.layout.left), Float(made.sheet.layout.right - made.sheet.layout.left)]
            (held, sheet, stamping) = (job.of, made.sheet, nil)
        }

        // the pen, at its time on the sheet, where the line it is drawing is
        guard let layout = held?.layout else { return }
        let row = min(pen / layout.seconds, Double(layout.lines) - 1e-6), line = row.rounded(.down), along = row - line
        penAt.floatValue = Float(row)
        let y = layout.top + (line + 0.5 + along) * layout.spacing - (sheet.flatMap { Sheet.deflection(pen, $0.today) } ?? 0) * layout.spacing
        tip.vectorFloat2Value = [Float((layout.left + along * (layout.right - layout.left)) / layout.scale), Float(pixels.y - y / layout.scale)]
    }

    /// The shader: the sheet's texture against the pen, on Etching's ground. Every read is at a texel's centre,
    /// since a row number smoothed between two texels is a row that drew neither. With a texel to each pixel that
    /// is one read; with a texel to two each way (`half`), the four round the pixel, each compared on its own and
    /// only then mixed.
    private static func source(half: Bool, pen: Double) -> String {
        let read = half ? """
            vec2 q = v_tex_coord * u_tex - 0.5, f = fract(q), b = floor(q);
            float line = 0.0, old = 0.0;
            for (float j = 0.0; j < 1.5; j += 1.0) {
                for (float i = 0.0; i < 1.5; i += 1.0) {
                    vec2 c = clamp(b + vec2(i, j), vec2(0.0), u_tex - 1.0);
                    vec4 s = texture2D(u_sheet, (c + 0.5) / u_tex);
                    float along = (c.x + 0.5 - u_rows.x) / u_rows.y, share = mix(1.0 - f.x, f.x, i) * mix(1.0 - f.y, f.y, j);
                    line += share * s.r * step(floor(s.g * 255.0 + 0.5) + along, u_at);
                    old += share * s.b * step(u_at, floor(s.a * 255.0 + 0.5) + along);
                }
            }
        """ : """
            vec2 c = floor(v_tex_coord * u_tex);
            vec4 s = texture2D(u_sheet, (c + 0.5) / u_tex);
            float along = (c.x + 0.5 - u_rows.x) / u_rows.y;
            float line = s.r * step(floor(s.g * 255.0 + 0.5) + along, u_at);
            float old = s.b * step(u_at, floor(s.a * 255.0 + 0.5) + along);
        """
        return """
        void main() {
        \(read)
            // Etching's ground, as Etching.swift has it: a pixel's own noise, a soft tooth from the grain tile, sparse
            // fibres on two lattices of unlike pitch, and the light from the upper left.
            vec2 px = floor(v_tex_coord * u_px), at = px + 0.5, cell = floor(at / 53.0);
            vec4 n = hash42(px), h = hash42(cell + 17.0);
            float soft = texture2D(u_grain, (mod(px + floor(h.zw * 512.0), 512.0) + 0.5) / 512.0).r - 1.004, fibres = 0.0;
            vec2 d = at - (cell + 0.16 + 0.68 * h.xy) * 53.0;
            if (dot(d, d) < 72.0) {
                vec2 along = normalize(vec2(h.z, fract(h.z * 64.0)) - 0.5);
                float reach = 3.0 + 4.0 * fract(h.w * 16.0);
                fibres += (step(0.5, h.w) * 2.0 - 1.0) * max(0.0, 1.0 - length(d - along * clamp(dot(d, along), -reach, reach)));
            }
            at += 400.0;
            cell = floor(at / 61.0);
            h = hash42(cell + 130.0);
            soft += texture2D(u_grain, (mod(px + floor(h.zw * 512.0), 512.0) + 0.5) / 512.0).r;
            d = at - (cell + 0.16 + 0.68 * h.xy) * 61.0;
            if (dot(d, d) < 72.0) {
                vec2 along = normalize(vec2(h.z, fract(h.z * 64.0)) - 0.5);
                float reach = 3.0 + 4.0 * fract(h.w * 16.0);
                fibres += (step(0.5, h.w) * 2.0 - 1.0) * max(0.0, 1.0 - length(d - along * clamp(dot(d, along), -reach, reach)));
            }
            float tooth = u_tooth.x * (n.x + n.y - 1.0) * 2.449 + u_tooth.y * soft * 5.635 + u_tooth.z * fibres;
            // yesterday's line, faint, where today's pen has not yet come; today's; then the pen's tip
            vec3 tone = mix(u_ground, u_ink, old * \(Layout.old));
            tone = mix(tone, u_ink, line);
            tone = mix(tone, u_ink, 0.9 * (1.0 - smoothstep(\(pen * 0.9), \(pen * 2.4), length(px + 0.5 - u_pen))));
            gl_FragColor = vec4(tone * (1.0 + 0.02 * (v_tex_coord.y - v_tex_coord.x)) + tooth * min(tone, u_ground), 1.0);
        }
        """
    }
}
