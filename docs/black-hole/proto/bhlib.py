"""Schwarzschild black hole: a brute-force ray tracer and the table method proposed for Atrium, side by side.

Units: the Schwarzschild radius r_s = 2GM/c^2 = 1, so M = 0.5, the horizon is r = 1, the photon sphere r = 1.5,
the ISCO r = 3 and the critical impact parameter b_c = sqrt(27)/2 = 2.598. u = 1/r.
World: hole at the origin, disc in the z = 0 plane turning anticlockwise about +z.

The reference integrates each pixel's ray in 3D with d2x/dl2 = -1.5 h^2 x / r^5 (the Binet-equation trick, as in
rantonels/starless), knowing nothing about tables. The table method uses two tables that depend on nothing but
the metric (after Bruneton 2020, arXiv:2010.08735): U(e, phi), the inverse radius along a ray from infinity, and
phiA(e), the angle from infinity to the ray's closest approach. Both are packed into 8-bit RGBA as SpriteKit needs.
"""
import numpy as np

MU = 4.0 / 27.0          # e^2 above this: the ray is captured
U_IN = 1.0 / 3.0         # ISCO
PI = np.pi


# ---------------------------------------------------------------- camera

def camera(W, H, fov_x_deg, inc_deg, r_c, look=(0.0, 0.0)):
    """Unit vector c from hole to camera, and each pixel's ray direction as a static observer there sees it.
    inc is the angle between the disc's axis and the line of sight (90 = edge-on). `look` shifts the hole off
    centre, in units of the half-width."""
    i = np.radians(inc_deg)
    c = np.array([np.sin(i), 0.0, np.cos(i)])
    f = -c
    right = np.cross(f, [0.0, 0.0, 1.0]); right /= np.linalg.norm(right)
    up = np.cross(right, f)
    t = np.tan(np.radians(fov_x_deg) / 2)
    xs = (np.arange(W) + 0.5) / W * 2 - 1
    ys = 1 - (np.arange(H) + 0.5) / H * 2
    X, Y = np.meshgrid(xs * t - look[0] * t, ys * t * H / W - look[1] * t)
    d = f[None, None, :] + X[..., None] * right + Y[..., None] * up
    d /= np.linalg.norm(d, axis=-1, keepdims=True)
    return c, d


def plane_basis(c, d):
    """The ray's orbital plane: x' = c, y' the part of d across it. Returns y', cos and sin of delta, the angle
    between the ray and the direction to the hole, and alpha in [0, pi), where the disc plane cuts this plane."""
    cosd = -(d @ c)
    perp = d + cosd[..., None] * c
    sind = np.linalg.norm(perp, axis=-1)
    yp = perp / np.maximum(sind, 1e-30)[..., None]
    alpha = np.mod(np.arctan2(-c[2], yp[..., 2]), PI)
    return yp, cosd, sind, alpha


# ---------------------------------------------------------------- reference: direct integration

