extends Control
## Title / level select. Left/Right choose, A / Start plays.
## Down goes to SHOP, RESET, CONTROLS, CHECK FOR UPDATES, and CREDITS.

const CREDITS := preload("res://scripts/app/credits.gd")

var sel := 0
var thumbs: Array = []
var t := 0.0
var _stick_ready := true
var font: Font
var row := 0                    # 0 = level cards, 1 = bottom buttons, 2 = the character toggle
var btn := 0                    # 0 shop, 1 reset, 2 controls, 3 updates, 4 credits
var mode := "menu"              # menu | credits | update | shop | controls
var prompt_i := 0
var ctrl_row := 0              # 0 = prompt style cards, 1 = CRT filter toggle
var credit_sel := 0
var shop_i := 0
var shop_page := 0             # v0.12.2: 0 stats, 1 moves and summon times
var shop_ally := 0
var note := ""
var note_t := 0.0


func _ready() -> void:
	Carry.ensure()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	font = ThemeDB.fallback_font
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sel = Levels.current
	for k in range(1, Levels.STAGE_FROM.size()):
		var from: int = Levels.STAGE_FROM[k]
		if Carry.unlocked >= from and Levels.current == from - 1:
			sel = from                                # just beat the last level of a stage (the dragon, Perry, the Black Knight): open on the next
	if Levels.current == Levels.THRONE and Carry.unlocked >= Levels.COURT:
		sel = Levels.COURT                            # just beat the Warlord: the king's court is next
	for lv in Levels.list():
		thumbs.append(load("res://assets/levels/%s/thumb.png" % String(lv["id"])))
	RenderingServer.set_default_clear_color(Color(0.02, 0.01, 0.04))
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--menu-shot="):
			_shot.call_deferred(a.get_slice("=", 1))
			return
	if not args.is_empty() and not ("--menu" in args) and not ("--update-selftest" in args):   # capture / test args (--demo, --level=N, ...): into the game
		get_tree().change_scene_to_file.call_deferred("res://scenes/game.tscn")
		return
	var upd := _upd()
	if upd and upd.auto_check and not upd.auto_checked and not ("--no-update-check" in args):
		upd.auto_checked = true
		upd.check()


func _upd() -> Node:
	return get_node_or_null("/root/Updater")


func _shot(path: String) -> void:
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)
	get_tree().quit()


func _process(delta: float) -> void:
	t += delta
	if note_t > 0.0:
		note_t -= delta
		if note_t <= 0.0:
			note_t = 0.0
			note = ""
	queue_redraw()


func _origin() -> Vector2:
	return Vector2((size.x - 1920.0) * 0.5, (size.y - 1080.0) * 0.5)


func _to_design(p: Vector2) -> Vector2:
	return p - _origin()


## the level indices on the page that shows level i (stage 1: 0..4, stage 2: 5..10, stage 3: 11..17, stage 4: 18..23, last stage: 24 and 25)
func page_levels(page: int) -> Array:
	var out: Array = []
	for i in thumbs.size():
		if Levels.stage_of(i) == page:
			out.append(i)
	return out


func page_of(i: int) -> int:
	return Levels.stage_of(i)


const PAGE_HEADS := ["STAGE 1  SELECT A LEVEL", "STAGE 2: THE ISLAND  SELECT A LEVEL", "STAGE 3: CHANGELING  SELECT A LEVEL", "STAGE 4: THE FALLEN CITY  SELECT A LEVEL", "THE KING'S COURT  SELECT A LEVEL"]   # one per Levels.stage_of
const WIDE_PAGE := 6          # a page with more cards than this lays them out in two rows (stage 3 has 7)


func _card(i: int) -> Rect2:
	var pl := page_levels(page_of(i))
	var n := maxi(pl.size(), 1)
	var k := maxi(pl.find(i), 0)
	if n > WIDE_PAGE:
		var per_row := ceili(float(n) / 2.0)
		var cw := 256.0
		var chh := 144.0
		var cgap := 60.0
		var x0 := (1920.0 - (cw * float(per_row) + cgap * float(per_row - 1))) * 0.5
		return Rect2(x0 + float(k % per_row) * (cw + cgap), 388.0 + float(floori(float(k) / float(per_row))) * 228.0, cw, chh)
	var gap := 18.0
	var margin := 28.0
	var w := minf((1920.0 - margin * 2.0 - gap * float(n - 1)) / float(n), 420.0)          # a page with one or two cards does not stretch them
	var x0 := (1920.0 - (w * float(n) + gap * float(n - 1))) * 0.5
	return Rect2(x0 + float(k) * (w + gap), 400, w, 168)


const BTN_N := 5


func _button(i: int) -> Rect2:
	var gap := 12.0
	var margin := 28.0
	var w := (1920.0 - margin * 2.0 - gap * float(BTN_N - 1)) / float(BTN_N)
	return Rect2(margin + float(i) * (w + gap), 980.0, w, 64.0)


func _button_text(i: int) -> String:
	if i == 0:
		return "SHOP"
	if i == 1:
		return "RESET"
	if i == 2:
		return "CONTROLS"
	if i == 4:
		return "CREDITS"
	var u := _upd()
	if u and u.state in ["available", "ready"]:
		return "UPDATE TO v%s" % u.version_text(u.latest["version"])
	return "CHECK FOR UPDATES"


