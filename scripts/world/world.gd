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
const Speech := preload("res://scripts/fx/speech.gd")
const Spawning := preload("res://scripts/fx/spawning.gd")

var track: Track
var player: Salmon
var camera: ChaseCam
var school: School
## The next stage, made out of sight while the salmon swims on down the run-out of the one
## it has finished: see make_next and take_next.
var ahead: Track
## ...and the one just left, kept in the picture behind until the next change.
var behind: Track
var _join := Transform3D.IDENTITY
var _join_s := 0.0
var _water_to := {}
var _water_turning := false
var _water_blend: Tween

var others: School
## The salmon run: a great many more salmon that turn up for a short while and copy the
## player move for move (see start_salmon_run).
var run: School
var _run_left := 0.0
var shoals: Shoals
var sardines: Shoals
var edge_swarm: EdgeSwarm
var visitors: SeaVisitors
var bubbles: CurrentBubbles
## What the salmon says (how well a swipe was timed), in a bubble beside it.
var speech: Speech
## The spawning scene, while it is being played (see spawning_begin).
var spawning: Spawning
var env: Environment
var sun: DirectionalLight3D
var _fireflies: CPUParticles3D
var _rising: CPUParticles3D
var _specks: CPUParticles3D
var _sky: ShaderMaterial
var _mote_mat: StandardMaterial3D
var _light_energy := 1.15
# the haze of the stage as it stands (it turns from one stage's into the next's: see _apply_level)
var _fog_now := Color(0.85, 0.5, 0.55)
var _fog_density_now := 0.0055
var _blend: Tween


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
	run = School.new()
	run.active = 0
	add_child(run)
	run.setup(track, player, 9 if Save.is_mobile() else 16)
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
	speech = Speech.new()
	speech.who = player
	add_child(speech)
	camera = ChaseCam.new()
	camera.near = 0.2
	camera.far = 450.0 if Save.is_mobile() else 900.0
	camera.player = player
	camera.track = track
	school.track = track
	others.track = track
	run.track = track
	run.active = 0
	_run_left = 0.0
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
	_drop(ahead)
	_drop(behind)
	behind = null
	ahead = null


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
	run.track = track
	run.active = 0
	_run_left = 0.0
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
	run.set_look(look)


## `blend` is how many seconds the change takes (0 is at once): swimming from one stage on to
## the next, the sky, the haze and the light turn from the one's into the other's.
func _apply_level(blend := 0.0, of: Dictionary = {}) -> void:
	var cfg := track.cfg if of.is_empty() else of
	_sky.set_shader_parameter("sun_dir", cfg.sun_dir)
	_sky.set_shader_parameter("sun_disc", 1.0 if cfg.get("sun_disc", true) else 0.0)
	# (simple clouds, unless the stage says how many: "clouds", 0 for a clear sky)
	_sky.set_shader_parameter("clouds", float(cfg.get("clouds", 0.32)))
	# light comes from where the sun is drawn in the sky
	var dir: Vector3 = (cfg.sun_dir as Vector3).normalized()
	sun.rotation = Vector3(-asin(clampf(dir.y, 0.55, 0.9)), atan2(-dir.x, -dir.z) + PI * 0.83, 0.0)
	_mote_mat.albedo_color = cfg.motes
	_mote_mat.emission = cfg.motes
	var sky_keys := {"top_color": cfg.sky_top, "horizon_color": cfg.sky_horizon, "bottom_color": cfg.sky_bottom, "sun_color": cfg.sun}
	if _blend:
		_blend.kill()
	if blend <= 0.0:
		for key: String in sky_keys:
			_sky.set_shader_parameter(key, sky_keys[key])
		env.fog_light_color = cfg.fog
		env.fog_density = cfg.fog_density
		env.ambient_light_color = cfg.ambient
		env.ambient_light_energy = cfg.ambient_energy
		sun.light_color = cfg.light
		_light_energy = cfg.light_energy
		_fog_now = cfg.fog
		_fog_density_now = cfg.fog_density
		return
	_blend = create_tween().set_parallel(true)
	for key: String in sky_keys:
		var was: Variant = _sky.get_shader_parameter(key)
		var to: Variant = sky_keys[key]
		if was == null:
			_sky.set_shader_parameter(key, to)
			continue
		# (a sky colour is a Vector3 or a Color, as the stage gave it: both blend the same way)
		_blend.tween_method(func(t: float) -> void: _sky.set_shader_parameter(key, lerp(was, to, t)), 0.0, 1.0, blend)
	_blend.tween_property(self, "_fog_now", cfg.fog, blend)
	_blend.tween_property(self, "_fog_density_now", float(cfg.fog_density), blend)
	_blend.tween_property(env, "ambient_light_color", cfg.ambient, blend)
	_blend.tween_property(env, "ambient_light_energy", float(cfg.ambient_energy), blend)
	_blend.tween_property(sun, "light_color", cfg.light, blend)
	_blend.tween_property(self, "_light_energy", float(cfg.light_energy), blend)


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


