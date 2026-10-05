"""Horizon profiles for Live Sky's landscapes, from public-domain elevation data.

    python3 docs/live-sky/horizon.py <site> [...]     # sites are listed in SITES below; "all" runs every one

From the observer's point it walks outward along 4,801 bearings across the view and keeps the highest angle the
ground reaches on each, with the Earth's curve and standard refraction. It writes
Sources/Atrium/Resources/sky-<site>.txt: "azimuth-offset altitude" in degrees, one pair per line (offset 0 is the
centre of the view, which is 120 degrees across), simplified to 0.03 degrees. `Landscape` in LiveSky.swift draws it
through the sky's own projection. Look at it with:

    SNAPSHOT_DEFAULTS="sky.landscape=1,sky.ground=1" SNAPSHOT_SCENE="Live Sky" swift test

Data: USGS 3DEP (public domain) through the National Map's ImageServer for US sites, NASA SRTMGL1 v3 (public domain,
30 m: soft nearer than about 8 km and spiky in steep granite) from ESA's STEP mirror elsewhere. Both are cached in
$TMPDIR/atrium-dem. Needs numpy, scipy and Pillow.
"""
import math, os, sys, tempfile, urllib.request, zipfile
import numpy as np
from PIL import Image
from scipy.ndimage import map_coordinates

HERE = os.path.dirname(os.path.abspath(__file__))
DEM = os.path.join(tempfile.gettempdir(), 'atrium-dem')
OUT = os.path.join(HERE, '../../Sources/Atrium/Resources')
R = 6371000.0
AGENT = {'User-Agent': 'horizon-profile-script/0.1'}

# name: (lat, lon, eye height above ground m, centre azimuth deg, magnification, max distance km, source, note)
SITES = {
    'monument': (36.9820, -110.1121, 2, 85, 1.0, 30, '3dep', 'Monument Valley from the visitor centre, facing east'),
    'tetons':   (43.7513, -110.6237, 2, 268, 1.0, 45, '3dep', 'Teton Range from Snake River Overlook, facing west'),
    'shiprock': (36.7235, -108.8364, 2, 180, 1.0, 40, '3dep', 'Shiprock from 4 km north, facing south'),
    'tower':    (44.5729, -104.7011, 2, 331, 1.0, 25, '3dep', 'Devils Tower from 2.2 km south-east, facing north-west'),
    'fuji':     (35.5228, 138.7453, 2, 185, 1.0, 45, 'srtm', 'Mount Fuji from the north shore of Lake Kawaguchi, facing south'),
}

# Finer 3DEP squares over the features that make the skyline: site -> [(lat, lon, half-width km)], each 2000 px across
DETAIL = {
    'monument': [(36.9886, -110.0955, 1.0), (36.9873, -110.0687, 1.0), (36.9805, -110.0859, 1.0), (37.0090, -110.0990, 1.5)],
    'tetons':   [(43.7410, -110.8024, 5.0), (43.8350, -110.7760, 4.0), (43.6900, -110.8300, 5.0)],
    'shiprock': [(36.6875, -108.8364, 1.5)],
    'tower':    [(44.5902, -104.7146, 1.0)],
}

