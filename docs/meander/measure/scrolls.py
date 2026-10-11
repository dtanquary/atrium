"""Ridge-and-swale spacing and relief along transects of a DEM (float TIFF, metres; pixel size given).
usage: python3 -I scrolls.py <dem.tif> <metres per px> x0,y0,x1,y1 [...]"""
import sys
import numpy as np
from PIL import Image
z = np.asarray(Image.open(sys.argv[1]), dtype=np.float32)
mpp = float(sys.argv[2])
for spec in sys.argv[3:]:
    x0, y0, x1, y1 = map(float, spec.split(","))
    n = int(np.hypot(x1 - x0, y1 - y0))
    xs, ys = np.linspace(x0, x1, n), np.linspace(y0, y1, n)
    p = z[ys.round().astype(int), xs.round().astype(int)]
    k = int(600 / mpp) | 1                                     # 600 m running mean = the bar's own slope
    trend = np.convolve(np.pad(p, k // 2, mode="edge"), np.ones(k) / k, mode="valid")
    r = p - trend
    ac = np.correlate(r, r, "full")[n - 1:] / (r @ r)
    peaks = [i for i in range(4, len(ac) - 1) if ac[i] > ac[i - 1] and ac[i] >= ac[i + 1] and ac[i] > 0.15]
    # crests and troughs: local extrema of the residual smoothed over 25 m
    s = np.convolve(r, np.ones(5) / 5, "same")
    ext = [i for i in range(1, n - 1) if (s[i] - s[i - 1]) * (s[i + 1] - s[i]) < 0]
    amps = np.abs(np.diff(s[ext])); amps = amps[amps > 0.15]
    crests = [i for i in ext if s[i] > s[i - 1]]
    print(f"transect {spec}: {n*mpp/1000:.1f} km, elevation {p.min():.1f}-{p.max():.1f} m, "
          f"residual std {r.std():.2f} m, crest-to-trough median {np.median(amps):.2f} m (90th pct {np.percentile(amps,90):.2f}), "
          f"autocorrelation peak at {[round(i*mpp) for i in peaks[:3]]} m, mean crest spacing {n*mpp/max(1,len(amps)/2):.0f} m")
