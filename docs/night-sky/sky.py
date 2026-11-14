# Night Sky's photograph of the whole sky, from ESO/S. Brunier's panorama (eso0932a, CC BY 4.0). ESO's full-size
# original is 6000 x 3000, and the TIFF is that without a JPEG's blocks:
#   curl -LO https://cdn.eso.org/images/original/eso0932a.tif
#   python3 docs/night-sky/sky.py eso0932a.tif sky.png && sips -s format heic -s formatOptions 88 sky.png --out Sources/Atrium/Resources/sky-milky-way.heic
# Two things are changed. Venus and Jupiter, which stood in Aquarius and Sagittarius on the nights it was shot
# (2008-09), are painted out with the sky beside them: they'd be two bright stars that aren't there. And the photo's
# own stars are taken out: stretched over a screen they are soft dots, a point and a half from where the catalogue
# puts the same stars, so the scene draws the stars itself, sharp, and keeps the photo for what is spread out (the
# Milky Way's glow and dust, the Magellanic Clouds, Andromeda, the nebulae). A median over 5 pixels, a third of a
# degree, does it, and the glow of a crowded star field is its median, so no light has to be put back. Over 9 pixels
# the last star goes but so do the dust lanes' fine edges; over 3, stars are left beside the catalogue's. It is kept
# at the original's own 6000 x 3000: at 4096 the lanes are visibly softer. `keep` (0 to 1) leaves that share of the
# stars in, to look at.
import sys
from PIL import Image, ImageChops, ImageDraw, ImageFilter
Image.MAX_IMAGE_PIXELS = None
src, out = sys.argv[1], sys.argv[2]
keep = float(sys.argv[3]) if len(sys.argv) > 3 else 0
photo = Image.open(src).convert('RGB')
for x, y, r in ((1851, 2472, 80), (2776, 1776, 60)):  # Venus, Jupiter: centre and radius in the original's pixels
    side = 2 * r + 60
    box = (x - side // 2, y - side // 2, x + side // 2, y + side // 2)
    beside = photo.crop((box[0] + side, box[1], box[2] + side, box[3]))  # the same galactic latitude, so as bright
    mask = Image.new('L', (side, side), 0)
    ImageDraw.Draw(mask).ellipse((30, 30, side - 30, side - 30), fill=255)
    photo.paste(beside, box[:2], mask.filter(ImageFilter.GaussianBlur(12)))
sky = photo.filter(ImageFilter.MedianFilter(5)).filter(ImageFilter.GaussianBlur(0.7))
if keep:
    sky = ImageChops.add(sky, ImageChops.subtract(photo, sky).point(lambda v: int(v * keep + 0.5)))
sky.save(out)
