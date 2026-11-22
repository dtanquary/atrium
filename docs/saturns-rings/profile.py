"""Fetches and bakes the ring profile mock.swift reads: python3 -I profile.py <empty download dir> [profile.tsv].
With --fine it bakes the A ring every km instead, for the close views (below): python3 -I profile.py <dir> --fine [out.bin].

Two real radial profiles of Saturn's main rings, both from the PDS Ring-Moon Systems Node:
- optical depth: Cassini UVIS's occultation of beta Centauri, 2008-231, 10 km bins (volume COUVIS_8001),
  clamped to the most the star could show and zeroed where it is only noise (outside the rings, F ring kept);
- the particles' brightness (albedo times phase function): Voyager 2's lit-face I/F (volume VG_2810, clear filter,
  phase 47 deg, incidence 81.95, emission 66.7) divided by what the single-scattering slab predicts from that tau at
  Voyager's geometry. Where tau is too thin to say, it takes its neighbours' value.
Writes radius (km), tau and albedo every 8 km from 72,000 to 142,000 km, with a header naming the sources. Both are
NASA mission data: NASA SPD-41a puts mission data in the public domain (CC0).
"""
import os, sys, urllib.request
import numpy as np

UVIS = "https://pds-rings.seti.org/holdings/volumes/COUVIS_8xxx/COUVIS_8001/data/UVIS_HSP_2008_231_BETCEN_I_TAU10KM.TAB"
VGR = "https://pds-rings.seti.org/holdings/volumes/VG_28xx/VG_2810/DATA/IS2_P0001_V01_KM010.TAB"
STEP, LO, HI = 8.0, 72000.0, 142000.0
# The A ring every km, where the close views draw finer than 8 km a pixel: the same occultation's 1 km file and
# Voyager 2's same profile sampled every 2 km (5 km resolution), 16,384 samples (Metal's widest texture) from 121,500 km,
# in the Cassini division, to 137,883 km, past the A ring's edge.
UVIS1 = "https://pds-rings.seti.org/holdings/volumes/COUVIS_8xxx/COUVIS_8001/data/UVIS_HSP_2008_231_BETCEN_I_TAU01KM.TAB"
VGR2 = "https://pds-rings.seti.org/holdings/volumes/VG_28xx/VG_2810/DATA/IS2_P0001_V01_KM002.TAB"
FINE_LO, FINE_N = 121500.0, 16384
SMOOTH = [1, 2, 1]


def fetch(url, folder):
    path = os.path.join(folder, url.rsplit("/", 1)[1])
    if not os.path.exists(path):
        req = urllib.request.Request(url, headers={"User-Agent": "profile-baker"})
        with urllib.request.urlopen(req) as r, open(path, "wb") as f:
            f.write(r.read())
    return path


def rows(path):
    return np.array([[float(x) for x in line.split(",")] for line in open(path) if line.strip()])


def bake(folder):
    u = rows(fetch(UVIS, folder))  # radius, longitude, phi, signal, tau, most tau, ...
    v = rows(fetch(VGR, folder))   # radius, I/F, pixel count
    r = np.arange(LO, HI + STEP / 2, STEP)
    tau = np.interp(r, u[:, 0], np.clip(np.minimum(u[:, 4], u[:, 5]), 0, None), left=0, right=0)
    # Noise: the star's tau wanders +-0.005 where there is no ring. Zero it outside the main rings and the F ring's
    # core, and below 0.01 anywhere beyond the A ring.
    rings = ((r > 74400) & (r < 136800)) | ((r > 139900) & (r < 140550))
    tau = np.where(rings, tau, 0.0)
    tau = np.where((r > 136800) & (tau < 0.01), 0.0, tau)
    # Voyager's radii against Cassini's: the shift that best lines up the brightness with the slab's prediction
    mu0, mu = np.cos(np.radians(81.95)), np.cos(np.radians(66.7))
    slab = mu0 / (mu + mu0) * (1 - np.exp(-tau * (1 / mu + 1 / mu0)))
    best = max(range(-60, 61, 2), key=lambda s: np.corrcoef(np.interp(r, v[:, 0] + s, v[:, 1]), slab)[0, 1])
    iof = np.interp(r, v[:, 0] + best, v[:, 1], left=0, right=0)
    alb = np.where(slab > 0.01, iof / np.maximum(slab, 1e-6), np.nan)
    alb = np.clip(alb, 0, 1.2)
    # thin places take the median of their neighbours within 400 km; the F ring (beyond Voyager's profile) the A ring's edge
    ok = ~np.isnan(alb)
    for i in np.where(~ok)[0]:
        near = alb[max(0, i - 50):i + 51]
        near = near[~np.isnan(near)]
        alb[i] = np.median(near) if len(near) else np.nan
    alb = np.where(np.isnan(alb), np.nanmedian(alb[(r > 130000) & (r < 136000)]), alb)
    return r, tau, alb, best


