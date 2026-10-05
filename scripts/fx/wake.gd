extends Node
## The salmon's wake. It is not drawn here: this keeps the trail of where the salmon has been
## on the surface and hands it to the water shader, which draws the wake as part of the water
## (two bands of foam opening out into a V, and the waves churned flat between them). See the
## "wake" uniforms in shaders/water.gdshader.

const Track := preload("res://scripts/world/track.gd")

## Seconds the wake lasts, how often a new point is laid, and how many the shader takes.
const LIFE := 1.6
const STEP := 0.075
const POINTS := 24

var track: Track

# where the salmon has been: [s, x, time laid], oldest first. A break (an empty entry) is
# where it left the surface, so that the two ends are not joined up.
var _trail: Array = []
var _clock := 0.0
var _since := 0.0


## Called every frame by the salmon: where it is, and whether it is cutting the surface
## (strength above 0).
func lay(s: float, x: float, strength: float, delta: float) -> void:
	_clock += delta
	_since += delta
	if strength <= 0.0:
		if not _trail.is_empty() and not (_trail[-1] as Array).is_empty():
			_trail.append([])
	elif _since >= STEP or _trail.is_empty() or (_trail[-1] as Array).is_empty():
		_since = 0.0
		_trail.append([s, x, _clock])
	while not _trail.is_empty() and ((_trail[0] as Array).is_empty() or _clock - float(_trail[0][2]) > LIFE):
		_trail.pop_front()
	while _trail.size() > POINTS - 1:
		_trail.pop_front()
	_send(s, x, strength)


func clear() -> void:
	_trail.clear()
	if track and track.mat_water:
		track.mat_water.set_shader_parameter("wake_count", 0)


func _send(s: float, x: float, strength: float) -> void:
	if track == null or track.mat_water == null:
		return
	# (the newest point is always the salmon itself, so that the wake never lags behind it)
	var pieces := _trail.duplicate()
	if strength > 0.0:
		pieces.append([s, x, _clock])
	var pts := PackedVector3Array()
	var first := INF
	var last := -INF
	for piece: Array in pieces:
		if piece.is_empty():
			pts.append(Vector3(0.0, 0.0, -1.0))
			continue
		var ps: float = piece[0]
		first = minf(first, ps)
		last = maxf(last, ps)
		pts.append(Vector3(track.water_u(ps, float(piece[1])), ps, _clock - float(piece[2])))
	var count := pts.size()
	pts.resize(POINTS)
	var mat := track.mat_water
	mat.set_shader_parameter("wake_pts", pts)
	mat.set_shader_parameter("wake_count", count)
	mat.set_shader_parameter("wake_span", Vector2(first - 6.0, last + 2.0))
	mat.set_shader_parameter("wake_life", LIFE)
