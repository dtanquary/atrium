import ServiceManagement
import SpriteKit
import SwiftUI

/// One live setting of a wallpaper, stored in UserDefaults under `key`: a slider, or a switch when `format` is
/// `.toggle` (stored as 0 or 1). Scenes read `value` and listen for `UserDefaults.didChangeNotification` to follow
/// changes while the control moves; shader scenes usually feed each knob into a uniform of the same name.
struct Knob {
    /// `choice` is a menu of named steps, stored as the index of the pick; `times` is a multiplier like "1.5×".
    enum Format: Equatable { case number, clock, minutes, toggle, times, choice([String]) }

    let key: String, label: String, range: ClosedRange<Double>, standard: Double
    /// The Settings section it's grouped under.
    var section = "Settings"
    var format = Format.number
    /// Only shown while this toggle knob is on.
    var shownWhen: String?

    var value: Double { UserDefaults.standard.object(forKey: key) as? Double ?? standard }
}

/// Named colour palettes a wallpaper can be pinned to, stored by name under `key`; empty rolls one at random.
/// Each option carries a few swatch colours for its dark and light looks. `standard` is the pick before the user
/// makes one. Options with an entry in `photos` show that resource image for each look instead of their colours.
struct PaletteChoice {
    let key: String
    let options: [(name: String, dark: [SIMD3<Float>], light: [SIMD3<Float>])]
    var standard = ""
    var photos: [String: (dark: String, light: String)] = [:]
    /// The Settings section it heads.
    var title = "Colors"
}

/// The Settings window, laid out like System Settings: wallpapers down the side, each with its own page.
struct SettingsView: View {
    @AppStorage("scene") private var current = scenes[0].name
    @State private var selection: String?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Wallpapers") {
                    ForEach(scenes, id: \.name) { wallpaper in
                        HStack {
                            IconTile(icon: wallpaper.icon, tint: wallpaper.tint, size: 22)
                            Text(wallpaper.name)
                            Spacer()
                            if wallpaper.name == current {
                                Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.secondary)
                            }
                        }
                        .tag(wallpaper.name)
                    }
                }
                Section {
                    HStack {
                        IconTile(icon: "gearshape.fill", tint: .gray, size: 22)
                        Text("General")
                    }
                    .tag(GeneralPage.tag)
                    HStack {
                        IconTile(icon: "bolt.fill", tint: .green, size: 22)
                        Text("Power")
                    }
                    .tag(PowerPage.tag)
                    HStack {
                        IconTile(icon: "info", tint: .gray, size: 22)
                        Text("About")
                    }
                    .tag(AboutPage.tag)
                }
            }
            .navigationSplitViewColumnWidth(min: 210, ideal: 230)
        } detail: {
            if selection == AboutPage.tag {
                AboutPage()
            } else if selection == GeneralPage.tag {
                GeneralPage()
            } else if selection == PowerPage.tag {
                PowerPage()
            } else if let wallpaper = scenes.first(where: { $0.name == selection ?? current }) {
                WallpaperPage(wallpaper: wallpaper).id(wallpaper.name)
            }
        }
        .onAppear { selection = selection ?? current }
    }
}

/// An SF Symbol on a rounded, tinted square, like the icons in iOS Settings.
struct IconTile: View {
    let icon: String
    let tint: Color
    let size: CGFloat

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.52, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint.gradient, in: .rect(cornerRadius: size * 0.26))
    }
}

extension View {
    /// Liquid Glass on macOS 26 and later, frosted material before it.
    @ViewBuilder func glass(cornerRadius: CGFloat) -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            background(.regularMaterial, in: .rect(cornerRadius: cornerRadius))
        }
    }
}

