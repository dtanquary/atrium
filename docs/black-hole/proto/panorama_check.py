"""Is ESO's Milky Way panorama (eso0932a, ESO/S. Brunier, CC BY 4.0) a plain equirectangular map in galactic
coordinates, and where is its zero? Sum the photo's brightness where the catalogue's stars (V < 4) should fall,
over a range of shifts and x scales; a sharp peak says the map is right and gives the calibration.
Run: python3 -I panorama_check.py <panorama.jpg> <stars.txt>"""
import sys, numpy as np
from PIL import Image
Image.MAX_IMAGE_PIXELS = None
lum = np.asarray(Image.open(sys.argv[1]).convert('L'), dtype=np.float32) / 255
H, W = lum.shape
rows = [l.split() for l in open(sys.argv[2]) if not l.startswith('#')]
ra, dec, v, bv = np.array(rows, float).T
ra, dec = np.radians(ra), np.radians(dec)
eq = np.stack([np.cos(dec) * np.cos(ra), np.cos(dec) * np.sin(ra), np.sin(dec)], 1)
G = np.array([[-0.0548755604, -0.8734370902, -0.4838350155], [0.4941094279, -0.4448296300, 0.7469822445],
              [-0.8676661490, -0.1980763734, 0.4559837762]])      # J2000 -> galactic, as SkyMath.swift
g = eq @ G.T
l, b = np.arctan2(g[:, 1], g[:, 0]), np.arcsin(g[:, 2])
sel = (v < 4.0) & (np.abs(b) < np.radians(60))
def score(sign, dx, dy):
    x = np.round((0.5 - sign * l[sel] / (2 * np.pi)) * W + dx).astype(int) % W
    y = np.clip(np.round((0.5 - b[sel] / np.pi) * H + dy).astype(int), 0, H - 1)
    return lum[y, x].mean()
for sign, name in [(1, "l rising to the left"), (-1, "mirrored (control)")]:
    best = (0, 0, 0)
    grid = np.zeros((81, 161))
    for j, dy in enumerate(range(-80, 81, 2)):
        for i, dx in enumerate(range(-160, 161, 2)):
            grid[j, i] = score(sign, dx, dy)
            if grid[j, i] > best[0]: best = (grid[j, i], dx, dy)
    print(f"{name}: peak {best[0]:.3f} at shift ({best[1]}, {best[2]}) px of {W} = ({best[1]*360/W:.2f}, {best[2]*180/H:.2f}) deg; "
          f"background {np.median(grid):.3f}, next-best far from the peak {np.sort(grid.ravel())[-40]:.3f}")
    if sign == 1: bx, by = best[1], best[2]
# refine to 1 px and see how many stars then sit on a bright pixel
best = max(((score(1, dx, dy), dx, dy) for dy in range(by - 3, by + 4) for dx in range(bx - 3, bx + 4)))
x = np.round((0.5 - l[sel] / (2 * np.pi)) * W + best[1]).astype(int) % W
y = np.clip(np.round((0.5 - b[sel] / np.pi) * H + best[2]).astype(int), 0, H - 1)
on = np.array([lum[max(yy - 2, 0):yy + 3, max(xx - 2, 0):xx + 3].max() > 0.5 for xx, yy in zip(x, y)])
print(f"refined shift ({best[1]}, {best[2]}) px: {on.sum()} of {sel.sum()} stars have a bright pixel within 2 px (0.12 deg)")
# does the fit hold across the map, or drift (a different projection)? compare thirds in longitude
for lo, hi in [(-180, -60), (-60, 60), (60, 180)]:
    part = (np.degrees(l[sel]) >= lo) & (np.degrees(l[sel]) < hi)
    print(f"  l {lo:+d}..{hi:+d}: {on[part].mean():.0%} of {part.sum()}")
for lo, hi in [(-60, -20), (-20, 20), (20, 60)]:
    part = (np.degrees(b[sel]) >= lo) & (np.degrees(b[sel]) < hi)
    print(f"  b {lo:+d}..{hi:+d}: {on[part].mean():.0%} of {part.sum()}")
