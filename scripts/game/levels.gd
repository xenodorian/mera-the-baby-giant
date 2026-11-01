class_name Levels
extends RefCounted
## v0.5 level list (built by tools/build_levels.py into assets/levels/levels.json) and the level being played.
## 1 Sunlit Country, 2 Misty Woods, 3 Moonlit Town, 4 Moonlit Cemetery, 5 Infernal Caverns.
## with invisible walls at both ends and an exit gate at the right end.

const JSON_PATH := "res://assets/levels/levels.json"
const EDGE := 120.0          # Mera / enemies stay this far inside the map ends
const EXIT_PAD := 360.0      # the exit gate stands this far from the right end

static var current := 0      # index into list()
static var _data: Dictionary = {}


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
	return float(data()["map_w"])


static func pad() -> float:
	return float(data()["pad"])
