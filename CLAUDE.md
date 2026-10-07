# Atrium

Atrium is a menu bar app that plays animated wallpapers on macOS 27. Swift package plus SpriteKit: no Xcode project, no dependencies.

## How it works
- macOS has no public API for third-party live wallpapers. Instead, each display gets a borderless `NSWindow` at `CGWindowLevelForKey(.desktopWindow)`. That puts it above the system wallpaper and below the desktop icons, on every Space, and it ignores the mouse. Only public AppKit APIs are used: no private frameworks, no changes to system files, no SIP changes. Keep it that way.
- Each wallpaper is an `SKScene` shown in a `WallpaperView` (an `SKView`). Its frame rate comes from Settings → Power (`Power` in Settings.swift, applied by `applyPowerState` in main.swift): 60 fps on mains power, 30 fps on battery and frozen on its current frame in Low Power Mode unless changed, with 15 fps offered. The menu's Full Speed on Battery is a one-click version for demos. Scenes step by elapsed time, so they must look the same at 15, 30 and 60 fps. The view pauses whenever its window is fully covered. If SpriteKit stops drawing while the view isn't paused (seen once after the Mac slept: no display link left, the last frame held for good), `WallpaperView.watch` restarts it within a few seconds and logs it under the subsystem `com.dtanquary.atrium` (`log show --predicate 'subsystem == "com.dtanquary.atrium"'`).
- Switching scenes crossfades inside the existing windows. A wallpaper that has run for 12 hours is rebuilt when the displays sleep, or with a crossfade after 3 days if they never do (`refreshIfStale` in main.swift), so the clocks its shaders animate by stay small. Display changes only touch the displays that actually changed, so the system wallpaper never flashes through.
- The menu bar icon (✨📺) picks the scene, saved in `UserDefaults` under `scene`. It also toggles Shuffle (with Next Wallpaper while it's on), opens Settings, toggles Open at Login (`SMAppService`) and Full Speed on Battery, and quits the app.
- Wallpapers are listed alphabetically, in both the menu and the Settings sidebar (and Shuffle's list in General). `allScenes` in Scenes.swift sorts itself by name, so a new, renamed or removed wallpaper needs no reordering: never hand-order the list or index into it (`scenes[0]`). The first-launch wallpaper is `defaultScene` (Fish Tank), named rather than taken from the top of the list. `scenes` is what people see: `allScenes` less any flagged `unfinished: true` (hidden until it's good enough; `defaults write com.dtanquary.atrium unfinished -bool true` shows them). The render tests cover all of them.
- **Settings** (`Settings.swift`, opened by `SettingsWindow` in main.swift) is an ordinary window laid out like System Settings: General, Power, Software Update and About, then a searchable sidebar of wallpapers, each with its own page. While it's open Atrium is a regular app (Dock, ⌘-Tab, its own menus); it reopens on the page last picked (`settings.page`), and opening Atrium again while it runs opens it. General holds Open at Login and Shuffle. `Shuffle` moves the desktop on to a random wallpaper on a wall-clock timer that any change of `scene` restarts, or at each unlock (`com.apple.screenIsUnlocked`), skipping the names in `shuffle.skip`. Each page runs its own copy of the wallpaper live behind its top (`LivePreview`), under a Liquid Glass header, so settings show as they change. The page shows the wallpaper's screenshot (`Resources/preview-<name>.jpg`, see `docs/README.md`) until the live copy has built, then fades to it. A wallpaper's settings are plain data on its `Wallpaper` entry in Scenes.swift:
  - `knobs`: sliders, switches with `format: .toggle`, or menus with `format: .choice([names])` (stored as the index), or multipliers with `format: .times`, grouped by `section`. A knob can depend on a switch with `shownWhen`.
  - `palettes`: a `PaletteChoice` of named swatches. The pick is stored by name, and an empty value means Random.
  - `status`: a UserDefaults key the scene keeps a line of text in (Weather's last live report), shown under a knob while that knob is 0.
  - `refresh`: a `Refresh` (Scenes.swift) for Refresh Now on its page: fetch its live data now, within the source's own cooldown. Open-Meteo counts every point in a request as a call, so shrink grids and fetch longer forecasts less often rather than polling faster.

  Knobs are stored in UserDefaults. Live scenes read `knob.value` and observe `UserDefaults.didChangeNotification` to feed their shader uniforms (see `FlowingGradient` and `LavaLamp`). A plain shader scene can instead pass `knobs:` to `shaderScene`, and each knob becomes a live uniform; a `speed:` knob adds `u_clock`, time that runs at that speed without jumping when the slider moves (see Rain on Glass). `gradeKnobs(prefix)` plus `grade()` in the shader add the shared brightness, contrast, saturation and hue sliders (see Nebula). A new palette pick rebuilds the scene if it's on the desktop. To tune, read the values back with `defaults read com.dtanquary.atrium`.
- Known seams: the lock screen, and the tint of the menu bar and windows, come from the system wallpaper. General → Match the lock screen (`LockScreen.swift`, opt-in) sets it to a still of each display's scene, saved by display UUID, and puts the user's own back when turned off, on quitting, or at the next launch after a crash. macOS sets a wallpaper for the Space in front only, so each Space gets the latest still as it comes to the front (`LockScreen.spaceChanged`); the user's own goes back on the Space in front only. `pkill` skips the quit, so the next launch restores it. The screen saver is separate (the wallpaper store's Idle choice, no public API): after an Aerial one, the lock screen shows the Aerial's last frame, not the still, so Settings and the README tell the user to pick another or none.

## Layout
- `Sources/Atrium/main.swift`: the app host (one window per display, the menu, handling display changes).
- `Scenes.swift`: the scene registry (sorted by name for the menu and Settings), plus shared helpers `shaderScene`, `paint` and `resource`.
- `Welcome.swift`: the welcome sheet over Settings (first launch, and About → Show Welcome): tap a screenshot to put that wallpaper on the desktop (as many as they like), location if they use it, then Open at Login, Match the lock screen, Shuffle between all wallpapers (on for new users) and full speed on battery. Its mood groups and `local` list name wallpapers; a new one joins the last group on its own.
- `Location.swift`: `Location.shared`, using CoreLocation with a fallback guessed from the time zone. The last fix is saved in UserDefaults.
- `LiveWeather.swift`: `LiveWeather.shared`, the current weather from Open-Meteo, one fetch shared by every scene. Call `poll()` from a periodic action, read `latest`, observe `LiveWeather.changed`.
- `Updater.swift`: `Updater.shared` looks for a newer GitHub release once a day (`update.automatic`) and opens Settings → Software Update (`UpdatePage`) to offer it. Install and Relaunch mounts the release's DMG, checks the app in it meets this one's designated requirement (so only Developer ID builds update themselves, not build.sh's ad-hoc ones), swaps it in with `replaceItemAt` and relaunches. So a release has to attach release.sh's DMG and be tagged `v<version>`, with `-beta` while it's a prerelease.
- `Sources/TreeGrowth/`: A Tree for the Year's growth and bake, its own module built with `-O` even in debug (Foundation and simd only).
- One file per scene. `Shaders.swift` holds the full-screen shader scenes. `SkyMath.swift` and `ISS.swift` are shared by Live Sky and Earth from Orbit.
- `Sources/Atrium/Resources/`: data files (star catalogue, constellation lines, Earth textures, the reef tank's photo cut-outs as HEIC with alpha, credited in `reef-credits.tsv`). They're excluded from the target. `build.sh` copies them into the .app, and `resource(_:)` finds them there or in the source tree. Don't use `Bundle.module`.
- `Tests/AtriumTests/`: `RenderTests` renders every scene offscreen, `SkyTests` checks the astronomy against JPL Horizons, and `WeatherTests` parses a real Open-Meteo reply.
- `docs/`: one file per wallpaper (e.g. `docs/nebula.md`) covering how it works, its settings, cost, shortcuts, Dave's feedback and next ideas. `docs/README.md` indexes them and records Dave's overall direction. `docs/app-store.md` is the plan for the Mac App Store, step by step. **Read the wallpaper's doc before changing it, and update the doc in the same commit.**
- `site/`: the website, atrium.show, a static Cloudflare Pages site built from the app's own renders. Its brief and plan are in `site/CLAUDE.md`.

## Commands
```sh
./build.sh                    # release build → build/Atrium.app (ad-hoc signed, menu bar only)
APP_STORE=1 ./build.sh        # the Mac App Store variant: sandboxed, no updater (docs/app-store.md has the plan)
./release.sh                  # for a GitHub release: build/Atrium-<version>-beta.dmg (no -beta from 1.0), Developer ID signed and notarized (setup at its top)
pkill -x Atrium; open build/Atrium.app
defaults write com.dtanquary.atrium scene "Live Sky"   # pick a scene without the menu
swift test                    # renders every scene to $TMPDIR/atrium-snapshots and prints the cost per frame
SNAPSHOT_SCENE="Aurora" SNAPSHOT_DIR=/some/dir SNAPSHOT_SECONDS=20 swift test
SNAPSHOT_DEFAULTS="gradient.ribbons=1,gradient.previewTime=1" swift test   # snapshot with Settings values
SNAPSHOT_SCENE="Fish Tank" SNAPSHOT_MOVIE=6 swift test   # then 6 s in real time, saved as 15 fps frames (Fish Tank-000.png…)
SETTINGS_SHOT="Nebula" swift test --filter settingsWindow   # opens Settings on that page for a moment and captures the window
ffmpeg -framerate 15 -i 'Fish Tank-%03d.png' -vf "scale=800:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle" docs/images/fish-tank.gif
```

## Adding a scene
1. Create a file with `@MainActor func myScene(size: CGSize) -> SKScene` and add it to `allScenes` in Scenes.swift anywhere: it sorts by name. After adding, renaming or cutting a wallpaper, check the menu and Settings still list it in alphabetical order.
2. Build everything visible in `init` or `sceneDidLoad`. The render test uses `SKRenderer`, which never calls `didMove(to:)`.
3. Start live services (`Location.shared.start()`, network polling) in `didMove(to:)`.
4. Drive periodic work with SKActions or `update(_:)`, not Timers, so it stops while the wallpaper is hidden.
5. For separate Light and Dark Mode looks, read `systemIsDark` when the scene is built. The app rebuilds the current scene with a crossfade when macOS switches appearance. Check both looks with `SNAPSHOT_APPEARANCE=light|dark`.
6. Stay within budget: about 2 ms of CPU and 2 ms of GPU per frame at 2x Retina, as the render test prints it. Scenes run all day.
7. Look at the snapshot PNG before calling it done.
8. Add a screenshot to `docs/images` and its Settings copy (see `docs/README.md`). While its Settings page is open, a second copy of the scene runs, just as it would on a second display, so shared state has to cope with two.

## Gotchas
- SKShader is GLSL-like and gets translated to Metal. There's no `inout`, no early `return` from `main()` (it won't compile), and no `sampler2D` parameters (keep texture reads in `main()`).
- Animate shaders by `u_now`, never SpriteKit's `u_time`. `u_time` counts from app launch and nothing resets it, so as a Float it goes choppy after a week or two of running, and sines of it turn to noise within a month. `u_now` (`WallpaperTime` in Scenes.swift) restarts when the app rebuilds a long-running wallpaper, and in the render tests it moves with `SNAPSHOT_SECONDS`. `shaderScene` adds it when the source uses it; other shaders list `WallpaperTime.now` in their uniforms. Wrap anything a jump can't hurt, like a twinkle, with `mod(t, 3600.0)`: `starField` and `brightStar` already do.
- A transition never advances in an `SKView` that isn't drawing (paused, covered, display asleep), and `view.scene` stays the old scene until it does. `WallpaperView` swaps straight when its window is covered, so the lock screen's still is never of the wallpaper before.
- Globals in `main.swift` are set up by top-level code and aren't safe to use from tests. Put shared state in other files.
- Swift 6 strict concurrency: AppKit and CoreLocation delegate callbacks are `nonisolated` and use `MainActor.assumeIsolated`.
- Don't change a node's `speed` every frame while `SKAction.animate(withWarps:)` runs on it. SpriteKit gets steadily slower (from 1 ms to 10 ms a frame within a minute). Pick precomputed warp frames yourself in `update(_:)` instead.
- `hash21` repeats every 50 whole-number cells across and 100 up, so anything scattered one per cell (stars, sparkles) visibly tiles. Use `hash42` for cell lookups; it also returns four random numbers at once. `u_texture` is SpriteKit's own uniform, so don't name one that.
- In SKShader, uniforms are only visible inside `main()`, so pass them to helper functions as parameters, and there's no global `const`.
- A texture handed to a shader as a uniform is smoothed between its pixels even when its `filteringMode` is `.nearest`. For crisp pixel art, sample at the centre of a whole pixel: `(floor(p) + 0.5) / size` (see Pixel City's water).
- A shader can take about 30 uniforms (Metal's buffer indices run 0–30, and SpriteKit adds its own). Past that it fails to compile at runtime ("'buffer' attribute parameter is out of bounds") and draws nothing; `swift build` won't catch it. Pass `shaderScene` only the knobs its shader reads, and write fixed values into the source.
- `paint(_:_:)` draws at 2x, so the texture's pixel size is double. Give sprites an explicit size.
- Data must be public domain or permissively licensed. Cite the source in a comment or in the data file's header.
- README GIFs: Bayer dithering (above) makes them about a third the size of ffmpeg's default. A scene with film grain (Campfire) changes every pixel every frame and comes out over 15 MB, so use a still.

## Conventions
- Minimal code, no dependencies, native frameworks first. Mark deliberate shortcuts with `ponytail:` comments that say where the shortcut stops being good enough.
- Match the code around you: doc comments on types and functions, sparse comments inside them.

## Git and deploying
- **Commit early and often.** One logical change per commit, made as soon as it builds and `swift test` passes. Don't bundle unrelated work together.
- **Redeploy as work lands.** After each working change, run `./build.sh` and relaunch (`pkill -x Atrium; open build/Atrium.app`) so Dave can try it from the menu bar. Tell him what to test.
- Messages: a plain-English imperative subject that says what changed and why, e.g. "Pause rendering while the wallpaper is covered".
- **Versioning:** semantic versioning, set by `VERSION=` at the top of `build.sh` (it goes into Info.plist and shows in Settings → About). Bump it in the same commit as the change that earns it:
  - until 1.0: a new or cut wallpaper, or a feature users will notice, bumps the minor version (0.2.0 → 0.3.0); fixes and tuning bump the patch (0.3.0 → 0.3.1). A run of tuning commits on one wallpaper can share one patch bump.
  - from 1.0.0, the first stable public release: breaking changes (a removed setting, a raised minimum macOS) bump the major version.
  - only official releases get a git tag (`v1.0.0`) and a GitHub release, with the DMG from `release.sh`. Dave decides when to cut one. Before 1.0 they're betas: `PRERELEASE=beta` in `build.sh` (it shows in About) and marked Pre-release on GitHub, so the site's `releases/latest` link lands on the Releases page.
