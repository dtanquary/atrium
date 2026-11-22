"""Round 1's sheets: each a list of (caption, mock.swift settings). sheet.py draws them.

Every tile is the same real afternoon: NL.HGN (the Netherlands) on 2026-11-16, the sheet's day in US Central time,
the pen at 16:50, eighty minutes into the train of the M6.6 Banda Sea quake (21:11 UTC, 117° away), with the 15th as
yesterday under it. traces.py makes the traces; SEISMO_DATA is the directory it made them in.
"""
import os, tempfile

DATA = os.path.join(os.environ.get("SEISMO_DATA", os.path.join(tempfile.gettempdir(), "seismo-data")), "traces")


def day(band="long", **kw):
    """The standard tile: Chart, the long-period band, 30-minute rows, the flat sheet, at 16:50 on the 16th."""
    rate = 1 if band == "long" else 40
    return {"trace": f"{DATA}/{band}-2026-11-16.f32", "yesterday": f"{DATA}/{band}-2026-11-15.f32", "rate": rate,
            "now": (16 + 50 / 60) * 3600, "view": "sheet", "surface": "Chart", "pen": 2.0, "fade": 0.5, "marks": 0.12, **kw}


BLUES = [[30, 52, 104], [38, 72, 138], [54, 90, 158], [72, 110, 172]]  # research-look.md §3, the USGS's four blues dimmed

SHEETS = {
    "sheet1-view": [
        ("A  Flat sheet: the day as a page, today over yesterday", day()),
        ("B  The last 24 hours, the newest row at the bottom", day(view="roll")),
        ("C  The drum upright: the paper turns past a still pen", day(view="drum")),
        ("D  The drum as recorders stand: rows run up it", day(view="drum-real")),
    ],
    "sheet2-surface": [
        ("A  Chart: dimmed cream, black-brown ink", day()),
        ("B  Paper (Etching's)", day(surface="Paper")),
        ("C  Parchment, sepia (Etching's)", day(surface="Parchment")),
        ("D  Blue ink, four blues by row", day(surface="Blueprint", inks=BLUES)),
        ("E  Smoked: a scratch through soot", day(surface="Smoked", fade=0.3)),
        ("F  Paper Dark: chalk on charcoal (Etching's)", day(surface="Paper", tone="dark", fade=0.3)),
    ],
    "sheet3-band": [
        ("A  Long period (15 to 50 s): quakes from anywhere", day()),
        ("B  Short period (0.5 to 8 Hz): local quakes, the day's hum", day("short", pen=1.6)),
        ("C  Raw: the ocean's microseism fills it", day("broad", pen=1.6)),
        ("D  Long period, half the gain", day(gain=0.5)),
    ],
    "sheet4-rows": [
        ("A  15 minutes a row, 96 rows", day(minutes=15, pen=1.5)),
        ("B  30 minutes a row, 48 rows", day()),
        ("C  60 minutes a row, 24 rows", day(minutes=60, pen=2.4)),
    ],
    "sheet5-desk": [
        ("Flat sheet, Chart, long period, 30 minutes a row: 16:50 on 16 Nov, an M6.6 eighty minutes in", day()),
    ],
    # 12 s at the real pace: the pen crawls 1.7 device pixels a second on the sheet; round the upright drum the
    # paper slides 5.4 a second under a still pen.
    "film1-pen": [("", day(frames=360, fps=30))],
    "film2-drum": [("", day(view="drum", frames=360, fps=30))],
    # the same 12 s at 1:1, 1,000 by 600 device pixels round the pen, where its crawl can be seen
    "film3-pen-close": [("", day(frames=360, fps=30, crop=[1500, 1050, 1000, 600]))],
    # time-lapses, to show what the pace hides (not a proposed speed): the M6.6's train written from 15:20 to 16:50
    # at 450 times, and the whole of the 16th at 7,200 times, a row each quarter second
    "film4-quake-timelapse": [("", day(now=(15 + 20 / 60) * 3600, speed=450, frames=360, fps=30))],
    "film5-day-timelapse": [("", day(now=0, speed=7200, frames=360, fps=30))],
}
