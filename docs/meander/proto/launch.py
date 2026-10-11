"""What the first frame would look like after the history made at launch: a start, T of coarse steps, the fields
brought up to date every 8th step (what the Swift sketch timed). python3 launch.py"""
import numpy as np, render
from PIL import Image
from meander import River
tiles = []
for label, kw, T in (("straight start, T 30", dict(start="noise"), 30), ("straight start, T 60", dict(start="noise"), 60),
                     ("ready-made bends, T 15", dict(start="sine"), 15), ("ready-made bends, T 30", dict(start="sine"), 30)):
    r = River(seed=21, **kw)
    for _ in range(int(T / r.eps)): r.step(stamp_every=8, cut_every=1)
    print(label, r.stats(), "lakes", len(r.lakes))
    for fn in (render.relief, render.fisk):
        tiles.append(Image.fromarray((fn(r, f=1) * 255).astype(np.uint8)))
w, h = tiles[0].size; sheet = Image.new("RGB", (w * 2, h * 4))
for i, t in enumerate(tiles): sheet.paste(t, ((i % 2) * w, (i // 2) * h))
sheet.save("launch-history.png"); print(sheet.size)
