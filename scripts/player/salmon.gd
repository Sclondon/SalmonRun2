extends Node3D
## The salmon. Movement is simulated in track space (s, x, y), which keeps it robust on a
## twisting river with waterfalls. Tricks are tracked as accumulated rotation angles and
## judged on landing.

signal trick_landed(trick: Dictionary)   # {name, points, beat}
## A swipe (or a jump, or the start of a spin on the keys) has been timed against the beat:
## how well, as a grade (see Score.GRADES).
signal swipe_timed(grade: int)
signal wiped_out(reason: String)
## A glancing hit (rock while swimming): you lose speed and flow but keep control.
signal bumped(reason: String)
signal ring_collected(count: int)
signal jumped
signal landed(impact: float)
## Dived under the surface (true) or came back up to it (false).
signal dived(down: bool)

enum State { IDLE, SWIM, AIR, GRIND, WIPEOUT, CURRENT }

const Track := preload("res://scripts/world/track.gd")
const Props := preload("res://scripts/world/props.gd")
const Splash := preload("res://scripts/fx/splash.gd")
const Wake := preload("res://scripts/fx/wake.gd")
const Score := preload("res://scripts/game/score.gd")

const GRAVITY := Track.GRAVITY
const CRUISE := 22.0
const BOOST_SPEED := 12.0
const STEER := 12.0
const SPIN_RATE := 620.0
const FLIP_RATE := 480.0
const ROLL_RATE := 540.0
const WIPE_TIME := 1.0
## Touch: steering strength per metre between the salmon and the finger it is following.
const FOLLOW_GAIN := 0.4
## Touch: how hard a swipe-up jumps (as a fraction of a fully charged jump).
const SWIPE_JUMP := 1.0
## Spins and flips swing the salmon around a circle of this radius instead of turning on the spot.
const ARC_RADIUS := 0.9
## How far downstream you are swept when you fail to clear a waterfall (room for a run-up).
const WASH_BACK := 40.0
## How far its back is arched as it rides a rail.
const RAIL_ARCH := 0.8
## How far above the water counts as being in the air while wiped out.
const AIRBORNE := 0.4
## Swipe tricks: the two axes, how long one full turn takes on each (seconds), and how much of
## that is the wind-up before it whips round.
const SPIN := 0
const FLIP := 1
const TRICK_TIME := [0.4, 0.5]
const TRICK_WINDUP := 0.16
## Diving: how long it takes to get down a layer or back up one. (How many layers there are and
## how far apart is the stage's business: see Track.layers.)
const DIVE_TIME := 0.22
## Under the water the salmon can also be swum up and down freely (up and down on the keys or
## the stick; on touch, a slow drag up or down with the finger held): this many layers a second.
const FREE_SWIM := 2.4  # (no longer used: up and down go at the speed of steering, see _swim)
## A swipe to one side on the water dashes this far across (metres), in this long.
const DASH := 3.0
const DASH_TIME := 0.13
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
## Swept back down from a waterfall it did not clear: how many metres it has still to be
## carried (0 when it is not). It tumbles as it goes, and has no say in it.
var washed := 0.0
## On a rail: how far round it has still to spin (degrees, signed), how far round it is, and
## how many spins it has made on this one (a swipe to one side is a spin).
var _rail_spin := 0.0
var _rail_yaw := 0.0
var _rail_spins := 0
var invuln := 0.0
var control := false
var autopilot := false
## Dived under the surface, to which layer (0 is the surface), and how far down it has got so
## far, in layers
var under := false
var layer := 0
var dive := 0.0
## How far down it is making for, in layers: the layer it was last sent to, or wherever it
## has been swum to freely since.
var dive_to := 0.0
## How fast it swims of the speed it would (1 is all of it): less while it idles along after
## a stage is done, 0 to hold where it is.
var pace := 1.0
# how well each swipe of the leap in hand was timed (the jump itself is the first), and
# which of the held inputs (spin, flip, corkscrew, grab) were already on last frame
var _marks: Array[int] = []
var _held := [true, true, true, true]
var _rise := 0.0
var _rise_v := 0.0
# how far it has climbed without a break, coming up from the deep (metres): see the swoop
var _swoop := 0.0
# how fast it is going up or down under the water (m/s, up is +), for the tilt of its body
var _climb := 0.0
var _dive_was := 0.0
var _current_wait := 0.0
var _dash := 0.0
# the corkscrew it turns as it dashes: which way, and how far through it is (1 is done)
var _dash_dir := 0.0
var _dash_t := 1.0

