extends Node3D
## Bubbles swept along inside the ocean currents: real things in the water (each a little ring
## that faces the eye), not part of the picture on the tunnel's wall. They fill whichever
## current is near the salmon, go down it faster than the salmon swims, each at its own
## speed, and turn slowly round the middle of the tunnel as they go.

const Track := preload("res://scripts/world/track.gd")
const Salmon := preload("res://scripts/player/salmon.gd")

## The stretch of a current that has bubbles in it: this far behind the salmon, and ahead.
const BEHIND := 25.0
const AHEAD := 120.0

var track: Track
var player: Salmon

var _mm: MultiMesh
var _node: MultiMeshInstance3D
# each bubble: (where along the stretch, from 0 to 1; which way out from the middle, in
# turns; how far out, from 0 to 1), its speed (m/s) and its size (m)
var _places: Array[Vector3] = []
var _speeds := PackedFloat32Array()
var _sizes := PackedFloat32Array()
var _t := 0.0


func setup(t: Track, p: Salmon, count: int) -> void:
	track = t
	player = p
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/bubble.gdshader")
	quad.material = mat
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.mesh = quad
	_mm.instance_count = count
	_node = MultiMeshInstance3D.new()
	_node.multimesh = _mm
	_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (it is set down wherever the current is, in the world's own measure: never culled)
	_node.custom_aabb = AABB(Vector3(-1e5, -1e3, -1e5), Vector3(2e5, 2e3, 2e5))
	_node.visible = false
	add_child(_node)
	for k in count:
		# (more of them out towards the wall than in the middle, where the salmon rides)
		_places.append(Vector3(rng.randf(), rng.randf(), sqrt(rng.randf_range(0.08, 0.9))))
		_speeds.append(rng.randf_range(26.0, 46.0))
		_sizes.append(rng.randf_range(0.14, 0.42))


func _process(delta: float) -> void:
	if track == null or player == null or _mm == null:
		return
	_t += minf(delta, 1.0 / 15.0)
	# the current that is nearest the salmon, if any is near at all
	var from := player.s - BEHIND
	var to := player.s + AHEAD
	var near := {}
	for c: Dictionary in track.currents:
		if float(c.s1) > from and float(c.s0) < to:
			near = c
			break
	_node.visible = not near.is_empty()
	if not _node.visible:
		return
	var long := BEHIND + AHEAD
	var tiny := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.001), Vector3.ZERO)
	for k in _places.size():
		var place := _places[k]
		# (each keeps going down the water at its own speed, and comes round again)
		var s := from + fposmod(place.x * long + _t * _speeds[k] - from, long)
		if s < float(near.s0) + 0.5 or s > float(near.s1) - 0.5:
			_mm.set_instance_transform(k, tiny)
			continue
		var turn := (place.y + _t * 0.12 * (0.5 + place.x)) * TAU
		var out := track.current_radius(near, s) * place.z
		var middle := track.point(s, track.current_x(near, s), track.water_y(s) - track.current_depth(near, s))
		var at := middle + (track.right(s) * cos(turn) + Vector3.UP * sin(turn)) * out
		# (smaller and smaller towards either end of the current, where it fades away)
		var there := smoothstep(0.0, 26.0, minf(s - float(near.s0), float(near.s1) - s))
		_mm.set_instance_transform(k, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * _sizes[k] * maxf(there, 0.01)), at))
