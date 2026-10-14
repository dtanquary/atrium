"""Turns a picture into the route Etching's stylus takes: one unbroken line, the picture's own outlines first
and then its shading, written as Sources/Atrium/Resources/etching-<name>.route (docs/etching.md has the format).

    python3 bake.py <folder of source pictures> <Resources folder> [name ...] [--fine]

The source pictures are not in the repo: PICTURES gives each one's address, and the file name it is looked for
under. Needs numpy, scipy and Pillow, and clang for route.c. --fine bakes the half-width line (twice the detail)
as etching-<name>-fine.route. A picture in FINE_ONLY is too dense for the standard line and is baked fine only.

A patent's file is one sheet of the Patent Office's PDF, taken out as it is: `pdfimages -png -f 1 -l 1 US0059915.pdf
US0059915-p1` (poppler), then renamed. A Bourgoin plate is the Internet Archive's own JPEG of that leaf. A drawing on
a stained sheet, or a painted leaf, has its paper's tone taken out first (`flatten`).

The grid is the stylus's own: a cell is one step, 1024 x 640 of them to a 16:10 screen (2048 x 1280 fine), and the
line is 1.44 cells wide. Measured on the real toy, a line is about 1/700 of the screen's width.
"""
import ctypes, os, struct, subprocess, sys, tempfile, zlib
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

Image.MAX_IMAGE_PIXELS = None
HERE = os.path.dirname(os.path.abspath(__file__))

WELLCOME = "https://iiif.wellcomecollection.org/image/%s/full/max/0/default.jpg"
HYDE_PARK = ("https://archive.org/download/McGillLibrary-rbsc_building-erected-hyde-park_folioNA6750L6D71852-21979/rbsc_building-erected-hyde-park_folioNA6750L6D71852"
             "_jp2.zip/rbsc_building-erected-hyde-park_folioNA6750L6D71852_jp2%%2Frbsc_building-erected-hyde-park_folioNA6750L6D71852_%s.jp2")
MADRID = "https://bnedigital.bne.es/bd/es/viewer?id=1354ee8e-5c8d-4f9c-bb4c-6963121b7a7e&page=%d"