func _press_button() -> void:
	Sfx.play("swipe", 1.0, -6.0)
	if btn == 0:
		Carry.ensure()
		mode = "shop"
		shop_page = 0
		shop_i = 0
		return
	if btn == 1:
		Carry.reset()
		note = "Reset. Gold, items, and upgrades cleared."
		note_t = 4.0
		return
	if btn == 2:
		var choices: Array = Controls.prompt_choices()
		prompt_i = maxi(choices.find(Controls.prompt_style()), 0)
		ctrl_row = 0
		mode = "controls"
		return
	if btn == 4:
		mode = "credits"
		credit_sel = 0
		return
	mode = "update"
	var u := _upd()
	if u and u.state in ["idle", "uptodate", "error", "unsupported"]:
		u.check()


## the update panel: A = next step (download -> install), B = close
func _update_input(e: InputEvent) -> void:
	var u := _upd()
	if e.is_action_pressed("btn_b") or (e is InputEventKey and e.pressed and e.physical_keycode == KEY_ESCAPE):
		mode = "menu"
	elif e.is_action_pressed("btn_a") or e.is_action_pressed("start") or e.is_action_pressed("ui_accept"):
		if u == null:
			mode = "menu"
		elif u.state == "available":
			u.download()
		elif u.state == "ready":
			u.apply()
		elif u.state in ["uptodate", "error", "unsupported"]:
			mode = "menu"


func _credits_input(e: InputEvent) -> void:
	var n: int = CREDITS.ENTRIES.size()
	if e.is_action_pressed("btn_b") or (e is InputEventKey and e.pressed and e.physical_keycode == KEY_ESCAPE):
		mode = "menu"
	elif e.is_action_pressed("up"):
		credit_sel = (credit_sel - 1 + n) % n
	elif e.is_action_pressed("down"):
		credit_sel = (credit_sel + 1) % n
	elif e.is_action_pressed("btn_a") or e.is_action_pressed("ui_accept"):
		OS.shell_open(String(CREDITS.ENTRIES[credit_sel]["url"]))
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for i in n:
			if Rect2(160, 190 + i * 74 - 30, 1600, 70).has_point(_to_design(e.position)):
				credit_sel = i
				OS.shell_open(String(CREDITS.ENTRIES[i]["url"]))


## v0.12.2: two shop pages. Left/Right switch page. Page 1 is the stats, page 2 the moves and summon times.
const SHOP_PAGES := [
	["potion_cap", "mana_cap", "card_cap", "card", "fury", "mana_bar", "scale", "key", "respawn"],
	["move:beam", "move:earthquake", "move:super_quake", "move:rear", "move:fury_mode", "move:homing", "summon:1", "summon:2", "summon:3"],
]


## big text means few rows: every shop list is cut into pages of SHOP_PER_PAGE rows
const SHOP_PER_PAGE := 5


## every row of the selected character's shop, in order
func _all_rows() -> Array:
	if _perry_page():
		var rows: Array = ["respawn"]
		rows.append_array(_perry_ids().map(func(id): return "perry:" + String(id)))
		return rows
	var out: Array = []
	for pg in SHOP_PAGES:
		out.append_array(pg)
	return out


func _rows() -> Array:
	var all := _all_rows()
	var from := clampi(shop_page, 0, _page_count() - 1) * SHOP_PER_PAGE
	return all.slice(from, mini(from + SHOP_PER_PAGE, all.size()))


func _perry_ids() -> Array:
	var ids: Array = [PerryUnlocks.POWDER_ID]
	for u in PerryUnlocks.LIST:
		ids.append(String(u["id"]))
	return ids


func _page_count() -> int:
	return maxi(ceili(float(_all_rows().size()) / float(SHOP_PER_PAGE)), 1)


func _perry_page() -> bool:
	return Carry.perry_selected()                            # the shop shows the character that is selected


func _perry_row_id(i: int) -> String:
	var w := _shop_what(i)
	return w.substr(6) if w.begins_with("perry:") else ""


func _shop_what(i: int) -> String:
	var r := _rows()
	return String(r[i]) if i >= 0 and i < r.size() else ""


func _ally_id() -> String:
	return String(Carry.ALLIES[posmod(shop_ally, Carry.ALLIES.size())])


func _shop_name(i: int) -> String:
	var pid := _perry_row_id(i)
	if pid != "":
		return "Bone Powder  (+%d max HP)" % Tuning.PERRY_HP_STEP if pid == PerryUnlocks.POWDER_ID else String(PerryUnlocks.by_id(pid)["name"])
	match _shop_what(i):
		"potion_cap":
			return "Health potion slots"
		"mana_cap":
			return "Mana potion slots"
		"card_cap":
			return "Card slots"
		"card":
			return "Buy summon card   < %s >   (X / A: change)" % _ally_id().capitalize()
		"fury":
			return "Fury bar +%d" % int(Carry.RAGE_STEP)
		"mana_bar":
			return "Mana bar +%d" % int(Carry.STAMINA_STEP)
		"scale":
			return "Size cap +1 (max %dx)" % Carry.SCALE_CAP_MAX
		"key":
			return "Stage key"
		"respawn":
			return "Respawn with minigame"
		"move:beam":
			return "Beam at the end of a combo (X X X, then Y)"
		"move:earthquake":
			return "Earthquake (Down + Y)"
		"move:super_quake":
			return "Super earthquake (Down + Y at full rage)"
		"move:rear":
			return "Rear explosion (X + Y)"
		"move:fury_mode":
			return "Fury mode (L2 + R2)"
		"move:homing":
			return "Homing shots (quick fire bolts seek enemies)"
		"summon:1":
			return "Summon time 60 s"
		"summon:2":
			return "Summon time 90 s"
		"summon:3":
			return "Summon time 120 s"
		_:
			return ""


