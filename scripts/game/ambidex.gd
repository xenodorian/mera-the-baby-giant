extends Node2D
## Death duel. Port of xenodorian/BeelzTimeKey (godot/main.gd).
## Left hand catches falling letters. Right hand taps the flashed letter. Survive 30s.
## The parent listens for finished(won). Win and loss both leave on their own. Esc pauses this duel and does not quit.

signal finished(won: bool)

const FALL_SEC := 1.0
const RIGHT_WINDOW := 1.0
const RIGHT_PERIOD := 2.0
const SURVIVE_SEC := 30.0
const LEFT := ["W", "A", "S", "D"]
const RIGHT := ["I", "J", "K", "L"]

const INK := Color("#12110e")
const PANEL := Color("#1e1b17")
const CREAM := Color("#f3ecdf")
const MUTED := Color("#9c9486")
const SIGNAL := Color("#ff5a1f")

const IDLE_W := 46
const IDLE_H := 55
const IDLE_N := 10
const SLASH_W := 160
const SLASH_H := 64
const SLASH_N := 17
const SLASH_FPS := 20.0
const PERRY_IDLE_N := 4
const PERRY_IDLE := Vector2(132, 93)
const PERRY_SLASH_N := 6
const PERRY_SLASH := Vector2(222, 93)
const REAP_IDLE_N := 8
const REAP_IDLE := Vector2(192, 150)
const REAP_IDLE_FPS := 8.0
const REAP_ATK_N := 10
const REAP_ATK := Vector2(602, 234)
const REAP_ATK_FPS := 10.0
const REAP_HURT_N := 15
const REAP_HURT := Vector2(424, 194)
const REAP_HURT_FPS := 10.0
const REAP_DEATH_N := 14
const REAP_DEATH := Vector2(514, 294)
const REAP_DEATH_FPS := 10.0
const REAP_IDLE_FOOT := Vector2(111, 148)
const REAP_ATK_FOOT := Vector2(416, 232)
const REAP_HURT_FOOT := Vector2(307, 192)
const REAP_DEATH_FOOT := Vector2(352, 292)
const END_HOLD := 2.2
const DIED_COLS := 4
const DIED_CELL := Vector2(640, 360)
const CHEAT_COLS := 8
const CHEAT_CELL := Vector2(480, 270)
const CHEAT_DUR: PackedFloat32Array = [
	0.08,
	0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 0.04,
	0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 0.04,
	0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 0.04,
	0.08, 0.08, 0.08, 0.08, 0.08, 0.08, 0.08,
	1.24,
]

var idle_tex: Texture2D = preload("res://ambidex/art/mera-idle.png")
var slash_tex: Texture2D = preload("res://ambidex/art/mera-slash.png")
var reap_idle_tex: Texture2D = preload("res://ambidex/art/reaper_idle.png")
var reap_atk_tex: Texture2D = preload("res://ambidex/art/reaper_attack.png")
var reap_hurt_tex: Texture2D = preload("res://ambidex/art/reaper_hurt.png")
var reap_death_tex: Texture2D = preload("res://ambidex/art/reaper_death.png")
var died_tex: Texture2D = preload("res://ambidex/art/you-died.png")
var cheat_tex: Texture2D = preload("res://ambidex/art/you-cheated.png")
var bgm_stream: AudioStream = preload("res://ambidex/audio/bgm.mp3")
var land_sfx: AudioStream = preload("res://ambidex/audio/land.wav")
var block_sfx: AudioStream = preload("res://ambidex/audio/block.wav")
var hurt_sfx: AudioStream = preload("res://ambidex/audio/hurt.wav")
var as_perry := false

var state := "menu"
var score := 0
var best := 0
var combo := 0
var hp := 100
var pain := 0
var keys: Array = []
var cycle := 0.0
var caught := false
var expired := false
var flash := "K"
var successes := 0
var time := 0.0
var particles: Array = []
var floaters: Array = []
var button := Rect2()
var duel := "idle"
var duel_age := 0.0
var ending_time := 0.0
var survived := 0.0
var input_method := "keys"
var pad_style := ""
var ask_pad := false
var pad_highlight := "xbox"
var pad_dismissed := false
var paused_for_ask := false
var pad_lock_until := 0
var muted := false
var audio_ready := false
var death_age := 0.0
var sent := false
var bgm_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if as_perry:
		idle_tex = load("res://ambidex/art/perry-idle.png")
		slash_tex = load("res://ambidex/art/perry-slash.png")
	best = _load_best()
	_load_pad()
	Input.joy_connection_changed.connect(_on_joy_connection)
	start_run()


func _exit_tree() -> void:
	if bgm_player:
		bgm_player.stop()

func _load_pad() -> void:
	var path := "user://pad.txt"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var raw := file.get_as_text().strip_edges()
	if raw == "xbox" or raw == "playstation":
		pad_style = raw