def running(x, n, f):
    """f (np.mean, np.median) of x over n samples centred on each (n odd), the ends padded with their own values."""
    pad = np.pad(x, n // 2, mode="edge")
    return f(np.lib.stride_tricks.sliding_window_view(pad, n), axis=1)


def fine(folder, smooth):
    """The A ring every km: radius, tau, brightness, and Voyager's shift.

    - tau is the 1 km file's, clamped as the 8 km profile's is. From one sample to the next it wanders by 0.12 on 0.6 in
      the A ring, twenty times the star's own noise (0.005): the star crossed a kilometre of clumped ring (its
      self-gravity wakes, a hundred metres apart) on a track a few tens of metres wide, and a camera's pixel averages
      far more of the ring than that. So tau is smoothed over `smooth` (weights, in transmission at the star's own
      slant, as the 10 km bins are): the real grooves stay, at about the contrast a picture would show.
    - Where its 9 km median is under 0.006 it is the star's noise in a gap, and zero (the Encke gap's ringlet, 0.01 to
      0.02 by its outer edge, stays); past the A ring's edge it is zero.
    - The Keeler gap's outer edge is moved in 2 km, to 136,519.5 km, so the gap lies inside the one the wallpaper draws
      from its own edges while Daphnis is in view (136,486.5 to 136,521.5 km), and no second edge shows beside it.
    - The brightness is Voyager's 2 km profile over the slab's prediction from tau smoothed to its 5 km, as the 8 km
      profile's is from its 10 km.
    """
    u = rows(fetch(UVIS1, folder))
    v = rows(fetch(VGR2, folder))
    r = FINE_LO + np.arange(FINE_N)
    raw = np.interp(r, u[:, 0], np.clip(np.minimum(u[:, 4], u[:, 5]), 0, None))
    slant = 1 / np.cos(np.radians(23.3))  # the star's light came in 23.3 degrees off the rings' normal (the file's label)
    pad = np.pad(np.exp(-raw * slant), len(smooth) // 2, mode="edge")
    tau = -np.log(np.convolve(pad, np.array(smooth) / sum(smooth), mode="valid")) / slant
    tau = np.where(running(raw, 9, np.median) < 0.006, 0.0, tau)
    tau = np.where(r > 136766, 0.0, tau)
    keeler = (r >= 136520) & (r <= 136522)
    tau[keeler] = tau[r == 136523][0]
    mu0, mu = np.cos(np.radians(81.95)), np.cos(np.radians(66.7))
    def slab(t):
        return mu0 / (mu + mu0) * (1 - np.exp(-t * (1 / mu + 1 / mu0)))
    seen = running(slab(tau), 5, np.mean)  # what Voyager's 5 km would have seen of it
    best = max(range(-60, 61), key=lambda s: np.corrcoef(np.interp(r, v[:, 0] + s, v[:, 1]), seen)[0, 1])
    iof = np.interp(r, v[:, 0] + best, v[:, 1], left=0, right=0)
    alb = np.clip(iof / np.maximum(seen, 1e-6), 0, 1.2)
    # thin places (a gap, its ringlets) and the 12 km either side of one, where the two profiles' blur differs, take the
    # median of their neighbours within 400 km
    alb[running(slab(tau), 25, np.min) < 0.05] = np.nan
    for i in np.where(np.isnan(alb))[0]:
        near = alb[max(0, i - 400):i + 401]
        near = near[~np.isnan(near)]
        alb[i] = np.median(near) if len(near) else np.nan
    alb = np.where(np.isnan(alb), np.nanmedian(alb[(r > 130000) & (r < 136000)]), alb)
    return r, tau, alb, best, raw


if __name__ == "__main__":
    folder = sys.argv[1]
    if "--fine" in sys.argv:
        # Two bytes each, low byte first, sample by sample: tau in ten-thousandths, then the brightness in fifty-thousandths.
        # The sources are the 8 km profile's (its header has the licence): the wallpaper's doc and SaturnsRings.swift name them.
        rest = [a for a in sys.argv[2:] if a != "--fine"]
        out = rest[0] if rest else os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../Sources/Atrium/Resources/saturn-rings-fine.bin")
        r, tau, alb, shift, raw = fine(folder, SMOOTH)
        packed = np.stack([np.clip(tau * 10000, 0, 65535), np.clip(alb * 50000, 0, 65535)], axis=1).round().astype("<u2")
        open(out, "wb").write(packed.tobytes())
        a = (r > 128000) & (r < 133000)
        print("fine rows", len(r), "voyager shift", shift, "km; A ring tau mean", tau[a].mean(), "its step-to-step sd", np.diff(tau[a]).std(),
              "(raw", np.diff(raw[a]).std(), "); albedo median", np.median(alb[a]), "sd", alb[a].std())
        sys.exit(0)
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "profile.tsv")
    r, tau, alb, shift = bake(folder)
    with open(out, "w") as f:
        f.write("# Saturn's main rings, every 8 km: radius (km), normal optical depth, particle brightness (ϖ0·P/4).\n")
        f.write("# tau: Cassini UVIS HSP occultation of beta Cen, 2008-231, 10 km bins, volume COUVIS_8001, PDS Ring-Moon Systems Node:\n")
        f.write(f"#   {UVIS}\n")
        f.write("# brightness: Voyager 2 ISS lit-face I/F, clear filter, 10 km, volume VG_2810, divided by the single-scattering slab's\n")
        f.write(f"#   prediction from tau at Voyager's geometry (Voyager radii shifted {shift:+d} km to match): {VGR}\n")
        f.write("# Licence: NASA mission data, public domain (NASA SPD-41a, footnote 29: \"Mission data are released into the public domain\";\n")
        f.write("#   https://science.nasa.gov/wp-content/uploads/2023/08/smd-information-policy-spd-41a.pdf). Made by profile.py.\n")
        for a, b, c in zip(r, tau, alb):
            f.write(f"{a:.0f}\t{b:.4f}\t{c:.4f}\n")
    print("rows", len(r), "voyager shift", shift, "km; albedo B ring median", np.median(alb[(r > 100000) & (r < 115000)]),
          "A", np.median(alb[(r > 123000) & (r < 133000)]), "C", np.median(alb[(r > 76000) & (r < 90000)]))
