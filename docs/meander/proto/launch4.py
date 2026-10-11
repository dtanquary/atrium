"""The first frame after the cheap distant past: T 300 of old history with nodes 1 W apart, steps of 0.12 T and plain
in-or-out stamps every 4th step, then T 60 as the live river runs it (nodes 0.5 W apart, steps of 0.04 T).
  python3 launch4.py seed outdir [T of distant past, default 300]"""
import sys, time, pickle, numpy as np, render
from meander import River
seed, out = int(sys.argv[1]), sys.argv[2]; past = float(sys.argv[3]) if len(sys.argv) > 3 else 300.0
t0 = time.time()
r = River(seed=seed, ds=1.0, eps=0.12)
for _ in range(int(past / r.eps)): r.step(stamp_every=4, cut_every=1, crude=True)
print("distant past:", r.stats(), "crossings", r.crossings(), "%.0f s" % (time.time() - t0))
r.ds, r.eps = 0.5, 0.04
r.resample()
for _ in range(1500): r.step(stamp_every=2, cut_every=1)
print("then T 60:", r.stats(), "crossings", r.crossings(), "lakes", len(r.lakes), "%.0f s" % (time.time() - t0))
pickle.dump(r, open(f"{out}/first-frame.pkl", "wb"))
render.save(render.relief(r), f"{out}/first-frame-relief.png")
render.save(render.fisk(r, rule="fixed"), f"{out}/first-frame-fisk.png")
render.save(render.fisk(r, rule="order"), f"{out}/first-frame-fisk-order.png")
