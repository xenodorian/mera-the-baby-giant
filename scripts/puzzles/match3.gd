extends "res://scripts/puzzles/puzzle_host.gd"
## Match three with enemy portraits. Tile kinds are the faces of a few distinct enemies (Roster.face).
## Swap two neighbouring tiles; runs of 3 or more clear, tiles fall, new ones drop in, and cascades pay more.
## Reach Tuning.MATCH_TARGET points before the real-time clock (Tuning.MATCH_TIME_S seconds) runs out. Swaps that match nothing are undone.
## Keyboard / pad: A picks a tile, then a direction swaps it (or A on a neighbour). Touch: drag a tile onto a neighbour, or tap two neighbours.

const TILE := 128.0
const SWAP_S := 0.08
const CLEAR_S := 0.12
const FALL_S := 0.14

var cols := Tuning.MATCH_COLS
var rows := Tuning.MATCH_ROWS
var kinds: Array = []              # enemy ids, one per tile kind
var board: Array = []              # kind index per cell (row-major), -1 = empty
var fall_off: Array = []           # per cell: pixels the tile still has to fall (draw offset)
var cursor := Vector2i(3, 3)
var sel := Vector2i(-1, -1)
var score := 0
var time_left := Tuning.MATCH_TIME_S
var target := Tuning.MATCH_TARGET
var chain := 0
var busy := false
var reshuffles := 0
var origin_px := Vector2.ZERO
var _phase := ""                   # "" | swap | clear | fall
var _phase_t := 0.0
var _swap_a := Vector2i.ZERO
var _swap_b := Vector2i.ZERO
var _clearing: Dictionary = {}
var _bad_t := 0.0
var _press := Vector2.ZERO
var _press_cell := Vector2i(-1, -1)
var _pop_text: String = ""
var _pop_t := 0.0


func title() -> String:
	return "MATCH THE FOES"


func hint_keys() -> String:
	return "Arrows move   A pick, then a direction swaps   B give up"


func hint_touch() -> String:
	return "Drag a face onto a neighbour, or tap two neighbours   Give up: top right"


func hint_size() -> int:
	return 34


func hint_y() -> float:
	return 998.0


func _setup() -> void:
	origin_px = Vector2(PANEL.position.x + 50.0, 190.0)
	var pool: Array = []
	var ids: Array = Roster.ids()
	ids.sort()
	for id in ids:
		if not bool(Roster.def(String(id)).get("boss", false)) and Roster.face(String(id)) != null:
			pool.append(String(id))
	# fewer faces than kinds (a tiny roster) just means fewer kinds
	var want := mini(Tuning.MATCH_KINDS, pool.size())
	for i in want:
		var j := i + rng.randi() % (pool.size() - i)
		var t = pool[i]
		pool[i] = pool[j]
		pool[j] = t
		kinds.append(pool[i])
	_fill_board()


func _fill_board() -> void:
	for attempt in 200:
		board.clear()
		fall_off.clear()
		for y in rows:
			for x in cols:
				var k := rng.randi() % kinds.size()
				var tries := 0
				while _would_match(x, y, k) and tries < 30:
					k = rng.randi() % kinds.size()
					tries += 1
				board.append(k)
				fall_off.append(0.0)
		if _find_matches().is_empty() and not find_move().is_empty():
			return


func _would_match(x: int, y: int, k: int) -> bool:
	if x >= 2 and board[y * cols + x - 1] == k and board[y * cols + x - 2] == k:
		return true
	if y >= 2 and board[(y - 1) * cols + x] == k and board[(y - 2) * cols + x] == k:
		return true
	return false


func at(c: Vector2i) -> int:
	return int(board[c.y * cols + c.x])


func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows


## every cell that is part of a run of 3 or more
func _find_matches() -> Dictionary:
	var out := {}
	for y in rows:
		var x := 0
		while x < cols:
			var k: int = board[y * cols + x]
			var x2 := x
			while x2 + 1 < cols and board[y * cols + x2 + 1] == k:
				x2 += 1
			if k >= 0 and x2 - x >= 2:
				for xx in range(x, x2 + 1):
					out[y * cols + xx] = true
			x = x2 + 1
	for x in cols:
		var y := 0
		while y < rows:
			var k: int = board[y * cols + x]
			var y2 := y
			while y2 + 1 < rows and board[(y2 + 1) * cols + x] == k:
				y2 += 1
			if k >= 0 and y2 - y >= 2:
				for yy in range(y, y2 + 1):
					out[yy * cols + x] = true
			y = y2 + 1
	return out