func _shop_stat(i: int) -> String:
	var w := _shop_what(i)
	if w.begins_with("perry:"):
		var pid := w.substr(6)
		if pid == PerryUnlocks.POWDER_ID:
			return "%d / %d HP" % [Carry.perry_hp_max, Tuning.PERRY_HP_CAP]
		if PerryUnlocks.owned(pid):
			return "owned"
		return PerryUnlocks.locked_reason(pid) if PerryUnlocks.locked_reason(pid) != "" else "for sale"
	if w.begins_with("move:"):
		if Carry.owns(w.substr(5)):
			return "owned"
		if w == "move:super_quake" and not Carry.owns("earthquake"):
			return "needs earthquake"
		return "locked"
	if w.begins_with("summon:"):
		var t := int(w.substr(7))
		if t <= Carry.summon_tier:
			return "owned"
		return "now %d s" % int(Carry.SUMMON_S[Carry.summon_tier])
	match w:
		"potion_cap":
			return "%d / %d" % [Carry.potion_cap, Carry.POTION_CAP_MAX]
		"mana_cap":
			return "%d / %d" % [Carry.mana_potion_cap, Carry.MANA_POTION_CAP_MAX]
		"card_cap":
			return "%d / %d" % [Carry.card_cap, Carry.CARD_CAP_MAX]
		"card":
			return "x%d" % int(Carry.cards.get(_ally_id(), 0))
		"fury":
			return str(int(Carry.rage_max))
		"mana_bar":
			return str(int(Carry.stamina_max))
		"scale":
			return str(Carry.scale_cap)
		"key":
			if Carry.unlocked >= Carry.stage_count() - 1:
				return "all open"
			return "opens stage %d" % (Carry.unlocked + 2)
		"respawn":
			return "owned" if Carry.respawn else "locked"
		_:
			return ""


func _shop_price(i: int) -> int:
	var w := _shop_what(i)
	if w.begins_with("perry:"):
		return PerryUnlocks.price(w.substr(6))
	if w.begins_with("move:"):
		return int(Carry.PRICE_MOVE.get(w.substr(5), 0))
	if w.begins_with("summon:"):
		return int(Carry.PRICE_SUMMON[int(w.substr(7)) - 1])
	match w:
		"potion_cap":
			return Carry.PRICE_POTION_CAP
		"mana_cap":
			return Carry.PRICE_MANA_CAP
		"card_cap":
			return Carry.PRICE_CARD_CAP
		"card":
			return Carry.PRICE_CARD
		"fury":
			return Carry.PRICE_FURY
		"mana_bar":
			return Carry.PRICE_MANA_BAR
		"scale":
			return Carry.PRICE_SCALE
		"key":
			return Carry.PRICE_KEY
		"respawn":
			return Carry.PRICE_RESPAWN
		_:
			return 0


func _shop_row_rect(i: int) -> Rect2:
	return Rect2(160, 250 + i * 124, 1600, 116)


func _shop_buy() -> void:
	var what := _shop_what(shop_i)
	var ally := ""
	if what == "card" and not Carry.ALLIES.is_empty():
		ally = _ally_id()
	var result := Carry.buy(what, ally)
	if result == "":
		note = "Bought."
		Sfx.play("potion", 1.0, -4.0)
	elif result == "gold":
		note = "Not enough gold."
		Sfx.play("swipe", 0.8, -10.0)
	elif result == "max":
		note = "Already maxed."
		Sfx.play("swipe", 0.8, -10.0)
	elif result == "owned":
		note = "Already owned."
		Sfx.play("swipe", 0.8, -10.0)
	elif result == "order":
		note = "Buy the earthquake first." if what == "move:super_quake" else "Buy the shorter summon time first."
		Sfx.play("swipe", 0.8, -10.0)
	elif result == "full":
		note = "Card slots full."
		Sfx.play("swipe", 0.8, -10.0)
	elif result == "locked":
		note = PerryUnlocks.locked_reason(what.substr(6))
		Sfx.play("swipe", 0.8, -10.0)
	else:
		note = "Can't buy that."
		Sfx.play("swipe", 0.8, -10.0)
	note_t = 4.0


