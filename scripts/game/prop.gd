extends Node2D
## v0.8 (S4) one breakable / set piece / secret (data: scripts/game/props.gd). Duck-typed like an enemy for Mera's
## damage loops (game.targets()): alive() hurt_rect() take_damage(amount, from_x, kind) -> bool, plus is_prop.
##   candle, candle_b, urn, crate, chest  break (shatter) and drop what Mera is low on (game.smart_drop)
##   barrel       explodes: fixed damage in a radius, kind "explosion" (pierces the Fire Knight's block), chains
##   chandelier   hangs on a chain; any hit, a nearby blast or the earthquake drops it: crushes + stuns below
##   wall         a cracked wall with an ally card behind it (4 hits)
##   lever, door  hit the lever: the door rises and shows the card behind it
##   plank        crumbling step (Mera stands on it -> it shakes, breaks, grows back); ledge = solid card ledge

const P := preload("res://scripts/game/props.gd")

var game: Node = null
var kind := ""
var extra: Dictionary = {}
var is_prop := true
var hp := 1
var k := 4.0
var state := "idle"            # idle | fall | gone | open | crumble | broken
var t := 0.0
var t_state := 0.0
var flash := 0.0
var spr: Sprite2D
var chain: Sprite2D
var card: Node2D = null        # the ally card this secret hides
var door: Node2D = null        # lever -> its door
var vy := 0.0
var stand_t := 0.0
var hits_taken := 0
var top_y := 0.0               # platforms: surface height (world y)
var crushed := 0               # chandelier: enemies hit (tests)
var _boom_left := -1.0


func setup(g: Node, kd: String, x: float, ex: Dictionary = {}) -> void:
	game = g
	kind = kd
	extra = ex
	var d: Array = P.KINDS[kind]
	k = float(d[1])
	hp = int(d[2])
	var gy: float = float(g.GROUND_Y) if g else 1060.0
	position = Vector2(x, gy)
	if kind == "chandelier":
		position.y = gy - P.CHANDELIER_Y
	if kind == "plank" or kind == "ledge":
		top_y = gy - float(ex.get("h", P.STEP_H))
		position.y = top_y


func _ready() -> void:
	spr = Sprite2D.new()
	spr.texture = P.tex(kind)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.centered = false
	spr.scale = Vector2(k, k)
	var sz := spr.texture.get_size()
	match kind:
		"chandelier":
			spr.offset = Vector2(-sz.x / 2.0, -sz.y)               # hangs: its bottom at position
			chain = Sprite2D.new()
			chain.texture = load(P.DIR + "chain.png")
			chain.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			chain.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			chain.region_enabled = true
			chain.centered = false
			var len_px := (position.y - sz.y * k + 60.0) / k
			chain.region_rect = Rect2(0, 0, chain.texture.get_width(), len_px)
			chain.scale = Vector2(k, k)
			chain.position = Vector2(-chain.texture.get_width() * k / 2.0, -sz.y * k - len_px * k)
			add_child(chain)
			z_index = -3
		"plank", "ledge":
			spr.offset = Vector2(-sz.x / 2.0, 0.0)                 # its top surface at position
			z_index = -2
			if kind == "plank":
				spr.modulate = Color(0.92, 0.85, 0.78)
		"wall", "door":
			spr.offset = Vector2(-sz.x / 2.0, -sz.y)
			z_index = 6                                            # in front of the hidden card
		_:
			spr.offset = Vector2(-sz.x / 2.0, -sz.y)
			z_index = -4
	add_child(spr)


func alive() -> bool:
	return hp > 0 and state == "idle" and kind in P.HITTABLE


func blocking() -> bool:
	return blocks_path()


func hurt_rect() -> Rect2:
	var sz := spr.texture.get_size() * k if spr else Vector2(40, 40)
	if kind == "chandelier":
		return Rect2(global_position + Vector2(-sz.x / 2.0, -sz.y), sz)
	return Rect2(global_position + Vector2(-sz.x / 2.0, -sz.y), sz)


## platforms: the walkable rect [x0, x1] at top_y (null when crumbled)
func surface() -> Vector3:
	var w := spr.texture.get_size().x * k
	return Vector3(global_position.x - w / 2.0 + 6.0, global_position.x + w / 2.0 - 6.0, top_y)


func solid() -> bool:
	return (kind == "plank" and state in ["idle", "crumble"]) or kind == "ledge"


