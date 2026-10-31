"""Bake every Mera animation the playable level uses (pack animations + the canon cast sequences) into Godot sheets.

Output: assets/characters/merakintsugi/game/<key>.png (packed atlas) + anims.json (one entry per animation).
Every frame stores up to three trimmed layers, all positioned relative to Mera's feet pivot in native art pixels
(art faces LEFT, x grows right, y grows down):
  c = body (character layers; the canon casts include their rim light)   -> normal blend
  f = effects (pack slash layers, charge orbs, rune rings, beam, light dots) -> normal blend, recoloured in Fury
  l = additive light (beam halo only)                                     -> additive blend, recoloured in Fury
Each layer entry is [atlas_x, atlas_y, w, h, offset_x, offset_y]. Per frame: ms, body box (hurtbox) and hit box
(the effect pixels of attack frames). Placement uses the same feet-anchor chain as tools/beam_cast_sequences.py
(ground pinned, x by silhouette IoU), so chained moves and the canon casts line up pixel for pixel.
The canon casts are re-rendered through tools/projectile_cast.py / beam_cast_sequences.py with SPLIT set, which
does not touch their GIFs. Pack .aseprite files are only read.  Run from the repo root."""
import os, sys, json, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image
import beam_cast_sequences as cs
import projectile_cast as pc
from ase_render import load, frame

ROOT = cs.ROOT; PK = cs.PK; OUT = f'{ROOT}/assets/characters/merakintsugi/game'
GROUND = cs.GROUND
_ib = cs.img('idle', 0).getbbox(); PX = (_ib[0] + _ib[2]) // 2; PY = GROUND + 1   # feet pivot in world (idle canvas) px

