extends RefCounted
class_name SoulMazeBoard
## 23×13 maze. Straight pieces may be absent. Each bent piece may appear up to six times.

const COLS := 23
const ROWS := 13

const SHAPES := [
	{"name": "i2", "cells": [Vector2i(0, 0), Vector2i(1, 0)], "min": 0, "max": 2},
	{"name": "i3", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)], "min": 0, "max": 6},
	{"name": "i4", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)], "min": 0, "max": 4},
	{"name": "i5", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)], "min": 0, "max": 1},
	{"name": "l3", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)], "min": 0, "max": 6},
	{"name": "l4", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, 2)], "min": 3, "max": 6},
	{"name": "chunk", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)], "min": 2, "max": 6},
	{"name": "hook", "cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 2)], "min": 2, "max": 6},
	{"name": "ell5", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(0, 2)], "min": 1, "max": 6},
	{"name": "ell6", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)], "min": 1, "max": 6},
]


static func generate() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var pick: Array = MAPS[rng.randi() % MAPS.size()]
	var flip := rng.randi() % 2 == 1
	var grid: Array = []
	for row in pick:
		var line := String(row)
		if flip:
			var rev := ""
			for i in range(line.length() - 1, -1, -1):
				rev += line[i]
			line = rev
		grid.append(line)
	_stamp_house(grid)
	_put(grid, 11, 4, ".")
	_sprinkle(grid)
	return grid


## Eight boards drawn on the wall bench. The house is stamped on top.
## A horizontal mirror is the other deal. Dead-end notches stay as drawn.
const MAPS := [
	[
		"#######################",
		"#....#.#########.#....#",
		"#.##.#...........#.##.#",
		"#..#.#.####.####.#.#..#",
		"##.#...#.......#...#.##",
		"##.###.#.#####.#.###.##",
		"##.......#...#.......##",
		"##.###.#.#...#.#.###.##",
		"##.#...#.#####.#...#.##",
		"#..#.#.#.......#.#.#..#",
		"#.##.#.##.###.##.#.##.#",
		"#....#...........#....#",
		"#######################",
	],
	[
		"###########.###########",
		"#.......###.###.......#",
		"#.#.#.#.........#.#.#.#",
		"#.#.#.##.#####.##.#.#.#",
		"#......#.......#......#",
		"#.####.#.#####.#.####.#",
		"#......#.#...#.#......#",
		"######.#.#...#.#.######",
		".........#####.........",
		"#.####.#.......#.####.#",
		"#.####.##.#.#.##.####.#",
		"#.........#.#.........#",
		"###########.###########",
	],
	[
		"#######################",
		"#.........#.#.........#",
		"#.###.###.#.#.###.###.#",
		"#..##.............##..#",
		"##....##.##.##.##....##",
		"#..##.##.#####.##.##..#",
		"..##...#.#...#.#...##..",
		"#....#.#.#...#.#.#....#",
		"#.##.#.#.#####.#.#.##.#",
		"#..#...............#..#",
		"##.###.###.#.###.###.##",
		"#..........#..........#",
		"#######################",
	],
	[
		"##.#################.##",
		"##.#.....##.##.....#.##",
		"##.#.###.##.##.###.#.##",
		"##.#.#...##.##...#.#.##",
		"##.....#.......#.....##",
		"#..##.##.#####.##.##..#",
		"..##...#.#...#.#...##..",
		"#....#.#.#...#.#.#....#",
		"#.##.#.#.#####.#.#.##.#",
		"#.##...............##.#",
		"#.####.###.#.###.####.#",
		"#......###.#.###......#",
		"##.#################.##",
	],
	[
		"#.#########.#########.#",
		"#...#.............#...#",
		"###.#.#.#######.#.#.###",
		"..#.#.#.#######.#.#.#..",
		"#.#.#.#.........#.#.#.#",
		"#.#...##.#####.##...#.#",
		"#.###....#...#....###.#",
		"#.....##.#...#.##.....#",
		"###.####.#####.####.###",
		"..#.................#..",
		"#.##.####.#.#.####.##.#",
		"#.........#.#.........#",
		"#.#########.#########.#",
	],
	[
		"#####.###########.#####",
		"#........#...#........#",
		"#.######.#.#.#.######.#",
		"#........#.#.#........#",
		"#.######.......######.#",
		"#........#####........#",
		"#.#.#.#.##...##.#.#.#.#",
		"#.#.#.#.##...##.#.#.#.#",
		"..#.#.#.#######.#.#.#..",
		"#.#.#.#.........#.#.#.#",
		"#.#.#.#.#######.#.#.#.#",
		"#.....................#",
		"#####.###########.#####",
	],
	[
		"#.###################.#",
		"#.....................#",
		"#.###.##.##.##.##.###.#",
		"#.#....#.##.##.#....#.#",
		"#.#.##.#.......#.##.#.#",
		"#...##.#.#####.#.##...#",
		"#.#....#.#...#.#....#.#",
		"#.####...#...#...####.#",
		"#......#.#####.#......#",
		"..####.#.......#.####..",
		"######.#.#####.#.######",
		"#.....................#",
		"#.###################.#",
	],
	[
		"######.#########.######",
		"#.....................#",
		"#.###.#####.#####.###.#",
		"#.#...##.......##...#.#",
		"#.#.#.##.##.##.##.#.#.#",
		"#...#.##.#####.##.#...#",
		"#.#....#.#...#.#....#.#",
		"#.####...#...#...####.#",
		"#......#.#####.#......#",
		"#.####.#.......#.####.#",
		"#.####.##.###.##.####.#",
		"#.....................#",
		"######.#########.######",
	],
]


