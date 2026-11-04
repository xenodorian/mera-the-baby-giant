#!/usr/bin/env python3
"""Build the tunnel level (s4_tunnel, the last level of Stage 4) from the owner's cavern map (assets/_source/tunnel/tunnel_map.jpg).

The 1199 x 1703 map is scaled up x15 with nearest neighbour (pre-scaled x3, the game draws a layer at x5): a passage of 65 source
pixels becomes about 1000 world px, enough for a size 6 Mera (about 350 px tall) to jump without touching the ceiling. The level is TALL:
the camera follows Mera up and down (levels.json "tall": true). The passages are found by thresholding the map; in every column the open
vertical runs give the floors (one-way "surfaces"), and runs taller than 100 source px (the shafts) get ladders up to the floor above.
Enemies fill the floors ("spawns", created when Mera comes near). Re-runnable: python3 tools/build_tunnel.py
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import build_stage3 as B3  # noqa: E402

SRC = ROOT / "assets" / "_source" / "tunnel" / "tunnel_map.jpg"
LEVELS_JSON = ROOT / "assets" / "levels" / "levels.json"
S = 15                      # world px per source px (x3 pre-scale, x5 layer scale)
K = 3
ART = B3.ART
GROUND_Y = B3.GROUND_Y
PADX = 1100                 # world x of source column 0
STEP = 6                    # column step in source px
MIN_RUN = 38                # a passage must be this tall (source px) to count: 570 world px
LADDER_RUN = 90
START_SRC = (130, 1480)     # the orange glow, bottom left
EXIT_SRC = (700, 160)       # the shrine under the light pillar, top centre
LID = "s4_tunnel"


def passages() -> np.ndarray:
    im = Image.open(SRC).convert("L").filter(ImageFilter.GaussianBlur(3))
    m = np.array(im) > 24
    lab, n = ndi.label(m)
    sizes = ndi.sum(m, lab, range(1, n + 1))
    return np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s > 3000])


def runs_of(col: np.ndarray):
    out, s = [], None
    for i, v in enumerate(col):
        if v and s is None:
            s = i
        if not v and s is not None:
            out.append((s, i - 1))
            s = None
    if s is not None:
        out.append((s, len(col) - 1))
    return out


def analyse(m: np.ndarray):
    h, w = m.shape
    cols = []                              # (x, top, bottom)
    for x in range(0, w, STEP):
        for t, b in runs_of(m[:, min(x, w - 1)]):
            if b - t >= MIN_RUN:
                cols.append((x, t, b))
    # floors: group neighbouring columns whose bottoms agree
    cols.sort(key=lambda c: (c[0], c[2]))
    segs = []                              # [x0, x1, y, top]
    for x, t, b in cols:
        y = b - 3
        for sg in segs:
            if sg[1] == x - STEP and abs(sg[2] - y) <= 10:
                sg[1] = x
                sg[4].append(y)
                sg[3] = min(sg[3], t)
                break
        else:
            segs.append([x, x, y, t, [y]])
    surfaces = []
    for x0, x1, y, t, ys in segs:
        if x1 - x0 >= 4 * STEP:
            surfaces.append([x0, x1 + STEP, int(np.median(ys)), t])
    return cols, surfaces


def to_world(sx: float, sy: float, sy_ref: float):
    return PADX + sx * S, GROUND_Y - (sy_ref - sy) * S


def main() -> None:
    m = passages()
    h, w = m.shape
    cols, surfaces = analyse(m)
    sy_ref = max(s[2] for s in surfaces)                     # the lowest floor is the game's ground line
    # start: the floor nearest the orange glow; exit: the floor nearest the shrine
    def nearest(p):
        return min(surfaces, key=lambda s: (max(s[0] - p[0], 0, p[0] - s[1]) ** 2 + (s[2] - p[1]) ** 2))
    st = nearest(START_SRC)
    ex = nearest(EXIT_SRC)
    start = to_world(min(max(START_SRC[0], st[0] + 10), st[1] - 10), st[2], sy_ref)
    exit_p = to_world((ex[0] + ex[1]) / 2, ex[2], sy_ref)
    surf_world = []
    for x0, x1, y, t in surfaces:
        wx0, wy = to_world(x0, y, sy_ref)
        wx1, _ = to_world(x1, y, sy_ref)
        surf_world.append([int(wx0), int(wx1), int(wy)])
    # ladders: tall runs (shafts) climb to the nearest floor above beside them
    ladders = []
    seen = set()
    for x, t, b in cols:
        if b - t < LADDER_RUN:
            continue
        top_y = t + 6
        best = None
        for sx0, sx1, y, _ in surfaces:
            if sx0 - 50 <= x <= sx1 + 50 and t - 10 <= y <= b - 60:
                if best is None or y < best:
                    best = y
        if best is not None:
            top_y = best
        key = (round(x / 150), int(top_y / 40))
        if key in seen:
            continue
        seen.add(key)
        wx, wy_b = to_world(x, b - 3, sy_ref)
        _, wy_t = to_world(x, top_y, sy_ref)
        if wy_b - wy_t >= 400:
            ladders.append([int(wx), int(wy_b), int(wy_t)])
    # enemies
    rng = np.random.default_rng(2828)
    ground_pool = ["cl_grunt", "cl_mud", "cl_rat_king", "cl_knight", "cl_ranger", "cl_weaver", "sx_zombie", "sx_skeleton", "sx_witch", "skeleton",
                   "x_mimic", "x_slime", "x_rat", "x_frost_guardian", "werewolf", "p_orc", "p_goblin", "x_dark_wizard", "x_lightning_mage", "x_wanderer_mage",
                   "p_firemage", "hell_hound", "demon", "death", "lm_skeleton", "lm_goblin", "lm_mushroom"]
    fly_pool = ["x_bat", "flying_eye", "ghost", "fire_skull", "lm_eye", "nightmare"]
    spawns = []
    for x0, x1, y, _ in surfaces:
        wx0, wy = to_world(x0, y, sy_ref)
        wx1, _ = to_world(x1, y, sy_ref)
        length = wx1 - wx0
        if length < 900:
            continue
        n = int(length // 650) + 1
        for i in range(n):
            x = wx0 + 300 + (length - 600) * (i + rng.random() * 0.6) / n
            if abs(x - start[0]) < 2200 and abs(wy - start[1]) < 600:
                continue
            flyer = rng.random() < 0.22
            spawns.append([int(x), int(wy), str((fly_pool if flyer else ground_pool)[int(rng.integers(0, len(fly_pool if flyer else ground_pool)))])])
    boss_at = [int(exit_p[0] - 1400), int(exit_p[1])]
    # art: the map x3 (nearest), padded so source column 0 sits at world x PADX; world px of texture column c is 5 * (c - 205)
    img = Image.open(SRC).convert("RGB").resize((w * K, h * K), Image.NEAREST)
    left = (PADX + 1025) // ART                              # native columns before source column 0
    right = (1100 + 1024) // ART + 1
    canvas = Image.new("RGB", (left + w * K + right, h * K), (4, 3, 8))
    canvas.paste(img, (left, 0))
    dest = ROOT / "assets" / "levels" / LID
    dest.mkdir(parents=True, exist_ok=True)
    canvas.quantize(colors=96, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).save(dest / "ground.png")
    Image.new("RGB", (384, 224), (4, 3, 8)).save(dest / "sky.png")
    layer_y = GROUND_Y - sy_ref * S                           # world y of texture row 0
    layers = [B3.layer(LID, 0.1, 384, B3.SKY_Y, "sky.png", -40),
              {"file": f"res://assets/levels/{LID}/ground.png", "scroll": 1.0, "y": int(layer_y), "z": -10, "period": 0, "w": canvas.width * ART, "modulate": None}]
    # the thumbnail: the window of the map round the start, drawn at game scale
    cw = int(1920 / S)
    ch = int(1080 / S)
    sx0 = int(START_SRC[0] - cw / 2)
    sy0 = int(st[2] - ch * 0.62)
    crop = Image.open(SRC).convert("RGB").crop((max(sx0, 0), max(sy0, 0), max(sx0, 0) + cw, max(sy0, 0) + ch)).resize((384, 216), Image.NEAREST)
    crop.save(dest / "thumb.png")
    bg = [4, 3, 8]
    entry = {"id": LID, "name": "The Hollow Warren", "sub": "Climb the tunnels to the shrine", "layers": layers, "bg": bg,
             "music": "res://assets/perry/music/boss3.ogg", "surfaces": surf_world, "ladders": ladders, "platforms": [], "hazards": [], "marks": [],
             "tall": True, "start": [int(start[0]), int(start[1])], "exit": [int(exit_p[0]), int(exit_p[1])], "boss_at": boss_at, "spawns": spawns}
    raw = LEVELS_JSON.read_text()
    doc = json.loads(raw)
    ids = [lv["id"] for lv in doc["levels"]]
    if LID in ids:
        doc["levels"][ids.index(LID)] = entry
    else:
        doc["levels"].insert(ids.index("s4_gate") + 1, entry)
    LEVELS_JSON.write_text(json.dumps(doc, indent=1))
    print(f"surfaces {len(surf_world)} ladders {len(ladders)} spawns {len(spawns)} start {entry['start']} exit {entry['exit']} boss_at {boss_at}")
    print("canvas", canvas.size, "layer_y", int(layer_y), "map_w", canvas.width * ART - 1024 - 1100)
    # debug overlay
    dbg = Image.open(SRC).convert("RGB")
    from PIL import ImageDraw
    d = ImageDraw.Draw(dbg)
    for x0, x1, y, _ in surfaces:
        d.line((x0, y, x1, y), fill=(0, 255, 0), width=3)
    for lx, lb, lt in [(l[0], l[1], l[2]) for l in ladders]:
        sx = (lx - PADX) / S
        d.line((sx, sy_ref - (GROUND_Y - lb) / S, sx, sy_ref - (GROUND_Y - lt) / S), fill=(255, 255, 0), width=2)
    d.ellipse((START_SRC[0] - 10, START_SRC[1] - 10, START_SRC[0] + 10, START_SRC[1] + 10), outline=(255, 128, 0), width=4)
    d.ellipse((EXIT_SRC[0] - 10, EXIT_SRC[1] - 10, EXIT_SRC[0] + 10, EXIT_SRC[1] + 10), outline=(255, 0, 255), width=4)
    dbg.resize((600, 852)).save("/tmp/claude-0/-home-user/30a3820d-cdd0-52ad-96e4-ef061324fb98/scratchpad/tunnel_debug.png")


if __name__ == "__main__":
    main()
