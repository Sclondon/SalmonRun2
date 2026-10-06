extends Node3D
## The rest of the run: a pack of other salmon making the same journey right alongside you,
## each keeping a place of its own round the player. They are company,
## not competition: they keep to the water near the player, weave round rocks, ride the ramps,
## leap the falls, leap when the player leaps and dive when the player dives, and are swapped
## back in close by if they are ever left behind.

const Track := preload("res://scripts/world/track.gd")
const Salmon := preload("res://scripts/player/salmon.gd")
const Props := preload("res://scripts/world/props.gd")
const Splash := preload("res://scripts/fx/splash.gd")

const AHEAD := 45.0
const BEHIND := 22.0

var track: Track
var player: Salmon

var _fish: Array[Dictionary] = []
var _look := ""
var _t := 0.0
var _was_air := false
var wakes: Array[MeshInstance3D] = []
var _wake_mat: StandardMaterial3D
# a few splashes, used in turn by whichever of them leaps or lands next
var _splashes: Array[Splash] = []
var _splash_next := 0
## How closely the pack keeps to the player and copies it, from 0 (company: each in its own
## place, leaping when it likes) to 1 (in step: drawn in close, leaping when the player leaps,
## as high, and turning every trick the player turns). Set from the flow, by main.
var in_step := 0.0
## Loose: not a pack at all but salmon about their own business, spread far out ahead and to
## either side, each at its own pace, taking no notice of the player. (Set before setup.)
var loose := false
## How many of them are about (the rest wait out of sight): all of them, unless set lower.
var active := 999
var _step := 0.0
var _rng := RandomNumberGenerator.new()


func setup(t: Track, p: Salmon, count: int) -> void:
	track = t
	player = p
	_wake_mat = StandardMaterial3D.new()
	_wake_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wake_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_wake_mat.albedo_color = Color(0.94, 1.0, 0.98)
	_rng.seed = 2468 + (99 if loose else 0)
	var shader := preload("res://shaders/fish.gdshader")
	for i in count:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		var node := MeshInstance3D.new()
		node.material_override = mat
		add_child(node)
		# its wake: a flat V of foam lying on the water behind it (the player's own wake is
		# worked out in the water itself, for every pixel near it: far too dear for a pack)
		var trail := MeshInstance3D.new()
		trail.mesh = _wake_mesh()
		trail.material_override = _wake_mat
		trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		trail.visible = false
		add_child(trail)
		wakes.append(trail)
		_fish.append({"node": node, "mat": mat, "s": 0.0, "x": 0.0, "y": 0.0, "vy": 0.0, "vx": 0.0,
				"n": i, "vs": 20.0, "lane": 0.0, "pace": 1.0, "size": 1.0, "phase": _rng.randf() * TAU, "hop": _rng.randf_range(1.0, 5.0),
				# its place in the pack: how far ahead of the player and how far to one side
				"ahead": lerpf(-7.0, 15.0, (i + 0.5) / count) + _rng.randf_range(-1.5, 1.5),
				"off": (3.0 + _rng.randf_range(0.0, 5.5)) * (1.0 if i % 2 == 0 else -1.0), "deep": 0.0})
	set_look("spawner")
	scatter()


## Matches the school to the stage of life the player is in.
func set_look(look: String) -> void:
	if look == _look:
		return
	_look = look
	var mesh := Props.salmon(look)
	for f: Dictionary in _fish:
		f.size = 1.35 * maxf(Props.salmon_size(look), 0.62) * _rng.randf_range(0.75, 1.05)
		(f.node as MeshInstance3D).mesh = mesh
		(f.node as MeshInstance3D).scale = Vector3.ONE * float(f.size)


## Spreads everyone out around the player (after a restart or a change of level).
func scatter() -> void:
	var foam: Variant = track.mat_water.get_shader_parameter("foam_color") if track.mat_water else null
	if foam != null and _wake_mat:
		_wake_mat.albedo_color = foam
	for f: Dictionary in _fish:
		_place(f, player.s + (_rng.randf_range(-20.0, 80.0) if loose else float(f.ahead)))


