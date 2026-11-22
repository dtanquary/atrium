"""Bakes Seismograph's station list: python3 -I stations.py <new, empty download dir> <out tsv> <networks tsv>.

Every station in EarthScope's SeedLink ring with a live LHZ stream (a sample a second, vertical; its newest sample under
30 minutes old when fetched), with its place from EarthScope's station service, from networks whose licence allows
it. A network's licence is its DOI record's at DataCite: none declared means EarthScope's default, CC BY 4.0 ("When no
license has been declared by the owner, the facility distributes the data with a license of" CC BY 4.0, checked at
https://docs.earthscope.org/sponsored-open-data, research-method.md §1); a declared one must be CC BY or CC0, any
version (labels that are not licences aside, `LABELS`). AM (Raspberry Shake) is left out, its data's licence unchecked. The list goes in the app, which searches it
on the Mac, so nothing about where the Mac is goes anywhere (research-method.md §2). Remake it at each release.
"""
import calendar, json, os, subprocess, sys, time, urllib.parse
from xml.etree import ElementTree

UA = "generic-client/1.0"
LEFT_OUT = {"AM"}
# entries in a DOI's rights that are labels, not licences: MN's beside its CC BY 4.0, and AU's security marking beside its own
LABELS = {"open access", "australian government security classificationsystem"}


def get(url, path):
    subprocess.run(["curl", "-sf", "--retry", "2", "-A", UA, "-o", path, url], check=True)
    return path


def main(d, out, networks_out):
    streams = open(get("https://rtserve.earthscope.org/streams", f"{d}/streams.txt")).read().split("\n")
    fetched = time.time()
    live = {}
    for row in streams:
        parts = row.split()
        if len(parts) < 3 or not parts[0].endswith("_L_H_Z/MSEED"):
            continue
        net, sta, loc = parts[0][5:].split("_")[:3]
        newest = calendar.timegm(time.strptime(parts[2][:19], "%Y-%m-%dT%H:%M:%S"))
        if fetched - newest < 1800 and net not in LEFT_OUT:
            live.setdefault((net, sta), []).append(loc)
    nets = sorted({n for n, _ in live})
    q = urllib.parse.urlencode({"level": "network", "net": ",".join(nets), "format": "xml"})
    xml = ElementTree.parse(get(f"https://service.earthscope.org/fdsnws/station/1/query?{q}", f"{d}/networks.xml"))
    ns = {"s": "http://www.fdsn.org/xml/station/1"}
    dois = {}
    for n in xml.getroot().iterfind("s:Network", ns):
        ident = n.find("s:Identifier[@type='DOI']", ns)
        if ident is not None:
            dois.setdefault(n.get("code"), ident.text.strip())
    allowed, record = set(), []
    for net in nets:
        doi = dois.get(net)
        rights = []
        if doi:
            try:
                meta = json.load(open(get(f"https://api.datacite.org/dois/{urllib.parse.quote(doi, safe='')}", f"{d}/doi-{net}.json")))
                rights = [r.get("rightsIdentifier") or r.get("rights", "") for r in meta["data"]["attributes"].get("rightsList", [])]
            except Exception:
                rights = ["unreadable"]
        licences = [r for r in rights if r.lower() not in LABELS]
        ok = all(r.lower().startswith(("cc-by-", "cc0", "creative commons attribution")) and "-nc" not in r.lower() and "-nd" not in r.lower() for r in licences)
        licence = ", ".join(rights) if rights else "none declared: EarthScope's CC BY 4.0"
        record.append(f"{net}\t{doi or '-'}\t{licence}\t{'yes' if ok else 'no'}")
        if ok:
            allowed.add(net)
    q = urllib.parse.urlencode({"level": "station", "net": ",".join(sorted(allowed)), "cha": "LHZ", "format": "text", "endafter": time.strftime("%Y-%m-%d")})
    rows = open(get(f"https://service.earthscope.org/fdsnws/station/1/query?{q}", f"{d}/stations.txt")).read().split("\n")
    places = {}
    for row in rows[1:]:
        f = row.split("|")
        if len(f) >= 6:
            places[(f[0], f[1])] = (float(f[2]), float(f[3]), f[5].strip())
    lines = []
    for (net, sta), locs in sorted(live.items()):
        if net in allowed and (net, sta) in places:
            lat, lon, name = places[(net, sta)]
            loc = "00" if "00" in locs else sorted(locs)[0]
            lines.append(f"{net}\t{sta}\t{loc}\t{lat:.4f}\t{lon:.4f}\t{' '.join(name.split())[:60]}")
    with open(out, "w") as f:
        f.write(f"# Seismograph's stations: live LHZ streams in EarthScope's SeedLink ring on {time.strftime('%Y-%m-%d', time.gmtime(fetched))}, "
                "from networks under CC BY or CC0 (docs/seismograph/stations.py, networks.tsv). net, station, location, latitude, longitude, site.\n")
        f.write("\n".join(lines) + "\n")
    with open(networks_out, "w") as f:
        f.write("# network\tDOI\tlicence (DataCite)\tin the list\n" + "\n".join(record) + "\n")
    print(len(lines), "stations from", len(allowed), "of", len(nets), "networks;", "left out:", sorted(set(nets) - allowed))


if __name__ == "__main__":
    main(*sys.argv[1:4])
