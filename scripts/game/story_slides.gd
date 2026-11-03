class_name StorySlides
extends RefCounted

# Data for the six story slides shown above the story text.
# Each slide is drawn in a 1920 x 804 design-px band (see slide_view.gd).
# Keys: bg, pan, zoom, dur, tint, dark, vignette, fx, flashes, sprites.
# Sprite keys: who, anim, pos, scale, flip, color, fps, at, until, move.

const SLIDES := {
	"intro_1": {
		"bg": "res://assets/perry/maps/story/4_village_meadow.png",
		"pan": [0.1, 0.9],
		"dur": 16.0,
		"sprites": [
			{"who": "ogre", "anim": "idle", "pos": [520, 560], "scale": 7, "flip": false, "color": [0.16, 0.19, 0.28, 1.0], "fps": 0, "at": 0.0},
			{"who": "minotaur", "anim": "idle", "pos": [1340, 560], "scale": 7, "flip": false, "color": [0.16, 0.19, 0.28, 1.0], "fps": 0, "at": 0.0},
			{"who": "mera", "anim": "idle", "pos": [960, 760], "scale": 3, "flip": false, "fps": 0, "at": 0.0}
		]
	},
	"intro_2": {
		"bg": "res://assets/perry/maps/story/2_sunset_island.png",
		"pan": [0.3, 0.7],
		"tint": [1.0, 0.6, 0.2, 0.2],
		"sprites": [
			{
				"who": "ogre", "anim": "idle", "pos": [960, 600], "scale": 8, "flip": false,
				"color": [0.1, 0.06, 0.12, 1.0], "fps": 0, "at": 0.0,
				"move": [{"t": 0.0, "dur": 10.0, "scale": 15.0}]
			},
			{"who": "mera", "anim": "idle", "pos": [960, 640], "scale": 3, "flip": false, "fps": 0, "at": 0.0}
		]
	},
	"intro_3": {
		"bg": "res://assets/perry/maps/story/3_moonlit_courtyard.png",
		"zoom": [1.0, 1.15],
		"fx": ["flicker"],
		"vignette": 0.5,
		"tint": [0.7, 0.05, 0.05, 0.12],
		"sprites": [
			{"who": "nero", "anim": "idle", "pos": [1250, 540], "scale": 11, "flip": true, "fps": 0, "at": 0.0}
		]
	},
	"intro_4": {
		"bg": "res://assets/perry/maps/story/7_snow_temple.png",
		"pan": [0.2, 0.8],
		"flashes": [6.5],
		"sprites": [
			{
				"who": "perry", "anim": "walk", "pos": [-100, 700], "scale": 4, "flip": false,
				"fps": 0, "at": 0.0, "until": 6.0,
				"move": [{"t": 0.0, "dur": 6.0, "to": [700, 700]}]
			},
			{"who": "perry", "anim": "idle", "pos": [700, 700], "scale": 4, "flip": false, "fps": 0, "at": 6.0}
		]
	},
	"intro_5": {
		"bg": "res://assets/perry/maps/story/1_burning_house.png",
		"fx": ["fire", "shake"],
		"dark": 0.1,
		"flashes": [1.0, 2.0],
		"sprites": [
			{
				"who": "ogre", "anim": "idle", "pos": [380, 700], "scale": 8, "flip": false,
				"color": [0.08, 0.06, 0.1, 1.0], "fps": 0, "at": 0.0,
				"move": [{"t": 1.0, "dur": 5.0, "rot": 80.0, "alpha": 0.0}]
			},
			{
				"who": "minotaur", "anim": "idle", "pos": [640, 700], "scale": 8, "flip": false,
				"color": [0.08, 0.06, 0.1, 1.0], "fps": 0, "at": 0.0,
				"move": [{"t": 2.0, "dur": 5.0, "rot": 80.0, "alpha": 0.0}]
			},
			{"who": "perry", "anim": "parry", "pos": [1350, 700], "scale": 4.5, "flip": true, "fps": 0, "at": 0.0}
		]
	},
	"intro_6": {
		"bg": "res://assets/perry/maps/story/8_cave_shrine.png",
		"dark": 0.25,
		"pan": [0.7, 0.3],
		"sprites": [
			{"who": "mera", "anim": "idle", "pos": [420, 760], "scale": 4, "flip": false, "fps": 0, "at": 0.0},
			{
				"who": "ogre", "anim": "idle", "pos": [1120, 690], "scale": 4, "flip": false,
				"color": [0.05, 0.03, 0.06, 0.0], "fps": 0, "at": 0.5,
				"move": [{"t": 0.5, "dur": 0.6, "alpha": 1.0}]
			},
			{
				"who": "minotaur", "anim": "idle", "pos": [1260, 670], "scale": 4, "flip": false,
				"color": [0.05, 0.03, 0.06, 0.0], "fps": 0, "at": 1.2,
				"move": [{"t": 1.2, "dur": 0.6, "alpha": 1.0}]
			},
			{
				"who": "demon", "anim": "idle", "pos": [1390, 650], "scale": 4, "flip": false,
				"color": [0.05, 0.03, 0.06, 0.0], "fps": 0, "at": 1.9,
				"move": [{"t": 1.9, "dur": 0.6, "alpha": 1.0}]
			},
			{
				"who": "wolf", "anim": "run", "pos": [1520, 700], "scale": 3, "flip": true,
				"color": [0.05, 0.03, 0.06, 0.0], "fps": 0, "at": 2.6,
				"move": [{"t": 2.6, "dur": 0.6, "alpha": 1.0}]
			},
			{
				"who": "werewolf", "anim": "idle", "pos": [1700, 680], "scale": 4, "flip": true,
				"color": [0.05, 0.03, 0.06, 0.0], "fps": 0, "at": 3.3,
				"move": [{"t": 3.3, "dur": 0.6, "alpha": 1.0}]
			}
		]
	}
}


static func has_slide(id: String) -> bool:
	return SLIDES.has(id)


static func get_slide(id: String) -> Dictionary:
	if not SLIDES.has(id):
		return {}
	return (SLIDES[id] as Dictionary).duplicate(true)
