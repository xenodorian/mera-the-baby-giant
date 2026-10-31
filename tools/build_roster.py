#!/usr/bin/env python3
"""v0.6 enemy roster manifest: assets/enemies/roster.json

For every enemy and animation it lists the frame PNGs (res:// paths to the original pack files; nothing is copied
except frames that only exist inside a sprite sheet, which are cut into assets/enemies/<id>/), plus per frame
the opaque-pixel box relative to the animation pivot (feet centre for ground enemies, body centre for flyers),
in native pixels, as the art faces natively. The game turns those boxes into hurt boxes (idle frame 0) and
attack boxes (the active frames of an attack). Re-run after changing a pack:  python3 tools/build_roster.py
"""
import json, os, re
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CH = "assets/characters/"
OUT = "assets/enemies/"


def nat(s):
    return [int(t) if t.isdigit() else t for t in re.split(r"(\d+)", s)]


def frames_in(d):
    p = os.path.join(ROOT, CH, d)
    return [os.path.join(CH, d, f) for f in sorted(os.listdir(p), key=nat) if f.endswith(".png")]


def cut_sheet(sheet, n, eid, name):
    im = Image.open(os.path.join(ROOT, CH, sheet)).convert("RGBA")
    w = im.size[0] // n
    out = []
    os.makedirs(os.path.join(ROOT, OUT, eid), exist_ok=True)
    for i in range(n):
        rel = os.path.join(OUT, eid, "%s_%d.png" % (name, i + 1))
        im.crop((i * w, 0, (i + 1) * w, im.size[1])).save(os.path.join(ROOT, rel))
        out.append(rel)
    return out


