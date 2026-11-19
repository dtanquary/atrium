"""Fetches and bakes the ring profile mock.swift reads: python3 -I profile.py <empty download dir> [profile.tsv].

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


if __name__ == "__main__":
    folder = sys.argv[1]
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
