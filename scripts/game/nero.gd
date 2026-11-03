extends "res://scripts/game/cl_warlord.gd"
## The final boss: King Lucius Nerochilde (Roster id nero). The Warlord's shape with his own numbers (Roster.DEFS "nero"):
##   phase 1  staff swing, a volley of three dark bolts from range, a lunge
##   phase 2  + a charge across the court; if he reaches the wall he crashes and is stunned (CHARGE_STUN s)
##   phase 3  + a jump slam: two floor shockwaves roll out from where he lands (jump them); faster tells and steps
## He does not parry and has no shield: every attack is telegraphed. His damage never scales with anything.
## Beating him ends the game: Roster.FINALE[20] plays the ending pages (game.gd _start_finale_victory).
