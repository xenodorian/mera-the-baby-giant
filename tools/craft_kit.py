#!/usr/bin/env python3
"""Craftpix platformer art kit for the Stage 3 maps (see docs/CRAFT_KIT.md).

Renders the ground layer and the parallax layers of the four "craft" variants
(meadow, cave, sky_isles, jungle) from the free Craftpix pack in assets/_source/craftpix_platformer/.

  draw_ground_craft(variant, rows, info, colw, wpx) -> PIL RGBA, same contract as build_stage3.draw_ground
  make_layers(variant, dest_dir, level_id)          -> layer dicts for levels.json (saves sky.png and friends)

One ASCII column is one 32 px native tile (COLW = 160 world px at x5), so no tile is ever resampled.
python only (PIL, numpy). Never touches Godot. Running this file renders a self test into the scratchpad.
"""
import glob
import math
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PACK = ROOT / "assets" / "_source" / "craftpix_platformer" / "PNG"
BGDIR = PACK / "Background" / "1920x1080"          # the "÷2" subfolder holds the 960x540 versions used here

# numbers shared with tools/build_stage3.py (copied, so this file stands alone)
ART = 5
GROUND_Y = 1060
IMG_ROWS = 216
FLOOR_ROW = GROUND_Y // ART        # 212
IMG_X0 = 205                       # image pixel that is world x 0
TIER_PX = 130
MAX_TIER = 6
SCREEN_W, SCREEN_H = 1920, 1080
START_CAM = 760.0
PAD = 64

COLW = 160                         # world px of one craft column = one 32 px native tile
TS = 32                            # tile size (native px)
SURF = 5                           # tile row of the walking line in the grass tiles: tile top = surface y - SURF
VARIANTS = ("meadow", "cave", "sky_isles", "jungle")
BG = {"meadow": (139, 154, 200), "cave": (14, 15, 24), "sky_isles": (98, 150, 214), "jungle": (60, 92, 70)}

# ------------------------------------------------------------------ catalogs
# TILE: name -> (source png, row, col) of a 32 px tile. Tileset.png is 17 columns x 12 rows.
TILE = {
    # solid ground block: grass top row, walls, fill, base (a block grows down from grass_top_*)
    "grass_top_l": ("Tileset", 0, 6), "grass_top_m": ("Tileset", 0, 7), "grass_top_r": ("Tileset", 0, 8),
    "wall_l": ("Tileset", 8, 9), "wall_m": ("Tileset", 8, 10), "wall_r": ("Tileset", 8, 11),
    "base_l": ("Tileset", 9, 9), "base_m": ("Tileset", 9, 10), "base_r": ("Tileset", 9, 11),
    "fill": ("Tileset", 1, 7),
    # one tile wide column
    "pillar_top": ("Tileset", 0, 1), "pillar_body": ("Tileset", 2, 1), "pillar_base": ("Tileset", 4, 1),
    # floating platform strip (grass on top, rock rounded underneath)
    "plat_l": ("Tileset", 7, 8), "plat_m1": ("Tileset", 7, 9), "plat_m2": ("Tileset", 7, 10),
    "plat_m3": ("Tileset", 7, 11), "plat_r": ("Tileset", 7, 12), "plat_one": ("Tileset", 8, 7),
    # ceilings and cave pieces
    "ceil_jag": ("Tileset", 8, 1), "ceil_flat_l": ("Tileset", 10, 0), "ceil_flat_m": ("Tileset", 10, 1),
    "ceil_flat_r": ("Tileset", 10, 2), "ceil_cone_l": ("Tileset", 9, 0), "ceil_cone_r": ("Tileset", 9, 2),
    "cave_wall_a": ("cave_entrance", 1, 1), "cave_wall_b": ("cave_entrance", 1, 2),
    "cave_wall_c": ("cave_entrance", 2, 3), "cave_wall_d": ("cave_entrance", 0, 3),
    "cave_edge_l": ("cave_entrance", 1, 0), "cave_edge_r": ("cave_entrance", 1, 5),
}
# SPR: name -> (source png, (x0, y0, x1, y1)) free sprites cut out of the sheets (found by connected components)
SPR = {
    "tree_round": ("Objects", (728, 24, 800, 111)), "tree_spooky": ("Objects", (507, 19, 596, 145)),
    "tree_tall": ("Objects", (452, 167, 544, 305)), "sign": ("Objects", (672, 144, 704, 174)),
    "bush_a": ("Objects", (752, 145, 782, 175)), "bush_b": ("Objects", (801, 145, 831, 175)),
    "bush_big": ("Objects", (747, 261, 788, 302)), "shroom_house": ("Objects", (915, 140, 944, 174)),
    "shroom_pair": ("Objects", (896, 82, 932, 115)), "crystal_big": ("Objects", (1042, 134, 1071, 174)),
    "crystal_small": ("Objects", (1044, 210, 1067, 240)), "flower": ("Objects", (1159, 139, 1177, 172)),
    "plant_big": ("Objects", (1096, 19, 1160, 112)), "plant_mid": ("Objects", (1199, 14, 1253, 81)),
    "plant_small": ("Predator_plant", (25, 44, 79, 114)), "plant_alt": ("Predator_plant", (10, 196, 69, 274)),
    "stal_s": ("stalactites", (34, 1472, 63, 1495)), "stal_m": ("stalactites", (34, 1632, 63, 1670)),
    "stal_l": ("stalactites", (34, 1792, 63, 1843)), "stal_xl": ("stalactites", (34, 32, 63, 96)),
    "spike_a": ("Spikes", (128, 0, 160, 64)), "spike_b": ("Spikes", (160, 0, 192, 64)),   # base row is 50
    "cave_entrance": ("cave_entrance", (0, 0, 192, 128)), "chest": ("chest", (0, 0, 64, 64)),
    "key": ("key", (0, 0, 32, 32)), "entrance_mid": ("cave_entrance", (0, 32, 192, 64)),
}
SPIKE_BASE = 50
# BGIMG: the 960x540 backdrops (the "÷2" folder), tile horizontally
BGIMG = ("Sky", "Clouds", "Flora1", "Flora2", "Full_bg")