func _save_pad() -> void:
	var file := FileAccess.open("user://pad.txt", FileAccess.WRITE)
	if file:
		file.store_string(pad_style)

func _boot_audio() -> void:
	if audio_ready:
		return
	audio_ready = true
	bgm_player = AudioStreamPlayer.new()
	add_child(bgm_player)
	var stream := bgm_stream.duplicate()
	if stream is AudioStreamMP3:
		stream.loop = true
	bgm_player.stream = stream
	bgm_player.volume_db = -80.0 if muted else -14.0
	bgm_player.play()
	for _i in 4:
		var player := AudioStreamPlayer.new()
		player.volume_db = -3.0
		add_child(player)
		sfx_players.append(player)

func _toggle_mute() -> void:
	_boot_audio()
	muted = not muted
	if bgm_player:
		bgm_player.volume_db = -80.0 if muted else -14.0

func _blow(kind: String) -> void:
	_boot_audio()
	if muted:
		return
	var stream := land_sfx
	if kind == "block":
		stream = block_sfx
	elif kind == "hurt":
		stream = hurt_sfx
	for player in sfx_players:
		if not player.playing:
			player.stream = stream
			player.play()
			return
	sfx_players[0].stream = stream
	sfx_players[0].play()

func _glyph(letter: String) -> String:
	var style := Controls.prompt_style()
	if style == "key":
		return letter
	if style == "playstation":
		match letter:
			"W": return "↑"
			"A": return "←"
			"S": return "↓"
			"D": return "→"
			"I": return "△"
			"J": return "□"
			"K": return "×"
			"L": return "○"
	else:
		match letter:
			"W": return "↑"
			"A": return "←"
			"S": return "↓"
			"D": return "→"
			"I": return "Y"
			"J": return "X"
			"K": return "A"
			"L": return "B"
	return letter

func _open_ask() -> void:
	if ask_pad:
		return
	ask_pad = true
	if pad_style == "playstation" or pad_style == "xbox":
		pad_highlight = pad_style
	if state == "play":
		state = "pause"
		paused_for_ask = true

func _confirm_style(next: String) -> void:
	pad_style = next
	pad_highlight = next
	input_method = "pad"
	_save_pad()
	ask_pad = false
	paused_for_ask = false
	_boot_audio()
	if state == "menu":
		start_run()
	elif state == "pause":
		state = "play"

func _dismiss_pad() -> void:
	pad_dismissed = true
	input_method = "keys"
	ask_pad = false
	if paused_for_ask and state == "pause":
		state = "play"
	paused_for_ask = false
	if state == "menu":
		start_run()

func _on_joy_connection(_device: int, connected: bool) -> void:
	if not connected:
		if Input.get_connected_joypads().is_empty():
			pad_dismissed = false
		return

func _ask_rects(size: Vector2) -> Dictionary:
	var card_w := 250.0
	var card_h := 210.0
	var y := size.y * 0.30
	return {
		"xbox": Rect2(size.x * 0.5 - card_w - 12.0, y, card_w, card_h),
		"ps": Rect2(size.x * 0.5 + 12.0, y, card_w, card_h),
		"keep": Rect2(size.x * 0.5 - 150.0, y + card_h + 20.0, 300.0, 48.0),
	}

func _style_button_rect(size: Vector2) -> Rect2:
	return Rect2(size.x * 0.5 - 160.0, size.y * 0.64 + 72.0, 320.0, 44.0)

func _load_best() -> int:
	var path := "user://best.txt"
	if not FileAccess.file_exists(path):
		return 0
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	return int(file.get_as_text())

func _save_best() -> void:
	var file := FileAccess.open("user://best.txt", FileAccess.WRITE)
	if file:
		file.store_string(str(best))

func _layout() -> Dictionary:
	var size := get_viewport_rect().size
	var hit_y := maxf(210.0, size.y * 0.68)
	var zone_h := clampf(size.y * 0.2, 112.0, 160.0)
	var key_size := clampf(zone_h * 0.58, 64.0, 96.0)
	return {
		"size": size,
		"hit_y": hit_y,
		"zone_h": zone_h,
		"key_size": key_size,
		"lane_x": size.x * 0.25,
	}

func _key_y(age: float, layout: Dictionary) -> float:
	var key_size: float = layout.key_size
	var height: float = layout.size.y
	var start := -key_size * 0.5
	var end := height + key_size * 0.5
	var t := clampf(age / FALL_SEC, 0.0, 1.0)
	return start + (end - start) * t

func _touching(y: float, layout: Dictionary) -> bool:
	var half: float = layout.key_size * 0.5
	var top: float = layout.hit_y - layout.zone_h * 0.5
	var bottom: float = layout.hit_y + layout.zone_h * 0.5
	return y + half >= top and y - half <= bottom

func _passed(y: float, layout: Dictionary) -> bool:
	return y - layout.key_size * 0.5 > layout.hit_y + layout.zone_h * 0.5

