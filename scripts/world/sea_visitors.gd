extends Node3D
## Other animals of the open sea, each with a chance of turning up on a stage of salt water:
## a leatherback turtle or two paddling slowly along, a humpback whale off to one side that
## rolls up to breathe and now and then throws itself out of the water, and a few Pacific
## bluefin tuna that come up from behind and go by faster than the salmon can swim. They are
## scenery: nothing touches them. Which of them a stage has is rolled afresh every time the
## stage is begun (see scatter).

const Track := preload("res://scripts/world/track.gd")
const Salmon := preload("res://scripts/player/salmon.gd")
const Props := preload("res://scripts/world/props.gd")

## For each kind: its chance of being about on a stage, how many of them, and how big they
## are drawn (the meshes are made about life size already). "few" of them are about when a
## stage has the kind at all; the rest, up to "count", join them as the score climbs. And a
## kind the stage did not have turns up anyway once the score is high enough (see abundance).
const KINDS := {
	"turtle": {"chance": 0.6, "count": 4, "few": 1, "size": 1.1},
	"whale": {"chance": 0.45, "count": 2, "few": 1, "size": 1.7},
	"tuna": {"chance": 0.9, "count": 9, "few": 4, "size": 1.25},
	# (in fresh water; the golden trout is a rare one: touch it and it joins the pack)
	"trout": {"chance": 0.75, "count": 7, "few": 3, "size": 1.0, "fresh": true},
	"sturgeon": {"chance": 0.5, "count": 3, "few": 1, "size": 1.0, "fresh": true},
	"golden": {"chance": 0.22, "count": 1, "few": 1, "size": 1.15, "fresh": true, "rare": true},
	# (down in the abyss: anglerfish, each hanging in the dark behind its light)
	"angler": {"chance": 1.0, "count": 7, "few": 4, "size": 1.6, "deep": true},
}

var track: Track
var player: Salmon

## How well the stage is going, from 0 to 1 (set from the score, by main): the more, the
## more animals are about.
var abundance := 0.0

## The salmon has touched the golden trout (which is then gone from here: see world.gd).
signal befriended

var _animals: Array[Dictionary] = []
# for each kind: whether the stage has it from the start, and the score it turns up at anyway
var _about := {}
var _turns_up := {}
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func setup(t: Track, p: Salmon) -> void:
	track = t
	player = p
	_rng.randomize()
	var meshes := {"turtle": Props.turtle(), "whale": Props.whale(), "tuna": Props.tuna(), "trout": Props.trout(), "sturgeon": Props.sturgeon(), "golden": Props.trout(true), "angler": Props.angler()}
	for kind: String in KINDS:
		for i in int(KINDS[kind].count):
			var node := MeshInstance3D.new()
			node.mesh = meshes[kind]
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.visible = false
			add_child(node)
			# (a whale bends as it swims, tail up and down in a slow wave: see fish.gdshader)
			var bends: ShaderMaterial = null
			if kind == "whale":
				bends = ShaderMaterial.new()
				bends.shader = preload("res://shaders/fish.gdshader")
				bends.set_shader_parameter("wag_amp", 0.0)
				bends.set_shader_parameter("heave", 0.75)
				bends.set_shader_parameter("body", 7.0)
			_animals.append({"node": node, "kind": kind, "i": i, "here": false, "s": 0.0, "x": 0.0, "mat": bends,
					"depth": 1.0, "pace": 1.0, "phase": _rng.randf() * TAU})
	scatter()


## Rolls which animals this stage has, and sets them down (after a change of stage).
func scatter() -> void:
	var salt := bool(track.cfg.get("salt", false))
	_about = {}
	for kind: String in KINDS:
		# (each in its own water: those of the sea in salt, trout and sturgeon in fresh)
		var at_home: bool = salt != bool(KINDS[kind].get("fresh", false))
		# (and those of the deep only on a stage swum all under the water)
		if KINDS[kind].get("deep", false):
			at_home = bool(track.cfg.get("submerged", false))
		_about[kind] = at_home and _rng.randf() < float(KINDS[kind].chance)
		# (on the open ocean there is always the one whale: it leads the way to the abyss)
		if kind == "whale" and _guiding():
			_about[kind] = true
		# (a rare one is there or it is not: no score brings it)
		_turns_up[kind] = _rng.randf_range(0.25, 0.9) if at_home and not KINDS[kind].get("rare", false) else 9.0
	for a: Dictionary in _animals:
		a.here = false
		(a.node as MeshInstance3D).visible = false
		(a.node as MeshInstance3D).material_override = a.mat if a.mat != null else track.mat_world


