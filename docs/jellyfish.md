# Jellyfish

Jellyfish drifting and pulsing in dark water, drawn by shaders rather than cut out of photos: real species at their real sizes and pace, lit by a dim lamp, or glowing with their own light only as the real ones do. Every bell squeezes quickly, re-opens slowly and coasts, with its margin lagging behind. Its tentacles trail from where the margin was a moment ago, so a squeeze or a turn runs down them.

It began in [ideas.md](ideas.md) under "Left out on purpose": "Photo cut-outs of big animals never moved convincingly in the Fish Tank's Ocean Voyager and Shallow Reef ... Jellyfish would have to be drawn by a shader, not cut out, to be worth another try." Dave ran it through the new-wallpaper process on 2026-11-07, as "A shader-drawn bell on black, dim and bioluminescent, is the version worth a mock-up." That day two agents researched it and one round of mock-ups was drawn. Nothing is built.

- **Source:** `Sources/Atrium/Jellyfish.swift`: the scene, its motion and its shaders, all in one file.
- **Data:** none. Everything is drawn; reference photos stay references.
- **Research:** [the method](jellyfish/research-method.md) (swimming numbers, bioluminescence, how to draw it, cost measured with a SpriteKit probe), [the look](jellyfish/research-look.md) (species, palettes, brightness, names) and [how real groups move](jellyfish/research-motion.md), measured from nine freely licensed clips of real tanks and a wild bloom. Every figure in them is marked checked or unchecked.
- **Scripts:** `jellyfish/mock.swift` draws the mock-ups with SpriteKit as the app would; `sheet.py` lays out the sheets and films from the variants in `variants.py`.
- **Where it stands (2026-11-08):** built and hidden behind the `unfinished` switch; the motion was reworked after Dave's first look on his desktop (step 2 below).

## Dave's decisions (2026-11-07)
- **Groups, not a single jelly:** "the single jellifish is very underwhelming, we need to focus on groups that are moving". The deep species, the close-up and the ROV and lights-off looks are set aside.
- **Three looks,** from round 1's sheet 1, D, E and F, after round 2's films ("its looking good, lets offer all 3 options"): crystal jellies under blue light with their green rings (D); moon jellies in the lit blue tank (E); the same moon jellies with a steady blue glow (F). F is made up, and the sheet said so.
- **Two automatic modes:** "an auto mode for system along with a mode that follows day/night where E is the light mode, F or D is dark". So a Look menu of five: follow Light and Dark Mode, follow day and night where you are, or one of the three always. **As decided in the build:** which dark look the automatic modes use is a setting, F by default, since F is the same moon jellies as E and the change is then only the light.
- **Natural motion first:** "we need to really focus on natural movement". The motion is set to what research-motion.md measured from footage, and is judged in films before stills.

Still his to decide, once it runs on his desktop: the pace, and whether the crystal jellies' rings should give way more to their bells.

## Names and look-alikes
- **Jellyfish** is the name proposed: plain, like Fireflies. "Jellies" sits beside Apple's own Palau Jellies and Alaskan Jellies aerials, and "Deep Sea" is too near Space Tour's deep space. JELLYFISH is registered in the US for unrelated goods only, checked through third-party mirrors ([research-look.md](jellyfish/research-look.md) §6).
- **Every Mac already has filmed jellies,** in those aerials. This one has to be what film can't: deep species, their own light, never repeating, tunable.

## Mock-ups, round 1 (2026-11-07)
Drawn by `mock.swift` through SKRenderer, as the render test draws a wallpaper, so a tile shows what the app's shaders can draw. Each jelly is one sprite with a shared shader, as the method research recommends. The bell is marched through in 40 steps, so its rim is bright where the line of sight grazes the tissue, not painted on. The pulse, the lagging margin, the delayed-follow tentacles and oral arms, and the turns made only while squeezing all follow research-method.md §1. Jellies are simulated in metres at their real sizes and seen through a camera 50° across, set back as far as the animals are big. Desktop tiles are a 14-inch display at 2x, scaled down.

```sh
cd docs/jellyfish && swiftc -O mock.swift -o $TMPDIR/jelly-mock
python3 sheet.py sheet1-light .   # or sheet2-species, sheet3-crowd, sheet4-motion, sheet5-desk, film1-deep, film2-pulse
```

