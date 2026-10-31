class_name Shot
extends Node2D
## Mera's projectiles, drawn from the canon cast formulas (tools/export_game_anims.py spell sprites):
##  "bolt"     quick fire (pick3 v4): level, constant 400 px/s x size, flies until it hits or leaves the screen.
##  "fireball" rear explosion (pick2 v4): leaves along the wand (11 deg down), curves down to the ground at the
##             canon distance (130 px x size) or explodes on the first enemy it touches -> ansimuz Ground Explosion.

var game: Node = null
var kind := "bolt"
var dir := 1
var size := 1.0
var damaging := true
var shot := {}
var t := 0.0
var start := Vector2.ZERO
var trail: Array = []
var spr: Sprite2D
var tex_discs: Texture2D
var done := false
var speed_mult := 1.0          # v0.4: B, Y fast quick fire = 2.0


func speed() -> float:
	return 400.0 * size * speed_mult


func setup(g: Node, k: String, p: Vector2, d: int, s: float, sh: Dictionary, dmg_on: bool) -> void:
	game = g
	kind = k
	start = p
	position = p
	dir = d
	size = s
	shot = sh
	damaging = dmg_on
	material = AnimLib.fx_mat
	if kind == "bolt":
		spr = Sprite2D.new()
		spr.texture = AnimLib.spell_tex("bolt")
		spr.hframes = int(AnimLib.spell_cell("bolt")[2])
		spr.centered = false
		spr.offset = -Vector2(9, 4)
		spr.scale = Vector2(-dir * size, size)       # sprite flies LEFT natively
		spr.material = AnimLib.fx_mat
		add_child(spr)
	else:
		tex_discs = AnimLib.spell_tex("discs")


func _physics_process(delta: float) -> void:
	if done:
		return
	t += delta
	if kind == "bolt":
		position.x += dir * speed() * delta
		spr.frame = int(t * 1000.0 / 40.0) % spr.hframes
		var r := Rect2(position - Vector2(5, 3) * size, Vector2(10, 6) * size)
		if damaging:
			for e in game.enemies():
				if e.alive() and r.intersects(e.hurt_rect()):
					game.mera.deal(e, 1, position.x - dir * 50.0, "bolt")
					game.hit_spark(position, size)
					queue_free()
					return
		if absf(position.x - game.camera_x()) > 1920.0:
			queue_free()
		return
	# fireball
	var sp := float(shot["speed_px_s"])
	var dist := float(shot["dist"])
	var tana := tan(deg_to_rad(float(shot["ang"])))
	var gdy := float(shot["ground_dy"]) - 4.0
	var sd := minf(sp * t, dist)
	var k := (gdy - dist * tana) / (dist * dist)
	position = start + Vector2(dir * sd, sd * tana + k * sd * sd + 0.6 * sin(sd * 0.35)) * size
	trail.push_front(position)
	if trail.size() > 7:
		trail.pop_back()
	queue_redraw()
	var hit := sd >= dist
	if damaging and not hit:
		var r := Rect2(position - Vector2(4, 4) * size, Vector2(8, 8) * size)
		for e in game.enemies():
			if e.alive() and r.intersects(e.hurt_rect()):
				hit = true
	if hit:
		done = true
		game.explode(Vector2(position.x, game.GROUND_Y), size, damaging)
		queue_free()


func _draw() -> void:
	if kind != "fireball":
		return
	var cell: Array = AnimLib.spell_cell("discs")
	var w := float(cell[0])
	for j in range(trail.size() - 1, -1, -1):
		var p: Vector2 = trail[j] - position
		var di := mini(j, int(cell[2]) - 1)
		var sz := Vector2(w, w) * size
		draw_texture_rect_region(tex_discs, Rect2(p - sz / 2.0, sz), Rect2(di * w, 0, w, w))
