"""Round 4's pictures, with out2's names; the old map both ways ("-order" is Fisk's order with long stages and the whole
sheet sliding each stage; without it, colours are fixed to the land).  python3 stills4.py v4-seed11 out4 10000"""
import sys, os, pickle, numpy as np, render
from PIL import Image, ImageDraw
src, out, pick = sys.argv[1], sys.argv[2], int(sys.argv[3])
load = lambda n: pickle.load(open(f"{src}/state-{n:06d}.pkl", "rb"))
img = lambda a: Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8))
slug = lambda s: s.lower().replace(" ", "-")
r = load(pick); pre = render.reads(r, 2)
for pal in render.RELIEF: img(render.relief(r, palette=pal, pre=pre)).save(f"{out}/still-relief-{slug(pal)}.png")
for pal in ("Fisk 1944", "Sage", "Fisk 1944 Dark", "Salmon", "Sage Dark"):
    img(render.fisk(r, palette=pal, rule="fixed", pre=pre)).save(f"{out}/still-fisk-{slug(pal)}.png")
    if pal in ("Fisk 1944", "Sage", "Fisk 1944 Dark"): img(render.fisk(r, palette=pal, rule="order", pre=pre)).save(f"{out}/still-fisk-order-{slug(pal)}.png")
crop = (150, 325, 300, 550)  # a 500 x 350 pt piece, at four pixels a texel: 2x Retina
pre = render.reads(r, 4, crop)
img(render.relief(r, f=4, crop=crop, pre=pre)).save(f"{out}/retina-relief.png")
img(render.fisk(r, f=4, crop=crop, rule="fixed", pre=pre)).save(f"{out}/retina-fisk.png")
img(render.fisk(r, f=4, crop=crop, rule="order", pre=pre)).save(f"{out}/retina-fisk-order.png")
mins = [n for n in (8000 + k * 60 for k in range(6)) if os.path.exists(f"{src}/state-{n:06d}.pkl")]
if len(mins) == 6:
    for look, fn in (("relief", lambda r, p: render.relief(r, f=1, pre=p)), ("fisk", lambda r, p: render.fisk(r, f=1, rule="fixed", pre=p))):
        tiles = []
        for n in mins:
            q = load(n); tiles.append(img(fn(q, render.reads(q, 1))))
        w, h = tiles[0].size; s = Image.new("RGB", (w * 3, h * 2))
        for i, t in enumerate(tiles):
            s.paste(t, ((i % 3) * w, (i // 3) * h)); ImageDraw.Draw(s).text(((i % 3) * w + 8, (i // 3) * h + 6), f"+{i * 2.4:.1f} T  (+{i} min at 25 s a T)", fill=(255, 255, 255), stroke_width=2, stroke_fill=(0, 0, 0))
        s.save(f"{out}/strip-minutes-{look}.png")
print("done", pick, len(mins))
