extends Node3D
## The 3D world: environment, lights, the course, the salmon and the camera.

const Track := preload("res://scripts/world/track.gd")
const Salmon := preload("res://scripts/player/salmon.gd")
const ChaseCam := preload("res://scripts/world/chase_camera.gd")
const Levels := preload("res://scripts/world/levels.gd")
const School := preload("res://scripts/world/school.gd")
const Shoals := preload("res://scripts/world/shoals.gd")
const EdgeSwarm := preload("res://scripts/world/edge_swarm.gd")
const SeaVisitors := preload("res://scripts/world/sea_visitors.gd")
const CurrentBubbles := preload("res://scripts/world/current_bubbles.gd")

var track: Track
var player: Salmon
var camera: ChaseCam
var school: School
var others: School
var shoals: Shoals
var sardines: Shoals
var edge_swarm: EdgeSwarm
var visitors: SeaVisitors
var bubbles: CurrentBubbles
var env: Environment
var sun: DirectionalLight3D
var _fireflies: CPUParticles3D
var _rising: CPUParticles3D
var _specks: CPUParticles3D
var _sky: ShaderMaterial
var _mote_mat: StandardMaterial3D
var _light_energy := 1.15


func _ready() -> void:
	_make_environment()
	track = Track.new()
	add_child(track)
	track.build(Save.level, false, Save.down)
	player = Salmon.new()
	add_child(player)
	player.setup(track)
	school = School.new()
	add_child(school)
	school.setup(track, player, 6)
	# (and, besides the pack, other salmon about their own business further off)
	others = School.new()
	others.loose = true
	add_child(others)
	others.setup(track, player, 8 if Save.is_mobile() else 16)
	others.active = 3
	shoals = Shoals.new()
	add_child(shoals)
	shoals.setup(track, player, 5 if Save.is_mobile() else 9, 9 if Save.is_mobile() else 14)
	# swarms of sardines under the sea, and the swarm that gathers at its edges
	sardines = Shoals.new()
	sardines.sardines = true
	add_child(sardines)
	sardines.setup(track, player, 3 if Save.is_mobile() else 5, 45 if Save.is_mobile() else 90)
	edge_swarm = EdgeSwarm.new()
	add_child(edge_swarm)
	edge_swarm.setup(track, player, 110 if Save.is_mobile() else 260)
	# turtles, a whale, tuna: each with a chance of being about on a stage of the sea
	visitors = SeaVisitors.new()
	add_child(visitors)
	visitors.setup(track, player)
	# bubbles swept along inside whichever current is near
	bubbles = CurrentBubbles.new()
	add_child(bubbles)
	bubbles.setup(track, player, 30 if Save.is_mobile() else 60)
	camera = ChaseCam.new()
	camera.near = 0.2
	camera.far = 450.0 if Save.is_mobile() else 900.0
	camera.player = player
	camera.track = track
	school.track = track
	others.track = track
	others.scatter()
	school.scatter()
	add_child(camera)
	camera.current = true
	_make_fireflies()
	_make_sea_life()
	_apply_level()
	_dress_player(track.level, track.down)


## Swaps in another level (or the practice course, which borrows the jungle). Rebuilding takes a moment.
func has_course(level: int, test: bool, down := false) -> bool:
	return track.test == test and track.level == (Levels.RAINFOREST if test else level) and track.down == (down and not test)


func set_course(level: int, test: bool, down := false) -> void:
	if test:
		down = false
		level = Levels.RAINFOREST
	_dress_player(level, down)
	if has_course(level, test, down):
		return
	remove_child(track)
	track.queue_free()
	track = Track.new()
	add_child(track)
	move_child(track, 0)
	track.build(level, test, down)
	_apply_level()
	player.track = track
	player.rail = {}
	player.reset(Track.START_S)
	camera.track = track
	school.track = track
	others.track = track
	others.scatter()
	school.scatter()
	shoals.track = track
	sardines.track = track
	sardines.scatter()
	edge_swarm.track = track
	visitors.track = track
	bubbles.track = track
	visitors.scatter()
	shoals.scatter()
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


## The salmon changes with its life. On the way up: silver at sea, turning as it enters fresh
## water, and the red and green of a spawner by the upper river. On the way back down, the
## young: a fry in the lake, a barred parr in the river, a silver smolt by the sea.
func _dress_player(level: int, down: bool) -> void:
	var stage: Dictionary = Levels.LIST[level]
	var tier := int(stage.tier)
	var look := "ocean"
	if down:
		look = "fry" if tier >= 5 else ("parr" if tier >= 3 else "smolt")
	elif not stage.salt:
		look = "spawner" if tier >= 4 else "migrating"
	player.set_look(look)
	school.set_look(look)
	others.set_look(look)


