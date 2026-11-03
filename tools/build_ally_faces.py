#!/usr/bin/env python3
"""Stage 3 phase 7: add only the face-ally entries (ally_cl_*, ally_perry) to assets/enemies/roster.json, leaving every
other entry as it is on disk (so it is safe to run while other roster work is in progress).  python3 tools/build_ally_faces.py"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_roster as B

path = os.path.join(B.ROOT, B.OUT, "roster.json")
with open(path) as fh:
    out = json.load(fh)
for eid, (face, flyer, anims) in B.ALLIES.items():
    if not eid.startswith("ally_"):
        continue
    e = {"facing": face, "flyer": flyer, "anims": {}}
    base = None
    for name, (src, fps, loop, *rest) in anims.items():
        explicit = rest[0] if rest else None
        ent = B.anim_entry(eid, name, src, fps, loop, flyer, explicit)
        if explicit is None and base is not None and ent["size"] == base["size"]:     # same cell: share the idle pivot
            ent = B.anim_entry(eid, name, src, fps, loop, flyer, base["pivot"])
        base = base or ent
        e["anims"][name] = ent
    e["body"] = e["anims"]["idle"]["boxes"][0]
    out[eid] = e
    print(eid, "body", e["body"], len(e["anims"]), "anims")
with open(path, "w") as fh:
    json.dump(out, fh, indent=1)
