class_name Levels
extends RefCounted
## v0.5 level list (built by tools/build_levels.py into assets/levels/levels.json) and the level being played.
## 1 Sunlit Country, 2 Misty Woods, 3 Moonlit Town, 4 Moonlit Cemetery, 5 Infernal Caverns, 6 Dragon's Lair (stage 1);
## 7 Mossy Falls, 8 Sunstone Canyon, 9 Sunset Shore, 10 Mire Wood, 11 Moonlit Sanctum (stage 2: the island).
## with invisible walls at both ends and an exit gate at the right end.

const JSON_PATH := "res://assets/levels/levels.json"
const EDGE := 120.0          # Mera / enemies stay this far inside the map ends
const EXIT_PAD := 360.0      # the exit gate stands this far from the right end

const STAGE2_FROM := 6       # the first level index of stage 2
const STAGE3_FROM := 12      # the first level index of stage 3 (the Changeling maps; 11 is Perry's Arena, the last of stage 2)
const STAGE4_FROM := 19      # stage 4: the nine new maps (s4_drowned .. s4_gate; the Black Knight ends it at STAGE5_FROM - 1)
const STAGE5_FROM := 29      # the last stage: the Warlord's Throne (finale, opens the court), then Nerochilde's Court (the final boss)
## the Warlord's Throne and the king's court follow from STAGE5_FROM (inserting a level before them is a one-number edit above)
const STAGE_FROM := [0, STAGE2_FROM, STAGE3_FROM, STAGE4_FROM, STAGE5_FROM]   # first level index of each stage (stage_of is the position)
const THRONE := STAGE5_FROM
const COURT := STAGE5_FROM + 1
const BLACK_KNIGHT := STAGE5_FROM - 1   # the end-of-stage mini-boss level of the second to last stage

static var current := 0      # index into list()
static var _data: Dictionary = {}


## 0 for the levels of stage 1, 1 stage 2, 2 the Changeling stage, 3 the new stage, 4 the last stage (Throne and Court)
static func stage_of(i: int) -> int:
	var s := 0
	for k in STAGE_FROM.size():
		if i >= int(STAGE_FROM[k]):
			s = k
	return s


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(JSON_PATH, FileAccess.READ)
		_data = JSON.parse_string(f.get_as_text())
	return _data


static func list() -> Array:
	return data()["levels"]


static func level(i: int = -1) -> Dictionary:
	var ls := list()
	return ls[clampi(current if i < 0 else i, 0, ls.size() - 1)]


static func map_w() -> float:
	var lv := level()
	if lv.has("map_w"):
		return float(lv["map_w"])
	return float(data()["map_w"])


static func pad() -> float:
	return float(data()["pad"])
