class_name Pickup
extends Node2D
## Green potion (+1 carried potion; L1 drinks one: +1 size up to 6x) or red rage sphere (+rage, 10 % per Fire Knight).

var game: Node = null
var kind := "potion"
var value := 10.0
var t := 0.0
var spr := Sprite2D.new()
const SCALE := 4.0


## v: rage for spheres, stamina for blue potions (v0.8 breakables drop smaller ones); < 0 = the standard amount
func setup(g: Node, k: String, p: Vector2, v: float = -1.0) -> void:
	game = g
	kind = k
	value = v if v >= 0.0 or k != "sphere" else 10.0
	position = p
	spr.texture = AnimLib.spell_tex(k)
	spr.hframes = int(AnimLib.spell_cell(k)[2])
	var small := (k == "sphere" and value < 5.0) or (k == "stamina" and value > 0.0 and value < Tuning.STAMINA_POTION)
	spr.scale = Vector2(SCALE, SCALE) * (0.7 if small else 1.0)
	spr.offset = Vector2(0, -float(AnimLib.spell_cell(k)[1]) / 2.0)
	add_child(spr)


func _physics_process(delta: float) -> void:
	t += delta
	var ms := float(AnimLib.spells[kind]["ms"])
	spr.frame = int(t * 1000.0 / ms) % spr.hframes
	var m: Node2D = game.mera
	if m.state == "dead":
		return
	var body: Rect2 = m.hurt_rect()
	if kind == "sphere":
		spr.position.y = -30.0 - sin(t * 3.0) * 8.0
		var to: Vector2 = body.get_center() - global_position
		if t > 0.5 and to.length() < 420.0 + 30.0 * m.shown:
			position += to.normalized() * minf(to.length(), 900.0 * delta)
	else:
		spr.position.y = -sin(t * 2.5) * 4.0
	var r := Rect2(global_position + Vector2(-28, -80), Vector2(56, 80))
	if t > 0.4 and r.intersects(body):
		game.collect(self)
		queue_free()