Each question, with my recommendation:

1. **What light shows them** ([sheet1-light.jpg](jellyfish/sheet1-light.jpg)). A, Into the Deep: a dim lamp on deep red Periphylla, Atolla and a comb jelly on black, after Monterey Bay Aquarium's gallery. B, an ROV's lights: near ones bright, far ones gone, lit marine snow. C, lights off: only their own light, which real jellies make only when touched, so the screen is mostly black. D, crystal jellies under blue light, their fluorescent green ring always on. E, the jelly gallery's lit blue tank of moon jellies. F, a steady blue glow, which no jelly makes. **Recommended:** A as the standard, E as its Light Mode, and B, C and D as a Look menu. F only if Dave wants it knowing it's made up.
2. **Which animals** ([sheet2-species.jpg](jellyfish/sheet2-species.jpg)): moon jelly, Pacific sea nettle, crystal jelly, crown jelly (Atolla), helmet jelly (Periphylla), lobed comb jelly. **Recommended:** each look keeps the animals that really live together: the deep ones in A, B and C, crystal jellies in D, moon jellies and sea nettles in E.
3. **How many, and how near** ([sheet3-crowd.jpg](jellyfish/sheet3-crowd.jpg)): four; ten near, middle and far; one up close; a bloom of thirty helmet jellies, as Norway's Lurefjorden has. **Recommended:** ten as standard, with a slider up to the bloom.
4. **The motion** ([sheet4-motion.jpg](jellyfish/sheet4-motion.jpg), [film1-deep.mp4](jellyfish/film1-deep.mp4), [film2-pulse.mp4](jellyfish/film2-pulse.mp4)): a moon jelly's pulse, a sea nettle's turn, and 12 s of each at the real pace. The research's biggest risk is motion that still reads fake, and its third is the real 0.4 s squeeze feeling twitchy. Judge both from the films. **Recommended:** the real pace as 1× on a Speed slider.

[sheet5-desk.jpg](jellyfish/sheet5-desk.jpg) is A at full size under a menu bar and desktop folders.

## Mock-ups, round 2 (2026-11-07)
Groups only, in Dave's three lights, with the motion rebuilt and then set to what the footage measured ([research-motion.md](jellyfish/research-motion.md)). [round2-still.jpg](jellyfish/round2-still.jpg) is one moment of each; the films are what to judge: [film-d.mp4](jellyfish/film-d.mp4) (16 crystal jellies), [film-e.mp4](jellyfish/film-e.mp4) (28 moon jellies in the lit tank) and [film-f.mp4](jellyfish/film-f.mp4) (the same 28 with the steady glow), each 20 s in real time at half a 14-inch display's pixels.

What changed from round 1, each against the footage:
- **Poses in 3D.** Each bell's axis points any way in 3D and keeps changing: a slow drift of the axis between pulses, a rock of about ±6° with each pulse, and turns of 11 to 40° in two squeezes of five. Righting goes as the sine of the tilt, so a tipped bell comes back slowly and an upside-down one hardly at all, and the tank's current turns the bells it carries.
- **The pulse.** A pulse every 1.6 s at 15 cm, each jelly at its own rate and each pulse a little different. The squeeze is 39% of the cycle and re-opening the rest, with no long coast. Moon jellies go about 0.2 diameters a pulse.
- **The group.** Jellies spread through a tank as deep as the view, coming nearer and going back, carried round by a current of 2 cm/s at its rim. A jelly that touches another stops pulsing for a second or two, then turns 45 to 90° away. A few rest for 6 to 10 s and sink.
- **Tentacles and arms** hang along a spine laid out from where the bell's axis pointed as the margin passed, so a turn, a tumble or a tilt toward the camera all run down them. The moon jellies' arms flick out at each squeeze. Crystal jellies' tentacles stream about three diameters behind in loose bundles of uneven strands, and they pulse in irregular bursts.
- **A slight upward look** of 12° into the tanks of D and E, as people look into a tall jelly tank; it shows more undersides and their four gonads.

The simulation measured as the footage was, over 120 s of 28 moon jellies:

