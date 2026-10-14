# Updates

How Atrium updates itself outside the App Store (`Sources/Atrium/Updater.swift`, `release.sh`), why it fetches single files instead of the whole disk image, what was measured, and what hasn't been proven yet. The App Store build has no updater ([app-store.md](app-store.md)).

On 2026-10-10 Dave asked whether each release could publish a full build and a delta, with the app applying several deltas in a row when it's several versions behind: "my goal is to prevent users from having to re download the whole thing over and over as i add more wallpapers." Two research agents and local tests answered it (below). He then said "yes build it, go ahead with the notarize test". Since 0.107.0 an update fetches only the files a copy lacks.

## How an update works
1. **The look.** Once a day, and when Software Update opens, `check()` reads GitHub's list of releases and `newest` picks the first that's newer. A `Release` holds the disk image's address (the asset ending `.dmg`) and, if the release has one, its list of files (the asset ending `.files`). The same reply gives Software Update every release's notes (`history`): the newest under Recently Changed, or What's New when it's on offer, and the rest folded under Past Updates. A copy built from source looks too, when Software Update opens, for the notes only: it's offered nothing.
2. **File by file** (`install` → `rebuild` → `build` → `assemble`), when the release has a list:
   - The list is fetched and read by `listed`: a line for each file of the new app, with its SHA-256, size, where it starts in the disk image, permissions and path.
   - Every file of the installed app is hashed (0.2 s for 400 MB).
   - The new app is built in a temporary folder. A file the installed app has, under any name, is cloned from it, which takes no room and no time, and means a renamed photo isn't fetched again. Each of the rest is fetched from its place in the image with one request for that range of bytes (`bytes`), and checked against the list's size and hash.
   - Nothing is carried over that the list doesn't name, so a cut wallpaper's files go, and a damaged file in the installed app is simply fetched again.
   - A list with nothing to fetch is refused: it describes the app that's already installed (every release differs at least in its `Info.plist`), and would "update" the app to itself for ever.
3. **The whole image** (`downloadImage` → `swap`), when the release has no list or anything in step 2 fails: download the disk image, mount it, copy the app out. This is the only path releases up to 0.106 have, and it's logged when taken as a fallback (`log show --predicate 'subsystem == "com.dtanquary.atrium"'`). Cancelling is not a failure: it goes back to offering the update.
4. **The check and the swap** (`put`), the same for both: the new app must be intact with every file as signed, meet the running app's designated requirement (same bundle identifier, same Developer ID team), have an executable that's allowed to run, and be no older than the running version. Then `replaceItemAt` swaps it in and the app relaunches.