## the shop: Up/Down a row, Left/Right the page, X (A) the summon card, A buys, B closes
func _shop_input(e: InputEvent) -> void:
	var n := _rows().size()
	if e.is_action_pressed("btn_b") or (e is InputEventKey and e.pressed and e.physical_keycode == KEY_ESCAPE):
		mode = "menu"
	elif e.is_action_pressed("up"):
		shop_i = (shop_i - 1 + n) % n
		Sfx.play("swipe", 1.2, -8.0)
	elif e.is_action_pressed("down"):
		shop_i = (shop_i + 1) % n
		Sfx.play("swipe", 1.2, -8.0)
	elif e.is_action_pressed("left") or e.is_action_pressed("right"):
		shop_page = posmod(shop_page + (-1 if e.is_action_pressed("left") else 1), _page_count())
		shop_i = mini(shop_i, _rows().size() - 1)
		Sfx.play("swipe", 1.4, -8.0)
	elif e.is_action_pressed("btn_x"):
		if _shop_what(shop_i) == "card" and not Carry.ALLIES.is_empty():
			shop_ally = (shop_ally + 1) % Carry.ALLIES.size()
			Sfx.play("swipe", 1.4, -8.0)
	elif e.is_action_pressed("btn_a") or e.is_action_pressed("ui_accept"):
		_shop_buy()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var p := _to_design(e.position)
		for i in n:
			if _shop_row_rect(i).has_point(p):
				shop_i = i
				_shop_buy()
				return


## Stage 3: X (the A key) on the level select switches between Mera and Perry. Perry opens once Moonlit Sanctum is cleared.
func _toggle_character() -> void:
	Carry.ensure()
	if not Carry.perry_unlocked():
		note = "Perry is locked: clear Stage 2, Moonlit Sanctum (level %d), first." % (Carry.PERRY_CLEAR_LEVEL + 1)
		note_t = 4.0
		Sfx.play("swipe", 0.7, -8.0)
		return
	Carry.set_character("mera" if Carry.character == "perry" else "perry")
	shop_page = 0
	shop_i = 0
	Sfx.play("swipe", 1.4, -8.0)


## the big character toggle under the level cards: MERA on the left half, PERRY on the right half
func _char_rect() -> Rect2:
	return Rect2(560, 700, 800, 112)


