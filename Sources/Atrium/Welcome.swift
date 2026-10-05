import ImageIO
import ServiceManagement
import SwiftUI

/// The welcome, a sheet over Settings on first launch and from About → Show Welcome: tap a wallpaper to put it on the
/// desktop (as many as you like, to try them), allow location if they use it, then a few switches.
/// Skipping keeps the wallpaper last tapped and changes nothing else.
struct WelcomeView: View {
    /// Set to show the welcome; Settings shows it over whatever page is open.
    static let key = "welcome.show"
    /// The wallpapers by mood, as the README groups them. Any wallpaper not listed joins the last group.
    static let groups: [(name: String, members: [String])] = [
        ("Nature and weather", ["Fish Tank", "Weather", "A Tree for the Year", "Dappled Light", "Rain on Glass", "Wind",
                                "Murmuration", "Aurora", "Fireflies", "Campfire"]),
        ("Space", ["Solar System Tour", "Deep Space Tour", "Nebula", "Galaxy", "Live Sky", "Earth from Orbit", "Pixel Spaceport"]),
        ("Color, light and pattern", ["Flowing Gradient", "Lava Lamp", "Schlieren", "Turing Patterns", "Game of Life", "Pixel City"]),
    ]
    /// Wallpapers that follow the sky, weather, light or seasons where you are, so they ask for your location.
    static let local: Set<String> = ["Live Sky", "Earth from Orbit", "Weather", "A Tree for the Year", "Dappled Light", "Wind",
                                     "Pixel City", "Pixel Spaceport", "Campfire", "Solar System Tour", "Flowing Gradient"]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    private enum Step { case pick, location, switches }
    @State private var step = Step.pick
    @AppStorage("scene") private var current = defaultScene.name
    /// On for a new user, so they meet every wallpaper; otherwise as Shuffle is.
    @State private var shuffle = UserDefaults.standard.object(forKey: Shuffle.on.key) == nil || Shuffle.on.value > 0.5
    @State private var openAtLogin = SMAppService.mainApp.status == .enabled
    @State private var matchLockScreen = LockScreen.knob.value > 0.5
    @State private var fullSpeed = Power.battery.value >= Power.plugged.value

    private var steps: [Step] {
        Location.shared.undecided && (shuffle || Self.local.contains(current)) ? [.pick, .location, .switches] : [.pick, .switches]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 52, height: 52).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome to Atrium").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                    Text(subtitle).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding([.horizontal, .top], 24)
            .padding(.bottom, 12)

            switch step {
            case .pick: picking
            case .location: location
            case .switches: switches
            }