# Sets one down where it will next be met: ahead of the salmon (or, the tuna, behind it).
func _place(a: Dictionary, first: bool) -> void:
	var lim := track.width(player.s) * 0.5
	match a.kind:
		"trout", "golden":
			# one here, one there, holding in the stream or nosing along it, under the surface
			a.s = player.s + _rng.randf_range(60.0, 240.0) + (0.0 if first else 120.0) + (200.0 if a.kind == "golden" else 0.0)
			a.x = _rng.randf_range(-0.8, 0.8) * maxf(lim - 2.5, 1.0)
			a.depth = _rng.randf_range(0.35, minf(1.2, track.layer_depth()))
			a.pace = _rng.randf_range(4.0, 14.0)
		"angler":
			# down near the floor, off to one side or the other, drifting hardly at all
			a.s = player.s + _rng.randf_range(70.0, 260.0) + (0.0 if first else 150.0)
			a.x = _rng.randf_range(-0.85, 0.85) * maxf(lim - 4.0, 1.0)
			a.depth = _rng.randf_range(0.45, 0.95) * track.layers() * track.layer_depth()
			a.pace = _rng.randf_range(0.5, 2.0)
		"sturgeon":
			# a great slow fish, down on the bed
			a.s = player.s + _rng.randf_range(150.0, 400.0) + (0.0 if first else 250.0) + int(a.i) * 180.0
			a.x = _rng.randf_range(-0.6, 0.6) * maxf(lim - 3.0, 1.0)
			a.depth = maxf(track.layers() * track.layer_depth() + 0.5, 1.5)
			a.pace = _rng.randf_range(1.0, 2.5)
		"turtle":
			a.s = player.s + _rng.randf_range(120.0, 320.0) + (0.0 if first else 250.0) + int(a.i) * 260.0
			a.x = _rng.randf_range(-0.6, 0.6) * (lim - 6.0)
			a.depth = _rng.randf_range(0.5, 2.6)
			a.pace = _rng.randf_range(1.5, 3.0)
		"whale":
			a.s = player.s + _rng.randf_range(200.0, 500.0) + (0.0 if first else 300.0)
			# (well off to one side: it is far too big to have in the way)
			a.x = (1.0 if _rng.randf() < 0.5 else -1.0) * maxf(lim + _rng.randf_range(-12.0, 25.0), 30.0)
			a.depth = 3.0
			a.pace = _rng.randf_range(4.0, 7.0)
		"tuna":
			# (all of them together, in a loose arrowhead)
			if int(a.i) == 0:
				a.s = player.s - _rng.randf_range(60.0, 110.0)
				a.x = _rng.randf_range(-0.5, 0.5) * (lim - 8.0)
				a.depth = _rng.randf_range(0.8, 3.0)
				a.pace = 0.0
			else:
				var lead: Dictionary = _animals.filter(func(b: Dictionary) -> bool: return b.kind == "tuna" and int(b.i) == 0)[0]
				var row := (int(a.i) + 1) / 2
				a.s = float(lead.s) - row * 3.2
				a.x = float(lead.x) + row * 2.4 * (1.0 if int(a.i) % 2 == 1 else -1.0)
				a.depth = float(lead.depth) + _rng.randf_range(-0.3, 0.5)
				a.pace = 0.0


