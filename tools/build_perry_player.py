#!/usr/bin/env python3
"""Perry as a playable character: cut EVERY Perry Riposte move into frames and write the move table.

Reads assets/perry/source/biboo_data.json (window.BIBOO dump: `moves`, `beams`, `input`), the chain moves in
assets/perry/source/moves_extra.json (moves_extra.js without its JS wrapper) and the strips beside them. Writes
  assets/characters/perry/player/<move>/<move>_<n>.png      one PNG per frame (n from 1, strip cell n-1, full cell, no trim)
  assets/characters/perry/player/<move>_fx/<move>_fx_<n>.png  the FX strips (energy_wave, meteor_shower, energy_burst)
  assets/characters/perry/player/beamtile_<kind>/beamtile_<kind>_1.png  the four beam tiles
  assets/perry/perry_player.json
Per move the JSON holds: frames, loop, loopFrom, input, inputType, cell, pivot, hurt, and per frame ms, root [dx, dy]
(px, y up), top, shake, beam, and `hits`: attack boxes [x0, y0, x1, y1] in sprite px relative to the pivot (x forward,
y down from the feet line, so a box 80 px up is -80). Perry Riposte names the attack boxes `hits` on moves.

The pivot is the same body-centre rule build_perry.py uses: pivot x = anchor x + c, with c = (opaque bbox centre of the
idle first frame) - idle anchor x; pivot y = anchor y (the feet row). Shapes (capsule, box, circle) become the bounding
box of each shape; a move with an fxScale (energy wave 0.6, meteor shower 1.8) scales its shapes by it, like the
original (worldShape). heavy_horizontal is the slash with a 50 px step (progress.js / 00_core.js), so it reuses the
slash frames (`anim` names the frame folder).
Re-run:  python3 tools/build_perry_player.py
"""
import json, os, shutil
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets/perry/source")
OUT = os.path.join(ROOT, "assets/characters/perry/player")
META = os.path.join(ROOT, "assets/perry/perry_player.json")
HH_STEP = 50.0           # heavy horizontal: the slash while she steps this far forward (00_core.js)
DASH_DIST = 120.0        # dash, dash_thrust, energy_dash_thrust cover this far (04_chain.js)
BURST_SCALE = 1.0        # energy_burst circle radius scale (12_hits.js)


def strip_path(src):
    rel = src[len("assets/"):] if src.startswith("assets/") else src
    return os.path.join(SRC, rel)


def open_strip(src, cw, ch):
    im = Image.open(strip_path(src)).convert("RGBA")
    assert im.size[1] == ch, "%s height %d != cell %d" % (src, im.size[1], ch)
    assert im.size[0] % cw == 0, "%s width %d not a multiple of %d" % (src, im.size[0], cw)
    return im


def opaque_bbox(im):
    return im.split()[3].point(lambda v: 255 if v > 40 else 0).getbbox()


def boxes_of(hits, sc, c, burst):
    """hit shapes (anchor space, y up) -> [x0, y0, x1, y1] boxes relative to the pivot (y down from the feet)."""
    out = []
    for h in hits or []:
        if h["shape"] == "capsule":
            r = h["radius"] * sc
            (ax, ay), (bx, by) = h["a"], h["b"]
            xs = [ax * sc, bx * sc]
            ys = [ay * sc, by * sc]
            x0, x1, y0, y1 = min(xs) - r, max(xs) + r, min(ys) - r, max(ys) + r
        elif h["shape"] == "circle":
            r = h["r"] * (BURST_SCALE if burst else sc)
            cx, cy = h["c"][0] * sc, h["c"][1] * sc
            x0, x1, y0, y1 = cx - r, cx + r, cy - r, cy + r
        else:
            (ax, ay), (bx, by) = h["a"], h["b"]
            x0, x1 = sorted([ax * sc, bx * sc])
            y0, y1 = sorted([ay * sc, by * sc])
        out.append([round(x0 - c, 1), round(-y1, 1), round(x1 - c, 1), round(-y0, 1)])
    return out


