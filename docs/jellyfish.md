# Jellyfish

Jellyfish drifting and pulsing in dark water, drawn by shaders rather than cut out of photos: real species at their real sizes and pace, lit by a dim lamp, or glowing with their own light only as the real ones do. Every bell squeezes quickly, re-opens slowly and coasts, its margin flapping a moment behind. Its tentacles trail from where the margin was a moment ago, so a squeeze or a turn runs down them.

It began in [ideas.md](ideas.md) under "Left out on purpose": "Photo cut-outs of big animals never moved convincingly in the Fish Tank's Ocean Voyager and Shallow Reef ... Jellyfish would have to be drawn by a shader, not cut out, to be worth another try." Dave ran it through the new-wallpaper process on 2026-11-07, as "A shader-drawn bell on black, dim and bioluminescent, is the version worth a mock-up." That day two agents researched it and one round of mock-ups was drawn. Nothing is built.

- **Source:** `Sources/Atrium/Jellyfish.swift`: the scene, its motion and its shaders, all in one file.
- **Data:** none. Everything is drawn; reference photos stay references.
- **Research:** [the method](jellyfish/research-method.md) (swimming numbers, bioluminescence, how to draw it, cost measured with a SpriteKit probe), [the look](jellyfish/research-look.md) (species, palettes, brightness, names) and [how real groups move](jellyfish/research-motion.md), measured from nine freely licensed clips of real tanks and a wild bloom. Every figure in them is marked checked or unchecked.
- **Scripts:** `jellyfish/mock.swift` draws the mock-ups with SpriteKit as the app would; `sheet.py` lays out the sheets and films from the variants in `variants.py`.
- **Where it stands (2026-11-09):** shown to everyone from 0.122.0, when Dave asked for it and Kelp Forest to go on the website and the README; it was built behind the `unfinished` switch, and the motion was reworked after his first look on his desktop (step 2 below).

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

**Step 4 (2026-11-14): the review's suggestions.** A review of every wallpaper found this one strong as a crowd ("the crowd and its drift are good from a distance") but drawn at about twice the GPU budget, with each jelly stopping dead between strokes, a bell that only rescales, and the nearest bells grainy with a comb for a fringe. Dave asked for all of its suggestions. Each is its own commit, the savings first; the numbers are the review's.

