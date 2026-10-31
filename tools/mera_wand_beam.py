"""Mera wand beam: 1x atk wind-up -> hold most-extended frame -> procedural beam (port of the wizard_beam
energy-field method from GameOfGameBecauseGame/reference/wizard_beam_pixel_art.zip, src/render.py) -> to idle.
Pure pixel art: smooth energy field E cut into flat colour bands; light field added through a 4x4 Bayer dither."""
import sys, os, math, random, glob, json, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ase_render import load, frame
from PIL import Image, ImageDraw
import numpy as np

REPO = os.environ.get('REPO', os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
MK = f'{REPO}/assets/characters/merakintsugi/platformer-character-pack'
FK = f'{REPO}/assets/characters/chierit/fire-knight/png/fire_knight'
CEM = f'{REPO}/assets/environments/ansimuz/gothicvania-cemetery'
OUT = os.environ.get('OUT', f'{REPO}/previews/beam')
DER = os.environ.get('DER', f'{REPO}/assets/characters/merakintsugi/derived/beam_cast')
SCALE = 4

def hx(s): s = s.lstrip('#'); return np.array([int(s[i:i+2], 16) / 255 for i in (0, 2, 4)])
# Mera's own slash-fx teal ramp (from 1x atk_fx layer), core to edge
RAMP = [(0.30, hx('28c090')), (0.50, hx('48e0b0')), (0.66, hx('88f8d0')), (0.80, hx('c8f8e8')), (0.92, hx('ffffff'))]
TINT = np.array([0.03, 0.16, 0.12])     # faint halo / light colour (teal)
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0

# ---------------- timeline ----------------
A = load(f'{MK}/atk/1x atk/1x atk_c.aseprite')
CHAR = {'1x atk', 'to idle'}
HOLD_SRC = 5                    # 1x atk frame 6 (1-based): the fully extended pose (identical to frame 5)
TIP = (149, 39)                 # wand tip pixel in the 160x64 atk canvas at HOLD_SRC
CHARGE, FIRE, SUSTAIN, FADE = 6, 3, 14, 6
NHOLD = CHARGE + FIRE + SUSTAIN + FADE          # 29 frames held = 1.16 s at 40 ms
SEQ = [(i, None) for i in range(0, HOLD_SRC)] + [(HOLD_SRC, h) for h in range(NHOLD)] \
    + [(i, None) for i in range(6, 17)] + [(16, None)] * 6
# phase of hold frame h
def phase(h):
    if h is None: return None
    if h < CHARGE: return ('charge', h)
    h -= CHARGE
    if h < FIRE: return ('fire', h)
    h -= FIRE
    if h < SUSTAIN: return ('sustain', h)
    return ('fade', h - SUSTAIN)

def sprite(i): return frame(A, i, only=CHAR)

# ---------------- beam (energy field) ----------------
def line(x0, y0, x1, y1):
    x0, y0, x1, y1 = map(lambda v: int(round(v)), (x0, y0, x1, y1))
    dx, dy = abs(x1 - x0), -abs(y1 - y0); sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err, pts = dx + dy, []
    while True:
        pts.append((x0, y0))
        if x0 == x1 and y0 == y1: return pts
        e2 = 2 * err
        if e2 >= dy: err += dy; x0 += sx
        if e2 <= dx: err += dx; y0 += sy

class Beam:
    def __init__(s, W, H, seed=7): s.W, s.H = W, H; s.rng = random.Random(seed); s.parts = []
    YY = None
    def bolt(s, xa, ya, xb, yb, amp, depth=4):
        pts = [(xa, ya), (xb, yb)]
        for _ in range(depth):
            new = [pts[0]]
            for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
                new += [((x0 + x1) / 2 + s.rng.uniform(-amp, amp) * 0.4, (y0 + y1) / 2 + s.rng.uniform(-amp, amp)), (x1, y1)]
            pts, amp = new, amp * 0.55
        return pts
    def raster(s, E, pts, core=0.97, glow=0.52):
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            for x, y in line(x0, y0, x1, y1):
                for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    if 0 <= x + ox < s.W and 0 <= y + oy < s.H: E[y + oy, x + ox] = max(E[y + oy, x + ox], glow)
                if 0 <= x < s.W and 0 <= y < s.H: E[y, x] = max(E[y, x], core)
    def spawn(s, x, y, vx, vy, life, e, g=0.0, kind='spark'):
        s.parts.append(dict(x=x, y=y, vx=vx, vy=vy, life=life, max=life, e=e, g=g, kind=kind))
    def step(s, ph, ox, oy, xmax, floor, t):
        """returns E (energy), L (light), glow, beam end x. ox,oy = wand tip (beam origin), beam runs to +x up to xmax."""
        W, H, rng = s.W, s.H, s.rng
        YY, XX = np.mgrid[0:H, 0:W].astype(float)
        E = np.zeros((H, W)); L = np.zeros((H, W)); glow = 0.0; xend = None
        D0 = np.hypot(XX - ox, YY - oy)
        if ph and ph[0] == 'charge':
            k = ph[1]; c = 0.35 + 0.65 * (k / (CHARGE - 1))
            rad = 1.5 + 2.6 * c + 0.4 * math.sin(k * 1.3)
            E = np.maximum(E, np.clip(1.0 - D0 / rad, 0, 1) * (0.75 + 0.35 * c))
            L += 0.5 * c * np.exp(-D0 / 18); glow = c * 0.5
            for _ in range(2 + k // 2):
                a = rng.uniform(0, 2 * math.pi); r = rng.uniform(10, 18)
                s.spawn(ox + r * math.cos(a), oy + r * math.sin(a), 0, 0, rng.randint(5, 8), rng.uniform(0.55, 0.9), kind='mote')
            if k >= 3:  # rune ring closing in
                n = 8; R = 6 + (CHARGE - 1 - k) * 1.0
                for j in range(n):
                    a = j * 2 * math.pi / n + k * 0.35
                    x, y = int(round(ox + R * math.cos(a))), int(round(oy + R * math.sin(a)))
                    if 0 <= x < W and 0 <= y < H: E[y, x] = max(E[y, x], 0.85 if j % 2 else 0.6)
        elif ph and ph[0] in ('fire', 'sustain', 'fade'):
            kind, k = ph
            ext = {0: 0.3, 1: 0.62, 2: 0.88}[k] if kind == 'fire' else 1.0
            env = 1.0 if kind != 'fade' else 1 - (k + 1) / (FADE + 1)
            if kind == 'fire' and k == 0: env = 0.7
            xend = int(ox + (xmax - ox) * ext)
            xs = np.arange(int(ox), xend + 1); rel = xs - ox
            pulse = np.maximum(0, np.sin(rel * 0.22 - t * 1.9)) ** 6
            base = 3.6 * env * (1 + 0.18 * np.sin(rel * 0.45 - t * 3.1) + 0.12 * np.sin(rel * 0.13 + t * 1.3) + 0.35 * pulse)
            base *= 0.45 + 0.55 * np.clip(rel / 10, 0, 1)            # taper at the wand
            wu = base * (1 + np.array([rng.uniform(-0.22, 0.22) for _ in xs]))
            wl = base * (1 + np.array([rng.uniform(-0.22, 0.22) for _ in xs]))
            keep = np.ones(len(xs), bool)
            if kind == 'fade':
                thr = (k + 1) / FADE
                n = np.array([rng.random() for _ in rel]) * 0.6 + 0.4 * (np.sin(rel * 0.11 + t) * 0.5 + 0.5)
                keep = n > thr * 0.95
                for i in np.where(~keep)[0][::3]:
                    s.spawn(xs[i], oy + rng.uniform(-2, 2), rng.uniform(-0.3, 0.6), rng.uniform(-1.0, -0.2), rng.randint(6, 12), rng.uniform(0.5, 0.9))
            dy = YY[:, 0] - oy
            for i, x in enumerate(xs):
                if not keep[i] or not 0 <= x < W: continue
                ratio = np.where(dy < 0, -dy / (wu[i] + 2.0), dy / (wl[i] + 2.0))
                col = np.where(ratio < 1, 1.08 * (1 - np.clip(ratio, 0, 1) ** 1.6) + 0.08 * pulse[i], 0)
                E[:, x] = np.maximum(E[:, x], np.clip(col, 0, 1.1) * (0.6 + 0.4 * env))
            inx = np.clip((XX - ox + 4) / 10, 0, 1) * (XX <= xend + 2)      # soft start at the wand, no hard box edge
            L += 0.8 * env * np.exp(-np.abs(YY - oy) / 7) * inx
            L += 0.5 * env * np.exp(-np.hypot(XX - xend, YY - oy) / 9); glow = env
            # muzzle flare + 4-ray star alternating 0/45 deg
            E = np.maximum(E, np.clip(1.2 - D0 / (5.5 + 1.0 * math.sin(t * 2.1)), 0, 1.1) * env)
            a = (t % 2) * math.pi / 4
            for j in range(4):
                ang = a + j * math.pi / 2; ln = 6 + 3 * ((t + j) % 3)
                for r in range(3, int(ln * env) + 1):
                    x, y = int(round(ox + r * math.cos(ang))), int(round(oy + r * math.sin(ang)))
                    if 0 <= x < W and 0 <= y < H: E[y, x] = max(E[y, x], 0.95 - r / ln * 0.55)
            if not (kind == 'fade' and k > 1):  # crackling arcs + edge sparks
                for _ in range(rng.randint(2, 4)):
                    xa = rng.uniform(ox + 4, max(ox + 5, xend - 8)); xb = min(xa + rng.uniform(10, 28), xend)
                    sa, sb = rng.choice((-1, 1)), rng.choice((-1, 1))
                    ya = oy + sa * (3 * env + rng.uniform(1, 6)); yb = oy + sb * (3 * env + rng.uniform(1, 6))
                    pts = s.bolt(xa, ya, xb, yb, 5); s.raster(E, pts)
                    if rng.random() < 0.5:
                        mx, my = pts[len(pts) // 2]
                        s.raster(E, s.bolt(mx, my, mx + rng.uniform(3, 8), my + rng.choice((-1, 1)) * rng.uniform(3, 7), 3, 3), 0.85, 0.4)
                if kind == 'sustain' and rng.random() < 0.3:  # ground strike
                    gx = rng.uniform(ox + 16, xend - 8)
                    s.raster(E, s.bolt(gx, oy + 3, gx + rng.uniform(-6, 6), floor, 4))
                    for _ in range(5): s.spawn(gx, floor - 1, rng.uniform(-1.5, 1.5), rng.uniform(-2.0, -0.6), rng.randint(5, 9), 0.85, g=0.25)
                for _ in range(4):
                    x = rng.uniform(ox + 5, xend); sg = rng.choice((-1, 1))
                    s.spawn(x, oy + sg * 3 * env, rng.uniform(0.3, 1.8), sg * rng.uniform(0.4, 1.4), rng.randint(5, 10), rng.uniform(0.6, 1.0))
            if ext >= 1.0 and not (kind == 'fade' and k > 2):  # impact at the end
                D = np.hypot(XX - xend, YY - oy)
                rimp = (5 + 2 * math.sin(t * 2.7) + rng.uniform(-1, 1)) * env
                E = np.maximum(E, np.clip(1.2 - D / max(rimp, 1), 0, 1.1) * (XX <= xend + 1))
                for j in range(7):
                    ang = math.pi / 2 + (j / 6) * math.pi + rng.uniform(-0.2, 0.2); ln = rng.uniform(5, 12) * env
                    s.raster(E, s.bolt(xend, oy, xend + ln * math.cos(ang), oy + ln * math.sin(ang), 3, 2), 0.9, 0.45)
                for _ in range(3):
                    s.spawn(xend - 1, oy + rng.uniform(-3, 3), rng.uniform(-2.8, -0.8), rng.uniform(-2.2, 1.0), rng.randint(7, 14), rng.uniform(0.7, 1.0), g=0.18)
            elif ext < 1.0:
                D = np.hypot(XX - xend, YY - oy); E = np.maximum(E, np.clip(1.15 - D / 4.5, 0, 1.1))
        # particles
        for p in s.parts[:]:
            if p['kind'] == 'mote':
                dx, dy_ = ox - p['x'], oy - p['y']; dist = math.hypot(dx, dy_) + 1e-6
                p['vx'] = dx / dist * 2.4 - dy_ / dist * 1.1; p['vy'] = dy_ / dist * 2.4 + dx / dist * 1.1
                if dist < 2.5: p['life'] = 0
            p['x'] += p['vx']; p['y'] += p['vy']; p['vy'] += p['g']; p['life'] -= 1
            if p['y'] >= floor and p['g'] > 0: p['y'] = floor - 1; p['vy'] *= -0.4; p['vx'] *= 0.6
            if p['life'] <= 0: s.parts.remove(p); continue
            kk = p['life'] / p['max']; x, y = int(round(p['x'])), int(round(p['y'])); v = p['e'] * (0.45 + 0.55 * kk)
            if 0 <= x < W and 0 <= y < H:
                E[y, x] = max(E[y, x], v)
                if kk > 0.6 and p['kind'] == 'spark':
                    tx, ty = int(round(p['x'] - p['vx'])), int(round(p['y'] - p['vy']))
                    if 0 <= tx < W and 0 <= ty < H: E[ty, tx] = max(E[ty, tx], v * 0.6)
        return np.clip(E, 0, 1.2), L, glow, xend

def bands(E):
    """energy -> RGBA layer: opaque flat bands >=0.30, faint halo below (alpha)"""
    H, W = E.shape; rgb = np.zeros((H, W, 3)); a = np.zeros((H, W))
    soft = (E > 0.06) & (E < RAMP[0][0]); rgb[soft] = RAMP[0][1]; a[soft] = np.where(E[soft] > 0.18, 0.4, 0.2)  # 2 flat halo steps
    for th, col in RAMP: rgb[E >= th] = col
    a[E >= RAMP[0][0]] = 1
    return rgb, a

def rim(spr, glow):
    """rim light: beam-side (rightmost) opaque pixel of each row recoloured while the beam glows"""
    if glow <= 0.2: return spr
    arr = np.array(spr); m = arr[..., 3] > 0; c = (RAMP[1][1] if glow > 0.55 else RAMP[0][1]) * 255
    for y in range(arr.shape[0]):
        xs = np.nonzero(m[y])[0]
        if len(xs): arr[y, xs[-1], :3] = c
    return Image.fromarray(arr)

def cemetery(W):
    """ansimuz Gothicvania Cemetery scene, 224 px tall, feet line y=188 (same layout as tools/compat.py)"""
    bg = Image.open(f'{CEM}/background.png').convert('RGBA'); mt = Image.open(f'{CEM}/mountains.png').convert('RGBA')
    gy = Image.open(f'{CEM}/graveyard.png').convert('RGBA'); tile = Image.open(f'{CEM}/tileset.png').convert('RGBA').crop((64, 48, 128, 96))
    o = Image.new('RGBA', (W, 224), (12, 8, 24, 255))
    for x in range(0, W, bg.width): o.alpha_composite(bg, (x, 0))
    for x in range(0, W, mt.width): o.alpha_composite(mt, (x, 224 - mt.height - 30))
    for x in range(0, W, gy.width): o.alpha_composite(gy, (x, 224 - gy.height - 20))
    ImageDraw.Draw(o).rectangle([0, 202, W, 224], fill=(23, 14, 28, 255))
    for x in range(0, W, 64): o.alpha_composite(tile, (x, 172))
    return o

def fk_frames(d): return [Image.open(p).convert('RGBA') for p in sorted(glob.glob(f'{FK}/{d}/*.png'), key=lambda s: int(re.findall(r'(\d+)\.png', s)[0]))]
def ubox(im): return Image.Image.getbbox(im)

def render(bg_kind, path, with_target):
    W = 330
    if bg_kind == 'dark':
        H = 80; FEET = 72; bg = Image.new('RGBA', (W, H), (18, 16, 30, 255))
        d = ImageDraw.Draw(bg); d.rectangle([0, FEET + 1, W, H], fill=(30, 26, 48, 255)); d.line([0, FEET + 1, W, FEET + 1], fill=(48, 42, 72, 255))
    else:
        full = cemetery(W); FEET = 188; top = FEET - 70; bg = full.crop((0, top, W, top + 90)); FEET -= top; H = 90
    mb = max(np.nonzero(np.array(sprite(0))[..., 3])[0])      # Mera feet row in canvas (atk canvas, ground frames)
    MX = 8; MY = FEET - mb                                     # atk canvas placement
    ox, oy = MX + TIP[0] + 1, MY + TIP[1]                      # beam origin: first pixel right of the wand tip
    # target
    tgt = None
    if with_target:
        idle = fk_frames('01_idle'); hit = fk_frames('10_take_hit')
        idl = idle[0].transpose(Image.FLIP_LEFT_RIGHT); b = ubox(idl)
        TX = 300; tgt = dict(idle=[f.transpose(Image.FLIP_LEFT_RIGHT) for f in idle], hit=[f.transpose(Image.FLIP_LEFT_RIGHT) for f in hit],
                             pos=(TX - (b[0] + b[2]) // 2, FEET - b[3]))
        # beam end = first opaque knight pixel on the beam row (+1 px into the body)
        row = np.array(idl)[oy - tgt['pos'][1], :, 3]; xmax = tgt['pos'][0] + int(np.nonzero(row)[0].min()) + 1 if row.any() else tgt['pos'][0] + b[0]
    else:
        xmax = ox + 150
    beam = Beam(W, H); frames = []; log = []; hit_t = None; end_t = -99
    for t, (si, h) in enumerate(SEQ):
        ph = phase(h)
        E, L, glow, xend = beam.step(ph, ox, oy, xmax, FEET, t)
        img = bg.copy()
        # light on environment through Bayer dither
        by = np.tile(BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W]
        lit = np.floor(np.clip(L, 0, 1.2) * 4 + by) / 4
        arr = np.array(img).astype(float) / 255; arr[..., :3] = np.clip(arr[..., :3] + lit[..., None] * TINT * 1.6, 0, 1)
        if ph and ph[0] == 'fire' and ph[1] == 0: arr[..., :3] = arr[..., :3] * 0.6 + 0.4 * np.array([0.16, 0.5, 0.42])
        img = Image.fromarray((arr * 255).astype(np.uint8))
        # target
        if tgt:
            if ph and ph[0] in ('sustain',) and hit_t is None: hit_t = t
            if ph and ph[0] in ('sustain', 'fade'): end_t = t
            n_hit = len(tgt['hit'])
            if hit_t is not None and (ph and ph[0] in ('sustain', 'fade') or t - end_t < (n_hit - 3) * 2):
                # stagger: frames 1-3 while the beam is on, then frames 4..n after it ends
                fr = tgt['hit'][min((t - hit_t) // 2, 2)] if ph and ph[0] in ('sustain', 'fade') else tgt['hit'][min(3 + (t - end_t) // 2, n_hit - 1)]
                if (t - hit_t) < 2 or (ph and ph[0] == 'sustain' and (t - hit_t) % 6 == 0):   # white flash on hit + per tick
                    a_ = np.array(fr); a_[..., :3] = np.where(a_[..., 3:] > 0, 255, a_[..., :3]); fr = Image.fromarray(a_)
            else: fr = tgt['idle'][(t // 3) % len(tgt['idle'])]
            img.alpha_composite(fr, tgt['pos'])
        spr = rim(sprite(si), glow if h is not None else 0)
        img.alpha_composite(spr, (MX, MY))
        rgb, a = bands(E)
        base = np.array(img).astype(float) / 255
        out = base[..., :3] * (1 - a[..., None]) + rgb * a[..., None]
        out = Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), 'RGB')
        frames.append(out); log.append(dict(t=t, src_frame=si + 1, hold=h, phase=ph[0] if ph else ('atk' if si < 10 else 'to idle'), beam_end=xend))
    big = [f.resize((W * SCALE, H * SCALE), Image.NEAREST) for f in frames]
    # one shared palette from all frames (exact if <=256 colours)
    allc = np.unique(np.concatenate([np.array(f).reshape(-1, 3) for f in frames]), axis=0)
    strip = Image.new('RGB', (W, H * len(frames)))
    for i, f in enumerate(frames): strip.paste(f, (0, i * H))
    pal_img = strip.quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE) if len(allc) > 256 else None
    if pal_img is None:
        pal_img = Image.new('P', (1, 1)); pl = allc.flatten().tolist(); pal_img.putpalette(pl + [0] * (768 - len(pl)))
    q = [b.quantize(palette=pal_img, dither=Image.Dither.NONE) for b in big]
    q[0].save(path, save_all=True, append_images=q[1:], duration=40, loop=0, disposal=1, optimize=False)
    print(path, len(frames), 'frames', len(allc), 'colours', 'origin', (ox, oy), 'xmax', xmax)
    return frames, log, (MX, MY, ox, oy, W, H, FEET)

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    fr, log, geo = render('dark', f'{OUT}/mera_wand_beam.gif', False)
    W, H = geo[4], geo[5]
    # frame sheet (every frame, 1x -> 2x) with frame labels
    cols = 8; rows = (len(fr) + cols - 1) // cols; S = 2
    sh = Image.new('RGB', (cols * W * S, rows * (H * S + 12)), (8, 8, 12)); d = ImageDraw.Draw(sh)
    for i, f in enumerate(fr):
        x, y = (i % cols) * W * S, (i // cols) * (H * S + 12)
        sh.paste(f.resize((W * S, H * S), Image.NEAREST), (x, y + 12)); L_ = log[i]
        d.text((x + 3, y), f"{i}: atk f{L_['src_frame']} {L_['phase']}" + (f" h{L_['hold']}" if L_['hold'] is not None else ''), fill=(220, 220, 220))
    sh.save(f'{OUT}/mera_wand_beam_sheet.png')
    json.dump(dict(timeline=log, geometry=dict(zip(['mera_x', 'mera_y', 'origin_x', 'origin_y', 'W', 'H', 'feet'], geo)), fps=25, frame_ms=40), open(f'{OUT}/mera_wand_beam_timeline.json', 'w'), indent=1, default=int)
    render('cemetery', f'{OUT}/mera_wand_beam_cemetery_vs_fire_knight.gif', True)
    render('dark', f'{OUT}/mera_wand_beam_vs_fire_knight.gif', True)
