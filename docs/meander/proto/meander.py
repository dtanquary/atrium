#!/usr/bin/env python3
"""Meander prototype for Atrium.

Howard & Knutson (1984) curvature-driven migration of a centreline, with neck cutoffs, in a walled valley, feeding
three per-texel fields at the resolution the app would use (one texel per 2 pt):
  stamp  the time the channel last covered the texel
  lake   distance to the centreline of the abandoned loop the texel belongs to, creeping up as the lake fills
  dact   distance to the live centreline, in a narrow band (made at draw time here; every step in the app)
Units: channel width W = 1. Time T is 'nominal widths': the distance a bank of unit dimensionless curvature would
move with no upstream weighting (kl * t in the papers' terms).

The migration law and its constants are the ones meanderpy uses (Apache-2.0, read for reference, no code copied):
  R1(s) = OMEGA*R0(s) + GAMMA * sum(R0(s - xi) G(xi)) / sum(G),  G = exp(-alpha xi),  R0 = kl * W * curvature
"""
import numpy as np
from scipy.spatial import cKDTree  # only to find cutoffs quickly here; the app would use a grid of buckets

OMEGA, GAMMA = -1.0, 2.5
FAR = 9.0


def smooth(a, lo, hi):
    t = np.clip((a - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)


class River:
    """The river is periodic along the valley: its last node joins its first one valley-length further on. A pinned
    inlet lets the bends wash out downstream (see meander-pinned.py and lines-pinned-washout.png)."""
    def __init__(s, seed=1, sx=54.0, sy=35.07, tex=14, pad=10.0, ds=0.5, alpha=0.73, eps=0.04, cap=0.05,
                 crdist=1.04, wall=1.5, wallw=5.0, noise=0.5, fields=True, lake_life=16.0, start="noise"):
        s.rng = np.random.default_rng(seed)
        s.sx, s.sy, s.tex, s.pad, s.ds, s.alpha, s.eps, s.cap = sx, sy, tex, pad, ds, alpha, eps, cap
        s.L = sx + 2 * pad  # the valley's period; the screen shows x in 0..<sx
        s.crdist = crdist
        s.yc, s.ywall, s.wallw, s.noise = sy / 2, sy / 2 - wall, wallw, noise
        s.scallop = (s.rng.normal(0, 1, (2, 6)), s.rng.uniform(0, 6.283, (2, 6)))  # each wall wanders in and out along the valley
        s.fields, s.lake_life = fields, lake_life
        n = int(round(s.L / ds))
        s.x = -pad + s.L * np.arange(n) / n
        if start == "noise":  # a straight river with small wiggles: the instability does the rest
            k = np.arange(1, 40)[:, None]
            s.y = s.yc + (s.rng.normal(0, 0.25, (39, 1)) / np.sqrt(k) * np.sin(2 * np.pi * k * np.arange(n)[None, :] / n + s.rng.uniform(0, 6.283, (39, 1)))).sum(axis=0)
        else:  # a sine-generated curve (Langbein & Leopold 1966) with every bend its own size: a head start
            nb = 2 * int(round(s.L / s.rng.uniform(20, 26)))  # bends in the period, an even number
            parts = []
            for b in range(nb):
                m = int(s.rng.uniform(16, 30) / ds / 2); amp = s.rng.uniform(1.0, 1.9) * (1 if b % 2 == 0 else -1)
                parts.append(amp * np.sin(np.pi * (np.arange(m) + 0.5) / m))
            dth = np.concatenate(parts); th = np.cumsum(dth) * ds / 3.2  # direction along the path
            th -= th.mean()
            px, py = np.cumsum(ds * np.cos(th)), np.cumsum(ds * np.sin(th))
            py -= np.arange(len(py)) * py[-1] / len(py)  # close it across the valley
            px *= s.L / (px[-1] + ds * np.cos(th[0]))
            s.x, s.y = px - pad, py - py.mean() + s.yc
        s.t, s.steps, s.ncut, s.cutlog = 0.0, 0, 0, []
        k = int(8 / (alpha * ds))
        s.G = np.exp(-alpha * ds * np.arange(k)); s.Gsum = s.G.sum()
        # erodibility: a smooth random field, the same for the whole run (clay here, sand there), periodic too
        s.ecols = int(round(s.L / 8.0)); s.ecell = s.L / s.ecols
        s.egrid = s.rng.normal(0, 1, (int(sy / s.ecell) + 3, s.ecols))
        s.tw, s.th = int(round(sx * tex)), int(round(sy * tex))
        s.stamp = np.full((s.th, s.tw), -1e9, np.float32)
        s.hollow = np.full((s.th, s.tw), 1.0, np.float32)  # bank distance of old channels' footprints
        s.lakes = []; s.trims = []
        s.cov = np.zeros((s.th, s.tw), np.float32)
        s.cross = np.linspace(-0.5 + 0.3 / tex, 0.5 - 0.3 / tex, int(tex * 2) + 1)
        s.lastR = (0, 0)
        s.hw = np.full(len(s.x), 0.5)  # each node's half-width: wide round bends, narrow at the crossings between
        s.resample()

    # --- the river ---------------------------------------------------------------------------------------------
    def ext(s, a, k, shift=0.0):
        """a with k nodes of the neighbouring periods on each end."""
        return np.concatenate([a[-k:] - shift, a, a[:k] + shift])

    def erod(s, x, y):
        gx = ((x + s.pad) / s.ecell) % s.ecols; gy = np.clip(y / s.ecell, 0, s.egrid.shape[0] - 1.001)
        ix, iy = gx.astype(int) % s.ecols, gy.astype(int); fx, fy = gx - np.floor(gx), gy - iy
        g = s.egrid; jx = (ix + 1) % s.ecols
        v = (g[iy, ix] * (1 - fx) + g[iy, jx] * fx) * (1 - fy) + (g[iy + 1, ix] * (1 - fx) + g[iy + 1, jx] * fx) * fy
        return np.exp(s.noise * v)

    def rates(s):
        """Howard & Knutson's rate at every node: minus the local curvature, plus 2.5 times its average upstream,
        weighted by exp(-alpha * distance). Nodes aren't evenly spaced, so the curvature is the circle through
        three nodes and the average runs on the real distances."""
        n = len(s.x)
        x, y = s.ext(s.x, 1, s.L), s.ext(s.y, 1)
        ax, ay, bx, by = x[1:-1] - x[:-2], y[1:-1] - y[:-2], x[2:] - x[1:-1], y[2:] - y[1:-1]
        la, lb = np.hypot(ax, ay), np.hypot(bx, by)
        cx, cy = ax + bx, ay + by; lc = np.hypot(cx, cy) + 1e-12
        curv = 2 * (ax * by - ay * bx) / (la * lb * lc + 1e-12)
        w = (0.5 * (la + lb)).tolist(); kw = (curv * 0.5 * (la + lb)).tolist(); q = np.exp(-s.alpha * la).tolist()
        c = g = 0.0
        for i in range(max(n - int(16 / s.alpha / s.ds), 0), n):  # run up to the start from further round the period
            c = kw[i] + q[i] * c; g = w[i] + q[i] * g
        up = [0.0] * n
        for i in range(n):
            c = kw[i] + q[i] * c; g = w[i] + q[i] * g
            up[i] = c / g
        return OMEGA * curv + GAMMA * np.array(up), cy / lc, -cx / lc, curv

    def migrate(s):
        R, nx, ny, curv = s.rates()
        sg = np.sign(R)
        bx, by = s.x + 0.5 * sg * nx, s.y + 0.5 * sg * ny  # the bank being eaten
        E = s.erod(bx, by)
        # valley walls resist being cut into, and never hold a bank that is leaving them
        outward = (sg * ny) * (by - s.yc) > 0
        E = E * np.where(outward, smooth(s.ywall - s.wall_in(bx, by) - np.abs(by - s.yc), 0, s.wallw), 1.0)
        d = np.clip(R * E * s.eps, -1.25 * s.eps, 1.25 * s.eps)  # no bank moves faster than 1.25 W a T
        on = s.onscreen()
        s.lastR = (float(np.abs(d[on]).max()) / s.eps, float(np.abs(d[on]).mean()) / s.eps) if on.any() else (0, 0)
        s.x = s.x + d * nx; s.y = s.y + d * ny
        # the width eases toward 0.7 W where the river is straight and 1.5 W round its tightest bends
        bend = np.convolve(np.tile(np.abs(curv), 3), np.ones(7) / 7, "same")[len(curv):2 * len(curv)]
        want = 0.5 * (0.7 + 0.8 * np.clip(bend / 0.4, 0, 1))
        s.hw += (want - s.hw) * (1 - np.exp(-s.eps / 1.5))
        s.t += s.eps; s.steps += 1

    def wall_in(s, x, y):
        """How far the valley wall on a point's side stands in from its outermost line there: 0 to about 5 W,
        in bays 12 to 37 W long, so the belt's edge is scalloped, not a straight corridor."""
        side = (y > s.yc).astype(int)
        k = np.arange(2, 8)[None, :]
        amp, ph = s.scallop[0][side], s.scallop[1][side]
        wave = (amp / np.sqrt(k) * np.sin(2 * np.pi * k * ((x + s.pad) / s.L)[:, None] + ph)).sum(axis=1)
        return 2.5 * (1 + np.tanh(wave))

    def onscreen(s):
        xm = (s.x + s.pad) % s.L - s.pad
        return (xm >= 0) & (xm < s.sx)

    def resample(s, force=False):
        """Keeps the nodes 0.6 to 1.4 ds apart by splitting long segments (at the Catmull-Rom midpoint) and dropping
        the far node of short ones. Every other node stays where it is, so nothing shifts along the rest of the river."""
        for _ in range(4):
            n = len(s.x)
            x, y = s.ext(s.x, 2, s.L), s.ext(s.y, 2)
            seg = np.hypot(np.diff(x[2:n + 3]), np.diff(y[2:n + 3]))  # n segments, the last one closing the period
            long = np.nonzero(seg > 1.4 * s.ds)[0]
            if len(long):
                mid = lambda p: (-p[long + 1] + 9 * p[long + 2] + 9 * p[long + 3] - p[long + 4]) / 16
                s.x, s.y = np.insert(s.x, long + 1, mid(x)), np.insert(s.y, long + 1, mid(y))
                s.hw = np.insert(s.hw, long + 1, 0.5 * (s.hw[long] + s.hw[(long + 1) % n]))
                continue
            short = np.nonzero(seg < 0.6 * s.ds)[0]
            if not len(short): break
            short = short[np.concatenate([[True], np.diff(short) > 1])]  # never two neighbours at once
            drop = (short + 1) % n
            s.x, s.y, s.hw = np.delete(s.x, drop), np.delete(s.y, drop), np.delete(s.hw, drop)
        s.x -= s.L * np.round((s.x.mean() - (s.L / 2 - s.pad)) / s.L)

    def cutoff(s):
        """Neck cutoffs: where the banks of two stretches of the river touch, drop the loop between them."""
        while True:
            n = len(s.x)
            x, y, h = np.concatenate([s.x, s.x + s.L]), np.concatenate([s.y, s.y]), np.concatenate([s.hw, s.hw])
            pairs = cKDTree(np.c_[x, y]).query_pairs(s.crdist * 2 * s.hw.max(), output_type="ndarray")
            if not len(pairs): return
            lo, hi = pairs.min(axis=1), pairs.max(axis=1)
            dist = np.hypot(x[lo] - x[hi], y[lo] - y[hi])
            ok = (lo < n) & (hi - lo >= int(6 / s.ds)) & (hi - lo <= n - int(6 / s.ds)) & (dist < s.crdist * (h[lo] + h[hi]))
            if not ok.any(): return
            lo, hi, dist = lo[ok], hi[ok], dist[ok]
            k = np.argmin(dist - h[lo] - h[hi]); i, j = lo[k], hi[k]  # the pair whose banks are closest: straight across the neck
            loop = (x[i:j + 1].copy(), y[i:j + 1].copy(), h[i:j + 1].copy())
            s.cutlog.append((s.t, float(0.5 * (x[i] + x[j])), float(0.5 * (y[i] + y[j])), int(j - i)))
            keep = np.arange(j, i + n + 1)  # from j on round to i in the next period
            s.x, s.y, s.hw = x[keep] - (s.L if j >= n else 0), y[keep], h[keep]
            s.ncut += 1
            if s.fields: s.make_lake(*loop)

    # --- the floodplain's memory ---------------------------------------------------------------------------------
    def closed(s):
        """One period of the centreline with its closing node, and the half-widths, for drawing."""
        return np.append(s.x, s.x[0] + s.L), np.append(s.y, s.y[0]), np.append(s.hw, s.hw[0])

    def curve(s, x, y, h, closed=False):
        """A polyline with a point added half-way along each segment, on the Catmull-Rom curve through its nodes,
        so banks drawn from it are not faceted. A closed one is a period of the river with its closing node."""
        if closed:
            px, py = np.concatenate([[x[-2] - s.L], x, [x[1] + s.L]]), np.concatenate([[y[-2]], y, [y[1]]])
        else:
            px, py = np.concatenate([[2 * x[0] - x[1]], x, [2 * x[-1] - x[-2]]]), np.concatenate([[2 * y[0] - y[1]], y, [2 * y[-1] - y[-2]]])
        mid = lambda p: (-p[:-3] + 9 * p[1:-2] + 9 * p[2:-1] - p[3:]) / 16
        def weave(a, m):
            out = np.empty(2 * len(a) - 1, a.dtype); out[0::2] = a; out[1::2] = m
            return out
        return weave(x, mid(px)), weave(y, mid(py)), weave(h, 0.5 * (h[:-1] + h[1:]))

    def band(s, x, y, h, r, want_seg=False):
        """Bank distance for every texel within r of a channel's bank: the exact distance from the texel's centre
        to the centreline, less the half-width there, plus 0.5. So 0.5 is the bank, less is water, and it is 9
        (FAR) beyond r. Optionally also how far along the polyline the nearest point is. Each segment is drawn in
        the period that puts it on screen."""
        tex = s.tex
        hw = int(np.ceil((0.5 * 1.6 * s.ds + r + h.max()) * tex)) + 1
        mx = 0.5 * (x[:-1] + x[1:]); sh = (mx + s.pad) % s.L - s.pad - mx
        cx = np.floor((mx + sh) * tex).astype(np.int64); cy = np.floor(0.5 * (y[:-1] + y[1:]) * tex).astype(np.int64)
        keep = np.nonzero((cx >= -hw) & (cx < s.tw + hw) & (cy >= -hw) & (cy < s.th + hw))[0]
        P = 2 * hw  # padding, so no window needs clipping
        out = np.full((s.th + 2 * P, s.tw + 2 * P), FAR, np.float32)
        seg = np.zeros(out.shape, np.float32) if want_seg else None
        if len(keep):
            ax, ay, bx, by = (x[:-1] + sh)[keep], y[:-1][keep], (x[1:] + sh)[keep], y[1:][keep]
            ha, hb = h[:-1][keep][:, None, None], h[1:][keep][:, None, None]
            cx, cy = cx[keep], cy[keep]
            off = np.arange(-hw, hw + 1)
            gx = (cx[:, None, None] + off[None, None, :] + 0.5) / tex - ax[:, None, None]
            gy = (cy[:, None, None] + off[None, :, None] + 0.5) / tex - ay[:, None, None]
            ex, ey = (bx - ax)[:, None, None], (by - ay)[:, None, None]
            tt = np.clip((gx * ex + gy * ey) / (ex * ex + ey * ey + 1e-12), 0, 1)
            bd = (np.sqrt((gx - tt * ex) ** 2 + (gy - tt * ey) ** 2) - (ha + tt * (hb - ha)) + 0.5).astype(np.float32)
            for k in range(len(keep)):
                ys, xs = slice(cy[k] + hw, cy[k] + 3 * hw + 1), slice(cx[k] + hw, cx[k] + 3 * hw + 1)
                w = out[ys, xs]
                if want_seg: m = bd[k] < w; seg[ys, xs][m] = (keep[k] + tt[k])[m]
                np.minimum(w, bd[k], out=w)
        d = out[P:-P, P:-P]; d[d > 0.5 + r] = FAR
        return (d, seg[P:-P, P:-P]) if want_seg else d

    def stamp_now(s, crude=False):
        """Texels under the channel take the present time. A texel the bank is only part-way across takes that
        share of the way to the present, so the furthest line a bank reached is recorded to a fraction of a texel
        and old scarps come out smooth. (crude: just in or out, as a plain filled ribbon would stamp it; for the
        distant past made at launch.) The river also wipes any hollow it crosses and trims any lake."""
        d = s.band(*s.curve(*s.closed(), closed=True), 2.0 / s.tex)
        if crude:
            s.stamp[d < 0.5] = s.t
            cov = (d < 0.5).astype(np.float32)
        else:
            cov = np.clip(0.5 + (0.5 - d) * s.tex, 0, 1)
            full = cov >= 1
            s.stamp[full] = s.t
            rising = (cov > s.cov) & ~full
            old = np.maximum(s.stamp[rising], s.t - 400.0)
            s.stamp[rising] = old + (s.t - old) * (cov[rising] - s.cov[rising]) / (1 - s.cov[rising])
        np.maximum(s.hollow, 0.5 + 3 * (0.5 - d), out=s.hollow, where=d < 1)
        s.cov = cov
        s.trim_lakes(d)

    def make_lake(s, lx, ly, lh):
        """A cut-off loop becomes a lake: its own nodes and half-widths, drawn from then on by the same routine
        as the river, so on the cutoff frame the water is the same water. Its footprint is also kept as a hollow."""
        d = s.band(*s.curve(lx, ly, lh), 0.5)
        np.minimum(s.hollow, d, out=s.hollow)
        s.lakes.append(dict(x=lx, y=ly, h=lh, born=s.t, a=s.t, b=s.t))  # a, b: when each end became an end

    def lake_widths(s, k):
        """A lake's half-widths now. Each end silts up: a front moves in from it, quickly for the first 1.2 W (the
        plug), then at 0.25 W a T, with the water tapering to nothing over the 2 W ahead of it. Over the second half
        of its life the whole lake narrows to nothing. A dry stretch gets a negative width so nothing is drawn."""
        arc = np.concatenate([[0], np.cumsum(np.hypot(np.diff(k["x"]), np.diff(k["y"])))])
        def end(dist, since):
            age = s.t - since
            front = 3.2 * (1 - np.exp(-age / 0.6)) + 0.25 * age
            return smooth((dist - front) / 2.0 + 1, 0, 1)
        m = (1 - smooth(s.t - k["born"], 0.5 * s.lake_life, s.lake_life)) * end(arc, k["a"]) * end(arc[-1] - arc, k["b"])
        return k["h"] * m - 0.15 * (1 - m), m

    def trim_lakes(s, d):
        """Where the live channel has covered a lake's nodes, drop them: the lake ends at the outermost node still
        under the river (so its water runs into the river's and nothing shows), and a lake the river cuts through
        becomes two. A new end starts silting up from that moment. Dry and worn-out lakes are forgotten."""
        out = []
        for k in s.lakes:
            if s.t - k["born"] > s.lake_life: continue
            xm = (k["x"] + s.pad) % s.L - s.pad
            ix, iy = np.floor(xm * s.tex).astype(int), np.floor(k["y"] * s.tex).astype(int)
            on = (ix >= 0) & (ix < s.tw) & (iy >= 0) & (iy < s.th)
            cov = np.zeros(len(xm), bool); cov[on] = d[iy[on], ix[on]] < 0.5
            if not cov.any(): out.append(k); continue
            n = len(cov); i = 0
            while i < n:  # each run of nodes not under the river, with one covered node kept at either end of it
                if cov[i]: i += 1; continue
                j = i
                while j + 1 < n and not cov[j + 1]: j += 1
                lo, hi = max(i - 1, 0), min(j + 1, n - 1)
                if hi - lo >= 1:
                    out.append(dict(x=k["x"][lo:hi + 1], y=k["y"][lo:hi + 1], h=k["h"][lo:hi + 1], born=k["born"],
                                    a=k["a"] if lo == 0 else s.t, b=k["b"] if hi == n - 1 else s.t))
                    if lo != 0 or hi != n - 1: s.trims.append((s.t, float(xm[lo if lo != 0 else hi]), float(k["y"][lo if lo != 0 else hi]), s.t - k["born"]))
                i = j + 1
        s.lakes = out

    def water(s, r=0.5):
        """The one water field the shader reads: bank distance of the live channel or of any lake, whichever is less."""
        w = s.band(*s.curve(*s.closed(), closed=True), r)
        for k in s.lakes:
            if s.t - k["born"] > s.lake_life: continue
            h, m = s.lake_widths(k)
            if m.max() <= 0: continue
            np.minimum(w, s.band(*s.curve(k["x"], k["y"], h), r), out=w)
        return w

    def step(s, stamp_every=2, cut_every=2, crude=False):
        s.migrate()
        if s.steps % cut_every == 0: s.cutoff()
        s.resample()
        if s.fields and s.steps % stamp_every == 0: s.stamp_now(crude)

    # --- measurements ---------------------------------------------------------------------------------------------
    def stats(s):
        x, y, _ = s.closed()
        arc = np.hypot(np.diff(x), np.diff(y)).sum()
        _, _, _, curv = s.rates()
        c = np.convolve(np.tile(curv, 3), np.ones(5) / 5, "same")[len(curv):2 * len(curv)]
        bends = int(np.sum(np.sign(c) != np.sign(np.roll(c, 1))))
        return dict(T=round(s.t, 1), n=len(s.x), sinuosity=round(arc / s.L, 2), bends=bends,
                    wavelength=round(2 * s.L / max(bends, 1), 1), ymin=round(float(s.y.min()), 1), ymax=round(float(s.y.max()), 1),
                    cuts=s.ncut, peak=round(s.lastR[0], 3), mean=round(s.lastR[1], 3),
                    visited=round(float((s.stamp > -1e8).mean()), 3))

    def crossings(s):
        """How many times the centreline crosses itself: must stay 0."""
        x, y, _ = s.closed()
        ax, ay, bx, by = x[:-1], y[:-1], x[1:], y[1:]
        mid = np.c_[(ax + bx) / 2, (ay + by) / 2]
        pairs = cKDTree(mid).query_pairs(s.ds * 1.1, output_type="ndarray")
        if len(pairs): pairs = pairs[(np.abs(pairs[:, 1] - pairs[:, 0]) > 2) & (np.abs(pairs[:, 1] - pairs[:, 0]) < len(ax) - 2)]
        if not len(pairs): return 0
        i, j = pairs[:, 0], pairs[:, 1]
        def side(px, py, qx, qy, rx, ry): return (qx - px) * (ry - py) - (qy - py) * (rx - px)
        a = side(ax[i], ay[i], bx[i], by[i], ax[j], ay[j]) * side(ax[i], ay[i], bx[i], by[i], bx[j], by[j])
        b = side(ax[j], ay[j], bx[j], by[j], ax[i], ay[i]) * side(ax[j], ay[j], bx[j], by[j], bx[i], by[i])
        return int(np.sum((a < 0) & (b < 0)))


if __name__ == "__main__":
    # self-check: a short run grows bends, cuts some off, never crosses itself and stays in the valley
    r = River(seed=3, fields=False)
    for _ in range(6000): r.step()
    st = r.stats(); print(st, "crossings", r.crossings())
    assert st["cuts"] > 5 and st["sinuosity"] > 1.5 and r.crossings() == 0
    assert st["ymin"] > 0 and st["ymax"] < r.sy
    print("ok")