PICTURES = {   # name: file, source, crop as fractions of the file, tone gamma, then options (rot, invert, lift, blank, flatten)
    "wave": ("45434-DP130155.jpg", "https://images.metmuseum.org/CRDImages/as/original/DP130155.jpg", (0.0, 0.0, 1.0, 1.0), 1.0, {}),
    "rhinoceros": ("356497-DT241450.jpg", "https://images.metmuseum.org/CRDImages/dp/original/DT241450.jpg", (0.0, 0.104, 1.0, 0.995), 1.0, {}),
    "flea": ("science-hooke-flea-1665-wellcome.jpg", "https://iiif.wellcomecollection.org/image/L0084699/full/max/0/default.jpg", (0.05, 0.04, 0.98, 0.95), 1.2, {}),
    "interlace": ("ornament-bourgoin-entrelacs-1879-gri-n240.png",
                  "https://archive.org/download/gri_33125012261786/gri_33125012261786_jp2.zip/gri_33125012261786_jp2%2Fgri_33125012261786_0240.jp2",
                  (0.10, 0.30, 0.835, 0.72), 1.0, {}),
    "flyer": ("machines-wright-flying-machine-1906-uspto-sheet1.png", "https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/0821393",
              (0.17, 0.215, 0.80, 0.765), 1.0, dict(rot=-90)),
    "mishima": ("56346-DP141065.jpg", "https://images.metmuseum.org/CRDImages/as/original/DP141065.jpg", (0.005, 0.012, 0.985, 0.975), 1.0, {}),
    # the second set, 2026-10-12
    "velocipede": ("US0059915-p1.png", "https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/0059915", (0.16, 0.15, 0.73, 0.42), 1.0, {}),
    "airship": ("US0621195-p1.png", "https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/0621195", (0.15, 0.15, 0.72, 0.87), 1.0,
                dict(rot=-90, blank=[(0.0, 0.55, 0.20, 1.0), (0.0, 0.0, 0.22, 0.27)])),          # the sheet is sideways; signatures painted out
    "polyhedra": ("339008-DP239933.jpg", "https://images.metmuseum.org/CRDImages/dp/original/DP239933.jpg", (0.13, 0.155, 0.90, 0.835), 1.0, {}),
    "kajikazawa": ("56727-DP140973.jpg", "https://images.metmuseum.org/CRDImages/as/original/DP140973.jpg", (0.02, 0.03, 0.975, 0.955), 1.6, {}),
    "stars": ("bourgoin-n244.jpg", "https://archive.org/download/gri_33125012261786/page/n244.jpg", (0.105, 0.475, 0.775, 0.775), 1.0, dict(lift=0.35)),
    "bands": ("bourgoin-n190.jpg", "https://archive.org/download/gri_33125012261786/page/n190.jpg", (0.10, 0.33, 0.77, 0.63), 1.0, dict(lift=0.35)),
    "pontneuf": ("maps-turgot-paris-sheet11-1739-bpl.jpg",
                 "https://upload.wikimedia.org/wikipedia/commons/c/c3/Turgot_map_of_Paris%2C_sheet_11_-_Norman_B._Leventhal_Map_Center.jpg",
                 (0.012, 0.55, 0.348, 0.855), 1.3, {}),
    # the third set, 2026-10-13: old plans and plates
    "rotonda": ("698054-DP109542.jpg", "https://images.metmuseum.org/CRDImages/dp/original/DP109542.jpg", (0.03, 0.604, 0.97, 0.988), 1.0,
                dict(lift=0.2, blank=[(0.36, 0.0, 0.64, 0.17), (0.84, 0.60, 1.0, 0.76)])),       # the lower half of the page; the plan above it is cropped away
    "ant": ("wellcome-L0084697.jpg", WELLCOME % "L0084697", (0.185, 0.03, 0.992, 0.976), 1.6, dict(rot=90, blank=[(0.02, 0.555, 0.065, 0.80)])),
    "fanlight": ("hydepark-0155.jp2", HYDE_PARK % "0155", (0.08, 0.09, 0.985, 0.85), 1.0, {}),
    "crystal": ("hydepark-0074.jp2", HYDE_PARK % "0074", (0.316, 0.122, 0.677, 0.80), 1.0, {}),   # the elevation's middle third
    "stjerneborg": ("tycho-n104.jpg", "https://archive.org/download/gri_tychonisbrah00brah/page/n104.jpg", (0.035, 0.148, 0.893, 0.495), 1.0,
                    dict(lift=0.25)),                                                             # the next page's type shows through the paper
    "telescope": ("wellcome-V0024709.jpg", WELLCOME % "V0024709", (0.03, 0.112, 0.955, 0.95), 1.0,
                  dict(lift=0.15, blank=[(0.0, 0.574, 0.389, 0.678), (0.0, 0.678, 0.365, 0.762), (0.461, 0.574, 1.0, 0.671), (0.488, 0.671, 1.0, 0.762)])),
    "press": ("wellcome-V0023776.jpg", WELLCOME % "V0023776", (0.02, 0.115, 0.955, 0.875), 1.4, dict(blank=[(0.185, 0.17, 0.255, 0.215), (0.762, 0.86, 1.0, 1.0)])),
    "waterworks": ("wellcome-V0023884.jpg", WELLCOME % "V0023884", (0.05, 0.064, 0.93, 0.78), 1.0,
                   dict(blank=[(0.63, 0.275, 0.96, 0.34), (0.245, 0.35, 0.295, 0.385), (0.72, 0.35, 0.77, 0.385)])),
    "steamer": ("wellcome-V0024366.jpg", WELLCOME % "V0024366", (0.12, 0.528, 0.98, 0.912), 1.0,
                dict(blank=[(0.2, 0.0, 0.8, 0.06), (0.375, 0.305, 0.41, 0.355), (0.85, 0.945, 0.96, 0.995)])),   # one figure of the plate's four
    "balloons": ("loc-ppmsca-02501u.tif", "https://cdn.loc.gov/master/pnp/ppmsca/02500/02501u.tif", (0.06, 0.095, 0.89, 0.495), 1.3,
                 dict(lift=0.3, blank=[(0.0, 0.0, 0.215, 0.03), (0.245, 0.0, 0.5, 0.03), (0.66, 0.0, 0.95, 0.055), (0.0, 0.925, 0.55, 1.0)])),   # the top row
    "cayley": ("loc-ppmsca-02521u.tif", "https://cdn.loc.gov/master/pnp/ppmsca/02500/02521u.tif", (0.03, 0.06, 0.95, 0.85), 1.0,
               dict(blank=[(0.62, 0.03, 1.0, 0.085), (0.04, 0.77, 0.07, 0.90)])),
    "roadengine": ("US0549160-p1.png", "https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/0549160", (0.19, 0.225, 0.91, 0.54), 1.0,
                   dict(blank=[(0.50, 0.0, 0.67, 0.09), (0.0, 0.0, 0.5, 0.012)])),
    "draught": ("dimu-architecturan-XL.jpg", "https://ems.dimu.org/image/012uK3KjAwSh?dimension=max", (0.03, 0.10, 0.945, 0.93), 0.6,   # hair-thin lines: darkened to keep them
                dict(blank=[(0.0, 0.25, 0.225, 0.35), (0.0, 0.545, 0.235, 0.65), (0.0, 0.85, 0.25, 0.96), (0.585, 0.04, 0.645, 0.085), (0.89, 0.035, 0.95, 0.08),
                            (0.905, 0.465, 0.96, 0.51), (0.91, 0.755, 0.97, 0.81), (0.915, 0.10, 1.0, 0.27)])),
    "centres": ("wellcome-V0024341.jpg", WELLCOME % "V0024341", (0.03, 0.20, 0.97, 0.93), 1.0,
                dict(blank=[(0.43, 0.235, 0.56, 0.275), (0.23, 0.375, 0.75, 0.475), (0.75, 0.35, 1.0, 0.48), (0.40, 0.49, 0.61, 0.528), (0.44, 0.80, 0.56, 0.84), (0.76, 0.48, 1.0, 0.615)])),
    # and Leonardo and the old machine books. A Science History Institute file is the page's "Full-sized JPG".
    "screw": ("ravaisson2-n340.jpg", "https://archive.org/download/lesmanuscritsdel02lo/page/n340.jpg", (0.31, 0.375, 0.72, 0.565), 1.0,
              dict(lift=0.3, blank=[(0.0, 0.25, 0.21, 0.72), (0.0, 0.80, 1.0, 1.0)], flatten="paper")),
    "bear": ("459184-DP324213.jpg", "https://images.metmuseum.org/CRDImages/rl/original/DP324213.jpg", (0.06, 0.07, 0.94, 0.86), 1.0, dict(lift=0.35, flatten="paper")),
    "wing": ("atlanticus-f858r.jpg", "https://upload.wikimedia.org/wikipedia/commons/8/89/Leonardo_da_Vinci_-_Ambrosiana-Codice-Atlantico-Codex-Atlanticus-f-858-recto.jpg",
             (0.0, 0.0, 0.985, 0.985), 1.0, dict(lift=0.15, flatten="paper")),
    "fountain": ("ramelli-644.jpg", "https://digital.sciencehistory.org/downloads/deriv/d217qp85p/download_full", (0.186, 0.20, 0.855, 0.79), 1.6, dict(lift=0.3)),
    "furnaces": ("agricola-500.jpg", "https://digital.sciencehistory.org/downloads/deriv/kdc86qn/download_full", (0.105, 0.153, 0.682, 0.486), 1.5, {}),
    "peacocks": ("451302-DP369551.jpg", "https://images.metmuseum.org/CRDImages/is/original/DP369551.jpg", (0.07, 0.035, 0.93, 0.407), 1.0,
                 dict(lift=0.2, blank=[(0.0, 0.86, 0.20, 1.0)], flatten="paper")),   # its bottom edge is not to move: under it is a bent crank that, alone, reads as a hooked cross
    "dragon": ("358276-DP108930.jpg", "https://images.metmuseum.org/CRDImages/dp/original/DP108930.jpg", (0.105, 0.035, 0.895, 0.835), 1.0,
               dict(blank=[(0.497, 0.0, 0.522, 1.0), (0.0, 0.0, 0.33, 0.115), (0.74, 0.0, 1.0, 0.135)])),          # two facing pages: the gutter painted out
    # Leonardo's Codex Madrid I (Biblioteca Nacional de España, Mss/8937): each file is that page of BNE's own viewer, downloaded
    # from its panel as a JPEG (1578 x 2174) and renamed by its folio. The blanks paint out the page's writing.
    "spring": ("bne-mss8937-f004r.jpg", MADRID % 20, (0.054, 0.204, 0.951, 0.623), 1.0, dict(lift=0.15, blank=[(0.88, 0.0, 1.0, 1.0)], flatten="through")),
    "fusee": ("bne-mss8937-f016r.jpg", MADRID % 44, (0.044, 0.064, 0.936, 0.482), 1.0, dict(lift=0.15, blank=[(0.0, 0.76, 0.21, 1.0), (0.0, 0.0, 1.0, 0.05)], flatten="through")),
    "twister": ("bne-mss8937-f067v.jpg", MADRID % 131, (0.112, 0.100, 0.888, 0.463), 1.0,
                dict(lift=0.15, blank=[(0.19, 0.0, 0.77, 0.165), (0.0, 0.0, 0.105, 0.21), (0.0, 0.6, 0.11, 1.0), (0.905, 0.27, 1.0, 1.0), (0.78, 0.0, 0.845, 0.16)], flatten="through")),
    "sector": ("bne-mss8937-f030v.jpg", MADRID % 73, (0.029, 0.087, 0.979, 0.521), 1.0, dict(lift=0.15, blank=[(0.1, 0.0, 0.92, 0.205)], flatten="through")),
    "hammers": ("bne-mss8937-f092v.jpg", MADRID % 181, (0.015, 0.036, 0.985, 0.505), 1.0, dict(lift=0.15, blank=[(0.1, 0.80, 0.66, 1.0)], flatten="through")),
    "rack": ("bne-mss8937-f029r.jpg", MADRID % 70, (0.093, 0.219, 0.907, 0.598), 1.0, dict(lift=0.15, blank=[(0.28, 0.0, 0.82, 0.14)], flatten="through")),
}
FINE_ONLY = {"pontneuf"}   # a muddle at the standard line: no standard route is baked, and the app draws it fine whatever Detail says