# key: (file, body layers, fx layers)
PACK = {
 'idle': ('idle/idle.aseprite', {'idle'}, set()),
 'walk': ('walk/walk.aseprite', {'walk'}, set()),
 'run_start': ('run/run_start.aseprite', {'sprint_start'}, set()),
 'run': ('run/run.aseprite', {'sprint'}, set()),
 'run_stop': ('run/run_stop.aseprite', {'sprint stop'}, set()),
 'run_turn': ('run/run_turn.aseprite', {'sprint_turn'}, set()),
 'crouch': ('crouching/crouching.aseprite', {'crouching', 'crouching idle', 'to idle'}, set()),
 'jump': ('jump/jump.aseprite', {'jump', 'landing'}, set()),
 'djump_v': ('jump/double jump_vertical.aseprite', {'double jump_vertical'}, set()),
 'djump_f': ('jump/double jump_forward.aseprite', {'Sprite Sheet'}, set()),
 'roll_land': ('jump/roll landing.aseprite', {'roll landing'}, set()),
 'adash': ('aerial dash/aerial dash.aseprite', {'aerial dash'}, {'01', '02', '03', '04', 'smoke'}),
 'bdodge': ('back dodge/back dodge.aseprite', {'back dodge'}, {'illusion_01', 'illusion_02', 'illusion_03'}),
 'atk1': ('atk/1x atk/1x atk_c.aseprite', {'1x atk', 'to idle'}, {'1x atk_fx'}),
 'atk2': ('atk/2x atk/2x atk.aseprite', {'2x atk', 'to idle(short delay)'}, {'fx01'}),
 'atk2_1': ('atk/2x-1 atk/2x-1 atk.aseprite', {'2x-1 atk'}, {'fx'}),
 'atk2_2': ('atk/2x-2 atk/2x-2 atk.aseprite', {'2x-2 atk'}, {'fx'}),
 'atk3': ('atk/3x atk/3x atk.aseprite', {'3x atk'}, {'3x atk_fx01', '3x atk_fx02', '3x atk_fx03'}),
 'datk1': ('dodge atk/dodge atk 1x/dodge atk 1x.aseprite', {'dodge atk 1x', 'to idle'}, {'fx01', 'fx02'}),
 'datk2': ('dodge atk/dodge atk 2x/dodge atk 2x.aseprite', {'dodge atk 2x'}, {'fx'}),
 'datk3': ('dodge atk/dodge atk 3x(vertical atk)/dodge atk 3x.aseprite', {'vertical atk', 'vertical atk fall loop'},
           {'smoke', 'fx_upper', 'fall fx_01', 'fall fx_03', 'fall fx_05'}),
 'jatk1': ('jump attack/jump atk 1x/jump attack 1x.aseprite', {'jump atk 1x'}, {'fx'}),
 'jatk2': ('jump attack/jump atk 2x/jump atk 2x.aseprite', {'jump atk 2x'}, {'fx'}),
 'heal': ('healing/healing.aseprite', {'healing'}, {'fx_01', 'fx_02'}),
 'hurt': ('hurt/hurt.aseprite', {'normal hit'}, set()),
 'hurt_hard': ('hurt/hurt.aseprite', {'hard hit'}, set()),
 'knockback': ('hurt/hurt.aseprite', {'hit'}, set()),
 'slide': ('slide/slide.aseprite', {'slide', 'to', 'from'}, {'fx01', 'fx02', 'fx03', 'spark'}),
 'ladder': ('ladder action/ladder action.aseprite', {'climb start', 'climb up', 'climb end', 'slide loop', 'slide end'}, set()),
 'ledge': ('ledge action/ledge action.aseprite', {'hang', 'up'}, set()),
 'wall_jump': ('wall jump/wall jump.aseprite', {'wall slide', 'wall jump'}, set()),
}
FRAMES = {'hurt': range(10, 22), 'hurt_hard': range(10, 34), 'knockback': range(0, 10)}
# placement: key -> (own frame pinned to the ground / matched, reference key, reference frame). None = cs chain.
PLACE = {
 'walk': (0, 'idle', 0), 'run_start': (0, 'idle', 0), 'run': (0, 'run_start', 1), 'run_stop': (0, 'run', 19),
 'run_turn': (0, 'run', 19), 'crouch': (0, 'idle', 0), 'jump': (0, 'idle', 0), 'djump_v': (0, 'jump', 10), 'djump_f': (0, 'jump', 10),
 'roll_land': (8, 'idle', 0), 'adash': (0, 'jump', 10), 'bdodge': (0, 'idle', 0), 'atk2_1': (0, 'atk2', 9), 'atk2_2': (0, 'atk2', 9),
 'datk2': (0, 'datk1', 15), 'datk3': (21, 'idle', 0), 'jatk1': (0, 'jump', 10), 'jatk2': (0, 'jatk1', 8), 'heal': (0, 'idle', 0),
 'hurt': (21, 'idle', 0), 'hurt_hard': (33, 'idle', 0), 'knockback': (9, 'idle', 0), 'slide': (0, 'idle', 0),
 'ladder': (0, 'idle', 0), 'ledge': (13, 'idle', 0), 'wall_jump': (0, 'jump', 10),
}
CSKEY = {'idle': 'idle', 'atk1': '1x', 'atk2': '2x', 'atk3': '3x', 'datk1': 'd1'}
LOOPS = {'idle', 'walk', 'run'}
D = {k: load(PK + v[0]) for k, v in PACK.items()}
_c = {}
def body(k, i):
    if (k, i, 'b') not in _c: _c[(k, i, 'b')] = frame(D[k], i, only=PACK[k][1], use_visibility=False)
    return _c[(k, i, 'b')]
def fxl(k, i):
    if not PACK[k][2]: return None
    if (k, i, 'f') not in _c: _c[(k, i, 'f')] = frame(D[k], i, only=PACK[k][2], use_visibility=False)
    return _c[(k, i, 'f')]
def frames_of(k): return list(FRAMES.get(k, range(len(D[k]['frames']))))

OFF = {k: cs.OFF[v] for k, v in CSKEY.items()}
def place(k):
    if k in OFF: return OFF[k]
    own, rk, rf = PLACE[k]; ro = place(rk)
    dy = GROUND - cs.bottom(body(k, own))
    iou, dx = cs.best_dx(cs.mask(body(rk, rf)), cs.mask(body(k, own)), dy - ro[1], range(-260, 200))
    OFF[k] = (ro[0] + dx, dy); print(f'{k:10s} offset {OFF[k]} matched {rk} f{rf} IoU {iou:.2f}'); return OFF[k]

def idle_after(k, last, off):
    """idle frame + world dx that continues the last frame (silhouette match, ground pinned)"""
    best = (-1, 0, 0); im = body(k, last) if k in PACK else last
    for ii in range(10):
        iou, dx = cs.best_dx(cs.mask(im), cs.mask(cs.img('idle', ii)), GROUND - cs.bottom(cs.img('idle', ii)) - off[1], range(-220, 220))
        if iou > best[0]: best = (iou, dx, ii)
    return off[0] + best[1], best[2], best[0]