## Cracked walls and closed doors are solid. An opened door stops blocking once it has risen.
func blocks_path() -> bool:
	if kind == "wall":
		return hp > 0 and state == "idle"
	if kind == "door":
		if state != "open":
			return true
		if spr == null or spr.texture == null:
			return false
		return spr.position.y > -spr.texture.get_height() * k * 0.55
	return false


func take_damage(amount: int, from_x: float, kind_: String = "melee") -> bool:
	if not alive() or amount <= 0:
		return false
	hits_taken += 1
	flash = 0.1
	if kind == "chandelier":
		_drop()
		return true
	if kind == "lever":
		_pull()
		return true
	# everything but the cracked wall breaks on one hit. A blast still clears a wall.
	hp -= hp if (kind_ == "explosion" or kind != "wall") else 1
	if kind in ["crate"] and hp > 0:
		spr.texture = load(P.DIR + "crate_hit.png")
		get_tree().create_timer(0.12).timeout.connect(func(): if is_instance_valid(self) and hp > 0: spr.texture = P.tex(kind))
	if kind == "wall" and hp > 0:
		Sfx.play("stone", 1.2, -6.0)
		position.x += 3.0 if from_x < global_position.x else -3.0
		return true
	if hp <= 0:
		_break(from_x, kind_)
	return true


func _break(from_x: float, why: String) -> void:
	var from := Vector2(from_x, hurt_rect().get_center().y + 30.0)
	match kind:
		"barrel":
			_explode()
			return
		"chest":
			state = "open"
			hp = 0
			spr.texture = load(P.DIR + "chest_open.png")
			Sfx.play("wood", 1.2)
			Sfx.play("potion", 0.8, -4.0)
			if game:
				game.break_drop(global_position + Vector2(0, -30))
				game.debris.spark(hurt_rect().get_center(), 3.0)
			return
	state = "broken"
	hp = 0
	Sfx.play(String(P.KINDS[kind][4]), 0.8 if kind in ["urn", "wall"] else 1.0)
	if game:
		game.debris.shatter_node(spr, from, 620.0 if kind != "wall" else 900.0, {"cols": 6 if kind != "wall" else 8, "rows": 6 if kind != "wall" else 9, "life": 1.8})
		if kind == "crate":
			_crate_pieces(from)
		var tier: String = String(P.KINDS[kind][3])
		if tier != "" or kind == "wall":
			game.break_drop(global_position + Vector2(0, -10))
		if kind == "wall":
			game.shake(10.0, 0.25)
			HitStop.stop(Tuning.HITSTOP_HEAVY_MS)
			game.reveal_secret(self)
	queue_free()


func _crate_pieces(from: Vector2) -> void:
	for i in range(1, 5):
		var s := Sprite2D.new()
		s.texture = load(P.DIR + "crate_piece%d.png" % i)
		s.scale = Vector2(k, k)
		s.global_position = global_position + Vector2((i - 2.5) * 20.0, -40.0)
		game.world.add_child(s)
		game.debris.shatter_node(s, from, 700.0, {"cols": 1, "rows": 1, "life": 1.4})
		s.queue_free()


# ---------------------------------------------------------------- barrel
func _explode() -> void:
	state = "broken"
	hp = 0
	var c := global_position + Vector2(0, -spr.texture.get_height() * k * 0.5)
	if game:
		game.barrel_blast(c, self)
		game.break_drop(global_position)
	var fx := AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.set_animation_loop("default", false)
	sf.set_animation_speed("default", 20.0)
	var sheet: Texture2D = load(P.DIR + "barrel_boom.png")
	for i in 12:
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(i * 32, 0, 32, 32)
		sf.add_frame("default", at)
	fx.sprite_frames = sf
	fx.scale = Vector2(10, 10)
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fx.global_position = c
	fx.z_index = 9
	fx.animation_finished.connect(fx.queue_free)
	if game:
		game.world.add_child(fx)
		game.debris.shatter_node(spr, c + Vector2(0, 40), 1100.0, {"cols": 4, "rows": 5, "life": 1.6, "tint": Color(1.0, 0.6, 0.45)})
	fx.play("default")
	queue_free()


## a blast reached this prop (another barrel, a chandelier ...)
func blast_hit(delay: float) -> void:
	if not alive():
		return
	if kind == "barrel":
		_boom_left = delay
		state = "lit"
		return
	if kind == "chandelier":
		_drop()
		return
	take_damage(99, global_position.x - 1.0, "explosion")


