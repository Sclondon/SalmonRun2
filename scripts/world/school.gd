extends Node3D
## The rest of the run: other salmon making the same journey alongside you. They are company,
## not competition: they keep to the water near the player, weave round rocks, ride the ramps,
## leap the falls, and are swapped back in ahead or behind when they drift out of sight.

const Track := preload("res://scripts/world/track.gd")
const Salmon := preload("res://scripts/player/salmon.gd")
const Props := preload("res://scripts/world/props.gd")

const AHEAD := 95.0
const BEHIND := 30.0

var track: Track
var player: Salmon

var _fish: Array[Dictionary] = []
var _look := ""
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func setup(t: Track, p: Salmon, count: int) -> void:
	track = t
	player = p
	_rng.seed = 2468
	var shader := preload("res://shaders/fish.gdshader")
	for i in count:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		var node := MeshInstance3D.new()
		node.material_override = mat
		add_child(node)
		_fish.append({"node": node, "mat": mat, "s": 0.0, "x": 0.0, "y": 0.0, "vy": 0.0, "vx": 0.0,
				"lane": 0.0, "pace": 1.0, "size": 1.0, "phase": _rng.randf() * TAU, "hop": _rng.randf_range(2.0, 9.0)})
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
		_place(f, player.s + _rng.randf_range(-BEHIND * 0.6, AHEAD * 0.6))


func _place(f: Dictionary, at_s: float) -> void:
	f.s = clampf(at_s, 4.0, track.length - 8.0)
	var lim := track.width(f.s) * 0.5 - 2.0
	# near the player, so they are company even where the water is very wide
	f.lane = clampf(player.x + _rng.randf_range(-13.0, 13.0), -lim, lim)
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
	for f: Dictionary in _fish:
		# out of sight: come back in from the other end
		var gap: float = float(f.s) - player.s
		if gap > AHEAD or gap < -BEHIND:
			_place(f, player.s + (_rng.randf_range(AHEAD * 0.6, AHEAD * 0.9) if gap < 0.0 else -BEHIND * 0.8))
		var s: float = f.s
		var x: float = f.x
		var y: float = f.y
		var vy: float = f.vy
		s += Salmon.CRUISE * float(f.pace) * dt
		# drift about the lane, and steer round any rock coming up
		var lim := track.width(s) * 0.5 - 1.8
		var want := clampf(float(f.lane) + sin(_t * 0.5 + float(f.phase)) * 2.0, -lim, lim)
		for r: Dictionary in track.rocks:
			var d: float = float(r.s) - s
			if d > -2.0 and d < 22.0 and absf(want - float(r.x)) < float(r.r) + 1.6:
				want = float(r.x) + (float(r.r) + 2.2) * (1.0 if want >= float(r.x) else -1.0)
		var vx := clampf((want - x) * 1.5, -9.0, 9.0)
		x = clampf(x + vx * dt, -lim, lim)
		var surf := track.surface_y(s, x)
		# (a generous margin: going downhill the surface drops away a little every frame)
		var on_water := y <= surf + 0.4 and vy <= 0.0
		if on_water:
			# climbing a ramp carries its lift into the air, like the player
			vy = clampf((surf - y) / dt, 0.0, 14.0) if surf > y else 0.0
			y = surf
			f.hop = float(f.hop) - dt
			var leap := float(f.hop) < 0.0
			if uphill:
				for wf: Dictionary in track.waterfalls:
					var d: float = track.fall_base(wf) - s
					if d > 12.0 and d < 16.0:
						leap = true
			if leap:
				vy = 15.0 if uphill else _rng.randf_range(7.0, 12.0)
				f.hop = _rng.randf_range(4.0, 12.0)
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
		f.s = s
		f.x = x
		f.y = y
		f.vy = vy
		f.vx = vx
		var air := y > surf + 0.1
		var b := track.basis_at(s) * Basis(Vector3.UP, -atan2(vx, Salmon.CRUISE) * 1.3) \
				* Basis(Vector3.RIGHT, atan2(vy, Salmon.CRUISE) * 0.8 if air else sin(_t * 5.0 + float(f.phase)) * 0.05)
		var node: MeshInstance3D = f.node
		# (on the swell, like the player)
		var lift := track.swell_y(s, x) * (1.0 - smoothstep(0.0, 2.5, y - track.water_y(s)))
		node.transform = Transform3D(b.scaled(Vector3.ONE * float(f.size)), track.point(s, x, y + lift - (0.0 if air else 0.1)))
		var mat: ShaderMaterial = f.mat
		mat.set_shader_parameter("wag_phase", _t * (6.0 if air else 18.0) + float(f.phase))
		mat.set_shader_parameter("wag_amp", 0.08 if air else 0.12)
