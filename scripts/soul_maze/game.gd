extends Node2D
## Soul Maze. Arrows, the touch pad, and a gamepad d-pad or left stick move.
## Enter or Start begins a run and restarts after a win or a catch. B or Esc returns to the title.

const Board := preload("res://scripts/soul_maze/maze.gd")
const COLS := 23
const ROWS := 13
const PLAYER_SPEED := 5.6
const GHOST_SPEED := 4.85
const FRIGHT_SPEED := 3.15
const EATEN_SPEED := 8.0

var grid: Array = []
var px := 1.0
var py := 1.0
var spawn := Vector2i(1, 1)
var dir := Vector2i.ZERO
var want := Vector2i.ZERO
var facing := 1
var moving := false
var ghosts: Array = []
var door := Vector2i(11, 5)
var score := 0
var souls_left := 0
var souls_total := 0
var phase := "ready"
var mode := "chase"
var wave := 0
var mode_time := 20.0
var fright := 0.0
var anim := 0.0
var tunnels := {}

var mera: Array[Texture2D] = []
var reaper: Array[Texture2D] = []
var soul: Array[Texture2D] = []
var coin: Texture2D
var font: Font
var _steer_g: Dictionary


func _steer_player(_here: Vector2i) -> Vector2i:
	return want


func _steer_ghost(here: Vector2i) -> Vector2i:
	_steer_g["x"] = float(here.x)
	_steer_g["y"] = float(here.y)
	return _ghost_dir(_steer_g)


func _ready() -> void:
	font = ThemeDB.fallback_font
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for i in 4:
		mera.append(load("res://soul_maze/art/mera_%d.png" % i))
	for i in 8:
		reaper.append(load("res://soul_maze/art/reaper_%d.png" % i))
	for i in 12:
		soul.append(load("res://soul_maze/art/soul_%d.png" % i))
	coin = load("res://soul_maze/art/coin.png")
	_new_maze()


func _new_maze() -> void:
	grid = Board.generate()
	tunnels.clear()
	ghosts.clear()
	var homes: Array[Vector2i] = []
	souls_left = 0
	for y in ROWS:
		var row: String = grid[y]
		if row[0] != "#":
			tunnels[y] = true
		for x in COLS:
			var t := row[x]
			if t == "P":
				spawn = Vector2i(x, y)
				_put(x, y, " ")
			elif t == "G":
				homes.append(Vector2i(x, y))
			elif t == "=":
				door = Vector2i(x, y)
			elif t == "o":
				souls_left += 1
	souls_total = souls_left
	score = 0
	px = float(spawn.x)
	py = float(spawn.y)
	dir = Vector2i.ZERO
	want = Vector2i.ZERO
	moving = false
	fright = 0.0
	mode = "chase"
	wave = 0
	mode_time = 20.0
	phase = "ready"
	var scatter := [
		_nearest_open(COLS - 2, 1),
		_nearest_open(1, 1),
		_nearest_open(COLS - 2, ROWS - 2),
		_nearest_open(1, ROWS - 2),
	]
	for i in 4:
		var home: Vector2i = homes[i % homes.size()]
		ghosts.append({
			"x": float(home.x), "y": float(home.y),
			"dir": Vector2i(signi(door.x - home.x), -1 if home.x == door.x else 0),
			"state": "out", "scatter": scatter[i], "home": home, "bob": i,
		})


func _put(x: int, y: int, ch: String) -> void:
	var row: String = grid[y]
	grid[y] = row.substr(0, x) + ch + row.substr(x + 1)


func _at(x: int, y: int) -> String:
	if y < 0 or y >= ROWS:
		return "#"
	if x < 0 or x >= COLS:
		if not tunnels.has(y):
			return "#"
		x = posmod(x, COLS)
	return grid[y][x]


func _blocked(x: int, y: int, who: String) -> bool:
	var t := _at(x, y)
	if t == "#":
		return true
	if (who == "player" or who == "roam") and (t == "=" or t == "G"):
		return true
	return false


