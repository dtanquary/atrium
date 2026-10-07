import AppKit
import Observation
import Security
import SwiftUI

/// Keeps Atrium up to date from its releases on GitHub. Once a day, while `automatic` is on, `check()` looks for a newer
/// release and, if there is one, opens Settings → Software Update to offer it. Installing downloads the disk image,
/// checks the app in it is intact and signed by the same developer as this one, puts it in place of this one and
/// relaunches. Only a Developer ID build updates itself: one from build.sh is ad-hoc signed, and updates with git pull.
@MainActor @Observable final class Updater {
    static let shared = Updater()
    static let automatic = Knob(key: "update.automatic", label: "Check for updates automatically", range: 0...1, standard: 1, format: .toggle)
    private static let checkedKey = "update.checked"
    private static let feed = URL(string: "https://api.github.com/repos/dtanquary/atrium/releases?per_page=10")!
    /// This build's version and prerelease label ("beta", "rc 1" or none), from build.sh.
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    static let prerelease = Bundle.main.object(forInfoDictionaryKey: "AtriumPrerelease") as? String ?? ""

    /// A release on GitHub: its version ("0.95.0", from the tag "v0.95.0-beta"), notes in Markdown, disk image and page.
    struct Release: Equatable { let version: String, notes: String, dmg: URL, page: URL }
    enum State: Equatable { case idle, checking, upToDate, available, downloading, installing, failed(String) }

    private(set) var state = State.idle
    /// The newer release, once one is found.
    private(set) var release: Release?
    /// The disk image's download, while it runs.
    private(set) var download: URLSessionDownloadTask?
    /// Whether this copy can update itself: signed with a Developer ID, not built from source.
    let updatable = Updater.requirement() != nil
    /// When GitHub last answered.
    var checked: Date? { UserDefaults.standard.object(forKey: Self.checkedKey) as? Date }

    /// Looks for a newer release: now with `force` (Check Now, or opening Software Update), otherwise only while
    /// automatic checks are on and a day has passed since GitHub last answered. One found by a daily look opens Settings
    /// to offer it, again each day until it's installed. Offline, a daily look tries again at the next call.
    func check(force: Bool = false) {
        guard updatable, state != .checking, state != .installing, download == nil,
              force || Self.automatic.value > 0.5 && Date().timeIntervalSince(checked ?? .distantPast) > 86400 else { return }
        let before = state
        state = .checking
        Task {
            guard let (data, response) = try? await URLSession.shared.data(from: Self.feed),
                  (response as? HTTPURLResponse)?.statusCode == 200 else {
                state = force ? .failed("Couldn't reach GitHub. Check your connection and try again.") : before
                return
            }
            UserDefaults.standard.set(Date(), forKey: Self.checkedKey)
            release = Self.newest(from: data, version: Self.version, prerelease: Self.prerelease)
            state = release == nil ? .upToDate : .available
            if release != nil, !force { SettingsWindow.shared.open(page: UpdatePage.tag) }
        }
    }

    /// Downloads the release's disk image, installs the app in it, and relaunches.
    func install() {
        guard let release, download == nil else { return }
        state = .downloading
        let task = URLSession.shared.downloadTask(with: release.dmg) { @Sendable file, response, error in
            let problem: String? // nil once installed, empty if cancelled
            do {
                guard let file, (response as? HTTPURLResponse)?.statusCode == 200 else { throw error ?? URLError(.badServerResponse) }
                Task { @MainActor in if Updater.shared.state == .downloading { Updater.shared.state = .installing } }
                try Updater.swap(in: file)
                problem = nil
            } catch {
                problem = (error as? URLError)?.code == .cancelled ? "" : error.localizedDescription
            }
            Task { @MainActor in Updater.shared.finished(problem) }
        }
        download = task
        task.resume()
    }

    /// Stops the download.
    func cancel() { download?.cancel() }

    private func finished(_ problem: String?) {
        download = nil
        switch problem {
        case nil: relaunch()
        case ""?: state = .available
        case let problem?: state = .failed(problem)
        }
    }

