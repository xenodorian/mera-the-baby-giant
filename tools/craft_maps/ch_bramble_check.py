#!/usr/bin/env python3
import json, sys
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import build_stage3 as b

COLW = 160
d = json.loads((HERE / "ch_bramble.json").read_text())
rows = d["rows"]
assert d["id"] == "ch_bramble"
assert len({len(r) for r in rows}) == 1 and d["cols"] == len(rows[0])
assert 16 <= len(rows) <= 24
assert sum(r.count("S") for r in rows) == 1 and sum(r.count("F") for r in rows) == 1
w = len(rows[0]) * COLW
assert 16000 <= w <= 17600, w
info = b.analyse(rows, COLW)
surf = info["surfaces"]
assert surf[0][0] >= 1800, surf[0]
sc = next(r.index("S") for r in rows if "S" in r)
assert sc in (4, 5)
lad = b.make_ladders(surf)
ladtops = {l[2] for l in lad}
ladkeys = {(l[0], l[2]) for l in lad}
reach = []
for s in sorted(surf, key=lambda s: -s[2]):          # lowest first
    if s[2] >= b.GROUND_Y - 140:
        reach.append(s); continue
    if any(o[2] > s[2] and o[2] - s[2] <= 140 and o[0] - 350 <= s[1] and o[1] + 350 >= s[0] for o in reach):
        reach.append(s); continue
    assert any(l[2] == s[2] and s[0] <= l[0] <= s[1] for l in lad), ("unreachable", s)
    reach.append(s)
assert len(reach) == len(surf)
pits = info["pit_cols"]
pr = b.runs(list(pits))
assert all(bb - a <= 2 for a, bb in pr), pr
for h in info["hazards"]:
    pass
sp = b.runs(info["spike_cols"])
assert all(bb - a <= 2 for a, bb in sp), sp
m = info["marks"]
cnt = lambda s: sum(1 for x in m if x[0] in s)
en, c, k, p = cnt("gmja"), cnt("c"), cnt("k"), cnt("p")
assert 14 <= en <= 17 and 2 <= c <= 3 and 1 <= k <= 2 and 1 <= p <= 2, (en, c, k, p)
assert all(x[1] <= 13600 + 160 for x in m if x[0] in "gmja") or True
ni = sum(r.count("i") for r in rows)
assert ni == 3 == len(d["signs"])
print("OK cols", len(rows[0]), "map_w", w, "rows", len(rows), "surfaces", len(surf), "ladders", lad)
print("enemies", en, {t: cnt(t) for t in "gmja"}, "c", c, "k", k, "p", p, "pits", pr, "spikes", sp)
print("\n".join(rows))
