class_name StoryPages
extends RefCounted
## The story cards of docs/KING_ARC.md, played by scripts/game/cutscene.gd. A page is a String (one line), an Array of one or two
## Strings (a gold first line and a pale second line), or a Dictionary {"text": String or Array, "slide": id, "music": path} (a slideshow page). game.gd `_story_start` / `_start_finale_victory` pick them.

## the opening is a slideshow: each page names its slide (scripts/game/story_slides.gd) and the first starts the prologue music
const INTRO := [
	{"text": "Years ago, two giants lived beyond the hills.", "slide": "intro_1", "music": "res://assets/perry/music/prologue.ogg"},
	{"text": "They could grow until they blotted out the sun. Their child, Mera, was still small.", "slide": "intro_2"},
	{"text": "King Lucius Nerochilde feared that size. He called it a threat to his crown.", "slide": "intro_3"},
	{"text": "He sent his daughter, Perry Nerochilde. Fighters call her Parry Perry.", "slide": "intro_4"},
	{"text": "No blade could touch her. She parried every blow. The giants fell.", "slide": "intro_5"},
	{"text": "Mera lived. The road ahead is full of the monsters he summoned.", "slide": "intro_6"},
]

## Perry's Arena: she falls
const PERRY_FALLS := [
	"Perry drops her sword. The red glow leaves her eyes.",
	{"text": "\"Father. The spell. I could not stop my hands.\"", "speaker": "perry", "name": "Perry"},
	"Breaking his mind control broke the magic that made her strong.",
	"She starts again from nothing. Her shop is empty. She will walk with you.",
	"Stage 3 is open. The mad king is still ahead.",
]

## first step into Stage 3 (level 12)
const STAGE3_STEP := [
	"Perry is with you. Only one of you can stand in the fight.",
	"Switch on the title screen. Her strength must be bought again, in her own shop.",
]

## the king's court (level 20)
const KING_INTRO := [
	["King Lucius Nerochilde. He ordered your parents' death.", "No army. No daughter. Only the dark lord he became."],
]

const KING_END := [
	"The mad king falls. The spell on the land breaks with him.",
	"Mera stands. Perry stands free. The giants' daughter finished what they could not.",
]
