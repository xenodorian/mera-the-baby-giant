class_name RangerPlanner
extends RefCounted
## Stage 3 phase 7: how the Changeling Ranger ally (cl_ranger) climbs to a flyer. A pure function: given where she stands
## and where the flyer is, it returns the planks and ladders to build (Game.build_platform / Game.build_ladder arguments)
## in the order she uses them. Every platform-to-platform (or ground-to-platform) rise is at most `max_rise`
## (Tuning.PLATFORM_STEP_H, one jump); a taller rise is a ladder whose top is level with the plank it serves.
## At most MAX_PLATFORMS planks and MAX_LADDERS ladders, so Mera and Perry can use the same stair.

const SHOT_REACH := 240.0       # she can shoot a flyer up to this far above her feet (arrows are aimed, so not level)
const MAX_PLATFORMS := 3
const MAX_LADDERS := 2
const LADDER_MAX := 700.0       # the longest single ladder
const PLATFORM_W := 260.0
const FIRST_OFFSET := 150.0     # the first plank's centre, px from her toward the flyer
const DX := 120.0               # each next plank's centre is this much further on (planks overlap, so one jump reaches it)
const LADDER_INSET := 90.0      # a ladder stands this far inside the near edge's side of the plank it serves


## how far her feet must still rise before the flyer (centre y `target_y`) is within shot reach
static func climb_needed(surface_y: float, target_y: float, reach: float = SHOT_REACH) -> float:
	return maxf(0.0, (surface_y - target_y) - reach)


## {"steps": [{kind: "platform", x, top_y, w, rise} | {kind: "ladder", x, bottom_y, top_y}], "climb": px the plan lifts her,
##  "needed": px she needed, "complete": bool, "final_y": the last surface's y}
static func plan(ally_x: float, surface_y: float, target_x: float, target_y: float, max_rise: float = 72.0, ttl: float = 25.0) -> Dictionary:
	var need := climb_needed(surface_y, target_y)
	var out := {"steps": [], "climb": 0.0, "needed": need, "complete": true, "final_y": surface_y, "ttl": ttl}
	if need <= 0.0 or max_rise <= 1.0:
		return out
	var rises: Array = []                      # [rise, is_ladder] per plank
	if need <= MAX_PLATFORMS * max_rise:
		var n := ceili(need / max_rise)
		for i in n:
			rises.append([need / float(n), false])
	elif need - 2.0 * max_rise <= LADDER_MAX:
		rises = [[need - 2.0 * max_rise, true], [max_rise, false], [max_rise, false]]
	else:
		var half := (need - max_rise) * 0.5
		if half > LADDER_MAX:
			half = LADDER_MAX
			out["complete"] = false
		rises = [[half, true], [half, true], [max_rise, false]]
	var dir := 1.0 if target_x >= ally_x else -1.0
	var max_off := maxf(absf(target_x - ally_x) - 200.0, 100.0)
	var cur := surface_y
	var climbed := 0.0
	for i in rises.size():
		var rise: float = rises[i][0]
		var top := cur - rise
		var cx := ally_x + dir * minf(FIRST_OFFSET + float(i) * DX, max_off)
		if bool(rises[i][1]):
			out["steps"].append({"kind": "ladder", "x": cx - dir * LADDER_INSET, "bottom_y": cur, "top_y": top})
		out["steps"].append({"kind": "platform", "x": cx, "top_y": top, "w": PLATFORM_W, "rise": rise})
		cur = top
		climbed += rise
	out["climb"] = climbed
	out["final_y"] = cur
	return out


static func count(p: Dictionary, kind: String) -> int:
	var n := 0
	for s in p["steps"]:
		if s["kind"] == kind:
			n += 1
	return n


## true when every plank's rise is within max_rise unless a ladder (same top) serves it, and the caps hold
static func valid(p: Dictionary, max_rise: float) -> bool:
	if count(p, "platform") > MAX_PLATFORMS or count(p, "ladder") > MAX_LADDERS:
		return false
	var prev_ladder_top := INF
	for s in p["steps"]:
		if s["kind"] == "ladder":
			prev_ladder_top = float(s["top_y"])
		elif float(s["rise"]) > max_rise + 0.01 and not is_equal_approx(prev_ladder_top, float(s["top_y"])):
			return false
	return true
