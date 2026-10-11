"""The long run: three days of wallpaper time (T 3600 at the default pace of 75 s a T), logging the river's
vital signs every 1000 steps and saving states to draw strips from.
  python3 long.py outdir seed steps"""
import sys, os, time, pickle, json, numpy as np
from meander import River
import render
out, seed, steps = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
os.makedirs(out, exist_ok=True)
r = River(seed=seed); t0 = time.time(); log = []
minutes = {1500} | {8000 + k * 60 for k in range(6)}  # the first frame after a T 60 launch history; then 2.4 T apart
hours = set(range(2500, steps + 1, 2500))          # 100 T apart
for n in range(1, steps + 1):
    r.step()
    if n % 1000 == 0:
        st = r.stats(); st["step"] = n; st["crossings"] = r.crossings(); st["lakes"] = len(r.lakes)
        st["history"] = round(float((r.stamp > r.t - render.AMAX).mean()), 3)
        st["finite"] = bool(np.isfinite(r.x).all() and np.isfinite(r.y).all())
        log.append(st); print(st, flush=True)
    if n in minutes or n in hours or n == steps:
        pickle.dump(r, open(f"{out}/state-{n:06d}.pkl", "wb"))
json.dump(log, open(f"{out}/log.json", "w"))
print("done in %.0f s" % (time.time() - t0))
