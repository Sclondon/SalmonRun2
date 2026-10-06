extends RefCounted
## Score bookkeeping. Every landed trick banks immediately, multiplied by FLOW: each clean
## trick raises flow (up to x5); a wipeout, or too long on the water without a trick, resets it.

const FLOW_WINDOW := 4.0
const MAX_FLOW := 5
const RING_POINTS := 250
## How well a trick was timed to the beat, worst first: its name, how far from the beat it may
## be (as a share of the way to half-way between two beats), and what it multiplies the
## points by.
const GRADES := [
	["MISS", 1.0, 1.0],
	["SLOPPY", 0.92, 1.0],
	["O.K.", 0.82, 1.1],
	["ALRIGHT", 0.73, 1.15],
	["NICE", 0.63, 1.25],
	["GOOD", 0.52, 1.35],
	["GREAT", 0.4, 1.5],
	["EXCELLENT", 0.27, 1.75],
	["PERFECT!", 0.15, 2.0],
]
## From this grade up, a trick counts as landed on the beat (for the goals that ask for it).
const ON_BEAT := 4

var score := 0
var flow := 1
## Clean tricks since the flow last went up: it takes FLOW_STEP of them for each step.
var _clean := 0
const FLOW_STEP := 2
var timer := 0.0
var tricks := 0
var rings := 0
var wipeouts := 0
var on_beats := 0
var best_trick := ""
var best_trick_pts := 0
var best_flow := 1


## The grade (an index into GRADES) for a trick `off` seconds from the nearest beat.
static func grade(off: float, sec_per_beat: float) -> int:
	var share := absf(off) / maxf(sec_per_beat * 0.5, 0.001)
	var best := 0
	for i in GRADES.size():
		if share <= float(GRADES[i][1]):
			best = i
	return best


func reset() -> void:
	score = 0
	flow = 1
	timer = 0.0
	tricks = 0
	rings = 0
	wipeouts = 0
	on_beats = 0
	best_trick = ""
	best_trick_pts = 0
	best_flow = 1


## Banks a trick at the current flow and returns the points gained.
func add_trick(trick: Dictionary) -> int:
	var gained: int = int(trick.points) * flow
	score += gained
	tricks += 1
	if int(trick.beat) > 0:
		on_beats += 1
	if gained > best_trick_pts:
		best_trick_pts = gained
		best_trick = trick.name
	_clean += 1
	if _clean >= FLOW_STEP:
		_clean = 0
		flow = mini(flow + 1, MAX_FLOW)
	best_flow = maxi(best_flow, flow)
	timer = FLOW_WINDOW
	return gained


func add_rings(count: int) -> void:
	rings += count
	score += RING_POINTS * count
	if flow > 1:
		timer = minf(timer + 0.5 * count, FLOW_WINDOW)


## Call every frame. The flow timer only runs while you're on the water.
func tick(delta: float, airborne: bool) -> void:
	if flow <= 1 or airborne:
		return
	timer -= delta
	if timer <= 0.0:
		flow = 1
		_clean = 0


## Wipeout: flow resets. Returns the flow that was lost.
func drop() -> int:
	var had := flow
	flow = 1
	timer = 0.0
	wipeouts += 1
	return had


static func rank_for(value: int) -> String:
	if value >= 160000:
		return "S"
	if value >= 110000:
		return "A"
	if value >= 70000:
		return "B"
	if value >= 35000:
		return "C"
	return "D"
