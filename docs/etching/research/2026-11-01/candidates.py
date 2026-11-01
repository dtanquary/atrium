"""Every candidate of the 2026-11-01 research round, picked or not, as each researcher had it in a copy of bake.py.
Imported by nothing: to bake one, copy its entry (and any constant above it) into bake.py's PICTURES. The maps'
entries with `specks` need `despeckled`, at the bottom. candidates.md says which were picked, the licences as read
and why the rest were not; the contact sheets beside it (art.jpg, blueprints.jpg, wwii.jpg, maps.jpg) show them."""
WELLCOME = "https://iiif.wellcomecollection.org/image/%s/full/max/0/default.jpg"

# ---- art and natural history ----
# the wildcard round, 2026-11-01: fine-art prints, natural history and ornament (research copy only)
MET = "https://images.metmuseum.org/CRDImages/%s/original/%s.jpg"
WELL = "https://iiif.wellcomecollection.org/image/%s/full/max/0/default.jpg"
RIJKS = "https://iiif.micr.io/%s/full/max/0/default.jpg"
ART = {
    "fujimigahara": ("36500-DP140982.jpg", MET % ("as", "DP140982"), (0.02, 0.075, 0.97, 0.955), 1.0, dict(lift=0.2, flatten="paper", blank=[(0.0, 0.0, 0.135, 0.29)])),   # the sky's graded blue flattened away; the title and signature painted out
    "shono": ("36521-DP122216.jpg", MET % ("as", "DP122216"), (0.12, 0.10, 0.955, 0.925), 1.6, dict(lift=0.15)),
    "fujiatsea": ("57793-LC-JIB108_a_b_b_010.jpg", MET % ("as", "LC-JIB108_a_b_b_010"), (0.03, 0.167, 0.948, 0.91), 1.0, dict(lift=0.2, flatten="paper", blank=[(0.42, 0.0, 0.54, 1.0), (0.925, 0.0, 1.0, 0.07)])),
    "penship": ("358328-DP161559.jpg", MET % ("dp", "DP161559"), (0.01, 0.02, 0.98, 0.93), 0.7, {}),
    "horseskeleton": ("359031-DP353983.jpg", MET % ("dp", "DP353983"), (0.08, 0.24, 0.95, 0.91), 1.0, dict(lift=0.15)),
    "maze": ("rijks-200458486.jpg", RIJKS % "WBrGk", (0.115, 0.11, 0.90, 0.83), 1.4, dict(blank=[(0.128, 0.0, 0.447, 0.075), (0.97, 0.0, 1.0, 0.09), (0.70, 0.055, 0.98, 0.125), (0.86, 0.91, 0.95, 0.955), (0.59, 0.955, 0.85, 1.0), (0.20, 0.37, 0.34, 0.405), (0.245, 0.46, 0.325, 0.50)])),
    "venuscomb": ("rijks-RP-P-1992-16.jpg", RIJKS % "MoMvw", (0.03, 0.03, 0.975, 0.885), 1.0, dict(lift=0.15)),
    "nautilus": ("rijks-RP-P-OB-11.659.jpg", RIJKS % "hvoTh", (0.0, 0.01, 1.0, 0.94), 1.0, dict(lift=0.2, blank=[(0.0, 0.0, 0.04, 1.0), (0.96, 0.0, 1.0, 1.0)])),
    "clams": ("rijks-RP-P-1920-2772.jpg", RIJKS % "AQXHi", (0.07, 0.115, 0.915, 0.86), 1.0, dict(lift=0.2, blank=[(0.09, 0.07, 0.19, 0.20)])),
    "seaserpent": ("wellcome-V0021194.jpg", WELL % "V0021194", (0.02, 0.065, 0.912, 0.95), 1.0, dict(lift=0.4, blank=[(0.0, 0.0, 1.0, 0.04), (0.95, 0.0, 1.0, 0.24), (0.92, 0.55, 1.0, 1.0), (0.0, 0.70, 0.04, 1.0), (0.09, 0.74, 0.16, 0.88)])),
    "unicorn": ("wellcome-V0021193.jpg", WELL % "V0021193", (0.0, 0.04, 1.0, 1.0), 1.0, dict(lift=0.3)),
    "elephant": ("wellcome-V0021192.jpg", WELL % "V0021192", (0.03, 0.0, 0.93, 0.97), 1.0, dict(lift=0.3, blank=[(0.0, 0.8, 0.06, 0.9)])),
    "gorgon": ("wellcome-L0028396.jpg", WELL % "L0028396", (0.02, 0.03, 0.98, 0.99), 1.0, dict(lift=0.2, blank=[(0.08, 0.0, 0.30, 0.07), (0.75, 0.0, 1.0, 0.07)])),
    "megatherium": ("wellcome-V0016986.jpg", WELL % "V0016986", (0.03, 0.02, 0.97, 0.93), 1.0, dict(lift=0.25, flatten="paper", blank=[(0.0, 0.0, 1.0, 0.14), (0.28, 0.14, 0.72, 0.19)])),
    "sanchu": ("36505-DP140987.jpg", MET % ("as", "DP140987"), (0.025, 0.05, 0.975, 0.96), 1.0, dict(lift=0.15, flatten="paper")),
    "malghera": ("cma-1925.1239.2_print.jpg", "https://openaccess-cdn.clevelandart.org/1925.1239.2/1925.1239.2_print.jpg", (0.025, 0.03, 0.98, 0.955), 1.0, {}),
}

