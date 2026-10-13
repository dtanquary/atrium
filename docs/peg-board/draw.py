"""Draws Peg Board's pictures, the app's own figures, and sets them on its holes: its charts are this file's work.

usage: python3 -I draw.py <Sources/Atrium/Resources> [sheet.png [large|medium|small]]

The sheet is the charts of one size as plain discs, to look at while drawing.

A figure is a list of flat shapes, each in one peg colour (or "none": empty holes, which on a black sheet are a dark
line), the later ones over the earlier. They are drawn on the holes of a chart for Large pegs, 43 holes by 30 rows at
the most: x counts holes along a row and y counts rows from the top, so a row's holes have their middles at a half y
and at whole x, or at half x in every other row (the bottom row, 29, is at whole x, and so is every odd row). A row is
0.866 of a hole high; a radius or a line's width is in holes. Every hole takes the colour of the shape its own middle
is in, so an edge goes between holes, never through their middles (an upright edge at a quarter x), and a disc of
radius 1.2 or 2.1 about a hole's middle is that hole and one or two rings round it. (Not 1.8: thirteen holes make a
six-pointed star.) The chart for Medium pegs is the same drawing at two holes to a unit and the one for Small at
three, which is 86 by 60 and 129 by 90 at the most; a shape can be for some sizes only (`only`), where Large pegs
want a simpler drawing. A figure with `mirror` is drawn as its left half and folded about that x.

Every figure here was drawn from nothing for this file: no picture, template or chart was copied or traced.

It writes peg-board-charts.txt afresh. Needs numpy and Pillow."""
import sys
from math import cos, sin, pi, radians
import numpy as np
from PIL import Image, ImageChops, ImageDraw

RISE = 0.8660254
SIZES = {"large": 1, "medium": 2, "small": 3}                 # holes to a unit of the drawing
COLS, ROWS = 43, 30
NAMES = ["red", "pink", "orange", "yellow", "green", "blue", "violet", "clear"]
# ponytail: Pillow draws each shape as a picture, 30 pixels to a hole with two holes of margin, and a hole reads the
# pixel under its middle. So an edge is good to a thirtieth of a hole, which is plenty while edges are kept clear of
# holes' middles; a figure that needs one closer would want the shapes tested exactly.
FINE, PAD = 30, 2
CANVAS = ((COLS + 2 * PAD) * FINE, int((ROWS + 2 * PAD) * RISE * FINE))


def flat(points):
    """Points and lists of points, as one list."""
    return [q for p in points for q in ([p] if isinstance(p[0], (int, float)) else flat(p))]


def poly(colour, *points, **how): return ("poly", colour, flat(points), how)
def disc(colour, x, y, r, ry=None, **how): return ("disc", colour, (x, y, r, ry or r), how)
def line(colour, width, *points, **how): return ("line", colour, (width, flat(points)), how)


def arc(x, y, r, a0, a1, ry=None, n=24):
    """Points along an ellipse about (x, y) from a0 to a1 degrees, 0 to the right and 90 straight down."""
    return [(x + r * cos(radians(a0 + (a1 - a0) * i / n)), y + (ry or r) * sin(radians(a0 + (a1 - a0) * i / n)) / RISE) for i in range(n + 1)]


def smooth(*points, times=3):
    """A closed outline with its corners cut (Chaikin's), for a rounded shape from a few points."""
    p = flat(points)
    for _ in range(times):
        p = [((1 - t) * a[0] + t * b[0], (1 - t) * a[1] + t * b[1]) for a, b in zip(p, p[1:] + p[:1]) for t in (0.25, 0.75)]
    return p


def mask(shape, size):
    """Where a shape is, as a picture FINE pixels to a hole; nowhere, if it is not for this size."""
    kind, _, a, how = shape
    m = Image.new("L", CANVAS, 0)
    if size[0] not in how.get("only", "lms"): return m
    d = ImageDraw.Draw(m)
    def px(p): return ((p[0] + PAD) * FINE, (p[1] + PAD) * RISE * FINE)
    def blob(p, r): x, y = px(p); d.ellipse([x - r * FINE, y - r * FINE, x + r * FINE, y + r * FINE], fill=255)
    if kind == "poly": d.polygon([px(p) for p in a], fill=255)
    elif kind == "disc":
        x, y = px(a[:2]); d.ellipse([x - a[2] * FINE, y - a[3] * FINE, x + a[2] * FINE, y + a[3] * FINE], fill=255)
    else:                                                     # a thick line with round ends and joins
        d.line([px(p) for p in a[1]], fill=255, width=round(a[0] * FINE))
        for p in a[1]: blob(p, a[0] / 2)
    return ImageChops.multiply(m, mask(how["within"], size)) if "within" in how else m


