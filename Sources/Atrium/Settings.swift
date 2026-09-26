import SwiftUI

/// One live setting of a wallpaper, stored in UserDefaults under `key`: a slider, or a switch when `format` is
/// `.toggle` (stored as 0 or 1). Scenes read `value` and listen for `UserDefaults.didChangeNotification` to follow
/// changes while the control moves; shader scenes usually feed each knob into a uniform of the same name.
struct Knob {
    /// `choice` is a menu of named steps, stored as the index of the pick; `times` is a multiplier like "6×".
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
/// makes one.
struct PaletteChoice {
    let key: String
    let options: [(name: String, dark: [SIMD3<Float>], light: [SIMD3<Float>])]
    var standard = ""
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
                DisclosureGroup("Weather's hills, clouds and Moon, from the BLM, NASA, Poly Haven and Wikimedia Commons") {
                    ForEach(credits("weather-credits.tsv"), id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
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

/// One wallpaper's settings: a header to put it on the desktop, its palettes, then its knobs by section.
struct WallpaperPage: View {
    let wallpaper: Wallpaper
    @AppStorage("scene") private var current = scenes[0].name

    private var sections: [String] {
        wallpaper.knobs.map(\.section).reduce(into: []) { if !$0.contains($1) && $1 != "Colors" { $0.append($1) } }
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    IconTile(icon: wallpaper.icon, tint: wallpaper.tint, size: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(wallpaper.name).font(.title2.bold())
                        Text(wallpaper.blurb).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if wallpaper.name == current {
                        Label("On Desktop", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Button("Show on Desktop") { show(wallpaper.name) }.buttonStyle(.borderedProminent)
                    }
                }
                .padding(.vertical, 6)
            }
            if let palettes = wallpaper.palettes {
                Section("Colors") {
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
        .navigationTitle(wallpaper.name)
    }

    /// Palettes are picked when a scene is built, so a new pick rebuilds it if it's on the desktop.
    private func rebuildIfShowing() {
        if wallpaper.name == current { switchScene() }
    }
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
        case .times: "\(Int(value.rounded()))×"
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
            swatch("Random", colours: choice.options.compactMap { (scheme == .dark ? $0.dark : $0.light).last }, symbol: "shuffle")
            ForEach(choice.options, id: \.name) { option in
                swatch(option.name, colours: scheme == .dark ? option.dark : option.light)
            }
        }
        .padding(.vertical, 6)
    }

    private func swatch(_ name: String, colours: [SIMD3<Float>], symbol: String? = nil) -> some View {
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
                    .overlay { if let symbol { Image(systemName: symbol).font(.title3.bold()).foregroundStyle(.white) } }
                    .overlay { RoundedRectangle(cornerRadius: 15).strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2.5).padding(-4) }
                Text(name).font(.caption).foregroundStyle(isSelected ? .primary : .secondary).lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}
