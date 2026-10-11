"""How far off is Beloborodov's closed form (ApJ 566 L85, 2002) for the disc's direct image? For a far camera,
a ray of impact parameter b meets the disc plane where the radius vector makes angle psi with the line of sight:
  r(psi) = sqrt(rs^2 (1-cos psi)^2 / (4 (1+cos psi)^2) + b^2 / sin^2 psi) - rs (1-cos psi) / (2 (1+cos psi))
Compared here with the exact ray, u'' = 1.5u^2 - u from infinity (r_s = 1). Run: python3 beloborodov.py"""
import numpy as np
from bhlib import _rk4_u, phi_apsis, MU

def exact_r(b, psis):
    e = 1 / b
    out = np.full(len(psis), np.nan)
    if e * e < MU:
        pa = phi_apsis(e * e)[0]
        inb = psis <= pa
        if inb.any(): out[inb] = _rk4_u(e, psis[inb])
        outb = ~inb & (2 * pa - psis > 0)
        if outb.any():
            m = (2 * pa - psis[outb])[::-1]
            out[outb] = _rk4_u(e, m)[::-1]
    else:
        out = _rk4_u(e, psis)
    with np.errstate(divide='ignore'): return 1 / out

psis = np.radians(np.arange(5, 176, 1.0))
print(" psi   worst |dr|/r over rays that meet the disc (3..15 r_s) there      worst dr in r_s")
rows = {}
for b in np.concatenate([np.linspace(0.3, 2.59, 30), np.linspace(2.6, 16, 120)]):
    r = exact_r(b, psis)
    c = np.cos(psis); rb = np.sqrt((1 - c) ** 2 / (4 * (1 + c) ** 2) + b * b / np.sin(psis) ** 2) - (1 - c) / (2 * (1 + c))
    ok = (r >= 3) & (r <= 15)
    for p, a, bb, o in zip(psis, r, rb, ok):
        if o: rows.setdefault(int(round(np.degrees(p) / 15)) * 15, []).append((abs(bb - a) / a, abs(bb - a)))
for k in sorted(rows):
    a = np.array(rows[k]); print(f"{k:4d}   {a[:,0].max():7.2%}                                                  {a[:,1].max():.3f}")
