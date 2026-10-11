"""Table method against direct integration, pixel by pixel. Run: python3 compare.py [W]"""
import sys, time, numpy as np
from bhlib import *

W = int(sys.argv[1]) if len(sys.argv) > 1 else 480
H = W * 5 // 8
R_C, R_OUT, FOV = 50.0, 12.0, 40.0          # camera at 100 M, disc out to 24 M
px_per_rs = W / (2 * np.tan(np.radians(FOV / 2)) * R_C)     # screen pixels per r_s at the hole's distance
t0 = time.time(); T8 = Tables((128, 64), 512, eight_bit=True); print(f"bake: {time.time()-t0:.2f} s (numpy, pure-python RK4)")
variants = {"128x64+512, 8-bit packed, float32 maths": (T8, np.float32),
            "64x32+256, 8-bit packed, float32 maths": (Tables((64, 32), 256, True), np.float32),
            "128x64+512, float tables, float64 maths": (Tables((128, 64), 512, False), np.float64)}
for inc in [85.0, 75.0, 45.0, 15.0]:
    c, d = camera(W, H, FOV, inc, R_C)
    t0 = time.time(); ref = trace_reference(c, d, R_C, R_OUT); tr = time.time() - t0
    print(f"\n=== inclination {inc:.0f} deg, {W}x{H}, reference {tr:.0f} s; 1 px = {1/px_per_rs:.4f} r_s")
    for name, (T, f) in variants.items():
        t0 = time.time(); tab = trace_tables(c, d, R_C, R_OUT, T, f); tt = time.time() - t0
        # first hit (what an opaque disc shows)
        h_ref = ~np.isnan(ref["r"][..., 0]); h_tab = ~np.isnan(tab["r"][..., 0])
        both = h_ref & h_tab
        dr = np.abs(tab["r"][..., 0] - ref["r"][..., 0])[both]
        dp = np.linalg.norm(tab["p"][..., 0, :] - ref["p"][..., 0, :], axis=-1)[both]
        # sky direction where both escape and neither hit the disc
        sk = ref["escaped"] & tab["escaped"] & ~h_ref & ~h_tab
        ang = np.degrees(np.arccos(np.clip(np.sum(ref["sky"][sk] * tab["sky"][sk], axis=-1), -1, 1)))
        fate = (ref["captured"] != tab["captured"]).sum()
        # disagreement about hit / no hit happens only on edges: count them
        print(f"  {name}: {tt:.2f} s")
        print(f"    disc pixels {both.sum()}, hit/no-hit disagree {(h_ref != h_tab).sum()} px, captured disagree {fate} px")
        print(f"    radius error: median {np.median(dr):.2e}, 99% {np.percentile(dr,99):.2e}, max {dr.max():.2e} r_s"
              f"  | 3D point error: 99% {np.percentile(dp,99):.2e}, max {dp.max():.2e} r_s = {dp.max()*px_per_rs:.2f} px at this size")
        print(f"    sky direction error: median {np.median(ang)*60:.3f}', 99% {np.percentile(ang,99)*60:.2f}', max {ang.max()*60:.1f}' "
              f"(1 px = {FOV/W*60:.1f}')")
        if inc == 75.0 and f is np.float32 and T is T8:
            np.savez_compressed("cmp75.npz", ref_r=ref["r"], tab_r=tab["r"], ref_sky=ref["sky"], tab_sky=tab["sky"],
                                ref_p=ref["p"], tab_p=tab["p"], cap_ref=ref["captured"], cap_tab=tab["captured"])