def chart(figure, size):
    """One chart: rows x cols of 0 (empty) or 1 to 8 (a peg colour's place in NAMES, plus one), top row first."""
    s, layers = SIZES[size], []
    for shapes in (figure["shapes"], figure.get("whole", [])):  # what `mirror` folds, and anything over it that is not folded
        layer = Image.new("L", CANVAS, 0)
        for shape in shapes: layer.paste(9 if shape[1] == "none" else NAMES.index(shape[1]) + 1, mask=mask(shape, size))
        layers.append(layer.load())
    rows, cols, axis = ROWS * s, COLS * s, figure.get("mirror")
    out = np.zeros((rows, cols), int)
    for top in range(rows):
        for col in range(cols):
            x, y = (col + 0.5 * ((rows - 1 - top) & 1)) / s, (top + 0.5) / s
            def read(layer, x): return layer[int((x + PAD) * FINE), int((y + PAD) * RISE * FINE)]
            out[top, col] = (read(layers[1], x) or read(layers[0], axis - abs(x - axis) if axis else x)) % 9   # 9 is "none"
    # trimmed to its pegs: whole columns, rows off the top, and rows off the bottom in twos, so the bottom row stays one that is not offset
    rws, cls = np.flatnonzero(out.any(1)), np.flatnonzero(out.any(0))
    bottom = rows - 1 - rws[-1]
    return out[rws[0]:rows - (bottom - bottom % 2), cls[0]:cls[-1] + 1]


def wave(x0, x1, y, high=0.9, long=6.2):
    """A band of water from x0 to x1 with waves along its top at y, down to the bottom row."""
    n = int((x1 - x0) * 4)
    return [(x0 + (x1 - x0) * i / n, y + high * sin(2 * pi * (x0 + (x1 - x0) * i / n) / long)) for i in range(n + 1)] + [(x1, 30), (x0, 30)]


def gore(colour, k):
    """The balloon's envelope, or a stripe of it k of its width: a ball and the cone under it."""
    return [disc(colour, 12, 11.2, 11 * k, 9.5), poly(colour, (12 - 9.3 * k, 16.5), (12.2, 16.5), (12.2, 24), (12 - 2.4 * k, 24))]


BODY = disc("orange", 23, 15, 12, 7.8)                        # the fish's, which its stripes are cut to
TOWER = poly("clear", (13.75, 10), (17.2, 10), (17.2, 26), (11.75, 26))   # the lighthouse's, likewise
# the snail's shell, a coil from its middle out
SPIRAL = [(15.5 + (1.2 + 3.3 * t) * cos(radians(70 - 360 * (t - 2.75))), 14 + (1.2 + 3.3 * t) * sin(radians(70 - 360 * (t - 2.75))) / RISE) for t in [i / 40 for i in range(111)]]

