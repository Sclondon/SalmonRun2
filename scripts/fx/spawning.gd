extends Node3D
## The spawning, played out under the water at the end of the way up, a caption to each part
## of it (see main.SPAWNING): the pair come to the gravel; she turns on her side and digs
## the nest with her tail; she lays her eggs in it and he fertilises them; she covers them
## and the two drift away; in spring the eggs hatch; and the young swim off for the sea.
##
## It is a little stage set down in the water where the salmon is: `begin` builds it,
## `advance` moves it on (by how many captions have gone by), `end` takes it away.

const Track := preload("res://scripts/world/track.gd")
const Props := preload("res://scripts/world/props.gd")

const EGGS := 46
const YOUNG := 14

var track: Track
## Where the nest is: how far along the stage and across it, and how far under the surface.
var at_s := 0.0
var at_x := 0.0
var deep := 2.4

var _she: MeshInstance3D
var _he: MeshInstance3D
var _mats: Array[ShaderMaterial] = []
var _nest: MeshInstance3D
var _cover: MeshInstance3D
var _eggs: MultiMesh
var _egg_at: Array[Vector3] = []
var _young: Array[MeshInstance3D] = []
var _grit: CPUParticles3D
var _milt: CPUParticles3D
var _t := 0.0


## Builds the set at `s`, `x` on `on`. `look` is what the pair look like (the spawner).
func begin(on: Track, s: float, x: float) -> void:
	track = on
	at_s = s
	at_x = x
	transform = Transform3D(track.basis_at(s), track.point(s, x, track.water_y(s) - deep))
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	var world_mat: Material = track.mat_world
	# the gravel: a low bed of it with pebbles on, and (later) the heap that covers the eggs
	var mb := Props.MB.new()
	Props.blob(mb, Vector3(0.0, -0.55, 0.0), Vector3(4.6, 0.5, 4.6), rng, Color(0.46, 0.44, 0.4), 9, 3, 0.12)
	for k in 40:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 4.2
		var size := rng.randf_range(0.12, 0.3)
		Props.blob(mb, Vector3(cos(a) * r, -0.14 - 0.05 * r, sin(a) * r), Vector3(size, size * 0.7, size), rng,
				Color(0.5, 0.48, 0.44).lerp(Color(0.34, 0.33, 0.32), rng.randf()), 5, 2, 0.2)
	_nest = _part(mb.build(), world_mat)
	var heap := Props.MB.new()
	Props.blob(heap, Vector3(0.0, -0.1, 0.0), Vector3(1.1, 0.34, 1.1), rng, Color(0.52, 0.5, 0.46), 7, 3, 0.2)
	_cover = _part(heap.build(), world_mat)
	_cover.scale = Vector3.ONE * 0.01
	# the eggs: small orange beads, each with a place in the nest to fall to
	var bead := SphereMesh.new()
	bead.radius = 0.06
	bead.height = 0.12
	bead.radial_segments = 6
	bead.rings = 3
	var orange := StandardMaterial3D.new()
	orange.albedo_color = Color(1.0, 0.45, 0.12)
	orange.emission_enabled = true
	orange.emission = Color(1.0, 0.4, 0.1)
	orange.emission_energy_multiplier = 0.5
	bead.material = orange
	_eggs = MultiMesh.new()
	_eggs.transform_format = MultiMesh.TRANSFORM_3D
	_eggs.mesh = bead
	_eggs.instance_count = EGGS
	var beads := MultiMeshInstance3D.new()
	beads.multimesh = _eggs
	add_child(beads)
	for k in EGGS:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.6
		_egg_at.append(Vector3(cos(a) * r, 0.02 + rng.randf() * 0.14, sin(a) * r))
		_eggs.set_instance_transform(k, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.001), Vector3.ZERO))
	# the pair
	var shader := preload("res://shaders/fish.gdshader")
	var adult := Props.salmon("spawner")
	for k in 2:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		_mats.append(mat)
		var fish := MeshInstance3D.new()
		fish.mesh = adult
		fish.material_override = mat
		add_child(fish)
		if k == 0:
			_she = fish
		else:
			_he = fish
	# the young, when they hatch: fry, very small
	var fry := Props.salmon("fry")
	for k in YOUNG:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("wag_amp", 0.2)
		_mats.append(mat)
		var small := MeshInstance3D.new()
		small.mesh = fry
		small.material_override = mat
		small.visible = false
		add_child(small)
		_young.append(small)
	# gravel thrown up by her tail, and his milt: a pale cloud
	_grit = _cloud(Color(0.6, 0.58, 0.52), 60, 0.09, 2.6, Vector3(0, -3.0, 0))
	_milt = _cloud(Color(0.95, 0.97, 1.0), 70, 0.16, 0.5, Vector3(0, -0.15, 0))
	_milt.lifetime = 2.6
	advance(0.0, 0.0)


