"""Brute-force Schwarzschild ray tracer for Black Hole mock-ups (not the app's method: every ray is integrated).

Units: the Schwarzschild radius Rs = 1, c = 1. The disc lies in the plane y = 0 and turns about +y.
A light ray's path is exactly that of a particle under the force -1.5 h^2 x / r^5, with h = |x × v| conserved
(the Binet equation u'' + u = 1.5 u^2 in disguise), so the bending needs no approximation.
"""
import os
import numpy as np
from PIL import Image

DATA = os.environ.get("BH_DATA", "data")  # the star maps as raw float files; see ../black-hole.md

# Blackbody colours (sRGB, Mitchell Charity's table, rounded), K -> hex.
BB = [(1000, "ff3800"), (1500, "ff6d00"), (2000, "ff8912"), (2500, "ff9f46"), (3000, "ffb46b"), (3500, "ffc38a"),
      (4000, "ffd1a3"), (4500, "ffdbba"), (5000, "ffe4ce"), (5500, "ffede0"), (6000, "fff3ef"), (6600, "fffefa"),
      (7000, "f5f3ff"), (8000, "e3e9ff"), (10000, "ccdbff"), (15000, "b3ccff"), (20000, "a8c5ff"), (40000, "9bbcff")]
BB_T = np.array([t for t, _ in BB], dtype=np.float64)
BB_RGB = np.array([[int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)] for _, h in BB]) ** 2.2  # to linear


def blackbody(T):
    """Linear RGB hue of a blackbody at T kelvin (unit-ish brightness; below 1000 K it fades to deep red)."""
    lt = np.log(np.clip(T, 1000, 40000))
    out = np.stack([np.interp(lt, np.log(BB_T), BB_RGB[:, c]) for c in range(3)], axis=-1)
    cold = np.clip(T / 1000, 0, 1) ** 3
    return out * cold[..., None]


def disc_texture(seed, nr=384, nphi=2048):
    """Streaks drawn out along the orbit, in (log r, phi); periodic in phi. Values 0…1."""
    rng = np.random.default_rng(seed)
    fr = np.fft.fftfreq(nr)[:, None]
    fp = np.fft.fftfreq(nphi)[None, :]
    tex = np.zeros((nr, nphi))
    for sr, sphi, amp in [(14, 150, 1.0), (6, 70, 0.9), (3, 28, 0.6), (1.5, 10, 0.35)]:
        n = rng.standard_normal((nr, nphi))
        k = np.exp(-2 * np.pi ** 2 * ((fr * sr) ** 2 + (fp * sphi) ** 2))
        b = np.fft.ifft2(np.fft.fft2(n) * k).real
        tex += amp * b / b.std()
    tex /= tex.std()
    return (0.5 + 0.5 * np.tanh(tex * 0.9)).astype(np.float32)


_sky = {}


def sky_map(name):
    if name not in _sky:
        a = np.fromfile(f"{DATA}/{name}.raw", dtype=np.float32)
        h = int(round((a.size / 8) ** 0.5))
        _sky[name] = a.reshape(h, 2 * h, 4)[..., :3]
    return _sky[name]


def bilinear(img, u, v, wrap_u=True):
    h, w = img.shape[:2]
    u0 = np.floor(u).astype(np.int64)
    v0 = np.floor(v).astype(np.int64)
    fu = (u - u0)[..., None].astype(np.float32)
    fv = (v - v0)[..., None].astype(np.float32)
    u1 = u0 + 1
    if wrap_u:
        u0 %= w
        u1 %= w
    else:
        u0 = np.clip(u0, 0, w - 1)
        u1 = np.clip(u1, 0, w - 1)
    v1 = np.clip(v0 + 1, 0, h - 1)
    v0 = np.clip(v0, 0, h - 1)
    if img.ndim == 2:
        fu, fv = fu[..., 0], fv[..., 0]
    return (img[v0, u0] * (1 - fu) + img[v0, u1] * fu) * (1 - fv) + (img[v1, u0] * (1 - fu) + img[v1, u1] * fu) * fv


def rot(axis, deg):
    a = np.radians(deg)
    c, s = np.cos(a), np.sin(a)
    return {"x": np.array([[1, 0, 0], [0, c, -s], [0, s, c]]), "y": np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]]),
            "z": np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])}[axis]


