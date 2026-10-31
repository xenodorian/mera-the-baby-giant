"""Full beam cast sequences for the three user-picked poses (previews/beam/cast_sequences/).
idle -> the pack's own lead-in frames (charge orb tracks the wand tip each frame, brightening) -> fire on the pose
frame -> hold the pose for fire/sustain/fade while recoil slides her rigidly away from the beam (kick, ease-out push,
small sustain shake, settle) with the beam origin glued to the tip -> the animation's own follow-through/recovery ->
idle. Particles from the beam's dissolve are released into world space and hover/fade while she recovers.
Animations are placed in one world by the feet anchor (ground pinned, x by silhouette overlap), the same chain as
tools/mk_full.py: idle -> 1x atk -> 2x atk (from 1x f9) -> 3x atk (from 2x f9); dodge atk 1x from idle.
Beam: tools/mera_wand_beam.py energy-field pipeline, drawn in a beam-local frame and resampled (nearest) along the
wand direction, so it can fire left, right or angled.  Run from the repo root."""
import os, sys, json, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image, ImageDraw
import mera_wand_beam as mb
from ase_render import load, frame

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
PK = f'{ROOT}/assets/characters/merakintsugi/platformer-character-pack/'
OUT = f'{ROOT}/previews/beam/cast_sequences'
AN = {'idle': ('idle/idle.aseprite', {'idle'}), '1x': ('atk/1x atk/1x atk_c.aseprite', {'1x atk', 'to idle'}),
      '2x': ('atk/2x atk/2x atk.aseprite', {'2x atk', 'to idle(short delay)'}), '3x': ('atk/3x atk/3x atk.aseprite', {'3x atk'}),
      'd1': ('dodge atk/dodge atk 1x/dodge atk 1x.aseprite', {'dodge atk 1x', 'to idle'}),
      'cr': ('crouching/crouching.aseprite', {'crouching'})}
NAMES = {'idle': 'idle', '1x': '1x atk', '2x': '2x atk', '3x': '3x atk', 'd1': 'dodge atk 1x', 'cr': 'crouching'}
D = {k: load(PK + f) for k, (f, _) in AN.items()}
_cache = {}
def img(k, i):
    if (k, i) not in _cache: _cache[(k, i)] = frame(D[k], i, only=AN[k][1])
    return _cache[(k, i)]
def mask(im): return np.array(im.getchannel('A')) > 0
def bottom(im): return int(np.nonzero(mask(im))[0].max())
def best_dx(mr, mn, dy, rng=range(-160, 160)):
    ys, xs = np.nonzero(mn); ys2 = ys + dy; best = (-1, 0)
    for dx in rng:
        xs2 = xs + dx; ok = (ys2 >= 0) & (ys2 < mr.shape[0]) & (xs2 >= 0) & (xs2 < mr.shape[1])
        inter = mr[ys2[ok], xs2[ok]].sum(); iou = inter / (mr.sum() + mn.sum() - inter)
        if iou > best[0]: best = (iou, dx)
    return best
GROUND = bottom(img('idle', 0)); OFF = {'idle': (0, 0)}
for k, ref, rf in [('1x', 'idle', 0), ('2x', '1x', 9), ('3x', '2x', 9), ('d1', 'idle', 0), ('cr', 'idle', 0)]:
    dy = GROUND - bottom(img(k, 0)); iou, dx = best_dx(mask(img(ref, rf)), mask(img(k, 0)), dy - OFF[ref][1])
    OFF[k] = (OFF[ref][0] + dx, dy)

# pick1 v2 places 3x atk without the combo: f23 matched to crouching f0 by silhouette (ground y kept from the chain)
_iou, _dx = best_dx(mask(img('cr', 0)), mask(img('3x', 23)), OFF['3x'][1] - OFF['cr'][1], range(-250, 100))
OFF_3X_FROM_CROUCH = (OFF['cr'][0] + _dx, OFF['3x'][1])

