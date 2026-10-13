"""Cuts Peg Board's pictures down to pegs, and writes its charts and their credits.

usage: python3 -I cut.py <folder of the source pictures> <Sources/Atrium/Resources> [sheet.png]

Each picture in PICTURES is downloaded by hand from its `image` address into the folder, under its `file` name. A
chart is the picture at one size: a honeycomb of holes (rows half a pitch offset and 0.866 of a pitch apart), each
empty or holding one of the eight peg colours. Every hole takes the picture's average over its own cell, or, for a
charted pattern, one of the pattern's own squares (below), and then:
  colour: left empty where the picture is dark and colourless (`cut`), or near the colour of its paper (`paper`),
          or lands on a colour named in `drop`; else the nearest peg colour in OKLab, lightness counting 0.7.
  tone:   for a print in one ink. Its lightness, turned over when `ink` is set so that ink becomes light, is left
          empty below `cut` and above it takes a peg from `ramp`, dimmest first.
A peg with no peg beside it is taken out. A picture is cut at each size in its `sizes`, and only those: every chart
was looked at (the optional sheet draws them all as plain discs), and a picture that did not read at a size is not
cut at it.

A charted pattern (an old needlework chart, drawn on a net of squares) can go a square to a hole, so that every peg
is one of its maker's own squares: set brick-fashion, each row half a hole along from the last, which leans its
uprights and makes it a seventh shorter. Such a picture has `nets`, each the net of one band of its page: where the
first square's middle is and the steps to the next square across and down, in the page's own pixels (grid.py finds
them). A size is then a list of (net, columns from and to, rows from and to), set one under the next with three
empty rows between; a size given as None is cut from the `crop` in the ordinary way.

It writes peg-board-charts.txt afresh, so the app's own figures, which draw.py adds to that file, want drawing again
after it. docs/peg-board.md has the sources' licences. Needs numpy and Pillow."""
import sys
import numpy as np
from PIL import Image, ImageDraw
Image.MAX_IMAGE_PIXELS = None

RISE = 0.8660254
# Holes across and down, at most, by the size of peg a chart is for: what a 13-inch laptop's display holds, less a
# margin, at Large pegs (the toy's own size), Medium (half) and Small (a third).
SIZES = {"large": (43, 30), "medium": (86, 61), "small": (131, 93)}
NAMES = ["red", "pink", "orange", "yellow", "green", "blue", "violet", "clear"]
# The peg colours as measured from photographs of the real pegs, sRGB: what a picture's colours are matched to.
PEGS = np.array([[200, 25, 10], [205, 25, 75], [220, 95, 10], [205, 170, 20], [0, 195, 25], [5, 80, 190], [140, 45, 190], [235, 215, 180]], np.float32)
WARM = ("red", "orange", "yellow")
MET = "The Metropolitan Museum of Art"
SIBMACHER = dict(author="Johann Sibmacher; " + MET, licence="CC0", how="tone", ink=True, cut=0.5)

