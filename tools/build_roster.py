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
                           "tail": ("ansimuz/grotto-escape-2-boss-dragon/sprites/tail", 10, False),
                           "spit": ("ansimuz/grotto-escape-2-boss-dragon/spit-nofire/sprites/spit", 12, False),
                           # v0.8.1 flight loop picked by the user: breath 1, 5, 4, 5 (plume-free copies), looped
                           "fly": (["ansimuz/grotto-escape-2-boss-dragon/spit-nofire/sprites/spit/" + f for f in
                                    ("_0000_Layer-1.png", "_0004_Layer-5.png", "_0003_Layer-4.png", "_0004_Layer-5.png")],
                                   11, True)}),
    "hell_gato": (-1, False, {"run": ("ansimuz/cemetery-hell-gato/Sprites", 10, True)}),
    "skeleton": (-1, False, {"rise": ("ansimuz/cemetery-skeleton/skeleton-rise", 8, False),
                             "walk": ("ansimuz/cemetery-skeleton/Sprites/Walk", 8, True),
                             "rise_clothed": ("ansimuz/cemetery-skeleton/skeleton-rise-clothed", 8, False),
                             "walk_clothed": ("ansimuz/cemetery-skeleton/Sprites/walk-clothed", 8, True)}),
    # v0.10 CC0 itch.io. LuizMelo's pack, plus Stealthix's three standalone sheets.
    "lm_goblin": (1, False, {"idle": ("itch/luizmelo/goblin/idle", 8, True),
                             "move": ("itch/luizmelo/goblin/move", 12, True),
                             "atk": ("itch/luizmelo/goblin/atk", 12, False),
                             "atk2": ("itch/luizmelo/goblin/atk2", 12, False)}),
    "lm_mushroom": (1, False, {"idle": ("itch/luizmelo/mushroom/idle", 8, True),
                               "move": ("itch/luizmelo/mushroom/move", 12, True),
                               "atk": ("itch/luizmelo/mushroom/atk", 12, False),
                               "atk2": ("itch/luizmelo/mushroom/atk2", 12, False)}),
    "lm_skeleton": (1, False, {"idle": ("itch/luizmelo/skeleton/idle", 8, True),
                               "move": ("itch/luizmelo/skeleton/move", 10, True),
                               "atk": ("itch/luizmelo/skeleton/atk", 12, False),
                               "atk2": ("itch/luizmelo/skeleton/atk2", 12, False)}),
    "lm_eye": (1, True, {"fly": ("itch/luizmelo/eye/fly", 12, True),
                         "atk": ("itch/luizmelo/eye/atk", 12, False),
                         "atk2": ("itch/luizmelo/eye/atk2", 12, False)}),
    "sx_zombie": (1, False, {"idle": ("itch/stealthix/zombie/idle", 8, True),
                             "move": ("itch/stealthix/zombie/move", 10, True),
                             "atk": ("itch/stealthix/zombie/atk", 10, False)}),
    "sx_skeleton": (1, False, {"idle": ("itch/stealthix/skeleton/idle", 8, True),
                               "move": ("itch/stealthix/skeleton/move", 10, True),
                               "atk": ("itch/stealthix/skeleton/atk", 10, False)}),
    "sx_witch": (1, False, {"idle": ("itch/stealthix/witch/idle", 8, True),
                            "move": ("itch/stealthix/witch/move", 10, True),
                            "atk": ("itch/stealthix/witch/atk", 10, False),
                            "atk2": ("itch/stealthix/witch/atk2", 10, False)}),
}
# v0.11 Perry + the biboosgba creatures: written by tools/build_perry.py (assets/perry/perry_meta.json), frames under
# assets/characters/perry/<id>/<anim>/. Every anim carries an explicit pivot (the 4th tuple element).
PERRY_META = os.path.join(ROOT, "assets/perry/perry_meta.json")
# Perry Riposte anims the Mera AI never plays (Roster.DEFS): left out of the roster and the export
PERRY_DROP = {"perry": {"parry", "block", "charge"}, "p_percy": {"block", "upHold"}, "p_firemage": {"walk"}}
if os.path.exists(PERRY_META):
    with open(PERRY_META) as fh:
        for _pid, _m in json.load(fh).items():
            E[_pid] = (_m["facing"], False, {_n: ("perry/%s/%s" % (_pid, _n), _a["fps"], _a["loop"], _a["pivot"])
                                             for _n, _a in _m["anims"].items() if _n not in PERRY_DROP.get(_pid, ())})
