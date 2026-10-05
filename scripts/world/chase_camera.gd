extends Camera3D
## Follows the salmon in track space. Mode FOLLOW is the gameplay chase cam; mode CINEMA cycles
## through a few TV-style angles for the title screen.

enum Mode { FOLLOW, CINEMA }

const Track := preload("res://scripts/world/track.gd")
const Salmon := preload("res://scripts/player/salmon.gd")

var player: Salmon
var track: Track
var mode := Mode.FOLLOW
var shake := 0.0

## How far to the side of the camera the salmon may get before the camera follows.
const VIEW_EDGE := 7.5

var _pos := Vector3.ZERO
var _look := Vector3.ZERO
var _has_pos := false
var _cx := 0.0  # where the camera is across the course
var _cine_t := 0.0
var _cine_kind := 0


func snap() -> void:
	_has_pos = false


func _process(delta: float) -> void:
	if player == null or track == null:
		return
	var dt := minf(delta, 0.05)
	var p := player
	var fwd := track.forward(p.s)
	var target := p.global_position
	var desired: Vector3
	var look: Vector3
	var cam_s: float
	if mode == Mode.CINEMA:
		_cine_t += dt
		if _cine_t > 6.0:
			_cine_t = 0.0
			_cine_kind = (_cine_kind + 1) % 3
			_has_pos = false
		match _cine_kind:
			0:
				cam_s = p.s - 11.0
				desired = track.point(cam_s, p.x * 0.5, maxf(track.water_y(cam_s) + 3.5, p.y + 2.5))
			1:
				cam_s = p.s + 3.0
				var side := 9.0 if p.x < 0.0 else -9.0
				desired = track.point(cam_s, p.x + side, track.water_y(cam_s) + 1.6)
			_:
				cam_s = p.s + 16.0
				desired = track.point(cam_s, p.x * 0.3 + 3.0, track.water_y(cam_s) + 2.2)
		look = target
	else:
		cam_s = p.s - (6.0 + p.speed * 0.05)
		# The camera only drifts a little with the salmon and looks down the river rather than
		# at the fish, so the salmon really crosses the screen (and can swim to a finger).
		var cx := p.x * 0.2
		if track.lane_room() > 0.0:
			# Open water much wider than a river has no middle to hang about: the camera
			# stays put while the salmon is in view, and goes with it once it nears the edge.
			# (So a finger held near the edge keeps it swimming that way, and a finger
			# anywhere else parks it there.)
			_cx = clampf(_cx, p.x - VIEW_EDGE, p.x + VIEW_EDGE)
			cx = _cx
		else:
			_cx = cx
		var ground := maxf(track.surface_y(cam_s, cx), maxf(track.surface_y(cam_s, cx - 3.0), track.surface_y(cam_s, cx + 3.0)))
		desired = track.point(cam_s, cx, maxf(ground + 2.2, p.y + 1.9))
		look = track.point(p.s, lerpf(cx, p.x, 0.2), p.y) + fwd * 5.0 + Vector3.UP * 0.4
	if not _has_pos:
		_pos = desired
		_look = look
		_has_pos = true
	var k := 1.0 - exp(-dt * 8.0)
	_pos.x = lerpf(_pos.x, desired.x, k)
	_pos.z = lerpf(_pos.z, desired.z, k)
	_pos.y = lerpf(_pos.y, desired.y, 1.0 - exp(-dt * 6.0))
	_pos.y = maxf(_pos.y, track.water_y(cam_s) + 0.8)
	_look = _look.lerp(look, 1.0 - exp(-dt * 10.0))
	var jitter := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake * 0.35
	shake = move_toward(shake, 0.0, dt * 2.5)
	global_position = _pos + jitter
	if not global_position.is_equal_approx(_look):
		look_at(_look, Vector3.UP)
	var target_fov := clampf(68.0 + (p.speed - 30.0) * 0.7 + (8.0 if p.boosting else 0.0), 62.0, 92.0)
	# Portrait phones: widen the view (but not all the way to 16:9, or the salmon gets tiny)
	var vp := get_viewport().get_visible_rect().size
	if vp.x < vp.y * 1.2:
		keep_aspect = Camera3D.KEEP_WIDTH
		target_fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(target_fov) * 0.5) * 1.35))
	else:
		keep_aspect = Camera3D.KEEP_HEIGHT
	fov = lerpf(fov, target_fov, 1.0 - exp(-dt * 3.0))
