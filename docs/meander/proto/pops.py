"""Does a cutoff pop? Steps the river at the wallpaper's own pace (one frame of a 15 fps display per step), finds
the next cutoff on screen, and measures how much the picture changes from each frame to the next around it.
  python3 pops.py state.pkl outdir [pace: seconds of wallpaper per T, default 75]"""
import sys, os, copy, pickle, numpy as np
from PIL import Image
import render
state, out = sys.argv[1], sys.argv[2]; pace = float(sys.argv[3]) if len(sys.argv) > 3 else 75.0
os.makedirs(out, exist_ok=True)
base = pickle.load(open(state, "rb"))
FPS = 15
def fine(r):
    r.eps = 1 / pace / FPS; r.cap = 1.25 * r.eps; return r
# pass 1: when and where is the next cutoff on screen?
r = fine(copy.deepcopy(base)); n0 = r.ncut; k = 0
while True:
    r.step(stamp_every=1, cut_every=1); k += 1
    if r.ncut > n0:
        t, cx, cy, size = r.cutlog[-1]
        cx = (cx + r.pad) % r.L - r.pad
        if 6 < cx < r.sx - 6 and 6 < cy < r.sy - 6 and size * r.ds > 8: break
        n0 = r.ncut
print(f"cutoff after {k} frames ({k / FPS:.0f} s of wallpaper) at ({cx:.1f}, {cy:.1f}) W, loop {size * r.ds:.0f} W long")
# pass 2: the same run again, drawing a window round the cutoff
half = 7.0  # widths
x0, y0 = int((cx - half) * base.tex), int((cy - half) * base.tex); x0, y0 = max(x0, 0), max(y0, 0)
crop = (y0, min(y0 + int(2 * half * base.tex), base.th), x0, min(x0 + int(2 * half * base.tex), base.tw))
r = fine(copy.deepcopy(base)); before, after = 3 * FPS, 20 * FPS
for _ in range(k - before): r.step(stamp_every=1, cut_every=1)
rows = []; prev = {}; keep = {}
stills = {-before + 1: "3 s before", 0: "the cutoff frame", 1: "one frame after", 2 * FPS: "2 s after", 10 * FPS: "10 s", 20 * FPS: "20 s"}
for j in range(-before + 1, after + 1):
    r.step(stamp_every=1, cut_every=1)
    for look, fn in (("relief", render.relief), ("fisk", render.fisk)):
        img = (fn(r, f=2, crop=crop) * 255).astype(np.float32)
        if look in prev:
            d = np.abs(img - prev[look]).max(axis=-1)
            rows.append((j, look, float(d.mean()), float(np.percentile(d, 99.9)), float(d.max()), float((d > 20).mean())))
        prev[look] = img
        if j in stills: keep[(look, j)] = img
# later frames, to show the lake forming: 1, 2, 5 and 10 minutes after
for label, secs in (("1 min", 60), ("2 min", 120), ("5 min", 300), ("10 min", 600)):
    target = secs * FPS
    r.eps = 0.004; r.cap = 1.25 * r.eps  # coarser steps for the long wait
    while (r.t - t) * pace * FPS < target: r.step(stamp_every=1, cut_every=1)
    for look, fn in (("relief", render.relief), ("fisk", render.fisk)): keep[(look, label)] = (fn(r, f=2, crop=crop) * 255).astype(np.float32)
    stills[label] = label
for look in ("relief", "fisk"):
    tiles = [Image.fromarray(keep[(look, key)].astype(np.uint8)) for key in stills]
    w, h = tiles[0].size; sheet = Image.new("RGB", (w * 5, h * 2))
    for i, tl in enumerate(tiles): sheet.paste(tl, ((i % 5) * w, (i // 5) * h))
    sheet.save(f"{out}/cutoff-{look}.png")
print("order of tiles:", list(stills.values()))
for look in ("relief", "fisk"):
    rr = [x for x in rows if x[1] == look]
    typical = [x for x in rr if x[0] < -5]
    at = [x for x in rr if x[0] in (0, 1)]
    print(look, "typical frame-to-frame: mean %.3f levels, 99.9th pct %.1f, max %.0f, share over 20 levels %.5f" % tuple(np.mean([x[2:] for x in typical], axis=0)))
    for x in at: print(look, "frame %d: mean %.3f, 99.9th pct %.1f, max %.0f, share over 20 levels %.5f" % (x[0], *x[2:]))
    worst = max(rr, key=lambda x: x[4]); print(look, "worst frame in the window: frame %d, max %.0f, 99.9th %.1f" % (worst[0], worst[4], worst[3]))
    tail = [x for x in rr if 2 <= x[0] <= 5 * FPS]
    print(look, "the 5 s after: mean %.3f, 99.9th pct %.1f, max %.0f, share over 20 levels %.5f" % tuple(np.mean([x[2:] for x in tail], axis=0)))