def trace_reference(c, d, r_c, r_out, step=0.02, r_far=400.0, max_steps=6000):
    """Integrates every pixel's ray in 3D. Returns the first two disc-plane crossings inside [3, r_out] (radius and
    3D point), the escape direction, and whether the ray was captured."""
    shape = d.shape[:-1]
    n = int(np.prod(shape))
    u_c = 1.0 / r_c
    # A static observer's local direction, in coordinate components: the radial part shrinks by sqrt(1 - u).
    dl = d.reshape(n, 3)
    rad = dl @ c
    dc = dl + (np.sqrt(1 - u_c) - 1) * rad[:, None] * c
    dc /= np.linalg.norm(dc, axis=1, keepdims=True)
    x = np.tile(c * r_c, (n, 1))
    v = dc.copy()
    h2 = np.sum(np.cross(x, v) ** 2, axis=1)

    hits_r = np.full((n, 2), np.nan)
    hits_p = np.full((n, 2, 3), np.nan)
    nhit = np.zeros(n, int)
    escaped = np.zeros(n, bool)
    captured = np.zeros(n, bool)
    out_dir = np.full((n, 3), np.nan)
    alive = np.arange(n)

    def acc(x, h2):
        r2 = np.sum(x * x, axis=1)
        return -1.5 * (h2 / (r2 * r2 * np.sqrt(r2)))[:, None] * x

    for _ in range(max_steps):
        if alive.size == 0:
            break
        xa, va, ha = x[alive], v[alive], h2[alive]
        r = np.linalg.norm(xa, axis=1)
        dt = (step * r / np.linalg.norm(va, axis=1))[:, None]
        k1x, k1v = va, acc(xa, ha)
        k2x, k2v = va + 0.5 * dt * k1v, acc(xa + 0.5 * dt * k1x, ha)
        k3x, k3v = va + 0.5 * dt * k2v, acc(xa + 0.5 * dt * k2x, ha)
        k4x, k4v = va + dt * k3v, acc(xa + dt * k3x, ha)
        xn = xa + dt / 6 * (k1x + 2 * k2x + 2 * k3x + k4x)
        vn = va + dt / 6 * (k1v + 2 * k2v + 2 * k3v + k4v)
        # disc plane crossings, by a cubic through the step's ends
        cross = (xa[:, 2] * xn[:, 2] < 0) & (nhit[alive] < 2)
        if cross.any():
            idx = np.nonzero(cross)[0]
            z0, z1 = xa[idx, 2], xn[idx, 2]
            s = z0 / (z0 - z1)
            for _ in range(3):   # Newton on the Hermite cubic for z
                h00, h10 = 2 * s**3 - 3 * s**2 + 1, s**3 - 2 * s**2 + s
                h01, h11 = -2 * s**3 + 3 * s**2, s**3 - s**2
                m0, m1 = va[idx, 2] * dt[idx, 0], vn[idx, 2] * dt[idx, 0]
                z = h00 * z0 + h10 * m0 + h01 * z1 + h11 * m1
                dz = (6 * s**2 - 6 * s) * z0 + (3 * s**2 - 4 * s + 1) * m0 + (-6 * s**2 + 6 * s) * z1 + (3 * s**2 - 2 * s) * m1
                s = np.clip(s - z / dz, 0, 1)
            h00, h10 = 2 * s**3 - 3 * s**2 + 1, s**3 - 2 * s**2 + s
            h01, h11 = -2 * s**3 + 3 * s**2, s**3 - s**2
            p = (h00[:, None] * xa[idx] + h10[:, None] * va[idx] * dt[idx] + h01[:, None] * xn[idx] + h11[:, None] * vn[idx] * dt[idx])
            rp = np.linalg.norm(p, axis=1)
            ok = (rp >= 3.0) & (rp <= r_out)
            g = alive[idx[ok]]
            hits_r[g, nhit[g]] = rp[ok]
            hits_p[g, nhit[g]] = p[ok]
            nhit[g] += 1
        x[alive], v[alive] = xn, vn
        rn = np.linalg.norm(xn, axis=1)
        cap = rn < 1.02
        esc = (rn > r_far) & (np.sum(xn * vn, axis=1) > 0)
        captured[alive[cap]] = True
        escaped[alive[esc]] = True
        out_dir[alive[esc]] = vn[esc] / np.linalg.norm(vn[esc], axis=1, keepdims=True)
        alive = alive[~(cap | esc)]
    return dict(r=hits_r.reshape(shape + (2,)), p=hits_p.reshape(shape + (2, 3)), nhit=nhit.reshape(shape),
                escaped=escaped.reshape(shape), captured=captured.reshape(shape), sky=out_dir.reshape(shape + (3,)))


# ---------------------------------------------------------------- the tables

def phi_ub(e2):
    """Bruneton's upper bound on the angle a ray from infinity turns through before its closest approach or
    before it's inside r = 3, whichever comes first (functions.glsl, BSD-3-Clause)."""
    return (1 + e2) / (1.0 / 3.0 + 2 * e2 * np.sqrt(e2))


def _rk4_u(e, phis):
    """u(phi) for a ray from infinity (u = 0, du/dphi = e), at the angles `phis` (rising), from u'' = 1.5u^2 - u."""
    out = np.empty(len(phis))
    u, w, p = 0.0, e, 0.0
    f = lambda u: 1.5 * u * u - u
    for j, target in enumerate(phis):
        nsub = max(1, int(np.ceil((target - p) / 0.002)))
        hstep = (target - p) / nsub
        for _ in range(nsub):
            k1u, k1w = w, f(u)
            k2u, k2w = w + 0.5 * hstep * k1w, f(u + 0.5 * hstep * k1u)
            k3u, k3w = w + 0.5 * hstep * k2w, f(u + 0.5 * hstep * k2u)
            k4u, k4w = w + hstep * k3w, f(u + hstep * k3u)
            u += hstep / 6 * (k1u + 2 * k2u + 2 * k3u + k4u)
            w += hstep / 6 * (k1w + 2 * k2w + 2 * k3w + k4w)
            if u > 2.0:      # long since swallowed
                out[j:] = 2.0
                return out
        p = target
        out[j] = u
    return out