def trace(W, H, incl=84.0, fov=40.0, D=40.0, centre=(0.5, 0.5), roll=0.0, r_in=3.0, r_out=11.0,
          sky="starmap_gal_4k", sky_rot=(35.0, -55.0, 12.0), ss=2, K=3, log=None):
    """Follows every ray once and keeps what it met: up to K crossings of the disc (radius, angle) and the sky
    colour it ends on. incl is degrees between the line of sight and the disc's axis (90 = edge on); fov is the
    horizontal field; centre is where the hole sits in the frame (0…1, from top left)."""
    w, h = W * ss, H * ss
    i = np.radians(incl)
    cam = D * np.array([0.0, np.cos(i), -np.sin(i)])
    f = -cam / D
    right = np.array([1.0, 0.0, 0.0])
    up = np.cross(f, right)
    basis = np.stack([right, up, f])
    if roll:
        cr, sr = np.cos(np.radians(roll)), np.sin(np.radians(roll))
        right, up = cr * right + sr * up, -sr * right + cr * up
    s = np.tan(np.radians(fov) / 2)
    px = ((np.arange(w) + 0.5) / w - centre[0]) * 2 * s
    py = (centre[1] - (np.arange(h) + 0.5) / h) * 2 * s * h / w
    d = f[None, None, :] + px[None, :, None] * right[None, None, :] + py[:, None, None] * up[None, None, :]
    d /= np.linalg.norm(d, axis=-1, keepdims=True)
    N = w * h
    v = d.reshape(N, 3).astype(np.float64)
    x = np.broadcast_to(cam, (N, 3)).copy()
    hv = np.cross(x, v)
    h2 = (hv * hv).sum(1)
    ell = (-hv[:, 1]).astype(np.float32)  # the photon's angular momentum about the disc's axis, on its way to us

    rr = np.zeros((N, K), dtype=np.float32)
    ph = np.zeros((N, K), dtype=np.float32)
    nhit = np.zeros(N, dtype=np.int8)
    skyc = np.zeros((N, 3), dtype=np.float32)
    idx = np.arange(N)
    R_esc = max(1.6 * D, 60.0)
    R = rot("y", sky_rot[1]) @ rot("x", sky_rot[2]) @ rot("z", sky_rot[0])

    def acc(x, h2):
        r2 = (x * x).sum(1)
        return (-1.5 * h2 / (r2 * r2 * np.sqrt(r2)))[:, None] * x

    for step in range(900):
        r = np.sqrt((x * x).sum(1))
        dt = np.clip(0.045 * r, 0.02, 4.0)[:, None]
        k1v = acc(x, h2); k1x = v
        k2v = acc(x + 0.5 * dt * k1x, h2); k2x = v + 0.5 * dt * k1v
        k3v = acc(x + 0.5 * dt * k2x, h2); k3x = v + 0.5 * dt * k2v
        k4v = acc(x + dt * k3x, h2); k4x = v + dt * k3v
        xn = x + dt / 6 * (k1x + 2 * k2x + 2 * k3x + k4x)
        v = v + dt / 6 * (k1v + 2 * k2v + 2 * k3v + k4v)
        cross = (x[:, 1] * xn[:, 1] < 0)
        if cross.any():
            c = np.nonzero(cross)[0]
            t = x[c, 1] / (x[c, 1] - xn[c, 1])
            p = x[c] + t[:, None] * (xn[c] - x[c])
            rad = np.sqrt(p[:, 0] ** 2 + p[:, 2] ** 2)
            gi = idx[c]
            ok = (rad > r_in) & (rad < r_out) & (nhit[gi] < K)
            gi, p, rad = gi[ok], p[ok], rad[ok]
            rr[gi, nhit[gi]] = rad
            ph[gi, nhit[gi]] = np.arctan2(p[:, 2], p[:, 0])
            nhit[gi] += 1
        x = xn
        r = np.sqrt((x * x).sum(1))
        fell = r < 1.01
        out = (r > R_esc) & ((x * v).sum(1) > 0)
        if out.any():
            o = np.nonzero(out)[0]
            dv = v[o] / np.linalg.norm(v[o], axis=1, keepdims=True)
            ds = (dv @ basis.T) @ R.T
            lon = np.arctan2(ds[:, 0], ds[:, 2])
            lat = np.arcsin(np.clip(ds[:, 1], -1, 1))
            m = sky_map(sky)
            skyc[idx[o]] = bilinear(m, (lon / (2 * np.pi) + 0.5) * m.shape[1], (0.5 - lat / np.pi) * (m.shape[0] - 1))
        done = fell | out
        if done.any():
            keep = ~done
            x, v, h2, idx = x[keep], v[keep], h2[keep], idx[keep]
        if idx.size == 0:
            break
        if log and step % 40 == 0:
            log(f"step {step}: {idx.size} rays left")
    return dict(W=W, H=H, ss=ss, rr=rr, ph=ph, ell=ell, sky=skyc, r_in=r_in, r_out=r_out)