func _nearest_open(x: int, y: int) -> Vector2i:
	var best := Vector2i(1, 1)
	var best_d := 100000
	for yy in ROWS:
		for xx in COLS:
			if _blocked(xx, yy, "eyes"):
				continue
			var d := absi(xx - x) + absi(yy - y)
			if d < best_d:
				best_d = d
				best = Vector2i(xx, yy)
	return best


func _wrap(x: float, y: float) -> float:
	if not tunnels.has(int(round(y))):
		return x
	if x < -0.5:
		return x + COLS
	if x > COLS - 0.5:
		return x - COLS
	return x


func _held_dir() -> Vector2i:
	var x := 0
	var y := 0
	if Input.is_action_pressed("left"):
		x -= 1
	if Input.is_action_pressed("right"):
		x += 1
	if Input.is_action_pressed("up"):
		y -= 1
	if Input.is_action_pressed("down"):
		y += 1
	if x == 0 and y == 0:
		return Vector2i.ZERO
	if x != 0 and y != 0:
		if absi(x) == absi(y):
			return Vector2i(x, 0) if want.x != 0 else Vector2i(0, y)
		return Vector2i(x, 0) if absi(x) > absi(y) else Vector2i(0, y)
	return Vector2i(x, y)


func _begin() -> void:
	if phase == "won" or phase == "over":
		_new_maze()
	phase = "play"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("start") or event.is_action_pressed("ui_accept"):
		if phase != "play":
			_begin()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("btn_b") or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE):
		# Deferred. Changing scene inside this callback frees the node that is
		# still handling the key, and the title treats that same Escape as quit.
		get_tree().change_scene_to_file.call_deferred("res://scenes/menu.tscn")
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	anim += delta
	var held := _held_dir()
	if held != Vector2i.ZERO:
		want = held
	if phase == "play":
		_step(delta)
	queue_redraw()


func _cruise(x: float, y: float, d: Vector2i, dist: float, who: String) -> Dictionary:
	if d == Vector2i.ZERO:
		return {"x": round(x), "y": round(y), "center": true, "left": 0.0, "stopped": true}
	if d.x != 0:
		y = round(y)
	else:
		x = round(x)
	var sign: float = float(d.x if d.x != 0 else d.y)
	var along: float = x if d.x != 0 else y
	var center: float = ceil(along - 0.0001) if sign > 0.0 else floor(along + 0.0001)
	var to_center: float = abs(center - along)
	var place := func(pos: float) -> Vector2:
		var nx := pos if d.x != 0 else x
		var ny := pos if d.y != 0 else y
		if d.x != 0:
			nx = _wrap(nx, ny)
		return Vector2(nx, ny)
	var next_blocked := func() -> bool:
		var tx := int(center) + d.x if d.x != 0 else int(round(x))
		var ty := int(center) + d.y if d.y != 0 else int(round(y))
		return _blocked(tx, ty, who)
	if to_center <= 0.0001:
		if next_blocked.call():
			var p: Vector2 = place.call(center)
			return {"x": p.x, "y": p.y, "center": true, "left": 0.0, "stopped": true}
		var travel := minf(dist, 1.0)
		var landed := travel >= 1.0 - 0.0001
		var p2: Vector2 = place.call(center + sign * travel)
		return {"x": p2.x, "y": p2.y, "center": landed, "left": dist - 1.0 if landed else 0.0, "stopped": false}
	if dist < to_center - 0.000001:
		var p3: Vector2 = place.call(along + sign * dist)
		return {"x": p3.x, "y": p3.y, "center": false, "left": 0.0, "stopped": false}
	if next_blocked.call():
		var p4: Vector2 = place.call(center)
		return {"x": p4.x, "y": p4.y, "center": true, "left": 0.0, "stopped": true}
	var p5: Vector2 = place.call(center)
	return {"x": p5.x, "y": p5.y, "center": true, "left": dist - to_center, "stopped": false}