func _process(delta: float) -> void:
	if track == null or player == null:
		return
	var dt := minf(delta, 1.0 / 15.0)
	_t += dt
	for a: Dictionary in _animals:
		var node: MeshInstance3D = a.node
		if a.mat != null:
			(a.mat as ShaderMaterial).set_shader_parameter("wag_phase", _t * 1.6 + float(a.phase))
		# (is it about yet? More of each kind as the score climbs)
		var rule: Dictionary = KINDS[a.kind]
		var wanted := 0
		if _about.get(a.kind, false) or abundance >= float(_turns_up.get(a.kind, 9.0)):
			wanted = int(rule.few) + int(roundf((int(rule.count) - int(rule.few)) * abundance))
		if int(a.i) < wanted and not a.here:
			a.here = true
			_place(a, true)
		if not a.here:
			node.visible = false
			continue
		var gap: float = float(a.s) - player.s
		# gone by (or, the tuna, gone on ahead out of sight): met again further on
		var leads: bool = a.kind == "whale" and int(a.i) == 0 and _guiding()
		# (the tuna stay with the salmon: they are only set down afresh if left far behind)
		if not leads and ((a.kind == "tuna" and absf(gap) > 220.0) or (a.kind != "tuna" and gap < -40.0)):
			_place(a, false)
			gap = float(a.s) - player.s
		a.s = float(a.s) + float(a.pace) * dt
		var s: float = a.s
		node.visible = gap > -60.0 and gap < 260.0 and s > 4.0 and s < track.length - 8.0 and not track.near_fall(s, 30.0, 30.0)
		if not node.visible and not leads:
			continue
		var phase: float = a.phase
		var depth: float = a.depth
		var tilt := 0.0
		var roll := 0.0
		var sway := 0.0
		match a.kind:
			"trout", "golden":
				sway = sin(_t * 8.0 + phase) * 0.14
				depth += sin(_t * 0.8 + phase) * 0.12
				# the golden one: touched, it is the salmon's friend, and goes with the pack
				if a.kind == "golden" and absf(s - player.s) < 2.6 and absf(float(a.x) - player.x) < 2.2 \
						and absf(player.y - (track.water_y(s) - depth)) < 2.0:
					a.here = false
					_about["golden"] = false
					node.visible = false
					befriended.emit()
					continue
			"angler":
				# (it turns to watch the salmon go by, and bobs a little)
				sway = clampf((player.x - float(a.x)) * 0.04, -0.7, 0.7) + PI
				depth += sin(_t * 0.9 + phase) * 0.3
			"sturgeon":
				sway = sin(_t * 1.6 + phase) * 0.1
			"turtle":
				# paddling: it rises and sinks a little with each stroke, and rocks
				depth += sin(_t * 1.6 + phase) * 0.25
				roll = sin(_t * 1.6 + phase) * 0.12
				tilt = cos(_t * 1.6 + phase) * 0.06
			"tuna":
				sway = sin(_t * 9.0 + phase) * 0.1
				# They chase the salmon: up from behind, fast, and then round it, now ahead and
				# now beside, each keeping a place of its own in the pack of them.
				var row := (int(a.i) + 1) / 2
				var wing := 1.0 if int(a.i) % 2 == 1 else -1.0
				var want_s := player.s - 5.0 - row * 3.4 + sin(_t * 0.35 + phase) * 9.0
				var want_x := player.x + (4.5 + row * 2.6) * wing + sin(_t * 0.5 + phase * 1.7) * 2.5
				a.s = float(a.s) + clampf(player.speed + (want_s - float(a.s)) * 1.4, 6.0, Salmon.CRUISE + 20.0) * dt - float(a.pace) * dt
				a.x = lerpf(float(a.x), want_x, 1.0 - exp(-1.2 * dt))
				a.depth = lerpf(float(a.depth), maxf(track.layer_depth() * player.dive, 0.0) + 0.6 + 0.4 * row, 1.0 - exp(-1.5 * dt))
				s = float(a.s)
				depth = float(a.depth)
			"whale":
				# The one that leads the way (the open ocean): it keeps ahead of the salmon, a little
				# to one side, makes for the giant current as the ship comes up, and goes down it.
				if int(a.i) == 0 and _guiding() and player.s < track.course * 0.5:
					# (it has not turned up yet: half way through the stage it does, from ahead)
					a.s = player.s + 190.0
					a.x = player.x + 30.0
					node.visible = false
					continue
				if int(a.i) == 0 and _guiding():
					var down: Dictionary = _abyss()
					var want := player.s + 46.0
					a.s = lerpf(float(a.s), want, 1.0 - exp(-1.5 * dt)) if absf(float(a.s) - want) < 200.0 else want
					s = float(a.s)
					var near := smoothstep(float(down.s0) - 700.0, float(down.s0) - 120.0, s)
					a.x = lerpf(float(a.x), lerpf(player.x + 16.0, track.current_x(down, maxf(s, float(down.s0))), near), 1.0 - exp(-0.8 * dt))
					# (its back is always out of the water, to be followed; it rolls higher to breathe)
					var breathe := 1.5 - 1.3 * maxf(sin(_t * 0.5 + phase), 0.0)
					depth = breathe * float(KINDS[a.kind].size)
					tilt = cos(_t * 0.5 + phase) * 0.1
					if s > float(down.s0) - 30.0:
						var into := smoothstep(float(down.s0) - 30.0, float(down.s0) + 40.0, s)
						depth = lerpf(breathe, track.current_depth(down, s) + 1.0, into)
						tilt = -0.3 * into
					node.visible = s < track.length - 8.0
					node.transform = Transform3D((track.basis_at(s) * Basis(Vector3.RIGHT, tilt)).scaled(Vector3.ONE * float(KINDS[a.kind].size)), track.point(s, float(a.x), track.water_y(s) - depth))
					_blow(node, s, float(a.x), dt)
					continue
				# It rolls up to breathe, its back clear of the water, and sinks away again; and
				# once in a while it comes up fast instead and throws most of itself out.
				var turn := fposmod(_t * 0.09 + phase, 1.0)
				if int((_t * 0.09 + phase) / 1.0) % 3 == 2:
					var leap := sin(clampf((turn - 0.35) / 0.3, 0.0, 1.0) * PI)
					depth = lerpf(6.0, -4.5, leap)
					tilt = lerpf(0.0, 0.9, leap) * (1.0 if turn < 0.5 else -0.4)
					roll = leap * 0.5
				else:
					depth = 5.0 - 4.2 * sin(clampf((turn - 0.2) / 0.5, 0.0, 1.0) * PI)
					tilt = cos(clampf((turn - 0.2) / 0.5, 0.0, 1.0) * PI) * 0.18
		var b := track.basis_at(s) * Basis(Vector3.UP, sway) * Basis(Vector3.RIGHT, tilt) * Basis(Vector3.BACK, roll)
		node.transform = Transform3D(b.scaled(Vector3.ONE * float(KINDS[a.kind].size)), track.point(s, float(a.x), track.water_y(s) - depth))


