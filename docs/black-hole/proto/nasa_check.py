"""Where the disc's images fall on the vertical line through the hole, by the table method, for a far camera:
in shadow radii (b / b_c), to set beside bh-look's measurements of NASA's frames and its schwarz.py predictions.
Disc 6 M to 30 M (r = 3 to 15 r_s). Run: python3 nasa_check.py"""
import numpy as np
from bhlib import *

T = Tables((256, 128), 1024, True, True)
BC = np.sqrt(27) / 2
U_OUT = 1 / 15.0

def spans(mask, x):
    """Runs of True in mask, as (start, end) in x."""
    edges = np.flatnonzero(np.diff(np.concatenate([[0], mask.astype(int), [0]])))
    return [(x[a], x[b - 1]) for a, b in zip(edges[::2], edges[1::2])]

def line(inc_deg, above):
    alpha = np.radians(90 + inc_deg if above else 90 - inc_deg)
    b = np.linspace(0.02, 7.0, 400001) * BC
    e2 = 1 / b ** 2
    esc = e2 < MU
    pha = T.lookup_phia(np.minimum(e2, MU))
    u0 = T.lookup_u(e2, np.full_like(b, alpha))
    ok0 = (alpha < phi_ub(e2)) & (~esc | (alpha < pha)) & (u0 <= U_IN) & (u0 >= U_OUT)
    s = 2 * pha - alpha
    psi1 = np.mod(s, np.pi); k = np.floor(s / np.pi)
    u1 = T.lookup_u(e2, psi1)
    ok1 = esc & (s > 0) & (psi1 < pha) & (psi1 < phi_ub(e2)) & (u1 <= U_IN) & (u1 >= U_OUT)
    out = [("first crossing", a, c) for a, c in spans(ok0, b / BC)]
    for kk in np.unique(k[ok1]):
        out += [(f"second crossing, {int(kk) + 1} half-turns", a, c) for a, c in spans(ok1 & (k == kk), b / BC)]
    return out

for inc in [0.0, 10.0, 56.0, 65.0, 85.0]:
    for above in (True, False):
        for name, a, c in line(inc, above):
            if c - a > 2e-4:
                print(f"inc {inc:4.0f}  {'above' if above else 'below'}  {name:32s} {a:.3f} to {c:.3f}  (width {c - a:.4f})")
