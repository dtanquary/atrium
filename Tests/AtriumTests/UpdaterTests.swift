import CryptoKit
import Foundation
import Testing
@testable import Atrium

/// The updater offers the newest release from GitHub's reply only when it's newer than this build, skips drafts, and
/// skips prereleases for a stable build. It finds the release's list of files beside the disk image, if there is one.
@MainActor @Test func picksTheNewerRelease() throws {
    func reply(_ releases: [(tag: String, prerelease: Bool, draft: Bool)]) -> Data {
        try! JSONSerialization.data(withJSONObject: releases.map { release in
            ["tag_name": release.tag, "body": "### New\r\n- **Pixel Spaceport**", "draft": release.draft, "prerelease": release.prerelease,
             "html_url": "https://github.com/dtanquary/atrium/releases/tag/\(release.tag)",
             "assets": [["name": "notes.txt", "browser_download_url": "https://example.com/notes.txt"],
                        ["name": "Atrium-\(release.tag).dmg", "browser_download_url": "https://example.com/\(release.tag).dmg"]]
                + (release.tag == "v0.96.0-beta" ? [["name": "Atrium-0.96.0-beta.files", "browser_download_url": "https://example.com/files"]] : [])]
        })
    }
    let betas = reply([("v0.97.0-beta", true, true), ("v0.96.0-beta", true, false), ("v0.95.0-beta", true, false)])
    let offer = try #require(Updater.newest(from: betas, version: "0.95.0", prerelease: "beta"))
    #expect(offer.version == "0.96.0") // not the draft
    #expect(offer.dmg == URL(string: "https://example.com/v0.96.0-beta.dmg"))
    #expect(offer.files == URL(string: "https://example.com/files"))
    #expect(Updater.newest(from: reply([("v0.100.0-beta", true, false)]), version: "0.95.1", prerelease: "beta")?.files == nil) // the whole image, then
    #expect(Updater.newest(from: betas, version: "0.96.0", prerelease: "beta") == nil)
    #expect(Updater.newest(from: betas, version: "0.100.0", prerelease: "beta") == nil) // numbers, not text
    #expect(Updater.newest(from: reply([("v0.100.0-beta", true, false)]), version: "0.95.1", prerelease: "beta")?.version == "0.100.0")

    let stable = reply([("v1.1.0-rc1", true, false), ("v1.0.0", false, false)])
    #expect(Updater.newest(from: stable, version: "1.0.0", prerelease: "") == nil) // no release candidates for a stable build
    #expect(Updater.newest(from: stable, version: "1.0.0", prerelease: "rc 1")?.version == "1.1.0")
    #expect(Updater.newest(from: reply([("v1.0.0", false, false)]), version: "1.0.0", prerelease: "rc 1")?.version == "1.0.0")
    #expect(Updater.newest(from: reply([("v1.0.0-rc2", true, false)]), version: "1.0.0", prerelease: "rc 1")?.version == "1.0.0-rc2")
    #expect(Updater.newest(from: reply([("v1.0.0-rc1", true, false)]), version: "1.0.0", prerelease: "beta")?.version == "1.0.0-rc1")
    #expect(Updater.newest(from: reply([("v1.0.0-rc1", true, false)]), version: "1.0.0", prerelease: "rc 1") == nil)
    #expect(Updater.newest(from: reply([("v1.0.0-rc1", true, false)]), version: "1.0.0", prerelease: "rc 2") == nil)
    #expect(Updater.newest(from: reply([("v1.0.0-rc10", true, false)]), version: "1.0.0", prerelease: "rc 9")?.version == "1.0.0-rc10")
    #expect(Updater.newest(from: Data("{\"message\":\"API rate limit exceeded\"}".utf8), version: "0.1.0", prerelease: "beta") == nil)

    #expect(String(UpdatePage.notes(offer.notes).characters) == "New\n• Pixel Spaceport")
}

