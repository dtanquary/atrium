"""Minimal miniSEED 2 reader (Steim1/Steim2, big-endian), stdlib + numpy, written by the method research (research-method.md),
which checked it against 346 records' own check values. For the mock-ups only; the app will have its own decoder."""
import struct, sys, datetime as dt
import numpy as np


def _sext(v, bits):
    m = 1 << (bits - 1)
    return (v & ((1 << bits) - 1) ^ m) - m


def _steim(data, nsamp, steim):
    diffs = []
    x0 = None
    for f in range(len(data) // 64):
        w = struct.unpack(">16I", data[f * 64:(f + 1) * 64])
        ctl = w[0]
        for i in range(1, 16):
            c = (ctl >> (30 - 2 * i)) & 3
            v = w[i]
            if f == 0 and i == 1:
                x0 = struct.unpack(">i", struct.pack(">I", v))[0]; continue
            if f == 0 and i == 2:
                continue
            if c == 0:
                continue
            if c == 1:
                diffs += [_sext(v >> s, 8) for s in (24, 16, 8, 0)]
            elif steim == 1:
                if c == 2:
                    diffs += [_sext(v >> 16, 16), _sext(v, 16)]
                else:
                    diffs.append(_sext(v, 32))
            else:
                d = v >> 30
                if c == 2:
                    if d == 1: diffs.append(_sext(v, 30))
                    elif d == 2: diffs += [_sext(v >> 15, 15), _sext(v, 15)]
                    elif d == 3: diffs += [_sext(v >> s, 10) for s in (20, 10, 0)]
                else:
                    if d == 0: diffs += [_sext(v >> s, 6) for s in (24, 18, 12, 6, 0)]
                    elif d == 1: diffs += [_sext(v >> s, 5) for s in (25, 20, 15, 10, 5, 0)]
                    elif d == 2: diffs += [_sext(v >> s, 4) for s in (24, 20, 16, 12, 8, 4, 0)]
        if len(diffs) >= nsamp:
            break
    d = np.array(diffs[:nsamp], dtype=np.int64)
    out = np.empty(nsamp, dtype=np.int64)
    out[0] = x0
    out[1:] = x0 + np.cumsum(d[1:])
    return out


def read(path):
    """Returns list of (id, start datetime, rate, samples) per record."""
    b = open(path, "rb").read()
    recs = []
    p = 0
    while p + 48 <= len(b):
        h = b[p:p + 48]
        sta = h[8:13].decode().strip(); loc = h[13:15].decode().strip(); cha = h[15:18].decode(); net = h[18:20].decode().strip()
        yr, doy, hh, mm, ss, _, frac = struct.unpack(">HHBBBBH", h[20:30])
        nsamp, fac, mul = struct.unpack(">Hhh", h[30:36])
        boff = struct.unpack(">H", h[46:48])[0]
        doff = struct.unpack(">H", h[44:46])[0]
        enc, reclen = 11, 512
        q = boff
        while q:
            bt, nxt = struct.unpack(">HH", b[p + q:p + q + 4])
            if bt == 1000:
                enc = b[p + q + 4]; reclen = 1 << b[p + q + 6]
            q = nxt
        rate = (fac if fac > 0 else -1 / fac) * (mul if mul > 0 else -1 / mul)
        t = dt.datetime(yr, 1, 1, hh, mm, ss, frac * 100, tzinfo=dt.timezone.utc) + dt.timedelta(days=doy - 1)
        if nsamp:
            if enc in (10, 11):
                s = _steim(b[p + doff:p + reclen], nsamp, 1 if enc == 10 else 2)
            elif enc == 3:
                s = np.frombuffer(b[p + doff:p + doff + 4 * nsamp], dtype=">i4").astype(np.int64)
            else:
                raise ValueError(f"encoding {enc}")
            recs.append((f"{net}.{sta}.{loc}.{cha}", t, rate, s))
        p += reclen
    return recs


def trace(path):
    """Merge records into (start, rate, samples), filling gaps with NaN."""
    recs = sorted(read(path), key=lambda r: r[1])
    if not recs:
        return None
    t0, rate = recs[0][1], recs[0][2]
    end = max((r[1] - t0).total_seconds() * rate + len(r[3]) for r in recs)
    out = np.full(int(round(end)), np.nan)
    for _, t, _, s in recs:
        i = int(round((t - t0).total_seconds() * rate))
        out[i:i + len(s)] = s
    return t0, rate, out


if __name__ == "__main__":
    for path in sys.argv[1:]:
        r = read(path)
        if not r:
            print(path, "no records"); continue
        last = max(r, key=lambda x: x[1])
        end = last[1] + dt.timedelta(seconds=len(last[3]) / last[2])
        now = dt.datetime.now(dt.timezone.utc)
        n = sum(len(x[3]) for x in r)
        print(f"{path}: {r[0][0]} {r[0][2]} sps, {len(r)} recs, {n} samples, last sample {end:%H:%M:%S}, {(now - end).total_seconds():.0f} s behind now")
