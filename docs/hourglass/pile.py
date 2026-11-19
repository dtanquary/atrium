"""Hourglass method probe: a point-fed 2D pile with hysteretic avalanches in the lower bulb of a flat glass,
at a 14-inch MacBook Pro's device pixels (0.1 mm each), and the deposit-time map baked from it.

Throwaway research code (docs/hourglass/research-method.md). Run:
    python3 pile.py [--period 900] [--window 1.0] [--repose 32 --stable 35] [--bands 8] [--upper] [--out DIR]
--window: how far the flank must lag behind a line at the angle of repose from the top before it slides, as a share
          of the most a flank at the angle of maximum stability can lag (1.0: the whole flank steepens first, drum-like;
          0.3: smaller, more frequent slides). Each side draws its own share again (0.6 to 1.0 of it) after each slide.
--upper:  the upper bulb, turned 180 degrees, so the air over the draining sand grows as a pile from the round top.
Prints the timings and the avalanche statistics; writes small JPEGs to --out.
"""
import argparse, time, math
import numpy as np
from PIL import Image

p = argparse.ArgumentParser()
p.add_argument("--period", type=float, default=900.0)   # seconds to fill
p.add_argument("--window", type=float, default=1.0)
p.add_argument("--width", type=int, default=3024)
p.add_argument("--height", type=int, default=982)       # the lower bulb: the bottom half of the screen
p.add_argument("--layer", type=float, default=0)   # px: slide once the cap is this thick (Lemieux & Durian: ~15 grains), in place of --window
p.add_argument("--repose", type=float, default=32.0)    # degrees
p.add_argument("--stable", type=float, default=35.0)    # angle of maximum stability, degrees
p.add_argument("--dt", type=float, default=0.1)
p.add_argument("--fill", type=float, default=0.62)      # sand area as a share of the bulb's
p.add_argument("--seed", type=int, default=1)
p.add_argument("--out", default=".")
p.add_argument("--bands", type=int, default=0)   # coloured-sand layers: this many alternating bands of tone a fill
p.add_argument("--upper", action="store_true")   # the upper bulb, turned 180 degrees: the air above the sand grows as a pile from its round top while the sand drains
a = p.parse_args()
rng = np.random.default_rng(a.seed)
W, H = a.width, a.height
x = np.arange(W) + 0.5
x0 = W / 2
sr, sm = math.tan(math.radians(a.repose)), math.tan(math.radians(a.stable))

# The lower bulb of a flat glass, 180-degree symmetric with the upper: a rounded floor (a superellipse's bottom),
# and a ceiling that runs into the neck as a cone steeper than repose (so the turned glass drains clean).
half = 0.47 * W
u = np.clip(np.abs(x - x0) / half, 0, 1)
floor = 0.06 * H + 0.30 * H * (1 - (1 - u ** 3) ** (1 / 3))           # flat middle, rising to the walls
cone = H - 8 - np.abs(x - x0) * math.tan(math.radians(38))             # the shoulders, into the neck at the top
top = 0.94 * H - 0.30 * H * (1 - (1 - u ** 3) ** (1 / 3))
ceil = np.minimum(cone, top)
ceil = np.where(u >= 1, 0, ceil)
floor = np.where(u >= 1, H, floor)
inside = (u < 1) & (ceil > floor + 2)
cap = np.sum(np.clip(ceil - floor, 0, None))
total = a.fill * cap
q = total / a.period                                                   # px^2 per second
steps = int(a.period / a.dt)

h = floor.copy()
if a.upper:   # a level surface: air of even depth over the (turned) round top, sand from there to the funnel
    lo_, hi_ = 0.0, float(H)
    for _ in range(50):
        lev = (lo_ + hi_) / 2
        sandarea = np.clip(ceil - np.maximum(floor, lev), 0, None)[inside].sum()
        if sandarea > total: lo_ = lev
        else: hi_ = lev
    h = np.where(inside, np.minimum(np.maximum(floor, lo_), ceil), floor)
hist = np.empty((steps + 1, W), np.float32)
hist[0] = h
avs = []          # (step, side, apex x, end x, layer px^2)

def cap_fill(h, xa, m):
    """Sand landing at the top settles as a cap at the angle of maximum stability round the apex: the new
    profile is max(h, P - sm |x - xa|), P chosen so the cap holds m px^2 (bucket filling)."""
    lo_i, hi_i = max(xa - 900, 0), min(xa + 900, W)
    seg, cl = h[lo_i:hi_i], ceil[lo_i:hi_i]
    d = np.abs(np.arange(lo_i, hi_i) - xa)
    lo, hi = seg.min(), seg.max() + 400
    for _ in range(40):
        P = (lo + hi) / 2
        add = np.clip(np.minimum(np.maximum(seg, P - sm * d), cl) - seg, 0, None).sum()
        if add > m: hi = P
        else: lo = P
    h[lo_i:hi_i] = np.maximum(seg, np.minimum(np.maximum(seg, lo - sm * d), cl))