# Whether this stage has a whale that leads the way: the one with the way down to the abyss.
func _guiding() -> bool:
	return track != null and not track.fork.is_empty() and bool(track.fork.get("abyss", false)) and not _abyss().is_empty()


# The giant current down to the abyss, on the stage that has one.
func _abyss() -> Dictionary:
	for c: Dictionary in track.currents:
		if c.get("abyss", false):
			return c
	return {}


# The whale's spout: every so often it blows, a column of spray straight up out of its
# blowhole for a couple of seconds. Swim into it and it throws the salmon high into the air.
var _spout: CPUParticles3D
var _blow_t := 0.0
func _blow(whale: MeshInstance3D, s: float, x: float, dt: float) -> void:
	if _spout == null:
		_spout = CPUParticles3D.new()
		var drop := SphereMesh.new()
		drop.radius = 0.5
		drop.height = 1.0
		drop.radial_segments = 5
		drop.rings = 2
		var white := StandardMaterial3D.new()
		white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		white.albedo_color = Color(0.94, 1.0, 1.0)
		drop.material = white
		_spout.mesh = drop
		_spout.amount = 90
		_spout.lifetime = 1.3
		_spout.local_coords = false
		_spout.direction = Vector3.UP
		_spout.spread = 9.0
		_spout.initial_velocity_min = 16.0
		_spout.initial_velocity_max = 24.0
		_spout.gravity = Vector3(0, -22.0, 0)
		_spout.scale_amount_min = 0.25
		_spout.scale_amount_max = 0.7
		_spout.emitting = false
		add_child(_spout)
	_blow_t += dt
	var blowing := fposmod(_blow_t, 7.0) < 2.2 and whale.visible
	var hole := whale.global_transform * Vector3(0.0, 1.2, -4.4)
	hole.y = maxf(hole.y, track.water_y(s))
	_spout.global_position = hole
	_spout.emitting = blowing
	if blowing and player.global_position.distance_to(Vector3(hole.x, player.global_position.y, hole.z)) < 4.5 and absf(player.y - track.water_y(player.s)) < 1.5:
		player.launch(27.0)
