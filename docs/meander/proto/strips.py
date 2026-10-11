"""Draws the long run's saved states: stills in each look and palette, a strip a minute or so apart, and a strip
hours apart. python3 strips.py long-seed11 out"""
import sys, glob, pickle, numpy as np, render
from PIL import Image, ImageDraw
src, out = sys.argv[1], sys.argv[2]
load = lambda n: pickle.load(open(f"{src}/state-{n:06d}.pkl", "rb"))
img = lambda a: Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8))
def sheet(tiles, cols, path, labels=None):
    w, h = tiles[0].size; s = Image.new("RGB", (w * cols, h * ((len(tiles) + cols - 1) // cols)))
    for i, t in enumerate(tiles):
        s.paste(t, ((i % cols) * w, (i // cols) * h))
        if labels: ImageDraw.Draw(s).text(((i % cols) * w + 8, (i // cols) * h + 6), labels[i], fill=(255, 255, 255), stroke_width=2, stroke_fill=(0, 0, 0))
    s.save(path); print(path, s.size)
# stills: full size (1512 x 982, one pixel a point), at T 2400
r = load(60000)
for pal in render.RELIEF: img(render.relief(r, palette=pal)).save(f"{out}/still-relief-{pal.lower()}.png")
for pal in render.FISK: img(render.fisk(r, palette=pal)).save(f"{out}/still-fisk-{pal.lower()}.png")
# at 2x Retina: a 500 x 350 pt piece, four pixels a texel
crop = (120, 295, 250, 500)
img(render.relief(r, f=4, crop=crop)).save(f"{out}/retina-relief.png"); img(render.fisk(r, f=4, crop=crop, palette="Jade")).save(f"{out}/retina-fisk-jade.png")
# a strip through time: 2.4 T apart, which is a minute at 25 s a T, or three minutes at 75 s a T
mins = [6000 + k * 60 for k in range(6)]
for look, fn, pal in (("relief", render.relief, "Glacier"), ("fisk", render.fisk, "Survey")):
    sheet([img(fn(load(n), f=1, palette=pal)) for n in mins], 3, f"{out}/strip-minutes-{look}.png", [f"T {n * 0.04:.1f}  (+{k * 2.4:.1f} T)" for k, n in enumerate(mins)])
# and hours apart: every 400 T, which is 2 h 47 min at 25 s a T, or 8 h 20 min at 75 s a T
hours = list(range(10000, 90001, 10000))
for look, fn, pal in (("relief", render.relief, "Glacier"), ("fisk", render.fisk, "Jade")):
    sheet([img(fn(load(n), f=1, palette=pal)) for n in hours], 3, f"{out}/strip-hours-{look}.png", [f"T {n * 0.04:.0f}" for n in hours])
