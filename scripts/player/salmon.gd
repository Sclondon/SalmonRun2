extends Node3D
## The salmon. Movement is simulated in track space (s, x, y), which keeps it robust on a
## twisting river with waterfalls. Tricks are tracked as accumulated rotation angles and
## judged on landing.

signal trick_landed(trick: Dictionary)   # {name, points, beat}
signal wiped_out(reason: String)
## A glancing hit (rock while swimming): you lose speed and flow but keep control.
signal bumped(reason: String)
signal ring_collected(count: int)
signal jumped
signal landed(impact: float)

enum State { IDLE, SWIM, AIR, GRIND, WIPEOUT }

const Track := preload("res://scripts/world/track.gd")
const Props := preload("res://scripts/world/props.gd")

const GRAVITY := Track.GRAVITY
const CRUISE := 30.0
const BOOST_SPEED := 14.0
const STEER := 15.0
const SPIN_RATE := 620.0
const FLIP_RATE := 480.0
const ROLL_RATE := 540.0
const WIPE_TIME := 1.0
const GRAB_NAMES := ["Fin Grab", "Tail Tweak", "Gill Slap", "Dorsal Stale"]
# body pose per grab: [curl, bend]
const GRAB_POSES := [[0.7, 0.0], [0.0, 0.8], [-0.6, 0.0], [0.0, -0.8]]

var track: Track
var state := State.IDLE
var s := 0.0
var x := 0.0
var y := 0.0
var speed := 0.0
var vx := 0.0
var vy := 0.0
var boost := 40.0
var boosting := false
var charge := 0.0
var air_time := 0.0
var yaw := 0.0
var pitch := 0.0
var roll := 0.0
var grab := -1
var grabs := {}
var rail: Dictionary = {}
var rail_time := 0.0
var wipe_time := 0.0
var invuln := 0.0
var control := false
var autopilot := false

var _yaw_v := 0.0
var _pitch_v := 0.0
var _roll_v := 0.0
var _ramp_vy := 0.0
var _prev_surface := 0.0
var _jump_prev := false
var _land_twist := 0.0
var _wag_phase := 0.0
var _curl := 0.0
var _bend := 0.0
var _t := 0.0
var _stumble := 0.0
var _fish: MeshInstance3D
var _mat: ShaderMaterial
var _wake: CPUParticles3D
var _splash: CPUParticles3D
var _spray: CPUParticles3D
var _ai := {"hold": 0.0, "next_hop": 2.0, "plan": [0.0, 0.0, 0.0, -1]}


func setup(t: Track) -> void:
	track = t
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/fish.gdshader")
	_fish = MeshInstance3D.new()
	_fish.mesh = Props.salmon()
	_fish.material_override = _mat
	_fish.scale = Vector3.ONE * 1.35
	add_child(_fish)
	_wake = _particles(40, 0.6, Color(0.85, 1.0, 0.97), 0.3, false)
	_wake.position = Vector3(0, -0.1, 0.6)
	_wake.emission_box_extents = Vector3(0.4, 0.05, 0.8)
	_wake.direction = Vector3(0, 1, 0.6)
	_wake.initial_velocity_min = 2.0
	_wake.initial_velocity_max = 4.0
	_splash = _particles(70, 1.0, Color(0.9, 1.0, 0.97), 0.45, true)
	_splash.initial_velocity_min = 6.0
	_splash.initial_velocity_max = 11.0
	_splash.spread = 55.0
	_spray = _particles(24, 0.3, Color(0.4, 1.0, 0.9), 0.14, false)
	_spray.local_coords = true
	_spray.gravity = Vector3(0, -6, 0)
	reset(Track.START_S)


