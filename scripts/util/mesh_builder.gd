extends RefCounted
## Tiny flat-shaded mesh builder: every triangle gets its own face normal and colour, which is
## what gives the faceted low-poly look.

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var uvs := PackedVector2Array()


## Adds a triangle. `hint` is a direction the face should point towards (UP for ground,
## outward for props); Vector3.ZERO trusts the given order.
func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, hint := Vector3.ZERO,
		ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO) -> void:
	var raw := (b - a).cross(c - a)
	if raw.length_squared() < 1e-10:
		return
	var n := raw.normalized()
	if hint != Vector3.ZERO and n.dot(hint) < 0.0:
		n = -n
	# Godot treats clockwise triangles as front faces, i.e. the winding whose right-hand-rule
	# normal points away from the viewer.
	if raw.dot(n) > 0.0:
		_emit(a, c, b, ua, uc, ub, n, col)
	else:
		_emit(a, b, c, ua, ub, uc, n, col)


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, hint := Vector3.ZERO,
		ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO, ud := Vector2.ZERO) -> void:
	tri(a, b, c, col, hint, ua, ub, uc)
	tri(a, c, d, col, hint, ua, uc, ud)


## Triangle whose normal points away from `center`.
func tri_out(a: Vector3, b: Vector3, c: Vector3, col: Color, center: Vector3) -> void:
	tri(a, b, c, col, (a + b + c) / 3.0 - center)


func _emit(a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, n: Vector3, col: Color) -> void:
	verts.append(a)
	verts.append(b)
	verts.append(c)
	uvs.append(ua)
	uvs.append(ub)
	uvs.append(uc)
	for i in 3:
		normals.append(n)
		colors.append(col)


func is_empty() -> bool:
	return verts.is_empty()


func build(mesh: ArrayMesh = null) -> ArrayMesh:
	if mesh == null:
		mesh = ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
