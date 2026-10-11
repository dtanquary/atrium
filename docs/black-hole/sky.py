#!/usr/bin/env python3
"""Bakes Black Hole's sky into Sources/Atrium/Resources: the stars and the Milky Way's glow, both already turned
to the scene's own frame, so the app does no astronomy.

  blackhole-stars.lzfse   the HYG catalogue's stars from magnitude -1.5 to 11 (115,562 of them), then LZFSE.
                          Four runs, each one entry a star, the stars in order of latitude: longitude (2 bytes, low
                          first, 0...65535 for -180...180 degrees), latitude (2 bytes, -90...90), magnitude (1 byte,
                          -1.5...11) and B-V colour (1 byte, -0.4...2).
  blackhole-glow.heic     ESO's Milky Way panorama with its own stars taken out (they don't line up with the
                          catalogue's: docs/black-hole.md) and their light spread back as a haze, 2048 x 1024,
                          longitude across and latitude up, north at the top. Stored lighter than it is, as
                          value^0.6, so the dark sky keeps its steps; the shader undoes it.

The scene's frame: longitude 0, latitude 0 is straight through the hole from the camera, latitude is up the screen
and longitude runs to the right. The sky is turned as in the mock-up Dave picked (sheet 3, tile K: bh.py's
sky_rot = (35, -55, 12)), which puts the Milky Way's band down the right of the screen, with its bright centre
off screen beyond it (66 degrees right, 15 down).

From two sources, both credited in Resources/blackhole-credits.tsv and in Settings, About:
  stars  HYG v4.4, David Nash, CC BY-SA 4.0     https://codeberg.org/astronexus/hyg  (hyg_v44.csv)
  glow   ESO/S. Brunier, CC BY 4.0              https://www.eso.org/public/images/eso0932a/  (the 6000 x 3000 JPEG)
The baked star file is an adaptation of HYG and stays under CC BY-SA 4.0.

    python3 -I docs/black-hole/sky.py hyg_v44.csv eso0932a.jpg     (needs numpy and Pillow; half a minute)
"""
import csv, os, subprocess, sys, tempfile
import numpy as np
from PIL import Image, ImageFilter

Image.MAX_IMAGE_PIXELS = None
RESOURCES = os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../Sources/Atrium/Resources')
GALACTIC = np.array([[-0.0548755604, -0.8734370902, -0.4838350155],     # J2000 to galactic, as SkyMath.swift
                     [+0.4941094279, -0.4448296300, +0.7469822445],
                     [-0.8676661490, -0.1980763734, +0.4559837762]])


def rot(axis, deg):
    c, s = np.cos(np.radians(deg)), np.sin(np.radians(deg))
    return {'x': np.array([[1, 0, 0], [0, c, -s], [0, s, c]]), 'y': np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]]),
            'z': np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])}[axis]


# bh.py took a direction in the camera's frame (right, up, toward the hole) to its sky map by this turn, and read the
# map (galactic, longitude rising to the left) at longitude -atan2(x, z), latitude asin(y). Together: camera to galactic.
TURN = rot('y', -55) @ rot('x', 12) @ rot('z', 35)
TO_GALACTIC = np.array([[0, 0, 1], [-1, 0, 0], [0, 1, 0]]) @ TURN