# ---- blueprints and engineering ----
PLANS = {
    # research, 2026-11-01: blueprints and engineering drawings
    "neuilly": ("perronet-0117.jp2", "https://archive.org/download/chepfl-lipr-axd-20-01/CHEPFL_LIPR_AXD20_01_jp2.zip/CHEPFL_LIPR_AXD20_01_jp2%2FCHEPFL_LIPR_AXD20_01_0117.jp2",
                (0.2028, 0.14, 0.5156, 0.4225), 1.0,
                dict(blank=[(0.44, 0.0, 1.0, 0.075), (0.0, 0.15, 0.05, 0.22), (0.105, 0.025, 0.152, 0.055), (0.302, 0.025, 0.348, 0.055),
                            (0.437, 0.15, 0.483, 0.178), (0.88, 0.15, 0.926, 0.178), (0.59, 0.255, 0.775, 0.288), (0.474, 0.437, 0.538, 0.466)])),
    "garabit": ("garabit-0034.jp2", "https://archive.org/download/TA624282EIF/TA624282EIF_jp2.zip/TA624282EIF_jp2%2FTA624282EIF_0034.jp2",
                (0.375, 0.172, 0.685, 0.634), 1.0,
                dict(lift=0.3, flatten="paper", blank=[(0.0, 0.0, 1.0, 0.075), (0.474, 0.20, 0.512, 0.93), (0.395, 0.495, 0.585, 0.556), (0.088, 0.31, 0.103, 0.39),
                     (0.884, 0.29, 0.898, 0.36), (0.10, 0.715, 0.135, 0.75), (0.855, 0.64, 0.887, 0.67), (0.077, 0.69, 0.092, 0.71), (0.435, 0.925, 0.555, 0.95), (0.49, 0.97, 0.51, 1.0)])),
    "plough": ("wellcome-V0024680.jpg", WELLCOME % "V0024680", (0.03, 0.0, 0.968, 0.99), 0.8,
               dict(lift=0.25, flatten="paper", blank=[(0.144, 0.146, 0.501, 0.182), (0.299, 0.318, 0.341, 0.341), (0.0, 0.96, 0.773, 1.0), (0.927, 0.965, 1.0, 1.0),
                                                      (0.0, 0.03, 0.612, 0.062), (0.693, 0.03, 1.0, 0.062)])),   # inside the plate's border; title, imprint and scale painted out
    "crane": ("wellcome-V0024542.jpg", WELLCOME % "V0024542", (0.10, 0.06, 0.90, 0.90), 1.0,
              dict(lift=0.15, flatten="paper", blank=[(0.33, 0.06, 1.0, 0.25)])),
    "allerton": ("aic-215760.jpg", "https://www.artic.edu/iiif/2/ca5a19d3-5175-a64e-09fb-55ec14596718/full/3000,/0/default.jpg", (0.0475, 0.005, 0.845, 0.915), 1.0,
                 dict(lift=0.15, flatten="paper", blank=[(0.486, 0.111, 0.765, 0.223), (0.464, 0.254, 0.599, 0.276), (0.655, 0.225, 0.822, 0.295),
                                                        (0.696, 0.28, 0.742, 0.345), (0.365, 0.0, 0.405, 0.09)])),   # titles, the weathervane's arrow and the dome's finial painted out
    "locomotive": ("si-CHSDM-B4BB877E6CF52-000001.jpg", "https://ids.si.edu/ids/deliveryService?id=CHSDM-B4BB877E6CF52-000001", (0.10, 0.13, 0.89, 0.84), 1.0,
                   dict(lift=0.12, blank=[(0.09, 0.0, 0.17, 0.09), (0.0, 0.94, 0.12, 1.0), (0.79, 0.96, 1.0, 1.0), (0.955, 0.86, 1.0, 0.925)])),   # a stain, and the student's name and prize painted out
    "buddicom": ("armengaud-0082.jp2", "https://archive.org/download/CHEPFL_LIPR_AXB233_03/CHEPFL_LIPR_AXB233_03_jp2.zip/CHEPFL_LIPR_AXB233_03_jp2%2FCHEPFL_LIPR_AXB233_03_0082.jp2",
                 (0.15, 0.19, 0.84, 0.848), 1.0,
                 dict(lift=0.15, blank=[(0.0, 0.0, 0.142, 0.242), (0.142, 0.0, 0.16, 0.2), (0.615, 0.26, 0.66, 0.33), (0.655, 0.09, 0.72, 0.13), (0.16, 0.0, 0.66, 0.160), (0.17, 0.130, 0.35, 0.226), (0.35, 0.0, 0.62, 0.347),
                                        (0.63, 0.038, 0.82, 0.110), (0.9, 0.089, 1.0, 0.293)])),   # the plate's Figs. 12 and 9 and its captions painted out
    "sawmill": ("vanzyl-0182.jp2", "https://archive.org/download/chepfl-lipr-axd-19/CHEPFL_LIPR_AXD19_jp2.zip/CHEPFL_LIPR_AXD19_jp2%2FCHEPFL_LIPR_AXD19_0182.jp2",
                (0.125, 0.135, 0.925, 0.838), 1.0, dict(lift=0.15, flatten="paper", blank=[(0.0, 0.0, 1.0, 0.03)])),   # plate LI: its title painted out, above its scale
    "schooner": ("haer-ma1719-sheet02.tif", "https://tile.loc.gov/storage-services/master/pnp/habshaer/ma/ma1700/ma1719/sheet/00002a.tif", (0.055, 0.0, 0.88, 0.98), 0.7,
                 dict(blank=[(0.0, 0.0, 0.403, 0.033), (0.433, 0.0, 1.0, 0.033), (0.0, 0.054, 0.345, 0.159), (0.667, 0.066, 1.0, 0.133), (0.797, 0.155, 1.0, 0.352), (0.342, 0.178, 0.373, 0.217), (0.448, 0.157, 0.479, 0.196), (0.542, 0.259, 0.573, 0.298), (0.729, 0.4, 0.759, 0.439), (0.313, 0.489, 0.344, 0.528), (0.532, 0.629, 0.562, 0.668), (0.782, 0.635, 0.812, 0.674), (0.687, 0.707, 0.717, 0.746)])),   # HAER MA-168, sheet 2: the title, the sheet's border, the sail-area table and the sails' numbers painted out
    "holt": ("US0874008-p1.png", "https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/0874008", (0.44, 0.185, 0.93, 0.80), 1.0,
             dict(rot=-90, lift=0.2, blank=[(0.0, 0.7, 0.02, 0.9), (0.32, 0.05, 0.475, 0.14), (0.56, 0.07, 0.61, 0.14), (0.795, 0.615, 0.85, 0.68), (0.64, 0.615, 0.69, 0.655), (0.49, 0.74, 0.54, 0.775), (0.405, 0.715, 0.43, 0.75), (0.04, 0.7, 0.08, 0.73), (0.3, 0.52, 0.39, 0.58), (0.225, 0.525, 0.26, 0.565), (0.165, 0.265, 0.2, 0.31)])),   # the sheet is sideways; "Fig. 1", the inventor's line and the reference numerals painted out
}