var _yaw_v := 0.0
var _pitch_v := 0.0
var _roll_v := 0.0
# swipe tricks, per axis: progress through the turn in hand (-1 for none), where it started,
# which way it goes, how many more are waiting, and whether it follows straight on from one
var _trick_t := [-1.0, -1.0]
var _trick_from := [0.0, 0.0]
var _trick_dir := [0.0, 0.0]
var _trick_wait := [0.0, 0.0]
var _trick_chained := [false, false]
# squash and stretch (0 is at rest, + is long and thin) and the pose springs
var _stretch := 0.0
var _stretch_v := 0.0
var _curl_v := 0.0
var _bend_v := 0.0
var _base_scale := Vector3.ONE
var _ramp_vy := 0.0
var _prev_surface := 0.0
var _jump_prev := false
var _land_twist := 0.0
var _wag_phase := 0.0
var _curl := 0.0
var _bend := 0.0
var _t := 0.0
var _stumble := 0.0
# how hard the salmon is turning, -1..1, smoothed: drives the body arc
var _yaw_rate := 0.0
var _pitch_rate := 0.0
var _turn := 0.0
var _prev_yaw := 0.0
var _prev_pitch := 0.0
var _prev_vx := 0.0
var _fish: MeshInstance3D
var _look := "spawner"
var _mat: ShaderMaterial
var _wake: Wake
var _bubbles: CPUParticles3D
var _spray: CPUParticles3D
var _dots: Array[CPUParticles3D] = []
var _splashes: Array[Splash] = []
var _splash_next := 0
# the current being ridden is cut away near the eye (see shaders/current.gdshader)
var _ridden: ShaderMaterial
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
	_base_scale = _fish.scale
	# The wake: two bands of foam that open out behind into a V (see fx/wake.gd)
	_wake = Wake.new()
	_wake.track = track
	add_child(_wake)
	# a string of bubbles while dived
	_bubbles = _particles(18, 0.45, Color(0.85, 0.97, 1.0), 0.1)
	_bubbles.position = Vector3(0, 0.1, 0.4)
	_bubbles.emission_box_extents = Vector3(0.25, 0.1, 0.5)
	_bubbles.direction = Vector3(0, 1, 0)
	_bubbles.spread = 20.0
	_bubbles.initial_velocity_min = 1.5
	_bubbles.initial_velocity_max = 2.6
	_bubbles.gravity = Vector3.ZERO
	# while it swims at the surface: small white dots of spray tossed up off each shoulder.
	# (They travel with the salmon, so that they stay round it and are not strung out behind.)
	for side: float in [-1.0, 1.0]:
		var dots := _particles(10, 0.3, Color(0.96, 1.0, 1.0), 0.1)
		dots.local_coords = true
		dots.position = Vector3(side * 0.28, 0.05, -0.35)
		dots.emission_box_extents = Vector3(0.05, 0.03, 0.3)
		dots.direction = Vector3(side * 0.55, 1.0, 0.5)
		dots.spread = 20.0
		dots.initial_velocity_min = 1.4
		dots.initial_velocity_max = 2.8
		dots.gravity = Vector3(0, -18, 0)
		_dots.append(dots)
	# sparks off a rail, only wet: bright drops flung up and back from under the salmon
	_spray = _particles(70, 0.45, Color(0.9, 1.0, 1.0), 0.12)
	_spray.local_coords = false
	_spray.spread = 38.0
	_spray.initial_velocity_min = 5.0
	_spray.initial_velocity_max = 11.0
	_spray.emission_box_extents = Vector3(0.25, 0.05, 0.6)
	_spray.gravity = Vector3(0, -26, 0)
	# the splashes are made now and used in turn (see fx/splash.gd)
	for i in 4:
		var splash := Splash.new()
		add_child(splash)
		_splashes.append(splash)
	reset(Track.START_S)


