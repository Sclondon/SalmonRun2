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
var rings: Array = []        # {s, x, h, ref, pos, node, taken}
var bears: Array = []        # {s, x, node}

var mat_world: ShaderMaterial
var mat_foliage: ShaderMaterial
var mat_water: ShaderMaterial

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
	mat_water = ShaderMaterial.new()
	mat_water.shader = preload("res://shaders/water.gdshader")
	mat_water.set_shader_parameter("deep_color", cfg.water_deep)
	mat_water.set_shader_parameter("shallow_color", cfg.water_shallow)
	mat_water.set_shader_parameter("beat_color", cfg.water_beat)
	mat_water.set_shader_parameter("swell", cfg.swell)
	# upstream, the river runs towards you
	mat_water.set_shader_parameter("flow", -0.6 if uphill() else 0.6)


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


## Returns the (x, y-above-water) profile of one bank, from the water's edge outwards.
func bank_profile(s: float, side: float) -> PackedVector2Array:
	var hw := width(s) * 0.5
	var k := side * 100.0
	var n1 := _noise.get_noise_2d(s * 0.03, k)
	var n2 := _noise.get_noise_2d(s * 0.008, k + 30.0)
	var out := PackedVector2Array()
	for p: Array in cfg.profile:
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
	return got


func reset_rings() -> void:
	for r: Dictionary in rings:
		r.taken = false
		(r.node as Node3D).visible = true


func _process(_delta: float) -> void:
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


# ================================================================== planning

func _plan_features() -> void:
	var s := 230.0
	var since_fall := 0.0
	var kinds: Array = cfg.kinds
	var falls_every: float = cfg.falls_every
	var last := ""
	while s < length - 320.0:
		var kind: String
		if falls_every > 0.0 and since_fall > falls_every:
			kind = "bear_falls" if _rng.randf() < 0.5 else "falls"
		else:
			kind = kinds[_rng.randi() % kinds.size()]
			if kind == last:
				kind = kinds[(kinds.find(kind) + 1) % kinds.size()]
		last = kind
		var used := 0.0
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
			"predators":
				used = _plan_predators(s)
		var gap := _rng.randf_range(45.0, 80.0)
		s += used + gap
		since_fall += used + gap
	finish_s = length - 150.0


## Fixed layout, in the order you'd want to learn things: steer, jump, ramps, a rail,
## rocks, a waterfall.
func _plan_test() -> void:
	length = 1500.0
	finish_s = length - 150.0
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


## Two predators (sharks at sea, bears in the rivers) snapping on alternate beats, with rings
## over their heads for anyone brave enough to jump them.
func _plan_predators(s: float) -> float:
	if cfg.predator == "":
		return _plan_ring_trail(s)
	for k in 2:
		var ps := s + 30.0 + k * 34.0
		var px := _rng.randf_range(-5.0, 5.0)
		bears.append({"s": ps, "x": px, "off": float(k)})
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
	ramps.append({"s": s, "x": rx, "w": 5.0, "len": 9.0, "h": 2.6})
	var r_len := _rng.randf_range(45.0, 75.0)
	rails.append({"s0": s + 20.0, "s1": s + 20.0 + r_len, "x0": rx, "x1": clampf(rx + _rng.randf_range(-4.0, 4.0), -7.0, 7.0)})
	if _rng.randf() < 0.6:
		# a second, lower-entry rail you can swim straight onto
		var x2 := -rx if absf(rx) > 2.5 else rx + 6.0
		rails.append({"s0": s + 35.0, "s1": s + 35.0 + r_len * 0.7, "x0": x2, "x1": x2})
	return r_len + 30.0


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
		h += curv * STEP * _calm(s) * (0.3 if test else float(cfg.curve))
		pos += Vector3(sin(h), 0.0, -cos(h)) * STEP
		var down := -1.0 if uphill() else 1.0
		pos.y -= _slope(s) * STEP * down
		if fall_at.has(i):
			pos.y -= float(fall_at[i]) * down
	for r: Dictionary in rings:
		r.pos = point(r.s, r.x, water_y(r.ref) + r.h)


# ================================================================== meshes

func _build_chunks() -> void:
	var chunks := int(ceil(float(n - 1) / CHUNK))
	for c in chunks:
		var i0 := c * CHUNK
		var i1 := mini(i0 + CHUNK, n - 1)
		var ground := MB.new()
		var water := MB.new()
		for i in range(i0, i1):
			_ground_strip(ground, i)
			_water_strip(water, i)
		_add_mesh(ground.build(), mat_world)
		var wm := _add_mesh(water.build(), mat_water)
		wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _add_mesh(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)
	return mi


const BED_X := [-1.0, -0.5, 0.0, 0.5, 1.0]
const BED_D := [-1.2, -2.6, -3.0, -2.6, -1.2]


func _ground_strip(mb: MB, i: int) -> void:
	var sa := i * STEP
	var sb := (i + 1) * STEP
	var cliff := absf(pts[i + 1].y - pts[i].y) > 2.0
	var fwd := forward(sa)
	var hint := Vector3.UP + fwd * 0.6
	var rock: Color = cfg.cliff
	var bed: Color = cfg.bed
	for j in 4:
		var a := point(sa, BED_X[j] * (width(sa) * 0.5 - 0.5), water_y(sa) + BED_D[j])
		var b := point(sa, BED_X[j + 1] * (width(sa) * 0.5 - 0.5), water_y(sa) + BED_D[j + 1])
		var c := point(sb, BED_X[j + 1] * (width(sb) * 0.5 - 0.5), water_y(sb) + BED_D[j + 1])
		var d := point(sb, BED_X[j] * (width(sb) * 0.5 - 0.5), water_y(sb) + BED_D[j])
		var col := Props.vary(rock if cliff else bed, _rng, 0.05)
		mb.quad(a, b, c, d, col, hint)
	for side: float in [-1.0, 1.0]:
		var pa := bank_profile(sa, side)
		var pb := bank_profile(sb, side)
		var bank_hint := Vector3.UP + fwd * 0.6 - right(sa) * side * 0.4
		for j in pa.size() - 1:
			var a := point(sa, side * pa[j].x, water_y(sa) + pa[j].y)
			var b := point(sa, side * pa[j + 1].x, water_y(sa) + pa[j + 1].y)
			var c := point(sb, side * pb[j + 1].x, water_y(sb) + pb[j + 1].y)
			var d := point(sb, side * pb[j].x, water_y(sb) + pb[j].y)
			var base: Color = rock if cliff else cfg.bank_colors[j]
			mb.quad(a, b, c, d, Props.vary(base, _rng, 0.04), bank_hint)


