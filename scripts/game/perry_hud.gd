class_name PerryHud
extends RefCounted
## Perry's HUD parts (hud.gd calls these in place of Mera's SIZE pips): an HP bar, and the empower bar once she owns
## an unlock that uses it. Energy is the MANA bar and super is the RAGE bar.

## Perry's controls for the pause menu CONTROLS list and the in-play overlay (hud.gd _controls_table picks this).
## [gamepad (Xbox names), keyboard (Z A S Q W 1 2 E, arrows, numpad), what it does]. Rows with a 4th entry ("perry:<unlock id>") show only once that unlock is owned (hud.gd gate_ok).
const CONTROLS := [
	["D-pad / left stick", "arrows", "walk. Up = jump, Up again in the air = double jump. Down = duck"],
	["A", "Z", "slash"],
	["Forward + A", "arrow + Z", "lunging thrust", "perry:thrust"],
	["Down + A", "Down + Z", "ducking upswing", "perry:upswing"],
	["Y", "S", "spin attack, hits both sides"],
	["X + Y together", "A + S", "taunt", "perry:taunt"],
	["X", "A", "dash, invulnerable for most of it"],
	["X + A together", "A + Z", "dash thrust", "perry:dash_thrust"],
	["Double tap forward, then X + A, release", "Double tap, then A + Z, release", "energy dash thrust", "perry:energy_dash"],
	["B tap", "X tap", "PARRY: a hit that lands just as you tap does no damage and stuns the attacker"],
	["B hold", "X hold", "block"],
	["B hold, then A", "X hold, then Z", "heavy horizontal", "perry:heavy_horizontal"],
	["A x5", "Z x5", "attack chain: slash, 3 strikes, chop", "perry:chain"],
	["A x4 then B", "Z x4 then X", "energy burst finisher", "perry:chain_burst"],
	["A hold, release", "Z hold, release", "heavy chop (a full charge shakes the screen)", "perry:heavy_chop"],
	["A in the air", "Z in the air", "jumping crash (30 energy)", "perry:crash"],
	["Down, then Up", "Down, Up", "sky dash", "perry:sky_dash"],
	["L1", "Q", "push kick", "perry:push_kick"],
	["A + L1", "Z + Q", "laser beam", "perry:laser_beam"],
	["B hold + L1, release", "X hold + Q, release", "energy kick", "perry:energy_kick"],
	["L2 hold, release", "1 hold, release", "energy burst", "perry:energy_burst"],
	["A + L2", "Z + 1", "cloud beam", "perry:cloud_beam"],
	["R2 hold, release", "2 hold, release", "energy wave", "perry:energy_wave"],
	["A + R2", "Z + 2", "fire beam", "perry:fire_beam"],
	["R1 hold", "W hold", "kneel and heal (uses empower)", "perry:recover"],
	["A + R1", "Z + W", "empowerment beam", "perry:empower_beam"],
	["L1 + R1 hold", "Q + W hold", "meter charge", "perry:meter_charge"],
	["Down x4, then A", "Down x4, then Z", "EARTHQUAKE: full super", "perry:earthquake"],
	["B x5", "X x5", "METEOR SHOWER: full super", "perry:meteor"],
	["A B A B A B", "Z X Z X Z X", "rainbow guard", "perry:rainbow"],
	["A B A B, then Up", "Z X Z X, then Up", "flight", "perry:fly"],
	["A x4, then all four shoulders", "Z x4, then Q + W + 1 + 2", "ultimate chain", "perry:ultimate"],
	["Right stick flick / click", "numpad 8 2 4 6 / 5", "up = health potion, down = mana potion, left or right / click = summon ally"],
	["L3", "E", "drink a mana potion"],
	["Start", "Enter / F1", "pause. On Android the on-screen PAUSE button also pauses"],
	["Menus", "arrows, Z ok, X back", "level select, pickers, level clear. Moves not bought in the shop do nothing"],
]


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