func _swap_cells(a: Vector2i, b: Vector2i) -> void:
	var t = board[a.y * cols + a.x]
	board[a.y * cols + a.x] = board[b.y * cols + b.x]
	board[b.y * cols + b.x] = t


## [a, b] of the first swap that makes a match, or []
func find_move() -> Array:
	var best := moves_list()
	return [] if best.is_empty() else best[0]


## every swap [a, b] (right and down neighbours) that makes a match
func moves_list() -> Array:
	var out: Array = []
	for y in rows:
		for x in cols:
			var a := Vector2i(x, y)
			for b in [Vector2i(x + 1, y), Vector2i(x, y + 1)]:
				if not inside(b):
					continue
				_swap_cells(a, b)
				var ok := not _find_matches().is_empty()
				_swap_cells(a, b)
				if ok:
					out.append([a, b])
	return out


## try a swap. Returns true when it was a real move (it matched). Busy boards and non-neighbours refuse.
func try_swap(a: Vector2i, b: Vector2i) -> bool:
	if busy or result != "" or not inside(a) or not inside(b) or absi(a.x - b.x) + absi(a.y - b.y) != 1:
		return false
	_swap_cells(a, b)
	if _find_matches().is_empty():
		_swap_cells(a, b)
		_bad_t = 0.25
		Sfx.play("fail", 1.4, -12.0)
		return false
	chain = 0
	busy = true
	_swap_a = a
	_swap_b = b
	_phase = "swap"
	_phase_t = 0.0
	Sfx.play("swipe", 1.2, -8.0)
	return true


func _tick(dt: float) -> void:
	_bad_t = maxf(_bad_t - dt, 0.0)
	_pop_t = maxf(_pop_t - dt, 0.0)
	if result == "":
		time_left = maxf(time_left - dt, 0.0)                # real time: it keeps running through swaps and cascades
		if time_left <= 0.0:
			if score >= target:
				win()
			else:
				lose("TIME UP")
			return
	if not busy:
		return
	_phase_t += dt
	match _phase:
		"swap":
			if _phase_t >= SWAP_S:
				_start_clear()
		"clear":
			if _phase_t >= CLEAR_S:
				_drop_tiles()
		"fall":
			var left := 1.0 - minf(_phase_t / FALL_S, 1.0)
			_decay_fall(left)
			if _phase_t >= FALL_S:
				for i in fall_off.size():
					fall_off[i] = 0.0
				_start_clear()


var _fall_start: Array = []


func _decay_fall(left: float) -> void:
	for i in fall_off.size():
		fall_off[i] = float(_fall_start[i]) * left


func _start_clear() -> void:
	var m := _find_matches()
	if m.is_empty():
		_end_turn()
		return
	chain += 1
	var pts := int(round(float(m.size() * Tuning.MATCH_TILE_POINTS) * (1.0 + Tuning.MATCH_CHAIN_STEP * float(chain - 1))))
	score += pts
	_pop_text = "+%d%s" % [pts, ("  x%d chain" % chain) if chain > 1 else ""]
	_pop_t = 1.0
	_clearing = m
	_phase = "clear"
	_phase_t = 0.0
	Sfx.play("glass", 1.5 + 0.1 * float(chain), -8.0)


func _drop_tiles() -> void:
	for i in _clearing:
		board[i] = -1
	_clearing = {}
	_fall_start = []
	for i in board.size():
		_fall_start.append(0.0)
	for x in cols:
		var write := rows - 1
		for y in range(rows - 1, -1, -1):
			var k: int = board[y * cols + x]
			if k >= 0:
				if write != y:
					board[write * cols + x] = k
					board[y * cols + x] = -1
					_fall_start[write * cols + x] = float(write - y) * TILE
				write -= 1
		var n := write + 1                                   # empty cells at the top
		for y in range(write, -1, -1):
			var k := rng.randi() % kinds.size()
			if y + 1 < rows and rng.randf() < Tuning.MATCH_CASCADE_BIAS:
				k = board[(y + 1) * cols + x]               # copy the tile below: falling tiles line up into more chains
			board[y * cols + x] = k
			_fall_start[y * cols + x] = float(n) * TILE
	for i in fall_off.size():
		fall_off[i] = _fall_start[i]
	_phase = "fall"
	_phase_t = 0.0


