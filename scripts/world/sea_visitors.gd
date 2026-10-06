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
	"whale": {"chance": 0.45, "count": 2, "few": 1, "size": 1.0},
	"tuna": {"chance": 0.6, "count": 9, "few": 3, "size": 1.0},
}

var track: Track
var player: Salmon

## How well the stage is going, from 0 to 1 (set from the score, by main): the more, the
## more animals are about.
var abundance := 0.0

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
	var meshes := {"turtle": Props.turtle(), "whale": Props.whale(), "tuna": Props.tuna()}
	for kind: String in KINDS:
		for i in int(KINDS[kind].count):
			var node := MeshInstance3D.new()
			node.mesh = meshes[kind]
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.visible = false
			add_child(node)
			_animals.append({"node": node, "kind": kind, "i": i, "here": false, "s": 0.0, "x": 0.0,
					"depth": 1.0, "pace": 1.0, "phase": _rng.randf() * TAU})
	scatter()


## Rolls which animals this stage has, and sets them down (after a change of stage).
func scatter() -> void:
	var salt := bool(track.cfg.get("salt", false))
	_about = {}
	for kind: String in KINDS:
		_about[kind] = salt and _rng.randf() < float(KINDS[kind].chance)
		_turns_up[kind] = _rng.randf_range(0.25, 0.9) if salt else 9.0
	for a: Dictionary in _animals:
		a.here = false
		(a.node as MeshInstance3D).visible = false
		(a.node as MeshInstance3D).material_override = track.mat_world


# Sets one down where it will next be met: ahead of the salmon (or, the tuna, behind it).
func _place(a: Dictionary, first: bool) -> void:
	var lim := track.width(player.s) * 0.5
	match a.kind:
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
				a.s = player.s - _rng.randf_range(120.0, 420.0)
				a.x = _rng.randf_range(-0.5, 0.5) * (lim - 8.0)
				a.depth = _rng.randf_range(0.8, 3.0)
				a.pace = Salmon.CRUISE + _rng.randf_range(9.0, 15.0)
			else:
				var lead: Dictionary = _animals.filter(func(b: Dictionary) -> bool: return b.kind == "tuna" and int(b.i) == 0)[0]
				var row := (int(a.i) + 1) / 2
				a.s = float(lead.s) - row * 3.2
				a.x = float(lead.x) + row * 2.4 * (1.0 if int(a.i) % 2 == 1 else -1.0)
				a.depth = float(lead.depth) + _rng.randf_range(-0.3, 0.5)
				a.pace = lead.pace


func _process(delta: float) -> void:
	if track == null or player == null:
		return
	var dt := minf(delta, 1.0 / 15.0)
	_t += dt
	for a: Dictionary in _animals:
		var node: MeshInstance3D = a.node
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
		if (a.kind == "tuna" and gap > 170.0) or (a.kind != "tuna" and gap < -40.0):
			_place(a, false)
			gap = float(a.s) - player.s
		a.s = float(a.s) + float(a.pace) * dt
		var s: float = a.s
		node.visible = gap > -60.0 and gap < 260.0 and s > 4.0 and s < track.length - 8.0 and not track.near_fall(s, 30.0, 30.0)
		if not node.visible:
			continue
		var phase: float = a.phase
		var depth: float = a.depth
		var tilt := 0.0
		var roll := 0.0
		var sway := 0.0
		match a.kind:
			"turtle":
				# paddling: it rises and sinks a little with each stroke, and rocks
				depth += sin(_t * 1.6 + phase) * 0.25
				roll = sin(_t * 1.6 + phase) * 0.12
				tilt = cos(_t * 1.6 + phase) * 0.06
			"tuna":
				sway = sin(_t * 9.0 + phase) * 0.1
			"whale":
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