func _slide(x: float, y: float, d: Vector2i, dist: float, who: String, steer: Callable) -> Dictionary:
	var moved := false
	var guard := 0
	while guard < 4 and dist > 0.00001:
		guard += 1
		var hit: Dictionary = _cruise(x, y, d, dist, who)
		x = hit["x"]
		y = hit["y"]
		if hit["stopped"]:
			var sx := int(round(x))
			var sy := int(round(y))
			var next: Vector2i = steer.call(Vector2i(sx, sy))
			if next != Vector2i.ZERO and next != d and not _blocked(sx + next.x, sy + next.y, who):
				return {"x": float(sx), "y": float(sy), "dir": next, "moving": false}
			return {"x": float(sx), "y": float(sy), "dir": d, "moving": false}
		moved = true
		if not hit["center"]:
			return {"x": x, "y": y, "dir": d, "moving": true}
		x = round(x)
		y = round(y)
		var next_dir: Vector2i = steer.call(Vector2i(int(x), int(y)))
		if next_dir != Vector2i.ZERO and next_dir != d and not _blocked(int(x) + next_dir.x, int(y) + next_dir.y, who):
			d = next_dir
		dist = hit["left"]
	return {"x": x, "y": y, "dir": d, "moving": moved}


func _step(delta: float) -> void:
	if fright > 0.0:
		fright = maxf(0.0, fright - delta)
		if fright == 0.0:
			for g in ghosts:
				if g["state"] == "fright":
					g["state"] = "out"
	else:
		mode_time -= delta
		if mode_time <= 0.0:
			var waves := [
				["chase", 20.0], ["scatter", 7.0], ["chase", 20.0], ["scatter", 5.0], ["chase", 20.0], ["scatter", 5.0], ["chase", 1000000.0],
			]
			wave = mini(wave + 1, waves.size() - 1)
			var prev := mode
			mode = waves[wave][0]
			mode_time = waves[wave][1]
			if prev != mode:
				for g in ghosts:
					if g["state"] == "out":
						_reverse(g)
	var cx := int(round(px))
	var cy := int(round(py))
	if want != Vector2i.ZERO:
		if want == -dir:
			dir = want
		elif dir == Vector2i.ZERO or (abs(px - cx) < 0.001 and abs(py - cy) < 0.001):
			if not _blocked(cx + want.x, cy + want.y, "player"):
				px = float(cx)
				py = float(cy)
				dir = want
	if dir.x < 0:
		facing = -1
	elif dir.x > 0:
		facing = 1
	var moved: Dictionary = _slide(px, py, dir, PLAYER_SPEED * delta, "player", _steer_player)
	px = moved["x"]
	py = moved["y"]
	dir = moved["dir"]
	moving = moved["moving"]
	_collect()
	if phase != "play":
		return
	for g in ghosts:
		var who := "eyes" if g["state"] == "eaten" else ("pen" if _at(int(round(g["x"])), int(round(g["y"]))) in ["G", "="] else "roam")
		var speed := EATEN_SPEED if g["state"] == "eaten" else (FRIGHT_SPEED if g["state"] == "fright" else GHOST_SPEED)
		_steer_g = g
		var ghost_moved: Dictionary = _slide(g["x"], g["y"], g["dir"], speed * delta, who, _steer_ghost)
		g["x"] = ghost_moved["x"]
		g["y"] = ghost_moved["y"]
		g["dir"] = ghost_moved["dir"]
	_collide()


func _reverse(g: Dictionary) -> void:
	var back := -Vector2i(g["dir"])
	if back == Vector2i.ZERO:
		return
	var who := "roam"
	if not _blocked(int(round(g["x"])) + back.x, int(round(g["y"])) + back.y, who):
		g["dir"] = back


