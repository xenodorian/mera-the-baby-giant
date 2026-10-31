extends Node2D
## Mera scale test stage: native 1920x1080, fixed 1:1 camera.
## Cemetery art (ansimuz) at integer 5x: 384 * 5 = 1920 wide.
##
## Command-line options (after "--"):
##   --scale=N        start Mera at N x
##   --run=left|right hold a direction (for screenshots)
##   --debug          start with hurtbox outlines on
##   --shot=PATH      save a PNG after --wait frames, then quit
##   --wait=N         frames to wait before the screenshot (default 45)
##   --autotest       step 1..19..1 while running both ways, then quit

const CEM := "res://assets/environments/ansimuz/gothicvania-cemetery/"
const ART_SCALE := 5
const SRC_FEET := 188          # feet line in the 224 px tall source scene
const SRC_GROUND_TOP := 172
const GROUND_Y := 1060         # feet line on screen (19x Mera = 1045 px fits)
const SHIFT := GROUND_Y - SRC_FEET * ART_SCALE   # 120

@onready var mera: Node2D = $Mera
@onready var knight: Node2D = $FireKnight
@onready var overlay: Node2D = $DebugOverlay
@onready var hud: Label = $HUD/Info

var shot_path := ""
var wait_frames := 45
var frame_count := 0
var autotest := false


func _ready() -> void:
	_build_background()
	mera.position = Vector2(560, GROUND_Y)
	knight.position = Vector2(1500, GROUND_Y)
	overlay.targets = [mera, knight]
	overlay.ground_y = GROUND_Y
	overlay.visible = false
	mera.scale_changed.connect(func(_s): _update_hud())
	_parse_args()
	_update_hud()


func _build_background() -> void:
	var bg_layer := $Background
	var sky := ColorRect.new()
	sky.color = Color8(0, 0, 34)
	sky.size = Vector2(1920, SHIFT + 4)
	bg_layer.add_child(sky)
	_add_tiled(bg_layer, load(CEM + "background.png"), 0)
	var mt: Texture2D = load(CEM + "mountains.png")
	_add_tiled(bg_layer, mt, 224 - mt.get_height() - 30)
	var gy: Texture2D = load(CEM + "graveyard.png")
	_add_tiled(bg_layer, gy, 224 - gy.get_height() - 20)
	var dirt := ColorRect.new()
	dirt.color = Color8(23, 14, 28)
	dirt.position = Vector2(0, (SRC_GROUND_TOP + 30) * ART_SCALE + SHIFT)
	dirt.size = Vector2(1920, 400)
	bg_layer.add_child(dirt)
	var tile := AtlasTexture.new()
	tile.atlas = load(CEM + "tileset.png")
	tile.region = Rect2(64, 48, 64, 48)
	_add_tiled(bg_layer, tile, SRC_GROUND_TOP)


func _add_tiled(parent: Node, tex: Texture2D, src_y: int) -> void:
	var w := tex.get_width()
	var x := 0
	while x < 384:
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.scale = Vector2(ART_SCALE, ART_SCALE)
		s.position = Vector2(x * ART_SCALE, src_y * ART_SCALE + SHIFT)
		parent.add_child(s)
		x += w


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scale="):
			mera.set_size_scale(int(a.get_slice("=", 1)))
		elif a == "--run=left":
			mera.forced_dir = -1
		elif a == "--run=right":
			mera.forced_dir = 1
		elif a == "--debug":
			overlay.visible = true
		elif a.begins_with("--shot="):
			shot_path = a.get_slice("=", 1)
		elif a.begins_with("--wait="):
			wait_frames = int(a.get_slice("=", 1))
		elif a == "--autotest":
			autotest = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_H:
				overlay.visible = not overlay.visible
				_update_hud()
			KEY_F11:
				var w := get_window()
				w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
			KEY_ESCAPE:
				if OS.has_feature("web"):
					return
				if get_window().mode == Window.MODE_FULLSCREEN:
					get_window().mode = Window.MODE_WINDOWED
				else:
					get_tree().quit()


func _process(_delta: float) -> void:
	frame_count += 1
	if frame_count % 15 == 0:
		_update_hud()
	if autotest:
		_autotest_step()
	elif shot_path != "" and frame_count == wait_frames:
		_save_shot(shot_path)
		get_tree().quit()


func _autotest_step() -> void:
	# 19 steps up, 18 down, one step every 6 frames, reversing run direction.
	var step := frame_count / 6
	if step <= 18:
		mera.set_size_scale(1 + step)
	elif step <= 36:
		mera.set_size_scale(19 - (step - 18))
	else:
		var ok: bool = mera.size_scale == 1 and mera.position.x >= 0 and mera.position.x <= 1920
		print("AUTOTEST ", "PASS" if ok else "FAIL", " scale=", mera.size_scale, " x=", mera.position.x, " state=", mera.state)
		get_tree().quit(0 if ok else 1)
		return
	mera.forced_dir = 1 if (step / 4) % 2 == 0 else -1
	var h: int = mera.on_screen_height()
	var top: float = mera.position.y - h
	if top < 0:
		push_error("Mera top off screen at %dx: %f" % [mera.size_scale, top])


func _save_shot(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	print("SHOT ", path, " ", img.get_size(), " err=", err, " scale=", mera.size_scale, " height=", mera.on_screen_height())


func _update_hud() -> void:
	var win := get_window()
	var vp := get_viewport().get_visible_rect().size
	var px_ratio := float(win.size.y) / vp.y
	var lines := PackedStringArray()
	lines.append("Mera %dx   on-screen height %d px   (Fire Knight 6x = %d px)" % [mera.size_scale, mera.on_screen_height(), knight.on_screen_height()])
	lines.append("state %s   speed %d px/s   x %d" % [mera.state, int(mera.RUN_SPEED * mera.size_scale), int(mera.position.x)])
	lines.append("window %dx%d  (%.2f screen px per game px)%s" % [win.size.x, win.size.y, px_ratio, "   [hurtboxes ON]" if overlay.visible else ""])
	lines.append("Left/Right or A/D: run    Up/Down or W/S: size 1x-19x    H: hurtboxes    F11: fullscreen    Esc: exit")
	hud.text = "\n".join(lines)