- **1. The shader no longer works where nothing is drawn.** Six cases the tests of step 1 were sized too generously for:
  - *The fringe.* On a tilted bell every pixel of its face ran all eight strand look-ups, where strands hang only in a band under the rim. Each side of the ring is now skipped unless the pixel lies between its own root on the ring and the strands' tips, with room for the three slots either way that the look-ups reach. The strands drawn are the same to the byte.
  - *The march.* The line of sight is first met with the bell's outline, an ellipsoid grown 0.08 radii past the skin's glow and cut by a plane just under the margin. Where it misses (the corners of the bell's box, about a third of what was marched) nothing is marched, and elsewhere the 20 steps are spent only between the two crossings. So the steps are about half as long as they were, and the faces of the near bells are less grainy for it: the one change to the picture. On the crystal jellies the ring's hundred points now show as beads where they glittered.
  - *The gonads.* The four rings mirror one another, so the pixel is folded into one quarter and one ring is worked out, not four. They differ by 4 of 255 at most, on the lines between rings.
  - *The arms* were looked for as far down as the fringe's ring reaches (1.1 radii); their roots spread 0.14.
  - *The sprite's box* was never under 2.8 radii wide round a bell 2.1 wide, 0.8 above it plus the whole tilt, and 0.4 below arms that had already faded out. It now holds what is drawn: the bell at its tallest, the fringe to its tips and the arms to theirs. `jellyfishBoxHoldsWhatIsDrawn` draws the tank again with a roomier box and checks the picture is the same, so a part that grows later has to grow the box with it. For that, the march's jitter is now taken from the pixel's place on screen, not its place in the box.
  - *The water* is exact black in the glow, as the scene behind it is, so its sprite is hidden there.

  Measured with the old and new shaders drawing the same tank turn about in one process, so other work on the GPU falls on both (four other sessions were rendering): the lit tank went from 3.9 to 2.3 ms of GPU at the median frame (2.4 to 1.4 at the quietest tenth), the glow from 4.3 to 2.4, the crystal jellies from 2.8 to 2.5. By part, in the lit tank: the fringe 0.67 ms, the march 0.49, the box 0.34, the gonads 0.27, the arms 0.19; and the glow's water 0.45. By the render test, six runs each back to back, the quieter runs read 2.2 ms before and 1.3 after for the lit tank, 2.05 and 1.25 for the glow. The crystal jellies gain little: their cost is tentacles seven radii long, which none of this shortens.

- **9. No jelly's history is copied any more** (the review's ninth, done second as the other saving). Each `Jelly` held the last 600 steps of its axis in an array of its own, for the spine its tentacles hang along. `move` works on a copy of each jelly and writes it back, so the first write to that array found it shared and duplicated all 19 KB of it: for every jelly, every step. The histories are now one array a group, written in place, and as long as the spine looks back and no longer: 34 steps for moon jellies and 141 for crystal jellies, where 600 were kept. The picture is the same to the byte in all three looks. In a release build, 84 moon jellies step in 0.03 ms where they took 0.07 to 0.08, and filling a tank (when the scene is built, at each tick of the Jellyfish slider, and when Settings opens its live copy) stalls for 16 ms where it took 42; 48 crystal jellies, 0.02 ms from 0.04 to 0.05, and 8.5 ms from 23. The review guessed more (0.05 to 0.2 ms a step, a stall of 60 to 150 ms). The ten seconds a new tank is run ahead stay as they were: at 16 ms they are one frame, and shortening them would change every pinned picture. The whole frame's CPU, SpriteKit's own work included, is 0.64 to 0.74 ms in a release build with 84 jellies, before and after: the first time 84 were measured there, and well inside 2 ms.

- **2. Each jelly carries its way, pulses less often, and is drawn round its dome.** Dave, watching step 3 on his desktop: "They dont seem to move far at all given how much they pulse, if they pulse a lot they should move more or just pulse less and move less, or be more of a sea of less movement but its just not compelling". Worked through in a port of the motion, the travel was about right in body lengths (0.43 of a diameter a pulse); the fault was how it was delivered. A jelly's speed was set afresh every step from where it was in its pulse, with nothing carried over: 78% of a pulse's travel came in the squeeze, its speed sat under a fifth of its mean for 38% of every pulse, and its dome, drawn from the margin up, slid back as the bell re-opened. Of three ways out (more travel a pulse; fewer strokes with glide; a sea of less movement) the second was taken:
  - *Momentum.* A jelly now has a speed of its own through the water (`way`), pushed along its axis through the squeeze and slowed by drag always, the drag sized to bleed it over 0.45 of a pulse (`glide`) and the push so that each stroke carries it its distance however the strokes fall (`carried`). Its speed dips to about a third of its mean just before the next stroke and peaks at twice it, as a real one's does (about 2: Gemmell 2013, with a third of each pulse's distance made after the bell re-opens); it had been nothing and 3.3 times. A turning bell skids, and one that rests or is touched coasts to a stop. `surge`, whose second push ran past the end of the pulse and was cut off at its peak, is gone.
  - *Fewer, longer strokes.* A moon jelly of 15 cm pulses every 2.5 s (was 1.6), squeezes for a quarter of it (was 39%, so the squeeze itself still lasts 0.6 s) and goes 0.6 of a diameter a pulse (was 0.5). **This departs from the display footage**, whose jellies pulse every 1.6 s, on Dave's word above; 2.5 s is what wild moon jellies of 15 to 25 cm pulse at (2.4 to 2.6 s, Rakow & Graham 2006), and 0.6 of a diameter is a lone lab jelly's 0.57. On screen at Speed 1× a stroke now comes every 3.6 s at the median where one came every 2.3. The crystal jellies keep their pulse and gain the glide.
  - *Turns ease in and out* over their squeeze, where they switched on and off.
  - *Axes ease toward the plane of the glass* (`flatten`, 0.08 a second). A bell facing us pulses without getting anywhere on screen, and 21 to 23% of them faced us where footage has 10%; now 9%.
  - *The bell is drawn round its middle,* half its height above its margin, where its mass is: so the dome glides and the margin does the moving. Pinned by its margin, the dome lunged a tenth of a diameter and slipped back.

  Measured as the footage was (`jellyfishMoveAsFootage`, seeds 22 and 7), before and after:

  | | Step 3 | Step 4 | Footage |
  |---|---|---|---|
  | Speed relative to the group, median | 0.18 and 0.15 D/s | 0.20 and 0.18 D/s | 0.14 D/s (a floor) |
  | Facing us | 21% and 23% | 9% and 9% | 10% |
  | Of the faster ones, travelling within 30° of their axis | 90% and 92% | 78% and 76% | 53% (9 of 17) |
  | Top third / bottom third of the screen | 34% / 29% and 26% / 28% | 31% / 28% and 27% / 32% | jellies everywhere |
  | Side-on bells from vertical, median | 41° and 45° | 41° and 41° | 26° |

  And followed on screen through 10 s of the lit tank, as the review followed one: a near jelly's speed ran from 2 to 10 device pixels a second between strokes up to 110 to 138 at each, every 2.3 s; one now falls away from 70 to 100 at a stroke to 10 or 12 just before the next. It costs nothing: one more vector a jelly, and less arithmetic a step than `surge` was.

