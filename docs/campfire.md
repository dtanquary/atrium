# Campfire

A campfire in a ring of upright stones, in a real forest clearing at night under the real stars. The flames are a small fluid simulation, drawn as crisp tongues and torn wisps and coloured the way a camera records fire. Their light, measured from the flames themselves, falls on the stones, the charred sticks, the ground and the nearest trunks with the right distance, angle and shadows, and flickers as they do. Sparks rise in streaks, embers glow in the bed, and a faint warm haze, glow and heat shimmer hang over the flames.

- **Files:**
  - `Sources/Atrium/Campfire.swift`: the `Campfire` scene, the relighting shader, `FireCamera`, `CampfirePhoto` and `StarField`
  - `Sources/Atrium/CampfireFlames.swift`: `Flames`, `FlameSim`, `Sparks`, `coalBed` and `firePhoto`
  - `Resources/campfire-ground.heic`, `campfire-ground-aux.png`, `campfire-bed.png`, credited in `campfire-credits.tsv`
  - Live Sky's catalogue, `LiveSky.catalogue` and `LiveSky.starColour`, for the stars
- **Entry:** `campfire(size:)`, icon `flame.fill`, tint `.red`.
- **Kind:** photo ground relit in a shader, a CPU fluid simulation drawn by a shader, SpriteKit sprites.

## The backdrop and its bake
Baked offline from CC0 sources; the scripts are described below so it can be redone.

- **Photo:** Poly Haven's "Hochsal Forest" (Adrian Kubasa), an overcast 16k panorama (really 16192 × 8096) of a cleared patch of forest: a spruce stand behind bare beech, with open sky above. Overcast light is soft and even, which makes it easy to take out.
- **View:** reprojected from the linear EXR (read through ImageIO, since Python has no EXR reader here) to a pinhole camera 1.6 m up, pitched up 3°, 84° across 4096 × 2660 px (1512:982), facing yaw 292° in the panorama, away from the fields and the power line through the gap.
- **Sky:** cut per pixel, not along a skyline, because it shows through bare twigs everywhere. The local sky colour is estimated from clearly-sky pixels, and each pixel is unmixed as `α·branch + (1−α)·sky`, taking α as the smaller of a brightness estimate (bark ≈ 6% of the sky) and a blueness estimate (the sky is bluer than bark or needles). The second keeps pale beech trunks solid. Pixels that are mostly sky borrow the colour of solid branches nearby rather than trusting the unmix.
- **Distance:** Depth Anything V2 (Core ML), tiled as for Fireflies, then made metric by fitting `1/z = a·disparity + b` to the ground's exact distance under a flat plane 1.6 m down. The fit uses ground from −3° to the bottom, which puts the spruce stand at 21–24 m. Fitting only the near ground put everything at 14 m or nearer.
- **Normals:** from the gradients of the reconstructed world positions (lightly blurred).
- **Albedo:** the unmixed colour with its overcast light flattened (`FLAT` 0.3) and scaled so the open ground's median is 0.14; saturation 0.85.
- **The fire pit and wood:** "Stone Fire Pit" (Sebastian Platen): upright slate slabs, 1.45 m across and 0.39 m tall, with a gap at the front. Seven or eight "Dry Branches Medium 01" (Rico Cilliers) are leaned into a low teepee, shortened to 55% and thickened 1.7×. They're rendered with SceneKit offline, from the same camera, in albedo, world-normal, distance and wood passes; SceneKit writes to an sRGB target, so the data passes are decoded from sRGB. The pit sits 4.5 m ahead. They're merged into the photo's albedo, distance and normals, so one shader lights everything. The stones are darkened to 45% (soot and weather) and the wood takes one flat colour to its edges (no halo). Near the pit, the photo's ground takes the flat plane's exact distance, which is what the model stands on.
- **Shipped:** `campfire-ground.heic` 4096 × 2660, sRGB albedo × 0.5 with the sky matte in alpha (2.4 MB). `campfire-ground-aux.png` 2048 × 1330: R log distance (1–400 m), G/B the world normal's x/y. `campfire-bed.png`, the crop around the fire (px 1640–2452 × 1740–2372, fixed so the scene's constant holds): R wood, G pit and wood.

