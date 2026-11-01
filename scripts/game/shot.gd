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
var up := false                # v0.9.1 Up+Y: the same bolt flies straight up (sprite rotated head-up)
var aim := Vector2.ZERO        # set: fly this way (up, and the two upward diagonals)
var bulk := 1.0                # Up+Y bolts are drawn bigger. Speed stays the quick-fire speed.
var homing := false            # v0.12.2 unlock: a bolt bends toward the nearest enemy in range
var heading := Vector2.ZERO    # homing: the current flight direction (unit vector)
const HOMING_TURN := 7.0       # rad/s the bolt can turn
const HOMING_RANGE := 1400.0   # px: enemies farther than this are not chased


func hit_rect() -> Rect2:
	var vis := size * bulk
	if kind == "bolt":
		if up:
			return Rect2(global_position - Vector2(3, 5) * vis, Vector2(6, 10) * vis)
		return Rect2(global_position - Vector2(5, 3) * vis, Vector2(10, 6) * vis)
	return Rect2(global_position - Vector2(6, 6) * vis, Vector2(12, 12) * vis)


## v0.9.1: an enemy projectile met this shot. Both explode (no extra damage; the blast is the tell).
func burst() -> void:
	if done:
		return
	done = true
	if game:
		game.explode(global_position, maxf(size * 0.55, 0.8), false)
	queue_free()


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


func _ready() -> void:
	var lib: Node = get_node("/root/AnimLib")
	material = lib.fx_mat
	if kind == "bolt":
		spr = Sprite2D.new()
		spr.texture = lib.spell_tex("bolt")
		spr.hframes = int(lib.spell_cell("bolt")[2])
		spr.centered = false
		spr.offset = -Vector2(9, 4)
		var vis := size * bulk
		spr.scale = Vector2(-dir * vis, vis)       # sprite flies LEFT natively
		spr.material = lib.fx_mat
		add_child(spr)
		if up or aim != Vector2.ZERO:
			spr.scale = Vector2(vis, vis)
			var dir_v := aim if aim != Vector2.ZERO else Vector2(0, -1)
			spr.rotation = dir_v.angle() - PI
	else:
		tex_discs = lib.spell_tex("discs")


## v0.12.2: turn toward the nearest live enemy (centre of its hurt box) at HOMING_TURN, keep the speed, and point
## the sprite along the new heading. With no enemy in range it flies straight on.
func _home(delta: float) -> Vector2:
	var vis := size * bulk
	if heading == Vector2.ZERO:
		var base := aim if aim != Vector2.ZERO else (Vector2.UP if up else Vector2(dir, 0))
		heading = base.normalized()
	var tgt := _homing_target()
	if tgt != null:
		var want: Vector2 = tgt.hurt_rect().get_center() - position
		if want.length() > 1.0:
			var ang := heading.angle_to(want.normalized())
			heading = heading.rotated(clampf(ang, -HOMING_TURN * delta, HOMING_TURN * delta)).normalized()
	if spr:
		spr.scale = Vector2(vis, vis)
		spr.rotation = heading.angle() - PI
	return heading


func _homing_target() -> Node2D:
	var best: Node2D = null
	var bd := HOMING_RANGE
	for e in game.enemies():
		if is_instance_valid(e) and e.alive():
			var d := position.distance_to(e.hurt_rect().get_center())
			if d < bd:
				best = e
				bd = d
	return best


func _physics_process(delta: float) -> void:
	if done:
		return
	t += delta
	if kind == "bolt":
		if homing:
			position += _home(delta) * speed() * delta
		elif aim != Vector2.ZERO:
			position += aim.normalized() * speed() * delta
		elif up:
			position.y -= speed() * delta
		else:
			position.x += dir * speed() * delta
		spr.frame = int(t * 1000.0 / 40.0) % spr.hframes
		var vis := size * bulk
		var r := Rect2(position - Vector2(3, 5) * vis, Vector2(6, 10) * vis) if up else Rect2(position - Vector2(5, 3) * vis, Vector2(10, 6) * vis)
		if damaging:
			for e in game.enemies():
				if e.alive() and r.intersects(e.hurt_rect()):
					game.mera.deal(e, 1, position.x if up else position.x - dir * 50.0, "bolt")
					game.hit_spark(position, vis)
					queue_free()
					return
			var pr: Node2D = game.prop_at(r)
			if pr != null:
				game.mera.deal(pr, 1, position.x, "bolt")
				game.hit_spark(position, vis)
				queue_free()
				return
		if absf(position.x - game.camera_x()) > 2200.0 or position.y < game.cam.position.y - 800.0:
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
		if not hit and game.prop_at(r) != null:
			hit = true
	if hit:
		done = true
		game.explode(Vector2(position.x, game.GROUND_Y), size, damaging)
		queue_free()


func _draw() -> void:
	if kind != "fireball":
		return
	var cell: Array = get_node("/root/AnimLib").spell_cell("discs")
	var w := float(cell[0])
	for j in range(trail.size() - 1, -1, -1):
		var p: Vector2 = trail[j] - position
		var di := mini(j, int(cell[2]) - 1)
		var sz := Vector2(w, w) * size
		draw_texture_rect_region(tex_discs, Rect2(p - sz / 2.0, sz), Rect2(di * w, 0, w, w))
