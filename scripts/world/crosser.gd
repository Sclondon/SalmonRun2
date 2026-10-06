extends Node3D
## A boat that crosses the course from one side to the other and back, across the salmon's
## way: a work boat in a harbour. It is on the surface: go round it, or dive under it. (The
## salmon asks where it is: `across`, metres from the middle of the course.)

const Props := preload("res://scripts/world/props.gd")

## How far to either side of the middle it goes, how long one crossing takes (seconds), and
## how big it is drawn.
var reach := 20.0
var crossing := 7.0
var size := 1.0
## Where it is just now, across the course (metres from the middle).
var across := 0.0

var _boat: MeshInstance3D
var _wash: CPUParticles3D
var _clock := 0.0
var _start := 0.0


func setup(rng: RandomNumberGenerator, mat: Material) -> void:
	_start = rng.randf() * TAU
	_boat = MeshInstance3D.new()
	_boat.mesh = Props.boat(rng)
	_boat.material_override = mat
	_boat.scale = Vector3.ONE * size
	add_child(_boat)
	# the white water it leaves behind it
	_wash = CPUParticles3D.new()
	var speck := BoxMesh.new()
	speck.size = Vector3.ONE * 0.35
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color = Color(0.94, 1.0, 0.98)
	speck.material = white
	_wash.mesh = speck
	_wash.amount = 26
	_wash.lifetime = 0.9
	_wash.local_coords = false
	_wash.direction = Vector3.UP
	_wash.spread = 50.0
	_wash.initial_velocity_min = 1.0
	_wash.initial_velocity_max = 3.0
	_wash.gravity = Vector3(0, -9.0, 0)
	_wash.scale_amount_min = 0.5
	_wash.scale_amount_max = 1.2
	add_child(_wash)


func _process(delta: float) -> void:
	_clock += delta
	var a := _clock * PI / crossing + _start
	across = sin(a) * reach
	var going := cos(a)
	# (this node faces along the course: across it is its own X. The boat points the way it
	# is going, and comes round at each end.)
	_boat.position = Vector3(across, 0.05 + sin(_clock * 2.0) * 0.06, 0.0)
	_boat.rotation.y = -signf(going) * PI * 0.5 * smoothstep(0.0, 0.3, absf(going))
	_wash.position = Vector3(across - signf(going) * 2.2 * size, 0.1, 0.0)
	_wash.emitting = absf(going) > 0.3
