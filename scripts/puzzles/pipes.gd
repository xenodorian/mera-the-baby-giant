extends "res://scripts/puzzles/puzzle_host.gd"
## Connect the pipes. A grid of straight, corner and tee tiles; water enters on the left edge and must reach the drain
## on the right. A rotates the tile under the cursor (clockwise); a tap rotates the tile it lands on.
## The board is built from a random path (source to drain) whose tiles then get scrambled, so it is always solvable.
## Each rotation counts as a move; running out of moves, or B, loses.

const N := 1
const E := 2
const S := 4
const WEST := 8
const DIRS := [N, E, S, WEST]
const VEC := {N: Vector2i(0, -1), E: Vector2i(1, 0), S: Vector2i(0, 1), WEST: Vector2i(-1, 0)}
const STRAIGHT := 0
const CORNER := 1
const TEE := 2
const BASE := [N | S, N | E, N | E | WEST]          # open sides of each type at rotation 0
const CELL := 120.0

var cols := Tuning.PIPES_COLS
var rows := Tuning.PIPES_ROWS
var types: Array = []              # per cell
var rots: Array = []               # per cell, 0..3 clockwise quarter turns
var need: Array = []               # per cell: required open sides for the generated path (0 off the path)
var path: Array = []               # Vector2i cells from the source tile to the drain tile
var src_row := 0
var dst_row := 0
var cursor := Vector2i(0, 0)
var moves_used := 0
var moves_limit := 0
var wet: Dictionary = {}           # cell index -> true, water has reached it
var origin_px := Vector2.ZERO


func title() -> String:
	return "CONNECT THE PIPES"


func hint_keys() -> String:
	return "Arrows move   A rotate   B give up"


func hint_touch() -> String:
	return "Tap a tile to rotate it   Give up: top right"


func _setup() -> void:
	origin_px = Vector2(PANEL.position.x + (PANEL.size.x - CELL * cols) * 0.5, 210.0)
	for attempt in 50:
		if _generate():
			break
	_flow()


static func mask_of(type: int, rot: int) -> int:
	var m: int = BASE[type]
	for i in rot:
		m = ((m << 1) | (m >> 3)) & 15
	return m


func idx(c: Vector2i) -> int:
	return c.y * cols + c.x


func mask_at(c: Vector2i) -> int:
	return mask_of(int(types[idx(c)]), int(rots[idx(c)]))


func _generate() -> bool:
	src_row = rng.randi() % rows
	dst_row = rng.randi() % rows
	path = _random_path(Vector2i(0, src_row), Vector2i(cols - 1, dst_row))
	if path.is_empty():
		return false
	types.clear()
	rots.clear()
	need.clear()
	for i in cols * rows:
		types.append(rng.randi() % 3)
		rots.append(rng.randi() % 4)
		need.append(0)
	for k in path.size():
		var c: Vector2i = path[k]
		var want := 0
		want |= _side_to(c, path[k - 1]) if k > 0 else WEST
		want |= _side_to(c, path[k + 1]) if k < path.size() - 1 else E
		need[idx(c)] = want
		var t: int
		if rng.randf() < 0.3:
			t = TEE                                       # a tee holds the path and leaks a side branch
		elif want == (N | S) or want == (E | WEST):
			t = STRAIGHT
		else:
			t = CORNER
		types[idx(c)] = t
		if t == TEE:
			need[idx(c)] = _tee_mask(want)
	# scramble: random turns, and never start already solved
	for tries in 40:
		for i in cols * rows:
			rots[i] = rng.randi() % 4
		_flow()
		if not solved():
			break
	if solved():
		return false
	moves_limit = moves_needed() + Tuning.PIPES_MOVES_EXTRA
	return true


## a tee with the two required sides plus one more
func _tee_mask(want: int) -> int:
	var extra: Array = []
	for d in DIRS:
		if (want & d) == 0:
			extra.append(d)
	return want | int(extra[rng.randi() % extra.size()])


func _side_to(a: Vector2i, b: Vector2i) -> int:
	var d := b - a
	for k in DIRS:
		if VEC[k] == d:
			return k
	return 0


## randomized depth-first walk from a to b without revisiting a cell
func _random_path(a: Vector2i, b: Vector2i) -> Array:
	var seen := {a: true}
	var out: Array = [a]
	var stack: Array = [[a, _shuffled_dirs(), 0]]
	var steps := 0
	while not stack.is_empty() and steps < 4000:
		steps += 1
		var top: Array = stack[stack.size() - 1]
		var cur: Vector2i = top[0]
		if cur == b:
			return out
		var order: Array = top[1]
		var i: int = top[2]
		if i >= order.size():
			stack.pop_back()
			seen.erase(cur)
			out.pop_back()
			continue
		top[2] = i + 1
		var nx: Vector2i = cur + Vector2i(VEC[order[i]])
		if nx.x < 0 or nx.y < 0 or nx.x >= cols or nx.y >= rows or seen.has(nx):
			continue
		seen[nx] = true
		out.append(nx)
		stack.append([nx, _shuffled_dirs(), 0])
	return []