# pick2 v2 (user [pt32u]) lead-in 2x atk f0 -> 3x atk f0 -> 3x atk f2 without the combo: 2x f0 matched to idle f0, 3x f0 to 2x f0
_i2, _d2 = best_dx(mask(img('idle', 0)), mask(img('2x', 0)), GROUND - bottom(img('2x', 0)), range(-250, 100))
OFF_2X_FROM_IDLE = (_d2, GROUND - bottom(img('2x', 0)))
_i3, _d3 = best_dx(mask(img('2x', 0)), mask(img('3x', 0)), OFF['3x'][1] - OFF_2X_FROM_IDLE[1], range(-250, 100))
OFF_3X_FROM_2X0 = (OFF_2X_FROM_IDLE[0] + _d3, OFF['3x'][1])

# wand tip per frame (native canvas px of that animation), picked by eye on zoomed grids and snapped to the
# wand's own pixels. None = wand hidden behind her body (orb position interpolated between neighbours).
TIPS = {
 '1x': {0: (150, 31), 1: (154, 32), 2: (159, 37), 3: (158, 37), 4: (149, 39), 5: (149, 39), 6: (149, 40), 7: (149, 40), 8: (148, 40), 9: (148, 40)},
 '2x': {0: (155, 36), 1: (154, 32), 2: (81, 39), 3: (79, 39), 4: (55, 31), 5: (62, 29), 6: (68, 28), 7: (85, 27), 8: None, 9: None},
 '3x': {0: None, 1: None, 2: (160, 39), 3: (159, 39), 4: (160, 36), 5: (150, 35), 6: (148, 32), 7: (128, 33), 8: (165, 71), 9: (165, 71),
        10: (163, 73), 11: (163, 73), 12: (163, 72), 13: (163, 73), 14: (162, 74), 15: (162, 74), 16: (162, 74), 17: (162, 74),
        18: (162, 74), 19: (162, 74), 20: (163, 80), 21: (163, 80), 22: (157, 87), 23: (151, 86), 24: (162, 72)},
 'idle': {0: (57, 34)}, 'cr': {0: (49, 36)},
 'd1': {0: (130, 19), 1: (130, 21), 2: (145, 37), 3: (144, 38), 4: (144, 39), 5: (148, 42), 6: (155, 45), 7: (147, 47), 8: (72, 36),
        9: (74, 34), 10: (80, 25), 11: (80, 25), 12: (88, 23), 13: (95, 22), 14: (94, 22), 15: (94, 22)},
}
# the pack's own effect (slash) layers per animation, excluded from the body-only renders
FX_LAYERS = {'1x': {'1x atk_fx'}, '2x': {'fx01'}, '3x': {'3x atk_fx01', '3x atk_fx02', '3x atk_fx03'}}
PICKS = {
 # user [pt51u]: the combo into beam (pick1 v1) with each animation's own slash/fx layers on every frame that has them
 'pick1_combo_beam_slash': dict(lead=[('1x', i) for i in range(10)] + [('2x', i) for i in range(10)] + [('3x', i) for i in range(24)],
                                pose='3x', hold=[24], ang=180.0, rec=[('3x', i) for i in range(25, 34)], fx=FX_LAYERS, exact=True),
 # user [pt30u]: charge on idle 1 (index 0), crouching 1 (index 0) and 3x atk f23, then continue the 3x atk animation
 'pick1_v2_3x_atk_f24': dict(lead=[('idle', 0)] * 10 + [('cr', 0)] * 10 + [('3x', 23)] * 10, pre=0,
                             pose='3x', hold=[24], ang=180.0, rec=[('3x', i) for i in range(25, 34)], off={'3x': OFF_3X_FROM_CROUCH}, c0=0.3, cexp=1.0),
 # user [pt32u]: lead into pick2's blast with 2x atk f0 -> 3x atk f0 -> 3x atk f2 (frames she picked), native durations
 'pick2_v2_3x_atk_f4': dict(lead=[('2x', 0), ('3x', 0), ('3x', 2)], lead_ms=[40, 40, 40], pre=2, motes=2.5,
                            pose='3x', hold=[4], ang=11.0, rec=[('3x', i) for i in range(5, 34)],
                            off={'2x': OFF_2X_FROM_IDLE, '3x': OFF_3X_FROM_2X0}, c0=0.45, cexp=1.0),
 # user [pt31u]: no holds - each lead-in frame plays once at its normal duration (idle 60 ms, crouching 70 ms as in the
 # .aseprite files; 3x atk is 35 ms in the file, shown at 40 ms like the rest of 3x atk here, GIF has 10 ms resolution)
 'pick1_v3_3x_atk_f24': dict(lead=[('idle', 0), ('cr', 0), ('3x', 23)], lead_ms=[60, 70, 40], pre=0, motes=2.5,
                             pose='3x', hold=[24], ang=180.0, rec=[('3x', i) for i in range(25, 34)], off={'3x': OFF_3X_FROM_CROUCH}, c0=0.45, cexp=1.0),  # name: lead-in [(anim, frame)], pose anim, hold frames, beam angle (deg, 0 = right, y down), recovery
 'pick1_3x_atk_f24': dict(lead=[('1x', i) for i in range(10)] + [('2x', i) for i in range(10)] + [('3x', i) for i in range(24)],
                          pose='3x', hold=[24], ang=180.0, rec=[('3x', i) for i in range(25, 34)]),
 'pick2_3x_atk_f4': dict(lead=[('1x', i) for i in range(10)] + [('2x', i) for i in range(10)] + [('3x', i) for i in range(4)],
                         pose='3x', hold=[4], ang=11.0, rec=[('3x', i) for i in range(5, 34)]),
 'pick3_dodge_atk_1x_f14': dict(lead=[('d1', i) for i in range(14)], pose='d1', hold=[14, 14, 14, 15, 15, 15], ang=180.0,
                                rec=[('d1', i) for i in range(16, 19)]),
}
FIRE, SUSTAIN, FADE = mb.FIRE, mb.SUSTAIN, mb.FADE
# game export (tools/export_game_anims.py): when SPLIT is a list, build() also appends one record per frame (rim-lit
# body, pack fx, energy bands, additive light). The GIF output is unchanged.
SPLIT = None
RANGE = 150; IDLE_PRE = 6; IDLE_POST = 26; S = 4; BG = np.array([18, 16, 30]) / 255
LW, LH, LOX, LOY = RANGE + 50, 90, 20, 45      # beam-local canvas


