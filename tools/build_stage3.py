#!/usr/bin/env python3
"""Build the Stage 3 levels and put them into assets/levels/levels.json (rerunnable).

* p_arena: Perry's boss arena, from Perry's own keep backgrounds (assets/perry/maps/arenas/keep_*.png).
* ch_*: the eight Changeling maps (assets/changeling/source/src/levels.js, DCSS tiles in
  assets/changeling/source/tiles/) flattened into Mera levels (docs/STAGE3_PLAN.md, "Map conversion rule").

Conversion rule used here:
  * a column is COLW game px wide (135, so a map of 72+ columns is at least 9600 px; the 40 column
    Warlord's Throne uses 180 and is a 7200 px arena, map_w 7200);
  * the floor row is the row under the start tile 'S'; it becomes GROUND_Y (1060). Pits become floor
    with a hazard strip, floor spikes stay as a strip (both listed in "hazards", art only);
  * a ledge ('=' or '_' above the floor) h rows above the floor goes to tier ceil(h / 3), at most 6, and
    a tier is TIER_PX (130) px high. Tiers are one jump (about 160 px) apart, steps stay <= 140 px;
  * a ledge with no lower surface (<= 140 px under it) within LADDER_REACH gets a ladder from the surface
    below (or the floor) up to it: "ladders": [[x, bottom_y, top_y]];
  * "platforms": [] (run time platforms are built by the ranger ally, none are authored);
  * walls '#' above the floor are scenery only, cracked walls 'x' are floor (the secrets are Props'),
    letters become "marks": [[letter, x], ...] in reading order (g grunt, m mud revenant, j rat king,
    a archer, W warlord, c secret card, k route card, p power-up).
World x of an image pixel i is 5 * (i - IMG_X0) (game.gd puts a x5 layer at -960 - pad = -1024).
Never run tools/build_levels.py.
"""
import json
import math
import re
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
LEVELS_JSON = ROOT / "assets" / "levels" / "levels.json"
SRC_JS = ROOT / "assets" / "changeling" / "source" / "src" / "levels.js"
TILES = ROOT / "assets" / "changeling" / "source" / "tiles"
ARENAS = ROOT / "assets" / "perry" / "maps" / "arenas"

ART = 5
SCREEN_W, SCREEN_H = 1920, 1080
GROUND_Y = 1060
IMG_ROWS = 216            # ground layer at y 0, 216 rows x5 = 1080
FLOOR_ROW = GROUND_Y // ART   # 212
SKY_Y = -40
SKY_ROWS = 224            # -40 + 224 * 5 = 1080
COLW = 135
THRONE_COLW = 180
TIER_PX = 130
MAX_TIER = 6
LADDER_REACH = 350
IMG_X0 = 205              # image pixel that is world x 0 (game.gd draws image x 0 at world -1024)
START_CAM = 760.0         # Mera starts at x 760 (game.gd)
PAD = 64

# id, display name, sub, index in levels.js, theme, music
MAPS = [
    ("ch_greenwood", "Greenwood Road", "A quiet road and a loud welcome", 0, "field", "res://assets/music/country.ogg"),
    ("ch_bramble", "Bramble Hollow", "Thorns, spikes and a narrow shaft", 1, "field", "res://assets/perry/music/level1.ogg"),
    ("ch_watchtower", "Old Watchtower", "Archers watch from the ledges", 2, "field", "res://assets/perry/music/level3.ogg"),
    ("ch_marsh", "Rotting Marsh", "Cracked walls and murky water", 3, "marsh", "res://assets/music/mist.ogg"),
    ("ch_gate", "Castle Gate", "The Warlord waits at the top", 4, "castle", "res://assets/music/cemetery.ogg"),
    ("ch_undercroft", "Undercroft", "Cold stone under the castle", 5, "crypt", "res://assets/music/town.ogg"),
    ("ch_faces", "Hall of Faces", "Every face has its throne", 6, "hall", "res://assets/music/caverns.ogg"),
    ("ch_throne", "Warlord's Throne", "The Warlord of the Changeling", 7, "castle", "res://assets/perry/music/boss5.ogg"),
]
THRONE_ID = "ch_throne"