            HStack {
                if step == .pick {
                    Button("Skip") { dismiss() }
                } else {
                    Button("Back") { move(-1) }
                }
                Spacer()
                HStack(spacing: 6) { // where you are
                    ForEach(steps.indices, id: \.self) { i in
                        Circle().fill(steps[i] == step ? Color.primary : Color.secondary.opacity(0.35)).frame(width: 6, height: 6)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel("Step \((steps.firstIndex(of: step) ?? 0) + 1) of \(steps.count)")
                Spacer()
                if step == steps.last {
                    Button("Done", action: finish).buttonStyle(.glassProminent).keyboardShortcut(.defaultAction)
                } else {
                    Button("Continue") { move(1) }.buttonStyle(.glassProminent).keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
        }
        .frame(width: 760, height: 600)
    }

    private var subtitle: String {
        switch step {
        case .pick: "Tap a wallpaper to put it on your desktop. Try as many as you like."
        case .location: "Some wallpapers show the real sky, weather and light where you are."
        case .switches: "A few last choices. Everything here is in Settings too."
        }
    }

    // MARK: Steps

    private var picking: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(groupsShown, id: \.name) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.name).font(.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                            ForEach(group.members, id: \.self) { tile($0) }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
    }

    private var location: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "location.circle.fill").font(.system(size: 54)).foregroundStyle(.tint).accessibilityHidden(true)
            Text("Live Sky, Weather, Dappled Light and the others follow where you are: the real stars overhead, today's weather, the Sun's angle on the wall, your seasons. Atrium only needs a rough location, and sends it rounded to about a kilometer. Without it, it guesses from your time zone.")
                .multilineTextAlignment(.center).frame(maxWidth: 520)
            Button("Allow Location…") {
                Location.shared.start()
                move(1)
            }
            .buttonStyle(.glass)
            Button("Not Now") { move(1) }.buttonStyle(.link)
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var switches: some View {
        Form {
            Section {
                Toggle("Open at Login", isOn: $openAtLogin)
            } footer: {
                Text("Starts Atrium when you log in, so your wallpaper is always there.").foregroundStyle(.secondary)
            }
            Section {
                Toggle("Match the lock screen", isOn: $matchLockScreen)
            } footer: {
                Text("Sets your Mac's own wallpaper to a still of Atrium's, so the lock screen and the tint of windows match. Yours comes back when you turn this off or quit.")
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle("Shuffle between all wallpapers automatically", isOn: $shuffle)
            } footer: {
                Text("Moves on to a different wallpaper \(shuffleInterval), so you get to see them all. Change how often, or leave some out, in Settings → General.")
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle("Full speed on battery", isOn: $fullSpeed)
            } footer: {
                Text("On battery Atrium runs at 30 fps, about half the power of 60. Turn this on for the smoothest motion anyway.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: Picking

    /// The groups, with any wallpaper they don't list added to the last, so a new wallpaper is never left out.
    private var groupsShown: [(name: String, members: [String])] {
        let listed = Set(Self.groups.flatMap(\.members)), names = scenes.map(\.name)
        var groups = Self.groups.map { (name: $0.name, members: $0.members.filter(names.contains)) }
        groups[groups.count - 1].members += names.filter { !listed.contains($0) }
        return groups
    }

    private func tile(_ name: String) -> some View {
        let picked = name == current
        return Button {
            show(name)
        } label: {
            VStack(spacing: 6) {
                Color.clear
                    .aspectRatio(1512.0 / 982.0, contentMode: .fit)
                    .overlay { if let image = thumbnail(name) { Image(nsImage: image).resizable().scaledToFill() } }
                    .clipShape(.rect(cornerRadius: 10))
                    .overlay(alignment: .topTrailing) {
                        if picked {
                            Image(systemName: "checkmark.circle.fill").font(.title2).symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.accentColor).padding(6)
                        }
                    }
                    .overlay { RoundedRectangle(cornerRadius: 13).strokeBorder(picked ? Color.accentColor : .clear, lineWidth: 3).padding(-3) }
                Text(name).font(.callout).foregroundStyle(picked ? .primary : .secondary).lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(picked ? .isSelected : [])
    }

    private static var thumbnails: [String: NSImage] = [:]

    /// The wallpaper's screenshot, decoded small: 22 full-size ones would take about 80 MB.
    private func thumbnail(_ name: String) -> NSImage? {
        guard let wallpaper = scenes.first(where: { $0.name == name }) else { return nil }
        let url = wallpaper.preview(light: scheme == .light)
        if let image = Self.thumbnails[url.path] { return image }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                                                           kCGImageSourceThumbnailMaxPixelSize: 400] as CFDictionary)
        else { return nil }
        let thumbnail = NSImage(cgImage: image, size: .zero)
        Self.thumbnails[url.path] = thumbnail
        return thumbnail
    }

    // MARK: Moving on

    private var shuffleInterval: String {
        if case .choice(let names) = Shuffle.every.format {
            return names[min(max(Int(Shuffle.every.value), 0), names.count - 1)].lowercased()
        }
        return "every so often"
    }

    private func move(_ by: Int) {
        let i = (steps.firstIndex(of: step) ?? 0) + by
        if steps.indices.contains(i) { step = steps[i] }
    }

    /// Applies the switches, Shuffle taking in every wallpaper, and leaves Settings on the wallpaper picked.
    private func finish() {
        UserDefaults.standard.set(current, forKey: SettingsView.pageKey)
        UserDefaults.standard.set(shuffle ? 1.0 : 0.0, forKey: Shuffle.on.key)
        if shuffle { UserDefaults.standard.removeObject(forKey: Shuffle.skipKey) }
        if openAtLogin != (SMAppService.mainApp.status == .enabled) { setOpenAtLogin(openAtLogin) }
        UserDefaults.standard.set(matchLockScreen ? 1.0 : 0.0, forKey: LockScreen.knob.key)
        if fullSpeed {
            UserDefaults.standard.set(Power.plugged.value, forKey: Power.battery.key)
        } else if Power.battery.value >= Power.plugged.value {
            UserDefaults.standard.removeObject(forKey: Power.battery.key)
        }
        dismiss()
    }
}
