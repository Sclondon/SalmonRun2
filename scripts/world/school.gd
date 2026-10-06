extends Node3D
## The rest of the run: a pack of other salmon making the same journey right alongside you,
## each keeping a place of its own round the player. They are company,
## not competition: they keep to the water near the player, weave round rocks, ride the ramps,
## leap the falls, leap when the player leaps and dive when the player dives, and are swapped
## back in close by if they are ever left behind.

const Track := preload("res://scripts/world/track.gd")
const Salmon := preload("res://scripts/player/salmon.gd")
const Props := preload("res://scripts/world/props.gd")

const AHEAD := 45.0
const BEHIND := 22.0

var track: Track
var player: Salmon

var _fish: Array[Dictionary] = []
var _look := ""
var _t := 0.0
var _was_air := false
## How closely the pack keeps to the player and copies it, from 0 (company: each in its own
## place, leaping when it likes) to 1 (in step: drawn in close, leaping when the player leaps,
## as high, and turning every trick the player turns). Set from the flow, by main.
var in_step := 0.0
## Loose: not a pack at all but salmon about their own business, spread far out ahead and to
## either side, each at its own pace, taking no notice of the player. (Set before setup.)
var loose := false
var _step := 0.0
var _rng := RandomNumberGenerator.new()


func setup(t: Track, p: Salmon, count: int) -> void:
	track = t
	player = p
	_rng.seed = 2468 + (99 if loose else 0)
	var shader := preload("res://shaders/fish.gdshader")
	for i in count:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		var node := MeshInstance3D.new()
		node.material_override = mat
		add_child(node)
		_fish.append({"node": node, "mat": mat, "s": 0.0, "x": 0.0, "y": 0.0, "vy": 0.0, "vx": 0.0,
				"lane": 0.0, "pace": 1.0, "size": 1.0, "phase": _rng.randf() * TAU, "hop": _rng.randf_range(1.0, 5.0),
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
		# out of sight: come back in from the other end
		var gap: float = float(f.s) - player.s
		if gap > (95.0 if loose else AHEAD) or gap < -(30.0 if loose else BEHIND):
			_place(f, player.s + ((_rng.randf_range(55.0, 85.0) if gap < 0.0 else -24.0) if loose else float(f.ahead)))
		var s: float = f.s
		var x: float = f.x
		var y: float = f.y
		var vy: float = f.vy
		# it keeps its place in the pack: as fast as the player, and a little faster or slower
		# to get back to where it belongs
		if loose:
			s += Salmon.CRUISE * float(f.pace) * dt
		else:
			s += clampf(player.speed + (player.s + float(f.ahead) * close - s) * lerpf(1.2, 4.0, _step), 8.0, 48.0) * dt
			f.lane = player.x + float(f.off) * close
		# drift about the lane, and steer round any rock coming up
		var lim := track.width(s) * 0.5 - 1.8
		var want := clampf(float(f.lane) + sin(_t * 0.5 + float(f.phase)) * 2.0 * (1.0 - _step), -lim, lim)
		for r: Dictionary in track.rocks:
			var d: float = float(r.s) - s
			if d > -2.0 and d < 22.0 and absf(want - float(r.x)) < float(r.r) + 1.6:
				want = float(r.x) + (float(r.r) + 2.2) * (1.0 if want >= float(r.x) else -1.0)
		var vx := clampf((want - x) * lerpf(1.5, 5.0, _step), -14.0, 14.0)
		x = track.fork_keep(s, clampf(x + vx * dt, -lim, lim))
		var surf := track.surface_y(s, x)
		# (a generous margin: going downhill the surface drops away a little every frame)
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
		f.deep = lerpf(float(f.deep), depth * (0.8 + 0.25 * sin(float(f.phase))), 1.0 - exp(-3.0 * dt))
		var lift := track.swell_y(s, x) * (1.0 - smoothstep(0.0, 2.5, y - track.water_y(s))) * (1.0 - smoothstep(0.0, 1.0, float(f.deep))) - (0.0 if air else float(f.deep))
		node.transform = Transform3D(b.scaled(Vector3.ONE * float(f.size)), track.point(s, x, y + lift - (0.0 if air else 0.1)))
		var mat: ShaderMaterial = f.mat
		mat.set_shader_parameter("wag_phase", _t * (6.0 if air else 18.0) + float(f.phase))
		mat.set_shader_parameter("wag_amp", 0.08 if air else 0.12)