/// While on, moves the desktop on to a random wallpaper every so often, skipping any left out in Settings → General.
/// Any change of wallpaper, by hand or by Shuffle, starts the clock over.
@MainActor enum Shuffle {
    static let on = Knob(key: "shuffle.on", label: "Shuffle wallpapers", range: 0...1, standard: 0, format: .toggle)
    static let every = Knob(key: "shuffle.every", label: "Change wallpaper", range: 0...5, standard: 2,
                            format: .choice(["Every 5 minutes", "Every 15 minutes", "Every 30 minutes", "Every hour",
                                             "Every 3 hours", "Every day"]), shownWhen: on.key)
    private static let minutes: [Double] = [5, 15, 30, 60, 180, 1440]
    /// Wallpapers left out, by name and comma separated, so new wallpapers join in.
    static let skipKey = "shuffle.skip"
    static var skipped: [String] { (UserDefaults.standard.string(forKey: skipKey) ?? "").split(separator: ",").map(String.init) }

    /// A wallpaper to move on to: any but the one showing and those left out.
    /// ponytail: plain random, so one can come round again before all have shown; deal from a shuffled deck if that grates
    static func next() -> String? {
        let showing = UserDefaults.standard.string(forKey: "scene")
        return scenes.map(\.name).filter { $0 != showing && !skipped.contains($0) }.randomElement()
    }

    private static var pending: DispatchWorkItem?
    /// The wallpaper, switch and interval the pending change was set for.
    private static var scheduled: [String] = []

    /// Starts the clock over if the wallpaper, the switch or the interval has changed; call it on any defaults change.
    /// It counts wall-clock time, so a Mac that slept through the interval moves on as it wakes.
    static func reschedule() {
        let state = [UserDefaults.standard.string(forKey: "scene") ?? "", "\(on.value)", "\(every.value)"]
        guard state != scheduled else { return }
        scheduled = state
        pending?.cancel()
        guard on.value > 0.5 else { return }
        let work = DispatchWorkItem {
            MainActor.assumeIsolated {
                scheduled = [] // go round again even when there's nothing to move on to
                if let name = next() { show(name) }
                reschedule()
            }
        }
        pending = work
        let interval = minutes[min(max(Int(every.value), 0), minutes.count - 1)] * 60
        DispatchQueue.main.asyncAfter(wallDeadline: .now() + interval, execute: work)
    }
}

/// Turns Open at Login on or off. macOS may want it approved first, so this opens Login Items when it does.
@MainActor func setOpenAtLogin(_ on: Bool) {
    let service = SMAppService.mainApp
    do {
        if on { try service.register() } else { try service.unregister() }
    } catch {
        NSAlert(error: error).runModal()
    }
    if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
}

/// Open at Login, and Shuffle with the wallpapers it picks from.
struct GeneralPage: View {
    static let tag = "General" // sidebar selection; can't clash with a wallpaper name
    @State private var openAtLogin = SMAppService.mainApp.status == .enabled
    @AppStorage(Shuffle.on.key) private var shuffling = Shuffle.on.standard
    @AppStorage(Shuffle.skipKey) private var skip = ""

