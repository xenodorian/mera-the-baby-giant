extends Node
## Autoload "AnimLib": Mera's baked animations (tools/export_game_anims.py -> anims.json + one atlas per animation),
## the spell sprites, and the shared effect materials (Fury recolour is one switch for every effect).

const DIR := "res://assets/characters/merakintsugi/game/"
var anims: Dictionary = {}
var spells: Dictionary = {}
var palette: Dictionary = {}
var fx_mat: ShaderMaterial
var light_mat: ShaderMaterial
var remap_mat: ShaderMaterial
var fury := false
var _tex := {}


func _ready() -> void:
	var f := FileAccess.open(DIR + "anims.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	anims = data["anims"]
	spells = data["spells"]
	palette = data["palette"]
	fx_mat = ShaderMaterial.new()
	fx_mat.shader = load("res://shaders/spell_fx.gdshader")
	remap_mat = ShaderMaterial.new()
	remap_mat.shader = fx_mat.shader
	remap_mat.set_shader_parameter("remap", 1)
	light_mat = ShaderMaterial.new()
	light_mat.shader = load("res://shaders/spell_light.gdshader")


func sheet(key: String) -> Texture2D:
	if not _tex.has(key):
		_tex[key] = load(DIR + String(anims[key]["sheet"]))
	return _tex[key]


func spell_tex(name: String) -> Texture2D:
	var k := "spell:" + name
	if not _tex.has(k):
		_tex[k] = load(DIR + String(spells[name]["sheet"]))
	return _tex[k]


## a second sheet of a spell (e.g. the beam's additive light segments)
func spell_tex_field(name: String, field: String) -> Texture2D:
	var k := "spell:" + name + ":" + field
	if not _tex.has(k):
		_tex[k] = load(DIR + String(spells[name][field]))
	return _tex[k]


## [w, h, frames] of a spell strip
func spell_cell(name: String) -> Array:
	return spells[name]["cell"]


func frames(key: String) -> Array:
	return anims[key]["frames"]


func set_fury(on: bool) -> void:
	fury = on
	var v := 1.0 if on else 0.0
	for m in [fx_mat, light_mat, remap_mat]:
		m.set_shader_parameter("fury", v)


func keys() -> Array:
	var k := anims.keys()
	return k
