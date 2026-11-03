#!/usr/bin/env python3
"""Build the three forms of King Nerochilde from the owner's purchased art and merge them into assets/enemies/roster.json.

  nero         stage 1: the Medieval King (Luiz Melo's Medieval King Pack 2, bought by the owner), 160 x 111 cells, faces right.
  nero_reaper  stage 2: the owner's skull-cloak reaper GIF (5 frames, 1600 px canvas = native 160 px at x10). The flat brown
               background and the moon disc are removed by colour; frames are cut to one shared box. Faces right.
  nero_giant   stage 3: the owner's skull-giant GIF (23 frames, 400 x 300 = native 200 x 150 at x2, already transparent). Faces LEFT.
  _fx          slash_pale / slash_green: animated slash arcs drawn here (PIL) for stages 2 and 3.

Sources are read from assets/_source/king/ (MedievalKingPack2.zip, king_stage2_reaper.gif, king_stage3_giant.gif). One PNG per
frame goes under assets/characters/king/<form>/<anim>/<anim>_<n>.png (n from 1); the pivot is the bottom centre of the opaque
box of idle frame 1, shared by every anim of a form; boxes are opaque boxes relative to it (the roster format). Only the keys
nero, nero_reaper, nero_giant and _fx.slash_* are written; every other key keeps its bytes.

    python3 tools/build_king_forms.py
"""
import io
import json
import math
import pathlib
import shutil
import zipfile

import numpy as np
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "_source" / "king"
DEST = ROOT / "assets" / "characters" / "king"
ROSTER = ROOT / "assets" / "enemies" / "roster.json"
RES = "res://assets/characters/king"
THRESH = 40
REAPER_BG = [(105, 91, 89), (136, 110, 106)]        # the flat ground colour and the moon disc


def opaque_box(im):
    mask = np.asarray(im.getchannel("A")) > THRESH
    if not mask.any():
        return None
    ys, xs = np.nonzero(mask)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def body_box(frames_boxes_masks):
    """The torso: the columns whose opaque height is at least half the tallest column (a long weapon is thin)."""
    cols = None
    for mask in frames_boxes_masks:
        h = mask.sum(axis=0)
        cols = h if cols is None else np.maximum(cols, h)
    good = np.nonzero(cols >= 0.5 * cols.max())[0]
    return int(good.min()), int(good.max()) + 1


def save_form(form, anims, facing):
    """anims: name -> (frames [RGBA images], fps, loop). All frames of a form share one canvas size."""
    out_dir = DEST / form
    if out_dir.exists():
        shutil.rmtree(out_dir)
    idle0 = anims["idle"][0][0]
    l, t, r, b = opaque_box(idle0)
    cx0, cx1 = body_box([np.asarray(f.getchannel("A")) > THRESH for f in anims["idle"][0]])
    px, py = (cx0 + cx1) / 2.0, float(b)                     # the feet pivot sits under the torso, not the middle of a long weapon
    entry = {"facing": facing, "flyer": False, "anims": {}}
    idle_boxes, masks = [], []
    for name, (frames, fps, loop) in anims.items():
        d = out_dir / name
        d.mkdir(parents=True, exist_ok=True)
        paths, boxes = [], []
        for n, im in enumerate(frames, start=1):
            im.save(d / f"{name}_{n}.png")
            paths.append(f"{RES}/{form}/{name}/{name}_{n}.png")
            bb = opaque_box(im)
            boxes.append([0.0, 0.0, 0.0, 0.0] if bb is None else [bb[0] - px, bb[1] - py, bb[2] - px, bb[3] - py])
            if name == "idle":
                masks.append(np.asarray(im.getchannel("A")) > THRESH)
        if name == "idle":
            idle_boxes = boxes
        entry["anims"][name] = {"frames": paths, "fps": fps, "loop": loop, "size": [frames[0].width, frames[0].height],
                                "pivot": [px, py], "boxes": boxes}
    x0, x1 = body_box(masks)
    ys = [bx[1] for bx in idle_boxes]
    entry["body"] = [x0 - px, min(ys), x1 - px, max(bx[3] for bx in idle_boxes)]
    return entry


# ------------------------------------------------------------------ stage 1: the Medieval King
def king_entry():
    zf = zipfile.ZipFile(SRC / "MedievalKingPack2.zip")
    base = "Medieval King Pack 2/Sprites/"

    def strip(name):
        im = Image.open(io.BytesIO(zf.read(base + name))).convert("RGBA")
        n = im.width // 160
        return [im.crop((i * 160, 0, (i + 1) * 160, im.height)) for i in range(n)]

    anims = {
        "idle": (strip("Idle.png"), 8, True),
        "walk": (strip("Run.png"), 12, True),
        "attack": (strip("Attack1.png"), 8, False),
        "attack2": (strip("Attack2.png"), 8, False),
        "attack3": (strip("Attack3.png"), 8, False),
        "hurt": (strip("Take Hit.png"), 10, False),
    }
    return save_form("nero", anims, 1)


# ------------------------------------------------------------------ stage 2: the reaper
def reaper_entry():
    gif = Image.open(SRC / "king_stage2_reaper.gif")
    frames = []
    for i in range(gif.n_frames):
        gif.seek(i)
        a = np.array(gif.convert("RGBA"))
        small = a[5::10, 5::10].copy()                      # the picture is a 160 px painting drawn at x10: take each block's middle
        for c in REAPER_BG:
            small[(small[:, :, :3] == np.array(c)).all(axis=2), 3] = 0
        frames.append(Image.fromarray(small, "RGBA"))
    return crop_and_pack("nero_reaper", frames, 120, facing=1)


