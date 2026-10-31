extends Node2D
## chierit Fire Knight idle, used as a fixed 6x size reference.
## Frames are 288x128 with the feet centred at (146, 127). He faces right natively.

const DIR := "res://assets/characters/chierit/fire-knight/png/fire_knight/01_idle/"
const PIVOT := Vector2(146, 127)
const BODY_HEIGHT := 44
const HURTBOX_SIZE := Vector2(26, 44)
const SIZE_SCALE := 6
@export var face_left := true

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hurt_shape: CollisionShape2D = $Hurtbox/Shape


func _ready() -> void:
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", 10.0)
	sf.set_animation_loop("default", true)
	for i in range(1, 9):
		sf.add_frame("default", load(DIR + "idle_%d.png" % i))
	sprite.sprite_frames = sf
	sprite.centered = false
	sprite.offset = -PIVOT
	sprite.scale = Vector2(SIZE_SCALE * (-1 if face_left else 1), SIZE_SCALE)
	sprite.play("default")
	var shape := RectangleShape2D.new()
	shape.size = HURTBOX_SIZE * SIZE_SCALE
	hurt_shape.shape = shape
	hurt_shape.position = Vector2(0, -shape.size.y / 2.0)


func on_screen_height() -> int:
	return BODY_HEIGHT * SIZE_SCALE