func _shuffled_dirs() -> Array:
	var d: Array = DIRS.duplicate()
	for i in range(d.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t = d[i]
		d[i] = d[j]
		d[j] = t
	return d


## quarter turns still owed: for each path tile, the shortest clockwise turn count to a rotation that gives the needed sides
func moves_needed() -> int:
	var total := 0
	for c in path:
		total += _turns_to_fit(c)
	return total


func _turns_to_fit(c: Vector2i) -> int:
	var i := idx(c)
	if int(need[i]) == 0:
		return 0
	for k in 4:
		if mask_of(int(types[i]), (int(rots[i]) + k) % 4) == int(need[i]):
			return k
	return 0


func _flow() -> void:
	wet.clear()
	var start := Vector2i(0, src_row)
	if (mask_at(start) & WEST) == 0:
		return
	var queue: Array = [start]
	wet[idx(start)] = true
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		var m := mask_at(c)
		for d in DIRS:
			if (m & d) == 0:
				continue
			var nx: Vector2i = c + Vector2i(VEC[d])
			if nx.x < 0 or nx.y < 0 or nx.x >= cols or nx.y >= rows or wet.has(idx(nx)):
				continue
			var back: int = ((d << 2) | (d >> 2)) & 15            # the opposite side
			if (mask_at(nx) & back) != 0:
				wet[idx(nx)] = true
				queue.append(nx)


func solved() -> bool:
	var end := Vector2i(cols - 1, dst_row)
	return wet.has(idx(end)) and (mask_at(end) & E) != 0


func rotate_tile(c: Vector2i) -> void:
	if result != "" or c.x < 0 or c.y < 0 or c.x >= cols or c.y >= rows:
		return
	rots[idx(c)] = (int(rots[idx(c)]) + 1) % 4
	moves_used += 1
	Sfx.play("plank", 1.4, -10.0)
	_flow()
	if solved():
		win()
	elif moves_used >= moves_limit:
		lose("OUT OF MOVES")


func _on_action(a: String) -> void:
	match a:
		"left": cursor.x = maxi(cursor.x - 1, 0)
		"right": cursor.x = mini(cursor.x + 1, cols - 1)
		"up": cursor.y = maxi(cursor.y - 1, 0)
		"down": cursor.y = mini(cursor.y + 1, rows - 1)
		"btn_a": rotate_tile(cursor)


func _on_press(p: Vector2) -> void:
	var c := Vector2i(floori((p.x - origin_px.x) / CELL), floori((p.y - origin_px.y) / CELL))
	if c.x < 0 or c.y < 0 or c.x >= cols or c.y >= rows:
		return
	cursor = c
	rotate_tile(c)


func solve() -> void:
	for c in path:
		while _turns_to_fit(c) > 0 and result == "":
			rotate_tile(c)
	if result == "":
		_flow()
		if solved():
			win()


# ---------------------------------------------------------------- drawing
func _draw_puzzle() -> void:
	var o := origin_px
	var board := Rect2(o, Vector2(CELL * cols, CELL * rows))
	plate(board.grow(8.0), Color(0.03, 0.02, 0.06), Color(0.45, 0.4, 0.55), 3.0)
	# source and drain
	var sy := o.y + (src_row + 0.5) * CELL
	var dy := o.y + (dst_row + 0.5) * CELL
	_pipe_bar(Vector2(o.x - 70.0, sy), Vector2(o.x, sy), true)
	_pipe_bar(Vector2(board.end.x, dy), Vector2(board.end.x + 70.0, dy), solved())
	plate(Rect2(o.x - 170.0, sy - 40.0, 100.0, 80.0), Color(0.1, 0.25, 0.4), Color(0.4, 0.8, 1.0))
	text(Vector2(o.x - 170.0, sy + 10.0), "WATER", 22, Color(0.7, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER, 100.0)
	plate(Rect2(board.end.x + 70.0, dy - 40.0, 100.0, 80.0), Color(0.15, 0.12, 0.1), Color(1.0, 0.82, 0.45))
	text(Vector2(board.end.x + 70.0, dy + 10.0), "DRAIN", 22, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 100.0)
	for y in rows:
		for x in cols:
			var c := Vector2i(x, y)
			var r := Rect2(o + Vector2(x, y) * CELL, Vector2(CELL, CELL))
			ui.draw_rect(r.grow(-3.0), Color(0.1, 0.07, 0.14))
			var m := mask_at(c)
			var is_wet := wet.has(idx(c))
			var mid := r.get_center()
			for d in DIRS:
				if (m & d) != 0:
					var tip := mid + Vector2(VEC[d]) * (CELL * 0.5)
					_pipe_bar(mid, tip, is_wet)
			ui.draw_circle(mid, 21.0, Color(0.05, 0.03, 0.07))
			ui.draw_circle(mid, 15.0, Color(0.3, 0.72, 1.0) if is_wet else Color(0.6, 0.52, 0.45))
	var cr := Rect2(o + Vector2(cursor) * CELL, Vector2(CELL, CELL)).grow(-1.0)
	ui.draw_rect(cr, GOLD, false, 5.0)
	var left := maxi(moves_limit - moves_used, 0)
	text(Vector2(o.x, 890.0), "Moves left: %d" % left, 32, Color(1.0, 0.85, 0.4) if left > 4 else Color(1.0, 0.45, 0.4))


func _pipe_bar(a: Vector2, b: Vector2, is_wet: bool) -> void:
	ui.draw_line(a, b, Color(0.05, 0.03, 0.07), 34.0)
	ui.draw_line(a, b, Color(0.3, 0.72, 1.0) if is_wet else Color(0.6, 0.52, 0.45), 24.0)
