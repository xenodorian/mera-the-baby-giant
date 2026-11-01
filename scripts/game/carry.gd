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
const SCALE_CAP_MAX := 9
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

const ALLIES := ["priestess", "ranger", "brawler", "dancer"]

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


static func _read(d: Dictionary) -> void:
	gold = maxi(int(d.get("gold", 0)), 0)
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
	cards = {}
	var raw = d.get("cards", {})
	if raw is Dictionary:
		for k in raw:
			var n := maxi(int(raw[k]), 0)
			if n > 0 and String(k) in ALLIES:
				cards[String(k)] = n
	_trim_cards()


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


## "" on success, otherwise "gold", "max", "full", or "bad".
static func buy(what: String, ally_id: String = "") -> String:
	ensure()
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
		_:
			return "bad"
	save()
	return ""