# ------------------------------------------------------------------ image helpers
_cache = {}


def _png(name: str) -> Image.Image:
    if name not in _cache:
        _cache[name] = Image.open(PACK / f"{name}.png").convert("RGBA")
    return _cache[name]


def _bg(name: str) -> Image.Image:
    key = "bg_" + name
    if key not in _cache:
        path = glob.glob(str(BGDIR / "÷2" / f"{name}_*"))[0]
        _cache[key] = Image.open(path).convert("RGBA")
    return _cache[key]


def put(canvas: Image.Image, tile: Image.Image, x: int, y: int) -> None:
    """alpha composite with clipping at every canvas edge"""
    w, h = tile.size
    x0, y0 = max(x, 0), max(y, 0)
    x1, y1 = min(x + w, canvas.width), min(y + h, canvas.height)
    if x1 <= x0 or y1 <= y0:
        return
    canvas.alpha_composite(tile.crop((x0 - x, y0 - y, x1 - x, y1 - y)), (x0, y0))


def _arr(im: Image.Image) -> np.ndarray:
    return np.asarray(im.convert("RGBA")).astype(np.float64)


def _img(a: np.ndarray) -> Image.Image:
    return Image.fromarray(np.clip(np.round(a), 0, 255).astype(np.uint8), "RGBA")


def recolor(im: Image.Image, variant: str) -> Image.Image:
    """grade a pack image for a variant: grass (yellow green) and rock (brown/blue) are mapped separately"""
    if variant == "meadow":
        return im
    a = _arr(im)
    r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    lum = 0.3 * r + 0.59 * g + 0.11 * b
    grass = (g - b > 25) & (g >= r * 0.9) & (g > 60)
    bluerock = (b > r + 12) & ~grass
    out = a.copy()
    if variant == "cave":              # cold teal moss on blue-grey stone
        out[:, :, 0] = np.where(grass, lum * 0.50, r * 0.80)
        out[:, :, 1] = np.where(grass, lum * 0.98, g * 0.92)
        out[:, :, 2] = np.where(grass, lum * 0.92, b * 1.12)
        out[:, :, :3] *= 0.86
    elif variant == "jungle":          # saturated green leaves, mossy mud rock
        out[:, :, 0] = np.where(grass, r * 0.42, np.where(bluerock, r * 0.78, r * 1.0))
        out[:, :, 1] = np.where(grass, g * 1.0, np.where(bluerock, g * 1.25, g * 1.06))
        out[:, :, 2] = np.where(grass, b * 0.9 + 8, np.where(bluerock, b * 0.72, b * 0.62))
        out[:, :, :3] *= 0.96
    elif variant == "sky_isles":       # pale lavender stone, mint grass
        out[:, :, 0] = np.where(grass, r * 0.55, 34 + r * 1.30)
        out[:, :, 1] = np.where(grass, g * 1.02 + 6, 32 + g * 1.30)
        out[:, :, 2] = np.where(grass, b * 0.9 + 46, 44 + b * 1.30)
    return _img(np.concatenate([out[:, :, :3], a[:, :, 3:]], axis=2))


