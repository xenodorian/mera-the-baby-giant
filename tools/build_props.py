#!/usr/bin/env python3
"""v0.8 (S4) props, breakables and gore: crops copies of free CC0 packs into assets/props/ and assets/vfx/gore/,
and draws the few pieces no free pack had (urn, chest, lever, cracked-wall overlay) in this project.

Sources (originals kept unmodified in assets/_source/s4_free/, see docs/CREDITS.md):
  castle_tileset_part2/3.png   rubberduck, "pixel art castle tileset", OpenGameArt, CC0
  candles_with_eyes.png        vk, "candles, oil lamp and eye with varied stands", OpenGameArt, CC0
  Kings and Pigs.zip           Pixel Frog, itch.io, CC0   (box / crate + its hit frame and pieces)
  Red_Oil_Barrel_...zip        Jimmy D. Journey, itch.io, CC0 (barrel + 12-frame explosion)
  rc_art_-_gore_blood_gibs.zip Reactorcore, "Gore Blood Gibs Meat Chunks", OpenGameArt, CC0
Run: python3 tools/build_props.py   (idempotent)
"""
import io, os, zipfile, json
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets/_source/s4_free")
OUT = os.path.join(ROOT, "assets/props")
GORE = os.path.join(ROOT, "assets/vfx/gore")
os.makedirs(OUT, exist_ok=True)
os.makedirs(GORE, exist_ok=True)


def src(name):
    return Image.open(os.path.join(SRC, name)).convert("RGBA")


def zimg(zname, member_end):
    with zipfile.ZipFile(os.path.join(SRC, zname)) as z:
        for n in z.namelist():
            if n.endswith(member_end) and "__MACOSX" not in n:
                return Image.open(io.BytesIO(z.read(n))).convert("RGBA")
    raise SystemExit("missing %s in %s" % (member_end, zname))


def trim(im):
    bb = im.getbbox()
    return im.crop(bb) if bb else im


def save(im, *path):
    p = os.path.join(*path)
    im.save(p)
    print("wrote", os.path.relpath(p, ROOT), im.size)


# ---------------------------------------------------------------- rubberduck castle tileset (CC0)
p2 = src("castle_tileset_part2.png")
p3 = src("castle_tileset_part3.png")
GOLD = 320                                   # part 2: four metal blocks of 160 px (dark, silver, gold, copper)
save(trim(p2.crop((309, GOLD + 32, 309 + 86, GOLD + 32 + 88))), OUT, "chandelier.png")
save(trim(p2.crop((490, GOLD, 502, GOLD + 96))), OUT, "chain.png")
save(trim(p2.crop((231, GOLD + 13, 249, GOLD + 64))), OUT, "candelabra.png")
save(trim(p3.crop((39, 47, 89, 128))), OUT, "door.png")
save(trim(p3.crop((352, 129, 480, 160))), OUT, "plank.png")
# a 3 x 4 block wall of the grey stone tiles, then cracks drawn over it (the secret wall)
tile_a = p3.crop((352, 224, 384, 256))
tile_b = p3.crop((384, 256, 416, 288))
wall = Image.new("RGBA", (96, 128))
for r in range(4):
    for c in range(3):
        wall.alpha_composite(tile_a if (r + c) % 2 == 0 else tile_b, (c * 32, r * 32))
save(wall, OUT, "wall.png")
cr = wall.copy()
px = cr.load()
rng = np.random.default_rng(8)
for start in [(20, 6), (70, 40), (34, 80)]:
    x, y = start
    for i in range(46):
        if 0 <= x < 96 and 0 <= y < 128:
            px[x, y] = (24, 20, 28, 255)
            if x + 1 < 96:
                px[x + 1, y] = (70, 66, 74, 255)
        y += 1
        x += int(rng.integers(-1, 2))
save(cr, OUT, "wall_cracked.png")
save(trim(p3.crop((45, 5, 52, 13))), OUT, "flame.png")

# ---------------------------------------------------------------- vk candles (CC0): two variants, ground line cut off
cd = src("candles_with_eyes.png")
save(trim(cd.crop((3, 0, 17, 41))), OUT, "candle_a.png")
save(trim(cd.crop((94, 0, 106, 41))), OUT, "candle_b.png")

# ---------------------------------------------------------------- Pixel Frog Kings and Pigs (CC0): the box
def woodify(im):
    """the Pixel Frog box is pink/purple: rotate every pixel to a muted wood brown, value kept (v0.8 review)"""
    import colorsys
    im = im.convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, al = px[x, y]
            if not al:
                continue
            h, sat, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            sat = min(0.66, max(sat, 0.42) * 1.15)
            v = v * 0.8
            r2, g2, b2 = colorsys.hsv_to_rgb(0.075, sat, v)
            px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), al)
    return im


save(woodify(zimg("Kings and Pigs.zip", "08-Box/Idle.png")), OUT, "crate.png")
save(woodify(zimg("Kings and Pigs.zip", "08-Box/Hit.png")), OUT, "crate_hit.png")
for i in range(1, 5):
    save(woodify(zimg("Kings and Pigs.zip", "08-Box/Box Pieces %d.png" % i)), OUT, "crate_piece%d.png" % i)

# ---------------------------------------------------------------- Jimmy D. Journey barrel (CC0)
save(zimg("Red_Oil_Barrel_and_Exploding_Red_Oil_Barrel.zip", "Single_Sprite/Red Oil Barrel.png"), OUT, "barrel.png")
save(zimg("Red_Oil_Barrel_and_Exploding_Red_Oil_Barrel.zip", "Sprite_Sheets/Exploding Red Oil Barrel.png"), OUT, "barrel_boom.png")

