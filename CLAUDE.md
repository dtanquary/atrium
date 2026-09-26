# Atrium

Atrium is a menu bar app that plays animated wallpapers on macOS 27. Swift package plus SpriteKit: no Xcode project, no dependencies.

## How it works
- macOS has no public API for third-party live wallpapers. Instead, each display gets a borderless `NSWindow` at `CGWindowLevelForKey(.desktopWindow)`. That puts it above the system wallpaper and below the desktop icons, on every Space, and it ignores the mouse. Only public AppKit APIs are used: no private frameworks, no changes to system files, no SIP changes. Keep it that way.
- Each wallpaper is an `SKScene` shown in a `WallpaperView` (an `SKView`). It runs at 30 fps on mains power and 15 fps on battery, and freezes on its current frame in Low Power Mode. The view pauses whenever its window is fully covered.
- Switching scenes crossfades inside the existing windows. Display changes only touch the displays that actually changed, so the system wallpaper never flashes through.
- The menu bar icon (✨📺) picks the scene, saved in `UserDefaults` under `scene`. It also opens Settings, toggles Open at Login (`SMAppService`) and quits the app.
- **Settings** (`Settings.swift`) is a floating window laid out like System Settings: a sidebar of wallpapers, and a page for each one. A wallpaper's settings are plain data on its `Wallpaper` entry in Scenes.swift:
  - `knobs`: sliders, switches with `format: .toggle`, or menus with `format: .choice([names])` (stored as the index), or multipliers with `format: .times`, grouped by `section`. A knob can depend on a switch with `shownWhen`.
  - `palettes`: a `PaletteChoice` of named swatches. The pick is stored by name, and an empty value means Random.
  - `status`: a UserDefaults key the scene keeps a line of text in (Weather's last live report), shown under a knob while that knob is 0.

  Knobs are stored in UserDefaults. Live scenes read `knob.value` and observe `UserDefaults.didChangeNotification` to feed their shader uniforms (see `FlowingGradient` and `LavaLamp`). A plain shader scene can instead pass `knobs:` to `shaderScene`, and each knob becomes a live uniform. `gradeKnobs(prefix)` plus `grade()` in the shader add the shared brightness, contrast, saturation and hue sliders (see Nebula). A new palette pick rebuilds the scene if it's on the desktop. To tune, read the values back with `defaults read com.dtanquary.atrium`.
- Known seams: the lock screen, and the tint of the menu bar and windows, still come from the system wallpaper.

## Layout
- `Sources/Atrium/main.swift`: the app host (one window per display, the menu, handling display changes).
- `Scenes.swift`: the scene registry, in menu order, plus shared helpers `shaderScene`, `paint` and `resource`.
- `Location.swift`: `Location.shared`, using CoreLocation with a fallback guessed from the time zone. The last fix is saved in UserDefaults.
- One file per scene. `Shaders.swift` holds the full-screen shader scenes. `SkyMath.swift` and `ISS.swift` are shared by Live Sky and Earth from Orbit.
- `Sources/Atrium/Resources/`: data files (star catalogue, constellation lines, Earth textures, the reef tank's photo cut-outs as HEIC with alpha, credited in `reef-credits.tsv`). They're excluded from the target. `build.sh` copies them into the .app, and `resource(_:)` finds them there or in the source tree. Don't use `Bundle.module`.
- `Tests/AtriumTests/`: `RenderTests` renders every scene offscreen, `SkyTests` checks the astronomy against JPL Horizons, and `WeatherTests` parses a real Open-Meteo reply.
- `docs/`: one file per wallpaper (e.g. `docs/nebula.md`) covering how it works, its settings, cost, shortcuts, Dave's feedback and next ideas. `docs/README.md` indexes them and records Dave's overall direction. **Read the wallpaper's doc before changing it, and update the doc in the same commit.**

## Commands
```sh
./build.sh                    # release build → build/Atrium.app (ad-hoc signed, menu bar only)
pkill -x Atrium; open build/Atrium.app
defaults write com.dtanquary.atrium scene "Live Sky"   # pick a scene without the menu
swift test                    # renders every scene to $TMPDIR/atrium-snapshots and prints the cost per frame
SNAPSHOT_SCENE="Aurora" SNAPSHOT_DIR=/some/dir SNAPSHOT_SECONDS=20 swift test
SNAPSHOT_DEFAULTS="gradient.ribbons=1,gradient.previewTime=1" swift test   # snapshot with Settings values
```

## Adding a scene
1. Create a file with `@MainActor func myScene(size: CGSize) -> SKScene` and add it to `scenes` in Scenes.swift.
2. Build everything visible in `init` or `sceneDidLoad`. The render test uses `SKRenderer`, which never calls `didMove(to:)`.
3. Start live services (`Location.shared.start()`, network polling) in `didMove(to:)`.
4. Drive periodic work with SKActions or `update(_:)`, not Timers, so it stops while the wallpaper is hidden.
5. For separate Light and Dark Mode looks, read `systemIsDark` when the scene is built. The app rebuilds the current scene with a crossfade when macOS switches appearance. Check both looks with `SNAPSHOT_APPEARANCE=light|dark`.
6. Stay within budget: about 2 ms of CPU and 2 ms of GPU per frame at 2x Retina, as the render test prints it. Scenes run all day.
7. Look at the snapshot PNG before calling it done.

## Gotchas
- SKShader is GLSL-like and gets translated to Metal. There's no `inout`, no early `return` from `main()` (it won't compile), and no `sampler2D` parameters (keep texture reads in `main()`). `u_time` follows the wall clock, so `SNAPSHOT_SECONDS` doesn't move shader animation forward (SKActions do move forward).
- Globals in `main.swift` are set up by top-level code and aren't safe to use from tests. Put shared state in other files.
- Swift 6 strict concurrency: AppKit and CoreLocation delegate callbacks are `nonisolated` and use `MainActor.assumeIsolated`.
- Don't change a node's `speed` every frame while `SKAction.animate(withWarps:)` runs on it. SpriteKit gets steadily slower (from 1 ms to 10 ms a frame within a minute). Pick precomputed warp frames yourself in `update(_:)` instead.
- `hash21` repeats every 50 whole-number cells across and 100 up, so anything scattered one per cell (stars, sparkles) visibly tiles. Use `hash42` for cell lookups; it also returns four random numbers at once. `u_texture` is SpriteKit's own uniform, so don't name one that.
- In SKShader, uniforms are only visible inside `main()`, so pass them to helper functions as parameters, and there's no global `const`.
- A shader can take about 30 uniforms (Metal's buffer indices run 0–30, and SpriteKit adds its own). Past that it fails to compile at runtime ("'buffer' attribute parameter is out of bounds") and draws nothing; `swift build` won't catch it. Pass `shaderScene` only the knobs its shader reads, and write fixed values into the source.
- `paint(_:_:)` draws at 2x, so the texture's pixel size is double. Give sprites an explicit size.
- Data must be public domain or permissively licensed. Cite the source in a comment or in the data file's header.

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
  - only official releases get a git tag (`v1.0.0`) and a GitHub release. Dave decides when to cut one.
