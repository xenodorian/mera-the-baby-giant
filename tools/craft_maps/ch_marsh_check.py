import sys, json
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import build_stage3 as B

COLW = 160
d = json.loads((HERE / "ch_marsh.json").read_text())
rows = d["rows"]
nc = len(rows[0])
assert d["id"] == "ch_marsh" and d["cols"] == nc
assert all(len(r) == nc for r in rows) and 16 <= len(rows) <= 22
assert 116 <= nc <= 124, nc
assert sum(r.count("S") for r in rows) == 1
assert sum(r.count("F") for r in rows) == 1
srow = next(i for i, r in enumerate(rows) if "S" in r)
assert rows[srow].index("S") in (4, 5)
info = B.analyse(rows, COLW)
surf = info["surfaces"]
lad = B.make_ladders(surf)
assert nc * COLW >= 9600
assert min(s[0] for s in surf) >= 1800, surf[0]
# floor segments split at pits
GY = B.GROUND_Y
segs = []
cur = None
for c in range(nc):
    if c in info["pit_cols"]:
        if cur is not None: segs.append([cur * COLW, c * COLW, GY, 0]); cur = None
    elif cur is None: cur = c
if cur is not None: segs.append([cur * COLW, nc * COLW, GY, 0])
allsurf = segs + surf
ladtop = {l[2] for l in lad}
reach = [s[3] == 0 for s in allsurf]
ladx = [(l[0], l[2]) for l in lad]
for s, i in zip(allsurf, range(len(allsurf))):
    if s[3] > 0 and any(s[0] <= lx <= s[1] and y == s[2] for lx, y in ladx): reach[i] = True
ch = True
while ch:
    ch = False
    for i, s in enumerate(allsurf):
        if reach[i]: continue
        for j, o in enumerate(allsurf):
            if reach[j] and o[0] - 350 <= s[1] and o[1] + 350 >= s[0] and (o[2] - s[2] <= 140 or True) and (s[2] - o[2] <= 140):
                reach[i] = True; ch = True; break
bad = [s for s, r in zip(allsurf, reach) if not r]
assert not bad, bad
# pits
for a, b in B.runs(sorted(info["pit_cols"])):
    if b - a > 2:
        # no gap between consecutive ledges over the field wider than 2 columns
        ov = sorted([s for s in surf if s[1] > a * COLW and s[0] < b * COLW], key=lambda s: s[0])
        assert all(ov[k + 1][0] - ov[k][1] <= 2 * COLW for k in range(len(ov) - 1))
        assert ov[0][0] <= (a + 2) * COLW and ov[-1][1] >= (b - 2) * COLW
    else:
        assert b - a <= 2
m = [x[0] for x in info["marks"]]
en = sum(m.count(k) for k in "gmja")
assert 17 <= en <= 20, en
assert 2 <= m.count("c") <= 3 and 1 <= m.count("k") <= 2 and 1 <= m.count("p") <= 2
assert sum(r.count("i") for r in rows) == len(d["signs"]) == 3
assert len(info["hazards"]) >= 5
print("OK cols", nc, "map_w", nc * COLW, "enemies", en, "c", m.count("c"), "k", m.count("k"), "p", m.count("p"),
      "hazards", len(info["hazards"]), "surfaces", len(surf), "ladders", lad)
for r in rows: print(r)
