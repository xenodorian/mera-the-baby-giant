extends "res://scripts/puzzles/puzzle_host.gd"
## Stop the needle. A needle sweeps back and forth over a gauge with a green target zone. A (or a tap) stops it.
## Three stops in a row inside the zone win. Every success shrinks the zone and speeds the needle up; a miss loses.
## The zone never gets under Tuning.NEEDLE_ZONE_MIN of the gauge, so it stays fair on a phone.

const GAUGE := Rect2(360.0, 440.0, 1200.0, 120.0)
const READY_S := 0.7             # the needle waits this long at the start of each round

var round_i := 0                 # successful stops so far
var pos := 0.0                   # needle, 0..1 across the gauge
var dir := 1.0
var zone_center := 0.5
var zone_width := 0.2
var wait := READY_S
var stops: Array = []            # where each stop landed (for the marks on the gauge)
var _flash := 0.0
var _flash_ok := true


func title() -> String:
	return "STOP THE NEEDLE"


func hint_keys() -> String:
	return "A stop the needle in the green   B give up"


func hint_touch() -> String:
	return "Tap anywhere to stop the needle   Give up: top right"


func _setup() -> void:
	_new_round()


static func zone_for(round_n: int) -> float:
	var z: Array = Tuning.NEEDLE_ZONES
	return maxf(float(z[mini(round_n, z.size() - 1)]), Tuning.NEEDLE_ZONE_MIN)


static func speed_for(round_n: int) -> float:
	var s: Array = Tuning.NEEDLE_SPEEDS
	return float(s[mini(round_n, s.size() - 1)])


func speed() -> float:
	return speed_for(round_i)


func _new_round() -> void:
	zone_width = zone_for(round_i)
	var margin := 0.04
	zone_center = rng.randf_range(zone_width * 0.5 + margin, 1.0 - zone_width * 0.5 - margin)
	pos = 0.0 if rng.randf() < 0.5 else 1.0
	dir = 1.0 if pos == 0.0 else -1.0
	wait = READY_S


func in_zone() -> bool:
	return absf(pos - zone_center) <= zone_width * 0.5


func _tick(dt: float) -> void:
	_flash = maxf(_flash - dt, 0.0)
	if wait > 0.0:
		wait -= dt
		return
	pos += dir * speed() * dt
	if pos >= 1.0:
		pos = 1.0
		dir = -1.0
	elif pos <= 0.0:
		pos = 0.0
		dir = 1.0


## stop the needle where it is
func stop() -> void:
	if result != "" or wait > 0.0:
		return
	if in_zone():
		stops.append(pos)
		round_i += 1
		_flash = 0.35
		_flash_ok = true
		Sfx.play("parry", 1.0 + 0.1 * float(round_i), -8.0)
		if round_i >= Tuning.NEEDLE_ROUNDS:
			win()
		else:
			_new_round()
	else:
		_flash = 0.35
		_flash_ok = false
		lose("MISSED")


func _on_action(a: String) -> void:
	if a == "btn_a":
		stop()


func _on_press(_p: Vector2) -> void:
	stop()


func solve() -> void:
	while result == "":
		wait = 0.0
		pos = zone_center
		stop()


func _draw_puzzle() -> void:
	var g := GAUGE
	plate(g.grow(10.0), Color(0.03, 0.02, 0.06), Color(0.45, 0.4, 0.55), 3.0)
	ui.draw_rect(g, Color(0.12, 0.08, 0.17))
	var zr := Rect2(g.position.x + g.size.x * (zone_center - zone_width * 0.5), g.position.y, g.size.x * zone_width, g.size.y)
	ui.draw_rect(zr, Color(0.2, 0.65, 0.3))
	ui.draw_rect(zr, Color(0.55, 1.0, 0.6), false, 4.0)
	for i in 11:
		var x := g.position.x + g.size.x * float(i) / 10.0
		ui.draw_line(Vector2(x, g.end.y), Vector2(x, g.end.y + (24.0 if i % 5 == 0 else 12.0)), Color(0.6, 0.55, 0.7), 3.0)
	var nx := g.position.x + g.size.x * pos
	var col := Color(1.0, 0.4, 0.35)
	if _flash > 0.0:
		col = Color(0.6, 1.0, 0.6) if _flash_ok else Color(1.0, 0.2, 0.2)
	ui.draw_line(Vector2(nx, g.position.y - 30.0), Vector2(nx, g.end.y + 30.0), Color(0, 0, 0), 14.0)
	ui.draw_line(Vector2(nx, g.position.y - 30.0), Vector2(nx, g.end.y + 30.0), col, 8.0)
	ui.draw_colored_polygon(PackedVector2Array([Vector2(nx - 18.0, g.position.y - 54.0), Vector2(nx + 18.0, g.position.y - 54.0), Vector2(nx, g.position.y - 26.0)]), col)
	# rounds
	text(Vector2(PANEL.position.x, 300.0), "Stops in a row", 30, GOLD, HORIZONTAL_ALIGNMENT_CENTER, PANEL.size.x)
	for i in Tuning.NEEDLE_ROUNDS:
		var c := Vector2(PANEL.position.x + PANEL.size.x * 0.5 + (float(i) - float(Tuning.NEEDLE_ROUNDS - 1) * 0.5) * 90.0, 350.0)
		ui.draw_circle(c, 26.0, Color(0.1, 0.06, 0.14))
		ui.draw_circle(c, 20.0, Color(1.0, 0.82, 0.3) if i < round_i else Color(0.25, 0.2, 0.3))
	if wait > 0.0 and result == "":
		text(Vector2(PANEL.position.x, 700.0), "Get ready", 44, Color(0.85, 0.85, 0.9), HORIZONTAL_ALIGNMENT_CENTER, PANEL.size.x)
