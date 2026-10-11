"""Stills by the table method, written the way the shader would work: per pixel, table lookups and closed forms.

  python3 render.py compare           the same plain shading from the reference and from the tables, and their difference
  python3 render.py beauty [inc] [t]  disc (Novikov-Thorne, black body, Doppler), catalogue stars through the lens, glow

Everything lands in out/. Units as bhlib: r_s = 1.
"""
import sys, os, numpy as np
from PIL import Image
from bhlib import *

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out"); os.makedirs(OUT, exist_ok=True)
STARS = os.path.join(os.path.dirname(__file__), "../../../Sources/Atrium/Resources/stars.txt")
PANORAMA = os.path.join(HERE, "downloads/eso0932a/eso0932a-large.jpg")
GAL = np.array([[-0.0548755604, -0.8734370902, -0.4838350155], [0.4941094279, -0.4448296300, 0.7469822445],
                [-0.8676661490, -0.1980763734, 0.4559837762]])   # J2000 -> galactic (SkyMath.swift)


def save(name, rgb):
    Image.fromarray((np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, name))
    print("wrote", os.path.join(OUT, name))


# ---------------------------------------------------------------- black body colour, as a 1D table

def blackbody_lut(n=256, t0=800.0, t1=40000.0):
    """sRGB-linear colour of a black body, each scaled so its largest channel is 1, for log-spaced temperatures;
    and its luminance over the Planck function at 555 nm (smooth, near constant). CIE 1931 matching functions
    from Wyman, Sloan & Shirley 2013 (JCGT 2(2), the multi-lobe Gaussian fit)."""
    lam = np.arange(380.0, 781.0, 2.0)
    def gs(x, mu, s1, s2): return np.exp(-0.5 * ((x - mu) / np.where(x < mu, s1, s2)) ** 2)
    xb = 1.056 * gs(lam, 599.8, 37.9, 31.0) + 0.362 * gs(lam, 442.0, 16.0, 26.7) - 0.065 * gs(lam, 501.1, 20.4, 26.2)
    yb = 0.821 * gs(lam, 568.8, 46.9, 40.5) + 0.286 * gs(lam, 530.9, 16.3, 31.1)
    zb = 1.217 * gs(lam, 437.0, 11.8, 36.0) + 0.681 * gs(lam, 459.0, 26.0, 13.8)
    T = np.geomspace(t0, t1, n)
    B = 1 / (lam[None, :] ** 5 * (np.exp(1.4388e7 / (lam[None, :] * T[:, None])) - 1))     # lambda in nm
    XYZ = np.stack([(B * xb).sum(1), (B * yb).sum(1), (B * zb).sum(1)], 1)
    M = np.array([[3.2406, -1.5372, -0.4986], [-0.9689, 1.8758, 0.0415], [0.0557, -0.2040, 1.0570]])
    rgb = np.maximum(XYZ @ M.T, 0)
    rgb /= rgb.max(axis=1, keepdims=True)
    return T, rgb


LUT_T, LUT_RGB = blackbody_lut()

def blackbody(T):
    """Colour (max channel 1) and brightness of a black body at T kelvin: brightness is the Planck function at
    555 nm, normalised to 1 at 6500 K. One table fetch and one exp in the shader."""
    x = np.clip(np.log(np.maximum(T, 1) / LUT_T[0]) / np.log(LUT_T[-1] / LUT_T[0]), 0, 1) * (len(LUT_T) - 1)
    i = np.minimum(x.astype(int), len(LUT_T) - 2); f = (x - i)[..., None]
    col = LUT_RGB[i] * (1 - f) + LUT_RGB[i + 1] * f
    lum = (np.exp(25924.0 / 6500.0) - 1) / (np.exp(np.minimum(25924.0 / np.maximum(T, 1), 80)) - 1)
    return col, lum


# ---------------------------------------------------------------- tileable noise, standing in for CloudNoise.texture

