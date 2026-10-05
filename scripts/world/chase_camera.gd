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
## How far to the side the camera looks (metres, 11 m ahead) for each m/s the salmon is moving
## across the course.
const LEAN := 0.42
## How far under the water the camera is: 0 above the surface, 1 below it.
var submerged := 0.0

var _pos := Vector3.ZERO
var _look := Vector3.ZERO
var _has_pos := false
var _cine_t := 0.0
var _lean := 0.0
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
	var under := 0.0
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
		# The camera goes across the river with the salmon, which stays in the middle of the
		# screen. (So a finger held to one side keeps it swimming that way, more quickly the
		# further out the finger is.)
		# It turns to look the way the salmon is steering: the eye swings out to the other side
		# and looks across, so that the salmon stays near the middle of the picture.
		_lean = lerpf(_lean, clampf(p.vx * LEAN, -6.5, 6.5), 1.0 - exp(-dt * 4.0))
		# (never out over the bank)
		var edge := maxf(track.width(cam_s) * 0.5 - 1.2, absf(p.x))
		var cx := clampf(p.x - _lean * 0.6, -edge, edge)
		var ground := maxf(track.surface_y(cam_s, cx), maxf(track.surface_y(cam_s, cx - 3.0), track.surface_y(cam_s, cx + 3.0)))
		# dived, the camera goes under with the fish
		under = smoothstep(0.3, 0.9, p.dive)
		desired = track.point(cam_s, cx, lerpf(maxf(ground + 2.2, p.y + 1.9), p.y + 1.0, under))
		look = track.point(p.s, p.x + _lean, p.y) + fwd * 5.0 + Vector3.UP * 0.4
	if not _has_pos:
		_pos = desired
		_look = look
		_has_pos = true
	var k := 1.0 - exp(-dt * 8.0)
	_pos.x = lerpf(_pos.x, desired.x, k)
	_pos.z = lerpf(_pos.z, desired.z, k)
	_pos.y = lerpf(_pos.y, desired.y, 1.0 - exp(-dt * 6.0))
	# it stays clear of the surface: well above it, or (dived) well below, never in it
	var surface := track.water_y(cam_s)
	if under < 0.5:
		_pos.y = maxf(_pos.y, surface + 0.8)
	submerged = clampf((surface - _pos.y) / 0.3, 0.0, 1.0)
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