/// An update file by file: the new app is built from the old one's files wherever it has the bytes, under any name,
/// only the rest are fetched, nothing of the old app is left over, and permissions come from the list. A list that
/// would write outside the bundle, or asks for other permissions, isn't read at all; a file that arrives wrong stops
/// the update, and so does a list of the app that's already there.
@Test func rebuildsFromItsOwnFiles() async throws {
    let folder = FileManager.default.temporaryDirectory.appending(path: "atrium-update-test-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: folder) }
    func write(_ files: [String: String], to app: String, mode: Int = 0o644) throws {
        for (path, text) in files {
            let file = folder.appending(path: app).appending(path: path)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(text.utf8).write(to: file)
            try FileManager.default.setAttributes([.posixPermissions: mode], ofItemAtPath: file.path)
        }
    }
    try write(["Contents/MacOS/Atrium": "old code", "Contents/Resources/kept.heic": "a photo", "Contents/Resources/before.heic": "renamed",
               "Contents/Resources/cut.heic": "gone in the new one"], to: "old", mode: 0o600)
    let new = ["Contents/MacOS/Atrium": "new code", "Contents/Resources/kept.heic": "a photo", "Contents/Resources/after.heic": "renamed",
               "Contents/Resources/tour/added.heic": "a new photo", "Contents/Resources/empty": ""]
    let text = new.sorted { $0.key < $1.key }.enumerated().map { place, file in
        [SHA256.hash(data: Data(file.value.utf8)).map { String(format: "%02x", $0) }.joined(), "\(file.value.utf8.count)", "\(place * 100)",
         file.key.hasSuffix("MacOS/Atrium") ? "755" : "644", file.key].joined(separator: "\t")
    }.joined(separator: "\n") + "\n"
    let list = try #require(Updater.listed(text))
    #expect(list.count == 5 && list[0].path == "Contents/MacOS/Atrium" && list[0].mode == 0o755 && list[4].offset == 400)

    var asked: [String] = [], heard: [[Int]] = []
    let app = folder.appending(path: "built")
    try await Updater.assemble(list, from: folder.appending(path: "old"), at: app, progress: { heard.append([$0, $1]) }) { file in
        asked.append(file.path)
        return Data(new[file.path]!.utf8)
    }
    #expect(asked == ["Contents/MacOS/Atrium", "Contents/Resources/tour/added.heic"]) // not the kept photo, the renamed one or the empty file
    #expect(heard.first == [0, 19] && heard.last == [19, 19])
    let built = FileManager.default.enumerator(at: app, includingPropertiesForKeys: nil)!.compactMap { $0 as? URL }.filter { !$0.hasDirectoryPath }
    #expect(Set(built.map { String($0.path.split(separator: "/built/").last!) }) == Set(new.keys)) // no cut.heic, no before.heic
    for (path, text) in new {
        let file = app.appending(path: path)
        #expect(try String(contentsOf: file, encoding: .utf8) == text)
        #expect(try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? Int == (path.hasSuffix("MacOS/Atrium") ? 0o755 : 0o644))
    }

    await #expect(throws: Updater.Failure.self) {
        try await Updater.assemble(list, from: folder.appending(path: "old"), at: folder.appending(path: "bad")) { _ in Data("not what was listed".utf8) }
    }
    await #expect(throws: Updater.Failure.self) { // nothing to fetch: the list is of the app it's building from
        try await Updater.assemble(list, from: app, at: folder.appending(path: "same")) { _ in Data() }
    }
    let line = String(text.split(separator: "\n")[0])
    for bad in ["../outside", "/tmp/outside", "Contents//x", "Contents/./x", "Contents/Resources/../../../x", "", "Contents/x\0", "..\0"] {
        #expect(Updater.listed(line.replacing("Contents/MacOS/Atrium", with: bad)) == nil, "the path \(bad)")
    }
    for bad in ["", "abc\t1\t2\t644\tContents/x", String(line.dropFirst(64)), line.replacing("\t8\t", with: "\t-8\t"), line.replacing("\t8\t", with: "\t9223372036854775807\t"),
                line.replacing("\t755\t", with: "\t9\t"), line.replacing("\t755\t", with: "\t600\t"), line.replacing("\t755\t", with: "\t4755\t"),
                line.replacing("\t8\t", with: "\t2147483648\t"), text + "junk"] {
        #expect(Updater.listed(bad) == nil, "the list \(bad)")
    }
}

/// A stand-in for GitHub's release files: at update.test it serves a disk image a single range at a time, as GitHub's
/// storage does, and the image's list; at whole.test it ignores the range and starts on the whole image.
final class ImageHost: URLProtocol, @unchecked Sendable {
    static let files = ["Contents/Info.plist": "version two", "Contents/MacOS/Atrium": "new code", "Contents/Resources/photo.heic": "a photo"]
    /// The image, each file somewhere in it, and the list that says where.
    static let (image, list): (Data, String) = {
        var image = Data(), lines: [String] = []
        for (path, text) in files.sorted(by: { $0.key < $1.key }) {
            image.append(Data(repeating: 35, count: 100 + lines.count * 7))
            lines.append([SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined(), "\(text.utf8.count)", "\(image.count)",
                          path.hasSuffix("MacOS/Atrium") ? "755" : "644", path].joined(separator: "\t"))
            image.append(Data(text.utf8))
        }
        return (image + Data(repeating: 35, count: 50), lines.joined(separator: "\n") + "\n")
    }()