func _pick(list: Array, avoid: String = "") -> String:
	var choice: String = list[randi() % list.size()]
	if list.size() > 1 and choice == avoid:
		choice = list[(list.find(choice) + 1) % list.size()]
	return choice

func _right_live() -> bool:
	return state == "play" and cycle < RIGHT_WINDOW and not caught

func _arm_right() -> void:
	flash = _pick(RIGHT, flash)
	caught = false
	expired = false

func _spawn(layout: Dictionary) -> void:
	var key := {"letter": _pick(LEFT), "age": 0.0, "state": "live"}
	keys.append(key)

func start_run() -> void:
	_boot_audio()
	state = "play"
	score = 0
	combo = 0
	hp = 100
	pain = 0
	successes = 0
	cycle = 0.0
	keys.clear()
	particles.clear()
	floaters.clear()
	duel = "idle"
	duel_age = 0.0
	ending_time = 0.0
	survived = 0.0
	_arm_right()
	_spawn(_layout())

func _hurt(amount: int) -> void:
	if state != "play" or hp <= 0:
		return
	hp = maxi(0, hp - amount)
	pain = amount
	combo = 0
	if hp == 0:
		state = "over"
		ending_time = 0.0

func _cue(kind: String) -> void:
	duel = kind
	duel_age = 0.0
	var layout := _layout()
	var note := ""
	var at := Vector2(layout.size.x * 0.5, layout.size.y * 0.36)
	if kind == "parry":
		note = "PARRY"
	elif kind == "guard":
		note = "BLOCK"
		at.x = layout.size.x * 0.47
	elif kind == "struck":
		note = "HIT"
		at.x = layout.size.x * 0.4
	if note != "":
		floaters.append({"pos": at, "text": note, "life": 0.7})

func _award(side: String, at: Vector2) -> void:
	combo += 1
	var gained := 100 + combo * 12
	score += gained
	if score > best:
		best = score
		_save_best()
	successes += 1
	floaters.append({"pos": at + Vector2(0, -18), "text": "+%d" % gained, "life": 0.7})
	for i in 22:
		var angle := TAU * float(i) / 22.0 + randf() * 0.3
		var speed := 90.0 + randf() * 220.0
		particles.append({
			"pos": at,
			"vel": Vector2(cos(angle), sin(angle)) * speed + Vector2(0, -60),
			"life": 0.28 + randf() * 0.28,
			"max": 0.5,
			"side": side,
		})
	_blow("land" if side == "L" else "block")
	_cue("slash" if side == "L" else "guard")

func _press_letter(letter: String) -> void:
	if state == "menu" and (letter in LEFT or letter in RIGHT):
		start_run()
		return
	if state != "play":
		return
	var layout := _layout()
	if letter in LEFT:
		var found = null
		var any_touching := false
		for key in keys:
			if key.state != "live":
				continue
			var y := _key_y(key.age, layout)
			if not _touching(y, layout):
				continue
			any_touching = true
			if key.letter == letter:
				found = key
		if not any_touching or found == null:
			_cue("shield")
			_blow("block")
			_blow("hurt")
			_hurt(1)
			return
		_award("L", Vector2(layout.lane_x, _key_y(found.age, layout)))
		keys.erase(found)
		return
	if letter in RIGHT:
		if not _right_live() or letter != flash:
			_cue("shield")
			_blow("block")
			_blow("hurt")
			_hurt(1)
			return
		caught = true
		_award("R", Vector2(layout.size.x * 0.75, maxf(180.0, layout.size.y * 0.46)))

func _joy_letter(button_index: JoyButton) -> String:
	match button_index:
		JOY_BUTTON_DPAD_UP: return "W"
		JOY_BUTTON_DPAD_DOWN: return "S"
		JOY_BUTTON_DPAD_LEFT: return "A"
		JOY_BUTTON_DPAD_RIGHT: return "D"
		JOY_BUTTON_Y: return "I"
		JOY_BUTTON_X: return "J"
		JOY_BUTTON_A: return "K"
		JOY_BUTTON_B: return "L"
	return ""

