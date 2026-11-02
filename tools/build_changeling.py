#!/usr/bin/env python3
"""Cut Changeling character frames from the Liberated Pixel Cup sheets (Pillow and numpy).

Reads the sheets copied from the Changeling game into assets/changeling/source/lpc/ and writes
one PNG per frame to assets/characters/changeling/<id>/<anim>/<anim>_<n>.png (n counts from 1),
plus assets/changeling/changeling_meta.json.

Rows and frame counts come from ANIM_ROWS in the game's src/anim.js (copied to
assets/changeling/source/src/anim.js). Sheets face right; nothing is flipped or trimmed.

Enemies use the 64 px sheets the game loads (lpc/<kind>.png). The four playable faces use the
192 px big sheets (<key>_big.png). Those already hold the weapon layers, stacked in the z order
that game/tools/build_lpc.py gives them (a behind-body weapon at z 9 or -1, a front weapon at
z 140), so no second weapon pass is needed. Compositing <key>_weapon_big.png again would blend
every weapon edge twice.

    python3 tools/build_changeling.py
"""
import json
import pathlib
import shutil

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "changeling" / "source" / "lpc"
OUT = ROOT / "assets" / "characters" / "changeling"
META = ROOT / "assets" / "changeling" / "changeling_meta.json"
CREDITS = SRC / "CREDITS.txt"

# [row, frame count] per animation, copied from ANIM_ROWS in game/src/anim.js.
ANIM_ROWS = {
    "idle": [0, 2],
    "walk": [1, 9],
    "slash": [2, 6],
    "thrust": [3, 8],
    "spellcast": [4, 7],
    "shoot": [5, 13],
    "hurt": [6, 6],
    "jump": [7, 5],
}

FPS = {"idle": 8, "walk": 10, "slash": 12, "thrust": 12, "spellcast": 12, "shoot": 12, "jump": 12, "hurt": 8}

# (id, sheet file, cell size). Enemy ids use the sheet the game loads for their kind.
CHARACTERS = [
    ("grunt", "grunt.png", 64),
    ("mud_revenant", "mud_revenant.png", 64),
    ("rat_king", "rat_king.png", 64),
    ("archer", "archer.png", 64),
    ("warlord", "warlord.png", 64),
    ("knight", "knight_big.png", 192),
    ("ranger", "ranger_big.png", 192),
    ("weaver", "weaver_big.png", 192),
    ("mage", "mage_big.png", 192),
]


def has_pixels(cell):
    return bool(np.asarray(cell.getchannel("A")).any())


def cut_character(cid, sheet_name, cell):
    sheet = Image.open(SRC / sheet_name).convert("RGBA")
    cols, rows = sheet.width // cell, sheet.height // cell
    dest = OUT / cid
    if dest.exists():
        shutil.rmtree(dest)
    anims = {}
    for anim, (row, count) in ANIM_ROWS.items():
        if row >= rows:
            print(f"  {cid}: {anim} row {row} is outside the sheet, skipped")
            continue
        frames = []
        for c in range(min(count, cols)):
            cellimg = sheet.crop((c * cell, row * cell, (c + 1) * cell, (row + 1) * cell))
            frames.append(cellimg)
        # Stop at the last filled cell; drop the animation if no cell has pixels.
        last = -1
        for i, f in enumerate(frames):
            if has_pixels(f):
                last = i
        frames = frames[: last + 1]
        if not frames:
            print(f"  {cid}: {anim} is empty, dropped")
            continue
        adir = dest / anim
        adir.mkdir(parents=True, exist_ok=True)
        for n, f in enumerate(frames, start=1):
            f.save(adir / f"{anim}_{n}.png")
        anims[anim] = {"frames": len(frames), "fps": FPS[anim]}
    return {"facing": 1, "cell": [cell, cell], "anims": anims}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    meta = {}
    for cid, sheet_name, cell in CHARACTERS:
        meta[cid] = cut_character(cid, sheet_name, cell)
        summary = ", ".join(f"{a} {v['frames']}" for a, v in meta[cid]["anims"].items())
        print(f"{cid} ({cell}px): {summary}")
    META.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
    shutil.copyfile(CREDITS, OUT / "CREDITS.txt")
    print(f"wrote {META}")


if __name__ == "__main__":
    main()
