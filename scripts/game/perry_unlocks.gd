class_name PerryUnlocks
extends RefCounted
## Perry's unlock list, ported from BibooSGBA web/progress.js (UNLOCKS, PRICE, P.has / hasMove / buttonOn / meterOn).
## Prices are the original's, paid in gold instead of leaves: a scroll costs 15 + 10 * level, a mutagen 25 + 15 * level.
## An unlock is a mutagen when it uses a meter (energy, empower, super) or is meter_charge. Bone Powder (+25 max HP,
## up to 200) costs 90. Owned ids live in Carry.perry_owned, max HP in Carry.perry_hp_max (saved with Carry).
## "level" is the Perry level that sold the unlock. It opens once Stage 2 level (5 + level, at most 10) is cleared:
## level 1 -> level index 6 (Stage 2 level 1) ... level 5 -> index 10 (Moonlit Sanctum).

const POWDER_ID := "bone_powder"
const POWDER_PRICE := 90
const SHOULDERS := ["L1", "L2", "R1", "R2", "R"]
## moves she has from the start (BASE_MOVES in 00_core.js); double_jump is always on
const BASE_MOVES := ["idle", "walk_right", "walk_left", "duck", "block", "parry", "jump", "dash", "slash", "spin_attack"]

const LIST := [
	{"id": "thrust", "level": 1, "kind": "Combo", "name": "Lunging Thrust", "hint": "Hold Right (or Left) and press A to lunge", "moves": ["thrust"]},
	{"id": "upswing", "level": 1, "kind": "Combo", "name": "Ducking Upswing", "hint": "Hold Down and press A", "moves": ["upswing"]},
	{"id": "heavy_horizontal", "level": 1, "kind": "Combo", "name": "Heavy Horizontal", "hint": "Hold B and tap A", "moves": ["heavy_horizontal"]},
	{"id": "dash_thrust", "level": 1, "kind": "Combo", "name": "Dash Thrust", "hint": "Press X and A together", "moves": ["dash_thrust"]},
	{"id": "energy_dash", "level": 2, "kind": "Combo", "name": "Energy Dash Thrust", "hint": "Double tap forward, then hold X and A and let go", "moves": ["energy_dash_thrust"], "meters": ["energy"]},
	{"id": "taunt", "level": 2, "kind": "Combo", "name": "Taunt", "hint": "Press X and Y together", "moves": ["taunt"]},
	{"id": "sky_dash", "level": 1, "kind": "Combo", "name": "Sky Dash", "hint": "Press Down, then Up", "moves": ["sky_dash"]},
	{"id": "crash", "level": 3, "kind": "Combo", "name": "Jumping Crash", "hint": "Press A in the air (30 energy)", "moves": ["jump_crash"], "meters": ["energy"]},
	{"id": "heavy_chop", "level": 3, "kind": "Combo", "name": "Heavy Overhead Chop", "hint": "Hold A to charge, release to chop", "moves": ["heavy", "charge"], "meters": ["energy"]},
	{"id": "earthquake", "level": 5, "kind": "Combo", "name": "Earthquake", "hint": "Down four times, then A (full super meter)", "moves": ["earthquake"], "meters": ["super"]},
	{"id": "meteor", "level": 5, "kind": "Combo", "name": "Meteor Shower", "hint": "B five times (full super meter)", "moves": ["meteor_shower"], "meters": ["super"]},
	{"id": "push_kick", "level": 1, "kind": "Button", "name": "L1 button: Push Kick", "hint": "Press L1 for the push kick", "moves": ["push_kick"], "buttons": ["L1"]},
	{"id": "meter_charge", "level": 5, "kind": "Combo", "name": "Meter Charge", "hint": "Hold L1+R1: every meter you own slowly fills", "moves": ["meter_charge"], "buttons": ["L1", "R1"]},
	{"id": "recover", "level": 2, "kind": "Button", "name": "R1 button: Recover", "hint": "Hold R1 to kneel and heal (uses empower)", "moves": ["recover"], "buttons": ["R1", "R"], "meters": ["empower"]},
	{"id": "empower_beam", "level": 2, "kind": "Combo", "name": "Empowerment Beam", "hint": "Press A+R1 (uses empower)", "moves": ["beam_plasma"], "buttons": ["R1"], "meters": ["empower"]},
	{"id": "energy_kick", "level": 2, "kind": "Combo", "name": "Energy Kick", "hint": "Hold B+L1 to charge, let go to kick", "moves": ["energy_kick"], "buttons": ["L1"], "meters": ["energy"]},
	{"id": "energy_burst", "level": 2, "kind": "Button", "name": "L2 button: Energy Burst", "hint": "Hold L2 to charge, let go to burst", "moves": ["energy_burst"], "buttons": ["L2"], "meters": ["energy"]},
	{"id": "energy_wave", "level": 2, "kind": "Button", "name": "R2 button: Energy Wave", "hint": "Hold R2 to charge, let go to fire the wave", "moves": ["energy_wave"], "buttons": ["R2"], "meters": ["energy"]},
	{"id": "cloud_beam", "level": 2, "kind": "Combo", "name": "Cloud Beam", "hint": "Press A+L2 (uses energy)", "moves": ["beam_cloud"], "buttons": ["L2"], "meters": ["energy"]},
	{"id": "laser_beam", "level": 3, "kind": "Combo", "name": "Laser Beam", "hint": "Press A+L1 (uses energy)", "moves": ["beam_laser"], "buttons": ["L1"], "meters": ["energy"]},
	{"id": "fire_beam", "level": 3, "kind": "Combo", "name": "Fire Beam", "hint": "Press A+R2 (uses energy)", "moves": ["beam_fire"], "buttons": ["R2"], "meters": ["energy"]},
	{"id": "chain", "level": 4, "kind": "Combo", "name": "Attack Chain", "hint": "Mash A for chain", "moves": ["chain2", "chain3", "chain4"], "meters": ["energy"]},
	{"id": "chain_burst", "level": 4, "kind": "Combo", "name": "Burst Chain", "hint": "A x4 then B", "moves": [], "meters": ["energy"]},
	{"id": "fly", "level": 4, "kind": "Combo", "name": "Flight", "hint": "A, B, A, B, then Up", "moves": []},
	{"id": "rainbow", "level": 4, "kind": "Combo", "name": "Rainbow Guard", "hint": "A, B, A, B, A, B", "moves": []},
	{"id": "ultimate", "level": 4, "kind": "Combo", "name": "Ultimate Chain", "hint": "A x4 then shoulders", "moves": ["ultimate"], "buttons": ["L1", "L2", "R1", "R2"], "meters": ["energy", "empower"]},
]

