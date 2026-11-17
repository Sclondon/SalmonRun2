extends Node3D
## Sockeye salmon over a grey floor: a spawning male swimming slowly round in a circle
## (moved here, and told how fast with `step`), and inside the circle the other six
## stages of its life in a row, side on, holding their places (their `phase` set by
## hand, as a looping picture would; the last two are bare meshes and materials from
## `mesh_of` and `new_material`, as a game that keeps its own MeshInstance3Ds would
## have them). Every stage is shown the same length: SockeyeSalmon.SIZE says how long
## each really is. Give this to a Node3D at the root of an empty scene and play it.

var swimmer: SockeyeSalmon
var holders: Array[SockeyeSalmon] = []
var bare: Array[ShaderMaterial] = []
var _clock := 0.0


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.3, 0.36)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.7, 0.75)
	env.environment.ambient_light_energy = 0.6
	add_child(env)
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.look_at_from_position(Vector3(1, 4, 2), Vector3.ZERO)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(10, 10)
	floor.mesh = plane
	floor.position.y = -0.5
	add_child(floor)
	swimmer = SockeyeSalmon.new()
	add_child(swimmer)
	var row := [
		SockeyeSalmon.Stage.FRY, SockeyeSalmon.Stage.PARR, SockeyeSalmon.Stage.SMOLT, SockeyeSalmon.Stage.OCEAN,
		SockeyeSalmon.Stage.MIGRATING, SockeyeSalmon.Stage.SPAWNER_FEMALE,
	]
	for i in row.size():
		var at := Vector3((i % 3 - 1) * 0.75, 0.22 - 0.42 * (i / 3), 0.0)
		if i < 4:
			var holder := SockeyeSalmon.new()
			holder.stage = row[i]
			holder.swim = 0.35
			add_child(holder)
			holder.position = at
			# (side on to the camera, nose to the left)
			holder.rotation.y = PI * 0.5
			holders.append(holder)
		else:
			var mesh := MeshInstance3D.new()
			mesh.mesh = SockeyeSalmon.mesh_of(row[i], true)
			var material := SockeyeSalmon.new_material(row[i], true)
			material.set_shader_parameter(&"swim", 0.35)
			mesh.material_override = material
			add_child(mesh)
			mesh.position = at
			mesh.rotation.y = PI * 0.5
			bare.append(material)
	var camera := Camera3D.new()
	camera.fov = 40.0
	add_child(camera)
	camera.look_at_from_position(Vector3(0, 0.5, 3.4), Vector3(0, 0, 0))


func _process(delta: float) -> void:
	_clock += delta
	# The swimmer goes round the others, nose first.
	var angle := _clock * 0.5
	var was := swimmer.global_position
	swimmer.global_position = Vector3(cos(angle), 0.0, sin(angle)) * 1.5 + Vector3(0, -0.2, 0)
	var going := Vector3(-sin(angle), 0.0, cos(angle))
	swimmer.look_at(swimmer.global_position + going, Vector3.UP)
	swimmer.step((swimmer.global_position - was) / maxf(delta, 0.0001), delta)
	# The holders' beats set by hand: each comes round again every `beat` seconds exactly.
	for holder in holders:
		holder.phase = fposmod(_clock / holder.beat, 1.0)
	for material in bare:
		material.set_shader_parameter(&"phase", fposmod(_clock / 2.4, 1.0))