func _part(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	add_child(node)
	return node


func _cloud(colour: Color, amount: int, size: float, speed: float, pull: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var speck := SphereMesh.new()
	speck.radius = 0.5
	speck.height = 1.0
	speck.radial_segments = 5
	speck.rings = 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = colour
	speck.material = mat
	p.mesh = speck
	p.amount = amount
	p.lifetime = 1.1
	p.emitting = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = pull
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size * 1.3
	add_child(p)
	return p


## Moves the scene on: `u` is how many captions have gone by (2.5 is half way through the
## third), `delta` the time since the last call.
func advance(u: float, delta: float) -> void:
	_t += delta
	for k in _mats.size():
		_mats[k].set_shader_parameter("wag_phase", _t * (7.0 if k < 2 else 16.0) + k * 1.3)
	# --- the pair. (Upstream is -Z here: they face into the stream.)
	var dig := smoothstep(1.0, 1.25, u) * (1.0 - smoothstep(1.85, 2.05, u))
	var lay := smoothstep(2.0, 2.3, u) * (1.0 - smoothstep(3.0, 3.3, u))
	var gone := smoothstep(3.4, 4.0, u)
	# she comes down to the gravel; digging, she rolls on her side and beats her tail
	var beat := sin(_t * 16.0) * dig
	var her := Vector3(0.0, 1.0 - 0.45 * smoothstep(0.3, 1.0, u) - 0.25 * lay + beat * 0.08, 0.2 - 0.5 * dig)
	_she.transform = Transform3D(Basis(Vector3.BACK, 1.35 * dig + beat * 0.25) * Basis(Vector3.RIGHT, -0.25 * lay), her)
	_mats[0].set_shader_parameter("wag_amp", 0.1 + 0.3 * dig)
	# he keeps beside her, and comes in close over the nest as the eggs are laid
	var him := Vector3(1.5 - 1.0 * lay, 1.25 - 0.5 * lay, 1.0 - 0.9 * lay)
	_he.transform = Transform3D(Basis(Vector3.UP, 0.15 * lay) * Basis(Vector3.RIGHT, -0.2 * lay), him)
	# afterwards they are spent: they drift off down the stream, turning on their sides
	for fish: MeshInstance3D in [_she, _he]:
		var side := 1.0 if fish == _she else -1.0
		fish.position += Vector3(side * 1.5, -0.2, 9.0) * gone
		fish.basis = fish.basis * Basis(Vector3.BACK, side * 1.4 * gone)
		fish.visible = u < 4.2
	_mats[0].set_shader_parameter("wag_amp", lerpf(0.1 + 0.3 * dig, 0.02, gone))
	_mats[1].set_shader_parameter("wag_amp", lerpf(0.12, 0.02, gone))
	# --- the gravel thrown up as she digs, and again as she covers the eggs
	_grit.position = Vector3(0.0, 0.1, 0.9)
	_grit.emitting = dig > 0.5 or (u > 3.0 and u < 3.5)
	# --- the eggs: laid a few at a time, each falling to its place in the nest
	for k in EGGS:
		var laid := clampf((u - 2.25 - 0.5 * k / EGGS) / 0.22, 0.0, 1.0)
		var size := 1.0 if laid > 0.0 else 0.001
		# in spring they stir, and are gone as the young come out of them
		var stir := smoothstep(4.0, 4.5, u)
		var hatch := smoothstep(4.45 + 0.4 * k / EGGS, 4.6 + 0.4 * k / EGGS, u)
		size *= (1.0 + 0.25 * sin(_t * 9.0 + k) * stir) * (1.0 - hatch)
		var from := her + Vector3(0.0, -0.3, 0.5)
		var at := from.lerp(_egg_at[k], laid * laid)
		_eggs.set_instance_transform(k, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * maxf(size, 0.001)), at))
	# --- his milt, over the eggs
	_milt.position = him + Vector3(0.0, -0.3, 0.6)
	_milt.emitting = u > 2.45 and u < 3.0
	# --- the gravel swept over them, and worn away again by spring
	var covered := smoothstep(3.0, 3.5, u) * (1.0 - smoothstep(4.0, 4.4, u))
	_cover.scale = Vector3.ONE * maxf(covered, 0.01)
	# --- the young: out of the gravel, a moment wriggling over it, and away down the stream
	for k in YOUNG:
		var small := _young[k]
		var out := smoothstep(4.5 + 0.4 * k / YOUNG, 4.75 + 0.4 * k / YOUNG, u)
		small.visible = out > 0.0
		if not small.visible:
			continue
		var away := smoothstep(5.0 + 0.3 * k / YOUNG, 6.0, u)
		var home := _egg_at[(k * 3) % EGGS] * 1.6
		var roam := Vector3(sin(_t * 1.7 + k * 2.0) * 0.5, 0.35 + 0.25 * sin(_t * 2.3 + k), cos(_t * 1.3 + k * 1.4) * 0.5)
		# (down the stream is +Z here: they turn tail to the current and go)
		var place := (home + roam * out).lerp(home + Vector3(sin(k * 1.9) * 2.0, 0.8 + 0.1 * k, 4.0 + 14.0 * away), away)
		var turn := Basis(Vector3.UP, lerpf(sin(_t * 1.1 + k) * 0.8, PI, away))
		small.transform = Transform3D(turn.scaled(Vector3.ONE * 0.34 * out), place)


## Where to film it from, and what to look at: beside the nest, under the water.
func eye() -> Vector3:
	return global_transform * Vector3(-5.6, 1.1, 2.4)


func focus() -> Vector3:
	return global_transform * Vector3(0.0, 0.5, 0.4)
