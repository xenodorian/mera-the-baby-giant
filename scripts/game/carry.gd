class_name Carry
extends RefCounted
## Gold, shop caps, and the inventory that survives levels and deaths.
## Title shop and the game both read this file. Reset wipes it and the old run file.

const PATH := "user://mera_carry.json"
const RUN_PATH := "user://mera_run.json"

const POTION_CAP_0 := 5
const MANA_POTION_CAP_0 := 5
const CARD_CAP_0 := 3
const SCALE_CAP_0 := 3
const SCALE_CAP_MAX := 6        # Mera never grows past 6x: size makes her so strong that the second stage was too easy
const POTION_CAP_MAX := 12
const MANA_POTION_CAP_MAX := 12
const CARD_CAP_MAX := 9
const STAMINA_0 := 60.0
const RAGE_0 := 100.0
const STAMINA_CAP := 200.0
const RAGE_CAP := 200.0
const STAMINA_STEP := 20.0
const RAGE_STEP := 25.0

const PRICE_POTION_CAP := 40
const PRICE_MANA_CAP := 40
const PRICE_CARD_CAP := 70
const PRICE_CARD := 25
const PRICE_FURY := 50
const PRICE_MANA_BAR := 50
const PRICE_SCALE := 90
const PRICE_KEY := 200
const PRICE_RESPAWN := 200

const ALLIES := ["priestess", "ranger", "brawler", "dancer", "cl_knight", "cl_ranger", "cl_weaver", "perry"]

## v0.12.2 unlocks (shop page 2). Moves start locked; buy them in the shop.
const MOVE_IDS := ["beam", "earthquake", "super_quake", "rear", "fury_mode", "homing"]
const PRICE_MOVE := {"beam": 150, "earthquake": 120, "super_quake": 220, "rear": 100, "fury_mode": 250, "homing": 160}
const SUMMON_S := [30.0, 60.0, 90.0, 120.0]     # how long a summoned ally stays: tier 0 is the base
const PRICE_SUMMON := [90, 160, 240]            # the price of tier 1, 2, 3 (bought in order)
static var moves: Dictionary = {}               # move id -> true once bought
static var summon_tier := 0
static var test_all := false                    # tests: every unlock counts as owned
static var test_scale_cap := 9                  # tests: the size cap while test_all is on (a test about the cap sets its own)
static var test_homing := false                 # tests: homing shots on

static var gold := 0
static var potion_cap := POTION_CAP_0
static var mana_potion_cap := MANA_POTION_CAP_0
static var card_cap := CARD_CAP_0
static var scale_cap := SCALE_CAP_0
static var stamina_max := STAMINA_0
static var rage_max := RAGE_0
static var potions := 1
static var mana_pots := 0
static var cards: Dictionary = {}
static var stamina := STAMINA_0
static var rage := 0.0
static var size := 2
static var unlocked := 0       # highest stage index she may play. 0 = stage 1 only. Later stages stay locked.
static var ready := false
static var clears: Dictionary = {}   # level index (as a string key) -> times cleared. Pays gold on every clear.
const CLEAR_GOLD_FIRST := 15         # first clear of a level
const CLEAR_GOLD_REPEAT := 5         # each clear after that

## Perry becomes playable once Perry's Arena is cleared (level index 10)
const PERRY_CLEAR_LEVEL := 10
static var character := "mera"                  # "mera" | "perry": the player the title menu chose (Perry only counts while unlocked)
static var respawn := false                     # shop: 200 gold. A death plays the reaper duel and a win puts her back where she fell.
static var perry_owned: Dictionary = {}         # Perry unlock id -> true (scripts/game/perry_unlocks.gd)
static var perry_hp_max := Tuning.PERRY_HP_START
static var story_seen: Dictionary = {}          # cutscene key -> true once shown (scripts/game/cutscene.gd)
static var prisoners: Dictionary = {}           # level index (as a string key) -> true once freed (scripts/game/prisoner.gd)
static var perry_freed := false                 # Perry was freed from the king's spell (free_perry, once)