## Sky, fog and light for the level that was just built.
func _apply_level() -> void:
	var cfg := track.cfg
	_sky.set_shader_parameter("top_color", cfg.sky_top)
	_sky.set_shader_parameter("horizon_color", cfg.sky_horizon)
	_sky.set_shader_parameter("bottom_color", cfg.sky_bottom)
	_sky.set_shader_parameter("sun_color", cfg.sun)
	_sky.set_shader_parameter("sun_dir", cfg.sun_dir)
	_sky.set_shader_parameter("sun_disc", 1.0 if cfg.get("sun_disc", true) else 0.0)
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


## What hangs in the water when you are under it: bubbles coming up from the deep, and specks
## adrift. Both are let go in the water ahead of the salmon, since it leaves them behind at
## once.
func _make_sea_life() -> void:
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color = Color(0.85, 0.96, 1.0)
	var bubble := SphereMesh.new()
	bubble.radius = 0.5
	bubble.height = 1.0
	bubble.radial_segments = 6
	bubble.rings = 3
	bubble.material = white
	_rising = CPUParticles3D.new()
	_rising.amount = 22 if Save.is_mobile() else 45
	_rising.lifetime = 2.0
	_rising.local_coords = false
	_rising.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rising.emission_box_extents = Vector3(22, 3, 34)
	_rising.direction = Vector3.UP
	_rising.spread = 12.0
	_rising.initial_velocity_min = 0.8
	_rising.initial_velocity_max = 1.8
	_rising.gravity = Vector3.ZERO
	_rising.scale_amount_min = 0.06
	_rising.scale_amount_max = 0.3
	# (each swells a little as it comes up)
	var swell := Curve.new()
	swell.add_point(Vector2(0.0, 0.5))
	swell.add_point(Vector2(1.0, 1.0))
	_rising.scale_amount_curve = swell
	_rising.mesh = bubble
	_rising.emitting = false
	add_child(_rising)
	var speck := BoxMesh.new()
	speck.size = Vector3.ONE
	var dim := StandardMaterial3D.new()
	dim.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dim.albedo_color = Color(0.75, 0.88, 0.92)
	speck.material = dim
	_specks = CPUParticles3D.new()
	_specks.amount = 40 if Save.is_mobile() else 90
	_specks.lifetime = 2.4
	_specks.local_coords = false
	_specks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_specks.emission_box_extents = Vector3(22, 7, 38)
	_specks.direction = Vector3(1, 0, 0)
	_specks.spread = 180.0
	_specks.initial_velocity_min = 0.05
	_specks.initial_velocity_max = 0.4
	_specks.gravity = Vector3(0, -0.08, 0)
	_specks.scale_amount_min = 0.03
	_specks.scale_amount_max = 0.08
	_specks.mesh = speck
	_specks.emitting = false
	add_child(_specks)


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
	# (the light is steady: flashing it on the beat made the water shimmer, which is hard on
	# the eyes)
	sun.light_energy = _light_energy
	env.glow_intensity = 0.9
	if camera:
		_fireflies.global_position = camera.global_position + track.forward(player.s) * 25.0
		# dived: bubbles and specks in the water ahead, kept under the surface
		var dived: bool = player.dive > 0.3
		_rising.emitting = dived
		_specks.emitting = dived
		var ahead := minf(player.s + 36.0, track.length - 2.0)
		var surface := track.water_y(ahead)
		# (in as much water as there is to dive in: a river has far less of it than the sea)
		var room := track.layers() * track.layer_depth()
		var tall := clampf(room * 0.5 + 1.0, 1.5, 7.0)
		_specks.emission_box_extents.y = tall
		_rising.emission_box_extents.y = minf(tall, 3.0)
		_specks.global_transform = Transform3D(track.basis_at(ahead), track.point(ahead, player.x, minf(player.y, surface - tall - 0.5)))
		_rising.global_transform = Transform3D(track.basis_at(ahead), track.point(ahead, player.x, minf(player.y - 2.0, surface - 3.8 - minf(tall, 3.0))))
		# under the water it is murky, and everything fades into the colour of the water
		var under: float = camera.submerged
		var murk: Color = (track.cfg.get("water_shallow", Color(0.16, 0.7, 0.64)) as Color).lerp(track.cfg.get("water_deep", Color(0.03, 0.3, 0.36)), 0.5)
		env.fog_light_color = (track.cfg.fog as Color).lerp(murk, under)
		env.fog_density = lerpf(track.cfg.fog_density, track.cfg.get("murk", 0.016), under)
		env.fog_sky_affect = lerpf(0.25, 1.0, under)
		_sky.set_shader_parameter("sun_color", (track.cfg.sun as Color).lerp(murk, under))


## How well the stage is going, from 0 to 1 (from the score): the better, the more life there
## is in the water: more salmon about, and more of the other animals of the sea.
func set_abundance(amount: float) -> void:
	amount = clampf(amount, 0.0, 1.0)
	others.active = 3 + int(roundf((others.get_child_count() - 3) * amount))
	visitors.abundance = amount
