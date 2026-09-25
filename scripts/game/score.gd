extends RefCounted
## Score bookkeeping. Every landed trick banks immediately, multiplied by FLOW: each clean
## trick raises flow (up to x5); a wipeout, or too long on the water without a trick, resets it.

const FLOW_WINDOW := 4.0
const MAX_FLOW := 5
const RING_POINTS := 250

var score := 0
var flow := 1
var timer := 0.0
var tricks := 0
var rings := 0
var wipeouts := 0
var on_beats := 0
var best_trick := ""
var best_trick_pts := 0
var best_flow := 1


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