class Grid:
    """The stylus's grid: cells across and down, and the bare margin round the picture."""
    def __init__(self, fine): self.w, self.h, self.margin = (2048, 1280, 52) if fine else (1024, 640, 26)

def flattened(path, through, wide=0.04):
    """A manuscript sheet as bare paper and ink, in grey: what a drawing on stained paper, or a painted leaf, needs
    before `darkness` can take one tone as bare screen. The paper's tone is taken channel by channel from the sheet
    itself (the 85th percentile of each neighbourhood `wide` of the sheet's width across, on a copy an eighth the
    size, then blurred by half that), and each channel is divided by it, so stains and the sheet's darker edges come
    out as bare paper. `through` takes the other side's writing out as well: on scans of Leonardo's Codex Madrid it
    shows through more in red than in green (14 to 19% darker than the paper against 6 to 12% on the copies the
    research measured; 10 to 18% against 6 to 14% on the library's own files, which ship), where the ink is 50 to
    85% darker in both, so twice the green less the red keeps the ink and takes most of what shows through away;
    the pictures' `lift` drops the rest."""
    a = np.asarray(Image.open(path).convert("RGB"), np.float32)
    h, w = a.shape[:2]
    small = np.asarray(Image.fromarray(a.astype(np.uint8)).resize((w // 8, h // 8), Image.BOX), np.float32)
    k = max(3, int(wide * w / 8))
    rel = []
    for c in range(3):
        paper = ndi.gaussian_filter(ndi.percentile_filter(small[..., c], 85, size=k), k / 2)
        paper = np.asarray(Image.fromarray(paper).resize((w, h), Image.BILINEAR))
        rel.append(a[..., c] / np.maximum(paper, 1))
    v = 2 * rel[1] - rel[0] if through else (rel[0] + rel[1] + rel[2]) / 3
    return Image.fromarray((np.clip(v, 0, 1) * 255).astype(np.uint8))

def darkness(path, grid, crop, gamma=1.0, rot=0, invert=False, lift=0.08, blank=(), flatten=None):
    """The picture as darkness (0 bare screen .. 1 solid) on the grid, centred with a margin; and its rect in cells.
    `lift` is the tone taken as bare screen: raised, it drops a plate's faint construction lines. `flatten` takes
    the paper's own tone out of the whole sheet first (`flattened`): "paper", or "through" where the other side's
    writing shows through as well."""
    im = flattened(path, flatten == "through") if flatten else Image.open(path).convert("L")
    w, h = im.size
    im = im.crop((int(crop[0] * w), int(crop[1] * h), int(crop[2] * w), int(crop[3] * h)))
    if rot: im = im.rotate(rot, expand=True)                    # degrees anticlockwise: a plate printed sideways
    if invert: im = Image.eval(im, lambda v: 255 - v)           # white line on black: draw the line, not the ground
    for x0, y0, x1, y1 in blank:                                # signatures and captions, as fractions of the crop: painted out
        im.paste(255, (int(x0 * im.width), int(y0 * im.height), int(x1 * im.width), int(y1 * im.height)))
    s = min((grid.w - 2 * grid.margin) / im.width, (grid.h - 2 * grid.margin) / im.height)
    pw, ph = int(round(im.width * s)), int(round(im.height * s))
    a = np.asarray(im.resize((pw, ph), Image.BOX), dtype=np.float32)
    hi, lo = np.percentile(a, 97), np.percentile(a, 2)
    d = np.clip((hi - a) / (hi - lo), 0, 1)
    d = np.clip((d - lift) / (1 - lift), 0, 1) ** gamma        # paper tone is bare screen; gamma lightens a dark print
    out = np.zeros((grid.h, grid.w), np.float32)
    x0, y0 = (grid.w - pw) // 2, (grid.h - ph) // 2
    out[y0:y0 + ph, x0:x0 + pw] = d
    return out, (x0, y0, pw, ph)

def thin(m):
    """Zhang and Suen's thinning (CACM 27(3), 1984), then the corners of its staircases taken off."""
    m = m.astype(np.uint8).copy()
    while True:
        changed = False
        for step in (0, 1):
            P = np.pad(m, 1)
            p2, p3, p4, p5 = P[:-2, 1:-1], P[:-2, 2:], P[1:-1, 2:], P[2:, 2:]
            p6, p7, p8, p9 = P[2:, 1:-1], P[2:, :-2], P[1:-1, :-2], P[:-2, :-2]
            seq = [p2, p3, p4, p5, p6, p7, p8, p9, p2]
            B = sum(seq[:8]); A = sum(((seq[i] == 0) & (seq[i + 1] == 1)).astype(np.uint8) for i in range(8))
            c = ((p2 * p4 * p6 == 0) & (p4 * p6 * p8 == 0)) if step == 0 else ((p2 * p4 * p8 == 0) & (p2 * p6 * p8 == 0))
            rm = (m == 1) & (B >= 2) & (B <= 6) & (A == 1) & c
            if rm.any(): m[rm] = 0; changed = True
        if not changed: break
    for a, b, x, y, z in (((-1, 0), (0, 1), (1, 0), (0, -1), (1, -1)), ((0, 1), (1, 0), (-1, 0), (0, -1), (-1, -1)),
                          ((1, 0), (0, -1), (-1, 0), (0, 1), (-1, 1)), ((0, -1), (-1, 0), (1, 0), (0, 1), (1, 1))):
        P = np.pad(m, 1); g = lambda o: P[1 + o[0]:P.shape[0] - 1 + o[0], 1 + o[1]:P.shape[1] - 1 + o[1]]
        m[(m == 1) & (g(a) == 1) & (g(b) == 1) & (g(x) == 0) & (g(y) == 0) & (g(z) == 0)] = 0
    return m.astype(bool)

def line_mask(d, sigma=2.5, k=0.11, floor=0.22, least=12, bold=0.15):
    """The picture's own lines: cells darker than their surroundings, thinned to one cell wide.
    Returns (all lines, the bold ones): bold strokes still stand out after a blur, and are drawn first."""
    ds = ndi.gaussian_filter(d, 0.5)
    m = ((ds - ndi.gaussian_filter(d, sigma)) > k) & (ds > floor)
    sk = thin(m)
    def big(mask, n_):
        lab, n = ndi.label(mask, np.ones((3, 3))); size = ndi.sum(mask, lab, np.arange(n + 1)); return mask & (size[lab] >= n_)
    sk = big(sk, least)
    strong = (ndi.gaussian_filter(d, 1.0) - ndi.gaussian_filter(d, 4.5)) > bold
    major = big(sk & ndi.binary_dilation(sk & strong, np.ones((3, 3)), iterations=4), 30)
    return sk, major

def runs(row):
    """Inclusive (start, end) of each run of True in a 1-D array."""
    e = np.flatnonzero(np.diff(np.concatenate([[0], row.astype(np.int8), [0]])))
    return list(zip(e[::2], e[1::2] - 1))

# tone -> hatching, as the toy's best artists shade: horizontal lines, then vertical, then scraped solid
#   name, (rows or columns), every, offset, darker than
LAYERS = [("H8", 0, 8, 0, 0.20), ("H4", 0, 8, 4, 0.36), ("H2", 0, 4, 2, 0.54),
          ("V4", 1, 4, 0, 0.72), ("V2", 1, 4, 2, 0.84), ("solid", 0, 2, 1, 0.94)]

def hatch_layers(d, rng, jitter=0.03):
    """One mask per layer of hatching, with the zigzag links that join one row's end to the next."""
    ds = ndi.gaussian_filter(d, 1.2)
    out = []
    for name, axis, every, off, thr in LAYERS:
        a = ds.T if axis else ds
        m = np.zeros(a.shape, bool)
        idx = np.arange(off, a.shape[0], every)
        t = thr + rng.uniform(-jitter, jitter, len(idx))[:, None]
        sub = a[idx] > t
        sub = ndi.binary_opening(ndi.binary_closing(sub, np.ones((1, 4))), np.ones((1, 5)))   # no gaps under 4, no runs under 5
        m[idx] = sub
        if name in ("H8", "H4", "H2"):                       # zigzag: join overlapping runs of neighbouring rows
            for k in range(len(idx) - 1):
                ya, yb = idx[k], idx[k + 1]; rb = runs(sub[k + 1])
                for (a0, a1) in runs(sub[k]):
                    for (b0, b1) in rb:
                        lo, hi = max(a0, b0), min(a1, b1)
                        if lo <= hi: m[ya:yb + 1, hi if k % 2 == 0 else lo] = True
        out.append(m.T if axis else m)
    return out

def wanted(d, rect, seed=1):
    """The grid of wanted ink as tiers (0 bare; drawn in order 1, 2, ...): a frame and the bold lines, the other
    lines, then each depth of shading over the whole picture. And the cell the stylus starts on."""
    rng = np.random.default_rng(seed)
    tier = np.zeros(d.shape, np.uint8)
    x0, y0, pw, ph = rect
    frame = np.zeros(d.shape, bool); o = 6                         # a frame first, as a way round the picture
    frame[y0 - o, x0 - o:x0 + pw + o] = frame[y0 + ph + o - 1, x0 - o:x0 + pw + o] = True
    frame[y0 - o:y0 + ph + o, x0 - o] = frame[y0 - o:y0 + ph + o, x0 + pw + o - 1] = True
    lines, major = line_mask(d)
    layers = hatch_layers(d, rng)
    last = 3 + len(layers)
    tier[lines] = 2
    tier[major | frame] = 1
    first = lines | frame
    lab, n = ndi.label(first, np.ones((3, 3)))
    size = ndi.sum(first, lab, np.arange(n + 1))
    tier[first & (size[lab] < 60)] = last                           # small islands wait: later shading often reaches them
    for i, m in enumerate(layers):
        tier[m & (tier == 0)] = 3 + i
    return tier, (y0 + ph + o - 1) * d.shape[1] + x0 - o            # starting at the frame's lower left corner

def route(tier, start, bridge=20):
    """The stylus's cells in order, and how it came to each: 0 drawing, 1 back along its own line, 2 a stray mark."""
    lib = os.path.join(tempfile.gettempdir(), "etching-route.dylib")
    subprocess.check_call(["clang", "-O2", "-shared", "-o", lib, os.path.join(HERE, "route.c")])
    C = ctypes.CDLL(lib); p = ctypes.c_void_p
    C.route.restype = ctypes.c_long
    C.route.argtypes = [p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, p, p, ctypes.c_long, p]
    cap = int(tier.astype(bool).sum()) * 12 + 1_000_000
    out = np.zeros(cap, np.int32); kind = np.zeros(cap, np.uint8); drawn = np.zeros(tier.size, np.uint8)
    t = np.ascontiguousarray(tier, np.uint8); h, w = tier.shape
    n = C.route(t.ctypes.data_as(p), w, h, int(tier.max()), int(start), bridge, out.ctypes.data_as(p), kind.ctypes.data_as(p), cap, drawn.ctypes.data_as(p))
    assert n > 0, "route: out of room"
    assert drawn.reshape(tier.shape)[tier > 0].all(), "route: ink left undrawn"
    return out[:n].copy(), kind[:n].copy()

DIRS = [(1, 0), (0, 1), (-1, 0), (0, -1), (1, 1), (-1, 1), (-1, -1), (1, -1)]
HASTE = 8   # how many times faster the stylus goes back along a line than it draws (LineRoute.haste)

def pack(cells, kind, grid, rect):
    """The route as bytes. Each run of steps one way is a byte: bit 7 set while the stylus goes back along its own
    line, bits 6-4 the direction (DIRS), bits 3-0 the run's length less one. The runs are deflated; before them:
    "LRT1", the grid's width and height, the picture's rect, the start cell, the number of steps, the route's clock
    (cells of drawing, going back counting an eighth), and the deflated length."""
    x, y = cells % grid.w, cells // grid.w
    dx, dy = np.diff(x), np.diff(y)
    code = np.array([DIRS.index((int(a), int(b))) for a, b in zip(dx, dy)], np.uint8) << 4 | (kind[1:] == 1).astype(np.uint8) << 7
    edge = np.flatnonzero(np.r_[1, np.diff(code) != 0, 1])
    out = bytearray()
    for a, b in zip(edge[:-1], edge[1:]):
        n = int(b - a)
        while n > 0: out.append(int(code[a]) | (min(n, 16) - 1)); n -= 16
    # the clock, as the app works it out: positions eased by one step, a step going back taking an eighth of the time
    fx, fy = x + 0.5, y + 0.5
    for v in (fx, fy): v[1:-1] = (v[:-2] + 2 * v[1:-1] + v[2:]) / 4
    seg = np.hypot(np.diff(fx), np.diff(fy))
    clock = float(np.where(kind[1:] == 1, seg / HASTE, seg).sum())
    packed = zlib.compressobj(9, zlib.DEFLATED, -15); body = packed.compress(bytes(out)) + packed.flush()
    head = b"LRT1" + struct.pack("<8HIfI", grid.w, grid.h, *rect, int(x[0]), int(y[0]), len(cells) - 1, clock, len(body))
    return head + body, len(out), clock

if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if a != "--fine"]; fine = "--fine" in sys.argv
    src, dst, names = args[0], args[1], args[2:] or list(PICTURES)
    grid = Grid(fine)
    for name in names:
        if name in FINE_ONLY and not fine: print(f"{name}: fine only, skipped"); continue
        file, _, crop, gamma, more = PICTURES[name]
        d, rect = darkness(os.path.join(src, file), grid, crop, gamma, **more)
        tier, start = wanted(d, rect)
        cells, kind = route(tier, start)
        assert not (kind[1:] == 3).any(), "the line lifted"
        data, nruns, clock = pack(cells, kind, grid, rect)
        out = os.path.join(dst, f"etching-{name}{'-fine' if fine else ''}.route")
        open(out, "wb").write(data)
        stray = int((kind == 2).sum())
        print(f"{os.path.basename(out)}: {len(cells) - 1} steps in {nruns} runs, {len(data)} bytes; clock {clock:.1f} cells = "
              f"{clock / grid.w * 40 / 60:.0f} min at 1/40 of the width a second; {stray} cells of stray marks; picture at {rect}")