PAL = {
    "field": dict(top=(98, 160, 214), bot=(196, 224, 240), hill1=(150, 190, 214), hill2=(104, 160, 140),
                  tree=(0.55, 0.85, 0.65), bg=(127, 182, 224)),
    "marsh": dict(top=(120, 150, 110), bot=(198, 206, 150), hill1=(140, 160, 120), hill2=(92, 118, 74),
                  tree=(0.45, 0.62, 0.40), bg=(120, 150, 110)),
    "castle": dict(tint=(0.30, 0.26, 0.38), edge=(156, 143, 176), bg=(23, 20, 31)),
    "crypt": dict(tint=(0.16, 0.30, 0.36), edge=(134, 185, 191), bg=(12, 23, 29)),
    "hall": dict(tint=(0.40, 0.20, 0.20), edge=(217, 164, 65), bg=(28, 16, 18)),
}
DUNGEON = ("castle", "crypt", "hall")


def res_path(res: str) -> Path:
    assert res.startswith("res://"), res
    return ROOT / res[len("res://"):]


def parse_maps() -> list:
    s = SRC_JS.read_text()
    out = [re.findall(r'^\s+"([.#=_^xSFTicpkgmajWl]+)",$', b, re.M) for b in s.split('    name: "')[1:]]
    assert len(out) == 8, len(out)
    return out


# ------------------------------------------------------------------ pixel helpers (float H x W x 4 arrays)
def load_tile(name: str) -> np.ndarray:
    return np.asarray(Image.open(TILES / f"{name}.png").convert("RGBA")).astype(np.float64)


GRASS = load_tile("grass0")
DIRT = load_tile("grey_dirt0")
BRICK = load_tile("brick_brown0")
TREE = load_tile("tree1")


def tinted(tile: np.ndarray, mul) -> np.ndarray:
    out = tile.copy()
    out[:, :, :3] = np.clip(out[:, :, :3] * np.array(mul), 0, 255)
    return out


def grey_tinted(tile: np.ndarray, mul) -> np.ndarray:
    """the tile in greys, then multiplied by a colour (dungeon stone takes the theme colour, not the brick orange)"""
    out = tile.copy()
    lum = out[:, :, :3] @ np.array([0.3, 0.59, 0.11])
    out[:, :, :3] = np.clip(lum[:, :, None] * np.array(mul), 0, 255)
    return out


def blit(dst: np.ndarray, src: np.ndarray, x: int, y: int) -> None:
    h, w = src.shape[:2]
    x0, y0 = max(x, 0), max(y, 0)
    x1, y1 = min(x + w, dst.shape[1]), min(y + h, dst.shape[0])
    if x1 <= x0 or y1 <= y0:
        return
    s = src[y0 - y:y1 - y, x0 - x:x1 - x]
    d = dst[y0:y1, x0:x1]
    a = s[:, :, 3:4] / 255.0
    da = d[:, :, 3:4] / 255.0
    oa = a + da * (1.0 - a)
    rgb = np.where(oa > 0, (s[:, :, :3] * a + d[:, :, :3] * da * (1.0 - a)) / np.maximum(oa, 1e-6), 0)
    d[:, :, :3] = rgb
    d[:, :, 3:4] = oa * 255.0


def fill(dst, x0, y0, x1, y1, rgba) -> None:
    if x1 <= x0 or y1 <= y0:
        return
    blit(dst, np.broadcast_to(np.array(rgba, dtype=np.float64), (y1 - y0, x1 - x0, 4)).copy(), x0, y0)


def tile_fill(dst, tile, x0, y0, x1, y1, flip_alt=True) -> None:
    for ty in range(y0, y1, 32):
        for k, tx in enumerate(range(x0, x1, 32)):
            t = tile[:, ::-1] if (flip_alt and k % 2) else tile
            blit(dst, t[:min(32, y1 - ty), :min(32, x1 - tx)], tx, ty)