def lag(h, xa, side):
    """How far the flank lags behind a line at the angle of repose from the apex (the steep cap has grown by that
    much since the flank last slid), and the flank's length, apex to foot, leaving out sand held by the glass."""
    idx = np.arange(xa, -1, -1) if side < 0 else np.arange(xa, W)
    idx = idx[inside[idx]]
    on = (h[idx] > floor[idx] + 1) & (h[idx] < ceil[idx] - 0.5)
    if on.sum() < 30: return 0.0, 0
    last = np.nonzero(on)[0][-1]
    d = np.abs(idx[:last + 1] - xa)
    deficit = (h[xa] - sr * d) - h[idx[:last + 1]]
    return float(np.max(np.where(on[:last + 1], deficit, 0))), int(d[-1])

def avalanche(h, xa, side):
    """Relax one flank from the apex down to a line at the angle of repose, keeping the sand: the top is eroded,
    the rest gets a layer, clamped under the ceiling. Returns the new profile and where it ended."""
    if side > 0:
        idx = np.arange(xa, W)
    else:
        idx = np.arange(xa, -1, -1)
    idx = idx[inside[idx]]
    old = h[idx]
    dist = np.abs(idx - xa).astype(np.float64)
    mass = old.sum()

    def shape(top):
        line = top - sr * dist
        # erosion only from the apex down to where the line first rises above the old surface
        cross = np.argmax(line >= old) if np.any(line >= old) else len(old)
        g = np.maximum(line, old)
        g[:cross] = line[:cross]
        return np.minimum(g, ceil[idx]), cross

    lo, hi = old.min() - 10, old[0]
    if shape(hi)[0].sum() < mass: return None, 0.0   # held up by the glass: no room to slide
    for _ in range(50):
        mid = (lo + hi) / 2
        if shape(mid)[0].sum() > mass: hi = mid
        else: lo = mid
    g, cross = shape(lo)
    h[idx] = g
    return idx[-1], float(np.abs(g - old).sum() / 2)

t0 = time.perf_counter()
need = {-1: rng.uniform(0.6, 1.0), 1: rng.uniform(0.6, 1.0)}
for s in range(1, steps + 1):
    land = int(round(x0 + rng.normal(0, 3)))                            # the stream wanders a little
    cap_fill(h, land, q * a.dt)
    apex = land - 6 + int(np.argmax(h[land - 6:land + 7]))             # the top is under the stream
    fails = []
    for side in (-1, 1):
        dl, L = lag(h, apex, side)
        limit = a.layer * need[side] / 0.8 if a.layer > 0 else a.window * need[side] * (sm - sr) * L
        if L > 30 and dl >= max(1.0, min(limit, (sm - sr) * L)): fails.append((dl / max(L, 1), side))
    if fails:
        side = max(fails)[1]
        end, moved = avalanche(h, apex, side)
        if end is not None: avs.append((s, side, apex, end, moved))
        need[side] = rng.uniform(0.6, 1.0)
    hist[s] = h
sim = time.perf_counter() - t0

# The deposit-time map: when each pixel is first sand, and (for the share eroded by an avalanche) when it goes.
t1 = time.perf_counter()
ys = np.arange(H, dtype=np.float32) + 0.5
first = np.full((H, W), np.inf, np.float32)
gone = np.full((H, W), np.inf, np.float32)
refills = np.zeros((H, W), np.uint8)
run = np.maximum.accumulate(hist, axis=0)
for c in range(W):
    if not inside[c]: continue
    col = hist[:, c]
    i = np.searchsorted(run[:, c], ys, side="right")   # first step the column stood above y
    ok = i <= steps
    first[ok, c] = i[ok] * a.dt
    # erosion: steps where the column fell; pixels between new and old height are taken away
    fell = np.nonzero(np.diff(col) < -0.5)[0]
    for f in fell:
        lo_, hi_ = int(col[f + 1]), int(math.ceil(col[f]))
        gone[lo_:hi_, c] = np.minimum(gone[lo_:hi_, c], (f + 1) * a.dt)
        refills[lo_:hi_, c] += 1
bake = time.perf_counter() - t1
ev = np.array([v[0] for v in avs]) * a.dt
sizes = np.array([v[4] for v in avs])
sand = np.isfinite(first) & (ys[:, None] < hist[-1][None, :]) & (ys[:, None] > floor[None, :])
print(f"bulb {W}x{H}, sand {total:.0f} px^2 ({total/100:.0f} mm^2 at 0.1 mm/px), feed {q:.0f} px^2/s, {steps} steps")
print(f"sim {sim:.2f} s (numpy), deposit map {bake:.2f} s (numpy, per-column loop)")
print(f"avalanches {len(avs)}: one every {a.period/max(len(avs),1):.1f} s; moved px^2 median {np.median(sizes) if len(sizes) else 0:.0f}, "
      f"p10 {np.percentile(sizes,10) if len(sizes) else 0:.0f}, p90 {np.percentile(sizes,90) if len(sizes) else 0:.0f}")
