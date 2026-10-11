"""The frame on which the river re-crosses a lake (a lake at least 2 T old loses nodes to the live channel): how much
of a 14 W window round it changes, in relief and the old map both ways. 25 s a T, 15 frames a second.
  python3 recross4.py state.pkl outdir"""
import sys, os, copy, pickle, numpy as np, render
from PIL import Image
state, out = sys.argv[1], sys.argv[2]; os.makedirs(out, exist_ok=True)
PACE, FPS, half = 25.0, 15, 7.0
LOOKS = {"relief": lambda r, pre: render.relief(r, pre=pre), "fisk": lambda r, pre: render.fisk(r, rule="fixed", pre=pre),
         "fisk-order": lambda r, pre: render.fisk(r, rule="order", pre=pre)}
base = pickle.load(open(state, "rb")); base.eps = 1 / PACE / FPS
r = copy.deepcopy(base); AT = 0; found = []
while len(found) < 3 and AT < 20000:
    cuts, seen = r.ncut, len(r.trims)
    r.step(stamp_every=1, cut_every=1); AT += 1
    new = [t for t in r.trims[seen:] if t[3] > 2.0 and 8 < t[1] < r.sx - 8 and 8 < t[2] < r.sy - 8]
    if new and r.ncut == cuts and (not found or AT - found[-1][0] > 30): found.append((AT, new[0][1], new[0][2], new[0][3], len(r.trims) - seen))
print("re-crossings found:", [(a, round(x, 1), round(y, 1), round(age, 1), n) for a, x, y, age, n in found])
r = copy.deepcopy(base); frame = 0
for n, (AT, cx, cy, age, count) in enumerate(found):
    x0, y0 = max(int((cx - half) * r.tex), 0), max(int((cy - half) * r.tex), 0)
    crop = (y0, min(y0 + int(2 * half * r.tex), r.th), x0, min(x0 + int(2 * half * r.tex), r.tw))
    while frame < AT - 2: r.step(stamp_every=1, cut_every=1); frame += 1
    last = {}
    for at in (-1, 0, 1):
        r.step(stamp_every=1, cut_every=1); frame += 1
        pre = render.reads(r, 2, crop)
        for look, fn in LOOKS.items():
            raw = (fn(r, pre) * 255).astype(np.float32)
            if look in last:
                d = np.abs(raw - last[look]).max(axis=-1)
                print(f"re-crossing {n + 1} (lake {age:.1f} T old, {count} trims), {look}, {'the frame it happens' if at == 0 else 'the frame after'}: {100 * (d > 20).mean():.3f}% over 20 levels, mean {d.mean():.3f}, max {d.max():.0f}")
                if at == 0: Image.fromarray(np.concatenate([last[look], raw, np.repeat(np.clip(d * 4, 0, 255)[..., None], 3, -1)], 1).astype(np.uint8)).save(f"{out}/recross-{n + 1}-{look}.png")
            last[look] = raw
