#!/usr/bin/env python3
"""Cut King Nerochilde frames from Foozle's Lucifer Necromancer pack (CC0) and merge the roster key "nero".

Reads the right-facing strips straight from the saved zip (assets/_source/king/), so nothing is
extracted to disk. Each strip is a row of square cells (48 px). One PNG per frame is written to
assets/characters/itch/foozle/lucifer_necromancer/<anim>/<anim>_<n>.png (n counts from 1). Frames
are not trimmed or flipped. Pivot = bottom centre of the opaque bbox (alpha > 40) of idle frame 1,
shared by every anim; boxes are opaque bboxes relative to that pivot (the roster format, see
"cl_warlord" in assets/enemies/roster.json). Only the key "nero" is written to roster.json; every
other key keeps its bytes (the file is re-dumped with indent=1, which round-trips exactly).

    python3 tools/build_nero.py [contact_sheet.png]
"""
import io
import json
import pathlib
import shutil
import sys
import zipfile

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
ZIP = ROOT / "assets" / "_source" / "king" / "Foozle_2DC0010_Lucifer_Necromancer_Pixel_Art.zip"
LICENSE_SRC = ROOT / "assets" / "_source" / "king" / "LICENSE_foozle.txt"
DEST = ROOT / "assets" / "characters" / "itch" / "foozle" / "lucifer_necromancer"
ROSTER = ROOT / "assets" / "enemies" / "roster.json"
PKG = "Foozle_2DC0010_Lucifer_Necromancer_Pixel_Art"
CELL = 48
THRESH = 40
FACING = 1  # the right-facing strips face right as drawn

# game anim -> (strip name in the zip, fps, loop)
ANIMS = {
    "idle": ("NecromancerRightIdle.png", 6, True),
    "walk": ("NecromancerRightWalk.png", 8, True),
    "attack": ("NecromancerRightAttack01.png", 12, False),
    "attack2": ("NecromancerRightAttack02.png", 12, False),
    "cast": ("NecromancerRightAttack03.png", 10, False),
    "hurt": ("NecromancerRightHurt.png", 10, False),
    "death": ("NecromancerRightDeath.png", 8, False),
}


def read_strip(zf, name):
    data = zf.read(f"{PKG}/Right/Png/{name}")
    im = Image.open(io.BytesIO(data)).convert("RGBA")
    assert im.height == CELL and im.width % CELL == 0, (name, im.size)
    return [im.crop((i * CELL, 0, (i + 1) * CELL, CELL)) for i in range(im.width // CELL)]


def opaque_box(im):
    """(l, t, r, b) with b and r exclusive, or None when the cell has no pixel above THRESH."""
    mask = np.asarray(im.getchannel("A")) > THRESH
    if not mask.any():
        return None
    ys, xs = np.nonzero(mask)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def main(sheet_path):
    if DEST.exists():
        shutil.rmtree(DEST)
    DEST.mkdir(parents=True)
    shutil.copyfile(LICENSE_SRC, DEST / "LICENSE_foozle.txt")

    with zipfile.ZipFile(ZIP) as zf:
        strips = {anim: read_strip(zf, name) for anim, (name, _, _) in ANIMS.items()}

    idle0 = strips["idle"][0]
    l, t, r, b = opaque_box(idle0)
    pivot = ((l + r) / 2.0, float(b))
    px, py = pivot

    roster_entry = {"facing": FACING, "flyer": False, "anims": {}}
    idle_boxes = []
    report = []
    sheet_first = []

    for anim, (name, fps, loop) in ANIMS.items():
        frames = strips[anim]
        adir = DEST / anim
        adir.mkdir(parents=True, exist_ok=True)
        paths, boxes = [], []
        for n, im in enumerate(frames, start=1):
            out = adir / f"{anim}_{n}.png"
            im.save(out)
            paths.append(f"res://assets/characters/itch/foozle/lucifer_necromancer/{anim}/{anim}_{n}.png")
            bb = opaque_box(im)
            if bb is None:
                boxes.append([0.0, 0.0, 0.0, 0.0])
            else:
                boxes.append([bb[0] - px, bb[1] - py, bb[2] - px, bb[3] - py])
        if anim == "idle":
            idle_boxes = boxes
        roster_entry["anims"][anim] = {
            "frames": paths,
            "fps": fps,
            "loop": loop,
            "size": [CELL, CELL],
            "pivot": [px, py],
            "boxes": boxes,
        }
        sheet_first.append(frames[0])
        reach = max((bx[2] for bx in boxes if bx[2] != 0.0), default=0.0)
        report.append(f"{anim}: {len(frames)} frames, fps {fps}, loop {loop}, max right edge {reach:.0f}px")

    body = [
        min(bx[0] for bx in idle_boxes),
        min(bx[1] for bx in idle_boxes),
        max(bx[2] for bx in idle_boxes),
        max(bx[3] for bx in idle_boxes),
    ]
    roster_entry["body"] = body

    # Merge only the "nero" key; the rest of the file must stay byte-identical.
    before = ROSTER.read_bytes()
    data = json.loads(before.decode("utf-8"))
    wiz = data.get("x_dark_wizard", {}).get("anims", {}).get("bolt")
    if wiz:                                              # no projectile strip in the pack: the dark lord's bolt is the dark wizard's (Luiz Melo, CC0)
        roster_entry["anims"]["bolt"] = json.loads(json.dumps(wiz))
    data["nero"] = roster_entry
    ROSTER.write_bytes(json.dumps(data, indent=1, ensure_ascii=False).encode("utf-8"))

    # Contact sheet: first frame of each anim, x2 nearest, on a dark ground.
    gap = 4
    sheet = Image.new("RGBA", (len(sheet_first) * (CELL + gap) * 2, CELL * 2 + 8), (40, 40, 48, 255))
    for i, im in enumerate(sheet_first):
        sheet.alpha_composite(im.resize((CELL * 2, CELL * 2), Image.NEAREST), (i * (CELL + gap) * 2, 4))
    sheet.save(sheet_path)

    print("pivot", pivot, "body", body, "idle height", b - t)
    for line in report:
        print(line)
    print("contact sheet", sheet_path)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/claude-0/-home-user/30a3820d-cdd0-52ad-96e4-ef061324fb98/scratchpad/nero_contact.png")