static var _by: Dictionary = {}


static func by_id(id: String):
	if _by.is_empty():
		for u in LIST:
			_by[String(u["id"])] = u
	return _by.get(id, null)


## "mutagen" when it uses a meter (or is meter_charge), otherwise "scroll"
static func shop_kind(u: Dictionary) -> String:
	if not (u.get("meters", []) as Array).is_empty() or String(u["id"]) == "meter_charge":
		return "mutagen"
	return "scroll"


static func price(id: String) -> int:
	if id == POWDER_ID:
		return POWDER_PRICE
	var u = by_id(id)
	if u == null:
		return 0
	var lv := int(u["level"])
	return 25 + 15 * lv if shop_kind(u) == "mutagen" else 15 + 10 * lv


## the Stage 2 level index that must be cleared before an unlock opens (5 + level, at most 10)
static func req_index(id: String) -> int:
	var u = by_id(id)
	if u == null:
		return Carry.PERRY_CLEAR_LEVEL
	return mini(5 + int(u["level"]), Carry.PERRY_CLEAR_LEVEL)


static func req_cleared(id: String) -> bool:
	Carry.ensure()
	return int(Carry.clears.get(str(req_index(id)), 0)) > 0


## "" when it can be bought now, otherwise why not
static func locked_reason(id: String) -> String:
	if id == POWDER_ID:
		return ""
	if by_id(id) == null:
		return "unknown"
	if not req_cleared(id):
		return "Clear Stage 2 level %d first" % (req_index(id) - Levels.STAGE2_FROM + 1)
	return ""


static func owned(id: String) -> bool:
	Carry.ensure()
	return bool(Carry.perry_owned.get(id, false))


## the original P.has: double_jump is always on
static func has(id: String) -> bool:
	return id == "double_jump" or owned(id)


static func has_move(move: String) -> bool:
	if move == "double_jump" or move in BASE_MOVES:
		return true
	for u in LIST:
		if owned(String(u["id"])) and move in (u.get("moves", []) as Array):
			return true
	return false


## a shoulder button that no owned unlock lists is off (P.buttonOn); the face buttons and the d-pad are always on
static func button_on(b: String) -> bool:
	if b not in SHOULDERS:
		return true
	for u in LIST:
		if owned(String(u["id"])) and b in (u.get("buttons", []) as Array):
			return true
	return false


static func meter_on(m: String) -> bool:
	for u in LIST:
		if owned(String(u["id"])) and m in (u.get("meters", []) as Array):
			return true
	return false


## "" on success, otherwise "gold", "owned", "locked", "max" or "bad"
static func buy(id: String) -> String:
	Carry.ensure()
	if id == POWDER_ID:
		if Carry.perry_hp_max >= Tuning.PERRY_HP_CAP:
			return "max"
		if Carry.gold < POWDER_PRICE:
			return "gold"
		Carry.gold -= POWDER_PRICE
		Carry.perry_hp_max = mini(Carry.perry_hp_max + Tuning.PERRY_HP_STEP, Tuning.PERRY_HP_CAP)
		Carry.save()
		return ""
	if by_id(id) == null:
		return "bad"
	if owned(id):
		return "owned"
	if locked_reason(id) != "":
		return "locked"
	var p := price(id)
	if Carry.gold < p:
		return "gold"
	Carry.gold -= p
	Carry.perry_owned[id] = true
	Carry.save()
	return ""