func _input(event: InputEvent) -> void:
	var size := get_viewport_rect().size
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			var w := get_window()
			w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_M:
			_toggle_mute()
			get_viewport().set_input_as_handled()
			return
		if ask_pad and event.keycode == KEY_ESCAPE:
			_dismiss_pad()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE and state == "play":
			state = "pause"
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE and state == "pause":
			state = "play"
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			return
		var letter := ""
		match event.keycode:
			KEY_W: letter = "W"
			KEY_A: letter = "A"
			KEY_S: letter = "S"
			KEY_D: letter = "D"
			KEY_I: letter = "I"
			KEY_J: letter = "J"
			KEY_K: letter = "K"
			KEY_L: letter = "L"
		if letter != "":
			input_method = "keys"
			_boot_audio()
			if ask_pad:
				_dismiss_pad()
			elif state != "over" and state != "win" and state != "death":
				_press_letter(letter)
			get_viewport().set_input_as_handled()
	if event is InputEventJoypadButton and event.pressed:
		if Time.get_ticks_msec() < pad_lock_until:
			return
		if ask_pad:
			if event.button_index == JOY_BUTTON_DPAD_LEFT:
				pad_highlight = "xbox"
			elif event.button_index == JOY_BUTTON_DPAD_RIGHT:
				pad_highlight = "playstation"
			elif event.button_index == JOY_BUTTON_A:
				_confirm_style(pad_highlight)
			return
		input_method = "pad"
		_boot_audio()
		if event.button_index == JOY_BUTTON_START:
			if state == "play":
				state = "pause"
			elif state == "pause":
				state = "play"
			elif state == "menu":
				start_run()
			get_viewport().set_input_as_handled()
			return
		var pad_letter := _joy_letter(event.button_index)
		if pad_letter != "" and state != "over" and state != "win" and state != "death":
			_press_letter(pad_letter)
		get_viewport().set_input_as_handled()
	if event is InputEventAction and event.pressed and not event.is_echo():
		if event.action == "start":
			if state == "play":
				state = "pause"
			elif state == "pause":
				state = "play"
			get_viewport().set_input_as_handled()
			return
		var touch_letter := ""
		match event.action:
			"up": touch_letter = "W"
			"down": touch_letter = "S"
			"left": touch_letter = "A"
			"right": touch_letter = "D"
			"btn_y": touch_letter = "I"
			"btn_x": touch_letter = "J"
			"btn_a": touch_letter = "K"
			"btn_b": touch_letter = "L"
		if touch_letter != "" and state != "over" and state != "win" and state != "death":
			if pad_style == "":
				pad_style = "xbox"
			input_method = "pad"
			_boot_audio()
			if ask_pad:
				_dismiss_pad()
			else:
				_press_letter(touch_letter)
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_boot_audio()
		if ask_pad:
			var rects := _ask_rects(size)
			if rects.xbox.has_point(event.position):
				_confirm_style("xbox")
			elif rects.ps.has_point(event.position):
				_confirm_style("playstation")
			elif rects.keep.has_point(event.position):
				_dismiss_pad()
			return
		if button.has_point(event.position):
			if state == "menu":
				start_run()
			elif state == "pause":
				state = "play"
		get_viewport().set_input_as_handled()

func _advance_right(dt: float) -> void:
	var left := dt
	while left > 0.0 and state == "play":
		if cycle < RIGHT_WINDOW and not caught and not expired:
			var use := minf(RIGHT_WINDOW - cycle, left)
			cycle += use
			left -= use
			if cycle >= RIGHT_WINDOW:
				expired = true
				_cue("struck")
				_blow("land")
				_blow("hurt")
				_hurt(20)
		else:
			var use := minf(RIGHT_PERIOD - cycle, left)
			cycle += use
			left -= use
			if cycle >= RIGHT_PERIOD:
				cycle = 0.0
				_arm_right()

func _process(delta: float) -> void:
	time += delta
	var layout := _layout()
	for i in range(particles.size() - 1, -1, -1):
		particles[i].life -= delta
		particles[i].pos += particles[i].vel * delta
		particles[i].vel.y += 520.0 * delta
		if particles[i].life <= 0.0:
			particles.remove_at(i)
	for i in range(floaters.size() - 1, -1, -1):
		floaters[i].life -= delta
		floaters[i].pos.y -= 36.0 * delta
		if floaters[i].life <= 0.0:
			floaters.remove_at(i)
	if state == "play":
		for i in range(keys.size() - 1, -1, -1):
			var key = keys[i]
			key.age += delta
			var y := _key_y(key.age, layout)
			if key.state == "live" and _passed(y, layout):
				key.state = "missed"
				_cue("parry")
				_blow("block")
				_blow("hurt")
				_hurt(5)
			if key.age >= FALL_SEC:
				keys.remove_at(i)
			if state != "play":
				break
		if state == "play" and keys.is_empty():
			_spawn(layout)
		if state == "play":
			_advance_right(delta)
		if state == "play" and duel != "idle":
			duel_age += delta
			var limit := float(SLASH_N) / SLASH_FPS
			if duel == "slash":
				limit = maxf(limit, float(REAP_HURT_N) / REAP_HURT_FPS)
			elif duel == "guard" or duel == "struck" or duel == "parry":
				limit = maxf(limit, float(REAP_ATK_N) / REAP_ATK_FPS)
			if duel_age >= limit:
				duel = "idle"
				duel_age = 0.0
		if state == "play":
			survived += delta
			if survived >= SURVIVE_SEC:
				survived = SURVIVE_SEC
				state = "death"
				death_age = 0.0
				ending_time = 0.0
				duel = "idle"
	elif state == "death":
		death_age += delta
		if death_age >= float(REAP_DEATH_N) / REAP_DEATH_FPS:
			state = "win"
			ending_time = 0.0
	elif state == "over" or state == "win":
		ending_time += delta
		if ending_time >= END_HOLD and not sent:
			sent = true
			finished.emit(state == "win")
	queue_redraw()

