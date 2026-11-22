"""Bakes the planet's bands for the shader: python3 -I globe.py <empty download dir> [saturn-globe.tsv].

Saturn's colour by latitude, from Solar System Scope's Saturn map (2k_saturn.jpg, 2,048 x 1,024, equirectangular; INOVE,
CC BY 4.0: https://www.solarsystemscope.com/textures/), averaged round the planet at each latitude. Their page says the
maps are "based on NASA elevation and imagery data" and that "colors and shades of the textures are tuned accordng to
true-color photos made by Messenger, Viking and Cassini spacecrafts, and, of course, the Hubble Space Telescope", and
no more: which of the bands' places, colours and contrast is measured and which their artist's isn't said, so this is
their rendering of NASA's pictures, not a measurement. The map is all but zonal (about 3 levels of 255 along a latitude
against 20 to 30 between latitudes, most of it speckle), so one colour a latitude keeps what it has.
Writes 512 rows, north to south: latitude (degrees, taken as planetographic: the page doesn't say), R, G, B (the map's
own display values, 0-255), with a header naming the source.
"""
import os, sys, urllib.request
from PIL import Image
import numpy as np

MAP = "https://www.solarsystemscope.com/textures/download/2k_saturn.jpg"
ROWS = 512


def fetch(url, folder):
    path = os.path.join(folder, url.rsplit("/", 1)[1])
    if not os.path.exists(path):
        req = urllib.request.Request(url, headers={"User-Agent": "globe-baker"})
        with urllib.request.urlopen(req) as r, open(path, "wb") as f:
            f.write(r.read())
    return path


def main():
    folder, out = sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "saturn-globe.tsv"
    a = np.asarray(Image.open(fetch(MAP, folder)).convert("RGB")).astype(float)
    rows = a.mean(axis=1)                                             # one colour a row of the map
    rows = rows.reshape(ROWS, len(rows) // ROWS, 3).mean(axis=1)      # 1,024 rows to 512
    lat = 90 - (np.arange(ROWS) + 0.5) * 180 / ROWS
    with open(out, "w") as f:
        f.write("# Saturn's colour by latitude, north to south: latitude (degrees), R, G, B (display values, 0-255).\n")
        f.write("# From Solar System Scope's Saturn map, 2k_saturn.jpg (INOVE, CC BY 4.0, https://www.solarsystemscope.com/textures/),\n")
        f.write("#   averaged round the planet at each latitude. Their page: \"based on NASA elevation and imagery data\", its \"colors and\n")
        f.write("#   shades ... tuned\" to true-colour photographs, and no more: their rendering of NASA's pictures, not a measurement.\n")
        f.write("#   Latitude is taken as planetographic (the page doesn't say). Made by docs/saturns-rings/globe.py.\n")
        for l, (r, g, b) in zip(lat, rows):
            f.write(f"{l:.3f}\t{r:.1f}\t{g:.1f}\t{b:.1f}\n")


if __name__ == "__main__":
    main()
