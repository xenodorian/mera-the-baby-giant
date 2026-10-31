"""Export Mera's beam-cast frames (1x atk + to idle, character layers only, slash fx dropped) for Godot.
Output: assets/characters/merakintsugi/derived/beam_cast/mera_beam_cast_strip17.png (+ .json)
The pivot (feet) is aligned to the idle frames in mera_export, and the wand tip of the held frame is stored
relative to that pivot so the Godot beam starts exactly at the wand.  Run from the repo root."""
import os, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ase_render import load, frame
from PIL import Image
import numpy as np
SRC = 'assets/characters/merakintsugi/platformer-character-pack'
OUT = 'assets/characters/merakintsugi/derived/beam_cast'
A = load(f'{SRC}/atk/1x atk/1x atk_c.aseprite'); I = load(f'{SRC}/idle/idle.aseprite')
CH = {'1x atk', 'to idle'}
HOLD = 5; TIP = (149, 39)          # held frame (0-based) and its wand-tip pixel in the 160x64 atk canvas
m = lambda im: np.array(im.getchannel('A')) > 0
a0, i0 = m(frame(A, 0, only=CH)), m(frame(I, 0))
best = (-1, 0, 0)
for dy in range(-12, 13):            # atk canvas coord + (dx,dy) = idle canvas coord
    for dx in range(-110, 10):
        ys, xs = np.nonzero(a0); ys2, xs2 = ys + dy, xs + dx
        ok = (ys2 >= 0) & (ys2 < i0.shape[0]) & (xs2 >= 0) & (xs2 < i0.shape[1])
        sc = i0[ys2[ok], xs2[ok]].sum() / (a0.sum() + i0.sum() - i0[ys2[ok], xs2[ok]].sum())
        if sc > best[0]: best = (sc, dx, dy)
iou, dx, dy = best
ib = frame(I, 0).getbbox(); ground = int(np.nonzero(i0)[0].max())
piv_idle = ((ib[0] + ib[2]) // 2, ground + 1)                # same rule as export_mera_frames.py
pivot = (piv_idle[0] - dx, piv_idle[1] - dy)                 # in atk canvas coords
os.makedirs(OUT, exist_ok=True)
n = len(A['frames']); W, H = A['W'], A['H']
strip = Image.new('RGBA', (W * n, H))
for i in range(n): strip.alpha_composite(frame(A, i, only=CH), (i * W, 0))
fn = f'mera_beam_cast_strip{n}.png'; strip.save(f'{OUT}/{fn}')
meta = dict(file=fn, cell=[W, H], frames=n, pivot=list(pivot), faces='left (wand points right in the held pose)',
            durations_ms=[f['dur'] for f in A['frames']], hold_frame=HOLD, wand_tip=list(TIP),
            beam_origin_rel_pivot=[TIP[0] + 1 - pivot[0], TIP[1] - pivot[1]], idle_alignment_iou=round(float(iou), 3),
            source=f'{SRC}/atk/1x atk/1x atk_c.aseprite layers 1x atk + to idle (1x atk_fx slash layer dropped)')
json.dump(meta, open(f'{OUT}/mera_beam_cast.json', 'w'), indent=1); print(meta)