func _draw_char_toggle() -> void:
	Carry.ensure()
	var r := _char_rect()
	var on_row := row == 2
	draw_rect(r, Color(0.12, 0.08, 0.03, 0.95))
	var g := 0.5 + 0.5 * sin(t * 5.0)
	draw_rect(r, Color(1.0, 0.8, 0.4, 0.6 + 0.4 * g) if on_row else Color(0.5, 0.45, 0.6), false, 4.0)
	draw_string(font, Vector2(r.position.x, r.position.y + 30), Controls.faces("CHARACTER   (A / click to switch)"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, Color(0.85, 0.85, 0.9))
	var perry := Carry.perry_selected()
	var half := r.size.x / 2.0
	var lit_x := r.position.x + (half if perry else 0.0)
	draw_rect(Rect2(lit_x, r.position.y + 40, half, r.size.y - 48), Color(0.45, 0.3, 0.05, 0.9))
	draw_string(font, Vector2(r.position.x, r.position.y + 98), "MERA", HORIZONTAL_ALIGNMENT_CENTER, half, 52,
		Color(1.0, 0.9, 0.5) if not perry else Color(0.6, 0.6, 0.66))
	var perry_text := "PERRY" if Carry.perry_unlocked() else "PERRY (LOCKED)"
	draw_string(font, Vector2(r.position.x + half, r.position.y + 98), perry_text, HORIZONTAL_ALIGNMENT_CENTER, half, 52,
		Color(1.0, 0.9, 0.5) if perry else (Color(0.6, 0.6, 0.66) if Carry.perry_unlocked() else Color(0.9, 0.4, 0.35)))


func _move(d: int) -> void:
	sel = (sel + d + thumbs.size()) % thumbs.size()
	Sfx.play("swipe", 1.4, -8.0)


func _start() -> void:
	Carry.ensure()
	if not Carry.stage_open(sel):
		note = "Locked. Beat the previous stage, or buy a 200 gold key."
		note_t = 4.0
		Sfx.play("swipe", 0.7, -8.0)
		return
	Levels.current = sel
	Sfx.play("potion", 1.0)
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _unhandled_input(e: InputEvent) -> void:
	if e.is_echo():
		return
	if mode == "credits":
		_credits_input(e)
		return
	if mode == "update":
		_update_input(e)
		return
	if mode == "shop":
		_shop_input(e)
		return
	if mode == "controls":
		_prompt_input(e)
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and _char_rect().has_point(_to_design(e.position)):
		row = 2
		_toggle_character()
		return
	if e.is_action_pressed("down") and row == 0:
		row = 2                                              # cards -> character toggle -> bottom buttons
		Sfx.play("swipe", 1.2, -8.0)
		return
	if e.is_action_pressed("down") and row == 2:
		row = 1
		Sfx.play("swipe", 1.2, -8.0)
		return
	if e.is_action_pressed("up") and row == 1:
		row = 2
		Sfx.play("swipe", 1.2, -8.0)
		return
	if e.is_action_pressed("up") and row == 2:
		row = 0
		Sfx.play("swipe", 1.2, -8.0)
		return
	if row == 2:
		if e.is_action_pressed("btn_a") or e.is_action_pressed("start") or e.is_action_pressed("ui_accept"):
			_toggle_character()
		elif e is InputEventKey and e.pressed and e.physical_keycode == KEY_ESCAPE:
			get_tree().quit()
		return
	if row == 1:
		if e.is_action_pressed("left"):
			btn = (btn + BTN_N - 1) % BTN_N
			Sfx.play("swipe", 1.4, -8.0)
		elif e.is_action_pressed("right"):
			btn = (btn + 1) % BTN_N
			Sfx.play("swipe", 1.4, -8.0)
		elif e.is_action_pressed("btn_a") or e.is_action_pressed("start") or e.is_action_pressed("ui_accept"):
			_press_button()
		elif e is InputEventKey and e.pressed and e.physical_keycode == KEY_ESCAPE:
			get_tree().quit()
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_click_buttons(_to_design(e.position))
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and _click_buttons(_to_design(e.position)):
		return
	if e.is_action_pressed("left"):
		_move(-1)
	elif e.is_action_pressed("right"):
		_move(1)
	elif e.is_action_pressed("btn_a") or e.is_action_pressed("start") or e.is_action_pressed("ui_accept"):
		_start()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for i: int in page_levels(page_of(sel)):
			if _card(i).has_point(_to_design(e.position)):
				if sel == i:
					_start()
				sel = i
	elif e is InputEventKey and e.pressed and e.physical_keycode == KEY_ESCAPE:
		get_tree().quit()


func _click_buttons(p: Vector2) -> bool:
	for i in BTN_N:
		if _button(i).has_point(p):
			row = 1
			btn = i
			_press_button()
			return true
	return false


func _draw() -> void:
	var bg: Texture2D = thumbs[sel]
	draw_texture_rect(bg, Rect2(Vector2.ZERO, size), false, Color(0.35, 0.3, 0.4))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.0, 0.05, 0.45))
	draw_set_transform(_origin(), 0.0, Vector2.ONE)
	draw_string(font, Vector2(0, 200), "MERA", HORIZONTAL_ALIGNMENT_CENTER, 1920, 140, Color(1.0, 0.8, 0.45))
	draw_string(font, Vector2(0, 280), "THE BABY GIANT", HORIZONTAL_ALIGNMENT_CENTER, 1920, 56, Color(0.95, 0.9, 1.0))
	var head: String = PAGE_HEADS[page_of(sel)]
	draw_string(font, Vector2(0, 370), head, HORIZONTAL_ALIGNMENT_CENTER, 1920, 34, Color(0.8, 0.8, 0.9))
	var ls := Levels.list()
	for i: int in page_levels(page_of(sel)):
		var r := _card(i)
		var on := i == sel
		if on:
			var g := 0.5 + 0.5 * sin(t * 5.0)
			draw_rect(r.grow(10), Color(1.0, 0.8, 0.4, 0.6 + 0.4 * g))
		draw_texture_rect(thumbs[i], r, false, Color(1, 1, 1) if on else Color(0.55, 0.55, 0.6))
		draw_rect(r, Color(0, 0, 0), false, 3.0)
		var lv: Dictionary = ls[i]
		var open := Carry.stage_open(i)
		if not open:
			draw_rect(r, Color(0.02, 0.0, 0.04, 0.72))
		var lw := r.size.x + (60.0 if page_levels(page_of(sel)).size() > WIDE_PAGE else 0.0)     # two-row pages have room between the cards
		var lx := r.position.x - (lw - r.size.x) * 0.5
		var fs := 28 if lw > 300.0 else 24
		draw_string(font, Vector2(lx, r.end.y + (40 if lw > r.size.x else 52)), "%d  %s" % [i + 1, String(lv["name"])], HORIZONTAL_ALIGNMENT_CENTER, lw, fs,
			Color(1, 0.85, 0.5) if on else Color(0.75, 0.75, 0.8))
		if (i + 1) in Levels.STAGE_FROM and i != 0 and ls.size() > i + 1:       # the last level of a stage: the game goes on
			var yel := Color(1.0, 0.92, 0.2)
			var mid := r.position.y + r.size.y / 2.0 - 20.0
			var tri := PackedVector2Array([Vector2(r.end.x - 8.0, mid), Vector2(r.end.x - 44.0, mid - 22.0), Vector2(r.end.x - 44.0, mid + 22.0)])
			draw_colored_polygon(tri, yel)
			draw_string(font, Vector2(r.end.x - 86.0, r.end.y - 14.0), "CONTINUE", HORIZONTAL_ALIGNMENT_CENTER, 120, 22, yel)
		var sub := "LOCKED" if not open else String(lv["sub"])
		draw_string(font, Vector2(lx, r.end.y + (64 if lw > r.size.x else 86)), sub, HORIZONTAL_ALIGNMENT_CENTER, lw, 18,
			Color(1.0, 0.45, 0.4) if not open else Color(0.8, 0.8, 0.85))
	draw_string(font, Vector2(0, 860), Controls.faces("Left / Right: choose      A / Start: play      Down: shop, reset, controls, updates, credits, soul maze      Esc: quit"), HORIZONTAL_ALIGNMENT_CENTER, 1920, 26, Color(0.85, 0.85, 0.9))
	_draw_char_toggle()
	if mode == "menu":
		_draw_note_at(930)
	for i in BTN_N:
		var r := _button(i)
		var on := row == 1 and btn == i
		var u := _upd()
		var hot: bool = i == 3 and u != null and u.state in ["available", "ready"]
		draw_rect(r, Color(0.25, 0.12, 0.05, 0.9) if on else Color(0.08, 0.05, 0.12, 0.8))
		draw_rect(r, Color(1.0, 0.8, 0.4) if on else (Color(0.4, 1.0, 0.5) if hot else Color(0.5, 0.45, 0.6)), false, 3.0)
		draw_string(font, Vector2(r.position.x, r.position.y + 42), _button_text(i), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22,
			Color(1, 0.9, 0.6) if on else (Color(0.6, 1.0, 0.65) if hot else Color(0.85, 0.85, 0.9)))
	_draw_version()
	if mode == "credits":
		_draw_credits()
	elif mode == "update":
		_draw_update()
	elif mode == "shop":
		_draw_shop()
	elif mode == "controls":
		_draw_prompts()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _saved_run() -> Dictionary:
	if not FileAccess.file_exists("user://mera_run.json"):
		return {}
	var f := FileAccess.open("user://mera_run.json", FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}