def u_apsis(e2):
    """Closest approach of a ray that escapes (Bruneton eq. 9): the smallest positive root of e^2 = u^2 (1 - u)."""
    return 1.0 / 3.0 + (2.0 / 3.0) * np.sin(np.arcsin(np.clip(2 * e2 / MU - 1, -1, 1)) / 3)


def phi_apsis(e2, n=4000):
    """Angle from infinity to closest approach, for e^2 < MU, by Gauss-Chebyshev-like substitution so the
    square-root singularity at the turning point integrates cleanly: u = ua sin(t)... done as u = ua (1 - s^2)."""
    e2 = np.atleast_1d(np.asarray(e2, float))
    ua = u_apsis(e2)
    # e^2 - u^2 + u^3 = (ua - u) * Q(u), Q = -(u^2 + (ua - 1) u + ua (ua - 1))  (divide out the root ua)
    s = (np.arange(n) + 0.5) / n                      # midpoint rule in s, u = ua (1 - s^2), du = -2 ua s ds
    u = ua[:, None] * (1 - s[None, :] ** 2)
    Q = -(u * u + (ua[:, None] - 1) * u + ua[:, None] * (ua[:, None] - 1))
    # du / sqrt((ua - u) Q) = 2 ua s ds / (sqrt(ua) s sqrt(Q)) = 2 sqrt(ua) ds / sqrt(Q)
    return np.sum(2 * np.sqrt(ua)[:, None] / np.sqrt(Q), axis=1) / n


# Table B's coordinate: 0 at the critical ray, 1 for a ray infinitely far out (Bruneton's stretch, halved range).
def xb_from_e2(e2):
    return 1 - 2 * np.sqrt(np.maximum(-np.log(np.maximum(1 - e2 / MU, 1e-30)), 0) / 50)

def e2_from_xb(xb):
    return MU * (1 - np.exp(-50 * ((1 - xb) / 2) ** 2))

PHIA_SCALE = 8.0     # table B stores (phiA - pi/2) / PHIA_SCALE
U_SCALE = 0.5        # table A stores min(u, U_SCALE) / U_SCALE


def bake(na=(128, 64), nb=512):
    """Table A: U(e, phi), na[0] across in x = 1/(1 + 6 e^2), na[1] up in y = phi / phi_ub(e).
    Table B: phiA(e) - pi/2, nb across. Returned as floats in 0...1 (texel centres at (i + 0.5)/n)."""
    wa, ha = na
    A = np.empty((ha, wa))
    y = np.arange(ha) / (ha - 1)
    for i in range(wa):
        x = i / (wa - 1)
        if x == 0:          # e infinite, a ray straight at the hole: u = e sin(phi) -> y / 2 in these coordinates
            A[:, i] = np.minimum(y * 0.5, U_SCALE) / U_SCALE
        elif x == 1:        # e = 0: a ray infinitely far out never comes near
            A[:, i] = 0
        else:
            e2 = (1 / x - 1) / 6
            A[:, i] = np.minimum(_rk4_u(np.sqrt(e2), y * phi_ub(e2)), U_SCALE) / U_SCALE
    xb = np.arange(nb) / (nb - 1)
    e2b = e2_from_xb(xb)
    B = (phi_apsis(np.minimum(e2b, MU * (1 - 1e-12))) - PI / 2) / PHIA_SCALE
    B[-1] = 0.0   # e = 0
    return A, np.clip(B, 0, 1)


def pack16(v):
    """A 0...1 value as two bytes that bilinear filtering can interpolate: the rounded byte, and the rounding
    error. Decode with hi + (lo - 0.5) / 255."""
    hi = np.round(v * 255)
    lo = np.round((v * 255 - hi + 0.5) * 255)
    return hi.astype(np.uint8), lo.astype(np.uint8)


