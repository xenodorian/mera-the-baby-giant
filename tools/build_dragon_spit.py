#!/usr/bin/env python3
"""v0.8.1 dragon "spit" frames: the ansimuz breath frames with the baked-in fire plume removed.

The volley in dragon.gd launches lobbed bolts, so the breath plume must not show. The plume uses exactly three
colours that appear nowhere else in any dragon frame (checked below), so they are made transparent.
Works on COPIES: writes assets/characters/ansimuz/grotto-escape-2-boss-dragon/spit-nofire/sprites/spit/.
The ansimuz originals are never touched. Re-run, then python3 tools/build_roster.py.
"""
import glob, os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACK = os.path.join(ROOT, "assets/characters/ansimuz/grotto-escape-2-boss-dragon")
SRC = os.path.join(PACK, "sprites/breath")
DST = os.path.join(PACK, "spit-nofire/sprites/spit")
FIRE = {(242, 74, 2), (255, 141, 7), (255, 214, 133)}


def main():
    for d in ("idle", "tail"):                      # the fire colours must not be body colours
        for f in glob.glob(os.path.join(PACK, "sprites", d, "*.png")):
            im = Image.open(f).convert("RGBA")
            assert not any(p[3] and p[:3] in FIRE for p in im.get_flattened_data()), f
    os.makedirs(DST, exist_ok=True)
    for f in sorted(glob.glob(os.path.join(SRC, "*.png"))):
        im = Image.open(f).convert("RGBA")
        px = im.load()
        n = 0
        for y in range(im.size[1]):
            for x in range(im.size[0]):
                if px[x, y][3] and px[x, y][:3] in FIRE:
                    px[x, y] = (0, 0, 0, 0)
                    n += 1
        im.save(os.path.join(DST, os.path.basename(f)))
        print(os.path.basename(f), "fire px removed:", n)


if __name__ == "__main__":
    main()
