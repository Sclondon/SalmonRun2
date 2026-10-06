extends Camera3D
## Follows the salmon in track space. Mode FOLLOW is the gameplay chase cam; mode CINEMA cycles
## through a few TV-style angles for the title screen.

enum Mode { FOLLOW, CINEMA, OVERLOOK, STAGE }
## STAGE: filming a set (the spawning): where the eye is and what it looks at.
var stage_eye := Vector3.ZERO
var stage_focus := Vector3.ZERO

## OVERLOOK (the water lab) looks down on the water from high up: either going along with the
## salmon, or standing still over one stretch of water while the salmon swims on.
var overlook_follow := false
var _overlook_s := -1.0
var _overlook_x := 0.0
## Looking round in the water lab: the eye goes round the point it looks at. How far round
## (radians), how high (radians: under 0 it is below the surface, looking up), how far off
## (metres), and how far the point has been moved over the water (across, along).
const ORBIT_PITCH := 0.93
const ORBIT_DIST := 15.0
var orbit_yaw := 0.0
var orbit_pitch := ORBIT_PITCH
var orbit_dist := ORBIT_DIST
var orbit_move := Vector2.ZERO

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
	_overlook_s = -1.0
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
	if mode == Mode.OVERLOOK:
		if overlook_follow or _overlook_s < 0.0:
			_overlook_s = p.s
			_overlook_x = p.x
		cam_s = clampf(_overlook_s + 4.0 + orbit_move.y, 5.0, track.length - 40.0)
		# The eye goes round the point it looks at (see _unhandled_input): how far round, how
		# high (or, under 0, how far below the surface), and how far off.
		_orbit_keys(dt)
		var focus := track.point(cam_s, _overlook_x + orbit_move.x, track.water_y(cam_s))
		var away := Basis(Vector3.UP, orbit_yaw) * Basis(Vector3.RIGHT, -orbit_pitch) * Vector3(0.0, 0.0, orbit_dist)
		desired = focus + track.basis_at(cam_s) * away
		look = focus
		under = 1.0 if orbit_pitch < 0.0 else 0.0
	elif mode == Mode.STAGE:
		cam_s = p.s
		# (a slow drift, so that it is not a still picture)
		desired = stage_eye + Vector3(sin(Time.get_ticks_msec() * 0.0004) * 0.5, sin(Time.get_ticks_msec() * 0.0003) * 0.15, 0.0)
		look = stage_focus
		under = 1.0 if stage_eye.y < track.water_y(cam_s) else 0.0
	elif mode == Mode.CINEMA:
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
		_pos.y = maxf(_pos.y, surface + 0.8 + track.swell_top())
	submerged = clampf((surface - _pos.y) / 0.3, 0.0, 1.0)
	_look = _look.lerp(look, 1.0 - exp(-dt * 10.0))
	var jitter := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake * 0.35
	shake = move_toward(shake, 0.0, dt * 2.5)
	global_position = _pos + jitter
	if not global_position.is_equal_approx(_look):
		look_at(_look, Vector3.UP)
	var target_fov := clampf(68.0 + (p.speed - 25.0) * 0.8 + (8.0 if p.boosting else 0.0), 62.0, 92.0)
	# Portrait phones: widen the view (but not all the way to 16:9, or the salmon gets tiny)
	var vp := get_viewport().get_visible_rect().size
	if vp.x < vp.y * 1.2:
		keep_aspect = Camera3D.KEEP_WIDTH
		target_fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(target_fov) * 0.5) * 1.35))
	else:
		keep_aspect = Camera3D.KEEP_HEIGHT
	fov = lerpf(fov, target_fov, 1.0 - exp(-dt * 3.0))


# ================================================================== looking round (water lab)

## Puts the water lab's view back to where it starts: high up behind, looking down.
func orbit_reset() -> void:
	orbit_yaw = 0.0
	orbit_pitch = ORBIT_PITCH
	orbit_dist = ORBIT_DIST
	orbit_move = Vector2.ZERO


## In the water lab a drag turns the view round the point it looks at and tips it up and
## down, and the wheel moves it in and out. (Only what the panel has not used gets here.)
func _unhandled_input(event: InputEvent) -> void:
	if mode != Mode.OVERLOOK:
		return
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask != 0:
		var by: Vector2 = (event as InputEventMouseMotion).relative
		orbit_yaw = wrapf(orbit_yaw - by.x * 0.006, -PI, PI)
		orbit_pitch = clampf(orbit_pitch + by.y * 0.005, -1.2, 1.5)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_WHEEL_UP:
				orbit_dist = maxf(orbit_dist * 0.9, 2.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				orbit_dist = minf(orbit_dist * 1.1, 120.0)
	elif event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).physical_keycode == KEY_R:
		orbit_reset()


## The keys: W A S D or the arrows move the point looked at over the water (the way the view
## is facing), Q and E move the eye in and out.
func _orbit_keys(dt: float) -> void:
	# (not while a number is being typed into the panel)
	if get_tree().root.gui_get_focus_owner() is LineEdit:
		return
	var push := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		push.y += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		push.y -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		push.x += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		push.x -= 1.0
	if Input.is_physical_key_pressed(KEY_Q):
		orbit_dist = maxf(orbit_dist * (1.0 - dt), 2.0)
	if Input.is_physical_key_pressed(KEY_E):
		orbit_dist = minf(orbit_dist * (1.0 + dt), 120.0)
	if push != Vector2.ZERO:
		# (faster from further off, so that it crosses the picture at the same rate)
		orbit_move += push.rotated(-orbit_yaw) * maxf(orbit_dist, 6.0) * 1.2 * dt
		var lim := track.width(_overlook_s) * 0.5 + 30.0
		orbit_move.x = clampf(orbit_move.x, -lim - _overlook_x, lim - _overlook_x)


## Everything is measured from somewhere else from now on (the salmon has swum on to the next
## stage): the eye and what it looks at are carried over, so that the picture does not move.
func carry(by: Transform3D) -> void:
	_pos = by * _pos
	_look = by * _look
	_overlook_s = -1.0
