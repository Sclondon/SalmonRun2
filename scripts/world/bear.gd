extends Node3D
## A predator in the salmon's way, striking on every other beat: a grizzly standing in the
## river slamming its paws down, or (at sea) a shark lunging up out of the water.
## Jump over it (or steer wide) to get past.

const Props := preload("res://scripts/world/props.gd")

const SWIPE_BEATS := 0.3
## How far under the surface the shark waits between lunges.
const SHARK_DEPTH := 4.4

## 0 or 1: neighbouring predators alternate which beat they strike on.
var beat_offset := 0.0
var kind := "bear"
var _arms: Array[Node3D] = []
var _body: Node3D
var _fin: Node3D


func setup(rng: RandomNumberGenerator, mat: Material, predator := "bear") -> void:
	kind = predator
	_body = Node3D.new()
	add_child(_body)
	var body := MeshInstance3D.new()
	body.mesh = Props.shark_body(rng) if kind == "shark" else Props.bear_body(rng)
	body.material_override = mat
	_body.add_child(body)
	if kind == "shark":
		var fin := MeshInstance3D.new()
		fin.mesh = Props.shark_fin()
		fin.material_override = mat
		_fin = fin
		add_child(fin)
		return
	var arm_mesh := Props.bear_arm(rng)
	for sx: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(sx * 0.9, 2.05, -0.1)
		_body.add_child(pivot)
		var arm := MeshInstance3D.new()
		arm.mesh = arm_mesh
		arm.material_override = mat
		pivot.add_child(arm)
		_arms.append(pivot)


func _phase() -> float:
	return fposmod(Music.beat_float() + beat_offset, 2.0)


func is_swiping() -> bool:
	return _phase() < SWIPE_BEATS


func _process(_delta: float) -> void:
	var p := _phase()
	if kind == "shark":
		# up on the beat, sink away, then nose back up as a warning before the next one
		var depth: float
		if p < SWIPE_BEATS:
			depth = lerpf(1.2, 0.0, p / SWIPE_BEATS)
		elif p < 1.4:
			depth = lerpf(0.0, SHARK_DEPTH, smoothstep(SWIPE_BEATS, 1.0, p))
		else:
			depth = lerpf(SHARK_DEPTH, 1.2, smoothstep(1.4, 2.0, p))
		_body.position.y = -depth
		_body.rotation.y = sin(p * PI) * 0.25
		# the fin circles while the shark is down
		var a := Music.beat_float() * 0.9 + beat_offset * PI
		_fin.position = Vector3(cos(a) * 1.5, 0.0, sin(a) * 1.5)
		_fin.rotation.y = -a
		_fin.visible = depth > 2.0
		return
	var ang: float
	if p < SWIPE_BEATS:
		ang = lerpf(deg_to_rad(165.0), deg_to_rad(35.0), p / SWIPE_BEATS)
	else:
		ang = lerpf(deg_to_rad(35.0), deg_to_rad(165.0), smoothstep(SWIPE_BEATS, 1.7, p))
	for i in _arms.size():
		_arms[i].rotation = Vector3(ang, 0.0, 0.3 if i == 0 else -0.3)
	_body.rotation.x = -0.12 * (1.0 - smoothstep(0.0, 0.6, p))
