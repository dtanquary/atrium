# Measures how a canopy moves in one clip (an .npz of gray frames, RGB frames for the masks, fps), by block phase
# correlation, in Canopy's units: px at 2x on a 14" screen through a 90-degree lens (1512 px per unit of tan).
#   python3 -I flow.py clip.npz hfov_degrees out.json [stabilise: auto|none|all|thick]
import sys, json, numpy as np
from PIL import Image

path, hfov, out = sys.argv[1], float(sys.argv[2]), sys.argv[3]
mode = sys.argv[4] if len(sys.argv) > 4 else 'auto'
z = np.load(path)
gray, rgb, fps = z['gray'], z['rgb'], float(z['fps'])
T, H, W = gray.shape
k = 1512.0 / ((W / 2) / np.tan(np.radians(hfov / 2)))  # Canopy px at 2x per working px (at the middle)
B, S = 32, 16
L = max(1, round(fps / 12.5)); dt = L / fps
ys = np.arange(0, H - B + 1, S); xs = np.arange(0, W - B + 1, S)
ny, nx = len(ys), len(xs); N = ny * nx
cy, cx = np.meshgrid(ys + B / 2, xs + B / 2, indexing='ij'); cy, cx = cy.ravel(), cx.ravel()
win = np.outer(np.hanning(B), np.hanning(B)).astype(np.float32)

def blocks(img):
    v = np.lib.stride_tricks.sliding_window_view(img.astype(np.float32), (B, B))[::S, ::S][:ny, :nx]
    return v.reshape(N, B, B)

def spectra(img):
    b = blocks(img); tex = b.std(axis=(1, 2))
    return np.fft.fft2((b - b.mean(axis=(1, 2), keepdims=True)) * win), tex

def pc(fa, fb):
    """Where each block's content in a moved to in b: (dx, dy, peak)."""
    R = fb * np.conj(fa); R /= np.abs(R) + 1e-3
    r = np.fft.ifft2(R).real
    flat = r.reshape(N, -1); i = flat.argmax(1); peak = flat[np.arange(N), i]
    iy, ix = i // B, i % B
    def sub(m, p, c):  # parabola through three
        d = m - 2 * c + p; return np.where(np.abs(d) > 1e-9, 0.5 * (m - p) / d, 0)
    n = np.arange(N)
    dy = iy + sub(r[n, (iy - 1) % B, ix], r[n, (iy + 1) % B, ix], peak)
    dx = ix + sub(r[n, iy, (ix - 1) % B], r[n, iy, (ix + 1) % B], peak)
    dy = (dy + B / 2) % B - B / 2; dx = (dx + B / 2) % B - B / 2
    return dx, dy, peak

px, py = cx - W / 2, cy - H / 2
def fit(dx, dy, w):
    """A similarity (shift, zoom, turn) by weighted least squares, dropping outliers: its field at each block."""
    keep = w > 0
    p = np.zeros(4)
    for _ in range(4):
        if keep.sum() < 12: return np.zeros(N), np.zeros(N), p
        A = np.zeros((2 * keep.sum(), 4)); kx, ky = px[keep], py[keep]
        A[0::2] = np.stack([np.ones_like(kx), np.zeros_like(kx), kx, -ky], 1)
        A[1::2] = np.stack([np.zeros_like(kx), np.ones_like(kx), ky, kx], 1)
        b = np.empty(2 * keep.sum()); b[0::2] = dx[keep]; b[1::2] = dy[keep]
        ww = np.repeat(np.sqrt(w[keep]), 2)
        p = np.linalg.lstsq(A * ww[:, None], b * ww, rcond=None)[0]
        gx = p[0] + p[2] * px - p[3] * py; gy = p[1] + p[2] * py + p[3] * px
        res = np.hypot(dx - gx, dy - gy)
        mad = np.median(res[keep]); keep = (w > 0) & (res < max(3 * mad, 0.3))
    return gx, gy, p

# masks at the RGB frames' size: sky (bright, blue or neutral), leafy (saturated green, yellow or red), and how
# far each covered pixel is from the sky (a thickness)
hs, ws = rgb.shape[1], rgb.shape[2]; f = W // ws  # working px per mask px
def masks(c):
    c = c.astype(np.int16); r, g, b = c[..., 0], c[..., 1], c[..., 2]
    l = (r + g + b) / 3
    sky = (b >= g - 6) & (b >= r - 6) & (l > masks.bright)
    mx, mn = np.maximum(np.maximum(r, g), b), np.minimum(np.minimum(r, g), b)
    leafy = ~sky & ((mx - mn) > 0.25 * (mx + 1)) & ((g > b + 10) | (r > b + 25))
    d = np.zeros(sky.shape, np.int16); m = ~sky
    for i in range(1, 40):
        e = m.copy()
        e[1:] &= m[:-1]; e[:-1] &= m[1:]; e[:, 1:] &= m[:, :-1]; e[:, :-1] &= m[:, 1:]
        e[0] = e[-1] = False; e[:, 0] = e[:, -1] = False
        m = e
        if not m.any(): break
        d[m] = i
    return sky, leafy, d