func _blit(tex: Texture2D, src: Rect2, dest: Rect2, flip: bool) -> void:
	if not flip:
		draw_texture_rect_region(tex, dest, src)
		return
	draw_set_transform(Vector2(dest.position.x + dest.size.x, dest.position.y), 0.0, Vector2(-1, 1))
	draw_texture_rect_region(tex, Rect2(Vector2.ZERO, dest.size), src)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _paint_reaper(tex: Texture2D, frame: int, cell: Vector2, foot: Vector2, at: Vector2, scale: float) -> void:
	var src := Rect2(float(frame) * cell.x, 0, cell.x, cell.y)
	var dest := Rect2(at.x - foot.x * scale, at.y - foot.y * scale, cell.x * scale, cell.y * scale)
	_blit(tex, src, dest, false)


func _draw_fighters(layout: Dictionary) -> void:
	if state != "play" and state != "pause" and state != "death":
		return
	var size: Vector2 = layout.size
	var body_h := clampf(minf(size.x, size.y) * 0.2, 86.0, 140.0)
	var scale := body_h / float(IDLE_H)
	var reap_scale := body_h / REAP_IDLE.y
	var slot_top: float = layout.hit_y - layout.zone_h * 0.5
	var feet_y := maxf(body_h + 108.0, minf(slot_top - 18.0, size.y * 0.6))
	var gap := maxf(body_h * 1.45, minf(size.x * 0.22, 220.0))
	var mera_x := size.x * 0.5 - gap * 0.5
	var reaper_x := size.x * 0.5 + gap * 0.5
	var slash_frame := -1
	if state != "death" and (duel == "slash" or duel == "shield" or duel == "parry"):
		slash_frame = mini(SLASH_N - 1, int(duel_age * SLASH_FPS))
	var reaper_hurt := state != "death" and duel == "slash"
	var reaper_attack := state != "death" and (duel == "guard" or duel == "struck" or (duel == "parry" and slash_frame >= 3 and slash_frame <= 8))
	var reap_frame := int(time * REAP_IDLE_FPS) % REAP_IDLE_N
	var mera_ox := 0.0
	var reaper_ox := 0.0
	if duel == "slash" and slash_frame >= 4 and slash_frame <= 11:
		reaper_ox = 12.0
	if duel == "parry" and slash_frame >= 4:
		mera_ox = -12.0
	if duel == "guard":
		mera_ox = -6.0
	if duel == "struck" and int(duel_age * REAP_ATK_FPS) >= 2:
		mera_ox = -18.0
	var bob := 0.0
	if state != "death" and slash_frame < 0 and duel != "guard" and duel != "struck":
		bob = sin(time * 2.4) * 2.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(size.x * 0.5, feet_y + 4.0), gap * 0.28, Color(INK, 0.45))
	var paint_reaper := func() -> void:
		var at := Vector2(reaper_x + reaper_ox, feet_y)
		if state == "death":
			var frame := mini(REAP_DEATH_N - 1, int(death_age * REAP_DEATH_FPS))
			_paint_reaper(reap_death_tex, frame, REAP_DEATH, REAP_DEATH_FOOT, at, reap_scale)
		elif reaper_hurt:
			var frame := mini(REAP_HURT_N - 1, int(duel_age * REAP_HURT_FPS))
			_paint_reaper(reap_hurt_tex, frame, REAP_HURT, REAP_HURT_FOOT, at, reap_scale)
		elif reaper_attack:
			var age := duel_age
			if duel == "parry":
				age = maxf(0.0, duel_age - 3.0 / SLASH_FPS)
			var frame := mini(REAP_ATK_N - 1, int(age * REAP_ATK_FPS))
			_paint_reaper(reap_atk_tex, frame, REAP_ATK, REAP_ATK_FOOT, at, reap_scale)
		else:
			at.y += bob
			_paint_reaper(reap_idle_tex, reap_frame, REAP_IDLE, REAP_IDLE_FOOT, at, reap_scale)
	var idle_frame := int(time * 8.0) % IDLE_N
	var paint_mera := func() -> void:
		if as_perry:
			var k := body_h / PERRY_IDLE.y
			var idle_dw := PERRY_IDLE.x * k
			if slash_frame >= 0:
				var pf := clampi(int(float(slash_frame) * float(PERRY_SLASH_N) / float(SLASH_N)), 0, PERRY_SLASH_N - 1)
				var dw := PERRY_SLASH.x * k
				var dh := PERRY_SLASH.y * k
				_blit(slash_tex, Rect2(pf * PERRY_SLASH.x, 0, PERRY_SLASH.x, PERRY_SLASH.y), Rect2(mera_x - idle_dw * 0.5 + mera_ox, feet_y - dh, dw, dh), false)
			else:
				var fr := int(time * 8.0) % PERRY_IDLE_N
				var dh := PERRY_IDLE.y * k
				_blit(idle_tex, Rect2(fr * PERRY_IDLE.x, 0, PERRY_IDLE.x, PERRY_IDLE.y), Rect2(mera_x - idle_dw * 0.5 + mera_ox, feet_y - dh + bob, idle_dw, dh), false)
			return
		if slash_frame >= 0:
			var dw := float(SLASH_W) * scale
			var dh := float(SLASH_H) * scale
			var col := slash_frame % 4
			var row := int(slash_frame / 4.0)
			_blit(slash_tex, Rect2(col * SLASH_W, row * SLASH_H, SLASH_W, SLASH_H), Rect2(mera_x - 25.0 * scale + mera_ox, feet_y - 62.0 * scale, dw, dh), true)
		else:
			var dw := float(IDLE_W) * scale
			var dh := float(IDLE_H) * scale
			_blit(idle_tex, Rect2(idle_frame * IDLE_W, 0, IDLE_W, IDLE_H), Rect2(mera_x - dw * 0.5 + mera_ox, feet_y - dh + bob, dw, dh), false)
	if reaper_attack or reaper_hurt:
		paint_mera.call()
		paint_reaper.call()
	else:
		paint_reaper.call()
		paint_mera.call()
	if duel == "struck" and int(duel_age * REAP_ATK_FPS) >= 2:
		draw_circle(Vector2(mera_x + mera_ox, feet_y - body_h * 0.48), body_h * 0.34, Color(SIGNAL, 0.35))
	if duel == "shield":
		var hot := slash_frame >= 4
		var radius := body_h * (0.78 if hot else 0.7)
		var center := Vector2(reaper_x, feet_y - body_h * 0.46)
		draw_circle(center, radius, Color(0.45, 0.75, 1.0, 0.22))
		draw_arc(center, radius, 0.0, TAU, 48, Color(0.85, 0.95, 1.0, 0.95 if hot else 0.8), 4.0 if hot else 3.0, true)
		draw_circle(center + Vector2(-radius * 0.32, -radius * 0.36), radius * 0.12, Color(1, 1, 1, 0.75))
	if duel == "guard":
		var center := Vector2(mera_x + body_h * 0.42, feet_y - body_h * 0.5)
		var radius := body_h * 0.28
		draw_circle(center, radius, Color(CREAM, 0.94))
		draw_arc(center, radius, 0.0, TAU, 40, SIGNAL, 4.0, true)
		draw_arc(center, radius * 0.45, 0.0, TAU, 32, Color(INK, 0.85), 2.0, true)
	if duel == "parry" and slash_frame >= 3 and slash_frame <= 8:
		var center := Vector2(size.x * 0.5, feet_y - body_h * 0.45)
		var s := body_h * 0.22
		draw_line(center + Vector2(-s, -s), center + Vector2(s, s), CREAM, 4.0, true)
		draw_line(center + Vector2(s, -s), center + Vector2(-s, s), CREAM, 4.0, true)
		draw_arc(center, s * 0.9, 0.0, TAU, 32, SIGNAL, 2.0, true)