    /// Opens this app's path again once this copy has quit, and quits, so the update takes over. It exits rather than
    /// quitting, as `pkill` does, so Match the lock screen leaves the stills and the user's saved wallpaper to the new
    /// copy: put back on quitting, the user's own was lost, as macOS still reported the still to the new copy a moment
    /// later, which it doesn't save as theirs.
    private func relaunch() {
        let wait = "while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done; open \"$0\""
        _ = try? Process.run(URL(filePath: "/bin/sh"), arguments: ["-c", wait, Bundle.main.bundleURL.path])
        exit(0)
    }

    /// The newest release in a GitHub `releases` reply, if it's newer than `version` with its `prerelease` label.
    /// Prereleases count only while this build is one: until 1.0, every release is.
    // ponytail: one release candidate to the next ("rc 1" to "rc 2") isn't seen as newer; compare the labels if RCs pile up
    nonisolated static func newest(from reply: Data, version: String, prerelease: String) -> Release? {
        struct Entry: Decodable {
            struct Asset: Decodable { let name: String, browserDownloadUrl: URL }
            let tagName: String, body: String?, htmlUrl: URL, draft: Bool, prerelease: Bool, assets: [Asset]
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let entry = (try? decoder.decode([Entry].self, from: reply))?.first(where: { !$0.draft && (!$0.prerelease || !prerelease.isEmpty) }),
              let dmg = entry.assets.first(where: { $0.name.hasSuffix(".dmg") }) else { return nil }
        let tag = entry.tagName.trimmingPrefix("v").split(separator: "-", maxSplits: 1)
        let number = String(tag.first ?? "")
        let newer = switch number.compare(version, options: .numeric) {
        case .orderedDescending: true
        case .orderedSame: !prerelease.isEmpty && tag.count == 1 // the release that follows this build's candidate
        case .orderedAscending: false
        }
        return newer ? Release(version: number, notes: entry.body ?? "", dmg: dmg.browserDownloadUrl, page: entry.htmlUrl) : nil
    }

    /// Puts the app in the disk image `dmg` in place of this one, if it's intact and signed as this one is.
    nonisolated static func swap(in dmg: URL) throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "Atrium update \(UUID().uuidString)")
        let image = folder.appending(path: "Atrium.dmg"), volume = folder.appending(path: "Volume"), app = folder.appending(path: "Atrium.app")
        try FileManager.default.createDirectory(at: volume, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.moveItem(at: dmg, to: image)
        try run("/usr/sbin/diskutil", "image", "attach", "--readOnly", "--nobrowse", "--mountPoint", volume.path, image.path)
        defer { try? run("/usr/sbin/diskutil", "eject", volume.path) }
        try run("/usr/bin/ditto", volume.appending(path: "Atrium.app").path, app.path)
        guard let requirement = requirement(), signed(app, meets: requirement) else { throw Failure("The update isn't signed by Atrium's developer.") }
        _ = try FileManager.default.replaceItemAt(Bundle.main.bundleURL, withItemAt: app)
    }

    /// This app's designated requirement, which an update has to meet too, if it's signed with a Developer ID.
    nonisolated static func requirement() -> SecRequirement? {
        var code: SecStaticCode?, info: CFDictionary?, requirement: SecRequirement?
        guard SecStaticCodeCreateWithPath(Bundle.main.bundleURL as CFURL, [], &code) == errSecSuccess, let code,
              SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              (info as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] != nil,
              SecCodeCopyDesignatedRequirement(code, [], &requirement) == errSecSuccess else { return nil }
        return requirement
    }

    /// Whether the app at `url` is intact, every file as signed, and signed to meet `requirement`.
    nonisolated static func signed(_ url: URL, meets requirement: SecRequirement) -> Bool {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code else { return false }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode)
        return SecStaticCodeCheckValidity(code, flags, requirement) == errSecSuccess
    }

    nonisolated private static func run(_ tool: String, _ arguments: String...) throws {
        let process = Process()
        process.executableURL = URL(filePath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw Failure("\(process.executableURL!.lastPathComponent) failed (\(process.terminationStatus)).") }
    }

    struct Failure: LocalizedError {
        let errorDescription: String?
        init(_ description: String) { errorDescription = description }
    }
}