# id: facing (+1 right / -1 left as drawn), flyer, {anim: (source, fps, loop)}
# source: a folder under assets/characters, or ("sheet", path, n)
E = {
    "minotaur": (-1, False, {"idle": ("chierit/minotaur/animations/idle", 10, True),
                            "walk": ("chierit/minotaur/animations/walk", 10, True),
                            "atk": ("chierit/minotaur/animations/atk_1", 12, False)}),
    "ogre": (-1, False, {"idle": ("ansimuz/ogre/Sprites/Idle", 6, True),
                         "walk": ("ansimuz/ogre/Sprites/walk", 8, True),
                         "atk": ("ansimuz/ogre/Sprites/Attack", 10, False),
                         "idle_unarmed": ("ansimuz/ogre/Sprites/idle-unarmed", 6, True),
                         "walk_unarmed": ("ansimuz/ogre/Sprites/walk-unarmed", 10, True)}),
    "werewolf": (1, False, {"idle": ("ansimuz/werewolf/Sprites/Idle", 8, True),
                            "run": ("ansimuz/werewolf/Sprites/run", 12, True),
                            "jump": ("ansimuz/werewolf/Sprites/jump", 8, True),
                            "fall": ("ansimuz/werewolf/Sprites/fall", 8, True)}),
    "wolf": (1, False, {"run": (("sheet", "ansimuz/wolf-runing-cycle/spritesheets/wolf-runing-cycle.png", 4), 12, True),
                        "run_skin": (("sheet", "ansimuz/wolf-runing-cycle/spritesheets/wolf-runing-cycle-skin.png", 4), 12, True)}),
    "hell_hound": (-1, False, {"idle": ("ansimuz/hell-hound/Sprites/Idle", 10, True),
                               "walk": ("ansimuz/hell-hound/Sprites/Walk", 12, True),
                               "run": ("ansimuz/hell-hound/Sprites/Run", 12, True),
                               "jump": ("ansimuz/hell-hound/Sprites/Jump", 10, False)}),
    "hell_beast": (-1, False, {"idle": ("ansimuz/hell-beast/Idle/Sprites", 8, True),
                               "breath": ("ansimuz/hell-beast/Breath/Sprites", 8, False),
                               "burn": ("ansimuz/hell-beast/Burn/Sprites", 8, False),
                               "fireball": ("ansimuz/hell-beast/Fireball/Sprites", 12, True)}),
    "demon": (-1, True, {"idle": ("ansimuz/demon/Sprites/Idle", 8, True),
                         "atk": ("ansimuz/demon/Sprites/DemonAttack", 14, False),
                         "breath": ("ansimuz/demon/Sprites/DemonAttackBreath", 14, False)}),
    "flying_eye": (1, True, {"fly": ("ansimuz/flying-eye-demon/Sprites", 12, True)}),
    "death": (1, False, {"rise": ("ansimuz/death/Sprites/rise", 10, False),
                         "walk": ("ansimuz/death/Sprites/walk", 8, True),
                         "walk_nolamp": ("ansimuz/death/Sprites/No-lamp-walk", 10, True)}),
    "nightmare": (-1, False, {"idle": ("ansimuz/nightmare/Sprites/Idle", 6, True),
                              "run": ("ansimuz/nightmare/Sprites/Run", 10, True)}),
    "ghost": (1, True, {"float": ("ansimuz/enemy-ghost/Sprites/no-particles", 8, True),
                        "haunt": ("ansimuz/enemy-ghost/Sprites/Particles", 10, True)}),
    "fire_skull": (-1, True, {"fire": ("ansimuz/fire-skull/Sprites/Fire", 12, True),
                              "nofire": ("ansimuz/fire-skull/Sprites/NoFire", 6, True)}),
    "mutant_toad": (1, False, {"idle": ("ansimuz/mutant-toad/Sprites/idle", 6, True),
                               "jump": ("ansimuz/mutant-toad/Sprites/jump", 8, False),
                               "atk": ("ansimuz/mutant-toad/Sprites/attack", 8, False)}),
    "dragon": (-1, False, {"idle": ("ansimuz/grotto-escape-2-boss-dragon/sprites/idle", 8, True),
                           "breath": ("ansimuz/grotto-escape-2-boss-dragon/sprites/breath", 8, False),
                           "tail": ("ansimuz/grotto-escape-2-boss-dragon/sprites/tail", 10, False)}),
    "hell_gato": (-1, False, {"run": ("ansimuz/cemetery-hell-gato/Sprites", 10, True)}),
    "skeleton": (-1, False, {"rise": ("ansimuz/cemetery-skeleton/skeleton-rise", 8, False),
                             "walk": ("ansimuz/cemetery-skeleton/Sprites/Walk", 8, True),
                             "rise_clothed": ("ansimuz/cemetery-skeleton/skeleton-rise-clothed", 8, False),
                             "walk_clothed": ("ansimuz/cemetery-skeleton/Sprites/walk-clothed", 8, True)}),
}
WP = "chierit/water-priestess/png/"
LR = "chierit/leaf-ranger/animations/PNG/"
BG = "ansimuz/brawler-girl/skin-recolor/sprites/"
DG = "ansimuz/dancing-girl/skin-recolor/sprites/"   # v0.8 natural skin: tools/recolor_dancer_skin.py
# v0.7 allies (same manifest format; scripts/game/allies.gd + ally.gd)
ALLIES = {
    "priestess": (1, False, {"idle": (WP + "01_idle", 10, True), "walk": (WP + "02_walk", 12, True), "surf": (WP + "03_surf", 12, True),
                             "j_up": (WP + "04_j_up", 10, True), "j_down": (WP + "05_j_down", 10, True), "tumble": (WP + "06_tumble", 14, False),
                             "atk1": (WP + "07_1_atk", 14, False), "atk2": (WP + "08_2_atk", 16, False), "atk3": (WP + "09_3_atk", 16, False),
                             "sp": (WP + "10_sp_atk", 16, False), "heal": (WP + "11_heal", 12, False), "defend": (WP + "12_defend", 12, False),
                             "hit": (WP + "13_take_hit", 12, False), "death": (WP + "14_death", 12, False), "air": (WP + "air_atk", 14, False)}),
    "ranger": (1, False, {"idle": (LR + "idle", 12, True), "run": (LR + "run", 14, True), "jump": (LR + "jump_full", 16, False),
                          "j_up": (LR + "jump_up", 10, True), "j_down": (LR + "jump_down", 10, True), "roll": (LR + "roll", 14, False),
                          "slide": (LR + "slide", 14, False), "slide_loop": (LR + "slide_loop", 12, True),
                          "atk1": (LR + "1_atk", 14, False), "atk2": (LR + "2_atk", 14, False), "atk3": (LR + "3_atk", 14, False),
                          "sp": (LR + "sp_atk", 14, False), "air": (LR + "air_atk", 18, False), "defend": (LR + "defend", 14, False),
                          "defend_pose": (LR + "defend_pose", 1, True), "hit": (LR + "take_hit", 12, False), "death": (LR + "death", 12, False),
                          "arrow": (LR + "projectiles_and_effects/arrow", 1, True), "arrow_hit": (LR + "projectiles_and_effects/arrow_hit", 14, False)}),
    "brawler": (1, False, {"idle": (BG + "Idle", 8, True), "walk": (BG + "Walk", 12, True), "jab": (BG + "Jab", 12, False),
                           "punch": (BG + "Punch", 12, False), "kick": (BG + "Kick", 12, False), "jump": (BG + "Jump", 8, False),
                           "jump_kick": (BG + "Jump_kick", 10, False), "dive_kick": (BG + "Dive_kick", 12, False), "hurt": (BG + "Hurt", 8, False)}),
    "dancer": (1, False, {"skip": (DG + "Skip", 10, True), "hips": (DG + "hips", 8, True), "snap": (DG + "snap", 8, True),
                          "balancing": (DG + "Balancing", 8, True), "slide": (DG + "slide", 8, True)}),
}
BODY = {"death": "walk", "skeleton": "walk"}     # the hurt box / pivot comes from this animation's first frame
FX = {"enemy_death": ("ansimuz/cemetery-enemydeath/Sprites", 12, False)}


