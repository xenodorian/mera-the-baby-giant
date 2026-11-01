class_name Pickup
extends Node2D
## Green potion (+1 carried potion; L1 drinks one: +1 size up to 6x) or red rage sphere (+rage, 10 % per Fire Knight).
## v0.12.1: "key" (opens a locked chest; drawn by key_art.gd) and chest contents, which pop out in an arc (pop()).
const KEY_ART := preload("res://scripts/game/key_art.gd")
const POP_S := 0.35

var game: Node = null
var kind := "potion"
var value := 10.0
var t := 0.0
var spr := Sprite2D.new()
const SCALE := 4.0
var pop_from := Vector2.ZERO
var pop_to := Vector2.ZERO
var pop_t := -1.0              # >= 0 while the item is arcing from pop_from to pop_to


## v0.12.1: the item leaves `from` in a small arc and lands at `to` (call before it is added to the tree)
func pop(from: Vector2, to: Vector2) -> void:
	pop_from = from
	pop_to = to
	pop_t = 0.0
	position = from


## v: rage for spheres, stamina for blue potions (v0.8 breakables drop smaller ones); < 0 = the standard amount
func setup(g: Node, k: String, p: Vector2, v: float = -1.0) -> void:
	game = g
	kind = k
	value = v if v >= 0.0 or k != "sphere" else 10.0
	position = p
	if kind == "key":
		var kt: Texture2D = KEY_ART.texture()
		spr.texture = kt
		spr.hframes = 1
		spr.scale = Vector2(SCALE, SCALE)
		spr.offset = Vector2(0, -float(kt.get_height()) / 2.0)
		add_child(spr)
		set_meta("art", "key")
		return
	if kind == "coin" and ResourceLoader.exists("res://assets/ui/coin.png"):
		spr.texture = load("res://assets/ui/coin.png")
		spr.hframes = 1
		spr.scale = Vector2(3, 3)
		spr.offset = Vector2(0, -8)
		add_child(spr)
		set_meta("art", "coin")
		return
	var art := "potion"
	if kind == "sphere" or kind == "rage_max":
		art = "sphere" if kind != "rage_max" else "sphere"
	elif kind == "mana" or kind == "stamina" or kind == "stamina_max":
		art = "stamina"
	elif kind == "card":
		art = "potion"
	if kind == "rage_max":
		art = "sphere"
	spr.texture = AnimLib.spell_tex(art)
	spr.hframes = int(AnimLib.spell_cell(art)[2])
	var small := (art == "sphere" and kind != "rage_max" and value < 5.0) or (kind == "stamina" and value > 0.0 and value < Tuning.STAMINA_POTION)
	spr.scale = Vector2(SCALE, SCALE) * (0.7 if small else 1.0)
	if kind == "rage_max":
		spr.modulate = Color(1.0, 0.82, 0.35)
		spr.scale *= 1.15
	elif kind == "card":
		spr.modulate = Color(1.0, 0.45, 0.85)
	elif kind == "coin":
		spr.modulate = Color(1.0, 0.82, 0.25)
	spr.offset = Vector2(0, -float(AnimLib.spell_cell(art)[1]) / 2.0)
	add_child(spr)
	set_meta("art", art)


func _physics_process(delta: float) -> void:
	t += delta
	if pop_t >= 0.0:
		pop_t += delta
		var u := minf(pop_t / POP_S, 1.0)
		position = pop_from.lerp(pop_to, u) + Vector2(0, -sin(u * PI) * 70.0)
		if u >= 1.0:
			pop_t = -1.0
			position = pop_to
	if kind != "coin" and kind != "key":
		var art := "sphere" if kind == "rage_max" else kind
		if kind == "mana" or kind == "card":
			art = "stamina" if kind == "mana" else "potion"
		var ms := float(AnimLib.spells[art]["ms"])
		spr.frame = int(t * 1000.0 / ms) % maxi(spr.hframes, 1)
	var m: Node2D = game.mera
	if m.state == "dead":
		return
	var body: Rect2 = m.hurt_rect()
	var pull := _bubble_pull(m)
	var mv: Dictionary = m.get("mv") if m.get("mv") is Dictionary else {}
	var sliding: bool = String(m.get("state")) == "move" and String(mv.get("key", "")) == "slide"
	if kind == "sphere" or kind == "rage_max":
		spr.position.y = -30.0 - sin(t * 3.0) * 8.0
		if not pull:
			var to: Vector2 = body.get_center() - global_position
			if t > 0.5 and to.length() < 420.0 + 30.0 * m.shown:
				position += to.normalized() * minf(to.length(), 900.0 * delta)
	else:
		spr.position.y = -sin(t * 2.5) * 4.0
	if pull and absf(global_position.x - m.global_position.x) <= 960.0:
		var dest := body.get_center()
		var to_m := dest - global_position
		var step := Tuning.BUBBLE_PULL * delta
		if to_m.length() <= step:
			global_position = dest
		else:
			global_position += to_m.normalized() * step
	var r := Rect2(global_position + Vector2(-28, -80), Vector2(56, 80))
	var touch := body.grow(28.0) if sliding else body
	if (t > 0.4 or pull or sliding) and r.intersects(touch):
		game.collect(self)
		queue_free()


## full L2 bubble and the small crouch bubble both vacuum every item on screen
func _bubble_pull(m: Node2D) -> bool:
	if m.get("barrier_on") == true:
		return true
	return m.has_method("crouch_bubble_on") and m.crouch_bubble_on()