| | Simulation | Footage |
|---|---|---|
| Side-on bells from vertical, median | 34° | 26° |
| Side-on bells 45° or more over | 34% | 34% |
| Axis turn rate, median (90th pct) | 7.0°/s (24) | 6.5°/s (18) |
| Nearest neighbour on screen, median | 0.76 diameters | 1.0 diameters |
| Screen covered by bells | 14% | 16 to 46% |
| Dome-down, of side-on bells | 6% | about 45% on a tank's downward side; most up in another tank |

The face-on, oblique and side-on shares don't compare: the footage classed blobs by silhouette, and a side-on moon jelly with its arms hanging reads as oblique there.

Questions for round 2:
1. Does the motion read as natural now, in each film? If not, which jelly at which moment looks wrong.
2. D, E and F as one wallpaper with a Look menu, E following Light Mode and F or D in Dark Mode, or fewer?
3. How many: 28 moon jellies and 16 crystal jellies here, as dense as the footage's tanks.

## The build so far
**Step 1 (2026-11-07): the whole of round 2, in the app, hidden.** The mock's model, already judged by Dave in films, was ported whole rather than in steps: the bell, the pulse, the motion measured from footage, the spine the tentacles hang along, the touch and turn away, and all three looks with their automatic modes. What changed on the way in:
- **Cost.** As ported it drew in 5.35 ms of GPU. Each part now runs only where it can be seen: the bell is marched only inside its outline and only through its own depth, in 20 steps rather than the mock's 40; the gonads only near their height; tentacles and arms only within their reach down the spine; and each pixel looks at the four strands nearest it on each side of the ring rather than all of them. That came to 1.56 ms, with no change to be seen in the picture.
- **Time.** The pulse reaches the shader as seconds since it began, not as a clock, so it stays exact however long the scene runs; the sway and the marine snow take the scene's own clock wrapped hourly.
- **Groups.** Moon jellies and crystal jellies are two groups, each with its own shader and a fade. A group is filled only when it's to be seen, run 10 s at once so its poses, pulses and tentacles are already under way, and emptied when it has faded out.
- **The look.** One shader draws a moon jelly lit and glowing and mixes the two by how lit the tank is, so Light and Dark Mode, or dusk, change only the light; the crystal jellies fade in as their own group. The scene watches the appearance itself (`followsAppearance`), and checks the Sun every minute.

**Step 2 (2026-11-08): getting somewhere as they pulse.** Dave, on his desktop: "they seem to not move very much at all as they pulse". Measured as the footage was (`jellyfishMoveAsFootage`, two minutes of 28 moon jellies), they crossed the screen at 0.08 diameters a second relative to the group, against the footage's 0.14, and 56% of them sat in the top third with 10% in the bottom: drawn only upward, the upright ones swam to the top and pulsed against it going nowhere. Steady-camera clips reviewed this round (research-motion.md, addendum) show a lone jelly can pulse nearly in place for seconds too, so speed alone wasn't it: a whole group pinned to the top was. A lone lab jelly goes about 0.57 diameters a pulse (derived from Gemmell 2013). Three changes:
- **Half a diameter a pulse** for moon jellies (was 0.22), 0.35 for crystal jellies (was 0.25): between the footage's figure, a floor since it's measured against a group that swims too, and the lab's.
- **The group's loop.** Each bell is drawn round a slow loop through the view, up one side, across the top, down the other and back across the bottom, weakly near the middle and with the sideways legs half as strong as the upright ones, as wild aggregations swim up at one end and down at the other (Albert 2011, p479). It replaces righting toward up, and leaves as many bells pointing down as up.
- **The sides turn a bell away** within a bell's width of them, as a kreisel's wall flow does; without it the loop carried them into the sides to ride round pressed against them.

| | Step 1 | Step 2 | Footage |
|---|---|---|---|
| Speed relative to the group, median | 0.08 D/s | 0.18 D/s (0.15 at seed 7) | 0.14 D/s (a floor) |
| Top third / bottom third of the screen | 56% / 10% | 25% / 35% (31% / 26% at seed 7) | jellies everywhere |
| Pointing within 45° of up / of down | 41% / 1% | 22% / 16% | about half dome-down on a tank's downward side |
| Side-on bells from vertical, median | 36° | 37° | 26° |
| Face-on bells | 18% | 21% | 10% |

Cost is unchanged: 1.5 to 1.8 ms of GPU.

