"""v0.8: natural-skin recolour of ansimuz's Dancing Girl (CC0), on COPIES.
Method = the Brawler Girl one: ansimuz ships Brawler Girl as original/ and skin-recolor/; diffing those two sets
gives an exact 3-colour palette swap of the skin ramp (nothing else changes). The Dancing Girl uses the very same
skin ramp colours, so the same mapping is applied, exact-RGB only, alpha kept. Her yellow/olive dress, grey sleeves,
red hair and brown shoes are different colours and are untouched (the script asserts that).
In:  assets/characters/ansimuz/dancing-girl/sprites/<anim>/*.png   (originals, never written)
Out: assets/characters/ansimuz/dancing-girl/skin-recolor/sprites/<anim>/*.png
usage: python3 tools/recolor_dancer_skin.py"""
import glob, os
from collections import Counter, defaultdict
from PIL import Image

A = 'assets/characters/ansimuz/'
SRC = A + 'dancing-girl/sprites/'
DST = A + 'dancing-girl/skin-recolor/sprites/'


def brawler_map():
    m = defaultdict(Counter)
    for o in sorted(glob.glob(A + 'brawler-girl/original/sprites/*/*.png')):
        r = o.replace('/original/', '/skin-recolor/')
        if not os.path.exists(r):
            continue
        a, b = Image.open(o).convert('RGBA'), Image.open(r).convert('RGBA')
        if a.size != b.size:
            continue
        for p, q in zip(a.get_flattened_data(), b.get_flattened_data()):
            if p[3]:
                m[p[:3]][q[:3]] += 1
    out = {}
    for k, v in m.items():
        t = v.most_common(1)[0][0]
        if t != k:
            out[k] = t
    return out


def main():
    mp = brawler_map()
    print('brawler skin map:', mp)
    assert len(mp) == 3, mp
    changed, kept = Counter(), Counter()
    for f in sorted(glob.glob(SRC + '*/*.png')):
        im = Image.open(f).convert('RGBA')
        px = im.load()
        for y in range(im.height):
            for x in range(im.width):
                p = px[x, y]
                if p[3] and p[:3] in mp:
                    px[x, y] = mp[p[:3]] + (p[3],)
                    changed[p[:3]] += 1
                elif p[3]:
                    kept[p[:3]] += 1
        out = DST + os.path.relpath(f, SRC)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        im.save(out)
    print('changed:', dict(changed))
    assert (192, 177, 10) in kept and (91, 103, 49) in kept, 'dress colours must stay'
    print('kept (top):', kept.most_common(8))


if __name__ == '__main__':
    main()
