extends Node2D
## Draws hurtbox outlines and foot pivots when enabled (H key).

var targets: Array = []
var ground_y := 0.0


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	draw_line(Vector2(0, ground_y), Vector2(1920, ground_y), Color(0.3, 0.6, 1.0, 0.8), 1.0)
	for t in targets:
		var cs: CollisionShape2D = t.get_node("Hurtbox/Shape")
		var r := (cs.shape as RectangleShape2D).size
		var c := cs.global_position
		var area: Area2D = t.get_node("Hurtbox")
		var col := Color(1, 0.2, 0.2) if area.has_overlapping_areas() else Color(0.2, 1, 0.3)
		draw_rect(Rect2(c - r / 2.0, r), col, false, 2.0)
		var p: Vector2 = t.global_position
		draw_line(p + Vector2(-8, 0), p + Vector2(8, 0), Color.YELLOW, 2.0)
		draw_line(p + Vector2(0, -8), p + Vector2(0, 8), Color.YELLOW, 2.0)