if len(ev) > 1:
    gaps = np.diff(ev)
    big = ev[sizes > 2000]
    print(f"slides moving over 2000 px^2: {len(big)}, one every {a.period/max(len(big),1):.1f} s")
    print(f"gaps s: median {np.median(gaps):.1f} p10 {np.percentile(gaps,10):.1f} p90 {np.percentile(gaps,90):.1f} max {gaps.max():.1f}")
    sides = np.array([v[1] for v in avs]); print(f"sides: left {np.sum(sides<0)} right {np.sum(sides>0)}; longest run on one side {max(len(r) for r in ''.join('L' if v<0 else 'R' for v in sides).replace('LR','L R').replace('RL','R L').split())}")
er = np.isfinite(gone) & sand
print(f"pixels eroded then refilled: {er.sum()} of {sand.sum()} sand pixels ({100*er.sum()/max(sand.sum(),1):.2f}%); max fills of one pixel {refills.max()+1}")
apexh = hist[:, inside].max(axis=1)
mass = (hist[:, inside] - hist[0, inside]).sum(axis=1)
print('fed at 25/50/100%:', [round(float(mass[int(f*steps)])/total, 3) for f in (0.25, 0.5, 1.0)])
print(f"apex rise: {(apexh[-1]-apexh[0]):.0f} px over the period; per minute in the first, middle and last tenth: "
      + ", ".join(f"{(apexh[min(int((f+0.1)*steps),steps)]-apexh[int(f*steps)])/(0.1*a.period/60):.1f}" for f in (0.0, 0.45, 0.9)))
rise = np.diff(apexh) / a.dt
print(f"top's rise between slides: median {np.median(rise[rise>0]):.2f} px/s, p99 {np.percentile(rise[rise>0],99):.2f} px/s; biggest one-step change of any column {np.abs(np.diff(hist[:, inside], axis=0)).max():.1f} px")
np.save(f"{a.out}/avs.npy", np.array(avs, dtype=np.float64))

# Pictures, at a quarter size: the deposit time coloured (to show the layering), and the sand at three moments.
def shrink(img): return img.resize((W // 4, H // 4), Image.LANCZOS)
def tcolour(tm):
    ph = (tm / a.period * 9.0) % 1.0
    r = 0.55 + 0.35 * np.cos(2 * np.pi * (ph + 0.00)); g = 0.50 + 0.30 * np.cos(2 * np.pi * (ph + 0.33)); b = 0.45 + 0.30 * np.cos(2 * np.pi * (ph + 0.66))
    return np.stack([r, g, b], -1)
end = a.period
shown = np.isfinite(first) & (first <= end) & ~(gone <= end) | (np.isfinite(first) & (ys[:, None] < hist[-1][None, :]))
img = np.where(shown[..., None], tcolour(np.where(np.isfinite(first), first, 0)), 0.04)
img[~inside[None, :].repeat(H, 0)] = 0.0
img[ys[:, None].repeat(W, 1) > ceil[None, :]] = 0.12
img[ys[:, None].repeat(W, 1) < floor[None, :]] = 0.12
shrink(Image.fromarray((np.flipud(img) * 255).astype(np.uint8))).save(f"{a.out}/layers.jpg", quality=82)
noise = rng.normal(0, 1, (H, W)).astype(np.float32)
ys = ys.astype(np.float32)
for frac in (0.25, 0.6, 1.0):
    tt = frac * a.period
    s_i = min(int(tt / a.dt), steps)
    surf = hist[s_i]
    is_sand = (ys[:, None] > surf[None, :]) & (ys[:, None] < ceil[None, :]) if a.upper else ys[:, None] < surf[None, :]
    # sand: warm grey, a pixel's own noise (grains are 1-2 px at life size), and each avalanche layer a touch
    # darker at its base, as two sizes of grain would lay it (Makse's strata), faintly
    si = np.clip(np.where(np.isfinite(first), first / a.dt, 1).round().astype(int), 1, steps)
    cols = np.arange(W)[None, :]
    prev, new = hist[si - 1, cols], hist[si, cols]
    within = np.clip((ys[:, None] - prev) / np.maximum(new - prev, 1e-3), 0, 1)
    tone = 0.62 + 0.035 * noise - 0.05 * (1 - within)
    if a.bands: tone = tone * (1 + 0.10 * np.sign(np.cos(2 * np.pi * np.where(np.isfinite(first), first, 0) / a.period * a.bands / 2)))
    col = np.stack([tone * 1.0, tone * 0.90, tone * 0.74], -1)
    img = np.where(is_sand[..., None], col, 0.05)
    img[:, ~inside] = 0
    img[ys[:, None].repeat(W, 1) > ceil[None, :]] = 0.12
    img[ys[:, None].repeat(W, 1) < floor[None, :]] = 0.12
    if a.upper: img = np.flipud(np.fliplr(img))
    shrink(Image.fromarray((np.clip(np.flipud(img), 0, 1) * 255).astype(np.uint8))).save(f"{a.out}/sand-{int(frac*100):03d}.jpg", quality=82)
print("wrote", a.out)
