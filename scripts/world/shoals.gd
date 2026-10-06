extends Node3D
## Shoals of small fish under the water: scenery, not something to hit. Each shoal keeps to a
## depth of its own and swims along the course (some the other way), slower than the salmon,
## which goes past them. One that has dropped out of sight is put back in ahead.

const Track := preload("res://scripts/world/track.gd")
const Salmon := preload("res://scripts/player/salmon.gd")
const Props := preload("res://scripts/world/props.gd")

const AHEAD := 150.0
const BEHIND := 30.0
## The kinds of fish: the colour of the back, and of the flank.
const KINDS := [
	[Color(0.3, 0.42, 0.55), Color(0.82, 0.88, 0.92)],
	[Color(0.2, 0.5, 0.45), Color(0.9, 0.86, 0.6)],
	[Color(0.45, 0.4, 0.6), Color(0.95, 0.75, 0.8)],
]

var track: Track
var player: Salmon

## Sardines: great swarms of one small silver fish, each swarm turning slowly on itself, in the
## salt water only. (Set before setup.)
var sardines := false
## Krill: clouds of tiny pink shrimps drifting near the surface of the sea, which is what a
## sockeye feeds on out there. (Set before setup.)
var krill := false

var _shoals: Array[Dictionary] = []
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func setup(t: Track, p: Salmon, count: int, fish: int) -> void:
	track = t
	player = p
	_rng.seed = 1357 + (11 if sardines else 0) + (23 if krill else 0)
	var meshes: Array[Mesh] = []
	if krill:
		var shrimp := BoxMesh.new()
		shrimp.size = Vector3(0.05, 0.05, 0.22)
		var pink := StandardMaterial3D.new()
		pink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pink.albedo_color = Color(1.0, 0.6, 0.55)
		shrimp.material = pink
		meshes.append(shrimp)
	elif sardines:
		meshes.append(Props.sardine())
	for kind: Array in ([] if sardines or krill else KINDS):
		meshes.append(Props.small_fish(kind[0], kind[1]))
	for i in count:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[i % meshes.size()]
		mm.instance_count = fish
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# (the fish move about inside it, so it is given room enough never to be culled early)
		node.custom_aabb = AABB(Vector3(-16, -8, -16), Vector3(32, 16, 32))
		add_child(node)
		var places: Array[Vector3] = []
		for k in fish:
			places.append(Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)))
		_shoals.append({"node": node, "mm": mm, "places": places, "s": 0.0, "x": 0.0, "depth": 1.0,
				"pace": 8.0, "drift": 0.0, "size": 1.0, "spread": Vector3.ONE, "phase": _rng.randf() * TAU})
	scatter()


## Spreads the shoals out round the player (after a restart or a change of stage).
func scatter() -> void:
	for sh: Dictionary in _shoals:
		(sh.node as Node3D).material_override = null if krill else (silver() if sardines else track.mat_world)
		_place(sh, player.s + _rng.randf_range(10.0, AHEAD))


func _place(sh: Dictionary, at_s: float) -> void:
	sh.s = clampf(at_s, 4.0, track.length - 8.0)
	# (in as much water as there is to dive in: a river has far less of it than the sea)
	var room := track.layers() * track.layer_depth()
	var lim := maxf(track.width(sh.s) * 0.5 - 3.0, 1.0)
	sh.x = clampf(player.x + _rng.randf_range(-26.0, 26.0), -lim, lim)
	sh.depth = _rng.randf_range(minf(1.2, room * 0.7), room + 0.6)
	# most swim the way the salmon is going; some come the other way
	sh.pace = _rng.randf_range(6.0, 13.0) * (-1.0 if _rng.randf() < 0.3 else 1.0)
	sh.drift = _rng.randf_range(-1.2, 1.2)
	sh.size = _rng.randf_range(0.5, 0.75) if sardines else _rng.randf_range(0.7, 1.25)
	var tight := clampf(room / 6.0, 0.35, 1.0)
	sh.spread = Vector3(_rng.randf_range(1.5, 4.0) * tight, minf(_rng.randf_range(0.5, 1.6), sh.depth - 0.5) * tight, _rng.randf_range(2.5, 6.0) * tight)
	if krill:
		sh.depth = _rng.randf_range(0.5, 2.2)
		sh.pace = _rng.randf_range(0.5, 2.0)
		sh.size = 1.0
		sh.spread = Vector3(_rng.randf_range(4.0, 8.0), 0.7, _rng.randf_range(5.0, 10.0))


func _process(delta: float) -> void:
	if track == null or player == null:
		return
	var dt := minf(delta, 1.0 / 15.0)
	_t += dt
	for sh: Dictionary in _shoals:
		var gap: float = float(sh.s) - player.s
		if gap > AHEAD + 20.0 or gap < -BEHIND:
			_place(sh, player.s + _rng.randf_range(AHEAD * 0.7, AHEAD))
		var s: float = clampf(float(sh.s) + float(sh.pace) * dt, 4.0, track.length - 8.0)
		var lim := maxf(track.width(s) * 0.5 - 3.0, 1.0)
		var x: float = clampf(float(sh.x) + float(sh.drift) * dt, -lim, lim)
		sh.s = s
		sh.x = x
		var node: MultiMeshInstance3D = sh.node
		# (nothing swims through a waterfall)
		node.visible = not track.near_fall(s, 25.0, 25.0) and (not (sardines or krill) or bool(track.cfg.get("salt", false))) and not (krill and bool(track.cfg.get("submerged", false)))
		if not node.visible:
			continue
		var facing := track.basis_at(s)
		if float(sh.pace) < 0.0:
			facing = facing * Basis(Vector3.UP, PI)
		node.transform = Transform3D(facing, track.point(s, x, track.water_y(s) - float(sh.depth)))
		var mm: MultiMesh = sh.mm
		var places: Array[Vector3] = sh.places
		var spread: Vector3 = sh.spread
		var size: float = sh.size
		var phase: float = sh.phase
		for k in places.size():
			var at := places[k] * spread
			if sardines:
				# (a ball of them, turning: those further out go round slower)
				at = Basis(Vector3.UP, _t * 0.9 / (0.6 + places[k].length()) + phase) * (places[k] * Vector3(spread.z, spread.y * 1.6, spread.z) * 0.9)
			var own := phase + k * 1.7
			# each wanders a little about its place in the shoal, and wags as it swims
			at += Vector3(sin(_t * 0.9 + own), sin(_t * 0.7 + own * 1.3) * 0.4, sin(_t * 0.6 + own * 0.7)) * 0.35
			var wag := Basis(Vector3.UP, sin(_t * 11.0 + own) * 0.22)
			mm.set_instance_transform(k, Transform3D(wag.scaled(Vector3.ONE * size), at))


# Sardines are bright metal: they take the light and throw it back.
static var _silver: StandardMaterial3D
static func silver() -> StandardMaterial3D:
	if _silver == null:
		_silver = StandardMaterial3D.new()
		_silver.vertex_color_use_as_albedo = true
		_silver.metallic = 0.85
		_silver.roughness = 0.22
		_silver.metallic_specular = 1.0
		_silver.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _silver