- **3. A margin that flaps.** The bell was half an ellipsoid whose widest ring was always its margin, cut off flat, so in every frame it was an ellipse cap on a dead-straight base and the squeeze only rescaled it; the margin's lag moved its radius by 0.03 to 0.08. Now the outer sixth of the arc, below a hinge at 0.913 of the bell's radius and 0.408 of its height (the flexion point, 83% of the way from the apex: research-method.md), is a straight skirt 0.22 radii long whose angle follows the squeeze 0.15 s late: flared 55° out from straight down at rest, tucked 30° under at the full squeeze. So the bell rests as a saucer with its lip spread, and on the stroke the margin sweeps in under it; because the angle lags, the margin is still out as the bell starts to close and still in as it starts to open, the hysteresis research-method.md describes ("A bell that just scales is the commonest fake"). The skirt thins from the bell's thickness at the hinge to 0.06 radii at the margin, where the fringe and the crystal jellies' ring now hang, and each strand down its length takes the margin's radius from a moment before as it did. The sprite's box grows to the flared margin (`Species.rim`, 1.09 radii), and `jellyfishBoxHoldsWhatIsDrawn` still passes. It was tried in the app rather than in mock.swift first, judged by following one side-on jelly through a 6 s film; of two flaps, 50° out and 20° under, and 55° and 30°, the stronger read more as a bell and was kept. Both species have it. Cost, the old margin and the new drawn turn about in one process: about 0.05 ms more GPU for the lit tank and 0.08 for the crystal jellies, whose long tentacles look the margin up all the way down.
- **4. The grain is gone from the near bells' faces.** The skin is a glow 0.035 radii thick on each surface, and the march's steps are 0.05 to 0.1 radii long: where the line of sight crosses a surface squarely, as on the face of a near bell, most pixels' steps missed the skin and a few landed on it, so the face read as sand. The gonads' rings, 0.04 thick, were worse, and were most of what showed. Now each step widens the skin, and the rings, to its own stride across them (0.6 of how far the distance to the surface changed since the last step) and dims them to match, so they keep their light and can't be stepped over. Rims are untouched: there the line of sight runs along the skin and the stride across it is small. With the grain gone, 16 steps hold up for moon jellies where 20 were needed (step 3 tried 16 and saw grain; the cause was this). The crystal jellies keep 20: their ring's points, 0.024 thick, turned to glitter at 16. Taking the canals' angle only where the skin is, which the review also suggested, saved nothing measurable and wasn't kept. Measured in one process turn about with the old march, on a busy machine: the lit tank 0.05 to 0.09 ms less GPU, the glow and the crystal jellies the same.
- **5. Arms that trail the water, crystal jellies' bundles that fan, and eddies the group shares.**
  - *The trailing parts lie in the water going past.* The spine the arms and tentacles hang along was laid out along where the bell's axis had pointed, plus a sag, and nothing else moved them: the arms held the same inverted V through the whole re-opening. Each step now records how the water goes past the bell, back along its axis (weight 0.3) and streamed by its way through the water (1 per diameter a second), and how far it stretches them: 1.3 times their length at twice the bell's mean speed, down to 0.7 at rest (`trailing`). Each bit of an arm takes both from the moment the margin passed it, so at the stroke the arms stream out long, and as the bell slows they slacken and bunch, the change running down them; a bell skidding through a turn trails them between its axis and its way. The crystal jellies' tentacles, seven radii long, stretch 0.08 either way. `jellyfishArmsStreamAndBunch` checks the rule. A sinking jelly's arms don't visibly lift, as the review hoped: the moon jellies sink at 2 mm/s, a twentieth of their swimming.
  - *The crystal jellies' strands fanned, and were taken out again.* Where the spine carried a bundle aside, as after a turn, its strands spread apart by 0.35 of the offset, so a turn fanned the bundle rather than bending it as a tube. (The review suggested giving each strand its own share of the offset; but each pixel looks up only the strands nearest its own place on the ring, and offsets of their own would put strands where the look-up doesn't search, so they spread in order.) It read as a little less of a tube, no more, and the wider bundles and boxes cost the crystal jellies 0.2 to 0.3 ms more GPU (8 to 10%, measured turn about in one process), on a look already over its 2 ms: so it went.
  - *Eddies.* Four slow eddies join the tank's turn, 0.5 to 1.5 m across in the moon jellies' tank at up to about 2 cm/s (display tanks run 1 to 3), wandering over minutes, the same for every jelly: neighbours drift together, and more travel off their axis. Of the faster ones, 71% to 76% now travel within 30° of their axis (seeds 22, 7, 3 and 11) where 76% to 78% did without the eddies; the footage has 53%. Turned with the flow as well, as the tank's current turns them, the bells gathered toward the top (42% in the top third), so the eddies carry them without turning them. Side-on bells lie 37° to 42° from vertical (were 41°; footage 26°), and the motion test now expects under 76% along their axis. The eddies draw their places from a stream of their own, so a pinned tank (`jellyfish.seed`) keeps the animals it had.

  CPU only, in a release build: a step of 84 moon jellies takes 0.037 ms where it took 0.03, and filling the tank 20 ms where it took 16. On the GPU the arms' stretch grows the crystal jellies' boxes by about 5%.
