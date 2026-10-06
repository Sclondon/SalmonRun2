extends Node3D
## Builds the whole river course: centre-line, water, banks, jungle dressing and the gameplay
## features (ramps, rocks, bamboo rails, rings, bears, waterfalls).
##
## Gameplay code works in "track space": s = distance along the river (metres, horizontal),
## x = lateral offset from the centre (+ is river-right), y = absolute world height.

const MB := preload("res://scripts/util/mesh_builder.gd")
const Props := preload("res://scripts/world/props.gd")
const Bear := preload("res://scripts/world/bear.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const Levels := preload("res://scripts/world/levels.gd")

const STEP := 2.0
const CHUNK := 100
const GROUP_LEN := 400.0
const START_S := 30.0
const RAIL_H := 1.2
## Metres between the knots an ocean current winds through.
const CURRENT_KNOT := 26.0
## Every course meanders: metres from one bend to the left to the next, and how sharply it
## turns at the middle of a bend (radians per metre).
const MEANDER := 250.0
const MEANDER_TURN := 0.012
## On open water it is the trail that wanders, not the course: metres from one swing to the
## next (a long one and a short one), and the steepest it runs across the course.
const TRAIL_LONG := 620.0
const TRAIL_SHORT := 230.0
const TRAIL_SLOPE := 0.22
## A current that ends at the surface throws the salmon into the air: how fast it is going
## along the course by then, and how fast upwards.
const LAUNCH_SPEED := 40.0
const LAUNCH_VY := 14.0
const GRAVITY := 24.0

var length := 3400.0
## The practice level: a short, almost straight river with one of everything, for trying out the controls.
var test := false
## Swum back downstream by the next generation (spring, and the falls drop away again).
var down := false
var course_seed := 1987
## Which stage of the journey this is (index into Levels.LIST) and its settings.
var level := Levels.RAINFOREST
var cfg: Dictionary = Levels.LIST[Levels.RAINFOREST]

var n := 0
var pts := PackedVector3Array()
var heads := PackedFloat32Array()
var widths := PackedFloat32Array()
var finish_s := 0.0

var waterfalls: Array = []   # {s, drop}
var rapids: Array = []       # {s0, s1}
var pools: Array = []        # {s0, s1}
var ramps: Array = []        # {s, x, w, len, h}
var rocks: Array = []        # {s, x, r}
var rails: Array = []        # {s0, s1, x0, x1}
var currents: Array = []     # {s0, s1, xs, ds, off}: see current_x()
var jellies: Array = []      # {s, x, d, node}: d is metres under the surface
## Boost rings swum through since the salmon last looked (it sets this back to 0).
var surge := 0
var rings: Array = []        # {s, x, h, ref, pos, node, taken}
var bears: Array = []        # {s, x, node}

## The fork near the end of a stage whose way on divides (and which has a "divider"): a great
## obstacle down the middle of the course, with one way on to its left (the default) and one
## to its right (the advanced, shut by a boom until the stage's goal is met). {s0, s1: where
## the divider lies; boom: where its boom begins; ways: the stage each side leads to}. Empty
## where there is none.
var fork := {}
var fork_open := true
## Set once the salmon has passed the bow: the way is chosen, and nothing changes after.
var fork_locked := false
const FORK_BEAM := 11.0
var _boom: Node3D
var _fork_signs: Array[Label3D] = []
var _fork_set := false

var mat_world: ShaderMaterial
var mat_foliage: ShaderMaterial
var mat_water: ShaderMaterial
## The water of each stage as set by hand in the water lab (ui/water_lab.gd): the name of
## the stage -> {uniform: value}. They are kept in the project (PRESETS), so that they go
## out with the game; read_presets() fetches them and write_presets() puts them back.
static var water_presets := {}
static var _presets_read := false
const PRESETS := "res://materials/water_presets.cfg"
## The water every stage starts from: a material that can be opened and changed in the editor
## (scenes/water_scene.tscn shows a patch of sea with it). A stage's own "water_..." settings
## and its preset from the water lab go on top of it.
const WATER := preload("res://materials/water.tres")
const FOAM := preload("res://textures/foam_noise.png")
## Every setting the lab can change (put back to the material's own before a stage's are applied).
const WATER_KEYS := ["deep", "shallow", "foam_color", "depth_range", "alpha_shallow", "alpha_deep", "colour_ripple", "view_clear",
		"foam_amount", "foam_scale", "foam_speed", "edge_foam", "rapid_foam", "rim_width", "rim_ragged",
		"whitecaps", "whitecap_size", "whitecap_clump", "whitecap_clump_size", "crest_amount", "crest_size", "crest_ragged",
		"swell_height", "swell_length", "swell_speed",
		"roughness", "specular", "lines", "ripple_scale", "ripple_height", "ripple_choppy", "ripple_speed", "glint_pixels",
		"wake_spread", "wake_width", "wake_wiggle", "wake_wiggle_length", "wake_ragged", "wake_dashes", "wake_churn",
		"wake_echo", "wake_calm"]
## How long the salmon's wake lasts (seconds) where a stage's preset does not say.
const WAKE_LIFE := 0.45
var wake_life := WAKE_LIFE

var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _ring_root: Node3D


func build(level_index := Levels.RAINFOREST, test_level := false, downstream := false) -> void:
	down = downstream
	level = level_index
	cfg = Levels.settings(level)
	if down and cfg.has("spring"):
		cfg.merge(cfg.spring, true)
	length = cfg.length
	test = test_level
	course_seed = int(cfg.seed) + (500 if down else 0)
	_rng.seed = course_seed
	_noise.seed = course_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	_noise.frequency = 1.0
	_make_materials()
	fork = {}
	if not test and not down and cfg.has("divider") and Levels.next_of(level).size() > 1:
		var end := length - 150.0
		fork = {"s0": end - 140.0, "s1": end - 8.0, "boom": end - 250.0, "ways": Levels.next_of(level)}
	if test:
		_plan_test()
	else:
		_plan_features()
	_build_centreline()
	_build_chunks()
	_build_features()
	_scatter()


func _make_materials() -> void:
	mat_world = ShaderMaterial.new()
	mat_world.shader = preload("res://shaders/psx.gdshader")
	mat_foliage = ShaderMaterial.new()
	mat_foliage.shader = mat_world.shader
	mat_foliage.set_shader_parameter("wind", 1.0)
	# (a copy of the water set up by hand in scenes/water_scene.tscn: see WATER)
	mat_water = WATER.duplicate()
	# (the material may have been saved without its foam picture: it needs one)
	if mat_water.get_shader_parameter("foam_texture") == null:
		mat_water.set_shader_parameter("foam_texture", FOAM)
	apply_water()


## Sets the water to the water material's own settings, then to what the stage asks for, and
## then to the stage's preset from the water lab (see water_presets).
func apply_water() -> void:
	for key: String in WATER_KEYS:
		mat_water.set_shader_parameter(key, WATER.get_shader_parameter(key))
	# any "water_<name>" in the stage's settings sets the water shader's <name>
	for key: String in cfg:
		if key.begins_with("water_"):
			mat_water.set_shader_parameter(key.trim_prefix("water_"), cfg[key])
	mat_water.set_shader_parameter("swell", cfg.swell)
	# (how many metres the water's mapping runs across: see _water_mesh)
	mat_water.set_shader_parameter("across", 26.8 if float(cfg.width) > 40.0 else float(cfg.width) + 1.6)
	# upstream, the river runs towards you
	mat_water.set_shader_parameter("flow", -0.6 if uphill() else 0.6)
	var preset := water_preset()
	for key: String in preset:
		if key != "wake_life":
			mat_water.set_shader_parameter(key, preset[key])
	wake_life = float(preset.get("wake_life", WAKE_LIFE))
	# the same swell here as the shader has, for whatever floats on it (see swell_y)
	var rough := float(_water_value("swell", cfg.swell))
	_swell_high = float(_water_value("swell_height", SWELL_HEIGHT)) * rough
	_swell_long = maxf(float(_water_value("swell_length", SWELL_LENGTH)) * (0.4 + 0.6 * rough), 0.5)
	_swell_speed = float(_water_value("swell_speed", 1.0))


func _water_value(key: String, otherwise: Variant) -> Variant:
	var value: Variant = mat_water.get_shader_parameter(key)
	return otherwise if value == null else value


## This stage's preset from the water lab: {uniform: value}, to read or to change.
func water_preset() -> Dictionary:
	read_presets()
	var stage := str(cfg.name)
	if not water_presets.has(stage):
		water_presets[stage] = {}
	return water_presets[stage]


static func read_presets() -> void:
	if _presets_read:
		return
	_presets_read = true
	var file := ConfigFile.new()
	if file.load(PRESETS) != OK:
		return
	for stage: String in file.get_sections():
		var preset := {}
		for key: String in file.get_section_keys(stage):
			preset[key] = file.get_value(stage, key)
		water_presets[stage] = preset


## Writes every stage's preset back into the project. (Only where the game is run from the
## project itself, as on the desktop it is made on: a game that has been exported cannot.)
static func write_presets() -> bool:
	if not OS.has_feature("editor"):
		return false
	var file := ConfigFile.new()
	for stage: String in water_presets:
		var preset: Dictionary = water_presets[stage]
		var keys := preset.keys()
		keys.sort()
		for key: String in keys:
			file.set_value(stage, key, preset[key])
	return file.save(PRESETS) == OK


# ================================================================== the fork

## How wide the divider is to either side of the middle at `s` (0 where there is none).
func fork_half(s: float) -> float:
	if fork.is_empty() or s < float(fork.s0) or s > float(fork.s1):
		return 0.0
	# (a sharp bow, and a stern drawn in a little)
	var bow := sqrt(clampf((s - float(fork.s0)) / 40.0, 0.0, 1.0))
	var stern := lerpf(0.75, 1.0, clampf((float(fork.s1) - s) / 14.0, 0.0, 1.0))
	return FORK_BEAM * bow * stern


## Where the salmon may be across the water at `s`, wanting to be at `x`: not inside the
## divider, and (while the advanced way is shut) not on the far side of its boom.
func fork_keep(s: float, x: float) -> float:
	if fork.is_empty():
		return x
	var half := fork_half(s)
	if half > 0.0:
		var lim := half + 1.3
		if not fork_open:
			return minf(x, -lim)
		if absf(x) < lim:
			return lim if x >= 0.0 else -lim
	elif not fork_open and s > float(fork.boom) and s <= float(fork.s0):
		var t := (s - float(fork.boom)) / (float(fork.s0) - float(fork.boom))
		return minf(x, lerpf(width(s) * 0.5, -1.3, t) - 1.0)
	return x


## Opens or shuts the advanced way (the right-hand side of the divider): the boom of buoys
## across it, and what its sign says. Once the salmon has gone by, it stays as it was.
func set_fork_open(open: bool) -> void:
	if fork.is_empty() or fork_locked or (open == fork_open and _fork_set):
		return
	_fork_set = true
	fork_open = open
	_boom.visible = not open
	var ways: Array = fork.ways
	_fork_signs[1].text = str(Levels.LIST[ways[1]].name) if open else "CLOSED\n%s" % Levels.objective_text(level)
	_fork_signs[1].modulate = Color(1.0, 0.95, 0.6) if open else Color(1.0, 0.45, 0.4)


# The divider (a cruise ship lying along the middle of the course), the signs over the two
# ways round it, and the boom of buoys that shuts the right-hand way.
func _build_fork() -> void:
	var s0: float = fork.s0
	var s1: float = fork.s1
	var mb := MB.new()
	var hull := Color(0.96, 0.96, 0.94)
	var keel := Color(0.1, 0.16, 0.34)
	var deck_h := 9.0
	# the hull, a slice at a time, following the course
	var prev: Array = []
	var s := s0
	while s <= s1 + 0.01:
		var half := maxf(fork_half(s), 0.15)
		var wy := water_y(s)
		var row := [point(s, -half, wy - 2.5), point(s, -half, wy + 1.6), point(s, -half - 0.9, wy + deck_h),
				point(s, half + 0.9, wy + deck_h), point(s, half, wy + 1.6), point(s, half, wy - 2.5)]
		if not prev.is_empty():
			var mid := (row[2] as Vector3).lerp(prev[3], 0.5) - Vector3.UP * 4.0
			for j in 5:
				var col := keel if j == 0 or j == 4 else (Props.shade(hull, 1.08) if j == 2 else hull)
				mb.quad(prev[j], row[j], row[j + 1], prev[j + 1], col, ((row[j] as Vector3) + (prev[j + 1] as Vector3)) * 0.5 - mid)
		prev = row
		s += 5.0
	# (closed at the stern)
	mb.quad(prev[1], prev[2], prev[3], prev[4], hull, center(s1 + 5.0) - center(s1))
	# the decks above it: three tiers of cabins, each shorter than the one under it, with a
	# dark band of windows round each, and two funnels
	var mid_s := lerpf(s0, s1, 0.56)
	var b := basis_at(mid_s)
	var base := point(mid_s, 0.0, water_y(mid_s) + deck_h)
	var long := s1 - s0
	for tier in 3:
		var size := Vector3(FORK_BEAM * 2.0 - 3.0 - tier * 3.0, 3.2, long * (0.66 - tier * 0.12))
		var c := base + Vector3.UP * (1.6 + tier * 3.2)
		Props.box(mb, c, size, hull, null, 0.0, b)
		Props.box(mb, c + Vector3.UP * 0.3, Vector3(size.x + 0.12, 1.1, size.z - 1.5), Color(0.1, 0.2, 0.36), null, 0.0, b)
		Props.box(mb, c + Vector3.UP * 1.75, Vector3(size.x + 1.0, 0.3, size.z + 1.0), Props.shade(hull, 0.9), null, 0.0, b)
	for k in 2:
		var at := base + b * Vector3(0.0, 13.0, -8.0 + k * 16.0)
		Props.box(mb, at, Vector3(5.0, 7.0, 6.0), Color(0.86, 0.2, 0.16), null, 0.0, b)
		Props.box(mb, at + Vector3.UP * 3.9, Vector3(5.3, 1.2, 6.3), Color(0.12, 0.12, 0.14), null, 0.0, b)
	# a row of lifeboats down each side
	for k in 6:
		for side: float in [-1.0, 1.0]:
			var ls := lerpf(s0 + long * 0.3, s1 - long * 0.12, k / 5.0)
			Props.box(mb, point(ls, side * (fork_half(ls) + 0.2), water_y(ls) + deck_h + 1.0), Vector3(1.6, 1.3, 5.0), Color(0.95, 0.5, 0.12), null, 0.0, basis_at(ls))
	_add_mesh(mb.build(), mat_world)
	# the signs: the way each side leads, over the water ahead of the bow
	var ways: Array = fork.ways
	_fork_signs.clear()
	for k in 2:
		var label := Label3D.new()
		label.font = UI.font()
		label.font_size = 96
		label.pixel_size = 0.085
		label.outline_size = 26
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.text = str(Levels.LIST[ways[k]].name)
		label.modulate = Color(1.0, 0.95, 0.6)
		label.outline_modulate = Color(0.05, 0.08, 0.2)
		label.position = point(s0 + 12.0, (-1.0 if k == 0 else 1.0) * width(s0) * 0.25, water_y(s0) + 15.0)
		add_child(label)
		_fork_signs.append(label)
	# the boom: a line of red buoys from the right-hand edge of the water to the bow
	_boom = Node3D.new()
	add_child(_boom)
	var brng := RandomNumberGenerator.new()
	brng.seed = course_seed + 77
	var buoy := Props.buoy(brng, Color(0.85, 0.12, 0.1), Color(1.0, 0.3, 0.2))
	var boom_s: float = fork.boom
	var count := 34
	for k in count + 1:
		var t := float(k) / count
		var bs := lerpf(boom_s, s0, t)
		var mi := MeshInstance3D.new()
		mi.mesh = buoy
		mi.material_override = mat_world
		mi.scale = Vector3.ONE * 2.2
		mi.position = point(bs, lerpf(width(bs) * 0.5, 0.0, t), water_y(bs))
		_boom.add_child(mi)
	_fork_set = false
	set_fork_open(true)


# ================================================================== queries

func _fi(s: float) -> float:
	return clampf(s / STEP, 0.0, n - 1.001)


func center(s: float) -> Vector3:
	var f := _fi(s)
	var i := int(f)
	return pts[i].lerp(pts[i + 1], f - i)


func water_y(s: float) -> float:
	var f := _fi(s)
	var i := int(f)
	return lerpf(pts[i].y, pts[i + 1].y, f - i)


func heading(s: float) -> float:
	var f := _fi(s)
	var i := int(f)
	return lerpf(heads[i], heads[i + 1], f - i)


func width(s: float) -> float:
	var f := _fi(s)
	var i := int(f)
	return lerpf(widths[i], widths[i + 1], f - i)


func forward(s: float) -> Vector3:
	var h := heading(s)
	return Vector3(sin(h), 0.0, -cos(h))


func right(s: float) -> Vector3:
	var h := heading(s)
	return Vector3(cos(h), 0.0, sin(h))


## Rotation whose -Z points downstream.
func basis_at(s: float) -> Basis:
	return Basis(Vector3.UP, -heading(s))


func point(s: float, x: float, y: float) -> Vector3:
	var c := center(s) + right(s) * x
	c.y = y
	return c


## Where a point of the course is across the water's mapping (UV.x): see _water_mesh.
func water_u(s: float, x: float) -> float:
	if float(cfg.width) > 40.0:
		return 0.5 + x / 26.8
	return 0.5 + x / (width(s) + 1.6)


## The swell: four trains of waves crossing one another, each (which way it runs across and
## along, how long it is beside the longest, and how high beside the highest). The water
## shader has the same four (swell_at in shaders/water.gdshader) and lifts the water's mesh
## by them; this is for whatever floats on it.
const SWELLS := [[0.34, -0.94, 1.0, 1.0], [-0.78, -0.62, 0.62, 0.55], [0.97, 0.26, 0.37, 0.3], [-0.57, 0.82, 0.23, 0.16]]
## What the shader's swell uniforms are when nothing sets them.
const SWELL_HEIGHT := 0.18
const SWELL_LENGTH := 12.0

## Seconds since the stage was made: the swell's clock (the shader is sent it every frame,
## as the project's water_clock).
var clock := 0.0
var _swell_high := 0.0
var _swell_long := 12.0
var _swell_speed := 1.0


## How far the swell has lifted the water at (s, x) just now.
func swell_y(s: float, x: float) -> float:
	if _swell_high <= 0.0:
		return 0.0
	var h := 0.0
	for i in SWELLS.size():
		var w: Array = SWELLS[i]
		var k := TAU / (_swell_long * float(w[2]))
		h += _swell_high * float(w[3]) * sin(k * (float(w[0]) * x + float(w[1]) * s) - sqrt(9.8 * k) * _swell_speed * clock + i * 1.7)
	return h


## The highest the swell ever lifts the water (metres).
func swell_top() -> float:
	return _swell_high * 2.01


func surface_y(s: float, x: float) -> float:
	return water_y(s) + ramp_height(s, x)


func ramp_height(s: float, x: float) -> float:
	for r: Dictionary in ramps:
		var d: float = s - r.s
		if d >= 0.0 and d <= r.len and absf(x - r.x) <= r.w * 0.5:
			return r.h * d / r.len
	return 0.0


func rail_x(r: Dictionary, s: float) -> float:
	return lerpf(r.x0, r.x1, clampf((s - r.s0) / (r.s1 - r.s0), 0.0, 1.0))


## How many layers there are to dive to under the surface, and how far apart they are.
func layers() -> int:
	return int(cfg.get("layers", 1))


func layer_depth() -> float:
	return float(cfg.get("layer_depth", 1.7))


## An ocean current is a rail under the water that winds about: where it is across the course
## at s, and how far under the surface (metres). Both are smooth curves through its knots.
func current_x(c: Dictionary, s: float) -> float:
	return float(c.off) + _spline(c.xs, (s - float(c.s0)) / CURRENT_KNOT)


## How wide a current is at `s` (its radius, metres): as wide as it was made, but drawn in
## where it comes near the surface, so as to stay under it.
func current_radius(c: Dictionary, s: float) -> float:
	return minf(float(c.get("r", 1.25)), maxf(current_depth(c, s) - 0.3, 1.6))


func current_depth(c: Dictionary, s: float) -> float:
	return maxf(_spline(c.ds, (s - float(c.s0)) / CURRENT_KNOT), 0.0) * layer_depth()


func _spline(knots: PackedFloat32Array, f: float) -> float:
	var last := knots.size() - 1
	f = clampf(f, 0.0, float(last))
	var i := mini(int(f), last - 1)
	return cubic_interpolate(knots[i], knots[i + 1], knots[maxi(i - 1, 0)], knots[mini(i + 2, last)], f - i)


## A stage with a "shore" has land on that side only (-1 is the left, 1 the right) and open
## sea on the other.
func is_sea_side(side: float) -> bool:
	return cfg.has("shore") and signf(side) != signf(float(cfg.shore))


## Returns the (x, y-above-water) profile of one bank, from the water's edge outwards.
func bank_profile(s: float, side: float) -> PackedVector2Array:
	var hw := width(s) * 0.5
	var k := side * 100.0
	var n1 := _noise.get_noise_2d(s * 0.03, k)
	var n2 := _noise.get_noise_2d(s * 0.008, k + 30.0)
	var out := PackedVector2Array()
	for p: Array in (SEA_PROFILE if is_sea_side(side) else cfg.profile):
		out.append(Vector2(hw + float(p[0]), float(p[1]) + n1 * float(p[2]) + n2 * float(p[3])))
	return out


## World height of the bank at lateral distance |x| = dist on the given side.
func bank_y(s: float, side: float, dist: float) -> float:
	var prof := bank_profile(s, side)
	var y := prof[prof.size() - 1].y
	for j in prof.size() - 1:
		if dist <= prof[j + 1].x:
			var t := clampf((dist - prof[j].x) / (prof[j + 1].x - prof[j].x), 0.0, 1.0)
			y = lerpf(prof[j].y, prof[j + 1].y, t)
			break
	return water_y(s) + y


func near_fall(s: float, before: float, after: float) -> bool:
	for wf: Dictionary in waterfalls:
		if s > wf.s - before and s < wf.s + after:
			return true
	return false


## Collects rings near `pos`; returns how many were collected this call.
func collect_rings(pos: Vector3) -> int:
	var got := 0
	for r: Dictionary in rings:
		if r.taken:
			continue
		var rp: Vector3 = r.pos
		if rp.distance_squared_to(pos) < 2.4 * 2.4:
			r.taken = true
			(r.node as Node3D).visible = false
			got += 1
			if r.get("boost", false):
				surge += 1
	return got


func reset_rings() -> void:
	for r: Dictionary in rings:
		r.taken = false
		(r.node as Node3D).visible = true


func _process(delta: float) -> void:
	clock += delta
	RenderingServer.global_shader_parameter_set("water_clock", clock)
	if _ring_root == null:
		return
	var pulse := Music.beat_pulse()
	var t := Time.get_ticks_msec() / 1000.0
	for r: Dictionary in rings:
		if r.taken:
			continue
		var node: Node3D = r.node
		node.scale = Vector3.ONE * (1.0 + pulse * 0.25)
		node.position.y = (r.pos as Vector3).y + sin(t * 2.0 + r.s * 0.1) * 0.15
	# sea nettles pulse, and drift up and down a little
	for j: Dictionary in jellies:
		var beat := sin(t * 2.6 + float(j.s))
		var node: Node3D = j.node
		node.scale = Vector3(1.0 - beat * 0.09, 1.0 + beat * 0.14, 1.0 - beat * 0.09) * 1.25
		node.position.y = float(j.y) + sin(t * 0.9 + float(j.s) * 0.3) * 0.25


# ================================================================== planning

func _plan_features() -> void:
	var s := 230.0
	var since_fall := 0.0
	var kinds: Array = cfg.kinds
	var falls_every: float = cfg.falls_every
	var last := ""
	var room := lane_room()
	# (nothing is laid where the fork is)
	while s < length - (450.0 if not fork.is_empty() else 320.0):
		var kind: String
		if falls_every > 0.0 and since_fall > falls_every:
			kind = "bear_falls" if _rng.randf() < 0.5 else "falls"
		else:
			kind = kinds[_rng.randi() % kinds.size()]
			if kind == last:
				kind = kinds[(kinds.find(kind) + 1) % kinds.size()]
		last = kind
		var used := 0.0
		var from := {"ramps": ramps.size(), "rocks": rocks.size(), "rings": rings.size(), "bears": bears.size(), "rails": rails.size(), "currents": currents.size(), "jellies": jellies.size()}
		match kind:
			"falls", "bear_falls":
				used = _plan_falls(s, kind == "bear_falls")
				since_fall = -used
			"ramps":
				used = _plan_ramps(s)
			"rails":
				used = _plan_rails(s)
			"rocks":
				used = _plan_rocks(s)
			"rings":
				used = _plan_ring_trail(s)
			"surge":
				used = _plan_surge(s)
			"jellies":
				used = _plan_jellies(s)
			"currents":
				used = _plan_current(s, false)
			"predators":
				used = _plan_predators(s)
		if room > 0.0:
			_slide(from, 0)
		var gap := _rng.randf_range(45.0, 80.0) * float(cfg.get("spacing", 1.0))
		s += used + gap
		since_fall += used + gap
	finish_s = length - 150.0
	_fit_to_river()
	_plan_deep()


## Every piece is laid out for a river some 20 m across. In a narrower one they are all drawn
## in towards the middle, so that nothing is left in the bank.
func _fit_to_river() -> void:
	var k := clampf((float(cfg.width) * 0.5 - 2.6) / 7.4, 0.5, 1.0)
	if k >= 1.0:
		return
	for list: Array in [ramps, rocks, rings, bears]:
		for piece: Dictionary in list:
			piece.x = float(piece.x) * k
	for r: Dictionary in rails:
		r.x0 = float(r.x0) * k
		r.x1 = float(r.x1) * k


## What is under the sea is laid out on its own, from one end of the course to the other,
## whatever is on the surface above it: the things in the stage's "deep" list, in turn.
func _plan_deep() -> void:
	var deep: Array = cfg.get("deep", [])
	if deep.is_empty():
		return
	var s := 260.0
	var k := 0
	while s < length - 480.0:
		var from := {"ramps": ramps.size(), "rocks": rocks.size(), "rings": rings.size(), "bears": bears.size(), "rails": rails.size(), "currents": currents.size(), "jellies": jellies.size()}
		var used := 0.0
		match str(deep[k % deep.size()]):
			"currents":
				used = _plan_current(s, false)
			"launch":
				used = _plan_current(s, true)
			"rings":
				used = _plan_deep_rings(s)
			"surge":
				used = _plan_surge(s)
			"jellies":
				used = _plan_jellies(s)
		k += 1
		_slide(from, 1)
		s += used + _rng.randf_range(30.0, 70.0)


## How far the pieces of a very wide course can be moved off its middle (0 on a river).
func lane_room() -> float:
	return maxf(float(cfg.width) * 0.5 - 16.0, 0.0)


## Every piece is laid out round the middle of the course, as a river needs. Open water far
## wider than a river runs straight, and it is the trail of things to swim for that wanders
## from side to side across it: each thing is moved over to where the trail is at that point.
## (lane 0 is the trail on the surface, 1 the one under the sea, which goes its own way.)
func _slide(from: Dictionary, lane: int) -> void:
	for i in range(int(from.ramps), ramps.size()):
		ramps[i].x = float(ramps[i].x) + trail_x(ramps[i].s, lane)
	for i in range(int(from.rocks), rocks.size()):
		rocks[i].x = float(rocks[i].x) + trail_x(rocks[i].s, lane)
	for i in range(int(from.rings), rings.size()):
		# (rings in the air stay in line with the leap that goes through them)
		rings[i].x = float(rings[i].x) + trail_x(rings[i].ref, lane)
	for i in range(int(from.bears), bears.size()):
		bears[i].x = float(bears[i].x) + trail_x(bears[i].s, lane)
	for i in range(int(from.rails), rails.size()):
		rails[i].x0 = float(rails[i].x0) + trail_x(rails[i].s0, lane)
		rails[i].x1 = float(rails[i].x1) + trail_x(rails[i].s1, lane)
	for i in range(int(from.currents), currents.size()):
		var c: Dictionary = currents[i]
		var xs: PackedFloat32Array = c.xs
		for k in xs.size():
			xs[k] += trail_x(float(c.s0) + CURRENT_KNOT * k, lane)
		c.xs = xs
	for i in range(int(from.jellies), jellies.size()):
		jellies[i].x = float(jellies[i].x) + trail_x(jellies[i].s, lane)


## Where the trail is across open water at s: a long swing from side to side with a shorter
## one on top, never steeper than the salmon can comfortably steer.
func trail_x(s: float, lane := 0) -> float:
	var room := lane_room()
	if room <= 0.0:
		return 0.0
	var phase := float(int(cfg.seed) % 100) * 0.063 + lane * 2.1
	var wide := minf(room * 0.7, TRAIL_SLOPE * TRAIL_LONG / TAU)
	var narrow := minf(room * 0.25, TRAIL_SLOPE * 0.4 * TRAIL_SHORT / TAU)
	# (it starts from the middle, where the salmon does)
	return (wide * sin(s * TAU / TRAIL_LONG + phase) + narrow * sin(s * TAU / TRAIL_SHORT + phase * 1.7)) * smoothstep(150.0, 400.0, s)


## Fixed layout, in the order you'd want to learn things: steer, jump, ramps, a rail,
## rocks, a waterfall.
func _plan_test() -> void:
	length = 1500.0
	finish_s = length - 150.0
	_fit_to_river()
	_plan_deep()
	# steering: a ring slalom on the water that gets wider
	for k in 18:
		var rs := 110.0 + k * 13.0
		rings.append({"s": rs, "x": (3.0 + k * 0.25) * sin(k * 0.6), "h": 0.7, "ref": rs})
	# jumping: rings to leap through on open water
	for k in 4:
		var rs := 390.0 + k * 38.0
		rings.append({"s": rs, "x": 0.0, "h": 3.2, "ref": rs})
	# ramps: one in the middle, then a pair
	ramps.append({"s": 560.0, "x": 0.0, "w": 7.0, "len": 9.0, "h": 2.8})
	ramps.append({"s": 640.0, "x": -5.0, "w": 5.0, "len": 9.0, "h": 3.2})
	ramps.append({"s": 640.0, "x": 5.0, "w": 5.0, "len": 9.0, "h": 3.2})
	# a ramp onto a bamboo rail, and a second rail you can swim straight onto
	ramps.append({"s": 730.0, "x": -3.0, "w": 5.0, "len": 9.0, "h": 2.6})
	rails.append({"s0": 750.0, "s1": 815.0, "x0": -3.0, "x1": 0.0})
	rails.append({"s0": 765.0, "s1": 810.0, "x0": 5.0, "x1": 5.0})
	# a few rocks to weave through
	for k in 7:
		rocks.append({"s": 880.0 + k * 16.0, "x": (5.0 if k % 2 == 0 else -4.0) + sin(k * 2.1) * 2.0, "r": 1.3})
	# a small waterfall with rings along the arc
	waterfalls.append({"s": 1060.0, "drop": 3.2 if uphill() else 9.0})
	pools.append({"s0": 1062.0, "s1": 1130.0})
	_fall_rings(1060.0, 0.0)
	# and a big ramp to finish
	ramps.append({"s": 1220.0, "x": 0.0, "w": 8.0, "len": 10.0, "h": 3.6})


func _plan_falls(s: float, with_bear: bool) -> float:
	var lip := s + 40.0
	var drop := _rng.randf_range(9.0, 20.0)
	if uphill():
		# heading upstream the falls are steps to leap up, so they have to be jumpable
		drop = remap(drop, 9.0, 20.0, 2.6, 4.0)
	waterfalls.append({"s": lip, "drop": drop})
	pools.append({"s0": lip + 2.0, "s1": lip + 70.0})
	_fall_rings(lip, _rng.randf_range(-4.0, 4.0))
	if with_bear and cfg.predator != "":
		# never where you have to take off or land
		bears.append({"s": lip + 32.0 if uphill() else lip - 6.0, "x": _rng.randf_range(-3.0, 3.0), "off": 0.0})
		bears.append({"s": lip + 58.0, "x": 9.0 * (1.0 if _rng.randf() < 0.5 else -1.0), "off": 1.0})
	return 110.0


## Rings along the jump: up and over the falls going upstream, off the lip going down.
func _fall_rings(lip: float, side: float) -> void:
	if uphill():
		rings.append({"s": lip - 11.0, "x": side, "h": 3.2, "ref": lip - 3.0})
		rings.append({"s": lip - 4.0, "x": side, "h": 4.6, "ref": lip - 3.0})
		rings.append({"s": lip + 8.0, "x": side, "h": 1.4, "ref": lip + 3.0})
		return
	for k in 3:
		var t := 0.3 + 0.28 * k
		rings.append({"s": lip + 34.0 * t, "x": side, "h": 1.5 + 11.0 * t - 12.0 * t * t, "ref": lip - 1.0})


## What the arch at the end says: where this leg of the journey is heading.
func _finish_text() -> String:
	if test:
		return "ONE MORE LAP"
	if down:
		return "THE OPEN OCEAN" if int(cfg.tier) == 0 else "DOWNSTREAM"
	return "SPAWNING GROUNDS" if Levels.is_end(level) else "UPSTREAM"


## True when this level is swum upstream: the water climbs and waterfalls are leapt up.
func uphill() -> bool:
	return cfg.get("uphill", false) and not down


## Where the face of a waterfall starts (it is one STEP long).
func fall_base(wf: Dictionary) -> float:
	return floorf(float(wf.s) / STEP) * STEP


## Two predators with rings over their heads for anyone brave enough to jump them: bears in
## the rivers, snapping on alternate beats; sharks at sea, swimming to and fro across the
## way, the first at the surface and the second somewhere under it.

func _plan_predators(s: float) -> float:
	if cfg.predator == "":
		return _plan_ring_trail(s)
	for k in 2:
		var ps := s + 30.0 + k * 34.0
		var px := _rng.randf_range(-5.0, 5.0)
		bears.append({"s": ps, "x": px, "off": float(k), "d": 0.5 if k == 0 else layer_depth() * _rng.randi_range(1, layers())})
		rings.append({"s": ps, "x": px, "h": 4.6, "ref": ps})
	return 95.0


func _plan_ramps(s: float) -> float:
	var count := _rng.randi_range(1, 3)
	var side_by_side := count == 2 and _rng.randf() < 0.5
	for i in count:
		var rs := s if side_by_side else s + i * 48.0
		var rx := (-5.0 if i == 0 else 5.0) if side_by_side else _rng.randf_range(-6.0, 6.0)
		var h := _rng.randf_range(2.2, 3.4)
		var rl := 9.0
		ramps.append({"s": rs, "x": rx, "w": 5.0, "len": rl, "h": h})
		var vy := 32.0 * h / rl + 8.0
		for k in 2:
			var t := 0.35 + 0.4 * k
			rings.append({"s": rs + rl + 32.0 * t, "x": rx, "h": h + vy * t - 12.0 * t * t, "ref": rs})
	return (48.0 if side_by_side else count * 48.0) + 20.0


func _plan_rails(s: float) -> float:
	var rx := _rng.randf_range(-5.0, 5.0)
	# (where there are no ramps, both rails are ones to swim straight onto)
	if cfg.get("ramps", true):
		ramps.append({"s": s, "x": rx, "w": 5.0, "len": 9.0, "h": 2.6})
	var r_len := _rng.randf_range(45.0, 75.0)
	rails.append({"s0": s + 20.0, "s1": s + 20.0 + r_len, "x0": rx, "x1": clampf(rx + _rng.randf_range(-4.0, 4.0), -7.0, 7.0)})
	if _rng.randf() < 0.6:
		# a second, lower-entry rail you can swim straight onto
		var x2 := -rx if absf(rx) > 2.5 else rx + 6.0
		rails.append({"s0": s + 35.0, "s1": s + 35.0 + r_len * 0.7, "x0": x2, "x1": x2})
	return r_len + 30.0


## A current under the sea: it starts near the top (a dive or two from the surface catches
## it), winds from side to side and down and up through every layer there is, and ends at
## whatever depth it has got to. Or it is a launch: it ends by rising to the surface, and
## throws the salmon into the air.
func _plan_current(s: float, launch: bool) -> float:
	var count := _rng.randi_range(6, 9)
	var xs := PackedFloat32Array()
	var ds := PackedFloat32Array()
	var cx := _rng.randf_range(-4.0, 4.0)
	var deepest := layers()
	var depth := _rng.randi_range(1, mini(deepest, 2))
	# (it makes for the bottom first, or it would hang about near the top)
	var aim := deepest
	for k in count + 1:
		# (straight and level at the start, so that it is easy to get on)
		if k > 1:
			if k < count:
				cx = clampf(cx + _rng.randf_range(5.0, 11.0) * (1.0 if _rng.randf() < 0.5 else -1.0), -15.0, 15.0)
			if depth == aim:
				aim = _rng.randi_range(1, deepest)
			# (no more than two layers between one knot and the next: more is too steep)
			depth += clampi(aim - depth, -2, 2)
		xs.append(cx)
		ds.append(float(depth))
	var start := s + 25.0
	var end := start + CURRENT_KNOT * count
	if launch:
		# the climb to the surface at the end is no steeper than the rest
		ds[count] = 0.0
		ds[count - 1] = minf(ds[count - 1], 2.0)
		ds[count - 2] = minf(ds[count - 2], 4.0)
		# rings in the air along the leap it throws you into
		for i in 3:
			var t := 0.45 + 0.4 * i
			rings.append({"s": end + LAUNCH_SPEED * t, "x": cx, "h": LAUNCH_VY * t - 12.0 * t * t + 0.4, "ref": end})
	# (they come in all sizes: most are a tight tube, and about one in three is a great wide one)
	var radius := _rng.randf_range(5.5, 7.5) if _rng.randf() < 0.34 else _rng.randf_range(3.2, 4.4)
	currents.append({"s0": start, "s1": end, "xs": xs, "ds": ds, "off": 0.0, "launch": launch, "r": radius})
	return CURRENT_KNOT * count + 40.0


## A trail of rings under the sea: a few on one layer, then a few on the next one down or up,
## winding from side to side as it goes.
func _plan_deep_rings(s: float) -> float:
	var count := _rng.randi_range(9, 13)
	var cx := _rng.randf_range(-5.0, 5.0)
	var swing := _rng.randf_range(3.0, 6.0)
	var ph := _rng.randf() * TAU
	var layer := _rng.randi_range(1, layers())
	for k in count:
		var rs := s + 20.0 + 13.0 * k
		if k > 0 and k % 4 == 0 and layers() > 1:
			layer += 1 if (layer == 1 or (layer < layers() and _rng.randf() < 0.5)) else -1
		rings.append({"s": rs, "x": cx + sin(ph + k * 0.6) * swing, "h": -layer * layer_depth() + 0.2, "ref": rs})
	return 13.0 * count + 40.0


## A run of boost rings under the sea, strung along a curve that winds from side to side and
## down through the layers: each one swum through is a surge of speed.
func _plan_surge(s: float) -> float:
	var count := _rng.randi_range(6, 9)
	var cx := _rng.randf_range(-5.0, 5.0)
	var swing := _rng.randf_range(4.0, 8.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
	var wave := _rng.randf_range(0.5, 0.8)
	# (it dips no more than three layers, from wherever it starts: more is too steep to follow)
	var span := mini(layers() - 1, 3)
	var top := float(_rng.randi_range(1, layers() - span))
	for k in count:
		var rs := s + 25.0 + 17.0 * k
		# (down and back up again)
		var layer := top + span * (0.5 - 0.5 * cos(PI * k / maxf(count - 1.0, 1.0) * 2.0))
		rings.append({"s": rs, "x": cx + sin(k * wave) * swing, "h": -layer * layer_depth() + 0.2, "ref": rs, "boost": true})
	return 17.0 * count + 40.0


## A drift of sea nettles under the surface, at every depth: swim round them, or over them.
func _plan_jellies(s: float) -> float:
	var zone := 130.0
	var count := _rng.randi_range(7, 11)
	for k in count:
		var js := s + 15.0 + (zone - 20.0) * (k + _rng.randf() * 0.6) / count
		jellies.append({"s": js, "x": _rng.randf_range(-13.0, 13.0), "d": _rng.randi_range(1, layers()) * layer_depth()})
	return zone


func _plan_rocks(s: float) -> float:
	var zone := 150.0
	rapids.append({"s0": s, "s1": s + zone})
	var count := _rng.randi_range(9, 14)
	for k in count:
		var rs := s + 15.0 + (zone - 20.0) * (k + _rng.randf() * 0.6) / count
		rocks.append({"s": rs, "x": _rng.randf_range(-7.0, 7.0), "r": _rng.randf_range(0.9, 1.7)})
	if _rng.randf() < 0.6:
		ramps.append({"s": s + zone * 0.5, "x": _rng.randf_range(-3.0, 3.0), "w": 4.0, "len": 7.0, "h": 2.0})
	return zone


func _plan_ring_trail(s: float) -> float:
	var ph := _rng.randf() * TAU
	var amp := _rng.randf_range(3.0, 6.0)
	for k in 10:
		var rs := s + k * 12.0
		rings.append({"s": rs, "x": amp * sin(ph + k * 0.7), "h": 0.7, "ref": rs})
	return 125.0


# ================================================================== centre-line

func _zone(s: float, s0: float, s1: float, fade: float) -> float:
	return minf(smoothstep(s0 - fade, s0, s), 1.0 - smoothstep(s1, s1 + fade, s))


func _calm(s: float) -> float:
	var k := 1.0
	if s < 180.0:
		k = 0.15
	if near_fall(s, 80.0, 50.0):
		k = minf(k, 0.08)
	for r: Dictionary in ramps:
		if s > r.s - 30.0 and s < r.s + 55.0:
			k = minf(k, 0.35)
	for r: Dictionary in rails:
		if s > r.s0 - 40.0 and s < r.s1 + 10.0:
			k = minf(k, 0.25)
	return k


func _slope(s: float) -> float:
	var sl: float = cfg.slope
	if s < 120.0:
		sl = minf(sl, 0.01)
	for z: Dictionary in rapids:
		sl = lerpf(sl, float(cfg.slope) + 0.055, _zone(s, z.s0, z.s1, 20.0))
	for z: Dictionary in pools:
		sl = lerpf(sl, minf(sl, 0.004), _zone(s, z.s0, z.s1, 10.0))
	return sl


func _width_rule(s: float) -> float:
	var base: float = cfg.width
	var w := base + 5.0 * _noise.get_noise_1d(s * 0.005 + 400.0)
	if s < 150.0:
		w = base + 2.0
	for z: Dictionary in rapids:
		w = lerpf(w, base - 4.5, _zone(s, z.s0, z.s1, 25.0))
	for z: Dictionary in pools:
		w = lerpf(w, base + 7.0, _zone(s, z.s0, z.s1, 12.0))
	return w


func _rapid_amount(s: float) -> float:
	var a := 0.0
	for z: Dictionary in rapids:
		a = maxf(a, _zone(s, z.s0, z.s1, 15.0))
	return a


func _build_centreline() -> void:
	n = int(length / STEP) + 1
	pts.resize(n)
	heads.resize(n)
	widths.resize(n)
	var fall_at := {}
	for wf: Dictionary in waterfalls:
		fall_at[int(wf.s / STEP)] = wf.drop
	var pos := Vector3.ZERO
	var h := 0.0
	for i in n:
		var s := i * STEP
		pts[i] = pos
		heads[i] = h
		widths[i] = _width_rule(s)
		var curv := _noise.get_noise_1d(s * 0.0035 + 10.0) * 0.012 + _noise.get_noise_1d(s * 0.013 + 50.0) * 0.004
		curv -= h * 0.0025
		# and it meanders: bends to the left and to the right, one after the other, all the
		# way along
		var bend := sin(s * TAU / MEANDER + float(int(cfg.seed) % 100) * 0.063) * MEANDER_TURN
		# (open water runs all but straight: there it is the trail that wanders, see trail_x,
		# so that the salmon is never turned without being steered)
		var open := 0.15 if lane_room() > 0.0 else 1.0
		h += (curv * (0.3 if test else float(cfg.curve)) * open + bend * (0.3 if test else float(cfg.get("meander", 1.0))) * floorf(open)) * STEP * _calm(s)
		pos += Vector3(sin(h), 0.0, -cos(h)) * STEP
		var down := -1.0 if uphill() else 1.0
		pos.y -= _slope(s) * STEP * down
		if fall_at.has(i):
			pos.y -= float(fall_at[i]) * down
	for r: Dictionary in rings:
		r.pos = point(r.s, r.x, water_y(r.ref) + r.h)


# ================================================================== meshes

func _build_chunks() -> void:
	if cfg.has("floor"):
		_build_floor()
	var chunks := int(ceil(float(n - 1) / CHUNK))
	for c in chunks:
		var i0 := c * CHUNK
		var i1 := mini(i0 + CHUNK, n - 1)
		var ground := MB.new()
		for i in range(i0, i1):
			_ground_strip(ground, i)
		if not ground.is_empty():
			_add_mesh(ground.build(), mat_world)
		var wm := _add_mesh(_water_mesh(i0, i1), mat_water)
		# (the swell lifts it out of the box it was made in)
		wm.extra_cull_margin = 4.0
		wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## How far below the water the sea floor is at a point (rolling hills, never breaking the
## surface).
func _floor_depth(s: float, x: float) -> float:
	var deep: float = cfg.floor
	var hills := _noise.get_noise_2d(s * 0.011, x * 0.011 + 300.0) * 0.4 + _noise.get_noise_2d(s * 0.04 + 50.0, x * 0.04) * 0.12
	return maxf(deep * (1.0 + hills), deep * 0.35)


## The sea floor of an open-water stage: a coarse sheet of hills far wider than the course,
## way down under the water.
func _build_floor() -> void:
	# (a floor too deep to see is not built at all: there is only the dark below)
	if float(cfg.floor) > 100.0:
		return
	var cell := 16.0
	var half := float(cfg.width) * 0.5 + 180.0
	var across := int(ceil(half * 2.0 / cell))
	var along := int(cell / STEP)
	var base: Color = cfg.bed
	var rows_per_mesh := 12
	var row := 0
	var mb := MB.new()
	var i := 0
	while i + along < n:
		var sa := i * STEP
		var sb := (i + along) * STEP
		for j in across:
			var x0 := -half + j * cell
			var x1 := x0 + cell
			var d: Array[float] = [_floor_depth(sa, x0), _floor_depth(sa, x1), _floor_depth(sb, x1), _floor_depth(sb, x0)]
			# lighter on the rises, darker in the hollows
			var lift: float = 1.0 - ((d[0] + d[2]) * 0.5) / float(cfg.floor)
			var col := Props.vary(base.lightened(clampf(lift * 0.5, 0.0, 0.3)) if lift > 0.0 else base.darkened(clampf(-lift * 0.6, 0.0, 0.4)), _rng, 0.03)
			mb.quad(point(sa, x0, water_y(sa) - d[0]), point(sa, x1, water_y(sa) - d[1]),
					point(sb, x1, water_y(sb) - d[2]), point(sb, x0, water_y(sb) - d[3]), col, Vector3.UP)
		row += 1
		if row % rows_per_mesh == 0:
			_add_mesh(mb.build(), mat_world)
			mb = MB.new()
		i += along
	if not mb.is_empty():
		_add_mesh(mb.build(), mat_world)


func _add_mesh(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)
	return mi


## The "bank" on the side that is open sea: a shelf under the water, out of sight.
const SEA_PROFILE := [[-0.5, -1.2, 0, 0], [4.0, -3.0, 0, 0], [60.0, -3.0, 0, 0], [170.0, -3.0, 0, 0]]
const BED_X := [-1.0, -0.5, 0.0, 0.5, 1.0]
const BED_D := [-1.2, -2.6, -3.0, -2.6, -1.2]


func _ground_strip(mb: MB, i: int) -> void:
	# open sea has no river bed or banks: its floor is built on its own, far below. (Where it
	# has a shore, there is the one bank.)
	var open: bool = cfg.has("floor")
	if open and not cfg.has("shore"):
		return
	var sa := i * STEP
	var sb := (i + 1) * STEP
	var cliff := absf(pts[i + 1].y - pts[i].y) > 2.0
	var fwd := forward(sa)
	var hint := Vector3.UP + fwd * 0.6
	var rock: Color = cfg.cliff
	var bed: Color = cfg.bed
	for j in (0 if open else 4):
		var a := point(sa, BED_X[j] * (width(sa) * 0.5 - 0.5), water_y(sa) + BED_D[j])
		var b := point(sa, BED_X[j + 1] * (width(sa) * 0.5 - 0.5), water_y(sa) + BED_D[j + 1])
		var c := point(sb, BED_X[j + 1] * (width(sb) * 0.5 - 0.5), water_y(sb) + BED_D[j + 1])
		var d := point(sb, BED_X[j] * (width(sb) * 0.5 - 0.5), water_y(sb) + BED_D[j])
		var col := Props.vary(rock if cliff else bed, _rng, 0.05)
		mb.quad(a, b, c, d, col, hint)
	for side: float in [-1.0, 1.0]:
		var sea := is_sea_side(side)
		if open and sea:
			continue
		var pa := bank_profile(sa, side)
		var pb := bank_profile(sb, side)
		var bank_hint := Vector3.UP + fwd * 0.6 - right(sa) * side * 0.4
		for j in pa.size() - 1:
			var a := point(sa, side * pa[j].x, water_y(sa) + pa[j].y)
			var b := point(sa, side * pa[j + 1].x, water_y(sa) + pa[j + 1].y)
			var c := point(sb, side * pb[j + 1].x, water_y(sb) + pb[j + 1].y)
			var d := point(sb, side * pb[j].x, water_y(sb) + pb[j].y)
			var base: Color = rock if cliff else (bed if sea else cfg.bank_colors[j])
			mb.quad(a, b, c, d, Props.vary(base, _rng, 0.04), bank_hint)


## The water of one chunk of the course: a mesh fine enough (a few metres to a square) for
## the shader to lift into a swell. Each strip along the course has corners of its own, so
## that a waterfall's face is square to the water above and below it; across, they are shared.
## Besides the usual mapping (see water_u) each corner carries where it is in metres across
## the course, and how much of the swell it gets (UV2): none far out to sea, where the mesh
## is coarse.
func _water_mesh(i0: int, i1: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var tangents := PackedFloat32Array()
	var indices := PackedInt32Array()
	# A river's water is mapped bank to bank, with foam along its edges. Open water far wider
	# than a river keeps the same size of ripple (so the mapping repeats) and has no edges.
	var wide := float(cfg.width) > 40.0
	var cols := clampi(ceili((float(cfg.width) + 1.6) / 3.5), 6, 48)
	# open water beyond the course, each side that has no shore: two more columns, the far
	# one very wide (green vertex colour = no foam along its edges)
	var skirts: Array[float] = []
	if cfg.has("sea_from"):
		var d0: float = cfg.sea_from
		var d1: float = cfg.get("sea_to", 170.0)
		skirts = [d0, minf(d0 + 30.0, d1), d1]
	for i in range(i0, i1):
		var first := verts.size()
		var row := 0
		for end in 2:
			var s := (i + end) * STEP
			var half := width(s) * 0.5 + 0.8
			var repeat := (half * 2.0 / 26.8) if wide else 1.0
			var colour := Color(_rapid_amount(i * STEP), 1.0 if wide else 0.0, 0.0)
			var across: Array = []   # [x, u, swell, colour]
			for side: float in [-1.0, 1.0]:
				# (the open water on the left, from far out inwards; then the course's own
				# water; then the open water on the right)
				var sea := not skirts.is_empty() and not (cfg.has("shore") and not is_sea_side(side))
				if side > 0.0:
					for j in cols + 1:
						var f := -1.0 + 2.0 * j / cols
						across.append([f * half, 0.5 + f * 0.5 * repeat, 1.0, colour])
				if sea:
					for k in skirts.size():
						var dist: float = skirts[k] if side > 0.0 else skirts[skirts.size() - 1 - k]
						across.append([side * (width(s) * 0.5 + dist), 0.5 + side * (0.5 * repeat + dist * 0.04), 1.0 if dist == skirts[0] else 0.0, Color(0.0, 1.0, 0.0)])
			row = across.size()
			for v: Array in across:
				verts.append(point(s, float(v[0]), water_y(s)))
				uvs.append(Vector2(float(v[1]), s))
				uv2s.append(Vector2(float(v[0]), float(v[2])))
				colours.append(v[3])
				# (which way is across the course here: the shader needs it for the waves' slope)
				var over := right(s)
				tangents.append_array(PackedFloat32Array([over.x, over.y, over.z, 1.0]))
		# the strip's face: square to its slope (upright on a waterfall)
		var along := point((i + 1) * STEP, 0.0, water_y((i + 1) * STEP)) - point(i * STEP, 0.0, water_y(i * STEP))
		var face := along.cross(right(i * STEP)).normalized()
		if face.y < 0.0:
			face = -face
		for k in row * 2:
			normals.append(face)
		for j in row - 1:
			var a := first + j
			var b := a + 1
			var c := first + row + j + 1
			var d := first + row + j
			# (Godot's front faces are the clockwise ones: seen from above, these are)
			var raw := (verts[b] - verts[a]).cross(verts[c] - verts[a])
			if raw.dot(face) > 0.0:
				indices.append_array(PackedInt32Array([a, c, b, a, d, c]))
			else:
				indices.append_array(PackedInt32Array([a, b, c, a, c, d]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# ================================================================== features

func _build_features() -> void:
	var frng := RandomNumberGenerator.new()
	frng.seed = course_seed + 5
	for r: Dictionary in ramps:
		var mi := _add_mesh(Props.ramp(r.w, r.len, r.h, frng, cfg.ramp, cfg.ramp_top), mat_world)
		mi.transform = Transform3D(basis_at(r.s), point(r.s, r.x, water_y(r.s)))

	var rock_meshes := [Props.rock(frng, cfg.rock, cfg.rock_cap), Props.rock(frng, cfg.rock, cfg.rock_cap),
			Props.rock(frng, Props.shade(cfg.rock, 0.82), cfg.rock_cap)]
	if cfg.get("rock_mesh", "") == "crate":
		rock_meshes = [Props.crate(frng, cfg.rock), Props.crate(frng, Props.shade(cfg.rock, 0.8)), Props.crate(frng, cfg.rock)]
	if cfg.get("rock_mesh", "") == "buoy":
		rock_meshes = [Props.buoy(frng, cfg.rock, cfg.rock_cap), Props.buoy(frng, cfg.rock_cap, cfg.rock), Props.buoy(frng, cfg.rock, cfg.rock_cap)]
	for r: Dictionary in rocks:
		var mi := _add_mesh(rock_meshes[frng.randi() % 3], mat_world)
		# (a float is a slimmer thing than a rock, so it is drawn bigger to fill the same room)
		var b := Basis(Vector3.UP, frng.randf() * TAU).scaled(Vector3(r.r, r.r * 1.1, r.r) * (1.5 if cfg.get("rock_mesh", "") == "buoy" else 1.15))
		mi.transform = Transform3D(b, point(r.s, r.x, water_y(r.s) - 0.35))

	for r: Dictionary in rails:
		_build_rail(r)
	for j: Dictionary in jellies:
		var nettle := _add_mesh(Props.sea_nettle(frng), mat_world)
		nettle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		j.y = water_y(j.s) - float(j.d)
		nettle.transform = Transform3D(Basis(Vector3.UP, frng.randf() * TAU), point(j.s, j.x, j.y))
		j.node = nettle
	for c: Dictionary in currents:
		_build_current(c)

	_ring_root = Node3D.new()
	add_child(_ring_root)
	var ring_mesh := Props.ring()
	var boost_mesh := Props.ring(1.9, 0.2, Color(0.4, 1.0, 0.95), Color(0.85, 1.0, 1.0))
	for r: Dictionary in rings:
		var mi := MeshInstance3D.new()
		mi.mesh = boost_mesh if r.get("boost", false) else ring_mesh
		mi.material_override = mat_world
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ring_root.add_child(mi)
		mi.transform = Transform3D(basis_at(r.s), r.pos)
		r.node = mi
		r.taken = false

	for b: Dictionary in bears:
		var bear := Bear.new()
		add_child(bear)
		bear.setup(frng, mat_world, cfg.predator)
		bear.beat_offset = b.off
		if cfg.predator == "shark":
			bear.depth = float(b.get("d", 0.5))
			bear.sweep = minf(8.0, width(b.s) * 0.5 - 3.0)
			bear.transform = Transform3D(basis_at(b.s), point(b.s, b.x, water_y(b.s)))
		else:
			bear.transform = Transform3D(Basis(Vector3.UP, -heading(b.s) + PI), point(b.s, b.x, water_y(b.s) - 0.7))
		b.node = bear

	var speaker := Props.speaker_stack(frng)
	var ruin_meshes := [Props.ruin(frng), Props.ruin(frng)]
	for wf: Dictionary in waterfalls:
		var lip: float = wf.s
		# white water where the falls land
		var at := lip - 3.0 if uphill() else lip + 3.0
		var foam := _foam(point(at, 0.0, water_y(at) + 0.3), basis_at(lip), width(at))
		add_child(foam)
		for side: float in [-1.0, 1.0]:
			if cfg.ruins:
				_place_facing_river(ruin_meshes[frng.randi() % 2], lip - 4.0, side, width(lip - 4.0) * 0.5 + 3.0, 1.0)
			_place_facing_river(speaker, lip + 30.0, side, width(lip + 30.0) * 0.5 + 6.0, 1.0)
	_place_facing_river(speaker, START_S + 40.0, 1.0, width(START_S + 40.0) * 0.5 + 6.0, 1.0)
	_place_facing_river(speaker, START_S + 40.0, -1.0, width(START_S + 40.0) * 0.5 + 6.0, 1.0)

	# (no gate at the start: only the one at the finish)
	_build_arch(finish_s, _finish_text(), Color(1.0, 0.35, 0.7))
	if not fork.is_empty():
		_build_fork()


func _place_facing_river(mesh: Mesh, s: float, side: float, dist: float, sc: float) -> void:
	var mi := _add_mesh(mesh, mat_world)
	var face := -right(s) * side
	var b := Basis.looking_at(face, Vector3.UP).scaled(Vector3.ONE * sc)
	# out at sea there is no bank to stand on, so it floats
	mi.transform = Transform3D(b, point(s, side * dist, maxf(bank_y(s, side, dist), water_y(s) + 0.3) - 0.3))


## A current is drawn as a tube of streaks running the way it flows, with a row of arrows on
## the surface over its mouth that point down to it.
func _build_current(c: Dictionary) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/current.gdshader")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 20
	var rows := int((float(c.s1) - float(c.s0)) / 2.0)
	var wide := float(c.get("r", 1.25))
	# (few strands, well spread out: a wide one has a few more, no thicker than a narrow one has)
	mat.set_shader_parameter("strands", maxf(roundf(TAU * wide / 11.0), 2.0))
	mat.set_shader_parameter("girth", TAU * wide)
	mat.set_shader_parameter("ends", Vector2(float(c.s0), float(c.s1)) / 6.0)
	for k in rows + 1:
		var s: float = float(c.s0) + 2.0 * k
		var mid := point(s, current_x(c, s), water_y(s) - current_depth(c, s))
		var across := right(s)

		# (and where it comes near the surface it is drawn in, so as to stay under it)
		# (the same all the way: its two ends are open mouths, not points)
		var radius := current_radius(c, s)
		for j in sides + 1:
			var a := TAU * j / sides
			st.set_normal(across * cos(a) + Vector3.UP * sin(a))
			st.set_uv(Vector2(s / 6.0, float(j) / sides))
			st.add_vertex(mid + (across * cos(a) + Vector3.UP * sin(a)) * radius)
	for k in rows:
		for j in sides:
			var a := k * (sides + 1) + j
			var b := a + sides + 1
			for i: int in [a, b, a + 1, a + 1, b, b + 1]:
				st.add_index(i)
	_add_mesh(st.commit(), mat)
	c.mat = mat
	var arrows := SurfaceTool.new()
	arrows.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var s: float = float(c.s0) - 4.0 + 5.0 * k
		var top := point(s, current_x(c, s), water_y(s) + 1.5 - 0.25 * k)
		var across := right(s) * 0.9
		for v: Vector3 in [top - across, top + across, top - Vector3.UP * 0.9]:
			arrows.set_color(Color(1.0, 1.0, 1.0))
			arrows.add_vertex(v)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.vertex_color_use_as_albedo = true
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_mesh(arrows.commit(), glow)


func _build_rail(r: Dictionary) -> void:
	var mb := MB.new()
	var green: Color = cfg.rail
	var node_col: Color = cfg.rail_node
	var radius := 0.35
	var prev := Vector3.ZERO
	var s: float = r.s0
	var k := 0
	while s <= r.s1 + 0.01:
		var p := point(s, rail_x(r, s), water_y(s) + RAIL_H - radius)
		if k > 0:
			Props.frustum(mb, prev, p, radius, radius, 6, green if k % 2 == 0 else Props.shade(green, 0.9), false)
			var dir := (p - prev).normalized()
			Props.frustum(mb, p - dir * 0.08, p + dir * 0.08, radius * 1.18, radius * 1.18, 6, node_col, false)
		if k % 4 == 0:
			var base := point(s, rail_x(r, s), water_y(s) - 1.5)
			var side := right(s) * 0.8
			Props.frustum(mb, base - side, p + side * 0.2, 0.12, 0.1, 4, node_col, true)
			Props.frustum(mb, base + side, p - side * 0.2, 0.12, 0.1, 4, node_col, true)
		prev = p
		s += 3.0
		k += 1
	# glowing end caps so the rail reads from a distance
	var cap := Props.glow(Color(0.7, 1.0, 0.3), 0.6)
	for cs: float in [r.s0, r.s1]:
		var cp := point(cs, rail_x(r, cs), water_y(cs) + RAIL_H - radius)
		Props.blob(mb, cp, Vector3.ONE * 0.45, _rng, cap, 5, 3, 0.0)
	_add_mesh(mb.build(), mat_world)


func _build_arch(s: float, text: String, col: Color) -> void:
	var arng := RandomNumberGenerator.new()
	arng.seed = int(s)
	var span := width(s) + 3.0
	var mi := _add_mesh(Props.arch(span, arng, col, cfg.arch), mat_world)
	mi.transform = Transform3D(basis_at(s), point(s, 0.0, water_y(s)))
	var label := Label3D.new()
	label.text = text
	label.font = UI.font()
	label.font_size = 96
	label.pixel_size = 0.016
	label.outline_size = 18
	label.modulate = Color(1, 1, 1)
	label.outline_modulate = Color(0.1, 0.02, 0.15)
	label.position = Vector3(0.0, 8.4, 0.3)
	mi.add_child(label)


func _foam(pos: Vector3, b: Basis, w: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 90
	p.lifetime = 1.4
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(w * 0.5, 0.3, 2.0)
	p.direction = Vector3(0, 1, -0.4)
	p.spread = 35.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 7.0
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	var m := BoxMesh.new()
	m.size = Vector3.ONE * 0.6
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.9, 1.0, 0.97)
	m.material = mat
	p.mesh = m
	p.transform = Transform3D(b, pos)
	return p


# ================================================================== jungle scatter

const FOLIAGE := ["tree", "palm", "fern", "reeds", "pine", "larch", "grass", "bamboo", "maple"]
const NO_SHADOW := ["fern", "flower", "reeds", "lily", "shroom", "grass", "floe", "coral", "jelly"]


## The variants of one kind of dressing (see the scatter rules in levels.gd).
func _scatter_meshes(kind: String, rng: RandomNumberGenerator) -> Array:
	match kind:
		"tree":
			return [Props.jungle_tree(rng), Props.jungle_tree(rng), Props.jungle_tree(rng), Props.jungle_tree(rng)]
		"palm":
			return [Props.palm(rng), Props.palm(rng), Props.palm(rng)]
		"fern":
			return [Props.fern(rng), Props.fern(rng), Props.fern(rng)]
		"bush":
			return [Props.bush(rng), Props.bush(rng)]
		"rock":
			return [Props.rock(rng, cfg.rock, cfg.rock_cap), Props.rock(rng, Props.shade(cfg.rock, 1.08), cfg.rock_cap)]
		"flower":
			return [Props.flower(rng, Color(1.0, 0.3, 0.7)), Props.flower(rng, Color(0.3, 0.9, 1.0)), Props.flower(rng, Color(1.0, 0.75, 0.2))]
		"shroom":
			return [Props.mushroom(rng, Color(0.3, 1.0, 0.9)), Props.mushroom(rng, Color(0.8, 0.4, 1.0))]
		"reeds":
			return [Props.reeds(rng), Props.reeds(rng)]
		"lily":
			return [Props.lily_pad(rng, false), Props.lily_pad(rng, true)]
		"hill":
			return [Props.hill(rng, cfg.hill), Props.hill(rng, cfg.hill)]
		"mountain":
			var peak: Color = cfg.get("peak", Color(0.94, 0.96, 1.0))
			return [Props.mountain(rng, cfg.hill, peak), Props.mountain(rng, cfg.hill, peak), Props.mountain(rng, cfg.hill, peak)]
		"pine":
			var snow: float = cfg.get("snow", 0.0)
			return [Props.pine(rng, snow), Props.pine(rng, snow), Props.pine(rng, snow), Props.pine(rng, snow)]
		"larch":
			return [Props.pine(rng, 0.0, true), Props.pine(rng, 0.0, true), Props.pine(rng, 0.0, true)]
		"crate":
			return [Props.crate(rng, Props.CONTAINER_COLORS[0]), Props.crate(rng, Props.CONTAINER_COLORS[1]),
					Props.crate(rng, Props.CONTAINER_COLORS[2]), Props.crate(rng, Props.CONTAINER_COLORS[3])]
		"boat":
			return [Props.boat(rng), Props.boat(rng), Props.boat(rng)]
		"ship":
			return [Props.ship(rng), Props.ship(rng)]
		"piling":
			return [Props.piling(rng), Props.piling(rng), Props.piling(rng)]
		"crane":
			return [Props.crane(rng), Props.crane(rng)]
		"shed":
			return [Props.shed(rng), Props.shed(rng), Props.shed(rng)]
		"lamp":
			return [Props.lamp(rng), Props.lamp(rng)]
		"jelly":
			return [Props.jelly(rng), Props.jelly(rng), Props.jelly(rng)]
		"spire":
			return [Props.spire(rng), Props.spire(rng)]
		"bamboo":
			return [Props.bamboo(rng), Props.bamboo(rng), Props.bamboo(rng), Props.bamboo(rng)]
		"maple":
			return [Props.maple(rng, cfg.leaf, cfg.leaf2), Props.maple(rng, cfg.leaf, cfg.leaf2), Props.maple(rng, cfg.leaf, cfg.leaf2)]
		"torii":
			return [Props.torii(rng)]
		"lantern":
			return [Props.lantern(rng)]
		"bale":
			return [Props.bale(rng), Props.bale(rng)]
		"barn":
			return [Props.barn(rng), Props.barn(rng)]
		"windmill":
			return [Props.windmill(rng), Props.windmill(rng)]
		"cactus":
			return [Props.cactus(rng), Props.cactus(rng), Props.cactus(rng)]
		"mesa":
			return [Props.mesa(rng, cfg.hill), Props.mesa(rng, cfg.hill), Props.mesa(rng, cfg.hill)]
		"pen":
			return [Props.pen(rng), Props.pen(rng)]
		"grass":
			return [Props.grass(rng), Props.grass(rng)]
		"coral":
			return [Props.coral(rng), Props.coral(rng), Props.coral(rng), Props.coral(rng)]
		"stack":
			return [Props.sea_stack(rng), Props.sea_stack(rng)]
		"iceberg":
			return [Props.iceberg(rng), Props.iceberg(rng), Props.iceberg(rng)]
		"floe":
			return [Props.floe(rng), Props.floe(rng)]
		"umbrella":
			return [Props.umbrella(rng), Props.umbrella(rng), Props.umbrella(rng)]
		"driftwood":
			return [Props.driftwood(rng), Props.driftwood(rng)]
	return []


func _scatter() -> void:
	var srng := RandomNumberGenerator.new()
	srng.seed = course_seed + 99
	var rules: Array = cfg.scatter
	var meshes := {}
	for rule: Array in rules:
		if not meshes.has(rule[0]):
			meshes[rule[0]] = _scatter_meshes(rule[0], srng)
	var bucket := {}
	var s := 0.0
	while s < length - 4.0:
		if near_fall(s, 2.0, 4.0):
			s += 4.0
			continue
		var hw := width(s) * 0.5
		for side: float in [-1.0, 1.0]:
			for rule: Array in rules:
				var kind: String = rule[0]
				var variants: int = (meshes[kind] as Array).size()
				match rule[7]:
					"bank":
						# (no bank on the side that is open sea)
						if is_sea_side(side):
							continue
						_try(bucket, srng, kind, variants, rule[1], s, side, hw + float(rule[2]), hw + float(rule[3]), rule[4], rule[5], rule[6])
					"water":
						# (and nothing afloat beyond the course on the side that is land)
						if cfg.has("shore") and not is_sea_side(side) and float(rule[2]) >= 0.0:
							continue
						if srng.randf() < float(rule[1]):
							var d := srng.randf_range(hw + float(rule[2]), hw + float(rule[3]))
							# keep the course itself clear of rapids and ramps
							if d > hw or (_rapid_amount(s) < 0.1 and ramp_height(s, side * d) == 0.0):
								_put(bucket, kind, srng.randi() % variants, s, point(s, side * d, water_y(s) + float(rule[6])), srng.randf_range(rule[4], rule[5]), srng)
					"far":
						# (a ninth entry keeps it to one side: -1 the left, 1 the right)
						if rule.size() > 8 and float(rule[8]) != side:
							continue
						if int(s) % 40 == 0 and srng.randf() < float(rule[1]):
							var d := srng.randf_range(hw + float(rule[2]), hw + float(rule[3]))
							var sink := srng.randf_range(-12.0, 4.0) if kind in ["hill", "mountain", "mesa"] else float(rule[6])
							_put(bucket, kind, srng.randi() % variants, s, point(s, side * d, water_y(s) + sink), srng.randf_range(rule[4], rule[5]), srng)
			# lane markers where there are no banks to show the way
			# (not on the salt water: a swarm of sardines keeps its edges, see edge_swarm.gd)
			if cfg.has("markers") and not bool(cfg.get("salt", false)) and int(s) % 16 == 0 and not (cfg.has("shore") and not is_sea_side(side)):
				_put(bucket, "marker", 0, s, point(s, side * (hw + 0.4), water_y(s)), 1.0, srng)
		s += 4.0
	if cfg.has("markers"):
		meshes["marker"] = [Props.buoy(srng, cfg.markers[0], cfg.markers[1])]
	for key: String in bucket:
		var parts := key.split("|")
		var kind := parts[0]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[kind][int(parts[1])]
		var list: Array = bucket[key]
		mm.instance_count = list.size()
		for k in list.size():
			mm.set_instance_transform(k, list[k])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat_foliage if kind in FOLIAGE else mat_world
		if kind in NO_SHADOW:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)


func _try(bucket: Dictionary, rng: RandomNumberGenerator, kind: String, variants: int, chance: float,
		s: float, side: float, d0: float, d1: float, sc0: float, sc1: float, sink: float) -> void:
	if rng.randf() > chance:
		return
	var ss := s + rng.randf_range(0.0, 4.0)
	if near_fall(ss, 2.0, 4.0):
		return
	var d := rng.randf_range(d0, d1)
	var y := bank_y(ss, side, d) + sink
	_put(bucket, kind, rng.randi() % variants, ss, point(ss, side * d, y), rng.randf_range(sc0, sc1), rng)


func _put(bucket: Dictionary, kind: String, variant: int, s: float, pos: Vector3, sc: float, rng: RandomNumberGenerator) -> void:
	var key := "%s|%d|%d" % [kind, variant, int(s / GROUP_LEN)]
	if not bucket.has(key):
		bucket[key] = []
	var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc)
	bucket[key].append(Transform3D(b, pos))