# ---------------------------------------------------------------- packing
class Atlas:
    def __init__(s, maxw=2048): s.items = []; s.maxw = maxw
    def add(s, im, wx, wy, pad):
        """im = RGBA placed at world (wx, wy); returns a slot dict filled in by pack()"""
        b = im.getbbox()
        if not b: return None
        c = im.crop((b[0] - pad, b[1] - pad, b[2] + pad, b[3] + pad))
        slot = dict(im=c, ox=wx + b[0] - pad - PX, oy=wy + b[1] - pad - PY); s.items.append(slot); return slot
    def pack(s, path):
        x = y = rowh = 0; W = 1
        order = sorted(s.items, key=lambda d: -d['im'].height)
        for d in order:
            w, h = d['im'].size
            if x + w > s.maxw: x = 0; y += rowh; rowh = 0
            d['ax'], d['ay'] = x, y; x += w; rowh = max(rowh, h); W = max(W, x)
        H = y + rowh; sheet = Image.new('RGBA', (W, max(H, 1)), (0, 0, 0, 0))
        for d in order: sheet.paste(d['im'], (d['ax'], d['ay']))
        sheet.save(path); return sheet.size
def ent(sl): return None if sl is None else [sl['ax'], sl['ay'], sl['im'].width, sl['im'].height, sl['ox'], sl['oy']]
def rel_box(im, wx, wy, shrink=0):
    b = im.getbbox() if im is not None else None
    if not b: return None
    return [b[0] + wx - PX + shrink, b[1] + wy - PY + shrink, b[2] + wx - PX - shrink, b[3] + wy - PY]

ANIMS = {}
def finish(key, atlas, frames, **extra):
    size = atlas.pack(f'{OUT}/{key}.png')
    out = []
    for fr in frames:
        e = dict(ms=fr['ms'], c=ent(fr.get('c')), f=ent(fr.get('f')), l=ent(fr.get('l')), body=fr.get('body'), hit=fr.get('hit'))
        for kk in ('src', 'phase', 'beam'):
            if kk in fr: e[kk] = fr[kk]
        out.append(e)
    ANIMS[key] = dict(sheet=f'{key}.png', size=list(size), frames=out, **extra); print(key, len(out), 'frames', size)

def bake_pack(key):
    off = place(key); at = Atlas(); frs = []
    for i in frames_of(key):
        b = body(key, i); f = fxl(key, i)
        fr = dict(ms=D[key]['frames'][i]['dur'], c=at.add(b, off[0], off[1], 2), body=rel_box(b, off[0], off[1], 3), src=i)
        if f is not None and f.getbbox():
            fr['f'] = at.add(f, off[0], off[1], 1); fr['hit'] = rel_box(f, off[0], off[1])
        frs.append(fr)
    ix = idle_after(key, frames_of(key)[-1], off)
    finish(key, at, frs, loop=key in LOOPS, end_dx=ix[0], end_idle=ix[1], tags=D[key]['tags'], offset=list(off))

# ---------------------------------------------------------------- canon casts
def split_layers(r, mode):
    """body + fx (+ light) RGBA images on the cast canvas, so body under fx reproduces the GIF frame without background"""
    W, H = r['size']; x, y = r['pos']
    cb = Image.new('RGBA', (W, H), (0, 0, 0, 0)); cb.alpha_composite(r['spr'], (x, y))
    pf = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    if r['fxi'] is not None: pf.alpha_composite(r['fxi'], (x, y))
    fx = np.zeros((H, W, 4), np.uint8); light = None
    if mode == 'proj':
        bodyA = np.array(cb)[..., 3] > 0; pfa = np.array(pf)
        dots = r['dots'] & ~bodyA & (pfa[..., 3] == 0); fx[dots, :3] = pc.P['deep']; fx[dots, 3] = 255
        m = pfa[..., 3] > 0; fx[m] = pfa[m]
        for th, col in pc.BANDS:
            m = r['E'] >= th; fx[m, :3] = col; fx[m, 3] = 255
    else:
        pfa = np.array(pf); m = pfa[..., 3] > 0; fx[m] = pfa[m]
        al = r['al']; m = al > 0
        fx[m, :3] = (r['rgb'][m] * 255).astype(np.uint8); fx[m, 3] = np.maximum((al[m] * 255).astype(np.uint8), np.where(pfa[m, 3] > 0, 255, 0).astype(np.uint8))
        both = m & (pfa[..., 3] > 0) & (al < 1)   # translucent band over the pack slash: keep the blend the GIF shows
        if both.any():
            mix = pfa[both, :3] * (1 - al[both, None]) + r['rgb'][both] * 255 * al[both, None]; fx[both, :3] = mix.astype(np.uint8); fx[both, 3] = 255
        lt = r['light']; lm = lt.max(-1) > 0.004
        if lm.any():
            la = np.zeros((H, W, 4), np.uint8); la[lm, :3] = np.clip(lt[lm] * 255, 0, 255).astype(np.uint8); la[lm, 3] = 255; light = Image.fromarray(la)
    return cb, Image.fromarray(fx), light