func _process(delta: float) -> void:
	# the salmon run runs out, and its salmon go their ways
	if _run_left > 0.0:
		_run_left -= delta
		if _run_left <= 0.0:
			run.active = 0
			for trail in run.wakes:
				trail.visible = false
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
		env.fog_light_color = _fog_now.lerp(murk, under)
		env.fog_density = lerpf(_fog_density_now, track.cfg.get("murk", 0.016), under)
		env.fog_sky_affect = lerpf(0.25, 1.0, under)
		_sky.set_shader_parameter("sun_color", (track.cfg.sun as Color).lerp(murk, under))


## How well the stage is going, from 0 to 1 (from the score): the better, the more life there
## is in the water: more salmon about, and more of the other animals of the sea.
func set_abundance(amount: float) -> void:
	amount = clampf(amount, 0.0, 1.0)
	others.active = 3 + int(roundf((others.get_child_count() - 3) * amount))
	visitors.abundance = amount


## A salmon run: for `seconds`, a crowd of salmon swims in close round the player and copies
## every move it makes.
func start_salmon_run(seconds: float) -> void:
	if _run_left <= 0.0:
		run.active = 999
		run.scatter()
	run.in_step = 1.0
	_run_left = seconds


## How much of the salmon run is left (seconds; 0 when there is none).
func salmon_run_left() -> float:
	return _run_left


# ================================================================== from one stage on to the next

func _drop(old: Track) -> void:
	if old != null and is_instance_valid(old):
		old.queue_free()


## How far ahead of the salmon, at the least, the next stage is joined on (metres): far
## enough to be out in the haze, so that it comes up out of the distance.
const JOIN_AHEAD := 130.0

## Makes the stage that comes next and joins it on to the one being swum, a way ahead of
## the salmon down its run-out: everything of this stage from there on is taken out of the
## picture, and the next begins there, in line with it. The salmon swims on to it (see
## take_next); until then it is still on this one.
func make_next(level: int, down: bool) -> void:
	_drop(ahead)
	_drop(behind)
	behind = null
	_drop(behind)
	behind = null
	_join_s = track.join_after(player.s, JOIN_AHEAD)
	ahead = Track.new()
	ahead.live = false
	add_child(ahead)
	move_child(ahead, 0)
	ahead.build(level, false, down, track.width(_join_s))
	track.hide_from(_join_s)
	var from := track.basis_at(_join_s)
	var at := track.point(_join_s, 0.0, track.water_y(_join_s))
	var turned := from * ahead.basis_at(0.0).inverse()
	_join = Transform3D(turned, at - turned * ahead.point(0.0, 0.0, ahead.water_y(0.0)))
	ahead.transform = _join
	# The water of the two is one water: the next stage's begins as this one's is (its colours,
	# its foam, its swell), and both turn to the next stage's own together (see theme_ahead),
	# so that there is no line across the water where they meet.
	_water_to = {}
	for key: String in Track.WATER_KEYS + ["swell"]:
		_water_to[key] = ahead.mat_water.get_shader_parameter(key)
		ahead.mat_water.set_shader_parameter(key, track.mat_water.get_shader_parameter(key))
	_water_turning = false