def gpu_bilinear(tex, x, y=None):
    """What a GPU returns for an 8-bit texture at unit coordinates x (and y): texel centres at (i + 0.5)/n,
    clamped at the edges, weights held to 1/256 as most GPUs do."""
    t = tex.astype(float) / 255.0
    if y is None:
        n = t.shape[0]
        fx = np.clip(x * n - 0.5, 0, n - 1)
        i0 = np.minimum(np.floor(fx).astype(int), n - 2); w = np.round((fx - i0) * 256) / 256
        return t[i0] * (1 - w) + t[i0 + 1] * w
    hgt, wid = t.shape
    fx = np.clip(x * wid - 0.5, 0, wid - 1); fy = np.clip(y * hgt - 0.5, 0, hgt - 1)
    i0 = np.minimum(np.floor(fx).astype(int), wid - 2); j0 = np.minimum(np.floor(fy).astype(int), hgt - 2)
    wx = np.round((fx - i0) * 256) / 256; wy = np.round((fy - j0) * 256) / 256
    return (t[j0, i0] * (1 - wx) + t[j0, i0 + 1] * wx) * (1 - wy) + (t[j0 + 1, i0] * (1 - wx) + t[j0 + 1, i0 + 1] * wx) * wy


def pack24(v):
    """The same over three bytes, for the one value that needs it (the escape angle)."""
    hi = np.round(v * 255)
    mid = np.round((v * 255 - hi + 0.5) * 255)
    lo = np.round((((v * 255 - hi + 0.5) * 255 - mid) + 0.5) * 255)
    return hi.astype(np.uint8), mid.astype(np.uint8), lo.astype(np.uint8)


class Tables:
    def __init__(self, na=(128, 64), nb=512, eight_bit=True, b24=False):
        self.A, self.B = bake(na, nb)
        self.na, self.nb, self.eight_bit, self.b24 = na, nb, eight_bit, b24
        self.Ahi, self.Alo = pack16(self.A)
        self.Bhi, self.Blo = pack16(self.B)
        self.B3 = pack24(self.B)

    def unit(self, x, n):
        return (x * (n - 1) + 0.5) / n

    def lookup_u(self, e2, phi):
        x = self.unit(1 / (1 + 6 * e2), self.na[0])
        y = self.unit(np.clip(phi / phi_ub(e2), 0, 1), self.na[1])
        if self.eight_bit:
            v = gpu_bilinear(self.Ahi, x, y) + (gpu_bilinear(self.Alo, x, y) - 0.5) / 255
        else:
            v = _bilinear_float(self.A, x, y)
        return v * U_SCALE

    def lookup_phia(self, e2):
        x = self.unit(np.clip(xb_from_e2(e2), 0, 1), self.nb)
        if self.eight_bit and self.b24:
            v = gpu_bilinear(self.B3[0], x) + (gpu_bilinear(self.B3[1], x) - 0.5) / 255 + (gpu_bilinear(self.B3[2], x) - 0.5) / 65025
        elif self.eight_bit:
            v = gpu_bilinear(self.Bhi, x) + (gpu_bilinear(self.Blo, x) - 0.5) / 255
        else:
            n = self.nb
            fx = np.clip(x * n - 0.5, 0, n - 1); i0 = np.minimum(np.floor(fx).astype(int), n - 2); w = fx - i0
            v = self.B[i0] * (1 - w) + self.B[i0 + 1] * w
        return v * PHIA_SCALE + PI / 2


def _bilinear_float(t, x, y):
    hgt, wid = t.shape
    fx = np.clip(x * wid - 0.5, 0, wid - 1); fy = np.clip(y * hgt - 0.5, 0, hgt - 1)
    i0 = np.minimum(np.floor(fx).astype(int), wid - 2); j0 = np.minimum(np.floor(fy).astype(int), hgt - 2)
    wx = fx - i0; wy = fy - j0
    return (t[j0, i0] * (1 - wx) + t[j0, i0 + 1] * wx) * (1 - wy) + (t[j0 + 1, i0] * (1 - wx) + t[j0 + 1, i0 + 1] * wx) * wy


def phi_camera(e, u_c):
    """Angle from infinity to a camera at u_c along a ray of inverse impact parameter e, to first order in r_s
    (the camera is far out, where the field is weak): asin(u/e) less the bending already done."""
    s = np.sqrt(np.maximum(e * e - u_c * u_c, 1e-30))
    return np.arcsin(np.clip(u_c / e, -1, 1)) - 0.5 * ((2 * e * e - u_c * u_c) / s - 2 * e)


