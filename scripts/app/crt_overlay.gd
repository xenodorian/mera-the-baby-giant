extends CanvasLayer
## Full-screen CRT post effect. Used in the playable level and on the title screen.
## In the game it lives under the HUD (layer 20) and under story / victory cards (layer 10),
## so bars stay readable. On the title it covers the whole menu so toggling CRT on Options
## is visible immediately. The ColorRect samples the screen texture through shaders/crt.gdshader.

const SHADER := preload("res://shaders/crt.gdshader")
const LAYER := 8

var _rect: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	follow_viewport_enabled = false
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(copy)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("cheap", OS.get_name() == "Android")
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.color = Color.WHITE
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)
	var settings := _settings()
	if settings:
		if not settings.crt_changed.is_connected(_on_crt_changed):
			settings.crt_changed.connect(_on_crt_changed)
	_apply()


func _exit_tree() -> void:
	var settings := _settings()
	if settings and settings.crt_changed.is_connected(_on_crt_changed):
		settings.crt_changed.disconnect(_on_crt_changed)


func _settings() -> Node:
	return get_node_or_null("/root/Settings")


func _on_crt_changed(_on: bool) -> void:
	_apply()


func _apply() -> void:
	if _rect:
		var settings := _settings()
		_rect.visible = settings != null and bool(settings.get("crt"))


func shown() -> bool:
	return _rect != null and _rect.visible


func uses_cheap_glow() -> bool:
	return _mat != null and bool(_mat.get_shader_parameter("cheap"))
