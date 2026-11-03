#!/usr/bin/env python3
"""Cut the Black Knight (Fellor / BitBlast Studio, owner-supplied pack) into the roster key "black_knight".

Source: assets/_source/black_knight/Black_Knight_All_In_One_New.png (git-ignored: the pack's licence forbids redistributing the
assets as-is; the frames cut for the game are shipped inside the game only). It is a contact sheet of 18 x 18 cells of 144 x 64 px,
each cell with a 1 px coloured border. The 34 animations run in reading order; the cell index where each starts was found from the
border colour changes and checked against the pack's preview GIFs (frame for frame). Only the armed ("weapon") set is imported,
plus the draw / sheathe pair, the parry trio, the two hurt variants and the death; the unarmed duplicates are not used.
Faces right as drawn. Pivot = bottom centre of the torso of idle frame 1, shared by every anim.

    python3 tools/build_black_knight.py
"""
import json
import pathlib
import shutil

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHEET = ROOT / "assets" / "_source" / "black_knight" / "Black_Knight_All_In_One_New.png"
DEST = ROOT / "assets" / "characters" / "black_knight"
ROSTER = ROOT / "assets" / "enemies" / "roster.json"
RES = "res://assets/characters/black_knight"
CW, CH, COLS = 144, 64, 18
THRESH = 40

# anim -> (first cell, last cell, fps, loop)
ANIMS = {
    "idle": (32, 37, 8, True),
    "walk": (160, 171, 14, True),
    "draw": (0, 17, 16, False),
    "sheathe": (18, 31, 16, False),
    "attack1": (84, 92, 14, False),
    "attack2": (93, 101, 14, False),
    "attack3": (102, 112, 14, False),
    "attack4": (113, 123, 14, False),
    "heavy1": (44, 62, 12, False),
    "heavy2": (63, 70, 12, False),
    "heavy3": (71, 83, 12, False),
    "art": (222, 256, 14, False),
    "roll": (124, 135, 16, False),
    "jump": (197, 202, 12, False),
    "midair": (203, 203, 8, False),
    "fall_light": (204, 209, 12, False),
    "fall_heavy": (210, 215, 12, False),
    "land": (216, 221, 14, False),
    "parry_start": (257, 262, 14, False),
    "parry": (263, 277, 14, False),
    "parry_miss": (278, 280, 10, False),
    "hurt": (281, 285, 12, False),
    "hurt2": (286, 290, 12, False),
    "death": (291, 299, 10, False),
    "buff": (312, 323, 12, False),
}


def cell(sheet, i):
    r, c = divmod(i, COLS)
    im = sheet.crop((c * CW, r * CH, (c + 1) * CW, (r + 1) * CH)).copy()
    a = np.array(im)
    a[0, :, 3] = 0                     # the 1 px cell border
    a[-1, :, 3] = 0
    a[:, 0, 3] = 0
    a[:, -1, 3] = 0
    return Image.fromarray(a)


def opaque_box(im):
    mask = np.asarray(im.getchannel("A")) > THRESH
    if not mask.any():
        return None
    ys, xs = np.nonzero(mask)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def torso_x(frames):
    cols = None
    for f in frames:
        h = (np.asarray(f.getchannel("A")) > THRESH).sum(axis=0)
        cols = h if cols is None else np.maximum(cols, h)
    good = np.nonzero(cols >= 0.5 * cols.max())[0]
    return int(good.min()), int(good.max()) + 1


def main():
    sheet = Image.open(SHEET).convert("RGBA")
    if DEST.exists():
        shutil.rmtree(DEST)
    frames = {a: [cell(sheet, i) for i in range(lo, hi + 1)] for a, (lo, hi, _, _) in ANIMS.items()}
    idle0 = frames["idle"][0]
    l, t, r, b = opaque_box(idle0)
    tx0, tx1 = torso_x(frames["idle"])
    px, py = (tx0 + tx1) / 2.0, float(b)
    entry = {"facing": 1, "flyer": False, "anims": {}}
    idle_boxes = []
    for anim, (lo, hi, fps, loop) in ANIMS.items():
        d = DEST / anim
        d.mkdir(parents=True, exist_ok=True)
        paths, boxes = [], []
        for n, im in enumerate(frames[anim], start=1):
            im.save(d / f"{anim}_{n}.png")
            paths.append(f"{RES}/{anim}/{anim}_{n}.png")
            bb = opaque_box(im)
            boxes.append([0.0, 0.0, 0.0, 0.0] if bb is None else [bb[0] - px, bb[1] - py, bb[2] - px, bb[3] - py])
        if anim == "idle":
            idle_boxes = boxes
        entry["anims"][anim] = {"frames": paths, "fps": fps, "loop": loop, "size": [CW, CH], "pivot": [px, py], "boxes": boxes}
    ys = [bx[1] for bx in idle_boxes]
    entry["body"] = [tx0 - px, min(ys), tx1 - px, max(bx[3] for bx in idle_boxes)]
    data = json.loads(ROSTER.read_bytes().decode("utf-8"))
    data["black_knight"] = entry
    ROSTER.write_bytes(json.dumps(data, indent=1, ensure_ascii=False).encode("utf-8"))
    print("black_knight body", [round(v, 1) for v in entry["body"]], {a: len(v["frames"]) for a, v in entry["anims"].items()})
    for a, v in entry["anims"].items():
        print("  ", a, "max reach", round(max(bx[2] for bx in v["boxes"])), "top", round(min(bx[1] for bx in v["boxes"])))


if __name__ == "__main__":
    main()
