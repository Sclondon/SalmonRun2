extends Node3D
## A predator in the salmon's way, striking on every other beat: a grizzly standing in the
## river slamming its paws down (jump over it, or steer wide), or at sea a shark, which
## strikes on no beat: it swims to and fro across the way, at the surface or under it, and is
## to be got round, over or under.


const Props := preload("res://scripts/world/props.gd")

const SWIPE_BEATS := 0.3
## How far under the surface the shark waits between lunges.
const SHARK_DEPTH := 4.4

## 0 or 1: neighbouring predators alternate which beat they strike on.
var beat_offset := 0.0
var kind := "bear"
var _arms: Array[Node3D] = []
var _body: Node3D
## The shark: how far to either side of its place it swims (m), how fast it goes to and fro,
## how far under the surface it keeps (m), and where it is across just now (m from its place,
## the way the course measures across).
var sweep := 8.0
var sweep_rate := 0.9
var depth := 0.5
var across := 0.0
const SHARK_SIZE := 1.5
var _clock := 0.0
var _phase0 := 0.0


func setup(rng: RandomNumberGenerator, mat: Material, predator := "bear") -> void:
	kind = predator
	_body = Node3D.new()
	add_child(_body)
	var body := MeshInstance3D.new()
	body.mesh = Props.shark_whole() if kind == "shark" else Props.bear_body(rng)
	body.material_override = mat
	_body.add_child(body)
	if kind == "shark":
		body.scale = Vector3.ONE * SHARK_SIZE
		_phase0 = rng.randf() * TAU
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


func _process(delta: float) -> void:
	var p := _phase()
	if kind == "shark":
		# to and fro across the salmon's way, turning at each end, with a slow beat of the tail
		_clock += delta
		var a := _clock * sweep_rate + _phase0
		across = sin(a) * sweep
		var going := cos(a)
		_body.position = Vector3(across, -depth, 0.0)
		# (its nose is at -Z: it faces the way it is going, and comes round through the turn)
		_body.rotation.y = -signf(going) * PI * 0.5 * smoothstep(0.0, 0.35, absf(going)) + sin(_clock * 5.0) * 0.12
		return
	var ang: float
	if p < SWIPE_BEATS:
		ang = lerpf(deg_to_rad(165.0), deg_to_rad(35.0), p / SWIPE_BEATS)
	else:
		ang = lerpf(deg_to_rad(35.0), deg_to_rad(165.0), smoothstep(SWIPE_BEATS, 1.7, p))
	for i in _arms.size():
		_arms[i].rotation = Vector3(ang, 0.0, 0.3 if i == 0 else -0.3)
	_body.rotation.x = -0.12 * (1.0 - smoothstep(0.0, 0.6, p))