FIGURES = {
    "sailboat": dict(shapes=[
        poly("clear", (15.2, 0.6), (21, 8), (25, 14), (27.3, 19), (15.2, 19)),
        poly("yellow", (14.3, 3.5), (8.8, 12.5), (4, 19), (14.3, 19)),
        poly("red", (2.5, 20), (29, 20), (25.4, 25), (6.3, 25)),
        poly("blue", wave(-0.4, 31.4, 26)),
    ]),
    "butterfly": dict(mirror=18, shapes=[
        poly("violet", smooth((16.2, 14.6), (16.2, 7.5), (11.5, 2), (5.5, 0.3), (1.2, 2.8), (0.8, 8.5), (4, 13.5), (10, 15))),
        poly("pink", smooth((16.2, 16.2), (10, 16.1), (4.5, 17), (2.6, 21.5), (5.5, 27.2), (10.5, 28.6), (14.5, 24.5), (16.2, 19.5))),
        disc("clear", 7.5, 6.5, 2.1), disc("clear", 8, 21.5, 1.2),
        line("yellow", 1.9, (18, 7.5), (18, 24.5)), disc("yellow", 18, 5.5, 1.2),
        line("yellow", 0.8, (17.5, 4.5), (15.5, 0.5)),
    ]),
    "tulip": dict(shapes=[
        poly("green", smooth((10.4, 30), (4.5, 27.5), (1.2, 21), (1.5, 12.5), (5.5, 19.5), (10.4, 26))),
        poly("green", smooth((11.6, 30), (17.5, 27.5), (20.8, 22), (20.6, 14.5), (16.5, 20.5), (11.6, 26.5))),
        poly("green", (10.25, 15), (12.25, 15), (12.25, 30), (10.25, 30)),
        poly("red", arc(11, 8, 7.2, 0, 180, ry=7 * RISE), (3.8, 0.3), (5.3, 0.3), (7.6, 4.6), (10.2, 0.2), (11.8, 0.2), (14.4, 4.6), (16.7, 0.3), (18.2, 0.3)),
        line("none", 0.8, (8, 5.5), (11, 11.5)), line("none", 0.8, (14, 5.5), (11, 11.5)),
    ]),
    "fish": dict(shapes=[
        poly("yellow", smooth((12, 15), (3, 5.5), (1.2, 7.5), (5, 15), (1.2, 22.5), (3, 24.5))),
        poly("yellow", (16, 8.5), (19.5, 2), (28.5, 7.5), (24, 9)), poly("yellow", (25, 22.5), (18, 22), (16.5, 27), (20.5, 27.6)),
        BODY,
        poly("clear", (17.25, 0), (19.75, 0), (19.75, 30), (17.25, 30), within=BODY),
        poly("clear", (25.25, 0), (27.75, 0), (27.75, 30), (25.25, 30), within=BODY),
        disc("none", 31.5, 12.5, 0.6),
        disc("blue", 37, 5.5, 1.2), disc("none", 37, 5.5, 0.5),
    ]),
    "rocket": dict(mirror=10, shapes=[
        poly("red", (10.2, 0), (8.9, 1.7), (7.8, 3.7), (6.9, 6), (6.25, 9), (10.2, 9)),
        poly("clear", (6.25, 9), (10.2, 9), (10.2, 22), (6.25, 22)),
        disc("blue", 10, 13.5, 1.2),
        poly("red", (6.25, 16), (6.25, 23), (1.3, 25.5), (1.3, 22.5), (4, 18.5)),
        poly("yellow", (6.9, 23), (10.2, 23), (10.2, 30), (8.3, 26.5)),
    ]),
    "owl": dict(mirror=11, shapes=[
        poly("orange", (0.5, 28), (11.2, 28), (11.2, 30), (0.5, 30)),
        poly("violet", (3.2, 8.5), (2.6, 0.4), (9, 4.5)),
        disc("violet", 11, 14.5, 9.2, 11),
        disc("clear", 7, 9.5, 3.1), disc("none", 7, 9.5, 1.2),
        poly("yellow", (11.2, 12), (9.4, 13.5), (11.2, 16.5)),
        disc("yellow", 8.5, 26.5, 1.2),
    ]),
    "mushroom": dict(mirror=13, shapes=[
        disc("red", 13, 14, 12.6, 11.3), poly("none", (0, 16), (14, 16), (14, 31), (0, 31)),
        disc("clear", 13, 5.5, 2.1), disc("clear", 6.5, 8.5, 2.1), disc("clear", 4, 13.5, 1.2), disc("clear", 9.5, 12.5, 1.2),
        poly("clear", (9.6, 17), (13.1, 17), (13.1, 28.2), (8.6, 28.2)),
        poly("green", (1.5, 30), (1.5, 28), (3, 26.2), (4.2, 28), (5.5, 25.5), (7, 28), (8.3, 26), (9.5, 28), (13.1, 28), (13.1, 30)),
    ]),
    "cactus": dict(shapes=[
        line("green", 3.4, (12, 19), (4.5, 19), (4.5, 10.5)), line("green", 3.4, (12, 15), (19.5, 15), (19.5, 6.5)),
        line("green", 5.6, (12, 5), (12, 24.5)),
        disc("pink", 12, 1.5, 1.2),
        poly("orange", (5.75, 24), (18.25, 24), (18.25, 26), (5.75, 26)), poly("orange", (6.75, 26), (17.25, 26), (15.6, 30), (8.4, 30)),
    ]),
    "balloon": dict(mirror=12, shapes=[
        *gore("red", 1), *gore("yellow", 0.6), *gore("red", 0.2),
        poly("orange", (9.75, 26), (12.2, 26), (12.2, 30), (10.25, 30)),
        line("orange", 0.5, (9.8, 24), (10, 26), only="ms"),
    ]),
    "snail": dict(shapes=[
        line("yellow", 3.6, (5, 27.6), (27, 27.6), (31.5, 24.5), (32, 17.5)), poly("yellow", (0.5, 29.7), (6.5, 26), (6.5, 29.7)),
        line("yellow", 1.0, (31.3, 16.5), (30, 12.5)), line("yellow", 1.0, (32.7, 16.5), (34.5, 12.8)),
        line("orange", 2.3, SPIRAL),
    ]),
    "lighthouse": dict(mirror=17, whole=[   # its light: three rays to one side only (one each side made a cross with the tower)
        line("yellow", 0.9, (13.5, 6.5), (1.5, 6.5)), line("yellow", 0.9, (13.2, 5.6), (1.5, 2.4)), line("yellow", 0.9, (13.2, 7.4), (1.5, 10.6)),
    ], shapes=[
        poly("red", (13.3, 4), (17.2, -0.3), (17.2, 4)),
        poly("yellow", (14.75, 4), (17.2, 4), (17.2, 8), (14.75, 8)),
        poly("red", (12.75, 8), (17.2, 8), (17.2, 10), (12.75, 10)),
        TOWER,
        poly("red", (0, 14), (18, 14), (18, 18), (0, 18), within=TOWER), poly("red", (0, 22), (18, 22), (18, 26), (0, 26), within=TOWER),
        poly("blue", wave(3, 17.4, 27.2)),
    ]),
}


