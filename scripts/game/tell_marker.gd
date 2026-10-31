extends Node2D
## the "!" telegraph marker (scripts/game/telegraph.gd). Kept at a fixed on-screen size whatever the owner's scale.

var kind := "melee"
var t := 0.0


func set_kind(k: String) -> void:
	kind = k
	t = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if visible:
		t += delta
		var p := get_parent() as Node2D
		if p:
			scale = Vector2(1.0 / absf(p.scale.x), 1.0 / absf(p.scale.y)) if p.scale.x != 0.0 else Vector2.ONE
		queue_redraw()


func _draw() -> void:
	var c: Color = Telegraph.color(kind)
	var pop := 1.0 + 0.25 * maxf(0.0, 1.0 - t * 6.0)
	var w := 16.0 * pop
	var h := 46.0 * pop
	draw_rect(Rect2(-w / 2.0 - 4, -h - 20 - 4, w + 8, h + 8 + 26), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-w / 2.0, -h - 20, w, h), c)
	draw_rect(Rect2(-w / 2.0, -14, w, 12), c)