static func _trim_dead(grid: Array) -> void:
	var changed := true
	while changed:
		changed = false
		for y in ROWS:
			for x in COLS:
				if not _open(grid, x, y):
					continue
				if x == 0 or x == COLS - 1:
					continue
				var deg := 0
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx := x + d.x
					var ny := y + d.y
					if nx < 0 or ny < 0 or nx >= COLS or ny >= ROWS:
						continue
					if _open(grid, nx, ny) or _at(grid, nx, ny) == "=":
						deg += 1
				if deg <= 1:
					_put(grid, x, y, "#")
					changed = true


static func _forms() -> Array:
	var out: Array = []
	for shape in SHAPES:
		var item: Dictionary = shape.duplicate(true)
		item["forms"] = _orientations(item["cells"])
		out.append(item)
	return out


static func _orientations(cells: Array) -> Array:
	var seen := {}
	var out: Array = []
	var cur: Array = cells
	for _turn in 4:
		for flip in [false, true]:
			var next: Array = []
			for c in cur:
				var v: Vector2i = c
				next.append(Vector2i(-v.x if flip else v.x, v.y))
			next = _normalize(next)
			var key := _key(next)
			if not seen.has(key):
				seen[key] = true
				out.append(next)
		var turned: Array = []
		for c in cur:
			var v: Vector2i = c
			turned.append(Vector2i(v.y, -v.x))
		cur = turned
	return out


static func _normalize(cells: Array) -> Array:
	var min_x := 999
	var min_y := 999
	for c in cells:
		var v: Vector2i = c
		min_x = mini(min_x, v.x)
		min_y = mini(min_y, v.y)
	var out: Array = []
	for c in cells:
		var v: Vector2i = c
		out.append(Vector2i(v.x - min_x, v.y - min_y))
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return out


static func _key(cells: Array) -> String:
	var bits: PackedStringArray = []
	for c in cells:
		var v: Vector2i = c
		bits.append("%d,%d" % [v.x, v.y])
	return ";".join(bits)


static func _blank() -> Array:
	var grid: Array = []
	var wall := "#".repeat(COLS)
	for _y in ROWS:
		grid.append(wall)
	for y in range(1, ROWS - 1):
		var row := "#"
		for _x in range(1, COLS - 1):
			row += "."
		grid[y] = row + "#"
	for y in [1, 11]:
		_put(grid, 0, y, ".")
		_put(grid, COLS - 1, y, ".")
	return grid


static func _put(grid: Array, x: int, y: int, ch: String) -> void:
	var row: String = grid[y]
	grid[y] = row.substr(0, x) + ch + row.substr(x + 1)


static func _at(grid: Array, x: int, y: int) -> String:
	if y < 0 or y >= ROWS or x < 0 or x >= COLS:
		return "#"
	return grid[y][x]


static func _open(grid: Array, x: int, y: int) -> bool:
	var t := _at(grid, x, y)
	return t == "." or t == "o" or t == "P" or t == " "


static func _wide(grid: Array) -> int:
	var n := 0
	for y in ROWS - 1:
		for x in COLS - 1:
			if _open(grid, x, y) and _open(grid, x + 1, y) and _open(grid, x, y + 1) and _open(grid, x + 1, y + 1):
				n += 1
	return n