func _ghost_dir(g: Dictionary) -> Vector2i:
	var here := Vector2i(int(round(g["x"])), int(round(g["y"])))
	if g["state"] == "eaten" and here == g["home"]:
		g["state"] = "out"
	var who := "eyes" if g["state"] == "eaten" else ("pen" if _at(here.x, here.y) in ["G", "="] else "roam")
	var options: Array[Vector2i] = []
	for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]:
		if g["state"] != "eaten" and d == -Vector2i(g["dir"]) and Vector2i(g["dir"]) != Vector2i.ZERO:
			continue
		if not _blocked(here.x + d.x, here.y + d.y, who):
			options.append(d)
	if options.is_empty():
		for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]:
			if not _blocked(here.x + d.x, here.y + d.y, who):
				options.append(d)
	if options.is_empty():
		return g["dir"]
	if who == "pen" and g["state"] != "eaten":
		return _closest(here, options, Vector2i(door.x, door.y - 1))
	if g["state"] == "fright":
		return options[randi() % options.size()]
	var target: Vector2i = g["scatter"]
	if g["state"] == "eaten":
		target = g["home"] if absi(here.x - door.x) + absi(here.y - door.y) <= 1 else door
	elif mode == "chase":
		var index := ghosts.find(g)
		var face := dir if dir != Vector2i.ZERO else Vector2i(facing, 0)
		var player := Vector2i(int(round(px)), int(round(py)))
		if index == 1:
			target = player + face * 4
		elif index == 2:
			var ahead := player + face * 2
			var blinky := Vector2i(int(round(ghosts[0]["x"])), int(round(ghosts[0]["y"])))
			target = ahead * 2 - blinky
		elif index == 3:
			var dx := here.x - player.x
			var dy := here.y - player.y
			target = player if dx * dx + dy * dy >= 64 else g["scatter"]
		else:
			target = player
	return _closest(here, options, target)


func _closest(here: Vector2i, options: Array[Vector2i], target: Vector2i) -> Vector2i:
	var best: Vector2i = options[0]
	var best_d := 10000000
	for d in options:
		var n := here + d
		var dist := (n.x - target.x) * (n.x - target.x) + (n.y - target.y) * (n.y - target.y)
		if dist < best_d:
			best_d = dist
			best = d
	return best


func _collect() -> void:
	var x := int(round(px))
	var y := int(round(py))
	if y < 0 or y >= ROWS or x < 0 or x >= COLS:
		return
	var t := _at(x, y)
	if t == ".":
		_put(x, y, " ")
		score += 10
	elif t == "o":
		_put(x, y, " ")
		score += 50
		souls_left -= 1
		fright = 3.0
		for g in ghosts:
			if g["state"] == "out" or g["state"] == "fright":
				g["state"] = "fright"
				_reverse(g)
		if souls_left <= 0:
			phase = "won"


func _collide() -> void:
	if phase != "play":
		return
	for g in ghosts:
		if g["state"] == "eaten":
			continue
		var dx := float(g["x"]) - px
		if tunnels.has(int(round(py))):
			if dx > float(COLS) * 0.5:
				dx -= COLS
			if dx < float(COLS) * -0.5:
				dx += COLS
		var dy := float(g["y"]) - py
		if dx * dx + dy * dy > 0.32:
			continue
		if g["state"] == "fright":
			g["state"] = "eaten"
			score += 200
			continue
		phase = "over"
		dir = Vector2i.ZERO
		moving = false
		return


