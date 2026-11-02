#!/usr/bin/env python3
"""Perry and the biboosgba creatures: sprite export from the web game's data.

Reads assets/perry/source/biboo_data.json (dumped from biboosgba web/assets data.js, creatures.js,
duelist.js, mage.js) and the strips copied beside it, and writes one PNG per animation frame to
  assets/characters/perry/<id>/<anim>/<anim>_<n>.png     (n from 1, in play order; repeats are separate files)
plus assets/perry/perry_meta.json (read by tools/build_roster.py).

Only the creatures in ENEMY_KEYS are exported (owner scope: the ones with real frame animation).
Re-run:  python3 tools/build_perry.py   then   python3 tools/build_roster.py
"""
import json, os, shutil
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets/perry/source")
OUT = os.path.join(ROOT, "assets/characters/perry")
META = os.path.join(ROOT, "assets/perry/perry_meta.json")

# source key -> output id (duelist is Percy, firemage is the fire mage)
ENEMY_KEYS = {"goblin": "p_goblin", "orc": "p_orc", "clubogre": "p_clubogre", "mirrormax": "p_mirrormax",
              "duelist": "p_percy", "firemage": "p_firemage"}

# Perry anim name -> move key in data.js
PERRY_MOVES = [("idle", "idle"), ("walk", "walk_right"), ("slash", "slash"), ("thrust", "thrust"),
               ("upswing", "upswing"), ("heavy", "heavy"), ("spin", "spin_attack"), ("dash", "dash"),
               ("energy_wave", "energy_wave"), ("jump_crash", "jump_crash"), ("parry", "parry"),
               ("block", "block"), ("taunt", "taunt"), ("recover", "recover"), ("charge", "charge"),
               ("sky_dash", "sky_dash"), ("meteor_shower", "meteor_shower"), ("push_kick", "push_kick"),
               ("heavy_kick", "heavy_kick")]

# Facing: enemies are drawn facing left (-1). Percy (p_percy) is the exception: duelist.js says "Not flipped",
# and on the art his slash strikes (cells 13, 8, 14) reach to the RIGHT edge while the idle sword hangs down-right,
# so the sprite faces right (+1). Confirm in game before relying on it.
FACING = {"p_percy": 1, "perry": 1}
FX_FPS = 16


def strip_path(src):
    """'assets/enemies/goblin.png' -> <SRC>/enemies/goblin.png (the copy keeps the subfolder names)."""
    rel = src[len("assets/"):] if src.startswith("assets/") else src
    return os.path.join(SRC, rel)


def open_strip(src, cw, ch):
    im = Image.open(strip_path(src)).convert("RGBA")
    assert im.size[1] == ch, "%s height %d != cell %d" % (src, im.size[1], ch)
    assert im.size[0] % cw == 0, "%s width %d not a multiple of %d" % (src, im.size[0], cw)
    return im


def cell(strip, i, cw, ch):
    return strip.crop((i * cw, 0, (i + 1) * cw, ch))


def opaque_bbox(im):
    """Opaque bbox (alpha > 40), PIL style: right and bottom are exclusive. None if fully transparent."""
    return im.split()[3].point(lambda v: 255 if v > 40 else 0).getbbox()


def body_offset(idle_img, anchor_x):
    """c = (opaque bbox centre x of the idle first frame) - idle anchor x. 0 with a warning if the frame is empty."""
    b = opaque_bbox(idle_img)
    if b is None:
        print("  warning: empty idle first frame, body offset 0")
        return 0.0
    return (b[0] + b[2]) / 2.0 - anchor_x


def fps_of(ms_list):
    mean = sum(ms_list) / float(len(ms_list))
    return max(4, min(30, int(round(1000.0 / mean))))


def write_anim(anims, id_, name, imgs, fps, loop, pivot, active, cw, ch):
    """Write one PNG per frame and record the anim in anims (the meta dict's "anims")."""
    d = os.path.join(OUT, id_, name)
    os.makedirs(d, exist_ok=True)
    for n, im in enumerate(imgs, 1):
        im.save(os.path.join(d, "%s_%d.png" % (name, n)))
    anims[name] = {"frames": len(imgs), "fps": fps, "loop": bool(loop),
                   "pivot": [round(pivot[0], 2), round(pivot[1], 2)], "cell": [cw, ch], "active": active}