static func _can_place(grid: Array, cells: Array, ox: int, oy: int, reserved: Dictionary) -> Array:
	var abs_cells: Array = []
	for c in cells:
		var v: Vector2i = c
		var ax := ox + v.x
		var ay := oy + v.y
		if ax < 1 or ay < 1 or ax >= COLS - 1 or ay >= ROWS - 1:
			return []
		if _at(grid, ax, ay) != "." or reserved.has("%d,%d" % [ax, ay]):
			return []
		abs_cells.append(Vector2i(ax, ay))
	var self_set := {}
	for c in abs_cells:
		var v: Vector2i = c
		self_set["%d,%d" % [v.x, v.y]] = true
	for c in abs_cells:
		var v: Vector2i = c
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = v + d
			if self_set.has("%d,%d" % [n.x, n.y]):
				continue
			if n.x > 0 and n.y > 0 and n.x < COLS - 1 and n.y < ROWS - 1 and _at(grid, n.x, n.y) == "#":
				return []
	return abs_cells


static func _paint(grid: Array, cells: Array) -> void:
	for c in cells:
		var v: Vector2i = c
		_put(grid, v.x, v.y, "#")


static func _covers(cells: Array, target: Array) -> bool:
	var need := {}
	for c in target:
		var v: Vector2i = c
		need["%d,%d" % [v.x, v.y]] = true
	for c in cells:
		var v: Vector2i = c
		if need.has("%d,%d" % [v.x, v.y]):
			return true
	return false


static func _place_covering(grid: Array, forms: Array, reserved: Dictionary, target: Array, rng: RandomNumberGenerator) -> Array:
	var picks: Array = []
	for form in forms:
		for y in range(1, ROWS - 1):
			for x in range(1, COLS - 1):
				var abs_cells := _can_place(grid, form, x, y, reserved)
				if not abs_cells.is_empty() and _covers(abs_cells, target):
					picks.append(abs_cells)
	if picks.is_empty():
		return []
	return picks[rng.randi() % picks.size()]


static func _first_wide(grid: Array) -> Array:
	for y in ROWS - 1:
		for x in COLS - 1:
			if _open(grid, x, y) and _open(grid, x + 1, y) and _open(grid, x, y + 1) and _open(grid, x + 1, y + 1):
				return [Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x, y + 1), Vector2i(x + 1, y + 1)]
	return []


static func _place_anywhere(grid: Array, forms: Array, reserved: Dictionary, rng: RandomNumberGenerator) -> Array:
	var hole := _first_wide(grid)
	if not hole.is_empty():
		var covering := _place_covering(grid, forms, reserved, hole, rng)
		if not covering.is_empty():
			return covering
	var picks: Array = []
	for form in forms:
		for y in range(1, ROWS - 1):
			for x in range(1, COLS - 1):
				var abs_cells := _can_place(grid, form, x, y, reserved)
				if not abs_cells.is_empty():
					picks.append(abs_cells)
	if picks.is_empty():
		return []
	return picks[rng.randi() % picks.size()]


static func _connected(grid: Array) -> bool:
	if not _open(grid, 11, 4):
		return false
	var seen := {"11,4": true}
	var queue: Array[Vector2i] = [Vector2i(11, 4)]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = cur.x + d.x
			var ny: int = cur.y + d.y
			if ny < 0 or ny >= ROWS:
				continue
			if nx < 0 or nx >= COLS:
				if _at(grid, 0, ny) == "#" or _at(grid, COLS - 1, ny) == "#":
					continue
				nx = posmod(nx, COLS)
			if not _open(grid, nx, ny):
				continue
			var key := "%d,%d" % [nx, ny]
			if seen.has(key):
				continue
			seen[key] = true
			queue.append(Vector2i(nx, ny))
	for y in ROWS:
		for x in COLS:
			if _open(grid, x, y) and not seen.has("%d,%d" % [x, y]):
				return false
	return true


static func _stamp_house(grid: Array) -> void:
	var house := [
		[9, 5, "#"], [10, 5, "#"], [11, 5, "="], [12, 5, "#"], [13, 5, "#"],
		[9, 6, "#"], [10, 6, "G"], [11, 6, "G"], [12, 6, "G"], [13, 6, "#"],
		[9, 7, "#"], [10, 7, "G"], [11, 7, "G"], [12, 7, "G"], [13, 7, "#"],
		[9, 8, "#"], [10, 8, "#"], [11, 8, "#"], [12, 8, "#"], [13, 8, "#"],
	]
	for cell in house:
		_put(grid, cell[0], cell[1], cell[2])


