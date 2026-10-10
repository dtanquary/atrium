#!/usr/bin/env python3
"""Bakes Pixel Window Seat's map of the Earth for its orbit mode: Sources/Atrium/Resources/orbit-earth.lzfse.

One byte for every 4.9 km of the Earth between 73 degrees north and south (the station never sees past 72):
what the ground is made of in its low five bits, and how brightly it is lit at night in its high three.
8192 bytes a row, 3322 rows, the first along 73 N, each starting at 180 W; then LZFSE.

From two NASA maps, both public domain:
  day    Blue Marble Next Generation with topography and bathymetry, September 2004, 21600 x 10800
         https://eoimages.gsfc.nasa.gov/images/imagerecords/73000/73801/world.topo.bathy.200409.3x21600x10800.jpg
  night  Black Marble 2016, 3 km, 13500 x 6750
         https://eoimages.gsfc.nasa.gov/images/imagerecords/144000/144898/BlackMarble_2016_3km.jpg

    python3 -I docs/pixel-window-seat/earth.py day.jpg night.jpg     (needs numpy and Pillow)
"""
import os, subprocess, sys, tempfile
import numpy as np
from PIL import Image

Image.MAX_IMAGE_PIXELS = None
WIDE, HIGH, EDGE = 8192, 4096, 73

# The Blue Marble's own colour for each kind of land, sampled at known places, and the material it becomes
# (`Ground` in PixelOrbit.swift, in this order after the four waters).
GROUND = ['deep', 'sea', 'shelf', 'shallows', 'sand', 'dune', 'ochre', 'redRock', 'steppe', 'scrub', 'pasture', 'grass',
          'woods', 'pine', 'forest', 'rock', 'firn', 'snow']
LAND = [((209, 180, 136), 'sand'), ((197, 167, 122), 'sand'), ((176, 134, 95), 'ochre'), ((150, 120, 84), 'dune'),
        ((141, 119, 79), 'steppe'), ((103, 68, 43), 'redRock'), ((112, 96, 62), 'scrub'), ((108, 90, 56), 'scrub'),
        ((76, 71, 40), 'pasture'), ((61, 64, 31), 'grass'), ((53, 58, 26), 'grass'), ((40, 44, 18), 'woods'), ((32, 35, 13), 'pine'),
        ((27, 42, 11), 'forest'), ((252, 253, 255), 'snow'), ((200, 205, 215), 'firn'), ((150, 150, 150), 'rock'), ((95, 92, 85), 'rock')]


def ground(rgb):
    """Blue Marble colours to materials: water by how blue it is and how deep its shading, land by its nearest sample."""
    r, g, b = (rgb[..., i].astype(np.int16) for i in range(3))
    water = np.where(b < 50, 0, np.where(b < 104, 1, np.where(g < 0.72 * b, 2, 3)))
    centres = np.array([c for c, _ in LAND], dtype=np.float32)
    kinds = np.array([GROUND.index(k) for _, k in LAND], dtype=np.uint8)
    land = kinds[((rgb[..., None, :].astype(np.float32) - centres) ** 2).sum(axis=-1).argmin(axis=-1)]
    return np.where((b > r + 12) & (b >= g), water, land).astype(np.uint8)


def lamps(rgb):
    """Black Marble colours to eight steps of light. Its unlit land is a dim blue, brightest on sand and ice, which
    is not a lamp: a light is warm, or white."""
    r, b = rgb[..., 0].astype(np.float32), rgb[..., 2].astype(np.float32)
    return np.rint(np.clip(np.maximum((r - b + 5) / 60, (r - 90) / 150), 0, 1) * 7).astype(np.uint8)


if __name__ == '__main__':
    day, night = sys.argv[1], sys.argv[2]
    top = round((90 - EDGE) / 180 * HIGH)
    rows = slice(top, HIGH - top)
    out = np.empty((HIGH - 2 * top, WIDE), dtype=np.uint8)
    d = np.asarray(Image.open(day).convert('RGB').resize((WIDE, HIGH), Image.LANCZOS))[rows]
    n = np.asarray(Image.open(night).convert('RGB').resize((WIDE, HIGH), Image.LANCZOS))[rows]
    for y in range(0, out.shape[0], 256):  # in bands, to keep the nearest-sample search small
        out[y:y + 256] = ground(d[y:y + 256]) | (lamps(n[y:y + 256]) << 5)
    here = os.path.dirname(os.path.abspath(__file__))
    target = os.path.join(here, '../../Sources/Atrium/Resources/orbit-earth.lzfse')
    with tempfile.NamedTemporaryFile(suffix='.raw') as raw:
        raw.write(out.tobytes())
        raw.flush()
        subprocess.run(['/usr/bin/compression_tool', '-encode', '-a', 'lzfse', '-i', raw.name, '-o', target], check=True)
    kinds = np.bincount(out.ravel() & 31, minlength=len(GROUND))
    print(out.shape, os.path.getsize(target), 'bytes;', ', '.join(f'{k} {c * 100 / out.size:.1f}%' for k, c in zip(GROUND, kinds)),
          f'; lit {float((out >> 5 > 0).mean()) * 100:.2f}%')
    if len(sys.argv) > 3:  # a picture of the bake, to look at
        colours = np.array([(22, 56, 104), (28, 70, 120), (38, 96, 136), (52, 126, 148), (236, 208, 158), (188, 154, 114), (196, 146, 110),
                            (160, 112, 88), (170, 148, 106), (138, 136, 98), (106, 140, 82), (96, 132, 72), (54, 96, 62), (30, 58, 56),
                            (42, 80, 56), (124, 120, 124), (198, 210, 232), (238, 242, 248)], dtype=np.uint8)
        Image.fromarray(colours[out & 31]).save(sys.argv[3] + '-day.png')
        Image.fromarray((out >> 5) * 36).save(sys.argv[3] + '-night.png')
