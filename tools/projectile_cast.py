"""Projectile versions of the Mera wand casts (user requests, 2026-10-30). Same spell family for both:
every effect pixel is one of the explosion's own palette colours (sampled from ansimuz Ground Explosion).

  pick1_v4_projectile  (rear shot, 3x atk f24): lead-in as pick1 v3 (idle f0 60 ms -> crouching f0 70 ms -> 3x atk f23
      40 ms, quick charge), f24 fires a fireball LEFT from the wand tip (162,72); she holds f24 4 x 40 ms with a short
      3-2-1-0 px recoil kick and goes straight into the f25-33 recovery. The shot flies 120 px (10 px / 40 ms), drops to
      the ground and plays ansimuz "Ground Explosion" (Legacy Collection, CC0) at 1:1, 70 ms/frame.
  pick3_v2_projectile  (dodge atk 1x f14): 2 idle frames -> dodge atk 1x f0-13 (40 ms each, charge ramps), f14 fires a
      small quick bolt LEFT from the tip (94,22); f14 + f15 play once each (40 ms) with a 2-1 px kick, then f16-18 and
      idle. The bolt flies 90 px straight (12 px / 40 ms) and pops in the air with ansimuz explosion-1-a (32x32,
      8 frames, explosions-pack, CC0) recoloured on the fly to the same palette (the file is not modified).
Sparks shed by the shot and embers/smoke from the impact linger and fade. Event-driven GIF: a frame is emitted
whenever Mera, the shot or the explosion changes, so each plays at its own rate (10 ms steps, minimum 20 ms).
Usage (repo root): python3 tools/projectile_cast.py [pick1_v4_projectile|pick3_v2_projectile]  (default: both)"""
import os, sys, json, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image, ImageDraw, ImageSequence
import beam_cast_sequences as cs
import mera_wand_beam as mb

ROOT = cs.ROOT; OUT = cs.OUT; S = 4
VFX = f'{ROOT}/assets/vfx/ansimuz'
GEX = f'{VFX}/ground-explosion'
_fr = json.load(open(f'{GEX}/spritesheet/explosion-animation.json'))['frames']
# palette of Ground Explosion (exact sprite colours), brightest -> darkest
P = dict(core=(255, 248, 230), hot=(250, 169, 83), mid=(207, 86, 56), outer=(163, 33, 33), dark=(105, 27, 43),
         deep=(74, 20, 39), smoke=(130, 88, 97))
BANDS = [(0.18, P['dark']), (0.32, P['outer']), (0.52, P['mid']), (0.72, P['hot']), (0.90, P['core'])]
BG = (18, 16, 30)

def ground_explosion():
    fr = [Image.open(f'{GEX}/sprites/explosion-animation{i}.png').convert('RGBA') for i in range(1, 10)]
    return fr, [f['duration'] for f in (_fr.values() if isinstance(_fr, dict) else _fr)]
def small_pop():
    """explosions-pack explosion-1-a (8 x 32x32), recoloured in memory: its 3 colours -> core / hot / mid"""
    sh = Image.open(f'{VFX}/explosions-pack/explosion-1-a/spritesheet.png').convert('RGBA'); a = np.array(sh)
    for src, dst in [((255, 236, 145), P['core']), ((255, 166, 25), P['hot']), ((255, 60, 0), P['mid'])]:
        m = (a[..., :3] == src).all(-1) & (a[..., 3] > 0); a[m, :3] = dst
    sh = Image.fromarray(a); fr = [sh.crop((i * 32, 0, i * 32 + 32, 32)) for i in range(8)]
    fr = [f for f in fr if f.getbbox()]; return fr, [60] * len(fr)

