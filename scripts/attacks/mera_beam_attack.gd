extends Node2D
## Mera "Wand Beam" attack. Add as a child of the Mera node (scripts/mera.gd); everything it owns
## (cast sprite, beam drawing, hitbox, range ray) lives under one Rig node whose scale is
## (size_scale * direction, size_scale), so the attack scales 1x..19x with her and needs no per-size data.
##
## Timeline at 25 fps (40 ms per frame, the pack's own timing), from the 1x atk animation:
##   atk frames 1-5 wind-up -> HOLD frame 6 (arm/wand fully extended) for 29 frames:
##   6 charge, 3 fire (head races out), 14 sustain, 6 fade -> atk frames 7-10 settle -> "to idle" 11-17.
## The art faces left; in the held pose the wand points to the RIGHT (behind her). So by default the beam
## fires out of the wand, i.e. behind Mera. Set toward_facing = true to fire where she faces instead
## (she turns her back to cast).

signal hit(target: Node, damage: int)
signal finished

const STRIP := "res://assets/characters/merakintsugi/derived/beam_cast/mera_beam_cast_strip17.png"
const CELL := Vector2i(160, 64)
const PIVOT := Vector2(139, 63)          # feet, aligned to mera_export idle (see mera_beam_cast.json)
const ORIGIN := Vector2(11, -24)         # first pixel past the wand tip, relative to the feet, 1x px
const HOLD_FRAME := 5
const CHARGE := 6
const FIRE := 3
const SUSTAIN := 14
const FADE := 6
const FRAME_SEC := 0.04
const MAX_RANGE := 150.0                 # 1x px; multiplied by size through the Rig scale
const HIT_HALF_HEIGHT := 5.0             # covers the 0.30 band at peak width
const TICK_FRAMES := 3                   # damage tick every 0.12 s while active
const DAMAGE := 1

@export var toward_facing := false

var casting := false
var _seq: Array = []                     # [atk frame, beam phase, phase index]
var _i := 0
var _acc := 0.0
var _hit_len := MAX_RANGE
var _last_tick := {}

@onready var mera: Node2D = get_parent()
var rig: Node2D
var sprite: AnimatedSprite2D
var fx: Node2D
var hitbox: Area2D
var hit_shape: CollisionShape2D
var ray: RayCast2D


func _ready() -> void:
	rig = Node2D.new(); rig.name = "Rig"; add_child(rig)
	sprite = AnimatedSprite2D.new(); sprite.name = "CastSprite"
	var sf := SpriteFrames.new()
	var tex: Texture2D = load(STRIP)
	for i in 17:
		var at := AtlasTexture.new(); at.atlas = tex
		at.region = Rect2(i * CELL.x, 0, CELL.x, CELL.y)
		sf.add_frame("default", at)
	sprite.sprite_frames = sf
	sprite.centered = false
	sprite.offset = -PIVOT
	sprite.visible = false
	rig.add_child(sprite)
	fx = Node2D.new(); fx.name = "Beam"; fx.set_script(load("res://scripts/attacks/beam_fx.gd"))
	fx.position = ORIGIN
	fx.floor_y = -ORIGIN.y
	fx.charge_frames = CHARGE; fx.fade_frames = FADE
	rig.add_child(fx)
	hitbox = Area2D.new(); hitbox.name = "Hitbox"
	hitbox.collision_layer = 0            # only detects; never detected by the range ray
	hitbox.monitorable = false
	hitbox.monitoring = false
	hit_shape = CollisionShape2D.new(); hit_shape.shape = RectangleShape2D.new()
	hitbox.add_child(hit_shape)
	rig.add_child(hitbox)
	ray = RayCast2D.new(); ray.name = "RangeRay"
	ray.position = ORIGIN
	ray.target_position = Vector2(MAX_RANGE, 0)
	ray.collide_with_areas = true
	ray.collide_with_bodies = true
	ray.enabled = false
	rig.add_child(ray)
	var own := mera.get_node_or_null("Hurtbox")
	if own is CollisionObject2D:
		ray.add_exception(own)
	_build_sequence()


