extends Node2D
## The small bubble's timer: a ring that empties over CROUCH_BUBBLE_S.

var frac := 1.0
var radius := 40.0


func _draw() -> void:
	if frac <= 0.001:
		return
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(0.7, 0.9, 1.0, 0.28), 3.0, true)
	var a0 := -PI * 0.5
	draw_arc(Vector2.ZERO, radius, a0, a0 + TAU * frac, 48, Color(0.55, 0.95, 1.0, 0.95), 4.0, true)