- **6. The fringe is a veil of fine hairs, not a comb.** A moon jelly's fringe was 120 strands, all the same length and brightness: on a near bell, a picket fence of even straight spikes. It is now 320 strands, each half as thick (0.003 radii), varying in length by up to 30% and in brightness by up to 40% (`TVARY` 0.5, where the crystal jellies have 0.7), so that together they carry about the light the 120 did (0.0023 radii, the same light, was tried and read as too faint); they fuse into a veil on all but the nearest bells and read as fine hairs on those, as research-motion.md has them ("visible as fine hairs only in the dark tank"). Their sway is halved, to 0.12, so the four strands a pixel looks at either side still find them. And they leave the margin along its skirt: each hair is splayed by 0.35 of the skirt's angle (step 4's third change) a radius along it, taken at the moment the margin passed it, so the fringe splays out at rest and swings in on the stroke where it only rode along with the rim. The crystal jellies' strands are as they were. The count costs nothing, each pixel still looking at eight strands: measured turn about with the old fringe, the same GPU time within the noise.
- **7. Gonads as round tubes, and no two animals alike.** Each of the four was a ribbon standing on edge, 0.04 radii wide and 0.09 tall, at one height and the same on all 84: side-on, every bell showed two or four upright rectangles, and face-on the same thin clover sat on every animal. Each is now a round tube 0.05 radii thick riding just under the dome's underside, so it curves down with it toward the rim; thicker and thinner along its length by where it lies in the bell, so the four differ; and each animal's are sized 0.8 to 1.2 and weighted 0.5 to 1.3, young to ripe, from its seed (real ones differ with age: MarLIN). Side-on they read as soft rounded bodies, face-on as uneven horseshoes. Like the skin, the tube is widened to the march's step where a step is longer than it is thick (side-on a step runs 0.12 radii), so it isn't stepped over. The tint is unchanged: moving it toward the mauve research-look.md sampled from photos (#D0B5DC) is Dave's call. Cost, measured turn about with the old gonads: about 0.06 to 0.1 ms more GPU in the lit tank, though only a little more arithmetic, the gonads being looked for only near their height and their ring.
- **8. Depth: soft focus by distance, and overlaps that don't blow out in the dark.**
  - *Soft focus.* A 30-point bell 6.5 m off was as sharp as a 660-point one at 1.2 m. The camera now focuses 2.4 m into the moon jellies' tank (1.3 times the tank's scale, so the crystal jellies' too), and every edge is at least as soft as a lens would blur it, by how far off focus a bell is in 1/distance: about 2.5 points across on the nearest bells, 1.5 on the furthest, none at the focus. The shader reads the distance back from the fog it is already sent, so nothing more is sent a frame. Strands and arms take it as their pixel width, which widens and dims them; the skin, the tissue's edges and the gonads take it as a floor on their own widths. Near bells' fringes go to a soft haze, mid-tank bells stay crisp, far ones soften a little: "near jellies are large and a little soft (a wider line profile, not a blur pass)", as research-method.md recommended.
  - *Screened in the dark.* Added light piled overlapping bells into the brightest thing on screen: in the glow, every pixel over 200 was in one pile. On the glow's and the crystal jellies' black the jellies are now screened, as The Moon's sky is, which is the same as adding for one bell and can't pass white for many: the glow's brightest tenth of a percent comes to 147 of 255 where it was 186 (the look research's cap for broad light is 150), its brightest pixel 206 where it was 255; the crystal jellies' 145 and 198, from 162 and 255. Screened on the lit tank's bright blue, every jelly went milky, so the lit tank keeps adding, and still clips where many overlap, as a Light Mode scene bright on purpose. The switch is made as the tank's light all but goes (under 2%), where the two differ only in piles. Drawing near bells in front of far ones (`.alpha`, with the order set by depth) was the review's better step; screening answered the pile, and wasn't tried. `jellyfishScreensInTheDark` checks each look's blend.

  Both cost nothing measurable: the focus is a log and a few multiplies a pixel, and the blend is the GPU's own.
- **A battery rate, tried and not set.** With the soft focus in, 20 s of the lit tank were measured for a `batteryRate`: at 20 fps the bells' middles move 4.3 device pixels a frame at the 99th percentile and 8.3 at most, and their margins, which now flap, 3.8 and 8.3 (at 30 fps, 3.1 and 7.1, and 2.4 and 5.5). That is twice and more the 2 pixels a frame that look the same as 30 fps, so the battery keeps its 30 fps. BatteryPaced still can't help: with 84 out of step, one is always mid-stroke.
- **10. The bell solved in closed form, rather than marched,** was not attempted, on Dave's word: where the GPU lands without it is under Cost.

## Settings
- **Look** (`jellyfish.look`, a menu): lit tank in Light Mode, glow in Dark Mode (the standard); lit tank in Light Mode, crystal jellies in Dark Mode; lit tank by day, glow at night; lit tank by day, crystal jellies at night; lit tank; glow; crystal jellies. Each pick says what it does, rather than a second menu for the dark look that would show for only four of the seven picks, which a knob can't express. By day means the Sun where you are: the tank's light eases through civil twilight, from 6° below the horizon to 1° above.
- **Jellyfish** (`jellyfish.count`, 0.5 to 1.5×): 84 moon jellies or 48 crystal jellies at 1×, Dave's pick from trying the slider (1.5× of step 3's 56 and 32, which were twice the first 28 and 16). A change refills the tank.
- **Speed** (`jellyfish.speed`, 0.5 to 1.5×): the scene's clock, so pulses, turns and drift keep their proportions. 1× is 0.8 of the real pace (`Jellyfish.pace`), Dave's pick from trying it, so the slider runs from 0.4 to 1.2 of the real pace. (His pick was made with a stroke every 1.6 s; step 4 made it every 2.5 s, so the pace is his to try again.)

