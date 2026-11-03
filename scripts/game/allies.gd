class_name Allies
extends RefCounted
## v0.7 allies (docs/GAME_RULES.md "Allies"). Colour-coded cards lie on levels 2-4; R1 summons one (a picker opens when
## cards of several types are held). Art: assets/enemies/roster.json (tools/build_roster.py). Behaviour: ally.gd.

const IDS := ["priestess", "ranger", "brawler", "dancer", "cl_knight", "cl_ranger", "cl_weaver", "cl_mage", "perry"]
const NAMES := {"priestess": "WATER PRIESTESS", "ranger": "LEAF RANGER", "brawler": "BRAWLER GIRL", "dancer": "DANCING GIRL",
	"cl_knight": "KNIGHT", "cl_ranger": "CHANGELING RANGER", "cl_weaver": "WEAVER", "cl_mage": "MAGE", "perry": "PERRY"}
const COLORS := {
	"priestess": Color(0.3, 0.62, 1.0),
	"ranger": Color(0.4, 0.88, 0.3),
	"brawler": Color(1.0, 0.45, 0.25),
	"dancer": Color(1.0, 0.4, 0.85),
	"cl_knight": Color(0.72, 0.76, 0.86),
	"cl_ranger": Color(0.3, 0.8, 0.55),
	"cl_weaver": Color(0.85, 0.82, 0.55),
	"cl_mage": Color(0.62, 0.45, 1.0),
	"perry": Color(1.0, 0.78, 0.2),
}
const BLURB := {
	"priestess": "heals Mera up to her size cap, water magic",
	"ranger": "arrows, kicks and a leaf beam",
	"brawler": "chases the nearest enemy and fights them",
	"dancer": "dances: every enemy on screen rushes over and jumps",
	"cl_knight": "tough melee tank: enemies go for him",
	"cl_ranger": "builds stairs and ladders to shoot flyers first",
	"cl_weaver": "spinning bone shots from range",
	"cl_mage": "casts bolts from range",
	"perry": "fast sword combos and an energy wave",
}
const STAY_S := {"priestess": 30.0, "ranger": 30.0, "brawler": 30.0, "dancer": 30.0, "cl_knight": 30.0, "cl_ranger": 30.0, "cl_weaver": 30.0, "cl_mage": 30.0, "perry": 30.0}      # v0.12.2 base; see Carry.summon_s()
const DANCE_S := 5.0          # she walks ahead, then dances this long (the lure), then waits out the rest of the 60 s
const K := {"priestess": 4.0, "ranger": 4.0, "brawler": 4.0, "dancer": 4.0, "cl_knight": 4.0, "cl_ranger": 4.0, "cl_weaver": 4.0, "cl_mage": 4.0, "perry": 2.0}
const HP := {"priestess": 10, "ranger": 10, "brawler": 12, "dancer": 1, "cl_knight": 22, "cl_ranger": 10, "cl_weaver": 10, "cl_mage": 8, "perry": 16}
const SPEED := {"priestess": 240.0, "ranger": 330.0, "brawler": 300.0, "dancer": 260.0, "cl_knight": 250.0, "cl_ranger": 300.0, "cl_weaver": 240.0, "cl_mage": 240.0, "perry": 380.0}
const HEAL_CD := 30.0          # the priestess heals Mera up to 6x at most once per this many seconds
const HEAL_TO := 6
const DANCE_RANGE := 1100.0    # enemies within this distance of the dancer (on screen) come to watch
const MAX_ACTIVE := 2
const CORE_IDS := ["priestess", "ranger", "brawler", "dancer"]      # the v0.7 allies (the four colours on the stage 1/2 maps)
const FACE_IDS := ["cl_knight", "cl_ranger", "cl_weaver", "cl_mage", "perry"]     # Stage 3 phase 7 (ally_faces.gd)
## roster.json key of an ally's art: the face allies have their own "ally_<id>" entries (the enemy cl_* and the boss
## perry keep the plain ones)
static func art_id(aid: String) -> String:
	return "ally_" + aid if aid in FACE_IDS else aid
## defeated enemy id -> the ally card it drops (always; a full hand leaves it on the floor, game.gd on_enemy_defeated)
const DROPS := {"cl_knight": "cl_knight", "cl_ranger": "cl_ranger", "cl_weaver": "cl_weaver", "cl_mage": "cl_mage", "perry": "perry"}          # allies on the field at once (one of each type)

## where the cards lie: level index -> [[x, ally id], ...]
## 0 Sunlit Country, 1 Misty Woods, 2 Moonlit Town, 4 Infernal Caverns, 6..10 the stage 2 maps. Cemetery (3) has none.
const CARDS := {
	0: [[2800.0, "ranger"], [7200.0, "dancer"], [11000.0, "priestess"], [15000.0, "brawler"]],
	1: [[3400.0, "priestess"], [7600.0, "brawler"], [11800.0, "ranger"], [15600.0, "dancer"]],
	2: [[3000.0, "dancer"], [7000.0, "ranger"], [10800.0, "priestess"], [14800.0, "brawler"]],
	4: [[3200.0, "ranger"], [6800.0, "priestess"], [10400.0, "dancer"], [13600.0, "brawler"]],
	6: [[3600.0, "priestess"], [7400.0, "dancer"], [11400.0, "brawler"], [15200.0, "ranger"]],
	7: [[2600.0, "brawler"], [6600.0, "ranger"], [10200.0, "dancer"], [14400.0, "priestess"]],
	8: [[3800.0, "dancer"], [7800.0, "priestess"], [12200.0, "ranger"], [15800.0, "brawler"]],
	9: [[3000.0, "ranger"], [6400.0, "brawler"], [11600.0, "priestess"], [14000.0, "dancer"]],
	10: [[3400.0, "brawler"], [7000.0, "dancer"], [10600.0, "ranger"], [14600.0, "priestess"]],
	# stage 3: the four Changeling faces (cards of the faces; 11 Perry's Arena and 19 the Throne have none)
	12: [[2600.0, "cl_knight"], [4570.0, "cl_ranger"], [6950.0, "cl_weaver"], [8200.0, "cl_mage"]],
	13: [[2600.0, "cl_ranger"], [7370.0, "cl_weaver"], [9630.0, "cl_mage"], [13600.0, "cl_knight"]],
	14: [[2600.0, "cl_weaver"], [5820.0, "cl_mage"], [8400.0, "cl_knight"], [11500.0, "cl_ranger"]],
	15: [[2600.0, "cl_mage"], [6420.0, "cl_knight"], [10880.0, "cl_ranger"], [15850.0, "cl_weaver"]],
	16: [[2600.0, "cl_knight"], [6720.0, "cl_ranger"], [10230.0, "cl_weaver"], [15250.0, "cl_mage"]],
	17: [[2600.0, "cl_ranger"], [6420.0, "cl_weaver"], [13580.0, "cl_mage"], [17200.0, "cl_knight"]],
	18: [[2200.0, "cl_weaver"], [9520.0, "cl_mage"], [13530.0, "cl_knight"], [17750.0, "cl_ranger"]],
}
