#!/usr/bin/env python3
"""Cuts Solar System's photos: level the black of space, crop to the world, cap the size, save HEIC + a thumbnail.

    SOLAR_ORIGINALS=/path/to/originals python3 prep.py [name ...]   # every entry in photos.py, or just those
Writes Sources/Atrium/Resources/solar-<name>.heic, solar-thumb-<body>.jpg, and solar-photos.tsv. The originals aren't
in the repo (about 2 GB); each one's source page is in photos.py, and `src` is its path under SOLAR_ORIGINALS.
Needs numpy, Pillow, scipy, and ffmpeg for 16-bit TIFFs.
"""
import io, json, os, subprocess, sys, tempfile
import numpy as np
from PIL import Image, ImageCms
from scipy import ndimage

Image.MAX_IMAGE_PIXELS = None
HERE = os.path.dirname(os.path.abspath(__file__))
ORIGINALS = os.environ.get('SOLAR_ORIGINALS', os.path.join(HERE, 'originals'))
RES = os.path.join(HERE, '../../Sources/Atrium/Resources')
SRGB = ImageCms.ImageCmsProfile(ImageCms.createProfile('sRGB')).tobytes()
sys.path.insert(0, HERE)
from photos import PHOTOS, HEADER  # noqa: E402


def load(path):
    """RGB floats 0..1, colour-managed to sRGB when the file carries a profile."""
    try:
        im = Image.open(path)
        if im.mode in ('RGB', 'RGBA', 'L', 'P', 'CMYK', 'LA'):
            if 'icc_profile' in im.info:
                src = ImageCms.ImageCmsProfile(io.BytesIO(im.info['icc_profile']))
                im = ImageCms.profileToProfile(im.convert('RGB'), src, ImageCms.createProfile('sRGB'), outputMode='RGB')
            return np.asarray(im.convert('RGB'), dtype=np.float32) / 255
    except Exception:
        pass
    probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries',
                                                'stream=width,height', '-of', 'json', path]))['streams'][0]
    raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', path, '-frames:v', '1', '-f', 'rawvideo', '-pix_fmt', 'rgb48le', '-'])
    return np.frombuffer(raw, dtype='<u2').reshape(probe['height'], probe['width'], 3).astype(np.float32) / 65535


def level(a, black=None):
    """Sets space to true black: the black point is the border's median plus 3 sigma of its noise, and a soft toe
    (y²/(y+t)) keeps faint haze and night sides rather than clipping them."""
    if black is None:
        edge = np.concatenate([a[:8].reshape(-1, 3), a[-8:].reshape(-1, 3), a[:, :8].reshape(-1, 3), a[:, -8:].reshape(-1, 3)])
        edge = edge[edge.sum(1) > 0] if (edge.sum(1) > 0).mean() > 0.2 else edge  # skip a padded frame of pure black
        med = np.median(edge, axis=0)
        sigma = 1.4826 * np.median(np.abs(edge - med), axis=0)
        black = med + 3 * sigma
    black = np.asarray(black, dtype=np.float32)
    y = np.clip((a - black) / (1 - black), 0, None)
    return y * y / (y + 0.015)