func _place(f: Dictionary, at_s: float) -> void:
	f.s = clampf(at_s, 4.0, track.length - 8.0)
	var lim := track.width(f.s) * 0.5 - 2.0
	# near the player, so they are company even where the water is very wide
	f.lane = clampf(player.x + (_rng.randf_range(-30.0, 30.0) if loose else float(f.off)), -lim, lim)
	f.x = f.lane
	f.y = track.surface_y(f.s, f.x)
	f.vy = 0.0
	f.vx = 0.0
	f.vs = maxf(player.speed, 10.0)
	f.pace = _rng.randf_range(0.9, 1.08)


func _process(delta: float) -> void:
	if track == null or player == null or player.state == Salmon.State.IDLE:
		return
	var dt := minf(delta, 1.0 / 15.0)
	_t += dt
	var uphill := track.uphill()
	_step = move_toward(_step, in_step, dt * 1.5)
	# (in step, each one's place is drawn in towards the player)
	var close := lerpf(1.0, 0.5, _step)
	var copying := _step > 0.5 and player.in_air()
	var height := player.y - track.surface_y(player.s, player.x)
	var jumped := player.in_air() and not _was_air
	_was_air = player.in_air()
	# (dived, the player takes the pack down too)
	var depth := 0.0 if loose else track.layer_depth() * player.dive
	for f: Dictionary in _fish:
		if f.has("n"):
			(f.node as MeshInstance3D).visible = int(f.n) < active
			if int(f.n) >= active:
				wakes[int(f.n)].visible = false
				continue
		# out of sight: come back in from the other end
		var gap: float = float(f.s) - player.s
		if gap > (95.0 if loose else AHEAD) or gap < -(30.0 if loose else BEHIND):
			_place(f, player.s + ((_rng.randf_range(55.0, 85.0) if gap < 0.0 else -24.0) if loose else float(f.ahead)))
		var s: float = f.s
		var x: float = f.x
		var y: float = f.y
		var vy: float = f.vy
		var lim := track.width(s) * 0.5 - 1.8
		var vx := 0.0
		if loose:
			s += Salmon.CRUISE * float(f.pace) * dt
			# drift about the lane
			var want := clampf(float(f.lane) + sin(_t * 0.5 + float(f.phase)) * 2.0, -lim, lim)
			want = _round_rocks(s, want)
			vx = clampf((want - x) * 1.5, -9.0, 9.0)
		else:
			# The pack is a flock (boids). Each one steers by three rules about its
			# neighbours, the player among them: keep clear of any that are too close, swim
			# the way and at the speed the others are swimming, and make for the middle of
			# them; and one more that makes it a pack: follow the player. In step, they
			# close up. (Along the course and across it: f.vs and f.vx are its own speed.)
			var here := Vector2(s, x)
			var vel := Vector2(float(f.vs), float(f.vx))
			var apart := lerpf(5.5, 2.4, _step)
			var away := Vector2.ZERO
			var middle := Vector2(player.s, player.x)
			var heading := Vector2(player.speed, player.vx)
			var near := 1
			for g: Dictionary in _fish:
				if g == f or int(g.n) >= active:
					continue
				var there := Vector2(float(g.s), float(g.x))
				var d := here.distance_to(there)
				if d < apart and d > 0.001:
					away += (here - there) / d * (apart - d)
				if d < 14.0:
					middle += there
					heading += Vector2(float(g.vs), float(g.vx))
					near += 1
			var from_player := here - Vector2(player.s, player.x)
			if from_player.length() < apart and from_player.length() > 0.001:
				away += from_player.normalized() * (apart - from_player.length()) * 1.5
			middle /= near
			heading /= near
			# (its own spot to make for is a little off from the player's, so that the pack
			# is all round the player and not in a line behind)
			# (loosely, until the flow is high: then it holds its spot hard)
			var roam := lerpf(1.7, 0.5, _step)
			var spot := Vector2(player.s + float(f.ahead) * 0.6 * roam, player.x + float(f.off) * roam)
			var hold := lerpf(0.7, 4.0, _step)
			# It uses what there is to use on its own account: a rail coming up, or a current,
			# if one is within reach, is where it makes for instead.
			var using := _find_use(f, s, x)
			if not using.is_empty():
				spot.y = float(using.x)
				hold = maxf(hold, 3.5)
			var push := away * 9.0 + (heading - vel) * 1.4 + (middle - here) * lerpf(0.25, 0.5, _step) + Vector2((spot.x - here.x) * maxf(hold, 1.6), (spot.y - here.y) * hold)
			# (and round any rock coming up)
			var clear := _round_rocks(s, x)
			if clear != x:
				push.y += (clear - x) * 12.0
			vel += push.limit_length(60.0) * dt
			vel.x = clampf(vel.x, maxf(player.speed - 12.0, 6.0), player.speed + 14.0)
			vel.y = clampf(vel.y, -14.0, 14.0)
			f.vs = vel.x
			s += vel.x * dt
			vx = vel.y
		x = track.fork_keep(s, clampf(x + vx * dt, -lim, lim))
		var surf := track.surface_y(s, x)
		# (a generous margin: going downhill the surface drops away a little every frame)
		# (a rail it has taken to: along the top of it, and a hop off the far end)
		if f.get("use_kind", "") == "rail" and bool(f.get("on_rail", false)):
			surf = track.water_y(s) + Track.RAIL_H
		var on_water := y <= surf + 0.4 and vy <= 0.0
		if on_water:
			# climbing a ramp carries its lift into the air, like the player
			vy = clampf((surf - y) / dt, 0.0, 14.0) if surf > y else 0.0
			y = surf
			f.hop = float(f.hop) - dt
			# (when the player leaps, so do they, each a moment after)
			if jumped and not loose:
				f.hop = minf(float(f.hop), _rng.randf_range(0.05, 0.6))
			var leap := float(f.hop) < 0.0 and float(f.deep) < 0.2
			if uphill:
				for wf: Dictionary in track.waterfalls:
					var d: float = track.fall_base(wf) - s
					if d > 12.0 and d < 16.0:
						leap = true
			if leap:
				vy = 15.0 if uphill else _rng.randf_range(7.0, 12.0)
				f.hop = _rng.randf_range(2.5, 7.0)
		if not on_water or vy > 0.0:
			vy -= Track.GRAVITY * dt
			y += vy * dt
			if y < surf and vy <= 0.0:
				y = surf
				vy = 0.0
		y = maxf(y, surf) if not uphill else y
		# a salmon that comes up short at a waterfall just tries again from further back
		if uphill and y < surf - 0.8:
			_place(f, s - 40.0)
			continue
		# in step, it is as high out of the water as the player is, when the player is
		if copying and not uphill:
			y = surf + maxf(height, 0.0)
			vy = player.vy
		f.s = s
		f.x = x
		f.y = y
		f.vy = vy
		f.vx = vx
		var air := y > surf + 0.1
		var b := track.basis_at(s) * Basis(Vector3.UP, -atan2(vx, Salmon.CRUISE) * 1.3) \
				* Basis(Vector3.RIGHT, atan2(vy, Salmon.CRUISE) * 0.8 if air else sin(_t * 5.0 + float(f.phase)) * 0.05)
		# ...and turned as the player is turned: every spin, flip and corkscrew
		if copying and air:
			var turned := Basis(Vector3.UP, deg_to_rad(player.yaw)) * Basis(Vector3.RIGHT, deg_to_rad(player.pitch) + atan2(player.vy, maxf(player.speed, 1.0)) * 0.6)
			b = track.basis_at(s) * turned * Basis(Vector3.BACK, deg_to_rad(player.roll))
		var node: MeshInstance3D = f.node
		# (on the swell, like the player)
		# (down with the player; or down into a current of its own)
		var deep_to := depth * (0.8 + 0.25 * sin(float(f.phase)))
		if f.get("use_kind", "") == "current":
			deep_to = float(f.use_depth)
		f.deep = lerpf(float(f.deep), deep_to, 1.0 - exp(-3.0 * dt))
		var lift := track.swell_y(s, x) * (1.0 - smoothstep(0.0, 2.5, y - track.water_y(s))) * (1.0 - smoothstep(0.0, 1.0, float(f.deep))) - (0.0 if air else float(f.deep))
		node.transform = Transform3D(b.scaled(Vector3.ONE * float(f.size)), track.point(s, x, y + lift - (0.0 if air else 0.1)))
		# its wake, on the surface, and a small splash as it leaves the water and as it lands
		var trail := wakes[int(f.n)]
		trail.visible = not air and float(f.deep) < 0.3 and absf(s - player.s) < 70.0 and not bool(f.get("on_rail", false))
		if trail.visible:
			trail.transform = Transform3D(track.basis_at(s) * Basis(Vector3.UP, -atan2(vx, Salmon.CRUISE)), track.point(s, x, track.water_y(s) + track.swell_y(s, x) + 0.05))
		if air != bool(f.get("was_air", false)) and float(f.deep) < 0.3 and absf(s - player.s) < 45.0:
			_splash(s, x, 0.3 if air else 0.45)
		f.was_air = air
		var mat: ShaderMaterial = f.mat
		mat.set_shader_parameter("wag_phase", _t * (6.0 if air else 18.0) + float(f.phase))
		mat.set_shader_parameter("wag_amp", 0.08 if air else 0.12)