CFG = {
 'pick1_v4_projectile': dict(pre=[], lead=[('idle', 0, 60), ('cr', 0, 70), ('3x', 23, 40)], offs={'3x': cs.OFF_3X_FROM_CROUCH},
     hold=[('3x', 24)] * 4, recoil=[3, 2, 1, 0], rec=[('3x', i) for i in range(25, 34)], pose=('3x', 24),
     speed=10, dist=120, drop=True, big=True, ex=ground_explosion, anchor='ground', c0=0.45, n_motes=46, ring=3,
     n_embers=34, ember_r=(8, 34), linger=1000),
 # user [pt39u]: the "rear blast" is pick2 v2 -> same fireball + Ground Explosion, fired right ~11 deg down along the wand
 'pick2_v3_projectile': dict(pre=[('idle', 0, 60), ('idle', 1, 60)], lead=[('2x', 0, 40), ('3x', 0, 40), ('3x', 2, 40)],
     offs={'2x': cs.OFF_2X_FROM_IDLE, '3x': cs.OFF_3X_FROM_2X0}, hidden={('3x', 0)},
     hold=[('3x', 4)] * 4, recoil=[3, 2, 1, 0], rec=[('3x', i) for i in range(5, 34)], pose=('3x', 4), dir=+1, ang=11.0,
     speed=10, dist=130, drop=True, big=True, ex=ground_explosion, anchor='ground', c0=0.45, n_motes=46, ring=3,
     n_embers=34, ember_r=(8, 34), linger=1000),
 'pick3_v2_projectile': dict(pre=[('idle', 0, 60), ('idle', 1, 60)], lead=[('d1', i, 40) for i in range(14)], offs={},
     hold=[('d1', 14), ('d1', 15)], recoil=[2, 1], rec=[('d1', i) for i in range(16, 19)], pose=('d1', 14),
     speed=12, dist=90, drop=False, big=False, ex=small_pop, anchor='centre', c0=0.15, n_motes=40, ring=3,
     n_embers=12, ember_r=(3, 12), linger=700),
}
TICK = 40

