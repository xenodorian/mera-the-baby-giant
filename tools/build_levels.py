"""Builds the four large native level maps (v0.5) from copies of the ansimuz environment packs.

Nothing loops as a single strip any more. Each level is a set of parallax layers:
  * tile layers: an image that tiles seamlessly by design (sky, clouds, mist) or, if its edges don't match, a
    mirrored pair (A + flipped A), which is seamless by construction (no blurred cross-fade);
  * unique layers: a long strip composed once from individual sprites (trees, graves, houses, rocks...) placed by a
    seeded RNG with random spacing and flips, plus the level's ground tiles. The playable layer is one unique strip
    covering the whole map, so the level is large natively.
Outputs assets/levels/<id>/*.png, thumb.png and assets/levels/levels.json (read by scripts/game/levels.gd).
The ansimuz sources are only read. Native art is 384 x 216 per screen, drawn x5 (1920 x 1080); feet line native y 212.
"""
import json, math, os, random
import numpy as np
from PIL import Image

ENV = 'assets/environments/ansimuz'
OUT = 'assets/levels'
ART = 5
SW, SH = 384, 216
PAD = 64                       # game px past each screen edge (screen shake headroom)
MAP_W = 19200                  # playable width in game px (10 screens); camera / Mera range 0..MAP_W


def img(p):
    return Image.open(f'{ENV}/{p}').convert('RGBA')


def seam(a):
    x = np.array(a).astype(int)
    return np.abs(x[:, 0] - x[:, -1]).mean()


def mirrored(a):
    out = Image.new('RGBA', (a.width * 2, a.height))
    out.alpha_composite(a, (0, 0))
    out.alpha_composite(a.transpose(Image.FLIP_LEFT_RIGHT), (a.width, 0))
    return out


def tileable(a, limit=4.0):
    return a if seam(a) <= limit else mirrored(a)


def pieces(a, min_w=6):
    """split a sprite strip into pieces separated by fully transparent columns"""
    al = np.array(a)[..., 3].any(0)
    out, x = [], 0
    while x < a.width:
        if not al[x]:
            x += 1
            continue
        x1 = x
        while x1 < a.width and al[x1]:
            x1 += 1
        if x1 - x >= min_w:
            p = a.crop((x, 0, x1, a.height))
            bb = p.getbbox()
            out.append(p.crop((0, bb[1], p.width, bb[3])))
        x = x1
    return out


def best_tile(a, box, min_w=24):
    """horizontally repeatable crop: the width (>= min_w) inside box whose left/right columns match best"""
    c = a.crop(box)
    arr = np.array(c).astype(int)
    best = None
    for w in range(min_w, c.width + 1):
        d = np.abs(arr[:, 0] - arr[:, w - 1]).mean() + np.abs(arr[:, 1] - arr[:, w - 1]).mean() * 0.5
        if best is None or d < best[0]:
            best = (d, w)
    return c.crop((0, 0, best[1], c.height))


def strip_width(scroll):
    """native width of a unique layer that covers every camera position 0..MAP_W at this scroll factor"""
    return math.ceil((scroll * MAP_W + 1920 + 2 * PAD) / ART) + 2


def scatter(width, height, items, rng, gap, start=0):
    """items: list of (sprite, weight, bottom_y). Places them left to right with random gaps and flips."""
    s = Image.new('RGBA', (width, height))
    x = start - rng.randint(0, 60)
    ws = [w for _, w, _ in items]
    while x < width:
        sp, _, by = rng.choices(items, weights=ws)[0]
        if rng.random() < 0.5:
            sp = sp.transpose(Image.FLIP_LEFT_RIGHT)
        s.alpha_composite(sp, (x, by - sp.height)) if x >= 0 else s.alpha_composite(sp.crop((-x, 0, sp.width, sp.height)), (0, by - sp.height))
        x += max(4, int(sp.width * rng.uniform(0.55, 1.05))) + rng.randint(gap[0], gap[1])
    return s


def row(width, height, tile, y):
    s = Image.new('RGBA', (width, height))
    for x in range(0, width, tile.width):
        s.alpha_composite(tile, (x, y))
    return s


