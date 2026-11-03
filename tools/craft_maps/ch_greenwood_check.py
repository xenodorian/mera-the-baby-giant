import json, sys
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import build_stage3 as b

d = json.load(open(HERE / "ch_greenwood.json"))
rows, COLW = d["rows"], 160
nc = len(rows[0])
assert d["cols"] == nc and 60 <= nc and 66 <= nc <= 74, nc
assert all(len(r) == nc for r in rows) and 14 <= len(rows) <= 20
assert sum(r.count("S") for r in rows) == 1 and sum(r.count("F") for r in rows) == 1
info = b.analyse(rows, COLW)
sr = next(r for r in range(len(rows)) if "S" in rows[r])
assert rows[sr].index("S") in (4, 5)
assert nc * COLW >= 9600
surf = info["surfaces"]
assert min(s[0] for s in surf) >= 1800, surf[0]
lad = b.make_ladders(surf)
ladder_tops = {l[2] for l in lad}
reach = {}
for s in sorted(surf, key=lambda s: -s[2]):   # lowest first
    ok = s[2] >= b.GROUND_Y - 140 or any(
        o is not s and 0 < o[2] - s[2] <= 140 and o[0] - 350 <= s[1] and o[1] + 350 >= s[0] for o in surf)
    ok = ok or any(l[2] == s[2] and s[0] <= l[0] <= s[1] for l in lad)
    assert ok, ("unreachable", s)
pits = b.runs(sorted(info["pit_cols"]))
for a, c in pits:
    if c - a > 2:
        assert any(s[0] <= a * COLW and s[1] >= c * COLW for s in surf if s[2] < b.GROUND_Y), ("wide pit no ledge", a, c)
cnt = lambda ch: sum(r.count(ch) for r in rows)
en = sum(cnt(ch) for ch in "gmja")
assert 11 <= en <= 14, en
assert cnt("c") == 2 and cnt("k") == 1 and cnt("p") == 1 and cnt("i") == 4 == len(d["signs"])
print("OK cols", nc, "enemies", en, "surfaces", len(surf), "ladders", lad, "pits", pits)
print("\n".join(rows))
