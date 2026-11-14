# Night Sky's photo of the whole sky, from ESO/S. Brunier's panorama (eso0932a, CC BY 4.0):
#   curl -LO https://cdn.eso.org/images/large/eso0932a.jpg
#   python3 docs/night-sky/sky.py eso0932a.jpg sky.png && sips -s format heic -s formatOptions 65 sky.png --out sky-milky-way.heic
# Two things are changed. Venus and Jupiter, which stood in Aquarius and Sagittarius on the nights it was shot
# (2008-09), are painted out with the sky beside them: they'd be two bright stars that aren't there. And the photo's
# own stars are turned down to `keep` of their light: left as they are, the faint ones (soft dots, all much the same
# brightness once the photo is stretched over a screen) drown the catalogue's stars and the constellations. A median
# takes the stars out and leaves what's spread out (the Milky Way's glow and dust, the Magellanic Clouds, Andromeda,
# the nebulae); that share of what it took out goes back on top.
import sys
from PIL import Image, ImageChops, ImageDraw, ImageFilter
Image.MAX_IMAGE_PIXELS = None
src, out = sys.argv[1], sys.argv[2]
keep = float(sys.argv[3]) if len(sys.argv) > 3 else 0.3
photo = Image.open(src).convert('RGB')
for x, y, r in ((1851, 2472, 80), (2776, 1776, 60)):  # Venus, Jupiter: centre and radius in the original's pixels
    side = 2 * r + 60
    box = (x - side // 2, y - side // 2, x + side // 2, y + side // 2)
    beside = photo.crop((box[0] + side, box[1], box[2] + side, box[3]))  # the same galactic latitude, so as bright
    mask = Image.new('L', (side, side), 0)
    ImageDraw.Draw(mask).ellipse((30, 30, side - 30, side - 30), fill=255)
    photo.paste(beside, box[:2], mask.filter(ImageFilter.GaussianBlur(12)))
glow = photo.filter(ImageFilter.MedianFilter(9)).filter(ImageFilter.GaussianBlur(2))
stars = ImageChops.subtract(photo, glow)  # clipped at 0: only what stands above the glow
sky = ImageChops.add(glow, stars.point(lambda v: int(v * keep + 0.5)))
sky.resize((4096, 2048), Image.LANCZOS).save(out)
if len(sys.argv) > 4:  # the patches, to look at
    for i, (x, y) in enumerate(((1851, 2472), (2776, 1776))):
        photo.crop((x - 300, y - 200, x + 300, y + 200)).save('%s-patch%d.jpg' % (sys.argv[4], i))