class HoverBeam(mb.Beam):
    """Beam whose dissolve particles are released into world space (self.world_spawn set during the fade)."""
    world_spawn = None
    def spawn(s, x, y, vx, vy, life, e, g=0.0, kind='spark'):
        if s.world_spawn is not None and g == 0.0 and kind == 'spark':
            s.world_spawn(x, y, e)
        else:
            super().spawn(x, y, vx, vy, life, e, g, kind)


def save_exact_gif(path, frames, durs, scale, allc):
    """exact-palette GIF: index every pixel by lookup (PIL's quantize(palette=) approximates colours)"""
    from PIL import ImageSequence
    key = (allc[:, 0].astype(np.int64) << 16) | (allc[:, 1].astype(np.int64) << 8) | allc[:, 2]
    flat = allc.flatten().tolist() + [0] * (768 - allc.size); ims = []
    for f in frames:
        a = np.array(f.resize((f.width * scale, f.height * scale), Image.NEAREST)).astype(np.int64)
        im = Image.fromarray(np.searchsorted(key, (a[..., 0] << 16) | (a[..., 1] << 8) | a[..., 2]).astype(np.uint8), 'P'); im.putpalette(flat); ims.append(im)
    ims[0].save(path, save_all=True, append_images=ims[1:], duration=durs, loop=0, disposal=1, optimize=False)
    dec = [np.array(g.convert('RGB')) for g in ImageSequence.Iterator(Image.open(path))]
    assert all((np.array(f.resize((f.width * scale, f.height * scale), Image.NEAREST)) == d).all() for f, d in zip(frames, dec))

_fxc = {}
def fx_img(a, f, layers):
    k = (a, f, tuple(sorted(layers)))
    if k not in _fxc: _fxc[k] = frame(D[a], f, only=set(layers))
    return _fxc[k]