# ---------------------------------------------------------------- Reactorcore gore (CC0)
chunks = zimg("rc_art_-_gore_blood_gibs.zip", "Sprites/Meat Gore Chunks All.png")
a = np.array(chunks)[:, :, 3] > 0
lab, n = ndimage.label(a, structure=np.ones((3, 3)))
rects = []
for s in ndimage.find_objects(lab):
    y0, y1, x0, x1 = s[0].start, s[0].stop, s[1].start, s[1].stop
    if (y1 - y0) * (x1 - x0) >= 12:
        rects.append((x0, y0, x1, y1))
rects.sort(key=lambda r: (r[1] // 10, r[0]))
for i, r in enumerate(rects):
    save(chunks.crop(r), GORE, "gib_%02d.png" % i)
save(zimg("rc_art_-_gore_blood_gibs.zip", "Sprites/Blood3_Blast_RefSheet.png"), GORE, "blood_blast.png")
save(zimg("rc_art_-_gore_blood_gibs.zip", "Sprites/Blood2_Burst_RefSheet.png"), GORE, "blood_burst.png")
save(zimg("rc_art_-_gore_blood_gibs.zip", "Sprites/glow_splat_medium_dark.png"), GORE, "glow_splat.png")
save(zimg("rc_art_-_gore_blood_gibs.zip", "Sprites/glow_mist_small.png"), GORE, "glow_mist.png")


# ---------------------------------------------------------------- drawn in this project
def draw(w, h, rows, pal):
    im = Image.new("RGBA", (w, h))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != "." and x < w:
                im.putpixel((x, y), pal[ch])
    return im


CLAY = {"o": (40, 22, 22, 255), "d": (118, 58, 40, 255), "m": (164, 86, 52, 255), "l": (206, 128, 76, 255),
        "h": (236, 176, 116, 255), "b": (70, 40, 34, 255)}
urn = [
    "....oooooooo....",
    "...oddmmmmddo...",
    "....oddddddo....",
    ".....ommmmo.....",
    "....omlllmmo....",
    "...omlhllmmdo...",
    "..omlhhllmmmdo..",
    ".omlhhllmmmmddo.",
    ".omlhllmmmmmddo.",
    "ombbbbbbbbbbbbbo",
    "omllhllmmmmmmddo",
    "omlhhllmmmmmmddo",
    "omlhllmmmmmmmddo",
    ".omllmmmmmmmddo.",
    ".omlmmmmmmmmddo.",
    "..ommmmmmmmddo..",
    "...odmmmmmddo...",
    "....oddddddo....",
    "...oddddddddo...",
    "...oooooooooo...",
]
save(draw(16, 20, urn, CLAY), OUT, "urn.png")
WOOD = {"o": (30, 18, 16, 255), "d": (86, 46, 30, 255), "m": (128, 72, 42, 255), "l": (168, 104, 60, 255),
        "i": (92, 96, 110, 255), "s": (168, 172, 186, 255), "g": (236, 196, 82, 255)}
chest = [
    "..oooooooooooooooooooo..",
    ".ollllllllllllllllllllo.",
    "omlmmmmmmmmmmmmmmmmmmlmo",
    "omsiimmmmmmmmmmmmmmiismo",
    "omsiimmmmmmmmmmmmmmiismo",
    "omsiimmmmmmmmmmmmmmiismo",
    "oooooooooooggggooooooooo",
    "osssssssssggoggssssssssso",
    "omsiimmmmmmggggmmmmiismo",
    "omsiillllllllllllllliismo",
    "omsiimmmmmmmmmmmmmmiismo",
    "omsiidddddddddddddddiismo",
    "omsiimmmmmmmmmmmmmmiismo",
    "omsiillllllllllllllliismo",
    "omsiimmmmmmmmmmmmmmiismo",
    "omsiidddddddddddddddiismo",
    "odddddddddddddddddddddddo",
    "oooooooooooooooooooooooo",
]
save(draw(24, 18, chest, WOOD), OUT, "chest.png")
chest_open = [
    "..oooooooooooooooooooo..",
    ".oddddddddddddddddddddo.",
    "odgggggggggggggggggggdo.",
    "odgllgggglggggglggglgdo.",
    "oooooooooooooooooooooooo",
] + chest[7:]
save(draw(24, 18, chest_open, WOOD), OUT, "chest_open.png")
LEV = {"o": (24, 20, 28, 255), "s": (160, 164, 176, 255), "i": (92, 96, 110, 255), "r": (210, 60, 50, 255),
       "w": (120, 76, 44, 255)}
lever_up = [
    "......orro......",
    "......orro......",
    ".......osio.....",
    "........osio....",
    ".........osio...",
    "..........osio..",
    "...........osio.",
    "...........osio.",
    "....oooooooooo..",
    "...osssssssssso.",
    "..oiiiiiiiiiiiio",
    "..owwwwwwwwwwwwo",
    "..oooooooooooooo",
]
save(draw(16, 13, lever_up, LEV), OUT, "lever_off.png")
lever_on = [
    ".orro...........",
    ".orro...........",
    "..oiso..........",
    "...oiso.........",
    "....oiso........",
    ".....oiso.......",
    "......oiso......",
    ".......oiso.....",
    "....oooooooooo..",
    "...osssssssssso.",
    "..oiiiiiiiiiiiio",
    "..owwwwwwwwwwwwo",
    "..oooooooooooooo",
]
save(draw(16, 13, lever_on, LEV), OUT, "lever_on.png")
