#!/usr/bin/env python3
"""Rebuild only the "perry" key of assets/enemies/roster.json (the boss plays every move of her player build).

tools/build_roster.py rebuilds the whole file; this merges one entry so the other keys stay byte-identical.
Run after changing PERRY_BOSS_EXTRA in tools/build_roster.py or the Perry frames:  python3 tools/build_perry_boss.py
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_roster as br

path = os.path.join(br.ROOT, br.OUT, "roster.json")
with open(path) as fh:
    data = json.load(fh)
face, flyer, anims = br.E["perry"]
e = {"facing": face, "flyer": flyer, "anims": {}}
base = None
for name, spec in anims.items():
    src, fps, loop, *rest = spec
    explicit = rest[0] if rest else None
    ent = br.anim_entry("perry", name, src, fps, loop, flyer, explicit)
    if (explicit is None and base is not None and ent["size"] == base["size"]
            and name not in ("fireball", "arrow", "arrow_hit", "bolt")):
        ent = br.anim_entry("perry", name, src, fps, loop, flyer, base["pivot"])
    if base is None:
        base = ent
    e["anims"][name] = ent
e["body"] = base["boxes"][0]
data["perry"] = e
with open(path, "w") as fh:
    json.dump(data, fh, indent=1)
print("perry: %d anims" % len(e["anims"]), ", ".join("%s:%d" % (k, len(v["frames"])) for k, v in e["anims"].items()))
