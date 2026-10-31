"""Fit the L2 barrier bubble around the barrier pose (heal f5-8, the frames held while L2 is down).

Uses every opaque pixel of every layer (body, effects, additive light) of those frames, so the raised hand and the
energy ball are inside. Writes spells.barrier.fit = [cx, cy, r] in art px relative to the feet pivot (art faces left).
Run standalone to patch anims.json in place; export_game_anims.py calls fit() too."""
import json, math, sys
import numpy as np
from PIL import Image

MARGIN = 3.0            # art px between the farthest pixel and the bubble's inner rim
HOLD = range(5, 9)      # heal frames held by the barrier (mera.gd: anim.section(5, 8))


def fit(anims, out_dir, key='heal', frames=HOLD, margin=MARGIN):
    a = anims[key]; sheet = np.array(Image.open(f"{out_dir}/{a['sheet']}").convert('RGBA'))
    pts = []
    for i in frames:
        f = a['frames'][i]
        for lk in ('c', 'f', 'l'):
            e = f.get(lk)
            if not e:
                continue
            ax, ay, w, h, ox, oy = e
            ys, xs = np.nonzero(sheet[ay:ay + h, ax:ax + w, 3] > 8)
            pts.append(np.stack([xs + ox + 0.5, ys + oy + 0.5], 1))
    p = np.concatenate(pts)
    lo, hi = p.min(0), p.max(0); c = (lo + hi) / 2
    for _ in range(200):                     # nudge the centre toward the farthest pixel (approx. min enclosing circle)
        d = np.hypot(*(p - c).T); j = d.argmax(); c = c + (p[j] - c) * 0.02
    r = float(np.hypot(*(p - c).T).max()) + 0.71 + margin   # +0.71: pixel corner, not centre
    return [round(float(c[0]), 2), round(float(c[1]), 2), round(r, 2)], [float(lo[0]), float(lo[1]), float(hi[0]), float(hi[1])]


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'assets/characters/merakintsugi/game'
    d = json.load(open(f'{out}/anims.json'))
    d['spells']['barrier']['fit'], d['spells']['barrier']['pose_bounds'] = fit(d['anims'], out)
    d['spells']['barrier']['rim_r'] = 36       # radius of the rim in spell_barrier.png
    json.dump(d, open(f'{out}/anims.json', 'w'), separators=(',', ':'))
    print('barrier fit', d['spells']['barrier']['fit'], 'pose bounds', d['spells']['barrier']['pose_bounds'])
