extends "res://scripts/game/cl_warlord.gd"
## The final boss: King Lucius Nerochilde (Roster id nero), one health pool in three forms (Roster.DEFS nero, nero_reaper, nero_giant).
## The Warlord's phase rule picks the form: above 2/3 hp the Medieval King, above 1/3 the skull-cloak reaper, the rest the skull giant.
##   form 1  the King: sword swings, a spin, an overhead chop, three dark bolts from range, a lunge
##   form 2  the reaper: scythe slashes (each throws a pale slash arc), bolts, and a charge across the court; if he reaches the wall he
##           crashes and is stunned (CHARGE_STUN s)
##   form 3  the giant: wide green slash arcs, the charge, and a jump slam: two floor shockwaves roll out from where he lands (jump them);
##           faster tells and steps
## He does not parry and has no shield: every attack is telegraphed. His damage never scales with anything. The node's `id` stays "nero"
## (loot, names, the finale); `form_id` says which body he wears. Beating him ends the game: Roster.FINALE[20] plays the ending pages.

const FORMS := {1: "nero", 2: "nero_reaper", 3: "nero_giant"}
const BEAM := preload("res://scripts/game/king_beam.gd")

var form_id := "nero"
var forms_log: Array = ["nero"]           # forms worn, in order (tests)
var slashes := 0                          # slash arcs thrown (tests)
var beam: Node2D = null                   # the long attack being wound up or fired (king_beam.gd)
var beams_fired := 0                      # (tests)


## the form change: his art, size, speed and attack list are the new form's; he takes a breath while it settles
func _check_phase() -> void:
	var before := phase
	super()
	if phase == before:
		return
	_set_form(String(FORMS[phase]))
	attacks = _phase_attacks(phase)
	if phase >= 3:
		speed = base_speed * 1.2


func _set_form(fid: String) -> void:
	form_id = fid
	forms_log.append(fid)
	d = ROSTER.def(fid)
	art = ROSTER.art(fid)
	native = int(art["facing"])
	k = float(d["k"])
	idle_a = String(d["idle"])
	move_a = String(d["move"])
	base_speed = float(d["speed"])
	speed = base_speed
	atk = {}
	marker.visible = false
	vx = 0.0
	sprite.sprite_frames = _frames(fid)
	_place_overhead()
	_face(facing)
	_to_idle(0.9)
	flash = 0.6
	if game:
		game.shake(14.0, 0.5)
		game.hit_spark(hurt_rect().get_center(), 5.0)
	Sfx.play("boom_big", 0.6, -2.0)
	_spawn_slash("slash_pale" if fid == "nero_reaper" else "slash_green", 1.6)


## a long attack (atk "beam": "energy" or "zigzag"): the aiming line appears with the "!" and follows the player until the tell ends
func _start_tell(a: Dictionary, face: int) -> void:
	super(a, face)
	if a.has("beam") and get_parent() != null:
		beam = BEAM.new()
		var b: Array = art["body"]
		beam.setup(game, self, String(a["beam"]), int(a["dmg"]), Vector2(body_w() * 0.3, float(b[1]) * k * 0.55))
		get_parent().add_child(beam)


func _start_active(m: Node2D) -> void:
	super(m)
	if atk.has("beam") and is_instance_valid(beam):
		beam.fire()
		beams_fired += 1
	if atk.has("fx") and String(atk["fx"]) != "":
		_spawn_slash(String(atk["fx"]), 1.0)


## a slash arc in front of his chest: the animated effect (Roster _fx), once, then it frees itself
func _spawn_slash(fx_name: String, size_mul: float) -> void:
	var fx_all: Dictionary = ROSTER.data().get("_fx", {})
	if not fx_all.has(fx_name) or get_parent() == null:
		return
	slashes += 1
	var e: Dictionary = fx_all[fx_name]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("s")
	sf.set_animation_speed("s", float(e["fps"]))
	sf.set_animation_loop("s", false)
	for p in e["frames"]:
		sf.add_frame("s", load(p))
	var fxs := AnimatedSprite2D.new()
	fxs.sprite_frames = sf
	fxs.centered = false
	fxs.offset = -Vector2(float(e["pivot"][0]), float(e["pivot"][1]))
	var sc := k * 1.1 * size_mul
	fxs.scale = Vector2(sc * facing, sc)
	var b: Array = art["body"]
	fxs.position = global_position + Vector2(facing * body_w() * 0.2, float(b[1]) * k * 0.5)
	fxs.z_index = 6
	fxs.animation_finished.connect(fxs.queue_free)
	get_parent().add_child(fxs)
	fxs.play("s")


## the slash arcs of the reaper and the giant hit a box out in front of him (the art itself barely moves)
func attack_rect() -> Rect2:
	if state == "atk" and atk.has("beam"):
		return Rect2()                                  # the beam is its own hit test (king_beam.gd)
	if state == "atk" and not atk.is_empty() and atk.has("reach") and _window_of(sprite.frame) >= 0:
		var b: Array = art["body"]
		var reach := float(atk["reach"]) * k
		var top := float(b[1]) * k
		var x0 := global_position.x if facing > 0 else global_position.x - reach
		return Rect2(Vector2(x0, global_position.y + top * 0.95), Vector2(reach, -top * 0.9))
	return super()
