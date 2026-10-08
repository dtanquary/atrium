import Foundation
import Testing
@testable import Atrium

/// The updater offers the newest release from GitHub's reply only when it's newer than this build, skips drafts, and
/// skips prereleases for a stable build.
@MainActor @Test func picksTheNewerRelease() throws {
    func reply(_ releases: [(tag: String, prerelease: Bool, draft: Bool)]) -> Data {
        try! JSONSerialization.data(withJSONObject: releases.map { release in
            ["tag_name": release.tag, "body": "### New\r\n- **Pixel Spaceport**", "draft": release.draft, "prerelease": release.prerelease,
             "html_url": "https://github.com/dtanquary/atrium/releases/tag/\(release.tag)",
             "assets": [["name": "notes.txt", "browser_download_url": "https://example.com/notes.txt"],
                        ["name": "Atrium-\(release.tag).dmg", "browser_download_url": "https://example.com/\(release.tag).dmg"]]]
        })
    }
    let betas = reply([("v0.97.0-beta", true, true), ("v0.96.0-beta", true, false), ("v0.95.0-beta", true, false)])
    let offer = try #require(Updater.newest(from: betas, version: "0.95.0", prerelease: "beta"))
    #expect(offer.version == "0.96.0") // not the draft
    #expect(offer.dmg == URL(string: "https://example.com/v0.96.0-beta.dmg"))
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
