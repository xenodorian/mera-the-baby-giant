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
const STAGE4_FROM := 20      # stage 4: the king's court (Nerochilde's Court, a solo boss arena)

static var current := 0      # index into list()
static var _data: Dictionary = {}


## 0 for the levels of stage 1, 1 for stage 2, 2 for stage 3 (Changeling), 3 for the king's court
static func stage_of(i: int) -> int:
	if i >= STAGE4_FROM:
		return 3
	if i >= STAGE3_FROM:
		return 2
	return 1 if i >= STAGE2_FROM else 0


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
