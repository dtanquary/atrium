import AppKit
import CryptoKit
import Observation
import OSLog
import Security
import SwiftUI

// Not in the App Store build (APP_STORE, see docs/app-store.md): the App Store updates its own apps, and its rules
// allow no other way.
#if !APP_STORE
/// Keeps Atrium up to date from its releases on GitHub. Once a day, while `automatic` is on, `check()` looks for a newer
/// release and, if there is one, opens Settings → Software Update to offer it, once for each release and behind the app
/// in front, so it never pulls anyone out of what they're doing. Installing fetches only the files this copy lacks,
/// each from its place in the release's disk image, builds the new app from them and this copy's own, checks it's
/// intact and signed by the same developer as this one, puts it in place of this one and relaunches. If any of that
/// fails, short of being cancelled, it downloads the whole disk image instead. Only a Developer ID build updates itself: one from build.sh is
/// ad-hoc signed, and updates with git pull. docs/updates.md has the reasons and what was measured.
@MainActor @Observable final class Updater {
    static let shared = Updater()
    static let automatic = Knob(key: "update.automatic", label: "Check for updates automatically", range: 0...1, standard: 1, format: .toggle)
    private static let checkedKey = "update.checked"
    /// The release a daily look last opened Settings for.
    private static let offeredKey = "update.offered"
    private static let feed = URL(string: "https://api.github.com/repos/dtanquary/atrium/releases?per_page=10")!
    private static let log = Logger(subsystem: "com.dtanquary.atrium", category: "update")
    /// This build's version and prerelease label ("beta", "rc 1" or none), from build.sh.
    nonisolated static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    static let prerelease = Bundle.main.object(forInfoDictionaryKey: "AtriumPrerelease") as? String ?? ""

    /// A release on GitHub: its version ("0.95.0", from the tag "v0.95.0-beta"), notes in Markdown, disk image, the
    /// list of the files in that image (release.sh's, on a release that has one) and page.
    struct Release: Equatable { let version: String, notes: String, dmg: URL, files: URL?, page: URL }
    /// A release's notes for Software Update's list: its version as tagged ("0.95.0 beta"), when it came out and its page.
    struct Notes { let version: String, date: Date?, notes: String, page: URL }
    /// One of the app's files as release.sh lists it: its SHA-256, size, where it starts in the disk image, its
    /// permissions (644, or 755 for one that runs) and its path in the bundle.
    struct Listed: Equatable { let hash: String, size: Int, offset: Int, mode: Int, path: String }
    enum State: Equatable { case idle, checking, upToDate, available, downloading, installing, failed(String) }

    private(set) var state = State.idle
    /// The newer release, once one is found.
    private(set) var release: Release?
    /// Every release's notes from the last look, newest first.
    private(set) var history: [Notes] = []
    /// The disk image's download, while it runs.
    private(set) var download: URLSessionDownloadTask?
    /// The update file by file, while it runs, and the bytes it has fetched of those this copy lacks.
    private(set) var patch: Task<Void, Never>?
    private(set) var fetched = 0
    private(set) var lacking = 0
    /// How much of the update has arrived, and of how much: the files this copy lacks, or the whole disk image.
    var progress: (done: Int64, of: Int64) {
        download.map { ($0.countOfBytesReceived, $0.countOfBytesExpectedToReceive) } ?? (Int64(fetched), Int64(lacking))
    }
    /// Whether this copy can update itself: signed with a Developer ID, not built from source.
    let updatable = Updater.requirement() != nil
    /// When GitHub last answered.
    var checked: Date? { UserDefaults.standard.object(forKey: Self.checkedKey) as? Date }

    /// Looks for a newer release: now with `force` (Check Now, or opening Software Update), otherwise only while
    /// automatic checks are on and a day has passed since GitHub last answered. One found by a daily look opens Settings
    /// to offer it the first time, behind the app in front; the menu offers it from then on. Offline, a daily look tries
    /// again at the next call. A copy built from source looks only when forced, for the notes, and is offered nothing.
    func check(force: Bool = false) {
        guard state != .checking, state != .installing, download == nil, patch == nil,
              force || updatable && Self.automatic.value > 0.5 && abs(Date().timeIntervalSince(checked ?? .distantPast)) > 86400 else { return }
        let before = state
        state = .checking
        Task {
            guard let (data, response) = try? await URLSession.shared.data(from: Self.feed),
                  (response as? HTTPURLResponse)?.statusCode == 200 else {
                state = force ? .failed("Couldn't reach GitHub. Check your connection and try again.") : before
                return
            }
            UserDefaults.standard.set(Date(), forKey: Self.checkedKey)
            history = Self.history(from: data, prerelease: Self.prerelease)
            release = updatable ? Self.newest(from: data, version: Self.version, prerelease: Self.prerelease) : nil
            state = release == nil ? .upToDate : .available
            if let release, !force, UserDefaults.standard.string(forKey: Self.offeredKey) != release.version {
                UserDefaults.standard.set(release.version, forKey: Self.offeredKey)
                SettingsWindow.shared.open(page: UpdatePage.tag, activate: false)
            }
        }
    }