func _ending_frame(durs: PackedFloat32Array, looping: bool) -> int:
	var total := 0.0
	for d in durs:
		total += d
	var t := ending_time
	if looping:
		t = fmod(t, total)
	var acc := 0.0
	for i in durs.size():
		acc += durs[i]
		if t < acc:
			return i
	return durs.size() - 1

func _draw_card(tex: Texture2D, frame: int, cols: int, cell: Vector2, area: Rect2) -> void:
	var src := Rect2(Vector2((frame % cols) * cell.x, int(frame / cols) * cell.y), cell)
	var scale := minf(area.size.x / cell.x, area.size.y / cell.y)
	var dw := cell.x * scale
	var dh := cell.y * scale
	var dest := Rect2(area.position.x + (area.size.x - dw) * 0.5, area.position.y + (area.size.y - dh) * 0.5, dw, dh)
	draw_texture_rect_region(tex, dest, src)

func _draw_ending(layout: Dictionary) -> void:
	var size: Vector2 = layout.size
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK, true)
	var footer := 92.0
	var area := Rect2(0, 0, size.x, maxf(32.0, size.y - footer))
	if state == "over":
		var durs: PackedFloat32Array = [0.08, 0.08, 0.08, 0.08, 0.08, 0.08, 0.08, 0.08]
		_draw_card(died_tex, _ending_frame(durs, true), DIED_COLS, DIED_CELL, area)
	else:
		_draw_card(cheat_tex, _ending_frame(CHEAT_DUR, false), CHEAT_COLS, CHEAT_CELL, area)
	var font := ThemeDB.fallback_font
	var score_line := "Score %d" % score
	if best > 0:
		score_line += "  ·  Best %d" % best
	draw_string(font, Vector2(size.x * 0.5 - 70, size.y - 68), score_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, CREAM)
	button = Rect2()
	draw_string(font, Vector2(size.x * 0.5 - 90, size.y - 36), "Back to the title", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, MUTED)