def bake_cast(key, recs, mode, start, end, extra):
    X0, Y0 = recs[0]['origin']; at = Atlas(); frs = []
    for r in recs[start:end]:
        cb, fx, lt = split_layers(r, mode)
        fr = dict(ms=r['ms'], c=at.add(cb, X0, Y0, 2), body=rel_box(r['spr'], r['pos'][0] + X0, r['pos'][1] + Y0, 3),
                  src=f"{cs.NAMES[r['anim']]} f{r['frame']}", phase=r['phase'])
        if fx.getbbox(): fr['f'] = at.add(fx, X0, Y0, 1)
        if lt is not None and lt.getbbox(): fr['l'] = at.add(lt, X0, Y0, 0)
        hit = None
        if r['fxi'] is not None and r['fxi'].getbbox(): hit = rel_box(r['fxi'], r['pos'][0] + X0, r['pos'][1] + Y0)
        if mode == 'beam' and r['phase'] in ('fire', 'sustain'):   # the beam's hot core (energy >= 0.5)
            ys, xs = np.nonzero(r['E'] >= 0.5)
            if len(xs):
                bb = [int(xs.min()) + X0 - PX, int(ys.min()) + Y0 - PY, int(xs.max()) + 1 + X0 - PX, int(ys.max()) + 1 + Y0 - PY]
                hit = bb if hit is None else [min(hit[0], bb[0]), min(hit[1], bb[1]), max(hit[2], bb[2]), max(hit[3], bb[3])]
                fr['beam'] = bb
        fr['hit'] = hit; frs.append(fr)
    finish(key, at, frs, loop=False, **extra)

def proj_cast(key, name, skip_pre=2):
    pc.SPLIT = []; pc.build(name, pc.CFG[name]); recs = pc.SPLIT; pc.SPLIT = None
    meta = recs.pop()['meta']; fire = None
    for i, r in enumerate(recs):
        if r['phase'] == 'fire' and fire is None: fire = i - skip_pre
    sx, sy = meta['spawn']
    bake_cast(key, recs, 'proj', skip_pre, len(recs), dict(
        end_dx=meta['idle_dx'], end_idle=meta['idle_frame'], fire_frame=fire, spawn=[round(sx - PX, 2), round(sy - PY, 2)],
        shot=dict(speed_px_s=meta['speed'] * 1000, dist=meta['dist'], dir=meta['dir'], ang=meta['ang'], level=meta['level'], drop=meta['drop'],
                  ground_dy=meta['ground'] + 1 - PY - (sy - PY)), canon=f'previews/beam/cast_sequences/{name}_cast.gif'))

def beam_cast(key, name, from_anim='3x'):
    cs.SPLIT = []; cs.build(name, cs.PICKS[name]); recs = cs.SPLIT; cs.SPLIT = None
    rec = [r for r in recs if r['phase'] not in ('idle', 'idle_end')]
    for r in recs: r['ms'] = 40 if r['phase'] not in ('idle', 'idle_end') else 60
    start = next(i for i, r in enumerate(rec) if r['anim'] == from_anim) if from_anim else 0
    fire = next(i for i, r in enumerate(rec) if r['phase'] == 'fire') - start
    bake_cast(key, rec, 'beam', start, len(rec), dict(end_dx=recs[0]['idle_dx'], end_idle=recs[0]['idle_frame'], fire_frame=fire,
              canon=f'previews/beam/cast_sequences/{name}_cast.gif'))

# ---------------------------------------------------------------- spell sprites (shots, lightning, barrier)
P = pc.P
def band_img(E, bands=pc.BANDS):
    H, W = E.shape; a = np.zeros((H, W, 4), np.uint8)
    for th, col in bands:
        m = E >= th; a[m, :3] = col; a[m, 3] = 255
    return Image.fromarray(a)