    /// Installs the release and relaunches. Where the release lists its files, only those this copy lacks are fetched
    /// and the new app is built from them and this copy's own (`rebuild`); without a list, or if that fails for any
    /// reason but being cancelled, the whole disk image is downloaded.
    func install() {
        guard let release, download == nil, patch == nil else { return }
        state = .downloading
        guard let files = release.files else { return downloadImage(release) }
        (fetched, lacking) = (0, 0)
        patch = Task {
            defer { patch = nil }
            do {
                try await Self.rebuild(from: release.dmg, listed: files) { done, of in
                    Task { @MainActor in (Updater.shared.fetched, Updater.shared.lacking) = (done, of) }
                }
                relaunch()
            } catch {
                guard !Task.isCancelled else { return state = .available }
                Self.log.notice("Updating file by file failed, so downloading the disk image: \(error.localizedDescription, privacy: .public)")
                downloadImage(release)
            }
        }
    }

    /// Downloads the release's whole disk image, installs the app in it, and relaunches.
    private func downloadImage(_ release: Release) {
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
    func cancel() {
        download?.cancel()
        patch?.cancel()
    }

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
        guard (try? Process.run(URL(filePath: "/bin/sh"), arguments: ["-c", wait, Bundle.main.bundleURL.path])) != nil else {
            state = .failed("The update is installed, but Atrium couldn't reopen itself. Quit Atrium and open it again.")
            return
        }
        exit(0)
    }

    /// The newest release in a GitHub `releases` reply, if it's newer than `version` with its `prerelease` label.
    /// Prereleases count only while this build is one: until 1.0, every release is. Of the same version, the final
    /// release follows any candidate, and a later label another ("rc2" after "rc 1", "rc1" after "beta"); one of those
    /// is named as tagged ("1.0.0-rc2"), so it doesn't read as this version.
    nonisolated static func newest(from reply: Data, version: String, prerelease: String) -> Release? {
        guard let entry = entries(reply, prerelease: prerelease).first, let dmg = entry.assets.first(where: { $0.name.hasSuffix(".dmg") }) else { return nil }
        let tag = entry.tagName.trimmingPrefix("v").split(separator: "-", maxSplits: 1)
        let number = String(tag.first ?? "")
        let order = number.compare(version, options: .numeric)
        let newer = switch order {
        case .orderedDescending: true
        case .orderedSame: !prerelease.isEmpty && (tag.count == 1 || tag[1].compare(prerelease.replacing(" ", with: ""), options: .numeric) == .orderedDescending)
        case .orderedAscending: false
        }
        return newer ? Release(version: order == .orderedSame && tag.count == 2 ? tag.joined(separator: "-") : number, notes: entry.body ?? "",
                               dmg: dmg.browserDownloadUrl, files: entry.assets.first { $0.name.hasSuffix(".files") }?.browserDownloadUrl,
                               page: entry.htmlUrl) : nil
    }

    /// Every release's notes in a GitHub `releases` reply that `newest` would consider, newest first.
    nonisolated static func history(from reply: Data, prerelease: String) -> [Notes] {
        entries(reply, prerelease: prerelease).map {
            Notes(version: String($0.tagName.trimmingPrefix("v").replacing("-", with: " ")), date: $0.publishedAt, notes: $0.body ?? "", page: $0.htmlUrl)
        }
    }

    private struct Entry: Decodable {
        struct Asset: Decodable { let name: String, browserDownloadUrl: URL }
        let tagName: String, body: String?, htmlUrl: URL, publishedAt: Date?, draft: Bool, prerelease: Bool, assets: [Asset]
    }

    /// The releases in a GitHub `releases` reply, newest first, less drafts, and less prereleases unless this build is one.
    nonisolated private static func entries(_ reply: Data, prerelease: String) -> [Entry] {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return ((try? decoder.decode([Entry].self, from: reply)) ?? []).filter { !$0.draft && (!$0.prerelease || !prerelease.isEmpty) }
    }

