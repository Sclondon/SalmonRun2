extends MeshInstance3D
## The salmon's wake: two unbroken bands of foam lying on the water, one off each shoulder,
## that open out behind it into a V and fade, the way the wake of a boat does. It is laid on
## the water where the salmon has been, and stays there.

const Track := preload("res://scripts/world/track.gd")

## Seconds the foam lasts, and how often a new piece is laid.
const LIFE := 1.5
const STEP := 0.035
## How fast each arm moves out from the middle (m/s), and how wide the band of foam gets.
const SPREAD := 2.1
const WIDTH := 0.5

var track: Track

# where the salmon has been: [s, x, time laid, strength], oldest first. A break (an empty
# entry) is where it left the water, so that the two ends are not joined up.
var _trail: Array = []
var _clock := 0.0
var _since := 0.0
var _mesh := ImmediateMesh.new()


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# (drawn after the water it lies on, or the water would be painted over it)
	mat.render_priority = 1
	material_override = mat


## Called every frame by the salmon: where it is, and whether it is cutting the surface (and
## how hard, 0 to 1).
func lay(s: float, x: float, strength: float, delta: float) -> void:
	_clock += delta
	_since += delta
	if strength <= 0.0:
		if not _trail.is_empty() and not (_trail[-1] as Array).is_empty():
			_trail.append([])
	elif _since >= STEP or _trail.is_empty() or (_trail[-1] as Array).is_empty():
		_since = 0.0
		_trail.append([s, x, _clock, strength])
	while not _trail.is_empty() and ((_trail[0] as Array).is_empty() or _clock - float(_trail[0][2]) > LIFE):
		_trail.pop_front()
	_draw(s, x, strength)


func clear() -> void:
	_trail.clear()
	_mesh.clear_surfaces()


func _draw(s: float, x: float, strength: float) -> void:
	_mesh.clear_surfaces()
	if track == null:
		return
	# (the newest piece is always at the salmon itself, so the wake never lags behind it)
	var pieces := _trail.duplicate()
	if strength > 0.0:
		pieces.append([s, x, _clock, strength])
	for side: float in [-1.0, 1.0]:
		var run: Array = []
		for piece: Array in pieces + [[]]:
			if not piece.is_empty():
				run.append(piece)
				continue
			if run.size() >= 2:
				_band(run, side)
			run = []


# One arm of the V, for one unbroken run of the trail.
func _band(run: Array, side: float) -> void:
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for piece: Array in run:
		var age := _clock - float(piece[2])
		var k := age / LIFE
		var ps: float = piece[0]
		# out from the shoulder, further the older it is; the edge is a little ragged
		var inner := 0.28 + SPREAD * age * (1.0 - 0.3 * k) + 0.07 * sin(ps * 1.7 + side)
		var wide := WIDTH * float(piece[3]) * smoothstep(0.0, 0.12, age) * (1.0 - 0.45 * k) + 0.05
		var col := Color(0.94, 1.0, 0.98, pow(1.0 - k, 1.4) * 0.7)
		var y := track.water_y(ps) + 0.07
		_mesh.surface_set_color(col)
		# (it rides the swell with the water it lies on)
		var x0 := float(piece[1]) + side * inner
		var x1 := float(piece[1]) + side * (inner + wide)
		_mesh.surface_add_vertex(track.point(ps, x0, y + track.swell_y(ps, x0)))
		# (the outer edge thins away to nothing)
		_mesh.surface_set_color(Color(col, col.a * 0.25))
		_mesh.surface_add_vertex(track.point(ps, x1, y + track.swell_y(ps, x1)))
	_mesh.surface_end()
