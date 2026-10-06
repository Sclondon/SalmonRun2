extends Node3D
## The weather of a stage (its "weather" in levels.gd; none where there is no such key):
## "rain" is rain, falling in long thin streaks all round the eye, a little aslant, and
## "snow" is snow, drifting down. It goes wherever the camera goes.

var camera: Camera3D

var _fall: CPUParticles3D
var _kind := ""


func _ready() -> void:
	_fall = CPUParticles3D.new()
	_fall.local_coords = false
	_fall.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_fall.emission_box_extents = Vector3(26, 1, 26)
	_fall.spread = 3.0
	_fall.emitting = false
	add_child(_fall)


## Sets the weather: "rain", "snow", or "" for none.
func set_kind(kind: String) -> void:
	if kind == _kind:
		return
	_kind = kind
	_fall.emitting = kind != ""
	if kind == "":
		return
	var streak := BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak.material = mat
	_fall.mesh = streak
	if kind == "rain":
		streak.size = Vector3(0.03, 0.9, 0.03)
		mat.albedo_color = Color(0.8, 0.88, 0.95)
		_fall.amount = 260 if Save.is_mobile() else 600
		_fall.lifetime = 0.8
		_fall.direction = Vector3(0.12, -1.0, 0.05)
		_fall.initial_velocity_min = 26.0
		_fall.initial_velocity_max = 32.0
		_fall.gravity = Vector3.ZERO
	else:
		streak.size = Vector3(0.09, 0.09, 0.09)
		mat.albedo_color = Color(1.0, 1.0, 1.0)
		_fall.amount = 160 if Save.is_mobile() else 380
		_fall.lifetime = 5.0
		_fall.direction = Vector3(0.3, -1.0, 0.1)
		_fall.spread = 25.0
		_fall.initial_velocity_min = 2.5
		_fall.initial_velocity_max = 4.5
		_fall.gravity = Vector3.ZERO


func _process(_delta: float) -> void:
	if camera == null or _kind == "":
		return
	# (let go above and a little ahead of the eye, so that it is falling through the picture)
	var ahead := -camera.global_transform.basis.z
	ahead.y = 0.0
	_fall.global_position = camera.global_position + ahead.normalized() * 14.0 + Vector3.UP * (16.0 if _kind == "rain" else 9.0)