    /// Reads release.sh's list: a line for each file, its fields separated by tabs. Nil unless every line is well
    /// formed, with a plain path that stays inside the bundle and one of the two permissions release.sh writes, as
    /// the list comes off the network and says where files are written.
    nonisolated static func listed(_ text: String) -> [Listed]? {
        let sane = 0..<1 << 31 // GitHub's 2 GiB a file: nothing in an image is bigger or further in, and these add up without overflowing
        let list = text.split(whereSeparator: \.isNewline).map { line -> Listed? in
            let fields = line.split(separator: "\t", maxSplits: 4, omittingEmptySubsequences: false)
            guard fields.count == 5, fields[0].count == 64, let size = Int(fields[1]), let offset = Int(fields[2]), sane ~= size, sane ~= offset,
                  let mode = Int(fields[3], radix: 8), mode == 0o644 || mode == 0o755, fields[4].unicodeScalars.allSatisfy({ $0.value >= 0x20 }),
                  fields[4].split(separator: "/", omittingEmptySubsequences: false).allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else { return nil }
            return Listed(hash: String(fields[0]), size: size, offset: offset, mode: mode, path: String(fields[4]))
        }
        return list.isEmpty || list.contains(nil) ? nil : list.compactMap { $0 }
    }

    /// Builds the app `list` describes at `app`. A file that `old` has, under any name, is cloned from it, so it takes
    /// no room and a renamed photo isn't fetched again; the rest are asked of `fetch` and checked against the list.
    /// `progress` hears the bytes fetched so far, and how many `old` lacks: none means the list is of the app `old`
    /// already is, and that's an error, as every release differs at least in its Info.plist. The code signature
    /// vouches for every file's bytes but not its permissions, so those come from the list, and a clone leaves behind
    /// the quarantine mark of the day the app was first downloaded, as a copy from the disk image has none. Folders
    /// are made open to read whatever the user's umask, as the image's are.
    nonisolated static func assemble(_ list: [Listed], from old: URL, at app: URL, progress: (Int, Int) -> Void = { _, _ in },
                                     fetch: (Listed) async throws -> Data) async throws {
        let files = FileManager.default
        var have: [String: URL] = [:]
        let found = files.enumerator(at: old, includingPropertiesForKeys: [.isRegularFileKey])
        while let file = found?.nextObject() as? URL {
            guard (try? file.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true,
                  let data = try? Data(contentsOf: file, options: .mappedIfSafe) else { continue }
            have[hash(data)] = file
        }
        let lacking = Dictionary(list.filter { have[$0.hash] == nil }.map { ($0.hash, $0.size) }) { size, _ in size }.values.reduce(0, +)
        guard lacking > 0 else { throw Failure("The release's list of files is of this version.") }
        var fetched = 0
        progress(0, lacking)
        for file in list {
            try Task.checkCancellation()
            let to = app.appending(path: file.path)
            try files.createDirectory(at: to.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o755])
            if let from = have[file.hash] {
                try files.copyItem(at: from, to: to)
                removexattr(to.path, "com.apple.quarantine", 0)
            } else {
                let data = file.size == 0 ? Data() : try await fetch(file)
                guard data.count == file.size, hash(data) == file.hash else { throw Failure("\(file.path) didn't arrive whole.") }
                try data.write(to: to)
                have[file.hash] = to
                fetched += file.size
                progress(fetched, lacking)
            }
            try files.setAttributes([.posixPermissions: file.mode], ofItemAtPath: to.path)
        }
    }

    /// Builds the release's app at `app` from the copy at `old` and the disk image at `image`, whose files the list at
    /// `list` names: each one `old` lacks is fetched from its place in the image with a request for that range.
    nonisolated static func build(_ app: URL, from image: URL, listed list: URL, on old: URL, progress: (Int, Int) -> Void = { _, _ in }) async throws {
        let (text, response) = try await URLSession.shared.data(from: list)
        guard (response as? HTTPURLResponse)?.statusCode == 200, let list = listed(String(decoding: text, as: UTF8.self)) else {
            throw Failure("The release's list of files can't be read.")
        }
        // GitHub answers with a redirect to its storage, at an address that's good for about an hour: ask there while
        // it lasts, and GitHub again once it has run out.
        var source = image
        try await assemble(list, from: old, at: app, progress: progress) { file in
            var got = source == image ? nil : try? await bytes(of: file, in: source)
            if got == nil { got = try await bytes(of: file, in: image) }
            source = got!.from
            return got!.data
        }
    }

