"""Fits where Saturn's six big moons are, for SaturnsRings.swift: python3 -I moons.py <empty download dir>.

JPL Horizons (https://ssd.jpl.nasa.gov/horizons/, ephemeris sat441l) gives each moon's place from Saturn's centre every
23 days from 2022 to 2041, and at five other moments to check against. To each this fits a small orbit in Saturn's
equator, the ring plane: a mean longitude that runs on at a steady rate (with a square and a cube of the time, which
take in Mimas's 71-year swing with Tethys), an eccentricity and an inclination, each with its own slowly turning
direction. Prints the numbers as SaturnsRings.swift's table, how far the fit is from Horizons, and the check moments
as SaturnsRingsTests.swift's table. Horizons' data is NASA/JPL's, free to use (https://ssd.jpl.nasa.gov/about/).
"""
import os, sys, urllib.parse, urllib.request
import numpy as np

MOONS = [("Mimas", 601, 381.9945), ("Enceladus", 602, 262.7319), ("Tethys", 603, 190.6979),
         ("Dione", 604, 131.5349), ("Rhea", 605, 79.6900), ("Titan", 606, 22.5770)]  # Horizons' number, degrees a day
EPOCH = 2461000.5            # 2025-11-21 00:00 UTC: the day the fit's time counts from
TDB = 69.184 / 86400         # Horizons' clock (TDB) runs this far ahead of UTC in these years
CHECKS = "'2461366.0','2461479.75','2463079.5','2464733.25','2462200.1'"


def fetch(folder, name, number, when):
    path = os.path.join(folder, f"{name}-{number}.txt")
    if not os.path.exists(path):
        query = {"format": "text", "COMMAND": f"'{number}'", "OBJ_DATA": "'NO'", "MAKE_EPHEM": "'YES'", "EPHEM_TYPE": "'VECTORS'",
                 "CENTER": "'500@699'", "VEC_TABLE": "'1'", "REF_SYSTEM": "'ICRF'", "REF_PLANE": "'FRAME'", "VEC_CORR": "'NONE'",
                 "OUT_UNITS": "'KM-S'", "CSV_FORMAT": "'YES'", **when}
        req = urllib.request.Request("https://ssd.jpl.nasa.gov/api/horizons.api?" + urllib.parse.urlencode(query), headers={"User-Agent": "ephemeris-fit"})
        with urllib.request.urlopen(req) as r, open(path, "wb") as f:
            f.write(r.read())
    text = open(path).read()
    rows = [line.split(",") for line in text.split("$$SOE")[1].split("$$EOE")[0].strip().splitlines()]
    return np.array([[float(row[0]) - TDB] + [float(x) / 1000 for x in row[2:5]] for row in rows])  # JD (UTC), Mm


def frame(jd):
    """Saturn's pole (the IAU's, as SaturnsRings.pole) and two directions in its equator, the first where the equator
    rises through the Earth's (J2000)."""
    t = (jd - 2451545) / 36525
    ra, dec = np.radians(40.589 - 0.036 * t), np.radians(83.537 - 0.004 * t)
    pole = np.stack([np.cos(dec) * np.cos(ra), np.cos(dec) * np.sin(ra), np.sin(dec)], axis=-1)
    e1 = np.stack([-pole[..., 1], pole[..., 0], np.zeros_like(ra)], axis=-1)
    e1 /= np.linalg.norm(e1, axis=-1, keepdims=True)
    return pole, e1, np.cross(pole, e1)


def place(m, jd):
    """The fitted orbit's place at jd (UTC), Mm, J2000 equatorial: SaturnsRings.moons(at:) is this."""
    t = jd - EPOCH
    L = np.radians(m["L"][0] + m["L"][1] * t + m["L"][2] * t * t + m["L"][3] * t ** 3)
    M = L - np.radians(m["peri"][0] + m["peri"][1] * t)
    lon, r = L + 2 * m["e"] * np.sin(M), m["a"] * (1 - m["e"] * np.cos(M))
    lat = np.radians(m["i"]) * np.sin(lon - np.radians(m["node"][0] + m["node"][1] * t))
    pole, e1, e2 = frame(jd)
    return r[..., None] * (np.cos(lat)[..., None] * (np.cos(lon)[..., None] * e1 + np.sin(lon)[..., None] * e2) + np.sin(lat)[..., None] * pole)


def turning(angle, t, values, rates, also=None):
    """The amplitude, direction (degrees at the epoch) and rate (degrees a day) of values = A sin(angle - direction - rate t),
    the rate found by trying each of `rates`; `also` = (other values, their amplitude over A) fits them as
    -cos of the same angle at once (the distance, which an eccentricity moves as well as the longitude)."""
    best = None
    for rate in rates:
        x = angle - np.radians(rate) * t
        design, target = np.stack([np.sin(x), -np.cos(x)], axis=1), values
        if also is not None:
            design = np.concatenate([design, also[1] * np.stack([-np.cos(x), -np.sin(x)], axis=1)])
            target = np.concatenate([values, also[0]])
        (c, s), residual = np.linalg.lstsq(design, target, rcond=None)[:2]
        if best is None or residual[0] < best[0]:
            best = (residual[0], np.hypot(c, s), np.degrees(np.arctan2(s, c)) % 360, rate)
    return best[1:]