## Cost
Measured by the render test at 2x Retina on an M3 Max, debug build (release CPU is lower), with the seed pinned:

| Look | CPU | GPU |
|---|---|---|
| Lit tank, 84 moon jellies | 4.9–5.1 ms | 3.9–4.2 ms |
| Crystal jellies, 48 | 2.5 ms | 2.6–3.9 ms |

At 4 and 8 s in, with Atrium quit: a copy on the desktop shares the GPU and more than doubled the readings. That is about twice the 2 ms of GPU a wallpaper aims for, the price of three times as many as at first: 28 moon jellies drew in 1.56 ms and 56 in 2.9. In a release build 56 moon jellies took 0.7 to 0.95 ms of CPU; 84 weren't measured there until step 4: 0.64 to 0.74 ms, and 0.54 to 0.61 for 48 crystal jellies, so the CPU column above is a debug build's and the wallpaper's CPU is inside its 2 ms.

That table is step 3's. After step 4 (2026-11-15), the render test drew each look with the code from before it and the code after, turn about, four times each on a machine shared with four other sessions; the quietest of each:

| Look | GPU before | GPU after | CPU, release, before | after |
|---|---|---|---|---|
| Lit tank, 84 moon jellies | 2.05 ms | 1.30 ms | 0.77–0.83 ms | 0.73–0.75 ms |
| Glow | 2.07 ms | 1.10 ms | | |
| Crystal jellies, 48 | 3.16 ms | 2.36 ms | 0.70 ms | 0.82 ms (one run) |