# ---------------------------------------------------------------- chandelier
func _drop() -> void:
	if state != "idle":
		return
	state = "fall"
	hp = 0
	vy = 0.0
	Sfx.play("metal", 1.3)
	if chain:
		var tw := create_tween()
		tw.tween_property(chain, "modulate:a", 0.0, 0.25)


func _land_chandelier() -> void:
	state = "broken"
	var r := hurt_rect().grow_individual(40.0, 0.0, 40.0, 30.0)
	if game:
		for e in game.enemies():
			if r.intersects(e.hurt_rect()):
				crushed += 1
				e.take_damage(P.CHANDELIER_DMG, global_position.x, "crush")
				if e.alive() and e.has_method("stun") and e.get("on_ground"):
					e.stun(P.CHANDELIER_STUN_S)
		game.shake(16.0, 0.3)
		HitStop.stop(Tuning.HITSTOP_HEAVY_MS)
		game.debris.shatter_node(spr, global_position + Vector2(0, 60), 900.0, {"cols": 8, "rows": 7, "life": 2.0})
		game.debris.spark(global_position + Vector2(0, -40), 4.0)
	Sfx.play("glass", 0.7)
	Sfx.play("metal", 0.7)
	queue_free()


# ---------------------------------------------------------------- lever / door
func _pull() -> void:
	state = "open"
	hp = 0
	spr.texture = load(P.DIR + "lever_on.png")
	Sfx.play("metal", 1.0)
	Sfx.play("clang", 0.7, -6.0)
	if door != null and is_instance_valid(door):
		door.open()


func open() -> void:
	if state != "idle":
		return
	state = "open"
	Sfx.play("plank", 0.6)
	var tw := create_tween()
	tw.tween_property(spr, "position:y", -spr.texture.get_height() * k * 0.85, 1.1).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(spr, "modulate:a", 0.25, 1.1)
	tw.tween_callback(func(): if game: game.reveal_secret(self))
	if game:
		game.shake(5.0, 1.0)


# ---------------------------------------------------------------- tick
func _physics_process(delta: float) -> void:
	t += delta
	t_state += delta
	flash -= delta
	if spr:
		var a := spr.modulate.a
		spr.modulate = Color(3, 3, 3, a) if flash > 0.0 else (Color(0.92, 0.85, 0.78, a) if kind == "plank" else Color(1, 1, 1, a))
	match kind:
		"chandelier":
			if state == "idle":
				rotation = sin(t * 1.3) * 0.025
			elif state == "fall":
				vy += 2600.0 * delta
				position.y += vy * delta
				rotation = move_toward(rotation, 0.0, delta)
				if game and position.y >= float(game.GROUND_Y) - 6.0:
					position.y = float(game.GROUND_Y) - 6.0
					_land_chandelier()
		"barrel":
			if state == "lit":
				_boom_left -= delta
				spr.position.x = sin(t * 60.0) * 3.0
				if _boom_left <= 0.0:
					hp = 0
					_explode()
		"plank":
			_crumble_tick(delta)


func _crumble_tick(delta: float) -> void:
	var m: Node2D = game.mera if game else null
	match state:
		"idle":
			if m and m.on_ground and absf(m.ground_y - top_y) < 1.0 and m.global_position.x >= surface().x and m.global_position.x <= surface().y:
				stand_t += delta
				if stand_t >= P.CRUMBLE_S:
					state = "crumble"
					t_state = 0.0
					Sfx.play("plank", 0.8)
			else:
				stand_t = 0.0
		"crumble":
			spr.position.x = sin(t * 70.0) * 4.0
			if t_state >= P.CRUMBLE_SHAKE_S:
				state = "gone"
				t_state = 0.0
				spr.position.x = 0.0
				Sfx.play("wood", 0.8)
				if game:
					game.debris.shatter_node(spr, global_position + Vector2(0, -60), 380.0, {"cols": 7, "rows": 2, "life": 1.4})
				spr.visible = false
		"gone":
			if t_state >= P.CRUMBLE_BACK_S:
				state = "idle"
				stand_t = 0.0
				spr.visible = true
				spr.modulate.a = 0.0
				var tw := create_tween()
				tw.tween_property(spr, "modulate:a", 1.0, 0.5)
