extends Node3D
## A landing splash, after the ones in The Wind Waker: rings of columns of water that shoot up
## one after another, each wider and lower than the last, ripples spreading across the surface
## and a burst of splattery drops.
##
## It rides along the course a little slower than the salmon rather than staying where it
## landed, or at racing speed it would be behind the camera before it had finished.

const Track := preload("res://scripts/world/track.gd")
const Props := preload("res://scripts/world/props.gd")

const LIFE := 1.1
## Each ring of columns: how many, how far out, how tall, how thick, and when it goes up.
const RINGS := [[7, 0.55, 2.3, 0.16, 0.0], [10, 1.25, 1.5, 0.15, 0.08], [14, 2.1, 0.95, 0.13, 0.17]]
const RING_TIME := 0.5
## Each ripple: when it starts, and how wide it gets.
const RIPPLES := [[0.0, 3.2], [0.14, 4.4], [0.3, 5.6]]
const RIPPLE_TIME := 0.75

static var _meshes := {}
static var _mat: StandardMaterial3D

var track: Track
## The salmon it follows along the course.
var player: Node3D
var s := 0.0
var x := 0.0
var strength := 1.0

var _t := 0.0
var _columns: Array[Node3D] = []
var _ripples: Array[MeshInstance3D] = []


## Plain white-and-blue water, unlit, coloured by the mesh.
static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.vertex_color_use_as_albedo = true
	return _mat


static func mesh(key: String) -> Mesh:
	if _meshes.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for i in RINGS.size():
			_meshes["columns%d" % i] = Props.splash_columns(RINGS[i][0], float(RINGS[i][3]) / float(RINGS[i][1]), rng)
		_meshes["ring"] = Props.splash_ring()
		_meshes["drop"] = Props.droplet(rng)
		_meshes["splat"] = Props.splat(rng)
	return _meshes[key]


func start(on: Track, follow: Node3D, at_s: float, at_x: float, how_big: float) -> void:
	track = on
	player = follow
	s = at_s
	x = at_x
	strength = how_big
	for i in RINGS.size():
		var node := MeshInstance3D.new()
		node.mesh = mesh("columns%d" % i)
		node.material_override = material()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.rotation.y = randf() * TAU
		node.visible = false
		add_child(node)
		_columns.append(node)
	for i in RIPPLES.size():
		var node := MeshInstance3D.new()
		node.mesh = mesh("ring")
		# each ripple fades on its own, so each needs a material of its own
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1, 1, 1, 0.0)
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_ripples.append(node)
	_burst("drop", int(10 * strength), 0.26, 5.0, 10.0)
	_burst("splat", int(8 * strength), 0.34, 3.5, 7.5)
	_place()


## A one-shot spray of drops, flung up and outwards.
func _burst(key: String, amount: int, size: float, slow: float, fast: float) -> void:
	var p := CPUParticles3D.new()
	p.mesh = mesh(key)
	p.material_override = material()
	p.amount = maxi(amount, 4)
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 0.8
	p.local_coords = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.5
	p.direction = Vector3.UP
	p.spread = 62.0
	p.initial_velocity_min = slow * sqrt(strength)
	p.initial_velocity_max = fast * sqrt(strength)
	p.gravity = Vector3(0, -24, 0)
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size * 1.3
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(0.7, 0.8))
	shrink.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = shrink
	add_child(p)
	p.emitting = true


func _place() -> void:
	transform = Transform3D(track.basis_at(s), track.point(s, x, track.water_y(s) + 0.03))


func _process(delta: float) -> void:
	_t += delta
	if _t > LIFE or track == null or not is_instance_valid(player):
		queue_free()
		return
	s = minf(s + float(player.get("speed")) * 0.82 * delta, track.length - 4.0)
	_place()
	for i in _columns.size():
		var u := (_t - float(RINGS[i][4])) / RING_TIME
		var node := _columns[i]
		node.visible = u > 0.0 and u < 1.0
		if not node.visible:
			continue
		# up fast, hang, then drop away: the key pose is the top, a quarter of the way in
		var rise := sin(minf(u / 0.25, 1.0) * PI * 0.5) if u < 0.25 else 1.0 - pow((u - 0.25) / 0.75, 2.2)
		var r := float(RINGS[i][1]) * sqrt(strength) * (1.0 + 0.35 * u)
		node.scale = Vector3(r, maxf(float(RINGS[i][2]) * strength * rise, 0.01), r)
	for i in _ripples.size():
		var u := (_t - float(RIPPLES[i][0])) / RIPPLE_TIME
		var node := _ripples[i]
		node.visible = u > 0.0 and u < 1.0
		if not node.visible:
			continue
		var r := lerpf(0.5, float(RIPPLES[i][1]) * sqrt(strength), 1.0 - pow(1.0 - u, 2.5))
		node.scale = Vector3(r, 1.0, r)
		(node.material_override as StandardMaterial3D).albedo_color.a = (1.0 - u) * 0.85
