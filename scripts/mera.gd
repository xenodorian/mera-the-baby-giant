extends Node2D
## Mera (merakintsugi Platformer Character Pack hero) - scale test controller.
## Frames come from tools/export_mera_frames.py: every animation shares one
## 74x57 cell with the feet pivot at (37, 55). The art faces LEFT natively.

signal scale_changed(new_scale: int)

const DIR := "res://assets/characters/merakintsugi/mera_export/"
const CELL := Vector2i(74, 57)
const PIVOT := Vector2(37, 55)
const BODY_HEIGHT := 55            # visible body height in source px
const BODY_HALF_WIDTH := 23        # idle bbox half width (for screen clamping)
const HURTBOX_SIZE := Vector2(28, 52)  # source px, centred on the feet
const MIN_SCALE := 1
const MAX_SCALE := 19
const RUN_SPEED := 150.0           # px/s at 1x; multiplied by the scale

# name: [file, frames, ms per frame, loop]
const ANIMS := {
	"idle": ["mera_idle_strip10.png", 10, 60, true],
	"run_start": ["mera_run_start_strip2.png", 2, 100, false],
	"run": ["mera_run_strip20.png", 20, 35, true],
	"run_stop": ["mera_run_stop_strip15.png", 15, 40, false],
	"run_turn": ["mera_run_turn_strip8.png", 8, 40, false],
}

var size_scale: int = 1
var facing: int = 1               # 1 = right, -1 = left
var state: String = "idle"
var velocity_x: float = 0.0
var min_x: float = 0.0
var max_x: float = 1920.0
var forced_dir: int = 0           # used by the screenshot / autotest mode

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hurtbox: Area2D = $Hurtbox
@onready var hurt_shape: CollisionShape2D = $Hurtbox/Shape


func _ready() -> void:
	sprite.sprite_frames = _build_frames()
	sprite.centered = false
	sprite.offset = -PIVOT
	sprite.animation_finished.connect(_on_anim_finished)
	hurt_shape.shape = RectangleShape2D.new()
	_set_state("idle")
	set_size_scale(size_scale)


func _build_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for anim_name in ANIMS:
		var a: Array = ANIMS[anim_name]
		var tex: Texture2D = load(DIR + a[0])
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, 1000.0 / a[2])
		sf.set_animation_loop(anim_name, a[3])
		for i in a[1]:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * CELL.x, 0, CELL.x, CELL.y)
			sf.add_frame(anim_name, at)
	return sf


func set_size_scale(s: int) -> void:
	size_scale = clampi(s, MIN_SCALE, MAX_SCALE)
	_apply_visual_scale()
	var shape := hurt_shape.shape as RectangleShape2D
	shape.size = HURTBOX_SIZE * size_scale
	hurt_shape.position = Vector2(0, -HURTBOX_SIZE.y * size_scale / 2.0)
	position.x = _clamped_x(position.x)
	scale_changed.emit(size_scale)


func _apply_visual_scale() -> void:
	# Art faces left, so facing right means a negative x scale.
	# Scaling the sprite node pivots at its origin, which is the feet.
	sprite.scale = Vector2(size_scale * -facing, size_scale)


func on_screen_height() -> int:
	return BODY_HEIGHT * size_scale


func _clamped_x(x: float) -> float:
	var half := BODY_HALF_WIDTH * size_scale
	return clampf(x, min_x + half, max_x - half)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.physical_keycode:
			KEY_UP, KEY_W:
				set_size_scale(size_scale + 1)
			KEY_DOWN, KEY_S:
				set_size_scale(size_scale - 1)


func _input_dir() -> int:
	if forced_dir != 0:
		return forced_dir
	var d := 0
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		d -= 1
	if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		d += 1
	return d


func _set_state(s: String) -> void:
	state = s
	sprite.play(s)


func _physics_process(delta: float) -> void:
	var d := _input_dir()
	var top := RUN_SPEED * size_scale
	match state:
		"idle":
			velocity_x = 0.0
			if d != 0:
				if d != facing:
					facing = d
					_apply_visual_scale()
				_set_state("run_start")
		"run_start":
			velocity_x = facing * top * 0.5
			if d == 0:
				_set_state("run_stop")
			elif d != facing:
				_set_state("run_turn")
		"run":
			velocity_x = facing * top
			if d == 0:
				_set_state("run_stop")
			elif d != facing:
				_set_state("run_turn")
		"run_stop":
			velocity_x = move_toward(velocity_x, 0.0, top * 3.0 * delta)
			if d == facing:
				_set_state("run")
			elif d == -facing:
				_set_state("run_turn")
		"run_turn":
			velocity_x = move_toward(velocity_x, 0.0, top * 4.0 * delta)
	position.x = _clamped_x(position.x + velocity_x * delta)


func _on_anim_finished() -> void:
	match state:
		"run_start":
			_set_state("run")
		"run_stop":
			_set_state("idle")
		"run_turn":
			facing = -facing
			_apply_visual_scale()
			_set_state("run" if _input_dir() == facing else "run_stop")