def bbox(a, thresh=0.04):
    """The world's box: the biggest bright blob, so stars and stray moons don't widen it."""
    lum = a @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    small = max(1, max(a.shape[:2]) // 800)
    mask = ndimage.binary_closing(lum[::small, ::small] > thresh, iterations=3)
    labels, n = ndimage.label(mask)
    if n == 0:
        return 0, 0, a.shape[1], a.shape[0]
    sizes = ndimage.sum(mask, labels, range(1, n + 1))
    ys, xs = np.nonzero(labels == 1 + int(np.argmax(sizes)))
    return xs.min() * small, ys.min() * small, (xs.max() + 1) * small, (ys.max() + 1) * small


def despeckle(a, t):
    """Replaces specks that stand out from their 5-pixel neighbourhood by more than t (JunoCam's grid of dark marks,
    Cassini's cosmic-ray hits) with the neighbourhood's median: darker ones for t > 0, brighter ones for t < 0."""
    lum = a @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    bad = ndimage.binary_dilation((ndimage.median_filter(lum, 5) - lum) * np.sign(t) > abs(t))
    for c in range(3):
        a[..., c][bad] = ndimage.median_filter(a[..., c], 7)[bad]
    print(f"  despeckled {bad.mean() * 100:.2f}% of pixels")
    return a


def pad_crop(a, x0, y0, x1, y1):
    """Crops, padding with black past the photo's edges."""
    out = np.zeros((y1 - y0, x1 - x0, 3), dtype=a.dtype)
    sx0, sy0, sx1, sy1 = max(x0, 0), max(y0, 0), min(x1, a.shape[1]), min(y1, a.shape[0])
    out[sy0 - y0:sy1 - y0, sx0 - x0:sx1 - x0] = a[sy0:sy1, sx0:sx1]
    return out


def resize(a, w, h):
    chans = [np.asarray(Image.fromarray(a[..., c].astype(np.float32), 'F').resize((w, h), Image.LANCZOS)) for c in range(3)]
    return np.stack(chans, -1)


def save_heic(a, out, quality):
    rgb = (np.clip(a, 0, 1) * 255 + np.random.uniform(-0.5, 0.5, a.shape)).clip(0, 255).astype(np.uint8)
    with tempfile.NamedTemporaryFile(suffix='.png') as tmp:
        Image.fromarray(rgb).save(tmp.name, icc_profile=SRGB)
        subprocess.check_call(['sips', '-s', 'format', 'heic', '-s', 'formatOptions', str(quality), tmp.name, '--out', out],
                              stdout=subprocess.DEVNULL)


def thumb(a, disc, out):
    """A 152×92 swatch for Settings: a whole world fills its height, a close-up is cut from its middle."""
    h, w = a.shape[:2]
    if disc:
        side = max(w, h) * 0.9
        cw, ch = side * 152 / 92 * 0.62, side * 0.62  # closer in than the whole disc, so small worlds read
    else:
        ch = min(h, w * 92 / 152); cw = ch * 152 / 92
    x0, y0 = int(w / 2 - cw / 2), int(h / 2 - ch / 2)
    part = pad_crop(a, x0, y0, x0 + int(cw), y0 + int(ch))
    Image.fromarray((np.clip(resize(part, 152, 92), 0, 1) * 255).astype(np.uint8)).save(out, quality=85)


def cut(p):
    """Returns the saved name, the pixels, and the focus in the cut photo (given as fractions of the original)."""
    a = load(os.path.join(ORIGINALS, p['src']))
    H0, W0 = a.shape[:2]
    ox, oy = 0.0, 0.0  # where the cut photo's corner sits in the original, in original pixels
    if 'crop' in p:  # x0, y0, x1, y1 as fractions: labels, borders, neighbours
        x0, y0, x1, y1 = p['crop']
        ox, oy = int(x0 * W0), int(y0 * H0)
        a = a[oy:int(y1 * H0), ox:int(x1 * W0)]
    if p.get('despeckle'):
        a = despeckle(np.array(a), p['despeckle'])
    if p.get('gain'):
        a = a * p['gain']
    if p['kind'] == 'disc':
        if not p.get('keepblack'):
            a = level(a, p.get('black'))
        if p.get('feather'):  # a photo cut off at its edges, or with no black around it (Titan before the rings), fades out there
            h, w = a.shape[:2]
            f = p['feather'] * min(w, h)
            ramp = lambda n: np.clip(np.minimum(np.arange(n) + 0.5, n - np.arange(n) - 0.5) / f, 0, 1) ** 2 * (3 - 2 * np.clip(np.minimum(np.arange(n) + 0.5, n - np.arange(n) - 0.5) / f, 0, 1))
            a = a * (ramp(h)[:, None] * ramp(w)[None, :])[..., None]
        if 'box' in p:  # a crescent's box needs giving, or it's only the lit part; fractions of the original
            bx0, by0, bx1, by1 = p['box']
            x0, y0, x1, y1 = int(bx0 * W0 - ox), int(by0 * H0 - oy), int(bx1 * W0 - ox), int(by1 * H0 - oy)
        else:
            x0, y0, x1, y1 = bbox(a)
        m = p.get('margin', 0.07) * max(x1 - x0, y1 - y0)
        a = pad_crop(a, int(x0 - m), int(y0 - m), int(x1 + m), int(y1 + m))
        ox, oy = ox + int(x0 - m), oy + int(y0 - m)
        cap = p.get('cap', 3200)
    else:
        cap = p.get('cap', 5120)
    h, w = a.shape[:2]
    f = min(1, cap / max(w, h))
    if p['kind'] == 'closeup' and max(w, h) / min(w, h) > 2:  # a long strip: keep its short side
        f = min(1, 3400 / min(w, h))
    f *= p.get('shrink', 1)  # an upscaled original goes back toward its real sharpness
    if f < 1:
        a = resize(a, round(w * f), round(h * f))
    fx, fy = p.get('at', (None, None))
    focus = (0.5, 0.5) if fx is None else ((fx * W0 - ox) / w, (fy * H0 - oy) / h)
    name = f"solar-{p['name']}.heic"
    save_heic(a, os.path.join(RES, name), p.get('quality', 80))
    return name, a, focus


# Photos not cut this run keep the focus the table already has for them.
TSV = os.path.join(RES, 'solar-photos.tsv')
FOCUS = {r[0]: tuple(float(v) for v in r[7].split(',')[:2]) for r in (l.rstrip('\n').split('\t') for l in open(TSV) if not l.startswith('#'))
         if len(r) > 7 and r[7]} if os.path.exists(TSV) else {}


def main(only):
    rows, thumbs = [], {}
    for p in PHOTOS:
        body = p['body']
        slug = body.lower().replace(' ', '-')
        if p['kind'] == 'live':
            rows.append([f'live-{slug}', body, p['credit'], p['licence'], p['source'], p['caption'], 'live', ''])
            continue
        name = f"solar-{p['name']}.heic"
        if not only or p['name'] in only:
            name, a, focus = cut(p)
            if slug not in thumbs and (p.get('thumb') or not any(q['body'] == body and q.get('thumb') for q in PHOTOS)):
                thumb(a, p['kind'] == 'disc', os.path.join(RES, f'solar-thumb-{slug}.jpg'))
            print(f"{name}: {a.shape[1]}x{a.shape[0]}, {os.path.getsize(os.path.join(RES, name)) / 1e6:.2f} MB, focus {focus[0]:.2f},{focus[1]:.2f}", flush=True)
            FOCUS[name] = focus
        thumbs.setdefault(slug, True)
        focus = tuple(FOCUS.get(name, (0.5, 0.5))) + ((p['zoom'],) if 'zoom' in p else ())
        rows.append([name, body, p['credit'], p['licence'], p['source'], p['caption'], p['kind'], ','.join(f'{v:.3g}' for v in focus)])
    with open(TSV, 'w') as f:
        f.write(HEADER)
        for r in rows:
            f.write('\t'.join(r) + '\n')


if __name__ == '__main__':
    main(set(sys.argv[1:]))