# ------------------------------------------------------------------ stage 3: the giant
def giant_entry():
    gif = Image.open(SRC / "king_stage3_giant.gif")
    frames = []
    for i in range(gif.n_frames):
        gif.seek(i)
        a = np.array(gif.convert("RGBA"))
        small = a[1::2, 1::2].copy()                        # 200 x 150 native, drawn at x2
        frames.append(Image.fromarray(small, "RGBA"))
    return crop_and_pack("nero_giant", frames, 110, facing=-1)


def crop_and_pack(form, frames, ms, facing):
    """One shared crop for every frame, then the anims every form needs (idle, walk, slash, hurt) from the same frames."""
    boxes = [opaque_box(f) for f in frames]
    l = min(b[0] for b in boxes)
    t = min(b[1] for b in boxes)
    r = max(b[2] for b in boxes)
    b = max(b[3] for b in boxes)
    frames = [f.crop((l, t, r, b)) for f in frames]
    fps = round(1000.0 / ms)
    anims = {
        "idle": (frames, fps, True),
        "walk": (frames, fps + 2, True),
        "slash": (frames, fps + 4, False),                 # the idle frames once, faster: the hit window is set in Roster.DEFS
        "hurt": ([frames[0], frames[min(1, len(frames) - 1)], frames[0]], 12, False),
    }
    return save_form(form, anims, facing)


# ------------------------------------------------------------------ slash effects
def slash_frames(col_a, col_b, n=7, size=96):
    """A crescent sweeping from the upper left through the front to the lower right and fading, drawn as crisp pixel art.
    Facing right; the game mirrors it. Drawn at 4x and reduced with nearest sampling so the edge stays hard."""
    big = size * 4
    frames = []
    for i in range(n):
        im = Image.new("RGBA", (big, big), (0, 0, 0, 0))
        dr = ImageDraw.Draw(im)
        cx, cy = big * 0.18, big * 0.50
        reach = (i + 1) / n
        a0 = -60.0
        a1 = a0 + 120.0 * reach
        a_tail = a1 - 70.0                                   # the tail behind the leading edge
        fade = 1.0 if i < n - 2 else max(0.0, 1.0 - (i - (n - 3)) * 0.4)
        for deg in np.arange(max(a0, a_tail), a1, 0.7):
            rad = math.radians(deg)
            k = (deg - a_tail) / 70.0                         # 0 tail .. 1 leading edge
            outer = big * 0.66
            inner = outer - big * (0.03 + 0.12 * k)           # the crescent is thickest at the leading edge
            col = col_b if k > 0.82 else col_a
            for rr in np.arange(inner, outer, 2.0):
                x = cx + math.cos(rad) * rr
                y = cy + math.sin(rad) * rr
                dr.ellipse((x - 4, y - 4, x + 4, y + 4), fill=col + (int(255 * fade * (0.35 + 0.65 * k)),))
        small = im.resize((size, size), Image.NEAREST)
        arr = np.array(small)
        arr[:, :, 3] = np.where(arr[:, :, 3] > 90, 255, 0)  # no soft edge: pixel art
        frames.append(Image.fromarray(arr, "RGBA"))
    return frames


def fx_entry(name, frames):
    d = DEST / "fx" / name
    if d.exists():
        shutil.rmtree(d)
    d.mkdir(parents=True)
    paths = []
    for n, im in enumerate(frames, start=1):
        im.save(d / f"{name}_{n}.png")
        paths.append(f"{RES}/fx/{name}/{name}_{n}.png")
    w, h = frames[0].size
    return {"frames": paths, "fps": 24, "loop": False, "size": [w, h], "pivot": [w * 0.18, h * 0.50], "boxes": [[0.0, 0.0, 0.0, 0.0]] * len(paths)}


def main():
    entries = {"nero": king_entry(), "nero_reaper": reaper_entry(), "nero_giant": giant_entry()}
    fx = {"slash_pale": fx_entry("slash_pale", slash_frames((120, 150, 235), (235, 245, 255))),
          "slash_green": fx_entry("slash_green", slash_frames((120, 170, 60), (235, 240, 150)))}
    before = ROSTER.read_bytes()
    data = json.loads(before.decode("utf-8"))
    wiz = data.get("x_dark_wizard", {}).get("anims", {}).get("bolt")
    if wiz:                                              # the king's dark bolt (stage 1 casts with it): the dark wizard's (Luiz Melo, CC0)
        entries["nero"]["anims"]["bolt"] = json.loads(json.dumps(wiz))
    data.update(entries)
    data.setdefault("_fx", {}).update(fx)
    ROSTER.write_bytes(json.dumps(data, indent=1, ensure_ascii=False).encode("utf-8"))
    for k, e in entries.items():
        print(k, "body", [round(v, 1) for v in e["body"]], {a: len(v["frames"]) for a, v in e["anims"].items()},
              "cell", e["anims"]["idle"]["size"], "pivot", e["anims"]["idle"]["pivot"])


if __name__ == "__main__":
    main()