def build(name, cfg):
    rng = random.Random(23)
    ang = math.radians(cfg['ang']); d = np.array([math.cos(ang), math.sin(ang)])
    n = np.array([-d[1], d[0]]) if d[0] >= 0 else np.array([d[1], -d[0]])      # beam-local "down" (mirrored when firing left)
    pose = cfg['pose']; hold = cfg['hold']; OFFS = {**OFF, **cfg.get('off', {})}
    # ---- timeline entries: (anim, frame, phase, k)
    seq = [('idle', i % 10, 'idle', None) for i in range(cfg.get('pre', IDLE_PRE))]
    seq += [(a, f, 'lead', j) for j, (a, f) in enumerate(cfg['lead'])]
    for ph, cnt in (('fire', FIRE), ('sustain', SUSTAIN), ('fade', FADE)):
        for k in range(cnt): seq.append((pose, hold[len(seq) % len(hold)], ph, k))
    seq += [(a, f, 'recover', j) for j, (a, f) in enumerate(cfg['rec'])]
    # end idle placed by silhouette match to the last recovery frame (ground pinned)
    la, lf = cfg['rec'][-1]
    endoff = None; best = (-1, 0, 0)
    for ii in range(10):
        iou, dx = best_dx(mask(img(la, lf)), mask(img('idle', ii)), GROUND - bottom(img('idle', ii)) - OFFS[la][1], range(-200, 200))
        if iou > best[0]: best = (iou, dx, ii)
    idle_dx = OFFS[la][0] + best[1]; idle_start = best[2]
    seq += [('idle', (idle_start + i) % 10, 'idle_end', i) for i in range(IDLE_POST)]
    def woff(a, phase):
        if phase == 'idle_end': return (idle_dx, 0)
        return OFFS[a]
    # ---- tips in world (lead-in + pose); interpolate hidden ones
    lead = [(a, f) for a, f, p, _ in seq if p == 'lead']
    pts = []
    for a, f in lead + [(pose, hold[0])]:
        t = TIPS[a].get(f); o = OFFS[a]
        pts.append(None if t is None else (t[0] + o[0], t[1] + o[1]))
    known = [i for i, p in enumerate(pts) if p is not None]
    for i, p in enumerate(pts):
        if p is None:
            lo = max([j for j in known if j < i], default=None); hi = min([j for j in known if j > i], default=None)
            if lo is None: pts[i] = pts[hi]
            elif hi is None: pts[i] = pts[lo]
            else:
                u = (i - lo) / (hi - lo); pts[i] = (pts[lo][0] + (pts[hi][0] - pts[lo][0]) * u, pts[lo][1] + (pts[hi][1] - pts[lo][1]) * u)
    hidden = [TIPS[a].get(f) is None for a, f in lead]
    tip_pose = pts[-1]
    # ---- recoil (native px, rigid), opposite the beam
    def recoil(ph, k):
        if ph == 'fire': r = [3.0, 2.4, 2.6][k]                                   # kick
        elif ph == 'sustain':
            u = (k + 1) / SUSTAIN; r = 2.6 + 2.4 * (1 - (1 - u) ** 3)              # ease-out push to ~5 px
        elif ph == 'fade':
            u = (k + 1) / FADE; r = 5.0 * (1 - (u * u * (3 - 2 * u)))              # settle back
        else: return (0, 0)
        v = -d * r
        sh = (0, 0)
        if ph == 'sustain' and k < SUSTAIN - 2: sh = (rng.choice((-1, 0, 1)) if k % 2 else 0, rng.choice((-1, 0, 0, 1)))
        return (int(round(v[0])) + sh[0], int(round(v[1])) + sh[1])
    # ---- world bounds
    xs, ys = [], []
    for a, f, p, _ in seq:
        b = img(a, f).getbbox(); o = woff(a, p); xs += [b[0] + o[0] - 6, b[2] + o[0] + 6]; ys += [b[1] + o[1], b[3] + o[1]]
        if a in cfg.get('fx', {}) and fx_img(a, f, cfg['fx'][a]).getbbox():
            b = fx_img(a, f, cfg['fx'][a]).getbbox(); xs += [b[0] + o[0] - 4, b[2] + o[0] + 4]; ys += [b[1] + o[1] - 2, b[3] + o[1] + 2]
    end = (tip_pose[0] + d[0] * (RANGE + 14), tip_pose[1] + d[1] * (RANGE + 14)); xs += [end[0], tip_pose[0] - d[0] * 10]; ys += [end[1] - 14, end[1] + 14]
    X0, Y0 = int(min(xs)) - 8, int(min(ys)) - 14; W = int(max(xs)) - X0 + 8; H = int(max(ys)) - Y0 + 10
    floor_w = GROUND + 1
    beam = HoverBeam(LW, LH, seed=11); hover = []
    by = np.tile(mb.BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W]
    YY, XX = np.mgrid[0:H, 0:W].astype(float)
    frames, durs, log = [], [], []
    li = 0; motes = []
    for t, (a, f, p, k) in enumerate(seq):
        o = woff(a, p); spr = img(a, f); rc = recoil(p, k) if p in ('fire', 'sustain', 'fade') else (0, 0)
        E = np.zeros((H, W)); L = np.zeros((H, W)); glow = 0.0
        # ---- charge orb on the tracked tip during the lead-in
        if p == 'lead':
            tx, ty = pts[k][0] - X0, pts[k][1] - Y0
            c0 = cfg.get('c0', 0.12); c = c0 + (1 - c0) * ((k + 1) / len(lead)) ** cfg.get('cexp', 1.4)
            if hidden[k]: c *= 0.55
            Dd = np.hypot(XX - tx, YY - ty)
            rad = 0.9 + 2.9 * c + 0.35 * math.sin(t * 1.3)
            E = np.maximum(E, np.clip(1.0 - Dd / rad, 0, 1) * (0.55 + 0.5 * c))
            L += 0.5 * c * np.exp(-Dd / 16); glow = c * 0.5
            for _ in range(int((1 + 4 * c) * cfg.get('motes', 1.0))):
                aa = rng.uniform(0, 2 * math.pi); r = rng.uniform(8, 16)
                motes.append([tx + r * math.cos(aa), ty + r * math.sin(aa), rng.randint(4, 7), rng.uniform(0.5, 0.9)])
            if k >= len(lead) - 4:   # rune ring closing in on the last frames
                R = 5 + (len(lead) - 1 - k) * 1.2
                for j in range(8):
                    a2 = j * 2 * math.pi / 8 + t * 0.35; x_, y_ = int(round(tx + R * math.cos(a2))), int(round(ty + R * math.sin(a2)))
                    if 0 <= x_ < W and 0 <= y_ < H: E[y_, x_] = max(E[y_, x_], 0.85 if j % 2 else 0.6)
        # motes spiral into the current tip
        if motes:
            tgt = (pts[k][0] - X0, pts[k][1] - Y0) if p == 'lead' else (tip_pose[0] + rc[0] - X0, tip_pose[1] + rc[1] - Y0)
            keep = []
            for m in motes:
                dx_, dy_ = tgt[0] - m[0], tgt[1] - m[1]; dist = math.hypot(dx_, dy_) + 1e-6
                m[0] += dx_ / dist * 2.6 - dy_ / dist * 1.2; m[1] += dy_ / dist * 2.6 + dx_ / dist * 1.2; m[2] -= 1
                if m[2] > 0 and dist > 2.5:
                    keep.append(m); x_, y_ = int(round(m[0])), int(round(m[1]))
                    if 0 <= x_ < W and 0 <= y_ < H: E[y_, x_] = max(E[y_, x_], m[3])
            motes = keep
        # ---- beam in local frame, resampled into world along the wand direction
        ox_w, oy_w = tip_pose[0] + rc[0] - X0 - d[0] * 0.0, tip_pose[1] + rc[1] - Y0
        ox_w += d[0] * 1.0; oy_w += d[1] * 1.0                                       # first pixel past the tip
        def to_world(lx, ly):
            u, v = lx - LOX, ly - LOY; return ox_w + u * d[0] + v * n[0], oy_w + u * d[1] + v * n[1]
        if p in ('fire', 'sustain', 'fade') or beam.parts:
            ph = (p, k) if p in ('fire', 'sustain', 'fade') else None
            if p == 'fade':
                def ws(x, y, e):
                    wx, wy = to_world(x, y)
                    life = rng.randint(int(len(seq) - t) // 2, max(int(len(seq) - t) - 4, int(len(seq) - t) // 2 + 1))
                    hover.append([wx, wy, rng.uniform(-0.12, 0.12), rng.uniform(-0.10, -0.02), life, life, rng.uniform(0.55, 0.95), rng.uniform(0, 6.28)])
                beam.world_spawn = ws
            else: beam.world_spawn = None
            El, Ll, gl, _ = beam.step(ph, LOX, LOY, LOX + RANGE, LOY + (floor_w - Y0 - oy_w) / max(n[1], 0.3), t)
            u = (XX - ox_w) * d[0] + (YY - oy_w) * d[1] + LOX; v = (XX - ox_w) * n[0] + (YY - oy_w) * n[1] + LOY
            ui, vi = np.rint(u).astype(int), np.rint(v).astype(int); ok = (ui >= 0) & (ui < LW) & (vi >= 0) & (vi < LH)
            Ew = np.zeros((H, W)); Lw = np.zeros((H, W)); Ew[ok] = El[vi[ok], ui[ok]]; Lw[ok] = Ll[vi[ok], ui[ok]]
            E = np.maximum(E, Ew); L += Lw; glow = max(glow, gl)
        # ---- hovering dissolve particles (world space, slow drift, gradual fade)
        keep = []
        for h in hover:
            h[7] += 0.15; h[0] += h[2] + 0.06 * math.sin(h[7]); h[1] += h[3]; h[4] -= 1
            if h[4] <= 0: continue
            keep.append(h); fade = min(1.0, (h[4] / h[5]) * 1.6)
            x_, y_ = int(round(h[0])), int(round(h[1]))
            if 0 <= x_ < W and 0 <= y_ < H: E[y_, x_] = max(E[y_, x_], h[6] * fade)
        hover = keep
        # ---- composite
        lit = np.floor(np.clip(L, 0, 1.2) * 4 + by) / 4
        bg = np.clip(np.zeros((H, W, 3)) + BG + lit[..., None] * mb.TINT * 1.6, 0, 1)
        if p == 'fire' and k == 0: bg = bg * 0.75 + 0.25 * np.array([0.16, 0.5, 0.42])
        im = Image.fromarray((bg * 255).astype(np.uint8)).convert('RGBA')
        sp = spr
        if glow > 0.2:   # rim light on the beam side
            sp = mb.rim(spr.transpose(Image.FLIP_LEFT_RIGHT), glow).transpose(Image.FLIP_LEFT_RIGHT) if d[0] < 0 else mb.rim(spr, glow)
        im.alpha_composite(sp, (o[0] + rc[0] - X0, o[1] + rc[1] - Y0))
        fxi = None
        if a in cfg.get('fx', {}):   # the pack's own effect layers, original pixels, same canvas offset + recoil as the body
            fxi = fx_img(a, f, cfg['fx'][a])
            if fxi.getbbox(): im.alpha_composite(fxi, (o[0] + rc[0] - X0, o[1] + rc[1] - Y0))
        rgb, al = mb.bands(np.clip(E, 0, 1.2)); base = np.array(im).astype(float) / 255
        if SPLIT is not None:
            SPLIT.append(dict(t=t, anim=a, frame=f, phase=p, k=k, pos=(o[0] + rc[0] - X0, o[1] + rc[1] - Y0), spr=sp, fxi=fxi, rgb=rgb, al=al,
                              light=np.clip(lit[..., None] * mb.TINT * 1.6, 0, 1), E=E.copy(), origin=(X0, Y0), size=(W, H), idle_dx=idle_dx, idle_frame=idle_start))
        out = base[..., :3] * (1 - al[..., None]) + rgb * al[..., None]
        frames.append(Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), 'RGB'))
        durs.append(cfg['lead_ms'][k] if p == 'lead' and 'lead_ms' in cfg else 60 if p in ('idle', 'idle_end') else 40)
        log.append(dict(t=t, anim=NAMES[a], frame=f, phase=p, k=k, recoil=list(rc), ms=durs[-1], hover=len(hover),
                        tip=None if p != 'lead' else [round(pts[k][0], 1), round(pts[k][1], 1)], tip_hidden=bool(hidden[k]) if p == 'lead' else None))
    # ---- write GIF (exact palette if possible)
    allc = np.unique(np.concatenate([np.array(fr).reshape(-1, 3) for fr in frames]), axis=0)
    if len(allc) <= 256:
        pal = Image.new('P', (1, 1)); pl = allc.flatten().tolist(); pal.putpalette(pl + [0] * (768 - len(pl)))
    else:
        strip = Image.new('RGB', (W, H * len(frames)))
        for i, fr in enumerate(frames): strip.paste(fr, (0, i * H))
        pal = strip.quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    gif = f'{OUT}/{name}_cast.gif'
    if cfg.get('exact') and len(allc) <= 256:   # exact palette indexing, verified on read-back (newer previews)
        save_exact_gif(gif, frames, durs, S, allc)
    else:
        q = [fr.resize((W * S, H * S), Image.NEAREST).quantize(palette=pal, dither=Image.Dither.NONE) for fr in frames]
        q[0].save(gif, save_all=True, append_images=q[1:], duration=durs, loop=0, disposal=1, optimize=False)
    return frames, log, dict(gif=gif, size=[W * S, H * S], frames=len(frames), ms=sum(durs), colours=int(len(allc)), bytes=os.path.getsize(gif),
                             world_origin=[X0, Y0], tip_pose_world=list(tip_pose), idle_end_match=dict(idle_frame=idle_start, dx=idle_dx, iou=round(best[0], 3)))

