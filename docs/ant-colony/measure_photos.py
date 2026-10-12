# measure_photos.py <folder of the photographs>: the colours the looks were begun from, off the reference photographs
# listed in docs/ant-colony.md ("Reference photographs"), each downloaded by hand under the name used here (the
# number in a name is its Flickr photo id). Boxes are fractions of each photo, picked by eye from contact sheets;
# sand and tunnel are told apart by brightness inside the box (its bright mode and its dark one), not by hand.
# None of the photographs is in the repository: several may not be copied. Run with python3 -I.
import sys, numpy as np
from PIL import Image
P = sys.argv[1] + "/"
def lum(a): return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
def box(name, x0, y0, x1, y1):
    im = Image.open(P + name).convert("RGB"); w, h = im.size
    return np.asarray(im.crop((int(x0 * w), int(y0 * h), int(x1 * w), int(y1 * h)))).astype(float)
def modes(a, lo, hi):
    L = lum(a).ravel(); c = a.reshape(-1, 3)
    return [tuple(int(v) for v in np.median(c[(L >= np.percentile(L, p0)) & (L <= np.percentile(L, p1))], axis=0)) for p0, p1 in (lo, hi)]
def show(label, cols):
    print(label, " ".join(f"{c} lum {lum(np.array(c, float)) / 255:.2f}" for c in cols))
a = box("flickr_sandfarm_antman3001_27383673142.jpg", 0.12, 0.49, 0.88, 0.76); show("A sand farm (mid): tunnel | sand", modes(a, (3, 12), (60, 95)))
L = lum(a); print("   share of the sand section that is tunnel (darker than midway):", f"{(L < (np.percentile(L, 5) + np.percentile(L, 90)) / 2).mean():.2f}")
a = box("flickr_sandfarm_zeldman_8142637940.jpg", 0.19, 0.50, 0.92, 0.70); show("B sand farm (late): tunnel | sand", modes(a, (3, 12), (60, 95)))
L = lum(a); print("   share that is tunnel:", f"{(L < (np.percentile(L, 5) + np.percentile(L, 90)) / 2).mean():.2f}")
a = box("flickr_gel_jurvetson_ants_in_space_2635075929.jpg", 0.42, 0.33, 0.83, 0.56); show("D gel, LED lit: ants | gel body | tunnel rims", modes(a, (0, 1.5), (30, 70)) + modes(a, (97, 99.5), (97, 99.5))[:1])
a = box("flickr_gel_jurvetson_ants_in_space_2635075929.jpg", 0.42, 0.33, 0.83, 0.40); show("   gel top:", modes(a, (40, 60), (40, 60))[:1])
a = box("flickr_gel_jurvetson_ants_in_space_2635075929.jpg", 0.42, 0.50, 0.83, 0.56); show("   gel bottom:", modes(a, (40, 60), (40, 60))[:1])
a = box("flickr_gel_jurvetson_ants_in_space_2635075929.jpg", 0.02, 0.02, 0.30, 0.20); show("   room:", modes(a, (40, 60), (40, 60))[:1])
a = box("flickr_gel_jurvetson_miners_5268677.jpg", 0.0, 0.0, 1.0, 1.0); show("G gel macro: ants | gel | bright", modes(a, (0, 2), (30, 60)) + modes(a, (95, 99), (95, 99))[:1])
a = box("flickr_closeup_keppens_lasius_3382430428.jpg", 0.05, 0.05, 0.95, 0.85); show("H fine sand nest: voids | sand", modes(a, (1, 5), (40, 90)))
L = lum(a); print("   share that is void:", f"{(L < (np.percentile(L, 2) + np.percentile(L, 70)) / 2).mean():.3f}")
a = box("flickr_closeup_fosterx2_4276960030.jpg", 0.53, 0.56, 0.76, 0.72); show("F harvester ant: dark parts | mid | glints", modes(a, (2, 15), (20, 40)) + modes(a, (45, 55), (45, 55))[:1])
a = box("flickr_closeup_fosterx2_4276215361.jpg", 0.46, 0.25, 0.56, 0.42); show("E ant on glass: dark | mid", modes(a, (5, 25), (40, 60)))
a = box("flickr_closeup_fosterx2_4276215361.jpg", 0.30, 0.20, 0.75, 0.90); show("E gallery back wall (shadowed sand) | lit sand", modes(a, (25, 45), (85, 97)))