PICTURES = [
    dict(name="great-wave", file="great-wave-met-DP130155.jpg", title="Under the Wave off Kanagawa (The Great Wave), c. 1830-32",
         author="Katsushika Hokusai; The Metropolitan Museum of Art", licence="CC0", source="https://www.metmuseum.org/art/collection/search/45434",
         image="https://images.metmuseum.org/CRDImages/as/web-large/DP130155.jpg",
         crop=(0.035, 0.03, 0.98, 0.97), how="colour", cut=0.6, drop=("yellow", "orange", "green"), sizes=("medium", "small")),
    dict(name="wreath", file="berlin-wicht-design-1860-ch-1947-78-2.jpg", title="Design for Berlin Wool Work (a wreath of flowers), c. 1860",
         author="Carl F. W. Wicht, Berlin; Cooper Hewitt, Smithsonian Design Museum", licence="CC0",
         source="https://collection.cooperhewitt.org/view/objects/asitem/id/96964", image="https://ids.si.edu/ids/download?id=CHSDM-1947-78-2MattFlynn.jpg",
         crop=(0.250, 0.228, 0.785, 0.730), how="colour", cut=0.0, paper=0.06, sizes=("medium", "small")),
    dict(name="stag", file="berlin-meister-stag-1850-ch-1960-59-2.jpg", title="Design for Berlin Wool Work, Stag, c. 1850",
         author="Thomas Wilhelm Meister, Berlin; Cooper Hewitt, Smithsonian Design Museum", licence="CC0",
         source="https://collection.cooperhewitt.org/view/objects/asitem/id/127556", image="https://ids.si.edu/ids/download?id=CHSDM-1960-59-2MattFlynn.jpg",
         crop=(0.27, 0.30, 0.74, 0.72), how="colour", cut=0.0, paper=0.06, sizes=("large", "medium", "small")),
    dict(name="flea", file="science-hooke-flea-1665-wellcome.jpg", title="A flea, from Micrographia, 1665",
         author="Robert Hooke; Wellcome Collection", licence="CC BY 4.0", source="https://wellcomecollection.org/works/ajveb66y",
         image="https://iiif.wellcomecollection.org/image/L0084699/full/max/0/default.jpg",
         crop=(0.075, 0.07, 0.95, 0.90), how="tone", ink=True, cut=0.35, ramp=WARM, sizes=("large", "medium", "small")),
    dict(name="sol", file="lacis-vinciolo-sol-1588-met-DP364040.jpg", title="Sol, a lace pattern from Les Singuliers et Nouveaux Portraicts, 1588",
         author="Federico de Vinciolo; The Metropolitan Museum of Art", licence="CC0", source="https://www.metmuseum.org/art/collection/search/665397",
         image="https://images.metmuseum.org/CRDImages/dp/original/DP364040.jpg",
         crop=(0.108, 0.112, 0.893, 0.708), how="tone", ink=False, cut=0.55, ramp=("yellow",), sizes=("medium", "small")),
    # Five pages of a pattern book of 1597, its squares read one to a hole. (Left alone under Dave's rule on religious
    # pictures: page 19's other band, hounds after a stag with what may be a cross over it; page 17's leaping stag; and
    # page 13's key border, a chain of stepped crosses.)
    dict(name="modelbook-9", file="sibmacher-1597-p9r-met-DP363477.jpg", title="Schön Neues Modelbuch, page 9 recto: birds, flowers and scrolls, 1597",
         source="https://www.metmuseum.org/art/collection/search/680631", image="https://images.metmuseum.org/CRDImages/dp/original/DP363477.jpg",
         nets=dict(birds=(313.2, 334.6, 17.374, -0.148, 0.256, 17.068), scrolls=(297.4, 1403.3, 17.541, -0.188, 0.204, 16.981)), ramp=("violet",),
         sizes=dict(large=[("scrolls", 42, 85, 1, 31)], medium=[("birds", 41, 127, 0, 57)], small=[("birds", 0, 127, 0, 57), ("scrolls", 0, 127, 0, 31)]), **SIBMACHER),
    dict(name="modelbook-14", file="sibmacher-1597-p14r-met-DP363482.jpg", title="Schön Neues Modelbuch, page 14 recto: an eagle among flowers, 1597",
         source="https://www.metmuseum.org/art/collection/search/680637", image="https://images.metmuseum.org/CRDImages/dp/original/DP363482.jpg",
         nets=dict(eagle=(319.8, 341.5, 16.799, -0.147, -0.107, 17.061)), ramp=("red",),
         sizes=dict(medium=[("eagle", 36, 92, 6, 63)], small=[("eagle", 0, 125, 0, 67)]), **SIBMACHER),
    dict(name="modelbook-19", file="sibmacher-1597-p19r-met-DP363487.jpg", title="Schön Neues Modelbuch, page 19 recto: a griffin among flowers, 1597",
         source="https://www.metmuseum.org/art/collection/search/680644", image="https://images.metmuseum.org/CRDImages/dp/original/DP363487.jpg",
         nets=dict(griffin=(282.7, 400.6, 17.261, -0.082, 0.057, 16.812)), ramp=("orange",),
         sizes=dict(medium=[("griffin", 22, 108, 4, 60)], small=[("griffin", 0, 125, 0, 65)]), **SIBMACHER),
    dict(name="modelbook-24", file="sibmacher-1597-p24r-met-DP363492.jpg", title="Schön Neues Modelbuch, page 24 recto: knots and stars, 1597",
         source="https://www.metmuseum.org/art/collection/search/680650", image="https://images.metmuseum.org/CRDImages/dp/original/DP363492.jpg",
         nets=dict(knots=(257.9, 338.8, 16.990, -0.102, 0.085, 17.049), stars=(249.6, 1359.3, 16.937, -0.204, -0.070, 17.015)), ramp=("pink",),
         sizes=dict(large=[("stars", 4, 47, 7, 26)], medium=[("knots", 12, 98, 0, 53)], small=[("knots", 0, 108, 0, 53), ("stars", 2, 78, 5, 28)]),
         **dict(SIBMACHER, cut=0.70), specks=True),  # its page marks a second colour with a ringed cross in the square: only the filled squares are taken
    dict(name="modelbook-13", file="sibmacher-1597-p13r-met-DP363481.jpg", title="Schön Neues Modelbuch, page 13 recto: eight-pointed stars, 1597",
         source="https://www.metmuseum.org/art/collection/search/680636", image="https://images.metmuseum.org/CRDImages/dp/original/DP363481.jpg",
         nets=dict(stars=(309.2, 470.1, 17.246, 0.073, -0.106, 16.811)), ramp=("blue", "clear"),
         sizes=dict(large=[("stars", 16, 59, 10, 40)], medium=[("stars", 0, 78, 0, 51)]),
         **dict(SIBMACHER, cut=0.33)),             # the same marks, here taken as a second colour: marked squares blue, filled ones clear
    # Three more lace patterns from Vinciolo's book, cut as Sol is: its net is a woodcut's, too uneven to read square by
    # square (the unicorn did not read at Large pegs, so is not cut for them).
    dict(name="lion", file="lacis-vinciolo-lion-1588-met-DP364071.jpg", title="A lion, a lace pattern from Les Singuliers et Nouveaux Portraicts, 1588",
         author="Federico de Vinciolo; " + MET, licence="CC0", source="https://www.metmuseum.org/art/collection/search/665797",
         image="https://images.metmuseum.org/CRDImages/dp/original/DP364071.jpg",
         crop=(0.125, 0.130, 0.830, 0.725), crops=dict(large=(0.20, 0.28, 0.83, 0.69)), how="tone", ink=False, cut=0.55, ramp=("yellow",), sizes=("large", "medium", "small")),
    dict(name="unicorn", file="lacis-vinciolo-unicorn-1588-met-DP364074.jpg", title="A unicorn, a lace pattern from Les Singuliers et Nouveaux Portraicts, 1588",
         author="Federico de Vinciolo; " + MET, licence="CC0", source="https://www.metmuseum.org/art/collection/search/665812",
         image="https://images.metmuseum.org/CRDImages/dp/original/DP364074.jpg",
         crop=(0.140, 0.135, 0.855, 0.735), how="tone", ink=False, cut=0.55, ramp=("clear",), sizes=("medium", "small")),
    dict(name="birds", file="lacis-vinciolo-birds-1588-met-DP364036.jpg", title="Four birds, a lace pattern from Les Singuliers et Nouveaux Portraicts, 1588",
         author="Federico de Vinciolo; " + MET, licence="CC0", source="https://www.metmuseum.org/art/collection/search/665394",
         image="https://images.metmuseum.org/CRDImages/dp/original/DP364036.jpg",
         crop=(0.118, 0.070, 0.754, 0.645), crops=dict(large=(0.19, 0.07, 0.745, 0.33)), how="tone", ink=False, cut=0.55, ramp=("blue",), sizes=("large", "medium", "small")),
]


