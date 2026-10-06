extends Node3D
## The edge of the open sea: no line of buoys, but a swarm of sardines. As the salmon nears
## the edge of the course a wall of them gathers in its way on that side, thick enough at the
## edge itself to turn it back (the edge is still where the salmon is stopped: see
## Salmon._clamp_banks). On the stages with salt water only.

const Track := preload("res://scripts/world/track.gd")
const Salmon := preload("res://scripts/player/salmon.gd")
const Props := preload("res://scripts/world/props.gd")

## How far from the edge (metres) the swarm begins to gather, and how far it is all there.
const FROM := 16.0
const FULL := 4.0
## How far along the course the wall reaches, behind the salmon and ahead of it.
const BEHIND := 8.0
const AHEAD := 30.0

var track: Track
var player: Salmon

var _mm: MultiMesh
var _node: MultiMeshInstance3D
# each sardine's place in the wall: (how far along, from 0 to 1; how deep, from 0 to 1; how
# far beyond the edge, from 0 to 1), and a number of its own to wander by
var _places: Array[Vector3] = []
var _t := 0.0
var _gathered := 0.0


func setup(t: Track, p: Salmon, fish: int) -> void:
	track = t
	player = p
	var rng := RandomNumberGenerator.new()
	rng.seed = 9753
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.mesh = Props.small_fish(Color(0.25, 0.4, 0.55), Color(0.86, 0.92, 0.97))
	_mm.instance_count = fish
	_node = MultiMeshInstance3D.new()
	_node.multimesh = _mm
	_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (it is set down wherever the salmon is, in the world's own measure: never culled)
	_node.custom_aabb = AABB(Vector3(-1e5, -1e3, -1e5), Vector3(2e5, 2e3, 2e5))
	_node.visible = false
	add_child(_node)
	for k in fish:
		_places.append(Vector3(rng.randf(), rng.randf(), rng.randf()))


func _process(delta: float) -> void:
	if track == null or player == null or _mm == null:
		return
	var dt := minf(delta, 1.0 / 15.0)
	_t += dt
	var lim := track.width(player.s) * 0.5 - 1.3
	var near := 0.0
	if bool(track.cfg.get("salt", false)) and not track.near_fall(player.s, 30.0, 30.0):
		near = 1.0 - smoothstep(FULL, FROM, lim - absf(player.x))
	_gathered = move_toward(_gathered, near, dt * 2.5)
	_node.visible = _gathered > 0.01
	if not _node.visible:
		return
	_node.material_override = track.mat_world
	var side := 1.0 if player.x >= 0.0 else -1.0
	# (it stands where the salmon is: at the surface, or round it wherever it has dived to)
	var depth := track.layer_depth() * player.dive
	var top := maxf(depth - 2.0, 0.0)
	var deep := 3.2
	for k in _places.size():
		var place := _places[k]
		var own := k * 1.618
		# they stream along the wall the way the salmon is going, a little faster than it
		var along := fposmod(place.x + _t * 0.11 * (0.6 + 0.8 * place.z), 1.0)
		var s := clampf(player.s - BEHIND + along * (BEHIND + AHEAD), 2.0, track.length - 2.0)
		var edge := track.width(s) * 0.5
		# (thickest right at the edge, thinning out beyond it; and it bulges in and out)
		var x := side * (edge - 1.0 + place.z * place.z * 3.5 + sin(_t * 1.3 + own) * 0.4)
		var y := track.water_y(s) - 0.15 - top - place.y * place.y * deep + sin(_t * 1.7 + own * 1.3) * 0.2
		# (a few of them break the surface, in little leaps)
		if k % 4 == 0 and depth < 1.0:
			y = track.water_y(s) + maxf(sin(_t * 3.5 + own), -0.15) * 1.1
		# (the ends of the wall, and the whole of it as it gathers, are thinner: smaller fish)
		var size := _gathered * sqrt(sin(along * PI)) * (1.3 + 0.6 * place.y)
		var b := track.basis_at(s) * Basis(Vector3.UP, sin(_t * 12.0 + own) * 0.25)
		_mm.set_instance_transform(k, Transform3D(b.scaled(Vector3.ONE * maxf(size, 0.001)), track.point(s, x, y)))
