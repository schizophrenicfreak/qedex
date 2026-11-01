#!/usr/bin/env python3
import json, math, os, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COLS, ROWS = 34, 10


def home():
    for name in ("config.json",):
        try:
            with open(os.path.join(ROOT, name)) as f:
                loc = json.load(f)["location"]
            return float(loc["lat"]), float(loc["lon"])
        except Exception:
            continue
    return 0.0, 0.0


def get(u):
    req = urllib.request.Request(u, headers={"User-Agent": "quickshell-edex"})
    with urllib.request.urlopen(req, timeout=6) as r:
        return json.load(r)


def cell(lat, lon):
    x = min(COLS - 1, max(0, int((lon + 180) / 360 * COLS)))
    y = min(ROWS - 1, max(0, int((90 - lat) / 180 * ROWS)))
    return x, y


HOME = home()
try:
    d = get("https://api.wheretheiss.at/v1/satellites/25544")
    la, lo = d["latitude"], d["longitude"]
    try:
        cc = get(f"https://api.wheretheiss.at/v1/coordinates/{la},{lo}").get("country_code", "??")
    except Exception:
        cc = "??"
    over = "OCEAN" if cc in ("??", "", None) else cc
    p1, p2 = math.radians(HOME[0]), math.radians(la)
    dp, dl = p2 - p1, math.radians(lo - HOME[1])
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    dist = 2 * 6371 * math.asin(math.sqrt(a))
    grid = [["."] * COLS for _ in range(ROWS)]
    hx, hy = cell(*HOME); grid[hy][hx] = "+"
    ix, iy = cell(la, lo); grid[iy][ix] = "@"
    out = {
        "lat": f"{abs(la):.2f}°{'N' if la >= 0 else 'S'}",
        "lon": f"{abs(lo):.2f}°{'E' if lo >= 0 else 'W'}",
        "alt": f"{d['altitude']:.0f} km",
        "vel": f"{d['velocity']:,.0f} km/h",
        "over": over,
        "dist": f"{dist:,.0f} km",
        "view": "YES" if dist < d.get("footprint", 0) / 2 else "NO",
        "vis": str(d.get("visibility", "-")).upper(),
        "map": "\n".join("".join(r) for r in grid),
        "state": "LIVE",
    }
except Exception:
    out = {"lat": "-", "lon": "-", "alt": "-", "vel": "-", "over": "-", "dist": "-",
           "view": "-", "vis": "-", "map": "", "state": "NO LINK"}
print(json.dumps(out, ensure_ascii=False))
