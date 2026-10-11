"""Do catalogue stars drawn by the grid-and-stretch method land where lensing puts them, and stay round?
For each star, solve for its two images directly (root-finding on the escape angle), then look at what the
per-pixel method drew there. Run: python3 stars_check.py"""
import numpy as np
from bhlib import *
from render import star_grid, stars_through_lens, rot, save, STARS

W, H, R_C, FOV, INC = 1512, 982, 40.0, 50.0, 78.0
c, d = camera(W, H, FOV, INC, R_C)
T = Tables((256, 128), 1024, True, True)
tr = trace_tables(c, d, R_C, 1.0001 * 3.0, T, np.float64)          # no disc to speak of: sky everywhere
focal = W / (2 * np.tan(np.radians(FOV / 2)))
yp, cosd, sind, alpha = plane_basis(c, d)
u_c = 1 / R_C
def phi_inf(sin_delta):
    ee = u_c * np.sqrt(1 - u_c) / sin_delta
    return 2 * T.lookup_phia(np.minimum(ee * ee, MU)) - phi_camera(ee, u_c)
delta = np.arcsin(np.clip(sind, 1e-9, 1)); h = 2e-4
k_r = (phi_inf(np.sin(delta + h)) - phi_inf(np.sin(delta - h))) / (2 * h)
pin = tr["phi_inf"]; k_t = np.sin(pin) / np.maximum(sind, 1e-9)
e_r = -np.sin(pin)[..., None] * c + np.cos(pin)[..., None] * yp
e_t = np.cross(np.broadcast_to(c, yp.shape), yp)
R = rot("z", 200.0) @ rot("x", 62.0)
grid, lost = star_grid(R)
sky = np.nan_to_num(tr["sky"])
img = stars_through_lens(sky, k_r, k_t, e_r, e_t, grid, focal)
img = np.where(tr["escaped"][..., None], img, 0)
lum = img.sum(-1)
save("stars-only.png", 1 - np.exp(-img * 1.5))

# direct solution for each star's images
rows = [l.split() for l in open(STARS) if not l.startswith('#')]
ra, dec, v, bv = np.array(rows, float).T
ra, dec = np.radians(ra), np.radians(dec)
s = np.stack([np.cos(dec) * np.cos(ra), np.cos(dec) * np.sin(ra), np.sin(dec)], 1) @ R.T
f = -c; right = np.cross(f, [0, 0, 1.0]); right /= np.linalg.norm(right); up = np.cross(right, f)
d_crit = np.arcsin(u_c * np.sqrt(1 - u_c) / np.sqrt(MU))           # the shadow's edge
def solve(target):               # delta with phi_inf(delta) = target, by bisection (phi_inf falls as delta grows)
    lo, hi = d_crit * (1 + 1e-9), np.radians(60.0)
    if not (phi_inf(np.sin(hi)) < target < phi_inf(np.sin(lo))): return None
    for _ in range(60):
        mid = 0.5 * (lo + hi)
        if phi_inf(np.sin(mid)) > target: lo = mid
        else: hi = mid
    return 0.5 * (lo + hi)
res = {1: [], 2: []}
for si, m in zip(s, v):
    ps = np.arccos(np.clip(si @ c, -1, 1))
    y1 = si - (si @ c) * c; y1 /= np.linalg.norm(y1)
    for order, target, ydir in [(1, ps, y1), (2, 2 * np.pi - ps, -y1)]:
        dl = solve(target)
        if dl is None: continue
        dvec = -np.cos(dl) * c + np.sin(dl) * ydir
        z = dvec @ f
        if z <= 0: continue
        px = (dvec @ right / z / np.tan(np.radians(FOV / 2)) + 1) / 2 * W - 0.5
        py = (1 - dvec @ up / z / np.tan(np.radians(FOV / 2)) * W / H) / 2 * H - 0.5
        if not (12 < px < W - 12 and 12 < py < H - 12): continue
        # magnification from the direct solution
        kr = (phi_inf(np.sin(dl + h)) - phi_inf(np.sin(dl - h))) / (2 * h); kt = np.sin(target) / np.sin(dl)
        mu = 1 / abs(kr * kt)
        flux = 10 ** (-0.4 * (m - 2.0)) * min(mu, 40)
        if flux < 0.02: continue
        xi, yi = int(round(px)), int(round(py))
        box = lum[yi - 8:yi + 9, xi - 8:xi + 9]
        if box.sum() <= 0: res[order].append((np.nan, np.nan, mu, m, np.degrees(dl - d_crit))); continue
        yy, xx = np.mgrid[-8:9, -8:9]
        cx, cy = (box * xx).sum() / box.sum() + xi, (box * yy).sum() / box.sum() + yi
        # roundness from the core's second moments
        core = np.where(box > 0.3 * box.max(), box, 0)
        mx, my = (core * xx).sum() / core.sum(), (core * yy).sum() / core.sum()
        sxx = (core * (xx - mx) ** 2).sum() / core.sum(); syy = (core * (yy - my) ** 2).sum() / core.sum(); sxy = (core * (xx - mx) * (yy - my)).sum() / core.sum()
        tr_, det = sxx + syy, sxx * syy - sxy ** 2
        l1, l2 = tr_ / 2 + np.sqrt(max(tr_ ** 2 / 4 - det, 0)), tr_ / 2 - np.sqrt(max(tr_ ** 2 / 4 - det, 0))
        res[order].append((np.hypot(cx - px, cy - py), np.sqrt(l1 / max(l2, 1e-9)), mu, m, np.degrees(dl - d_crit)))
for order in (1, 2):
    a = np.array(res[order])
    if len(a) == 0: print(f"image {order}: none bright enough in frame"); continue
    ok = ~np.isnan(a[:, 0])
    print(f"image {order}: {len(a)} star images expected in frame, {ok.sum()} drawn; centroid off by median {np.median(a[ok, 0]):.2f} px, "
          f"max {a[ok, 0].max():.2f} px; axis ratio of the drawn point median {np.median(a[ok, 1]):.2f}, max {a[ok, 1].max():.2f}; "
          f"magnification {a[:, 2].min():.3f}..{a[:, 2].max():.1f}")
    near = a[a[:, 4] < 3.0]
    print(f"   within 3 deg of the shadow's edge: {len(near)} images; offsets {np.round(near[:, 0], 2).tolist()[:8]} px; axis ratios {np.round(near[:, 1], 2).tolist()[:8]}")
print(f"shadow radius {np.degrees(d_crit):.2f} deg = {np.tan(d_crit) * focal:.0f} px; stars lost to shared cells {lost}")
