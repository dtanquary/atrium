"""Makes the mock-ups' traces from real records: python3 -I traces.py fetch|make <data dir>.

fetch: one archive request per span (not polling, which EarthScope forbids: research-method.md, Terms of use) into the
  data directory, which should be new and empty: NL.HGN in the Netherlands from ORFEUS (CC BY 4.0, declared by the NL
  network's DOI record, checked in research-method.md), LHZ (1 a second) for the long-period band and BHZ (40 a second)
  for short period, and the USGS's list of quakes over M5 (public domain).
make: each sheet's day, midnight to midnight in the sheet's own time zone (US Central here, UTC-6), filtered as the app
  would filter it, causally, by two biquads each way (Butterworth, fourth order), and scaled as the research recommends:
  a row's spacing is 13 times the band's median minute RMS, so the quiet line trembles about a fifth of a row either
  way. Written as little-endian Float32 from the sheet's midnight to <data dir>/traces/<band>-<date>.f32, which
  mock.swift reads as `trace` (1.0 is a row's spacing).
"""
import datetime as dt, math, os, subprocess, sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)  # run with python3 -I: only this folder, never the downloads'
import mseed

ZONE = dt.timezone(dt.timedelta(hours=-6))  # the sheet's day: US Central, as a desktop there would show it
SHEETS = ["2026-11-15", "2026-11-16"]  # the 16th has the M6.6 Banda Sea train at 15:30 local; the 15th is its yesterday
BANDS = {"long": ("LHZ", 1, 0.02, 0.1), "short": ("BHZ", 40, 0.5, 8.0), "broad": ("BHZ", 40, 0.05, 8.0)}  # channel, rate, Hz band;
# broad is the raw trace, only its drift taken off, which the research found the ocean's microseism fills
UA = "generic-client/1.0"


def fetch(d):
    start = dt.datetime.fromisoformat(SHEETS[0]).replace(tzinfo=ZONE) - dt.timedelta(hours=6)  # filters settle first
    end = dt.datetime.fromisoformat(SHEETS[-1]).replace(tzinfo=ZONE) + dt.timedelta(days=1)
    q = f"starttime={start.astimezone(dt.timezone.utc):%Y-%m-%dT%H:%M:%S}&endtime={end.astimezone(dt.timezone.utc):%Y-%m-%dT%H:%M:%S}"
    for cha in sorted({c for c, _, _, _ in BANDS.values()}):
        subprocess.run(["curl", "-sf", "-A", UA, "-o", f"{d}/HGN-{cha}.mseed",
                        f"https://www.orfeus-eu.org/fdsnws/dataselect/1/query?net=NL&sta=HGN&loc=02&cha={cha}&{q}"], check=True)
    subprocess.run(["curl", "-sf", "-A", UA, "-o", f"{d}/usgs.geojson",
                    f"https://earthquake.usgs.gov/fdsnws/event/1/query?format=geojson&{q}&minmagnitude=5"], check=True)


def biquads(rate, lo, hi):
    """Fourth-order Butterworth high-pass at lo and low-pass at hi, as four biquads (RBJ's cookbook, bilinear)."""
    out = []
    for f, high in ((lo, True), (hi, False)):
        for q in (0.5412, 1.3066):
            w = 2 * math.pi * f / rate
            c, a = math.cos(w), math.sin(w) / (2 * q)
            b = [(1 + c) / 2, -(1 + c), (1 + c) / 2] if high else [(1 - c) / 2, 1 - c, (1 - c) / 2]
            a0 = 1 + a
            out.append(([x / a0 for x in b], [-2 * c / a0, (1 - a) / a0]))
    return out


def run(x, sections):
    """The biquads one after another, sample by sample, as the app would run them as records land."""
    y = list(map(float, x))
    for (b0, b1, b2), (a1, a2) in sections:
        x1 = x2 = y1 = y2 = 0.0
        for i, v in enumerate(y):
            o = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2, x1, y2, y1 = x1, v, y1, o
            y[i] = o
    return np.array(y)


def make(d):
    os.makedirs(f"{d}/traces", exist_ok=True)
    for band, (cha, rate, lo, hi) in BANDS.items():
        t0, r, x = mseed.trace(f"{d}/HGN-{cha}.mseed")
        assert r == rate, (cha, r)
        gaps = np.isnan(x)
        x = np.where(gaps, 0.0, x - np.nanmean(x[: rate * 600]))
        y = run(x, biquads(rate, lo, hi))
        settle = rate * 3600  # the first hour rings
        n = (len(y) - settle) // (rate * 60) * rate * 60
        rms = np.sqrt((y[settle:settle + n].reshape(-1, rate * 60) ** 2).mean(1))
        y = y / (13 * np.median(rms))
        y[gaps] = np.nan
        for day in SHEETS:
            midnight = dt.datetime.fromisoformat(day).replace(tzinfo=ZONE)
            i = int(round((midnight - t0).total_seconds() * rate))
            out = y[i:i + 86400 * rate].astype("<f4")
            out.tofile(f"{d}/traces/{band}-{day}.f32")
            print(band, day, f"{len(out) / rate / 3600:.1f} h, gaps {np.isnan(out).mean() * 100:.2f}%, "
                  f"over a row {np.mean(np.abs(out) > 1) * 100:.2f}%, peak {np.nanmax(np.abs(out)):.1f} rows")


if __name__ == "__main__":
    {"fetch": fetch, "make": make}[sys.argv[1]](sys.argv[2])