static func _sprinkle(grid: Array) -> void:
	var open: Array[Vector2i] = []
	for y in ROWS:
		for x in COLS:
			if _at(grid, x, y) == ".":
				open.append(Vector2i(x, y))
	var souls: Array[Vector2i] = []
	for corner in [Vector2i(1, 1), Vector2i(COLS - 2, 1), Vector2i(1, ROWS - 2), Vector2i(COLS - 2, ROWS - 2)]:
		var best := Vector2i.ZERO
		var best_d := 100000
		var found := false
		for cell in open:
			var taken := false
			for soul in souls:
				if soul == cell:
					taken = true
					break
			if taken:
				continue
			var dist := absi(cell.x - corner.x) + absi(cell.y - corner.y)
			if dist < best_d:
				best_d = dist
				best = cell
				found = true
		if found:
			souls.append(best)
	for soul in souls:
		_put(grid, soul.x, soul.y, "o")
	var rest: Array[Vector2i] = []
	for cell in open:
		if _at(grid, cell.x, cell.y) == ".":
			rest.append(cell)
	rest.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return absi(a.x - 11) + absi(a.y - 11) > absi(b.x - 11) + absi(b.y - 11)
	)
	if not rest.is_empty():
		var spawn: Vector2i = rest[0]
		_put(grid, spawn.x, spawn.y, "P")


static func _copy_grid(grid: Array) -> Array:
	var out: Array = []
	for row in grid:
		out.append(String(row))
	return out


static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = items[i]
		items[i] = items[j]
		items[j] = swap


static func _build(forms: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var grid := _blank()
	_stamp_house(grid)
	var reserved := {}
	for y in range(4, 10):
		for x in range(8, 15):
			reserved["%d,%d" % [x, y]] = true
	for y in [1, 11]:
		for x in [1, 2, COLS - 3, COLS - 2]:
			reserved["%d,%d" % [x, y]] = true
	var tally := {}
	for shape in forms:
		tally[shape["name"]] = 0
	var armor := [
		[Vector2i(8, 3), Vector2i(9, 3), Vector2i(10, 3)],
		[Vector2i(12, 3), Vector2i(13, 3), Vector2i(14, 3)],
		[Vector2i(8, 10), Vector2i(9, 10), Vector2i(10, 10)],
		[Vector2i(12, 10), Vector2i(13, 10), Vector2i(14, 10)],
		[Vector2i(7, 4), Vector2i(7, 5), Vector2i(7, 6), Vector2i(7, 7), Vector2i(7, 8)],
		[Vector2i(15, 4), Vector2i(15, 5), Vector2i(15, 6)],
		[Vector2i(15, 8), Vector2i(15, 9)],
	]
	var armor_names := ["i3", "i3", "i3", "i3", "i5", "i3", "i2"]
	for i in armor.size():
		_paint(grid, armor[i])
		tally[armor_names[i]] += 1
	var by_name := {}
	for shape in forms:
		by_name[shape["name"]] = shape
	var queue: Array[String] = []
	for shape in forms:
		var need := maxi(0, int(shape["min"]) - int(tally[shape["name"]]))
		for _n in need:
			queue.append(String(shape["name"]))
	_shuffle(queue, rng)
	for shape_name in queue:
		var spot: Array = _place_anywhere(grid, by_name[shape_name]["forms"], reserved, rng)
		if spot.is_empty():
			return {"grid": grid, "ok": false, "wide": _wide(grid)}
		_paint(grid, spot)
		tally[shape_name] += 1
	var guard := 0
	while _wide(grid) > 1 and guard < 40:
		guard += 1
		var sealed := false
		for y in ROWS - 1:
			if sealed:
				break
			for x in COLS - 1:
				if sealed:
					break
				if not (_open(grid, x, y) and _open(grid, x + 1, y) and _open(grid, x, y + 1) and _open(grid, x + 1, y + 1)):
					continue
				var hole := [Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x, y + 1), Vector2i(x + 1, y + 1)]
				var options: Array = forms.duplicate()
				_shuffle(options, rng)
				for shape in options:
					if int(tally[shape["name"]]) >= int(shape["max"]):
						continue
					var placed: Array = _place_covering(grid, shape["forms"], reserved, hole, rng)
					if placed.is_empty():
						continue
					_paint(grid, placed)
					tally[shape["name"]] += 1
					sealed = true
					break
		if not sealed:
			break
	var counts_ok := true
	for shape in forms:
		var n := int(tally[shape["name"]])
		if n < int(shape["min"]) or n > int(shape["max"]):
			counts_ok = false
	var wide := _wide(grid)
	return {"grid": grid, "ok": counts_ok and wide <= 1 and _connected(grid), "wide": wide}