def linear(c):
    c = np.asarray(c, np.float32) / 255
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def oklab(rgb):
    """Linear sRGB to OKLab (Björn Ottosson, https://bottosson.github.io/posts/oklab/, public domain)."""
    l = np.cbrt(0.4122214708 * rgb[..., 0] + 0.5363325363 * rgb[..., 1] + 0.0514459929 * rgb[..., 2])
    m = np.cbrt(0.2119034982 * rgb[..., 0] + 0.6806995451 * rgb[..., 1] + 0.1073969566 * rgb[..., 2])
    s = np.cbrt(0.0883024619 * rgb[..., 0] + 0.2817188376 * rgb[..., 1] + 0.6299787005 * rgb[..., 2])
    return np.stack([0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s, 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
                     0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s], -1)


def holes(pic, cols, rows):
    """The picture's average over each hole's cell, in linear light: rows x cols x 3, top row first, and whether the
    hole is on the picture at all. The picture is set whole on the chart, in its middle. The bottom row is never offset."""
    h, w, _ = pic.shape
    scale = min((cols - 0.5) / w, (rows - 1) * RISE / h)                 # pitches to a pixel
    sums = np.zeros((h + 1, w + 1, 3)); sums[1:, 1:] = pic.cumsum(0).cumsum(1)
    out = np.zeros((rows, cols, 3), np.float32); on = np.zeros((rows, cols), bool)
    for top in range(rows):
        up = rows - 1 - top
        for col in range(cols):
            x = (col + 0.5 * (up & 1) - (cols - 0.5) / 2) / scale + w / 2
            y = (top - (rows - 1) / 2) * RISE / scale + h / 2
            half = 0.5 / scale
            x0, x1, y0, y1 = (int(round(v)) for v in (x - half, x + half, y - half * RISE, y + half * RISE))
            if x0 < 0 or y0 < 0 or x1 > w or y1 > h or x1 <= x0 or y1 <= y0: continue
            out[top, col] = (sums[y1, x1] - sums[y0, x1] - sums[y1, x0] + sums[y0, x0]) / ((x1 - x0) * (y1 - y0))
            on[top, col] = True
    return out, on