# Where across the water to be at `s`, wanting to be at `want`, so as to miss any rock
# coming up.
func _round_rocks(s: float, want: float) -> float:
	for r: Dictionary in track.rocks:
		var d: float = float(r.s) - s
		if d > -2.0 and d < 22.0 and absf(want - float(r.x)) < float(r.r) + 1.6:
			want = float(r.x) + (float(r.r) + 2.2) * (1.0 if want >= float(r.x) else -1.0)
	return want


# The V of a wake: two thin arms of foam opening out behind the fish (which is at the
# point of it, heading -Z), each widening and ending in a point.
static var _wake: ArrayMesh
func _wake_mesh() -> ArrayMesh:
	if _wake == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side: float in [-1.0, 1.0]:
			var tip := Vector3(0.0, 0.0, -0.3)
			var mid_in := Vector3(side * 0.42, 0.0, 1.9)
			var mid_out := Vector3(side * 0.62, 0.0, 1.8)
			var end := Vector3(side * 1.25, 0.0, 4.6)
			for v: Vector3 in [tip, mid_out, mid_in, mid_in, mid_out, end]:
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
		_wake = st.commit()
	return _wake


func _splash(s: float, x: float, strength: float) -> void:
	if _splashes.size() < 3:
		var made := Splash.new()
		add_child(made)
		_splashes.append(made)
	_splash_next = (_splash_next + 1) % _splashes.size()
	_splashes[_splash_next].start(track, s, x, strength)