So the moon jellies now draw inside the 2 ms of GPU, the saving of step 4's first change paying for the flap, the gonads and the rest; the crystal jellies are still over, their cost being tentacles seven radii long, which the bell's closed form (the review's tenth, not attempted) wouldn't shorten. The frames before and after aren't of the same moment of the same tank, since the motion changed; the sprites' boxes, a fair measure of what is drawn, cover 0.78 of the screen before step 4 and 0.48 after for the lit tank, 1.91 and 2.33 for the crystal jellies (their tentacles now bend with the eddies and the water).

No `batteryRate`: tried in step 4 and not set (above).

## Checking it
```sh
SNAPSHOT_SCENE="Jellyfish" SNAPSHOT_APPEARANCE=light SNAPSHOT_DEFAULTS="jellyfish.seed=22" swift test --filter everySceneRenders   # the lit tank
SNAPSHOT_SCENE="Jellyfish" SNAPSHOT_APPEARANCE=dark SNAPSHOT_DEFAULTS="jellyfish.seed=22" swift test --filter everySceneRenders    # the glow
SNAPSHOT_SCENE="Jellyfish" SNAPSHOT_DEFAULTS="jellyfish.seed=21,jellyfish.look=6" swift test --filter everySceneRenders          # crystal jellies
swift test --filter jellyfishMove                    # speed and spread measured as the footage was; JELLY_SEED and JELLY_LOOK pick another
swift test --filter jellyfishBox                     # each sprite's box holds everything its shader draws
swift test --filter jellyfish                        # those two, and the glide between strokes, the arms' trailing and each look's blend
```
`jellyfish.seed` (any whole number but 0) pins the tank's layout and every pulse and turn, for pictures that can be taken again; unset, each load is new. The Settings pictures are `preview-jellyfish.jpg` (the glow, Dark Mode's standard) and `preview-jellyfish-light.jpg` (the lit tank), from the first two commands. The mock and its statistics, which measure poses, turns, spacing and cover as research-motion.md measured footage, stay in `docs/jellyfish/` (`JSTATS=1` on `mock.swift`).