    /// The bytes of `file` from its place in the disk image at `image`, and the address that sent them after any
    /// redirect. It reads the reply's status before its body, so a server that ignores the range and starts on the
    /// whole image is cut off at once: GitHub honours one range a request today, but promises nothing.
    nonisolated private static func bytes(of file: Listed, in image: URL) async throws -> (data: Data, from: URL) {
        var request = URLRequest(url: image, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("bytes=\(file.offset)-\(file.offset + file.size - 1)", forHTTPHeaderField: "Range")
        let (body, response) = try await URLSession.shared.bytes(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 206, response.expectedContentLength == Int64(file.size) else {
            body.task.cancel()
            throw Failure("The disk image's host wouldn't send \(file.path) alone (\((response as? HTTPURLResponse)?.statusCode ?? 0)).")
        }
        // ponytail: one file at a time, read into memory a byte at a time (about 30 MB a second in a debug build).
        // Right for photos of a few MB; stream to disk and fetch several at once if a release ever adds a file of
        // hundreds of MB, or thousands of files.
        var data = Data(capacity: file.size)
        for try await byte in body { data.append(byte) }
        return (data, response.url ?? image)
    }

    /// Updates this copy file by file from the disk image at `image` and its list at `files`, as `build` does.
    nonisolated static func rebuild(from image: URL, listed files: URL, progress: @Sendable (Int, Int) -> Void) async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "Atrium update \(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let app = folder.appending(path: "Atrium.app")
        try await build(app, from: image, listed: files, on: Bundle.main.bundleURL, progress: progress)
        try Task.checkCancellation()
        try put(app)
    }

    nonisolated private static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

    /// Puts the app in the disk image `dmg` in place of this one, as `put` does.
    nonisolated static func swap(in dmg: URL) throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "Atrium update \(UUID().uuidString)")
        let image = folder.appending(path: "Atrium.dmg"), volume = folder.appending(path: "Volume"), app = folder.appending(path: "Atrium.app")
        try FileManager.default.createDirectory(at: volume, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.moveItem(at: dmg, to: image)
        try run("/usr/sbin/diskutil", "image", "attach", "--readOnly", "--nobrowse", "--mountPoint", volume.path, image.path)
        defer { try? run("/usr/sbin/diskutil", "eject", volume.path) }
        try run("/usr/bin/ditto", volume.appending(path: "Atrium.app").path, app.path)
        try put(app)
    }

    /// Puts the app at `app` in place of this one, if it's intact, signed as this one is, able to run and no older.
    /// The signature vouches for the developer and every file's bytes, but not for the executable's permission to run
    /// (an app without it passes, and never opens again), nor for which version it is: an old one is signed just as well.
    nonisolated static func put(_ app: URL) throws {
        guard let requirement = requirement(), signed(app, meets: requirement) else { throw Failure("The update isn't signed by Atrium's developer.") }
        guard let binary = Bundle(url: app)?.executableURL, FileManager.default.isExecutableFile(atPath: binary.path) else { throw Failure("The update can't be opened.") }
        guard let new = NSDictionary(contentsOf: app.appending(path: "Contents/Info.plist"))?["CFBundleShortVersionString"] as? String,
              new.compare(version, options: .numeric) != .orderedAscending else { throw Failure("The update is older than this version.") }
        _ = try FileManager.default.replaceItemAt(Bundle.main.bundleURL, withItemAt: app)
    }

    /// The designated requirement of the app at `app` (this one's own, by default), which an update has to meet too,
    /// if it's signed with a Developer ID.
    nonisolated static func requirement(of app: URL = Bundle.main.bundleURL) -> SecRequirement? {
        var code: SecStaticCode?, info: CFDictionary?, requirement: SecRequirement?
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &code) == errSecSuccess, let code,
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
/// and Relaunch, the download as it runs, the daily check's switch, and past releases' notes, folded. Opening it looks
/// for an update.
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
                if updater.state == .downloading {
                    TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                        let (done, of) = updater.progress
                        ProgressView(value: of > 0 ? min(Double(done) / Double(of), 1) : 0) {
                            Text(of > 0 ? "\(bytes(done)) of \(bytes(of))" : "Starting…")
                                .font(.callout).foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                }
            }
            if updater.updatable {
                Section {
                    KnobRow(knob: Updater.automatic)
                } footer: {
                    Text("Atrium looks for a new version on GitHub once a day, and shows it here. An update downloads only the files that changed, and before it's installed, Atrium checks it's signed by its developer. Your settings carry over.")
                        .foregroundStyle(.secondary)
                }
            }
            // The newest release: the one on offer, or else the latest (this version's, unless built from source).
            if let latest = updater.history.first {
                Section(updater.release.map { "What's New in \($0.version)" } ?? "Recently Changed") {
                    if updater.release == nil { label(latest) }
                    Text(Self.notes(latest.notes)).textSelection(.enabled)
                    Link("Release notes on GitHub", destination: latest.page)
                }
            }
            if updater.history.count > 1 {
                Section("Past Updates") {
                    ForEach(updater.history.dropFirst(), id: \.page) { past in
                        DisclosureGroup { Text(Self.notes(past.notes)).textSelection(.enabled) } label: { label(past) }
                    }
                    // ponytail: the feed brings the last ten releases; page through GitHub's if older ones are wanted here.
                    Link("All releases on GitHub", destination: URL(string: "https://github.com/dtanquary/atrium/releases")!)
                }
            }
        }
        .formStyle(.grouped)
        .task { if updater.state == .idle { updater.check(force: true) } }
    }

    private func label(_ release: Updater.Notes) -> some View {
        LabeledContent(release.version) { Text(release.date?.formatted(date: .abbreviated, time: .omitted) ?? "") }
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
#endif