func _draw_version() -> void:
	var u := _upd()
	var v := String(ProjectSettings.get_setting("application/config/version", "?"))
	draw_string(font, Vector2(20, 1062), "v" + v, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.6, 0.6, 0.7))
	if u and u.state == "available" and mode == "menu":
		var g := 0.6 + 0.4 * sin(t * 4.0)
		draw_string(font, Vector2(0, 50), "Update available: v%s   (Down, then CHECK FOR UPDATES)" % u.version_text(u.latest["version"]), HORIZONTAL_ALIGNMENT_RIGHT, 1900, 26, Color(0.5, 1.0, 0.55, g))


func _panel(r: Rect2) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.72))
	draw_set_transform(_origin(), 0.0, Vector2.ONE)
	draw_rect(r, Color(0.06, 0.03, 0.09, 0.97))
	draw_rect(r, Color(1.0, 0.8, 0.45), false, 3.0)


func _draw_credits() -> void:
	_panel(Rect2(120, 60, 1680, 960))
	draw_string(font, Vector2(0, 130), "CREDITS", HORIZONTAL_ALIGNMENT_CENTER, 1920, 50, Color(1.0, 0.8, 0.45))
	var i := 0
	for c in CREDITS.ENTRIES:
		var y := 190 + i * 74
		var on := i == credit_sel
		if on:
			draw_rect(Rect2(160, y - 30, 1600, 70), Color(0.3, 0.15, 0.05, 0.8))
		draw_string(font, Vector2(180, y), "%s  [%s]" % [String(c["who"]), String(c["lic"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 0.9, 0.6) if on else Color(0.95, 0.9, 1.0))
		draw_string(font, Vector2(180, y + 30), "%s  -  %s" % [String(c["what"]), String(c["url"])], HORIZONTAL_ALIGNMENT_LEFT, 1560, 20, Color(0.75, 0.75, 0.85))
		i += 1
	draw_string(font, Vector2(0, 950), CREDITS.FOOTER, HORIZONTAL_ALIGNMENT_CENTER, 1920, 20, Color(0.7, 0.7, 0.8))
	draw_string(font, Vector2(0, 990), Controls.faces("Up / Down: select    A or click: open the link    B / Esc: back"), HORIZONTAL_ALIGNMENT_CENTER, 1920, 24, Color(0.85, 0.85, 0.9))


func _draw_note_at(y: float) -> void:
	if note == "" or note_t <= 0.0:
		return
	var a := 1.0 if note_t > 0.7 else note_t / 0.7
	draw_string(font, Vector2(0, y), note, HORIZONTAL_ALIGNMENT_CENTER, 1920, 26, Color(1.0, 0.86, 0.45, a))


func _draw_shop() -> void:
	Carry.ensure()
	_panel(Rect2(120, 60, 1680, 960))
	var who := "PERRY SHOP" if _perry_page() else "MERA SHOP"
	draw_string(font, Vector2(0, 150), who, HORIZONTAL_ALIGNMENT_CENTER, 1920, 64, Color(1.0, 0.8, 0.45))
	draw_string(font, Vector2(0, 218), "Gold: %d        page %d / %d" % [Carry.gold, shop_page + 1, _page_count()], HORIZONTAL_ALIGNMENT_CENTER, 1920, 42, Color(1.0, 0.85, 0.4))
	var rows := _rows()
	for i in rows.size():
		var r := _shop_row_rect(i)
		var on := i == shop_i
		if on:
			draw_rect(r, Color(0.3, 0.15, 0.05, 0.8))
		var col := Color(1, 0.9, 0.6) if on else Color(0.95, 0.9, 1.0)
		if _perry_page() and _shop_what(i) != "respawn":
			_draw_perry_row(i, r, col)
			continue
		draw_string(font, Vector2(r.position.x + 24, r.position.y + 50), Controls.faces(_shop_name(i)), HORIZONTAL_ALIGNMENT_LEFT, 1220, 38, col)
		draw_string(font, Vector2(r.position.x + 24, r.position.y + 100), Controls.faces(_shop_stat(i)), HORIZONTAL_ALIGNMENT_LEFT, 1200, 30, Color(0.8, 0.8, 0.88))
		var price := _shop_price(i)
		var pc := Color(1.0, 0.8, 0.45) if Carry.gold >= price else Color(0.75, 0.45, 0.4)
		draw_string(font, Vector2(r.position.x + 1280, r.position.y + 50), "%d g" % price, HORIZONTAL_ALIGNMENT_RIGHT, 300, 40, pc)
	_draw_note_at(900)
	draw_string(font, Vector2(0, 985), Controls.faces("Up/Down: row    Left/Right: page    A: buy    B: back"), HORIZONTAL_ALIGNMENT_CENTER, 1920, 34, Color(0.85, 0.85, 0.9))


## a Perry shop row: name and price on the first line, hint and owned / why it is locked on the second
func _draw_perry_row(i: int, r: Rect2, col: Color) -> void:
	var pid := _perry_row_id(i)
	var owned := PerryUnlocks.owned(pid)
	var hint := "+%d max HP, up to %d" % [Tuning.PERRY_HP_STEP, Tuning.PERRY_HP_CAP] if pid == PerryUnlocks.POWDER_ID else String(PerryUnlocks.by_id(pid)["hint"])
	draw_string(font, Vector2(r.position.x + 24, r.position.y + 50), Controls.faces(_shop_name(i)), HORIZONTAL_ALIGNMENT_LEFT, 1220, 38, Color(0.6, 1.0, 0.65) if owned else col)
	draw_string(font, Vector2(r.position.x + 24, r.position.y + 100), Controls.faces(hint), HORIZONTAL_ALIGNMENT_LEFT, 880, 28, Color(0.8, 0.8, 0.88))
	var stat := _shop_stat(i)
	draw_string(font, Vector2(r.position.x + 920, r.position.y + 100), stat, HORIZONTAL_ALIGNMENT_LEFT, 660, 28, Color(0.6, 1.0, 0.65) if owned else (Color(1.0, 0.5, 0.45) if stat.begins_with("Clear") else Color(0.85, 0.85, 0.9)))
	if not owned or pid == PerryUnlocks.POWDER_ID:
		var price := _shop_price(i)
		draw_string(font, Vector2(r.position.x + 1280, r.position.y + 50), "%d g" % price, HORIZONTAL_ALIGNMENT_RIGHT, 300, 40, Color(1.0, 0.8, 0.45) if Carry.gold >= price else Color(0.75, 0.45, 0.4))


## the prompt style screen: Left/Right pick, and the choice is saved as soon as it changes. B closes.
const PROMPT_ROWS := [
	["Confirm", "btn_a"], ["Back", "btn_b"], ["Attack", "btn_x"], ["Quick", "btn_y"],
	["Heal", "l1"], ["Summon", "r1"], ["Bubble", "l2"], ["Lightning", "r2"],
	["Pause", "start"], ["Freeze slash", "r3"],
]


func _settings() -> Node:
	return get_node_or_null("/root/Settings")


func _crt_on() -> bool:
	var settings := _settings()
	return settings != null and bool(settings.get("crt"))


func _toggle_crt() -> void:
	var settings := _settings()
	if settings:
		settings.toggle_crt()
		Sfx.play("swipe", 1.0, -6.0)


## clickable / focusable CRT filter row on the Controls (options) page
func _crt_toggle_rect() -> Rect2:
	return Rect2(460, 800, 1000, 70)


func _prompt_card(i: int) -> Rect2:
	var choices: Array = Controls.prompt_choices()
	var n := maxi(choices.size(), 1)
	var w := 460.0
	var gap := 28.0
	var total := w * float(n) + gap * float(n - 1)
	var x0 := (1920.0 - total) * 0.5
	return Rect2(x0 + float(i) * (w + gap), 250.0, w, 520.0)


func _apply_prompt(i: int) -> void:
	var choices: Array = Controls.prompt_choices()
	if i < 0 or i >= choices.size():
		return
	prompt_i = i
	Controls.set_prompt(String(choices[i]))


func _prompt_input(e: InputEvent) -> void:
	var n: int = Controls.prompt_choices().size()
	if e.is_action_pressed("btn_b") or (e is InputEventKey and e.pressed and e.physical_keycode == KEY_ESCAPE):
		mode = "menu"
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var p := _to_design(e.position)
		if _crt_toggle_rect().has_point(p):
			ctrl_row = 1
			_toggle_crt()
			return
		for i in n:
			if _prompt_card(i).has_point(p):
				ctrl_row = 0
				_apply_prompt(i)
				return
	elif e.is_action_pressed("up"):
		if ctrl_row == 1:
			ctrl_row = 0
			Sfx.play("swipe", 1.3, -8.0)
		else:
			_apply_prompt(posmod(prompt_i - 1, n))
			Sfx.play("swipe", 1.3, -8.0)
	elif e.is_action_pressed("down"):
		if ctrl_row == 0:
			ctrl_row = 1
			Sfx.play("swipe", 1.3, -8.0)
		else:
			_toggle_crt()
	elif e.is_action_pressed("left"):
		if ctrl_row == 1:
			_toggle_crt()
		else:
			_apply_prompt(posmod(prompt_i - 1, n))
			Sfx.play("swipe", 1.3, -8.0)
	elif e.is_action_pressed("right"):
		if ctrl_row == 1:
			_toggle_crt()
		else:
			_apply_prompt(posmod(prompt_i + 1, n))
			Sfx.play("swipe", 1.3, -8.0)
	elif e.is_action_pressed("btn_a") or e.is_action_pressed("start") or e.is_action_pressed("ui_accept"):
		if ctrl_row == 1:
			_toggle_crt()
		else:
			_apply_prompt(prompt_i)
			mode = "menu"


func _draw_prompts() -> void:
	_panel(Rect2(120, 60, 1680, 960))
	draw_string(font, Vector2(0, 140), "OPTIONS", HORIZONTAL_ALIGNMENT_CENTER, 1920, 56, Color(1.0, 0.8, 0.45))
	draw_string(font, Vector2(0, 200), "Controller names, and the CRT filter. The buttons still do the same thing.", HORIZONTAL_ALIGNMENT_CENTER, 1920, 24, Color(0.8, 0.8, 0.88))
	var choices: Array = Controls.prompt_choices()
	for i in choices.size():
		var r := _prompt_card(i)
		var on := ctrl_row == 0 and i == prompt_i
		var id := String(choices[i])
		draw_rect(r, Color(0.28, 0.14, 0.04, 0.95) if on else Color(0.08, 0.05, 0.12, 0.92))
		draw_rect(r, Color(1.0, 0.8, 0.4) if on else Color(0.45, 0.4, 0.55), false, 4.0)
		draw_string(font, Vector2(r.position.x, r.position.y + 52), Controls.prompt_label(id), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 36, Color(1.0, 0.9, 0.55) if on else Color(0.9, 0.9, 0.95))
		var y := r.position.y + 110.0
		for row_i in PROMPT_ROWS:
			var label := String(row_i[0])
			var shown := Controls.button(String(row_i[1]), id)
			draw_string(font, Vector2(r.position.x + 36, y), label, HORIZONTAL_ALIGNMENT_LEFT, 250, 28, Color(0.75, 0.75, 0.82))
			draw_string(font, Vector2(r.position.x + 250, y), shown, HORIZONTAL_ALIGNMENT_LEFT, 170, 28, Color(1.0, 0.85, 0.45))
			y += 40.0
	var cr := _crt_toggle_rect()
	var crt_focus := ctrl_row == 1
	var crt_on := _crt_on()
	draw_rect(cr, Color(0.28, 0.14, 0.04, 0.95) if crt_focus else Color(0.08, 0.05, 0.12, 0.92))
	draw_rect(cr, Color(1.0, 0.8, 0.4) if crt_focus else Color(0.45, 0.4, 0.55), false, 4.0)
	var crt_label := "CRT FILTER: ON" if crt_on else "CRT FILTER: OFF"
	draw_string(font, Vector2(cr.position.x, cr.position.y + 48), crt_label, HORIZONTAL_ALIGNMENT_CENTER, cr.size.x, 36, Color(1.0, 0.9, 0.55) if crt_focus else Color(0.9, 0.9, 0.95))
	draw_string(font, Vector2(0, 980), Controls.faces("Left / Right: choose (saved at once)    Down: CRT filter (click or A to toggle)    A: close    B: back"), HORIZONTAL_ALIGNMENT_CENTER, 1920, 24, Color(0.85, 0.85, 0.9))


func _draw_update() -> void:
	var r := Rect2(360, 300, 1200, 440)
	_panel(r)
	draw_string(font, Vector2(0, 380), "UPDATES", HORIZONTAL_ALIGNMENT_CENTER, 1920, 46, Color(1.0, 0.8, 0.45))
	var u := _upd()
	if u == null:
		return
	draw_string(font, Vector2(0, 450), "This version: v%s" % String(ProjectSettings.get_setting("application/config/version", "?")), HORIZONTAL_ALIGNMENT_CENTER, 1920, 26, Color(0.8, 0.8, 0.9))
	draw_string(font, Vector2(400, 520), u.message, HORIZONTAL_ALIGNMENT_CENTER, 1120, 28, Color(0.95, 0.95, 1.0))
	if u.state == "downloading":
		var b := Rect2(560, 570, 800, 30)
		draw_rect(b, Color(0.15, 0.1, 0.2))
		draw_rect(Rect2(b.position, Vector2(b.size.x * u.progress, b.size.y)), Color(0.4, 1.0, 0.5))
		draw_rect(b, Color(0.8, 0.8, 0.9), false, 2.0)
	var hint := {"available": "A: download and verify      B: later",
		"ready": "A: install and restart%s      B: later" % (" (opens the Android installer)" if u.platform_name() == "Android" else ""),
		"checking": "B: close", "downloading": "B: hide (the download continues)", "installing": "",
		"uptodate": "A / B: close", "error": "A / B: close", "unsupported": "A / B: close", "idle": "B: close"}
	draw_string(font, Vector2(0, 690), Controls.faces(String(hint.get(u.state, ""))), HORIZONTAL_ALIGNMENT_CENTER, 1920, 26, Color(0.85, 0.85, 0.9))
