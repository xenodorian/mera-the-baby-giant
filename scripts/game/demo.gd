extends RefCounted
## Scripted input for the gameplay capture (game.gd --demo): [frame (60/s), op, arg]
## v0.6 controls (L2 tap = lightning, L2+R2 = Fury, Y in the bubble = lightning). Originally v0.3: a 6x Fire Knight fight (tell, back dodge through the swing, combo, a hit costs 1 size, potion),
## then the tessellated beam at 1x and at 6x running off-screen, L2-tap lightning (needs and drains a full meter) from
## above the screen top, a red Fury beam, and tilted Fury flight inside the Kaioken flame aura; then the 4x-speed
## ground dash, the 2x-speed back dodge, and the L2 bubble blocking a swing while Y strikes from inside it.
const STEPS := [
	[1, "spawning", false], [1, "potions", 3], [1, "spawn", 760],
	# he walks up, glows (tell), swings: back dodge through it (i-frames)
	[128, "press", "btn_b"], [131, "release", "btn_b"],
	# he walks back in and swings: this one connects, 2x -> 1x (exactly 1 size)
	# punish during his cooldown: run in (A + Right), X X X
	[345, "press", "right"], [345, "press", "btn_a"], [362, "release", "btn_a"], [362, "release", "right"],
	[364, "press", "btn_x"], [367, "release", "btn_x"], [377, "press", "btn_x"], [380, "release", "btn_x"],
	[390, "press", "btn_x"], [393, "release", "btn_x"],
	# drink a potion (L1): 1x -> 2x, then hold the barrier (L2) through his next swing
	[440, "press", "l1"], [443, "release", "l1"],
	[520, "press", "l2"], [640, "release", "l2"],
	# finish him: X X Y (1x 2x 3x)
	[650, "press", "right"], [650, "press", "btn_a"], [660, "release", "btn_a"], [660, "release", "right"],
	[662, "press", "btn_x"], [665, "release", "btn_x"], [675, "press", "btn_x"], [678, "release", "btn_x"],
	[690, "press", "btn_y"], [693, "release", "btn_y"],
	# a second knight: Mera stands still and takes one swing at 3x -> 2x (exactly 1 size), then he is told to wait
	[705, "spawn", 520], [870, "calm", 99999],
	# 1x: beam combo X X X Y, the beam runs off the right edge
	[910, "size", 1], [930, "press", "left"], [934, "release", "left"], [940, "press", "right"], [943, "release", "right"],
	[960, "press", "btn_x"], [963, "release", "btn_x"], [973, "press", "btn_x"], [976, "release", "btn_x"],
	[986, "press", "btn_x"], [989, "release", "btn_x"], [994, "press", "btn_y"], [997, "release", "btn_y"],
	# L2 tap below a full meter: fail cue, nothing; with a full meter: lightning, and the meter drains to 0
	[1105, "press", "l2"], [1108, "release", "l2"],
	[1130, "rage", 100], [1150, "press", "l2"], [1153, "release", "l2"],
	# 6x: beam to the left edge, lightning
	[1230, "size", 6], [1280, "press", "left"], [1284, "release", "left"],
	[1300, "press", "btn_x"], [1303, "release", "btn_x"], [1313, "press", "btn_x"], [1316, "release", "btn_x"],
	[1326, "press", "btn_x"], [1329, "release", "btn_x"], [1334, "press", "btn_y"], [1337, "release", "btn_y"],
	[1460, "rage", 100], [1480, "press", "l2"], [1483, "release", "l2"],
	# Fury (L2+R2) at 6x: deep-red beam
	[1560, "rage", 100], [1562, "press", "l2"], [1562, "press", "r2"], [1565, "release", "r2"], [1565, "release", "l2"],
	[1590, "press", "right"], [1594, "release", "right"],
	[1610, "press", "btn_x"], [1613, "release", "btn_x"], [1623, "press", "btn_x"], [1626, "release", "btn_x"],
	[1636, "press", "btn_x"], [1639, "release", "btn_x"], [1644, "press", "btn_y"], [1647, "release", "btn_y"],
	# Fury flight: she tilts head-first toward where she flies, eases upright in the hover; Kaioken flame aura
	[1770, "press", "up"], [1774, "release", "up"], [1786, "press", "up"], [1790, "release", "up"],
	[1792, "press", "up"], [1815, "release", "up"], [1815, "press", "right"], [1850, "press", "up"], [1872, "release", "up"],
	[1872, "release", "right"], [1872, "press", "left"], [1872, "press", "down"], [1900, "release", "down"], [1925, "release", "left"],
	[1925, "press", "up"], [1935, "release", "up"],
	# L2 tap in Fury: the meter is the Fury timer (already spent by R2) -> fail cue, no strike
	[1975, "press", "l2"], [1978, "release", "l2"],
	# after Fury, at 3x: ground dash (A+Y, 2x the distance in half the time, afterimages), fast back dodge (B)
	[2300, "size", 3], [2330, "press", "btn_a"], [2330, "press", "btn_y"], [2334, "release", "btn_y"], [2334, "release", "btn_a"],
	[2380, "press", "btn_b"], [2383, "release", "btn_b"],
	# the bubble (L2) now encloses her hand and energy ball; a knight swings into it (blocked) and Y calls the
	# lightning from inside the bubble (full meter, spent), she stays shielded
	[2420, "rage", 100], [2425, "spawn", 520], [2440, "press", "l2"],
	[2560, "press", "btn_y"], [2563, "release", "btn_y"], [2650, "release", "l2"],
]