/// Settings → Software Update, like System Settings': the version running, any newer one with its notes and Install
/// and Relaunch, the download as it runs, and the daily check's switch. Opening it looks for an update.
struct UpdatePage: View {
    static let tag = "Software Update" // sidebar selection; can't clash with a wallpaper name
    private let updater = Updater.shared

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 64, height: 64).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(headline).font(.title3.bold())
                        Text(detail).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                    Spacer()
                    action
                }
                .padding(.vertical, 6)
                if updater.state == .downloading, let task = updater.download {
                    TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                        ProgressView(value: task.progress.fractionCompleted) {
                            Text(task.countOfBytesExpectedToReceive > 0
                                 ? "\(bytes(task.countOfBytesReceived)) of \(bytes(task.countOfBytesExpectedToReceive))" : "Starting…")
                                .font(.callout).foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                }
            }
            if let release = updater.release, updater.state != .upToDate {
                Section("What's New in \(release.version)") {
                    Text(Self.notes(release.notes)).textSelection(.enabled)
                    Link("Release notes on GitHub", destination: release.page)
                }
            }
            if updater.updatable {
                Section {
                    KnobRow(knob: Updater.automatic)
                } footer: {
                    Text("Atrium looks for a new version on GitHub once a day, and shows it here. Before it's installed, Atrium checks the update is signed by its developer. Your settings carry over.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .task { if updater.state == .idle { updater.check(force: true) } }
    }

    private var headline: String {
        let next = updater.release?.version ?? ""
        return switch updater.state {
        case _ where !updater.updatable: "Atrium \(Updater.version)"
        case .idle, .checking: "Checking for Updates…"
        case .upToDate: "Atrium Is Up to Date"
        case .available: "Atrium \(next) Is Available"
        case .downloading: "Downloading Atrium \(next)…"
        case .installing: "Installing Atrium \(next)…"
        case .failed: "Couldn't Update Atrium"
        }
    }

    private var detail: String {
        let running = "Version \(Updater.version)" + (Updater.prerelease.isEmpty ? "" : " \(Updater.prerelease)")
        switch updater.state {
        case _ where !updater.updatable: return "Built from source. Update with git pull && ./build.sh."
        case .upToDate:
            let checked = updater.checked.map { $0 > .now - 60 ? "just now" : $0.formatted(.relative(presentation: .named)) }
            return running + (checked.map { " · Checked \($0)" } ?? "")
        case .available: return "You have \(running). Atrium quits and reopens to install it."
        case .downloading, .installing: return "Atrium will quit and reopen with the new version."
        case .failed(let problem): return problem
        case .idle, .checking: return running
        }
    }

    @ViewBuilder private var action: some View {
        if updater.updatable {
            switch updater.state {
            case .idle, .checking, .installing: ProgressView().controlSize(.small)
            case .upToDate: Button("Check Now") { updater.check(force: true) }
            case .available: Button("Install and Relaunch", action: updater.install).buttonStyle(.borderedProminent)
            case .downloading: Button("Cancel", action: updater.cancel)
            case .failed:
                if let release = updater.release {
                    Link("Download…", destination: release.page)
                    Button("Try Again", action: updater.install)
                } else {
                    Button("Try Again") { updater.check(force: true) }
                }
            }
        }
    }

    private func bytes(_ count: Int64) -> String { count.formatted(.byteCount(style: .file)) }

    /// A release's notes, from GitHub's Markdown: headings in bold, bullets as bullets, links and emphasis kept.
    static func notes(_ markdown: String) -> AttributedString {
        let lines = markdown.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map { line in
            line.hasPrefix("#") ? "**\(line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces))**"
                : line.hasPrefix("- ") ? "• " + line.dropFirst(2) : String(line)
        }
        let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }
}
