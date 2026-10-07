# The Mac App Store

The plan for putting Atrium on the Mac App Store alongside the notarized DMG on GitHub, and where it stands. Dave asked on 2026-10-06 how close it was, then to start on step 1 and keep the rest written down here to walk through slowly.

## Where it stands
- **Step 1, the App Store build: done.** `APP_STORE=1 ./build.sh` builds it, tested sandboxed on Dave's Mac (below). One open item: putting back a wallpaper from the user's own folders.
- **Step 2, signing, packaging and TestFlight: not started.**
- **Step 3, the listing and review: not started.**

## Step 1: the App Store build
`APP_STORE=1 ./build.sh` builds `build/Atrium.app` with the Swift flag `APP_STORE` and signs it ad hoc with the App Sandbox, network access (live data) and location. Under the flag:
- **No updater.** App Review guideline 2.4.5 has Mac App Store apps update only through the store. `Updater.swift` is left out entirely, with the Software Update page and its sidebar row, the menu's "Update to Atrium…" and About's "Releases on GitHub". The built binary has no `Updater` or `UpdatePage` symbols.
- Nothing else changes. A scan for what the sandbox blocks (running other programs, other apps' files, the home folder by path, AppleScript, private frameworks, screen capture) found only the updater.

### What the sandboxed build did on Dave's Mac (2026-10-06, macOS 27.2)
| What | Result |
|---|---|
| The wallpaper windows at desktop level, every scene drawing | works |
| Live data: Weather (Open-Meteo), Earth from Orbit's clouds, Wind's forecast and map tiles | works; caches land in the container |
| Match the lock screen: taking stills and setting them as the system wallpaper | works; stills are kept in the container and macOS shows them |
| Putting back a macOS wallpaper on quit (`/System/Library/Desktop Pictures`, the default Aerial's still) | works, once the quit pauses (see below) |
| Putting back a wallpaper from the user's own folders | **fails**: the sandbox can't read it, so `setDesktopImageURL` can't hand it to macOS. Tried with a file in `~/Library/Application Support` |
| Settings | macOS **moves** `~/Library/Preferences/com.dtanquary.atrium.plist` into the container at the first sandboxed launch. So someone who moves from the DMG to the App Store keeps their settings, with no migration code |
| Location prompt, Open at Login, Shuffle on unlock, Solar System Tour's live Sun | not tried; no reason to expect trouble, but check them in TestFlight |

Two bugs turned up along the way and are fixed for both builds (0.95.5): quitting didn't put the default wallpaper back (macOS drops a wallpaper set just before its app exits), and an update's relaunch lost the saved wallpaper. Both are in `AppDelegate.applicationWillTerminate` and `Updater.relaunch`.

### Open: the user's own wallpaper under the sandbox
Wallpapers chosen from System Settings live in `/System/Library` and come back fine. One of the user's own photos doesn't. Options, cheapest first:
1. Add `com.apple.security.assets.pictures.read-only` to the entitlements: it covers `~/Pictures`, where most people keep their photos. A standard entitlement, no review questions. Untested.
2. When Match the lock screen is turned on and the current wallpaper is a file the app can't read, ask for it once with an open panel aimed at the file, and keep a security-scoped bookmark. Covers everything, at the cost of one more prompt.
3. Otherwise tell the user in the switch's footer that a wallpaper from their own folders comes back as macOS's default.

### Running it on a Mac that has the DMG version
The first sandboxed launch moves the settings into `~/Library/Containers/com.dtanquary.atrium`, and from then on `defaults read/write com.dtanquary.atrium` reaches the container, while the DMG build and `./build.sh` builds look in `~/Library/Preferences` and start fresh. Also, `defaults write` doesn't reach a running sandboxed copy; Atrium reads `scene` at launch anyway. To go back after a test:
```sh
pkill -x Atrium
defaults export com.dtanquary.atrium /tmp/atrium-prefs.plist   # while the container exists, this reads it
rm -rf ~/Library/Containers/com.dtanquary.atrium
defaults import com.dtanquary.atrium /tmp/atrium-prefs.plist
```
Test it from a copy outside `build/`, which other sessions rebuild under it.

## Step 2: signing, packaging and TestFlight
1. **Certificates** (Xcode → Settings → Accounts → Manage Certificates): Apple Distribution, and Mac Installer Distribution. The Mac has only Developer ID Application and Apple Development now.
2. **App ID** `com.dtanquary.atrium` in the developer portal, and a Mac App Store provisioning profile for it, embedded in the app as `Contents/embedded.provisionprofile`.
3. **Entitlements** for the store: the three above, plus `com.apple.application-identifier` (`A3T6R9W85M.com.dtanquary.atrium`) and `com.apple.developer.team-identifier` (`A3T6R9W85M`).
4. **Info.plist:** `ITSAppUsesNonExemptEncryption` = false (HTTPS only, so no export paperwork). Probably also the build stamps Xcode adds (`DTXcode`, `DTXcodeBuild`, `DTSDKName`, `DTSDKBuild`, `DTPlatformBuild`, `DTPlatformName`, `DTPlatformVersion`, `BuildMachineOSBuild`), which the upload checks for "built with a released Xcode": fill them from `xcodebuild -version` and `xcrun --show-sdk-build-version`.
5. **`appstore.sh`**, beside `release.sh`: `APP_STORE=1 ./build.sh`, embed the profile, sign with Apple Distribution and the store entitlements, then `productbuild --component build/Atrium.app /Applications --sign "3rd Party Mac Developer Installer: …" build/Atrium.pkg`. `CFBundleVersion` (the commit count) already goes up with every upload, as the store requires.
6. **Upload** with Transporter, then install from **TestFlight** on Dave's Mac and run through the table above, the untried rows first.

## Step 3: the listing and review
- **Name:** "Atrium" is taken on the App Store (a hotel app among others), so the listing needs another, e.g. "Atrium: Living Wallpapers". The app keeps calling itself Atrium.
- **Privacy policy URL** (required): a page on atrium.show, adapted from the README's "Privacy, permissions and network".
- **App Privacy answers:** coarse location (rounded to 0.01°) goes to Open-Meteo to fetch the weather, and Dave never receives it. That can arguably be declared "Data Not Collected"; Dave's call.
- **Screenshots:** 2880×1800 (or 2560×1600, 1440×900, 1280×800), up to ten, rendered from the wallpapers with `SNAPSHOT_SCENE`.
- **Description, keywords, category** (Entertainment, as `LSApplicationCategoryType` says), **age rating** (4+), **support URL** (atrium.show or the GitHub issues).
- **Review notes:** it's a menu bar app (✨📺) with no Dock icon; on a MacBook the icon can hide behind the notch, and opening Atrium again opens Settings; the welcome sheet shows on first launch; Match the lock screen is opt-in, changes the system wallpaper and puts the user's back on quitting.

## Dave's decisions still open
- **Open-Meteo's terms:** its free API is for non-commercial use. A free app without ads should qualify; check with them if Atrium ever charges.
- **Share-alike photos:** 20 photos are CC BY-SA (13 of them 3.0 IGO, 6 of them 4.0, 1 of them 2.0). Mac apps aren't copy-protected on the store, so this is low risk, but check, or swap them for CC BY or CC0.
- **The user's own wallpaper under the sandbox:** pick one of the options above.
