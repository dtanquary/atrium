# Animated macOS Wallpapers

A menu bar app that plays animated wallpapers on macOS 27. Swift package plus SpriteKit: no Xcode project, no dependencies.

## How it works
- macOS has no public API for third-party live wallpapers. Instead, each display gets a borderless `NSWindow` at `CGWindowLevelForKey(.desktopWindow)`. That puts it above the system wallpaper and below the desktop icons, on every Space, and it ignores the mouse. Only public AppKit APIs are used: no private frameworks, no changes to system files, no SIP changes. Keep it that way.
- Each wallpaper is an `SKScene` shown in a `WallpaperView` (an `SKView`) at 30 fps. The view pauses whenever its window is fully covered.
- The menu bar icon (✨📺) picks the scene, saved in `UserDefaults` under `scene`. It also toggles Open at Login (`SMAppService`) and quits the app.
- Known seams: the lock screen, and the tint of the menu bar and windows, still come from the system wallpaper.

## Layout
- `Sources/Wallpaper/main.swift`: the app host (one window per display, the menu, handling display changes).
- `Scenes.swift`: the scene registry, in menu order, plus shared helpers `shaderScene`, `paint` and `resource`.
- `Location.swift`: `Location.shared`, using CoreLocation with a fallback guessed from the time zone. The last fix is saved in UserDefaults.
- One file per scene. `Shaders.swift` holds the full-screen shader scenes. `SkyMath.swift` and `ISS.swift` are shared by Night Sky and Earth from Orbit.
- `Sources/Wallpaper/Resources/`: data files (star catalogue, constellation lines, Earth textures). They're excluded from the target. `build.sh` copies them into the .app, and `resource(_:)` finds them there or in the source tree. Don't use `Bundle.module`.
- `Tests/WallpaperTests/`: `RenderTests` renders every scene offscreen, and `SkyTests` checks the astronomy against JPL Horizons.

## Commands
```sh
./build.sh                    # release build → build/Wallpaper.app (ad-hoc signed, menu bar only)
pkill -x Wallpaper; open build/Wallpaper.app
defaults write com.dtanquary.wallpaper scene "Night Sky"   # pick a scene without the menu
swift test                    # renders every scene to $TMPDIR/wallpaper-snapshots and prints the cost per frame
SNAPSHOT_SCENE="Aurora" SNAPSHOT_DIR=/some/dir SNAPSHOT_SECONDS=20 swift test
```

## Adding a scene
1. Create a file with `@MainActor func myScene(size: CGSize) -> SKScene` and add it to `scenes` in Scenes.swift.
2. Build everything visible in `init` or `sceneDidLoad`. The render test uses `SKRenderer`, which never calls `didMove(to:)`.
3. Start live services (`Location.shared.start()`, network polling) in `didMove(to:)`.
4. Drive periodic work with SKActions or `update(_:)`, not Timers, so it stops while the wallpaper is hidden.
5. Stay within budget: about 2 ms of CPU and 2 ms of GPU per frame at 2x Retina, as the render test prints it. Scenes run all day.
6. Look at the snapshot PNG before calling it done.

## Gotchas
- SKShader is GLSL-like and gets translated to Metal. There's no `inout`. `u_time` follows the wall clock, so `SNAPSHOT_SECONDS` doesn't move shader animation forward (SKActions do move forward).
- Globals in `main.swift` are set up by top-level code and aren't safe to use from tests. Put shared state in other files.
- Swift 6 strict concurrency: AppKit and CoreLocation delegate callbacks are `nonisolated` and use `MainActor.assumeIsolated`.
- `paint(_:_:)` draws at 2x, so the texture's pixel size is double. Give sprites an explicit size.
- Data must be public domain or permissively licensed. Cite the source in a comment or in the data file's header.

## Conventions
- Minimal code, no dependencies, native frameworks first. Mark deliberate shortcuts with `ponytail:` comments that say where the shortcut stops being good enough.
- Match the code around you: doc comments on types and functions, sparse comments inside them.

## Git
- **Commit early and often.** One logical change per commit, made as soon as it builds and `swift test` passes. Don't bundle unrelated work together.
- Messages: a plain-English imperative subject that says what changed and why, e.g. "Pause rendering while the wallpaper is covered".
