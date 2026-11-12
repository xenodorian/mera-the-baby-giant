extends Node
## Autoload "Settings": persisted options. Reset / Carry.reset do not clear these.
## CRT filter is off by default. Saved at user://mera_settings.json.

const PATH := "user://mera_settings.json"

signal crt_changed(on: bool)

var crt := false


func _ready() -> void:
	_load()


func _load() -> void:
	crt = false
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		crt = bool(data.get("crt", false))


func _save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"crt": crt}))


func set_crt(on: bool) -> void:
	var changed := on != crt
	crt = on
	_save()
	if changed:
		crt_changed.emit(crt)


func toggle_crt() -> void:
	set_crt(not crt)