## How it draws
Back to front:
1. **Sky** (z −1000): a moonless gradient, brighter low down (airglow and far towns) so the treeline stands out, plus a faint tail of procedural stars (`starField`, clumped). All in linear light through the tone curve.
2. **Real stars** (z −900): `StarField` places every catalogue star brighter than V 5.5 that is above the horizon and in view, for the viewer's location and time, facing the equator. It refreshes every 10 s. Size and alpha follow flux; they're tinted by B−V (half-desaturated) and dimmed near the horizon by 0.25 magnitudes per airmass. The photo's tree crowns and twigs cover them, since the photo's alpha is the sky matte.
3. **Ground, back slice** (z 0): the whole photo relit (below).
4. **Coal bed** (z 1): `coalBed`: Voronoi blocks ~2 cm across, with cracks 120 K hotter than the faces, each block breathing ±40 K on its own rhythm. It's hottest in the middle (~1050 K), with ash where it's cooler, through the camera colour.
5. **Flames** (z 2), additive, standing at the pit's middle (below), with the smoke haze (z 2.5) over them.
6. **Ground, front slice** (z 3): the same shader on a sprite over just the fire bed, drawing the stones and sticks nearer than 4.25 m over the flames (sticks nearer the middle stay behind them, as flames wrap round real logs). Its texture coordinates are still the whole photo's (`SKTexture(rect:in:)`).
7. **Sparks** (z 4), then the glow (z 5).

**Relighting (`groundSource`).** Albedo is `2·tex^2.2`. The aux map puts each pixel in world metres (x right, y up, z forward) from the camera ray and its distance. Firelight is a point at the flames' centre (moving with them). It's 1900 K through the camera's 3200 K balance, linear (1, 0.41, 0.09), × 2.6 × the flames' current light, over `r² + 0.16` (the flames are a broad source, so nothing right beside them blows out), times wrapped Lambert on the normal, plus 7% that reaches every face (bounce off the lit ground and the far stones, so the front stones aren't black). The stones hide the flames' lower part from anything outside the ring: from a point at horizontal distance `d` and height `y`, flames below `y + (0.39 − y)·d/(d − 0.72)` are hidden, and the lit share is `0.2 + 0.8·smoothstep` over a 1.05 m tall source (the floor is bounce off the far stones). The photo's own ground always counts as outside the ring (the bed mask's G), even where the depth estimate strays inside it; otherwise the ground behind the pit's front gap glowed. Wood is charred to 20% of its albedo and glows in its cracks (noise, 820–1020 K) in the lowest 0.35 m. Faint starlight (0.0020, 0.0026, 0.0042) lights everything, and the tone curve is `1 − exp(−1.4·x)` per channel. In the back slice, a column of hot air over the fire (0.3–2.2 m up, about 0.35 m either side) wobbles the view by about a pixel: heat shimmer, which shows on the firelit sapling behind.

## The flames
They paint temperature and soot, never colour, and put them through a camera. It's blackbody light white-balanced to 3200 K (R = exp(−22800·(1/T − 1/1300)), G = 0.165·exp(−26600·(…)), B ≈ 0), times `1 − exp(−τ)`. Then exposure 10, 1% crosstalk into all channels, and a per-channel `1 − exp(−s)`: red clips first, then green, and crosstalk lifts blue. That is why thick, hot flame comes out pale yellow-white, with orange and red at the thin, cooler edges, as in photos.

- **Sim:** two independent sheets of `FlameSim`, as a real fire is many flame sheets at different depths. Each is stable fluids (Stam 1999) on a 64 × 128 grid over 1 × 2 m, open on every side (the box starts inside the pile, so air also comes up from below; a closed floor made the flames run sideways along it).
  - **Physics:** buoyancy 9.8 × T, vorticity confinement ε 28, fuel burning at 1.2/s into heat, cooling at 5/s. The edges are sponged so the far air stays still; without the sponge the whole box drifted and blew up. Velocities are clamped.
  - **Solver:** red-black SOR (ω 1.8, 12 iterations, warm-started), semi-Lagrangian advection, and raw buffers with a ghost border.
  - **Fuel:** 32 patches in a 0.7 m pile. Each lets gas out in its own gusts (smooth random, six a second), and the whole bed puffs together at ~2 Hz (the base vortex, Cetegen and Ahmed 1993). Tuned against the real clips: area RMS 11% (real 8.6–10.6%), height RMS 13–15% (real 11–16%), half-times 100–133 ms (real ~100 ms), median height 0.6 m on a 0.7 m pile. The slow sine breathing it replaced flickered five times too slowly.