_tex = {}


def shade(b, t=0.0, period=180.0, T_peak=3300.0, beam=4.0, spin=-1, exposure=2.2, sky_gain=0.35, sky_floor=0.006,
          bloom=1.0, seed=7, streak=0.65):
    """Paints a traced picture at time t (seconds). period is how long the disc's inner edge takes to go round;
    further out it turns as r^-1.5, as orbits do. T_peak is the hottest ring's temperature in kelvin."""
    W, H, ss, r_in, r_out = b["W"], b["H"], b["ss"], b["r_in"], b["r_out"]
    w, h = W * ss, H * ss
    if seed not in _tex:
        _tex[seed] = disc_texture(seed)
    tex = _tex[seed]
    N = b["ell"].size
    col = np.zeros((N, 3), dtype=np.float32)
    trans = np.ones(N, dtype=np.float32)
    lr0, lr1 = np.log(r_in * 0.98), np.log(r_out * 1.02)
    Fn = lambda r: r ** -3.0 * (1 - np.sqrt(r_in / r))
    Fmax = Fn(np.array(r_in * 49 / 36))
    for k in range(b["rr"].shape[1]):
        c = np.nonzero(b["rr"][:, k] > 0)[0]
        if not c.size:
            break
        rad = b["rr"][c, k].astype(np.float64)
        omega = np.sqrt(0.5 / rad ** 3)
        g = np.sqrt(1 - 1.5 / rad) / (1 - spin * omega * b["ell"][c])
        Te = (Fn(rad) / Fmax) ** 0.25  # 1 at the hottest ring
        turn = 2 * np.pi * t / period * (r_in / rad) ** 1.5
        u = ((b["ph"][c, k] + spin * turn + streak * np.log(rad) * 3.0) / (2 * np.pi) % 1.0) * tex.shape[1]
        vv = (np.log(rad) - lr0) / (lr1 - lr0) * (tex.shape[0] - 1)
        tx = bilinear(tex, u, vv)
        inten = (g * Te) ** beam * (0.42 + 0.9 * tx ** 1.4)
        hue = blackbody(g * Te * T_peak).astype(np.float32)
        edge_in = np.clip((rad - r_in) / 0.12, 0, 1)
        fade = np.clip((r_out - rad) / (0.42 * r_out), 0, 1) ** 1.5
        alpha = (edge_in * np.clip(fade * (1.6 + 1.2 * tx), 0, 1)).astype(np.float32)
        col[c] += (trans[c] * alpha)[:, None] * hue * inten[:, None].astype(np.float32)
        trans[c] *= 1 - alpha
    col += trans[:, None] * np.clip(b["sky"] - sky_floor, 0, None) * sky_gain
    img = col.reshape(h, w, 3).astype(np.float64)
    if bloom > 0:
        fy = np.fft.fftfreq(h)[:, None]
        fx = np.fft.rfftfreq(w)[None, :]
        F = np.fft.rfft2(img, axes=(0, 1))
        glow = np.zeros_like(img)
        for sig, amt in [(0.004 * w, 0.20), (0.016 * w, 0.10), (0.06 * w, 0.025)]:
            kk = np.exp(-2 * np.pi ** 2 * sig ** 2 * (fx ** 2 + fy ** 2))
            glow += amt * np.fft.irfft2(F * kk[..., None], s=(h, w), axes=(0, 1))
        img = img + bloom * np.clip(glow, 0, None)
    img = 1 - np.exp(-exposure * np.clip(img, 0, None))
    img = img.reshape(H, ss, W, ss, 3).mean(axis=(1, 3))
    return (np.clip(img, 0, 1) ** (1 / 2.2) * 255 + 0.5).astype(np.uint8)


TRACE_KEYS = ("incl", "fov", "D", "centre", "roll", "r_in", "r_out", "sky", "sky_rot", "ss", "K", "log")


def render(W, H, **kw):
    """Trace, then shade: the two halves of one picture."""
    tk = {k: kw.pop(k) for k in list(kw) if k in TRACE_KEYS}
    return shade(trace(W, H, **tk), **kw)


if __name__ == "__main__":
    import sys, time
    t = time.time()
    a = render(480, 300, log=lambda s: print(s, flush=True))
    Image.fromarray(a).save(sys.argv[1] if len(sys.argv) > 1 else "test.png")
    print("took", round(time.time() - t, 1), "s")