The README's pictures and the site's (2026-11-09) are the first three commands at `SNAPSHOT_SECONDS=5` with `swift test -c release -Xswiftc -enable-testing`: `jellyfish.jpg` the lit tank (the hero, cut to the card and `preview-jellyfish-light.jpg`), `jellyfish-glow.jpg` (cut to `preview-jellyfish.jpg`) and `jellyfish-crystal.jpg`; and `jellyfish-crowd.jpg`, the lit tank with `jellyfish.count=1.5` added. The 12 s loop, the card and the menu tile are `site/media.sh preview-jellyfish card-jellyfish`, from 5 s into the lit tank.

## Shortcuts
- The sway and the marine snow jump once an hour where the shader's clock wraps.
- Every pair of jellies is checked for touching every step; fine at 84 at most.

## Dave's feedback
- **2026-11-07, on round 1:** "the single jellifish is very underwhelming, we need to focus on groups that are moving"; "sheet-1 is the best, and within that items D, E, and F are what we should focus in on"; "we need to really focus on natural movement, do more research if needed, its not quite there yet". So round 2 is groups in motion only, in three lights: crystal jellies under blue light with their green rings (D), moon jellies in the lit blue tank (E), and the steady blue glow (F), which no real jelly makes and the sheet said so. The deep species, the single close-up and the other sheets' questions are set aside. Motion gets its own research, measured from footage of real groups.

- **2026-11-08, on step 1 on his desktop:** "the overall movement of the jellyfish still doesnt seem very natural, they seem to not move very much at all as they pulse, please review video footage of dense jellyfish population and attempt to recreate that". So step 2: twice the travel per pulse, the group's loop round the tank, and the sides turning bells away.
- **2026-11-08, on step 2's film beside step 1's:** "the new motion is much better".
- **2026-11-08, on step 2 on his desktop:** "it looks much better, i just think that by default there should be a lot more of them, at least 2x more". So step 3.
- **2026-11-08, on step 3, after trying the sliders:** "1.5x population and 0.8x speed is my ideal sweet spot in testing". So 84 moon jellies and 48 crystal jellies became 1× of Jellyfish, and Speed's standard 0.8×, with 1× kept as the real pace.
- **2026-11-09, on that:** "about 1.5x population and 0.8x speed being the ideal default, we should rebalance all sliders from there and call that 1.0 1.0 for the values". So Speed's 1× is now 0.8 of the real pace, with 0.5 to 1.5× round it, as Jellyfish already was.

- **2026-11-14, on step 3 on his desktop:** "They dont seem to move far at all given how much they pulse, if they pulse a lot they should move more or just pulse less and move less, or be more of a sea of less movement but its just not compelling". So step 4's second change: fewer strokes, each carried further, with the way kept between them. The count stays at 84: his pick.

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
- Side-on bells lie further from vertical than the footage's (41° against 26°); a stronger pull round the loop didn't change it. (Twice as many faced the camera as in the footage until step 4 eased their axes toward the glass.)
- More jellies travel along their axis than the footage's: 71% to 76% of the faster ones against 53%, since step 4's eddies (76% to 78% before).
- The comb jelly is the weakest drawing: its rows read as dots at a distance.
- The moon jelly's gonads are lit in the tank's pale blue; photos show them mauve (#D0B5DC: research-look.md). Dave's call, the colours staying in one family.
- Whether "bioluminescent" in the brief means C (true and mostly black) or F (made up and lovely).

## Sources
The two research reports, [research-method.md](jellyfish/research-method.md) and [research-look.md](jellyfish/research-look.md), carry every source and its licence.
