extends Node3D
## A landing splash: three tubes of water, one inside the other like the tiers of a cake (the
## outer one wide and low, the inner one narrow and tall), that shoot up out of the surface
## with ragged crests and drop back into it, with ripples spreading across the water and a
## burst of splattery drops.
##
## It stays where the salmon went in.

const Track := preload("res://scripts/world/track.gd")
const Props := preload("res://scripts/world/props.gd")

const LIFE := 1.0
## Each tube, from the inside out: how far out, how tall, how many waves in its crest, and
## when it goes up.
const TUBES := [[0.5, 2.7, 5.0, 0.0], [1.15, 1.75, 7.0, 0.05], [1.9, 0.95, 10.0, 0.1]]
const TUBE_TIME := 0.62
## Each ripple: when it starts, and how wide it gets.
const RIPPLES := [[0.0, 3.2], [0.14, 4.4], [0.3, 5.6]]
const RIPPLE_TIME := 0.75

static var _meshes := {}
static var _mat: StandardMaterial3D

var track: Track
var s := 0.0
var x := 0.0
var strength := 1.0

var _t := 0.0
var _tubes: Array[MeshInstance3D] = []
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
		_meshes["tube"] = Props.splash_tube()
		_meshes["ring"] = Props.splash_ring()
		_meshes["drop"] = Props.droplet(rng)
		_meshes["splat"] = Props.splat(rng)
	return _meshes[key]


func start(on: Track, at_s: float, at_x: float, how_big: float) -> void:
	track = on
	s = at_s
	x = at_x
	strength = how_big
	for i in TUBES.size():
		var node := MeshInstance3D.new()
		node.mesh = mesh("tube")
		# each tube has a crest of its own, and thins out on its own
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/splash.gdshader")
		mat.set_shader_parameter("waves", TUBES[i][2])
		mat.set_shader_parameter("phase", randf() * TAU)
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visible = false
		add_child(node)
		_tubes.append(node)
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
	_burst("drop", int(12 * strength), 0.26, 5.0, 11.0)
	_burst("splat", int(9 * strength), 0.34, 3.5, 8.0)
	transform = Transform3D(track.basis_at(s), track.point(s, x, track.water_y(s) + 0.03))


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


func _process(delta: float) -> void:
	_t += delta
	if _t > LIFE:
		queue_free()
		return
	for i in _tubes.size():
		var u := (_t - float(TUBES[i][3])) / TUBE_TIME
		var node := _tubes[i]
		node.visible = u > 0.0 and u < 1.0
		if not node.visible:
			continue
		# up fast, hang at the top, then drop back: the key pose is the top, a fifth of the
		# way in
		var rise := sin(minf(u / 0.2, 1.0) * PI * 0.5) if u < 0.2 else 1.0 - pow((u - 0.2) / 0.8, 2.0)
		var r := float(TUBES[i][0]) * sqrt(strength) * (1.0 + 0.3 * u)
		node.scale = Vector3(r, maxf(float(TUBES[i][1]) * strength * rise, 0.01), r)
		(node.material_override as ShaderMaterial).set_shader_parameter("spent", smoothstep(0.3, 1.0, u))
	for i in _ripples.size():
		var u := (_t - float(RIPPLES[i][0])) / RIPPLE_TIME
		var node := _ripples[i]
		node.visible = u > 0.0 and u < 1.0
		if not node.visible:
			continue
		var r := lerpf(0.5, float(RIPPLES[i][1]) * sqrt(strength), 1.0 - pow(1.0 - u, 2.5))
		node.scale = Vector3(r, 1.0, r)
		(node.material_override as StandardMaterial3D).albedo_color.a = (1.0 - u) * 0.85