func _build_sequence() -> void:
	_seq.clear()
	for f in HOLD_FRAME:
		_seq.append([f, 0, 0])
	var phases := [[1, CHARGE], [2, FIRE], [3, SUSTAIN], [4, FADE]]
	for ph in phases:
		for k in ph[1]:
			_seq.append([HOLD_FRAME, ph[0], k])
	for f in range(HOLD_FRAME + 1, 17):
		_seq.append([f, 0, 0])


func _size() -> int:
	return int(mera.get("size_scale")) if mera.get("size_scale") != null else 1


func _facing() -> int:
	return int(mera.get("facing")) if mera.get("facing") != null else 1


## Direction the beam travels in screen space (+1 right, -1 left).
func beam_direction() -> int:
	return _facing() if toward_facing else -_facing()


func cast() -> bool:
	if casting:
		return false
	casting = true
	_i = 0; _acc = 0.0; _last_tick.clear()
	mera.set_physics_process(false)            # hold her in place while casting
	var body := mera.get_node_or_null("Sprite")
	if body:
		body.visible = false
	sprite.visible = true
	ray.enabled = true
	_apply_frame()
	return true


func _process(delta: float) -> void:
	# keep the rig on Mera's current size and direction (works while she grows mid-cast too)
	var s := _size()
	rig.scale = Vector2(s * beam_direction(), s)
	if not casting:
		return
	_acc += delta
	while _acc >= FRAME_SEC and casting:
		_acc -= FRAME_SEC
		_i += 1
		if _i >= _seq.size():
			_end()
			return
		_apply_frame()


func _physics_process(_delta: float) -> void:
	if not casting:
		return
	ray.force_raycast_update()
	_hit_len = MAX_RANGE
	if ray.is_colliding():
		_hit_len = clampf(rig.to_local(ray.get_collision_point()).x - ORIGIN.x + 1.0, 4.0, MAX_RANGE)
	var cur: Array = _seq[_i]
	var active: bool = (cur[1] == 2 and cur[2] >= 1) or cur[1] == 3
	hitbox.monitoring = active
	if active:
		for a in hitbox.get_overlapping_areas():
			var tgt := a.get_parent()
			if tgt == mera or not tgt.has_method("take_beam_hit"):
				continue
			var last: int = _last_tick.get(tgt, -999)
			if _i - last >= TICK_FRAMES:
				_last_tick[tgt] = _i
				tgt.take_beam_hit(DAMAGE)
				hit.emit(tgt, DAMAGE)


func _apply_frame() -> void:
	var cur: Array = _seq[_i]
	sprite.frame = cur[0]
	var ph: int = cur[1]
	var k: int = cur[2]
	var head := 0.0
	if ph == 2:
		head = _hit_len * [0.3, 0.62, 0.88][k]
	elif ph >= 3:
		head = _hit_len
	fx.step(ph, k, _i, head, _hit_len)
	# hitbox = beam rectangle from the wand tip to the head (local 1x px; the Rig scales it)
	var len_px := maxf(head, 1.0)
	(hit_shape.shape as RectangleShape2D).size = Vector2(len_px, HIT_HALF_HEIGHT * 2.0)
	hit_shape.position = ORIGIN + Vector2(len_px / 2.0, 0)


func _end() -> void:
	casting = false
	fx._parts.clear()
	fx.step(0, 0, _i, 0, _hit_len)
	hitbox.monitoring = false
	ray.enabled = false
	sprite.visible = false
	var body := mera.get_node_or_null("Sprite")
	if body:
		body.visible = true
	mera.set_physics_process(true)
	if mera.has_method("_set_state"):
		mera.call("_set_state", "idle")
	finished.emit()


## Debug: current hitbox rectangle in global coordinates (zero size when inactive).
func hitbox_global_rect() -> Rect2:
	if not hitbox.monitoring:
		return Rect2()
	var r := (hit_shape.shape as RectangleShape2D).size
	var a := rig.to_global(hit_shape.position - r / 2.0)
	var b := rig.to_global(hit_shape.position + r / 2.0)
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())