def to_img(arr: np.ndarray) -> Image.Image:
    return Image.fromarray(np.clip(np.round(arr), 0, 255).astype(np.uint8), "RGBA")


# ------------------------------------------------------------------ map analysis
def tier_of(h: int) -> int:
    return min(max(math.ceil(h / 3), 1), MAX_TIER)


def runs(cols: list) -> list:
    out, start, prev = [], None, None
    for c in sorted(cols) + [None]:
        if c is not None and prev is not None and c == prev + 1:
            prev = c
            continue
        if prev is not None:
            out.append((start, prev + 1))
        start = prev = c
    return out


def analyse(rows: list, colw: int) -> dict:
    nr, nc = len(rows), len(rows[0])
    sr = next(r for r in range(nr) for c in range(nc) if rows[r][c] == "S")
    floor = sr + 1
    by_tier = {}
    for r in range(floor):
        for c in range(nc):
            if rows[r][c] in "=_":
                by_tier.setdefault(tier_of(floor - r), set()).add(c)
    surfaces = []                      # [x0, x1, y, tier]
    for t in sorted(by_tier):
        for a, b in runs(list(by_tier[t])):
            surfaces.append([a * colw, b * colw, GROUND_Y - TIER_PX * t, t])
    surfaces.sort(key=lambda s: (s[0], s[2]))
    # a pit has nothing solid from the floor row down (a column with a lower floor, as in the Old Watchtower, is not one)
    pit_cols = [c for c in range(nc) if all(rows[r][c] in ".^" for r in range(floor, nr))]
    spike_cols = [c for c in range(nc) if rows[floor - 1][c] == "^"]
    hazards = sorted([[a * colw, b * colw] for a, b in runs(pit_cols)] + [[a * colw, b * colw] for a, b in runs(spike_cols)])
    marks = sorted(([c, r, rows[r][c]] for c in range(nc) for r in range(nr) if rows[r][c] in "gmjaWckp"))
    marks = [[m[2], m[0] * colw + colw // 2] for m in marks]
    return dict(floor=floor, nr=nr, nc=nc, surfaces=surfaces, hazards=hazards, marks=marks,
                pit_cols=set(pit_cols), spike_cols=spike_cols)


def make_ladders(surfaces: list) -> list:
    ladders = []
    for s in surfaces:
        x0, x1, y = s[0], s[1], s[2]
        if y >= GROUND_Y - 140:
            continue
        if any(o is not s and 0 < o[2] - y <= 140 and o[0] - LADDER_REACH <= x1 and o[1] + LADDER_REACH >= x0
               for o in surfaces):
            continue
        lx = x0 + min(60, (x1 - x0) // 2)
        bottom = GROUND_Y
        for o in surfaces:
            if o[2] > y and o[0] <= lx <= o[1] and o[2] < bottom:
                bottom = o[2]
        ladders.append([lx, bottom, y])
    return ladders


# ------------------------------------------------------------------ ground layer
def draw_spikes(img, x0, x1, base_y) -> None:
    n = max(1, (x1 - x0) // 9)
    for i in range(n):
        cx = x0 + int((i + 0.5) * (x1 - x0) / n)
        for k in range(10):
            half = (10 - k) * 4 // 10
            fill(img, cx - half, base_y - 10 + k, cx + half + 1, base_y - 9 + k, (190, 196, 206, 255))
        fill(img, cx, base_y - 10, cx + 1, base_y - 8, (240, 244, 250, 255))


def stretch(tile: np.ndarray, w: int, h: int, flip: bool) -> np.ndarray:
    t = tile[:, ::-1] if flip else tile
    yi = (np.arange(h) * 32 // h)
    xi = (np.arange(w) * 32 // w)
    return t[yi][:, xi]


def draw_ground(theme: str, rows: list, info: dict, colw: int, wpx: int) -> Image.Image:
    cw = colw // ART
    img = np.zeros((IMG_ROWS, wpx, 4), dtype=np.float64)
    pal = PAL[theme]
    dungeon = theme in DUNGEON
    floor, nr, nc = info["floor"], info["nr"], info["nc"]
    rng = np.random.RandomState(nc)
    tint = np.array(pal["tint"]) if dungeon else None
    wall_tile = grey_tinted(BRICK, tuple(tint * 2.4)) if dungeon else tinted(BRICK, (0.5, 0.45, 0.5))
    dirt_tile = grey_tinted(DIRT, tuple(tint * 3.0)) if dungeon else tinted(DIRT, (1.05, 0.82, 0.58))
    rows_per = TIER_PX / 3.0 / ART       # native rows per map row (linear scale for scenery walls)

    def cx(c):
        return IMG_X0 + c * cw

    for c in range(nc):
        x0, x1 = cx(c), cx(c) + cw
        cap = next((r for r in range(floor) if rows[r][c] in "=_"), None)
        plateau = cap is not None and cap < floor - 1 and all(rows[r][c] in "#=x" for r in range(cap + 1, floor))
        if plateau:
            ty = FLOOR_ROW - TIER_PX * tier_of(floor - cap) // ART
            tile_fill(img, wall_tile, x0, ty, x1, FLOOR_ROW)
            fill(img, x0, ty, x1, FLOOR_ROW, (0, 0, 0, 90))
        for r in range(floor):
            if rows[r][c] not in "#x" or (plateau and r > cap):
                continue
            y1 = FLOOR_ROW - int(round((floor - r - 1) * rows_per))
            y0 = FLOOR_ROW - int(round((floor - r) * rows_per))
            blit(img, stretch(wall_tile, cw, y1 - y0, c % 2 == 1), x0, y0)
            fill(img, x0, y0, x1, y1, (0, 0, 0, 70))

    for c in range(nc):                  # trees and sign posts stand on the floor
        for r in range(nr):
            ch = rows[r][c]
            if ch == "T" and not dungeon and r >= floor - 4:
                blit(img, np.repeat(np.repeat(TREE, 2, axis=0), 2, axis=1), cx(c) + cw // 2 - 32, FLOOR_ROW - 60)
            elif ch == "i" and r >= floor - 4:
                x = cx(c) + cw // 2
                fill(img, x - 1, FLOOR_ROW - 14, x + 1, FLOOR_ROW, (110, 78, 44, 255))
                fill(img, x - 7, FLOOR_ROW - 20, x + 7, FLOOR_ROW - 11, (168, 128, 72, 255))
                fill(img, x - 5, FLOOR_ROW - 17, x + 5, FLOOR_ROW - 15, (92, 66, 38, 255))

    for s in info["surfaces"]:           # ledge slabs
        x0, x1, y = IMG_X0 + s[0] // ART, IMG_X0 + s[1] // ART, s[2] // ART
        cols = range(s[0] // colw, s[1] // colw)
        thin = all(rows[r][c] != "=" for r in range(floor) for c in cols if tier_of(floor - r) == s[3])
        if thin:
            fill(img, x0, y, x1, y + 5, (154, 116, 66, 255))
            fill(img, x0, y, x1, y + 1, (200, 160, 98, 255))
            fill(img, x0, y + 4, x1, y + 5, (96, 68, 38, 255))
            for px in range(x0 + 8, x1, 16):
                fill(img, px, y + 1, px + 1, y + 5, (96, 68, 38, 255))
        elif dungeon:
            tile_fill(img, dirt_tile, x0, y, x1, y + 12)
            fill(img, x0, y, x1, y + 2, tuple(pal["edge"]) + (255,))
            fill(img, x0, y + 9, x1, y + 12, (0, 0, 0, 80))
        else:
            tile_fill(img, dirt_tile, x0, y + 4, x1, y + 12)
            tile_fill(img, GRASS, x0, y, x1, y + 5)
            fill(img, x0, y + 9, x1, y + 12, (0, 0, 0, 60))

    for c in range(nc):                  # the floor strip, pits
        x0, x1 = cx(c), cx(c) + cw
        if dungeon:
            tile_fill(img, dirt_tile, x0, FLOOR_ROW, x1, IMG_ROWS)
            if theme == "hall":
                fill(img, x0, FLOOR_ROW, x1, FLOOR_ROW + 2, (138, 34, 48, 255))
                fill(img, x0, FLOOR_ROW + 2, x1, FLOOR_ROW + 3, (217, 164, 65, 255))
            else:
                fill(img, x0, FLOOR_ROW, x1, FLOOR_ROW + 1, tuple(pal["edge"]) + (255,))
        else:
            tile_fill(img, dirt_tile, x0, FLOOR_ROW + 2, x1, IMG_ROWS)
            tile_fill(img, GRASS, x0, FLOOR_ROW, x1, FLOOR_ROW + 3)
            for tx in range(x0, x1, 3):
                if rng.rand() < 0.45:
                    fill(img, tx, FLOOR_ROW - 1 - rng.randint(0, 2), tx + 1, FLOOR_ROW, (52, 120, 52, 255))
        if c in info["pit_cols"]:
            if dungeon:
                fill(img, x0, FLOOR_ROW, x1, IMG_ROWS, (8, 6, 12, 255))
                draw_spikes(img, x0, x1, FLOOR_ROW + 8)
            else:
                fill(img, x0, FLOOR_ROW, x1, IMG_ROWS, (38, 52, 28, 255))
                fill(img, x0, FLOOR_ROW, x1, FLOOR_ROW + 1, (155, 176, 122, 255))
    for c in info["spike_cols"]:
        draw_spikes(img, cx(c), cx(c) + cw, FLOOR_ROW)
    return to_img(img)


# ------------------------------------------------------------------ sky layers (384 x 224 native, loops at 1920 px)
def draw_sky_field(theme: str) -> Image.Image:
    pal = PAL[theme]
    w, h = 384, SKY_ROWS
    img = np.zeros((h, w, 4), dtype=np.float64)
    t = np.linspace(0, 1, h)[:, None, None]
    img[:, :, :3] = np.array(pal["top"]) * (1 - t) + np.array(pal["bot"]) * t
    img[:, :, 3] = 255
    xs = np.arange(w)
    rng = np.random.RandomState(7)
    for _ in range(7):                   # clouds wrap around the edge
        cxp, cyp, rw = rng.randint(0, w), rng.randint(20, 90), rng.randint(14, 30)
        for dx in range(-rw, rw + 1):
            hh = int(math.sqrt(max(rw * rw - dx * dx, 0)) * 0.35)
            x = (cxp + dx) % w
            fill(img, x, cyp - hh, x + 1, cyp + hh // 2 + 1, (255, 255, 255, 150))
    for hill, base, amp, k, ph in (("hill1", 150, 26, 2, 0.4), ("hill2", 178, 20, 3, 1.7)):
        top = (base + amp * np.sin(2 * math.pi * k * xs / w + ph) + 8 * np.sin(2 * math.pi * 5 * xs / w)).astype(int)
        for x in xs:
            fill(img, x, top[x], x + 1, h, tuple(pal[hill]) + (255,))
        if hill == "hill2":              # a far tree line on the near hill
            tt = tinted(TREE, pal["tree"])
            for i, tx in enumerate(range(0, w, 36)):
                big = i % 2 == 1
                src = np.repeat(np.repeat(tt, 2, 0), 2, 1) if big else tt
                blit(img, src, tx, int(top[(tx + 32) % w]) + 4 - src.shape[0])
    return to_img(img)


def draw_sky_dungeon(theme: str) -> Image.Image:
    tint = np.array(PAL[theme]["tint"])
    w, h = 384, SKY_ROWS
    img = np.zeros((h, w, 4), dtype=np.float64)
    tile_fill(img, grey_tinted(BRICK, tuple(tint * 2.4)), 0, 0, w, h, flip_alt=False)
    for px in range(0, w, 192):          # pillars (192 divides 384 so the strip still loops)
        tile_fill(img, grey_tinted(BRICK, tuple(tint * 3.6)), px + 80, 0, px + 112, h, flip_alt=False)
        fill(img, px + 80, 0, px + 82, h, (0, 0, 0, 120))
        fill(img, px + 110, 0, px + 112, h, (0, 0, 0, 120))
    shade = 1.0 - np.linspace(0.55, 0.0, h)[:, None, None] * 0.45
    img[:, :, :3] *= shade
    img[:, :, 3] = 255
    return to_img(img)


# ------------------------------------------------------------------ thumb: the first screen as game.gd places the layers
def compose(bg, layers, cam_x=START_CAM) -> np.ndarray:
    canvas = np.zeros((SCREEN_H, SCREEN_W, 3), dtype=np.float64)
    canvas[:] = np.asarray(bg, dtype=np.float64)
    xs = np.arange(SCREEN_W)
    ys = np.arange(SCREEN_H)
    for L in sorted(layers, key=lambda layer: layer["z"]):
        tex = np.asarray(Image.open(res_path(L["file"])).convert("RGBA"))
        th, tw = tex.shape[:2]
        period = float(L["period"])
        s = float(L["scroll"])
        left = (-PAD - (cam_x * s) % period) if period > 0.0 else (-cam_x * s - PAD)
        cols = np.floor((xs - left) / ART).astype(int)
        if period > 0.0:
            cols = cols % tw
            col_ok = np.ones_like(cols, dtype=bool)
        else:
            col_ok = (cols >= 0) & (cols < tw)
        rws = np.floor((ys - float(L["y"])) / ART).astype(int)
        row_ok = (rws >= 0) & (rws < th)
        src = tex[np.clip(rws, 0, th - 1)[:, None], np.clip(cols, 0, tw - 1)[None, :]]
        a = (src[:, :, 3:4] / 255.0) * (row_ok[:, None] & col_ok[None, :])[:, :, None]
        canvas = canvas * (1.0 - a) + src[:, :, :3] * a
    return np.clip(np.round(canvas), 0, 255).astype(np.uint8)


def save_thumb(dest: Path, bg, layers) -> None:
    thumb = compose(bg, layers)[2::ART, 2::ART]
    assert thumb.shape == (216, 384, 3), thumb.shape
    Image.fromarray(thumb).save(dest / "thumb.png")


# ------------------------------------------------------------------ level entries
def layer(level_id, scroll, w, y, name, z) -> dict:
    return {"file": f"res://assets/levels/{level_id}/{name}", "scroll": scroll, "y": y, "z": z,
            "period": w * ART, "w": w * ART, "modulate": None}


def build_arena() -> dict:
    """Perry's Arena: Perry's keep layers, placed like tools/build_stage2.py (ground at y 100, sky padded up)"""
    level_id = "p_arena"
    dest = ROOT / "assets" / "levels" / level_id
    dest.mkdir(parents=True, exist_ok=True)
    ground_y = 100
    pad_rows = (ground_y - SKY_Y) // ART
    sky = Image.open(ARENAS / "keep_sky.png").convert("RGBA")
    out = Image.new("RGBA", (sky.width, sky.height + pad_rows))
    out.paste(sky.crop((0, 0, sky.width, pad_rows)).transpose(Image.FLIP_TOP_BOTTOM), (0, 0))
    out.paste(sky, (0, pad_rows))
    out.save(dest / "sky.png")
    for part in ("far", "near", "ground", "fringe"):
        Image.open(ARENAS / f"keep_{part}.png").convert("RGBA").save(dest / f"{part}.png")
    fringe = Image.open(dest / "fringe.png")
    first = int(np.where(np.asarray(fringe)[:, :, 3].max(axis=1) > 0)[0][0])
    fringe_y = ground_y
    if fringe_y + ART * first >= SCREEN_H:
        fringe_y = SCREEN_H - fringe.height * ART
    layers = [layer(level_id, 0.12, 384, SKY_Y, "sky.png", -40),
              layer(level_id, 0.3, 384, ground_y, "far.png", -30),
              layer(level_id, 0.55, 384, ground_y, "near.png", -20),
              layer(level_id, 1.0, 384, ground_y, "ground.png", -10),
              layer(level_id, 1.0, 384, fringe_y, "fringe.png", -9)]
    bg = [int(round(float(c))) for c in np.asarray(sky.convert("RGB"))[:8].reshape(-1, 3).mean(axis=0)]
    music = "res://assets/perry/music/boss6.ogg"
    assert res_path(music).is_file()
    save_thumb(dest, bg, layers)
    print("p_arena        map_w 7200 (boss arena, no surfaces)")
    return {"id": level_id, "name": "Perry's Arena", "sub": "Perry fights you alone", "map_w": 7200,
            "layers": layers, "bg": bg, "music": music}


def build_map(level_id, name, sub, theme, music, rows) -> dict:
    colw = THRONE_COLW if level_id == THRONE_ID else COLW
    info = analyse(rows, colw)
    map_w = info["nc"] * colw
    if level_id != THRONE_ID:
        assert map_w >= 9600, (level_id, map_w)
    surfaces = info["surfaces"]
    assert all(s[0] >= 1800 for s in surfaces), (level_id, surfaces[:2])
    ladders = make_ladders(surfaces)
    wpx = (map_w + 1024 + 1100) // ART + 1
    dest = ROOT / "assets" / "levels" / level_id
    dest.mkdir(parents=True, exist_ok=True)
    draw_ground(theme, rows, info, colw, wpx).save(dest / "ground.png")
    dungeon = theme in DUNGEON
    (draw_sky_dungeon(theme) if dungeon else draw_sky_field(theme)).save(dest / "sky.png")
    layers = [layer(level_id, 0.12 if dungeon else 0.15, 384, SKY_Y, "sky.png", -40),
              {"file": f"res://assets/levels/{level_id}/ground.png", "scroll": 1.0, "y": 0, "z": -10,
               "period": 0, "w": wpx * ART, "modulate": None}]
    bg = list(PAL[theme]["bg"])
    assert res_path(music).is_file(), music
    save_thumb(dest, bg, layers)
    entry = {"id": level_id, "name": name, "sub": sub}
    if level_id == THRONE_ID:
        entry["map_w"] = map_w
    entry.update({"layers": layers, "bg": bg, "music": music,
                  "surfaces": [s[:3] for s in surfaces], "ladders": ladders, "platforms": [],
                  "hazards": info["hazards"], "marks": info["marks"]})
    print(f"{level_id:14s} cols {info['nc']:3d} map_w {map_w:6d} surfaces {len(surfaces):2d} ladders {len(ladders):2d} "
          f"hazards {len(info['hazards']):2d} tiers {sorted(set(s[3] for s in surfaces))}")
    return entry


# ------------------------------------------------------------------ the four Craftpix maps (v0.21: tools/craft_kit.py, tools/craft_maps/<id>.json)
CRAFT_VARIANT = {"ch_greenwood": "meadow", "ch_bramble": "cave", "ch_watchtower": "sky_isles", "ch_marsh": "jungle"}


def build_craft_map(level_id, name, sub, music) -> dict:
    """Greenwood Road, Bramble Hollow, Old Watchtower and Rotting Marsh redesigned on the free Craftpix platformer tileset.
    One ASCII column is 160 px (one 32 px native tile). The pits and spike beds are real hazards at run time ("pits", "spikes" in
    levels.json: game.gd _hazard_tick); the old DCSS maps keep their art-only "hazards"."""
    import sys
    sys.path.insert(0, str(ROOT / "tools"))
    import craft_kit as K
    variant = CRAFT_VARIANT[level_id]
    data = json.loads((ROOT / "tools" / "craft_maps" / f"{level_id}.json").read_text())
    rows = data["rows"]
    colw = K.COLW
    info = analyse(rows, colw)
    map_w = info["nc"] * colw
    assert map_w >= 9600, (level_id, map_w)
    surfaces = info["surfaces"]
    assert all(s[0] >= 1800 for s in surfaces), (level_id, surfaces[:2])
    ladders = make_ladders(surfaces)
    wpx = (map_w + 1024 + 1100) // ART + 1
    dest = ROOT / "assets" / "levels" / level_id
    dest.mkdir(parents=True, exist_ok=True)
    K.draw_ground_craft(variant, rows, info, colw, wpx).save(dest / "ground.png")
    layers = K.make_layers(variant, dest, level_id)
    layers.append({"file": f"res://assets/levels/{level_id}/ground.png", "scroll": 1.0, "y": 0, "z": -10,
                   "period": 0, "w": wpx * ART, "modulate": None})
    bg = list(K.BG[variant])
    assert res_path(music).is_file(), music
    save_thumb(dest, bg, layers)
    pits = [[a * colw, b * colw] for a, b in runs(sorted(info["pit_cols"]))]
    spikes = [[a * colw, b * colw] for a, b in runs(sorted(info["spike_cols"]))]
    entry = {"id": level_id, "name": name, "sub": sub, "layers": layers, "bg": bg, "music": music,
             "surfaces": [s[:3] for s in surfaces], "ladders": ladders, "platforms": [],
             "hazards": info["hazards"], "pits": pits, "spikes": spikes, "marks": info["marks"]}
    print(f"{level_id:14s} {variant:9s} cols {info['nc']:3d} map_w {map_w:6d} surfaces {len(surfaces):2d} ladders {len(ladders):2d} "
          f"pits {len(pits):2d} spikes {len(spikes):2d} marks {len(info['marks'])}")
    return entry


def main_craft() -> None:
    """Rebuild only the four Craftpix maps (python3 tools/build_stage3.py --craft); every other level stays byte for byte."""
    raw = LEVELS_JSON.read_text()
    doc = json.loads(raw)
    assert json.dumps(doc, indent=1) == raw, "levels.json is not in the expected format"
    ids = [lv["id"] for lv in doc["levels"]]
    for level_id, name, sub, js, theme, music in MAPS:
        if level_id in CRAFT_VARIANT:
            doc["levels"][ids.index(level_id)] = build_craft_map(level_id, name, sub, music)
    for lv in doc["levels"]:
        for L in lv["layers"]:
            assert res_path(L["file"]).is_file(), L["file"]
    LEVELS_JSON.write_text(json.dumps(doc, indent=1))
    print(f"levels: {len(doc['levels'])}")


def main() -> None:
    import sys
    if "--craft" in sys.argv:
        main_craft()
        return
    raw = LEVELS_JSON.read_text()
    doc = json.loads(raw)
    assert json.dumps(doc, indent=1) == raw, "levels.json is not in the expected format"
    maps = parse_maps()
    entries = [build_arena()]
    for level_id, name, sub, js, theme, music in MAPS:
        if level_id in CRAFT_VARIANT:
            entries.append(build_craft_map(level_id, name, sub, music))
        else:
            entries.append(build_map(level_id, name, sub, theme, music, maps[js]))
    ids = [lv["id"] for lv in doc["levels"]]
    for e in entries:
        if e["id"] in ids:
            doc["levels"][ids.index(e["id"])] = e
        else:
            doc["levels"].append(e)
            ids.append(e["id"])
    for lv in doc["levels"]:
        for L in lv["layers"]:
            assert res_path(L["file"]).is_file(), L["file"]
        assert res_path(lv["music"]).is_file(), lv["music"]
    LEVELS_JSON.write_text(json.dumps(doc, indent=1))
    print(f"levels: {len(doc['levels'])}")


if __name__ == "__main__":
    main()