func _end_turn() -> void:
	busy = false
	_phase = ""
	sel = Vector2i(-1, -1)
	if score >= target:
		win()
		return
	if find_move().is_empty():
		_reshuffle()


## no move is left: mix the tiles that are on the board until there is one and nothing matches
func _reshuffle() -> void:
	reshuffles += 1
	for attempt in 100:
		for i in range(board.size() - 1, 0, -1):
			var j := rng.randi() % (i + 1)
			var t = board[i]
			board[i] = board[j]
			board[j] = t
		if _find_matches().is_empty() and not find_move().is_empty():
			return
	_fill_board()


## test hook: run every animation phase to its end
func settle() -> void:
	var guard := 0
	while busy and guard < 400:
		_tick(5.0)
		guard += 1


func _on_action(a: String) -> void:
	if busy:
		return
	var dv := Vector2i.ZERO
	match a:
		"left": dv = Vector2i(-1, 0)
		"right": dv = Vector2i(1, 0)
		"up": dv = Vector2i(0, -1)
		"down": dv = Vector2i(0, 1)
		"btn_a":
			if sel == Vector2i(-1, -1):
				sel = cursor
			elif sel == cursor:
				sel = Vector2i(-1, -1)
			elif absi(sel.x - cursor.x) + absi(sel.y - cursor.y) == 1:
				var s := sel
				sel = Vector2i(-1, -1)
				try_swap(s, cursor)
			else:
				sel = cursor
			return
	if sel != Vector2i(-1, -1):
		var to := sel + dv
		if inside(to):
			var s := sel
			sel = Vector2i(-1, -1)
			cursor = to
			try_swap(s, to)
	else:
		var nc := cursor + dv
		if inside(nc):
			cursor = nc


func _cell_at(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - origin_px.x) / TILE), floori((p.y - origin_px.y) / TILE))


func _on_press(p: Vector2) -> void:
	if busy:
		return
	var c := _cell_at(p)
	_press = p
	_press_cell = c if inside(c) else Vector2i(-1, -1)
	if not inside(c):
		return
	cursor = c
	if sel != Vector2i(-1, -1) and absi(sel.x - c.x) + absi(sel.y - c.y) == 1:
		var s := sel
		sel = Vector2i(-1, -1)
		_press_cell = Vector2i(-1, -1)
		try_swap(s, c)
	elif sel == c:
		sel = Vector2i(-1, -1)
	else:
		sel = c


func _on_drag(p: Vector2) -> void:
	if busy or _press_cell == Vector2i(-1, -1):
		return
	var d := p - _press
	if d.length() < TILE * 0.45:
		return
	var dv := Vector2i(1 if d.x > 0.0 else -1, 0) if absf(d.x) >= absf(d.y) else Vector2i(0, 1 if d.y > 0.0 else -1)
	var from := _press_cell
	_press_cell = Vector2i(-1, -1)
	sel = Vector2i(-1, -1)
	try_swap(from, from + dv)


func solve() -> void:
	var guard := 0
	while result == "" and guard < 60:
		guard += 1
		var mv := best_move()
		if mv.is_empty():
			break
		try_swap(mv[0], mv[1])
		settle()
	if result == "" and score >= target:
		win()


## the swap that clears the most tiles right now (the bot, and the hint for tests)
func best_move() -> Array:
	var best: Array = []
	var best_n := -1
	for mv in moves_list():
		_swap_cells(mv[0], mv[1])
		var n := _find_matches().size()
		_swap_cells(mv[0], mv[1])
		if n > best_n:
			best_n = n
			best = mv
	return best


# ---------------------------------------------------------------- drawing
func _kind_color(k: int) -> Color:
	var cols_a := [Color(0.35, 0.12, 0.12), Color(0.12, 0.28, 0.18), Color(0.12, 0.2, 0.38), Color(0.32, 0.26, 0.1), Color(0.28, 0.14, 0.36), Color(0.1, 0.3, 0.32)]
	return cols_a[k % cols_a.size()]


