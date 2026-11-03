class_name StoryPages
extends RefCounted
## The story cards of docs/KING_ARC.md, played by scripts/game/cutscene.gd. A page is a String (one line) or an Array of one or two
## Strings (a gold first line and a pale second line). game.gd `_story_start` / `_start_finale_victory` pick them.

const INTRO := [
	"Years ago, two giants lived beyond the hills.",
	"They could grow until they blotted out the sun. Their child, Mera, was still small.",
	"King Lucius Nerochilde feared that size. He called it a threat to his crown.",
	"He sent his daughter, Perry Nerochilde. Fighters call her Parry Perry.",
	"No blade could touch her. She parried every blow. The giants fell.",
	"Mera lived. The road ahead is full of the monsters he summoned.",
]

## Perry's Arena: she falls
const PERRY_FALLS := [
	"Perry drops her sword. The red glow leaves her eyes.",
	"\"Father. The spell. I could not stop my hands.\"",
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