# Stage 2 (2026-11-02): free frame-animated creatures. Luiz Melo CC0, chierit CC-BY 4.0 (docs/CREDITS.md).
LM = "itch/luizmelo/"
CH2 = "itch/chierit/"
E.update({
    "x_fire_worm": (1, False, {"idle": (LM + "fire_worm/idle", 8, True), "walk": (LM + "fire_worm/walk", 10, True),
                               "attack": (LM + "fire_worm/attack", 12, False), "hurt": (LM + "fire_worm/hurt", 10, False),
                               "death": (LM + "fire_worm/death", 10, False), "fireball": (LM + "fire_worm/fireball", 12, True)}),
    "x_bat": (1, True, {"fly": (LM + "bat/fly", 12, True), "attack": (LM + "bat/attack", 12, False),
                        "hurt": (LM + "bat/hurt", 10, False), "death": (LM + "bat/death", 8, False)}),
    "x_slime": (1, False, {"idle": (LM + "slime/idle", 10, True), "walk": (LM + "slime/walk", 8, True),
                           "attack": (LM + "slime/attack", 14, False), "hurt": (LM + "slime/hurt", 10, False),
                           "death": (LM + "slime/death", 10, False)}),
    "x_mimic": (1, False, {"idle": (LM + "mimic/idle", 8, True), "walk": (LM + "mimic/walk", 8, True),
                           "attack": (LM + "mimic/attack", 14, False), "hurt": (LM + "mimic/hurt", 10, False),
                           "death": (LM + "mimic/death", 8, False)}),
    "x_rat": (1, False, {"idle": (LM + "rat/idle", 10, True), "run": (LM + "rat/run", 14, True),
                         "attack": (LM + "rat/attack", 14, False), "hurt": (LM + "rat/hurt", 10, False),
                         "death": (LM + "rat/death", 10, False)}),
    "x_dark_wizard": (1, False, {"idle": (LM + "evil_wizard_3/idle", 8, True), "walk": (LM + "evil_wizard_3/walk", 10, True),
                                 "attack": (LM + "evil_wizard_3/attack", 12, False), "hurt": (LM + "evil_wizard_3/hurt", 10, False),
                                 "death": (LM + "evil_wizard_3/death", 12, False), "bolt": (LM + "evil_wizard_3/bolt", 14, True)}),
    "x_frost_guardian": (-1, False, {"idle": (CH2 + "frost_guardian/idle", 8, True), "walk": (CH2 + "frost_guardian/walk", 10, True),
                                     "attack": (CH2 + "frost_guardian/attack", 12, False), "hurt": (CH2 + "frost_guardian/hurt", 12, False),
                                     "death": (CH2 + "frost_guardian/death", 12, False)}),
    "x_demon_slime": (-1, False, {"idle": (CH2 + "demon_slime/idle", 8, True), "walk": (CH2 + "demon_slime/walk", 12, True),
                                  "attack": (CH2 + "demon_slime/attack", 14, False), "hurt": (CH2 + "demon_slime/hurt", 12, False),
                                  "death": (CH2 + "demon_slime/death", 12, False)}),
})
# Stage 3 (2026-11-02): the Changeling enemies. Frames: assets/characters/changeling/<id>/<anim>/ (tools/build_changeling.py).
# Only the animations the AI plays are listed. All face right; the pivot is the feet centre of the idle frame.
CL_LOOP = {"idle": 8, "walk": 10, "slash": 12, "thrust": 12, "spellcast": 12, "shoot": 12, "hurt": 8, "jump": 12}
CL_ARROW = "chierit/leaf-ranger/animations/PNG/projectiles_and_effects/arrow"
CL_BOLT = "itch/luizmelo/evil_wizard_3/bolt"


def _cl(src, names, extra=None):
    d = {n: ("changeling/%s/%s" % (src, n), CL_LOOP[n], n in ("idle", "walk")) for n in names}
    d.update(extra or {})
    return (1, False, d)


