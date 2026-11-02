class_name PerryHud
extends RefCounted
## Perry's HUD parts (hud.gd calls these in place of Mera's SIZE pips): an HP bar, and the empower bar once she owns
## an unlock that uses it. Energy is the MANA bar and super is the RAGE bar.


static func draw_hp(ui: Control, font: Font, m: Node, hx: float) -> void:
	var w := 330.0
	ui.draw_string(font, Vector2(38 + hx, 54), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(0, 0, 0, 0.7))
	ui.draw_string(font, Vector2(36 + hx, 52), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(0.95, 0.92, 0.88))
	var frac := clampf(float(m.hp) / maxf(float(m.hp_max), 1.0), 0.0, 1.0)
	ui.draw_rect(Rect2(110 + hx, 28, w, 26), Color(0.18, 0.04, 0.06))
	ui.draw_rect(Rect2(110 + hx, 28, w * frac, 26), Color(0.35, 0.85, 0.4) if frac > 0.34 else Color(0.9, 0.25, 0.2))
	ui.draw_rect(Rect2(110 + hx, 28, w, 26), Color(0.05, 0.03, 0.06), false, 3.0)
	var t := "%d/%d" % [m.hp, m.hp_max]
	ui.draw_string(font, Vector2(452 + hx, 52), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.95, 0.92, 0.88))
	if PerryUnlocks.meter_on("empower"):
		ui.draw_rect(Rect2(590 + hx, 16, 300, 44), Color(0.04, 0.03, 0.07, 0.55))
		ui.draw_string(font, Vector2(604 + hx, 46), "EMP", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1.0, 0.75, 0.4))
		var ef := clampf(float(m.empower) / maxf(float(m.empower_max), 1.0), 0.0, 1.0)
		ui.draw_rect(Rect2(670 + hx, 26, 200, 22), Color(0.2, 0.1, 0.02))
		ui.draw_rect(Rect2(670 + hx, 26, 200 * ef, 22), Color(1.0, 0.65, 0.2))
		ui.draw_rect(Rect2(670 + hx, 26, 200, 22), Color(0.05, 0.03, 0.06), false, 3.0)