    var body: some View {
        Form {
            Section {
                Toggle("Open at Login", isOn: Binding(get: { openAtLogin }, set: {
                    setOpenAtLogin($0)
                    openAtLogin = SMAppService.mainApp.status == .enabled
                }))
            }
            Section {
                KnobRow(knob: Shuffle.on)
                KnobRow(knob: Shuffle.every)
            } header: {
                Text("Shuffle")
            } footer: {
                Text("Moves on to another wallpaper at random. Picking one yourself starts the clock over.")
                    .foregroundStyle(.secondary)
            }
            if shuffling > 0.5 {
                Section {
                    ForEach(scenes, id: \.name) { wallpaper in
                        Toggle(isOn: Binding(get: { !Shuffle.skipped.contains(wallpaper.name) },
                                             set: { include(wallpaper.name, $0) })) {
                            HStack {
                                IconTile(icon: wallpaper.icon, tint: wallpaper.tint, size: 22)
                                Text(wallpaper.name)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Wallpapers to Shuffle")
                        Spacer()
                        Button("All") { skip = "" }
                        Button("None") { skip = scenes.map(\.name).joined(separator: ",") }
                    }
                    .buttonStyle(.link)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
    }

    private func include(_ name: String, _ on: Bool) {
        skip = (Shuffle.skipped.filter { $0 != name } + (on ? [] : [name])).joined(separator: ",")
    }
}

/// How fast wallpapers run on mains power, on battery and in Low Power Mode. `applyPowerState` reads the choices.
enum Power {
    /// Frames per second for each menu choice; 0 freezes the wallpaper on its current frame.
    static let rates = [0, 15, 30, 60]
    private static let names = ["Freeze", "15 fps", "30 fps", "60 fps"]
    static let plugged = Knob(key: "power.plugged", label: "Plugged in", range: 0...3, standard: 3, format: .choice(names))
    static let battery = Knob(key: "power.battery", label: "On battery", range: 0...3, standard: 2, format: .choice(names))
    static let lowPower = Knob(key: "power.lowPower", label: "Low Power Mode", range: 0...3, standard: 0, format: .choice(names))
    static let knobs = [plugged, battery, lowPower]

    /// The frame rate for a knob's current choice.
    static func rate(_ knob: Knob) -> Int { rates[min(max(Int(knob.value), 0), rates.count - 1)] }
}

/// The frame-rate menus. Low Power Mode wins over the power source.
struct PowerPage: View {
    static let tag = "Power" // sidebar selection; can't clash with a wallpaper name

    var body: some View {
        Form {
            Section {
                ForEach(Power.knobs, id: \.key) { KnobRow(knob: $0) }
            } header: {
                Text("Frame Rate")
            } footer: {
                Text("60 fps is the smoothest. 30 fps uses about half the power, and 15 fps about a quarter. Freeze holds the current frame. Wallpapers always pause while the desktop is covered.")
                    .foregroundStyle(.secondary)
            }
            Section {
                Button("Reset to Defaults", role: .destructive) {
                    for knob in Power.knobs { UserDefaults.standard.removeObject(forKey: knob.key) }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Power")
    }
}

/// Name, version, maker, source, licence and the credits the data sources ask for.
struct AboutPage: View {
    static let tag = "About" // sidebar selection; can't clash with a wallpaper name

    private let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Atrium"
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    /// The photographers, as CC BY asks: "subject: author, licence" for each image in a credits file.
    private func credits(_ file: String) -> [String] {
        ((try? String(contentsOf: resource(file), encoding: .utf8)) ?? "")
            .split(separator: "\n").filter { !$0.hasPrefix("#") }.map { line in
                let field = line.split(separator: "\t").map(String.init)
                return field.count > 3 ? "\(field[1]): \(field[2]), \(field[3])" : String(line)
            }
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    IconTile(icon: "sparkles.tv", tint: .indigo, size: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(name).font(.title2.bold())
                        Text("Version \(version)").foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
                Text("Living, animated wallpapers for macOS. Open source, and built to be built yourself.")
            }
            Section("Made by") {
                LabeledContent("Dave Tanquary") { Link("dtanquary.com", destination: URL(string: "https://dtanquary.com")!) }
                LabeledContent("Source") { Link("github.com/dtanquary/atrium", destination: URL(string: "https://github.com/dtanquary/atrium")!) }
                LabeledContent("License") { Text("MIT") }
            }
            Section("Data and Credits") {
                LabeledContent("Weather") { Link("Open-Meteo.com (CC BY 4.0)", destination: URL(string: "https://open-meteo.com")!) }
                LabeledContent("ISS position") { Link("wheretheiss.at", destination: URL(string: "https://wheretheiss.at")!) }
                LabeledContent("Stars") { Text("Yale Bright Star Catalogue") }
                LabeledContent("Constellations") { Link("d3-celestial (BSD 3-Clause)", destination: URL(string: "https://github.com/ofrohn/d3-celestial")!) }
                LabeledContent("Earth imagery") { Text("NASA Blue Marble and Black Marble") }
                LabeledContent("Clouds") { Link("Live Cloud Maps; contains modified EUMETSAT data", destination: URL(string: "https://clouds.matteason.co.uk")!) }
                LabeledContent("Planet positions") { Text("NASA JPL") }
                LabeledContent("Aurora's mountains") { Link("The Tetons, NPS photo by A. Falgoust (public domain)", destination: URL(string: "https://commons.wikimedia.org/wiki/File:Teton_Point_Turnout_in_Winter_(52098766554).jpg")!) }
                LabeledContent("Murmuration's pier") { Link("\"Tide bears the last glow\" by sagesolar (CC BY 4.0)", destination: URL(string: "https://commons.wikimedia.org/wiki/File:Tide_bears_the_last_glow_-_Brighton,_UK.jpg")!) }
                LabeledContent("Fireflies' meadow") { Link("\"Field at dusk\" by Tristan Ferne (CC BY 2.0)", destination: URL(string: "https://www.flickr.com/photos/89056504@N00/7357684410")!) }
                LabeledContent("Campfire's clearing") { Link("\"Hochsal Forest\" by Adrian Kubasa, Poly Haven (CC0)", destination: URL(string: "https://polyhaven.com/a/hochsal_forest")!) }
                LabeledContent("Campfire's fire pit") { Link("Scans by Sebastian Platen and Rico Cilliers, Poly Haven (CC0)", destination: URL(string: "https://polyhaven.com/a/stone_fire_pit")!) }
                LabeledContent("Murmuration's marsh") { Link("A tundra pond, USFWS photo (public domain)", destination: URL(string: "https://commons.wikimedia.org/wiki/File:Sunset_over_a_tundra_pond_(53708107535).jpg")!) }
                DisclosureGroup("Weather's hills, clouds and Moon, from the BLM, NASA, Poly Haven and Wikimedia Commons") {
                    ForEach(credits("weather-credits.tsv"), id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                }
                DisclosureGroup("Rain on Glass backdrops, from Poly Haven, Wikimedia Commons and the NPS") {
                    ForEach(credits("rain-credits.tsv"), id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                }
                DisclosureGroup("Reef photos, from iNaturalist, Wikimedia Commons and NOAA") {
                    ForEach(credits("reef-credits.tsv"), id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("About")
    }
}

/// One wallpaper's settings: the wallpaper running live behind the top of the page (its screenshot until it's built),
/// a glass header to put it on the desktop, its palettes, then its knobs by section.
struct WallpaperPage: View {
    let wallpaper: Wallpaper
    @AppStorage("scene") private var current = scenes[0].name
    @Environment(\.colorScheme) private var scheme
    /// Bumped to rebuild the live preview with a new palette.
    @State private var builds = 0
    /// Whether the live preview has taken over from the screenshot.
    @State private var live = false

    private var sections: [String] {
        wallpaper.knobs.map(\.section).reduce(into: []) { if !$0.contains($1) && $1 != "Colors" { $0.append($1) } }
    }

    var body: some View {
        Form {
            Section {} footer: { // a footer has no card behind it, and unlike a header leaves the next section's title alone
                HStack(spacing: 12) {
                    IconTile(icon: wallpaper.icon, tint: wallpaper.tint, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(wallpaper.name).font(.title3.bold()).foregroundStyle(.primary)
                        Text(wallpaper.blurb).font(.callout).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Spacer()
                    if wallpaper.name == current {
                        Label("On Desktop", systemImage: "checkmark.circle.fill").foregroundStyle(.green).padding(.trailing, 6)
                    } else {
                        Button("Show on Desktop") { show(wallpaper.name) }.buttonStyle(.borderedProminent)
                    }
                }
                .font(.body)
                .padding(10)
                .glass(cornerRadius: 16)
                .padding(.top, 150)
            }
            if let palettes = wallpaper.palettes {
                Section(palettes.title) {
                    PalettePicker(choice: palettes) { rebuildIfShowing() }
                    RandomOnly(choice: palettes) {
                        ForEach(wallpaper.knobs.filter { $0.section == "Colors" }, id: \.key) { KnobRow(knob: $0) }
                    }
                }
            }
            ForEach(sections, id: \.self) { section in
                Section(section) {
                    ForEach(wallpaper.knobs.filter { $0.section == section }, id: \.key) { knob in
                        KnobRow(knob: knob)
                        if let status = wallpaper.status, status.below == knob.key { StatusRow(key: status.key, gate: status.below) }
                    }
                }
            }
            if wallpaper.knobs.isEmpty && wallpaper.palettes == nil {
                Section { Text("No settings for this wallpaper yet.").foregroundStyle(.secondary) }
            } else {
                Section {
                    Button("Reset to Defaults", role: .destructive) {
                        for key in wallpaper.knobs.map(\.key) + [wallpaper.palettes?.key].compactMap({ $0 }) {
                            UserDefaults.standard.removeObject(forKey: key)
                        }
                        rebuildIfShowing()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(alignment: .top) {
            Color.clear.frame(height: 340)
                .overlay {
                    preview.resizable().scaledToFill()
                    if live { LivePreview(wallpaper: wallpaper).id([builds, scheme == .dark ? 1 : 0]).transition(.opacity) }
                }
                .clipped()
                .mask(LinearGradient(stops: [.init(color: .black, location: 0.55), .init(color: .clear, location: 1)],
                                     startPoint: .top, endPoint: .bottom))
                .ignoresSafeArea()
                .accessibilityHidden(true)
        }
        // The screenshot draws first, then the live scene fades in over it once built.
        // ponytail: Fish Tank and Weather take about half a second to build on the main thread, which stalls the
        // page once; build them off the main thread if that grates.
        .task { withAnimation(.easeIn(duration: 0.6)) { live = true } }
        .navigationTitle(wallpaper.name)
    }

    /// The wallpaper's screenshot, `Resources/preview-<name>.jpg`, with a `-light` one for Light Mode if it has one.
    private var preview: Image {
        let file = "preview-" + wallpaper.name.lowercased().replacingOccurrences(of: " ", with: "-")
        let image = scheme == .light ? NSImage(contentsOf: resource(file + "-light.jpg")) : nil
        return Image(nsImage: image ?? NSImage(contentsOf: resource(file + ".jpg")) ?? NSImage())
    }

    /// Palettes are picked when a scene is built, so a new pick rebuilds the preview, and the desktop if it's showing.
    private func rebuildIfShowing() {
        builds += 1
        if wallpaper.name == current { switchScene() }
    }
}

/// The wallpaper running live, framed like the desktop: built at the main display's size and scaled to fill.
/// `WallpaperView` pauses it whenever the Settings window is covered or closed. It's a second copy of the scene,
/// like one on another display, so shared services (location, clouds, ISS) already cope.
struct LivePreview: NSViewRepresentable {
    let wallpaper: Wallpaper

    func makeNSView(context: Context) -> WallpaperView {
        let view = WallpaperView()
        applyPowerState(to: [view])
        let scene = wallpaper.make(NSScreen.main?.frame.size ?? CGSize(width: 1512, height: 982))
        scene.scaleMode = .aspectFill
        view.presentScene(scene)
        return view
    }

    func updateNSView(_ view: WallpaperView, context: Context) {}
}

/// A scene's own status line from UserDefaults, shown while the knob `gate` is 0 and there's something to say.
struct StatusRow: View {
    @AppStorage private var text: String
    @AppStorage private var gate: Double

    init(key: String, gate: String) {
        _text = AppStorage(wrappedValue: "", key)
        _gate = AppStorage(wrappedValue: 0, gate)
    }

    var body: some View {
        if gate < 0.5 && !text.isEmpty { Text(text).font(.callout).foregroundStyle(.secondary).textSelection(.enabled) }
    }
}

/// A knob's control, hidden while the toggle it depends on is off.
struct KnobRow: View {
    let knob: Knob
    @AppStorage private var value: Double
    @AppStorage private var gate: Double

    init(knob: Knob) {
        self.knob = knob
        _value = AppStorage(wrappedValue: knob.standard, knob.key)
        _gate = AppStorage(wrappedValue: 1, knob.shownWhen ?? knob.key) // an empty key crashes KVO; unused when ungated
    }

    var body: some View {
        if knob.shownWhen == nil || gate > 0.5 {
            if knob.format == .toggle {
                Toggle(knob.label, isOn: Binding(get: { value > 0.5 }, set: { value = $0 ? 1 : 0 }))
            } else if case .choice(let names) = knob.format {
                Picker(knob.label, selection: Binding(get: { Int(value) }, set: { value = Double($0) })) {
                    ForEach(names.indices, id: \.self) { Text(names[$0]).tag($0) }
                }
            } else {
                LabeledContent(knob.label) {
                    HStack {
                        Slider(value: $value, in: knob.range)
                        Text(formatted).monospacedDigit().foregroundStyle(.secondary).frame(width: 52, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var formatted: String {
        switch knob.format {
        case .clock: String(format: "%d:%02d", Int(value) % 24, Int(value * 60) % 60)
        case .minutes: value < 0.5 ? "Off" : "\(Int(value.rounded())) min"
        case .times: String(format: value < 10 ? "%.1f×" : "%.0f×", value)
        default: String(format: "%.2f", value)
        }
    }
}

/// Shows its content only while the palette stored under `key` is Random, e.g. how often colours change.
struct RandomOnly<Content: View>: View {
    @AppStorage private var chosen: String
    @ViewBuilder let content: Content

    init(choice: PaletteChoice, @ViewBuilder content: () -> Content) {
        _chosen = AppStorage(wrappedValue: choice.standard, choice.key)
        self.content = content()
    }

    var body: some View {
        if chosen.isEmpty { content }
    }
}

/// Palette swatches in a grid, with Random first.
struct PalettePicker: View {
    let choice: PaletteChoice
    let picked: () -> Void
    @AppStorage private var selected: String
    @Environment(\.colorScheme) private var scheme

    init(choice: PaletteChoice, picked: @escaping () -> Void) {
        self.choice = choice
        self.picked = picked
        _selected = AppStorage(wrappedValue: choice.standard, choice.key)
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 14)], spacing: 14) {
            swatch("Random", colours: choice.options.filter { choice.photos[$0.name] == nil }.compactMap { (scheme == .dark ? $0.dark : $0.light).last },
                   symbol: "shuffle")
            ForEach(choice.options, id: \.name) { option in
                swatch(option.name, colours: scheme == .dark ? option.dark : option.light,
                       photo: choice.photos[option.name].map { scheme == .dark ? $0.dark : $0.light })
            }
        }
        .padding(.vertical, 6)
    }

    private func swatch(_ name: String, colours: [SIMD3<Float>], symbol: String? = nil, photo: String? = nil) -> some View {
        let isSelected = (name == "Random" ? "" : name) == selected
        return Button {
            selected = name == "Random" ? "" : name
            picked()
        } label: {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: colours.map { Color(red: Double($0.x), green: Double($0.y), blue: Double($0.z)) },
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(height: 46)
                    .overlay {
                        if let photo, let image = NSImage(contentsOf: resource(photo)) { // ponytail: reads the file on each redraw; small
                            Image(nsImage: image).resizable().scaledToFill().clipShape(.rect(cornerRadius: 12))
                        }
                    }
                    .overlay { if let symbol { Image(systemName: symbol).font(.title3.bold()).foregroundStyle(.white) } }
                    .overlay { RoundedRectangle(cornerRadius: 15).strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2.5).padding(-4) }
                Text(name).font(.caption).foregroundStyle(isSelected ? .primary : .secondary).lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}