## Level-list layout of the save. A save stores per-level data keyed by level index ("clears", "prisoners") and "unlocked";
## when levels are inserted into assets/levels/levels.json the old indices move. Each row is [version, from_index, shift]:
## a save older than `version` has every index >= from_index shifted by `shift` (and "unlocked" when it is > from_index: an
## unlocked value equal to from_index only said "the level after the last old one is open", and that is still true).
## Version 1: the nine Stage 4 maps went in at 19, so the old Throne and Court (19, 20) became 28 and 29.
## Version 2 inserted the tunnel map (s4_tunnel) at 28: the Warlord and the court moved on by one.
## Version 3 removed five levels (0 country, 12 greenwood, 14 watchtower, 17 undercroft, 28 the warren).
## Later indices move down, and a removed index is dropped. "unlocked" follows the last level that is still there.
const LAYOUT_VERSION := 3
const LAYOUT_MIGRATIONS := [[1, 19, 9], [2, 28, 1]]
const DROPPED_LEVELS := [0, 12, 14, 17, 28]


static func ensure() -> void:
	if ready:
		return
	ready = true
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		_read(data)


## v0.12.2: a bought unlock (or every unlock, under test_all)
static func owns(id: String) -> bool:
	if id == "homing":
		return test_homing or bool(moves.get(id, false))      # test_all leaves homing off so the old bolt tests keep their aim
	return test_all or bool(moves.get(id, false))


## v0.12.2: how long a summoned ally stays on the map
static func summon_s() -> float:
	return SUMMON_S[clampi(summon_tier, 0, SUMMON_S.size() - 1)]