- **Draw:** the sheets' temperature and fuel go to an `SKMutableTexture` each step (bytes packed on the main thread). The shader is a hybrid: the simulation says where flame is and how hot, and the research agent's procedural recipe draws what's inside.
  - **Envelope:** where fuel is hot enough for soot to glow (`smoothstep(0.25, 0.55)` of T), read through a slight warp so the 1.6 cm cells don't show. So the flames lean, puff and pinch off as the simulation does.
  - **Tongues:** 5 octaves of 3D noise, 12/H across by 2.4/H up, read at the time the rising gas takes to reach that height (`u = U√(z/zc)` to 0.4 H, then U = 1.9 H/s), so features speed up and stretch as real ones do. Each octave evolves 1.6× faster than the last, not 2×, which would make fine detail boil. Presence is `F = E − 0.5 + 1.45·n·reach`, with a 2–3 px soot edge (`smoothstep(−0.02, 0.02, F)`).
  - **Thickness and colour:** soot thickness has vertical streaks, and T is 930–1500 K from the simulation, cooler at thin edges, plus noise. It's averaged over a 1/60 s shutter (two samples) and skipped where the box is empty.
  - **Sprite:** it shows the bottom 1.3 m of the box, faded at its edges, drawn 1.25× life size.
- **Light:** `light` (≈1 on average) and `centre` are measured each step from hot fuel, weighted as blackbody light is. The scene lights the ground with `0.2 + 0.8 ×` that light, smoothed over 0.15 s: the embers are a steady floor, and near ground in the clips smooths like that.

**Smoke and glow.** A faint warm haze rises about 1 m/s from the tips to 1.5 m, in a cone widening 0.12 m per metre. It's noise lit from below by the firelight (1/r²), coloured about 2:1.2:1, which matches the few sRGB levels the footage shows at night. Two additive halos follow the light, a tight one (1.3 m, 10%) and a wide one (3.2 m, 4.5%), for lit air and lens flare. They're kept weak, since heavy glow is a tell of game fire.

