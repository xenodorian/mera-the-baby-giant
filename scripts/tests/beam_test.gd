extends Node2D
## Wand Beam test (1920x1080 native). Cemetery at 5x, Mera and the Fire Knight dummy at 5x.
## Keys: J or X = cast the beam out of her wand (behind her, true to the art)
##       K       = cast toward where she faces (she turns her back to cast)
##       Left/Right run, Up/Down change Mera's size 1x..19x (beam, hitbox and range scale with her)
##       H       = show the beam hitbox / hurtboxes
## Command line (after "--"): --cast[=K] cast at frame 20, --scale=N, --shot=PATH, --wait=N, --autotest

const CEM := "res://assets/environments/ansimuz/gothicvania-cemetery/"
const ART_SCALE := 5
const SRC_FEET := 188
const SRC_GROUND_TOP := 172
const GROUND_Y := 1000
const SHIFT := GROUND_Y - SRC_FEET * ART_SCALE

@onready var mera: Node2D = $Mera
@onready var beam: Node2D = $Mera/BeamAttack
@onready var knight: Node2D = $Target
@onready var hud: Label = $HUD/Info

var show_boxes := false
var shot_path := ""
var wait_frames := 40
var cast_at := -1
var cast_forward := false
var autotest := false
var frame_count := 0
var hit_log: Array = []


func _ready() -> void:
	_build_background()
	mera.position = Vector2(1380, GROUND_Y)
	mera.set_size_scale(5)
	knight.position = Vector2(560, GROUND_Y)
	beam.hit.connect(func(t, d): hit_log.append([Time.get_ticks_msec(), t.name, d]))
	beam.finished.connect(_on_beam_finished)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scale="):
			mera.set_size_scale(int(a.get_slice("=", 1)))
		elif a.begins_with("--shot="):
			shot_path = a.get_slice("=", 1)
		elif a.begins_with("--wait="):
			wait_frames = int(a.get_slice("=", 1))
		elif a.begins_with("--cast"):
			cast_at = 20
			cast_forward = a == "--cast=K"
		elif a == "--autotest":
			autotest = true; cast_at = 10
		elif a == "--boxes":
			show_boxes = true


func _build_background() -> void:
	var bg := $Background
	var sky := ColorRect.new(); sky.color = Color8(0, 0, 34); sky.size = Vector2(1920, maxf(SHIFT, 0) + 4)
	bg.add_child(sky)
	_tiled(bg, load(CEM + "background.png"), 0)
	var mt: Texture2D = load(CEM + "mountains.png"); _tiled(bg, mt, 224 - mt.get_height() - 30)
	var gy: Texture2D = load(CEM + "graveyard.png"); _tiled(bg, gy, 224 - gy.get_height() - 20)
	var dirt := ColorRect.new(); dirt.color = Color8(23, 14, 28)
	dirt.position = Vector2(0, (SRC_GROUND_TOP + 30) * ART_SCALE + SHIFT); dirt.size = Vector2(1920, 400)
	bg.add_child(dirt)
	var tile := AtlasTexture.new(); tile.atlas = load(CEM + "tileset.png"); tile.region = Rect2(64, 48, 64, 48)
	_tiled(bg, tile, SRC_GROUND_TOP)


func _tiled(parent: Node, tex: Texture2D, src_y: int) -> void:
	var x := 0
	while x < 384:
		var s := Sprite2D.new(); s.texture = tex; s.centered = false
		s.scale = Vector2(ART_SCALE, ART_SCALE); s.position = Vector2(x * ART_SCALE, src_y * ART_SCALE + SHIFT)
		parent.add_child(s); x += tex.get_width()


func _cast(forward: bool) -> void:
	beam.toward_facing = forward
	beam.cast()


func _on_beam_finished() -> void:
	if autotest:
		print("AUTOTEST hits=", knight.hits, " hit times ms=", hit_log.map(func(h): return h[0]), " casting=", beam.casting)
		get_tree().quit(0 if knight.hits > 0 else 1)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_J, KEY_X: _cast(false)
			KEY_K: _cast(true)
			KEY_H: show_boxes = not show_boxes
			KEY_ESCAPE:
				if not OS.has_feature("web"): get_tree().quit()


func _process(_delta: float) -> void:
	frame_count += 1
	if frame_count == cast_at:
		_cast(cast_forward)
	queue_redraw()
	hud.text = "Mera: The Baby Giant - Wand Beam test   size %dx   beam %s   hits on Fire Knight: %d\nJ / X: beam out of the wand (behind her)    K: beam toward facing    Left/Right: run    Up/Down: size 1x-19x    H: hitboxes" % [
		mera.size_scale, ("toward facing" if beam.toward_facing else "out of the wand"), knight.hits]
	if shot_path != "" and frame_count == wait_frames:
		get_viewport().get_texture().get_image().save_png(shot_path)
		print("saved ", shot_path, " hits=", knight.hits)
		get_tree().quit()


func _draw() -> void:
	if not show_boxes:
		return
	var r: Rect2 = beam.hitbox_global_rect()
	if r.size != Vector2.ZERO:
		draw_rect(r, Color(1, 0.2, 0.2, 0.9), false, 3.0)
	for n in [mera, knight]:
		var cs: CollisionShape2D = n.get_node("Hurtbox/Shape")
		var sz: Vector2 = (cs.shape as RectangleShape2D).size
		draw_rect(Rect2(cs.global_position - sz / 2.0, sz), Color(0.3, 1, 0.4, 0.9), false, 3.0)