def main():
    with open(os.path.join(SRC, "biboo_data.json")) as fh:
        data = json.load(fh)
    with open(os.path.join(SRC, "moves_extra.json")) as fh:
        extra = json.load(fh)
    moves = dict(data["moves"])
    moves.update(extra)
    idle = moves["idle"]
    icw, ich = idle["cell"]
    istrip = open_strip(idle["sheet"], icw, ich)
    bb = opaque_bbox(istrip.crop((0, 0, icw, ich)))
    c = (bb[0] + bb[2]) / 2.0 - idle["anchor"][0]
    body_w = bb[2] - bb[0]
    if os.path.isdir(OUT):
        shutil.rmtree(OUT)
    os.makedirs(OUT)
    # dash moves keep their shape but cover DASH_DIST (04_chain.js)
    for mid in ("dash", "dash_thrust", "energy_dash_thrust"):
        fr = moves[mid]["frames"]
        end = fr[-1]["root"][0]
        if end > 0:
            for f in fr:
                f["root"] = [f["root"][0] * DASH_DIST / end, f["root"][1]]
    result = {"body_c": round(c, 2), "body_w": body_w, "hurt": [round(10 - c, 1), round(60 - c, 1)],
              "moves": {}, "beams": {}, "fx": {}}
    total = 0
    for mid, m in moves.items():
        cw, ch = m["cell"]
        ax, ay = m["anchor"]
        strip = open_strip(m["sheet"], cw, ch)
        d = os.path.join(OUT, mid)
        os.makedirs(d)
        n = len(m["frames"])
        for i in range(n):
            strip.crop((i * cw, 0, (i + 1) * cw, ch)).save(os.path.join(d, "%s_%d.png" % (mid, i + 1)))
            total += 1
        sc = float(m.get("fxScale") or 1.0)
        shp = sc if m.get("fxSheet") else 1.0
        frames = []
        for f in m["frames"]:
            fd = {"name": f["name"], "ms": f["ms"], "root": [round(f["root"][0], 2), round(f["root"][1], 2)],
                  "top": f["top"], "shake": f["shake"], "hits": boxes_of(f["hits"], shp, c, mid == "energy_burst")}
            if f.get("beam"):
                fd["beam"] = f["beam"]
            if f.get("bw"):
                fd["bw"] = True
            frames.append(fd)
        entry = {"anim": mid, "title": m["title"], "input": m["input"], "inputType": m["inputType"], "loop": m["loop"],
                 "loopFrom": m["loopFrom"], "cell": [cw, ch], "anchor": [ax, ay], "pivot": [round(ax + c, 2), ay],
                 "frames": frames, "enter": m.get("enter")}
        if m.get("fxSheet"):
            fx = mid + "_fx"
            fcw, fch = m["cell"]
            fstrip = open_strip(m["fxSheet"], fcw, fch)
            fd2 = os.path.join(OUT, fx)
            os.makedirs(fd2)
            fn = fstrip.size[0] // fcw
            for i in range(fn):
                fstrip.crop((i * fcw, 0, (i + 1) * fcw, fch)).save(os.path.join(fd2, "%s_%d.png" % (fx, i + 1)))
                total += 1
            entry["fx"] = fx
            entry["fxScale"] = sc
            result["fx"][fx] = {"frames": fn, "cell": [fcw, fch], "pivot": [round(ax + c, 2), ay], "anchor": [ax, ay], "scale": sc}
        result["moves"][mid] = entry
    # heavy horizontal = the slash with a 50 px step spread over its time (00_core.js)
    sl = json.loads(json.dumps(result["moves"]["slash"]))
    tot = float(sum(f["ms"] for f in sl["frames"])) or 1.0
    acc = 0.0
    for f in sl["frames"]:
        acc += f["ms"]
        f["root"] = [round(HH_STEP * acc / tot, 2), f["root"][1]]
    sl.update({"title": "Heavy Horizontal", "input": "A+B", "inputType": "chord"})
    result["moves"]["heavy_horizontal"] = sl
    # beams: one tile each, tiled and scrolled by the game
    for kind, b in data["beams"].items():
        im = Image.open(strip_path(b["src"])).convert("RGBA")
        name = "beamtile_" + kind
        d = os.path.join(OUT, name)
        os.makedirs(d)
        im.save(os.path.join(d, name + "_1.png"))
        total += 1
        result["beams"][kind] = {"anim": name, "w": b["w"], "h": b["h"]}
    with open(META, "w") as fh:
        json.dump(result, fh, separators=(",", ":"))
    print("moves %d  fx %d  beams %d  png %d  body c=%.1f w=%d" % (len(result["moves"]), len(result["fx"]), len(result["beams"]), total, c, body_w))


if __name__ == "__main__":
    main()