# ---------------------------------------------------------------- the table method (what the shader would do)

def trace_tables(c, d, r_c, r_out, T, dtype=np.float64):
    """Per pixel: three table lookups and closed forms. Same outputs as trace_reference. dtype=float32 runs the
    arithmetic as a GPU would."""
    f = dtype
    u_c = f(1.0 / r_c)
    yp, cosd, sind, alpha = plane_basis(c, d)
    yp, cosd, sind, alpha = yp.astype(f), cosd.astype(f), sind.astype(f), alpha.astype(f)
    e = u_c * np.sqrt(1 - u_c) / np.maximum(sind, f(1e-9))          # a static observer: b = r sin(delta) / sqrt(1 - u)
    e2 = e * e
    phc = phi_camera(e, u_c).astype(f)
    escapes = e2 < MU                                                 # (the camera looks inward: cos delta > 0)
    pha = T.lookup_phia(np.minimum(e2, MU)).astype(f)
    u_out = f(1.0 / r_out)

    # first crossing, on the way in: alpha from the camera, phc + alpha from infinity
    psi0 = phc + alpha
    u0 = T.lookup_u(e2, psi0)
    ok0 = (psi0 < phi_ub(e2)) & (~escapes | (psi0 < pha)) & (u0 <= U_IN) & (u0 >= u_out)
    # second, on the way out: mirrored about the closest approach
    span = 2 * pha - phc - alpha
    psi1 = np.mod(span, f(PI))
    k = np.floor(span / f(PI))
    u1 = T.lookup_u(e2, psi1)
    ok1 = escapes & (psi1 < pha) & (psi1 < phi_ub(e2)) & (u1 <= U_IN) & (u1 >= u_out) & (span > 0)
    # when the first crossing lies beyond the closest approach it is this same outward one (k = 0)

    def point(phi_hit, u):
        return (np.cos(phi_hit)[..., None] * c + np.sin(phi_hit)[..., None] * yp) / np.maximum(u, 1e-9)[..., None]

    r = np.full(d.shape[:-1] + (2,), np.nan); p = np.full(d.shape[:-1] + (2, 3), np.nan)
    p0, p1 = point(alpha, u0), point(alpha + k * PI, u1)
    first = np.where(ok0, 0, np.where(ok1, 1, -1))
    r[..., 0] = np.where(ok0, 1 / np.maximum(u0, 1e-9), np.where(ok1, 1 / np.maximum(u1, 1e-9), np.nan))
    p[..., 0, :] = np.where(ok0[..., None], p0, np.where(ok1[..., None], p1, np.nan))
    both = ok0 & ok1
    r[..., 1] = np.where(both, 1 / np.maximum(u1, 1e-9), np.nan)
    p[..., 1, :] = np.where(both[..., None], p1, np.nan)
    phi_inf = 2 * pha - phc
    sky = np.cos(phi_inf)[..., None] * c + np.sin(phi_inf)[..., None] * yp
    sky = np.where(escapes[..., None], sky, np.nan)
    return dict(r=r, p=p, nhit=ok0.astype(int) + ok1.astype(int), escaped=escapes, captured=~escapes, sky=sky,
                e=e, yp=yp, first=first, phi_inf=phi_inf)


# ---------------------------------------------------------------- disc physics, in closed form

def nt_flux(r):
    """Novikov-Thorne / Page-Thorne (1974) flux from a thin disc around a Schwarzschild hole, zero at the ISCO.
    r in r_s; x = sqrt(r/M). Shape only (peak normalised to 1 at r = 4.776 r_s = 9.55 M)."""
    x = np.sqrt(2 * np.maximum(r, 3.0))
    s3, s6 = np.sqrt(3.0), np.sqrt(6.0)
    br = x - s6 + (s3 / 2) * np.log((x + s3) * (s6 - s3) / ((x - s3) * (s6 + s3)))
    return np.maximum(br, 0) / (x ** 5 * (x * x - 3)) / 1.14591e-4


def redshift(r, e, cosn):
    """g = observed / emitted frequency for gas on a circular orbit at r, seen by a far static observer along a
    ray of inverse impact parameter e. cosn is the cosine between the photon's angular momentum and the disc's
    spin: +1 when the photon leaves along the gas's motion."""
    u = 1 / r
    return np.sqrt(1 - 1.5 * u) / (1 - np.sqrt(u ** 3 / 2) * cosn / e)
