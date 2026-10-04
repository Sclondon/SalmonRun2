extends Node3D
## The 3D world: environment, lights, the course, the salmon and the camera.

const Track := preload("res://scripts/world/track.gd")
const Salmon := preload("res://scripts/player/salmon.gd")
const ChaseCam := preload("res://scripts/world/chase_camera.gd")

var track: Track
var player: Salmon
var camera: ChaseCam
var env: Environment
var sun: DirectionalLight3D
var _fireflies: CPUParticles3D


func _ready() -> void:
	_make_environment()
	track = Track.new()
	add_child(track)
	track.build(1987)
	player = Salmon.new()
	add_child(player)
	player.setup(track)
	camera = ChaseCam.new()
	camera.near = 0.2
	camera.far = 450.0 if Save.is_mobile() else 900.0
	camera.player = player
	camera.track = track
	add_child(camera)
	camera.current = true
	_make_fireflies()


## Swaps the river for the practice level (or back to the race course). Rebuilding takes a moment.
func set_course(test: bool) -> void:
	if track.test == test:
		return
	remove_child(track)
	track.queue_free()
	track = Track.new()
	add_child(track)
	move_child(track, 0)
	track.build(1987, test)
	player.track = track
	player.rail = {}
	player.reset(Track.START_S)
	camera.track = track
	camera.snap()


func _make_environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = preload("res://shaders/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.5, 0.7)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.85, 0.5, 0.55)
	env.fog_density = 0.0055
	env.fog_sky_affect = 0.25
	env.fog_aerial_perspective = 0.3
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.86, 0.7)
	sun.light_energy = 1.15
	sun.shadow_enabled = not Save.is_mobile()
	sun.directional_shadow_max_distance = 120.0
	sun.rotation_degrees = Vector3(-38.0, 150.0, 0.0)
	add_child(sun)


func _make_fireflies() -> void:
	_fireflies = CPUParticles3D.new()
	_fireflies.amount = 40 if Save.is_mobile() else 120
	_fireflies.lifetime = 5.0
	_fireflies.local_coords = false
	_fireflies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_fireflies.emission_box_extents = Vector3(40, 8, 40)
	_fireflies.direction = Vector3(0, 1, 0)
	_fireflies.spread = 180.0
	_fireflies.initial_velocity_min = 0.3
	_fireflies.initial_velocity_max = 1.2
	_fireflies.gravity = Vector3.ZERO
	var m := BoxMesh.new()
	m.size = Vector3.ONE * 0.12
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.8, 1.0, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 1.0, 0.3)
	mat.emission_energy_multiplier = 3.0
	m.material = mat
	_fireflies.mesh = m
	add_child(_fireflies)


func _process(_delta: float) -> void:
	var pulse := Music.beat_pulse()
	sun.light_energy = 1.15 + pulse * 0.12
	env.glow_intensity = 0.9 + pulse * 0.5
	if camera:
		_fireflies.global_position = camera.global_position + track.forward(player.s) * 25.0