class Skin:
    """tiles and sprites of one variant, recoloured once and cached"""

    def __init__(self, variant: str):
        assert variant in VARIANTS, variant
        self.variant = variant
        self._t = {}
        self._s = {}

    def tile(self, name: str, flip: bool = False, vflip: bool = False) -> Image.Image:
        key = (name, flip, vflip)
        if key not in self._t:
            src, r, c = TILE[name]
            im = _png(src).crop((c * TS, r * TS, c * TS + TS, r * TS + TS))
            if name.startswith("base_"):                 # the pack's base tiles carry leaf wings of the grass beside them
                a = np.asarray(im).copy()
                rr, gg, bb = (a[:, :, i].astype(int) for i in range(3))
                a[(gg - bb > 25) & (gg >= rr * 0.9) & (gg > 60), 3] = 0
                im = Image.fromarray(a, "RGBA")
            im = recolor(im, self.variant)
            if flip:
                im = im.transpose(Image.FLIP_LEFT_RIGHT)
            if vflip:
                im = im.transpose(Image.FLIP_TOP_BOTTOM)
            self._t[key] = im
        return self._t[key]

    def sprite(self, name: str, flip: bool = False) -> Image.Image:
        key = (name, flip)
        if key not in self._s:
            src, box = SPR[name]
            im = recolor(_png(src).crop(box), self.variant)
            self._s[key] = im.transpose(Image.FLIP_LEFT_RIGHT) if flip else im
        return self._s[key]


# ------------------------------------------------------------------ ground
def _tier_of(h: int) -> int:
    return min(max(math.ceil(h / 3), 1), MAX_TIER)


class _Ctx:
    def __init__(self, variant, rows, info, colw, wpx):
        assert colw == COLW, "craft levels use COLW = 160"
        self.v = variant
        self.rows = rows
        self.info = info
        self.nc = info["nc"]
        self.floor = info["floor"]
        self.nr = info["nr"]
        self.img = Image.new("RGBA", (wpx, IMG_ROWS), (0, 0, 0, 0))
        self.sk = Skin(variant)
        self.rng = np.random.RandomState(self.nc * 31 + VARIANTS.index(variant))
        self.segs = [[] for _ in range(self.nc)]       # per column: [yt, yb, floating]
        self.plateau = set()
        self.pits = info["pit_cols"]
        self.rows_per = TIER_PX / 3.0 / ART

    def cx(self, c: int) -> int:
        return IMG_X0 + c * TS

    def solid(self, c: int, y: int) -> bool:
        if c < 0 or c >= self.nc:
            return True                                  # the map border continues as it is
        return any(s[0] <= y < s[1] for s in self.segs[c])


def _plan(x: _Ctx) -> None:
    rows, floor = x.rows, x.floor
    for c in range(x.nc):
        cap = next((r for r in range(floor) if rows[r][c] in "=_"), None)
        plateau = cap is not None and cap < floor - 1 and all(rows[r][c] in "#=x" for r in range(cap + 1, floor))
        top = FLOOR_ROW
        if plateau:
            x.plateau.add(c)
            top = FLOOR_ROW - TIER_PX * _tier_of(floor - cap) // ART
        else:                                            # scenery walls
            r = floor - 1
            run_top = None
            floating = []
            while r >= 0:
                if rows[r][c] in "#x":
                    r1 = r
                    while r >= 0 and rows[r][c] in "#x":
                        r -= 1
                    y0 = FLOOR_ROW - int(round((floor - (r + 1)) * x.rows_per))
                    y1 = FLOOR_ROW - int(round((floor - r1 - 1) * x.rows_per))
                    if r1 == floor - 1:
                        run_top = y0
                    else:
                        floating.append([y0, y1, True])
                else:
                    r -= 1
            if run_top is not None:
                top = run_top
            x.segs[c].extend(floating)
        if c not in x.pits:
            x.segs[c].append([top, IMG_ROWS + 40, False])


def _draw_segment(x: _Ctx, c: int, yt: int, yb: int, floating: bool) -> None:
    sk, X = x.sk, x.cx(c)
    ty = yt if floating else yt - SURF                   # floating scenery blocks have no grass
    k = 0
    while ty < yb and ty < IMG_ROWS:
        yref = max(ty + 16, yt + 6)
        le = not x.solid(c - 1, yref)
        re = not x.solid(c + 1, yref)
        if k == 0 and floating:
            name = "base_l" if le else ("base_r" if re else "base_m")
        elif k == 0:
            if le and re:
                name = "pillar_top"
            else:
                name = "grass_top_l" if le else ("grass_top_r" if re else "grass_top_m")
        elif le and re:
            name = "pillar_body"
        else:
            name = "wall_l" if le else ("wall_r" if re else "wall_m")
        t = sk.tile(name, vflip=(k == 0 and floating))
        last = floating and ty + TS >= yb
        if last:                                         # clip, then the rounded bottom edge of a base tile
            keep = max(yb - ty - 6, 1)
            put(x.img, t.crop((0, 0, TS, min(keep, TS))), X, ty)
            b = sk.tile("base_l" if le else ("base_r" if re else "base_m"))
            put(x.img, b.crop((0, TS - 7, TS, TS)), X, yb - 7)
        else:
            put(x.img, t, X, ty)
        if name == "wall_m" and x.rng.rand() < 0.5:     # rock blobs break up the flat fill
            _detail(x, X, ty)
        ty += TS
        k += 1