def squares(pic, net, c0, c1, r0, r1):
    """A charted pattern's own squares, columns c0 to c1 and rows r0 to r1 of its net: each one's average over its
    middle half (clear of the net's lines), in linear light."""
    x0, y0, ax, ay, bx, by = net
    sums = np.zeros((pic.shape[0] + 1, pic.shape[1] + 1, 3)); sums[1:, 1:] = pic.cumsum(0).cumsum(1)
    q = 0.27 * np.hypot(ax, ay)
    out = np.zeros((r1 - r0, c1 - c0, 3), np.float32)
    for r in range(r0, r1):
        for c in range(c0, c1):
            x, y = x0 + c * ax + r * bx, y0 + c * ay + r * by
            xa, xb, ya, yb = int(round(x - q)), int(round(x + q)) + 1, int(round(y - q)), int(round(y + q)) + 1
            out[r - r0, c - c0] = (sums[yb, xb] - sums[ya, xb] - sums[yb, xa] + sums[ya, xa]) / ((xb - xa) * (yb - ya))
    return out


def cut(p, size):
    """One chart: rows x cols of 0 (empty) or 1 to 8 (a peg colour's place in NAMES, plus one), top row first."""
    parts = p["sizes"][size] if "nets" in p else None
    im = Image.open(f"{SOURCES}/{p['file']}")
    if im.format == "JPEG" and not parts: im.draft("RGB", (2400, 2400))
    im = im.convert("RGB"); w, h = im.size
    if parts:                                                              # its own squares, band under band
        bands = [squares(linear(np.asarray(im)), p["nets"][net], *box) for net, *box in parts]
        cols, rows = max(b.shape[1] for b in bands), sum(b.shape[0] for b in bands) + 3 * (len(bands) - 1)
        mean, on, top = np.zeros((rows, cols, 3), np.float32), np.zeros((rows, cols), bool), 0
        for b in bands:
            left = (cols - b.shape[1]) // 2
            mean[top:top + b.shape[0], left:left + b.shape[1]] = b
            on[top:top + b.shape[0], left:left + b.shape[1]] = True
            top += b.shape[0] + 3
    else:
        cols, rows = SIZES[size]
        c = p.get("crops", {}).get(size, p.get("crop"))                    # a size can have a crop of its own
        mean, on = holes(linear(np.asarray(im.crop((int(c[0] * w), int(c[1] * h), int(c[2] * w), int(c[3] * h))))), cols, rows)
    lab = oklab(mean)
    if p["how"] == "tone":
        lo, hi = np.percentile(lab[on][:, 0], [2, 99.5])
        v = np.clip((lab[..., 0] - lo) / (hi - lo), 0, 1)
        if p["ink"]: v = 1 - v
        ramp = np.array([NAMES.index(n) + 1 for n in p["ramp"]])
        chart = ramp[np.clip(((v - p["cut"]) / (1 - p["cut"]) * len(ramp)).astype(int), 0, len(ramp) - 1)]
        chart[(v < p["cut"]) | ~on] = 0
    else:
        pegs = oklab(linear(PEGS))
        lo, hi = np.percentile(lab[on][:, 0], [2, 99.5])
        L = np.clip((lab[..., 0] - lo) / (hi - lo), 0, 1)
        chroma = np.hypot(lab[..., 1], lab[..., 2])
        # the picture's most colourful parts are brought up to a peg's chroma: old pictures are far duller than pegs
        k = min(0.22 / max(np.percentile(chroma[on & (L > p["cut"])], 97), 1e-3), 4.0)
        empty = L < p["cut"] * (1 - np.clip(chroma * k / 0.10, 0, 1))      # dark and colourless is the sheet; deep blue stays a peg
        if p.get("paper"): empty |= np.sqrt(((lab - np.median(lab[on], 0)) ** 2).sum(-1)) < p["paper"]
        Lp = pegs[:, 0].min() + (pegs[:, 0].max() - pegs[:, 0].min()) * np.clip((L - p["cut"]) / (1 - p["cut"]), 0, 1)
        want = np.dstack([Lp * 0.7, lab[..., 1:] * k])
        chart = ((want[:, :, None, :] - pegs[None, None] * [0.7, 1, 1]) ** 2).sum(-1).argmin(-1) + 1
        chart[empty | ~on | np.isin(chart, [NAMES.index(n) + 1 for n in p.get("drop", ())])] = 0
    # a peg alone is a speck: its six neighbours are the two beside it and two in each row above and below. (Not in a
    # pattern's own squares, where a lone one is its maker's.)
    odd = ((rows - 1 - np.arange(rows)) & 1)[:, None]
    q = np.pad(chart > 0, 1); r, c = np.arange(rows)[:, None] + 1, np.arange(cols)[None, :] + 1
    if not parts: chart[~(q[r, c - 1] | q[r, c + 1] | q[r - 1, c - 1 + odd] | q[r - 1, c + odd] | q[r + 1, c - 1 + odd] | q[r + 1, c + odd])] = 0
    if p.get("specks"):                                                    # and, where asked, any clump of fewer than four
        seen = np.zeros(chart.shape, bool)
        for start in zip(*np.nonzero(chart)):
            if seen[start]: continue
            clump, todo = [], [start]; seen[start] = True
            while todo:
                j, i = todo.pop(); clump.append((j, i)); o = (rows - 1 - j) & 1
                for jj, ii in ((j, i - 1), (j, i + 1), (j - 1, i - 1 + o), (j - 1, i + o), (j + 1, i - 1 + o), (j + 1, i + o)):
                    if 0 <= jj < rows and 0 <= ii < cols and chart[jj, ii] and not seen[jj, ii]: seen[jj, ii] = True; todo.append((jj, ii))
            if len(clump) < 4:
                for j, i in clump: chart[j, i] = 0
    # trimmed to its pegs: whole columns, rows off the top, and rows off the bottom in twos (so its bottom row stays unoffset)
    rws, cls = np.flatnonzero(chart.any(1)), np.flatnonzero(chart.any(0))
    bottom = rows - 1 - rws[-1]
    return chart[rws[0]:rows - (bottom - bottom % 2), cls[0]:cls[-1] + 1]