def bolt_frames(n=8):
    """quick-fire bolt head + trail (same formula as projectile_cast, flying LEFT); head centre at (9, 4.5)"""
    out = []; W, H = 36, 10; YY, XX = np.mgrid[0:H, 0:W].astype(float); px, py = 9.0, 4.5
    for i in range(n):
        tm = i * 40; fk = math.sin(tm * 0.13) * math.sin(tm * 0.047 + 1); E = np.zeros((H, W))
        for j in range(1, 9):
            qx = px + j * 2.4; rx, ry = max(1.0, 3.6 - j * 0.3), max(0.7, 1.8 - j * 0.14)
            d = np.hypot((XX - qx) / rx, (YY - py) / ry); np.maximum(E, np.clip(1 - d, 0, 1) * (0.95 - j * 0.11), out=E)
        rx, ry = 5.2 + 0.6 * fk, 2.3 + 0.25 * fk
        d = np.hypot((XX - px) / rx, (YY - py) / ry); np.maximum(E, np.clip(1 - d, 0, 1) * (1.12 + 0.06 * fk), out=E)
        out.append(band_img(E))
    return out
def discs():
    """energy discs used for the fireball head and trail (radius r, peak e), as in projectile_cast.disc"""
    out = []
    for r, e in [(3.6, 1.15), (3.4, 1.0), (3.0, 0.9), (2.6, 0.8), (2.2, 0.7), (1.8, 0.6), (1.4, 0.5), (1.0, 0.4)]:
        S = 9; YY, XX = np.mgrid[0:S, 0:S].astype(float); E = np.clip(1 - np.hypot(XX - 4, YY - 4) / r, 0, 1) * e; out.append(band_img(E))
    return out
def lightning_frames(n=6, H=1100, W=56, seed=5):
    rng = np.random.default_rng(seed); out = []
    for i in range(n):
        E = np.zeros((H, W)); x = W / 2 + rng.uniform(-6, 6); pts = []
        for y in range(H - 1, -1, -1):
            if y % 6 == 0: x = float(np.clip(x + rng.uniform(-3.2, 3.2) - (x - W / 2) * 0.06, 8, W - 8))
            pts.append((x, y))
        def stroke(pts, w, e):
            for (xx, yy) in pts:
                x0 = int(round(xx))
                for dx in range(-w - 2, w + 3):
                    v = e * max(0.0, 1 - abs(dx) / (w + 2.5))
                    if 0 <= x0 + dx < W: E[yy, x0 + dx] = max(E[yy, x0 + dx], v)
        fade = 1.0 if i < n - 2 else (0.75 if i == n - 2 else 0.5)
        stroke(pts, 1, 1.2 * fade)
        for b in range(5):   # branches
            y0 = int(rng.uniform(120, H - 60)); xb = pts[H - 1 - y0][0]; dirb = rng.choice((-1, 1)); bp = []
            for k in range(int(rng.uniform(30, 90))):
                yy = y0 + k
                if yy >= H: break
                if k % 4 == 0: xb = float(np.clip(xb + dirb * rng.uniform(0.5, 2.5), 1, W - 2))
                bp.append((xb, yy))
            stroke(bp, 0, 0.75 * fade)
        out.append(band_img(E))
    return out