The running app is never changed in place: Apple warns that overwriting signed code a process is using can crash it, and to build beside it and replace ([Updating Mac Software](https://developer.apple.com/documentation/security/updating-mac-software)).

## What a release publishes
`release.sh` builds two files, and a release attaches both:
- **`Atrium-<version>.dmg`**, an *uncompressed* disk image (`--format UDRO`). The photos are already compressed, so this is 2% larger than the compressed one was (423 MB against 414), and every file of the app then sits in the image whole, at a fixed place.
- **`Atrium-<version>.files`**, the list (70 KB): `sha256 <tab> size <tab> offset <tab> mode <tab> path`, a line a file, the mode `755` for a file that runs and `644` for the rest. It's written last, from the signed and stapled image, by finding each file's bytes in it, so a place in the list is a place the file was read back from. The script stops if a file isn't in the image in one piece, or if the app holds a link.

Rules that follow:
- The list belongs to that exact image. Never replace one without the other.
- The updater in releases up to 0.106 takes the first asset whose name ends `.dmg`, so nothing else attached may end that way.
- The first release with a list is installed by older updaters as a whole image. The first update fetched file by file is the one after it.

## What the checks cover, and what they don't
The signature check is what makes this safe: the list and the image come off the network, and nothing they say is trusted until the built app passes it. Both agents tested what it covers, on macOS 27.2:
- **Covered:** every file's bytes, a missing file, an extra file anywhere in the bundle, a file swapped for a link, a changed `Info.plist`.
- **Not covered: permissions.** An app whose executable had lost its execute bit still passed, and such an app never opens again. So the list gives each file one of two permissions, `644` or `755` (`listed` reads no others and `release.sh` writes no others), `assemble` sets them, and `put` refuses an app whose executable isn't allowed to run, whichever path built it. Folders are made `755` whatever the user's umask.
- **Not covered: extended attributes.** A clone carries the quarantine mark from the day the app was first downloaded; a copy out of the disk image has none, so `assemble` removes it and the two paths end the same.
- **Not covered: which version it is.** An older release is signed just as well. `put` refuses one (Sparkle does the same).

What the list is not trusted with: a path that isn't plain and relative (`..`, a leading `/`, an empty part, a control character) makes the whole list unreadable; sizes and offsets are held under GitHub's 2 GiB a file, so arithmetic on them can't overflow; and a reply that isn't exactly the range asked for is cut off before its body is read, so a server that ignores the range can't make the app pull the whole image into memory. What's left: the list itself is read whole, and a file it names can be as large as 2 GiB, read into memory if the host really sends it. Only someone who can change Atrium's releases could arrange either, and both end in the fallback.

An independent review of the change before it was committed (2026-10-10, another agent given only the code) found no crash, hang, stuck state or write outside the temporary folder, and one real gap, since closed: a tampered list could mark the executable as not runnable and so install a validly signed app that would never open. The two-permissions rule and `put`'s check came from it, as did refusing a list of the installed version, honouring Cancel right up to the swap, and the control-character rule.

Apple's rule for App Management (macOS 13 on): apps signed by the same team may update each other with no permission and no Info.plist key ([NSUpdateSecurityPolicy](https://developer.apple.com/documentation/bundleresources/information-property-list/nsupdatesecuritypolicy), [WWDC22: What's new in privacy](https://developer.apple.com/videos/play/wwdc2022/10096/)).

## Why this design
**What changes between releases** (SHA-256 of every file in the released images, 2026-10-10). The app is 403 MB in 547 files; 372 photos are 375 MB of it, and the executable is 4.4 MB.

| From → to | Files that differ | To fetch |
|---|---|---|
| 0.95.1 → 0.102.3 | executable, Info.plist | 4.1 MB |
| 0.102.3 → 0.104.1 | executable, Info.plist, CodeResources, one preview picture | 4.5 MB |
| 0.95.1 → 0.104.1, two behind | the same four as the single step | 4.5 MB |
| 0.104.1 → a 0.106.0 build | those three and the Cupola's Earth data | 7.5 MB |

- **No chain of deltas.** When a delta is whole changed files, being several versions behind is just the union of those files, which a list of the newest version gives directly: one step, whatever version is installed, with no old release needing to stay online. None of the updaters read chains patches: Sparkle, Firefox and Microsoft AutoUpdate offer patches from the last five, four and three versions and otherwise send everything; Electron's updater and Chrome's work from what the client already has.
- **No binary patches.** Against the executable sent whole (0.95 MB compressed with lzma), a binary patch was 0.47 MB. Half a megabyte a release isn't worth a patch format, and macOS ships `bspatch` but not `bsdiff`.
- **No compression.** The files are fetched as they are in the image, so the executable travels as 4.4 MB, not 1 MB. Still 1% of what it was.
- **Not Sparkle.** It's a dependency, with its own signing key and feed, and its deltas stop five versions back.
- **The image as the archive.** A second, plain archive of the app beside the image would have worked the same and cost 400 MB more to upload with every release. An uncompressed image serves both.

## Measured (2026-10-10)
- **A rebuilt app is the released app.** The released 0.102.3 with four files from 0.104.1 laid over it was byte-identical to the released 0.104.1, passed `codesign --verify --strict --deep`, met 0.102.3's designated requirement, and `spctl` called it "Notarized Developer ID". A byte added to a photo, a stale extra file and a missing file each failed.
- **An uncompressed image notarizes, and nothing moves.** The 0.104.1 app in a UDRO image, signed with the Developer ID, notarized (Accepted) and stapled: all 546 files at the same places before signing, after signing and after stapling. `spctl` accepted the image.
- **The updater's own code, end to end.** `updatesFromARelease` built that notarized 0.104.1 from the released 0.102.3 app over a local web server: the list and four ranged requests, 4,759,066 bytes, 1.3 s, and the result passed the updater's signature check.
- **Against GitHub itself.** Six slices of the published v0.104.1-beta image came back right: the first request went to github.com and was redirected, the other five went straight to the storage address it gave.
- **A server that ignores ranges.** The updater gave up after one request, in 0.2 s.
- **Speed.** With nothing to build from, all 418 MB in 546 requests took 14.5 s from a local server in a debug build (the body is read a byte at a time, about 30 MB a second there). Writing the list takes 7 s.
- **GitHub.** One `bytes=a-b` range a request works; several ranges in one request, or "the last N bytes", get a 501. The storage address is good for about an hour. Up to 1,000 files a release, each under 2 GiB, no limit on total size or bandwidth ([About releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)). Forty ranged requests in a row weren't slowed.

## Checking it
- `swift test --filter rebuildsFromItsOwnFiles`: the build from old files, with a renamed file, a cut file, an empty file, permissions, a wrong reply, a list of the same app and hostile lists. `fetchesEachFileByItsRange` runs the fetching against a stand-in host (`ImageHost`, a `URLProtocol`): the list, exactly the right range for each file, and a host that ignores ranges. An off-by-one in the range fails it; without it such a slip would pass `swift test` and quietly turn every update back into a 400 MB download. `picksTheNewerRelease` covers finding the list in GitHub's reply.
- **A real release, before or after it's published:**
  ```sh
  UPDATE_IMAGE=https://github.com/dtanquary/atrium/releases/download/v<version>-beta/Atrium-<version>-beta.dmg \
  UPDATE_FROM=/path/to/an/older/Atrium.app swift test --filter updatesFromARelease
  ```
  It builds the release's app from the older one exactly as the updater would, prints the bytes fetched, and checks the result as the updater does. `UPDATE_FROM` is `/Applications/Atrium.app` unless given, and must be a Developer ID copy; `UPDATE_FILES` gives the list's address if it isn't beside the image. Before publishing, serve `build/` from any web server that honours ranges (Python's `http.server` doesn't).

## Not proven yet, and shortcuts
- **The whole thing inside the running app** (Install and Relaunch, the progress bar, Cancel, the fallback, `put`'s refusal of an older app, the relaunch) has only been read, reviewed and built, not run: it needs a Developer ID copy and a newer release with a list. The first chance is the second release after 0.107.0. Until then the pieces are tested, not the whole.
- **A first launch after a rebuild.** Gatekeeper's assessment accepts a rebuilt app; an actual relaunch into one hasn't happened. Today's updater has always swapped in an app it wrote itself, so nothing new is expected.
- **GitHub promises none of this.** Ranges on release files, and how many requests it allows, are what it does today. Anything but the exact range falls back to the whole image.
- **Plain files only.** A link in the bundle (a framework has them) stops `release.sh`; the list has no line for one.
- **One file at a time, each read into memory.** Right for photos of a few MB. A file of hundreds of MB, or thousands of new files in one release, would want streaming to disk and several requests at once.
- **Clones need the temporary folder on the app's volume**, which it is for an app in /Applications. Elsewhere the kept files are copied, 400 MB for a moment.
- **A refusal the whole image would only repeat** (an app folder that can't be written to, as when Atrium is run straight from its disk image) still downloads the image before saying so.
- **The file-by-file path never shows "Installing"**: it reads "Downloading" through the check and swap, a third of a second.
- **The heavy work runs off the main thread because the package's functions are `nonisolated` in the old sense.** If the package ever turns on `NonisolatedNonsendingByDefault`, `rebuild` needs `@concurrent`, or the hashing and the byte loop move to the main thread.
- **The App Store build** is updated by the store. Apple's documentation says it sends only changed files, but an Apple engineer said in January 2026 that the page assumes iOS ([forum thread](https://developer.apple.com/forums/thread/810624)); measure it once two builds are in TestFlight.

## Ideas
- **Photos out of the app.** Solar System Tour (197 MB) and Deep Space Tour (148 MB) are 345 MB of the 403. Downloaded on first use, the first install would be about 60 MB. It costs the tours working offline out of the box, and touches `resource(_:)`, both scenes, Settings and Welcome. Apple's hosted asset packs are for App Store and TestFlight apps only, and On-Demand Resources doesn't exist on the Mac, so it would be plain downloads with hashes carried in the signed app. It would also lift the ceiling below.
- **GitHub's 2 GiB a file** is a ceiling on the disk image: about nine more photo tours of today's size.
- Show an update's size before it's fetched; staple the notarization ticket to the app as well as the image.

## Sources
- Sparkle: [delta updates](https://sparkle-project.org/documentation/delta-updates/), and its source at [e95f42b](https://github.com/sparkle-project/Sparkle/tree/e95f42b) (`Autoupdate/SUBinaryDeltaCreate.m`, `SUBinaryDeltaApply.m`, `Sparkle/SUAppcastDriver.m`, `generate_appcast/main.swift`, `Autoupdate/SUPlainInstaller.m`).
- Other updaters: [Squirrel.Mac](https://github.com/Squirrel/Squirrel.Mac), [electron-updater](https://github.com/electron-userland/electron-builder/tree/master/packages/electron-updater/src), Chromium's [protocol](https://chromium.googlesource.com/chromium/src/+/main/docs/updater/protocol_4.md) and [Mac installer notes](https://chromium.googlesource.com/chromium/src/+/main/docs/updater/installer_api_mac.md) ("failure to mount DMGs is a common update error"), Firefox's [MAR files](https://firefox-source-docs.mozilla.org/toolkit/mozapps/update/docs/MarFiles.html), [Microsoft AutoUpdate](https://learn.microsoft.com/en-us/microsoft-365-apps/mac/updater-types-used-by-microsoft-autoupdate), [Tauri](https://v2.tauri.app/plugin/updater/), [Steam](https://partner.steamgames.com/doc/sdk/uploading).
- Code signing: [TN3126: Inside code signing: hashes](https://developer.apple.com/documentation/technotes/tn3126-inside-code-signing-hashes) (and its warning not to read `CodeResources` as a format, which is why the list is our own), [TN2206](https://developer.apple.com/library/archive/technotes/tn2206/_index.html), Apple's [Security source](https://github.com/apple-oss-distributions/Security/tree/main/OSX/libsecurity_codesigning/lib), [notarization](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow), the [platform security guide on Gatekeeper](https://support.apple.com/guide/security/sec5599b66df/web).
- GitHub: [release limits](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases), [API rate limits](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api), [release assets](https://docs.github.com/en/rest/releases/assets), [immutable releases](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository), [the 2025 limits on unauthenticated requests](https://github.blog/changelog/2025-05-08-updated-rate-limits-for-unauthenticated-requests/).
- The App Store and assets: [reducing the size of app updates](https://developer.apple.com/documentation/xcode/doing-advanced-optimization-to-further-reduce-your-app-s-size), [Apple-hosted asset packs](https://developer.apple.com/documentation/backgroundassets/downloading-apple-hosted-asset-packs), [self-hosted Background Assets](https://developer.apple.com/documentation/backgroundassets/configuring-an-unmanaged-background-assets-project), [NSBundleResourceRequest](https://developer.apple.com/documentation/foundation/nsbundleresourcerequest), [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) 2.4.5(iv) and 4.2.3(ii).