## A stream of round drops (never squares) that shrink away to nothing.
func _particles(amount: int, life: float, col: Color, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.emitting = false
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.6, 0.1, 0.6)
	p.direction = Vector3(0, 1, 0)
	p.spread = 40.0
	p.gravity = Vector3(0, -20, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 0.6))
	shrink.add_point(Vector2(0.2, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = shrink
	p.mesh = _round(size, size, col)
	add_child(p)
	return p


func _round(width: float, height: float, col: Color) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = width * 0.5
	m.height = height
	m.radial_segments = 8
	m.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	m.material = mat
	return m


## A splash where the salmon is (see fx/splash.gd): 1 is an ordinary landing.
func _do_splash(strength: float) -> void:
	if not is_inside_tree():
		return
	_splash_next = (_splash_next + 1) % _splashes.size()
	_splashes[_splash_next].start(track, s, x, strength)


## Which stage of its life the salmon is in: "ocean", "spawner" or "smolt" (see Props.salmon).
func set_look(look: String) -> void:
	if look == _look:
		return
	_look = look
	_fish.mesh = Props.salmon(look)
	# (the young are smaller, though not as small as they really are, or they would be lost
	# on the screen)
	_base_scale = Vector3.ONE * 1.35 * maxf(Props.salmon_size(look), 0.62)
	_fish.scale = _base_scale


func reset(at_s: float) -> void:
	washed = 0.0
	s = at_s
	if _wake:
		_wake.clear()
	x = 0.0
	# (a speck of a splash, so that what draws one is ready before the first leap needs it)
	if not _splashes.is_empty() and is_inside_tree():
		_splashes[0].start(track, s, 0.0, 0.02)
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
	under = false
	layer = 0
	dive = 0.0
	dive_to = 0.0
	# (on a stage that is all under the water, it begins under it)
	if track and track.cfg.get("submerged", false) and _sunk_here():
		layer = 2
		dive = 2.0
		dive_to = 2.0
		under = true
	state = State.IDLE
	Sfx.set_loop("grind", false)


func go() -> void:
	state = State.SWIM
	speed = 17.0


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
	var s_before := s
	if washed > 0.0:
		# carried back down by the water, quickly at first and easing off
		var back := minf(lerpf(10.0, 30.0, clampf(washed / WASH_BACK, 0.0, 1.0)) * delta, washed)
		washed -= back
		s = maxf(s - back, 4.0)
		x = lerpf(x, clampf(x, -track.width(s) * 0.5 + 3.0, track.width(s) * 0.5 - 3.0), 0.2)
		y = track.water_y(s)
		_prev_surface = y
		speed = 6.0
		vx = 0.0
		if washed <= 0.0:
			speed = 12.0
			_stumble = 0.5
		_update_visual(delta)
		return
	match state:
		State.IDLE:
			y = track.water_y(s)
		State.SWIM:
			_swim(delta, inp, released)
		State.AIR:
			_air(delta, inp)
		State.GRIND:
			_grind(delta, inp, released)
		State.CURRENT:
			_ride(delta, inp, released)
		State.WIPEOUT:
			_wipeout(delta)
	if _ridden and state != State.CURRENT:
		_ridden.set_shader_parameter("clear", 2.0)
		_ridden = null
	if state != State.IDLE and state != State.GRIND:
		_check_falls(s_before)
	if state != State.IDLE:
		_check_hazards()
		var got := track.collect_rings(track.point(s, x, y + 0.2))
		if got > 0:
			boost = minf(boost + 8.0 * got, 100.0)
			ring_collected.emit(got)
		# a boost ring under the sea is a surge of speed as well
		if track.surge > 0:
			track.surge = 0
			speed += 9.0
			boost = minf(boost + 12.0, 100.0)
			_stretch_v += 6.0
			Sfx.play("boost", 1.4, -5.0)
	_update_visual(delta)


func _read_input(delta: float) -> Dictionary:
	if autopilot:
		return _ai_input(delta)
	var swipes := GameInput.take_swipes()
	if not control:
		return {"steer": 0.0, "pitch": 0.0, "roll": 0.0, "jump": false, "boost": false, "grab": -1, "swipes": []}
	var g := -1
	for i in 4:
		if Input.is_action_pressed("grab_%d" % (i + 1)):
			g = i
	if Input.is_action_just_pressed("dive") and state == State.SWIM:
		swipes.append(Vector2.DOWN)
	var steer := Input.get_axis("steer_left", "steer_right")
	if GameInput.follow:
		steer = clampf(GameInput.follow_dx * FOLLOW_GAIN, -1.0, 1.0)
	return {
		"swipes": swipes,
		# (keys and pads: one button goes down a layer, or back up)
		"steer": steer,
		"pitch": Input.get_axis("swim_down", "swim_up"),
		# (under the water: up and down. A finger held and dragged slowly does it on touch.)
		"rise": -GameInput.follow_dy if GameInput.follow else Input.get_axis("swim_down", "swim_up"),
		"roll": GameInput.roll if GameInput.roll != 0.0 else Input.get_axis("roll_left", "roll_right"),
		"jump": Input.is_action_pressed("jump"),
		# (touch: a wiggle or a circle; in the air the circle is the corkscrew instead)
		"boost": Input.is_action_pressed("boost") or GameInput.wiggling or GameInput.roll != 0.0,
		"grab": g,
	}


func _swim(dt: float, inp: Dictionary, released: bool) -> void:
	# (on the surface up and down are faster and slower; under it they are up and down)
	var pitch_in: float = 0.0 if layer > 0 else float(inp.pitch)
	var target := (CRUISE + (pitch_in * 8.0 if pitch_in > 0.0 else pitch_in * 14.0)) * pace
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
	vx = lerpf(vx, float(inp.steer) * STEER, 1.0 - exp(-4.5 * dt))
	var prev_s := s
	s += speed * dt
	x += vx * dt
	# a swipe to one side is a dash: one place over, at once
	for swipe: Vector2 in inp.swipes:
		if swipe == Vector2.LEFT or swipe == Vector2.RIGHT:
			_dash = swipe.x * DASH
			_dash_dir = swipe.x
			_dash_t = 0.0
			_stretch_v += 5.0
			Sfx.play("jump", 1.5, -8.0)
	if _dash != 0.0:
		var hop := signf(_dash) * minf(absf(_dash), DASH / DASH_TIME * dt)
		x += hop
		_dash -= hop
	_clamp_banks()
	if inp.jump:
		charge = minf(charge + dt / 0.5, 1.0)

	# swim straight onto the end of a bamboo rail (from the surface: dived, you pass under it)
	for r: Dictionary in track.rails:
		if not under and prev_s < r.s0 and s >= r.s0 and absf(x - float(r.x0)) < 1.6:
			_start_grind(r)
			return

	var surf := track.surface_y(s, x)
	# a ramp is solid all the way down: coming up to one brings you back to the surface
	if under and track.ramp_height(s + 3.0, x) > 0.0:
		_set_layer(0)
	if surf < _prev_surface - 0.6:
		# the surface fell away under us: end of a ramp or a waterfall lip
		y = _prev_surface
		vy = maxf(_ramp_vy, 2.5)
		if released or inp.jump:
			vy += 6.6 + 7.7 * charge
		elif _swiped_up(inp):
			vy += 6.6 + 7.7 * SWIPE_JUMP * lerpf(0.72, 1.14, GameInput.swipe_power)
		_take_off(released or bool(inp.jump) or _swiped_up(inp))
		return
	var climb := (surf - _prev_surface) / dt if dt > 0.0 else 0.0
	_ramp_vy = clampf(climb, 0.0, 20.0)
	# The layers: the surface, and one or more dived under it (a river has one, the open
	# ocean several). Swiping down goes down one; swiping up comes up one (and from the
	# surface, jumps).
	# Under the water it can be swum up and down freely as well, to anywhere between the
	# layers; held up far enough, it comes back to the surface.
	_rise = float(inp.get("rise", 0.0)) if layer > 0 and not autopilot else 0.0
	# (up and down at the same speed as from side to side, and eased into in the same way)
	# (no faster than the water is deep: in a shallow river it is a gentle rise and fall, not
	# a dart from top to bottom)
	var rise_max := clampf(track.layers() * track.layer_depth() * 0.8, 2.2, STEER * 0.8)
	_rise_v = lerpf(_rise_v, _rise * rise_max, 1.0 - exp(-3.0 * dt)) if layer > 0 else 0.0
	_swoop = _swoop + _rise_v * dt if _rise_v > rise_max * 0.5 else 0.0
	if absf(_rise_v) > 0.05:
		dive_to = clampf(dive_to - _rise_v / track.layer_depth() * dt, 0.6 if track.cfg.get("submerged", false) and _sunk_here() else 0.0, float(track.layers()))
		if dive_to < 0.3 and _swoop > minf(2.0, track.layers() * track.layer_depth() * 0.6) and not (track.cfg.get("submerged", false) and _sunk_here()):
			# The swoop: come up from the deep without a check and it goes on up, clean out
			# of the water, the higher the further it has climbed.
			vy = 10.0 + minf(_swoop, 14.0) * 0.85 + _ramp_vy
			_swoop = 0.0
			_rise_v = 0.0
			_do_splash(1.6)
			_take_off(true)
			return
		if dive_to < 0.3:
			_set_layer(0)
		else:
			layer = maxi(roundi(dive_to), 1)
	dive = move_toward(dive, dive_to, dt * maxf(1.0 / DIVE_TIME, STEER / track.layer_depth()))
	y = surf - track.layer_depth() * dive
	_prev_surface = surf
	_current_wait = maxf(_current_wait - dt, 0.0)
	var up := released or _swiped_up(inp)
	var down := (inp.swipes as Array).has(Vector2.DOWN)
	if layer > 0 or dive > 0.35:
		if up:
			_set_layer(layer - 1)
		elif down:
			_set_layer(layer + 1)
		elif _current_wait <= 0.0:
			_try_current()
	elif released:
		vy = 7.7 + 8.8 * charge + _ramp_vy
		_take_off(true)
	elif up:
		vy = 7.7 + 8.8 * SWIPE_JUMP * lerpf(0.72, 1.14, GameInput.swipe_power) + _ramp_vy
		_take_off(true)
	elif down:
		_set_layer(1)


## Dives to a layer under the water (0 is the surface).
func _set_layer(to: int) -> void:
	# (a stage that is all under the water has no surface to come up to)
	to = clampi(to, 1 if track.cfg.get("submerged", false) and _sunk_here() else 0, track.layers())
	if to == layer:
		return
	var deeper := to > layer
	dive_to = float(to)
	layer = to
	under = layer > 0
	charge = 0.0
	# (only breaking the surface splashes)
	if dive < 1.0:
		_do_splash(0.5)
	_stretch_v += 4.0
	dived.emit(deeper)


# ================================================================== ocean currents

## Swimming into a current under the sea carries the salmon off along it.
func _try_current() -> void:
	var depth := track.layer_depth() * dive
	for c: Dictionary in track.currents:
		if s < float(c.s0) or s > float(c.s1) - 30.0 or (c.get("abyss", false) and not track.fork_open):
			continue
		# (anywhere inside it, however wide it is)
		var wide := track.current_radius(c, s)
		if absf(x - track.current_x(c, s)) < wide + 0.95 and absf(depth - track.current_depth(c, s)) < maxf(1.3, wide):
			state = State.CURRENT
			rail = c
			_ridden = c.get("mat")
			if _ridden:
				_ridden.set_shader_parameter("clear", 10.0)
			rail_time = 0.0
			charge = 0.0
			vx = 0.0
			_stretch_v += 6.0
			Sfx.play("boost", 1.2, -4.0)
			return


## Riding a current: it sets the way, fast, like a rail. An up or down swipe leaves it early.
func _ride(dt: float, inp: Dictionary, released: bool) -> void:
	rail_time += dt
	# a swipe to one side spins it round on the log, once for each swipe
	for sw: Vector2 in inp.swipes:
		if sw.x != 0.0 and sw.y == 0.0:
			_rail_spin -= sw.x * 360.0
			_rail_spins += 1
			_mark()
			_stretch_v -= 3.0
	var turn := signf(_rail_spin) * minf(absf(_rail_spin), 900.0 * dt)
	_rail_spin -= turn
	_rail_yaw += turn
	boosting = true
	boost = minf(boost + 12.0 * dt, 100.0)
	speed = move_toward(speed, CRUISE + BOOST_SPEED + 4.0, 22.0 * dt)
	var prev_x := x
	s += speed * dt
	x = lerpf(x, track.current_x(rail, s), 1.0 - exp(-14.0 * dt))
	vx = (x - prev_x) / maxf(dt, 0.001)
	var depth := lerpf(track.layer_depth() * dive, track.current_depth(rail, s), 1.0 - exp(-14.0 * dt))
	dive = depth / track.layer_depth()
	layer = clampi(roundi(dive), 1, track.layers())
	dive_to = dive
	under = true
	_prev_surface = track.surface_y(s, x)
	y = track.water_y(s) - depth
	var up := released or _swiped_up(inp)
	var down := (inp.swipes as Array).has(Vector2.DOWN)
	var done := s >= float(rail.s1)
	if done and rail.get("launch", false):
		# it comes up to the surface and throws the salmon into the air
		trick_landed.emit(_on_beat("Ocean Current", 150 + int(rail_time * 250.0)))
		y = track.water_y(s)
		vy = Track.LAUNCH_VY
		vx = 0.0
		_do_splash(1.2)
		_take_off()
		return
	if up or down or done:
		state = State.SWIM
		boosting = false
		vx = 0.0
		_current_wait = 0.9
		trick_landed.emit(_on_beat("Ocean Current", 150 + int(rail_time * 250.0)))
		if up or down:
			_set_layer(layer + (1 if down else -1))


func _swiped_up(inp: Dictionary) -> bool:
	return (inp.swipes as Array).has(Vector2.UP)


func _take_off(by_jump := false) -> void:
	_marks.clear()
	_held = [true, true, true, true]
	if by_jump:
		_mark()
	state = State.AIR
	air_time = 0.0
	yaw = 0.0
	pitch = 0.0
	roll = 0.0
	_yaw_v = 0.0
	_pitch_v = 0.0
	_roll_v = 0.0
	_trick_t = [-1.0, -1.0]
	under = false
	layer = 0
	dive = 0.0
	dive_to = 0.0
	_trick_wait = [0.0, 0.0]
	grabs.clear()
	grab = -1
	charge = 0.0
	boosting = false
	# the take-off pose: stretched out along the leap
	_stretch_v += 7.0
	_do_splash(0.55)
	_ai_plan_trick()
	jumped.emit()


# ------------------------------------------------------------------ swipe tricks

func _trick_busy(axis: int) -> bool:
	return _trick_t[axis] >= 0.0 or _trick_wait[axis] != 0.0


## Plays the swipe tricks on one axis, one full turn at a time, and returns the new angle.
## Each turn is timed rather than turned at a steady rate, so it can have key poses: a small
## wind-up the wrong way, a whip round, and a little overshoot that settles.
func _run_trick(axis: int, angle: float, dt: float) -> float:
	if _trick_t[axis] < 0.0:
		_trick_dir[axis] = signf(_trick_wait[axis])
		_trick_wait[axis] -= _trick_dir[axis]
		_trick_from[axis] = angle
		# one trick run straight into the next skips the wind-up
		_trick_t[axis] = TRICK_WINDUP if _trick_chained[axis] else 0.0
		# tuck in as it starts
		_stretch_v -= 3.5
	_trick_t[axis] += dt / TRICK_TIME[axis]
	if _trick_t[axis] >= 1.0:
		_trick_t[axis] = -1.0
		_trick_chained[axis] = _trick_wait[axis] != 0.0
		# the follow-through: open out again as it stops
		_stretch_v += 2.5
		return _trick_from[axis] + 360.0 * _trick_dir[axis]
	_trick_chained[axis] = false
	return _trick_from[axis] + 360.0 * _trick_dir[axis] * _trick_curve(_trick_t[axis])


## How far through a turn (0 to 1) the salmon is at time `t` (0 to 1) of it.
static func _trick_curve(t: float) -> float:
	if t < TRICK_WINDUP:
		return -0.04 * sin(t / TRICK_WINDUP * PI)
	# whip round, run a little past the mark, and settle back onto it
	var u := (t - TRICK_WINDUP) / (1.0 - TRICK_WINDUP)
	return 1.0 - pow(1.0 - u, 2.4) + 0.045 * sin(PI * smoothstep(0.5, 1.0, u))


func _air(dt: float, inp: Dictionary) -> void:
	air_time += dt
	vy -= GRAVITY * dt
	y += vy * dt
	s += speed * dt
	vx *= exp(-0.8 * dt)
	x += vx * dt
	_clamp_banks()
	# each swipe is one full turn that way: sideways spins, up is a backflip, down a frontflip
	for sw: Vector2 in inp.swipes:
		_mark()
		_trick_wait[SPIN] -= sw.x
		_trick_wait[FLIP] -= sw.y
	# a held finger only steers on the water, so it doesn't spin the salmon up here
	var spin_in := 0.0 if GameInput.follow and not autopilot else -float(inp.steer)
	var r: Vector2
	if _trick_busy(SPIN):
		# (it corkscrews into a swipe to one side: a turn of the roll with each turn of the spin)
		var yaw_was := yaw
		yaw = _run_trick(SPIN, yaw, dt)
		roll += yaw - yaw_was
		_yaw_v = 0.0
	else:
		r = _spin(yaw, _yaw_v, spin_in, SPIN_RATE, 180.0, dt)
		yaw = r.x
		_yaw_v = r.y
	if _trick_busy(FLIP):
		pitch = _run_trick(FLIP, pitch, dt)
		_pitch_v = 0.0
	else:
		r = _spin(pitch, _pitch_v, -float(inp.pitch), FLIP_RATE, 360.0, dt)
		pitch = r.x
		_pitch_v = r.y
	r = _spin(roll, _roll_v, -float(inp.roll), ROLL_RATE, 360.0, dt)
	roll = r.x
	_roll_v = r.y
	grab = inp.grab
	# (on keys and pads a spin is held, not swiped: it is timed from when it is begun)
	var holding := [absf(spin_in) > 0.2, absf(float(inp.pitch)) > 0.2, absf(float(inp.roll)) > 0.2, grab >= 0]
	for i in holding.size():
		if holding[i] and not _held[i]:
			_mark()
	_held = holding
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
	# the landing pose: squashed flat, springing back
	_stretch_v -= clampf(impact / 2.2, 3.0, 9.0)
	_do_splash(clampf(impact / 13.0, 0.7, 1.7))
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
	# (how well it was timed is how well its swipes were, the jump among them, taken together:
	# not when it lands)
	var sum := 0
	for m in _marks:
		sum += m
	var trick := _on_beat(" + ".join(parts), pts, roundi(float(sum) / _marks.size()) if not _marks.is_empty() else 0)
	trick.swiped = true
	return trick


## Times a swipe against the beat, remembers it for the trick it is part of, and says so.
func _mark() -> void:
	var grade := Score.grade(Music.beat_offset(), Music.sec_per_beat)
	_marks.append(grade)
	swipe_timed.emit(grade)


## Swiping (or leaving a rail) close to the beat multiplies the points: the closer, the better
## the grade (see Score.GRADES).
func _on_beat(trick_name: String, pts: int, grade := -1) -> Dictionary:
	if grade < 0:
		grade = Score.grade(Music.beat_offset(), Music.sec_per_beat)
	pts = int(pts * float(Score.GRADES[grade][2]))
	# (beat: 0 off it, 1 on it, 2 as good as it gets)
	var beat := 2 if grade >= Score.GRADES.size() - 2 else (1 if grade >= Score.ON_BEAT else 0)
	return {"name": trick_name, "points": pts, "beat": beat, "grade": grade}


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
	under = false
	layer = 0
	dive = 0.0
	dive_to = 0.0
	rail = r
	rail_time = 0.0
	_rail_spin = 0.0
	_rail_yaw = 0.0
	_rail_spins = 0
	vy = 0.0
	yaw = 0.0
	pitch = 0.0
	roll = 0.0
	grab = -1
	grabs.clear()
	charge = 0.0
	_do_splash(0.6)
	Sfx.set_loop("grind", true)
	landed.emit(4.0)


func _grind(dt: float, inp: Dictionary, released: bool) -> void:
	rail_time += dt
	# a swipe to one side spins it round on the log, once for each swipe
	for sw: Vector2 in inp.swipes:
		if sw.x != 0.0 and sw.y == 0.0:
			_rail_spin -= sw.x * 360.0
			_rail_spins += 1
			_mark()
			_stretch_v -= 3.0
	var turn := signf(_rail_spin) * minf(absf(_rail_spin), 900.0 * dt)
	_rail_spin -= turn
	_rail_yaw += turn
	speed = move_toward(speed, CRUISE + 4.0, 3.0 * dt)
	s += speed * dt
	x = track.rail_x(rail, s)
	y = track.water_y(s) + Track.RAIL_H
	if inp.jump:
		charge = minf(charge + dt / 0.5, 1.0)
	if _swiped_up(inp):
		released = true
		charge = SWIPE_JUMP
	if released or s >= float(rail.s1):
		Sfx.set_loop("grind", false)
		var pts := 150 + int(rail_time * 450.0) + 260 * _rail_spins
		trick_landed.emit(_on_beat("Log Ride" + (" + %d" % (_rail_spins * 360) if _rail_spins > 0 else ""), pts))
		vy = 5.0 + (6.0 + 7.0 * charge if released else 0.0)
		_take_off()


# ================================================================== wipeouts & hazards

func _wipe(reason: String) -> void:
	state = State.WIPEOUT
	under = false
	layer = 0
	dive = 0.0
	dive_to = 0.0
	wipe_time = 0.0
	grab = -1
	charge = 0.0
	boosting = false
	Sfx.set_loop("grind", false)
	_do_splash(1.5)
	wiped_out.emit(reason)


## Swimming upstream, a waterfall is a wall of water: clear the top in the air or be swept
## back down for another run at it.
func _check_falls(prev_s: float) -> void:
	if not track.uphill():
		return
	for wf: Dictionary in track.waterfalls:
		var base := track.fall_base(wf)
		var top := base + Track.STEP
		if s >= base and prev_s <= top and y < track.water_y(top + 0.01) - 0.6:
			_wash_back(base)
			return


func _wash_back(base: float) -> void:
	# (not set down further back: carried there, see `washed`)
	washed = maxf(s - (base - WASH_BACK), 8.0)
	s = minf(s, base - 0.5)
	y = track.water_y(s)
	vy = 0.0
	speed = 12.0
	state = State.SWIM
	under = false
	layer = 0
	dive = 0.0
	dive_to = 0.0
	charge = 0.0
	grab = -1
	yaw = 0.0
	pitch = 0.0
	roll = 0.0
	_land_twist = 0.0
	_prev_surface = y
	_ramp_vy = 0.0
	_stumble = 0.5
	_do_splash(1.1)
	bumped.emit("WASHED BACK!")


## Glancing off a rock: knocked sideways and slowed, but still steerable.
func _bump(rock_x: float, word := "ROCKED!") -> void:
	speed *= 0.6
	vx = (8.0 if x >= rock_x else -8.0)
	charge = 0.0
	invuln = 0.8
	_stumble = 0.5
	_do_splash(0.9)
	bumped.emit(word)


func _wipeout(dt: float) -> void:
	wipe_time += dt
	speed = move_toward(speed, 9.0, 25.0 * dt)
	s += speed * dt
	x += vx * dt
	vx *= exp(-2.0 * dt)
	_clamp_banks()
	var surf := track.water_y(s)
	# Only properly airborne counts as falling (knocked out of a jump, or over a waterfall).
	# Where the river runs downhill the surface drops away a little every frame, and treating
	# that as "in the air" meant the salmon never touched down to recover: it stayed wiped out
	# for the whole of a rapid, longer the lower the frame rate.
	if y > surf + AIRBORNE:
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
	# dived, you pass under anything that only floats (containers, ice, barrels)...
	var floats: bool = track.cfg.get("rock_mesh", "") == "crate" or track.cfg.get("rocks_float", false)
	if above < 1.3 and state != State.GRIND and not (dive > 0.6 and floats):
		for r: Dictionary in track.rocks:
			var ds: float = s - float(r.s)
			if absf(ds) < 3.5 and Vector2(ds, x - float(r.x)).length() < float(r.r) + 0.6:
				if state == State.SWIM:
					_bump(float(r.x), track.cfg.get("rock_word", "ROCKED!"))
				else:
					_wipe(track.cfg.get("rock_word", "ROCKED!"))
				return
	# a sea nettle stings whatever touches its bell or swims through what trails under it
	for j: Dictionary in track.jellies:
		var ds: float = s - float(j.s)
		var over := above + float(j.d)
		if absf(ds) < 3.0 and Vector2(ds, x - float(j.x)).length() < 1.7 and over < 1.2 and over > -3.0:
			_bump(float(j.x), "STUNG!")
			return
	# a boat crossing the course runs down whatever is at the surface in its way: go round
	# it, or dive under it
	for c: Dictionary in track.crossers:
		if absf(s - float(c.s)) < 3.4 and absf(x - float(c.node.across)) < 4.2 and above < 2.4 and dive < 0.6:
			_wipe("RUN DOWN!")
			return
	for b: Dictionary in track.bears:
		var ds: float = s - float(b.s)
		# a shark is wherever it has swum to, across the way and under the water: touch it at
		# its own depth and it has you (swim round it, over it or under it)
		if track.cfg.predator == "shark":
			if absf(ds) < 2.4 and absf(x - float(b.x) - float(b.node.across)) < 3.2 and absf(above + float(b.node.depth)) < 1.5:
				_wipe(track.cfg.predator_word)
				Sfx.play("bear")
				return
			continue
		# ...and under the paws of a bear
		if dive > 0.6 and track.cfg.predator == "bear":
			break
		if absf(ds) < 3.6 and absf(x - float(b.x)) < 4.6 and above < 4.6 and b.node.is_swiping():
			_wipe(track.cfg.predator_word)
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
	# (and out of the divider of a fork, and off the shut side of it)
	var kept := track.fork_keep(s, x)
	if kept != x:
		if (kept - x) * vx < 0.0:
			vx = -vx * 0.3
		x = kept


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
	var ease := 1.0 - exp(-10.0 * dt)
	var inv_dt := 1.0 / maxf(dt, 0.001)
	var spinning := state == State.AIR
	_yaw_rate = lerpf(_yaw_rate, clampf((yaw - _prev_yaw) * inv_dt / SPIN_RATE, -1.0, 1.0) if spinning else 0.0, ease)
	_pitch_rate = lerpf(_pitch_rate, clampf((pitch - _prev_pitch) * inv_dt / FLIP_RATE, -1.0, 1.0) if spinning else 0.0, ease)
	_turn = lerpf(_turn, clampf((vx - _prev_vx) * inv_dt / 60.0, -1.0, 1.0) if state == State.SWIM else 0.0, ease)
	_prev_yaw = yaw
	_prev_pitch = pitch
	_prev_vx = vx
	match state:
		State.IDLE, State.SWIM, State.CURRENT:
			pos.y -= 0.1 - sin(_t * 5.0) * 0.05
			# nose down on the way under, nose up on the way back
			# (its nose leads into a climb or a dive just as it leads into a turn: by how steeply
			# it is going up or down for the speed it is swimming at)
			_climb = lerpf(_climb, (_dive_was - dive) * track.layer_depth() * inv_dt, ease)
			_dive_was = dive
			var tip := clampf(-atan2(_climb, maxf(speed, 10.0)) * 1.3, -0.9, 0.9)
			_land_twist = lerpf(_land_twist, 0.0, 1.0 - exp(-8.0 * dt))
			if _stumble > 0.0:
				_stumble = maxf(_stumble - dt, 0.0)
				_land_twist += sin(_t * 30.0) * 40.0 * _stumble
			# nose leads into the turn and the body bends through it
			var lead := -atan2(vx, maxf(speed, 10.0)) * 1.3
			target_bend = _turn * 0.9
			b = base * Basis(Vector3.UP, deg_to_rad(_land_twist) + lead) \
					* Basis(Vector3.RIGHT, slope_ang + sin(_t * 5.0) * 0.05 - tip) \
					* Basis(Vector3.BACK, -vx * 0.035 - _dash_dir * TAU * smoothstep(0.0, 1.0, _dash_t))
			_dash_t = minf(_dash_t + dt / 0.32, 1.0)
			wag_speed = 8.0 + speed * 0.35
			if state == State.IDLE:
				wag_speed = 5.0
			target_curl = RAIL_ARCH + charge * 0.3
		State.AIR:
			# (it follows the arc of the leap: nose up going up, over the top, and nose down coming in)
			var traj := atan2(vy, maxf(speed, 1.0)) * 1.0
			# Swing through spins and flips: the salmon travels round a small circle whose centre
			# is on the inside of the turn, with its body curved along it.
			var yaw_b := Basis(Vector3.UP, deg_to_rad(yaw))
			var side := Vector3(-ARC_RADIUS * _yaw_rate, 0.0, 0.0)
			var up := Vector3(0.0, ARC_RADIUS * _pitch_rate, 0.0)
			pos += base * (side - yaw_b * side + yaw_b * (up - Basis(Vector3.RIGHT, deg_to_rad(pitch)) * up))
			target_bend = -_yaw_rate
			target_curl = _pitch_rate
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
			# (round and round on a swipe; and its back arched, riding on its belly)
			b = base * Basis(Vector3.UP, deg_to_rad(_rail_yaw)) * Basis(Vector3.BACK, sin(_t * 9.0) * 0.12)
			wag_speed = 18.0
			wag_amp = 0.06
			target_curl = RAIL_ARCH + charge * 0.3
		State.WIPEOUT:
			var k := 1.0 - clampf(wipe_time / WIPE_TIME, 0.0, 1.0)
			b = base * Basis(Vector3.UP, _t * 9.0 * k) * Basis(Vector3.BACK, _t * 14.0 * k)
			pos.y -= 0.2 * (1.0 - k)
			wag_speed = 24.0 * k
			wag_amp = 0.2 * k
	# (swept back down from a waterfall: over and over, half under the water)
	if washed > 0.0:
		b = base * Basis(Vector3.UP, _t * 7.0) * Basis(Vector3.BACK, _t * 11.0)
		pos.y -= 0.25
	# Squash and stretch on a spring: kicked long at take-off, flat on landing, tucked as a
	# trick starts, and left to ring a little each time (the follow-through).
	_stretch_v += (-260.0 * _stretch - 15.0 * _stretch_v) * dt
	_stretch = clampf(_stretch + _stretch_v * dt, -0.36, 0.5)
	_fish.scale = _base_scale * Vector3(1.0 - 0.45 * _stretch, 1.0 - 0.45 * _stretch, 1.0 + _stretch)
	if state == State.SWIM:
		pos.y += minf(_stretch, 0.0) * 0.9
	# it floats on the swell: all of it at the surface, none of it dived or well up in the air
	pos.y += track.swell_y(s, x) * (1.0 - smoothstep(0.0, 1.0, dive)) * (1.0 - smoothstep(0.0, 2.5, y - track.water_y(s)))
	transform = Transform3D(b.orthonormalized(), pos)
	# The body follows its pose on springs too, so the tail lags the turn and swings past
	# when it stops.
	_curl_v += (210.0 * (target_curl - _curl) - 13.0 * _curl_v) * dt
	_curl += _curl_v * dt
	_bend_v += (210.0 * (target_bend - _bend) - 13.0 * _bend_v) * dt
	_bend += _bend_v * dt
	_wag_phase += dt * wag_speed
	_mat.set_shader_parameter("wag_phase", _wag_phase)
	_mat.set_shader_parameter("wag_amp", wag_amp)
	_mat.set_shader_parameter("curl", _curl)
	_mat.set_shader_parameter("bend", _bend)
	var blink := invuln > 0.0 and fmod(_t, 0.2) < 0.1
	_mat.set_shader_parameter("flash", 0.6 if blink else (0.35 if boosting else 0.0))
	# the wake is cut only while swimming at the surface, and is stronger the faster it goes
	_wake.track = track
	_wake.lay(s, x, clampf(speed / CRUISE, 0.4, 1.4) if state == State.SWIM and speed > 5.0 and dive < 0.3 else 0.0, dt)
	_bubbles.emitting = (state == State.SWIM or state == State.CURRENT) and dive > 0.5
	# (sparks off the rail only: in the air they were just blue specks round the fish)
	_spray.emitting = state == State.GRIND
	if _spray.emitting:
		# (up and back the way it has come, a little to either side by turns)
		_spray.direction = (Vector3.UP * 1.2 - track.forward(s) + track.right(s) * sin(_t * 23.0) * 0.7).normalized()
		_spray.global_position = track.point(s, x, y - 0.25)
	for dots in _dots:
		dots.emitting = state == State.SWIM and speed > 8.0 and dive < 0.3


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
	var inp := {"steer": 0.0, "pitch": 0.3, "roll": 0.0, "jump": false, "boost": false, "grab": -1, "swipes": []}
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
				# going down, leap off the lip; going up, a full charge released in time to clear it
				if (d > 17.0 and d < 36.0) if track.uphill() else (d > 1.0 and d < 14.0):
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


# On a stage that is all under the water: whether this is the part of it that is (all of it
# but the last stretch, after the current that climbs back to the surface).
func _sunk_here() -> bool:
	for c: Dictionary in track.currents:
		if c.get("launch", false) and s > float(c.s1) - 5.0:
			return false
	return true
