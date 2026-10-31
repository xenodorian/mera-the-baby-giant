extends Node2D
## Beam test dummy: chierit Fire Knight (idle + take_hit), white flash on every beam tick.
## Frames are 288x128 with the feet at (146, 127); he faces right natively.

const FK := "res://assets/characters/chierit/fire-knight/png/fire_knight/"
const PIVOT := Vector2(146, 127)
const HURTBOX_SIZE := Vector2(26, 44)
@export var size_scale := 5
@export var face_left := false

var hits := 0
var _flash := 0.0
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hurt_shape: CollisionShape2D = $Hurtbox/Shape


func _ready() -> void:
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", 10.0)
	for i in range(1, 9):
		sf.add_frame("default", load(FK + "01_idle/idle_%d.png" % i))
	sf.add_animation("hit")
	sf.set_animation_speed("hit", 15.0)
	sf.set_animation_loop("hit", false)
	for i in range(1, 7):
		sf.add_frame("hit", load(FK + "10_take_hit/take_hit_%d.png" % i))
	sprite.sprite_frames = sf
	sprite.centered = false
	sprite.offset = -PIVOT
	sprite.scale = Vector2(size_scale * (-1 if face_left else 1), size_scale)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/hit_flash.gdshader")
	sprite.material = mat
	sprite.play("default")
	sprite.animation_finished.connect(func(): sprite.play("default"))
	var shape := RectangleShape2D.new()
	shape.size = HURTBOX_SIZE * size_scale
	hurt_shape.shape = shape
	hurt_shape.position = Vector2(0, -shape.size.y / 2.0)


func take_beam_hit(_damage: int) -> void:
	hits += 1
	_flash = 1.0
	if sprite.animation != "hit" or sprite.frame >= 3:
		sprite.play("hit")
		sprite.frame = 0


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta / 0.08)
		(sprite.material as ShaderMaterial).set_shader_parameter("flash", 1.0 if _flash > 0.0 else 0.0)
