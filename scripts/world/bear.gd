extends Node3D
## A grizzly standing in the river, slamming its paws down on every other beat.
## Jump over it (or steer wide) to get past.

const Props := preload("res://scripts/world/props.gd")

const SWIPE_BEATS := 0.3

## 0 or 1: neighbouring bears alternate which beat they swipe on.
var beat_offset := 0.0
var _arms: Array[Node3D] = []
var _body: Node3D


func setup(rng: RandomNumberGenerator, mat: Material) -> void:
	_body = Node3D.new()
	add_child(_body)
	var body := MeshInstance3D.new()
	body.mesh = Props.bear_body(rng)
	body.material_override = mat
	_body.add_child(body)
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
	var ang: float
	if p < SWIPE_BEATS:
		ang = lerpf(deg_to_rad(165.0), deg_to_rad(35.0), p / SWIPE_BEATS)
	else:
		ang = lerpf(deg_to_rad(35.0), deg_to_rad(165.0), smoothstep(SWIPE_BEATS, 1.7, p))
	for i in _arms.size():
		_arms[i].rotation = Vector3(ang, 0.0, 0.3 if i == 0 else -0.3)
	_body.rotation.x = -0.12 * (1.0 - smoothstep(0.0, 0.6, p))