## Where the stage being swum ends (metres along it): the salmon goes no further.
func end_s() -> float:
	return track.length - Track.STEP * 2.0


## True once the next stage is made and joined on; and where along this one it begins.
func has_next() -> bool:
	return ahead != null


func join_s() -> float:
	return _join_s


## Turns the sky, the haze and the light to those of the stage ahead.
func theme_ahead() -> void:
	if ahead != null:
		_apply_level(2.5, ahead.cfg)
		_turn_water(2.5)


## The salmon has reached the join: it is on the next stage from here. Everything is
## measured from the new stage now, and the old one is moved to where it lies from there (so
## nothing in the picture moves: only the numbers change).
func take_next() -> void:
	var over := player.s - _join_s
	var was_water := track.water_y(player.s)
	behind = track
	behind.live = false
	var carried := _join.affine_inverse()
	behind.transform = carried
	ahead.transform = Transform3D.IDENTITY
	ahead.clock = behind.clock
	ahead.live = true
	track = ahead
	ahead = null
	_dress_player(track.level, track.down)
	# (if the water has not begun to turn to this stage's yet, it does now)
	if not _water_turning:
		_turn_water(1.5)
	_water_turning = false
	player.track = track
	player.rail = {}
	if player._wake:
		player._wake.clear()
		player._wake.track = track
	player.s = maxf(over, 0.0)
	var lim := track.width(player.s) * 0.5 - 2.0
	player.x = clampf(player.x, -lim, lim)
	# (as far above the water, or under it, as it was: the new stage's water is at a height of
	# its own)
	var lift := track.water_y(player.s) - was_water
	player.y += lift
	player._prev_surface += lift
	for flock: School in [school, others, run]:
		flock.track = track
		flock.carry(_join_s)
	for shoal: Shoals in [shoals, sardines]:
		shoal.track = track
		shoal.scatter()
	edge_swarm.track = track
	visitors.track = track
	visitors.scatter()
	bubbles.track = track
	camera.track = track
	camera.carry(carried)


# Turns the water of the stage being swum, and of the one joined on ahead (or just swum on
# to), to the next stage's own, both together, over `seconds`.
func _turn_water(seconds: float) -> void:
	_water_turning = true
	if _water_blend:
		_water_blend.kill()
	var mats: Array[ShaderMaterial] = [track.mat_water]
	if ahead != null:
		mats.append(ahead.mat_water)
	if behind != null:
		mats.append(behind.mat_water)
	_water_blend = create_tween().set_parallel(true)
	for key: String in _water_to:
		var to: Variant = _water_to[key]
		var was: Variant = mats[0].get_shader_parameter(key)
		if to == null or was == null or typeof(to) != typeof(was):
			continue
		_water_blend.tween_method(func(t: float) -> void:
			for mat in mats:
				if is_instance_valid(mat):
					mat.set_shader_parameter(key, lerp(was, to, t)), 0.0, 1.0, seconds)


## Sets up the spawning scene where the salmon is, under the water, and films it: the
## salmon itself and everything that swims with it are out of the picture meanwhile.
func spawning_begin() -> void:
	spawning_end()
	spawning = Spawning.new()
	add_child(spawning)
	spawning.begin(track, player.s + 6.0, 0.0)
	for node: Node3D in [player, school, others, run, shoals, sardines, edge_swarm, visitors, speech]:
		node.visible = false
	camera.mode = camera.Mode.STAGE
	camera.stage_eye = spawning.eye()
	camera.stage_focus = spawning.focus()
	camera.snap()


func spawning_end() -> void:
	if spawning == null:
		return
	spawning.queue_free()
	spawning = null
	for node: Node3D in [player, school, others, run, shoals, sardines, edge_swarm, visitors]:
		node.visible = true