def tile_noise(n=256, seed=3):
    rng = np.random.default_rng(seed)
    out = np.zeros((n, n)); amp = 0.5
    for period in (8, 16, 32, 64):
        g = rng.random((period, period))
        idx = np.arange(n) * period / n
        i0 = idx.astype(int); f = idx - i0; f = f * f * (3 - 2 * f); i1 = (i0 + 1) % period
        rowsA = g[i0][:, i0] * (1 - f)[None, :] + g[i0][:, i1] * f[None, :]
        rowsB = g[i1][:, i0] * (1 - f)[None, :] + g[i1][:, i1] * f[None, :]
        out += amp * (rowsA * (1 - f)[:, None] + rowsB * f[:, None]); amp *= 0.5
    return out / 0.9375

NOISE = tile_noise()

def noise_at(u, v):
    n = NOISE.shape[0]
    x = (u % 1) * n; y = (v % 1) * n
    i0 = x.astype(int) % n; j0 = y.astype(int) % n; fx = x - np.floor(x); fy = y - np.floor(y)
    i1 = (i0 + 1) % n; j1 = (j0 + 1) % n
    return (NOISE[j0, i0] * (1 - fx) + NOISE[j0, i1] * fx) * (1 - fy) + (NOISE[j1, i0] * (1 - fx) + NOISE[j1, i1] * fx) * fy


def disc_texture(r, az, t, rings_per_fold=9.0):
    """Gas lanes that shear for ever without winding up: the disc is cut into narrow rings, evenly in log r. Each
    turns rigidly at its own Kepler rate, and a point takes the pattern of the two rings it lies between, mixed by
    where it sits. Neighbours slide past each other; nothing is ever stretched. t in r_s/c."""
    rho = rings_per_fold * np.log(np.maximum(r, 3.0) / 3.0)
    i = np.floor(rho); f = rho - i; f = f * f * (3 - 2 * f)
    def ring(k):
        rk = 3.0 * np.exp((k + 0.5) / rings_per_fold)
        turn = az - np.sqrt(0.5 / rk ** 3) * t            # Omega = sqrt(M / r^3), M = 1/2
        u = turn / (2 * np.pi)
        return 0.6 * noise_at(u * 3 + k * 0.37, rho * 0.11 + 0.5) + 0.4 * noise_at(u * 11 + k * 0.61, rho * 0.37)
    return ring(i) * (1 - f) + ring(i + 1) * f


# ---------------------------------------------------------------- the sky: catalogue stars in a grid, and a glow map

def star_grid(R, nx=1024, ny=512):
    """The catalogue as a texture: an equirectangular grid in the scene's frame (pole on the disc's axis), each
    cell holding at most its brightest star: where it sits in the cell (2 bytes), brightness and colour.
    R turns J2000 directions into the scene's frame."""
    rows = [l.split() for l in open(STARS) if not l.startswith('#')]
    ra, dec, v, bv = np.array(rows, float).T
    ra, dec = np.radians(ra), np.radians(dec)
    s = np.stack([np.cos(dec) * np.cos(ra), np.cos(dec) * np.sin(ra), np.sin(dec)], 1) @ R.T
    lon = np.arctan2(s[:, 1], s[:, 0]); lat = np.arcsin(np.clip(s[:, 2], -1, 1))
    gx = (lon / (2 * np.pi) + 0.5) * nx; gy = (lat / np.pi + 0.5) * ny
    grid = np.zeros((ny, nx, 4))      # fx, fy, flux, b-v
    order = np.argsort(-v)            # brightest written last, so it wins a shared cell
    ix = np.minimum(gx[order].astype(int), nx - 1); iy = np.minimum(gy[order].astype(int), ny - 1)
    grid[iy, ix, 0] = gx[order] - ix; grid[iy, ix, 1] = gy[order] - iy
    grid[iy, ix, 2] = 10 ** (-0.4 * (v[order] - 2.0)); grid[iy, ix, 3] = bv[order]
    lost = len(v) - (grid[..., 2] > 0).sum()
    return grid, lost