l0 = rgb[::max(1, T // 20)].astype(np.int16).mean(-1)
masks.bright = 0.5 * np.percentile(l0, 99)

def classify(c):
    """Each block's class: 0 sky, 1 twigs, 2 limbs, 3 trunks or solid masses, 4 foliage edge, 5 foliage mass."""
    sky, leafy, d = masks(c)
    bs, ss = B // f, S // f
    def per(a, fn):
        v = np.lib.stride_tricks.sliding_window_view(a, (bs, bs))[::ss, ::ss][:ny, :nx]
        return fn(v.reshape(N, -1))
    cover = per((~sky).astype(np.float32), lambda v: v.mean(1))
    leaf = per(leafy.astype(np.float32), lambda v: v.mean(1)) / np.maximum(cover, 1e-3)
    thick = (2 * per(d.astype(np.float32), lambda v: np.percentile(v, 95, axis=1)) + 1) * f * k  # Canopy px
    cls = np.where(thick < 12, 1, np.where(thick < 40, 2, 3))
    cls = np.where(leaf > 0.5, np.where(cover < 0.75, 4, 5), cls)
    return np.where(cover < 0.08, 0, cls), cover, sky

names = ['sky', 'twigs', 'limbs', 'trunks/solid', 'foliage edge', 'foliage mass']
rt = rgb.shape[0] / T  # RGB frames per gray frame (the same clip, so 1)

# 1. velocity at lag L, every L frames
idx = np.arange(0, T - L, L)
V = np.zeros((len(idx), N, 2), np.float32); P = np.zeros((len(idx), N), np.float32)
G = np.zeros((len(idx), N, 2), np.float32); GP = np.zeros((len(idx), 4)); CL = np.zeros((len(idx), N), np.int8)
TX = np.zeros((len(idx), N), np.float32); SKY = []
fa, ta = spectra(gray[0])
for n, t in enumerate(idx):
    fb, tb = spectra(gray[t + L])
    dx, dy, peak = pc(fa, fb)
    cls, cover, sky = classify(rgb[min(int(t * rt), rgb.shape[0] - 1)])
    SKY.append(sky)
    good = (peak > 0.25) & (ta > 4) & (cls > 0)
    V[n, :, 0], V[n, :, 1], P[n], CL[n], TX[n] = dx, dy, np.where(good, peak, 0), cls, ta
    fa, ta = fb, tb
# the camera: a similarity fit to the thickest wood if there is enough of it, else to everything
thickshare = ((CL == 3) & (P > 0)).sum(1).mean()
ref = mode if mode != 'auto' else ('thick' if thickshare >= 20 else 'all')
for n in range(len(idx)):
    w = P[n] * (CL[n] == 3) if ref == 'thick' else P[n]
    if ref == 'none': continue
    gx, gy, p = fit(V[n, :, 0], V[n, :, 1], w)
    G[n, :, 0], G[n, :, 1], GP[n] = gx, gy, p
R = (V - G) * k / dt  # Canopy px per second, relative to the camera's fit
valid = P > 0

out_d = {'clip': path.split('/')[-1], 'fps': fps, 'lag_s': dt, 'k': k, 'hfov': hfov, 'frames': T, 'seconds': T / fps,
         'stabilise': ref, 'thick_blocks': float(thickshare)}
# the camera's own motion, for judging tripod or hand
gsp = np.hypot(GP[:, 0], GP[:, 1]) * k / dt
out_d['camera_speed_rms'] = float(np.sqrt((gsp ** 2).mean())); out_d['camera_turn_deg_s_rms'] = float(np.degrees(np.sqrt((GP[:, 3] ** 2).mean())) / dt)

# 2. speed by class
sp = np.hypot(R[..., 0], R[..., 1])
cls_stats = {}
for c in range(1, 6):
    m = valid & (CL == c)
    if m.sum() < 200: continue
    s = sp[m]
    cls_stats[names[c]] = {'share': float(m.mean()), 'speed_rms': float(np.sqrt((s ** 2).mean())), 'speed_p50': float(np.median(s)),
                           'speed_p95': float(np.percentile(s, 95))}
out_d['speed'] = cls_stats
allm = valid & (CL > 0)
out_d['speed_all'] = {'rms': float(np.sqrt((sp[allm] ** 2).mean())), 'p50': float(np.median(sp[allm])), 'p95': float(np.percentile(sp[allm], 95))}

# 3. spectrum of displacement by class, from blocks valid nearly all the time (and the class they mostly are)
steady = valid.mean(0) > 0.85
blockcls = np.array([np.bincount(CL[:, j][CL[:, j] > 0], minlength=6).argmax() if (CL[:, j] > 0).any() else 0 for j in range(N)])
nt = len(idx); freqs = np.fft.rfftfreq(nt, dt)
band = (freqs >= 0.1) & (freqs <= min(6, 0.5 / dt))
def spec(sel):
    v = R[:, sel, :] - R[:, sel, :].mean(0)
    pw = (np.abs(np.fft.rfft(v * np.hanning(nt)[:, None, None], axis=0)) ** 2).sum(-1).mean(1)
    disp = np.where(freqs > 0, pw / (2 * np.pi * np.maximum(freqs, 1e-6)) ** 2, 0)
    db, fb_ = disp[band], freqs[band]; vb = pw[band]
    pk = fb_[db.argmax()]
    cum = np.cumsum(db) / db.sum(); cumv = np.cumsum(vb) / vb.sum()
    near = (fb_ > pk * 0.8) & (fb_ < pk * 1.2)
    bands = {'lt0.5': float(db[fb_ < 0.5].sum() / db.sum()), '0.5-2': float(db[(fb_ >= 0.5) & (fb_ < 2)].sum() / db.sum()), 'ge2': float(db[fb_ >= 2].sum() / db.sum())}
    return {'bands': bands, 'blocks': int(sel.sum()), 'disp_peak_hz': float(pk), 'disp_median_hz': float(fb_[np.searchsorted(cum, 0.5)]),
            'vel_median_hz': float(fb_[np.searchsorted(cumv, 0.5)]), 'peak_share': float(db[near].sum() / db.sum()),
            'curve': [[float(a), float(b)] for a, b in zip(fb_, db / db.sum())]}
specs = {}
for c in range(1, 6):
    sel = steady & (blockcls == c)
    if sel.sum() >= 8: specs[names[c]] = spec(sel)
if (steady & (blockcls > 0)).sum() >= 8: specs['all'] = spec(steady & (blockcls > 0))
out_d['spectrum'] = specs

# 4. displacement against lag (structure function), matching frame t to t + lag directly, after the camera's fit
lags = [l for l in [1 / fps, 0.1, 0.25, 0.5, 1, 2, 4, 8] if l * fps < T * 0.6]
sf = {}
for lag in lags:
    m = int(round(lag * fps)); ds = {c: [] for c in range(1, 6)}; lost = []; dall = []
    for t in range(0, T - m, max(1, int(fps / 2))):
        fa_, ta_ = spectra(gray[t]); fb_, _ = spectra(gray[t + m])
        dx, dy, peak = pc(fa_, fb_)
        cls, _, _ = classify(rgb[min(int(t * rt), rgb.shape[0] - 1)])
        ok = (ta_ > 4) & (cls > 0)
        good = ok & (peak > 0.25)
        if ref == 'none': gx = gy = np.zeros(N)
        else: gx, gy, _ = fit(dx, dy, peak * good * ((cls == 3) if ref == 'thick' else 1))
        d = np.hypot(dx - gx, dy - gy) * k
        lost.append(1 - good.sum() / max(ok.sum(), 1))
        for c in range(1, 6): ds[c] += list(d[good & (cls == c)])
        dall += list(d[good])
    row = {'lost': float(np.mean(lost)), 'all_rms': float(np.sqrt(np.mean(np.square(dall)))) if dall else None,
           'all_p95': float(np.percentile(dall, 95)) if dall else None}
    for c in range(1, 6):
        if len(ds[c]) > 100: row[names[c]] = [float(np.sqrt(np.mean(np.square(ds[c])))), float(np.percentile(ds[c], 95))]
    sf[str(round(lag, 3))] = row
out_d['displacement_vs_lag'] = sf

# 5. coherence: correlation of velocity between steady blocks against separation (not overlapping), per class pair too
sel = np.where(steady & (blockcls > 0))[0]
if len(sel) >= 10:
    v = R[:, sel, :] - R[:, sel, :].mean(0)
    sw = max(1, int(round(0.5 / dt)))
    v = np.apply_along_axis(lambda a: np.convolve(a, np.ones(sw) / sw, mode='same'), 0, v)
    vx, vy = v[..., 0].T, v[..., 1].T
    cc = (vx @ vx.T + vy @ vy.T); nrm = np.sqrt(np.diag(cc)); cc = cc / np.outer(nrm, nrm)
    dist = np.hypot(cx[sel][:, None] - cx[sel][None], cy[sel][:, None] - cy[sel][None])
    edges = [B, 2 * B, 3 * B, 4 * B, 6 * B, 8 * B, 12 * B, 16 * B, 24 * B]
    rows = []
    for a, b in zip(edges[:-1], edges[1:]):
        m = (dist >= a) & (dist < b)
        if m.sum() > 20: rows.append([float((a + b) / 2 * k), float(cc[m].mean()), int(m.sum())])
    out_d['coherence'] = rows
    same = blockcls[sel][:, None] == blockcls[sel][None]
    m = (dist >= B) & (dist < 2 * B)
    out_d['neighbour_corr'] = {'all': float(cc[m].mean()), 'same_class': float(cc[m & same].mean()) if (m & same).any() else None,
                               'other_class': float(cc[m & ~same].mean()) if (m & ~same).any() else None}
    for c in range(1, 6):
        mc = m & (blockcls[sel][:, None] == c) & (blockcls[sel][None] == c)
        if mc.sum() > 20: out_d['neighbour_corr'][names[c]] = float(cc[mc].mean())

# 6. gusts: the mean speed over the canopy, smoothed over 1 s
e = np.array([sp[n][valid[n]].mean() if valid[n].any() else np.nan for n in range(nt)])
e = np.nan_to_num(e, nan=np.nanmean(e))
kw = max(1, int(round(1 / dt))); es = np.convolve(e, np.ones(kw) / kw, mode='same')[kw:-kw] if nt > 3 * kw else e
med = np.median(es); lull = es < 0.5 * med
runs = []; r = 0
for x in lull:
    if x: r += 1
    elif r: runs.append(r * dt); r = 0
if r: runs.append(r * dt)
out_d['gusts'] = {'mean_speed_cv': float(es.std() / es.mean()), 'p90_over_p10': float(np.percentile(es, 90) / max(np.percentile(es, 10), 1e-6)),
                  'lulls_over_1s': [float(x) for x in runs if x >= 1], 'series': [float(x) for x in es]}
# a gust front: lag of each column band's envelope behind the left one, and each row band's behind the top one
def bandlag(axis):
    nb = 4; key = cx if axis == 0 else cy; span = W if axis == 0 else H
    env = []
    for b in range(nb):
        mb = (key >= b * span / nb) & (key < (b + 1) * span / nb)
        s = np.array([sp[n][valid[n] & mb].mean() if (valid[n] & mb).any() else np.nan for n in range(nt)])
        s = np.nan_to_num(s, nan=np.nanmean(s)); s = np.convolve(s, np.ones(kw) / kw, mode='same'); env.append(s - s.mean())
    res = []
    ml = int(3 / dt)
    for b in range(1, nb):
        a, c = env[0], env[b]
        best = max(range(-ml, ml + 1), key=lambda l: np.dot(a[max(0, -l):nt - max(0, l)], c[max(0, l):nt - max(0, -l)]) /
                   (np.linalg.norm(a[max(0, -l):nt - max(0, l)]) * np.linalg.norm(c[max(0, l):nt - max(0, -l)]) + 1e-9))
        aa, ccc = a[max(0, -best):nt - max(0, best)], c[max(0, best):nt - max(0, -best)]
        res.append([float(b * span / nb * k), float(best * dt), float(np.dot(aa, ccc) / (np.linalg.norm(aa) * np.linalg.norm(ccc) + 1e-9))])
    return res
out_d['gust_front'] = {'across_columns': bandlag(0), 'down_rows': bandlag(1)}

# 7. gaps: how long a pixel at the canopy's edge stays sky or covered, and how often it flips
sky = np.array(SKY)
mix = (sky.mean(0) > 0.1) & (sky.mean(0) < 0.9)
if mix.sum() > 100:
    s = sky[:, mix]
    flips = (s[1:] != s[:-1]).sum(0) / ((len(s) - 1) * dt)
    sk, cv = [], []
    for j in np.random.default_rng(0).choice(s.shape[1], min(3000, s.shape[1]), replace=False):
        col = s[:, j]; ch = np.flatnonzero(col[1:] != col[:-1])
        if len(ch) < 2: continue
        segs = np.diff(ch) * dt; st = col[ch[:-1] + 1]
        sk += list(segs[st]); cv += list(segs[~st])
    out_d['gaps'] = {'mixed_share_of_screen': float(mix.mean()), 'flips_per_s_median': float(np.median(flips)),
                     'flips_per_s_mean': float(flips.mean()),
                     'sky_run_s_median': float(np.median(sk)) if sk else None, 'cover_run_s_median': float(np.median(cv)) if cv else None}
json.dump(out_d, open(out, 'w'))
brief = {k_: v for k_, v in out_d.items() if k_ not in ('spectrum', 'gusts')}
print(json.dumps(brief)[:3000])
print({c: {kk: vv for kk, vv in s.items() if kk != 'curve'} for c, s in specs.items()})
print({kk: vv for kk, vv in out_d['gusts'].items() if kk != 'series'})