## the raw save dictionary with every LAYOUT_MIGRATIONS row newer than its "layout" applied (returns a new dictionary)
static func migrate(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	var v := int(out.get("layout", 0))
	for row: Array in LAYOUT_MIGRATIONS:
		if int(row[0]) <= v:
			continue
		var from_i := int(row[1])
		var shift := int(row[2])
		for key: String in ["clears", "prisoners"]:
			var src = out.get(key, {})
			if src is Dictionary:
				var moved := {}
				for k in src:
					var idx := int(String(k)) if String(k).is_valid_int() else -1
					moved[str(idx + shift) if idx >= from_i else String(k)] = src[k]
				out[key] = moved
		if out.has("unlocked") and int(out["unlocked"]) > from_i:
			out["unlocked"] = int(out["unlocked"]) + shift
	if v < 3:
		_drop_removed_levels(out)
	out["layout"] = LAYOUT_VERSION
	return out


## layout 3: five levels were removed. A kept index moves down by how many removed levels sat before it.
static func _remap_kept(idx: int) -> int:
	var shift := 0
	for d in DROPPED_LEVELS:
		if int(d) == idx:
			return -1
		if int(d) < idx:
			shift += 1
	return idx - shift


static func _drop_removed_levels(out: Dictionary) -> void:
	for key: String in ["clears", "prisoners"]:
		var src = out.get(key, {})
		if src is Dictionary:
			var moved := {}
			for k in src:
				var idx := int(String(k)) if String(k).is_valid_int() else -1
				if idx < 0:
					moved[String(k)] = src[k]
					continue
				var n := _remap_kept(idx)
				if n >= 0:
					moved[str(n)] = src[k]
			out[key] = moved
	if out.has("unlocked"):
		var u := int(out["unlocked"])
		var best := 0
		var any := false
		for i in range(maxi(u, 0) + 1):
			var n := _remap_kept(i)
			if n >= 0:
				best = n
				any = true
		out["unlocked"] = best if any else 0


static func _read(d: Dictionary) -> void:
	d = migrate(d)
	gold = maxi(int(d.get("gold", 0)), 0)
	moves = {}
	var rm = d.get("moves", {})
	if rm is Dictionary:
		for k in rm:
			if String(k) in MOVE_IDS and bool(rm[k]):
				moves[String(k)] = true
	summon_tier = clampi(int(d.get("summon_tier", 0)), 0, SUMMON_S.size() - 1)
	potion_cap = clampi(int(d.get("potion_cap", POTION_CAP_0)), 1, POTION_CAP_MAX)
	mana_potion_cap = clampi(int(d.get("mana_potion_cap", MANA_POTION_CAP_0)), 1, MANA_POTION_CAP_MAX)
	card_cap = clampi(int(d.get("card_cap", CARD_CAP_0)), 1, CARD_CAP_MAX)
	scale_cap = clampi(int(d.get("scale_cap", SCALE_CAP_0)), 2, SCALE_CAP_MAX)
	stamina_max = clampf(float(d.get("stamina_max", STAMINA_0)), STAMINA_0, STAMINA_CAP)
	rage_max = clampf(float(d.get("rage_max", RAGE_0)), RAGE_0, RAGE_CAP)
	potions = clampi(int(d.get("potions", 1)), 0, potion_cap)
	mana_pots = clampi(int(d.get("mana_pots", 0)), 0, mana_potion_cap)
	stamina = clampf(float(d.get("stamina", stamina_max)), 0.0, stamina_max)
	rage = clampf(float(d.get("rage", 0.0)), 0.0, rage_max)
	size = clampi(int(d.get("size", 2)), 1, scale_cap)
	unlocked = maxi(int(d.get("unlocked", 0)), 0)
	character = "perry" if String(d.get("character", "mera")) == "perry" else "mera"     # old saves: no Perry fields
	respawn = bool(d.get("respawn", false))
	perry_hp_max = clampi(int(d.get("perry_hp_max", Tuning.PERRY_HP_START)), Tuning.PERRY_HP_START, Tuning.PERRY_HP_CAP)
	perry_owned = {}
	var po = d.get("perry_owned", {})
	if po is Dictionary:
		for k in po:
			if bool(po[k]) and PerryUnlocks.by_id(String(k)) != null:
				perry_owned[String(k)] = true
	clears = {}
	var rc = d.get("clears", {})
	if rc is Dictionary:
		for k in rc:
			var n := maxi(int(rc[k]), 0)
			if n > 0:
				clears[String(k)] = n
	cards = {}
	var raw = d.get("cards", {})
	if raw is Dictionary:
		for k in raw:
			var n := maxi(int(raw[k]), 0)
			if n > 0 and String(k) in ALLIES:
				cards[String(k)] = n
	_trim_cards()
	story_seen = {}
	var rs = d.get("story_seen", {})
	if rs is Dictionary:
		for k in rs:
			if bool(rs[k]):
				story_seen[String(k)] = true
	prisoners = {}
	var rp = d.get("prisoners", {})
	if rp is Dictionary:
		for k in rp:
			if bool(rp[k]):
				prisoners[String(k)] = true
	perry_freed = bool(d.get("perry_freed", false))


static func pack() -> Dictionary:
	return {
		"gold": gold,
		"potion_cap": potion_cap,
		"mana_potion_cap": mana_potion_cap,
		"card_cap": card_cap,
		"scale_cap": scale_cap,
		"stamina_max": stamina_max,
		"rage_max": rage_max,
		"potions": potions,
		"mana_pots": mana_pots,
		"cards": cards.duplicate(true),
		"stamina": stamina,
		"rage": rage,
		"size": size,
		"unlocked": unlocked,
		"clears": clears.duplicate(),
		"moves": moves.duplicate(),
		"summon_tier": summon_tier,
		"character": character,
		"respawn": respawn,
		"perry_owned": perry_owned.duplicate(),
		"perry_hp_max": perry_hp_max,
		"story_seen": story_seen.duplicate(),
		"prisoners": prisoners.duplicate(),
		"perry_freed": perry_freed,
		"layout": LAYOUT_VERSION,
	}


static func save() -> void:
	ensure()
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(pack()))


static func reset() -> void:
	gold = 0
	potion_cap = POTION_CAP_0
	mana_potion_cap = MANA_POTION_CAP_0
	card_cap = CARD_CAP_0
	scale_cap = SCALE_CAP_0
	stamina_max = STAMINA_0
	rage_max = RAGE_0
	potions = 1
	mana_pots = 0
	cards = {}
	stamina = STAMINA_0
	rage = 0.0
	size = 2
	unlocked = 0
	clears = {}
	moves = {}
	summon_tier = 0
	character = "mera"
	respawn = false
	perry_owned = {}
	perry_hp_max = Tuning.PERRY_HP_START
	story_seen = {}
	prisoners = {}
	perry_freed = false
	ready = true
	save()
	if FileAccess.file_exists(RUN_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_PATH))


static func card_total() -> int:
	var n := 0
	for k in cards:
		n += int(cards[k])
	return n


static func _trim_cards() -> void:
	while card_total() > card_cap:
		var cut := false
		for k in ALLIES:
			if int(cards.get(k, 0)) > 0:
				cards[k] = int(cards[k]) - 1
				if int(cards[k]) <= 0:
					cards.erase(k)
				cut = true
				break
		if not cut:
			break