def stars(path):
    rows = []
    for row in csv.DictReader(open(path)):
        try:
            ra, dec, mag = float(row['ra']) * 15, float(row['dec']), float(row['mag'])
        except ValueError:
            continue
        if -1.5 <= mag <= 11:
            rows.append((ra, dec, mag, float(row['ci']) if row['ci'] else 0.6))     # no colour measured: a sunlike one
    ra, dec, mag, colour = np.array(rows).T
    ra, dec = np.radians(ra), np.radians(dec)
    seen = np.stack([np.cos(dec) * np.cos(ra), np.cos(dec) * np.sin(ra), np.sin(dec)], 1) @ GALACTIC.T @ TO_GALACTIC
    lon, lat = np.arctan2(seen[:, 0], seen[:, 2]), np.arcsin(np.clip(seen[:, 1], -1, 1))
    order = np.argsort(lat, kind='stable')

    def steps(value, low, high, top):
        return np.clip(np.round((value[order] - low) / (high - low) * top), 0, top)
    packed = (steps(lon, -np.pi, np.pi, 65535).astype('<u2').tobytes() + steps(lat, -np.pi / 2, np.pi / 2, 65535).astype('<u2').tobytes()
              + steps(mag, -1.5, 11, 255).astype(np.uint8).tobytes() + steps(colour, -0.4, 2, 255).astype(np.uint8).tobytes())
    target = os.path.join(RESOURCES, 'blackhole-stars.lzfse')
    with tempfile.NamedTemporaryFile(suffix='.raw') as raw:
        raw.write(packed)
        raw.flush()
        subprocess.run(['/usr/bin/compression_tool', '-encode', '-a', 'lzfse', '-i', raw.name, '-o', target], check=True)
    print(f'{len(rows)} stars, {len(packed)} bytes, {os.path.getsize(target)} packed -> {target}')


def glow(path, wide=2048, high=1024):
    # An opening (the least of each 9 x 9 patch, then the most of those) takes out anything smaller than half a
    # degree, which is every star and none of the dust lanes; then a blur for the patches' square corners. What it
    # took out is the photo's stars. Their light belongs in the glow (away from the galaxy's centre the Milky Way
    # is nothing else), but not their places, so it goes back spread over a degree, the brightest held down first.
    pan = Image.open(path).convert('RGB')
    opened = pan.filter(ImageFilter.MinFilter(9)).filter(ImageFilter.MaxFilter(9))
    points = np.clip((np.asarray(pan, dtype=np.float32) - np.asarray(opened, dtype=np.float32)) / 255, 0, 0.5)
    h, w, _ = points.shape
    spread = np.exp(-2 * np.pi ** 2 * 15.0 ** 2 * (np.fft.fftfreq(h)[:, None] ** 2 + np.fft.rfftfreq(w)[None, :] ** 2))
    haze = np.fft.irfft2(np.fft.rfft2(points, axes=(0, 1)) * spread[..., None], s=(h, w), axes=(0, 1))
    a = np.asarray(opened.filter(ImageFilter.GaussianBlur(3)), dtype=np.float32) / 255 + np.clip(haze, 0, None).astype(np.float32)
    lon = ((np.arange(wide) + 0.5) / wide - 0.5) * 2 * np.pi
    lat = (0.5 - (np.arange(high) + 0.5) / high) * np.pi                      # the top row is straight up
    lon, lat = np.meshgrid(lon, lat)
    seen = np.stack([np.cos(lat) * np.sin(lon), np.sin(lat), np.cos(lat) * np.cos(lon)], -1) @ TO_GALACTIC.T
    x = (0.5 - np.arctan2(seen[..., 1], seen[..., 0]) / (2 * np.pi)) % 1 * w - 0.5    # the panorama: galactic longitude 0 in the middle, rising to the left
    y = np.clip((0.5 - np.arcsin(np.clip(seen[..., 2], -1, 1)) / np.pi) * h - 0.5, 0, h - 1.001)
    i, j = np.floor(x).astype(int), np.floor(y).astype(int)
    fx, fy = (x - i)[..., None], (y - j)[..., None]
    out = ((a[j, i % w] * (1 - fx) + a[j, (i + 1) % w] * fx) * (1 - fy) + (a[j + 1, i % w] * (1 - fx) + a[j + 1, (i + 1) % w] * fx) * fy)
    target = os.path.join(RESOURCES, 'blackhole-glow.heic')
    with tempfile.NamedTemporaryFile(suffix='.png') as png:
        Image.fromarray((np.clip(out, 0, 1) ** 0.6 * 255 + 0.5).astype(np.uint8)).save(png.name)
        subprocess.run(['/usr/bin/sips', '-s', 'format', 'heic', '-s', 'formatOptions', '80', png.name, '--out', target],
                       check=True, stdout=subprocess.DEVNULL)
    print(f'glow {wide} x {high}, {os.path.getsize(target)} bytes -> {target}')


if __name__ == '__main__':
    stars(sys.argv[1])
    glow(sys.argv[2])
