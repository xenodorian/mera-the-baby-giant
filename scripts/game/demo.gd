extends RefCounted
## Scripted input for the gameplay capture (game.gd --demo). [physics frame, op, arg]
const STEPS := [
	[1, "spawn", 1],
	[20, "press", "right"], [70, "release", "right"],
	[80, "press", "btn_x"], [84, "release", "btn_x"], [96, "press", "btn_x"], [100, "release", "btn_x"],
	[112, "press", "btn_x"], [116, "release", "btn_x"],
	[150, "press", "btn_y"], [154, "release", "btn_y"],
	[205, "press", "btn_x"], [208, "release", "btn_x"], [220, "press", "btn_x"], [223, "release", "btn_x"],
	[234, "press", "btn_x"], [237, "release", "btn_x"], [240, "press", "btn_y"], [243, "release", "btn_y"],
	[380, "press", "btn_x"], [380, "press", "btn_y"], [384, "release", "btn_x"], [384, "release", "btn_y"],
	[470, "press", "up"], [476, "release", "up"], [490, "press", "btn_x"], [494, "release", "btn_x"],
	[540, "press", "r1"], [544, "release", "r1"],
	[620, "rage", 100], [622, "press", "r2"], [626, "release", "r2"],
	[640, "press", "up"], [646, "release", "up"], [652, "press", "up"], [656, "release", "up"],
	[660, "press", "right"], [660, "press", "up"], [700, "release", "up"], [740, "release", "right"],
	[760, "press", "btn_y"], [764, "release", "btn_y"],
	[820, "press", "down"], [900, "release", "down"],
	[910, "press", "btn_x"], [913, "release", "btn_x"], [925, "press", "btn_x"], [928, "release", "btn_x"],
	[939, "press", "btn_x"], [942, "release", "btn_x"], [946, "press", "btn_y"], [949, "release", "btn_y"],
	[1080, "press", "l2"], [1160, "release", "l2"],
	[1200, "press", "l1"], [1204, "release", "l1"],
]