def _detail(x: _Ctx, X: int, ty: int) -> None:
    d = _png("Details")
    r, c = [(1, 1), (1, 2), (1, 4), (2, 1), (3, 5), (4, 2), (4, 3), (4, 5), (6, 2), (6, 5)][x.rng.randint(0, 10)]
    t = d.crop((c * TS, r * TS, c * TS + TS, r * TS + TS))
    t = Image.eval(t, lambda v: v) if x.v == "meadow" else recolor(t, x.v)
    put(x.img, t, X, ty)


def _strip(x: _Ctx, c0: int, c1: int, y: int, under: bool) -> None:
    """a floating platform from column c0 to c1 (exclusive) whose walking line is y"""
    sk = x.sk
    n = c1 - c0
    for i in range(n):
        c = c0 + i
        if n == 1:
            name = "plat_one"
        elif i == 0:
            name = "plat_l"
        elif i == n - 1:
            name = "plat_r"
        else:
            name = ("plat_m1", "plat_m2", "plat_m3")[(c * 7 + c // 3) % 3]
        # a neighbour column that is solid at this height joins instead of capping
        if name == "plat_l" and x.solid(c - 1, y + 4):
            name = "plat_m2"
        if name == "plat_r" and x.solid(c + 1, y + 4):
            name = "plat_m2"
        put(x.img, sk.tile(name), x.cx(c), y - (6 if name == "plat_one" else 4))
        if under and x.v == "sky_isles" and x.rng.rand() < 0.45:     # hanging rock under floating isles
            s = sk.sprite(("stal_s", "stal_m", "stal_l")[x.rng.randint(0, 3)], bool(x.rng.randint(0, 2)))
            put(x.img, s, x.cx(c) + 1, y - 4 + 24)


def _decor_on(x: _Ctx, c: int, y: int, p: float) -> None:
    """small things standing on a grass top at column c, surface y"""
    if x.rng.rand() > p:
        return
    names = {"meadow": ("bush_a", "bush_b", "flower", "shroom_pair", "flower"),
             "cave": ("crystal_small", "crystal_big", "shroom_pair", "crystal_small"),
             "sky_isles": ("flower", "bush_a", "crystal_small", "flower", "crystal_big"),
             "jungle": ("bush_big", "bush_a", "bush_b", "flower", "shroom_house")}[x.v]
    s = x.sk.sprite(names[x.rng.randint(0, len(names))], bool(x.rng.randint(0, 2)))
    put(x.img, s, x.cx(c) + (TS - s.width) // 2 + x.rng.randint(-3, 4), y - s.height + 2)


def draw_ground_craft(variant: str, rows: list, info: dict, colw: int, wpx: int) -> Image.Image:
    """the ground layer: 216 native rows, world x of image pixel i is 5 * (i - IMG_X0)"""
    x = _Ctx(variant, rows, info, colw, wpx)
    sk = x.sk
    _plan(x)
    if variant == "cave":
        _ceiling(x)
        _entrance(x)
    # walls, plateaus and floor: tallest tops last would not matter, columns never overlap
    for c in range(x.nc):
        for yt, yb, fl in sorted(x.segs[c], key=lambda s: s[0]):
            _draw_segment(x, c, yt, yb, fl)
    # pits
    for c in range(x.nc):
        if c in x.pits:
            _pit(x, c)
    # ledges
    for s in info["surfaces"]:
        cols = [c for c in range(s[0] // colw, s[1] // colw) if c not in x.plateau]
        yv = s[2] // ART
        thin = all(rows[r][c] != "=" for r in range(x.floor) for c in range(s[0] // colw, s[1] // colw)
                   if _tier_of(x.floor - r) == s[3])
        i = 0
        while i < len(cols):
            j = i
            while j + 1 < len(cols) and cols[j + 1] == cols[j] + 1:
                j += 1
            _strip(x, cols[i], cols[j] + 1, yv, not thin)
            for c in range(cols[i], cols[j] + 1):
                _decor_on(x, c, yv, 0.14)
            i = j + 1
    # grass tops of plateaus and the floor get a little life
    for c in range(x.nc):
        if c in x.pits:
            continue
        top = x.segs[c][-1][0]
        if rows[x.floor][c] == "x":
            _crack(x, c, top)
        else:
            _decor_on(x, c, top, 0.10 if c not in x.plateau else 0.12)
    _props(x)
    if variant == "sky_isles":
        _mist(x)
    return x.img


def _crack(x: _Ctx, c: int, top: int) -> None:
    X = x.cx(c)
    px = x.img.load()
    for dx, dy in [(6, 5), (7, 6), (8, 7), (8, 8), (9, 9), (10, 10), (9, 11), (20, 5), (19, 6), (18, 8), (19, 9), (21, 10)]:
        if 0 <= X + dx < x.img.width and top + dy < IMG_ROWS:
            px[X + dx, top + dy] = (20, 14, 16, 255)


def _pit(x: _Ctx, c: int) -> None:
    X = x.cx(c)
    v = x.v
    if v == "sky_isles":
        return                                           # the cloud sea shows through
    img = x.img
    if v == "jungle":                                    # swamp water at the floor line
        top = (88, 146, 108, 255)
        body = Image.new("RGBA", (TS, IMG_ROWS - FLOOR_ROW), (28, 66, 56, 255))
        put(img, body, X, FLOOR_ROW)
        put(img, Image.new("RGBA", (TS, 1), top), X, FLOOR_ROW)
        put(img, Image.new("RGBA", (TS, 1), (52, 104, 84, 255)), X, FLOOR_ROW + 1)
        for dx in (3 + (c * 5) % 6, 15 + (c * 3) % 5, 25):
            put(img, Image.new("RGBA", (4, 1), (150, 200, 150, 255)), X + dx, FLOOR_ROW + 2)
        return
    col = (12, 9, 14, 255) if v == "meadow" else (6, 8, 14, 255)
    put(img, Image.new("RGBA", (TS, IMG_ROWS - FLOOR_ROW), col), X, FLOOR_ROW)
    put(img, Image.new("RGBA", (TS, 1), (30, 24, 28, 255) if v == "meadow" else (20, 28, 40, 255)), X, FLOOR_ROW)
    if v == "cave":                                      # spikes in the dark
        s = x.sk.sprite("spike_a")
        put(img, s, X, IMG_ROWS + 10 - SPIKE_BASE)


def _props(x: _Ctx) -> None:
    rows, img, v = x.rows, x.img, x.v
    tree = {"meadow": "tree_round", "cave": "crystal_big", "sky_isles": "tree_round", "jungle": "tree_tall"}[v]
    for c in range(x.nc):
        for r in range(x.nr):
            ch = rows[r][c]
            if ch not in "Ti" or r < x.floor - 4 or c in x.pits:
                continue
            base = x.segs[c][-1][0] + 2
            if ch == "T":
                s = x.sk.sprite(tree, bool(c % 2))
                put(img, s, x.cx(c) + (TS - s.width) // 2, base - s.height)
            else:
                s = x.sk.sprite("sign")
                put(img, s, x.cx(c) + (TS - s.width) // 2, base - s.height)
    # spike columns
    sc = x.info["spike_cols"]
    for c in sc:
        s = x.sk.sprite("spike_a" if (c % 2) else "spike_b")
        put(img, s, x.cx(c), x.segs[c][-1][0] + 2 - SPIKE_BASE)
    if v == "jungle":                                    # predator plants guard the spike runs
        i = 0
        while i < len(sc):
            j = i
            while j + 1 < len(sc) and sc[j + 1] == sc[j] + 1:
                j += 1
            a, b = sc[i], sc[j]
            left = a - 1
            if left >= 0 and left not in x.pits:
                s = x.sk.sprite("plant_small")
                put(img, s, x.cx(left) + TS - s.width + 8, x.segs[left][-1][0] + 2 - s.height)
            right = b + 1
            if right < x.nc and right not in x.pits:
                s = x.sk.sprite("plant_alt", True)
                put(img, s, x.cx(right) - 6, x.segs[right][-1][0] + 2 - s.height)
            i = j + 1


def _ceiling(x: _Ctx) -> None:
    """dark stone band along the top of the whole map with stalactites hanging from it"""
    sk, img = x.sk, x.img
    W = img.width
    fill = sk.tile("fill")
    for px in range(0, W, TS):
        put(img, fill, px, -TS + 10)
        put(img, sk.tile("ceil_jag", bool((px // TS * 7 + px // TS // 3) % 2)), px, -2)
    n = 0
    for px in range(0, W - 40, 38):
        if x.rng.rand() < 0.55:
            s = sk.sprite(("stal_s", "stal_m", "stal_l", "stal_m")[x.rng.randint(0, 4)], bool(x.rng.randint(0, 2)))
            put(img, s, px + x.rng.randint(0, 8), 16 + x.rng.randint(0, 4))
            n += 1


def _entrance(x: _Ctx) -> None:
    """the pack's cave mouth as a stone gate round the start tile: its two cobbled jambs, floor to ceiling"""
    sc = next((c for r in range(x.nr) for c in range(x.nc) if x.rows[r][c] == "S"), 2)
    X = x.cx(max(0, sc - 1)) - 16
    src = _png("cave_entrance")
    for col, dx in ((0, 0), (5, 160)):
        jamb = recolor(src.crop((col * TS, TS, col * TS + TS, 2 * TS)), "cave")
        jamb = _shift(jamb, mul=(0.85, 0.85, 0.9))
        ty = FLOOR_ROW - 6
        while ty > 8 - TS:
            ty -= TS
            put(x.img, jamb, X + dx, ty)


def _mist(x: _Ctx) -> None:
    """pixel cloud puffs hugging the floor line of the high cliff (below the walking line, behind Mera)"""
    rng = np.random.RandomState(5)
    h, w = 22, x.img.width
    puff = np.zeros((h, w, 4))
    px = 0
    while px < w:
        r = rng.randint(6, 11)
        cx, cy = px + r, h - 1 + rng.randint(0, 3)
        yy, xx = np.mgrid[0:h, 0:w]
        d = (xx - cx) ** 2 + (yy - cy) ** 2
        m = d <= r * r
        puff[m] = (246, 250, 255, 255)
        sh = m & (d > (r - 3) ** 2) & (yy > cy - r // 2)
        puff[sh] = (205, 224, 246, 255)
        px += int(r * 1.3) + rng.randint(0, 8)
    for c in x.pits:                                     # the gaps stay clear so they read as gaps
        x0 = x.cx(c)
        puff[:, max(x0, 0):x0 + TS, 3] = 0
    put(x.img, _img(puff), 0, IMG_ROWS - 3 - (h - 1 - 5))


# ------------------------------------------------------------------ parallax layers
def _shift(im: Image.Image, mul=None, add=None, mix=None, mix_a=0.0) -> Image.Image:
    a = _arr(im)
    if mul is not None:
        a[:, :, :3] *= np.array(mul)
    if add is not None:
        a[:, :, :3] += np.array(add)
    if mix is not None:
        a[:, :, :3] = a[:, :, :3] * (1 - mix_a) + np.array(mix) * mix_a
    return _img(a)


def _alpha(im: Image.Image, k: float) -> Image.Image:
    a = _arr(im)
    a[:, :, 3] *= k
    return _img(a)


def _gradient(w: int, h: int, top, bot) -> Image.Image:
    t = np.linspace(0, 1, h)[:, None, None]
    a = np.zeros((h, w, 4))
    a[:, :, :3] = np.array(top, float) * (1 - t) + np.array(bot, float) * t
    a[:, :, 3] = 255
    return _img(a)


def _crop_h(im: Image.Image, y0: int, y1: int) -> Image.Image:
    return im.crop((0, y0, im.width, y1))


def _layer(level_id: str, name: str, scroll: float, y: int, z: int, w_native: int) -> dict:
    return {"file": f"res://assets/levels/{level_id}/{name}.png", "scroll": scroll, "y": y, "z": z,
            "period": w_native * ART, "w": w_native * ART, "modulate": None}


def _save(im: Image.Image, dest: Path, name: str) -> None:
    """PNG, palette reduced when that keeps it small and unchanged in look"""
    p = dest / f"{name}.png"
    im.save(p, optimize=True)
    if p.stat().st_size > 250_000:
        im.quantize(256, method=Image.FASTOCTREE, dither=Image.NONE).save(p, optimize=True)


def _cave_wall(w: int, h: int) -> Image.Image:
    """the dark blotchy cave interior of cave_entrance.png (the seamless 4x3 tile patch), mirrored so the
    patch borders vanish"""
    patch = recolor(_png("cave_entrance").crop((TS, 0, 5 * TS, 3 * TS)), "cave")
    pw, ph = patch.size
    out = Image.new("RGBA", (w, h))
    for iy, ty in enumerate(range(0, h, ph)):
        for ix, tx in enumerate(range(0, w, pw)):
            t = patch
            if ix % 2:
                t = t.transpose(Image.FLIP_LEFT_RIGHT)
            if iy % 2:
                t = t.transpose(Image.FLIP_TOP_BOTTOM)
            out.paste(t, (tx, ty))
    return out


def _hang(w: int, h: int, seed: int, up: bool, n: int, tint, sizes) -> Image.Image:
    """stalactites hanging from the top (or stalagmites rising from the bottom) over a period of w native px"""
    sk = Skin("cave")
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    rng = np.random.RandomState(seed)
    xs = np.sort(rng.randint(0, w, n))
    for px in xs:
        s = sk.sprite(sizes[rng.randint(0, len(sizes))], bool(rng.randint(0, 2)))
        s = _shift(s, mul=tint)
        if up:
            s = s.transpose(Image.FLIP_TOP_BOTTOM)
            put(out, s, int(px), h - s.height)
            put(out, s, int(px) - w, h - s.height)
        else:
            put(out, s, int(px), 0)
            put(out, s, int(px) - w, 0)
        # wrap: a sprite crossing the right edge reappears at the left edge
        if px + s.width > w:
            put(out, s, int(px) - w, h - s.height if up else 0)
    return out


def make_layers(variant: str, dest_dir, level_id: str) -> list:
    """save the parallax PNGs into dest_dir and return their levels.json dicts (lowest first).
    sky.png is always written; ground.png is the caller's. Textures are native pixels (the game draws every layer
    at x5), so the 960 px wide backdrops have period and w 4800 (they tile horizontally)."""
    assert variant in VARIANTS, variant
    dest = Path(dest_dir)
    dest.mkdir(parents=True, exist_ok=True)
    W = 960
    SKY_H = 224                                         # y -40 .. 1080 like build_stage3
    layers = []

    def add(im, name, scroll, y, z):
        _save(im, dest, name)
        layers.append(_layer(level_id, name, scroll, y, z, im.width))

    def window(im, top_row, screen_row):
        """world y that puts image row top_row on native screen row screen_row (rows above it are off screen)"""
        return (screen_row - top_row) * ART

    sky, clouds, f1, f2 = _bg("Sky"), _bg("Clouds"), _bg("Flora1"), _bg("Flora2")
    if variant == "meadow":
        base = _crop_h(sky, 0, SKY_H)
        ramp = _gradient(W, SKY_H, (96, 148, 226), (196, 214, 240))
        base = Image.blend(base.convert("RGB"), ramp.convert("RGB"), 0.55).convert("RGBA")
        add(base, "sky", 0.06, -40, -40)
        add(_shift(clouds, mul=(1.1, 1.1, 1.1)), "clouds", 0.16, window(clouds, 14, 0), -36)
        far = _crop_h(f1, 130, 540)
        add(far, "flora_far", 0.32, 0, -30)
        near = _crop_h(f2, 200, 540)
        add(near, "flora_near", 0.55, window(near, 40, 60 // 1 - 0 + 0), -24)
    elif variant == "jungle":
        base = _crop_h(sky, 0, SKY_H)
        ramp = _gradient(W, SKY_H, (22, 54, 44), (96, 140, 96))
        base = Image.blend(base.convert("RGB"), ramp.convert("RGB"), 0.85).convert("RGBA")
        add(base, "sky", 0.06, -40, -40)
        mist = _alpha(_shift(clouds, mul=(0.6, 0.9, 0.65)), 0.35)
        add(mist, "mist", 0.14, window(mist, 40, 0), -36)
        far = _crop_h(f1, 130, 540)
        far = _shift(far, mul=(0.4, 0.68, 0.46))
        add(far, "flora_far", 0.30, 0, -30)
        near = _crop_h(f2, 200, 540)
        near = _shift(near, mul=(0.26, 0.5, 0.3))
        add(near, "flora_near", 0.58, window(near, 40, 60), -24)
    elif variant == "sky_isles":
        base = _gradient(W, SKY_H, (58, 116, 214), (186, 222, 248))
        wisps = _crop_h(sky, 0, SKY_H)
        base = Image.blend(base.convert("RGB"), _shift(wisps, mul=(1.0, 1.05, 1.2)).convert("RGB"), 0.18).convert("RGBA")
        add(base, "sky", 0.05, -40, -40)
        hi = _shift(clouds, mul=(1.18, 1.18, 1.14))
        add(hi, "clouds", 0.14, window(hi, 6, 0), -36)
        far = _shift(_crop_h(f1, 150, 275), mul=(0.8, 1.0, 1.25), mix=(176, 212, 240), mix_a=0.6)
        fa = _arr(far)
        fa[:, :, 3] *= np.clip((np.arange(far.height)[::-1] / 40.0), 0, 1)[:, None]   # the distant treetops fade into cloud
        add(_img(fa), "far_isles", 0.26, 90 * ART, -30)
        sea = _shift(clouds.transpose(Image.FLIP_LEFT_RIGHT), mul=(1.2, 1.2, 1.15))
        sa = _arr(sea)
        sea = _img(sa)
        add(sea, "cloud_sea", 0.5, window(sea, 150, 112), -24)
    else:                                               # cave
        wall = _cave_wall(W, SKY_H)
        wall = _shift(wall, mul=(0.62, 0.74, 0.98))
        shade = np.linspace(0.75, 1.15, SKY_H)[:, None, None]
        wa = _arr(wall)
        wa[:, :, :3] *= shade
        add(_img(wa), "sky", 0.08, -40, -40)
        fog = _alpha(_shift(clouds, mul=(0.35, 0.62, 0.8)), 0.30)
        add(fog, "fog", 0.16, window(fog, 120, 0), -36)
        st = _hang(W, 100, 3, False, 16, (0.34, 0.42, 0.62), ("stal_m", "stal_l", "stal_xl"))
        add(st, "stalactites_far", 0.28, -20, -32)
        sg = _hang(W, 72, 4, True, 20, (0.5, 0.6, 0.85), ("stal_s", "stal_m", "stal_l"))
        add(sg, "stalagmites", 0.5, SCREEN_H - sg.height * ART, -24)
    return layers


# ------------------------------------------------------------------ self test
TEST_MAP = [
    "........................................",
    "........................................",
    "........................................",
    "........................................",
    "...........................=======......",
    "..................=====..................",
    "...............................T.....c..",
    ".....................==....########......",
    "...........====............#######.....c",
    "...........________..i.....#######..p..F",
    "..S....k..g..j.^^^.....T...######..m....",
    "========.....=====..=====#######======..",
    "########..####x####.###########=#######.",
    "########^^#########^###########.########",
]


def _test_rows() -> list:
    rows = [r.ljust(40, ".")[:40] for r in TEST_MAP]
    # a plateau with a cap, a ledge ladder, two pits
    rows = ["".join(row) for row in rows]
    return rows


def _compose(layer_dicts: list, dest: Path, ground: Image.Image, cam_x: float, mera: bool = True) -> Image.Image:
    canvas = np.zeros((SCREEN_H, SCREEN_W, 3), dtype=np.float64)
    canvas[:] = np.array(BG[_compose.variant], float)
    xs = np.arange(SCREEN_W)
    ys = np.arange(SCREEN_H)
    allay = list(layer_dicts) + [{"file": "ground", "scroll": 1.0, "y": 0, "z": -10, "period": 0}]
    for L in sorted(allay, key=lambda d: d["z"]):
        if L["file"] == "ground":
            tex = np.asarray(ground)
        else:
            tex = np.asarray(Image.open(dest / Path(L["file"]).name).convert("RGBA"))
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
    out = Image.fromarray(np.clip(np.round(canvas), 0, 255).astype(np.uint8))
    if mera:                                            # stand-ins: Mera is about 60..300 world px tall
        from PIL import ImageDraw
        d = ImageDraw.Draw(out)
        d.rectangle([930, GROUND_Y - 300, 990, GROUND_Y], outline=(255, 255, 255), width=3)
        d.rectangle([930, GROUND_Y - 150, 990, GROUND_Y], fill=(240, 120, 170))
        d.rectangle([1100, GROUND_Y - 60, 1130, GROUND_Y], fill=(240, 120, 170))
    return out


def _analyse(rows: list) -> dict:
    """build_stage3.analyse when it can be imported, else a copy of the same rules"""
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import build_stage3 as b
    return b.analyse(rows, COLW)


def selftest(out_dir: str = "/tmp/claude-0/-home-user/30a3820d-cdd0-52ad-96e4-ef061324fb98/scratchpad/craft") -> None:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    rows = _test_rows()
    info = _analyse(rows)
    wpx = (info["nc"] * COLW + 1024 + 1100) // ART + 1
    for v in VARIANTS:
        d = out / v
        lay = make_layers(v, d, f"test_{v}")
        g = draw_ground_craft(v, rows, info, COLW, wpx)
        assert g.size == (wpx, IMG_ROWS), g.size
        g.save(d / "ground.png")
        _compose.variant = v
        size = sum(p.stat().st_size for p in d.glob("*.png") if p.name != "ground.png")
        for name, cam in (("start", START_CAM), ("mid", 3600.0)):
            p = out / f"preview_{v}_{name}.png"
            _compose(lay, d, g, cam).save(p)
            print(p)
        print(f"{v}: layers {[L['file'].rsplit('/', 1)[1] for L in lay]} png bytes (no ground) {size}")


if __name__ == "__main__":
    selftest()
