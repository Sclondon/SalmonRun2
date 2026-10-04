extends Node3D
## The 3D world: environment, lights, the course, the salmon and the camera.

const Track := preload("res://scripts/world/track.gd")
const Salmon := preload("res://scripts/player/salmon.gd")
const ChaseCam := preload("res://scripts/world/chase_camera.gd")
const Levels := preload("res://scripts/world/levels.gd")

var track: Track
var player: Salmon
var camera: ChaseCam
var env: Environment
var sun: DirectionalLight3D
var _fireflies: CPUParticles3D
var _sky: ShaderMaterial
var _mote_mat: StandardMaterial3D
var _light_energy := 1.15


func _ready() -> void:
	_make_environment()
	track = Track.new()
	add_child(track)
	track.build(Save.level)
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
	_apply_level()


## Swaps in another level (or the practice course, which borrows the jungle). Rebuilding takes a moment.
func has_course(level: int, test: bool) -> bool:
	return track.test == test and track.level == (Levels.JUNGLE if test else level)


func set_course(level: int, test: bool) -> void:
	if test:
		level = Levels.JUNGLE
	if has_course(level, test):
		return
	remove_child(track)
	track.queue_free()
	track = Track.new()
	add_child(track)
	move_child(track, 0)
	track.build(level, test)
	_apply_level()
	player.track = track
	player.rail = {}
	player.reset(Track.START_S)
	camera.track = track
	camera.snap()


func _make_environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = preload("res://shaders/sky.gdshader")
	_sky = sky_mat
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


## Sky, fog and light for the level that was just built.
func _apply_level() -> void:
	var cfg := track.cfg
	_sky.set_shader_parameter("top_color", cfg.sky_top)
	_sky.set_shader_parameter("horizon_color", cfg.sky_horizon)
	_sky.set_shader_parameter("bottom_color", cfg.sky_bottom)
	_sky.set_shader_parameter("sun_color", cfg.sun)
	_sky.set_shader_parameter("sun_dir", cfg.sun_dir)
	env.fog_light_color = cfg.fog
	env.fog_density = cfg.fog_density
	env.ambient_light_color = cfg.ambient
	env.ambient_light_energy = cfg.ambient_energy
	sun.light_color = cfg.light
	_light_energy = cfg.light_energy
	# light comes from where the sun is drawn in the sky
	var dir: Vector3 = (cfg.sun_dir as Vector3).normalized()
	sun.rotation = Vector3(-asin(clampf(dir.y, 0.55, 0.9)), atan2(-dir.x, -dir.z) + PI * 0.83, 0.0)
	_mote_mat.albedo_color = cfg.motes
	_mote_mat.emission = cfg.motes


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
	_mote_mat = mat
	add_child(_fireflies)


func _process(_delta: float) -> void:
	var pulse := Music.beat_pulse()
	sun.light_energy = _light_energy + pulse * 0.12
	env.glow_intensity = 0.9 + pulse * 0.5
	if camera:
		_fireflies.global_position = camera.global_position + track.forward(player.s) * 25.0
