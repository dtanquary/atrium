"""A strip of frames through the next cutoff on screen, at the wallpaper's own pace (25 s a T, 15 frames a second),
in both looks, and how much of the picture changes on the cutoff frame.
  python3 strip2.py state.pkl outdir"""
import sys, os, copy, pickle, numpy as np, render
from PIL import Image, ImageDraw
state, out = sys.argv[1], sys.argv[2]; os.makedirs(out, exist_ok=True)
PACE, FPS, half = 25.0, 15, 7.0
base = pickle.load(open(state, "rb")); base.eps = 1 / PACE / FPS; base.cap = 1.25 * base.eps
r = copy.deepcopy(base); n0 = r.ncut; CUT = 0   # first pass: when and where
while True:
    r.step(stamp_every=1, cut_every=1); CUT += 1
    if r.ncut > n0:
        _, cx, cy, size = r.cutlog[-1]; cx = (cx + r.pad) % r.L - r.pad
        if CUT > 3 * FPS + 2 and 8 < cx < r.sx - 8 and 8 < cy < r.sy - 8 and size * r.ds > 8: break
        n0 = r.ncut
print(f"cutoff {CUT} frames on ({CUT / FPS:.0f} s) at ({cx:.1f}, {cy:.1f}) W, a loop of about {size * r.ds:.0f} W")
r = copy.deepcopy(base)
x0, y0 = max(int((cx - half) * r.tex), 0), max(int((cy - half) * r.tex), 0)
crop = (y0, min(y0 + int(2 * half * r.tex), r.th), x0, min(x0 + int(2 * half * r.tex), r.tw))
marks = [(-3 * FPS, "3 s before"), (-1, "the frame before"), (0, "the cutoff frame"), (1, ""), (2 * FPS, "2 s after"), (10 * FPS, "10 s"),
         (30 * FPS, "30 s"), (60 * FPS, "1 min"), (120 * FPS, "2 min"), (300 * FPS, "5 min"), (600 * FPS, "10 min")]
tiles = {"relief": [], "fisk": []}; frame = 0; last = {}
for at, label in marks:
    while frame < CUT + at:
        if frame >= CUT + 30 * FPS and r.eps < 0.004: r.eps = 0.004; r.cap = 1.25 * r.eps   # coarser steps once nothing is quick
        step = int(round(r.eps * PACE * FPS)) if r.eps > 1 / PACE / FPS else 1
        r.step(stamp_every=1, cut_every=1); frame += step
    for look, fn in (("relief", render.relief), ("fisk", render.fisk)):
        im = Image.fromarray((fn(r, f=2, crop=crop) * 255).astype(np.uint8))
        raw = np.asarray(im).astype(np.float32)
        if at in (-1, 0, 1):
            if at != -1:
                d = np.abs(raw - last[look]).max(axis=-1)
                print(f"{look}: {'the cutoff frame' if at == 0 else 'the frame after'}: {100 * (d > 20).mean():.3f}% of the window changes by more than 20 levels, mean {d.mean():.3f}, max {d.max():.0f}")
            last[look] = raw
        if at == 1: continue
        ImageDraw.Draw(im).text((8, 6), label, fill=(255, 255, 255), stroke_width=2, stroke_fill=(0, 0, 0))
        tiles[look].append(im)
for look, ts in tiles.items():
    w, h = ts[0].size; s = Image.new("RGB", (w * 5, h * 2))
    for i, t in enumerate(ts): s.paste(t, ((i % 5) * w, (i // 5) * h))
    s.save(f"{out}/cutoff-{look}.png"); print(f"{out}/cutoff-{look}.png", s.size)