func _draw_puzzle() -> void:
	var o := origin_px
	var board_r := Rect2(o, Vector2(TILE * cols, TILE * rows))
	plate(board_r.grow(8.0), Color(0.03, 0.02, 0.06), Color(0.45, 0.4, 0.55), 3.0)
	for y in rows:
		for x in cols:
			var c := Vector2i(x, y)
			var i := y * cols + x
			var k: int = board[i]
			if k < 0:
				continue
			var pos := o + Vector2(x, y) * TILE
			pos.y -= float(fall_off[i])
			if busy and _phase == "swap":
				var u := minf(_phase_t / SWAP_S, 1.0)
				var pa := o + Vector2(_swap_a) * TILE
				var pb := o + Vector2(_swap_b) * TILE
				if c == _swap_a:
					pos = pb.lerp(pa, u)                       # the board is already swapped: this tile came from b
				elif c == _swap_b:
					pos = pa.lerp(pb, u)
			if _bad_t > 0.0 and (c == sel or c == cursor):
				pos.x += sin(_bad_t * 80.0) * 6.0
			var r := Rect2(pos, Vector2(TILE, TILE)).grow(-4.0)
			var clearing := _clearing.has(i) and _phase == "clear"
			var fill := _kind_color(k)
			if clearing:
				fill = fill.lerp(Color(1, 1, 1), minf(_phase_t / CLEAR_S, 1.0))
				r = r.grow(-14.0 * minf(_phase_t / CLEAR_S, 1.0))
			ui.draw_rect(r, fill)
			var tex: Texture2D = Roster.face(String(kinds[k]))
			if tex != null:
				var ts := tex.get_size()
				var sc := minf((r.size.x - 16.0) / ts.x, (r.size.y - 16.0) / ts.y)     # 8 px margin inside the tile
				var dsz := ts * sc
				ui.draw_texture_rect(tex, Rect2(r.get_center() - dsz * 0.5, dsz), false)
			ui.draw_rect(r, Color(0.55, 0.5, 0.65), false, 2.0)
			if c == sel:
				ui.draw_rect(r.grow(2.0), Color(1.0, 0.95, 0.6), false, 6.0)
	ui.draw_rect(Rect2(o + Vector2(cursor) * TILE, Vector2(TILE, TILE)).grow(-1.0), GOLD, false, 4.0)
	# side panel
	# right column: 60 px right of the board, 40 px inside the panel's right edge (1660 - 40 = 1620)
	var sx := board_r.end.x + 60.0
	text(Vector2(sx, 300.0), "SCORE", 44, GOLD)
	text(Vector2(sx, 388.0), "%d / %d" % [score, target], 88)
	var bar := Rect2(sx, 420.0, 480.0, 36.0)
	ui.draw_rect(bar, Color(0.1, 0.06, 0.14))
	ui.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(score) / float(target), 0.0, 1.0), bar.size.y)), Color(1.0, 0.8, 0.35))
	ui.draw_rect(bar, Color(0.45, 0.4, 0.55), false, 2.0)
	text(Vector2(sx, 530.0), "TIME", 44, GOLD)
	var low := time_left <= 5.0
	text(Vector2(sx, 618.0), "%d" % ceili(time_left), 88, Color(1.0, 0.45, 0.4) if low else INK)
	var tbar := Rect2(sx, 640.0, 480.0, 24.0)
	ui.draw_rect(tbar, Color(0.1, 0.06, 0.14))
	ui.draw_rect(Rect2(tbar.position, Vector2(tbar.size.x * clampf(time_left / Tuning.MATCH_TIME_S, 0.0, 1.0), tbar.size.y)), Color(1.0, 0.4, 0.35) if low else Color(0.5, 0.85, 1.0))
	ui.draw_rect(tbar, Color(0.45, 0.4, 0.55), false, 2.0)
	text(Vector2(sx, 722.0), "Clear 3 or more.", 36, Color(0.85, 0.85, 0.9))
	text(Vector2(sx, 770.0), "Chains pay extra.", 36, Color(0.85, 0.85, 0.9))
	if _pop_t > 0.0:
		text(Vector2(sx, 830.0), _pop_text, 44, Color(0.6, 1.0, 0.6, minf(_pop_t * 2.0, 1.0)))