# ---- WWII aircraft and ships ----
WWII = {
    # WWII research, 2026-11-01: US design patents, one figure each (the sheet's own page of the Office's PDF, pdfimages, as the airship)
    "b17": ("USD097355-p1.png", "https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/D097355", (0.075, 0.205, 0.71, 0.865), 1.0,
            dict(rot=-90, blank=[(0.0, 0.47, 0.14, 1.0), (0.0, 0.88, 0.3, 1.0), (0.83, 0.64, 0.93, 0.80)])),   # nose up; the signatures and "Fig. 1" painted out
    "p80": ("USD143822-p1.png", "https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/D143822", (0.05, 0.17, 0.84, 0.535), 1.0,
            dict(blank=[(0.325, 0.13, 0.49, 0.215), (0.965, 0.78, 1.0, 0.86)])),               # Fig. 1 alone; its label and a punch hole painted out
    "xp67": ("USD134426-p1.png", "https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/D134426", (0.16, 0.19, 0.79, 0.785), 1.0,
             dict(rot=-90, blank=[(0.39, 0.03, 0.47, 0.135)])),
    "a20": ("USD128027-p2.png", "https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/D128027", (0.07, 0.145, 0.72, 0.80), 1.0,
            dict(rot=-90, blank=[(0.0, 0.75, 0.068, 1.0), (0.0, 0.63, 0.03, 0.68), (0.24, 0.09, 0.42, 0.2)])),
    "electra": ("USD092654-p2.png", "https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/D092654", (0.22, 0.20, 0.80, 0.80), 1.0,
                dict(rot=-90, blank=[(0.01, 0.21, 0.125, 0.30)])),
    "b24": ("USD129529-p1.png", "https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/D129529", (0.06, 0.14, 0.622, 0.765), 1.0,
            dict(rot=90, blank=[(0.045, 0.52, 0.165, 0.60), (0.0, 0.0, 0.2, 0.025)])),   # nose up; "Figure 1" and the edge of "Figure 2" painted out
    # NACA's own three-view, in its wartime report L-334 (1942), page 24 of NTRS's PDF taken out with pdfimages -j
    "spitfire": ("naca-spitfire-000.jpg", "https://ntrs.nasa.gov/api/citations/19930092582/downloads/19930092582.pdf", (0.12, 0.497, 0.92, 0.902), 1.0,
                 dict(rot=180, lift=0.2, blank=[(0.0, 0.66, 0.44, 0.84), (0.13, 0.485, 0.31, 0.56), (0.88, 0.0, 0.93, 0.25), (0.03, 0.0, 0.10, 0.25), (0.115, 0.0, 0.15, 0.215), (0.85, 0.0, 0.885, 0.215)])),   # the plan view, nose up; caption and dimensions painted out
    # HAER VA-132, the Liberty ship Arthur M. Huddell (1943): Library of Congress master TIFFs of the sheets
    "libertylines": ("haer-va2040-00019a.tif", "https://tile.loc.gov/storage-services/master/pnp/habshaer/va/va2000/va2040/sheet/00019a.tif", (0.07, 0.105, 0.93, 0.645), 1.0,
                     dict(blank=[(0, 0, 0.048, 0.306), (0.03, 0, 0.085, 0.061), (0.185, 0, 0.28, 0.066), (0.078, 0.31, 0.1, 0.48), (0, 0.565, 0.048, 0.611),
                                 (0.03, 0.615, 0.30, 0.68), (0.64, 0.613, 0.988, 0.661), (0.76, 0, 0.94, 0.028), (0.941, 0, 1, 0.315), (0.75, 0.296, 0.915, 0.375),
                                 (0.89, 0.293, 0.945, 0.34), (0.918, 0.30, 0.94, 0.475), (0.442, 0.352, 0.57, 0.426), (0.938, 0.463, 1, 0.613), (0.395, 0.643, 0.605, 0.713),
                                 (0.40, 0.72, 0.452, 1), (0.577, 0.72, 0.65, 1)])),   # sheer, half-breadth and body plans; every label painted out
    "liberty": ("haer-va2040-00002a.tif", "https://tile.loc.gov/storage-services/master/pnp/habshaer/va/va2000/va2040/sheet/00002a.tif", (0.27, 0.175, 0.63, 0.495), 1.0, {}),   # the outboard profile's middle: the house and two masts
    # Sjöhistoriska museet: a 20 m motor torpedo boat (launched 1942, Kockums), Föreningen Sveriges Flotta's model drawing, sheet 1, 1946
    "mtb": ("dimu-mtb1946-bild1.jpg", "https://mm.dimu.org/image/032uK3D2krCA?dimension=max", (0.05, 0.06, 0.662, 0.635), 1.0,
            dict(lift=0.15, blank=[(0.062, 0.532, 0.163, 0.577), (0.76, 0.54, 0.882, 0.612), (0.882, 0.543, 1, 0.62), (0.975, 0.50, 1, 0.525), (0.08, 0.524, 1, 0.545), (0.965, 0.60, 1, 0.66)])),   # profile over plan; the notes painted out
}

