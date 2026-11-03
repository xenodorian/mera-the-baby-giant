#!/usr/bin/env python3
"""Cut the three Craftpix free wizards into roster entries (merged into assets/enemies/roster.json).

  p_firemage        the Fire Wizard (replaces Perry Riposte's fire mage, which was drawn from this same sprite)
  x_lightning_mage  the Lightning Mage
  x_wanderer_mage   the Wanderer Magician

Source: assets/_source/craftpix_wizards/<Folder>/<Strip>.png (not committed: the owner's free Craftpix download, see
docs/CREDITS.md). Character strips use 128 px cells (the figure is about 64 px tall), the loose effect strips 64 px wide cells.
Everything faces right as drawn. One PNG per frame goes to assets/characters/craftpix_wizards/<id>/<anim>/<anim>_<n>.png. The
pivot is the bottom centre of the opaque box of idle frame 1 and is shared by every character anim; boxes are opaque boxes
relative to it. Effect anims (bolt, blast) pivot on the middle of their cell. Only these three roster keys are written.

    python3 tools/build_wizards.py
"""
import json
import pathlib
import shutil

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "_source" / "craftpix_wizards"
DEST = ROOT / "assets" / "characters" / "craftpix_wizards"
ROSTER = ROOT / "assets" / "enemies" / "roster.json"
RES = "res://assets/characters/craftpix_wizards"
THRESH = 40

# id -> (folder, character anims {anim: (strip, fps, loop)}, effect anims {anim: (strip, cell width, first frame, last frame, fps, loop)})
WIZARDS = {
    "p_firemage": ("Fire Wizard",
        {"idle": ("Idle", 8, True), "walk": ("Walk", 8, True), "slash": ("Attack_1", 10, False), "spark": ("Attack_2", 10, False),
         "fireball": ("Fireball", 10, False), "flame": ("Flame_jet", 14, False), "hurt": ("Hurt", 10, False), "death": ("Dead", 8, False)},
        {"bolt": ("Charge", 64, 0, 5, 14, True), "blast": ("Charge", 64, 6, 11, 16, False)}),
    "x_lightning_mage": ("Lightning Mage",
        {"idle": ("Idle", 8, True), "walk": ("Walk", 9, True), "strike": ("Attack_1", 12, False), "spark": ("Attack_2", 10, False),
         "ball": ("Light_ball", 10, False), "beam": ("Light_charge", 14, False), "hurt": ("Hurt", 10, False), "death": ("Dead", 8, False)},
        {"bolt": ("Charge", 64, 0, 5, 14, True), "blast": ("Charge", 64, 6, 9, 16, False)}),
    "x_wanderer_mage": ("Wanderer Magican",
        {"idle": ("Idle", 8, True), "walk": ("Walk", 9, True), "sparkle": ("Attack_1", 10, False), "star": ("Attack_2", 11, False),
         "arrow": ("Magic_arrow", 10, False), "frost": ("Magic_sphere", 14, False), "hurt": ("Hurt", 10, False), "death": ("Dead", 8, False)},
        {"bolt": ("Charge_2", 64, 0, 5, 14, True), "blast": ("Charge_1", 64, 4, 8, 16, False)}),
}


def opaque_box(im):
    mask = np.asarray(im.getchannel("A")) > THRESH
    if not mask.any():
        return None
    ys, xs = np.nonzero(mask)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def strip_frames(folder, name, cell_w, first=0, last=None):
    im = Image.open(SRC / folder / f"{name}.png").convert("RGBA")
    n = im.width // cell_w
    last = n - 1 if last is None else min(last, n - 1)
    return [im.crop((i * cell_w, 0, (i + 1) * cell_w, im.height)) for i in range(first, last + 1)]


def torso_x(frames):
    """x range of the body: columns at least half as tall as the tallest, over the idle frames (a wand or flame is thin)."""
    cols = None
    for f in frames:
        h = (np.asarray(f.getchannel("A")) > THRESH).sum(axis=0)
        cols = h if cols is None else np.maximum(cols, h)
    good = np.nonzero(cols >= 0.5 * cols.max())[0]
    return int(good.min()), int(good.max()) + 1


def build(eid, folder, chars, effects):
    out_dir = DEST / eid
    if out_dir.exists():
        shutil.rmtree(out_dir)
    idle = strip_frames(folder, chars["idle"][0], 128)
    l, t, r, b = opaque_box(idle[0])
    tx0, tx1 = torso_x(idle)
    px, py = (tx0 + tx1) / 2.0, float(b)
    entry = {"facing": 1, "flyer": False, "anims": {}}
    idle_boxes = []

    def save(anim, frames, fps, loop, pivot):
        d = out_dir / anim
        d.mkdir(parents=True, exist_ok=True)
        paths, boxes = [], []
        for n, im in enumerate(frames, start=1):
            im.save(d / f"{anim}_{n}.png")
            paths.append(f"{RES}/{eid}/{anim}/{anim}_{n}.png")
            bb = opaque_box(im)
            boxes.append([0.0, 0.0, 0.0, 0.0] if bb is None else [bb[0] - pivot[0], bb[1] - pivot[1], bb[2] - pivot[0], bb[3] - pivot[1]])
        entry["anims"][anim] = {"frames": paths, "fps": fps, "loop": loop, "size": [frames[0].width, frames[0].height],
                                "pivot": [pivot[0], pivot[1]], "boxes": boxes}
        return boxes

    for anim, (strip, fps, loop) in chars.items():
        boxes = save(anim, strip_frames(folder, strip, 128), fps, loop, (px, py))
        if anim == "idle":
            idle_boxes = boxes
    for anim, (strip, cw, a, z, fps, loop) in effects.items():
        fr = strip_frames(folder, strip, cw, a, z)
        save(anim, fr, fps, loop, (fr[0].width / 2.0, fr[0].height / 2.0))
    ys = [bx[1] for bx in idle_boxes]
    entry["body"] = [tx0 - px, min(ys), tx1 - px, max(bx[3] for bx in idle_boxes)]
    return entry


def main():
    data = json.loads(ROSTER.read_bytes().decode("utf-8"))
    for eid, (folder, chars, effects) in WIZARDS.items():
        data[eid] = build(eid, folder, chars, effects)
        e = data[eid]
        print(eid, "body", [round(v, 1) for v in e["body"]], {a: len(v["frames"]) for a, v in e["anims"].items()})
    ROSTER.write_bytes(json.dumps(data, indent=1, ensure_ascii=False).encode("utf-8"))


if __name__ == "__main__":
    main()