if __name__ == "__main__":
    out = sys.argv[1]
    lines = ["# Peg Board's pictures: figures drawn for the app by docs/peg-board/draw.py, its own work, with no source to credit.",
             "# A chart is '= name size columns rows' (the size of peg it is for) and then its rows from the top: . is an empty hole, 1 to 8 a peg",
             "# (" + ", ".join(NAMES) + "). Rows are half a hole offset; a chart's bottom row is one that is not."]
    drawn = []
    for name, figure in FIGURES.items():
        for size, s in SIZES.items():
            c = chart(figure, size)
            pegs = int((c > 0).sum())
            assert c.shape[1] <= COLS * s and c.shape[0] <= ROWS * s and pegs > 150, (name, size, c.shape, pegs)
            print(f"{name} {size}: {c.shape[1]} x {c.shape[0]}, {pegs} pegs, colours {[NAMES[v - 1] for v in sorted(set(c[c > 0]))]}")
            lines.append(f"= {name} {size} {c.shape[1]} {c.shape[0]}")
            lines += ["".join(".12345678"[v] for v in row) for row in c]
            drawn.append((name, size, c))
    open(f"{out}/peg-board-charts.txt", "w").write("\n".join(lines) + "\n")
    if len(sys.argv) > 2:                                      # the charts of one size as plain discs, to look at while drawing
        size = sys.argv[3] if len(sys.argv) > 3 else "large"
        colours = [(188, 65, 50), (192, 65, 87), (201, 105, 56), (185, 159, 65), (66, 179, 66), (44, 95, 179), (138, 72, 178), (240, 204, 158)]
        s = SIZES[size]; q = 16 // s; cw, ch = COLS * s * q + 24, int(ROWS * s * q * RISE) + 40
        mine = [(n, c) for n, z, c in drawn if z == size]
        sheet = Image.new("RGB", (4 * cw, -(-len(mine) // 4) * ch), (0, 0, 0)); d = ImageDraw.Draw(sheet)
        for n, (label, c) in enumerate(mine):
            x0, y0 = (n % 4) * cw + 12, (n // 4) * ch + 24
            d.text((x0, y0 - 18), f"{label} {size} ({c.shape[1]} by {c.shape[0]}, {int((c > 0).sum())} pegs)", fill=(200, 200, 200))
            for top in range(c.shape[0]):
                for col in range(c.shape[1]):
                    x, y = x0 + (col + 0.5 * ((c.shape[0] - 1 - top) & 1) + 0.5) * q, y0 + (top * RISE + 0.5) * q
                    d.ellipse([x - 0.46 * q, y - 0.46 * q, x + 0.46 * q, y + 0.46 * q], fill=colours[c[top, col] - 1] if c[top, col] else (22, 22, 22))
        sheet.save(sys.argv[2])