def bv_colour(bv):
    t = 4600 * (1 / (0.92 * bv + 1.7) + 1 / (0.92 * bv + 0.62))      # Ballesteros 2012
    return blackbody(t)[0]


def stars_through_lens(sky, k_r, k_t, e_r, e_t, grid, focal_px, size_px=0.9):
    """Each pixel looks up the 2x2 grid cells round its own sky direction and draws any star there as a round
    point on screen: the offset to the star on the sky, divided by the lens's stretch along and across the ring
    (k_r, k_t: sky angle per screen angle), is how far away its image is on screen. Brightness times the
    magnification 1 / |k_r k_t|."""
    ny, nx, _ = grid.shape
    lon = np.arctan2(sky[..., 1], sky[..., 0]); lat = np.arcsin(np.clip(sky[..., 2], -1, 1))
    gx = (lon / (2 * np.pi) + 0.5) * nx - 0.5; gy = (lat / np.pi + 0.5) * ny - 0.5
    ix0 = np.floor(gx).astype(int); iy0 = np.floor(gy).astype(int)
    mag = np.minimum(1 / np.maximum(np.abs(k_r * k_t), 1e-6), 40.0)
    out = np.zeros(sky.shape)
    for dy in (0, 1):
        for dx in (0, 1):
            cx = (ix0 + dx) % nx; cy = np.clip(iy0 + dy, 0, ny - 1)
            cell = grid[cy, cx]
            has = cell[..., 2] > 0
            slon = ((cx + cell[..., 0]) / nx - 0.5) * 2 * np.pi; slat = ((cy + cell[..., 1]) / ny - 0.5) * np.pi
            star = np.stack([np.cos(slat) * np.cos(slon), np.cos(slat) * np.sin(slon), np.sin(slat)], -1)
            d = star - sky
            a = np.sum(d * e_r, -1) / k_r; b = np.sum(d * e_t, -1) / np.where(np.abs(k_t) < 1e-6, 1e-6, k_t)
            dist = np.hypot(a, b) * focal_px
            flux = cell[..., 2] * mag
            rad = size_px * (1 + 0.35 * np.log1p(flux))                    # brighter stars a little wider
            light = flux * (np.exp(-(dist / rad) ** 2) + 0.02 * np.exp(-dist / (3 * rad)))
            out += np.where(has, light, 0)[..., None] * bv_colour(cell[..., 3])
    return out


def glow_map(R, w=1024):
    """The Milky Way's glow from ESO's panorama, shrunk and blurred until its own stars are gone. Its geometry is
    only roughly galactic-equirectangular (see panorama_check.py), which is all a glow needs."""
    Image.MAX_IMAGE_PIXELS = None
    im = Image.open(PANORAMA).convert('RGB').resize((w, w // 2), Image.BOX)
    a = (np.asarray(im).astype(float) / 255) ** 2.2
    k = np.exp(-0.5 * (np.arange(-6, 7) / 2.5) ** 2); k /= k.sum()
    a = sum(np.roll(a, i - 6, axis=1) * k[i] for i in range(13))
    a = sum(np.roll(a, i - 6, axis=0) * k[i] for i in range(13))
    return a


def sample_glow(gmap, sky, R):
    g = sky @ (GAL @ R.T).T                                   # scene -> J2000 -> galactic
    l = np.arctan2(g[..., 1], g[..., 0]); b = np.arcsin(np.clip(g[..., 2], -1, 1))
    h, w, _ = gmap.shape
    x = ((0.5 - l / (2 * np.pi)) % 1) * w - 0.5; y = np.clip((0.5 - b / np.pi) * h - 0.5, 0, h - 1.001)
    i0 = np.floor(x).astype(int); fx = (x - i0)[..., None]; j0 = np.floor(y).astype(int); fy = (y - j0)[..., None]
    return ((gmap[j0, i0 % w] * (1 - fx) + gmap[j0, (i0 + 1) % w] * fx) * (1 - fy)
            + (gmap[j0 + 1, i0 % w] * (1 - fx) + gmap[j0 + 1, (i0 + 1) % w] * fx) * fy)


def rot(axis, deg):
    a = np.radians(deg); c, s = np.cos(a), np.sin(a)
    return {"x": np.array([[1, 0, 0], [0, c, -s], [0, s, c]]), "y": np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]]),
            "z": np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])}[axis]