static func room_for_potion() -> bool:
	ensure()
	return potions < potion_cap


static func room_for_mana() -> bool:
	ensure()
	return mana_pots < mana_potion_cap


static func both_potions_full() -> bool:
	return not room_for_potion() and not room_for_mana()


static func room_for_card() -> bool:
	ensure()
	return card_total() < card_cap


static func stage_count() -> int:
	return Levels.list().size()


static func stage_open(i: int) -> bool:
	ensure()
	return i <= unlocked


static func unlock_through(i: int) -> void:
	ensure()
	var n := maxi(i, unlocked)
	if n == unlocked:
		return
	unlocked = n
	save()


## v0.12.2: a level was cleared. 15 gold the first time, 5 gold on each clear after that. Returns the gold paid.
static func record_clear(level: int) -> int:
	ensure()
	var key := str(level)
	var before := int(clears.get(key, 0))
	var pay := CLEAR_GOLD_FIRST if before == 0 else CLEAR_GOLD_REPEAT
	clears[key] = before + 1
	add_gold(pay)
	return pay


## Perry is playable once Stage 2's last level has been cleared
static func perry_unlocked() -> bool:
	ensure()
	return int(clears.get(str(PERRY_CLEAR_LEVEL), 0)) > 0


## the title menu's choice, only while Perry is unlocked
static func perry_selected() -> bool:
	return character == "perry" and perry_unlocked()


static func has_respawn() -> bool:
	ensure()
	return respawn


## "mera" or "perry"; a locked Perry falls back to Mera
static func set_character(who: String) -> bool:
	ensure()
	if who == "perry" and not perry_unlocked():
		return false
	character = "perry" if who == "perry" else "mera"
	save()
	return true


## Cutscenes (scripts/game/cutscene.gd): a key is remembered once its scene has finished
static func seen(key: String) -> bool:
	ensure()
	return key != "" and bool(story_seen.get(key, false))


static func mark_seen(key: String) -> void:
	ensure()
	if key == "" or bool(story_seen.get(key, false)):
		return
	story_seen[key] = true
	save()


## Prisoners (scripts/game/prisoner.gd): one per level, freed once ever
static func prisoner_freed(level_index: int) -> bool:
	ensure()
	return bool(prisoners.get(str(level_index), false))


static func free_prisoner(level_index: int) -> void:
	ensure()
	if prisoner_freed(level_index):
		return
	prisoners[str(level_index)] = true
	save()


## Perry is freed from the king's spell, once: her bought unlocks go and her max HP goes back to the start.
## Gold, Mera's moves and the level clears stay.
static func free_perry() -> void:
	ensure()
	if perry_freed:
		return
	perry_freed = true
	perry_owned = {}
	perry_hp_max = Tuning.PERRY_HP_START
	save()


## grants a Mera move (a shop "move:" id, no price). True when it was newly granted.
static func give_move(id: String) -> bool:
	ensure()
	if id not in MOVE_IDS or bool(moves.get(id, false)):
		return false
	moves[id] = true
	save()
	return true


static func add_gold(n: int) -> void:
	ensure()
	gold = maxi(0, gold + n)
	save()


static func give_potion() -> bool:
	ensure()
	if potions >= potion_cap:
		return false
	potions += 1
	save()
	return true


static func give_mana() -> bool:
	ensure()
	if mana_pots >= mana_potion_cap:
		return false
	mana_pots += 1
	save()
	return true


static func give_card(id: String) -> bool:
	ensure()
	if id not in ALLIES or not room_for_card():
		return false
	cards[id] = int(cards.get(id, 0)) + 1
	save()
	return true


static func take_card(id: String) -> bool:
	ensure()
	if int(cards.get(id, 0)) <= 0:
		return false
	cards[id] = int(cards[id]) - 1
	if int(cards[id]) <= 0:
		cards.erase(id)
	save()
	return true