def fit(name, number, rate, folder):
    v = fetch(folder, "fit", number, {"START_TIME": "'2022-01-01'", "STOP_TIME": "'2041-01-01'", "STEP_SIZE": "'23d'"})
    jd, p = v[:, 0], v[:, 1:]
    t = jd - EPOCH
    pole, e1, e2 = frame(jd)
    r = np.linalg.norm(p, axis=1)
    lon = np.arctan2((p * e2).sum(1), (p * e1).sum(1))
    lat = np.arcsin((p * pole).sum(1) / r)
    m = {"name": name, "a": r.mean(), "e": 0.0, "peri": (0.0, 0.0), "i": 0.0, "node": (0.0, 0.0)}
    for _ in range(3):  # the steady longitude, then what the eccentricity adds to it, and again
        M0 = np.radians(m["peri"][0] + m["peri"][1] * t)
        mean = np.radians(rate) * t
        if "L" in m:
            mean = np.radians(m["L"][0] + m["L"][1] * t + m["L"][2] * t * t + m["L"][3] * t ** 3)
        off = lon - 2 * m["e"] * np.sin(mean - M0) - np.radians(rate) * t
        off = np.degrees((off + np.pi) % (2 * np.pi) - np.pi)
        off = off[0] + ((off - off[0] + 180) % 360 - 180)  # near the first, in case it straddles 180
        c = np.polyfit(t, off, 3)
        m["L"] = (c[3] % 360, rate + c[2], c[1], c[0])
        mean = np.radians(m["L"][0] + m["L"][1] * t + m["L"][2] * t * t + m["L"][3] * t ** 3)
        left = (lon - mean + np.pi) % (2 * np.pi) - np.pi
        e2x, peri, turn = turning(mean, t, left, np.arange(-0.3, 1.3, 0.0005), also=(r / m["a"] - 1, 0.5))
        m["e"], m["peri"] = e2x / 2, (peri, turn)
    M = mean - np.radians(m["peri"][0] + m["peri"][1] * t)
    inc, node, turn = turning(mean + 2 * m["e"] * np.sin(M), t, lat, np.arange(-1.3, 0.3, 0.0005))
    m["i"], m["node"] = np.degrees(inc), (node, turn)
    m["a"] = (r / (1 - m["e"] * np.cos(M))).mean()
    return m, jd, p


def apart(a, b):
    """The angle between two places as seen from Saturn's centre, degrees."""
    cos = (a * b).sum(-1) / np.linalg.norm(a, axis=-1) / np.linalg.norm(b, axis=-1)
    return np.degrees(np.arccos(np.clip(cos, -1, 1)))


if __name__ == "__main__":
    folder = sys.argv[1]
    sun = fetch(folder, "check", 10, {"TLIST": CHECKS})
    table, checks = [], []
    for name, number, rate in MOONS:
        m, jd, p = fit(name, number, rate, folder)
        off = apart(place(m, jd), p)
        c = fetch(folder, "check", number, {"TLIST": CHECKS})
        check = apart(place(m, c[:, 0]), c[:, 1:])
        km = np.linalg.norm(place(m, c[:, 0]) - c[:, 1:], axis=1).max() * 1000
        print(f"# {name}: a {m['a']:.3f} Mm, e {m['e']:.5f}, i {m['i']:.4f}; from Horizons 2022-2041: rms {np.sqrt((off ** 2).mean()):.3f} deg, "
              f"most {off.max():.3f}; at the check moments most {check.max():.3f} deg, {km:.0f} km")
        table.append(f'        Moon(name: "{name}", a: {m["a"]:.4f}, longitude: ({m["L"][0]:.4f}, {m["L"][1]:.7f}, {m["L"][2]:.4e}, {m["L"][3]:.4e}), '
                     f'e: {m["e"]:.5f}, peri: ({m["peri"][0]:.2f}, {m["peri"][1]:.4f}), i: {m["i"]:.4f}, node: ({m["node"][0]:.2f}, {m["node"][1]:.4f}), ')
        # the check: the moon's longitude round the pole from the Sun's, its height over the ring plane, and its distance
        pole, e1, e2 = frame(c[:, 0])
        for k in range(len(c)):
            s, q = sun[k, 1:], c[k, 1:]
            across = s - (s * pole[k]).sum() * pole[k]
            across /= np.linalg.norm(across)
            x, y, z = (q * across).sum(), (q * np.cross(pole[k], across)).sum(), (q * pole[k]).sum()
            checks.append(f'    ("{name}", {c[k, 0]:.5f}, {x:.3f}, {y:.3f}, {z:.3f}),')
    print("\n".join(table))
    print("\n".join(checks))
