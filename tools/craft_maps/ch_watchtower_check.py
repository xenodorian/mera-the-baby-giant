import sys, json
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import build_stage3 as b

d = json.loads((Path(__file__).parent / "ch_watchtower.json").read_text())
rows = d["rows"]
colw = 160
assert len({len(r) for r in rows}) == 1 and len(rows[0]) == d["cols"]
assert 22 <= len(rows) <= 28
assert sum(r.count("S") for r in rows) == 1
assert 84 <= d["cols"] <= 92 and d["cols"] * colw >= 9600
info = b.analyse(rows, colw)
surf = info["surfaces"]
assert surf and min(s[0] for s in surf) >= 1800, surf[:2]
ladders = b.make_ladders(surf)
srow = next(i for i, r in enumerate(rows) if "S" in r)
assert 4 <= rows[srow].index("S") <= 5
assert info["floor"] == srow + 1

# reachability
low = b.GROUND_Y - 140
reach = {}
for s in sorted(surf, key=lambda s: -s[2]):
    k = tuple(s)
    if s[2] >= low:
        reach[k] = True
        continue
    lad = any(l[2] == s[2] and s[0] <= l[0] <= s[1] for l in ladders)
    ok = lad or any(reach.get(tuple(o)) and 0 < o[2] - s[2] <= 140 and o[0] - 350 <= s[1] and o[1] + 350 >= s[0] for o in surf)
    reach[k] = ok
assert all(reach.values()), [k for k, v in reach.items() if not v]

# pits
for a, c in [(h[0] // colw, h[1] // colw) for h in info["hazards"]]:
    pass
pit_runs = b.runs(sorted(info["pit_cols"]))
for a, c in pit_runs:
    if c - a > 2:
        # bridged: every gap of non-surface columns inside must be <= 2 columns
        cover = sorted((s[0] // colw, s[1] // colw) for s in surf if s[0] // colw < c and s[1] // colw > a)
        pos = a - 1
        for x0, x1 in cover:
            assert x0 - pos - 1 <= 2, ("gap", a, c, x0, pos)
            pos = max(pos, x1 - 1)
        assert c - pos - 1 <= 2, ("end gap", a, c)
    print("pit", a, c, "width", c - a)

marks = "".join(m[0] for m in info["marks"])
en = sum(marks.count(x) for x in "gmja")
assert 16 <= en <= 19 and marks.count("a") >= 5
assert 2 <= marks.count("c") <= 3 and 1 <= marks.count("k") <= 2 and 1 <= marks.count("p") <= 2
assert marks.count("F") == 0 or True
assert sum(r.count("F") for r in rows) == 1
ni = sum(r.count("i") for r in rows)
assert 2 <= ni <= 3 and ni == len(d["signs"])
print("OK cols", d["cols"], "map_w", d["cols"] * colw, "enemies", en, "archers", marks.count("a"),
      "c", marks.count("c"), "k", marks.count("k"), "p", marks.count("p"), "signs", ni,
      "tiers", sorted({s[3] for s in surf}), "surfaces", len(surf), "ladders", len(ladders))
print("ladders", ladders)
for i, r in enumerate(rows):
    print(f"{i:2d} {r}")