# ---------------------------------------------------------------- stills

def compare(W=960):
    H = W * 5 // 8; R_C, R_OUT, FOV, INC = 50.0, 12.0, 40.0, 78.0
    c, d = camera(W, H, FOV, INC, R_C)
    ref = trace_reference(c, d, R_C, R_OUT)
    tab = trace_tables(c, d, R_C, R_OUT, Tables((256, 128), 1024, True, True), np.float32)
    def plain(tr):
        r = tr["r"][..., 0]; p = tr["p"][..., 0, :]
        az = np.arctan2(p[..., 1], p[..., 0])
        disc = 0.25 + 0.75 * ((np.floor(r * 1.5) + np.floor(az / (np.pi / 12))) % 2)       # a checkerboard in r and azimuth
        s = tr["sky"]; lon = np.arctan2(s[..., 1], s[..., 0]); lat = np.arcsin(np.clip(s[..., 2], -1, 1))
        grid = 0.12 + 0.3 * ((np.floor(np.degrees(lon) / 5) + np.floor(np.degrees(lat) / 5)) % 2)
        img = np.where(np.isnan(r), np.where(tr["escaped"], grid, 0.0), disc)
        return np.nan_to_num(img)
    a, b = plain(ref), plain(tab)
    save("compare-reference.png", np.repeat(a[..., None], 3, -1))
    save("compare-tables.png", np.repeat(b[..., None], 3, -1))
    diff = np.abs(a - b)
    save("compare-difference.png", np.repeat(np.minimum(diff * 2, 1)[..., None], 3, -1))
    print(f"pixels that differ at all: {(diff > 0.01).sum()} of {W * H} ({(diff > 0.01).mean():.2%}): edges of checks only")