def keystrip(name, frames, log):
    want = []
    def first(cond):
        for L in log:
            if cond(L): return L['t']
    lead = [L for L in log if L['phase'] == 'lead']
    picks = [('start', 0), ('lead early', lead[len(lead) // 4]['t']), ('lead mid', lead[len(lead) // 2]['t']),
             ('lead last', lead[-1]['t']), ('fire', first(lambda L: L['phase'] == 'fire')), ('sustain', first(lambda L: L['phase'] == 'sustain' and L['k'] == 9)),
             ('fade', first(lambda L: L['phase'] == 'fade' and L['k'] == 3)), ('recover', first(lambda L: L['phase'] == 'recover')),
             ('idle +8', first(lambda L: L['phase'] == 'idle_end' and L['k'] == 8)), ('idle +18', first(lambda L: L['phase'] == 'idle_end' and L['k'] == 18))]
    W, H = frames[0].size; s = 2; cols = 2
    sh = Image.new('RGB', (cols * W * s, ((len(picks) + 1) // 2) * (H * s + 16)), (0, 0, 0)); dr = ImageDraw.Draw(sh)
    for j, (lab, t) in enumerate(picks):
        x, y = (j % cols) * W * s, (j // cols) * (H * s + 16); L = log[t]
        sh.paste(frames[t].resize((W * s, H * s), Image.NEAREST), (x, y + 16))
        dr.text((x + 4, y + 2), f"{lab}: t={t} {L['anim']} f{L['frame']} {L['phase']} recoil {L['recoil']} hover {L['hover']}", fill=(255, 255, 255))
    sh.save(f'{OUT}/{name}_keyframes.png')

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True); rows = []
    meta = json.load(open(f'{OUT}/cast_sequences.json')) if os.path.exists(f'{OUT}/cast_sequences.json') else {}
    only = sys.argv[1:] or [k for k in PICKS if k != 'pick1_combo_beam_slash'] + ['pick1_combo_beam_slash']
    for name in only:
        frames, log, info = build(name, PICKS[name]); keystrip(name, frames, log)
        json.dump(log, open(f'{OUT}/{name}_timeline.json', 'w'), indent=0); meta[name] = info; print(name, info)
    json.dump(meta, open(f'{OUT}/cast_sequences.json', 'w'), indent=1, default=float)
