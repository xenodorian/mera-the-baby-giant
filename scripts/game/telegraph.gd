class_name Telegraph
extends RefCounted
## v0.6 telegraph standard (docs/GAME_RULES.md "Telegraphs"). Every enemy attack, knights included, starts with a TELL:
## the attacker freezes on its wind-up frame, its sprite pulses in the attack's colour and a "!" of the same colour
## pops over its head. The tell is never shorter than MIN_TELL. The colour says how to answer it:
##   MELEE  orange      a normal strike: step back, dodge (B) or block (L2 hold)
##   HEAVY  white-gold  a special or long-reach strike: get out of range or dodge through it
##   RANGED red         fire, breath or a projectile: barrier (L2 hold) or jump it
##   RUSH   purple      a charge, pounce or swoop with the whole body: jump over it or dodge

const MIN_TELL := 0.35
const COLORS := {
	"melee": Color(1.0, 0.55, 0.1),
	"heavy": Color(1.0, 0.92, 0.55),
	"ranged": Color(1.0, 0.15, 0.1),
	"rush": Color(0.75, 0.3, 1.0),
}


static func color(kind: String) -> Color:
	return COLORS.get(kind, COLORS["melee"])


## sprite modulate while telling (t = seconds into the tell)
static func pulse(kind: String, t: float) -> Color:
	var q := 0.5 + 0.5 * sin(t * 40.0)
	var c := color(kind)
	return Color(1.0 + c.r * 1.1 * q, 1.0 + c.g * 1.1 * q, 1.0 + c.b * 1.1 * q)


## the "!" over the head: a small Node2D, drawn when .visible; call set_kind() then show()
static func marker() -> Node2D:
	var n := Node2D.new()
	n.set_script(load("res://scripts/game/tell_marker.gd"))
	n.visible = false
	n.z_index = 20
	return n