# Whether there is something here for one of the pack to use on its own account, and where
# across the water it should be to use it: a bamboo rail it can get onto, or a current. Each
# is taken up or passed over once, as it comes within reach (a little over half are taken).
# Sets f.use_kind ("rail", "current" or ""), and for a current f.use_depth; returns {x} or {}.
func _find_use(f: Dictionary, s: float, x: float) -> Dictionary:
	if loose or _step > 0.6:
		f.use_kind = ""
		f.on_rail = false
		return {}
	for r: Dictionary in track.rails:
		var s0: float = r.s0
		if s < s0 - 22.0 or s > float(r.s1):
			continue
		var rx := track.rail_x(r, maxf(s, s0))
		if s < s0:
			# coming up to it: is it near enough to go for, and does this one fancy it?
			if absf(x - rx) > 9.0 or not _fancies(f, s0):
				continue
			# (a hop just before it, to land on it)
			if s > s0 - 6.0 and float(f.vy) == 0.0 and float(f.y) <= track.surface_y(s, x) + 0.1:
				f.vy = 7.5
				f.y = float(f.y) + 0.05
		elif not (f.get("use_kind", "") == "rail" and (bool(f.get("on_rail", false)) or absf(x - rx) < 1.6)):
			continue
		else:
			f.on_rail = true
		f.use_kind = "rail"
		return {"x": rx}
	f.on_rail = false
	for c: Dictionary in track.currents:
		var s0: float = c.s0
		if s < s0 - 20.0 or s > float(c.s1) - 20.0:
			continue
		var cx := track.current_x(c, maxf(s, s0))
		if s < s0 and (absf(x - cx) > 12.0 or not _fancies(f, s0)):
			continue
		if s >= s0 and f.get("use_kind", "") != "current":
			continue
		f.use_kind = "current"
		f.use_depth = track.current_depth(c, maxf(s, s0))
		return {"x": cx}
	f.use_kind = ""
	return {}


# Whether this one takes up the thing that begins at `s0` (made up once for each thing).
func _fancies(f: Dictionary, s0: float) -> bool:
	if float(f.get("asked", -1.0)) != s0:
		f.asked = s0
		f.fancy = _rng.randf() < 0.6
	return f.fancy
