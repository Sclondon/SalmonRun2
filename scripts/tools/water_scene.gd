@tool
extends MeshInstance3D
## A patch of open sea for setting up the water by hand in the editor (scenes/water_scene.tscn).
##
## It builds the same kind of mesh the game does (a few metres to a square, with each corner's
## place in metres and which way is across) and keeps the swell's clock running, so that the
## water moves in the editor as it does in the game. Its material is materials/water.tres:
## every stage starts from that, so what is changed there in the Inspector is what the game
## uses (wherever the stage has no setting of its own: see "water_..." in levels.gd).

## How far the patch reaches, across and along (metres).
@export var size := Vector2(140.0, 240.0):
	set(value):
		size = value
		_build()
## How big its squares are (metres). The game uses 3.5 across and 2 along at most.
@export var cell := Vector2(3.5, 2.0):
	set(value):
		cell = Vector2(maxf(value.x, 0.5), maxf(value.y, 0.5))
		_build()
## Stops the water where it is.
@export var frozen := false

var _clock := 0.0


func _ready() -> void:
	_build()


func _process(delta: float) -> void:
	if not frozen:
		_clock += delta
	RenderingServer.global_shader_parameter_set("water_clock", _clock)


func _build() -> void:
	var cols := maxi(int(size.x / cell.x), 1)
	var rows := maxi(int(size.y / cell.y), 1)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var tangents := PackedFloat32Array()
	var indices := PackedInt32Array()
	for r in rows + 1:
		# (along the course is away from you: -z)
		var s := size.y * r / rows
		for c in cols + 1:
			var x := size.x * (float(c) / cols - 0.5)
			verts.append(Vector3(x, 0.0, -s))
			normals.append(Vector3.UP)
			# (green: open water, with no foam along its edges)
			colours.append(Color(0.0, 1.0, 0.0))
			# the water's mapping runs once across every 26.8 m, as on the game's open sea
			uvs.append(Vector2(0.5 + x / 26.8, s))
			# where it is across, in metres, and all of the swell
			uv2s.append(Vector2(x, 1.0))
			tangents.append_array(PackedFloat32Array([1.0, 0.0, 0.0, 1.0]))
	for r in rows:
		for c in cols:
			var a := r * (cols + 1) + c
			var b := a + 1
			var d := a + cols + 1
			var e := d + 1
			indices.append_array(PackedInt32Array([a, e, b, a, d, e]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_INDEX] = indices
	var made := ArrayMesh.new()
	made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = made
	# (the swell lifts it out of the box it was made in)
	extra_cull_margin = 4.0