# ---- maps (crater_b, romsdal, toroweap_c, marble_c, sogn_t, iceland_b, fisk_b, yosemite_b, mtdesert_b are the ones on the sheet; the rest are trials) ----
MAPS = {
    # maps, 2026-11-01 (research)
    "yosemite": ("lev-4m90fc57z.jpg", "https://iiif.digitalcommonwealth.org/iiif/2/commonwealth:4m90fc57z/full/full/0/default.jpg", (0.067, 0.122, 0.924, 0.874), 1.0,
                 dict(blank=[(0.0, 0.0, 0.167, 0.252)])),
    "sierra": ("lev-4m90fc55d.jpg", "https://iiif.digitalcommonwealth.org/iiif/2/commonwealth:4m90fc55d/full/full/0/default.jpg", (0.068, 0.10, 0.918, 0.888), 1.5,
               dict(lift=0.35, blank=[(0.0, 0.0, 0.30, 0.23)])),
    "toroweap": ("dutton-0025.jp2", "https://archive.org/download/atlasaccompanym00dutt/atlasaccompanym00dutt_jp2.zip/atlasaccompanym00dutt_jp2%2Fatlasaccompanym00dutt_0025.jp2",
                 (0.075, 0.062, 0.925, 0.913), 1.0, dict(lift=0.25)),
    "marble": ("dutton-0081.jp2", "https://archive.org/download/atlasaccompanym00dutt/atlasaccompanym00dutt_jp2.zip/atlasaccompanym00dutt_jp2%2Fatlasaccompanym00dutt_0081.jp2",
               (0.075, 0.065, 0.925, 0.91), 1.0, dict(lift=0.25)),
    "trumbull": ("dutton-0041.jp2", "https://archive.org/download/atlasaccompanym00dutt/atlasaccompanym00dutt_jp2.zip/atlasaccompanym00dutt_jp2%2Fatlasaccompanym00dutt_0041.jp2",
                 (0.075, 0.065, 0.925, 0.91), 1.0, dict(lift=0.25)),
    "mtdesert": ("lev-3f462w46k.jpg", "https://iiif.digitalcommonwealth.org/iiif/2/commonwealth:3f462w46k/full/full/0/default.jpg", (0.05, 0.18, 0.95, 0.625), 1.0, {}),
    "iceland": ("lev-ht250b072.jpg", "https://iiif.digitalcommonwealth.org/iiif/2/commonwealth:ht250b072/full/full/0/default.jpg", (0.06, 0.05, 0.95, 0.88), 1.0,
                dict(blank=[(0.78, 0.74, 1.0, 0.95)])),
    "gulfstream": ("lev-z603vr47j.jpg", "https://iiif.digitalcommonwealth.org/iiif/2/commonwealth:z603vr47j/full/full/0/default.jpg", (0.055, 0.175, 0.905, 0.84), 1.0, {}),
    "fisk": ("fisk-22-6.jpg", "https://biotech.law.lsu.edu/climate/mississippi/fisk/plate_22-6.pdf", (0.02, 0.15, 0.72, 0.44), 1.0, {}),
    "yosemite_b": ("lev-4m90fc57z.jpg", "", (0.067, 0.122, 0.924, 0.874), 1.5, dict(lift=0.35, blank=[(0.0, 0.0, 0.167, 0.252)])),
    "yosemite_c": ("lev-4m90fc57z.jpg", "", (0.067, 0.122, 0.924, 0.874), 1.3, dict(lift=0.5, blank=[(0.0, 0.0, 0.167, 0.252)])),
    "yosemite_d": ("lev-4m90fc57z.jpg", "", (0.067, 0.122, 0.924, 0.874), 1.8, dict(lift=0.25, blank=[(0.0, 0.0, 0.167, 0.252)])),
    "toroweap_b": ("dutton-0025.jp2", "", (0.075, 0.062, 0.925, 0.913), 1.3, dict(lift=0.4)),
    "marble_b": ("dutton-0081.jp2", "", (0.075, 0.065, 0.925, 0.91), 1.3, dict(lift=0.4)),
    "trumbull_b": ("dutton-0041.jp2", "", (0.075, 0.065, 0.925, 0.91), 1.3, dict(lift=0.4)),
    "iceland_b": ("lev-ht250b072.jpg", "", (0.06, 0.05, 0.95, 0.88), 1.3, dict(lift=0.45, blank=[(0.78, 0.74, 1.0, 0.95)])),
    "crater": ("lev-4m90fc943.jpg", "https://iiif.digitalcommonwealth.org/iiif/2/commonwealth:4m90fc943/full/full/0/default.jpg", (0.07, 0.225, 0.93, 0.69), 1.3, dict(lift=0.3)),
    "rainier": ("lev-4m90fd64k.jpg", "https://iiif.digitalcommonwealth.org/iiif/2/commonwealth:4m90fd64k/full/full/0/default.jpg", (0.06, 0.21, 0.94, 0.78), 1.3, dict(lift=0.3)),
    "brightangel": ("lev-cj82m642f.jpg", "https://iiif.digitalcommonwealth.org/iiif/2/commonwealth:cj82m642f/full/full/0/default.jpg", (0.06, 0.27, 0.94, 0.71), 1.0, dict(lift=0.2)),
    "mtdesert_b": ("lev-3f462w46k.jpg", "", (0.05, 0.18, 0.95, 0.625), 1.4, dict(lift=0.25)),
    "toroweap_c": ("dutton-0025.jp2", "", (0.075, 0.062, 0.925, 0.913), 1.1, dict(lift=0.3)),
    "marble_c": ("dutton-0081.jp2", "", (0.075, 0.065, 0.925, 0.91), 1.1, dict(lift=0.3)),
    "trumbull_c": ("dutton-0041.jp2", "", (0.075, 0.065, 0.925, 0.91), 1.1, dict(lift=0.3)),
    "sogn": ("kv-93_amt1_nordre-bergenhus-amt-9-soe_1874.jpg", "https://kartverket.no/historiske/0/93_amt1_nordre-bergenhus-amt-9-soe_1874_jpg300dpi.jpg",
             (0.105, 0.085, 0.86, 0.645), 1.0, {}),
    "sogn_s": ("kv-93_amt1_nordre-bergenhus-amt-9-soe_1874.jpg", "", (0.105, 0.085, 0.86, 0.645), 1.0, dict(specks=(400, 150, 2))),
    "sogn_t": ("kv-93_amt1_nordre-bergenhus-amt-9-soe_1874.jpg", "", (0.105, 0.085, 0.86, 0.645), 1.4, dict(lift=0.2, specks=(400, 150, 2))),
    "crater_b": ("lev-4m90fc943.jpg", "", (0.07, 0.225, 0.93, 0.69), 1.5, dict(lift=0.4)),
    "fisk_b": ("fisk-22-6.jpg", "", (0.02, 0.15, 0.72, 0.44), 1.4, dict(lift=0.2)),
    "usrelief": ("lev-7h149z297.jpg", "https://iiif.digitalcommonwealth.org/iiif/2/commonwealth:7h149z297/full/full/0/default.jpg", (0.04, 0.06, 0.96, 0.92), 1.3,
                 dict(lift=0.3, blank=[(0.89, 0.67, 1.0, 0.85)])),
    "romsdal": ("kv-123_amt1_romsdals-amt-24-sv-1_1884.jpg", "https://kartverket.no/historiske/0/123_amt1_romsdals-amt-24-sv-1_1884_jpg300dpi.jpg",
                (0.18, 0.30, 0.95, 0.87), 1.4, dict(lift=0.2, specks=(400, 150, 2))),
    "romsdal_n": ("kv-123_amt1_romsdals-amt-24-sv-1_1884.jpg", "", (0.18, 0.30, 0.95, 0.87), 1.4, dict(lift=0.2)),
    "sheet6": ("dutton-0029.jp2", "https://archive.org/download/atlasaccompanym00dutt/atlasaccompanym00dutt_jp2.zip/atlasaccompanym00dutt_jp2%2Fatlasaccompanym00dutt_0029.jp2",
               (0.20, 0.18, 0.95, 0.93), 1.3, dict(lift=0.3)),
}