func _particles(amount: int, life: float, col: Color, size: float, one_shot: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = one_shot
	p.explosiveness = 1.0 if one_shot else 0.0
	p.emitting = false
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.6, 0.1, 0.6)
	p.direction = Vector3(0, 1, 0)
	p.spread = 40.0
	p.gravity = Vector3(0, -20, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var m := BoxMesh.new()
	m.size = Vector3.ONE * size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	m.material = mat
	p.mesh = m
	add_child(p)
	return p


func reset(at_s: float) -> void:
	s = at_s
	x = 0.0
	y = track.water_y(s)
	speed = 0.0
	vx = 0.0
	vy = 0.0
	boost = 40.0
	charge = 0.0
	yaw = 0.0
	pitch = 0.0
	roll = 0.0
	grab = -1
	invuln = 0.0
	_land_twist = 0.0
	_prev_surface = y
	state = State.IDLE
	Sfx.set_loop("grind", false)


func go() -> void:
	state = State.SWIM
	speed = 20.0


func in_air() -> bool:
	return state == State.AIR or state == State.GRIND


# ================================================================== update

func _process(delta: float) -> void:
	if track == null:
		return
	# Slow phones: only drop into slow motion below 15 fps
	delta = minf(delta, 1.0 / 15.0)
	_t += delta
	var inp := _read_input(delta)
	var jump_held: bool = inp.jump
	var released := _jump_prev and not jump_held
	_jump_prev = jump_held
	invuln = maxf(invuln - delta, 0.0)
	match state:
		State.IDLE:
			y = track.water_y(s)
		State.SWIM:
			_swim(delta, inp, released)
		State.AIR:
			_air(delta, inp)
		State.GRIND:
			_grind(delta, inp, released)
		State.WIPEOUT:
			_wipeout(delta)
	if state != State.IDLE:
		_check_hazards()
		var got := track.collect_rings(track.point(s, x, y + 0.2))
		if got > 0:
			boost = minf(boost + 8.0 * got, 100.0)
			ring_collected.emit(got)
	_update_visual(delta)


func _read_input(delta: float) -> Dictionary:
	if autopilot:
		return _ai_input(delta)
	if not control:
		return {"steer": 0.0, "pitch": 0.0, "roll": 0.0, "jump": false, "boost": false, "grab": -1}
	var g := -1
	for i in 4:
		if Input.is_action_pressed("grab_%d" % (i + 1)):
			g = i
	return {
		"steer": Input.get_axis("steer_left", "steer_right"),
		"pitch": Input.get_axis("swim_down", "swim_up"),
		"roll": Input.get_axis("roll_left", "roll_right"),
		"jump": Input.is_action_pressed("jump"),
		"boost": Input.is_action_pressed("boost"),
		"grab": g,
	}


func _swim(dt: float, inp: Dictionary, released: bool) -> void:
	var pitch_in: float = inp.pitch
	var target := CRUISE + (pitch_in * 8.0 if pitch_in > 0.0 else pitch_in * 14.0)
	var was_boosting := boosting
	boosting = inp.boost and boost > 0.0
	if boosting:
		target += BOOST_SPEED
		boost = maxf(boost - 28.0 * dt, 0.0)
		if not was_boosting:
			Sfx.play("boost", 1.0, -4.0)
	var slope := (track.water_y(s) - track.water_y(s + 4.0)) / 4.0
	target += clampf(slope, -0.2, 0.3) * 40.0
	speed = move_toward(speed, target, (16.0 if speed < target else 9.0) * dt)
	vx = lerpf(vx, float(inp.steer) * STEER, 1.0 - exp(-7.0 * dt))
	var prev_s := s
	s += speed * dt
	x += vx * dt
	_clamp_banks()
	if inp.jump:
		charge = minf(charge + dt / 0.5, 1.0)

	# swim straight onto the end of a bamboo rail
	for r: Dictionary in track.rails:
		if prev_s < r.s0 and s >= r.s0 and absf(x - float(r.x0)) < 1.6:
			_start_grind(r)
			return

	var surf := track.surface_y(s, x)
	if surf < y - 0.6:
		# the surface fell away under us: end of a ramp or a waterfall lip
		vy = maxf(_ramp_vy, 2.5)
		if released or inp.jump:
			vy += 6.0 + 7.0 * charge
		_take_off()
		return
	var climb := (surf - _prev_surface) / dt if dt > 0.0 else 0.0
	_ramp_vy = clampf(climb, 0.0, 20.0)
	y = surf
	_prev_surface = surf
	if released:
		vy = 7.0 + 8.0 * charge + _ramp_vy
		_take_off()


func _take_off() -> void:
	state = State.AIR
	air_time = 0.0
	yaw = 0.0
	pitch = 0.0
	roll = 0.0
	_yaw_v = 0.0
	_pitch_v = 0.0
	_roll_v = 0.0
	grabs.clear()
	grab = -1
	charge = 0.0
	boosting = false
	_ai_plan_trick()
	jumped.emit()


func _air(dt: float, inp: Dictionary) -> void:
	air_time += dt
	vy -= GRAVITY * dt
	y += vy * dt
	s += speed * dt
	vx *= exp(-0.8 * dt)
	x += vx * dt
	_clamp_banks()
	var r := _spin(yaw, _yaw_v, -float(inp.steer), SPIN_RATE, 180.0, dt)
	yaw = r.x
	_yaw_v = r.y
	r = _spin(pitch, _pitch_v, -float(inp.pitch), FLIP_RATE, 360.0, dt)
	pitch = r.x
	_pitch_v = r.y
	r = _spin(roll, _roll_v, -float(inp.roll), ROLL_RATE, 360.0, dt)
	roll = r.x
	_roll_v = r.y
	grab = inp.grab
	if grab >= 0:
		grabs[grab] = float(grabs.get(grab, 0.0)) + dt

	if vy <= 2.0 and _try_catch_rail():
		return
	var surf := track.surface_y(s, x)
	if y <= surf:
		y = surf
		if vy <= 0.0:
			_land()


## Rotates one axis: follows input, and when input is released keeps turning until the
## next clean orientation (multiple of `snap`), so landings are forgiving.
func _spin(angle: float, vel: float, input: float, rate: float, snap: float, dt: float) -> Vector2:
	if absf(input) > 0.2:
		vel = move_toward(vel, input * rate, rate * 6.0 * dt)
		return Vector2(angle + vel * dt, vel)
	if absf(vel) < 1.0:
		return Vector2(angle, 0.0)
	var goal := (ceilf(angle / snap - 0.02) if vel > 0.0 else floorf(angle / snap + 0.02)) * snap
	var next := move_toward(angle, goal, maxf(absf(vel), rate * 0.6) * dt)
	if is_equal_approx(next, goal):
		vel = 0.0
	return Vector2(next, vel)


func _is_clean() -> bool:
	var ye := absf(wrapf(yaw, -90.0, 90.0))
	var pe := absf(wrapf(pitch, -180.0, 180.0))
	var re := absf(wrapf(roll, -180.0, 180.0))
	return grab < 0 and ye < 60.0 and pe < 65.0 and re < 65.0


func _land() -> void:
	var impact := -vy
	vy = 0.0
	if not _is_clean():
		_wipe("SLOPPY!" if grab < 0 else "HELD THE GRAB!")
		return
	var trick := _compose_trick()
	state = State.SWIM
	_prev_surface = y
	_ramp_vy = 0.0
	_land_twist = wrapf(yaw, -180.0, 180.0)
	speed += 2.0
	_splash.restart()
	landed.emit(impact)
	if trick.points > 0:
		trick_landed.emit(trick)


func _times(k: int) -> String:
	match k:
		1:
			return ""
		2:
			return "Double "
		3:
			return "Triple "
	return "%dx " % k


func _compose_trick() -> Dictionary:
	var parts := PackedStringArray()
	var pts := 0
	var flips := int(roundf(absf(pitch) / 360.0))
	if flips > 0:
		parts.append(_times(flips) + ("Frontflip" if pitch < 0.0 else "Backflip"))
		pts += 450 * flips + 200 * (flips - 1) * flips
	var rolls := int(roundf(absf(roll) / 360.0))
	if rolls > 0:
		parts.append(_times(rolls) + "Corkscrew")
		pts += 400 * rolls + 150 * (rolls - 1) * rolls
	var halves := int(roundf(absf(yaw) / 180.0))
	if halves > 0:
		parts.append(str(halves * 180))
		pts += 140 * halves + 30 * halves * halves
	for g: int in grabs:
		var held: float = grabs[g]
		if held >= 0.12:
			parts.append(GRAB_NAMES[g] + ("!!" if held > 1.0 else ""))
			pts += 150 + int(minf(held, 2.5) * 320.0)
	if parts.is_empty():
		if air_time < 0.9:
			return {"name": "", "points": 0, "beat": 0}
		parts.append("Breach")
	pts += int(maxf(air_time - 0.5, 0.0) * 120.0)
	if air_time > 2.4:
		parts.append("Big Air")
		pts += 300
	if parts.size() >= 3:
		pts = int(pts * 1.25)
	return _on_beat(" + ".join(parts), pts)


## Landing (or leaving a rail) close to the beat multiplies the points.
func _on_beat(trick_name: String, pts: int) -> Dictionary:
	var off := absf(Music.beat_offset())
	var beat := 0
	if off < 0.045:
		beat = 2
		pts *= 2
	elif off < 0.095:
		beat = 1
		pts = int(pts * 1.5)
	return {"name": trick_name, "points": pts, "beat": beat}


# ================================================================== rails

func _try_catch_rail() -> bool:
	for r: Dictionary in track.rails:
		if s < float(r.s0) or s > float(r.s1) - 3.0:
			continue
		var ry := track.water_y(s) + Track.RAIL_H
		if absf(x - track.rail_x(r, s)) < 1.7 and y <= ry + 1.2 and y >= ry - 1.2:
			if not _is_clean():
				_wipe("SLOPPY!")
				return true
			var trick := _compose_trick()
			if trick.points > 0:
				trick_landed.emit(trick)
			_start_grind(r)
			return true
	return false


func _start_grind(r: Dictionary) -> void:
	state = State.GRIND
	rail = r
	rail_time = 0.0
	vy = 0.0
	yaw = 0.0
	pitch = 0.0
	roll = 0.0
	grab = -1
	grabs.clear()
	charge = 0.0
	_splash.restart()
	Sfx.set_loop("grind", true)
	landed.emit(4.0)


func _grind(dt: float, inp: Dictionary, released: bool) -> void:
	rail_time += dt
	speed = move_toward(speed, CRUISE + 4.0, 3.0 * dt)
	s += speed * dt
	x = track.rail_x(rail, s)
	y = track.water_y(s) + Track.RAIL_H
	if inp.jump:
		charge = minf(charge + dt / 0.5, 1.0)
	if released or s >= float(rail.s1):
		Sfx.set_loop("grind", false)
		var pts := 150 + int(rail_time * 450.0)
		trick_landed.emit(_on_beat("Bamboo Grind", pts))
		vy = 5.0 + (6.0 + 7.0 * charge if released else 0.0)
		_take_off()


# ================================================================== wipeouts & hazards

func _wipe(reason: String) -> void:
	state = State.WIPEOUT
	wipe_time = 0.0
	grab = -1
	charge = 0.0
	boosting = false
	Sfx.set_loop("grind", false)
	_splash.restart()
	wiped_out.emit(reason)


## Glancing off a rock: knocked sideways and slowed, but still steerable.
func _bump(rock_x: float) -> void:
	speed *= 0.6
	vx = (8.0 if x >= rock_x else -8.0)
	charge = 0.0
	invuln = 0.8
	_stumble = 0.5
	_splash.restart()
	bumped.emit("ROCKED!")


func _wipeout(dt: float) -> void:
	wipe_time += dt
	speed = move_toward(speed, 9.0, 25.0 * dt)
	s += speed * dt
	x += vx * dt
	vx *= exp(-2.0 * dt)
	_clamp_banks()
	var surf := track.water_y(s)
	if y > surf + 0.01:
		vy -= GRAVITY * dt
		y = maxf(y + vy * dt, surf)
	else:
		y = surf
		vy = 0.0
		if wipe_time > WIPE_TIME:
			state = State.SWIM
			speed = maxf(speed, 18.0)
			invuln = 1.5
			yaw = 0.0
			pitch = 0.0
			roll = 0.0
			_land_twist = 0.0
			_prev_surface = y


func _check_hazards() -> void:
	if invuln > 0.0 or state == State.WIPEOUT:
		return
	var above := y - track.water_y(s)
	if above < 1.3 and state != State.GRIND:
		for r: Dictionary in track.rocks:
			var ds: float = s - float(r.s)
			if absf(ds) < 3.5 and Vector2(ds, x - float(r.x)).length() < float(r.r) + 0.6:
				if state == State.SWIM:
					_bump(float(r.x))
				else:
					_wipe("ROCKED!")
				return
	for b: Dictionary in track.bears:
		var ds: float = s - float(b.s)
		if absf(ds) < 2.8 and absf(x - float(b.x)) < 3.0 and above < 3.6 and b.node.is_swiping():
			_wipe("BEAR'D!")
			Sfx.play("bear")
			return


func _clamp_banks() -> void:
	var lim := track.width(s) * 0.5 - 1.3
	if absf(x) > lim:
		x = clampf(x, -lim, lim)
		if signf(vx) == signf(x):
			if absf(vx) > 5.0 and state == State.SWIM:
				Sfx.play("bank", 1.0, -6.0)
				speed *= 0.93
			vx = -vx * 0.3


# ================================================================== visuals

func _update_visual(dt: float) -> void:
	var pos := track.point(s, x, y)
	var base := track.basis_at(s)
	var slope_ang := atan2(track.water_y(s + 1.5) - track.water_y(s - 1.5), 3.0)
	var b := base
	var wag_speed := 14.0
	var wag_amp := 0.12
	var target_curl := 0.0
	var target_bend := 0.0
	match state:
		State.IDLE, State.SWIM:
			pos.y -= 0.1 - sin(_t * 5.0) * 0.05
			_land_twist = lerpf(_land_twist, 0.0, 1.0 - exp(-8.0 * dt))
			if _stumble > 0.0:
				_stumble = maxf(_stumble - dt, 0.0)
				_land_twist += sin(_t * 30.0) * 40.0 * _stumble
			b = base * Basis(Vector3.UP, deg_to_rad(_land_twist)) \
					* Basis(Vector3.RIGHT, slope_ang + sin(_t * 5.0) * 0.05) \
					* Basis(Vector3.BACK, -vx * 0.035)
			wag_speed = 8.0 + speed * 0.35
			if state == State.IDLE:
				wag_speed = 5.0
			target_curl = charge * 0.7
		State.AIR:
			var traj := atan2(vy, maxf(speed, 1.0)) * 0.6
			b = base * Basis(Vector3.UP, deg_to_rad(yaw)) \
					* Basis(Vector3.RIGHT, deg_to_rad(pitch) + traj) \
					* Basis(Vector3.BACK, deg_to_rad(roll))
			wag_speed = 5.0
			wag_amp = 0.08
			if grab >= 0:
				target_curl = GRAB_POSES[grab][0]
				target_bend = GRAB_POSES[grab][1]
				wag_amp = 0.02
		State.GRIND:
			pos.y += 0.1
			b = base * Basis(Vector3.BACK, sin(_t * 9.0) * 0.12)
			wag_speed = 18.0
			wag_amp = 0.06
			target_curl = charge * 0.7
		State.WIPEOUT:
			var k := 1.0 - clampf(wipe_time / WIPE_TIME, 0.0, 1.0)
			b = base * Basis(Vector3.UP, _t * 9.0 * k) * Basis(Vector3.BACK, _t * 14.0 * k)
			pos.y -= 0.2 * (1.0 - k)
			wag_speed = 24.0 * k
			wag_amp = 0.2 * k
	transform = Transform3D(b.orthonormalized(), pos)
	_curl = lerpf(_curl, target_curl, 1.0 - exp(-12.0 * dt))
	_bend = lerpf(_bend, target_bend, 1.0 - exp(-12.0 * dt))
	_wag_phase += dt * wag_speed
	_mat.set_shader_parameter("wag_phase", _wag_phase)
	_mat.set_shader_parameter("wag_amp", wag_amp)
	_mat.set_shader_parameter("curl", _curl)
	_mat.set_shader_parameter("bend", _bend)
	var blink := invuln > 0.0 and fmod(_t, 0.2) < 0.1
	_mat.set_shader_parameter("flash", 0.6 if blink else (0.35 if boosting else 0.0))
	_wake.emitting = state == State.SWIM and speed > 5.0
	_spray.emitting = state == State.AIR or state == State.GRIND


# ================================================================== autopilot

func _ai_plan_trick() -> void:
	var r := randf()
	var steer := 0.0
	var flip := 0.0
	var roll_in := 0.0
	var g := -1
	if r < 0.3:
		steer = [-1.0, 1.0][randi() % 2]
	elif r < 0.55:
		flip = [-1.0, 1.0][randi() % 2]
	elif r < 0.7:
		roll_in = [-1.0, 1.0][randi() % 2]
	elif r < 0.85:
		steer = 1.0
		flip = -1.0
	if randf() < 0.5:
		g = randi() % 4
	_ai.plan = [steer, flip, roll_in, g]


func _ai_input(dt: float) -> Dictionary:
	var inp := {"steer": 0.0, "pitch": 0.3, "roll": 0.0, "jump": false, "boost": false, "grab": -1}
	match state:
		State.SWIM:
			var tx := 0.0
			var best := 90.0
			for r: Dictionary in track.ramps:
				var d: float = float(r.s) - s
				if d > -float(r.len) and d < best:
					best = d
					tx = r.x
			for r: Dictionary in track.rails:
				var d: float = float(r.s0) - s
				if d > 0.0 and d < best:
					best = d
					tx = r.x0
			for rk: Dictionary in track.rocks:
				var d: float = float(rk.s) - s
				if d > 0.0 and d < 28.0 and absf(tx - float(rk.x)) < float(rk.r) + 2.2:
					tx = float(rk.x) + (float(rk.r) + 3.0) * (1.0 if x > float(rk.x) else -1.0)
			inp.steer = clampf((tx - x) * 0.35, -1.0, 1.0)
			inp.boost = boost > 70.0
			var hold := false
			if track.ramp_height(s, x) > 0.0 and track.ramp_height(s + 2.0, x) > 0.0:
				hold = true
			for wf: Dictionary in track.waterfalls:
				var d: float = float(wf.s) - s
				if d > 1.0 and d < 14.0:
					hold = true
			for bb: Dictionary in track.bears:
				var d: float = float(bb.s) - s
				if d > 3.0 and d < 12.0 and absf(float(bb.x) - x) < 4.0:
					hold = true
			_ai.next_hop = float(_ai.next_hop) - dt
			if _ai.next_hop < 0.0:
				_ai.hold = 0.45
				_ai.next_hop = randf_range(2.0, 4.0)
			if float(_ai.hold) > 0.0:
				_ai.hold = float(_ai.hold) - dt
				hold = true
			inp.jump = hold
		State.AIR:
			var surf := track.surface_y(s + speed * 0.4, x)
			var h := maxf(y - surf, 0.0)
			var t_land := (vy + sqrt(vy * vy + 2.0 * GRAVITY * h)) / GRAVITY
			var plan: Array = _ai.plan
			if t_land > 0.55:
				inp.steer = plan[0]
				inp.pitch = plan[1]
				inp.roll = plan[2]
			if t_land > 0.7 and air_time > 0.15:
				inp.grab = plan[3]
			if t_land <= 0.55:
				inp.pitch = 0.0
		State.GRIND:
			inp.jump = s < float(rail.s1) - 5.0
	return inp
