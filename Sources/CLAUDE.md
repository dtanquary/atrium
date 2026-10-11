# Atrium's app code

For work on the app's Swift code: how a wallpaper's settings are declared, adding a scene, and the SpriteKit and shader gotchas. The app as a whole, the commands, and the rules for commits and versions are in `../CLAUDE.md`.

## A wallpaper's settings
A wallpaper's settings are plain data on its `Wallpaper` entry in Scenes.swift:
- `knobs`: sliders, switches with `format: .toggle`, or menus with `format: .choice([names])` (stored as the index), or multipliers with `format: .times`, grouped by `section`. A knob can depend on a switch with `shownWhen`, hide behind one with `hiddenWhen`, or (a slider) be held at its standard value by one with `lockedWhen`.
- `palettes`: a `PaletteChoice` of named swatches. The pick is stored by name, and an empty value means Random.
- `status`: a UserDefaults key the scene keeps a line of text in (Weather's last live report), shown under a knob while that knob is 0.
- `refresh`: a `Refresh` (Scenes.swift) for Refresh Now on its page: fetch its live data now, within the source's own cooldown. Open-Meteo counts every point in a request as a call, so shrink grids and fetch longer forecasts less often rather than polling faster.

Knobs are stored in UserDefaults. `knob.value` is cached (emptied on any defaults change), so reading it every frame costs a lookup. Live scenes read `knob.value` and observe `UserDefaults.didChangeNotification` to feed their shader uniforms (see `FlowingGradient` and `LavaLamp`). A plain shader scene can instead pass `knobs:` to `shaderScene`, and each knob becomes a live uniform; a `speed:` knob adds `u_clock`, time that runs at that speed without jumping when the slider moves (see Rain on Glass). `gradeKnobs(prefix)` plus `grade()` in the shader add the shared brightness, contrast, saturation and hue sliders (see Nebula). A new palette pick rebuilds the scene if it's on the desktop. To tune, read the values back with `defaults read com.dtanquary.atrium`.

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
- SKShader has `fwidth` but not `dFdx` or `dFdy`: they fail at run time ("use of undeclared identifier 'dFdx'"), which `swift build` won't catch. `fwidth` is the sum of the two slopes, so it runs about 4/π high for a slope in any direction (Black Hole takes that off).
- A branch on a uniform can change the picture where it never runs: giving Black Hole's shader a second mode behind `if (u_mode > 0.5)` moved 47 pixels by 1 of 255 with the mode off, because Metal laid the arithmetic out differently round it. Where a picture has to stay the same to the byte, write the variant as a second copy of the source (Black Hole's offscreen disc for its glow).
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