def build_enemy(id_, e):
    cw, ch = e["cell"]
    ax, ay = e["anchor"]
    strip = open_strip(e["sheet"], cw, ch)
    frames = e["frames"]
    # The game draws enemy cell k = anims[anim].frames[step] (an index into the frame list); frame "src" is not
    # used by the drawing code (15_draw_scenery.js blit(img[T.sheet].im, cell * cw, ...)), so that is the strip cell.
    n_cells = strip.size[0] // cw
    c = body_offset(cell(strip, e["anims"]["idle"]["frames"][0], cw, ch), ax)
    px = ax + c                                   # body centre, the same in every anim of this creature
    anims = {}
    order = ["idle"] + [n for n in e["anims"] if n != "idle"]
    for name in order:
        a = e["anims"][name]
        seq = a["frames"]                         # indices into the frame list, play order (repeats allowed)
        assert all(i < n_cells for i in seq), "%s %s: cell index past the %d-cell strip" % (id_, name, n_cells)
        imgs = [cell(strip, i, cw, ch) for i in seq]
        active = [p for p, i in enumerate(seq) if frames[i].get("hit") is not None]
        fps = fps_of([frames[i]["ms"] for i in seq])
        write_anim(anims, id_, name, imgs, fps, a["loop"], (px, ay), active, cw, ch)
    return {"facing": FACING.get(id_, -1), "anims": anims, "title": e.get("title", id_), "ai": e.get("ai")}


def build_perry(data):
    moves = data["moves"]
    idle = moves["idle"]
    cw0, ch0 = idle["cell"]
    strip0 = open_strip(idle["sheet"], cw0, ch0)
    c = body_offset(cell(strip0, 0, cw0, ch0), idle["anchor"][0])
    anims = {}
    for anim, mk in PERRY_MOVES:
        if mk not in moves:
            print("  skip perry %s: no move %s" % (anim, mk))
            continue
        m = moves[mk]
        cw, ch = m["cell"]
        ax, ay = m["anchor"]
        strip = open_strip(m["sheet"], cw, ch)
        frs = m["frames"]                         # frame i is cell i of the strip
        imgs = [cell(strip, i, cw, ch) for i in range(len(frs))]
        active = [p for p, f in enumerate(frs) if f.get("hits") is not None]
        fps = fps_of([f["ms"] for f in frs])
        write_anim(anims, "perry", anim, imgs, fps, m["loop"], (ax + c, ay), active, cw, ch)
    # FX strips: the game draws fx cell k at the move's own cell width (cw = m.cell[0]) and height m.cell[1]
    for anim, mk in [("wave_fx", "energy_wave"), ("meteor_fx", "meteor_shower")]:
        m = moves[mk]
        cw, ch = m["cell"]
        strip = open_strip(m["fxSheet"], cw, ch)
        imgs = [cell(strip, i, cw, ch) for i in range(strip.size[0] // cw)]
        write_anim(anims, "perry", anim, imgs, FX_FPS, False, (cw / 2.0, ch / 2.0), [], cw, ch)
    return {"facing": FACING["perry"], "anims": anims, "title": "Perry", "ai": None}


def build_fx(anims, id_, anim, src, cw, ch, loop):
    """A centre-pivot FX strip (duelist energy, mage blast). Every cell is cw wide."""
    strip = open_strip(src, cw, ch)
    imgs = [cell(strip, i, cw, ch) for i in range(strip.size[0] // cw)]
    write_anim(anims, id_, anim, imgs, FX_FPS, loop, (cw / 2.0, ch / 2.0), [], cw, ch)


def main():
    with open(os.path.join(SRC, "biboo_data.json")) as fh:
        data = json.load(fh)
    if os.path.isdir(OUT):
        shutil.rmtree(OUT)                        # rebuild from scratch: no stale frames
    os.makedirs(OUT, exist_ok=True)
    result = {"perry": build_perry(data)}
    for key, id_ in ENEMY_KEYS.items():
        meta = build_enemy(id_, data["enemies"][key])
        if id_ == "p_percy":
            build_fx(meta["anims"], id_, "energy", "duelist/energy.png", 395, 14, True)
        if id_ == "p_firemage":
            build_fx(meta["anims"], id_, "blast", "mage/blast.png", 100, 96, False)
        result[id_] = meta
    with open(META, "w") as fh:
        json.dump(result, fh, indent=1)
    for id_, m in result.items():
        print("%-10s facing %+d  %s" % (id_, m["facing"], ", ".join("%s:%d" % (k, v["frames"]) for k, v in m["anims"].items())))


if __name__ == "__main__":
    main()
