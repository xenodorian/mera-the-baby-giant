extends Node2D
## v0.7 colour-coded ally card lying on the map (allies.gd CARDS). Touch it to collect it; R1 then summons that ally.

const AL := preload("res://scripts/game/allies.gd")
const ROSTER := preload("res://scripts/game/roster.gd")
var game: Node
var ally_id := ""
var t := 0.0
var face: Texture2D
var taken := false
var base_y := -1.0             # v0.8: a card on a ledge floats above the ledge instead of the ground
var hidden_by: Node2D = null   # v0.8: a secret wall / door in front of it; it can't be seen or taken until revealed


func setup(g: Node, aid: String, p: Vector2) -> void:
	game = g
	ally_id = aid
	position = p


func _ready() -> void:
	z_index = 5
	face = ROSTER.face(ally_id)


func rect() -> Rect2:
	return Rect2(global_position + Vector2(-48, -150), Vector2(96, 150))


func _process(delta: float) -> void:
	t += delta
	var by := base_y if base_y >= 0.0 else (float(game.GROUND_Y) - 40.0 if game else position.y)
	position.y = by + sin(t * 3.0) * 8.0
	visible = not hidden()
	queue_redraw()


func hidden() -> bool:
	return hidden_by != null and is_instance_valid(hidden_by)


func _physics_process(_delta: float) -> void:
	if taken or game == null or hidden():
		return
	if game.mera.state != "dead" and rect().intersects(game.mera.hurt_rect()):
		taken = true
		game.collect_card(self)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(1.6, 1.6), 0.25)
		tw.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
		tw.tween_callback(queue_free)


func _draw() -> void:
	var c: Color = AL.COLORS[ally_id]
	var glow := 0.5 + 0.5 * sin(t * 4.0)
	draw_rect(Rect2(-56, -116, 112, 152), Color(c.r, c.g, c.b, 0.18 + 0.15 * glow))
	draw_rect(Rect2(-46, -106, 92, 132), Color(0.06, 0.05, 0.09))
	draw_rect(Rect2(-46, -106, 92, 132), c, false, 6.0)
	draw_rect(Rect2(-38, -98, 76, 14), c)
	draw_rect(Rect2(-38, 8, 76, 10), c)
	if face != null:
		var inner := Rect2(-36, -80, 72, 84)
		var ts := face.get_size()
		var fit := minf(inner.size.x / maxf(ts.x, 1.0), inner.size.y / maxf(ts.y, 1.0))
		var ds := ts * fit
		var dp := Vector2(inner.position.x + (inner.size.x - ds.x) * 0.5, inner.end.y - ds.y)
		draw_texture_rect(face, Rect2(dp, ds), false)
