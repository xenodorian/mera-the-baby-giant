#!/usr/bin/env python3
"""Build the nine Stage 4 levels from the owner's two stacked painting strips (assets/_source/stage4/).

The strips were split at their seams (rows 168, 336, 504, 673 of the 474 x 842 strip and 104, 300, 446 of the 335 x 597 one) into
nine scenes, scene1..9.png. Each scene is scaled up x2 with nearest neighbour (the game draws a layer at x5, so one source pixel is
10 screen pixels: massive pixel art), mirrored every other repeat so the painting tiles without a seam, and laid along the whole map
as the level's ground layer with its own walkway at native row 212 (GROUND_Y 1060). Floating stone slabs (one-way ledges, drawn in the
scene's own stone colours) are added in staircases and listed as "surfaces". Output per level: ground.png, sky.png, thumb.png and the
levels.json entry (inserted after ch_faces, in order). Re-runnable: python3 tools/build_stage4.py
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import build_stage3 as B3  # noqa: E402

SRC = ROOT / "assets" / "_source" / "stage4"
LEVELS_JSON = ROOT / "assets" / "levels" / "levels.json"
K = 2                       # nearest neighbour scale of the painting
SCALE = {6: 3}              # the Golden Terrace painting is only 104 rows tall: x3 so it fills the screen without stretching its top row
ART = B3.ART
IMG_X0 = B3.IMG_X0
FLOOR_ROW = B3.FLOOR_ROW    # 212
GROUND_Y = B3.GROUND_Y

# id, name, sub, scene file, floor row in the scene (top of its walkway), map width px, music
LEVELS = [
    ("s4_drowned", "Drowned Ruins", "Pillars stand in the flood", 1, 152, 12000, "res://assets/perry/music/level6.ogg"),
    ("s4_skyline", "Bluelit Skyline", "A dead city under a pale sky", 2, 150, 12800, "res://assets/perry/music/level5.ogg"),
    ("s4_clock", "Clocktower Quarter", "The clock still counts", 3, 153, 13600, "res://assets/perry/music/level4.ogg"),
    ("s4_chapel", "Overgrown Chapel", "Roots hold the walls up", 4, 152, 14400, "res://assets/perry/music/level3.ogg"),
    ("s4_courtyard", "Sunken Courtyard", "Doors that lead nowhere", 5, 156, 15200, "res://assets/perry/music/level2.ogg"),
    ("s4_terrace", "Golden Terrace", "White stone and gold leaves", 6, 90, 13000, "res://assets/perry/music/level1.ogg"),
    ("s4_vault", "Hoard Vault", "Candles over the king's gold", 7, 176, 14000, "res://assets/music/caverns.ogg"),
    ("s4_mushroom", "Mushroom Hollow", "A forest that glows", 8, 116, 14800, "res://assets/music/mist.ogg"),
    ("s4_gate", "Gilded Gate", "The Black Knight keeps the way", 9, 121, 16000, "res://assets/perry/music/boss4.ogg"),
]


def tile_scene(scene: Image.Image, floor_src: int, wpx: int, K: int = K) -> np.ndarray:
    """216 rows x wpx columns RGBA: the scene x2, mirrored on alternate repeats, its walkway on native row 212."""
    big = scene.convert("RGBA").resize((scene.width * K, scene.height * K), Image.NEAREST)
    a = np.asarray(big)
    h2, w2 = a.shape[:2]
    reps = wpx // w2 + 2
    row = np.concatenate([a if n % 2 == 0 else a[:, ::-1] for n in range(reps)], axis=1)[:, :wpx]
    top = FLOOR_ROW - floor_src * K                    # native row where scene row 0 lands
    out = np.zeros((216, wpx, 4), dtype=np.uint8)
    for r in range(216):
        sr = r - top
        sr = min(max(sr, 0), h2 - 1)                   # above the painting: its top row stretched up
        out[r] = row[sr]
    return out


def stone_colours(scene: Image.Image, floor_src: int):
    a = np.asarray(scene.convert("RGB"))
    band = a[min(floor_src + 1, a.shape[0] - 1)]
    body = a[min(floor_src + 4, a.shape[0] - 1)]
    top = np.median(band, axis=0).astype(int)
    bod = np.median(body, axis=0).astype(int)
    return tuple(int(v) for v in np.clip(top * 1.25 + 20, 0, 255)), tuple(int(v) for v in bod), tuple(int(v) for v in np.clip(bod * 0.45, 0, 255))


def slabs_for(level_index: int, map_w: int) -> list:
    """Staircase groups of floating slabs [x0, x1, tier]: up three, down two, then open ground."""
    rng = np.random.default_rng(4400 + level_index)
    out = []
    x = 2600
    while x < map_w - 4200:
        w = int(rng.integers(760, 1000))
        pattern = [(0, 1), (1000, 2), (2000, 3), (3000, 2), (4000, 1)] if rng.random() < 0.6 else [(0, 1), (1100, 2), (2200, 1)]
        for dx, t in pattern:
            out.append([x + dx, x + dx + w, t])
        x += pattern[-1][0] + w + int(rng.integers(1700, 2600))
    return out


def draw_slabs(img: np.ndarray, slabs: list, cols) -> None:
    top_c, body_c, edge_c = cols
    for x0, x1, t in slabs:
        c0 = x0 // ART + IMG_X0
        c1 = x1 // ART + IMG_X0
        y = FLOOR_ROW - 26 * t                         # a tier is 130 px = 26 native rows
        for c in range(c0, c1):
            if c < 0 or c >= img.shape[1]:
                continue
            for r in range(y, y + 13):
                if r < 0 or r >= 216:
                    continue
                col = top_c if r < y + 2 else (edge_c if r >= y + 11 or c in (c0, c1 - 1) else body_c)
                img[r, c] = (*col, 255)
        # chipped underside
        for c in range(c0 + 2, c1 - 2, 5):
            if 0 <= c < img.shape[1] and 0 <= y + 13 < 216:
                img[y + 13, c] = (*edge_c, 255)


def main() -> None:
    raw = LEVELS_JSON.read_text()
    doc = json.loads(raw)
    assert json.dumps(doc, indent=1) == raw, "levels.json is not in the expected format"
    ids = [lv["id"] for lv in doc["levels"]]
    entries = []
    for n, (lid, name, sub, sc, floor_src, map_w, music) in enumerate(LEVELS):
        scene = Image.open(SRC / f"scene{sc}.png").convert("RGB")
        wpx = (map_w + 1024 + 1100) // ART + 1
        img = tile_scene(scene, floor_src, wpx, SCALE.get(sc, K))
        slabs = slabs_for(n, map_w)
        draw_slabs(img, slabs, stone_colours(scene, floor_src))
        dest = ROOT / "assets" / "levels" / lid
        dest.mkdir(parents=True, exist_ok=True)
        Image.fromarray(img, "RGBA").quantize(colors=200, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).convert("RGBA").save(dest / "ground.png")
        # the sky: the painting's top row colour fading to its horizon colour (a 1 x 224 strip stretched; behind the painting)
        a = np.asarray(scene)
        c_top = a[0].mean(axis=0)
        c_low = a[min(floor_src // 2, a.shape[0] - 1)].mean(axis=0)
        sky = np.zeros((224, 384, 3), dtype=np.uint8)
        for r in range(224):
            f = r / 223.0
            sky[r, :] = np.clip(c_top * (1 - f) + c_low * f, 0, 255)
        Image.fromarray(sky, "RGB").save(dest / "sky.png")
        assert B3.res_path(music).is_file(), music
        layers = [B3.layer(lid, 0.1, 384, B3.SKY_Y, "sky.png", -40),
                  {"file": f"res://assets/levels/{lid}/ground.png", "scroll": 1.0, "y": 0, "z": -10, "period": 0, "w": wpx * ART, "modulate": None}]
        bg = [int(v) for v in c_top]
        B3.save_thumb(dest, bg, layers)
        surfaces = [[x0, x1, GROUND_Y - 130 * t] for x0, x1, t in slabs]
        entries.append({"id": lid, "name": name, "sub": sub, "layers": layers, "bg": bg, "music": music,
                        "surfaces": surfaces, "ladders": [], "platforms": [], "hazards": [], "marks": []})
        print(f"{lid:14s} scene{sc} scene {scene.width}x{scene.height} floor {floor_src} map_w {map_w} slabs {len(slabs)}")
    anchor = ids.index("ch_faces") + 1
    for i, e in enumerate(entries):
        if e["id"] in ids:
            doc["levels"][ids.index(e["id"])] = e
        else:
            doc["levels"].insert(anchor + i, e)
            ids.insert(anchor + i, e["id"])
    for lv in doc["levels"]:
        for L in lv["layers"]:
            assert B3.res_path(L["file"]).is_file(), L["file"]
    LEVELS_JSON.write_text(json.dumps(doc, indent=1))
    print("levels:", len(doc["levels"]), [lv["id"] for lv in doc["levels"]][17:30])


if __name__ == "__main__":
    main()
