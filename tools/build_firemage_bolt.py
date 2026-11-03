#!/usr/bin/env python3
"""The fire mage (p_firemage, Perry Riposte) used to throw its looping explosion animation ("blast") as the projectile.
It now throws a fire bolt and explodes only where the bolt hits (Roster.DEFS "impact": "blast"). The pack has no bolt strip, so
the bolt frames are the fire worm's fireball (x_fire_worm "fireball", Luiz Melo, CC0), copied into the p_firemage roster entry.
Merges one anim ("bolt") into assets/enemies/roster.json; run it after tools/build_roster.py rebuilds the file.
"""
import json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = os.path.join(ROOT, "assets/enemies/roster.json")
d = json.loads(open(P, "rb").read().decode("utf-8"))
d["p_firemage"]["anims"]["bolt"] = json.loads(json.dumps(d["x_fire_worm"]["anims"]["fireball"]))
open(P, "wb").write(json.dumps(d, indent=1, ensure_ascii=False).encode("utf-8"))
print("p_firemage bolt:", len(d["p_firemage"]["anims"]["bolt"]["frames"]), "frames")