def build(name, C):
    rng = random.Random(7)
    OFFS = {**cs.OFF, **C['offs']}; EX, EX_MS = C['ex']()
    seg = []; t = 0
    for a, f, d in C['pre']: seg.append((t, d, a, f, 'idle', None)); t += d
    for li, (a, f, d) in enumerate(C['lead']): seg.append((t, d, a, f, 'lead', li)); t += d
    T_FIRE = t
    for k, (a, f) in enumerate(C['hold']): seg.append((t, TICK, a, f, 'fire', k)); t += TICK
    for a, f in C['rec']: seg.append((t, TICK, a, f, 'recover', None)); t += TICK
    T_IDLE = t
    la, lf = C['rec'][-1]; best = (-1, 0, 0)
    for ii in range(10):
        iou, dx = cs.best_dx(cs.mask(cs.img(la, lf)), cs.mask(cs.img('idle', ii)), cs.GROUND - cs.bottom(cs.img('idle', ii)) - OFFS[la][1], range(-200, 200))
        if iou > best[0]: best = (iou, dx, ii)
    IDLE_OFF = (OFFS[la][0] + best[1], 0)
    SPEED = C['speed'] / TICK; DIST = C['dist']; T_HIT = T_FIRE + DIST / SPEED; T_EXP_END = T_HIT + sum(EX_MS)
    t_end = int(max(T_EXP_END + C['linger'], T_IDLE + 20 * 60)); k = 0
    while t < t_end: seg.append((t, 60, 'idle', (best[2] + k) % 10, 'idle_end', None)); t += 60; k += 1
    T_END = t
    def mera_at(tm):
        for s in seg:
            if s[0] <= tm < s[0] + s[1]: return s
        return seg[-1]
    def woff(a, ph): return IDLE_OFF if ph == 'idle_end' else OFFS[a]
    DIR = C.get('dir', -1); TANA = math.tan(math.radians(C.get('ang', 0.0))); HID = C.get('hidden', set())
    def tip_world(a, f):
        if (a, f) in HID:   # wand hidden behind her: midway between the neighbouring lead-in tips
            L_ = [(x, y) for x, y, _ in C['lead']]; i = L_.index((a, f))
            p0 = tip_world(*L_[i - 1]); p1 = tip_world(*L_[i + 1]) if i + 1 < len(L_) else tip_world(*C['pose'])
            return (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
        tx, ty = cs.TIPS[a][f]; o = OFFS[a]; return tx + o[0], ty + o[1]
    TIP = tip_world(*C['pose']); GY = cs.GROUND; R0 = C['recoil'][0]
    def proj_pos(tm):
        s = (tm - T_FIRE) * SPEED; u = s / DIST; x0, y0 = TIP[0] - DIR * (R0 - 2), TIP[1]
        if C['drop']:   # leaves along the wand angle, curves down to land just above the ground at DIST
            k = (GY - 3 - y0 - DIST * TANA) / (DIST * DIST); y = y0 + s * TANA + k * s * s
        else: y = y0 + 0.08 * s
        return x0 + DIR * s, y + 0.6 * math.sin(s * 0.35)
    X_HIT, Y_HIT = proj_pos(T_HIT)
    # particles (analytic in time, deterministic)
    motes = [(rng.uniform(0, T_FIRE - 40), rng.uniform(110, 200), rng.uniform(0, 6.28), rng.uniform(7, 15), rng.uniform(0.55, 0.95)) for _ in range(C['n_motes'])]
    sparks = []; tt = T_FIRE
    while tt < T_HIT:
        x, y = proj_pos(tt)
        for _ in range(2 if C['big'] else 1):
            sparks.append((tt, rng.uniform(500, 1200) * (1 if C['big'] else 0.7), x + rng.uniform(1, 5), y + rng.uniform(-2, 2), rng.uniform(-0.002, 0.004), rng.uniform(-0.006, -0.001), rng.uniform(0.6, 0.98)))
        tt += 20
    for _ in range(10 if C['big'] else 5):
        sparks.append((T_FIRE, rng.uniform(200, 450), TIP[0] - DIR, TIP[1] + rng.uniform(-1, 1), -DIR * rng.uniform(0.005, 0.03), rng.uniform(-0.02, 0.02), 0.95))
    embers = []
    cy = GY - 6 if C['anchor'] == 'ground' else Y_HIT
    for _ in range(C['n_embers']):
        a = rng.uniform(math.pi * 1.05, math.pi * 1.95) if C['anchor'] == 'ground' else rng.uniform(0, 2 * math.pi)
        r = rng.uniform(*C['ember_r'])
        embers.append((T_HIT + rng.uniform(0.25, 0.8) * sum(EX_MS), rng.uniform(900, 1600) * (1 if C['big'] else 0.6), X_HIT + r * math.cos(a), cy + r * math.sin(a) * 0.9,
                       rng.uniform(-0.004, 0.004), rng.uniform(-0.008, -0.002), 'ember' if rng.random() < 0.55 else 'smoke'))
    def life_k(t0, life, tm):
        u = (tm - t0) / life; return None if u < 0 or u >= 1 else u
    ex_pos = (int(X_HIT - EX[0].width // 2), int(GY - 100)) if C['anchor'] == 'ground' else (int(round(X_HIT)) - 16, int(round(Y_HIT)) - 16)
    # canvas
    xs, ys = [], []
    for s in seg:
        b = cs.img(s[2], s[3]).getbbox(); o = woff(s[2], s[4]); xs += [b[0] + o[0], b[2] + o[0] + 4]; ys += [b[1] + o[1], b[3] + o[1]]
    xs += [ex_pos[0], ex_pos[0] + EX[0].width]; ys += [ex_pos[1] + min(e.getbbox()[1] for e in EX if e.getbbox()), ex_pos[1] + max(e.getbbox()[3] for e in EX if e.getbbox())]
    X0, Y0 = int(min(xs)) - 6, int(min(ys)) - 4; W = int(max(xs)) - X0 + 6; H = int(max(ys)) - Y0 + 8
    YY, XX = np.mgrid[0:H, 0:W].astype(float); BAY = np.tile(mb.BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W]
    def disc(E, cx, cy, rad, peak):
        d = np.hypot(XX - cx, YY - cy); np.maximum(E, np.clip(1 - d / rad, 0, 1) * peak, out=E)
    def dot(E, x, y, e):
        xi, yi = int(round(x)), int(round(y))
        if 0 <= xi < W and 0 <= yi < H: E[yi, xi] = max(E[yi, xi], e)
    nl = len(C['lead'])
    def render(tm):
        s = mera_at(tm); a, f, ph, li = s[2], s[3], s[4], s[5]
        o = woff(a, ph); rc = (-DIR * C['recoil'][li] if li < len(C['recoil']) else 0, 0) if ph == 'fire' else (0, 0)
        E = np.zeros((H, W)); L = np.zeros((H, W)); smoke = np.zeros((H, W)); glow = 0.0
        if ph == 'lead':   # charge orb + motes + rune ring, peak on the last lead-in frame
            tx, ty = tip_world(a, f); tx -= X0; ty -= Y0
            c = C['c0'] + (1 - C['c0']) * (li + 1) / nl; sz = 1.0 if C['big'] else 0.75
            dimf = 0.55 if (a, f) in HID else 1.0
            disc(E, tx, ty, (1.0 + 2.9 * c + 0.3 * math.sin(tm * 0.05)) * sz, (0.6 + 0.45 * c) * dimf)
            L += 0.55 * c * np.exp(-np.hypot(XX - tx, YY - ty) / 15); glow = 0.5 * c
            if li >= nl - C['ring']:
                R = 5 + (nl - 1 - li) * 1.2
                for j in range(8):
                    a2 = j * 2 * math.pi / 8 + tm * 0.009; dot(E, tx + R * math.cos(a2), ty + R * math.sin(a2), 0.85 if j % 2 else 0.6)
            for (t0, lf, ang, r0, e) in motes:
                u = life_k(t0, lf, tm)
                if u is None: continue
                r = r0 * (1 - u); dot(E, tx + r * math.cos(ang + 2.2 * u), ty + r * math.sin(ang + 2.2 * u), e)
        if T_FIRE <= tm < T_FIRE + TICK:   # muzzle flash
            disc(E, TIP[0] + rc[0] - X0, TIP[1] - Y0, 4.5 if C['big'] else 3.0, 1.05)
            L += 0.8 * np.exp(-np.hypot(XX - (TIP[0] - X0), YY - (TIP[1] - Y0)) / 20); glow = 0.8
        if T_FIRE <= tm < T_HIT:           # the shot: head + trail along its real path
            px, py = proj_pos(tm); px -= X0; py -= Y0
            n, r0h, r0t, dr = (16, 3.6, 3.4, 0.17) if C['big'] else (9, 2.3, 2.0, 0.13)
            for j in range(n):
                tb = tm - j * 6
                if tb < T_FIRE: break
                qx, qy = proj_pos(tb); qx -= X0; qy -= Y0
                disc(E, qx, qy + (0.5 * math.sin(tb * 0.06 + j) if j > 3 else 0), max(0.8, r0t - j * dr), 1.0 - j * 0.05)
            disc(E, px, py, r0h, 1.15); L += (0.55 if C['big'] else 0.35) * np.exp(-np.hypot(XX - px, YY - py) / 13)
        for (t0, lf, x0, y0, vx, vy, e) in sparks:
            u = life_k(t0, lf, tm)
            if u is None: continue
            dtm = tm - t0; dot(E, x0 + vx * dtm - X0, y0 + vy * dtm + 0.000002 * dtm * dtm - Y0, e * (1 - u) ** 0.8)
        for (t0, lf, x0, y0, vx, vy, kind) in embers:
            u = life_k(t0, lf, tm)
            if u is None: continue
            dtm = tm - t0; x, y = x0 + vx * dtm - X0, y0 + vy * dtm - Y0
            if kind == 'ember': dot(E, x, y, 0.75 * (1 - u) + 0.15)
            else:
                xi, yi = int(round(x)), int(round(y))
                if 0 <= xi < W - 1 and 0 <= yi < H - 1 and BAY[yi, xi] > u * 0.9: smoke[yi:yi + 2, xi:xi + 2] = 1 if u < 0.55 else 0.5
        exi = None
        if T_HIT <= tm < T_EXP_END:
            acc = T_HIT; exi = 0
            for i, d in enumerate(EX_MS):
                if tm < acc + d: exi = i; break
                acc += d
            fl = max(0.0, 0.9 - 0.13 * exi) * (1 if C['big'] else 0.6)
            ecy = (GY - 20) if C['anchor'] == 'ground' else Y_HIT
            L += fl * np.exp(-np.hypot(XX - (X_HIT - X0), YY - (ecy - Y0)) / (30 if C['big'] else 14))
        img = np.zeros((H, W, 3), np.uint8); img[:] = BG
        img[L > (BAY * 1.1 + 0.18)] = P['deep']
        img[smoke >= 1] = P['smoke']; img[(smoke > 0) & (smoke < 1)] = P['deep']
        im = Image.fromarray(img).convert('RGBA'); spr = cs.img(a, f)
        if glow > 0.2:   # rim light on the edge the shot leaves from, palette colour
            arr = np.array(spr); m = arr[..., 3] > 0; col = P['hot'] if glow > 0.55 else P['mid']
            for yy in range(arr.shape[0]):
                xx = np.nonzero(m[yy])[0]
                if len(xx): arr[yy, xx[0] if DIR < 0 else xx[-1], :3] = col
            spr = Image.fromarray(arr)
        im.alpha_composite(spr, (o[0] + rc[0] - X0, o[1] + rc[1] - Y0))
        if exi is not None: im.alpha_composite(EX[exi], (ex_pos[0] - X0, ex_pos[1] - Y0))
        out = np.array(im)[..., :3]
        for th, col in BANDS: out[E >= th] = col
        return Image.fromarray(out), dict(t=int(tm), anim=cs.NAMES[a], frame=f, phase=ph, recoil=list(rc), explosion_frame=exi,
                                          projectile=None if not (T_FIRE <= tm < T_HIT) else [round(v, 1) for v in proj_pos(tm)])
    # event clock
    ev = {s[0]: 1 for s in seg}
    for i in range(int((T_HIT - T_FIRE) // TICK) + 1): ev[int(T_FIRE + TICK * i)] = 2
    for s in seg:
        if s[4] == 'lead' and s[1] >= 60: ev.setdefault(s[0] + 30, 0)
    acc = T_HIT
    for d in EX_MS: ev[int(acc)] = 3; acc += d
    ev[int(acc)] = 3
    ev = sorted((e, p) for e, p in ev.items() if e < T_END); evm = []
    for n, (e, p) in enumerate(ev):   # GIF players clamp delays < 20 ms: nudge lower-priority events, keep explosion timing
        nxt = ev[n + 1][0] if n + 1 < len(ev) else T_END
        if evm and e - evm[-1][0] < 20:
            if p > evm[-1][1] and (len(evm) < 2 or e - evm[-2][0] >= 20): evm[-1] = (e, p); continue
            e = evm[-1][0] + 20
            if nxt - e < 20: continue
        evm.append((e, p))
    evm = [e for e, _ in evm]
    frames, durs, log = [], [], []
    for i, e in enumerate(evm):
        fr, Lg = render(e); frames.append(fr); d = (evm[i + 1] if i + 1 < len(evm) else T_END) - e; durs.append(d); Lg['ms'] = d; log.append(Lg)
    allc = np.unique(np.concatenate([np.array(f).reshape(-1, 3) for f in frames]), axis=0)
    save_exact_gif(f'{OUT}/{name}_cast.gif', frames, durs, S, allc)
    json.dump(log, open(f'{OUT}/{name}_timeline.json', 'w'), indent=0)
    def at(tm): return max(i for i, e in enumerate(evm) if e <= tm)
    lead_t = [s[0] for s in seg if s[4] == 'lead']
    picks = [('start', 0), ('lead early', lead_t[0]), ('lead mid', lead_t[len(lead_t) // 2]), ('lead last (peak)', lead_t[-1]), ('fire', T_FIRE),
             ('flight', T_FIRE + 0.45 * (T_HIT - T_FIRE)), ('impact', T_HIT), ('explosion mid', T_HIT + sum(EX_MS) * 0.4),
             ('lingering', T_EXP_END + 100), ('fading', T_EXP_END + C['linger'] * 0.6)]
    cols = 2; sh = Image.new('RGB', (cols * W * 2, ((len(picks) + 1) // 2) * (H * 2 + 16))); dr = ImageDraw.Draw(sh)
    for j, (lab, tm) in enumerate(picks):
        i = at(tm); x, y = (j % cols) * W * 2, (j // cols) * (H * 2 + 16); Lg = log[i]
        sh.paste(frames[i].resize((W * 2, H * 2), Image.NEAREST), (x, y + 16))
        dr.text((x + 4, y + 2), f"{lab}: {Lg['t']} ms {Lg['anim']} f{Lg['frame']} recoil {Lg['recoil']} expl {Lg['explosion_frame']}", fill=(255, 255, 255))
    sh.save(f'{OUT}/{name}_keyframes.png')
    meta = dict(gif=f'previews/beam/cast_sequences/{name}_cast.gif', size=[W * S, H * S], frames=len(frames), ms=T_END, colours=int(len(allc)),
                bytes=os.path.getsize(f'{OUT}/{name}_cast.gif'), t_fire=T_FIRE, t_hit=T_HIT, t_explosion_end=T_EXP_END, t_idle=T_IDLE,
                tip_world=TIP, impact_world=[round(X_HIT, 1), round(Y_HIT, 1)], explosion_ms=EX_MS, palette=P, canvas_origin=[X0, Y0],
                idle_end=dict(frame=best[2], dx=IDLE_OFF[0], iou=round(float(best[0]), 3)))
    json.dump(meta, open(f'{OUT}/{name}.json', 'w'), indent=1); print(name, meta)
    return frames, log, meta

def save_exact_gif(path, frames, durs, scale, allc):
    """exact-palette GIF: index every pixel by lookup (PIL's quantize(palette=) approximates colours); verified on read-back"""
    assert len(allc) <= 256
    key = (allc[:, 0].astype(np.int64) << 16) | (allc[:, 1].astype(np.int64) << 8) | allc[:, 2]
    flat = allc.flatten().tolist() + [0] * (768 - allc.size); ims = []
    for f in frames:
        a = np.array(f.resize((f.width * scale, f.height * scale), Image.NEAREST)).astype(np.int64)
        im = Image.fromarray(np.searchsorted(key, (a[..., 0] << 16) | (a[..., 1] << 8) | a[..., 2]).astype(np.uint8), 'P'); im.putpalette(flat); ims.append(im)
    ims[0].save(path, save_all=True, append_images=ims[1:], duration=durs, loop=0, disposal=1, optimize=False)
    dec = [np.array(g.convert('RGB')) for g in ImageSequence.Iterator(Image.open(path))]
    assert all((np.array(f.resize((f.width * scale, f.height * scale), Image.NEAREST)) == d).all() for f, d in zip(frames, dec)), 'GIF round-trip mismatch'

if __name__ == '__main__':
    for n in (sys.argv[1:] or list(CFG)): build(n, CFG[n])
