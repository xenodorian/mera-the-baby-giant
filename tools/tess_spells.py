"""Tessellating spell segments for the playable level (tools/export_game_anims.py writes them to the game folder).

Beam (combo beam, normal and Fury): mid segments TW px long that tile seamlessly. Every deterministic part (the width
waves, the travelling pulse, the halo) is periodic in x with period TW, and all segments show the same frame index,
so segment edges line up at any count. Random parts (width jitter per column, crackle arcs, sparks, dissolve
particles) stay inside each segment, and three variants with different randomness break up the repetition.
Formulas and colours follow tools/mera_wand_beam.py (Beam.step / bands / TINT), so the tiles keep the canon look
(teal/white bands, crackle, dissolve particles). The game recolours them deep red in Fury with the fx shader.
Rows: sustain loop (NL frames), fade (FADE frames, columns dissolve), linger (dissolve particles drifting and fading
while Mera recovers), front (the extending beam head during the fire frames) and impact (beam end, off-screen).
Art faces LEFT like the rest of Mera's frames: the beam runs from a segment's right edge to its left edge.

Lightning (R1): vertical mid segments LTH px tall. The bolt enters and leaves every segment at the centre column,
so the segments stack seamlessly; branches stay inside their segment. Rows: mid (variants), bottom (ground impact),
top (fork that fades out above the screen). Palette = the explosion bands (projectile_cast.BANDS), like before."""
import math, random
import numpy as np
from PIL import Image
import mera_wand_beam as mb
import projectile_cast as pc

TW, TH, CY = 64, 48, 24          # beam segment size and beam centre row
NL, FADE, LINGER, V = 8, mb.FADE, 9, 3
CAP = 24                          # px of the baked cast frames kept past the wand (start cap); segments begin there
K1, K2 = 2 * math.pi * 2 / TW, 2 * math.pi * 5 / TW      # ~0.196 / ~0.49 rad/px: canon 0.22 / 0.45, made periodic
LW, LTH = 56, 64                  # lightning segment size
LN = 6                            # lightning frames (50 ms each)


def _bands_rgba(E):
    rgb, al = mb.bands(np.clip(E, 0, 1.2)); a = np.zeros(E.shape + (4,), np.uint8)
    a[..., :3] = (rgb * 255).astype(np.uint8); a[..., 3] = (al * 255).astype(np.uint8); return a


def _light_rgba(L):
    H, W = L.shape; by = np.tile(mb.BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W]
    lit = np.floor(np.clip(L, 0, 1.2) * 4 + by) / 4; rgb = np.clip(lit[..., None] * mb.TINT * 1.6, 0, 1)
    a = np.zeros((H, W, 4), np.uint8); m = rgb.max(-1) > 0.004
    a[m, :3] = (rgb[m] * 255).astype(np.uint8); a[m, 3] = 255; return a


class _Seg(mb.Beam):
    def raster_wrap(s, E, pts, core=0.97, glow=0.52):
        s.raster(E, [(max(1, min(TW - 2, x)), y) for x, y in pts], core, glow)


def _core(E, f, env, rng, keep=None):
    """beam body columns, periodic in x (period TW) and in time (period NL)"""
    ph = 2 * math.pi * f / NL; dy = np.arange(TH) - CY
    for x in range(TW):
        if keep is not None and not keep[x]: continue
        pulse = max(0.0, math.sin(K1 * x - ph)) ** 6
        base = 3.6 * env * (1 + 0.18 * math.sin(K2 * x - 2 * ph) + 0.12 * math.sin(K1 * x + ph) + 0.35 * pulse)
        wu = base * (1 + rng.uniform(-0.22, 0.22)); wl = base * (1 + rng.uniform(-0.22, 0.22))
        ratio = np.where(dy < 0, -dy / (wu + 2.0), dy / (wl + 2.0))
        col = np.where(ratio < 1, 1.08 * (1 - np.clip(ratio, 0, 1) ** 1.6) + 0.08 * pulse, 0)
        E[:, x] = np.maximum(E[:, x], np.clip(col, 0, 1.1) * (0.6 + 0.4 * env))


