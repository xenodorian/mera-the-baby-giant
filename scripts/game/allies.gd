class_name Allies
extends RefCounted
## v0.7 allies (docs/GAME_RULES.md "Allies"). Colour-coded cards lie on levels 2-4; R1 summons one (a picker opens when
## cards of several types are held). Art: assets/enemies/roster.json (tools/build_roster.py). Behaviour: ally.gd.

const IDS := ["priestess", "ranger", "brawler", "dancer"]
const NAMES := {"priestess": "WATER PRIESTESS", "ranger": "LEAF RANGER", "brawler": "BRAWLER GIRL", "dancer": "DANCING GIRL"}
const COLORS := {
	"priestess": Color(0.3, 0.62, 1.0),
	"ranger": Color(0.4, 0.88, 0.3),
	"brawler": Color(1.0, 0.45, 0.25),
	"dancer": Color(1.0, 0.4, 0.85),
}
const BLURB := {
	"priestess": "heals Mera to 6x (30 s cooldown), water magic",
	"ranger": "arrows, kicks and a leaf beam",
	"brawler": "jabs, punches, kicks, jump and dive kicks",
	"dancer": "dances: every non-boss enemy on screen rushes over to watch",
}
const STAY_S := {"priestess": 20.0, "ranger": 20.0, "brawler": 20.0, "dancer": 20.0}
const DANCE_S := 5.0          # she walks ahead, then dances this long (the lure), then waits out the rest of the 20 s
const K := {"priestess": 4.0, "ranger": 4.0, "brawler": 4.0, "dancer": 4.0}
const HP := {"priestess": 10, "ranger": 10, "brawler": 12, "dancer": 1}
const SPEED := {"priestess": 240.0, "ranger": 330.0, "brawler": 300.0, "dancer": 260.0}
const HEAL_CD := 30.0          # the priestess heals Mera up to 6x at most once per this many seconds
const HEAL_TO := 6
const DANCE_RANGE := 1100.0    # enemies within this distance of the dancer (on screen) come to watch
const MAX_ACTIVE := 2          # allies on the field at once (one of each type)

## where the cards lie: level index -> [[x, ally id], ...] (S4 hides some of them behind breakable walls)
const CARDS := {
	1: [[3400.0, "priestess"], [7600.0, "brawler"], [11800.0, "ranger"], [15600.0, "dancer"]],
	2: [[3000.0, "dancer"], [7000.0, "ranger"], [10800.0, "priestess"], [14800.0, "brawler"]],
	3: [[3200.0, "ranger"], [6800.0, "priestess"], [10400.0, "dancer"], [13600.0, "brawler"]],
}