if __name__ == "__main__":
    SOURCES, out = sys.argv[1], sys.argv[2]
    lines = ["# Peg Board's pictures, cut down to pegs by docs/peg-board/cut.py from the sources in peg-board-credits.tsv.",
             "# A chart is '= name size columns rows' (the size of peg it is for) and then its rows from the top: . is an empty hole, 1 to 8 a peg",
             "# (" + ", ".join(NAMES) + "). Rows are half a hole offset; a chart's bottom row is one that is not."]
    drawn = []
    for p in PICTURES:
        for size in p["sizes"]:
            chart = cut(p, size)
            assert chart.shape[1] <= SIZES[size][0] and chart.shape[0] <= SIZES[size][1], (p["name"], size, chart.shape)
            print(f"{p['name']} {size}: {chart.shape[1]} x {chart.shape[0]}, {int((chart > 0).sum())} pegs, colours {sorted(set(NAMES[v - 1] for v in chart[chart > 0]))}")
            lines.append(f"= {p['name']} {size} {chart.shape[1]} {chart.shape[0]}")
            lines += ["".join(".12345678"[v] for v in row) for row in chart]
            drawn.append((f"{p['name']} {size}", chart))
    open(f"{out}/peg-board-charts.txt", "w").write("\n".join(lines) + "\n")
    credits = ["# The pictures Peg Board builds in pegs, each cut down from one of these (docs/peg-board/cut.py). Public domain,",
               "# CC0 or CC BY; CC BY requires this attribution. Each holder's own words, read at the address given:",
               "# The Met (https://metmuseum.github.io/): its API gives \"corresponding high resolution images (JPEG format) that are",
               "#   in the public domain\", and a record's isPublicDomain, \"When \"true\" indicates an artwork in the Public Domain\",",
               "#   was true for each of these; of its data: \"The Metropolitan Museum of Art has waived all copyright and related or",
               "#   neighboring rights to this dataset using the Creative Commons Zero license.\"",
               "# Cooper Hewitt: CC0 under Smithsonian Open Access; each object's API record gives usage.access = CC0.",
               "# Wellcome Collection (https://wellcomecollection.org/works/ajveb66y): CC BY 4.0, \"You can use this work for any",
               "#   purpose, including commercial uses, without restriction under copyright law. You should also provide attribution",
               "#   to the original work, source and licence.\"",
               "# The figures drawn for the app (docs/peg-board/draw.py) are its own work, with no source, and are not listed.",
               "# file\tsubject\tauthor\tlicence\tsource"]
    credits += ["\t".join([p["name"], p["title"], p["author"], p["licence"], p["source"]]) for p in PICTURES]
    open(f"{out}/peg-board-credits.tsv", "w").write("\n".join(credits) + "\n")
    if len(sys.argv) > 3:                                     # every chart as plain discs, 10 px to a hole, to look at
        colours = [(188, 65, 50), (192, 65, 87), (201, 105, 56), (185, 159, 65), (66, 179, 66), (44, 95, 179), (138, 72, 178), (240, 204, 158)]
        cw, ch = SIZES["small"][0] * 10 + 20, int(SIZES["small"][1] * 10 * RISE) + 40
        sheet = Image.new("RGB", (3 * cw, -(-len(drawn) // 3) * ch), (0, 0, 0)); d = ImageDraw.Draw(sheet)
        for n, (label, chart) in enumerate(drawn):
            x0, y0 = (n % 3) * cw + 10, (n // 3) * ch + 24
            d.text((x0, y0 - 18), label, fill=(200, 200, 200))
            rows, cols = chart.shape
            for top in range(rows):
                for col in range(cols):
                    if chart[top, col]:
                        x, y = x0 + (col + 0.5 * ((rows - 1 - top) & 1)) * 10 + 5, y0 + top * 10 * RISE + 5
                        d.ellipse([x - 4.6, y - 4.6, x + 4.6, y + 4.6], fill=colours[chart[top, col] - 1])
        sheet.save(sys.argv[3])
