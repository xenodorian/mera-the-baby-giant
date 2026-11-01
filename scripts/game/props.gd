class_name Props
extends RefCounted
## v0.8 (S4) breakables, set pieces and secrets (docs/GAME_RULES.md "Breakables" / "Secrets"). Art: assets/props/
## (tools/build_props.py, free CC0 packs + a few pieces drawn in this project). Behaviour: scripts/game/prop.gd.
## Moonlit Cemetery has no props. The other four levels do.

const DIR := "res://assets/props/"
## kind -> [texture, scale, hp, drop tier, break sound]
const KINDS := {
	"candle": ["candle_a.png", 4.0, 1, "small", "glass"],
	"candle_b": ["candle_b.png", 4.0, 1, "small", "glass"],
	"urn": ["urn.png", 5.0, 1, "medium", "glass"],
	"crate": ["crate.png", 5.0, 1, "medium", "wood"],
	"chest": ["chest.png", 5.0, 1, "big", "wood"],
	"barrel": ["barrel.png", 4.0, 1, "", "boom_big"],
	"chandelier": ["chandelier.png", 3.0, 1, "", "glass"],
	"wall": ["wall_cracked.png", 3.0, 4, "", "stone"],
	"lever": ["lever_off.png", 5.0, 1, "", "metal"],
	"door": ["door.png", 4.0, 0, "", "metal"],
	"plank": ["plank.png", 2.5, 0, "", "plank"],
	"ledge": ["plank.png", 2.5, 0, "", "plank"],
}
const HITTABLE := ["candle", "candle_b", "urn", "crate", "chest", "barrel", "chandelier", "wall", "lever"]

const BARREL_DMG := 8             # fixed (never x Mera's size); kind "explosion" -> pierces the Fire Knight's block
const BARREL_R := 300.0           # blast radius (px)
const BARREL_CHAIN_S := 0.14      # a barrel caught in a blast goes off this much later (chain reactions)
const CHANDELIER_DMG := 6         # crushed by a falling chandelier ...
const CHANDELIER_STUN_S := 2.5    # ... and stunned this long
const CHANDELIER_Y := 430.0       # px above the ground where its bottom hangs
const CRUMBLE_S := 0.45           # standing on a crumbling plank this long -> it shakes ...
const CRUMBLE_SHAKE_S := 0.3      # ... then breaks
const CRUMBLE_BACK_S := 6.0       # ... and grows back after this long
const STEP_H := 150.0             # crumbling step height above the ground (1x Mera reaches it with a double jump)
const LEDGE_H := 300.0            # card ledge height
const DROP_P := {"small": 0.7, "medium": 0.9, "big": 1.0}

## secrets per level index: [card index into Allies.CARDS[level], how it's hidden]
## Cemetery (3) has none. Caverns are index 4.
const SECRETS := {
	0: [[0, "wall"], [1, "ledge"], [2, "door"]],
	1: [[0, "wall"], [1, "ledge"], [2, "door"]],
	2: [[0, "door"], [2, "wall"], [3, "ledge"]],
	4: [[1, "ledge"], [2, "door"], [3, "wall"]],
}
const CHANDELIERS := {2: true, 4: true}       # Moonlit Town and Infernal Caverns have something to hang them from
const LEVER_BACK := 620.0                     # the lever for a door stands this far before it


## every prop of a level: [[kind, x, extra], ...] (deterministic: seeded by the level)
static func layout(level: int, map_w: float) -> Array:
	var out: Array = []
	var id := ""
	if level >= 0 and level < Levels.list().size():
		id = String(Levels.list()[level].get("id", ""))
	if id == "cemetery" or id == "dragon_lair":
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = 7700 + level * 131
	var taken: Array = []                          # x ranges kept clear for secrets and cards
	var cards: Array = Allies.CARDS.get(level, [])
	for c in cards:
		taken.append(float(c[0]))
	for sec in SECRETS.get(level, []):
		var cx := float(cards[int(sec[0])][0])
		match String(sec[1]):
			"wall":
				out.append(["wall", cx, {"card": int(sec[0])}])
			"door":
				out.append(["door", cx, {"card": int(sec[0])}])
				out.append(["lever", cx - LEVER_BACK, {"door_x": cx}])
				taken.append(cx - LEVER_BACK)
			"ledge":
				out.append(["ledge", cx, {"card": int(sec[0]), "h": LEDGE_H}])
				out.append(["plank", cx - 300.0, {"h": STEP_H}])
				taken.append(cx - 300.0)
	var x := 1500.0
	var n := 0
	while x < map_w - 1400.0:
		var clear := true
		for t in taken:
			if absf(x - float(t)) < 420.0:
				clear = false
		if clear:
			var roll := rng.randf()
			if n % 5 == 2:
				out.append(["barrel", x, {}])
			elif n % 7 == 4:
				out.append(["chest", x, {}])
			elif roll < 0.35:
				out.append(["candle", x - 70.0, {}])
				out.append(["candle_b", x + 70.0, {}])
			elif roll < 0.65:
				out.append(["urn", x, {}])
				if rng.randf() < 0.5:
					out.append(["urn", x + 90.0, {}])
			else:
				out.append(["crate", x, {}])
				if rng.randf() < 0.4:
					out.append(["crate", x + 120.0, {}])
			n += 1
		x += rng.randf_range(650.0, 1050.0)
	if CHANDELIERS.has(level):
		var cx2 := 2600.0
		while cx2 < map_w - 2000.0:
			out.append(["chandelier", cx2, {}])
			cx2 += rng.randf_range(3300.0, 4300.0)
	return out


static func tex(kind: String) -> Texture2D:
	return load(DIR + String(KINDS[kind][0]))