**Step 3 (2026-11-08): twice as many.** Dave, on step 2 on his desktop: "it looks much better, i just think that by default there should be a lot more of them, at least 2x more". So 56 moon jellies and 32 crystal jellies at 1× (up to 84 and 48 at 1.5×). Twice as many in the same tank doubled the cost of drawing them (3.4 to 4.1 ms of GPU), most of it in the near bells, which are the biggest. So the tank now runs 3.5 times the animals' size deep rather than 2.2, and the added jellies are mostly the small, distant ones the Monterey footage is full of, with about as many near the glass as before. Speed and spread measure as in step 2 (0.16 to 0.17 diameters a second relative to the group; 27 to 28% of them in the top third, 31 to 32% in the bottom). Two savings came out of it with no change to the picture: the axis history is kept already turned by the camera's pitch, rather than turned 32 times a jelly every frame, and the tentacles' spine is laid out in 16 steps rather than 32; together they cut the scene's own update from 2.5 to 1.5 ms in a debug build (0.1 ms in release). Sixteen march steps through the bell instead of 20 was tried and not kept: it showed grain and softened the rims.

## Settings
- **Look** (`jellyfish.look`, a menu): lit tank in Light Mode, glow in Dark Mode (the standard); lit tank in Light Mode, crystal jellies in Dark Mode; lit tank by day, glow at night; lit tank by day, crystal jellies at night; lit tank; glow; crystal jellies. Each pick says what it does, rather than a second menu for the dark look that would show for only four of the seven picks, which a knob can't express. By day means the Sun where you are: the tank's light eases through civil twilight, from 6° below the horizon to 1° above.
- **Jellyfish** (`jellyfish.count`, 0.5 to 1.5×): 84 moon jellies or 48 crystal jellies at 1×, Dave's pick from trying the slider (1.5× of step 3's 56 and 32, which were twice the first 28 and 16). A change refills the tank.
- **Speed** (`jellyfish.speed`, 0.5 to 1.5×, standard 0.8×): the scene's clock, so pulses, turns and drift keep their proportions. 1× is the real pace; 0.8× is Dave's pick from trying it.

## Cost
Measured by the render test at 2x Retina on an M3 Max, debug build (release CPU is lower), with the seed pinned:

| Look | CPU | GPU |
|---|---|---|
| Lit tank, 84 moon jellies | 4.9–5.1 ms | 3.9–4.2 ms |
| Crystal jellies, 48 | 2.5 ms | 2.6–3.9 ms |

At 4 and 8 s in, with Atrium quit: a copy on the desktop shares the GPU and more than doubled the readings. That is about twice the 2 ms of GPU a wallpaper aims for, the price of three times as many as at first: 28 moon jellies drew in 1.56 ms and 56 in 2.9. In a release build 56 moon jellies took 0.7 to 0.95 ms of CPU; 84 weren't measured there.

No `batteryRate` yet: a near bell's margin moves about 3 device pixels a frame at 20 fps in the squeeze, a little over the 2 that can't be seen, so 20 fps waits on Dave seeing it side by side, as research-method.md advised.

## Checking it
```sh
defaults write com.dtanquary.atrium unfinished -bool true   # show hidden wallpapers, then relaunch
SNAPSHOT_SCENE="Jellyfish" SNAPSHOT_APPEARANCE=light SNAPSHOT_DEFAULTS="jellyfish.seed=22" swift test --filter everySceneRenders   # the lit tank
SNAPSHOT_SCENE="Jellyfish" SNAPSHOT_APPEARANCE=dark SNAPSHOT_DEFAULTS="jellyfish.seed=22" swift test --filter everySceneRenders    # the glow
SNAPSHOT_SCENE="Jellyfish" SNAPSHOT_DEFAULTS="jellyfish.seed=21,jellyfish.look=6" swift test --filter everySceneRenders          # crystal jellies
swift test --filter jellyfishMove                    # speed and spread measured as the footage was; JELLY_SEED and JELLY_LOOK pick another
```
`jellyfish.seed` (any whole number but 0) pins the tank's layout and every pulse and turn, for pictures that can be taken again; unset, each load is new. The Settings pictures are `preview-jellyfish.jpg` (the glow, Dark Mode's standard) and `preview-jellyfish-light.jpg` (the lit tank), from the first two commands. The mock and its statistics, which measure poses, turns, spacing and cover as research-motion.md measured footage, stay in `docs/jellyfish/` (`JSTATS=1` on `mock.swift`).

