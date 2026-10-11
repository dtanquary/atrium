"""Small numeric checks of the formulas the plan relies on. Run: python3 checks.py"""
import numpy as np
from bhlib import *
from bhlib import _rk4_u

# 1. phi_apsis against a straight RK4 march to the turning point
def phi_a_rk4(e2):
    e = np.sqrt(e2); u, w, p, h = 0.0, e, 0.0, 1e-4
    f = lambda u: 1.5*u*u - u
    while True:
        k1u,k1w = w, f(u); k2u,k2w = w+.5*h*k1w, f(u+.5*h*k1u); k3u,k3w = w+.5*h*k2w, f(u+.5*h*k2u); k4u,k4w = w+h*k3w, f(u+h*k3u)
        un = u + h/6*(k1u+2*k2u+2*k3u+k4u); wn = w + h/6*(k1w+2*k2w+2*k3w+k4w)
        if wn <= 0: return p + h * w/(w-wn)
        u, w, p = un, wn, p+h
for e2 in [1e-4, 0.01, 0.1, 0.14, MU*(1-1e-3), MU*(1-1e-5)]:
    print(f"e2={e2:.6g}  phiA quad={phi_apsis(e2)[0]:.6f}  rk4={phi_a_rk4(e2):.6f}  weak-field pi/2+e={np.pi/2+np.sqrt(e2):.6f}")

# strong-field limit (Darwin 1959): total bending = -ln(b/bc - 1) + ln(216 (7 - 4 sqrt3)) - pi
for eps in [1e-2, 1e-3, 1e-4]:
    b = np.sqrt(27)/2*(1+eps); e2 = 1/b**2
    print(f"b/bc-1={eps:g}: bending 2phiA-pi={2*phi_apsis(e2)[0]-np.pi:.5f}  Darwin log formula={-np.log(eps)+np.log(216*(7-4*np.sqrt(3)))-np.pi:.5f}")

# 2. on the critical ray, how far round is it by the time it's inside the ISCO?  (must be < pi for 'one crossing per leg')
e = np.sqrt(MU); phis = np.linspace(0, 4, 4001); us = _rk4_u(e, phis)
print("critical ray: phi at u=1/3:", phis[np.argmax(us >= 1/3)], " phi_ub there:", phi_ub(MU))
worst = 0
for e2 in np.geomspace(1e-3, 50, 200):
    us = _rk4_u(np.sqrt(e2), phis)
    ph13 = phis[np.argmax(us >= 1/3)] if (us >= 1/3).any() else np.inf
    pa = phi_apsis(e2)[0] if e2 < MU else np.inf
    worst = max(worst, min(ph13, pa) / phi_ub(e2))
print("max of min(phi_1/3, phiA)/phi_ub over e:", worst, "(must be <= 1)")

# 3. camera angle closed form vs RK4
for r_c in [30, 60, 100, 300]:
    u_c = 1/r_c; errs = []
    for delta in np.radians([1, 3, 10, 20, 35]):
        e = u_c*np.sqrt(1-u_c)/np.sin(delta)
        # march from infinity until u reaches u_c
        u, w, p, h = 0.0, e, 0.0, 1e-5
        f = lambda u: 1.5*u*u - u
        while u < u_c:
            k1u,k1w = w, f(u); k2u,k2w = w+.5*h*k1w, f(u+.5*h*k1u); k3u,k3w = w+.5*h*k2w, f(u+.5*h*k2u); k4u,k4w = w+h*k3w, f(u+h*k3u)
            up = u; pp = p
            u += h/6*(k1u+2*k2u+2*k3u+k4u); w += h/6*(k1w+2*k2w+2*k3w+k4w); p += h
        exact = pp + (u_c-up)/(u-up)*h
        errs.append(abs(phi_camera(e, u_c)-exact))
    print(f"r_c={r_c} r_s: closed-form phi_camera max error {max(errs):.2e} rad over delta 1..35 deg")

# 4. Novikov-Thorne: closed form against Page & Thorne's integral  f ~ -dOmega/dr (E - Omega L)^-2 Int (E - Omega L) dL/dr dr
M = 0.5
def EL(r):
    E = (1-2*M/r)/np.sqrt(1-3*M/r); L = np.sqrt(M*r)/np.sqrt(1-3*M/r); Om = np.sqrt(M/r**3); return E, L, Om
rs = np.linspace(3, 60, 200001)
E, L, Om = EL(rs)
dL = np.gradient(L, rs); dOm = np.gradient(Om, rs)
integ = np.concatenate([[0], np.cumsum(0.5*(((E-Om*L)*dL)[1:]+((E-Om*L)*dL)[:-1])*np.diff(rs))])
F = -dOm/(E-Om*L)**2*integ/rs       # /r from the metric determinant in the disc plane
F /= F.max()
closed = nt_flux(rs); 
print("NT closed form vs integral, max abs diff of normalised profiles:", np.abs(closed/closed.max()-F).max(), " peak at r =", rs[np.argmax(closed)], "r_s =", 2*rs[np.argmax(closed)], "M; nt_flux max", closed.max())
# with Luminet's printed sqrt(3)/3 coefficient instead of sqrt(3)/2:
x = np.sqrt(2*rs); s3, s6 = np.sqrt(3), np.sqrt(6)
alt = (x - s6 + (s3/3)*np.log((x+s3)*(s6-s3)/((x-s3)*(s6+s3))))/(x**5*(x*x-3)); 
print("  with sqrt(3)/3: min value", alt.min(), "(negative = wrong), max diff", np.abs(alt/alt.max()-F).max())