def beauty(inc=78.0, t=0.0, W=1512, tag=""):
    H = W * 982 // 1512
    R_C, R_OUT, FOV = 40.0, 14.0, 50.0                       # camera 80 M out, disc to 28 M, 50 degrees across
    T_PEAK = 6500.0                                          # hottest ring of the disc, kelvin, before any shift
    c, d = camera(W, H, FOV, inc, R_C, look=(0.0, 0.03))
    T = Tables((256, 128), 1024, True, True)
    tr = trace_tables(c, d, R_C, R_OUT * 1.15, T, np.float32)
    focal_px = W / (2 * np.tan(np.radians(FOV / 2)))
    yp, cosd, sind, alpha = plane_basis(c, d)
    e = tr["e"].astype(float)
    # the lens's stretch, for stars: along the ring by a finite difference of the escape angle, across it in closed form
    def phi_inf(sin_delta):
        u_c = 1 / R_C; ee = u_c * np.sqrt(1 - u_c) / sin_delta
        return 2 * T.lookup_phia(np.minimum(ee * ee, MU)) - phi_camera(ee, u_c)
    delta = np.arcsin(np.clip(sind, 1e-9, 1)); h = 2e-4
    k_r = (phi_inf(np.sin(delta + h)) - phi_inf(np.sin(delta - h))) / (2 * h)
    pin = tr["phi_inf"].astype(float)
    k_t = np.sin(pin) / np.maximum(sind, 1e-9)
    e_r = -np.sin(pin)[..., None] * c + np.cos(pin)[..., None] * yp
    e_t = np.cross(np.broadcast_to(c, yp.shape), yp)

    # sky: glow, catalogue stars, then (not here) a hashed faint field
    R = rot("z", 200.0) @ rot("x", 62.0)                     # where the scene's axis points on the real sky
    sky = np.nan_to_num(tr["sky"].astype(float))
    grid, lost = star_grid(R)
    skycol = 4.0 * sample_glow(glow_map(R), sky, R) + 0.6 * stars_through_lens(sky, k_r, k_t, e_r, e_t, grid, focal_px)
    skycol = np.where(tr["escaped"][..., None], skycol, 0.0)

    # disc: both crossings, front to back
    cosn = np.cross(yp, np.broadcast_to(c, yp.shape))[..., 2]        # photon's angular momentum against the spin axis
    def layer(k):
        r = tr["r"][..., k]; p = tr["p"][..., k, :]
        hit = ~np.isnan(r); r = np.where(hit, r, 5.0)
        g = redshift(r, e, cosn)
        temp = g * T_PEAK * nt_flux(r) ** 0.25
        col, lum = blackbody(temp)
        mu = np.clip(g * np.sqrt(np.maximum(1 - cosn ** 2, 0)) / (e * r), 0, 1)      # cosine of the angle it left the disc at
        limb = (3.0 / 7.0) * (1 + 2 * mu)                                             # an electron-scattering atmosphere
        tex = disc_texture(r, np.arctan2(p[..., 1], p[..., 0]), t)
        light = col * (lum * limb * (0.15 + 1.7 * tex * tex))[..., None]
        alpha_ = np.where(hit, np.clip((R_OUT * 1.15 - r) / (R_OUT * 0.3), 0, 1) * np.clip((r - 3.0) / 0.25, 0, 1), 0.0)
        return np.nan_to_num(light), alpha_
    l0, a0 = layer(0); l1, a1 = layer(1)
    lin = l0 * a0[..., None] + (1 - a0[..., None]) * (l1 * a1[..., None] + (1 - a1[..., None]) * skycol)

    # glow: the picture at an eighth of the size, blurred wide, added back (the app would bake this once per view)
    small = lin[:H // 8 * 8, :W // 8 * 8].reshape(H // 8, 8, W // 8, 8, 3).mean(axis=(1, 3))
    def blur(a, sig):
        n = int(3 * sig); k = np.exp(-0.5 * (np.arange(-n, n + 1) / sig) ** 2); k /= k.sum()
        pad = np.pad(a, ((n, n), (0, 0), (0, 0)), mode='edge'); a = sum(pad[i:i + a.shape[0]] * k[i] for i in range(2 * n + 1))
        pad = np.pad(a, ((0, 0), (n, n), (0, 0)), mode='edge'); return sum(pad[:, i:i + a.shape[1]] * k[i] for i in range(2 * n + 1))
    halo = 0.6 * blur(small, 1.5) + 0.4 * blur(small, 6.0)
    halo = np.asarray(Image.fromarray((np.clip(halo / halo.max(), 0, 1) * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC)).astype(float) / 255 * halo.max()
    lin = lin + 0.18 * halo

    # Galaxy's stretch: asinh on brightness, colour kept, highlights paling
    x = lin * 0.25
    lum = x @ np.array([0.3, 0.5, 0.2]) + 1e-4
    st = np.arcsinh(20 * lum) / np.arcsinh(240)
    photo = np.minimum(x * (st / lum)[..., None], 1)
    out = photo * (1 - 0.5 * np.clip((st - 0.55) / 0.45, 0, 1))[..., None] + (0.5 * np.clip((st - 0.55) / 0.45, 0, 1) * st)[..., None]
    save(f"beauty-inc{inc:.0f}-t{t:.0f}{tag}.png", out)
    print(f"  catalogue stars lost to shared grid cells: {lost}; disc pixels {int((a0 > 0).sum())}; second-image-only pixels {int(((a0 == 0) & (a1 > 0)).sum())}")


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "compare"
    if what == "compare":
        compare()
    else:
        beauty(float(sys.argv[2]) if len(sys.argv) > 2 else 78.0, float(sys.argv[3]) if len(sys.argv) > 3 else 0.0,
               int(sys.argv[4]) if len(sys.argv) > 4 else 1512)
