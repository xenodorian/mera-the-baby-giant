extends RefCounted
## Scripted input for the gameplay capture (game.gd --demo): [physics frame (60/s), op, arg]
const STEPS := [
	[1, "calm", 800], [1, "potions", 2], [1, "spawn", 700],
	[20, "press", "right"], [75, "release", "right"],
	# X X X -> 1x 2x 2x-2
	[80, "press", "btn_x"], [83, "release", "btn_x"], [93, "press", "btn_x"], [96, "release", "btn_x"],
	[106, "press", "btn_x"], [109, "release", "btn_x"],
	# Y -> quick fire
	[175, "press", "btn_y"], [178, "release", "btn_y"],
	[230, "spawn", 500],
	# X X X Y -> combo into beam (recoil + shake)
	[262, "press", "btn_x"], [265, "release", "btn_x"], [275, "press", "btn_x"], [278, "release", "btn_x"],
	[288, "press", "btn_x"], [291, "release", "btn_x"], [296, "press", "btn_y"], [299, "release", "btn_y"],
	# X+Y -> rear explosion
	[420, "press", "btn_x"], [420, "press", "btn_y"], [423, "release", "btn_x"], [423, "release", "btn_y"],
	[500, "spawn", 600],
	# jump + X (jump attack), jump + Y (aerial dash)
	[510, "press", "up"], [514, "release", "up"], [526, "press", "btn_x"], [529, "release", "btn_x"],
	[580, "press", "up"], [584, "release", "up"], [596, "press", "btn_y"], [599, "release", "btn_y"],
	# L1 potion (+1 size), R1 lightning
	[650, "press", "l1"], [653, "release", "l1"],
	[730, "press", "r1"], [733, "release", "r1"],
	# L2 barrier while the knight swings
	[800, "spawn", -500], [802, "press", "left"], [806, "release", "left"],
	[840, "press", "l2"], [960, "release", "l2"],
	# Fury: R2 at 100 % rage, fly, red bolt, land, red beam combo, red rear explosion
	[1000, "rage", 100], [1002, "press", "r2"], [1005, "release", "r2"],
	[1020, "press", "up"], [1024, "release", "up"], [1034, "press", "up"], [1038, "release", "up"],
	[1040, "press", "up"], [1040, "press", "right"], [1075, "release", "up"], [1110, "release", "right"],
	[1125, "press", "btn_y"], [1128, "release", "btn_y"],
	[1150, "press", "down"], [1215, "release", "down"],
	[1218, "spawn", 400],
	[1232, "press", "btn_x"], [1235, "release", "btn_x"], [1245, "press", "btn_x"], [1248, "release", "btn_x"],
	[1258, "press", "btn_x"], [1261, "release", "btn_x"], [1266, "press", "btn_y"], [1269, "release", "btn_y"],
	[1390, "press", "btn_x"], [1390, "press", "btn_y"], [1393, "release", "btn_x"], [1393, "release", "btn_y"],
]
