extends Node2D
## v0.9.1 Y Y Y, then L2: a harmless pulse wave (docs/GAME_RULES.md "Y chain"). Two bright rings expand from Mera
## over PULSE_S; game.pulse_wave() already pushed every enemy in reach away (knockback only, 0 damage).

var reach := 900.0
var s := 1.0
var t := 0.0


func setup(p: Vector2, r: float, size: float) -> void:
	position = p
	reach = r
	s = size
	material = AnimLib.fx_mat


func _process(delta: float) -> void:
	t += delta
	if t >= Tuning.PULSE_S + 0.2:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := clampf(t / Tuning.PULSE_S, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 3.0)
	var a := clampf(1.0 - (t - Tuning.PULSE_S * 0.6) / (Tuning.PULSE_S * 0.6 + 0.2), 0.0, 1.0)
	var w := maxf(10.0 * s * (1.0 - k) + 3.0, 3.0)
	draw_arc(Vector2.ZERO, reach * e, 0.0, TAU, 96, Color(0.55, 0.9, 1.0, 0.85 * a), w, true)
	draw_arc(Vector2.ZERO, reach * e * 0.82, 0.0, TAU, 96, Color(1.0, 0.95, 0.7, 0.55 * a), w * 0.5, true)
	draw_circle(Vector2.ZERO, reach * e * 0.8, Color(0.5, 0.85, 1.0, 0.10 * a))