## Shortcuts
- The sway and the marine snow jump once an hour where the shader's clock wraps.
- Every pair of jellies is checked for touching every step; fine at 84 at most.

## Dave's feedback
- **2026-11-07, on round 1:** "the single jellifish is very underwhelming, we need to focus on groups that are moving"; "sheet-1 is the best, and within that items D, E, and F are what we should focus in on"; "we need to really focus on natural movement, do more research if needed, its not quite there yet". So round 2 is groups in motion only, in three lights: crystal jellies under blue light with their green rings (D), moon jellies in the lit blue tank (E), and the steady blue glow (F), which no real jelly makes and the sheet said so. The deep species, the single close-up and the other sheets' questions are set aside. Motion gets its own research, measured from footage of real groups.

- **2026-11-08, on step 1 on his desktop:** "the overall movement of the jellyfish still doesnt seem very natural, they seem to not move very much at all as they pulse, please review video footage of dense jellyfish population and attempt to recreate that". So step 2: twice the travel per pulse, the group's loop round the tank, and the sides turning bells away.
- **2026-11-08, on step 2's film beside step 1's:** "the new motion is much better".
- **2026-11-08, on step 2 on his desktop:** "it looks much better, i just think that by default there should be a lot more of them, at least 2x more". So step 3.
- **2026-11-08, on step 3, after trying the sliders:** "1.5x population and 0.8x speed is my ideal sweet spot in testing". So those are the standards: 84 moon jellies and 48 crystal jellies at 1×, and Speed at 0.8×, with 1× kept as the real pace.

## What the mock-ups showed
- **Deep jellies are small.** At 6 to 15 cm, a camera 1 to 6 m off made them specks. The camera is now set back by the animals' size: about 45 cm to 4 m for the deep set, and half as far again for moon jellies.
- **At the real pace they leave.** In the model a 15 cm helmet jelly climbs about 19 cm in 20 s, off the top of the view. A build needs them to come back in, or, for a tank, what aquariums do: a kreisel's slow circular current, which keeps jellies off the walls and in front of the glass.
- **A turning jelly's sprite must widen.** For a few seconds after a turn its far tentacles still hang the old way, outside a box sized for a straight jelly. The mock widens the box by the sine of the turn.
- **Brightness at desktop size**, the brightest of R, G and B out of 255, against the look research's caps (backdrop to 8, broad light to 150, pinpoints to 190):

  | Look | median | 99th pct | 99.9th | max |
  |---|---|---|---|---|
  | A, Into the Deep | 3 | 64 | 94 | 104 |
  | B, ROV lights | 0 | 104 | 135 | 177 |
  | C, lights off | 0 | 34 | 77 | 125 |
  | D, crystal jellies | 6 | 71 | 135 | 157 |
  | E, lit blue tank | 144 | 222 | 255 | 255 |
  | F, steady glow | 0 | 44 | 79 | 151 |

  E is a Light Mode scene and bright on purpose, but jellies clip to white where they overlap on the blue.
- **Not measured:** the mock's cost. It loops over every tentacle and marches 40 steps, where the method's probe measured 0.45 to 0.75 ms of GPU for ten jellies with 24 steps and only the nearest tentacles looked up.

## Still open
- Round 2's open points: the crystal jellies' green ring still outshines their bells; the share of bells upside down is the weakest measurement (22 bells, one side of one tank); the touch behaviour comes from one filmed meeting.
- Dave's picks for the four questions above.
- After step 2, side-on bells lie further from vertical than the footage's (37° against 26°), and twice as many face the camera (21% against 10%). A stronger pull round the loop didn't change either.
- The comb jelly is the weakest drawing: its rows read as dots at a distance.
- The moon jelly's four gonads read as a cross seen side-on; seen from above they'd be its four rings.
- Whether "bioluminescent" in the brief means C (true and mostly black) or F (made up and lovely).

## Sources
The two research reports, [research-method.md](jellyfish/research-method.md) and [research-look.md](jellyfish/research-look.md), carry every source and its licence.