    override class func canInit(with request: URLRequest) -> Bool { request.url?.host?.hasSuffix(".test") == true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    override func startLoading() {
        let url = request.url!
        var status = 200, body = url.pathExtension == "files" ? Data(Self.list.utf8) : Self.image
        if url.pathExtension == "dmg", url.host == "update.test",
           let range = request.value(forHTTPHeaderField: "Range")?.wholeMatch(of: /bytes=(\d+)-(\d+)/), let from = Int(range.1), let to = Int(range.2) {
            (status, body) = (206, Data(Self.image[from...to]))
        }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Length": "\(body.count)"])!,
                            cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
}

/// The fetching itself, against that stand-in: the list is read, each file the old app lacks is asked for by exactly
/// its range of the image, and the app is built with the executable allowed to run. A host that answers a range
/// with the whole image is refused, which in the app means the whole disk image is downloaded instead.
@Test func fetchesEachFileByItsRange() async throws {
    URLProtocol.registerClass(ImageHost.self)
    defer { URLProtocol.unregisterClass(ImageHost.self) }
    let folder = FileManager.default.temporaryDirectory.appending(path: "atrium-update-test-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: folder) }
    let old = folder.appending(path: "old/Contents/Resources"), app = folder.appending(path: "built")
    try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
    try Data("a photo".utf8).write(to: old.appending(path: "photo.heic"))

    var heard: [Int] = []
    try await Updater.build(app, from: URL(string: "https://update.test/Atrium.dmg")!, listed: URL(string: "https://update.test/Atrium.files")!,
                            on: folder.appending(path: "old")) { heard = [$0, $1] }
    #expect(heard == [19, 19]) // the Info.plist and the executable, not the photo it had
    for (path, text) in ImageHost.files { #expect(try String(contentsOf: app.appending(path: path), encoding: .utf8) == text) }
    #expect(FileManager.default.isExecutableFile(atPath: app.appending(path: "Contents/MacOS/Atrium").path))

    await #expect(throws: Updater.Failure.self) {
        try await Updater.build(folder.appending(path: "refused"), from: URL(string: "https://whole.test/Atrium.dmg")!,
                                listed: URL(string: "https://whole.test/Atrium.files")!, on: folder.appending(path: "old"))
    }
}

/// A real update, when asked for: UPDATE_IMAGE is the address of a release's disk image, with its list beside it under
/// the same name ending .files (or at UPDATE_FILES), and UPDATE_FROM an older Atrium.app (the one in /Applications,
/// unless given). It builds the release's app as the updater would, fetching what the older one lacks, and checks it
/// as the updater does: every file as signed, and signed by the older one's developer. docs/updates.md has the recipe.
@Test(.enabled(if: ProcessInfo.processInfo.environment["UPDATE_IMAGE"] != nil)) func updatesFromARelease() async throws {
    let environment = ProcessInfo.processInfo.environment
    let image = try #require(URL(string: environment["UPDATE_IMAGE"]!)), old = URL(filePath: environment["UPDATE_FROM"] ?? "/Applications/Atrium.app")
    let folder = FileManager.default.temporaryDirectory.appending(path: "atrium-update-test-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: folder) }
    let app = folder.appending(path: "Atrium.app"), start = Date()
    var last = (0, 0)
    let list = environment["UPDATE_FILES"].flatMap { URL(string: $0) } ?? image.deletingPathExtension().appendingPathExtension("files")
    try await Updater.build(app, from: image, listed: list, on: old) { last = ($0, $1) }
    let version = { (app: URL) in NSDictionary(contentsOf: app.appending(path: "Contents/Info.plist"))?["CFBundleShortVersionString"] as? String ?? "?" }
    print("Built Atrium \(version(app)) from \(version(old)): fetched \(last.0) of \(last.1) bytes in \(String(format: "%.1f", -start.timeIntervalSinceNow)) s")
    let requirement = try #require(Updater.requirement(of: old), "UPDATE_FROM isn't signed with a Developer ID")
    #expect(Updater.signed(app, meets: requirement))
    #expect(Bundle(url: app)?.executableURL.map { FileManager.default.isExecutableFile(atPath: $0.path) } == true)
}
