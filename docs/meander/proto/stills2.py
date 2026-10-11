"""The second round's pictures, to Dave's picks and meander-look's measured targets. python3 stills2.py v2-seed11 out2 7500"""
import sys, os, pickle, numpy as np, render
from PIL import Image, ImageDraw
src, out, pick = sys.argv[1], sys.argv[2], int(sys.argv[3])
load = lambda n: pickle.load(open(f"{src}/state-{n:06d}.pkl", "rb"))
img = lambda a: Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8))
slug = lambda s: s.lower().replace(" ", "-")
r = load(pick)
for pal in render.RELIEF: img(render.relief(r, palette=pal)).save(f"{out}/still-relief-{slug(pal)}.png")
for pal in render.FISK: img(render.fisk(r, palette=pal)).save(f"{out}/still-fisk-{slug(pal)}.png")
crop = (150, 325, 300, 550)  # a 500 x 350 pt piece, at four pixels a texel: 2x Retina
img(render.relief(r, f=4, crop=crop)).save(f"{out}/retina-relief.png"); img(render.fisk(r, f=4, crop=crop)).save(f"{out}/retina-fisk.png")
first = load(1500)  # what a T 60 history at launch leaves: the first frame
img(render.relief(first)).save(f"{out}/first-frame-relief.png"); img(render.fisk(first)).save(f"{out}/first-frame-fisk.png")
mins = [n for n in (8000 + k * 60 for k in range(6)) if os.path.exists(f"{src}/state-{n:06d}.pkl")]
if len(mins) == 6:
    for look, fn in (("relief", render.relief), ("fisk", render.fisk)):
        tiles = [img(fn(load(n), f=1)) for n in mins]
        w, h = tiles[0].size; s = Image.new("RGB", (w * 3, h * 2))
        for i, t in enumerate(tiles):
            s.paste(t, ((i % 3) * w, (i // 3) * h)); ImageDraw.Draw(s).text(((i % 3) * w + 8, (i // 3) * h + 6), f"+{i * 2.4:.1f} T  (+{i} min at 25 s a T)", fill=(255, 255, 255), stroke_width=2, stroke_fill=(0, 0, 0))
        s.save(f"{out}/strip-minutes-{look}.png")
print("done", pick, len(mins))