def fetch(url, path):
    if not os.path.exists(path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        for attempt in range(4):   # the National Map answers 502 now and then
            try:
                with urllib.request.urlopen(urllib.request.Request(url, headers=AGENT), timeout=180) as r:
                    data = r.read()
                break
            except Exception as e:
                if attempt == 3 or '404' in str(e): raise
                import time; time.sleep(8 * (attempt + 1))
        with open(path, 'wb') as f: f.write(data)
    return path

def dem_3dep(lat, lon, km):
    """A square of 3DEP about a point, 2000 px across (the service fails on larger requests and resamples its best
    data), so the caller asks for several sizes: fine near the observer, coarser far away. The image's height is
    2000 x cos(latitude): the service keeps pixels square in degrees and would otherwise quietly widen the box."""
    dlat = km * 1000 / R * 180 / math.pi
    dlon = dlat / math.cos(math.radians(lat))
    box = (lon - dlon, lat - dlat, lon + dlon, lat + dlat)
    rows = round(2000 * math.cos(math.radians(lat)))
    url = ('https://elevation.nationalmap.gov/arcgis/rest/services/3DEPElevation/ImageServer/exportImage?'
           f'bbox={box[0]},{box[1]},{box[2]},{box[3]}&bboxSR=4326&imageSR=4326&size=2000,{rows}&format=tiff&pixelType=F32'
           '&interpolation=RSP_BilinearInterpolation&f=image')
    a = np.asarray(Image.open(fetch(url, os.path.join(DEM, f'3dep_{lat:.4f}_{lon:.4f}_{km}.tif')))).astype(np.float32)
    return a, box  # row 0 is the north edge

def dem_srtm(lat, lon, km):
    """The SRTM tiles within reach of the observer, joined."""
    dlat = km * 1000 / R * 180 / math.pi
    dlon = dlat / math.cos(math.radians(lat))
    lats = range(math.floor(lat - dlat), math.floor(lat + dlat) + 1)
    lons = range(math.floor(lon - dlon), math.floor(lon + dlon) + 1)
    rows = []
    for la in reversed(lats):
        row = []
        for lo in lons:
            name = f"{'N' if la >= 0 else 'S'}{abs(la):02d}{'E' if lo >= 0 else 'W'}{abs(lo):03d}"
            try:
                z = zipfile.ZipFile(fetch(f'https://step.esa.int/auxdata/dem/SRTMGL1/{name}.SRTMGL1.hgt.zip',
                                          os.path.join(DEM, name + '.zip')))
                t = np.frombuffer(z.read(z.namelist()[0]), '>i2').reshape(3601, 3601).astype(np.float32)
            except Exception as e:  # sea tiles don't exist
                print('  no tile', name, e); t = np.zeros((3601, 3601), np.float32)
            row.append(t[:-1, :-1])
        rows.append(np.concatenate(row, 1))
    a = np.concatenate(rows, 0)
    a[a < -1000] = 0
    return a, (lons[0], lats[0], lons[-1] + 1, lats[-1] + 1)

def profile(site, n=4801):
    lat, lon, eye, centre, mag, km, source, _ = SITES[site]
    # (reach in km, elevation grid) from fine to coarse; each covers the distances the one before it doesn't
    levels = [(r, dem_3dep(lat, lon, r)) for r in (4, 14, km)] if source == '3dep' else [(km, dem_srtm(lat, lon, km))]
    def sampler(level):
        dem, (w, s, e, nn) = level
        H, W = dem.shape
        return lambda la, lo: map_coordinates(dem, [(nn - la) / (nn - s) * (H - 1), (lo - w) / (e - w) * (W - 1)],
                                              order=1, mode='nearest')
    h0 = float(sampler(levels[0][1])(np.array([lat]), np.array([lon]))[0]) + eye
    span = 120.0 / mag
    az = np.radians(centre + np.linspace(-span / 2, span / 2, n))
    best = np.full(n, -90.0)
    start = 40.0
    for reach, level in levels:
        sample = sampler(level)
        d = np.geomspace(start, reach * 1000 * 0.98, 1500)
        start = reach * 1000 * 0.98
        for chunk in np.array_split(np.arange(len(d)), 15):
            dd = d[chunk][None, :]
            la = lat + np.degrees(dd * np.cos(az[:, None]) / R)
            lo = lon + np.degrees(dd * np.sin(az[:, None]) / (R * math.cos(math.radians(lat))))
            h = sample(la, lo) - dd * dd / (2 * R) * (1 - 0.13)   # curvature, with standard refraction
            best = np.maximum(best, np.degrees(np.arctan2(h - h0, dd)).max(1))
    for dlat_, dlon_, half in DETAIL.get(site, []):
        dem, (w, s, e, nn) = dem_3dep(dlat_, dlon_, half)
        H, W = dem.shape
        dist = math.hypot((dlat_ - lat) * math.pi / 180 * R, (dlon_ - lon) * math.pi / 180 * R * math.cos(math.radians(lat)))
        d = np.arange(max(40.0, dist - half * 1500), dist + half * 1500, half * 1.5)   # steps of 1.5 grid cells
        for chunk in np.array_split(np.arange(len(d)), max(1, len(d) // 100)):
            dd = d[chunk][None, :]
            la = lat + np.degrees(dd * np.cos(az[:, None]) / R)
            lo = lon + np.degrees(dd * np.sin(az[:, None]) / (R * math.cos(math.radians(lat))))
            inside = (la > s) & (la < nn) & (lo > w) & (lo < e)
            h = map_coordinates(dem, [(nn - la) / (nn - s) * (H - 1), (lo - w) / (e - w) * (W - 1)], order=1, mode='nearest')
            h = np.where(inside, h - dd * dd / (2 * R) * (1 - 0.13), -1e9)
            best = np.maximum(best, np.degrees(np.arctan2(h - h0, dd)).max(1))
    offs = np.linspace(-60, 60, n)        # after magnification the view is always 120 degrees across
    return offs, np.maximum(best, 0) * mag, h0

def simplify(x, y, tol):
    """Ramer-Douglas-Peucker, iteratively."""
    keep = np.zeros(len(x), bool); keep[[0, -1]] = True
    stack = [(0, len(x) - 1)]
    while stack:
        a, b = stack.pop()
        if b - a < 2: continue
        t = (x[a + 1:b] - x[a]) / (x[b] - x[a])
        dev = np.abs(y[a + 1:b] - (y[a] + t * (y[b] - y[a])))
        i = int(dev.argmax())
        if dev[i] > tol:
            keep[a + 1 + i] = True
            stack += [(a, a + 1 + i), (a + 1 + i, b)]
    return x[keep], y[keep]

def main(names):
    for name in names:
        lat, lon, eye, centre, mag, km, source, note = SITES[name]
        print(name, '-', note)
        offs, alts, h0 = profile(name)
        x, y = simplify(offs, alts, 0.03)
        with open(os.path.join(OUT, f'sky-{name}.txt'), 'w') as f:
            f.write(f'# {note}\n# Observer {lat}, {lon} at {h0:.0f} m; centre azimuth {centre}; angles x{mag}.\n')
            f.write('# Source: ' + ('USGS 3DEP' if source == '3dep' else 'NASA SRTMGL1 v3') + ' (public domain).\n')
            f.write('# azimuth offset and altitude, degrees\n')
            f.writelines(f'{a:.2f} {b:.2f}\n' for a, b in zip(x, y))
        print(f'  eye {h0:.0f} m, highest {alts.max():.1f} deg at offset {offs[alts.argmax()]:.0f}, median {np.median(alts):.1f} deg,'
              f' {len(x)} points')

if __name__ == '__main__':
    main(list(SITES) if sys.argv[1:] == ['all'] else sys.argv[1:])
