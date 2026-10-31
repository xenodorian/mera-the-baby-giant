extends Node2D
## v0.5 exit gate at the right end of each map: a pulsing pillar of light. Reaching it clears the level.

var t := 0.0
var game: Node = null     # v0.6: locked (dim, "SLAY THE DRAGON") while the level boss lives


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var locked: bool = game != null and game.exit_locked()
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	if locked:
		modulate = Color(0.55, 0.35, 0.35, 0.8)
	else:
		modulate = Color(1, 1, 1, 1)
	for i in 6:
		var w := 60.0 + i * 34.0
		var a := (0.22 - i * 0.03) * (0.7 + 0.3 * pulse)
		draw_rect(Rect2(-w / 2.0, -760.0, w, 760.0), Color(1.0, 0.85, 0.5, a))
	draw_rect(Rect2(-18, -760, 36, 760), Color(1, 0.95, 0.8, 0.55 + 0.3 * pulse))
	for k in 8:
		var y := -fposmod(t * 220.0 + k * 95.0, 760.0)
		draw_rect(Rect2(-60 + 15 * sin(k * 1.7 + t), y, 8, 8), Color(1, 0.9, 0.6, 0.8))
	var f := ThemeDB.fallback_font
	if locked:
		var msg := "SLAY THE DRAGON" if game == null or not game.has_method("exit_lock_text") else String(game.exit_lock_text())
		draw_string(f, Vector2(-360, -800), msg, HORIZONTAL_ALIGNMENT_CENTER, 720, 44, Color(1, 0.6, 0.5))
	else:
		draw_string(f, Vector2(-70, -800), "EXIT", HORIZONTAL_ALIGNMENT_CENTER, 140, 48, Color(1, 0.9, 0.6))