def _arcs(seg, E, rng, env, n):
    for _ in range(n):
        ln = rng.uniform(10, 26); xa = rng.uniform(3, TW - 3 - ln); xb = xa + ln
        sa, sb = rng.choice((-1, 1)), rng.choice((-1, 1))
        ya = CY + sa * (3 * env + rng.uniform(1, 6)); yb = CY + sb * (3 * env + rng.uniform(1, 6))
        pts = seg.bolt(xa, ya, xb, yb, 5); seg.raster_wrap(E, pts)
        if rng.random() < 0.5:
            mx, my = pts[len(pts) // 2]
            seg.raster_wrap(E, seg.bolt(mx, my, mx + rng.uniform(3, 8), my + rng.choice((-1, 1)) * rng.uniform(3, 7), 3, 3), 0.85, 0.4)


def _dots(E, parts):
    for p in parts:
        x, y = int(round(p['x'])), int(round(p['y']))
        if 1 <= x < TW - 1 and 0 <= y < TH: E[y, x] = max(E[y, x], p['v'])
        if p.get('trail') and 1 <= int(round(p['x'] - p['vx'])) < TW - 1 and 0 <= int(round(p['y'] - p['vy'])) < TH:
            E[int(round(p['y'] - p['vy'])), int(round(p['x'] - p['vx']))] = max(E[int(round(p['y'] - p['vy'])), int(round(p['x'] - p['vx']))], p['v'] * 0.6)


def beam_rows():
    """returns {row: [frames of (fx RGBA, light RGBA)] per variant} in +x orientation (flipped by the caller)"""
    rows = {}
    halo = np.exp(-np.abs(np.arange(TH) - CY) / 7)[:, None] * np.ones((1, TW))
    for v in range(V):
        rng = random.Random(100 + v); seg = _Seg(TW, TH, seed=200 + v)
        # sustain loop: sparks pre-warmed over 2 loops so the loop starts populated
        sparks = []; out = []
        for t in range(NL * 3):
            for _ in range(2):
                sg = rng.choice((-1, 1))
                sparks.append(dict(x=rng.uniform(4, TW - 4), y=CY + sg * 3, vx=rng.uniform(0.3, 1.8), vy=sg * rng.uniform(0.4, 1.4),
                                   life=rng.randint(5, 10), v0=rng.uniform(0.6, 1.0), trail=True))
            for p in sparks: p['x'] += p['vx']; p['y'] += p['vy']; p['life'] -= 1
            sparks = [p for p in sparks if p['life'] > 0 and 1 <= p['x'] < TW - 1]
            for p in sparks: p['v'] = p['v0'] * (0.45 + 0.55 * min(1, p['life'] / 8))
            if t < NL * 2: continue
            f = t - NL * 2; E = np.zeros((TH, TW)); _core(E, f, 1.0, rng); _arcs(seg, E, rng, 1.0, rng.randint(1, 2)); _dots(E, sparks)
            out.append((_bands_rgba(E), _light_rgba(0.8 * halo)))
        rows[('sustain', v)] = out
        # fade + linger: columns drop out, each dropped column releases hovering particles (canon world hover)
        n = np.array([rng.random() for _ in range(TW)]) * 0.6 + 0.4 * (np.sin(np.arange(TW) * K1 + v) * 0.5 + 0.5)
        hover = []; fade = []; linger = []; total = FADE + LINGER
        for k in range(FADE):
            env = 1 - (k + 1) / (FADE + 1); thr = (k + 1) / FADE; keep = n > thr * 0.95
            E = np.zeros((TH, TW)); _core(E, (k * 2) % NL, env, rng, keep)
            if k <= 1: _arcs(seg, E, rng, env, 1)
            for x in np.where(~keep)[0][::3]:
                if not any(abs(h['x0'] - x) < 0.5 for h in hover):
                    life = rng.randint((total - k) // 2 + 2, total - k + 2)
                    hover.append(dict(x0=float(x), x=float(x), y=CY + rng.uniform(-2, 2), vx=rng.uniform(-0.12, 0.12), vy=rng.uniform(-0.10, -0.02),
                                      life=life, max=life, e=rng.uniform(0.55, 0.95), ph=rng.uniform(0, 6.28)))
            _hover(E, hover); fade.append((_bands_rgba(E), _light_rgba(0.8 * env * halo)))
        for k in range(LINGER):
            E = np.zeros((TH, TW)); _hover(E, hover); linger.append((_bands_rgba(E), _light_rgba(0 * halo)))
        rows[('fade', v)] = fade; rows[('linger', v)] = linger
    # beam head while extending (fire frames) and the impact at the beam end (both centred at x = TW/2)
    YY, XX = np.mgrid[0:TH, 0:TW].astype(float); xe = TW // 2; rng = random.Random(7); seg = _Seg(TW, TH, seed=8)
    front, impact = [], []
    for f in range(NL):
        D = np.hypot(XX - xe, YY - CY)
        E = np.clip(1.15 - D / 4.5, 0, 1.1); front.append((_bands_rgba(E), _light_rgba(0.5 * np.exp(-D / 9))))
        rimp = 5 + 2 * math.sin(f * 2.7) + rng.uniform(-1, 1)
        E = np.clip(1.2 - D / rimp, 0, 1.1) * (XX <= xe + 1)
        for j in range(7):
            ang = math.pi / 2 + (j / 6) * math.pi + rng.uniform(-0.2, 0.2); ln = rng.uniform(5, 12)
            seg.raster(E, seg.bolt(xe, CY, xe + ln * math.cos(ang), CY + ln * math.sin(ang), 3, 2), 0.9, 0.45)
        impact.append((_bands_rgba(E), _light_rgba(0.5 * np.exp(-D / 9))))
    rows[('front', 0)] = front; rows[('impact', 0)] = impact
    return rows


def _hover(E, hover):
    for h in hover:
        if h['life'] <= 0: continue
        h['ph'] += 0.15; h['x'] += h['vx'] + 0.06 * math.sin(h['ph']); h['y'] += h['vy']; h['life'] -= 1
        fade = min(1.0, (h['life'] / h['max']) * 1.6); x, y = int(round(h['x'])), int(round(h['y']))
        if 1 <= x < TW - 1 and 0 <= y < TH and h['life'] > 0: E[y, x] = max(E[y, x], h['e'] * fade)


def _lstroke(E, pts, w, e):
    H, W = E.shape
    for xx, yy in pts:
        x0 = int(round(xx))
        for dx in range(-w - 2, w + 3):
            vv = e * max(0.0, 1 - abs(dx) / (w + 2.5))
            if 0 <= x0 + dx < W and 0 <= yy < H: E[yy, x0 + dx] = max(E[yy, x0 + dx], vv)


def _lpath(rng, y0, y1, x0, x1, W):
    """zig-zag from (x0, y0) down to (x1, y1), exact endpoints, one point per row"""
    n = y1 - y0; xs = []; x = 0.0
    for i in range(n + 1):
        if i % 6 == 0 and i: x = x + rng.uniform(-3.2, 3.2) - x * 0.06
        xs.append(x)
    xs = np.array(xs); xs = xs - xs[-1] * np.arange(n + 1) / max(n, 1)        # pin the end
    xs = x0 + (x1 - x0) * np.arange(n + 1) / max(n, 1) + xs
    return [(float(np.clip(xs[i], 6, W - 7)), y0 + i) for i in range(n + 1)]


def lightning_rows():
    rows = {}; c = LW / 2
    for v in range(V):
        rng = random.Random(300 + v); fr = []
        for i in range(LN):
            fade = 1.0 if i < LN - 2 else (0.75 if i == LN - 2 else 0.5)
            E = np.zeros((LTH, LW)); pts = _lpath(rng, 0, LTH - 1, c, c, LW); _lstroke(E, pts, 1, 1.2 * fade)
            if rng.random() < 0.6:          # a branch inside this segment
                y0 = int(rng.uniform(4, LTH - 26)); xb = pts[y0][0]; dirb = rng.choice((-1, 1)); bp = []
                for k in range(int(rng.uniform(10, 20))):
                    if k % 4 == 0: xb = float(np.clip(xb + dirb * rng.uniform(0.5, 2.5), 1, LW - 2))
                    bp.append((xb, y0 + k))
                _lstroke(E, bp, 0, 0.75 * fade)
            fr.append(pc_band(E))
        rows[('mid', v)] = fr
    rng = random.Random(400); bot = []; top = []
    YY, XX = np.mgrid[0:LTH, 0:LW].astype(float); gy = LTH - 4
    for i in range(LN):
        fade = 1.0 if i < LN - 2 else (0.75 if i == LN - 2 else 0.5)
        E = np.zeros((LTH, LW)); end = c + rng.uniform(-5, 5)
        _lstroke(E, _lpath(rng, 0, gy, c, end, LW), 1, 1.2 * fade)
        E = np.maximum(E, np.clip(1 - np.hypot((XX - end) / (12 - i), (YY - gy) / 4), 0, 1) * 1.1 * fade)
        for _ in range(4):
            ang = rng.uniform(math.pi * 1.1, math.pi * 1.9); ln = rng.uniform(5, 14) * fade
            _lstroke(E, [(end + r * math.cos(ang), int(round(gy + r * math.sin(ang)))) for r in range(int(ln))], 0, 0.8 * fade)
        bot.append(pc_band(E))
        E = np.zeros((LTH, LW))
        for b in range(3):                 # fork fanning out upward, dimming away from the seam (above the screen)
            xt = c + (b - 1) * rng.uniform(8, 18)
            pts = _lpath(rng, 0, LTH - 1, xt, c, LW)
            for x, y in pts: _lstroke(E, [(x, y)], 1 if b == 1 else 0, (1.2 if b == 1 else 0.8) * fade * (0.4 + 0.6 * y / LTH))
        top.append(pc_band(E))
    rows[('bottom', 0)] = bot; rows[('top', 0)] = top
    return rows


def pc_band(E):
    H, W = E.shape; a = np.zeros((H, W, 4), np.uint8)
    for th, col in pc.BANDS:
        m = E >= th; a[m, :3] = col; a[m, 3] = 255
    return a


def sheet(rows, order, cw, ch, flip=False, layer=None):
    """grid sheet: one row per (name, variant), frames left to right. Returns (Image, {name: [first_row, variants, frames]})"""
    nmax = max(len(rows[k]) for k in order); im = np.zeros((ch * len(order), cw * nmax, 4), np.uint8); info = {}
    for r, k in enumerate(order):
        for i, fr in enumerate(rows[k]):
            a = fr if layer is None else fr[layer]
            if flip: a = a[:, ::-1]
            im[r * ch:(r + 1) * ch, i * cw:(i + 1) * cw] = a
        nm, v = k
        if nm not in info: info[nm] = [r, 0, len(rows[k])]
        info[nm][1] += 1
    return Image.fromarray(im), info
