"""A short film in real time for the pace question: relief beside the old map (colours fixed to the land), 30 frames a
second, 20 s, starting 5 s before a cutoff on screen.   python3 film4.py state.pkl seconds_per_T out.mp4"""
import sys, os, copy, pickle, shutil, subprocess, numpy as np, render
from PIL import Image
state, pace, out = sys.argv[1], float(sys.argv[2]), sys.argv[3]
FPS, SECONDS, LEAD = 30, 20, 5
base = pickle.load(open(state, "rb")); base.eps = 1 / pace / FPS
r = copy.deepcopy(base); n0 = r.ncut; CUT = 0
while True:
    r.step(stamp_every=1, cut_every=1); CUT += 1
    if r.ncut > n0:
        _, cx, cy, size = r.cutlog[-1]; cx = (cx + r.pad) % r.L - r.pad
        if CUT > LEAD * FPS and 10 < cx < r.sx - 10 and 8 < cy < r.sy - 8 and size * r.ds > 10: break
        n0 = r.ncut
print(f"{out}: a cutoff {CUT / FPS:.0f} s on at ({cx:.1f}, {cy:.1f}) W, a loop of about {size * r.ds:.0f} W; filming from 5 s before it", flush=True)
tmp = out + ".frames"; shutil.rmtree(tmp, ignore_errors=True); os.makedirs(tmp)
r = copy.deepcopy(base)
for _ in range(CUT - LEAD * FPS): r.step(stamp_every=1, cut_every=1)
cuts = r.ncut
for n in range(SECONDS * FPS):
    r.step(stamp_every=1, cut_every=1)
    pre = render.reads(r, 1)
    pair = np.concatenate([render.relief(r, f=1, pre=pre), render.fisk(r, f=1, rule="fixed", pre=pre)], axis=1)[:490]
    Image.fromarray((pair * 255 + 0.5).astype(np.uint8)).save(f"{tmp}/{n:04d}.png")
print(f"{out}: {r.ncut - cuts} cutoffs during the film", flush=True)
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", f"{tmp}/%04d.png", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "17", out], check=True)
shutil.rmtree(tmp)