## Copies the live player into this file. `d` keys match pack().
static func push_play(d: Dictionary) -> void:
	ensure()
	potions = clampi(int(d.get("potions", potions)), 0, potion_cap)
	mana_pots = clampi(int(d.get("mana_pots", mana_pots)), 0, mana_potion_cap)
	stamina_max = clampf(float(d.get("stamina_max", stamina_max)), STAMINA_0, STAMINA_CAP)
	rage_max = clampf(float(d.get("rage_max", rage_max)), RAGE_0, RAGE_CAP)
	stamina = clampf(float(d.get("stamina", stamina)), 0.0, stamina_max)
	rage = clampf(float(d.get("rage", rage)), 0.0, rage_max)
	size = clampi(int(d.get("size", size)), 1, scale_cap)
	if d.has("cards") and d["cards"] is Dictionary:
		cards = {}
		for k in d["cards"]:
			var n := maxi(int(d["cards"][k]), 0)
			if n > 0 and String(k) in ALLIES:
				cards[String(k)] = n
		_trim_cards()
	save()


static func _buy_move(id: String) -> String:
	if not PRICE_MOVE.has(id):
		return "bad"
	if owns(id):
		return "owned"
	if id == "super_quake" and not owns("earthquake"):
		return "order"
	var price := int(PRICE_MOVE[id])
	if gold < price:
		return "gold"
	gold -= price
	moves[id] = true
	save()
	return ""


## tier 1 = 60 s, 2 = 90 s, 3 = 120 s. They must be bought in order.
static func _buy_summon(tier: int) -> String:
	if tier < 1 or tier > SUMMON_S.size() - 1:
		return "bad"
	if tier <= summon_tier:
		return "owned"
	if tier != summon_tier + 1:
		return "order"
	var price := int(PRICE_SUMMON[tier - 1])
	if gold < price:
		return "gold"
	gold -= price
	summon_tier = tier
	save()
	return ""


## "" on success, otherwise "gold", "max", "full", or "bad".
static func buy(what: String, ally_id: String = "") -> String:
	ensure()
	if what.begins_with("move:"):
		return _buy_move(what.substr(5))
	if what.begins_with("summon:"):
		return _buy_summon(int(what.substr(7)))
	if what.begins_with("perry:"):
		return PerryUnlocks.buy(what.substr(6))
	match what:
		"potion_cap":
			if potion_cap >= POTION_CAP_MAX:
				return "max"
			if gold < PRICE_POTION_CAP:
				return "gold"
			gold -= PRICE_POTION_CAP
			potion_cap += 1
		"mana_cap":
			if mana_potion_cap >= MANA_POTION_CAP_MAX:
				return "max"
			if gold < PRICE_MANA_CAP:
				return "gold"
			gold -= PRICE_MANA_CAP
			mana_potion_cap += 1
		"card_cap":
			if card_cap >= CARD_CAP_MAX:
				return "max"
			if gold < PRICE_CARD_CAP:
				return "gold"
			gold -= PRICE_CARD_CAP
			card_cap += 1
		"card":
			if ally_id not in ALLIES:
				return "bad"
			if not room_for_card():
				return "full"
			if gold < PRICE_CARD:
				return "gold"
			gold -= PRICE_CARD
			cards[ally_id] = int(cards.get(ally_id, 0)) + 1
		"fury":
			if rage_max >= RAGE_CAP - 0.5:
				return "max"
			if gold < PRICE_FURY:
				return "gold"
			gold -= PRICE_FURY
			rage_max = minf(rage_max + RAGE_STEP, RAGE_CAP)
			rage = minf(rage, rage_max)
		"mana_bar":
			if stamina_max >= STAMINA_CAP - 0.5:
				return "max"
			if gold < PRICE_MANA_BAR:
				return "gold"
			gold -= PRICE_MANA_BAR
			stamina_max = minf(stamina_max + STAMINA_STEP, STAMINA_CAP)
			stamina = minf(stamina, stamina_max)
		"scale":
			if scale_cap >= SCALE_CAP_MAX:
				return "max"
			if gold < PRICE_SCALE:
				return "gold"
			gold -= PRICE_SCALE
			scale_cap += 1
		"key":
			if unlocked >= stage_count() - 1:
				return "max"
			if gold < PRICE_KEY:
				return "gold"
			gold -= PRICE_KEY
			unlocked += 1
		"respawn":
			if respawn:
				return "owned"
			if gold < PRICE_RESPAWN:
				return "gold"
			gold -= PRICE_RESPAWN
			respawn = true
		_:
			return "bad"
	save()
	return ""