func _arrow_dir(letter: String) -> String:
	match letter:
		"↑": return "up"
		"↓": return "down"
		"←": return "left"
		"→": return "right"
	return ""

func _draw_thick_arrow(center: Vector2, length: float, dir: String) -> void:
	var height := length
	var width := length * 0.96
	var shaft := width * 0.62
	var head := height * 0.46
	var raw := PackedVector2Array([
		Vector2(0, -height * 0.5),
		Vector2(width * 0.5, -height * 0.5 + head),
		Vector2(shaft * 0.5, -height * 0.5 + head),
		Vector2(shaft * 0.5, height * 0.5),
		Vector2(-shaft * 0.5, height * 0.5),
		Vector2(-shaft * 0.5, -height * 0.5 + head),
		Vector2(-width * 0.5, -height * 0.5 + head),
	])
	var angle := 0.0
	if dir == "right":
		angle = PI / 2.0
	elif dir == "down":
		angle = PI
	elif dir == "left":
		angle = -PI / 2.0
	var transformed := PackedVector2Array()
	var basis := Transform2D(angle, center)
	for point in raw:
		transformed.append(basis * point)
	draw_colored_polygon(transformed, INK)

func _draw_keycap(center: Vector2, size: float, letter: String, fill: Color) -> void:
	var body := Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size))
	draw_rect(body, fill.darkened(0.35), true)
	var top := Rect2(body.position + Vector2(size * 0.08, size * 0.06), Vector2(size * 0.84, size * 0.72))
	draw_rect(top, fill, true)
	var dir := _arrow_dir(letter)
	if dir != "":
		_draw_thick_arrow(center + Vector2(0, -size * 0.06), size * 0.62, dir)
	else:
		draw_string(ThemeDB.fallback_font, center + Vector2(-size * 0.12, size * 0.08), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size * 0.42), INK)

