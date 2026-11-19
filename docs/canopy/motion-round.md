# Canopy: the motion, round 1 of films (2026-11-18)

Step (b2)'s films, for Dave to choose from after his word on (b)'s sway ("its obvious just the wavy effect being applied to an image"), each measured as research-motion.md measured the footage. **Built:** motion 0 (step (b)'s sway, kept to compare), Model 1 (the wood still, the twigs and leaves rustling by how free they are) and Model 2 (as 1, with the nearest leaves a picture of their own moving over the rest), behind `canopy.motion`; **Model 2 is the default.** How each is made is in `docs/canopy.md`, step (b2).

**Chosen:** Model 2 (Dave, 2026-11-18: "go with model 2", then "lets lock in model 2"). The switch, motion 0 and Model 1 are cut since; 532f0e8 is the last commit that redoes their films.

## The films
12 s each, seed 3 at 42°N 88°W, 15 July 3:30 pm (in leaf) and 17 November 1 pm (bare), at a breeze (`canopy.wind` 4.3 m/s, Beaufort 3) unless named; H.264 at half size (1512 × 982).

| | July | November |
|---|---|---|
| Now (motion 0) | [film-motion-0-july.mp4](film-motion-0-july.mp4) | [film-motion-0-november.mp4](film-motion-0-november.mp4) |
| Model 1 | [film-motion-1-july.mp4](film-motion-1-july.mp4) | [film-motion-1-november.mp4](film-motion-1-november.mp4) |
| **Model 2** | [film-motion-2-july.mp4](film-motion-2-july.mp4) | [film-motion-2-november.mp4](film-motion-2-november.mp4) |
| Model 2, light air (2 m/s, the floor Dave asked for) | [film-motion-2-july-light.mp4](film-motion-2-july-light.mp4) | |
| Model 2, strong wind (12 m/s, Beaufort 6) | [film-motion-2-july-strong.mp4](film-motion-2-july-strong.mp4) | |
| Side by side, now, Model 1, Model 2: the same 640 × 540 px of the lower crowns at full scale (px at 2x), so the motion can be seen | [film-motion-compare-july.mp4](film-motion-compare-july.mp4) | [film-motion-compare-november.mp4](film-motion-compare-november.mp4) |

## Measured
By `flow.py` (research-motion.md §2, unchanged; kept here as `docs/canopy/flow.py`): 15 fps frames at 1512 wide, phase correlation of 64 px blocks at 2x, the camera's fit taken out as the footage's was ("all"), and the wood's speed and correlation also as drawn ("none"), since Canopy has no camera. Wood is "trunks and solid masses" by the script's classes (over 40 px thick, or dark masses; here mostly the evergreens and the trunks), twigs under 12 px, leaves the foliage edge – mass. Wood correlation is its blocks' with their neighbours as drawn; "still" where they don't move at all (no correlation to take), and in brackets with the camera's fit out, which then only measures the fit (a similarity fitted to the moving leaves, taken off still wood, is the same at every block).

| Film | Speed median / 95th (px/s) | Wood / twigs / leaves, median (px/s) | Wood correlation | Drift 1 s / 4 s (RMS px) | Lost at 1 s / 4 s | Correlation at ~100 px; to 0.1 | Displacement <0.5 / 0.5–2 / >2 Hz | Gap open / closed (s) |
|---|---|---|---|---|---|---|---|---|
| **Real**, steady clips, light air to breeze (research-motion.md) | 0.5–10 / 4–50 | near still / 1.5–2× the thick | 0.08–0.19 | 1.3–11 / 1.6–15 | 4–79 / 10–94% | 0.03–0.77 (median 0.33); 250–1000 px | 69–99 / 1–31 / 0–5% | 0.25–0.8 / 0.17–0.9 |
| Now (motion 0), July | 3.2 / 20.8 | 3.2 / 5.9 / 4.4 – 3.0 | 0.83 (0.72) | 7.3 / 6.4 | 10 / 6% | 0.66; 447 px | 97 / 3 / 0% | 0.53 / 0.80 |
| Now, November | 2.8 / 18.2 | 3.5 / 2.8 / – | 0.81 (0.69) | 7.0 / 5.6 | 7 / 5% | 0.63; 447 px | 97 / 3 / 0% | 1.07 / 0.60 |
| Model 1, July | 1.2 / 12.5 | 0.0 / 4.1 / 4.2 – 1.3 | still (1.00) | 3.8 / 6.1 | 1 / 14% | 0.58; 639 px | 81 / 19 / 0% | 0.47 / 0.53 |
| Model 1, November | 0.3 / 7.6 | 0.0 / 1.6 / – | still (0.99) | 2.7 / 3.9 | 1 / 11% | 0.62; >1300 px | 81 / 19 / 0% | 0.67 / 0.40 |
| **Model 2**, July | 3.3 / 25.6 | 0.0 / 5.8 / 5.8 – 3.6 | still (0.55) | 5.1 / 7.0 | 34 / 61% | 0.43; 223 px | 82 / 17 / 0% | 0.33 / 0.40 |
| **Model 2**, November | 0.3 / 7.2 | 0.0 / 1.6 / – | still (0.99) | 2.5 / 3.9 | 1 / 12% | 0.61; 1279 px | 82 / 18 / 0% | 0.60 / 0.40 |
| Model 2, July, light air (2 m/s, the floor) | 1.6 / 7.1 | 0.0 / 2.5 / 2.6 – 1.7 | still (0.62) | 3.4 / 5.3 | 14 / 34% | 0.46; 223 px | 82 / 18 / 0% | 0.47 / 0.53 |
| Model 2, July, strong wind (12 m/s) | 8.6 / 46.5 | 2.0 / 21.4 / 21.2 – 9.6 | 0.69 (0.61) | 7.2 / 7.3 | 60 / 80% | 0.50; 447 px | 84 / 15 / 0% | 0.27 / 0.33 |

**Against the report's targets** (research-motion.md, Ranking):
- **The wood's correlation below 0.2:** met by Models 1 and 2, more than met: the wood doesn't move at all as drawn (0.0 px/s at the median, so no correlation to take), where now it moves with everything (3.2–3.5 px/s) and most coherently of all (0.81–0.83). Only in the strong wind does it move (2 px/s: the limbs freed and the crowns swaying), at 0.69.
- **The texture lost after 1 s, 15–60% in a breeze (Model 2):** met by Model 2: 34% in July at the breeze (61% after 4 s), 14% in light air, 60% in the strong wind (the windy footage: 66%); now 7–10%, Model 1 1%. Bare (November) there are no near leaves to cross, so 1% as for Model 1, as the real bare limb in still air (4%).
- **10–20% of the displacement in 0.5–2 Hz:** met by Models 1 and 2 everywhere, 15–19% (now 3%), with nothing above 2 Hz but the light's flicker.

**Besides:**
- **Amounts:** Model 2's breeze in July comes to a median 3.3 px/s (95th 25.6) and drifts 5.1 px in a second, the real breeze's 2–5 px/s and inside its 1.3–11 px; the strong wind's 8.6 / 46.5 px/s and 7.2 px are the windy footage's 10.4 / 42 and 11.3; the floor (2 m/s) keeps 1.6 px/s at the median, Dave's 1.5–2. Bare, the twigs move a median 1.6 px/s, the wood none, so the whole picture's median is 0.3: the bare stand is mostly wood.
- **No swinging back:** drift keeps growing from 1 s to 4 s in Models 1 and 2 (Model 2, July: 5.1, 6.2 at 2 s, 7.0 at 4 s), where now's falls (9.1 at 2 s, 6.4 at 4 s), as the real canopies' do. The share within ±20% of the peak frequency stays 0.45–0.49 for every film, now's included: in 12 s the measure can't resolve below its 0.17 Hz bin, where most of a broadband motion lies, so it doesn't tell a pendulum from this.
- **Patches:** two points 100 px apart move alike at 0.43–0.46 in Model 2 in leaf (now 0.66, real median 0.33), apart by 223 px (real 250–1000). Model 1 holds together further (0.58, 639 px): one picture over a smooth field, where Model 2's near leaves move on their own. Bare, the correlation (0.61–0.62, past 1,279 px) is the camera's fit over still wood, as the wood's own (0.99 with the fit, none as drawn) shows.
- **Gaps** open 0.33 s and close 0.40 s at the median in Model 2's July (real 0.25–0.8 and 0.17–0.9; now 0.53 and 0.80, swept by the sway); 0.27 / 0.33 in the strong wind.
- **Gusts:** the 1-s mean speed varies by 0.09–0.25 (real 0.11–0.36), p90 over p10 1.3–2.1 (real 1.3–3.1): the breeze's swell and gusts, with the floor taking off the deepest lulls.
- **Seen** (contact strips at full scale and the change over 1 s, frame by frame, and maps of where each film changes): in Models 1 and 2 the evergreens' masses and the trunks are black in every map of change, the twigs and the leaves' edges lit everywhere, each patch on its own; the leaves' sprays stay whole and no edge smears, ripples or tears. Now's maps light up the whole picture, the solid wood included, its twigs streaked the same way at once. In November a thin limb (about 6 px across) moves along its length as a whole; limbs from 8 px across are held still (before, from 12 px, those between moved too, on a field that can bend them).

## How to redo it
1. A film's frames (`docs/canopy.md`, Checking it): `SNAPSHOT_MOVIE=12`, `SNAPSHOT_SECONDS=4`, `SNAPSHOT_DEFAULTS` with `canopy.seed=3`, the date and hour, `latitude=42,longitude=-88`, `canopy.motion` and `canopy.wind`.
2. The frames to the script's input, gray at 1512 wide and colour at 756:
   ```python
   import glob, numpy as np; from PIL import Image
   files = sorted(glob.glob('/some/dir/Canopy-[0-9]*.png'))
   ims = [Image.open(f).convert('RGB') for f in files]
   np.savez('film.npz', gray=np.stack([np.asarray(i.convert('L').reduce(2)) for i in ims]), rgb=np.stack([np.asarray(i.reduce(4)) for i in ims]), fps=15.0)
   ```
3. `python3 -I docs/canopy/flow.py film.npz 90 film-all.json all` (and `none` for as drawn): the JSON holds every measure above (`speed`, `displacement_vs_lag`, `neighbour_corr`, `coherence`, `spectrum`, `gaps`, `gusts`), each 2–4 minutes on an M3 Max.
