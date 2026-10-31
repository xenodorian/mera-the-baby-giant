extends Node
## Runs the game's camera update after every other node's physics step (high process_physics_priority), so the camera
## locks onto where Mera is *this* frame. Without it the camera would lag her by one frame of movement.
var game: Node


func _ready() -> void:
	process_physics_priority = 1000


func _physics_process(delta: float) -> void:
	if game:
		game._follow_camera(delta)