func _water_strip(mb: MB, i: int) -> void:
	var sa := i * STEP
	var sb := (i + 1) * STEP
	var hint := Vector3.UP + forward(sa) * 0.6
	var ha := width(sa) * 0.5 + 0.8
	var hb := width(sb) * 0.5 + 0.8
	var ca := Color(_rapid_amount(sa), 0.0, 0.0)
	for j in 4:
		var xa0: float = BED_X[j]
		var xa1: float = BED_X[j + 1]
		var a := point(sa, xa0 * ha, water_y(sa))
		var b := point(sa, xa1 * ha, water_y(sa))
		var c := point(sb, xa1 * hb, water_y(sb))
		var d := point(sb, xa0 * hb, water_y(sb))
		var u0 := (xa0 + 1.0) * 0.5
		var u1 := (xa1 + 1.0) * 0.5
		mb.quad(a, b, c, d, ca, hint, Vector2(u0, sa), Vector2(u1, sa), Vector2(u1, sb), Vector2(u0, sb))
	if not cfg.has("sea_from"):
		return
	# open water beyond the course (green vertex colour = no foam along its edges)
	var open := Color(0.0, 1.0, 0.0)
	var d0: float = cfg.sea_from
	var d1: float = cfg.get("sea_to", 170.0)
	for side: float in [-1.0, 1.0]:
		var prev := d0
		for dist: float in [minf(d0 + 30.0, d1), d1]:
			var a := point(sa, side * (width(sa) * 0.5 + prev), water_y(sa))
			var b := point(sa, side * (width(sa) * 0.5 + dist), water_y(sa))
			var c := point(sb, side * (width(sb) * 0.5 + dist), water_y(sb))
			var d := point(sb, side * (width(sb) * 0.5 + prev), water_y(sb))
			var ua := 0.5 + side * (0.5 + prev * 0.04)
			var ub := 0.5 + side * (0.5 + dist * 0.04)
			mb.quad(a, b, c, d, open, hint, Vector2(ua, sa), Vector2(ub, sa), Vector2(ub, sb), Vector2(ua, sb))
			prev = dist


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
	for r: Dictionary in rocks:
		var mi := _add_mesh(rock_meshes[frng.randi() % 3], mat_world)
		var b := Basis(Vector3.UP, frng.randf() * TAU).scaled(Vector3(r.r, r.r * 1.1, r.r) * 1.15)
		mi.transform = Transform3D(b, point(r.s, r.x, water_y(r.s) - 0.35))

	for r: Dictionary in rails:
		_build_rail(r)

	_ring_root = Node3D.new()
	add_child(_ring_root)
	var ring_mesh := Props.ring()
	for r: Dictionary in rings:
		var mi := MeshInstance3D.new()
		mi.mesh = ring_mesh
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
		bear.transform = Transform3D(Basis(Vector3.UP, -heading(b.s) + PI), point(b.s, b.x, water_y(b.s) - (0.7 if cfg.predator == "bear" else 0.0)))
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

	_build_arch(START_S + 22.0, "PRACTICE" if test else str(cfg.name), Color(0.2, 1.0, 0.85))
	_build_arch(finish_s, _finish_text(), Color(1.0, 0.35, 0.7))


func _place_facing_river(mesh: Mesh, s: float, side: float, dist: float, sc: float) -> void:
	var mi := _add_mesh(mesh, mat_world)
	var face := -right(s) * side
	var b := Basis.looking_at(face, Vector3.UP).scaled(Vector3.ONE * sc)
	# out at sea there is no bank to stand on, so it floats
	mi.transform = Transform3D(b, point(s, side * dist, maxf(bank_y(s, side, dist), water_y(s) + 0.3) - 0.3))


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
						_try(bucket, srng, kind, variants, rule[1], s, side, hw + float(rule[2]), hw + float(rule[3]), rule[4], rule[5], rule[6])
					"water":
						if srng.randf() < float(rule[1]):
							var d := srng.randf_range(hw + float(rule[2]), hw + float(rule[3]))
							# keep the course itself clear of rapids and ramps
							if d > hw or (_rapid_amount(s) < 0.1 and ramp_height(s, side * d) == 0.0):
								_put(bucket, kind, srng.randi() % variants, s, point(s, side * d, water_y(s) + float(rule[6])), srng.randf_range(rule[4], rule[5]), srng)
					"far":
						if int(s) % 40 == 0 and srng.randf() < float(rule[1]):
							var d := srng.randf_range(hw + float(rule[2]), hw + float(rule[3]))
							var sink := srng.randf_range(-12.0, 4.0) if kind in ["hill", "mountain", "mesa"] else float(rule[6])
							_put(bucket, kind, srng.randi() % variants, s, point(s, side * d, water_y(s) + sink), srng.randf_range(rule[4], rule[5]), srng)
			# lane markers where there are no banks to show the way
			if cfg.has("markers") and int(s) % 16 == 0:
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