func _draw() -> void:
	var layout := _layout()
	var size: Vector2 = layout.size
	draw_rect(Rect2(Vector2.ZERO, size), INK, true)
	draw_rect(Rect2(0, 0, size.x * 0.5, size.y), PANEL.darkened(0.25), true)
	draw_rect(Rect2(size.x * 0.5, 0, size.x * 0.5, size.y), PANEL, true)
	draw_rect(Rect2(size.x * 0.5 - 1, 0, 2, size.y), CREAM.darkened(0.55), true)
	var font := ThemeDB.fallback_font
	var hands := _hand_labels()
	draw_string(font, Vector2(size.x * 0.25 - 70, 128), String(hands[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
	draw_string(font, Vector2(size.x * 0.75 - 90, 128), String(hands[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
	_draw_fighters(layout)
	var slot := Rect2(layout.lane_x - (layout.key_size + 36) * 0.5, layout.hit_y - layout.zone_h * 0.5, layout.key_size + 36, layout.zone_h)
	draw_rect(slot, INK, true)
	var hot := false
	for key in keys:
		if key.state == "live" and _touching(_key_y(key.age, layout), layout):
			hot = true
	draw_rect(slot, SIGNAL if hot else MUTED, false, 2.0)
	for key in keys:
		var fill := CREAM if key.state == "live" else SIGNAL.lightened(0.2)
		_draw_keycap(Vector2(layout.lane_x, _key_y(key.age, layout)), layout.key_size, _glyph(key.letter), fill)
	if state != "play" and state != "death":
		_draw_keycap(Vector2(layout.lane_x, layout.hit_y), layout.key_size, _glyph("W"), CREAM)
	var shown := ""
	if state == "death":
		shown = ""
	elif state != "play":
		shown = _glyph("K")
	elif _right_live():
		shown = _glyph(flash)
	if shown != "":
		var letter_size := int(minf(size.x * 0.16, 140.0))
		draw_string(font, Vector2(size.x * 0.75 - letter_size * 0.32, maxf(180.0, size.y * 0.46) + letter_size * 0.28), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, letter_size, SIGNAL)
	draw_string(font, Vector2(28, 42), "AMBIDEX", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, CREAM)
	draw_string(font, Vector2(size.x * 0.5 - 28, 48), str(hp), HORIZONTAL_ALIGNMENT_LEFT, -1, 36, CREAM)
	var pain_text := "HP" if pain <= 0 else "-%d HP" % pain
	draw_string(font, Vector2(size.x * 0.5 - 24, 70), pain_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, SIGNAL)
	draw_string(font, Vector2(size.x - 140, 42), str(score), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, CREAM)
	draw_string(font, Vector2(size.x - 140, 64), "Best %d" % best, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
	var bar := Rect2(28, 84, size.x - 56, 10)
	draw_rect(bar, PANEL, true)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(hp) / 100.0, bar.size.y)), SIGNAL, true)
	var left := maxf(0.0, SURVIVE_SEC - survived)
	var time_bar := Rect2(28, 98, size.x - 56, 6)
	draw_rect(time_bar, PANEL, true)
	draw_rect(Rect2(time_bar.position, Vector2(time_bar.size.x * left / SURVIVE_SEC, time_bar.size.y)), CREAM, true)
	draw_string(font, Vector2(28, 68), "%.1f" % left, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, CREAM)
	for spark in particles:
		var alpha := clampf(spark.life / spark.max, 0.0, 1.0)
		var color := CREAM if spark.side == "L" else SIGNAL
		color.a = alpha
		draw_circle(spark.pos, 3.0, color)
	for floater in floaters:
		draw_string(font, floater.pos, floater.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, CREAM)
	_draw_overlay(layout)
	if ask_pad:
		_draw_ask(size)

func _hand_labels() -> Array:
	match Controls.prompt_style():
		"key":
			return ["LEFT HAND  ·  WASD", "RIGHT HAND  ·  IJKL"]
		"playstation":
			return ["LEFT HAND  ·  D-PAD", "RIGHT HAND  ·  × ○ □ △"]
		"touch":
			return ["LEFT HAND  ·  D-PAD", "RIGHT HAND  ·  A B X Y"]
		_:
			return ["LEFT HAND  ·  D-PAD", "RIGHT HAND  ·  A B X Y"]


func _draw_style_card(rect: Rect2, title: String, detail: String, top: String, left: String, right: String, bottom: String, active: bool) -> void:
	draw_rect(rect, INK, true)
	if active:
		draw_rect(rect, SIGNAL, false, 3.0)
	var font := ThemeDB.fallback_font
	draw_string(font, rect.position + Vector2(16, 32), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, SIGNAL)
	draw_string(font, rect.position + Vector2(16, 56), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
	var center := rect.position + Vector2(rect.size.x * 0.5, 128)
	draw_string(font, center + Vector2(-10, -36), top, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, CREAM)
	draw_string(font, center + Vector2(-52, 4), left, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, CREAM)
	draw_string(font, center + Vector2(28, 4), right, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, CREAM)
	draw_string(font, center + Vector2(-10, 42), bottom, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, CREAM)

func _draw_ask(size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(INK, 0.94), true)
	var font := ThemeDB.fallback_font
	var rects := _ask_rects(size)
	draw_string(font, Vector2(size.x * 0.5 - 150, size.y * 0.16), "WHICH FACE BUTTONS?", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, CREAM)
	draw_string(font, Vector2(size.x * 0.5 - 230, size.y * 0.22), "D-pad is the left hand. Left or right to choose. Bottom button confirms.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, MUTED)
	_draw_style_card(rects.xbox, "XBOX", "A B X Y", "Y", "X", "B", "A", pad_highlight == "xbox")
	_draw_style_card(rects.ps, "PLAYSTATION", "× ○ □ △", "△", "□", "○", "×", pad_highlight == "playstation")
	draw_rect(rects.keep, PANEL, true)
	draw_string(font, rects.keep.position + Vector2(82, 32), "Keep keyboard", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, CREAM)

func _draw_overlay(layout: Dictionary) -> void:
	if state == "play" or state == "death":
		button = Rect2()
		return
	if state == "over" or state == "win":
		_draw_ending(layout)
		return
	var size: Vector2 = layout.size
	draw_rect(Rect2(Vector2.ZERO, size), Color(INK, 0.9), true)
	var font := ThemeDB.fallback_font
	var title := "SPLIT ATTENTION"
	var body := "Left hand catches. Right hand taps.\nSurvive 30 seconds."
	var action := "Start"
	if state == "pause":
		title = "PAUSED"
		body = "Esc, Start, or the button resumes."
		action = "Resume"
	draw_string(font, Vector2(size.x * 0.5 - 90, size.y * 0.32), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, SIGNAL)
	draw_string(font, Vector2(size.x * 0.5 - 180, size.y * 0.40), "AMBIDEX", HORIZONTAL_ALIGNMENT_LEFT, -1, 54, CREAM)
	draw_multiline_string(font, Vector2(size.x * 0.5 - 190, size.y * 0.50), body, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 24, CREAM)
	button = Rect2(size.x * 0.5 - 160, size.y * 0.64, 320, 56)
	draw_rect(button, SIGNAL, true)
	draw_string(font, button.position + Vector2(110, 36), action, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK)
	if state == "menu" or state == "pause":
		var style_rect := _style_button_rect(size)
		draw_rect(style_rect, INK, true)
		draw_string(font, style_rect.position + Vector2(28, 30), "Prompts: %s" % Controls.prompt_label(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, CREAM)
	if state == "menu":
		var hint := "or press any game key"
		if input_method == "pad":
			hint = "or press a controller button"
		draw_string(font, Vector2(size.x * 0.5 - 110, button.end.y + 132), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
		if best > 0:
			draw_string(font, Vector2(size.x * 0.5 - 40, button.end.y + 156), "Best %d" % best, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, CREAM)