def cobble(width, top, height, pal, rng):
    """procedural cobblestone street in the night-town palette (made in this project)"""
    a = np.zeros((height, width, 4), np.uint8)
    dark, mid, light, line = pal
    a[top:, :] = (*dark, 255)
    y = top + 1
    rowi = 0
    while y < height:
        h = 4 if rowi == 0 else 5
        x = -rng.randint(0, 7)
        while x < width:
            w = rng.randint(6, 10)
            x0, x1 = max(x + 1, 0), min(x + w, width)
            if x1 > x0:
                col = mid if rng.random() < 0.7 else light
                a[y:y + h - 1, x0:x1] = (*col, 255)
                a[y, x0:x1] = (*light, 255)
            x += w
        a[y + h - 1:y + h, :] = (*line, 255)
        y += h
        rowi += 1
    a[top, :] = (*light, 255)
    return Image.fromarray(a)


def save(level, name, im, layers, scroll, y, z, period=0, modulate=None):
    p = f'{OUT}/{level}/{name}.png'
    im.save(p)
    layers.append({'file': f'res://{p}', 'scroll': scroll, 'y': y * ART, 'z': z, 'period': period * ART,
                   'w': im.width * ART, 'modulate': modulate})


def thumb(level, layers, start=760):
    """first screen as the player sees it at the start (native 384 x 216)"""
    t = Image.new('RGBA', (SW, SH), (0, 0, 0, 255))
    for L in layers:
        im = Image.open(L['file'][6:]).convert('RGBA')
        cam = start
        if L['period'] > 0:
            off = (cam * L['scroll']) % L['period']
            x = -int(round(off / ART))
            while x < SW:
                t.alpha_composite(im, (x, L['y'] // ART)) if x >= 0 else t.alpha_composite(im.crop((-x, 0, im.width, im.height)), (0, L['y'] // ART))
                x += im.width
        else:
            lx = int(round((cam * L['scroll'] + PAD) / ART))
            t.alpha_composite(im.crop((lx, 0, lx + SW, im.height)), (0, L['y'] // ART))
    t.convert('RGB').save(f'{OUT}/{level}/thumb.png')


def build():
    levels = []
    # ---------------------------------------------------------------- 1 cemetery (as before, now one long map)
    lid, rng, L = 'cemetery', random.Random(101), []
    os.makedirs(f'{OUT}/{lid}', exist_ok=True)
    C = 'gothicvania-cemetery'
    save(lid, 'sky', img(f'{C}/background.png'), L, 0.0, -8, -40, 384)
    mt = img(f'{C}/mountains.png')
    w = strip_width(0.3)
    save(lid, 'mountains', scatter(w, 230, [(mt, 1, 218)], rng, (-50, -10)), L, 0.3, 0, -35)
    save(lid, 'graves_far', tileable(img(f'{C}/graveyard.png')), L, 0.7, 105, -30, 768)
    w = strip_width(1.0)
    near = row(w, 236, img(f'{C}/tileset.png').crop((64, 48, 128, 96)), 196)
    props = [(img(f'{C}/sliced-objects/{n}.png'), wt, 212) for n, wt in
             [('stone-1', 3), ('stone-2', 3), ('stone-3', 3), ('stone-4', 3), ('statue', 1.5), ('bush-large', 1.2),
              ('bush-small', 2), ('tree-1', 0.8), ('tree-2', 0.8), ('tree-3', 0.5)]]
    deco = scatter(w, 236, props, rng, (10, 70))
    deco.alpha_composite(near)
    save(lid, 'ground', deco, L, 1.0, 0, -10)
    thumb(lid, L)
    levels.append({'id': lid, 'name': 'Moonlit Cemetery', 'sub': 'Fire Knight and his Blue Knights', 'layers': L,
                   'bg': [0, 0, 34]})
    # ---------------------------------------------------------------- 2 mist forest
    lid, rng, L = 'mist_forest', random.Random(202), []
    os.makedirs(f'{OUT}/{lid}', exist_ok=True)
    M = 'mist-forest-background/layers/mist-forest-background'
    save(lid, 'mist', tileable(img(f'{M}-back.png')), L, 0.05, -8, -40, 512)
    save(lid, 'back_trees', tileable(img(f'{M}-back-trees.png')), L, 0.25, -8, -35, 160)
    tree = img(f'{M}-tree.png')
    save(lid, 'trees', scatter(strip_width(0.55), 230, [(tree, 1, 222)], rng, (40, 260)), L, 0.55, -8, -30)
    rocks = img(f'{M}-rocks.png')
    bb = rocks.getbbox()
    rocks = rocks.crop(bb)
    save(lid, 'rocks', scatter(strip_width(0.8), 236, [(rocks, 1, 226)], rng, (60, 380)), L, 0.8, 0, -25)
    tiles = img(f'{M}-tiles.png')
    slab = tiles.crop((22, 0, 170, 80))
    bb = slab.getbbox()
    slab = slab.crop(bb)
    gtile = best_tile(slab, (4, 0, slab.width - 4, slab.height), 40)
    w = strip_width(1.0)
    gr = Image.new('RGBA', (w, 236))
    for x in range(0, w, gtile.width):
        gr.alpha_composite(gtile, (x, 204))
        gr.alpha_composite(gtile.crop((0, gtile.height - 8, gtile.width, gtile.height)), (x, 204 + gtile.height))
    pillar = tiles.crop((170, 0, 288, 80))
    pillar = pillar.crop(pillar.getbbox())
    deco = scatter(w, 236, [(pillar, 1, 208)], rng, (500, 1400))
    deco.alpha_composite(gr)
    save(lid, 'ground', deco, L, 1.0, 0, -10)
    thumb(lid, L)
    levels.append({'id': lid, 'name': 'Misty Woods', 'sub': 'Beasts of the fog', 'layers': L, 'bg': [150, 190, 190]})
    # ---------------------------------------------------------------- 3 night town
    lid, rng, L = 'night_town', random.Random(303), []
    os.makedirs(f'{OUT}/{lid}', exist_ok=True)
    N = 'night-town-background/layers/night-town-background'
    save(lid, 'sky', tileable(img(f'{N}-sky.png')), L, 0.0, -8, -40, 96)
    cl = tileable(img(f'{N}-clouds.png'))
    save(lid, 'clouds', cl, L, 0.06, -8, -38, cl.width)
    mo = tileable(img(f'{N}-mountains.png'))
    save(lid, 'mountains', mo, L, 0.15, -8, -36, mo.width)
    fb = tileable(img(f'{N}-far-buildings.png'))
    save(lid, 'far_buildings', fb, L, 0.3, 216 - 80 - 34, -34, fb.width)
    fo = tileable(img(f'{N}-forest.png'))
    save(lid, 'forest', fo, L, 0.5, 216 - 96 - 10, -32, fo.width)
    town = pieces(img(f'{N}-town.png'))
    big = [p for p in town if p.height > 40]
    small = [p for p in town if p.height <= 40]
    w = strip_width(1.0)
    items = [(p, 2.0, 206) for p in big] + [(p, 1.0, 206) for p in small]
    deco = scatter(w, 236, items, rng, (6, 90))
    street = cobble(w, 204, 236, ((14, 18, 24), (34, 40, 46), (52, 60, 66), (8, 10, 14)), rng)
    deco.alpha_composite(street)
    save(lid, 'street', deco, L, 1.0, 0, -10)
    thumb(lid, L)
    levels.append({'id': lid, 'name': 'Moonlit Town', 'sub': 'Ghosts and the walking dead', 'layers': L, 'bg': [10, 22, 26]})
    # ---------------------------------------------------------------- 4 lava caverns
    lid, rng, L = 'lava_caverns', random.Random(404), []
    os.makedirs(f'{OUT}/{lid}', exist_ok=True)
    bg = tileable(img('lava-background/PNG/background.png'))
    save(lid, 'cavern', bg, L, 0.2, 216 - 240, -40, bg.width)
    mr = img('lava-background/PNG/middle-rocks.png')
    mr = mr.crop(mr.getbbox())
    save(lid, 'pillars', scatter(strip_width(0.6), 240, [(mr, 1, 240)], rng, (120, 420)), L, 0.6, 216 - 240, -30)
    lt = img('lava-background/PNG/lava-tile.png')
    w = strip_width(1.0)
    save(lid, 'lava_floor', row(w, 270, lt, 200), L, 1.0, 0, -10)
    thumb(lid, L)
    levels.append({'id': lid, 'name': 'Infernal Caverns', 'sub': 'Demons, hounds and the dragon', 'layers': L, 'bg': [40, 16, 30]})
    json.dump({'map_w': MAP_W, 'pad': PAD, 'art': ART, 'levels': levels}, open(f'{OUT}/levels.json', 'w'), indent=1)
    for lv in levels:
        print(lv['id'], [(os.path.basename(l['file']), Image.open(l['file'][6:]).size) for l in lv['layers']])


build()