**Sparks.** A pool of 48 streak sprites, never an emitter (emitters can't turn particles along their motion).
- **Birth:** about three a second, plus a pop every 5–20 s that throws 20–40 over about 0.2 s.
- **Launch and motion:** they leave at 0.8–1.5 m/s, or 2–4 m/s in a pop, into a plume rising 2.6 m/s that slows above 0.4 m, pushed about by eddies.
- **Look:** each is drawn as the streak a 1/60 s shutter makes.
- **Life:** as in the footage (sparks above small fires e-fold within 0.4–0.5 flame heights), they live 0.25–1.2 s (log-normal). They hardly cool (120 K) before half of them wink out.

## Settings
None. The flames are one engine now (see decisions).

## Time and appearance
Always night, with no Light Mode look. The sim, sparks, embers and firelight run on scene time. The stars are the real sky for the viewer's location right now (never daylight). Each load rolls new fuel patches, and the sparks are random.

**The shader clocks (`u_clock`)** are summed in Double (`time` in `Campfire` and `Flames`) and handed to the shaders wrapped hourly by `Flames.shaderClock`. They used to be summed straight into Float uniforms. The scene's clock then froze after about 6 days on screen at 60 fps, and the flames' after about 12, since a frame's step rounded away. Even a Float passed on from a Double coarsens as it grows: the flames read their noise at 3.8 units a second, with octaves up to 16× finer, so by a day or two the finest detail would step and block. The wrap keeps the Float under 3600, and costs a one-frame jump in the flame detail, smoke haze, heat shimmer and ember breathing once an hour. The tongues turn over every frame or two anyway, the haze is faint, and the shimmer is a pixel, so it passes for flicker. `ClockTests` checks the wrap.

## Performance
CPU 1.11 ms and GPU 0.84 ms per frame (release build, 2x, 2026-09-26). The simulation (two 64×128 sheets, one step each a frame) is ~0.55 ms of the CPU. Most of the GPU goes on the flames' noise, which is skipped where the box is empty. At 15 fps the sim still steps at 30 Hz of scene time (two steps a frame), so the CPU per second is the same. Memory: the ground texture is 4096 × 2660 RGBA, about 44 MB decoded.

## Gotchas and shortcuts
- **Offscreen tests:** `SK3DNode` (live SceneKit inside SpriteKit) blanks the whole `SKRenderer` render, so the scene would fail the render test. The pit and sticks are baked instead, and relit in 2D.
- **Sprite colour:** a sprite with a shader and a `.clear` colour draws nothing. Use `.black`.
- **Texture uploads:** `SKMutableTexture.modifyPixelData` may run later, on another thread. Pack the bytes first and capture a copy.
- **Pit gap:** the scanned pit has a gap at the front centre. That's why the photo's ground must never count as inside the ring.
- **Coarse depth:** the depth is only as good as Depth Anything's disparity plus a ground-plane fit. `ponytail:` it doesn't know the ground rises toward the forest, so far distances are rough; the light falls off so fast there that it doesn't show.
- **Wood colour:** the sticks' colour comes from the render, not the scan; `ponytail:` one flat charred colour, fine while flames cover most of it.
- **Shadows:** `ponytail:` the stones' shadow is analytic, for a ring 0.72 m out and 0.39 m high around the flames' axis. Shadows of the sticks, trunks and bench aren't modelled.

## Research
The research notes are in the session scratchpad (`notes/campfire-science.md` and `notes/campfire-footage.md`). The numbers used above:
- **Flame height:** Heskestad and McCaffrey give 0.3–0.7 m on a 0.4–0.6 m bed; the bottom 40% is solid, and the top comes and goes.
- **Puffing:** f ≈ 1.5/√D, 2–2.7 Hz.
- **Speed:** visible features rise 1.5–2.5 H/s (0.7 s base to tip, faster higher up), and flame shape decorrelates within 100 ms.
- **Flicker:** real clips flicker broadband, with a median of 1.6–2.8 Hz. Light on nearby ground swings 20–30% RMS, more than the clipped flames seem to, with a 150–330 ms half-time.
- **Colour:** soot is 1150–1400 K and embers 850–1100 K; firelight is ~1900 K.
- **What looks fake in CG fire:** summed soft blobs, colour by particle age, a fixed outline, symmetry, a sine-wave flicker, round sparks.

## Dave's feedback and decisions
- 2026-09-26: "start a fidelity pass on the campfire, same approach, do research on realistic looks, realistic forest backdrops, use our existing night sky star logic, and then try your best to create a realistic looking fire in the campfire".
- Research agents covered fire physics and camera rendering, measurements from real footage, and backdrop photos.
- **Backdrop:** Hochsal Forest was chosen for its soft, even light and open sky. Niederwihl Forest was the runner-up, a deeper forest with little sky.
- **Stars:** from Live Sky's catalogue, which is "our existing night sky star logic".
- **Flames:** the first build (0.20.0) had two engines behind a Settings choice. One was the simulation drawn softly; the other was the research agent's procedural shader, bright and crisp but smooth and patterned in motion.
- Dave, asked to compare: "do whatever you think would look best". I lined up consecutive frames of both against real footage (the Claytor Lake clip). Real fire has a bright clipped body, many sharp pointed tongues and torn fragments, all gone within a frame or two. So I locked in a hybrid: the simulation for where the fire is and its motion, and the procedural recipe for the tongues and the crisp edge. The Settings choice and the procedural engine were removed. Smoke haze, glow, heat shimmer and bounce light were added at the same time.

## Ideas / next steps
- Real footage of a real fire (Dave filming 2–5 minutes on a tripod at night) would be the ceiling for realism; it could come in as a choice to compare.
- The stars above the fire could shimmer too (they're sprites, so the sky shader's shimmer doesn't reach them).
- A Moon in its real phase, lighting the clearing a little.
- A log to sit on, lit on its side toward the fire.
- Logs slowly burning down over the evening.

## Checking it
`SNAPSHOT_SCENE=Campfire SNAPSHOT_SECONDS=4 swift test`. The sim, flames, sparks, embers and firelight all run on scene time, so they advance with `SNAPSHOT_SECONDS`; the faint star tail twinkles on `u_now`, which moves with it too. For cost, use `swift test -c release -Xswiftc -enable-testing`.
