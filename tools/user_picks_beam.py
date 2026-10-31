"""Wand beam from the three frames the user picked (matched by pixel correlation against all 547 frames).
Outputs to previews/beam/user_picks/: raw native frame PNG (character layer only, untouched), a 6x NN copy,
and a looping 4x GIF of the teal beam (tools/mera_wand_beam.py pipeline) firing from the exact wand tip
along the wand direction. Native facing is kept; for a left-pointing wand the scene is built mirrored and
flipped back, so the art itself is never altered.  Run from the repo root: python3 tools/user_picks_beam.py"""
import os, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image, ImageDraw
import mera_wand_beam as mb
from ase_render import load, frame

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
PK = f'{ROOT}/assets/characters/merakintsugi/platformer-character-pack/'
OUT = f'{ROOT}/previews/beam/user_picks'
PICKS = [  # name, file, layer, frame(0-based), hold frames, wand tip (native canvas px), direction (+1 right / -1 left)
    ('pick1_3x_atk_f24', 'atk/3x atk/3x atk.aseprite', '3x atk', 24, [24], (192, 72), +1),
    ('pick2_3x_atk_f4', 'atk/3x atk/3x atk.aseprite', '3x atk', 4, [4], (160, 36), +1),
    ('pick3_dodge_atk_1x_f14', 'dodge atk/dodge atk 1x/dodge atk 1x.aseprite', 'dodge atk 1x', 14, [14, 14, 14, 15, 15, 15], (94, 22), -1),
]
BG = (18, 16, 30, 255); S = 4; PRE, POST = 6, 8
NB = mb.CHARGE + mb.FIRE + mb.SUSTAIN + mb.FADE

def run(name, f, layer, fi, hold, tip, d):
    A = load(PK + f)
    raw = frame(A, fi, only={layer})
    raw.save(f'{OUT}/{name}_raw.png')                                  # native size, transparent, unmodified
    big = Image.new('RGBA', raw.size, (0, 0, 0, 0)); big = raw.resize((raw.width * 6, raw.height * 6), Image.NEAREST)
    v = Image.new('RGBA', big.size, BG); v.alpha_composite(big); v.convert('RGB').save(f'{OUT}/{name}_6x.png')
    sprites = {i: frame(A, i, only={layer}) for i in set(hold)}
    # union bbox of held frames
    bb = [sprites[i].getbbox() for i in sprites]; bx0 = min(b[0] for b in bb); by0 = min(b[1] for b in bb); bx1 = max(b[2] for b in bb); by1 = max(b[3] for b in bb)
    # work in "beam goes right" space: mirror when the wand points left
    Wc = A['W']
    if d < 0:
        sprites = {i: s.transpose(Image.FLIP_LEFT_RIGHT) for i, s in sprites.items()}
        tipm = (Wc - 1 - tip[0], tip[1]); bx0, bx1 = Wc - bx1, Wc - bx0
    else:
        tipm = tip
    PADL, PADT, RANGE = 10, 14, 150
    W = (tipm[0] - bx0) + PADL + RANGE + 14; H = (by1 - by0) + 2 * PADT
    MX, MY = PADL - bx0, PADT - by0                                         # sprite canvas placement
    ox, oy = MX + tipm[0] + 1, MY + tipm[1]                                  # first pixel past the wand tip
    floor = MY + by1 + 1
    beam = mb.Beam(W, H, seed=11)
    seq = [None] * PRE + list(range(NB)) + [None] * POST
    frames = []; by = np.tile(mb.BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W]
    for t, h in enumerate(seq):
        ph = mb.phase(h + 0 if h is None else h) if h is not None else None
        # mb.phase expects hold index counting from charge start
        E, L, glow, xend = beam.step(ph, ox, oy, ox + RANGE, floor, t)
        bg = np.zeros((H, W, 3)) + np.array(BG[:3]) / 255
        lit = np.floor(np.clip(L, 0, 1.2) * 4 + by) / 4
        bg = np.clip(bg + lit[..., None] * mb.TINT * 1.6, 0, 1)
        if ph and ph[0] == 'fire' and ph[1] == 0: bg = bg * 0.6 + 0.4 * np.array([0.16, 0.5, 0.42])
        img = Image.fromarray((bg * 255).astype(np.uint8)).convert('RGBA')
        si = hold[t % len(hold)]
        img.alpha_composite(mb.rim(sprites[si], glow if h is not None else 0), (MX, MY))
        rgb, a = mb.bands(E)
        base = np.array(img).astype(float) / 255
        out = base[..., :3] * (1 - a[..., None]) + rgb * a[..., None]
        o = Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), 'RGB')
        if d < 0: o = o.transpose(Image.FLIP_LEFT_RIGHT)
        frames.append(o)
    allc = np.unique(np.concatenate([np.array(f).reshape(-1, 3) for f in frames]), axis=0)
    pal = Image.new('P', (1, 1)); pl = allc.flatten().tolist()
    if len(allc) <= 256: pal.putpalette(pl + [0] * (768 - len(pl)))
    else:
        strip = Image.new('RGB', (W, H * len(frames)))
        for i, f in enumerate(frames): strip.paste(f, (0, i * H))
        pal = strip.quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    q = [f.resize((W * S, H * S), Image.NEAREST).quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
    gif = f'{OUT}/{name}_beam.gif'
    q[0].save(gif, save_all=True, append_images=q[1:], duration=40, loop=0, disposal=1, optimize=False)
    # origin in output (native) coords for the report / checks
    oxn = ox if d > 0 else W - 1 - ox
    info = dict(name=name, file=f, layer=layer, frame=fi, frame_1based=fi + 1, held_frames=sorted(set(hold)), wand_tip=list(tip),
                beam_direction='right' if d > 0 else 'left', gif=os.path.basename(gif), gif_size=[W * S, H * S], frames=len(frames),
                colours=int(len(allc)), beam_origin_in_gif_1x=[int(oxn), int(oy)], bytes=os.path.getsize(gif))
    print(info); return info, frames

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    meta = []
    for p in PICKS:
        info, fr = run(*p); meta.append(info)
        # key-frame strip for checking: charge, fire, sustain, fade
        ks = [PRE + 3, PRE + mb.CHARGE + 1, PRE + mb.CHARGE + mb.FIRE + 6, PRE + NB - 3]
        W, H = fr[0].size; st = Image.new('RGB', (W * 2, H * 2 * len(ks)))
        for k, i in enumerate(ks): st.paste(fr[i].resize((W * 2, H * 2), Image.NEAREST), (0, k * H * 2))
        st.save(f'{OUT}/{p[0]}_beam_keyframes.png')
    json.dump(meta, open(f'{OUT}/user_picks.json', 'w'), indent=1)