E.update({
    "cl_grunt": _cl("grunt", ["idle", "walk", "slash", "thrust", "hurt"]),
    "cl_mud": _cl("mud_revenant", ["idle", "walk", "spellcast", "slash", "hurt"]),
    "cl_rat_king": _cl("rat_king", ["idle", "walk", "slash", "jump", "hurt"]),
    "cl_archer": _cl("archer", ["idle", "shoot", "hurt"], {"arrow": (CL_ARROW, 1, True)}),
    "cl_warlord": _cl("warlord", ["idle", "walk", "slash", "thrust", "shoot", "jump", "hurt"], {"arrow": (CL_ARROW, 1, True)}),
    "cl_knight": _cl("knight", ["idle", "walk", "slash", "thrust", "hurt"]),
    "cl_ranger": _cl("ranger", ["idle", "walk", "shoot", "jump", "hurt"], {"arrow": (CL_ARROW, 1, True)}),
    "cl_weaver": _cl("weaver", ["idle", "walk", "shoot", "hurt"]),
    "cl_mage": _cl("mage", ["idle", "walk", "spellcast", "jump", "hurt"], {"bolt": (CL_BOLT, 14, True)}),
})
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
# Stage 3 phase 7: the playable faces as allies. Art keys are "ally_<id>" (the enemy cl_* / boss perry keep their own
# roster entries); scripts/game/allies.gd ART maps the ally id to the key. Merge only these with tools/build_ally_faces.py.
def _face_ally(src):
    d = "changeling/%s/" % src
    return (1, False, {"idle": (d + "idle", 8, True), "walk": (d + "walk", 10, True), "atk1": (d + "slash", 12, False),
                       "atk2": (d + "thrust", 12, False), "cast": (d + "spellcast", 12, False), "shoot": (d + "shoot", 12, False),
                       "hit": (d + "hurt", 10, False), "death": (d + "hurt", 6, False), "jump": (d + "jump", 12, False)})


def _perry_ally():
    path = os.path.join(ROOT, "assets/perry/perry_player.json")
    if not os.path.exists(path):
        return (1, False, {})
    with open(path) as fh:
        pj = json.load(fh)
    mv = pj["moves"]

    def a(move, loop=False):
        m = mv[move]
        ms = sum(f["ms"] for f in m["frames"]) / float(len(m["frames"]))
        return ("perry/player/%s" % move, round(1000.0 / ms, 1), loop, m["pivot"])
    fx = pj["fx"]["energy_wave_fx"]
    return (1, False, {"idle": a("idle", True), "walk": a("walk_right", True), "atk1": a("slash"), "atk2": a("thrust"),
                       "atk3": a("spin_attack"), "sp": a("energy_wave"), "hit": a("parry"), "death": a("parry"),
                       "jump": a("jump"), "wave": ("perry/player/energy_wave_fx", 14, True, fx["pivot"])})


ALLIES.update({"ally_cl_knight": _face_ally("knight"), "ally_cl_ranger": _face_ally("ranger"),
               "ally_cl_weaver": _face_ally("weaver"), "ally_cl_mage": _face_ally("mage"), "ally_perry": _perry_ally()})
BODY = {"death": "walk", "skeleton": "walk"}     # the hurt box / pivot comes from this animation's first frame
FX = {"enemy_death": ("ansimuz/cemetery-enemydeath/Sprites", 12, False)}


def bbox(path):
    im = Image.open(os.path.join(ROOT, path)).convert("RGBA")
    a = im.split()[3].point(lambda v: 255 if v > 40 else 0)
    return im.size, a.getbbox()


def anim_entry(eid, name, src, fps, loop, flyer, pivot=None):
    if isinstance(src, tuple):
        files = cut_sheet(src[1], src[2], eid, name)
    elif isinstance(src, list):                 # an explicit frame list (paths under assets/characters/), repeats allowed
        files = [os.path.join(CH, f) for f in src]
    else:
        files = frames_in(src)
    size, b0 = bbox(files[0])
    if b0 is None:                              # fully transparent first frame: fall back to the frame centre
        b0 = (size[0] // 2, size[1] // 2, size[0] // 2, size[1] // 2)
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
            src, fps, loop, *rest = anims[name]          # optional 4th element: an explicit pivot [x, y]
            explicit = rest[0] if rest else None
            ent = anim_entry(eid, name, src, fps, loop, flyer, explicit)
            # same frame size as the first animation -> share its pivot so poses don't jump (explicit pivots are kept)
            if (explicit is None and base is not None and ent["size"] == base["size"]
                    and name not in ("fireball", "arrow", "arrow_hit", "bolt")):
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