def barrier_frames(n=8, R=36):
    """spherical barrier: hot rim, dithered translucent body, a highlight that orbits the sphere"""
    S = 2 * R + 6; c = S / 2 - 0.5; YY, XX = np.mgrid[0:S, 0:S].astype(float); d = np.hypot(XX - c, YY - c) / R
    bay = np.tile(cs.mb.BAYER, (S // 4 + 1, S // 4 + 1))[:S, :S]; out = []
    for i in range(n):
        a = np.zeros((S, S, 4), np.uint8); ang = i * 2 * math.pi / n
        inside = d < 1
        a[inside & (bay < 0.04 + 0.30 * d ** 4)] = (*P["mid"], 120)
        a[inside & (d > 0.86)] = (*P['hot'], 230)
        a[(d >= 0.93) & (d < 1.0)] = (*P['core'], 255)
        hx, hy = c + R * 0.55 * math.cos(ang), c - R * 0.45 + R * 0.15 * math.sin(ang)
        a[np.hypot(XX - hx, YY - hy) < 3.2] = (*P['core'], 230)
        sp = np.hypot(XX - (c - R * 0.4 * math.cos(ang)), YY - (c + R * 0.5)) < 1.6; a[sp & inside] = (*P['hot'], 220)
        out.append(Image.fromarray(a))
    return out
GREEN = [(20, 52, 30), (34, 110, 52), (70, 180, 72), (150, 235, 120), (230, 255, 210)]
REDS = [(60, 8, 18), (120, 14, 24), (190, 28, 34), (240, 70, 60), (255, 190, 170)]
def potion_frames(n=6):
    """green healing potion (14x18): round flask, cork, liquid with a moving glint"""
    out = []
    for i in range(n):
        a = np.zeros((18, 14, 4), np.uint8); YY, XX = np.mgrid[0:18, 0:14].astype(float)
        d = np.hypot(XX - 6.5, (YY - 11.5) * 1.05)
        a[d < 6.2] = (*GREEN[0], 255); a[d < 5.2] = (*GREEN[1], 255)
        a[(d < 4.4) & (YY > 9 + 0.6 * np.sin(i * 1.05 + XX * 0.9))] = (*GREEN[2], 255)
        a[2:6, 5:9] = (*GREEN[0], 255); a[3:6, 6:8] = (180, 200, 200, 255)            # neck
        a[0:3, 5:9] = (98, 60, 40, 255); a[0, 5:9] = (140, 96, 60, 255)               # cork
        gx, gy = 4 + (i % 3 == 0), 9 + (i % 2); a[gy, gx] = (*GREEN[4], 255); a[gy + 1, gx] = (*GREEN[3], 255)
        out.append(Image.fromarray(a))
    return out
def sphere_frames(n=6):
    """red rage sphere (13x13), pulsing core"""
    out = []
    for i in range(n):
        S = 13; YY, XX = np.mgrid[0:S, 0:S].astype(float); d = np.hypot(XX - 6, YY - 6); a = np.zeros((S, S, 4), np.uint8)
        pul = 0.4 * math.sin(i * 2 * math.pi / n)
        for k, r in enumerate([6.2, 5.0 + pul * 0.5, 3.6 + pul, 2.2 + pul, 1.0]):
            a[d < r] = (*REDS[k], 255)
        a[3, 4] = (*REDS[4], 255)
        out.append(Image.fromarray(a))
    return out
def strip(frames, path):
    w, h = frames[0].size; s = Image.new('RGBA', (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames): s.paste(f, (i * w, 0))
    s.save(path); return [w, h, len(frames)]

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    only = sys.argv[1:]
    for k in PACK: bake_pack(k)
    proj_cast('quick_fire', 'pick3_v4_bolt')             # Y
    proj_cast('rear_blast', 'pick2_v4_projectile_slash') # X+Y
    beam_cast('beam_ender', 'pick1_combo_beam_slash')    # X X X Y (from 3x atk f0)
    proj_cast('quick_fire_v3', 'pick3_v3_bolt'); proj_cast('rear_blast_v3', 'pick2_v3_projectile')   # gallery
    beam_cast('beam_combo_v1', 'pick1_3x_atk_f24', from_anim=None)
    spells = dict(bolt=dict(sheet='spell_bolt.png', cell=strip(bolt_frames(), f'{OUT}/spell_bolt.png'), head=[9, 4], ms=40),
                  discs=dict(sheet='spell_discs.png', cell=strip(discs(), f'{OUT}/spell_discs.png'), centre=[4, 4]),
                  lightning=dict(sheet='spell_lightning.png', cell=strip(lightning_frames(), f'{OUT}/spell_lightning.png'), ms=50),
                  potion=dict(sheet='pickup_potion.png', cell=strip(potion_frames(), f'{OUT}/pickup_potion.png'), ms=110),
                  sphere=dict(sheet='pickup_sphere.png', cell=strip(sphere_frames(), f'{OUT}/pickup_sphere.png'), ms=90),
                  barrier=dict(sheet='spell_barrier.png', cell=strip(barrier_frames(), f'{OUT}/spell_barrier.png'), ms=80))
    json.dump(dict(pivot_world=[PX, PY], faces='left', palette=P, anims=ANIMS, spells=spells), open(f'{OUT}/anims.json', 'w'), separators=(',', ':'))
    print('wrote', len(ANIMS), 'animations')