func _draw() -> void:
	var view := get_viewport_rect().size
	var tile := minf(view.x * 0.96 / float(COLS), (view.y - 72.0) * 0.96 / float(ROWS))
	var origin := Vector2((view.x - tile * COLS) * 0.5, 64.0 + (view.y - 72.0 - tile * ROWS) * 0.5)
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.047, 0.039, 0.063))
	draw_string(font, Vector2(24, 42), "SOUL MAZE", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.96, 0.94, 0.9))
	draw_string(font, Vector2(0, 42), "Souls %d/%d" % [souls_total - souls_left, souls_total], HORIZONTAL_ALIGNMENT_CENTER, view.x, 28, Color(0.56, 0.83, 1.0))
	draw_string(font, Vector2(0, 42), str(score), HORIZONTAL_ALIGNMENT_RIGHT, view.x - 24.0, 28, Color(0.886, 0.690, 0.290))
	for y in ROWS:
		for x in COLS:
			var t := _at(x, y)
			var r := Rect2(origin + Vector2(x, y) * tile, Vector2(tile, tile))
			if t == "#":
				draw_rect(r, Color(0.886, 0.690, 0.290))
			else:
				draw_rect(r, Color(0.086, 0.071, 0.110))
				if t == "=":
					draw_rect(Rect2(r.position + Vector2(tile * 0.12, tile * 0.38), Vector2(tile * 0.76, maxf(2.0, tile * 0.16))), Color(0.886, 0.690, 0.290))
				elif t == "." and coin:
					var s := tile * 0.32
					draw_texture_rect(coin, Rect2(r.position + (Vector2(tile, tile) - Vector2(s, s)) * 0.5, Vector2(s, s)), false)
				elif t == "o" and not soul.is_empty():
					var frame: Texture2D = soul[int(anim * 12.0) % soul.size()]
					var s2 := tile * 0.62
					draw_texture_rect(frame, Rect2(r.position + (Vector2(tile, tile) - Vector2(s2, s2)) * 0.5, Vector2(s2, s2)), false)
	for g in ghosts:
		var frame: Texture2D = reaper[int(anim * 8.0 + float(g["bob"]) * 3.0) % maxi(1, reaper.size())] if not reaper.is_empty() else null
		var s := tile * (0.5 if g["state"] == "eaten" else 0.78)
		var center := origin + Vector2(float(g["x"]) + 0.5, float(g["y"]) + 0.5) * tile
		var flip := -1.0 if int(g["dir"].x) < 0 else 1.0
		draw_set_transform(center, 0.0, Vector2(flip, 1.0))
		var tint := Color(1, 1, 1, 0.4) if g["state"] == "eaten" else Color.WHITE
		if g["state"] == "fright":
			var flash := fright < 1.0 and int(anim * 8.0) % 2 == 0
			tint = Color.WHITE if flash else Color(0.25, 0.35, 1.0)
		if frame:
			draw_texture_rect(frame, Rect2(Vector2(-s, -s) * 0.5, Vector2(s, s)), false, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not mera.is_empty():
		var frame: Texture2D = mera[int(anim * 10.0) % mera.size() if moving else 0]
		var s := tile * 0.78
		var center := origin + Vector2(px + 0.5, py + 0.5) * tile
		draw_set_transform(center, 0.0, Vector2(float(facing), 1.0))
		draw_texture_rect(frame, Rect2(Vector2(-s, -s) * 0.5, Vector2(s, s)), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if phase != "play":
		draw_rect(Rect2(Vector2.ZERO, view), Color(0.047, 0.039, 0.063, 0.78))
		var title := "SOUL MAZE"
		var body := Controls.faces("Arrows, the pad, or a stick. Start begins.")
		var button := "START"
		if phase == "won":
			title = "SOULS TAKEN"
			body = "Every soul fragment is yours."
			button = "START AGAIN"
		elif phase == "over":
			title = "CAUGHT"
			body = "A reaper got Mera before the last soul."
			button = "START AGAIN"
		draw_string(font, Vector2(0, view.y * 0.40), title, HORIZONTAL_ALIGNMENT_CENTER, view.x, 64, Color(0.886, 0.690, 0.290))
		draw_string(font, Vector2(0, view.y * 0.40 + 80.0), body, HORIZONTAL_ALIGNMENT_CENTER, view.x, 28, Color(0.96, 0.94, 0.9))
		draw_string(font, Vector2(0, view.y * 0.40 + 140.0), button, HORIZONTAL_ALIGNMENT_CENTER, view.x, 32, Color(0.886, 0.690, 0.290))
		draw_string(font, Vector2(0, view.y - 36.0), Controls.faces("B or Esc: title"), HORIZONTAL_ALIGNMENT_CENTER, view.x, 22, Color(0.66, 0.60, 0.50))