# ---- dinosaurs (the T. rex skull is rexskull, D10, and the whole T. rex rex, D10b) ----
# the dinosaur round, 2026-11-01. An Internet Archive book's file is its own JPEG of that leaf, `https://archive.org/download/<id>/page/n<leaf>.jpg`.
# Marsh's plates are printed sideways (rot=90); their crops sit inside each plate's ruled frame, below its running head and above its caption.
IA = "https://archive.org/download/%s/page/n%d.jpg"
MARSH = "dinosaursofnort00mars"
DINOSAURS = {
    "brontosaurus": ("marsh-n284.jpg", IA % (MARSH, 284), (0.10, 0.10, 0.935, 0.885), 0.7, dict(rot=90, blank=[(0.85, 0.0, 1.0, 0.04)])),
    "stegosaurus": ("marsh-n324.jpg", IA % (MARSH, 324), (0.10, 0.115, 0.94, 0.895), 0.7, dict(rot=90)),
    "triceratops": ("marsh-n400.jpg", IA % (MARSH, 400), (0.10, 0.11, 0.93, 0.89), 0.7, dict(rot=90)),
    "ceratosaurus": ("marsh-n172.jpg", IA % (MARSH, 172), (0.10, 0.10, 0.925, 0.89), 0.7, dict(rot=90, blank=[(0.97, 0.0, 1.0, 1.0)])),
    "claosaurus": ("marsh-n412.jpg", IA % (MARSH, 412), (0.10, 0.10, 0.93, 0.88), 0.7, dict(rot=90)),
    "iguanodonmarsh": ("marsh-n456.jpg", IA % (MARSH, 456), (0.10, 0.07, 0.92, 0.92), 0.7, dict(rot=90, blank=[(0.92, 0.0, 1.0, 1.0), (0.0, 0.0, 1.0, 0.025)])),
    "struthiomimus": ("osborn1917-n44.jpg", IA % ("bulletin-american-museum-natural-history-35-733-771", 44), (0.0, 0.065, 1.0, 0.885), 0.8, dict(blank=[(0.62, 0.48, 0.70, 0.52), (0.44, 0.94, 0.52, 0.98), (0.88, 0.48, 0.96, 0.52), (0.76, 0.46, 0.80, 0.50), (0.805, 0.52, 0.85, 1.0), (0.585, 0.80, 0.61, 1.0), (0.585, 0.55, 0.61, 0.70), (0.05, 0.83, 0.09, 1.0), (0.585, 0.0, 0.61, 0.27)])),
    "plesiosaurus": ("conybeare1824-n600.jpg", IA % ("per_geological-society-london-trans_transactions-of-the-geological-society_1824_1", 600), (0.035, 0.03, 0.962, 0.86), 1.0, dict(blank=[(0.75, 0.036, 1.0, 0.084), (0.40, 0.0, 0.68, 0.06), (0.44, 0.40, 0.68, 0.455), (0.72, 0.585, 0.97, 0.625), (0.32, 0.935, 0.52, 0.97), (0.69, 0.80, 0.84, 0.84), (0.86, 0.82, 0.99, 0.88), (0.6, 0.95, 0.85, 1.0), (0.985, 0.0, 1.0, 1.0)])),
    "cryptocleidus": ("andrews1910-n217.jpg", IA % ("descriptivecatal01brit", 217), (0.145, 0.10, 0.85, 0.93), 0.8, dict(rot=-90, lift=0.2, blank=[(0.45, 0.19, 0.58, 0.25), (0.2, 0.80, 0.87, 0.86), (0.0, 0.0, 0.06, 1.0), (0.0, 0.0, 1.0, 0.02)])),
    "scelidosaurus": ("guide1905-n50.jpg", IA % ("guidetofossilrep8190bmnh", 50), (0.015, 0.12, 0.97, 0.497), 0.8, dict(lift=0.15, blank=[(0.9, 0.1, 1.0, 0.2)])),
    # T. rex: Osborn's own drawings of AMNH 5027 and 973. The 1912 memoir's file is the figure as embedded in the AMNH digital library's PDF
    # (`pdfimages -j -f 54 -l 54`, the second image on p. 54, Fig. 2 of the skull in side view), renamed.
    "rexskull": ("osborn1912-p54.jpg", "https://digitallibrary.amnh.org/server/api/core/bitstreams/c56a5e80-9468-4703-979e-fabbe65344f0/content", (0.0, 0.0, 1.0, 1.0), 1.0,
                 dict(lift=0.3, blank=[(0.072, 0.63, 0.282, 0.6625), (0.282, 0.6275, 0.372, 0.655), (0.212, 0.852, 0.30, 0.90), (0.30, 0.855, 0.40, 0.89),   # the rows of foramina dots
                                       (0.41, 0.835, 0.43, 0.855), (0.45, 0.77, 0.465, 0.79), (0.48, 0.80, 0.495, 0.82), (0.07, 0.565, 0.118, 0.595), (0.25, 0.567, 0.29, 0.592),
                                       (0.41, 0.865, 0.45, 0.89), (0.47, 0.61, 0.51, 0.64), (0.462, 0.672, 0.492, 0.70), (0.535, 0.60, 0.57, 0.63), (0.0, 0.70, 0.10, 0.80),
                                       (0.555, 0.0, 0.645, 0.065), (0.84, 0.0, 1.0, 0.095), (0.48, 0.10, 0.53, 0.14), (0.33, 0.2, 0.40, 0.272), (0.14, 0.30, 0.235, 0.355), (0.17, 0.33, 0.255, 0.375),
                                        (0.03, 0.45, 0.11, 0.49), (0.0, 0.545, 0.06, 0.585), (0.0, 0.70, 0.09, 0.88), (0.07, 0.78, 0.18, 0.84), (0.745, 0.905, 0.85, 1.0), (0.86, 0.85, 1.0, 1.0), (0.91, 0.735, 0.95, 0.78)])),
    "rexskull1906": ("osborn1906-n4.jpg", IA % ("bulletin-american-museum-natural-history-22-281-296", 4), (0.06, 0.31, 0.765, 0.668), 0.8,
                     dict(lift=0.15, blank=[(0.10, 0.40, 0.19, 0.50), (0.09, 0.52, 0.155, 0.61), (0.48, 0.33, 0.53, 0.41), (0.355, 0.41, 0.405, 0.49), (0.665, 0.23, 0.725, 0.31), (0.58, 0.14, 0.62, 0.20),
                                            (0.81, 0.06, 0.90, 0.135), (0.62, 0.68, 0.72, 0.76), (0.40, 0.87, 0.45, 0.94), (0.88, 0.82, 1.0, 1.0)])),
    "rex": ("osborn1906-n16.jpg", IA % ("bulletin-american-museum-natural-history-22-281-296", 16), (0.085, 0.015, 1.0, 0.905), 0.8,
            dict(lift=0.15, blank=[(0.89, 0.86, 0.99, 0.945), (0.55, 0.90, 0.64, 1.0)])),   # the plate's scale and caption cropped away; the man for scale kept
    "iguanodon": ("guide1905-n52.jpg", IA % ("guidetofossilrep8190bmnh", 52), (0.0, 0.275, 0.92, 0.612), 1.0, dict(blank=[(0.54, 0.42, 0.6, 0.5), (0.545, 0.54, 0.58, 0.58), (0.1, 0.0, 0.16, 0.04)])),
}