def bbox(path):
    im = Image.open(os.path.join(ROOT, path)).convert("RGBA")
    a = im.split()[3].point(lambda v: 255 if v > 40 else 0)
    return im.size, a.getbbox()


def anim_entry(eid, name, src, fps, loop, flyer, pivot=None):
    if isinstance(src, tuple):
        files = cut_sheet(src[1], src[2], eid, name)
    else:
        files = frames_in(src)
    size, b0 = bbox(files[0])
    if pivot is None:
        if flyer:
            pivot = [(b0[0] + b0[2]) / 2.0, (b0[1] + b0[3]) / 2.0]
        else:
            pivot = [(b0[0] + b0[2]) / 2.0, float(b0[3])]
    boxes = []
    for f in files:
        _, b = bbox(f)
        if b is None:
            boxes.append([0, 0, 0, 0])
        else:
            boxes.append([b[0] - pivot[0], b[1] - pivot[1], b[2] - pivot[0], b[3] - pivot[1]])
    return {"frames": ["res://" + f for f in files], "fps": fps, "loop": loop, "size": list(size),
            "pivot": pivot, "boxes": boxes}


def main():
    out = {}
    for eid, (face, flyer, anims) in list(E.items()) + list(ALLIES.items()):
        e = {"facing": face, "flyer": flyer, "anims": {}}
        base = None
        first = BODY.get(eid, next(iter(anims)))
        order = [first] + [n for n in anims if n != first]
        for name in order:
            src, fps, loop = anims[name]
            ent = anim_entry(eid, name, src, fps, loop, flyer)
            # same frame size as the first animation -> share its pivot so poses don't jump
            if base is not None and ent["size"] == base["size"] and name not in ("fireball", "arrow", "arrow_hit"):
                ent = anim_entry(eid, name, src, fps, loop, flyer, base["pivot"])
            if base is None:
                base = ent
            e["anims"][name] = ent
        e["anims"] = {n: e["anims"][n] for n in anims}
        b = base["boxes"][0]
        e["body"] = b
        out[eid] = e
        print("%-12s body %3dx%-3d  anims %s" % (eid, b[2] - b[0], b[3] - b[1], ", ".join(
            "%s:%d" % (k, len(v["frames"])) for k, v in e["anims"].items())))
    out["_fx"] = {k: anim_entry("fx", k, s, f, l, True) for k, (s, f, l) in FX.items()}
    with open(os.path.join(ROOT, OUT, "roster.json"), "w") as fh:
        json.dump(out, fh, indent=1)


if __name__ == "__main__":
    main()