# ---- the PBY Catalina (W10) ----
CATALINA = {
    "pby": ("ia-an015ma2-n11.jpg", "https://archive.org/download/handbook-of-erection-and-maint.-instructions-navy-pby-5/page/n11.jpg", (0.05, 0.505, 0.88, 0.87), 1.0,
            dict(lift=0.25, blank=[(0.46, 0.0, 0.55, 0.025), (0.0, 0.025, 1.0, 0.095), (0.503, 0.0, 0.518, 0.121), (0.03, 0.095, 0.047, 0.232), (0.972, 0.095, 0.99, 0.228), (0.475, 0.095, 0.6, 0.121), (0.618, 0.12, 0.73, 0.168), (0.42, 0.461, 0.61, 0.51), (0.508, 0.461, 0.517, 0.735), (0.2, 0.51, 0.8, 0.553), (0.205, 0.548, 0.372, 0.566), (0.205, 0.566, 0.2145, 0.775), (0.366, 0.566, 0.372, 0.652), (0.4, 0.582, 0.575, 0.608), (0.1, 0.645, 0.318, 0.659), (0.1, 0.659, 0.205, 0.738), (0.1, 0.738, 0.271, 0.746), (0.1, 0.746, 0.205, 0.895), (0.1, 0.86, 0.249, 0.874), (0.1, 0.874, 0.249, 0.905), (0.249, 0.895, 0.257, 0.905), (0.1, 0.905, 0.93, 1.0), (0.205, 0.815, 0.2145, 0.905), (0.508, 0.785, 0.517, 0.822), (0.508, 0.836, 0.517, 0.86), (0.508, 0.868, 0.517, 0.905), (0.59, 0.868, 0.6, 0.905), (0.597, 0.858, 0.93, 0.872), (0.765, 0.548, 0.781, 0.584), (0.79, 0.578, 0.93, 0.594), (0.825, 0.594, 0.93, 0.858), (0.755, 0.772, 0.825, 0.812), (0.725, 0.812, 0.83, 0.862), (0.77, 0.762, 0.778, 0.772), (0.985, 0.87, 1.0, 0.9), (0.0, 0.94, 0.05, 1.0), (0.262, 0.896, 0.275, 0.905), (0.414, 0.896, 0.427, 0.905), (0.443, 0.868, 0.452, 0.905), (0.778, 0.762, 0.8, 0.772)])),   # the front view over the side view; the plan view above, and every dimension, painted out
}

# The maps researcher's despeckle step, called first thing in darkness() as `if specks: im = despeckled(im, specks)`.
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

def despeckled(im, specks):
    """Research only: small isolated dark marks (lettering, symbols) painted out as paper. `specks` is (largest
    mark in pixels of the source, darkness threshold 0..255, how far round each mark to paint, in pixels)."""
    most, thr, grow = specks
    a = np.asarray(im, np.uint8)
    ink = a < thr
    lab, n = ndi.label(ink, np.ones((3, 3)))
    size = ndi.sum(ink, lab, np.arange(n + 1))
    small = (size[lab] <= most) & ink
    if grow: small = ndi.binary_dilation(small, iterations=grow) & (a < 250)
    out = a.copy(); out[small] = np.percentile(a, 97)
    return Image.fromarray(out)
